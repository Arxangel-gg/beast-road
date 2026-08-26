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
	_host_link.create_offer()

	# **`get_connection_status` is not the question.**
	#
	# A mesh answers CONNECTED the moment it is created - it is connected to
	# itself - so waiting on it returns instantly with a channel that is still
	# closed, and the very next `put_packet` fails with "DataChannel not open".
	# Found by running this, having written exactly that mistake into the
	# transport first. What actually matters is whether the *other peer's*
	# channel is open, which is what `peer_connected` announces and what
	# `get_peers()[id]["connected"]` reports.
	var host_ready: bool = false
	var guest_ready: bool = false
	_host.peer_connected.connect(func(_id: int) -> void: host_ready = true)
	_guest.peer_connected.connect(func(_id: int) -> void: guest_ready = true)

	var waited: float = 0.0
	while waited < TIMEOUT:
		# The connections as well as the meshes. A mesh polls what it owns, and
		# leaving the raw connections unpolled is a handshake that never advances.
		_host_link.poll()
		_guest_link.poll()
		_host.poll()
		_guest.poll()
		if host_ready and guest_ready:
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
	_check(host_ready, "the host must see the guest connect, waited %.1fs" % waited)
	_check(guest_ready, "the guest must see the host connect, waited %.1fs" % waited)
	if not (host_ready and guest_ready):
		_finish()
		return
	# The same fact read the other way, because the transport tests it that way.
	_check(_peer_is_open(_host, CoopWebRTC.GUEST_ID),
		"and the host must report the guest's channel open")
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

	_finish()


## Whether one named peer's channel is actually usable.
##
## `get_peers()` maps a peer id to a dictionary carrying `connected`. This is the
## same question `peer_connected` answers as an event, asked as a state - the
## transport needs the state form, because a peer installed after the signal
## fired would otherwise wait for an announcement that already happened.
static func _peer_is_open(peer: WebRTCMultiplayerPeer, id: int) -> bool:
	var peers: Dictionary = peer.get_peers()
	if not peers.has(id):
		return false
	var info: Variant = peers[id]
	return info is Dictionary and bool((info as Dictionary).get("connected", false))


func _connection() -> WebRTCPeerConnection:
	var link := WebRTCPeerConnection.new()
	if link.initialize({"iceServers": CoopWebRTC.ICE_SERVERS}) != OK:
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
