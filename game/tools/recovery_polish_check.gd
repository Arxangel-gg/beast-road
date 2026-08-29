extends Node

## Release gate for the two recovery systems and their presentation contract.
## Uses only the in-memory run singleton and never writes the player's save.

var _failures: PackedStringArray = []


func _ready() -> void:
	await get_tree().process_frame
	_test_content_and_art()
	_test_last_scar_success()
	_test_last_scar_failures()
	_test_last_scar_guest_mirror()
	await _test_mender_pity_and_healing()
	_test_shader_budget()

	if _failures.is_empty():
		print("[recovery-polish] PASS — bounded recovery, run-local Wound reward, "
			+ "replication state and quality-scaled polish")
	else:
		for failure: String in _failures:
			push_error("[recovery-polish] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_content_and_art() -> void:
	var oath: Resource = ContentDB.run_challenge("last_scar")
	var spark: Resource = ContentDB.recovery_drop(Balance.MENDER_SPARK_ID)
	_check(oath != null, "Oath of the Last Scar must be data-driven content")
	_check(spark != null, "Mender's Spark must be data-driven content")
	if oath != null:
		for key: String in ["offer_line", "condition_line", "reward_line",
				"accepted_line", "pursuer_line", "success_line", "button_line",
				"waiting_line", "sworn_line", "ration_blocked_line",
				"active_status", "pursuer_hunt_status",
				"pursuer_defeated_status"]:
			_check(not String(oath.get(key)).is_empty(),
				"Last Scar content is missing '%s'" % key)
		_check_asset(String(oath.call("get_sprite_path")), Vector2i(128, 128))
	if spark != null:
		for key: String in ["pickup_line", "broken_line", "active_status"]:
			_check(not String(spark.get(key)).is_empty(),
				"Mender's Spark content is missing '%s'" % key)
		_check_asset(String(spark.call("get_sprite_path")), Vector2i(48, 48))
	_check(EventBus.has_signal("coop_last_scar_accepted")
		and EventBus.has_signal("coop_last_scar_resolved"),
		"Last Scar authority facts must remain in the co-op contract")
	_check(EventBus.has_signal("mender_spark_collected"),
		"Mender pickup feedback must remain an EventBus fact")


func _qualify_for_last_scar(seed: int) -> void:
	RunState.reset(false, seed)
	RunState.act = Balance.LAST_SCAR_OFFER_ACT
	RunState.wounds_suffered = 1


func _test_last_scar_success() -> void:
	_qualify_for_last_scar(7281)
	_check(RunState.can_offer_last_scar(),
		"a wounded run must receive the once-per-run Act II offer")
	_check(RunState.accept_last_scar(), "an eligible Last Scar offer must be accepted")
	_check(not RunState.accept_last_scar(), "the vow cannot be accepted twice")
	RunState.start_last_scar_road()
	_check(RunState.last_scar_active and RunState.last_scar_locks_rations(),
		"the chosen sworn road must activate the no-ration rule")
	RunState.mark_last_scar_pursuer_spawned()
	RunState.mark_last_scar_pursuer_defeated()
	EventBus.town_health_changed.emit(72.0, 100.0)
	var result: Dictionary = RunState.resolve_last_scar_road()
	_check(bool(result.get("success", false)),
		"a clean sworn road with its pursuer defeated must succeed")
	_check(RunState.max_wounds() == Balance.HERO_MAX_WOUNDS
		+ Balance.LAST_SCAR_MAX_WOUND_BONUS,
		"the reward must add exactly one run-local maximum Wound")
	_check(not RunState.last_scar_locks_rations(),
		"field rations must unlock when the vow settles")


func _test_last_scar_failures() -> void:
	_qualify_for_last_scar(7282)
	RunState.accept_last_scar()
	RunState.start_last_scar_road()
	RunState.mark_last_scar_pursuer_spawned()
	RunState.mark_last_scar_pursuer_defeated()
	RunState.add_wound()
	var wound_result: Dictionary = RunState.resolve_last_scar_road()
	_check(String(wound_result.get("reason", "")) == "wound"
		and RunState.max_wounds() == Balance.HERO_MAX_WOUNDS,
		"taking a Wound must break the vow without persistent power")

	_qualify_for_last_scar(7283)
	RunState.accept_last_scar()
	RunState.start_last_scar_road()
	RunState.mark_last_scar_pursuer_spawned()
	EventBus.town_health_changed.emit(55.0, 100.0)
	var town_result: Dictionary = RunState.resolve_last_scar_road()
	_check(String(town_result.get("reason", "")) == "town",
		"the minimum Town Hall health across the road must settle the vow")

	_qualify_for_last_scar(7284)
	RunState.accept_last_scar()
	RunState.start_last_scar_road()
	var hunt_result: Dictionary = RunState.resolve_last_scar_road()
	_check(String(hunt_result.get("reason", "")) == "pursuer",
		"letting the marked pursuer escape must break the vow")


func _test_last_scar_guest_mirror() -> void:
	RunState.reset(false, 7285)
	RunState.mirror_accept_last_scar()
	RunState.start_last_scar_road()
	RunState.mirror_last_scar_resolution(true, "complete",
		Balance.HERO_MAX_WOUNDS + Balance.LAST_SCAR_MAX_WOUND_BONUS)
	_check(RunState.last_scar_resolved and not RunState.last_scar_active,
		"a guest must settle the host-authored vow state")
	_check(RunState.max_wounds() == Balance.HERO_MAX_WOUNDS
		+ Balance.LAST_SCAR_MAX_WOUND_BONUS,
		"a guest must mirror the host-authored maximum Wound reward")


func _test_mender_pity_and_healing() -> void:
	RunState.reset(false, 7286)
	var dropped: bool = false
	for _attempt: int in Balance.MENDER_SPARK_PITY_ELITES:
		dropped = RunState.roll_mender_spark()
		if dropped:
			break
	_check(dropped, "Mender's Spark pity must produce a drop by its elite cap")
	_check(not RunState.can_roll_mender_spark(),
		"only one Mender's Spark may be offered in an act")

	var packed: PackedScene = load("res://scenes/hero/hero.tscn")
	var hero: Hero = packed.instantiate() as Hero
	add_child(hero)
	await get_tree().process_frame
	hero.health.take_damage(hero.health.max_hp * 0.60, Vector2.RIGHT)
	var wounded_hp: float = hero.health.current_hp
	hero.apply_mender_spark()
	_check(hero.mender_active(), "collecting Mender's Spark must start regeneration")
	_check(hero.health.current_hp > wounded_hp,
		"Mender's Spark must restore an immediate, meaningful health slice")
	hero._tick_timers(Balance.MENDER_SPARK_BREAK_GRACE * 0.5)
	hero.health.take_damage(1.0, Vector2.RIGHT)
	_check(hero.mender_active(), "damage during the brief pickup grace must not break it")
	hero._tick_timers(Balance.MENDER_SPARK_BREAK_GRACE)
	hero.health.take_damage(1.0, Vector2.RIGHT)
	_check(not hero.mender_active(),
		"damage after the grace window must break regeneration")
	hero.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_shader_budget() -> void:
	var shader_paths: PackedStringArray = [
		"res://scripts/shaders/actor_polish.gdshader",
		"res://scripts/shaders/loot_polish.gdshader",
		"res://scripts/shaders/boss_phase_break.gdshader",
	]
	for path: String in shader_paths:
		_check(ResourceLoader.exists(path), "missing polish shader: %s" % path)
		var shader: Shader = load(path) as Shader
		_check(shader != null and not shader.code.is_empty(),
			"polish shader must compile as a Shader resource: %s" % path)
	var actor: Shader = load(shader_paths[0]) as Shader
	if actor != null:
		_check(actor.code.contains("left_a") and actor.code.contains("right_a")
			and actor.code.contains("up_a") and actor.code.contains("down_a"),
			"actor readability must remain the approved four-sample outline")
	for region: String in ["jungle", "desert", "snow"]:
		var terrain_path: String = "res://art/terrain/terrain_%s.png" % region
		_check_asset(terrain_path, Vector2i(512, 512))
		var road_path: String = "res://art/battlefield/road_surface_%s.png" % region
		_check_asset(road_path, Vector2i(512, 512))
		if ResourceLoader.exists(terrain_path):
			var terrain_image: Image = (load(terrain_path) as Texture2D).get_image()
			for offset: int in range(0, 512, 17):
				_check(terrain_image.get_pixel(0, offset).is_equal_approx(
					terrain_image.get_pixel(511, offset)),
					"%s must repeat cleanly across its horizontal seam" % terrain_path)
				_check(terrain_image.get_pixel(offset, 0).is_equal_approx(
					terrain_image.get_pixel(offset, 511)),
					"%s must repeat cleanly across its vertical seam" % terrain_path)
		if ResourceLoader.exists(road_path):
			var road_image: Image = (load(road_path) as Texture2D).get_image()
			for offset: int in range(0, 512, 17):
				_check(road_image.get_pixel(0, offset).is_equal_approx(
					road_image.get_pixel(511, offset)),
					"%s must repeat cleanly across its horizontal seam" % road_path)
				_check(road_image.get_pixel(offset, 0).is_equal_approx(
					road_image.get_pixel(offset, 511)),
					"%s must repeat cleanly across its vertical seam" % road_path)
	var road_material: ShaderMaterial = PathBlend.material_for_surface(
		"jungle", Vector2(1824.0, 1824.0))
	_check(is_equal_approx(float(road_material.get_shader_parameter("use_surface")), 1.0),
		"the baked road mask must receive its regional surface material")
	var repeat_value: Vector2 = road_material.get_shader_parameter("surface_repeat")
	_check(repeat_value.x > 1.0 and repeat_value.y > 1.0,
		"regional road detail must map continuously across the whole baked field")
	PathBlend.set_weather("downpour")
	if Graphics.polish_shaders():
		_check(is_equal_approx(float(road_material.get_shader_parameter(
			"wet_strength")), Balance.PATH_WET_SHEEN),
			"downpour must drive wet sheen on the baked road surface")
	PathBlend.set_weather("clear")
	_check(is_zero_approx(float(road_material.get_shader_parameter("wet_strength"))),
		"wet-road sheen must clear with the weather")
	_check(Balance.BLOOD_GROUND_LIFE >= 600.0,
		"ground blood must preserve the previous ten minutes")
	_check(Balance.LOOT_PICKUP_DISSOLVE_TIME > 0.0
		and Balance.BOSS_PHASE_CRACK_DURATION > 0.0,
		"pickup dissolve and phase-break polish must have visible lifetimes")


func _check_asset(path: String, expected: Vector2i) -> void:
	_check(ResourceLoader.exists(path), "missing production asset: %s" % path)
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	_check(texture != null, "asset must load as a texture: %s" % path)
	if texture == null:
		return
	_check(Vector2i(texture.get_width(), texture.get_height()) == expected,
		"%s must be %dx%d" % [path, expected.x, expected.y])
	var image: Image = texture.get_image()
	if image != null:
		var marker: Color = image.get_pixel(0, 0)
		_check(not (marker.r > 0.99 and marker.g < 0.01 and marker.b > 0.99),
			"asset is still a magenta-marked placeholder: %s" % path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
