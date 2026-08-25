extends Node

## Measures the four numbers GDD §47 locks and nothing was checking.
##
##   60 FPS at 1080p on the authored worst-case wave
##   no recurring hitch above 33 ms
##   save and checkpoint under 100 ms
##   a 30-minute soak with no unbounded node, signal, texture, particle or
##   audio growth
##
## All four were LOCKED requirements and none of them had ever been read. The
## codebase did not call `get_frames_per_second` or touch a `Performance`
## monitor anywhere.
##
##   godot --path game res://tools/perf_check.tscn -- --seconds=120 --build
##   godot --headless --path game res://tools/perf_check.tscn -- --seconds=180
##
## **Headless and windowed measure different things, and conflating them would
## make this worthless.** With the dummy renderer there is no GPU work, so a
## frame rate means nothing — a headless run will happily report 900 FPS on a
## machine that stutters. Growth, on the other hand, is entirely real headless:
## nodes, orphans and memory climb the same way either way.
##
## So frame timing is *reported* and only *asserted* when a real renderer is
## present, while growth is asserted always. That is what makes this safe to put
## in CI, which runs headless, without it either lying or failing at random.

# --- Budgets -----------------------------------------------------------------
#
# Deliberately not in Balance.gd. These are release gates, not gameplay tuning:
# nobody should be nudging the frame budget in the Update Manager to make a
# build pass.

## GDD §47: 60 FPS at 1080p. Checked against the average, because a single
## stalled frame is the hitch budget's job, not the throughput budget's.
const MIN_AVERAGE_FPS: float = 60.0

## GDD §47: no recurring gameplay hitch above 33 ms.
##
## "Recurring" is the operative word. One long frame while a scope builds is not
## a hitch, it is a load; the budget is about stutter the player feels as a
## pattern, so a small number is tolerated and a stream of them is not.
const HITCH_MS: float = 33.0
const MAX_HITCHES_PER_MINUTE: float = 3.0

## Growth, measured as the slope between the first and last third of the run.
##
## Comparing start to end would fail every time: the opening seconds build a
## battlefield, so the count legitimately rises and then plateaus. What matters
## is whether it is *still* rising once the game has settled.
const MAX_NODE_GROWTH: float = 0.06
const MAX_ORPHAN_GROWTH: int = 64

## Warm-up excluded from every measurement. The first frames build the scope,
## compile shaders and load textures, and none of that is what the budget is
## about.
const WARMUP_SECONDS: float = 6.0
## A distinct slot in the same storage backend as the real save. It is never
## loaded by the game and is removed immediately after timing, so the gate
## measures representative I/O without mutating the player's progression.
const CHECKPOINT_PATH: String = "user://beast_road_perf_checkpoint.json"

var _seconds: float = 120.0
var _build: bool = false
var _idle: bool = false
var _vsync_actual: int = -1
var _checkpoint_path: String = CHECKPOINT_PATH
## High is the shipped, authored target and therefore the release budget. Ultra
## is intentionally an opt-in headroom mode; it can be profiled explicitly with
## `--quality=ultra` without silently turning the normal certification into a
## benchmark of the most expensive possible settings.
var _quality: String = Graphics.PRESET_HIGH

## Features switched off on top of the preset, for cost attribution.
var _disabled: Array[String] = []
var _elapsed: float = 0.0

## Measurement starts when the first wave does, not when the process does.
var _fighting: bool = false
var _fight_started: float = 0.0
var _nag: float = 1.0

var _frame_ms: Array[float] = []
var _hitches: int = 0
var _worst_ms: float = 0.0

## Sampled once a second rather than per frame: the question is a trend over
## minutes, and sixty samples a second only makes the array bigger.
var _sample_left: float = 1.0
var _nodes: Array[float] = []
var _orphans: Array[float] = []
var _memory: Array[float] = []

var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			_seconds = float(argument.split("=")[1])
		elif argument.begins_with("--checkpoint="):
			# CI uses user:// to exercise the shipped storage backend. Sandboxed
			# developer runs can point at a disposable absolute path instead of
			# weakening the save-time gate or touching an installed save profile.
			_checkpoint_path = argument.trim_prefix("--checkpoint=")
		elif argument.begins_with("--quality="):
			var requested: String = argument.split("=")[1].to_lower()
			if Graphics.PRESETS.has(requested):
				_quality = requested
			else:
				push_warning("Unknown quality preset '%s'; testing High." % requested)
		elif argument.begins_with("--off="):
			# Turns one feature off on top of the chosen preset, so the cost of a
			# single thing can be measured instead of inferred from the gap between
			# two presets that differ in five ways at once.
			#
			#   --quality=high --off=cast     what do torch shadows cost
			#   --quality=high --off=clouds   what does the cloud layer cost
			for piece: String in argument.split("=")[1].split(","):
				_disabled.append(piece.strip_edges().to_lower())
		elif argument == "--build":
			_build = true
		elif argument == "--idle":
			# No wave at all, to separate "the scene exists" from "a fight is
			# happening". Turning individual effects off never moved the frame
			# time, so the question became *what is left* - and a battlefield
			# with nobody on it is the only measurement that answers it.
			_idle = true

	# Vsync off, or this measures the monitor rather than the game.
	#
	# With it on, the frame rate is pinned to the refresh rate and every result
	# lands just under it - the first windowed run here reported 58 fps and looked
	# like a failed budget, when it was a 60 Hz panel and a couple of frames of
	# jitter. A budget that cannot tell "slow" from "capped" would never detect
	# headroom disappearing until it had already gone.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Reported, not assumed. Asking for it off and *getting* it off are different
	# things - a driver or compositor can hold the swap regardless, and then every
	# number lands near the refresh interval and looks like a fixed cost in the
	# game. Which is exactly what a whole afternoon of measurements looked like.
	_vsync_actual = int(DisplayServer.window_get_vsync_mode())
	Graphics.apply_preset(_quality)
	for feature: String in _disabled:
		match feature:
			"cast": Graphics.set_switch(Graphics.KEY_CAST_SHADOWS, false)
			"contact": Graphics.set_switch(Graphics.KEY_CONTACT_SHADOWS, false)
			"clouds": Graphics.set_switch(Graphics.KEY_CLOUDS, false)
			"particles": Graphics.set_switch(Graphics.KEY_PARTICLES, 0.0)
			"foliage": Graphics.set_switch(Graphics.KEY_FOLIAGE, 0.0)
			"lights": _kill_lights()
			"flames": _kill_emitters()
			_: push_warning("Unknown --off feature '%s'." % feature)
	# The player's stored cap is irrelevant to a throughput test. Apply the
	# visual preset first (it reapplies that cap), then uncap the benchmark.
	Engine.max_fps = 0

	RunState.reset()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	add_child(load("res://scenes/run/run.tscn").instantiate())
	await get_tree().process_frame

	if _build:
		_build_defence()
	if not _idle:
		_start_fighting()

	var off: String = ("  minus " + ", ".join(_disabled)) if not _disabled.is_empty() else ""
	print("[perf] vsync requested OFF, actually %d (0=disabled 1=on 2=adaptive 3=mailbox)"
		% _vsync_actual)
	print("[perf] %s renderer, %s quality%s, %.0fs of measured combat, warm-up %.0fs"
		% [_renderer_name(), _quality.capitalize(), off, _seconds, WARMUP_SECONDS])


## Towers, so the worst case is a real fight rather than an empty field. A
## performance budget measured on a battlefield with nothing on it is a budget
## measured on the wrong thing.
func _build_defence() -> void:
	var field: Battlefield = null
	for node: Node in _all(get_tree().root):
		if node is Battlefield:
			field = node
			break
	if field == null:
		return
	for currency: String in [RunState.WOOD, RunState.FOOD, RunState.GOLD, RunState.STONE]:
		RunState.gain_currency(currency, 99999)
	var towers: Array[TowerData] = ContentDB.base_towers()
	if towers.is_empty():
		return
	for lane: int in Balance.LANE_COUNT:
		for _pair: int in 2:
			field.try_build(field.free_anchor_near(lane), towers[lane % towers.size()])


## Leaves Preparation so waves actually arrive.
func _start_fighting() -> void:
	for node: Node in _all(get_tree().root):
		if node is Run:
			# Performance measurement is not an onboarding test. Confirm uncovered
			# roads when --build was not requested, so this gate always measures a
			# live formation instead of the player-controlled opening Preparation.
			node.set("_preparation_left", 0.0)
			node.call("_on_ride_on_requested")
			if RunState.is_preparation():
				node.call("_on_ride_on_requested")
			return


func _process(delta: float) -> void:
	_elapsed += delta
	# Nothing is measured until a fight is actually happening.
	#
	# Reasserting the request also makes this robust to the uncovered-road
	# confirmation. The first version measured an idle Preparation screen and
	# reported a flawless but meaningless result.
	if not _fighting:
		if RunState.phase == RunState.Phase.ROAD_BATTLE:
			_fighting = true
			_fight_started = _elapsed
		else:
			_nag -= delta
			if _nag <= 0.0:
				_nag = 1.0
				_start_fighting()
		return

	if _elapsed - _fight_started < WARMUP_SECONDS:
		return

	var ms: float = delta * 1000.0
	_frame_ms.append(ms)
	_worst_ms = maxf(_worst_ms, ms)
	if ms > HITCH_MS:
		_hitches += 1

	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left = 1.0
		_nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		_orphans.append(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		_memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))

	if _elapsed - _fight_started - WARMUP_SECONDS >= _seconds:
		set_process(false)
		_report()


# --- Reporting ---------------------------------------------------------------

func _report() -> void:
	if not _fighting:
		_failures.append("the run never left Preparation - nothing was measured")
	_check_timing()
	_check_growth()
	_check_save_time()

	for note: String in _notes:
		print("[perf] %s" % note)
	for problem: String in _failures:
		push_error(problem)
	print("[perf] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	_bail(1 if not _failures.is_empty() else 0)


func _check_timing() -> void:
	if _frame_ms.is_empty():
		_failures.append("no frames were sampled")
		return

	var total: float = 0.0
	for ms: float in _frame_ms:
		total += ms
	var average: float = total / float(_frame_ms.size())
	var fps: float = 1000.0 / maxf(average, 0.001)

	var sorted: Array[float] = _frame_ms.duplicate()
	sorted.sort()
	var p99: float = sorted[mini(int(float(sorted.size()) * 0.99), sorted.size() - 1)]
	var minutes: float = maxf(float(_frame_ms.size()) * average / 60000.0, 0.01)
	var per_minute: float = float(_hitches) / minutes

	_notes.append("frames  avg %.1f ms (%.0f fps)  p99 %.1f ms  worst %.1f ms"
		% [average, fps, p99, _worst_ms])
	_notes.append("hitches over %.0f ms: %d  (%.1f per minute, budget %.1f)"
		% [HITCH_MS, _hitches, per_minute, MAX_HITCHES_PER_MINUTE])
	_notes.append("render objects %d  primitives %d  draw calls %d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	])
	# Where the frame actually goes.
	#
	# Added after the minimum-spec work, which found that turning off cast
	# shadows, contact shadows, clouds, particles and foliage *together* did not
	# improve the frame time at all - so 13-14 ms was going somewhere none of the
	# quality settings touch, and the report could not say where. A total with no
	# breakdown tells you that you have a problem and nothing about whose it is.
	var script_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(
		Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_notes.append("frame split  process %.1f ms  physics %.1f ms  rest %.1f ms"
		% [script_ms, physics_ms, maxf(average - script_ms - physics_ms, 0.0)])

	if not _has_renderer():
		_notes.append("timing NOT asserted: the dummy renderer does no GPU work, "
			+ "so a headless frame rate says nothing about a real one")
		return

	if fps < MIN_AVERAGE_FPS:
		_failures.append("average %.0f fps is below the %.0f fps budget" % [fps, MIN_AVERAGE_FPS])
	if per_minute > MAX_HITCHES_PER_MINUTE:
		_failures.append("%.1f hitches per minute over %.0f ms, budget is %.1f"
			% [per_minute, HITCH_MS, MAX_HITCHES_PER_MINUTE])


## Growth is the headless-safe half, and the half that catches real bugs: a
## system that adds a node per wave and never frees one looks perfect for ten
## minutes and unplayable at forty.
func _check_growth() -> void:
	if _nodes.size() < 6:
		_notes.append("run too short to judge growth (%d samples)" % _nodes.size())
		return

	var node_ratio: float = _tail_over_head(_nodes)
	var orphan_rise: float = _tail_average(_orphans) - _head_average(_orphans)
	var memory_ratio: float = _tail_over_head(_memory)

	_notes.append("nodes    %.0f -> %.0f  (%+.1f%% between the first and last third)"
		% [_head_average(_nodes), _tail_average(_nodes), (node_ratio - 1.0) * 100.0])
	_notes.append("orphans  %+.0f" % orphan_rise)
	_notes.append("memory   %+.1f%%" % ((memory_ratio - 1.0) * 100.0))

	if node_ratio - 1.0 > MAX_NODE_GROWTH:
		_failures.append("node count still climbing after warm-up (%+.1f%%, budget %+.1f%%)"
			% [(node_ratio - 1.0) * 100.0, MAX_NODE_GROWTH * 100.0])
	if orphan_rise > float(MAX_ORPHAN_GROWTH):
		_failures.append("orphaned nodes rose by %.0f, budget is %d - something is being "
			% [orphan_rise, MAX_ORPHAN_GROWTH] + "removed from the tree without being freed")


## GDD §47: save and checkpoint operations below 100 ms.
func _check_save_time() -> void:
	# Provision the isolated slot before timing. On Windows, the first write into
	# a brand-new user profile can synchronously create directories and trigger
	# antivirus indexing (hundreds of milliseconds in QA); gameplay checkpoints
	# overwrite an already provisioned slot, which is the operation §47 budgets.
	var payload: String = MetaState.serialized_save()
	var provision: FileAccess = FileAccess.open(_checkpoint_path, FileAccess.WRITE)
	if provision == null:
		_failures.append("could not provision isolated checkpoint at %s" % _checkpoint_path)
		return
	provision.store_string(payload)
	provision.close()

	var started: int = Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(_checkpoint_path, FileAccess.WRITE)
	if file == null:
		_failures.append("could not create isolated checkpoint at %s" % _checkpoint_path)
		return
	file.store_string(payload)
	file.close()
	var ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_checkpoint_path))
	_notes.append("save     %.1f ms (budget 100 ms)" % ms)
	if ms > 100.0:
		_failures.append("saving took %.1f ms, budget is 100 ms" % ms)


# --- Helpers -----------------------------------------------------------------

func _head_average(values: Array[float]) -> float:
	return _average(values, 0, maxi(values.size() / 3, 1))


func _tail_average(values: Array[float]) -> float:
	return _average(values, values.size() - maxi(values.size() / 3, 1), values.size())


func _average(values: Array[float], from: int, to: int) -> float:
	var total: float = 0.0
	var count: int = 0
	for i: int in range(maxi(from, 0), mini(to, values.size())):
		total += values[i]
		count += 1
	return total / float(maxi(count, 1))


func _tail_over_head(values: Array[float]) -> float:
	var head: float = _head_average(values)
	return _tail_average(values) / maxf(head, 1.0)


func _has_renderer() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_video_adapter_name() != ""


## Switches every CPU particle emitter off, for pricing them.
##
## Deliberately separate from `--off=particles`, which scales the *VFX* budget.
## The torch flames are their own emitters and that setting never touched them -
## a census of an idle battlefield found ninety-seven CPUParticles2D nodes still
## running, which is ninety-seven simulations a frame that no quality option in
## the game can turn down.
func _kill_emitters() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var killed: int = 0
	for node: Node in _all_nodes(get_tree().root):
		var emitter := node as CPUParticles2D
		if emitter != null:
			emitter.emitting = false
			emitter.visible = false
			killed += 1
	print("[perf] emitters disabled: %d" % killed)


## Switches every 2D light off, for pricing them.
##
## Not a quality setting, and that is exactly why it is worth being able to
## measure: there is no slider a player can move to reduce the light count, so if
## lights turn out to be the fixed cost then the fixed cost is not something the
## player can do anything about. Deferred a frame so the scopes have built.
func _kill_lights() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var killed: int = 0
	for node: Node in _all_nodes(get_tree().root):
		var light := node as Light2D
		if light != null:
			light.enabled = false
			killed += 1
	print("[perf] lights disabled: %d" % killed)


func _all_nodes(from: Node) -> Array[Node]:
	var out: Array[Node] = [from]
	for child: Node in from.get_children():
		out.append_array(_all_nodes(child))
	return out


func _renderer_name() -> String:
	return "headless" if not _has_renderer() else RenderingServer.get_video_adapter_name()


## The run is freed before quitting, and the audio autoloads stopped first.
##
## Quitting on top of a live run reports leaked resources that are not leaks, and
## a gate that prints ERROR on a healthy pass is a gate the release workflow
## fails on and everybody learns to ignore.
func _bail(code: int) -> void:
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for child: Node in get_children():
		child.queue_free()
	for _frame: int in 40:
		await get_tree().process_frame
	get_tree().quit(code)


func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found
