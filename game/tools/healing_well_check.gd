extends Node

## A well fills, pours for a hurt hero, and never becomes a regeneration aura.
##
## Owner brief, 2026-09-10: "players should also be able to build healing wells
## that fill up over time and can grant players who drink from them a bit of
## healing similar to the ones in diablo, placed as towers".
##
## **Placed as towers is the balance**, and that is the part a gate has to hold.
## A well occupies a slot on a road that could have held something that kills,
## and it pays no separate currency and runs on no separate clock. Everything
## below exists to stop that trade quietly evaporating: a well that poured on a
## short timer, or for a hero who had barely been scratched, would be a
## regeneration aura with a roof on it, and the wave curve is not tuned against
## one of those.
##
## Driven through the tower's own `_process` rather than by calling `_pour`. The
## refill deliberately runs on the same `_cooldown` every other tower uses, and a
## test that stepped past it would prove nothing about the thing a player stands
## next to.
##
## **One well, watched over time**, rather than three separate stages. Standing
## up a second run while the first was still tearing down double-connected a
## global signal and printed an error, which fails this gate as surely as a
## failed assertion would - and one well that is scratched at, then drunk from,
## then waited beside is a truer account of the object anyway.

var _failures: int = 0
var _checked: int = 0

var _run: Node = null
var _hero: Hero = null
var _tower: Node2D = null


func _ready() -> void:
	await get_tree().process_frame
	_test_the_data_is_a_well()
	if await _stand_up_a_well():
		await _test_it_will_not_pour_for_a_scratch()
		await _test_it_pours_for_somebody_hurt()
		await _test_it_does_not_pour_twice_without_refilling()
	_finish()


func _test_the_data_is_a_well() -> void:
	var data: TowerData = ContentDB.tower("healing_well")
	_checked += 1
	if not _check(data != null, "no healing_well tower is authored"):
		return
	_checked += 1
	_check(data.is_well(), "the healing well does not report as a well")
	_checked += 1
	_check(is_zero_approx(data.damage),
		"the healing well deals %.1f damage; a well that also shoots is a gun"
			% data.damage)
	# **And no gun may quietly become one.** `Tower._process` hands off to the
	# pour as soon as `is_well` answers true, so a stray `well_heal` on a
	# shooting tower would stop it firing entirely - which reads as that tower
	# being broken rather than as a slip in a `.tres`.
	var wells: int = 0
	for value: Variant in ContentDB.towers.values():
		var tower := value as TowerData
		if tower != null and tower.is_well():
			wells += 1
			_checked += 1
			_check(is_zero_approx(tower.damage),
				"%s heals and deals damage; it will never fire" % tower.id)
	_checked += 1
	_check(wells >= 1, "nothing in the roster is a well")


## A hero who has barely been scratched is not worth a draught.
##
## First, deliberately: the well is full at this point, so a pour here would be
## it spending its one draught on nobody in particular - which is exactly the
## failure that turns a well into a top-up aura.
func _test_it_will_not_pour_for_a_scratch() -> void:
	_hero.health.heal(_hero.health.max_hp)
	_hero.health.take_damage(_hero.health.max_hp
		* (Balance.WELL_MIN_MISSING_FRACTION * 0.4), Vector2.RIGHT)
	var scratched: float = _hero.health.current_hp
	await _wait_beside(120)
	_checked += 1
	_check(_hero.health.current_hp <= scratched + 0.01,
		("a well poured for a hero missing less than %.0f%% of their health; "
			+ "standing beside one would top a player up forever")
			% (Balance.WELL_MIN_MISSING_FRACTION * 100.0))
	_checked += 1
	_check(bool(_tower.call("draught_ready")),
		"the well spent its draught on a scratch and has nothing left")


## And a hero who is genuinely hurt gets one.
func _test_it_pours_for_somebody_hurt() -> void:
	_hero.health.take_damage(_hero.health.max_hp * 0.55, Vector2.RIGHT)
	var hurt: float = _hero.health.current_hp
	await _wait_beside(120, hurt)
	_checked += 1
	_check(_hero.health.current_hp > hurt,
		"a hurt hero stood at a full well and it poured nothing")
	_checked += 1
	_check(_hero.health.current_hp <= _hero.health.max_hp,
		"a well healed past maximum health")


## One draught, then a wait. This is the constraint that keeps it a well.
func _test_it_does_not_pour_twice_without_refilling() -> void:
	_checked += 1
	_check(not bool(_tower.call("draught_ready")),
		"the well still reports a draught ready immediately after pouring one")
	# Hurt again, so the only thing between the hero and more health is the
	# refill itself.
	_hero.health.take_damage(_hero.health.max_hp * 0.3, Vector2.RIGHT)
	var hurt_again: float = _hero.health.current_hp
	await _wait_beside(150)
	_checked += 1
	_check(_hero.health.current_hp <= hurt_again + 0.01,
		("the well poured again within two and a half seconds; its refill is "
			+ "%.0fs and one that ignores that is a regeneration aura")
			% float(_tower.call("well_refill_seconds")))


## Frames spent standing at the well, holding the hero there. Stops early if
## `until_above` is given and the hero's health passes it.
func _wait_beside(frames: int, until_above: float = INF) -> void:
	var beside: Vector2 = _tower.global_position + Vector2(20.0, 0.0)
	for _f: int in frames:
		await get_tree().process_frame
		if not is_instance_valid(_hero) or not is_instance_valid(_tower):
			return
		_hero.global_position = beside
		if _hero.health.current_hp > until_above:
			return


## One real battlefield with one well built into it.
##
## **A stub field is not enough, and the attempt is worth recording.** `Tower`
## declares `var _field: Battlefield`, statically typed, so assigning an
## `EnemyField` subclass silently leaves it null - the tower then raises on its
## first frame reading `lane_armour` off nothing and never gets as far as
## pouring. That failure looked exactly like a broken well.
##
## Built through `try_build`, which is the call the placement cursor makes.
## Hand-instantiating a tower and calling `setup` produced a node the
## battlefield promptly freed, because the field rebuilds its towers from
## `RunState` and anything it did not put there is a stray.
func _stand_up_a_well() -> bool:
	RunState.reset()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 14:
		await get_tree().process_frame
	var field: Battlefield = _run.get("battlefield")
	_hero = field.hero

	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(4000)
	var built: bool = false
	for tile: Vector2i in _candidate_tiles():
		if field.try_build(tile, ContentDB.tower("healing_well")).is_empty():
			built = true
			break
	_checked += 1
	if not _check(built, "no tile on the field would take a healing well"):
		return false
	for _f: int in 6:
		await get_tree().process_frame

	for one: Tower in field.all_towers():
		if one.data != null and one.data.is_well():
			_tower = one
	_checked += 1
	if not _check(_tower != null, "the well was bought and no tower appeared"):
		return false

	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	RunState.begin_command_battle()
	# **The first fill is skipped, and only the first.** A newly built well takes
	# its full eighteen seconds before the first draught, which is correct - you
	# build it and it fills - and it would put a minute of waiting into a gate
	# that is not asking about it. The *refill*, which is the constraint that
	# keeps a well from being a regeneration aura, is measured for real below and
	# is not touched here.
	_tower.set("_cooldown", 0.0)
	_hero.set_present(true)
	for _f: int in 6:
		await get_tree().process_frame
	return true


## Tiles worth trying, nearest the middle of the grid first. The field refuses a
## tile for a dozen good reasons - the road runs through it, something is already
## there - and this test has no opinion about which one it gets.
func _candidate_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = [Vector2i.ZERO]
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) == radius:
					out.append(Vector2i(x, y))
	return out


func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	push_error("[healing-well] %s" % why)
	return false


func _finish() -> void:
	if _failures == 0:
		print(("[healing-well] PASS - %d checks; it fills, it pours once, and it "
			+ "does not top anybody up") % _checked)
	else:
		push_error("[healing-well] FAIL - %d of %d" % [_failures, _checked])
	if is_instance_valid(_run):
		_run.queue_free()
	_run = null
	_hero = null
	_tower = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)
