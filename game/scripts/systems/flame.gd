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

## Whether the flame carries a smoke emitter. A torch says no (`TORCH_SMOKES`);
## set before `configure`, which is where the emitters are built.
var smokes: bool = true

## 0..1. Scales height, glow and particle output together, so one number turns a
## fire up. The city uses it to make a fresh blaze settle into a steady burn.
var intensity: float = 1.0

var _time: float = 0.0
## Seconds since the flame last redrew; see `_process`.
var _redraw_debt: float = 0.0
var _seed: float = 0.0
var _lit: bool = true

## The glow's pulse and alpha, drawn by `_draw` (2026-09-24): it was a
## sprite under every flame - two hundred and twenty canvas items on Act X
## - and the flame already redraws at `FLAME_REDRAW_HZ`, which is exactly
## the clock the glow breathed on.
var _glow_pulse: float = 1.0
var _embers: CPUParticles2D
var _smoke: CPUParticles2D
var _light: PointLight2D
## Whether the camera could see this flame on its last tick.
var _seen: bool = true
## **An unseen flame sleeps** (2026-09-24). Two hundred and twenty flames
## ticked every frame to ask whether they were on screen, and the asking was
## 0.3 ms of a frame on which forty of them could be seen. A flame that finds
## itself off screen stops processing and lies here; `wake_the_seen` (called
## by `Vfx` on `PARTICLE_CULL_INTERVAL`) walks the list and wakes whichever
## the camera has reached. A flame's dance clock is not continuous across a
## sleep, and nothing can tell: it was off screen.
static var _dormant: Array[Flame] = []
## The screen test's own clock, staggered per flame, so two hundred flames do
## not each transform themselves into the viewport every frame.
var _cull_left: float = 0.0

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
	var additive: CanvasItemMaterial = LightKit.additive_material()
	material = additive

	if smokes:
		_build_smoke()
	_build_embers()

	if light_radius > 0.0:
		_light = LightKit.add_light(self, light_colour, light_radius,
			light_energy, Balance.TORCH_FLICKER)
		if casts_shadows:
			LightKit.enable_shadows(_light,
				Balance.SHADOW_LAYER_SCENERY | Balance.SHADOW_LAYER_UNITS,
				shadow_on_ultra_only)


# --- Silhouette -------------------------------------------------------------

func _process_measured(delta: float) -> void:
	if not _lit:
		return
	_time += delta * Balance.FLAME_DANCE_SPEED
	# **A flame the camera cannot see costs nothing.** The clock still runs, so
	# one sliding into frame is already mid-dance rather than starting from a
	# standstill - but the glow is not re-scaled and nothing is redrawn.
	#
	# This is the whole of `flame.gd`'s frame cost: three polygons rebuilt per
	# flame per frame, times every torch on a 75x75 grid, of which a handful
	# are ever on screen at gameplay zoom.
	_cull_left -= delta
	if _cull_left <= 0.0:
		_cull_left = Balance.PARTICLE_CULL_INTERVAL * randf_range(0.7, 1.3)
		var seen: bool = _on_screen()
		if seen != _seen:
			_seen = seen
			_show_particles(seen)
	if not _seen:
		_sleep()
		return
	# **Redrawn at `FLAME_REDRAW_HZ`, not every frame.** The clock above runs
	# at frame rate, so the dance is as smooth as the cadence it is sampled at
	# - and a fire sampled thirty times a second is a fire. Measured on the
	# 2026-09-14 field (100 flames, a hundred torches on the outskirts' roads):
	# `flame.gd` was 5.2 ms of a 17.7 ms frame with every flame rebuilding
	# three polygons a frame; at thirty a second it is half that.
	_redraw_debt += delta
	if _redraw_debt < 1.0 / Balance.FLAME_REDRAW_HZ:
		return
	_redraw_debt = fmod(_redraw_debt, 1.0 / Balance.FLAME_REDRAW_HZ)
	# The glow breathes with the flame but lags it slightly. Perfectly in
	# phase, the two read as one object being scaled.
	_glow_pulse = 1.0 + sin(_time * 1.9 - 0.6) * 0.13
	queue_redraw()


func _sleep() -> void:
	set_process(false)
	if not _dormant.has(self):
		_dormant.append(self)


## Wakes every sleeping flame the camera can see now. One walk on a cadence
## for the whole field, in place of a tick per flame per frame.
static func wake_the_seen() -> void:
	var index: int = _dormant.size() - 1
	while index >= 0:
		var flame: Flame = _dormant[index]
		if flame == null or not is_instance_valid(flame):
			_dormant.remove_at(index)
		elif flame.is_inside_tree() and flame._on_screen():
			_dormant.remove_at(index)
			flame._seen = true
			flame._show_particles(true)
			flame._cull_left = Balance.PARTICLE_CULL_INTERVAL
			flame.set_process(true)
			flame.queue_redraw()
		index -= 1


## How many flames are asleep, for the gate.
static func dormant_count() -> int:
	return _dormant.size()


## Whether any of this flame could land inside the viewport.
##
## `get_global_transform_with_canvas` gives the position in viewport pixels
## directly, so this costs one transform and four comparisons - against three
## polygons rebuilt from a sine outline, which is what it replaces.
func _on_screen() -> bool:
	return ScreenCull.sees(self, Balance.FLAME_OFFSCREEN_MARGIN)


## **An unseen flame's embers and smoke rest** (2026-09-24). `CPUParticles2D`
## skips its whole update while it is not visible in the tree, so hiding the
## two emitters is what stops a hundred torches on the outskirts being
## simulated for a camera that sees six. Hidden rather than stopped: nothing
## restarts, and a torch panned onto is mid-life rather than starting empty.
func _show_particles(seen: bool) -> void:
	if _embers != null and is_instance_valid(_embers):
		_embers.visible = seen
	if _smoke != null and is_instance_valid(_smoke):
		_smoke.visible = seen


## **The tongues are a ring of shapes shared by every flame** (2026-09-24).
##
## Every flame in view used to rebuild its three tongues in script on each
## redraw - twenty vertices of sines and a colour lerp per slice per layer,
## about 80 us a flame - and on Act X the camera sees fifty-five of them, so
## the flames alone were 4.4 ms of a 30 ms frame. That is the same finding
## as 2026-09-14 (`flame.gd` 5.2 ms), which the redraw clock halved and did
## not end.
##
## Every shape function here is linear in `size`, so one ring of
## `RING_STEPS` phases built once at `RING_SIZE` serves every flame in the
## game through a transform: `size / RING_SIZE` across, and `intensity`
## along the height, which is what a guttering torch's height was. A flame's
## own seed is its offset into the ring, so no two are in step. The colours
## are per layer and per slice and never change, so they are built once too.
## What a redraw costs now is a halo rect and one `draw_mesh`.
##
## **A mesh, not a triangle array** (measured the same evening). A triangle
## array handed to the Compatibility renderer is a new GPU buffer on every
## redraw, and the visual ablation table (`perf_bisect --visuals`) read the
## flames at 2.7-3.6 ms a frame *after* the ring took the script cost
## away. A `Mesh` is uploaded once and drawn from then on; the ring is
## forty-eight of them, three surfaces each, and a flame draws one.
##
## The ring wraps every `RING_PERIOD` seconds of the flame's own clock; the
## sines that shape a tongue are not periodic in that, so a flame jumps a
## little at the wrap - once every few seconds, on a shape that flickers all
## the time, on a random offset per flame. Photographed on `torch_shot` and
## not visible.
const RING_STEPS: int = 48
const RING_PERIOD: float = 4.0
const RING_SIZE: float = 32.0
static var _ring: Dictionary = {}


static func _shape_ring() -> Dictionary:
	if not _ring.is_empty():
		return _ring
	var probe := Flame.new()
	probe.size = RING_SIZE
	probe.intensity = 1.0
	probe._seed = 0.0
	var meshes: Array[ArrayMesh] = []
	var base_colours: Array[Color] = [Balance.FLAME_BODY, Balance.FLAME_MID, Balance.FLAME_CORE]
	var vertices: int = 0
	for step: int in RING_STEPS:
		probe._time = RING_PERIOD * float(step) / float(RING_STEPS)
		var mesh := ArrayMesh.new()
		for index: int in LAYERS.size():
			var layer: Dictionary = LAYERS[index]
			var colour: Color = base_colours[index]
			colour.a = float(layer["alpha"])
			var outline: PackedVector2Array = probe.outline_for(layer, float(index) * 2.7)
			var built: Dictionary = _tongue_geometry(outline, colour)
			var points: PackedVector2Array = built["points"]
			if points.is_empty():
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = points
			arrays[Mesh.ARRAY_COLOR] = built["colours"]
			arrays[Mesh.ARRAY_INDEX] = built["indices"]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			vertices += points.size()
		meshes.append(mesh)
	probe.free()
	_ring = {"meshes": meshes, "vertices": vertices}
	return _ring


## For the gate: the ring, built if it has not been.
static func shape_ring() -> Dictionary:
	return _shape_ring()


## Diagnostic only: `perf_bisect --visuals` switches the halo and the tongues
## off one at a time to price them. Never set by the game.
static var ablate_halo: bool = false
static var ablate_tongues: bool = false


func _draw_measured() -> void:
	if not _lit or intensity <= 0.01:
		return
	# The glow first, so the tongues sit on it. On this node's own additive
	# material, which is what a halo of light is.
	if not ablate_halo:
		var halo: Texture2D = LightKit.falloff_texture()
		var halo_size: Vector2 = halo.get_size() * _glow_base_scale() * _glow_pulse * intensity
		draw_texture_rect(halo, Rect2(Vector2(-halo_size.x * 0.5, -size * 0.55 - halo_size.y * 0.5), halo_size),
			false, Color(Balance.FLAME_MID, Balance.FLAME_GLOW_ALPHA * intensity * (0.86 + 0.14 * _glow_pulse)))
	if ablate_tongues:
		return
	if intensity <= Balance.FLAME_MIN_INTENSITY or size * intensity < Balance.FLAME_MIN_SIZE * 2.0:
		return
	var ring: Dictionary = _shape_ring()
	var meshes: Array[ArrayMesh] = ring["meshes"]
	if meshes.is_empty():
		return
	var step: int = int(fposmod(_time + _seed, RING_PERIOD) / RING_PERIOD * float(RING_STEPS)) % RING_STEPS
	draw_mesh(meshes[step], null, Transform2D(0.0, Vector2(size / RING_SIZE, size / RING_SIZE * intensity), 0.0, Vector2.ZERO))


## One tongue's geometry from its outline: a solid spine fading to a clear
## rim, hotter at the base. `BloodInk`'s rule - one colour for the whole
## shape is what a hard edge is - applied to fire. Returns the arrays rather
## than drawing them, so the ring can keep them.
static func _tongue_geometry(outline: PackedVector2Array, colour: Color) -> Dictionary:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var slices: int = outline.size() / 2
	if slices < 2:
		return {"points": points, "colours": colours, "indices": indices}
	var last: int = outline.size() - 1
	for i: int in slices:
		var left: Vector2 = outline[i]
		var right: Vector2 = outline[last - i]
		var u: float = float(i) / float(slices - 1)
		var heat: Color = colour.lerp(Color(1.0, 1.0, 1.0, colour.a),
			Balance.FLAME_BASE_HEAT * (1.0 - u))
		heat.a = colour.a * (1.0 - Balance.FLAME_TIP_FADE * u * u)
		var clear := Color(heat.r, heat.g, heat.b, 0.0)
		points.append(left)
		points.append((left + right) * 0.5)
		points.append(right)
		colours.append(clear)
		colours.append(heat)
		colours.append(clear)
	for i: int in slices - 1:
		var a: int = i * 3
		indices.append_array([a, a + 1, a + 3, a + 1, a + 4, a + 3,
			a + 1, a + 2, a + 4, a + 2, a + 5, a + 4])
	return {"points": points, "colours": colours, "indices": indices}


## The filled shape of one layer, or an empty array when there is nothing to
## draw.
##
## Split out of `_draw_layer` so a gate can look at it. The bug this exists to
## prevent is invisible from outside: a polygon with the right number of points
## and no area is a canvas-server error, not a wrong-looking flame, and the only
## symptom is a red release build.
##
## **One polygon for the layer, not one per segment.**
##
## This drew a separate quad between each pair of slices, which is the obvious
## way to write it and was the single most expensive thing in the game. Nine
## segments times three layers times forty-eight lit flames is **1,296
## `draw_colored_polygon` calls every frame**, each one a four-point polygon
## rebuilt from scratch - and in the compatibility renderer a draw call is CPU
## work whether or not the GPU cares.
##
## `perf_bisect` measured `flame.gd` at 14.8 ms of a 21.5 ms frame, against a
## ~2.5 ms noise floor that every other script in the game sat at. It is also
## why the quality presets looked innocent: flames are not foliage, lights,
## clouds, particles or shadows, so every `--off=` combination left them running
## and the cost looked like an immovable floor.
##
## The quads shared their edges exactly, so their union is a simple strip and
## the same filled area can be expressed as one polygon: up the left edge, back
## down the right. Identical pixels, nine times fewer draw calls.
func outline_for(layer: Dictionary, phase: float) -> PackedVector2Array:
	var speed: float = float(layer["speed"])
	var lick: float = float(layer["lick"])

	# The whole flame breathes. Offsetting by the layer phase means the core
	# surges a beat before the body does, which reads as the fire drawing breath.
	var breath: float = 1.0 + sin(_time * 1.7 + phase + _seed) * Balance.FLAME_BREATH
	var height: float = size * float(layer["height"]) * breath * intensity
	var base_width: float = size * float(layer["width"]) * 0.52

	# **A flame with no size is not a thin flame, it is an invalid polygon.**
	#
	# Every point below takes its y from `-height * u`, so at height zero all
	# `(segments + 1) * 2` of them land on one horizontal line: the right number
	# of vertices enclosing no area at all. Godot answers
	# `ERROR: Invalid polygon data, triangulation failed`, and an error line
	# fails a release build even on a clean exit.
	#
	# `intensity` reaches zero legitimately - a torch guttering out ramps its
	# strength down through it - so this is an ordinary frame in an ordinary
	# run, and that is exactly why it was intermittent enough to survive this
	# long. It failed a release on 2026-09-10 having never failed one before.
	#
	# Guarded on intensity as well as on the computed size, because "height is
	# above zero" is not the same as "this shape has area": at intensity 0.005 a
	# torch still produced twenty points enclosing 0.15 square pixels, which is
	# degenerate in every sense that matters and was still passing a height
	# check written in absolute units.
	if intensity <= Balance.FLAME_MIN_INTENSITY \
			or height <= Balance.FLAME_MIN_SIZE \
			or base_width <= Balance.FLAME_MIN_SIZE:
		return PackedVector2Array()

	var segments: int = maxi(Balance.FLAME_SEGMENTS, 3)
	var outline: PackedVector2Array = PackedVector2Array()
	outline.resize((segments + 1) * 2)
	var last: int = outline.size() - 1
	for i: int in segments + 1:
		var u: float = float(i) / float(segments)
		var x: float = _centre_at(u, speed, lick, phase, height)
		var half: float = _half_width_at(u, base_width, speed, phase)
		var y: float = -height * u
		outline[i] = Vector2(x - half, y)
		outline[last - i] = Vector2(x + half, y)
	return outline


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

	var additive: CanvasItemMaterial = LightKit.additive_material()
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


## `FrameProfile` bucket "flame": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"flame", started)


## `FrameProfile` bucket "d_flame": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_flame", started)
