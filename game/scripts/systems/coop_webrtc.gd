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
const ICE_SERVERS: Array = [
	{"urls": ["stun:stun.l.google.com:19302"]},
	{"urls": ["stun:stun1.l.google.com:19302"]},
	{"urls": ["stun:stun.cloudflare.com:3478"]},
]

## How often the signalling table is read while a handshake is in progress.
const POLL_SECONDS: float = 1.0

## How long to keep trying before saying so. Generous: a first connection over
## STUN can take several seconds on a slow link, and giving up early on a
## connection that would have worked is the worse failure.
const HANDSHAKE_TIMEOUT: float = 45.0

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
	return probe.initialize({"iceServers": ICE_SERVERS}) == OK


func room_code() -> String:
	return _code


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
				_fail("Could not open a room. The matchmaking service is not " \
					+ "reachable.")
				return
			_room = _text_of(data)
			if _room.is_empty():
				_fail("The matchmaking service refused the room.")
				return
			# The host does *not* offer. See `join`.
			_begin_polling())
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
			# **The guest offers, and which side does is not arbitrary.**
			#
			# `WebRTCMultiplayerPeer` creates the data channels on the peer with
			# the higher id and expects the lower one to receive them, so the
			# offer has to come from the side that made them or it describes a
			# connection with nothing in it. The guest is 2 and the host is 1.
			#
			# A browser and a desktop build negotiate identically from here,
			# which is the entire reason this works cross-platform.
			_begin_polling()
			_connection.create_offer())


## Builds the peer and this side's half of the connection.
func _build_peer(own_id: int, other_id: int) -> bool:
	_peer = WebRTCMultiplayerPeer.new()
	if _peer.create_mesh(own_id) != OK:
		_fail("Could not start a WebRTC session.")
		return false
	_connection = WebRTCPeerConnection.new()
	if _connection.initialize({"iceServers": ICE_SERVERS}) != OK:
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
	return true


func _begin_polling() -> void:
	_live = true
	_seen = 0
	_poll_left = 0.0
	_deadline = HANDSHAKE_TIMEOUT
	set_process(true)


# --- The handshake -----------------------------------------------------------

## This side produced an offer or an answer. Keep it, and post it.
func _on_description(type: String, sdp: String) -> void:
	_connection.set_local_description(type, sdp)
	_post(type, {"sdp": sdp})


## A route this machine might be reachable on.
func _on_candidate(media: String, index: int, name: String) -> void:
	_post("candidate", {"media": media, "index": index, "name": name})


func _post(kind: String, payload: Dictionary) -> void:
	if _room.is_empty():
		return
	rest.call_rpc("post_signal", {
		"p_room": _room,
		"p_token": _token,
		"p_kind": kind,
		"p_payload": payload,
	}, func(_ok: bool, _data: Variant) -> void: pass)


func _poll() -> void:
	if _room.is_empty():
		return
	rest.call_rpc("read_signals", {
		"p_room": _room,
		"p_token": _token,
		"p_after": _seen,
	}, func(ok: bool, data: Variant) -> void:
		if not ok or not (data is Array):
			return
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
	match kind:
		"offer":
			# Only a guest has anything to do with an offer. A host that applied
			# its own would be answering itself.
			if _is_host:
				return
			_connection.set_remote_description("offer", String(body.get("sdp", "")))
			progress.emit("Connecting...")
		"answer":
			if not _is_host:
				return
			_connection.set_remote_description("answer", String(body.get("sdp", "")))
			progress.emit("Connecting...")
		"candidate":
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

	_deadline -= delta
	if _deadline <= 0.0:
		_fail("Could not reach the other player. They may have closed the game.")
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
	_room = ""
	rest.call_rpc("close_room", {"p_room": room, "p_token": token},
		func(_ok: bool, _data: Variant) -> void: pass)


func _reset() -> void:
	_live = false
	_announced = false
	_seen = 0
	_room = ""
	_code = ""
	set_process(false)
	if _connection != null:
		_connection.close()
		_connection = null
	if _peer != null:
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
