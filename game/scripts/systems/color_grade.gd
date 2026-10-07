class_name ColorGrade
extends CanvasLayer

## The grade over the whole frame: one pass, per region, per hour. See
## `color_grade.gdshader`. Sits under the HUD and over every scope, so the
## interface stays the interface and the world is what gets the look.
##
## The region's numbers come off its `TerrainData` (`grade_tint`,
## `grade_saturation`, `grade_contrast`, `grade_lift`, `grade_vignette`) and
## the hour off `DayNight.darkness`, eased so a scope change or an act
## boundary is a cross-fade rather than a cut. Off when the settings say so
## (`Graphics.grade_enabled`), which is also how a headless gate never pays
## for a screen read.

var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _wanted: Dictionary = {}
var _current: Dictionary = {}
var _clock: float = 0.0
## **The moments** (2026-10-07): how far into a boss fight the frame has
## tightened, the fringe a heavy blow kicked, and the weather's haze and heat,
## each eased so nothing about the picture ever cuts.
var _boss: float = 0.0
var _fringe_kick: float = 0.0
var _haze: float = 0.0
var _haze_colour: Color = Color(0.7, 0.72, 0.76)
var _heat: float = 0.0
## `grade_shot`'s one seam: the cinematic half switched off, so a photograph can
## set it beside the grade it was added to. Nothing in the game writes it.
static var cinematic_off: bool = false


func _ready() -> void:
	name = "ColorGrade"
	_rect = ColorRect.new()
	_rect.name = "Grade"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/shaders/color_grade.gdshader")
	_rect.material = _material
	add_child(_rect)
	_current = _neutral()
	_wanted = _current.duplicate()
	_apply(_current)
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void: refresh())
	EventBus.scope_changed.connect(func(_scope: int) -> void: refresh())
	EventBus.camera_impact.connect(_on_impact)
	refresh()


func _neutral() -> Dictionary:
	return {"tint": Color.WHITE, "saturation": 1.0, "contrast": 1.0, "lift": 0.0,
		"vignette": Balance.GRADE_VIGNETTE}


## Reads the region's grade. The menu and the results have no region and get
## the neutral grade with a touch more vignette.
func refresh() -> void:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id) if GameDirector.run_active else null
	if terrain == null:
		_wanted = _neutral()
		return
	_wanted = {"tint": terrain.grade_tint, "saturation": terrain.grade_saturation,
		"contrast": terrain.grade_contrast, "lift": terrain.grade_lift,
		"vignette": terrain.grade_vignette}


func _process_measured(delta: float) -> void:
	_clock += delta
	if _rect == null:
		return
	var on: bool = Graphics.grade_enabled()
	_rect.visible = on
	if not on:
		return
	var ease_amount: float = 1.0 - exp(-Balance.GRADE_EASE * delta)
	_current["tint"] = (_current["tint"] as Color).lerp(_wanted["tint"] as Color, ease_amount)
	for key: String in ["saturation", "contrast", "lift", "vignette"]:
		_current[key] = lerpf(float(_current[key]), float(_wanted[key]), ease_amount)
	_ease_the_moments(delta)
	_apply(_current)


## **A heavy blow kicks a lens fringe** (2026-10-07): the blows that shake the
## camera hard, weighed by how near they land to what it watches - the camera's
## own falloff - and turned down with the screen flashes, because a player who
## asked for fewer flashes did not ask for the lens to jump.
func _on_impact(at: Vector2, power: float) -> void:
	if power < Balance.IMPACT_SHAKE_HEAVY:
		return
	var camera: Camera2D = get_viewport().get_camera_2d() if get_viewport() != null else null
	if camera == null:
		return
	var near: float = clampf(1.0 - camera.get_screen_center_position().distance_to(at)
		/ maxf(Balance.IMPACT_SHAKE_REACH, 1.0), 0.0, 1.0)
	_fringe_kick = maxf(_fringe_kick, clampf(power, 0.0, 1.0) * near * near)


## What the moments want, eased toward: a boss fight tightens the frame, the
## weather hazes and heats the air, and a kicked fringe falls away.
func _ease_the_moments(delta: float) -> void:
	var fighting_a_boss: bool = GameDirector.run_active and (RunState.phase == RunState.Phase.BOSS
		or RunState.phase == RunState.Phase.FINAL_ASCENT)
	_boss = move_toward(_boss, 1.0 if fighting_a_boss else 0.0, delta / Balance.GRADE_BOSS_EASE)
	_fringe_kick = maxf(0.0, _fringe_kick - delta / Balance.GRADE_FRINGE_SECONDS)
	var weather: Dictionary = wanted_weather()
	var ease_amount: float = 1.0 - exp(-Balance.GRADE_EASE * delta)
	_haze = lerpf(_haze, float(weather["haze"]), ease_amount)
	_haze_colour = _haze_colour.lerp(weather["colour"] as Color, ease_amount)
	_heat = lerpf(_heat, float(weather["heat"]), ease_amount)


## The haze and the heat the sky over this road asks for. Nothing at all on the
## menu and underground, where there is no sky: a rift has no weather.
static func wanted_weather() -> Dictionary:
	var none: Dictionary = {"haze": 0.0, "colour": Color(0.7, 0.72, 0.76), "heat": 0.0}
	if not GameDirector.run_active or RunState.wind_sheltered:
		return none
	var sky: WeatherData = ContentDB.weather(RunState.weather_id)
	if sky == null:
		return none
	var dark: float = clampf(DayNight.darkness, 0.0, 1.0)
	var colour: Color = Balance.GRADE_HAZE_COLOUR * sky.tint
	colour = colour.lerp(Balance.GRADE_HAZE_NIGHT_COLOUR, dark)
	var haze: float = sky.gloom * Balance.GRADE_HAZE_PER_GLOOM
	haze += clampf(RunState.flood, 0.0, 1.0) * Balance.GRADE_HAZE_FLOOD
	var heat: float = clampf((sky.temperature - Balance.GRADE_HEAT_FROM) / Balance.GRADE_HEAT_SPAN,
		0.0, 1.0) * Balance.GRADE_HEAT_SHIMMER * (1.0 - dark * 0.7)
	return {"haze": minf(haze, Balance.GRADE_HAZE_MAX), "colour": colour, "heat": heat}


## The fringe the lens wears this frame: a boss's steady breath of it, plus a
## kick, turned down with the flashes.
func fringe() -> float:
	var kicked: float = (_boss * Balance.GRADE_BOSS_FRINGE + _fringe_kick * Balance.GRADE_FRINGE_KICK)
	var comfort: float = JuiceDirector.flash_scale()
	return kicked * comfort


func boss_share() -> float:
	return _boss


func haze_share() -> float:
	return _haze


func heat_share() -> float:
	return _heat


func _apply(grade: Dictionary) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("tint", grade["tint"])
	_material.set_shader_parameter("saturation", grade["saturation"])
	_material.set_shader_parameter("contrast", grade["contrast"])
	_material.set_shader_parameter("lift", grade["lift"])
	_material.set_shader_parameter("vignette", grade["vignette"])
	_material.set_shader_parameter("night", clampf(DayNight.darkness, 0.0, 1.0) * Balance.GRADE_NIGHT_STRENGTH)
	# The bloom (2026-09-24), the night's mostly: the threshold falls with the
	# dark, so by day only what outshines a sunlit field blooms.
	var dark: float = clampf(DayNight.darkness, 0.0, 1.0)
	_material.set_shader_parameter("bloom", lerpf(Balance.BLOOM_STRENGTH_DAY,
		Balance.BLOOM_STRENGTH_NIGHT, dark) if Graphics.bloom() else 0.0)
	_material.set_shader_parameter("bloom_threshold", lerpf(Balance.BLOOM_THRESHOLD_DAY,
		Balance.BLOOM_THRESHOLD_NIGHT, dark))
	_material.set_shader_parameter("now", _clock)
	# The cinematic half (2026-10-07).
	var tint: Color = grade["tint"] as Color
	var on: float = 0.0 if cinematic_off else 1.0
	_material.set_shader_parameter("shoulder", Balance.GRADE_SHOULDER * on)
	_material.set_shader_parameter("split", Balance.GRADE_SPLIT * on)
	_material.set_shader_parameter("split_shadow",
		Balance.GRADE_SPLIT_SHADOW.lerp(Balance.GRADE_SPLIT_SHADOW_NIGHT, dark))
	_material.set_shader_parameter("split_highlight", Balance.GRADE_SPLIT_HIGHLIGHT.lerp(
		Color(tint.r, tint.g, tint.b), Balance.GRADE_SPLIT_REGION))
	_material.set_shader_parameter("haze", _haze * on)
	_material.set_shader_parameter("haze_colour", _haze_colour)
	_material.set_shader_parameter("heat", _heat * on)
	_material.set_shader_parameter("fringe", fringe() * on)
	_material.set_shader_parameter("boss", _boss * on)


## `FrameProfile` bucket "p_color_grade": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_color_grade", started)
