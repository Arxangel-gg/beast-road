extends Node

## Proves the on-screen controls turn thumbs into the same input a keyboard makes.
##
##   godot --headless --path game res://tools/touch_check.tscn
##
## This exists because the thing it checks cannot be checked by hand here: the
## controls only appear on a touchscreen, and the machine this is developed on
## does not have one. Everything below drives synthetic `InputEventScreenTouch`
## and `InputEventScreenDrag` through the real autoload and reads the real input
## map afterwards, so a regression shows up on a push rather than on a phone.
##
## What it does *not* prove is that the sticks feel right under a thumb. Nothing
## headless can, and `docs/ROAD_TO_RELEASE.md` says so.

var _failures: int = 0


func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	# Forced on: this machine has no touchscreen, and the point is to exercise
	# the controls rather than the decision about whether to show them.
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	# The controls belong to a run. They drive the hero, so outside a run they are
	# hidden *and* deaf on purpose - that is what keeps the dash button from
	# sitting on the main menu eating taps. This harness has no run, so it says it
	# has one; `touch_shot.gd` does the same for the same reason.
	GameDirector.run_active = true
	TouchInput.refresh()
	await get_tree().process_frame

	_check(TouchInput.is_showing(), "the setting must be able to force the controls on")
	var landscape_factor: float = ScreenFit.factor_for(Vector2(1215.0, 541.0),
		ScreenFit.base_size(), true)
	_check(landscape_factor > 1.0,
		"a landscape phone must receive readable scaling, got %.2f" % landscape_factor)
	GameDirector.current_scope = GameDirector.Scope.TOWN
	_settle()
	_check(not TouchInput.visible, "combat controls must be hidden in the Town scope")
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_settle()
	_check(TouchInput.visible, "combat controls must return on the Battlefield")

	# Asked for, not recomputed. A first version worked out the zones itself from
	# the same fractions the autoload uses, which meant it was checking a copy of
	# the layout — and it happily put the right thumb inside the dash button,
	# where the failure looked like "the aim stick is broken".
	var span: Vector2 = get_viewport().get_visible_rect().size
	var left_thumb: Vector2 = TouchInput.zone(false).get_center()
	var right_thumb: Vector2 = TouchInput.zone(true).get_center()
	_check(not TouchInput.dash_rect().has_point(right_thumb),
		"the dash button must not sit where an aiming thumb rests")

	# --- the left stick becomes movement -----------------------------------
	_touch(left_thumb, true, 0)
	_drag(left_thumb + Vector2(-Balance.TOUCH_STICK_REACH, 0.0), 0)
	_settle()
	_check(Input.is_action_pressed(&"move_left"), "a thumb pushed left must press move_left")
	_check(not Input.is_action_pressed(&"move_right"), "and must not press its opposite")
	_check(is_equal_approx(Input.get_action_strength(&"move_left"), 1.0),
		"a full push must be full strength, not a digital press")

	# Half a push is half a walk. This is the property a keyboard cannot express
	# and the reason movement is fed as strength rather than as a boolean.
	_drag(left_thumb + Vector2(-Balance.TOUCH_STICK_REACH * 0.5, 0.0), 0)
	_settle()
	var half: float = Input.get_action_strength(&"move_left")
	_check(half > 0.35 and half < 0.65, "half a push must be about half strength, got %.2f" % half)

	# --- the right stick becomes aim, and past a threshold, an attack -------
	_touch(right_thumb, true, 1)
	_drag(right_thumb + Vector2(0.0, -Balance.TOUCH_STICK_REACH), 1)
	_settle()
	_check(TouchInput.aim().is_equal_approx(Vector2.UP),
		"a thumb pushed up on the right must aim up, got %s" % str(TouchInput.aim()))
	_check(Input.is_action_pressed(&"attack"), "a full push on the right must attack")
	var local_input := LocalHeroInput.new()
	_check(local_input.held(HeroInput.HOLD_ATTACK),
		"a held attack stick must reach the local hero as HOLD_ATTACK")
	var held_snapshot: Array = local_input.snapshot(TouchInput.aim())
	var remote_input := RemoteHeroInput.new()
	remote_input.apply(held_snapshot)
	_check(remote_input.held(HeroInput.HOLD_ATTACK),
		"touch auto-attack must cross the co-op input snapshot as a hold")

	# Aiming without committing has to be possible, or a shot cannot be lined up.
	_drag(right_thumb + Vector2(0.0, -Balance.TOUCH_STICK_REACH * 0.2), 1)
	_settle()
	_check(not Input.is_action_pressed(&"attack"),
		"a gentle push must aim without attacking")

	# --- two thumbs at once, which is the whole point ----------------------
	_drag(left_thumb + Vector2(0.0, Balance.TOUCH_STICK_REACH), 0)
	_drag(right_thumb + Vector2(Balance.TOUCH_STICK_REACH, 0.0), 1)
	_settle()
	_check(Input.is_action_pressed(&"move_down") and TouchInput.aim().is_equal_approx(Vector2.RIGHT),
		"both sticks must work at once; drags interleave by finger index")

	# --- releasing one finger must not disturb the other -------------------
	_touch(right_thumb, false, 1)
	_settle()
	_check(Input.is_action_pressed(&"move_down"),
		"letting go of the right stick must not release the left")
	_check(not Input.is_action_pressed(&"attack"),
		"letting go of the right stick must stop attacking")

	_touch(left_thumb, false, 0)
	_settle()
	_check(not Input.is_action_pressed(&"move_down"), "letting go must stop the walk")

	# --- a touch nobody's stick owns is left alone -------------------------
	# Placing a tower is a tap in the middle of the field. If a stick claimed it,
	# the game would be unplayable in exactly the phase it is most needed.
	var middle := Vector2(span.x * 0.5, span.y * 0.25)
	_touch(middle, true, 3)
	_settle()
	_check(TouchInput.move() == Vector2.ZERO,
		"a tap outside both corners must not be claimed by a stick")
	_touch(middle, false, 3)

	# --- the emulated pointer belongs to whoever holds finger 0 ------------
	# Godot emulates a mouse from touch, and only from finger 0. Placement asks
	# `owns_pointer()` before acting, so this is the property that stops a walking
	# thumb from building towers.
	_touch(left_thumb, true, 0)
	_settle()
	_check(TouchInput.owns_pointer(),
		"a thumb on the movement stick must own the emulated pointer")
	_touch(left_thumb, false, 0)
	_settle()
	_check(not TouchInput.owns_pointer(), "letting go must hand the pointer back")

	# A second finger emulates nothing, so it must never claim the pointer and
	# block a legitimate tap.
	_touch(right_thumb, true, 1)
	_settle()
	_check(not TouchInput.owns_pointer(),
		"only finger 0 is emulated, so no other finger may claim the pointer")
	_touch(right_thumb, false, 1)
	_settle()

	# --- hiding the controls must not leave an action held -----------------
	_touch(left_thumb, true, 0)
	_drag(left_thumb + Vector2(Balance.TOUCH_STICK_REACH, 0.0), 0)
	_settle()
	_check(Input.is_action_pressed(&"move_right"), "sanity: the walk is on")
	MetaState.settings[TouchInput.TOUCH_KEY] = false
	TouchInput.refresh()
	_settle()
	_check(not Input.is_action_pressed(&"move_right"),
		"hiding the controls must release what they were holding, or the hero walks forever")

	_test_revive_hold()
	_test_dash_clears_the_rail()
	_test_build_mode_frees_the_screen()
	await _test_a_tap_is_a_tap_wherever_it_lands()

	if _failures == 0:
		print("[touch] PASS - thumbs reach the input map, both sticks work at once, "
			+ "held attack replicates, the revive hold reaches the hero, nothing leaks")
	get_tree().quit(_failures)


## A thumb must be able to pick a partner up.
##
## There is no `revive` action a thumb can reach - the hold is read straight from
## `Input.is_action_pressed("revive")` - so on a phone this was always false and
## a fallen partner stayed down for the rest of the run. In a two-player game
## that is the end of the run.
func _test_revive_hold() -> void:
	# The leak test above ends the run to prove the controls go deaf, which is
	# exactly what it should check - and leaves them deaf for anything after it.
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	GameDirector.run_active = true
	TouchInput.refresh()
	_settle()
	_check(not TouchInput.revive_held(), "nothing is held before anybody falls")
	# The button only exists while somebody is down, which is what the hero
	# system announces when it happens.
	EventBus.coop_hero_down.emit(2, Vector2.ZERO)
	_settle()
	var spot: Rect2 = TouchInput.revive_rect()
	_check(spot.size.x > 0.0, "a downed partner must put a revive button on screen")
	_touch(spot.get_center(), true, 4)
	_settle()
	_check(TouchInput.revive_held(), "a thumb on it must read as held")
	_check(LocalHeroInput.new().held(HeroInput.HOLD_REVIVE),
		"and must reach the hero as HOLD_REVIVE")
	_touch(spot.get_center(), false, 4)
	_settle()
	_check(not TouchInput.revive_held(), "lifting the thumb must let go")
	EventBus.coop_hero_revived.emit(2, Vector2.ZERO)
	_settle()
	_check(TouchInput.revive_rect().size.x > 0.0 == false
			or not TouchInput._revive.visible,
		"and the button goes away once they are up")


## The dash must not sit under the scope rail.
##
## A button drawn beneath a HUD panel is not merely hidden - the sticks read
## `_unhandled_input`, so the panel eats the tap and the dash silently stops
## working. The rail moved to the right edge after the dash was put there.
func _test_dash_clears_the_rail() -> void:
	# **Amended 2026-09-25.** This held the dash against a rail one square wide,
	# which is the assumption that put it on the second column of a wrapped rail
	# on a landscape phone (owner's screenshots). What it has to hold is that
	# the dash never shares a pixel with the rail *as drawn*; the one-square
	# rail stands in only when no HUD has drawn one.
	var nav: Rect2 = HUD.live_nav_rect()
	if nav.has_area():
		for spot: Rect2 in [TouchInput.dash_rect(), TouchInput.revive_rect(),
				TouchInput.loose_rect(), TouchInput.ammo_rect(),
				TouchInput.cast_rect(), TouchInput.use_rect()]:
			_check(not spot.intersects(nav),
				"a thumb button at %s sits on the scope rail at %s" % [spot, nav])
		return
	var span: Vector2 = get_viewport().get_visible_rect().size
	var rail: float = span.x - HUD.one_nav_column()
	_check(TouchInput.dash_rect().end.x <= rail + 1.0,
		"dash right edge %.0f must clear the scope rail at %.0f"
			% [TouchInput.dash_rect().end.x, rail])


func _touch(at: Vector2, pressed: bool, finger: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	event.index = finger
	TouchInput._unhandled_input(event)


func _drag(to: Vector2, finger: int) -> void:
	var event := InputEventScreenDrag.new()
	event.position = to
	event.index = finger
	TouchInput._unhandled_input(event)


## A finger coming off the glass, the way the engine delivers it: `_input`
## first - which lets go of whatever held the finger - then `_unhandled_input`.
func _lift(at: Vector2, finger: int) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = false
	event.index = finger
	TouchInput._input(event)
	TouchInput._unhandled_input(event)


## **A tap is a tap wherever it lands** (owner, 2026-09-25: "Too often i'll be in
## build mode and try tapping on a ground tile to place a tower or trap and the
## menus wont open!"). The measurement below records why: the stick zones own
## most of the lower screen, and a finger a stick holds never reached the field.
## A quick, still press is handed back as `field_tapped`; a drag stays a stick.
##
## TouchInput's half only. `road_sheet_check` drives the same tap through a real
## battlefield and insists the build sheet opens.
func _test_a_tap_is_a_tap_wherever_it_lands() -> void:
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	TouchInput.refresh()
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_settle()
	var heard: Array[Vector2] = []
	var listen := func(at: Vector2) -> void: heard.append(at)
	TouchInput.field_tapped.connect(listen)
	var left: Vector2 = TouchInput.zone(false).get_center()
	var right: Vector2 = TouchInput.zone(true).get_center()

	_touch(left, true, 0)
	_lift(left, 0)
	_check(heard.size() == 1 and heard[0].is_equal_approx(left),
		"a quick tap in the move stick's zone must reach the field once, heard %s" % str(heard))

	heard.clear()
	_touch(right + Vector2(0.0, -30.0), true, 1)
	_lift(right + Vector2(0.0, -30.0), 1)
	_check(heard.size() == 1, "a quick tap in the aim stick's zone must reach the field once, heard %d"
		% heard.size())

	heard.clear()
	_touch(left, true, 0)
	_drag(left + Vector2(Balance.TOUCH_TAP_SLOP * 3.0, 0.0), 0)
	_lift(left + Vector2(Balance.TOUCH_TAP_SLOP * 3.0, 0.0), 0)
	_check(heard.is_empty(), "a push of the stick must stay a push, not a tap")

	heard.clear()
	_touch(left, true, 0)
	var held_from: int = Time.get_ticks_msec()
	# **On the wall clock**, which is the one a tap is judged by. A scene timer
	# counts game time, and headless that ran twice as fast: the first cut
	# waited "0.45 s" and held the thumb for 229 ms.
	while Time.get_ticks_msec() - held_from < int((Balance.TOUCH_TAP_SECONDS + 0.15) * 1000.0):
		await get_tree().process_frame
	_lift(left, 0)
	_check(heard.is_empty(), "a thumb held still on the stick for %d ms is not a tap, heard %s"
		% [Time.get_ticks_msec() - held_from, str(heard)])

	# A second finger, while the first holds the move stick: only finger 0 is
	# emulated as a mouse, so without this the other hand's tap clicked nothing.
	var middle: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.5, 0.25)
	heard.clear()
	_touch(left, true, 0)
	_touch(middle, true, 1)
	_lift(middle, 1)
	_lift(left, 0)
	_check(heard.size() >= 1 and heard[0].is_equal_approx(middle),
		"a second finger's tap on open ground must reach the field, heard %s" % str(heard))

	# Finger 0 on open ground is the emulated mouse's; reporting it too would
	# open the sheet twice.
	heard.clear()
	_touch(middle, true, 0)
	_lift(middle, 0)
	_check(heard.is_empty(), "finger 0 on open ground is the mouse's click and must not be reported twice")

	TouchInput.field_tapped.disconnect(listen)
	MetaState.settings[TouchInput.TOUCH_KEY] = false
	TouchInput.refresh()
	_settle()


## Runs the frame that turns stick positions into pressed actions.
func _settle() -> void:
	TouchInput._process(0.016)


## Build mode gives the screen back.
##
## The stick zones are 42% of the width by 62% of the height *each*, anchored to
## the bottom - together the whole lower two-thirds of the screen bar a narrow
## centre strip. A press inside one is claimed and marked handled, so while they
## are live a tap on a buildable tile in that area never reaches the placement
## cursor and the tower sheet does not open. Reported from a phone as the build
## menu working "sometimes", which is what a rule about *where* you tapped looks
## like from the outside.
##
## Held here rather than in the input code because the failure is a silent one:
## nothing errors, the tap simply goes nowhere, and the only symptom is a player
## pressing the same tile twice.
func _test_build_mode_frees_the_screen() -> void:
	var was: bool = GameDirector.build_mode
	var span: Vector2 = get_viewport().get_visible_rect().size
	var left: Rect2 = TouchInput.zone(false)
	var right: Rect2 = TouchInput.zone(true)
	_check(left.size.x > 0.0 and left.size.y > 0.0, "the sticks must have zones")
	# The two of them really do own most of the glass - stated so the number is
	# in front of whoever changes it next.
	var covered: float = (left.get_area() + right.get_area()) \
		/ maxf(span.x * span.y, 1.0)
	_check(covered > 0.4,
		"the stick zones cover %.0f%% of the screen; if that has shrunk this "
			% (covered * 100.0) + "test is guarding something that moved")

	# **Answered by tap-versus-drag, as of 2026-09-25**, and asserted in
	# `_test_a_tap_is_a_tap_wherever_it_lands`. The obvious fix - stand the
	# sticks down in build mode - is wrong: `GameDirector.build_mode` defaults
	# to *true*, so it disables them globally and this gate went from clean to
	# twelve failures. The sticks still claim the finger; a press let go
	# quickly and still is handed back to the field as a tap. The measurement
	# above stays, because it is why the tap exists.
	GameDirector.build_mode = was


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[touch] %s" % why)
