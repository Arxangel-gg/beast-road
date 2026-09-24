class_name TowerAura
extends CPUParticles2D

## What a tower's element does to the air around it (owner brief,
## 2026-09-12): embers off a fire tower, drips and snow off a water one,
## grit and pebbles off earth, sparks and gusts off air. One particle node a
## tower, tuned by element and scaled a little by level, so a road of towers
## reads as a road of *different* towers before any of them fires.
##
## CPU particles rather than GPU: the compatibility renderer this project
## ships on treats them the same, and a few dozen small emitters is nothing.

var element: int = 0
var level: int = 1
## Which air this tower has (owner brief, 2026-09-14: effects catered per
## tower). `TowerData.Ambient.ELEMENT` is the element's own default above.
var kind: int = TowerData.Ambient.ELEMENT
## The tower's shot colour, for the airs that carry a colour (motes, glints,
## sparks, frost). Transparent means the air's own colour.
var tint: Color = Color(0.0, 0.0, 0.0, 0.0)

var _built: int = TowerData.Ambient.ELEMENT
## The screen cull's clock and its last answer (2026-09-24).
var _cull_left: float = 0.0
var _seen: bool = true


func _ready() -> void:
	name = "Aura"
	# Staggered, so forty towers do not all ask on the same frame.
	_cull_left = randf() * Balance.PARTICLE_CULL_INTERVAL
	z_index = 1
	z_as_relative = true
	local_coords = false
	var chosen: int = kind
	if chosen == TowerData.Ambient.ELEMENT:
		match element:
			TowerData.Element.FIRE:
				chosen = TowerData.Ambient.EMBERS
			TowerData.Element.WATER:
				chosen = TowerData.Ambient.DRIPS
			TowerData.Element.EARTH:
				chosen = TowerData.Ambient.GRIT
			_:
				chosen = TowerData.Ambient.GUSTS
	match chosen:
		TowerData.Ambient.EMBERS:
			_embers()
		TowerData.Ambient.SMOKE:
			_smoke()
		TowerData.Ambient.DRIPS:
			_drips()
		TowerData.Ambient.FROST:
			_frost()
		TowerData.Ambient.GRIT:
			_grit()
		TowerData.Ambient.MOTES:
			_motes()
		TowerData.Ambient.SPARKS:
			_sparks()
		TowerData.Ambient.GLINTS:
			_glints()
		TowerData.Ambient.NONE:
			_built = TowerData.Ambient.NONE
			amount = 1
			emitting = false
			return
		_:
			_gusts()
	amount = maxi(int(float(amount) * (1.0 + 0.12 * float(level - 1))), 1)
	emitting = Graphics.particle_scale() > 0.0


## The air this tower ended up with, for the gate: the kind actually built.
func built_kind() -> int:
	return _built


## The authored colour or the air's own.
func _tinted(fallback: Color, alpha: float) -> Color:
	if tint.a > 0.0:
		return Color(tint.r, tint.g, tint.b, alpha)
	return Color(fallback.r, fallback.g, fallback.b, alpha)


## Smoke: soft grey puffs rising off the crown, growing as they thin.
func _smoke() -> void:
	_built = TowerData.Ambient.SMOKE
	amount = 9
	lifetime = 2.4
	randomness = 0.5
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 10.0
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN)
	direction = Vector2(0.0, -1.0)
	spread = 18.0
	gravity = Vector2(0.0, -18.0)
	initial_velocity_min = 10.0
	initial_velocity_max = 22.0
	scale_amount_min = 2.0
	scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.52, 0.5, 0.0))
	ramp.set_color(1, Color(0.4, 0.38, 0.38, 0.0))
	ramp.add_point(0.3, _tinted(Color(0.6, 0.57, 0.55), 0.45))
	color_ramp = ramp


## Frost: a slow fall of pale motes that hang and sparkle round the crown.
func _frost() -> void:
	_built = TowerData.Ambient.FROST
	amount = 12
	lifetime = 2.6
	randomness = 0.8
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 30.0
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN * 0.8)
	direction = Vector2(0.0, 1.0)
	spread = 60.0
	gravity = Vector2(0.0, 9.0)
	initial_velocity_min = 2.0
	initial_velocity_max = 8.0
	scale_amount_min = 0.9
	scale_amount_max = 1.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.97, 1.0, 0.0))
	ramp.set_color(1, Color(0.8, 0.92, 1.0, 0.0))
	ramp.add_point(0.5, _tinted(Color(0.95, 1.0, 1.0), 0.95))
	color_ramp = ramp


## Motes: the tower's own colour hovering and rising slowly round its body.
func _motes() -> void:
	_built = TowerData.Ambient.MOTES
	amount = 12
	lifetime = 2.2
	randomness = 0.7
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(30.0, 34.0)
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN * 0.5)
	direction = Vector2(0.0, -1.0)
	spread = 30.0
	gravity = Vector2(0.0, -14.0)
	initial_velocity_min = 4.0
	initial_velocity_max = 12.0
	scale_amount_min = 1.0
	scale_amount_max = 2.0
	var ramp := Gradient.new()
	var tone: Color = _tinted(Color(0.6, 0.9, 0.6), 1.0)
	ramp.set_color(0, Color(tone, 0.0))
	ramp.set_color(1, Color(tone, 0.0))
	ramp.add_point(0.4, Color(tone.lerp(Color.WHITE, 0.3), 0.9))
	color_ramp = ramp


## Sparks: quick bright specks jumping off the crown and falling back.
func _sparks() -> void:
	_built = TowerData.Ambient.SPARKS
	amount = 10
	lifetime = 0.7
	randomness = 0.9
	explosiveness = 0.15
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 8.0
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN)
	direction = Vector2(0.0, -1.0)
	spread = 70.0
	gravity = Vector2(0.0, 220.0)
	initial_velocity_min = 60.0
	initial_velocity_max = 130.0
	scale_amount_min = 0.7
	scale_amount_max = 1.4
	var ramp := Gradient.new()
	var tone: Color = _tinted(Balance.LIGHTNING_COLOUR, 1.0)
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	ramp.set_color(1, Color(tone, 0.0))
	ramp.add_point(0.3, Color(tone.lerp(Color.WHITE, 0.4), 0.95))
	color_ramp = ramp


## Glints: a pinpoint that flares and is gone, here and there on the crown.
func _glints() -> void:
	_built = TowerData.Ambient.GLINTS
	amount = 4
	lifetime = 0.9
	randomness = 1.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(22.0, 30.0)
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN * 0.75)
	direction = Vector2(0.0, -1.0)
	spread = 10.0
	gravity = Vector2.ZERO
	initial_velocity_min = 0.0
	initial_velocity_max = 2.0
	scale_amount_min = 1.4
	scale_amount_max = 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	scale_amount_curve = curve
	var ramp := Gradient.new()
	var tone: Color = _tinted(Color(1.0, 0.98, 0.9), 1.0)
	ramp.set_color(0, Color(tone, 0.0))
	ramp.set_color(1, Color(tone, 0.0))
	ramp.add_point(0.5, Color(tone.lerp(Color.WHITE, 0.6), 1.0))
	color_ramp = ramp


## Embers: born at the crown, rising, drifting, cooling from white to red.
func _embers() -> void:
	_built = TowerData.Ambient.EMBERS
	amount = 14
	lifetime = 1.6
	explosiveness = 0.0
	randomness = 0.6
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 14.0
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN)
	direction = Vector2(0.0, -1.0)
	spread = 28.0
	gravity = Vector2(0.0, -34.0)
	initial_velocity_min = 18.0
	initial_velocity_max = 44.0
	scale_amount_min = 1.2
	scale_amount_max = 2.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	ramp.set_color(1, Color(0.85, 0.25, 0.1, 0.0))
	ramp.add_point(0.35, Color(1.0, 0.6, 0.2, 0.95))
	color_ramp = ramp


## Drips and flakes: born over the tower, falling slowly, fading.
func _drips() -> void:
	_built = TowerData.Ambient.DRIPS
	amount = 10
	lifetime = 2.2
	randomness = 0.7
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(22.0, 6.0)
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN * 0.9)
	direction = Vector2(0.0, 1.0)
	spread = 12.0
	gravity = Vector2(0.0, 22.0)
	initial_velocity_min = 4.0
	initial_velocity_max = 14.0
	scale_amount_min = 1.0
	scale_amount_max = 2.2
	angular_velocity_min = -60.0
	angular_velocity_max = 60.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.95, 1.0, 0.0))
	ramp.set_color(1, Color(0.7, 0.9, 1.0, 0.0))
	ramp.add_point(0.25, Color(0.9, 0.98, 1.0, 0.9))
	color_ramp = ramp


## Grit: pebbles and dust shaken loose, falling off the flanks.
func _grit() -> void:
	_built = TowerData.Ambient.GRIT
	amount = 8
	lifetime = 1.1
	randomness = 0.9
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(26.0, 12.0)
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN * 0.5)
	direction = Vector2(0.0, 1.0)
	spread = 40.0
	gravity = Vector2(0.0, 140.0)
	initial_velocity_min = 6.0
	initial_velocity_max = 26.0
	scale_amount_min = 1.0
	scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.6, 0.52, 0.42, 0.9))
	ramp.set_color(1, Color(0.45, 0.4, 0.34, 0.0))
	color_ramp = ramp


## Gusts and sparks: streaks curling round the tower, quick and pale.
func _gusts() -> void:
	_built = TowerData.Ambient.GUSTS
	amount = 12
	lifetime = 0.9
	randomness = 0.5
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = 30.0
	position = Vector2(0.0, -Balance.TOWER_AURA_CROWN * 0.7)
	direction = Vector2(1.0, 0.0)
	spread = 180.0
	gravity = Vector2.ZERO
	orbit_velocity_min = 0.6
	orbit_velocity_max = 1.1
	initial_velocity_min = 30.0
	initial_velocity_max = 70.0
	scale_amount_min = 0.8
	scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.9, 1.0, 0.0))
	ramp.set_color(1, Color(0.75, 0.8, 1.0, 0.0))
	ramp.add_point(0.4, Color(0.95, 0.97, 1.0, 0.85))
	color_ramp = ramp


## **An air the camera cannot see rests** (2026-09-24): forty towers' emitters
## were simulated every frame for a camera that sees eight. Hidden rather
## than stopped, so a tower panned onto is mid-air rather than starting empty.
func _process_measured(delta: float) -> void:
	_cull_left -= delta
	if _cull_left > 0.0:
		return
	_cull_left = Balance.PARTICLE_CULL_INTERVAL
	var seen: bool = ScreenCull.sees(self, Balance.PARTICLE_CULL_MARGIN)
	if seen != _seen:
		_seen = seen
		visible = seen


## `FrameProfile` bucket "aura": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"aura", started)
