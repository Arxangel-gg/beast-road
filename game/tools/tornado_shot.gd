extends Node

## Photographs a funnel being born, standing and coming apart, two of them
## turning opposite ways, on the real field (owner, 2026-10-07: the V of the
## debris sheet sat below the column and turned whichever way it liked). The
## funnel is `_draw`, which headless never draws. Diagnostic only, never a
## gate: each frame lands in `--out=<dir>` (or `user://`) as
## `tornado_<what>.png`.
##
##   tools/perf_offscreen.sh <profile> res://tools/tornado_shot.tscn --out=<dir>

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
	var hero: Hero = field.hero
	hero.global_position = Battlefield.lane_vector(0) * 480.0
	var middle: Vector2 = hero.global_position + Vector2(0.0, -120.0)
	if field.fog() != null:
		field.fog().reveal_all()
	var cam := field.camera as Camera2D
	if cam != null:
		cam.set_process(false)
		cam.set_physics_process(false)
		cam.zoom = Vector2(0.62, 0.62)
		cam.global_position = middle
	# Two funnels, one born where each turns its own way, held still so the
	# pictures are of the funnel and not of where it wandered.
	var left: Tornado = sky.spawn_tornado(middle + Vector2(-380.0, 260.0),
		middle + Vector2(-380.0, -2000.0), 30.0)
	var right: Tornado = sky.spawn_tornado(middle + Vector2(380.0, 260.0),
		middle + Vector2(390.0, -2000.0), 30.0)
	for funnel: Tornado in [left, right]:
		funnel.wander = 0.0
		funnel.set_process(false)
	print("[tornado] turning: left %d, right %d" % [int(left.turning), int(right.turning)])
	await _step([left, right], 0.3)
	await _shoot("born_0_3")
	await _step([left, right], 0.6)
	await _shoot("born_0_9")
	await _step([left, right], 2.4)
	await _shoot("standing")
	await _step([left, right], 0.05)
	await _shoot("standing_next")
	for funnel: Tornado in [left, right]:
		funnel.seconds_left = 0.0
	await _step([left, right], 0.5)
	await _shoot("dying")
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	get_tree().quit(0)


## Runs the funnels by hand, a sixtieth of a second at a time, held in place.
func _step(funnels: Array, seconds: float) -> void:
	var steps: int = int(round(seconds * 60.0))
	for _i: int in steps:
		for funnel: Tornado in funnels:
			if not is_instance_valid(funnel):
				continue
			var at: Vector2 = funnel.at
			funnel._process(1.0 / 60.0)
			if is_instance_valid(funnel):
				funnel.at = at
				funnel.position = at
		await get_tree().process_frame


func _shoot(what: String) -> void:
	for _f: int in 2:
		await get_tree().process_frame
	var path: String = _out + "tornado_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("[tornado] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
