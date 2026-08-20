extends Node

## Measures frame time on a loaded battlefield and fails if it misses the target.
##
## v4 §52 lists "60 FPS at 1920x1080" as a release row, and it is one of the
## seven the audit marks as human judgement — which in practice meant nobody had
## ever measured it. This turns it into a number.
##
## **Not headless.** A headless run draws nothing, so it reports whatever the
## logic costs and none of what the rendering costs, which is the half most
## likely to be the problem. Run it windowed:
##
##     godot --path game res://tools/perf_check.tscn
##
## And therefore **not in CI**: a CI runner has no GPU worth measuring and would
## either fail honestly or pass meaninglessly. Same reasoning as
## `save_backup_check` — some checks belong to a machine somebody owns.
##
## **Run the baseline first, every time, on a machine you have not measured
## before:**
##
##     godot --path game res://tools/perf_check.tscn -- baseline
##
## That measures an empty window. If it does not come back comfortably under
## budget, the machine cannot render fast enough to say anything about the game
## and the loaded figure is noise. On the development container this was written
## in, the *empty* window reported 1 FPS and the loaded battlefield reported 21 —
## which looks like a damning result and is actually a statement about the
## container's software rasteriser. Two numbers, one of which is obviously
## impossible, is the only way to tell those apart.

## Frames to warm up before measuring. Shader compilation, texture upload and the
## first wave's allocations all land in the first second and are not what this is
## trying to measure.
const WARMUP_FRAMES: int = 120

## Frames to measure over. Two seconds at target.
const SAMPLE_FRAMES: int = 120

## The bar, in milliseconds. 16.67 is 60 FPS; the allowance covers a stray
## garbage collection inside the window rather than a genuinely slow frame.
const BUDGET_MS: float = 16.67
const ALLOWANCE_MS: float = 1.4

## How many frames may blow the budget entirely before this is a stutter problem
## rather than noise, as a fraction of the sample.
const SPIKE_TOLERANCE: float = 0.05

var _samples: PackedFloat32Array = []
var _frames: int = 0
var _run: Run = null
var _baseline: bool = false


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	# Uncapped and unsynced, or this measures the display rather than the game.
	# The first run of this tool reported a flat 20 FPS with a 50 ms p95, which is
	# the shape of a throttle and not of a workload - an unfocused window is
	# rate-limited by the OS, and vsync pins every frame to the refresh interval
	# whether the frame took that long or not.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	# `-- baseline` measures an empty window. If the empty case is also slow the
	# machine is the bottleneck, not the game, and the run's number means nothing.
	_baseline = OS.get_cmdline_user_args().has("baseline")
	if _baseline:
		return

	RunState.reset()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)

	# Measured under load, not on an empty field: an idle battlefield is not the
	# frame anybody is going to complain about.
	for _f: int in 8:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(99999)
	_fill_the_board()
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.battlefield.begin_battle()


## Builds a tower on every free plot and starts a wave, so the sample includes
## the projectiles, lights, shadows and enemies a real fight carries.
func _fill_the_board() -> void:
	var field: Battlefield = _run.battlefield
	var towers: Array[TowerData] = ContentDB.unlocked_base_towers()
	if field == null or towers.is_empty():
		return
	var built: int = 0
	for y: int in BattleGrid.SIZE:
		for x: int in BattleGrid.SIZE:
			var anchor := Vector2i(x, y)
			if not field.grid.footprint_is_open(anchor):
				continue
			if not field.try_build(anchor, towers[built % towers.size()]).is_empty():
				continue
			built += 1
			if built >= 24:
				return


func _process(_delta: float) -> void:
	if _run == null and not _baseline:
		return
	_frames += 1
	if _frames <= WARMUP_FRAMES:
		return
	# Wall-clock frame time, not TIME_PROCESS: process time excludes the render
	# thread, which is exactly where a battlefield full of lights and shadows
	# spends itself.
	#
	# Converted to milliseconds here, at the one place it is sampled. TIME_FPS
	# reports frames per second and everything below this line is a budget in ms;
	# comparing 58 against 16.67 would have "failed" every healthy frame.
	var fps: float = maxf(float(Performance.get_monitor(Performance.TIME_FPS)), 1.0)
	_samples.append(1000.0 / fps)
	if _samples.size() < SAMPLE_FRAMES:
		return
	set_process(false)
	_report()


## Counts the node types that actually cost something to draw, by scene branch.
func _count(node: Node, tally: Dictionary) -> void:
	for child: Node in node.get_children():
		var key: String = child.get_class()
		if key in ["Sprite2D", "PointLight2D", "GPUParticles2D", "Line2D",
				"Polygon2D", "CanvasItem", "Node2D"]:
			tally[key] = int(tally.get(key, 0)) + 1
		_count(child, tally)


func _report() -> void:
	var sorted: Array[float] = []
	for value: float in _samples:
		sorted.append(value)
	sorted.sort()

	var total: float = 0.0
	var spikes: int = 0
	for value: float in sorted:
		total += value
		if value > BUDGET_MS + ALLOWANCE_MS:
			spikes += 1
	var mean: float = total / float(sorted.size())
	# The 95th percentile, not the worst frame: one bad frame in a hundred is a
	# hitch, and reporting the maximum makes every run look broken.
	var p95: float = sorted[mini(int(float(sorted.size()) * 0.95), sorted.size() - 1)]
	var spike_ratio: float = float(spikes) / float(sorted.size())

	print("[perf] %dx%d  mean %.2f ms (%.0f fps)  p95 %.2f ms  over-budget %.1f%%"
		% [get_window().size.x, get_window().size.y, mean,
			1000.0 / maxf(mean, 0.001), p95, spike_ratio * 100.0])
	if _baseline:
		print("[perf] baseline (empty window) — anything near the loaded figure "
			+ "means this machine cannot measure the game")
		get_tree().quit(0)
		return

	print("[perf] enemies=%d draw calls=%d objects=%d"
		% [_run.battlefield.enemy_count(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	# Where the nodes actually are. A draw-call count on its own says the field is
	# expensive; this says which part of it to look at.
	var tally: Dictionary = {}
	_count(_run, tally)
	var worst: Array[String] = []
	for key: Variant in tally:
		worst.append("%s=%d" % [key, tally[key]])
	worst.sort()
	print("[perf] ", ", ".join(worst))

	var passed: bool = mean <= BUDGET_MS and spike_ratio <= SPIKE_TOLERANCE
	if passed:
		print("[perf] PASS — holds 60 FPS under a full board")
	else:
		push_error("[perf] FAIL — mean %.2f ms, %.1f%% of frames over budget"
			% [mean, spike_ratio * 100.0])

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
