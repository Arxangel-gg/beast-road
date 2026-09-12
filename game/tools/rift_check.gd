extends Node

## Rifts and dungeons: the gates on the field, the fill, the guardian, the
## door, and a reward that is only ever what the road already pays.
##
## Owner request, 2026-09-11. The system reuses the raid's arena, so most of
## what could break it is already gated there; what this holds is the part
## that is new and the part that is a rule:
##
## - a gate is dug where the ponds are dug - the outer band, open ground, off
##   the roads - and only from the act rifts open; a dungeon mouth only every
##   so many acts; a gate taken is a gate spent;
## - kills fill the rift and the guardian steps through at full; the guardian
##   falling opens the door - out of a rift, down or out of a dungeon - with
##   a chest beside it; the clock starts a collapse, and a collapse that runs
##   out pays only what was banked while an exit taken in time keeps it;
## - **the reward is currency, gear and Shards and nothing else.** Every key
##   on it is named here, so a future "and a permanent +1" cannot arrive
##   without failing this file.

const ARENA: String = "res://scenes/rift/rift_arena.tscn"

var _failures: int = 0
var _checked: int = 0
var _rewards: Array[Dictionary] = []
var _doors: Array[Vector2i] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260911)
	RunState.terrain_id = "jungle"
	RunState.phase = RunState.Phase.ROAD_BATTLE
	GameDirector.run_active = true
	EventBus.rift_ended.connect(func(reward: Dictionary) -> void: _rewards.append(reward))
	EventBus.rift_stage_cleared.connect(func(stage: int, stages: int) -> void:
		_doors.append(Vector2i(stage, stages)))
	await get_tree().process_frame

	await _test_gates_are_dug_where_ponds_are()
	await _test_a_rift_fills_and_closes()
	await _test_a_dungeon_has_a_door()
	await _test_a_collapse_pays_only_what_was_banked()
	_test_the_reward_is_only_what_the_road_pays()

	# The rift opening put the raid theme on; a playback alive at exit is a
	# leaked resource and a red gate.
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Vfx.clear()
	for _f: int in 10:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[rifts] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[rifts] PASS - %d checks: gates, the fill, the guardian, the door and the reward" % _checked)
	get_tree().quit(0)


## Gates sit in the outer band, on open ground, off the roads; a rift from
## `RIFT_FIRST_ACT`, a dungeon mouth every `DUNGEON_EVERY_ACTS`.
func _test_gates_are_dug_where_ponds_are() -> void:
	var grid := BattleGrid.new()
	var reach: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE * 2.5
	for act: int in [1, Balance.RIFT_FIRST_ACT, Balance.DUNGEON_EVERY_ACTS]:
		RunState.act = act
		var gates := RiftGates.new()
		gates.grid = grid
		add_child(gates)
		gates.scatter()
		var kinds: Array[int] = gates.gate_kinds()
		if act < Balance.RIFT_FIRST_ACT:
			_check(kinds.is_empty(), "act %d is before rifts open and dug %d gates" % [act, kinds.size()])
		else:
			_check(kinds.has(RiftArena.Kind.RIFT), "act %d must dig a rift gate" % act)
			_check(kinds.has(RiftArena.Kind.DUNGEON) == (act % Balance.DUNGEON_EVERY_ACTS == 0),
				"act %d dug a dungeon mouth when it should not have, or did not when it should" % act)
		for at: Vector2 in gates.gate_positions():
			_check(at.length() >= Balance.RIFT_GATE_EDGE_BAND * reach * 0.98,
				"a gate at %s is %.0f from the town, inside the edge band" % [str(at), at.length()])
			_check(grid.cell_at(BattleGrid.world_to_tile(at)) == BattleGrid.Cell.OPEN,
				"a gate at %s is not on open ground" % str(at))
			var half: Vector2 = Vector2(RiftGates.FOOTPRINT) * BattleGrid.TILE * 0.5
			_check(Fishing.ground_is_open(grid, Rect2(at - half, half * 2.0),
				Balance.RIFT_GATE_CLEARANCE_TILES), "a gate at %s stands on or beside a road" % str(at))
		if kinds.has(RiftArena.Kind.RIFT):
			var where: Vector2 = gates.spend(RiftArena.Kind.RIFT)
			_check(where != Vector2.ZERO, "spending the rift gate must say where it stood")
			_check(gates.spend(RiftArena.Kind.RIFT) == Vector2.ZERO,
				"a spent gate must not be spent twice")
		gates.queue_free()
		await get_tree().process_frame
	# The same seed digs the same gates, on both machines.
	RunState.act = Balance.DUNGEON_EVERY_ACTS
	var one := RiftGates.new()
	one.grid = grid
	add_child(one)
	one.scatter()
	var two := RiftGates.new()
	two.grid = grid
	add_child(two)
	two.scatter()
	_check(one.gate_positions() == two.gate_positions(), "two machines dug different gates from one seed")
	one.queue_free()
	two.queue_free()
	await get_tree().process_frame


## Kills fill the rift; at full the guardian steps through; its fall closes
## the rift and pays one stage.
func _test_a_rift_fills_and_closes() -> void:
	RunState.act = 2
	var rift: RiftArena = await _arena()
	var before: int = MetaState.rifts_closed
	rift.open(RiftArena.Kind.RIFT, Vector2(300.0, -200.0))
	rift.set_process(false)
	rift._process(0.1)
	var state: Dictionary = rift.status()
	_check(int(state["stages"]) == 1 and int(state["stage"]) == 1, "a rift is one stage")
	_check(not bool(state["guardian_out"]), "the guardian waits for the fill")
	var kills: int = int(ceil(1.0 / Balance.RIFT_FILL_PER_KILL))
	for _kill: int in kills - 1:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	rift._process(0.1)
	_check(not bool(rift.status()["guardian_out"]), "one kill short must not be full")
	EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	rift._process(0.1)
	_check(bool(rift.status()["guardian_out"]), "the last kill brings the guardian through")
	_check(rift._guardian != null and is_instance_valid(rift._guardian), "and it is a real body on the field")
	_check(_rewards.is_empty(), "the rift must not close while the guardian stands")
	# The guardian falls: the door opens with the chest beside it (2026-09-12),
	# and leaving is what closes the rift.
	_fell(rift)
	rift._process(0.1)
	_check(_rewards.is_empty() and bool(rift.status()["at_door"]),
		"the guardian falling opens the rift's door rather than closing it")
	_check(bool(rift.status()["chest"]) and bool(rift.status()["exit_open"]),
		"a chest lands and the exit opens when the guardian falls")
	_check(not rift.descend(), "a rift has no way down")
	_check(rift.leave(), "and leaving through the door closes it")
	if _rewards.size() == 1:
		var reward: Dictionary = _rewards[0]
		_check(int(reward["stages"]) == 1, "one stage banked")
		_check(int(reward["resources"]) == Balance.RIFT_RESOURCES_PER_STAGE, "a stage pays its resources")
		_check(int(reward["shards"]) == Balance.RIFT_SHARDS_PER_STAGE, "and its Shards")
		_check((reward["gear"] as Array).size() == Balance.RIFT_GEAR_PER_STAGE, "and its gear")
		_check(String(reward["relic_id"]).is_empty(), "a rift is not a dungeon and pays no relic")
		_check(reward["at"] == Vector2(300.0, -200.0), "the spoils land where the gate stood")
	_check(MetaState.rifts_closed == before + 1, "the statistic counts the stage")
	rift.queue_free()
	await get_tree().process_frame


## A dungeon's guardian opens a door: down, or out with what is banked.
func _test_a_dungeon_has_a_door() -> void:
	RunState.act = Balance.DUNGEON_EVERY_ACTS
	_rewards.clear()
	_doors.clear()
	var rift: RiftArena = await _arena()
	rift.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
	rift.set_process(false)
	rift._process(0.1)
	_check(int(rift.status()["stages"]) == Balance.DUNGEON_STAGES, "a dungeon has %d stages" % Balance.DUNGEON_STAGES)
	_check(not rift.leave() and not rift.descend(), "there is no door until the guardian falls")
	var escalation_first: float = rift._escalation()
	_fill_and_clear(rift)
	_check(_doors.size() == 1 and _doors[0] == Vector2i(1, Balance.DUNGEON_STAGES),
		"the first guardian opens the first door: %s" % str(_doors))
	_check(_rewards.is_empty(), "a door is not the end")
	_check(bool(rift.status()["at_door"]), "the dungeon waits at the door")
	_check(rift.descend(), "going down is allowed at the door")
	rift.set_process(false)
	_check(int(rift.status()["stage"]) == 2, "and it is the second stage")
	_check(rift._escalation() > escalation_first, "deeper is harder")
	_fill_and_clear(rift)
	_check(_doors.size() == 2, "the second guardian opens the second door")
	# The chest: the stage's currency bursts on the floor and its gear is
	# banked, and the exit then pays the stage's currency *no second time*.
	var chest: DungeonChest = rift._chest
	_check(chest != null and is_instance_valid(chest), "the vault holds a chest")
	if chest != null and is_instance_valid(chest):
		rift.open_chest(chest)
		var entry: Dictionary = rift._banked_stage(2)
		_check(bool(entry.get("chest_opened", false)), "the chest marks its stage paid")
		_check((entry.get("gear", []) as Array).size() == Balance.RIFT_GEAR_PER_STAGE,
			"the chest holds the stage's gear")
		rift.open_chest(chest)
		_check((entry.get("gear", []) as Array).size() == Balance.RIFT_GEAR_PER_STAGE,
			"a chest opens once")
	_check(rift.leave(), "leaving is allowed at the door")
	_check(_rewards.size() == 1, "leaving closes the dungeon")
	if _rewards.size() == 1:
		var reward: Dictionary = _rewards[0]
		_check(int(reward["stages"]) == 2, "two stages banked; got %d" % int(reward["stages"]))
		# Stage two's currency burst from its chest; only stage one is paid here.
		_check(int(reward["resources"]) == Balance.RIFT_RESOURCES_PER_STAGE,
			"a stage whose chest was opened is not paid twice: got %d" % int(reward["resources"]))
		_check((reward["gear"] as Array).size() == Balance.RIFT_GEAR_PER_STAGE * 2,
			"two stages of gear, one rolled at the exit and one carried from the chest")
		_check(String(reward["relic_id"]).is_empty(), "a relic waits at the bottom, not the second door")
		_check(bool(reward["left"]), "and it says the player left")
	rift.queue_free()
	await get_tree().process_frame


## The clock collapses a stage. What was banked pays; what was in progress does not.
func _test_a_collapse_pays_only_what_was_banked() -> void:
	RunState.act = 2
	_rewards.clear()
	var rift: RiftArena = await _arena()
	rift.open(RiftArena.Kind.RIFT, Vector2.ZERO)
	rift.set_process(false)
	for _kill: int in 3:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	rift._process(Balance.RIFT_TIME_LIMIT + 1.0)
	_check(_rewards.is_empty() and bool(rift.status()["collapsing"]),
		"the clock running out starts a collapse rather than ending the stage")
	_check(bool(rift.status()["exit_open"]), "the exit opens for the collapse")
	var hp_before: float = rift.hero.health.current_hp
	rift._process(1.05)
	_check(rift.hero.health.current_hp < hp_before, "the collapse bites")
	rift._process(Balance.DUNGEON_COLLAPSE_SECONDS)
	_check(_rewards.size() == 1, "a collapse that runs out ends the stage")
	if _rewards.size() == 1:
		var reward: Dictionary = _rewards[0]
		_check(bool(reward["collapsed"]), "and says it collapsed")
		_check(int(reward["stages"]) == 0 and int(reward["resources"]) == 0
			and int(reward["shards"]) == 0 and (reward["gear"] as Array).is_empty(),
			"a collapsed stage pays nothing: %s" % str(reward))
	# An exit taken during the collapse keeps what was banked.
	_rewards.clear()
	var escape: RiftArena = await _arena()
	escape.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
	escape.set_process(false)
	_fill_and_clear(escape)
	_check(escape.descend(), "down to the second stage")
	escape.set_process(false)
	escape._process(Balance.RIFT_TIME_LIMIT + 1.0)
	_check(bool(escape.status()["collapsing"]), "the second stage collapses")
	_check(escape.take_exit(), "the exit can be taken while it collapses")
	_check(_rewards.size() == 1 and bool(_rewards[0]["escaped"]) and int(_rewards[0]["stages"]) == 1,
		"escaping keeps the banked stage: %s" % str(_rewards[0] if not _rewards.is_empty() else {}))
	escape.queue_free()
	await get_tree().process_frame
	# Dying pays nothing either, banked or not.
	var dead: Dictionary = rift._build_rift_reward({"died": true})
	_check(int(dead["resources"]) == 0 and (dead["gear"] as Array).is_empty() and int(dead["shards"]) == 0,
		"dying in the rift must pay nothing")
	rift.queue_free()
	await get_tree().process_frame


## The bound: every key a reward may carry, so a new kind of payment cannot
## arrive without being argued for here.
func _test_the_reward_is_only_what_the_road_pays() -> void:
	var allowed: Array[String] = ["kind", "stages", "died", "collapsed", "left", "escaped",
		"resources", "gear", "shards", "relic_id", "at"]
	for reward: Dictionary in _rewards:
		for key: Variant in reward.keys():
			_check(allowed.has(String(key)),
				("a rift reward carries `%s`, which is not currency, gear, Shards or a "
					+ "relic - nothing else may come out of a rift (working rule 7)") % String(key))
	_check(Balance.RIFT_FIRST_ACT >= 2, "rifts must not open on the teaching act")
	_check(Balance.DUNGEON_STAGES >= 2, "a dungeon with one stage is a rift")


func _fill_and_clear(rift: RiftArena) -> void:
	var kills: int = int(ceil(1.0 / Balance.RIFT_FILL_PER_KILL))
	for _kill: int in kills:
		EventBus.enemy_died.emit("bogkin", Vector2.ZERO)
	rift._process(0.1)
	_check(bool(rift.status()["guardian_out"]), "the fill must bring the guardian through")
	_fell(rift)
	rift._process(0.1)


## The guardian is gone. Freed rather than damaged: what the stage reads is
## that the body is no longer there, and that is the same whether it died of
## a sword or of a test.
func _fell(rift: RiftArena) -> void:
	var guardian: Enemy = rift._guardian
	if guardian == null or not is_instance_valid(guardian):
		return
	var parent: Node = guardian.get_parent()
	if parent != null:
		parent.remove_child(guardian)
	guardian.free()


func _arena() -> RiftArena:
	var rift: RiftArena = (load(ARENA) as PackedScene).instantiate() as RiftArena
	add_child(rift)
	for _f: int in 3:
		await get_tree().process_frame
	return rift


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	print("[rifts] %s" % message)
