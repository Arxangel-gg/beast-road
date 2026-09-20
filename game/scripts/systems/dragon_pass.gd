class_name DragonPass
extends Node2D

## Host-authored dragon encounters: curved flight, optional landing, then departure.
## Route-derived presentation is deterministic; committed breath paths travel through
## EventBus so guests draw the host's warnings without applying damage themselves.
## Variant weights, colors and fire behavior belong to EnemyData resources.

const ART: String = "res://art/vfx/dragon_overhead.png"

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var field: Battlefield = null
var wildfire: Wildfire = null

## How many plants this pass set alight. For the gate.
var lit: int = 0
var rarity: int = 0
var authored_plan: Dictionary = {}

var _art: Texture2D = null
var _ground_art: Texture2D = null
var _kind: EnemyData = null
var _random := RandomNumberGenerator.new()
var _curve: Vector2 = Vector2.ZERO
var _landing: Vector2 = Vector2.ZERO
var _will_land: bool = false
var _land_left: float = -1.0
var _landed: bool = false
var _has_landed: bool = false
var _height: float = 0.0
var _heading: Vector2 = Vector2.RIGHT

var _left: float = 0.0
var _flying: bool = false
var _since_fire: float = 0.0
var _mirror: bool = false


func _ready() -> void:
	name = "DragonPass"
	z_as_relative = false
	z_index = Balance.DRAGON_Z
	_mirror = Coop.is_guest()
	_left = Balance.DRAGON_WARNING_SECONDS
	# The transmitted route defines the same presentation on every machine.
	_random.seed = hash(str(from) + str(to) + str(RunState.run_seed))
	var variants: Array[EnemyData] = []
	var weight: float = 0.0
	for value: Variant in ContentDB.enemies.values():
		var candidate := value as EnemyData
		if candidate != null and candidate.dragon_event_weight > 0.0:
			variants.append(candidate)
			weight += candidate.dragon_event_weight
	variants.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.id < b.id)
	var rare_roll: float = _random.randf()
	for index: int in Balance.DRAGON_RARITY_WEIGHTS.size():
		rare_roll -= Balance.DRAGON_RARITY_WEIGHTS[index]
		if rare_roll <= 0.0:
			rarity = index
			break
	var pick: float = _random.randf() * weight
	for candidate: EnemyData in variants:
		pick -= candidate.dragon_event_weight
		if pick <= 0.0:
			_kind = candidate
			break
	if _kind != null and ResourceLoader.exists(_kind.get_sprite_path()):
		_ground_art = load(_kind.get_sprite_path()) as Texture2D
	_curve = (to - from).normalized().orthogonal() * _random.randf_range(
		-Balance.DRAGON_CURVE_WIDTH, Balance.DRAGON_CURVE_WIDTH)
	_will_land = _random.randf() < Balance.DRAGON_LAND_CHANCE
	_landing = from.lerp(to, 0.5) + _curve
	if field != null:
		var clearance: float = _ground_art.get_size().length() * Balance.DRAGON_SCALE * 0.5 if _ground_art != null else Balance.DRAGON_FIRE_RADIUS
		_landing = field.deflect_from_city(_landing, clearance)
		_will_land = _will_land and absf(_landing.x) < BattleGrid.HALF_EXTENT and absf(_landing.y) < BattleGrid.HALF_EXTENT and field.water_depth_at(_landing) <= 0.0
	if not authored_plan.is_empty():
		_kind = ContentDB.enemy(String(authored_plan.get("variant", "")))
		rarity = clampi(int(authored_plan.get("rarity", 0)), 0, Balance.DRAGON_RARITY_WEIGHTS.size() - 1)
		_landing = authored_plan.get("landing", _landing) as Vector2
		_will_land = bool(authored_plan.get("land", false))
		_curve = authored_plan.get("curve", _curve) as Vector2
		if _kind != null and ResourceLoader.exists(_kind.get_sprite_path()):
			_ground_art = load(_kind.get_sprite_path()) as Texture2D
	_height = Balance.DRAGON_HEIGHT
	_heading = (to - from).normalized()
	if ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = from
	Sfx.play("sfx_thunder_far", -2.0)
	set_process(true)


func _process(delta: float) -> void:
	if _landed:
		_land_left -= delta
		_since_fire += delta
		if _since_fire >= Balance.DRAGON_FIRE_INTERVAL:
			_since_fire = 0.0
			_breathe()
		if _land_left <= 0.0:
			_landed = false
		queue_redraw()
		return
	_left -= delta
	if not _flying:
		if _left <= 0.0:
			_flying = true
			_left = Balance.DRAGON_PASS_SECONDS
			# Said once, as it comes over: the walk draws a shadow crossing the
			# sky above the carried town, because the one view whose subject is
			# the world should be the view that sees the biggest thing in it.
			EventBus.dragon_overhead.emit(Balance.DRAGON_PASS_SECONDS)
		queue_redraw()
		return
	var travelled: float = 1.0 - clampf(_left / maxf(Balance.DRAGON_PASS_SECONDS,
		0.01), 0.0, 1.0)
	var before: Vector2 = global_position
	# Two curved legs meet at a checked landing point, with a smooth descent.
	if travelled <= 0.5:
		global_position = from.lerp(_landing, travelled * 2.0) + _curve * sin(travelled * TAU) * 0.35
	else:
		global_position = _landing.lerp(to, (travelled - 0.5) * 2.0) - _curve * sin(travelled * TAU) * 0.35
	_heading = (global_position - before).normalized()
	if _will_land:
		_height = Balance.DRAGON_HEIGHT * clampf(absf(travelled - 0.5) * 6.0, 0.0, 1.0)
		if travelled >= 0.5 and not _has_landed:
			_has_landed = true
			_landed = true
			_land_left = Balance.DRAGON_LAND_SECONDS
			_left = Balance.DRAGON_PASS_SECONDS * 0.5
			global_position = _landing
			_height = 0.0
	_since_fire += delta
	if _since_fire >= Balance.DRAGON_FIRE_INTERVAL:
		_since_fire = 0.0
		_breathe()
	queue_redraw()
	if _left <= 0.0:
		queue_free()


## What it leaves under itself.
##
## **The host burns and the guest watches**, which is the wildfire's own rule:
## `ignite_near` announces each plant it lights and the guest lights the same
## one when told. A guest that burned on its own would be a second opinion about
## which forest is on fire.
func _breathe() -> void:
	if _mirror or _random.randf() > Balance.DRAGON_BREATH_CHANCE:
		return
	var target: Vector2 = global_position + _heading * Balance.DRAGON_BREATH_REACH
	if field != null:
		var nearest: float = Balance.DRAGON_BREATH_REACH
		for hero: Hero in field.heroes():
			if hero == null or not hero.is_alive() or field.inside_city(hero.global_position):
				continue
			var distance: float = global_position.distance_to(hero.global_position)
			if distance < nearest:
				nearest = distance
				target = hero.global_position
	var tint: Color = _kind.dragon_breath_tint if _kind != null else Color(1.0, 0.4, 0.12)
	EventBus.world_hazard.emit("ground", {
		"mode": "breath", "from": global_position, "to": target,
		"origin": global_position - Vector2(0.0, _height),
		"width": Balance.DRAGON_BREATH_WIDTH, "warning": Balance.DRAGON_BREATH_WARNING,
		"travel": 0.35, "share": Balance.DRAGON_BREATH_HERO_SHARE * (1.0 + float(rarity) * Balance.DRAGON_RARITY_DAMAGE_STEP),
		"tower_damage": 0.0, "tint": tint,
		"blame": _kind.display_name if _kind != null else "dragon"})
	if wildfire != null and (_kind == null or _kind.dragon_ignites):
		if wildfire.ignite_near(target, Balance.DRAGON_FIRE_RADIUS, Balance.DRAGON_FIRE_CHANCE, false):
			lit += 1
		if field != null and field.climate() != null:
			field.climate().add_heat(target, Balance.DRAGON_HEAT, Balance.DRAGON_FIRE_RADIUS * 1.4)


## The shadow first, then the thing casting it.
##
## Drawn rather than lit: a real light of this size on a field that already
## carries a hundred torches is a frame nobody can afford, and a shadow is what
## a player actually reads as something passing over.
func _draw() -> void:
	if _art == null:
		return
	var size: Vector2 = _art.get_size() * Balance.DRAGON_SCALE * (1.0 + float(rarity) * Balance.DRAGON_RARITY_SIZE_STEP)
	var turn: float = _heading.angle() + PI * 0.5
	if not _flying:
		# The warning: the shadow alone, growing in as it comes out of the sun.
		var coming: float = 1.0 - clampf(_left / maxf(
			Balance.DRAGON_WARNING_SECONDS, 0.01), 0.0, 1.0)
		_shadow(size, turn, coming * 0.55)
		return
	_shadow(size, turn, 0.55)
	if _landed and _ground_art != null:
		var ground_size: Vector2 = _ground_art.get_size() * Balance.DRAGON_SCALE
		draw_texture_rect(_ground_art, Rect2(Vector2(-ground_size.x * 0.5, -ground_size.y), ground_size), false)
		return
	draw_set_transform(Vector2(0.0, -_height), turn, Vector2.ONE)
	draw_texture_rect(_art, Rect2(-size * 0.5, size), false,
		_kind.dragon_breath_tint.lightened(0.65) if _kind != null else Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shadow(size: Vector2, turn: float, strength: float) -> void:
	draw_set_transform(Vector2.ZERO, turn, Vector2.ONE)
	draw_texture_rect(_art, Rect2(-size * 0.5, size), false,
		Color(0.0, 0.0, 0.0, clampf(strength, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Drive the whole pass by hand. For the gate, which has no minutes to spend.
func advance(seconds: float, steps: int = 40) -> void:
	var step: float = seconds / maxf(float(steps), 1.0)
	for _tick: int in steps:
		if not is_instance_valid(self) or is_queued_for_deletion():
			return
		_process(step)


func encounter_plan() -> Dictionary:
	return {"from": from, "to": to, "landing": _landing, "land": _will_land,
		"curve": _curve, "variant": _kind.id if _kind != null else "",
		"rarity": rarity}
