extends Node

## **Escape closes the topmost thing first** (owner, 2026-10-01):
##
##   godot --headless --path game res://tools/escape_check.tscn
##
## *"Pressing Esc again while on the pause screen should close the pause menu.
## Pressing Esc while any menu is open should close the highest layer menu first
## each time it's pressed and if there's nothing open then it can go to the
## pause menu. The town and beast scopes can also be returned to the battlefield
## scope with Esc at the last zoom the screen was at before entering either of
## the scopes."*
##
## Every press here is a real Escape key pushed through the viewport, so what is
## held is the whole route - the run's `_unhandled_input`, its `escape`, and the
## pause menu answering while the tree is paused - and never a function called
## behind the router's back.
##
## **The ways this goes wrong:** a second Escape that reaches nobody because the
## run is paused with the tree; a sheet that pauses the game instead of closing;
## one press closing two things; the Town or Yuri left at the band's end rather
## than where the fight was framed; a decision - a fork - closed by a key; and a
## pad's B pausing the game.

const SEED: int = 20261001

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run
var _hud: HUD
var _field: Battlefield


func _ready() -> void:
	# The tree is paused under half of these; the harness must keep counting.
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaState.hold_saves()
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	_hud = _run.hud
	_field = _run.battlefield
	_field.wave_director.stop()
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(9999)
	for _f: int in 4:
		await get_tree().process_frame

	await _test_pause_opens_and_a_second_press_closes_it()
	await _test_settings_close_before_the_menu()
	await _test_sheets_close_before_the_pause()
	await _test_the_town_steps_back_to_the_field()
	await _test_yuri_steps_back_to_the_field()
	await _test_the_draft_closes_layer_by_layer()
	await _test_a_fork_is_not_closed()
	await _test_a_wayside_card_walks_on()
	await _test_back_never_pauses()

	var expected: int = 9
	_check(_finished == expected, "%d of %d tests reached their end" % [_finished, expected])
	if get_tree().paused:
		GameDirector.set_paused(false)
	_run.queue_free()
	for _f: int in 6:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print(("[escape] PASS - %d checks: a second Escape closes the pause menu, the "
			+ "settings close first, a sheet closes before anything pauses, the Town "
			+ "and Yuri step back to the zoom the fight had, the draft closes a layer "
			+ "a press, a fork is never closed, and back never pauses") % _checks)
	else:
		push_error("[escape] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


# --- Helpers ----------------------------------------------------------------


## One Escape, as the keyboard sends it, through the viewport.
func _escape() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_ESCAPE
	down.physical_keycode = KEY_ESCAPE
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)
	for _f: int in 3:
		await get_tree().process_frame


## "Back" alone, as a pad's B sends it.
func _back() -> void:
	var down := InputEventAction.new()
	down.action = &"ui_cancel"
	down.pressed = true
	get_viewport().push_input(down)
	var up := InputEventAction.new()
	up.action = &"ui_cancel"
	up.pressed = false
	get_viewport().push_input(up)
	for _f: int in 3:
		await get_tree().process_frame


func _paused() -> bool:
	return get_tree().paused


func _pause_open() -> bool:
	return _run.pause_ui.is_open()


func _sheet(name: String) -> Control:
	return _hud.get(name) as Control


func _road_tile() -> Vector2i:
	for radius: int in range(2, 40):
		for angle: int in range(0, 360, 15):
			var at := Vector2i(int(cos(deg_to_rad(angle)) * float(radius)),
				int(sin(deg_to_rad(angle)) * float(radius)))
			if _field.grid.cell_at(at) != BattleGrid.Cell.ROAD:
				continue
			if RunState.traps.has(at) or RunState.barricade_at(at) != null:
				continue
			return at
	_check(false, "the harness needs an empty road tile")
	return Vector2i.ZERO


func _rig() -> CameraRig:
	return _field.camera as CameraRig


# --- Tests ------------------------------------------------------------------


func _test_pause_opens_and_a_second_press_closes_it() -> void:
	_check(not _paused() and not _pause_open(), "the harness began paused")
	await _escape()
	_check(_pause_open() and _paused(), "Escape with nothing open did not open the pause menu")
	await _escape()
	_check(not _pause_open(), "a second Escape on the pause screen did not close it")
	_check(not _paused(), "the pause menu closed and left the tree paused")
	_finished += 1


func _test_settings_close_before_the_menu() -> void:
	await _escape()
	_check(_pause_open(), "Escape did not open the pause menu for the settings test")
	var settings: Control = _run.pause_ui.get("_settings") as Control
	_run.pause_ui.call("_show_settings", true)
	await get_tree().process_frame
	_check(settings != null and settings.visible, "the settings did not open")
	await _escape()
	_check(settings != null and not settings.visible,
		"Escape in the settings did not close them")
	_check(_run.pause_ui.panel.visible and _paused(),
		"closing the settings also closed the pause menu - one press closed two things")
	await _escape()
	_check(not _pause_open() and not _paused(),
		"the Escape after the settings did not close the pause menu")
	_finished += 1


func _test_sheets_close_before_the_pause() -> void:
	_hud.call("_open_build_panel", _field.free_anchor_near(0))
	await get_tree().process_frame
	var build: Control = _sheet("_build_panel")
	_check(build != null and build.visible, "the build sheet did not open")
	await _escape()
	_check(build != null and not build.visible, "Escape did not close the build sheet")
	_check(not _pause_open() and not _paused(),
		"Escape over the build sheet paused the game as well")

	_hud.call("_open_road_panel", _road_tile())
	await get_tree().process_frame
	var road: Control = _sheet("_road_panel")
	_check(road != null and road.visible, "the road sheet did not open")
	await _escape()
	_check(road != null and not road.visible, "Escape did not close the road sheet")
	_check(not _pause_open(), "Escape over the road sheet paused the game as well")
	await _escape()
	_check(_pause_open(), "with every sheet closed, Escape did not pause")
	await _escape()
	_check(not _pause_open() and not _paused(), "the pause menu did not close again")
	_finished += 1


func _test_the_town_steps_back_to_the_field() -> void:
	var rig: CameraRig = _rig()
	_check(rig != null, "the battlefield has no camera rig")
	if rig == null:
		_finished += 1
		return
	rig.set_zoom_share(0.3)
	var framed: float = rig.zoom_share()
	_run.switch_scope(GameDirector.Scope.TOWN)
	await get_tree().process_frame
	# Moved while away, as the wheel's return does: what is held is that Escape
	# puts it back, not that nothing touched it.
	rig.reset_to_close()
	var building: String = ""
	for id: Variant in ContentDB.buildings:
		building = String(id)
		break
	_run.town_panel.open(building)
	await get_tree().process_frame
	_check(_run.town_panel.is_open(), "the Town's sheet did not open for %s" % building)
	await _escape()
	_check(not _run.town_panel.is_open(), "Escape did not close the Town's sheet")
	_check(GameDirector.current_scope == GameDirector.Scope.TOWN,
		"closing the Town's sheet also left the Town - one press closed two things")
	await _escape()
	_check(GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD,
		"Escape in the Town did not step back to the battlefield")
	_check(absf(rig.zoom_share() - framed) < 0.01,
		"back from the Town at zoom share %.2f, not the %.2f the field was framed at"
		% [rig.zoom_share(), framed])
	_check(not _pause_open(), "stepping back from the Town paused the game as well")
	_finished += 1


func _test_yuri_steps_back_to_the_field() -> void:
	var rig: CameraRig = _rig()
	if rig == null:
		_finished += 1
		return
	rig.set_zoom_share(0.8)
	var framed: float = rig.zoom_share()
	_run.switch_scope(GameDirector.Scope.BEAST)
	await get_tree().process_frame
	rig.reset_to_wide()
	await _escape()
	_check(GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD,
		"Escape on Yuri did not step back to the battlefield")
	_check(absf(rig.zoom_share() - framed) < 0.01,
		"back from Yuri at zoom share %.2f, not the %.2f the field was framed at"
		% [rig.zoom_share(), framed])
	_check(not _pause_open(), "stepping back from Yuri paused the game as well")
	_finished += 1


func _test_the_draft_closes_layer_by_layer() -> void:
	var screen: CrossroadScreen = _run.crossroad_ui
	RunState.augment_queue = []
	RunState.augment_offer = []
	RunState.augment_banishes = 2
	RunState.queue_augment(Augments.SOURCE_RANK)
	_check(screen.open_augment_draft(), "the draft did not open")
	for _f: int in 4:
		await get_tree().process_frame
	var offer: Array[String] = RunState.augment_offer.duplicate()
	var card: RoadCardData = ContentDB.road_card(offer[0]) if not offer.is_empty() else null
	_check(card != null, "the draft dealt nothing")
	if card == null:
		_finished += 1
		return

	# The leave-one-behind table goes back to the cards.
	screen.call("_open_drop_choice", card)
	await get_tree().process_frame
	await _escape()
	_check(screen.is_augment_open(), "Escape on the leave-one-behind table closed the draft")
	var keep: Variant = screen.get("_keep_hand_button")
	_check(not is_instance_valid(keep) or (keep as Button).is_queued_for_deletion()
		or not (keep as Button).is_inside_tree(),
		"Escape on the leave-one-behind table did not go back to the cards")
	_check(RunState.augment_offer == offer, "going back from the table changed the offer")
	_check(not _pause_open(), "Escape on the table paused the game as well")

	# An armed Banish is disarmed before the draft is put off.
	screen.call("_arm_banish")
	await get_tree().process_frame
	_check(bool(screen.get("_banishing")), "the harness could not arm Banish")
	await _escape()
	_check(not bool(screen.get("_banishing")), "Escape did not disarm Banish")
	_check(screen.is_augment_open(), "disarming Banish also closed the draft")

	# And then the draft itself is put off - Later, still banked.
	var waiting: int = RunState.augments_waiting()
	await _escape()
	_check(not screen.is_augment_open(), "Escape did not put the draft off")
	_check(RunState.augments_waiting() == waiting,
		"putting the draft off by Escape changed what was banked (%d to %d)"
		% [waiting, RunState.augments_waiting()])
	_check(not _pause_open(), "putting the draft off paused the game as well")
	RunState.augment_queue = []
	RunState.augment_offer = []
	_finished += 1


func _test_a_fork_is_not_closed() -> void:
	var screen: CrossroadScreen = _run.crossroad_ui
	screen.open(1)
	for _f: int in 3:
		await get_tree().process_frame
	_check(screen.is_open(), "the fork did not open")
	_check(not screen.close_top_layer(), "a fork's choice of road was closed as a menu")
	await _escape()
	_check(screen.is_open(), "Escape closed a fork - a decision the road is waiting on")
	_check(_pause_open(), "Escape over a fork did not pause")
	await _escape()
	_check(not _pause_open(), "the pause menu over a fork did not close again")
	screen.panel.visible = false
	_finished += 1


func _test_a_wayside_card_walks_on() -> void:
	var encounter: String = ""
	for id: Variant in ContentDB.wayside_encounters:
		encounter = String(id)
		break
	_run.call("_on_wayside_reached", encounter, "")
	await get_tree().process_frame
	var card: WaysideCard = _run.wayside_card()
	_check(card != null and card.visible, "the wayside card did not open for %s" % encounter)
	await _escape()
	_check(card != null and not card.visible, "Escape did not walk on from a wayside card")
	_check(not _field.is_suspended(), "walking on by Escape left the field frozen")
	_check(not _pause_open(), "walking on by Escape paused the game as well")
	_finished += 1


func _test_back_never_pauses() -> void:
	await _back()
	_check(not _pause_open() and not _paused(), "a pad's back paused the game")
	_hud.call("_open_build_panel", _field.free_anchor_near(0))
	await get_tree().process_frame
	await _back()
	_check(not (_sheet("_build_panel")).visible, "a pad's back did not close the build sheet")
	_run.switch_scope(GameDirector.Scope.TOWN)
	await get_tree().process_frame
	await _back()
	_check(GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD,
		"a pad's back did not step out of the Town")
	_check(not _pause_open(), "a pad's back paused the game on the way out of the Town")
	_finished += 1


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[escape] " + message)
