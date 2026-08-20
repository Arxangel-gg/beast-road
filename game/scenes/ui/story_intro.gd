class_name StoryIntro
extends CanvasLayer

## The opening cinematic, shown once before a player's first run.
##
## Four panels and four lines: what Yuri is, what is chasing them, who the player
## is, and where the road goes. That is the whole premise (GDD §6), and it is the
## minimum a player needs before they are asked to defend four roads for an hour.
##
## **Skippable from the first frame, and shown once.** A cinematic that cannot be
## skipped is a cinematic that gets resented on the second run, and one that
## replays every launch is worse. It is gated on a MetaState flag rather than on
## `runs_started`, because a player who quits during the intro has not seen it
## and should get it again.
##
## Timed on real seconds rather than frames: the intro runs with the tree paused
## so nothing behind it ticks, and a frame-counted fade would run at whatever
## speed the machine happened to manage.

signal finished()

## One panel: an image, a heading and a line of prose.
const PANELS: Array[Dictionary] = [
	{
		"art": "res://art/story/story_worldstrider.png",
		"title": "The Worldstriders",
		"line": "Beasts large enough to carry soil, water and a settlement across"
			+ " their backs. Yuri is one of the last.",
	},
	{
		"art": "res://art/story/story_host.png",
		"title": "The Chainbound Host",
		"line": "A warlord holds the summit, and his chain-magic drives the clans"
			+ " after us. They are not evil. They are compelled.",
	},
	{
		"art": "res://art/story/story_warden.png",
		"title": "The Warden",
		"line": "Four roads climb Yuri's flanks. You are the one defender bound"
			+ " to hold them.",
	},
	{
		"art": "res://art/story/story_summit.png",
		"title": "The Crown of the World",
		"line": "There is a beacon at the top of the world that can break the"
			+ " chain. Walk him there.",
	},
]

const FADE: float = 1.4

## How long a panel holds once its text has fully arrived.
##
## Was 3.4 measured from the *start* of the panel, which meant the prose had
## about a second and a half of legible time - less than it takes to read two
## lines. It now starts counting when the line finishes fading in, so this is
## reading time rather than total time. [TUNE]
const HOLD: float = 5.2

const TITLE_RISE: float = 26.0

## A slow push on the art while a panel holds, so a still image is not a still
## image. Fraction of its size, over the whole panel.
const KEN_BURNS: float = 0.055

## Seconds Escape must be held to abandon the whole cinematic.
##
## Held rather than tapped, and separate from advancing. Tapping any key skips
## to the *next* panel, which is what someone re-reading a line they have already
## seen wants; skipping the whole thing is a different intent and should take a
## deliberate act, or a player who taps twice to hurry up finds they have thrown
## away the opening entirely.
const SKIP_HOLD: float = 0.9

var _root: Control
var _art: TextureRect
var _title: Label
var _line: Label
var _hint: Label
var _running: bool = false
var _skipped: bool = false

## Set when the player asks for the next panel rather than the whole skip.
var _advance: bool = false

## How long Escape has been held this frame run.
var _held: float = 0.0
var _hold_bar: ProgressBar


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	# The panel keeps its aspect and sits above the text rather than behind it.
	# Pixel art stretched to an arbitrary window is the fastest way to make a
	# careful piece of art look cheap.
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_art.add_to_group(Graphics.FILTER_GROUP)
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.modulate.a = 0.0
	_root.add_child(_art)

	# The art fills the frame and the text sits on a scrim over it.
	#
	# Reserving a strip for the text instead left the art in a box wider than
	# 16:9, so a 16:9 panel was pillarboxed with black down both sides on a 16:9
	# monitor - the one shape it should have fitted exactly. Filling and scrimming
	# also reads as a cinematic rather than as an image with a caption.
	var scrim := TextureRect.new()
	scrim.texture = _scrim_texture()
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.offset_top = -300.0
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	column.offset_left = 140.0
	column.offset_right = -140.0
	column.offset_top = -210.0
	column.offset_bottom = -76.0
	column.add_theme_constant_override("separation", 14)
	_root.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_title)

	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 21)
	_line.add_theme_color_override("font_color", Color("cdc3ad"))
	column.add_child(_line)

	_hint = Label.new()
	_hint.text = "Any key: next   ·   hold Esc: skip"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -320.0
	_hint.offset_top = -46.0
	_hint.offset_right = -28.0
	_hint.offset_bottom = -18.0
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.58, 0.50, 0.75))
	_root.add_child(_hint)

	# A visible fill while Escape is held, so holding reads as doing something
	# rather than as the key not working.
	_hold_bar = ProgressBar.new()
	_hold_bar.show_percentage = false
	_hold_bar.max_value = SKIP_HOLD
	_hold_bar.value = 0.0
	_hold_bar.custom_minimum_size = Vector2(0.0, 4.0)
	_hold_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hold_bar.offset_left = -320.0
	_hold_bar.offset_top = -16.0
	_hold_bar.offset_right = -28.0
	_hold_bar.offset_bottom = -12.0
	_hold_bar.modulate = Color(0.91, 0.64, 0.24, 0.0)
	_root.add_child(_hold_bar)


## A one-pixel-wide vertical gradient, transparent to near-black.
##
## Built rather than authored: it is two colours and a direction, and an asset
## file for that is a file somebody has to find when the palette changes.
func _scrim_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.03, 0.05, 0.0))
	gradient.set_color(1, Color(0.02, 0.03, 0.05, 0.94))
	var fill := GradientTexture2D.new()
	fill.gradient = gradient
	fill.width = 4
	fill.height = 256
	fill.fill_from = Vector2.ZERO
	fill.fill_to = Vector2(0.0, 1.0)
	return fill


## Whether this account has already been shown the opening.
static func already_seen() -> bool:
	return MetaState.story_intro_seen


func play() -> void:
	if _running:
		return
	_running = true
	_skipped = false
	visible = true
	get_tree().paused = true

	Sfx.play("sfx_story_open", 0.0)
	for panel: Dictionary in PANELS:
		if _skipped:
			break
		await _show(panel)

	# Marked seen whether it was watched or skipped. Skipping is a decision about
	# this account, not about this launch.
	MetaState.story_intro_seen = true
	MetaState.save_game()

	visible = false
	get_tree().paused = false
	_running = false
	finished.emit()


func _show(panel: Dictionary) -> void:
	var path: String = String(panel["art"])
	_art.texture = load(path) if ResourceLoader.exists(path) else null
	_title.text = String(panel["title"])
	_line.text = String(panel["line"])

	var start: float = _title.position.y
	_title.position.y = start + TITLE_RISE
	for node: CanvasItem in [_art, _title, _line]:
		node.modulate.a = 0.0

	# A slow push across the whole panel. A still image held for seven seconds
	# reads as the game having frozen; the drift is what says it is a scene.
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2.ONE
	var drift: Tween = create_tween()
	drift.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	drift.tween_property(_art, "scale", Vector2.ONE * (1.0 + KEN_BURNS),
		FADE * 2.0 + HOLD)

	var rise: Tween = create_tween()
	rise.set_parallel(true)
	rise.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	rise.tween_property(_art, "modulate:a", 1.0, FADE)
	rise.tween_property(_title, "modulate:a", 1.0, FADE * 0.8)
	rise.tween_property(_title, "position:y", start, FADE)
	rise.tween_property(_line, "modulate:a", 1.0, FADE).set_delay(FADE * 0.4)
	Sfx.play_group("story_panel")

	# The hold begins once the *line* has finished arriving, not once the panel
	# started. Counting from the start gave the prose about a second and a half
	# of legible time, which is less than it takes to read it.
	await _wait(FADE * 1.4)
	if _skipped or await _interruptible(HOLD):
		drift.kill()
		if _skipped:
			return

	var out: Tween = create_tween()
	out.set_parallel(true)
	out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for node: CanvasItem in [_art, _title, _line]:
		out.tween_property(node, "modulate:a", 0.0, FADE * 0.6)
	await _wait(FADE * 0.6)


## A timer that runs while the tree is paused, since the intro pauses it.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Waits, but returns early if the player asked for the next panel.
##
## Polled rather than awaited on a signal because the wait has to end on *either*
## the clock or the player, and a plain timer cannot be cancelled. Returns true
## when it was cut short.
func _interruptible(seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		if _advance or _skipped:
			_advance = false
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return false


## Escape held long enough abandons the whole cinematic.
func _process(delta: float) -> void:
	if not _running:
		return
	if Input.is_key_pressed(KEY_ESCAPE):
		_held += delta
		if _hold_bar != null:
			_hold_bar.value = _held
			_hold_bar.modulate.a = clampf(_held / SKIP_HOLD, 0.0, 1.0)
		if _held >= SKIP_HOLD:
			_skipped = true
	else:
		_held = 0.0
		if _hold_bar != null:
			_hold_bar.value = 0.0
			_hold_bar.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _running or _skipped:
		return
	var pressed: bool = (event is InputEventKey and event.is_pressed()) \
		or (event is InputEventMouseButton and event.is_pressed()) \
		or (event is InputEventJoypadButton and event.is_pressed())
	if pressed:
		get_viewport().set_input_as_handled()
		# A tap moves on; only a held Escape abandons the whole thing, which
		# `_process` decides. Tapping used to skip everything, so a player
		# hurrying past a line they had read threw away the rest of the opening.
		_advance = true
		Sfx.play("sfx_ui_move", 0.0)
