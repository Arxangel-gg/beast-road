extends Node

## Renders a raid camp so the generated terrain can be looked at.
## Diagnostic only, never a gate.
##
## `--` args: `night` sets the world clock to deep night before the camp is
## entered, so the arena's own tint (2026-09-14) and the fires' light can be
## looked at; `close` frames it at play zoom instead of the whole camp.

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var night: bool = args.has("night")
	var close: bool = args.has("close")
	RunState.reset()
	RunState.terrain_id = "jungle"
	if night:
		DayNight._apply(0.8)
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
		# **A diagnostic framing, not the game's.** Play sits at about 0.95,
		# which shows 2021x1137 units - the arena fills 69% of the width and the
		# hero lights 51% of it. This pulls back to 0.30 so the whole camp is in
		# one picture, which makes the fog look far tighter than a player ever
		# sees it. Do not measure readability or framing from this tool's output;
		# it was read as a badly framed raid once already.
		cam.zoom = Vector2(0.95, 0.95) if close else Vector2(0.30, 0.30)
		if close and raid.hero != null:
			cam.global_position = raid.hero.global_position
	for _f: int in 30 if close else 6:
		await get_tree().process_frame
	var tint_node: CanvasModulate = raid.get_node_or_null("ArenaTint") as CanvasModulate
	print("[raid] clock phase %.2f tint %s darkness %.2f; arena tint %s visible %s" % [
		DayNight.phase, str(DayNight.tint), DayNight.darkness,
		str(tint_node.color) if tint_node != null else "none",
		str(tint_node.visible) if tint_node != null else "-"])
	if args.has("notint") and tint_node != null:
		tint_node.visible = false
		for _f: int in 3:
			await get_tree().process_frame
	var suffix: String = ("_night" if night else "") + ("_close" if close else "") + ("_notint" if args.has("notint") else "")
	var path: String = "user://raid_shot%s.png" % suffix
	get_viewport().get_texture().get_image().save_png(path)
	print("[raid] camp -> %s" % ProjectSettings.globalize_path(path))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
