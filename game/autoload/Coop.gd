extends Node

## The co-op session: hosting, joining, and knowing which of the two you are.
##
## Two players, one city, one beast (GDD §54, amended 2026-08-24 by the owner).
## The full design is `docs/COOP_DESIGN.md`; this is step 1 of its build order
## and it owns the connection and **nothing else**. No game state crosses this
## yet — no heroes, no enemies, no resources. That is step 2 onward, and keeping
## them apart is deliberate: a transport that cannot be tested without a running
## game is a transport nobody tests.
##
## **Host-authoritative.** The host simulates and the guest mirrors. This class
## does not enforce that by itself; what it provides is one honest answer to "am
## I the host", so every system that has to ask asks the same thing rather than
## each inventing its own test. See `docs/COOP_DESIGN.md` §2 for why lockstep was
## rejected.
##
## Deliberately safe when nothing is connected. `is_host()` answers **true** in a
## single-player run, because a lone player is the authority over their own game.
## Every "may I do this" check downstream then reads the same in both modes, and
## the single-player path cannot rot from being the branch nobody exercises.
## `is_networked()` is the question to ask when the answer really is "is anyone
## else here".

enum State {
	## Single player. The default, and what every run has been until now.
	OFFLINE,
	## Listening. Playable alone: a host does not wait for company to start.
	HOSTING,
	## Dialling a host. The outcome is not known yet.
	CONNECTING,
	## Joined, as the guest.
	CONNECTED,
	## The last attempt did not work; `last_error` says how.
	FAILED,
}

## Why the last attempt failed, in a sentence fit to put in front of a player.
var last_error: String = ""

var _state: State = State.OFFLINE
var _peer: ENetMultiplayerPeer = null
var _connect_left: float = 0.0

## The one place messages cross the wire. A child rather than a sibling or a
## second autoload, and that is load-bearing: a `MultiplayerAPI` is registered
## against a subtree, so a relay parented here is guaranteed to be on the same
## API as the session that owns it. The harness stands up two of each and neither
## can accidentally end up talking through the other's peer.
var _relay: CoopRelay = null

## The address a friend would type, once it is known.
##
## Two of them, because they answer different questions. The local one is what a
## second machine in the same house uses; the external is what somebody in
## another country needs. Both are looked up rather than assumed - a player who
## has to find their own public IP will not play co-op.
var local_address: String = ""
var external_address: String = ""

## Whether UPnP persuaded the router to forward the port.
##
## False is not a failure to report as an error: plenty of routers have UPnP
## switched off, and the honest answer is "forward port N yourself, or play on
## the same network" rather than a stack trace.
var port_mapped: bool = false

## UPnP discovery blocks for seconds. On the main thread that is the menu
## freezing, so it runs on its own and the result arrives as a signal.
var _upnp_thread: Thread = null

## Asks the internet what this machine looks like from outside, when the router
## will not say.
##
## **UPnP answers for a minority of players.** Plenty of routers have it switched
## off and plenty of connections sit behind carrier-grade NAT, and for all of
## them `external_address` stayed empty - so the co-op screen showed a local
## address and nothing else, and a player wanting to play with a friend in
## another country had to go and find their own public IP. That is the step
## people do not take.
##
## Only ever used when hosting, only when UPnP has already failed, and it sends
## nothing: the request carries no payload and the reply is this machine's own
## address. It is a fallback for the *display*, not for the connection.
var _ip_probe: HTTPRequest = null

## Where to ask. Plain text, one line, no key and no account.
const PUBLIC_IP_URL: String = "https://api.ipify.org"


func _ready() -> void:
	# ALWAYS, because a co-op session must survive the tree being paused. A
	# pause menu that also stops answering the network drops the other player.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind()
	_relay = CoopRelay.new()
	_relay.name = "Relay"
	_relay.session = self
	# Both set before the node enters the tree: the relay binds its signals in
	# `_ready`, and a relay that arrives without a bus binds to nothing.
	_relay.bus = EventBus
	add_child(_relay)


## Wires this node's own `MultiplayerAPI`.
##
## `multiplayer` rather than `get_tree().get_multiplayer()`, and that is what
## makes co-op testable at all: a `MultiplayerAPI` is registered against a subtree
## path, so a Coop node placed under a custom-API subtree picks that one up. The
## harness stands a host and a guest up in one process on exactly that property.
func _bind() -> void:
	var api: MultiplayerAPI = multiplayer
	if api == null:
		return
	api.peer_connected.connect(_on_peer_connected)
	api.peer_disconnected.connect(_on_peer_disconnected)
	api.connected_to_server.connect(_on_connected_to_server)
	api.connection_failed.connect(_on_connection_failed)
	api.server_disconnected.connect(_on_server_disconnected)


# --- Asking ------------------------------------------------------------------

func state() -> State:
	return _state


## True when a second machine is involved at all.
func is_networked() -> bool:
	return _state == State.HOSTING or _state == State.CONNECTING \
		or _state == State.CONNECTED


## True for the authority over the simulation — **including single player**.
##
## See the class comment: a lone player is the authority over their own run, so
## every downstream permission check reads identically in both modes.
func is_host() -> bool:
	return _state != State.CONNECTING and _state != State.CONNECTED


## True only for the joined second player.
func is_guest() -> bool:
	return _state == State.CONNECTED


## Whether the other player is actually here, as opposed to expected.
##
## A host that is listening with nobody connected is not in company, and a wave
## sized for two would be a wave sized for a player who has not arrived.
func partner_present() -> bool:
	var api: MultiplayerAPI = multiplayer
	if api == null or not api.has_multiplayer_peer():
		return false
	return not api.get_peers().is_empty()


## The relay, for the systems that have to send a request or read the guard.
##
## Nothing in the battlefield, town or beast scope should reach for this. The
## relay exists so those systems do not have to know a network exists, and a
## gameplay script that starts asking it questions has undone that.
func relay() -> CoopRelay:
	return _relay


## How many players the run should be balanced for, right now.
##
## The number the difficulty director will read in step 5. One unless somebody
## is genuinely connected, which is why it is built on `partner_present` rather
## than on the session state.
func player_count() -> int:
	return 2 if partner_present() else 1


# --- Doing -------------------------------------------------------------------

## Opens the session. Returns whether the port was taken.
##
## Hosting does not block or wait. The run is playable immediately and alone;
## the partner arriving is an event, not a precondition.
func host(port: int = Balance.COOP_PORT) -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var made: int = peer.create_server(port, Balance.COOP_MAX_GUESTS)
	if made != OK:
		return _fail("Could not open port %d. Another program may be using it." % port)
	_peer = peer
	multiplayer.multiplayer_peer = peer
	_set_state(State.HOSTING)
	_begin_address_lookup(port)
	return true


## Dials a host. Returns whether the attempt *started*, not whether it worked.
##
## The outcome arrives later, as `coop_state_changed` reaching CONNECTED or
## FAILED. Callers must not treat `true` as connected — a wrong address returns
## true here and fails ten seconds later, which is the whole reason the timeout
## in `_process` exists.
func join(address: String, port: int = Balance.COOP_PORT) -> bool:
	leave()
	var wanted: String = address.strip_edges()
	if wanted.is_empty():
		return _fail("Enter the host's address.")
	var peer := ENetMultiplayerPeer.new()
	var made: int = peer.create_client(wanted, port)
	if made != OK:
		return _fail("%s is not an address this game can dial." % wanted)
	_peer = peer
	multiplayer.multiplayer_peer = peer
	_connect_left = Balance.COOP_CONNECT_TIMEOUT
	_set_state(State.CONNECTING)
	return true


## Ends the session and returns to single player.
##
## Safe to call when there is no session, which is why `host` and `join` both
## open with it: reconnecting is then the same code path as connecting, and
## there is no second teardown to keep in step with this one.
func leave() -> void:
	_connect_left = 0.0
	_join_lookup()
	if _peer != null:
		_peer.close()
		_peer = null
	var api: MultiplayerAPI = multiplayer
	if api != null:
		api.multiplayer_peer = null
	if _state != State.OFFLINE:
		_set_state(State.OFFLINE)


## Finds the two addresses a friend might need, off the main thread.
##
## `UPNP.discover()` blocks for about two seconds and a menu that freezes for two
## seconds when you click Host reads as a crash. The thread is joined in
## `_exit_tree` and before any second lookup, because a Thread destroyed without
## `wait_to_finish` warns loudly - and a warning on exit fails the guard.
func _begin_address_lookup(port: int) -> void:
	local_address = _first_local_address()
	external_address = ""
	port_mapped = false
	EventBus.coop_address_known.emit(local_address, "", false)
	_join_lookup()
	# Not headless. There is no player to show a public address to, and Godot's
	# UPNP prints `ERROR: Couldn't find any UPNPDevices` when there is no gateway
	# to find - which is a perfectly ordinary answer on a CI runner and a fatal
	# one to `guard.yml`, which fails any check that emits an ERROR line.
	#
	# Skipping it headless also keeps every harness that hosts a session from
	# spending two seconds asking a router that is not there.
	if DisplayServer.get_name() == "headless":
		return
	_upnp_thread = Thread.new()
	_upnp_thread.start(_lookup_external.bind(port))


func _lookup_external(port: int) -> void:
	var upnp := UPNP.new()
	var found: int = upnp.discover()
	var address: String = ""
	var mapped: bool = false
	if found == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null 			and upnp.get_gateway().is_valid_gateway():
		address = upnp.query_external_address()
		# UDP: ENet is a UDP protocol, and mapping TCP would open the wrong door
		# and report success while nothing could connect.
		mapped = upnp.add_port_mapping(port, port, "Beast Road co-op",
			"UDP") == UPNP.UPNP_RESULT_SUCCESS
	_finish_lookup.call_deferred(address, mapped)


## Back on the main thread, because signals reach UI from here.
func _finish_lookup(address: String, mapped: bool) -> void:
	external_address = address
	port_mapped = mapped
	EventBus.coop_address_known.emit(local_address, external_address, port_mapped)
	# The router did not know, or would not say. Ask the internet instead, so the
	# player at least has an address to send even if they have to forward the
	# port themselves.
	if external_address.is_empty():
		_ask_the_internet()


## The public-address fallback. See `_ip_probe`.
func _ask_the_internet() -> void:
	if DisplayServer.get_name() == "headless":
		# No player to show it to, and a network call from a gate is a gate that
		# fails when the runner has no route out.
		return
	if _ip_probe == null:
		_ip_probe = HTTPRequest.new()
		_ip_probe.timeout = 6.0
		add_child(_ip_probe)
		_ip_probe.request_completed.connect(_on_public_ip)
	if _ip_probe.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_ip_probe.request(PUBLIC_IP_URL)


func _on_public_ip(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var text: String = body.get_string_from_utf8().strip_edges()
	# Checked rather than trusted. This is a reply from a machine on the
	# internet and it ends up in front of the player as *their* address, so
	# anything that is not four numbers and three dots is discarded.
	var parts: PackedStringArray = text.split(".")
	if parts.size() != 4:
		return
	for part: String in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return
	external_address = text
	EventBus.coop_address_known.emit(local_address, external_address, port_mapped)


func _join_lookup() -> void:
	if _upnp_thread != null:
		if _upnp_thread.is_started():
			_upnp_thread.wait_to_finish()
		_upnp_thread = null


## The machine's own address on its network.
##
## Skips loopback and IPv6: what this is for is being read aloud or pasted into a
## friend's join box, and neither `::1` nor a link-local IPv6 address is that.
func _first_local_address() -> String:
	for address: String in IP.get_local_addresses():
		if address.begins_with("127.") or address.contains(":"):
			continue
		return address
	return "127.0.0.1"


func _exit_tree() -> void:
	_join_lookup()


func _process(delta: float) -> void:
	if _state != State.CONNECTING:
		return
	_connect_left -= delta
	if _connect_left <= 0.0:
		# Deliberately not a silent return to OFFLINE. A join that quietly gives
		# up looks identical to one still trying, and the player retypes the
		# address they already had right.
		var reason: String = "No answer from the host. Check the address and that they are hosting."
		leave()
		_fail(reason)


# --- Hearing -----------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	EventBus.coop_partner_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	EventBus.coop_partner_left.emit(id)


func _on_connected_to_server() -> void:
	_connect_left = 0.0
	_set_state(State.CONNECTED)


func _on_connection_failed() -> void:
	var reason: String = "The host refused the connection."
	leave()
	_fail(reason)


## The host went away.
##
## `docs/COOP_DESIGN.md` §7: a host drop ends the run for both, and host
## migration is out of scope — a large amount of work for a two-player game where
## one player is by definition the owner of the run.
##
## The guest's run has to end, but **this is not the thing that ends it.** All
## that happens here is the fact being reported: the session is gone, and why.
## `GameDirector` owns navigation and listens for it.
##
## That split is not tidiness. A first version had this call `goto_menu()`
## directly, which is the network layer reaching across to drive scene changes -
## against working rule 5, and immediately visible as a bug: it replaced the
## scene the co-op harness was running in, mid-test, and the run ended in a page
## of engine shutdown errors. A layer that can delete its own caller is one worth
## keeping on its own side of the seam.
func _on_server_disconnected() -> void:
	leave()
	_fail("The host ended the session.")


# --- Bookkeeping -------------------------------------------------------------

func _set_state(to: State) -> void:
	if _state == to:
		return
	_state = to
	if to != State.FAILED:
		last_error = ""
	EventBus.coop_state_changed.emit(int(to))


## Records a failure and reports it. Always returns false, so every caller can
## `return _fail(...)` and read as one line.
## Reports a failure that happened before any dialling started.
##
## Public because a mistyped code is refused by the *screen* rather than by the
## transport - there is nothing to dial - and a refusal the player never sees is
## a Join button that appears to do nothing.
func report_failure(reason: String) -> void:
	_fail(reason)


func _fail(reason: String) -> bool:
	last_error = reason
	_set_state(State.FAILED)
	EventBus.coop_failed.emit(reason)
	return false
