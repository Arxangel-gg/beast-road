extends Node

## Hardcore: one wound, alone, and a road that does not come home buries the
## slot (owner, 2026-09-30: *"Hardcore players and leaderboards who lose
## everything including that save slot if they do not successfully extract,
## and only have 1/1 wounds possible ever"*).
##
##   godot --headless --path game res://tools/hardcore_check.tscn
##
## **The rule that cannot be dodged is the load.** A road that is left by the
## pause menu, a crash or a pulled plug never reaches the debrief, so the flag
## is written when the road begins and read on every load - and that is the
## door this gate drives hardest, through the real `load_save` on a real file.
##
## Everything that writes is pointed at a fixture first, through the documented
## `MetaState.slot_root` seam `save_slot_check` already uses: the doors under
## test are the real ones and a developer's own Wardens are on no path this
## gate can reach.

const FIXTURE_DIR: String = "res://.automated_checks/hardcore"
const FIXTURE_BASE: String = FIXTURE_DIR + "/probe.json"

var _failures: int = 0
var _checked: int = 0
var _saved_root: String = ""
var _saved_slot: int = 0
var _saved_phase: int = 0
var _last_summary: Dictionary = {}
## Each test stamps its name as its last statement: a runtime error aborts a
## function silently, and a count of checks is not a proof that they ran.
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	_saved_root = MetaState.slot_root
	_saved_slot = MetaState.slot()
	_saved_phase = int(RunState.phase)
	_open_the_fixture()
	# Resumed inside the fixture: the subject is what reaches the disk.
	MetaState.resume_saves()
	EventBus.run_ended.connect(_on_run_ended)

	var tests: Array[String] = ["oath", "load", "settle", "board", "leaving",
		"doors", "slots"]
	_test_the_oath()
	_test_a_road_left_buries_the_slot()
	await _test_the_road_ends()
	_test_the_board()
	_test_leaving_says_so()
	_test_the_doors()
	await _test_the_slot_screen()
	for name: String in tests:
		_check(_reached.has(name), "'%s' never reached its end" % name)

	EventBus.run_ended.disconnect(_on_run_ended)
	GameDirector.run_active = false
	MetaState.hold_saves()
	_close_the_fixture()
	if _failures == 0:
		print("[hardcore] PASS - %d checks; one wound, alone, and a road that does "
			% _checked + "not come home buries the slot")
	else:
		push_error("[hardcore] FAIL - %d of %d" % [_failures, _checked])
	MetaState.resume_saves()
	get_tree().quit(1 if _failures > 0 else 0)


func _on_run_ended(_victory: bool, summary: Dictionary) -> void:
	_last_summary = summary


# --- The oath ------------------------------------------------------------------

## Sworn only by a Warden who has never walked a road, never taken off, carried
## through the save, and one wound whatever raises the ceiling.
func _test_the_oath() -> void:
	_fresh()
	_check(MetaState.set_hardcore().is_empty() and MetaState.hardcore,
		"a new Warden could not swear Hardcore")
	_check(MetaState.set_hardcore().is_empty() and MetaState.hardcore,
		"swearing it twice must be harmless")
	_fresh()
	MetaState.runs_started = 1
	_check(not MetaState.set_hardcore().is_empty() and not MetaState.hardcore,
		"a Warden who has walked a road swore Hardcore after the fact")

	_fresh()
	MetaState.set_hardcore()
	MetaState.hardcore_road_live = true
	var data: Dictionary = MetaState.parse_save_text(MetaState.serialized_save())
	MetaState.call("_adopt_new_account")
	MetaState.adopt_save(data)
	_check(MetaState.hardcore and MetaState.hardcore_road_live,
		"the oath and the live road must survive the save")
	var stats: Dictionary = data.get("stats", {}) as Dictionary
	stats["hardcore"] = false
	stats["hardcore_road_live"] = true
	MetaState.adopt_save(data)
	_check(not MetaState.hardcore_road_live,
		"an ordinary Warden read a Hardcore road off the save")

	_fresh()
	MetaState.set_hardcore()
	RunState.hero_max_wounds_bonus = 5
	_check(RunState.max_wounds() == 1,
		"a Hardcore Warden carries %d wounds - the oath is one, whatever raises it"
		% RunState.max_wounds())
	MetaState.hardcore = false
	RunState.hero_max_wounds_bonus = 0
	_check(RunState.max_wounds() == Balance.HERO_MAX_WOUNDS,
		"an ordinary Warden lost their wounds to the Hardcore rule")
	_reached["oath"] = true


# --- The load ------------------------------------------------------------------

## A road begun and never brought home is found on the next read and the slot
## is buried: the first slot's file written as a new account, any other slot's
## file deleted. A road brought home, and an ordinary Warden, are left alone.
func _test_a_road_left_buries_the_slot() -> void:
	_fresh()
	MetaState.set_hardcore()
	MetaState.hero_level = 40
	MetaState.marks = 500
	MetaState.hardcore_road_began()
	MetaState.hardcore_buried_on_load = false
	MetaState.load_save()
	_check(not MetaState.hardcore and MetaState.hero_level == 1 and MetaState.marks == 0,
		"a Hardcore road never brought home survived the load (hardcore %s, level %d, %d Marks)"
		% [str(MetaState.hardcore), MetaState.hero_level, MetaState.marks])
	_check(MetaState.hardcore_buried_on_load,
		"a burial on the load must be said on the menu")
	var disk: Dictionary = MetaState.parse_save_text(
		MetaState.read_committed_text(MetaState.slot_path(0)))
	var hero: Dictionary = disk.get("hero", {}) as Dictionary
	_check(not disk.is_empty() and int(hero.get("level", 1)) == 1,
		"the first slot's file must be written over as a new account")
	_check(MetaState.stash.size() > 0,
		"a buried slot begins again with what a new account is given")
	MetaState.hardcore_buried_on_load = false

	_check(MetaState.use_slot(1), "could not move to the second slot in the fixture")
	MetaState.set_hardcore()
	MetaState.hardcore_road_began()
	_check(FileAccess.file_exists(MetaState.slot_path(1)),
		"beginning a Hardcore road must write the slot at once")
	MetaState.load_save()
	_check(not FileAccess.file_exists(MetaState.slot_path(1)),
		"a buried second slot's file must be gone")
	_check(MetaState.slot_summary(1).get("exists", false) == true and not MetaState.hardcore,
		"the slot being stood in reads as a new Warden")
	MetaState.hardcore_buried_on_load = false
	MetaState.use_slot(0)

	_fresh()
	MetaState.set_hardcore()
	MetaState.hero_level = 22
	MetaState.hardcore_road_began()
	MetaState.hardcore_road_home()
	MetaState.save_game()
	MetaState.load_save()
	_check(MetaState.hardcore and MetaState.hero_level == 22,
		"a Hardcore Warden who came home was buried anyway")

	_fresh()
	MetaState.hero_level = 9
	MetaState.hardcore_road_live = true
	MetaState.save_game()
	MetaState.load_save()
	_check(MetaState.hero_level == 9 and not MetaState.hardcore_buried_on_load,
		"an ordinary Warden was buried")
	_reached["load"] = true


# --- The road's end ------------------------------------------------------------

## Through the real `_settle_run`: a fall buries after the debrief is built,
## and the debrief carries who ran it; home and the summit keep the Warden;
## an ordinary Warden's fall buries nobody.
func _test_the_road_ends() -> void:
	_fresh()
	MetaState.set_hardcore()
	MetaState.player_name = "Tester"
	MetaState.hero_level = 12
	_begin_a_road()
	GameDirector._settle_run(false)
	await get_tree().process_frame
	_check(bool(_last_summary.get("buried", false)) and bool(_last_summary.get("hardcore", false)),
		"a Hardcore fall must be told as a burial")
	_check(String(_last_summary.get("warden", "")) == "Tester"
		and int(_last_summary.get("warden_level", 0)) == 12,
		"the debrief must carry the Warden who ran it (%s, %d)"
		% [String(_last_summary.get("warden", "")), int(_last_summary.get("warden_level", 0))])
	_check(not MetaState.hardcore and MetaState.hero_level == 1,
		"a Hardcore Warden who fell kept their account")
	_check((_last_summary.get("unlocks", [1]) as Array).is_empty(),
		"a buried Warden's debrief listed unlocks they no longer hold")

	for ending: Array in [[false, true, "a return"], [true, false, "the summit"]]:
		_fresh()
		MetaState.set_hardcore()
		MetaState.hero_level = 30
		_begin_a_road()
		GameDirector._settle_run(bool(ending[0]), bool(ending[1]))
		await get_tree().process_frame
		_check(MetaState.hardcore and not MetaState.hardcore_road_live
			and not bool(_last_summary.get("buried", false)),
			"%s buried a Hardcore Warden" % String(ending[2]))

	_fresh()
	MetaState.hero_level = 15
	_begin_a_road()
	GameDirector._settle_run(false)
	await get_tree().process_frame
	_check(not bool(_last_summary.get("buried", false)) and MetaState.hero_level >= 15,
		"an ordinary Warden's fall buried them")
	GameDirector.run_active = false
	_reached["settle"] = true


# --- The board -----------------------------------------------------------------

## A Hardcore run goes to its own board and says so beside the row, never in
## the post; a buried Warden's run is not kept on the new account; the mark
## survives the outbox and the save.
func _test_the_board() -> void:
	_fresh()
	_check(Leaderboard.table_for(true) == Leaderboard.HARDCORE_TABLE
		and Leaderboard.table_for(false) == Leaderboard.TABLE,
		"the Hardcore board must be a table of its own")
	var row: Dictionary = {"submission_id": "hc", "name": "Gone", "tier": "normal",
		"score": 10, "act": 1, "wave": 3, "hero_level": 7, "duration": 60,
		"victory": false, "seed": "1", "version": "0.1.0", "board": "hardcore"}
	_check(Score.is_hardcore(Score.clean_kept(row)) and not Score.clean_row(row).has("board"),
		"a kept row keeps its board, and a posted row never carries it")

	var tier: CampaignTierData = ContentDB.tier("normal")
	var buried: Dictionary = {"hardcore": true, "buried": true, "warden": "Gone",
		"warden_level": 7, "act": 1, "wave": 3, "time": 60}
	Leaderboard.submit(buried, tier)
	_check(MetaState.best_runs.is_empty(),
		"a buried Warden's run was kept on the new account")
	_check(MetaState.pending_runs.size() == 1 and Score.is_hardcore(MetaState.pending_runs[0])
		and String((MetaState.pending_runs[0] as Dictionary).get("name", "")) == "Gone",
		"a Hardcore run must wait for the Hardcore board, under the Warden who ran it")

	var kept: Dictionary = buried.duplicate()
	kept.erase("buried")
	Leaderboard.submit(kept, tier)
	Leaderboard.submit({"act": 1, "wave": 4, "time": 70}, tier)
	_check(Leaderboard.local_board("normal", true).size() == 1
		and Leaderboard.local_board("normal", false).size() == 1,
		"each board must show its own runs and not the other's")

	var data: Dictionary = MetaState.parse_save_text(MetaState.serialized_save())
	MetaState.adopt_save(data)
	var marked: int = 0
	for entry: Variant in MetaState.pending_runs:
		if entry is Dictionary and Score.is_hardcore(entry as Dictionary):
			marked += 1
	_check(marked == 2, "the outbox must keep which runs were Hardcore through the save (%d)"
		% marked)
	MetaState.pending_runs.clear()
	MetaState.best_runs.clear()
	_reached["board"] = true


# --- Leaving -------------------------------------------------------------------

func _test_leaving_says_so() -> void:
	_fresh()
	MetaState.set_hardcore()
	_begin_a_road()
	var said: String = PauseMenu.leaving_costs()
	_check(said.contains("Hardcore") and said.contains("buries"),
		"the pause menu must say leaving a Hardcore road buries the Warden: '%s'" % said)
	MetaState.hardcore = false
	MetaState.hardcore_road_live = false
	_check(not PauseMenu.leaving_costs().contains("Hardcore"),
		"an ordinary road was warned about Hardcore")
	GameDirector.run_active = false
	_reached["leaving"] = true


# --- The doors, by source ------------------------------------------------------

## Read off the source because each is a door a headless gate cannot walk
## through without losing its own scene: the menu, the Hold's party and the
## co-op screen. The failure is an omission, which is what a source walk sees.
func _test_the_doors() -> void:
	var director: String = FileAccess.get_file_as_string("res://autoload/GameDirector.gd")
	var menu_at: int = director.find("func goto_menu() -> void:")
	var body: String = director.substr(menu_at, 700)
	_check(body.find("bury_hardcore") >= 0 and body.find("bury_hardcore") < body.find("run_active = false"),
		"leaving a road for the menu must bury a Hardcore Warden before the road is let go")
	var start_at: int = director.find("func start_run(")
	var start: String = director.substr(start_at, director.find("\nfunc ", start_at + 10) - start_at)
	_check(start.contains("MetaState.hardcore_road_began()") and start.contains("Coop.leave()"),
		"a road must mark itself begun, and a Hardcore Warden must walk it alone")
	var meta: String = FileAccess.get_file_as_string("res://autoload/MetaState.gd")
	var load_at: int = meta.find("func load_save() -> void:")
	_check(meta.substr(load_at, meta.find("\nfunc ", load_at + 10) - load_at)
		.contains("_bury_if_the_road_was_left()"),
		"the load must look for a road never brought home")
	_check(FileAccess.get_file_as_string("res://scenes/ui/main_menu.gd").contains("Hardcore walks alone"),
		"the co-op door must refuse a Hardcore Warden and say why")
	var hold: String = FileAccess.get_file_as_string("res://scripts/systems/hold_session.gd")
	_check(hold.contains("occupied() < 2 or MetaState.hardcore")
		and hold.contains("accepted and not MetaState.hardcore"),
		"the Hold must never put a shared road to or from a Hardcore Warden")
	_reached["doors"] = true


# --- The slot screen -----------------------------------------------------------

func _test_the_slot_screen() -> void:
	_fresh()
	MetaState.save_game()
	var screen := SaveSlotScreen.new()
	add_child(screen)
	screen.open()
	await get_tree().process_frame
	var begin := screen.find_child("Hardcore2", true, false) as Button
	_check(begin != null and begin.text.contains("Hardcore"),
		"an empty slot must offer to begin as Hardcore")
	if begin != null:
		begin.pressed.emit()
		await get_tree().process_frame
		_check(MetaState.slot() == 2 and MetaState.hardcore,
			"beginning an empty slot as Hardcore did not swear it (slot %d, hardcore %s)"
			% [MetaState.slot(), str(MetaState.hardcore)])
		_check(bool(MetaState.slot_summary(2).get("hardcore", false)),
			"the slot card must say the Warden is Hardcore")
	MetaState.use_slot(0)
	_fresh()
	screen.refresh()
	await get_tree().process_frame
	var swear := screen.find_child("Hardcore0", true, false) as Button
	_check(swear != null, "a Warden who has never walked a road must be offered the oath")
	if swear != null:
		swear.pressed.emit()
		_check(not MetaState.hardcore, "one press swore the oath - it asks twice")
		swear.pressed.emit()
		_check(MetaState.hardcore, "the second press must swear it")
	screen.queue_free()
	await get_tree().process_frame
	MetaState.hardcore = false
	_reached["slots"] = true


# --- Harness -------------------------------------------------------------------

## A new account in the fixture's first slot.
func _fresh() -> void:
	MetaState.call("_adopt_new_account")
	MetaState.hardcore_buried_on_load = false
	MetaState.pending_runs.clear()
	MetaState.best_runs.clear()


func _begin_a_road() -> void:
	RunState.reset()
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	GameDirector.run_active = true
	MetaState.hardcore_road_began()


func _open_the_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	MetaState.slot_root = FIXTURE_BASE
	_wipe_the_fixture()
	MetaState.call("_adopt_new_account")


func _close_the_fixture() -> void:
	_wipe_the_fixture()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	MetaState.slot_root = _saved_root
	RunState.set_phase(_saved_phase as RunState.Phase)
	MetaState.set("_slot", _saved_slot)


func _wipe_the_fixture() -> void:
	var dir: DirAccess = DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return
	for name: String in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR.path_join(name)))


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if not passed:
		_failures += 1
		push_error("[hardcore] " + message)
