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


func _process(delta: float) -> void:
	_spin += delta * Balance.TORNADO_SPIN
	queue_redraw()
	if _mirror:
		return
	seconds_left -= delta
	# Wandering toward its point, then past it: the heading turns a little
	# every frame, so the path is a curve nobody can stand in the way of by
	# reading a straight line.
	var wanted: Vector2 = (_target - at).normalized() if at.distance_to(_target) > 40.0 else heading
	heading = heading.lerp(wanted, minf(delta * 1.4, 1.0)).rotated(
		_rng.randf_range(-1.0, 1.0) * wander * delta).normalized()
	at += heading * Balance.TORNADO_SPEED * delta
	position = at
	_tick_fire(delta)
	_hurt(delta)
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = 0.28
		Vfx.dust(at, Color(0.42, 0.36, 0.28), 5, Balance.TORNADO_WAKE)
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


## The funnel: turning ellipses from a wide, faint top to a narrow, dark foot.
func _draw() -> void:
	var layers: int = 7
	for index: int in layers:
		var t: float = float(index) / float(layers - 1)
		var height: float = -Balance.TORNADO_HEIGHT * t
		var width: float = lerpf(Balance.TORNADO_WAKE * 0.5, Balance.TORNADO_AOE * 0.9, t)
		var sway: float = sin(_spin * 0.7 + t * 4.0) * width * 0.18
		var alpha: float = lerpf(0.55, 0.16, t)
		var shade: float = lerpf(0.28, 0.62, t)
		var layer: PackedVector2Array = _funnel_layer(t, height, width, sway)
		if layer.size() < 3:
			continue
		if burning():
			# A fire whirl: lit from inside, brightest at the foot.
			var glow: Color = Color(1.0, lerpf(0.45, 0.7, t), lerpf(0.12, 0.3, t), alpha * 1.15)
			draw_colored_polygon(layer, glow)
			continue
		draw_colored_polygon(layer, Color(shade, shade * 0.92, shade * 0.8, alpha))
	# The foot on the ground.
	var foot: PackedVector2Array = PackedVector2Array()
	for s: int in 16:
		var angle: float = TAU * float(s) / 16.0
		foot.append(Vector2(cos(angle), sin(angle) * 0.35) * Balance.TORNADO_WAKE * 0.7)
	draw_colored_polygon(foot, Color(0.55, 0.22, 0.08, 0.6) if burning() else Color(0.2, 0.17, 0.13, 0.5))


func _funnel_layer(t: float, height: float, width: float, sway: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	# A layer thinner than a pixel is no polygon; the caller skips an empty one.
	if width < 2.0:
		return points
	var steps: int = 18
	for s: int in steps:
		var angle: float = TAU * float(s) / float(steps) + _spin * (1.0 + t)
		points.append(Vector2(sway + cos(angle) * width, height + sin(angle) * width * 0.28))
	return points
