class_name DragonPass
extends Node2D

## Host-authored dragon encounters: curved flight, optional landing, then departure.
## Route-derived presentation is deterministic; committed breath paths travel through
## EventBus so guests draw the host's warnings without applying damage themselves.
## Variant weights, colors and fire behavior belong to EnemyData resources.

const ART: String = "res://art/vfx/dragon_overhead.png"
## Each variant's own overhead painting, with `_fly_NN` wing-beat frames
## beside it by the same convention every flyer uses. A variant without one
## flies as the shared painting tinted, which is what every dragon was until
## 2026-09-21 - so a missing file is a duller dragon, never a missing one.
const VARIANT_ART_FORMAT: String = "res://art/vfx/dragon_overhead_%s.png"

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

# Presentation only: nothing below reads any of these.
var _wing_frames: Array[Texture2D] = []
var _idle_frames: Array[Texture2D] = []
var _attack_frames: Array[Texture2D] = []
var _own_art: bool = false
var _clock: float = 0.0
var _attack_left: float = 0.0
var _touched_down: bool = false


## Every passing dragon, for anything that has to find one - the edge arrows.
const GROUP: StringName = &"dragon_pass"


## Whether it is standing on the field rather than crossing the sky.
func is_landed() -> bool:
	return _landed


func _ready() -> void:
	name = "DragonPass"
	add_to_group(GROUP)
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
	_load_ground_art()
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
		_load_ground_art()
	_height = Balance.DRAGON_HEIGHT
	_heading = (to - from).normalized()
	_load_wings()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = from
	Sfx.play("sfx_thunder_far", -2.0)
	set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	_attack_left = maxf(_attack_left - delta, 0.0)
	if _landed:
		_land_left -= delta
		_since_fire += delta
		if _since_fire >= Balance.DRAGON_FIRE_INTERVAL:
			_since_fire = 0.0
			_breathe()
		if _land_left <= 0.0:
			_landed = false
			_take_off()
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
			_touch_down()
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
	# Its own element or plain fire, and the fire wyrm's ultra now and then,
	# off the pass's own dice so both machines draw the same breath.
	var chosen: Dictionary = DragonBreath.choose(_kind, _random)
	var width: float = Balance.DRAGON_BREATH_WIDTH * float(chosen["width"])
	if bool(chosen["ultra"]):
		target = global_position + (target - global_position) * Balance.DRAGON_ULTRA_REACH
	_attack_left = Balance.DRAGON_BREATH_WARNING + 0.35
	EventBus.world_hazard.emit("ground", {
		"mode": "breath", "from": global_position, "to": target,
		"element": String(chosen["element"]), "ultra": bool(chosen["ultra"]),
		"origin": global_position - Vector2(0.0, _height),
		"width": width, "warning": Balance.DRAGON_BREATH_WARNING,
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
##
## **The shadow settles.** In the air it is the whole silhouette, soft and wide
## on the ground beneath; as the body comes down it draws in under the feet,
## and a landed dragon stands in a contact shadow rather than under a copy of
## itself. A shadow that stayed at flight size on the ground read as a second
## dragon lying beside the first, which is the report this answers.
func _draw() -> void:
	if _art == null:
		return
	var size: Vector2 = flying_size()
	var turn: float = _heading.angle() + PI * 0.5
	if not _flying:
		# The warning: the shadow alone, growing in as it comes out of the sun.
		var coming: float = 1.0 - clampf(_left / maxf(
			Balance.DRAGON_WARNING_SECONDS, 0.01), 0.0, 1.0)
		_shadow(size, turn, coming * 0.55)
		return
	_shadow(size * shadow_scale(), turn, 0.55)
	if _landed and _ground_art != null:
		var ground_size: Vector2 = landed_size()
		draw_texture_rect(landed_frame(), Rect2(Vector2(-ground_size.x * 0.5, -ground_size.y), ground_size), false)
		return
	draw_set_transform(Vector2(0.0, -_height), turn, Vector2.ONE)
	# A variant painted in its own colours is drawn as painted; the shared
	# painting is tinted toward the breath, which is all it ever had to say.
	var tint: Color = Color.WHITE if _own_art else (
		_kind.dragon_breath_tint.lightened(0.65) if _kind != null else Color.WHITE)
	draw_texture_rect(wing_frame(), Rect2(-size * 0.5, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shadow(size: Vector2, turn: float, strength: float) -> void:
	draw_set_transform(Vector2.ZERO, turn, Vector2.ONE)
	draw_texture_rect(_art, Rect2(-size * 0.5, size), false,
		Color(0.0, 0.0, 0.0, clampf(strength, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The rarity step is the same on the ground as in the air: a Cairnwyrm that
## was a fifth larger overhead used to land at the common size.
func rarity_scale() -> float:
	return 1.0 + float(rarity) * Balance.DRAGON_RARITY_SIZE_STEP


func flying_size() -> Vector2:
	return _art.get_size() * Balance.DRAGON_SCALE * rarity_scale() if _art != null else Vector2.ZERO


func landed_size() -> Vector2:
	return _ground_art.get_size() * Balance.DRAGON_SCALE * rarity_scale() if _ground_art != null else Vector2.ZERO


## How much of its flight silhouette the shadow keeps, by height: whole at
## `DRAGON_HEIGHT`, `DRAGON_SHADOW_REST` of it on the ground.
func shadow_scale() -> float:
	var aloft: float = clampf(_height / maxf(Balance.DRAGON_HEIGHT, 1.0), 0.0, 1.0)
	return lerpf(Balance.DRAGON_SHADOW_REST, 1.0, aloft)


## The wing beat: frame zero is the painting, the rest its `_flight` frames.
func wing_frame() -> Texture2D:
	if _wing_frames.size() <= 1:
		return _art
	var index: int = int(_clock * Balance.DRAGON_WING_HZ) % _wing_frames.size()
	return _wing_frames[index]


## On the ground it breathes on its idle frames and strikes on its attack
## frames - the same sheets a camp lord of the same kind fights on.
func landed_frame() -> Texture2D:
	if _attack_left > 0.0 and _attack_frames.size() > 1:
		var swing: float = 1.0 - _attack_left / (Balance.DRAGON_BREATH_WARNING + 0.35)
		var index: int = clampi(int(swing * float(_attack_frames.size())), 0, _attack_frames.size() - 1)
		return _attack_frames[index]
	if _idle_frames.size() <= 1:
		return _ground_art
	return _idle_frames[int(_clock * Balance.DRAGON_LANDED_IDLE_HZ) % _idle_frames.size()]


## Which frame the landed body is showing, for the gate: -1 in the air.
func landed_frame_index() -> int:
	if not _landed:
		return -1
	if _attack_left > 0.0 and _attack_frames.size() > 1:
		return 100 + _attack_frames.find(landed_frame())
	return _idle_frames.find(landed_frame())


func wing_frame_count() -> int:
	return _wing_frames.size()


func _load_ground_art() -> void:
	_ground_art = null
	_idle_frames.clear()
	_attack_frames.clear()
	if _kind == null or not ResourceLoader.exists(_kind.get_sprite_path()):
		return
	var base: String = _kind.get_sprite_path()
	_ground_art = load(base) as Texture2D
	# A loaded sequence already carries the painting as frame zero.
	_idle_frames = GameData.load_idle_frames(base)
	_attack_frames = GameData.load_attack_frames(base)


func _load_wings() -> void:
	_art = null
	_own_art = false
	_wing_frames.clear()
	if _kind != null:
		var own: String = VARIANT_ART_FORMAT % _kind.id.trim_prefix("dragon_")
		if ResourceLoader.exists(own):
			_art = load(own) as Texture2D
			_own_art = true
			_wing_frames = GameData.load_flight_frames(own)
	if _art == null and ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D


## The landing is felt: dust the colour of the ground it came down on, a
## knock weighted by distance like every other blow, and the animal's own
## voice. Presentation only, on every machine, from the same deterministic
## descent.
func _touch_down() -> void:
	_touched_down = true
	var tone: Color = Color(0.5, 0.45, 0.4)
	if field != null:
		tone = field.ground_colour(_landing)
	Vfx.dust(_landing, tone.lightened(0.15), 16, landed_size().x * 0.45)
	Vfx.ring(_landing, landed_size().x * 0.55, Color(tone.r, tone.g, tone.b, 0.5), 0.5, 5.0)
	EventBus.camera_impact.emit(_landing, Balance.DRAGON_LAND_IMPACT)
	Sfx.play_group_at("sfx_hit_stone", _landing, 2.0)
	Sfx.play_group_at("sfx_enemy_call_beast", _landing, 3.0)


func _take_off() -> void:
	var tone: Color = Color(0.5, 0.45, 0.4)
	if field != null:
		tone = field.ground_colour(_landing)
	Vfx.dust(global_position, tone.lightened(0.1), 10, landed_size().x * 0.5)


func has_touched_down() -> bool:
	return _touched_down


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
