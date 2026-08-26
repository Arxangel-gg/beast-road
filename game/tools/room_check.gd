extends Node

## Two processes meeting through a **real room**, on the live service.
##
##   godot --headless --path game res://tools/room_check.tscn -- --role=host
##   godot --headless --path game res://tools/room_check.tscn -- --role=guest
##
## Driven by `tools/room.sh`. This is the only harness that exercises the whole
## WebRTC path as a player uses it: open a room, publish the code, enter it by
## code, exchange offer and answer *through the table*, gather routes, open a
## data channel, carry a packet.
##
## **`webrtc_check` deliberately does not do this**, and could not have caught
## what this is here for. That one hands the two connections straight to each
## other to test the transport in isolation - so when the offer moved to the
## guest and the host went on ignoring offers, it still reported a healthy
## connection while every real join timed out. The routing only exists on this
## path.
##
## Talks to the live project, so it is not in CI: a check that fails when a
## third party is down teaches everyone to ignore it.

const SETTLE: float = 60.0

var _role: String = ""
var _failures: int = 0
var _handshake: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.split("=")[1]
		elif argument.begins_with("--code-file="):
			_handshake = argument.split("=")[1]

	Coop.webrtc().progress.connect(func(text: String) -> void:
		print("[room] %s: %s" % [_role, text]))
	Coop.webrtc().failed.connect(func(why: String) -> void:
		_check(false, "handshake failed: %s" % why))

	if _role == "host":
		await _run_host()
	else:
		await _run_guest()
	_finish()


func _run_host() -> void:
	_check(CoopWebRTC.available(), "the host build must have WebRTC")
	var code: String = Coop.host_room()
	_check(code.length() == 6, "opening a room must return a six-character code")
	if code.length() != 6:
		return
	print("[room] host opened %s" % code)
	# Handed over on disk, because the guest is another process and the whole
	# point is that it joins by nothing but the code.
	var file: FileAccess = FileAccess.open(_handshake, FileAccess.WRITE)
	if file != null:
		file.store_string(code)
		file.close()
	await _until(func() -> bool: return Coop.partner_present())
	_check(Coop.partner_present(), "the host must see the guest arrive")
	# Outlives the guest: it is measuring this session at the same moment.
	await _hold(12.0)


func _run_guest() -> void:
	_check(CoopWebRTC.available(), "the guest build must have WebRTC")
	# **A member, not a local.** GDScript lambdas capture locals by *value*, so
	# assigning to a captured `var` inside one writes to the closure's own copy
	# and the outer variable never changes - the wait returned instantly with an
	# empty code and the guest never dialled anything.
	await _until(func() -> bool: return _read_code().length() == 6)
	var code: String = _read_code()
	_check(code.length() == 6, "the guest needs a code to join with")
	if code.length() != 6:
		return
	print("[room] guest joining %s" % code)
	Coop.join_room(code)

	await _until(func() -> bool: return Coop.state() == Coop.State.CONNECTED)
	_check(Coop.state() == Coop.State.CONNECTED,
		"the guest must reach CONNECTED through the room, state %d"
			% Coop.state())
	if Coop.state() != Coop.State.CONNECTED:
		return

	# Connected is not the same as usable. `CoopRelay` speaks `send_bytes`, so a
	# session that cannot carry one is a session that carries no facts at all.
	var relay: CoopRelay = Coop.relay()
	_check(relay != null, "a connected session must have a relay")
	await _hold(3.0)
	_check(Coop.partner_present(), "and must still see the host after settling")
	print("[room] guest connected through the room")


## The code the host wrote, or "" if it has not written one yet.
func _read_code() -> String:
	if not FileAccess.file_exists(_handshake):
		return ""
	var file: FileAccess = FileAccess.open(_handshake, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text().strip_edges()
	file.close()
	return text


func _until(done: Callable) -> void:
	var deadline: int = Time.get_ticks_msec() + int(SETTLE * 1000.0)
	while Time.get_ticks_msec() < deadline and not bool(done.call()):
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	# **FAIL, spelled out.** Progress lines are `[room] host: Connecting...` and
	# a failure was `[room] host: could not...` - the same shape, so the runner's
	# grep counted every status message as a failure and reported "2 of 2 failed"
	# under two passing roles.
	printerr("[room] FAIL %s: %s" % [_role, why])


func _finish() -> void:
	Coop.leave()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[room] %s PASS" % _role)
	get_tree().quit(_failures)
