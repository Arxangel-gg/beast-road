class_name Arsenal
extends Node2D

## **The Arsenal: the hand's weapons, fired on their own clocks** (owner,
## 2026-09-27; `docs/AUTO_ARSENAL_2026-09-27.md`).
##
## *"These augments are supposed to be more like Megabonk and Tower of Babel
## ... providing new little ways of dealing damage to enemies."* One of these
## stands beside every Warden and fires the weapons at their shoulder; one
## stands on the battlefield and fires the weapons on the board and the town.
##
## **Eight patterns, once.** Orbit, seeker, chain, nova, trail, strike, on-kill
## and arc are code here; every weapon is an `ArsenalWeaponData` file.
##
## **The bounds, each held by `arsenal_check`:**
##
## - Every blow goes through `Enemy.take_damage`, named in the ledger as the card
##   that threw it, as a generated blow (`active_hero` false): a ward turns it, a
##   planted shield takes it, a puppet on a guest refuses it, and it sets off no
##   form, no Hunter's Mark and no hit signal - so a weapon never fires a weapon.
## - A hit is `hit_for`: the weapon's damage at its level, the act, the owner's
##   own damage multiplier and the Arsenal's power, and nothing else. Focus
##   shortens the cadence to the spell's cap.
## - A kill-weapon's own payload never re-fires it, and it fires at most
##   `ARSENAL_KILL_TRIGGERS_PER_SECOND` a second.
## - Everything it has in the air is a record on two canvases, never a node, and
##   there are at most `ARSENAL_RECORDS_MAX` of them.
## - It lives under its scope, so a raid's freeze holds every orb and bolt.

## The Warden this Arsenal fights beside, or null for the board's.
var hero: Hero = null
## The battlefield, for the board's Arsenal: its towers and its town.
var board: Battlefield = null

## **What it has dealt, for the gate and the debrief**: damage and hits by card.
var dealt: Dictionary = {}
var hits: Dictionary = {}
## How often each kill-weapon has been set loose, for the gate.
var kill_triggers: Dictionary = {}

var _armed: Dictionary = {}
var _records: Array[Dictionary] = []
var _glow: _Glow = null
var _clock: float = 0.0
var _redraw_left: float = 0.0
var _rearm_left: float = 0.0
var _dice := RandomNumberGenerator.new()
var _kill_window: Dictionary = {}
var _suppressing: String = ""
var _bodies_frame: int = -1
var _bodies: Array[Enemy] = []

static var _heads: Dictionary = {}
## **One hand-over a repaint** (2026-09-30; see `InkBatch`): the flat shapes,
## the light, and one textured batch for each head picture drawn this frame.
var _flat := InkBatch.new()
var _light := InkBatch.new()
var _head_batches: Dictionary = {}
## Reused rather than made a shape at a time: the jitter of a bolt and the
## spikes of a patch were a `RandomNumberGenerator.new()` each, every repaint.
var _shape_dice := RandomNumberGenerator.new()

const HEAD_FORMAT: String = "res://art/vfx/projectile_%s.png"
## A shape laid on the ground: the camera looks down and slightly along.
const GROUND: Vector2 = Vector2(1.0, 0.5)


## What one armed card is doing.
class Armed extends RefCounted:
	var card: RoadCardData = null
	var weapon: ArsenalWeaponData = null
	var level: int = 1
	var clock: float = 0.0
	var angle: float = 0.0
	## When each body was last cut by this weapon, by instance id.
	var touched: Dictionary = {}
	## Road kills counted toward a weapon that fires every so many.
	var kills: int = 0
	## Where the last trail patch was laid.
	var last_step: Vector2 = Vector2.INF
	## Arcs standing this moment, as pairs of points.
	var arcs: Array[PackedVector2Array] = []
	## A guard's stones standing this moment; -1 before the first tick sets them.
	var stones: int = -1
	## A field's next ring.
	var pulse: float = 0.0


func _ready() -> void:
	name = "Arsenal"
	# World space, so every record is drawn where it is in the scope rather than
	# turning and sliding with the Warden.
	top_level = true
	position = Vector2.ZERO
	z_as_relative = false
	z_index = Balance.VFX_Z - 1
	# **Seeded by the run and by whose Arsenal this is, never by the instance
	# id.** An instance id is a count of everything allocated before this node,
	# so a seed drawn from it made every weapon's first clock a function of
	# whether a save had been loaded: `arsenal_check` passed on a fresh profile
	# and failed on the sweep's, deterministically, on a ring whose first bite
	# was drawn in 0.4 to 2.0 seconds against a wait of 1.5 - and it failed the
	# v0.61.0 tag the same way. The tenth coin toss this project has shipped in a
	# gate's clothes, and the first worn by an allocation count.
	_dice.seed = hash("arsenal:%s:%d" % [_owner_name(), RunState.run_seed])
	_glow = _Glow.new()
	_glow.arsenal = self
	_glow.show_behind_parent = true
	_glow.material = LightKit.additive_material()
	add_child(_glow)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.augment_hand_changed.connect(rearm)
	# **A retort answers a blow** (docs/ARSENAL_DEFENSIVE_2026-09-28.md): the
	# Warden's own pool for the Arsenal at their side, and the board's two
	# announcements for the one on the board.
	if hero != null and is_instance_valid(hero) and hero.health != null:
		hero.health.damaged.connect(_on_warden_struck)
	if board != null:
		EventBus.tower_struck.connect(_on_tower_struck)
		EventBus.town_struck.connect(_on_town_struck)
	rearm()


## Whose Arsenal this is, for the dice: a Warden's by seat, or the board's.
func _owner_name() -> String:
	if hero != null and is_instance_valid(hero):
		return "warden:%d" % hero.party_slot
	return "board"


# --- The hand -----------------------------------------------------------------


## Reads which weapons this Arsenal fires, and at what level. Kept cards keep
## their clocks; a new card starts part of the way through its first cadence,
## on this Arsenal's own dice, so five weapons taken at once do not all fire on
## one frame.
func rearm() -> void:
	_rearm_left = 1.0
	var wanted: Dictionary = _held()
	for id: Variant in _armed.keys():
		if not wanted.has(id):
			_armed.erase(id)
	for id: Variant in wanted:
		var card: RoadCardData = ContentDB.road_card(String(id))
		if card == null:
			continue
		var weapon: ArsenalWeaponData = card.weapon_data()
		if weapon == null:
			continue
		var armed: Armed = _armed.get(id, null) as Armed
		if armed == null:
			armed = Armed.new()
			armed.card = card
			armed.weapon = weapon
			armed.clock = _dice.randf_range(0.2, 1.0) * weapon.cooldown
			# A field is standing the moment it is held: a ring dealt mid-wave
			# that let bodies walk through it for two seconds read as a card
			# that did nothing. Its cadence is its tick, not its cooldown.
			if weapon.pattern == ArsenalWeaponData.Pattern.FIELD:
				armed.clock = 0.0
			armed.angle = _dice.randf() * TAU
			_armed[id] = armed
		armed.level = clampi(int(wanted[id]), 1, Balance.AUGMENT_MAX_LEVEL)


## The weapon cards this Arsenal fires, by id, with their levels.
func _held() -> Dictionary:
	var out: Dictionary = {}
	if hero != null and is_instance_valid(hero):
		var seat: AugmentSeat = RunState.augment_seat(hero.party_slot)
		var levels: Dictionary = RunState.levels_of(seat)
		for id: String in RunState.hand_of(seat):
			var weapon: ArsenalWeaponData = _weapon_of(id)
			if weapon != null and weapon.anchor == ArsenalWeaponData.Anchor.WARDEN:
				out[id] = maxi(1, int(levels.get(id, 1)))
	elif board != null:
		for id: String in RunState.road_cards:
			var weapon: ArsenalWeaponData = _weapon_of(id)
			if weapon != null and weapon.anchor != ArsenalWeaponData.Anchor.WARDEN:
				out[id] = maxi(1, int(RunState.road_card_levels.get(id, 1)))
	return out


func _weapon_of(card_id: String) -> ArsenalWeaponData:
	var card: RoadCardData = ContentDB.road_card(card_id)
	return card.weapon_data() if card != null else null


## **What the HUD draws**: every armed card, its level, and how ready it is
## as a share from nought to one - the clock against the cadence for a weapon
## that fires on a clock, the stones standing for a guard, the kills counted
## for a weapon that fires every so many, and one for a weapon that is always
## on (an orbit, a trail, a field, an arc). Read by `ArsenalStrip` and by
## nothing that decides anything.
func readout() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in armed_cards():
		var armed: Armed = _armed[id]
		var weapon: ArsenalWeaponData = armed.weapon
		var share: float = 1.0
		match weapon.pattern:
			ArsenalWeaponData.Pattern.ORBIT, ArsenalWeaponData.Pattern.TRAIL, \
					ArsenalWeaponData.Pattern.FIELD, ArsenalWeaponData.Pattern.ARC:
				share = 1.0
			ArsenalWeaponData.Pattern.GUARD:
				var full: int = maxi(count_for(weapon, armed.level), 1)
				share = 1.0 if armed.stones < 0 else clampf(float(armed.stones) / float(full), 0.0, 1.0)
			ArsenalWeaponData.Pattern.ON_KILL:
				share = 1.0
			_:
				if weapon.every_kills > 0:
					share = clampf(float(armed.kills) / float(weapon.every_kills), 0.0, 1.0)
				else:
					var wait: float = maxf(cadence(weapon), 0.001)
					share = 1.0 - clampf(armed.clock / wait, 0.0, 1.0)
		out.append({"card": armed.card, "level": armed.level, "share": share})
	return out


## The cards armed right now - for the gate.
func armed_cards() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in _armed:
		out.append(String(id))
	out.sort()
	return out


# --- How hard, how often, how many --------------------------------------------


## **The one formula** (`docs/AUTO_ARSENAL_2026-09-27.md` §3): the weapon at its
## level, the act, the owner's own damage multiplier and the Arsenal's power.
func hit_for(weapon: ArsenalWeaponData, level: int) -> float:
	return weapon.damage_at(level) * Balance.arsenal_act_scale(RunState.act) \
		* owner_multiplier() * (1.0 + maxf(_value(Modifiers.ARSENAL_POWER), 0.0))


## What the owner's own blows are multiplied by: the Warden's, or the party's
## mean for the board. Might from level and gear, the form, the hand.
## **What a weapon would hit for in this Warden's hands**, for a card's face.
## The same formula as `hit_for`, read through the sheet rather than a body -
## Might from level and gear, the hand, the form and the Arsenal's power - so
## the number a card promises is the number the fight deals.
static func preview_hit(weapon: ArsenalWeaponData, level: int) -> float:
	var multiplier: float = WardenSheet.multiplier_of(null, Modifiers.HERO_DAMAGE)
	multiplier *= 1.0 + float(WardenSheet.attribute_of(null, RunState.Attribute.MIGHT)) \
		* Balance.HERO_MIGHT_PER_POINT
	var form: DisciplineNodeData = WardenSheet.form_of(null)
	if form != null:
		multiplier *= 1.0 + form.form_damage
	return weapon.damage_at(level) * Balance.arsenal_act_scale(RunState.act) * multiplier \
		* (1.0 + maxf(Modifiers.value(Modifiers.ARSENAL_POWER), 0.0))


func owner_multiplier() -> float:
	if hero != null and is_instance_valid(hero):
		return hero.damage_multiplier()
	var total: float = 0.0
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var warden := node as Hero
		if warden != null and warden.is_alive():
			total += warden.damage_multiplier()
			count += 1
	return total / float(count) if count > 0 else 1.0


## Seconds between firings: the authored cadence, sooner by the cadence catalyst
## and by Focus, never below the floor.
func cadence(weapon: ArsenalWeaponData) -> float:
	var quicker: float = maxf(_value(Modifiers.ARSENAL_HASTE), 0.0)
	if hero != null and is_instance_valid(hero):
		var focus: int = WardenSheet.attribute_of(hero.sheet, RunState.Attribute.FOCUS)
		quicker += minf(float(focus) * Balance.HERO_FOCUS_COOLDOWN_PER_POINT,
			Balance.HERO_FOCUS_COOLDOWN_CAP)
	return weapon.cooldown * maxf(1.0 - quicker, Balance.ARSENAL_CADENCE_FLOOR)


func count_for(weapon: ArsenalWeaponData, level: int) -> int:
	return maxi(weapon.count_at(level), 1) + clampi(int(round(_value(Modifiers.ARSENAL_COUNT))),
		0, Balance.ARSENAL_COUNT_CEILING)


func radius_for(weapon: ArsenalWeaponData, level: int) -> float:
	return weapon.radius_at(level) * (1.0 + maxf(_value(Modifiers.ARSENAL_AREA), 0.0))


func duration_for(weapon: ArsenalWeaponData) -> float:
	return weapon.duration * (1.0 + maxf(_value(Modifiers.ARSENAL_DURATION), 0.0))


func _value(key: String) -> float:
	if hero != null and is_instance_valid(hero):
		return WardenSheet.value_of(hero.sheet, key)
	return Modifiers.value(key)


# --- The clock ----------------------------------------------------------------


func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_clock += delta
	_rearm_left -= delta
	if _rearm_left <= 0.0:
		rearm()
	if _may_fight():
		for armed: Armed in _armed.values():
			_tick_weapon(armed, delta)
	_tick_records(delta)
	_redraw_left -= delta
	if _redraw_left <= 0.0:
		_redraw_left = 1.0 / Balance.ARSENAL_DRAW_HZ
		queue_redraw()
		_glow.queue_redraw()
	FrameProfile.add(&"arsenal", started)


## Whether there is anybody to fight for and anywhere to fight.
func _may_fight() -> bool:
	if _armed.is_empty():
		return false
	if hero != null:
		return is_instance_valid(hero) and hero.is_alive() \
			and hero.is_in_group(Hero.GROUP_ANY) and hero.field != null
	return board != null and RunState.is_command_combat()


func _field() -> EnemyField:
	if hero != null and is_instance_valid(hero):
		return hero.field
	return board


## The bodies a weapon may strike: living, and not a camp that has not been
## roused - an Arsenal that woke every camp it walked past would drag the
## outskirts onto the Warden, which is the towers' own rule for the same reason.
func bodies() -> Array[Enemy]:
	var frame: int = Engine.get_process_frames()
	if frame == _bodies_frame:
		return _bodies
	_bodies_frame = frame
	_bodies.clear()
	var field: EnemyField = _field()
	if field == null:
		return _bodies
	for enemy: Enemy in field.living_bodies():
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
			continue
		if enemy.is_camp_mob() and not enemy.is_provoked():
			continue
		_bodies.append(enemy)
	return _bodies


func _tick_weapon(armed: Armed, delta: float) -> void:
	var weapon: ArsenalWeaponData = armed.weapon
	match weapon.pattern:
		ArsenalWeaponData.Pattern.ORBIT:
			_tick_orbit(armed, delta)
			return
		ArsenalWeaponData.Pattern.RETORT:
			# Its clock is a refractory, spent by a blow rather than by time.
			armed.clock = maxf(armed.clock - delta, 0.0)
			return
		ArsenalWeaponData.Pattern.GUARD:
			_tick_guard(armed, delta)
			return
		ArsenalWeaponData.Pattern.FIELD:
			_tick_field(armed, delta)
			return
		ArsenalWeaponData.Pattern.TRAIL:
			_tick_trail(armed)
			return
		ArsenalWeaponData.Pattern.ARC:
			_tick_arc(armed, delta)
			return
		ArsenalWeaponData.Pattern.ON_KILL:
			return
	if weapon.every_kills > 0:
		if armed.kills >= weapon.every_kills and _fire(armed):
			armed.kills = 0
		return
	armed.clock -= delta
	if armed.clock > 0.0:
		return
	# **A weapon with nothing to fire at keeps its shot** and looks again soon,
	# rather than spending its cadence on an empty road.
	armed.clock = cadence(weapon) if _fire(armed) else Balance.ARSENAL_RETRY


func _fire(armed: Armed) -> bool:
	match armed.weapon.pattern:
		ArsenalWeaponData.Pattern.SEEKER:
			return _fire_seekers(armed, _anchors(armed))
		ArsenalWeaponData.Pattern.CHAIN:
			return _fire_chain(armed)
		ArsenalWeaponData.Pattern.NOVA:
			return _fire_nova(armed)
		ArsenalWeaponData.Pattern.STRIKE:
			return _fire_strikes(armed)
		ArsenalWeaponData.Pattern.WARD:
			return _fire_ward(armed)
		ArsenalWeaponData.Pattern.MEND:
			return _fire_mend(armed)
	return false


## **The towers a weapon on the board stands on: the ones near a Warden.**
##
## Measured before this was written: armed on every tower, Sentry Wisps alone
## modelled at more than the whole board by Act X, because a board of forty
## multiplied it forty times, and the Arsenal became nine tenths of the defence.
## Arming the towers within `ARSENAL_TOWER_REACH` of a Warden bounds it by a
## handful, and it does something better than a number could: where the Warden
## stands decides which stretch of wall fights harder - the Warden as the one
## who moves, which is the direction the road was set on 2026-09-22.
func armed_towers() -> Array[Tower]:
	var out: Array[Tower] = []
	if board == null:
		return out
	var wardens: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var warden := node as Hero
		if warden != null and warden.is_alive():
			wardens.append(warden.global_position)
	var reach: float = Balance.ARSENAL_TOWER_REACH * Balance.ARSENAL_TOWER_REACH
	for tower: Tower in board.all_towers():
		if tower == null or not is_instance_valid(tower) or not tower.is_vulnerable():
			continue
		for at: Vector2 in wardens:
			if at.distance_squared_to(tower.global_position) <= reach:
				out.append(tower)
				break
	return out


## Where a weapon stands: the Warden, the towers near a Warden, or the town.
func _anchors(armed: Armed) -> Array[Vector2]:
	var out: Array[Vector2] = []
	match armed.weapon.anchor:
		ArsenalWeaponData.Anchor.WARDEN:
			if hero != null and is_instance_valid(hero):
				out.append(hero.global_position)
		ArsenalWeaponData.Anchor.TOWERS:
			for tower: Tower in armed_towers():
				out.append(tower.global_position)
		ArsenalWeaponData.Anchor.TOWN:
			if board != null:
				out.append(board.town_position())
	return out


# --- The blow -----------------------------------------------------------------


## One blow from a weapon, through the one door every blow uses.
##
## **It answers the elements the way a tower's shot does** (2026-09-27), because
## the Arsenal shipped without and a Frost Shards that never soaked anything beside
## a storm tower that hits soaked bodies harder was two halves of a combo that did
## not meet. An air weapon is a storm weapon - `Tower._hit`'s own rule, every air
## tower - and hits a wet body `WET_SHOCK_DAMAGE` harder; a water weapon leaves
## what it hits wet for `WET_SECONDS`. Fire on a soaked body steams inside
## `apply_burn`, and wet chill inside the chill meter, so neither is written
## here. **Shape, never size**: each multiplies a blow already being dealt, on a
## body the world already soaked, which is the bound every status is held to.
func strike_body(armed: Armed, enemy: Enemy, amount: float, from: Vector2,
		knockback: float = -1.0) -> bool:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return false
	var weapon: ArsenalWeaponData = armed.weapon
	if weapon.element == TowerData.Element.AIR:
		amount *= enemy.shock_scale()
	enemy.mark_element(weapon.element)
	if weapon.pattern == ArsenalWeaponData.Pattern.ON_KILL:
		_suppressing = armed.card.id
	var shove: float = weapon.knockback if knockback < 0.0 else knockback
	DamageLedger.credit_as(DamageLedger.AUGMENT_PREFIX + armed.card.id)
	var landed: bool = enemy.take_damage(amount * enemy.brand_multiplier(), from, shove,
		false, hero.sheet if hero != null and is_instance_valid(hero) else null)
	_suppressing = ""
	if not landed:
		return false
	if weapon.element == TowerData.Element.WATER and is_instance_valid(enemy) \
			and not enemy.is_dying():
		enemy.apply_wet(Balance.WET_SECONDS)
	if weapon.burn_share > 0.0 and is_instance_valid(enemy) and not enemy.is_dying():
		var lasting: float = maxf(duration_for(weapon), 1.0)
		enemy.apply_burn(amount * weapon.burn_share / lasting, lasting)
	if weapon.slow < 1.0 and is_instance_valid(enemy) and not enemy.is_dying():
		enemy.apply_slow(weapon.slow, Balance.ARSENAL_SLOW_SECONDS)
	dealt[armed.card.id] = float(dealt.get(armed.card.id, 0.0)) + amount
	hits[armed.card.id] = int(hits.get(armed.card.id, 0)) + 1
	return true


# --- The defence (docs/ARSENAL_DEFENSIVE_2026-09-28.md) -------------------------


## **A ward or a mend is a share of the anchor's own pool, never a figure.** The
## authored share up its ladder, worth more by the guard catalyst, and never
## past the ceiling whatever the data or the hand say.
func guard_share(armed: Armed, ceiling: float) -> float:
	var share: float = armed.weapon.share_at(armed.level)
	share *= 1.0 + maxf(_value(Modifiers.ARSENAL_GUARD), 0.0)
	return clampf(share, 0.0, ceiling)


## A ward on the anchor. On the Warden through `Hero.grant_ward`, which the
## Kept Gate already reads; on a tower through `Tower.ward`; on the wall through
## `TownCore.ward`. Aegis of the Road spreads a Warden's ward to every Warden
## and the towers near them.
func _fire_ward(armed: Armed) -> bool:
	var weapon: ArsenalWeaponData = armed.weapon
	var share: float = guard_share(armed, Balance.ARSENAL_WARD_CEILING)
	if share <= 0.0:
		return false
	var fired: bool = false
	match weapon.anchor:
		ArsenalWeaponData.Anchor.WARDEN:
			if hero == null or not is_instance_valid(hero) or hero.health == null:
				return false
			if hero.health.shield() >= hero.health.max_hp * Balance.HEALTH_SHIELD_CEILING - 0.5:
				return false
			hero.grant_ward(share)
			_show_guard(weapon, hero.global_position, 1.0)
			fired = true
			if weapon.spread:
				for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
					var other := node as Hero
					if other != null and other != hero and other.is_alive():
						other.grant_ward(share)
						_show_guard(weapon, other.global_position, 1.0)
				for tower: Tower in _towers_near_wardens():
					tower.ward(share)
					_show_guard(weapon, tower.global_position, 0.8)
		ArsenalWeaponData.Anchor.TOWERS:
			for tower: Tower in armed_towers():
				tower.ward(share)
				_show_guard(weapon, tower.global_position, 0.8)
				fired = true
		ArsenalWeaponData.Anchor.TOWN:
			var town: Node = board.town if board != null else null
			if town != null and is_instance_valid(town) and town.has_method("ward"):
				town.call("ward", share)
				_show_guard(weapon, board.town_position(), 2.2)
				fired = true
	return fired


## A mend of a share of what the anchor is missing. **A whole anchor is mended
## by nothing**: the weapon keeps its shot and looks again soon.
func _fire_mend(armed: Armed) -> bool:
	var weapon: ArsenalWeaponData = armed.weapon
	var share: float = guard_share(armed, Balance.ARSENAL_MEND_CEILING)
	if share <= 0.0:
		return false
	var fired: bool = false
	match weapon.anchor:
		ArsenalWeaponData.Anchor.WARDEN:
			if hero == null or not is_instance_valid(hero) or hero.health == null:
				return false
			var missing: float = hero.health.max_hp - hero.health.current_hp
			if missing <= 0.5:
				return false
			hero.health.heal(missing * share)
			_show_guard(weapon, hero.global_position, 1.0)
			fired = true
		ArsenalWeaponData.Anchor.TOWERS:
			for tower: Tower in armed_towers():
				if not tower.needs_repair():
					continue
				tower.repair((1.0 - tower.health_ratio()) * share, true)
				_show_guard(weapon, tower.global_position, 0.8)
				fired = true
		ArsenalWeaponData.Anchor.TOWN:
			var town: Node = board.town if board != null else null
			if town != null and is_instance_valid(town) and town.has_method("mend") \
					and bool(town.call("mend", share)):
				_show_guard(weapon, board.town_position(), 2.2)
				fired = true
	return fired


## The towers within a Warden's reach, asked of the field the Warden stands on -
## the Arsenal at a Warden's side has no board of its own.
func _towers_near_wardens() -> Array[Tower]:
	var out: Array[Tower] = []
	var field: Battlefield = (hero.field as Battlefield) if hero != null and is_instance_valid(hero) else board
	if field == null:
		return out
	var reach: float = Balance.ARSENAL_TOWER_REACH * Balance.ARSENAL_TOWER_REACH
	for tower: Tower in field.all_towers():
		if tower == null or not is_instance_valid(tower) or not tower.is_vulnerable():
			continue
		for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
			var warden := node as Hero
			if warden != null and warden.is_alive() \
					and warden.global_position.distance_squared_to(tower.global_position) <= reach:
				out.append(tower)
				break
	return out


## The forged sheet a defence plays where it lands, sized to the anchor.
func _show_guard(weapon: ArsenalWeaponData, at: Vector2, scale: float) -> void:
	var effect: String = weapon.effect if not weapon.effect.is_empty() else "ward"
	Vfx.forge_play(effect, at + Vector2(0.0, -24.0 * scale), 120.0 * scale, weapon.tint)
	Vfx.ring(at, 40.0 * scale, Color(weapon.tint, 0.55), 0.35, 3.0)


## **A retort answers a blow**: the bodies at the anchor take a burst, through
## the same door every Arsenal blow uses, at most once a cadence - and never
## when the anchor is left alone, which is what separates it from a nova.
func _retort(armed: Armed, anchor: Vector2, from: Vector2) -> void:
	if armed.clock > 0.0 or not _may_fight():
		return
	var weapon: ArsenalWeaponData = armed.weapon
	var reach: float = radius_for(weapon, armed.level)
	var hit: float = hit_for(weapon, armed.level)
	var struck: bool = false
	for enemy: Enemy in bodies():
		if enemy.global_position.distance_to(anchor) <= reach + enemy.contact_radius() * 0.5:
			if strike_body(armed, enemy, hit, anchor):
				struck = true
	if not struck:
		return
	armed.clock = cadence(weapon)
	Vfx.forge_play(weapon.effect if not weapon.effect.is_empty() else "burst",
		anchor, reach * 2.0, weapon.tint)
	Vfx.ring(anchor, reach, Color(weapon.tint, 0.7), 0.28, 4.0)
	Vfx.spark(anchor, weapon.tint, 8, (anchor - from).normalized(), 160.0)


func _on_warden_struck(amount: float, _from: Vector2) -> void:
	if amount <= 0.0 or hero == null or not is_instance_valid(hero):
		return
	for armed: Armed in _armed.values():
		if armed.weapon.pattern == ArsenalWeaponData.Pattern.RETORT \
				and armed.weapon.anchor == ArsenalWeaponData.Anchor.WARDEN:
			_retort(armed, hero.global_position, _from)


func _on_tower_struck(at: Vector2) -> void:
	for armed: Armed in _armed.values():
		if armed.weapon.pattern != ArsenalWeaponData.Pattern.RETORT \
				or armed.weapon.anchor != ArsenalWeaponData.Anchor.TOWERS:
			continue
		for tower: Tower in armed_towers():
			if tower.origin().distance_to(at) <= 8.0:
				_retort(armed, tower.global_position, at)
				break


func _on_town_struck(from: Vector2) -> void:
	if board == null:
		return
	for armed: Armed in _armed.values():
		if armed.weapon.pattern == ArsenalWeaponData.Pattern.RETORT \
				and armed.weapon.anchor == ArsenalWeaponData.Anchor.TOWN:
			_retort(armed, board.town_position(), from)


## The stones turn, and a missing one reforms on the cadence.
func _tick_guard(armed: Armed, delta: float) -> void:
	var weapon: ArsenalWeaponData = armed.weapon
	armed.angle = fposmod(armed.angle + Balance.ARSENAL_GUARD_SPIN * delta, TAU)
	var full: int = count_for(weapon, armed.level)
	if armed.stones < 0:
		armed.stones = full
		return
	if armed.stones >= full:
		return
	armed.clock -= delta
	if armed.clock <= 0.0:
		armed.stones += 1
		armed.clock = cadence(weapon)
		if hero != null and is_instance_valid(hero):
			Vfx.spark(hero.global_position, weapon.tint, 5, Vector2.UP, 90.0)


## **A guard swallows a shot and never a blow.** Asked by the field for every
## hostile shot in flight, after the mirrors. A stone is spent; Stone Choir
## throws the shot back as bolts from where it was caught.
func absorb(at: Vector2) -> bool:
	if hero == null or not is_instance_valid(hero) or not _may_fight():
		return false
	for armed: Armed in _armed.values():
		var weapon: ArsenalWeaponData = armed.weapon
		if weapon.pattern != ArsenalWeaponData.Pattern.GUARD or armed.stones <= 0:
			continue
		var ring: float = radius_for(weapon, armed.level)
		if at.distance_to(hero.global_position) > ring + Balance.ARSENAL_GUARD_REACH:
			continue
		if armed.stones >= count_for(weapon, armed.level):
			armed.clock = cadence(weapon)
		armed.stones -= 1
		Vfx.forge_play(weapon.effect if not weapon.effect.is_empty() else "hit_earth",
			at, 90.0, weapon.tint)
		Vfx.spark(at, weapon.tint, 7, (at - hero.global_position).normalized(), 150.0)
		if weapon.damage > 0.0:
			var from_points: Array[Vector2] = [at]
			_fire_seekers(armed, from_points)
		return true
	return false


## The ring's bite, on its own tick: slowed, and soaked if it is water. Nothing
## is moved - a status the fight already has, on bodies that walked in.
func _tick_field(armed: Armed, delta: float) -> void:
	var weapon: ArsenalWeaponData = armed.weapon
	armed.clock -= delta
	armed.pulse -= delta
	if armed.clock > 0.0:
		return
	armed.clock = Balance.ARSENAL_FIELD_TICK
	var reach: float = radius_for(weapon, armed.level)
	var anchors: Array[Vector2] = _anchors(armed)
	var caught: bool = false
	for anchor: Vector2 in anchors:
		for enemy: Enemy in bodies():
			if enemy.global_position.distance_to(anchor) > reach + enemy.contact_radius() * 0.5:
				continue
			caught = true
			if weapon.slow < 1.0:
				enemy.apply_slow(weapon.slow, Balance.ARSENAL_FIELD_TICK * 2.2)
			if weapon.element == TowerData.Element.WATER:
				enemy.apply_wet(Balance.WET_SECONDS)
	if armed.pulse <= 0.0 and caught:
		armed.pulse = Balance.ARSENAL_FIELD_PULSE
		for anchor: Vector2 in anchors:
			Vfx.forge_play(weapon.effect if not weapon.effect.is_empty() else "nova",
				anchor, reach * 2.0, weapon.tint)


# --- Orbit --------------------------------------------------------------------


func _tick_orbit(armed: Armed, delta: float) -> void:
	var weapon: ArsenalWeaponData = armed.weapon
	armed.angle = fposmod(armed.angle + weapon.speed * delta, TAU)
	var anchors: Array[Vector2] = _anchors(armed)
	if anchors.is_empty():
		return
	var count: int = count_for(weapon, armed.level)
	var ring: float = radius_for(weapon, armed.level)
	var gap: float = cadence(weapon)
	var hit: float = hit_for(weapon, armed.level)
	var reach: float = ring + Balance.ARSENAL_ORB_SIZE + Balance.ARSENAL_BODY_ALLOWANCE
	for anchor: Vector2 in anchors:
		for enemy: Enemy in bodies():
			var at: Vector2 = enemy.global_position
			if at.distance_squared_to(anchor) > reach * reach:
				continue
			var id: int = enemy.get_instance_id()
			if _clock - float(armed.touched.get(id, -INF)) < gap:
				continue
			for index: int in count:
				var orb: Vector2 = anchor + Vector2.from_angle(
					armed.angle + TAU * float(index) / float(count)) * ring
				if orb.distance_to(at) <= Balance.ARSENAL_ORB_SIZE + Balance.ARSENAL_BODY_ALLOWANCE:
					armed.touched[id] = _clock
					if strike_body(armed, enemy, hit, orb):
						Vfx.spark(orb, weapon.tint, 3, (at - orb).normalized(), 140.0)
					break
	if armed.touched.size() > 256:
		armed.touched.clear()


# --- Seekers ------------------------------------------------------------------


func _fire_seekers(armed: Armed, from_points: Array[Vector2]) -> bool:
	var weapon: ArsenalWeaponData = armed.weapon
	if from_points.is_empty():
		return false
	var count: int = count_for(weapon, armed.level)
	var fired: bool = false
	for from: Vector2 in from_points:
		var targets: Array[Enemy] = _nearest(from, weapon.reach, count)
		if targets.is_empty():
			continue
		for index: int in count:
			var target: Enemy = targets[index % targets.size()]
			var heading: Vector2 = (target.global_position - from).normalized()
			heading = heading.rotated(_dice.randf_range(-0.55, 0.55) \
				+ (float(index) - float(count - 1) * 0.5) * 0.35)
			_add_record({"kind": "bolt", "card": armed.card.id, "at": from + heading * 18.0,
				"velocity": heading * weapon.speed, "target": weakref(target),
				"life": Balance.ARSENAL_BOLT_LIFE, "trail": PackedVector2Array([from]),
				"damage": hit_for(weapon, armed.level)})
		fired = true
		Vfx.spark(from, weapon.tint, 4, Vector2.ZERO, 120.0)
	return fired


func _tick_bolt(record: Dictionary, delta: float) -> bool:
	var armed: Armed = _armed.get(record["card"], null) as Armed
	var target: Enemy = (record["target"] as WeakRef).get_ref() as Enemy
	var at: Vector2 = record["at"] as Vector2
	if target == null or not is_instance_valid(target) or target.is_dying():
		var near: Array[Enemy] = _nearest(at, Balance.ARSENAL_BOLT_RETARGET, 1)
		target = near[0] if not near.is_empty() else null
		record["target"] = weakref(target) if target != null else weakref(self)
	var velocity: Vector2 = record["velocity"] as Vector2
	var speed: float = maxf(velocity.length(), 1.0)
	if target != null and is_instance_valid(target):
		var wanted: Vector2 = (target.global_position - at).normalized() * speed
		velocity = velocity.lerp(wanted, clampf(Balance.ARSENAL_BOLT_TURN * delta, 0.0, 1.0))
	at += velocity * delta
	record["velocity"] = velocity
	record["at"] = at
	var trail: PackedVector2Array = record["trail"] as PackedVector2Array
	trail.append(at)
	while trail.size() > 9:
		trail.remove_at(0)
	record["trail"] = trail
	if target != null and is_instance_valid(target) and armed != null \
			and at.distance_to(target.global_position) <= Balance.ARSENAL_BOLT_HIT \
				+ target.contact_radius() * 0.5:
		strike_body(armed, target, float(record["damage"]), at)
		Vfx.impact(at, armed.weapon.element, armed.weapon.tint, 58.0)
		return false
	return true


## The nearest `count` bodies within `reach` of `from`, nearest first.
func _nearest(from: Vector2, reach: float, count: int) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var gaps: Array[float] = []
	var limit: float = reach * reach
	for enemy: Enemy in bodies():
		var gap: float = enemy.global_position.distance_squared_to(from)
		if gap > limit:
			continue
		var index: int = gaps.bsearch(gap)
		if index >= count:
			continue
		gaps.insert(index, gap)
		found.insert(index, enemy)
		if gaps.size() > count:
			gaps.resize(count)
			found.resize(count)
	return found


# --- Chain --------------------------------------------------------------------


func _fire_chain(armed: Armed) -> bool:
	var weapon: ArsenalWeaponData = armed.weapon
	var anchors: Array[Vector2] = _anchors(armed)
	if anchors.is_empty():
		return false
	var start: Vector2 = anchors[0] + Vector2(0.0, -Balance.ARSENAL_CHAIN_LIFT)
	var first: Array[Enemy] = _nearest(anchors[0], weapon.reach, 1)
	if first.is_empty():
		return false
	var hit: float = hit_for(weapon, armed.level)
	var visited: Dictionary = {}
	var points := PackedVector2Array([start])
	var current: Enemy = first[0]
	for jump: int in count_for(weapon, armed.level):
		if current == null:
			break
		visited[current.get_instance_id()] = true
		var at: Vector2 = current.global_position + Vector2(0.0, -Balance.ARSENAL_CHAIN_LIFT)
		points.append(at)
		# Conductive, as the sky's own lightning is: a storm leaving a wet body
		# leaps `WET_CHAIN_RANGE` further. Read before the blow, which may kill.
		var leap: float = Balance.ARSENAL_CHAIN_LEAP
		if weapon.element == TowerData.Element.AIR and current.is_wet():
			leap *= Balance.WET_CHAIN_RANGE
		strike_body(armed, current, hit, points[points.size() - 2])
		Vfx.impact(at, weapon.element, weapon.tint, 52.0)
		current = _next_link(at, visited, leap)
	_add_record({"kind": "chain", "card": armed.card.id, "points": points,
		"life": Balance.ARSENAL_CHAIN_LIFE, "full": Balance.ARSENAL_CHAIN_LIFE})
	return true


func _next_link(from: Vector2, visited: Dictionary,
		leap: float = Balance.ARSENAL_CHAIN_LEAP) -> Enemy:
	var best: Enemy = null
	var nearest: float = leap * leap
	for enemy: Enemy in bodies():
		if visited.has(enemy.get_instance_id()):
			continue
		var gap: float = enemy.global_position.distance_squared_to(from)
		if gap < nearest:
			nearest = gap
			best = enemy
	return best


# --- Nova ---------------------------------------------------------------------


func _fire_nova(armed: Armed) -> bool:
	var weapon: ArsenalWeaponData = armed.weapon
	var reach: float = radius_for(weapon, armed.level)
	var fired: bool = false
	for anchor: Vector2 in _anchors(armed):
		var caught: Array[Enemy] = []
		for enemy: Enemy in bodies():
			if enemy.global_position.distance_to(anchor) <= reach + enemy.contact_radius() * 0.5:
				caught.append(enemy)
		if caught.is_empty():
			continue
		var hit: float = hit_for(weapon, armed.level)
		for enemy: Enemy in caught:
			strike_body(armed, enemy, hit, anchor)
		Vfx.forge_play(weapon.effect if not weapon.effect.is_empty() else "nova",
			anchor, reach * 2.1, weapon.tint)
		Vfx.ring(anchor, reach, Color(weapon.tint, 0.7), 0.32, 4.0)
		fired = true
	return fired


# --- Trail --------------------------------------------------------------------


func _tick_trail(armed: Armed) -> void:
	var anchors: Array[Vector2] = _anchors(armed)
	if anchors.is_empty():
		return
	var at: Vector2 = anchors[0]
	if armed.last_step != Vector2.INF \
			and at.distance_to(armed.last_step) < Balance.ARSENAL_TRAIL_STEP:
		return
	armed.last_step = at
	var weapon: ArsenalWeaponData = armed.weapon
	_add_record({"kind": "patch", "card": armed.card.id, "at": at,
		"radius": radius_for(weapon, armed.level), "life": duration_for(weapon),
		"full": duration_for(weapon), "bite": 0.0, "seed": _dice.randi()})


func _tick_patch(record: Dictionary, delta: float) -> void:
	var armed: Armed = _armed.get(record["card"], null) as Armed
	if armed == null:
		return
	record["bite"] = float(record["bite"]) - delta
	if float(record["bite"]) > 0.0:
		return
	record["bite"] = cadence(armed.weapon)
	var at: Vector2 = record["at"] as Vector2
	var reach: float = float(record["radius"])
	var hit: float = hit_for(armed.weapon, armed.level)
	for enemy: Enemy in bodies():
		if enemy.global_position.distance_to(at) <= reach + enemy.contact_radius() * 0.5:
			if strike_body(armed, enemy, hit, at, 0.0):
				Vfx.spark(enemy.global_position, armed.weapon.tint, 2, Vector2.UP, 90.0)


# --- Strike -------------------------------------------------------------------


## Something falls on the thickest knots of bodies in reach: a ring first, for
## `ARSENAL_STRIKE_WARNING`, and then the blow - the telegraph rule every blow
## from the sky here obeys. A weapon on the towers throws from each tower at the
## nearest body in that tower's own reach.
func _fire_strikes(armed: Armed) -> bool:
	var weapon: ArsenalWeaponData = armed.weapon
	var blast: float = radius_for(weapon, armed.level)
	var hit: float = hit_for(weapon, armed.level)
	if weapon.anchor == ArsenalWeaponData.Anchor.TOWERS:
		var thrown: bool = false
		for tower: Tower in armed_towers():
			var near: Array[Enemy] = _nearest(tower.global_position, tower.effective_range(), 1)
			if near.is_empty():
				continue
			_add_strike(armed, near[0].global_position, blast, hit,
				Balance.ARSENAL_STRIKE_WARNING * 0.6, tower.global_position)
			thrown = true
		return thrown
	var anchors: Array[Vector2] = _anchors(armed)
	if anchors.is_empty():
		return false
	var knots: Array[Vector2] = _knots(anchors[0], weapon.reach, blast,
		count_for(weapon, armed.level))
	for at: Vector2 in knots:
		_add_strike(armed, at, blast, hit, Balance.ARSENAL_STRIKE_WARNING, Vector2.INF)
	return not knots.is_empty()


func _add_strike(armed: Armed, at: Vector2, blast: float, hit: float, warning: float,
		thrown_from: Vector2) -> void:
	_add_record({"kind": "strike", "card": armed.card.id, "at": at, "radius": blast,
		"damage": hit, "life": warning, "full": warning, "from": thrown_from})


func _land_strike(record: Dictionary) -> void:
	var armed: Armed = _armed.get(record["card"], null) as Armed
	if armed == null:
		return
	var at: Vector2 = record["at"] as Vector2
	var blast: float = float(record["radius"])
	for enemy: Enemy in bodies():
		if enemy.global_position.distance_to(at) <= blast + enemy.contact_radius() * 0.5:
			strike_body(armed, enemy, float(record["damage"]), at)
	var weapon: ArsenalWeaponData = armed.weapon
	Vfx.forge_play(weapon.effect if not weapon.effect.is_empty() else "slam_impact",
		at, blast * 2.2, weapon.tint)
	Vfx.dust(at, Color(weapon.tint.darkened(0.4), 0.5), 6, blast)
	EventBus.camera_impact.emit(at, Balance.ARSENAL_STRIKE_SHAKE)


## Up to `count` points where a blast of `blast` would catch the most bodies,
## among the bodies within `reach` of `from`, no two within a blast of each other.
func _knots(from: Vector2, reach: float, blast: float, count: int) -> Array[Vector2]:
	var candidates: Array[Enemy] = _nearest(from, reach, Balance.ARSENAL_KNOT_CANDIDATES)
	var scored: Array = []
	for enemy: Enemy in candidates:
		var crowd: int = 0
		for other: Enemy in candidates:
			if other.global_position.distance_to(enemy.global_position) <= blast:
				crowd += 1
		scored.append([crowd, enemy.global_position])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var out: Array[Vector2] = []
	for entry: Array in scored:
		if out.size() >= count:
			break
		var at: Vector2 = entry[1] as Vector2
		var clear: bool = true
		for chosen: Vector2 in out:
			if chosen.distance_to(at) < blast:
				clear = false
				break
		if clear:
			out.append(at)
	return out


# --- On kill ------------------------------------------------------------------


func _on_enemy_died(_enemy_id: String, at: Vector2) -> void:
	if not _may_fight():
		return
	for armed: Armed in _armed.values():
		var weapon: ArsenalWeaponData = armed.weapon
		if weapon.every_kills > 0:
			armed.kills += 1
		if weapon.pattern != ArsenalWeaponData.Pattern.ON_KILL:
			continue
		# A payload's own kill never releases another from the same card.
		if armed.card.id == _suppressing:
			continue
		var anchors: Array[Vector2] = _anchors(armed)
		if anchors.is_empty() or anchors[0].distance_to(at) > weapon.reach:
			continue
		if not _kill_allowed(armed.card.id):
			continue
		kill_triggers[armed.card.id] = int(kill_triggers.get(armed.card.id, 0)) + 1
		if weapon.speed > 0.0:
			_fire_seekers(armed, [at] as Array[Vector2])
		else:
			_burst_at(armed, at)


## **A chain reaction ends**: at most `ARSENAL_KILL_TRIGGERS_PER_SECOND` a second.
func _kill_allowed(card_id: String) -> bool:
	var window: Array = _kill_window.get(card_id, [-INF, 0]) as Array
	if _clock - float(window[0]) >= 1.0:
		window = [_clock, 0]
	if int(window[1]) >= Balance.ARSENAL_KILL_TRIGGERS_PER_SECOND:
		_kill_window[card_id] = window
		return false
	window[1] = int(window[1]) + 1
	_kill_window[card_id] = window
	return true


func _burst_at(armed: Armed, at: Vector2) -> void:
	var weapon: ArsenalWeaponData = armed.weapon
	var blast: float = radius_for(weapon, armed.level)
	var hit: float = hit_for(weapon, armed.level)
	for enemy: Enemy in bodies():
		if enemy.global_position.distance_to(at) <= blast + enemy.contact_radius() * 0.5:
			strike_body(armed, enemy, hit, at)
	Vfx.forge_play(weapon.effect if not weapon.effect.is_empty() else "burst",
		at, blast * 2.0, weapon.tint)


# --- Arc ----------------------------------------------------------------------


## Lightning between neighbouring towers: each tower to its nearest neighbour
## within `ARSENAL_ARC_SPAN`, the closest pairs first, as many as the weapon's
## count; a body within `radius` of a line is bitten on the weapon's cadence.
func _tick_arc(armed: Armed, delta: float) -> void:
	var weapon: ArsenalWeaponData = armed.weapon
	armed.arcs.clear()
	var points: Array[Vector2] = _anchors(armed)
	if points.size() < 2:
		return
	var pairs: Array = []
	for index: int in points.size():
		var best: int = -1
		var nearest: float = Balance.ARSENAL_ARC_SPAN
		for other: int in points.size():
			if other == index:
				continue
			var gap: float = points[index].distance_to(points[other])
			if gap < nearest:
				nearest = gap
				best = other
		if best >= 0:
			var low: int = mini(index, best)
			var high: int = maxi(index, best)
			var pair: Array = [nearest, low, high]
			if not pairs.has(pair):
				pairs.append(pair)
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var lift := Vector2(0.0, -Balance.ARSENAL_ARC_LIFT)
	for pair: Array in pairs.slice(0, count_for(weapon, armed.level)):
		armed.arcs.append(PackedVector2Array([points[int(pair[1])] + lift,
			points[int(pair[2])] + lift]))
	armed.clock -= delta
	if armed.clock > 0.0:
		return
	armed.clock = cadence(weapon)
	var width: float = radius_for(weapon, armed.level)
	var hit: float = hit_for(weapon, armed.level)
	for line: PackedVector2Array in armed.arcs:
		var a: Vector2 = line[0] - lift
		var b: Vector2 = line[1] - lift
		for enemy: Enemy in bodies():
			var on: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, a, b)
			if on.distance_to(enemy.global_position) <= width + enemy.contact_radius() * 0.5:
				if strike_body(armed, enemy, hit, on):
					Vfx.spark(enemy.global_position + lift * 0.5, weapon.tint, 3,
						Vector2.ZERO, 150.0)


# --- Records ------------------------------------------------------------------


func _add_record(record: Dictionary) -> void:
	_records.append(record)
	while _records.size() > Balance.ARSENAL_RECORDS_MAX:
		_records.pop_front()


func records() -> int:
	return _records.size()


func _tick_records(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for record: Dictionary in _records:
		record["life"] = float(record["life"]) - delta
		var keep: bool = float(record["life"]) > 0.0
		match String(record["kind"]):
			"bolt":
				keep = keep and _tick_bolt(record, delta)
				if not keep and float(record["life"]) <= 0.0:
					Vfx.spark(record["at"] as Vector2, Color(1.0, 1.0, 1.0, 0.5), 2,
						Vector2.ZERO, 70.0)
			"patch":
				if keep:
					_tick_patch(record, delta)
			"strike":
				if not keep:
					_land_strike(record)
		if keep:
			kept.append(record)
	_records = kept


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	for armed: Armed in _armed.values():
		match armed.weapon.pattern:
			ArsenalWeaponData.Pattern.ORBIT:
				_draw_orbit(armed)
			ArsenalWeaponData.Pattern.GUARD:
				_draw_guard(armed)
			ArsenalWeaponData.Pattern.FIELD:
				_draw_field(armed)
	for record: Dictionary in _records:
		var armed: Armed = _armed.get(record["card"], null) as Armed
		if armed == null:
			continue
		match String(record["kind"]):
			"bolt":
				_draw_head(armed.weapon, record["at"] as Vector2,
					Balance.ARSENAL_BOLT_SIZE, (record["velocity"] as Vector2).angle())
			"strike":
				_draw_strike_warning(armed.weapon, record)
			"patch":
				_draw_patch(armed.weapon, record)
	var item: RID = get_canvas_item()
	_flat.flush(item)
	for texture: Variant in _head_batches:
		(_head_batches[texture] as InkBatch).flush(item, texture as Texture2D)


func _draw_orbit(armed: Armed) -> void:
	var count: int = count_for(armed.weapon, armed.level)
	var ring: float = radius_for(armed.weapon, armed.level)
	for anchor: Vector2 in _anchors(armed):
		for index: int in count:
			var angle: float = armed.angle + TAU * float(index) / float(count)
			_draw_head(armed.weapon, anchor + Vector2.from_angle(angle) * ring,
				Balance.ARSENAL_ORB_SIZE, angle + PI * 0.5)


## The stones standing this moment, on the guard's ring.
func _draw_guard(armed: Armed) -> void:
	if armed.stones <= 0:
		return
	var full: int = maxi(count_for(armed.weapon, armed.level), 1)
	var ring: float = radius_for(armed.weapon, armed.level)
	for anchor: Vector2 in _anchors(armed):
		for index: int in armed.stones:
			var angle: float = armed.angle + TAU * float(index) / float(full)
			_draw_head(armed.weapon, anchor + Vector2.from_angle(angle) * ring,
				Balance.ARSENAL_ORB_SIZE, angle + PI * 0.5)


## The field's ring: an ellipse on the ground in the weapon's colour, breathing.
func _draw_field(armed: Armed) -> void:
	var reach: float = radius_for(armed.weapon, armed.level)
	var breath: float = 0.75 + 0.25 * sin(_clock * 2.4)
	for anchor: Vector2 in _anchors(armed):
		_flat.ring(anchor, reach, 3.0, Color(armed.weapon.tint, 0.35 * breath), 48, GROUND)
		_flat.ring(anchor, reach * 0.82, 8.0, Color(armed.weapon.tint, 0.12 * breath), 48, GROUND)


## A weapon's head: the element's painted projectile when it has one, turning
## on its own frames, or a soft disc in the weapon's colour.
func _draw_head(weapon: ArsenalWeaponData, at: Vector2, size: float, angle: float) -> void:
	var frames: Array = _frames_for(weapon.head)
	if frames.is_empty():
		_flat.disc(at, size * 0.55, weapon.tint)
		return
	var texture: Texture2D = frames[int(_clock * 12.0) % frames.size()] as Texture2D
	var batch: InkBatch = _head_batches.get(texture, null) as InkBatch
	if batch == null:
		batch = InkBatch.new()
		_head_batches[texture] = batch
	batch.quad(at, size, angle, weapon.tint.lightened(0.35))


func _draw_strike_warning(weapon: ArsenalWeaponData, record: Dictionary) -> void:
	var at: Vector2 = record["at"] as Vector2
	var blast: float = float(record["radius"])
	var done: float = 1.0 - float(record["life"]) / maxf(float(record["full"]), 0.01)
	_flat.ring(at, blast, 4.0, Color(0.05, 0.03, 0.02, 0.55), 40, GROUND)
	_flat.ring(at, blast * done, 3.0, Color(weapon.tint, 0.8), 40, GROUND)
	var from: Vector2 = record.get("from", Vector2.INF) as Vector2
	if from != Vector2.INF:
		var arc_at: Vector2 = from.lerp(at, done) + Vector2(0.0, -sin(done * PI) * 140.0)
		_draw_head(weapon, arc_at, Balance.ARSENAL_BOLT_SIZE, done * TAU)
	else:
		var fall: Vector2 = at + Vector2(0.0, -(1.0 - done) * 420.0)
		_draw_head(weapon, fall, Balance.ARSENAL_BOLT_SIZE * 1.5, PI * 0.5)


func _draw_patch(weapon: ArsenalWeaponData, record: Dictionary) -> void:
	var at: Vector2 = record["at"] as Vector2
	var reach: float = float(record["radius"])
	var left: float = clampf(float(record["life"]) / maxf(float(record["full"]), 0.01), 0.0, 1.0)
	var ink := Color(weapon.tint.darkened(0.55), 0.55 * left)
	var dice: RandomNumberGenerator = _shape_dice
	dice.seed = int(record["seed"])
	for spike: int in 7:
		var base: Vector2 = at + Vector2.from_angle(dice.randf() * TAU) \
			* dice.randf_range(0.1, 0.8) * reach * GROUND
		var tall: float = dice.randf_range(10.0, 22.0) * (0.6 + 0.4 * left)
		_flat.triangle(base + Vector2(-4.0, 0.0), base + Vector2(4.0, 0.0),
			base + Vector2(dice.randf_range(-3.0, 3.0), -tall), ink)


func _frames_for(head: String) -> Array:
	if head.is_empty():
		return []
	if _heads.has(head):
		return _heads[head] as Array
	var frames: Array = []
	var base: String = HEAD_FORMAT % head
	# `load_idle_frames` hands the painting back as frame zero already; putting
	# it on the front again held the rest pose for two beats of every turn -
	# the fault the tooltips and the traps shipped with on 2026-09-25.
	if ResourceLoader.exists(base):
		for frame: Texture2D in GameData.load_idle_frames(base):
			frames.append(frame)
		if frames.is_empty():
			frames.append(load(base))
	_heads[head] = frames
	return frames


## The additive half: glows under the heads, bolt trails, chains, arcs, and the
## light of a patch and a warning.
func paint_light(on: CanvasItem) -> void:
	_light.clear()
	for armed: Armed in _armed.values():
		var weapon: ArsenalWeaponData = armed.weapon
		match weapon.pattern:
			ArsenalWeaponData.Pattern.ORBIT:
				var count: int = count_for(weapon, armed.level)
				var ring: float = radius_for(weapon, armed.level)
				for anchor: Vector2 in _anchors(armed):
					for index: int in count:
						var orb: Vector2 = anchor + Vector2.from_angle(
							armed.angle + TAU * float(index) / float(count)) * ring
						_soft(on, orb, Balance.ARSENAL_ORB_SIZE * 1.8, Color(weapon.tint, 0.45))
			ArsenalWeaponData.Pattern.ARC:
				for line: PackedVector2Array in armed.arcs:
					_bolt_line(on, line[0], line[1], weapon.tint, 0.85)
	for record: Dictionary in _records:
		var armed: Armed = _armed.get(record["card"], null) as Armed
		if armed == null:
			continue
		var tint: Color = armed.weapon.tint
		match String(record["kind"]):
			"bolt":
				_light.ribbon(record["trail"] as PackedVector2Array, Transform2D.IDENTITY,
					Balance.ARSENAL_BOLT_SIZE * 0.9, tint, 0.0, 0.8)
				_soft(on, record["at"] as Vector2, Balance.ARSENAL_BOLT_SIZE * 1.9, Color(tint, 0.5))
			"chain":
				var points: PackedVector2Array = record["points"] as PackedVector2Array
				var fade: float = float(record["life"]) / maxf(float(record["full"]), 0.01)
				for index: int in range(1, points.size()):
					_bolt_line(on, points[index - 1], points[index], tint, fade)
			"patch":
				var left: float = clampf(float(record["life"]) / maxf(float(record["full"]), 0.01),
					0.0, 1.0)
				_light.soft_disc(record["at"] as Vector2, float(record["radius"]),
					Color(tint, 0.22 * left), 12, GROUND)
			"strike":
				var done: float = 1.0 - float(record["life"]) / maxf(float(record["full"]), 0.01)
				_light.soft_disc(record["at"] as Vector2, float(record["radius"]),
					Color(tint, 0.18 + 0.25 * done), 12, GROUND)
	_light.flush(on.get_canvas_item())


## A jagged line of light between two points, flickering on the Arsenal's clock.
func _bolt_line(on: CanvasItem, a: Vector2, b: Vector2, tint: Color, strength: float) -> void:
	var steps: int = maxi(int(a.distance_to(b) / 26.0), 2)
	var across: Vector2 = (b - a).normalized().orthogonal()
	var points := PackedVector2Array([a])
	var flicker: RandomNumberGenerator = _shape_dice
	flicker.seed = int(_clock * 30.0) + int(a.x) * 7 + int(b.y) * 13
	for step: int in range(1, steps):
		var t: float = float(step) / float(steps)
		points.append(a.lerp(b, t) + across * flicker.randf_range(-14.0, 14.0))
	points.append(b)
	_light.band(points, 7.0, Color(tint, 0.55 * strength))
	_light.band(points, 2.0, Color(1.0, 1.0, 1.0, 0.85 * strength))


func _soft(_on: CanvasItem, at: Vector2, radius: float, colour: Color) -> void:
	_light.soft_disc(at, radius, colour)


class _Glow extends Node2D:
	var arsenal: Arsenal = null

	func _draw() -> void:
		if arsenal != null and is_instance_valid(arsenal):
			arsenal.paint_light(self)
