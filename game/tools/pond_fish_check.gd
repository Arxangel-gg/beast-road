extends Node

## The fish in the ponds, driven on real water.
##
## Owner brief, 2026-09-16: fish swimming with real navigation that cannot leave
## the pond and cannot draw over what they should be under, jumps that come back
## in, and a school that answers a line by luck, placement and orientation.
##
## What this holds, and why each one is the thing worth holding:
##
## - **A fish never leaves the water.** The whole navigation is one rule - look a
##   little ahead, turn toward the deepest bearing when that is shallow - and if
##   it has a hole then a fish ends up on the bank, which is the one failure
##   nobody could explain away. Driven for a full minute of swimming on every
##   region's ponds, sampling every fish every frame, because a leak that happens
##   once in a thousand frames is still a fish standing on grass.
## - **A jump comes down in the pond.** The one moment a fish is allowed out of
##   the water is also the one moment it could be left there.
## - **The school is stocked with fish that live here.** A pond showing a
##   Deepwinter Pike in the jungle is worse than an empty one: what swims past is
##   a promise about what can be landed.
## - **`claim_biter` can only hand back a fish that was in the pond**, and hands
##   back nothing when nothing came to look - which is what keeps the one
##   gameplay coupling in this system from being a second, hidden loot roll.
## - **A float on a fish's head always frightens it**, whatever else is true.
##   That is the only part of the reaction that is a rule rather than a roll, and
##   a roll is a coin toss wearing a gate's clothes.
## - **And switching it off leaves nothing running**, which is the bound every
##   decoration in this project is held to.

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	RunState.reset(false, 20260916)
	await _test_every_region_keeps_its_fish_wet()
	await _test_the_school_is_this_region_s_fish()
	await _test_a_float_on_the_head_frightens()
	await _test_the_biter_came_out_of_this_pond()
	await _test_every_fish_faces_the_way_it_is_drawn()
	await _test_a_fish_swims_the_way_it_looks()
	await _test_off_is_off()
	Sfx.stop_immediately()
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[pond-fish] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[pond-fish] PASS - %d checks: the water holds them, the jumps come back,"
		% _checked + " the school is the region's, the biter is one of them, every fish faces its heading, and off is off")
	get_tree().quit(0)


## A `Fishing` with ponds dug in a region, standing alone. No battlefield: the
## question here is about water and fish, and a whole field would bring wildlife
## that scares them and a hero that casts.
func _dug(terrain: String, seed_value: int = 424242) -> Fishing:
	RunState.set_seed(seed_value)
	RunState.terrain_id = terrain
	RunState.phase = RunState.Phase.ROAD_BATTLE
	var grid := BattleGrid.new()
	var ponds := Fishing.new()
	ponds.grid = grid
	add_child(ponds)
	await get_tree().process_frame
	ponds.scatter()
	await get_tree().process_frame
	return ponds


func _schools_of(ponds: Fishing) -> Array[PondFish]:
	var out: Array[PondFish] = []
	for node: Node in _walk(ponds):
		if node is PondFish:
			out.append(node as PondFish)
	return out


func _walk(from: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in from.get_children():
		out.append(child)
		out.append_array(_walk(child))
	return out


## **The bound.** A minute of swimming in every region, every fish read every
## frame against the pond's own depth mask.
##
## Sampled every frame rather than at the end, because the interesting failure is
## a fish that crosses a spit of dry ground and carries on swimming on the far
## side - which a reading taken afterwards would call a pass.
func _test_every_region_keeps_its_fish_wet() -> void:
	for terrain: String in ["jungle", "desert", "snow", "hollow_marches", "saltpan"]:
		var ponds: Fishing = await _dug(terrain)
		var schools: Array[PondFish] = _schools_of(ponds)
		_check(not schools.is_empty(), "%s digs ponds with fish in them" % terrain)
		var dry: int = 0
		var jumped: int = 0
		var dry_landing: int = 0
		# **The clock is driven, not waited on.** Headless, `process_frame` returns
		# as fast as the machine can go, so nine hundred of them is a fraction of
		# a second of simulated time - the first cut of this asked for "a minute
		# of swimming", got about half a second, and reported that no fish ever
		# jumps. Ticking the real `_process` with a fixed delta buys a real minute
		# and makes the reading the same on every machine.
		for _step: int in 3600:
			for school: PondFish in schools:
				school._process(1.0 / 60.0)
			for school: PondFish in schools:
				for fish: Dictionary in school.school():
					var sprite: Variant = fish["sprite"]
					if sprite == null or not is_instance_valid(sprite as Object):
						continue
					var at: Vector2 = (sprite as Sprite2D).position
					if int(fish["state"]) == PondFish.State.JUMPING:
						jumped += 1
						# Where it is going matters; where it is mid-arc does not.
						if school.wet_at(fish["jump_to"] as Vector2) <= 0.0:
							dry_landing += 1
						continue
					if school.wet_at(at) <= 0.0:
						dry += 1
		_check(dry == 0, "%s: a fish was on dry ground on %d frames" % [terrain, dry])
		_check(dry_landing == 0,
			"%s: %d jumps were aimed at dry ground" % [terrain, dry_landing])
		_check(jumped > 0, "%s: no fish jumped in a minute of swimming" % terrain)
		ponds.queue_free()
		await get_tree().process_frame


## What swims past is a promise about what can be landed, so it has to be a fish
## that actually lives in this water.
func _test_the_school_is_this_region_s_fish() -> void:
	for terrain: String in ["jungle", "snow"]:
		var ponds: Fishing = await _dug(terrain)
		var strangers: int = 0
		var counted: int = 0
		for school: PondFish in _schools_of(ponds):
			for fish: Dictionary in school.school():
				counted += 1
				if not (fish["kind"] as FishData).lives_in(terrain):
					strangers += 1
		_check(counted > 0, "%s stocked %d fish" % [terrain, counted])
		_check(strangers == 0,
			"%s: %d fish in the water do not live there" % [terrain, strangers])
		ponds.queue_free()
		await get_tree().process_frame


## The one part of the reaction that is a rule rather than a roll. Everything
## else here is a chance, and a gate that asserts a chance is a coin toss.
func _test_a_float_on_the_head_frightens() -> void:
	var ponds: Fishing = await _dug("jungle")
	var schools: Array[PondFish] = _schools_of(ponds)
	_check(not schools.is_empty(), "there is a school to frighten")
	var frightened: int = 0
	var asked: int = 0
	for school: PondFish in schools:
		for fish: Dictionary in school.school():
			var sprite: Variant = fish["sprite"]
			if sprite == null or not is_instance_valid(sprite as Object):
				continue
			if int(fish["state"]) == PondFish.State.JUMPING:
				continue
			asked += 1
			# Right on top of it: inside `POND_FISH_ON_ITS_HEAD` there is no roll.
			school.line_landed((sprite as Sprite2D).position, 1.0)
			if int(fish["state"]) == PondFish.State.STARTLED:
				frightened += 1
	_check(asked > 0, "there were fish to drop a float on (%d)" % asked)
	_check(frightened == asked,
		"a float on the head frightened %d of %d - it must frighten every one" % [frightened, asked])
	# And a float on the far side of the world is not noticed at all.
	var far_curious: int = 0
	for school: PondFish in schools:
		far_curious += school.line_landed(Vector2(90000.0, 90000.0), 1.0)
	_check(far_curious == 0, "a float nowhere near the water interested %d fish" % far_curious)
	ponds.queue_free()
	await get_tree().process_frame


## The one thing about the school that gameplay reads, held at both ends: it
## hands back nothing when nothing came to look, and what it does hand back was
## in this pond.
func _test_the_biter_came_out_of_this_pond() -> void:
	var ponds: Fishing = await _dug("jungle")
	for school: PondFish in _schools_of(ponds):
		var held: Array[String] = []
		for fish: Dictionary in school.school():
			held.append((fish["kind"] as FishData).id)
		if held.is_empty():
			continue
		# Nothing is curious yet, so nothing may be claimed however close the
		# float is - otherwise this would be a second loot roll behind a ripple.
		var before: int = school.count()
		_check(school.claim_biter(Vector2.ZERO) == null,
			"a float with nothing interested in it claimed a fish")
		_check(school.count() == before, "and the school is the size it was")
		# Now interest one, by dropping the float where it is looking.
		var first: Dictionary = school.school()[0]
		var body := first["sprite"] as Sprite2D
		first["state"] = PondFish.State.CURIOUS
		var caught: FishData = school.claim_biter(body.position)
		_check(caught != null, "a fish at the float is the fish on the hook")
		if caught != null:
			_check(held.has(caught.id),
				"the fish on the hook (%s) was one of the fish in the pond" % caught.id)
			_check(school.count() == before - 1, "and it is out of the water now")
	ponds.queue_free()
	await get_tree().process_frame


## Decoration is decoration: switched off it draws nothing and costs nothing.
func _test_off_is_off() -> void:
	Graphics.set_switch(Graphics.KEY_POND_FISH, false)
	var ponds: Fishing = await _dug("jungle")
	var schools: Array[PondFish] = _schools_of(ponds)
	_check(not schools.is_empty(), "the ponds still have schools when it is off")
	var moved: int = 0
	var before: Array[Vector2] = []
	for school: PondFish in schools:
		_check(not school.visible, "the school is not drawn")
		for fish: Dictionary in school.school():
			before.append((fish["sprite"] as Sprite2D).position)
	for _step: int in 600:
		for school: PondFish in schools:
			school._process(1.0 / 60.0)
	var index: int = 0
	for school: PondFish in schools:
		for fish: Dictionary in school.school():
			if index < before.size() \
					and (fish["sprite"] as Sprite2D).position.distance_to(before[index]) > 0.01:
				moved += 1
			index += 1
	_check(moved == 0, "%d fish kept swimming with the setting off" % moved)
	Graphics.set_switch(Graphics.KEY_POND_FISH, true)
	ponds.queue_free()
	await get_tree().process_frame


## **Which way every painted fish faces**, read off a contact sheet of the whole
## roster on 2026-09-16 and kept here so it can never quietly drift.
##
## This is the third time this project has needed a ledger like this - the
## enemies have one and the wildlife have one - and it is for the same reason
## both times: a facing flag is only ever wrong in a way a person has to *look*
## at. Nothing measurable changes, no gate fails, the fish simply swims
## backwards. So the roster is written down, and a fish that is added or
## redrawn without somebody reading its painting fails by name.
##
## Every one of the eleven is drawn head-left, which is why `art_faces_right`
## defaults to false; the Sunglass Ray is a top view and is not mirrored at all.
const FACINGS: Dictionary = {
	"chainmaker_koi": "left", "deepwinter_pike": "left", "frostgill_char": "left",
	"glasshead_dace": "left", "greenback_perch": "left", "mirebell_eel": "left",
	"roadkeeper_carp": "left", "saltglass_bream": "left", "silt_minnow": "left",
	"sunglass_ray": "top_down", "white_teeth_trout": "left",
}


## The ledger against the data, both ways: every fish in the game is recorded,
## and every recorded facing is what the resource actually carries.
func _test_every_fish_faces_the_way_it_is_drawn() -> void:
	var seen: Dictionary = {}
	for kind: FishData in ContentDB.fish_sorted():
		seen[kind.id] = true
		_check(FACINGS.has(kind.id),
			"%s is not in the facing ledger - read its art and record it" % kind.id)
		if not FACINGS.has(kind.id):
			continue
		var recorded: String = String(FACINGS[kind.id])
		var carried: String = "top_down" if kind.art_top_down 			else ("right" if kind.art_faces_right else "left")
		_check(recorded == carried,
			"%s is recorded as facing %s and is authored %s" % [kind.id, recorded, carried])
	for id: Variant in FACINGS:
		_check(seen.has(id), "the ledger records %s, which is not a fish any more" % id)


## And the flag is *read*: a fish swimming left is drawn looking left.
##
## Driven rather than asserted - the heading is set and `_dress` is the real one,
## because a ledger that agrees with the data proves only that two files agree.
func _test_a_fish_swims_the_way_it_looks() -> void:
	var ponds: Fishing = await _dug("jungle")
	var backwards: int = 0
	var read: int = 0
	for school: PondFish in _schools_of(ponds):
		for fish: Dictionary in school.school():
			var kind := fish["kind"] as FishData
			if kind.art_top_down:
				continue
			var sprite := fish["sprite"] as Sprite2D
			for going: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
				fish["heading"] = going
				school.dress(fish)
				read += 1
				# What the player sees pointing forward: the art's own direction,
				# mirrored or not.
				var looks_right: bool = sprite.flip_h != kind.art_faces_right
				if looks_right != (going.x > 0.0):
					backwards += 1
	_check(read > 0, "there were fish to turn (%d readings)" % read)
	_check(backwards == 0,
		"%d of %d fish were drawn facing away from where they were swimming" % [backwards, read])
	ponds.queue_free()
	await get_tree().process_frame



func _check(passed: bool, what: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[pond-fish] %s" % what)
