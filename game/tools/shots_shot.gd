extends Node

## Photographs every head an enemy shot can wear, which no headless gate can see.
##
##   godot --path game res://tools/shots_shot.tscn
##
## Twelve projectiles on a plate, one per `EnemyShotData.Head`, each painted
## in a breed's own colours and caught mid-flight - the drawing is what the
## owner asked for ("each enemy should have its own unique projectiles ... max
## perfect polished ultra juicy"), and `enemy_shot_check` can only prove that
## each one lands. Written to `user://shots_shot.png`; look at it before
## believing the gate.

const SIZE := Vector2i(1200, 420)
## One shot per head, in a breed's own colours, so the sheet reads as the
## roster's shots rather than as a palette.
const SHOTS: Array[String] = [
	"drowned_choir_marshal_bolt", "fog_lantern_lantern_bolt", "thorn_archer_thorn_arrow",
	"glass_chanter_glass_dart", "gatekeeper_gate_volley", "anchor_cantor_anchor_hex",
	"marsh_piper_piper_hex", "wolf_rider_wolf_bola", "ember_shaman_cinder_bolt",
	"crown_herald_herald_blast", "bell_priest_peal", "rustmother_rust_volley",
]


func _ready() -> void:
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260921)
	MetaState.hold_saves()
	var plate := ColorRect.new()
	plate.color = Color(0.13, 0.15, 0.12)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)
	var stage := Node2D.new()
	stage.scale = Vector2(2.2, 2.2)
	add_child(stage)
	var flying: Array[EnemyProjectile] = []
	for index: int in SHOTS.size():
		var shot: EnemyShotData = ContentDB.enemy_shots.get(SHOTS[index]) as EnemyShotData
		var column: int = index % 6
		var row: int = index / 6
		var origin := Vector2(30.0 + float(column) * 88.0, 60.0 + float(row) * 90.0)
		var bolt := (load("res://scenes/battlefield/enemy_projectile.gd").new()) as EnemyProjectile
		if shot != null:
			bolt.tint = shot.tint
			bolt.core_tint = shot.core_tint if shot.core_tint.a > 0.0 else shot.tint
			bolt.shell_tint = shot.shell_tint if shot.shell_tint.a > 0.0 else shot.tint.darkened(0.72)
			bolt.head = int(shot.head)
			bolt.head_scale = shot.head_scale
			bolt.spin = shot.spin
			bolt.wobble = shot.wobble
			bolt.trail_scale = shot.trail_scale
			bolt.pace_scale = shot.pace
		# Into the scaled stage first, then aimed in global space: configured
		# before it had a parent, a shot's local origin became a global one and
		# every column past the second stood off the plate.
		stage.add_child(bolt)
		bolt.configure_toward(stage.to_global(origin + Vector2(400.0, 0.0)), stage.to_global(origin))
		flying.append(bolt)
		var tag := Label.new()
		tag.text = "%s\n%s" % [SHOTS[index].get_slice("_", 0), EnemyShotData.Head.keys()[int(shot.head) if shot != null else 0]]
		tag.position = origin + Vector2(-24.0, 18.0)
		tag.add_theme_font_size_override("font_size", 7)
		stage.add_child(tag)
	# Let each fly a third of a second so the trail exists, then hold it.
	var waited: float = 0.0
	while waited < 0.32:
		await get_tree().process_frame
		waited += get_process_delta_time()
	for bolt: EnemyProjectile in flying:
		if is_instance_valid(bolt):
			bolt.set_process(false)
	for _frame: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path("user://shots_shot.png")
	get_viewport().get_texture().get_image().save_png(path)
	print("shots -> %s" % path)
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 6:
		await get_tree().process_frame
	get_tree().quit(0)
