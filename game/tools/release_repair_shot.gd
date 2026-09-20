extends Node


func _ready() -> void:
	MetaState.hold_saves()
	get_window().size = Vector2i(1280, 900)
	get_viewport().set_content_scale_size(Vector2i(1280, 900))
	UiFonts.apply()
	MetaState.marks = 100000
	var stable := StableScreen.new()
	add_child(stable)
	stable.open()
	for frame: int in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/release-qa/stable.png")
	stable.queue_free()
	await get_tree().process_frame
	RunState.reset(false, 7192026)
	var run := (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.hero.global_position = Vector2(800.0, 800.0)
	if run.hud != null:
		run.hud.visible = false
	for frame: int in 30:
		await get_tree().process_frame
	field.process_mode = Node.PROCESS_MODE_DISABLED
	var sky: WeatherSky = field.sky()
	sky.call("_draw_bolt", Vector2(1000.0, 760.0))
	sky.call("_draw_chain", Vector2(1000.0, 760.0), Vector2(760.0, 850.0))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/release-qa/lightning.png")
	sky.clear_bolts()
	for index: int in 2:
		var hazard := GroundHazard.new()
		hazard.field = field
		hazard.mirror = true
		hazard.plan = {"mode": "fissure" if index == 0 else "trail",
			"from": Vector2(550.0, 780.0 + float(index) * 160.0),
			"to": Vector2(1080.0, 780.0 + float(index) * 160.0), "width": 24.0,
			"warning": 1.8, "travel": 2.8, "share": 0.0, "tower_damage": 0.0,
			"tint": Color(0.84, 0.57, 0.24), "blame": "earthquake"}
		field.add_child(hazard)
		hazard.call("_process", 3.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/release-qa/earth-patterns.png")
	run.queue_free()
	await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	get_tree().quit()
