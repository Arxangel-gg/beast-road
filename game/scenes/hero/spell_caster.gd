class_name SpellCaster
extends Node

## The hero's four spell slots (GDD §11).
##
## Like HeroAttack, this is a state machine that does not know what a Hero is:
## the hero ticks it, hands it an aim and an origin, and connects to what it
## reports. Effects are switched on `SpellData.kind`, so adding a spell is a
## `.tres` with an existing kind.

## The hero should move to `to` immediately (Rift Step).
signal blink_requested(to: Vector2)

## The hero should gain invulnerability and a speed bonus (Ash Veil).
signal veil_requested(duration: float, speed_bonus: float)

## The hero should be healed (Marrow Drain).
signal heal_requested(amount: float)

## Iron Roar: the hero should turn away `fraction` of harm for `seconds`.
signal armor_requested(fraction: float, seconds: float)

## Sanguine Guard: once the veil ends (`delay`), bank `fraction` of each blow
## as a recoverable wound for `seconds`.
signal wound_guard_requested(fraction: float, delay: float, seconds: float)

## Red Pursuit: the hero stepped through marked prey and gets this share of the
## dash cooldown back.
signal dash_refund_requested(fraction: float)

## A cast was refused for want of mana. The HUD flashes the bar.
signal cast_starved(slot: int)

## A spell resolved, for feedback and the HUD.
signal spell_cast(slot: int, spell_id: String, at: Vector2)

## A slot's cooldown changed, 0..1 remaining.
signal cooldown_changed(slot: int, ratio: float)

var field: EnemyField = null

## The hero this casts for. Assigned by `Hero`, beside `field`.
##
## Handed in rather than reached for with `get_parent()`, which is CLAUDE.md §5's
## rule and earns its keep here: a companion has to know whose it is, and in
## co-op there are two heroes with two casters and the wrong answer is silent.
var hero: Node2D = null

## Seconds remaining per slot, indexed the same as RunState.equipped_spells.
var _cooldowns: Array[float] = []

## The lane shield left by Bulwark Ward: lane index and seconds remaining.
var _ward_lane: int = -1
var _ward_left: float = 0.0

var _beam_left: float = 0.0
var _beam_spell: SpellData = null
var _beam_aim: Vector2 = Vector2.RIGHT

## Shield fields left by Aegis Step: where, how long, and who has already been
## warded by it. Each hero is warded once per field, so standing in one is not
## a regenerating pool - it is a thing you step into on the way past.
var _aegis_fields: Array[Dictionary] = []


func _ready() -> void:
	_cooldowns.resize(Balance.HERO_MAX_SPELL_SLOTS)
	_cooldowns.fill(0.0)


func tick(delta: float, aim: Vector2, origin: Vector2) -> void:
	for i: int in _cooldowns.size():
		if _cooldowns[i] <= 0.0:
			continue
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
		cooldown_changed.emit(i, cooldown_ratio(i))

	if _ward_left > 0.0:
		_ward_left = maxf(_ward_left - delta, 0.0)
		if _ward_left <= 0.0:
			_ward_lane = -1

	if _beam_left > 0.0:
		_beam_left = maxf(_beam_left - delta, 0.0)
		_tick_beam(delta, origin)
		if _beam_left <= 0.0:
			_beam_spell = null
	else:
		_beam_aim = aim

	_tick_aegis(delta)


## Wards each hero standing in a live shield field, once per field.
func _tick_aegis(delta: float) -> void:
	if _aegis_fields.is_empty():
		return
	var heroes: Array[Node] = get_tree().get_nodes_in_group(Hero.GROUP_ANY)
	for index: int in range(_aegis_fields.size() - 1, -1, -1):
		var zone: Dictionary = _aegis_fields[index]
		zone["left"] = float(zone["left"]) - delta
		if float(zone["left"]) <= 0.0:
			_aegis_fields.remove_at(index)
			continue
		var granted: Array = zone["granted"]
		for node: Node in heroes:
			var body := node as Node2D
			if body == null or granted.has(body):
				continue
			if body.global_position.distance_to(zone["at"]) > Balance.DISCIPLINE_AEGIS_RADIUS:
				continue
			var pool: Health = Health.of(body)
			if pool == null or pool.is_dead:
				continue
			pool.add_shield(pool.max_hp * Balance.DISCIPLINE_AEGIS_SHIELD_FRACTION)
			granted.append(body)


## How many shield fields are live. For the gate.
func aegis_field_count() -> int:
	return _aegis_fields.size()


## The hero's feet, or the cast origin when there is no hero (the gates cast
## from a bare caster). Ground effects and destinations live in this frame;
## `origin` is the body, which `enemies_near` measures to.
func _foot(origin: Vector2) -> Vector2:
	var body := hero as Node2D
	return body.global_position if body != null else origin


## True while a channelled spell is resolving; the hero is rooted.
func is_channelling() -> bool:
	return _beam_left > 0.0


func is_lane_warded(lane: int) -> bool:
	return _ward_left > 0.0 and _ward_lane == lane


func spell_in_slot(slot: int) -> SpellData:
	if slot < 0 or slot >= RunState.equipped_spells.size():
		return null
	return ContentDB.spells.get(RunState.equipped_spells[slot], null) as SpellData


func cooldown_ratio(slot: int) -> float:
	var spell: SpellData = spell_in_slot(slot)
	if spell == null or spell.cooldown <= 0.0 or slot >= _cooldowns.size():
		return 0.0
	return _cooldowns[slot] / _effective_cooldown(spell)


## Clears every cooldown and any channel in progress. Used when the hero
## ascends, and by the headless checks that walk all eight spells.
func clear_cooldowns() -> void:
	for i: int in _cooldowns.size():
		_cooldowns[i] = 0.0
		cooldown_changed.emit(i, 0.0)
	_beam_left = 0.0
	_beam_spell = null


## Preparation keeps locomotion live but cancels combat commitments. In
## particular, a beam begun on the final enemy may not root the hero for the
## first seconds of the construction window.
func cancel_channel() -> void:
	_beam_left = 0.0
	_beam_spell = null


func is_ready(slot: int) -> bool:
	return slot < _cooldowns.size() and _cooldowns[slot] <= 0.0 and spell_in_slot(slot) != null


## Returns true if the spell went off.
func try_cast(slot: int, aim: Vector2, origin: Vector2) -> bool:
	if field == null or not is_ready(slot) or is_channelling():
		return false
	var spell: SpellData = spell_in_slot(slot)
	if spell == null:
		return false
	# Paid before it resolves, and refused if it cannot be. A bare caster with
	# no hero - the gates - casts for free, which is what they need.
	if hero != null and hero.has_method("spend_mana"):
		if not bool(hero.call("spend_mana", spell.cost())):
			cast_starved.emit(slot)
			return false

	_cooldowns[slot] = _effective_cooldown(spell)
	cooldown_changed.emit(slot, 1.0)
	_resolve(spell, aim, origin)
	_rider(slot, spell, aim, origin)
	spell_cast.emit(slot, spell.id, origin)
	EventBus.spell_cast.emit(spell.id, slot, origin)
	return true


## The Sanctum shortens cooldowns, and so does the Mirrorfang core.
func _effective_cooldown(spell: SpellData) -> float:
	var sanctum: BuildingData = ContentDB.building("sanctum")
	var reduction: float = 0.0
	if sanctum != null:
		reduction = sanctum.effect_at(RunState.building_tier("sanctum"))
	var flat: float = Modifiers.value(Modifiers.DASH_COOLDOWN)
	# Focus shortens every cooldown, up to a cap, so it cannot be spent into
	# a spell with no cooldown at all.
	var focus_cut: float = minf(float(RunState.attribute(RunState.Attribute.FOCUS))
		* Balance.HERO_FOCUS_COOLDOWN_PER_POINT, Balance.HERO_FOCUS_COOLDOWN_CAP)
	return maxf(spell.cooldown * (1.0 - reduction) * (1.0 - focus_cut) + flat, 0.5)


## What Focus multiplies spell damage by. The Mansion has said "spell power"
## since the attribute was authored; this is where it happens.
static func focus_power() -> float:
	return 1.0 + float(RunState.attribute(RunState.Attribute.FOCUS)) \
		* Balance.HERO_FOCUS_SPELL_PER_POINT


## What the discipline node in this slot adds on top of the spell it adapts.
##
## **A node is not only its spell.** Eleven of the authored nodes name an
## existing `spell_id` *and* an `effect_id` describing something more - Marrow
## Drain generates Command, Crimson Tempest returns health, Chain Hook works on
## things too heavy to pull. The spell half was wired up and the rider half was
## not, so those nodes cast correctly and quietly failed to do the thing their
## own description promised.
##
## Read off the equipped node rather than a global table, because a rider belongs
## to the node that bought it: unequipping Marrow Drain has to stop paying
## Command, and a lookup by `spell_id` alone would keep paying it for anyone who
## happened to cast the same spell.
func _rider(slot: int, spell: SpellData, aim: Vector2, origin: Vector2) -> void:
	var node: DisciplineNodeData = RunState.discipline_node_in_slot(slot)
	if node == null or node.spell_id != spell.id:
		return
	match node.effect_id:
		"drain_command":
			_drain_command(origin, aim, spell, node.effect_value)
		"tempest_heal_cap":
			_tempest_heal(origin, spell, node.effect_value)
		"heavy_reverse_pull":
			_reverse_hook(origin, spell)
		"armor_stagger":
			_roar(origin, spell, node.effect_value)
		"dash_shield_field":
			_aegis_fields.append({"at": _foot(origin), "left": node.effect_value, "granted": []})
			Vfx.ring(_foot(origin), Balance.DISCIPLINE_AEGIS_RADIUS, Color("9fd3ff"), 0.5, 4.0)
		"lane_cleanse":
			_cleanse(origin, spell)
		"recoverable_wound":
			wound_guard_requested.emit(node.effect_value, spell.duration,
				Balance.DISCIPLINE_WOUND_SECONDS)
		"road_line_disrupt":
			_line_disrupt(origin, spell, node.effect_value)
		"selected_road_shockwave":
			_road_shockwave(origin, spell, node.effect_value)
		"marked_dash_refund":
			_pursuit(origin, aim, spell, node.effect_value)


## Iron Roar: a radial stagger on the cast, and armour that outlasts the veil.
##
## The veil is already invulnerable for its duration, so armour *under* it would
## be nothing; it runs for the veil plus a tail, which is when it matters.
func _roar(origin: Vector2, spell: SpellData, fraction: float) -> void:
	var feet: Vector2 = _foot(origin)
	for enemy: Enemy in field.enemies_near(origin, Balance.DISCIPLINE_ROAR_RADIUS):
		if enemy.is_dying():
			continue
		enemy.apply_stagger(Balance.DISCIPLINE_ROAR_STAGGER)
		enemy.shove(feet, Balance.DISCIPLINE_ROAR_SHOVE)
	armor_requested.emit(fraction, spell.duration + Balance.DISCIPLINE_ROAR_ARMOR_TAIL)
	Vfx.ring(origin, Balance.DISCIPLINE_ROAR_RADIUS, Color("ffb35c"), 0.4, 5.0)


## Bulwark Ward also clears a disable off every hero standing on the warded
## ground - the caster included, and the partner if they are close.
func _cleanse(origin: Vector2, spell: SpellData) -> void:
	var centre: Vector2 = _foot(origin)
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var body := node as Node2D
		if body == null or not body.has_method("cleanse_disables"):
			continue
		if body.global_position.distance_to(centre) <= spell.effect_radius:
			body.call("cleanse_disables")


## Tremor's ground line: a corridor along the road, both ways, that staggers
## what stands on it and shoves it off the line - so a dense road splits rather
## than merely stepping back.
func _line_disrupt(origin: Vector2, spell: SpellData, scale: float) -> void:
	var along: Vector2 = field.lane_direction(_lane_at(origin))
	var reach: float = spell.effect_radius * Balance.DISCIPLINE_LINE_REACH_SCALE * scale
	var feet: Vector2 = _foot(origin)
	for enemy: Enemy in field.enemies_near(origin, reach):
		if enemy.is_dying():
			continue
		var offset: Vector2 = enemy.global_position - feet
		if absf(offset.cross(along)) > Balance.DISCIPLINE_LINE_HALF_WIDTH:
			continue
		enemy.apply_stagger(Balance.DISCIPLINE_LINE_STAGGER)
		var on_line: Vector2 = feet + along * offset.dot(along)
		enemy.shove(on_line, Balance.DISCIPLINE_LINE_SHOVE)


## Beast's Breath carries on down the selected road past the nova's reach,
## thinning with distance. Only bodies the nova did not already hit.
func _road_shockwave(origin: Vector2, spell: SpellData, scale: float) -> void:
	var along: Vector2 = field.lane_direction(_lane_at(origin))
	var reach: float = Balance.DISCIPLINE_ROAD_SHOCK_REACH * scale
	var feet: Vector2 = _foot(origin)
	var power: float = spell.damage * Modifiers.multiplier(Modifiers.HERO_DAMAGE) * focus_power()
	var centre: Vector2 = origin + along * (reach * 0.5)
	var sweep: float = reach * 0.5 + Balance.DISCIPLINE_ROAD_SHOCK_HALF_WIDTH
	for enemy: Enemy in field.enemies_near(centre, sweep):
		if enemy.is_dying():
			continue
		if origin.distance_to(enemy.combat_origin()) <= spell.effect_radius:
			continue
		var offset: Vector2 = enemy.global_position - feet
		var ahead: float = offset.dot(along)
		if ahead <= 0.0 or ahead > reach:
			continue
		if absf(offset.cross(along)) > Balance.DISCIPLINE_ROAD_SHOCK_HALF_WIDTH:
			continue
		var falloff: float = 1.0 - Balance.DISCIPLINE_ROAD_SHOCK_FALLOFF * (ahead / reach)
		enemy.take_damage(power * falloff, feet, spell.knockback, true)
		enemy.shove(feet, Balance.DISCIPLINE_ROAD_SHOCK_SHOVE)


## Red Pursuit: a Rift Step whose line passes through marked prey - branded, or
## the priority bodies the read is about - gives back part of the dash.
func _pursuit(origin: Vector2, aim: Vector2, spell: SpellData, fraction: float) -> void:
	var middle: Vector2 = origin + aim * (spell.cast_range * 0.5)
	var sweep: float = spell.cast_range * 0.5 + Balance.DISCIPLINE_PURSUIT_WIDTH
	for enemy: Enemy in field.enemies_near(middle, sweep):
		if enemy.is_dying():
			continue
		if not (enemy.is_branded() or enemy.is_priority()):
			continue
		var body: Vector2 = enemy.combat_origin()
		var t: float = clampf((body - origin).dot(aim), 0.0, spell.cast_range)
		if body.distance_to(origin + aim * t) <= Balance.DISCIPLINE_PURSUIT_WIDTH:
			dash_refund_requested.emit(fraction)
			Vfx.ring(enemy.global_position, 40.0, Color("ff6a5c"), 0.3, 4.0)
			return


## Marrow Drain pays Command for channelling on something that mattered.
##
## Priority prey only. Command is the resource that buys orders, and a drain that
## paid out on any body in range would make the cheapest possible cast the best
## way to earn it - which is the opposite of what "channel on priority prey"
## asks for.
func _drain_command(origin: Vector2, aim: Vector2, spell: SpellData,
		amount: float) -> void:
	var centre: Vector2 = origin + aim * (spell.effect_radius * 0.5)
	for enemy: Enemy in field.enemies_near(centre, spell.effect_radius):
		if enemy.is_priority():
			RunState.gain_command(amount)
			return


## Crimson Tempest returns health, up to the node's hard cap.
##
## The cap is the whole balance argument - an area nuke that healed in proportion
## to how many things it hit would make a crowd safer than an empty road - so it
## is applied here rather than trusted to the fraction.
func _tempest_heal(origin: Vector2, spell: SpellData, cap: float) -> void:
	var struck: float = 0.0
	for enemy: Enemy in field.enemies_near(origin, spell.effect_radius):
		if not enemy.is_dying():
			struck += 1.0
	if struck <= 0.0:
		return
	var healed: float = minf(
		spell.damage * struck * Balance.DISCIPLINE_TEMPEST_LIFESTEAL, cap)
	if healed > 0.0:
		heal_requested.emit(healed)


## Chain Hook against something that was never going to move.
##
## The node promises both directions and only one was built. A heavy target
## simply absorbed the pull and the cast was wasted; now the hook reels the hero
## in instead, which turns the worst case for the spell into its opening.
func _reverse_hook(origin: Vector2, spell: SpellData) -> void:
	var heaviest: Enemy = null
	var best: float = Balance.DISCIPLINE_HEAVY_RESISTANCE
	for enemy: Enemy in field.enemies_near(origin, spell.cast_range):
		if enemy.data == null or enemy.is_dying():
			continue
		if enemy.data.knockback_resistance >= best:
			best = enemy.data.knockback_resistance
			heaviest = enemy
	if heaviest == null:
		return
	# **Two frames, and they must not be mixed.** A cast arrives at
	# `combat_origin()` - the body, which is what `enemies_near` measures to -
	# while `blink_requested` sets the hero's `global_position`, which is its
	# feet. Taking the direction in one frame and the destination in the other
	# lands the hero a body-height off the ground.
	var approach: Vector2 = heaviest.combat_origin() - origin
	if approach.length() < 1.0:
		return
	# Stopped short of the body rather than on top of it, so the hero arrives in
	# swinging range instead of inside something's hitbox.
	var stand_off: float = Balance.HERO_ATTACK_RANGE[0] * 0.5
	blink_requested.emit(heaviest.global_position - approach.normalized() * stand_off)


func _resolve(spell: SpellData, aim: Vector2, origin: Vector2) -> void:
	var power: float = spell.damage * Modifiers.multiplier(Modifiers.HERO_DAMAGE) * focus_power()
	match spell.kind:
		SpellData.Kind.BLINK:
			# The destination is a place to stand, so it is built from the feet.
			# `origin` is the body, a head-height above them; adding the step to
			# it landed the hero that much up-screen on every Rift Step.
			blink_requested.emit(_foot(origin) + aim * spell.cast_range)
		SpellData.Kind.NOVA:
			_damage_area(origin, spell.effect_radius, power, spell.knockback, origin)
			EventBus.camera_shake_requested.emit(7.0, 0.25)
		SpellData.Kind.HOOK:
			_hook(origin, spell, power)
		SpellData.Kind.DRAIN:
			_drain(origin, aim, spell, power)
		SpellData.Kind.SHOCKWAVE:
			_damage_area(origin, spell.effect_radius, power, spell.knockback, origin)
			EventBus.camera_shake_requested.emit(10.0, 0.35)
		SpellData.Kind.VEIL:
			veil_requested.emit(spell.duration, spell.speed_bonus)
		SpellData.Kind.WARD:
			_ward_lane = _lane_at(origin)
			_ward_left = spell.duration
		SpellData.Kind.BEAM:
			_beam_spell = spell
			_beam_left = spell.duration
			_beam_aim = aim
		SpellData.Kind.COMPANION:
			_summon(spell, origin, aim)


## Calls a companion in beside the hero.
##
## Placed a little way along the aim rather than on top of the caster, so it
## arrives *between* the hero and whatever they were pointing at - which is where
## a summon is wanted, and it saves the first second of it walking there.
##
## Only one at a time per hero. A second cast replaces the first rather than
## stacking, because two Bears is a party and §54 cut that; replacing also gives
## the spell an honest use while it is already up.
func _summon(spell: SpellData, origin: Vector2, aim: Vector2) -> void:
	var data: CompanionData = ContentDB.companion(spell.companion_id)
	if data == null or field == null:
		return
	for node: Node in get_tree().get_nodes_in_group(Companion.GROUP):
		var existing := node as Companion
		if existing != null and existing.owner_hero == hero:
			existing.dismiss()
	var companion := Companion.new()
	companion.setup(data, hero, field)
	companion.global_position = origin + aim.normalized() * 70.0
	field.add_child(companion)


func _damage_area(centre: Vector2, radius: float, power: float, knockback: float, from: Vector2) -> float:
	var dealt: float = 0.0
	for enemy: Enemy in field.enemies_near(centre, radius):
		if enemy.take_damage(power, from, knockback, true):
			dealt += power
	return dealt


func _hook(origin: Vector2, spell: SpellData, power: float) -> void:
	for enemy: Enemy in field.enemies_near(origin, spell.cast_range):
		enemy.take_damage(power, origin, 0.0, true)
		# Negative knockback would be a hack; pulling is its own operation.
		enemy.pull_toward(origin, spell.knockback)


func _drain(origin: Vector2, aim: Vector2, spell: SpellData, power: float) -> void:
	var centre: Vector2 = origin + aim * (spell.effect_radius * 0.5)
	var dealt: float = _damage_area(centre, spell.effect_radius, power, spell.knockback, origin)
	if dealt > 0.0 and spell.lifesteal > 0.0:
		heal_requested.emit(dealt * spell.lifesteal)


func _tick_beam(delta: float, origin: Vector2) -> void:
	if _beam_spell == null:
		return
	var reach: float = maxf(_beam_spell.effect_radius, 120.0)
	var tick_damage: float = _beam_spell.damage * delta \
		* Modifiers.multiplier(Modifiers.HERO_DAMAGE) * focus_power()
	# A line, approximated by walking spheres along the aim — cheap, and exact
	# enough for something that is already a cone of fire.
	var steps: int = 6
	for i: int in steps:
		var point: Vector2 = origin + _beam_aim * (reach * float(i + 1) / float(steps))
		for enemy: Enemy in field.enemies_near(point, reach * 0.28):
			enemy.take_damage(tick_damage, origin, 0.0)


## Which lane a point belongs to, by angle. Used by Bulwark Ward.
func _lane_at(point: Vector2) -> int:
	if point.length() < 1.0:
		return 0
	var best: int = 0
	var best_dot: float = -2.0
	for lane: int in Balance.LANE_COUNT:
		var dot: float = point.normalized().dot(Battlefield.lane_vector(lane))
		if dot > best_dot:
			best_dot = dot
			best = lane
	return best
