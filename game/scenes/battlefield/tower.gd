class_name Tower
extends Node2D

const ActorPolishScript = preload("res://scripts/systems/actor_polish.gd")

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
var _aura: TowerAura = null
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
## Which way this emplacement was taken at level five, and what the tenth
## level added on top. Read from `RunState` on every refresh rather than
## held, so a co-op guest and a reloaded save agree with the host.
var _path: int = TowerData.Path.NONE

## The live weather's multiplier for this tower's element.
var _weather_scale: float = 1.0
## Seconds of the storm's charge left on this tower - see `storm_charge`.
var _storm_left: float = 0.0
var _storm_pulse: float = 0.0
## How much of a drawn draught the heat has taken back, 0..1.
var _evaporated: float = 0.0
var _extra_chain_targets: int = 0
var _health: Health = null
var _health_bar: HealthBar = null
var _damage_flames: Array[Flame] = []
var _step_wobble: float = 0.0
var _impact_material: ShaderMaterial = null
var _impact_left: float = 0.0

## Idle animation state. The phase starts scattered so a row of towers breathes
## out of step - in unison it reads as a screen-wide pulse rather than as
## buildings settling.
var _idle_phase: float = 0.0
var _idle_frame_clock: float = 0.0
var _idle_frames: Array[Texture2D] = []
var _attack_frames: Array[Texture2D] = []
var _attack_left: float = 0.0
var _level_scale: Vector2 = Vector2.ONE

## How much of the firing kick is left: 1 at the shot, 0 at rest.
var _fire_kick: float = 0.0

## Which way the recoil pushes — away from what was shot at.
var _fire_recoil: Vector2 = Vector2.UP

## Where the sprite sits when nothing is shoving it.
var _sprite_home: Vector2 = Vector2.ZERO

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
	_impact_material = ActorPolishScript.attach(sprite)
	_idle_frames = GameData.load_idle_frames(path)
	_attack_frames = GameData.load_attack_frames(path)
	_draw_range_ring()
	refresh_modifiers()
	_light = LightKit.add_light(self, TowerData.element_colour(data.element),
		Balance.TOWER_LIGHT_RADIUS, Balance.TOWER_LIGHT_ENERGY, Balance.TOWER_LIGHT_FLICKER)

	# A tower is scenery as far as shadows go: it sits still and it is solid, so
	# every torch near it throws its shape across the road.
	# Everything visible is lifted back to the plot centre, so moving the node
	# down to its base changes the sorting and nothing else.
	sprite.position.y -= Balance.TOWER_SORT_LIFT
	# Captured after the sort lift, so the recoil returns the sprite to where the
	# tower actually stands rather than to the node's origin.
	_sprite_home = sprite.position
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
	# What its element does to the air (2026-09-12). A well is water enough.
	_aura = TowerAura.new()
	_aura.element = int(data.element)
	_aura.level = level
	_aura.position = sprite.position
	add_child(_aura)
	_apply_level_look()
	_build_health()
	_build_gauge()
	call_deferred("refresh_modifiers")
	EventBus.relic_socketed.connect(_on_relic_changed)
	EventBus.relic_unsocketed.connect(_on_relic_changed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.beast_step_landed.connect(_on_beast_step)
	# Stagger the first shot so a freshly built lane does not fire in lockstep.
	_cooldown = RunState.rng("combat").randf() * data.interval_at(level) * path_interval_scale()


## Recomputed whenever the lane's contents or the terrain change, rather than
## every frame — these only move when the player builds something.
func refresh_modifiers() -> void:
	_path = RunState.tower_path(anchor)
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
		# A taunting tower - the Bastion and its kin - is built to be hit, and
		# wears armour for it (owner brief, 2026-09-14).
		_health.flat_damage_reduction = _field.lane_armour(lane()) \
			+ (Balance.TAUNT_TOWER_ARMOUR if data.taunts else 0.0)


func _on_weather_changed(_id: String) -> void:
	refresh_modifiers()


func _on_relic_changed(_id: String) -> void:
	refresh_modifiers()


func _on_boss_defeated(_id: String, _act: int) -> void:
	refresh_modifiers()


func _process(delta: float) -> void:
	_tick_step_wobble(delta)
	_impact_left = maxf(_impact_left - delta, 0.0)
	ActorPolishScript.drive(_impact_material, _impact_left)
	if data == null or _field == null or not RunState.is_command_combat():
		return
	_command_overdrive_left = maxf(_command_overdrive_left - delta, 0.0)
	_command_rally_left = maxf(_command_rally_left - delta, 0.0)
	var rate: float = Balance.COMMAND_OVERDRIVE_RATE \
		if _command_overdrive_left > 0.0 else 1.0
	_cooldown -= delta * rate
	_tick_storm(delta)
	_tick_heat(delta)
	if _cooldown > 0.0:
		return

	if _health != null and _health.is_dead:
		return
	# A puppet tower does not choose. Its shots arrive from the host, and letting
	# it acquire locally would have the two screens firing at different enemies
	# on different cooldowns - the same drift the enemies themselves used to have.
	if puppet:
		return
	if data.is_well():
		_pour(delta)
		return
	var targets: Array[Enemy] = _acquire_targets()
	if targets.is_empty():
		return
	_cooldown = data.interval_at(level) * path_interval_scale()
	_fire(targets)


# --- Healing wells ------------------------------------------------------------
#
# Owner brief, 2026-09-10. A well fills over time and a hero who comes to it
# drinks; see `TowerData` for why it is two fields rather than a new role, and
# what the design says it costs.
#
# **The refill runs on the same `_cooldown` every other tower uses.** It is
# already decremented above at the Command Overdrive rate, already paused
# outside command combat, and already reset by the same upgrade path - so a well
# inherits every rule about when a tower is allowed to act rather than inventing
# a parallel set that would drift from them.

var _draught_ready: bool = false
## The gauge over the basin, and whether this well is the one prompting.
var _gauge: WellGauge = null
var _prompting: bool = false


## The draught is drawn; a hero who comes and drinks takes it.
##
## **A drink is taken, not poured** (owner brief, 2026-09-12: "players should
## need to do something to interact with it to heal", and the well shows how
## full it is). The draught waits until somebody hurt walks up and presses
## Interact, so a player who arrives hurt gets the one that has been standing
## ready rather than one that timed out into an empty basin - and a player who
## is fine walks past a full well and leaves it full.
func _pour(_delta: float) -> void:
	if not _draught_ready:
		_draught_ready = true
		Vfx.ring(global_position, 54.0, Balance.WELL_COLOUR, 0.5, 3.0)
	var thirsty: Hero = _thirstiest_hero()
	if thirsty == null or not thirsty.is_local_player():
		_say("", "")
		return
	_say("Drink from the well", "DRINK")
	var source := thirsty.get("input") as HeroInput
	if source == null or not source.pressed(HeroInput.BUTTON_INTERACT):
		return
	# Scaled down at level one and earned back with the levels the player
	# pays for (2026-09-13). The free early answer is what has gone.
	var healed: float = data.well_heal * Balance.WELL_EARLY_HEAL_SCALE * (1.0
		+ float(maxi(level - 1, 0)) * Balance.WELL_HEAL_PER_LEVEL)
	thirsty.drink_from_well(healed)
	Sfx.play("sfx_well_drink")
	_say("", "")
	_draught_ready = false
	# **The pour is the well's firing pose.** Every tower authors three, and the
	# art gate demands them from a well too - which looked at first like a rule
	# that did not fit, and is actually the right one: a well that healed you
	# without visibly doing anything is a tower that never animates. `kick` is
	# the one place that starts the sequence, so the well uses it and inherits
	# the timing, the recoil direction and the frame stepping unchanged.
	kick(thirsty.combat_origin())
	_cooldown = well_refill_seconds()
	Vfx.ring(global_position, data.range_at(level) * Balance.WELL_DRINK_RANGE_SHARE,
		Balance.WELL_COLOUR, 0.42, 4.0)
	Vfx.spark(global_position, Balance.WELL_COLOUR, 8,
		(thirsty.combat_origin() - global_position).normalized(), 190.0)


## The prompt, said once per change through the same road the ponds and the
## gates use.
func _say(text: String, button: String) -> void:
	var wanted: bool = not text.is_empty()
	if wanted == _prompting and not wanted:
		return
	_prompting = wanted
	EventBus.interact_prompt.emit(text, button)


## How full the well is, 0..1. For the gauge and the gate.
func well_fill() -> float:
	if _draught_ready:
		return 1.0
	var refill: float = maxf(well_refill_seconds(), 0.01)
	return clampf(1.0 - _cooldown / refill, 0.0, 1.0)


## The gauge over the basin: an arc that fills as the draught draws. Built
## once the tower knows it is a well.
func _build_gauge() -> void:
	if _gauge != null or data == null or not data.is_well():
		return
	_gauge = WellGauge.new()
	_gauge.name = "Gauge"
	_gauge.well = self
	add_child(_gauge)


## Seconds this well takes to draw its next draught, bounded below so a maxed
## one is still a well rather than a fountain.
func well_refill_seconds() -> float:
	var share: float = 1.0 - float(maxi(level - 1, 0)) * Balance.WELL_REFILL_PER_LEVEL
	# Slower in the heat and faster in the rain (2026-09-14): a well under a
	# heatwave draws less, and one under a downpour fills by the rate of it.
	return maxf(data.well_refill_seconds * Balance.WELL_REFILL_SCALE * maxf(share, 0.1),
		Balance.WELL_MIN_REFILL) * RunState.well_refill_scale() \
		/ (1.0 + clampf(RunState.rain_intensity, 0.0, 1.0) * Balance.RAIN_WELL_REFILL)


## A strike near a storm tower charges it (owner brief, 2026-09-14): harder
## and faster for a while, which is what an air tower is for. The longer of
## the two windows rather than their sum, so a burst of strikes is one long
## charge and not an unbounded one.
func storm_charge(seconds: float) -> void:
	if data == null or data.element != TowerData.Element.AIR:
		return
	var fresh: bool = _storm_left <= 0.0
	_storm_left = maxf(_storm_left, seconds)
	if fresh and sprite != null:
		Vfx.ring(global_position + Vector2(0.0, -24.0), 60.0, Color(Balance.LIGHTNING_COLOUR, 0.9), 0.5, 5.0)
		Vfx.spark(global_position + Vector2(0.0, -24.0), Balance.LIGHTNING_COLOUR, 14, Vector2.UP, 260.0)


func storm_charged() -> bool:
	return _storm_left > 0.0


func _storm_damage() -> float:
	return Balance.STORM_EMPOWER_DAMAGE if _storm_left > 0.0 else 1.0


## Water feeds the water towers: the flood and the rain both (owner brief,
## 2026-09-14). Read each shot rather than cached, because the flood moves.
func _water_damage() -> float:
	if data == null or data.element != TowerData.Element.WATER:
		return 1.0
	return 1.0 + clampf(RunState.flood, 0.0, 1.0) * Balance.FLOOD_WATER_EMPOWER \
		+ clampf(RunState.rain_intensity, 0.0, 1.0) * Balance.RAIN_WATER_EMPOWER


## Fire feeds the fire towers: a wildfire burning nearby heats them.
func _wildfire_damage() -> float:
	if data == null or data.element != TowerData.Element.FIRE or _field == null:
		return 1.0
	var fire: Wildfire = _field.wildfire()
	if fire == null:
		return 1.0
	return 1.0 + Balance.WILDFIRE_TOWER_BUFF * minf(fire.heat_at(origin(), Balance.WILDFIRE_TOWER_BUFF_RADIUS), 2.0)


## Charged ground feeds the towers of its element standing on it: a storm
## core the air towers, burning ground the fire towers, and so on. One
## number on a figure the tower already has, which is the bound.
func _zone_damage() -> float:
	if data == null or _field == null:
		return 1.0
	var ground: WrathZones = _field.zones()
	if ground == null or ground.count() == 0:
		return 1.0
	return 1.0 + Balance.ZONE_TOWER_BUFF * ground.boost_at(int(data.element), origin())


func _storm_interval() -> float:
	return Balance.STORM_EMPOWER_INTERVAL if _storm_left > 0.0 else 1.0


## The charge running down, crackling while it does.
func _tick_storm(delta: float) -> void:
	if _storm_left <= 0.0:
		return
	_storm_left = maxf(_storm_left - delta, 0.0)
	_storm_pulse -= delta
	if _storm_pulse <= 0.0:
		_storm_pulse = 0.45
		Vfx.spark(global_position + Vector2(0.0, -36.0), Balance.LIGHTNING_COLOUR, 4,
			Vector2.UP, 150.0)


## A well in the heat: the draught it has drawn goes back into the ground, and
## the one it is drawing comes slower. Nothing here reaches any other tower.
func _tick_heat(delta: float) -> void:
	if data == null or not data.is_well():
		return
	var evaporation: float = RunState.well_evaporation()
	if evaporation <= 0.0:
		_evaporated = maxf(_evaporated - delta * 0.2, 0.0)
		return
	var refill: float = maxf(well_refill_seconds(), 1.0)
	if _draught_ready:
		_evaporated += delta * evaporation / refill
		if _evaporated >= 1.0:
			_evaporated = 0.0
			_draught_ready = false
			_cooldown = refill * 0.35
			_say("", "")
	else:
		# The fill falls: the cooldown grows, but never past a full refill.
		_cooldown = minf(_cooldown + delta * evaporation, refill)


## The hero in reach who has actually lost something worth pouring for.
##
## The *most* hurt of them, so in co-op a full draught is not spent on whichever
## partner happened to walk past first while the other is nearly down.
func _thirstiest_hero() -> Hero:
	var reach: float = data.range_at(level) * Balance.WELL_DRINK_RANGE_SHARE
	var best: Hero = null
	var worst: float = 1.0 - Balance.WELL_MIN_MISSING_FRACTION
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not who.is_alive() or who.health == null:
			continue
		if who.combat_origin().distance_to(global_position) > reach:
			continue
		var ratio: float = who.health.ratio()
		if ratio < worst:
			worst = ratio
			best = who
	return best


## Whether the next draught is drawn. For the HUD and the gate.
func draught_ready() -> bool:
	return _draught_ready


func effective_damage() -> float:
	var command_bonus: float = Balance.COMMAND_OVERDRIVE_UTILITY \
		if _command_overdrive_left > 0.0 else 0.0
	# Read relic damage live. Regional relic adapters can cross their town-health
	# threshold between shots, so caching this value at build time would leave the
	# HUD and actual combat state disagreeing until some unrelated refresh.
	var relic_bonus: float = Modifiers.value(Modifiers.TOWER_DAMAGE)
	var total: float = 1.0 + _damage_bonus + relic_bonus + command_bonus
	return data.damage_at(level) * total * _weather_scale * _path_damage() * _storm_damage() \
		* _water_damage() * _wildfire_damage() * _zone_damage()


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


func _refresh_aura_level() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.level = level
		_aura.amount = maxi(int(float(_aura.amount) * 1.08), 1)


func upgrade_to(new_level: int) -> void:
	_refresh_aura_level()
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
	# **A camp is somewhere you go, not something that walks into your guns.**
	#
	# Camp bodies patrol their own ground and never take the road; a tower in
	# reach of one farmed it forever for spoils the player never earned, which
	# is what the owner reported on 2026-09-13. Ignoring them entirely would be
	# wrong the other way - a camp roused by a player and chasing them home
	# should meet the defence it is running into. So: a camp body is invisible
	# to a tower until something provokes it, and then it is fair game.
	candidates = candidates.filter(func(enemy: Enemy) -> bool:
		return not enemy.is_camp_mob() or enemy.is_provoked())
	if candidates.is_empty():
		return found

	var priority: int = RunState.target_priority_at(anchor)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return _target_score(a, priority) > _target_score(b, priority))

	var wanted: int = 1 + data.extra_targets_at(level) + _extra_chain_targets + path_extra_targets()
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
	kick(primary.global_position)
	# The storm towers running stir the air; enough of it and a funnel forms.
	if data.element == TowerData.Element.AIR:
		RunState.gale += Balance.GALE_PER_SHOT

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
	kick(at)
	if _is_aura():
		Vfx.ring(origin(), effective_range(),
			Color(TowerData.element_colour(data.element), 0.30), 0.45, 3.0)
		return
	var target: Enemy = _nearest_enemy(at)
	if target == null:
		# **Nothing within the match radius, so take the nearest body anywhere.**
		# The tight match is right when it succeeds: it identifies the enemy the
		# host actually meant. But a guest's puppets are a batch behind, so the
		# body that was under `at` when the host fired is often no longer within
		# `COOP_SHOT_MATCH_RANGE` of it by the time the packet lands - and this
		# returned empty-handed, drawing nothing.
		#
		# The two-process harness caught it as "the guest must see its towers'
		# projectiles fly", reproducibly, while the host saw its own shots fine.
		# A shot homing on a slightly wrong enemy is a cosmetic inaccuracy nobody
		# can detect at combat speed; a tower that visibly never fires is the
		# guest watching a different battle.
		target = _any_enemy()
	# Only when the field is genuinely empty - the enemy died between the host
	# firing and the packet arriving - is drawing nothing the right answer. A
	# homing shot with nothing to home on flies off the field.
	if target == null:
		return
	_launch(target)


## The nearest living enemy at any distance, or null when the field is clear.
func _any_enemy() -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		var distance: float = enemy.combat_origin().distance_to(origin())
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## The enemy the host meant, identified by where it said the shot was going.
func _nearest_enemy(at: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance: float = Balance.COOP_SHOT_MATCH_RANGE
	for enemy: Enemy in _field.enemies_near(at, Balance.COOP_SHOT_MATCH_RANGE):
		var distance: float = enemy.combat_origin().distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Shoves the tower back from what it just shot at.
##
## Public because a guest's tower is told to fire rather than deciding to, and
## both paths have to look the same - a tower that only recoiled on the machine
## that chose the shot would read as broken on the other one.
func kick(toward: Vector2) -> void:
	_fire_kick = 1.0
	_attack_left = Balance.TOWER_FIRE_ANIMATION_SECONDS
	if not _attack_frames.is_empty():
		sprite.texture = _attack_frames[0]
	var away: Vector2 = origin() - toward
	_fire_recoil = away.normalized() if away.length() > 0.001 else Vector2.UP


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
	# The level is passed *in*, because the shot builds its head, trail, glow and
	# light from it. It used to be assigned after `setup` had already run, so
	# every projectile in the game was built as a level 1 shot no matter what
	# fired it - the tier scaling existed, was correct, and did nothing.
	shot.setup(enemy, data, rolled_damage(),
		data.knockback_at(level) * Modifiers.multiplier(Modifiers.KNOCKBACK),
		level)
	# The spreading path widens every blast this tower throws (2026-09-13).
	shot.aoe_scale = path_aoe_scale()
	_field.add_projectile(shot, origin() + Vector2(0.0, -Balance.TOWER_SPRITE_LIFT))


func _hit(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	if effective_damage() > 0.0:
		var dealt: float = rolled_damage() * enemy.brand_multiplier()
		enemy.take_damage(dealt, origin(),
			data.knockback_at(level) * Modifiers.multiplier(Modifiers.KNOCKBACK))
		if data.element == TowerData.Element.FIRE:
			# The earth remembers fire. And a fire tower's shot may light the
			# plant beside whatever it hit.
			RunState.ember += dealt * Balance.EMBER_PER_DAMAGE
			if _field != null and _field.wildfire() != null:
				_field.wildfire().ignite_near(enemy.global_position, Balance.WILDFIRE_TOWER_REACH,
					Balance.WILDFIRE_TOWER_CHANCE)
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
	return data.range_at(level) * Modifiers.multiplier(Modifiers.TOWER_RANGE) 		* path_range_scale()


## What the chosen path does to this tower's reach, capstone included.
##
## Its own function rather than an expression inside `effective_range`, so the
## gate can read the path's reach the way it already reads its damage, its rate,
## its targets and its blast - the dead half of the Focus capstone survived
## precisely because reach was the one path number nothing could ask about.
func path_range_scale() -> float:
	if _path != TowerData.Path.FOCUS:
		return 1.0
	var further: float = 1.0 + Balance.TOWER_FOCUS_RANGE
	if level >= Balance.TOWER_CAPSTONE_LEVEL:
		further += Balance.TOWER_CAPSTONE_FOCUS_RANGE
	return further


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
	_leave_rubble()
	RunState.towers_lost += 1
	RunState.clear_tower(anchor)


## What a broken tower leaves: a scatter of stone that settles into the ground
## over a while, and the ground under it marked. On the field rather than on
## this node, which is about to go, and the spot is free to build on again the
## moment it does - the rubble is a picture, not a thing.
func _leave_rubble() -> void:
	if _field == null:
		return
	var rubble := Polygon2D.new()
	rubble.name = "Rubble"
	var points: PackedVector2Array = PackedVector2Array()
	var rng: RandomNumberGenerator = RunState.rng("wrath")
	for s: int in 9:
		var angle: float = TAU * float(s) / 9.0
		points.append(Vector2(cos(angle), sin(angle) * 0.55) * rng.randf_range(26.0, 44.0))
	rubble.polygon = points
	rubble.color = Color(0.3, 0.27, 0.24, 0.95)
	rubble.global_position = global_position
	rubble.z_index = Balance.SCORCH_Z + 1
	rubble.z_as_relative = false
	_field.add_child(rubble)
	var fade: Tween = rubble.create_tween()
	fade.tween_interval(Balance.DEBRIS_FADE_SECONDS * 0.5)
	fade.tween_property(rubble, "modulate:a", 0.0, Balance.DEBRIS_FADE_SECONDS * 0.5)
	fade.tween_callback(rubble.queue_free)
	Vfx.dust(global_position, Color(0.42, 0.38, 0.32), 14, 90.0)
	if _field.scorch() != null:
		_field.scorch().stamp(global_position, 70.0, 0.5)


func is_vulnerable() -> bool:
	return _health != null and not _health.is_dead


## A blow from the world - a funnel, a stone - through the same health every
## enemy's swing reaches, so the repair, the flames and the collapse all
## follow.
func hurt(amount: float, from: Vector2) -> void:
	if _health == null or _health.is_dead or amount <= 0.0:
		return
	_health.take_damage(amount, from)


func health_ratio() -> float:
	return _health.ratio() if _health != null and _health.max_hp > 0.0 else 1.0


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
	_impact_left = Balance.HIT_FLASH_TIME
	ActorPolishScript.strike(_impact_material, away)
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
	var pose: Texture2D = sprite.texture
	if not _idle_frames.is_empty():
		_idle_frame_clock += delta * Balance.STRUCTURE_IDLE_FRAME_RATE
		var frame: int = int(floor(_idle_frame_clock)) % _idle_frames.size()
		pose = _idle_frames[frame]
	else:
		_idle_phase += delta * Balance.STRUCTURE_IDLE_RATE * TAU
		breathe = sin(_idle_phase)
		sway = sin(_idle_phase * 0.63)
	# Authored discharge overrides the idle texture, not the shared transform.
	# The same kick starts it on host and guest; no gameplay timing is delayed.
	_attack_left = maxf(_attack_left - delta, 0.0)
	if _attack_left > 0.0 and not _attack_frames.is_empty():
		var progress: float = 1.0 - _attack_left / Balance.TOWER_FIRE_ANIMATION_SECONDS
		var attack_frame: int = mini(int(progress * _attack_frames.size()),
			_attack_frames.size() - 1)
		pose = _attack_frames[attack_frame]
	# Choose once; changing to idle and immediately back to discharge every
	# frame would needlessly invalidate the sprite's render state twice.
	if sprite.texture != pose:
		sprite.texture = pose
	# Squared, so the kick is sharp at the shot and settles rather than sliding
	# back at a constant rate. A linear recoil reads as the tower being dragged.
	_fire_kick = maxf(_fire_kick - delta / Balance.TOWER_FIRE_KICK_SECONDS, 0.0)
	var kicked: float = _fire_kick * _fire_kick
	sprite.rotation = deg_to_rad(_step_wobble + sway * Balance.STRUCTURE_IDLE_SWAY)
	# The kick rides *on top of* the idle rather than replacing it. Two systems
	# assigning the same property is how the earlier sway and wobble bug happened,
	# and a tower that stopped breathing while it recoiled would read as two
	# animations fighting over one sprite.
	sprite.scale = _level_scale * (1.0 + breathe * Balance.STRUCTURE_IDLE_SCALE
		+ kicked * Balance.TOWER_FIRE_KICK_SCALE)
	sprite.position = _sprite_home 		+ _fire_recoil * kicked * Balance.TOWER_FIRE_KICK_PUSH


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


# --- The path a tower was taken (2026-09-13) -------------------------------------------

## What the chosen path does to this tower's damage, capstone included.
func _path_damage() -> float:
	match _path:
		TowerData.Path.FOCUS:
			var focus: float = 1.0 + Balance.TOWER_FOCUS_DAMAGE
			if level >= Balance.TOWER_CAPSTONE_LEVEL:
				focus += Balance.TOWER_CAPSTONE_FOCUS_DAMAGE
			return focus
		TowerData.Path.SPREAD:
			return 1.0 + Balance.TOWER_SPREAD_DAMAGE
		_:
			return 1.0


## And to how often it fires. Spread is faster, focus is slower; a shorter
## interval is a faster tower, so the sign is inverted from the note.
func path_interval_scale() -> float:
	# Dawn Bell rides here rather than on each tower's own clock: a tower built
	# during the window should be hasted too, and one sold during it should not
	# leave a timer behind. See `RunState.haste_the_towers`.
	var haste: float = RunState.tower_haste() * _storm_interval()
	match _path:
		TowerData.Path.FOCUS:
			return (1.0 - Balance.TOWER_FOCUS_RATE) * haste
		TowerData.Path.SPREAD:
			return haste / (1.0 + Balance.TOWER_SPREAD_RATE)
		_:
			return haste


## How many extra bodies it reaches on the spread path, capstone included.
func path_extra_targets() -> int:
	if _path != TowerData.Path.SPREAD:
		return 0
	var extra: int = Balance.TOWER_SPREAD_TARGETS
	if level >= Balance.TOWER_CAPSTONE_LEVEL:
		extra += Balance.TOWER_CAPSTONE_SPREAD_TARGETS
	return extra


## And how much wider its blast is.
func path_aoe_scale() -> float:
	if _path != TowerData.Path.SPREAD:
		return 1.0
	var wider: float = 1.0 + Balance.TOWER_SPREAD_AOE
	if level >= Balance.TOWER_CAPSTONE_LEVEL:
		wider += Balance.TOWER_CAPSTONE_SPREAD_AOE
	return wider


## Which path this tower took. For the sheet and for the gate.
func path() -> int:
	return _path
