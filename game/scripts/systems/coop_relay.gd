class_name CoopRelay
extends Node

## The one place a co-op message crosses the wire.
##
## Step 2 of `docs/COOP_DESIGN.md`. The design's §4 argument is that `EventBus`
## is already the right seam for a network boundary — its signals describe facts
## about the run rather than node plumbing, which is exactly what has to travel.
## What it has never had to carry is **authority**, and that is what this adds.
##
## Three kinds of traffic, and the split is the whole design:
##
## * **Host-authored facts** travel host → guest. The guest re-emits them on its
##   own `EventBus` so guest-side systems keep working unchanged and never learn
##   a network exists.
## * **Guest requests** travel guest → host. The host is told a request arrived
##   and answers it by authoring a fact. A guest's own UI never decides an
##   outcome.
## * **Cosmetic signals** — camera shake, sparks, sound — are **not relayed** at
##   all. Each client derives them from the facts it already has, and sending
##   them would double the traffic to reproduce something free.
##
## **One relay point, not a hundred call sites.** Nothing in the battlefield, the
## town or the beast scope is aware of any of this. That is deliberate and worth
## defending: the moment a gameplay system starts asking "am I the host" inline,
## the seam stops being a seam.
##
## Raw packets rather than `@rpc`, and not for style. An `@rpc` call resolves by
## node path and therefore needs the sender and receiver at the *same* path in
## their respective trees. The co-op harness necessarily has a host and a guest
## at different paths in one tree, so a path-bound relay could not be tested in
## process — which would throw away the property step 1 was built to have.
## `SceneMultiplayer.send_bytes` is path-independent.

## Facts the host authors and the guest mirrors. Wire values: append only,
## never renumber — an older build must not read a newer one's packet as a
## different fact.
enum Fact {
	ENEMY_DIED = 0,
	WAVE_CLEARED = 1,
	BOSS_DEFEATED = 2,
	LANE_PRESSURE = 3,
	PHASE_CHANGED = 4,
	CURRENCY_CHANGED = 5,
	TOWN_HEALTH = 6,
	HERO_STATE = 7,
	TOWER_STATE = 8,
	ENEMY_SPAWNED = 9,
	ENEMY_BATCH = 10,
	ENEMY_REMOVED = 11,
	XP_AWARDED = 12,
	RUN_STARTED = 13,
	HOST_INPUT = 14,
	WORLD_CLOCK = 15,
	PAUSED = 16,
	HERO_DOWN = 17,
	HERO_REVIVED = 18,
	TOWER_FIRED = 19,
	CINEMATIC_SKIPPED = 20,
	TEAM_WIPE = 21,
	REVIVE_PROGRESS = 22,
	TRAP_STATE = 23,
	TRAP_FIRED = 24,
}

## Things a guest may ask the host to do. Arriving is all this step promises;
## the systems that carry them out are steps 3 and 4.
enum Request {
	BUILD_TOWER = 0,
	UPGRADE_TOWER = 1,
	COMMAND_ORDER = 2,
	WAR_HORN = 3,
	RIDE_ON = 4,
	ENTER_RAID = 5,
	HERO_INPUT = 6,
	PAUSE = 7,
	SKIP_CINEMATIC = 8,
	PLACE_TRAP = 9,
}

## Facts that are *state announcements* rather than events.
##
## A machine re-stating something it already holds - the town saying how much
## health it has on the frame it is built - is not the same as claiming something
## happened. Both are host-authored and both are relayed; the difference is only
## that a guest emitting one is harmless rather than a bug, because the host's
## own value overwrites it immediately.
##
## Kept deliberately short. Everything absent from it is an event, and a guest
## originating an event is exactly what the guard exists to catch.
const ANNOUNCEMENT_FACTS: Array[int] = [Fact.TOWN_HEALTH, Fact.CURRENCY_CHANGED]

## Wire tags. A packet is `[tag, kind, args]`.
##
## A refusal is its own tag rather than a fact, because it is the one message
## addressed to a *person* rather than describing the world. It goes to the peer
## that asked and nobody else, and it carries a sentence rather than state.
const TAG_FACT: int = 0
const TAG_REQUEST: int = 1
const TAG_REFUSAL: int = 2

## The session that says whether we are the host. Assigned by `Coop` on creation.
var session: Node = null

## The event bus this relay listens to and speaks on. `EventBus` in the game.
##
## Injected rather than reached for, and the reason is not purity. Two machines
## have two buses; a harness simulating both in one process would otherwise have
## them share the single autoload, and then the host's own emissions arrive at
## the guest's relay directly — which both echoes facts back and forth forever
## and trips the guard on traffic that never crossed a wire. A test that cannot
## tell the two machines apart cannot test the thing that separates them.
var bus: Node = null

## True only while re-emitting a received fact, so the guard below can tell a
## mirrored fact from one this machine invented.
var _replaying: bool = false

## Host-authored signals seen originating on a guest. A permanent architecture
## error rather than a runtime hiccup — see `_guard`.
var _violations: PackedStringArray = []

## Reported once per fact kind. A violation usually fires every frame, and a log
## flooded with the same line is a log nobody reads.
var _reported: Dictionary = {}

## Whether a violation also goes to the error log. Always true in the game.
##
## The co-op gate provokes a violation on purpose to prove the guard catches it,
## and `guard.yml` fails any check that prints an `ERROR:` line — so a passing
## test would have broken the build to demonstrate that the build-breaking
## machinery works. The gate turns this off and asserts on `violations()`
## instead, which is the detection itself; only the logging is silenced.
var report_violations: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind_transport()
	_bind_facts()


func _bind_transport() -> void:
	var api: MultiplayerAPI = multiplayer
	var scene_api := api as SceneMultiplayer
	if scene_api == null:
		return
	# Never decode objects off the wire. A packet is data; letting it name a
	# class to instantiate turns a corrupt or hostile message into code
	# execution. It is false by default and is set here so that stays true on
	# purpose rather than by luck.
	scene_api.allow_object_decoding = false
	scene_api.peer_packet.connect(_on_packet)


## Swaps the bus this relay speaks on, dropping the old connections first.
##
## Only the co-op harness needs this: a relay is built by `Coop` and bound to
## `EventBus` before it enters the tree, so in the game the bus never changes.
## The harness gives each simulated machine its own bus and has to do so *after*
## the session exists, because the session is what creates the relay.
func rebind_bus(to: Node) -> void:
	_unbind_facts()
	bus = to
	_bind_facts()


## Subscribes to every relayed signal, on both sides.
##
## The host uses these to send. The guest uses the same connections to *watch*,
## which is what makes the guard free: no extra bookkeeping, and a violation is
## caught at the moment it happens rather than by inspection.
func _bind_facts() -> void:
	if bus == null:
		return
	for entry: Array in _fact_bindings():
		bus.connect(StringName(entry[0]), entry[1] as Callable)


func _unbind_facts() -> void:
	if bus == null:
		return
	for entry: Array in _fact_bindings():
		var name := StringName(entry[0])
		var handler := entry[1] as Callable
		if bus.is_connected(name, handler):
			bus.disconnect(name, handler)


## Every relayed signal, paired with the method that forwards it.
##
## Named methods rather than lambdas, so the same table can bind *and* unbind.
## A lambda cannot be disconnected without having kept the exact Callable, and a
## relay that can only ever attach is a relay whose bus can never be swapped.
##
## Signals absent from this table are not relayed. That is how a cosmetic signal
## stays local: by omission, with no per-call-site decision to get wrong.
func _fact_bindings() -> Array:
	return [
		["enemy_died", _on_enemy_died],
		["wave_cleared", _on_wave_cleared],
		["boss_defeated", _on_boss_defeated],
		["lane_pressure_changed", _on_lane_pressure_changed],
		["coop_phase", _on_coop_phase],
		["currency_changed", _on_currency_changed],
		["town_health_changed", _on_town_health_changed],
		["coop_hero_state", _on_coop_hero_state],
		["coop_tower_state", _on_coop_tower_state],
		["coop_enemy_spawned", _on_coop_enemy_spawned],
		["coop_enemy_batch", _on_coop_enemy_batch],
		["coop_enemy_removed", _on_coop_enemy_removed],
		["coop_xp_awarded", _on_coop_xp_awarded],
		["coop_run_started", _on_coop_run_started],
		["coop_host_input", _on_coop_host_input],
		["coop_world_clock", _on_coop_world_clock],
		["coop_paused", _on_coop_paused],
		["coop_hero_down", _on_coop_hero_down],
		["coop_hero_revived", _on_coop_hero_revived],
		["coop_tower_fired", _on_coop_tower_fired],
		["coop_cinematic_skipped", _on_coop_cinematic_skipped],
		["coop_team_wipe", _on_coop_team_wipe],
		["coop_revive_progress", _on_coop_revive_progress],
		["coop_trap_state", _on_coop_trap_state],
		["coop_trap_fired", _on_coop_trap_fired],
	]


func _on_enemy_died(id: String, at: Vector2) -> void:
	_relay(Fact.ENEMY_DIED, [id, at])


func _on_wave_cleared(wave: int) -> void:
	_relay(Fact.WAVE_CLEARED, [wave])


func _on_boss_defeated(id: String, act: int) -> void:
	_relay(Fact.BOSS_DEFEATED, [id, act])


func _on_lane_pressure_changed(lane: int, pressure: float) -> void:
	_relay(Fact.LANE_PRESSURE, [lane, pressure])


func _on_coop_phase(phase: int, previous: int) -> void:
	_relay(Fact.PHASE_CHANGED, [phase, previous])


func _on_coop_cinematic_skipped() -> void:
	_relay(Fact.CINEMATIC_SKIPPED, [])


func _on_coop_team_wipe() -> void:
	_relay(Fact.TEAM_WIPE, [])


func _on_coop_revive_progress(host_hero: bool, progress: float) -> void:
	_relay(Fact.REVIVE_PROGRESS, [host_hero, progress])


func _on_coop_trap_state(tile: Vector2i, trap_id: String, triggers_left: int) -> void:
	_relay(Fact.TRAP_STATE, [tile, trap_id, triggers_left])


func _on_coop_trap_fired(tile: Vector2i) -> void:
	_relay(Fact.TRAP_FIRED, [tile])


func _on_currency_changed(id: String, amount: int) -> void:
	_relay(Fact.CURRENCY_CHANGED, [id, amount])


func _on_town_health_changed(current: float, maximum: float) -> void:
	_relay(Fact.TOWN_HEALTH, [current, maximum])


## Hero positions are a fact like any other, and travel the same way.
##
## Worth noting because it looked at first like it needed its own send path: it
## does not. `CoopHeroes` emits this on the host's own bus and the relay forwards
## it, exactly as it forwards a death or a wave clearing. One mechanism, and the
## guard covers hero state for free - a guest that tried to author a position
## would be caught by the same check that catches a guest inventing a kill.
func _on_coop_hero_state(host_at: Vector2, host_aim: Vector2,
		guest_at: Vector2, guest_aim: Vector2) -> void:
	_relay(Fact.HERO_STATE, [host_at, host_aim, guest_at, guest_aim])


func _on_coop_tower_state(anchor: Vector2i, tower_id: String, level: int) -> void:
	_relay(Fact.TOWER_STATE, [anchor, tower_id, level])


func _on_coop_tower_fired(anchor: Vector2i, at: Vector2) -> void:
	_relay(Fact.TOWER_FIRED, [anchor, at])


func _on_coop_enemy_spawned(net_id: int, data_id: String, lane: int, at: Vector2,
		hp_scale: float, damage_scale: float, speed_scale: float) -> void:
	_relay(Fact.ENEMY_SPAWNED,
		[net_id, data_id, lane, at, hp_scale, damage_scale, speed_scale])


func _on_coop_enemy_batch(entries: Array) -> void:
	_relay(Fact.ENEMY_BATCH, [entries])


func _on_coop_enemy_removed(net_id: int) -> void:
	_relay(Fact.ENEMY_REMOVED, [net_id])


func _on_coop_xp_awarded(amount: float) -> void:
	_relay(Fact.XP_AWARDED, [amount])


func _on_coop_run_started(seed_value: int, endless: bool) -> void:
	_relay(Fact.RUN_STARTED, [seed_value, endless])


func _on_coop_host_input(snapshot: Array) -> void:
	_relay(Fact.HOST_INPUT, [snapshot])


func _on_coop_world_clock(distance: float, weather_id: String, act: int) -> void:
	_relay(Fact.WORLD_CLOCK, [distance, weather_id, act])


func _on_coop_paused(paused: bool) -> void:
	_relay(Fact.PAUSED, [paused])


func _on_coop_hero_down(host_hero: bool, at: Vector2) -> void:
	_relay(Fact.HERO_DOWN, [host_hero, at])


func _on_coop_hero_revived(host_hero: bool, at: Vector2) -> void:
	_relay(Fact.HERO_REVIVED, [host_hero, at])


# --- Sending -----------------------------------------------------------------

## A relayed signal fired locally. Forward it, or catch a guest inventing it.
func _relay(kind: Fact, args: Array) -> void:
	if _replaying:
		# This machine is mirroring a fact it was told. Sending it back would be
		# an echo, and on the guest it is also the one case where a host-authored
		# signal legitimately fires locally.
		return
	if session == null:
		return
	if not bool(session.call("is_host")):
		# A guest re-announcing state it already holds is not a guest inventing an
		# outcome, and the guard must be able to tell the two apart.
		#
		# Found in live play: the guest's town emits `town_health_changed` when the
		# battlefield builds, because a full-health town announcing itself is what
		# that signal is *for* on a single machine. The host's own value arrives a
		# moment later and overwrites it, so nothing is wrong - but the guard saw a
		# host-authored fact originating on a guest and was right to shout.
		#
		# Suppressed rather than reported, and suppressed *silently*: it must not
		# reach the wire either, because the host does not want to be told what its
		# guest's town thinks. A guest that authored something genuinely new - a
		# kill, a wave clearing, a position - is still caught, because those carry
		# information the host never sent.
		if not ANNOUNCEMENT_FACTS.has(kind):
			_guard(kind)
		return
	if not bool(session.call("partner_present")):
		# Single player, or a host nobody has joined. Nothing to tell.
		return
	_send([TAG_FACT, int(kind), args])


## Asks the host to do something. Called on the guest.
##
## Returns whether the request was *sent*, never whether it was granted — the
## answer comes back later as a fact, and a caller that treats true as success
## has reinvented the client-authority bug this whole layer exists to prevent.
func request(kind: Request, args: Array = []) -> bool:
	if session == null or not bool(session.call("is_guest")):
		return false
	return _send([TAG_REQUEST, int(kind), args])


## Tells one peer it cannot have what it asked for.
##
## Addressed rather than broadcast: the other player has no use for it, and a
## refusal shown on both screens would read as the game refusing *both* of them.
## Host side only - a guest has nobody to refuse.
func refuse(peer: int, kind: int, reason: String) -> bool:
	if session == null or not bool(session.call("is_host")):
		return false
	return _send([TAG_REFUSAL, kind, [reason]], peer)


func _send(packet: Array, to_peer: int = 0) -> bool:
	var api := multiplayer as SceneMultiplayer
	if api == null or not api.has_multiplayer_peer():
		return false
	# 0 means every peer. With two players that is the other one.
	return api.send_bytes(var_to_bytes(packet), to_peer,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE) == OK


# --- Receiving ---------------------------------------------------------------

func _on_packet(from: int, packet: PackedByteArray) -> void:
	# `allow_objects` left at its default false, deliberately and for the same
	# reason as `allow_object_decoding` above.
	var decoded: Variant = bytes_to_var(packet)
	if not (decoded is Array):
		return
	var message: Array = decoded
	if message.size() != 3 or not (message[2] is Array):
		return
	var tag: int = int(message[0])
	var kind: int = int(message[1])
	var args: Array = message[2]

	if tag == TAG_FACT:
		# Only the host authors facts. A packet claiming otherwise is either a
		# bug or something hostile, and either way it is not obeyed.
		if session != null and bool(session.call("is_host")):
			return
		_replay(kind, args)
	elif tag == TAG_REQUEST:
		if session == null or not bool(session.call("is_host")):
			return
		bus.coop_request_received.emit(kind, args, from)
	elif tag == TAG_REFUSAL:
		# Only a host refuses. A packet telling the host it was refused is either a
		# bug or something hostile, and either way it is not believed.
		if session != null and bool(session.call("is_host")):
			return
		if args.size() == 1:
			bus.coop_request_refused.emit(kind, String(args[0]))


## Re-emits a received fact on this machine's own EventBus.
##
## Guest-side systems then behave exactly as they do in single player. Every
## argument is cast to the signal's declared type rather than passed through:
## the wire carries Variants, and a float arriving where an int is declared is a
## silent mismatch that would surface far from here.
func _replay(kind: int, args: Array) -> void:
	_replaying = true
	match kind:
		Fact.ENEMY_DIED:
			if args.size() == 2:
				bus.enemy_died.emit(String(args[0]), args[1] as Vector2)
		Fact.WAVE_CLEARED:
			if args.size() == 1:
				bus.wave_cleared.emit(int(args[0]))
		Fact.BOSS_DEFEATED:
			if args.size() == 2:
				bus.boss_defeated.emit(String(args[0]), int(args[1]))
		Fact.LANE_PRESSURE:
			if args.size() == 2:
				bus.lane_pressure_changed.emit(int(args[0]), float(args[1]))
		Fact.PHASE_CHANGED:
			if args.size() == 2:
				bus.coop_phase.emit(int(args[0]), int(args[1]))
		Fact.CINEMATIC_SKIPPED:
			bus.coop_cinematic_skipped.emit()
		Fact.TEAM_WIPE:
			bus.coop_team_wipe.emit()
		Fact.REVIVE_PROGRESS:
			if args.size() == 2:
				bus.coop_revive_progress.emit(bool(args[0]), float(args[1]))
		Fact.CURRENCY_CHANGED:
			if args.size() == 2:
				bus.currency_changed.emit(String(args[0]), int(args[1]))
		Fact.TOWN_HEALTH:
			if args.size() == 2:
				bus.town_health_changed.emit(float(args[0]), float(args[1]))
		Fact.HERO_STATE:
			if args.size() == 4:
				bus.coop_hero_state.emit(args[0] as Vector2, args[1] as Vector2,
					args[2] as Vector2, args[3] as Vector2)
		Fact.TRAP_STATE:
			if args.size() == 3:
				bus.coop_trap_state.emit(args[0] as Vector2i, String(args[1]),
					int(args[2]))
		Fact.TRAP_FIRED:
			if args.size() == 1:
				bus.coop_trap_fired.emit(args[0] as Vector2i)
		Fact.TOWER_FIRED:
			if args.size() == 2:
				bus.coop_tower_fired.emit(args[0] as Vector2i, args[1] as Vector2)
		Fact.TOWER_STATE:
			if args.size() == 3:
				bus.coop_tower_state.emit(args[0] as Vector2i, String(args[1]),
					int(args[2]))
		Fact.ENEMY_SPAWNED:
			if args.size() == 7:
				bus.coop_enemy_spawned.emit(int(args[0]), String(args[1]),
					int(args[2]), args[3] as Vector2, float(args[4]),
					float(args[5]), float(args[6]))
		Fact.ENEMY_BATCH:
			if args.size() == 1 and args[0] is Array:
				bus.coop_enemy_batch.emit(args[0] as Array)
		Fact.ENEMY_REMOVED:
			if args.size() == 1:
				bus.coop_enemy_removed.emit(int(args[0]))
		Fact.XP_AWARDED:
			if args.size() == 1:
				bus.coop_xp_awarded.emit(float(args[0]))
		Fact.RUN_STARTED:
			if args.size() == 2:
				bus.coop_run_started.emit(int(args[0]), bool(args[1]))
		Fact.HOST_INPUT:
			if args.size() == 1 and args[0] is Array:
				bus.coop_host_input.emit(args[0] as Array)
		Fact.WORLD_CLOCK:
			if args.size() == 3:
				bus.coop_world_clock.emit(float(args[0]), String(args[1]), int(args[2]))
		Fact.PAUSED:
			if args.size() == 1:
				bus.coop_paused.emit(bool(args[0]))
		Fact.HERO_DOWN:
			if args.size() == 2:
				bus.coop_hero_down.emit(bool(args[0]), args[1] as Vector2)
		Fact.HERO_REVIVED:
			if args.size() == 2:
				bus.coop_hero_revived.emit(bool(args[0]), args[1] as Vector2)
	_replaying = false


# --- The guard ---------------------------------------------------------------

## A host-authored fact originated on a guest.
##
## This is the invariant the whole layer rests on, and it cannot be enforced by
## review alone — it only has to be broken once, in one system, for the two
## machines to start disagreeing about what happened. Catching it at the moment
## of emission names the signal instead of leaving a desync to be explained
## later.
##
## Recorded rather than thrown. A guest that mistakenly emits `enemy_died` is
## wrong, but crashing the run in front of two players is worse than a loud log
## and a gate that fails on the next push.
func _guard(kind: Fact) -> void:
	if session == null or not bool(session.call("is_guest")):
		return
	var name: String = Fact.keys()[int(kind)]
	_violations.append(name)
	if not report_violations or _reported.has(name):
		return
	_reported[name] = true
	push_error("[coop] a guest originated the host-authored fact %s. "
		% name + "Only the host may author this; see docs/COOP_DESIGN.md §4.")


## Every violation seen, for the gate. Empty is the only correct answer.
func violations() -> PackedStringArray:
	return _violations


## True while mirroring, for tests that need to tell the two cases apart.
func is_replaying() -> bool:
	return _replaying
