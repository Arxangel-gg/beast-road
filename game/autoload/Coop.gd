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

## The second address from a pasted code, and its port. See `join`.
var _alternate: String = ""
var _alternate_port: int = Balance.COOP_PORT

## Local-network discovery, built on demand so a run that never opens the co-op
## screen never binds a socket.
var _beacon: CoopBeacon = null

## The public lobby list. Built on demand for the same reason: a player who never
## looks for a game never makes a request.
var _directory: CoopDirectory = null

## Who is in the party, and which seat each of them holds.
var _party: CoopParty = null

## The seat currently being acted for, while the host carries out a request.
##
## **So a receipt can name the right player.** The host performs a guest's build
## through exactly the same `try_build` a local click uses - which is what keeps
## one set of rules rather than two - and that function has no idea who asked.
## This is set around the call and read by `PartyNotices`; zero means "this
## machine's own player", which is the truth everywhere except inside a request.
var acting_slot: int = 0

## The shared REST client, and the WebRTC transport that uses it for signalling.
var _rest: Supabase = null
var _friends: CoopFriends = null
var _webrtc: CoopWebRTC = null

## The room code a friend types, while this machine is hosting over WebRTC.
var room_code: String = ""


## The lobby broadcaster and listener.
func beacon() -> CoopBeacon:
	if _beacon == null:
		_beacon = CoopBeacon.new()
		_beacon.name = "CoopBeacon"
		add_child(_beacon)
	return _beacon


## What this game calls itself in somebody else's lobby list.
##
## Deliberately not a machine name or an account name. It goes out on the local
## network to anything listening, and "the hero you have" is the most it needs to
## say for a friend to recognise it.
## The public lobby list.
func directory() -> CoopDirectory:
	if _directory == null:
		_directory = CoopDirectory.new()
		_directory.name = "CoopDirectory"
		add_child(_directory)
	return _directory


## The party roster. Built on demand and never torn down: a run that never opens
## co-op still asks it for a slot, and the answer is 1.
func party() -> CoopParty:
	if _party == null:
		_party = CoopParty.new()
		_party.name = "CoopParty"
		add_child(_party)
	return _party


## Who this player knows, and which of them is online.
func friends() -> CoopFriends:
	if _friends == null:
		_friends = CoopFriends.new()
		_friends.name = "CoopFriends"
		_friends.rest = rest()
		add_child(_friends)
	return _friends


## The REST client. One instance, shared by the lobby list and by signalling.
func rest() -> Supabase:
	if _rest == null:
		_rest = Supabase.new()
		_rest.name = "Supabase"
		add_child(_rest)
	return _rest


## The WebRTC transport.
func webrtc() -> CoopWebRTC:
	if _webrtc == null:
		_webrtc = CoopWebRTC.new()
		_webrtc.name = "CoopWebRTC"
		_webrtc.rest = rest()
		add_child(_webrtc)
		_webrtc.ready_to_play.connect(_on_webrtc_ready)
		_webrtc.failed.connect(_on_webrtc_failed)
	return _webrtc


## Opens a room anybody can join, on any platform, without forwarding a port.
##
## **This is the one that works everywhere.** ENet hosting below needs an open
## port and cannot run in a browser at all; this needs neither, and a desktop
## player and a browser player meet on it identically. Returns the code to
## share, or "" if this build cannot do it.
func host_room() -> String:
	leave()
	if not CoopWebRTC.available():
		_fail("This build cannot use WebRTC.")
		return ""
	var code: String = webrtc().host()
	if code.is_empty():
		return ""
	room_code = code
	# Hosting, immediately and honestly: a host is playable alone and does not
	# wait for company, exactly as with ENet.
	# The host takes seat one, before anybody can join it.
	party().open(lobby_name())
	_set_state(State.HOSTING)
	return code


## Joins a room by its code. Works from a browser and from the desktop build.
func join_room(code: String) -> bool:
	leave()
	if not CoopWebRTC.available():
		return _fail("This build cannot use WebRTC.")
	_connect_left = Balance.COOP_CONNECT_TIMEOUT_ROOM
	_set_state(State.CONNECTING)
	webrtc().join(code)
	return true


## Tells the host how far this account has climbed. Guest side.
##
## Sent on connecting rather than asked for, because the host needs it before it
## can decide whether the party may play the tier it has chosen - and a question
## the host has to remember to ask is a question it will forget to ask.
func _declare_tier() -> void:
	if not is_guest():
		return
	var line: CoopRelay = relay()
	if line != null:
		line.request(CoopRelay.Request.DECLARE_TIER, [MetaState.tier_cleared])


## Why this party cannot play the run's chosen tier, or "" if it can.
func party_blocked_from(tier: CampaignTierData) -> String:
	if not is_networked():
		return ""
	return party().blocked_from(tier)


## The handshake finished. Install the peer and let the game get on with it.
##
## Everything above this point - the relay, the facts, the authority guard - is
## unchanged and never learns which transport carried it.
func _on_webrtc_ready(peer: WebRTCMultiplayerPeer) -> void:
	_peer = null
	multiplayer.multiplayer_peer = peer
	if _state == State.CONNECTING:
		_set_state(State.CONNECTED)
	_declare_tier.call_deferred()


func _on_webrtc_failed(reason: String) -> void:
	room_code = ""
	_fail(reason)


func lobby_name() -> String:
	return "Warden · level %d" % MetaState.hero_level

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
## **The transport's count, not the roster's**, and the difference matters. The
## roster is host-authored and arrives a packet late; the peer list is what this
## machine can actually see. A wave sized from a roster that has not landed yet
## is a wave sized for a player who is not there - which is exactly the failure
## `partner_present` was written to avoid, and the reason it is built on peers.
##
## Everybody counted, capped at the seat count so a stray connection cannot
## inflate a wave. One when playing alone.
func player_count() -> int:
	var api: MultiplayerAPI = multiplayer
	if api == null or not api.has_multiplayer_peer():
		return 1
	return clampi(api.get_peers().size() + 1, 1, Balance.COOP_MAX_PLAYERS)


# --- Doing -------------------------------------------------------------------

## Opens the session. Returns whether the port was taken.
##
## Hosting does not block or wait. The run is playable immediately and alone;
## the partner arriving is an event, not a precondition.
## Opens a port on this machine. Direct, serverless, and desktop-only.
##
## Kept alongside `host_room` rather than replaced by it, and each has a job the
## other cannot do: this one needs no internet at all, which is what makes two
## people in one house work with the line down, and it is measurably lower
## latency because nothing is negotiated. What it cannot do is run in a browser
## or cross a router nobody configured.
func host(port: int = Balance.COOP_PORT) -> bool:
	leave()
	if OS.has_feature("web"):
		return _fail("Opening a port needs the desktop version. Host a room instead.")
	var peer := ENetMultiplayerPeer.new()
	var made: int = peer.create_server(port, Balance.COOP_MAX_GUESTS)
	if made != OK:
		return _fail("Could not open port %d. Another program may be using it." % port)
	_peer = peer
	multiplayer.multiplayer_peer = peer
	# The host takes seat one, before anybody can join it.
	party().open(lobby_name())
	_set_state(State.HOSTING)
	_begin_address_lookup(port)
	# Shout on the local network, so anyone in the same house needs neither an
	# address nor a code. See `CoopBeacon`.
	beacon().announce(lobby_name(), port)
	return true


## Dials a host. Returns whether the attempt *started*, not whether it worked.
##
## The outcome arrives later, as `coop_state_changed` reaching CONNECTED or
## FAILED. Callers must not treat `true` as connected — a wrong address returns
## true here and fails ten seconds later, which is the whole reason the timeout
## in `_process` exists.
func join(address: String, port: int = Balance.COOP_PORT,
		alternate: String = "") -> bool:
	leave()
	var wanted: String = address.strip_edges()
	if wanted.is_empty():
		return _fail("Enter the host's address.")
	# The second address a code carries, tried if the first goes unanswered.
	#
	# The public address is the one a friend in another country needs and the one
	# that fails for a friend in the same house, because most routers will not
	# loop a connection back to themselves. Rather than ask the player which case
	# they are in - which they cannot know - the code carries both and this tries
	# the other before giving up.
	_alternate = alternate.strip_edges()
	_alternate_port = port
	if OS.has_feature("web"):
		# A browser cannot open the socket this dials. The lobby list already
		# hides address-coded games here, but a player can still paste one, and
		# a dial that fails ten seconds later with "no answer from the host"
		# would send them looking for a network problem they do not have.
		return _fail("A browser cannot dial an address. Ask your friend for a "
			+ "six-character room code instead.")
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
	room_code = ""
	if _party != null:
		_party.clear()
	if _webrtc != null:
		_webrtc.cancel()
	beacon().stop_announcing()
	# Off the public list too. A game nobody is hosting is not one to advertise,
	# and the row is what keeps that table honest.
	if _directory != null:
		_directory.withdraw()
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
	# The roster, on repeat, while anybody is there to hear it.
	if is_host() and partner_present():
		_roster_clock -= delta
		if _roster_clock <= 0.0:
			_roster_clock = ROSTER_INTERVAL
			_publish_roster()

	if _state != State.CONNECTING:
		return
	_connect_left -= delta
	if _connect_left <= 0.0:
		# Deliberately not a silent return to OFFLINE. A join that quietly gives
		# up looks identical to one still trying, and the player retypes the
		# address they already had right.
		if not _alternate.is_empty():
			var second: String = _alternate
			var second_port: int = _alternate_port
			_alternate = ""
			leave()
			# Not a failure yet. The first address simply did not answer, which
			# is the expected outcome for exactly half the codes ever pasted.
			join(second, second_port)
			return
		var reason: String = "No answer from the host. If you are on the same " 			+ "network as them, ask for their Same network address. Otherwise " 			+ "they may need to forward UDP %d on their router." % Balance.COOP_PORT
		leave()
		_fail(reason)


# --- Hearing -----------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	# **Seated before anybody is told they arrived.** Everything downstream reads
	# a slot - the colour, the spawn point, the name in the party list - and a
	# join announced before the seat exists is a player briefly wearing nobody's
	# colour on somebody else's screen.
	if is_host():
		# The host's own clear is recorded once, so `blocked_from` can judge the
		# whole party from one list rather than treating seat one as a special
		# case that has to be remembered separately.
		var mine: CoopParty.Seat = party().seat_for_slot(1)
		if mine != null:
			mine.cleared = MetaState.tier_cleared
		party().seat(id, "Warden")
		_publish_roster()
	EventBus.coop_partner_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if is_host():
		party().unseat(id)
		_publish_roster()
	EventBus.coop_partner_left.emit(id)


## Tells everybody who is in the party. Host side.
##
## **Repeated, not announced once.** A roster sent on the frame a peer connects
## races the guest's own relay coming up, and a guest that misses it stays
## seatless forever - every guest believing it was seat one, wearing red, and
## standing on the host. Four rows twice a second is nothing, and it also seats
## anybody who joins later without a second mechanism to get wrong.
func _publish_roster() -> void:
	if not is_host():
		return
	EventBus.coop_party_roster.emit(party().to_wire())


## How often the host re-states the roster while anybody is listening. [TUNE]
const ROSTER_INTERVAL: float = 0.5
var _roster_clock: float = 0.0


func _on_connected_to_server() -> void:
	_connect_left = 0.0
	_set_state(State.CONNECTED)
	_declare_tier.call_deferred()


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
