extends Node

## Photographs the Warden's Glass, which no headless gate can see.
##
##   godot --path game res://tools/glass_shot.tscn -- <out dir>
##
## `warden_glass_check` proves every control reaches the look and nothing else
## moves; it cannot tell whether the screen is any good to look at, whether a
## thumbnail sits on its head, or whether a skin tone reads as skin. Four looks,
## one photograph each, into the directory named after `--` (or `user://`).

const SIZE := Vector2i(1600, 900)

## Choices by key, and a dye preset: bald and painted; a mane with a full beard
## on brown skin; twin braids on fair skin; an afro on deep skin, female if the
## female body is drawn.
const LOOKS: Array = [
	["painted", {}, 0],
	["mane", {"hair": 10, "hair_colour": 4, "beard": 5, "skin": 7}, 1],
	["braids", {"hair": 17, "hair_colour": 6, "beard": 0, "skin": 2}, 2],
	["afro", {"body": 1, "hair": 11, "hair_colour": 1, "beard": 0, "skin": 8}, 4],
	# The cloth colours (2026-09-30): a crimson top on sea trousers, and a moss
	# top on charcoal trousers on the female body.
	["cloth", {"top_colour": 1, "bottom_colour": 7}, 0],
	["cloth_female", {"body": 1, "top_colour": 4, "bottom_colour": 11, "skin": 3}, 0],
]


func _ready() -> void:
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	MetaState.hold_saves()
	var kept: Dictionary = MetaState.look.duplicate()
	var out: String = "user://"
	# The first argument that is not a flag (`tools/perf_offscreen.sh` passes
	# `--offscreen` ahead of the tool's own).
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--"):
			out = argument
			break
	var glass := WardenGlass.new()
	add_child(glass)
	await get_tree().process_frame
	for entry: Array in LOOKS:
		var look: Dictionary = WardenLook.plain()
		var choices: Dictionary = entry[1]
		for key: Variant in choices:
			look[key] = choices[key]
		if int(look.get("body", 0)) == 1 and not WardenDress.available("female"):
			look["body"] = 0
		MetaState.look = WardenLook.dyed_as(look, int(entry[2]))
		glass.open()
		for _frame: int in 45:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = get_viewport().get_texture().get_image()
		var path: String = out.path_join("glass_%s.png" % String(entry[0]))
		frame.save_png(path)
		print("[glass-shot] saved ", path)
		glass.close()
	MetaState.look = kept
	MetaState.resume_saves()
	get_tree().quit()
