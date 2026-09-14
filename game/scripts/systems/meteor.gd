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


func _process(delta: float) -> void:
	if _landed:
		return
	_left -= delta
	queue_redraw()
	if _left <= 0.0:
		_land()


## The shadow, growing; and in the last half second the stone itself, coming
## in from the upper right.
func _draw() -> void:
	var progress: float = 1.0 - clampf(_left / maxf(Balance.METEOR_WARNING, 0.01), 0.0, 1.0)
	var radius: float = Balance.METEOR_RADIUS * lerpf(0.25, 0.85, progress)
	var shadow: PackedVector2Array = PackedVector2Array()
	for s: int in 24:
		var angle: float = TAU * float(s) / 24.0
		shadow.append(Vector2(cos(angle), sin(angle) * 0.45) * radius)
	if radius >= 2.0:
		draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.18 + 0.4 * progress))
	# The rim pulses faster as it comes.
	var pulse: float = 0.5 + 0.5 * sin(progress * progress * 40.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.45, 0.15, 0.25 + 0.5 * pulse * progress), 3.0)
	if _left < Balance.METEOR_FALL:
		var fall: float = 1.0 - _left / Balance.METEOR_FALL
		var from: Vector2 = Vector2(Balance.METEOR_FALL_FROM.x, -Balance.METEOR_FALL_FROM.y)
		var stone: Vector2 = from.lerp(Vector2.ZERO, fall)
		draw_line(from.lerp(stone, 0.55), stone, Color(1.0, 0.6, 0.25, 0.8), 14.0)
		draw_line(from.lerp(stone, 0.8), stone, Color(1.0, 0.9, 0.7, 0.95), 7.0)
		draw_circle(stone, 22.0, Color(1.0, 0.85, 0.6, 1.0))


func _land() -> void:
	_landed = true
	Vfx.flash(Color(1.0, 0.72, 0.45), Balance.METEOR_FLASH, 0.28)
	Vfx.flash_at(at, Color(1.0, 0.7, 0.4), Balance.METEOR_RADIUS * 0.6)
	Vfx.ring(at, Balance.METEOR_RADIUS, Color(1.0, 0.55, 0.25, 0.95), 0.55, 8.0)
	Vfx.ring(at, Balance.METEOR_RADIUS * 1.6, Color(0.6, 0.4, 0.25, 0.6), 0.8, 4.0)
	Vfx.spark(at, Color(1.0, 0.7, 0.35), 30, Vector2.UP, 420.0)
	Vfx.dust(at, Color(0.32, 0.26, 0.2), 18, Balance.METEOR_RADIUS)
	EventBus.camera_impact.emit(at, Balance.METEOR_SHAKE)
	Sfx.play("sfx_meteor_impact", 0.0)
	if marks != null:
		marks.stamp(at, Balance.METEOR_RADIUS * 0.9, 1.0)
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
