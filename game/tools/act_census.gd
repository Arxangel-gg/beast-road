extends Node

## What is on an Act X field, counted (2026-09-24). A diagnostic, not a gate.
##
##   godot --headless --path game res://tools/act_census.tscn [--act=N] [--seconds=S]
##
## `perf_check` measures the frame and can only say how long it took; this
## stands the same late road up the same way (`PerfCheck.stage_late_act`,
## `build_late_board`, the same seed), lets the waves arrive, and then counts
## what the renderer would be handed: canvas items by kind, what is under the
## sorted layer, how many lights, occluders and emitters stand, and how many
## of each the camera could actually see. Headless, so it costs no window.

const PerfCheck = preload("res://tools/perf_check.gd")

var _act: int = 10
var _seconds: float = 40.0


func _ready() -> void:
	MetaState.hold_saves()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--act="):
			_act = int(argument.trim_prefix("--act="))
		elif argument.begins_with("--seconds="):
			_seconds = float(argument.trim_prefix("--seconds="))
	Graphics.apply_preset(Graphics.PRESET_HIGH)
	Engine.max_fps = 0
	RunState.reset(false, 20260922)
	if _act > 1:
		PerfCheck.stage_late_act(_act)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	add_child(load("res://scenes/run/run.tscn").instantiate())
	await get_tree().process_frame
	var field: Battlefield = null
	var run: Node = null
	for node: Node in _all(get_tree().root):
		if node is Battlefield and field == null:
			field = node
		if node is Run and run == null:
			run = node
	if field == null or run == null:
		push_error("[census] no field or no run")
		get_tree().quit(1)
		return
	PerfCheck.build_late_board(field, ContentDB.base_towers())
	run.set("_preparation_left", 0.0)
	run.call("_on_ride_on_requested")
	if RunState.is_preparation():
		run.call("_on_ride_on_requested")
	await get_tree().create_timer(_seconds).timeout
	_census(field)
	Sfx.stop_immediately()
	await get_tree().process_frame
	get_tree().quit(0)


func _census(field: Battlefield) -> void:
	var everything: Array[Node] = _all(get_tree().root)
	var items: int = 0
	var by_kind: Dictionary = {}
	var by_kind_seen: Dictionary = {}
	var lights: int = 0
	var lights_seen: int = 0
	var shadows: int = 0
	var occluders: int = 0
	var emitters: int = 0
	var emitters_seen: int = 0
	var particles: int = 0
	var particles_seen: int = 0
	var window: Rect2 = ScreenCull.world_window(get_viewport(), 0.0)
	for node: Node in everything:
		var item := node as CanvasItem
		if item == null:
			continue
		items += 1
		var key: String = _kind(node)
		by_kind[key] = int(by_kind.get(key, 0)) + 1
		var seen: bool = item.is_visible_in_tree() and _in(window, item)
		if seen:
			by_kind_seen[key] = int(by_kind_seen.get(key, 0)) + 1
		var light := node as PointLight2D
		if light != null:
			lights += 1
			if light.is_visible_in_tree() and _in(window, light):
				lights_seen += 1
			if light.shadow_enabled:
				shadows += 1
		if node is LightOccluder2D:
			occluders += 1
		var emitter := node as CPUParticles2D
		if emitter != null:
			emitters += 1
			particles += emitter.amount
			if emitter.is_visible_in_tree() and _in(window, emitter):
				emitters_seen += 1
				particles_seen += emitter.amount
	print("[census] act %d wave %d  nodes %d  canvas items %d  (%d inside the view)" % [
		RunState.act, RunState.wave_number, everything.size(), items, _sum(by_kind_seen)])
	print("[census] lights %d (%d in view, %d casting)  occluders %d  emitters %d (%d in view)  particles %d (%d in view)" % [
		lights, lights_seen, shadows, occluders, emitters, emitters_seen, particles, particles_seen])
	print("[census] enemies %d  wildlife %d  towers %d  drops %d" % [
		get_tree().get_nodes_in_group(Enemy.GROUP).size(),
		_count_kind(by_kind, "wildlife"),
		get_tree().get_nodes_in_group(Tower.GROUP).size(),
		get_tree().get_nodes_in_group(LootDrop.GROUP).size()])
	var keys: Array = by_kind.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(by_kind[a]) > int(by_kind[b]))
	print("[census] canvas items by kind (all / in view):")
	for index: int in mini(keys.size(), 48):
		var key: String = keys[index]
		print("[census]   %5d / %5d  %s" % [int(by_kind[key]), int(by_kind_seen.get(key, 0)), key])
	# The sorted layer, which is sorted every frame.
	var sorted: Node = field.find_child("Sorted", true, false)
	if sorted != null:
		var under: Dictionary = {}
		for child: Node in sorted.get_children():
			var key: String = _kind(child)
			under[key] = int(under.get(key, 0)) + 1
		var under_keys: Array = under.keys()
		under_keys.sort_custom(func(a: String, b: String) -> bool: return int(under[a]) > int(under[b]))
		print("[census] under the sorted layer: %d children" % sorted.get_child_count())
		for index: int in mini(under_keys.size(), 16):
			var key: String = under_keys[index]
			print("[census]   %5d  %s" % [int(under[key]), key])
	var ink: VfxInk = Vfx.ink()
	var flat: VfxInk = Vfx.ink_flat()
	print("[census] ink records: light %d  paint %d" % [
		ink.live() if ink != null else -1, flat.live() if flat != null else -1])
	print("[census] draw calls %d  objects %d  primitives %d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])


## A scripted node is named by its script; a plain one by the nearest scripted
## ancestor and its own class, so a torch's four sprites read as the torch's.
func _kind(node: Node) -> String:
	var script := node.get_script() as Script
	if script != null and not script.resource_path.is_empty():
		return script.resource_path.get_file().get_basename()
	var up: Node = node.get_parent()
	while up != null:
		var owner := up.get_script() as Script
		if owner != null and not owner.resource_path.is_empty():
			return owner.resource_path.get_file().get_basename() + " > " + node.get_class()
		up = up.get_parent()
	return node.get_class()


func _in(window: Rect2, item: CanvasItem) -> bool:
	var node := item as Node2D
	if node == null:
		return true
	return window.has_point(node.global_position)


func _sum(counts: Dictionary) -> int:
	var total: int = 0
	for key: Variant in counts:
		total += int(counts[key])
	return total


func _count_kind(counts: Dictionary, prefix: String) -> int:
	var total: int = 0
	for key: Variant in counts:
		if String(key).begins_with(prefix):
			total += int(counts[key])
	return total


func _all(from: Node) -> Array[Node]:
	var out: Array[Node] = [from]
	for child: Node in from.get_children():
		out.append_array(_all(child))
	return out
