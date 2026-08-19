extends Node

## Renders the battlefield road to a PNG so the autotiling can be looked at.
## Diagnostic only, never a gate.

func _ready() -> void:
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	var cam := run.battlefield.camera as Camera2D
	if cam != null:
		cam.zoom = Vector2(0.32, 0.32)
		cam.global_position = Vector2.ZERO
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 8:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://road_shot.png")
	print("[road] shot -> %s" % ProjectSettings.globalize_path("user://road_shot.png"))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20: await get_tree().process_frame
	get_tree().quit(0)
