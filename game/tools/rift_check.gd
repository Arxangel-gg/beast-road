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
	await _test_the_deep_stands_at_the_road()
	await _test_caches_and_plates()
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
		# The stage's own figure rather than the constant: a stage pays by the
		# act since 2026-10-01, and the act scale is held below.
		# **Amended 2026-10-06**: the exit pays the stage's figure less the
		# caches' shares; the caches pay the rest when opened. The sum is held
		# in `_test_caches_and_plates`.
		_check(int(reward["resources"]) == RiftArena._stage_exit_pay(1), "a stage pays its resources")
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
		_check(int(reward["resources"]) == RiftArena._stage_exit_pay(1),
			"a stage whose chest was opened is not paid twice: got %d" % int(reward["resources"]))
		_check((reward["gear"] as Array).size() == Balance.RIFT_GEAR_PER_STAGE * 2,
			"two stages of gear, one rolled at the exit and one carried from the chest")
		_check(String(reward["relic_id"]).is_empty(), "a relic waits at the bottom, not the second door")
		_check(bool(reward["left"]), "and it says the player left")
	rift.queue_free()
	await get_tree().process_frame


## **Caches and plates** (2026-10-06). The caches stand in rooms off the way,
## on open floor, clear of the entry and the vault; one broken open pays its
## share on the floor as drops, once; the exit pays the figure less the
## caches' shares, and the two halves sum to the stage's figure exactly. The
## plates stand on corridor floor in no room, spaced; a hero standing on one
## fires a strike that takes the authored share of the hero's pool, a body on
## one takes the share of its own, and a plate fires once until it rearms.
func _test_caches_and_plates() -> void:
	RunState.act = Balance.DUNGEON_EVERY_ACTS
	_rewards.clear()
	var rift: RiftArena = await _arena()
	rift.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
	rift.set_process(false)
	var maze: DungeonLayout = rift.dungeon()
	var caches: Array[DungeonCache] = rift.caches()
	var plates: Array[DungeonPlate] = rift.plates()
	_check(caches.size() == Balance.DUNGEON_CACHES_PER_STAGE,
		"a stage lays %d caches (%d)" % [Balance.DUNGEON_CACHES_PER_STAGE, caches.size()])
	_check(plates.size() == Balance.DUNGEON_PLATES_PER_STAGE,
		"a dungeon lays %d plates (%d)" % [Balance.DUNGEON_PLATES_PER_STAGE, plates.size()])
	for cache: DungeonCache in caches:
		var tile: Vector2i = RaidLayout.world_to_tile(cache.global_position)
		var in_room: bool = false
		for room: Rect2i in maze.rooms:
			if room.has_point(tile):
				in_room = true
		_check(maze.is_open(cache.global_position) and in_room, "a cache stands on a room's floor")
		_check(maxi(absi(tile.x - maze.entry.x), absi(tile.y - maze.entry.y)) >= 3
			and maxi(absi(tile.x - maze.deep.x), absi(tile.y - maze.deep.y)) >= 2,
			"a cache stands clear of the entry and the vault")
	for index: int in plates.size():
		var plate: DungeonPlate = plates[index]
		var tile: Vector2i = RaidLayout.world_to_tile(plate.global_position)
		var in_room: bool = false
		for room: Rect2i in maze.rooms:
			if room.has_point(tile):
				in_room = true
		_check(maze.is_open(plate.global_position) and not in_room, "a plate stands on corridor floor")
		_check(maxi(absi(tile.x - maze.entry.x), absi(tile.y - maze.entry.y)) >= 5, "a plate is clear of the entry")
		for other: int in range(index + 1, plates.size()):
			var there: Vector2i = RaidLayout.world_to_tile(plates[other].global_position)
			_check(maxi(absi(there.x - tile.x), absi(there.y - tile.y)) >= Balance.DUNGEON_PLATE_SPACING,
				"plates keep their spacing")
	# The sum: every cache's share and the exit's pay are the stage's figure.
	var figure: int = RiftArena._stage_resources(1)
	_check(RiftArena._cache_pay(1) * Balance.DUNGEON_CACHES_PER_STAGE + RiftArena._stage_exit_pay(1) == figure,
		"the caches and the exit sum to the stage's figure (%d + %d = %d)" % [
			RiftArena._cache_pay(1) * Balance.DUNGEON_CACHES_PER_STAGE, RiftArena._stage_exit_pay(1), figure])
	_check(RiftArena._cache_pay(1) > 0 and RiftArena._stage_exit_pay(1) > RiftArena._cache_pay(1),
		"a cache is worth something and the exit is worth more")
	# One broken open pays its share on the floor, once.
	if not caches.is_empty():
		var before: int = _loot_on(rift)
		caches[0].open()
		_check(_loot_on(rift) - before == RiftArena._cache_pay(1),
			"a cache pays its share on the floor (%d for %d)" % [_loot_on(rift) - before, RiftArena._cache_pay(1)])
		caches[0].open()
		rift.open_cache(caches[0])
		_check(_loot_on(rift) - before == RiftArena._cache_pay(1), "a cache opens once")
		_check(int(rift.status()["caches_opened"]) == 1, "the stage counts the cache")
	# A plate under the hero fires, and the strike takes the hero's share.
	if not plates.is_empty() and rift.hero != null:
		var plate: DungeonPlate = plates[0]
		var pool: Health = Health.of(rift.hero)
		pool.current_hp = pool.max_hp
		rift.hero.global_position = plate.global_position
		plate._process(0.05)
		_check(not plate.armed and plate.fired == 1, "a hero on the plate fires it")
		var strike: EnemyGroundStrike = null
		for node: Node in rift.effect_root.get_children():
			if node is EnemyGroundStrike:
				strike = node
		_check(strike != null and is_instance_valid(strike), "the plate stands a strike up")
		if strike != null:
			_check(strike.hurts_bodies and strike.body_field == rift
				and is_equal_approx(strike.reach, Balance.DUNGEON_PLATE_REACH), "the strike is the plate's")
			strike._process(Balance.DUNGEON_PLATE_DELAY + 0.05)
			var taken: float = pool.max_hp - pool.current_hp
			_check(is_equal_approx(taken, pool.max_hp * Balance.DUNGEON_PLATE_DAMAGE),
				"the hero takes the plate's share of their own pool (%.1f of %.1f)" % [taken, pool.max_hp])
		plate._process(0.05)
		_check(plate.fired == 1, "a fired plate does not fire again before it rearms")
		# Off the plate, a body on it fires it once it has rearmed, and takes its own share.
		rift.hero.global_position = plate.global_position + Vector2(400.0, 0.0)
		var breed: EnemyData = rift._pick_breed()
		var body: Enemy = rift._spawn(breed, plate.global_position + Vector2(8.0, 0.0), 1.0)
		await get_tree().process_frame
		var body_pool: Health = Health.of(body)
		var body_before: float = body_pool.current_hp
		plate._process(Balance.DUNGEON_PLATE_REARM + 0.1)
		plate._process(0.05)
		_check(plate.armed == false and plate.fired == 2, "a body on the plate fires it once it has rearmed (%d)" % plate.fired)
		var second: EnemyGroundStrike = null
		for node: Node in rift.effect_root.get_children():
			if node is EnemyGroundStrike:
				second = node
		if second != null:
			second._process(Balance.DUNGEON_PLATE_DELAY + 0.05)
			var body_taken: float = body_before - body_pool.current_hp
			_check(is_equal_approx(body_taken, body_pool.max_hp * Balance.DUNGEON_PLATE_BODY_SHARE),
				"a body takes the plate's share of its own pool (%.1f of %.1f)" % [body_taken, body_pool.max_hp])
	rift.call("_finish", {"died": true})
	rift.queue_free()
	await get_tree().process_frame


func _loot_on(rift: RiftArena) -> int:
	var total: int = 0
	for node: Node in rift.effect_root.get_children():
		var drop := node as LootDrop
		if drop != null and is_instance_valid(drop) and not drop.is_queued_for_deletion():
			total += drop.amount
	return total


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


## **A body under the road stands at the road's strength, and a stage pays by
## the act** (2026-10-01). Arenas fielded their region's breeds at base health
## on every act and every road, so an Act VII rift on the Chainmaker's Road was
## paper - and paid what an Act II rift paid. Driven through the arena's own
## `_spawn`, which the raid, the rift, the dungeon, the chieftain and the
## guardian all go through, on a late act and the hardest road.
func _test_the_deep_stands_at_the_road() -> void:
	var act_was: int = RunState.act
	var tier_was: String = RunState.tier_id
	var wave_was: int = RunState.wave_number
	RunState.act = 7
	RunState.tier_id = "hell"
	RunState.wave_number = 300
	var rift: RiftArena = await _arena()
	rift.open(RiftArena.Kind.RIFT, Vector2.ZERO)
	rift.set_process(false)
	var breed: EnemyData = ContentDB.enemy("bogkin")
	var body: Enemy = rift._spawn(breed, Vector2(120.0, 0.0), 1.0) if breed != null else null
	_check(body != null, "the arena stands a body up")
	if body != null:
		var hp: float = float(body.get("_hp_scale"))
		var hit: float = float(body.get("_damage_scale"))
		_check(is_equal_approx(hp, WaveDirector.road_hp_scale()),
			"a body in the deep stands at the road's health: %.2f against %.2f"
				% [hp, WaveDirector.road_hp_scale()])
		_check(is_equal_approx(hit, WaveDirector.road_damage_scale()),
			"and hits at the road's weight: %.2f against %.2f"
				% [hit, WaveDirector.road_damage_scale()])
		_check(hp > 5.0, "an Act VII body on the hardest road is no base-strength body: %.2f" % hp)
	var paid: int = RiftArena._stage_resources(1)
	var want: int = int(round(float(Balance.RIFT_RESOURCES_PER_STAGE) * Balance.kill_act_scale(7)))
	_check(paid == want and paid > Balance.RIFT_RESOURCES_PER_STAGE,
		"an Act VII stage pays by the act, as a kill does: %d against %d" % [paid, want])
	rift.queue_free()
	await get_tree().process_frame
	RunState.act = act_was
	RunState.tier_id = tier_was
	RunState.wave_number = wave_was


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
