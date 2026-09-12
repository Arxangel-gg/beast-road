extends Node

## Renders a rift's maze and a dungeon's, so the cut floor can be looked at.
## Diagnostic only, never a gate.
##
## `--` args: `rift` or `dungeon` (default dungeon), and an optional seed.

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: RiftArena.Kind = RiftArena.Kind.DUNGEON
	var seed_value: int = 20260912
	for arg: String in args:
		if arg == "rift":
			which = RiftArena.Kind.RIFT
		elif arg.is_valid_int():
			seed_value = int(arg)
	RunState.reset(false, seed_value)
	RunState.terrain_id = "jungle"
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 8:
		await get_tree().process_frame
	run.battlefield.suspend()
	var rift: RiftArena = run.rift
	rift.visible = true
	rift.process_mode = Node.PROCESS_MODE_INHERIT
	rift.open(which, Vector2.ZERO)
	rift.activate()
	for _f: int in 8:
		await get_tree().process_frame
	if run.hud != null:
		run.hud.visible = false
	var cam := rift.camera as Camera2D
	if cam != null:
		cam.make_current()
		cam.global_position = Vector2.ZERO
		cam.zoom = Vector2(0.30, 0.30)
	# Mark the vault and the entry so the shot says where the far end is.
	var maze: DungeonLayout = rift.dungeon()
	if maze != null:
		Vfx.ring(RaidLayout.tile_to_world(maze.deep), 120.0, Color(1.0, 0.4, 0.9), 3.0, 10.0)
		Vfx.ring(RaidLayout.tile_to_world(maze.entry), 120.0, Color(0.4, 0.9, 1.0), 3.0, 10.0)
		print("[dungeon] %s: %d open tiles, %d rooms, vault %s at depth %d" % [
			"rift" if which == RiftArena.Kind.RIFT else "dungeon",
			maze.open_tiles().size(), maze.rooms.size(), maze.deep, maze.deepest()])
	for _f: int in 6:
		await get_tree().process_frame
	var name: String = "rift" if which == RiftArena.Kind.RIFT else "dungeon"
	get_viewport().get_texture().get_image().save_png("user://%s_shot.png" % name)
	print("[dungeon] %s -> %s" % [name, ProjectSettings.globalize_path("user://%s_shot.png" % name)])
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
