extends Node

## Guards the bugs fixed on 2026-08-24, so they stay fixed.
##
##   godot --headless --path game res://tools/regression_check.tscn
##
## Each of these was reported by the owner playing the game, and each was a
## quiet failure rather than a crash: an enemy facing the wrong way, a readout
## describing a wave that had moved on, a pack that outlived the act that
## summoned it, a control eating taps on the front door. Nothing errored. That
## is exactly the class of bug a harness has to hold, because the next person to
## touch the code will not know to look.
##
## Deliberately not one test per fix where a fix has a shared cause. The touch
## rows below are two symptoms of one thing - a release that never arrived -
## and they are checked as that.

var _failures: int = 0
var _run: Run = null


func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset()
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame

	_test_lane_is_read_from_position()
	_test_starting_capital()
	_test_loot_reads_at_range()
	await _test_enemy_faces_its_travel()
	await _test_boss_summons_leave_with_the_boss()
	_test_touch_release_always_lands()
	_test_touch_controls_belong_to_the_run()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	# Torn down rather than left standing, so the leak report at exit means
	# something. `breather_check` does the same for the same reason.
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	for _f: int in 4:
		await get_tree().process_frame
	if _failures == 0:
		print("[regression] PASS - facing, threat lane, boss summons, loot scale, touch ownership")
	get_tree().quit(_failures)


## The threat readout must describe where enemies *are*, not where they entered.
##
## `enemy.lane` is written once at spawn. An enemy that breaks off the road to
## chase the hero can end up bearing on another side of the town entirely, and
## the rosette was still crediting the road it came in by.
func _test_lane_is_read_from_position() -> void:
	var span: float = Balance.LANE_SPAWN_RADIUS
	for lane: int in Balance.LANE_COUNT:
		var out: Vector2 = BattleGrid.lane_vector(lane) * span
		_check(BattleGrid.lane_at(out) == lane,
			"a point straight out along lane %d must read as lane %d" % [lane, lane])

	# The actual bug, expressed as a test: something that entered by one lane and
	# walked into another lane's quarter belongs to the quarter it is standing in.
	var north: Vector2 = BattleGrid.lane_vector(0) * span
	var east: Vector2 = BattleGrid.lane_vector(1) * span
	_check(BattleGrid.lane_at(north) != BattleGrid.lane_at(east),
		"opposite quarters must not collapse to one lane")
	_check(BattleGrid.lane_at(Vector2.ZERO) >= 0
		and BattleGrid.lane_at(Vector2.ZERO) < Balance.LANE_COUNT,
		"the town's own centre must still answer with a legal lane")


## The run starts with no build capital (GDD §448, amended 2026-08-24).
##
## Here as well as in `balance_test`, because this one is cheap and the failure
## is silent: a reinstated starting cache would not error, it would just quietly
## delete the design.
func _test_starting_capital() -> void:
	_check(RunState.currency(RunState.GOLD) == 0,
		"the run must start with no Gold, got %d" % RunState.currency(RunState.GOLD))
	var cheapest: int = -1
	for value: Variant in ContentDB.towers.values():
		var tower := value as TowerData
		if tower == null:
			continue
		var gold: int = int(tower.build_cost_table().get(RunState.GOLD, 0))
		if gold > 0 and (cheapest < 0 or gold < cheapest):
			cheapest = gold
	_check(cheapest > 0, "every tower must carry a Gold price for a zero-Gold start to mean anything")
	_check(not RunState.can_afford_cost({RunState.GOLD: cheapest}),
		"no tower may be affordable on the opening frame")


## A pickup has to be findable, and the rule has to agree with the art.
##
## Raised twice by the owner. The collect radius must not be smaller than the
## sprite, or the hero stands on a coin without taking it.
func _test_loot_reads_at_range() -> void:
	_check(Balance.LOOT_COLLECT_RANGE >= Balance.LOOT_ICON_SIZE * 0.5,
		"the collect radius must reach the edge of the drop it is collecting: %.0f vs %.0f" % [
			Balance.LOOT_COLLECT_RANGE, Balance.LOOT_ICON_SIZE * 0.5])
	_check(Balance.GEAR_DROP_ICON_SIZE > Balance.LOOT_ICON_SIZE,
		"gear must stay the more prominent drop")
	_check(Balance.LOOT_GLOW_SIZE > Balance.LOOT_ICON_SIZE,
		"the pool of light must be wider than the thing it is lighting")
	# The screen-pixel floor, which is the number the complaint was actually
	# about. Anything under about 20 px on a 1080p frame is not a reward.
	var on_screen: float = Balance.LOOT_ICON_SIZE * Balance.CAMERA_ZOOM_BATTLEFIELD_MIN
	_check(on_screen >= 20.0,
		"a drop must clear 20 screen px at the widest zoom, got %.1f" % on_screen)


## A walking enemy faces the way it walks; a fighting one faces its victim.
##
## The bug: facing asked about the target first, so an enemy that had acquired
## something walked the rest of a bend backwards.
func _test_enemy_faces_its_travel() -> void:
	var field: Battlefield = _run.battlefield
	var data: EnemyData = ContentDB.enemy("bogkin")
	if data == null or field == null:
		_check(false, "the harness needs a battlefield and a breed to test facing")
		return
	var enemy: Enemy = field.spawn_enemy(data, 0, 1.0)
	if enemy == null:
		_check(false, "spawn_enemy must return the enemy it spawned")
		return
	await get_tree().process_frame

	# Walking left. No target, so this is the plain motion case.
	enemy._state = Enemy.State.WALKING
	enemy._target = null
	enemy._motion = Vector2(-Balance.FACING_DEADZONE * 4.0, 0.0)
	enemy._update_sprite()
	_check(enemy.sprite.flip_h, "an enemy walking left must face left")

	enemy._motion = Vector2(Balance.FACING_DEADZONE * 4.0, 0.0)
	enemy._update_sprite()
	_check(not enemy.sprite.flip_h, "an enemy walking right must face right")

	# The regression itself: still walking right, but locked onto something to
	# the left. Motion has to win, or the enemy moonwalks down the road.
	var victim: Enemy = field.spawn_enemy(data, 0, 1.0)
	if victim != null:
		victim.global_position = enemy.global_position + Vector2(-900.0, 0.0)
		enemy._target = victim
		enemy._state = Enemy.State.WALKING
		enemy._motion = Vector2(Balance.FACING_DEADZONE * 4.0, 0.0)
		enemy._update_sprite()
		_check(not enemy.sprite.flip_h,
			"a walking enemy must face its travel, not a target behind it")

		# Stopped to swing: now the target is the right answer, because only
		# WALKING moves under its own power.
		enemy._state = Enemy.State.WINDUP
		enemy._motion = Vector2.ZERO
		enemy._update_sprite()
		_check(enemy.sprite.flip_h, "an attacking enemy must face what it is hitting")
		victim.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


## A boss's pack must not outlive the act the boss ended.
##
## And must not pay out when it goes: rushing the boss and ignoring its adds
## would otherwise be the most profitable way to fight one.
func _test_boss_summons_leave_with_the_boss() -> void:
	var field: Battlefield = _run.battlefield
	var data: EnemyData = ContentDB.enemy("bogkin")
	if data == null or field == null:
		_check(false, "the harness needs a battlefield and a breed to test summons")
		return

	var summoned: Array[Enemy] = []
	for _i: int in 3:
		var minion: Enemy = field.spawn_enemy(data, 1, 1.0)
		if minion != null:
			minion.add_to_group(Enemy.SUMMON_GROUP)
			summoned.append(minion)
	await get_tree().process_frame
	_check(summoned.size() == 3, "the harness must have three summons to dismiss")

	var kills_before: int = RunState.enemies_killed
	var gold_before: int = RunState.currency(RunState.GOLD)
	var xp_before: float = RunState.hero_xp

	for minion: Enemy in summoned:
		minion.dismiss()
	await get_tree().process_frame

	for minion: Enemy in summoned:
		_check(minion.is_dying(), "a dismissed summon must be leaving the field")
	_check(RunState.enemies_killed == kills_before,
		"dismissing a summon must not count as a kill")
	_check(RunState.currency(RunState.GOLD) == gold_before,
		"dismissing a summon must not pay resources")
	_check(is_equal_approx(RunState.hero_xp, xp_before),
		"dismissing a summon must not pay hero XP")
	_check(get_tree().get_nodes_in_group(Enemy.SUMMON_GROUP).is_empty(),
		"a dismissed summon must leave the summon group")


## A release must be observed even when something else consumed it.
##
## The bug: sticks and the dash button read `_unhandled_input`, which never sees
## an event a Control took first. A thumb lifted over a panel left the stick
## holding finger 0 forever, `owns_pointer()` stayed true, and every later tap on
## a tile was refused as "that is a thumb". The build panel opened once and never
## again.
func _test_touch_release_always_lands() -> void:
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	GameDirector.run_active = true
	TouchInput.refresh()

	var thumb: Vector2 = TouchInput.zone(false).get_center()
	var press := InputEventScreenTouch.new()
	press.position = thumb
	press.pressed = true
	press.index = 0
	TouchInput._unhandled_input(press)
	_check(TouchInput.owns_pointer(),
		"a thumb on the movement stick must own the emulated pointer")

	# The release goes to `_input`, the path that still runs when a panel above
	# has already handled the event. `_unhandled_input` is deliberately not used
	# here: that is the path the bug proved cannot be relied on.
	var release := InputEventScreenTouch.new()
	release.position = thumb
	release.pressed = false
	release.index = 0
	TouchInput._input(release)
	_check(not TouchInput.owns_pointer(),
		"lifting the thumb must release the pointer even when a panel ate the event")


## The on-screen controls belong to a run, not to the device.
##
## The dash button drew its ring over the main menu and, worse, went on
## consuming taps there.
func _test_touch_controls_belong_to_the_run() -> void:
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	GameDirector.run_active = false
	TouchInput.refresh()
	TouchInput._process(0.016)
	_check(TouchInput.is_showing(),
		"the setting must still report the controls as enabled for this device")
	_check(not TouchInput.visible,
		"the controls must not be drawn outside a run")

	var tap := InputEventScreenTouch.new()
	tap.position = TouchInput.dash_rect().get_center()
	tap.pressed = true
	tap.index = 0
	TouchInput._unhandled_input(tap)
	_check(not TouchInput.owns_pointer(),
		"a tap outside a run must not be swallowed by the dash button")

	GameDirector.run_active = true
	TouchInput._process(0.016)
	_check(TouchInput.visible, "the controls must come back when a run starts")


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[regression] %s" % why)
