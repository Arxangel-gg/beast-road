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
var _phase: float = 0.0


func _ready() -> void:
	scatter()
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: scatter())


## Rebuilds the whole scatter for the current terrain.
func scatter() -> void:
	for clump: Node2D in _clumps:
		if is_instance_valid(clump):
			clump.queue_free()
	_clumps.clear()

	var style: Dictionary = STYLES.get(RunState.terrain_id, STYLES["ashfen"])
	var rng := RandomNumberGenerator.new()
	# Seeded per terrain, so a given act always looks the same rather than
	# reshuffling every time the scope is entered.
	rng.seed = hash(RunState.terrain_id)

	var placed: int = 0
	var attempts: int = 0
	while placed < Balance.FOLIAGE_COUNT and attempts < Balance.FOLIAGE_COUNT * 12:
		attempts += 1
		var point: Vector2 = _random_point(rng)
		if not _is_clear(point):
			continue
		_clumps.append(_build_clump(point, style, rng))
		placed += 1


## Uniform over the disc. Sampling radius linearly would bunch everything at the
## centre, which is exactly where the town is.
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


func _build_clump(at: Vector2, style: Dictionary, rng: RandomNumberGenerator) -> Node2D:
	var clump := Node2D.new()
	clump.position = at
	# Sorted with everything else, so a plant in front of the hero occludes and
	# one behind does not.
	clump.y_sort_enabled = false
	add_child(clump)

	var scale: float = rng.randf_range(Balance.FOLIAGE_MIN_SCALE, Balance.FOLIAGE_MAX_SCALE)
	var blades: int = rng.randi_range(3, 6)
	for i: int in blades:
		var blade := Polygon2D.new()
		blade.polygon = _blade_shape(String(style["kind"]), rng)
		blade.color = (style["dark"] as Color).lerp(style["light"] as Color, rng.randf())
		blade.position = Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-4.0, 4.0))
		blade.scale = Vector2.ONE * scale * rng.randf_range(0.8, 1.2)
		blade.rotation = rng.randf_range(-0.18, 0.18)
		clump.add_child(blade)

	clump.set_meta("phase", rng.randf() * TAU)
	clump.set_meta("sway", rng.randf_range(0.6, 1.4))
	return clump


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


## Everything leans on the same wind, each clump at its own phase and rate, so
## the field moves as one thing without any two plants moving alike.
func _process(delta: float) -> void:
	_phase += delta * Balance.FOLIAGE_SWAY_SPEED
	for clump: Node2D in _clumps:
		if not is_instance_valid(clump):
			continue
		var phase: float = float(clump.get_meta("phase", 0.0))
		var rate: float = float(clump.get_meta("sway", 1.0))
		clump.rotation = sin(_phase * rate + phase) * deg_to_rad(Balance.FOLIAGE_SWAY_DEGREES)
