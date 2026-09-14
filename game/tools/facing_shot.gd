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
	# The fog hides a body the hero has not seen and the road's head is past
	# the hero's sight, so the first version of this photographed an empty road
	# and nobody noticed for a day. Everything is revealed, and the camera is
	# brought in so the body is more than forty pixels tall in the frame.
	if field.fog() != null:
		field.fog().reveal_all()
	var rig: CameraRig = field.camera as CameraRig
	if rig != null:
		rig.zoom_by(3)
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
			var frame: Image = get_viewport().get_texture().get_image()
			frame.save_png(path)
			# And the body alone, cut from the same frame around where it stands,
			# so the facing can be read without hunting a forty-pixel figure.
			# The canvas transform answers in the project's stretched design space
			# and the frame is the window's own size, which on a 1440p monitor is
			# not the same thing, so the point is scaled into the frame.
			var on_screen: Vector2 = get_viewport().get_canvas_transform() * body.global_position
			on_screen *= Vector2(frame.get_size()) / get_viewport().get_visible_rect().size
			var box := Rect2i(Vector2i(on_screen) - Vector2i(180, 200), Vector2i(360, 320))
			box = box.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
			if box.size.x > 0 and box.size.y > 0:
				frame.get_region(box).save_png("user://facing_%s_%s_body.png" % [id, heading])
			print("[facing] %s walking %s (flip_h %s) -> %s" % [id, heading,
				str(body.sprite.flip_h), ProjectSettings.globalize_path(path)])
			print("[facing]   body at %s on screen %s visible %s/%s modulate %s state %s" % [
				str(body.global_position), str(on_screen), str(body.visible),
				str(body.sprite.visible), str(body.modulate), str(body.get("_state"))])
			body.queue_free()
			await get_tree().process_frame
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
