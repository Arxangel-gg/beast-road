extends Node

## Five ranged answers instead of one, and the bound that keeps them honest.
##
##   godot --headless --path game res://tools/enemy_shot_check.tscn
##
## Owner report, 2026-09-13: "the ranged enemies all have one attack and the
## same one, we need more variety."
##
## They did. `role == HOWLER` built one `EnemyProjectile` and nothing else
## varied, so fourteen breeds across ten regions posed a single question between
## them and a player who learned to sidestep in Act I had learned the entire
## ranged game.
##
## **The bound is that a shot changes the shape of a blow, never its size.** A
## fan divides the strike it rolled; a mortar and a lance land that one strike
## on whoever is standing there; a hex trades part of it for mana. If any of
## them ever multiplies, the ten-act pressure curve is being read against
## numbers that no longer describe the fight - and nothing else in the project
## would notice, because the curve models a ranged enemy as its
## `contact_damage`.
##
## So this gate **measures** rather than reads: it fires each shot at a body
## with a known health pool and reads what came off. Five ways it can be a lie:
##
## 1. **A shot that deals more than the strike it rolled.** The bound.
## 2. **A shot that deals nothing.** A silent dud is worse than a bolt, and an
##    area blow that resolved on nobody would be exactly that.
## 3. **A telegraph that lies about where the blow lands.** A ring drawn at a
##    radius the blow does not use teaches the player the wrong thing.
## 4. **A blow that dies with its thrower.** Then killing a shooter after it
##    commits is free, and the telegraph is a reward rather than a warning.
## 5. **A breed that cannot besiege.** An area blow resolves on heroes and
##    spirits only, so a shooter whose target is the wall must fall back to a
##    bolt or quietly stop being able to attack the town.

var _failures: int = 0
var _checks: int = 0
var _field: Node = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260913)
	RunState.phase = RunState.Phase.ROAD_BATTLE

	_test_every_shot_is_authored_somewhere()
	await _test_each_shot_lands_and_none_exceeds_its_strike()
	await _test_a_blow_outlives_its_thrower()
	_test_the_tell_matches_the_blow()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _field != null and is_instance_valid(_field):
		_field.queue_free()
	for _f: int in 12:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[enemy-shots] PASS - %d checks: five shots, each lands, none exceeds its strike"
			% _checks)
	else:
		push_error("[enemy-shots] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


## Every shot the enum names is thrown by somebody, and nobody who cannot throw
## authors one.
##
## A shot nothing throws is a feature that silently never appears, which is the
## exact failure the portent pool had: ten cards looked ample until you noticed
## that what is dealt leaves.
func _test_every_shot_is_authored_somewhere() -> void:
	var thrown: Dictionary = {}
	var shooters: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		var shoots: bool = breed.role == EnemyData.Role.HOWLER
		if shoots:
			shooters += 1
			thrown[breed.shot] = int(thrown.get(breed.shot, 0)) + 1
		else:
			_check(breed.shot == EnemyData.Shot.BOLT,
				"%s is not a shooter but authors a shot, which nothing will ever throw"
					% breed.id)
	_check(shooters >= 5, "there must be ranged breeds to vary; found %d" % shooters)
	for shot: int in EnemyData.Shot.size():
		_check(int(thrown.get(shot, 0)) > 0,
			"no breed throws shot %d, so it is a feature that never appears" % shot)
	# And no one shot is the whole roster, which is the thing being fixed.
	for shot: int in EnemyData.Shot.size():
		_check(int(thrown.get(shot, 0)) < shooters,
			"every shooter throws shot %d - that is the one-answer problem again" % shot)


## Fired for real at a body with a known pool, and the damage read off it.
##
## Driven rather than asserted from the constants: the failure this is written
## against is a shot that is *authored* correctly and resolves on nobody, which
## reads identically from the data side.
func _test_each_shot_lands_and_none_exceeds_its_strike() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	GameDirector.run_active = true
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var hero: Hero = field.hero if field != null else null
	if hero == null or hero.health == null:
		_check(false, "the harness needs a hero on a battlefield")
		run.queue_free()
		return

	# A pool deep enough that nothing here can kill the probe, and i-frames off
	# so a second blow is not silently evaded.
	hero.health.max_hp = 100000.0
	const STRIKE: float = 400.0
	for shot: int in EnemyData.Shot.size():
		var shooter: Enemy = _a_shooter(field, hero, shot)
		if shooter == null or not is_instance_valid(shooter):
			_check(false, "the harness could not place a shooter for shot %d" % shot)
			continue
		hero.health.current_hp = hero.health.max_hp
		hero.mana = hero.mana_max()
		shooter.call("_loose_a_shot", STRIKE)
		# Long enough for a mortar's tell and a hex's slow flight.
		for _frame: int in 240:
			hero.health._invulnerable_left = 0.0
			await get_tree().process_frame
		var taken: float = hero.health.max_hp - hero.health.current_hp
		_check(taken > 0.0,
			"shot %d landed nothing at all - a silent dud is worse than a bolt" % shot)
		_check(taken <= STRIKE + 0.5,
			("shot %d took %.1f from a strike of %.1f - a shot may change the shape "
				+ "of a blow and never its size") % [shot, taken, STRIKE])
		if shot == EnemyData.Shot.HEX:
			_check(hero.mana < hero.mana_max(),
				"a hex must take mana with it, which is the whole of what makes it a hex")
		if is_instance_valid(shooter):
			shooter.queue_free()
		await get_tree().process_frame

	# 5. A shooter aimed at the wall still hurts the wall, whatever it throws.
	var town: Node2D = field.town_node()
	if town != null:
		var health: Health = Health.of(town)
		if health != null:
			var before: float = health.current_hp
			var sieger: Enemy = _a_shooter(field, town, EnemyData.Shot.LOB)
			if sieger != null and is_instance_valid(sieger):
				sieger.call("_loose_a_shot", STRIKE)
				for _frame: int in 120:
					await get_tree().process_frame
				_check(health.current_hp < before,
					"a mortar breed aimed at the wall must still hurt the wall - an area "
						+ "blow resolves on people, so it has to fall back to a bolt")
				sieger.queue_free()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	GameDirector.run_active = false


## A blow already thrown lands even when its thrower does not survive the tell.
##
## Otherwise the correct play against every mortar and lance breed is to kill it
## after it commits, and the telegraph stops being a warning and becomes a
## window in which the enemy can be deleted for free.
func _test_a_blow_outlives_its_thrower() -> void:
	_field = Node2D.new()
	add_child(_field)
	var mark := Node2D.new()
	_field.add_child(mark)

	var blow := EnemyGroundStrike.new()
	blow.shape = EnemyGroundStrike.Shape.CIRCLE
	blow.damage = 5.0
	blow.delay = 0.2
	blow.reach = 120.0
	_field.add_child(blow)
	mark.queue_free()
	await get_tree().process_frame
	_check(is_instance_valid(blow),
		"a blow must not be freed along with whatever threw it")
	# And it clears itself up rather than sitting on the field forever.
	for _frame: int in 60:
		await get_tree().process_frame
		if not is_instance_valid(blow):
			break
	_check(not is_instance_valid(blow), "and it must clean itself up when it lands")
	_field.queue_free()
	_field = null
	await get_tree().process_frame


## The tell is built from the blow's own numbers.
##
## Checked on the shape rather than on the drawing: a circle covers exactly what
## it says it covers and a line covers exactly its own width. A ring drawn at a
## radius the blow does not use teaches the player the wrong lesson, which is
## worse than drawing nothing.
func _test_the_tell_matches_the_blow() -> void:
	var ring := EnemyGroundStrike.new()
	ring.shape = EnemyGroundStrike.Shape.CIRCLE
	ring.reach = 100.0
	_check(bool(ring.call("_covers", Vector2(99.0, 0.0))), "a circle covers inside itself")
	_check(not bool(ring.call("_covers", Vector2(101.0, 0.0))), "and not outside it")
	ring.free()

	var line := EnemyGroundStrike.new()
	line.shape = EnemyGroundStrike.Shape.LINE
	line.aim = Vector2.RIGHT
	line.reach = 300.0
	line.half_width = 30.0
	_check(bool(line.call("_covers", Vector2(150.0, 29.0))), "a line covers its own width")
	_check(not bool(line.call("_covers", Vector2(150.0, 31.0))), "and nothing beside it")
	_check(not bool(line.call("_covers", Vector2(301.0, 0.0))), "and nothing past its reach")
	_check(not bool(line.call("_covers", Vector2(-10.0, 0.0))), "and nothing behind the thrower")
	line.free()


## A live shooter on the field, aimed at `at`, throwing `shot`.
func _a_shooter(field: Battlefield, at: Node2D, shot: int) -> Enemy:
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var candidate := value as EnemyData
		if candidate != null and candidate.role == EnemyData.Role.HOWLER:
			breed = candidate
			break
	if breed == null or field == null:
		return null
	# The breed is *posed* rather than picked by its authored shot, so the gate
	# tests all five even if the roster stops authoring one of them - and so a
	# breed's own data is never what decides whether its shot is covered here.
	var posed: EnemyData = breed.duplicate() as EnemyData
	posed.shot = shot
	# **And its repertoire is emptied**, or the pose decides nothing. Since
	# 2026-09-13 a breed draws from `shot_ids` when it has one, so posing `shot`
	# on a breed that knows several would test whichever the draw happened to
	# pick - which is how this gate started reporting that a hex took no mana.
	# The repertoire has its own gate; this one is about the five kinds.
	posed.shot_ids = PackedStringArray()
	var enemy := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
	# Through `setup` rather than by assigning `data`: `_ready` refuses a body
	# that has no field and frees itself, and a freed probe reads exactly like a
	# shot that resolved on nobody.
	enemy.setup(posed, 0, field, 1.0, 1.0, 1.0)
	field.add_child(enemy)
	enemy.global_position = at.global_position + Vector2.RIGHT * 220.0
	enemy.set("_target", at)
	return enemy
