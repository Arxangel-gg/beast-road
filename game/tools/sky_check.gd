extends Node

## The sky does what it says: rain that swells, a flood that slows and drowns,
## lightning that hurts and charges the storm towers, heat that dries the
## wells, and a guest told the same numbers.
##
##   godot --headless --path game res://tools/sky_check.tscn
##
## Every half of the 2026-09-14 weather brief is measured here on the real
## battlefield rather than read back from a constant, because each half has a
## way of being a lie that would not error: a swell that never swings, a flood
## that rises on snow, a strike that misses the body under it, a well that
## keeps drawing in the heat, a torch that never notices the rain.

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _sky: WeatherSky = null


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
	_sky = _field.sky() if _field != null else null
	_check(_sky != null, "the battlefield must stand a sky up")
	if _sky != null:
		# The weather is the subject here and the earth's wrath is
		# `wrath_check`'s. Left on, the animals this gate drowns and strikes
		# anger the earth enough for a quake to fire inside the lightning test
		# and hurt the body that was supposed to be out of reach.
		_sky.events_enabled = false
		_test_the_rain_swells()
		_test_the_swell_is_deterministic()
		await _test_the_flood()
		_test_snow_never_floods()
		await _test_lightning()
		await _test_the_storm_towers()
		await _test_the_torches()
		await _test_the_wildlife()
		_test_the_heat()
		await _test_the_guest_is_told()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[sky] PASS - %d checks: the swell, the flood, the lightning, the storm "
			% _checks + "towers, the torches, the wildlife, the wells and the guest")
	else:
		for failure: String in _failures:
			push_error("[sky] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _weather(id: String) -> void:
	RunState.weather_id = id
	EventBus.weather_changed.emit(id)


## Back to a dry, clear field: the rain forced off, the flood drained, the sky
## rolling its own weather again. Every test that made it rain ends here,
## because a flood one test left standing put out the next test's torch and
## told the wildlife nothing new had happened.
func _dry() -> void:
	_sky.forced_intensity = 0.0
	_step(Balance.FLOOD_DRAIN_SECONDS + 30.0)
	_sky.forced_intensity = -1.0
	_weather("clear")
	_step(5.0)
	if _field.climate() != null:
		_field.climate().reset(0.0)


## Steps the sky by hand, the way `camps_check` steps the camps: sky time is
## what matters and a frame is too slow to walk three minutes of it.
func _step(seconds: float, step: float = 0.5) -> void:
	var left: float = seconds
	while left > 0.0:
		var dt: float = minf(step, left)
		_sky._process(dt)
		left -= dt


## The rain rises and falls on its own, within bounds, and clears when the
## sky does.
func _test_the_rain_swells() -> void:
	_weather("downpour")
	_sky.forced_intensity = -1.0
	var low: float = INF
	var high: float = -INF
	var step: float = 0.5
	for _i: int in 600:
		_sky._process(step)
		low = minf(low, RunState.rain_scale)
		high = maxf(high, RunState.rain_scale)
		_check(RunState.rain_intensity >= 0.0 and RunState.rain_intensity <= 1.0,
			"rain intensity %.2f is outside 0..1" % RunState.rain_intensity)
	_check(low < 0.85, "in five minutes of downpour the rain never slackened below 0.85 (%.2f)" % low)
	_check(high > 1.05, "in five minutes of downpour the rain never swelled past 1.05 (%.2f)" % high)
	_check(low >= Balance.SKY_RAIN_SCALE_RANGE.x - 0.01 and high <= Balance.SKY_RAIN_SCALE_RANGE.y + 0.01,
		"the swell left its authored range: %.2f..%.2f" % [low, high])
	_weather("clear")
	_step(30.0)
	_check(RunState.rain_intensity == 0.0, "a clear sky rains %.2f" % RunState.rain_intensity)
	_check(is_equal_approx(RunState.rain_scale, 1.0), "a clear sky's rain scale is %.2f, not 1" % RunState.rain_scale)


## The swell is a function of the sky's clock and its seeded phases, so two
## machines that agree on the clock agree on the rain.
func _test_the_swell_is_deterministic() -> void:
	_weather("downpour")
	var first: Array[float] = _swell_series()
	var second: Array[float] = _swell_series()
	_check(first == second, "the same sky clock gave two different swells")
	_weather("clear")
	_step(30.0)


func _swell_series() -> Array[float]:
	_sky.set("_clock", 0.0)
	_sky.set("_scale", 1.0)
	_sky.set("_scale_target", 1.0)
	var out: Array[float] = []
	for _i: int in 120:
		_sky._process(0.5)
		out.append(snappedf(RunState.rain_scale, 0.0001))
	return out


## Heavy rain held long enough floods the field; the flood slows the hero;
## and it drains once the rain eases.
func _test_the_flood() -> void:
	_weather("downpour")
	var dry: float = _field.hero.move_speed()
	_sky.forced_intensity = 1.0
	_step(Balance.FLOOD_RISE_SECONDS + 30.0)
	_check(RunState.flood >= 0.95, "after a full downpour the flood stands at %.2f" % RunState.flood)
	_check(RunState.flood_slow() < 0.7, "the flood slows walking to %.2f, which is not a flood" % RunState.flood_slow())
	var wet: float = _field.hero.move_speed()
	_check(wet < dry * 0.75, "the hero wades at %.0f against %.0f dry" % [wet, dry])
	_sky.forced_intensity = 0.0
	_step(Balance.FLOOD_DRAIN_SECONDS + 30.0)
	_check(RunState.flood < 0.05, "after the rain stopped the flood is still %.2f" % RunState.flood)
	_check(is_equal_approx(_field.hero.move_speed(), dry), "the hero is still slowed after the flood drained")
	_sky.forced_intensity = -1.0
	await get_tree().process_frame


func _test_snow_never_floods() -> void:
	_weather("snowfall")
	_sky.forced_intensity = 1.0
	_step(120.0)
	_check(RunState.flood == 0.0, "snow flooded the field to %.2f" % RunState.flood)
	_sky.forced_intensity = -1.0
	_weather("clear")


## A charged downpour strikes; a strike hurts what is under it and not what is
## not; and it never lands on the city.
func _test_lightning() -> void:
	_weather("downpour")
	_sky.forced_intensity = 1.0
	var before: int = _sky.strikes
	var waited: float = 0.0
	while _sky.strikes == before and waited < 900.0:
		_sky._process(0.25)
		waited += 0.25
	_check(_sky.strikes > before, "a full downpour threw no lightning in fifteen minutes")
	_check(_sky.charge() > 0.0, "a strike left no charge behind")
	_check(_sky.hazard_now() > 0.0, "a charged downpour has no hazard")
	for _i: int in 200:
		_check(_sky._pick_strike_point().length() >= Balance.LIGHTNING_TOWN_CLEARANCE,
			"a strike point landed within the city's clearance")
	# A strike, aimed: the body under it hurts, the body away from it does not.
	var data: EnemyData = ContentDB.enemy("bogkin")
	var at: Vector2 = Vector2(600.0, 600.0)
	var near: Enemy = _field.spawn_enemy(data, 0, 1.0)
	var far: Enemy = _field.spawn_enemy(data, 0, 1.0)
	await get_tree().process_frame
	near.global_position = at
	# Out of reach of the strike *and* of the chain a full flood carries -
	# the flood is standing from the wait above - with room for the frame
	# or two of walking between placing the bodies and the strike: at three
	# radii it sat ten units inside the chain's reach and CI caught it.
	far.global_position = at + Vector2(maxf(Balance.LIGHTNING_RADIUS * 3.0,
		Balance.CHAIN_RANGE * (1.0 + Balance.CHAIN_FLOOD_RANGE) + 200.0), 0.0)
	await get_tree().process_frame
	var near_hp: float = near.health.current_hp
	var far_hp: float = far.health.current_hp
	_sky.strike_at(at)
	_check(near.health.current_hp < near_hp, "the body under the strike was not hurt")
	_check(is_equal_approx(far.health.current_hp, far_hp), "a body three radii away was hurt")
	near.queue_free()
	far.queue_free()
	_dry()
	await get_tree().process_frame


## A storm tower near a strike is charged: harder and faster, for a while.
func _test_the_storm_towers() -> void:
	RunState.gain_every_currency(20000)
	var coil: TowerData = ContentDB.tower("arc_coil")
	_check(coil != null and coil.element == TowerData.Element.AIR, "arc_coil is the storm tower this leans on")
	if coil == null:
		return
	var anchor: Vector2i = BattleGrid.world_to_tile(_field.grid.lane_pocket_centre(0))
	# Building is locked to Preparation (owner decision, 2026-08-13), and the
	# harness respects the lock rather than reaching round it.
	RunState.set_phase(RunState.Phase.PREPARATION)
	var problem: String = _field.try_build(anchor, coil)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(problem.is_empty(), "the harness must be able to build a storm tower: %s" % problem)
	await get_tree().process_frame
	var tower: Tower = null
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var candidate := node as Tower
		if candidate != null and candidate.data == coil:
			tower = candidate
	_check(tower != null, "the built storm tower is on the field")
	if tower == null:
		return
	var calm: float = tower.effective_damage()
	_sky.strike_at(tower.global_position + Vector2(Balance.LIGHTNING_EMPOWER_RADIUS * 0.5, 0.0))
	_check(tower.storm_charged(), "a strike within reach did not charge the storm tower")
	_check(tower.effective_damage() > calm * 1.3,
		"a charged storm tower deals %.1f against %.1f calm" % [tower.effective_damage(), calm])
	tower._process(Balance.LIGHTNING_EMPOWER_SECONDS + 1.0)
	_check(not tower.storm_charged(), "the charge did not run down")
	# The strike also left a storm core under the tower, which is the other
	# thing an air tower is fed by and is `wrath_check`'s to measure; cleared
	# here so this reads the charge alone.
	if _field.zones() != null:
		_field.zones().clear()
	# The charge's own multiplier and the ground's, back to one. Not the
	# absolute figure: a relic adapter crossing its town-health line or a
	# weather change between the two reads moves that for reasons that are
	# not the charge, and this gate once failed on exactly that in a sweep.
	_check(is_equal_approx(float(tower.call("_storm_damage")), 1.0), "the charge's multiplier did not settle back")
	_check(is_equal_approx(float(tower.call("_zone_damage")), 1.0), "the ground's multiplier did not settle back")
	_check(tower.effective_damage() < calm * 1.3, "damage stayed charged after the charge ran down")
	# And a strike well out of reach charges nothing.
	_sky.strike_at(tower.global_position + Vector2(Balance.LIGHTNING_EMPOWER_RADIUS * 3.0, 0.0))
	_check(not tower.storm_charged(), "a strike three reaches away charged the tower")


## Rain wears a torch down and it recovers when the rain stops; a flood at its
## height puts it out.
func _test_the_torches() -> void:
	# The innermost post: the camps stand bodies in the trees along the outer
	# corridors, and this is about the rain, not about them.
	var torch: Torch = null
	for node: Node in get_tree().get_nodes_in_group(Torch.GROUP):
		var candidate := node as Torch
		if candidate == null:
			continue
		if torch == null or candidate.global_position.length() < torch.global_position.length():
			torch = candidate
	_check(torch != null, "the field stands torches up")
	if torch == null:
		return
	torch.relight()
	_weather("downpour")
	_sky.forced_intensity = 1.0
	_sky._process(0.1)
	for _i: int in 180:
		torch._process(1.0)
	_check(torch.light_strength() < 0.9 or not torch.is_lit(),
		"three minutes of the heaviest rain left a torch at %.2f" % torch.light_strength())
	_sky.forced_intensity = 0.0
	_sky._process(0.1)
	if not torch.is_lit():
		torch.relight()
	for _i: int in 60:
		torch._process(1.0)
	_check(torch.is_lit() and torch.light_strength() > 0.95,
		"a torch out of the rain did not recover (%.2f, lit %s)" % [torch.light_strength(), str(torch.is_lit())])
	RunState.flood = 1.0
	torch._process(0.1)
	_check(not torch.is_lit(), "a flood at its height left a torch burning")
	RunState.flood = 0.0
	torch.relight()
	_dry()
	await get_tree().process_frame


## At the flood's height the flyers leave, the climbers climb, and the small
## drown where they stand and leave their food.
func _test_the_wildlife() -> void:
	var animals: Wildlife = _field.wildlife()
	_check(animals != null, "the field has wildlife")
	if animals == null:
		return
	var by_id: Dictionary = {}
	for kind: WildlifeData in ContentDB.wildlife():
		by_id[kind.id] = kind
	var flyer: WildlifeData = by_id.get("butterfly_azure", null)
	var climber: WildlifeData = by_id.get("squirrel", null)
	var small: WildlifeData = by_id.get("rabbit", null)
	_check(flyer != null and flyer.flies, "butterfly_azure flies")
	_check(climber != null and climber.climbs, "squirrel climbs")
	_check(small != null and not small.climbs and not small.flies and small.scale < Balance.FLOOD_DROWN_SCALE,
		"rabbit is small, walks and cannot climb")
	if flyer == null or climber == null or small == null:
		return
	var living: Array = animals.get("_living")
	var before: int = living.size()
	var at: Vector2 = Vector2(-700.0, 400.0)
	animals.call("_spawn", flyer, at)
	animals.call("_spawn", climber, at + Vector2(40.0, 0.0))
	animals.call("_spawn", small, at + Vector2(80.0, 0.0))
	_check(living.size() == before + 3, "three animals spawned (%d)" % (living.size() - before))
	if living.size() < before + 3:
		return
	var bird: Dictionary = living[before]
	var squirrel: Dictionary = living[before + 1]
	var rabbit: Dictionary = living[before + 2]
	# Settled, so the flood is what moves them.
	for animal: Dictionary in [bird, squirrel, rabbit]:
		animal["state"] = Wildlife.State.SETTLED
		animal["goal"] = (animal["sprite"] as Node2D).global_position
	# A flood earlier in this run has to have receded first, or the animals
	# were already told about this one.
	EventBus.flood_changed.emit(0.0)
	RunState.flood = 1.0
	EventBus.flood_changed.emit(1.0)
	_check(int(bird["state"]) == Wildlife.State.LEAVING, "the butterfly did not leave the flood")
	_check(bool(squirrel.get("climbing", false)), "the squirrel did not make for a tree")
	_check(float(rabbit["dying"]) > 0.0, "the rabbit did not drown")
	# The squirrel reaches its trunk and goes up it. The trunk is the nearest
	# tree, the trees are scattered by the run's own seed, and an animal
	# further from every hero than `WILDLIFE_FORGET_DISTANCE` is forgotten
	# before it can climb - so the hero, who is the observer, stands beside
	# it. Without this the verdict was a property of the seed (CI, v0.21.0).
	var trunk: Vector2 = squirrel["goal"] as Vector2
	(squirrel["sprite"] as Node2D).global_position = trunk
	_field.hero.global_position = trunk + Vector2(120.0, 0.0)
	animals.call("_tick_one", squirrel, 0.5)
	_check(bool(squirrel.get("treed", false)), "the squirrel at its trunk did not climb")
	# And comes down when the water does.
	RunState.flood = 0.0
	EventBus.flood_changed.emit(0.0)
	animals.call("_tick_one", squirrel, 0.5)
	_check(not bool(squirrel.get("treed", false)), "the squirrel stayed up its tree after the flood")
	await get_tree().process_frame


## The heat: a well refills slower past one threshold and loses water past
## another, and neither touches anything at a mild temperature.
func _test_the_heat() -> void:
	RunState.temperature = 20.0
	_check(is_equal_approx(RunState.well_refill_scale(), 1.0), "a mild day slows the wells")
	_check(RunState.well_evaporation() == 0.0, "a mild day dries the wells")
	RunState.temperature = 40.0
	_check(RunState.well_refill_scale() > 1.3, "a heatwave leaves the wells refilling at %.2f" % RunState.well_refill_scale())
	_check(RunState.well_evaporation() > 0.0, "a heatwave does not dry the wells")
	RunState.temperature = 20.0


## A guest writes the four numbers it is told and rolls nothing of its own.
func _test_the_guest_is_told() -> void:
	var guest := WeatherSky.new()
	add_child(guest)
	await get_tree().process_frame
	# After `_ready`, which reads `Coop.is_guest()` and would have overwritten
	# it: this machine is nobody's guest, so the sky is told it is one.
	guest.set("_mirror", true)
	var before: float = guest.rain_scale()
	guest._process(5.0)
	_check(is_equal_approx(guest.rain_scale(), before), "a guest's sky rolled its own rain")
	EventBus.coop_sky_clock.emit(0.71, 0.42, 0.33, 31.5)
	_check(is_equal_approx(RunState.rain_scale, 0.71), "the guest did not take the host's rain scale")
	_check(is_equal_approx(RunState.flood, 0.42), "the guest did not take the host's flood")
	_check(is_equal_approx(RunState.storm_charge, 0.33), "the guest did not take the host's charge")
	_check(is_equal_approx(RunState.temperature, 31.5), "the guest did not take the host's temperature")
	guest.queue_free()
	RunState.flood = 0.0
	RunState.rain_scale = 1.0
	RunState.storm_charge = 0.0
	RunState.temperature = 20.0
	await get_tree().process_frame
