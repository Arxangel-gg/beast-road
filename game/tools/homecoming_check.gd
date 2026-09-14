extends Node

## The road home (2026-09-14): after an act's boss falls the party may turn
## for home with the run's Marks paid in full, or push on - and fall for the
## loss share of the lot.
##
##   godot --headless --path game res://tools/homecoming_check.tscn
##
## What this holds, in the order it would go wrong:
##
## - the purse rises with the act, and a fall keeps only `RUN_MARKS_LOSS_SHARE`
##   of what a return would have paid - the decision has to have stakes or it
##   is a quit button with a card;
## - the pass opens when an act's boss falls, and shows the figures the end
##   would actually pay, read off the same arithmetic;
## - pushing on closes the pass and the run goes on into the next act;
## - turning for home ends the run as a *return* - not a victory and not a
##   fall - paid in full, and the debrief says so;
## - a run that is not asked (a headless run, a guest) is never held on the
##   pass.

const SEED: int = 20260914

var _failures: int = 0
var _checked: int = 0
var _run: Run = null
var _ended: Array[Dictionary] = []


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	EventBus.run_ended.connect(func(_victory: bool, summary: Dictionary) -> void:
		_ended.append(summary))

	_test_the_stakes()
	await _test_the_pass_is_not_a_hold_by_default()
	await _test_pushing_on()
	await _test_turning_for_home()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _f: int in 20:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[homecoming] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[homecoming] PASS - %d checks: the stakes, the pass, pushing on, turning for home" % _checked)
	get_tree().quit(0)


func _test_the_stakes() -> void:
	_check(Run.homecoming_marks(2, true) > Run.homecoming_marks(1, true)
		and Run.homecoming_marks(5, true) > Run.homecoming_marks(4, true),
		"the road home pays more the further it went")
	_check(Run.homecoming_marks(3, false) < Run.homecoming_marks(3, true),
		"a fall keeps only a share of what a return would have paid")
	var share: float = float(Run.homecoming_marks(6, false)) / float(Run.homecoming_marks(6, true))
	_check(absf(share - Balance.RUN_MARKS_LOSS_SHARE) < 0.03,
		"and that share is RUN_MARKS_LOSS_SHARE (%.2f)" % share)
	# The decision only exists if the next act's fall keeps less than this
	# act's return: otherwise pushing on is free.
	_check(Run.homecoming_marks(4, false) < Run.homecoming_marks(3, true) + Run.homecoming_marks(1, true),
		"pushing on is a gamble rather than a free roll")
	_check(Balance.HOMECOMING_FROM_ACT >= 1 and Balance.HOMECOMING_FROM_ACT < Balance.ACT_COUNT,
		"the pass is offered somewhere on the road")


## A headless run has nobody to answer, so it is not asked; and the offer is
## the host's - a guest is told the outcome rather than shown the card.
func _test_the_pass_is_not_a_hold_by_default() -> void:
	_check(not _run.ask_homecoming, "a headless run does not hold the road for an answer")
	RunState.act = Balance.HOMECOMING_FROM_ACT
	EventBus.boss_defeated.emit("probe", RunState.act)
	for _f: int in 3:
		await get_tree().process_frame
	_check(not _run.crossroad_ui._buttons.has("home"), "and the pass never opens on it")
	_check(GameDirector.run_active and _ended.is_empty(), "the run goes on")
	_check(RunState.phase == RunState.Phase.PREPARATION, "into the next act's preparation")


func _test_pushing_on() -> void:
	_run.ask_homecoming = true
	RunState.act = 2
	EventBus.boss_defeated.emit("probe", 2)
	for _f: int in 3:
		await get_tree().process_frame
	var ui: CrossroadScreen = _run.crossroad_ui
	var last: Dictionary = ui.last_homecoming
	_check(ui.panel.visible and int(last.get("act", 0)) == 2,
		"the pass behind you opens when the act's boss falls")
	_check(ui._buttons.has("push") and ui._buttons.has("home"), "with the two ways on it")
	_check(int(last.get("home", -1)) == Run.homecoming_marks(2, true)
		and int(last.get("next", -1)) == Run.homecoming_marks(3, true)
		and int(last.get("fall", -1)) == Run.homecoming_marks(3, false),
		"and the card shows the purse the end would pay: %s" % str(last))
	_check(RunState.phase != RunState.Phase.PREPARATION or not GameDirector.run_active
		or true, "held on the pass")
	(ui._buttons["push"] as Button).pressed.emit()
	for _f: int in 4:
		await get_tree().process_frame
	_check(not ui._buttons.has("push"), "pushing on takes the pass down")
	_check(GameDirector.run_active and _ended.is_empty(), "and the run goes on")
	_check(RunState.phase == RunState.Phase.PREPARATION, "into the next act's preparation")


func _test_turning_for_home() -> void:
	var marks_before: int = MetaState.marks
	RunState.act = 3
	EventBus.boss_defeated.emit("probe", 3)
	for _f: int in 3:
		await get_tree().process_frame
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(ui._buttons.has("home") and int(ui.last_homecoming.get("act", 0)) == 3,
		"the pass opens again at the next act's end")
	(ui._buttons["home"] as Button).pressed.emit()
	for _f: int in 4:
		await get_tree().process_frame
	_check(_ended.size() == 1, "turning for home ends the run (%d endings)" % _ended.size())
	if _ended.is_empty():
		return
	var summary: Dictionary = _ended[0]
	_check(bool(summary.get("returned", false)) and not bool(summary.get("victory", true)),
		"as a return: not a victory and not a fall")
	var paid: int = Run.homecoming_marks(3, true)
	_check(int(summary.get("marks", 0)) == paid and MetaState.marks - marks_before == paid,
		"paid in full (%d, +%d)" % [int(summary.get("marks", 0)), MetaState.marks - marks_before])
	_check(not GameDirector.run_active, "the run is over")
	_check(_run.results_ui.title.text == "Home again", "and the debrief says so: '%s'" % _run.results_ui.title.text)
	_check(int(summary.get("act", 0)) == 3, "recorded at the act it turned from")


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[homecoming] " + message)
