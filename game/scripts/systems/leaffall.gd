class_name Leaffall
extends Node2D

## Leaves coming off the treeline, occasionally, and landing.
##
## Owner request, 2026-09-01: "would be nice if sometimes trees had leaf falling
## particle system effects that procedurally randomly have leaves occasionally
## falling and blowing with the wind a bit and landing on the ground somewhere
## naturally and randomly and aesthetically, and fading out after an appropriate
## amount of time without being distracting."
##
## ## One canvas item, not one per leaf
##
## The foliage field's whole performance history is in `Foliage`: 420 separate
## `CanvasItem`s, each transformed once a frame, cost more than cast shadows,
## contact shadows and cloud shadows put together. A particle effect that
## repeated that mistake would undo the fix.
##
## So every live leaf is drawn by *this* node's `_draw`. Thirty leaves is thirty
## quads in one canvas item and one `queue_redraw` a frame, against thirty nodes
## with thirty transforms and thirty draw calls. The leaves are plain data in an
## array; nothing about them is a `Node`.
##
## ## Why not `GPUParticles2D`
##
## Because a leaf has to *land*. A particle system can fall and fade, but "settle
## on the ground at a plausible place and lie there for a moment" is a state
## machine, and expressing it as a lifetime curve would be a worse version of the
## twenty lines below. The count is small enough that the CPU cost of doing it
## honestly is not measurable.

## One leaf, in flight or at rest. A Dictionary rather than a class instance for
## the same reason `Foliage._animated` is: this array is walked every frame.
var _leaves: Array[Dictionary] = []

## Canopy points to shed from, handed over by `Treeline` when it scatters.
## Each entry is [position, height, half_width].
var _canopies: Array[Array] = []

var _next_fall: float = 0.0
var _rng := RandomNumberGenerator.new()
var _region: String = "jungle"


func _ready() -> void:
	# Just above the blood ground layer and well below anything the player has to
	# read. A leaf must never be mistaken for a pickup.
	z_index = Balance.LEAFFALL_Z
	_rng.randomize()
	_next_fall = _rng.randf_range(Balance.LEAFFALL_INTERVAL.x,
		Balance.LEAFFALL_INTERVAL.y)


## Told where the trees are, rather than searching for them.
##
## `Treeline` re-scatters whenever the act changes, and a group query per fall
## would allocate an array of two hundred nodes to pick one of them. The caller
## already holds the list.
func set_canopies(points: Array[Array], region: String) -> void:
	_canopies = points
	_region = region
	_leaves.clear()
	queue_redraw()


func _process(delta: float) -> void:
	var moved: bool = _tick_leaves(delta)
	if not _canopies.is_empty():
		_next_fall -= delta * _rate()
		if _next_fall <= 0.0:
			_next_fall = _rng.randf_range(Balance.LEAFFALL_INTERVAL.x,
				Balance.LEAFFALL_INTERVAL.y)
			_shed()
			moved = true
	if moved:
		queue_redraw()


## How often this region sheds, folded together with the graphics setting.
##
## A player who has turned foliage down has said they want less of this kind of
## thing; leaves are foliage even when they are in the air.
func _rate() -> float:
	var region: float = float(Balance.LEAFFALL_REGION_RATE.get(_region, 1.0))
	return region * clampf(Graphics.foliage_scale(), 0.0, 1.5)


## Where the camera is looking, in this node's own space, grown by a margin so a
## tree just off the edge can still drop a leaf that drifts into frame.
##
## **Sheds are aimed at visible trees.** The treeline is placed *outside* the
## battlefield on purpose - it is the wall of the arena - and a canopy chosen
## uniformly from two hundred of them is almost never one the player can see. A
## measured run had 0 of 24 live leaves inside the view: the effect worked
## perfectly and was invisible. Choosing from what is on screen also means the
## thirty-leaf budget is spent where it can be spent well.
func _view() -> Rect2:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return Rect2()
	var span: Vector2 = get_viewport().get_visible_rect().size / camera.zoom
	var rect := Rect2(camera.get_screen_center_position() - span * 0.5, span)
	return rect.grow(span.y * Balance.LEAFFALL_VIEW_MARGIN)


func _shed() -> void:
	if _leaves.size() >= Balance.LEAFFALL_MAX:
		return
	# From a tree the player can see, when there is one. Falling back to any
	# canopy keeps the effect alive during a transition where the camera has
	# not settled, rather than making it stop for a second.
	var view: Rect2 = _view()
	var seen: Array[Array] = []
	if view.size.x > 1.0:
		for canopy_at: Array in _canopies:
			if view.has_point(global_position + (canopy_at[0] as Vector2)):
				seen.append(canopy_at)
	var pool: Array = seen if not seen.is_empty() else _canopies
	var canopy: Array = pool[_rng.randi_range(0, pool.size() - 1)]
	var at: Vector2 = canopy[0]
	var height: float = float(canopy[1])
	var half_width: float = float(canopy[2])
	var burst: int = _rng.randi_range(Balance.LEAFFALL_BURST.x,
		Balance.LEAFFALL_BURST.y)
	var colours: Array = Balance.LEAFFALL_REGION_COLOURS.get(_region,
		Balance.LEAFFALL_REGION_COLOURS["jungle"]) as Array
	for _leaf: int in burst:
		if _leaves.size() >= Balance.LEAFFALL_MAX:
			return
		# Somewhere in the crown, not at the trunk: a leaf that appears on the
		# bark and falls straight down reads as a bug rather than as a leaf.
		var start := Vector2(
			at.x + _rng.randf_range(-half_width, half_width),
			at.y - height * _rng.randf_range(Balance.LEAFFALL_START_HEIGHT.x,
				Balance.LEAFFALL_START_HEIGHT.y))
		_leaves.append({
			"at": start,
			"from_x": start.x,
			"ground": start.y + height * _rng.randf_range(
				Balance.LEAFFALL_DROP.x, Balance.LEAFFALL_DROP.y),
			"fall": _rng.randf_range(Balance.LEAFFALL_FALL_SPEED.x,
				Balance.LEAFFALL_FALL_SPEED.y),
			"sway": _rng.randf_range(Balance.LEAFFALL_SWAY_SPEED.x,
				Balance.LEAFFALL_SWAY_SPEED.y),
			"phase": _rng.randf() * TAU,
			"spin": _rng.randf_range(Balance.LEAFFALL_SPIN.x, Balance.LEAFFALL_SPIN.y),
			"angle": _rng.randf() * TAU,
			"size": _rng.randf_range(Balance.LEAFFALL_SIZE.x, Balance.LEAFFALL_SIZE.y),
			"tint": (colours[0] as Color).lerp(colours[1] as Color, _rng.randf()),
			"age": 0.0,
			"rest": 0.0,
			"landed": false,
		})


## Returns whether anything moved, so a still field costs no redraws.
func _tick_leaves(delta: float) -> bool:
	if _leaves.is_empty():
		return false
	var wind: float = 0.0
	var weather: WeatherData = RunState.weather()
	if weather != null:
		wind = clampf(weather.wind, -1.0, 1.0)
	var drift: float = wind * Balance.LEAFFALL_WIND_DRIFT
	var dead: Array[int] = []
	for index: int in _leaves.size():
		var leaf: Dictionary = _leaves[index]
		leaf["age"] = float(leaf["age"]) + delta
		if bool(leaf["landed"]):
			leaf["rest"] = float(leaf["rest"]) + delta
			if float(leaf["rest"]) >= Balance.LEAFFALL_REST + Balance.LEAFFALL_FADE:
				dead.append(index)
			continue
		var at: Vector2 = leaf["at"]
		at.y += float(leaf["fall"]) * delta
		# The sway is a function of age rather than an accumulated velocity, so a
		# leaf traces a clean sine instead of drifting off on rounding error.
		var swing: float = sin(float(leaf["phase"])
			+ float(leaf["age"]) * float(leaf["sway"])) * Balance.LEAFFALL_SWAY_PIXELS
		at.x = float(leaf["from_x"]) + swing + drift * float(leaf["age"])
		leaf["angle"] = float(leaf["angle"]) + float(leaf["spin"]) * delta
		if at.y >= float(leaf["ground"]):
			at.y = float(leaf["ground"])
			leaf["landed"] = true
			# Lying flat once it is down. A leaf standing on its edge in the grass
			# is the one thing that would give away that these are quads.
			leaf["angle"] = _rng.randf_range(-0.4, 0.4)
		leaf["at"] = at
		_leaves[index] = leaf
	# Backwards, so removing one does not shift the index of the next.
	for index: int in range(dead.size() - 1, -1, -1):
		_leaves.remove_at(dead[index])
	return true


func _draw() -> void:
	for leaf: Dictionary in _leaves:
		var tint: Color = leaf["tint"]
		tint.a = Balance.LEAFFALL_ALPHA
		if bool(leaf["landed"]):
			var rest: float = float(leaf["rest"])
			if rest > Balance.LEAFFALL_REST:
				tint.a *= clampf(1.0 - (rest - Balance.LEAFFALL_REST)
					/ Balance.LEAFFALL_FADE, 0.0, 1.0)
			# Flattened once it is down, which is the whole of "landing".
			_draw_leaf(leaf["at"], float(leaf["angle"]), float(leaf["size"]),
				0.34, tint)
			continue
		_draw_leaf(leaf["at"], float(leaf["angle"]), float(leaf["size"]),
			# The vertical squash tracks the spin, so a leaf turning edge-on
			# thins out instead of staying a solid lozenge.
			absf(cos(float(leaf["angle"]))) * 0.55 + 0.12, tint)


## One leaf: a four-point lozenge, pointed at both ends.
##
## Drawn rather than textured, like everything else in `Vfx`. A leaf is six
## pixels across at gameplay zoom; an authored sprite for it would be four
## coloured pixels and a manifest row.
func _draw_leaf(at: Vector2, angle: float, size: float, squash: float,
		tint: Color) -> void:
	var along: Vector2 = Vector2.RIGHT.rotated(angle) * size
	var across: Vector2 = Vector2.DOWN.rotated(angle) * size * squash
	draw_colored_polygon(PackedVector2Array([
		at - along, at - across, at + along, at + across]), tint)
