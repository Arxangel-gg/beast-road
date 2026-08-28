extends Node

## Bodies must not stand inside each other, and bosses must be exempt.
##
## Separation is a thing that stops working without erroring: it is a small push
## applied after movement, and any change to how enemies step - a new slide, a
## knockback, a mirrored guest position - can quietly overwrite it. The overlap
## comes back and the crowd goes back to being one blob, which nobody notices as
## a bug because it is what the game looked like before.
##
## So this measures the overlap directly. Bodies are placed deliberately on top
## of one another, the pass is run, and the result is the amount of body still
## sharing space.

var _failures: int = 0


func _ready() -> void:
	var field := EnemyField.new()
	add_child(field)

	var breed: EnemyData = null
	var boss: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var data := value as EnemyData
		if data == null:
			continue
		if data.phase_thresholds.is_empty() and breed == null:
			breed = data
		elif not data.phase_thresholds.is_empty() and boss == null:
			boss = data
	_check(breed != null, "a normal breed is needed")
	_check(boss != null, "a boss is needed")
	if breed == null or boss == null:
		_finish()
		return

	# Eight bodies stacked within a whisker of one point. Nothing sane puts them
	# there; a wave funnelling into a lane mouth gets close enough.
	var crowd: Array[Enemy] = []
	for i: int in 8:
		crowd.append(_place(field, breed,
			Vector2(600.0, 600.0) + Vector2(float(i) * 2.0, 0.0)))
	var before: float = _worst_overlap(crowd)
	# **Called directly, and that is a real limit of this gate.** Driving it by
	# frames would also prove something runs it, but these bodies are parented to
	# a bare `EnemyField` rather than a battlefield, and an Enemy whose field is
	# a stub misbehaves the moment it gets a frame of its own. So this covers the
	# separation and the boss exemption; that `_process` calls it is not covered.
	for step: int in 90:
		field.separate_crowd(1.0 / 60.0)
	var after: float = _worst_overlap(crowd)
	print("[crowd] worst overlap %.1f -> %.1f units across %d bodies"
		% [before, after, crowd.size()])
	_check(after < before * 0.5,
		"a stack must push itself apart, went from %.1f to %.1f" % [before, after])
	_check(after <= Balance.CROWD_RESIDUAL,
		"and end up barely touching, %.1f units still shared" % after)

	# The boss stands where it was put.
	var monarch: Enemy = _place(field, boss, Vector2(1200.0, 600.0))
	var escort: Array[Enemy] = []
	for i: int in 5:
		escort.append(_place(field, breed,
			Vector2(1200.0, 600.0) + Vector2(float(i) * 3.0, 1.0)))
	var throne: Vector2 = monarch.global_position
	for step: int in 90:
		field.separate_crowd(1.0 / 60.0)
	_check(monarch.global_position.distance_to(throne) < 0.01,
		"a boss must not be shoved by its escort, moved %.1f units"
			% monarch.global_position.distance_to(throne))
	_check(monarch.ignores_crowd(), "and must declare itself exempt")
	_check(not escort[0].ignores_crowd(), "while a summon is an ordinary body")

	_finish()


func _place(field: EnemyField, data: EnemyData, at: Vector2) -> Enemy:
	var scene: PackedScene = load("res://scenes/battlefield/enemy.tscn")
	var enemy := scene.instantiate() as Enemy
	enemy.data = data
	field.add_child(enemy)
	enemy.global_position = at
	return enemy


## The deepest shared space between any two of them.
func _worst_overlap(crowd: Array[Enemy]) -> float:
	var worst: float = 0.0
	for i: int in crowd.size():
		for j: int in range(i + 1, crowd.size()):
			var gap: float = crowd[i].contact_radius() + crowd[j].contact_radius()
			var apart: float = crowd[i].global_position.distance_to(
				crowd[j].global_position)
			worst = maxf(worst, gap - apart)
	return worst


func _finish() -> void:
	if _failures == 0:
		print("[crowd] PASS - bodies push apart, bosses stand their ground")
	else:
		printerr("[crowd] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[crowd] FAIL: %s" % why)
