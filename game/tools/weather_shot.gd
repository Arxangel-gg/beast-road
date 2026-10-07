extends Node

## Renders the battlefield under one weather, so it can be looked at.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/weather_shot.tscn -- --weather=snowfall --cover=0.8
##
## Weather rolls per act and is otherwise unreachable without playing to it,
## which is how it shipped invisible for as long as it did.

func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, 271828182)
	GameDirector.run_active = true
	var wanted: String = "downpour"
	var cover: float = 0.0
	# `--front=2.5`: clear the sky first and catch the weather coming in as a
	# front, this many seconds after it began (`WEATHER_FRONT_SPEED`).
	var front: float = -1.0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--weather="):
			wanted = argument.split("=")[1]
		elif argument.begins_with("--cover="):
			cover = float(argument.split("=")[1])
		elif argument.begins_with("--front="):
			front = float(argument.split("=")[1])
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	if run.hud != null:
		run.hud.visible = false
	var veil_node: WeatherVeil = run.battlefield.get_node_or_null("WeatherVeil")
	if front >= 0.0 and veil_node != null:
		RunState.weather_id = "clear"
		EventBus.weather_changed.emit("clear")
		for _f: int in 400:
			await get_tree().process_frame
		RunState.weather_id = wanted
		EventBus.weather_changed.emit(wanted)
		var since: float = 0.0
		while since < front:
			await get_tree().process_frame
			since += get_process_delta_time()
	else:
		RunState.weather_id = wanted
		EventBus.weather_changed.emit(wanted)
		# Let the veil fade all the way in rather than catching it mid-arrival.
		for _f: int in 260:
			await get_tree().process_frame
	if cover > 0.0:
		# Set on the system that owns it, not emitted past it. Emitting the signal
		# by hand looked like it worked and did not: `WeatherVeil` recomputes and
		# re-announces cover every frame, so a forced value survived exactly one
		# frame and the screenshot caught bare ground.
		var veil: WeatherVeil = run.battlefield.get_node_or_null("WeatherVeil")
		if veil != null:
			veil.set_cover(cover)
		for _f: int in 3:
			await get_tree().process_frame
	var path: String = "user://weather_%s%s.png" % [wanted, "_front" if front >= 0.0 else ""]
	get_viewport().get_texture().get_image().save_png(path)
	print("[weather] %s cover=%.2f -> %s" % [wanted, cover,
		ProjectSettings.globalize_path(path)])
	if front >= 0.0 and veil_node != null:
		# And once it has crossed, so the two can be compared side by side.
		print("[weather] the front came from %s" % str(veil_node.front_from()))
		while veil_node.front() < 1.0:
			await get_tree().process_frame
		for _f: int in 30:
			await get_tree().process_frame
		var done: String = "user://weather_%s_front_done.png" % wanted
		get_viewport().get_texture().get_image().save_png(done)
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
