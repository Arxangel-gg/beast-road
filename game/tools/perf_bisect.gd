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
## `--visuals`: the other table. Instead of a script's `_process`, a *class of
## thing on the screen* is hidden and the frame measured without it - the
## painted plants, the torches, the bars, the fog, the interface - so the
## renderer's levers are sized in one run rather than guessed at. Needs a
## renderer, because headless draws nothing and hides nothing.
var _visuals: bool = false
## `--floor`: every node's processing off, then classes of nodes *freed* one
## after another, cumulatively, with the frame measured after each - what the
## engine's own frame is made of when nothing runs. Headless is fine: what it
## measures is the tree, not the picture. Destructive; the run is over after.
var _floor: bool = false
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
		elif argument == "--visuals":
			_visuals = true
		elif argument == "--floor":
			_floor = true
	# **Headless frames are floored at 6.9 ms by a sleep, not by work** (found
	# 2026-09-24): with nothing to draw, `OS.add_frame_delay` sleeps each frame
	# out to `low_processor_mode_sleep_usec`, whose default is 6900 - so every
	# frame lighter than that read as 6.90, a floor ablation freed the whole
	# field and moved nothing, and every headless average carried the sleep.
	# Off for the length of this tool.
	OS.low_processor_usage_mode_sleep_usec = 0
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
		(_run as Run).journey.stop()
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

	# Held in combat, or the towers measured are idle ones.
	if not _idle and not RunState.is_command_combat():
		print("[bisect] the field was held in %s rather than combat; towers idle here"
			% RunState.Phase.keys()[RunState.phase])
	if _visuals:
		await _visual_table()
		return
	if _floor:
		await _floor_table()
		return
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
		# **Measured against its own neighbours, not the opening baseline.** A
		# table takes minutes and the frame drifts under it; the second Act X
		# run compared every group with a baseline taken two minutes earlier
		# and named nothing. On, off, on again: the drift cancels.
		var before: float = await _measure()
		for node: Node in affected:
			node.set_process(false)
		if get_tree() == null:
			print("[bisect] the run ended under the measurement; the rest is unmeasured")
			break
		var without: float = await _measure()
		for node: Node in affected:
			if is_instance_valid(node):
				node.set_process(true)
		var after: float = await _measure()
		scored.append({
			"script": String(key).trim_prefix("res://"),
			"nodes": affected.size(),
			"saved": (before + after) * 0.5 - without,
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
	# **The floor**: every node's _process and _physics_process off at once,
	# so what is left is the engine's own frame - the canvas cull, tweens,
	# signals, transform propagation - which no script toggle above can name.
	# The named rows add up to a share of the baseline; this says how big the
	# share nobody owns is, which is the difference between "optimise a
	# script" and "there are too many nodes".
	var everything: Array[Node] = _all(get_tree().root)
	var stilled: Array[Node] = []
	for node: Node in everything:
		if node == self or not is_instance_valid(node):
			continue
		if node.is_processing() or node.is_physics_processing():
			node.set_process(false)
			node.set_physics_process(false)
			stilled.append(node)
	var floor_ms: float = await _measure()
	for node: Node in stilled:
		if is_instance_valid(node):
			node.set_process(true)
			node.set_physics_process(true)
	print("[bisect] floor %.2f ms with every node's processing off (%d nodes stilled) - the engine's own frame" % [floor_ms, stilled.size()])
	print("[bisect] done - comparative only; re-measure with perf_check before believing a fix")


## **What is on the screen, by kind.** Classified by script file, class and
## name rather than by scene, because what costs the renderer is what it is
## asked to draw and not where it lives in the tree. An inner-class script has
## no path (a foliage band), so those are read off their host.
func _visual_groups() -> Dictionary:
	var out: Dictionary = {}
	var shadowed: Array = []
	for node: Node in _all(get_tree().root):
		if not is_instance_valid(node) or not (node is CanvasItem):
			continue
		var item := node as CanvasItem
		var script: Script = node.get_script() as Script
		var file: String = script.resource_path.get_file() if script != null else ""
		var key: String = ""
		match file:
			"torch.gd": key = "torches"
			"flame.gd": key = "flames"
			"health_bar.gd": key = "bars"
			"loot_drop.gd": key = "drops"
			"tower_aura.gd": key = "auras"
			"ground_glow.gd", "torch_pool.gd": key = "pools"
			"fog_of_war.gd": key = "fog"
			"hud.gd": key = "hud"
			"minimap.gd": key = "minimap"
			"enemy.gd": key = "enemies"
			"tower.gd": key = "towers"
			"wildlife.gd": key = "wildlife"
			"parallax_scatter.gd", "parallax_band.gd", "treeline.gd": key = "treeline"
			"weather_veil.gd", "color_grade.gd", "cloud_shadows.gd", "sun_relief.gd": key = "post"
			"vfx_ink.gd": key = "ink_light" if bool(node.get("additive")) else "ink_flat"
			"blood_motes.gd": key = "blood_air"
			"blood_field.gd": key = "blood_ground"
			"combat_tells.gd": key = "tells"
			"footfalls.gd": key = "footfalls"
			"foliage.gd": key = "foliage_host"
			_:
				if node is TileMapLayer:
					key = "tiles"
				elif node is CPUParticles2D and node.name == "Embers":
					key = "embers"
				elif node is Sprite2D and node.name == "Pool" and script == null:
					key = "torch_pools"
				elif node is CPUParticles2D or node is GPUParticles2D:
					key = "particles"
				elif node is Sprite2D and script == null and (node as Sprite2D).texture != null \
						and (node as Sprite2D).texture.resource_path.contains("/foliage/"):
					key = "plants"
				elif script != null and script.resource_path.is_empty() and node is Node2D \
						and node.get_parent() != null and node.get_parent().name == "Sorted":
					key = "bands"
		if node is Light2D:
			key = "lights"
			if (node as Light2D).shadow_enabled:
				shadowed.append(node)
		if key.is_empty():
			continue
		if not out.has(key):
			out[key] = []
		(out[key] as Array).append(item)
	if not shadowed.is_empty():
		out["shadows"] = shadowed
	return out


func _visual_table() -> void:
	var groups: Dictionary = _visual_groups()
	var keys: Array = groups.keys()
	keys.sort()
	var motes: BloodMotes = Vfx.blood_motes()
	var draws_before: int = motes.draws if motes != null else -1
	var scored: Array = []
	for key: Variant in keys:
		var items: Array = groups[key]
		var live: Array = []
		for value: Variant in items:
			if is_instance_valid(value):
				live.append(value)
		if live.is_empty():
			continue
		var before: float = await _measure()
		if get_tree() == null:
			return
		for value: Variant in live:
			if not is_instance_valid(value):
				continue
			if String(key) == "shadows":
				(value as Light2D).shadow_enabled = false
			else:
				(value as CanvasItem).visible = false
		var without: float = await _measure()
		for value: Variant in live:
			if not is_instance_valid(value):
				continue
			if String(key) == "shadows":
				(value as Light2D).shadow_enabled = true
			else:
				(value as CanvasItem).visible = true
		var after: float = await _measure()
		scored.append({"kind": String(key), "nodes": live.size(),
			"saved": (before + after) * 0.5 - without, "off": without, "on": (before + after) * 0.5})
		print("[bisect]   %-12s %4d nodes  on %.2f  off %.2f  saved %.2f ms" % [
			String(key), live.size(), (before + after) * 0.5, without, (before + after) * 0.5 - without])
	await _ablate_parts(groups, scored)
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["saved"]) > float(b["saved"]))
	print("[bisect] frame cost by what is drawn, most expensive first:")
	for row: Dictionary in scored:
		print("[bisect]   %-12s %4d nodes  saves %.2f ms when hidden" % [
			row["kind"], int(row["nodes"]), float(row["saved"])])
	if motes != null:
		print("[bisect] blood motes canvas drew %d times during the table (live %d)" % [
			motes.draws - draws_before, motes.live()])


## **The torch and the flame, split** (2026-09-24). The coarse rows hide a
## node with everything under it, so "torches 2.5 ms" could not say whether
## the cost is the ironwork, the halo, the tongue mesh, the embers or the
## tick. These rows switch one part at a time through a diagnostic static on
## the class, or stop the class's process, and measure exactly as the node
## rows do.
func _ablate_parts(groups: Dictionary, scored: Array) -> void:
	var torches: Array = groups.get("torches", [])
	var flames: Array = groups.get("flames", [])
	var iron := func(off: bool) -> void:
		Torch.ablate_ironwork = off
		_redraw_all(torches)
	var halo := func(off: bool) -> void:
		Flame.ablate_halo = off
		_redraw_all(flames)
	var tongues := func(off: bool) -> void:
		Flame.ablate_tongues = off
		_redraw_all(flames)
	var torch_tick := func(off: bool) -> void:
		for item: Variant in torches:
			if is_instance_valid(item):
				(item as Node).set_process(not off)
	var flame_tick := func(off: bool) -> void:
		for item: Variant in flames:
			if is_instance_valid(item):
				(item as Node).set_process(not off)
	await _part_row("torch_iron", torches.size(), iron, scored)
	await _part_row("flame_halo", flames.size(), halo, scored)
	await _part_row("flame_tongue", flames.size(), tongues, scored)
	await _part_row("torch_tick", torches.size(), torch_tick, scored)
	await _part_row("flame_tick", flames.size(), flame_tick, scored)


func _part_row(kind: String, count: int, apply: Callable, scored: Array) -> void:
	if count == 0:
		return
	var before: float = await _measure()
	if get_tree() == null:
		return
	apply.call(true)
	var without: float = await _measure()
	apply.call(false)
	var after: float = await _measure()
	scored.append({"kind": kind, "nodes": count,
		"saved": (before + after) * 0.5 - without, "off": without, "on": (before + after) * 0.5})
	print("[bisect]   %-12s %4d nodes  on %.2f  off %.2f  saved %.2f ms" % [
		kind, count, (before + after) * 0.5, without, (before + after) * 0.5 - without])


func _redraw_all(items: Array) -> void:
	for item: Variant in items:
		if is_instance_valid(item):
			(item as CanvasItem).queue_redraw()


func _floor_table() -> void:
	var live: float = await _measure()
	print("[bisect] floor: live frame %.2f ms" % live)
	for node: Node in _all(get_tree().root):
		if node == self or not is_instance_valid(node):
			continue
		node.set_process(false)
		node.set_physics_process(false)
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
	var quiet: float = await _measure()
	print("[bisect] floor: every node's processing off %.2f ms" % quiet)
	var groups: Dictionary = _visual_groups()
	var order: Array[String] = ["particles", "flames", "torches", "lights", "plants", "bands",
		"foliage_host", "bars", "drops", "enemies", "towers", "auras", "pools", "ink_light",
		"ink_flat", "blood_air", "blood_ground", "tells", "footfalls", "fog", "minimap", "hud",
		"tiles", "treeline", "post", "wildlife"]
	var last: float = quiet
	for key: String in order:
		if not groups.has(key):
			continue
		var freed: int = 0
		for value: Variant in groups[key]:
			if is_instance_valid(value) and (value as Node).is_inside_tree():
				(value as Node).free()
				freed += 1
		if freed == 0:
			continue
		var now: float = await _measure()
		print("[bisect] floor: without %-12s (%4d freed) %.2f ms  (-%.2f)" % [key, freed, now, last - now])
		last = now
	var remaining: int = 0
	var items: int = 0
	for node: Node in _all(get_tree().root):
		remaining += 1
		if node is CanvasItem:
			items += 1
	print("[bisect] floor: %d nodes and %d canvas items left, %.2f ms" % [remaining, items, last])
