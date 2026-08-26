extends Node

## Two processes finding each other on the local network, which is the only way
## this can be tested at all.
##
##   godot --headless --path game res://tools/lobby_check.tscn -- --role=host
##   godot --headless --path game res://tools/lobby_check.tscn -- --role=listen
##
## `coop_check.tscn` covers the packet shape, the name cleaning and the ageing
## out, all in one process. What it cannot cover is the part that broke: only one
## program on a machine can hold the well-known port, so the second copy binds an
## ephemeral one and hears nothing unless the first answers it directly. That is
## invisible until there genuinely are two processes.
##
## Run in both orders. Whoever starts first takes the port, and the two cases are
## different code paths - broadcast in one direction, a direct reply in the other.

const FIND_SECONDS: float = 15.0

var _beacon: CoopBeacon = null
var _role: String = "listen"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.split("=")[1]
	_beacon = CoopBeacon.new()
	add_child(_beacon)

	if _role == "host":
		_beacon.announce("Warden \u00b7 level 9", Balance.COOP_PORT)
		print("[lobby] host announcing, holds the well-known port: %s"
			% str(_beacon.has_well_known_port()))
		# Outlives the listener deliberately: it is the thing being looked for.
		await _hold(FIND_SECONDS + 4.0)
		print("[lobby] host PASS")
		get_tree().quit(0)
		return

	_beacon.listen()
	print("[lobby] listening, holds the well-known port: %s"
		% str(_beacon.has_well_known_port()))
	var deadline: int = Time.get_ticks_msec() + int(FIND_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline and _beacon.games().is_empty():
		await get_tree().process_frame
	var found: Array = _beacon.games()
	if found.is_empty():
		printerr("[lobby] listen: no game found on this network in %.0fs"
			% FIND_SECONDS)
		get_tree().quit(1)
		return
	if found.size() != 1:
		printerr("[lobby] listen: one host must be one row, got %d" % found.size())
		get_tree().quit(1)
		return
	var game: Dictionary = found[0]
	# A friend cannot dial 127.0.0.1, so the routable address has to be the one
	# that survives when a host is heard over both routes.
	if String(game["address"]).begins_with("127."):
		printerr("[lobby] listen: kept the loopback address, which is no use to "
			+ "anybody else")
		get_tree().quit(1)
		return
	print("[lobby] found '%s' at %s:%d" % [String(game["name"]),
		String(game["address"]), int(game["port"])])
	print("[lobby] listen PASS")
	get_tree().quit(0)


func _hold(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
