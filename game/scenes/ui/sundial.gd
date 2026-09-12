class_name Sundial
extends Control

## The time of day, as a dial: the sun's arc by day and the moon's by night,
## with the sunrise and sunset marked where they will happen.
##
## Owner brief (2026-09-12): "a clock so that players can know the time of day
## with how long it is before sunset and sunrise, like a sundial that has a sun
## and moon icon". Drawn rather than iconed so it stays crisp at every HUD
## scale and the two bodies can move along the arc by the pixel.
##
## Reads `DayNight.phase` - 0 dawn, 0.25 midday, 0.5 dusk, 0.75 midnight - so
## the dial and the sky can never disagree. The day's arc runs left to right
## for phase 0..0.5 and the night's for 0.5..1, so the sun sets exactly where
## the moon rises, which is what makes "how long until dark" readable without a
## number: it is the distance left on the arc.

const WIDTH: float = 108.0
const HEIGHT: float = 50.0

var _font: Font = null


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Time of day. The sun sets where the moon rises."
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var centre := Vector2(WIDTH * 0.5, HEIGHT - 12.0)
	var radius: float = WIDTH * 0.42
	var phase: float = DayNight.phase
	var night: bool = phase >= 0.5
	# The arc itself: a faint sky-coloured band, warmer by day.
	var band: Color = Color(0.32, 0.36, 0.5, 0.55) if night else Color(0.95, 0.8, 0.5, 0.45)
	draw_arc(centre, radius, PI, TAU, 28, Color(0.05, 0.05, 0.08, 0.55), 6.0)
	draw_arc(centre, radius, PI, TAU, 28, band, 3.0)
	# The horizon, with sunrise on the left and sunset on the right.
	draw_line(centre + Vector2(-radius - 6.0, 0.0), centre + Vector2(radius + 6.0, 0.0),
		Color(0.86, 0.80, 0.70, 0.7), 1.5)
	_mark(centre + Vector2(-radius, 0.0), Color(1.0, 0.82, 0.45))
	_mark(centre + Vector2(radius, 0.0), Color(0.85, 0.55, 0.45))
	# Where the body is: the fraction of its own half of the day, along the arc.
	var t: float = (phase - 0.5) / 0.5 if night else phase / 0.5
	var angle: float = PI + PI * clampf(t, 0.0, 1.0)
	var at: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius
	if night:
		_moon(at)
	else:
		_sun(at)
	# The clock, under the horizon.
	if _font != null:
		var text: String = DayNight.clock_text()
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(_font, Vector2(WIDTH * 0.5 - width * 0.5 + 1.0, HEIGHT - 1.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.0, 0.0, 0.0, 0.7))
		draw_string(_font, Vector2(WIDTH * 0.5 - width * 0.5, HEIGHT - 2.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.9, 0.8))


func _mark(at: Vector2, colour: Color) -> void:
	draw_line(at + Vector2(0.0, -4.0), at + Vector2(0.0, 4.0), colour, 2.0)


func _sun(at: Vector2) -> void:
	draw_circle(at, 9.0, Color(1.0, 0.8, 0.3, 0.35))
	for ray: int in 8:
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(ray) / 8.0)
		draw_line(at + direction * 6.5, at + direction * 9.5, Color(1.0, 0.88, 0.5), 1.5)
	draw_circle(at, 5.0, Color(1.0, 0.92, 0.62))
	draw_circle(at + Vector2(-1.5, -1.5), 2.0, Color(1.0, 1.0, 0.9))


func _moon(at: Vector2) -> void:
	draw_circle(at, 8.5, Color(0.7, 0.8, 1.0, 0.25))
	draw_circle(at, 5.5, Color(0.9, 0.93, 1.0))
	# The crescent: the dark of the sky bitten out of the disc.
	draw_circle(at + Vector2(2.6, -1.4), 4.6, Color(0.13, 0.15, 0.26))
	draw_circle(at + Vector2(-3.0, 1.5), 0.9, Color(1.0, 1.0, 1.0, 0.9))
