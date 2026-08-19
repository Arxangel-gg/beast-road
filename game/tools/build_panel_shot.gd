extends Node

## Renders the build panel so the element rail can be looked at.
## Diagnostic only, never a gate.

func _ready() -> void:
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(9999)
	var field: Battlefield = run.battlefield
	var anchor: Vector2i = Vector2i.ZERO
	for y: int in BattleGrid.SIZE:
		for x: int in BattleGrid.SIZE:
			if field.grid.footprint_is_open(Vector2i(x, y)):
				anchor = Vector2i(x, y)
				break
		if anchor != Vector2i.ZERO:
			break
	run.hud.call("_open_build_panel", anchor)
	run.hud.set("_build_element", TowerData.Element.WATER)
	run.hud.call("_refresh_build_panel")
	for _f: int in 8:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://build_panel_shot.png")
	print("[build] shot -> %s" % ProjectSettings.globalize_path("user://build_panel_shot.png"))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20: await get_tree().process_frame
	get_tree().quit(0)
