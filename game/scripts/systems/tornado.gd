class_name Tornado
extends Node2D

## A funnel that walks the field: it flattens what it passes over and batters
## what stands near.
##
## Owner brief, 2026-09-14. Raised by the earth's wrath, or by the storm towers
## themselves once they have run long enough (`RunState.gale`). It is born at
## the field's edge, heads for a point inside and wanders as it goes, and dies
## after its seconds are spent or once it has walked off the far side. In its
## wake - `TORNADO_WAKE` - a tower is torn down and a body is thrown and hurt
## hard; out to `TORNADO_AOE` everything alive is hurt a little and pushed.
##
## Drawn rather than painted: a stack of turning ellipses narrowing to the
## ground, dust at the foot, debris climbing it. Nothing here needs a shader,
## which is why it can be looked at headless. The host moves it and hurts with
## it; a guest is told where it is (`coop_tornado_moved`) and draws it there.

const GROUP: StringName = &"tornadoes"

var at: Vector2 = Vector2.ZERO
var heading: Vector2 = Vector2.RIGHT
var seconds_left: float = 0.0
var field: Battlefield = null
var _rng: RandomNumberGenerator = null
var _mirror: bool = false
var _spin: float = 0.0
var _sync_timer: float = 0.0
var _dust_timer: float = 0.0
var _howl_timer: float = 0.0
var _debris: CPUParticles2D = null
var _target: Vector2 = Vector2.ZERO
## For the gate: what it has torn down and hurt.
var towers_felled: int = 0
## How far it wanders off its line each second. A seam for the gate, which
## needs a funnel that walks over the tower it was aimed at.
var wander: float = Balance.TORNADO_WANDER
## A fire whirl: seconds left carrying fire, after crossing a wildfire.
var _fire_left: float = 0.0
var _ignite_timer: float = 0.0


func _ready() -> void:
	name = "Tornado"
	add_to_group(GROUP)
	z_as_relative = false
	z_index = Balance.TORNADO_Z
	position = at
	_rng = RunState.rng("wrath")
	_mirror = Coop.is_guest()
	_build_debris()
	EventBus.coop_tornado_moved.connect(_on_moved_elsewhere)


func _build_debris() -> void:
	_debris = CPUParticles2D.new()
	_debris.name = "Debris"
	_debris.texture = Flame.dot_texture()
	_debris.amount = Graphics.scaled(48, Graphics.particle_scale())
	_debris.lifetime = 1.4
	_debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_debris.emission_sphere_radius = Balance.TORNADO_WAKE * 0.6
	_debris.direction = Vector2.UP
	_debris.spread = 40.0
	_debris.initial_velocity_min = 120.0
	_debris.initial_velocity_max = 320.0
	_debris.gravity = Vector2(0.0, 90.0)
	_debris.scale_amount_min = 1.2
	_debris.scale_amount_max = 3.2
	_debris.color = Color(0.36, 0.3, 0.24, 0.85)
	_debris.local_coords = false
	add_child(_debris)


func _process_measured(delta: float) -> void:
	_spin += delta * Balance.TORNADO_SPIN
	queue_redraw()
	if _mirror:
		return
	seconds_left -= delta
	# Wandering toward its point, then past it: the heading turns a little
	# every frame, so the path is a curve nobody can stand in the way of by
	# reading a straight line.
	var wanted: Vector2 = (_target - at).normalized() if at.distance_to(_target) > 40.0 else heading
	heading = (heading.lerp(wanted, minf(delta * 1.4, 1.0)).rotated(
		_rng.randf_range(-1.0, 1.0) * wander * delta)
		+ RunState.wind * Balance.TORNADO_WIND_PUSH * delta).normalized()
	at += heading * Balance.TORNADO_SPEED * delta
	position = at
	_tick_fire(delta)
	_hurt(delta)
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = 0.28
		Vfx.dust(at, Color(0.42, 0.36, 0.28), 5, Balance.TORNADO_WAKE)
		# **The debris caught in it**, on the wake's own clock. The sheet is
		# the one looping effect in the catalogue - it comes back round to
		# where it started - which is what lets it be played over and over
		# while the funnel stands rather than reading as a repeated blow.
		# Upright, because a funnel lying on its side is not a funnel.
		Vfx.forge_play("funnel_debris", at, Balance.TORNADO_AOE * 1.6,
			Color(0.78, 0.7, 0.58, 0.8))
	_howl_timer -= delta
	if _howl_timer <= 0.0:
		_howl_timer = 2.4
		Sfx.play("sfx_tornado", -4.0)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = Balance.SKY_SYNC_INTERVAL
		if Coop.is_host() and Coop.partner_present():
			EventBus.tornado_moved.emit(at, burning())
	var reach: float = BattleGrid.HALF_EXTENT + Balance.TREELINE_RING
	if seconds_left <= 0.0 or absf(at.x) > reach or absf(at.y) > reach:
		_die()


## Where it is heading first. Set by the sky before it enters the tree.
func aim_at(target: Vector2) -> void:
	_target = target
	heading = (target - at).normalized()


## Whether it carries fire right now.
func burning() -> bool:
	return _fire_left > 0.0


## A funnel through a fire carries it (ChatGPT notes, 2026-09-14: "Wildfire +
## Tornado -> Fire Tornado"): for a while after crossing burning ground it
## lights the brush in its wake and burns what it touches. It re-arms only
## from a fresh crossing - the fires it lit itself fall behind it faster than
## they can keep it lit - and the wildfire's own bounds hold the rest.
func _tick_fire(delta: float) -> void:
	var fire: Wildfire = field.wildfire() if field != null else null
	if fire == null:
		return
	if _fire_left <= 0.0 and fire.heat_at(at, Balance.TORNADO_AOE) > 0.0:
		_fire_left = Balance.TORNADO_FIRE_SECONDS
		Vfx.flash_at(at, Color(1.0, 0.6, 0.25), Balance.TORNADO_AOE * 0.5)
		Vfx.spark(at, Color(1.0, 0.55, 0.2), 24, Vector2.UP, 360.0)
		if _debris != null:
			_debris.color = Color(1.0, 0.5, 0.18, 0.9)
	if _fire_left <= 0.0:
		return
	_fire_left -= delta
	if _fire_left <= 0.0 and _debris != null:
		_debris.color = Color(0.36, 0.3, 0.24, 0.85)
	_ignite_timer -= delta
	if _ignite_timer <= 0.0:
		_ignite_timer = Balance.TORNADO_FIRE_IGNITE_TICK
		var behind: Vector2 = at - heading * Balance.TORNADO_WAKE \
			+ Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * Balance.TORNADO_WAKE
		fire.ignite_near(behind, Balance.TORNADO_WAKE * 1.5, 1.0)


func _hurt(delta: float) -> void:
	if field == null:
		return
	var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_HP_SCALE.size() - 1)]
	var fire_more: float = Balance.TORNADO_FIRE_DPS if burning() else 0.0
	# Towers in the wake are torn down. Hard, and per second rather than at
	# once, so a funnel that clips a tower scars it and one that sits on it
	# breaks it.
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower == null or not is_instance_valid(tower) or not tower.is_vulnerable():
			continue
		if tower.global_position.distance_to(at) <= Balance.TORNADO_WAKE:
			var was: bool = tower.is_vulnerable()
			tower.hurt(Balance.TORNADO_TOWER_DPS * delta, at)
			if was and not tower.is_vulnerable():
				towers_felled += 1
	for enemy: Enemy in field.enemies_near(at, Balance.TORNADO_AOE):
		var away: float = enemy.global_position.distance_to(at)
		var inside: bool = away <= Balance.TORNADO_WAKE
		var amount: float = ((Balance.TORNADO_WAKE_DPS if inside else Balance.TORNADO_AOE_DPS) + fire_more) \
			* act_scale * delta
		enemy.take_damage(amount, at, 0.0)
	var hero_pool: float = 100.0
	if field.hero != null and field.hero.health != null:
		hero_pool = field.hero.health.max_hp
	EnemyGroundStrike.strike_the_players(get_tree(), hero_pool * Balance.TORNADO_HERO_SHARE_PER_SECOND * delta,
		"", func(where: Vector2) -> bool: return where.distance_to(at) <= Balance.TORNADO_AOE,
		Balance.TORNADO_PUSH * delta, at)
	var animals: Wildlife = field.wildlife()
	if animals != null:
		animals.wound_within(at, Balance.TORNADO_AOE, Balance.TORNADO_WILDLIFE_DPS * delta, false)
		animals.scare_from(at, Balance.TORNADO_AOE * 1.5)


func _on_moved_elsewhere(where: Vector2, is_burning: bool) -> void:
	if _mirror:
		at = where
		position = at
		_fire_left = Balance.TORNADO_FIRE_SECONDS if is_burning else 0.0
		if _debris != null:
			_debris.color = Color(1.0, 0.5, 0.18, 0.9) if is_burning else Color(0.36, 0.3, 0.24, 0.85)


func _die() -> void:
	Vfx.dust(at, Color(0.42, 0.36, 0.28), 14, Balance.TORNADO_AOE * 0.6)
	# Where it fell apart the air stays charged for a while.
	if not _mirror and field != null and field.zones() != null:
		field.zones().open("storm_core", at, Balance.ZONE_STORM_RADIUS)
	if _debris != null:
		_debris.emitting = false
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 1.2)
	fade.tween_callback(queue_free)
	set_process(false)


## The funnel: a column of dust that fades into the air at every edge, with
## debris winding up it and a pool of grit at its foot.
func _draw_measured() -> void:
	_draw_the_foot()
	_draw_the_column()
	_draw_the_streaks()


## How far out the funnel reaches at a height, and how far the column leans
## there. One function so the column, the streaks and the foot cannot disagree
## about where the funnel is.
func _reach_at(t: float) -> float:
	return lerpf(Balance.TORNADO_WAKE * 0.5, Balance.TORNADO_AOE * 0.9, t)


func _lean_at(t: float) -> float:
	return sin(_spin * 0.7 + t * 4.0) * _reach_at(t) * 0.18


## The dust of the funnel at a height and a place across it (-1 to 1).
func _dust_at(t: float, across: float) -> Color:
	# Dense through the middle, nothing at the silhouette: the shape has no
	# edge, which is the whole difference from a stack of flat ellipses.
	var solid: float = 1.0 - pow(absf(across), Balance.TORNADO_EDGE_FALLOFF)
	# Dense at the foot where the funnel is packed with what it has picked up,
	# thin at the top where it is only air. At 0.62 the first cut read as smoke
	# against dark ground rather than as a column of dirt.
	var alpha: float = lerpf(0.92, 0.2, t * t) * clampf(solid, 0.0, 1.0)
	if burning():
		# A fire whirl, lit from inside: hot and pale up the core, darker
		# toward the edges where there is only smoke.
		var heat: float = clampf(solid * 1.25, 0.0, 1.0)
		return Color(lerpf(0.55, 1.0, heat), lerpf(0.16, lerpf(0.5, 0.82, t), heat),
			lerpf(0.08, lerpf(0.1, 0.34, t), heat), alpha * 1.2)
	# Thin dust at the edge catches more light than the packed core does.
	var shade: float = lerpf(0.58, 0.19, clampf(solid, 0.0, 1.0)) + t * 0.16
	return Color(shade, shade * 0.93, shade * 0.82, alpha)


func _draw_the_column() -> void:
	var rings: int = Balance.TORNADO_RINGS
	var columns: int = Balance.TORNADO_COLUMNS
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for ring: int in rings:
		var t: float = float(ring) / float(rings - 1)
		var reach: float = _reach_at(t)
		var lean: float = _lean_at(t)
		var height: float = -Balance.TORNADO_HEIGHT * t
		for column: int in columns:
			var across: float = lerpf(-1.0, 1.0, float(column) / float(columns - 1))
			# The rim of a ring sits a little lower than its middle: the far
			# side of a circle seen from above and slightly along.
			var dip: float = (1.0 - absf(across)) * reach * 0.2
			points.append(Vector2(lean + across * reach, height + dip))
			colours.append(_dust_at(t, across))
	var indices := PackedInt32Array()
	for ring: int in rings - 1:
		for column: int in columns - 1:
			var a: int = ring * columns + column
			indices.append_array([a, a + 1, a + columns,
				a + 1, a + columns + 1, a + columns])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## **Debris going round.** Six strands winding up the funnel, each tapering to
## nothing at both ends and fading as it passes behind the column, so the thing
## reads as turning. Built into one mesh rather than drawn strand by strand.
func _draw_the_streaks() -> void:
	var rings: int = Balance.TORNADO_RINGS
	var half: float = Balance.TORNADO_STREAK_WIDTH * 0.5
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var lit: bool = burning()
	for strand: int in Balance.TORNADO_STREAKS:
		var phase: float = TAU * float(strand) / float(Balance.TORNADO_STREAKS) + _spin * 1.6
		var first: int = points.size()
		for ring: int in rings:
			var t: float = float(ring) / float(rings - 1)
			var angle: float = phase + t * TAU * Balance.TORNADO_STREAK_TURNS
			var reach: float = _reach_at(t)
			var here := Vector2(_lean_at(t) + cos(angle) * reach * 0.86,
				-Balance.TORNADO_HEIGHT * t + sin(angle) * reach * 0.2)
			points.append(here + Vector2(0.0, -half))
			points.append(here + Vector2(0.0, half))
			# Bright as it comes round the near side, gone behind the column,
			# and tapering away at the top and the foot.
			var facing: float = clampf(sin(angle) * 0.5 + 0.5, 0.0, 1.0)
			var ends: float = sin(t * PI)
			var alpha: float = facing * ends * lerpf(0.55, 0.22, t)
			var grit: Color = Color(1.0, 0.72, 0.36, alpha * 1.4) if lit \
				else Color(0.74, 0.69, 0.58, alpha)
			colours.append(grit)
			colours.append(grit)
			if ring > 0:
				var a: int = first + (ring - 1) * 2
				indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## The grit at the foot: a pool that is thickest at its rim, where the funnel is
## throwing the ground outward, and clear in the middle where the funnel stands.
func _draw_the_foot() -> void:
	var steps: int = 20
	var reach: float = Balance.TORNADO_WAKE * (0.95 + sin(_spin * 2.1) * 0.06)
	var lit: bool = burning()
	var middle: Color = Color(0.62, 0.26, 0.09, 0.42) if lit else Color(0.22, 0.19, 0.15, 0.36)
	var rim: Color = Color(0.9, 0.46, 0.16, 0.0) if lit else Color(0.5, 0.45, 0.37, 0.0)
	var edge: Color = Color(0.86, 0.42, 0.14, 0.5) if lit else Color(0.46, 0.41, 0.34, 0.44)
	var points := PackedVector2Array([Vector2.ZERO])
	var colours := PackedColorArray([middle])
	for band: int in 2:
		for s: int in steps:
			var angle: float = TAU * float(s) / float(steps) + _spin * 0.4
			var out: float = reach * (0.66 if band == 0 else 1.0)
			points.append(Vector2(cos(angle), sin(angle) * 0.36) * out)
			colours.append(edge if band == 0 else rim)
	var indices := PackedInt32Array()
	for s: int in steps:
		var inner: int = 1 + s
		var next_inner: int = 1 + (s + 1) % steps
		indices.append_array([0, inner, next_inner])
		var outer: int = 1 + steps + s
		var next_outer: int = 1 + steps + (s + 1) % steps
		indices.append_array([inner, outer, next_inner, outer, next_outer, next_inner])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## `FrameProfile` bucket "d_tornado": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_tornado", started)


## `FrameProfile` bucket "p_tornado": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_tornado", started)
