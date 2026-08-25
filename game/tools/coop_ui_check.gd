extends Node

## Drives the co-op screen the way a player does, in two real processes.
##
##   godot --path game res://tools/coop_ui_check.tscn -- --role=host
##   godot --path game res://tools/coop_ui_check.tscn -- --role=guest
##
## Distinct from coop_live_check, which drives `Coop` directly. This one goes in
## through the **menu**: it builds the real MainMenu, finds the real Co-op
## button, presses it, and presses Host or Join on the real screen. That is the
## path a player takes, and it is the path that did not exist until now - every
## underlying piece was gated while none of it could be reached.

const PORT_WAIT: float = 30.0

var _role: String = ""
var _failures: int = 0
var _menu: MainMenu = null
var _coop: CanvasLayer = null

## Set once the run has begun. From that moment this harness must not tear
## anything down: closing the peer would drop the run-start packet the guest
## is waiting for, and the scene it lives in is about to be replaced anyway.
var _entered_run: bool = false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.split("=")[1]
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true

	_menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(_menu)
	for _f: int in 12:
		await get_tree().process_frame

	# The button a player clicks. Found by name, not built here - if the menu
	# stops offering it, this fails, which is the point.
	var button: Button = _find_button(_menu, "Coop")
	_check(button != null, "the main menu must offer a Co-op button")
	if button == null:
		return _finish()
	button.emit_signal("pressed")
	await get_tree().process_frame
	_coop = _menu.get("_coop") as CanvasLayer
	_check(_coop != null and _coop.visible, "pressing it must open the co-op screen")
	if _coop == null:
		return _finish()

	if _role == "host":
		await _run_host()
	else:
		await _run_guest()
	# Skipped once the run has begun. `_finish` calls `Coop.leave()`, and closing
	# the peer discards anything not yet on the wire - including the packet that
	# tells the guest which world to roll. That is exactly how this failed:
	# the host asserted, tore down, and the guest sat in the menu and started a
	# run of its own with a different seed.
	if not _entered_run:
		_finish()


func _run_host() -> void:
	(_coop.get("_host_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(Coop.state() == Coop.State.HOSTING, "Host must open a session")
	_check(not Coop.local_address.is_empty(), "and report an address to share")
	print("[coop-ui] host listening on %s:%d" % [Coop.local_address, Balance.COOP_PORT])

	await _until(func() -> bool: return Coop.partner_present())
	_check(Coop.partner_present(), "the host must see the guest arrive")
	_check(Coop.player_count() == 2, "and count two players")

	# The button only unlocks with company, which is the rule it should express.
	var begin: Button = _coop.get("_begin_button") as Button
	_check(begin != null and not begin.disabled,
		"Begin must unlock once a friend has joined")
	print("[coop-ui] host sees partner; begin enabled")

	# The half that matters. Connecting two people who then sit in two menus is
	# not co-op; pressing Begin has to take *both* of them into the *same* run.
	begin.emit_signal("pressed")
	await _until(func() -> bool: return GameDirector.run_active)
	_check(GameDirector.run_active, "Begin must start the host's run")
	_entered_run = true
	print("[coop-ui] host run started, seed %d" % RunState.run_seed)
	# Give the socket a moment to actually send before anything else happens.
	await _hold(2.0)
	# Deliberately does not tear down or quit.
	#
	# `start_run` changes the scene and this harness *is* the current scene, so it
	# is freed a frame from now and will never reach `_finish` - same lesson as
	# `Coop` calling `goto_menu()` and deleting the harness it ran inside. Calling
	# `Coop.leave()` on the way out was worse than useless: it closed the peer
	# before the run-start packet had flushed, so the guest was never told and sat
	# in the menu rolling its own world.
	#
	# So the host says what it found and stops. The wrapper judges on the printed
	# assertions rather than on an exit code, because a process whose scene has
	# just been replaced has no clean exit to give.


func _run_guest() -> void:
	(_coop.get("_join_field") as LineEdit).text = "127.0.0.1"
	(_coop.get("_join_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(Coop.state() == Coop.State.CONNECTING, "Join must start a connection")

	await _until(func() -> bool: return Coop.state() == Coop.State.CONNECTED)
	_check(Coop.state() == Coop.State.CONNECTED,
		"the guest must connect through the menu, not just through code")
	_check(Coop.is_guest() and not Coop.is_host(), "and hold no authority")
	print("[coop-ui] guest connected via the menu")

	# Nothing is pressed here. The guest is *taken* into the run - there is no
	# second ready button to coordinate, and no way for the two to start
	# different worlds.
	await _until(func() -> bool: return GameDirector.run_active)
	_check(GameDirector.run_active,
		"the guest must be carried into the run when the host begins it")
	_check(RunState.run_seed > 0, "and be in a real run")
	_entered_run = true
	print("[coop-ui] guest carried into run, seed %d" % RunState.run_seed)
	# As above: the scene is about to be replaced, so report and go.


func _find_button(from: Node, wanted: String) -> Button:
	for child: Node in from.get_children():
		if child is Button and child.name == wanted:
			return child as Button
		var found: Button = _find_button(child, wanted)
		if found != null:
			return found
	return null


## Waits on a wall clock, not on accumulated frame deltas.
##
## Deltas were the first attempt and made this harness flaky: two game processes
## do not start together, and a run that happened to be slow to boot spent its
## whole budget before the other side was listening - then connected a moment
## after the check had already failed. The log showed a failure and a success for
## the same thing, in that order, which is the signature of a deadline that was
## never really measuring time.
func _until(done: Callable) -> void:
	var deadline: int = Time.get_ticks_msec() + int(PORT_WAIT * 1000.0)
	while Time.get_ticks_msec() < deadline and not bool(done.call()):
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _finish() -> void:
	Coop.leave()
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("[coop-ui] %s PASS" % _role)
	get_tree().quit(_failures)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[coop-ui] %s: %s" % [_role, why])
