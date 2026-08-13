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

## A spell resolved, for feedback and the HUD.
signal spell_cast(slot: int, spell_id: String, at: Vector2)

## A slot's cooldown changed, 0..1 remaining.
signal cooldown_changed(slot: int, ratio: float)

var field: EnemyField = null

## Seconds remaining per slot, indexed the same as RunState.equipped_spells.
var _cooldowns: Array[float] = []

## The lane shield left by Bulwark Ward: lane index and seconds remaining.
var _ward_lane: int = -1
var _ward_left: float = 0.0

var _beam_left: float = 0.0
var _beam_spell: SpellData = null
var _beam_aim: Vector2 = Vector2.RIGHT


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


func is_ready(slot: int) -> bool:
	return slot < _cooldowns.size() and _cooldowns[slot] <= 0.0 and spell_in_slot(slot) != null


## Returns true if the spell went off.
func try_cast(slot: int, aim: Vector2, origin: Vector2) -> bool:
	if field == null or not is_ready(slot) or is_channelling():
		return false
	var spell: SpellData = spell_in_slot(slot)
	if spell == null:
		return false

	_cooldowns[slot] = _effective_cooldown(spell)
	cooldown_changed.emit(slot, 1.0)
	_resolve(spell, aim, origin)
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
	return maxf(spell.cooldown * (1.0 - reduction) + flat, 0.5)


func _resolve(spell: SpellData, aim: Vector2, origin: Vector2) -> void:
	var power: float = spell.damage * Modifiers.multiplier(Modifiers.HERO_DAMAGE)
	match spell.kind:
		SpellData.Kind.BLINK:
			blink_requested.emit(origin + aim * spell.cast_range)
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
	var tick_damage: float = _beam_spell.damage * delta * Modifiers.multiplier(Modifiers.HERO_DAMAGE)
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
