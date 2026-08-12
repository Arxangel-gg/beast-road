class_name LaneRosette
extends Control

## The directional threat readout (GDD §3), drawn as four arcs around the town.
##
## It replaces four labelled progress bars floating in the middle of the screen.
## Those had three problems and only one of them was cosmetic:
##
## * They were as loud at rest as under attack. A readout the player must ignore
##   most of the time has to disappear most of the time, or it stops being read
##   at all.
## * They labelled themselves N/E/S/W. The player can see which way is up; the
##   letters were answering a question nobody had while sitting over the field.
## * A rectangle floating beside a lane does not point anywhere. Threat from the
##   north is a *direction*, and the shape saying so should be aimed along it.
##
## An arc hugging the town on the side the pressure is coming from says the same
## thing without naming it, and says nothing at all when the road is clear.
##
## Drawn rather than built from Control nodes because it is one shape per lane
## with no interaction — four ProgressBars with rotated containers would be more
## nodes, more theme overrides and less control over the falloff.

## 0..1 per lane, smoothed toward whatever the battlefield last reported.
var _pressure: Array[float] = []
var _shown: Array[float] = []
var _pulse: float = 0.0

## Where the arcs are centred, in screen space.
##
## The town, not the middle of the screen. The camera follows the hero, so the
## town drifts off centre whenever the player walks out to a lane — and a ring
## that stays put while the thing it describes slides out from under it reads as
## a HUD element that has come loose. Falls back to the centre if there is no
## town, which is the case in a raid.
var _centre: Vector2 = Vector2.ZERO
var _town: Node2D = null


func _ready() -> void:
	_pressure.resize(Balance.LANE_COUNT)
	_pressure.fill(0.0)
	_shown.resize(Balance.LANE_COUNT)
	_shown.fill(0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	EventBus.lane_pressure_changed.connect(set_pressure)
	# Drawn once up front. _process only redraws on change, so without this the
	# empty track never appears until the first enemy walks.
	resized.connect(queue_redraw)
	queue_redraw()


func set_pressure(lane: int, value: float) -> void:
	if lane >= 0 and lane < _pressure.size():
		_pressure[lane] = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	_pulse += delta * Balance.LANE_RING_PULSE_SPEED

	var moved: bool = false
	var wanted: Vector2 = _town_on_screen()
	if wanted.distance_to(_centre) > 0.5:
		_centre = wanted
		moved = true

	# Eased toward the target rather than snapped. Pressure is recomputed on a
	# slow tick, and a bar that steps five times a second reads as broken.
	for lane: int in _shown.size():
		var next: float = lerpf(_shown[lane], _pressure[lane], 1.0 - exp(-6.0 * delta))
		if absf(next - _shown[lane]) > 0.0005:
			_shown[lane] = next
			moved = true
	# Redrawn while anything is alight, because the alarm pulse animates even
	# when the value is steady.
	if moved or _any_alarmed():
		queue_redraw()


func _town_on_screen() -> Vector2:
	if _town == null or not is_instance_valid(_town):
		_town = get_tree().get_first_node_in_group(&"town") as Node2D
	if _town == null or not _town.is_inside_tree():
		return size * 0.5
	# The canvas transform folds in the camera, which is exactly the mapping from
	# a world position to where it lands on screen.
	return _town.get_global_transform_with_canvas().origin


func _any_alarmed() -> bool:
	for value: float in _shown:
		if value >= Balance.LANE_RING_ALARM_AT:
			return true
	return false


func _draw() -> void:
	var centre: Vector2 = _centre if _centre != Vector2.ZERO else size * 0.5
	var span: float = deg_to_rad(Balance.LANE_RING_ARC_DEGREES)

	for lane: int in _shown.size():
		# Lane 0 is north and they run clockwise, matching Battlefield.lane_vector.
		# Screen angles start at +X, so north is a quarter turn back from it.
		var middle: float = -PI * 0.5 + TAU * float(lane) / float(Balance.LANE_COUNT)
		var value: float = _shown[lane]

		# The empty track. Faint enough to ignore, present enough that a filling
		# arc has somewhere visible to fill.
		draw_arc(centre, Balance.LANE_RING_RADIUS, middle - span * 0.5, middle + span * 0.5,
			48, Color(1.0, 0.94, 0.86, Balance.LANE_RING_TRACK_ALPHA),
			Balance.LANE_RING_THICKNESS, true)

		if value <= 0.004:
			continue

		# The fill grows outward from the middle of the arc in both directions, so
		# it reads as pressure building on that side rather than as a bar filling
		# from one end. Direction, not quantity, is the thing being communicated.
		var half: float = span * 0.5 * value
		var colour: Color = Balance.LANE_RING_CALM.lerp(Balance.LANE_RING_HOT, value)
		var alpha: float = Balance.LANE_RING_FULL_ALPHA * (0.35 + 0.65 * value)
		var thickness: float = Balance.LANE_RING_THICKNESS + Balance.LANE_RING_GROWTH * value

		# Above the alarm line it breathes. Below it, it holds still — a readout
		# that always pulses is one the eye stops going to.
		if value >= Balance.LANE_RING_ALARM_AT:
			var beat: float = 0.82 + 0.18 * sin(_pulse)
			alpha *= beat
			thickness *= 0.92 + 0.08 * beat

		draw_arc(centre, Balance.LANE_RING_RADIUS, middle - half, middle + half,
			48, Color(colour, alpha), thickness, true)

		# A marker outside the arc pointing down the lane. Only once the lane is
		# genuinely under load, so it works as an alert rather than as chrome.
		if value >= Balance.LANE_RING_ALARM_AT:
			var outward: Vector2 = Vector2.RIGHT.rotated(middle)
			var at: Vector2 = centre + outward * (Balance.LANE_RING_RADIUS + thickness * 2.6)
			var arrow: Texture2D = IconKit.ui("pressure_arrow")
			if arrow != null:
				# The art points right, which is angle zero — the same convention
				# the arc angles use, so `middle` rotates it straight onto the lane.
				var reach: float = Balance.LANE_RING_ARROW_SIZE * (0.75 + 0.25 * value)
				draw_set_transform(at, middle, Vector2.ONE)
				draw_texture_rect(arrow,
					Rect2(-reach * 0.5, -reach * 0.5, reach, reach), false, Color(colour, alpha))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var wing: Vector2 = outward.orthogonal() * thickness * 1.1
				var back: Vector2 = centre + outward * (Balance.LANE_RING_RADIUS + thickness * 0.6)
				draw_colored_polygon(PackedVector2Array([
					at, back + wing, back - wing]), Color(colour, alpha))
