extends Node

## A throwaway harness for looking at the running game.
##
## A one-frame `--quit` proves the project loads and nothing else. It has already
## missed a NodePath bug that only appeared once enemies were walking, so the
## rule in CLAUDE.md is that running the scene is the authority.
##
## This instantiates a real run, lets it play for a while, prints what actually
## got built, and saves screenshots at chosen moments so the look can be judged
## rather than assumed. Run it with the scene as a positional argument:
##
##   Godot --path game res://tools/soak.tscn
##
## Optional `--seconds=N`, `--phase=F` (force a day/night phase), `--shots=a,b,c`
## (seconds at which to capture).

const RUN_SCENE: String = "res://scenes/run/run.tscn"

var _run: Node = null
var _elapsed: float = 0.0
var _duration: float = 14.0
var _shots: Array[float] = [3.0, 8.0, 13.0]
var _taken: int = 0
var _forced_phase: float = -1.0
var _zoom: float = 0.0
var _roads_only: bool = false
var _peaceful: bool = false
var _build: bool = false
var _no_casters: bool = false
var _panel: bool = false
var _settings: bool = false
var _pause_only: bool = false
var _panel_lane: int = 0
var _panel_slot: int = 0
var _reported: bool = false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			_duration = float(argument.split("=")[1])
		elif argument.begins_with("--phase="):
			_forced_phase = float(argument.split("=")[1])
		elif argument.begins_with("--zoom="):
			_zoom = float(argument.split("=")[1])
		elif argument == "--no-casters":
			# Removes every light blocker. Diffing a frame against this answers
			# "are cast shadows rendering at all" without squinting at a dark
			# screenshot and talking myself into a yes.
			_no_casters = true
		elif argument == "--settings":
			# Opens the pause screen's settings panel.
			_settings = true
		elif argument == "--pause":
			# Opens the pause screen itself and stops there.
			_settings = true
			_pause_only = true
		elif argument.begins_with("--panel="):
			# --panel=lane,slot
			var parts: PackedStringArray = argument.split("=")[1].split(",")
			_panel = true
			_panel_lane = int(parts[0])
			_panel_slot = int(parts[1]) if parts.size() > 1 else 0
		elif argument == "--build":
			# Puts a tower in every slot. Cast shadows need something to cast,
			# and an empty field proves nothing about them.
			_build = true
		elif argument == "--peaceful":
			# Stops the waves. Nobody is playing the hero in a soak, so enemies
			# walk straight into the town and beat it forever - and the town's
			# damage flash then tints every frame red, which makes judging the
			# night lighting impossible.
			_peaceful = true
		elif argument == "--roads-only":
			# Hides the terrain so the road strips can be judged on their own.
			# The ashfen texture tiles with strong tonal blocks that look exactly
			# like a hard-edged road from a distance, which makes "is the blend
			# working" impossible to answer by eye over the top of it.
			_roads_only = true
		elif argument.begins_with("--shots="):
			_shots.clear()
			for piece: String in argument.split("=")[1].split(","):
				_shots.append(float(piece))

	var packed: PackedScene = load(RUN_SCENE)
	_run = packed.instantiate()
	add_child(_run)
	print("[soak] run instantiated, %.1fs, shots at %s" % [_duration, str(_shots)])


func _process(delta: float) -> void:
	_elapsed += delta

	if _forced_phase >= 0.0:
		# Held every frame: the real phase is driven by distance travelled, so
		# it walks away from whatever is set once unless it is pinned.
		DayNight._apply(_forced_phase)

	if _zoom > 0.0:
		# Held every frame: the camera rig writes zoom itself, so setting it once
		# is overwritten within a frame.
		for node: Node in _all(get_tree().root):
			var camera := node as Camera2D
			if camera != null and camera.is_current():
				camera.zoom = Vector2.ONE * _zoom

	if _peaceful:
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			node.queue_free()
		for node: Node in _all(get_tree().root):
			if node is WaveDirector:
				node.set_process(false)

	if _elapsed > 1.5 and not _reported:
		_reported = true
		if _roads_only:
			for node: Node in _all(get_tree().root):
				if node.name == "Ground":
					(node as CanvasItem).visible = false
		if _build:
			_build_everything()
		if _settings:
			# The settings panel is only reachable through two clicks and a pause,
			# none of which a soak can perform. Opening it directly is the only way
			# to see it before shipping it.
			#
			# The harness runs unpaused on purpose: toggle() pauses the whole tree,
			# and a paused tree stops this node's _process - which is what takes the
			# screenshots. PROCESS_MODE_ALWAYS keeps the camera rolling over a
			# genuinely paused game, which is exactly the state being photographed.
			process_mode = Node.PROCESS_MODE_ALWAYS
			var opened: bool = false
			for node: Node in _all(get_tree().root):
				if node is PauseMenu:
					node.toggle()
					node.call("_show_settings", not _pause_only)
					opened = true
					break
			print("[soak] settings panel opened=%s" % str(opened))
		if _panel:
			# Opens the build panel on a slot. It cannot be reached without a
			# mouse, and it is the densest piece of UI in the game — so it is the
			# one most worth forcing open in a test.
			for node: Node in _all(get_tree().root):
				if node is HUD:
					node.call("_open_build_panel", _panel_lane, _panel_slot)
					break
		if _no_casters:
			var removed: int = 0
			for node: Node in _all(get_tree().root):
				if node is LightOccluder2D:
					node.queue_free()
					removed += 1
			print("[soak] removed %d light occluders" % removed)
		_report()

	if _taken < _shots.size() and _elapsed >= _shots[_taken]:
		_capture(_shots[_taken])
		_taken += 1

	if _elapsed >= _duration:
		set_process(false)
		print("[soak] final battlefield state")
		_report()
		print("[soak] done")
		_finish.call_deferred()


## Let the instantiated run release its nodes and resources before shutting
## down. Quitting on the same frame used to turn a healthy soak into a wall of
## false-positive ObjectDB/resource leak warnings.
func _finish() -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	if is_instance_valid(_run):
		_run.queue_free()
	# The dummy audio driver releases decoder playbacks asynchronously. A few
	# frames is racy on fast headless runners; half a second is deterministic.
	for _frame: int in 30:
		await get_tree().process_frame
	get_tree().quit()


## Fills the two outer slots on every lane. The middle one is the combination
## spot and refuses anything until its neighbours exist, so it is left alone.
func _build_everything() -> void:
	var field: Battlefield = null
	for node: Node in _all(get_tree().root):
		if node is Battlefield:
			field = node as Battlefield
			break
	if field == null:
		return
	RunState.gain_resources(9999)
	var towers: Array[TowerData] = ContentDB.base_towers()
	if towers.is_empty():
		return
	for lane: int in Balance.LANE_COUNT:
		for slot: int in [0, 2]:
			var problem: String = field.try_build(lane, slot, towers[lane % towers.size()])
			if not problem.is_empty():
				print("[soak] build refused: %s" % problem)


func _report() -> void:
	var tree: SceneTree = get_tree()
	for node: Node in _all(get_tree().root):
		var tint := node as CanvasModulate
		if tint != null:
			print("[soak] canvas modulate %s = %s" % [tint.name, str(tint.color)])
	print("[soak] torches=%d  towers=%d  enemies=%d"
		% [tree.get_nodes_in_group(&"torches").size(),
			tree.get_nodes_in_group(&"towers").size(),
			tree.get_nodes_in_group(&"enemies").size()])

	var flames: int = _count_of("Flame")
	var shadows: int = _count_shadows()
	var casters: int = _count_of("LightOccluder2D")
	var particles: int = _count_of("CPUParticles2D")
	print("[soak] flames=%d  contact shadows=%d  cast occluders=%d  particle systems=%d"
		% [flames, shadows, casters, particles])

	var lit_lights: int = 0
	var shadow_lights: int = 0
	for node: Node in _all(get_tree().root):
		var light := node as PointLight2D
		if light != null:
			lit_lights += 1
			if light.shadow_enabled:
				shadow_lights += 1
	print("[soak] point lights=%d  of which cast shadows=%d" % [lit_lights, shadow_lights])

	var strips: int = 0
	var blended: int = 0
	for node: Node in _all(get_tree().root):
		var sprite := node as Sprite2D
		if sprite == null or sprite.get_parent() == null:
			continue
		if sprite.get_parent().name != "LaneRoot":
			continue
		strips += 1
		if sprite.material is ShaderMaterial:
			blended += 1
			var material := sprite.material as ShaderMaterial
			if strips == 1:
				print("[soak] road: core=%s fade=%s half=%s alpha=%.2f" % [
					str(material.get_shader_parameter("core_radius")),
					str(material.get_shader_parameter("edge_fade")),
					str(material.get_shader_parameter("half_width")),
					sprite.modulate.a])
				print("[soak] road geometry: pos=%s rot=%.2f region=%s tex=%s repeat=%d rect=%s" % [
					str(sprite.position), sprite.rotation, str(sprite.region_rect),
					str(sprite.texture.get_size()) if sprite.texture != null else "none",
					sprite.texture_repeat, str(sprite.get_rect())])
	print("[soak] lane strips=%d  with blend shader=%d" % [strips, blended])
	print("[soak] phase=%.2f darkness=%.2f night=%s"
		% [DayNight.phase, DayNight.darkness, str(DayNight.is_night())])

	for node: Node in _all(get_tree().root):
		var rosette := node as LaneRosette
		if rosette != null:
			print("[soak] rosette size=%s visible=%s centre=%s"
				% [str(rosette.size), str(rosette.visible), str(rosette._town_on_screen())])


func _capture(at: float) -> void:
	# Bright lights, listed at the moment of the shot. Anything washing the frame
	# out is in here, and guessing which node it belongs to from a screenshot is
	# how a whole round gets spent on the wrong suspect.
	for node: Node in _all(get_tree().root):
		var light := node as PointLight2D
		if light == null or not light.visible or light.energy < 0.6:
			continue
		var reach: float = light.texture_scale * 128.0
		if reach < 300.0:
			continue
		print("[soak]   light %s owner=%s pos=%s colour=%s energy=%.2f reach=%.0f shadows=%s" % [
			light.name, light.get_parent().name, str(light.global_position),
			str(light.color), light.energy, reach, str(light.shadow_enabled)])

	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "user://soak_%02d.png" % int(round(at))
	image.save_png(path)
	print("[soak] shot %.1fs -> %s" % [at, ProjectSettings.globalize_path(path)])


func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found


func _count_of(type_name: String) -> int:
	var total: int = 0
	for node: Node in _all(get_tree().root):
		if node.is_class(type_name) or node.get_script() != null \
				and node.get_script().get_global_name() == type_name:
			total += 1
	return total


## By material identity, not by name. Godot renames duplicate siblings to the
## internal `@ContactShadow@2` form, so counting by name silently reported three
## shadows on a field that had two hundred — which looked exactly like the
## shadow code not running.
func _count_shadows() -> int:
	var wanted: Material = ShadowKit.material()
	var total: int = 0
	for node: Node in _all(get_tree().root):
		var sprite := node as Sprite2D
		if sprite != null and sprite.material == wanted:
			total += 1
	return total
