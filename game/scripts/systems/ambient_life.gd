class_name AmbientLife
extends Node2D

## Small, non-interactive life in the battlefield margins.
##
## This system has no EventBus gameplay messages, collision, groups, health or
## network ids by design. Fireflies and butterflies are each client's local
## dressing; losing or gaining one can never change a seeded run.

const BUTTERFLY_FRAME_FORMAT: String = "res://art/foliage/butterfly_fly_%02d.png"
const MAX_BUTTERFLY_FRAMES: int = 12

var grid: BattleGrid = null
var host: Node2D = null

var _butterflies: Array[Dictionary] = []
var _butterfly_frames: Array[Texture2D] = []
var _fireflies: CPUParticles2D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash("ambient-life:%s:%d" % [RunState.terrain_id, RunState.run_seed])
	_butterfly_frames = _frame_series()
	_build_butterflies()
	_build_fireflies()
	DayNight.night_changed.connect(_on_night_changed)
	_on_night_changed(DayNight.is_night())


func _exit_tree() -> void:
	for butterfly: Dictionary in _butterflies:
		var sprite := butterfly.get("sprite", null) as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_butterflies.clear()
	if _fireflies != null and is_instance_valid(_fireflies):
		_fireflies.queue_free()


func _process(delta: float) -> void:
	for butterfly: Dictionary in _butterflies:
		_tick_butterfly(butterfly, delta)


func _frame_series() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for index: int in range(1, MAX_BUTTERFLY_FRAMES + 1):
		var path: String = BUTTERFLY_FRAME_FORMAT % index
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


func _build_butterflies() -> void:
	if _butterfly_frames.is_empty():
		return
	var count: int = Graphics.scaled(Balance.AMBIENT_BUTTERFLY_COUNT,
		Graphics.foliage_scale())
	for index: int in count:
		var at: Vector2 = _clear_point()
		if at == Vector2.INF:
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Butterfly%d" % index
		sprite.texture = _butterfly_frames[index % _butterfly_frames.size()]
		sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
		sprite.add_to_group(Graphics.FILTER_GROUP)
		sprite.position = at
		sprite.offset.y = -Balance.AMBIENT_BUTTERFLY_LIFT
		sprite.scale = Vector2.ONE * _rng.randf_range(0.42, 0.68)
		(host if host != null else self).add_child(sprite)
		var angle: float = _rng.randf() * TAU
		_butterflies.append({
			"sprite": sprite,
			"home": at,
			"goal": at + Vector2.RIGHT.rotated(angle) * Balance.AMBIENT_BUTTERFLY_ROAM,
			"heading": Vector2.RIGHT.rotated(angle),
			"speed": _rng.randf_range(Balance.AMBIENT_BUTTERFLY_SPEED.x,
				Balance.AMBIENT_BUTTERFLY_SPEED.y),
			"phase": _rng.randf() * TAU,
			"frame": _rng.randf() * float(_butterfly_frames.size()),
		})


func _tick_butterfly(butterfly: Dictionary, delta: float) -> void:
	var sprite := butterfly["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	butterfly["frame"] = float(butterfly["frame"]) \
		+ delta * Balance.AMBIENT_BUTTERFLY_FRAME_RATE
	var frame: int = int(floor(float(butterfly["frame"]))) \
		% _butterfly_frames.size()
	sprite.texture = _butterfly_frames[frame]
	butterfly["phase"] = float(butterfly["phase"]) + delta * 2.1

	var toward: Vector2 = (butterfly["goal"] as Vector2) - sprite.position
	if toward.length() < 28.0:
		var home: Vector2 = butterfly["home"] as Vector2
		var roll: Vector2 = Vector2.RIGHT.rotated(_rng.randf() * TAU) \
			* _rng.randf_range(Balance.AMBIENT_BUTTERFLY_ROAM * 0.35,
				Balance.AMBIENT_BUTTERFLY_ROAM)
		var wanted: Vector2 = home + roll
		butterfly["goal"] = wanted if _is_clear(wanted) else home
		toward = (butterfly["goal"] as Vector2) - sprite.position
	var wanted_heading: Vector2 = toward.normalized() if not toward.is_zero_approx() \
		else butterfly["heading"] as Vector2
	wanted_heading += wanted_heading.orthogonal() \
		* sin(float(butterfly["phase"])) * 0.52
	var heading: Vector2 = (butterfly["heading"] as Vector2).lerp(
		wanted_heading.normalized(), clampf(delta * Balance.AMBIENT_BUTTERFLY_TURN, 0.0, 1.0))
	butterfly["heading"] = heading.normalized()
	sprite.position += (butterfly["heading"] as Vector2) \
		* float(butterfly["speed"]) * delta
	if absf((butterfly["heading"] as Vector2).x) > 0.01:
		sprite.flip_h = (butterfly["heading"] as Vector2).x < 0.0
	sprite.rotation = sin(float(butterfly["phase"]) * 0.73) * 0.08


func _build_fireflies() -> void:
	_fireflies = CPUParticles2D.new()
	_fireflies.name = "NightFireflies"
	_fireflies.texture = Flame.dot_texture()
	_fireflies.amount = Graphics.scaled(Balance.AMBIENT_FIREFLY_AMOUNT,
		Graphics.foliage_scale())
	_fireflies.lifetime = Balance.AMBIENT_FIREFLY_LIFETIME
	_fireflies.lifetime_randomness = 0.55
	_fireflies.preprocess = Balance.AMBIENT_FIREFLY_LIFETIME
	_fireflies.local_coords = true
	_fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies.emission_rect_extents = Balance.AMBIENT_FIREFLY_FIELD_EXTENT
	_fireflies.direction = Vector2.UP
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = Balance.AMBIENT_FIREFLY_SPEED * 0.35
	_fireflies.initial_velocity_max = Balance.AMBIENT_FIREFLY_SPEED
	_fireflies.gravity = Vector2(1.5, -2.0)
	_fireflies.scale_amount_min = Balance.AMBIENT_FIREFLY_SIZE * 0.55
	_fireflies.scale_amount_max = Balance.AMBIENT_FIREFLY_SIZE
	var twinkle := Curve.new()
	twinkle.add_point(Vector2(0.0, 0.0))
	twinkle.add_point(Vector2(0.18, 1.0))
	twinkle.add_point(Vector2(0.48, 0.25))
	twinkle.add_point(Vector2(0.72, 1.0))
	twinkle.add_point(Vector2(1.0, 0.0))
	_fireflies.scale_amount_curve = twinkle
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.20, 0.72, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.70, 1.0, 0.38, 0.0), Color(0.88, 1.0, 0.48, 0.92),
		Color(1.0, 0.83, 0.31, 0.78), Color(0.64, 0.94, 0.38, 0.0),
	])
	_fireflies.color_ramp = ramp
	_fireflies.z_index = 3
	(host if host != null else self).add_child(_fireflies)


func _on_night_changed(is_night: bool) -> void:
	if _fireflies != null:
		_fireflies.emitting = is_night
	for butterfly: Dictionary in _butterflies:
		var sprite := butterfly.get("sprite", null) as Sprite2D
		if sprite != null:
			sprite.visible = not is_night


func _clear_point() -> Vector2:
	var extent: Vector2 = Balance.AMBIENT_FIREFLY_FIELD_EXTENT * 0.82
	for attempt: int in 18:
		var point := Vector2(_rng.randf_range(-extent.x, extent.x),
			_rng.randf_range(-extent.y, extent.y))
		if _is_clear(point):
			return point
	return Vector2.INF


func _is_clear(point: Vector2) -> bool:
	if point.length() < Balance.TOWN_RADIUS + Balance.FOLIAGE_TOWN_MARGIN:
		return false
	if grid == null:
		return true
	var tile: Vector2i = BattleGrid.world_to_tile(point)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var cell: int = grid.cell_at(tile + Vector2i(dx, dy))
			if cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN:
				return false
	return true
