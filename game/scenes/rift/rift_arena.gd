class_name RiftArena
extends RaidArena
## A rift, or - deeper - a dungeon: the raid's arena put to a second use.
##
## Owner request (2026-09-11): Astonia-style dungeons and rifts. A raid is a
## camp with a way out that keeps closing; a rift has no way out at all. Kills
## fill it, and when it is full its guardian steps through: kill the guardian
## and the rift closes and pays, run out of time and it collapses and pays
## nothing for the stage. A dungeon is a rift with stages, each harder than
## the last, and a door between them where the player decides - go deeper for
## more of the same, or leave with what is banked.
##
## **Everything a rift pays, the road already pays.** Run currency split the
## way a raid's is, gear rolled on the same tables at the same tier, Shards.
## That is the bound that keeps this a content system rather than a second
## economy (working rule 7): nothing new persists, and deeper is more of the
## same rather than a new kind of thing.
##
## Inherits the camp, the spawning, the hero handling and the cliffs from
## `RaidArena`; overrides the clock, the windows, the ending and the reward.

enum Kind { RIFT, DUNGEON }

var kind: Kind = Kind.RIFT
var _stage: int = 0
var _stages: int = 1
var _fill: float = 0.0
var _stage_clock: float = 0.0
var _guardian: Enemy = null
var _guardian_out: bool = false
var _at_door: bool = false
## Each stage cleared, kept so a collapse or a door pays what was earned.
var _banked: Array[Dictionary] = []
## Where the gate stood, so the spoils land beside it on the battlefield.
var _entered_from: Vector2 = Vector2.ZERO


func _ready() -> void:
	super()
	# Its own stream, so a rift's camp and a raid's are not the same shape.
	_rng = RunState.rng("rifts")


## Opens a rift of `which` kind, entered from `from` on the battlefield.
func open(which: Kind, from: Vector2) -> void:
	kind = which
	_stages = Balance.DUNGEON_STAGES if kind == Kind.DUNGEON else 1
	_stage = 0
	_banked.clear()
	_entered_from = from
	_begin_stage()


## Stands up one stage: a fresh camp, the clock at zero, the rift empty.
func _begin_stage() -> void:
	_stage += 1
	_fill = 0.0
	_stage_clock = 0.0
	_guardian = null
	_guardian_out = false
	_at_door = false
	_clear_enemies()
	_setup_ground()
	_build_camp()
	_tint_for_kind()
	_running = true
	_finished = false
	_kills = 0
	_refusals = 0
	_spawn_timer = 0.0
	set_process(true)
	visible = true
	if hero != null:
		hero.field = self
		hero.sync_from_run_state()
		hero.set_active(true)
		# Presence as well as activity; see `RaidArena.begin` for why both.
		hero.set_present(true)
	claim_effects()
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.rift_started.emit(int(kind), _stage, _stages)


## The rift's light on the camp: violet for a rift, a sunken green for a
## dungeon, so a glance says which this is.
func _tint_for_kind() -> void:
	if _terrain_root == null:
		return
	_terrain_root.modulate = Color(0.82, 0.78, 1.0) if kind == Kind.RIFT \
		else Color(0.78, 0.92, 0.82)


func _process(delta: float) -> void:
	if not _running:
		return
	_stage_clock += delta
	if not hero.is_alive() and not _finished:
		# Dying in the rift costs everything, as it does in a camp.
		_finish({"died": true})
		return
	if _at_door:
		return
	if _stage_clock >= Balance.RIFT_TIME_LIMIT and not _finished:
		_finish({"collapsed": true})
		return
	if _guardian_out:
		if _guardian == null or not is_instance_valid(_guardian) or _guardian.is_dying():
			_stage_cleared()
			return
	_tick_spawning(delta)


## No windows in a rift; the base class's tick is what the raid is.
func _tick_windows(_delta: float) -> void:
	pass


func _tick_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	# Half as fast once the guardian is out: the fight is the guardian's.
	_spawn_timer = Balance.RIFT_SPAWN_INTERVAL * (2.0 if _guardian_out else 1.0)
	if enemy_count() >= Balance.RIFT_MAX_ENEMIES:
		return
	var data: EnemyData = _pick_breed()
	if data != null:
		_spawn(data, _edge_point(), _escalation())


## Deeper is harder: each stage compounds on the last.
func _escalation() -> float:
	return Balance.RIFT_BASE_ESCALATION \
		* pow(1.0 + Balance.DUNGEON_STAGE_ESCALATION, float(_stage - 1)) \
		* RunState.enemy_escalation_multiplier()


func _on_enemy_died(_id: String, _at: Vector2) -> void:
	_kills += 1
	if _guardian_out or _at_door:
		return
	_fill = minf(_fill + Balance.RIFT_FILL_PER_KILL, 1.0)
	if _fill >= 1.0:
		_spawn_guardian()


## The guardian: one of the region's elites, scaled to be the stage's fight.
func _spawn_guardian() -> void:
	if _guardian_out:
		return
	_guardian_out = true
	var elites: Array[EnemyData] = []
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		for id: String in terrain.elite_ids:
			var regional: EnemyData = ContentDB.enemy(id)
			if regional != null:
				elites.append(regional)
	if elites.is_empty():
		elites = ContentDB.enemies_of_category(EnemyData.Category.ELITE)
	var data: EnemyData = elites[_rng.randi_range(0, elites.size() - 1)] \
		if not elites.is_empty() else _pick_breed()
	if data == null:
		return
	_guardian = _spawn(data, _edge_point(), _escalation() * Balance.RIFT_GUARDIAN_SCALE)
	EventBus.camera_shake_requested.emit(12.0, 0.5)
	Sfx.play("sfx_boss_spawn")


func _stage_cleared() -> void:
	_guardian_out = false
	_guardian = null
	_banked.append({"stage": _stage, "kills": _kills, "time": _stage_clock})
	_clear_enemies()
	if kind == Kind.RIFT or _stage >= _stages:
		_finish({"closed": true})
		return
	_at_door = true
	EventBus.rift_stage_cleared.emit(_stage, _stages)


## At a dungeon's door: down, or out.
func descend() -> bool:
	if not _at_door or _finished:
		return false
	_begin_stage()
	return true


func leave() -> bool:
	if not _at_door or _finished:
		return false
	_finish({"closed": true, "left": true})
	return true


## A rift has no windows, so the raid's extraction is refused here.
func extract() -> bool:
	return false


func _finish(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	_at_door = false
	set_process(false)
	if hero != null:
		hero.set_active(false)
		hero.set_present(false)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	var reward: Dictionary = _build_rift_reward(result)
	_clear_enemies()
	EventBus.rift_ended.emit(reward)


## What the banked stages pay. Dying pays nothing, as a camp death does; a
## collapse pays the stages already banked and forfeits the one in progress.
func _build_rift_reward(result: Dictionary) -> Dictionary:
	var reward: Dictionary = {
		"kind": int(kind),
		"stages": _banked.size(),
		"died": bool(result.get("died", false)),
		"collapsed": bool(result.get("collapsed", false)),
		"left": bool(result.get("left", false)),
		"resources": 0,
		"gear": [],
		"shards": 0,
		"relic_id": "",
		"at": _entered_from,
	}
	if bool(result.get("died", false)) or _banked.is_empty():
		return reward
	var paid: int = _banked.size()
	# Deeper pays more of the same: the second stage is worth a quarter more
	# than the first, the third half more, and so on.
	var weight: float = 0.0
	for index: int in paid:
		weight += 1.0 + 0.25 * float(index)
	reward["resources"] = int(round(float(Balance.RIFT_RESOURCES_PER_STAGE) * weight))
	reward["shards"] = int(round(float(Balance.RIFT_SHARDS_PER_STAGE) * weight))
	var tier: CampaignTierData = RunState.tier()
	var tier_order: int = tier.order if tier != null else 0
	var gear: Array = []
	for _stage_paid: int in paid:
		for _piece: int in Balance.RIFT_GEAR_PER_STAGE:
			var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), tier_order,
				RunState.rng("gear"))
			if not piece.is_empty():
				gear.append(piece)
	reward["gear"] = gear
	if kind == Kind.DUNGEON and paid >= _stages:
		reward["relic_id"] = _pick_relic()
	MetaState.rifts_closed += paid
	return reward


## For the HUD and the gate.
func status() -> Dictionary:
	return {
		"kind": int(kind),
		"stage": _stage,
		"stages": _stages,
		"fill": _fill,
		"time_left": maxf(Balance.RIFT_TIME_LIMIT - _stage_clock, 0.0),
		"guardian_out": _guardian_out,
		"at_door": _at_door,
		"kills": _kills,
		"banked": _banked.size(),
	}
