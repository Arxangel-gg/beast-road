extends Node

## The ground's own weather does what it says: sources add with falloff and
## stack, heat spreads and cools, rain wets everything and hot ground dries,
## cells sleep when nothing is happening to them, the bands cross once per
## crossing, the guest eases toward what it is told and never simulates, and
## the things that used to read one number for the whole road read the
## ground under them instead.
##
##   godot --headless --path game res://tools/climate_check.tscn
##
## Every read is measured on the real battlefield's climate, because each half
## has a way of being a lie that would not error: a source that overwrites
## rather than adds, a falloff that is a step, a cell that never sleeps, a
## band told every tick, a well that still evaporates by the sky alone.

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _climate: Climate = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	_climate = _field.climate() if _field != null else null
	_check(_climate != null, "the battlefield must stand a climate up")
	if _climate != null and _field.sky() != null:
		_field.sky().events_enabled = false
		_field.sky().forced_intensity = 0.0
		_test_the_grid_covers_the_field()
		_test_sources_add_with_falloff()
		_test_heat_spreads_and_cools()
		_test_rain_wets_and_heat_dries()
		_test_cells_sleep()
		_test_bands_cross_once()
		await _test_the_guest_is_told()
		await _test_the_wells_read_the_ground()
		await _test_the_fire_reads_the_ground()
		_test_the_picture()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[climate] PASS - %d checks: the grid, the sources, the spread, the rain, the "
			% _checks + "sleep, the bands, the guest, the wells, the fire and the picture")
	else:
		for failure: String in _failures:
			push_error("[climate] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _tick(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_climate._tick(Balance.CLIMATE_TICK)
		left -= Balance.CLIMATE_TICK


func _test_the_grid_covers_the_field() -> void:
	var across: int = _climate.across()
	_check(across >= 4 and _climate.count() == across * across, "a grid of %d cells" % _climate.count())
	var far: Vector2 = Vector2.ONE * (_climate.half_extent - 1.0)
	_check(_climate.cell_of(-far) == 0, "the top-left corner is cell 0")
	_check(_climate.cell_of(far) == _climate.count() - 1, "the bottom-right corner is the last cell")
	_check(_climate.cell_of(Vector2.ONE * 1e6) == _climate.count() - 1, "a point off the field clamps to the grid")
	_check(is_equal_approx(_climate.temperature_at(Vector2.ZERO), RunState.temperature),
		"calm ground is the sky's temperature")
	_check(is_equal_approx(_climate.wetness_at(Vector2(700.0, -400.0)), Balance.CLIMATE_WET_REST),
		"calm ground stands at rest wetness")
	_check(_climate.soil_at(Vector2.ZERO) == Climate.Soil.NORMAL, "the soil byte is reserved and NORMAL")


func _test_sources_add_with_falloff() -> void:
	_climate.reset()
	var at: Vector2 = _climate.cell_centre(_climate.cell_of(Vector2(600.0, 600.0)))
	_climate.add_heat(at, 10.0)
	var centre: float = _climate.heat_at(at)
	_check(centre > 8.0, "ten degrees put at a cell's centre reads %.1f there" % centre)
	var beside: float = _climate.heat_at(at + Vector2(Balance.CLIMATE_SOURCE_RADIUS * 0.6, 0.0))
	_check(beside > 0.0 and beside < centre, "the heat should fall off toward the edge (%.1f against %.1f)" % [beside, centre])
	_check(is_zero_approx(_climate.heat_at(at + Vector2(Balance.CLIMATE_SOURCE_RADIUS * 3.0, 0.0))),
		"three radii away the ground is untouched")
	# Additive: a second tower beside the first makes a hotter spot.
	_climate.add_heat(at, 10.0)
	_check(_climate.heat_at(at) > centre * 1.8, "a second source on the same ground did not stack (%.1f)" % _climate.heat_at(at))
	_climate.add_heat(at, -30.0)
	_check(_climate.heat_at(at) < 0.0, "cold is heat with the sign turned")
	_climate.reset()
	_climate.add_wet(at, 0.5)
	_check(_climate.wetness_at(at) > Balance.CLIMATE_WET_REST + 0.3, "water put on the ground did not wet it")
	_climate.reset()


func _test_heat_spreads_and_cools() -> void:
	_climate.reset()
	var index: int = _climate.cell_of(Vector2(-800.0, 300.0))
	var at: Vector2 = _climate.cell_centre(index)
	var next_door: Vector2 = _climate.cell_centre(index + 1)
	_climate.add_heat(at, 30.0, 10.0)
	var before: float = _climate.heat_at(at)
	_check(is_zero_approx(_climate.heat_at(next_door)), "a source with no reach warmed the next cell")
	_tick(10.0)
	_check(_climate.heat_at(next_door) > 0.0, "ten seconds on, the next cell has none of the heat")
	_check(_climate.heat_at(at) < before, "the source cell never cooled")
	_tick(Balance.CLIMATE_HEAT_TAU * 6.0)
	_check(absf(_climate.heat_at(at)) < 0.5, "six half-lives on the ground is still %.2f warm" % _climate.heat_at(at))
	_climate.reset()


func _test_rain_wets_and_heat_dries() -> void:
	_climate.reset()
	RunState.rain_intensity = 1.0
	_tick(40.0)
	var points: Array[Vector2] = [Vector2.ZERO, Vector2(1500.0, -1200.0), Vector2(-2000.0, 1800.0)]
	for at: Vector2 in points:
		_check(_climate.wetness_at(at) > 0.8, "forty seconds of downpour left %s at %.2f" % [at, _climate.wetness_at(at)])
	RunState.rain_intensity = 0.0
	_tick(Balance.CLIMATE_WET_TAU * 4.0)
	_check(_climate.wetness_at(Vector2.ZERO) < Balance.CLIMATE_WET_REST + 0.1,
		"long after the rain the ground is still %.2f wet" % _climate.wetness_at(Vector2.ZERO))
	# Hot ground dries faster than cool ground.
	_climate.reset()
	var hot: Vector2 = _climate.cell_centre(_climate.cell_of(Vector2(900.0, 900.0)))
	var cool: Vector2 = _climate.cell_centre(_climate.cell_of(Vector2(-900.0, -900.0)))
	_climate.add_wet(hot, 0.6, 10.0)
	_climate.add_wet(cool, 0.6, 10.0)
	_climate.add_heat(hot, 25.0, 10.0)
	_tick(30.0)
	_check(_climate.wetness_at(hot) < _climate.wetness_at(cool),
		"hot ground (%.2f) should dry faster than cool (%.2f)" % [_climate.wetness_at(hot), _climate.wetness_at(cool)])
	# A flood is standing water everywhere.
	_climate.reset()
	RunState.flood = 0.9
	_tick(1.0)
	_check(_climate.wetness_at(Vector2(400.0, -1300.0)) > 0.85, "a flood did not wet the ground under it")
	RunState.flood = 0.0
	_climate.reset()


func _test_cells_sleep() -> void:
	_climate.reset()
	_check(_climate.awake_count() == 0, "a calm field has %d cells awake" % _climate.awake_count())
	_climate.add_heat(Vector2(500.0, 500.0), 12.0)
	_check(_climate.awake_count() > 0, "a source woke nothing")
	_tick(Balance.CLIMATE_HEAT_TAU * 8.0)
	_check(_climate.awake_count() == 0, "long after the source, %d cells are still awake" % _climate.awake_count())
	_climate.reset()


func _test_bands_cross_once() -> void:
	_climate.reset()
	var told: int = _climate.bands_told
	var at: Vector2 = _climate.cell_centre(_climate.cell_of(Vector2(-600.0, 900.0)))
	_check(_climate.temp_band_at(at) == Climate.TempBand.NORMAL, "calm ground is a NORMAL band")
	_climate.add_heat(at, 40.0, 10.0)
	_tick(Balance.CLIMATE_TICK)
	_check(_climate.temp_band_at(at) >= Climate.TempBand.HOT, "forty degrees on a cell is not HOT")
	var crossings: int = _climate.bands_told - told
	_check(crossings == 1, "one crossing told %d times" % crossings)
	told = _climate.bands_told
	_tick(2.0)
	_check(_climate.bands_told == told or _climate.temp_band_at(at) != Climate.TempBand.SCORCHING,
		"a cell that stayed in its band was told again")
	_tick(Balance.CLIMATE_HEAT_TAU * 8.0)
	_check(_climate.temp_band_at(at) == Climate.TempBand.NORMAL, "cooled ground did not come back to NORMAL")
	_check(_climate.bands_told > told, "coming back to NORMAL was not told")
	_climate.reset()


func _test_the_guest_is_told() -> void:
	var mirror := Climate.new()
	mirror.half_extent = _climate.half_extent
	add_child(mirror)
	await get_tree().process_frame
	mirror.set("_mirror", true)
	var index: int = mirror.cell_of(Vector2(300.0, 300.0))
	var at: Vector2 = mirror.cell_centre(index)
	mirror.add_heat(at, 30.0)
	_check(is_zero_approx(mirror.heat_at(at)), "a guest heated its own ground")
	EventBus.coop_climate_band_changed.emit(index, Climate.TempBand.HOT, Climate.WetBand.WET)
	_check(mirror.temp_band_at(at) == Climate.TempBand.HOT, "a guest did not take the band it was told")
	var first: float = mirror.heat_at(at)
	mirror.call("_ease_toward_bands", Balance.CLIMATE_TICK)
	var eased: float = mirror.heat_at(at)
	_check(eased > first and eased < float(Balance.CLIMATE_BAND_HEAT[Climate.TempBand.HOT]),
		"a guest should ease toward the band, not snap (%.1f)" % eased)
	for _i: int in 200:
		mirror.call("_ease_toward_bands", Balance.CLIMATE_TICK)
	_check(absf(mirror.heat_at(at) - float(Balance.CLIMATE_BAND_HEAT[Climate.TempBand.HOT])) < 0.5,
		"a guest never arrived at the band's figure (%.1f)" % mirror.heat_at(at))
	_check(mirror.wetness_at(at) > 0.6, "a guest's wet band did not take")
	mirror.queue_free()
	await get_tree().process_frame


## A well beside hot ground evaporates; one on cool ground does not, whatever
## the sky says.
func _test_the_wells_read_the_ground() -> void:
	_climate.reset()
	RunState.gain_every_currency(20000)
	var data: TowerData = ContentDB.tower("healing_well")
	_check(data != null, "a well to read the ground")
	if data == null:
		return
	var anchor: Vector2i = BattleGrid.world_to_tile(_field.grid.lane_pocket_centre(0))
	RunState.set_phase(RunState.Phase.PREPARATION)
	var problem: String = _field.try_build(anchor, data)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(problem.is_empty(), "the harness must be able to build a well: %s" % problem)
	await get_tree().process_frame
	var well: Tower = null
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower != null and tower.data == data:
			well = tower
	if well == null:
		return
	_check(is_zero_approx(well.evaporation_now()), "a well on calm ground evaporates %.3f" % well.evaporation_now())
	_climate.add_heat(well.origin(), 30.0)
	_check(well.evaporation_now() > 0.0, "a well on hot ground does not evaporate")
	_climate.reset()
	_check(is_zero_approx(well.evaporation_now()), "the ground cooled and the well kept evaporating")
	RunState.clear_tower(anchor)
	await get_tree().process_frame


## A fire on wet ground does not spread; the same fire on dry ground does;
## a strike on wet ground lights nothing.
func _test_the_fire_reads_the_ground() -> void:
	var fire: Wildfire = _field.wildfire()
	var foliage: Foliage = fire.call("_foliage") if fire != null else null
	_check(fire != null and foliage != null, "a wildfire and foliage to read the ground")
	if fire == null or foliage == null:
		return
	fire.call("_clear")
	var seed_at: Vector2 = Vector2.INF
	for candidate: Dictionary in foliage.plants_near(Vector2.ZERO, BattleGrid.CORE_HALF_EXTENT * 1.4):
		if foliage.plants_near(candidate["at"] as Vector2, Balance.WILDFIRE_SPREAD_RADIUS * 0.8).size() >= 4:
			seed_at = candidate["at"]
			break
	_check(seed_at.is_finite(), "a thicket for the fire")
	if not seed_at.is_finite():
		return
	# Soaked: it burns alone and goes out.
	_climate.reset(1.0)
	_check(fire.ignite_near(seed_at, 20.0, 1.0), "a plant on wet ground refused to be lit by hand")
	for _i: int in 40:
		fire._process(0.5)
	_check(fire.lit_count == 1, "a fire on soaked ground spread to %d plants" % fire.lit_count)
	fire.call("_clear")
	# Tinder: it spreads. The soaked plant went out for good - wet ground
	# quenches - so this lights the nearest of its neighbours.
	_climate.reset(0.0)
	var lit_before: int = fire.lit_count
	_check(fire.ignite_near(seed_at, Balance.WILDFIRE_SPREAD_RADIUS, 1.0), "no neighbour left to light")
	for _i: int in 40:
		fire._process(0.5)
	_check(fire.lit_count - lit_before >= 2, "a fire on dry ground never spread (%d)" % (fire.lit_count - lit_before))
	# A burning plant heats and dries the ground under it.
	_check(_climate.heat_at(seed_at) > 0.0 or _climate.heat_at(_climate.cell_centre(_climate.cell_of(seed_at))) > 0.0,
		"a fire did not heat the ground it burns on")
	fire.call("_clear")
	# Dry lightning on wet ground lights nothing.
	_climate.reset(1.0)
	var sky: WeatherSky = _field.sky()
	sky.set("_temperature", 40.0)
	for _i: int in 20:
		sky.strike_at(seed_at)
	_check(fire.fire_count() == 0, "a strike on soaked ground lit the brush")
	fire.call("_clear")
	if _field.zones() != null:
		_field.zones().clear()
	_climate.reset()
	await get_tree().process_frame


func _test_the_picture() -> void:
	_climate.reset()
	var texture: Texture2D = _climate.texture()
	_check(texture != null and texture.get_width() == _climate.across() and texture.get_height() == _climate.across(),
		"the picture is one texel a cell")
	var at: Vector2 = _climate.cell_centre(_climate.cell_of(Vector2(1000.0, 1000.0)))
	_climate.add_heat(at, 30.0, 10.0)
	_tick(Balance.CLIMATE_TICK)
	_climate.call("_refresh_picture")
	var image: Image = (_climate.get("_image") as Image)
	var index: int = _climate.cell_of(at)
	var pixel: Color = image.get_pixel(index % _climate.across(), floori(float(index) / float(_climate.across())))
	_check(pixel.r > 0.55, "a hot cell should read warm in the picture (%.2f)" % pixel.r)
	_check(not _climate.debug_shown, "the debug view is off by default")
	_climate.toggle_debug()
	_check(_climate.debug_shown, "the debug view did not toggle on")
	_climate.toggle_debug()
	_climate.reset()
