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

	if _failures == 0:
		print("[touch] PASS - thumbs reach the input map, both sticks work at once, nothing leaks")
	get_tree().quit(_failures)


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


## Runs the frame that turns stick positions into pressed actions.
func _settle() -> void:
	TouchInput._process(0.016)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[touch] %s" % why)
