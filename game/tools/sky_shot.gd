extends Node

## Photographs the sky's weather on the real field: a flooded road, and a
## lightning strike beside the hero. Diagnostic only, never a gate.
##
##   godot --path game res://tools/sky_shot.tscn
##
## The flood sheen is a shader and the bolt is drawn for a few frames; neither
## can be looked at headless, which is how the city's health ring shipped
## broken. Two frames land in `user://`: `sky_shot_flood.png` with the water at
## its height, and `sky_shot_bolt.png` on the frame after a strike.

func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.get("battlefield") as Battlefield
	if field == null or field.hero == null or field.sky() == null:
		push_error("[sky] no battlefield, hero or sky")
		get_tree().quit(1)
		return
	var sky: WeatherSky = field.sky()
	RunState.weather_id = "downpour"
	EventBus.weather_changed.emit("downpour")
	field.hero.global_position = Battlefield.lane_vector(0) * 480.0
	# A flood at its height, without waiting three minutes of sky time for it.
	sky.forced_intensity = 1.0
	for _f: int in 6:
		sky._process(Balance.FLOOD_RISE_SECONDS / 4.0)
	for _f: int in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://sky_shot_flood.png")
	print("[sky] flood %.2f -> %s" % [sky.flood(),
		ProjectSettings.globalize_path("user://sky_shot_flood.png")])
	# And a strike a little way from the hero, caught on the frame after.
	sky.strike_at(field.hero.global_position + Vector2(260.0, -120.0))
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://sky_shot_bolt.png")
	print("[sky] strike -> %s" % ProjectSettings.globalize_path("user://sky_shot_bolt.png"))
	for _f: int in 30:
		await get_tree().process_frame
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
