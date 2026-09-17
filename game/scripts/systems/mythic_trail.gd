class_name MythicTrail
extends Node2D

## Evidence, then tracking, then the thing itself.
##
## **Owner brief, 2026-09-15** (forwarded proposal, triaged in
## `docs/IDEAS_REVIEW_2026-09-15.md`): mythical wildlife, found by following
## what they leave behind rather than by meeting them on the road. The review's
## conclusion was that the best idea in a document of 112 creatures is not a
## creature: it is the trail, because a creature you simply walk into is a
## bigger boar.
##
## **What this is.** Once a run reaches the act a mythic belongs to, its first
## sign is laid somewhere in the outskirts. Walking near a sign reads it - no
## button, because a trail you have to press a key at is an errand rather than
## something you noticed - and the next sign is laid further out and roughly
## onward, so the trail *leads*. At the end of it the animal is there.
##
## **What this is not.** It decides where and when a mythic appears and nothing
## else. A mythic is an ordinary `WildlifeData` in every other respect: the same
## rarity ladder, the same rank sheen, the same population cap, the same wrath
## for killing it, the same bond. `IDEAS_REVIEW` settled that Mythic is a
## *classification* rather than a sixth rarity, and this is where that decision
## is cashed - `WildlifeData.mythic` keeps a species out of the random scatter,
## and this puts it on the field instead.
##
## **Seeded, so co-op needs no new wire.** Where every sign of every trail falls
## is drawn from the run's own seed, exactly as the ponds, the gather nodes and
## the farm plots are - "both machines dig the same ponds and neither is told
## about them". Reading one is a *position* test against heroes both machines
## already mirror, so both reach the same stage at the same moment without a
## packet. Only the animal itself crosses the wire, and it does that as ordinary
## wildlife through `coop_wildlife_spawned`, which already exists.
##
## **Nothing persists.** A trail is the run's, like a relic socket and an omen.

## The signs laid so far: each a Dictionary of the sign data, its node and where
## it stands.
var _signs: Array[Dictionary] = []
## Which species is being tracked this run, and how far along we are.
var _quarry: WildlifeData = null
var _stage: int = 0
## Where the last sign stood and which way the trail is heading, so it leads
## rather than scattering.
var _from: Vector2 = Vector2.ZERO
var _heading: Vector2 = Vector2.RIGHT
## True once the animal has been placed, so a trail is walked once.
var _found: bool = false

var grid: BattleGrid = null
var animals: Wildlife = null

var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_as_relative = false
	set_process(true)


## Lay the first sign for the act, if any mythic belongs to it.
##
## Called from `Battlefield.refresh_terrain`, which is the one function
## everything regional goes through - the list a gather node was once left out
## of, and a treeline was never in at all.
func scatter() -> void:
	_clear()
	if grid == null:
		return
	_rng.seed = RunState.run_seed * 7919 + hash("trail:%d" % RunState.act)
	_quarry = _choose()
	if _quarry == null:
		return
	_stage = 0
	_found = false
	# The trail starts far out and heads further out: the wilds are where a
	# thing that does not want to be found lives, and it is the same ground the
	# rare gather nodes and the rift gates use.
	_from = _far_point(Vector2.ZERO, Balance.TRAIL_FIRST_DISTANCE)
	_heading = _from.normalized() if _from.length() > 1.0 else Vector2.RIGHT
	_lay(_from)


## Which mythic this act is about, or null.
##
## One at a time and one a run: a road with three legends on it has none.
func _choose() -> WildlifeData:
	var ready: Array[WildlifeData] = []
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind == null or not kind.mythic:
			continue
		if RunState.act < kind.trail_first_act:
			continue
		if kind.trail_signs.is_empty():
			continue
		ready.append(kind)
	if ready.is_empty():
		return null
	ready.sort_custom(func(a: WildlifeData, b: WildlifeData) -> bool:
		return a.id < b.id)
	return ready[_rng.randi() % ready.size()]


## One sign on the ground, and the line that comes with it.
func _lay(at: Vector2) -> void:
	if _quarry == null:
		return
	var kind: TrailSignData = _sign_for(_stage)
	if kind == null:
		# A trail with no sign for this stage ends here rather than hanging: the
		# animal arrives, which is the honest failure. `mythic_trail_check`
		# refuses a species whose stages have holes in them, so this is the
		# belt rather than the braces.
		_arrive()
		return
	var art: Texture2D = load(kind.get_sprite_path()) as Texture2D if \
		ResourceLoader.exists(kind.get_sprite_path()) else null
	var mark := Sprite2D.new()
	mark.texture = art
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.scale = Vector2.ONE * kind.scale
	mark.global_position = at
	mark.z_as_relative = false
	mark.modulate.a = 0.0
	add_child(mark)
	# Found rather than announced: it fades up as the fog uncovers it, which is
	# what makes it read as something that was already there.
	var fade := create_tween()
	fade.tween_property(mark, "modulate:a", 1.0, Balance.TRAIL_SIGN_FADE)
	_signs.append({"data": kind, "node": mark, "at": at, "read": false})


## The sign for a stage of this species' trail.
func _sign_for(stage: int) -> TrailSignData:
	var choices: Array[TrailSignData] = []
	for id: String in _quarry.trail_signs:
		var kind := ContentDB.trail_signs.get(id, null) as TrailSignData
		if kind != null and kind.suits(_quarry.id, stage):
			choices.append(kind)
	if choices.is_empty():
		return null
	choices.sort_custom(func(a: TrailSignData, b: TrailSignData) -> bool:
		return a.id < b.id)
	return choices[_rng.randi() % choices.size()]


func _process(delta: float) -> void:
	if _quarry == null or _found or _signs.is_empty():
		return
	_clock += delta
	if _clock < Balance.TRAIL_LOOK_INTERVAL:
		return
	_clock = 0.0
	var last: Dictionary = _signs[_signs.size() - 1]
	if bool(last["read"]):
		return
	if not _somebody_is_near(last["at"] as Vector2):
		return
	last["read"] = true
	_read(last)


## Whether any hero is close enough to see it.
##
## **Any hero, not the local one.** Both machines mirror both positions, so both
## reach the same verdict on the same frame and the trail advances together
## without a packet - the reasoning `Enemy._pick_target` already uses for
## `nearest_foe`.
func _somebody_is_near(at: Vector2) -> bool:
	var field := get_parent() as Battlefield
	if field == null:
		return false
	for who: Hero in field.heroes():
		if who != null and is_instance_valid(who) and who.is_alive() \
				and who.global_position.distance_to(at) <= Balance.TRAIL_READ_RADIUS:
			return true
	return false


## A sign is read: it is said, it is marked, and the trail goes on.
func _read(sign: Dictionary) -> void:
	var kind := sign["data"] as TrailSignData
	if kind != null:
		# The same door the earth's own signs use, so a trail reads like the
		# world telling you something rather than like a quest log.
		EventBus.sky_warned.emit(kind.reading, kind.display_name)
		# Its own recording rather than the interface's chime: a sign is read out
		# on the road, at a place, and `sfx_wildlife_trail_sign` was registered
		# and reached by nothing.
		var node_at := sign.get("node") as Node2D
		if node_at != null and is_instance_valid(node_at):
			Sfx.play_group_at("sfx_wildlife_trail_sign", node_at.global_position, -3.0)
		else:
			Sfx.play_group("sfx_wildlife_trail_sign", -3.0)
	var node := sign.get("node") as Node2D
	if node != null and is_instance_valid(node):
		# It stays on the ground - a trail you can look back along is a trail -
		# but it dims, so the next one is the bright thing.
		var dim := create_tween()
		dim.tween_property(node, "modulate:a", Balance.TRAIL_SIGN_SPENT, 0.6)
	_stage += 1
	if _stage >= Balance.TRAIL_LENGTH:
		_arrive()
		return
	# Onward: further out, and within a wedge of the way it was already going,
	# so the trail leads somewhere rather than scattering.
	_heading = _heading.rotated(_rng.randf_range(-Balance.TRAIL_TURN,
		Balance.TRAIL_TURN))
	var want: Vector2 = _from + _heading * Balance.TRAIL_STEP
	_from = _far_point(want, Balance.TRAIL_FIRST_DISTANCE)
	_lay(_from)


## The animal, at the end of its own trail.
func _arrive() -> void:
	_found = true
	if _quarry == null or animals == null:
		return
	# **The host places it, as it places every animal.** A guest draws what it
	# is told; if it spawned its own the two machines would hold two legends.
	if Coop.is_guest():
		return
	animals.place_mythic(_quarry, _from + _heading * Balance.TRAIL_STEP * 0.5)


## Somewhere out in the wilds, near a wanted point, on open ground.
##
## Drawn from the band's open tiles rather than from a polar throw: open ground
## out there is four corner pockets, and a random point in the outer band lands
## on one about once in five hundred tries.
func _far_point(near: Vector2, least: float) -> Vector2:
	var tiles: Array[Vector2i] = Fishing.band_tiles(grid, 0.0)
	if tiles.is_empty():
		return near
	var best: Vector2 = BattleGrid.tile_to_world(tiles[0])
	var closest: float = INF
	# A sample rather than a sort: the band holds a few hundred tiles and this
	# runs five times a run.
	for _try: int in Balance.TRAIL_PLACEMENT_TRIES:
		var at: Vector2 = BattleGrid.tile_to_world(
			tiles[_rng.randi() % tiles.size()])
		if at.length() < least:
			continue
		var gap: float = at.distance_to(near)
		if gap < closest:
			closest = gap
			best = at
	return best


func _clear() -> void:
	for sign: Dictionary in _signs:
		var node: Node = sign.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_signs.clear()
	_quarry = null
	_stage = 0
	_found = false


## What is being tracked, how far along, and where the signs are. For the gate
## and for the map, which marks a sign the party has found.
func report() -> Dictionary:
	var places: Array[Vector2] = []
	for sign: Dictionary in _signs:
		places.append(sign["at"] as Vector2)
	return {
		"quarry": _quarry.id if _quarry != null else "",
		"stage": _stage,
		"signs": places,
		"found": _found,
	}


## Advance the trail by hand. For the gate, which has no hero to walk.
func read_the_next_sign() -> bool:
	if _signs.is_empty() or _found:
		return false
	var last: Dictionary = _signs[_signs.size() - 1]
	if bool(last["read"]):
		return false
	last["read"] = true
	_read(last)
	return true
