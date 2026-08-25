class_name Enemy
extends Node2D

## One enemy walking a lane (GDD §3). Everything about it comes from an
## EnemyData resource, so adding a breed is adding a `.tres`.
##
## **Enemies do not damage by touching.** They walk until something is in reach,
## stop, wind up on a visible tell, and strike. Contact damage was how the first
## prototype worked and it made attacking feel like self-harm: you had to be
## inside the thing that was hurting you in order to hit it. The wind-up is what
## gives the dash something to dodge and the melee chain a window to live in.

const GROUP: StringName = &"enemies"

## Enemies that exist only because a boss called them.
##
## A group rather than a list held by BossDirector: the boss can die on any
## frame, summons die on their own all the time, and a list of node references
## would need validity-checking on every entry. The group carries the same
## information and cannot dangle.
const SUMMON_GROUP: StringName = &"boss_summons"

## Identity across two machines, assigned by the host when it spawns this.
##
## Zero in a single-player run and for anything the host never announced. Node
## names would have been the obvious alternative and are the wrong one: they are
## unique within a parent, not across a wire, and Godot renames on collision - so
## two machines can disagree about which enemy is which without either being
## wrong locally.
var net_id: int = 0

## True when this is a picture of an enemy simulated on another machine.
##
## A puppet decides nothing. It does not pick targets, walk, strike, take damage
## or pay out; its position and health arrive as facts. Everything else - the
## sprite, the facing, the walk animation, the tint - runs through exactly the
## same code as a real enemy, which is why a guest's battlefield looks alive
## rather than like a slideshow of the host's.
var puppet: bool = false
var _puppet_last: Vector2 = Vector2.ZERO

## Where the host last said this is, and how long there is to get there.
##
## A puppet is **interpolated**, not snapped. Positions arrive ten times a second
## and a body that jumps to each one and then waits is a body that stutters -
## reported from play as "enemy walks are all jittery". Between packets it walks
## the remaining distance at the speed that will arrive exactly as the next one
## does, so the motion is continuous and the position is still the host's.
var _mirror_target: Vector2 = Vector2.ZERO
var _mirror_left: float = 0.0
var _mirror_ratio: float = 0.0

enum State {
	WALKING,
	WINDUP,
	STRIKE,
	RECOVER,
	DYING,
}

@export var health: Health
@export var sprite: Sprite2D
@export var health_bar: HealthBar
@export var animator: SpriteAnimator

## Set by the spawner before the node enters the tree.
var data: EnemyData = null
var lane: int = 0

var _field: EnemyField = null
var _state: State = State.WALKING
var _state_left: float = 0.0
var _target: Node2D = null

var _knockback: Vector2 = Vector2.ZERO
var _hitstun_left: float = 0.0

## Counts down before another hitstun may be applied. Without it, every hit
## refreshes the flinch and a well-covered tile switches an enemy off.
var _hitstun_refractory: float = 0.0
var _flash_left: float = 0.0
var _death_left: float = 0.0

## Lateral offset from the lane centre line, so a wave reads as a column.
var _lane_offset: float = 0.0

## Which leg of the road this enemy is walking. Only ever increases.
var _path_index: int = 0

## The way in this enemy chose when it spawned.
##
## Held rather than looked up, because the authored map forks: asking the lane
## for "the" path would send every enemy down the shortest corridor and quietly
## throw away the whole point of the layout. Chosen once so the choice is stable
## - re-rolling it per frame would make an enemy dither at every junction.
var _route: PackedVector2Array = PackedVector2Array()


## Separate scaling keeps durability tense without letting late enemies erase
## the town in one hit. Speed gets its own gentler curve too.
var _hp_scale: float = 1.0
var _damage_scale: float = 1.0
var _speed_scale: float = 1.0

# --- Status effects ---
## Movement penalty, derived from `_chill` every tick. Kept as its own field
## because movement and target sorting both read it on hot paths.
var _slow_factor: float = 1.0

## The chill meter, 0..1. Every slow in the game feeds this one value rather than
## overwriting the last one, and it is the single source of both how slowly the
## enemy walks and whether it shatters. See the chill block in Balance.
var _chill: float = 0.0

## While positive, chill holds instead of decaying. This is what an authored
## `slow_duration` means now.
var _chill_hold: float = 0.0

## Counts down before this enemy may be locked again.
var _freeze_refractory: float = 0.0

var _freeze_left: float = 0.0
var _burn_dps: float = 0.0
var _burn_left: float = 0.0

## Velocity from the previous frame drives the procedural gait. Keeping it here
## also makes hitstun and freezing visibly settle instead of walking in place.
var _motion: Vector2 = Vector2.ZERO
var _boss_phase: int = 0

## A slide in progress on snow, and how long is left of it.
##
## Sideways rather than forwards: a slip is losing your footing, not being
## hurried along. Carried as a velocity so it composes with the walk instead of
## replacing it - an enemy mid-slip is still trying to get where it was going,
## which is what makes it read as a stumble rather than as a teleport.
var _slip: Vector2 = Vector2.ZERO
var _slip_left: float = 0.0


func setup(enemy_data: EnemyData, lane_index: int, field: EnemyField,
		hp_scale: float, damage_scale: float = -1.0, speed_scale: float = 1.0) -> void:
	data = enemy_data
	lane = lane_index
	_field = field
	_hp_scale = hp_scale
	_damage_scale = hp_scale if damage_scale < 0.0 else damage_scale
	_speed_scale = speed_scale
	_route = field.lane_route(lane_index)


func _ready() -> void:
	add_to_group(GROUP)
	if data == null or _field == null:
		push_error("Enemy spawned without data or battlefield; setup() must run first.")
		queue_free()
		return

	health.max_hp = data.max_hp * _hp_scale
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health_bar.bind(health)
	if data.role == EnemyData.Role.HOWLER:
		_build_aura_readout()

	animator.mass = _mass_for_category()
	animator.capture_home()

	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	_apply_category_scale()
	animator.capture_home()

	# Shadows are added after the texture, because both are measured from it.
	# A pool under every walker is most of what stops a crowd looking like decals
	# sliding across the floor, and the caster is what makes them streak past a
	# torch at night.
	ShadowKit.add_contact(self, sprite)
	var half: Vector2 = sprite.texture.get_size() * sprite.scale.abs() * 0.5 \
		if sprite.texture != null else Vector2(40, 40)
	ShadowKit.add_caster(self, half.x * 0.42, half.y * 0.20,
		Balance.SHADOW_LAYER_UNITS, half.y * 0.40)

	_lane_offset = RunState.rng("combat").randf_range(
		-Balance.LANE_WIDTH, Balance.LANE_WIDTH) * 0.5
	EventBus.beast_step_landed.connect(_on_beast_step)
	EventBus.enemy_spawned.emit(data.id, global_position)


func _process(delta: float) -> void:
	if _state == State.DYING:
		_tick_death(delta)
		return

	if puppet:
		_tick_puppet(delta)
		return

	_tick_status(delta)
	_hitstun_left = maxf(_hitstun_left - delta, 0.0)
	_hitstun_refractory = maxf(_hitstun_refractory - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, Balance.ENEMY_KNOCKBACK_DECAY * delta)

	var before: Vector2 = global_position
	if _freeze_left <= 0.0 and _hitstun_left <= 0.0:
		_tick_state(delta)

	global_position += _knockback * delta
	_motion = (global_position - before) / maxf(delta, 0.0001)
	animator.set_motion(_motion, maxf(data.move_speed, 1.0), delta)
	_update_sprite()


## A mirrored enemy: draw what arrived, decide nothing.
##
## Motion is *derived* from the position the host sent rather than sent
## alongside it. Two reasons: it is a vector the wire does not have to carry, and
## it means facing and the walk cycle are driven by the same `_motion` the real
## enemy uses. A puppet with its own facing rule would be a second implementation
## of the thing that was just fixed for walking backwards.
func _tick_puppet(delta: float) -> void:
	# Walk toward where the host says to be, rather than teleporting there. The
	# step is scaled by how much of the remaining window this frame is, so the
	# body arrives just as the next packet lands however the frame rate varies.
	if _mirror_left > 0.0:
		var step: float = minf(delta / _mirror_left, 1.0)
		global_position = global_position.lerp(_mirror_target, step)
		_mirror_left -= delta
	_motion = (global_position - _puppet_last) / maxf(delta, 0.0001)
	_puppet_last = global_position
	if animator != null and data != null:
		animator.set_motion(_motion, maxf(data.move_speed, 1.0), delta)
	_update_sprite()


## The scaling this enemy was spawned with, so a mirror can be built to match.
##
## Read rather than guessed: the guest must construct an identical enemy or the
## health bar it draws is a bar for a different creature.
func hp_scale() -> float:
	return _hp_scale


func damage_scale() -> float:
	return _damage_scale


func speed_scale() -> float:
	return _speed_scale


## Health as 0..1, which is what crosses the wire. A ratio rather than an
## absolute survives any later change to how max health is computed.
func health_ratio() -> float:
	return health.ratio() if health != null else 0.0


## How long to expect between position packets, in seconds.
##
## Told rather than guessed: the interpolation has to know the size of the window
## it is spreading movement across, and a hard-coded copy of `BATCH_INTERVAL`
## here would silently start stuttering the day that constant was tuned.
func set_mirror_interval(seconds: float) -> void:
	_mirror_ratio = seconds


## Takes a position and health from the host.
##
## Health is assigned rather than damaged: a puppet must not run the death path,
## because the host already ran it and will say so with its own message. Two
## machines each paying out the same kill is how a shared purse doubles.
func mirror(at: Vector2, hp_ratio: float) -> void:
	# The first packet places it; every one after aims it. Snapping on arrival
	# would put the body where it *was* when the packet was sent and then leave
	# it there, which is the stutter this exists to remove.
	if _mirror_left <= 0.0 and _mirror_target == Vector2.ZERO:
		global_position = at
		_puppet_last = at
	_mirror_target = at
	_mirror_left = maxf(_mirror_ratio, 0.05)
	if health != null and health.max_hp > 0.0:
		health.current_hp = clampf(hp_ratio, 0.0, 1.0) * health.max_hp
		health.changed.emit(health.current_hp, health.max_hp)


# --- State machine ----------------------------------------------------------

func _tick_state(delta: float) -> void:
	match _state:
		State.WALKING:
			_target = _pick_target()
			if _target != null and _in_reach(_target):
				_enter(State.WINDUP, Balance.ENEMY_ATTACK_WINDUP)
				# Coil before the blow: the tell the player reads.
				animator.squash(Balance.ANIM_HURT_SQUASH * 0.8)
			else:
				_walk(delta)
		State.WINDUP:
			_state_left -= delta
			if _state_left <= 0.0:
				_strike()
				_enter(State.STRIKE, Balance.ENEMY_ATTACK_STRIKE)
				var toward: Vector2 = Vector2.RIGHT
				if _target != null and is_instance_valid(_target):
					toward = (_target.global_position - global_position).normalized()
				animator.punch(toward, 1.1)
		State.STRIKE:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter(State.RECOVER, Balance.ENEMY_ATTACK_RECOVERY)
		State.RECOVER:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter(State.WALKING, 0.0)
		_:
			pass


func _enter(state: State, duration: float) -> void:
	_state = state
	_state_left = duration


## Walks the lane's road toward the town, holding a fixed lateral offset so a
## wave arrives as a column rather than in single file.
##
## The road bends now (GDD §13), so this follows waypoints instead of aiming at
## the town. Aiming straight at the town across a U-bend would send the whole
## formation over the open ground the player is meant to be building on, which
## is the entire point of the bend.
func _walk(delta: float) -> void:
	var destination: Vector2 = _target.global_position if _target != null else _field.town_position()
	var to: Vector2 = destination - global_position
	if to.length() <= 1.0:
		return
	var direction: Vector2 = to.normalized()
	# Only enemies still heading for the town hold the road; one that has broken
	# off to fight the hero moves straight at them.
	if _target == null or _target == _field.town_node():
		direction = _road_direction()

	_tick_slip(delta, direction)
	var step: Vector2 = (direction * current_speed() + _slip) * delta
	var wanted: Vector2 = global_position + step
	if _field.step_is_legal(global_position, wanted):
		global_position = wanted
		return

	# Blocked by a cliff. Slide along it rather than stopping dead: an enemy that
	# freezes at the foot of an island reads as broken, while one that runs along
	# the face looking for the ramp reads as a siege - which is the behaviour the
	# ramp exists to produce.
	for sideways: Vector2 in [Vector2(step.y, -step.x), Vector2(-step.y, step.x)]:
		var slide: Vector2 = global_position + sideways
		if _field.step_is_legal(global_position, slide):
			global_position = slide
			return


## Losing your footing on snow.
##
## Rolled per step against how much snow is *actually lying* - a dusting barely
## does it and a covered field does it often - so the effect appears with the
## weather rather than being a property of the act. Read from `RunState`, which
## is where the run's snow depth lives; an enemy caching its own copy would keep
## slipping through a thaw.
##
## Rolled from the combat stream, so a seeded replay slips in the same places.
## Anything else would make a reproducible run stop being reproducible the moment
## it snowed.
##
## Puppets never slip: on a guest they are a picture of an enemy whose footing
## was decided on the host, and rolling locally would have the two machines
## disagree about where it ended up.
func _tick_slip(delta: float, heading: Vector2) -> void:
	if _slip_left > 0.0:
		_slip_left -= delta
		if _slip_left <= 0.0:
			_slip = Vector2.ZERO
		return
	if puppet or RunState.snow_cover <= 0.01:
		return
	var chance: float = Balance.SNOW_SLIP_CHANCE * RunState.snow_cover * delta * 10.0
	if RunState.rng("combat").randf() > chance:
		return
	# Sideways, either way, off the direction of travel.
	var side: Vector2 = heading.orthogonal().normalized()
	if RunState.rng("combat").randf() < 0.5:
		side = -side
	_slip = side * (Balance.SNOW_SLIP_DISTANCE / maxf(Balance.SNOW_SLIP_SECONDS, 0.01))
	_slip_left = Balance.SNOW_SLIP_SECONDS
	# The lean sells it. Without this an enemy slides flat and reads as being
	# dragged rather than as having lost its footing.
	if animator != null:
		animator.punch(side, 0.55)


## Direction to the next waypoint, offset sideways into this enemy's column lane.
##
## The offset is applied perpendicular to the *current segment* rather than to
## the lane's overall heading, so a column keeps its shape around a corner
## instead of fanning out and cutting it.
func _road_direction() -> Vector2:
	var path: PackedVector2Array = _route
	if path.size() < 2:
		return (_field.town_position() - global_position).normalized()

	# Advance by *projection along the segment*, not by distance to the waypoint.
	#
	# The radius test this replaces could be missed entirely: an enemy holds a
	# lateral offset of up to half a lane width, so it approaches a line that
	# passes the corner to one side and may never come within any fixed radius of
	# it. The formation then walked to the first bend and stopped there.
	#
	# Asking "am I past the end of this leg" cannot be missed, however wide the
	# column runs or however hard something was knocked sideways.
	while _path_index < path.size() - 1:
		var from: Vector2 = path[_path_index]
		var segment: Vector2 = path[_path_index + 1] - from
		var length_squared: float = segment.length_squared()
		if length_squared <= 0.01:
			_path_index += 1
			continue
		if (global_position - from).dot(segment) / length_squared >= 1.0:
			_path_index += 1
		else:
			break

	if _path_index >= path.size() - 1:
		return (_field.town_position() - global_position).normalized()

	var leg: Vector2 = path[_path_index + 1] - path[_path_index]
	var aim: Vector2 = path[_path_index + 1] + leg.normalized().orthogonal() * _lane_offset
	var toward: Vector2 = aim - global_position
	return toward.normalized() if toward.length() > 1.0 else leg.normalized()


func current_speed() -> float:
	var speed: float = targeting_speed()
	if data.role != EnemyData.Role.HOWLER:
		var howler: Enemy = _nearby_howler()
		if howler != null:
			speed *= 1.0 + howler.data.aura_strength
	return speed


## Cheap speed read for tower target sorting. The full movement calculation
## searches for a nearby Howler; calling that inside a sort comparator turns a
## 180-enemy formation into thousands of group scans per tower volley. Global,
## status and boss-phase speed are enough to rank runners correctly.
func targeting_speed() -> float:
	var speed: float = data.move_speed * _speed_scale * _slow_factor
	if _boss_phase > 0:
		speed *= 1.0 + data.phase_speed_bonus * float(_boss_phase)
	if RunState.horn_active:
		speed *= Balance.HORN_ENEMY_SPEED_SCALE
	return speed


## Taunting towers pull first, then the hero if they have come close enough to
## be worth stopping for, then the town.
func _pick_target() -> Node2D:
	var taunt: Node2D = _field.taunting_tower_in_lane(lane)
	if taunt != null and is_instance_valid(taunt):
		return taunt
	if data.targets_towers:
		var structure: Node2D = _field.vulnerable_tower_in_lane(lane, global_position)
		if structure != null and is_instance_valid(structure):
			return structure
	var hero: Node2D = _field.hero_node()
	var town: Node2D = _field.town_node()
	if hero != null and is_instance_valid(hero) and _field.hero_is_alive():
		# With no town to march on — the raid arena — the hero is the only
		# objective there is, at any distance.
		if town == null or global_position.distance_to(hero.global_position) <= Balance.ENEMY_HERO_AGGRO_RANGE:
			return hero
	return town


func _in_reach(target: Node2D) -> bool:
	var attack_range: float = Balance.ENEMY_RANGED_RANGE \
		if data.role == EnemyData.Role.HOWLER else Balance.ENEMY_ATTACK_RANGE
	var reach: float = attack_range + contact_radius() + _field.target_radius(target)
	return global_position.distance_to(target.global_position) <= reach


func _strike() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Re-checked at the moment of the blow, slightly generously: stepping out
	# during the wind-up is supposed to work, but not by a single pixel.
	var attack_range: float = Balance.ENEMY_RANGED_RANGE \
		if data.role == EnemyData.Role.HOWLER else Balance.ENEMY_ATTACK_RANGE
	var reach: float = (attack_range + contact_radius() + _field.target_radius(_target)) * 1.15
	if global_position.distance_to(_target.global_position) > reach:
		return
	var target_health: Health = Health.of(_target)
	if target_health == null:
		return
	# Rolled, like a tower's shot. A blow that lands for the same number every
	# time reads as arithmetic; the average is unchanged, so nothing balanced
	# against it moves.
	var damage: float = TowerData.roll_damage(
		data.contact_damage * _damage_scale, RunState.rng("combat"))
	if _boss_phase > 0:
		damage *= 1.0 + data.phase_damage_bonus * float(_boss_phase)
	if data.role != EnemyData.Role.HOWLER:
		var howler: Enemy = _nearby_howler()
		if howler != null:
			damage *= 1.0 + howler.data.aura_strength
	if RunState.enemies_are_weakened():
		damage *= Balance.WEAKENED_STAT_SCALE
	if _target == _field.town_node():
		damage *= Balance.TOWN_DAMAGE_SCALE
	if data.role == EnemyData.Role.HOWLER:
		var shot: Node2D = load("res://scenes/battlefield/enemy_projectile.gd").new() as Node2D
		shot.configure(_target, damage, global_position)
		_field.add_child(shot)
		return
	target_health.take_damage(damage, global_position)


# --- Damage and status ------------------------------------------------------

func contact_radius() -> float:
	return data.body_radius if data != null else Balance.ENEMY_BODY_RADIUS


func is_dying() -> bool:
	return _state == State.DYING


## True while the wind-up tell is showing — the window the player is meant to
## react to.
func is_telegraphing() -> bool:
	return _state == State.WINDUP


func apply_boss_phase(phase: int) -> void:
	_boss_phase = maxi(phase, _boss_phase)
	if _boss_phase <= 0:
		return
	# The ring and outward sparks make the transition readable through a crowd;
	# the persistent speed/damage change is authored on EnemyData.
	Vfx.ring(global_position, contact_radius() * 2.8,
		Color(1.0, 0.25, 0.12, 0.8), 0.75, 8.0)
	Vfx.spark(global_position, Color("ff7a4e"), 22, Vector2.ZERO, 330.0)
	animator.squash(1.45)


## A puppet ignores damage. The host decides what hurt it and by how much, and
## the answer arrives as health in `mirror`. Applying local damage as well would
## make a guest's enemies die early and then be resurrected by the next packet.
func take_damage(amount: float, from: Vector2, knockback: float,
		active_hero: bool = false) -> bool:
	if _state == State.DYING or data == null or puppet:
		return false
	var was_telegraphing: bool = _state == State.WINDUP
	var incoming: float = amount
	if RunState.enemies_are_weakened():
		incoming /= Balance.WEAKENED_STAT_SCALE
	if not health.take_damage(incoming, from):
		return false
	var attack_node: DisciplineNodeData = RunState.discipline_node_in_slot(0) \
		if active_hero else null
	if attack_node != null and attack_node.effect_id == "bleed_finisher":
		# The finisher is the only hit whose authored base damage reaches the last
		# chain value. Apply a bounded three-second bleed; it uses the shared status
		# path so death rewards and hit accounting remain identical.
		var finisher_damage: float = Balance.HERO_ATTACK_DAMAGE[Balance.HERO_CHAIN_LENGTH - 1] \
			* Modifiers.multiplier(Modifiers.HERO_DAMAGE)
		if amount >= finisher_damage * 0.9:
			apply_burn(amount * attack_node.effect_value, 3.0)
	_add_hitstun(Balance.ENEMY_HITSTUN)
	# The number is the clearest signal that a hit registered at all, which
	# matters most when a swing catches six things at once.
	Vfx.number(global_position, incoming, Color("ffe3b0"), incoming >= data.max_hp * 0.4)
	Vfx.spark(global_position, Color("ffcf9a"), 4, (global_position - from).normalized(), 170.0)
	animator.recoil(from, global_position, clampf(amount / maxf(data.max_hp, 1.0) * 3.0, 0.5, 1.8))
	animator.impact_frame()
	var away: Vector2 = global_position - from
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	_knockback = away * knockback * (1.0 - data.knockback_resistance)
	# Being hit hard enough interrupts a wind-up. This is what makes attacking
	# into a telegraph a real answer rather than a trade.
	if knockback > 0.0 and _state == State.WINDUP:
		_enter(State.RECOVER, Balance.ENEMY_ATTACK_RECOVERY * 0.5)
	if active_hero:
		var priority: bool = data.category != EnemyData.Category.BREED \
			or data.role == EnemyData.Role.HOWLER or data.role == EnemyData.Role.BURROWER
		EventBus.hero_enemy_hit.emit(data.id, lane, priority,
			was_telegraphing and knockback > 0.0, global_position)
	return true


func _on_beast_step(impulse: Vector2, strength: float) -> void:
	if _state == State.DYING or _field is RaidArena:
		return
	var resistance: float = data.knockback_resistance if data != null else 0.0
	_knockback += impulse * strength * (1.0 - resistance) * 0.72
	_add_hitstun(Balance.BEAST_STEP_STUN * strength)
	animator.beast_step(impulse, strength / sqrt(maxf(_mass_for_category(), 1.0)))


## Chain Hook drags things in. Expressed as its own operation rather than as
## negative knockback, so knockback resistance does not accidentally make an
## enemy immune to being pulled.
func pull_toward(point: Vector2, strength: float) -> void:
	if _state == State.DYING:
		return
	var toward: Vector2 = point - global_position
	if toward.length() < 1.0:
		return
	_knockback = toward.normalized() * strength
	_add_hitstun(Balance.ENEMY_HITSTUN)


## Feeds the chill meter. Repeated slows stack toward the floor instead of the
## strongest one simply winning, which is what makes a second frost tower worth
## building rather than redundant.
## Locks the enemy briefly, unless one was applied too recently.
##
## The single door for every movement lock in the game. It used to be four
## separate assignments, and the one in `take_damage` fired on *every* hit with
## nothing to stop it refreshing - so enough incoming fire simply switched an
## enemy off, which is what a Glacial Mortar or a Pyre Cannon looked like from
## the player's side. Routing them all through here makes "an enemy always gets
## to move" a property of this class rather than of whatever is shooting it.
func _add_hitstun(duration: float) -> void:
	if duration <= 0.0 or _hitstun_refractory > 0.0:
		return
	_hitstun_left = maxf(_hitstun_left, duration)
	_hitstun_refractory = duration + Balance.ENEMY_HITSTUN_GAP


func apply_slow(factor: float, duration: float) -> void:
	if factor >= 1.0 or duration <= 0.0:
		return
	_add_chill((1.0 - factor) * Balance.CHILL_PER_SLOW)
	_chill_hold = maxf(_chill_hold, duration)


## A freeze proc is chill, not a lock.
##
## This used to set a timer that any later proc refreshed, so overlapping freeze
## towers held an enemy still for as long as they kept firing. It now fills the
## meter faster than a plain slow does, and the lock - if one happens at all -
## comes from `_shatter`, under the same ceiling and refractory as everything
## else.
func apply_freeze(duration: float) -> void:
	if duration <= 0.0:
		return
	_add_chill(Balance.CHILL_PER_FREEZE_PROC)
	_chill_hold = maxf(_chill_hold, duration)


## Adds chill and locks the enemy if that fills the meter.
func _add_chill(amount: float) -> void:
	if amount <= 0.0 or _state == State.DYING:
		return
	if data != null and data.category == EnemyData.Category.BOSS:
		amount *= Balance.CHILL_BOSS_RESIST
	_chill = minf(_chill + amount, 1.0)
	if _chill >= 1.0:
		_shatter()


## The moment at a full meter: a short lock, then back to walking slowed.
func _shatter() -> void:
	if _freeze_refractory > 0.0:
		return
	_freeze_left = maxf(_freeze_left,
		minf(Balance.CHILL_SHATTER_SECONDS, Balance.FREEZE_MAX_SECONDS))
	_freeze_refractory = Balance.FREEZE_REFRACTORY
	_chill = Balance.CHILL_AFTER_SHATTER
	animator.squash(1.25)


func apply_stagger(duration: float) -> void:
	if _state == State.DYING or duration <= 0.0:
		return
	_add_hitstun(duration)
	_knockback += Battlefield.lane_vector(lane) * 90.0
	if _state == State.WINDUP or _state == State.STRIKE:
		_enter(State.RECOVER, maxf(duration * 0.65, Balance.ENEMY_ATTACK_RECOVERY))
	animator.squash(1.35)


func apply_burn(dps: float, duration: float) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = maxf(_burn_left, duration)


func _tick_status(delta: float) -> void:
	_freeze_refractory = maxf(_freeze_refractory - delta, 0.0)
	if _chill_hold > 0.0:
		_chill_hold -= delta
	elif _chill > 0.0:
		_chill = maxf(_chill - Balance.CHILL_DECAY * delta, 0.0)
	_slow_factor = lerpf(1.0, Balance.CHILL_SLOW_FLOOR, _chill)
	if _freeze_left > 0.0:
		_freeze_left -= delta
	if _burn_left > 0.0:
		_burn_left -= delta
		health.take_damage(_burn_dps * delta, global_position)
	if data.hp_regen > 0.0:
		health.heal(data.hp_regen * delta)
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null and terrain.enemy_hp_regen > 0.0:
		health.heal(terrain.enemy_hp_regen * delta)


func _on_damaged(_amount: float, _from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME


func _on_died(_from: Vector2) -> void:
	_enter(State.DYING, 0.0)
	_death_left = Balance.ENEMY_DEATH_FADE
	remove_from_group(GROUP)
	health_bar.visible = false
	RunState.enemies_killed += 1
	RunState.gain_kill_resources(data.resource_value)
	# XP scales with the enemy's health rather than an authored per-enemy number,
	# so an elite is worth more than a runner with no second table to maintain,
	# and act scaling carries the curve forward on its own.
	# The tier's own multiplier on top of the health it already scaled, so a Hell
	# kill is worth more than the same enemy on Normal twice over: once for being
	# tougher, once for the tier being worth running.
	var tier: CampaignTierData = RunState.tier()
	var payout: float = data.max_hp * _hp_scale * Balance.HERO_XP_PER_HP
	RunState.gain_hero_xp(payout * (tier.xp_scale if tier != null else 1.0))
	_drop_loot()
	_drop_gear()
	if data.category == EnemyData.Category.ELITE:
		RunState.gain_currency(RunState.STONE, Balance.ELITE_STONE_REWARD)
	EventBus.enemy_died.emit(data.id, global_position)


## Removes this enemy without killing it.
##
## For the pack a boss called and then died before it could spend. The boss's
## death ends the wave and the act, so anything it summoned rides into the next
## act's Preparation - which is untimed and is meant to be the one safe phase.
## The player was spending it hunting leftovers instead of preparing, which is
## the exact failure that phase exists to prevent.
##
## Deliberately not `_on_died`, and the difference is the whole point: nothing
## here is a kill. No kill count, no resources, no hero XP, no loot, no gear, no
## `enemy_died`. Paying out for these would make ignoring a boss's adds and
## rushing the boss the most profitable way to fight one, which is the opposite
## of what summoning is for.
##
## It fades rather than popping. A dozen sprites vanishing on a single frame
## reads as a crash, not as a rout.
func dismiss() -> void:
	if is_dying():
		return
	_enter(State.DYING, 0.0)
	_death_left = Balance.ENEMY_DEATH_FADE
	remove_from_group(GROUP)
	remove_from_group(SUMMON_GROUP)
	health_bar.visible = false


## Scatters this kill's bonus loot, if it rolled any.
##
## Rolled from the combat stream so a seeded replay drops the same things, and
## rounded up to at least one so a low-value enemy that *did* roll a drop never
## produces a pickup worth nothing.
func _drop_loot() -> void:
	if _field == null or not _field.has_method("spawn_loot"):
		return
	var elite: bool = data.category != EnemyData.Category.BREED
	var chance: float = Balance.LOOT_DROP_CHANCE
	if elite:
		chance = 1.0
	if RunState.rng("combat").randf() > chance:
		return
	var share: float = float(data.resource_value) * Balance.KILL_RESOURCE_SCALE 		* Balance.LOOT_BONUS_SHARE
	if elite:
		share *= Balance.LOOT_ELITE_MULTIPLIER
	var tier: CampaignTierData = RunState.tier()
	if tier != null:
		share *= tier.loot_scale
	var amount: int = maxi(1, int(round(share)))
	var currency: String = RunState.CURRENCIES[
		RunState.rng("combat").randi_range(0, RunState.CURRENCIES.size() - 1)]
	_field.spawn_loot(currency, amount, global_position)


## Gear used to exist only behind a raid chest. The battlefield now has its own
## low-frequency hunt: breeds can surprise, elites are meaningful prospects and
## bosses always leave a piece. A separate deterministic stream means adding a
## cosmetic spark or changing attack variance cannot rewrite the stash reward.
func _drop_gear() -> void:
	if _field == null or not (_field is Battlefield) \
			or not _field.has_method("spawn_gear"):
		return
	var chance: float = Balance.GEAR_BATTLEFIELD_DROP_CHANCE
	match data.category:
		EnemyData.Category.ELITE:
			chance = Balance.GEAR_BATTLEFIELD_ELITE_CHANCE
		EnemyData.Category.BOSS:
			chance = Balance.GEAR_BATTLEFIELD_BOSS_CHANCE
	if RunState.rng("gear").randf() > chance:
		return
	var tier: CampaignTierData = RunState.tier()
	var tier_order: int = tier.order if tier != null else 0
	var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), tier_order,
		RunState.rng("gear"))
	if not piece.is_empty():
		_field.spawn_gear(piece, global_position)


func _tick_death(delta: float) -> void:
	_death_left -= delta
	if _death_left <= 0.0:
		queue_free()
		return
	var t: float = _death_left / Balance.ENEMY_DEATH_FADE
	sprite.modulate = Color(1.0, 1.0, 1.0, t)


## Mass drives how heavily this thing moves. Derived rather than authored, so
## the enemy `.tres` files did not all need a new field.
func _mass_for_category() -> float:
	match data.category:
		EnemyData.Category.ELITE:
			return Balance.ANIM_MASS_ELITE
		EnemyData.Category.BOSS:
			return Balance.ANIM_MASS_BOSS
		_:
			return lerpf(Balance.ANIM_MASS_BREED, Balance.ANIM_MASS_ELITE,
				clampf((data.body_radius - Balance.ENEMY_BODY_RADIUS) / 24.0, 0.0, 0.45))


func _apply_category_scale() -> void:
	var visual_scale: float = Balance.ENEMY_SPRITE_SCALE
	var reference_height: float = 96.0
	match data.category:
		EnemyData.Category.ELITE:
			visual_scale = Balance.ELITE_SPRITE_SCALE
			reference_height = 128.0
		EnemyData.Category.BOSS:
			visual_scale = Balance.BOSS_SPRITE_SCALE
			reference_height = float(sprite.texture.get_height()) if sprite.texture != null else 384.0
	if sprite.texture != null:
		visual_scale *= reference_height / maxf(float(sprite.texture.get_height()), 1.0)
	sprite.scale = Vector2.ONE * visual_scale
	if health_bar != null and sprite.texture != null:
		health_bar.position.y = -sprite.texture.get_height() * visual_scale * 0.46


func _build_aura_readout() -> void:
	if data.aura_radius <= 0.0:
		return
	var ring := Line2D.new()
	var points: PackedVector2Array = []
	for i: int in 49:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 48.0) * data.aura_radius)
	ring.points = points
	ring.width = 2.0
	ring.default_color = Color(0.95, 0.42, 0.22, 0.22)
	ring.z_index = -1
	add_child(ring)


## An active Howler turns a loose pack into an urgent escort target. The first
## valid aura is enough; overlapping Howlers do not compound into a speed spike.
func _nearby_howler() -> Enemy:
	if _field == null:
		return null
	for enemy: Enemy in _field.enemies_near(global_position, Balance.HOWLER_SEARCH_RADIUS):
		if enemy == self or enemy.data == null or enemy.is_dying():
			continue
		if enemy.data.role == EnemyData.Role.HOWLER \
				and global_position.distance_to(enemy.global_position) <= enemy.data.aura_radius:
			return enemy
	return null


func _update_sprite() -> void:
	# A walking enemy faces the way it is walking. A fighting enemy faces what it
	# is hitting. Those are different questions and the state answers which one
	# applies, because the two only agree on a straight approach.
	#
	# This used to ask about the target first, which meant an enemy that had
	# acquired something walked the rest of its leg backwards whenever the road
	# bent away from it - the lock outranked the legs. Motion now wins while
	# WALKING, and only WALKING moves under its own power, so the target branch
	# still covers the windup, the strike, the recovery and the knockback slide,
	# where facing the victim is right and facing the slide is not.
	#
	# Thresholded rather than tested against zero: an enemy tracking a bend drifts
	# a fraction of a unit either way on the x axis, and a bare sign test would
	# make it shudder between facings every frame. Below the threshold the facing
	# is left alone rather than reset, so a road running straight up the screen
	# does not blank it.
	if _state == State.WALKING and absf(_motion.x) > Balance.FACING_DEADZONE:
		sprite.flip_h = _motion.x < 0.0
	elif _target != null and is_instance_valid(_target):
		sprite.flip_h = _target.global_position.x < global_position.x

	var tint: Color = Color.WHITE
	if _freeze_left > 0.0:
		tint = Color(0.55, 0.80, 1.0)
	elif _chill > 0.02:
		# Deepens with the meter rather than being on or off, so a player can see
		# a shatter building and read a second frost tower as doing something.
		tint = Color.WHITE.lerp(Color(0.62, 0.84, 1.0), _chill)
	if _burn_left > 0.0:
		tint = tint.lerp(Color(1.0, 0.55, 0.25), 0.5)
	# The wind-up tell overrides every other tint, because it is the one the
	# player has to read.
	if _state == State.WINDUP:
		var pulse: float = 0.5 + 0.5 * sin(_state_left * 34.0)
		tint = Color(1.0, 0.45, 0.35).lerp(Color(1.0, 0.95, 0.7), pulse)
	if _flash_left > 0.0:
		tint = Balance.HIT_FLASH_COLOUR.lerp(tint, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)
	sprite.modulate = tint
