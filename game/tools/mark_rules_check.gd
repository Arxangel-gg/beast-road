extends Node

## **Marks that read the world, and tiers that are rules** (2026-09-25).
##
## `docs/IDEAS_REVIEW_2026-09-25.md` §1, §6 and §7: one door every mark is rolled
## through, where the weather chooses and one draw is spent a pick; a tier that
## marks a share of the ordinary road, lifted by the earth's anger and capped,
## and nothing at all on Normal; a boss that wears a mark's behaviour and never
## its size; four new marks - Frenzied, Packbound, Stormbound, Mirrorhide; the
## speed a mark authors actually applied; and the earth's floor by tier.
##
## Driven through the real doors on a real run: bodies stood up by the spawn
## door, a tower's own `_hit`, a body's own death, the sky's own act change.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _arcs: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260925)
	RunState.tier_id = "normal"

	_test_normal_is_untouched()
	_test_even_weights_deal_what_they_always_dealt()
	_test_one_draw_a_pick()
	_test_the_weather_chooses()
	_test_wrath_lifts_and_caps()
	_test_a_tier_marks_a_share()
	_test_the_door_is_one()

	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		_check(false, "the harness needs a battlefield")
	else:
		if _field.town != null and _field.town.health != null:
			_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
		RunState.gain_every_currency(20000)
		EventBus.world_hazard.connect(_on_hazard)
		_test_speed_marks_move()
		_test_frenzy()
		_test_a_boss_wears_behaviour_not_size()
		_test_a_marked_common_wears_an_outline_not_a_rank()
		_test_packbound_hears_only_kin()
		await _test_stormbound_leaps()
		await _test_mirrorhide_glances_towers_and_not_the_warden()
		_test_the_tier_floor_holds()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	GameDirector.run_active = false
	RunState.tier_id = "normal"
	MetaState.resume_saves()
	if _failures == 0:
		print(("[mark-rules] PASS - %d checks: one door, the weather chooses, a tier "
			+ "marks a share, a boss wears behaviour, and four new marks do what they say")
			% _checks)
	else:
		push_error("[mark-rules] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[mark-rules] FAIL: %s" % why)


func _on_hazard(kind: String, _payload: Dictionary) -> void:
	if kind == "chain":
		_arcs += 1


# --- The door -----------------------------------------------------------------------

## **Normal is where every curve is measured, so Normal moves nothing.** No
## share, no boss marks, no floor - and a marked-common roll on Normal draws
## nothing from the rank stream, so a seeded Normal road deals what it always
## dealt.
func _test_normal_is_untouched() -> void:
	var normal: CampaignTierData = ContentDB.tier("normal")
	_check(normal != null, "there is no Normal tier")
	if normal == null:
		return
	_check(normal.marked_share == 0.0 and normal.marks_max == 0
			and normal.boss_marks == 0 and normal.wrath_floor == 0.0,
		"Normal carries a rule - every curve in the project is measured there")
	_check(EnemyMarks.marked_share(normal, 1.5) == 0.0,
		"the earth's anger marked bodies on Normal")
	var director := WaveDirector.new()
	var stream: RandomNumberGenerator = RunState.rng("rank")
	var before: int = stream.state
	for _i: int in 200:
		var worn: Array = director.call("_roll_marked_common")
		_check(worn.is_empty(), "Normal marked an ordinary body")
	_check(stream.state == before,
		"a marked-common roll on Normal drew from the rank stream - every seeded road moves")
	director.free()


## **The same pick when nothing is favoured.** The old roll was
## `randi() % pool.size()`; under a weather nothing favours, the door must deal
## exactly that, draw for draw.
func _test_even_weights_deal_what_they_always_dealt() -> void:
	for act: int in [1, 4, 7, 10]:
		var a := RandomNumberGenerator.new()
		var b := RandomNumberGenerator.new()
		a.seed = 7300 + act
		b.seed = 7300 + act
		var rolled: Array[EnemyAffixData] = EnemyMarks.roll(3, act, "", a)
		var pool: Array[EnemyAffixData] = EnemyMarks.pool(act)
		var expected: Array[String] = []
		for _i: int in mini(3, pool.size()):
			var pick: int = b.randi() % pool.size()
			expected.append(pool[pick].id)
			pool.remove_at(pick)
		var got: Array[String] = []
		for affix: EnemyAffixData in rolled:
			got.append(affix.id)
		_check(got == expected,
			"act %d with no favoured weather dealt %s where the old roll dealt %s"
				% [act, str(got), str(expected)])


## **One draw a pick, whatever the weights**, so the rank stream is exactly as
## far along as it was and every later roll on it lands where it did.
func _test_one_draw_a_pick() -> void:
	for weather: String in ["", "snowfall", "clear", "heatwave"]:
		var a := RandomNumberGenerator.new()
		var b := RandomNumberGenerator.new()
		a.seed = 99
		b.seed = 99
		EnemyMarks.roll(2, 10, weather, a)
		b.randi()
		b.randi()
		_check(a.state == b.state,
			"two marks under '%s' spent other than two draws" % weather)


## **The weather chooses.** Under a snowfall the Rimewarded come up several
## times as often; under a sky nothing favours, as often as anything else.
func _test_the_weather_chooses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var in_snow: int = 0
	var in_haze: int = 0
	for _i: int in 6000:
		if EnemyMarks.roll(1, 10, "snowfall", rng)[0].id == "rimewarded":
			in_snow += 1
		if EnemyMarks.roll(1, 10, "", rng)[0].id == "rimewarded":
			in_haze += 1
	_check(in_haze > 0, "the Rimewarded never came up at all")
	var ratio: float = float(in_snow) / float(maxi(in_haze, 1))
	_check(ratio > Balance.MARK_WEATHER_FAVOUR * 0.5,
		("the snow made the Rimewarded only %.2f times as likely (%d against %d) - "
			+ "the weather is not choosing") % [ratio, in_snow, in_haze])
	# And every mark that names a weather names a real one, or it is favoured
	# under a sky that never comes.
	for value: Variant in ContentDB.affixes.values():
		var affix := value as EnemyAffixData
		for id: String in affix.favoured_weather:
			_check(ContentDB.weather(id) != null,
				"%s favours '%s', which is no weather" % [affix.id, id])


## The anger lifts the share, and the ceiling holds.
func _test_wrath_lifts_and_caps() -> void:
	var hell: CampaignTierData = ContentDB.tier("hell")
	_check(hell != null and hell.marked_share > 0.0, "Hell marks nothing")
	if hell == null:
		return
	var calm: float = EnemyMarks.marked_share(hell, 0.0)
	var angry: float = EnemyMarks.marked_share(hell, 1.0)
	var furious: float = EnemyMarks.marked_share(hell, 50.0)
	_check(is_equal_approx(calm, hell.marked_share),
		"a calm earth changed Hell's share to %.3f" % calm)
	_check(angry > calm, "the earth's anger marked no more of the road")
	_check(furious <= Balance.MARK_SHARE_CEILING + 0.0001,
		"the share passed its ceiling at %.3f" % furious)


## **A tier marks a share**, one to `marks_max` marks each, never the same one
## twice on a body.
func _test_a_tier_marks_a_share() -> void:
	for tier_id: String in ["nightmare", "hell"]:
		var tier: CampaignTierData = ContentDB.tier(tier_id)
		if tier == null:
			_check(false, "there is no %s tier" % tier_id)
			continue
		RunState.tier_id = tier_id
		RunState.act = 8
		var director := WaveDirector.new()
		var marked: int = 0
		var trials: int = 4000
		var widest: int = 0
		for _i: int in trials:
			var worn: Array = director.call("_roll_marked_common")
			if worn.is_empty():
				continue
			marked += 1
			widest = maxi(widest, worn.size())
			var ids: Dictionary = {}
			for affix: EnemyAffixData in worn:
				ids[affix.id] = true
			_check(ids.size() == worn.size(), "%s wore one mark twice" % tier_id)
		var share: float = float(marked) / float(trials)
		_check(absf(share - tier.marked_share) < 0.04,
			"%s marked %.3f of the road against its rule of %.3f"
				% [tier_id, share, tier.marked_share])
		_check(widest <= tier.marks_max and widest >= 1,
			"%s dealt a body %d marks against its rule of %d" % [tier_id, widest, tier.marks_max])
		director.free()
	RunState.tier_id = "normal"
	RunState.act = 1


## **One door.** Nothing else picks a mark out of the content: a second copy of
## "which mark comes up" is how one of them ends up ignoring the weather.
func _test_the_door_is_one() -> void:
	var roots: PackedStringArray = ["res://scenes", "res://scripts", "res://autoload"]
	var offenders: PackedStringArray = []
	for root: String in roots:
		for path: String in _scripts_under(root):
			if path.ends_with("enemy_marks.gd") or path.ends_with("codex_screen.gd") \
					or path.ends_with("content_db.gd") or path.ends_with("ContentDB.gd"):
				continue
			var text: String = FileAccess.get_file_as_string(path)
			# Iterating the marks is picking one; looking one up by name is not.
			var iterates: bool = text.contains("ContentDB.affixes.keys()") or text.contains("ContentDB.affixes.values()")
			if iterates or text.contains("in ContentDB.affixes"):
				offenders.append(path)
	_check(offenders.is_empty(),
		"marks are picked outside EnemyMarks in %s" % ", ".join(offenders))
	var waves: String = FileAccess.get_file_as_string("res://scripts/systems/wave_director.gd")
	var boss: String = FileAccess.get_file_as_string("res://scripts/systems/boss_director.gd")
	_check(waves.contains("EnemyMarks.roll(") and boss.contains("EnemyMarks.roll("),
		"the waves or the boss roll marks some other way")


func _scripts_under(root: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		var path: String = root + "/" + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_scripts_under(path))
		elif entry.ends_with(".gd"):
			out.append(path)
		entry = dir.get_next()
	return out


# --- The bodies ------------------------------------------------------------------------

func _stand(breed_id: String, marks: Array[String], at: Vector2) -> Enemy:
	var worn: Array[EnemyAffixData] = []
	for id: String in marks:
		var affix := ContentDB.affixes.get(id, null) as EnemyAffixData
		_check(affix != null, "there is no mark '%s'" % id)
		if affix != null:
			worn.append(affix)
	var breed: EnemyData = ContentDB.enemy(breed_id)
	if breed == null:
		_check(false, "there is no breed '%s'" % breed_id)
		return null
	var body: Enemy = _field.spawn_enemy(breed, 0, 1.0, 1.0, 1.0, false,
		Enemy.Rank.COMMON, worn)
	if body != null:
		body.global_position = at
	return body


func _free(bodies: Array) -> void:
	for body: Variant in bodies:
		if body != null and is_instance_valid(body):
			(body as Node).queue_free()


## **The speed a mark authors, applied** - and capped. It had been authored on
## twelve marks and applied by nothing until this date.
func _test_speed_marks_move() -> void:
	var at := Vector2(-2400.0, 1800.0)
	var plain: Enemy = _stand("bogkin", [], at)
	var swift: Enemy = _stand("bogkin", ["swiftfoot"], at + Vector2(60.0, 0.0))
	var both: Enemy = _stand("bogkin", ["swiftfoot", "galeshod"], at + Vector2(120.0, 0.0))
	if plain == null or swift == null or both == null:
		_free([plain, swift, both])
		return
	var base: float = plain.targeting_speed()
	var swift_mark := ContentDB.affixes.get("swiftfoot", null) as EnemyAffixData
	_check(absf(swift.targeting_speed() - base * swift_mark.speed_scale) < 0.5,
		("a Swiftfoot body walks at %.1f where its mark says %.1f - the mark's "
			+ "speed is applied by nothing") % [swift.targeting_speed(),
				base * swift_mark.speed_scale])
	_check(both.targeting_speed() <= base * Balance.ENEMY_MARK_SPEED_MAX + 0.5,
		"two speed marks multiplied past the cap: %.1f against %.1f"
			% [both.targeting_speed(), base * Balance.ENEMY_MARK_SPEED_MAX])
	_free([plain, swift, both])


## **Frenzied**: whole, its breed's pace; under its threshold, faster by its own
## authored share.
func _test_frenzy() -> void:
	var body: Enemy = _stand("bogkin", ["frenzied"], Vector2(-2300.0, 1900.0))
	if body == null:
		return
	var mark := ContentDB.affixes.get("frenzied", null) as EnemyAffixData
	var whole: float = body.targeting_speed()
	body.health.current_hp = body.health.max_hp * (mark.frenzy_below * 0.5)
	var hurt: float = body.targeting_speed()
	_check(absf(hurt - whole * mark.frenzy_speed) < 0.5,
		"a frenzied body under its threshold walks at %.1f, not %.1f"
			% [hurt, whole * mark.frenzy_speed])
	body.health.current_hp = body.health.max_hp
	_check(absf(body.targeting_speed() - whole) < 0.01,
		"a whole Frenzied body is faster than its breed")
	_free([body])


## **A boss wears a mark's behaviour and never its size.** Ironhide makes a road
## body tougher; on a boss the pool is the pool.
func _test_a_boss_wears_behaviour_not_size() -> void:
	var terrain: TerrainData = ContentDB.terrain_for_act(1)
	var boss: EnemyData = ContentDB.enemy(terrain.boss_id) if terrain != null else null
	if boss == null:
		_check(false, "the harness needs the first act's boss")
		return
	var ironhide := ContentDB.affixes.get("ironhide", null) as EnemyAffixData
	var worn: Array[EnemyAffixData] = [ironhide]
	var none: Array[EnemyAffixData] = []
	var plain: Enemy = _field.spawn_enemy(boss, 0, 1.0, 1.0, 1.0, false,
		Enemy.Rank.COMMON, none)
	var marked: Enemy = _field.spawn_enemy(boss, 1, 1.0, 1.0, 1.0, false,
		Enemy.Rank.COMMON, worn)
	if plain == null or marked == null:
		_check(false, "a boss would not stand")
		_free([plain, marked])
		return
	_check(not marked.affixes.is_empty(), "a boss spawned with a mark wears none")
	_check(is_equal_approx(marked.health.max_hp, plain.health.max_hp),
		("a boss wearing Ironhide has %.0f health against %.0f - a mark's size "
			+ "reached a boss") % [marked.health.max_hp, plain.health.max_hp])
	_check(absf(marked.targeting_speed() - plain.targeting_speed()) < 0.01,
		"a boss wearing a mark walks at another pace")
	# And the same mark does make a road body tougher, or the check above
	# proves nothing.
	var road_plain: Enemy = _stand("bogkin", [], Vector2(-2600.0, 2000.0))
	var road_marked: Enemy = _stand("bogkin", ["ironhide"], Vector2(-2660.0, 2000.0))
	if road_plain != null and road_marked != null:
		_check(road_marked.health.max_hp > road_plain.health.max_hp,
			"Ironhide made a road body no tougher, so the boss check proves nothing")
	_free([plain, marked, road_plain, road_marked])


## **An outline, not a rank**: a marked ordinary body is its breed at its size,
## wearing the mark's colour and its name.
func _test_a_marked_common_wears_an_outline_not_a_rank() -> void:
	var plain: Enemy = _stand("bogkin", [], Vector2(-2500.0, 2100.0))
	var marked: Enemy = _stand("bogkin", ["cruel"], Vector2(-2560.0, 2100.0))
	if plain == null or marked == null:
		_free([plain, marked])
		return
	_check(marked.rank == Enemy.Rank.COMMON, "a marked common was promoted to a rank")
	_check(marked.affixes.size() == 1, "a marked common wears %d marks, not 1" % marked.affixes.size())
	_check(marked.sprite.scale.is_equal_approx(plain.sprite.scale),
		"a marked common grew like an elite")
	_check(marked.promoted_name().contains("Cruel"),
		"a marked common does not say its mark: '%s'" % marked.promoted_name())
	_free([plain, marked])


## **Packbound**: its own breed hears it and nothing else does.
func _test_packbound_hears_only_kin() -> void:
	var at := Vector2(-2200.0, 2300.0)
	var caller: Enemy = _stand("bogkin", ["packbound"], at)
	var kin: Enemy = _stand("bogkin", [], at + Vector2(50.0, 0.0))
	var other_breed: String = "wolf_rider"
	var stranger: Enemy = _stand(other_breed, [], at + Vector2(-50.0, 0.0))
	if caller == null or kin == null or stranger == null:
		_free([caller, kin, stranger])
		return
	_field.roster_changed()
	var kin_haste: float = float(kin.call("_ally_aura", &"aura_speed"))
	var stranger_haste: float = float(stranger.call("_ally_aura", &"aura_speed"))
	_check(kin_haste > 0.0, "a Packbound body's own kind did not hear it")
	_check(stranger_haste == 0.0,
		"a Packbound body's aura reached another breed (%.2f)" % stranger_haste)
	_free([caller, kin, stranger])


## **Stormbound**: the blast's own damage leaps to the nearest few of the
## player's side and nobody else, as the sky's own arc.
func _test_stormbound_leaps() -> void:
	var hero: Hero = _field.hero
	if hero == null or hero.health == null:
		_check(false, "the harness needs a hero")
		return
	hero.health.max_hp = 100000.0
	hero.health.current_hp = 100000.0
	var mark := ContentDB.affixes.get("stormbound", null) as EnemyAffixData
	var body: Enemy = _stand("bogkin", ["stormbound"],
		hero.global_position + Vector2(mark.death_blast_radius * 0.5, 0.0))
	if body == null:
		return
	_arcs = 0
	var before: float = hero.health.current_hp
	body.health.kill(hero.global_position)
	await get_tree().process_frame
	var taken: float = before - hero.health.current_hp
	_check(_arcs == 1, "a Stormbound death beside one Warden threw %d arcs, not 1" % _arcs)
	_check(taken > 0.0 and taken <= mark.death_blast_damage + 0.01,
		"a Stormbound death took %.1f from the Warden against its blast of %.1f"
			% [taken, mark.death_blast_damage])
	# Out of reach, nothing leaps.
	var far: Enemy = _stand("bogkin", ["stormbound"],
		hero.global_position + Vector2(mark.death_blast_radius * 3.0, 0.0))
	if far != null:
		_arcs = 0
		before = hero.health.current_hp
		far.health.kill(far.global_position)
		await get_tree().process_frame
		_check(_arcs == 0 and is_equal_approx(before, hero.health.current_hp),
			"a Stormbound death out of reach still struck the Warden")


## **Mirrorhide**: in its window a tower's own blow glances and the Warden's
## lands; out of it, the tower's lands.
func _test_mirrorhide_glances_towers_and_not_the_warden() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var tower_data: TowerData = ContentDB.tower("ember_spire")
	var anchor: Vector2i = _field.free_anchor_near(0, 8)
	var problem: String = _field.try_build(anchor, tower_data)
	_check(problem.is_empty(), "the harness could not build a tower (%s)" % problem)
	await get_tree().process_frame
	var tower: Tower = _field.tower_at_anchor(anchor)
	if tower == null:
		_check(false, "no tower stood where it was built")
		return
	var body: Enemy = _stand("bogkin", ["mirrorhide"], tower.origin() + Vector2(90.0, 0.0))
	if body == null:
		return
	body.health.max_hp = 100000.0
	body.health.current_hp = 100000.0
	# Into the window, on the mark's own clock.
	body.set("_glance_clock", 0.5)
	body.call("_tick_glance", 0.0)
	_check(body.glances_tower_shots(), "a Mirrorhide body never opened its window")
	var before: float = body.health.current_hp
	tower.call("_hit", body)
	_check(is_equal_approx(before, body.health.current_hp),
		"a tower's shot landed on a Mirrorhide body in its window")
	body.take_damage(40.0, _field.hero.global_position, 0.0, true)
	_check(body.health.current_hp < before,
		"the Warden's blow glanced off a Mirrorhide body - the answer to a mirror is the person")
	# Out of the window, the tower lands.
	var mark := ContentDB.affixes.get("mirrorhide", null) as EnemyAffixData
	body.set("_glance_clock", mark.tower_glance_seconds + 0.5)
	body.call("_tick_glance", 0.0)
	_check(not body.glances_tower_shots(), "a Mirrorhide window never closed")
	before = body.health.current_hp
	tower.call("_hit", body)
	_check(body.health.current_hp < before, "a tower's shot missed a Mirrorhide body out of its window")
	_free([body])
	_field.try_sell(anchor)


## **The earth's floor by tier**: where it opens, and what an act's easing
## cannot take away.
func _test_the_tier_floor_holds() -> void:
	var sky: WeatherSky = _field.sky()
	if sky == null:
		_check(false, "the harness needs the sky")
		return
	RunState.tier_id = "hell"
	var lowest: float = WeatherSky.tier_floor()
	var hell: CampaignTierData = ContentDB.tier("hell")
	_check(hell != null and is_equal_approx(lowest, hell.wrath_floor) and lowest > 0.0,
		"Hell's earth opens at %.2f" % lowest)
	sky.set("_wrath_floor", lowest)
	sky.set("_wrath_heat", 0.0)
	sky.call("_on_act_started", 2, "")
	_check(sky.wrath() >= lowest - 0.0001,
		"an act's easing took the earth below Hell's floor (%.3f)" % sky.wrath())
	RunState.tier_id = "normal"
	_check(WeatherSky.tier_floor() == 0.0, "Normal's earth has a floor")
