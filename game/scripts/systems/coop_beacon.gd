class_name CoopBeacon
extends Node

## Finds games on the same network, so two people in one house type nothing.
##
## **A code is the answer for the internet and overkill for a living room.** The
## honest shape of "anyone can play with anyone" is three doors: a lobby for
## people on the same network, a code for people who are not, and a typed address
## for anyone who would rather. This is the first one.
##
## A host shouts a small packet on the broadcast address once a second; anybody
## on the co-op screen listens and lists what it hears. There is no server and
## nothing leaves the local network - a broadcast is not routed - so this needs
## no infrastructure and cannot be the thing that breaks when infrastructure
## does.
##
## **Everything in a beacon is untrusted.** It arrives from whatever else is on
## the network, so it is checked for shape, its strings are truncated and
## stripped of control characters, and objects are refused when it is decoded.
## The worst a hostile beacon can do is put a wrong name in a list.

## Its own port, not the game's. A listener must be able to bind while a host on
## the same machine holds the game port, which is exactly the two-process case.
const PORT: int = 45871

## How often a host shouts, and how long a silent game stays listed. The timeout
## is several beacons long so one dropped packet does not blink an entry out.
const BEACON_INTERVAL: float = 1.0
const BEACON_TIMEOUT: float = 4.0

## The tag every packet opens with. Anything else on this port is not ours.
const MAGIC: String = "beast-road-lobby"
const VERSION: int = 1

## Names are shown to a player, so they are bounded here rather than wherever
## they are drawn.
const MAX_NAME: int = 28

signal games_changed(games: Array)

## **One socket, and it may not get the port it wants.**
##
## Only one program on a machine can hold the well-known port, and two copies of
## this game on one desk is exactly how people test co-op - so whoever starts
## second binds an ephemeral port instead and would hear nothing at all if
## broadcasts were the only channel.
##
## So there are two: a host broadcasts, a listener *probes*, and whichever of
## them holds the well-known port answers the other directly. Across two machines
## both hold it and both channels work; on one machine exactly one holds it and
## the direct reply carries the rest.
var _socket: PacketPeerUDP = null
var _has_well_known: bool = false
var _announcing: bool = false
var _listening_now: bool = false
var _clock: float = 0.0
var _name: String = ""
var _port: int = Balance.COOP_PORT

## This host's identity for the length of one hosted game.
var _id: int = 0

## Keyed on the *host's* identity rather than on an address.
##
## One host is reached two ways on the same machine - over loopback and over the
## network - and keying on the address listed it twice, as two games with the
## same name at different addresses. An identity makes it one row, and the
## routable address is the one kept: a friend cannot dial 127.0.0.1.
##
## Values: {"id", "name", "address", "port", "players", "heard"}.
var _seen: Dictionary = {}


func _ready() -> void:
	set_process(false)


## Starts shouting that a game is open here. Called when hosting begins.
## True where a UDP socket can exist at all.
##
## A browser cannot open one - the sandbox allows WebSocket and WebRTC and
## nothing else - so every entry point here returns quietly on the web rather
## than failing six different ways. The web build finds its games through the
## public lobby list instead, which is HTTP and works everywhere.
static func possible() -> bool:
	return not OS.has_feature("web")


func announce(game_name: String, game_port: int) -> void:
	if not possible():
		return
	_name = _clean(game_name)
	_port = game_port
	# A new identity each time a game opens, so one host reached by two routes is
	# one row rather than two. See `_seen`.
	_id = randi()
	_announcing = true
	_open()
	_clock = 0.0
	set_process(true)


## Stops shouting. The entry ages out of every listener within BEACON_TIMEOUT.
func stop_announcing() -> void:
	_announcing = false
	_idle_if_done()


## Starts listening for games. Called when the co-op screen opens.
func listen() -> void:
	if not possible():
		return
	_listening_now = true
	_seen.clear()
	_open()
	set_process(true)


func stop_listening() -> void:
	_listening_now = false
	_seen.clear()
	_idle_if_done()


## Opens the one socket, preferring the well-known port. See `_socket`.
func _open() -> void:
	if _socket != null:
		return
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	_has_well_known = _socket.bind(PORT) == OK
	if _has_well_known:
		return
	# Somebody else on this machine holds it - the other copy of the game, which
	# is the whole case this exists for. A different port still sends, and still
	# receives whatever is addressed straight back at it.
	#
	# Named ports rather than `bind(0)`: Godot refuses port zero, so the first
	# version silently ended up with no socket at all and a listener that never
	# sent a single probe. It reported "holds the well-known port: false" and was
	# indistinguishable from one that was simply not being answered.
	for offset: int in range(1, 9):
		if _socket.bind(PORT + offset) == OK:
			return
	_socket = null


## Whether this beacon managed to take the well-known port.
##
## Public for the two-process check, which has to be able to say *which* of the
## two paths it exercised - the direct reply only happens for whichever copy
## started second.
func has_well_known_port() -> bool:
	return _has_well_known


## Everything heard recently, newest first.
func games() -> Array:
	var out: Array = []
	for entry: Variant in _seen.values():
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"]))
	return out


func _idle_if_done() -> void:
	if _announcing or _listening_now:
		return
	if _socket != null:
		_socket.close()
		_socket = null
	set_process(false)


func _process(delta: float) -> void:
	if _socket == null:
		return
	_clock -= delta
	if _clock <= 0.0:
		_clock = BEACON_INTERVAL
		if _announcing:
			_shout_to_everyone(_beacon_packet())
		if _listening_now:
			# A probe rather than silence. Whoever holds the well-known port
			# hears it and answers straight back, which is the only way a second
			# copy on the same machine ever finds the first.
			_shout_to_everyone({"magic": MAGIC, "version": VERSION,
				"probe": true})
	_collect()
	if _listening_now:
		_forget_the_silent(delta)


func _beacon_packet() -> Dictionary:
	return {
		"magic": MAGIC,
		"version": VERSION,
		"id": _id,
		"name": _name,
		"port": _port,
		"players": 2 if Coop.partner_present() else 1,
	}


## Sends to the network *and* to this machine.
##
## **Loopback is not an optimisation, it is the reliable half.** A broadcast is
## the only way to reach another machine and the least reliable way to reach this
## one: Windows will happily let a program broadcast and quietly drop what comes
## back until somebody clicks Allow on a firewall prompt. Two copies on one desk
## then find nothing, which is exactly how anybody tests co-op. Loopback is never
## filtered, so the same-machine case works before any prompt is answered.
##
## Both, every time. A packet arriving twice is deduplicated by address anyway,
## because a game is keyed on where it is rather than on how it was heard.
func _shout_to_everyone(packet: Dictionary) -> void:
	_send(packet, "255.255.255.255", PORT)
	_send(packet, "127.0.0.1", PORT)


func _send(packet: Dictionary, address: String, port: int) -> void:
	if _socket == null:
		return
	_socket.set_dest_address(address, port)
	_socket.put_packet(var_to_bytes(packet))


func _collect() -> void:
	var changed: bool = false
	while _socket.get_available_packet_count() > 0:
		var from: String = _socket.get_packet_ip()
		var from_port: int = _socket.get_packet_port()
		var raw: PackedByteArray = _socket.get_packet()
		# `allow_objects` left false, as everywhere else this game decodes
		# something that arrived over a wire.
		var decoded: Variant = bytes_to_var(raw)
		if not (decoded is Dictionary):
			continue
		var beacon: Dictionary = decoded
		if String(beacon.get("magic", "")) != MAGIC:
			continue
		if int(beacon.get("version", 0)) != VERSION:
			continue
		# Our own voice, coming back off the broadcast address. A host with the
		# co-op screen open would otherwise find itself and offer to join it.
		if _announcing and int(beacon.get("id", 0)) == _id and _id != 0:
			continue
		# Somebody is looking for games. If this machine has one, say so to them
		# directly rather than waiting for the next broadcast they may not hear.
		if bool(beacon.get("probe", false)):
			if _announcing and from_port > 0:
				_send(_beacon_packet(), from, from_port)
			continue
		if not _listening_now:
			continue
		var port: int = int(beacon.get("port", 0))
		if port <= 0 or port > 65535 or from.is_empty():
			continue
		var key: int = int(beacon.get("id", 0))
		if key == 0:
			# A beacon from a build that predates identities. Falling back to the
			# address keeps it findable rather than invisible.
			key = hash("%s:%d" % [from, port])
		var was: bool = _seen.has(key)
		# Loopback is a real route and a useless thing to hand a friend, so a
		# routable address always wins once one has been heard.
		var address: String = from
		if was and from.begins_with("127."):
			var known: String = String((_seen[key] as Dictionary)["address"])
			if not known.begins_with("127."):
				address = known
		_seen[key] = {
			"id": key,
			"name": _clean(String(beacon.get("name", ""))),
			"address": address,
			"port": port,
			"players": clampi(int(beacon.get("players", 1)), 1, 2),
			"heard": 0.0,
		}
		if not was:
			changed = true
	if changed:
		games_changed.emit(games())


func _forget_the_silent(delta: float) -> void:
	var gone: Array = []
	for key: Variant in _seen:
		var entry: Dictionary = _seen[key]
		entry["heard"] = float(entry["heard"]) + delta
		if float(entry["heard"]) > BEACON_TIMEOUT:
			gone.append(key)
	for key: Variant in gone:
		_seen.erase(key)
	if not gone.is_empty():
		games_changed.emit(games())


## A name fit to put in a list: bounded, single-line, and never empty.
static func _clean(text: String) -> String:
	var out: String = ""
	for character: String in text:
		# Control characters and newlines would break the row they are drawn in,
		# and this string arrives from the network.
		if character.unicode_at(0) >= 32 and out.length() < MAX_NAME:
			out += character
	out = out.strip_edges()
	return out if not out.is_empty() else "A warden's camp"
