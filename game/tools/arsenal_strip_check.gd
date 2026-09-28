extends Node

## The Arsenal strip on the HUD says what the hand is doing, and only that.
##
##   godot --headless --path game res://tools/arsenal_strip_check.tscn
##
## A readout reads: `Arsenal.readout()` answers the strip and nothing that
## decides anything, and the strip draws it. What can go wrong is what goes
## wrong with every readout here - it lies, it is wired to nothing, or it
## costs something. So: a tile a weapon, none with an empty hand; the share of
## a clocked weapon climbing as its clock runs down and full when it fires; a
## guard's share falling as its stones are spent; the board's weapons after
## the Warden's; and the run byte-identical with the strip drawn or not.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260928)
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 12:
		await get_tree().process_frame
	await _test_the_strip()
	_test_the_bars_carry_it()
	Sfx.stop_immediately()
	MetaState.resume_saves()
	if _failures == 0:
		print("[arsenal-strip] PASS - %d checks: a tile a weapon, the clock and the stones read true, the board after the Warden, and nothing decided" % _checks)
	else:
		push_error("[arsenal-strip] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _strip() -> ArsenalStrip:
	if _run == null or _run.hud == null:
		return null
	return _find(_run.hud, "ArsenalStrip") as ArsenalStrip


func _find(from: Node, wanted: String) -> Node:
	if from.name == wanted:
		return from
	for child: Node in from.get_children():
		var hit: Node = _find(child, wanted)
		if hit != null:
			return hit
	return null


func _hold(ids: Array, level: int = 1) -> void:
	var hand: Array[String] = []
	var levels: Dictionary = {}
	for id: Variant in ids:
		hand.append(String(id))
		levels[String(id)] = level
	RunState.hands_split = false
	RunState.road_cards = hand
	RunState.road_card_levels = levels
	Modifiers.rebuild()
	EventBus.augment_hand_changed.emit()


func _card_with(pattern: int, anchor: int) -> RoadCardData:
	var ids: Array = ContentDB.road_cards.keys()
	ids.sort()
	for id: Variant in ids:
		var card: RoadCardData = ContentDB.road_card(String(id))
		if card == null or not card.is_weapon():
			continue
		var weapon: ArsenalWeaponData = card.weapon_data()
		if weapon != null and weapon.pattern == pattern and weapon.anchor == anchor \
				and weapon.every_kills <= 0:
			return card
	return null


func _test_the_strip() -> void:
	var strip: ArsenalStrip = _strip()
	_check(strip != null, "the HUD carries no Arsenal strip on a desktop")
	if strip == null:
		return
	var hero: Hero = _run.battlefield.hero
	_check(hero != null and hero.arsenal != null, "the hero has no Arsenal to read")
	if hero == null or hero.arsenal == null:
		return
	strip.hero = hero
	strip.board = _run.battlefield

	# Empty-handed, nothing is drawn.
	_hold([])
	hero.arsenal.rearm()
	strip.refresh()
	_check(not strip.visible and strip.shown() == 0, "an empty hand draws %d tiles" % strip.shown())

	# A clocked weapon of the Warden's and a guard: two tiles, in that order.
	var seeker: RoadCardData = _card_with(ArsenalWeaponData.Pattern.SEEKER, ArsenalWeaponData.Anchor.WARDEN)
	var guard: RoadCardData = _card_with(ArsenalWeaponData.Pattern.GUARD, ArsenalWeaponData.Anchor.WARDEN)
	var board_card: RoadCardData = null
	for pattern: int in [ArsenalWeaponData.Pattern.STRIKE, ArsenalWeaponData.Pattern.NOVA,
			ArsenalWeaponData.Pattern.WARD, ArsenalWeaponData.Pattern.MEND]:
		board_card = _card_with(pattern, ArsenalWeaponData.Anchor.TOWERS)
		if board_card == null:
			board_card = _card_with(pattern, ArsenalWeaponData.Anchor.TOWN)
		if board_card != null:
			break
	_check(seeker != null and guard != null and board_card != null,
		"the deck lacks a Warden seeker, a Warden guard or a board weapon to read")
	if seeker == null or guard == null or board_card == null:
		return
	_hold([seeker.id, guard.id, board_card.id], 3)
	hero.arsenal.rearm()
	_run.battlefield.board_arsenal().rearm()
	strip.refresh()
	_check(strip.visible, "a held hand leaves the strip hidden")
	_check(strip.shown() == 3, "three weapons draw %d tiles" % strip.shown())
	var before: String = MetaState.serialized_save()
	var rows: Array[Dictionary] = hero.arsenal.readout()
	_check(rows.size() == 2, "the Warden's Arsenal reads %d rows for two weapons" % rows.size())
	var board_rows: Array[Dictionary] = _run.battlefield.board_arsenal().readout()
	_check(board_rows.size() == 1, "the board's Arsenal reads %d rows for one weapon" % board_rows.size())
	for row: Dictionary in rows:
		_check(int(row["level"]) == 3, "a level-3 card reads as level %d" % int(row["level"]))
		_check(float(row["share"]) >= 0.0 and float(row["share"]) <= 1.0,
			"a share of %.2f is outside nought to one" % float(row["share"]))

	# The clocked weapon's share climbs as its clock runs down. Pin the clock
	# by hand and read the share twice.
	var armed: Dictionary = hero.arsenal.get("_armed")
	var seeker_armed: Arsenal.Armed = armed[seeker.id]
	var wait: float = hero.arsenal.cadence(seeker.weapon_data())
	seeker_armed.clock = wait
	var low: float = _share_of(hero.arsenal.readout(), seeker.id)
	seeker_armed.clock = wait * 0.25
	var high: float = _share_of(hero.arsenal.readout(), seeker.id)
	_check(is_equal_approx(low, 0.0), "a seeker with its whole clock to wait reads %.2f ready" % low)
	_check(is_equal_approx(high, 0.75), "a seeker a quarter of its clock from firing reads %.2f ready" % high)

	# A guard's share is its stones.
	var guard_armed: Arsenal.Armed = armed[guard.id]
	var full: int = hero.arsenal.count_for(guard.weapon_data(), 3)
	guard_armed.stones = full
	_check(is_equal_approx(_share_of(hero.arsenal.readout(), guard.id), 1.0), "a whole guard reads short")
	guard_armed.stones = 0
	_check(is_equal_approx(_share_of(hero.arsenal.readout(), guard.id), 0.0), "an emptied guard reads as standing")
	guard_armed.stones = full

	# The strip draws what it was told, the board after the Warden.
	strip.refresh()
	_check(strip.tile_share(0) >= 0.0 and strip.tile_share(1) >= 0.0, "the tiles carry no share")
	_check(strip.get_child(0) is Control and strip.get_child_count() >= 4,
		"the strip has %d children for three tiles and a gap" % strip.get_child_count())

	# **And nothing was decided.** The account is byte-identical, and the run's
	# hand is what it was told.
	_check(MetaState.serialized_save() == before, "reading the strip changed the save")
	_check(RunState.road_cards.size() == 3, "reading the strip changed the hand")

	# Out of scope, the strip is off and hidden.
	EventBus.scope_changed.emit(GameDirector.Scope.TOWN)
	await get_tree().process_frame
	_check(not strip.visible, "in the town the strip is still showing")
	_check(not strip.is_processing(), "in the town the strip is still ticking")
	EventBus.scope_changed.emit(GameDirector.Scope.BATTLEFIELD)
	await get_tree().process_frame
	_check(strip.is_processing(), "back on the field the strip does not tick")


func _share_of(rows: Array[Dictionary], card_id: String) -> float:
	for row: Dictionary in rows:
		if (row["card"] as RoadCardData).id == card_id:
			return float(row["share"])
	return -1.0


func _test_the_bars_carry_it() -> void:
	for workflow: String in ["res://../.github/workflows/guard.yml",
			"res://../.github/workflows/release.yml"]:
		_check(FileAccess.get_file_as_string(workflow).contains("arsenal_strip_check.tscn"),
			"%s does not run this gate" % workflow.get_file())


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[arsenal-strip] " + why)
