class_name DeathMarkers
extends Node2D

## Where the players fell (owner brief, 2026-09-14).
##
## One stone falls where a hero collapsed and stands while they need recovery;
## when they are up it dissolves. Their remains stay on that spot until the act
## ends - scenery, with no prompt and no glow. Solo deaths, co-op downs, the
## solo clock, a partner's revive and a team wipe all arrive through the same
## door, because this **watches the heroes rather than listening for a
## message**: every frame, each hero in this scope is either standing or not,
## and a change is a fall or a rise. That is what makes the identity stable -
## a hero has at most one stone, so no packet, replay or double signal can
## plant a second - and what makes it work in every scope: the field owns one
## and each arena owns one, and each watches only the heroes under it, so a
## death in a dungeon marks the dungeon and never the road above it.
##
## Nothing here is read by the game and nothing persists. In co-op each machine
## draws its own stones from the downs it already mirrors; nothing crosses the
## wire for this.

const BONES_ART: String = "res://art/vfx/death_bones.png"

## The scope whose heroes this watches. Set by the owner before adding.
var scope: Node = null

## Hero instance id -> DeathStone, while that hero is down.
var _stones: Dictionary = {}
## Hero instance id -> whether it stood last frame.
var _standing: Dictionary = {}
## Every remains decal laid this act.
var _bones: Array[Sprite2D] = []
## Every marker position laid this act, for the overlap rule.
var _spots: Array[Vector2] = []


func _ready() -> void:
	name = "DeathMarkers"
	y_sort_enabled = true
	EventBus.act_started.connect(_on_act_started)


func _process(_delta: float) -> void:
	for hero: Hero in _heroes():
		var id: int = hero.get_instance_id()
		var alive: bool = hero.is_alive()
		var was: bool = bool(_standing.get(id, true))
		_standing[id] = alive
		if was and not alive:
			_fall(hero)
		elif alive and not was:
			_rise(hero)


## The heroes this scope owns: every hero in play under it. A hero in another
## scope's tree - the arena's own while the field waits, or the field's while
## a rift is fought - belongs to the other scope's markers.
func _heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	var root: Node = scope if scope != null else get_parent()
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero != null and root != null and root.is_ancestor_of(hero):
			out.append(hero)
	# A hero that stepped out of play while down (a raid taken from the floor
	# is refused, but a scope change is not) still owns its stone.
	for id: Variant in _stones.keys():
		var hero: Hero = instance_from_id(int(id)) as Hero
		if hero != null and is_instance_valid(hero) and not out.has(hero):
			out.append(hero)
	return out


## A hero went down: one stone, and the remains, at the spot they fell -
## nudged aside if another marker already lies there, so two deaths on one
## tile read as two.
func _fall(hero: Hero) -> void:
	var id: int = hero.get_instance_id()
	if _stones.has(id):
		return
	var at: Vector2 = _clear_spot(hero.global_position)
	var drowned: bool = hero.has_method("is_drowned") and hero.is_drowned()
	var stone := DeathStone.new()
	stone.drowned = drowned
	add_child(stone)
	stone.global_position = at
	_stones[id] = stone
	_spots.append(at)
	if not drowned:
		_lay_bones(at)


## The hero is up. The stone goes; the bones stay.
func _rise(hero: Hero) -> void:
	var id: int = hero.get_instance_id()
	var stone: DeathStone = _stones.get(id, null) as DeathStone
	_stones.erase(id)
	if stone != null and is_instance_valid(stone):
		stone.dissolve()


func _lay_bones(at: Vector2) -> void:
	if not ResourceLoader.exists(BONES_ART):
		return
	var bones := Sprite2D.new()
	bones.texture = load(BONES_ART) as Texture2D
	bones.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	bones.add_to_group(Graphics.FILTER_GROUP)
	# Ground, not a body: under everything that walks, above the terrain.
	bones.z_index = -1
	bones.z_as_relative = true
	bones.modulate = Color(1.0, 1.0, 1.0, Balance.DEATH_BONES_ALPHA)
	bones.scale = Vector2(1.0 if randf() < 0.5 else -1.0, 1.0)
	add_child(bones)
	bones.global_position = at + Vector2(0.0, -8.0)
	_bones.append(bones)


## A place near `at` that no marker of this act already occupies.
func _clear_spot(at: Vector2) -> Vector2:
	var spot: Vector2 = at
	var tries: int = 0
	while tries < 6 and _spots.any(func(other: Vector2) -> bool:
			return other.distance_to(spot) < Balance.DEATH_MARKER_OVERLAP):
		tries += 1
		spot = at + Vector2(Balance.DEATH_MARKER_OVERLAP * float(tries), 0.0) \
			* (1.0 if tries % 2 == 1 else -1.0)
	return spot


## The act ends: the remains go with it. Stones stay - a hero down when the
## road moves on is still down.
func _on_act_started(_act: int, _terrain: String) -> void:
	clear_bones()


func clear_bones() -> void:
	for bones: Sprite2D in _bones:
		if is_instance_valid(bones):
			bones.queue_free()
	_bones.clear()
	_spots.clear()
	for id: Variant in _stones:
		var stone: DeathStone = _stones[id] as DeathStone
		if stone != null and is_instance_valid(stone):
			_spots.append(stone.global_position)


# --- For the gate ---------------------------------------------------------------

func stone_for(hero: Hero) -> DeathStone:
	if hero == null:
		return null
	return _stones.get(hero.get_instance_id(), null) as DeathStone


func stone_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is DeathStone and is_instance_valid(child) and not child.is_queued_for_deletion():
			count += 1
	return count


func bones_count() -> int:
	var count: int = 0
	for bones: Sprite2D in _bones:
		if is_instance_valid(bones) and not bones.is_queued_for_deletion():
			count += 1
	return count


func bones_positions() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for bones: Sprite2D in _bones:
		if is_instance_valid(bones):
			out.append(bones.global_position)
	return out
