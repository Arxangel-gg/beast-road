extends Node

## Ponds, what comes out of them, and the one bound the whole system rests on.
##
## Fishing is the first thing in this project that lets a **consumable** survive
## a run, which is an amendment to working rule 7. The amendment is recorded in
## CLAUDE.md and its bound is `Balance.FISH_MEALS_PER_RUN`: the pantry persists,
## the appetite does not. If that cap ever stops being enforced, a player with a
## full larder cannot be killed and the wounds, the Tonic and the whole recovery
## economy become decoration - so it is asserted here first and hardest.
##
## The other four failures this holds are ones the project has hit before in
## other systems: content authored and drawn by nothing, a procedural placement
## that puts a thing where the player cannot reach it, two machines deriving
## different worlds from the same seed, and a catch that quietly grants power.

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260911)

	_test_every_fish_is_real()
	_test_no_fish_grants_power()
	await _test_ponds_are_reachable_and_off_the_roads()
	await _test_the_same_seed_digs_the_same_ponds()
	await _test_a_line_needs_stillness()
	_test_the_meal_cap_holds()
	_test_the_pantry_survives_a_round_trip()

	Sfx.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	if _failures > 0:
		push_error("[fishing] FAIL - %d problem(s) across %d tests" % [_failures, _ran])
		get_tree().quit(1)
		return
	print("[fishing] PASS - %d tests: ponds, stillness, the seed, the meal cap and the pantry"
		% _ran)
	get_tree().quit(0)


## Every authored fish is complete, drawn, and reachable from somewhere.
##
## The last clause is the one worth having. A fish whose `regions` names a
## terrain that does not exist is authored, listed, priced and can never be
## caught - the same failure `call_wolf` had in the discipline tree, which
## nothing noticed for months because "no consumer" is invisible.
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
	# And every region holds something, or a whole act has dry ponds.
	for region: String in terrains:
		_check(reachable.has(region), "no fish lives in %s" % region)
	_ran += 1


## A fish restores; it never raises a stat.
##
## Working rule 7's bound, checked against the resource rather than argued
## about: levelling and gear are the two capped scales the campaign tiers are
## tuned against, and a consumable that granted attribute points would be a
## third that nobody is tuning. Every effect a fish can carry is a fraction of
## something the hero already has.
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


## Water is dug where the player can walk to it and where nobody was building.
##
## Both halves have bitten this project in other systems. `Treeline` puts trees
## *outside* the grid, which is right for a tree and would be fatal here: the
## hero is clamped to the grid, so a pond out there is a thing you can see and
## can never reach. And a pond across a road would be decor sitting in the one
## place the game is played.
func _test_ponds_are_reachable_and_off_the_roads() -> void:
	var ponds: Fishing = await _dug("jungle")
	_check(ponds.pond_count() > 0, "a jungle act must dig at least one pond")
	var reach: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE
	for at: Vector2 in ponds.pond_positions():
		_check(absf(at.x) <= reach and absf(at.y) <= reach,
			("a pond at %s is outside the hero's own bounds, so it can be seen "
				+ "and never fished") % str(at))
		_check(ponds.grid.cell_at(BattleGrid.world_to_tile(at)) == BattleGrid.Cell.OPEN,
			"a pond at %s is not on open ground" % str(at))
		var nearest: float = INF
		for path: Variant in ponds.grid.lane_paths:
			for point: Vector2 in (path as PackedVector2Array):
				nearest = minf(nearest, at.distance_to(point))
		_check(nearest >= Balance.FISHING_ROAD_CLEARANCE,
			("a pond at %s sits %.0f from a road, inside the %.0f clearance - "
				+ "water must not take ground somebody was defending")
				% [str(at), nearest, Balance.FISHING_ROAD_CLEARANCE])
	ponds.queue_free()
	await get_tree().process_frame
	_ran += 1


## Two machines dig the same ponds, because neither is told about them.
##
## `Fishing` derives its scatter from the run's own seeded stream rather than
## relaying it, which is what CLAUDE.md asks for - "adding a fact is adding a
## thing that can be subtly wrong". The property that makes that safe is this
## one, and it is exactly the property `seed_reproduction_check` holds for the
## rest of the run.
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

	# And a different seed is a different lake. Without this the test above
	# passes just as well against a hard-coded list of positions.
	var elsewhere: Fishing = await _dug("snow", 993311)
	var third: PackedVector2Array = elsewhere.pond_positions()
	elsewhere.queue_free()
	await get_tree().process_frame
	var identical: bool = third.size() == one.size()
	for index: int in mini(third.size(), one.size()):
		identical = identical and third[index].is_equal_approx(one[index])
	_check(not identical, "two different seeds dug the identical lake")
	_ran += 1


## The line goes in when you stand still and comes out when you do not.
##
## The whole cost of fishing is the seconds you were not defending, so this is
## the design rather than a detail. Driven through `_process` with a real body,
## because the thing under test is what the system reads off that body.
func _test_a_line_needs_stillness() -> void:
	var ponds: Fishing = await _dug("jungle")
	if ponds.pond_count() <= 0:
		ponds.queue_free()
		_ran += 1
		return
	var angler := CharacterBody2D.new()
	angler.set_script(load("res://tools/fishing_check_angler.gd"))
	add_child(angler)
	ponds.field = _stub_field(angler)
	angler.global_position = ponds.pond_positions()[0]

	angler.velocity = Vector2.ZERO
	ponds._process(0.05)
	_check(ponds.is_fishing(), "standing still beside a pond must put the line in")

	angler.velocity = Vector2.RIGHT * Balance.HERO_MOVE_SPEED
	ponds._process(0.05)
	_check(not ponds.is_fishing(), "walking away must take the line out")

	# Far from any water, standing still is just standing still.
	angler.velocity = Vector2.ZERO
	angler.global_position = Vector2(BattleGrid.HALF_EXTENT * 4.0, 0.0)
	ponds._process(0.05)
	_check(not ponds.is_fishing(), "there is no fishing away from water")

	# A pond is exhaustible, and that is what stops the correct play being
	# "stand in a corner for the whole act".
	_check(Balance.FISHING_POND_STOCK > 0 and Balance.FISHING_POND_STOCK <= 10,
		"a pond holds %d fish, which is either nothing or a job"
			% Balance.FISHING_POND_STOCK)
	angler.queue_free()
	ponds.queue_free()
	await get_tree().process_frame
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

	# A fresh run is a fresh appetite, and the larder is untouched by it.
	var kept: int = MetaState.fish_count(kind.id)
	RunState.reset()
	_check(RunState.meals_eaten == 0, "a new run must restore the appetite")
	_check(MetaState.fish_count(kind.id) == kept,
		"and must not empty the larder: %d became %d"
			% [kept, MetaState.fish_count(kind.id)])

	# Out of a run there is nothing to feed, and it says so rather than
	# silently spending a fish against a hero that does not exist.
	GameDirector.run_active = false
	_check(not RunState.eat_fish(kind.id).is_empty(),
		"eating between runs must be refused")
	_check(MetaState.fish_count(kind.id) == kept,
		"and must not spend the fish while refusing")

	# The larder is finite too, or a long session writes a save nobody can read.
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

	# A fish that no longer exists is dropped rather than carried. A stale
	# unlock is harmless; a stale consumable is a row with no name that a
	# player would try to eat.
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
	var grid := BattleGrid.new()
	var ponds := Fishing.new()
	ponds.grid = grid
	add_child(ponds)
	await get_tree().process_frame
	ponds.scatter()
	return ponds


## A scope that answers the two questions `Fishing` asks of one.
func _stub_field(angler: Node2D) -> Node:
	var stub := Node.new()
	stub.set_script(load("res://tools/fishing_check_field.gd"))
	stub.set("hero", angler)
	add_child(stub)
	return stub


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)
