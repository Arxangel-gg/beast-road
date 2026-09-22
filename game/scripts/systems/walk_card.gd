class_name WalkCard
extends PanelContainer

## **The card the Walk speaks through.**
##
## Owner brief, 2026-09-17: narration "that helps the player understand and
## identify everything easily at the right time in the right way like the
## runescape tutorial world".
##
## **A card at the edge, not a banner across the middle**, which is the rule the
## first-run coach was built under and the reason it is a narrow column: a wide
## centred panel is a modal in everything but name, sitting over the very thing
## it is describing. This one is the same corner, a little taller, because a
## stop says an instruction and sometimes a line of the world underneath it.
##
## **Nothing is modal and nothing has to be acknowledged.** The card carries
## *Got it*, which dismisses the words and never the stop - the objective is
## still the objective - and *Skip the walk*, which is offered from the first
## frame and confirmed once. A tutorial you cannot leave is a tutorial people
## remember for the wrong reason.

signal dismissed()
signal skip_asked()

const WIDTH: float = 380.0
## The card's height, and the air kept between its foot and the HUD's own band.
const HEIGHT: float = 226.0
const BOTTOM_AIR: float = 16.0
const FADE: float = 0.22

var _instruction: Label = null
var _aside: Label = null
var _skip: Button = null
var _confirming: bool = false
var _left: float = 0.0


func _ready() -> void:
	name = "WalkCard"
	visible = false
	modulate.a = 0.0
	# The same corner the coach uses, and for the same reasons: the right belongs
	# to the build panel, the bottom strip to the command bar, and the top to the
	# seed line, the resources and the boss bar.
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 24.0
	offset_right = 24.0 + WIDTH
	# **Above the HUD's command row, by the HUD's own measure.** The card sat
	# 24px off the bottom edge, and the bottom edge is where the ability slots
	# and the action buttons live - so the first thing the valley said was
	# written across the first thing it asked the player to press (owner,
	# 2026-09-21). `HUD.bottom_reserve` is the one number the HUD measures its
	# own band by, on a desktop and on a phone, so the two cannot drift apart.
	#
	# Both offsets. With a bottom preset the top offset is measured from the
	# bottom edge too, so leaving it at zero describes a box running from the
	# bottom of the screen upwards past its own top - which is how the coach's
	# card ended up in the top-left corner twice.
	var clear: float = HUD.bottom_reserve() + BOTTOM_AIR
	offset_top = -(clear + HEIGHT)
	offset_bottom = -clear
	mouse_filter = Control.MOUSE_FILTER_PASS

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_instruction = Label.new()
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.add_theme_font_size_override("font_size", 16)
	_instruction.add_theme_color_override("font_color", Color("f2e6d0"))
	column.add_child(_instruction)

	_aside = Label.new()
	_aside.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aside.add_theme_font_size_override("font_size", 14)
	_aside.add_theme_color_override("font_color", Color("9aa5a2"))
	column.add_child(_aside)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	var got := Button.new()
	got.text = "Got it"
	got.custom_minimum_size = Vector2(0.0, 36.0)
	got.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	got.pressed.connect(func() -> void:
		hide_card()
		dismissed.emit())
	row.add_child(got)

	_skip = Button.new()
	_skip.text = "Skip the walk"
	_skip.custom_minimum_size = Vector2(0.0, 36.0)
	_skip.pressed.connect(_on_skip)
	row.add_child(_skip)


## Says a stop. `aside` may be empty - a replay shows instructions only, because
## a player walking it again wants the rules and not the story a second time.
func say(instruction: String, aside: String, seconds: float) -> void:
	_instruction.text = instruction
	_aside.text = aside
	_aside.visible = not aside.strip_edges().is_empty()
	_left = maxf(seconds, 0.0)
	_confirming = false
	_skip.text = "Skip the walk"
	visible = true
	set_process(true)
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)


func hide_card() -> void:
	_left = 0.0
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE)
	fade.tween_callback(func() -> void:
		visible = false
		set_process(false))


## **Confirmed once**, because leaving a tutorial by a misclick is a thing a
## player only finds out about later.
func _on_skip() -> void:
	if not _confirming:
		_confirming = true
		_skip.text = "Skip? You can walk it again from the Hold."
		return
	_confirming = false
	skip_asked.emit()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		hide_card()
