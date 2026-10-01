class_name BloodPools
extends Sprite2D

## **Where the blood runs deep** (owner, 2026-10-01: *"where there is dense
## fresh blood it should pool to increasing depths and the deeper it is the
## more it should slow characters moving through it. And also furthermore the
## pools should spread to surrounding vicinity with a blood-like viscosity as
## the pool's depths reduces with its spread naturally"*). Brutal blood only.
##
## A sheet of cells `BLOOD_POOL_CELL` across over the field, each holding a
## depth and how fresh it is. A mark laid on Brutal pours its volume into the
## cells under it; a pool deeper than its neighbours gives them a share of the
## difference at `BLOOD_POOL_VISCOSITY` - slowly, so it creeps rather than runs
## - and every pool soaks into the ground at `BLOOD_POOL_SOAK`, so spreading is
## also thinning. Only cells that hold anything are visited.
##
## **Drawn as one texture**: a texel a cell, filtered smooth, through
## `blood_pool.gdshader` - dark where it is old, red and glossy where it is
## fresh, lit off its own slope, and gathering first in the dents of the ground
## where the ground is scarred (`GroundScars`). Updated a few times a second
## and only when something moved.
##
## **The one gameplay number**: `slow_at`, what a pool takes off the speed of
## anything walking through it, up to `BLOOD_POOL_SLOW_MAX` at
## `BLOOD_POOL_FULL`. The same for a Warden, a body and an animal.

var _half: float = 0.0
var _across: int = 0
var _depth: PackedFloat32Array = PackedFloat32Array()
var _fresh: PackedFloat32Array = PackedFloat32Array()
var _active: PackedInt32Array = PackedInt32Array()
var _in_active: PackedByteArray = PackedByteArray()
var _image: Image = null
var _texture: ImageTexture = null
var _dirty: bool = false
var _sim_left: float = 0.0
var _draw_left: float = 0.0
var _total: float = 0.0
## Seconds of a quake's slosh left: pools creep faster while it runs.
var _sloshing: float = 0.0
## The heights of the ground's scars, when there are any, for the shader.
var scars: GroundScars = null:
	set(value):
		scars = value
		_wire_scars()


func _init(half_extent: float = 0.0) -> void:
	_half = half_extent if half_extent > 0.0 else BattleGrid.HALF_EXTENT
	_across = maxi(int(ceil(_half * 2.0 / Balance.BLOOD_POOL_CELL)), 1)
	_depth.resize(_across * _across)
	_depth.fill(0.0)
	_fresh.resize(_across * _across)
	_fresh.fill(0.0)
	_in_active.resize(_across * _across)
	_in_active.fill(0)


func _ready() -> void:
	name = "BloodPools"
	centered = false
	position = Vector2(-_half, -_half)
	scale = Vector2.ONE * Balance.BLOOD_POOL_CELL
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if DisplayServer.get_name() != "headless":
		_image = Image.create(_across, _across, false, Image.FORMAT_RG8)
		_image.fill(Color(0.0, 0.0, 0.0, 1.0))
		_texture = ImageTexture.create_from_image(_image)
		texture = _texture
		var shader: Shader = load("res://scripts/shaders/blood_pool.gdshader") as Shader
		if shader != null:
			var made := ShaderMaterial.new()
			made.shader = shader
			made.set_shader_parameter("fresh_colour", Balance.BLOOD_POOL_FRESH)
			made.set_shader_parameter("dry_colour", Balance.BLOOD_POOL_DRY)
			made.set_shader_parameter("depth_range", Balance.BLOOD_POOL_MAX)
			material = made
		_wire_scars()
	visible = false


func _wire_scars() -> void:
	var made := material as ShaderMaterial
	if made == null:
		return
	var heights: Texture2D = scars.heights() if scars != null and is_instance_valid(scars) else null
	made.set_shader_parameter("scar_enabled", 1.0 if heights != null else 0.0)
	if heights != null:
		made.set_shader_parameter("scars", heights)
		# The scars' sheet may be laid on another grid: map pool UV to scar UV.
		made.set_shader_parameter("scar_extent", scars.half_extent())
		made.set_shader_parameter("pool_extent", _half)


## **Pours `volume` of blood at `at`**, spread over `radius`, most at the
## middle. The whole of it lands - spread by weight - so a mark is worth the
## same blood wherever it falls.
func pour(at: Vector2, volume: float, radius: float) -> void:
	if volume <= 0.0:
		return
	var reach: float = maxf(radius, Balance.BLOOD_POOL_CELL * 0.6)
	var low: Vector2i = _cell_of(at - Vector2(reach, reach))
	var high: Vector2i = _cell_of(at + Vector2(reach, reach))
	var cells: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var sum: float = 0.0
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var centre: Vector2 = _centre_of(x, y)
			var falloff: float = 1.0 - centre.distance_to(at) / reach
			if falloff <= 0.0:
				continue
			cells.append(y * _across + x)
			weights.append(falloff)
			sum += falloff
	if cells.is_empty():
		var only: Vector2i = _cell_of(at)
		if not _inside(at):
			return
		cells.append(only.y * _across + only.x)
		weights.append(1.0)
		sum = 1.0
	for i: int in cells.size():
		var index: int = cells[i]
		var added: float = volume * weights[i] / sum
		_depth[index] = minf(_depth[index] + added, Balance.BLOOD_POOL_MAX)
		_fresh[index] = 1.0
		_activate(index)
		_total += added
	_dirty = true
	visible = true
	set_process(true)


## How deep the blood is at `at`, read across the four nearest cells.
func depth_at(point: Vector2) -> float:
	if _total <= 0.0:
		return 0.0
	var fx: float = (point.x + _half) / Balance.BLOOD_POOL_CELL - 0.5
	var fy: float = (point.y + _half) / Balance.BLOOD_POOL_CELL - 0.5
	var x0: int = clampi(int(floor(fx)), 0, _across - 1)
	var y0: int = clampi(int(floor(fy)), 0, _across - 1)
	var x1: int = mini(x0 + 1, _across - 1)
	var y1: int = mini(y0 + 1, _across - 1)
	var tx: float = clampf(fx - float(x0), 0.0, 1.0)
	var ty: float = clampf(fy - float(y0), 0.0, 1.0)
	var top: float = lerpf(_depth[y0 * _across + x0], _depth[y0 * _across + x1], tx)
	var bottom: float = lerpf(_depth[y1 * _across + x0], _depth[y1 * _across + x1], tx)
	return lerpf(top, bottom, ty)


## **What a pool takes off the speed of anything walking through it**: 1 on
## dry ground, falling to `1 - BLOOD_POOL_SLOW_MAX` at `BLOOD_POOL_FULL`.
func slow_at(point: Vector2) -> float:
	var depth: float = depth_at(point)
	if depth <= Balance.BLOOD_POOL_SLOW_FROM:
		return 1.0
	var share: float = clampf((depth - Balance.BLOOD_POOL_SLOW_FROM)
		/ maxf(Balance.BLOOD_POOL_FULL - Balance.BLOOD_POOL_SLOW_FROM, 0.001), 0.0, 1.0)
	return 1.0 - Balance.BLOOD_POOL_SLOW_MAX * smoothstep(0.0, 1.0, share)


## How high up a body standing here the blood reaches, in world units.
func wade_at(point: Vector2) -> float:
	var depth: float = depth_at(point)
	if depth <= Balance.BLOOD_POOL_SLOW_FROM * 0.5:
		return 0.0
	return minf(depth * Balance.BLOOD_WADE_PER_DEPTH, Balance.BLOOD_WADE_MAX)


## All the blood on the field, for the gate.
func total() -> float:
	return _total


func active_count() -> int:
	return _active.size()


## **Washed**: a heavy flood carries blood away at `rate` of the depth a second.
func wash(rate: float, delta: float) -> void:
	if _total <= 0.0 or rate <= 0.0:
		return
	var keep: float = maxf(1.0 - rate * delta, 0.0)
	for index: int in _active:
		_depth[index] *= keep
	_recount()
	_dirty = true


## The ground is shaking: the pools creep `BLOOD_POOL_QUAKE_SLOSH` times as
## fast for `seconds`.
func agitate(seconds: float) -> void:
	_sloshing = maxf(_sloshing, seconds)
	if not _active.is_empty():
		set_process(true)


func clear() -> void:
	for index: int in _active:
		_depth[index] = 0.0
		_fresh[index] = 0.0
		_in_active[index] = 0
	_active = PackedInt32Array()
	_total = 0.0
	_dirty = true
	visible = false


func _process(delta: float) -> void:
	_sim_left -= delta
	if _sim_left <= 0.0:
		var step: float = 1.0 / Balance.BLOOD_POOL_SIM_HZ
		_sim_left += step
		_simulate(step)
	_draw_left -= delta
	if _dirty and _draw_left <= 0.0:
		_draw_left = 1.0 / Balance.BLOOD_POOL_DRAW_HZ
		_upload()
	if _active.is_empty() and not _dirty:
		set_process(false)


## **One step of the pools**: each cell deeper than its neighbours gives each a
## share of the difference, and everything soaks into the ground a little.
func _simulate(step: float) -> void:
	if _active.is_empty():
		return
	var slosh: float = Balance.BLOOD_POOL_QUAKE_SLOSH if _sloshing > 0.0 else 1.0
	_sloshing = maxf(_sloshing - step, 0.0)
	var flow_share: float = clampf(Balance.BLOOD_POOL_VISCOSITY * slosh * step, 0.0, 0.2)
	var soak: float = Balance.BLOOD_POOL_SOAK * step
	var fresh_keep: float = pow(0.5, step / maxf(Balance.BLOOD_POOL_FRESH_HALF_LIFE, 1.0))
	var visiting: PackedInt32Array = _active.duplicate()
	for index: int in visiting:
		var depth: float = _depth[index]
		if depth > Balance.BLOOD_POOL_SPREAD_FROM:
			var x: int = index % _across
			var y: int = index / _across
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx < 0 or ny < 0 or nx >= _across or ny >= _across:
					continue
				var neighbour: int = ny * _across + nx
				var gap: float = _depth[index] - _depth[neighbour]
				if gap <= Balance.BLOOD_POOL_SPREAD_FROM * 0.5:
					continue
				var moved: float = gap * flow_share
				_depth[index] -= moved
				_depth[neighbour] += moved
				_fresh[neighbour] = maxf(_fresh[neighbour], _fresh[index] * 0.9)
				_activate(neighbour)
		_depth[index] = maxf(_depth[index] - soak, 0.0)
		_fresh[index] *= fresh_keep
	# Drop what has soaked away.
	var kept: PackedInt32Array = PackedInt32Array()
	for index: int in _active:
		if _depth[index] > 0.002:
			kept.append(index)
		else:
			_depth[index] = 0.0
			_fresh[index] = 0.0
			_in_active[index] = 0
	_active = kept
	_recount()
	_dirty = true


func _upload() -> void:
	_dirty = false
	visible = _total > 0.0
	if _image == null or _texture == null:
		return
	# Only the cells that hold blood, and their neighbours that just lost it,
	# change - but a whole upload is one call and cheaper than tracking which.
	_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	var range_max: float = maxf(Balance.BLOOD_POOL_MAX, 0.001)
	for index: int in _active:
		_image.set_pixel(index % _across, index / _across,
			Color(clampf(_depth[index] / range_max, 0.0, 1.0), clampf(_fresh[index], 0.0, 1.0), 0.0, 1.0))
	_texture.update(_image)


## **The pools, for a banked front** (Brutal): every cell that holds anything,
## as `[index, depth in thousandths, freshness in hundredths]` flat.
func snapshot() -> Array:
	var out: Array = []
	for index: int in _active:
		if _depth[index] < 0.01:
			continue
		out.append(index)
		out.append(int(round(_depth[index] * 1000.0)))
		out.append(int(round(_fresh[index] * 100.0)))
	return out


func restore(stored: Array) -> void:
	clear()
	var at: int = 0
	while at + 2 < stored.size():
		var index: int = int(stored[at])
		if index >= 0 and index < _depth.size():
			_depth[index] = clampf(float(stored[at + 1]) / 1000.0, 0.0, Balance.BLOOD_POOL_MAX)
			_fresh[index] = clampf(float(stored[at + 2]) / 100.0, 0.0, 1.0)
			_activate(index)
		at += 3
	_recount()
	_dirty = true
	visible = _total > 0.0
	set_process(true)


func _activate(index: int) -> void:
	if _in_active[index] == 0:
		_in_active[index] = 1
		_active.append(index)


func _recount() -> void:
	_total = 0.0
	for index: int in _active:
		_total += _depth[index]


func _inside(point: Vector2) -> bool:
	return absf(point.x) < _half and absf(point.y) < _half


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((point.x + _half) / Balance.BLOOD_POOL_CELL)), 0, _across - 1),
		clampi(int(floor((point.y + _half) / Balance.BLOOD_POOL_CELL)), 0, _across - 1))


func _centre_of(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * Balance.BLOOD_POOL_CELL - _half,
		(float(y) + 0.5) * Balance.BLOOD_POOL_CELL - _half)
