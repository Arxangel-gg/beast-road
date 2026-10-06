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

## Whose weapon this is, set by the hero every tick like the multiplier above.
## A partner's Warden on this machine swings the weapon its own player wears -
## the kind arrives over the wire (`Hero.gear_kinds`) - where it used to read
## this machine's stash and swing with its reach and pace (2026-09-26).
var own_stash: bool = true
var partner_weapon: String = ""
## The swinging Warden's sheet when it is not this machine's (`Hero.sheet`),
## handed down by the hero: their Swiftness, form, nodes and shove. Null reads
## this machine's own account, as every swing always did. A number the hero
## sets, like `drag` - this class still does not know what a `Hero` is.
var sheet: WardenSheet = null

## **How much longer every phase takes**, set by the hero from where it is
## standing. One at the ordinary pace; above one is slower.
##
## Deep water is the only thing that sets it today (owner, 2026-09-16: a flooded
## hero "should still be able to attack but at a much slower rate"). It lives
## here as a plain number rather than as a `Hero` reference because this object
## is a pure state machine and does not know what a Hero is - the same
## arrangement `damage_multiplier` above already uses.
var drag: float = 1.0

## Whether this swing's radiant splash has gone off - once a swing, like the
## announcement.
var _radiant_done: bool = false

var _phase: Phase = Phase.READY
## **The chain is thrown this tick**: the form is a thrown one and the owner
## can pay a bolt. Set by the hero every tick from its own form and pool, so a
## partner body throws by its own sheet and a drained pool swings steel.
var thrown: bool = false
## The bolt of this swing has left; the rest of its active window sweeps nothing.
var _thrown_this_swing: bool = false
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

## Whether the current swing has been announced. See `_strike`.
var _announced: bool = false


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
## **Everything that stretches or shortens a swing, in one place.**
##
## The windup, the active and the recovery each multiplied these by hand, which
## gave a new factor three chances to be added and two to be forgotten. That is
## the fault an Arcane node shipped with when its reach reached four of five
## throws.
func _phase_scale() -> float:
	return _swiftness_scale() * _weapon_scale() * _haste_scale() * maxf(drag, 0.01)


func _haste_scale() -> float:
	var scale: float = Balance.HERO_EVADE_HASTE_SCALE if _evade_haste_left > 0.0 else 1.0
	return scale * _fury_scale()


## Snaps Rising Fury to its cap. Second Wind's whole effect.
##
## A method rather than the hero writing `_fury_seconds` from outside: the ramp
## and its reset window belong to this file, and a caller setting the timer
## directly would be a second place that knows how fury is measured.
func fill_fury() -> void:
	_fury_seconds = maxf(_fury_seconds, Balance.RISING_FURY_RAMP_SECONDS)
	_fury_idle = 0.0


## How far up the ramp Rising Fury currently is, 0 to 1.
##
## Public because it is the one number Second Wind changes, and a gate that had
## to infer it from a swing interval would be measuring three other multipliers
## at the same time.
func fury_ramp() -> float:
	return clampf(_fury_seconds / maxf(Balance.RISING_FURY_RAMP_SECONDS, 0.001), 0.0, 1.0)


## Rising Fury's share, as a phase multiplier: 1.0 cold, and at the cap the
## authored fraction faster. Multiplied with the evade haste rather than
## replacing it, so a perfect dodge inside a long fight still reads as an event.
##
## Capped by construction - the ramp is clamped at 1 - because the node says
## "to a hard cap" and an attack speed that kept climbing while the player kept
## swinging would be a second power scale beside levelling and gear.
func _fury_scale() -> float:
	var gain: float = WardenSheet.trained_value_of(sheet, "active_attack_speed")
	if gain <= 0.0:
		return 1.0
	var ramp: float = clampf(_fury_seconds / maxf(Balance.RISING_FURY_RAMP_SECONDS, 0.001),
		0.0, 1.0)
	return 1.0 / (1.0 + gain * ramp)


func _swiftness_scale() -> float:
	var points: int = WardenSheet.attribute_of(sheet, RunState.Attribute.SWIFTNESS)
	return 1.0 / (1.0 + float(points) * Balance.HERO_SWIFTNESS_ATTACK_PER_POINT)


## The weapon in hand, or null when the slot is empty. Read per swing rather
## than cached: equipment cannot change mid-combat, so there is nothing to gain
## by holding a copy, and a copy is one more thing that can go stale.
func _weapon() -> GearData:
	if not own_stash:
		return ContentDB.gear(partner_weapon) if not partner_weapon.is_empty() else null
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
			_phase_left += Balance.HERO_ATTACK_ACTIVE[_step] * _phase_scale()
		Phase.ACTIVE:
			_phase = Phase.RECOVERY
			_phase_left += Balance.HERO_ATTACK_RECOVERY[_step] * _phase_scale()
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
	_phase_left = Balance.HERO_ATTACK_WINDUP[_step] * _phase_scale()
	_swing_aim = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	_buffer_left = 0.0
	_chain_left = 0.0
	_hit_ids.clear()
	_announced = false
	_radiant_done = false
	_thrown_this_swing = false
	# A thrown chain does not lunge: the blow travels, the body stands.
	if not (thrown and _form_is_thrown()):
		lunge_requested.emit(_swing_aim, Balance.HERO_ATTACK_LUNGE[_step])
	# Announced on the swing, not on the hit. Feedback for an action the player
	# took has to happen even when the action accomplishes nothing.
	EventBus.hero_swing_started.emit(_step, _swing_origin)


## Which blow of the chain the next swing would be.
##
## Each step has its own reach and arc, so a tell drawn at the wrong one marks
## the wrong bodies - and the step is private, which is why this exists.
func next_step() -> int:
	return _step


## **Who the next swing would land on**, asked before it is thrown.
##
## Owner, 2026-09-18: the bodies *"a player is within range of hitting with
## their next melee attack"* should be highlighted - and only those, aimed
## where the player is aiming.
##
## **It is the strike's own rule, lifted rather than copied.** A highlight
## computed a second way is a promise the swing does not keep: it would mark a
## body the blow misses, or miss one the blow lands on, and a tell that lies
## about the blow is worse than no tell. So `_strike` now asks this too, and
## the two cannot disagree about reach, arc, or what counts as a body.
##
## `step` is which blow of the chain is next, since each has its own reach and
## arc. Wildlife is included because the owner asked for it and because a
## swing genuinely hits it.
func would_hit(origin: Vector2, aim: Vector2, step: int) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var at: int = clampi(step, 0, Balance.HERO_ATTACK_RANGE.size() - 1)
	var reach: float = Balance.HERO_ATTACK_RANGE[at] * reach_scale()
	var half_arc: float = deg_to_rad(Balance.HERO_ATTACK_ARC_DEGREES[at] * 0.5)
	# **The tread group is every walking body in the game** - it was built for
	# the ground VFX and it is exactly the roll call this needs, so wildlife
	# needs no group of its own. The player's own are filtered below.
	var seen: Dictionary = {}
	for group: StringName in [Enemy.GROUP, Footfalls.GROUP]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var body := node as Node2D
			if body == null or not is_instance_valid(body):
				continue
			if body is Hero or body is Companion or body is MountRig:
				continue
			if seen.has(body.get_instance_id()):
				continue
			var enemy := body as Enemy
			if enemy != null and enemy.is_dying():
				continue
			var middle: Vector2 = _middle_of(body)
			var wide: float = _width_of(body)
			var to: Vector2 = middle - origin
			var distance: float = to.length()
			if distance > reach + wide:
				continue
			if distance > 0.001 and absf(aim.angle_to(to)) > half_arc:
				continue
			seen[body.get_instance_id()] = true
			out.append(body)
	return out


## **Whether the next blow of the chain reaches `body` from `origin`**, aimed
## straight at it - the question a click-to-move order asks before it stops
## chasing and starts swinging (2026-10-01). The same middle, width and reach
## `would_hit` judges by, so the chase never stops short of a blow that would
## land or swings at one that cannot. `share` brings the line in a little, so a
## body stepping back as the blow comes still meets it.
func reaches(origin: Vector2, body: Node2D, share: float = 1.0) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	var at: int = clampi(_step, 0, Balance.HERO_ATTACK_RANGE.size() - 1)
	var reach: float = Balance.HERO_ATTACK_RANGE[at] * reach_scale()
	return origin.distance_to(_middle_of(body)) <= (reach + _width_of(body)) * share


## Where a body is judged from, for a swing: a road body's own middle, anything
## else's position.
static func _middle_of(body: Node2D) -> Vector2:
	var enemy := body as Enemy
	return enemy.combat_origin() if enemy != null else body.global_position


static func _width_of(body: Node2D) -> float:
	var enemy := body as Enemy
	return enemy.contact_radius() if enemy != null else Balance.ENEMY_BODY_RADIUS


## Bodies standing in this swing's arc right now, hit or not.
func _count_in_arc(reach: float, half_arc: float) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		var to: Vector2 = enemy.combat_origin() - _swing_origin
		var distance: float = to.length()
		if distance > reach + enemy.contact_radius():
			continue
		if distance > 0.001 and absf(_swing_aim.angle_to(to)) > half_arc:
			continue
		count += 1
	return count


## **Consecrated Chain**: the third hit splashes radiant damage near defenses.
## Once a swing, only when a tower stands within `DISCIPLINE_RADIANT_TOWER_REACH`
## of the Warden, onto the bodies round the blow that the swing itself missed -
## a share of the finisher, never a second finisher.
## Whether the form this body swings is a thrown one, by its own sheet.
func _form_is_thrown() -> bool:
	var form: DisciplineNodeData = WardenSheet.form_of(sheet) \
		if own_stash or sheet != null else null
	return form != null and form.form_thrown


## **One body, one blow of the chain** - the door the arc sweep and the thrown
## bolt both land through, so Open Vein, Brand of Ruin, the ledger, the
## striker's sheet and Weeping Edge cannot disagree between a swing and a
## throw. The blow dealt, or -1 if the body refused it.
func _land_on(enemy: Enemy, damage: float, knockback: float, finisher: bool,
		form: DisciplineNodeData, origin: Vector2) -> float:
	var id: int = enemy.get_instance_id()
	if _hit_ids.has(id):
		return -1.0
	# **Open Vein.** Rolled per body, because the card is about *isolated*
	# enemies and a crowd has none in it - a roll per swing would hand the
	# whole crowd one verdict.
	var blow: float = damage
	var owner := get_parent() as Node
	if owner != null and owner.has_method("telling_blow"):
		blow *= float(owner.call("telling_blow", enemy))
		if blow > damage:
			Vfx.spark(enemy.combat_origin(), Color(1.0, 0.86, 0.5), 9,
				_swing_aim, 240.0)
	# **Brand of Ruin**: the finisher strikes a branded body harder.
	if finisher and form != null and enemy.is_branded():
		blow *= 1.0 + WardenSheet.upgrade_of(sheet, form.id, "form_vs_branded")
	DamageLedger.credit_as(DamageLedger.WARDEN)
	if not enemy.take_damage(blow, origin, knockback, true, sheet):
		return -1.0
	_hit_ids[id] = true
	# **Weeping Edge**: every hit in the chain opens the Bleed, at a share of
	# the finisher's. The finisher's own is `enemy.gd`'s.
	if not finisher and form != null and form.effect_id == "bleed_finisher":
		var weep: float = WardenSheet.upgrade_of(sheet, form.id, "form_bleed_every_hit")
		if weep > 0.0:
			enemy.apply_burn(blow * form.effect_value * weep / Balance.DISCIPLINE_STATUS_SECONDS,
				Balance.DISCIPLINE_STATUS_SECONDS)
	return blow


## **The chain is thrown** (owner, 2026-10-06). On the first active frame of a
## swing whose form is thrown and whose owner can pay, the blow leaves as a
## bolt along the aim instead of sweeping an arc: the same step, the same
## damage, the same knockback, landing through `_land_on` when it meets a
## body. Returns false when the pool could not pay after all, and the swing
## is steel.
func _throw_the_chain(form: DisciplineNodeData, damage: float, knockback: float,
		finisher: bool) -> bool:
	var owner := get_parent() as Node
	if owner == null or not owner.has_method("spend_mana"):
		return false
	if not bool(owner.call("spend_mana", Balance.CHAIN_BOLT_MANA_COST)):
		return false
	var field: EnemyField = owner.get("field") as EnemyField
	if field == null:
		return false
	var bolt := HeroArrow.new()
	var tint: Color = Balance.CHAIN_BOLT_TINT
	bolt.launch_bolt(field, _swing_origin + _swing_aim * Balance.HERO_ARROW_MUZZLE,
		_swing_aim, damage, knockback,
		Balance.CHAIN_BOLT_FINISHER_PIERCE if finisher else 1, tint,
		_bolt_landed.bind(finisher, form, _step))
	field.add_child(bolt)
	Vfx.flash_at(_swing_origin + _swing_aim * Balance.HERO_ARROW_MUZZLE, tint, 22.0)
	Vfx.spark(_swing_origin + _swing_aim * Balance.HERO_ARROW_MUZZLE, tint, 6, _swing_aim, 260.0)
	EventBus.ranged_shot_fired.emit(_swing_origin, Balance.CHAIN_BOLT_TRAVEL, _swing_aim)
	return true


## A thrown blow met a body. Everything a landed swing says, said for one body:
## the form's branches, the hit, the hitstop and the shake.
func _bolt_landed(enemy: Enemy, at: Vector2, finisher: bool, form: DisciplineNodeData,
		step: int) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	var damage: float = Balance.HERO_ATTACK_DAMAGE[step] * damage_multiplier
	var knockback: float = Balance.HERO_ATTACK_KNOCKBACK[step] \
		* WardenSheet.multiplier_of(sheet, Modifiers.KNOCKBACK)
	var blow: float = _land_on(enemy, damage, knockback, finisher, form, at)
	if blow < 0.0:
		return
	if form != null and own_stash:
		_form_branches(form, finisher, 1, blow, Balance.CHAIN_BOLT_TRAVEL)
	landed.emit(step, 1, at)
	var hide: int = int(enemy.data.hide) if enemy.data != null else 0
	EventBus.hero_attack_landed.emit(step, 1, at, hide)
	EventBus.hitstop_requested.emit(Balance.HERO_ATTACK_HITSTOP[step] * 0.5
		* float(Balance.HIDE_HITSTOP_SCALE[clampi(hide, 0, Balance.HIDE_HITSTOP_SCALE.size() - 1)]))
	EventBus.camera_impact.emit(at, Balance.HERO_ATTACK_SHAKE[step] * 0.6)


func _radiant_splash(amount: float, reach: float, form: DisciplineNodeData = null) -> void:
	if _radiant_done or amount <= 0.0:
		return
	var near_tower: bool = false
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Node2D
		if tower != null and tower.global_position.distance_to(_swing_origin) \
				<= Balance.DISCIPLINE_RADIANT_TOWER_REACH:
			near_tower = true
			break
	if not near_tower:
		return
	_radiant_done = true
	var centre: Vector2 = _swing_origin + _swing_aim * reach * 0.6
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying() or _hit_ids.has(enemy.get_instance_id()):
			continue
		if enemy.combat_origin().distance_to(centre) \
				> Balance.DISCIPLINE_RADIANT_RADIUS + enemy.contact_radius():
			continue
		DamageLedger.credit_as(DamageLedger.WARDEN)
		if enemy.take_damage(amount, centre, 0.0) and form != null:
			# **Searing Light**: what the splash touches burns.
			var sear: float = WardenSheet.upgrade_of(sheet, form.id, "form_splash_burn")
			if sear > 0.0:
				enemy.apply_burn(amount * sear / Balance.DISCIPLINE_STATUS_SECONDS,
					Balance.DISCIPLINE_STATUS_SECONDS)
	Vfx.ring(centre, Balance.DISCIPLINE_RADIANT_RADIUS, Color("ffe7a3"), 0.4, 4.0)
	# **Bastion Hymn**: the splash also wards the nearest tower.
	if form != null:
		var hymn: float = WardenSheet.upgrade_of(sheet, form.id, "form_splash_shield")
		if hymn > 0.0:
			var nearest: Node2D = null
			var best: float = INF
			for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
				var tower := node as Node2D
				if tower != null and tower.global_position.distance_to(_swing_origin) < best:
					best = tower.global_position.distance_to(_swing_origin)
					nearest = tower
			if nearest != null and nearest.has_method("ward"):
				nearest.call("ward", hymn)
				Vfx.ring(nearest.global_position, 60.0, Color("ffe7a3"), 0.4, 4.0)


## **What the form's branches and the Oath do once a swing has landed**, each
## a door on the hero called by name so this file still does not know what a
## `Hero` is. `dealt` is what the swing took off every body it struck.
func _form_branches(form: DisciplineNodeData, finisher: bool, hits: int, dealt: float,
		reach: float) -> void:
	var owner := get_parent() as Node
	if owner == null:
		return
	# The Red Road heals on every swing; the Red Draught on the finisher.
	var heal: float = WardenSheet.boon_of(sheet, "oath_lifesteal")
	if finisher:
		heal += WardenSheet.upgrade_of(sheet, form.id, "form_finisher_heal")
	if heal > 0.0 and owner.has_method("heal_unscaled"):
		owner.call("heal_unscaled", dealt * heal)
	if not finisher:
		return
	# Spellblade's own refund, and its branches.
	var refund: float = WardenSheet.upgrade_of(sheet, form.id, "form_finisher_mana")
	if form.effect_id == "form_finisher_mana":
		refund += form.effect_value
	if refund > 0.0 and owner.has_method("refund_mana_share"):
		owner.call("refund_mana_share", refund)
	var dash: float = WardenSheet.upgrade_of(sheet, form.id, "form_finisher_dash_refund")
	if dash > 0.0 and owner.has_method("refund_dash"):
		owner.call("refund_dash", dash * float(hits) / maxf(Balance.HERO_DASH_COOLDOWN, 0.01))
	if WardenSheet.upgrade_of(sheet, form.id, "form_finisher_cast_discount") > 0.0 \
			and owner.has_method("note_finisher_landed"):
		owner.call("note_finisher_landed")
	var bolt: float = WardenSheet.upgrade_of(sheet, form.id, "form_finisher_bolt")
	if bolt > 0.0:
		_arc_bolt(dealt / float(maxi(hits, 1)) * bolt, reach)


## **Arc Bolt**: the finisher throws a bolt at the nearest body beyond its
## reach that it did not strike.
func _arc_bolt(blow: float, reach: float) -> void:
	var target: Enemy = null
	var best: float = reach * Balance.DISCIPLINE_BOLT_REACH_SCALE
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying() or _hit_ids.has(enemy.get_instance_id()):
			continue
		var apart: float = enemy.combat_origin().distance_to(_swing_origin)
		if apart < best:
			best = apart
			target = enemy
	if target == null:
		return
	Vfx.streak(_swing_origin, target.combat_origin(), 0.12, Color(0.62, 0.8, 1.0), "air", 12.0)
	DamageLedger.credit_as(DamageLedger.WARDEN)
	target.take_damage(blow, _swing_origin, 0.0, true, sheet)


func _strike() -> void:
	var reach: float = Balance.HERO_ATTACK_RANGE[_step] * reach_scale()
	var half_arc: float = deg_to_rad(Balance.HERO_ATTACK_ARC_DEGREES[_step] * 0.5)
	var damage: float = Balance.HERO_ATTACK_DAMAGE[_step] * damage_multiplier
	var knockback: float = Balance.HERO_ATTACK_KNOCKBACK[_step] * WardenSheet.multiplier_of(sheet, Modifiers.KNOCKBACK)
	var hits: int = 0
	var struck_hide: int = -1
	# **The chain's form**, read for the Warden this machine plays: a partner's
	# form is their account's, and it is not on this machine to read.
	var form: DisciplineNodeData = WardenSheet.form_of(sheet) \
		if own_stash or sheet != null else null
	var finisher: bool = _step >= Balance.HERO_CHAIN_LENGTH - 1
	# **A thrown form looses the blow once**, on the first active frame, and
	# the rest of the window sweeps nothing: the bolt is the swing. A pool that
	# cannot pay after all makes this swing steel, which is the only way a
	# press can ever do nothing.
	if _thrown_this_swing:
		return
	if thrown and form != null and form.form_thrown:
		if _throw_the_chain(form, damage, knockback, finisher):
			_thrown_this_swing = true
			_announced = true
			return
	# **Wide Cleave**: the finisher's arc is wider.
	if finisher and form != null:
		half_arc *= 1.0 + WardenSheet.upgrade_of(sheet, form.id, "form_finisher_arc")
	var dealt: float = 0.0
	# **Cleaving Road**: the wide third hit gains force for each enemy struck.
	# Counted across the whole arc before any blow lands, so the first body is
	# shoved as hard as the last; capped, so a packed road is a wall moved rather
	# than a wall thrown off the map.
	if finisher and form != null and form.effect_id == "crowd_finisher_force":
		var crowd: int = _count_in_arc(reach, half_arc)
		knockback *= 1.0 + form.effect_value \
			* float(clampi(crowd - 1, 0, Balance.DISCIPLINE_CLEAVE_CROWD_CAP))

	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		var id: int = enemy.get_instance_id()
		if _hit_ids.has(id):
			continue
		# **The body from its feet to its chest, not a point on it** (see
		# `Hitbox`, 2026-10-01). Measured to the floor, aiming at a chest
		# missed; measured to the chest alone, a giant was hard to reach from
		# its south and easy from its north. The nearest point of its stroke is
		# where this swing meets it, and the bearing the arc judges.
		var to: Vector2 = Hitbox.meet(enemy, _swing_origin) - _swing_origin
		var distance: float = to.length()
		if distance > reach + enemy.contact_radius():
			continue
		# An enemy standing on top of the hero has no meaningful bearing, so it
		# is always in the arc rather than sometimes unhittable.
		if distance > 0.001 and absf(_swing_aim.angle_to(to)) > half_arc:
			continue
		var blow: float = _land_on(enemy, damage, knockback, finisher, form, _swing_origin)
		if blow < 0.0:
			continue
		hits += 1
		dealt += blow
		# The first body struck decides what the hit sounds and looks like.
		if struck_hide < 0 and enemy.data != null:
			struck_hide = int(enemy.data.hide)

	# Announced whether or not it connected, and *before* the early return: a
	# swing that touched no enemy is still a swing, and something small standing
	# in front of the hero should know about it.
	#
	# **Once.** This function runs on every frame of the active window, so a
	# body that steps in mid-swing is still hit - and the announcement ran on
	# every one of those frames too: six at sixty frames a second, eighteen
	# on a 180 Hz tick. Each drew a blade, a ribbon, motes and a forged hit,
	# and each wounded an animal in front of the hero. Reported as a fan of
	# knives (owner, 2026-09-26).
	if not _announced:
		_announced = true
		var held: GearData = _weapon()
		EventBus.hero_swing_resolved.emit(_swing_origin, _swing_aim, reach, _step,
			held.id if held != null else "", own_stash)
	# **No Ground Given** is spent by the blow it paid for, whether or not that
	# blow found anything. A bonus that survived a missed finisher would be a
	# bonus the player keeps until it is convenient.
	if _step >= Balance.HERO_CHAIN_LENGTH - 1:
		var owner := get_parent() as Node
		if owner != null and owner.has_method("spend_guard"):
			owner.call("spend_guard")
	if hits == 0:
		return
	if finisher and form != null and form.effect_id == "defense_radiant_finisher":
		_radiant_splash(damage * form.effect_value, reach, form)
	if form != null and own_stash:
		_form_branches(form, finisher, hits, dealt, reach)
	landed.emit(_step, hits, _swing_origin)
	var hide: int = maxi(struck_hide, 0)
	EventBus.hero_attack_landed.emit(_step, hits, _swing_origin, hide)
	# Armour holds the blade a beat longer than flesh; a spirit barely does.
	EventBus.hitstop_requested.emit(Balance.HERO_ATTACK_HITSTOP[_step]
		* float(Balance.HIDE_HITSTOP_SCALE[clampi(hide, 0, Balance.HIDE_HITSTOP_SCALE.size() - 1)]))
	EventBus.camera_shake_requested.emit(Balance.HERO_ATTACK_SHAKE[_step], Balance.HIT_FLASH_TIME * 2.0)
