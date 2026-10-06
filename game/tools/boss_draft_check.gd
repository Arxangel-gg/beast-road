extends Node

## The draft an act boss banks never strands the road (owner report, 2026-10-06:
## "Defeating an act boss offers augments but does not pause on the augment
## selection and will go to act crossroads and prevent continuing to next act
## if the augment was not selected in time getting stuck and needing a game
## restart").
##
##   godot --headless --path game res://tools/boss_draft_check.tscn
##
## The crossroad screen is one panel worn by the portent choice, the augment
## draft, the fork and the road-card draft in turn, and every door onto it
## rebuilds the same option box. What this holds is that whichever order a
## boss's fall lays them in, the road comes out the other side *unlocked and
## unfrozen* with the draft still reachable:
##
## - At once off: the boss falls, the portent is read, the banked draft opens
##   in the untimed Preparation, a card is taken, and Ride On starts the next
##   act's first wave on a field that is not suspended.
## - At once on: the draft opens the moment the boss falls and freezes the
##   field; the boss card and the portent are then laid over it. The portent
##   read, the draft must come back, and taking it must *release the field* -
##   a field left suspended under an open road is the restart the owner met.
## - A fork over a draft: a draft opened mid-fight by the road-rank strip
##   (field frozen) is stomped by a crossroad. Choosing the road and its card
##   must leave the field running and the draft banked for the next breather.
## - Escape over any of it closes one layer and never the fork.

const SEED: int = 20261006

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

	await _test_at_once_off()
	await _test_at_once_on()
	await _test_pass_over_a_draft()
	await _test_fork_over_a_draft()

	MetaState.settings.erase(UserSettings.AUGMENT_AT_ONCE_KEY)
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
		push_error("[boss-draft] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print(("[boss-draft] PASS - %d checks: the boss draft at once off and on,"
		+ " a fork over a draft, the field released every time") % _checked)
	get_tree().quit(0)


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failures += 1
		push_error("[boss-draft] FAIL: " + what)


func _frames(count: int) -> void:
	for _f: int in count:
		await get_tree().process_frame


func _state() -> String:
	var ui: CrossroadScreen = _run.crossroad_ui
	return "open=%s augment=%s suspended=%s locked=%s phase=%d waiting=%d omens=%d" % [
		ui.is_open(), ui.is_augment_open(), _run.battlefield.is_suspended(),
		_run._locked, RunState.phase, RunState.augments_waiting(),
		RunState.pending_omens.size()]


## The road as a player left it: nothing open, nothing frozen, nothing locked.
func _road_is_free(where: String) -> void:
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(not ui.is_open(), "%s: the panel is down (%s)" % [where, _state()])
	_check(not _run.battlefield.is_suspended(), "%s: the field is not suspended (%s)" % [where, _state()])
	_check(not _run._locked, "%s: the run is not locked (%s)" % [where, _state()])


## Reads the one portent on the table and waits for the screen to settle.
func _read_a_portent(where: String) -> void:
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(not RunState.pending_omens.is_empty() and ui.is_open(),
		"%s: the portent is offered after the boss (%s)" % [where, _state()])
	if RunState.pending_omens.is_empty():
		return
	ui._choose_omen(RunState.pending_omens[0])
	await _frames(4)


## Takes the first card of the open draft; a hand of nothing never needs a drop.
func _take_the_draft(where: String) -> void:
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(ui.is_augment_open() and not RunState.augment_offer.is_empty(),
		"%s: the banked draft is on the table (%s)" % [where, _state()])
	if RunState.augment_offer.is_empty():
		return
	ui._choose_augment(RunState.augment_offer[0])
	await _frames(4)


func _ride_on() -> void:
	# The coverage warning wants a second press; a harness board covers nothing.
	_run._on_ride_on_requested()
	await _frames(2)
	if RunState.is_preparation():
		_run._on_ride_on_requested()
	await _frames(4)


func _fresh_road(act: int, at_once: bool) -> void:
	MetaState.settings[UserSettings.AUGMENT_AT_ONCE_KEY] = at_once
	RunState.augment_queue.clear()
	RunState.augment_offer.clear()
	RunState.pending_omens.clear()
	RunState.pending_road_cards.clear()
	RunState.act = act
	RunState.wave_number = 12
	# A boss falls in the BOSS phase, which is the command combat the at-once
	# door asks for; the field runs and nothing is locked, as in play.
	_run.battlefield.resume()
	_run._locked = false
	RunState.set_phase(RunState.Phase.BOSS)
	await _frames(2)


func _test_at_once_off() -> void:
	await _fresh_road(2, false)
	EventBus.boss_defeated.emit("probe", 2)
	await _frames(4)
	_check(RunState.augments_waiting() == 1, "the boss banks one draft (%s)" % _state())
	await _read_a_portent("off")
	_check(RunState.is_preparation(), "off: the next act opens in Preparation (%s)" % _state())
	# The banked draft opens once the portent is read and the grace has passed.
	await _frames(6)
	await _take_the_draft("off")
	_road_is_free("off, draft taken")
	_check(RunState.augments_waiting() == 0, "off: the draft is spent (%s)" % _state())
	await _ride_on()
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE,
		"off: Ride On starts the next act's road (%s)" % _state())
	_road_is_free("off, riding")
	_check(_run.journey._running, "off: the beast walks")
	_check(_ended.is_empty() and GameDirector.run_active, "off: the run goes on")


func _test_at_once_on() -> void:
	await _fresh_road(3, true)
	# **The card is held for a moment, as it is in play**: that is the window
	# the at-once door opens the draft in, on a deferred call inside the frame
	# the boss fell, and freezes the field for it.
	_run.fallen_card_test_seconds = 0.6
	EventBus.boss_defeated.emit("probe", 3)
	await get_tree().create_timer(0.2).timeout
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(ui.is_augment_open() and _run.battlefield.is_suspended(),
		"on: the draft opens under the card and holds the field (%s)" % _state())
	await get_tree().create_timer(0.6).timeout
	_run.fallen_card_test_seconds = 0.0
	# The card gone, the portent is laid over the draft. Read it.
	await _read_a_portent("on")
	await _frames(6)
	# **The draft must come back, and the field must be released by taking it.**
	await _take_the_draft("on")
	_road_is_free("on, draft taken")
	await _ride_on()
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE,
		"on: Ride On starts the next act's road (%s)" % _state())
	_road_is_free("on, riding")
	_check(_run.journey._running, "on: the beast walks")
	_check(_ended.is_empty() and GameDirector.run_active, "on: the run goes on")


## The pass home is the other card laid over an at-once draft at an act's end,
## and the one with a clock a player can let run out.
func _test_pass_over_a_draft() -> void:
	await _fresh_road(maxi(Balance.HOMECOMING_FROM_ACT, 2), true)
	_run.ask_homecoming = true
	_run.fallen_card_test_seconds = 0.4
	EventBus.boss_defeated.emit("probe", RunState.act)
	await get_tree().create_timer(0.2).timeout
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(ui.is_augment_open() and _run.battlefield.is_suspended(),
		"pass: the draft opens under the card and holds the field (%s)" % _state())
	await get_tree().create_timer(0.5).timeout
	_run.fallen_card_test_seconds = 0.0
	_check(ui._buttons.has("push") and ui._buttons.has("home"),
		"pass: the pass home is laid over the draft (%s)" % _state())
	if ui._buttons.has("push"):
		(ui._buttons["push"] as Button).pressed.emit()
	await _frames(4)
	_run.ask_homecoming = false
	await _read_a_portent("pass")
	await _frames(6)
	await _take_the_draft("pass")
	_road_is_free("pass, draft taken")
	await _ride_on()
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE,
		"pass: Ride On starts the next act's road (%s)" % _state())
	_road_is_free("pass, riding")
	_check(_ended.is_empty() and GameDirector.run_active, "pass: the run goes on")


func _test_fork_over_a_draft() -> void:
	await _fresh_road(4, true)
	# Mid-fight on the road, a draft banked by a rank and opened by the strip:
	# the field freezes for it, the way At once freezes it.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.journey.start()
	RunState.queue_augment(Augments.SOURCE_RANK)
	await _frames(2)
	_run._on_augment_open_requested()
	await _frames(3)
	var ui: CrossroadScreen = _run.crossroad_ui
	_check(ui.is_augment_open() and _run.battlefield.is_suspended(),
		"fork: the strip opens the draft and holds the road (%s)" % _state())
	# Escape closes the draft as Later and gives the road back.
	_check(_run.escape(false), "fork: Escape closes the draft")
	await _frames(3)
	_road_is_free("fork, draft put off")
	_check(RunState.augments_waiting() == 1, "fork: the put-off draft stays banked (%s)" % _state())
	# Open it again and let a crossroad arrive over it, as one does on a walked
	# road: the fork takes the table.
	_run._on_augment_open_requested()
	await _frames(3)
	_check(ui.is_augment_open(), "fork: the draft is open again (%s)" % _state())
	EventBus.crossroad_reached.emit(3)
	await _frames(4)
	_check(ui.is_open() and not ui.is_augment_open() and _run._locked,
		"fork: the crossroad takes the table from the draft (%s)" % _state())
	_check(not _run.escape(false) or ui.is_open(),
		"fork: Escape never closes the fork (%s)" % _state())
	var offer: PackedStringArray = ui.first_offer()
	_check(offer.size() == 2, "fork: a road is on the table")
	if offer.size() == 2:
		ui._choose(offer[0], offer[1])
	await _frames(4)
	if not RunState.pending_road_cards.is_empty():
		ui._choose_road_card(RunState.pending_road_cards[0])
		await _frames(4)
	_check(RunState.is_preparation() and not _run._locked,
		"fork: the road chosen, the run is unlocked in Preparation (%s)" % _state())
	# The banked draft comes back in that Preparation, and taking it frees the field.
	await _frames(6)
	await _take_the_draft("fork")
	_road_is_free("fork, draft taken")
	await _ride_on()
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE, "fork: the road rides on (%s)" % _state())
	_road_is_free("fork, riding")
	_check(_ended.is_empty() and GameDirector.run_active, "fork: the run goes on")
