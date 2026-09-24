extends Node

## The earth's wrath: kills feed it, it leans the weather, and it shakes,
## burns, spins and throws stones. Each of those is measured on the real field.
##
##   godot --headless --path game res://tools/wrath_check.tscn
##
## Owner brief, 2026-09-14. Every event here has a way of lying that would not
## error - a quake that shakes the screen and hurts nobody, a fire that draws a
## flame and never spreads or never goes out, a funnel that walks past a tower
## and leaves it standing, a stone that lands in an empty field - so the gate
## drives each on the real battlefield with real bodies and real towers and
## reads the numbers back.

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _sky: WeatherSky = null
var _fire: Wildfire = null


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
	_fire = _field.wildfire() if _field != null else null
	_check(_sky != null and _fire != null and _field.scorch() != null,
		"the battlefield must stand a sky, a wildfire and the scorch marks up")
	if _sky != null and _fire != null:
		_sky.events_enabled = false
		_test_wrath_rises_and_cools()
		await _test_the_earth_answers_on_its_own()
		await _test_acts_ease_the_wrath()
		await _test_rarity_and_the_shock()
		await _test_anchors_and_recovery()
		_test_strain_and_the_wind()
		_test_wrath_leans_the_weather()
		await _test_the_quake()
		await _test_the_wave_travels()
		await _test_the_wildfire()
		await _test_the_rain_puts_fire_out()
		await _test_the_tornado()
		await _test_the_meteor()
		await _test_chain_lightning()
		await _test_water_feeds_the_water_towers()
		await _test_deep_water_stops_the_dash()
		await _test_enemies_turn_on_towers()
		await _test_the_ground_stays_charged()
		await _test_the_quake_is_telegraphed()
		await _test_the_tornado_is_telegraphed()
		await _test_the_fire_whirl()
		await _test_dry_lightning()
		await _test_the_guest_only_draws()
		await _test_the_guest_is_told()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[wrath] PASS - %d checks: the measure, the acts, the rarity, the anchors, the strain, "
			% _checks + "the weather, the quake, the fire, the funnel, the stone, the chain, the water, "
			+ "the dash, the towers, the charged ground, the tells, the fire whirl, the dry strike and the guest")
	else:
		for failure: String in _failures:
			push_error("[wrath] " + failure)
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


func _step(seconds: float, step: float = 0.5) -> void:
	var left: float = seconds
	while left > 0.0:
		var dt: float = minf(step, left)
		_sky._process(dt)
		left -= dt


func _dry() -> void:
	_sky.forced_intensity = 0.0
	_step(Balance.FLOOD_DRAIN_SECONDS + 30.0)
	_sky.forced_intensity = -1.0
	_weather("clear")
	_step(5.0)
	RunState.flood = 0.0
	if _field.climate() != null:
		_field.climate().reset(0.0)


func _body(at: Vector2, hp_scale: float = 1.0) -> Enemy:
	var enemy: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, hp_scale)
	enemy.global_position = at
	return enemy


## A fusion is a property of where you built: two finished parents either
## side of an empty plot. Finds three open anchors in a row inside the pocket,
## builds the parents on the outer two and the fusion between them.
func _build_fusion(id: String, parent_id: String, around: Vector2) -> Tower:
	var centre: Vector2i = BattleGrid.world_to_tile(around)
	for dy: int in range(-6, 7):
		for dx: int in range(-6, 7):
			var anchor: Vector2i = centre + Vector2i(dx, dy)
			for axis: Vector2i in [Vector2i(BattleGrid.FOOTPRINT, 0), Vector2i(0, BattleGrid.FOOTPRINT)]:
				var a: Vector2i = anchor - axis
				var b: Vector2i = anchor + axis
				if not _field.placement_problem(anchor).is_empty():
					continue
				if not _field.placement_problem(a).is_empty() or not _field.placement_problem(b).is_empty():
					continue
				var left: Tower = _build(parent_id, BattleGrid.tile_to_world(a))
				var right: Tower = _build(parent_id, BattleGrid.tile_to_world(b))
				if left == null or right == null:
					return null
				return _build(id, BattleGrid.tile_to_world(anchor))
	return null


## The nearest open build anchor to a point within `radius`, as a world
## position, or INF when the ground there is all road, water or rock.
func _open_anchor_near(at: Vector2, radius: float) -> Vector2:
	var centre: Vector2i = BattleGrid.world_to_tile(at)
	var reach: int = int(ceil(radius / BattleGrid.TILE)) + 1
	var best: Vector2 = Vector2.INF
	var nearest: float = radius
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var anchor: Vector2i = centre + Vector2i(dx, dy)
			if not _field.placement_problem(anchor).is_empty():
				continue
			# Measured from where the tower will stand, returned as the tile
			# `_build` turns back into that anchor.
			var away: float = BattleGrid.footprint_centre(anchor).distance_to(at)
			if away < nearest:
				nearest = away
				best = BattleGrid.tile_to_world(anchor)
	return best


## Every tower off the field, so each test builds on a free pocket.
func _clear_towers() -> void:
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower != null and is_instance_valid(tower):
			RunState.clear_tower(tower.anchor)
	await get_tree().process_frame
	await get_tree().process_frame


func _pocket(lane: int) -> Vector2:
	return _field.grid.lane_pocket_centre(lane)


## With the earth furious and its events allowed, something happens within a
## while. Proves the hazard path the rest of the gate switches off.
func _test_the_earth_answers_on_its_own() -> void:
	_dry()
	_sky.set("_wrath_floor", Balance.WRATH_CAP)
	_sky.events_enabled = true
	var before: int = _sky.quakes + _sky.wildfires + _sky.tornadoes
	var waited: float = 0.0
	while _sky.quakes + _sky.wildfires + _sky.tornadoes == before and waited < 1800.0:
		_sky._process(0.5)
		waited += 0.5
	_check(_sky.quakes + _sky.wildfires + _sky.tornadoes > before,
		"half an hour of a furious earth and nothing happened")
	_sky.events_enabled = false
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	_sky.set("_quake_left", 0.0)
	for node: Node in get_tree().get_nodes_in_group(Tornado.GROUP):
		node.queue_free()
	_fire.call("_clear")
	await get_tree().process_frame


func _build(id: String, at: Vector2) -> Tower:
	RunState.gain_every_currency(20000)
	var data: TowerData = ContentDB.tower(id)
	if data == null:
		_check(false, "no tower called %s" % id)
		return null
	var anchor: Vector2i = BattleGrid.world_to_tile(at)
	RunState.set_phase(RunState.Phase.PREPARATION)
	var problem: String = _field.try_build(anchor, data)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(problem.is_empty(), "the harness must be able to build %s: %s" % [id, problem])
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower != null and tower.data == data and tower.anchor == anchor:
			return tower
	return null


## Kills raise it - a floor for the run and a heat that cools - and nothing
## reaches the HUD.
func _test_wrath_rises_and_cools() -> void:
	_check(_sky.wrath() == 0.0, "a fresh road starts with no wrath (%.3f)" % _sky.wrath())
	for _i: int in 6:
		EventBus.wildlife_killed.emit("rabbit", 3, Vector2.ZERO, 0, false, false)
	var hot: float = _sky.wrath()
	_check(hot > 0.2, "six kills left the earth at %.3f" % hot)
	_step(Balance.WRATH_HEAT_HALF_LIFE * 3.0)
	var cooled: float = _sky.wrath()
	_check(cooled < hot * 0.6, "half an hour later the earth is still at %.3f of %.3f" % [cooled, hot])
	# The floor stays - a quiet road eases it, slowly, and never to nothing
	# inside an hour and a half of six kills.
	_check(cooled > 0.0 and cooled >= Balance.WRATH_FLOOR_PER_KILL * 6.0
		- Balance.WRATH_FLOOR_RECOVERY_PER_SECOND * Balance.WRATH_HEAT_HALF_LIFE * 3.0 - 0.001,
		"the floor cooled away too: %.3f" % cooled)
	_check(is_equal_approx(RunState.wrath, cooled), "RunState.wrath is not what the sky says")


## The crossroad's harsh skies grow likelier with wrath.
func _test_wrath_leans_the_weather() -> void:
	var downpour: WeatherData = ContentDB.weather("downpour")
	var clear: WeatherData = ContentDB.weather("clear")
	_check(downpour != null and downpour.wrathful and clear != null and not clear.wrathful,
		"a downpour is wrathful and a clear sky is not")
	var was: float = RunState.wrath
	RunState.wrath = 0.0
	var calm_rain: float = RunState._wrathful_weight(downpour)
	var calm_clear: float = RunState._wrathful_weight(clear)
	RunState.wrath = 1.0
	_check(RunState._wrathful_weight(downpour) > calm_rain * 2.0,
		"full wrath does not lean the crossroad toward a downpour")
	_check(is_equal_approx(RunState._wrathful_weight(clear), calm_clear),
		"wrath changed the weight of a clear sky")
	RunState.wrath = was


## The ground shakes and everything alive is hurt by it.
##
## **The harness had to learn that a quake arrives rather than happening.**
## Until 2026-09-22 the blow was dealt to the whole field on the frame
## `quake()` was called, so reading the health back on the next line was a
## fair question; `GroundWave` rolls crests out from an epicentre and strikes
## each body as a front reaches it, which takes a couple of seconds. The
## *invariant* has not moved - a quake hurts bodies, chips a tower without
## felling it, hurts the hero without killing them outright, and leaves a
## fault - so what changed here is only how long the gate waits, which is a
## harness change and not an amendment.
func _test_the_quake() -> void:
	_field.hero.global_position = _field.city_bounds().end + Vector2(180.0, 180.0)
	var body: Enemy = _body(Vector2(700.0, 700.0), 1.0)
	await get_tree().process_frame
	_make_it_endure(body)
	var body_hp: float = body.health.current_hp
	var hero_hp: float = _field.hero.health.current_hp
	await _clear_towers()
	var wall: Tower = _build("grit_sling", _pocket(0))
	var marks_before: int = _sky.marks.stamp_count() if _sky.marks != null else 0
	var before: int = _sky.quakes
	_sky.quake(1.0, ["quake"])
	_check(_sky.quakes == before + 1, "the quake was not counted")
	await _let_the_wave_run()
	_check(is_instance_valid(body) and body.health.current_hp < body_hp,
		"the quake did not hurt a body")
	if wall != null and is_instance_valid(wall):
		_check(wall.health_ratio() < 1.0 and wall.is_vulnerable(),
			"the quake should chip a standing tower and never fell it (%.2f)" % wall.health_ratio())
	_check(_field.hero.health.current_hp < hero_hp, "the quake did not hurt the hero")
	_check(_field.hero.health.current_hp > 0.0, "a full quake killed a full hero outright")
	if _sky.marks != null:
		_check(_sky.marks.stamp_count() > marks_before,
			"the wave left no cracks where its own front passed")
	body.queue_free()
	await get_tree().process_frame


## **The wave comes from somewhere, and standing still costs more than
## moving.** The bound the ground wave was built under: every crest carries
## the old blow divided by the crest count and reaches past the far corner,
## so a body that does not move takes exactly the old total - and a body that
## steps out of a crest takes less. Measured on two bodies of the same breed
## with the same pool, one held at the epicentre's ring and one walked out of
## it, rather than read off the constants.
func _test_the_wave_travels() -> void:
	# **Nothing left over from the last quake.** A wave crosses the whole
	# grid, which takes longer than the test before this waits, so
	# `_the_wave` was handing back that test's wave and the gate was
	# measuring an epicentre nobody had asked for.
	await _clear_waves()
	await _clear_towers()
	# **Nothing bites the probes.** The animals are the seed's, and on CI
	# (2026-09-24) one stood where the mover ran: it "took more than the body
	# that stood still" and the gate read that as crests that cost nothing.
	# Cleared and stilled for this test only - the wildfire test below wants
	# them back.
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	_field.hero.global_position = _field.city_bounds().end + Vector2(900.0, 900.0)
	var still: Enemy = _body(Vector2(-900.0, 0.0))
	var mover: Enemy = _body(Vector2(900.0, 0.0))
	await get_tree().process_frame
	_make_it_endure(still)
	_make_it_endure(mover)
	var pool: float = still.health.current_hp
	_sky.quake(1.0, ["quake"], Vector2(1.0, 0.0))
	var wave: GroundWave = _the_wave()
	_check(wave != null, "a quake with a quake pattern in it opened no wave")
	if wave == null:
		return
	_check(wave.at == Vector2(1.0, 0.0),
		"the wave broke at %s rather than where the warning said" % wave.at)
	_check(wave.rings >= 1, "a full quake sent no crest at all")
	# The mover is carried outward faster than the front, so it is never
	# inside a crest after the first. It cannot avoid the first: the wave is
	# born under it, which is the honest floor - a quake is not dodgeable,
	# only readable.
	var ran: float = 0.0
	while ran < 6.0 and is_instance_valid(wave):
		await get_tree().process_frame
		ran += get_process_delta_time()
		if is_instance_valid(mover):
			mover.global_position += Vector2(Balance.QUAKE_WAVE_SPEED * 1.4, 0.0) 				* get_process_delta_time()
	_check(still.health.current_hp < pool, "the crest passed the still body and did not strike it")
	_check(mover.health.current_hp > still.health.current_hp,
		"stepping out of the crests bought nothing: %.0f against %.0f"
			% [mover.health.current_hp, still.health.current_hp])
	still.queue_free()
	mover.queue_free()
	if animals != null:
		animals.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().process_frame


## Frees every wave still crossing the field, so the next test starts on
## ground nothing is rolling over.
func _clear_waves() -> void:
	for child: Node in _field.get_children():
		var wave := child as GroundWave
		if wave != null:
			_field.remove_child(wave)
			wave.queue_free()
	await get_tree().process_frame


## Waits out the crests, or six seconds, whichever is sooner.
func _let_the_wave_run() -> void:
	var waited: float = 0.0
	while waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _the_wave() == null and waited > 0.2:
			return


## A pool nothing on the field can empty inside a measurement.
func _make_it_endure(body: Enemy) -> void:
	if body == null or not is_instance_valid(body) or body.health == null:
		return
	body.health.max_hp = 1000000.0
	body.health.current_hp = 1000000.0


func _the_wave() -> GroundWave:
	for child: Node in _field.get_children():
		var wave := child as GroundWave
		if wave != null and is_instance_valid(wave):
			return wave
	return null


## A plant catches, hurts what stands in it, heats the fire towers, spreads,
## and when it is gone the plant is gone, the ground is marked, and a tree it
## reached never grows back.
func _test_the_wildfire() -> void:
	_dry()
	var lit_at_start: int = _fire.lit_count
	var foliage: Foliage = _fire.call("_foliage")
	_check(foliage != null, "the wildfire knows the foliage")
	if foliage == null:
		return
	# A plant with neighbours that has open ground within a fire tower's reach
	# of it, so spread has somewhere to go and the tower somewhere to stand.
	await _clear_towers()
	var seed_at: Vector2 = Vector2.INF
	var stand: Vector2 = Vector2.INF
	for candidate: Dictionary in foliage.plants_near(Vector2.ZERO, BattleGrid.CORE_HALF_EXTENT * 1.4):
		# Fire damage needs a legal place for a body to stand after city deflection.
		if _field.city_bounds().grow(180.0).has_point(candidate["at"] as Vector2):
			continue
		var around: Array[Dictionary] = foliage.plants_near(candidate["at"] as Vector2,
			Balance.WILDFIRE_SPREAD_RADIUS * 0.8)
		if around.size() < 3:
			continue
		var open: Vector2 = _open_anchor_near(candidate["at"] as Vector2, Balance.WILDFIRE_TOWER_BUFF_RADIUS * 0.6)
		if open.is_finite():
			seed_at = candidate["at"]
			stand = open
			break
	_check(seed_at.is_finite(), "no plant with neighbours and open ground within a fire tower's reach")
	if not seed_at.is_finite():
		return
	# The fire tower stands first and is read calm, so the heat is measured
	# against a number taken before anything was burning.
	var coil: Tower = _build("ash_thrower", stand)
	await get_tree().process_frame
	var calm: float = coil.effective_damage() if coil != null else 0.0
	# Counted as a difference, not a total: the fire tower stood up a frame ago
	# may already have lit something with a shot, which is the tower working -
	# on CI's slower frames it did, twice, and the total read 3.
	var burning: int = _fire.fire_count()
	_check(_fire.ignite_near(seed_at, 20.0, 1.0), "a dry plant did not catch")
	_check(_fire.fire_count() == burning + 1, "one plant lit means one fire (%d from %d)"
		% [_fire.fire_count(), burning])
	# A body standing in it burns; a fire tower near it heats.
	var body: Enemy = _body(seed_at)
	body.set_process(false)
	await get_tree().process_frame
	var body_hp: float = body.health.current_hp
	_fire.set("_mirror", false)
	for _i: int in 4:
		_fire._process(0.5)
	_check(body.health.current_hp < body_hp, "a body standing in the fire was not hurt")
	# **And an animal standing in it burns too** (owner, 2026-09-16: "wildfires
	# need to damage wildlife that walks through them too, and same for
	# enemies"). The enemy half was gated and the wildlife half was not, so a
	# broken `animals` wiring would have read as working - the fire scares
	# animals away from itself, and an animal that is never in one is
	# indistinguishable from one that cannot be hurt by one.
	var beast: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null and not kind.mythic and not kind.is_hostile():
			beast = kind
			break
	var animals: Wildlife = _field.wildlife()
	_check(_fire.animals != null,
		"the wildfire was never handed the wildlife, so it can never burn one")
	if beast != null and animals != null:
		# Placed with a stage, the way `wildlife_family_check` places one: an
		# empty `born` leaves the record half-filled and the spawn refuses it.
		var animal: Dictionary = animals.spawn_born(beast, seed_at,
			{"stage": WildlifeFamilies.Stage.ADULT})
		if animal.is_empty():
			_check(false, "the harness could not stand an animal in the fire")
		else:
			# It will try to run - the blaze scares animals off itself - so it is
			# pinned where it was put. An animal that flees before the first tick
			# proves nothing about whether fire can hurt one.
			var animal_hp: float = float(animal.get("hp", 0.0))
			var pinned := animal.get("sprite") as Sprite2D
			for _i: int in 4:
				if is_instance_valid(pinned):
					pinned.global_position = seed_at
				_fire._process(0.5)
			_check(float(animal.get("hp", 0.0)) < animal_hp,
				("an animal standing in a wildfire kept all %.1f of its health - "
					+ "the blaze reaches enemies and not the ecology")
					% animal_hp)
	if coil != null:
		_check(coil.effective_damage() > calm * 1.05,
			"a fire tower beside a wildfire deals %.1f against %.1f calm" % [coil.effective_damage(), calm])
	# It spreads.
	for _i: int in 40:
		_fire._process(0.5)
	_check(_fire.lit_count >= 2, "twenty seconds beside dry neighbours and the fire never spread (%d lit)" % _fire.lit_count)
	# And it goes out, leaving its marks. Bounded: a blaze lights at most so
	# many plants over so many generations, so it must be out well inside a
	# generation's worth of burn time each.
	var burnt_before: int = foliage.burnt_count()
	for _i: int in int(Balance.WILDFIRE_BURN_SECONDS * 2.0 * float(Balance.WILDFIRE_MAX_GENERATIONS + 1)) + 40:
		_fire._process(0.5)
	_check(_fire.fire_count() == 0, "the fire never went out (%d still burning)" % _fire.fire_count())
	# A blaze heats the ground it burns on, so the hot bound is the one it
	# may reach: a fire that grows its own weather is the design, not a leak.
	var most: int = int(round(Balance.WILDFIRE_MAX_LIT * Balance.WILDFIRE_HOT_LIT_SCALE)) + 1
	_check(_fire.lit_count - lit_at_start <= most,
		"one blaze lit %d plants against a bound of %d" % [_fire.lit_count - lit_at_start, most])
	_check(foliage.burnt_count() > burnt_before, "no plant was left burnt")
	_check(_field.scorch().marked_at(seed_at), "the ground under the fire is not marked")
	# A tree the fire reaches is charred for good.
	var trees: Gathering = _fire.gathering
	if trees != null and trees.node_count() > 0:
		var index: int = -1
		var ids: Array[String] = trees.node_ids()
		for i: int in ids.size():
			var kind: GatherNodeData = ContentDB.gather_node(ids[i])
			if kind != null and kind.craft == "woodcutter":
				index = i
				break
		_check(index >= 0, "the field grows at least one woodcutting tree")
		if index >= 0:
			var at: Vector2 = trees.node_positions()[index]
			_check(trees.burn_near(at, 10.0) == 1, "the tree beside the fire did not char")
			_check(trees.node_is_burned(index) and trees.node_is_spent(index), "a charred tree is not spent")
			trees._process(10000.0)
			_check(trees.node_is_spent(index), "a charred tree grew back")
	body.queue_free()
	await get_tree().process_frame


## Rain shortens a fire, and a flood ends it.
func _test_the_rain_puts_fire_out() -> void:
	var foliage: Foliage = _fire.call("_foliage")
	var plants: Array[Dictionary] = foliage.plants_near(Vector2(-900.0, 900.0), 2400.0)
	_check(not plants.is_empty(), "plants to light on the far side")
	if plants.is_empty():
		return
	_fire.ignite_near(plants[0]["at"], 20.0, 1.0)
	_check(_fire.fire_count() >= 1, "a plant lit for the rain test")
	_sky.forced_intensity = 1.0
	_sky._process(0.1)
	var seconds: float = 0.0
	while _fire.fire_count() > 0 and seconds < Balance.WILDFIRE_BURN_SECONDS:
		_fire._process(0.5)
		seconds += 0.5
	_check(_fire.fire_count() == 0 and seconds < Balance.WILDFIRE_BURN_SECONDS * 0.6,
		"the heaviest rain took %.0fs to put a fire out that burns %.0fs dry" % [seconds, Balance.WILDFIRE_BURN_SECONDS])
	_check(not _fire.ignite_near(plants[1]["at"] if plants.size() > 1 else plants[0]["at"], 20.0, 1.0),
		"a plant caught fire in a downpour")
	_dry()
	_fire.ignite_near(plants[0]["at"], 20.0, 1.0)
	RunState.flood = 0.8
	_fire._process(0.1)
	_check(_fire.fire_count() == 0, "a flood left a fire burning")
	RunState.flood = 0.0
	await get_tree().process_frame


## **A funnel that passes costs a tower; a funnel that stands fells it.**
##
## **This invariant was amended on 2026-09-22 and the old one is recorded
## here rather than quietly replaced.** It read *"the funnel walked over a
## tower and left it standing"* - a funnel crossing the 84-unit wake in 1.4
## seconds had to fell a 610-hp grit_sling, which required at least 436 tower
## DPS and is why `TORNADO_TOWER_DPS` was 700. The owner reported the
## consequence: a single pass deleted every emplacement on a road, in one and
## a half seconds, with nothing the player could do about it.
##
## What replaces it holds *both* ends, which the old one did not:
##
## - a straight pass **hurts** the tower and **does not fell it** - so the
##   nerf cannot be undone by raising the constant back;
## - a funnel **parked** on the tower fells it inside twelve seconds - so the
##   nerf cannot be taken any further either, and a tornado stays a thing you
##   lose a tower to if you leave it alone.
##
## The body beside the path is unchanged: it must be hurt and not killed.
func _test_the_tornado() -> void:
	await _clear_towers()
	var at: Vector2 = _pocket(1)
	var tower: Tower = _build("grit_sling", at)
	_check(tower != null, "a tower to put in the funnel's way")
	if tower == null:
		return
	# Tough enough to survive the edge of the funnel and show the difference
	# between the wake and the wind around it.
	var bystander: Enemy = _body(tower.global_position + Vector2(0.0, Balance.TORNADO_AOE * 0.8), 40.0)
	await get_tree().process_frame
	var bystander_hp: float = bystander.health.current_hp
	var whole: float = tower.health_ratio()
	var before: int = _sky.tornadoes
	var funnel: Tornado = _sky.spawn_tornado(tower.global_position + Vector2(-Balance.TORNADO_SPEED * 3.0, 0.0),
		tower.global_position + Vector2(Balance.TORNADO_SPEED * 3.0, 0.0), 40.0)
	_check(funnel != null and _sky.tornadoes == before + 1, "the funnel was spawned and counted")
	if funnel == null:
		return
	# Aimed at the tower and walking straight: the wander is what the gate is
	# not measuring, and with it on the funnel missed one run in three.
	funnel.wander = 0.0
	var seconds: float = 0.0
	while seconds < 7.0:
		funnel._process(0.1)
		seconds += 0.1
	_check(tower != null and is_instance_valid(tower) and tower.is_vulnerable(),
		"one pass of a funnel deleted a tower outright, which is what the "
			+ "2026-09-22 nerf exists to stop")
	if tower == null or not is_instance_valid(tower):
		return
	var after_pass: float = tower.health_ratio()
	_check(after_pass < whole,
		"the funnel walked over a tower and cost it nothing (%.2f)" % after_pass)
	_check(bystander.health.current_hp < bystander_hp and bystander.health.current_hp > 0.0,
		"a body beside the funnel's path was not hurt, or was killed outright")

	# **And a funnel that stands on it does fell it.** Parked by putting it
	# back on the tower after every tick: what is being measured is the
	# damage, and the walk is the other half of the test above.
	var parked: float = 0.0
	while tower != null and is_instance_valid(tower) and tower.is_vulnerable() and parked < 12.0:
		funnel.at = tower.global_position
		funnel.position = funnel.at
		funnel._process(0.1)
		parked += 0.1
	_check(funnel.towers_felled >= 1,
		"a funnel parked on a tower for twelve seconds left it standing")

	funnel.seconds_left = 0.0
	funnel._process(0.1)
	await get_tree().process_frame
	bystander.queue_free()
	await get_tree().process_frame


## A stone lands near a tower, hurts it and everything around, and marks the
## ground.
func _test_the_meteor() -> void:
	await _clear_towers()
	var at: Vector2 = _pocket(2)
	var tower: Tower = _build("grit_sling", at)
	_check(tower != null, "a tower for the stone to aim at")
	if tower == null:
		return
	var before: int = _sky.meteors
	var stone: Meteor = _sky.drop_meteor()
	_check(stone != null and _sky.meteors == before + 1, "the stone was thrown and counted")
	if stone == null:
		return
	var near_some_tower: bool = false
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var built := node as Tower
		if built != null and built.global_position.distance_to(stone.at) <= Balance.METEOR_SCATTER + 1.0:
			near_some_tower = true
	_check(near_some_tower, "the stone was aimed nowhere near a tower")
	_check(stone.at.length() >= Balance.LIGHTNING_TOWN_CLEARANCE, "the stone was aimed at the city")
	var victim: Enemy = _body(stone.at)
	await get_tree().process_frame
	var victim_hp: float = victim.health.current_hp
	var ratio_before: float = 1.0
	var target: Tower = _field.tower_near(stone.at, Balance.METEOR_RADIUS)
	if target != null:
		ratio_before = target.health_ratio()
	stone._process(Balance.METEOR_WARNING + 0.1)
	_check(victim.health.current_hp < victim_hp, "the body under the stone was not hurt")
	if target != null:
		_check(target.health_ratio() < ratio_before, "the tower under the stone was not hurt")
	_check(_field.scorch().marked_at(stone.at), "the stone left no mark")
	victim.queue_free()
	await get_tree().process_frame
	_fire.call("_clear")


## Dry, the arc reaches a body two hundred units on and no further; in a
## flood it reaches one three times further.
func _test_chain_lightning() -> void:
	_dry()
	var at: Vector2 = Vector2(-800.0, -800.0)
	var first: Enemy = _body(at + Vector2(140.0, 0.0))
	var second: Enemy = _body(at + Vector2(140.0 + Balance.CHAIN_RANGE * 1.4, 0.0))
	await get_tree().process_frame
	var first_hp: float = first.health.current_hp
	var second_hp: float = second.health.current_hp
	var arcs: int = _sky.chain_arcs
	_sky.strike_at(at)
	_check(first.health.current_hp < first_hp, "the arc did not reach the body beside the strike")
	_check(is_equal_approx(second.health.current_hp, second_hp), "on dry ground the arc reached a body it could not")
	_check(_sky.chain_arcs > arcs, "no arc was drawn")
	RunState.flood = 1.0
	second_hp = second.health.current_hp
	_sky.strike_at(at)
	_check(second.health.current_hp < second_hp, "in a flood the arc did not carry to the far body")
	RunState.flood = 0.0
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame


## The flood and the rain feed the water towers; the rain fills the wells.
func _test_water_feeds_the_water_towers() -> void:
	await _clear_towers()
	var lance: Tower = _build("rime_lance", _pocket(3))
	if lance == null:
		return
	RunState.flood = 0.0
	RunState.rain_intensity = 0.0
	var calm: float = lance.effective_damage()
	RunState.flood = 1.0
	_check(lance.effective_damage() > calm * 1.3, "a flood did not feed the water tower")
	RunState.flood = 0.0
	RunState.rain_intensity = 1.0
	_check(lance.effective_damage() > calm * 1.15, "the rain did not feed the water tower")
	var well: Tower = _build("healing_well", _pocket(0))
	if well != null:
		RunState.rain_intensity = 0.0
		var slow: float = well.well_refill_seconds()
		RunState.rain_intensity = 1.0
		_check(well.well_refill_seconds() < slow * 0.7, "the rain did not fill the well faster")
	RunState.rain_intensity = 0.0
	await get_tree().process_frame


## Over the knee, nobody dashes.
func _test_deep_water_stops_the_dash() -> void:
	var hero: Hero = _field.hero
	hero.refund_dash(1.0)
	RunState.flood = 1.0
	hero._try_dash()
	_check(float(hero.get("_dash_left")) <= 0.0, "the hero dashed through a flood")
	RunState.flood = 0.0
	hero.refund_dash(1.0)
	hero._try_dash()
	_check(float(hero.get("_dash_left")) > 0.0, "the hero could not dash on dry ground")
	await get_tree().process_frame
	hero.set("_dash_left", 0.0)


## A body a tower hits may turn on it; a Bastion pulls some in and not others,
## and wears armour for it.
func _test_enemies_turn_on_towers() -> void:
	await _clear_towers()
	var tower: Tower = _build("grit_sling", _pocket(1))
	_check(tower != null, "a tower to be turned on")
	if tower == null:
		return
	var body: Enemy = _body(tower.global_position + Vector2(120.0, 0.0))
	await get_tree().process_frame
	var blows: int = 0
	while body.get("_grudge") == null and blows < 60:
		body.take_damage(1.0, tower.origin(), 0.0)
		blows += 1
	_check(body.get("_grudge") != null, "sixty blows from a tower and the body never turned on it")
	_check(body._pick_target() == tower, "a grudge did not make the tower the target")
	body.queue_free()
	# The Bastion: a chance, not a certainty, and armour. It is a fusion, so
	# it wants two Earth parents either side of an empty plot.
	var bastion: Tower = _build_fusion("bastion", "grit_sling", _pocket(2))
	_check(bastion != null, "the harness must be able to fuse a Bastion")
	if bastion != null:
		var pulled: int = 0
		var bodies: Array[Enemy] = []
		for _i: int in 30:
			var one: Enemy = _body(bastion.global_position + Vector2(100.0, 0.0))
			bodies.append(one)
		await get_tree().process_frame
		for one: Enemy in bodies:
			if bool(one.call("_taunted_by", bastion)):
				pulled += 1
			one.queue_free()
		_check(pulled > 0 and pulled < 30, "the Bastion pulled %d of 30 bodies: a taunt is a chance" % pulled)
		var armour: Health = Health.of(bastion)
		_check(armour != null and armour.flat_damage_reduction >= Balance.TAUNT_TOWER_ARMOUR,
			"the Bastion wears no extra armour")
	await get_tree().process_frame


## A guest draws what it is told and hurts nothing.
func _test_the_guest_only_draws() -> void:
	var mirror := Wildfire.new()
	mirror.field = _field
	mirror.foliage = _fire.call("_foliage")
	add_child(mirror)
	await get_tree().process_frame
	mirror.set("_mirror", true)
	var plants: Array[Dictionary] = mirror.foliage.plants_near(Vector2(900.0, -900.0), 1200.0)
	if not plants.is_empty():
		EventBus.coop_wildfire_lit.emit(plants[0]["at"])
		_check(mirror.fire_count() == 1, "a guest's wildfire did not light the plant it was told about")
		var body: Enemy = _body(plants[0]["at"])
		await get_tree().process_frame
		var hp: float = body.health.current_hp
		for _i: int in 6:
			mirror._process(0.5)
		_check(is_equal_approx(body.health.current_hp, hp), "a guest's fire hurt a body")
		body.queue_free()
	mirror.call("_clear")
	mirror.queue_free()
	await get_tree().process_frame


## Between acts the earth eases and does not forget.
func _test_acts_ease_the_wrath() -> void:
	_sky.set("_wrath_floor", 0.4)
	_sky.set("_wrath_heat", 0.3)
	var before: float = _sky.wrath()
	EventBus.act_started.emit(RunState.act, RunState.terrain_id)
	await get_tree().process_frame
	var after: float = _sky.wrath()
	_check(after < before and after > 0.0,
		"an act should ease the wrath and keep some of it (%.2f -> %.2f)" % [before, after])
	# A frame of cooling sits between the two reads, so a hundredth of slack.
	_check(absf(after - before * Balance.WRATH_ACT_CARRY) < 0.01,
		"the carry is %.2f of what it was, not %.2f" % [Balance.WRATH_ACT_CARRY, after / maxf(before, 0.001)])
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	_sky.set("_tier_told", 0)
	await get_tree().process_frame


## A strike leaves a storm core; the air towers on it are overcharged, the
## others are not; it fades, it caps, it renews rather than doubles, and an
## act clears it.
func _test_the_ground_stays_charged() -> void:
	_dry()
	await _clear_towers()
	var ground: WrathZones = _field.zones()
	_check(ground != null, "the field stands charged ground up")
	if ground == null:
		return
	ground.clear()
	var air_id: String = ""
	for value: Variant in ContentDB.towers.values():
		var data := value as TowerData
		if data != null and data.element == TowerData.Element.AIR and not data.is_combination:
			air_id = data.id
			break
	_check(not air_id.is_empty(), "an air tower to stand in the storm")
	if air_id.is_empty():
		return
	var tower: Tower = _build(air_id, _pocket(3))
	if tower == null:
		return
	var calm: float = tower.effective_damage()
	var opened: int = ground.opened
	var centre: Vector2 = tower.global_position + Vector2(40.0, 0.0)
	_check(ground.open("storm_core", centre, Balance.ZONE_STORM_RADIUS), "a storm core opens")
	_check(ground.opened == opened + 1 and ground.count() == 1, "one zone opened and stands")
	_check(tower.effective_damage() > calm * 1.2,
		"an air tower on a storm core deals %.1f against %.1f calm" % [tower.effective_damage(), calm])
	_check(is_zero_approx(ground.boost_at(TowerData.Element.EARTH, centre)), "the wrong element was fed")
	var edge: float = ground.boost_at(TowerData.Element.AIR, centre + Vector2(Balance.ZONE_STORM_RADIUS * 0.9, 0.0))
	_check(ground.boost_at(TowerData.Element.AIR, centre) > edge and edge > 0.0,
		"the charge should fall toward the edge and still count there")
	_check(is_zero_approx(ground.boost_at(TowerData.Element.AIR, centre + Vector2(Balance.ZONE_STORM_RADIUS * 1.2, 0.0))),
		"outside the zone is charged")
	# The same kind over the same ground renews it.
	ground.open("storm_core", centre + Vector2(30.0, 0.0), Balance.ZONE_STORM_RADIUS)
	_check(ground.count() == 1, "a second storm core on the first doubled it (%d)" % ground.count())
	# A strike opens one on its own.
	ground.clear()
	_sky.strike_at(_pocket(0))
	_check(ground.kind_at(_pocket(0)) == "storm_core", "a strike left no storm core under it")
	# The cap.
	for index: int in Balance.ZONE_MAX + 3:
		ground.open("burning_ground", Vector2(-2000.0 + float(index) * Balance.ZONE_BURN_RADIUS * 2.5, -1800.0),
			Balance.ZONE_BURN_RADIUS)
	_check(ground.count() == Balance.ZONE_MAX, "%d zones stand against a cap of %d" % [ground.count(), Balance.ZONE_MAX])
	# They fade.
	ground._process(Balance.ZONE_SECONDS + 1.0)
	_check(ground.count() == 0, "the zones outlived their seconds (%d)" % ground.count())
	# And an act clears them.
	ground.open("storm_core", centre, Balance.ZONE_STORM_RADIUS)
	EventBus.act_started.emit(RunState.act, RunState.terrain_id)
	await get_tree().process_frame
	_check(ground.count() == 0, "an act began and the ground stayed charged")
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	_fire.call("_clear")
	await get_tree().process_frame


## The ground hums first, then breaks, and leaves a fault.
func _test_the_quake_is_telegraphed() -> void:
	_dry()
	_sky.set("_quake_left", 0.0)
	_sky.set("_quake_warning_left", 0.0)
	var quakes: int = _sky.quakes
	var ground: WrathZones = _field.zones()
	var opened: int = ground.opened if ground != null else 0
	var warned: Array[String] = []
	var catcher: Callable = func(kind_id: String, _at: Vector2, _seconds: float) -> void: warned.append(kind_id)
	EventBus.wrath_warned.connect(catcher)
	_sky.warn_quake(0.8)
	_check(warned.has("quake"), "the quake was not warned")
	_check(_sky.quakes == quakes, "the warning is not the quake")
	_step(Balance.QUAKE_WARNING_SECONDS * 0.5)
	_check(_sky.quakes == quakes, "halfway through the warning the ground broke")
	_step(Balance.QUAKE_WARNING_SECONDS * 0.5 + 1.0)
	_check(_sky.quakes == quakes + 1, "the warning ran out and the quake did not come")
	# **The fault arrives with the wave rather than with the break.** It is
	# laid where the first crest's own front was strongest, which is a couple
	# of seconds out - and `_step` drives the sky by hand, which never ticks
	# a wave living under the battlefield. The invariant is the one it always
	# was: a quake leaves a fault. Only the moment moved.
	await _let_the_wave_run()
	if ground != null:
		_check(ground.opened == opened + 1, "the quake left no fault")
		ground.clear()
	EventBus.wrath_warned.disconnect(catcher)
	_step(Balance.QUAKE_SECONDS + 0.5)
	await get_tree().process_frame


## The wind rises first, then the funnel is born where it rose.
func _test_the_tornado_is_telegraphed() -> void:
	var before: int = _sky.tornadoes
	var from: Vector2 = _pocket(2) + Vector2(-600.0, 0.0)
	_sky.warn_tornado(from, _pocket(2), 6.0)
	_check(_sky.tornadoes == before, "the wind rising is not the funnel")
	_step(Balance.TORNADO_WARNING_SECONDS * 0.5)
	_check(_sky.tornadoes == before, "the funnel came before the wind finished rising")
	_step(Balance.TORNADO_WARNING_SECONDS * 0.5 + 1.0)
	_check(_sky.tornadoes == before + 1, "the wind rose and no funnel came")
	for node: Node in get_tree().get_nodes_in_group(Tornado.GROUP):
		node.queue_free()
	await get_tree().process_frame
	if _field.zones() != null:
		_field.zones().clear()


## A funnel through a fire carries it, and lights the brush in its wake.
func _test_the_fire_whirl() -> void:
	_dry()
	_fire.call("_clear")
	var foliage: Foliage = _fire.call("_foliage")
	var seed_at: Vector2 = Vector2.INF
	for candidate: Dictionary in foliage.plants_near(Vector2.ZERO, BattleGrid.CORE_HALF_EXTENT * 1.4):
		if foliage.plants_near(candidate["at"] as Vector2, Balance.WILDFIRE_SPREAD_RADIUS).size() >= 4:
			seed_at = candidate["at"]
			break
	_check(seed_at.is_finite(), "a thicket for the fire whirl")
	if not seed_at.is_finite():
		return
	_check(_fire.ignite_near(seed_at, 20.0, 1.0), "the thicket did not catch")
	var lit: int = _fire.lit_count
	var funnel: Tornado = _sky.spawn_tornado(seed_at + Vector2(-Balance.TORNADO_SPEED * 2.0, 0.0),
		seed_at + Vector2(Balance.TORNADO_SPEED * 2.0, 0.0), 30.0)
	funnel.wander = 0.0
	_check(not funnel.burning(), "a funnel is born burning")
	for _i: int in 50:
		funnel._process(0.1)
	_check(funnel.burning(), "a funnel through a fire did not catch")
	_check(_fire.lit_count > lit, "a fire whirl lit nothing in its wake")
	funnel.seconds_left = 0.0
	funnel._process(0.1)
	await get_tree().process_frame
	_fire.call("_clear")
	if _field.zones() != null:
		_field.zones().clear()


## A strike on dry brush under a heatwave lights it; one in a downpour does not.
func _test_dry_lightning() -> void:
	_dry()
	_fire.call("_clear")
	_weather("heatwave")
	_sky.set("_temperature", 40.0)
	_step(2.0)
	var foliage: Foliage = _fire.call("_foliage")
	var plants: Array[Dictionary] = foliage.plants_near(Vector2(-900.0, -900.0), 2400.0)
	_check(not plants.is_empty(), "plants for the dry lightning")
	if plants.is_empty():
		return
	var at: Vector2 = plants[0]["at"]
	var lit: bool = false
	for _i: int in 40:
		_sky.strike_at(at)
		if _fire.fire_count() > 0:
			lit = true
			break
	_check(lit, "forty dry strikes on the brush under a heatwave and nothing caught")
	_fire.call("_clear")
	_weather("downpour")
	_sky.forced_intensity = 1.0
	_step(3.0)
	for _i: int in 20:
		_sky.strike_at(at)
	_check(_fire.fire_count() == 0, "a strike in a downpour lit the brush")
	_dry()
	_fire.call("_clear")
	if _field.zones() != null:
		_field.zones().clear()
	await get_tree().process_frame


## A guest opens the ground it is told about, says the warning it is told,
## and never fires the event itself.
func _test_the_guest_is_told() -> void:
	var mirror := WrathZones.new()
	add_child(mirror)
	await get_tree().process_frame
	mirror.set("_mirror", true)
	EventBus.coop_wrath_zone_opened.emit("storm_core", Vector2(500.0, 500.0), 200.0, 30.0)
	_check(mirror.count() == 1, "a guest did not open the zone it was told about")
	_check(not mirror.open("storm_core", Vector2.ZERO, 200.0), "a guest opened a zone on its own")
	mirror.queue_free()
	var said: Array[String] = []
	var catcher: Callable = func(line: String, _title: String) -> void: said.append(line)
	EventBus.sky_warned.connect(catcher)
	var quakes: int = _sky.quakes
	_sky.set("_mirror", true)
	EventBus.coop_wrath_warned.emit("quake", Vector2.ZERO, 1.0)
	_step(2.0)
	_sky.set("_mirror", false)
	EventBus.sky_warned.disconnect(catcher)
	var kind: WrathEventData = ContentDB.wrath_event("quake")
	_check(kind != null and said.has(kind.warning), "a guest did not say the warning it was told")
	_check(_sky.quakes == quakes, "a guest's warning ran out and it shook the ground itself")
	await get_tree().process_frame


## The rarer the animal the sharper the cost; a shiny and an elite more; a
## legendary is a shock the world announces and a window of raised hazard.
func _test_rarity_and_the_shock() -> void:
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	# Measured on the heat, which has no cap; `wrath()` clamps and a
	# legendary alone reaches the ceiling.
	var costs: Array[float] = []
	for rarity: int in 4:
		var before: float = float(_sky.get("_wrath_heat"))
		EventBus.wildlife_killed.emit("stag", 3, Vector2.ZERO, rarity, false, false)
		costs.append(float(_sky.get("_wrath_heat")) - before)
	for rarity: int in 3:
		_check(costs[rarity + 1] > costs[rarity] * 1.5,
			"rarity %d should cost sharply more than %d (%.3f against %.3f)" % [rarity + 1, rarity, costs[rarity + 1], costs[rarity]])
	var plain: float = float(_sky.get("_wrath_heat"))
	EventBus.wildlife_killed.emit("stag", 3, Vector2.ZERO, 1, true, false)
	var shiny_cost: float = float(_sky.get("_wrath_heat")) - plain
	_check(shiny_cost > costs[1] * 1.2, "a shiny should cost more than its rarity alone")
	plain = float(_sky.get("_wrath_heat"))
	EventBus.wildlife_killed.emit("stag", 3, Vector2.ZERO, 1, false, true)
	_check(float(_sky.get("_wrath_heat")) - plain > costs[1] * 1.5, "an elite should cost more than its rarity alone")
	# The legendary above told the world and opened the shock.
	_check(_sky.shocks >= 1, "a legendary died and the earth was not shocked")
	_check(_sky.hazard_boost() > 1.0, "the shock did not lift the earth's hazards")
	_check(_sky.wind() == Vector2.ZERO, "the wind did not stop for the legendary")
	_step(Balance.WRATH_SHOCK_SECONDS + 1.0)
	_check(is_equal_approx(_sky.hazard_boost(), 1.0 / (1.0 + float(_sky.anchors()) * Balance.WRATH_ANCHOR_CALM)),
		"the shock did not pass")
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	_sky.set("_tier_told", 0)
	await get_tree().process_frame


## A living legendary calms the earth and speeds its recovery; the floor
## recovers only when the road has been quiet, and never below nothing.
func _test_anchors_and_recovery() -> void:
	var animals: Wildlife = _field.wildlife()
	var legendary: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.rarity == WildlifeData.Rarity.LEGENDARY:
			legendary = kind
			break
	_check(legendary != null, "a legendary species to anchor the road")
	var calm_alone: float = _sky.hazard_boost()
	var living_before: int = animals.living_legendaries()
	if legendary != null:
		animals.call("_spawn", legendary, Vector2(900.0, -300.0))
		await get_tree().process_frame
		_check(animals.living_legendaries() == living_before + 1, "the legendary did not stand")
		_check(_sky.hazard_boost() < calm_alone, "a living legendary did not calm the earth (%.2f against %.2f)" % [_sky.hazard_boost(), calm_alone])
	# Quiet: nothing killed, felled or burnt - the floor eases.
	_sky.set("_wrath_floor", 0.3)
	_sky.set("_quiet", 0.0)
	_step(Balance.WRATH_QUIET_SECONDS * 0.5)
	_check(is_equal_approx(float(_sky.get("_wrath_floor")), 0.3), "the floor eased before the road was quiet")
	_step(Balance.WRATH_QUIET_SECONDS + 120.0)
	var eased: float = float(_sky.get("_wrath_floor"))
	_check(eased < 0.3 and eased > 0.0, "a quiet road should ease the floor and keep some (%.3f)" % eased)
	# A kill resets the quiet.
	EventBus.wildlife_killed.emit("rabbit", 1, Vector2.ZERO, 0, false, false)
	_check(float(_sky.get("_quiet")) == 0.0, "a kill did not reset the quiet")
	# Clear-cutting: a few fells are free, the rest cost.
	_sky.set("_wrath_heat", 0.0)
	for _i: int in Balance.WRATH_FELL_FREE:
		EventBus.gathered.emit("ashwood_log", 1)
	_check(is_zero_approx(float(_sky.get("_wrath_heat"))), "the first fells should be free")
	for _i: int in 4:
		EventBus.gathered.emit("ashwood_log", 1)
	_check(float(_sky.get("_wrath_heat")) > 0.0, "clear-cutting cost nothing")
	EventBus.gathered.emit("iron_ore", 1)
	var after_ore: float = float(_sky.get("_wrath_heat"))
	EventBus.gathered.emit("iron_ore", 1)
	_check(is_equal_approx(float(_sky.get("_wrath_heat")), after_ore), "ore is not a tree")
	# A fire the player lit burns a forest: the earth counts the plants.
	_dry()
	_fire.call("_clear")
	var foliage: Foliage = _fire.call("_foliage")
	var plants: Array[Dictionary] = foliage.plants_near(Vector2(-900.0, -900.0), 2400.0)
	if not plants.is_empty():
		_sky.set("_wrath_heat", 0.0)
		_check(_fire.ignite_near(plants[0]["at"], 20.0, 1.0, true), "the player's fire did not catch")
		for _i: int in int(Balance.WILDFIRE_BURN_SECONDS * 2.0) + 4:
			_fire._process(0.5)
		_sky._process(0.5)
		_check(_fire.burnt_by_player >= 1, "a plant the player's fire burnt was not counted")
		_check(float(_sky.get("_wrath_heat")) > 0.0, "a forest burnt by the player's fire cost nothing")
	_fire.call("_clear")
	if _field.zones() != null:
		_field.zones().clear()
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	_sky.set("_tier_told", 0)
	await get_tree().process_frame


## Every element's strain feeds the anger, each settling on its own clock,
## and the wind is a vector that leans with the weather.
func _test_strain_and_the_wind() -> void:
	_sky.set("_wrath_heat", 0.0)
	RunState.tide = Balance.TIDE_FULL
	RunState.tremor = Balance.TREMOR_FULL
	_sky._process(1.0)
	_check(float(_sky.get("_wrath_heat")) > 0.0, "water and earth strain fed nothing")
	_check(RunState.tide < Balance.TIDE_FULL and RunState.tremor < Balance.TREMOR_FULL, "the strains did not settle")
	_check(RunState.tide < RunState.tremor, "water should drain faster than the ground settles (%.0f against %.0f)" % [RunState.tide, RunState.tremor])
	RunState.tide = 0.0
	RunState.tremor = 0.0
	# Fire cools faster in the rain.
	RunState.ember = 2000.0
	_sky._process(1.0)
	var dry_left: float = RunState.ember
	RunState.ember = 2000.0
	RunState.rain_intensity = 1.0
	_sky._process(1.0)
	_check(RunState.ember < dry_left, "rain should cool the ember faster (%.0f against %.0f dry)" % [RunState.ember, dry_left])
	RunState.rain_intensity = 0.0
	RunState.ember = 0.0
	# The wind: none in still air, a vector along the road in a wind.
	# A clear sky carries its authored breeze and no more; a downpour blows.
	_weather("clear")
	_sky._process(0.5)
	var breeze: float = absf(ContentDB.weather("clear").wind)
	_check(_sky.wind().length() <= breeze * 1.3 + 0.001, "a clear sky blows %.2f against its %.2f" % [_sky.wind().length(), breeze])
	_weather("downpour")
	_sky._process(0.5)
	var blowing: Vector2 = _sky.wind()
	_check(blowing.length() > 0.2, "a downpour's wind is %.2f" % blowing.length())
	_check(RunState.wind == blowing, "the wind was not published")
	_dry()
	_sky.set("_wrath_heat", 0.0)
	_sky.set("_tier_told", 0)
