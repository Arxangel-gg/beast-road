extends Node

## Photographs Brutal blood and the ground's scars (2026-10-01): pools where a
## fight was thickest, a body standing in one and stained to its shins, and the
## ground broken by a slam, a crack, a crater and a quake - at play zoom, then
## the pools again after they have crept.
##
##   godot --path game res://tools/brutal_shot.tscn
##
## Windowed, because a headless display has no pixels. Diagnostic only:
## `brutal_blood_check` holds what the blood and the scars do.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[brutal-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	# The fog off, so the picture is of the ground rather than of what is seen.
	Graphics.set_switch(Graphics.KEY_FOG, false)
	RunState.reset(false, 20261016)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 30:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.town.health.floor_hp = field.town.health.max_hp * 0.5
	var faded: float = 0.0
	while faded < 5.0:
		await get_tree().process_frame
		faded += get_process_delta_time()
	var hero: Hero = field.hero
	hero.health.floor_hp = hero.health.max_hp
	var spot: Vector2 = hero.global_position + Vector2(260.0, -60.0)
	field.camera.set_zoom_share(0.8)
	# The ground broken first, so the blood lies over it.
	var scars: GroundScars = field.scars()
	scars.dent(spot + Vector2(-240.0, 40.0), 70.0, 0.55)
	scars.crack(spot + Vector2(-320.0, -140.0), spot + Vector2(80.0, -200.0), 14.0, 0.5)
	scars.crater(spot + Vector2(260.0, 120.0), 90.0)
	scars.quake(spot + Vector2(-60.0, 260.0), 600.0, 0.8)
	# A fight's worth of blood where the Warden is about to stand.
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	var blood: BloodField = Vfx.blood_field()
	for _i: int in 70:
		blood.splat(spot + Vector2(dice.randf_range(-50.0, 50.0), dice.randf_range(-30.0, 30.0)),
			Vector2.from_angle(dice.randf() * TAU), Balance.VFX_BLOOD_DEATH_SIZE, dice)
	for _i: int in 30:
		blood.splat(spot + Vector2(-240.0, 40.0) + Vector2(dice.randf_range(-25.0, 25.0), dice.randf_range(-15.0, 15.0)),
			Vector2.from_angle(dice.randf() * TAU), Balance.VFX_BLOOD_HIT_SIZE, dice)
	var body: Enemy = field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 1.0, 0.001, 0.001)
	await get_tree().process_frame
	body.global_position = spot + Vector2(10.0, 0.0)
	for _f: int in 4:
		await get_tree().process_frame
	body.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = spot + Vector2(-60.0, 10.0)
	for second: int in 4:
		var waited: float = 0.0
		while waited < (0.6 if second == 0 else 4.0):
			await get_tree().process_frame
			waited += get_process_delta_time()
		# The disabled body's own blood tick does not run: stain it by hand,
		# through the same door its tick would.
		BloodStain.wade(body.sprite.material as ShaderMaterial, body.sprite, body.global_position,
			Vfx.blood_wade(body.global_position))
		BloodStain.wade(hero.sprite.material as ShaderMaterial, hero.sprite, hero.global_position,
			maxf(Vfx.blood_wade(hero.global_position), 14.0), hero.frames.feet_row())
		for who: Node2D in [hero, body]:
			var worn := (who.get("sprite") as Sprite2D).material as ShaderMaterial
			print("[brutal-shot] ", who.name, " wears ", worn.shader.resource_path if worn != null and worn.shader != null else "nothing",
				" band ", worn.get_shader_parameter("wade_band") if worn != null else "-",
				" wade ", Vfx.blood_wade(who.global_position))
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "user://brutal_%d.png" % second
		image.save_png(path)
		print("[brutal-shot] -> ", ProjectSettings.globalize_path(path),
			"  pool depth ", snappedf(Vfx.blood_field().pools_if_any().depth_at(spot), 0.01))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	UserSettings.set_blood_level(UserSettings.BLOOD_LOW)
	run.queue_free()
	for _frame: int in 10:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	get_tree().quit(0)
