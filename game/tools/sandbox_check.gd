extends Node

## **A sandbox road keeps nothing** (2026-09-30, `IDEAS_REVIEW_2026-09-23`
## §4.3): every tower, a full purse, any act, and the account read back from
## disk when the road ends.
##
##   godot --headless --path game res://tools/sandbox_check.tscn
##
## The account is the one thing git cannot restore, so this drives the real
## doors in a `slot_root` fixture, as `hardcore_check` does: the account is
## written, the sandbox holds it, the road changes everything a road can change
## - Marks, a level, the whole roster, a piece of gear, a save attempt - and
## the real `_settle_run` ends it. What is on the disk and what is in memory
## must both be what they were, byte for byte.

const TAG: String = "[sandbox]"
const FIXTURE_DIR: String = "res://.automated_checks/sandbox"
const FIXTURE_BASE: String = FIXTURE_DIR + "/probe.json"

var _failures: int = 0
var _checked: int = 0
var _saved_root: String = ""
var _saved_slot: int = 0
var _saved_phase: int = 0
var _last_summary: Dictionary = {}
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	_saved_root = MetaState.slot_root
	_saved_slot = MetaState.slot()
	_saved_phase = int(RunState.phase)
	_open_the_fixture()
	MetaState.resume_saves()
	EventBus.run_ended.connect(_on_run_ended)

	await _test_the_account_comes_back()
	_test_the_road_opens()
	await _test_a_hardcore_sandbox_buries_nobody()
	_test_it_is_not_posted()
	_test_the_doors()
	for stage: String in ["account", "road", "hardcore", "board", "doors"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)

	EventBus.run_ended.disconnect(_on_run_ended)
	GameDirector.run_active = false
	if GameDirector.sandbox_holding():
		GameDirector.call("_release_sandbox")
	MetaState.hold_saves()
	_close_the_fixture()
	if _failures == 0:
		print("%s PASS - %d checks: the disk is untouched and the account read back, the road opens where it was asked with every tower and the purse, and nothing is posted" % [TAG, _checked])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checked])
	MetaState.resume_saves()
	get_tree().quit(1 if _failures > 0 else 0)


func _on_run_ended(_victory: bool, summary: Dictionary) -> void:
	_last_summary = summary


func _disk() -> String:
	return FileAccess.get_file_as_string(MetaState.slot_path(MetaState.slot()))


## A played account: Marks, a level, a piece of gear, a tower bought.
func _played() -> void:
	MetaState.call("_adopt_new_account")
	MetaState.pending_runs.clear()
	MetaState.best_runs.clear()
	MetaState.marks = 321
	MetaState.hero_level = 9
	MetaState.player_name = "Holder"
	MetaState.save_game()


## Through the real doors: hold, open, change everything, settle.
func _test_the_account_comes_back() -> void:
	_played()
	var memory: String = MetaState.serialized_save()
	var disk: String = _disk()
	_check(not disk.is_empty(), "the fixture account must be on disk")
	_check(bool(GameDirector.call("_hold_for_sandbox")), "a sandbox must take the account")
	_check(not bool(GameDirector.call("_hold_for_sandbox")), "a second sandbox may not take it twice")
	RunState.reset()
	RunState.sandbox = true
	GameDirector.call("_open_the_sandbox", 4)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	GameDirector.run_active = true
	# Everything a road can do to an account.
	MetaState.marks += 5000
	MetaState.hero_level = 60
	var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 3, RandomNumberGenerator.new())
	MetaState.stash.append(piece)
	MetaState.unlocked_towers.append("not_a_tower")
	MetaState.save_game()
	_check(_disk() == disk, "a save during a sandbox road reached the disk")
	GameDirector._settle_run(false)
	await get_tree().process_frame
	_check(bool(_last_summary.get("sandbox", false)), "the debrief must say it was a sandbox")
	_check((_last_summary.get("unlocks", [1]) as Array).is_empty()
		and int(_last_summary.get("tools", 1)) == 0,
		"a sandbox's debrief listed a payout it did not keep")
	_check(not GameDirector.sandbox_holding() and not MetaState.saves_held(),
		"the account must be let go when the road ends")
	_check(_disk() == disk, "the disk after a sandbox is not what it was")
	# Compared as parsed JSON, which has no integers - a setting read back from
	# disk is a float where the account that wrote it held an int, and that is
	# the save format rather than the sandbox.
	_check(str(JSON.parse_string(MetaState.serialized_save())) == str(JSON.parse_string(memory)),
		"the account after a sandbox is not what it was: Marks %d, level %d, %d pieces"
		% [MetaState.marks, MetaState.hero_level, MetaState.stash.size()])
	GameDirector.run_active = false
	_reached.append("account")


## Where it was asked, with the purse, the wall whole and every tower.
func _test_the_road_opens() -> void:
	_played()
	GameDirector.call("_hold_for_sandbox")
	RunState.reset()
	RunState.sandbox = true
	GameDirector.call("_open_the_sandbox", 6)
	_check(RunState.act == 6, "a sandbox at Act VI opened at Act %d" % RunState.act)
	var terrain: TerrainData = ContentDB.terrain_for_act(6)
	_check(terrain != null and RunState.terrain_id == terrain.id,
		"a sandbox at Act VI must be on its ground")
	for id: String in RunState.CURRENCIES:
		_check(RunState.currency(id) == Balance.SANDBOX_PURSE,
			"a sandbox's %s is %d, not the purse" % [id, RunState.currency(id)])
	_check(is_equal_approx(RunState.town_hp, RunState.town_max_hp), "a sandbox's wall must be whole")
	var missing: int = 0
	for tower: TowerData in ContentDB.base_towers():
		if not MetaState.unlocked_towers.has(tower.id):
			missing += 1
	_check(missing == 0, "a sandbox left %d towers locked" % missing)
	_check(RunState.pending_outfit.is_empty(), "a sandbox must build no board: that is the player's to do")
	var line: String = PauseMenu.leaving_costs() if GameDirector.run_active else ""
	GameDirector.run_active = true
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	line = PauseMenu.leaving_costs()
	_check(line.contains("sandbox") and line.contains("Nothing"),
		"the pause menu must say a sandbox keeps nothing, said '%s'" % line)
	GameDirector.run_active = false
	GameDirector.call("_release_sandbox")
	# Act I opens where Act I opens.
	_played()
	GameDirector.call("_hold_for_sandbox")
	RunState.reset()
	GameDirector.call("_open_the_sandbox", 1)
	_check(RunState.act == 1 and RunState.wave_number == 0,
		"a sandbox at Act I must open where Act I opens")
	GameDirector.call("_release_sandbox")
	_reached.append("road")


## A Hardcore Warden's sandbox is not their road: a fall there buries nobody.
func _test_a_hardcore_sandbox_buries_nobody() -> void:
	MetaState.call("_adopt_new_account")
	MetaState.set_hardcore()
	MetaState.save_game()
	var disk: String = _disk()
	GameDirector.call("_hold_for_sandbox")
	RunState.reset()
	RunState.sandbox = true
	GameDirector.call("_open_the_sandbox", 2)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	GameDirector.run_active = true
	MetaState.hardcore_road_began()
	GameDirector._settle_run(false)
	await get_tree().process_frame
	_check(not bool(_last_summary.get("buried", false)), "a sandbox fall was told as a burial")
	_check(MetaState.hardcore and _disk() == disk,
		"a Hardcore Warden's sandbox fall reached their account")
	GameDirector.run_active = false
	_reached.append("hardcore")


func _test_it_is_not_posted() -> void:
	_played()
	var answer: Array = [true, ""]
	var ear: Callable = func(ok: bool, message: String) -> void:
		answer[0] = ok
		answer[1] = message
	Leaderboard.submitted.connect(ear)
	Leaderboard.submit({"sandbox": true, "act": 6, "wave": 40, "time": 600},
		ContentDB.tier("normal"))
	Leaderboard.submitted.disconnect(ear)
	_check(not bool(answer[0]) and String(answer[1]).contains("sandbox"),
		"a sandbox road was posted: %s" % str(answer))
	_check(MetaState.best_runs.is_empty() and MetaState.pending_runs.is_empty(),
		"a sandbox road was kept on the board")
	_reached.append("board")


## Omissions a driven test cannot see.
func _test_the_doors() -> void:
	var director: String = FileAccess.get_file_as_string("res://autoload/GameDirector.gd")
	var menu: String = director.get_slice("func goto_menu", 1).get_slice("\nfunc ", 0)
	_check(menu.contains("_release_sandbox()"), "leaving from the pause menu must let the account go")
	var hold: String = director.get_slice("func _hold_for_sandbox", 1).get_slice("\nfunc ", 0)
	_check(hold.contains("Coop.is_networked()"), "a sandbox must be refused on a shared road")
	var hub: String = FileAccess.get_file_as_string("res://scenes/ui/hub_screen.gd")
	_check(hub.contains("if not Coop.is_networked():\n\t\t_road_button(\"Sandbox"),
		"the Hold must offer the sandbox to a Warden alone and never to a party")
	var results: String = FileAccess.get_file_as_string("res://scenes/ui/results_screen.gd")
	_check(results.contains("summary.get(\"sandbox\"") and results.contains("_submit_button.disabled = true"),
		"the debrief must say a sandbox is not posted")
	_reached.append("doors")


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
		push_error("%s %s" % [TAG, message])
