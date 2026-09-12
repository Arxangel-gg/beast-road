class_name WellGauge
extends Node2D

## The ring over a Healing Well that says how full it is, and whether there
## is a draught to take (owner brief, 2026-09-12: "healing wells do not have
## any indicator for how full they are or whether it's possible to drink").
##
## An arc that fills clockwise as the well draws, pale while filling and
## bright when full, with a slow pulse on a full one so a player crossing the
## field sees it from a distance. Drawn rather than sprited, so it is right at
## every tower level and every zoom.

var well: Tower = null
var _clock: float = 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = Balance.HEALTH_BAR_Z - 1
	position = Vector2(0.0, -Balance.WELL_GAUGE_RADIUS * 1.4)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if well == null or not is_instance_valid(well):
		return
	var fill: float = well.well_fill()
	var radius: float = Balance.WELL_GAUGE_RADIUS
	var full: bool = fill >= 0.999
	var pulse: float = 0.5 + 0.5 * sin(_clock * 3.0) if full else 0.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.03, 0.05, 0.07, 0.55), 6.0)
	if fill > 0.001:
		var colour: Color = Balance.WELL_GAUGE_EMPTY.lerp(Balance.WELL_GAUGE_FULL, fill)
		draw_arc(Vector2.ZERO, radius, -PI * 0.5, -PI * 0.5 + TAU * fill, 40, colour, 3.5)
	if full:
		draw_arc(Vector2.ZERO, radius + 4.0 + pulse * 3.0, 0.0, TAU, 40,
			Color(Balance.WELL_GAUGE_FULL, 0.25 + 0.25 * pulse), 2.0)
	# The droplet: the thing this gauge is a gauge of.
	var tip := Vector2(0.0, -7.0)
	var drop: PackedVector2Array = PackedVector2Array([tip, Vector2(5.0, 1.0), Vector2(3.5, 6.0),
		Vector2(0.0, 8.0), Vector2(-3.5, 6.0), Vector2(-5.0, 1.0)])
	draw_colored_polygon(drop, Balance.WELL_GAUGE_FULL if full else Balance.WELL_GAUGE_EMPTY)
