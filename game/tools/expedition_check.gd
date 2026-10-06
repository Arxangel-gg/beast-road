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
##   The Hold sells the gate repair from 2026-09-22, which is the same failure
##   arriving with a price tag on it: cheap enough and attrition is refunded
##   out of the payout the withdrawal that caused it already earned.
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
	_test_the_hold_sells_the_gate_repair()
	await _test_banking_and_coming_back()
	await _test_a_front_comes_home_on_new_ground()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[expedition] PASS - %d checks: a front is banked whole or "
			+ "refused whole, the fortress comes back as hurt as it was left, "
			+ "the gate mends for Marks or for ore and timber, never free and never dearer than a return, the account "
			+ "is untouched, and momentum never reaches a fight")
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


## **The Hold sells the gate repair** (owner, 2026-09-22), and this holds the
## four ways that sale can be wrong.
##
## Driven through `MetaState.mend_expedition` rather than through the pure
## functions, because the failure worth catching is a till: a price that reads
## correctly on a screen and a door that charges something else.
##
## **The bound that needs arguing is which direction is dangerous.** There is
## no Marks printer available here and there could not be - the transaction
## consumes Marks and produces a mended wall, paying out no currency, no gear
## and no level. What is available is the opposite: `return_home` banks the
## front *and* pays `homecoming_marks` in full, and the withdrawal of
## 2026-09-16 is what wears the gate on the way out. So a whole gate cheaper
## than one return is a withdrawal refunded out of its own payout, and the
## 2026-09-15 ruling that a damaged fortification comes back damaged survives
## only as a sentence on the Resume card.
##
## Held against the **real** `Run.homecoming_marks` for every act and every
## tier, rather than against the constant: `Expedition.homecoming_worth`
## writes that arithmetic out a second time to stay off `Run`'s dependency
## chain, and two copies of one sum is precisely what a gate is for.
func _test_the_hold_sells_the_gate_repair() -> void:
	var kept_front: Dictionary = MetaState.expedition
	var kept_marks: int = MetaState.marks
	var kept_tier: String = RunState.tier_id

	var front: Dictionary = {
		"version": Expedition.VERSION, "seed": 7, "act": 4, "wave": 31,
		"wall": 1.0, "towers": [], "purse": {}, "momentum": 0.0,
		"tier": "normal",
	}

	# --- A whole gate is not for sale -----------------------------------------
	MetaState.expedition = front.duplicate(true)
	MetaState.marks = 100000
	_check(Expedition.gate_price(front) == 0,
		"a whole gate was priced at %d Marks" % Expedition.gate_price(front))
	_check(not Expedition.needs_mending(front),
		"a whole front was offered a repair")
	var refused_whole: String = MetaState.mend_expedition()
	_check(not refused_whole.is_empty(),
		"the Hold sold a repair for a fortress with nothing wrong with it")
	_check(MetaState.marks == 100000,
		"and it took %d Marks for it" % (100000 - MetaState.marks))

	# --- Cheaper than letting the run go, never free, on every road ----------
	#
	# **Amended 2026-09-30** (owner: "Make mending base repairs at main menu
	# cheaper and more accessible/gatherable"). This held that a fallen gate
	# must cost *more* than the return that wore it; the owner chose the other
	# side of that trade. What it holds now is that resuming is never the worse
	# choice - a fallen gate costs less than a return pays - and that it is
	# never free and never cheaper on a harder road or a later act.
	#
	# Every act and every tier, because a guarantee is a property of all of
	# them or it is not a guarantee - and `loot_scale` runs 1.0 to 3.6, so a
	# price that ignored the tier would read the same on Hell as on the Long Road.
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		RunState.tier_id = tier.id
		var last: int = 0
		for act: int in range(1, Balance.ACT_COUNT + 2):
			var fallen: Dictionary = front.duplicate(true)
			fallen["act"] = act
			fallen["tier"] = tier.id
			fallen["wall"] = 0.0
			var paid: int = Run.homecoming_marks(act, true)
			_check(Expedition.homecoming_worth(fallen) == paid,
				("the price's model of the payout drifted from the payout on "
					+ "%s act %d: %d against %d")
					% [tier.id, act, Expedition.homecoming_worth(fallen), paid])
			var gate: int = Expedition.gate_price(fallen)
			_check(gate > 0 and gate < paid,
				("a fallen gate on %s act %d costs %d Marks against the %d a "
					+ "return pays - it should be under a return and never free")
					% [tier.id, act, gate, paid])
			_check(gate >= last, "the gate on %s act %d is cheaper than the act before" % [tier.id, act])
			last = gate
	RunState.tier_id = kept_tier

	# --- Or in what the mines give --------------------------------------------
	var stony: Dictionary = front.duplicate(true)
	stony["wall"] = Balance.HOMECOMING_WALL_FLOOR
	var gate_bill: Dictionary = Expedition.gate_materials(stony)
	_check(gate_bill.size() == 2, "the gate has no price in ore and timber: %s" % gate_bill)
	_check(Expedition.bill_text(stony).contains("Marks")
			and Expedition.bill_text(stony).contains(" or "),
		"the bill must say the gate is Marks or materials, said '%s'" % Expedition.bill_text(stony))
	var kept_materials: Dictionary = MetaState.materials.duplicate(true)
	MetaState.expedition = stony.duplicate(true)
	MetaState.marks = 0
	for id: Variant in gate_bill:
		MetaState.materials[String(id)] = int(gate_bill[id]) + 5
	var stone_ok: String = MetaState.mend_expedition()
	_check(stone_ok.is_empty(), "a Warden with the ore and timber was refused: '%s'" % stone_ok)
	_check(is_equal_approx(Expedition.wall_share(MetaState.expedition), 1.0),
		"the gate paid for in ore and timber came back at %.2f" % Expedition.wall_share(MetaState.expedition))
	for id: Variant in gate_bill:
		_check(int(MetaState.materials.get(String(id), 0)) == 5,
			"the gate took %d %s against the %d it was priced at"
				% [int(gate_bill[id]) + 5 - int(MetaState.materials.get(String(id), 0)), id, int(gate_bill[id])])
	_check(MetaState.marks == 0, "a gate paid in materials took Marks as well")
	MetaState.materials = kept_materials

	# --- Short of Marks: refuses, and spends nothing --------------------------
	var worn: Dictionary = front.duplicate(true)
	worn["wall"] = Balance.HOMECOMING_WALL_FLOOR
	var price: int = Expedition.gate_price(worn)
	_check(price > 0, "a gate at the withdrawal's floor wants no mending")
	_check(Expedition.needs_mending(worn),
		"a worn gate above a whole board is not offered a mend")
	_check(Expedition.bill_text(worn).contains("Marks"),
		"the bill must say what the gate costs, said '%s'"
			% Expedition.bill_text(worn))

	MetaState.expedition = worn.duplicate(true)
	MetaState.marks = price - 1
	var refused: String = MetaState.mend_expedition()
	_check(not refused.is_empty(),
		"the Hold mended the gate for a Warden who could not pay for it")
	_check(MetaState.marks == price - 1,
		"a refused repair still took Marks: %d against %d"
			% [MetaState.marks, price - 1])
	_check(absf(Expedition.wall_share(MetaState.expedition)
			- Balance.HOMECOMING_WALL_FLOOR) < 0.001,
		"a refused repair still mended the gate")

	# --- Paid for: the gate, the Marks, and nothing else ----------------------
	#
	# "Byte-identical" is taken literally: the whole save is serialized either
	# side, the two things the purchase is allowed to move are put back, and
	# the strings are compared. A repair that quietly handed over a tower
	# level, a currency or an unlock shows up as a diff and as nothing else.
	MetaState.expedition = worn.duplicate(true)
	MetaState.marks = price + 13
	var before: String = MetaState.serialized_save()
	var paid_ok: String = MetaState.mend_expedition()
	_check(paid_ok.is_empty(), "a Warden who could pay was refused: '%s'" % paid_ok)
	_check(MetaState.marks == 13,
		"the gate cost %d Marks against the %d it was priced at"
			% [price + 13 - MetaState.marks, price])
	_check(is_equal_approx(Expedition.wall_share(MetaState.expedition), 1.0),
		"the gate was paid for and came back at %.2f"
			% Expedition.wall_share(MetaState.expedition))
	_check(not Expedition.needs_mending(MetaState.expedition),
		"a mended front was offered the repair again")
	MetaState.marks = price + 13
	MetaState.expedition = worn.duplicate(true)
	_check(MetaState.serialized_save() == before,
		"mending the gate moved something in the account other than the Marks")

	# --- Restores, never improves ---------------------------------------------
	#
	# Compared against the same snapshot with its damage taken off by hand, so
	# the assertion is "exactly these fields moved" rather than "the wall is
	# whole" - which is the half that would miss a repair granting a level.
	var battered: Dictionary = front.duplicate(true)
	battered["wall"] = 0.3
	battered["towers"] = [
		{"x": 3, "y": 4, "kind": _a_tower(), "level": 2, "path": 0,
			"priority": 0, "health": 0.25},
		{"x": 9, "y": 2, "kind": _a_tower(), "level": 1, "path": 0,
			"priority": 0, "health": 1.0},
	]
	var expected: Dictionary = battered.duplicate(true)
	expected["wall"] = 1.0
	for row: Variant in (expected["towers"] as Array):
		(row as Dictionary)["health"] = 1.0
	_check(JSON.stringify(Expedition.mend(battered)) == JSON.stringify(expected),
		("mending changed more than the damage:\n  %s\n  %s")
			% [JSON.stringify(Expedition.mend(battered)), JSON.stringify(expected)])
	_check(Expedition.gate_price(battered) > 0
			and not Expedition.repair_bill(battered).is_empty(),
		"the battered front must want both halves of the bill, so this is "
			+ "measuring a real repair")

	MetaState.expedition = kept_front
	MetaState.marks = kept_marks
	RunState.tier_id = kept_tier


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
	# On Keep, which is a road a player can be on. A bare reset lays the
	# authored reference ground, and a front banked there comes home on Keep
	# by design (2026-10-06) - so the emplacements this test stands up would be
	# refunded on resume rather than found standing.
	RunState.map_mode = MapModes.KEEP
	RunState.map_varied = false
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
	# And a gate that came home worn off a real field is one the Hold will
	# sell a repair for. Asked of the gate's own price rather than of
	# `needs_mending`, which the damaged emplacements above would answer on
	# their own - the wall is the half that had no purchase at all.
	_check(Expedition.gate_price(hurt) > 0,
		"a gate that came home at %d%% was offered no repair"
			% int(round(Expedition.wall_share(hurt) * 100.0)))
	_check(Expedition.wall_share({}) == 1.0,
		"and a snapshot with no wall reads as whole rather than as fallen")
	RunState.town_hp = RunState.town_max_hp

	print("[expedition] closing original field")
	await _leave(run)

	# --- And put back down ----------------------------------------------------
	RunState.reset(false, 0)
	_check(RunState.towers.is_empty(), "a reset must leave no fortress")
	# The worn front, so the field and the HUD can be asked about the gate.
	_check(Expedition.apply(hurt), "a readable front refused to be applied")
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
	# **And the gate, on the field and on the screen** (owner, 2026-10-01: "City
	# base health does not properly load when continuing"). The field always had
	# it; the HUD is built after the field and its bar was born full, so a front
	# that came home at 40% read as whole until its first blow.
	var gate: TownCore = resumed.battlefield.town
	_check(gate != null and absf(gate.health.current_hp / maxf(gate.health.max_hp, 1.0) - 0.4) < 0.02,
		"the resumed gate stands at %.2f on a front that came home at 0.40"
			% (gate.health.current_hp / maxf(gate.health.max_hp, 1.0) if gate != null else -1.0))
	var bar: ProgressBar = resumed.hud.get("_town_bar") as ProgressBar
	_check(bar != null and absf(bar.value - 0.4) < 0.02,
		"the HUD shows the resumed gate at %.2f on a front that came home at 0.40"
			% (bar.value if bar != null else -1.0))
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


## **A front banked on the retired layout comes home on Keep, and what cannot
## stand on the new ground is refunded at the road's own prices** (2026-10-06).
## A tower planted on what is road in Keep and a trap on what is open ground
## there are each taken down before they are stood up, their price comes back
## to the purse, and a tower on ground Keep does offer is left exactly as it
## was. Nothing is created: the gate reads the purse back against the prices
## the field itself quotes.
func _test_a_front_comes_home_on_new_ground() -> void:
	# **A new account's roads are Random** (owner, 2026-10-06). Read off the
	# declared default and off the reader's own fallback rather than off this
	# profile, which a sweep shares with every other gate.
	# The declared default is a line in the settings table, and the table is
	# what the loader keeps keys by - an undeclared key is dropped on load
	# (`undeclared-save-keys-vanish-silently`). A source walk is the honest
	# proof of a declaration: the default value is not a constant expression
	# the script can hand back.
	var meta_source: String = FileAccess.get_file_as_string("res://autoload/MetaState.gd")
	_check(meta_source.contains('"map_mode": MapModes.RANDOM,'),
		"the declared map_mode setting is Random")
	var setting_was: Variant = MetaState.settings.get(UserSettings.MAP_MODE_KEY, null)
	MetaState.settings.erase(UserSettings.MAP_MODE_KEY)
	_check(UserSettings.map_mode() == MapModes.RANDOM,
		"an account with no map setting reads Random, got %s" % UserSettings.map_mode())
	MetaState.settings[UserSettings.MAP_MODE_KEY] = MapModes.LEGACY_CLASSIC
	_check(UserSettings.map_mode() == MapModes.KEEP,
		"a setting saved as the retired layout reads Keep, got %s" % UserSettings.map_mode())
	if setting_was == null:
		MetaState.settings.erase(UserSettings.MAP_MODE_KEY)
	else:
		MetaState.settings[UserSettings.MAP_MODE_KEY] = setting_was
	RunState.reset(false, 0)
	var keep := BattleGrid.new(4242, MapModes.KEEP)
	var road_tile := Vector2i(-1, -1)
	var open_tile := Vector2i(-1, -1)
	var trap_tile := Vector2i(-1, -1)
	var margin: int = BattleGrid.OUTSKIRTS + 6
	for y: int in range(margin, BattleGrid.OUTSKIRTS + BattleGrid.CORE_SIZE - 6):
		for x: int in range(margin, BattleGrid.OUTSKIRTS + BattleGrid.CORE_SIZE - 6):
			var tile := Vector2i(x, y)
			if road_tile.x < 0 and keep.cell_at(tile) == BattleGrid.Cell.ROAD \
					and keep.cell_at(tile + Vector2i(1, 1)) == BattleGrid.Cell.ROAD:
				road_tile = tile
			elif open_tile.x < 0 and keep.footprint_is_open(tile):
				open_tile = tile
			elif open_tile.x >= 0 and trap_tile.x < 0 \
					and keep.cell_at(tile) == BattleGrid.Cell.OPEN \
					and (tile - open_tile).length() >= 4.0:
				trap_tile = tile
	_check(road_tile.x >= 0 and open_tile.x >= 0 and trap_tile.x >= 0,
		"Keep offers a road tile, an open plot and an open tile apart from it")
	var kind: TowerData = ContentDB.tower(_a_tower())
	var trap: TrapData = null
	for value: Variant in ContentDB.traps.values():
		trap = value as TrapData
		if trap != null:
			break
	var front: Dictionary = {
		"version": Expedition.VERSION, "seed": 4242, "act": 2, "wave": 9,
		"wall": 1.0, "purse": {RunState.GOLD: 500}, "momentum": 0.0, "tier": "normal",
		"map_mode": MapModes.LEGACY_CLASSIC, "map_varied": false,
		"towers": [
			{"x": road_tile.x, "y": road_tile.y, "kind": kind.id, "level": 3,
				"priority": 0, "path": 0, "health": 1.0},
			{"x": open_tile.x, "y": open_tile.y, "kind": kind.id, "level": 1,
				"priority": 0, "path": 0, "health": 0.6},
		],
	}
	_check(Expedition.is_readable(front), "the front with the retired layout's name is readable")
	_check(Expedition.apply(front), "and it applies")
	_check(RunState.map_mode == MapModes.KEEP,
		"a front banked on the retired layout comes home on Keep (got %s)" % RunState.map_mode)
	_check(not RunState.map_varied, "and on Keep as designed, never varied")
	if trap != null:
		RunState.set_trap(trap_tile, trap.id, trap.triggers)
	var purse_before: int = RunState.currency(RunState.GOLD)
	var expected: int = int(Battlefield.cost_of(kind).get(RunState.GOLD, 0))
	for level: int in range(1, 3):
		expected += Battlefield.upgrade_cost_of(level)
	if trap != null:
		expected += int(trap.cost.get(RunState.GOLD, 0))
	print("[expedition] standing the front on Keep")
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	_check(field != null and field.grid != null and field.grid.mode == MapModes.KEEP,
		"the field was laid on Keep")
	_check(not RunState.towers.has(road_tile), "the tower on Keep's road was taken down")
	_check(RunState.towers.has(open_tile), "and the tower on open ground still stands")
	_check(not RunState.traps.has(trap_tile), "the trap on open ground was taken down")
	for anchor: Vector2i in RunState.towers:
		_check(field.grid.footprint_is_open(anchor) or field.tower_at_anchor(anchor) != null,
			"every emplacement left stands on ground the layout offers")
	var refunded: int = RunState.currency(RunState.GOLD) - purse_before
	_check(refunded == expected,
		"the purse came back by exactly what the fallen emplacements cost (%d against %d)"
			% [refunded, expected])
	var worn: Tower = field.tower_at_anchor(open_tile)
	_check(worn != null and worn.health_ratio() < 0.7,
		"the standing tower came home as hurt as it was banked")
	await _leave(run)
	RunState.reset(false, 0)


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
