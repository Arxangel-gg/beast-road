extends Node

## Renders a raid camp so the generated terrain can be looked at.
## Diagnostic only, never a gate.

func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 8:
		await get_tree().process_frame
	# The real entry path. `switch_scope` returns early for raids on purpose -
	# they are entered through the request handler, which is also what suspends
	# and *hides* the battlefield. Poking visibility directly left the road
	# network drawn under the camp, which looked like a rendering bug in the new
	# terrain and was a bug in this tool.
	# The battlefield is suspended the way a real raid entry suspends it - that is
	# what *hides* it. `_on_raid_requested` is gated on raid charge, which a tool
	# has no way to have earned, so the two steps are taken directly.
	run.battlefield.suspend()
	var raid: RaidArena = run.raid
	raid.visible = true
	raid.process_mode = Node.PROCESS_MODE_INHERIT
	raid.begin()
	raid.activate()
	for _f: int in 8:
		await get_tree().process_frame
	if run.hud != null:
		run.hud.visible = false
	var cam := raid.camera as Camera2D
	if cam != null:
		cam.make_current()
		cam.global_position = Vector2.ZERO
		cam.zoom = Vector2(0.30, 0.30)
	for _f: int in 6:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://raid_shot.png")
	print("[raid] camp -> %s" % ProjectSettings.globalize_path("user://raid_shot.png"))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
