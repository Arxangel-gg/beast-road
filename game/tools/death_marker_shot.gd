extends Node

## Photographs where a player fell: the stone in the air, the stone landed
## beside the remains, the stone dissolving on the revive, and the remains
## alone afterwards. Diagnostic only, never a gate.
##
##   godot --path game res://tools/death_marker_shot.tscn
##
## Four frames land in `user://` as `death_marker_<what>.png`, each with a
## crop around the spot as `death_marker_<what>_close.png`.

var _field: Battlefield = null
var _hero: Hero = null
var _spot: Vector2 = Vector2.ZERO


func _ready() -> void:
	RunState.reset(false, 20260914)
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
	_field = run.get("battlefield") as Battlefield
	_hero = _field.hero if _field != null else null
	if _field == null or _hero == null:
		push_error("[death-marker] no battlefield or hero")
		get_tree().quit(1)
		return
	if _field.wave_director != null:
		_field.wave_director.stop()
	_field.sky().events_enabled = false
	if _field.fog() != null:
		_field.fog().reveal_all()
	var rig: CameraRig = _field.camera as CameraRig
	if rig != null:
		rig.zoom_by(3)
	# On the road a little way from the town, so the stone has ground to land on.
	_spot = _field.road_spawn_point(0).lerp(Vector2.ZERO, 0.6)
	_hero.global_position = _spot
	for _f: int in 40:
		await get_tree().process_frame
	_hero.go_down(_spot)
	await _shoot("falling", 0.16)
	await _shoot("landed", Balance.DEATH_STONE_FALL_SECONDS + 0.5)
	_hero.revive_in_place()
	await _shoot("dissolving", Balance.DEATH_STONE_DISSOLVE_SECONDS * 0.45)
	await _shoot("bones", Balance.DEATH_STONE_DISSOLVE_SECONDS + 0.6)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _shoot(what: String, after: float) -> void:
	var left: float = after
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
	var frame: Image = get_viewport().get_texture().get_image()
	var path: String = "user://death_marker_%s.png" % what
	frame.save_png(path)
	var on_screen: Vector2 = get_viewport().get_canvas_transform() * _spot
	on_screen *= Vector2(frame.get_size()) / get_viewport().get_visible_rect().size
	var box := Rect2i(Vector2i(on_screen) - Vector2i(220, 260), Vector2i(440, 400))
	box = box.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
	if box.size.x > 0 and box.size.y > 0:
		frame.get_region(box).save_png("user://death_marker_%s_close.png" % what)
	print("[death-marker] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
