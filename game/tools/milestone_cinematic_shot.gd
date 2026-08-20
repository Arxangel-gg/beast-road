extends Node

## Diagnostic render for art-direction and responsive-layout review.


func _ready() -> void:
	var id: String = "mirrorfang"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		id = args[0]
	var data := ContentDB.milestone_cinematics.get(id, null) as MilestoneCinematicData
	if data == null:
		push_error("[milestone-shot] unknown id: " + id)
		get_tree().quit(1)
		return
	var overlay := MilestoneCinematic.new()
	add_child(overlay)
	overlay.visible = true
	overlay.call("_apply", data)
	await get_tree().process_frame
	await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	var output: String = "res://.godot/milestone_%s.png" % id
	var error: Error = image.save_png(output)
	if error != OK:
		push_error("[milestone-shot] could not save %s (%s)" % [output, error_string(error)])
		get_tree().quit(1)
		return
	print("[milestone-shot] %s -> %s" % [id, ProjectSettings.globalize_path(output)])
	get_tree().quit(0)
