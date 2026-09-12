extends Node

## Ponds, what comes out of them, the skill it takes, and the two bounds the
## system rests on.
##
## Fishing is the first thing in this project that lets a **consumable** survive
## a run, which is an amendment to working rule 7. The amendment is recorded in
## CLAUDE.md and its bound is `Balance.FISH_MEALS_PER_RUN`: the pantry persists,
## the appetite does not. If that cap ever stops being enforced, a player with a
## full larder cannot be killed and the wounds, the Tonic and the whole recovery
## economy become decoration - so it is asserted here first and hardest.
##
## The second cut (2026-09-11) added the Angler, the first profession, and its
## bound is the other thing held here: **a profession touches nothing but its
## own craft**. A maxed Angler fishes better and fights exactly as they did.
##
## The rest is the road a catch travels - cast, wait, hook, reel - driven
## through the real `Fishing` with a scripted input, because the owner's report
## on the first cut was that the automatic version "did not happen", and a gate
## that called the landing function directly would have passed on that build.

var _failures: int = 0
var _ran: int = 0
var _caught: Array[String] = []
var _failed_reasons: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260911)
	RunState.phase = RunState.Phase.ROAD_BATTLE
	EventBus.fish_caught.connect(func(fish_id: String, _food: int) -> void:
		_caught.append(fish_id))
	EventBus.fishing_failed.connect(func(reason: String) -> void:
		_failed_reasons.append(reason))

	_test_every_fish_is_real()
	_test_no_fish_grants_power()
	await _test_ponds_sit_at_the_edge_off_the_roads_in_every_region()
	await _test_the_same_seed_digs_the_same_ponds()
	await _test_a_catch_is_cast_hooked_and_reeled()
	await _test_a_slack_or_snapped_line_pays_nothing()
	_test_the_angler_only_fishes()
	_test_the_meal_cap_holds()
	_test_the_pantry_survives_a_round_trip()

	Sfx.stop_immediately()
	Vfx.clear()
	for _f: int in 10:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[fishing] FAIL - %d problem(s) across %d tests" % [_failures, _ran])
		get_tree().quit(1)
		return
	print("[fishing] PASS - %d tests: ponds, the cast, the reel, the Angler, the meal cap and the pantry"
		% _ran)
	get_tree().quit(0)


## Every authored fish is complete, drawn, and reachable from somewhere.
func _test_every_fish_is_real() -> void:
	var roster: Array[FishData] = ContentDB.fish_sorted()
	_check(roster.size() >= 6, "the ponds need a roster; found %d" % roster.size())
	var terrains: Array[String] = []
	for value: Variant in ContentDB.terrains.values():
		var region := value as TerrainData
		if region != null:
			terrains.append(region.id)
	var reachable: Dictionary = {}
	for kind: FishData in roster:
		_check(not kind.display_name.is_empty(), "%s has no name" % kind.id)
		_check(not kind.description.is_empty(), "%s has no description" % kind.id)
		_check(kind.food > 0, "%s pays no Food, so catching it is a waste of the wait" % kind.id)
		_check(kind.patience > 0.0, "%s takes no time to catch" % kind.id)
		_check(kind.weight > 0.0, "%s can never be the one that bites" % kind.id)
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no art at %s" % [kind.id, kind.get_sprite_path()])
		var homes: int = 0
		for region: String in terrains:
			if kind.lives_in(region):
				homes += 1
				reachable[region] = true
		_check(homes > 0,
			("%s lives in %s, which is not a region in this game - so it is "
				+ "authored, priced and uncatchable") % [kind.id, str(kind.regions)])
	for region: String in terrains:
		_check(reachable.has(region), "no fish lives in %s" % region)
	_ran += 1


## A fish restores; it never raises a stat.
func _test_no_fish_grants_power() -> void:
	for kind: FishData in ContentDB.fish_sorted():
		for field: String in ["attribute", "attribute_points", "points", "base_points",
				"might", "vigour", "swiftness", "focus", "damage", "max_hp"]:
			_check(not (field in kind),
				("%s carries a `%s`. A fish restores what the road took; it does "
					+ "not raise a stat (working rule 7)") % [kind.id, field])
		_check(kind.heal_fraction <= 1.0 and kind.shield_fraction <= 1.0
				and kind.mana_fraction <= 1.0,
			"%s restores more than a full hero's worth" % kind.id)
	_ran += 1


## Water is dug at the edge of the field, on open ground, off the roads and
## off the spawn mouths - in every region, because a region without ponds is
## an act without fishing and nothing else would notice.
##
## The owner's ruling put ponds "around the edges of the playable map, beyond
## where the paths start", and the first version put them in the middle; the
## band is asserted so the ruling cannot drift back.
func _test_ponds_sit_at_the_edge_off_the_roads_in_every_region() -> void:
	var reach: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE
	for value: Variant in ContentDB.terrains.values():
		var region := value as TerrainData
		if region == null:
			continue
		_check(ResourceLoader.exists(Fishing.TILES_ART_FORMAT % region.id),
			"%s has no pond tile sheet at %s" % [region.id, Fishing.TILES_ART_FORMAT % region.id])
		var ponds: Fishing = await _dug(region.id)
		_check(ponds.pond_count() > 0, "%s must dig at least one pond" % region.id)
		var wanted: int = int((Fishing.REGIONS.get(region.id, Fishing.REGIONS["jungle"]) as Dictionary)["ponds"])
		_check(ponds.pond_count() >= mini(wanted, 2),
			"%s asked for %d ponds and dug %d - the field has no room for water at its edge"
				% [region.id, wanted, ponds.pond_count()])
		var centres: PackedVector2Array = ponds.pond_positions()
		var halves: PackedVector2Array = ponds.pond_extents()
		var cells: PackedInt32Array = ponds.pond_cell_counts()
		for index: int in centres.size():
			var at: Vector2 = centres[index]
			var half: Vector2 = halves[index]
			_check(absf(at.x) + half.x <= reach and absf(at.y) + half.y <= reach,
				"%s: a pond at %s reaches past the hero's own bounds" % [region.id, str(at)])
			_check(at.length() >= Balance.FISHING_EDGE_BAND * (BattleGrid.HALF_EXTENT - BattleGrid.TILE * 2.0) * 0.98,
				"%s: a pond at %s is %.0f from the town, inside the edge band the owner asked for"
					% [region.id, str(at), at.length()])
			_check(cells[index] >= 4,
				"%s: the pond at %s drew %d water cells - a puddle, or nothing" % [region.id, str(at), cells[index]])
			var rim := Rect2(at - half, half * 2.0)
			_check(Fishing.ground_is_open(ponds.grid, rim, Balance.FISHING_ROAD_CLEARANCE_TILES),
				("%s: a pond at %s lies on, or within %d tile(s) of, ground that is not open - "
					+ "water must not take a road or the border") % [region.id, str(at),
					Balance.FISHING_ROAD_CLEARANCE_TILES])
		ponds.queue_free()
		await get_tree().process_frame
	_ran += 1


## Two machines dig the same ponds, because neither is told about them.
func _test_the_same_seed_digs_the_same_ponds() -> void:
	var first: Fishing = await _dug("snow", 771234)
	var one: PackedVector2Array = first.pond_positions()
	first.queue_free()
	await get_tree().process_frame
	var second: Fishing = await _dug("snow", 771234)
	var two: PackedVector2Array = second.pond_positions()
	second.queue_free()
	await get_tree().process_frame

	_check(one.size() == two.size() and one.size() > 0,
		"the same seed dug %d ponds and then %d" % [one.size(), two.size()])
	for index: int in mini(one.size(), two.size()):
		_check(one[index].is_equal_approx(two[index]),
			("pond %d landed at %s and then at %s - a guest would be fishing "
				+ "water the host has not got") % [index, str(one[index]), str(two[index])])

	# The dig must not move when the catches do. The first cut drew both from
	# one stream, so a host that had landed three fish dug different ponds
	# from a guest that had landed none.
	var fished: Fishing = await _dug("snow", 771234)
	for _draw: int in 7:
		RunState.rng("fishing").randf()
	fished.scatter()
	var three: PackedVector2Array = fished.pond_positions()
	fished.queue_free()
	await get_tree().process_frame
	_check(three.size() == one.size(), "catching fish moved the ponds")
	for index: int in mini(three.size(), one.size()):
		_check(three[index].is_equal_approx(one[index]),
			"pond %d moved after the fishing stream was drawn on" % index)

	var elsewhere: Fishing = await _dug("snow", 993311)
	var third: PackedVector2Array = elsewhere.pond_positions()
	elsewhere.queue_free()
	await get_tree().process_frame
	var identical: bool = third.size() == one.size()
	for index: int in mini(third.size(), one.size()):
		identical = identical and third[index].is_equal_approx(one[index])
	_check(not identical, "two different seeds dug the identical lake")
	_ran += 1


## The road a catch travels: stand still, cast, wait, hook the bite, reel.
##
## Driven with a scripted input through `_process`, the way a player drives it.
## The owner's report on the first cut was that fishing "did not happen"; the
## thing this holds is that it happens, and only when asked.
func _test_a_catch_is_cast_hooked_and_reeled() -> void:
	var ponds: Fishing = await _dug("jungle")
	if ponds.pond_count() <= 0:
		ponds.queue_free()
		_ran += 1
		return
	var angler: CharacterBody2D = _angler(ponds)
	var field: Node = ponds.field
	MetaState.fish.clear()
	MetaState.profession_xp.clear()
	_caught.clear()

	# Standing still beside water is an offer, not a line in the water.
	angler.velocity = Vector2.ZERO
	ponds._process(0.05)
	_check(ponds.state() == Fishing.State.READY, "standing by a pond must make the cast available")
	_check(not ponds.is_fishing(), "the first cut put the line in by itself; this one must wait to be asked")

	# The cast, and the flight.
	angler.call("press_interact")
	ponds._process(0.05)
	# The second cut (2026-09-12): a press charges and the release casts.
	ponds._process(0.05)
	_check(ponds.state() == Fishing.State.CASTING, "a press and a release must cast (state %d)" % ponds.state())
	_tick(ponds, Balance.FISHING_CAST_TIME + 0.2)
	_check(ponds.state() == Fishing.State.WAITING, "the float must land and the wait begin")
	_check(ponds.is_fishing(), "a cast line is fishing")

	# Walking away takes the line out.
	angler.velocity = Vector2.RIGHT * Balance.HERO_MOVE_SPEED
	ponds._process(0.05)
	_check(not ponds.is_fishing(), "walking away must take the line out")
	angler.velocity = Vector2.ZERO

	# Again, and this time wait it out to a bite - and miss it.
	ponds._process(0.05)
	angler.call("press_interact")
	ponds._process(0.05)
	# The second cut (2026-09-12): a press charges and the release casts.
	ponds._process(0.05)
	_tick(ponds, Balance.FISHING_CAST_TIME + 0.2)
	var reached_bite: bool = _tick_until(ponds, Fishing.State.BITE, 120.0)
	_check(reached_bite, "the wait must end in a bite")
	_tick(ponds, Balance.FISHING_BITE_WINDOW * Balance.FISHING_SKILL_BITE_CEILING + 0.2)
	_check(ponds.state() == Fishing.State.WAITING,
		"an unanswered bite slips the hook and the line stays in; state is %d" % ponds.state())
	_check(_failed_reasons.has("It slipped the hook."), "and it must say so")
	_check(MetaState.profession_xp.get("angler", 0.0) > 0.0,
		"a slipped bite still teaches the Angler something")

	# The bite, hooked, and reeled with the tension kept in the band.
	reached_bite = _tick_until(ponds, Fishing.State.BITE, 120.0)
	_check(reached_bite, "the second wait must end in a bite too")
	angler.call("press_interact")
	ponds._process(0.05)
	# The second cut (2026-09-12): a press charges and the release casts.
	ponds._process(0.05)
	_check(ponds.state() == Fishing.State.REELING, "a press inside the window hooks the fish")
	var before_food: int = int((field.get("paid") as Dictionary).get(RunState.FOOD, 0))
	var landed: bool = false
	for _step: int in 3000:
		var reel: Vector2 = ponds.reel_state()
		angler.call("hold_interact", reel.x < Balance.FISHING_SAFE_BAND_CENTRE)
		ponds._process(0.05)
		if ponds.state() != Fishing.State.REELING:
			landed = _caught.size() > 0
			break
	_check(landed, "keeping the tension in the band must land the fish (state %d, reasons %s)"
		% [ponds.state(), str(_failed_reasons)])
	_check(int((field.get("paid") as Dictionary).get(RunState.FOOD, 0)) > before_food,
		"a landed fish must pay Food")
	_check(MetaState.fish_total() == 1, "and put itself in the pantry: %d there" % MetaState.fish_total())
	_check(ponds.stocked_count() <= ponds.pond_count(), "a catch counts against the pond's stock")
	_check(MetaState.profession_xp.get("angler", 0.0) >= float(Balance.FISHING_XP_BY_RARITY[0]),
		"a landed fish trains the Angler")

	angler.queue_free()
	ponds.queue_free()
	await get_tree().process_frame
	_ran += 1


## Holding the line tight snaps it; a slack line loses the fish. Neither pays.
func _test_a_slack_or_snapped_line_pays_nothing() -> void:
	var ponds: Fishing = await _dug("jungle", 4242)
	if ponds.pond_count() <= 0:
		ponds.queue_free()
		_ran += 1
		return
	var angler: CharacterBody2D = _angler(ponds)
	MetaState.fish.clear()
	_caught.clear()
	_failed_reasons.clear()
	angler.velocity = Vector2.ZERO
	ponds._process(0.05)
	angler.call("press_interact")
	ponds._process(0.05)
	# The second cut (2026-09-12): a press charges and the release casts.
	ponds._process(0.05)
	_tick(ponds, Balance.FISHING_CAST_TIME + 0.2)
	_check(_tick_until(ponds, Fishing.State.BITE, 120.0), "the wait must end in a bite")
	angler.call("press_interact")
	ponds._process(0.05)
	# The second cut (2026-09-12): a press charges and the release casts.
	ponds._process(0.05)
	# Hold and never let go.
	angler.call("hold_interact", true)
	for _step: int in 600:
		ponds._process(0.05)
		if ponds.state() != Fishing.State.REELING:
			break
	_check(_failed_reasons.has("The line snapped."), "a line held tight must snap: %s" % str(_failed_reasons))
	_check(_caught.is_empty() and MetaState.fish_total() == 0, "a snapped line pays nothing")
	angler.call("hold_interact", false)

	# And slack: hook it, then never reel.
	_failed_reasons.clear()
	ponds._process(0.05)
	angler.call("press_interact")
	ponds._process(0.05)
	# The second cut (2026-09-12): a press charges and the release casts.
	ponds._process(0.05)
	_tick(ponds, Balance.FISHING_CAST_TIME + 0.2)
	_check(_tick_until(ponds, Fishing.State.BITE, 120.0), "the wait must end in a bite")
	angler.call("press_interact")
	ponds._process(0.05)
	# The second cut (2026-09-12): a press charges and the release casts.
	ponds._process(0.05)
	for _step: int in 600:
		ponds._process(0.05)
		if ponds.state() != Fishing.State.REELING:
			break
	_check(_failed_reasons.has("It threw the hook.") or _failed_reasons.has("It slipped away."),
		"a slack line loses the fish: %s" % str(_failed_reasons))
	_check(_caught.is_empty() and MetaState.fish_total() == 0, "a lost fish pays nothing")

	angler.queue_free()
	ponds.queue_free()
	await get_tree().process_frame
	_ran += 1


## The Angler's bound: a profession touches nothing but its craft.
##
## Levelling and gear are the two capped scales the campaign tiers are tuned
## against. A maxed Angler must have exactly the attributes they had at level
## one, and the level must be capped and derived rather than stored.
func _test_the_angler_only_fishes() -> void:
	MetaState.profession_xp.clear()
	var before: Array[int] = []
	for attribute: int in 4:
		before.append(RunState.attribute(attribute))
	_check(MetaState.profession_level("angler") == 1, "a fresh account is an Angler of level 1")
	MetaState.gain_profession_xp("angler", int(MetaState.profession_xp_to_cap()) + 500)
	_check(MetaState.profession_level("angler") == Balance.PROFESSION_MAX_LEVEL,
		"the Angler must cap at %d, not %d" % [Balance.PROFESSION_MAX_LEVEL, MetaState.profession_level("angler")])
	_check(float(MetaState.profession_xp.get("angler", 0.0)) <= MetaState.profession_xp_to_cap() + 0.01,
		"experience past the cap must not be kept")
	for attribute: int in 4:
		_check(RunState.attribute(attribute) == before[attribute],
			"a maxed Angler changed attribute %d - a profession must not touch the fight" % attribute)
	_check(MetaState.gain_profession_xp("smith", 10) == 1 and not MetaState.profession_xp.has("smith"),
		"a profession the game does not name must not be trained")
	# Round trip, with a stale profession dropped.
	var written: String = MetaState.serialized_save()
	var parsed: Dictionary = MetaState.parse_save_text(written)
	_check(parsed.has("professions"), "the save must carry the professions")
	MetaState.profession_xp.clear()
	MetaState._read_professions(parsed.get("professions", {}) as Dictionary)
	_check(MetaState.profession_level("angler") == Balance.PROFESSION_MAX_LEVEL,
		"the Angler's level must survive a load")
	MetaState._read_professions({"xp": {"angler": 45.0, "a_craft_that_was_cut": 900.0}})
	_check(not MetaState.profession_xp.has("a_craft_that_was_cut"),
		"a profession that no longer exists must not survive a load")
	_check(MetaState.profession_level("angler") == 2, "45 experience is level 2, not %d"
		% MetaState.profession_level("angler"))
	MetaState.profession_xp.clear()
	_ran += 1


## The bound. Three meals a run, however deep the larder.
func _test_the_meal_cap_holds() -> void:
	var kind: FishData = ContentDB.fish_sorted()[0]
	MetaState.fish.clear()
	for _keep: int in Balance.FISH_MEALS_PER_RUN + 5:
		MetaState.take_fish(kind.id)
	RunState.meals_eaten = 0
	GameDirector.run_active = true

	var eaten: int = 0
	var refusal: String = ""
	for _attempt: int in Balance.FISH_MEALS_PER_RUN + 5:
		var why: String = RunState.eat_fish(kind.id)
		if why.is_empty():
			eaten += 1
		else:
			refusal = why
	_check(eaten == Balance.FISH_MEALS_PER_RUN,
		("a run must allow exactly %d meals; it allowed %d. This is the bound "
			+ "the whole system rests on") % [Balance.FISH_MEALS_PER_RUN, eaten])
	_check(not refusal.is_empty(), "and it must say why it refused")
	_check(MetaState.fish_count(kind.id) > 0,
		"a refused meal must not eat the fish anyway")

	var kept: int = MetaState.fish_count(kind.id)
	RunState.reset()
	RunState.phase = RunState.Phase.ROAD_BATTLE
	_check(RunState.meals_eaten == 0, "a new run must restore the appetite")
	_check(MetaState.fish_count(kind.id) == kept,
		"and must not empty the larder: %d became %d"
			% [kept, MetaState.fish_count(kind.id)])

	GameDirector.run_active = false
	_check(not RunState.eat_fish(kind.id).is_empty(),
		"eating between runs must be refused")
	_check(MetaState.fish_count(kind.id) == kept,
		"and must not spend the fish while refusing")

	MetaState.fish.clear()
	for _flood: int in Balance.FISH_STASH_CAPACITY + 12:
		MetaState.take_fish(kind.id)
	_check(MetaState.fish_total() == Balance.FISH_STASH_CAPACITY,
		"the larder holds %d against a cap of %d"
			% [MetaState.fish_total(), Balance.FISH_STASH_CAPACITY])
	_ran += 1


## The pantry is written, read back, and cleaned of anything stale.
func _test_the_pantry_survives_a_round_trip() -> void:
	var kind: FishData = ContentDB.fish_sorted()[0]
	MetaState.fish.clear()
	MetaState.take_fish(kind.id)
	MetaState.take_fish(kind.id)
	var written: String = MetaState.serialized_save()
	var parsed: Dictionary = MetaState.parse_save_text(written)
	_check(parsed.has("pantry"), "the save must carry the pantry")
	MetaState.fish.clear()
	MetaState._read_pantry(parsed.get("pantry", {}) as Dictionary)
	_check(MetaState.fish_count(kind.id) == 2,
		"two fish went in and %d came back" % MetaState.fish_count(kind.id))
	MetaState._read_pantry({"fish": {"a_fish_that_was_cut": 4, kind.id: 1}})
	_check(MetaState.fish_count("a_fish_that_was_cut") == 0,
		"a fish that no longer exists must not survive a load")
	_check(MetaState.fish_count(kind.id) == 1,
		"and the ones that do exist must")
	MetaState.fish.clear()
	_ran += 1


## A `Fishing` with real ponds dug for `region`.
func _dug(region: String, run_seed: int = 20260911) -> Fishing:
	RunState.set_seed(run_seed)
	RunState.terrain_id = region
	RunState.phase = RunState.Phase.ROAD_BATTLE
	var grid := BattleGrid.new()
	var ponds := Fishing.new()
	ponds.grid = grid
	add_child(ponds)
	await get_tree().process_frame
	ponds.scatter()
	return ponds


## A body standing at the first pond's edge, with a scripted input.
func _angler(ponds: Fishing) -> CharacterBody2D:
	var angler := CharacterBody2D.new()
	angler.set_script(load("res://tools/fishing_check_angler.gd"))
	add_child(angler)
	var stub := Node.new()
	stub.set_script(load("res://tools/fishing_check_field.gd"))
	stub.set("hero", angler)
	add_child(stub)
	ponds.field = stub
	var at: Vector2 = ponds.pond_positions()[0]
	var half: Vector2 = ponds.pond_extents()[0]
	angler.global_position = at + Vector2(half.x + 20.0, 0.0)
	return angler


func _tick(ponds: Fishing, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		ponds._process(0.05)
		left -= 0.05


## Ticks until the pond reaches `state`, or gives up after `limit` seconds.
func _tick_until(ponds: Fishing, state: int, limit: float) -> bool:
	var left: float = limit
	while left > 0.0:
		if ponds.state() == state:
			return true
		ponds._process(0.05)
		left -= 0.05
	return ponds.state() == state


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)
