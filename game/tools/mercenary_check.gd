extends Node

## **Mercenaries** (owner, 2026-10-07; `docs/MERCENARIES_2026-10-07.md`).
##
## Stage one, the roster: a stranger is the same Warden however often it is
## rolled and never above the hiring Warden's level; the fee charges for level
## and gear and the contract is a share of it; a hire takes exactly the fee and
## adds a row and moves nothing else in the account; three at most, nobody
## twice; a third wound puts one in a bed with a bill and a rest, and it gets up
## only when both are done; a release works from a bed and is refused on a live
## road; a hand-edited row is cleaned on reading; and the Inn's own buttons do
## what the doors do.

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var held_marks: int = MetaState.marks
	var held_roster: Array[Dictionary] = MetaState.mercenaries.duplicate(true)
	var held_level: int = MetaState.hero_level
	MetaState.mercenaries = []
	MetaState.hero_level = 40
	_test_an_offer()
	_test_the_price()
	_test_hiring()
	_test_the_bed()
	_test_a_live_road()
	_test_the_save()
	await _test_the_inn()
	MetaState.marks = held_marks
	MetaState.mercenaries = held_roster
	MetaState.hero_level = held_level
	for stage: String in ["offer", "price", "hire", "bed", "road", "save", "inn"]:
		_check(stage in _reached, "the %s stage never reached its end" % stage)
	_finish()


func _test_an_offer() -> void:
	var a: Dictionary = Mercenaries.offer("yard:1", "Marrow", 40, RunState.tier())
	var b: Dictionary = Mercenaries.offer("yard:1", "Marrow", 40, RunState.tier())
	_check(a == b, "the same stranger rolled twice is two different Wardens")
	var c: Dictionary = Mercenaries.offer("yard:2", "Ash", 40, RunState.tier())
	_check(String(a["uid"]) != String(c["uid"]), "two strangers share a name on the roster")
	for who: int in 30:
		var offer: Dictionary = Mercenaries.offer("yard:%d" % who, "x", 25, RunState.tier())
		var level: int = int(offer["level"])
		_check(level <= 25 and level >= 25 - Balance.MERC_LEVEL_SPREAD,
			"a stranger at level %d beside a level-25 Warden" % level)
		var placed: int = 0
		for points: int in (offer["attributes"] as Array):
			placed += points
		_check(placed == level - 1, "a level-%d mercenary placed %d points" % [level, placed])
	var stranger: Dictionary = HoldYard.stranger_of("yard:1")
	var worn: Array[String] = Mercenaries.worn_kinds(a)
	for kind: Variant in (stranger["gear"] as Array):
		if not String(kind).is_empty():
			_check(String(kind) in worn, "the mercenary does not wear the %s the stranger did" % kind)
	_check(Mercenaries.offer("yard:9", "", 1, RunState.tier())["level"] == 1,
		"a level-one Warden was offered somebody above level one")
	_reached.append("offer")


func _test_the_price() -> void:
	var low: Dictionary = Mercenaries.offer("yard:1", "a", 10, RunState.tier())
	var high: Dictionary = low.duplicate(true)
	high["level"] = int(low["level"]) + 20
	_check(Mercenaries.fee(high) > Mercenaries.fee(low), "a higher level does not cost more")
	var bare: Dictionary = low.duplicate(true)
	bare["gear"] = []
	_check(Mercenaries.gear_points(low) == 0 or Mercenaries.fee(low) > Mercenaries.fee(bare),
		"gear does not cost anything")
	_check(Mercenaries.contract(low) > 0 and Mercenaries.contract(low) < Mercenaries.fee(low),
		"a contract is not a share of the fee")
	_check(Mercenaries.bill(high) > Mercenaries.bill(low), "a higher level's bill is no dearer")
	_reached.append("price")


func _test_hiring() -> void:
	MetaState.mercenaries = []
	var offer: Dictionary = Mercenaries.offer("yard:1", "Marrow", 40, RunState.tier())
	var price: int = Mercenaries.fee(offer)
	MetaState.marks = price - 1
	_check(not MetaState.hire_mercenary(offer), "a Warden short of the fee hired anyway")
	_check(MetaState.mercenaries.is_empty(), "a refused hire left a row")
	MetaState.marks = price * 10
	var before: Dictionary = _account()
	_check(MetaState.hire_mercenary(offer), "a Warden with the fee could not hire")
	_check(MetaState.marks == price * 10 - price, "a hire took %d, the fee is %d" % [price * 10 - MetaState.marks, price])
	_check(MetaState.mercenaries.size() == 1, "a hire did not add one row")
	var after: Dictionary = _account()
	for key: Variant in before:
		if String(key) in ["unlocked", "mercenaries"]:
			continue
		_check(JSON.stringify(before[key]) == JSON.stringify(after.get(key)),
			"hiring moved the account's %s" % key)
	_check(not MetaState.hire_mercenary(offer), "the same stranger was hired twice")
	MetaState.hire_mercenary(Mercenaries.offer("yard:2", "Ash", 40, RunState.tier()))
	MetaState.hire_mercenary(Mercenaries.offer("yard:3", "Rue", 40, RunState.tier()))
	_check(MetaState.mercenaries.size() == Balance.MERC_ROSTER_MAX, "the company did not fill to its cap")
	_check(not MetaState.hire_mercenary(Mercenaries.offer("yard:4", "Fen", 40, RunState.tier())),
		"a fourth was hired past the cap")
	# Seats: alone, every one may come.
	for row: Dictionary in MetaState.mercenaries:
		_check(MetaState.set_mercenary_taking(String(row["uid"]), true), "a ready mercenary could not be taken")
	_check(MetaState.mercenaries_taking().size() == mini(Balance.MERC_ROSTER_MAX, MetaState.mercenary_seats()),
		"%d taken against %d seats" % [MetaState.mercenaries_taking().size(), MetaState.mercenary_seats()])
	_reached.append("hire")


func _test_the_bed() -> void:
	var row: Dictionary = MetaState.mercenaries[0]
	var uid: String = String(row["uid"])
	MetaState.send_mercenary_to_bed(uid)
	_check(String(row["state"]) == Mercenaries.STATE_RESTING, "a third wound did not put it in a bed")
	_check(int(row["bill"]) == Mercenaries.bill(row), "the bill is not its level's bill")
	_check(not bool(row["taking"]), "a mercenary in a bed is still coming")
	_check(not MetaState.mercenary_ready(uid), "a mercenary in a bed may take the road")
	_check(not MetaState.set_mercenary_taking(uid, true), "a mercenary in a bed was taken")
	MetaState.marks = int(row["bill"]) * 3
	_check(MetaState.pay_mercenary_bill(uid), "the bill could not be paid")
	_check(MetaState.marks == int(Mercenaries.bill(row)) * 2, "paying the bill took the wrong Marks")
	_check(not MetaState.mercenary_ready(uid), "paying the bill skipped the rest")
	row["rest_until"] = Time.get_unix_time_from_system() - 1.0
	MetaState.wake_rested_mercenaries()
	_check(MetaState.mercenary_ready(uid) and String(row["state"]) == Mercenaries.STATE_READY,
		"a rested mercenary with its bill paid did not get up")
	# Rested but owing is still in bed.
	MetaState.send_mercenary_to_bed(uid)
	row["rest_until"] = Time.get_unix_time_from_system() - 1.0
	MetaState.wake_rested_mercenaries()
	_check(not MetaState.mercenary_ready(uid), "a rested mercenary got up with its bill unpaid")
	_check(MetaState.release_mercenary(uid), "a mercenary could not be released from its bed")
	_check(MetaState.mercenary(uid).is_empty(), "a released mercenary is still on the roster")
	_reached.append("bed")


func _test_a_live_road() -> void:
	var was_active: bool = GameDirector.run_active
	var was_phase: int = RunState.phase
	GameDirector.run_active = true
	RunState.phase = RunState.Phase.ROAD_BATTLE
	var uid: String = String(MetaState.mercenaries[0]["uid"]) if not MetaState.mercenaries.is_empty() else ""
	_check(not MetaState.release_mercenary(uid), "a mercenary was released from a live road")
	_check(not MetaState.hire_mercenary(Mercenaries.offer("yard:7", "x", 40, RunState.tier())),
		"a mercenary was hired on a live road")
	GameDirector.run_active = was_active
	RunState.phase = was_phase as RunState.Phase
	_reached.append("road")


func _test_the_save() -> void:
	var text: String = MetaState.serialized_save()
	var parsed: Dictionary = JSON.parse_string(text) as Dictionary
	var rows: Array = parsed.get("mercenaries", []) as Array
	_check(rows.size() == MetaState.mercenaries.size(), "the save carries %d of %d" % [rows.size(), MetaState.mercenaries.size()])
	var count: int = MetaState.mercenaries.size()
	# A hand-edited save: a row over the level cap, points past its budget, a
	# piece the game has never heard of, a row with no name, and too many rows.
	var forged: Array = rows.duplicate(true)
	if not forged.is_empty():
		var bad: Dictionary = (forged[0] as Dictionary).duplicate(true)
		bad["uid"] = "forged"
		bad["who"] = "forged"
		bad["level"] = 9999
		bad["attributes"] = [9999, 9999, 9999, 9999, 9999]
		bad["gear"] = [{"kind": "nothing_real", "rarity": 99, "level": 99}]
		forged.append(bad)
	forged.append({"name": "nobody"})
	MetaState._read_mercenaries(forged)
	_check(MetaState.mercenaries.size() <= Balance.MERC_ROSTER_MAX, "a save read back past the cap")
	for row: Dictionary in MetaState.mercenaries:
		_check(int(row["level"]) <= Balance.HERO_MAX_LEVEL, "a forged level survived the read")
		var placed: int = 0
		for points: int in (row["attributes"] as Array):
			placed += points
		_check(placed <= int(row["level"]) - 1, "a forged row placed %d points at level %d" % [placed, int(row["level"])])
		for piece: Dictionary in (row["gear"] as Array):
			_check(ContentDB.gear(String(piece["kind"])) != null, "a forged piece survived the read")
	MetaState._read_mercenaries(rows)
	_check(MetaState.mercenaries.size() == count, "the save did not read back what it wrote")
	_reached.append("save")


func _test_the_inn() -> void:
	MetaState.mercenaries = []
	MetaState.marks = 100000
	var inn := InnScreen.new()
	inn.strangers = func() -> Array:
		return [{"who": "yard:11", "name": "Marrow"}, {"who": "yard:12", "name": "Ash"}]
	add_child(inn)
	await get_tree().process_frame
	inn.open()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(inn.offers().size() == 2, "the inn offers %d of two strangers" % inn.offers().size())
	var hire: Button = _find(inn, "Hire") as Button
	_check(hire != null and not hire.disabled, "the inn has no Hire button a Warden could press")
	if hire != null:
		hire.pressed.emit()
		await get_tree().process_frame
		_check(MetaState.mercenaries.size() == 1, "the inn's Hire hired nobody")
		_check(inn.offers().size() == 1, "a hired stranger is still offered")
	var release: Button = _find(inn, "Release") as Button
	if release != null:
		release.pressed.emit()
		await get_tree().process_frame
		_check(MetaState.mercenaries.size() == 1, "one press of Release let them go")
		release = _find(inn, "Release") as Button
		if release != null:
			release.pressed.emit()
			await get_tree().process_frame
		_check(MetaState.mercenaries.is_empty(), "two presses of Release did not let them go")
	inn.hide_screen()
	inn.queue_free()
	await get_tree().process_frame
	_reached.append("inn")


## The account as written, less the Marks the fee is paid in - they ride in the
## stash's block, and a hire is meant to move them.
func _account() -> Dictionary:
	var account: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	if account.get("stash", null) is Dictionary:
		(account["stash"] as Dictionary).erase("marks")
	return account


func _find(from: Node, named: String) -> Node:
	for child: Node in from.get_children():
		if child.name == named and child is Button and (child as Button).is_visible_in_tree():
			return child
		var deeper: Node = _find(child, named)
		if deeper != null:
			return deeper
	return null


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("mercenary_check: " + message)


func _finish() -> void:
	if _failures == 0:
		print("mercenary_check: PASS (%d checks)" % _checks)
	else:
		print("mercenary_check: FAIL (%d of %d)" % [_failures, _checks])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	for child: Node in get_children():
		child.queue_free()
	for _i: int in 20:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)
