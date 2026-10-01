extends Node

## **The trailer opens the game, once, and always lets go** (owner, 2026-10-01).
##
## Holds:
## - **The film ships**: `res://video/trailer.ogv` loads as a video and runs
##   between `MIN_SECONDS` and `MAX_SECONDS` - the owner asked for about 75.
## - **It opens only when welcome**: the setting on, the file there, not yet
##   shown this launch, and the screen-flash scale not turned down; off when any
##   of those is not so. The setting is declared and survives the save.
## - **Out of the splash and nowhere else**: the splash hands to
##   `GameDirector.after_splash`, which is the only caller of `play_trailer` but
##   the menu's own door - so leaving a road never replays it.
## - **It plays**: a real player advances its stream, on the music bus.
## - **Every way out works**: Escape, Enter, Space, a pad's A and Start, and a
##   click on Skip each end it as "skipped".
## - **It fails open**: a missing file ends it at once and a stream that stops
##   moving ends it inside the stall clock, never leaving a launch stuck on a
##   black screen.

const MIN_SECONDS: float = 60.0
const MAX_SECONDS: float = 90.0

var _checks: int = 0
var _failures: int = 0
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_film_ships()
	_test_it_opens_only_when_welcome()
	_test_out_of_the_splash_and_nowhere_else()
	await _test_it_plays()
	await _test_every_way_out()
	await _test_it_fails_open()
	for stage: String in ["ships", "welcome", "splash", "plays", "skips", "fails_open"]:
		_check(_reached.has(stage), ("'%s' never reached its end - it aborted partway, and every "
			+ "check it had not made yet is a check nobody made") % stage)
	MetaState.resume_saves()
	TrailerPlayer.play_in_tests = false
	GameDirector.trailer_shown = false
	if _failures == 0:
		print(("[trailer] PASS - %d checks: the film ships at its length, opens once and only "
			+ "when welcome, only out of the splash, plays on the music bus, every key and "
			+ "button skips it, and a missing film or a stalled stream goes on to the menu") % _checks)
	else:
		push_error("[trailer] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[trailer] " + why)


func _test_the_film_ships() -> void:
	_check(TrailerPlayer.available(), "%s is not in the build" % TrailerPlayer.VIDEO)
	var stream := load(TrailerPlayer.VIDEO) as VideoStream if TrailerPlayer.available() else null
	_check(stream != null, "%s does not load as a video" % TrailerPlayer.VIDEO)
	if stream != null:
		var probe := VideoStreamPlayer.new()
		add_child(probe)
		probe.stream = stream
		var length: float = probe.get_stream_length()
		_check(length >= MIN_SECONDS and length <= MAX_SECONDS,
			"the trailer runs %.1f s, outside %.0f-%.0f" % [length, MIN_SECONDS, MAX_SECONDS])
		probe.queue_free()
	_reached["ships"] = true


func _test_it_opens_only_when_welcome() -> void:
	var kept: Dictionary = MetaState.settings.duplicate(true)
	TrailerPlayer.play_in_tests = true
	GameDirector.trailer_shown = false
	UserSettings.set_value(UserSettings.TRAILER_KEY, true)
	UserSettings.set_value(UserSettings.FLASH_KEY, 1.0)
	_check(TrailerPlayer.should_autoplay(), "a launch with the setting on and the film there does not open with it")
	GameDirector.trailer_shown = true
	_check(not TrailerPlayer.should_autoplay(), "the trailer would open twice in one launch")
	GameDirector.trailer_shown = false
	UserSettings.set_value(UserSettings.TRAILER_KEY, false)
	_check(not TrailerPlayer.should_autoplay(), "the trailer opens with its setting off")
	UserSettings.set_value(UserSettings.TRAILER_KEY, true)
	UserSettings.set_value(UserSettings.FLASH_KEY, Balance.TRAILER_REDUCED_FLASH - 0.1)
	_check(not TrailerPlayer.should_autoplay(),
		"the trailer opens for a player who turned the screen flashes down")
	UserSettings.set_value(UserSettings.FLASH_KEY, 1.0)
	TrailerPlayer.play_in_tests = false
	_check(not TrailerPlayer.should_autoplay(), "the trailer would open headless, where there is no screen")
	# Declared, so it survives the save.
	_check(kept.has(UserSettings.TRAILER_KEY) or MetaState.settings.has(UserSettings.TRAILER_KEY),
		"'%s' is not a declared setting" % UserSettings.TRAILER_KEY)
	UserSettings.set_value(UserSettings.TRAILER_KEY, false)
	var text: String = MetaState.serialized_save()
	var parsed: Variant = JSON.parse_string(text)
	UserSettings.set_value(UserSettings.TRAILER_KEY, true)
	if parsed is Dictionary and (parsed as Dictionary).get("settings") is Dictionary:
		MetaState.call("_read_settings", (parsed as Dictionary)["settings"])
	_check(not UserSettings.trailer_at_startup(), "turning the trailer off did not survive the save")
	MetaState.settings = kept
	_reached["welcome"] = true


func _test_out_of_the_splash_and_nowhere_else() -> void:
	var splash: String = FileAccess.get_file_as_string("res://scenes/ui/splash.gd")
	_check(splash.contains("GameDirector.after_splash()"), "the splash does not hand to after_splash")
	var director: String = FileAccess.get_file_as_string("res://autoload/GameDirector.gd")
	var menu_at: int = director.find("func goto_menu() -> void:")
	var next_func: int = director.find("\nfunc ", menu_at + 10)
	var goto_menu_body: String = director.substr(menu_at, next_func - menu_at)
	_check(not goto_menu_body.contains("play_trailer") and not goto_menu_body.contains("after_splash"),
		"goto_menu opens the trailer - every way to the menu would replay it")
	var callers: PackedStringArray = []
	for path: String in _scripts("res://scenes") + _scripts("res://scripts") + _scripts("res://autoload"):
		var source: String = FileAccess.get_file_as_string(path)
		if source.contains("play_trailer") and not path.ends_with("GameDirector.gd"):
			callers.append(path)
	_check(callers.size() == 1 and callers[0].ends_with("main_menu.gd"),
		"play_trailer is reached from %s - it is the splash's and the menu door's alone" % ", ".join(callers))
	var player: String = FileAccess.get_file_as_string("res://autoload/GameDirector.gd")
	_check(player.contains("trailer_shown = true"), "play_trailer does not mark the launch as shown")
	_reached["splash"] = true


func _scripts(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_scripts(folder.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	return found


func _player(path: String = TrailerPlayer.VIDEO) -> TrailerPlayer:
	var player := (load("res://scenes/ui/trailer_player.tscn") as PackedScene).instantiate() as TrailerPlayer
	player.leaves = false
	player.video_path = path
	add_child(player)
	return player


func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await get_tree().process_frame


func _test_it_plays() -> void:
	var player: TrailerPlayer = _player()
	await _wait(1.2)
	var video := player.get_node_or_null("Video") as VideoStreamPlayer
	if video == null:
		for node: Node in player.find_children("*", "VideoStreamPlayer", true, false):
			video = node as VideoStreamPlayer
	_check(video != null, "the trailer player has no video in it")
	if video != null:
		_check(video.is_playing() and video.stream_position > 0.3,
			"the trailer did not play (playing %s, at %.2f s)" % [str(video.is_playing()), video.stream_position])
		_check(video.bus == AudioBuses.MUSIC, "the trailer plays on '%s', not the music bus" % video.bus)
		_check(video.expand, "the video is not letterboxed to the screen")
	_check(player.reason.is_empty(), "the trailer ended on its own a second in: %s" % player.reason)
	player.queue_free()
	await get_tree().process_frame
	_reached["plays"] = true


func _test_every_way_out() -> void:
	var presses: Array[Dictionary] = [
		{"name": "Escape", "event": _key(KEY_ESCAPE)},
		{"name": "Enter", "event": _key(KEY_ENTER)},
		{"name": "Space", "event": _key(KEY_SPACE)},
		{"name": "a pad's A", "event": _pad(JOY_BUTTON_A)},
		{"name": "a pad's Start", "event": _pad(JOY_BUTTON_START)},
	]
	for press: Dictionary in presses:
		var player: TrailerPlayer = _player()
		await _wait(0.3)
		get_viewport().push_input(press["event"] as InputEvent)
		await get_tree().process_frame
		_check(player.reason == "skipped", "%s did not skip the trailer (%s)"
			% [press["name"], player.reason if not player.reason.is_empty() else "still playing"])
		player.queue_free()
		await get_tree().process_frame
	# The Skip button, clicked where it is drawn.
	var clicked: TrailerPlayer = _player()
	await _wait(1.0)
	var skip := clicked.get_node_or_null("Skip") as Button
	_check(skip != null and skip.is_visible_in_tree(), "there is no Skip button on screen")
	if skip != null:
		var view: Rect2 = get_viewport().get_visible_rect()
		var rect: Rect2 = skip.get_global_rect()
		_check(view.encloses(rect), "the Skip button %s is not on the screen %s" % [rect, view])
		# **Nothing above it takes the click.** Headless, the viewport hovers
		# nothing at all (measured: `gui_get_hovered_control` is null over a
		# visible button), so a pushed click cannot be the test; what it would
		# have proved is that the button is the topmost thing that listens.
		_check(skip.mouse_filter == Control.MOUSE_FILTER_STOP, "the Skip button does not take clicks")
		var above: PackedStringArray = []
		for node: Node in clicked.find_children("*", "Control", true, false):
			var control := node as Control
			if control == skip or control.is_ancestor_of(skip) or skip.is_ancestor_of(control):
				continue
			if control.get_index() > skip.get_index() and control.get_parent() == skip.get_parent() 					and control.mouse_filter != Control.MOUSE_FILTER_IGNORE 					and control.get_global_rect().intersects(rect):
				above.append(String(control.name))
		_check(above.is_empty(), "%s lies over the Skip button and takes its clicks" % ", ".join(above))
		skip.pressed.emit()
		await get_tree().process_frame
		_check(clicked.reason == "skipped", "a click on Skip did not skip the trailer (%s)"
			% (clicked.reason if not clicked.reason.is_empty() else "still playing"))
	clicked.queue_free()
	await get_tree().process_frame
	_reached["skips"] = true


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _test_it_fails_open() -> void:
	var missing: TrailerPlayer = _player("res://video/no_such_trailer.ogv")
	await _wait(0.2)
	_check(missing.reason == "missing", "a missing film did not go straight on (%s)"
		% (missing.reason if not missing.reason.is_empty() else "still waiting"))
	missing.queue_free()
	# **A stream that stops moving** is let go of inside the stall clock. Made by
	# pausing a real one rather than by playing a broken file, because a broken
	# file is an engine error line - and the release bar fails on those.
	var frozen: TrailerPlayer = _player()
	await _wait(0.6)
	var video: VideoStreamPlayer = null
	for node: Node in frozen.find_children("*", "VideoStreamPlayer", true, false):
		video = node as VideoStreamPlayer
	if video != null:
		video.paused = true
	await _wait(Balance.TRAILER_STALL_SECONDS + 1.0)
	_check(frozen.reason == "stalled", "a stream that stopped moving held the launch for %.1f s (%s)"
		% [Balance.TRAILER_STALL_SECONDS + 1.0, frozen.reason if not frozen.reason.is_empty() else "still waiting"])
	frozen.queue_free()
	await get_tree().process_frame
	_reached["fails_open"] = true
