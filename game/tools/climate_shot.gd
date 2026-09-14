extends Node

## Photographs the ground's own weather on the real field: a hot spot as
## three fire towers would make it, cold ground across the road, a soaked
## patch that puddles, and then the same frame with the debug view on.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/climate_shot.tscn
##
## The overlay is a shader and the puddles are the flood's shader reading the
## climate's picture - neither can be looked at headless. Each frame lands in
## `user://` as `climate_shot_<what>.png`.

var _field: Battlefield = null
var _climate: Climate = null


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	_field = run.get("battlefield") as Battlefield
	_climate = _field.climate() if _field != null else null
	if _climate == null or _field.hero == null or _field.sky() == null:
		push_error("[climate] no battlefield, hero or climate")
		get_tree().quit(1)
		return
	_field.sky().events_enabled = false
	var hero: Hero = _field.hero
	hero.global_position = Battlefield.lane_vector(0) * 480.0
	var at: Vector2 = hero.global_position
	# Three fire towers' worth of heat beside the road, cold across from it,
	# and a soaked patch below that puddles.
	for _i: int in 3:
		_climate.add_heat(at + Vector2(420.0, -140.0), 14.0)
	_climate.add_heat(at + Vector2(-560.0, 40.0), -18.0)
	_climate.add_wet(at + Vector2(60.0, 440.0), 0.9)
	for _t: int in 8:
		_climate._tick(Balance.CLIMATE_TICK)
	await _shoot("climate", 30)
	# What the picture and the water actually hold, for the log.
	var sky: WeatherSky = _field.sky()
	var sheen: ColorRect = sky.get("_sheen") as ColorRect
	var material: ShaderMaterial = sky.get("_sheen_material") as ShaderMaterial
	var image: Image = _climate.get("_image") as Image
	var wet_cell: int = _climate.cell_of(at + Vector2(60.0, 440.0))
	var hot_cell: int = _climate.cell_of(at + Vector2(420.0, -140.0))
	print("[climate] wettest=%.2f sheen.visible=%s level=%s wet_tex=%s overlay.material=%s overlay.modulate=%s z=%d" % [
		_climate.wettest(), str(sheen.visible if sheen != null else "none"),
		str(material.get_shader_parameter("level") if material != null else "none"),
		str(material.get_shader_parameter("wet_tex") if material != null else "none"),
		str(_climate.get("_overlay").material), str(_climate.get("_overlay").modulate), _climate.z_index])
	print("[climate] wet cell pixel=%s hot cell pixel=%s across=%d picture_dirty=%s" % [
		str(image.get_pixel(wet_cell % _climate.across(), floori(float(wet_cell) / float(_climate.across())))),
		str(image.get_pixel(hot_cell % _climate.across(), floori(float(hot_cell) / float(_climate.across())))),
		_climate.across(), str(_climate.get("_picture_dirty"))])
	_climate.toggle_debug()
	await _shoot("climate_debug", 10)
	_climate.toggle_debug()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _shoot(what: String, settle_frames: int) -> void:
	for _f: int in settle_frames:
		await get_tree().process_frame
	var path: String = "user://climate_shot_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("[climate] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
