extends Node

## **The Cairn keeps the road's history** (triage of 2026-10-07, "run history
## and the Hall").
##
##   godot --headless --path game res://tools/cairn_check.tscn
##
## Holds that a settled road is remembered with how it ended, newest first, and
## that a fall says what felled the Warden while a homecoming says nothing of
## the sort; that the Walk and a sandbox are never remembered; that the list
## keeps `RUN_HISTORY_MAX` and the records outlive it; that a save carries both
## and reads them back clean - a row the game could not have written dropped or
## clamped; that `_settle_run` is the door that writes; and that the Cairn reads
## the history without writing a byte.

const TAG: String = "[cairn]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var kept_history: Array[Dictionary] = MetaState.run_history.duplicate(true)
	var kept_records: Dictionary = MetaState.run_records.duplicate(true)
	RunState.reset()
	_test_a_road_is_remembered()
	_test_the_walk_and_the_sandbox_are_not()
	_test_the_list_is_bounded_and_records_outlive_it()
	_test_the_save_reads_clean()
	_test_the_door_that_writes()
	await _test_the_cairn_reads()
	for stage: String in ["remembered", "refused", "bounded", "save", "door", "screen"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MetaState.run_history = kept_history
	MetaState.run_records = kept_records
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: a road is remembered with how it ended, the Walk and the sandbox are not, the list is bounded and the records outlive it, the save reads clean, and the Cairn reads without writing" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])


func _summary(victory: bool, returned: bool, act: int, kills: int) -> Dictionary:
	return {"victory": victory, "returned": returned, "act": act, "wave": act * 40,
		"distance": float(act * 900), "kills": kills, "time": float(act * 600),
		"towers_built": act * 3, "last_blow": "Felled by a Bog Crane's bite"}


func _test_a_road_is_remembered() -> void:
	MetaState.run_history.clear()
	MetaState.run_records = {}
	MetaState.remember_run(_summary(false, false, 3, 120))
	MetaState.remember_run(_summary(false, true, 5, 300))
	MetaState.remember_run(_summary(true, false, 11, 900))
	var rows: Array[Dictionary] = MetaState.run_history
	_check(rows.size() == 3, "three settled roads left %d stones" % rows.size())
	if rows.size() == 3:
		_check(String(rows[0]["ended"]) == "summit" and String(rows[1]["ended"]) == "home"
			and String(rows[2]["ended"]) == "fell", "the endings are %s, %s, %s - newest first is summit, home, fell"
			% [rows[0]["ended"], rows[1]["ended"], rows[2]["ended"]])
		_check(String(rows[2]["cause"]).contains("Bog Crane"), "a fall does not say what felled the Warden")
		_check(String(rows[1]["cause"]).is_empty(), "a road that came home says something felled it")
		_check(int(rows[0]["act"]) == 11 and int(rows[0]["kills"]) == 900, "the summit's road is not the one remembered")
		_check((rows[2]["look"] as Array).size() == WardenLook.KEYS.size(), "a stone does not keep the Warden's look")
	_check(int(MetaState.run_records.get("kills", 0)) == 900 and int(MetaState.run_records.get("act", 0)) == 11,
		"the records did not take the best of the three")
	_reached.append("remembered")


func _test_the_walk_and_the_sandbox_are_not() -> void:
	var before: int = MetaState.run_history.size()
	RunState.walking = true
	MetaState.remember_run(_summary(false, false, 1, 3))
	RunState.walking = false
	RunState.sandbox = true
	MetaState.remember_run(_summary(false, false, 7, 400))
	RunState.sandbox = false
	_check(MetaState.run_history.size() == before, "the Walk or a sandbox left a stone")
	_reached.append("refused")


func _test_the_list_is_bounded_and_records_outlive_it() -> void:
	MetaState.run_history.clear()
	MetaState.run_records = {}
	MetaState.remember_run(_summary(false, false, 9, 99999))
	for index: int in Balance.RUN_HISTORY_MAX + 6:
		MetaState.remember_run(_summary(false, false, 2, 10 + index))
	_check(MetaState.run_history.size() == Balance.RUN_HISTORY_MAX,
		"the history kept %d roads against %d" % [MetaState.run_history.size(), Balance.RUN_HISTORY_MAX])
	var oldest_kept: int = int(MetaState.run_history[MetaState.run_history.size() - 1]["kills"])
	_check(oldest_kept != 99999, "the oldest road was kept past the list's length")
	_check(int(MetaState.run_records.get("kills", 0)) == 99999, "a record fell off with the road that set it")
	_reached.append("bounded")


func _test_the_save_reads_clean() -> void:
	MetaState.run_history.clear()
	MetaState.run_records = {}
	MetaState.remember_run(_summary(false, false, 4, 210))
	MetaState.remember_run(_summary(false, true, 6, 330))
	var parsed: Variant = JSON.parse_string(MetaState.serialized_save())
	_check(parsed is Dictionary, "the save does not parse")
	if not (parsed is Dictionary):
		_reached.append("save")
		return
	var stats: Dictionary = (parsed as Dictionary).get("stats", {}) as Dictionary
	var written: Array = stats.get("run_history", []) as Array
	_check(written.size() == 2, "the save carries %d stones" % written.size())
	# Planted rows: a forged ending, an act past the summit, a level past the cap,
	# a cause too long to draw, an unknown road and a helmet in the weapon's hand.
	written.append({"ended": "ascended", "act": 3})
	written.append("not a row")
	written.append({"ended": "fell", "act": 99, "level": 999, "cause": "x".repeat(500),
		"tier": "nowhere", "gear": ["ironcrown_barbute", "", "", "", ""], "kills": 5})
	stats["run_history"] = written
	stats["run_records"] = {"kills": 7, "wave": "many", "act": 99}
	MetaState.adopt_save(parsed as Dictionary)
	var rows: Array[Dictionary] = MetaState.run_history
	_check(rows.size() == 3, "the read kept %d stones from 2 good and 3 planted" % rows.size())
	if rows.size() == 3:
		var planted: Dictionary = rows[2]
		_check(int(planted["act"]) == Balance.FINAL_ASCENT_ACT and int(planted["level"]) == Balance.HERO_MAX_LEVEL,
			"a planted stone read back at act %d, level %d" % [int(planted["act"]), int(planted["level"])])
		_check(String(planted["cause"]).length() <= 96 and String(planted["tier"]).is_empty(),
			"a planted stone kept its long cause or its unknown road")
		_check(String((planted["gear"] as Array)[0]).is_empty(), "a helmet was read into the weapon's hand")
	_check(int(MetaState.run_records.get("kills", 0)) == 330, "the records did not take the best of the stones read")
	_check(int(MetaState.run_records.get("act", 0)) == Balance.FINAL_ASCENT_ACT,
		"a stored record past the summit read back as act %d" % int(MetaState.run_records.get("act", 0)))
	_reached.append("save")


func _test_the_door_that_writes() -> void:
	var director: String = FileAccess.get_file_as_string("res://autoload/GameDirector.gd")
	var at: int = director.find("func _settle_run(")
	var body: String = director.substr(at, director.find("\nfunc ", at + 10) - at) if at >= 0 else ""
	_check(body.contains("MetaState.remember_run(summary)"), "a settled road is never remembered")
	_check(body.find("MetaState.remember_run(summary)") < body.find("MetaState.save_game()"),
		"a road is remembered after the save, so the stone is lost on quit")
	_reached.append("door")


func _test_the_cairn_reads() -> void:
	MetaState.run_history.clear()
	MetaState.run_records = {}
	MetaState.remember_run(_summary(false, false, 3, 120))
	MetaState.remember_run(_summary(false, true, 5, 300))
	MetaState.remember_run(_summary(false, false, 7, 410))
	var before: String = MetaState.serialized_save()
	var screen := CairnScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	for _frame: int in 4:
		await get_tree().process_frame
	_check(CairnScreen.fallen_rows().size() == 2, "the Cairn shows %d fallen of 2" % CairnScreen.fallen_rows().size())
	var records := screen.find_child("Heading_records", true, false) as Label
	_check(records != null and not records.text.is_empty(), "the Cairn has no records heading")
	var words: PackedStringArray = []
	for node: Node in screen.find_children("*", "Label", true, false):
		words.append((node as Label).text)
	var all: String = " ".join(words)
	_check(all.contains("410"), "the Cairn does not show the most fallen in one road")
	_check(all.contains("Bog Crane"), "the Cairn does not say what felled the last Warden")
	_check(MetaState.serialized_save() == before, "opening the Cairn wrote to the account")
	screen.hide_screen()
	screen.queue_free()
	await get_tree().process_frame
	_reached.append("screen")
