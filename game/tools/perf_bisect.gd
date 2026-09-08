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
var _run: Node = null


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			_seconds = float(argument.split("=")[1])
		elif argument == "--idle":
			_idle = true
		elif argument == "--no-build":
			_build = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _boot()
	await _report()
	get_tree().quit(0)


func _boot() -> void:
	RunState.reset()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_run = load("res://scenes/run/run.tscn").instantiate()
	add_child(_run)
	await get_tree().process_frame
	if _build:
		for currency: String in [RunState.WOOD, RunState.FOOD, RunState.GOLD, RunState.STONE]:
			RunState.gain_currency(currency, 99999)
	# Let the world settle before anything is measured: the opening seconds
	# build roads, foliage and a town, and timing them measures construction.
	for _frame: int in 180:
		await get_tree().process_frame


## Wall-clock frame time over a fixed number of frames.
##
## Frames rather than seconds, because a slow configuration would otherwise get
## more samples than a fast one and the comparison would drift.
func _measure() -> float:
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
	keys.sort()
	var scored: Array = []
	for key: Variant in keys:
		var nodes: Array = groups[key]
		var affected: Array[Node] = []
		for value: Variant in nodes:
			var node := value as Node
			if node != null and is_instance_valid(node) and node.is_processing():
				affected.append(node)
		if affected.is_empty():
			continue
		for node: Node in affected:
			node.set_process(false)
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
