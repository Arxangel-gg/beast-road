extends Node

## The frontier: banked, restored, and at risk.
##
##   godot --headless --path game res://tools/expedition_check.tscn
##
## Owner brief, 2026-09-15: *"if a player successfully extracts, they will be
## able to start the next run fresh from there with the same resources they had
## when they left that run ... all of the towers and their placements will be
## restored including their levels ... except for the wildlife and foliage etc"*.
##
## **The two rules everything here rests on:**
##
## - **Only a successful extraction banks.** A snapshot taken mid-wave is a
##   save-scum, and the whole tension of the crossroads is that what happened
##   since the last one is at risk.
## - **A wipe does not clear the frontier.** That is the anti-frustration rule -
##   everything before the last crossroads is banked - and it is the difference
##   between pushing deeper being exciting and being horrifying.
##
## **And one bound that is easy to lose:** an expedition carries the *road* and
## never the *account*. No hero level, no gear, no attribute, no unlock - working
## rule 7's list is untouched. What is now resumable is the world, not the
## Warden, and a snapshot that started carrying account progress would be a
## second save game wearing a checkpoint's clothes.
##
## **The silent failures:**
##
## - **A half-applied snapshot.** One naming a tower that no longer exists must
##   be refused whole, because half a fortress is worse than none - the player
##   cannot tell which half is missing.
## - **Free repairs.** If extraction healed the fortifications, the correct play
##   is to leave the moment anything is damaged and attrition stops existing.
## - **Momentum reaching a fight.** It is bought by refusing to save; if it moved
##   `hero_damage` or `tower_damage`, `curve_report` would be measuring a game
##   that only exists for players who never bank.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_a_snapshot_is_refused_or_whole()
	_test_momentum_stays_out_of_the_fight()
	_test_a_worn_gate_is_offered_a_mend()
	await _test_banking_and_coming_back()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[expedition] PASS - %d checks: a front is banked whole or "
			+ "refused whole, the fortress comes back as hurt as it was left, "
			+ "the account is untouched, and momentum never reaches a fight")
			% _checks)
	else:
		push_error("[expedition] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **A worn gate is a front that needs mending** (owner, 2026-09-22: the Hold
## should sell the repair *"if a successful extract is available to continue
## its run and it requires mending"*).
##
## Both screens asked `fortifications().y`, which counts **towers**, while
## `repair_bill` has priced the gate since 2026-09-20 - so a front that came
## home behind a broken wall with every emplacement whole was offered no mend
## anywhere, and the purchase that would have worked was never reached. The
## question is the bill's, and this holds the four corners of it.
func _test_a_worn_gate_is_offered_a_mend() -> void:
	var whole: Dictionary = {
		"seed": 1, "act": 2, "wave": 9, "wall": 1.0, "towers": [],
		"currencies": {}, "momentum": 0.0,
	}
	_check(not Expedition.needs_mending(whole),
		"a whole front is not offered a mend")

	var worn: Dictionary = whole.duplicate(true)
	worn["wall"] = 0.42
	_check(Expedition.needs_mending(worn),
		"a worn gate with no towers at all must still want mending")
	_check(Expedition.hurt_summary(worn).contains("gate"),
		"and the button must say it is the gate, said '%s'"
			% Expedition.hurt_summary(worn))
	_check(Expedition.fortifications(worn).y == 0,
		"the tower count is zero here, which is exactly why it cannot be the "
			+ "question")

	# And the mend puts it right, which is what clears the fires on the way
	# back in - see `Expedition.wall_share`.
	var mended: Dictionary = Expedition.mend(worn)
	_check(is_equal_approx(Expedition.wall_share(mended), 1.0),
		"mending must set the gate whole, left at %.2f"
			% Expedition.wall_share(mended))
	_check(not Expedition.needs_mending(mended),
		"and a mended front is not offered one again")

	# A hurt tower and a whole gate says towers, and both says both.
	var tower: Dictionary = whole.duplicate(true)
	tower["towers"] = [{"kind": "ember_spire", "level": 1, "health": 0.5,
		"anchor": Vector2i(1, 1), "path": 0}]
	_check(Expedition.hurt_summary(tower).contains("tower"),
		"a hurt tower is named, said '%s'" % Expedition.hurt_summary(tower))
	var pair: Dictionary = tower.duplicate(true)
	pair["wall"] = 0.6
	_check(Expedition.hurt_summary(pair).contains("tower")
			and Expedition.hurt_summary(pair).contains("gate"),
		"and both are named together, said '%s'" % Expedition.hurt_summary(pair))


## **Whole or refused.** Half a fortress is worse than none.
func _test_a_snapshot_is_refused_or_whole() -> void:
	_check(not Expedition.is_readable({}), "an empty snapshot read as a frontier")
	_check(not Expedition.is_readable({"version": Expedition.VERSION,
		"act": 0, "wave": 0}), "a snapshot at wave zero read as a frontier")
	_check(not Expedition.is_readable({"version": Expedition.VERSION + 99,
		"act": 2, "wave": 9}),
		"a snapshot from another build read as a frontier")
	# A tower that no longer exists is the real case: content is removed and
	# renamed between builds, and a fortress missing a third of itself is a bug
	# report nobody can describe.
	_check(not Expedition.is_readable({"version": Expedition.VERSION,
		"act": 2, "wave": 9, "towers": [{"kind": "a_tower_that_was_cut"}]}),
		"a snapshot naming a tower this build does not have was accepted")
	var real: String = _a_tower()
	_check(Expedition.is_readable({"version": Expedition.VERSION,
		"act": 2, "wave": 9, "towers": [{"kind": real, "x": 4, "y": 4}]}),
		"a snapshot naming a real tower was refused")
	_check(Expedition.describe({}).is_empty(),
		"an unreadable snapshot still described a front")


## **Momentum may only move what the road gives up, never a fight.**
func _test_momentum_stays_out_of_the_fight() -> void:
	_check(Balance.MOMENTUM_MAX > 0.0, "momentum that can never rise is not a reward")
	_check(Balance.MOMENTUM_PER_CROSSROAD > 0.0,
		"a crossroad that pays nothing is not a decision")
	var forbidden: Array[String] = [Modifiers.HERO_DAMAGE, Modifiers.TOWER_DAMAGE,
		Modifiers.HERO_MAX_HP, Modifiers.TOWN_MAX_HP, Modifiers.TOWER_RANGE,
		Modifiers.ENEMY_DAMAGE]
	RunState.momentum = 0.0
	Modifiers.rebuild()
	var before: Dictionary = {}
	for key: String in forbidden:
		before[key] = Modifiers.value(key)
	var paid_before: float = Modifiers.value(Modifiers.KILL_RESOURCES)

	RunState.momentum = Balance.MOMENTUM_MAX
	Modifiers.rebuild()
	for key: String in forbidden:
		_check(is_equal_approx(Modifiers.value(key), float(before[key])),
			("momentum moved '%s' from %.3f to %.3f - a stack bought by refusing "
				+ "to bank must never reach a fight")
				% [key, float(before[key]), Modifiers.value(key)])
	_check(Modifiers.value(Modifiers.KILL_RESOURCES) > paid_before,
		"momentum at its ceiling paid nothing, so pressing on is never worth it")
	# And it is capped: a player who never banks must not climb for ever.
	RunState.momentum = Balance.MOMENTUM_MAX * 10.0
	Modifiers.rebuild()
	var runaway: float = Modifiers.value(Modifiers.KILL_RESOURCES)
	RunState.momentum = Balance.MOMENTUM_MAX
	Modifiers.rebuild()
	_check(is_equal_approx(runaway, Modifiers.value(Modifiers.KILL_RESOURCES)),
		"momentum past its ceiling kept paying: %.3f against %.3f"
			% [runaway, Modifiers.value(Modifiers.KILL_RESOURCES)])
	RunState.momentum = 0.0
	Modifiers.rebuild()


## **Driven on the real field**, because the failure worth catching is a
## snapshot that reads well and restores a different fortress.
func _test_banking_and_coming_back() -> void:
	var before_account: Array = [MetaState.hero_level, MetaState.stash.size(),
		MetaState.unlocked_towers.size()]
	print("[expedition] opening original field")
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	_check(field != null, "there must be a field to photograph")
	if field == null:
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(6000)
	RunState.act = 3
	RunState.wave_number = 27

	# Three emplacements, one of them hurt.
	var kind: TowerData = ContentDB.tower(_a_tower())
	var anchors: Array[Vector2i] = []
	for lane: int in 3:
		var anchor: Vector2i = field.free_anchor_near(lane, 8)
		if not field.placement_problem(anchor).is_empty() or anchors.has(anchor):
			continue
		if field.try_build(anchor, kind).is_empty():
			anchors.append(anchor)
	_check(anchors.size() >= 2, "at least two emplacements are needed")
	await get_tree().process_frame
	var wounded: Tower = field.tower_at_anchor(anchors[0]) if not anchors.is_empty() \
		else null
	_check(wounded != null, "a tower node must stand on the plot that was bought")
	if wounded == null:
		await _leave(run)
		return
	wounded.hurt(Health.of(wounded).max_hp * 0.55, wounded.global_position)
	var hurt_ratio: float = wounded.health_ratio()
	_check(hurt_ratio < 0.9, "the probe tower must actually be damaged: %.2f"
		% hurt_ratio)
	var purse: int = RunState.currency(RunState.GOLD)

	# --- Banked ---------------------------------------------------------------
	RunState.building_tiers["forge"] = 3
	RunState.held_items["repair_kit"] = 2
	RunState.wrath = Balance.WRATH_CAP
	var snapshot: Dictionary = Expedition.compose(field)
	_check(Expedition.is_readable(snapshot), "a live field composed an unreadable front")
	_check(int(snapshot.get("act", 0)) == 3 and int(snapshot.get("wave", 0)) == 27,
		"the front was banked at the wrong place")
	_check((snapshot.get("towers", []) as Array).size() == anchors.size(),
		"the front banked %d emplacements against %d standing"
			% [(snapshot.get("towers", []) as Array).size(), anchors.size()])
	var standing: Vector2i = Expedition.fortifications(snapshot)
	_check(standing.y >= 1,
		("the front banked no damaged fortification, so extraction is a free "
			+ "repair and attrition stops existing"))
	# **The wall comes home in the state it was left**, and is readable off the
	# snapshot without a field. The menu's Resume card shows it from 2026-09-16,
	# because `fortifications` counts towers and the wall is the thing a run is
	# actually lost through - and the withdrawal added on the same day can wear
	# it on the way out.
	RunState.town_hp = RunState.town_max_hp * 0.4
	var hurt: Dictionary = Expedition.compose(field)
	_check(absf(Expedition.wall_share(hurt) - 0.4) < 0.02,
		"a worn gate must come home worn (%.2f)" % Expedition.wall_share(hurt))
	_check(Expedition.wall_share({}) == 1.0,
		"and a snapshot with no wall reads as whole rather than as fallen")
	RunState.town_hp = RunState.town_max_hp

	print("[expedition] closing original field")
	await _leave(run)

	# --- And put back down ----------------------------------------------------
	RunState.reset(false, 0)
	_check(RunState.towers.is_empty(), "a reset must leave no fortress")
	_check(Expedition.apply(snapshot), "a readable front refused to be applied")
	_check(RunState.act == 3 and RunState.wave_number == 27,
		"the front came back at Act %d Wave %d" % [RunState.act, RunState.wave_number])
	_check(RunState.towers.size() == anchors.size(),
		"the fortress came back with %d of %d emplacements"
			% [RunState.towers.size(), anchors.size()])
	_check(RunState.currency(RunState.GOLD) == purse,
		"the purse came back as %d against %d"
			% [RunState.currency(RunState.GOLD), purse])
	# **The damage came home with it.**
	var restored: float = float(RunState.tower_health_restore.get(anchors[0], 1.0))
	_check(absf(restored - hurt_ratio) < 0.02,
		("the hurt emplacement came back at %.2f having left at %.2f - a fortress "
			+ "that heals on extraction is a fortress nobody has to mend")
			% [restored, hurt_ratio])

	_check(int(RunState.building_tiers.get("forge", 0)) == 3,
		"city progression did not survive the checkpoint")
	_check(int(RunState.held_items.get("repair_kit", 0)) == 2,
		"run inventory did not survive the checkpoint")
	_check(RunState.wrath == 0.0 and RunState.tremor == 0.0,
		"returning to a checkpoint retained earth wrath")
	# Records alone passed the old gate while the actual field was empty.
	var resumed: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	print("[expedition] opening restored field")
	add_child(resumed)
	print("[expedition] restored field ready")
	for frame: int in 3:
		await get_tree().process_frame
	for anchor: Vector2i in anchors:
		var tower: Tower = resumed.battlefield.tower_at_anchor(anchor)
		_check(tower != null and tower.is_visible_in_tree(),
			"saved tower did not materialize visibly on its original plot")
	var rebuilt: Tower = resumed.battlefield.tower_at_anchor(anchors[0])
	_check(rebuilt != null and absf(rebuilt.health_ratio() - hurt_ratio) < 0.02,
		"live restored tower lost its saved damage")
	await _leave(resumed)

	# **And the account is exactly where it was.** An expedition carries the road.
	var after_account: Array = [MetaState.hero_level, MetaState.stash.size(),
		MetaState.unlocked_towers.size()]
	_check(before_account == after_account,
		"banking or restoring a front changed the account: %s against %s"
			% [after_account, before_account])

	# **A wipe does not clear it.** The whole anti-frustration rule.
	MetaState.expedition = snapshot
	_check(MetaState.has_expedition(), "a banked front did not read back")
	RunState.reset(false, 0)
	_check(MetaState.has_expedition(),
		("a reset cleared the banked front - a wipe must return the party to the "
			+ "last secured crossroads rather than to Act I"))
	MetaState.abandon_expedition()
	_check(not MetaState.has_expedition(), "the front could not be given up")


func _a_tower() -> String:
	var ids: Array = ContentDB.towers.keys()
	ids.sort()
	for id: String in ids:
		var kind := ContentDB.towers[id] as TowerData
		if kind != null and not kind.is_well() and kind.damage > 0.0:
			return id
	return ""


func _leave(run: Run) -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[expedition] " + why)
