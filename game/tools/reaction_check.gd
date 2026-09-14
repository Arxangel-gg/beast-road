extends Node

## Wet and its reactions do what they say, on the real battlefield: a body
## hit by water is wet for a while, and while it is, lightning hits it harder
## and chains further off it, chill fills faster on it, and fire steams the
## wet away rather than burning; rain heavy enough wets everybody; a water
## tower wets what it hits; and a spell of an element touches the world the
## way a tower of it does.
##
##   godot --headless --path game res://tools/reaction_check.tscn
##
## Measured rather than read back, because each reaction is a multiplier at
## one call site and a multiplier applied at the wrong one is invisible: a
## wet body that "conducts" in the sky and not from a storm tower, a steam
## that removes the wet and lets the burn take anyway.

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null


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
	_check(_field != null and _field.sky() != null and _field.climate() != null,
		"the battlefield must stand a sky and a climate up")
	if _field != null and _field.sky() != null:
		_field.sky().events_enabled = false
		_field.sky().forced_intensity = 0.0
		RunState.rain_intensity = 0.0
		RunState.flood = 0.0
		await _test_wet_comes_and_goes()
		await _test_conductive()
		await _test_flash_freeze()
		await _test_steam()
		_test_rain_wets_everybody()
		await _test_the_water_tower_wets()
		_test_spells_touch_the_world()
		await _test_the_puppet_stays_dry()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[reactions] PASS - %d checks: wet, conductive, flash freeze, steam, the rain, "
			% _checks + "the water tower, the spells and the puppet")
	else:
		for failure: String in _failures:
			push_error("[reactions] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _body(at: Vector2, hp_scale: float = 4.0) -> Enemy:
	var enemy: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, hp_scale)
	enemy.global_position = at
	return enemy


func _test_wet_comes_and_goes() -> void:
	var body: Enemy = _body(Vector2(600.0, 500.0))
	await get_tree().process_frame
	_check(not body.is_wet(), "a body on a dry road is wet")
	body.apply_wet(Balance.WET_SECONDS)
	_check(body.is_wet(), "water hit the body and it is not wet")
	body.call("_tick_status", Balance.WET_SECONDS * 0.5)
	_check(body.is_wet(), "half way through, the wet is gone")
	body.call("_tick_status", Balance.WET_SECONDS * 0.6)
	_check(not body.is_wet(), "the wet never dried")
	body.queue_free()
	await get_tree().process_frame


## A strike hits a wet body harder, and the chain leaving a wet body reaches
## a third body a dry chain does not.
func _test_conductive() -> void:
	var sky: WeatherSky = _field.sky()
	# Deep pools, so the strike takes a share of each rather than all of both.
	var at: Vector2 = Vector2(-700.0, 600.0)
	var dry: Enemy = _body(at, 40.0)
	var wet: Enemy = _body(at + Vector2(0.0, 900.0), 40.0)
	await get_tree().process_frame
	wet.apply_wet(Balance.WET_SECONDS)
	var dry_hp: float = dry.health.current_hp
	var wet_hp: float = wet.health.current_hp
	sky.strike_at(at)
	sky.strike_at(at + Vector2(0.0, 900.0))
	var dry_lost: float = dry_hp - dry.health.current_hp
	var wet_lost: float = wet_hp - wet.health.current_hp
	_check(dry_lost > 0.0, "the dry body was not struck")
	_check(wet_lost > dry_lost * 1.3, "a wet body should take more from a strike (%.1f against %.1f dry)" % [wet_lost, dry_lost])
	_check(wet.shock_scale() > 1.0 and is_equal_approx(dry.shock_scale(), 1.0), "shock_scale does not read the wet")
	dry.queue_free()
	wet.queue_free()
	await get_tree().process_frame
	# The chain: a body just past a dry chain's reach is reached from a wet one.
	var here: Vector2 = Vector2(700.0, -600.0)
	var source: Enemy = _body(here)
	var beyond: Enemy = _body(here + Vector2(Balance.CHAIN_RANGE * 1.3, 0.0))
	await get_tree().process_frame
	var beyond_hp: float = beyond.health.current_hp
	sky.call("_chain", source.global_position, [source] as Array[Enemy], 50.0)
	_check(is_equal_approx(beyond.health.current_hp, beyond_hp), "a dry chain reached past its range")
	source.apply_wet(Balance.WET_SECONDS)
	sky.call("_chain", source.global_position, [source] as Array[Enemy], 50.0)
	_check(beyond.health.current_hp < beyond_hp, "a chain leaving a wet body did not reach further")
	source.queue_free()
	beyond.queue_free()
	await get_tree().process_frame


func _test_flash_freeze() -> void:
	var dry: Enemy = _body(Vector2(500.0, -500.0))
	var wet: Enemy = _body(Vector2(-500.0, -500.0))
	await get_tree().process_frame
	wet.apply_wet(Balance.WET_SECONDS)
	dry.apply_freeze(1.0)
	wet.apply_freeze(1.0)
	var dry_chill: float = float(dry.get("_chill"))
	var wet_chill: float = float(wet.get("_chill"))
	_check(dry_chill > 0.0, "a freeze proc left no chill on the dry body")
	_check(wet_chill > dry_chill * 1.3, "a wet body should chill faster (%.2f against %.2f dry)" % [wet_chill, dry_chill])
	dry.queue_free()
	wet.queue_free()
	await get_tree().process_frame


func _test_steam() -> void:
	var dry: Enemy = _body(Vector2(900.0, 300.0))
	var wet: Enemy = _body(Vector2(-900.0, 300.0))
	await get_tree().process_frame
	wet.apply_wet(Balance.WET_SECONDS)
	dry.apply_burn(10.0, 4.0)
	wet.apply_burn(10.0, 4.0)
	_check(float(dry.get("_burn_left")) > 0.0, "the dry body did not catch")
	_check(is_zero_approx(float(wet.get("_burn_left"))), "fire on a soaked body burned instead of steaming")
	_check(not wet.is_wet(), "the steam did not take the wet off")
	# And the other way: water on a burning body puts it out.
	_check(float(dry.get("_burn_left")) > 0.0, "the dry body is burning for the next check")
	dry.apply_wet(Balance.WET_SECONDS)
	_check(is_zero_approx(float(dry.get("_burn_left"))), "water on a burning body did not put it out")
	# Rain-wet is thinner: the burn takes, for half as long.
	dry.call("_tick_status", Balance.WET_SECONDS + 1.0)
	RunState.rain_intensity = 1.0
	dry.apply_burn(10.0, 4.0)
	var rain_burn: float = float(dry.get("_burn_left"))
	RunState.rain_intensity = 0.0
	_check(rain_burn > 0.0 and rain_burn < 4.0, "rain should halve a burn, not stop it (%.1f)" % rain_burn)
	dry.queue_free()
	wet.queue_free()
	await get_tree().process_frame


func _test_rain_wets_everybody() -> void:
	var body: Enemy = _body(Vector2(300.0, 900.0))
	_check(not body.is_wet(), "dry before the rain")
	RunState.rain_intensity = Balance.WET_RAIN_FROM + 0.1
	_check(body.is_wet(), "heavy rain did not wet the body")
	RunState.rain_intensity = 0.0
	RunState.flood = Balance.FLOOD_KNEE + 0.05
	_check(body.is_wet(), "a flood at the knee did not wet the body")
	RunState.flood = 0.0
	_check(not body.is_wet(), "dry again after")
	body.queue_free()


func _test_the_water_tower_wets() -> void:
	RunState.gain_every_currency(20000)
	var lance: TowerData = ContentDB.tower("rime_lance")
	_check(lance != null and lance.element == TowerData.Element.WATER, "rime_lance is the water tower this leans on")
	if lance == null:
		return
	var anchor: Vector2i = BattleGrid.world_to_tile(_field.grid.lane_pocket_centre(1))
	RunState.set_phase(RunState.Phase.PREPARATION)
	var problem: String = _field.try_build(anchor, lance)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(problem.is_empty(), "the harness must be able to build a water tower: %s" % problem)
	await get_tree().process_frame
	var tower: Tower = null
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var candidate := node as Tower
		if candidate != null and candidate.data == lance:
			tower = candidate
	if tower == null:
		return
	var body: Enemy = _body(tower.global_position + Vector2(100.0, 0.0))
	await get_tree().process_frame
	var tide: float = RunState.tide
	tower.call("_hit", body)
	_check(body.is_wet(), "a water tower's shot did not wet the body")
	_check(RunState.tide > tide, "a water tower's shot did not feed the tide")
	body.queue_free()
	RunState.clear_tower(anchor)
	await get_tree().process_frame


func _test_spells_touch_the_world() -> void:
	var caster: SpellCaster = _field.hero.spells if _field.hero != null else null
	_check(caster != null, "the hero has a caster")
	if caster == null:
		return
	var ground: Climate = _field.climate()
	ground.reset()
	var fire: SpellData = ContentDB.spells.get("ember_fall", null) as SpellData
	var water: SpellData = ContentDB.spells.get("frost_lance", null) as SpellData
	_check(fire != null and fire.element == TowerData.Element.FIRE, "ember_fall is a fire spell")
	_check(water != null and water.element == TowerData.Element.WATER, "frost_lance is a water spell")
	var at: Vector2 = Vector2(-400.0, -400.0)
	var ember: float = RunState.ember
	caster.call("_touch_the_world", fire, at)
	_check(ground.heat_at(at) > 0.0, "a fire spell did not warm the ground")
	_check(RunState.ember > ember, "a fire spell did not feed the ember")
	var far: Vector2 = Vector2(1600.0, 1600.0)
	var tide: float = RunState.tide
	caster.call("_touch_the_world", water, far)
	_check(ground.wetness_at(far) > Balance.CLIMATE_WET_REST, "a water spell did not wet the ground")
	_check(ground.heat_at(far) < 0.0, "a water spell did not cool the ground")
	_check(RunState.tide > tide, "a water spell did not feed the tide")
	# A spell of no element touches nothing.
	var step: SpellData = ContentDB.spells.get("rift_step", null) as SpellData
	var before_ember: float = RunState.ember
	if step != null:
		caster.call("_touch_the_world", step, at)
	_check(is_equal_approx(RunState.ember, before_ember), "a spell of no element fed the ember")
	ground.reset()
	RunState.ember = 0.0
	RunState.tide = 0.0


## A guest's puppet never decides its own wet; the host does.
func _test_the_puppet_stays_dry() -> void:
	var body: Enemy = _body(Vector2(200.0, -900.0))
	await get_tree().process_frame
	body.puppet = true
	body.apply_wet(Balance.WET_SECONDS)
	_check(not body.is_wet(), "a puppet wet itself")
	body.puppet = false
	body.queue_free()
	await get_tree().process_frame
