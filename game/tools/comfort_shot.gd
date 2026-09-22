extends Node

## Photographs the first-run comfort card. Diagnostic only, never a gate.
##
##   godot --path game res://tools/comfort_shot.tscn
##
## `comfort_card_check` proves the card writes nothing, that every slider
## reaches the game and that its ranges are the table's. None of that says
## whether three scales and their explanations read as a thing a new player
## wants to answer, or whether it fits - and this project has paid several
## times over for the difference between a number agreeing and a picture
## agreeing.

func _ready() -> void:
	MetaState.hold_saves()
	get_window().size = Vector2i(1280, 720)
	var plate := ColorRect.new()
	plate.color = Color(0.09, 0.11, 0.10)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var card := ComfortCard.new()
	add_child(card)
	card.open()
	for _frame: int in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("user://comfort_shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[comfort] shot -> %s" % path)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
