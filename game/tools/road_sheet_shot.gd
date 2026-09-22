extends Node

## Renders the road sheet, so the trap menu can be looked at.
##
##   godot --path game res://tools/road_sheet_shot.tscn
##
## Diagnostic only, never a gate. `road_sheet_check` measures the rectangles
## and cannot see whether the new trap's art belongs beside the seven that
## shipped, or whether ten rows read as a list a person can choose from. This
## project has paid several times for the difference between a number agreeing
## and a picture agreeing - the menu camp, the beast's tail, the foliage - and
## a sheet full of content is exactly the kind of thing where they part.

func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	# A spirit, so the readout the sheet stops under is actually on screen -
	# without one the picture shows a sheet with nothing above it, which is not
	# the arrangement anybody reported.
	MetaState.equipped_spirit = "fox:0"
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 14:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(9999)
	# **With a deadline running**, so the clock at the top of the sheet is in
	# the picture. It is hidden where there is nothing to count, which is what
	# an untimed Preparation is - and that is most of them.
	EventBus.preparation_changed.emit(Balance.PREPARATION_BETWEEN_WAVES * 0.42, true)
	var field: Battlefield = run.battlefield
	var road: Vector2i = Vector2i.ZERO
	for radius: int in range(3, 40):
		for angle: int in range(0, 360, 15):
			var at := Vector2i(int(cos(deg_to_rad(angle)) * float(radius)),
				int(sin(deg_to_rad(angle)) * float(radius)))
			if field.grid.cell_at(at) == BattleGrid.Cell.ROAD:
				road = at
				break
		if road != Vector2i.ZERO:
			break
	run.hud.call("_open_road_panel", road)
	for _f: int in 10:
		await get_tree().process_frame
	# Hovered, because the figures box beside the sheet is half of what was
	# reported and an unhovered sheet does not draw it at all.
	var list: Control = run.hud.get("_road_list") as Control
	var row: Button = _last_row(list)
	if row != null:
		row.mouse_entered.emit()
	for _f: int in 6:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://road_sheet_shot.png")
	print("[road-sheet] shot -> %s"
		% ProjectSettings.globalize_path("user://road_sheet_shot.png"))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(0)


## The last offer on the sheet, which is a barricade - the rows the owner
## reported as having no tooltip at all.
func _last_row(list: Control) -> Button:
	var found: Button = null
	for node: Node in list.get_children():
		var button := node as Button
		if button != null:
			found = button
	return found
