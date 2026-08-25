extends Node

## Traps: laid on roads, in Preparation, and consumed.
##
##   godot --headless --path game res://tools/trap_check.tscn
##
## Three properties, and every one of them is a rule the rest of the game would
## not notice being broken.
##
## **Preparation only.** CLAUDE.md §1 locks construction to Preparation and says
## not to reopen it. A trap that could be dropped mid-combat reopens exactly that
## decision, and it would not error - it would just quietly become a different
## game. Asserted here so the single gate stays the single gate.
##
## **On the road, and only there.** The placement rule is inverted against a
## tower's: a tower may not stand on a lane and a trap is worthless anywhere
## else. Two opposite rules a few lines apart is how one of them ends up written
## the wrong way round.
##
## **Consumed.** A trap has a number of triggers and then it is gone. That is
## what stops a lane being solved once and ceasing to be a lane, and a trap that
## stopped counting down would look completely normal.

const SEED: int = 271828183

var _failures: int = 0
var _run: Node = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	RunState.gain_every_currency(9999)

	_test_the_data_is_whole()
	await _test_laying_is_preparation_only()
	await _test_a_trap_belongs_on_a_road()
	await _test_it_fires_and_is_spent()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[trap] PASS - road-only, Preparation-only, and every one of them runs out")
	get_tree().quit(_failures)


func _test_the_data_is_whole() -> void:
	var kinds: Array[TrapData] = ContentDB.trap_kinds()
	_check(kinds.size() >= 3, "the three traps must ship, found %d" % kinds.size())
	for kind: TrapData in kinds:
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no sprite at %s" % [kind.id, kind.get_sprite_path()])
		_check(kind.triggers > 0, "%s must run out: an endless trap is a tower "
			% kind.id + "that costs less and cannot be shot")
		_check(not kind.cost.is_empty(), "%s must cost something" % kind.id)
		# A trap that does nothing at all is content that looks like a bug.
		_check(kind.damage > 0.0 or kind.slow_factor < 1.0 or kind.burn_dps > 0.0,
			"%s does nothing when it goes off" % kind.id)


## The locked build phase, tested rather than trusted.
func _test_laying_is_preparation_only() -> void:
	var road: Vector2i = _road_tile()
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var refusal: String = _field.try_place_trap(road, ContentDB.trap("spike_pit"))
	_check(not refusal.is_empty(),
		"laying a trap during combat must be refused: CLAUDE.md §1 locks it")
	_check(not RunState.traps.has(road), "and must not lay one anyway")

	RunState.set_phase(RunState.Phase.PREPARATION)
	_check(_field.try_place_trap(road, ContentDB.trap("spike_pit")).is_empty(),
		"and must be allowed during Preparation")
	_check(RunState.traps.has(road), "which means a trap is actually there")
	await get_tree().process_frame
	RunState.clear_trap(road)
	await get_tree().process_frame


## The inverted placement rule.
func _test_a_trap_belongs_on_a_road() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var off_road: Vector2i = _open_tile()
	_check(not _field.try_place_trap(off_road, ContentDB.trap("tar_snare")).is_empty(),
		"a trap off the road must be refused: it is the one thing it cannot do")

	var road: Vector2i = _road_tile()
	_check(_field.try_place_trap(road, ContentDB.trap("tar_snare")).is_empty(),
		"and on the road must be allowed")
	_check(not _field.try_place_trap(road, ContentDB.trap("tar_snare")).is_empty(),
		"but two on one tile must not")
	await get_tree().process_frame
	RunState.clear_trap(road)
	await get_tree().process_frame


## It goes off, it hurts, and it runs out.
func _test_it_fires_and_is_spent() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var road: Vector2i = _road_tile()
	var pit: TrapData = ContentDB.trap("spike_pit")
	_field.try_place_trap(road, pit)
	await get_tree().process_frame
	var trap: Trap = null
	for node: Node in get_tree().get_nodes_in_group(Trap.GROUP):
		var candidate := node as Trap
		if candidate != null and candidate.tile == road:
			trap = candidate
	if trap == null:
		_check(false, "laying a trap must raise its node")
		return
	_check(trap.triggers_left() == pit.triggers,
		"a fresh trap must carry its full triggers")

	# Fired directly rather than by walking something over it: what is under test
	# is the counting down and the clearing, not the proximity check.
	for _shot: int in pit.triggers:
		trap.fire()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not RunState.traps.has(road),
		"a spent trap must be cleared from the run, not left lying there")
	_check(not is_instance_valid(trap) or trap.is_queued_for_deletion(),
		"and its node must go with it")


## A tile that is definitely a road.
func _road_tile() -> Vector2i:
	for radius: int in range(2, 40):
		for angle: int in range(0, 360, 15):
			var at := Vector2i(int(cos(deg_to_rad(angle)) * float(radius)),
				int(sin(deg_to_rad(angle)) * float(radius)))
			if _field.grid.cell_at(at) == BattleGrid.Cell.ROAD:
				if not RunState.traps.has(at):
					return at
	_check(false, "the harness needs a road tile")
	return Vector2i.ZERO


## A tile that is definitely not a road.
func _open_tile() -> Vector2i:
	for radius: int in range(4, 40):
		for angle: int in range(0, 360, 15):
			var at := Vector2i(int(cos(deg_to_rad(angle)) * float(radius)),
				int(sin(deg_to_rad(angle)) * float(radius)))
			if _field.grid.cell_at(at) == BattleGrid.Cell.OPEN:
				return at
	_check(false, "the harness needs open ground")
	return Vector2i.ZERO


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[trap] %s" % why)
