extends Node

## **Wayside encounters** (2026-09-25, `docs/IDEAS_REVIEW_2026-09-25.md` §4, §8).
##
## An encounter asks, and every answer is a door the game already has. This
## holds the three ways that can be a lie:
##
## - **Authored and unreachable**: a choice nothing offers, an animal encounter
##   whose title has no name in it, a prop with no painting, a price in a
##   currency the purse does not have, a sighting on a prop that has no animal.
## - **A door that moves something other than what it says**: every authored
##   choice is taken for real on the real field and the purse, the ground, the
##   journal, the hero, the savages and the earth are read back - the cost
##   exactly, the boon exactly, and nothing else that was not asked for.
## - **A choice that pays twice, or for free**: refused when the purse is short,
##   refused a second time, refused when it belongs to another encounter.
##
## And the road it is laid on: never in the opening act, never on the Walk,
## always on open ground in the outer band clear of what else answers Interact,
## and the whole flow a player takes - walk up, press, the field freezes, the
## card, a choice, walk on - driven through the real doors.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _wayside: Wayside = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260927)
	_test_the_encounters_are_authored()

	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_wayside = _field.wayside() if _field != null else null
	if _field == null or _wayside == null:
		_check(false, "the harness needs a battlefield with a wayside")
	else:
		if _field.town != null and _field.town.health != null:
			_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
		_test_the_road_lays_them_where_they_belong()
		await _test_every_choice_opens_its_door()
		_test_an_answer_survives_the_bank()
		_test_a_choice_is_paid_once_and_only_for_its_own()
		await _test_the_flow_a_player_takes()
		_test_it_is_re_laid_with_the_region()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures == 0:
		print(("[wayside] PASS - %d checks: authored, laid where they belong, every "
			+ "choice through its own door, paid once, and the whole walk-up") % _checks)
	else:
		push_error("[wayside] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("[wayside] FAIL: " + why)


# --- Authored ----------------------------------------------------------------------

func _test_the_encounters_are_authored() -> void:
	var ids: Array[String] = ContentDB.wayside_ids()
	_check(ids.size() >= 6, "only %d wayside encounters are authored" % ids.size())
	var offered: Dictionary = {}
	var effects_used: Dictionary = {}
	for id: String in ids:
		var data: WaysideData = ContentDB.wayside(id)
		_check(data != null and data.id == id, "the wayside file '%s' does not name itself" % id)
		if data == null:
			continue
		_check(not data.display_name.strip_edges().is_empty() and not data.text.strip_edges().is_empty(),
			"%s says nothing" % id)
		_check(data.first_act >= Balance.WAYSIDE_FIRST_ACT,
			"%s is laid from act %d, before the road lays any" % [id, data.first_act])
		_check(data.weight > 0.0, "%s can never be chosen" % id)
		_check(data.choice_ids.size() >= 2,
			"%s offers %d answers - one answer and walking on is not a choice" % [id, data.choice_ids.size()])
		if data.scene == WaysideData.Scene.ANIMAL:
			_check(data.display_name.contains("%s"), "%s is an animal and its title does not name it" % id)
			_check(not data.title_for("Deer").contains("%"), "%s's title does not take the name" % id)
		else:
			_check(ResourceLoader.exists(data.get_sprite_path()),
				"%s is a prop with no painting at %s" % [id, data.get_sprite_path()])
		for choice_id: String in data.choice_ids:
			var choice: WaysideChoiceData = ContentDB.wayside_choice(choice_id)
			_check(choice != null, "%s offers '%s', which is not authored" % [id, choice_id])
			if choice == null:
				continue
			_check(not offered.has(choice_id), "'%s' is offered by two encounters" % choice_id)
			offered[choice_id] = id
			_check_choice(data, choice)
			effects_used[choice.boon] = true
			effects_used[choice.bane] = true
	for choice_id: Variant in ContentDB.wayside_choices.keys():
		_check(offered.has(String(choice_id)),
			"the choice '%s' is authored and offered by nothing" % String(choice_id))
	# Every door is walked by some authored choice, or the doors below would be
	# tested only in the abstract.
	for effect: int in WaysideChoiceData.Effect.values():
		if effect == WaysideChoiceData.Effect.NOTHING:
			continue
		_check(effects_used.has(effect),
			"no authored choice opens door %s" % WaysideChoiceData.Effect.keys()[effect])


func _check_choice(data: WaysideData, choice: WaysideChoiceData) -> void:
	var what: String = choice.id
	_check(not choice.display_name.strip_edges().is_empty() and not choice.hint.strip_edges().is_empty()
		and not choice.outcome.strip_edges().is_empty(), "%s has no label, hint or outcome" % what)
	if not choice.cost_currency.is_empty() or choice.cost_amount != 0:
		_check(RunState.CURRENCIES.has(choice.cost_currency) and choice.cost_amount > 0,
			"%s is priced %d in '%s'" % [what, choice.cost_amount, choice.cost_currency])
	_check(choice.boon != WaysideChoiceData.Effect.NOTHING, "%s gives nothing" % what)
	if choice.boon == WaysideChoiceData.Effect.CURRENCY:
		_check(RunState.CURRENCIES.has(choice.boon_currency) and choice.boon_amount > 0.0,
			"%s pays %.0f in '%s'" % [what, choice.boon_amount, choice.boon_currency])
	# A bane that pays is a boon wearing a bane's clothes.
	_check(choice.bane in [WaysideChoiceData.Effect.NOTHING, WaysideChoiceData.Effect.SAVAGE,
		WaysideChoiceData.Effect.WRATH], "%s has a bane that gives something" % what)
	for effect: int in [choice.boon, choice.bane]:
		if effect == WaysideChoiceData.Effect.SIGHTING:
			_check(data.scene == WaysideData.Scene.ANIMAL,
				"%s offers a sighting on %s, where there is no animal to see" % [what, data.id])
	if choice.boon in [WaysideChoiceData.Effect.HEAL, WaysideChoiceData.Effect.EXPERIENCE]:
		_check(choice.boon_amount > 0.0 and choice.boon_amount <= 1.0,
			"%s gives %.2f of a whole - a share is at most one" % [what, choice.boon_amount])
	# A choice that costs nothing and risks nothing must not be the obvious
	# answer to everything: it gives no more than one thing.
	if choice.cost().is_empty() and choice.bane == WaysideChoiceData.Effect.NOTHING:
		_check(choice.boon != WaysideChoiceData.Effect.HEAL,
			"%s heals for nothing and risks nothing" % what)


# --- Where it is laid ------------------------------------------------------------------

func _test_the_road_lays_them_where_they_belong() -> void:
	var act_was: int = RunState.act
	var seed_was: int = RunState.run_seed
	var laid: int = 0
	var tried: int = 0
	var ids: Dictionary = {}
	for act: int in range(2, Balance.ACT_COUNT + 2):
		for trial: int in 24:
			RunState.act = act
			RunState.run_seed = 5100 + trial * 37 + act * 1009
			_wayside.scatter()
			tried += 1
			var at: Vector2 = _wayside.position_of()
			if at == Vector2.INF:
				continue
			laid += 1
			ids[_wayside.laid_id()] = true
			var data: WaysideData = ContentDB.wayside(_wayside.laid_id())
			_check(data != null and data.first_act <= act,
				"act %d laid '%s', which opens later" % [act, _wayside.laid_id()])
			var half := Vector2.ONE * BattleGrid.TILE
			_check(Fishing.ground_is_open(_field.grid, Rect2(at - half, half * 2.0), 0),
				"act %d laid an encounter on ground that is not open, at %s" % [act, at])
			for taken: Vector2 in _wayside.avoid:
				_check(at.distance_to(taken) >= Balance.WAYSIDE_SPACING,
					"act %d laid an encounter %.0f from something else that answers Interact"
						% [act, at.distance_to(taken)])
			var extent: float = BattleGrid.play_extent()
			_check(absf(at.x) <= extent and absf(at.y) <= extent,
				"act %d laid an encounter off the field, at %s" % [act, at])
			if data != null and data.scene == WaysideData.Scene.ANIMAL:
				var kind: WildlifeData = ContentDB.wildlife_kinds.get(_wayside.laid_species(), null) as WildlifeData
				_check(kind != null and not kind.is_hostile() and not kind.mythic,
					"an animal encounter laid '%s', which is a hunter or a legend" % _wayside.laid_species())
	var share: float = float(laid) / float(maxi(tried, 1))
	_check(absf(share - Balance.WAYSIDE_CHANCE_PER_ACT) < 0.15,
		"the road laid an encounter in %.0f%% of acts against %.0f%% authored"
			% [share * 100.0, Balance.WAYSIDE_CHANCE_PER_ACT * 100.0])
	_check(ids.size() >= 4, "only %d different encounters were ever laid" % ids.size())
	# The opening act lays nothing, whatever the dice.
	for trial: int in 30:
		RunState.act = 1
		RunState.run_seed = 900 + trial
		_wayside.scatter()
		_check(_wayside.position_of() == Vector2.INF, "the opening act laid an encounter")
	# Nor does the Walk.
	RunState.walking = true
	RunState.act = 4
	for trial: int in 30:
		RunState.run_seed = 1900 + trial
		_wayside.scatter()
		_check(_wayside.position_of() == Vector2.INF, "the Walk laid an encounter")
	RunState.walking = false
	RunState.act = act_was
	RunState.run_seed = seed_was


# --- Every door -------------------------------------------------------------------------

func _test_every_choice_opens_its_door() -> void:
	RunState.act = 4
	var hero: Hero = _field.hero
	for encounter_id: String in ContentDB.wayside_ids():
		var data: WaysideData = ContentDB.wayside(encounter_id)
		for choice_id: String in data.choice_ids:
			var choice: WaysideChoiceData = ContentDB.wayside_choice(choice_id)
			await _take_for_real(data, choice, hero)


## Lays the encounter by the Warden, takes one answer, and reads everything
## back - on the frame it was taken, before a piece is collected or the heat
## cools.
func _take_for_real(data: WaysideData, choice: WaysideChoiceData, hero: Hero) -> void:
	_clear_the_air()
	var at: Vector2 = hero.global_position + Vector2(260.0, 0.0)
	_wayside.lay_for_test(data, at)
	var species: String = _wayside.laid_species()
	RunState.gain_every_currency(5000)
	if hero.health != null:
		hero.health.current_hp = hero.health.max_hp * 0.2
	var before: Dictionary = _read_the_world(species, data.animal_rarity, hero)
	EventBus.wayside_chosen.emit(data.id, choice.id)
	var after: Dictionary = _read_the_world(species, data.animal_rarity, hero)
	var what: String = "%s / %s" % [data.id, choice.id]
	_check(_wayside.is_resolved(), "%s was taken and the encounter is still there" % what)

	# The cost, exactly.
	for currency: String in RunState.CURRENCIES:
		var spent: int = int(before["purse"][currency]) - int(after["purse"][currency])
		var owed: int = int(choice.cost().get(currency, 0))
		_check(spent == owed, "%s took %d %s against a price of %d" % [what, spent, currency, owed])

	var expected: Dictionary = {"loot": {}, "gear": 0, "sightings": 0, "heal": 0.0,
		"xp": 0.0, "savages": 0, "heat": 0.0}
	for pair: Array in [[choice.boon, choice.boon_amount, choice.boon_currency],
			[choice.bane, choice.bane_amount, ""]]:
		var effect: int = int(pair[0])
		var amount: float = float(pair[1])
		match effect:
			WaysideChoiceData.Effect.CURRENCY:
				expected["loot"][String(pair[2])] = int(round(amount * Balance.kill_act_scale(RunState.act)))
			WaysideChoiceData.Effect.GEAR:
				expected["gear"] = maxi(int(amount), 1)
			WaysideChoiceData.Effect.SIGHTING:
				expected["sightings"] = maxi(int(amount), 1)
			WaysideChoiceData.Effect.HEAL:
				expected["heal"] = minf(hero.health.max_hp * amount,
					hero.health.max_hp - float(before["hp"]))
			WaysideChoiceData.Effect.EXPERIENCE:
				# Nothing at the cap: `gain_hero_xp` is a ceiling, and so is this.
				var level_cost: float = RunState.hero_xp_for_level(int(before["level"]))
				expected["xp"] = 0.0 if is_inf(level_cost) else level_cost * amount
			WaysideChoiceData.Effect.SAVAGE:
				expected["savages"] = 1
			WaysideChoiceData.Effect.WRATH:
				expected["heat"] = Balance.WRATH_HEAT_PER_KILL * amount

	for currency: String in RunState.CURRENCIES:
		var laid_down: int = int(after["loot"].get(currency, 0)) - int(before["loot"].get(currency, 0))
		var owed_loot: int = int(expected["loot"].get(currency, 0))
		_check(laid_down == owed_loot, "%s laid %d %s on the ground against %d authored"
			% [what, laid_down, currency, owed_loot])
	_check(int(after["gear"]) - int(before["gear"]) == int(expected["gear"]),
		"%s laid %d gear against %d" % [what, int(after["gear"]) - int(before["gear"]), int(expected["gear"])])
	_check(int(after["sightings"]) - int(before["sightings"]) == int(expected["sightings"]),
		"%s recorded %d sightings against %d"
			% [what, int(after["sightings"]) - int(before["sightings"]), int(expected["sightings"])])
	_check(absf((float(after["hp"]) - float(before["hp"])) - float(expected["heal"])) < 0.5,
		"%s healed %.1f against %.1f" % [what, float(after["hp"]) - float(before["hp"]), float(expected["heal"])])
	_check(absf((float(after["xp"]) - float(before["xp"])) - float(expected["xp"])) < 0.01,
		"%s gave %.3f experience against %.3f" % [what, float(after["xp"]) - float(before["xp"]), float(expected["xp"])])
	_check(int(after["savages"]) - int(before["savages"]) == int(expected["savages"]),
		"%s sent %d savages against %d" % [what, int(after["savages"]) - int(before["savages"]), int(expected["savages"])])
	_check(absf((float(after["heat"]) - float(before["heat"])) - float(expected["heat"])) < 0.0001,
		"%s moved the earth's heat by %.4f against %.4f"
			% [what, float(after["heat"]) - float(before["heat"]), float(expected["heat"])])
	await get_tree().process_frame


func _read_the_world(species: String, rarity: int, hero: Hero) -> Dictionary:
	var purse: Dictionary = {}
	for currency: String in RunState.CURRENCIES:
		purse[currency] = RunState.currency(currency)
	var loot: Dictionary = {}
	var gear: int = 0
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop == null or not is_instance_valid(drop) or drop.is_queued_for_deletion():
			continue
		if not drop.gear.is_empty():
			gear += 1
		elif not drop.currency.is_empty():
			loot[drop.currency] = int(loot.get(drop.currency, 0)) + drop.amount
	var savages: int = 0
	var animals: Wildlife = _field.wildlife_system()
	if animals != null:
		for animal: Dictionary in animals.living():
			if bool(animal.get("savage", false)):
				savages += 1
	var sightings: int = 0
	if not species.is_empty():
		sightings = MetaState.spirit_encounter_count(SpiritBond.key(species, rarity, false))
	var sky: WeatherSky = _field.sky()
	return {
		"purse": purse, "loot": loot, "gear": gear, "savages": savages,
		"sightings": sightings, "hp": hero.health.current_hp if hero.health != null else 0.0,
		"xp": float(RunState.kept.get("xp", 0.0)), "level": RunState.hero_level,
		"heat": float(sky.get("_wrath_heat")) if sky != null else 0.0,
	}


## No savage left over from the last choice, no piece on the ground, the
## animals few enough that one more can always arrive.
func _clear_the_air() -> void:
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		if is_instance_valid(node):
			node.queue_free()
	var animals: Wildlife = _field.wildlife_system()
	if animals != null:
		for animal: Dictionary in animals.living():
			animals.perish(animal)


# --- Banked --------------------------------------------------------------------------------

## **An answered encounter stays answered across a banked front.** The encounter
## is re-laid from the run's seed, so without this a front banked at a crossroad
## and resumed lays the same encounter again - and bank, resume, answer, bank is
## a loop that farms gear. Driven through the real `Expedition.compose` and
## `apply`, because the fault is a field the snapshot forgets.
func _test_an_answer_survives_the_bank() -> void:
	RunState.act = 4
	RunState.wave_number = maxi(RunState.wave_number, 5)
	var found: int = -1
	for trial: int in 80:
		RunState.run_seed = 7700 + trial
		RunState.wayside_answered.clear()
		_wayside.scatter()
		if _wayside.position_of() != Vector2.INF:
			found = RunState.run_seed
			break
	_check(found >= 0, "the harness found no seed that lays an encounter in act 4")
	if found < 0:
		return
	var data: WaysideData = ContentDB.wayside(_wayside.laid_id())
	RunState.gain_every_currency(5000)
	var unanswered: Dictionary = Expedition.compose(_field)
	EventBus.wayside_chosen.emit(data.id, data.choice_ids[0])
	_check(RunState.wayside_answered.has(4), "answering the encounter was not recorded")
	var banked: Dictionary = Expedition.compose(_field)
	RunState.wayside_answered.clear()
	_check(Expedition.apply(banked), "the harness could not put the front back down")
	_wayside.scatter()
	_check(_wayside.position_of() == Vector2.INF,
		"a resumed front laid an encounter it had already answered")
	# And one banked before it was answered still has it to answer.
	_check(Expedition.apply(unanswered), "the harness could not put the earlier front back down")
	_wayside.scatter()
	_check(_wayside.position_of() != Vector2.INF and _wayside.laid_id() == data.id,
		"a front banked before its encounter was answered lost the encounter")
	# A new road forgets it all.
	RunState.wayside_answered.append(4)
	RunState.reset(false, found)
	_check(RunState.wayside_answered.is_empty(), "a new road remembers the last road's answers")


# --- Paid once ---------------------------------------------------------------------------

func _test_a_choice_is_paid_once_and_only_for_its_own() -> void:
	var cart: WaysideData = ContentDB.wayside("overturned_cart")
	var cairn: WaysideData = ContentDB.wayside("offering_cairn")
	if cart == null or cairn == null:
		_check(false, "the harness wants the cart and the cairn")
		return
	var at: Vector2 = _field.hero.global_position + Vector2(260.0, 0.0)

	# Short: the price is refused whole and nothing moves.
	_wayside.lay_for_test(cart, at)
	var right: WaysideChoiceData = ContentDB.wayside_choice("cart_right")
	RunState.currencies[right.cost_currency] = right.cost_amount - 1
	var gear_before: int = _gear_on_the_ground()
	EventBus.wayside_chosen.emit(cart.id, right.id)
	_check(not _wayside.is_resolved(), "an answer the purse could not pay for was taken")
	_check(RunState.currency(right.cost_currency) == right.cost_amount - 1,
		"an answer the purse could not pay for took something anyway")
	_check(_gear_on_the_ground() == gear_before, "an answer that was not paid for laid gear")

	# Another encounter's answer is not this one's.
	RunState.gain_every_currency(5000)
	EventBus.wayside_chosen.emit(cart.id, "cairn_take")
	_check(not _wayside.is_resolved(), "the cart took an answer that belongs to the cairn")

	# Once taken, never again.
	EventBus.wayside_chosen.emit(cart.id, "cart_strip")
	_check(_wayside.is_resolved(), "the cart's own answer was refused")
	var gold: int = RunState.currency(RunState.GOLD)
	var loot_before: int = _loot_on_the_ground(RunState.GOLD)
	EventBus.wayside_chosen.emit(cart.id, "cart_strip")
	_check(_loot_on_the_ground(RunState.GOLD) == loot_before and RunState.currency(RunState.GOLD) == gold,
		"an answered encounter paid a second time")


func _gear_on_the_ground() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop != null and is_instance_valid(drop) and not drop.is_queued_for_deletion() \
				and not drop.gear.is_empty():
			count += 1
	return count


func _loot_on_the_ground(currency: String) -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop != null and is_instance_valid(drop) and not drop.is_queued_for_deletion() \
				and drop.currency == currency:
			total += drop.amount
	return total


# --- The walk-up --------------------------------------------------------------------------

## Walk up, press Interact, the field freezes, the card, a choice, walk on. Every
## step through the door a player uses.
func _test_the_flow_a_player_takes() -> void:
	var hero: Hero = _field.hero
	var cairn: WaysideData = ContentDB.wayside("offering_cairn")
	_clear_the_air()
	RunState.gain_every_currency(5000)
	var at: Vector2 = hero.global_position + Vector2(40.0, 0.0)
	_wayside.lay_for_test(cairn, at)
	var heard: Array[String] = []
	var said: Array[String] = []
	var reached := func(id: String, _title: String) -> void: heard.append(id)
	var prompt := func(text: String, _button: String) -> void: said.append(text)
	EventBus.wayside_reached.connect(reached)
	EventBus.interact_prompt.connect(prompt)
	for _frame: int in 4:
		await get_tree().process_frame
	_check(said.size() > 0 and said[said.size() - 1].contains(cairn.display_name),
		"standing at the cairn prompts nothing that names it (%s)" % str(said))

	var was: HeroInput = hero.input
	var pressing := PressedInput.new(hero)
	pressing.press = HeroInput.BUTTON_INTERACT
	hero.input = pressing
	for _frame: int in 3:
		await get_tree().process_frame
	pressing.press = 0
	hero.input = was
	EventBus.wayside_reached.disconnect(reached)
	EventBus.interact_prompt.disconnect(prompt)
	_check(heard.size() == 1 and heard[0] == cairn.id,
		"a press at the cairn reached %s rather than the cairn once" % str(heard))
	var card: WaysideCard = _run.wayside_card()
	_check(card != null and card.showing() == cairn.id, "the press opened no card")
	_check(_field.is_suspended(), "the field runs on under the card")
	if card == null:
		return
	# The first answer the player can afford, pressed on the card itself.
	var rows: Node = card.find_child("Choices", true, false)
	var take: Button = null
	for row: Node in rows.get_children():
		var button := row.get_node_or_null("Take") as Button
		if button != null and not button.disabled:
			take = button
			break
	_check(take != null, "the card offers nothing the Warden can take")
	if take != null:
		take.pressed.emit()
	_check(_wayside.is_resolved(), "an answer pressed on the card did not reach the encounter")
	var outcome := card.find_child("Outcome", true, false) as Label
	_check(outcome != null and outcome.visible and not outcome.text.is_empty(),
		"the card did not say what came of it")
	var leave := card.find_child("Leave", true, false) as Button
	leave.pressed.emit()
	_check(not card.visible, "walking on left the card up")
	_check(not _field.is_suspended(), "walking on left the field frozen")

	# A price the purse cannot meet is on the card, dimmed.
	_wayside.lay_for_test(cairn, at)
	for currency: String in RunState.CURRENCIES:
		RunState.currencies[currency] = 0
	card.open(cairn, cairn.display_name)
	var give := rows.get_node_or_null("cairn_give/Take") as Button
	_check(give != null and give.disabled, "a price the purse cannot meet is offered anyway")
	_check(give != null and give.text.contains("25"), "a dimmed answer hides its price")
	card.close()


# --- Re-laid with the region ------------------------------------------------------------

## The encounter is the act's: `refresh_terrain` re-lays it, or the road carries
## Act II's cart into Act IX. A source walk, because the fault is an omission
## from the one function everything regional goes through.
func _test_it_is_re_laid_with_the_region() -> void:
	var source: String = FileAccess.get_file_as_string("res://scenes/battlefield/battlefield.gd")
	var start: int = source.find("func refresh_terrain")
	var end: int = source.find("\nfunc ", start + 10)
	var body: String = source.substr(start, end - start) if start >= 0 else ""
	_check(body.contains("_wayside.scatter()"), "refresh_terrain does not re-lay the wayside")


class PressedInput extends HeroInput:
	var press: int = 0

	func _read_press(button: int) -> bool:
		return press & button != 0

	func _read_hold(_mask: int) -> bool:
		return false

	func is_local() -> bool:
		return true
