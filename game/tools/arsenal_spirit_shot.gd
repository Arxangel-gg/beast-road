extends Node

## Photographs the Arsenal's spirits leaving the bodies that fell (owner,
## 2026-10-08: "some arsenal/augments give spirits or something but I haven't
## seen those happen"). Three spirit cards held in a rift, a ring of bodies, one
## felled at a time, and photographs as each spirit rises and hunts.
##
##   godot --path game res://tools/arsenal_spirit_shot.tscn
##
## Diagnostic only, never a gate: `arsenal_check` holds what the spirits do.

const SIZE := Vector2i(1600, 900)


func _ready() -> void:
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	MetaState.hold_saves()
	RunState.act = 3
	RunState.road_cards = ["pyre_spirits", "marrow_seekers", "frost_wraiths"] as Array[String]
	var rift: RiftArena = (load("res://scenes/rift/rift_arena.tscn") as PackedScene).instantiate() as RiftArena
	add_child(rift)
	for _f: int in 3:
		await get_tree().process_frame
	rift.open(RiftArena.Kind.RIFT, Vector2(300.0, -200.0))
	for _f: int in 20:
		await get_tree().process_frame
	var hero: Hero = rift.hero
	var bodies: Array[Enemy] = []
	for index: int in 8:
		var angle: float = TAU * float(index) / 8.0
		var body: Enemy = rift._spawn(ContentDB.enemy("bogkin"),
			hero.global_position + Vector2.from_angle(angle) * Vector2(300.0, 200.0), 60.0)
		if body != null:
			bodies.append(body)
	var shot: int = 0
	for victim: int in 3:
		if victim >= bodies.size() or not is_instance_valid(bodies[victim]):
			continue
		DamageLedger.credit_as(DamageLedger.OTHER)
		bodies[victim].take_damage(1000000.0, bodies[victim].global_position, 0.0)
		for wait: float in [0.18, 0.22, 0.3]:
			var started: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - started < int(wait * 1000.0):
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			var path: String = "user://arsenal_spirit_%d.png" % shot
			image.save_png(path)
			print("[arsenal-spirit] -> ", ProjectSettings.globalize_path(path))
			shot += 1
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	get_tree().quit()
