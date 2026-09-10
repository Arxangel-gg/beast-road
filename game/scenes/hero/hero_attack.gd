class_name HeroAttack
extends Node

## The hero's 3-hit melee chain (GDD §3.1).
##
## A pure state machine: it does not know what a Hero is. The hero ticks it and
## hands it an aim direction and an origin, and it reports back through signals.
## Keeping it acyclic means neither script has to resolve the other's class, and
## the chain — the part most likely to be re-tuned twenty times — can be read on
## its own.
##
## Each hit runs windup -> active -> recovery. During `active` the arc is tested
## once per frame against every enemy it has not already hit this swing, so one
## swing hits a given enemy exactly once no matter how many frames it lasts.
##
## Two concessions to feel, both of which matter more than they look:
##   - the aim is locked when the swing starts, so the hitbox matches the
##     animation instead of tracking the mouse mid-swing
##   - a click up to HERO_ATTACK_BUFFER early is remembered, so the chain does
##     not feel like it drops inputs

enum Phase {
	READY,
	WINDUP,
	ACTIVE,
	RECOVERY,
}

## The hero should step into this swing.
signal lunge_requested(direction: Vector2, distance: float)

## A swing connected. `targets` is how many enemies it caught.
signal landed(chain_step: int, targets: int, at: Vector2)

## Multiplier applied to every swing, set by the hero from relics and buildings.
var damage_multiplier: float = 1.0

var _phase: Phase = Phase.READY
var _step: int = 0
var _phase_left: float = 0.0

## Time left in which the next click continues the chain instead of restarting it.
var _chain_left: float = 0.0

## Time left on a click that arrived before the hero could act on it.
var _buffer_left: float = 0.0

var _swing_aim: Vector2 = Vector2.RIGHT
var _swing_origin: Vector2 = Vector2.ZERO

## Instance ids already hit by the current swing.
var _hit_ids: Dictionary = {}


## Called on click. Never starts a swing directly — the buffer does that, so
## there is one path into a swing rather than two.
func request() -> void:
	_buffer_left = Balance.HERO_ATTACK_BUFFER


func cancel() -> void:
	_phase = Phase.READY
	_step = 0
	_phase_left = 0.0
	_chain_left = 0.0
	_buffer_left = 0.0
	_hit_ids.clear()


## How much faster Swiftness makes a swing, as a multiplier on its phases.
##
## Every phase scales together - wind-up, active and recovery - because
## shortening only the recovery would make the swing read as faster without the
## telegraph shortening with it, and the telegraph is what the enemy reads.
## Seconds of quickened swinging owed to a perfect evade. See `Hero`.
var _evade_haste_left: float = 0.0

## **Rising Fury.** "Sustained active combat raises attack speed to a hard cap."
##
## The node has promised that since it was authored and did nothing:
## `active_attack_speed` was one of twenty-one discipline effects with no
## consumer anywhere. Seconds of unbroken swinging, and the gap since the last
## one - both here rather than on the hero, because this is the object that
## already owns every other thing that shortens a swing.
##
## It ramps rather than switching on. A cap reached instantly is a flat buff
## wearing a condition, and the sentence says *sustained*: the reward is for
## staying in a fight, so it has to be earned across one.
var _fury_seconds: float = 0.0
var _fury_idle: float = 0.0


## Grants the reward for a perfect evade: the next swings come faster.
##
## **Speed, never damage.** Hero power is on one capped scale (working rule 7)
## and a dodge that hit harder would be a second one. What this buys is tempo -
## the window a good dodge opens is a window to *act*, and the reward is being
## able to.
func grant_haste(seconds: float) -> void:
	_evade_haste_left = maxf(_evade_haste_left, seconds)


## Folded in with Swiftness and the weapon, so every phase of the swing shortens
## together. Shortening the recovery alone would make the swing read as faster
## without its own telegraph shortening with it, which is the same mistake the
## weapon scale's comment warns about.
func _haste_scale() -> float:
	var scale: float = Balance.HERO_EVADE_HASTE_SCALE if _evade_haste_left > 0.0 else 1.0
	return scale * _fury_scale()


## Rising Fury's share, as a phase multiplier: 1.0 cold, and at the cap the
## authored fraction faster. Multiplied with the evade haste rather than
## replacing it, so a perfect dodge inside a long fight still reads as an event.
##
## Capped by construction - the ramp is clamped at 1 - because the node says
## "to a hard cap" and an attack speed that kept climbing while the player kept
## swinging would be a second power scale beside levelling and gear.
func _fury_scale() -> float:
	var gain: float = DisciplineEffects.trained_value("active_attack_speed")
	if gain <= 0.0:
		return 1.0
	var ramp: float = clampf(_fury_seconds / maxf(Balance.RISING_FURY_RAMP_SECONDS, 0.001),
		0.0, 1.0)
	return 1.0 / (1.0 + gain * ramp)


func _swiftness_scale() -> float:
	var points: int = RunState.attribute(RunState.Attribute.SWIFTNESS)
	return 1.0 / (1.0 + float(points) * Balance.HERO_SWIFTNESS_ATTACK_PER_POINT)


## The weapon in hand, or null when the slot is empty. Read per swing rather
## than cached: equipment cannot change mid-combat, so there is nothing to gain
## by holding a copy, and a copy is one more thing that can go stale.
func _weapon() -> GearData:
	var piece: Dictionary = MetaState.equipped_piece(GearData.Slot.WEAPON)
	if piece.is_empty():
		return null
	return ContentDB.gear(String(piece.get("kind", "")))


## How far this swing reaches, as a multiplier. A bare fist is the baseline.
func reach_scale() -> float:
	var weapon: GearData = _weapon()
	return 1.0 if weapon == null else weapon.reach_scale


## How much faster the weapon swings. Folded into the same phase scale as
## Swiftness, and for the same reason: every phase moves together, because
## shortening the recovery alone would make the swing read as faster without
## the telegraph shortening with it.
func _weapon_scale() -> float:
	var weapon: GearData = _weapon()
	return 1.0 if weapon == null else 1.0 / maxf(weapon.swing_scale, 0.01)


func is_swinging() -> bool:
	return _phase == Phase.WINDUP or _phase == Phase.ACTIVE


## Movement multiplier the hero should apply this frame. Recovery is left at
## full speed: the commitment is in the swing, and being able to reposition
## afterwards is what stops the chain feeling like a trap.
func move_scale() -> float:
	return Balance.HERO_ATTACK_MOVE_SCALE if is_swinging() else 1.0


func current_step() -> int:
	return _step


## Locked direction of the current swing. The hero uses this for recoil so an
## aim stick turning during active frames cannot kick the body sideways.
func swing_direction() -> Vector2:
	return _swing_aim


func tick(delta: float, aim: Vector2, origin: Vector2) -> void:
	_evade_haste_left = maxf(_evade_haste_left - delta, 0.0)
	# Swinging counts as combat; standing still does not. The idle gap is what
	# ends it, so leaving a fight loses the ramp and a dash mid-fight does not.
	if _phase == Phase.READY:
		_fury_idle += delta
		if _fury_idle >= Balance.RISING_FURY_RESET_SECONDS:
			_fury_seconds = 0.0
	else:
		_fury_idle = 0.0
		_fury_seconds += delta
	_swing_origin = origin
	_buffer_left = maxf(_buffer_left - delta, 0.0)
	if _phase == Phase.READY:
		_chain_left = maxf(_chain_left - delta, 0.0)

	if _phase != Phase.READY:
		_phase_left -= delta
		if _phase == Phase.ACTIVE:
			_strike()
		while _phase_left <= 0.0 and _phase != Phase.READY:
			_advance_phase()

	if _phase == Phase.READY and _buffer_left > 0.0:
		# The chain only continues while its window is open and there is another
		# hit in it; otherwise the click starts a fresh chain.
		var continuing: bool = _chain_left > 0.0 and _step + 1 < Balance.HERO_CHAIN_LENGTH
		_begin_swing(_step + 1 if continuing else 0, aim)
	elif _phase == Phase.READY and _chain_left <= 0.0:
		_step = 0


func _advance_phase() -> void:
	match _phase:
		Phase.WINDUP:
			_phase = Phase.ACTIVE
			_phase_left += Balance.HERO_ATTACK_ACTIVE[_step] * _swiftness_scale() * _weapon_scale() * _haste_scale()
		Phase.ACTIVE:
			_phase = Phase.RECOVERY
			_phase_left += Balance.HERO_ATTACK_RECOVERY[_step] * _swiftness_scale() * _weapon_scale() * _haste_scale()
		Phase.RECOVERY:
			_phase = Phase.READY
			_phase_left = 0.0
			_chain_left = Balance.HERO_CHAIN_WINDOW
		_:
			_phase = Phase.READY
			_phase_left = 0.0


func _begin_swing(step: int, aim: Vector2) -> void:
	_step = clampi(step, 0, Balance.HERO_CHAIN_LENGTH - 1)
	_phase = Phase.WINDUP
	_phase_left = Balance.HERO_ATTACK_WINDUP[_step] * _swiftness_scale() * _weapon_scale() * _haste_scale()
	_swing_aim = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	_buffer_left = 0.0
	_chain_left = 0.0
	_hit_ids.clear()
	lunge_requested.emit(_swing_aim, Balance.HERO_ATTACK_LUNGE[_step])
	# Announced on the swing, not on the hit. Feedback for an action the player
	# took has to happen even when the action accomplishes nothing.
	EventBus.hero_swing_started.emit(_step, _swing_origin)


func _strike() -> void:
	var reach: float = Balance.HERO_ATTACK_RANGE[_step] * reach_scale()
	var half_arc: float = deg_to_rad(Balance.HERO_ATTACK_ARC_DEGREES[_step] * 0.5)
	var damage: float = Balance.HERO_ATTACK_DAMAGE[_step] * damage_multiplier
	var knockback: float = Balance.HERO_ATTACK_KNOCKBACK[_step] * Modifiers.multiplier(Modifiers.KNOCKBACK)
	var hits: int = 0

	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		var id: int = enemy.get_instance_id()
		if _hit_ids.has(id):
			continue
		# The body, not the feet - see `EnemyField.enemies_near`. A swing arc
		# measured to the floor meant aiming at an enemy's chest missed them.
		var to: Vector2 = enemy.combat_origin() - _swing_origin
		var distance: float = to.length()
		if distance > reach + enemy.contact_radius():
			continue
		# An enemy standing on top of the hero has no meaningful bearing, so it
		# is always in the arc rather than sometimes unhittable.
		if distance > 0.001 and absf(_swing_aim.angle_to(to)) > half_arc:
			continue
		if not enemy.take_damage(damage, _swing_origin, knockback, true):
			continue
		_hit_ids[id] = true
		hits += 1

	# Announced whether or not it connected, and *before* the early return: a
	# swing that touched no enemy is still a swing, and something small standing
	# in front of the hero should know about it.
	EventBus.hero_swing_resolved.emit(_swing_origin, _swing_aim, reach, _step)
	if hits == 0:
		return
	landed.emit(_step, hits, _swing_origin)
	EventBus.hero_attack_landed.emit(_step, hits, _swing_origin)
	EventBus.hitstop_requested.emit(Balance.HERO_ATTACK_HITSTOP[_step])
	EventBus.camera_shake_requested.emit(Balance.HERO_ATTACK_SHAKE[_step], Balance.HIT_FLASH_TIME * 2.0)
