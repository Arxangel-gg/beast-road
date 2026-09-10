extends Node

## The merchants' corner, drawn, and one shelf open beside it.
##
## `merchant_check` proves every offer delivers and every refusal speaks. It
## cannot see whether a merchant is standing behind the Town Hall, drawn at the
## size of a building, or covered by the sheet the moment it opens - and the
## fault that started this whole session was a town plot sitting under a docked
## panel, invisible to every gate the project had.

var _run: Node = null


func _ready() -> void:
	await get_tree().process_frame
	RunState.reset()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _i: int in 12:
		await get_tree().process_frame
	_run.call("switch_scope", GameDirector.Scope.TOWN)
	for _i: int in 20:
		await get_tree().process_frame

	# Everybody at once, which no real run does - the point is to see three
	# visitors laid out beside each other, not to reproduce a probable town.
	RunState.act = 3
	RunState.wave_number = 4
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(4000)
	for data: MerchantData in MerchantYard.all_sorted():
		MerchantYard._open_visit(data, false)
	for _i: int in 30:
		await get_tree().process_frame

	var panel: Node = _run.get("town_panel")
	panel.call("open_merchant", MerchantYard.all_sorted()[0].id)
	var town: Node2D = _run.get("town")
	town.call("set_view_inset", panel.call("docked_width"))
	for _i: int in 60:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var out: String = OS.get_environment("SHOT_OUT")
	if out.is_empty():
		out = "user://merchant_shot.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("[merchant-shot] wrote %s" % out)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit()
