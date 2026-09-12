class_name ActTrack
extends Control

## How far through the act the beast is, with the crossroads marked on it.
##
## Owner brief (2026-09-12): a measurement display for how far into the
## current act the player is, with markers for the next crossroads. Drawn
## rather than built from bars, because the whole readout is one line: the
## act's road from its start to its boss, a tick at every crossroad, the beast
## where it is now, and the boss at the end.
##
## Reads `RunState` every frame it is visible and nothing else - it is a
## window onto the run, like the scope it sits in.

const WIDTH: float = 720.0
const HEIGHT: float = 58.0
const TRACK_Y: float = 34.0

var _font: Font = null


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var left: float = 0.0
	var right: float = WIDTH
	var progress: float = RunState.act_progress()
	var road: Color = Color(0.86, 0.80, 0.70, 0.55)
	var done: Color = Color(0.91, 0.64, 0.24, 0.95)
	# The road, and the part of it walked.
	draw_line(Vector2(left, TRACK_Y), Vector2(right, TRACK_Y), Color(0.05, 0.05, 0.06, 0.6), 8.0)
	draw_line(Vector2(left, TRACK_Y), Vector2(right, TRACK_Y), road, 4.0)
	draw_line(Vector2(left, TRACK_Y), Vector2(lerpf(left, right, progress), TRACK_Y), done, 4.0)
	# The crossroads: one every segment, the last one the boss.
	var segments: int = maxi(int(round(Balance.ACT_DISTANCE / Balance.SEGMENT_DISTANCE)), 1)
	for index: int in range(1, segments + 1):
		var t: float = float(index) / float(segments)
		var x: float = lerpf(left, right, t)
		var passed: bool = progress >= t - 0.0001
		if index == segments:
			# The boss: a diamond at the road's end.
			var colour: Color = Color(0.95, 0.35, 0.28, 1.0) if not passed else done
			draw_colored_polygon(PackedVector2Array([Vector2(x, TRACK_Y - 11.0),
				Vector2(x + 9.0, TRACK_Y), Vector2(x, TRACK_Y + 11.0), Vector2(x - 9.0, TRACK_Y)]),
				colour)
			_text(Vector2(x - 20.0, TRACK_Y + 26.0), "Boss", colour, 13)
		else:
			var colour: Color = done if passed else Color(0.86, 0.80, 0.70, 0.9)
			draw_line(Vector2(x, TRACK_Y - 9.0), Vector2(x, TRACK_Y + 9.0), colour, 3.0)
			draw_circle(Vector2(x, TRACK_Y - 13.0), 3.0, colour)
			_text(Vector2(x - 36.0, TRACK_Y + 26.0), "Crossroad", colour, 12)
	# The beast: where it is now, as a bright marker with a soft halo.
	var here: float = lerpf(left, right, progress)
	draw_circle(Vector2(here, TRACK_Y), 9.0, Color(done, 0.35))
	draw_circle(Vector2(here, TRACK_Y), 5.5, Color(1.0, 0.93, 0.78, 1.0))
	# The words: the act, and what is next.
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	var name: String = terrain.display_name if terrain != null else RunState.terrain_id.capitalize()
	_text(Vector2(left, 12.0), "Act %d  ·  %s" % [RunState.act, name], Color(0.95, 0.9, 0.8), 15)
	var to_cross: float = RunState.distance_to_crossroad()
	var to_boss: float = RunState.distance_to_boss()
	var next: String = "boss in %d" % int(ceil(to_boss)) if to_boss <= to_cross + 0.5 \
		else "crossroad in %d" % int(ceil(to_cross))
	var width: float = _font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x if _font != null else 120.0
	_text(Vector2(right - width, 12.0), next, Color(0.86, 0.80, 0.70, 0.95), 14)


func _text(at: Vector2, text: String, colour: Color, size: int) -> void:
	if _font == null:
		return
	draw_string(_font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(0.0, 0.0, 0.0, 0.7))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
