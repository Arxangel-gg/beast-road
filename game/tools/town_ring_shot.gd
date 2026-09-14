extends Node

## Photographs the city's health ring, which needs a real renderer to exist.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/town_ring_shot.tscn -- --share=0.55
##
## The ring is a shader, and a shader is the one thing a headless run cannot
## check: `town_health_ring.gdshader` shipped broken and drew nothing for as long
## as it took somebody to look at a screen.


func _ready() -> void:
	var share: float = 0.55
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--share="):
			share = clampf(float(argument.trim_prefix("--share=")), 0.0, 1.0)
	RunState.reset()
	GameDirector.run_active = true
	var run: Node = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	var town: Node = _find_town(run)
	if town == null:
		push_error("[ring] no town core in the battlefield")
		get_tree().quit(1)
		return
	var health: Health = town.get("health") as Health
	if health != null:
		health.current_hp = health.max_hp * share
	for _f: int in 90:
		await get_tree().process_frame
	var path: String = "user://town_ring_%d.png" % int(round(share * 100.0))
	get_viewport().get_texture().get_image().save_png(path)
	print("[ring] share %.2f -> %s" % [share, ProjectSettings.globalize_path(path)])
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)


func _find_town(from: Node) -> Node:
	if from is TownCore:
		return from
	for child: Node in from.get_children():
		var found: Node = _find_town(child)
		if found != null:
			return found
	return null
