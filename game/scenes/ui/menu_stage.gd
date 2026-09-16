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
## The drawn corners: two hanging vines and two ferns.
var _foliage: Array[MenuFoliage] = []
## The leaves that let go of them. Two of these: one behind the interface
## and one, more rarely used, in front of it.
var _leaves_behind: MenuLeaves = null
var _leaves_infront: MenuLeaves = null
var _tail: BeastTailSpline = null
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
## The weather and the light (owner brief, 2026-09-12).
var _rays: ColorRect = null
var _rain: CPUParticles2D = null
var _fires: Array[Sprite2D] = []
var _fireflies: MenuFireflies = null
var _elements: MenuElements = null
var _birds: MenuBirds = null
var _camp: MenuCamp = null
var _camp_fire: CampFire = null
var _logo_glow: Sprite2D = null
var _logo_sparks: CPUParticles2D = null
var _grade: ColorRect = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# **The whole stage sits below the interface, and it has to say so itself.**
	# Tree order puts it under the logo and the buttons, which is right until
	# something inside it wants a `z_index` - `z_index` sorts across the entire
	# canvas layer rather than within a parent, so the foliage at 6 was drawing
	# over the menu buttons and a frond was sitting across Quit. Pushing the
	# stage negative keeps its own internal ordering exactly as it was (children
	# are relative) while putting the top of it under everything the player has
	# to read.
	z_index = Balance.MENU_STAGE_Z
	_build_backdrop()
	_build_shimmer()
	_build_glow()
	_build_mist()
	_build_gate_lights()
	_build_fires()
	_build_beast()
	_build_fireflies()
	_build_elements()
	_build_birds()
	_build_camp()
	_build_rays()
	_build_embers()
	_build_rain()
	_build_logo_glow()
	_build_foliage()
	_build_leaves()
	_build_vignette()
	_build_grade()
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
	_fade_the_stub(_beast)
	add_child(_beast)
	# The tail, rooted on the frame's own stub and drawn behind the body
	# (owner brief, 2026-09-12: the menu's Yuri had none).
	# **A spline rather than a sprite** (owner, 2026-09-15). See
	# `beast_tail_spline.gd`: the limb is the painting cut into slices and laid
	# along a chain whose first point is the body's own stub row, so the join
	# cannot come apart and the tail is alive rather than placed.
	var painting: Texture2D = _load("res://art/beast/beast_tail_idle_00.png")
	if painting == null:
		painting = _load("res://art/beast/beast_tail.png")
	if painting != null:
		_tail = BeastTailSpline.new()
		_tail.name = "Tail"
		_tail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_tail.adopt(painting)
		_tail.frame_time = Balance.MENU_BEAST_FRAME_TIME
		if not _frames.is_empty():
			_tail.harmonise(_frames[0])
		# **No material on the tail.** It is drawn whole and simply placed; the
		# beast's own stub is what dissolves into it (`_fade_the_stub`). A
		# shader here also cost the tail the scene tint, because assigning to
		# COLOR throws the inherited modulate away.
		_tail.show_behind_parent = true
		_beast.add_child(_tail)
		_place_menu_tail()


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
		# No line - the 2026-09-11 frames were drawn without one - so the
		# baseline is the row under the feet: the same crop, with nothing to
		# cut, and the same height for the layout to grow to.
		return y + 1
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
	_place_foliage(span)
	# **Where the leaves let go**, refreshed with the corners themselves: a
	# strand that moved is a strand whose leaves are somewhere else now.
	var hanging: Array[Dictionary] = []
	for corner: MenuFoliage in _foliage:
		hanging.append_array(corner.leaf_points())
	for layer: MenuLeaves in [_leaves_behind, _leaves_infront]:
		if layer != null:
			layer.span = span
			layer.fall_from(hanging)

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
		var beast_grade: Color = _sampled_beast_tint()
		_beast.modulate = beast_grade
		# **The limb is told the same thing on the same frame.** It does not
		# arrive down the modulate chain - measured - and a tail graded from a
		# different value than the body it grows from is the fault this has
		# been reported for seven times.
		if _tail != null:
			_tail.wear_grade(beast_grade)
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
			_drive_menu_tail()
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

	_drive_weather(span, backdrop_drift)

	# **The gate fires move with the backdrop, and that is correct.**
	#
	# Reported as looking like they sway with the beast's camera (owner,
	# 2026-09-14). They do move - but with the *backdrop*, by exactly its own
	# drift, because each one is the glow of a torch painted into that art. Held
	# still while the painting drifts, every flame would slide off its own
	# torch within a few seconds, which is the bug this looks like but is not.
	#
	# They are deliberately not parented to the backdrop: it is overscanned and
	# scaled to the window, and a child of it would be scaled too - a flame the
	# size of the gate on an ultrawide.
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


## The beast's own tail stub dissolves at the canvas edge, so the separate
## tail behind it shows through rather than butting against it.
##
## On the body rather than on the tail: see `beast_stub_fade.gdshader` and the
## note on `Balance.BEAST_STUB_FADE_PX`.
static func _fade_the_stub(body: Sprite2D) -> void:
	var fade := ShaderMaterial.new()
	fade.shader = load("res://scripts/shaders/beast_stub_fade.gdshader")
	fade.set_shader_parameter("fade_px", Balance.BEAST_STUB_FADE_PX)
	body.material = fade


## Roots the menu tail on the current frame's stub. With the region cut at the
## baseline the frame's centre moves up by half the cut, so the root is
## shifted the same.
func _place_menu_tail() -> void:
	if _tail == null or _beast == null or _beast.texture == null:
		return
	var root: Vector2 = BeastTail.root_of(_beast.texture)
	if root == Vector2.ZERO:
		_tail.position = Balance.BEAST_TAIL_ANCHOR
		return
	var cut: float = 0.0
	if _beast.region_enabled:
		cut = float(_beast.texture.get_height()) - _beast.region_rect.size.y
	_tail.position = root + Vector2(Balance.BEAST_TAIL_OVERLAP,
		cut * 0.5 - Balance.BEAST_TAIL_LIFT)


## **The spline moves itself**; this only keeps its root on the body, because
## the body's own stub row changes with the frame of the idle.
func _drive_menu_tail() -> void:
	if _tail == null:
		return
	_place_menu_tail()


# --- The weather and the light (2026-09-12) ------------------------------------------

const RAYS_SHADER: String = """
shader_type canvas_item;
render_mode blend_add;

uniform float time_now = 0.0;
uniform vec2 origin = vec2(0.82, -0.18);
uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.6, 1.0);
uniform float strength = 0.14;

void fragment() {
	vec2 d = UV - origin;
	float angle = atan(d.y, d.x);
	float dist = length(d);
	float rays = sin(angle * 18.0 + time_now * 0.11) * 0.5 + 0.5;
	rays *= sin(angle * 7.0 - time_now * 0.07) * 0.5 + 0.5;
	rays = pow(rays, 2.2);
	float fade = smoothstep(1.4, 0.15, dist) * smoothstep(-0.05, 0.3, UV.y);
	COLOR = vec4(tint.rgb, rays * fade * strength);
}
"""


## Light rays: a slow fan from the upper right, over the gate and the beast.
func _build_rays() -> void:
	_rays = _shaded("Rays", RAYS_SHADER)
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)


## Rain: thin streaks falling across the whole frame, angled with the wind.
func _build_rain() -> void:
	_rain = CPUParticles2D.new()
	_rain.name = "Rain"
	_rain.texture = _streak_texture()
	_rain.amount = maxi(int(float(Balance.MENU_RAIN_AMOUNT) * Graphics.particle_scale()), 8)
	_rain.lifetime = 2.6
	_rain.preprocess = 2.6
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.direction = Vector2(-0.16, 1.0)
	_rain.spread = 2.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = Balance.MENU_RAIN_SPEED.x
	_rain.initial_velocity_max = Balance.MENU_RAIN_SPEED.y
	_rain.angle_min = 9.0
	_rain.angle_max = 9.0
	_rain.scale_amount_min = 0.8
	_rain.scale_amount_max = 1.5
	_rain.color = Color(0.78, 0.86, 1.0, 0.26)
	add_child(_rain)


## A drop: a short vertical streak, bright in the middle and soft at both ends.
func _streak_texture() -> Texture2D:
	var image := Image.create(3, 18, false, Image.FORMAT_RGBA8)
	for y: int in 18:
		var along: float = float(y) / 17.0
		var alpha: float = sin(along * PI)
		image.set_pixel(1, y, Color(1.0, 1.0, 1.0, alpha))
		image.set_pixel(0, y, Color(1.0, 1.0, 1.0, alpha * 0.35))
		image.set_pixel(2, y, Color(1.0, 1.0, 1.0, alpha * 0.35))
	return ImageTexture.create_from_image(image)


## The gate's fires, animated: the camp fire's own frames, with its glow and
## its light, sat on each brazier the key art paints.
func _build_fires() -> void:
	# The flame alone, cropped off the camp fire's frames: the braziers are
	# painted into the key art already, and a stone ring floating on a gate
	# pillar read as exactly that.
	var art: String = "res://art/ui/menu_flame.png"
	if not ResourceLoader.exists(art):
		return
	for index: int in GATE_LIGHTS.size():
		var fire := CampFire.new()
		fire.name = "GateFlame%d" % index
		fire.texture = load(art)
		fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(fire)
		# **A fire nobody is fighting beside is a fire somebody looks at.**
		# Owner, 2026-09-15: the menu's fires want glow that flickers, shafts,
		# embers and light on the ground under them. `make_showpiece` is opt-in
		# for exactly this reason - a battlefield burns dozens of these.
		fire.make_showpiece(Balance.MENU_GATE_FIRE_GLOW)
		_fires.append(fire)


## Fireflies about the beast: a slow drift, blinking.
## The fireflies, and why they stopped being particles.
##
## **They were sixteen particles in a sphere over the beast's shoulder**, which
## is a glowing cloud rather than an insect: they emitted, drifted outward and
## died, all from one point, all on the same ramp. The owner's brief was
## "procedurally coming on and off where they're more likely to be on the map as
## they wander", and a particle system can do the blink and neither of the other
## two - it has no notion of a place a fly would rather be, and its drift is an
## initial velocity rather than a mind being changed.
##
## `MenuFireflies` is three dozen that each keep their own clock, wander with a
## slow jitter, and are drawn back toward the greenery when they stray out over
## the road. See the note on that file for why the blink curve is a power.
func _build_fireflies() -> void:
	_fireflies = MenuFireflies.new()
	_fireflies.name = "Fireflies"
	add_child(_fireflies)


## The elements crossing the valley. See `menu_elements.gd`: one pass every
## twenty seconds or so and never the same one twice running.
func _build_elements() -> void:
	_elements = MenuElements.new()
	_elements.name = "Elements"
	add_child(_elements)


## The leaves that fall off the hanging vines.
##
## **Two nodes, because one cannot be in two places.** The common layer sits
## here in the stage, under everything the interface draws; the rare one is put
## on its own `CanvasLayer` above the buttons by the menu itself. Splitting them
## is what lets a leaf cross in front of a word now and then without every leaf
## doing it - see `menu_leaves.gd`.
func _build_leaves() -> void:
	_leaves_behind = MenuLeaves.new()
	_leaves_behind.name = "LeavesBehind"
	add_child(_leaves_behind)


## The layer the rare front leaves are drawn on. The menu hangs this over its
## own interface; the stage only builds it.
func front_leaves() -> MenuLeaves:
	if _leaves_infront == null:
		_leaves_infront = MenuLeaves.new()
		_leaves_infront.name = "LeavesInFront"
	return _leaves_infront


## Somebody out there watching the beast.
##
## **Built late, so it is in front of everything.** The whole vignette depends
## on reading as foreground - a Warden at a tenth of the screen's height is only
## small if the eye can tell they are *near*, and nothing says near like being
## in front of the weather.
func _build_camp() -> void:
	_camp = MenuCamp.new()
	_camp.name = "Camp"
	add_child(_camp)
	# The campfire is the same animated flame the gate braziers burn, rather
	# than a second kind of fire on one screen.
	var art: String = "res://art/ui/menu_flame.png"
	if ResourceLoader.exists(art):
		_camp_fire = CampFire.new()
		_camp_fire.name = "CampFlame"
		_camp_fire.texture = load(art)
		_camp_fire.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_camp_fire.make_showpiece(Balance.MENU_CAMP_FIRE_GLOW)
		add_child(_camp_fire)


## The birds. Behind the beast in tree order, so one crossing the arch passes
## behind the thing whose size the arch exists to state.
func _build_birds() -> void:
	_birds = MenuBirds.new()
	_birds.name = "Birds"
	# **Tree order, and no `z_index`.** The first cut put them at -1 to keep
	# them behind the gate's stonework, which put them behind the *backdrop* -
	# and the backdrop is one opaque texture across the whole screen, so every
	# bird flew where nobody could see it. Built here, after the beast and
	# before the rain, they are above the painting and under the weather.
	add_child(_birds)


## The wordmark's glow and the sparks that rise off it.
func _build_logo_glow() -> void:
	_logo_glow = Sprite2D.new()
	_logo_glow.name = "LogoGlow"
	_logo_glow.texture = LightKit.falloff_texture()
	_logo_glow.modulate = Color(1.0, 0.8, 0.45, 0.16)
	add_child(_logo_glow)
	_logo_sparks = CPUParticles2D.new()
	_logo_sparks.name = "LogoSparks"
	_logo_sparks.amount = 22
	_logo_sparks.lifetime = 3.4
	_logo_sparks.preprocess = 3.4
	_logo_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_logo_sparks.emission_rect_extents = Vector2(300.0, 90.0)
	_logo_sparks.direction = Vector2.UP
	_logo_sparks.spread = 40.0
	_logo_sparks.gravity = Vector2(0.0, -8.0)
	_logo_sparks.initial_velocity_min = 6.0
	_logo_sparks.initial_velocity_max = 18.0
	_logo_sparks.scale_amount_min = 0.8
	_logo_sparks.scale_amount_max = 1.8
	var gold := Gradient.new()
	gold.set_color(0, Color(1.0, 0.85, 0.45, 0.0))
	gold.set_color(1, Color(1.0, 0.7, 0.3, 0.0))
	gold.add_point(0.3, Color(1.0, 0.9, 0.55, 0.85))
	_logo_sparks.color_ramp = gold
	add_child(_logo_sparks)


## The grade over the stage: warm, a touch more saturated and contrasted, and
## vignetted, so the key art, the beast frames and the effects composite as
## one picture rather than layers.
func _build_grade() -> void:
	_grade = ColorRect.new()
	_grade.name = "Grade"
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/shaders/color_grade.gdshader")
	material.set_shader_parameter("tint", Balance.MENU_GRADE_TINT)
	material.set_shader_parameter("saturation", Balance.MENU_GRADE_SATURATION)
	material.set_shader_parameter("contrast", Balance.MENU_GRADE_CONTRAST)
	material.set_shader_parameter("lift", 0.02)
	material.set_shader_parameter("vignette", Balance.MENU_GRADE_VIGNETTE)
	material.set_shader_parameter("night", 0.0)
	_grade.material = material
	_grade.visible = Graphics.grade_enabled()
	add_child(_grade)


## Everything above, placed and driven each frame.
func _drive_weather(span: Vector2, backdrop_drift: Vector2) -> void:
	var unit: float = span.y / 1080.0
	if _rays != null:
		var material: ShaderMaterial = _rays.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("time_now", _time)
	if _rain != null:
		_rain.position = Vector2(span.x * 0.5, -30.0)
		_rain.emission_rect_extents = Vector2(span.x * 0.7, 6.0)
		_rain.lifetime = span.y / 520.0 + 0.4
	for index: int in _fires.size():
		var fire: Sprite2D = _fires[index]
		fire.position = span * GATE_LIGHTS[index] + backdrop_drift + Vector2(0.0, -6.0 * unit)
		fire.scale = Vector2.ONE * unit * Balance.MENU_FIRE_SCALE
	if _fireflies != null:
		_fireflies.position = Vector2.ZERO
		_fireflies.resize(span)
	if _elements != null:
		_elements.position = Vector2.ZERO
		_elements.resize(span)
		_elements.light = _sampled_beast_tint()
		# Graded to the scene like everything else here, but only in hue: a
		# firefly is its own light source and must not be dimmed by the dusk it
		# is lighting. The stage's warm value pulls it slightly toward the
		# scene without taking its brightness away.
		var lamp: Color = stage_light()
		_fireflies.glow = Color(0.86, 0.94, 0.48).lerp(lamp, 0.25)
	if _camp != null:
		_camp.position = Vector2.ZERO
		_camp.resize(span)
		# Rock and cloak take the horizon's own colour, pushed dark - the same
		# grade the beast and the corner foliage get. The fire does not: it is a
		# light source, and grading a light by the dark it is lighting is how
		# you get a campfire you cannot see.
		var low: Color = _backdrop_near(Vector2(0.5, 0.86))
		if low.a <= 0.0:
			low = Color(0.22, 0.21, 0.26)
		_camp.firelight = Color(1.0, 0.72, 0.36).lerp(stage_light(), 0.2)
		_camp.shade = MenuCamp.graded_for(low, _camp.firelight)
		if _camp_fire != null:
			# **What the fire lights agrees with the fire.** The camp grades its
			# rock, its cloak and its rider toward the firelight; read as a
			# constant that is a painted highlight rather than a light, and a
			# flame flickering beside a figure lit at a fixed level is the thing
			# that reads as artificial in the wrong way.
			_camp.fire_pulse = _camp_fire.flicker()
			var where: Vector2 = _camp.fire_at()
			_camp_fire.visible = where != Vector2.ZERO
			_camp_fire.position = where
			var tall: float = span.y * Balance.MENU_CAMP_FIGURE * Balance.MENU_CAMP_FIRE_SIZE
			_camp_fire.scale = Vector2.ONE * (tall
				/ maxf(float(_camp_fire.texture.get_height()), 1.0))
	if _birds != null:
		_birds.position = Vector2.ZERO
		_birds.resize(span)
		# **Dim, not black** (owner brief). The corner sky's own colour at a
		# third of its brightness: a warm grey against a sunset, a cool one at
		# night, and never a hole cut in the picture.
		_birds.tint = Color(0.3, 0.29, 0.33, 0.9)
		# Each bird shades itself against the stretch of sky it is about to
		# cross, rather than the whole flock sharing one colour taken from one
		# point. See `MenuBirds._shade_for`.
		_birds.sky_at = func(at: Vector2) -> Color:
			return _backdrop_near(Vector2(at.x / maxf(span.x, 1.0),
				at.y / maxf(span.y, 1.0)))
	var title: Control = get_parent().get_node_or_null("Title") as Control if get_parent() != null else null
	if title != null:
		var centre: Vector2 = title.position + title.size * 0.5
		if _logo_glow != null:
			_logo_glow.position = centre
			var falloff: Texture2D = _logo_glow.texture
			var width: float = float(falloff.get_width()) if falloff != null else 256.0
			_logo_glow.scale = Vector2(title.size.x * 1.15 / width, title.size.y * 1.4 / width)
			_logo_glow.modulate.a = 0.13 + 0.05 * sin(_time * 1.3)
		if _logo_sparks != null:
			_logo_sparks.position = centre
			_logo_sparks.emission_rect_extents = title.size * Vector2(0.36, 0.26)
	if _grade != null:
		_grade.visible = Graphics.grade_enabled()
		var material: ShaderMaterial = _grade.material as ShaderMaterial
		if material != null:
			material.set_shader_parameter("now", _time)


## The corners: branches with hanging vines above, ferns at the feet.
##
## **Drawn, not animated** - the owner's brief called looping pixel animation
## repetitive, and it is: the moment a viewer sees the loop they stop seeing the
## plant. `MenuFoliage` sums sines of incommensurable periods instead, so the
## motion never returns to a pose and there is nothing to recognise.
##
## Silhouettes in the backdrop's own darkest value, so they belong to whatever
## sky is behind them without needing a set of assets per act. In front of the
## stage and behind the interface: foliage is scenery, and a frond over a button
## is a frond in the way.
func _build_foliage() -> void:
	var pieces: Array[Array] = [
		[MenuFoliage.Kind.VINE, Balance.MENU_VINE_LEFT, 1.0, 0.0],
		[MenuFoliage.Kind.VINE, Balance.MENU_VINE_RIGHT, -1.0, 2.2],
		[MenuFoliage.Kind.FERN, Balance.MENU_FERN_LEFT, 1.0, 1.1],
		[MenuFoliage.Kind.FERN, Balance.MENU_FERN_RIGHT, -1.0, 3.4],
	]
	for row: Array in pieces:
		var leaf := MenuFoliage.new()
		leaf.name = "Foliage%d" % _foliage.size()
		leaf.kind = int(row[0])
		leaf.anchor = row[1] as Vector2
		leaf.facing = float(row[2])
		leaf.phase = float(row[3])
		leaf.sway = Balance.MENU_VINE_SWAY if leaf.kind == MenuFoliage.Kind.VINE 			else Balance.MENU_FERN_SWAY
		leaf.z_index = Balance.MENU_FOLIAGE_Z
		add_child(leaf)
		_foliage.append(leaf)


## Places and sizes the corners for the window as it is now.
##
## Called from `_layout` rather than set once, because the menu is re-laid on
## every resize and a corner piece sized for a desktop is a smear on a phone.
func _place_foliage(span: Vector2) -> void:
	for leaf: MenuFoliage in _foliage:
		leaf.position = span * leaf.anchor
		var share: float = Balance.MENU_VINE_REACH 			if leaf.kind == MenuFoliage.Kind.VINE else Balance.MENU_FERN_REACH
		leaf.reach = span.y * share
		leaf.tint = _foliage_tint()
		# **The painted leaves are graded to the corner they hang in**, exactly
		# as the beast is graded to the ground it stands on. A leaf carrying its
		# own daylight green against this dusk reads as a sticker; the same leaf
		# pulled halfway to the corner's hue and exposure sits in the scene.
		leaf.leaf_tint = _leaf_grade(leaf.anchor)
		leaf.queue_redraw()


## The darkest thing in the sky, which is what a near silhouette should be.
##
## Taken from the backdrop rather than typed in, so every act's menu gets
## foliage that belongs to its own sky - a black frond against a pale dawn is
## a hole in the screen, and the same frond against a night sky disappears.
func _foliage_tint() -> Color:
	var sky: Color = Color(0.05, 0.06, 0.06)
	if _backdrop != null and _backdrop.texture != null:
		var image: Image = _backdrop.texture.get_image()
		if image != null:
			sky = image.get_pixel(int(image.get_width() * 0.5),
				int(image.get_height() * 0.86))
	return Color(sky.r * 0.22, sky.g * 0.24, sky.b * 0.26, 0.94)


## What the painted foliage in a given corner is multiplied by.
##
## The beast's grade, applied to a leaf: the local backdrop's hue at half
## strength over an exposure taken from its luminance, floored so a dark corner
## does not swallow the plant it is supposed to be lighting. One function per
## corner rather than one for the screen, because the top of this scene is a
## purple sky and the bottom is a lit road, and a single grade cannot be right
## for both.
func _leaf_grade(at: Vector2) -> Color:
	var sampled: Color = _backdrop_near(at)
	if sampled.a <= 0.0:
		return Color(0.46, 0.54, 0.44, 0.97)
	var peak: float = maxf(maxf(sampled.r, sampled.g), maxf(sampled.b, 0.001))
	var hue := Color(sampled.r / peak, sampled.g / peak, sampled.b / peak)
	var exposure: float = clampf(sampled.get_luminance() * 2.4,
		Balance.MENU_LEAF_LIGHT_FLOOR, 0.96)
	var mixed: Color = Color.WHITE.lerp(hue, Balance.MENU_LEAF_TINT_STRENGTH)
	return Color(mixed.r * exposure, mixed.g * exposure, mixed.b * exposure, 0.97)


## The backdrop's mean colour around a point, as a fraction of the screen.
## Alpha 0 when there is no backdrop to read, which every caller treats as
## "no opinion" and falls back from.
func _backdrop_near(at: Vector2) -> Color:
	if _backdrop == null or _backdrop.texture == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var image: Image = _backdrop.texture.get_image()
	if image == null or image.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var centre := Vector2i(
		clampi(roundi(float(image.get_width()) * at.x), 0, image.get_width() - 1),
		clampi(roundi(float(image.get_height()) * at.y), 0, image.get_height() - 1))
	var reach: int = maxi(mini(image.get_width(), image.get_height()) / 12, 3)
	var sum := Vector3.ZERO
	var count: int = 0
	for y: int in range(maxi(centre.y - reach, 0),
			mini(centre.y + reach + 1, image.get_height()), 3):
		for x: int in range(maxi(centre.x - reach, 0),
				mini(centre.x + reach + 1, image.get_width()), 3):
			var pixel: Color = image.get_pixel(x, y)
			sum += Vector3(pixel.r, pixel.g, pixel.b)
			count += 1
	if count <= 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(sum.x / float(count), sum.y / float(count), sum.z / float(count), 1.0)


## The stage's own light, for anything grading itself to this screen.
##
## The warm middle of the backdrop rather than its darkest value - that one is
## the foliage silhouette's business. Normalised by the caller; this only has
## to report the hue the scene is lit in.
func stage_light() -> Color:
	if _backdrop == null or _backdrop.texture == null:
		return Color(1.0, 0.92, 0.82)
	var image: Image = _backdrop.texture.get_image()
	if image == null:
		return Color(1.0, 0.92, 0.82)
	# **The light in the scene, not the average of it.** Averaging the whole
	# band returned the dusky purple sky and graded the interface cold, on a
	# screen whose identity is the warm horizon behind the gate. A scene is lit
	# by its brightest quarter - here the sunset, at night the moon - so that is
	# what is sampled.
	var wide: int = image.get_width()
	var tall: int = image.get_height()
	var seen: Array[Color] = []
	for x: int in range(int(wide * 0.15), int(wide * 0.85), maxi(wide / 64, 1)):
		for y: int in range(int(tall * 0.12), int(tall * 0.70), maxi(tall / 48, 1)):
			seen.append(image.get_pixel(x, y))
	if seen.is_empty():
		return Color(1.0, 0.92, 0.82)
	seen.sort_custom(func(a: Color, b: Color) -> bool:
		return (a.r + a.g + a.b) > (b.r + b.g + b.b))
	var take: int = maxi(seen.size() / 4, 1)
	var total: Color = Color(0.0, 0.0, 0.0)
	for index: int in take:
		total += seen[index]
	return Color(total.r / float(take), total.g / float(take), total.b / float(take))
