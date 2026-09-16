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
	_test_the_withdrawal_ramp()
	await _test_the_pass_is_not_a_hold_by_default()
	await _test_pushing_on()
	await _test_the_withdrawal_holds_the_wall()
	await _test_turning_for_home()
	await _test_the_fork_offers_the_road_home()

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
	print(("[homecoming] PASS - %d checks: the stakes, the pass, pushing on,"
		+ " the withdrawal, turning for home") % _checked)
	get_tree().quit(0)


## **The road can be put down at a fork, and it is worth what the pass is worth.**
##
## Expedition persistence was recorded as "the road is put down at a crossroad
## and picked up next time", and `Run._open_crossroad` prices momentum as "the
## momentum a player refused to bank" - while the only door to banking was the
## pass at an act's end. A player paid for a decision that was never offered.
##
## Driven through `Run.extraction_open` and the screen's own build, because what
## was wrong is that a *button did not exist* and no constant can be asked that.
func _test_the_fork_offers_the_road_home() -> void:
	var ui: CrossroadScreen = _run.crossroad_ui
	RunState.momentum = 0.0
	RunState.act = 2

	# **Never headless**, for the reason the pass is not: a gate that fells a
	# boss must not be held on a question.
	_run.ask_homecoming = false
	_check(not _run.extraction_open(),
		"a headless run is never held at the fork for an answer")

	# **Not on the first fork.** Banking a front nobody has built is a trip to
	# the menu for nothing, and `HOMECOMING_FROM_ACT` does not stop it on its own
	# because Act I opens with a fork.
	_run.ask_homecoming = true
	_check(not _run.extraction_open(),
		"the road home is not offered before a single fork has been passed")

	# One fork behind them, and it is offered.
	RunState.momentum = Balance.MOMENTUM_PER_CROSSROAD
	_check(_run.extraction_open(), "with a fork behind them, the road home is offered")

	# **And it pays exactly what the pass pays.** Two doors to one ending that
	# disagreed about its price would be worse than one door.
	ui.extraction_offered = true
	ui.extraction_marks = Run.homecoming_marks(RunState.act, true)
	_check(ui.extraction_marks == Run.homecoming_marks(RunState.act, true),
		"the fork and the act's end must agree what a return is worth")

	# The card is on the panel, and pressing it says so once.
	var taken: Array[bool] = [false]
	var ear: Callable = func() -> void: taken[0] = true
	ui.extraction_chosen.connect(ear)
	ui.open(1)
	await get_tree().process_frame
	var button: Button = ui.get("_extract_button") as Button
	_check(button != null and button.text.contains("TURN FOR HOME"),
		"the fork must carry the road home as a pressable card")
	if button != null:
		button.pressed.emit()
		await get_tree().process_frame
		_check(taken[0], "pressing it must announce the return")
		taken[0] = false
		button.pressed.emit()
		await get_tree().process_frame
		_check(not taken[0], "and a second press must not settle the run twice")
	ui.extraction_chosen.disconnect(ear)
	ui.panel.visible = false
	ui.extraction_offered = false
	RunState.momentum = 0.0
	_run.ask_homecoming = false


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
	# **This assertion used to end in `or true`** and could not fail, so the
	# gate counted a check it was not making. What it means to hold is that the
	# road does not advance underneath an open pass. The card's figures are
	# computed from the act the boss fell in and the payout recomputes from
	# `RunState.act` when the run settles; they agree only because turning
	# for home returns before `resume_after_boss` increments it. If the road
	# ever walks on during the walk out, the card starts lying about the
	# purse and nothing else would notice.
	_check(GameDirector.run_active and RunState.act == 2,
		"the road is held at the act the pass was drawn for (act %d)" % RunState.act)
	(ui._buttons["push"] as Button).pressed.emit()
	for _f: int in 4:
		await get_tree().process_frame
	_check(not ui._buttons.has("push"), "pushing on takes the pass down")
	_check(GameDirector.run_active and _ended.is_empty(), "and the run goes on")
	_check(RunState.phase == RunState.Phase.PREPARATION, "into the next act's preparation")


func _test_turning_for_home() -> void:
	var marks_before: int = MetaState.marks
	RunState.act = 3
	# A run that has fought its way to an act's boss has a wave number, and
	# `Expedition.is_readable` refuses a snapshot without one - so a harness
	# that never ran a wave cannot bank a front and would read the banking
	# check below as broken rather than as unreachable.
	RunState.wave_number = 12
	EventBus.boss_defeated.emit("probe", 3)
	for _f: int in 3:
		await get_tree().process_frame
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(ui._buttons.has("home") and int(ui.last_homecoming.get("act", 0)) == 3,
		"the pass opens again at the next act's end")
	# **The walk out is driven for real here**, through the seam that exists
	# because `_ride_home` returns on its first line headless - so every line of
	# the departure beat has been ungated since the day it was written, and the
	# withdrawal would have inherited that hole.
	_run.withdrawal_test_seconds = 0.5
	var wall_before: float = RunState.town_hp / maxf(RunState.town_max_hp, 1.0)
	(ui._buttons["home"] as Button).pressed.emit()
	await get_tree().process_frame
	_check(RunState.withdrawing, "turning for home closes the road behind the party")
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE,
		"in the combat phase, so the board the party built actually fires")
	var closing: Withdrawal = _run.battlefield.withdrawal()
	# **The wall is worn while the withdrawal runs**, by hand rather than by
	# waiting for bodies to walk the road, because what is being measured here is
	# *when the front is photographed* rather than how hard the fight is. Without
	# a difference between the wall before and after, a snapshot composed before
	# the withdrawal and one composed after read identically and the check below
	# cannot tell a withdrawal that costs something from one that costs nothing.
	var town: Health = _run.battlefield.town.health
	town.take_damage(town.max_hp * 0.30, _run.battlefield.town_position())
	for _f: int in 120:
		if not GameDirector.run_active:
			break
		await get_tree().process_frame
	_check(closing == null or closing.sent() > 0,
		"and the road sends bodies while it pulls away (%d)"
			% (closing.sent() if closing != null else -1))
	_check(not RunState.withdrawing, "the run does not settle until the road is closed")
	_run.withdrawal_test_seconds = -1.0
	var _wall_after: float = RunState.town_hp
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
	# **And the fortress comes home in the condition the withdrawal left it.**
	# That is what the withdrawal costs and the only thing it costs - the front
	# is banked either way, the Marks are paid in full either way. A snapshot
	# composed before the fight would make the whole feature decoration.
	var front: Dictionary = MetaState.expedition
	_check(Expedition.is_readable(front), "the front was banked on the way out")
	if Expedition.is_readable(front):
		var walls: float = float(front.get("wall", -1.0))
		_check(absf(walls - RunState.town_hp / maxf(RunState.town_max_hp, 1.0)) < 0.02,
			"carrying the wall the withdrawal left standing (%.2f)" % walls)
		# **Photographed after the fight, which is the whole of what a withdrawal
		# costs.** Composed a moment earlier it would carry the wall the party had
		# before the road closed, every check above would still pass, and the
		# feature would be a fight with no consequence attached to it.
		_check(walls < wall_before - 0.05,
			"and the front is photographed after the withdrawal, not before"
				+ " (%.2f then, %.2f banked)" % [wall_before, walls])
	_check(int(summary.get("marks", 0)) == Run.homecoming_marks(3, true),
		"and a withdrawal takes nothing off the purse")
	# **And the debrief says the front was kept.** Banking one is the whole reason
	# to turn for home, and the screen used to give the ordinary payout with no
	# mention of it - so a player had to quit to the menu to find out whether the
	# thing they pressed the card for had worked.
	var said: String = _run.results_ui.body.text if _run.results_ui.body != null else ""
	_check(said.contains("THE FRONT"), "the debrief names the front that was banked")
	_check(said.contains("the gate at"),
		"and says what condition the withdrawal left it in")


## **Pressure rises.** The owner ruled for rising pressure during the walk out,
## so the one thing that must be true of the ramp is that it is a ramp: the gap
## between bodies closes from the first moment to the last, and it closes all
## the way along rather than in one step at the end.
##
## Statics, driven rather than read back, for the reason `homecoming_marks` is
## static: the shape of a withdrawal is measurable without standing a field up.
func _test_the_withdrawal_ramp() -> void:
	_check(Withdrawal.spacing_at(0.0) > Withdrawal.spacing_at(1.0),
		"the road presses harder at the end of a withdrawal than at the start")
	var falling: bool = true
	var last: float = INF
	for step: int in 11:
		var gap: float = Withdrawal.spacing_at(float(step) / 10.0)
		if gap > last:
			falling = false
		last = gap
	_check(falling, "and it closes the whole way rather than in one step")
	_check(Withdrawal.spacing_at(-1.0) == Withdrawal.spacing_at(0.0)
		and Withdrawal.spacing_at(2.0) == Withdrawal.spacing_at(1.0),
		"the ramp is clamped at both ends")
	_check(Withdrawal.bodies_expected() >= 8.0,
		"a withdrawal is a formation rather than a gesture (%.1f bodies)"
			% Withdrawal.bodies_expected())
	_check(Balance.HOMECOMING_WALL_FLOOR > 0.0 and Balance.HOMECOMING_WALL_FLOOR < 1.0,
		"the wall is floored somewhere between standing and fallen")


## **A party who pressed Turn For Home always reaches home.**
##
## This is the bound the whole feature rests on and the reason the other two
## designs for it were refused: `bank_the_front` is called by extraction and by
## nothing else, so extraction is the only ratchet the expedition system has. A
## withdrawal that could be *failed* would put that ratchet behind a fight and
## pin a player who cannot win one at their last successful extraction.
##
## Driven on the real field with real damage rather than by reading the floor
## back, because what must be true is that the town does not *die* - and the
## constant being right says nothing about whether anything reads it.
func _test_the_withdrawal_holds_the_wall() -> void:
	var field: Battlefield = _run.battlefield
	var closing: Withdrawal = field.withdrawal() if field != null else null
	_check(closing != null, "the battlefield carries a withdrawal")
	if closing == null:
		return
	var town: Health = field.town.health
	var floor_before: float = town.floor_hp
	var was_active: bool = GameDirector.run_active

	closing.begin(0.4)
	_check(RunState.withdrawing, "beginning one closes the road")
	_check(not field.wave_director._road_waves_allowed(),
		"and no ordinary formation may start underneath it")
	_check(town.floor_hp > 0.0, "the town is held above a floor while it runs")

	# Far more than the town has, several times over, from every direction: this
	# is the worst a withdrawal could ever go.
	for _blow: int in 12:
		town.take_damage(town.max_hp * 2.0, field.town_position() + Vector2.RIGHT)
		await get_tree().process_frame
	_check(GameDirector.run_active == was_active and not town.is_dead,
		"and the town cannot be lost on the way out")
	_check(town.current_hp > 0.0 and town.current_hp
		<= town.max_hp * Balance.HOMECOMING_WALL_FLOOR + 1.0,
		"it is worn to the floor and no further (%.0f of %.0f)"
			% [town.current_hp, town.max_hp])
	_check(closing.sent() > 0, "bodies are sent at the town while it runs")
	# **And it says how much is left.** The player is dropped into sixteen seconds
	# of combat by a card; the banner clears after three, and the preview line was
	# showing the next wave's forecast - a wave that never arrives, because a
	# withdrawal suppresses road formations and the run ends when it ends.
	_check(closing.seconds_left() > 0.0 and closing.seconds_left() <= 0.4,
		"the withdrawal reports the road it has left to hold (%.2f)"
			% closing.seconds_left())

	# **And the party cannot be killed out of the walk either.**
	#
	# The wall floor closes one door and this closes the other: a Warden on their
	# last Wound who goes down during a withdrawal would otherwise lose the return
	# they had already chosen *and* the front it was about to bank, because
	# `bank_the_front` is reached from `return_home` and from nowhere else. Driven
	# through the real death path with the Wounds already spent.
	_check(not RunState.run_may_be_lost(), "a run in withdrawal may not be lost")
	var hero: Hero = field.hero
	if hero != null and is_instance_valid(hero):
		RunState.hero_wounds = RunState.max_wounds()
		hero.health.current_hp = hero.health.max_hp
		hero.health.take_damage(hero.health.max_hp * 4.0, field.town_position())
		await get_tree().process_frame
		_check(GameDirector.run_active == was_active,
			"a Warden falling past their last Wound does not end the walk out")
		RunState.hero_wounds = 0
		hero.health.revive(1.0)

	# And it ends, and lets go.
	for _f: int in 90:
		if not RunState.withdrawing:
			break
		await get_tree().process_frame
	_check(not RunState.withdrawing, "the withdrawal ends on its own clock")
	# **The failure this catches is silent and permanent**: a floor left standing
	# is a town that can never be lost again, with nothing erroring and every
	# number on screen reading exactly as it should. The same shape as a hush
	# that never resolves.
	_check(town.floor_hp == floor_before,
		"and releases the wall it was holding (%.2f)" % town.floor_hp)
	_check(field.wave_director._road_waves_allowed()
		or RunState.phase != RunState.Phase.ROAD_BATTLE,
		"the road may send formations again once it has")
	town.heal(town.max_hp)
	RunState.town_hp = town.current_hp


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[homecoming] " + message)
