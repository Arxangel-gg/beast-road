extends Node

## **Levels on the road's animals and on companions** (owner, 2026-10-08).
##
## Holds: the curve climbs and stops at its cap; an animal arrives at level one
## in the opening act and a little more later, read off its own name; a level
## grows the body and deepens the pool keeping its share; the level is hidden
## until the animal is hurt and shown beside its bar while it is not whole; the
## peaceful learn faster by living than a hunter and by surviving a wound; a
## hunter learns by the damage it deals, a kill, and an assist on a target
## something else finished - a road body and an animal alike; a guest told a
## level grows the same animal and a late guest is told it in the welcome; and a
## companion's level is the account's - one a spirit species and rarity, its own
## for a raised creature, a lower cap for a spirit than for a mortal - read back
## through the save and grown as it fights.

const TAG: String = "[wildlife-level]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var held: String = MetaState.serialized_save()
	_test_the_curves()
	_test_the_arrival()
	await _test_the_road()
	await _test_the_companions()
	for stage: String in ["curves", "arrival", "road", "companions"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	var parsed: Variant = JSON.parse_string(held)
	if parsed is Dictionary:
		MetaState.adopt_save(parsed as Dictionary)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for child: Node in get_children():
		child.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: the curve and its caps, the arrival level, growth that keeps its share, a level hidden until hurt, the peaceful learning by living and the hunter by its teeth, kills and assists, the guest's word, and a companion's level by species and rarity, kept and grown" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_the_curves() -> void:
	for level: int in range(1, Balance.WILDLIFE_LEVEL_MAX):
		_check(WildlifeLevels.xp_to_next(level + 1) > WildlifeLevels.xp_to_next(level),
			"the next wild level costs no more than the last at %d" % level)
	for level: int in range(1, Balance.WILDLIFE_LEVEL_MAX + 1):
		_check(WildlifeLevels.level_for_xp(WildlifeLevels.xp_at(level), Balance.WILDLIFE_LEVEL_MAX) == level,
			"the experience a level begins at reads as level %d"
			% WildlifeLevels.level_for_xp(WildlifeLevels.xp_at(level), Balance.WILDLIFE_LEVEL_MAX))
	_check(WildlifeLevels.level_for_xp(1.0e12, Balance.WILDLIFE_LEVEL_MAX) == Balance.WILDLIFE_LEVEL_MAX,
		"an animal climbed past its cap")
	_check(WildlifeLevels.size_scale(5) > WildlifeLevels.size_scale(1)
		and WildlifeLevels.health_scale(5) > 1.0 and WildlifeLevels.yield_scale(5) > 1.0,
		"a level grows nothing")
	_check(Balance.COMPANION_LEVEL_MAX_PEN > Balance.COMPANION_LEVEL_MAX_SPIRIT,
		"a raised creature, which can die, does not climb higher than a spirit")
	_check(WildlifeLevels.companion_level(1.0e12, false) == Balance.COMPANION_LEVEL_MAX_SPIRIT
		and WildlifeLevels.companion_level(1.0e12, true) == Balance.COMPANION_LEVEL_MAX_PEN,
		"a companion's cap is not the cap its kind is held to")
	_check(WildlifeLevels.time_rate(ContentDB.wildlife_kinds.get("deer") as WildlifeData)
		> WildlifeLevels.time_rate(ContentDB.wildlife_kinds.get("wolf") as WildlifeData),
		"a hunter learns as fast by living as a grazer does")
	_reached.append("curves")


func _test_the_arrival() -> void:
	RunState.reset(false, 20261008)
	var grown: int = 0
	for net_id: int in range(1, 401):
		_check(WildlifeLevels.arrival_level(net_id, 1) == 1, "an animal arrived grown in the opening act")
		var late: int = WildlifeLevels.arrival_level(net_id, 10)
		_check(late >= 1 and late <= 1 + 9 / Balance.WILDLIFE_LEVEL_ARRIVAL_ACTS,
			"an Act X arrival at level %d" % late)
		_check(late == WildlifeLevels.arrival_level(net_id, 10), "one animal arrived at two levels")
		if late > 1:
			grown += 1
	_check(grown > 100, "only %d of 400 Act X arrivals came grown" % grown)
	_reached.append("arrival")


func _test_the_road() -> void:
	RunState.reset(false, 20261008)
	RunState.act = 1
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.sky().events_enabled = false
	field.town.health.floor_hp = field.town.health.max_hp * 0.5
	var animals: Wildlife = field.wildlife()
	animals.clear()
	animals.set("_hush_left", 1.0e9)
	field.hero.global_position = field.town_position()
	await get_tree().process_frame
	var far: Vector2 = field.town_position() + Vector2(1600.0, 1400.0)
	var deer: Dictionary = _stand(animals, "deer", far)
	var wolf: Dictionary = _stand(animals, "wolf", far + Vector2(300.0, 0.0))
	var pup: Dictionary = _stand(animals, "wolf", far + Vector2(500.0, 0.0))
	_check(not deer.is_empty() and not wolf.is_empty() and not pup.is_empty(), "the harness stood no animals")
	if deer.is_empty() or wolf.is_empty() or pup.is_empty():
		run.queue_free()
		return
	var deer_kind := deer["data"] as WildlifeData
	# Hidden while whole.
	_check(int(deer["level"]) == 1, "an opening-act deer arrived at level %d" % int(deer["level"]))
	Wildlife._carry_bar(deer, deer_kind)
	_check(not bool(animals.level_reading(deer)["shown"]), "a whole animal shows its level")
	# A level grows it, keeping its share.
	var size_before: float = float(deer["size"])
	var pool_before: float = Wildlife.pool_of(deer)
	animals.earn(deer, WildlifeLevels.xp_to_next(1) + 0.01)
	_check(int(deer["level"]) == 2, "a deer given a level's experience is level %d" % int(deer["level"]))
	_check(is_equal_approx(float(deer["size"]), size_before * WildlifeLevels.size_scale(2)),
		"a level grew the body to %.3f from %.3f" % [float(deer["size"]), size_before])
	_check(is_equal_approx(Wildlife.pool_of(deer), pool_before * WildlifeLevels.health_scale(2)),
		"a level did not deepen the pool")
	_check(is_equal_approx(float(deer["hp"]), Wildlife.pool_of(deer)), "a whole animal grew into a hurt one")
	_check(String(animals.level_reading(deer)["tag"]) == "Lv 2", "the tag reads '%s'" % animals.level_reading(deer)["tag"])
	# Hurt: the level shows beside the bar, and the wound teaches a grazer.
	var xp_before: float = float(deer["xp"])
	animals.call("_wound", animals.living().find(deer), deer, 4.0, true)
	Wildlife._carry_bar(deer, deer_kind)
	_check(bool(animals.level_reading(deer)["shown"]), "a hurt animal hides its level")
	_check(is_equal_approx(float(deer["xp"]) - xp_before, Balance.WILDLIFE_LEVEL_XP_SURVIVED),
		"a wound survived taught a grazer %.2f" % (float(deer["xp"]) - xp_before))
	deer["hp"] = Wildlife.pool_of(deer)
	(deer["bar"] as ProgressBar).value = 1.0
	Wildlife._carry_bar(deer, deer_kind)
	_check(not bool(animals.level_reading(deer)["shown"]), "a mended animal still shows its level")
	# Living: the peaceful learn faster than a hunter.
	var deer_was: float = float(deer["xp"])
	var wolf_was: float = float(wolf["xp"])
	await _seconds(1.5)
	var deer_gain: float = float(deer["xp"]) - deer_was
	var wolf_gain: float = float(wolf["xp"]) - wolf_was
	_check(deer_gain > 0.0 and wolf_gain > 0.0 and deer_gain > wolf_gain,
		"living a while taught the deer %.3f and the wolf %.3f" % [deer_gain, wolf_gain])
	# Teeth: damage, a kill, an assist - on a road body.
	var wolf_kind := wolf["data"] as WildlifeData
	var body: Enemy = _stand_a_body(field, far + Vector2(0.0, 300.0))
	if body != null:
		await get_tree().process_frame
		var bit: float = float(wolf["xp"])
		animals.call("_strike", wolf, wolf["sprite"], wolf_kind, body)
		_check(float(wolf["xp"]) > bit, "a wolf's bite on a road body taught it nothing")
		animals.call("_strike", pup, pup["sprite"], pup["data"], body)
		var killer_was: float = float(wolf["xp"])
		var helper_was: float = float(pup["xp"])
		body.health.current_hp = 0.5
		animals.call("_strike", wolf, wolf["sprite"], wolf_kind, body)
		_check(float(wolf["xp"]) - killer_was >= Balance.WILDLIFE_LEVEL_XP_KILL,
			"a wolf that killed a road body learned %.2f" % (float(wolf["xp"]) - killer_was))
		_check(is_equal_approx(float(pup["xp"]) - helper_was, Balance.WILDLIFE_LEVEL_XP_ASSIST),
			"a wolf that had bitten it learned %.2f for the assist" % (float(pup["xp"]) - helper_was))
	# And on an animal: the wolf bites a hare, the pup finishes it.
	var hare: Dictionary = _stand(animals, "rabbit", far + Vector2(0.0, -300.0))
	if not hare.is_empty():
		animals.call("_strike", wolf, wolf["sprite"], wolf_kind, hare["sprite"])
		var assist_was: float = float(wolf["xp"])
		var kill_was: float = float(pup["xp"])
		hare["hp"] = 0.1
		animals.call("_strike", pup, pup["sprite"], pup["data"], hare["sprite"])
		_check(float(pup["xp"]) - kill_was >= Balance.WILDLIFE_LEVEL_XP_KILL,
			"a wolf that killed a hare learned %.2f" % (float(pup["xp"]) - kill_was))
		_check(is_equal_approx(float(wolf["xp"]) - assist_was, Balance.WILDLIFE_LEVEL_XP_ASSIST),
			"a wolf that had bitten the hare learned %.2f for the assist" % (float(wolf["xp"]) - assist_was))
	else:
		_check(false, "the harness stood no hare")
	# The guest's word and the welcome.
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/wildlife.gd")
	var family: int = source.find("func _on_coop_family(")
	var word: int = source.find("WildlifeFamilies.Word.LEVEL:", family)
	var grows: int = source.find("grow(animal, value", word)
	_check(family >= 0 and word > family and grows > word and grows - word < 80,
		"a guest told a level does not grow the animal it draws")
	var told: bool = false
	for entry: Array in animals.elite_words():
		if int(entry[0]) == int(deer["net_id"]) and int(entry[1]) == WildlifeFamilies.Word.LEVEL and int(entry[2]) == 2:
			told = true
	_check(told, "a late guest is not told a grown animal's level")
	_check(WildlifeFamilies.Word.LEVEL == 4, "the LEVEL word was inserted rather than appended")
	run.queue_free()
	await get_tree().process_frame
	_reached.append("road")


func _test_the_companions() -> void:
	MetaState.spirit_levels = {}
	var wolf_kind := ContentDB.wildlife_kinds.get("wolf") as WildlifeData
	var common: String = SpiritBond.key("wolf", 0, false)
	var rare: String = SpiritBond.key("wolf", 2, false)
	var rare_shiny: String = SpiritBond.key("wolf", 2, true)
	MetaState.gain_companion_xp(rare, "", WildlifeLevels.companion_xp_at(4))
	_check(MetaState.companion_level(rare) == 4, "a Rare wolf given four levels' experience is %d" % MetaState.companion_level(rare))
	_check(MetaState.companion_level(common) == 1, "a Common wolf took the Rare wolf's level")
	_check(MetaState.companion_level(rare_shiny) == 4, "a shiny Rare wolf is not the Rare wolf's level")
	MetaState.gain_companion_xp(rare, "", 1.0e12)
	_check(MetaState.companion_level(rare) == Balance.COMPANION_LEVEL_MAX_SPIRIT,
		"a spirit climbed to %d past its cap" % MetaState.companion_level(rare))
	# A raised creature: its own, to the higher cap.
	var held_pen: Array[Dictionary] = MetaState.pen.duplicate(true)
	MetaState.pen.clear()
	MetaState.pen.append({"uid": "pen-level", "species": "wolf", "rarity": 2, "shiny": false,
		"trait": "", "health": 1.0, "healed_at": 0.0, "xp": 0.0})
	MetaState.gain_companion_xp(rare, "pen-level", 1.0e12)
	_check(MetaState.companion_level(rare, "pen-level") == Balance.COMPANION_LEVEL_MAX_PEN,
		"a raised wolf reached %d against a cap of %d" % [MetaState.companion_level(rare, "pen-level"),
			Balance.COMPANION_LEVEL_MAX_PEN])
	# Kept, and read back clean.
	var round_trip: Variant = JSON.parse_string(MetaState.serialized_save())
	if round_trip is Dictionary:
		var block: Dictionary = (round_trip as Dictionary)["spirits"] as Dictionary
		(block["levels"] as Dictionary)["nobody|1"] = 50.0
		(block["levels"] as Dictionary)["wolf|9"] = 50.0
		(block["levels"] as Dictionary)["wolf|1"] = 1.0e15
		MetaState.adopt_save(round_trip as Dictionary)
		_check(MetaState.companion_level(rare) == Balance.COMPANION_LEVEL_MAX_SPIRIT,
			"a spirit's level did not come back through the save")
		_check(MetaState.companion_level(rare, "pen-level") == Balance.COMPANION_LEVEL_MAX_PEN,
			"a raised creature's level did not come back through the save")
		_check(not MetaState.spirit_levels.has("nobody|1") and not MetaState.spirit_levels.has("wolf|9"),
			"a save naming no spirit kept a level for it")
		_check(float(MetaState.spirit_levels.get("wolf|1", 0.0)) <= WildlifeLevels.companion_xp_at(Balance.COMPANION_LEVEL_MAX_SPIRIT),
			"a forged experience read back past the spirit's cap")
	else:
		_check(false, "the save did not parse")
	# On the road: a level is a stronger blow and a deeper pool, and fighting grows it.
	MetaState.spirit_levels = {}
	MetaState.pen = held_pen
	RunState.reset(false, 20261008)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	# One rarity at two levels: a rarity's own painting already strikes harder.
	var plain: Companion = _call(field, rare, wolf_kind)
	await get_tree().process_frame
	MetaState.spirit_levels[WildlifeLevels.spirit_level_key(rare)] = WildlifeLevels.companion_xp_at(5)
	var grown: Companion = _call(field, rare, wolf_kind)
	var learner: Companion = _call(field, common, wolf_kind)
	await get_tree().process_frame
	if plain != null and grown != null and learner != null:
		_check(grown.level == 5 and plain.level == 1, "the companions came out at levels %d and %d" % [plain.level, grown.level])
		var ratio: float = float(grown.get("_power")) / maxf(float(plain.get("_power")), 0.001)
		_check(is_equal_approx(ratio, WildlifeLevels.companion_power(5)),
			"a level-five spirit strikes %.3f of a level-one, wanted %.3f" % [ratio, WildlifeLevels.companion_power(5)])
		var deeper: float = float(grown.get("_max_hp")) / maxf(float(plain.get("_max_hp")), 0.001)
		_check(is_equal_approx(deeper, WildlifeLevels.companion_health(5)),
			"a level-five spirit's pool is %.3f of a level-one's" % deeper)
		var power_was: float = float(learner.get("_power"))
		learner.call("_learn", WildlifeLevels.companion_xp_at(3))
		_check(learner.level == 3, "a spirit that fought a level's worth is level %d" % learner.level)
		_check(is_equal_approx(float(learner.get("_power")), power_was * WildlifeLevels.companion_power(3)),
			"a level reached on the road did not grow the blow")
		_check(MetaState.companion_level(common) == 3, "the account did not keep what the spirit learned")
		var hud_source: String = FileAccess.get_file_as_string("res://scenes/ui/hud.gd")
		_check(hud_source.contains("Lv %d\" % [spirit.data.display_name, spirit.level]"),
			"the spirit readout does not say its level")
	else:
		_check(false, "the harness could not call a companion")
	run.queue_free()
	await get_tree().process_frame
	_reached.append("companions")


func _call(field: Battlefield, key: String, kind: WildlifeData) -> Companion:
	if field == null or field.hero == null or kind == null:
		return null
	var spirit := Companion.new()
	spirit.spirit_key = key
	spirit.setup(SpiritBond.companion_form(kind, key), field.hero, field)
	spirit.global_position = field.hero.global_position + Vector2(120.0, 0.0)
	field.entity_root.add_child(spirit)
	return spirit


func _stand(animals: Wildlife, id: String, at: Vector2) -> Dictionary:
	var kind := ContentDB.wildlife_kinds.get(id, null) as WildlifeData
	if kind == null:
		return {}
	var before: int = animals.living().size()
	animals.call("_spawn", kind, at)
	if animals.living().size() <= before:
		return {}
	var animal: Dictionary = animals.living().back()
	var sprite := animal["sprite"] as Sprite2D
	sprite.global_position = at
	animal["state"] = Wildlife.State.SETTLED
	animal["goal"] = at
	return animal


func _stand_a_body(field: Battlefield, at: Vector2) -> Enemy:
	var breed: EnemyData = ContentDB.enemy("bogkin")
	if breed == null:
		return null
	var body: Enemy = field.spawn_enemy(breed, 0, 1.0, 0.0, 0.001)
	if body != null:
		body.global_position = at
	return body


func _seconds(span: float) -> void:
	var waited: float = 0.0
	while waited < span:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
