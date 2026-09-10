extends Node

## What the run is like *after* a raid, which nothing had ever looked at.
##
## Reported from play on 2026-09-10: "when players return from raids their
## weapon swings do not seem to show their visuals", and in the same breath that
## the new VFX were not visible at all. Both are one fault. Transient effects are
## parented into the scope that owns them, the raid claims that ownership when it
## opens, and **nothing ever claimed it back** - so after one raid `Vfx.world`
## pointed at `raid.effect_root` for the rest of the run, and the raid is left
## `visible = false` and `PROCESS_MODE_DISABLED` when it closes.
##
## Every effect after that first raid was therefore parented into an invisible,
## disabled node. Not a broken effect - an effect drawn somewhere nobody can see.
##
## It very likely explains a third report too. An arrow taking seven per cent off
## an elite, with no damage number, no hit spark and no impact flash, reads
## exactly like an arrow that did nothing - and the ranged system was measured
## working in isolation while this was live.
##
## The check drives the real signals rather than calling the handlers: the raid
## is entered the way the run enters it and left the way it leaves it, because
## the fault was in the *seam* and a test that called `resume()` directly would
## have passed on the broken build.

var _failures: int = 0
var _checked: int = 0
var _run: Node = null


func _ready() -> void:
	await get_tree().process_frame
	RunState.reset()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _i: int in 16:
		await get_tree().process_frame

	var field: Battlefield = _run.get("battlefield")
	var raid: RaidArena = _run.get("raid")
	_checked += 1
	_check(field != null and raid != null, "the run has no battlefield or no raid")
	if field == null or raid == null:
		_finish()
		return

	_checked += 1
	_check(_effects_live(), "effects were already homeless before any raid")
	var before: Node2D = Vfx.world

	# Entered the way the player enters it. `switch_scope(RAID)` is not that
	# route and does not open a camp - the horn does, through
	# `_on_raid_requested`, which is what suspends the battlefield and hands the
	# raid its process mode. A test that used the scope switch would have been
	# measuring a raid that never actually started.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	RunState.begin_command_battle()
	# The horn opens on a full charge; the run holds the value, so this is the
	# same state a player reaches by fighting rather than a back door into the
	# raid itself.
	RunState.raid_charge = 1.0
	_run.call("_on_raid_requested")
	for _i: int in 20:
		await get_tree().process_frame
	_checked += 1
	_check(Vfx.world != before, "opening a raid did not move the effect world")
	_checked += 1
	_check(_effects_live(), "effects are homeless inside the raid")

	await _check_raid_enemies_come_for_the_hero(raid)

	# Left the way the run leaves it: the raid announces its own ending and the
	# run does the rest.
	EventBus.raid_ended.emit({"resources": 0, "died": false})
	for _i: int in 30:
		await get_tree().process_frame

	_checked += 1
	_check(Vfx.world == before,
		"after the raid the effect world is %s, not the battlefield's"
			% (Vfx.world.name if Vfx.world != null else "null"))
	_checked += 1
	_check(_effects_live(),
		"after the raid effects are parented somewhere invisible or disabled")

	# And the thing a player actually notices: a swing leaves something behind.
	Vfx.clear()
	EventBus.hero_swing_resolved.emit(Vector2.ZERO, Vector2.RIGHT,
		Balance.HERO_ATTACK_RANGE[0], 0)
	for _i: int in 4:
		await get_tree().process_frame
	_checked += 1
	_check(_visible_effect_count() > 0,
		"a swing after a raid drew nothing anybody can see")
	_finish()


## Bodies in a camp walk toward the hero, not toward the middle of the map.
##
## Reported from play on 2026-09-10. `EnemyField.town_position` answers the
## origin - right for a scope built around a town at its centre, and exactly
## wrong for one whose own header says "no lanes, no town, the hero is the only
## objective". Every body that had not acquired the hero fell back to that origin
## and converged on the middle of the arena.
##
## Measured as *distance closed over time*, from a hero deliberately parked away
## from the centre. A position check alone would pass on a body that happened to
## spawn near the hero, and a direction check alone would pass on one that faced
## the right way and never moved.
func _check_raid_enemies_come_for_the_hero(raid: RaidArena) -> void:
	var hero: Hero = raid.hero
	_checked += 1
	if not _check(hero != null and hero.is_alive(), "the camp has no living hero"):
		return
	# Well away from the origin, so "walked to the centre" and "walked to the
	# hero" are different answers rather than the same one.
	hero.global_position = Vector2(900.0, -700.0)

	# **Bodies placed rather than waited for.**
	#
	# The first version counted whatever the camp had spawned by then, and that
	# is a race: a camp fills over time, and under sweep load it had produced two
	# bodies where a bare run produced four. The gate passed alone and failed in
	# the sweep, which is the least useful way for a gate to behave.
	#
	# Placed at known points that are neither the hero nor the origin, and
	# equidistant-ish from both, so "walked toward the hero" and "walked toward
	# the middle" are genuinely different directions for every one of them.
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED:
			breed = one
			break
	_checked += 1
	if not _check(breed != null, "no breed to place in the camp"):
		return
	var bodies: Array[Enemy] = []
	for spot: Vector2 in [Vector2(-700.0, -600.0), Vector2(-800.0, 200.0),
			Vector2(200.0, 800.0), Vector2(-200.0, -900.0)]:
		var foe := (load("res://scenes/battlefield/enemy.tscn") as PackedScene)			.instantiate() as Enemy
		foe.setup(breed, 0, raid, 1.0)
		raid.add_child(foe)
		foe.global_position = spot
		bodies.append(foe)
	for _i: int in 6:
		await get_tree().process_frame
		hero.global_position = Vector2(900.0, -700.0)

	var from_at: Array[Vector2] = []
	for foe: Enemy in bodies:
		from_at.append(foe.global_position)
	# Held in place throughout: a hero that wanders is a moving target, and the
	# question is whether bodies come to *it* rather than to the origin.
	for _i: int in 150:
		await get_tree().process_frame
		hero.global_position = Vector2(900.0, -700.0)

	var toward_hero: int = 0
	var toward_centre: int = 0
	var alive: int = 0
	for i: int in bodies.size():
		var foe: Enemy = bodies[i]
		if not is_instance_valid(foe) or foe.is_dying():
			continue
		var travel: Vector2 = foe.global_position - from_at[i]
		if travel.length() < 8.0:
			continue
		alive += 1
		var to_hero: Vector2 = (hero.global_position - from_at[i]).normalized()
		var to_centre: Vector2 = (-from_at[i]).normalized()
		if travel.normalized().dot(to_hero) > travel.normalized().dot(to_centre):
			toward_hero += 1
		else:
			toward_centre += 1
	_checked += 1
	if not _check(alive >= 3, "only %d of 4 placed bodies moved far enough to read"
			% alive):
		return
	_checked += 1
	_check(toward_hero > toward_centre,
		("%d of %d bodies walked toward the hero and %d toward the map centre; "
			+ "in a camp the hero is the objective")
			% [toward_hero, alive, toward_centre])


## Whether the effect world is somewhere a player could actually see something.
##
## Three separate ways it can fail and all three were true of the stale raid
## root: freed, hidden, or not processing. `is_visible_in_tree` covers a parent
## being hidden as well as the node itself, which is exactly the raid's case -
## `effect_root` was never touched, its owner was.
func _effects_live() -> bool:
	var world: Node2D = Vfx.world
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return false
	if not world.is_visible_in_tree():
		return false
	return world.can_process()


func _visible_effect_count() -> int:
	var world: Node2D = Vfx.world
	if world == null or not is_instance_valid(world) or not _effects_live():
		return 0
	var total: int = 0
	for child: Node in world.get_children():
		var drawn := child as CanvasItem
		if drawn != null and drawn.is_visible_in_tree():
			total += 1
	return total


## Returns what it was told, so a caller can stop rather than pile a second
## failure on top of the first it already reported.
func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	push_error("[raid-return] %s" % why)
	return false


func _finish() -> void:
	if _failures == 0:
		print("[raid-return] PASS - %d checks; the battlefield takes its effects back"
			% _checked)
	else:
		push_error("[raid-return] FAIL - %d of %d" % [_failures, _checked])
	if is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)
