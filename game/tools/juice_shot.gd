extends Node

## Photographs the things on the road that can be worked, with the hero
## beside each: a gather node glinting and breathing its reach ring, a pond
## with a fish surfacing, a rift gate letting its motes rise. Diagnostic
## only, never a gate.
##
##   godot --path game res://tools/juice_shot.tscn
##
## Each frame lands in `user://` as `juice_shot_<what>.png`.

var _field: Battlefield = null


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	_field = run.get("battlefield") as Battlefield
	if _field == null or _field.hero == null:
		push_error("[juice] no battlefield or hero")
		get_tree().quit(1)
		return
	var hero: Hero = _field.hero
	# A gather node, the hero a step from it.
	var nodes: PackedVector2Array = _field.tree_positions()
	var gathering: Gathering = _field.get("_gathering") as Gathering
	if gathering != null and gathering.node_count() > 0:
		var at: Vector2 = gathering.node_positions()[0]
		hero.global_position = at + Vector2(70.0, 30.0)
		await _shoot("node", 150)
	# A pond.
	var ponds: Fishing = _field.ponds()
	if ponds != null and not ponds.pond_positions().is_empty():
		# **The biggest one, close up.** The first pond dug is as often as not a
		# four-tile puddle, and the things worth photographing here - the fish,
		# the bubbles, the surface - are all small. Zoomed in as far as a player
		# can go, because that is how anybody ever actually looks at a pond.
		var spots: PackedVector2Array = ponds.pond_positions()
		var cells: PackedInt32Array = ponds.pond_cell_counts()
		var pick: int = 0
		for index: int in spots.size():
			if index < cells.size() and cells[index] > cells[pick]:
				pick = index
		var at: Vector2 = spots[pick]
		hero.global_position = at + Vector2(0.0, 130.0)
		var rig: Node = _field.camera
		if rig != null:
			rig.set("_wanted_zoom", Balance.CAMERA_ZOOM_BATTLEFIELD_MAX)
		await _shoot("pond", 300)
		if rig != null:
			rig.set("_wanted_zoom", Balance.CAMERA_ZOOM_BATTLEFIELD)
	# A rift gate.
	var gates: Node = _field.get("_rifts")
	if gates != null and gates.has_method("gate_positions"):
		var spots: PackedVector2Array = gates.call("gate_positions")
		if not spots.is_empty():
			hero.global_position = spots[0] + Vector2(90.0, 40.0)
			await _shoot("gate", 120)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _shoot(what: String, settle_frames: int) -> void:
	for _f: int in settle_frames:
		await get_tree().process_frame
	var path: String = "user://juice_shot_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("[juice] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
