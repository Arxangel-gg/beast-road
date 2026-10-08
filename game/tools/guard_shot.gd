extends Node

## Photographs a raised shield four ways, with its guard on the ground (owner,
## 2026-10-08: "Unable to raise shield with Y or standing still" - it rose, and
## nothing on screen said so).
##
##   godot --path game res://tools/guard_shot.tscn
##
## Diagnostic only, never a gate: `durability_check` holds the guard.

const SIZE := Vector2i(1600, 900)


class Held extends HeroInput:
	var hold: int = 0
	var walk: Vector2 = Vector2.ZERO

	func _read_press(_button: int) -> bool:
		return false

	func _read_hold(mask: int) -> bool:
		return hold & mask != 0

	func move() -> Vector2:
		return walk

	func is_local() -> bool:
		return true


func _ready() -> void:
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	MetaState.hold_saves()
	RunState.reset(false, 20261008)
	MetaState.stash = []
	MetaState.equipped = {}
	for id: String in [_one_hander(), "ironbound_kite"]:
		var piece: Dictionary = Stash.make(id, 4, 3)
		MetaState.stash.append(piece)
		MetaState.equipped[ContentDB.gear(id).slot] = Stash.uid(piece)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 20:
		await get_tree().process_frame
	run.battlefield.wave_director.stop()
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var hero: Hero = run.battlefield.hero
	var hands := Held.new(hero)
	hero.input = hands
	hero.call("_dress_warden")
	hero.global_position = Vector2(2000.0, 1700.0)
	var camera: Camera2D = get_viewport().get_camera_2d()
	var shot: int = 0
	for heading: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		hands.hold = 0
		hands.walk = heading
		await _seconds(0.25)
		hands.walk = Vector2.ZERO
		# Standing still, the Warden faces the aim, not the last step.
		hero.set("_aim", heading)
		hands.hold = HeroInput.HOLD_GUARD
		await _seconds(0.6)
		if camera != null:
			camera.zoom = Vector2(2.4, 2.4)
			camera.global_position = hero.global_position + Vector2(0.0, -40.0)
		await RenderingServer.frame_post_draw
		var path: String = "user://guard_%d.png" % shot
		get_viewport().get_texture().get_image().save_png(path)
		print("[guard-shot] -> ", ProjectSettings.globalize_path(path))
		shot += 1
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	get_tree().quit()


func _one_hander() -> String:
	for kind: GearData in ContentDB.gear_sorted():
		if kind != null and kind.slot == GearData.Slot.WEAPON and kind.grip == GearData.Grip.ONE_HAND \
				and not kind.trophy:
			return kind.id
	return ""


func _seconds(span: float) -> void:
	var waited: float = 0.0
	while waited < span:
		await get_tree().process_frame
		waited += get_process_delta_time()
