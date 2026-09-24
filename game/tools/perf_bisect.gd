extends Node

## Where does the frame actually go?
##
## `perf_check` says the budget is missed and `--off=` says which *quality
## settings* cost what, but on 2026-09-08 the answer to both was "not much":
## Low quality bought one frame per second, an idle battlefield bought one, and
## turning off lights, foliage, clouds, particles and both shadows together left
## a 15.4 ms floor with nobody fighting. There is no hotspot in the settings, so
## the question became *which code* is spending it, and nothing could answer.
##
## This answers it two ways, because the two costs live in different places:
##
##   1. **Script time**, by bisection. Group every node by the script it runs,
##      switch `_process` off for one group at a time, and measure. A group
##      worth two milliseconds is two milliseconds of `_process`.
##   2. **Draw cost**, by census. Count `CanvasItem`s and their draw calls.
##      1156 draw calls survive with every optional visual disabled, and in the
##      compatibility renderer a draw call is CPU work whether or not the GPU
##      cares - so a frame can be script-cheap and still slow.
##
## Diagnostic only. It never fails, asserts nothing and is not in any workflow:
## it exists to be run by hand while somebody is optimising, and its numbers are
## comparative rather than absolute.
##
##   godot --path game --resolution 1920x1080 res://tools/perf_bisect.tscn -- --seconds=4
##   godot --path game --resolution 1920x1080 res://tools/perf_bisect.tscn -- --seconds=4 --idle

## Seconds of measurement per group. Short on purpose: this runs once per script
## group and there are dozens, so a long sample turns one answer into an hour.
var _seconds: float = 4.0
var _idle: bool = false
var _build: bool = true
## The act to bisect in (`--act=`), staged and boarded exactly as `perf_check`
## stages it, through that tool's own statics - so the road bisected is the
## road that failed.
var _act: int = 1
const PerfCheck := preload("res://tools/perf_check.gd")
## Seconds the fight runs before anything is grouped or measured (`--settle=`).
## The first cut measured three seconds in, on an empty road: 10 ms against
## the 76 ms `perf_check` sees ninety seconds into Act X's waves, because the
## cost is the bodies and there were none yet. Bisect the road that failed.
var _settle_seconds: float = 3.0
var _run: Node = null


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			_seconds = float(argument.split("=")[1])
		elif argument == "--idle":
			_idle = true
		elif argument == "--no-build":
			_build = false
		elif argument.begins_with("--act="):
			_act = clampi(int(argument.split("=")[1]), 1, Balance.FINAL_ASCENT_ACT)
		elif argument.begins_with("--settle="):
			_settle_seconds = maxf(float(argument.split("=")[1]), 0.5)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _boot()
	await _report()
	get_tree().quit(0)


func _boot() -> void:
	# Say why, if the run ends under the table: the first steady bisect lost
	# its tree a few seconds in and the log said nothing about what did it.
	EventBus.run_ended.connect(func(victory: bool, summary: Dictionary) -> void:
		print("[bisect] RUN ENDED victory=%s last_blow=%s wave=%s phase=%s" % [
			victory, str(summary.get("last_blow", RunState.last_blow)),
			str(summary.get("wave", RunState.wave_number)), str(RunState.phase)]))
	RunState.reset()
	if _act > 1:
		# Forty waves short of the boss rather than eight: a bisect runs for
		# minutes and the road advances under it, and an act boss arriving
		# ends the measurement in the middle of the table.
		PerfCheck.stage_late_act(_act, 40.0)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_run = load("res://scenes/run/run.tscn").instantiate()
	add_child(_run)
	await get_tree().process_frame
	if _build:
		for currency: String in [RunState.WOOD, RunState.FOOD, RunState.GOLD, RunState.STONE]:
			RunState.gain_currency(currency, 99999)
		if _act > 1:
			for node: Node in _all(get_tree().root):
				if node is Battlefield:
					PerfCheck.build_late_board(node as Battlefield, ContentDB.base_towers())
					break
	# The town is held at half so the run cannot end under the measurement: a
	# late act's waves felled it partway through the first bisect, the run
	# settled, the tree went away, and every group after that measured
	# nothing and was reported as the whole frame.
	for node: Node in _all(get_tree().root):
		if node is Battlefield:
			var town: Variant = node.get("town")
			if town != null and town.get("health") != null:
				town.health.floor_hp = town.health.max_hp * 0.5
			break
	if not _idle:
		# Leave Preparation the way `perf_check` does, so the bisect measures a
		# live formation and not a Preparation screen with a board on it.
		for node: Node in _all(get_tree().root):
			if node is Run:
				node.set("_preparation_left", 0.0)
				node.call("_on_ride_on_requested")
				if RunState.is_preparation():
					node.call("_on_ride_on_requested")
				break
	# Let the world settle before anything is measured: the opening seconds
	# build roads, foliage and a town, and timing them measures construction.
	# Then let the fight fill the road (`--settle=`), because an empty one
	# measures nothing the player will meet.
	var until: int = Time.get_ticks_msec() + int(_settle_seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	print("[bisect] settled %.0fs in: %d enemies on the field" % [_settle_seconds,
		get_tree().get_nodes_in_group("enemies").size()])
	_hold_the_field()


## The field held at the load it reached, so every group is measured against
## the same frame. The first steady bisect measured groups across a wave's end:
## the ones that happened to land in the breather "saved" forty milliseconds
## of bodies that had simply died, and read as the frame's biggest costs.
## So: no more arrivals, no body dies, nobody wins - the towers keep firing at
## bodies that keep standing, which is the peak the frame has to hold.
func _hold_the_field() -> void:
	if _idle:
		return
	for node: Node in _all(get_tree().root):
		if node is WaveDirector:
			(node as WaveDirector).stop()
		elif node is Battlefield:
			var town: Variant = node.get("town")
			if town != null and town.get("health") != null:
				town.health.floor_hp = town.health.max_hp * 0.5
			var hero: Variant = node.get("hero")
			if hero != null and is_instance_valid(hero) and hero.get("health") != null:
				hero.health.floor_hp = hero.health.max_hp * 0.5
	var held: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var body := node as Enemy
		if body == null or not is_instance_valid(body):
			continue
		var pool: Health = Health.of(body)
		if pool != null:
			pool.floor_hp = pool.max_hp * 0.5
			held += 1
	print("[bisect] holding the field: %d bodies immortal, no arrivals" % held)
	# **And the pause menu is disarmed.** Traced on 2026-09-24 through the
	# director's scene door: an unattended windowed bisect opened the pause
	# menu and pressed Leave a minute in, the world paused under the table
	# (every group "saved" seventy milliseconds) and then the road went to the
	# menu. Whatever presses it - a pad on the desk, a focus change - it has
	# no business in a measurement.
	for menu: Node in get_tree().get_nodes_in_group(&"pause_menu"):
		menu.process_mode = Node.PROCESS_MODE_DISABLED
		if menu is CanvasItem:
			(menu as CanvasItem).visible = false
	# No key reaches the pause either: the action is unbound for the life of
	# this process, which is the harness's own and touches no save.
	if InputMap.has_action(&"pause"):
		InputMap.action_erase_events(&"pause")
	# **And the road stops.** A crossroad every 560 units suspends the field
	# and pauses the tree under a choice nobody in a harness will make, and
	# the boss at the act's end takes the whole scene; a bisect runs for
	# minutes and the beast walked into both. The sky's events go too - a
	# quake mid-table is a group that "saved" the quake.
	if _run != null and _run.get("journey") != null:
		_run.journey.stop()
	for node: Node in _all(get_tree().root):
		if node is Battlefield and node.has_method("sky"):
			var sky: Variant = node.call("sky")
			if sky != null:
				sky.set("events_enabled", false)
			break


## Wall-clock frame time over a fixed number of frames.
##
## Frames rather than seconds, because a slow configuration would otherwise get
## more samples than a fast one and the comparison would drift.
func _measure() -> float:
	if get_tree() == null:
		push_error("[bisect] the tree is gone - the run ended under the measurement")
		return 0.0
	if get_tree().paused:
		print("[bisect] the tree was paused under the measurement - unpausing")
		get_tree().paused = false
	var frames: int = maxi(int(_seconds * 60.0), 30)
	# Discard the first few: switching `_process` off dirties one frame.
	for _warm: int in 8:
		await get_tree().process_frame
	var started: int = Time.get_ticks_usec()
	for _frame: int in frames:
		await get_tree().process_frame
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0
	return elapsed / float(frames)


func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found


## Nodes grouped by the script they run, which is the unit an optimiser can act
## on. Nodes without a script cannot be spending script time and are skipped.
func _groups() -> Dictionary:
	var out: Dictionary = {}
	for node: Node in _all(get_tree().root):
		var script: Script = node.get_script() as Script
		if script == null:
			continue
		var key: String = script.resource_path
		if key.is_empty():
			continue
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append(node)
	return out


func _report() -> void:
	var baseline: float = await _measure()
	print("[bisect] baseline %.2f ms (%.0f fps)%s" % [
		baseline, 1000.0 / maxf(baseline, 0.001), "  idle" if _idle else "  fighting"])

	var canvas_items: int = 0
	var lights: int = 0
	var particles: int = 0
	for node: Node in _all(get_tree().root):
		if not is_instance_valid(node):
			continue
		if node is CanvasItem:
			canvas_items += 1
		if node is Light2D:
			lights += 1
		if node is GPUParticles2D or node is CPUParticles2D:
			particles += 1
	print("[bisect] census  canvas items %d  lights %d  particle systems %d  draw calls %d  render objects %d" % [
		canvas_items, lights, particles,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
	])

	var groups: Dictionary = _groups()
	var keys: Array = groups.keys()
	# Most nodes first: the groups worth knowing about are the populous ones,
	# and if the run ends under the measurement the tail is what is lost.
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return (groups[a] as Array).size() > (groups[b] as Array).size())
	var scored: Array = []
	for key: Variant in keys:
		var nodes: Array = groups[key]
		var affected: Array[Node] = []
		for value: Variant in nodes:
			# A body that died between the census and this group is a freed
			# instance, and casting one throws before any guard can run.
			if not is_instance_valid(value):
				continue
			var node := value as Node
			if node != null and node.is_processing():
				affected.append(node)
		if affected.is_empty():
			continue
		for node: Node in affected:
			node.set_process(false)
		if get_tree() == null:
			print("[bisect] the run ended under the measurement; the rest is unmeasured")
			break
		var without: float = await _measure()
		for node: Node in affected:
			if is_instance_valid(node):
				node.set_process(true)
		scored.append({
			"script": String(key).trim_prefix("res://"),
			"nodes": affected.size(),
			"saved": baseline - without,
		})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["saved"]) > float(b["saved"]))
	print("[bisect] _process cost by script, most expensive first:")
	for row: Dictionary in scored:
		var saved: float = float(row["saved"])
		# Below a tenth of a millisecond is inside the noise of this harness and
		# printing it would pad the list with fifty rows that mean nothing.
		if saved < 0.1:
			continue
		print("   %6.2f ms  %4d nodes  %s" % [saved, int(row["nodes"]), row["script"]])
	print("[bisect] done - comparative only; re-measure with perf_check before believing a fix")
