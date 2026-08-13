class_name TownCore
extends Node2D

## The thing being defended (GDD §3). Holds the town's health, which lives in
## RunState so the town scope and the HUD read the same number.
##
## Losing this ends the run.

const GROUP: StringName = &"town"

@export var health: Health
@export var sprite: Sprite2D
@export var occluder: Occluder

## Health fractions at which the town swaps to the next damage stage. The art is
## city_base -> city_damage_1 -> _2 -> _3, so the town visibly falls apart as it
## is worn down rather than only reporting it on a bar.
const STAGES: Array[Dictionary] = [
	{"above": 0.75, "texture": "res://art/city/city_base.png"},
	{"above": 0.50, "texture": "res://art/city/city_damage_1.png"},
	{"above": 0.25, "texture": "res://art/city/city_damage_2.png"},
	{"above": -1.0, "texture": "res://art/city/city_damage_3.png"},
]

var _flash_left: float = 0.0
var _ended: bool = false
var _stage: int = -1

## Fires currently alight on the city, and the column of smoke above it. Both are
## rebuilt whenever the damage stage changes.
var _fires: Array[Flame] = []
var _smoke: CPUParticles2D = null
var _fire_rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	health.max_hp = RunState.town_max_hp
	health.current_hp = RunState.town_hp
	health.damaged.connect(_on_damaged)
	health.changed.connect(_on_changed)
	health.died.connect(_on_died)
	# Seeded, so the fires do not shuffle to new roofs every time the scope is
	# entered. A city that rearranges its own damage does not read as a place.
	_fire_rng.seed = 0x8EA57
	_build_smoke()
	ShadowKit.add_contact(self, sprite, 0.72)
	if sprite != null and sprite.texture != null:
		var half: Vector2 = sprite.texture.get_size() * 0.5
		ShadowKit.add_caster(self, half.x * 0.44, half.y * 0.18,
			Balance.SHADOW_LAYER_SCENERY, half.y * 0.42)
	_apply_stage(true)
	EventBus.town_health_changed.emit(health.current_hp, health.max_hp)
	EventBus.relic_socketed.connect(_on_relic_changed)
	EventBus.relic_unsocketed.connect(_on_relic_changed)


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	sprite.modulate = Balance.HIT_FLASH_COLOUR.lerp(Color.WHITE, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)


func radius() -> float:
	return Balance.TOWN_RADIUS


## Town-health relics are live run loadout choices. Preserve the damage already
## taken when a socket changes instead of silently healing or hurting the city.
func _apply_relic_health() -> void:
	var wanted: float = Balance.TOWN_MAX_HP + Modifiers.value(Modifiers.TOWN_MAX_HP)
	if is_equal_approx(wanted, health.max_hp):
		return
	var missing: float = health.max_hp - health.current_hp
	health.max_hp = wanted
	health.current_hp = clampf(wanted - missing, 1.0, wanted)
	health.changed.emit(health.current_hp, health.max_hp)


func _on_relic_changed(_id: String) -> void:
	_apply_relic_health()


## Swaps the sprite when health crosses a threshold, and only on a change.
##
## The Occluder measures its trigger area from the sprite's texture, so it is
## re-measured on every swap - otherwise a stage with different dimensions would
## keep fading using the previous stage's bounds. Y-sorting is unaffected: it
## reads the node position, not the texture.
func _apply_stage(force: bool = false) -> void:
	var ratio: float = health.ratio()
	var wanted: int = STAGES.size() - 1
	for i: int in STAGES.size():
		if ratio > float(STAGES[i]["above"]):
			wanted = i
			break
	if wanted == _stage and not force:
		return
	_stage = wanted

	var path: String = String(STAGES[wanted]["texture"])
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
		if occluder != null:
			occluder.remeasure()

	_rebuild_fires()

	if not force:
		# A stage change is a landmark: the town just visibly got worse.
		Vfx.ring(global_position, Balance.TOWN_RADIUS * 1.6,
			Color(0.9, 0.45, 0.25, 0.6), 0.6, 6.0)
		EventBus.camera_shake_requested.emit(14.0, 0.5)
		Sfx.play("sfx_town_damaged", 4.0)


# --- Burning ----------------------------------------------------------------

## Fires on the city, one set per damage stage.
##
## The stage swap alone reads on a still frame and not at all in motion — a
## player mid-wave does not study the roofline. Fire does read: it moves, it
## throws light on the ground around it, and it is the difference between damaged
## art and a place that is visibly losing.
##
## Rebuilt rather than added to, so healing the town puts the fires out.
func _rebuild_fires() -> void:
	for fire: Flame in _fires:
		if is_instance_valid(fire):
			fire.queue_free()
	_fires.clear()

	var wanted: int = 0
	if _stage >= 0 and _stage < Balance.CITY_FIRES_PER_STAGE.size():
		wanted = Balance.CITY_FIRES_PER_STAGE[_stage]

	_update_smoke(wanted)
	if wanted <= 0 or sprite == null or sprite.texture == null:
		return

	var extent: Vector2 = sprite.texture.get_size() * sprite.scale.abs() * Balance.CITY_FIRE_SPREAD
	# The same seed every time, so fire number three is always on the same roof.
	_fire_rng.seed = 0x8EA57 + _stage

	for i: int in wanted:
		var fire := Flame.new()
		fire.name = "Fire%d" % i
		# Spread across the silhouette, biased upward: the roofs burn, not the
		# ground the walls stand on.
		fire.position = Vector2(
			_fire_rng.randf_range(-extent.x, extent.x),
			_fire_rng.randf_range(-extent.y, extent.y * 0.35))
		add_child(fire)

		var size: float = _fire_rng.randf_range(
			Balance.CITY_FIRE_SIZE_MIN, Balance.CITY_FIRE_SIZE_MAX)
		# Only the larger fires carry a light. Seven lights inside one building
		# would flatten it into a glowing blob.
		var radius: float = size * 7.0 if size > Balance.CITY_FIRE_SIZE_MAX * 0.7 else 0.0
		fire.configure(size, radius, Balance.FLAME_MID, 0.8, false)

		# Fires further down the sprite are nearer the viewer, so they draw over
		# the ones behind them.
		fire.z_index = 1
		_fires.append(fire)


func _build_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.name = "Smoke"
	_smoke.texture = Flame.dot_texture()
	_smoke.emitting = false
	_smoke.lifetime = Balance.CITY_SMOKE_LIFETIME
	_smoke.lifetime_randomness = 0.45
	_smoke.local_coords = false
	_smoke.amount = Balance.CITY_SMOKE_AMOUNT

	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 70.0
	_smoke.direction = Vector2.UP
	_smoke.spread = 18.0
	_smoke.initial_velocity_min = Balance.CITY_SMOKE_SPEED * 0.5
	_smoke.initial_velocity_max = Balance.CITY_SMOKE_SPEED
	# Leaning, so the column drifts off the city rather than standing over it
	# like a chimney in still air.
	_smoke.gravity = Vector2(26.0, -34.0)
	_smoke.damping_min = 1.0
	_smoke.damping_max = 4.0
	_smoke.angular_velocity_min = -22.0
	_smoke.angular_velocity_max = 22.0
	_smoke.scale_amount_min = 1.6
	_smoke.scale_amount_max = 3.4

	var growth := Curve.new()
	growth.add_point(Vector2(0.0, 0.3))
	growth.add_point(Vector2(1.0, 1.0))
	_smoke.scale_amount_curve = growth

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	ramp.colors = PackedColorArray([
		Color(Balance.FLAME_SMOKE_COLOUR, 0.0),
		Color(Balance.FLAME_SMOKE_COLOUR, Balance.CITY_SMOKE_ALPHA),
		Color(Balance.FLAME_SMOKE_COLOUR, 0.0),
	])
	_smoke.color_ramp = ramp
	# Above the city, so the column reads as rising off it rather than as a stain
	# behind it.
	_smoke.z_index = 2
	add_child(_smoke)


func _update_smoke(fires: int) -> void:
	if _smoke == null:
		return
	_smoke.emitting = fires > 0
	if fires <= 0:
		return
	# Thickens with the count rather than with the stage index, so the smoke and
	# the fires can never disagree about how bad it is.
	var share: float = float(fires) / float(maxi(Balance.CITY_FIRES_PER_STAGE.max(), 1))
	_smoke.amount = maxi(int(round(float(Balance.CITY_SMOKE_AMOUNT) * share)), 1)
	_smoke.position.y = -60.0


func _on_damaged(amount: float, _from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	# Damage to the town slows the beast, which slows construction. That chain
	# is the whole reason failure compounds (GDD §7).
	RunState.beast_speed = maxf(
		RunState.beast_speed - amount * Balance.BEAST_SPEED_LOSS_PER_DAMAGE,
		Balance.BEAST_SPEED_FLOOR)
	EventBus.beast_speed_changed.emit(RunState.beast_speed)
	_apply_stage()
	EventBus.town_damaged.emit(amount, health.current_hp, health.max_hp)
	EventBus.camera_shake_requested.emit(6.0, 0.25)


func _on_changed(current: float, maximum: float) -> void:
	RunState.town_hp = current
	RunState.town_max_hp = maximum
	EventBus.town_health_changed.emit(current, maximum)


func _on_died(_from: Vector2) -> void:
	if _ended:
		return
	_ended = true
	GameDirector.end_run(false)
