class_name CampMarker
extends Node2D

## The sign over a razed camp that it will stand again, and when (owner
## brief, 2026-09-12: "some sort of indicator for their respawn cooldown
## timer, cleverly integrated"). A ring that fills clockwise as the clock
## runs down, with a small skull at its heart that brightens as the camp
## nears standing, and the seconds under it for a player close enough to
## read them. Drawn, so it is right at every zoom.

var total: float = 1.0
var left: float = 0.0
var _clock: float = 0.0
var _label: Label = null


func _ready() -> void:
	z_as_relative = false
	z_index = Balance.HEALTH_BAR_Z - 2
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.03, 0.9))
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(-40.0, Balance.CAMP_MARKER_RADIUS + 6.0)
	_label.size = Vector2(80.0, 16.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process_measured(delta: float) -> void:
	_clock += delta
	if _label != null:
		_label.text = "%d s" % int(ceil(maxf(left, 0.0)))
	queue_redraw()


func _draw_measured() -> void:
	var radius: float = Balance.CAMP_MARKER_RADIUS
	var done: float = 1.0 - clampf(left / maxf(total, 0.01), 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_clock * (2.0 + 4.0 * done))
	draw_circle(Vector2.ZERO, radius + 3.0, Color(0.04, 0.03, 0.04, 0.45))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Balance.CAMP_MARKER_DIM, 4.0)
	if done > 0.001:
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * done, 40,
			Balance.CAMP_MARKER_COLOUR, 4.0)
	# The skull: two sockets and a jaw, brightening as the camp nears.
	var bone: Color = Color(0.9, 0.85, 0.78, 0.35 + 0.6 * done)
	draw_circle(Vector2(0.0, -3.0), 8.0, bone)
	draw_rect(Rect2(-5.0, 3.0, 10.0, 5.0), bone)
	var socket: Color = Color(0.1, 0.06, 0.06, 0.8)
	draw_circle(Vector2(-3.2, -4.0), 2.2, socket)
	draw_circle(Vector2(3.2, -4.0), 2.2, socket)
	draw_rect(Rect2(-3.0, 4.0, 1.5, 3.0), socket)
	draw_rect(Rect2(0.0, 4.0, 1.5, 3.0), socket)
	if done > 0.85:
		draw_arc(Vector2.ZERO, radius + 6.0 + pulse * 3.0, 0.0, TAU, 40,
			Color(Balance.CAMP_MARKER_COLOUR, 0.2 + 0.3 * pulse), 2.0)


## `FrameProfile` bucket "d_camp_marker": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_camp_marker", started)


## `FrameProfile` bucket "p_camp_marker": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_camp_marker", started)
