extends Node

## Photographs the pantry with a basket (2026-09-30, cooking): once eating
## plain and once with a crop chosen, so the pot row and the Cook buttons can
## be looked at rather than measured.
##
##   godot --path game res://tools/pantry_shot.tscn
##
## Windowed, because a headless display has no pixels. The larder and the
## basket are stocked for the shot and put back after it. Diagnostic only:
## `cooking_check` holds what cooking does.

const SIZE := Vector2i(1600, 900)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[pantry-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	var fish_before: Dictionary = MetaState.fish.duplicate()
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260930)
	GameDirector.run_active = true
	for id: String in ["deepwinter_pike", "greenback_perch", "silt_minnow", "sunglass_ray"]:
		for _n: int in 2:
			MetaState.take_fish(id)
	RunState.basket = {"barley": 2, "glowcap": 1, "stone_melon": 1}
	var screen := StashScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	screen._filter = StashScreen.FILTER_PANTRY
	screen._refresh()
	await _shoot("user://pantry_plain.png")
	screen._cook_with = "glowcap"
	screen._refresh()
	await _shoot("user://pantry_cook.png")
	screen.queue_free()
	MetaState.fish = fish_before
	GameDirector.run_active = false
	MetaState.resume_saves()
	get_tree().quit(0)


func _shoot(path: String) -> void:
	for _settle: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("[pantry-shot] -> ", ProjectSettings.globalize_path(path))
