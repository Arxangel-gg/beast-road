class_name TrampleField
extends Node2D

## **Plants give way to whatever walks through them.**
##
## The owner's brief: "moving through small foliage plants should procedurally
## animate them". The foliage shader already leans every plant on a travelling
## wind, and the obvious answer - tell each plant about the hero - is the one
## thing this cannot do: `Foliage` shares **one material per painted kind** on
## purpose, so there is no per-plant uniform to write to. A material per plant
## is the cost that file was written to avoid.
##
## So the disturbance is *data* rather than a parameter, and it is the same
## shape `FogOfWar` already proved here: one small image over the field,
## stamped on the CPU a few times a second and read in the vertex shader. It
## costs one texture sample per vertex and is flat in the number of movers -
## forty enemies, four heroes, a herd of deer and a beast's footfall all stamp
## into the same picture for the same price.
##
## **What a texel holds.** The push *direction* in RG, signed around 0.5, and
## its *strength* in B. Direction matters: a plant shoved by something crossing
## left to right leans right and springs back, which is the difference between
## foliage that reacts and foliage that merely flattens. A strength-only field
## would make every plant bow the same way whatever went past.
##
## **Nothing reads it but the shader.** It changes no number, decides no
## collision and is never asked where anything is - the same bound the fog and
## the phenotypes are held to, and the reason `Graphics.KEY_FOLIAGE_TRAMPLE`
## can switch the whole thing off on a weak machine with the run byte for byte
## identical.

const FORMAT: int = Image.FORMAT_RGB8

## One texel per this many world units. Coarse on purpose: the bend is a soft
## blob several texels wide and a bilinear read smooths it further, so a finer
## grid would cost memory to describe something nothing can see.
var cell: float = 48.0
var half_extent: float = BattleGrid.HALF_EXTENT

## How often the picture is restamped. The plants are drawn every frame and
## their lean eases, so the field itself does not need frame rate - measured
## against `flame.gd`, which cost this project two performance passes by
## rebuilding geometry every frame for something nobody could see move.
var hz: float = 15.0

var _across: int = 0
var _push_x: PackedFloat32Array = PackedFloat32Array()
var _push_y: PackedFloat32Array = PackedFloat32Array()
var _weight: PackedFloat32Array = PackedFloat32Array()
var _bytes: PackedByteArray = PackedByteArray()
var _image: Image = null
var _texture: ImageTexture = null
var _clock: float = 0.0
var _last: Dictionary = {}
var _on: bool = true
## **Only the trodden cells cost anything** (2026-09-24). The decay and
## the publish walked all thirteen thousand cells fifteen times a second -
## 2.8 ms a stamp, in script - when a few hundred were ever pressed. The
## live list is every cell with weight in it; a cell that decays to nothing
## writes its neutral bytes once and leaves the list.
var _live: PackedInt32Array = PackedInt32Array()
var _in_live: PackedByteArray = PackedByteArray()


func _ready() -> void:
	name = "TrampleField"
	_across = maxi(int(ceil(half_extent * 2.0 / maxf(cell, 1.0))), 2)
	var count: int = _across * _across
	_push_x.resize(count)
	_push_y.resize(count)
	_weight.resize(count)
	_in_live.resize(count)
	_bytes.resize(count * 3)
	_clear()
	_image = Image.create_from_data(_across, _across, false, FORMAT, _bytes)
	_texture = ImageTexture.create_from_image(_image)
	_publish()


func _clear() -> void:
	_push_x.fill(0.0)
	_push_y.fill(0.0)
	_weight.fill(0.0)
	_in_live.fill(0)
	_live = PackedInt32Array()
	for i: int in _bytes.size():
		_bytes[i] = 128 if i % 3 < 2 else 0


## Hands the field to the shared foliage materials. Called once, and again if
## the terrain is re-laid: `Foliage` rebuilds its materials per region, and a
## texture handed to the old one reaches nothing.
func publish_to(materials: Array) -> void:
	for entry: Variant in materials:
		var material := entry as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("trample", _texture)
		material.set_shader_parameter("trample_extent", half_extent)
		material.set_shader_parameter("trample_reach",
			Balance.FOLIAGE_TRAMPLE_REACH if _on else 0.0)


func set_enabled(on: bool) -> void:
	_on = on


func _process_measured(delta: float) -> void:
	if not _on or _image == null:
		return
	_clock += delta
	var step: float = 1.0 / maxf(hz, 1.0)
	if _clock < step:
		return
	_stamp(_clock)
	_clock = 0.0


## Everything on the field that has feet, and where it was last time.
##
## The push is the *direction of travel*, not a direction away from the body:
## something walking north through a clump lays it north, which is what a
## trail through long grass actually looks like. A body standing still lays
## nothing new and what it already laid springs back under it.
func _movers() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for group: String in [Hero.GROUP_ANY, Enemy.GROUP, Companion.GROUP]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body := node as Node2D
			if body != null and is_instance_valid(body):
				out.append(body)
	return out


func _stamp(delta: float) -> void:
	# Everything eases back first, so a plant springs up behind whatever passed
	# rather than staying flat for the rest of the act.
	var keep: float = exp(-delta / maxf(Balance.FOLIAGE_TRAMPLE_SPRING, 0.05))
	var survivors := PackedInt32Array()
	for i: int in _live:
		var weight: float = _weight[i] * keep
		if weight < 0.004:
			_weight[i] = 0.0
			_push_x[i] = 0.0
			_push_y[i] = 0.0
			_in_live[i] = 0
			_bytes[i * 3] = 128
			_bytes[i * 3 + 1] = 128
			_bytes[i * 3 + 2] = 0
			continue
		_weight[i] = weight
		_push_x[i] *= keep
		_push_y[i] *= keep
		survivors.append(i)
	_live = survivors
	var seen: Dictionary = {}
	for body: Node2D in _movers():
		var at: Vector2 = body.global_position
		var id: int = body.get_instance_id()
		seen[id] = at
		var before: Variant = _last.get(id, null)
		if before == null:
			continue
		var moved: Vector2 = at - (before as Vector2)
		# A body that has not really moved does not lay anything down.
		if moved.length() < Balance.FOLIAGE_TRAMPLE_MIN_STEP:
			continue
		_press(at, moved.normalized(), Balance.FOLIAGE_TRAMPLE_RADIUS)
	_last = seen
	_publish_bytes()


## One soft blob, strongest at the middle and nothing at the rim.
func _press(at: Vector2, way: Vector2, radius: float) -> void:
	var reach: int = maxi(int(ceil(radius / maxf(cell, 1.0))), 1)
	var centre: Vector2i = _cell_of(at)
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var x: int = centre.x + dx
			var y: int = centre.y + dy
			if x < 0 or y < 0 or x >= _across or y >= _across:
				continue
			var away: float = Vector2(float(dx), float(dy)).length() / float(reach)
			if away > 1.0:
				continue
			var strength: float = 1.0 - away * away
			var i: int = y * _across + x
			if _in_live[i] == 0:
				_in_live[i] = 1
				_live.append(i)
			_weight[i] = minf(_weight[i] + strength, 1.0)
			_push_x[i] = clampf(_push_x[i] + way.x * strength, -1.0, 1.0)
			_push_y[i] = clampf(_push_y[i] + way.y * strength, -1.0, 1.0)


func _cell_of(at: Vector2) -> Vector2i:
	var u: float = (at.x + half_extent) / maxf(half_extent * 2.0, 1.0)
	var v: float = (at.y + half_extent) / maxf(half_extent * 2.0, 1.0)
	return Vector2i(clampi(int(u * float(_across)), 0, _across - 1),
		clampi(int(v * float(_across)), 0, _across - 1))


func _publish_bytes() -> void:
	for i: int in _live:
		_bytes[i * 3] = int(clampf((_push_x[i] * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		_bytes[i * 3 + 1] = int(clampf((_push_y[i] * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		_bytes[i * 3 + 2] = int(clampf(_weight[i] * 255.0, 0.0, 255.0))
	_publish()


func _publish() -> void:
	if _image == null:
		return
	_image.set_data(_across, _across, false, FORMAT, _bytes)
	_texture.update(_image)


## For the gate: how hard the field is pressed at a point, 0 to 1.
func pressed_at(at: Vector2) -> float:
	var c: Vector2i = _cell_of(at)
	return _weight[c.y * _across + c.x]


## For the gate: which way the plants there have been laid.
func laid_at(at: Vector2) -> Vector2:
	var c: Vector2i = _cell_of(at)
	var i: int = c.y * _across + c.x
	return Vector2(_push_x[i], _push_y[i])


func cells_across() -> int:
	return _across


## `FrameProfile` bucket "trample": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"trample", started)
