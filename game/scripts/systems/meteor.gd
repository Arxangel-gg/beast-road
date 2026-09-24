class_name Meteor
extends Node2D

## A stone from the sky, aimed near the player's towers.
##
## Owner brief, 2026-09-14: too much fire, and the earth answers with a
## meteor "nearby player towers, damaging the tower as well as all characters
## in a large aoe blast". It arrives in two beats. The warning: a shadow grows
## on the ground for `METEOR_WARNING` seconds and the whistle rises, which is
## the player's time to get out from under it. The impact: a flash, a ring,
## the ground marked, every tower and body in the blast hurt, and the plants
## around it lit - a meteor is a wildfire's opening move.
##
## The host resolves the hurt on impact; a guest is told the point when the
## warning begins (`coop_meteor_incoming`) and runs the same two beats to
## draw them.

var at: Vector2 = Vector2.ZERO
var field: Battlefield = null
var wildfire: Wildfire = null
var marks: ScorchMarks = null
## The holes in the ground, which outlive the stone by the rest of the act.
var pits: Craters = null
var _spark_in: float = 0.0
var _left: float = 0.0
var _mirror: bool = false
var _landed: bool = false
var _rng: RandomNumberGenerator = null
## For the gate.
var struck_towers: int = 0


func _ready() -> void:
	name = "Meteor"
	z_as_relative = false
	z_index = Balance.METEOR_Z
	position = at
	_left = Balance.METEOR_WARNING
	_mirror = Coop.is_guest()
	_rng = RunState.rng("wrath")
	Sfx.play("sfx_meteor_whistle", 0.0)


func _process_measured(delta: float) -> void:
	if _landed:
		return
	_left -= delta
	queue_redraw()
	# Burning material shedding off it on the way in. On its own clock rather
	# than per frame: a spark a frame is a solid line, and this is a stone
	# coming apart rather than a jet.
	if _left < Balance.METEOR_FALL:
		_spark_in -= delta
		if _spark_in <= 0.0:
			_spark_in = Balance.METEOR_TRAIL_SPARK_TICK
			var fall: float = 1.0 - _left / Balance.METEOR_FALL
			var from: Vector2 = Vector2(Balance.METEOR_FALL_FROM.x, -Balance.METEOR_FALL_FROM.y)
			var along: Vector2 = global_position + from.lerp(Vector2.ZERO, fall)
			Vfx.spark(along, Color(1.0, 0.66, 0.28), 3, -from.normalized(), 180.0)
			# **The trail, laid along the way it is coming.** An aimed sheet,
			# so it is turned onto the descent rather than spun - a streak at
			# a random angle is a streak that is not a trail. Same clock as
			# the sparks, for the same reason.
			Vfx.forge_play("meteor_trail", along, Balance.METEOR_RADIUS * 0.9,
				Color(1.0, 0.72, 0.36), (-from).angle())
	if _left <= 0.0:
		_land()


## **Where, and when.** The shadow says where; a ring closing onto the target
## says when; and in the last half second the stone comes in, lighting the ground
## it is about to hit.
func _draw_measured() -> void:
	var progress: float = 1.0 - clampf(_left / maxf(Balance.METEOR_WARNING, 0.01), 0.0, 1.0)
	var radius: float = Balance.METEOR_RADIUS * lerpf(0.25, 0.85, progress)
	if radius >= 2.0:
		_draw_shadow(radius, progress)
	# The target, tightening, and a second ring falling onto it - the stone's own
	# arrival drawn as a countdown. A shadow that only grows says where something
	# will land and nothing at all about when.
	var pulse: float = 0.5 + 0.5 * sin(progress * progress * 40.0)
	var mark := Color(1.0, 0.45, 0.15, 0.25 + 0.5 * pulse * progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, mark, 3.0)
	var closing: float = radius * lerpf(Balance.METEOR_CLOSING_RING, 1.0, progress * progress)
	draw_arc(Vector2.ZERO, closing, 0.0, TAU, 44,
		Color(1.0, 0.62, 0.3, 0.45 * progress), 2.5)
	if _left < Balance.METEOR_FALL:
		_draw_the_stone(1.0 - _left / Balance.METEOR_FALL, radius)


## The shadow under it: a bowl rather than a disc. A `draw_colored_polygon` is
## one colour for the whole shape, which is what a hard edge *is* - the same
## finding the menu's light shafts, the funnel and the flame each reached.
func _draw_shadow(radius: float, progress: float) -> void:
	var steps: int = 28
	var dark: float = 0.2 + 0.55 * progress
	var points := PackedVector2Array([Vector2.ZERO])
	var colours := PackedColorArray([Color(0.0, 0.0, 0.0, dark)])
	for band: int in 2:
		for s: int in steps:
			var angle: float = TAU * float(s) / float(steps)
			var out := Vector2(cos(angle), sin(angle) * 0.45)
			points.append(out * radius * (Balance.METEOR_SHADOW_CORE if band == 0 else 1.0))
			colours.append(Color(0.0, 0.0, 0.0, dark if band == 0 else 0.0))
	var indices := PackedInt32Array()
	for s: int in steps:
		var inner: int = 1 + s
		var next_inner: int = 1 + (s + 1) % steps
		indices.append_array([0, inner, next_inner])
		var outer: int = 1 + steps + s
		var next_outer: int = 1 + steps + (s + 1) % steps
		indices.append_array([inner, outer, next_inner, outer, next_outer, next_inner])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## The stone: a trail that fades along its length rather than two flat strokes,
## a white-hot head inside a corona, and the ground brightening under it.
func _draw_the_stone(fall: float, radius: float) -> void:
	var from: Vector2 = Vector2(Balance.METEOR_FALL_FROM.x, -Balance.METEOR_FALL_FROM.y)
	var stone: Vector2 = from.lerp(Vector2.ZERO, fall)
	var along: Vector2 = (Vector2.ZERO - from).normalized()
	var side := Vector2(-along.y, along.x)
	# The trail, as one tapering strip: wide and clear behind, narrow and bright
	# at the head.
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var steps: int = 10
	for step: int in steps + 1:
		var t: float = float(step) / float(steps)
		var here: Vector2 = stone - along * (1.0 - t) * from.length() * 0.42 * fall
		var wide: float = lerpf(30.0, 7.0, t)
		points.append(here + side * wide)
		points.append(here - side * wide)
		var tone := Color(1.0, lerpf(0.42, 0.88, t), lerpf(0.12, 0.62, t), lerpf(0.0, 0.95, t * t))
		colours.append(tone)
		colours.append(tone)
		if step > 0:
			var a: int = (step - 1) * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)
	# The head, and the air burning around it.
	draw_circle(stone, 42.0, Color(1.0, 0.5, 0.18, 0.22))
	draw_circle(stone, 26.0, Color(1.0, 0.72, 0.34, 0.75))
	draw_circle(stone, 14.0, Color(1.0, 0.97, 0.88, 1.0))
	# And the ground it is about to hit, brightening.
	draw_circle(Vector2.ZERO, radius * Balance.METEOR_APPROACH_GLOW,
		Color(1.0, 0.55, 0.22, 0.05 + 0.16 * fall * fall))


func _land() -> void:
	_landed = true
	Vfx.flash(Color(1.0, 0.72, 0.45), Balance.METEOR_FLASH, 0.28)
	Vfx.flash_at(at, Color(1.0, 0.7, 0.4), Balance.METEOR_RADIUS * 0.6)
	# The fall lights the field round it for a moment (2026-09-24).
	Vfx.light_burst(at, Color(1.0, 0.72, 0.45), Balance.METEOR_RADIUS * 2.4, 1.8, 0.55)
	# Three rings leaving at three speeds: the blast, the shock behind it, and
	# the dust it pushed. One ring is a drawn radius; three read as something
	# expanding.
	Vfx.ring(at, Balance.METEOR_RADIUS * 0.45, Color(1.0, 0.95, 0.8, 0.95), 0.2, 11.0)
	Vfx.ring(at, Balance.METEOR_RADIUS, Color(1.0, 0.55, 0.25, 0.95), 0.55, 8.0)
	Vfx.ring(at, Balance.METEOR_RADIUS * 1.6, Color(0.6, 0.4, 0.25, 0.6), 0.8, 4.0)
	# Thrown up and out: the plume first, then what rains back down.
	Vfx.spark(at, Color(1.0, 0.92, 0.7), 16, Vector2.UP, 620.0)
	Vfx.spark(at, Color(1.0, 0.7, 0.35), 30, Vector2.UP, 420.0)
	Vfx.spark(at, Color(0.44, 0.36, 0.28), 18, Vector2.UP, 240.0)
	Vfx.dust(at, Color(0.32, 0.26, 0.2), 26, Balance.METEOR_RADIUS * 1.3)
	# And the bloom off the ground, at the radius the three rings are drawn
	# at. The biggest sheet in the catalogue, and the only one with a floor
	# under it - which is what this is a picture of.
	Vfx.forge_play("meteor_bloom", at, Balance.METEOR_RADIUS * 2.2,
		Color(1.0, 0.76, 0.46))
	EventBus.camera_impact.emit(at, Balance.METEOR_SHAKE)
	Sfx.play("sfx_meteor_impact", 0.0)
	if marks != null:
		marks.stamp(at, Balance.METEOR_RADIUS * 0.9, 1.0)
	# **The hole, which outlives everything else here.** Opened on both machines
	# - a guest mirrors the stone and lands it through this same function - so
	# nothing about a crater crosses the wire.
	if pits != null and is_instance_valid(pits):
		pits.open(at, Balance.METEOR_RADIUS * 0.55)
	if field != null and field.climate() != null:
		field.climate().add_heat(at, Balance.CLIMATE_HEAT_PER_METEOR, Balance.METEOR_RADIUS * 1.5)
	if not _mirror:
		_hurt()
		if wildfire != null:
			for _i: int in Balance.METEOR_FIRES:
				var seed_at: Vector2 = at + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * Balance.METEOR_RADIUS
				wildfire.ignite_near(seed_at, Balance.METEOR_RADIUS * 0.8, 1.0)
		# What it leaves: ground that burns, and feeds the fire towers on it.
		if field != null and field.zones() != null:
			field.zones().open("burning_ground", at, Balance.ZONE_BURN_RADIUS)
	var fade: Tween = create_tween()
	fade.tween_interval(0.3)
	fade.tween_callback(queue_free)


func _hurt() -> void:
	if field == null:
		return
	var radius: float = Balance.METEOR_RADIUS
	var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_HP_SCALE.size() - 1)]
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower == null or not is_instance_valid(tower) or not tower.is_vulnerable():
			continue
		var away: float = tower.global_position.distance_to(at)
		if away <= radius:
			tower.hurt(Balance.METEOR_TOWER_DAMAGE * (1.0 - 0.5 * away / radius), at)
			struck_towers += 1
	for enemy: Enemy in field.enemies_near(at, radius):
		enemy.take_damage(Balance.METEOR_ENEMY_DAMAGE * act_scale, at, 0.0)
	var hero_pool: float = 100.0
	if field.hero != null and field.hero.health != null:
		hero_pool = field.hero.health.max_hp
	EnemyGroundStrike.strike_the_players(get_tree(), hero_pool * Balance.METEOR_HERO_SHARE, "meteor",
		func(where: Vector2) -> bool: return where.distance_to(at) <= radius, Balance.METEOR_PUSH, at)
	var animals: Wildlife = field.wildlife()
	if animals != null:
		animals.wound_within(at, radius, Balance.METEOR_WILDLIFE_DAMAGE, false)


## `FrameProfile` bucket "d_meteor": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_meteor", started)


## `FrameProfile` bucket "p_meteor": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_meteor", started)
