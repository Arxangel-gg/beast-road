extends Node

## The welcome (2026-09-14): a guest whose field has just stood up - fresh at
## the start, or back after a drop - is told the run as it stands, so a
## rejoin lands in the same run the host is playing rather than an empty
## road with the right seed.
##
##   godot --headless --path game res://tools/rejoin_check.tscn
##
## What this holds, in the order it would go wrong:
##
## - the host composes the welcome from what it actually holds: the seed, the
##   wave and the phase; the clock and the act; the purse and the wall; every
##   tower, every announced body, every drop on the ground - and nothing that
##   was never announced, because a body with no identity cannot be mirrored;
## - a guest fed that welcome through the relay's own receive path stands
##   where the host stands: the wave, the phase, the towers as puppets, the
##   bodies as puppets, the drops on the ground.
##
## The wire itself - that a late arrival is sent the seed, addressed to it
## alone - is `coop_check`'s, which has two real sessions to prove it on.

const SEED: int = 20260914

var _failures: int = 0
var _checked: int = 0
var _run: Run = null
var _field: Battlefield = null
var _world: CoopWorld = null


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	_field = _run.battlefield
	_world = _field.get("_coop_world") as CoopWorld if _field != null else null
	_check(_field != null and _world != null, "the harness needs a battlefield and its co-op world")
	if _field != null and _world != null:
		if _field.wave_director != null:
			_field.wave_director.stop()
		_field.sky().events_enabled = false
		await _test_the_welcome_is_the_world()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _f: int in 20:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[rejoin] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[rejoin] PASS - %d checks: the welcome is the world, and a guest fed it stands where the host stands" % _checked)
	get_tree().quit(0)


func _test_the_welcome_is_the_world() -> void:
	# The host's world: a wave in, in battle, two towers, two announced bodies
	# and one that never was, a coin on the ground.
	RunState.gain_every_currency(400)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	RunState.wave_number = 12
	var first: Vector2i = _field.free_anchor_near(0)
	RunState.set_tower(first, "ember_spire", 2)
	var second: Vector2i = _field.free_anchor_near(2)
	RunState.set_tower(second, "ember_spire", 1)
	await get_tree().process_frame
	var breed: EnemyData = ContentDB.enemy("bogkin")
	var told: Enemy = _field.spawn_enemy(breed, 0, 1.0)
	var also: Enemy = _field.spawn_enemy(breed, 1, 1.0)
	var nobody: Enemy = _field.spawn_enemy(breed, 2, 1.0)
	if told == null or also == null or nobody == null:
		_check(false, "the harness needs three bodies")
		return
	told.net_id = 7
	also.net_id = 8
	# And a boss mid-fight, a phase in.
	var bosses: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.BOSS)
	var boss: Enemy = _field.spawn_enemy(bosses[0], 3, 1.0) if not bosses.is_empty() else null
	if boss != null:
		boss.net_id = 9
		boss.apply_boss_phase(1)
	_field.spawn_loot(RunState.GOLD, 20, Vector2(900.0, 900.0))
	await get_tree().process_frame
	var coin: LootDrop = null
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		coin = node as LootDrop
	_check(coin != null, "the harness needs a drop on the ground")
	if coin != null:
		coin.net_id = 3
	var gold: int = RunState.currency(RunState.GOLD)

	var facts: Array = _world.compose_welcome()
	_check(not facts.is_empty() and int(facts[0][0]) == CoopRelay.Fact.WELCOME,
		"the welcome opens with the run itself")
	var snapshot: Dictionary = facts[0][1][0] if not facts.is_empty() else {}
	_check(int(snapshot.get("seed", -1)) == RunState.run_seed, "carrying the seed")
	_check(int(snapshot.get("wave", -1)) == 12, "the wave (%s)" % str(snapshot.get("wave")))
	_check(int(snapshot.get("phase", -1)) == RunState.Phase.ROAD_BATTLE, "and the phase")
	var kinds: Dictionary = {}
	for fact: Array in facts:
		kinds[int(fact[0])] = int(kinds.get(int(fact[0]), 0)) + 1
	_check(int(kinds.get(CoopRelay.Fact.WORLD_CLOCK, 0)) == 1, "the clock, once")
	_check(int(kinds.get(CoopRelay.Fact.PHASE_CHANGED, 0)) == 1, "the phase, once")
	_check(int(kinds.get(CoopRelay.Fact.CURRENCY_CHANGED, 0)) == RunState.CURRENCIES.size(),
		"every purse (%d)" % int(kinds.get(CoopRelay.Fact.CURRENCY_CHANGED, 0)))
	_check(int(kinds.get(CoopRelay.Fact.TOWN_HEALTH, 0)) == 1, "the wall's health")
	_check(int(kinds.get(CoopRelay.Fact.TOWER_STATE, 0)) == 2, "both towers (%d)" % int(kinds.get(CoopRelay.Fact.TOWER_STATE, 0)))
	_check(int(kinds.get(CoopRelay.Fact.ENEMY_SPAWNED, 0)) == 3,
		"the announced bodies and not the one nobody announced (%d)" % int(kinds.get(CoopRelay.Fact.ENEMY_SPAWNED, 0)))
	_check(int(kinds.get(CoopRelay.Fact.BOSS_SPAWNED, 0)) == 1 and int(kinds.get(CoopRelay.Fact.BOSS_PHASE_CHANGED, 0)) == 1,
		"the boss, as a boss, in the phase it reached")
	_check(int(kinds.get(CoopRelay.Fact.LOOT_SPAWNED, 0)) == 1, "the coin on the ground")
	var gold_told: int = -1
	var ids: Array[int] = []
	var anchors: Array = []
	for fact: Array in facts:
		match int(fact[0]):
			CoopRelay.Fact.CURRENCY_CHANGED:
				if String(fact[1][0]) == RunState.GOLD:
					gold_told = int(fact[1][1])
			CoopRelay.Fact.ENEMY_SPAWNED:
				ids.append(int(fact[1][0]))
			CoopRelay.Fact.TOWER_STATE:
				anchors.append(fact[1][0])
	ids.sort()
	_check(gold_told == gold, "the purse as it stands (%d vs %d)" % [gold_told, gold])
	_check(ids == [7, 8, 9], "the bodies by their identities (%s)" % str(ids))
	_check(anchors.has(first) and anchors.has(second), "the towers where they stand")

	# The guest's side: the same run with none of it, fed the welcome through
	# the relay's own receive path.
	RunState.wave_number = 0
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.clear_tower(first)
	RunState.clear_tower(second)
	for enemy: Enemy in [told, also, nobody, boss]:
		if enemy != null:
			enemy.queue_free()
	if coin != null:
		coin.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_field.tower_at_anchor(first) == null and _field.enemy_count() == 0,
		"the guest starts with nothing standing")
	# A guest, by the state the session reads and nothing else: `_set_state`
	# would announce a session to every screen in the game.
	Coop._state = Coop.State.CONNECTED
	# Through the session's own relay: a second relay on the same bus would
	# hear the first one's replay as a guest authoring facts and shout.
	var line: CoopRelay = Coop.relay()
	_check(line != null, "the session carries its relay offline")
	for fact: Array in facts:
		if line != null:
			line.call("_replay", int(fact[0]), fact[1])
	await get_tree().process_frame
	await get_tree().process_frame
	_check(RunState.wave_number == 12, "the guest is on the wave (%d)" % RunState.wave_number)
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE, "and in the phase")
	var rebuilt: Tower = _field.tower_at_anchor(first)
	_check(rebuilt != null and rebuilt.puppet, "the towers stand again, as puppets")
	_check(_field.tower_at_anchor(second) != null, "both of them")
	var puppets: int = 0
	var found: Array[int] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body != null and body.puppet and body.net_id > 0:
			puppets += 1
			found.append(body.net_id)
	found.sort()
	_check(puppets == 3 and found == [7, 8, 9], "the bodies stand again, as puppets (%s)" % str(found))
	var drops: int = 0
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop != null and drop.net_id == 3:
			drops += 1
	_check(drops == 1, "the coin lies where it lay")
	Coop._state = Coop.State.OFFLINE
	await get_tree().process_frame


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[rejoin] " + message)
