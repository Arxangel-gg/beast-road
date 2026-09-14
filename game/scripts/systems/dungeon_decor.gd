class_name DungeonDecor
extends Node2D

## What a rift's floor is dressed with beyond the camp's own props
## (2026-09-14): sconces on the walls, rubble and puddles on a dungeon's
## flagstones, crystal and stalagmite in a rift's cavern, and the rune circle
## on the vault's floor that wakes as the rift fills.
##
## Decoration, never geometry, exactly as `RaidDressing`: a prop blocks
## nothing, the flow field and `can_step` know nothing about it, and the
## runes are a picture of the fill rather than a reading of it - the player
## is told the guardian is near by the floor glowing, not by a number.
##
## Standing props are planted straight into the sorted layer (this node's
## parent), so a body walks behind a stalagmite and in front of a puddle; the
## flat pieces are children of this node one z-layer under the units, which is
## where the contact shadows already live.

const ART_FORMAT: String = "res://art/raid/%s.png"
const RUNES_FORMAT: String = "res://art/raid/dungeon_runes_%s.png"
## The floor pieces a kind is dressed with, and which of them lie flat.
const PIECES: Dictionary = {
	RiftArena.Kind.DUNGEON: ["dungeon_rubble", "dungeon_puddle", "dungeon_rubble"],
	RiftArena.Kind.RIFT: ["dungeon_crystals", "dungeon_stalagmite", "dungeon_rubble"],
}
const FLAT: Array[String] = ["dungeon_rubble", "dungeon_puddle"]
const GLOWING: Array[String] = ["dungeon_crystals"]

var arena: RiftArena = null

var _planted: Array[Node] = []
var _sconces: Array[DungeonSconce] = []
var _decals: Array[Sprite2D] = []
var _glows: Array[Sprite2D] = []
var _runes: Sprite2D = null
var _runes_glow: Sprite2D = null
var _runes_at: Vector2 = Vector2.ZERO
var _clock: float = 0.0
var _woke: float = 0.0


## Dresses `layout` for a rift of `kind`, from `rng`.
func dress(layout: DungeonLayout, kind: int, rng: RandomNumberGenerator) -> void:
	sweep()
	if layout == null:
		return
	_plant_sconces(layout, kind, rng)
	_plant_pieces(layout, kind, rng)
	_plant_runes(layout, kind)


## The floor glowing: the guardian has stepped through.
func wake() -> void:
	_woke = 1.0
	if _runes != null:
		Vfx.ring(_runes.global_position, 150.0, _runes_tint(), 0.9, 5.0)


func sweep() -> void:
	for node: Node in _planted:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_planted.clear()
	_sconces.clear()
	_decals.clear()
	_glows.clear()
	_runes = null
	_runes_glow = null
	_woke = 0.0


func sconces() -> Array[DungeonSconce]:
	return _sconces


func sconce_count() -> int:
	return _sconces.size()


func decals() -> Array[Sprite2D]:
	return _decals


func decal_count() -> int:
	return _decals.size()


func runes_at() -> Vector2:
	return _runes_at


func has_runes() -> bool:
	return _runes != null


func _process(delta: float) -> void:
	_clock += delta
	_woke = maxf(_woke - delta * 0.6, 0.0)
	var fill: float = arena.fill() if arena != null else 0.0
	if _runes != null:
		# Faint until the rift fills, breathing harder as it does, and full
		# for a beat when the guardian comes.
		var breath: float = 0.5 + 0.5 * sin(_clock * (1.2 + 2.4 * fill))
		var glow: float = clampf(0.28 + 0.62 * fill * (0.55 + 0.45 * breath) + _woke, 0.0, 1.0)
		_runes.modulate.a = glow
		if _runes_glow != null:
			_runes_glow.modulate.a = 0.35 * glow
			_runes_glow.scale = Vector2.ONE * (_runes_glow_scale() * (0.9 + 0.2 * breath + 0.3 * _woke))
	for index: int in _glows.size():
		var glow_sprite: Sprite2D = _glows[index]
		if glow_sprite != null and is_instance_valid(glow_sprite):
			glow_sprite.modulate.a = 0.28 + 0.14 * sin(_clock * 1.7 + float(index) * 1.3)


# --- Sconces --------------------------------------------------------------------------

## Every wall tile with floor directly south is a face a bracket can hang on;
## one every `DUNGEON_SCONCE_EVERY` tiles along them, spread by the dice,
## never more than `DUNGEON_SCONCE_MAX`, and every `DUNGEON_SCONCE_LIGHT_EVERY`-th
## carrying a real light.
func _plant_sconces(layout: DungeonLayout, kind: int, rng: RandomNumberGenerator) -> void:
	var faces: Array = []
	for y: int in RaidLayout.SIZE - 1:
		for x: int in RaidLayout.SIZE:
			var tile := Vector2i(x, y)
			if layout.cell_at(tile) != RaidLayout.Cell.WALL:
				continue
			if layout.cell_at(tile + Vector2i(0, 1)) != RaidLayout.Cell.OPEN:
				continue
			faces.append(tile)
	_shuffle(faces, rng)
	var taken: Array[Vector2i] = []
	var layer: Node = get_parent() if get_parent() != null else self
	var colour: Color = Balance.RIFT_SCONCE_COLOUR if kind == RiftArena.Kind.RIFT \
		else Balance.DUNGEON_SCONCE_COLOUR
	for face: Vector2i in faces:
		if taken.size() >= Balance.DUNGEON_SCONCE_MAX:
			break
		var crowded: bool = false
		for other: Vector2i in taken:
			if maxi(absi(other.x - face.x), absi(other.y - face.y)) < Balance.DUNGEON_SCONCE_EVERY:
				crowded = true
				break
		if crowded:
			continue
		taken.append(face)
		var sconce := DungeonSconce.new()
		sconce.name = "Sconce%d" % taken.size()
		sconce.colour = colour
		sconce.carries_light = (taken.size() - 1) % Balance.DUNGEON_SCONCE_LIGHT_EVERY == 0
		sconce.position = RaidLayout.tile_to_world(face) \
			+ Vector2(rng.randf_range(-10.0, 10.0), RaidLayout.TILE * 0.5)
		layer.add_child(sconce)
		_planted.append(sconce)
		_sconces.append(sconce)


# --- The floor ---------------------------------------------------------------------

func _plant_pieces(layout: DungeonLayout, kind: int, rng: RandomNumberGenerator) -> void:
	var names: Array = PIECES.get(kind, PIECES[RiftArena.Kind.DUNGEON])
	var art: Dictionary = {}
	for piece: String in names:
		var path: String = ART_FORMAT % piece
		if ResourceLoader.exists(path) and not art.has(piece):
			art[piece] = load(path)
	if art.is_empty():
		return
	var candidates: Array = []
	for tile: Vector2i in layout.open_tiles():
		if maxi(absi(tile.x - layout.entry.x), absi(tile.y - layout.entry.y)) < 3:
			continue
		if maxi(absi(tile.x - layout.deep.x), absi(tile.y - layout.deep.y)) < 2:
			continue
		candidates.append(tile)
	_shuffle(candidates, rng)
	var taken: Array[Vector2i] = []
	var layer: Node = get_parent() if get_parent() != null else self
	for tile: Vector2i in candidates:
		if taken.size() >= Balance.DUNGEON_DECAL_COUNT:
			break
		var crowded: bool = false
		for other: Vector2i in taken:
			if maxi(absi(other.x - tile.x), absi(other.y - tile.y)) < 2:
				crowded = true
				break
		if crowded:
			continue
		taken.append(tile)
		var piece: String = String(names[rng.randi_range(0, names.size() - 1)])
		if not art.has(piece):
			continue
		var texture: Texture2D = art[piece] as Texture2D
		var at: Vector2 = RaidLayout.tile_to_world(tile) \
			+ Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-14.0, 14.0))
		var sprite := Sprite2D.new()
		sprite.name = piece.trim_prefix("dungeon_").capitalize() + str(taken.size())
		sprite.texture = texture
		sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
		sprite.add_to_group(Graphics.FILTER_GROUP)
		sprite.flip_h = rng.randf() < 0.5
		if FLAT.has(piece):
			# Flat on the floor, under everything that walks.
			sprite.position = at
			sprite.z_index = -1
			sprite.z_as_relative = true
			add_child(sprite)
			_decals.append(sprite)
		else:
			sprite.offset = Foliage.foot_offset(texture)
			sprite.position = at
			layer.add_child(sprite)
			ShadowKit.add_contact(sprite, sprite)
			_decals.append(sprite)
			if GLOWING.has(piece):
				var glow := Sprite2D.new()
				glow.name = "Glow"
				glow.texture = LightKit.falloff_texture()
				var additive := CanvasItemMaterial.new()
				additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				glow.material = additive
				glow.modulate = Color(0.7, 0.45, 1.0, 0.3)
				glow.scale = Vector2.ONE * (150.0 / maxf(float(glow.texture.get_width()), 1.0))
				glow.position = Vector2(0.0, -float(texture.get_height()) * 0.35)
				glow.z_index = -1
				glow.z_as_relative = true
				sprite.add_child(glow)
				_glows.append(glow)
		_planted.append(sprite)


# --- The vault -------------------------------------------------------------------------

func _plant_runes(layout: DungeonLayout, kind: int) -> void:
	var path: String = RUNES_FORMAT % ("rift" if kind == RiftArena.Kind.RIFT else "dungeon")
	_runes_at = RaidLayout.tile_to_world(layout.deep)
	if not ResourceLoader.exists(path):
		return
	_runes = Sprite2D.new()
	_runes.name = "Runes"
	_runes.texture = load(path)
	_runes.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_runes.add_to_group(Graphics.FILTER_GROUP)
	_runes.scale = Vector2.ONE * Balance.DUNGEON_RUNES_SCALE
	_runes.position = _runes_at
	_runes.modulate = Color(1.0, 1.0, 1.0, 0.28)
	_runes.z_index = -1
	_runes.z_as_relative = true
	add_child(_runes)
	_planted.append(_runes)
	_runes_glow = Sprite2D.new()
	_runes_glow.name = "RunesGlow"
	_runes_glow.texture = LightKit.falloff_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_runes_glow.material = additive
	_runes_glow.modulate = Color(_runes_tint(), 0.1)
	_runes_glow.scale = Vector2.ONE * _runes_glow_scale()
	_runes_glow.position = _runes_at
	_runes_glow.z_index = -1
	_runes_glow.z_as_relative = true
	add_child(_runes_glow)
	_planted.append(_runes_glow)


func _runes_tint() -> Color:
	return Color(0.85, 0.5, 1.0) if arena != null and arena.kind == RiftArena.Kind.RIFT \
		else Color(1.0, 0.6, 0.25)


func _runes_glow_scale() -> float:
	var across: float = maxf(float(LightKit.falloff_texture().get_width()), 1.0)
	return 128.0 * Balance.DUNGEON_RUNES_SCALE * 1.6 / across


## Fisher-Yates on the given dice, so the dressing moves no roll on any
## stream that matters.
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var held: Variant = items[i]
		items[i] = items[j]
		items[j] = held


func _exit_tree() -> void:
	sweep()
