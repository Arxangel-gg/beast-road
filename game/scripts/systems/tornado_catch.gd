class_name TornadoCatch
extends Node

## **The funnel pulls, lifts and throws** (owner, 2026-09-30: *"Tornados ...
## should cause nearby characters to get pulled closer to it a bit, some might
## be able to outpace it if further, some might get pulled into it and take
## damage as they spin around in it and up the funnel and eventually getting
## thrown out in their momentum's direction once reaching the top of the
## tornado, if they're still alive by the that is, and even taking a bit of fall
## damage with juicy landing vfx"*).
##
## One node a funnel, run on the host only - the funnel's own `_mirror` rule.
##
## - **The pull** falls from `TORNADO_PULL_SPEED` at the wake's edge to nothing
##   at `TORNADO_PULL_REACH`. A Warden walks at 200 and outpaces it from
##   anywhere but the very edge; the roster walks at 28 to 68 and is dragged in.
## - **The catch**: a body that reaches `TORNADO_CATCH_RADIUS` is carried round
##   the funnel and up it for `TORNADO_LIFT_SECONDS`, hurt as the wake hurts, and
##   then thrown out along the way it was spinning - its momentum - landing
##   `TORNADO_THROW_DISTANCE` away after `TORNADO_THROW_SECONDS` with a fall's
##   damage, dust, a ring and a weighted shake.
## - **While aloft a body's own processing stands still** (`process_mode`
##   disabled): its walk, its swing and its stride would fight the hand that is
##   carrying it, and an enemy's hitstun is capped by design so it cannot hold
##   one. Its health still answers every blow, and a body that falls while aloft
##   is let go on the spot.
##
## **Never lifted**: a boss, a camp lord, a Warden inside the walls, and anything
## let go within `TORNADO_RECATCH_SECONDS` - so a body thrown out is not caught
## again on the way down. At most `TORNADO_CATCH_MAX` at once.

var funnel: Node2D = null
var field: Battlefield = null

## Body instance id to its flight: {body, t, angle, ground, phase, land_from,
## land_to, throw_t, spin, kept_rotation}.
var _aloft: Dictionary = {}
## Body instance id to the time it was let go.
var _let_go: Dictionary = {}
var _clock: float = 0.0


func _ready() -> void:
	name = "TornadoCatch"
	# After the bodies have moved, so the carried position is the last word.
	process_priority = 100
	process_physics_priority = 100


## **A body carried by any funnel wears this**, so a second funnel standing
## beside the first cannot pick it up too. Two funnels at once was real: the
## sky refuses a second *warning* while one is pending and nothing refused a
## second funnel while one *stood*, and a body at the heart of both was lifted
## by both - hurt twice over, moved by two hands, and the second catch
## recorded "disabled" as the mode to put it back to, because the first had
## already switched it off. Whichever let go last left it switched off for
## ever: alive, a body standing still in its walking pose; dead, a corpse in
## `DYING` whose fade never ticked and whose free never came - out of the
## roster, untargetable, and on the field for the rest of the run. That is the
## owner's report of 2026-10-06 ("potentially died but kept walking ...
## untargetable by towers and players"), reproduced by `tornado_ghost_trace`.
const CARRIED_META: StringName = &"tornado_carried"


## Whether a body is being carried, for the funnel's own blows to pass it over.
func carries(body: Node) -> bool:
	return body != null and _aloft.has(body.get_instance_id())


func _process(delta: float) -> void:
	if funnel == null or not is_instance_valid(funnel) or field == null:
		_release_all()
		return
	_clock += delta
	var at: Vector2 = funnel.get("at") as Vector2
	_pull(at, delta)
	_carry(at, delta)


func _pull(at: Vector2, delta: float) -> void:
	for body: Node2D in _bodies(at, Balance.TORNADO_PULL_REACH):
		if carries(body):
			continue
		var offset: Vector2 = at - body.global_position
		var apart: float = offset.length()
		if apart < 1.0:
			continue
		if apart <= Balance.TORNADO_CATCH_RADIUS and _may_lift(body):
			_catch(body, at)
			continue
		var share: float = clampf((Balance.TORNADO_PULL_REACH - apart)
			/ maxf(Balance.TORNADO_PULL_REACH - Balance.TORNADO_WAKE, 1.0), 0.0, 1.0)
		var step: Vector2 = offset / apart * Balance.TORNADO_PULL_SPEED * share * delta
		if step.length() > apart:
			step = offset
		if body is Enemy:
			(body as Enemy).drift(step)
		elif body is Hero:
			(body as Hero).drift(step)


func _bodies(at: Vector2, reach: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero == null or not is_instance_valid(hero) or not hero.is_alive():
			continue
		if field.inside_city(hero.global_position):
			continue
		if hero.global_position.distance_to(at) <= reach:
			out.append(hero)
	for enemy: Enemy in field.enemies_near(at, reach):
		if is_instance_valid(enemy) and not enemy.is_dying():
			out.append(enemy)
	return out


func _may_lift(body: Node2D) -> bool:
	if _aloft.size() >= Balance.TORNADO_CATCH_MAX:
		return false
	var id: int = body.get_instance_id()
	if _let_go.has(id) and _clock - float(_let_go[id]) < Balance.TORNADO_RECATCH_SECONDS:
		return false
	# Another funnel's, or switched off by something that is not a funnel at
	# all: in either case not ours to lift. A dying body is a corpse, and a
	# corpse is not lifted either - the broadphase refuses it, but the hero
	# list beside it does not.
	if body.has_meta(CARRIED_META) or body.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	if body is Enemy:
		var data: EnemyData = (body as Enemy).data
		if data == null or data.category == EnemyData.Category.BOSS \
				or data.category == EnemyData.Category.CAMP_LORD \
				or (body as Enemy).is_dying():
			return false
	return true


func _catch(body: Node2D, at: Vector2) -> void:
	if body is Hero:
		(body as Hero).throw_from_saddle()
	var sprite: Node2D = body.get("sprite") as Node2D
	# **Never remember "disabled" as the mode to go back to.** `_may_lift`
	# refuses a disabled body, so this cannot happen through the front door;
	# it is the second bound on the same fault, for whatever door comes next.
	var kept: Node.ProcessMode = body.process_mode
	if kept == Node.PROCESS_MODE_DISABLED:
		kept = Node.PROCESS_MODE_INHERIT
	_aloft[body.get_instance_id()] = {
		"body": body, "t": 0.0, "angle": (body.global_position - at).angle(),
		"phase": 0, "kept_rotation": sprite.rotation if sprite != null else 0.0,
		"kept_mode": kept,
	}
	body.set_meta(CARRIED_META, true)
	body.process_mode = Node.PROCESS_MODE_DISABLED
	Sfx.play_at("sfx_tornado", body.global_position, 2.0)
	Vfx.dust(body.global_position, Color(0.42, 0.36, 0.28), 6, 40.0)


func _carry(at: Vector2, delta: float) -> void:
	for id: Variant in _aloft.keys():
		var flight: Dictionary = _aloft[id]
		var body := flight["body"] as Node2D
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			_aloft.erase(id)
			continue
		if not _alive(body):
			_drop(id, body, false)
			continue
		flight["t"] = float(flight["t"]) + delta
		var sprite: Node2D = body.get("sprite") as Node2D
		if int(flight["phase"]) == 0:
			var rise: float = clampf(float(flight["t"]) / Balance.TORNADO_LIFT_SECONDS, 0.0, 1.0)
			# Round the way the funnel turns (`Tornado.turning`).
			flight["angle"] = float(flight["angle"]) + Balance.TORNADO_CARRY_SPIN * _turning() * delta
			var ring: float = lerpf(Balance.TORNADO_CATCH_RADIUS, Balance.TORNADO_WAKE * 1.2, rise)
			var ground: Vector2 = at + Vector2.from_angle(float(flight["angle"])) * ring * Vector2(1.0, 0.5)
			var lift: float = Balance.TORNADO_LIFT_HEIGHT * (rise * (2.0 - rise))
			body.global_position = ground - Vector2(0.0, lift)
			flight["ground"] = ground
			if sprite != null:
				sprite.rotation += Balance.TORNADO_CARRY_SPIN * 1.6 * _turning() * delta
			_hurt_aloft(body, delta)
			if rise >= 1.0:
				# Thrown out along the way it was spinning: the tangent.
				var tangent: Vector2 = Vector2.from_angle(float(flight["angle"]) + PI * 0.5 * _turning())
				var land: Vector2 = ground + tangent * Balance.TORNADO_THROW_DISTANCE
				if field.has_method("hold_inside"):
					land = field.hold_inside(land)
				flight["phase"] = 1
				flight["throw_t"] = 0.0
				flight["land_from"] = ground
				flight["land_to"] = land
				flight["from_lift"] = lift
		else:
			flight["throw_t"] = float(flight["throw_t"]) + delta
			var s: float = clampf(float(flight["throw_t"]) / Balance.TORNADO_THROW_SECONDS, 0.0, 1.0)
			var ground: Vector2 = (flight["land_from"] as Vector2).lerp(flight["land_to"] as Vector2, s)
			var height: float = lerpf(float(flight["from_lift"]), 0.0, s) \
				+ Balance.TORNADO_THROW_ARC * 4.0 * s * (1.0 - s)
			body.global_position = ground - Vector2(0.0, height)
			if sprite != null:
				sprite.rotation += Balance.TORNADO_CARRY_SPIN * 0.8 * _turning() * delta
			if s >= 1.0:
				_land(id, body)


## The wake's own blow, for a body the wake is carrying.
func _hurt_aloft(body: Node2D, delta: float) -> void:
	if body is Enemy:
		var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
			Balance.WAVE_ACT_HP_SCALE.size() - 1)]
		DamageLedger.credit_as(DamageLedger.EARTH)
		(body as Enemy).take_damage(Balance.TORNADO_WAKE_DPS * act_scale * delta, body.global_position, 0.0)
	elif body is Hero:
		var health: Health = (body as Hero).health
		if health != null and health.accepts_damage():
			var amount: float = health.max_hp * Balance.TORNADO_HERO_SHARE_PER_SECOND * delta
			RunState.note_blow("a tornado", amount)
			EarthHand.open()
			health.take_damage(amount, body.global_position)
			EarthHand.close()


func _land(id: Variant, body: Node2D) -> void:
	var at: Vector2 = body.global_position
	_drop(id, body, true)
	# **The fall**, with the landing it deserves.
	if body is Enemy:
		var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
			Balance.WAVE_ACT_HP_SCALE.size() - 1)]
		DamageLedger.credit_as(DamageLedger.EARTH)
		(body as Enemy).take_damage(Balance.TORNADO_FALL_DAMAGE * act_scale, at, 0.0)
	elif body is Hero:
		var health: Health = (body as Hero).health
		if health != null and health.accepts_damage():
			var amount: float = health.max_hp * Balance.TORNADO_FALL_HERO_SHARE
			RunState.note_blow("a tornado's fall", amount)
			EarthHand.open()
			health.take_damage(amount, at)
			EarthHand.close()
	Vfx.dust(at, Color(0.45, 0.38, 0.3), 10, 70.0)
	Vfx.ring(at, 80.0, Color(0.85, 0.78, 0.66, 0.7), 0.35, 4.0)
	Vfx.forge_hit("earth", at, 120.0, Color(0.8, 0.7, 0.55))
	EventBus.camera_impact.emit(at, Balance.TORNADO_LANDING_IMPACT)
	Sfx.play_at("sfx_hit_stone_1", at, 2.0)


func _drop(id: Variant, body: Node2D, upright: bool) -> void:
	var flight: Dictionary = _aloft.get(id, {})
	_aloft.erase(id)
	_let_go[id] = _clock
	if body == null or not is_instance_valid(body):
		return
	if flight.has("ground") and not upright:
		body.global_position = flight["ground"] as Vector2
	# A body let go always processes again: a frozen one is the ghost above.
	var back: Node.ProcessMode = flight.get("kept_mode", Node.PROCESS_MODE_INHERIT) as Node.ProcessMode
	if back == Node.PROCESS_MODE_DISABLED:
		back = Node.PROCESS_MODE_INHERIT
	body.process_mode = back
	if body.has_meta(CARRIED_META):
		body.remove_meta(CARRIED_META)
	var sprite: Node2D = body.get("sprite") as Node2D
	if sprite != null:
		sprite.rotation = float(flight.get("kept_rotation", 0.0))


func _alive(body: Node2D) -> bool:
	if body is Enemy:
		return not (body as Enemy).is_dying()
	if body is Hero:
		return (body as Hero).is_alive()
	return false


## Everybody down, where they are. A funnel that dies mid-carry does not leave
## a body hanging in the air with its processing switched off.
func _release_all() -> void:
	for id: Variant in _aloft.keys():
		var body := (_aloft[id] as Dictionary).get("body") as Node2D
		if body != null and is_instance_valid(body):
			_drop(id, body, false)
	_aloft.clear()


func _exit_tree() -> void:
	_release_all()


## Which way the funnel turns, 1 or -1.
func _turning() -> float:
	if funnel == null or not is_instance_valid(funnel):
		return 1.0
	var way: Variant = funnel.get("turning")
	return float(way) if way != null else 1.0
