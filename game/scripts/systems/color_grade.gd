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
	_apply(_current)


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


## `FrameProfile` bucket "p_color_grade": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_color_grade", started)
