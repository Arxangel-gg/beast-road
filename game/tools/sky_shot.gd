extends Node

## Photographs the sky and the earth's wrath on the real field: a flood, a
## lightning strike, a wildfire, a funnel, a stone coming down and landing,
## and a quake. Diagnostic only, never a gate.
##
##   godot --path game res://tools/sky_shot.tscn
##
## The sheen is a shader, the bolt is drawn for a few frames, the funnel and
## the stone are `_draw` - none of it can be looked at headless, which is how
## the city's health ring shipped broken. Each frame lands in `user://` as
## `sky_shot_<what>.png`.

var _field: Battlefield = null
var _sky: WeatherSky = null


func _ready() -> void:
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
	_field = run.get("battlefield") as Battlefield
	if _field == null or _field.hero == null or _field.sky() == null:
		push_error("[sky] no battlefield, hero or sky")
		get_tree().quit(1)
		return
	_sky = _field.sky()
	var hero: Hero = _field.hero
	hero.global_position = Battlefield.lane_vector(0) * 480.0

	# The flood at its height, without three minutes of sky time.
	RunState.weather_id = "downpour"
	EventBus.weather_changed.emit("downpour")
	_sky.forced_intensity = 1.0
	# Half way first - the shore and the puddles - then the full sheet.
	_sky.set("_flood", 0.45)
	RunState.flood = 0.45
	await _shoot("flood_half", 40)
	for _f: int in 6:
		_sky._process(Balance.FLOOD_RISE_SECONDS / 4.0)
	await _shoot("flood", 40)
	# A strike beside the hero, caught on the frame after: the bolt lives a
	# seventh of a second, and a slow frame after the strike outlives it.
	_sky.strike_at(hero.global_position + Vector2(260.0, -120.0))
	await _shoot("bolt", 1)
	# Dry again for the fire.
	_sky.forced_intensity = 0.0
	for _f: int in 6:
		_sky._process(Balance.FLOOD_DRAIN_SECONDS / 4.0)
	_sky.forced_intensity = -1.0
	RunState.weather_id = "clear"
	EventBus.weather_changed.emit("clear")
	for _f: int in 10:
		await get_tree().process_frame

	# A wildfire in the plants beside the road, a few seconds in.
	var fire: Wildfire = _field.wildfire()
	if fire != null:
		var lit: int = 0
		for plant: Dictionary in (fire.call("_foliage") as Foliage).plants_near(hero.global_position + Vector2(220.0, 60.0), 360.0):
			if lit >= 3:
				break
			if fire.ignite_near(plant["at"], 20.0, 1.0):
				lit += 1
		for _f: int in 6:
			fire._process(0.5)
		await _shoot("wildfire", 30)
		# A funnel through it becomes a fire whirl.
		var whirl: Tornado = _sky.spawn_tornado(hero.global_position + Vector2(-300.0, 60.0),
			hero.global_position + Vector2(900.0, 60.0), 30.0)
		whirl.wander = 0.0
		for _f: int in 42:
			whirl._process(0.1)
		await _shoot("firewhirl", 6)
		whirl.seconds_left = 0.0
		whirl._process(0.1)
		for _f: int in 20:
			await get_tree().process_frame
		# And what it leaves.
		for _f: int in int(Balance.WILDFIRE_BURN_SECONDS * 2.0) + 40:
			fire._process(0.5)
		await _shoot("scorch", 20)
		# The ground the fire left, charged, with a storm core beside it.
		var ground: WrathZones = _field.zones()
		if ground != null:
			ground.clear()
			ground.open("burning_ground", hero.global_position + Vector2(220.0, 60.0), Balance.ZONE_BURN_RADIUS)
			ground.open("storm_core", hero.global_position + Vector2(-320.0, -60.0), Balance.ZONE_STORM_RADIUS)
			await _shoot("zones", 40)
			ground.clear()

	# A funnel walking past.
	var funnel: Tornado = _sky.spawn_tornado(hero.global_position + Vector2(-420.0, 160.0),
		hero.global_position + Vector2(420.0, -100.0), 30.0)
	for _f: int in 20:
		funnel._process(0.05)
	await _shoot("tornado", 10)
	funnel.seconds_left = 0.0
	funnel._process(0.1)
	for _f: int in 20:
		await get_tree().process_frame

	# A stone: the shadow with the streak, then the blast.
	var stone: Meteor = _sky.drop_meteor(hero.global_position + Vector2(300.0, -60.0))
	stone._process(Balance.METEOR_WARNING - Balance.METEOR_FALL * 0.4)
	await _shoot("meteor", 1)
	stone._process(Balance.METEOR_FALL)
	await _shoot("impact", 3)
	for _f: int in 40:
		await get_tree().process_frame

	# The ground shaking.
	_sky.quake(1.0)
	await _shoot("quake", 12)

	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)


func _shoot(what: String, settle_frames: int) -> void:
	for _f: int in settle_frames:
		await get_tree().process_frame
	var path: String = "user://sky_shot_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("[sky] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
