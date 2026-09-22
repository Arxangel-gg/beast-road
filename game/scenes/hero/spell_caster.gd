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

## **Wellspring**: a kill gave mana back, as a share of the pool. A share rather
## than a number so it is worth the same at level one and at level a hundred.
signal mana_refunded(share: float)

## **Siphoning Veil**: a cast left a ward worth this share of the hero's health.
signal ward_requested(share: float)

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
## Break the Host: how much of the cap this channel has already spent, so a
## long fight cannot extend one beam indefinitely a second at a time.
var _beam_extended: float = 0.0
## Where the last elite fell, so the flourish has somewhere to happen.
var _beam_from: Vector2 = Vector2.ZERO

## Quickening: how long the chain has left. A window rather than a flat
## reduction, so it ends the moment the player stops casting - which is what
## keeps it from being a cooldown cut wearing a card's clothes.
var _chain_left: float = 0.0

## Echo of the Weave: true while an echo is resolving, so an echo cannot echo.
var _echoing: bool = false
var _beam_spell: SpellData = null
var _beam_aim: Vector2 = Vector2.RIGHT

## Strikes that have been aimed and have not landed yet.
##
## A list rather than one slot, because both ranged kinds put several in the air
## at once - a volley is six of them on one cast - and because a second cast
## must not cancel the first one's damage after the player has already paid the
## mana for it.
##
## Each entry is `{at, radius, power, knockback, left}`. They carry their own
## power rather than their spell, so a strike already in the air is unaffected
## by anything that happens to the hero between the cast and the landing: the
## number was decided when the player committed to it.
var _falling: Array[Dictionary] = []

## Shield fields left by Aegis Step: where, how long, and who has already been
## warded by it. Each hero is warded once per field, so standing in one is not
## a regenerating pool - it is a thing you step into on the way past.
var _aegis_fields: Array[Dictionary] = []


func _ready() -> void:
	_cooldowns.resize(Balance.HERO_MAX_SPELL_SLOTS)
	_cooldowns.fill(0.0)
	EventBus.elite_fell.connect(func(at: Vector2) -> void: extend_channel_on_elite(at))
	# **Wellspring.** A kill gives mana back. Announced as a fact by the body
	# that fell rather than polled, like every other reaction in this file.
	EventBus.enemy_died.connect(func(_id: String, _at: Vector2) -> void: _wellspring())


func tick(delta: float, aim: Vector2, origin: Vector2) -> void:
	for i: int in _cooldowns.size():
		if _cooldowns[i] <= 0.0:
			continue
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
		cooldown_changed.emit(i, cooldown_ratio(i))

	_chain_left = maxf(_chain_left - delta, 0.0)
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

	_tick_falling(delta)
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
##
## **A BEAM is not the same thing as a channel**, and reading it as one rooted
## the Arcane caster on every lance. `SpellData.is_channelled` was authored for
## exactly this distinction and read by nothing: `beasts_breath` is a cone the
## hero stands and holds, while Frost Lance and Sky Lance are BEAMs of 0.5 and
## 0.4 seconds - a flash along the aim. Rooting the player for those took away
## the one thing the Arcane tree sells, which is where they are standing, and
## locked the whole spell bar for the duration besides (see `cast`).
func is_channelling() -> bool:
	return _beam_left > 0.0 and _beam_spell != null and _beam_spell.is_channelled


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
	_beam_extended = 0.0
	_beam_spell = null
	_falling.clear()


## Preparation keeps locomotion live but cancels combat commitments. In
## particular, a beam begun on the final enemy may not root the hero for the
## first seconds of the construction window.
##
## **Strikes still in the air are cancelled too**, for the same reason and by
## the same argument the beam is: Preparation is the one phase that is supposed
## to be safe, and a meteor aimed during the last second of a wave would
## otherwise land on the construction screen. `spell_strike_check` caught this
## on its first run - `clear_cooldowns` emptied the list and this did not, so a
## fight that ended with a cast in the air behaved differently from one that
## ended any other way.
func cancel_channel() -> void:
	_beam_left = 0.0
	_beam_extended = 0.0
	_beam_spell = null
	_falling.clear()


func is_ready(slot: int) -> bool:
	return slot < _cooldowns.size() and _cooldowns[slot] <= 0.0 and spell_in_slot(slot) != null


## Returns true if the spell went off.
func try_cast(slot: int, aim: Vector2, origin: Vector2) -> bool:
	if field == null or not is_ready(slot) or is_channelling():
		return false
	var spell: SpellData = spell_in_slot(slot)
	if spell == null:
		return false
	# Aegis Step is a step, and over the knee there is no stepping (owner
	# brief, 2026-09-14). Refused before it is paid for.
	if spell.id == "aegis_step" and RunState.flood_over_knee():
		Vfx.word(origin + Vector2(0.0, -40.0), "Too deep", Color(0.7, 0.85, 1.0), 20)
		return false
	# Paid before it resolves, and refused if it cannot be. A bare caster with
	# no hero - the gates - casts for free, which is what they need.
	if hero != null and hero.has_method("spend_mana"):
		if not bool(hero.call("spend_mana", spell.cost())):
			cast_starved.emit(slot)
			return false

	# **Quickening** lands on the cooldown this cast lays down, which is the
	# *next* one the player waits for - a cast that shortened its own cooldown
	# would be a rate increase rather than a reward for casting.
	_cooldowns[slot] = _effective_cooldown(spell) * _quickening_scale()
	cooldown_changed.emit(slot, 1.0)
	_resolve(spell, aim, origin)
	_rider(slot, spell, aim, origin)
	# **Siphoning Veil** and **Echo of the Weave**, after the cast they ride.
	_siphon_ward(origin)
	_echo(slot, spell, aim, origin)
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
		"tower_haste":
			# **Dawn Bell.** The stagger is Tremor's own; this is the bell that
			# follows it, and it reaches the towers rather than the bodies.
			RunState.haste_the_towers(node.effect_value,
				Balance.DISCIPLINE_TOWER_HASTE_SECONDS)
			Vfx.ring(_foot(origin), Balance.DISCIPLINE_WALL_WARD_RADIUS,
				Color("ffd98a"), 0.7, 5.0)
			Sfx.play("sfx_spell_nova", -4.0)


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
	var middle: Vector2 = origin + aim * (_reach(spell) * 0.5)
	var sweep: float = _reach(spell) * 0.5 + Balance.DISCIPLINE_PURSUIT_WIDTH
	for enemy: Enemy in field.enemies_near(middle, sweep):
		if enemy.is_dying():
			continue
		if not (enemy.is_branded() or enemy.is_priority()):
			continue
		var body: Vector2 = enemy.combat_origin()
		var t: float = clampf((body - origin).dot(aim), 0.0, _reach(spell))
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
	for enemy: Enemy in field.enemies_near(origin, _reach(spell)):
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


## `share` is what an **Echo of the Weave** is worth: one for an ordinary cast,
## a fraction for the echo that follows it. Threaded through as a scale rather
## than as a second code path, so an echo is the same spell resolving again and
## nothing downstream has to learn that echoes exist.
func _resolve(spell: SpellData, aim: Vector2, origin: Vector2, share: float = 1.0) -> void:
	var power: float = spell.damage * Modifiers.multiplier(Modifiers.HERO_DAMAGE) 		* focus_power() * share
	# Where the spell lands, for what it does to the world.
	var lands: Vector2 = origin
	if spell.kind == SpellData.Kind.METEOR or spell.kind == SpellData.Kind.VOLLEY:
		lands = _foot(origin) + aim * _reach(spell)
	_touch_the_world(spell, lands, share)
	match spell.kind:
		SpellData.Kind.BLINK:
			# The destination is a place to stand, so it is built from the feet.
			# `origin` is the body, a head-height above them; adding the step to
			# it landed the hero that much up-screen on every Rift Step.
			blink_requested.emit(_foot(origin) + aim * _reach(spell))
		SpellData.Kind.NOVA:
			_forged("nova", origin, spell)
			_damage_area(origin, spell.effect_radius, power, spell.knockback, origin, spell.element)
			# **Blood Remembers.** Asked here rather than in `_rider`, because it
			# is a passive with no `spell_id` of its own - the Tempest is simply
			# the nova this hero happens to be casting.
			_consume_the_brands(origin, spell)
			EventBus.camera_shake_requested.emit(7.0, 0.25)
		SpellData.Kind.HOOK:
			_hook(origin, spell, power)
		SpellData.Kind.DRAIN:
			_drain(origin, aim, spell, power)
		SpellData.Kind.SHOCKWAVE:
			_forged("slam_impact", origin, spell)
			_damage_area(origin, spell.effect_radius, power, spell.knockback, origin, spell.element)
			EventBus.camera_shake_requested.emit(10.0, 0.35)
		SpellData.Kind.VEIL:
			veil_requested.emit(spell.duration, spell.speed_bonus)
		SpellData.Kind.WARD:
			_forged("ward", origin, spell)
			_ward_lane = _lane_at(origin)
			_ward_left = spell.duration
			# **Unbroken Oath.** A ward that shields the lane shields what is
			# standing in it, walls included. A passive again, so it is asked
			# rather than dispatched.
			_ward_the_walls(origin)
		SpellData.Kind.BEAM:
			_beam_spell = spell
			_beam_left = spell.duration
			_beam_aim = aim
		SpellData.Kind.COMPANION:
			_summon(spell, origin, aim)
		SpellData.Kind.METEOR:
			_aim_strike(_foot(origin) + aim * _reach(spell),
				spell.effect_radius, power, spell.knockback,
				Balance.SPELL_METEOR_DELAY)
		SpellData.Kind.VOLLEY:
			_volley(_foot(origin) + aim * _reach(spell), spell, power)


## **The forged sheet for a spell**, in the spell's own element.
##
## One helper rather than the same three lines at five call sites: which
## element a spell is decides how its sheet is tinted, and a reach worked out
## per call site is a reach that is wrong at one of them. It is the last
## thing each branch does with the cast and nothing reads it - the bound
## every feel change in this project is held to.
func _forged(effect: String, at: Vector2, spell: SpellData) -> void:
	var wide: float = maxf(spell.effect_radius, Balance.SPELL_FORGE_MIN_REACH) * 2.0
	Vfx.forge_play(effect, at, wide, TowerData.element_colour(spell.element))


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


## Puts one strike in the air. The telegraph is drawn where it will land, so
## the warning and the damage cannot disagree about the place.
func _aim_strike(at: Vector2, radius: float, power: float, knockback: float,
		delay: float) -> void:
	_falling.append({
		"at": at, "radius": radius, "power": power,
		"knockback": knockback, "left": maxf(delay, 0.01),
	})
	# The telegraph is `Vfx.ring` rather than a new effect: a ring that grows to
	# exactly the radius the damage will use, over exactly the delay before it
	# lands, is the warning - and building it from the same two numbers is what
	# stops the tell and the blow from ever disagreeing.
	Vfx.ring(at, radius, Balance.SPELL_STRIKE_WARNING_COLOUR,
		maxf(delay, 0.01), 3.0)


## Six small hits inside one circle, spread across the spell's duration.
##
## Scattered from the run's own stream rather than a fresh generator, so a
## seeded run lands its volley in the same places twice and a host and a guest
## watching the same cast see the same thing.
func _volley(at: Vector2, spell: SpellData, power: float) -> void:
	var strikes: int = maxi(Balance.SPELL_VOLLEY_STRIKES, 1)
	var rng: RandomNumberGenerator = RunState.rng("combat")
	var small: float = spell.effect_radius / sqrt(float(strikes))
	for index: int in strikes:
		var angle: float = rng.randf() * TAU
		var spread: float = spell.effect_radius * Balance.SPELL_VOLLEY_SCATTER
		# Square-rooted so the hits spread evenly over the circle's area
		# rather than clustering in the middle of it.
		var reach: float = spread * sqrt(rng.randf())
		var spot: Vector2 = at + Vector2(cos(angle), sin(angle)) * reach
		var when: float = spell.duration * float(index) / float(strikes)
		_aim_strike(spot, small, power, spell.knockback, when + 0.12)


## Lands everything whose moment has come.
func _tick_falling(delta: float) -> void:
	if _falling.is_empty():
		return
	for index: int in range(_falling.size() - 1, -1, -1):
		var strike: Dictionary = _falling[index]
		strike["left"] = float(strike["left"]) - delta
		if float(strike["left"]) > 0.0:
			continue
		var at: Vector2 = strike["at"]
		_damage_area(at, float(strike["radius"]), float(strike["power"]),
			float(strike["knockback"]), at)
		Vfx.ring(at, float(strike["radius"]),
			Balance.SPELL_STRIKE_LANDED_COLOUR, 0.30, 7.0)
		# The bloom, at the radius the ring already promised and never a
		# second reach - the bound every telegraphed blow here is held to.
		Vfx.forge_play("meteor_bloom", at, float(strike["radius"]) * 2.2,
			Balance.SPELL_STRIKE_LANDED_COLOUR)
		EventBus.camera_shake_requested.emit(6.0, 0.18)
		_falling.remove_at(index)


func _damage_area(centre: Vector2, radius: float, power: float, knockback: float, from: Vector2,
		element: int = -1) -> float:
	var dealt: float = 0.0
	for enemy: Enemy in field.enemies_near(centre, radius):
		if enemy.take_damage(power, from, knockback, true):
			dealt += power
			# A water spell leaves what it hits wet.
			if element == TowerData.Element.WATER:
				enemy.apply_wet(Balance.WET_SECONDS)
	return dealt


## A spell of an element works the world the way a tower of it does, by the
## mana it spent: fire warms the ground and feeds the ember, water wets and
## cools and feeds the tide, earth the tremor, air the gale. One event per
## cast; the climate takes it on its own tick.
func _touch_the_world(spell: SpellData, at: Vector2, share: float = 1.0) -> void:
	if spell == null or spell.element < 0 or field == null:
		return
	var spent: float = maxf(spell.mana_cost, 0.0) * share
	if spent <= 0.0:
		return
	var ground: Climate = field.climate() if field.has_method("climate") else null
	match spell.element:
		TowerData.Element.FIRE:
			if ground != null:
				ground.add_heat(at, Balance.SPELL_HEAT_PER_MANA * spent, Balance.SPELL_WORLD_RADIUS)
			RunState.ember += Balance.SPELL_STRAIN_PER_MANA * spent
		TowerData.Element.WATER:
			if ground != null:
				ground.add_heat(at, -Balance.SPELL_HEAT_PER_MANA * spent, Balance.SPELL_WORLD_RADIUS)
				ground.add_wet(at, Balance.SPELL_WET_PER_MANA * spent, Balance.SPELL_WORLD_RADIUS)
			RunState.tide += Balance.SPELL_STRAIN_PER_MANA * spent
		TowerData.Element.EARTH:
			RunState.tremor += Balance.SPELL_STRAIN_PER_MANA * spent
		TowerData.Element.AIR:
			RunState.gale += Balance.SPELL_STRAIN_PER_MANA * spent * 0.05


func _hook(origin: Vector2, spell: SpellData, power: float) -> void:
	for enemy: Enemy in field.enemies_near(origin, _reach(spell)):
		enemy.take_damage(power, origin, 0.0, true)
		# Negative knockback would be a hack; pulling is its own operation.
		enemy.pull_toward(origin, spell.knockback)


func _drain(origin: Vector2, aim: Vector2, spell: SpellData, power: float) -> void:
	var centre: Vector2 = origin + aim * (spell.effect_radius * 0.5)
	var dealt: float = _damage_area(centre, spell.effect_radius, power, spell.knockback, origin)
	if dealt > 0.0 and spell.lifesteal > 0.0:
		heal_requested.emit(dealt * spell.lifesteal)


## When the beam's terminus is next drawn. Run-scoped and read by nothing.
var _beam_spark: float = 0.0


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
	# **Where the beam ends, a few times a second rather than every frame.**
	# An aimed sheet laid along the beam's own angle, so the spray it throws
	# runs back up the beam instead of into the ground it is burning. On its
	# own clock because a sheet a frame is sixty sprites a second, and this
	# is decoration - `Graphics.particle_scale` takes it away entirely.
	_beam_spark -= delta
	if _beam_spark <= 0.0:
		_beam_spark = Balance.SPELL_BEAM_END_INTERVAL
		Vfx.forge_play("beam_end", origin + _beam_aim * reach,
			reach * Balance.SPELL_BEAM_END_SHARE,
			TowerData.element_colour(_beam_spell.element), _beam_aim.angle())


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


# --- The three that used to do nothing (2026-09-13) ---------------------------

## **Blood Remembers.** The Tempest takes the brands with it.
##
## A passive rather than a rider: it has no `spell_id` of its own, so it is
## asked at the cast rather than dispatched from `_rider`. Every branded body
## inside the nova gives up its brand for one extra blow, and the whole burst is
## capped - a road of forty branded bodies must not be a one-cast wipe.
func _consume_the_brands(origin: Vector2, spell: SpellData) -> void:
	var share: float = DisciplineEffects.trained_value("consume_marks_burst")
	if share <= 0.0 or field == null:
		return
	var spent: float = 0.0
	var taken: int = 0
	for enemy: Enemy in field.enemies_near(origin, spell.effect_radius):
		if enemy.is_dying() or not enemy.is_branded():
			continue
		var blow: float = minf(spell.damage * share,
			Balance.DISCIPLINE_MARK_BURST_CAP - spent)
		if blow <= 0.0:
			break
		spent += blow
		taken += 1
		enemy.clear_brand()
		enemy.take_damage(blow, origin, 0.0, false)
		Vfx.spark(enemy.combat_origin(), Color(0.86, 0.24, 0.3), 8, Vector2.UP, 210.0)
	if taken > 0:
		Vfx.ring(_foot(origin), spell.effect_radius, Color(0.86, 0.24, 0.3, 0.7), 0.35, 5.0)


## **Unbroken Oath.** A ward puts a shield on the walls near it.
##
## A shield rather than health, which is the card's own distinction - "never
## permanent tower HP". A barricade repaired outright would make the wall
## economy free; a shield is spent by the next thing that hits it.
func _ward_the_walls(origin: Vector2) -> void:
	var share: float = DisciplineEffects.trained_value("repair_blocker_shields")
	if share <= 0.0:
		return
	var centre: Vector2 = _foot(origin)
	var warded: int = 0
	for node: Node in get_tree().get_nodes_in_group(Barricade.GROUP):
		var wall := node as Barricade
		if wall == null or not is_instance_valid(wall) or wall.health == null:
			continue
		if wall.global_position.distance_to(centre) > Balance.DISCIPLINE_WALL_WARD_RADIUS:
			continue
		wall.health.add_shield(wall.health.max_hp * share)
		warded += 1
	if warded > 0:
		Vfx.ring(centre, Balance.DISCIPLINE_WALL_WARD_RADIUS,
			Color("9fd3ff"), 0.6, 4.0)


## **Break the Host.** An elite falling while a channel runs buys it a moment
## more, up to a hard cap the card promises out loud.
func extend_channel_on_elite(at: Vector2 = Vector2.ZERO) -> void:
	_beam_from = at
	var step: float = DisciplineEffects.trained_value("elite_extend_ultimate")
	if step <= 0.0 or _beam_left <= 0.0 or not is_channelling():
		return
	var room: float = Balance.DISCIPLINE_CHANNEL_EXTEND_CAP - _beam_extended
	if room <= 0.0:
		return
	var given: float = minf(step, room)
	_beam_left += given
	_beam_extended += given
	# At the enemy that fell rather than at the caster: this is a Node, not a
	# Node2D - it deliberately does not know where the hero is standing.
	Vfx.spark(_beam_from, Color("ffb35c"), 8, Vector2.UP, 200.0)


# --- The Arcane (2026-09-13) --------------------------------------------------

## **Wellspring.** A kill gives back a share of the pool.
##
## A share rather than a number, so it is worth the same at level one and at
## level a hundred - a flat refund would be everything early and nothing late,
## which is the shape that makes a node feel dead by Act III.
## **The Long Reach.** How far this spell actually throws.
##
## One function, and every throw in this file goes through it - a reach applied
## at four of five call sites is a node that works on some spells.
func _reach(spell: SpellData) -> float:
	return spell.cast_range * (1.0 + minf(
		DisciplineEffects.trained_value("arcane_reach"), Balance.ARCANE_REACH_CAP))


func _wellspring() -> void:
	if not DisciplineEffects.trained("mana_on_kill"):
		return
	mana_refunded.emit(Balance.ARCANE_MANA_ON_KILL)


## **Quickening.** A cast inside the window takes a share off the next
## cooldown, and starts the window again.
##
## Returns the scale the cooldown just laid down should be multiplied by, so
## the reduction lands on the *next* spell rather than on the one that earned
## it - a cast that shortened its own cooldown would be a rate increase.
func _quickening_scale() -> float:
	var share: float = DisciplineEffects.trained_value("cast_haste_chain")
	if share <= 0.0:
		return 1.0
	var scale: float = 1.0 - clampf(share, 0.0, 0.6) if _chain_left > 0.0 else 1.0
	_chain_left = Balance.ARCANE_CHAIN_SECONDS
	return scale


## **Siphoning Veil.** A cast leaves a ward, and Focus deepens it.
##
## The one Arcane effect that reads an attribute, and it reads the caster's own:
## a wizard's answer to being hit is that they were casting when it happened.
func _siphon_ward(origin: Vector2) -> void:
	var share: float = DisciplineEffects.trained_value("focus_ward")
	if share <= 0.0:
		return
	var focus: int = RunState.attribute(RunState.Attribute.FOCUS)
	var deepened: float = share + minf(float(focus) * Balance.ARCANE_WARD_FOCUS_PER_POINT,
		Balance.ARCANE_WARD_FOCUS_CAP)
	ward_requested.emit(deepened)
	Vfx.ring(_foot(origin), Balance.DISCIPLINE_AEGIS_RADIUS * 0.7,
		Color("c39bff"), 0.5, 4.0)


## **Echo of the Weave.** A cast sometimes happens twice, at a fraction.
##
## `_echoing` is what stops an echo echoing: without it a twenty-five percent
## chance is a geometric series rather than one extra cast, and the tail of that
## series is where a build stops being balanceable.
func _echo(_slot: int, spell: SpellData, aim: Vector2, origin: Vector2) -> bool:
	if _echoing:
		return false
	var chance: float = DisciplineEffects.trained_value("spell_echo")
	if chance <= 0.0 or RunState.rng("combat").randf() >= chance:
		return false
	_echoing = true
	_resolve(spell, aim, origin, Balance.ARCANE_ECHO_POWER)
	_echoing = false
	Vfx.ring(_foot(origin), Balance.DISCIPLINE_AEGIS_RADIUS * 0.5,
		Color("c39bff"), 0.4, 3.0)
	return true
