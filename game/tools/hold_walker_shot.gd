extends Node

## Photographs each simulated Warden walking the Hold beside the Inn's portrait
## of the same stranger (owner, 2026-10-08: "Player NPCs at the Hold do not have
## their visual appearances properly set as they walk around the way they do at
## the Inn"). One plate a seat: the walker close, the portrait in the corner.
##
##   godot --path game res://tools/hold_walker_shot.tscn
##
## Diagnostic only, never a gate.

const SIZE := Vector2i(1600, 900)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)
		return
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20261008)
	var plate := ColorRect.new()
	plate.color = Color(0.05, 0.06, 0.05)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var yard := HoldYard.new()
	add_child(yard)
	yard.advance(4.0)
	DayNight._apply(0.30)
	var layer := CanvasLayer.new()
	add_child(layer)
	for index: int in range(1, yard.seats()):
		var stage := WardenStage.new()
		stage.size = Vector2(260.0, 260.0)
		stage.position = Vector2(SIZE.x - 280.0, 20.0)
		stage.turntable = false
		layer.add_child(stage)
		await get_tree().process_frame
		var stranger: Dictionary = HoldYard.stranger_of(yard.sim_key(index))
		stage.show_look_wearing(stranger["look"] as Dictionary, stranger["gear"] as Array)
		stage.fit_height(260.0)
		yard.advance(0.4, 2)
		var at: Vector2 = yard.seat_state(index).get("at", Vector2.ZERO) as Vector2
		yard.scale = Vector2(2.6, 2.6)
		yard.position = Vector2(SIZE) * 0.5 - (at + Vector2(0.0, -60.0)) * 2.6
		for _settle: int in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = "user://hold_walker_%d.png" % index
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("[hold-walker] %s -> %s" % [yard.seat_name(index), ProjectSettings.globalize_path(path)])
		stage.queue_free()
	# **Walking**: one sent across the yard and photographed four times on the way.
	var seat: Dictionary = yard.seat_state(3)
	var start: Vector2 = seat.get("at", Vector2.ZERO) as Vector2
	seat["to"] = start + Vector2(260.0, 40.0)
	seat["left"] = 0.0
	for step: int in 4:
		var began: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - began < 260:
			await get_tree().process_frame
		var here: Vector2 = seat.get("at", Vector2.ZERO) as Vector2
		yard.position = Vector2(SIZE) * 0.5 - (here + Vector2(0.0, -60.0)) * 2.6
		await RenderingServer.frame_post_draw
		var path: String = "user://hold_walking_%d.png" % step
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("[hold-walker] walking %d at %s anim %s" % [step, here,
			(seat.get("animator") as HeroAnimator).current_state()])
	get_tree().quit(0)
