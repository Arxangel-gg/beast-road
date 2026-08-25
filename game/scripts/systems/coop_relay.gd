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
}

## Wire tags. A packet is `[tag, kind, args]`.
const TAG_FACT: int = 0
const TAG_REQUEST: int = 1

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
		["phase_changed", _on_phase_changed],
		["currency_changed", _on_currency_changed],
		["town_health_changed", _on_town_health_changed],
	]


func _on_enemy_died(id: String, at: Vector2) -> void:
	_relay(Fact.ENEMY_DIED, [id, at])


func _on_wave_cleared(wave: int) -> void:
	_relay(Fact.WAVE_CLEARED, [wave])


func _on_boss_defeated(id: String, act: int) -> void:
	_relay(Fact.BOSS_DEFEATED, [id, act])


func _on_lane_pressure_changed(lane: int, pressure: float) -> void:
	_relay(Fact.LANE_PRESSURE, [lane, pressure])


func _on_phase_changed(phase: int, previous: int) -> void:
	_relay(Fact.PHASE_CHANGED, [phase, previous])


func _on_currency_changed(id: String, amount: int) -> void:
	_relay(Fact.CURRENCY_CHANGED, [id, amount])


func _on_town_health_changed(current: float, maximum: float) -> void:
	_relay(Fact.TOWN_HEALTH, [current, maximum])


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


func _send(packet: Array) -> bool:
	var api := multiplayer as SceneMultiplayer
	if api == null or not api.has_multiplayer_peer():
		return false
	# 0 means every peer. With two players that is the other one.
	return api.send_bytes(var_to_bytes(packet), 0,
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
				bus.phase_changed.emit(int(args[0]), int(args[1]))
		Fact.CURRENCY_CHANGED:
			if args.size() == 2:
				bus.currency_changed.emit(String(args[0]), int(args[1]))
		Fact.TOWN_HEALTH:
			if args.size() == 2:
				bus.town_health_changed.emit(float(args[0]), float(args[1]))
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
