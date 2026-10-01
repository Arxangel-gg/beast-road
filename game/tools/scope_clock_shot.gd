extends Node

## Photographs the breather's clock in the Town and on Yuri (owner, 2026-10-01:
## *"A countdown progress bar needs to also be visible in the town and beast
## scope views during preparation"*).
##
##   shot_offscreen.sh <profile> 1920 1080 res://tools/scope_clock_shot.tscn
##
## Two frames, the Town then Yuri, each in a timed breather with eighteen
## seconds left. Written to `user://scope_clock_<scope>.png`. Diagnostic only.

var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261001)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 30:
		await get_tree().process_frame
	if _run.battlefield != null and _run.battlefield.wave_director != null:
		_run.battlefield.wave_director.stop()
	RunState.set_phase(RunState.Phase.PREPARATION)
	for scope: int in [int(GameDirector.Scope.TOWN), int(GameDirector.Scope.BEAST)]:
		_run.switch_scope(scope as GameDirector.Scope)
		for _frame: int in 20:
			EventBus.preparation_changed.emit(18.0, true)
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		EventBus.preparation_changed.emit(18.0, true)
		await RenderingServer.frame_post_draw
		var name: String = "town" if scope == int(GameDirector.Scope.TOWN) else "beast"
		var path: String = ProjectSettings.globalize_path("user://scope_clock_%s.png" % name)
		get_viewport().get_texture().get_image().save_png(path)
		print("[scope-clock] %s -> %s (clock %s)" % [name, path,
			"shown" if _run.hud.scope_clock() != null and _run.hud.scope_clock().visible else "hidden"])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
