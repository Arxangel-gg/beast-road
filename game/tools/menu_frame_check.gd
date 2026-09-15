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
	await _test_the_lightning_is_lightning()
	_test_the_holographic_pass_only_adds()
	await _test_one_element_crosses_at_a_time()
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




## **The lightning is lightning, and it stops.**
##
## Owner, 2026-09-15: arcs that snap the frame's segments together, and "little
## lightning arcs procedurally spark off of the title text art". Four ways a
## procedural bolt is quietly wrong, none of them visible in a still frame:
##
## - **It is straight.** A midpoint displacement with the push set to nothing is
##   a wire, and a wire between two points on a border looks like a bug.
## - **It is the same bolt every time.** The path is rolled from the arc's own
##   seed so the three passes that draw it agree; if the seed did not vary, the
##   frame would grow one permanent scribble.
## - **It never ends.** An arc is an event. A crackle that runs for ever is a
##   screensaver and the eye stops seeing it in a minute.
## - **It darkens.** Additive, like everything else drawn over this menu.
func _test_the_lightning_is_lightning() -> void:
	var arcs := MenuArcs.new()
	add_child(arcs)
	await get_tree().process_frame

	var from := Vector2(0.0, 0.0)
	var to := Vector2(120.0, 0.0)
	arcs.strike_between(from, to)
	_check(arcs.burning() == 1, "a struck arc must be alive")
	var path: PackedVector2Array = arcs.path_of_first()
	_check(path.size() >= 8,
		"a bolt must be subdivided, not a line: %d points" % path.size())
	var worst: float = 0.0
	for point: Vector2 in path:
		worst = maxf(worst, absf(point.y))
	_check(worst > 3.0,
		("a bolt must leave the straight line between its ends: %.2f pixels off "
			+ "a 120 span") % worst)
	_check(worst < 120.0 * 0.5,
		"and must not be a scribble: %.2f off a 120 span" % worst)
	_check(is_equal_approx(path[0].x, from.x) and is_equal_approx(path[0].y, from.y),
		"a bolt must start where it was struck")
	_check(path[path.size() - 1].distance_to(to) < 0.01,
		"and end where it was aimed")

	# Two bolts are two bolts.
	arcs.strike_between(from, to)
	var second: PackedVector2Array = arcs.path_of_first()
	var identical: bool = second.size() == path.size()
	if identical:
		var apart: float = 0.0
		for index: int in path.size():
			apart = maxf(apart, path[index].distance_to(second[index]))
		identical = apart < 0.01
	_check(not identical, "two arcs must not be the same scribble")

	# And they end.
	for _step: int in 40:
		arcs.advance(0.05)
	_check(arcs.burning() >= 0, "the arc list must stay sane")
	var material := arcs.material as CanvasItemMaterial
	_check(material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
		"the lightning must be additive: it is drawn over the interface")
	arcs.queue_free()


## **The holographic pass can only add light**, read out of the shader.
##
## Owner, 2026-09-15: "make the frame also holographic". The frame is drawn with
## a per-piece tint that `light_at` computes and the gate above bounds; a shader
## over the top that *assigned* to COLOR would throw that tint away, and one
## that multiplied by less than one could darken the border to nothing on a dark
## backdrop. Both are one character of somebody's edit, and neither shows in a
## headless run, where no shader compiles at all.
func _test_the_holographic_pass_only_adds() -> void:
	var file := FileAccess.open("res://scripts/shaders/menu_frame_holo.gdshader",
		FileAccess.READ)
	_check(file != null, "the frame's hologram shader must be on disk")
	if file == null:
		return
	var code: String = file.get_as_text()
	_check(code.contains("art * COLOR"),
		("the pass must multiply the art by the colour handed in: that is how "
			+ "the per-piece tint reaches the pixel"))
	_check(not code.contains("COLOR = art;"),
		"and must never assign over it, which throws the tint away")
	_check(code.contains("lit.rgb += "),
		"the hologram itself must be added rather than mixed")
	_check(not code.contains("blend_mul") and not code.contains("blend_sub"),
		"and the frame must not multiply or subtract, which can darken stone")
	_check(Balance.MENU_FRAME_HOLO_CEILING <= 0.2,
		("the hologram may add at most a fifth: %.2f washes the carving out"
			% Balance.MENU_FRAME_HOLO_CEILING))


## **One element crosses at a time, briefly, and never the same one twice.**
##
## Owner, 2026-09-15: "make chain lightning and fire and other elements flow
## through the menu". The failure that brief invites is everything at once - a
## screen so busy that none of it is read and the beast stops being what you are
## looking at - and the failure a rotation invites is a loop, which is what two
## storms in a row reads as. Both are properties of a minute of running, not of
## a frame, so neither can be photographed.
func _test_one_element_crosses_at_a_time() -> void:
	var scene := MenuElements.new()
	add_child(scene)
	scene.resize(Vector2(1920.0, 1080.0))
	await get_tree().process_frame

	var seen: Dictionary = {}
	var order: Array[int] = []
	var crossing: int = 0
	var steps: int = 0
	for _step: int in 900:
		scene.advance(0.25)
		steps += 1
		var now: int = scene.passing()
		if now < 0:
			continue
		crossing += 1
		seen[now] = true
		if order.is_empty() or order[order.size() - 1] != now:
			order.append(now)
	_check(seen.size() >= 3,
		"the rotation must reach most of its elements: %d of 4 in under four "
			% seen.size() + "minutes")
	var repeats: int = 0
	for index: int in range(1, order.size()):
		if order[index] == order[index - 1]:
			repeats += 1
	_check(repeats == 0,
		"an element must never follow itself: %d times in %d passes"
			% [repeats, order.size()])
	# And the menu is quiet most of the time.
	var busy: float = float(crossing) / float(maxi(steps, 1))
	_check(busy < 0.4,
		("the elements must be an event: the menu was crossed %.0f%% of the "
			+ "time") % (busy * 100.0))
	_check(busy > 0.02,
		"and must actually happen: %.1f%% of the time" % (busy * 100.0))
	scene.queue_free()


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[menu-frame] FAIL: %s" % why)
