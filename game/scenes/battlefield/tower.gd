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
var _light: PointLight2D = null
var _command_overdrive_left: float = 0.0
var _command_rally_left: float = 0.0

## The tower's ground shadow, and its size at level 1 — upgrades scale the sprite
## and the shadow has to follow, so the level-1 measurement is kept rather than
## re-derived from an already-scaled sprite.
var _shadow: Sprite2D = null
var _shadow_base_scale: Vector2 = Vector2.ONE
var _shadow_base_y: float = 0.0

## Extra damage from the lane's same-element synergy (GDD §4.2) and terrain.
var _damage_bonus: float = 0.0
var _extra_chain_targets: int = 0
var _health: Health = null
var _health_bar: HealthBar = null


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
	_light = LightKit.add_light(self, TowerData.element_colour(data.element),
		Balance.TOWER_LIGHT_RADIUS, Balance.TOWER_LIGHT_ENERGY, Balance.TOWER_LIGHT_FLICKER)

	# A tower is scenery as far as shadows go: it sits still and it is solid, so
	# every torch near it throws its shape across the road.
	_shadow = ShadowKit.add_contact(self, sprite)
	if _shadow != null:
		_shadow_base_scale = _shadow.scale
		_shadow_base_y = _shadow.position.y
	if sprite.texture != null:
		var half: Vector2 = sprite.texture.get_size() * 0.5
		ShadowKit.add_caster(self, half.x * 0.36, half.y * 0.16,
			Balance.SHADOW_LAYER_SCENERY, half.y * 0.44)

	_apply_level_look()
	_build_health()
	call_deferred("refresh_modifiers")
	EventBus.relic_socketed.connect(_on_relic_changed)
	EventBus.relic_unsocketed.connect(_on_relic_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
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
	if _health != null:
		_health.flat_damage_reduction = _field.lane_armour(lane)


func _on_relic_changed(_id: String) -> void:
	refresh_modifiers()


func _on_boss_defeated(_id: String, _act: int) -> void:
	refresh_modifiers()


func _process(delta: float) -> void:
	if data == null or _field == null or not RunState.is_command_combat():
		return
	_command_overdrive_left = maxf(_command_overdrive_left - delta, 0.0)
	_command_rally_left = maxf(_command_rally_left - delta, 0.0)
	var rate: float = Balance.COMMAND_OVERDRIVE_RATE \
		if _command_overdrive_left > 0.0 else 1.0
	_cooldown -= delta * rate
	if _cooldown > 0.0:
		return

	if _health != null and _health.is_dead:
		return
	var targets: Array[Enemy] = _acquire_targets()
	if targets.is_empty():
		return
	_cooldown = data.interval_at(level)
	_fire(targets)


func effective_damage() -> float:
	var command_bonus: float = Balance.COMMAND_OVERDRIVE_UTILITY \
		if _command_overdrive_left > 0.0 else 0.0
	return data.damage_at(level) * (1.0 + _damage_bonus + command_bonus)


func command_overdrive(duration: float) -> void:
	_command_overdrive_left = maxf(_command_overdrive_left, duration)
	_cooldown = 0.0
	Vfx.ring(global_position, effective_range() * 0.52,
		Color("e8a33d", 0.82), 0.48, 6.0)
	Vfx.rays(global_position, Color("fff0bd"), 10, 82.0)


func command_rally(duration: float) -> void:
	_command_rally_left = maxf(_command_rally_left, duration)
	if _health != null:
		_health.add_invulnerability(duration)
	Vfx.ring(global_position, 68.0, Color("d9cdb8", 0.72), 0.42, 5.0)


func command_reset_attack() -> void:
	_cooldown = 0.0


func upgrade_to(new_level: int) -> void:
	level = clampi(new_level, 1, Balance.TOWER_MAX_LEVEL)
	_draw_range_ring()
	refresh_modifiers()
	_apply_level_look()
	_refresh_health_for_level()

	# The upgrade gets a moment of its own. Paying resources should feel like
	# something happened, not like a number changed in a panel.
	var colour: Color = TowerData.element_colour(data.element)
	Vfx.build_burst(global_position, colour, true)


## Colourblind modes remap semantic element cues in-place. The sprite keeps its
## authored material, while the persistent light, tier tint and range cue all
## update immediately and new projectiles inherit the same palette.
func refresh_palette() -> void:
	if data == null:
		return
	if _light != null:
		_light.color = TowerData.element_colour(data.element)
	_draw_range_ring()
	_apply_level_look()


## A higher tower is bigger, warmer and brighter. Level has to read at a glance
## across twelve slots without clicking any of them.
func _apply_level_look() -> void:
	var step: float = float(level - 1)
	var growth: float = 1.0 + step * Balance.TOWER_LEVEL_SCALE_STEP
	sprite.scale = Vector2.ONE * growth
	# A bigger tower stands on more ground. Left out, an upgraded tower appears
	# to lift off its own shadow.
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.scale = _shadow_base_scale * growth
		_shadow.position.y = _shadow_base_y * growth

	var colour: Color = TowerData.element_colour(data.element)
	sprite.self_modulate = Color.WHITE.lerp(
		colour.lerp(Color.WHITE, 0.55), step * Balance.TOWER_LEVEL_TINT_STEP)

	if _light != null:
		var boost: float = 1.0 + step * Balance.TOWER_LEVEL_LIGHT_STEP
		_light.energy = Balance.TOWER_LIGHT_ENERGY * boost
		_light.texture_scale = (Balance.TOWER_LIGHT_RADIUS / 128.0) * (1.0 + step * 0.25)


func show_range(visible_now: bool) -> void:
	if range_ring != null:
		range_ring.visible = visible_now


## The player chooses a doctrine per built tower. "First" is the safe default;
## the alternatives turn high-level towers into active tactical tools against
## the authored formations instead of fire-and-forget stat sticks.
func _acquire_targets() -> Array[Enemy]:
	var found: Array[Enemy] = []
	var reach: float = effective_range()
	var candidates: Array[Enemy] = _field.enemies_near(global_position, reach)
	if candidates.is_empty():
		return found

	var priority: int = RunState.target_priority_in_slot(lane, slot)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return _target_score(a, priority) > _target_score(b, priority))

	var wanted: int = 1 + data.extra_targets + _extra_chain_targets
	for enemy: Enemy in candidates:
		if found.size() >= wanted:
			break
		found.append(enemy)
	return found


func _target_score(enemy: Enemy, priority: int) -> float:
	if enemy == null or enemy.data == null:
		return -INF
	# A small closeness tie-break keeps every doctrine deterministic and prevents
	# two equal targets from shuffling order every acquisition.
	var closeness: float = 1.0 - clampf(enemy.global_position.length() \
		/ maxf(Balance.LANE_SPAWN_RADIUS, 1.0), 0.0, 1.0)
	match priority:
		TowerData.TargetPriority.STRONG:
			var target_health: Health = Health.of(enemy)
			return (target_health.max_hp if target_health != null else enemy.data.max_hp) \
				+ closeness * 0.01
		TowerData.TargetPriority.FAST:
			return enemy.targeting_speed() + closeness * 0.01
		TowerData.TargetPriority.SPECIAL:
			var role_score: float = 0.0
			match enemy.data.category:
				EnemyData.Category.BOSS:
					role_score = 1000.0
				EnemyData.Category.ELITE:
					role_score = 500.0
			match enemy.data.role:
				EnemyData.Role.HOWLER:
					role_score += 90.0
				EnemyData.Role.BURROWER:
					role_score += 80.0
				EnemyData.Role.WARDEN:
					role_score += 70.0
				EnemyData.Role.VANGUARD:
					role_score += 55.0
			return role_score + closeness
		_:
			return closeness


func _fire(targets: Array[Enemy]) -> void:
	var primary: Enemy = targets[0]
	EventBus.tower_fired.emit(lane, slot, primary.global_position)

	# An aura tower has no projectile: it affects everything in reach at once,
	# and a shot flying out to each target would be a lie about how it works.
	if _is_aura():
		for enemy: Enemy in _field.enemies_near(global_position, effective_range()):
			_hit(enemy)
		Vfx.ring(global_position, effective_range(),
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
	shot.tier = level
	_field.add_projectile(shot, global_position + Vector2(0.0, -Balance.TOWER_SPRITE_LIFT))


func _hit(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	if effective_damage() > 0.0:
		enemy.take_damage(effective_damage(), global_position,
			data.knockback * Modifiers.multiplier(Modifiers.KNOCKBACK))
	var utility: float = data.utility_at(level)
	if data.slow_factor < 1.0:
		# A stronger slow is a *lower* factor, so the relic subtracts.
		var slow: float = 1.0 - (1.0 - data.slow_factor) * utility
		enemy.apply_slow(maxf(slow - Modifiers.value(Modifiers.SLOW_STRENGTH), 0.1),
			data.slow_duration * utility)
	if data.burn_dps > 0.0:
		enemy.apply_burn(data.burn_dps * utility * Modifiers.multiplier(Modifiers.BURN_DAMAGE),
			data.burn_duration * sqrt(utility))
	if data.freeze_chance > 0.0 and randf() < minf(data.freeze_chance * utility, 0.82):
		enemy.apply_freeze(1.2 * sqrt(utility))


func effective_range() -> float:
	return data.range_at(level) * Modifiers.multiplier(Modifiers.TOWER_RANGE)


## Taunting towers are actual blockers now. They use the same Health component
## as every other attack target, and their authored HP finally matters.
func _build_health() -> void:
	if data.max_hp <= 0.0:
		return
	_health = Health.new()
	_health.name = "Health"
	add_child(_health)
	_refresh_health_for_level()
	_health.revive()
	_health.damaged.connect(func(amount: float, from: Vector2) -> void:
		Vfx.number(global_position, amount, Color("d9cdb8"))
		Vfx.spark(global_position, Color("a78f6d"), 5,
			(global_position - from).normalized(), 120.0))
	_health.died.connect(_on_destroyed)

	var health_scene: PackedScene = load("res://scenes/ui/health_bar.tscn")
	_health_bar = health_scene.instantiate() as HealthBar
	if _health_bar == null:
		return
	_health_bar.hide_until_damaged = true
	_health_bar.position = Vector2(0.0, -Balance.TOWER_SPRITE_LIFT * 2.4)
	add_child(_health_bar)
	_health_bar.bind(_health)


func _refresh_health_for_level() -> void:
	if _health == null or data.max_hp <= 0.0:
		return
	var ratio: float = _health.ratio() if _health.max_hp > 0.0 else 1.0
	_health.max_hp = data.max_hp * data.utility_at(level)
	_health.current_hp = _health.max_hp * ratio
	_health.changed.emit(_health.current_hp, _health.max_hp)


func _on_destroyed(_from: Vector2) -> void:
	Vfx.spark(global_position, TowerData.element_colour(data.element), 18,
		Vector2.ZERO, 260.0)
	Vfx.ring(global_position, 110.0,
		Color(TowerData.element_colour(data.element), 0.7), 0.5, 5.0)
	EventBus.camera_shake_requested.emit(9.0, 0.4)
	RunState.towers_lost += 1
	RunState.clear_slot(lane, slot)


func _draw_range_ring() -> void:
	if range_ring == null:
		return
	var reach: float = effective_range()
	var points: PackedVector2Array = []
	for i: int in 49:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 48.0) * reach)
	range_ring.points = points
	range_ring.width = 2.0
	range_ring.default_color = Color(TowerData.element_colour(data.element), 0.35)
	range_ring.visible = false
