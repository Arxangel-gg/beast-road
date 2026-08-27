extends Node

## Two WebRTC peers, in one process, actually connecting and carrying bytes.
##
##   godot --headless --path game res://tools/webrtc_check.tscn
##
## **Signalling is wired directly here, on purpose.** `CoopWebRTC` passes offers
## and candidates through a table so two machines can find each other; that is a
## separate question from whether the transport works, and mixing them would
## make a network outage look like a broken handshake. Here the two connections
## hand each other their notes in memory, which leaves exactly one thing under
## test: does a WebRTC peer come up, and does `send_bytes` - the call every fact
## in this game travels on - arrive at the other end.
##
## If this passes and a real room does not, the fault is in the signalling or in
## the network between two houses. If this fails, nothing else is worth looking
## at.

const TIMEOUT: float = 20.0

var _failures: int = 0
var _host: WebRTCMultiplayerPeer = null
var _guest: WebRTCMultiplayerPeer = null
var _host_link: WebRTCPeerConnection = null
var _guest_link: WebRTCPeerConnection = null
var _seen_candidates: int = 0
var _guest_candidates: int = 0
var _last_report: int = -1


func _ready() -> void:
	if not CoopWebRTC.available():
		# Named platform and all, because the usual cause is an extension that
		# has a binary for the machine somebody develops on and not for the one
		# that runs the checks.
		_check(false, "WebRTC must be usable in this build - no implementation "
			+ "on %s. See addons/webrtc_native/webrtc_native.gdextension, which "
				% OS.get_name()
			+ "must list a library for every platform that runs this.")
		_finish()
		return

	_host = WebRTCMultiplayerPeer.new()
	_guest = WebRTCMultiplayerPeer.new()
	_check(_host.create_mesh(CoopWebRTC.HOST_ID) == OK, "the host mesh must start")
	_check(_guest.create_mesh(CoopWebRTC.GUEST_ID) == OK, "the guest mesh must start")

	_host_link = _connection()
	_guest_link = _connection()
	if _host_link == null or _guest_link == null:
		_finish()
		return

	# Each side's notes go straight to the other. This is the only part a real
	# room does differently.
	_host_link.session_description_created.connect(
		func(type: String, sdp: String) -> void:
			_host_link.set_local_description(type, sdp)
			_guest_link.set_remote_description(type, sdp))
	_guest_link.session_description_created.connect(
		func(type: String, sdp: String) -> void:
			_guest_link.set_local_description(type, sdp)
			_host_link.set_remote_description(type, sdp))
	_host_link.ice_candidate_created.connect(
		func(media: String, index: int, name: String) -> void:
			_seen_candidates += 1
			_guest_link.add_ice_candidate(media, index, name))
	_guest_link.ice_candidate_created.connect(
		func(media: String, index: int, name: String) -> void:
			_guest_candidates += 1
			_host_link.add_ice_candidate(media, index, name))

	_check(_host.add_peer(_host_link, CoopWebRTC.GUEST_ID) == OK,
		"the host must accept the guest into its mesh")
	_check(_guest.add_peer(_guest_link, CoopWebRTC.HOST_ID) == OK,
		"the guest must accept the host into its mesh")
	_guest_link.create_offer()

	# **`get_connection_status` is not the question.**
	#
	# A mesh answers CONNECTED the moment it is created - it is connected to
	# itself - so waiting on it returns instantly with a channel that is still
	# closed, and the very next `put_packet` fails with "DataChannel not open".
	# Found by running this, having written exactly that mistake into the
	# transport first. What actually matters is whether the *other peer's*
	# channel is open, which is what `peer_connected` announces and what
	# `get_peers()[id]["connected"]` reports.
	var waited: float = 0.0
	while waited < TIMEOUT:
		# The connections as well as the meshes. A mesh polls what it owns, and
		# leaving the raw connections unpolled is a handshake that never advances.
		_host_link.poll()
		_guest_link.poll()
		_host.poll()
		_guest.poll()
		if _peer_is_open(_host, CoopWebRTC.GUEST_ID) \
				and _peer_is_open(_guest, CoopWebRTC.HOST_ID):
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	# Printed whatever happens: on a failure it is the difference between "the
	# two never described themselves to each other" and "they did, and the
	# packets between them were dropped" - which are different faults with
	# different fixes, and impossible to tell apart from a timeout alone.
	print("[webrtc] routes offered: host %d, guest %d; states %d / %d"
		% [_seen_candidates, _guest_candidates,
			_host_link.get_connection_state(), _guest_link.get_connection_state()])
	var host_ready: bool = _peer_is_open(_host, CoopWebRTC.GUEST_ID)
	var guest_ready: bool = _peer_is_open(_guest, CoopWebRTC.HOST_ID)
	_check(host_ready, "the host must see the guest's channel open, waited %.1fs"
		% waited)
	_check(guest_ready, "the guest must see the host's channel open, waited %.1fs"
		% waited)
	if not (host_ready and guest_ready):
		_finish()
		return
	print("[webrtc] connected in %.1fs" % waited)

	# **The thing every fact in this game travels on.**
	#
	# `CoopRelay` sends packets rather than calling `@rpc` methods, which is what
	# makes it transport-independent - so a peer that connects but cannot carry a
	# packet would pass the check above and fail at everything that matters.
	var sent := PackedByteArray([7, 1, 4, 9, 255, 0, 128])
	_guest.set_target_peer(CoopWebRTC.HOST_ID)
	_check(_guest.put_packet(sent) == OK, "the guest must be able to send a packet")

	var got := PackedByteArray()
	var listened: float = 0.0
	while listened < 5.0:
		_host.poll()
		_guest.poll()
		if _host.get_available_packet_count() > 0:
			got = _host.get_packet()
			break
		await get_tree().process_frame
		listened += get_process_delta_time()
	_check(got == sent,
		"and the host must receive exactly those bytes, got %s" % str(got))
	print("[webrtc] carried %d bytes intact" % got.size())

	# Both ways. A one-directional channel would let a guest be told everything
	# and ask for nothing, which is half the protocol.
	var back := PackedByteArray([3, 3, 3])
	_host.set_target_peer(CoopWebRTC.GUEST_ID)
	_check(_host.put_packet(back) == OK, "and the host must be able to reply")
	var returned := PackedByteArray()
	listened = 0.0
	while listened < 5.0:
		_host.poll()
		_guest.poll()
		if _guest.get_available_packet_count() > 0:
			returned = _guest.get_packet()
			break
		await get_tree().process_frame
		listened += get_process_delta_time()
	_check(returned == back, "with the guest receiving it, got %s" % str(returned))

	_test_signalling_routing()
	_test_tokens_are_not_the_global_rng()
	_finish()


## **Who acts on which note.** The half this harness could not otherwise see.
##
## Everything above hands the two connections straight to each other, which
## tests the transport and skips the routing entirely - and the routing is where
## the bug was: the guest began making the offer while the host went on ignoring
## offers, so no answer was ever produced and every real join timed out with
## "could not reach the other player". A network-shaped message for a pure
## dispatch fault, on the one path no test touched.
## Two peers must never draw the same room token.
##
## This is a regression test with a date on it. Until 2026-08-26 `token()` was
## built from `randi()`, the engine's global seeded PRNG, and two copies of the
## game that began life in the same state produced the same "secret". A guest
## carrying the host's token is resolved as the host by the service, so
## `read_signals` - which returns only the other side's notes - hid every
## message from both peers. Both sides polled and posted successfully for the
## full forty-five second timeout and neither heard anything.
##
## Seeding the global RNG identically and demanding different tokens is exactly
## the shape of that bug: it fails against `randi()` and passes against the OS.
func _test_tokens_are_not_the_global_rng() -> void:
	seed(20260826)
	var first: String = Supabase.token()
	var first_code: String = Supabase.room_code()
	seed(20260826)
	var second: String = Supabase.token()
	var second_code: String = Supabase.room_code()
	_check(first != second,
		"two peers seeded alike must still draw different tokens, got %s twice"
			% first)
	_check(first_code != second_code,
		"and different room codes, got %s twice" % first_code)
	_check(first.length() == 24, "a token is 24 characters, got %d"
		% first.length())
	_check(first_code.length() == 6, "a room code is six characters, got %d"
		% first_code.length())
	# The service checks the code against this pattern and rejects the room
	# outright if it does not match, which would fail as "could not open a room".
	var shape := RegEx.new()
	shape.compile("^[0-9A-HJKMNP-TV-Z]{6}$")
	_check(shape.search(first_code) != null,
		"and it must match what the service accepts, got %s" % first_code)


func _test_signalling_routing() -> void:
	# Exactly one side offers.
	_check(CoopWebRTC.offers(false) != CoopWebRTC.offers(true),
		"exactly one side of a room may make the offer")

	# And it is never the side that answers one. This is the assertion that
	# fails if either half is flipped without the other.
	for is_host: bool in [true, false]:
		_check(CoopWebRTC.offers(is_host) != CoopWebRTC.consumes("offer", is_host),
			"the side that offers must not also be the side that answers "
				+ "(is_host=%s)" % str(is_host))
		_check(CoopWebRTC.consumes("answer", is_host) == CoopWebRTC.offers(is_host),
			"an answer must come back to whoever asked (is_host=%s)" % str(is_host))
		_check(CoopWebRTC.consumes("candidate", is_host),
			"both sides need routes while they negotiate (is_host=%s)" % str(is_host))
		_check(not CoopWebRTC.consumes("nonsense", is_host),
			"and nothing acts on a kind it does not know")

	# Stated absolutely as well as relatively, so a consistent double-flip - both
	# halves inverted together - still fails rather than passing quietly.
	_check(CoopWebRTC.offers(false),
		"the guest offers: the mesh puts the data channels on the higher peer id")
	_check(CoopWebRTC.consumes("offer", true), "so the host answers")


## Whether one named peer's channel is actually usable.
##
## **The state, not the signal.** This waited on `peer_connected` first and
## timed out at twenty seconds against two peers that were connected in four -
## the signal is emitted by a `MultiplayerAPI` driving the peer, and nothing here
## drives one. Reading `get_peers()[id]["connected"]` asks the peer directly and
## is what the transport uses, so the harness and the thing it tests now ask the
## same question in the same words.
static func _peer_is_open(peer: WebRTCMultiplayerPeer, id: int) -> bool:
	var peers: Dictionary = peer.get_peers()
	if not peers.has(id):
		return false
	var info: Variant = peers[id]
	return info is Dictionary and bool((info as Dictionary).get("connected", false))


func _connection() -> WebRTCPeerConnection:
	var link := WebRTCPeerConnection.new()
	if link.initialize({"iceServers": CoopWebRTC.ice_servers()}) != OK:
		_check(false, "a WebRTC connection must initialise")
		return null
	return link


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[webrtc] %s" % why)


func _finish() -> void:
	if _host != null:
		_host.close()
	if _guest != null:
		_guest.close()
	for _frame: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("[webrtc] PASS - two peers connected and carried packets both ways")
	get_tree().quit(_failures)
