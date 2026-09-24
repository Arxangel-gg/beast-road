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
## Set before entering the tree. Non-casting torches still illuminate, flicker,
## dim and relight; paired road lights do not both need to render the same
## occluders from nearly the same distance.
var casts_shadows: bool = true
var shadow_on_ultra_only: bool = false

## Whether this post carries a real light. False still burns, glows and smokes -
## it is simply lit by its neighbours rather than casting its own pool. See
## Balance.TORCH_LIGHT_EVERY for why not every post can afford one.
var carries_light: bool = true

const GROUP: StringName = &"torches"

var _lit: bool = true
var _strength: float = 1.0
var _relight: float = 0.0
var _pressure: float = 0.0
var _pressure_sample_left: float = 0.0

var _flame: Flame
## The coals' alpha, drawn by `_draw`.
var _coals_alpha: float = 0.55
var _relight_glow: Sprite2D
## The warm pool on the ground under the post - see `_build_pool`.
var _pool: Sprite2D
var _pool_phase: float = 0.0
## Each post rolls its own weather, from the run's seed and its own place,
## so a row of torches in the rain goes out one at a time and the same
## torches go out on both machines.
var _rain_rng := RandomNumberGenerator.new()
var _rain_sample_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	# The origin is the contact point at the foot of the post. Keeping the whole
	# torch under this unsorted branch makes EntityRoot compare that point to the
	# hero's feet instead of sorting the elevated flame as a separate object.
	y_sort_enabled = false
	_rain_rng.seed = RunState.run_seed ^ hash(Vector2i(global_position.round()))
	_rain_sample_left = _rain_rng.randf() * Balance.TORCH_RAIN_SAMPLE
	_build()
	_apply_state(true)


func _build() -> void:
	queue_redraw()

	# A pool at the foot of the post.
	#
	# The torches light the whole field and stood on nothing, which reads as
	# "the lighting is wrong" without anyone being able to say why: every other
	# object on the ground has a contact shadow, so the one thing casting the
	# light looked pasted on top of the floor.
	#
	# Sized rather than measured, because the ironwork is `Polygon2D` and has no
	# texture to measure - see `ShadowKit.add_contact_sized`. The origin is
	# already the contact point at the foot of the post, so the offset is zero.
	ShadowKit.add_contact_sized(self, Balance.TORCH_SHADOW_WIDTH)
	_build_pool()
	EventBus.act_started.connect(_retint_pool)

	_flame = Flame.new()
	_flame.name = "Fire"
	_flame.position.y = -Balance.TORCH_HEIGHT
	add_child(_flame)
	# A radius of zero means "no PointLight2D", which is how an unlit post still
	# gets its flame and glow without adding to the light budget.
	_flame.configure(Balance.TORCH_FLAME_SIZE,
		Balance.TORCH_LIGHT_RADIUS if carries_light else 0.0,
		Balance.TORCH_LIGHT_COLOUR, Balance.TORCH_LIGHT_ENERGY,
		casts_shadows and carries_light, shadow_on_ultra_only)

	# The wisp that grows while the hero holds position to relight it lives
	# only while one is held (`_show_rekindle`): a hundred zero-sized sprites
	# waiting for a relight were a hundred items to cull every frame.


## The pool of light on the ground, on every torch, at no cost in lights.
##
## **Owner, 2026-09-14: torches can be on and it is still dark around them, as
## if there were no lighting.** True, and measured: `night_check` puts a
## torch's real light at a lift of 0.018 in luminance - present, provable, and
## invisible. It is that faint for two good reasons that add up to a bad one.
## Every `PointLight2D` re-draws everything under it, so only every second post
## carries a light at all (`TORCH_LIGHT_EVERY`), and the energy of the ones that
## do was brought down so overlapping pools would not sum into bright knots.
## The road is lit *evenly*, and evenly is what nobody can see.
##
## So the pool the eye wants is faked, which the owner asked for by name and
## which is the right answer regardless: an additive falloff sprite squashed
## onto the ground, on **every** post whether or not it carries a light, costing
## one quad each. It follows the flame's strength, the day's darkness and a
## slow flicker, so it vanishes by noon and gutters with the torch. The real
## lights still do what only lights can - shade the sprites and cast the
## shadows - and `night_check` still measures them, because this is in both of
## its passes and cancels out of the lift.
func _build_pool() -> void:
	_pool = Sprite2D.new()
	_pool.name = "Pool"
	_pool.texture = LightKit.falloff_texture()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pool.material = additive
	var across: float = maxf(float(_pool.texture.get_width()), 1.0)
	var span: float = Balance.TORCH_POOL_RADIUS * 2.0 / across
	# Flattened into an ellipse: the camera looks down and along, so a circle of
	# light on the ground is a circle seen at an angle.
	_pool.scale = Vector2(span, span * Balance.TORCH_POOL_SQUASH)
	_pool.modulate = Color(_pool_colour(), 0.0)
	# Under the post and the shadow, over the ground the torch stands on.
	_pool.z_index = -2
	add_child(_pool)
	_pool_phase = randf() * TAU
	DayNight.phase_changed.connect(func(_p: float, _t: Color, _d: float) -> void:
		_refresh_pool())
	_refresh_pool()


## The pool's colour: the flame's, as it lands on the ground under this post
## (2026-09-23, `GroundGlow.bounced`) - a redder pool on red earth than on snow.
## Asked again when the region changes, because the post stays and the ground
## does not.
func _pool_colour() -> Color:
	var node: Node = get_parent()
	while node != null:
		if node is Battlefield:
			return GroundGlow.bounced(Balance.TORCH_LIGHT_COLOUR,
				(node as Battlefield).ground_colour(global_position))
		node = node.get_parent()
	return Balance.TORCH_LIGHT_COLOUR


func _retint_pool(_act: int, _terrain_id: String) -> void:
	if _pool != null:
		_pool.modulate = Color(_pool_colour(), _pool.modulate.a)


## How bright the pool is right now: the flame's strength, by the night.
func _refresh_pool(wobble: float = 1.0) -> void:
	if _pool == null:
		return
	var night: float = lerpf(Balance.TORCH_POOL_DAY, 1.0, DayNight.darkness)
	var strength: float = _strength if _lit else 0.0
	# Rain on the ground scatters the pool. Dimmer, not smaller.
	var wet: float = 1.0 - Balance.TORCH_RAIN_POOL_DIM * RunState.rain_intensity
	_pool.modulate.a = Balance.TORCH_POOL_ALPHA * strength * night * wobble * wet
	_pool.visible = _pool.modulate.a > 0.004


## The post and brazier. Drawn rather than art because at this size a PNG would
## be nine pixels of detail and one more file to keep in the manifest.
##
## **One canvas item, not five** (2026-09-24). The post, the collar, the bowl,
## the rim and the coals were four `Polygon2D`s and a sprite under every one
## of a hundred torches - five hundred items for the renderer to cull and draw
## on a field that had five thousand. They are five commands in one `_draw`
## now, redrawn only when the coals change, which is on a strength change and
## a relight and nowhere else. The order is what it was: a parent draws
## before its children, and the ironwork was the first child.
func _draw() -> void:
	var height: float = Balance.TORCH_HEIGHT
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, 0.0), Vector2(3.0, 0.0),
		Vector2(2.0, -height), Vector2(-2.0, -height),
	]), Color(0.13, 0.11, 0.10))
	# A collar partway up, so the post has a silhouette instead of being a stick.
	var collar_y: float = -height * 0.42
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, collar_y), Vector2(5.0, collar_y),
		Vector2(4.0, collar_y - 4.0), Vector2(-4.0, collar_y - 4.0),
	]), Color(0.20, 0.17, 0.14))
	# The bowl the fire sits in. Its rim is drawn separately and slightly lighter
	# so the fire looks contained by it rather than drawn on top of it.
	var bowl_y: float = -height + 4.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, bowl_y), Vector2(9.0, bowl_y),
		Vector2(5.5, bowl_y - 8.0), Vector2(-5.5, bowl_y - 8.0),
	]), Color(0.19, 0.15, 0.13))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.5, bowl_y), Vector2(9.5, bowl_y),
		Vector2(9.5, bowl_y - 2.0), Vector2(-9.5, bowl_y - 2.0),
	]), Color(0.34, 0.27, 0.20))
	# Coals: visible whether or not the torch is lit, so a dead torch reads as a
	# torch that has gone out and not as an empty pole.
	var coals: Texture2D = Flame.dot_texture()
	var size: Vector2 = coals.get_size() * Vector2(0.42, 0.20)
	draw_texture_rect(coals, Rect2(Vector2(-size.x * 0.5, -height + 1.0 - size.y * 0.5), size),
		false, Color(0.55, 0.18, 0.06, _coals_alpha))


## The coals' alpha: brighter while a relight is held, dimmer as the flame
## gutters. Redraws the ironwork only when it actually moves.
func _set_coals(alpha: float) -> void:
	if is_equal_approx(alpha, _coals_alpha):
		return
	_coals_alpha = alpha
	queue_redraw()


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
	# A flood at its height puts every post out. No roll: the brazier is under
	# water.
	if RunState.flood >= Balance.FLOOD_DROWN_LEVEL:
		extinguish()
		return
	# The rain. A droplet in the bowl now and then, by how hard it is falling;
	# the recovery below is what a light rain never gets ahead of.
	var rain: float = RunState.rain_intensity
	if rain > 0.0:
		_rain_sample_left -= delta
		if _rain_sample_left <= 0.0:
			_rain_sample_left = Balance.TORCH_RAIN_SAMPLE
			if _rain_rng.randf() < rain * Balance.TORCH_RAIN_HIT_CHANCE:
				_strength -= Balance.TORCH_RAIN_HIT * (0.6 + 0.8 * rain)
	if _pressure > 0.0:
		_strength -= Balance.TORCH_DIM_PER_ENEMY_SECOND * _pressure * delta
		if hero_near:
			_strength = maxf(_strength, Balance.TORCH_HERO_MIN_STRENGTH)
	else:
		# A brazier does not dry out while it is being rained on. Recovery is
		# what a drizzle never gets ahead of and a downpour does, and the
		# difference between the two is this one line.
		_strength += Balance.TORCH_RECOVERY_PER_SECOND * delta * (1.0 - rain)
		if hero_near:
			_strength += Balance.TORCH_HERO_RECOVERY_PER_SECOND * delta
	_strength = clampf(_strength, 0.0, 1.0)
	if not is_equal_approx(before, _strength):
		_apply_strength()
	# The pool breathes with the flame. Two sines of unrelated periods, like
	# the light's own flicker, so a row of posts never pulses together.
	_pool_phase += delta
	_refresh_pool(1.0 + Balance.TORCH_POOL_FLICKER
		* (sin(_pool_phase * 6.1) * 0.6 + sin(_pool_phase * 11.7) * 0.4))
	if _strength <= 0.001 and not hero_near:
		extinguish()


## Total hostile mass presently level with this brazier. Longitudinal distance
## is deliberate: the torch stands beside the road, so a straight-line radius
## would never reach a walker on the lane centre.
func _enemy_pressure() -> float:
	var direction: Vector2 = Battlefield.lane_vector(lane)
	var total: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.lane != lane or enemy.is_dying():
			continue
		# A camp body never walks the road. It patrols its own clearing off the
		# corridor, and with the camps moved closer to the road (2026-09-14) it
		# was putting out torches from the trees - the same "torches going out
		# with nothing on their stretch of road" the lateral check was added for.
		if enemy.is_camp_mob():
			continue
		var offset: Vector2 = enemy.global_position - global_position
		if absf(offset.dot(direction)) > Balance.TORCH_SNUFF_RANGE:
			continue
		# **Level with it is not the same as near it.**
		#
		# Only the longitudinal distance was measured, on the reasoning that a
		# torch stands beside the road and a straight-line radius would never
		# reach a walker on the lane centre. True for a straight road; the roads
		# bend, and a bent road doubles back - so an enemy on a different leg
		# entirely projects onto the same point along the lane vector and snuffs
		# a torch it is nowhere near. Reported from play as torches going out
		# with nothing on their stretch of road.
		if absf(offset.dot(direction.orthogonal())) > Balance.TORCH_SNUFF_LATERAL:
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
	# **Any** hero, not the player's. A torch does not care whose boots
	# these are, and asking for `GROUP` meant only one of four could ever
	# relight one - the rest walked past in the dark.
	return Hero.nearest_on_field(get_tree(), global_position,
		Balance.TORCH_RELIGHT_RANGE) != null


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
	Sfx.play_at("sfx_tower_build", at, -6.0)


## Held near a dead torch, the hero rekindles it. Deliberately not instant: it
## has to cost a moment of standing still in a lane, or it is not a decision.
func _tick_relight(delta: float) -> void:
	# Nothing lights under water. The flood has to fall first.
	if RunState.flood >= Balance.FLOOD_DROWN_LEVEL:
		_relight = 0.0
		_show_rekindle(0.0)
		return
	# Whoever is standing here. The relight timer used to run only for the
	# player's own hero, so a guest could hold a dead torch all night.
	if Hero.nearest_on_field(get_tree(), global_position,
			Balance.TORCH_RELIGHT_RANGE) == null:
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
	if progress <= 0.0:
		if _relight_glow != null and is_instance_valid(_relight_glow):
			_relight_glow.queue_free()
		_relight_glow = null
		_set_coals(0.55)
		return
	if _relight_glow == null or not is_instance_valid(_relight_glow):
		# Reusing the flame for this would mean a half-lit torch already
		# counted as lit.
		_relight_glow = Sprite2D.new()
		_relight_glow.name = "Rekindle"
		_relight_glow.texture = LightKit.falloff_texture()
		_relight_glow.position.y = -Balance.TORCH_HEIGHT
		_relight_glow.modulate = Color(Balance.TORCH_LIGHT_COLOUR, 0.0)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_relight_glow.material = additive
		add_child(_relight_glow)
	var span: float = Balance.TORCH_FLAME_SIZE * 2.4 / float(LightKit.falloff_texture().width)
	_relight_glow.scale = Vector2.ONE * span * progress
	_relight_glow.modulate.a = progress * 0.7
	_set_coals(0.55 + progress * 0.45)


func _apply_state(quiet: bool = false) -> void:
	if _flame != null:
		_flame.set_lit(_lit)
		_flame.set_intensity(_strength)
	_set_coals(0.55)
	_refresh_pool()
	_show_rekindle(0.0)
	if not quiet:
		state_changed.emit(_lit)
		EventBus.torch_state_changed.emit(lane, _lit)


func _apply_strength() -> void:
	if _flame != null:
		_flame.set_intensity(_strength)
	_set_coals(lerpf(0.55, 0.12, _strength))
	_refresh_pool()
