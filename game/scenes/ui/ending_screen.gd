class_name EndingScreen
extends CanvasLayer

## The ending (GDD v4 §"Final Ascent - Crown of the World").
##
## v4 is explicit that breaking the last chain "transitions directly into the
## ending without a post-victory loot menu", so this plays the moment the
## Chainmaker falls rather than after a debrief.
##
## Lines are authored here rather than in data because there is exactly one
## ending and it is four sentences long. If a second ending ever exists, this
## moves to `.tres` like everything else (CLAUDE.md §3).

const LINES: Array[String] = [
	"The last chain gives.",
	"Yuri stands, and the mountain is quiet for the first time in a long age.",
	"The town on his back is still burning its lamps. Somebody down there is"
		+ " already asking what the next road looks like.",
]

## How long each line takes to arrive, and how long the whole thing waits before
## offering the choice. Short: this is a curtain, not a cutscene.
const LINE_FADE: float = 0.9
const LINE_GAP: float = 1.5

@export var backdrop: TextureRect
@export var title: Label
@export var body: Label
@export var finish_button: Button
@export var credits_button: Button
@export var credits: Label

## The roll itself. Authored here for the same reason the ending lines are: there
## is one of it, it is short, and a `.tres` for a single block of text is filing
## rather than data-driving.
const CREDITS: Array[String] = [
	"BEAST ROAD",
	"",
	"Design and direction",
	"Arxangel",
	"",
	"Built with Godot 4",
	"Pixel art generated with PixelLab",
	"",
	"Thank you for riding.",
]

## Seconds the roll takes to cross the panel. Skippable throughout - a credit
## roll nobody can stop is a credit roll nobody watches twice.
const CREDITS_SCROLL: float = 22.0

var _playing: bool = false
var _rolling: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# A scrim between the art and the words. The summit is a bright sky and pale
	# snow, and white text on it was legible only where a mountain happened to
	# sit behind a line - which is not something the layout can guarantee.
	var scrim := ColorRect.new()
	scrim.color = Color(0.04, 0.06, 0.10, 0.52)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	move_child(scrim, 1)
	credits.text = "
".join(CREDITS)
	credits.visible = false
	credits_button.pressed.connect(_roll_credits)
	finish_button.pressed.connect(func() -> void:
		_dismiss()
		GameDirector.end_run(true))


## Plays the ending before the completed run's debrief.
func play() -> void:
	if _playing:
		return
	_playing = true
	visible = true
	get_tree().paused = true

	title.text = "The chains are broken"
	body.text = ""
	finish_button.disabled = true

	for index: int in LINES.size():
		body.text += ("\n\n" if index > 0 else "") + LINES[index]
		body.modulate.a = 0.0
		var fade: Tween = create_tween()
		fade.tween_property(body, "modulate:a", 1.0, LINE_FADE)
		await get_tree().create_timer(LINE_GAP, true, false, true).timeout

	finish_button.disabled = false
	finish_button.grab_focus()


## Rolls the credits over the ending, and stops on a second press.
##
## Over it rather than on their own screen: the summit art is the last thing the
## player earned and there is no reason to take it away to show them a list.
func _roll_credits() -> void:
	if _rolling:
		_end_credits()
		return
	_rolling = true
	credits_button.text = "Skip credits"
	credits.visible = true
	body.visible = false

	var span: float = float(get_viewport().get_visible_rect().size.y)
	credits.position.y = span
	var roll: Tween = create_tween()
	roll.tween_property(credits, "position:y", -credits.size.y - span * 0.2, CREDITS_SCROLL)
	roll.tween_callback(_end_credits)


func _end_credits() -> void:
	_rolling = false
	credits_button.text = "Credits"
	credits.visible = false
	body.visible = true


func _dismiss() -> void:
	_playing = false
	_rolling = false
	visible = false
	get_tree().paused = false
