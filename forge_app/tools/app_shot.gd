extends Node

## Photographs the forge app.
##
## The same argument as every `*_shot` tool in the game: a window whose whole
## job is to *show* something cannot be judged by a gate. The theme is derived
## in code, the preview draws additively over a plate, and both of those are
## exactly the kind of thing that is arithmetically perfect and visibly wrong.

const SHOTS: String = "res://../docs/shots"

@export var seconds: float = 1.2


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1440, 900))
	var app: Node = load("res://scenes/forge_app.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	var out: String = ProjectSettings.globalize_path("res://").path_join(
		"../docs/shots/forge_app.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	shot.save_png(out)
	print("[forge_app] wrote ", out, " ", shot.get_width(), "x", shot.get_height())
	get_tree().quit()
