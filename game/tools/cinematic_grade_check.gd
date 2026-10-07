extends Node

## **The cinematic half of the grade** (owner, 2026-10-07). Headless never
## compiles a shader, so the picture is `grade_shot`'s; this holds the driver:
## the weather hazes and heats the air and nothing does underground or on the
## menu, a boss tightens the frame and lets go, a heavy blow near the camera
## kicks the lens fringe and a light or distant one does not, the kick falls
## away, the flash comfort takes it to nothing - and the shader carries every
## uniform the driver sets.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	var grade := ColorGrade.new()
	add_child(grade)
	await get_tree().process_frame
	var was_active: bool = GameDirector.run_active
	var was_phase: int = RunState.phase
	var was_weather: String = RunState.weather_id
	var was_sheltered: bool = RunState.wind_sheltered
	var was_dark: float = DayNight.darkness
	_test_the_weather()
	_test_a_boss(grade)
	_test_a_heavy_blow(grade)
	_test_the_shader_carries_it()
	GameDirector.run_active = was_active
	RunState.phase = was_phase as RunState.Phase
	RunState.weather_id = was_weather
	RunState.wind_sheltered = was_sheltered
	DayNight.darkness = was_dark
	_finish()


func _test_the_weather() -> void:
	DayNight.darkness = 0.0
	GameDirector.run_active = false
	RunState.weather_id = "marsh_mist"
	_check(float(ColorGrade.wanted_weather()["haze"]) == 0.0, "the menu is hazed by a weather it has no sky for")
	GameDirector.run_active = true
	RunState.wind_sheltered = false
	var mist: Dictionary = ColorGrade.wanted_weather()
	_check(float(mist["haze"]) > 0.05, "a marsh mist laid no haze (%.3f)" % float(mist["haze"]))
	_check(float(mist["haze"]) <= Balance.GRADE_HAZE_MAX, "a haze past its ceiling")
	RunState.weather_id = "clear"
	_check(float(ColorGrade.wanted_weather()["haze"]) < 0.01, "a clear sky laid a haze")
	_check(float(ColorGrade.wanted_weather()["heat"]) == 0.0, "a mild clear day bent the air")
	RunState.weather_id = "heatwave"
	var hot: float = float(ColorGrade.wanted_weather()["heat"])
	_check(hot > 0.0, "a heatwave bent no air")
	DayNight.darkness = 1.0
	_check(float(ColorGrade.wanted_weather()["heat"]) < hot, "a heatwave's air bends as hard at midnight")
	RunState.weather_id = "thunderstorm"
	var night_haze: Color = ColorGrade.wanted_weather()["colour"] as Color
	DayNight.darkness = 0.0
	var day_haze: Color = ColorGrade.wanted_weather()["colour"] as Color
	_check(night_haze.get_luminance() < day_haze.get_luminance() - 0.1,
		"a night haze is no darker than a day's")
	RunState.wind_sheltered = true
	_check(float(ColorGrade.wanted_weather()["haze"]) == 0.0, "a rift is hazed by a sky it cannot see")
	RunState.wind_sheltered = false


func _test_a_boss(grade: ColorGrade) -> void:
	GameDirector.run_active = true
	RunState.phase = RunState.Phase.ROAD_BATTLE
	for _i: int in 60:
		grade._ease_the_moments(1.0 / 30.0)
	_check(grade.boss_share() < 0.01, "an ordinary wave tightened the frame")
	RunState.phase = RunState.Phase.BOSS
	for _i: int in int(Balance.GRADE_BOSS_EASE * 30.0) + 4:
		grade._ease_the_moments(1.0 / 30.0)
	_check(grade.boss_share() > 0.99, "a boss fight tightened the frame to %.2f" % grade.boss_share())
	_check(grade.fringe() > 0.0, "a boss fight breathed no fringe")
	RunState.phase = RunState.Phase.PREPARATION
	for _i: int in int(Balance.GRADE_BOSS_EASE * 30.0) + 4:
		grade._ease_the_moments(1.0 / 30.0)
	_check(grade.boss_share() < 0.01, "the frame stayed tight after the boss")


func _test_a_heavy_blow(grade: ColorGrade) -> void:
	var camera := Camera2D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = Vector2(500.0, 500.0)
	camera.force_update_scroll()
	var spot: Vector2 = camera.get_screen_center_position()
	EventBus.camera_impact.emit(spot, Balance.IMPACT_SHAKE_HEAVY * 0.5)
	_check(grade.fringe() == 0.0, "a light blow kicked the lens")
	EventBus.camera_impact.emit(spot + Vector2(Balance.IMPACT_SHAKE_REACH * 1.2, 0.0), 1.0)
	_check(grade.fringe() == 0.0, "a blow beyond the camera's reach kicked the lens")
	EventBus.camera_impact.emit(spot, 1.0)
	var kicked: float = grade.fringe()
	_check(kicked > 0.0, "a heavy blow at the camera kicked no fringe")
	var held: Variant = MetaState.settings.get(UserSettings.FLASH_KEY, 1.0)
	MetaState.settings[UserSettings.FLASH_KEY] = 0.0
	_check(grade.fringe() == 0.0, "the lens jumped for a player who asked for no flashes")
	MetaState.settings[UserSettings.FLASH_KEY] = held
	for _i: int in int(Balance.GRADE_FRINGE_SECONDS * 30.0) + 3:
		grade._ease_the_moments(1.0 / 30.0)
	_check(grade.fringe() == 0.0, "a kicked fringe outlived its moment")
	camera.queue_free()


func _test_the_shader_carries_it() -> void:
	var shader: String = FileAccess.get_file_as_string("res://scripts/shaders/color_grade.gdshader")
	var driver: String = FileAccess.get_file_as_string("res://scripts/systems/color_grade.gd")
	for name: String in ["shoulder", "split", "split_shadow", "split_highlight", "haze",
			"haze_colour", "heat", "fringe", "boss"]:
		var declared := RegEx.create_from_string("uniform [a-z0-9]+ " + name + "[ :;=]")
		_check(declared.search(shader) != null, "the grade shader has no uniform %s" % name)
		_check(driver.contains("set_shader_parameter(\"%s\"" % name),
			"the grade driver never sets %s" % name)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("cinematic_grade_check: " + message)


func _finish() -> void:
	if _failures == 0:
		print("cinematic_grade_check: PASS (%d checks)" % _checks)
	else:
		print("cinematic_grade_check: FAIL (%d of %d)" % [_failures, _checks])
	for child: Node in get_children():
		child.queue_free()
	for _i: int in 10:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)
