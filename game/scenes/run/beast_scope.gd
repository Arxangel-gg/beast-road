class_name BeastScope
extends Node2D

## The walk (GDD §7). The beast crossing the land with the town on its back —
## References/Scope3(Beast).png — plus how far there is left to go.
##
## This scope shows state and changes nothing. Its job is to make distance feel
## like a place rather than a number in the corner of a HUD.

## How far the parallax layers scroll per distance unit.
const BACKDROP_SCROLL: float = 2.4
const FOREGROUND_SCROLL: float = 6.0

@export var backdrop: Sprite2D
@export var beast: Sprite2D
@export var route_line: Line2D
@export var route_marker: Sprite2D

## Each scope owns its camera; the run makes the right one current when the
## scope changes, so switching does not leave the view sitting in another scope.
@export var camera: Camera2D


func activate() -> void:
	if camera != null:
		camera.make_current()

var _zoomed_out: bool = false
var _bob: float = 0.0


func _ready() -> void:
	_setup_route()


func _process(delta: float) -> void:
	# The beast bobs with its own gait rather than with real time, so a slowed
	# beast visibly plods.
	_bob += delta * RunState.beast_speed * 2.2
	if beast != null:
		beast.position.y = sin(_bob) * 6.0
		beast.position.x = -20.0 + sin(_bob * 0.5) * 8.0

	if backdrop != null:
		var offset: float = fmod(RunState.distance_travelled * BACKDROP_SCROLL, 1920.0)
		backdrop.position.x = -offset

	_update_route()


## Toggled from the HUD. Zooming out swaps the walking view for the whole route,
## which is where "how far to the next crossroad" actually reads.
func set_zoomed_out(value: bool) -> void:
	_zoomed_out = value
	if route_line != null:
		route_line.visible = value
	if route_marker != null:
		route_marker.visible = value
	if beast != null:
		beast.scale = Vector2.ONE * (0.45 if value else 1.0)
	if backdrop != null:
		backdrop.modulate = Color(0.55, 0.55, 0.6) if value else Color.WHITE


func is_zoomed_out() -> bool:
	return _zoomed_out


func toggle_zoom() -> void:
	set_zoomed_out(not _zoomed_out)


## The whole journey as one line, with a tick at every crossroad and act
## boundary so the shape of the run is legible at a glance.
func _setup_route() -> void:
	if route_line == null:
		return
	var left: float = -820.0
	var right: float = 820.0
	route_line.points = PackedVector2Array([Vector2(left, 220.0), Vector2(right, 220.0)])
	route_line.width = 6.0
	route_line.default_color = Color(0.85, 0.80, 0.72, 0.5)
	route_line.visible = false

	var segments: int = int(Balance.JOURNEY_TOTAL_DISTANCE / Balance.SEGMENT_DISTANCE)
	for i: int in range(1, segments):
		var t: float = float(i) / float(segments)
		var tick := Line2D.new()
		var x: float = lerpf(left, right, t)
		var is_act_boundary: bool = int(round(t * Balance.JOURNEY_TOTAL_DISTANCE)) % int(Balance.ACT_DISTANCE) == 0
		var height: float = 34.0 if is_act_boundary else 18.0
		tick.points = PackedVector2Array([Vector2(x, 220.0 - height), Vector2(x, 220.0 + height)])
		tick.width = 5.0 if is_act_boundary else 3.0
		tick.default_color = Color(0.91, 0.64, 0.24, 0.9) if is_act_boundary else Color(0.85, 0.80, 0.72, 0.6)
		route_line.add_child(tick)

	if route_marker != null:
		route_marker.visible = false


func _update_route() -> void:
	if route_marker == null or not _zoomed_out:
		return
	route_marker.position = Vector2(lerpf(-820.0, 820.0, RunState.journey_ratio()), 220.0)
