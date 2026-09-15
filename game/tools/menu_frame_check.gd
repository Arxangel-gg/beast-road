extends Node

## The carved border is alive, and it cannot take a press.
##
## Owner brief, 2026-09-15: a frame that is "gorgeous and maybe even has lively
## animated elements with awesome game juice and even reactiveness".
##
## **The one thing that must never happen is a decoration eating an input.** An
## overlay across the whole screen, over the buttons, is the shape of the fault
## every full-screen border in every project ships with once: the menu looks
## right and nothing can be clicked. That is the first check here and the
## loudest, and it is asked of the node rather than of the comment above it.
##
## The rest is what a screenshot cannot see. A frame that only *adds* light, so
## it can never swallow the edge of a dark backdrop - the bound `UiJuice` is
## held to and for the same reason. A sheen that travels rather than a whole
## frame that brightens, which is the difference between light moving and a
## loading bar. A press answered at the edge the press was near. And a wave that
## ends, because a reactive glow that never fades is just a brighter frame.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_the_art_is_on_disk()
	await _test_it_cannot_take_a_press()
	await _test_it_can_only_add_light()
	await _test_the_sheen_travels()
	await _test_a_press_is_answered_where_it_landed()
	_finish()


func _test_the_art_is_on_disk() -> void:
	for path: String in [MenuFrame.CORNER_ART, MenuFrame.EDGE_ART]:
		_check(ResourceLoader.exists(path), "%s must exist" % path)
	# A corner bracket is square, or turning it three times does not make a
	# frame - it makes three rectangles of different sizes at the corners.
	var corner: Texture2D = load(MenuFrame.CORNER_ART) as Texture2D
	if corner != null:
		_check(corner.get_width() == corner.get_height(),
			"the corner bracket must be square to be turned: %dx%d"
				% [corner.get_width(), corner.get_height()])


## **The whole screen, over the buttons, and untouchable.**
func _test_it_cannot_take_a_press() -> void:
	var frame: MenuFrame = await _frame()
	_check(frame.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the frame must ignore the mouse: it covers every button on the menu")
	# And it has to be asked of the real thing rather than of the constructor:
	# a `set_anchors_preset` that did not run leaves a zero-sized frame that
	# passes a filter check and draws nothing.
	_check(frame.size.x > 100.0 and frame.size.y > 100.0,
		"the frame must fill its layer: %s" % str(frame.size))
	frame.queue_free()


## **Additive only.** Every point on the frame, at many instants, with a press
## travelling: never darker than the unlit stone, never over white.
func _test_it_can_only_add_light() -> void:
	var frame: MenuFrame = await _frame()
	frame.light = Color(1.0, 0.92, 0.82)
	# The unlit stone, derived from the light the frame was given rather than
	# from a copy of the shade arithmetic - a floor that assumed white light
	# reads as a failure on every scene that is not lit white.
	var floor_lit: float = minf(frame.light.r * Balance.MENU_FRAME_SHADE,
		minf(frame.light.g * Balance.MENU_FRAME_SHADE * 0.97,
			frame.light.b * Balance.MENU_FRAME_SHADE * 0.93))
	var darkest: float = 9.0
	var brightest: float = 0.0
	for step: int in 40:
		frame.advance(0.7)
		frame.pulse_at(Vector2(float(step) * 37.0, float(step) * 11.0))
		for around: int in 24:
			var lit: Color = frame.light_at(float(around) / 24.0)
			darkest = minf(darkest, minf(lit.r, minf(lit.g, lit.b)))
			brightest = maxf(brightest, maxf(lit.r, maxf(lit.g, lit.b)))
	_check(darkest >= floor_lit - 0.001,
		("the frame must never darken below its own stone: %.3f against %.3f"
			% [darkest, floor_lit]))
	_check(brightest <= 1.0,
		"and never over white: %.3f" % brightest)
	frame.queue_free()


## **A band that moves, not a frame that pulses.** At any instant most of the
## perimeter is unlit by the sheen, and where the bright part is changes.
func _test_the_sheen_travels() -> void:
	var frame: MenuFrame = await _frame()
	var heads: Dictionary = {}
	for step: int in 8:
		frame.advance(3.1)
		var best: float = -1.0
		var at: int = 0
		for around: int in 32:
			var lit: float = frame.light_at(float(around) / 32.0).r
			if lit > best:
				best = lit
				at = around
		heads[at] = true
		# Most of the frame is not the sheen.
		var bright: int = 0
		for around: int in 32:
			if frame.light_at(float(around) / 32.0).r > best - 0.02:
				bright += 1
		_check(bright <= 12,
			("the sheen must be a band: %d of 32 points are at the brightest"
				% bright))
	_check(heads.size() >= 4,
		"the sheen must travel: it was brightest at %d different places over 8 steps"
			% heads.size())
	frame.queue_free()


## **Pressed near an edge, answered at that edge** - and the answer ends.
func _test_a_press_is_answered_where_it_landed() -> void:
	var frame: MenuFrame = await _frame()
	var span: Vector2 = frame.size
	# A point just inside the left edge belongs to the left run, which is the
	# last quarter of the way round. An angle from the centre would have sent a
	# press low on the left to the bottom edge on a wide screen.
	var left: float = frame.perimeter_of(Vector2(6.0, span.y * 0.8))
	_check(left > 0.72 and left < 1.0,
		"a press at the left edge must answer on the left run, not at %.2f" % left)
	var top: float = frame.perimeter_of(Vector2(span.x * 0.25, 4.0))
	_check(top > 0.0 and top < 0.25,
		"and one at the top on the top run, not at %.2f" % top)

	frame.pulse_at(Vector2(6.0, span.y * 0.8))
	_check(frame.waving(), "a press must start a wave")
	var near: float = frame.light_at(left).r
	var far: float = frame.light_at(fposmod(left + 0.5, 1.0)).r
	_check(near > far,
		("the wave must be brighter where it was pressed: %.3f against %.3f "
			+ "on the far side") % [near, far])
	for _step: int in 40:
		frame.advance(0.1)
	_check(not frame.waving(),
		"and it must end: a glow that never fades is just a brighter frame")
	frame.queue_free()


func _frame() -> MenuFrame:
	var layer := CanvasLayer.new()
	add_child(layer)
	var frame := MenuFrame.new()
	layer.add_child(frame)
	frame.size = Vector2(1920.0, 1080.0)
	await get_tree().process_frame
	return frame


func _finish() -> void:
	if _failures == 0:
		print("[menu-frame] PASS - %d checks: the art turns, the border takes no press, adds light and never takes it, a sheen that travels and a press answered where it landed" % _checks)
	else:
		push_error("[menu-frame] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[menu-frame] FAIL: %s" % why)
