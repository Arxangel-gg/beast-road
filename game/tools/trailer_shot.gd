extends Node

## Photographs the trailer playing in the game: the film letterboxed, the Skip
## button in its corner. Diagnostic only, never a gate.
##
##   shot_offscreen.sh <profile> 1920 1080 res://tools/trailer_shot.tscn
##
## Written to `user://trailer_shot.png`, three seconds in.


func _ready() -> void:
	var player := (load("res://scenes/ui/trailer_player.tscn") as PackedScene).instantiate() as TrailerPlayer
	player.leaves = false
	add_child(player)
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("user://trailer_shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[trailer-shot] %s (%s)" % [path, player.reason if not player.reason.is_empty() else "playing"])
	player.skip()
	MusicPlayer.stop_immediately()
	for _frame: int in 8:
		await get_tree().process_frame
	get_tree().quit(0)
