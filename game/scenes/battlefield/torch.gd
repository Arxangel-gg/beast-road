class_name Torch
extends Node2D

## A torch on a lane, which the player wants kept lit.
##
## This is a mechanic wearing a lighting effect, not decoration. An enemy walking
## past snuffs a torch out; the hero standing near a dead one relights it. The
## darker a lane gets, the stronger and more frequent the things that come down
## it — so keeping the road lit is a real defensive choice competing for the same
## attention as everything else, and it matters most at night when the light is
## also what lets you see.
##
## The fire itself is `Flame`, shared with the burning city. Everything here is
## the ironwork it stands in and the rules about putting it out.
##
## The light casts real shadows. That is the point of a torch: not that it is
## bright, but that everything near it suddenly has a long streak behind it.

signal state_changed(lit: bool)

## Which lane this belongs to, so the wave director can ask how dark it is.
var lane: int = 0

const GROUP: StringName = &"torches"

var _lit: bool = true
var _strength: float = 1.0
var _relight: float = 0.0
var _pressure: float = 0.0
var _pressure_sample_left: float = 0.0

var _flame: Flame
var _embers_out: Sprite2D
var _relight_glow: Sprite2D


func _ready() -> void:
	add_to_group(GROUP)
	# The origin is the contact point at the foot of the post. Keeping the whole
	# torch under this unsorted branch makes EntityRoot compare that point to the
	# hero's feet instead of sorting the elevated flame as a separate object.
	y_sort_enabled = false
	_build()
	_apply_state(true)


func _build() -> void:
	_build_ironwork()

	_flame = Flame.new()
	_flame.name = "Fire"
	_flame.position.y = -Balance.TORCH_HEIGHT
	add_child(_flame)
	_flame.configure(Balance.TORCH_FLAME_SIZE, Balance.TORCH_LIGHT_RADIUS,
		Balance.TORCH_LIGHT_COLOUR, Balance.TORCH_LIGHT_ENERGY, true)

	# The wisp that grows while the hero holds position to relight it. Reusing
	# the flame for this would mean a half-lit torch already counted as lit.
	_relight_glow = Sprite2D.new()
	_relight_glow.name = "Rekindle"
	_relight_glow.texture = LightKit.falloff_texture()
	_relight_glow.position.y = -Balance.TORCH_HEIGHT
	_relight_glow.modulate = Color(Balance.TORCH_LIGHT_COLOUR, 0.0)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_relight_glow.material = additive
	_relight_glow.scale = Vector2.ZERO
	add_child(_relight_glow)


## The post and brazier. Drawn rather than art because at this size a PNG would
## be nine pixels of detail and one more file to keep in the manifest.
func _build_ironwork() -> void:
	var height: float = Balance.TORCH_HEIGHT

	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([
		Vector2(-3.0, 0.0), Vector2(3.0, 0.0),
		Vector2(2.0, -height), Vector2(-2.0, -height),
	])
	post.color = Color(0.13, 0.11, 0.10)
	add_child(post)

	# A collar partway up, so the post has a silhouette instead of being a stick.
	var collar := Polygon2D.new()
	collar.polygon = PackedVector2Array([
		Vector2(-5.0, 0.0), Vector2(5.0, 0.0), Vector2(4.0, -4.0), Vector2(-4.0, -4.0),
	])
	collar.color = Color(0.20, 0.17, 0.14)
	collar.position.y = -height * 0.42
	add_child(collar)

	# The bowl the fire sits in. Its rim is drawn separately and slightly lighter
	# so the fire looks contained by it rather than drawn on top of it.
	var bowl := Polygon2D.new()
	bowl.polygon = PackedVector2Array([
		Vector2(-9.0, 0.0), Vector2(9.0, 0.0),
		Vector2(5.5, -8.0), Vector2(-5.5, -8.0),
	])
	bowl.color = Color(0.19, 0.15, 0.13)
	bowl.position.y = -height + 4.0
	add_child(bowl)

	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-9.5, 0.0), Vector2(9.5, 0.0), Vector2(9.5, -2.0), Vector2(-9.5, -2.0),
	])
	rim.color = Color(0.34, 0.27, 0.20)
	rim.position.y = -height + 4.0
	add_child(rim)

	# Coals: visible whether or not the torch is lit, so a dead torch reads as a
	# torch that has gone out and not as an empty pole.
	_embers_out = Sprite2D.new()
	_embers_out.texture = Flame.dot_texture()
	_embers_out.modulate = Color(0.55, 0.18, 0.06, 0.55)
	_embers_out.scale = Vector2(0.42, 0.20)
	_embers_out.position.y = -height + 1.0
	add_child(_embers_out)


func _process(delta: float) -> void:
	_pressure_sample_left -= delta
	if _pressure_sample_left <= 0.0:
		_pressure_sample_left = Balance.TORCH_PRESSURE_SAMPLE
		_pressure = _enemy_pressure()
	if _lit:
		_tick_strength(delta)
		return
	_tick_relight(delta)


func is_lit() -> bool:
	return _lit


## Continuous contribution to lane darkness. A half flame is half a defence, so
## waves respond before the final ember disappears.
func light_strength() -> float:
	return _strength if _lit else 0.0


func _tick_strength(delta: float) -> void:
	var hero_near: bool = _hero_is_near()
	var before: float = _strength
	if _pressure > 0.0:
		_strength -= Balance.TORCH_DIM_PER_ENEMY_SECOND * _pressure * delta
		if hero_near:
			_strength = maxf(_strength, Balance.TORCH_HERO_MIN_STRENGTH)
	else:
		_strength += Balance.TORCH_RECOVERY_PER_SECOND * delta
		if hero_near:
			_strength += Balance.TORCH_HERO_RECOVERY_PER_SECOND * delta
	_strength = clampf(_strength, 0.0, 1.0)
	if not is_equal_approx(before, _strength):
		_apply_strength()
	if _strength <= 0.001 and not hero_near:
		extinguish()


## Total hostile mass presently level with this brazier. Longitudinal distance
## is deliberate: the torch stands beside the road, so a straight-line radius
## would never reach a walker on the lane centre.
func _enemy_pressure() -> float:
	var direction: Vector2 = Battlefield.lane_vector(lane)
	var torch_along: float = global_position.dot(direction)
	var total: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.lane != lane or enemy.is_dying():
			continue
		if absf(enemy.global_position.dot(direction) - torch_along) > Balance.TORCH_SNUFF_RANGE:
			continue
		var weight: float = 1.0
		if enemy.data != null:
			if enemy.data.category == EnemyData.Category.BOSS:
				weight = Balance.TORCH_BOSS_PRESSURE
			elif enemy.data.category == EnemyData.Category.ELITE:
				weight = Balance.TORCH_ELITE_PRESSURE
		total += weight
	return minf(total, Balance.TORCH_PRESSURE_MAX_WEIGHT)


func _hero_is_near() -> bool:
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	return hero != null and is_instance_valid(hero) \
		and global_position.distance_to(hero.global_position) <= Balance.TORCH_RELIGHT_RANGE


## Snuffed by something walking past.
func extinguish() -> void:
	if not _lit:
		return
	_lit = false
	_strength = 0.0
	_relight = 0.0
	_apply_state()
	var at: Vector2 = global_position + Vector2(0.0, -Balance.TORCH_HEIGHT)
	Vfx.spark(at, Color(0.45, 0.45, 0.48), 6, Vector2.UP, 100.0)


## Relit by the hero standing close enough for long enough.
func relight() -> void:
	if _lit:
		return
	_lit = true
	_strength = 1.0
	_relight = 0.0
	_apply_state()
	var at: Vector2 = global_position + Vector2(0.0, -Balance.TORCH_HEIGHT)
	Vfx.spark(at, Balance.TORCH_LIGHT_COLOUR, 12, Vector2.UP, 210.0)
	Vfx.ring(at, 70.0, Color(Balance.TORCH_LIGHT_COLOUR, 0.7), 0.35, 3.0)
	Vfx.flash_at(at, Balance.TORCH_LIGHT_COLOUR, 26.0)
	Sfx.play("sfx_tower_build", -6.0)


## Held near a dead torch, the hero rekindles it. Deliberately not instant: it
## has to cost a moment of standing still in a lane, or it is not a decision.
func _tick_relight(delta: float) -> void:
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	if hero == null or not is_instance_valid(hero):
		return
	if global_position.distance_to(hero.global_position) > Balance.TORCH_RELIGHT_RANGE:
		_relight = 0.0
		_show_rekindle(0.0)
		return

	_relight += delta
	_show_rekindle(clampf(_relight / Balance.TORCH_RELIGHT_TIME, 0.0, 1.0))
	if _relight >= Balance.TORCH_RELIGHT_TIME:
		relight()


## The coals brightening under the hero's attention: the readout that holding
## position here is doing something.
func _show_rekindle(progress: float) -> void:
	if _relight_glow == null:
		return
	var span: float = Balance.TORCH_FLAME_SIZE * 2.4 / float(LightKit.falloff_texture().width)
	_relight_glow.scale = Vector2.ONE * span * progress
	_relight_glow.modulate.a = progress * 0.7
	if _embers_out != null:
		_embers_out.modulate.a = 0.55 + progress * 0.45


func _apply_state(quiet: bool = false) -> void:
	if _flame != null:
		_flame.set_lit(_lit)
		_flame.set_intensity(_strength)
	if _embers_out != null:
		_embers_out.modulate.a = 0.55
	_show_rekindle(0.0)
	if not quiet:
		state_changed.emit(_lit)
		EventBus.torch_state_changed.emit(lane, _lit)


func _apply_strength() -> void:
	if _flame != null:
		_flame.set_intensity(_strength)
	if _embers_out != null:
		_embers_out.modulate.a = lerpf(0.55, 0.12, _strength)
