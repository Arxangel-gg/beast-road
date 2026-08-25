class_name CoopWorld
extends Node

## Enemies and towers, made to agree on two machines.
##
## Step 4 of `docs/COOP_DESIGN.md`. The host simulates; the guest is shown what
## happened. Two very different problems wearing one name:
##
## **Towers are almost free.** `battlefield.gd` rebuilds every tower node from
## `RunState` whenever `tower_changed` fires — building, selling, upgrading and
## a fusion being refunded all arrive through that one signal. So a guest that is
## told "there is a level 2 Ember Spire at (3, 4)" writes it to its own RunState
## and the tower appears, upgrades or vanishes with no tower-specific network code
## at all. That was already the right design before co-op existed; it just paid.
##
## **Enemies are not.** There are up to fifty of them, they move every frame, and
## they have identity that has to survive a wire. They are mirrored as puppets:
## spawned on announcement, moved in a periodic batch, removed on command. A
## puppet decides nothing — see `Enemy.puppet`.
##
## Inert in a single-player run, like `CoopHeroes`. A system that only exists in
## co-op is a system that only gets exercised in co-op.

## How often the enemy batch goes out, in seconds. [TUNE]
##
## Slower than the heroes' rate on purpose. There is one hero per player and up
## to fifty enemies, so this is the packet that decides whether co-op is playable
## on a domestic connection. Enemies walk in near-straight lines at a known
## speed, which is exactly the motion a lower rate hides best.
const BATCH_INTERVAL: float = 0.1

## How often the world clock goes out, in seconds. [TUNE]
##
## Far slower than the bodies, because none of it moves quickly: distance walked,
## the weather, the act. Time of day is *derived* from distance, so sending the
## distance keeps both skies in step without replicating the derivation - and
## keeps the difficulty in step too, since night raises the wave budget.
const CLOCK_INTERVAL: float = 0.5

var field: Node = null

var _batch_timer: float = 0.0
var _clock_timer: float = 0.0

## Host side: the next identity to hand out. Starts at 1 so 0 keeps meaning
## "nobody announced this", which is every enemy in a single-player run.
var _next_net_id: int = 1

## Guest side: puppets by the identity the host gave them.
var _puppets: Dictionary = {}

## Host side: every identity handed out and not yet reported gone.
##
## Removals are worked out by comparing this against what is alive, rather than
## by hooking the death path. That keeps `Enemy` free of any knowledge that a
## network exists - working rule 5 - and it catches every way an enemy can leave
## at once: killed, dismissed with its summoner, or freed with the scope.
##
## Note this is the *host* comparing its own authoritative view against itself,
## which is safe. A guest deleting anything missing from an arriving packet would
## be quite different, and would empty the field the first time one arrived late.
var _announced: Dictionary = {}


func _ready() -> void:
	EventBus.coop_tower_state.connect(_on_tower_state)
	EventBus.coop_enemy_spawned.connect(_on_enemy_spawned)
	EventBus.coop_enemy_batch.connect(_on_enemy_batch)
	EventBus.coop_enemy_removed.connect(_on_enemy_removed)
	EventBus.coop_request_received.connect(_on_request)
	EventBus.tower_changed.connect(_on_tower_changed)
	EventBus.coop_state_changed.connect(_on_session_changed)
	EventBus.coop_world_clock.connect(_on_world_clock)
	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.coop_phase.connect(_on_coop_phase)
	EventBus.trap_changed.connect(_on_trap_changed)
	EventBus.coop_trap_state.connect(_on_coop_trap_state)
	EventBus.trap_triggered.connect(_on_trap_triggered)
	EventBus.coop_trap_fired.connect(_on_coop_trap_fired)
	EventBus.barricade_changed.connect(_on_barricade_changed)
	EventBus.coop_barricade_state.connect(_on_coop_barricade_state)
	EventBus.coop_loot_spawned.connect(_on_coop_loot_spawned)
	EventBus.coop_loot_taken.connect(_on_coop_loot_taken)
	EventBus.coop_tower_fired.connect(_on_coop_tower_fired)
	# Same reasoning as `CoopHeroes`: the session is established in the menu,
	# so a system built with the battlefield has already missed every signal
	# announcing it. Nothing to spawn here, but the identity counter must not
	# carry over from a previous session on the same machine.
	if not Coop.is_networked():
		_puppets.clear()
		_announced.clear()


## Hands an enemy its identity and announces it. Host side, called on spawn.
##
## Returns the id so the caller can hold it; zero when there is nobody to tell,
## which keeps a single-player run from numbering things nobody asked about.
func announce_enemy(enemy: Enemy) -> int:
	if enemy == null or not _is_authority_with_company():
		return 0
	enemy.net_id = _next_net_id
	_next_net_id += 1
	_announced[enemy.net_id] = true
	EventBus.coop_enemy_spawned.emit(enemy.net_id, enemy.data.id, enemy.lane,
		enemy.global_position, enemy.hp_scale(), enemy.damage_scale(),
		enemy.speed_scale())
	return enemy.net_id


## Reports everything that has left since the last batch. Host side.
func _retire_missing(living: Dictionary) -> void:
	var gone: Array = []
	for net_id: Variant in _announced:
		if not living.has(net_id):
			gone.append(net_id)
	for net_id: Variant in gone:
		_announced.erase(net_id)
		EventBus.coop_enemy_removed.emit(int(net_id))


func _physics_process(delta: float) -> void:
	if not _is_authority_with_company():
		return
	_clock_timer -= delta
	if _clock_timer <= 0.0:
		_clock_timer = CLOCK_INTERVAL
		EventBus.coop_world_clock.emit(RunState.distance_travelled,
			RunState.weather_id, RunState.act)
	_batch_timer -= delta
	if _batch_timer > 0.0:
		return
	_batch_timer = BATCH_INTERVAL
	_send_batch()


## Everything alive, in one packet.
##
## One message rather than one per enemy: fifty small packets a tick is fifty
## chances to be reordered and fifty headers, to describe a crowd that moves
## together. Health rides along because a health bar that lags behind a death is
## worse than no health bar.
func _send_batch() -> void:
	var entries: Array = []
	var living: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.net_id == 0 or enemy.is_dying():
			continue
		living[enemy.net_id] = true
		# The state rides along with the position, and it has to. A wind-up is
		# the telegraph the whole dodge window is built on - an enemy that
		# mirrors its position but not the fact that it is about to strike gives
		# the guest no warning at all, and the guest is playing a different game.
		entries.append([enemy.net_id, enemy.global_position, enemy.health_ratio(),
			enemy.combat_state()])
	# Retirements first. A guest that is told where something is and then that it
	# is gone, in that order, never draws a corpse at a stale position.
	_retire_missing(living)
	if entries.is_empty():
		return
	EventBus.coop_enemy_batch.emit(entries)


# --- Guest side --------------------------------------------------------------

func _on_enemy_spawned(net_id: int, data_id: String, lane: int, at: Vector2,
		hp_scale: float, damage_scale: float, speed_scale: float) -> void:
	if not Coop.is_guest() or _puppets.has(net_id):
		return
	var battlefield := field as Battlefield
	if battlefield == null:
		return
	var enemy: Enemy = battlefield.spawn_enemy(ContentDB.enemy(data_id), lane,
		hp_scale, damage_scale, speed_scale)
	if enemy == null:
		return
	enemy.net_id = net_id
	# Set before the first frame so nothing simulates even once. A puppet that
	# picks a target on its first tick has already disagreed with the host.
	enemy.puppet = true
	enemy.set_mirror_interval(BATCH_INTERVAL)
	enemy.global_position = at
	_puppets[net_id] = enemy


func _on_enemy_batch(entries: Array) -> void:
	if not Coop.is_guest():
		return
	for entry: Variant in entries:
		if not (entry is Array):
			continue
		var row: Array = entry
		if row.size() < 3:
			continue
		var enemy: Enemy = _puppets.get(int(row[0]), null) as Enemy
		if enemy != null and is_instance_valid(enemy):
			enemy.mirror(row[1] as Vector2, float(row[2]),
				int(row[3]) if row.size() > 3 else -1)


func _on_enemy_removed(net_id: int) -> void:
	if not Coop.is_guest():
		return
	var enemy: Enemy = _puppets.get(net_id, null) as Enemy
	_puppets.erase(net_id)
	if enemy != null and is_instance_valid(enemy):
		# Dismissed rather than freed, so it fades like anything else that dies.
		# The payout is skipped for the same reason `dismiss` exists at all: the
		# host already paid, and a guest paying again doubles a shared purse.
		enemy.dismiss()


## The sky, the weather and how far the beast has walked.
##
## Distance is written straight into `RunState` rather than announced, because
## `DayNight` already derives the time of day from it - so one number keeps both
## machines' light, tint, night flag and night difficulty bonus identical without
## any of that being replicated separately.
##
## The weather is re-announced only when it actually changes. It arrives twice a
## second and `weather_changed` starts a three-second fade, so emitting it every
## time would restart the fade forever and the rain would never arrive.
func _on_world_clock(distance: float, weather_id: String, act: int) -> void:
	if not Coop.is_guest():
		return
	RunState.distance_travelled = distance
	RunState.act = act
	EventBus.distance_changed.emit(distance, RunState.distance_to_crossroad())
	if weather_id != RunState.weather_id:
		RunState.weather_id = weather_id
		EventBus.weather_changed.emit(weather_id)


## A tower appeared, changed tier or went away, on the host's say-so.
func _on_tower_state(anchor: Vector2i, tower_id: String, level: int) -> void:
	if not Coop.is_guest():
		return
	if tower_id.is_empty():
		RunState.clear_tower(anchor)
	else:
		RunState.set_tower(anchor, tower_id, level)
	# The battlefield rebuilds its tower nodes off that write, so the new one
	# exists by the time this returns and has to be told it does not decide.
	_mark_puppet_towers()


## Every tower on a guest is a puppet.
##
## Told rather than asked, and told here rather than in `Tower._ready`, for the
## same reason `Enemy` carries a flag somebody else sets: a tower that looked up
## the session itself would be a gameplay node that knows a network exists, and
## the seam stops being a seam the moment one of them does.
func _mark_puppet_towers() -> void:
	if not Coop.is_guest():
		return
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower != null:
			tower.puppet = true


## This machine's own run changed phase. Host side.
func _on_phase_changed(phase: int, previous: int) -> void:
	if not _is_authority_with_company():
		return
	EventBus.coop_phase.emit(phase, previous)


## The host's run changed phase, so this one does too. Guest side.
##
## Written into `RunState` rather than merely announced, which is the bug play
## found: the relay used to re-emit `phase_changed` straight onto the guest's
## bus, so every listener heard that combat had begun while `RunState.phase`
## still said Preparation. `can_build_now()` reads the phase, so the guest sat in
## build mode through a wave the host had already started.
##
## `set_phase` emits the guest's own `phase_changed` as a consequence of the
## write, exactly as it does on a machine playing alone - so guest-side systems
## still never learn a network exists.
func _on_coop_phase(phase: int, _previous: int) -> void:
	if not Coop.is_guest():
		return
	RunState.set_phase(phase as RunState.Phase)


## The host dropped a coin, so one appears here too. Guest side.
func _on_coop_loot_spawned(net_id: int, currency: String, amount: int,
		at: Vector2) -> void:
	if not Coop.is_guest():
		return
	var battlefield := field as Battlefield
	if battlefield != null:
		battlefield.mirror_loot(net_id, currency, amount, at)


## The host says that coin was picked up. Guest side.
func _on_coop_loot_taken(net_id: int) -> void:
	if not Coop.is_guest():
		return
	var battlefield := field as Battlefield
	if battlefield != null:
		battlefield.take_mirrored_loot(net_id)


## This machine's own barricades changed. Host side.
##
## Health travels as a *fraction* rather than an absolute, so a guest rebuilds
## against its own `max_hp` and the two cannot drift if the resource is retuned.
func _on_barricade_changed(tile: Vector2i) -> void:
	if not _is_authority_with_company():
		return
	var data: BarricadeData = RunState.barricade_at(tile)
	EventBus.coop_barricade_state.emit(tile, data.id if data != null else "",
		RunState.barricade_health(tile))


## A barricade was raised, worn down or broken, on the host's say-so. Guest side.
func _on_coop_barricade_state(tile: Vector2i, barricade_id: String,
		health: float) -> void:
	if not Coop.is_guest():
		return
	if barricade_id.is_empty():
		RunState.clear_barricade(tile)
	else:
		RunState.set_barricade(tile, barricade_id, health)


## This machine's own traps changed. Host side.
##
## The same shape the towers use, and free for the same reason: the battlefield
## rebuilds its trap nodes from `RunState` on one signal, so a guest told what is
## laid where writes it and the node follows.
func _on_trap_changed(tile: Vector2i) -> void:
	if not _is_authority_with_company():
		return
	var data: TrapData = RunState.trap_at(tile)
	EventBus.coop_trap_state.emit(tile, data.id if data != null else "",
		RunState.trap_triggers_left(tile))


## A trap was laid, spent or cleared, on the host's say-so. Guest side.
func _on_coop_trap_state(tile: Vector2i, trap_id: String, triggers_left: int) -> void:
	if not Coop.is_guest():
		return
	if trap_id.is_empty():
		RunState.clear_trap(tile)
	else:
		RunState.set_trap(tile, trap_id, triggers_left)


## One of this machine's traps went off. Host side.
func _on_trap_triggered(tile: Vector2i, _trap_id: String, _left: int) -> void:
	if not _is_authority_with_company():
		return
	EventBus.coop_trap_fired.emit(tile)


## The host's trap went off, so ours draws it. Guest side.
func _on_coop_trap_fired(tile: Vector2i) -> void:
	if not Coop.is_guest():
		return
	for node: Node in get_tree().get_nodes_in_group(Trap.GROUP):
		var trap := node as Trap
		if trap != null and trap.tile == tile:
			trap.fire()
			return


## This machine's own tower took a shot. Host side.
##
## Relayed as a fact rather than left for each machine to derive, because it
## cannot be derived: cooldowns, target priority and the closeness tie-break all
## run against positions that are a batch old on the guest, so two machines
## acquiring independently pick different enemies at different moments. Cheap to
## send - a shot is a plot and a point, and towers fire far less often than
## enemies move.
func _on_tower_fired(anchor: Vector2i, at: Vector2) -> void:
	if not _is_authority_with_company():
		return
	EventBus.coop_tower_fired.emit(anchor, at)


## The host's tower fired, so ours does too. Guest side.
func _on_coop_tower_fired(anchor: Vector2i, at: Vector2) -> void:
	if not Coop.is_guest():
		return
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower != null and tower.anchor == anchor:
			tower.fire_remote(at)
			return


## Forwards this machine's own tower changes. Host side.
func _on_tower_changed(anchor: Vector2i) -> void:
	if not _is_authority_with_company():
		return
	var data: TowerData = RunState.tower_at(anchor)
	EventBus.coop_tower_state.emit(anchor, data.id if data != null else "",
		RunState.level_at(anchor))


func _on_session_changed(state: int) -> void:
	if state == Coop.State.OFFLINE or state == Coop.State.FAILED:
		_puppets.clear()
		_announced.clear()


# --- Requests ----------------------------------------------------------------

## A guest asked to build. Host side.
##
## Validated through `Battlefield.try_build` — the *same* function a local click
## goes through, not a copy of its rules. A second implementation of "may this be
## built here" would be a second answer, and the two would diverge the first time
## either changed. The refusal string it returns is already written for a player
## to read, so it travels back as-is.
func _on_request(kind: int, args: Array, from: int) -> void:
	if not Coop.is_host():
		return
	var battlefield := field as Battlefield
	if battlefield == null:
		return
	match kind:
		CoopRelay.Request.BUILD_TOWER:
			if args.size() == 2:
				_answer(from, kind, battlefield.try_build(args[0] as Vector2i,
					ContentDB.tower(String(args[1]))))
		CoopRelay.Request.UPGRADE_TOWER:
			if args.size() == 1:
				_answer(from, kind, battlefield.try_upgrade(args[0] as Vector2i))
		CoopRelay.Request.PLACE_TRAP:
			if args.size() == 2:
				_answer(from, kind, battlefield.try_place_trap(args[0] as Vector2i,
					ContentDB.trap(String(args[1]))))
		CoopRelay.Request.RAISE_BARRICADE:
			if args.size() == 2:
				_answer(from, kind, battlefield.try_raise_barricade(
					args[0] as Vector2i, ContentDB.barricade(String(args[1]))))


## Tells one peer why it did not get what it asked for.
##
## Only on refusal. A grant needs no reply: it produces facts - a tower appearing,
## a wallet dropping - and those are already on their way. Acknowledging success
## separately would mean two messages saying the same thing, and a guest that
## believed the acknowledgement over the facts would be trusting itself again.
func _answer(peer: int, kind: int, refusal: String) -> void:
	if refusal.is_empty():
		return
	var relay: CoopRelay = Coop.relay()
	if relay != null:
		relay.refuse(peer, kind, refusal)


## True when this machine decides things *and* somebody is listening.
##
## Both halves matter. A guest must never author these, and a host playing alone
## has nobody to tell - so a single-player run pays one boolean per frame and
## sends nothing.
func _is_authority_with_company() -> bool:
	return Coop.is_host() and Coop.partner_present()
