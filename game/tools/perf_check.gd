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

## How far above the budget a display must refresh before this gate will judge a
## frame rate at all.
##
## Not zero, and not a round number for its own sake. A panel refreshing at
## exactly the budget can only ever *equal* it, so a passing measurement would be
## indistinguishable from a throttled one; a little headroom is what makes the
## two separable. 15 Hz is enough that the common 75, 120 and 144 Hz panels all
## qualify while 60 Hz does not, which is the distinction that matters here.
const REFRESH_HEADROOM: float = 15.0

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

## The road this report measures, unless `--seed=` names another.
##
## **Measured at 45, 90 and 150 seconds on this seed: the window is one
## continuous ROAD_BATTLE.** A wave is about ninety seconds of road, so the
## release's 45s never contains a between-wave breather at all - which is
## where the 2026-09-22 node leak lived, and why that leak reached a release
## bar the gate for it was already on. Tripling the release job to buy a
## breather is the wrong trade: `preparation_check` holds the interface's
## per-frame work deterministically in about a second, on both bars. What
## this report owes instead is to **say which phases it watched**, so that
## 'nothing grew' is never read as 'nothing can grow'.
##
## **Fixed, because a report whose verdict is a draw is not a report.** This
## called `RunState.reset()` with no seed, so every run rolled a different
## road - and the node-growth leak of 2026-09-22 only ran during a *timed*
## Preparation breather, which a 45-second window contained about one run in
## three. The gate was right, intermittently, for as long as that took to
## notice. Frame time varies with the formation drawn too, so the same
## argument covers the whole report: measure one road and re-measure it.
const DEFAULT_SEED: int = 20260922
const MAX_ORPHAN_GROWTH: int = 64

## Warm-up excluded from every measurement. The first frames build the scope,
## compile shaders and load textures, and none of that is what the budget is
## about.
const WARMUP_SECONDS: float = 6.0
## The board a late act is measured with: what `curve_report` says a walked
## campaign holds by Act X (forty emplacements at level 8 on Normal).
const LATE_BOARD_TOWERS: int = 40
const LATE_BOARD_LEVEL: int = 8
## Whether the numbers were ever printed. See `_exit_tree`.
var _reported: bool = false
## A distinct slot in the same storage backend as the real save. It is never
## loaded by the game and is removed immediately after timing, so the gate
## measures representative I/O without mutating the player's progression.
const CHECKPOINT_PATH: String = "user://beast_road_perf_checkpoint.json"

var _seconds: float = 120.0
var _build: bool = false
var _idle: bool = false
var _vsync_actual: int = -1
## Measure the display at its native size and mode rather than pinned 1080p.
var _native: bool = false
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
## The frame's parts, summed over every sampled frame rather than read once
## at the end (2026-09-24) - a single sample at report time was one frame's
## worth and read as 'rest 0' on one run and 'rest 22' on the next. `process`
## is the main loop's whole iteration, which in the Compatibility renderer
## includes `RenderingServer.draw` on this thread, so the renderer's own CPU
## and GPU time are measured beside it: a cost that moves with `--off=cast`
## and not with a script is the renderer's, and a script bisect cannot see it.
var _process_ms_sum: float = 0.0
var _physics_ms_sum: float = 0.0
var _render_cpu_ms_sum: float = 0.0
var _render_gpu_ms_sum: float = 0.0
## Each hitch: when, how long, and what arrived that frame.
var _hitch_ledger: Array[Dictionary] = []
var _nodes_last: int = 0
var _textures_last: float = 0.0
var _bodies_last: int = 0
## `--trace=FROM:TO` prints every frame inside that window of measured
## seconds with its cost, what arrived, and every EventBus signal that fired
## in it (2026-09-24). A burst of hitches at a fixed second on a fixed seed
## is one scripted event, and the ledger can say when and never what.
var _trace_from: float = -1.0
var _trace_to: float = -1.0
var _trace_fired: PackedStringArray = []
var _listening: bool = false
var _trace_said_motes: bool = false

## Sampled once a second rather than per frame: the question is a trend over
## minutes, and sixty samples a second only makes the array bigger.
var _sample_left: float = 1.0
var _nodes: Array[float] = []
var _orphans: Array[float] = []
## One census a second beside the scalar, so a leak can be named.
var _census: Array[Dictionary] = []
## The trace's own census of the frame before, and how many nodes a traced
## frame must stand up before its movers are printed.
var _trace_census_last: Dictionary = {}
const TRACE_CENSUS_FROM: int = 10
var _seed: int = DEFAULT_SEED
## The act to stand the field up in, near the end of its road where its waves
## are heaviest (2026-09-24, owner: "run even the last few acts and peak
## pressure at 60fps"). 1 is the opening the gate always measured; with
## `--build` a late act stands a full board at the Forge's top cap, because
## that is the field a player reaches Act X with.
var _act: int = 1
## Every run phase the measured window actually saw, in order.
var _phases_seen: Array[String] = []
var _memory: Array[float] = []

var _failures: PackedStringArray = []
var _notes: PackedStringArray = []


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			_seed = int(argument.split("=")[1])
		elif argument.begins_with("--seconds="):
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
		elif argument == "--native":
			_native = true
		elif argument.begins_with("--off="):
			# Turns one feature off on top of the chosen preset, so the cost of a
			# single thing can be measured instead of inferred from the gap between
			# two presets that differ in five ways at once.
			#
			#   --quality=high --off=cast     what do torch shadows cost
			#   --quality=high --off=clouds   what does the cloud layer cost
			for piece: String in argument.split("=")[1].split(","):
				_disabled.append(piece.strip_edges().to_lower())
		elif argument.begins_with("--act="):
			_act = clampi(int(argument.split("=")[1]), 1, Balance.FINAL_ASCENT_ACT)
		elif argument.begins_with("--trace="):
			var span: PackedStringArray = argument.trim_prefix("--trace=").split(":")
			if span.size() == 2:
				_trace_from = float(span[0])
				_trace_to = float(span[1])
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
	# **Measured at 1080p, windowed, whatever the monitor is** (2026-09-24). The
	# project opens fullscreen at the display's native size, so every number
	# taken before this was at 1440p on the owner's monitor against a budget
	# the design states at 1080p - the GPU's share of the frame was a third
	# higher than the game a 1080p player sees. `--native` measures the
	# display as it is, for the question "how does it run on this monitor".
	if not _native:
		# **On the fastest screen** (2026-09-24). `(40, 40)` is a point on
		# screen 0, which on the machine this is tuned on is a 60 Hz monitor
		# beside a 180 Hz one - and a windowed frame on a 60 Hz screen is
		# rounded up to the next 16.7 ms by the compositor whatever vsync
		# says, so a 20 ms frame read as 33 and the average was a quantisation.
		var best: int = DisplayServer.window_get_current_screen()
		for screen: int in DisplayServer.get_screen_count():
			var faster: bool = DisplayServer.screen_get_refresh_rate(screen) > DisplayServer.screen_get_refresh_rate(best) + 0.5
			if faster:
				best = screen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_current_screen(best)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		DisplayServer.window_set_position(DisplayServer.screen_get_position(best) + Vector2i(40, 40))
	# **Headless frames are floored at 6.9 ms by a sleep, not by work** (found
	# 2026-09-24): with nothing to draw, `OS.add_frame_delay` sleeps each frame
	# out to `low_processor_mode_sleep_usec`, whose default is 6900 - so every
	# frame lighter than that read as 6.90, a floor ablation freed the whole
	# field and moved nothing, and every headless average carried the sleep.
	# Off for the length of this report.
	OS.low_processor_usage_mode_sleep_usec = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Reported, not assumed. Asking for it off and *getting* it off are different
	# things - a driver or compositor can hold the swap regardless, and then every
	# number lands near the refresh interval and looks like a fixed cost in the
	# game. Which is exactly what a whole afternoon of measurements looked like.
	_vsync_actual = int(DisplayServer.window_get_vsync_mode())
	# The renderer's own clock, cpu and gpu, per frame (see the sums above).
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
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

	RunState.reset(false, _seed)
	if _act > 1:
		stage_late_act(_act)
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
	print("[perf] window %s%s on screen %d at %.0f Hz" % [str(DisplayServer.window_get_size()),
		"  (native)" if _native else "  (pinned 1080p)", DisplayServer.window_get_current_screen(),
		DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())])
	print("[perf] %s renderer, %s quality%s, %.0fs of measured combat, warm-up %.0fs"
		% [_renderer_name(), _quality.capitalize(), off, _seconds, WARMUP_SECONDS])


## The road put down near the end of a late act, the way `ActStart.begin`
## puts it down at an act's door: the act, the distance, the wave the road
## would be on, the region, and the Forge at its top so the board can climb.
## Twelve waves short of the boss (eight until 2026-09-24, when a sixty-second
## run reached it and measured the arrival's textures), so the window is the act's heaviest
## waves and not the boss fight - which is a different measurement.
##
## Static, and shared with `perf_bisect` through a preload, so the two tools
## stand on the same road: a bisect of a different act than the one that
## failed would name different culprits.
static func stage_late_act(act: int, waves_short: float = 12.0) -> void:
	RunState.act = act
	RunState.distance_travelled = maxf(Balance.act_end_distance(act)
		- Balance.WAVE_ROAD_DISTANCE * waves_short, Balance.act_start_distance(act))
	RunState.wave_number = maxi(int(round(
		RunState.distance_travelled / Balance.WAVE_ROAD_DISTANCE)), 0)
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	if terrain != null:
		RunState.terrain_id = terrain.id
	RunState.building_tiers["forge"] = Balance.TOWER_LEVEL_CAP_BY_FORGE.size() - 1
	print("[perf] staged act %d at distance %.0f, wave %d, %s" % [act,
		RunState.distance_travelled, RunState.wave_number, RunState.terrain_id])


## The late board, through the same doors a player's build calls. Returns the
## anchors it stood up.
static func build_late_board(field: Battlefield, towers: Array[TowerData]) -> Array[Vector2i]:
	for currency: String in [RunState.WOOD, RunState.FOOD, RunState.GOLD, RunState.STONE]:
		RunState.gain_currency(currency, 900000)
	var built: Array[Vector2i] = []
	var per_lane: int = int(ceil(float(LATE_BOARD_TOWERS) / float(Balance.LANE_COUNT)))
	for lane: int in Balance.LANE_COUNT:
		for index: int in per_lane:
			var anchor: Vector2i = field.free_anchor_near(lane, 9)
			var kind: TowerData = towers[(lane * per_lane + index) % towers.size()]
			if field.try_build(anchor, kind).is_empty():
				built.append(anchor)
	var climbed: int = 0
	for anchor: Vector2i in built:
		for _step: int in LATE_BOARD_LEVEL - 1:
			if not field.try_upgrade(anchor).is_empty():
				break
			if RunState.level_at(anchor) == Balance.TOWER_SPECIALISE_LEVEL:
				RunState.set_tower_path(anchor, TowerData.Path.SPREAD if climbed % 2 == 0
					else TowerData.Path.FOCUS)
		climbed += 1
	var levels: int = 0
	for anchor: Vector2i in built:
		levels += RunState.level_at(anchor)
	print("[perf] late board: %d towers, mean level %.1f" % [built.size(),
		float(levels) / maxf(float(built.size()), 1.0)])
	return built


## Towers, so the worst case is a real fight rather than an empty field. A
## performance budget measured on a battlefield with nothing on it is a budget
## measured on the wrong thing.
##
## In a late act (`--act=`) the board is the one a player reaches it with:
## `LATE_BOARD_TOWERS` emplacements climbed to `LATE_BOARD_LEVEL`, every path
## chosen, through the same doors a player's own build calls.
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
	if _act <= 1:
		for lane: int in Balance.LANE_COUNT:
			for _pair: int in 2:
				field.try_build(field.free_anchor_near(lane), towers[lane % towers.size()])
		return
	build_late_board(field, towers)


## Leaves Preparation so waves actually arrive.
## Every signal on the bus, noted by name into the frame it fired in. A lambda
## with seven optional parameters accepts any arity the bus declares.
func _listen_to_the_bus() -> void:
	if _trace_to <= 0.0 or _listening:
		return
	_listening = true
	FrameProfile.enabled = true
	for info: Dictionary in EventBus.get_signal_list():
		var named: String = String(info["name"])
		var note := func(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null,
				_e: Variant = null, _f: Variant = null, _g: Variant = null, _h: Variant = null) -> void:
			_trace_fired.append(named)
		EventBus.connect(named, note)


func _start_fighting() -> void:
	_listen_to_the_bus()
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
	_process_ms_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_physics_ms_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var rid: RID = get_viewport().get_viewport_rid()
	_render_cpu_ms_sum += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	_render_gpu_ms_sum += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	# What the frame did, for the hitch ledger: nodes that arrived and texture
	# memory that appeared are the two signatures of a load mid-fight.
	var nodes_now: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var textures_now: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var bodies_now: int = get_tree().get_nodes_in_group("enemies").size()
	var buckets: String = FrameProfile.take() if _trace_to > 0.0 else ""
	if _trace_to > 0.0 and _elapsed >= _trace_from and _elapsed <= _trace_to:
		print("[trace] %6.2fs %5.1f ms  nodes %+4d  bodies %+3d  %s" % [_elapsed, ms,
			nodes_now - _nodes_last, bodies_now - _bodies_last, " ".join(_trace_fired)])
		# **What a frame stood up, by kind.** A node delta says how many; the
		# census says what, which is the difference between "a death allocates"
		# and "a death allocates three dust puffs a piece". Walked only inside
		# the trace window, where a five-thousand-node walk a frame is a
		# diagnostic's price and not the game's.
		var census_now: Dictionary = _node_census()
		if nodes_now - _nodes_last >= TRACE_CENSUS_FROM and not _trace_census_last.is_empty():
			print("[trace-census] %6.2fs %s" % [_elapsed,
				", ".join(_movers_between(_trace_census_last, census_now, 6))])
		_trace_census_last = census_now
		var motes: BloodMotes = Vfx.blood_motes()
		print("[profile] motes=%d/%d pool loot=%d/%d/%d shot=%d/%d/%d eshot=%d/%d/%d %s" % [
			motes.live() if motes != null else -1, motes.draws if motes != null else -1,
			NodePool.made(&"loot"), NodePool.reused(&"loot"), NodePool.pooled(&"loot"),
			NodePool.made(&"shot"), NodePool.reused(&"shot"), NodePool.pooled(&"shot"),
			NodePool.made(&"enemy_shot"), NodePool.reused(&"enemy_shot"), NodePool.pooled(&"enemy_shot"),
			buckets])
		if motes != null and _trace_said_motes == false:
			_trace_said_motes = true
			print("[trace] motes canvas: in_tree=%s visible=%s visible_in_tree=%s parent=%s z=%d pos=%s" % [
				str(motes.is_inside_tree()), str(motes.visible), str(motes.is_visible_in_tree()),
				str(motes.get_parent().get_path()) if motes.get_parent() != null else "none", motes.z_index, str(motes.global_position)])
	_trace_fired.clear()
	if ms > HITCH_MS:
		_hitches += 1
		_hitch_ledger.append({"at": _elapsed, "ms": ms, "nodes": nodes_now - _nodes_last,
			"textures_kb": (textures_now - _textures_last) / 1024.0,
			"bodies": bodies_now - _bodies_last})
	_bodies_last = bodies_now
	_nodes_last = nodes_now
	_textures_last = textures_now

	_sample_left -= delta
	if _sample_left <= 0.0:
		_sample_left = 1.0
		_nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		_orphans.append(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		_memory.append(Performance.get_monitor(Performance.MEMORY_STATIC))
		# **Taken after the frame has been charged**, so an O(n) walk over
		# eighteen thousand nodes cannot invent a hitch in the frame it is
		# measuring. It is what lets a growth failure name its culprit: the
		# scalar above says a leak exists and can never say what leaked, and
		# diagnosing the one that shipped on 2026-09-22 needed a separate
		# census harness written from scratch to answer it.
		_census.append(_node_census())
		# **What the window actually watched.** A report that only ever sees
		# one wave is how a leak that lives in the breather shipped; naming the
		# phases is what lets a reader tell 'nothing grew' from 'the half that
		# grows was never on screen'.
		var phase: String = RunState.Phase.keys()[RunState.phase]
		if _phases_seen.is_empty() or _phases_seen[_phases_seen.size() - 1] != phase:
			_phases_seen.append(phase)

	if _elapsed - _fight_started - WARMUP_SECONDS >= _seconds:
		set_process(false)
		_report()


# --- Reporting ---------------------------------------------------------------

## **A run that ends takes this gate down with it.**
##
## Without towers the wall falls, the results screen changes the scene, and the
## scene it replaces is *this* one - so the tool is freed mid-measurement and the
## process exits 0 having printed no numbers at all. Which is a silent pass, and
## a perf gate that can silently measure nothing is worse than no perf gate.
##
## CI always passes `--build`, so it never happens there; it happens the moment
## anybody runs this by hand for longer than a defenceless road survives. Said
## out loud and failed, rather than left to look like a clean run.
func _exit_tree() -> void:
	if _reported or not _fighting:
		return
	push_error("[perf] the run ended before %.0fs of combat had been measured - "
		% _seconds + "nothing was reported. Pass --build, or a shorter --seconds.")


func _report() -> void:
	_reported = true
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
	# **Whether the hitches are a beat** (2026-09-24). Three hundred hitches
	# in ninety seconds is either one burst or a clock: the eight worst below
	# could not tell them apart, and a stutter at a fixed rate names the
	# system that ticks at that rate. Measured on the chronological ledger,
	# before it is sorted by size.
	if _hitch_ledger.size() >= 4:
		var gaps: Array[float] = []
		for index: int in range(1, _hitch_ledger.size()):
			gaps.append(float(_hitch_ledger[index]["at"]) - float(_hitch_ledger[index - 1]["at"]))
		gaps.sort()
		var median: float = gaps[gaps.size() / 2]
		var near: int = 0
		for gap: float in gaps:
			if median > 0.0 and absf(gap - median) <= median * 0.2:
				near += 1
		var buckets: Dictionary = {}
		for hitch: Dictionary in _hitch_ledger:
			var bucket: int = int(float(hitch["at"]) / 10.0) * 10
			buckets[bucket] = int(buckets.get(bucket, 0)) + 1
		var keys: Array = buckets.keys()
		keys.sort()
		var spread: PackedStringArray = []
		for key: Variant in keys:
			spread.append("%ds:%d" % [int(key), int(buckets[key])])
		var spawned: int = 0
		var fell: int = 0
		for hitch: Dictionary in _hitch_ledger:
			if int(hitch.get("bodies", 0)) > 0:
				spawned += 1
			elif int(hitch.get("bodies", 0)) < 0:
				fell += 1
		_notes.append("hitch beat: median gap %.2fs (%.1f Hz), %d of %d gaps within 20%% of it; "
			% [median, 1.0 / maxf(median, 0.001), near, gaps.size()]
			+ "per 10s %s" % ", ".join(spread))
		_notes.append("hitch frames: %d saw a body arrive, %d saw one leave, %d neither"
			% [spawned, fell, _hitch_ledger.size() - spawned - fell])
	# The worst eight, with what arrived in the frame: a hitch with a texture
	# jump is a load, one with a node jump is a spawn, one with neither is
	# script time.
	_hitch_ledger.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) > float(b["ms"]))
	var loads: int = 0
	for hitch: Dictionary in _hitch_ledger:
		if float(hitch["textures_kb"]) > 256.0:
			loads += 1
	if not _hitch_ledger.is_empty():
		_notes.append("hitches that loaded textures: %d of %d" % [loads, _hitch_ledger.size()])
	for index: int in mini(_hitch_ledger.size(), 8):
		var hitch: Dictionary = _hitch_ledger[index]
		_notes.append("  hitch %.1f ms at %.1fs  nodes %+d  bodies %+d  textures %+.0f KB" % [
			float(hitch["ms"]), float(hitch["at"]), int(hitch["nodes"]), int(hitch.get("bodies", 0)),
			float(hitch["textures_kb"])])
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
	#
	# **`TIME_PROCESS` and `TIME_PHYSICS_PROCESS` are each second's worst
	# frame**, refreshed once a second (`Main::iteration` hands the monitor
	# `process_max`), which is why a 'process' of thirty could sit beside an
	# average frame of twenty on 2026-09-24 and read as the renderer being
	# half the frame. The viewport's own render times are per frame. Said on
	# the line, so the two are not subtracted from each other again.
	var sampled: float = float(maxi(_frame_ms.size(), 1))
	var process_worst: float = _process_ms_sum / sampled
	var physics_worst: float = _physics_ms_sum / sampled
	var render_cpu: float = _render_cpu_ms_sum / sampled
	var render_gpu: float = _render_gpu_ms_sum / sampled
	_notes.append(("frame split  renderer cpu %.1f ms  gpu %.1f ms per frame;  "
		+ "each second's worst process frame %.1f ms, worst physics %.1f ms")
		% [render_cpu, render_gpu, process_worst, physics_worst])

	if not _has_renderer():
		_notes.append("timing NOT asserted: the dummy renderer does no GPU work, "
			+ "so a headless frame rate says nothing about a real one")
		return

	# **You cannot measure a 60 FPS budget on a 60 Hz screen.**
	#
	# The comment in `_ready` warns that a compositor can hold the swap whatever
	# vsync says, and that every number then "lands near the refresh interval and
	# looks like a fixed cost in the game". It warns; it did not check.
	#
	# This guard exists because on 2026-09-08 that warning nearly claimed a
	# second victim. Six runs produced 48-56 FPS across loads that should have
	# differed wildly - Low quality, an idle battlefield with nobody on it, and a
	# full fight all landed within a couple of milliseconds - which is exactly
	# the signature the warning describes. `Win32_VideoController` reported
	# 60 Hz, and the whole result was almost withdrawn as a measurement artefact.
	#
	# It was not. That 60 Hz belonged to a *secondary* monitor;
	# `DisplayServer.screen_get_refresh_rate` on the window's own screen says
	# 180 Hz, there was no ceiling, and the frame rate was real. Ask the display
	# server about the screen the window is actually on - the OS-level query
	# answers about a different one, and the two disagreeing is how an hour went.
	#
	# The check stays because the trap is real for anyone measuring on a 60 Hz
	# panel: with a refresh at or below the budget there is no headroom in which
	# to *demonstrate* the budget, and a pass would mean the display presented
	# more frames than it can present. Report the number and refuse to judge it,
	# exactly as the headless branch above does. A gate that cannot answer must
	# say so - `night_check` was given the same treatment when it turned out to
	# be sampling the dummy renderer and confidently printing PASS.
	var refresh: float = DisplayServer.screen_get_refresh_rate(
		DisplayServer.window_get_current_screen())
	if refresh > 0.0 and refresh < MIN_AVERAGE_FPS + REFRESH_HEADROOM:
		_notes.append(("timing NOT asserted: this screen refreshes at %.0f Hz and "
			+ "the budget is %.0f FPS, so there is no headroom to measure it in. "
			+ "Windowed OpenGL is throttled by the desktop compositor whatever "
			+ "vsync reports, so every load lands near %.1f ms and looks like a "
			+ "fixed cost. Measure on a display above %.0f Hz.")
			% [refresh, MIN_AVERAGE_FPS, 1000.0 / refresh,
				MIN_AVERAGE_FPS + REFRESH_HEADROOM])
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
	# Said beside the growth figure rather than only on a failure, because "the
	# window saw ROAD_BATTLE and nothing else" is the reading that turns a clean
	# result into a question.
	_notes.append("phases   seed %d watched %s" % [_seed,
		"nothing" if _phases_seen.is_empty() else " -> ".join(_phases_seen)])
	if not _phases_seen.has("PREPARATION"):
		_notes.append("         growth judged on combat only - a between-wave "
			+ "breather needs about 150s of road, and the interface's own "
			+ "per-frame work is held by preparation_check on both bars")
	_notes.append("memory   %+.1f%%" % ((memory_ratio - 1.0) * 100.0))

	if node_ratio - 1.0 > MAX_NODE_GROWTH:
		var movers: Array[String] = _biggest_movers(3)
		_failures.append("node count still climbing after warm-up (%+.1f%%, budget %+.1f%%)%s"
			% [(node_ratio - 1.0) * 100.0, MAX_NODE_GROWTH * 100.0,
				"" if movers.is_empty() else " - " + ", ".join(movers)])
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


## How many nodes of each kind stand in the tree right now.
##
## Keyed by script basename where there is one and by class otherwise, because
## "NinePatchRect" names a leak far less usefully than "sheet_clock" would -
## and both are more useful than a percentage.
func _node_census() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in _all_nodes(get_tree().root):
		var script := node.get_script() as Script
		var key: String = node.get_class()
		if script != null and not script.resource_path.is_empty():
			key = script.resource_path.get_file().get_basename()
		out[key] = int(out.get(key, 0)) + 1
	return out


## The kinds that grew most between the first and the last census, biggest
## first, as "name +n" strings.
func _biggest_movers(most: int) -> Array[String]:
	if _census.size() < 2:
		return []
	return _movers_between(_census[0], _census[_census.size() - 1], most)


func _movers_between(first: Dictionary, last: Dictionary, most: int) -> Array[String]:
	var moved: Array = []
	for key: Variant in last.keys():
		var rise: int = int(last[key]) - int(first.get(key, 0))
		if rise > 0:
			moved.append({"key": String(key), "rise": rise})
	moved.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["rise"]) > int(b["rise"]))
	var out: Array[String] = []
	for entry: Variant in moved.slice(0, most):
		out.append("%s +%d" % [(entry as Dictionary)["key"],
			(entry as Dictionary)["rise"]])
	return out


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
