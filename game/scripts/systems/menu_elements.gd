class_name MenuElements
extends Node2D

## The elements cross the menu: a storm, an ember wind, a frost, a green surge.
##
## **Owner brief, 2026-09-15:** "make chain lightning and fire and other
## elements flow through the menu if you can make it aesthetically appealing and
## game juicy super vfx awesome and gorgeous".
##
## **One at a time, and never for long.** The temptation with a brief like that
## is to run everything at once, and the result is a screen that is busy rather
## than alive - the eye stops reading any of it, and the beast the picture is
## about stops being what you are looking at. So a *pass* crosses the scene
## every twenty seconds or so, lasts four, and is gone; the next one is a
## different element, never the same twice running.
##
## **Each element is what the game already means by it.** Storm is the same
## `MenuArcs` lightning the frame's joints use, chaining across the valley.
## Ember is fire's own colour drifting up on the wind. Frost falls instead of
## rising and is pale. Growth is a green swell of motes that drift sideways with
## the foliage. Nothing new is invented for the menu that the road does not have
## a name for.
##
## **It is drawn and read by nothing.** No input, no layout, no state; it sits
## behind the interface and in front of the backdrop, and if it were deleted the
## menu would be exactly as usable.

enum Element { STORM, EMBER, FROST, GROWTH }

## How wide a band of the screen a pass travels through, as fractions of the
## scene's height. The sky's own band: high enough to be over the valley,
## low enough not to run behind the title.
const BAND: Vector2 = Vector2(0.24, 0.78)

var span: Vector2 = Vector2(1920.0, 1080.0)
## Pulled toward the scene, so a pass belongs to the evening it crosses.
var light: Color = Color(1.0, 0.92, 0.82)

var _arcs: MenuArcs = null
var _motes: CPUParticles2D = null
var _time: float = 0.0
var _until: float = 0.0
var _next: float = 6.0
var _element: int = Element.STORM
var _last: int = -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_arcs = MenuArcs.new()
	_arcs.name = "Chain"
	# Off until a storm is passing: `MenuArcs` rolls its own arcs, and a pass
	# that is not happening must not spark.
	_arcs.spark_every = 999.0
	_arcs.weight = 3.2
	add_child(_arcs)
	_motes = CPUParticles2D.new()
	_motes.name = "Motes"
	_motes.emitting = false
	_motes.amount = 90
	_motes.lifetime = 5.5
	_motes.local_coords = false
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.spread = 34.0
	_motes.scale_amount_min = 1.0
	_motes.scale_amount_max = 2.6
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_motes.material = additive
	add_child(_motes)
	set_process(true)


func resize(to: Vector2) -> void:
	if to.x > 0.0 and to.y > 0.0:
		span = to


func _process(delta: float) -> void:
	_time += delta
	if _time < _until:
		if _element == Element.STORM:
			_arcs.spark_every = Balance.MENU_ELEMENT_STORM_EVERY
		return
	if _arcs != null:
		_arcs.spark_every = 999.0
	if _motes != null and _motes.emitting:
		_motes.emitting = false
	_next -= delta
	if _next <= 0.0:
		_begin()


## Start a pass. **Never the element that just went**, because two storms in a
## row is the one thing that makes a rotation read as a loop.
func _begin() -> void:
	var pick: int = _last
	for _try: int in 8:
		pick = int(_rng.randi() % 4)
		if pick != _last:
			break
	_last = pick
	_element = pick
	_until = _time + Balance.MENU_ELEMENT_SECONDS
	_next = Balance.MENU_ELEMENT_EVERY * _rng.randf_range(0.7, 1.4)
	var top: float = span.y * BAND.x
	var bottom: float = span.y * BAND.y
	match pick:
		Element.STORM:
			# Anchors strung across the valley at the band's own height, so the
			# chain hops from one to the next rather than striking the ground.
			var points := PackedVector2Array()
			var many: int = 9
			for step: int in many:
				points.append(Vector2(
					span.x * (0.06 + 0.88 * float(step) / float(many - 1)),
					_rng.randf_range(top, bottom)))
			_arcs.anchors = points
			_arcs.reach = span.x * 0.22
			_arcs.colour = Color(0.62, 0.82, 1.0, 1.0)
		Element.EMBER:
			_rain(Color(1.0, 0.56, 0.22, 1.0), Vector2(0.0, -46.0), bottom,
				span.y * 0.22)
		Element.FROST:
			_rain(Color(0.72, 0.9, 1.0, 1.0), Vector2(0.0, 30.0), top,
				span.y * 0.16)
		Element.GROWTH:
			_rain(Color(0.55, 0.92, 0.5, 1.0), Vector2(-18.0, -12.0),
				(top + bottom) * 0.5, span.y * 0.3)


## A drift of motes across the scene, given a colour, a direction and a height
## to start from. One emitter for all three, because they differ only in those.
func _rain(tint: Color, gravity: Vector2, from: float, spread: float) -> void:
	if _motes == null:
		return
	_motes.position = Vector2(span.x * 0.5, from)
	_motes.emission_rect_extents = Vector2(span.x * 0.52, spread * 0.5)
	_motes.gravity = gravity
	_motes.direction = gravity.normalized() if gravity.length() > 0.01 \
		else Vector2.UP
	_motes.initial_velocity_min = 8.0
	_motes.initial_velocity_max = 34.0
	var fade := Gradient.new()
	fade.set_color(0, Color(tint.r, tint.g, tint.b, 0.0))
	fade.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	fade.add_point(0.25, Color(tint.r, tint.g, tint.b, 0.55))
	fade.add_point(0.7, Color(tint.r, tint.g, tint.b, 0.4))
	_motes.color_ramp = fade
	_motes.emitting = true


## Which element is crossing right now, or -1 between passes. For the gate.
func passing() -> int:
	return _element if _time < _until else -1


## Advance the clock by hand. For the gate, which has no frames to spend.
func advance(delta: float) -> void:
	_process(delta)
