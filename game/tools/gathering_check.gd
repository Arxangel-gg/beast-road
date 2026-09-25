extends Node

## Woodcutting, mining and the forge: where nodes may stand, what practice
## buys, and the bound that lets materials persist at all.
##
##   godot --headless --path game res://tools/gathering_check.tscn
##
## Owner brief, 2026-09-13: crafts that persist across runs, nodes of different
## rarities with cooldowns, gems out of the ground, a gem plus smithing level
## giving a chance at rarity, a place to smith, and **no materials at all on a
## new account**.
##
## **The bound that matters most is the one that makes the persistence safe.**
## CLAUDE.md §7 names what a save may hold. Materials were added to that list
## with one rule: a material is an input to the Smithy and nothing else. It
## grants no attribute, buys no tower, pays no wave and does not exchange for a
## run currency. What it makes is gear, which is already on the capped scale
## levelling shares. So the third power scale this project keeps refusing does
## not arrive through the back of a mine - and that is asserted first.
##
## Seven ways this can be a lie:
##
## 1. **A material that is worth a stat.** The bound. Checked by maxing every
##    craft and filling the store, then reading every attribute back.
## 2. **A new account that is not new.** The owner asked for zero, and a
##    default that is not zero is invisible until somebody looks.
## 3. **A node that can never appear.** The three gates are distance, practice
##    and the node's own floor; a node whose gates cannot all be met at once is
##    a file nothing will ever draw - the same failure `call_wolf` was.
## 4. **A node inside the city's square.** The owner's placement instruction,
##    and the one thing here a player would notice immediately.
## 5. **A forge that makes something from nothing.** Validate, spend, make - in
##    that order, and a refused forge must leave the store exactly as it was.
## 6. **A forged piece that is better than a found one.** It must roll on the
##    same tables at the same caps, or the Smithy is a way past the road rather
##    than another way onto it.
## 7. **A craft that touches the fight.** The Angler's bound, applied to three
##    more crafts.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260913)
	RunState.phase = RunState.Phase.ROAD_BATTLE

	_test_a_new_account_has_nothing()
	_test_every_node_is_real_and_reachable()
	_test_the_store_only_takes_what_is_named()
	await _test_nodes_stand_outside_the_city()
	await _test_a_new_act_relays_the_ground()
	_test_the_forge_validates_before_it_spends()
	_test_a_forged_piece_is_an_ordinary_piece()
	_test_the_crafts_only_craft()
	await _test_a_seam_is_not_spoken_over()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _f: int in 12:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[gathering] PASS - %d checks: nothing on a new account, nodes out past the roads, a forge that only makes gear, and a seam nobody speaks over"
			% _checks)
	else:
		push_error("[gathering] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **A seam's prompt survives another system having nothing to say.**
##
## `interact_prompt` and `fishing_prompt` feed one label and seven systems write
## to it - seams, plots, rift gates, towers, nests, and the dungeon's chest and
## portal - each caching its own last line so it does not spam the bus. That made
## a *clear* dangerous: a system with nothing to say emitted "" after one with
## something to say emitted its line, and with both now deduping **neither ever
## re-asserted**. A Warden standing at a copper seam was shown nothing at all.
##
## Found by photographing the Guide's gathering section: `Gathering` held
## "Mine - Copper Seam" and the screen was blank.
##
## Driven through the two real `_set_prompt`s in the order that broke it, reading
## what actually reached the bus - two caches disagreeing about one label is not
## something a constant can be asked about.
func _test_a_seam_is_not_spoken_over() -> void:
	var said: Array[String] = [""]
	var ear: Callable = func(text: String, _button: String) -> void: said[0] = text
	EventBus.interact_prompt.connect(ear)

	var seams := Gathering.new()
	var plots := Farming.new()
	add_child(seams)
	add_child(plots)
	await get_tree().process_frame

	# **The sequence a player actually walks**: past a plot, on to a seam, away
	# from the plot. Ordered this way on purpose - with the plots never having
	# spoken, their clear dedupes against their own empty cache and the bug hides.
	plots.call("_set_prompt", "Plant a seed", "PLANT")
	_check(said[0] == "Plant a seed",
		"a plot must be able to say what it is; the line reads %s" % said[0])

	# The seam is reached, and takes the line.
	seams.call("_set_prompt", "Mine  ·  Copper Seam", "WORK")
	_check(said[0] == "Mine  ·  Copper Seam",
		"a seam in reach must take the line; it reads %s" % said[0])

	# And the plot falls out of reach. **This is the clear that used to wipe the
	# seam's words and leave the Warden told nothing at all.**
	plots.call("_set_prompt", "", "")
	_check(said[0] == "Mine  ·  Copper Seam",
		"a system with nothing to say must not speak over one that has - "
		+ "the line reads %s" % said[0])

	# And a system that lost the line says its piece again rather than deduping
	# against a cache that no longer describes the screen.
	plots.call("_set_prompt", "Plant a seed", "PLANT")
	seams.call("_set_prompt", "Mine  ·  Copper Seam", "WORK")
	_check(said[0] == "Mine  ·  Copper Seam",
		"a system that lost the line must re-assert it; it reads %s" % said[0])

	# The owner may clear its own line.
	seams.call("_set_prompt", "", "")
	_check(said[0] == "", "the holder of the line must be able to clear it")

	EventBus.interact_prompt.disconnect(ear)
	seams.queue_free()
	plots.queue_free()
	await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


## The owner's own instruction: a new account starts with none of it.
func _test_a_new_account_has_nothing() -> void:
	MetaState.erase_progress()
	_check(MetaState.materials.is_empty(),
		"a new account holds no materials; it holds %d" % MetaState.materials.size())
	for craft: String in Balance.PROFESSIONS:
		_check(MetaState.profession_level(craft) == 1,
			"a new account is a %s of level 1" % craft)
	_check(Balance.PROFESSIONS.has("woodcutter") and Balance.PROFESSIONS.has("miner")
			and Balance.PROFESSIONS.has("smith") and Balance.PROFESSIONS.has("angler"),
		"four crafts are named: %s" % str(Balance.PROFESSIONS))


## Every node is complete, drawn, and its three gates can all be met at once.
##
## The failure this is written against is a node nothing will ever draw. The
## gates are distance, the rarity's share of the ladder and the node's own
## floor, and a node that wants a level past the cap is authored and unreachable
## - which this project has already paid for once with a discipline node no seed
## could ever offer.
func _test_every_node_is_real_and_reachable() -> void:
	var nodes: Array[GatherNodeData] = ContentDB.gather_nodes_sorted()
	_check(nodes.size() >= 6, "there must be nodes to work; found %d" % nodes.size())
	var by_craft: Dictionary = {}
	var gems: int = 0
	for node: GatherNodeData in nodes:
		by_craft[node.craft] = int(by_craft.get(node.craft, 0)) + 1
		_check(Balance.PROFESSIONS.has(node.craft),
			"%s trains \"%s\", which is not a craft" % [node.id, node.craft])
		_check(not node.display_name.is_empty(), "%s has no name" % node.id)
		_check(ResourceLoader.exists(node.get_sprite_path()),
			"%s has no art at %s" % [node.id, node.get_sprite_path()])
		var material: MaterialData = ContentDB.material(node.material_id)
		_check(material != null,
			"%s yields \"%s\", which no material names" % [node.id, node.material_id])
		if material != null and material.kind == MaterialData.Kind.GEM:
			gems += 1
		_check(node.swings > 0 and node.material_per_swing > 0,
			"%s gives nothing for the time it takes" % node.id)
		_check(node.xp_per_swing > 0, "%s teaches its craft nothing" % node.id)
		# Reachable: the level it wants must be inside the ladder.
		var rarity: int = clampi(node.rarity, 0, Balance.GATHER_LEVEL_SHARE_BY_RARITY.size() - 1)
		var wanted: int = maxi(node.min_level, 1 + int(round(
			Balance.GATHER_LEVEL_SHARE_BY_RARITY[rarity]
				* float(Balance.PROFESSION_MAX_LEVEL - 1))))
		_check(wanted <= Balance.PROFESSION_MAX_LEVEL,
			"%s wants a %s of level %d and the ladder stops at %d - it could never be worked"
				% [node.id, node.craft, wanted, Balance.PROFESSION_MAX_LEVEL])
		# And far enough out to still be inside the map.
		var reach: float = Balance.GATHER_DISTANCE_BY_RARITY[
			clampi(node.rarity, 0, Balance.GATHER_DISTANCE_BY_RARITY.size() - 1)]
		_check(reach < 1.0,
			"%s may only appear past the rim of the map" % node.id)
	_check(int(by_craft.get("woodcutter", 0)) > 0, "the Woodcutter has nothing to fell")
	_check(int(by_craft.get("miner", 0)) > 0, "the Miner has nothing to break")
	_check(gems > 0, "no node yields a gem, and the forge needs one")

	# Every material is drawn, described and reachable from some node.
	var yielded: Dictionary = {}
	for node: GatherNodeData in nodes:
		yielded[node.material_id] = true
	for material: MaterialData in ContentDB.materials_sorted():
		_check(ResourceLoader.exists(material.get_sprite_path()),
			"%s has no icon at %s" % [material.id, material.get_sprite_path()])
		_check(not material.description.is_empty(), "%s says nothing" % material.id)
		_check(yielded.has(material.id),
			"nothing on the road yields %s, so it can only ever be zero" % material.id)


## The store refuses what the content does not name, and a save is a claim.
func _test_the_store_only_takes_what_is_named() -> void:
	MetaState.erase_progress()
	_check(not MetaState.gain_material("no_such_thing", 5),
		"a material the game does not name must not be created")
	_check(MetaState.material_count("no_such_thing") == 0, "and it must not be stored")
	var real: String = ContentDB.materials_sorted()[0].id
	_check(MetaState.gain_material(real, 3), "a real material must be storable")
	_check(MetaState.material_count(real) == 3, "and counted: %d" % MetaState.material_count(real))
	_check(not MetaState.spend_material(real, 4),
		"spending more than is held must refuse rather than go negative")
	_check(MetaState.material_count(real) == 3, "and change nothing when it refuses")
	_check(MetaState.spend_material(real, 3), "spending exactly what is held must work")
	_check(not MetaState.materials.has(real), "and an empty entry must not be kept")

	# A save is a file on somebody's disk, so what comes back is a claim.
	MetaState._read_materials({"no_such_thing": 900, real: -4, "": 5})
	_check(MetaState.materials.is_empty(),
		"a save claiming materials the game does not name must read as nothing: %s"
			% str(MetaState.materials))
	MetaState._read_materials({real: 99999999})
	_check(MetaState.material_count(real) <= Balance.MATERIAL_STACK_CEILING,
		"and a claim past the ceiling must be clamped")
	MetaState.erase_progress()


## The owner's placement instruction, driven through the real battlefield.
##
## Every node must sit **beyond the inner square the roads make** - outside the
## authored core - and a rare one must sit further out than a common one. Checked
## on the ground rather than on the constants, because the constants have been
## right while the placement was wrong before: a legal-placement gate passed
## once while every pond sat somewhere the hero could not reach.
func _test_nodes_stand_outside_the_city() -> void:
	MetaState.erase_progress()
	var grid := BattleGrid.new()
	var patch := Gathering.new()
	patch.grid = grid
	add_child(patch)
	await get_tree().process_frame
	var dug: int = 0
	var by_rarity: Dictionary = {}
	for region: String in ["jungle", "snow", "iron_steppe", "ashen_reach"]:
		RunState.terrain_id = region
		patch.scatter()
		dug += patch.node_count()
		var ids: Array[String] = patch.node_ids()
		var at: PackedVector2Array = patch.node_positions()
		for index: int in ids.size():
			var node: GatherNodeData = ContentDB.gather_node(ids[index])
			var spot: Vector2 = at[index]
			_check(absf(spot.x) > BattleGrid.CORE_HALF_EXTENT
					or absf(spot.y) > BattleGrid.CORE_HALF_EXTENT,
				"a node at %s is inside the city's square, which is where the roads are"
					% str(spot))
			_check(spot.length() >= Balance.FISHING_TOWN_CLEARANCE,
				"a node at %s is on top of the town" % str(spot))
			if node != null:
				var reach: float = spot.length() / BattleGrid.HALF_EXTENT
				by_rarity[node.rarity] = maxf(float(by_rarity.get(node.rarity, 0.0)), reach)
				_check(reach >= Balance.GATHER_DISTANCE_BY_RARITY[
						clampi(node.rarity, 0, Balance.GATHER_DISTANCE_BY_RARITY.size() - 1)] - 0.001,
					"a rarity-%d node grew at %.2f of the way out, nearer than its own floor"
						% [node.rarity, reach])
	_check(dug > 0, "four regions must dig at least one node between them; dug %d" % dug)
	patch.queue_free()
	await get_tree().process_frame


## **A new act re-lays the ground, and that includes the trees and seams.**
##
## `Battlefield.refresh_terrain` is the one function that re-skins a region, and
## anything regional left out of it keeps the previous act's version of itself
## for the rest of the run. The gather nodes were left out of it when they were
## added - so from Act II onward the road would have grown Act I's trees, in Act
## I's places, preferring Act I's region.
##
## Driven through the real battlefield and the real function, because the
## failure is an omission from a list: a test that called `scatter()` itself
## would pass with the omission still there. That is the same reasoning the
## comment inside `refresh_terrain` gives for keeping this list in one function
## rather than spreading it over signals.
func _test_a_new_act_relays_the_ground() -> void:
	MetaState.erase_progress()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var patch: Gathering = field.gathering() if field != null else null
	if field == null or patch == null:
		_check(false, "the harness needs a battlefield with its nodes dug")
		if run != null:
			run.queue_free()
		return

	RunState.terrain_id = "jungle"
	field.refresh_terrain()
	var before: PackedVector2Array = patch.node_positions()
	_check(before.size() > 0, "the first region must dig nodes")

	# A different region, through the real re-lay.
	RunState.act = 3
	RunState.terrain_id = "snow"
	field.refresh_terrain()
	var after: PackedVector2Array = patch.node_positions()
	var moved: bool = before.size() != after.size()
	if not moved:
		for index: int in before.size():
			if not before[index].is_equal_approx(after[index]):
				moved = true
				break
	_check(moved,
		("a new act must re-lay the trees and seams; %d nodes stood in exactly "
			+ "the same places after the region changed") % after.size())

	# And the same seed and region gives the same ground back, so a scope left
	# and returned to is not a reshuffle.
	RunState.terrain_id = "snow"
	field.refresh_terrain()
	var again: PackedVector2Array = patch.node_positions()
	var same: bool = again.size() == after.size()
	if same:
		for index: int in again.size():
			if not again[index].is_equal_approx(after[index]):
				same = false
				break
	_check(same, "the same act re-entered must show the same nodes, not a reshuffle")

	# **And no node stands where a press would mean two things.** A pond answers
	# Interact from its own rim plus half a cast, and a node answers from its
	# centre; a node inside the sum of those reaches would have the hero casting
	# a line and swinging an axe on one button.
	var ponds: Node = field.call("ponds") if field.has_method("ponds") else null
	if ponds != null and ponds.has_method("pond_positions"):
		var centres: PackedVector2Array = ponds.call("pond_positions")
		var halves: PackedVector2Array = ponds.call("pond_extents")
		var reach: float = Balance.FISHING_RADIUS + Balance.FISHING_CAST_MAX * 0.5 \
			+ Balance.GATHER_RADIUS
		for spot: Vector2 in patch.node_positions():
			for index: int in mini(centres.size(), halves.size()):
				var rim := Rect2(centres[index] - halves[index], halves[index] * 2.0)
				var near := Vector2(clampf(spot.x, rim.position.x, rim.end.x),
					clampf(spot.y, rim.position.y, rim.end.y))
				_check(spot.distance_to(near) >= reach - 0.5,
					("a node at %s is %.0f from a pond's rim against a combined reach "
						+ "of %.0f - one press would start two things")
						% [str(spot), spot.distance_to(near), reach])

	# The same standing battlefield answers the readout questions, rather than
	# a second one being built for them.
	await _test_the_work_says_what_it_did(field, patch)
	_test_a_swing_pays_what_the_node_holds(patch)

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.erase_progress()


## Validate, then spend, then make.
##
## A forge that spent first and failed second would eat the gem, which is the
## scarce half of the price and the one a player went out past the camps for.
## **A swing that paid and a seam that is empty must not look the same.**
##
## Owner report: mining "doesn't give enough of an indication of whether
## anything was gathered or if it was an unsuccessful/empty mine attempt". The
## amount and the material were already on `EventBus.gathered` and nothing in
## the game listened, so every swing looked like every other one - and a seam on
## cooldown is skipped by `_node_near`, so walking up to one you had just
## emptied offered no prompt and no reason, which is indistinguishable from
## standing in the wrong place.
##
## Driven rather than grepped: the prompt is read off the real signal, from a
## real node put on a real cooldown.
## **Given the harness rather than standing up its own.** A third Run inside one
## gate re-connects the autoload signals a freed one left behind - "signal
## already connected", "lambda capture was freed" - and the release gate fails
## on a warning exactly as it fails on an assertion.
func _test_the_work_says_what_it_did(field: Battlefield, patch: Gathering) -> void:
	if field == null or patch == null or patch.node_count() <= 0:
		_check(false, "the harness needs a battlefield with its nodes dug")
		return

	# A rest is read as a clock. "back in 130.0" is a number, not an answer.
	_check(String(patch.call("_rest_left", 45.0)) == "45s",
		"a short rest should read as seconds, got \"%s\""
			% str(patch.call("_rest_left", 45.0)))
	_check(String(patch.call("_rest_left", 130.0)) == "2m 10s",
		"a long rest should read as minutes and seconds, got \"%s\""
			% str(patch.call("_rest_left", 130.0)))

	var nodes: Array = patch.get("_nodes") as Array
	_check(nodes.size() > 0, "the patch should hold its nodes")
	if nodes.is_empty():
		return
	var seam: Dictionary = nodes[0] as Dictionary
	var hero: Node2D = field.get("hero") as Node2D
	if hero == null:
		_check(false, "the harness needs a hero to stand at the seam")
		return

	var said: PackedStringArray = []
	var listen := func(text: String, _button: String) -> void:
		said.append(text)
	EventBus.interact_prompt.connect(listen)

	# Standing at a seam that is resting.
	seam["cooldown"] = 130.0
	hero.global_position = seam["at"] as Vector2
	for _frame: int in 4:
		await get_tree().process_frame
	var resting: String = said[said.size() - 1] if said.size() > 0 else ""
	_check(resting.to_lower().contains("worked out"),
		("a seam on cooldown must say so - it is skipped for work, so with no "
			+ "prompt it is indistinguishable from standing nowhere. Got \"%s\"")
			% resting)
	_check(resting.contains("2m"),
		"and must say when it is back, got \"%s\"" % resting)

	# And a seam that is ready offers the work again.
	said.clear()
	seam["cooldown"] = 0.0
	for _frame: int in 4:
		await get_tree().process_frame
	var ready_text: String = said[said.size() - 1] if said.size() > 0 else ""
	_check(not ready_text.to_lower().contains("worked out"),
		"a seam off cooldown must stop calling itself worked out, got \"%s\""
			% ready_text)
	EventBus.interact_prompt.disconnect(listen)

	# And the swing itself has to say what it paid. A grep, because the readout
	# is a floating word with no state to read back - but the fault it guards is
	# exactly a call that is not made.
	var source := FileAccess.open("res://scripts/systems/gathering.gd", FileAccess.READ)
	if source != null:
		var code: String = source.get_as_text()
		var swing: int = code.find("func _land_a_swing")
		var says: int = code.find("_say_the_take(", swing)
		var ends: int = code.find("\nfunc ", swing + 10)
		_check(swing >= 0 and says >= 0 and (ends < 0 or says < ends),
			("a swing must say what it paid - `gathered` carried the amount for "
				+ "a fortnight and nothing listened, which is the whole report"))
	# **Walking away stops the work**, and it is checked by walking away.
	#
	# This was broken for as long as it existed: the hero's speed is a float
	# and `_tick_swing` declared it a `Vector2`, so the assignment failed, the
	# value stayed zero and the check never fired. Nothing here noticed,
	# because standing still is what a gate naturally does - so the test moves.
	seam["cooldown"] = 0.0
	hero.global_position = seam["at"] as Vector2
	for _frame: int in 3:
		await get_tree().process_frame
	patch.set("_working", 0)
	patch.set("_swing_left", 9.0)
	await get_tree().process_frame
	_check(int(patch.get("_working")) == 0, "the harness must be able to start a swing")
	# A step away, at more than the stillness speed. The hero is asked for its
	# own speed, so the harness sets the velocity the hero reports from.
	hero.global_position = (seam["at"] as Vector2) + Vector2(Balance.GATHER_RADIUS * 2.0, 0.0)
	for _frame: int in 4:
		await get_tree().process_frame
	_check(int(patch.get("_working")) < 0,
		"walking out of reach must stop the work (still working: %d)"
			% int(patch.get("_working")))

	# **And the speed itself, which is the half the distance check cannot see.**
	#
	# Checked against the contract rather than by driving it, deliberately, and
	# the reason is worth keeping: the only way to make the hero *read* as
	# moving is to give it motion, and motion carries it out of reach, so the
	# distance check above stops the work first and the test passes with the
	# bug still in. Two attempts did exactly that.
	#
	# The bug this guards: `Hero.own_speed` returns a **float** - the magnitude
	# with the beast's shove already subtracted - and `_tick_swing` declared it
	# `Vector2`. The assignment failed every frame of every swing, the value
	# stayed zero, and walking away never stopped you chopping. It printed a
	# type error each frame and only CI ever saw it, because a gate that stands
	# still never enters the branch.
	_check(typeof(hero.call("own_speed")) == TYPE_FLOAT,
		"Hero.own_speed must be a number; the gathering swing reads it as one")
	var swing_source := FileAccess.open("res://scripts/systems/gathering.gd", FileAccess.READ)
	if swing_source != null:
		var swing_code: String = swing_source.get_as_text()
		_check(not swing_code.contains("var own_speed: Vector2 = who.call(\"own_speed\")"),
			("the swing must take the hero's speed as a number: typed as a "
				+ "Vector2 the assignment fails silently and walking away "
				+ "never stops the work"))

	# Put the seam back the way it was found, since the harness lives on.
	seam["cooldown"] = 0.0



## **A swing pays the node's sides, and practice widens the take without
## unbounding it** (owner, 2026-09-21: "appropriate chances for all of the
## resources they should provide, which should also include stone, and there
## should be chances to gain increased quantities each mining action with
## randomness that is also scaled by the player's mining level"). Measured by
## driving the real `_land_a_swing` a few hundred times on a copper seam at
## level one and at the cap, against the store and the purse read before and
## after - never by reading the chances back, which would pass with the rolls
## wired to nothing. A novice sees the sides rarely and never more copper than
## the rolls allow; a master sees more of everything and still never past the
## ceiling. The Stone goes through `RunState.gain_currency`, so the trim at the
## door applies to it exactly as to a crate.
const SWINGS: int = 400


func _test_a_swing_pays_what_the_node_holds(patch: Gathering) -> void:
	var seam: GatherNodeData = ContentDB.gather_node("copper_seam")
	if seam == null or patch.node_count() <= 0:
		_check(false, "the copper seam and a dug patch are needed to swing at")
		return
	_check(seam.currency_id == RunState.STONE and seam.currency_chance > 0.0,
		"a copper seam sheds Stone")
	_check(not seam.bonus_material_id.is_empty() and seam.bonus_chance > 0.0
			and ContentDB.material(seam.bonus_material_id) != null,
		"a copper seam holds a gem the store knows")
	var held: bool = MetaState.profession_xp.has(seam.craft)
	var before_xp: float = float(MetaState.profession_xp.get(seam.craft, 0.0))
	var novice: Dictionary = _swing_away(patch, seam, true)
	MetaState.gain_profession_xp(seam.craft, int(MetaState.profession_xp_to_cap()) + 500)
	_check(MetaState.profession_level(seam.craft) == Balance.PROFESSION_MAX_LEVEL,
		"the miner reached the cap for the measurement")
	var master: Dictionary = _swing_away(patch, seam, false)
	if held:
		MetaState.profession_xp[seam.craft] = before_xp
	else:
		MetaState.profession_xp.erase(seam.craft)
	var ceiling: float = float(seam.material_per_swing + Balance.GATHER_BONUS_ROLLS)
	_check(float(novice["ore"]) / float(SWINGS) >= float(seam.material_per_swing),
		"a novice's swing pays at least the authored take (%.2f a swing)"
			% (float(novice["ore"]) / float(SWINGS)))
	_check(float(master["ore"]) > float(novice["ore"]) * 1.15,
		"a master takes more ore from the same seam: %d against %d over %d swings"
			% [master["ore"], novice["ore"], SWINGS])
	_check(float(master["ore"]) / float(SWINGS) <= ceiling,
		"and never past the authored take plus the rolls (%.2f of %.0f a swing)"
			% [float(master["ore"]) / float(SWINGS), ceiling])
	_check(int(master["stone"]) > 0,
		"a master's seam sheds Stone (%d over %d swings)" % [master["stone"], SWINGS])
	_check(int(master["stone"]) > int(novice["stone"]),
		"and more of it than a novice's: %d against %d" % [master["stone"], novice["stone"]])
	_check(int(master["gem"]) >= 1,
		"a master finds the gem in a copper seam now and then (%d over %d swings)"
			% [master["gem"], SWINGS])
	_check(int(novice["gem"]) <= int(master["gem"]),
		"and no more often than a master: %d against %d" % [novice["gem"], master["gem"]])
	print("[gathering] copper seam over %d swings: novice %d ore %d stone %d gem; master %d ore %d stone %d gem"
		% [SWINGS, novice["ore"], novice["stone"], novice["gem"],
			master["ore"], master["stone"], master["gem"]])


## Drives the real swing `SWINGS` times against node zero and returns what the
## store and the purse gained. A novice is held at nothing, because four hundred
## swings of practice would otherwise make a journeyman of the measurement.
func _swing_away(patch: Gathering, seam: GatherNodeData, novice: bool) -> Dictionary:
	var nodes: Array = patch.get("_nodes") as Array
	patch.set("_working", 0)
	var ore_before: int = MetaState.material_count(seam.material_id)
	var gem_before: int = MetaState.material_count(seam.bonus_material_id)
	var stone_before: int = RunState.currency(seam.currency_id)
	for _swing: int in SWINGS:
		# Kept one swing from spent, so the node is never worked out and the
		# respawn clock never starts underneath the measurement.
		(nodes[0] as Dictionary)["left"] = 5
		if novice:
			MetaState.profession_xp[seam.craft] = 0.0
		patch.call("_land_a_swing", seam)
	return {
		"ore": MetaState.material_count(seam.material_id) - ore_before,
		"gem": MetaState.material_count(seam.bonus_material_id) - gem_before,
		"stone": RunState.currency(seam.currency_id) - stone_before,
	}

func _test_the_forge_validates_before_it_spends() -> void:
	MetaState.erase_progress()
	var wood: MaterialData = _one_of(MaterialData.Kind.WOOD)
	var ore: MaterialData = _one_of(MaterialData.Kind.ORE)
	var gem: MaterialData = _one_of(MaterialData.Kind.GEM)
	if wood == null or ore == null or gem == null:
		_check(false, "the forge needs one of each kind of material authored")
		return

	# Measured against what the stash held when this started rather than against
	# empty: a fresh account is not necessarily an empty stash, and an assertion
	# that assumes it is fails for a reason that has nothing to do with the forge.
	var held_before: int = MetaState.stash.size()
	_check(not Forge.refusal(wood.id, ore.id, gem.id).is_empty(),
		"an empty store must refuse")
	var refused: Dictionary = Forge.forge(wood.id, ore.id, gem.id)
	_check(refused.has("error"), "and the forge must say so rather than making something")
	_check(MetaState.materials.is_empty(),
		"a refused forge must spend nothing: %s" % str(MetaState.materials))
	_check(MetaState.stash.size() == held_before, "and make nothing")

	# Wood and ore but no gem: still refused, still spends nothing.
	MetaState.gain_material(wood.id, Balance.FORGE_WOOD_COST)
	MetaState.gain_material(ore.id, Balance.FORGE_ORE_COST)
	_check(Forge.forge(wood.id, ore.id, gem.id).has("error"), "no gem, no piece")
	_check(MetaState.material_count(wood.id) == Balance.FORGE_WOOD_COST
			and MetaState.material_count(ore.id) == Balance.FORGE_ORE_COST,
		"and the wood and ore must still be there")

	# And the wrong kind in the wrong slot is refused rather than accepted.
	_check(not Forge.refusal(ore.id, wood.id, gem.id).is_empty(),
		"ore is not wood and the forge must say so")


## A forged piece is an ordinary piece.
##
## The Smithy is another way onto the loot ladder and never a way past it, which
## is the whole reason materials are allowed to persist. Checked by forging a
## hundred pieces with the best gem a maxed smith can set and reading the
## rarities back.
func _test_a_forged_piece_is_an_ordinary_piece() -> void:
	MetaState.erase_progress()
	var wood: MaterialData = _best_of(MaterialData.Kind.WOOD)
	var ore: MaterialData = _best_of(MaterialData.Kind.ORE)
	var gem: MaterialData = _best_of(MaterialData.Kind.GEM)
	if wood == null or ore == null or gem == null:
		return
	MetaState.gain_profession_xp("smith", int(MetaState.profession_xp_to_cap()))
	var top: int = 0
	var made: int = 0
	var best_seen: int = 0
	for _attempt: int in 100:
		MetaState.gain_material(wood.id, Balance.FORGE_WOOD_COST)
		MetaState.gain_material(ore.id, Balance.FORGE_ORE_COST)
		MetaState.gain_material(gem.id, Balance.FORGE_GEM_COST)
		var piece: Dictionary = Forge.forge(wood.id, ore.id, gem.id)
		if piece.has("error"):
			break
		made += 1
		var rarity: int = int(piece.get("rarity", 0))
		best_seen = maxi(best_seen, rarity)
		if rarity >= Stash.RARITY_NAMES.size() - 1:
			top += 1
		_check(int(piece.get("level", 0)) >= 1 and int(piece.get("level", 0)) <= Stash.MAX_LEVEL,
			"a forged piece's level must be inside the ladder: %d" % int(piece.get("level", 0)))
		_check(rarity >= 0 and rarity < Stash.RARITY_NAMES.size(),
			"and its rarity must be a rarity: %d" % rarity)
		_check(ContentDB.gear(String(piece.get("kind", ""))) != null,
			"and its kind must be a kind of gear")
		_check(piece.has("uid"), "and it must be named, like every other piece")
	_check(made >= 50, "the harness must forge a hundred pieces; it forged %d" % made)
	_check(top == 0,
		("the best gem a maxed smith can set reached the top rarity %d times in %d - "
			+ "the rarest gear is found, not forged") % [top, made])
	_check(best_seen > 0,
		"a maxed smith with the best gem must at least sometimes climb a rung; best was %d"
			% best_seen)
	MetaState.erase_progress()


## A craft touches nothing but its own craft.
##
## The Angler's bound, applied to all four. Levelling and gear are the two capped
## scales the campaign tiers are tuned against; a craft that raised an attribute
## would be a third that nobody is tuning.
func _test_the_crafts_only_craft() -> void:
	MetaState.erase_progress()
	var before: Array[int] = []
	for attribute: int in RunState.Attribute.size():
		before.append(RunState.attribute(attribute))
	for craft: String in Balance.PROFESSIONS:
		MetaState.gain_profession_xp(craft, int(MetaState.profession_xp_to_cap()) + 500)
		_check(MetaState.profession_level(craft) == Balance.PROFESSION_MAX_LEVEL,
			"%s must cap at %d" % [craft, Balance.PROFESSION_MAX_LEVEL])
	for material: MaterialData in ContentDB.materials_sorted():
		MetaState.gain_material(material.id, 500)
	for attribute: int in RunState.Attribute.size():
		_check(RunState.attribute(attribute) == before[attribute],
			("four maxed crafts and a full store changed %s - a craft may change how "
				+ "well the hero does its own thing and nothing about the fight")
				% RunState.attribute_name(attribute))
	_check(MetaState.gain_profession_xp("tanner", 10) == 1
			and not MetaState.profession_xp.has("tanner"),
		"a craft the game does not name must not be trained")
	MetaState.erase_progress()


func _one_of(kind: int) -> MaterialData:
	for material: MaterialData in ContentDB.materials_sorted():
		if material.kind == kind:
			return material
	return null


func _best_of(kind: int) -> MaterialData:
	var best: MaterialData = null
	for material: MaterialData in ContentDB.materials_sorted():
		if material.kind == kind and (best == null or material.rarity > best.rarity):
			best = material
	return best
