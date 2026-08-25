class_name Tower
extends Node2D

## An auto-firing tower standing on a 2x2 patch of the battlefield grid (GDD §13).
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

## Top-left tile of this tower's 2x2 footprint. Its identity on the grid.
var anchor: Vector2i = Vector2i.ZERO


## Which road this tower answers to, for synergy, road armour and Rally.
## Free placement means a tower is not *in* a lane; the nearest cardinal is.
func lane() -> int:
	return RunState.tower_lane(anchor)

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

## The live weather's multiplier for this tower's element.
var _weather_scale: float = 1.0
var _extra_chain_targets: int = 0
var _health: Health = null
var _health_bar: HealthBar = null
var _damage_flames: Array[Flame] = []
var _step_wobble: float = 0.0

## Idle animation state. The phase starts scattered so a row of towers breathes
## out of step - in unison it reads as a screen-wide pulse rather than as
## buildings settling.
var _idle_phase: float = 0.0
var _idle_frame_clock: float = 0.0
var _idle_frames: Array[Texture2D] = []
var _level_scale: Vector2 = Vector2.ONE

## True when the host decides this tower's shots and this machine only draws
## them. Set by `CoopWorld` on a guest; false in single player and on the host.
var puppet: bool = false


## The plot centre: where this tower *is*, for anything that measures.
##
## The node itself stands one tile lower, on the front edge of its plot, because
## that is the only way to make it y-sort against ground foliage by the ground it
## occupies. Foliage growing in front of a tower has to draw in front of it, and
## sorting on a structure's middle gets that backwards for everything in the
## lower half of the sprite.
func origin() -> Vector2:
	return global_position + Vector2(0.0, -Balance.TOWER_SORT_LIFT)


func setup(tower_data: TowerData, tower_level: int, tile: Vector2i, field: Battlefield) -> void:
	data = tower_data
	level = tower_level
	anchor = tile
	_field = field


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		queue_free()
		return
	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	_idle_frames = GameData.load_idle_frames(path)
	_draw_range_ring()
	refresh_modifiers()
	_light = LightKit.add_light(self, TowerData.element_colour(data.element),
		Balance.TOWER_LIGHT_RADIUS, Balance.TOWER_LIGHT_ENERGY, Balance.TOWER_LIGHT_FLICKER)

	# A tower is scenery as far as shadows go: it sits still and it is solid, so
	# every torch near it throws its shape across the road.
	# Everything visible is lifted back to the plot centre, so moving the node
	# down to its base changes the sorting and nothing else.
	sprite.position.y -= Balance.TOWER_SORT_LIFT
	if range_ring != null:
		range_ring.position.y -= Balance.TOWER_SORT_LIFT

	_shadow = ShadowKit.add_contact(self, sprite)
	if _shadow != null:
		_shadow_base_scale = _shadow.scale
		_shadow_base_y = _shadow.position.y
	if sprite.texture != null:
		var half: Vector2 = sprite.texture.get_size() * 0.5
		ShadowKit.add_caster(self, half.x * 0.36, half.y * 0.16,
			Balance.SHADOW_LAYER_SCENERY, half.y * 0.44)

	_idle_phase = RunState.rng("combat").randf() * TAU
	if not _idle_frames.is_empty():
		_idle_frame_clock = _idle_phase / TAU * float(_idle_frames.size())
	_apply_level_look()
	_build_health()
	call_deferred("refresh_modifiers")
	EventBus.relic_socketed.connect(_on_relic_changed)
	EventBus.relic_unsocketed.connect(_on_relic_changed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.beast_step_landed.connect(_on_beast_step)
	# Stagger the first shot so a freshly built lane does not fire in lockstep.
	_cooldown = RunState.rng("combat").randf() * data.interval_at(level)


## Recomputed whenever the lane's contents or the terrain change, rather than
## every frame — these only move when the player builds something.
func refresh_modifiers() -> void:
	_damage_bonus = 0.0
	_weather_scale = 1.0
	_extra_chain_targets = 0

	if RunState.has_fusion_synergy(anchor) and not data.is_combination:
		_damage_bonus += Balance.SAME_ELEMENT_LANE_BONUS

	_extra_chain_targets += int(Modifiers.value(Modifiers.CHAIN_TARGETS))

	# Weather multiplies where the region's affinity adds.
	#
	# Two additives on one tower is how a "+40%" turns out to be +95% and neither
	# number explains it. A multiplier also means weather reads the same whatever
	# else the tower has going for it: a Downpour costs a fire tower a fifth of
	# its damage on any road, in any act, with any relic.
	_weather_scale = RunState.weather_scale(data.element)

	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		if terrain.favoured_element == data.element:
			_damage_bonus += terrain.favoured_element_bonus
		if data.extra_targets > 0:
			_extra_chain_targets += terrain.bonus_chain_targets
	if _health != null:
		_health.flat_damage_reduction = _field.lane_armour(lane())


func _on_weather_changed(_id: String) -> void:
	refresh_modifiers()


func _on_relic_changed(_id: String) -> void:
	refresh_modifiers()


func _on_boss_defeated(_id: String, _act: int) -> void:
	refresh_modifiers()


func _process(delta: float) -> void:
	_tick_step_wobble(delta)
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
	# A puppet tower does not choose. Its shots arrive from the host, and letting
	# it acquire locally would have the two screens firing at different enemies
	# on different cooldowns - the same drift the enemies themselves used to have.
	if puppet:
		return
	var targets: Array[Enemy] = _acquire_targets()
	if targets.is_empty():
		return
	_cooldown = data.interval_at(level)
	_fire(targets)


func effective_damage() -> float:
	var command_bonus: float = Balance.COMMAND_OVERDRIVE_UTILITY \
		if _command_overdrive_left > 0.0 else 0.0
	# Read relic damage live. Regional relic adapters can cross their town-health
	# threshold between shots, so caching this value at build time would leave the
	# HUD and actual combat state disagreeing until some unrelated refresh.
	var relic_bonus: float = Modifiers.value(Modifiers.TOWER_DAMAGE)
	var total: float = 1.0 + _damage_bonus + relic_bonus + command_bonus
	return data.damage_at(level) * total * _weather_scale


## What this shot actually lands for.
##
## `effective_damage` stays the average, because every balance number and every
## HUD figure is written in those terms; only the blow itself varies. Splitting
## the two means a spread can be tuned, or set to zero, without any of the
## arithmetic around it moving.
func rolled_damage() -> float:
	return TowerData.roll_damage(effective_damage(), RunState.rng("combat"))


func command_overdrive(duration: float) -> void:
	_command_overdrive_left = maxf(_command_overdrive_left, duration)
	_cooldown = 0.0
	Vfx.ring(origin(), effective_range() * 0.52,
		Color("e8a33d", 0.82), 0.48, 6.0)
	Vfx.rays(origin(), Color("fff0bd"), 10, 82.0)


func command_rally(duration: float) -> void:
	_command_rally_left = maxf(_command_rally_left, duration)
	if _health != null:
		_health.add_invulnerability(duration)
	Vfx.ring(origin(), 68.0, Color("d9cdb8", 0.72), 0.42, 5.0)


func command_reset_attack() -> void:
	_cooldown = 0.0


func upgrade_to(new_level: int) -> void:
	var previous_level: int = level
	level = clampi(new_level, 1, Balance.TOWER_MAX_LEVEL)
	_draw_range_ring()
	refresh_modifiers()
	_apply_level_look()
	_refresh_health_for_level()
	if level != previous_level:
		_rebuild_damage_flames()

	# The upgrade gets a moment of its own. Paying resources should feel like
	# something happened, not like a number changed in a panel.
	if level != previous_level:
		var colour: Color = TowerData.element_colour(data.element)
		Vfx.build_burst(origin(), colour, true)


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
	# Stored rather than assigned: the idle multiplies this every frame, and a
	# tower that wrote its level scale straight to the sprite would fight it.
	_level_scale = Vector2.ONE * growth
	sprite.scale = _level_scale
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
	var candidates: Array[Enemy] = _field.enemies_near(origin(), reach)
	if candidates.is_empty():
		return found

	var priority: int = RunState.target_priority_at(anchor)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return _target_score(a, priority) > _target_score(b, priority))

	var wanted: int = 1 + data.extra_targets_at(level) + _extra_chain_targets
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
	EventBus.tower_fired.emit(anchor, primary.global_position)

	# An aura tower has no projectile: it affects everything in reach at once,
	# and a shot flying out to each target would be a lie about how it works.
	if _is_aura():
		for enemy: Enemy in _field.enemies_near(origin(), effective_range()):
			_hit(enemy)
		Vfx.ring(origin(), effective_range(),
			Color(TowerData.element_colour(data.element), 0.30), 0.45, 3.0)
		return

	for enemy: Enemy in targets:
		_launch(enemy)


## Plays a shot the host has already decided on.
##
## The host sends *where* its primary target was rather than *which* enemy it
## was. A position needs no identity to survive the wire and no lookup at the far
## end, and it is exact: the same batch that placed the puppets placed them at
## the coordinates this was measured against, so the nearest one to that point is
## the enemy the host meant.
##
## Nothing here damages anything. Puppets ignore damage and status by design -
## the host has already resolved the hit and reports it as health in the next
## batch - so what this adds is purely the part the guest was missing, which is
## seeing its towers work at all.
func fire_remote(at: Vector2) -> void:
	if data == null or _field == null:
		return
	EventBus.tower_fired.emit(anchor, at)
	if _is_aura():
		Vfx.ring(origin(), effective_range(),
			Color(TowerData.element_colour(data.element), 0.30), 0.45, 3.0)
		return
	var target: Enemy = _nearest_enemy(at)
	# The enemy died between the host firing and the packet arriving. A homing
	# shot with nothing to home on flies off the field, which reads worse than a
	# shot that never appears.
	if target == null:
		return
	_launch(target)


## The enemy the host meant, identified by where it said the shot was going.
func _nearest_enemy(at: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance: float = Balance.COOP_SHOT_MATCH_RANGE
	for enemy: Enemy in _field.enemies_near(at, Balance.COOP_SHOT_MATCH_RANGE):
		var distance: float = enemy.global_position.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


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
	shot.setup(enemy, data, rolled_damage(),
		data.knockback_at(level) * Modifiers.multiplier(Modifiers.KNOCKBACK))
	shot.tier = level
	_field.add_projectile(shot, origin() + Vector2(0.0, -Balance.TOWER_SPRITE_LIFT))


func _hit(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	if effective_damage() > 0.0:
		enemy.take_damage(rolled_damage(), origin(),
			data.knockback_at(level) * Modifiers.multiplier(Modifiers.KNOCKBACK))
	var utility: float = data.utility_at(level)
	if data.slow_factor < 1.0:
		# A stronger slow is a *lower* factor, so the relic subtracts.
		var slow: float = 1.0 - (1.0 - data.slow_factor) * utility
		enemy.apply_slow(maxf(slow - Modifiers.value(Modifiers.SLOW_STRENGTH), 0.1),
			data.slow_duration * utility)
	if data.burn_dps > 0.0:
		enemy.apply_burn(data.burn_dps * utility * Modifiers.multiplier(Modifiers.BURN_DAMAGE),
			data.burn_duration * sqrt(utility))
	if data.freeze_chance > 0.0 and RunState.rng("combat").randf() \
			< minf(data.freeze_chance * utility, 0.82):
		enemy.apply_freeze(1.2 * sqrt(utility))


func effective_range() -> float:
	return data.range_at(level) * Modifiers.multiplier(Modifiers.TOWER_RANGE)


## Taunting towers are actual blockers now. They use the same Health component
## as every other attack target, and their authored HP finally matters.
func _build_health() -> void:
	_health = Health.new()
	_health.name = "Health"
	add_child(_health)
	_refresh_health_for_level()
	_health.revive()
	_health.damaged.connect(func(amount: float, from: Vector2) -> void:
		Vfx.number(origin(), amount, Color("d9cdb8"))
		Vfx.spark(origin(), Color("a78f6d"), 5,
			(origin() - from).normalized(), 120.0)
		_pulse_impact(from)
		_refresh_damage_flames())
	_health.changed.connect(func(_current: float, _maximum: float) -> void:
		_refresh_damage_flames())
	_health.died.connect(_on_destroyed)

	var health_scene: PackedScene = load("res://scenes/ui/health_bar.tscn")
	_health_bar = health_scene.instantiate() as HealthBar
	if _health_bar == null:
		return
	_health_bar.hide_until_damaged = true
	_health_bar.position = Vector2(0.0,
		-Balance.TOWER_SPRITE_LIFT * 2.4 - Balance.TOWER_SORT_LIFT)
	add_child(_health_bar)
	_health_bar.bind(_health)
	_build_damage_flames()


func _refresh_health_for_level() -> void:
	if _health == null or data.max_hp <= 0.0:
		return
	var ratio: float = _health.ratio() if _health.max_hp > 0.0 else 1.0
	_health.max_hp = data.max_hp * data.utility_at(level)
	_health.current_hp = _health.max_hp * ratio
	_health.changed.emit(_health.current_hp, _health.max_hp)


func _on_destroyed(_from: Vector2) -> void:
	Vfx.spark(origin(), TowerData.element_colour(data.element), 18,
		Vector2.ZERO, 260.0)
	Vfx.ring(origin(), 110.0,
		Color(TowerData.element_colour(data.element), 0.7), 0.5, 5.0)
	EventBus.camera_shake_requested.emit(9.0, 0.4)
	RunState.towers_lost += 1
	RunState.clear_tower(anchor)


func is_vulnerable() -> bool:
	return _health != null and not _health.is_dead


func needs_repair() -> bool:
	return is_vulnerable() and _health.current_hp < _health.max_hp - 0.5


func repair(fraction: float) -> void:
	if not is_vulnerable():
		return
	_health.heal(_health.max_hp * clampf(fraction, 0.0, 1.0))
	_refresh_damage_flames()
	Vfx.ring(origin(), 74.0, Color(0.58, 0.88, 0.64, 0.65), 0.45, 5.0)
	Vfx.spark(origin(), Color("b7e6c0"), 12, Vector2.UP, 150.0)
	Sfx.play("sfx_tower_upgrade", -5.0)


## Damage fires are anchored to the actual alpha silhouette, not fixed world
## coordinates. Each authored tower therefore burns from its own roofline and
## upper structure even though all eighteen share this script.
func _build_damage_flames() -> void:
	if sprite == null or sprite.texture == null:
		return
	var image: Image = sprite.texture.get_image()
	if image == null or image.is_empty():
		return
	for fraction: float in [0.34, 0.62, 0.49]:
		var column: int = clampi(int(round(float(image.get_width() - 1) * fraction)),
			0, image.get_width() - 1)
		var first_opaque: int = -1
		for y: int in image.get_height():
			if image.get_pixel(column, y).a > 0.2:
				first_opaque = y
				break
		if first_opaque < 0:
			continue
		var fire := Flame.new()
		fire.name = "DamageFlame%d" % _damage_flames.size()
		var local_x: float = (float(column) - float(image.get_width()) * 0.5) * sprite.scale.x
		var local_y: float = (float(first_opaque) - float(image.get_height()) * 0.5 \
			+ float(image.get_height()) * 0.14) * sprite.scale.y
		fire.position = sprite.position + Vector2(local_x, local_y)
		fire.z_index = 2
		add_child(fire)
		fire.configure(11.0 + float(_damage_flames.size()) * 1.5)
		fire.set_lit(false)
		_damage_flames.append(fire)


## Upgrade scaling changes the sprite silhouette in local space. Re-sampling
## after the scale change keeps every fire attached to its authored roofline.
func _rebuild_damage_flames() -> void:
	for fire: Flame in _damage_flames:
		if is_instance_valid(fire):
			fire.queue_free()
	_damage_flames.clear()
	_build_damage_flames()
	_refresh_damage_flames()


func _refresh_damage_flames() -> void:
	if _damage_flames.is_empty() or _health == null:
		return
	var damage: float = 1.0 - _health.ratio()
	var wanted: int = 0
	if damage >= 0.22:
		wanted = 1
	if damage >= 0.48:
		wanted = 2
	if damage >= 0.74:
		wanted = 3
	for index: int in _damage_flames.size():
		var fire: Flame = _damage_flames[index]
		var burning: bool = index < wanted
		fire.set_lit(burning)
		if burning:
			fire.set_intensity(clampf(0.45 + damage * 0.65, 0.0, 1.0))


func _pulse_impact(from: Vector2) -> void:
	var away: Vector2 = origin() - from
	var side: float = signf(away.x) if absf(away.x) > 0.01 else 1.0
	_step_wobble += side * 1.1


func _on_beast_step(impulse: Vector2, strength: float) -> void:
	if _health == null or _health.is_dead:
		return
	# A tall structure torques whichever way it is shoved. Sideways tips it
	# directly; a shove along the view axis still rocks it, but a 2D rotation
	# cannot show that head-on, so it reads as a shallower lean rather than as
	# nothing at all - which is what a bare signf(x) gave on a cardinal step.
	var push: Vector2 = impulse.normalized()
	var lean: float = push.x + push.y * 0.35
	_step_wobble = -lean * Balance.BEAST_STEP_WOBBLE_DEGREES * 0.45 * strength


## The beast's step, and the tower's own idle, summed into one transform.
##
## Two channels rather than two writers: the wobble is a reaction that decays to
## zero and the idle never stops, and if both assigned `sprite.rotation` the
## later one would simply erase the earlier. Same rule the SpriteAnimator uses.
func _tick_step_wobble(delta: float) -> void:
	if sprite == null:
		return
	_step_wobble = move_toward(_step_wobble, 0.0, 12.0 * delta)
	var breathe: float = 0.0
	var sway: float = 0.0
	if not _idle_frames.is_empty():
		_idle_frame_clock += delta * Balance.STRUCTURE_IDLE_FRAME_RATE
		var frame: int = int(floor(_idle_frame_clock)) % _idle_frames.size()
		sprite.texture = _idle_frames[frame]
	else:
		_idle_phase += delta * Balance.STRUCTURE_IDLE_RATE * TAU
		breathe = sin(_idle_phase)
		sway = sin(_idle_phase * 0.63)
	sprite.rotation = deg_to_rad(_step_wobble + sway * Balance.STRUCTURE_IDLE_SWAY)
	sprite.scale = _level_scale * (1.0 + breathe * Balance.STRUCTURE_IDLE_SCALE)


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
