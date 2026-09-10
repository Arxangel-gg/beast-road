extends Node

## The Mansion tree page with the synergy list on it.
##
## `discipline_check` proves the three synergies fire and that none of them can
## be authored as a lie. It cannot see whether a player can *find* them, and the
## whole argument for stage two is that a synergy nobody can aim at is a
## coincidence rather than a build. So this is here to be looked at.

var _run: Node = null


func _ready() -> void:
	await get_tree().process_frame
	RunState.reset()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _i: int in 12:
		await get_tree().process_frame
	_run.call("switch_scope", GameDirector.Scope.TOWN)
	for _i: int in 20:
		await get_tree().process_frame

	# One half of one synergy trained, which is the state the list exists for:
	# something active, something one node away, something not started.
	RunState.act = 3
	RunState.building_tiers["sanctum"] = 3
	RunState.set_phase(RunState.Phase.PREPARATION)
	for effect_id: String in ["support_kill_speed", "revive_knockback"]:
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.effect_id == effect_id:
				RunState.trained_discipline_nodes.append(node.id)

	var panel: Node = _run.get("town_panel")
	panel.call("open", "sanctum")
	for _i: int in 20:
		await get_tree().process_frame
	# The tree page at the top, which is where the synergy list sits - above the
	# thirty nodes rather than below them, so it is the first thing on the page.
	panel.set("_mansion_page", TownPanel.Mansion.TREE)
	panel.call("_refresh")
	for _i: int in 20:
		await get_tree().process_frame
	var scroll := panel.get("scroll") as ScrollContainer
	if scroll != null:
		scroll.scroll_vertical = 0
	for _i: int in 10:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var out: String = OS.get_environment("SHOT_OUT")
	if out.is_empty():
		out = "user://synergy_shot.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("[synergy-shot] wrote %s" % out)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit()
