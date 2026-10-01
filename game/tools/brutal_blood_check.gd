extends Node

## **Brutal blood, and the ground that remembers** (owner, 2026-10-01):
##
##   godot --headless --path game res://tools/brutal_blood_check.tscn
##
## - **Brutal is a fourth level**, above High, saved by number; High is still
##   High.
## - **A Brutal mark never fades on its own**: no time ages it away and no rain
##   washes it; a flood short of heavy does nothing; a heavy flood thins it over
##   a long while and **never takes it** - it holds at `BLOOD_BRUTAL_WASH_FLOOR`
##   (owner, 2026-10-01: "Brutal blood is practically forever"). Amended on that
##   date: this gate used to insist a held heavy flood washed the field clean.
## - **Nothing Brutal is ever lost**: a mark the field lets go of past its cap
##   is baked into the ground's stain map, and a pool that soaks away leaves a
##   stain as deep as it stood. Deep pools soak away slower than shallow ones.
## - **Dense blood pools**, and only on Brutal: deep where it fell thickest,
##   creeping out and thinning as it spreads, soaking away slowly - faster
##   while the ground shakes.
## - **A pool slows what walks in it** - the same door for every mover - and
##   **stains it to the height it waded**, for as long as it lives.
## - **It comes home with a banked front**, marks and pools, and on no other
##   level.
## - **The ground keeps its scars**: a dent is a bowl with a lip, a crack runs
##   its line, a quake cracks and slumps the ground round where it broke - and
##   since 2026-10-01 the act's end **keeps** them, and so do the burns and the
##   holes, and all three come home with a banked front (owner: "permanent for
##   the entire continuation of all of the runs that journey continues").

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run = null
var _field: Battlefield = null
var _blood: BloodField = null
var _dice := RandomNumberGenerator.new()


func _ready() -> void:
	MetaState.hold_saves()
	_dice.seed = 20261015
	RunState.reset(false, 20261015)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_field.claim_effects()
	_blood = Vfx.blood_field()
	_check(_blood != null, "the field has no blood on its ground")
	if _blood != null:
		_test_the_level()
		_test_it_never_fades_but_to_a_heavy_flood()
		_test_nothing_brutal_is_lost()
		_test_it_pools_spreads_and_soaks()
		await _test_it_slows_and_stains_what_wades()
		_test_it_comes_home()
		_test_the_ground_keeps_its_scars()
	_check(_finished == 7, "%d of 7 tests reached their end" % _finished)
	UserSettings.set_blood_level(UserSettings.BLOOD_LOW)
	RunState.flood = 0.0
	RunState.set_phase(RunState.Phase.PREPARATION)
	GameDirector.run_active = false
	_run.queue_free()
	MetaState.resume_saves()
	if _failures == 0:
		print("[brutal-blood] PASS - %d checks: a fourth level that never fades but to a heavy flood, pools that spread, soak and slosh, slow every mover and stain what wades, come home with a front, and a ground that keeps its scars" % _checks)
	else:
		push_error("[brutal-blood] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _test_the_level() -> void:
	_check(UserSettings.BLOOD_LEVEL_NAMES.size() == 4 and UserSettings.BLOOD_LEVEL_NAMES[3] == "Brutal",
		"Brutal is not the fourth blood level")
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	_check(UserSettings.blood_level() == UserSettings.BLOOD_BRUTAL, "the blood setting will not hold Brutal")
	UserSettings.set_blood_level(UserSettings.BLOOD_HIGH)
	_check(UserSettings.blood_level() == UserSettings.BLOOD_HIGH, "High is no longer High")
	_finished += 1


## Runs the field's own clock for `seconds`, in steps.
func _age(seconds: float, step: float = 50.0) -> void:
	var left: float = seconds
	while left > 0.0:
		var dt: float = minf(step, left)
		_blood._process(dt)
		left -= dt


func _test_it_never_fades_but_to_a_heavy_flood() -> void:
	_blood.wipe()
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	RunState.flood = 0.0
	_blood.splat(Vector2(400.0, 1200.0), Vector2.RIGHT, Balance.VFX_BLOOD_HIT_SIZE, _dice)
	_age(200000.0, 5000.0)
	_check(_blood.marks() == 1, "a Brutal mark faded away with nothing but time")
	RunState.weather_id = "downpour"
	EventBus.weather_changed.emit("downpour")
	# A downpour is rain to the field: High would wash under it.
	UserSettings.set_blood_level(UserSettings.BLOOD_HIGH)
	_check(_blood.wash_multiplier() > 1.0, "the harness's downpour is no rain to the blood field")
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	_check(is_equal_approx(_blood.wash_multiplier(), 1.0), "rain washes Brutal blood")
	RunState.flood = Balance.BLOOD_BRUTAL_FLOOD_FROM - 0.1
	_check(is_equal_approx(_blood.wash_multiplier(), 1.0), "a flood short of heavy washes Brutal blood")
	_age(600.0, 10.0)
	_check(is_zero_approx(_blood.wash_clock()), "a flood short of heavy ran the flood clock")
	# A heavy flood at the height that drowns, held ten times its own while.
	RunState.flood = 1.0
	_age(Balance.BLOOD_BRUTAL_WASH_TAU * 10.0, 10.0)
	_check(_blood.marks() == 1, "a heavy flood took a Brutal mark away")
	var left: float = _blood.brutal_left_of(0.0)
	_check(left >= Balance.BLOOD_BRUTAL_WASH_FLOOR - 0.001,
		"a heavy flood took a Brutal mark below its floor: %.2f left" % left)
	_check(left < 0.95, "a heavy flood held ten times its while did not thin a Brutal mark at all (%.2f left)" % left)
	# And it takes great depth: just past the threshold the clock barely moves.
	var shallow: float = BloodField.brutal_flood_rate(Balance.BLOOD_BRUTAL_FLOOD_FROM + 0.02)
	_check(shallow < 0.02, "a flood just past heavy thins Brutal blood at %.3f of its fastest" % shallow)
	RunState.flood = 0.0
	RunState.weather_id = "clear"
	EventBus.weather_changed.emit("clear")
	_finished += 1


func _pour_a_fight(at: Vector2, splats: int) -> void:
	for _i: int in splats:
		_blood.splat(at + Vector2(_dice.randf_range(-30.0, 30.0), _dice.randf_range(-20.0, 20.0)),
			Vector2.from_angle(_dice.randf() * TAU), Balance.VFX_BLOOD_DEATH_SIZE, _dice)


## **Nothing Brutal is ever lost** (owner, 2026-10-01). The field's cap used to
## throw the oldest mark away; past it now, the mark is baked into the stain map.
func _test_nothing_brutal_is_lost() -> void:
	_blood.wipe()
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	var first: Vector2 = Vector2(-1500.0, -1500.0)
	_blood.splat(first, Vector2.RIGHT, Balance.VFX_BLOOD_DEATH_SIZE, _dice)
	for index: int in Balance.BLOOD_MARKS_BRUTAL + 40:
		_blood.droplet(Vector2(1500.0, 1500.0) + Vector2(float(index % 40) * 6.0, float(index / 40) * 6.0),
			2.5, _dice)
	_check(_blood.held() <= Balance.BLOOD_MARKS_BRUTAL, "the field held %d marks past its cap" % _blood.held())
	var stains: BloodStains = _blood.stains_if_any()
	_check(stains != null and stains.baked > 0, "a Brutal mark past the cap was thrown away, not baked")
	_check(stains != null and stains.coverage_at(first) > 0.2,
		"the first mark's ground holds no stain after it was let go (%.2f)"
			% (stains.coverage_at(first) if stains != null else 0.0))
	# It comes home with the front.
	var banked: Dictionary = Vfx.blood_snapshot()
	_check(not String(banked.get("stains", "")).is_empty(), "a Brutal field banked no stain map")
	var again := BloodField.new()
	add_child(again)
	again.restore(banked)
	var restored: BloodStains = again.stains_if_any()
	_check(restored != null and absf(restored.coverage_at(first) - stains.coverage_at(first)) < 0.02,
		"the restored stain map does not hold the banked stain")
	again.queue_free()
	# A pool that soaks away leaves a stain, and a deep pool outlasts a shallow one.
	var deep := BloodPools.new()
	var shallow := BloodPools.new()
	add_child(deep)
	add_child(shallow)
	deep.pour(Vector2(0.0, 0.0), 8.0, 10.0)
	shallow.pour(Vector2(0.0, 0.0), 0.4, 10.0)
	# Measured as how long each lasts, because a deep pool spreads over more
	# ground and so loses a larger share early - what the owner asked for is a
	# pool that stays, and a deeper one that stays longer.
	var shallow_life: float = 0.0
	while shallow.total() > 0.0 and shallow_life < 20000.0:
		deep._simulate(2.0)
		shallow._simulate(2.0)
		shallow_life += 2.0
	_check(shallow_life >= 150.0, "a thin pool of a few drops soaked away in %.0f seconds" % shallow_life)
	_check(deep.total() > 0.0, "a deep pool was gone as soon as a shallow one (%.0f s)" % shallow_life)
	var dried := BloodPools.new()
	add_child(dried)
	var ground := BloodStains.new()
	add_child(ground)
	dried.stains = ground
	dried.pour(Vector2(40.0, 40.0), 0.02, 10.0)
	for _step: int in 400:
		dried._simulate(1.0)
	_check(dried.total() <= 0.0, "a thin film never soaked away")
	_check(ground.coverage_at(Vector2(40.0, 40.0)) > 0.05,
		"a pool that soaked away left no stain on its ground")
	for node: Node in [deep, shallow, dried, ground]:
		node.queue_free()
	_blood.wipe()
	_finished += 1


func _test_it_pools_spreads_and_soaks() -> void:
	_blood.wipe()
	UserSettings.set_blood_level(UserSettings.BLOOD_HIGH)
	_pour_a_fight(Vector2(-600.0, 1300.0), 10)
	var none: BloodPools = _blood.pools_if_any()
	_check(none == null or none.total() <= 0.0, "High blood pooled")
	_blood.wipe()
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	var at: Vector2 = Vector2(-600.0, 1300.0)
	_pour_a_fight(at, 40)
	var pools: BloodPools = _blood.pools_if_any()
	_check(pools != null and pools.total() > 0.0, "a Brutal fight left no pool")
	if pools == null:
		_finished += 1
		return
	var deep: float = pools.depth_at(at)
	_check(deep > Balance.BLOOD_POOL_SLOW_FROM, "forty deaths in one place pooled only %.3f deep" % deep)
	_check(pools.depth_at(at + Vector2(600.0, 0.0)) <= 0.0, "a pool reached ground nobody bled on")
	var cells: int = pools.active_count()
	var whole: float = pools.total()
	for _step: int in 40:
		pools._simulate(1.0 / Balance.BLOOD_POOL_SIM_HZ)
	_check(pools.active_count() > cells, "the pool did not creep out (%d cells, then %d)" % [cells, pools.active_count()])
	_check(pools.depth_at(at) < deep, "the pool did not thin as it spread")
	_check(pools.total() < whole, "nothing soaked into the ground")
	# A quake sloshes it: the same pool, shaken, creeps further in the same time.
	var calm := BloodPools.new()
	var shaken := BloodPools.new()
	add_child(calm)
	add_child(shaken)
	calm.pour(at, 6.0, 30.0)
	shaken.pour(at, 6.0, 30.0)
	shaken.agitate(10.0)
	for _step: int in 16:
		calm._simulate(1.0 / Balance.BLOOD_POOL_SIM_HZ)
		shaken._simulate(1.0 / Balance.BLOOD_POOL_SIM_HZ)
	_check(shaken.active_count() > calm.active_count(), "a quake did not slosh the blood out further")
	calm.queue_free()
	shaken.queue_free()
	_finished += 1


func _test_it_slows_and_stains_what_wades() -> void:
	_blood.wipe()
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	var at: Vector2 = Vector2(900.0, -1300.0)
	_pour_a_fight(at, 60)
	var dry: Vector2 = at + Vector2(700.0, 0.0)
	_check(Vfx.blood_slow(at) < 1.0, "a deep pool slowed nothing")
	_check(Vfx.blood_slow(at) >= 1.0 - Balance.BLOOD_POOL_SLOW_MAX - 0.0001, "a pool slowed past its bound")
	_check(is_equal_approx(Vfx.blood_slow(dry), 1.0), "dry ground slowed a mover")
	var body: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 1.0, 0.001, 0.001)
	await get_tree().process_frame
	body.global_position = dry
	var free_speed: float = body.current_speed()
	body.global_position = at
	_check(body.current_speed() < free_speed, "a body in a pool walked as fast as on dry ground")
	# Wading: the stain climbs to the pool's height and stays when it walks out.
	for _f: int in 3:
		await get_tree().process_frame
	var made := body.sprite.material as ShaderMaterial
	_check(made != null, "the body wears no material to stain")
	if made != null:
		var band: Vector2 = made.get_shader_parameter("wade_band")
		_check(band.x >= 0.0 and band.y > band.x, "a body that waded through a pool kept no stain (%s)" % band)
		body.global_position = dry
		for _f: int in 3:
			await get_tree().process_frame
		_check(made.get_shader_parameter("wade_band") == band, "the wade stain washed off on dry ground")
	var hero: Hero = _field.hero
	hero.global_position = at
	# **In game seconds, never in frames** (2026-10-01). The Warden's look is
	# written on a physics tick, and three headless frames can pass inside one
	# sixtieth of a second with no tick in them - the release sweep read an
	# unset band as a script error on a contended machine. Held on the pool
	# for the wait, so a shove off it cannot read as a stain that never came.
	var worn := hero.sprite.material as ShaderMaterial
	var hero_band: Variant = null
	var waited: float = 0.0
	while waited < 0.5 and hero_band == null:
		await get_tree().process_frame
		waited += get_process_delta_time()
		hero.global_position = at
		worn = hero.sprite.material as ShaderMaterial
		hero_band = worn.get_shader_parameter("wade_band") if worn != null else null
	if worn != null:
		_check(hero_band is Vector2 and (hero_band as Vector2).x >= 0.0,
			"the Warden waded through a pool and kept no stain (%s)" % str(hero_band))
	body.queue_free()
	_finished += 1


func _test_it_comes_home() -> void:
	_blood.wipe()
	UserSettings.set_blood_level(UserSettings.BLOOD_BRUTAL)
	var at: Vector2 = Vector2(-900.0, -1200.0)
	_pour_a_fight(at, 25)
	var banked: Dictionary = Vfx.blood_snapshot()
	_check(not (banked.get("marks", []) as Array).is_empty(), "a Brutal field banked no marks")
	_check(not (banked.get("pools", []) as Array).is_empty(), "a Brutal field banked no pools")
	# A front is only readable once a wave has been fought.
	RunState.wave_number = maxi(RunState.wave_number, 3)
	var front: Dictionary = Expedition.compose(_field)
	_check(front.has("blood") and not (front["blood"] as Dictionary).is_empty(),
		"a banked front carries no Brutal blood")
	var held: int = _blood.held()
	var depth: float = _blood.pools_if_any().depth_at(at)
	# Laid again on fresh ground.
	var again := BloodField.new()
	add_child(again)
	again.restore(banked)
	_check(again.held() == held, "a restored field holds %d marks, not %d" % [again.held(), held])
	var restored: BloodPools = again.pools_if_any()
	_check(restored != null and absf(restored.depth_at(at) - depth) < 0.01,
		"the restored pool is not as deep as the banked one")
	again.queue_free()
	# The front hands it to the next road.
	RunState.blood_restore.clear()
	Expedition.apply(front)
	_check(not RunState.blood_restore.is_empty(), "applying a banked front left no blood to lay")
	RunState.blood_restore.clear()
	UserSettings.set_blood_level(UserSettings.BLOOD_HIGH)
	_check(Vfx.blood_snapshot().is_empty(), "a High field banked blood with the front")
	_finished += 1


func _test_the_ground_keeps_its_scars() -> void:
	var scars: GroundScars = _field.scars()
	_check(scars != null, "the field keeps no scars")
	if scars == null:
		_finished += 1
		return
	scars.clear()
	var at: Vector2 = Vector2(1200.0, 900.0)
	scars.dent(at, 60.0, 0.5)
	_check(scars.height_at(at) < -0.3, "a dent left no bowl")
	_check(scars.height_at(at + Vector2(72.0, 0.0)) > 0.0, "a dent threw up no lip")
	_check(is_zero_approx(scars.height_at(at + Vector2(400.0, 0.0))), "a dent marked ground far from it")
	var from: Vector2 = Vector2(-1200.0, 600.0)
	scars.crack(from, from + Vector2(400.0, 0.0), 14.0, 0.5)
	var along: int = 0
	for index: int in 9:
		var point: Vector2 = from + Vector2(50.0 * float(index), 0.0)
		var lowest: float = 0.0
		for side: int in range(-5, 6):
			lowest = minf(lowest, scars.height_at(point + Vector2(0.0, float(side) * 8.0)))
		if lowest < -0.1:
			along += 1
	_check(along >= 7, "a crack did not run its line (%d of 9 points)" % along)
	var stamped: int = scars.stamps
	var quake_at: Vector2 = Vector2(-300.0, -900.0)
	EventBus.earthquake.emit(0.8, 0.5, quake_at, 1)
	_check(scars.stamps > stamped, "a quake left the ground unbroken")
	var broken: int = 0
	for ring: int in 24:
		var probe: Vector2 = quake_at + Vector2.from_angle(TAU * float(ring) / 24.0) * 200.0
		if scars.height_at(probe) != 0.0:
			broken += 1
	_check(broken > 0, "nothing round the quake's epicentre was broken")
	# **The act's end keeps them** (owner, 2026-10-01), the burns and the holes
	# with them - amended from "the act's end clears it".
	var burns: ScorchMarks = _field.scorch()
	var holes: Craters = _field.craters()
	var burnt: Vector2 = Vector2(-1500.0, 1500.0)
	burns.stamp(burnt, 60.0, 1.0)
	holes.open(Vector2(1500.0, -1500.0), 50.0)
	var depth_before: float = scars.height_at(at)
	var holes_before: int = holes.count()
	_field.refresh_terrain()
	_check(is_equal_approx(scars.height_at(at), depth_before), "the act's end healed the ground's scars")
	_check(burns.marked_at(burnt), "the act's end cleared the burns")
	_check(holes.count() == holes_before, "the act's end filled the craters (%d of %d left)"
		% [holes.count(), holes_before])
	# And all three come home with a banked front.
	var banked: Dictionary = _field.ground_snapshot()
	RunState.wave_number = maxi(RunState.wave_number, 3)
	var front: Dictionary = Expedition.compose(_field)
	_check(front.has("ground") and not String((front["ground"] as Dictionary).get("scars", "")).is_empty(),
		"a banked front carries no ground")
	RunState.ground_restore.clear()
	Expedition.apply(front)
	_check(not RunState.ground_restore.is_empty(), "applying a banked front left no ground to lay")
	RunState.ground_restore.clear()
	scars.clear()
	burns.clear()
	holes.clear()
	_field.restore_ground(banked)
	_check(absf(scars.height_at(at) - depth_before) < 0.02,
		"the restored ground's dent is %.2f where it was %.2f" % [scars.height_at(at), depth_before])
	_check(burns.marked_at(burnt), "the restored ground lost its burns")
	_check(holes.count() == holes_before, "the restored ground has %d craters, not %d"
		% [holes.count(), holes_before])
	_finished += 1


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[brutal-blood] " + why)
