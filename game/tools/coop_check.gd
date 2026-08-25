extends Node

## Stands a co-op host and guest up in one process and makes them shake hands.
##
##   godot --headless --path game res://tools/coop_check.tscn
##
## Step 1 of the co-op build order in `docs/COOP_DESIGN.md`. It checks the
## transport and the session state machine and deliberately nothing else — no
## heroes, no waves, no resources cross the wire yet.
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
	await _test_guest_leaves_cleanly()
	await _test_a_bad_address_fails_instead_of_hanging()

	_tear_down()
	for _f: int in 4:
		await get_tree().process_frame
	if _failures == 0:
		print("[coop] PASS - loopback handshake, partner count, clean leave, dead address")
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

	_host = Node.new()
	_host.name = "Coop"
	_host.set_script(script)
	_host_root.add_child(_host)

	_guest = Node.new()
	_guest.name = "Coop"
	_guest.set_script(script)
	_guest_root.add_child(_guest)


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
		var host_api: MultiplayerAPI = _host.multiplayer
		var guest_api: MultiplayerAPI = _guest.multiplayer
		if host_api != null and host_api.has_multiplayer_peer():
			host_api.poll()
		if guest_api != null and guest_api.has_multiplayer_peer():
			guest_api.poll()
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[coop] %s" % why)
