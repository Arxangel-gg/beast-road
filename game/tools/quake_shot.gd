extends Node

## Photographs the earth breaking on the real field: the split as it hums, the
## break, the crests rolling out and what they leave. `_draw` and a screen
## shader, which headless never draws. Diagnostic only, never a gate: frames
## land in `--out=<dir>` (or `user://`) as `quake_<when>.png`.
##
##   tools/perf_offscreen.sh <profile> res://tools/quake_shot.tscn --out=<dir>

var _out: String = "user://"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=").trim_suffix("/") + "/"
	MetaState.hold_saves()
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	if run.hud != null:
		run.hud.visible = false
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	var sky: WeatherSky = field.sky()
	sky.events_enabled = false
	var hero: Hero = field.hero
	hero.global_position = Battlefield.lane_vector(0) * 480.0
	var middle: Vector2 = hero.global_position + Vector2(-60.0, -40.0)
	if field.fog() != null:
		field.fog().reveal_all()
	var cam := field.camera as Camera2D
	if cam != null:
		cam.set_process(false)
		cam.set_physics_process(false)
		cam.zoom = Vector2(0.55, 0.55)
		cam.global_position = middle
	for _f: int in 30:
		await get_tree().process_frame
	sky.quake(1.0, ["quake"], middle)
	for when: int in [8, 40, 75, 110, 150, 220, 320]:
		await _shoot_at(when)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	get_tree().quit(0)


var _frames: int = 0


func _shoot_at(frame: int) -> void:
	while _frames < frame:
		await get_tree().process_frame
		_frames += 1
	var path: String = _out + "quake_%03d.png" % frame
	get_viewport().get_texture().get_image().save_png(path)
	print("[quake] %d -> %s" % [frame, ProjectSettings.globalize_path(path)])
