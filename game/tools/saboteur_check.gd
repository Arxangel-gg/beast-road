extends Node

## **The saboteur mark** (triage of 2026-10-07: "a mark that goes for a well or
## a trap rather than the wall").
##
##   godot --headless --path game res://tools/saboteur_check.tscn
##
## Holds that a saboteur on a lane with a gun and a well goes for the well, that
## an unmarked body does not, that a trap it stands in loses one charge with no
## bite and only once for it, that an ordinary body still springs the trap, and
## that the mark is in the road's pool with its medallion on disk.

const TAG: String = "[saboteur]"

var _run: Run = null
var _field: Battlefield = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261009)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	RunState.gain_every_currency(999999)
	_field.hero.global_position = _field.town_position()
	_test_the_mark()
	_test_it_goes_for_the_helpers()
	_test_it_takes_a_trap_apart()
	for stage: String in ["mark", "helpers", "trap"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: a saboteur goes for the well over the gun, takes a trap apart once without a bite, and an ordinary body still springs it" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
	return ok


func _mark() -> EnemyAffixData:
	return ContentDB.affixes.get("saboteur", null) as EnemyAffixData


func _breed() -> EnemyData:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.category == EnemyData.Category.BREED and not breed.targets_towers:
			return breed
	return null


func _body(marked: bool, at: Vector2) -> Enemy:
	var worn: Array[EnemyAffixData] = []
	if marked and _mark() != null:
		worn.append(_mark())
	var body: Enemy = _field.spawn_enemy(_breed(), 0, 60.0, -1.0, 0.001,
		false, Enemy.Rank.COMMON, worn)
	if body != null:
		body.global_position = at
	return body


func _test_the_mark() -> void:
	var mark: EnemyAffixData = _mark()
	if _check(mark != null, "no saboteur mark is authored"):
		_check(mark.sabotage, "the saboteur mark does not sabotage")
		_check(ResourceLoader.exists(mark.get_sprite_path()), "the saboteur has no medallion on disk")
		_check(mark.from_act <= Balance.ACT_COUNT, "the saboteur is in no act's pool")
	_reached.append("mark")


func _test_it_goes_for_the_helpers() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var well_data: TowerData = null
	for value: Variant in ContentDB.towers.values():
		var data := value as TowerData
		if data != null and data.is_well():
			well_data = data
			break
	var gun_anchor: Vector2i = _field.free_anchor_near(0)
	var gun_problem: String = _field.try_build(gun_anchor, ContentDB.base_towers()[0])
	var well_anchor: Vector2i = _field.free_anchor_near(0, 6)
	var well_problem: String = _field.try_build(well_anchor, well_data) if well_data != null else "no well"
	var gun: Tower = _field.tower_at_anchor(gun_anchor)
	var well: Tower = _field.tower_at_anchor(well_anchor)
	if not _check(gun != null and well != null, "the harness could not stand a gun and a well (%s / %s)" % [gun_problem, well_problem]):
		_reached.append("helpers")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	# Stood nearer the gun than the well, so "the nearest structure" and "the
	# helper" are different answers.
	var at: Vector2 = gun.global_position + (gun.global_position - well.global_position).normalized() * 60.0
	var saboteur: Enemy = _body(true, at)
	var plain: Enemy = _body(false, at)
	if _check(saboteur != null and plain != null, "the harness could not stand the bodies"):
		_check(saboteur.sabotages(), "a body wearing the mark does not sabotage")
		_check(not plain.sabotages(), "a body with no mark sabotages")
		var chose: Node2D = saboteur._choose_target()
		_check(chose == well, "the saboteur went for %s rather than the well" % [chose.name if chose != null else "nothing"])
		_check(plain._choose_target() != well, "an unmarked body went for the well")
		plain.order_siege()
		_check(plain._choose_target() == gun, "a body under siege orders went past the nearer gun")
		saboteur.queue_free()
		plain.queue_free()
	_field.try_sell(gun_anchor)
	_field.try_sell(well_anchor)
	_reached.append("helpers")


func _test_it_takes_a_trap_apart() -> void:
	var trap_data: TrapData = ContentDB.trap("spike_pit")
	RunState.set_phase(RunState.Phase.PREPARATION)
	var tile: Vector2i = Vector2i(-1, -1)
	if trap_data != null:
		for point: Vector2 in _field.lane_route(0):
			var candidate: Vector2i = BattleGrid.world_to_tile(point)
			if _field.try_place_trap(candidate, trap_data).is_empty():
				tile = candidate
				break
	var trap: Trap = _field.get("_traps").get(tile, null) as Trap if tile != Vector2i(-1, -1) else null
	if not _check(trap != null, "the harness could not lay a trap"):
		_reached.append("trap")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	trap.set("_arming", 0.0)
	var start: int = trap.triggers_left()
	var saboteur: Enemy = _body(true, trap.global_position)
	var pool: float = saboteur.health.current_hp
	for _tick: int in 4:
		trap.set("_sense_left", 0.0)
		trap._physics_process_measured(0.01)
	_check(trap.triggers_left() == start - 1,
		"a saboteur standing in a trap took %d charges, it takes one" % (start - trap.triggers_left()))
	_check(is_equal_approx(saboteur.health.current_hp, pool), "the trap bit the saboteur that took it apart")
	var second: Enemy = _body(true, trap.global_position)
	trap.set("_sense_left", 0.0)
	trap._physics_process_measured(0.01)
	_check(trap.triggers_left() == maxi(start - 2, 0), "a second saboteur took no charge of its own")
	saboteur.queue_free()
	second.queue_free()
	# An ordinary body springs it, and a saboteur standing beside it in the same
	# trap is still not bitten - it knows where the trap is.
	trap.set_triggers_left(maxi(trap.triggers_left(), 2))
	var before: int = trap.triggers_left()
	var plain: Enemy = _body(false, trap.global_position)
	var beside: Enemy = _body(true, trap.global_position + Vector2(6.0, 0.0))
	var plain_pool: float = plain.health.current_hp
	var beside_pool: float = beside.health.current_hp
	trap.set("_sense_left", 0.0)
	trap._physics_process_measured(0.01)
	_check(trap.triggers_left() == before - 1, "an ordinary body did not spring the trap")
	if trap_data.damage > 0.0:
		_check(plain.health.current_hp < plain_pool, "the trap an ordinary body sprang bit nothing")
		_check(is_equal_approx(beside.health.current_hp, beside_pool),
			"a trap an ordinary body sprang bit the saboteur beside it")
	plain.queue_free()
	beside.queue_free()
	_reached.append("trap")
