extends Node2D

## Photographs every dragon breath on a plate: fire, frost, storm, stone and the
## plasma ultra, each at its charge and mid-blast.
##
##   godot --path game res://tools/breath_shot.tscn
##
## A diagnostic rather than a gate. `dragon_check` holds what a breath is; this
## is the half a number cannot answer - whether it reads as fire, as frost, as a
## hyperbeam - and the owner's report was about exactly that.

const OUT: String = "user://breath_shot_%s.png"
const ROWS: Array = [["fire", false], ["frost", false], ["storm", false],
	["stone", false], ["plasma", true]]


func _ready() -> void:
	get_window().size = Vector2i(1600, 1000)
	var plate := ColorRect.new()
	plate.color = Color(0.16, 0.19, 0.13)
	plate.size = Vector2(1600, 1000)
	plate.z_index = -10
	add_child(plate)
	Vfx.world = self
	for _f: int in 4:
		await get_tree().process_frame
	for row: int in ROWS.size():
		var kind: String = String(ROWS[row][0])
		var ultra: bool = bool(ROWS[row][1])
		var y: float = 110.0 + float(row) * 190.0
		var breath := DragonBreath.new()
		breath.mouth = Vector2(160.0, y)
		breath.to = Vector2(160.0 + 620.0 * (1.35 if ultra else 1.0), y)
		breath.half_width = 40.0 * (0.62 if ultra else 1.0)
		breath.element = kind
		breath.ultra = ultra
		breath.warning = 0.9
		breath.blast = Balance.DRAGON_ULTRA_BLAST if ultra else Balance.DRAGON_BREATH_BLAST
		add_child(breath)
	var elapsed: float = 0.0
	for moment: Array in [["charge", 0.6], ["blast", 1.12], ["late", 1.4]]:
		while elapsed < float(moment[1]):
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(OUT % String(moment[0]))
		print("[breath] %s -> %s" % [moment[0], ProjectSettings.globalize_path(OUT % String(moment[0]))])
	Sfx.stop_immediately()
	get_tree().quit()
