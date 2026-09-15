extends Node

## Where the players fell: one stone per hero down, and the remains that stay.
##
## The owner's brief (2026-09-14): on an actual collapse, one marker at the
## recorded death position; a stone falls from above, lands, stands while the
## player needs recovery and dissolves when they are up; the remains stay on
## that spot until the act ends; every death path - the solo clock, a co-op
## down and a partner's revive, a team wipe, a drowning - and a stable
## identity so nothing can plant a second stone for one death; a death in an
## arena marks the arena and not the road.
##
## Driven through the real doors: the hero's own `go_down`, `revive_in_place`
## and `respawn_from_wipe`, the solo respawn clock, the field's own suspend,
## and `act_started` on the bus. The markers watch the heroes rather than
## listen for a message, so this asks nothing of the wire.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _hero: Hero = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260914)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_hero = _field.hero if _field != null else null
	if _field == null or _hero == null or _field.death_markers() == null:
		_check(false, "the harness needs a battlefield, a hero and the field's markers")
		_finish()
		return
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)

	await _test_a_solo_fall_plants_one_stone_and_the_clock_dissolves_it()
	await _test_a_down_is_one_stone_however_often_it_is_said()
	await _test_a_partner_revive_dissolves_it_where_they_fell()
	await _test_a_revive_during_the_fall_dissolves_it_in_the_air()
	await _test_a_wipe_dissolves_it_too()
	await _test_two_deaths_on_one_spot_stand_apart()
	await _test_a_drowning_splashes_and_leaves_no_bones()
	await _test_the_field_frozen_holds_the_stone_in_the_air()
	await _test_the_act_ending_clears_the_bones_and_keeps_a_standing_stone()
	await _test_an_arena_marks_itself_and_never_the_road()
	_finish()


func _finish() -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _run != null:
		_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[death-markers] PASS - %d checks: the fall, the stand, the dissolve, the bones, every path, every scope" % _checks)
	else:
		push_error("[death-markers] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[death-markers] FAIL: %s" % why)


func _markers() -> DeathMarkers:
	return _field.death_markers()


func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _stand_at(at: Vector2) -> void:
	_hero.global_position = at
	await get_tree().process_frame


## Everybody up and every marker gone, between tests.
func _clean() -> void:
	if not _hero.is_alive():
		_hero.revive_in_place()
	# Past the dissolve and past the respawn's invulnerability, so the next
	# test's blow is not refused.
	await _wait(maxf(Balance.DEATH_STONE_DISSOLVE_SECONDS + 0.4, Balance.HERO_RESPAWN_INVULN + 0.2))
	_markers().clear_bones()
	await get_tree().process_frame


## The solo path: the hero falls, one stone falls with them and lands where
## they lie; the remains are laid; the clock stands them up at the spawn and
## the stone dissolves where it stood, the bones staying.
func _test_a_solo_fall_plants_one_stone_and_the_clock_dissolves_it() -> void:
	await _clean()
	var at: Vector2 = Vector2(320.0, -180.0)
	await _stand_at(at)
	# Through the real door: a lethal blow, the solo wound path, the clock.
	_hero.health.take_damage(_hero.health.max_hp * 10.0, at + Vector2(30.0, 0.0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not _hero.is_alive(), "a lethal blow puts the hero down")
	var stone: DeathStone = _markers().stone_for(_hero)
	_check(stone != null, "a hero down has a stone")
	_check(_markers().stone_count() == 1, "one stone for one fall (%d)" % _markers().stone_count())
	if stone == null:
		return
	_check(stone.global_position.distance_to(at) < 1.0,
		"the stone stands where the hero fell (%s vs %s)" % [str(stone.global_position), str(at)])
	_check(stone.is_falling() and stone.height() > 10.0,
		"the stone starts its fall from above (%.0f up)" % stone.height())
	_check(_markers().bones_count() == 1, "the remains are laid with the fall")
	await _wait(Balance.DEATH_STONE_FALL_SECONDS + 0.3)
	_check(stone.has_landed() and stone.height() < 0.5,
		"the stone has landed by the end of its fall (%.1f up)" % stone.height())
	_check(not stone.is_dissolving(), "a stone stands while the player is down")
	# The clock, wound short: solo, this is a Wound and a respawn at the spawn.
	_hero.set("_respawn_left", 0.05)
	await _wait(0.3)
	_check(_hero.is_alive(), "the clock stands the hero up")
	_check(stone != null and is_instance_valid(stone) and stone.is_dissolving(),
		"the stone dissolves when the player is up")
	await _wait(Balance.DEATH_STONE_DISSOLVE_SECONDS + 0.3)
	_check(_markers().stone_count() == 0, "the dissolved stone is gone")
	_check(_markers().bones_count() == 1, "the bones stay after the stone has gone")
	_check(_markers().stone_for(_hero) == null, "a standing hero has no stone")


## The identity: one stone per hero, whatever says they are down again.
func _test_a_down_is_one_stone_however_often_it_is_said() -> void:
	await _clean()
	var at: Vector2 = Vector2(-300.0, 200.0)
	await _stand_at(at)
	_hero.go_down(at)
	await get_tree().process_frame
	await get_tree().process_frame
	_hero.go_down(at)
	_hero.go_down(at + Vector2(40.0, 0.0))
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_markers().stone_count() == 1,
		"saying it three times plants one stone (%d)" % _markers().stone_count())
	_check(_markers().bones_count() == 1, "and one set of remains")


## A partner's revive: up where they fell, and the stone dissolves there.
func _test_a_partner_revive_dissolves_it_where_they_fell() -> void:
	await _clean()
	var at: Vector2 = Vector2(200.0, 260.0)
	await _stand_at(at)
	_hero.go_down(at)
	await _wait(Balance.DEATH_STONE_FALL_SECONDS + 0.3)
	var stone: DeathStone = _markers().stone_for(_hero)
	_check(stone != null and stone.has_landed(), "the stone stands before the revive")
	_hero.revive_in_place()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_hero.is_alive(), "the partner's revive stands the hero up")
	_check(_hero.global_position.distance_to(at) < 1.0, "up where they fell")
	_check(stone != null and is_instance_valid(stone) and stone.is_dissolving(),
		"the stone dissolves on the partner's revive")
	_check(stone != null and is_instance_valid(stone) and stone.global_position.distance_to(at) < 1.0,
		"and dissolves where it stood")


## Revived while the stone is still in the air: it dissolves where it is
## rather than landing on somebody already on their feet.
func _test_a_revive_during_the_fall_dissolves_it_in_the_air() -> void:
	await _clean()
	var at: Vector2 = Vector2(-220.0, -240.0)
	await _stand_at(at)
	_hero.go_down(at)
	await get_tree().process_frame
	await get_tree().process_frame
	var stone: DeathStone = _markers().stone_for(_hero)
	_check(stone != null and stone.is_falling(), "the stone is still falling")
	var up: float = stone.height() if stone != null else 0.0
	_hero.revive_in_place()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(stone != null and is_instance_valid(stone) and stone.is_dissolving(),
		"a stone revived in the air dissolves")
	_check(stone != null and is_instance_valid(stone) and not stone.has_landed(),
		"and never lands")
	_check(stone != null and is_instance_valid(stone) and absf(stone.height() - up) < Balance.DEATH_STONE_FALL_HEIGHT * 0.5,
		"and stays about where it was in the air (%.0f -> %.0f)" % [up, stone.height() if stone != null else 0.0])


## The wipe's return: everybody comes back at the spawn and the stones go.
func _test_a_wipe_dissolves_it_too() -> void:
	await _clean()
	var at: Vector2 = Vector2(260.0, -60.0)
	await _stand_at(at)
	_hero.go_down(at)
	await _wait(Balance.DEATH_STONE_FALL_SECONDS + 0.3)
	var stone: DeathStone = _markers().stone_for(_hero)
	_hero.respawn_from_wipe()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_hero.is_alive(), "the wipe's return stands the hero up")
	_check(stone != null and is_instance_valid(stone) and stone.is_dissolving(),
		"the stone dissolves on the wipe's return")
	_check(_markers().bones_count() == 1, "the remains stay where the hero fell")


## Two deaths on one spot: the second marker is nudged aside so both read.
func _test_two_deaths_on_one_spot_stand_apart() -> void:
	await _clean()
	var at: Vector2 = Vector2(-120.0, 300.0)
	await _stand_at(at)
	_hero.go_down(at)
	await _wait(Balance.DEATH_STONE_FALL_SECONDS + 0.3)
	_hero.revive_in_place()
	await _wait(Balance.DEATH_STONE_DISSOLVE_SECONDS + 0.3)
	await _stand_at(at)
	_hero.go_down(at)
	await get_tree().process_frame
	await get_tree().process_frame
	var bones: PackedVector2Array = _markers().bones_positions()
	_check(bones.size() == 2, "two deaths leave two sets of remains (%d)" % bones.size())
	if bones.size() == 2:
		_check(bones[0].distance_to(bones[1]) >= Balance.DEATH_MARKER_OVERLAP - 0.5,
			"and they stand apart (%.0f)" % bones[0].distance_to(bones[1]))
	var stone: DeathStone = _markers().stone_for(_hero)
	_check(stone != null and stone.global_position.distance_to(at) >= Balance.DEATH_MARKER_OVERLAP - 0.5,
		"the second stone stands beside the first remains, not on them")


## Drowned: the stone lands on the water with a splash, and the river keeps
## the body - no bones.
func _test_a_drowning_splashes_and_leaves_no_bones() -> void:
	await _clean()
	var at: Vector2 = Vector2(80.0, -300.0)
	await _stand_at(at)
	_hero.set("_swimming", true)
	_hero.go_down(at)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_hero.is_drowned(), "a hero down in the water is drowned")
	var stone: DeathStone = _markers().stone_for(_hero)
	_check(stone != null and stone.drowned, "the stone knows it fell into water")
	_check(_markers().bones_count() == 0, "a drowning leaves no remains (%d)" % _markers().bones_count())
	await _wait(Balance.DEATH_STONE_FALL_SECONDS + 0.3)
	_check(stone != null and is_instance_valid(stone) and stone.has_landed(), "it still lands")
	_hero.set("_swimming", false)
	_hero.revive_in_place()
	await get_tree().process_frame
	_check(not _hero.is_drowned(), "standing again is standing on land")


## Working rule 8: the field frozen for a raid holds the stone in the air.
func _test_the_field_frozen_holds_the_stone_in_the_air() -> void:
	await _clean()
	var at: Vector2 = Vector2(-60.0, 120.0)
	await _stand_at(at)
	_hero.go_down(at)
	await get_tree().process_frame
	await get_tree().process_frame
	var stone: DeathStone = _markers().stone_for(_hero)
	var before: float = stone.height() if stone != null else -1.0
	_field.suspend()
	for _frame: int in 30:
		await get_tree().process_frame
	var held: float = stone.height() if stone != null else -2.0
	_field.resume()
	_check(absf(held - before) < 0.5, "a frozen field holds the stone where it was (%.1f -> %.1f)" % [before, held])
	await _wait(Balance.DEATH_STONE_FALL_SECONDS + 0.3)
	_check(stone != null and is_instance_valid(stone) and stone.has_landed(), "and it lands once the field resumes")


## The act ends: the remains go; a hero still down keeps their stone.
func _test_the_act_ending_clears_the_bones_and_keeps_a_standing_stone() -> void:
	await _clean()
	var at: Vector2 = Vector2(140.0, 140.0)
	await _stand_at(at)
	_hero.go_down(at)
	await _wait(Balance.DEATH_STONE_FALL_SECONDS + 0.3)
	_check(_markers().bones_count() >= 1, "remains lie before the act ends")
	EventBus.act_started.emit(RunState.act + 1, RunState.terrain_id)
	await get_tree().process_frame
	_check(_markers().bones_count() == 0, "the act ending clears the remains (%d)" % _markers().bones_count())
	_check(_markers().stone_count() == 1, "and keeps the stone of a hero still down")
	_hero.revive_in_place()
	await _wait(Balance.DEATH_STONE_DISSOLVE_SECONDS + 0.3)


## A death in an arena marks the arena's floor and never the road above it.
func _test_an_arena_marks_itself_and_never_the_road() -> void:
	await _clean()
	var arena: RaidArena = _run.raid
	_check(arena != null and arena.death_markers() != null, "an arena carries its own markers")
	if arena == null or arena.death_markers() == null or arena.hero == null:
		return
	# The run holds an arena out of scope with its processing off; the raid
	# button turns it on. The harness turns it on the same way.
	var mode: Node.ProcessMode = arena.process_mode
	arena.process_mode = Node.PROCESS_MODE_INHERIT
	var present: bool = arena.hero.is_in_group(Hero.GROUP_ANY)
	arena.hero.set_present(true)
	var road_before: int = _markers().stone_count()
	var at: Vector2 = Vector2(50.0, 60.0)
	arena.hero.global_position = at
	arena.hero.go_down(at)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(arena.death_markers().stone_count() == 1, "the arena's markers stand a stone for the arena's hero")
	_check(_markers().stone_count() == road_before, "the road's markers do not (%d)" % _markers().stone_count())
	arena.hero.revive_in_place()
	await _wait(Balance.DEATH_STONE_DISSOLVE_SECONDS + 0.3)
	_check(arena.death_markers().stone_count() == 0, "and it dissolves when the arena's hero is up")
	arena.hero.set_present(present)
	arena.process_mode = mode
