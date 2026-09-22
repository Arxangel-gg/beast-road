class_name FogOfWar
extends Node2D

## The fog of war (owner brief, 2026-09-12: "like League of Legends"): what
## the party has never seen is dark, what it has seen and left is dim, and
## what something of the party's can see now is clear. Heroes, companions,
## towers and the town all give vision; a body standing in the fog is not
## drawn at all, which is the whole point of a fog rather than a tint.
##
## One small image over the field - a cell a tile - carrying "explored" in
## its luminance and "seen now" in its alpha, stamped on the CPU a few times
## a second and drawn stretched over the field through `fog_of_war.gdshader`,
## whose bilinear read is what turns the cells into a soft edge. The same
## texture is what the minimap darkens with, so the two can never disagree
## about what has been seen.
##
## Generic on purpose: the battlefield gives it the grid's extent and the
## road's vision sources, and a raid or a dungeon gives it the arena's and
## the hero alone - so every stage of a dungeon is fresh discovery.

const FORMAT: Image.Format = Image.FORMAT_LA8

## The field's half extent and the size of one fog cell, in world units.
var half_extent: float = BattleGrid.HALF_EXTENT
var cell: float = BattleGrid.TILE
## Returns an Array of {"at": Vector2, "radius": float}: what can see, and how far.
var sources: Callable = Callable()
## Groups whose members are hidden while the fog covers them.
var hide_groups: Array[StringName] = []
## **The only part of the tree this fog may hide**, and it is load-bearing
## rather than tidy.
##
## `_hide_the_unseen` walks `get_nodes_in_group`, which is the *whole tree* -
## so a raid or a rift arena's fog reached every body still standing on the
## battlefield, found them nowhere near the arena's hero, and set them
## invisible. The owner's report of 2026-09-22: *"once players return from a
## raid or dungeon the enemies that were on the map have their visuals off and
## are hidden"*. Each stage of a dungeon stands a fresh fog up, so the one that
## hid them was routinely not the one still alive to put them back.
##
## A fog is the fog *of a place*. Left null it hides nothing, which is the
## safe direction: a fog that forgot its scope stops hiding rather than
## starts hiding somebody else's road.
var scope: Node = null
## The wildlife system, which hides its own animals (they are not nodes of a group).
var wildlife: Node = null

var _across: int = 0
var _explored: PackedByteArray = PackedByteArray()
var _visible: PackedByteArray = PackedByteArray()
var _bytes: PackedByteArray = PackedByteArray()
var _image: Image = null
var _texture: ImageTexture = null
var _veil: Sprite2D = null
var _rim: Node2D = null
var _clock: float = 0.0
var _on: bool = true
var _hidden: Array[CanvasItem] = []


func _ready() -> void:
	name = "FogOfWar"
	_across = maxi(int(ceil(half_extent * 2.0 / maxf(cell, 1.0))), 2)
	var count: int = _across * _across
	_explored.resize(count)
	_explored.fill(0)
	_visible.resize(count)
	_visible.fill(0)
	_bytes.resize(count * 2)
	_bytes.fill(0)
	_image = Image.create_from_data(_across, _across, false, FORMAT, _bytes)
	_texture = ImageTexture.create_from_image(_image)
	_veil = Sprite2D.new()
	_veil.name = "Veil"
	_veil.texture = _texture
	_veil.centered = true
	# Stretched over the field: one texel a cell, read bilinearly.
	_veil.scale = Vector2.ONE * (half_extent * 2.0 / float(_across))
	_veil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/shaders/fog_of_war.gdshader")
	material.set_shader_parameter("unexplored", Balance.FOG_UNEXPLORED_ALPHA)
	material.set_shader_parameter("explored", Balance.FOG_EXPLORED_ALPHA)
	_veil.material = material
	add_child(_veil)
	# The rim: four bands of the unexplored shade round the field, so the
	# treeline beyond the grid is as dark as ground never walked.
	_rim = Node2D.new()
	_rim.name = "Rim"
	var reach: float = half_extent + Balance.FOG_RIM_REACH
	var shade := Color(0.02, 0.03, 0.06, Balance.FOG_UNEXPLORED_ALPHA)
	for rect: Rect2 in [Rect2(-reach, -reach, reach * 2.0, reach - half_extent),
			Rect2(-reach, half_extent, reach * 2.0, reach - half_extent),
			Rect2(-reach, -half_extent, reach - half_extent, half_extent * 2.0),
			Rect2(half_extent, -half_extent, reach - half_extent, half_extent * 2.0)]:
		var band := Polygon2D.new()
		band.polygon = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0.0),
			rect.end, rect.position + Vector2(0.0, rect.size.y)])
		band.color = shade
		_rim.add_child(band)
	add_child(_rim)
	_on = Graphics.fog_of_war()
	_veil.visible = _on
	_rim.visible = _on
	_tick()


## The fog's own texture: luminance is explored, alpha is seen now.
func texture() -> Texture2D:
	return _texture


func cells_across() -> int:
	return _across


func _index_of(at: Vector2) -> int:
	var x: int = int(floor((at.x + half_extent) / cell))
	var y: int = int(floor((at.y + half_extent) / cell))
	if x < 0 or y < 0 or x >= _across or y >= _across:
		return -1
	return y * _across + x


## Whether something of the party's can see this point now. Everything is
## seen with the fog off, so nothing downstream has to ask twice.
func sees(at: Vector2) -> bool:
	if not _on:
		return true
	var index: int = _index_of(at)
	return index >= 0 and _visible[index] >= Balance.FOG_SEEN_THRESHOLD


func explored_at(at: Vector2) -> bool:
	if not _on:
		return true
	var index: int = _index_of(at)
	return index >= 0 and _explored[index] >= Balance.FOG_SEEN_THRESHOLD


## Marks a square as already explored - known, but not currently seen.
##
## **The city's own ground is not a discovery.** A hero defending a town they
## live in should not have to walk their own four roads before they can see
## where to build, and Preparation is exactly when a player needs to read the
## whole field at once. So the authored core starts explored and the
## outskirts - the camps, the forks, the far legs, the ponds and the rift
## gates - are what the fog is actually about.
func prime_explored(half: float) -> void:
	var lo: int = maxi(_index_of(Vector2(-half, -half)), 0)
	for y: int in _across:
		var at_y: float = float(y) * cell - half_extent + cell * 0.5
		if absf(at_y) > half:
			continue
		for x: int in _across:
			var at_x: float = float(x) * cell - half_extent + cell * 0.5
			if absf(at_x) > half:
				continue
			_explored[y * _across + x] = 255
	for index: int in _explored.size():
		_bytes[index * 2] = _explored[index]
	_upload()


## Lifts the whole fog, for a tool that wants to photograph a field.
func reveal_all() -> void:
	_explored.fill(255)
	_visible.fill(255)
	_upload()


func _process(delta: float) -> void:
	_clock += delta
	if _clock < Balance.FOG_TICK:
		return
	_clock = 0.0
	var wanted: bool = Graphics.fog_of_war()
	if wanted != _on:
		_on = wanted
		_veil.visible = _on
		if _rim != null:
			_rim.visible = _on
		if not _on:
			_show_everything()
	if _on:
		_tick()


func _tick() -> void:
	_visible.fill(0)
	var found: Array = sources.call() if sources.is_valid() else []
	for source: Variant in found:
		if source is Dictionary:
			_stamp((source as Dictionary).get("at", Vector2.ZERO) as Vector2,
				float((source as Dictionary).get("radius", 0.0)))
	for index: int in _explored.size():
		var seen: int = _visible[index]
		if seen > _explored[index]:
			_explored[index] = seen
		_bytes[index * 2] = _explored[index]
		_bytes[index * 2 + 1] = seen
	_upload()
	_hide_the_unseen()


func _upload() -> void:
	if _image == null:
		return
	_image.set_data(_across, _across, false, FORMAT, _bytes)
	_texture.update(_image)


## A soft disc of sight: full inside, feathered over `FOG_FEATHER` at the rim.
func _stamp(at: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var centre: Vector2 = (at + Vector2.ONE * half_extent) / cell
	var reach: float = radius / cell
	var feather: float = maxf(Balance.FOG_FEATHER / cell, 0.25)
	var x0: int = maxi(int(floor(centre.x - reach)), 0)
	var x1: int = mini(int(ceil(centre.x + reach)), _across - 1)
	var y0: int = maxi(int(floor(centre.y - reach)), 0)
	var y1: int = mini(int(ceil(centre.y + reach)), _across - 1)
	for y: int in range(y0, y1 + 1):
		var row: int = y * _across
		for x: int in range(x0, x1 + 1):
			var away: float = Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(centre)
			var strength: float = clampf((reach - away) / feather, 0.0, 1.0)
			if strength <= 0.0:
				continue
			var value: int = int(strength * 255.0)
			if value > _visible[row + x]:
				_visible[row + x] = value


## Bodies in the fog are not drawn. Whatever this hid is remembered, so
## turning the fog off (or the body walking into sight) shows it again
## without anything else having to know the fog exists.
func _hide_the_unseen() -> void:
	var still_hidden: Array[CanvasItem] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for group: StringName in hide_groups:
		for node: Node in tree.get_nodes_in_group(group):
			var item: CanvasItem = node as CanvasItem
			if item == null or not is_instance_valid(item):
				continue
			# Not mine to hide. See `scope`.
			if scope == null or not scope.is_ancestor_of(item):
				continue
			var seen: bool = sees((item as Node2D).global_position) if item is Node2D else true
			if seen:
				if item in _hidden:
					item.visible = true
			else:
				item.visible = false
				still_hidden.append(item)
	_hidden = still_hidden
	if wildlife != null and is_instance_valid(wildlife) and wildlife.has_method("apply_fog"):
		wildlife.call("apply_fog", self)


func _show_everything() -> void:
	for item: CanvasItem in _hidden:
		if is_instance_valid(item):
			item.visible = true
	_hidden.clear()
	if wildlife != null and is_instance_valid(wildlife) and wildlife.has_method("apply_fog"):
		wildlife.call("apply_fog", null)


func _exit_tree() -> void:
	_show_everything()
