extends Node

## Regression gate for the v4 raid contract: battlefield simulation freezes
## exactly, a raid down adds one Wound, and ejection restores the field hero at
## the prescribed half-health state.

var _run: Run
var _failures: PackedStringArray = []


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	_run = load("res://scenes/run/run.tscn").instantiate() as Run
	add_child(_run)
	await get_tree().process_frame

	_run._preparation_left = 0.0
	_run._on_ride_on_requested()
	_run._on_ride_on_requested()
	await get_tree().process_frame
	_run.battlefield.wave_director.stop()

	var data: EnemyData = ContentDB.enemy("bogkin")
	var enemy: Enemy = _run.battlefield.spawn_enemy(data, 0, 1.0)
	await get_tree().process_frame
	var enemy_at: Vector2 = enemy.global_position
	var distance_before: float = RunState.distance_travelled

	RunState.raid_charge = 1.0
	_run._on_raid_requested()
	await get_tree().process_frame
	_check(RunState.phase == RunState.Phase.RAID and _run.battlefield.is_suspended(),
		"entering a raid must freeze the battlefield and claim the Raid phase")
	for _frame: int in 12:
		await get_tree().physics_frame
	_check(enemy.global_position.is_equal_approx(enemy_at),
		"battlefield enemies must not move while the raid is active")
	_check(is_equal_approx(RunState.distance_travelled, distance_before),
		"journey distance must not advance while the battlefield is frozen")

	var wounds_before: int = RunState.hero_wounds
	_run.raid.hero.health.take_damage(_run.raid.hero.health.max_hp * 2.0, Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(RunState.hero_wounds == wounds_before + 1,
		"a raid down must add exactly one Wound")
	_check(not _run.battlefield.is_suspended() and RunState.phase == RunState.Phase.ROAD_BATTLE,
		"raid failure must eject back to the live road battle")
	_check(_run.battlefield.hero.is_alive() \
			and is_equal_approx(_run.battlefield.hero.health.ratio(), Balance.HERO_WOUND_REVIVE_HP),
		"raid ejection must return the battlefield hero alive at 50 percent HP")

	if _failures.is_empty():
		print("[raid-suspend] PASS — exact freeze and wounded ejection")
	else:
		for failure: String in _failures:
			push_error("[raid-suspend] " + failure)

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for _frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
