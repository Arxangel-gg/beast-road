class_name MenuStage
extends Control

## The living part of the main menu: the beast standing on a pixel-art vista,
## with the weather going on around it.
##
## ## Why this is pixel art now
##
## The menu shipped as a painterly 1920x1080 painting, and the argument for
## leaving it that way was that key art shares a frame with nothing, so it cannot
## clash with anything. The owner overruled it on 2026-08-21, and the call is
## theirs: a first screen is a promise about what the game looks like, and one
## made in a different medium than the game is a promise the game does not keep.
##
## ## What is on it, and why each thing earns its place
##
## The beast is **the game's own beast**, idling on the game's own frames — not a
## menu-only illustration of one. That is the whole point of putting it here: the
## thing on the front is the thing you get, down to the town on its back.
##
## Everything else is motion, because a still first screen reads as a screenshot
## of a game rather than a game waiting. Each layer moves at its own rate and on
## its own period, so nothing in the composition ever comes back into phase:
##
##   backdrop   a slow two-axis drift, over an overscan so no edge shows
##   mist       two bands crossing at different speeds and heights
##   beast      its idle cycle, plus a counter-drift so it parallaxes
##   embers     drifting up out of the valley, seeded across their own lifetime
##
## ## Cost
##
## `CPUParticles2D`, not GPU. This is the first screen and it runs on whatever
## the player has, including a browser tab through WebGL2 — and the counts here
## are small enough that the CPU path is free while the GPU path would be one
## more thing to be wrong on a driver somewhere.

## Where the beast stands, as a fraction of the stage. Right of centre and low,
## so it sits on the horizon and clear of the button column on the left.
const BEAST_AT := Vector2(0.645, 0.605)

## How tall the beast is drawn, as a fraction of the stage height.
##
## **It is the thing the menu is about.** At 0.44 it stood on the vista as one
## more element of a landscape; the city rides on its back and the whole game
## happens up there, so it should dominate the frame rather than decorate it.
## Its feet sit lower to match, which keeps the top of the silhouette clear of
## the title. [TUNE]
const BEAST_HEIGHT: float = 0.74

## Normalised positions of the painted gate's fire sources. Runtime light is
## deliberately separate from the backdrop so the architecture breathes rather
## than reading as a still wallpaper. No full-screen pass and only five sprites.
const GATE_LIGHTS: Array[Vector2] = [
	Vector2(0.465, 0.585), Vector2(0.522, 0.605), Vector2(0.603, 0.603),
	Vector2(0.700, 0.585), Vector2(0.796, 0.570),
]

var _backdrop: TextureRect = null
var _beast: Sprite2D = null
var _shadow: Sprite2D = null
var _baseline: int = 0
var _mist: Array[ColorRect] = []
var _frames: Array[Texture2D] = []
var _time: float = 0.0
var _home := Vector2.ZERO
var _laid_out_at := Vector2.ZERO
var _shimmer: ColorRect = null
var _glow: ColorRect = null
var _gate_lights: Array[Sprite2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_shimmer()
	_build_glow()
	_build_mist()
	_build_gate_lights()
	_build_beast()
	_build_embers()
	_build_vignette()
	_layout()


func _build_backdrop() -> void:
	_backdrop = TextureRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.texture = _load("res://art/bg/menu_key_art.png")
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nearest, or the pixel art stops being pixel art the moment it is scaled up
	# to fill a 1080p screen.
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_backdrop)


## Two mist bands, crossing.
##
## Slices of the backdrop were the first attempt — the reasoning being that a
## strip of the vista is already the right colour for the sky it drifts through.
## It drew two flat grey rectangles with hard edges straight across the middle of
## the screen. A rectangle of sky is not mist; what makes mist is that it has no
## edges at all.
##
## So the band is a shader instead: a soft horizontal smear that fades out at the
## top, the bottom and both ends, with a little noise through it so it is not a
## clean gradient either. Nothing to slice, nothing to fall out of step with a
## regenerated backdrop, and no edges anywhere.
const MIST_SHADER: String = """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.78, 0.82, 0.94, 1.0);
uniform float strength = 0.16;
uniform float drift = 0.0;

// Cheap value noise. A gradient with no grain in it reads as a lighting bug
// rather than as weather.
float hash(vec2 at) {
	return fract(sin(dot(at, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 at) {
	vec2 cell = floor(at);
	vec2 into = fract(at);
	into = into * into * (3.0 - 2.0 * into);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), into.x),
	           mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), into.x), into.y);
}

void fragment() {
	// Fades to nothing at the top and bottom of the band, and at both ends, so
	// there is no edge anywhere on it.
	float band = sin(UV.y * 3.14159);
	float ends = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);

	float grain = noise(vec2(UV.x * 5.0 + drift, UV.y * 2.0)) * 0.6 + 0.4;

	COLOR = vec4(tint.rgb, band * band * ends * grain * strength);
}
"""


## Twinkling stars, and a horizon that breathes.
##
## Both add light rather than replacing it (`blend_add`), so they lift what the
## backdrop already has instead of painting over it. That is what keeps the
## shimmer from reading as a second, wrong set of stars laid on top of the
## painted ones: it brightens the sky in the places stars already are, which is
## what twinkling is.
const SKY_SHADER: String = """
shader_type canvas_item;
render_mode blend_add;

uniform float time_now = 0.0;
uniform float density = 62.0;
uniform vec4 tint : source_color = vec4(0.86, 0.90, 1.0, 1.0);
uniform float strength = 0.5;

float hash(vec2 at) {
	return fract(sin(dot(at, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Sky only. Fades out well before the ridgeline, so nothing twinkles on a
	// mountain.
	float sky = smoothstep(0.62, 0.18, UV.y);
	if (sky <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 cell = floor(UV * density);
		vec2 into = fract(UV * density);

		// One candidate star per cell, at its own place inside that cell, so
		// they are scattered rather than on a grid.
		vec2 at = vec2(hash(cell), hash(cell + 17.0));
		float near = 1.0 - smoothstep(0.0, 0.10, distance(into, at));

		// Most cells hold nothing. Sparse is what makes the ones that do read
		// as stars rather than as noise.
		float exists = step(0.90, hash(cell + 3.7));

		// Each on its own phase and its own rate, so the sky never pulses as
		// one thing.
		float phase = hash(cell + 8.1) * 6.2831;
		float rate = 0.6 + hash(cell + 5.3) * 1.4;
		float pulse = 0.35 + 0.65 * (0.5 + 0.5 * sin(time_now * rate + phase));

		COLOR = vec4(tint.rgb, near * exists * pulse * sky * strength);
	}
}
"""

const GLOW_SHADER: String = """
shader_type canvas_item;
render_mode blend_add;

uniform float time_now = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.26, 1.0);
uniform float strength = 0.16;

void fragment() {
	// A soft band, brightest along its middle and gone at both edges.
	float band = sin(UV.y * 3.14159);
	float ends = smoothstep(0.0, 0.30, UV.x) * smoothstep(1.0, 0.70, UV.x);

	// Breathing, slowly. The last light of a day does not hold still.
	float breath = 0.80 + 0.20 * sin(time_now * 0.21);

	COLOR = vec4(tint.rgb, band * band * ends * breath * strength);
}
"""


func _build_shimmer() -> void:
	_shimmer = _shaded("Shimmer", SKY_SHADER)


func _build_glow() -> void:
	_glow = _shaded("HorizonGlow", GLOW_SHADER)


## A full-rect ColorRect carrying one shader. Four of the five layers on this
## stage are exactly this, so it is written once.
func _shaded(name: String, code: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	add_child(rect)
	return rect


func _build_mist() -> void:
	var shader := Shader.new()
	shader.code = MIST_SHADER
	for index: int in 2:
		var band := ColorRect.new()
		band.name = "Mist%d" % index
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("strength", 0.20 if index == 0 else 0.13)
		material.set_shader_parameter("tint",
			Color(0.80, 0.84, 0.96) if index == 0 else Color(0.92, 0.80, 0.74))
		band.material = material
		add_child(band)
		_mist.append(band)


func _build_gate_lights() -> void:
	var texture: Texture2D = LightKit.falloff_texture()
	if texture == null:
		return
	for index: int in GATE_LIGHTS.size():
		var light := Sprite2D.new()
		light.name = "GateFire%d" % index
		light.texture = texture
		light.modulate = Color(1.0, 0.48, 0.18, 0.14)
		add_child(light)
		_gate_lights.append(light)


func _build_beast() -> void:
	_frames = _series("res://art/beast/beast_idle_%02d.png")
	if _frames.is_empty():
		_frames = _series("res://art/beast/beast_walk_%02d.png")

	# A soft contact shadow, under the beast and before it in the tree so it
	# draws behind. See `_baseline` for what it is replacing.
	_shadow = Sprite2D.new()
	_shadow.name = "BeastShadow"
	_shadow.texture = _round_shadow()
	_shadow.centered = true
	add_child(_shadow)

	_beast = Sprite2D.new()
	_beast.name = "Beast"
	_beast.centered = true
	_beast.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not _frames.is_empty():
		_beast.texture = _frames[0]
		_baseline = _find_baseline(_frames[0])
		if _baseline > 0:
			_beast.region_enabled = true
			_beast.region_rect = Rect2(0.0, 0.0,
				float(_frames[0].get_width()), float(_baseline))
	add_child(_beast)


## The row the beast art draws its own ground line on, or 0 if it has none.
##
## The frames carry a hard dark line under the feet. In the beast scope that is
## right — it is the contact shadow against the ground strip the beast walks on.
## Here there is no ground strip, so it drew as a black bar ruled across the road
## with the beast floating above it.
##
## Found rather than hardcoded, because the frames are generated art and a row
## number written down here would quietly stop being the right one the next time
## they are.
func _find_baseline(texture: Texture2D) -> int:
	var image: Image = texture.get_image()
	if image == null:
		return 0
	var width: int = image.get_width()
	for y: int in range(image.get_height() - 1, -1, -1):
		var opaque: int = 0
		var dark: int = 0
		for x: int in width:
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.5:
				continue
			opaque += 1
			if pixel.get_luminance() < 0.24:
				dark += 1
		if opaque == 0:
			continue
		# A drawn ground line is a wide row that is almost entirely dark. Any
		# row of the beast itself has highlights in it.
		if opaque > width / 2 and dark > opaque * 9 / 10:
			return y
		return 0
	return 0


## A soft round shadow, built rather than authored.
##
## One 64px radial gradient squashed under the feet. A PNG of this would be a
## manifest row describing a blurred ellipse.
func _round_shadow() -> Texture2D:
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(0.04, 0.03, 0.06, 0.55))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(0.04, 0.03, 0.06, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture


## Embers drifting up out of the valley.
##
## Seeded across their own lifetime by `preprocess`, so the screen opens with a
## field of them already rising rather than with the first one being born — a
## particle system that starts empty announces itself as a particle system.
func _build_embers() -> void:
	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = 44
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.direction = Vector2.UP
	embers.spread = 22.0
	embers.gravity = Vector2(0.0, -9.0)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 26.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.4
	embers.color = Color("ffb35c")
	# Fading in and out rather than popping: an ember that appears at full
	# brightness at the bottom of the screen is a sprite, not an ember.
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1.0, 0.70, 0.36, 0.0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1.0, 0.45, 0.20, 0.0))
	fade.add_point(0.22, Color(1.0, 0.78, 0.42, 0.85))
	fade.add_point(0.70, Color(1.0, 0.58, 0.28, 0.55))
	# The Gradient itself, not a GradientTexture1D wrapping it: CPUParticles2D
	# takes the curve, and the GPU node is the one that takes a texture of it.
	embers.color_ramp = fade
	add_child(embers)


## A vignette, so the button column and the logo have something to sit against.
##
## Drawn rather than authored: it is four gradients' worth of nothing, and a PNG
## of it would be a 1920x1080 file in the manifest that says less than this does.
func _build_vignette() -> void:
	var shade := ColorRect.new()
	shade.name = "Vignette"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform float edge = 0.62;
uniform float left_band = 0.42;

void fragment() {
	// Round falloff from the centre, for the frame.
	float away = distance(UV, vec2(0.5)) * 1.42;
	float ring = smoothstep(edge, 1.0, away) * 0.72;

	// Plus a straight wash down the left, which is the half the buttons are on
	// and the half that has to stay readable whatever the art does there.
	float wash = smoothstep(left_band, 0.0, UV.x) * 0.40;

	COLOR = vec4(tint.rgb, max(ring, wash));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	add_child(shade)


## The stage's extent, taken from the viewport rather than from `size`.
##
## A Control's own size is zero until the layout pass that fills it has run, and
## `_ready` is before that pass — so laying out against `size` there put every
## element at the origin at native scale: a 256px beast in the top-left corner of
## an otherwise empty screen. Connecting to `resized` did not save it either,
## because this node is added from code after its parent has already settled and
## the signal never fires.
##
## The viewport rect is correct from the first frame and stays correct through a
## window resize, which is the whole of what this needs.
func _span() -> Vector2:
	return get_viewport_rect().size


func _layout() -> void:
	var span: Vector2 = _span()
	if span.x <= 0.0 or span.y <= 0.0:
		return
	_laid_out_at = span

	# Overscanned so the drift can never pull a bare edge into frame.
	var over: float = Balance.MENU_OVERSCAN
	_backdrop.size = span * over
	_backdrop.position = -span * (over - 1.0) * 0.5
	_home = _backdrop.position

	if _beast != null and not _frames.is_empty():
		var native: float = float(_baseline) if _baseline > 0 \
			else float(_frames[0].get_height())
		var grow: float = span.y * BEAST_HEIGHT / maxf(native, 1.0)
		_beast.scale = Vector2.ONE * grow
		_beast.position = span * BEAST_AT
		_beast.modulate = _sampled_beast_tint()
		if _shadow != null:
			# Wider than the beast and very flat, sitting just under where its
			# feet now end.
			_shadow.scale = Vector2(native * grow / 42.0, native * grow / 190.0)
			_shadow.position = _beast.position + Vector2(0.0, native * grow * 0.47)

	for index: int in _gate_lights.size():
		var light: Sprite2D = _gate_lights[index]
		light.position = span * GATE_LIGHTS[index]
		var diameter: float = span.y * (0.13 if index == 2 else 0.095)
		var base_scale: Vector2 = Vector2.ONE * (diameter
			/ maxf(float(light.texture.get_width()), 1.0))
		light.scale = base_scale
		light.set_meta(&"base_scale", base_scale)

	if _shimmer != null:
		_shimmer.position = Vector2.ZERO
		_shimmer.size = span

	if _glow != null:
		# Sat on the horizon, which is where the backdrop's warm band is.
		_glow.size = Vector2(span.x, span.y * 0.30)
		_glow.position = Vector2(0.0, span.y * 0.42 - _glow.size.y * 0.5)

	for index: int in _mist.size():
		var band: ColorRect = _mist[index]
		band.size = Vector2(span.x, span.y * (0.24 if index == 0 else 0.18))
		band.position = Vector2(0.0,
			span.y * (0.50 if index == 0 else 0.66) - band.size.y * 0.5)

	var embers := get_node_or_null("Embers") as CPUParticles2D
	if embers != null:
		embers.position = Vector2(span.x * 0.5, span.y * 0.92)
		embers.emission_rect_extents = Vector2(span.x * 0.5, span.y * 0.06)


## Samples the gate painting at the beast's authored location. Hue and exposure
## therefore keep matching if the backdrop is replaced, while the floor keeps
## the subject readable over the near-black threshold stones.
func _sampled_beast_tint() -> Color:
	if _backdrop == null or _backdrop.texture == null:
		return Color.WHITE
	var image: Image = _backdrop.texture.get_image()
	if image == null or image.is_empty():
		return Color.WHITE
	var centre := Vector2i(
		clampi(roundi(float(image.get_width()) * BEAST_AT.x), 0, image.get_width() - 1),
		clampi(roundi(float(image.get_height()) * BEAST_AT.y), 0, image.get_height() - 1))
	var reach: int = maxi(mini(image.get_width(), image.get_height()) / 18, 2)
	var sum := Color(0.0, 0.0, 0.0, 0.0)
	var count: int = 0
	for y: int in range(maxi(centre.y - reach, 0),
			mini(centre.y + reach + 1, image.get_height()), 3):
		for x: int in range(maxi(centre.x - reach, 0),
				mini(centre.x + reach + 1, image.get_width()), 3):
			var pixel: Color = image.get_pixel(x, y)
			sum += Color(pixel.r, pixel.g, pixel.b, 0.0)
			count += 1
	if count <= 0:
		return Color.WHITE
	var sampled := Color(sum.r / float(count), sum.g / float(count),
		sum.b / float(count))
	var peak: float = maxf(maxf(sampled.r, sampled.g), maxf(sampled.b, 0.001))
	var hue := Color(sampled.r / peak, sampled.g / peak, sampled.b / peak)
	var exposure: float = clampf(sampled.get_luminance() * 1.65,
		Balance.MENU_BEAST_LIGHT_FLOOR, 0.94)
	var mixed: Color = Color.WHITE.lerp(hue, Balance.MENU_BEAST_TINT_STRENGTH)
	return Color(mixed.r * exposure, mixed.g * exposure, mixed.b * exposure, 1.0)


func _process(delta: float) -> void:
	_time += delta
	var span: Vector2 = _span()
	if span.x <= 0.0:
		return
	# Re-laid on a window resize. Cheap, and checked here rather than driven by
	# `resized` for the reason given on `_span`.
	if not span.is_equal_approx(_laid_out_at):
		_layout()

	var turn: float = TAU * _time / maxf(Balance.MENU_DRIFT_PERIOD, 1.0)
	var travel: Vector2 = span * Balance.MENU_DRIFT
	var backdrop_drift := Vector2(
		sin(turn) * travel.x, sin(turn * 0.61) * travel.y)

	if _backdrop != null:
		_backdrop.position = _home + backdrop_drift

	if _beast != null:
		if not _frames.is_empty():
			var step: int = int(_time / maxf(Balance.MENU_BEAST_FRAME_TIME, 0.01))
			_beast.texture = _frames[step % _frames.size()]
		# Against the backdrop rather than with it, so the two separate in depth.
		# A foreground that drifts in step with its background is one flat image
		# being slid around.
		_beast.position = span * BEAST_AT - Vector2(
			sin(turn) * travel.x, sin(turn * 0.61) * travel.y) * 0.55

	for shaded: ColorRect in [_shimmer, _glow]:
		if shaded == null:
			continue
		var sky: ShaderMaterial = shaded.material as ShaderMaterial
		if sky != null:
			sky.set_shader_parameter("time_now", _time)

	# The band itself does not move; what moves is the noise inside it, which is
	# what mist actually does. Sliding the whole band would drag its soft ends
	# across the frame and give it edges again.
	for index: int in _mist.size():
		var rate: float = Balance.MENU_MIST_SPEED * (0.012 if index == 0 else -0.008)
		var material: ShaderMaterial = _mist[index].material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("drift", _time * rate)

	for index: int in _gate_lights.size():
		var light: Sprite2D = _gate_lights[index]
		light.position = span * GATE_LIGHTS[index] + backdrop_drift
		var pulse: float = 0.86 + 0.14 * sin(_time * (4.1 + index * 0.37)
			+ float(index) * 1.73)
		light.modulate.a = 0.10 + pulse * 0.075
		light.scale = (light.get_meta(&"base_scale", light.scale) as Vector2) \
			* (0.94 + pulse * 0.08)


## Absence is a supported state: the menu drew fine as a still image before any
## of this, and a missing frame set should cost the animation, not the screen.
func _series(format: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for index: int in 64:
		var path: String = format % index
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
