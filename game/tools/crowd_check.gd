extends Node

## Fixed-step crowd regression, independent of renderer and wall-clock speed.
##
## Real Enemy scenes exercise the same contact radii/group membership as play,
## but their autonomous movement is disabled: this measures separation, not AI.
## The process-entry test also catches removal of EnemyField's separation hook;
## it does not claim to verify scheduling alongside a moving battlefield.
##
## CI remains disabled until its original Linux failure is actually reproduced.
## Stable fixtures and per-case diagnostics make that next run informative.

const FIXTURE_SEED: int = 20260902
const STEP_DELTA: float = 1.0 / 60.0
const SETTLE_STEPS: int = 90
const STACK_SIZE: int = 8
const POSITION_EPSILON: float = 0.01
const EXPECTED_CASES: int = 7

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	# Enemy._ready records first sightings in the Codex. A check must neither
	# discover enemies for a real account nor depend on that account's history.
	MetaState.hold_saves()
	RunState.set_seed(FIXTURE_SEED)
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	var breed: EnemyData = null
	var boss: EnemyData = null
	var largest: EnemyData = null
	for id: String in ids:
		var data := ContentDB.enemies[id] as EnemyData
		if data == null:
			continue
		if data.phase_thresholds.is_empty():
			if breed == null and data.category == EnemyData.Category.BREED:
				breed = data
			if largest == null or data.body_radius > largest.body_radius:
				largest = data
		elif boss == null:
			boss = data
	_check(breed != null, "a normal breed is needed")
	_check(boss != null, "a boss is needed")
	_check(largest != null, "a non-boss body is needed")
	if breed == null or boss == null or largest == null:
		await _finish()
		return

	print("[crowd] platform=%s engine=%s seed=%d dt=%.6f steps=%d "
		% [OS.get_name(), Engine.get_version_info().string, FIXTURE_SEED,
			STEP_DELTA, SETTLE_STEPS]
		+ "breed=%s radius=%.1f largest=%s radius=%.1f boss=%s residual=%.1f"
		% [breed.id, breed.body_radius, largest.id, largest.body_radius,
			boss.id, Balance.CROWD_RESIDUAL])
	_test_stack("offset stack", breed, Vector2(600.0, 600.0), 2.0)
	_test_stack("reversed insertion", breed, Vector2(600.0, 600.0), 2.0, true)
	_test_stack("exact coincidence", breed, Vector2(600.0, 600.0), 0.0)
	# Floor-based grid coordinates cross zero and negative cell edges too.
	_test_stack("negative cell boundary", breed,
		Vector2(-Balance.CROWD_CELL - 4.0, -Balance.CROWD_CELL), 2.0)
	# A larger stack has farther to spread under the same units/second cap.
	# Keep the original 90-step breed check, but scale this added stress case's
	# physical time with its radius rather than demanding impossible travel.
	var largest_steps: int = ceili(float(SETTLE_STEPS)
		* maxf(largest.body_radius / breed.body_radius, 1.0))
	_test_stack("largest body", largest, Vector2(600.0, 600.0), 2.0,
		false, false, largest_steps)
	_test_stack("process entry", breed, Vector2(600.0, 600.0), 2.0, false, true)
	_test_boss_exemption(breed, boss)
	await _finish()


func _test_stack(label: String, data: EnemyData, anchor: Vector2, spacing: float,
		reversed: bool = false, process_entry: bool = false,
		steps: int = SETTLE_STEPS) -> void:
	var field: EnemyField = _field()
	var crowd: Array[Enemy] = []
	for index: int in STACK_SIZE:
		var slot: int = STACK_SIZE - 1 - index if reversed else index
		crowd.append(_place(field, data, anchor + Vector2(float(slot) * spacing, 0.0)))
	var before: float = _worst_overlap(crowd)
	_check(before > Balance.CROWD_RESIDUAL,
		"%s must begin with real overlap, got %.3f" % [label, before])
	var max_step: float = _settle(field, crowd, process_entry, steps)
	var after: float = _worst_overlap(crowd)
	print("[crowd] %s: overlap %.3f -> %.3f over %d steps, max step %.3f / %.3f"
		% [label, before, after, steps, max_step, Balance.CROWD_MAX_SHOVE * STEP_DELTA])
	_check(after < before * 0.5,
		"%s must push apart, went from %.3f to %.3f" % [label, before, after])
	_check(after <= Balance.CROWD_RESIDUAL,
		"%s must end barely touching, %.3f units still shared" % [label, after])
	_check(max_step <= Balance.CROWD_MAX_SHOVE * STEP_DELTA + POSITION_EPSILON,
		"%s exceeded the per-step shove cap: %.3f" % [label, max_step])
	if _failures > 0:
		_dump_positions(label, crowd)
	# Immediate teardown removes group membership before the next case. Merely
	# queueing here would leave earlier cases participating in the next pass.
	field.free()
	_ran += 1


func _test_boss_exemption(breed: EnemyData, boss: EnemyData) -> void:
	var field: EnemyField = _field()
	var throne := Vector2(1200.0, 600.0)
	var monarch: Enemy = _place(field, boss, throne)
	var escort: Array[Enemy] = [_place(field, breed, throne)]
	_settle(field, escort)
	_check(escort[0].global_position.distance_to(throne) < POSITION_EPSILON,
		"a boss must not shove a lone overlapping escort")
	_check(monarch.global_position.distance_to(throne) < POSITION_EPSILON,
		"a boss must not be shoved by a lone escort")
	for index: int in 4:
		escort.append(_place(field, breed, throne + Vector2(float(index) * 3.0, 1.0)))
	_settle(field, escort)
	var moved: float = monarch.global_position.distance_to(throne)
	_check(moved < POSITION_EPSILON,
		"a boss must not be shoved by its whole escort, moved %.3f units" % moved)
	_check(monarch.ignores_crowd(), "the boss must declare itself exempt")
	_check(not escort[0].ignores_crowd(), "an escort must remain an ordinary body")
	print("[crowd] boss exemption: moved %.3f; overlap tolerated both ways" % moved)
	field.free()
	_ran += 1


func _field() -> EnemyField:
	RunState.set_seed(FIXTURE_SEED)
	var field := EnemyField.new()
	add_child(field)
	_check(field.is_processing(), "EnemyField must register a process callback")
	field.set_process(false)
	return field


func _place(field: EnemyField, data: EnemyData, at: Vector2) -> Enemy:
	var scene: PackedScene = load("res://scenes/battlefield/enemy.tscn")
	var enemy := scene.instantiate() as Enemy
	enemy.setup(data, 0, field, 1.0)
	# setup-before-ready is required by the real scene. Stop incidental scene
	# processing without replacing its real radius, boss flag or group identity.
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	field.add_child(enemy)
	# _ready shifts the root to the feet by an art-dependent amount. These
	# fixtures describe ground positions, so place them after that conversion.
	enemy.global_position = at
	return enemy


func _settle(field: EnemyField, bodies: Array[Enemy], process_entry: bool = false,
		steps: int = SETTLE_STEPS) -> float:
	var max_step: float = 0.0
	for step: int in steps:
		var positions: Array[Vector2] = []
		for body: Enemy in bodies:
			positions.append(body.global_position)
		if process_entry:
			field._process(STEP_DELTA)
		else:
			field.separate_crowd(STEP_DELTA)
		for index: int in bodies.size():
			var at: Vector2 = bodies[index].global_position
			if not at.is_finite():
				_check(false, "non-finite position at step %d body %d: %s" % [step, index, at])
				return INF
			max_step = maxf(max_step, at.distance_to(positions[index]))
	return max_step


func _worst_overlap(crowd: Array[Enemy]) -> float:
	var worst: float = 0.0
	for i: int in crowd.size():
		for j: int in range(i + 1, crowd.size()):
			var gap: float = crowd[i].contact_radius() + crowd[j].contact_radius()
			var apart: float = crowd[i].global_position.distance_to(crowd[j].global_position)
			worst = maxf(worst, gap - apart)
	return worst


func _dump_positions(label: String, crowd: Array[Enemy]) -> void:
	for index: int in crowd.size():
		print("[crowd] %s body %d (%s r=%.1f) at %s" % [label, index,
			crowd[index].data.id, crowd[index].contact_radius(), crowd[index].global_position])


func _finish() -> void:
	for child: Node in get_children():
		child.queue_free()
	Sfx.stop_immediately()
	for _frame: int in 40:
		await get_tree().process_frame
	_check(_ran == EXPECTED_CASES, "only %d of %d cases ran" % [_ran, EXPECTED_CASES])
	_check(get_tree().get_nodes_in_group(Enemy.GROUP).is_empty(),
		"test enemies must all leave the tree before exit")
	if _failures == 0:
		print("[crowd] PASS - %d cases; stacks separate, shove stays capped, bosses stay exempt" % _ran)
	else:
		push_error("[crowd] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[crowd] FAIL: %s" % why)
