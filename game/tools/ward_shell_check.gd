extends Node

## Holds the ward's shell round the Warden (owner, 2026-10-01: *"a shield
## visualizer that is juicy and aesthetically appealing and affected by amount of
## shield visually"*).
##
##   godot --headless --path game res://tools/ward_shell_check.tscn
##
## Headless never compiles a shader, so how the shell *looks* is
## `ward_shell_shot`'s; what this holds is everything a number can say about it,
## driven through the one door every ward comes through (`Health.add_shield`)
## and the one every blow does (`Health.take_damage`):
##
## - every Warden wears one, placed over the body and under the bar;
## - no ward, no shell; a ward raises one;
## - **more ward is a stronger and a larger shell** - the whole point;
## - a blow it pays for flashes it, and emptying the ward takes it down;
## - it reads nothing into the fight: the pool and the ward are exactly what the
##   doors made them with the shell there.

var _checks: int = 0
var _failures: int = 0
var _hero: Hero = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261001)
	var stage := Node2D.new()
	add_child(stage)
	_hero = (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	_hero.position = Vector2(400.0, 400.0)
	stage.add_child(_hero)
	await _frames(3)
	var shell: WardShell = _hero.ward_shell
	_check(shell != null and shell.get_parent() == _hero, "the Warden wears no ward shell")
	if shell != null:
		_check(shell.get_index() == _hero.sprite.get_index() + 1,
			"the shell is not laid just over the body (index %d, sprite %d)"
				% [shell.get_index(), _hero.sprite.get_index()])
		_check(shell.get_index() < _hero.health_bar.get_index(),
			"the shell is laid over the bar above the Warden's head")
		await _test_amounts(shell)
		await _test_blows(shell)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	stage.queue_free()
	await _frames(10)
	MetaState.resume_saves()
	if _failures == 0:
		print("[ward-shell] PASS - %d checks: every Warden wears a shell, more ward is a "
			% _checks + "stronger and larger one, a blow flashes it, an empty ward takes it "
			+ "down, and it moves no number")
	else:
		push_error("[ward-shell] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_amounts(shell: WardShell) -> void:
	var ceiling: float = _hero.health.max_hp * Balance.HEALTH_SHIELD_CEILING
	await _seconds(0.4)
	_check(shell.presence() < 0.01 and not shell.visible,
		"a Warden with no ward stands in a shell (presence %.2f)" % shell.presence())
	var hp_before: float = _hero.health.current_hp
	_grant_to(ceiling * 0.15)
	await _seconds(1.2)
	var low_strength: float = shell.shown()
	var low_radius: Vector2 = shell.radius()
	_check(shell.visible and shell.presence() > 0.95,
		"a ward raised no shell (presence %.2f)" % shell.presence())
	_check(absf(low_strength - 0.15) < 0.03,
		"a ward of 15%% of the ceiling is shown at %.2f" % low_strength)
	_grant_to(ceiling)
	await _seconds(1.2)
	_check(shell.shown() > low_strength + 0.6,
		"a full ward shows no stronger than a sliver (%.2f against %.2f)"
			% [shell.shown(), low_strength])
	_check(shell.radius().x > low_radius.x + 3.0 and shell.radius().y > low_radius.y + 3.0,
		"a full ward's shell is no larger than a sliver's (%s against %s)"
			% [shell.radius(), low_radius])
	_check(is_equal_approx(_hero.health.current_hp, hp_before),
		"the shell moved the Warden's health")
	_check(absf(_hero.health.shield() - ceiling) < 1.0,
		"the ward is %.0f where the door made it %.0f" % [_hero.health.shield(), ceiling])


func _test_blows(shell: WardShell) -> void:
	await _seconds(0.6)
	_check(shell.flash_level() < 0.01, "a shell nothing struck is flashing")
	var held: float = _hero.health.shield()
	_hero.health.take_damage(held * 0.2, _hero.global_position + Vector2(200.0, 0.0))
	await _frames(2)
	_check(shell.flash_level() > 0.3, "a blow the ward paid for did not flash the shell (%.2f)"
		% shell.flash_level())
	_check(absf(_hero.health.shield() - held * 0.8) < held * 0.05 + 1.0,
		"the ward took %.0f of a blow worth %.0f" % [held - _hero.health.shield(), held * 0.2])
	_hero.health.take_damage(_hero.health.shield() + 1.0, _hero.global_position + Vector2(0.0, -200.0))
	await _seconds(0.6)
	_check(_hero.health.shield() <= 0.0, "the ward outlived a blow larger than it")
	_check(shell.presence() < 0.05 and not shell.visible,
		"an empty ward still stands in a shell (presence %.2f)" % shell.presence())


func _grant_to(amount: float) -> void:
	var missing: float = amount - _hero.health.shield()
	if missing > 0.0:
		_hero.health.add_shield(missing / maxf(_hero.health.shield_scale, 0.01))


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[ward-shell] " + why)


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _seconds(span: float) -> void:
	var until: int = Time.get_ticks_msec() + int(span * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
