class_name CampFire
extends Sprite2D

## A fire that burns: the authored flame frames beside `camp_fire.png` on
## the structure-idle convention, and a warm light under it that breathes
## (owner brief, 2026-09-12: "fireplaces at camps should be animated and
## have lighting"). One node, so the camps and the raid's dressing light
## their fires the same way.

var _frames: Array[Texture2D] = []
var _clock: float = 0.0
var _glow: Sprite2D = null
var _light: PointLight2D = null
var _seed: float = 0.0
## Showpiece parts. Null on every fire in the game except the handful the
## menu burns - see `make_showpiece`.
var _core: Sprite2D = null
var _pool: Sprite2D = null
var _embers: CPUParticles2D = null
var _showpiece: bool = false
var _glow_scale: float = 1.0
var _drawn_at: float = -1.0
var _flicker: float = 1.0
## The screen cull's clock and its last answer (2026-09-24).
var _cull_left: float = 0.0
var _seen: bool = true


func _ready() -> void:
	if texture != null and texture.resource_path != "":
		_frames = GameData.load_idle_frames(texture.resource_path)
	_seed = randf() * TAU
	_glow = Sprite2D.new()
	_glow.name = "Glow"
	_glow.texture = LightKit.falloff_texture()
	_glow.modulate = Balance.CAMP_FIRE_LIGHT
	_glow.scale = Vector2.ONE * (Balance.CAMP_FIRE_LIGHT_RADIUS
		/ maxf(float(LightKit.falloff_texture().get_width()), 1.0)) / maxf(scale.x, 0.01)
	_glow.position = Vector2(0.0, -6.0)
	_glow.z_index = -1
	_glow.z_as_relative = true
	add_child(_glow)
	_light = LightKit.add_light(self, Color(1.0, 0.62, 0.3), Balance.CAMP_FIRE_LIGHT_RADIUS * 1.4,
		0.9, 0.35)


func _process_measured(delta: float) -> void:
	_clock += delta
	# An unseen fire's embers rest (`ScreenCull`); the flicker still runs so
	# what the fire lights agrees with it the frame it comes into view.
	_cull_left -= delta
	if _cull_left <= 0.0:
		_cull_left = Balance.PARTICLE_CULL_INTERVAL
		var seen: bool = ScreenCull.sees(self, Balance.PARTICLE_CULL_MARGIN)
		if seen != _seen and _embers != null and is_instance_valid(_embers):
			_embers.visible = seen
		_seen = seen
	var flicker: float = 0.86 + 0.14 * sin(_clock * 9.0 + _seed) * sin(_clock * 3.7 + _seed * 0.5)
	_flicker = flicker
	if _showpiece:
		_tick_showpiece(flicker)
	if _glow != null:
		_glow.modulate.a = Balance.CAMP_FIRE_LIGHT.a * flicker
		_glow.scale = Vector2.ONE * (Balance.CAMP_FIRE_LIGHT_RADIUS
			/ maxf(float(LightKit.falloff_texture().get_width()), 1.0)) / maxf(scale.x, 0.01) \
			* (0.94 + 0.06 * flicker)
	if _light != null:
		_light.energy = 0.9 * flicker
	if _frames.is_empty():
		return
	var index: int = int(floor(_clock * Balance.CAMP_FIRE_FRAME_RATE)) % _frames.size()
	texture = _frames[index]


## How bright this fire is at this instant, from about 0.72 to 1.0.
##
## **So that what the fire lights agrees with the fire.** The camp grades its
## rock, its cloak and its rider toward `firelight`; read as a constant, that is
## a painted highlight rather than a light, and the flame flickering beside a
## figure lit at a fixed level is what reads as artificial in the wrong way.
func flicker() -> float:
	return _flicker


## **Turn one fire into something a player looks at rather than past.**
##
## Owner brief, 2026-09-15: the menu's fires want to be "holographic-esque with
## proper lighting and fake lighting", with "glow flickering and vfx game juice
## and embers". A fire on a battlefield is read at a glance and there are dozens
## of them; the three on the menu's gate and the one at the camp are on screen,
## still, for as long as somebody is deciding what to play.
##
## **Opt-in, and that is the whole reason it is a function rather than the
## default.** `flame.gd` cost this project 5.2ms of a 16ms frame by rebuilding
## polygons for a hundred flames every frame, and the answer then was the same
## as the answer here: sample the drawing rather than the clock, and do the
## expensive version only where it is looked at.
##
## Four parts, each one a thing the single radial glow could not do:
##
## - **A hot core** on its own faster clock, so the fire has a temperature
##   gradient rather than one soft halo.
## - **A pool on the ground**, flattened, so the rock under the fire is lit by
##   it. Without this the fire floats: everything around it is evenly dark and
##   only the flame is bright, which is exactly what a decal looks like.
## - **Light shafts**, faint and wavering, rising and widening. This is the
##   "holographic" read - light you can see the shape of - and it is two
##   additive triangles rather than anything volumetric.
## - **Embers**, drifting up and out and dying.
func make_showpiece(glow_scale: float = 1.0) -> void:
	if _showpiece:
		return
	_showpiece = true
	# The pool first, so it is under everything: a wide falloff squashed flat
	# against the ground, warmer and dimmer than the flame itself.
	_pool = Sprite2D.new()
	_pool.name = "Pool"
	_pool.texture = LightKit.falloff_texture()
	_pool.modulate = Color(Balance.CAMP_FIRE_LIGHT.r, Balance.CAMP_FIRE_LIGHT.g * 0.82,
		Balance.CAMP_FIRE_LIGHT.b * 0.6, Balance.CAMP_FIRE_LIGHT.a * 0.55)
	_pool.z_index = -2
	_pool.z_as_relative = true
	_pool.position = Vector2(0.0, 4.0)
	add_child(_pool)
	# The core: small, pale, and nearly white at the heart of the flame.
	_core = Sprite2D.new()
	_core.name = "Core"
	_core.texture = LightKit.falloff_texture()
	_core.modulate = Color(1.0, 0.86, 0.62, 0.5)
	# **Never above the fire's own layer.** At +1 the core of a fire standing
	# behind Yuri drew over him: a bright spot floating on the beast with no
	# fire visible under it, which the owner reported as light showing through.
	# Zero keeps it above the flame sprite by tree order and below anything the
	# scene draws in front of the fire, which is the whole of what it needs.
	_core.z_index = 0
	_core.z_as_relative = true
	_core.position = Vector2(0.0, -4.0)
	add_child(_core)
	_embers = CPUParticles2D.new()
	_embers.name = "Embers"
	_embers.amount = 14
	_embers.lifetime = 2.1
	_embers.preprocess = 1.0
	_embers.local_coords = false
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 5.0
	_embers.direction = Vector2(0.0, -1.0)
	_embers.spread = 26.0
	_embers.gravity = Vector2(0.0, -14.0)
	_embers.initial_velocity_min = 16.0
	_embers.initial_velocity_max = 38.0
	_embers.scale_amount_min = 0.7
	_embers.scale_amount_max = 1.6
	_embers.color = Color(1.0, 0.68, 0.3, 0.9)
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.86, 0.5, 0.95))
	fade.set_color(1, Color(0.9, 0.34, 0.12, 0.0))
	# `color_ramp` on a CPUParticles2D is the Gradient itself, not a texture of
	# one - that distinction is a parse error rather than a wrong look.
	_embers.color_ramp = fade
	var additive: CanvasItemMaterial = LightKit.additive_material()
	_embers.material = additive
	_embers.position = Vector2(0.0, -6.0)
	# Same reason as the core above: embers from a fire behind the beast must
	# not rise in front of it.
	_embers.z_index = 0
	_embers.z_as_relative = true
	add_child(_embers)
	# **Additive, like every other fire in this project draws itself.** See the
	# note at the top of `flame.gd`: a flame is emitted light rather than paint,
	# and the shafts below are drawn by this node so they take the same blend.
	var lit: CanvasItemMaterial = LightKit.additive_material()
	material = lit
	_glow_scale = glow_scale
	_tick_showpiece(1.0)


## The showpiece parts, sampled rather than driven every frame - see the note
## on `make_showpiece` about what redrawing a hundred flames cost.
func _tick_showpiece(flicker: float) -> void:
	var falloff: float = maxf(float(LightKit.falloff_texture().get_width()), 1.0)
	var own: float = maxf(scale.x, 0.01)
	if _pool != null:
		var spread: float = Balance.CAMP_FIRE_LIGHT_RADIUS * 1.5 * _glow_scale / falloff / own
		_pool.scale = Vector2(spread * (0.97 + 0.06 * flicker), spread * 0.30)
		_pool.modulate.a = Balance.CAMP_FIRE_LIGHT.a * 0.55 * flicker
	if _core != null:
		# Its own faster beat, so the heart of the fire is never in step with
		# the halo around it. One clock for both is what reads as a pulsing
		# lamp rather than as burning.
		var hot: float = 0.78 + 0.22 * sin(_clock * 15.7 + _seed * 2.3)
		var tight: float = Balance.CAMP_FIRE_LIGHT_RADIUS * 0.34 * _glow_scale / falloff / own
		_core.scale = Vector2.ONE * tight * (0.9 + 0.2 * hot)
		_core.modulate.a = 0.34 + 0.2 * hot
	if _clock - _drawn_at >= 1.0 / maxf(Balance.FLAME_REDRAW_HZ, 1.0):
		_drawn_at = _clock
		queue_redraw()


## The shafts. Drawn rather than textured because their shape is the point: two
## faint wedges leaning with the flame, widening as they rise and fading out
## before the top, which is what light looks like when there is something in the
## air for it to catch.
func _draw_measured() -> void:
	if not _showpiece:
		return
	var tall: float = Balance.CAMP_FIRE_LIGHT_RADIUS * 0.62 * _glow_scale / maxf(scale.y, 0.01)
	var wide: float = tall * 0.26
	for side: int in Balance.CAMP_FIRE_SHAFT_COUNT:
		# **Every cone is its own.** The old pair shared a length and took their
		# lean from the side index, so they swung as a matched pair - two wipers
		# rather than light. Each offset is an irrational step through the fire's
		# own seed, so no two shafts over one flame ever fall into step.
		var own: float = _seed + float(side) * 2.399963
		var spread: float = (float(side) - float(Balance.CAMP_FIRE_SHAFT_COUNT - 1) * 0.5) 			/ maxf(float(Balance.CAMP_FIRE_SHAFT_COUNT - 1), 1.0)
		var reach: float = tall * (0.74 + 0.40 * fposmod(own * 0.618, 1.0))
		# Its own flicker, at its own rate: a shaft that breathes with its
		# neighbour is one wide shaft with a seam down it.
		reach *= 0.88 + 0.12 * _flicker + 0.07 * sin(_clock * (0.9 + 0.27 * float(side)) + own * 1.7)
		var lean: float = sin(_clock * (0.7 + 0.31 * float(side)) + own)
		var foot: float = wide * 0.30 * spread * 2.0
		var head: Vector2 = Vector2(lean * wide * 0.5 + foot * 1.6, -reach)
		var lit: float = (0.055 + 0.03 * _flicker) 			* (1.0 - 0.25 * absf(spread))
		_feathered_shaft(foot, wide * 0.17, head, wide * 0.5, lit)


## One shaft, soft at both edges and fading out toward its head.
##
## **A `draw_colored_polygon` cannot have a soft edge**: one colour for the whole
## shape is what a hard edge is, and the owner reported exactly that. A colour
## *per vertex* can, so the shaft is three quads - a core, and a feather either
## side whose outer vertices are fully transparent - and the light falls off
## across the shaft instead of stopping at a line. The head vertices carry a
## fraction of the foot's alpha, so it also thins out as it rises, which is what
## a shaft of light in dusty air does.
func _feathered_shaft(foot_x: float, foot_half: float, head: Vector2,
		head_half: float, lit: float) -> void:
	var tint := Color(1.0, 0.72, 0.36, 1.0)
	var core := Color(tint, lit)
	var edge := Color(tint, 0.0)
	# The head keeps a little of the light so the fade is a gradient rather than
	# a cut, and the very tip is gone.
	var core_top := Color(tint, lit * 0.28)
	for band: int in 3:
		var from: float = float(band - 1)
		var to: float = float(band)
		# -1..0..1..2 across the three bands: the middle one is the core.
		var a: float = foot_x + foot_half * (from - 0.5) * 2.0
		var b: float = foot_x + foot_half * (to - 0.5) * 2.0
		var c: float = head.x + head_half * (to - 0.5) * 2.0
		var d: float = head.x + head_half * (from - 0.5) * 2.0
		var left_lit: Color = edge if band == 0 else core
		var right_lit: Color = edge if band == 2 else core
		var left_top: Color = edge if band == 0 else core_top
		var right_top: Color = edge if band == 2 else core_top
		draw_polygon(
			PackedVector2Array([Vector2(a, -2.0), Vector2(b, -2.0),
				Vector2(c, head.y), Vector2(d, head.y)]),
			PackedColorArray([left_lit, right_lit, right_top, left_top]))


## `FrameProfile` bucket "d_camp_fire": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_camp_fire", started)


## `FrameProfile` bucket "p_camp_fire": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_camp_fire", started)
