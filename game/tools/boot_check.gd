extends Node

## Boots the game the way the game boots it.
##
## The soak instantiates run.tscn directly, which skips GameDirector.start_run()
## and therefore skips RunState.reset() — so every soak has been running against
## a RunState that a real game never has. It also force-opens the build panel
## instead of clicking a slot, so the click path has never been exercised at all.
##
## Both of those are exactly where "the HUD vanished and slots do nothing" would
## hide. This drives the real entry point and then clicks a real build spot.

var _clicked: bool = false


func _ready() -> void:
	# start_run() ends in change_scene_to_file, which frees whatever is the
	# current scene - including this checker - so the awaits below would never
	# resume. Everything start_run does *before* that is what matters here: the
	# RunState reset that the soak has never performed.
	RunState.reset()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	add_child(load("res://scenes/run/run.tscn").instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var hud: HUD = _find(HUD) as HUD
	if hud == null:
		push_error("no HUD in the tree after start_run()")
		_bail(1)
		return

	# Count what actually got built. A _ready() that threw half way leaves the
	# node present and mostly empty, which looks identical to "the HUD is gone".
	var controls: int = 0
	for node: Node in _all(hud):
		if node is Control:
			controls += 1
	print("[boot] HUD present, %d child controls" % controls)

	# Preparation remains playable: movement and torch bracing stay live while
	# formations and projectiles wait. Exactly one battlefield hero must own the
	# active group both before and after Ride On.
	var heroes: int = get_tree().get_nodes_in_group(Hero.GROUP).size()
	print("[boot] heroes during Preparation=%d" % heroes)
	var preparation_heroes: int = heroes

	# The build path, exercised through the real signal the real cursor emits.
	# Free placement replaced the twelve fixed slot nodes, so what is checked now
	# is that a legal tile opens the panel - the same question, one layer up.
	var field: Battlefield = _find(Battlefield) as Battlefield
	if field != null and field.placement != null and field.grid != null:
		var anchor: Vector2i = BattleGrid.world_to_tile(field.grid.lane_pocket_centre(0))
		print("[boot] placement cursor live=%s, pocket buildable=%s" % [
			str(field.placement._is_active()),
			str(field.placement_problem(anchor).is_empty())])
		field.placement.tile_clicked.emit(anchor)
		await get_tree().process_frame
		var panel: Control = hud.get("_build_panel") as Control
		print("[boot] build panel visible after click=%s" % str(panel != null and panel.visible))
		_clicked = panel != null and panel.visible

	var run: Run = _find(Run) as Run
	if run != null:
		run._preparation_left = 0.0
		run._on_ride_on_requested()
		run._on_ride_on_requested()
		await get_tree().process_frame
	heroes = get_tree().get_nodes_in_group(Hero.GROUP).size()
	print("[boot] heroes after Ride On=%d phase=%d" % [heroes, int(RunState.phase)])

	# "wired slots" is gone with the slot nodes; the equivalent question is whether
	# clicking a legal tile opens the build panel, which `_clicked` answers.
	if controls < 20 or not _clicked \
			or preparation_heroes != 1 or heroes != 1 \
			or RunState.phase != RunState.Phase.ROAD_BATTLE:
		push_error("boot check failed: controls=%d panel=%s prep_heroes=%d heroes=%d phase=%d"
			% [controls, str(_clicked), preparation_heroes, heroes, int(RunState.phase)])
		_bail(1)
		return
	_bail(0)


func _bail(code: int) -> void:
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(code)


func _find(type: Variant) -> Node:
	for node: Node in _all(get_tree().root):
		if is_instance_of(node, type):
			return node
	return null


func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found
