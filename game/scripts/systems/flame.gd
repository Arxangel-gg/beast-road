class_name Flame
extends Node2D

## A procedural fire that actually dances: silhouette, glow, embers and smoke.
##
## Written once and used by both the lane torches and the burning city, because
## fire was going to be needed twice and the second copy is always the one that
## drifts out of step.
##
## The old torch flame was a five-point teardrop whose whole body leaned on a
## sine. That reads as a flag on a pole, not as fire, and no amount of tuning
## fixes it — the problem is the shape, not the numbers. Four things fix it:
##
## 1. **The displacement grows with height.** Every horizontal slice is offset
##    sideways by an amount proportional to how far up the flame it is, so the
##    base stays pinned in the brazier while the tip whips. A rigid lean has one
##    degree of freedom; this has as many as it has slices.
##
## 2. **Two waves travelling at different rates.** One slow and wide, one fast
##    and tight, so the silhouette never repeats visibly and tongues appear to
##    travel *up* the flame rather than the whole thing swinging.
##
## 3. **Three nested layers, drawn additively.** A dark red body, an orange
##    middle and a small near-white core, each on its own phase. Fire is brighter
##    in the middle because it is hotter there, and additive blending is what
##    makes the overlap bloom instead of merely stacking.
##
## 4. **The height breathes.** A flame of constant height is a lamp.
##
## The glow behind it is a radial gradient sprite, not a polygon. The polygon it
## replaces had fourteen straight sides and was plainly visible as a disc.

## Slices are drawn as separate quads rather than as one outline. A flame
## silhouette is not convex — it wanders across its own axis — and the polygon
## draw calls are only correct for convex shapes. Abutting trapezoids give the
## identical result and are convex by construction.
const LAYERS: Array[Dictionary] = [
	{"width": 1.00, "height": 1.00, "speed": 1.00, "lick": 1.00, "alpha": 0.85},
	{"width": 0.62, "height": 0.74, "speed": 1.35, "lick": 1.25, "alpha": 0.90},
	{"width": 0.30, "height": 0.44, "speed": 1.80, "lick": 1.55, "alpha": 0.95},
]

## Height of the flame in pixels. Everything else scales off it.
var size: float = 16.0

## 0..1. Scales height, glow and particle output together, so one number turns a
## fire up. The city uses it to make a fresh blaze settle into a steady burn.
var intensity: float = 1.0

var _time: float = 0.0
var _seed: float = 0.0
var _lit: bool = true

var _glow: Sprite2D
var _embers: CPUParticles2D
var _smoke: CPUParticles2D
var _light: PointLight2D

## A small soft dot, shared by every particle in the game. Cached because a
## burning city plus twenty-four torches is otherwise thirty gradient textures
## that are pixel-for-pixel identical.
static var _dot: GradientTexture2D = null


static func dot_texture() -> GradientTexture2D:
	if _dot != null:
		return _dot
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0),
	])
	_dot = GradientTexture2D.new()
	_dot.gradient = gradient
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	_dot.width = 32
	_dot.height = 32
	return _dot


## `light_radius` of zero means no light at all — the city's smaller fires do not
## each need one, and twenty of them would wash the whole town out.
func configure(flame_size: float, light_radius: float = 0.0,
		light_colour: Color = Balance.FLAME_MID, light_energy: float = 1.0,
		casts_shadows: bool = false, shadow_on_ultra_only: bool = false) -> void:
	size = flame_size
	_seed = randf() * 100.0

	# Additive, so the flame reads as emitted light rather than as paint. The
	# material goes on this node because _draw output obeys it.
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

	_build_smoke()
	_build_glow()
	_build_embers()

	if light_radius > 0.0:
		_light = LightKit.add_light(self, light_colour, light_radius,
			light_energy, Balance.TORCH_FLICKER)
		if casts_shadows:
			LightKit.enable_shadows(_light,
				Balance.SHADOW_LAYER_SCENERY | Balance.SHADOW_LAYER_UNITS,
				shadow_on_ultra_only)


# --- Silhouette -------------------------------------------------------------

func _process(delta: float) -> void:
	if not _lit:
		return
	_time += delta * Balance.FLAME_DANCE_SPEED
	if _glow != null:
		# The glow breathes with the flame but lags it slightly. Perfectly in
		# phase, the two read as one object being scaled.
		var pulse: float = 1.0 + sin(_time * 1.9 - 0.6) * 0.13
		_glow.scale = Vector2.ONE * _glow_base_scale() * pulse * intensity
		_glow.modulate.a = Balance.FLAME_GLOW_ALPHA * intensity * (0.86 + 0.14 * pulse)
	queue_redraw()


func _draw() -> void:
	if not _lit or intensity <= 0.01:
		return

	var colours: Array[Color] = [Balance.FLAME_BODY, Balance.FLAME_MID, Balance.FLAME_CORE]
	for index: int in LAYERS.size():
		var layer: Dictionary = LAYERS[index]
		var colour: Color = colours[index]
		colour.a = float(layer["alpha"])
		_draw_layer(layer, colour, float(index) * 2.7)


func _draw_layer(layer: Dictionary, colour: Color, phase: float) -> void:
	var speed: float = float(layer["speed"])
	var lick: float = float(layer["lick"])

	# The whole flame breathes. Offsetting by the layer phase means the core
	# surges a beat before the body does, which reads as the fire drawing breath.
	var breath: float = 1.0 + sin(_time * 1.7 + phase + _seed) * Balance.FLAME_BREATH
	var height: float = size * float(layer["height"]) * breath * intensity
	var base_width: float = size * float(layer["width"]) * 0.52

	var segments: int = maxi(Balance.FLAME_SEGMENTS, 3)
	var previous_x: float = _centre_at(0.0, speed, lick, phase, height)
	var previous_half: float = _half_width_at(0.0, base_width, speed, phase)

	for i: int in segments:
		var u: float = float(i + 1) / float(segments)
		var x: float = _centre_at(u, speed, lick, phase, height)
		var half: float = _half_width_at(u, base_width, speed, phase)
		var y0: float = -height * (float(i) / float(segments))
		var y1: float = -height * u

		draw_colored_polygon(PackedVector2Array([
			Vector2(previous_x - previous_half, y0),
			Vector2(previous_x + previous_half, y0),
			Vector2(x + half, y1),
			Vector2(x - half, y1),
		]), colour)

		previous_x = x
		previous_half = half


## Sideways displacement of the slice `u` of the way up the flame.
##
## The `u * u` is the important part: at the base it is zero, so the flame is
## anchored where it is burning, and it accelerates toward the tip. Two waves at
## unrelated rates make the tongues appear to travel upward.
func _centre_at(u: float, speed: float, lick: float, phase: float, height: float) -> float:
	var wave: float = sin(_time * speed * 1.6 + u * 5.2 + phase + _seed) * 0.62 \
		+ sin(_time * speed * 2.9 - u * 9.1 + phase * 1.7) * 0.38
	return wave * u * u * height * Balance.FLAME_LICK * lick


## Widest just above the base, tapering to nothing at the tip, with a wobble so
## the edges are not two clean curves.
func _half_width_at(u: float, base_width: float, speed: float, phase: float) -> float:
	var taper: float = pow(maxf(1.0 - u, 0.0), 0.62) * (0.55 + 0.75 * u * (1.0 - u))
	var wobble: float = 1.0 + sin(_time * speed * 2.2 + u * 7.3 + phase) * 0.16
	return maxf(base_width * taper * wobble, 0.0)


# --- Attachments ------------------------------------------------------------

func _glow_base_scale() -> float:
	return size * Balance.FLAME_GLOW_SCALE / float(LightKit.falloff_texture().width)


func _build_glow() -> void:
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = LightKit.falloff_texture()
	_glow.modulate = Color(Balance.FLAME_MID, Balance.FLAME_GLOW_ALPHA)
	_glow.scale = Vector2.ONE * _glow_base_scale()
	_glow.position.y = -size * 0.55
	# Behind the flame body, in front of the smoke.
	_glow.z_index = -1
	add_child(_glow)


func _build_embers() -> void:
	_embers = CPUParticles2D.new()
	_embers.name = "Embers"
	_embers.texture = dot_texture()
	_embers.amount = Graphics.scaled(
		int(round(float(Balance.FLAME_EMBER_AMOUNT) * intensity)), Graphics.particle_scale())
	_embers.lifetime = Balance.FLAME_EMBER_LIFETIME
	_embers.lifetime_randomness = 0.55
	_embers.local_coords = false

	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = size * 0.30
	_embers.position.y = -size * 0.3

	_embers.direction = Vector2.UP
	_embers.spread = Balance.FLAME_EMBER_SPREAD
	_embers.initial_velocity_min = Balance.FLAME_EMBER_SPEED * 0.5
	_embers.initial_velocity_max = Balance.FLAME_EMBER_SPEED
	# Negative gravity: hot air carries embers up, and they slow as they cool.
	_embers.gravity = Vector2(0.0, -Balance.FLAME_EMBER_RISE)
	_embers.damping_min = 8.0
	_embers.damping_max = 22.0

	_embers.scale_amount_min = size * 0.006
	_embers.scale_amount_max = size * 0.014
	_embers.scale_amount_curve = _fade_curve()

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([
		Balance.FLAME_CORE, Balance.FLAME_BODY, Color(Balance.FLAME_BODY, 0.0),
	])
	_embers.color_ramp = ramp

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_embers.material = additive
	add_child(_embers)


func _build_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.name = "Smoke"
	_smoke.texture = dot_texture()
	_smoke.amount = Graphics.scaled(
		int(round(float(Balance.FLAME_SMOKE_AMOUNT) * intensity)), Graphics.particle_scale())
	_smoke.lifetime = Balance.FLAME_SMOKE_LIFETIME
	_smoke.lifetime_randomness = 0.4
	_smoke.local_coords = false

	_smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = size * 0.25
	_smoke.position.y = -size * 0.8

	_smoke.direction = Vector2.UP
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = Balance.FLAME_SMOKE_SPEED * 0.6
	_smoke.initial_velocity_max = Balance.FLAME_SMOKE_SPEED
	# A steady sideways drift, so the column leans like there is weather.
	_smoke.gravity = Vector2(14.0, -18.0)
	_smoke.damping_min = 2.0
	_smoke.damping_max = 6.0

	_smoke.angular_velocity_min = -30.0
	_smoke.angular_velocity_max = 30.0

	_smoke.scale_amount_min = size * 0.030
	_smoke.scale_amount_max = size * 0.055
	# Smoke expands as it rises and cools; a puff that keeps its size reads as a
	# sprite moving rather than as a gas.
	_smoke.scale_amount_curve = _growth_curve()

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	ramp.colors = PackedColorArray([
		Color(Balance.FLAME_SMOKE_COLOUR, 0.0),
		Color(Balance.FLAME_SMOKE_COLOUR, Balance.FLAME_SMOKE_ALPHA),
		Color(Balance.FLAME_SMOKE_COLOUR, 0.0),
	])
	_smoke.color_ramp = ramp
	# Mixed, not added: smoke is the one part of a fire that darkens what is
	# behind it.
	_smoke.z_index = -2
	add_child(_smoke)


static func _fade_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


static func _growth_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


# --- State ------------------------------------------------------------------

## Re-reads the particle budget without rebuilding the emitters.
##
## Changing `amount` restarts a CPUParticles2D, which is a visible hiccup - but
## one hiccup when a player deliberately changes a setting is fine, and it is far
## better than the setting appearing to do nothing at all.
func refresh_quality() -> void:
	var scale: float = Graphics.particle_scale()
	if _embers != null:
		var ember_amount: int = maxi(Graphics.scaled(
			int(round(float(Balance.FLAME_EMBER_AMOUNT) * intensity)), scale), 1)
		if _embers.amount != ember_amount:
			_embers.amount = ember_amount
	if _smoke != null:
		var smoke_amount: int = maxi(Graphics.scaled(
			int(round(float(Balance.FLAME_SMOKE_AMOUNT) * intensity)), scale), 1)
		if _smoke.amount != smoke_amount:
			_smoke.amount = smoke_amount


func set_lit(lit: bool) -> void:
	if _lit == lit:
		return
	_lit = lit
	if _embers != null:
		_embers.emitting = lit
	if _smoke != null:
		# Smoke outlives the flame by one lifetime: a torch that has just gone
		# out should smoulder, not stop dead.
		_smoke.emitting = lit
	if _glow != null:
		_glow.visible = lit
	if _light != null:
		_light.visible = lit
	queue_redraw()


func is_lit() -> bool:
	return _lit


## Scales the whole fire without rebuilding it.
func set_intensity(value: float) -> void:
	intensity = clampf(value, 0.0, 1.0)
	if _light != null:
		# LightDriver owns energy for day/night and flicker. Alpha is the orthogonal
		# channel for flame strength, so neither system overwrites the other.
		var light_colour: Color = _light.color
		light_colour.a = intensity
		_light.color = light_colour
	if _glow != null:
		_glow.visible = _lit and intensity > 0.01
	if _embers != null:
		var ember_amount: int = maxi(Graphics.scaled(
			int(round(float(Balance.FLAME_EMBER_AMOUNT) * intensity)), Graphics.particle_scale()), 1)
		if _embers.amount != ember_amount:
			_embers.amount = ember_amount
		_embers.emitting = _lit and intensity > 0.035
	if _smoke != null:
		var smoke_amount: int = maxi(Graphics.scaled(
			int(round(float(Balance.FLAME_SMOKE_AMOUNT) * intensity)), Graphics.particle_scale()), 1)
		if _smoke.amount != smoke_amount:
			_smoke.amount = smoke_amount
		_smoke.emitting = _lit and intensity > 0.035
	queue_redraw()


func light() -> PointLight2D:
	return _light
