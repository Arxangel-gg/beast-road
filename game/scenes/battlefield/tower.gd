class_name Tower
extends Node2D

## An auto-firing tower standing in one of a lane's three build spots (GDD §4).
##
## All behaviour is read off TowerData: single target, AoE, chains, slows,
## burns, freezes, taunts. There is no per-tower script and there must never be
## one — eighteen towers are eighteen `.tres` files.

const GROUP: StringName = &"towers"

@export var sprite: Sprite2D
@export var range_ring: Line2D

## Set by the battlefield so shots can be parented outside the tower.
var projectile_scene: PackedScene = null

var data: TowerData = null
var level: int = 1
var lane: int = 0
var slot: int = 0

var _field: Battlefield = null
var _cooldown: float = 0.0

## Extra damage from the lane's same-element synergy (GDD §4.2) and terrain.
var _damage_bonus: float = 0.0
var _extra_chain_targets: int = 0


func setup(tower_data: TowerData, tower_level: int, lane_index: int, slot_index: int, field: Battlefield) -> void:
	data = tower_data
	level = tower_level
	lane = lane_index
	slot = slot_index
	_field = field


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		queue_free()
		return
	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	_draw_range_ring()
	refresh_modifiers()
	LightKit.add_light(self, TowerData.element_colour(data.element),
		Balance.TOWER_LIGHT_RADIUS, Balance.TOWER_LIGHT_ENERGY, Balance.TOWER_LIGHT_FLICKER)
	# Stagger the first shot so a freshly built lane does not fire in lockstep.
	_cooldown = randf() * data.interval_at(level)


## Recomputed whenever the lane's contents or the terrain change, rather than
## every frame — these only move when the player builds something.
func refresh_modifiers() -> void:
	_damage_bonus = 0.0
	_extra_chain_targets = 0

	if RunState.lane_has_element_synergy(lane) and not data.is_combination:
		_damage_bonus += Balance.SAME_ELEMENT_LANE_BONUS

	_damage_bonus += Modifiers.value(Modifiers.TOWER_DAMAGE)
	_extra_chain_targets += int(Modifiers.value(Modifiers.CHAIN_TARGETS))

	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		if terrain.favoured_element == data.element:
			_damage_bonus += terrain.favoured_element_bonus
		if data.extra_targets > 0:
			_extra_chain_targets += terrain.bonus_chain_targets


func _process(delta: float) -> void:
	if data == null or _field == null:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return

	var targets: Array[Enemy] = _acquire_targets()
	if targets.is_empty():
		return
	_cooldown = data.interval_at(level)
	_fire(targets)


func effective_damage() -> float:
	return data.damage_at(level) * (1.0 + _damage_bonus)


func upgrade_to(new_level: int) -> void:
	level = clampi(new_level, 1, Balance.TOWER_MAX_LEVEL)
	_draw_range_ring()
	refresh_modifiers()


func show_range(visible_now: bool) -> void:
	if range_ring != null:
		range_ring.visible = visible_now


## Nearest-first, then as many extra targets as the tower chains to. Nearest to
## the town would be better play, but this tower does not know where along the
## lane "ahead" is; the battlefield sorts that for AoE.
func _acquire_targets() -> Array[Enemy]:
	var found: Array[Enemy] = []
	var reach: float = data.attack_range * Modifiers.multiplier(Modifiers.TOWER_RANGE)
	var candidates: Array[Enemy] = _field.enemies_near(global_position, reach)
	if candidates.is_empty():
		return found

	# Prefer whatever is closest to the town: that is the thing about to matter.
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.length() < b.global_position.length())

	var wanted: int = 1 + data.extra_targets + _extra_chain_targets
	for enemy: Enemy in candidates:
		if found.size() >= wanted:
			break
		found.append(enemy)
	return found


func _fire(targets: Array[Enemy]) -> void:
	var primary: Enemy = targets[0]
	EventBus.tower_fired.emit(lane, slot, primary.global_position)

	# An aura tower has no projectile: it affects everything in reach at once,
	# and a shot flying out to each target would be a lie about how it works.
	if _is_aura():
		for enemy: Enemy in _field.enemies_near(global_position, data.attack_range):
			_hit(enemy)
		Vfx.ring(global_position, data.attack_range,
			Color(TowerData.element_colour(data.element), 0.30), 0.45, 3.0)
		return

	for enemy: Enemy in targets:
		_launch(enemy)


## True for towers that pulse an area rather than firing at something.
func _is_aura() -> bool:
	return data.aoe_radius > 0.0 and effective_damage() <= 0.0


## Sends a shot at `enemy`. Parented to the battlefield's effect layer rather
## than to the tower, so it keeps flying if the tower is sold mid-flight.
func _launch(enemy: Enemy) -> void:
	if projectile_scene == null or _field == null:
		_hit(enemy)
		return
	var shot := projectile_scene.instantiate() as Projectile
	if shot == null:
		_hit(enemy)
		return
	shot.setup(enemy, data, effective_damage(),
		data.knockback * Modifiers.multiplier(Modifiers.KNOCKBACK))
	_field.add_projectile(shot, global_position + Vector2(0.0, -Balance.TOWER_SPRITE_LIFT))


func _hit(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	if effective_damage() > 0.0:
		enemy.take_damage(effective_damage(), global_position,
			data.knockback * Modifiers.multiplier(Modifiers.KNOCKBACK))
	if data.slow_factor < 1.0:
		# A stronger slow is a *lower* factor, so the relic subtracts.
		enemy.apply_slow(maxf(data.slow_factor - Modifiers.value(Modifiers.SLOW_STRENGTH), 0.1), data.slow_duration)
	if data.burn_dps > 0.0:
		enemy.apply_burn(data.burn_dps * Modifiers.multiplier(Modifiers.BURN_DAMAGE), data.burn_duration)
	if data.freeze_chance > 0.0 and randf() < data.freeze_chance:
		enemy.apply_freeze(1.2)


func _draw_range_ring() -> void:
	if range_ring == null:
		return
	var reach: float = data.attack_range * Modifiers.multiplier(Modifiers.TOWER_RANGE)
	var points: PackedVector2Array = []
	for i: int in 49:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 48.0) * reach)
	range_ring.points = points
	range_ring.width = 2.0
	range_ring.default_color = Color(TowerData.element_colour(data.element), 0.35)
	range_ring.visible = false
