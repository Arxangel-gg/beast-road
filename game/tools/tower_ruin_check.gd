extends Node

## **A hurt tower shows it, and a fallen one falls** (triage of 2026-10-07;
## `Tower._tick_ruin`, `Tower._fall`).
##
## On a real field: a tower untouched neither smokes nor leans; one that has
## lost most of its pool smokes, crackles and leans away from the side the blow
## came from, by its share; mended, it straightens and the smoke stops; struck
## from the other side it leans the other way; destroyed, it topples away from
## the blow and is gone - and breaking it moves no roll on the earth's stream.

const TAG: String = "[tower-ruin]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261007)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	if _field.town != null and _field.town.health != null:
		_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	RunState.gain_every_currency(20000)
	await _test_the_ruin()
	for stage: String in ["standing", "hurt", "mended", "other_side", "fallen"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: whole and still, hurt and smoking and leaning away from the blow, mended straight, leaning the other way, and fallen away from the blow on its own dice" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _build(lane: int) -> Tower:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var data: TowerData = null
	var ids: Array = ContentDB.towers.keys()
	ids.sort()
	for id: Variant in ids:
		var kind := ContentDB.towers[id] as TowerData
		if kind != null and not kind.is_well() and not kind.is_support() and not kind.is_combination:
			data = kind
			break
	if data == null:
		return null
	var anchor: Vector2i = _field.free_anchor_near(lane, 8)
	var problem: String = _field.try_build(anchor, data)
	_check(problem.is_empty(), "%s would not build (%s)" % [data.id, problem])
	await get_tree().process_frame
	return _field.tower_at_anchor(anchor)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _lean(tower: Tower) -> float:
	return float(tower.get("_hurt_lean"))


func _test_the_ruin() -> void:
	var tower: Tower = await _build(0)
	var whole: Tower = await _build(2)
	_check(tower != null and whole != null, "the harness could not stand two towers")
	if tower == null or whole == null:
		return
	await _wait(1.6)
	_check(whole.smoke_puffs == 0 and absf(_lean(whole)) < 0.01,
		"a whole tower smoked (%d) or leaned (%.2f)" % [whole.smoke_puffs, _lean(whole)])
	_reached.append("standing")
	# Most of its pool gone, struck from the left.
	var health: Health = tower.get("_health") as Health
	health.current_hp = health.max_hp * 0.25
	health.take_damage(1.0, tower.origin() + Vector2(-220.0, 0.0))
	await _wait(1.6)
	var lost: float = 1.0 - health.ratio()
	_check(tower.smoke_puffs > 0, "a tower three quarters gone did not smoke")
	_check(tower.crackles > 0, "a tower three quarters gone did not crackle")
	_check(_lean(tower) > Balance.TOWER_HURT_LEAN_DEGREES * lost * 0.8,
		"struck from the left it leans %.2f, not away from the blow by its share (%.2f)"
		% [_lean(tower), Balance.TOWER_HURT_LEAN_DEGREES * lost])
	_reached.append("hurt")
	# Mended whole: straight again, and the smoke stops.
	tower.repair(1.0, true)
	await _wait(2.0)
	var puffs: int = tower.smoke_puffs
	await _wait(1.2)
	_check(absf(_lean(tower)) < 0.05, "a mended tower still leans %.2f" % _lean(tower))
	_check(tower.smoke_puffs == puffs, "a mended tower still smokes")
	_reached.append("mended")
	# From the right, it leans the other way.
	health.current_hp = health.max_hp * 0.4
	health.take_damage(1.0, tower.origin() + Vector2(220.0, 0.0))
	await _wait(1.6)
	_check(_lean(tower) < -0.5, "struck from the right it leans %.2f" % _lean(tower))
	_reached.append("other_side")
	# Fallen: it topples away from the blow, on its own dice, and is gone.
	var parent: Node = tower.get_parent()
	var earth: RandomNumberGenerator = RunState.rng("wrath")
	var earth_state: int = earth.state
	var id: String = tower.data.id
	health.take_damage(health.max_hp * 10.0, tower.origin() + Vector2(220.0, 0.0))
	await get_tree().process_frame
	_check(RunState.rng("wrath").state == earth_state, "breaking a tower moved the earth's stream")
	var fallen: Node2D = parent.get_node_or_null("Fallen_%s" % id) as Node2D
	_check(fallen != null, "a destroyed tower left nothing falling")
	if fallen != null:
		await _wait(Balance.TOWER_FALL_SECONDS * 0.8)
		if is_instance_valid(fallen):
			_check(fallen.rotation < -0.3, "struck from the right it fell %.2f, not away to the left" % fallen.rotation)
		await _wait(Balance.TOWER_FALL_SECONDS + 1.0)
		_check(not is_instance_valid(fallen), "the fallen tower was never taken away")
	_reached.append("fallen")
	whole.queue_free()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
