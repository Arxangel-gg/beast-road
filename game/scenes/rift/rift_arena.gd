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
## **The second cut (owner brief, 2026-09-12).** The floor is a maze now
## (`DungeonLayout`): rooms and corridors cut through rock, the guardian
## waiting in the vault at the far end of it, and bodies that come *through
## the maze* rather than at you across a plain. The clock no longer ends a
## stage on the frame it runs out - the place **collapses**: the exit opens
## where you came in, the ground shakes and bites, and you have a few seconds
## to reach it with what is banked or lose the stage with your health. A
## fallen guardian leaves a **chest**, which is the stage's spoils happening
## in front of you, and the way down and the way out are doors on the floor
## as well as buttons on the HUD.
##
## **Everything a rift pays, the road already pays.** Run currency split the
## way a raid's is, gear rolled on the same tables at the same tier, Shards.
## That is the bound that keeps this a content system rather than a second
## economy (working rule 7): nothing new persists, and deeper is more of the
## same rather than a new kind of thing. The chest changes *where* a stage's
## currency is paid, never how much.
##
## Inherits the camp, the spawning, the hero handling and the cliffs from
## `RaidArena`; overrides the layout, the clock, the windows, the ending, the
## reward and where bodies walk.

enum Kind { RIFT, DUNGEON }

var kind: Kind = Kind.RIFT
var _stage: int = 0
var _stages: int = 1
var _fill: float = 0.0
var _stage_clock: float = 0.0
var _guardian: Enemy = null
var _guardian_out: bool = false
var _guardian_at: Vector2 = Vector2.ZERO
var _at_door: bool = false
## Each stage cleared, kept so a collapse or a door pays what was earned:
## {stage, kills, time, chest_opened, gear}.
var _banked: Array[Dictionary] = []
## Where the gate stood, so the spoils land beside it on the battlefield.
var _entered_from: Vector2 = Vector2.ZERO

## The collapse: on once the clock runs out, with what is left of it.
var _collapsing: bool = false
var _collapse_left: float = 0.0
var _collapse_bite: float = 0.0
## Walking distances from the hero's tile, for bodies that come through the
## maze. Refreshed on a short clock rather than every frame.
var _flow: Dictionary = {}
var _flow_timer: float = 0.0
var _chest: DungeonChest = null
var _exit: DungeonPortal = null
var _stairs: DungeonPortal = null


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


## A rift's floor is cut, not raised. See `DungeonLayout`.
func _make_layout() -> RaidLayout:
	return DungeonLayout.new(_rng, kind == Kind.RIFT)


func dungeon() -> DungeonLayout:
	return layout as DungeonLayout


## Stands up one stage: a fresh maze, the clock at zero, the rift empty.
func _begin_stage() -> void:
	_stage += 1
	_fill = 0.0
	_stage_clock = 0.0
	_guardian = null
	_guardian_out = false
	_at_door = false
	_collapsing = false
	_collapse_left = 0.0
	_collapse_bite = 0.0
	_sweep_props()
	_clear_enemies()
	_setup_ground()
	_build_camp()
	_tint_for_kind()
	_running = true
	_finished = false
	_kills = 0
	_refusals = 0
	_spawn_timer = Balance.DUNGEON_FIRST_SPAWN_DELAY
	set_process(true)
	visible = true
	if hero != null:
		hero.field = self
		hero.sync_from_run_state()
		hero.set_active(true)
		# Presence as well as activity; see `RaidArena.begin` for why both.
		hero.set_present(true)
	_refresh_flow()
	claim_effects()
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.rift_started.emit(int(kind), _stage, _stages)


## The rock is dark and the floor is lit, so the maze reads the right way
## round: the raised plates are the walls here, and lit they read as the
## ground. Violet rock for a rift, cold grey for a dungeon, so a glance says
## which this is.
func _tint_for_kind() -> void:
	if _terrain_root == null:
		return
	_terrain_root.modulate = Balance.RIFT_WALL_TINT if kind == Kind.RIFT \
		else Balance.DUNGEON_WALL_TINT


## A dungeon is furnished with what was left in it: bones, cages, crates.
func _dress_camp() -> void:
	_dressing_root().dress(layout, _rng, Balance.DUNGEON_PROP_COUNT, Balance.DUNGEON_PROP_KINDS)


func _process(delta: float) -> void:
	if not _running:
		return
	_stage_clock += delta
	if not hero.is_alive() and not _finished:
		# Dying in the rift costs everything, as it does in a camp.
		_finish({"died": true})
		return
	_flow_timer -= delta
	if _flow_timer <= 0.0:
		_refresh_flow()
	if _at_door:
		return
	if _collapsing:
		_tick_collapse(delta)
		if _guardian_out:
			_watch_guardian()
		return
	if _stage_clock >= Balance.RIFT_TIME_LIMIT and not _finished:
		_begin_collapse()
		return
	if _guardian_out:
		_watch_guardian()
		return
	_tick_spawning(delta)


func _watch_guardian() -> void:
	if _guardian != null and is_instance_valid(_guardian) and not _guardian.is_dying():
		_guardian_at = _guardian.global_position
		return
	_stage_cleared()


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


# --- The maze: where bodies appear and how they come ------------------------------

func _refresh_flow() -> void:
	_flow_timer = Balance.DUNGEON_FLOW_REFRESH
	var maze: DungeonLayout = dungeon()
	if maze == null or hero == null:
		_flow = {}
		return
	_flow = maze.distances_from(RaidLayout.world_to_tile(hero.global_position))


## A body's feet land where it was dealt. `Enemy._ready` moves the node down
## by its feet anchor after the position is set, which on the raid's plain is
## harmless and in a maze can put the feet in the rock under a corridor -
## from where `can_step` refuses every step. Put back on the tile.
func _spawn(data: EnemyData, at: Vector2, scale: float) -> Enemy:
	var enemy: Enemy = super(data, at, scale)
	if enemy != null and dungeon() != null:
		enemy.global_position = at
	return enemy


## Bodies come out of the dark: an open tile a good walk from the hero, so
## they arrive through the maze rather than on top of the player.
func _edge_point() -> Vector2:
	var maze: DungeonLayout = dungeon()
	if maze == null:
		return super()
	var far: Array[Vector2i] = []
	for tile: Variant in _flow:
		if int(_flow[tile]) >= Balance.DUNGEON_SPAWN_MIN_TILES:
			far.append(tile)
	if far.is_empty():
		# Nothing that far - a small cavern - so anything not underfoot.
		var here: Vector2i = RaidLayout.world_to_tile(hero.global_position) if hero != null \
			else maze.entry
		for tile: Vector2i in maze.open_tiles():
			if maxi(absi(tile.x - here.x), absi(tile.y - here.y)) >= 3:
				far.append(tile)
	if far.is_empty():
		return RaidLayout.tile_to_world(maze.deep)
	var pick: Vector2i = far[_rng.randi_range(0, far.size() - 1)]
	return RaidLayout.tile_to_world(pick) + Vector2(_rng.randf_range(-16.0, 16.0),
		_rng.randf_range(-16.0, 16.0))


## **A body in a maze walks the maze.** The base answers the hero's position,
## which through rock is a wall to press against. This answers the next tile
## on the way, from the walking distances kept from the hero's tile; a body
## within a tile of the hero is told the hero, so the last step is the fight.
func objective_position(from: Vector2) -> Vector2:
	return route_hint(from, super(from))


func route_hint(from: Vector2, goal: Vector2) -> Vector2:
	var maze: DungeonLayout = dungeon()
	if maze == null or _flow.is_empty():
		return goal
	var here: Vector2i = RaidLayout.world_to_tile(from)
	var there: Vector2i = RaidLayout.world_to_tile(goal)
	if maxi(absi(here.x - there.x), absi(here.y - there.y)) <= 1:
		return goal
	if not _flow.has(here):
		return goal
	var best: Vector2i = here
	var best_depth: int = int(_flow[here])
	for step: Vector2i in DungeonLayout.DIRS:
		var next: Vector2i = here + step
		if _flow.has(next) and int(_flow[next]) < best_depth:
			best_depth = int(_flow[next])
			best = next
	if best == here:
		return goal
	return RaidLayout.tile_to_world(best)


# --- Kills, the guardian and the door ----------------------------------------------

func _on_enemy_died(_id: String, _at: Vector2) -> void:
	_kills += 1
	if _guardian_out or _at_door:
		return
	_fill = minf(_fill + Balance.RIFT_FILL_PER_KILL, 1.0)
	if _fill >= 1.0:
		_spawn_guardian()


## The guardian: one of the region's elites, scaled to be the stage's fight,
## waking in the vault at the far end of the maze and coming for the hero.
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
	var maze: DungeonLayout = dungeon()
	var at: Vector2 = RaidLayout.tile_to_world(maze.deep) if maze != null else _edge_point()
	_guardian = _spawn(data, at, _escalation() * Balance.RIFT_GUARDIAN_SCALE)
	_guardian_at = at
	EventBus.camera_shake_requested.emit(12.0, 0.5)
	Vfx.ring(at, 160.0, Color(0.95, 0.5, 0.9, 0.9), 0.8, 6.0)
	Sfx.play("sfx_boss_spawn")


## The guardian fell: the stage is banked, the chest lands where it died, and
## the doors open - down where it stood, out where the hero came in.
func _stage_cleared() -> void:
	_guardian_out = false
	_guardian = null
	_banked.append({"stage": _stage, "kills": _kills, "time": _stage_clock,
		"chest_opened": false, "gear": []})
	_clear_enemies()
	_at_door = true
	_collapsing = false
	var maze: DungeonLayout = dungeon()
	var vault: Vector2 = _guardian_at
	if maze != null:
		vault = RaidLayout.tile_to_world(maze.nearest_open(_guardian_at))
	_chest = DungeonChest.new()
	_chest.name = "Chest"
	_chest.arena = self
	_chest.stage = _stage
	_chest.position = vault
	_props_root().add_child(_chest)
	_open_exit()
	if kind == Kind.DUNGEON and _stage < _stages:
		_stairs = DungeonPortal.new()
		_stairs.name = "Stairs"
		_stairs.kind = DungeonPortal.Kind.STAIRS
		_stairs.arena = self
		_stairs.position = vault + Vector2(0.0, -RaidLayout.TILE * 1.5)
		_props_root().add_child(_stairs)
	EventBus.camera_shake_requested.emit(8.0, 0.4)
	EventBus.rift_stage_cleared.emit(_stage, _stages)


## The chest and the doors live with the bodies, sorted, and are swept away
## with the stage.
func _props_root() -> Node2D:
	return entity_root if entity_root != null else self


func _sweep_props() -> void:
	for prop: Node in [_chest, _exit, _stairs]:
		if prop != null and is_instance_valid(prop):
			prop.queue_free()
	_chest = null
	_exit = null
	_stairs = null


## The way out, where the hero arrived. Opened at the door and by a collapse.
func _open_exit() -> void:
	if _exit != null and is_instance_valid(_exit):
		_exit.open = true
		return
	var maze: DungeonLayout = dungeon()
	_exit = DungeonPortal.new()
	_exit.name = "Exit"
	_exit.kind = DungeonPortal.Kind.EXIT
	_exit.arena = self
	_exit.position = RaidLayout.tile_to_world(maze.entry) if maze != null else Vector2.ZERO
	_props_root().add_child(_exit)


## The chest opened: the stage's currency bursts across the floor as drops,
## and its gear is named and banked for the exit. Paid here *instead of* at
## the exit, never as well.
func open_chest(chest: DungeonChest) -> void:
	var entry: Dictionary = _banked_stage(chest.stage)
	if entry.is_empty() or bool(entry.get("chest_opened", false)):
		return
	entry["chest_opened"] = true
	var at: Vector2 = chest.global_position
	var resources: int = _stage_resources(chest.stage)
	var pieces: int = maxi(Balance.DUNGEON_CHEST_PIECES, 1)
	for index: int in pieces:
		var share: int = resources / pieces + (1 if index < resources % pieces else 0)
		if share <= 0:
			continue
		var currency: String = RunState.CURRENCIES[_rng.randi_range(0, RunState.CURRENCIES.size() - 1)]
		spawn_loot(currency, share, at)
	var tier: CampaignTierData = RunState.tier()
	var tier_order: int = tier.order if tier != null else 0
	var count: int = Balance.RIFT_GEAR_PER_STAGE
	if kind == Kind.DUNGEON and chest.stage >= _stages:
		count += Balance.DUNGEON_LAST_STAGE_BONUS_GEAR
	var gear: Array = []
	for _piece: int in count:
		var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), tier_order, RunState.rng("gear"))
		if piece.is_empty():
			continue
		gear.append(piece)
		var data: GearData = ContentDB.gear(String(piece["kind"]))
		var label: String = "%s %s" % [Stash.rarity_name(piece), data.display_name if data != null else "Gear"]
		Vfx.word(at + Vector2(0.0, -40.0 - 26.0 * float(gear.size())), label,
			Stash.rarity_colour(piece), 22)
	entry["gear"] = gear
	Sfx.play("sfx_chest_open")
	Vfx.ring(at, Balance.RAID_CHEST_GLOW * 1.2, Balance.LOOT_GLOW_COLOUR, 0.6, 6.0)
	Vfx.spark(at, Balance.LOOT_GLOW_COLOUR, 26, Vector2.UP, 320.0)
	Vfx.rays(at, Balance.LOOT_GLOW_COLOUR, 10, 90.0)
	Vfx.flash_at(at, Color(1.0, 0.92, 0.6, 0.6), 140.0)
	EventBus.camera_shake_requested.emit(6.0, 0.3)
	EventBus.rift_chest_opened.emit(chest.stage, gear.size())


func _banked_stage(stage: int) -> Dictionary:
	for entry: Dictionary in _banked:
		if int(entry.get("stage", 0)) == stage:
			return entry
	return {}


## What one stage's currency is worth: the second a quarter more than the
## first, the third half more, and so on.
static func _stage_resources(stage: int) -> int:
	return int(round(float(Balance.RIFT_RESOURCES_PER_STAGE) * (1.0 + 0.25 * float(stage - 1))))


## At a dungeon's door: down, or out.
func descend() -> bool:
	if not _at_door or _finished or kind != Kind.DUNGEON or _stage >= _stages:
		return false
	Sfx.play("sfx_dungeon_exit")
	_begin_stage()
	return true


func leave() -> bool:
	if not _at_door or _finished:
		return false
	_finish({"closed": true, "left": true})
	return true


## The exit taken on foot: at the door it is `leave`; in a collapse it is the
## escape that keeps what is banked.
func take_exit() -> bool:
	if _finished:
		return false
	if _at_door:
		return leave()
	if _collapsing:
		Sfx.play("sfx_dungeon_exit")
		_finish({"closed": true, "left": true, "escaped": true})
		return true
	return false


# --- The collapse -----------------------------------------------------------------

## The clock ran out. The stage is not lost yet: the exit opens where the hero
## came in, and the place gives them a few seconds to reach it while it shakes
## itself apart around them. Standing still is what loses it.
func _begin_collapse() -> void:
	_collapsing = true
	_collapse_left = Balance.DUNGEON_COLLAPSE_SECONDS
	_collapse_bite = 1.0
	_open_exit()
	Sfx.play("sfx_dungeon_collapse")
	EventBus.camera_shake_requested.emit(18.0, 1.2)
	Vfx.flash(Color(0.9, 0.3, 0.2, 0.35), 0.35, 0.6)
	EventBus.rift_collapsing.emit(Balance.DUNGEON_COLLAPSE_SECONDS)


func _tick_collapse(delta: float) -> void:
	_collapse_left -= delta
	_collapse_bite -= delta
	if _collapse_bite <= 0.0:
		_collapse_bite = 1.0
		if hero != null and hero.health != null:
			hero.health.take_damage(hero.health.max_hp * Balance.DUNGEON_COLLAPSE_DAMAGE,
				hero.global_position + Vector2.UP * 40.0)
		EventBus.camera_shake_requested.emit(6.0, 0.35)
		var maze: DungeonLayout = dungeon()
		if maze != null and hero != null:
			# Rock falling around the hero, wherever they are running.
			for _rock: int in 3:
				var at: Vector2 = hero.global_position + Vector2(_rng.randf_range(-220.0, 220.0),
					_rng.randf_range(-160.0, 160.0))
				Vfx.dust(at, Color(0.45, 0.4, 0.36, 0.9), 6, 40.0)
	if _collapse_left <= 0.0 and not _finished:
		_finish({"collapsed": true})


# --- Ending ---------------------------------------------------------------------------

## A rift has no windows, so the raid's extraction is refused here.
func extract() -> bool:
	return false


func _finish(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	_at_door = false
	_collapsing = false
	set_process(false)
	if hero != null:
		hero.set_active(false)
		hero.set_present(false)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	EventBus.interact_prompt.emit("", "")
	var reward: Dictionary = _build_rift_reward(result)
	_clear_enemies()
	EventBus.rift_ended.emit(reward)


## What the banked stages pay. Dying pays nothing, as a camp death does; a
## collapse pays the stages already banked and forfeits the one in progress.
## A stage whose chest was opened has had its currency already, and its gear
## is what the chest held.
func _build_rift_reward(result: Dictionary) -> Dictionary:
	var reward: Dictionary = {
		"kind": int(kind),
		"stages": _banked.size(),
		"died": bool(result.get("died", false)),
		"collapsed": bool(result.get("collapsed", false)),
		"left": bool(result.get("left", false)),
		"escaped": bool(result.get("escaped", false)),
		"resources": 0,
		"gear": [],
		"shards": 0,
		"relic_id": "",
		"at": _entered_from,
	}
	# A guest's arena reports its stages by count; this one counts its own.
	var partner: bool = bool(result.get("for_partner", false))
	var paid: int = int(result.get("stages", _banked.size()))
	reward["stages"] = paid
	if bool(result.get("died", false)) or paid <= 0:
		return reward
	var tier: CampaignTierData = RunState.tier()
	var tier_order: int = tier.order if tier != null else 0
	var resources: int = 0
	var shards: float = 0.0
	var gear: Array = []
	for index: int in paid:
		var stage: int = index + 1
		var weight: float = 1.0 + 0.25 * float(index)
		shards += float(Balance.RIFT_SHARDS_PER_STAGE) * weight
		var entry: Dictionary = {} if partner else _banked_stage(stage)
		if bool(entry.get("chest_opened", false)):
			# Burst on the floor already; carry out what the chest held.
			for piece: Variant in entry.get("gear", []):
				gear.append(piece)
			continue
		resources += _stage_resources(stage)
		for _piece: int in Balance.RIFT_GEAR_PER_STAGE:
			var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), tier_order,
				RunState.rng("gear"))
			if not piece.is_empty():
				gear.append(piece)
	reward["resources"] = resources
	reward["shards"] = int(round(shards))
	reward["gear"] = gear
	if kind == Kind.DUNGEON and paid >= _stages:
		reward["relic_id"] = _pick_relic()
	if not partner:
		MetaState.rifts_closed += paid
	return reward


## A reward for a partner's own rift, from the result it reported. Public so
## the run can pay a guest who went in alone. Bounded: the stages are capped
## at the dungeon's own count, so a report cannot bank more than exists.
func reward_for_partner(result: Dictionary) -> Dictionary:
	var capped: Dictionary = result.duplicate()
	capped["stages"] = clampi(int(result.get("stages", 0)), 0, Balance.DUNGEON_STAGES)
	capped["for_partner"] = true
	# The host may be inside its own rift while a guest reports: borrow the
	# arena's identity for the arithmetic and hand it straight back.
	var was_kind: Kind = kind
	var was_stages: int = _stages
	var was_from: Vector2 = _entered_from
	kind = int(result.get("kind", 0)) as Kind
	_stages = Balance.DUNGEON_STAGES if kind == Kind.DUNGEON else 1
	_entered_from = result.get("at", Vector2.ZERO)
	var reward: Dictionary = _build_rift_reward(capped)
	kind = was_kind
	_stages = was_stages
	_entered_from = was_from
	return reward


## The word for this place, for prompts and the party.
func what() -> String:
	return "dungeon" if kind == Kind.DUNGEON else "rift"


## For the HUD and the gate.
func status() -> Dictionary:
	return {
		"kind": int(kind),
		"stage": _stage,
		"stages": _stages,
		"fill": _fill,
		"time_left": maxf(Balance.RIFT_TIME_LIMIT - _stage_clock, 0.0),
		"time_limit": Balance.RIFT_TIME_LIMIT,
		"guardian_out": _guardian_out,
		"at_door": _at_door,
		"collapsing": _collapsing,
		"collapse_left": maxf(_collapse_left, 0.0),
		"collapse_seconds": Balance.DUNGEON_COLLAPSE_SECONDS,
		"kills": _kills,
		"banked": _banked.size(),
		"chest": _chest != null and is_instance_valid(_chest),
		"chest_opened": _chest != null and is_instance_valid(_chest) and _chest.is_opened(),
		"exit_open": _exit != null and is_instance_valid(_exit) and _exit.open,
	}


## Where the exit and the vault are, for the gate and the HUD compass.
func exit_position() -> Vector2:
	if _exit != null and is_instance_valid(_exit):
		return _exit.global_position
	var maze: DungeonLayout = dungeon()
	return RaidLayout.tile_to_world(maze.entry) if maze != null else Vector2.ZERO


func vault_position() -> Vector2:
	var maze: DungeonLayout = dungeon()
	return RaidLayout.tile_to_world(maze.deep) if maze != null else Vector2.ZERO
