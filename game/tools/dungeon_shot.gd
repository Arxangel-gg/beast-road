extends Node

## Renders a rift's maze and a dungeon's, so the cut floor can be looked at:
## the whole floor from above, then the hero among the sconces, then the
## vault with the guardian through and the runes awake, then the collapse.
## Diagnostic only, never a gate.
##
## `--` args: `rift` or `dungeon` (default dungeon), an optional seed, and
## `perf` to measure the frame at play zoom for a few seconds instead of
## photographing - the sconces, the tiles and the air have a cost and this
## is where it is read.

var _rift: RiftArena = null
var _name: String = "dungeon"
var _perf: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var which: RiftArena.Kind = RiftArena.Kind.DUNGEON
	var seed_value: int = 20260912
	for arg: String in args:
		if arg == "rift":
			which = RiftArena.Kind.RIFT
		elif arg == "perf":
			_perf = true
		elif arg.is_valid_int():
			seed_value = int(arg)
	_name = "rift" if which == RiftArena.Kind.RIFT else "dungeon"
	RunState.reset(false, seed_value)
	RunState.terrain_id = "jungle"
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 8:
		await get_tree().process_frame
	run.battlefield.suspend()
	_rift = run.rift
	_rift.visible = true
	_rift.process_mode = Node.PROCESS_MODE_INHERIT
	_rift.open(which, Vector2.ZERO)
	_rift.activate()
	for _f: int in 8:
		await get_tree().process_frame
	if run.hud != null:
		run.hud.visible = false
	var cam := _rift.camera as Camera2D
	var maze: DungeonLayout = _rift.dungeon()
	if maze != null:
		print("[dungeon] %s: %d open tiles, %d rooms, vault %s at depth %d" % [
			_name, maze.open_tiles().size(), maze.rooms.size(), maze.deep, maze.deepest()])
	if _perf:
		await _measure(cam)
		Sfx.stop_immediately()
		MusicPlayer.stop_immediately()
		Ambience.stop_immediately()
		get_tree().quit(0)
		return
	# The whole floor from above, the vault and the entry marked.
	if cam != null:
		cam.make_current()
		cam.global_position = Vector2.ZERO
		cam.zoom = Vector2(0.30, 0.30)
	if _rift.fog() != null:
		_rift.fog().reveal_all()
	if maze != null:
		Vfx.ring(RaidLayout.tile_to_world(maze.deep), 120.0, Color(1.0, 0.4, 0.9), 3.0, 10.0)
		Vfx.ring(RaidLayout.tile_to_world(maze.entry), 120.0, Color(0.4, 0.9, 1.0), 3.0, 10.0)
	await _shoot("", 6)
	# The hero among the sconces, at play zoom.
	if cam != null:
		cam.zoom = Vector2(0.95, 0.95)
		cam.global_position = _rift.hero.global_position
	await _shoot("_close", 40)
	# The rift full, the guardian through, the runes awake.
	var kills: int = int(ceil(1.0 / Balance.RIFT_FILL_PER_KILL))
	for _kill: int in kills:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	if maze != null:
		_rift.hero.global_position = RaidLayout.tile_to_world(maze.deep) + Vector2(0.0, 90.0)
		if cam != null:
			cam.global_position = _rift.hero.global_position
	await _shoot("_vault", 30)
	# The collapse.
	_rift.call("_begin_collapse")
	await _shoot("_collapse", 50)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


## Four seconds at play zoom with the rift filling and the guardian out,
## then the frame times, sorted.
func _measure(cam: Camera2D) -> void:
	if cam != null:
		cam.zoom = Vector2(0.95, 0.95)
	for _f: int in 30:
		await get_tree().process_frame
	var kills: int = int(ceil(1.0 / Balance.RIFT_FILL_PER_KILL))
	for _kill: int in kills:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	var frames: Array[float] = []
	var clock: float = 0.0
	while clock < 4.0:
		var delta: float = get_process_delta_time()
		clock += delta
		frames.append(delta * 1000.0)
		await get_tree().process_frame
	frames.sort()
	var total: float = 0.0
	for ms: float in frames:
		total += ms
	var nodes: int = get_tree().get_node_count()
	var lights: int = 0
	for node: Node in _rift.find_children("*", "PointLight2D", true, false):
		if (node as CanvasItem).visible:
			lights += 1
	print("[dungeon] perf %s: %d frames, mean %.2f ms, p50 %.2f, p99 %.2f, worst %.2f; %d nodes, %d lights, %d bodies" % [
		_name, frames.size(), total / float(frames.size()), frames[frames.size() / 2],
		frames[int(float(frames.size()) * 0.99)], frames[frames.size() - 1], nodes, lights, _rift.enemy_count()])


func _shoot(suffix: String, settle_frames: int) -> void:
	for _f: int in settle_frames:
		await get_tree().process_frame
	var path: String = "user://%s_shot%s.png" % [_name, suffix]
	get_viewport().get_texture().get_image().save_png(path)
	print("[dungeon] %s%s -> %s" % [_name, suffix, ProjectSettings.globalize_path(path)])
