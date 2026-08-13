class_name Foliage
extends Node2D

## Scattered plants that sway, placed procedurally per terrain.
##
## Two rules make scattered decoration read as a place rather than as confetti:
##
## 1. **Nothing lands where the game happens.** Lanes, build spots and the town
##    are exclusion zones. Decoration that overlaps a road makes the road look
##    like a mistake, and decoration under a tower makes the tower hard to click.
##
## 2. **Nothing is identical.** Every clump varies in size, tint, lean and sway
##    phase, so a hundred instances of three shapes still look like undergrowth.
##
## The shapes are polygons rather than art: three silhouettes per terrain, each
## built from the terrain's own palette, is enough at this scale and costs no
## asset. Real foliage art can replace `_build_clump` without touching placement.

## Per-terrain look: silhouette style and colour range.
const STYLES: Dictionary = {
	"ashfen": {
		"kind": "reed",
		"dark": Color(0.20, 0.26, 0.18),
		"light": Color(0.42, 0.46, 0.26),
	},
	"saltglass": {
		"kind": "shard",
		"dark": Color(0.42, 0.50, 0.56),
		"light": Color(0.72, 0.80, 0.86),
	},
	"steppe": {
		"kind": "tuft",
		"dark": Color(0.34, 0.26, 0.16),
		"light": Color(0.56, 0.46, 0.26),
	},
}

var _clumps: Array[Node2D] = []
var _clump_phases: Array[float] = []
var _clump_rates: Array[float] = []
var _clump_amounts: Array[float] = []

## Held apart from the clumps because they must not sway: a shadow that swings
## with the plant above it reads as the ground moving.
var _shadows: Array[Node2D] = []
var _phase: float = 0.0
var _update_left: float = 0.0

## The density this scatter was built at, so a re-scatter only happens on change.
var _scattered_at: float = -1.0


func _ready() -> void:
	scatter()
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: scatter())


## Rebuilds the whole scatter for the current terrain.
func scatter() -> void:
	for node: Node2D in _clumps + _shadows:
		if is_instance_valid(node):
			node.queue_free()
	_clumps.clear()
	_shadows.clear()
	_clump_phases.clear()
	_clump_rates.clear()
	_clump_amounts.clear()

	var style: Dictionary = STYLES.get(RunState.terrain_id, STYLES["ashfen"])
	var rng := RandomNumberGenerator.new()
	# Seeded per terrain, so a given act always looks the same rather than
	# reshuffling every time the scope is entered.
	rng.seed = hash(RunState.terrain_id)

	# Scaled at scatter time, not culled afterwards: four hundred clumps that are
	# never created cost nothing, whereas four hundred hidden ones still sit in the
	# tree and still get walked every frame by the wind.
	_scattered_at = Graphics.foliage_scale()
	var wanted: int = Graphics.scaled(Balance.FOLIAGE_COUNT, _scattered_at)
	var placed: int = 0
	var attempts: int = 0
	while placed < wanted and attempts < wanted * 12:
		attempts += 1
		var point: Vector2 = _random_point(rng)
		if not _is_clear(point):
			continue
		# Ground cover first, tall growth on top. Two heights is the difference
		# between undergrowth and a field of identical weeds.
		var ground: bool = rng.randf() < Balance.FOLIAGE_GROUND_RATIO
		_clumps.append(_build_clump(point, style, rng, ground))
		placed += 1


## Uniform over the disc. Sampling radius linearly would bunch everything at the
## centre, which is exactly where the town is.
## Re-scatters if the density setting moved.
##
## Guarded because this is called on every quality change and a full re-scatter
## of six hundred clumps is not something to do because the frame cap moved.
func refresh_quality() -> void:
	if is_equal_approx(_scattered_at, Graphics.foliage_scale()):
		return
	scatter()


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	var radius: float = sqrt(rng.randf()) * Balance.LANE_SPAWN_RADIUS * 1.15
	return Vector2.RIGHT.rotated(rng.randf() * TAU) * radius


## Keeps plants off the roads, the build spots and the town.
func _is_clear(point: Vector2) -> bool:
	if point.length() < Balance.TOWN_RADIUS + Balance.FOLIAGE_TOWN_MARGIN:
		return false

	for lane: int in Balance.LANE_COUNT:
		var direction: Vector2 = Battlefield.lane_vector(lane)
		# Distance from the lane's centre line, but only along the stretch the
		# road actually occupies - beyond the spawn point there is no road to
		# avoid.
		var along: float = point.dot(direction)
		if along > 0.0 and along < Balance.LANE_SPAWN_RADIUS:
			var across: float = absf(point.dot(direction.orthogonal()))
			if across < Balance.LANE_WIDTH * Balance.FOLIAGE_LANE_CLEARANCE:
				return false

		for slot: int in Balance.TOWER_SLOT_RADII.size():
			if point.distance_to(Battlefield.slot_position(lane, slot)) < Balance.FOLIAGE_SLOT_MARGIN:
				return false
	return true


func _build_clump(at: Vector2, style: Dictionary, rng: RandomNumberGenerator, ground: bool) -> Node2D:
	var clump := FoliageClump.new()
	clump.position = at
	# Sorted with everything else, so a plant in front of the hero occludes and
	# one behind does not.
	clump.y_sort_enabled = false
	add_child(clump)

	var scale: float = rng.randf_range(Balance.FOLIAGE_MIN_SCALE, Balance.FOLIAGE_MAX_SCALE)
	if ground:
		scale *= Balance.FOLIAGE_GROUND_SCALE
	var blades: int = rng.randi_range(5, 9) if ground else rng.randi_range(3, 6)
	clump.configure(_clump_shape(String(style["kind"]), rng, blades, ground),
		(style["dark"] as Color).lerp(style["light"] as Color, rng.randf()), scale)

	# Only the tall layer gets a shadow. Ground cover is already a few pixels
	# high, so a pool under it reads as dirt rather than as shade — and there are
	# two hundred and fifty of them, which is a lot of quads for nothing.
	if not ground:
		_add_shadow(clump, scale)

	_clump_phases.append(rng.randf() * TAU)
	# Low cover barely moves; tall growth catches the wind. Uniform sway across
	# both layers is what makes procedural foliage look like it is breathing in
	# unison rather than growing in a real place.
	var sway: float = rng.randf_range(0.6, 1.4)
	_clump_rates.append(sway * (Balance.FOLIAGE_GROUND_SWAY if ground else 1.0))
	_clump_amounts.append(Balance.FOLIAGE_GROUND_SWAY if ground else 1.0)
	return clump


## A shadow for a clump, which has no sprite to measure — so it is built by hand
## against the same shared material every other shadow on the field uses.
func _add_shadow(clump: Node2D, scale: float) -> void:
	# Built by hand rather than through ShadowKit.add_contact, which measures a
	# sprite this has none of - so the quality switch has to be checked here too.
	# Missing it meant Low reported "ground shadows off" and still drew fifty of
	# them, which is a setting that lies.
	var shadow := Sprite2D.new()
	shadow.name = "ContactShadow"
	shadow.texture = ShadowKit.quad_texture()
	shadow.material = ShadowKit.material()
	shadow.scale = Vector2.ONE * (34.0 * scale / float(ShadowKit.quad_texture().width))
	shadow.z_index = -1
	shadow.z_as_relative = true
	shadow.position = clump.position
	shadow.add_to_group(ShadowKit.GROUP)
	shadow.visible = Graphics.contact_shadows()
	add_child(shadow)
	_shadows.append(shadow)


func _blade_shape(kind: String, rng: RandomNumberGenerator) -> PackedVector2Array:
	var height: float = rng.randf_range(16.0, 30.0)
	match kind:
		"shard":
			return PackedVector2Array([
				Vector2(-3.0, 0.0), Vector2(3.0, 0.0),
				Vector2(rng.randf_range(-2.0, 2.0), -height)])
		"tuft":
			return PackedVector2Array([
				Vector2(-4.0, 0.0), Vector2(4.0, 0.0),
				Vector2(2.0, -height * 0.7), Vector2(0.0, -height),
				Vector2(-2.0, -height * 0.7)])
		_:
			return PackedVector2Array([
				Vector2(-2.0, 0.0), Vector2(2.0, 0.0),
				Vector2(rng.randf_range(1.0, 5.0), -height)])


## One coherent silhouette per plant. Closely packed blade polygons were being
## submitted as five to nine separate draws even though the player reads them
## as one clump at battlefield scale. This jagged upper contour retains each
## terrain's species language and variation in a single cached draw.
func _clump_shape(kind: String, rng: RandomNumberGenerator, blades: int,
		ground: bool) -> PackedVector2Array:
	var half_span: float = 18.0 if ground else 13.0
	var points := PackedVector2Array([Vector2(-half_span, 1.5)])
	var spacing: float = (half_span * 2.0) / float(blades)
	var blade_half: float = spacing * 0.46
	for index: int in blades:
		var x: float = -half_span + spacing * (float(index) + 0.5)
		var height: float = rng.randf_range(13.0, 23.0) if ground \
			else rng.randf_range(19.0, 34.0)
		var lean: float = rng.randf_range(-2.6, 2.6)
		match kind:
			"shard":
				lean *= 0.45
			"tuft":
				height *= 0.88
			_:
				lean += rng.randf_range(0.8, 2.8)
		# Strictly increasing x makes this contour simple and guarantees Godot's
		# triangulator never sees crossing edges, even on a nine-blade clump.
		var left_x: float = x - blade_half
		var right_x: float = x + blade_half
		var tip_x: float = clampf(x + lean, left_x + 0.05, right_x - 0.05)
		points.append(Vector2(left_x, rng.randf_range(-1.5, 0.5)))
		points.append(Vector2(tip_x, -height))
		points.append(Vector2(right_x, rng.randf_range(-1.5, 0.5)))
	points.append(Vector2(half_span, 1.5))
	return points


## Everything leans on the same wind, each clump at its own phase and rate, so
## the field moves as one thing without any two plants moving alike.
func _process(delta: float) -> void:
	_phase += delta * Balance.FOLIAGE_SWAY_SPEED
	_update_left -= delta
	if _update_left > 0.0:
		return
	_update_left += Balance.FOLIAGE_UPDATE_INTERVAL
	var gust: float = 0.6 + 0.4 * sin(_phase * 0.23)
	for index: int in _clumps.size():
		var clump: Node2D = _clumps[index]
		if not is_instance_valid(clump):
			continue
		var phase: float = _clump_phases[index]
		var rate: float = _clump_rates[index]
		var amount: float = _clump_amounts[index]
		# A gust term on top of the base sway: the whole field leans together
		# every few seconds, which is what sells wind rather than fidgeting.
		clump.rotation = sin(_phase * rate + phase) \
			* deg_to_rad(Balance.FOLIAGE_SWAY_DEGREES) * amount * gust


## One cached CanvasItem per clump instead of one Polygon2D node per blade.
## Godot records these draw commands until the clump changes; swaying its parent
## transform therefore moves the whole plant without rebuilding any geometry.
## This preserves the exact procedural silhouettes while removing thousands of
## independently managed scene nodes from the authored High battlefield.
class FoliageClump extends Node2D:
	var _silhouette: PackedVector2Array = []
	var _colour: Color = Color.WHITE

	func configure(shape: PackedVector2Array, colour: Color, clump_scale: float) -> void:
		_silhouette = shape
		_colour = colour
		scale = Vector2.ONE * clump_scale
		queue_redraw()

	func _draw() -> void:
		if not _silhouette.is_empty():
			draw_colored_polygon(_silhouette, _colour)
