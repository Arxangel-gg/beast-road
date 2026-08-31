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

	# War Horn is once per command battle, makes real progress, and cannot be
	# double-triggered while active.
	RunState.raid_charge = 0.0
	var horn_uses_before: int = RunState.war_horn_uses
	_check(_run.war_horn.blow(), "War Horn must activate in a live road battle")
	_check(RunState.horn_active and RunState.war_horn_uses == horn_uses_before + 1,
		"War Horn activation must update its run state and telemetry")
	_check(not _run.war_horn.blow(), "War Horn must not trigger twice in one battle")
	EventBus.enemy_died.emit("test", Vector2.ZERO)
	_check(RunState.raid_charge > Balance.RAID_CHARGE_PER_KILL,
		"War Horn kills must accelerate raid charge")

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
	_check(Balance.RAID_EXTRACTION_WINDOWS == [25.0, 50.0],
		"raid must expose the authored 25s and 50s extraction windows")
	_check(Balance.LEADER_RESOLUTIONS.size() == 3,
		"full raid rewards must expose oath, ransom and standard resolutions")

	# **The raid hero has to be findable, not merely present in the tree.**
	# `GROUP_ANY` means "a hero in play" and is granted by whichever scope owns
	# the body; the raid never claimed it, so its hero was active and absent -
	# every enemy asking for a hero in play found none and stood still, and the
	# camp's interactables had nobody to interact with. Reported from play, and
	# nothing here noticed because the whole gate was about freezing the
	# battlefield rather than about the raid being playable.
	var raid_hero: Hero = _run.raid.hero
	_check(raid_hero != null, "the raid arena must have a hero")
	if raid_hero != null:
		_check(raid_hero.is_in_group(Hero.GROUP_ANY),
			"the raid hero must be in play, or nothing in the camp can target it")
		_check(_run.raid.nearest_hero(Vector2.ZERO) == raid_hero,
			"an enemy asking the arena for the nearest hero must be given it")
		var in_play: int = 0
		for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
			if is_instance_valid(node):
				in_play += 1
		_check(in_play == 1,
			"exactly one hero may be in play during a raid, not %d - the frozen "
				% in_play + "battlefield's body must have handed presence back")
	_run.raid._elapsed = 25.0
	_run.raid._tick_windows(0.0)
	_check(_run.raid.window_is_open(), "first raid extraction window must open at 25s")
	_run.raid._window_open = false
	_run.raid._next_window = 1
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

	# Regression: a dead raid hero is a reusable scene instance. Refill the meter
	# and enter again in the same run; begin() must revive/synchronise that hero,
	# clear its old enemies, and claim the Raid phase a second time.
	RunState.raid_charge = 1.0
	EventBus.raid_charge_changed.emit(1.0)
	_run._on_raid_requested()
	await get_tree().process_frame
	_check(RunState.phase == RunState.Phase.RAID and _run.raid.hero.is_alive(),
		"a raid failure must not permanently lock or kill future raid attempts")
	_run.raid._finish({"partial": true, "died": false, "kills": 0})
	await get_tree().process_frame
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE and not _run.battlefield.is_suspended(),
		"a second raid must eject cleanly back to the road")

	if _failures.is_empty():
		print("[raid-suspend] PASS — exact freeze, wounded ejection and retry")
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
