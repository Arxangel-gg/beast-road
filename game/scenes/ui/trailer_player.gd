class_name TrailerPlayer
extends Control

## **The trailer, between the studio splash and the main menu** (owner,
## 2026-10-01: *"I want it implemented in the beginning of the game before the
## main menu transitions in"*), and from the menu's own door whenever asked.
##
## Played once a launch at most (`GameDirector.trailer_shown`), and only when it
## would be welcome: the setting is on, the file is there, this is not the web
## (a browser refuses sound before a gesture, so a startup trailer there plays
## silently or not at all), and the player has not turned the screen flashes
## down - a trailer is the flashiest minute of the game, and a player who asked
## for fewer flashes did not ask for that first.
##
## **It always lets go.** A missing or unreadable file, a stream that stops
## advancing, one that ends early or never ends - every one of those goes to the
## menu with a line in the log, because a launch that hangs on a video is worse
## than a launch with no video. And any of Escape, Enter, Space, a pad's face or
## Start button, or the Skip button (a click or a tap) ends it at once.

const VIDEO: String = "res://video/trailer.ogv"

## **Seams for `trailer_check`.** Headless the startup trailer is never played
## (there is no screen), and a gate that wants to drive the decision says so;
## `leaves` lets a gate end the trailer without the scene being replaced.
static var play_in_tests: bool = false
var leaves: bool = true
## The file this player tries to play; a gate points it at a missing or broken
## one to prove the player fails open.
var video_path: String = VIDEO

signal ended(reason: String)

var _player: VideoStreamPlayer = null
var _skip: Button = null
var _cover: ColorRect = null
var _done: bool = false
var _last_position: float = -1.0
var _still: float = 0.0
var _elapsed: float = 0.0
var _ceiling: float = 0.0
var _started: bool = false
## Why it ended: "finished", "skipped", "missing", "stalled", "stopped", "timeout".
var reason: String = ""


## Whether the file is shipped in this build.
static func available() -> bool:
	return ResourceLoader.exists(VIDEO)


## Whether the trailer opens this launch, on the way out of the splash.
static func should_autoplay() -> bool:
	if GameDirector.trailer_shown:
		return false
	if DisplayServer.get_name() == "headless" and not play_in_tests:
		return false
	if OS.has_feature("web"):
		return false
	if not UserSettings.trailer_at_startup():
		return false
	if JuiceDirector.flash_scale() < Balance.TRAILER_REDUCED_FLASH:
		return false
	return available()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	# Letterboxed rather than stretched: the film is 16:9 and a phone is not.
	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	_player = VideoStreamPlayer.new()
	_player.name = "Video"
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The trailer's sound is mostly its score, so it answers the music slider.
	_player.bus = AudioBuses.MUSIC
	frame.add_child(_player)
	_build_skip()
	# The Skip button answers being touched as every button in the game does.
	UiJuice.enrol.call_deferred(get_tree(), self)
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cover)
	var reveal: Tween = create_tween()
	reveal.tween_property(_cover, "color:a", 0.0, Balance.TRAILER_FADE_SECONDS)
	MusicPlayer.stop()
	_start.call_deferred()


func _start() -> void:
	var stream: VideoStream = null
	if ResourceLoader.exists(video_path):
		stream = load(video_path) as VideoStream
	if stream == null:
		_end("missing")
		return
	_player.stream = stream
	_player.play()
	_started = true
	var length: float = _player.get_stream_length()
	_ceiling = (length if length > 0.0 else Balance.TRAILER_LONGEST) + Balance.TRAILER_GRACE_SECONDS


func _build_skip() -> void:
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = "Skip"
	_skip.focus_mode = Control.FOCUS_ALL
	_skip.tooltip_text = "Escape, Enter or Space, or a pad's A, B or Start"
	# A thumb's size on a touch layout, a button's otherwise.
	_skip.custom_minimum_size = Vector2(176.0, 92.0) if TouchInput.is_showing() \
		else Vector2(150.0, 52.0)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -Balance.TRAILER_SKIP_MARGIN
	_skip.offset_bottom = -Balance.TRAILER_SKIP_MARGIN
	_skip.offset_left = _skip.offset_right - _skip.custom_minimum_size.x
	_skip.offset_top = _skip.offset_bottom - _skip.custom_minimum_size.y
	_skip.modulate.a = 0.0
	IconKit.on_button(_skip, "pressure_arrow", 22)
	_skip.pressed.connect(func() -> void: skip())
	add_child(_skip)
	var show: Tween = create_tween()
	show.tween_interval(Balance.TRAILER_SKIP_DELAY)
	show.tween_property(_skip, "modulate:a", Balance.TRAILER_SKIP_ALPHA, 0.4)


## Ends the trailer at the player's word.
func skip() -> void:
	_end("skipped")


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			skip()
		return
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed:
		if pad.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK]:
			get_viewport().set_input_as_handled()
			skip()
		return
	# A tap or a click anywhere else brings the Skip button up to full, so a
	# player who did not see it in the corner is shown where it is.
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if (touch != null and touch.pressed) or (click != null and click.pressed):
		_skip.modulate.a = 1.0
		_skip.grab_focus()


func _process(delta: float) -> void:
	if _done or not _started:
		return
	_elapsed += delta
	var at: float = _player.stream_position
	if at > _last_position + 0.0001:
		_last_position = at
		_still = 0.0
	else:
		_still += delta
	if _still >= Balance.TRAILER_STALL_SECONDS:
		_end("stalled")
	elif not _player.is_playing() and _elapsed > 1.0:
		_end("stopped")
	elif _elapsed >= _ceiling:
		_end("timeout")


func _end(why: String) -> void:
	if _done:
		return
	_done = true
	reason = why
	print("[trailer] ended: %s at %.1fs" % [why, _elapsed])
	if _player != null:
		_player.stop()
	ended.emit(why)
	if not leaves:
		return
	# A failure goes straight on; an ending the player saw fades to black first.
	var seen: bool = why == "finished" or why == "skipped"
	if not seen or not is_inside_tree():
		GameDirector.goto_menu()
		return
	var fade: Tween = create_tween()
	fade.tween_property(_cover, "color:a", 1.0, Balance.TRAILER_FADE_SECONDS)
	fade.tween_callback(GameDirector.goto_menu)

