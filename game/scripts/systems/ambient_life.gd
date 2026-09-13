class_name AmbientLife
extends Node2D

## Small, non-interactive life in the battlefield margins.
##
## This system has no EventBus gameplay messages, collision, groups, health or
## network ids by design. Fireflies and butterflies are each client's local
## dressing; losing or gaining one can never change a seeded run.

const BUTTERFLY_FRAME_FORMAT: String = "res://art/foliage/butterfly_fly_%02d.png"
const BUTTERFLY_SIDE_FRAME_FORMAT: String = "res://art/foliage/butterfly_side_%02d.png"
const BUTTERFLY_IDLE_PATH: String = "res://art/foliage/butterfly_idle_01.png"
const MAX_BUTTERFLY_FRAMES: int = 12

var grid: BattleGrid = null
var host: Node2D = null

var _butterflies: Array[Dictionary] = []
var _butterfly_frames: Array[Texture2D] = []
var _butterfly_side_frames: Array[Texture2D] = []
var _butterfly_idle: Texture2D = null
var _fireflies: Node2D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash("ambient-life:%s:%d" % [RunState.terrain_id, RunState.run_seed])
	_butterfly_frames = _frame_series(BUTTERFLY_FRAME_FORMAT)
	_butterfly_side_frames = _frame_series(BUTTERFLY_SIDE_FRAME_FORMAT)
	if ResourceLoader.exists(BUTTERFLY_IDLE_PATH):
		_butterfly_idle = load(BUTTERFLY_IDLE_PATH) as Texture2D
	_build_butterflies()
	_build_fireflies()
	DayNight.night_changed.connect(_on_night_changed)
	_on_night_changed(DayNight.is_night())


func _exit_tree() -> void:
	for butterfly: Dictionary in _butterflies:
		# The shadow is a sibling rather than a child, so it is not carried off
		# by freeing the butterfly and has to be let go of here.
		var shadow := butterfly.get("shadow", null) as Sprite2D
		if shadow != null and is_instance_valid(shadow):
			shadow.queue_free()
		var sprite := butterfly.get("sprite", null) as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_butterflies.clear()
	if _fireflies != null and is_instance_valid(_fireflies):
		_fireflies.queue_free()


func _process(delta: float) -> void:
	for butterfly: Dictionary in _butterflies:
		_tick_butterfly(butterfly, delta)
		# **After the tick, never inside it.** The tick moves the butterfly and
		# returns early when it is perched, so a shadow placed at the top of it
		# sat where the butterfly had been on the previous frame - measured as
		# a shadow trailing a flying butterfly by about a pixel.
		_place_shadow(butterfly, butterfly.get("sprite", null) as Sprite2D)


func _frame_series(format: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for index: int in range(1, MAX_BUTTERFLY_FRAMES + 1):
		var path: String = format % index
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


## The shadow stays on the ground the butterfly is over, and shrinks and fades
## as it climbs.
##
## The vertical gap is not set here and never could be: the sprite is drawn
## `offset.y` above its own ground point and the shadow sits *at* that point, so
## the distance between them is the altitude by construction. A perched
## butterfly is two pixels up and all but touching its shadow; a flying one is
## twenty-eight up and clearly separated, and it eases between the two because
## the offset does.
func _place_shadow(butterfly: Dictionary, sprite: Sprite2D) -> void:
	var shadow := butterfly.get("shadow", null) as Sprite2D
	if shadow == null or not is_instance_valid(shadow):
		return
	if sprite == null or not is_instance_valid(sprite):
		return
	shadow.position = sprite.position
	var lift: float = -sprite.offset.y
	var climb: float = clampf(inverse_lerp(Balance.AMBIENT_BUTTERFLY_PERCH_LIFT,
		Balance.AMBIENT_BUTTERFLY_LIFT, lift), 0.0, 1.0)
	var base: Vector2 = butterfly.get("shadow_scale", Vector2.ONE)
	shadow.scale = base * lerpf(Balance.AMBIENT_BUTTERFLY_SHADOW_SCALE.x,
		Balance.AMBIENT_BUTTERFLY_SHADOW_SCALE.y, climb)
	shadow.modulate.a = lerpf(Balance.AMBIENT_BUTTERFLY_SHADOW_ALPHA.x,
		Balance.AMBIENT_BUTTERFLY_SHADOW_ALPHA.y, climb)


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
		var visual_scale: float = _rng.randf_range(0.42, 0.68)
		sprite.scale = Vector2.ONE * visual_scale
		var parent: Node = host if host != null else self
		parent.add_child(sprite)
		# **A sibling, not a child of the butterfly.** `offset` moves only the
		# drawn texture, so a shadow parented to the sprite would already sit on
		# the ground - but it would also inherit the perched breathing squash,
		# which would have the shadow swelling and pinching in time with the
		# wings. Held beside it and moved by hand instead.
		var shadow: Sprite2D = ShadowKit.add_contact_sized(parent,
			Balance.AMBIENT_BUTTERFLY_SHADOW_WIDTH * visual_scale, 0.0)
		if shadow != null:
			shadow.position = at
		var angle: float = _rng.randf() * TAU
		_butterflies.append({
			"sprite": sprite,
			"shadow": shadow,
			"shadow_scale": shadow.scale if shadow != null else Vector2.ONE,
			"home": at,
			"goal": at + Vector2.RIGHT.rotated(angle) * Balance.AMBIENT_BUTTERFLY_ROAM,
			"heading": Vector2.RIGHT.rotated(angle),
			"speed": _rng.randf_range(Balance.AMBIENT_BUTTERFLY_SPEED.x,
				Balance.AMBIENT_BUTTERFLY_SPEED.y),
			"phase": _rng.randf() * TAU,
			"frame": _rng.randf() * float(_butterfly_frames.size()),
			"scale": visual_scale,
			"rest": 0.0,
			"swerve": _rng.randf_range(-1.0, 1.0),
			"swerve_left": _rng.randf_range(Balance.AMBIENT_BUTTERFLY_SWERVE_TIME.x,
				Balance.AMBIENT_BUTTERFLY_SWERVE_TIME.y),
		})


func _tick_butterfly(butterfly: Dictionary, delta: float) -> void:
	var sprite := butterfly["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	butterfly["phase"] = float(butterfly["phase"]) + delta * 2.1
	var visual_scale: float = float(butterfly["scale"])
	var rest: float = maxf(float(butterfly["rest"]) - delta, 0.0)
	butterfly["rest"] = rest
	if rest > 0.0:
		# Side-on with a tiny breathing wing motion: a butterfly at rest is perched,
		# not a top-down sprite frozen in mid-flight.
		var resting_frames: Array[Texture2D] = _butterfly_side_frames \
			if not _butterfly_side_frames.is_empty() else _butterfly_frames
		sprite.texture = _butterfly_idle if _butterfly_idle != null else resting_frames[0]
		sprite.offset.y = move_toward(sprite.offset.y,
			-Balance.AMBIENT_BUTTERFLY_PERCH_LIFT, delta * 28.0)
		sprite.rotation = sin(float(butterfly["phase"]) * 0.38) * 0.025
		sprite.flip_h = (butterfly["heading"] as Vector2).x < 0.0
		var breathe: float = sin(float(butterfly["phase"]) * 0.72) * 0.035
		sprite.scale = Vector2(visual_scale * (1.0 + breathe),
			visual_scale * (1.0 - breathe * 0.55))
		return

	butterfly["frame"] = float(butterfly["frame"]) \
		+ delta * Balance.AMBIENT_BUTTERFLY_FRAME_RATE
	sprite.offset.y = move_toward(sprite.offset.y, -Balance.AMBIENT_BUTTERFLY_LIFT,
		delta * 34.0)
	sprite.scale = Vector2.ONE * visual_scale

	var toward: Vector2 = (butterfly["goal"] as Vector2) - sprite.position
	if toward.length() < 28.0:
		if _rng.randf() < Balance.AMBIENT_BUTTERFLY_LAND_CHANCE:
			butterfly["rest"] = _rng.randf_range(Balance.AMBIENT_BUTTERFLY_REST.x,
				Balance.AMBIENT_BUTTERFLY_REST.y)
			return
		var home: Vector2 = butterfly["home"] as Vector2
		var roll: Vector2 = Vector2.RIGHT.rotated(_rng.randf() * TAU) \
			* _rng.randf_range(Balance.AMBIENT_BUTTERFLY_ROAM * 0.35,
				Balance.AMBIENT_BUTTERFLY_ROAM)
		var wanted: Vector2 = home + roll
		butterfly["goal"] = wanted if _is_clear(wanted) else home
		toward = (butterfly["goal"] as Vector2) - sprite.position
	var wanted_heading: Vector2 = toward.normalized() if not toward.is_zero_approx() \
		else butterfly["heading"] as Vector2
	butterfly["swerve_left"] = float(butterfly["swerve_left"]) - delta
	if float(butterfly["swerve_left"]) <= 0.0:
		butterfly["swerve_left"] = _rng.randf_range(Balance.AMBIENT_BUTTERFLY_SWERVE_TIME.x,
			Balance.AMBIENT_BUTTERFLY_SWERVE_TIME.y)
		butterfly["swerve"] = _rng.randf_range(-1.0, 1.0)
	wanted_heading += wanted_heading.orthogonal() \
		* (sin(float(butterfly["phase"])) * 0.34 \
			+ float(butterfly["swerve"]) * Balance.AMBIENT_BUTTERFLY_SWERVE)
	var heading: Vector2 = (butterfly["heading"] as Vector2).lerp(
		wanted_heading.normalized(), clampf(delta * Balance.AMBIENT_BUTTERFLY_TURN, 0.0, 1.0))
	butterfly["heading"] = heading.normalized()
	sprite.position += (butterfly["heading"] as Vector2) \
		* float(butterfly["speed"]) * delta
	var travel: Vector2 = butterfly["heading"] as Vector2
	# **Every flight frame is a top view, including the ones called "side".**
	# The side sheet is a butterfly seen from above at an angle, not in
	# profile, so the old branch that swapped to it for horizontal travel
	# left the sprite pointing north while it flew east - the 90 degrees
	# reported on 2026-09-13. The side frames keep their job as the perched
	# pose and no longer steer.
	var frames: Array[Texture2D] = _butterfly_frames
	var frame: int = int(floor(float(butterfly["frame"]))) % frames.size()
	sprite.texture = frames[frame]
	# The source faces north. Rotate that north vector onto travel; this is
	# orientation, not decorative sway, so it stays correct through every turn.
	sprite.flip_h = false
	sprite.rotation = travel.angle() + PI * 0.5


func _build_fireflies() -> void:
	_fireflies = Node2D.new()
	_fireflies.name = "NightFireflies"
	(host if host != null else self).add_child(_fireflies)
	var total: int = Graphics.scaled(Balance.AMBIENT_FIREFLY_AMOUNT,
		Graphics.foliage_scale())
	var cluster_count: int = maxi(Balance.AMBIENT_FIREFLY_CLUSTER_COUNT, 1)
	var tree_clusters: int = int(round(float(cluster_count) * Balance.AMBIENT_FIREFLY_TREE_BIAS))
	var trees: Array[Node] = get_tree().get_nodes_in_group("ambient_tree")
	for index: int in cluster_count:
		var at: Vector2 = _clear_point()
		if index < tree_clusters and not trees.is_empty():
			var tree := trees[_rng.randi_range(0, trees.size() - 1)] as Node2D
			if tree != null:
				at = tree.global_position + Vector2(_rng.randf_range(-90.0, 90.0),
					_rng.randf_range(-55.0, 75.0))
		if at == Vector2.INF:
			continue
		_build_firefly_cluster(at, maxi(int(ceil(float(total) / float(cluster_count))), 1))


func _build_firefly_cluster(at: Vector2, amount: int) -> void:
	var cluster := CPUParticles2D.new()
	cluster.name = "FireflyCluster"
	cluster.position = at
	cluster.texture = Flame.dot_texture()
	cluster.amount = amount
	cluster.lifetime = Balance.AMBIENT_FIREFLY_LIFETIME
	cluster.lifetime_randomness = 0.55
	cluster.preprocess = Balance.AMBIENT_FIREFLY_LIFETIME
	cluster.local_coords = true
	cluster.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	cluster.emission_rect_extents = Balance.AMBIENT_FIREFLY_CLUSTER_EXTENT
	cluster.direction = Vector2.UP
	cluster.spread = 180.0
	cluster.initial_velocity_min = Balance.AMBIENT_FIREFLY_SPEED * 0.35
	cluster.initial_velocity_max = Balance.AMBIENT_FIREFLY_SPEED
	cluster.gravity = Vector2(0.8, -1.2)
	cluster.scale_amount_min = Balance.AMBIENT_FIREFLY_SIZE * 0.55
	cluster.scale_amount_max = Balance.AMBIENT_FIREFLY_SIZE
	var twinkle := Curve.new()
	twinkle.add_point(Vector2(0.0, 0.0))
	twinkle.add_point(Vector2(0.18, 1.0))
	twinkle.add_point(Vector2(0.48, 0.25))
	twinkle.add_point(Vector2(0.72, 1.0))
	twinkle.add_point(Vector2(1.0, 0.0))
	cluster.scale_amount_curve = twinkle
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.20, 0.72, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.70, 1.0, 0.38, 0.0), Color(0.88, 1.0, 0.48, 0.92),
		Color(1.0, 0.83, 0.31, 0.78), Color(0.64, 0.94, 0.38, 0.0),
	])
	cluster.color_ramp = ramp
	cluster.z_index = 3
	_fireflies.add_child(cluster)


func _on_night_changed(is_night: bool) -> void:
	if _fireflies != null:
		for child: Node in _fireflies.get_children():
			var cluster := child as CPUParticles2D
			if cluster != null:
				cluster.emitting = is_night
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
