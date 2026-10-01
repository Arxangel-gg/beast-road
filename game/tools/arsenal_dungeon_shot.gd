extends Node

## Photographs the Arsenal at a Warden's side in a dungeon, so its bolts and
## orbits can be looked at where the owner saw them (2026-09-30: "Projectiles
## from arsenals looked like they might have been direction flipped in
## dungeons"). Seekers and orbits armed, a ring of bodies around the Warden,
## and four photographs a fifth of a second apart.
##
##   godot --path game res://tools/arsenal_dungeon_shot.tscn
##
## Diagnostic only, never a gate: `arsenal_check` holds what the weapons do.

const SIZE := Vector2i(1600, 900)


func _ready() -> void:
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	MetaState.hold_saves()
	RunState.act = 3
	RunState.road_cards = ["seeking_flames", "hurled_stones", "ice_needles", "ember_wisps",
		"gale_blades"] as Array[String]
	var rift: RiftArena = (load("res://scenes/rift/rift_arena.tscn") as PackedScene).instantiate() as RiftArena
	add_child(rift)
	for _f: int in 3:
		await get_tree().process_frame
	rift.open(RiftArena.Kind.DUNGEON, Vector2(300.0, -200.0))
	for _f: int in 20:
		await get_tree().process_frame
	var hero: Hero = rift.hero
	for index: int in 6:
		var angle: float = TAU * float(index) / 6.0
		rift._spawn(ContentDB.enemy("bogkin"), hero.global_position + Vector2.from_angle(angle) * 260.0, 60.0)
	for shot: int in 4:
		var started: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < 220:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "user://arsenal_dungeon_%d.png" % shot
		image.save_png(path)
		print("[arsenal-dungeon] -> ", ProjectSettings.globalize_path(path))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	get_tree().quit()
