extends Node

## Enemy morale (owner request, 2026-09-02).
##
## Enemies break when their champion falls and run for a moment before finding
## their nerve. It is the clearest thing on the field under "the Road is always
## telling you something": a line coming apart is information the player reads
## without a number being shown, and it makes killing the leader *first* the
## readable play rather than a tip in a menu.
##
## Six promises. The first is the design bound and the rest are how it fails
## quietly:
##
## 1. **Morale changes the shape of a fight and never its size.** A routed body
##    comes back, still counts, and still pays out. The three-act pressure curve
##    is tuned against how many bodies arrive; if breaking one removed it, every
##    wave in the game would quietly get easier and the curve would be measuring
##    something that no longer happens.
## 2. **Only ordinary bodies break.** An elite that ran would undo the whole
##    reason it was promoted.
## 3. **A living champion holds the line**, so killing it first is what pays.
## 4. **A retreat is back up the road, never toward the town.** "Away from what
##    frightened me" sends a body that broke on the town side straight at the
##    gate, which turns breaking its nerve into helping it arrive.
## 5. **A broken body stops fighting** while it runs, and resumes after.
## 6. **It animates.** A body sliding backwards in its standing pose reads as
##    being dragged rather than running.

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	RunState.reset()
	RunState.act = 2
	await _test_leader_death_breaks_the_line()
	await _test_promoted_bodies_hold()
	await _test_a_living_champion_rallies()
	await _test_retreat_is_away_from_the_town()
	await _test_a_routed_body_returns_and_still_counts()
	_finish()


## 1 and 5. The champion falls, the line breaks, and it comes back.
func _test_leader_death_breaks_the_line() -> void:
	var field := EnemyField.new()
	add_child(field)
	var breed: EnemyData = _breed()
	if breed == null:
		field.queue_free()
		return
	var footman: Enemy = _make(field, breed, Vector2(400.0, 0.0), Enemy.Rank.COMMON)
	await _settle()
	_check(not footman.is_routed(), "a body with its nerve is not running")

	footman.shake_morale(Balance.ENEMY_MORALE_LEADER_LOSS)
	await _settle()
	_check(footman.is_routed(),
		"an ordinary body must break when its leader falls")
	_check(not footman.is_dying(),
		"and must still be alive - breaking is not dying")
	_check(footman.is_in_group(Enemy.GROUP),
		"and must still be an enemy the wave is waiting on, or morale would "
			+ "quietly make every wave in the game shorter")

	# And it finds its nerve. Driven by draining the meter rather than waiting
	# out the clock, because a gate that sleeps is a gate nobody runs.
	footman.set("_rout_left", 0.001)
	await _settle()
	_check(not footman.is_routed(),
		"a broken body must come back rather than leave the field")

	field.queue_free()
	await _settle()
	_ran += 1


## 2. Promotion means holding.
func _test_promoted_bodies_hold() -> void:
	var field := EnemyField.new()
	add_child(field)
	var breed: EnemyData = _breed()
	if breed == null:
		field.queue_free()
		return
	for rank: Enemy.Rank in [Enemy.Rank.ELITE, Enemy.Rank.CHAMPION]:
		var promoted: Enemy = _make(field, breed, Vector2(400.0, 0.0), rank)
		await _settle()
		promoted.shake_morale(1.0)
		await _settle()
		_check(not promoted.is_routed(),
			"a promoted body must never run - rank %d did" % int(rank))
	field.queue_free()
	await _settle()
	_ran += 1


## 3. The rally, which is what makes killing the leader first the play.
func _test_a_living_champion_rallies() -> void:
	var field := EnemyField.new()
	add_child(field)
	var breed: EnemyData = _breed()
	if breed == null:
		field.queue_free()
		return
	var champion: Enemy = _make(field, breed, Vector2(400.0, 0.0),
		Enemy.Rank.CHAMPION)
	var footman: Enemy = _make(field, breed,
		Vector2(400.0 + Balance.ENEMY_RALLY_RADIUS * 0.4, 0.0), Enemy.Rank.COMMON)
	await _settle()
	footman.shake_morale(1.0)
	await _settle()
	_check(not footman.is_routed(),
		"a body standing beside a living champion must hold, or killing the "
			+ "leader first stops being the readable play")

	# Take the champion away and the same shock lands.
	champion.queue_free()
	await _settle()
	footman.shake_morale(1.0)
	await _settle()
	_check(footman.is_routed(),
		"and must break once nothing is holding it together")
	field.queue_free()
	await _settle()
	_ran += 1


## 4. Retreat is up the road, never at the wall.
func _test_retreat_is_away_from_the_town() -> void:
	var field := EnemyField.new()
	add_child(field)
	var breed: EnemyData = _breed()
	if breed == null:
		field.queue_free()
		return
	var town: Vector2 = field.town_position()
	# Deliberately placed *beyond* the town from the road's point of view, which
	# is the case a naive "run from what scared me" gets wrong.
	var footman: Enemy = _make(field, breed, town + Vector2(360.0, 0.0),
		Enemy.Rank.COMMON)
	await _settle()
	var before: float = footman.global_position.distance_to(town)
	footman.shake_morale(1.0)
	for _frame: int in 30:
		await get_tree().physics_frame
	var after: float = footman.global_position.distance_to(town)
	_check(footman.is_routed(), "the body must actually be running")
	_check(after >= before - 1.0,
		"a retreat must never close on the town: %.0f -> %.0f" % [before, after])
	field.queue_free()
	await _settle()
	_ran += 1


## 1 again, from the other side, and 6.
##
## The size of a fight is the thing morale must not touch, so it is asked twice:
## once that the body is still in the group, and once that a whole line breaking
## leaves exactly as many enemies on the field as it started with.
func _test_a_routed_body_returns_and_still_counts() -> void:
	var field := EnemyField.new()
	add_child(field)
	var breed: EnemyData = _breed()
	if breed == null:
		field.queue_free()
		return
	var line: Array[Enemy] = []
	for index: int in 6:
		line.append(_make(field, breed, Vector2(300.0 + index * 40.0, 0.0),
			Enemy.Rank.COMMON))
	await _settle()
	var before: int = get_tree().get_nodes_in_group(Enemy.GROUP).size()
	for foe: Enemy in line:
		foe.shake_morale(1.0)
	await _settle()
	var broke: int = 0
	for foe: Enemy in line:
		if foe.is_routed():
			broke += 1
	_check(broke == line.size(), "the whole line must break, %d of %d did"
		% [broke, line.size()])
	_check(get_tree().get_nodes_in_group(Enemy.GROUP).size() == before,
		"and the field must still hold the same number of enemies - a wave "
			+ "cannot get shorter because its nerve failed")

	# It animates while it runs, if the breed has frames to animate with.
	#
	# Sampled over enough frames for the cycle to actually turn over. The walk
	# phase is advanced by *ground covered*, not by elapsed time - deliberately,
	# so a chilled body takes slower steps - which means a short sample can watch
	# a running enemy for a quarter of a second and correctly see one pose. The
	# first version of this did exactly that and blamed the code.
	var frames: Array = line[0].get("_walk_frames") as Array
	if not frames.is_empty():
		var poses: Dictionary = {}
		var from: Vector2 = line[0].global_position
		for _frame: int in 90:
			await get_tree().physics_frame
			poses[line[0].sprite.texture] = true
		var travelled: float = from.distance_to(line[0].global_position)
		_check(travelled > 30.0,
			"a running body must cover ground, moved %.0f" % travelled)
		_check(poses.size() > 1,
			"a running body must animate rather than slide in its standing "
				+ "pose - covered %.0f across %d poses" % [travelled, poses.size()])

	field.queue_free()
	await _settle()
	_ran += 1


# --- harness -----------------------------------------------------------------

func _breed() -> EnemyData:
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED:
			return one
	_check(false, "a breed is needed to break")
	return null


func _make(field: EnemyField, breed: EnemyData, at: Vector2,
		rank: Enemy.Rank) -> Enemy:
	var scene: PackedScene = load("res://scenes/battlefield/enemy.tscn")
	var foe := scene.instantiate() as Enemy
	if rank != Enemy.Rank.COMMON:
		var worn: Array[EnemyAffixData] = []
		for value: Variant in ContentDB.affixes.values():
			var affix := value as EnemyAffixData
			if affix != null:
				worn.append(affix)
				break
		foe.promote(rank, worn)
	foe.setup(breed, 0, field, 1.0)
	field.add_child(foe)
	foe.global_position = at
	return foe


func _settle() -> void:
	for _frame: int in 4:
		await get_tree().process_frame
		await get_tree().physics_frame


func _finish() -> void:
	Sfx.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	if _failures == 0 and _ran == 5:
		print("[morale] PASS - a line breaks when its champion falls, holds "
			+ "while one stands, retreats up the road, comes back, and never "
			+ "changes how many bodies a wave costs")
	elif _failures == 0:
		printerr("[morale] FAIL - only %d of 5 tests ran" % _ran)
		get_tree().quit(1)
		return
	else:
		printerr("[morale] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[morale] FAIL: %s" % why)
