class_name RaidDressing
extends Node2D

## The war camp's furniture: tents, fires, palisades, banners, crates and
## the bones of what the camp ate, stood on the raid's floor so the place a
## raid happens in reads as somewhere the war host lives (owner brief,
## 2026-09-12: "raids need way more polish").
##
## The battlefield's camps already have this art (`Camps.PROP_FORMAT`); this
## puts it on the raid's islands and floor. Decoration, never geometry: a
## prop blocks nothing, so the cliffs and ramps the layout guarantees are the
## only walls there are. Parented to the arena's sorted layer, so the hero
## walks behind a tent and in front of a fire.
##
## A fire is the one thing here that moves: `CampFire` burns and lights.
##
## Every prop is a direct child of the sorted layer, tracked in a list:
## children of this node would sort at this node's own position, which is
## the origin, and every tent would draw under every body.

var _props: Array[Node] = []


## Furnishes `layout` with `count` props from `rng`, keeping clear of the
## arrival, the chests and the keys.
func dress(layout: RaidLayout, rng: RandomNumberGenerator, count: int,
		kinds: Array[String] = Camps.PROP_KINDS) -> void:
	for prop: Node in _props:
		if prop != null and is_instance_valid(prop):
			prop.queue_free()
	_props.clear()
	if layout == null:
		return
	var art: Dictionary = {}
	for kind: String in kinds:
		var path: String = Camps.PROP_FORMAT % kind
		if ResourceLoader.exists(path):
			art[kind] = load(path)
	if art.is_empty():
		return
	var centre := Vector2i(RaidLayout.SIZE / 2, RaidLayout.SIZE / 2)
	var floor_tiles: Array[Vector2i] = []
	for tile: Vector2i in layout.reachable_tiles():
		if layout.cell_at(tile) == RaidLayout.Cell.RAMP:
			continue
		if Vector2(tile - centre).length() < Balance.RAID_ARRIVAL_CLEARANCE + 1.0:
			continue
		floor_tiles.append(tile)
	if floor_tiles.is_empty():
		return
	var taken: Array[Vector2] = []
	for at: Vector2 in layout.chests:
		taken.append(at)
	for at: Vector2 in layout.keys:
		taken.append(at)
	var names: Array = art.keys()
	var placed: int = 0
	for _attempt: int in count * 10:
		if placed >= count:
			break
		var tile: Vector2i = floor_tiles[rng.randi_range(0, floor_tiles.size() - 1)]
		var at: Vector2 = RaidLayout.tile_to_world(tile) + Vector2(rng.randf_range(-18.0, 18.0),
			rng.randf_range(-18.0, 18.0))
		var crowded: bool = false
		for other: Vector2 in taken:
			if at.distance_to(other) < Balance.RAID_PROP_SPACING:
				crowded = true
				break
		if crowded:
			continue
		taken.append(at)
		placed += 1
		# Fires are rarer than tents, and a camp always has at least one.
		var kind: String = String(names[rng.randi_range(0, names.size() - 1)])
		if kind == "fire" and placed > 1 and rng.randf() < 0.5:
			kind = String(names[rng.randi_range(0, names.size() - 1)])
		if placed == 1 and art.has("fire"):
			kind = "fire"
		_plant(art[kind] as Texture2D, at, kind == "fire", rng)


func _plant(texture: Texture2D, at: Vector2, is_fire: bool, rng: RandomNumberGenerator) -> void:
	var prop: Sprite2D = CampFire.new() if is_fire else Sprite2D.new()
	prop.texture = texture
	prop.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	prop.add_to_group(Graphics.FILTER_GROUP)
	prop.offset = Foliage.foot_offset(texture)
	prop.position = at
	var kind: String = "fire" if is_fire else texture.resource_path.get_file().trim_prefix("camp_").get_basename()
	prop.scale = Vector2.ONE * float(Balance.CAMP_PROP_SCALE.get(kind, 1.0))
	prop.flip_h = not is_fire and rng.randf() < 0.5
	var layer: Node = get_parent() if get_parent() != null else self
	layer.add_child(prop)
	_props.append(prop)
	ShadowKit.add_contact(prop, prop)


func _exit_tree() -> void:
	for prop: Node in _props:
		if prop != null and is_instance_valid(prop):
			prop.queue_free()
	_props.clear()
