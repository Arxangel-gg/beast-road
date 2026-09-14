extends Node

## Photographs one breed walking west and walking east, on the real field.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/facing_shot.tscn -- --breed=rootshield
##   godot --path game res://tools/facing_shot.tscn -- --breed=all
##
## **This is what settles a facing report.** The facing gate reads a table; the
## table was written from a contact sheet; the contact sheet was read wrong
## twice and then read *right* for the wrong question - a shield-bearer's body
## is square to the camera, and marking it FRONT was correct about the art and
## wrong about the game, because it then walked half the map with its shield
## trailing. Four reports. None of them could have been answered by looking at
## the sprite on its own, and all of them are answered by this: the body, on
## the road, going the way a body goes, twice.
##
## The hero is stood at the head of the east road and the west road in turn, so
## the camera is already there when the breed spawns and walks in toward the
## town - west from the east road, east from the west road. Both shots land in
## `user://` with the breed and the direction in the name.

var _breeds: Array[String] = []


func _ready() -> void:
	var wanted: String = "rootshield"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--breed="):
			wanted = argument.trim_prefix("--breed=")
	if wanted == "all":
		for data: EnemyData in ContentDB.enemies.values():
			_breeds.append(data.id)
		_breeds.sort()
	else:
		for id: String in wanted.split(","):
			_breeds.append(id.strip_edges())
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.get("battlefield") as Battlefield
	if field == null or field.hero == null:
		push_error("[facing] no battlefield or hero")
		get_tree().quit(1)
		return
	for id: String in _breeds:
		var data: EnemyData = ContentDB.enemy(id)
		if data == null:
			push_error("[facing] no breed called %s" % id)
			continue
		# Lane 1 is the east road (its bodies walk west); lane 3 the west road.
		for lane: int in [1, 3]:
			var heading: String = "west" if lane == 1 else "east"
			var head: Vector2 = field.road_spawn_point(lane)
			var inward: Vector2 = -Battlefield.lane_vector(lane)
			# The camera follows the hero, so the hero stands a little way in
			# from the road's head, looking back up it at what is coming.
			field.hero.global_position = head + inward * 340.0
			for _f: int in 30:
				await get_tree().process_frame
			var body: Enemy = field.spawn_enemy(data, lane, 1.0)
			if body == null:
				continue
			for _f: int in 70:
				await get_tree().process_frame
			var path: String = "user://facing_%s_%s.png" % [id, heading]
			get_viewport().get_texture().get_image().save_png(path)
			print("[facing] %s walking %s (flip_h %s) -> %s" % [id, heading,
				str(body.sprite.flip_h), ProjectSettings.globalize_path(path)])
			body.queue_free()
			await get_tree().process_frame
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
