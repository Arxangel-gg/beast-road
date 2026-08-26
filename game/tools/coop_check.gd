extends Node

## Stands a co-op host and guest up in one process and makes them shake hands.
##
##   godot --headless --path game res://tools/coop_check.tscn
##
## The wire, for every step that uses it: the transport and session state machine
## (step 1), the relay layer over it (step 2), and that the hero, enemy and tower
## messages of steps 3 and 4 arrive intact. What those messages *mean* is checked
## in `coop_heroes_check.tscn` and `coop_world_check.tscn`, which need a real Run
## and have nothing to say about sockets.
##
## The row that matters most is `_test_a_guest_cannot_author_a_fact`. Everything
## else here would still look fine if the authority model were quietly broken;
## that one is the invariant the whole design rests on, and it only has to fail
## once in one system for two machines to start disagreeing about what happened.
##
## **Why this can exist at all.** A `MultiplayerAPI` is registered against a
## subtree path rather than being one global thing, so two of them can live in
## one process. `Coop` reads its own `multiplayer` property for exactly this
## reason: parent a Coop under a subtree with its own API and it uses that one.
## Without that, testing co-op would need two machines and would therefore never
## happen on a push.
##
## The loopback is real. This opens a real port, dials it over 127.0.0.1 and
## waits for ENet to complete a real handshake — it is not a mock. If the port
## is busy the run says so rather than passing quietly.

## Kept away from `Balance.COOP_PORT` on purpose. The gate must not fail because
## the developer happens to be hosting a game on the default port at the time.
const TEST_PORT: int = 45879

## Frames to wait for something that involves the network. Generous: a loopback
## handshake is fast, but a loaded CI box is not, and a flaky gate is worse than
## no gate.
const NETWORK_FRAMES: int = 240

var _failures: int = 0

var _host_root: Node = null
var _guest_root: Node = null
var _host: Node = null
var _guest: Node = null

## One event bus per simulated machine. See `_build_two_sessions`.
var _host_bus: Node = null
var _guest_bus: Node = null

## What each side heard, recorded from its own bus.
var _guest_heard: Array = []
var _host_heard: Array = []
var _host_requests: Array = []
var _guest_world: Array = []
var _guest_refusals: Array = []

## Signals seen, recorded from the callbacks rather than inferred afterwards.
## Members rather than captured locals: a GDScript lambda captures a local **by
## value**, so `connected = true` inside one updates a copy and the outer
## variable never moves. That mistake reads as "the handshake failed" while the
## logs plainly show it succeeded.
var _joined_peers: Array[int] = []
var _left_peers: Array[int] = []
var _failure_reasons: PackedStringArray = []


func _ready() -> void:
	EventBus.coop_partner_joined.connect(func(id: int) -> void: _joined_peers.append(id))
	EventBus.coop_partner_left.connect(func(id: int) -> void: _left_peers.append(id))
	EventBus.coop_failed.connect(func(why: String) -> void: _failure_reasons.append(why))

	_build_two_sessions()
	_test_the_shipping_singleton()
	await _test_offline_is_its_own_authority()
	await _test_host_and_join()
	await _test_partner_and_player_count()
	await _test_facts_travel_host_to_guest()
	await _test_a_guest_cannot_author_a_fact()
	await _test_requests_travel_guest_to_host()
	await _test_cosmetic_signals_stay_home()
	await _test_world_facts_cross_the_wire()
	await _test_a_refusal_is_addressed()
	await _test_a_dropped_host_ends_the_guest_run()
	await _test_guest_leaves_cleanly()
	await _test_a_bad_address_fails_instead_of_hanging()
	_test_a_code_survives_the_round_trip()
	await _test_a_beacon_is_heard()
	_test_the_public_list_is_not_trusted()
	_test_webrtc_is_actually_available()
	_test_both_kinds_of_code_are_offered()

	_tear_down()
	for _f: int in 4:
		await get_tree().process_frame
	if _failures == 0:
		print("[coop] PASS - handshake, relayed facts, the authority guard, "
			+ "requests and refusals, world facts, cosmetic isolation, "
			+ "host drop, clean leave, dead address")
	get_tree().quit(_failures)


## Two independent sessions, each with its own MultiplayerAPI.
func _build_two_sessions() -> void:
	var script: GDScript = load("res://autoload/Coop.gd") as GDScript

	_host_root = Node.new()
	_host_root.name = "CoopHostRoot"
	add_child(_host_root)
	_guest_root = Node.new()
	_guest_root.name = "CoopGuestRoot"
	add_child(_guest_root)

	# Registered against the subtree *before* the Coop nodes enter it, so their
	# `_ready` binds to the right API rather than to the default one.
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(),
		_host_root.get_path())
	get_tree().set_multiplayer(MultiplayerAPI.create_default_interface(),
		_guest_root.get_path())

	# A bus each. Two machines have two event buses, and sharing the one autoload
	# between the simulated pair would make the host's own emissions arrive at the
	# guest's relay without ever crossing a wire — echoing facts back and forth
	# and tripping the guard on local traffic. `CoopRelay.bus` is injectable for
	# exactly this reason.
	var bus_script: GDScript = load("res://autoload/EventBus.gd") as GDScript
	_host_bus = Node.new()
	_host_bus.name = "HostBus"
	_host_bus.set_script(bus_script)
	_host_root.add_child(_host_bus)
	_guest_bus = Node.new()
	_guest_bus.name = "GuestBus"
	_guest_bus.set_script(bus_script)
	_guest_root.add_child(_guest_bus)

	_host = Node.new()
	_host.name = "Coop"
	_host.set_script(script)
	_host_root.add_child(_host)
	_rebind_relay(_host, _host_bus)

	_guest = Node.new()
	_guest.name = "Coop"
	_guest.set_script(script)
	_guest_root.add_child(_guest)
	_rebind_relay(_guest, _guest_bus)


## Points a session's relay at this side's own bus.
##
## The relay binds in `_ready`, and `_ready` has already run by the time
## `add_child` returns — so the relay is holding the real `EventBus` autoload.
## Replacing it here means dropping the old connections and binding again, which
## is why `_bind_facts` had to be safe to call twice.
func _rebind_relay(session: Node, bus: Node) -> void:
	var relay: CoopRelay = session.call("relay")
	if relay == null:
		_check(false, "a session must build its relay on ready")
		return
	relay.rebind_bus(bus)
	# The guard test provokes a real violation to prove it is caught, and
	# `guard.yml` fails any check that prints an ERROR line. Only the logging is
	# silenced; `violations()` still records, and that is what is asserted.
	relay.report_violations = false


## The autoload — the instance the game actually ships with.
##
## Everything else here drives Coop nodes parented under custom-API subtrees,
## which is what makes a two-sided test possible but is *not* the path a player
## takes. The singleton binds to the tree's default `MultiplayerAPI`, and a
## registration mistake there would leave every check below passing against an
## object no running game ever touches.
##
## Deliberately does not open a port. Setting a peer on the default API changes
## the whole tree's networking for the rest of the process, and this gate has no
## business doing that to prove the autoload exists.
func _test_the_shipping_singleton() -> void:
	_check(Coop != null, "the Coop autoload must be registered")
	_check(Coop.state() == Coop.State.OFFLINE,
		"the shipping session must start offline")
	_check(Coop.is_host() and not Coop.is_guest(),
		"a player who has not opened a session is their own authority")
	_check(not Coop.is_networked(), "and is not networked")
	_check(Coop.player_count() == 1, "and counts as one player")
	_check(Coop.multiplayer == get_tree().get_multiplayer(),
		"the autoload must bind to the tree's default API, not a subtree's")


## A single player is the authority over their own run.
##
## This matters more than it looks. Every downstream "may I do this" check will
## ask `is_host()`, and if that answered false offline, the single-player path
## would be a different branch from the co-op one — the branch nobody exercises,
## which is the branch that rots.
func _test_offline_is_its_own_authority() -> void:
	_check(_host.state() == _host.State.OFFLINE, "a fresh session must be OFFLINE")
	_check(_host.is_host(), "a single player must be their own authority")
	_check(not _host.is_guest(), "a single player is not a guest")
	_check(not _host.is_networked(), "a single player is not networked")
	_check(_host.player_count() == 1, "a single player must count as one")
	await get_tree().process_frame


func _test_host_and_join() -> void:
	_check(_host.host(TEST_PORT), "hosting on a free port must succeed (%s)" % _host.last_error)
	_check(_host.state() == _host.State.HOSTING, "a host must report HOSTING")
	_check(_host.is_host() and not _host.is_guest(), "a host is the host")
	_check(_host.is_networked(), "a host is networked even before anyone arrives")
	_check(_host.player_count() == 1,
		"an empty host must still balance for one: nobody has arrived yet")

	# There was a check here that a second server could not take the port. It was
	# removed rather than kept: the guest connecting below already proves the
	# host was listening, and provoking ENet into refusing a bind prints an
	# engine-level error to stderr. The guard workflow fails a gate on any error
	# line, so a passing test would have broken the build to assert something the
	# next four lines assert anyway.
	_check(_guest.join("127.0.0.1", TEST_PORT),
		"dialling a live host must start (%s)" % _guest.last_error)
	_check(_guest.state() == _guest.State.CONNECTING,
		"a dial in flight must report CONNECTING, not success")

	await _settle(func() -> bool: return _guest.state() == _guest.State.CONNECTED)
	_check(_guest.state() == _guest.State.CONNECTED,
		"the guest must connect over loopback")
	_check(_guest.is_guest() and not _guest.is_host(),
		"a guest must not claim authority")


func _test_partner_and_player_count() -> void:
	await _settle(func() -> bool: return _host.partner_present())
	_check(_host.partner_present(), "the host must see the guest arrive")
	_check(_guest.partner_present(), "the guest must see the host")
	_check(_host.player_count() == 2, "a joined pair must balance for two")
	_check(_guest.player_count() == 2, "and both sides must agree on that")
	_check(not _joined_peers.is_empty(),
		"coop_partner_joined must have been emitted for the arrival")


## A fact the host authors must arrive on the guest, intact.
##
## "Intact" is the part that matters and the part a looser test would miss. The
## wire carries Variants, so a float arriving where the signal declares an int
## is a mismatch that would surface a long way from here — the arguments are
## compared by value, not merely counted.
func _test_facts_travel_host_to_guest() -> void:
	_listen(_guest_bus, _guest_heard)
	_listen(_host_bus, _host_heard)

	_host_bus.enemy_died.emit("bogkin", Vector2(120.0, -40.0))
	_host_bus.wave_cleared.emit(7)
	_host_bus.currency_changed.emit("gold", 315)
	await _settle(func() -> bool: return _guest_heard.size() >= 3)

	_check(_heard(_guest_heard, "enemy_died", ["bogkin", Vector2(120.0, -40.0)]),
		"the guest must receive enemy_died with its arguments unchanged")
	_check(_heard(_guest_heard, "wave_cleared", [7]),
		"the guest must receive wave_cleared")
	_check(_heard(_guest_heard, "currency_changed", ["gold", 315]),
		"the guest must receive currency_changed: the pool is shared")

	# And the host does not hear its own traffic come back. An echo would double
	# every kill and every payment.
	_check(_count(_host_heard, "enemy_died") == 1,
		"the host must not receive an echo of the fact it authored")


## The invariant the whole layer rests on.
##
## `docs/COOP_DESIGN.md` §4: the guest must never originate a host-authored
## fact. It only has to happen once, in one system, for the two machines to
## start disagreeing about what happened — and the resulting desync would be
## debugged nowhere near the line that caused it. The relay catches it at the
## moment of emission and names the signal.
func _test_a_guest_cannot_author_a_fact() -> void:
	var guest_relay: CoopRelay = _guest.call("relay")
	var before: int = _guest_heard.size()
	_check(guest_relay.violations().is_empty(),
		"nothing legitimate so far may have counted as a violation")

	# A guest-side system misbehaving. Deliberately the same signal the host
	# authored above, so the test cannot pass by the guard simply rejecting
	# everything.
	_guest_bus.enemy_died.emit("bogkin", Vector2.ZERO)
	await get_tree().process_frame

	_check(guest_relay.violations().has("ENEMY_DIED"),
		"a guest authoring enemy_died must be caught and named")
	await _settle_frames(6)
	_check(_count(_host_heard, "enemy_died") == 1,
		"and it must not reach the host: a guest cannot tell the host what happened")

	# Mirrored facts must not be mistaken for invented ones, or the guard would
	# fire on every single relayed message and be worthless.
	_host_bus.wave_cleared.emit(8)
	await _settle(func() -> bool: return _guest_heard.size() > before + 1)
	_check(not guest_relay.violations().has("WAVE_CLEARED"),
		"a fact the guest was *told* must not be counted as one it invented")


## A request travels the other way, and stays a request.
func _test_requests_travel_guest_to_host() -> void:
	_host_bus.coop_request_received.connect(
		func(kind: int, args: Array, from: int) -> void:
			_host_requests.append([kind, args, from]))

	var guest_relay: CoopRelay = _guest.call("relay")
	_check(guest_relay.request(CoopRelay.Request.BUILD_TOWER, [Vector2i(3, 4), "ember_spire"]),
		"a guest must be able to ask the host to build")
	await _settle(func() -> bool: return not _host_requests.is_empty())

	_check(not _host_requests.is_empty(), "the request must reach the host")
	if not _host_requests.is_empty():
		var got: Array = _host_requests[0]
		_check(int(got[0]) == CoopRelay.Request.BUILD_TOWER,
			"the host must see which request it was")
		_check((got[1] as Array).size() == 2 and (got[1] as Array)[0] == Vector2i(3, 4),
			"and its arguments, unchanged")
		_check(int(got[2]) > 0, "and who asked, so it can answer them")

	# The host cannot issue requests: it has nobody to ask.
	var host_relay: CoopRelay = _host.call("relay")
	_check(not host_relay.request(CoopRelay.Request.WAR_HORN),
		"a host must not send itself a request")


## Cosmetic signals stay on the machine that raised them.
##
## Each client can derive a screen shake from the facts it already has. Relaying
## them would double the traffic to reproduce something free — and this is
## enforced by *omission* from the relay's table, so there is no per-call-site
## decision anywhere to get wrong.
func _test_cosmetic_signals_stay_home() -> void:
	var before: int = _guest_heard.size()
	_host_bus.camera_shake_requested.emit(22.0, 1.2)
	_host_bus.hero_dashed.emit(0.3)
	await _settle_frames(8)
	_check(_guest_heard.size() == before,
		"cosmetic signals must not cross the wire, got %d new"
			% (_guest_heard.size() - before))


## The step 4 traffic: enemies and towers.
##
## Checked here, at the wire, because it is the part a harness *can* see. What it
## cannot see is two battlefields agreeing - there is one `RunState` autoload in
## a process, so a simulated guest shares the host's run state and the two cannot
## meaningfully disagree. `coop_world_check.tscn` covers what a mirrored enemy
## does; this covers that the facts describing one arrive intact.
func _test_world_facts_cross_the_wire() -> void:
	_guest_bus.coop_enemy_spawned.connect(
		func(net_id: int, data_id: String, lane: int, at: Vector2,
				hp: float, dmg: float, spd: float) -> void:
			_guest_world.append(["spawned", net_id, data_id, lane, at, hp, dmg, spd]))
	_guest_bus.coop_enemy_batch.connect(
		func(entries: Array) -> void: _guest_world.append(["batch", entries]))
	_guest_bus.coop_enemy_removed.connect(
		func(net_id: int) -> void: _guest_world.append(["removed", net_id]))
	_guest_bus.coop_tower_state.connect(
		func(anchor: Vector2i, id: String, level: int) -> void:
			_guest_world.append(["tower", anchor, id, level]))

	_host_bus.coop_enemy_spawned.emit(41, "bogkin", 2, Vector2(300.0, -120.0),
		1.5, 1.25, 1.1)
	_host_bus.coop_enemy_batch.emit([[41, Vector2(280.0, -100.0), 0.5]])
	_host_bus.coop_tower_state.emit(Vector2i(3, 4), "ember_spire", 2)
	_host_bus.coop_enemy_removed.emit(41)
	await _settle(func() -> bool: return _guest_world.size() >= 4)

	_check(_guest_world.size() >= 4,
		"all four world facts must arrive, got %d" % _guest_world.size())
	var spawned: Array = _row("spawned")
	_check(not spawned.is_empty(), "an enemy spawn must cross")
	if not spawned.is_empty():
		# Every field, because a spawn is how the guest *builds* the enemy: a lane
		# or a scale arriving wrong makes a mirror of a different creature, and the
		# health bar it draws would be a bar for something else.
		_check(int(spawned[1]) == 41 and String(spawned[2]) == "bogkin"
			and int(spawned[3]) == 2 and spawned[4] == Vector2(300.0, -120.0)
			and is_equal_approx(float(spawned[5]), 1.5)
			and is_equal_approx(float(spawned[6]), 1.25)
			and is_equal_approx(float(spawned[7]), 1.1),
			"a spawn must arrive with every field intact")

	var batch: Array = _row("batch")
	_check(not batch.is_empty(), "a position batch must cross")
	if not batch.is_empty():
		var entries: Array = batch[1]
		_check(entries.size() == 1 and (entries[0] as Array).size() == 3,
			"a batch must survive as a list of rows, not be flattened")

	var tower: Array = _row("tower")
	_check(not tower.is_empty() and tower[1] == Vector2i(3, 4)
		and String(tower[2]) == "ember_spire" and int(tower[3]) == 2,
		"a tower placement must cross with its anchor, kind and tier")
	_check(not _row("removed").is_empty(), "a retirement must cross")


## A refusal goes to the one who asked, and only the host may send one.
##
## Addressed rather than broadcast because the other player has no use for it —
## a refusal on both screens reads as the game refusing them both.
func _test_a_refusal_is_addressed() -> void:
	_guest_bus.coop_request_refused.connect(
		func(kind: int, reason: String) -> void:
			_guest_refusals.append([kind, reason]))
	var host_relay: CoopRelay = _host.call("relay")
	var guest_relay: CoopRelay = _guest.call("relay")

	var peers: Array = (_host.multiplayer as MultiplayerAPI).get_peers()
	_check(not peers.is_empty(), "the host must know who to answer")
	if peers.is_empty():
		return
	_check(host_relay.refuse(int(peers[0]), CoopRelay.Request.BUILD_TOWER,
		"Needs 70 Gold."), "a host must be able to refuse")
	await _settle(func() -> bool: return not _guest_refusals.is_empty())

	_check(not _guest_refusals.is_empty(), "the refusal must reach the guest")
	if not _guest_refusals.is_empty():
		_check(int(_guest_refusals[0][0]) == CoopRelay.Request.BUILD_TOWER,
			"and say which request it answers")
		_check(String(_guest_refusals[0][1]) == "Needs 70 Gold.",
			"carrying the host's own sentence, unedited")

	# A guest refusing anything would be a guest deciding an outcome.
	_check(not guest_relay.refuse(1, CoopRelay.Request.BUILD_TOWER, "no"),
		"a guest must not be able to refuse anything")


## The first recorded world row of a kind, or empty.
func _row(kind: String) -> Array:
	for entry: Array in _guest_world:
		if String(entry[0]) == kind:
			return entry
	return []


## A host that vanishes is reported to the guest, loudly and recoverably.
##
## `docs/COOP_DESIGN.md` §7. What follows from it - the guest's run being
## abandoned back to the menu - is `GameDirector`'s job, deliberately, and is
## **not** driven here.
##
## That is not squeamishness. A first version had `Coop` call `goto_menu()`
## itself, and it replaced the scene this harness was running in, mid-test, ending
## the run in a page of engine shutdown errors. The layering fix and the testing
## problem had the same answer: the network layer reports, and the thing that owns
## navigation decides. A test that has to destroy itself to run is telling you the
## seam is in the wrong place.
##
## So `run_active` is left false here. What is asserted is that the session
## reports the loss with something to show a player, that it does not quietly
## record a finished run, and that a new session can be opened afterwards - a
## dropped host that leaves the game unable to reconnect would be the worse bug.
func _test_a_dropped_host_ends_the_guest_run() -> void:
	_check(_guest.state() == _guest.State.CONNECTED,
		"the harness expects a joined guest")
	_check(not GameDirector.run_active,
		"this harness must not have a live run: abandoning one changes the scene")
	var best_before: int = MetaState.best_runs.size()
	var failures_before: int = _failure_reasons.size()

	# The host goes away without saying goodbye, which is the case that matters:
	# a clean quit and a pulled cable must look the same to the guest.
	_host.leave()
	await _settle(func() -> bool: return _guest.state() != _guest.State.CONNECTED)

	_check(_guest.state() != _guest.State.CONNECTED,
		"the guest must notice the host is gone")
	_check(_failure_reasons.size() > failures_before,
		"and say so, with a reason fit to show a player")
	_check(_guest.is_host(),
		"the player is their own authority again afterwards")
	_check(MetaState.best_runs.size() == best_before,
		"a vanished host must not write a finished run into the record")

	# Put the pair back together for the rows that follow, which also proves a
	# drop does not leave the game unable to reconnect.
	_check(_host.host(TEST_PORT), "the harness must be able to host again")
	_check(_guest.join("127.0.0.1", TEST_PORT), "and the guest to rejoin")
	await _settle(func() -> bool: return _guest.state() == _guest.State.CONNECTED)
	_check(_guest.state() == _guest.State.CONNECTED,
		"a session must be re-openable after a drop")


func _test_guest_leaves_cleanly() -> void:
	_guest.leave()
	_check(_guest.state() == _guest.State.OFFLINE, "leaving must return to OFFLINE")
	_check(_guest.is_host(), "a player who left is once again their own authority")

	await _settle(func() -> bool: return not _host.partner_present())
	_check(not _host.partner_present(), "the host must notice the guest is gone")
	_check(_host.player_count() == 1,
		"the host must fall back to balancing for one")
	_check(_host.state() == _host.State.HOSTING,
		"the host keeps hosting after a guest leaves: the run is still theirs")
	_check(not _left_peers.is_empty(),
		"coop_partner_left must have been emitted for the departure")

	_host.leave()
	_check(_host.state() == _host.State.OFFLINE, "a host that leaves goes offline")
	# And the port comes back, which is what makes hosting twice in one sitting
	# work.
	var after := ENetMultiplayerPeer.new()
	_check(after.create_server(TEST_PORT, 1) == OK,
		"leaving must release the port")
	after.close()


## A dead address must fail, and must fail *out loud*.
##
## ENet's `connection_failed` answers "the host refused". Nothing at the address
## answers nothing at all, so without the timeout this state would sit in
## CONNECTING forever and a player would watch a spinner and conclude the game
## had hung.
func _test_a_bad_address_fails_instead_of_hanging() -> void:
	_check(not _guest.join("", TEST_PORT), "an empty address must be refused outright")
	_check(_guest.state() == _guest.State.FAILED, "a refused dial must report FAILED")
	_check(not _guest.last_error.is_empty(), "a failure must carry a reason to show")
	_check(not _failure_reasons.is_empty(), "coop_failed must have been emitted")

	# The timeout itself, driven rather than waited out: this is a ten-second
	# clock and a gate must not take ten seconds to check it.
	_check(_guest.join("127.0.0.1", TEST_PORT + 1),
		"dialling a closed port must at least start")
	_check(_guest.state() == _guest.State.CONNECTING, "and must be in flight")
	_guest._process(Balance.COOP_CONNECT_TIMEOUT + 1.0)
	_check(_guest.state() == _guest.State.FAILED,
		"a dial with no answer must time out rather than hang in CONNECTING")
	_guest.leave()
	await get_tree().process_frame


## The connect code, which is the whole of "playing with a friend anywhere".
##
## Pure arithmetic and therefore cheap to hold, and worth holding: a code that
## decodes to the *wrong* address sends somebody dialling a stranger, and a code
## that half-parses is worse than one that fails. Both directions, both the
## boundaries, and the shapes that must be refused.
func _test_a_code_survives_the_round_trip() -> void:
	for row: Array in [["203.0.113.42", 45870], ["8.8.8.8", 1],
			["255.255.255.255", 65535], ["10.0.0.237", 45870]]:
		var address: String = String(row[0])
		var port: int = int(row[1])
		var code: String = CoopCode.encode(address, port)
		_check(not code.is_empty(), "%s:%d must encode" % [address, port])
		var back: Dictionary = CoopCode.decode(code)
		_check(String(back.get("address", "")) == address
				and int(back.get("port", 0)) == port,
			"%s:%d -> %s must come back the same, got %s"
				% [address, port, code, back])
		# However it arrives out of a chat window.
		_check(CoopCode.decode(code.to_lower()) == back, "case must not matter")
		_check(CoopCode.decode(code.replace("-", "")) == back,
			"nor the dash")

	# And the shapes that must not be accepted. A code that half-parses is a
	# player dialling somebody they have never met.
	for bad: String in ["", "ABC", "IIIII-IIIII", "0000000000000",
			"192.168.0.4", "6B01R-JNCS"]:
		_check(CoopCode.decode(bad).is_empty(),
			"'%s' must be refused rather than parsed" % bad)
	_check(CoopCode.looks_like_code("6B01R-JNCSE"), "a code must look like one")
	_check(not CoopCode.looks_like_code("192.168.0.4"),
		"and an address must not")
	_check(CoopCode.encode("not.an.address.here", 45870).is_empty(),
		"nonsense must not encode")
	_check(CoopCode.encode("10.0.0.1", 0).is_empty(), "nor a port of zero")


## A host on this network is findable without anybody typing anything.
##
## Broadcast, bind, hear it, and age it out again. Run in one process because a
## broadcast reaches the machine that sent it - which is the same reason two
## copies on one desk can find each other, so this is the real path rather than a
## stand-in for it.
func _test_a_beacon_is_heard() -> void:
	var listener := CoopBeacon.new()
	var shouter := CoopBeacon.new()
	add_child(listener)
	add_child(shouter)
	listener.listen()
	shouter.announce("Warden · level 9", Balance.COOP_PORT)
	# Several beacon intervals, because a packet may be dropped and the point is
	# that a host keeps saying it rather than saying it once.
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and listener.games().is_empty():
		await get_tree().process_frame
	var found: Array = listener.games()
	_check(not found.is_empty(),
		"a host shouting on this network must be heard, found %d" % found.size())
	if not found.is_empty():
		var game: Dictionary = found[0]
		_check(String(game["name"]) == "Warden · level 9",
			"and named, got '%s'" % String(game["name"]))
		_check(int(game["port"]) == Balance.COOP_PORT,
			"and carry the port to dial, got %d" % int(game["port"]))
		_check(not String(game["address"]).is_empty(),
			"and an address to dial it at")

	# And a host that stops is forgotten, or the list fills with games that
	# ended an hour ago.
	shouter.stop_announcing()
	var gone_by: int = Time.get_ticks_msec() + int(
		(CoopBeacon.BEACON_TIMEOUT + 2.0) * 1000.0)
	while Time.get_ticks_msec() < gone_by and not listener.games().is_empty():
		await get_tree().process_frame
	_check(listener.games().is_empty(),
		"a game that stopped shouting must age out of the list")

	# Anything else on that port is not ours, and a name from the network is
	# never drawn as it arrived.
	_check(CoopBeacon._clean("") == "A warden's camp",
		"an empty name must still be something to click")
	_check(not CoopBeacon._clean("a
b	c").contains("
"),
		"a name must not carry line breaks into the row it is drawn in")
	_check(CoopBeacon._clean("x".repeat(200)).length() <= CoopBeacon.MAX_NAME,
		"nor run past the panel")

	listener.stop_listening()
	listener.queue_free()
	shouter.queue_free()
	await get_tree().process_frame


## Rows from the public lobby table, treated as what they are: text from
## strangers on the internet, drawn as buttons.
##
## No network here. The parsing is the part that has to be right - a bad row must
## be dropped rather than made into a button that cannot work - and it is exactly
## the part that can be handed the shapes a hostile or broken table would return.
func _test_the_public_list_is_not_trusted() -> void:
	var good: String = CoopCode.encode_pair("203.0.113.9", "192.168.0.4",
		Balance.COOP_PORT)
	var rows: Array = CoopDirectory.parse_rows([
		{"code": good, "name": "Warden · level 9", "players": 1, "age_seconds": 12},
		# Every one of these must be dropped rather than drawn.
		{"code": "not-a-code", "name": "junk", "players": 1, "age_seconds": 1},
		{"code": "", "name": "empty", "players": 1, "age_seconds": 1},
		{"code": "IIIII-IIIII", "name": "bad letters", "players": 1, "age_seconds": 1},
		"a bare string, not a row",
		42,
	])
	_check(rows.size() == 1,
		"only rows carrying a code that parses may be drawn, kept %d of 6"
			% rows.size())
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		_check(String(row["code"]) == good, "and the code must survive intact")
		_check(int(row["age"]) == 12, "with the age it was given")

	# A name is drawn in a row on screen and arrived from a stranger.
	var nasty: Array = CoopDirectory.parse_rows([
		{"code": good, "name": "line" + "
" + "break", "players": 9, "age_seconds": -5},
	])
	_check(nasty.size() == 1, "a hostile name must not lose the row")
	if nasty.size() == 1:
		var row: Dictionary = nasty[0]
		_check(not String(row["name"]).contains("
"),
			"a name must not carry a line break into the row it is drawn in")
		_check(int(row["players"]) <= 2,
			"a player count must be clamped, got %d" % int(row["players"]))
		_check(int(row["age"]) >= 0, "and an age must not be negative")
	_check(CoopDirectory.parse_rows("not an array").is_empty(),
		"a reply that is not a list must produce no rows at all")

	# Our own listing is not something to offer to join.
	var mine: Array = CoopDirectory.parse_rows(
		[{"code": good, "name": "me", "players": 1, "age_seconds": 3}], good)
	_check(mine.is_empty(), "a host must not be offered its own game")


## WebRTC has an implementation behind it, not just a class name.
##
## **The engine defines `WebRTCPeerConnection` whether or not anything
## implements it**, so `class_exists` answers true on a desktop build with no
## extension and the co-op screen would offer a room button that cannot work.
## The only honest test is to initialise one, which is what `available()` does.
##
## A desktop build reaching here without the extension is a build somebody made
## wrong - the DLLs are committed - so this fails rather than warns.
func _test_webrtc_is_actually_available() -> void:
	_check(CoopWebRTC.available(),
		"WebRTC must be usable in this build: the extension in "
			+ "addons/webrtc_native is what lets a desktop player meet a browser "
			+ "player, and without it the room button is decoration")
	# The ids are fixed and the two sides must not agree by coincidence.
	_check(CoopWebRTC.HOST_ID != CoopWebRTC.GUEST_ID,
		"the two peers in a room need different ids")
	# A room code has to survive being read aloud and typed back.
	for _attempt: int in 40:
		var code: String = Supabase.room_code()
		_check(code.length() == 6, "a room code is six characters, got %d"
			% code.length())
		for character: String in code:
			_check(not "ILOU".contains(character),
				"a room code must avoid characters that are misread: %s" % code)


## The lobby list offers what this build can dial, and nothing else.
##
## Both kinds of code live in the same column - six characters is a WebRTC room,
## longer is an address - and a listing that understood only one would silently
## hide every game hosted the other way.
func _test_both_kinds_of_code_are_offered() -> void:
	var address: String = CoopCode.encode_pair("203.0.113.9", "192.168.0.4",
		Balance.COOP_PORT)
	_check(CoopDirectory.joinable_code(address),
		"a desktop build must offer address-coded games")
	_check(CoopDirectory.joinable_code("K7M2QX"),
		"and room-coded ones, which are the only kind a browser can join")
	_check(not CoopDirectory.joinable_code("ILLEGAL"),
		"but not a code that is neither")
	_check(not CoopDirectory.joinable_code(""), "nor an empty one")
	_check(not CoopDirectory.joinable_code("K7M2Q!"),
		"nor six characters that are not a room code")


func _tear_down() -> void:
	if _guest != null and is_instance_valid(_guest):
		_guest.leave()
	if _host != null and is_instance_valid(_host):
		_host.leave()
	if _host_root != null and is_instance_valid(_host_root):
		_host_root.queue_free()
	if _guest_root != null and is_instance_valid(_guest_root):
		_guest_root.queue_free()


## Runs frames until `done` answers true, or the budget is spent.
##
## Both sessions are polled by hand each frame. A `MultiplayerAPI` registered on
## a subtree is not driven by the same loop that drives the default one, and
## without this the handshake never advances and every network row fails for a
## reason that has nothing to do with the code under test.
func _settle(done: Callable) -> void:
	for _f: int in NETWORK_FRAMES:
		if bool(done.call()):
			return
		_poll_both()
		await get_tree().process_frame


func _poll_both() -> void:
	var host_api: MultiplayerAPI = _host.multiplayer
	var guest_api: MultiplayerAPI = _guest.multiplayer
	if host_api != null and host_api.has_multiplayer_peer():
		host_api.poll()
	if guest_api != null and guest_api.has_multiplayer_peer():
		guest_api.poll()


## Records everything relayable that a bus emits, as `[name, args]`.
##
## Connected by name from the same list the relay uses, so a signal added to the
## relay and forgotten here shows up as a missing recording rather than as a
## silent gap in the test.
func _listen(bus: Node, into: Array) -> void:
	for name: String in ["enemy_died", "wave_cleared", "boss_defeated",
			"lane_pressure_changed", "phase_changed", "currency_changed",
			"town_health_changed", "camera_shake_requested", "hero_dashed"]:
		var tag: String = name
		bus.connect(StringName(name), func(a: Variant = null, b: Variant = null) -> void:
			var args: Array = []
			if a != null:
				args.append(a)
			if b != null:
				args.append(b)
			into.append([tag, args]))


## Whether `into` recorded `name` carrying exactly `args`.
func _heard(into: Array, name: String, args: Array) -> bool:
	for entry: Array in into:
		if String(entry[0]) != name:
			continue
		var got: Array = entry[1]
		if got.size() != args.size():
			continue
		var same: bool = true
		for index: int in args.size():
			# Compared by value *and* type: the wire carries Variants, so an int
			# arriving as a float is exactly the class of drift worth catching.
			if typeof(got[index]) != typeof(args[index]) or got[index] != args[index]:
				same = false
				break
		if same:
			return true
	return false


func _count(into: Array, name: String) -> int:
	var total: int = 0
	for entry: Array in into:
		if String(entry[0]) == name:
			total += 1
	return total


## Pumps both sides for a fixed number of frames, for asserting a *non*-event.
func _settle_frames(count: int) -> void:
	for _f: int in count:
		_poll_both()
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[coop] %s" % why)
