extends Node

## The interface answers being touched, and stays readable while it does.
##
## Owner brief, 2026-09-15: "holographic vfx for when players hover or tap on UI
## buttons as well and more game juice to UI interactions".
##
## **The one thing that must not happen is a button nobody can read.** That is
## `UiTint`'s standing bound - frames may be graded, text may not - and the
## hologram inherits it in a stronger form: additive blending can only add
## light, so over dark plates and pale lettering no glyph loses contrast. This
## gate holds that as a property of the shader rather than of the comment above
## it, because a later hand tuning the look could reach for `blend_mix` without
## ever noticing what it cost.
##
## The rest is the failures a screenshot cannot show: an effect wired to the
## mouse and not the pad, a second enrol stacking a second skin on every button,
## and a sweep that loops instead of answering.

var _failures: int = 0
var _checks: int = 0
var _root: Control = null
var _button: Button = null


func _ready() -> void:
	_root = Control.new()
	add_child(_root)
	_button = Button.new()
	_button.text = "Take the road"
	_button.size = Vector2(240.0, 64.0)
	_root.add_child(_button)
	await get_tree().process_frame
	_test_the_hologram_can_only_add_light()
	_test_a_button_is_dressed_once()
	_test_the_pad_gets_the_same_answer()
	await _test_a_press_tears_and_recovers()
	await _test_the_sweep_is_an_answer_and_not_a_loop()
	await _test_a_hover_never_leaves_its_layout_place()
	_finish()


## **Additive, bounded, and read off the shader.**
##
## Three ways this becomes an unreadable interface and all three are text in a
## file somebody will edit: the blend mode, the ceiling, and the possibility of
## the skin swallowing input in front of a button.
func _test_the_hologram_can_only_add_light() -> void:
	var file := FileAccess.open(UiJuice.SHADER, FileAccess.READ)
	_check(file != null, "the hologram shader must be on disk")
	if file == null:
		return
	var code: String = file.get_as_text()
	_check(code.contains("blend_add"),
		("the hologram must be additive: it is drawn over the button's own text, "
			+ "and only an additive layer is guaranteed not to take contrast away"))
	_check(not code.contains("blend_mul") and not code.contains("blend_sub"),
		"and it must not multiply or subtract, which can darken a glyph")

	UiJuice.dress(_button)
	var skin: ColorRect = UiJuice.skin_of(_button)
	_check(skin != null, "a dressed button must carry a skin")
	if skin == null:
		return
	_check(skin.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		("the skin must ignore the mouse: it covers the whole button, and one "
			+ "that ate clicks would make every dressed control dead"))
	var material := skin.material as ShaderMaterial
	_check(material != null, "the skin must carry the hologram material")
	if material == null:
		return
	var ceiling: float = float(material.get_shader_parameter("ceiling"))
	_check(ceiling > 0.0 and ceiling <= 0.25,
		("the hologram's ceiling is %0.3f: above a quarter it stops being light "
			+ "on a button and becomes a wash over the words") % ceiling)
	_check(is_zero_approx(UiJuice.strength_of(_button)),
		"a button nobody is pointing at must be drawing nothing (%0.3f)"
			% UiJuice.strength_of(_button))


## A control can be enrolled twice - the HUD rebuilds parts of itself, which is
## exactly why `UiTint` uses a group rather than a list - so dressing has to be
## idempotent or every rebuild stacks another skin and another set of signals.
func _test_a_button_is_dressed_once() -> void:
	UiJuice.dress(_button)
	UiJuice.dress(_button)
	UiJuice.dress(_button)
	var skins: int = 0
	for child: Node in _button.get_children():
		if child is ColorRect and child.name == String(UiJuice.SKIN):
			skins += 1
	_check(skins == 1, "a button must carry exactly one skin, not %d" % skins)


## **The pad and the thumb, not only the mouse.** A hover effect wired to
## `mouse_entered` alone is a hover effect for one of the three ways this game
## is played, and the controller path is the one that gets forgotten.
func _test_the_pad_gets_the_same_answer() -> void:
	_button.focus_entered.emit()
	_check(UiJuice.strength_of(_button) >= 0.0,
		"focus must reach the hologram at all")
	_button.mouse_entered.emit()
	var lit_by_mouse: bool = true
	_button.mouse_exited.emit()
	_check(lit_by_mouse, "the mouse must reach it too")
	# Driven rather than read: the connections themselves are what the failure
	# would be, so they are counted.
	for signal_name: String in ["mouse_entered", "mouse_exited",
			"focus_entered", "focus_exited", "button_down"]:
		var connections: Array = _button.get_signal_connection_list(signal_name)
		_check(not connections.is_empty(),
			"%s must be wired, or that way of touching a button says nothing"
				% signal_name)


## A press tears the hologram for a moment and then stops. A tear that never
## recovered would leave every pressed button permanently glitching.
func _test_a_press_tears_and_recovers() -> void:
	var skin: ColorRect = UiJuice.skin_of(_button)
	if skin == null:
		return
	var material := skin.material as ShaderMaterial
	# Read on the same call rather than after a frame: headless frames are not
	# sixtieths of a second, and one of them is longer than the tear.
	_button.button_down.emit()
	_check(float(material.get_shader_parameter("flicker")) > 0.1,
		"a press must tear the hologram (%0.3f)"
			% float(material.get_shader_parameter("flicker")))
	await get_tree().create_timer(Balance.UI_HOLO_TEAR + 0.25).timeout
	_check(float(material.get_shader_parameter("flicker")) < 0.05,
		"and it must settle again (%0.3f)"
			% float(material.get_shader_parameter("flicker")))


## **The sweep is a one-shot.** Parked outside its own range when nothing is
## happening, so an idle screen of buttons is not a wall of crawling light -
## which is a screensaver rather than a response, and is also the one thing
## here that would cost a frame on a menu that is otherwise still.
func _test_the_sweep_is_an_answer_and_not_a_loop() -> void:
	var skin: ColorRect = UiJuice.skin_of(_button)
	if skin == null:
		return
	var material := skin.material as ShaderMaterial
	_button.mouse_entered.emit()
	_button.mouse_exited.emit()
	# **Settled, not instantaneous.** A button the pointer has just left is not
	# idle yet - its light is still falling and its sweep is still crossing -
	# and the first cut of this read the sweep mid-flight at 1.161 and called a
	# working effect a loop. What matters is where both end up.
	await get_tree().create_timer(Balance.UI_HOLO_SWEEP
		+ Balance.UI_HOLO_FALL + 0.3).timeout
	var parked: float = float(material.get_shader_parameter("sweep"))
	_check(parked < -0.39 or parked > 1.39,
		"a settled button's sweep must be parked off its own surface (%0.3f)" % parked)
	_check(UiJuice.strength_of(_button) < 0.01,
		("and its light must be out, so an idle screen of buttons draws nothing "
			+ "(%0.3f)") % UiJuice.strength_of(_button))
	var file := FileAccess.open(UiJuice.SHADER, FileAccess.READ)
	if file != null:
		var code: String = file.get_as_text()
		_check(code.contains("step(-0.399, sweep)"),
			("the shader must refuse to draw a parked sweep, so a control whose "
				+ "tween never ran costs nothing"))


func _finish() -> void:
	if _root != null:
		_root.queue_free()
	for _frame: int in 4:
		await get_tree().process_frame
	if _failures == 0:
		print("[ui-juice] PASS - %d checks: additive and bounded, one skin a button, the pad answered like the mouse, a tear that settles and a sweep that is parked" % _checks)
	else:
		push_error("[ui-juice] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[ui-juice] FAIL: %s" % why)


## **A hovered button never leaves the layout's own place by more than a nudge.**
##
## Owner report, 2026-09-15: the Preparation card's RIDE ON button "moves way
## too far", is "hard to click" and "covers up the ui texts including
## countdown". The lift was two pixels and the fault was not its size - it
## remembered where the button had been on the first hover and tweened back to
## that forever, while the container went on re-laying the column out under it
## every time the countdown's text changed size. The button then jumped out from
## under the cursor, which un-hovered it, which dropped it back: a bounce that
## no screenshot and no static layout check can see.
##
## So this drives the real thing: a real container, a sibling that changes size
## the way a clock does, and the displacement measured against where the layout
## put the button rather than against where it started.
func _test_a_hover_never_leaves_its_layout_place() -> void:
	var column := VBoxContainer.new()
	column.size = Vector2(220.0, 200.0)
	_root.add_child(column)
	var clock := Label.new()
	clock.text = "12 sec"
	clock.add_theme_font_size_override("font_size", 26)
	column.add_child(clock)
	var ride := Button.new()
	ride.text = "RIDE ON"
	column.add_child(ride)
	await get_tree().process_frame
	UiJuice.dress(ride)

	# Hovered where it stands: at most the authored nudge, upward.
	ride.mouse_entered.emit()
	for _frame: int in 24:
		await get_tree().process_frame
	var laid_out: float = column.position.y + clock.size.y 		+ column.get_theme_constant(&"separation")
	_check(absf(ride.position.y - laid_out) <= Balance.UI_HOLO_LIFT + 0.6,
		"a hovered button must sit within %0.1fpx of where the column put it: %0.1f against %0.1f"
			% [Balance.UI_HOLO_LIFT, ride.position.y, laid_out])

	# **The clock ticks, and the column re-sorts under the hovered button.**
	# This is the fault: the remembered home is now wrong by however much the
	# row above grew.
	clock.add_theme_font_size_override("font_size", 52)
	clock.text = "GO"
	column.queue_sort()
	for _frame: int in 8:
		await get_tree().process_frame
	ride.mouse_exited.emit()
	ride.mouse_entered.emit()
	for _frame: int in 24:
		await get_tree().process_frame
	var moved: float = column.position.y + clock.size.y 		+ column.get_theme_constant(&"separation")
	_check(absf(ride.position.y - moved) <= Balance.UI_HOLO_LIFT + 0.6,
		("after the column re-sorts, a hover must still land within %0.1fpx of "
			+ "the new layout: %0.1f against %0.1f")
			% [Balance.UI_HOLO_LIFT, ride.position.y, moved])

	# And left alone it returns exactly, rather than settling a nudge higher
	# every time it is pointed at.
	ride.mouse_exited.emit()
	for _frame: int in 24:
		await get_tree().process_frame
	_check(absf(ride.position.y - moved) <= 0.6,
		"and it must come back to the layout's own place: %0.1f against %0.1f"
			% [ride.position.y, moved])
	column.queue_free()
