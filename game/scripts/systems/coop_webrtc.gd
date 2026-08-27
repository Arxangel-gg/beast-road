class_name CoopWebRTC
extends Node

## Co-op over WebRTC: the transport the **web build** can use, and the one that
## gets through a home router without anybody forwarding a port.
##
## ENet is still here and still the right answer for a direct address or a game
## on your own network - it needs no server at all and works with the internet
## down. What it cannot do is run in a browser, because a browser cannot open a
## UDP socket, and it cannot cross two home routers without one of them being
## configured. WebRTC does both.
##
## ### The shape of a connection
##
## Two peers, fixed ids: the host is 1 and the guest is 2. The host opens a room
## and waits; the guest joins it. Everything above this - `CoopRelay`, the facts,
## the authority guard - is unchanged and does not know which transport carried
## it, because the relay speaks `send_bytes` on whatever `MultiplayerPeer` is
## installed rather than binding to a socket.
##
## ### Signalling
##
## Two browsers cannot exchange connection details without something in the
## middle to pass notes. That something is a Supabase table, polled over the
## same REST client the lobby list uses. Polling rather than a socket, on
## purpose: a handshake is a handful of messages over a couple of seconds, a
## poll costs nothing at that rate, and it avoids a second protocol that would
## have to work identically in a browser and out of one.
##
## The room is deleted the moment both sides are connected. Nothing about a
## finished handshake is worth keeping.

## Godot's fixed ids for a two-player mesh.
const HOST_ID: int = 1
const GUEST_ID: int = 2

## Public STUN servers, for discovering what address a router is presenting.
##
## Several, because one being unreachable should slow a connection down rather
## than prevent it - and in the places where this matters most, one of them
## being blocked is the likely case rather than the unlucky one.
const STUN_SERVERS: Array = [
	{"urls": ["stun:stun.l.google.com:19302"]},
	{"urls": ["stun:stun1.l.google.com:19302"]},
	{"urls": ["stun:stun.cloudflare.com:3478"]},
]

## Relays, for the pairs that cannot reach each other directly.
##
## **STUN is not enough and never was.** It tells a peer what address its router
## is presenting, which is all two cooperative routers need to punch a hole
## through to each other. Symmetric NAT does not cooperate, and carrier-grade
## NAT - the normal case on mobile networks and common for whole countries -
## gives a peer no reachable address at all. For those pairs there is no direct
## route to find, and a game with only STUN configured does not connect slowly,
## it does not connect.
##
## Measured from a browser on 2026-08-26: STUN yields one `host` and one `srflx`
## candidate and no `relay`, which is exactly the `ice 2/2` a failing session
## reports. The free public relay this would otherwise have used
## (openrelay.metered.ca) answered on none of its three ports.
##
## So this list is empty until it is filled in, and the game says so rather than
## letting people discover it as an intermittent failure. See docs/COOP_WEBRTC.md
## for where credentials come from; the values are long-term TURN credentials,
## which are meant to live in the client exactly like the anon key is.
const TURN_SERVERS: Array = [
]

## What the connection is actually offered.
static func ice_servers() -> Array:
	var all: Array = STUN_SERVERS.duplicate(true)
	all.append_array(TURN_SERVERS)
	return all


## Whether a relay is configured. Without one, some pairs simply cannot meet.
static func has_relay() -> bool:
	return not TURN_SERVERS.is_empty()

## How often the signalling table is read while a handshake is in progress.
const POLL_SECONDS: float = 1.0

## How long to keep trying before saying so. Generous: a first connection over
## STUN can take several seconds on a slow link, and giving up early on a
## connection that would have worked is the worse failure.
const HANDSHAKE_TIMEOUT: float = 45.0

## How many refused polls in a row mean the room has gone, rather than one
## request losing its way. At one poll a second this is a few seconds of grace.
const MISSES_ALLOWED: int = 20

## What the service raises when the room in question no longer exists. Told
## apart from a request that merely failed, because one is fatal and certain and
## the other is a busy connection that will very likely work next second.
const ROOM_GONE: String = "P0002"

## A frame longer than this means the game was not running, not that it was
## running slowly.
##
## A browser stops `requestAnimationFrame` in a hidden tab, and Godot's whole
## main loop rides on it - so a backgrounded tab is *stopped*, not slow. Any
## request in flight when that happens sits there while its eight second timeout
## expires in wall-clock time, and every one of them fails the instant the tab
## is looked at again. Two tabs on one machine therefore lose roughly half their
## requests, which is a fact about browsers rather than a fault in the session.
const SUSPENDED_FRAME: float = 0.5

## The longest a host will hold a room open waiting for somebody.
##
## Not a handshake timeout - it is the point past which an abandoned room should
## stop being advertised. Generous, because the failure it replaces was a host
## being cut off after forty-five seconds, and erring the other way costs
## nothing but a stale row the sweep will take.
##
## It also keeps this build honest against a service that has not been migrated
## yet: without the `seen_at` heartbeat the room is swept after two minutes, and
## a host with no deadline at all would poll a room that no longer exists until
## somebody closed the tab.
const HOST_WAIT_LIMIT: float = 900.0

signal ready_to_play(peer: WebRTCMultiplayerPeer)
signal failed(reason: String)
signal progress(text: String)

var rest: Supabase = null

var _peer: WebRTCMultiplayerPeer = null
var _connection: WebRTCPeerConnection = null
var _room: String = ""
var _code: String = ""
var _token: String = ""
var _is_host: bool = false
var _seen: int = 0
var _poll_left: float = 0.0
var _deadline: float = 0.0
var _live: bool = false
var _announced: bool = false

## How far the handshake got. See `status_line`.
var _sent_sdp: int = 0
var _heard_sdp: int = 0
var _sent_ice: int = 0
var _heard_ice: int = 0

## Reads attempted, and reads the service actually answered.
var _polls: int = 0
var _replies: int = 0
## Posts the service *confirmed* it stored, and posts it silently dropped.
##
## Separate from `_sent_sdp` and `_sent_ice`, which count what this side tried
## to say. The two are not the same number and the gap between them is a whole
## class of fault: `post_signal` answers HTTP 200 with a body of `null` when the
## caller's token belongs to neither side of the room, so a peer writing into a
## room it is not a member of looks, from here, exactly like a peer writing
## successfully into one it is.
var _stored: int = 0
var _refused: int = 0
## The room and code this side last used, kept **through** a reset purely so the
## diagnostic can be read after a failure.
##
## Same mistake as the counters, in the same file: `_reset` cleared `_room`, so
## the status line showed an empty room in precisely the state anybody wants to
## read it - after it went wrong. Two peers that never met and two peers that
## met in different rooms are completely different faults and the blank looked
## identical for both.
var _last_room: String = ""
var _last_code: String = ""
## Consecutive polls the service refused. A room that has been swept away
## answers every read with an error, and polling a room that no longer exists is
## otherwise indistinguishable from polling a quiet one.
var _misses: int = 0
## True while a poll is out. A poll is issued on a timer, and a timer does not
## know whether the last one came back - so on a slow link they stack, and each
## new one competes with the ones already waiting. The pile only ever grows.
var _poll_busy: bool = false
## Why the last request failed, for the diagnostic. `ok` alone cannot tell a
## timeout from a refusal, and those are opposite problems.
var _why: String = ""
## Candidate types gathered here and heard from the other side.
##
## A pair holding only `host` and `srflx` has no fallback: if neither a local
## route nor a hole punched through both routers works, there is nothing else to
## try. `relay` is the one that always works and the one that needs a TURN
## server, so counting them is how "these two cannot reach each other" is told
## apart from "nobody offered them a way".
var _mine: Dictionary = {}
var _theirs: Dictionary = {}
## The connection's own last words, kept past the reset that clears it.
var _ending: String = ""


func _ready() -> void:
	set_process(false)


## Whether this build can use WebRTC at all.
##
## True in a browser, which implements it natively, and true on desktop when the
## `webrtc_native` extension is present. False is not an error to shout about -
## it means "offer ENet and say so", which is what the co-op screen does.
static func available() -> bool:
	if not ClassDB.class_exists("WebRTCPeerConnection"):
		return false
	# The class exists in the engine as an interface even when nothing
	# implements it, so existence is not the question - whether a connection can
	# actually be initialised is. Asked once, cheaply, rather than assumed from
	# the platform, because the answer is a property of this build.
	var probe := WebRTCPeerConnection.new()
	return probe.initialize({"iceServers": ice_servers()}) == OK


func room_code() -> String:
	return _code


## **What the handshake has actually done**, in one line, for the co-op screen.
##
## A timeout says only that it did not finish. This says how far it got, and the
## stages fail in a fixed order - so where the numbers stop is where the fault
## is. Sent/heard offers and answers prove the table is carrying notes; routes
## prove ICE gathered and crossed; the states prove whether the connection and
## the channel came up.
##
## Written because the browser cannot be driven from the development harness,
## and "connecting, then a timeout" was the only evidence available for three
## rounds of guessing.
func status_line() -> String:
	var link: int = _connection.get_connection_state() if _connection != null else -1
	var mesh: int = _peer.get_connection_status() if _peer != null else -1
	# `polls` is what separates "nobody said anything" from "nobody was
	# listening". Without it, zero heard is two entirely different faults with
	# the same reading, and the fix for one is nothing like the fix for the other.
	# The room id is here because "both sides are polling and neither hears
	# anything" has two causes that read identically - the same room refusing
	# the writes, or two different rooms each working perfectly. Eight
	# characters is enough to tell one from the other at a glance.
	var live: String = ""
	if _connection != null:
		live = "%d/%d/%s" % [_connection.get_connection_state(),
			_connection.get_gathering_state(), _summary(_mine) + ">" + _summary(_theirs)]
	var state: String = live if not live.is_empty() else _ending
	var room: String = _room if not _room.is_empty() else _last_room
	var code: String = _code if not _code.is_empty() else _last_code
	return ("%s %s  sdp %d/%d  ice %d/%d  put %d/%d  polls %d/%d  link %d  "
		+ "mesh %d  room %s%s") % [
			"host" if _is_host else "guest", code,
			_sent_sdp, _heard_sdp, _sent_ice, _heard_ice, _stored, _refused,
			_polls, _replies, link, mesh, room.substr(0, 8),
			"" if _why.is_empty() else "  why " + _why]  + "  ice " + state


# --- Opening and joining a room ----------------------------------------------

## Opens a room and waits for somebody. Returns the code to share, or "".
func host() -> String:
	if not available():
		failed.emit("This build cannot use WebRTC.")
		return ""
	_reset()
	_is_host = true
	_code = Supabase.room_code()
	_token = Supabase.token()
	if not _build_peer(HOST_ID, GUEST_ID):
		return ""
	progress.emit("Opening a room...")
	rest.call_rpc("open_room", {"p_code": _code, "p_token": _token},
		func(ok: bool, data: Variant) -> void:
			if not ok:
				_fail("Could not open a room: the matchmaking service did not "
					+ "answer. If this is a fresh install of the service, the "
					+ "tables in docs/MATCHMAKING.md have not been created yet.")
				return
			_room = _text_of(data)
			if _room.is_empty():
				_fail("The matchmaking service refused the room.")
				return
			_begin_polling()
			_start_offer())
	return _code


## Joins somebody's room by the code they shared.
func join(code: String) -> void:
	if not available():
		failed.emit("This build cannot use WebRTC.")
		return
	var wanted: String = code.strip_edges().to_upper().replace("-", "")
	if wanted.length() != 6:
		failed.emit("A room code is six characters.")
		return
	_reset()
	_is_host = false
	_code = wanted
	_token = Supabase.token()
	if not _build_peer(GUEST_ID, HOST_ID):
		return
	progress.emit("Looking for the room...")
	rest.call_rpc("enter_room", {"p_code": _code, "p_token": _token},
		func(ok: bool, data: Variant) -> void:
			if not ok:
				_fail("Could not reach the matchmaking service.")
				return
			_room = _text_of(data)
			if _room.is_empty():
				_fail("No game is waiting on that code.")
				return
			# Which side offers is not arbitrary - see `offers`. A browser and
			# a desktop build negotiate identically from here, which is the
			# entire reason this works cross-platform.
			_begin_polling()
			_start_offer())


## Asks this side for an offer, if this is the side that offers.
##
## The return value is checked, which it previously was not, and that omission
## is the shape of the bug it was hiding: `create_offer` is the one step of the
## handshake that can fail without anything being logged, thrown or emitted. A
## guest whose offer never gets made looks identical from the host's chair to a
## guest who never arrived - the mesh is built, the peer is added, the room is
## polled, and the counter simply reads zero for forty-five seconds.
##
## Every other call in `_build_peer` was already checked. This one is now too.
func _start_offer() -> void:
	if not offers(_is_host):
		# Not this side's turn. The other one speaks first and we answer.
		print("[rtc] waiting for an offer")
		return
	print("[rtc] asking for an offer")
	var result: int = _connection.create_offer()
	if result != OK:
		print("[rtc] create_offer refused: %d" % result)
		_fail("This browser would not start a connection (error %d). "
			% result + "WebRTC may be disabled or blocked by an extension.")


## Builds the peer and this side's half of the connection.
func _build_peer(own_id: int, other_id: int) -> bool:
	_peer = WebRTCMultiplayerPeer.new()
	if _peer.create_mesh(own_id) != OK:
		_fail("Could not start a WebRTC session.")
		return false
	_connection = WebRTCPeerConnection.new()
	if _connection.initialize({"iceServers": ice_servers()}) != OK:
		_fail("Could not start a WebRTC connection.")
		return false
	_connection.session_description_created.connect(_on_description)
	_connection.ice_candidate_created.connect(_on_candidate)
	# Ordered and reliable, because everything above assumes a stream that
	# arrives complete and in order - the relay's facts are not idempotent and a
	# dropped one is a machine holding a stale opinion forever.
	if _peer.add_peer(_connection, other_id) != OK:
		_fail("Could not add the other player to the session.")
		return false

	# **Installed now, not when it connects.**
	#
	# `peer_connected` is emitted by the peer the moment the channel opens, and
	# the `MultiplayerAPI` only learns who is in the session by hearing it. Wait
	# for the channel and *then* install, and that announcement has already been
	# and gone: the handshake succeeds, both sides say "Connected", and
	# `multiplayer.get_peers()` is empty for ever - so `partner_present()` is
	# false and the game believes nobody arrived.
	#
	# This is how ENet is used too: the peer is installed and then connects.
	# Nothing above minds a peer that is still negotiating, because nothing above
	# sends anything until `Coop` says the session is up.
	multiplayer.multiplayer_peer = _peer
	return true


func _begin_polling() -> void:
	_live = true
	_seen = 0
	_sent_sdp = 0
	_heard_sdp = 0
	_sent_ice = 0
	_heard_ice = 0
	_polls = 0
	_replies = 0
	_stored = 0
	_refused = 0
	_poll_busy = false
	_mine = {}
	_theirs = {}
	_poll_left = 0.0
	_misses = 0
	# **A host has no deadline until somebody arrives.**
	#
	# A guest may fairly give up on a clock: it typed a code for a room that is
	# supposed to be there right now. A host is waiting for a *person* to read
	# six characters out of a chat window and type them in, and that takes as
	# long as it takes.
	#
	# Arming this for the host failed every host after forty-five seconds - and
	# `_fail` closes the room on its way out, so the friend who finally typed
	# the code was told no game was waiting on it, while the host's screen still
	# said it was hosting. The clock starts when the guest speaks.
	_deadline = HOST_WAIT_LIMIT if _is_host else HANDSHAKE_TIMEOUT
	set_process(true)


# --- The handshake -----------------------------------------------------------

## This side produced an offer or an answer. Keep it, and post it.
func _on_description(type: String, sdp: String) -> void:
	# Printed as well as counted. On the web these reach the browser console, so
	# a failure can be read without attaching a debugger to anything.
	print("[rtc] made a %s (%d chars)" % [type, sdp.length()])
	_sent_sdp += 1
	_connection.set_local_description(type, sdp)
	_post(type, {"sdp": sdp})


## A route this machine might be reachable on.
## Reads `typ host` / `typ srflx` / `typ relay` out of a candidate line.
## "h2s1r0" - compact on purpose; this sits on one line of a debug footer.
static func _summary(counts: Dictionary) -> String:
	return "h%ds%dr%d" % [int(counts.get("host", 0)),
		int(counts.get("srflx", 0)), int(counts.get("relay", 0))]


static func _kind_of(candidate: String) -> String:
	var marker: int = candidate.find(" typ ")
	if marker < 0:
		return "?"
	var rest: String = candidate.substr(marker + 5)
	var end: int = rest.find(" ")
	return rest.substr(0, end) if end > 0 else rest


static func _tally(into: Dictionary, kind: String) -> void:
	into[kind] = int(into.get(kind, 0)) + 1


func _on_candidate(media: String, index: int, name: String) -> void:
	_tally(_mine, _kind_of(name))
	_sent_ice += 1
	_post("candidate", {"media": media, "index": index, "name": name})


func _post(kind: String, payload: Dictionary) -> void:
	if _room.is_empty():
		return
	rest.call_rpc("post_signal", {
		"p_room": _room,
		"p_token": _token,
		"p_kind": kind,
		"p_payload": payload,
	}, func(ok: bool, data: Variant) -> void:
		# `post_signal` returns the new sequence number, or null. Null is not a
		# transport failure - the request succeeded - it means the service
		# looked up this token against the room and found it on neither side,
		# so the note was thrown away. Discarding this reply, which is what used
		# to happen here, turns the one fatal answer the service can give into
		# forty-five seconds of silence on the *other* machine.
		if ok and (data is float or data is int):
			_stored += 1
			return
		_refused += 1
		print("[rtc] %s refused by the room (reply: %s)" % [kind, str(data)])
		if _refused == 1:
			_fail("The matchmaking service would not accept this connection: "
				+ "the room did not recognise us. The host may have closed it, "
				+ "or somebody else joined first."))


func _poll() -> void:
	if _room.is_empty() or _poll_busy:
		return
	_poll_busy = true
	_polls += 1
	if _polls == 1:
		print("[rtc] polling as %s" % ("host" if _is_host else "guest"))
	rest.call_rpc("read_signals", {
		"p_room": _room,
		"p_token": _token,
		"p_after": _seen,
	}, func(ok: bool, data: Variant) -> void:
		_poll_busy = false
		if not ok or not (data is Array):
			if data is Dictionary:
				var d: Dictionary = data
				_why = "%s/%s/%s" % [d.get("code", "?"), d.get("result", "-"),
					d.get("status", "-")]
			# **Two different failures wear this shape**, and treating them
			# alike is why a browser reported a closed room it was still in.
			#
			# The service raising `P0002` is the room genuinely being gone -
			# certain, immediate, and worth saying so. A request that simply
			# did not arrive is a busy connection, and a browser has plenty:
			# the lobby list, the heartbeat, the signal posts and this poll all
			# compete, and any of them can lose an 8 second timeout. Giving up
			# after five of *those* ends a session that was fine.
			if data is Dictionary 					and String((data as Dictionary).get("code", "")) == ROOM_GONE:
				_fail("The room is no longer open. Host again to get a fresh "
					+ "code.")
				return
			_misses += 1
			if _misses >= MISSES_ALLOWED:
				_fail("Lost contact with the matchmaking service. Check your "
					+ "connection and try again.")
			return
		_misses = 0
		_replies += 1
		if _is_host and _deadline > HANDSHAKE_TIMEOUT 				and not (data as Array).is_empty():
			# Somebody is negotiating. From here a clock is fair, and a stalled
			# handshake should be reported rather than waited on for ever.
			_deadline = HANDSHAKE_TIMEOUT
		if (data as Array).size() > 0:
			print("[rtc] heard %d note(s)" % (data as Array).size())
		for entry: Variant in (data as Array):
			if entry is Dictionary:
				_apply(entry as Dictionary))


## One signalling message from the other side.
##
## Everything here arrived over the internet from a stranger, so nothing is
## trusted to be the shape it should be: a malformed row is skipped rather than
## handed to WebRTC, and the sequence number only ever moves forward.
func _apply(row: Dictionary) -> void:
	_seen = maxi(_seen, int(row.get("seq", 0)))
	if _connection == null:
		return
	var kind: String = String(row.get("kind", ""))
	var payload: Variant = row.get("payload", null)
	if not (payload is Dictionary):
		return
	var body: Dictionary = payload
	if not consumes(kind, _is_host):
		return
	if kind == "candidate":
		_heard_ice += 1
	else:
		_heard_sdp += 1
	match kind:
		"offer":
			_connection.set_remote_description("offer", String(body.get("sdp", "")))
			progress.emit("Connecting...")
		"answer":
			_connection.set_remote_description("answer", String(body.get("sdp", "")))
			progress.emit("Connecting...")
		"candidate":
			_tally(_theirs, _kind_of(String(body.get("name", ""))))
			_connection.add_ice_candidate(String(body.get("media", "")),
				int(body.get("index", 0)), String(body.get("name", "")))


# --- Driving it --------------------------------------------------------------

func _process(delta: float) -> void:
	if not _live:
		return
	# The connection *and* the mesh. A handshake that is not polled is a
	# handshake that never happens: polling is what turns gathered routes into
	# `ice_candidate_created` and what advances the negotiation between them.
	if _connection != null:
		_connection.poll()
	if _peer != null:
		_peer.poll()
		if _other_side_is_open() and not _announced:
			_announced = true
			_live = false
			set_process(false)
			progress.emit("Connected.")
			# The room existed to introduce two machines and they have met.
			# Nothing about a finished handshake is worth keeping, and a table
			# of stale rooms is a table nobody can trust.
			_close_room()
			ready_to_play.emit(_peer)
			return

	if delta > SUSPENDED_FRAME:
		# The tab was asleep. Everything that failed while it was is noise: the
		# requests did not fail on their merits, they expired unattended. Hold
		# the clock too, or a player who looked at another window for a minute
		# comes back to a session that gave up on them.
		_misses = 0
		return

	_deadline -= delta
	if _deadline <= 0.0:
		if _is_host and _sent_sdp == 0 and _heard_sdp == 0:
			# Nobody ever arrived. That is not a failed connection, and saying
			# it was sends people looking for a network fault that is not there.
			_fail("Nobody joined. Host again when your friend is ready.")
		else:
			_fail("Could not reach the other player. They may have closed the "
				+ "game.")
		return

	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = POLL_SECONDS
		_poll()


## Whether the *other player's* channel is open and usable.
##
## **`get_connection_status()` is the wrong question and answers it wrongly.** A
## mesh reports CONNECTED the moment it is created, because it is connected to
## itself - so waiting on it succeeds instantly, installs a peer whose data
## channel is still closed, and the first packet sent through it fails with
## "DataChannel not open". That is what this code did until
## `tools/webrtc_check.tscn` was pointed at it and said "connected in 0.0s"
## about two peers that could not exchange a byte.
##
## Asked as a *state* rather than taken from the `peer_connected` signal, so a
## peer that finished connecting before anything was listening is still seen.
func _other_side_is_open() -> bool:
	if _peer == null:
		return false
	var other: int = GUEST_ID if _is_host else HOST_ID
	var peers: Dictionary = _peer.get_peers()
	if not peers.has(other):
		return false
	var info: Variant = peers[other]
	return info is Dictionary and bool((info as Dictionary).get("connected", false))


## **Which side makes the offer.** One fact, and everything else derives from it.
##
## The guest, because `WebRTCMultiplayerPeer` creates the data channels on the
## peer with the *higher* id and expects the lower one to receive them - so an
## offer from the host describes a connection with nothing in it.
static func offers(is_host: bool) -> bool:
	return not is_host


## Whether this side of the room is the one that acts on a note of this kind.
##
## **Derived from `offers`, not written out separately.** These were two
## independent lists once, and they drifted the moment the offering side changed:
## the guest began offering and the host went on ignoring offers, so no answer
## was ever produced and every join timed out with "could not reach the other
## player" - which reads as a network fault and is not one.
##
## `webrtc_check` could not catch it, because that harness hands the two
## connections straight to each other and never comes through here.
static func consumes(kind: String, is_host: bool) -> bool:
	match kind:
		# Whoever did not make the offer is the one who has to answer it.
		"offer":
			return not offers(is_host)
		# And the answer goes back to whoever asked.
		"answer":
			return offers(is_host)
		# Routes are useful to both sides for as long as they are negotiating.
		"candidate":
			return true
	return false


## Gives up, tears down, and says why.
##
## Every failure path lands here so a half-built peer is never left installed:
## a `WebRTCMultiplayerPeer` that never connected still answers
## `get_connection_status`, and something upstream would eventually believe it.
func _fail(reason: String) -> void:
	_close_room()
	_reset()
	failed.emit(reason)


## Stops waiting and cleans up, without an error. For a player who changed their
## mind, and for `Coop.leave`.
func cancel() -> void:
	if _room.is_empty() and _peer == null:
		return
	_close_room()
	_reset()


func _close_room() -> void:
	if _room.is_empty():
		return
	var room: String = _room
	var token: String = _token
	_last_room = room
	_room = ""
	rest.call_rpc("close_room", {"p_room": room, "p_token": token},
		func(_ok: bool, _data: Variant) -> void: pass)


func _reset() -> void:
	_live = false
	_announced = false
	_seen = 0
	# **The counters survive a failure**, and are cleared when the next attempt
	# begins instead. Resetting them here wiped the only record of how far the
	# handshake got at the exact moment somebody wanted to read it - the guest's
	# line said 0/0 after every timeout, which is indistinguishable from never
	# having tried.
	if _connection != null:
		# Why it ended, taken before the object that knows is thrown away.
		_ending = "%d/%d/%s" % [_connection.get_connection_state(),
			_connection.get_gathering_state(), _summary(_mine) + ">" + _summary(_theirs)]
	if not _room.is_empty():
		_last_room = _room
	if not _code.is_empty():
		_last_code = _code
	_room = ""
	_code = ""
	set_process(false)
	if _connection != null:
		_connection.close()
		_connection = null
	if _peer != null:
		# Uninstalled before it is closed, or the session is left holding a dead
		# peer - which reads to everything above as a connection that exists and
		# never answers.
		if multiplayer.multiplayer_peer == _peer:
			multiplayer.multiplayer_peer = null
		_peer.close()
		_peer = null


## Supabase returns a bare scalar for a function that returns one.
static func _text_of(data: Variant) -> String:
	if data is String:
		return String(data)
	if data is Array and (data as Array).size() > 0:
		return String((data as Array)[0])
	if data is Dictionary:
		return String((data as Dictionary).get("id", ""))
	return ""


func _exit_tree() -> void:
	cancel()
