class_name SpeechBubble
extends Node2D

## **A line over somebody's head** (2026-10-07): what a mercenary says, said
## where it stands. One a body, reused; it rises a little, holds, and fades.
## An alert is warmer and holds longer. A look: nothing reads it.

var _label: Label = null
var _left: float = 0.0
var _life: float = 0.0


## Says `text` over `body`, building its bubble the first time.
static func say(body: Node2D, text: String, alert: bool = false) -> SpeechBubble:
	if body == null or not is_instance_valid(body):
		return null
	var bubble := body.get_node_or_null("SpeechBubble") as SpeechBubble
	if bubble == null:
		bubble = SpeechBubble.new()
		bubble.name = "SpeechBubble"
		body.add_child(bubble)
	bubble.show_line(text, alert)
	return bubble


## The line it is showing, or "" once it has faded.
func line() -> String:
	return _label.text if _label != null and _left > 0.0 else ""


func _ready() -> void:
	if _label != null:
		return
	z_index = 40
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(Balance.MERC_BUBBLE_WIDTH, 0.0)
	_label.position = Vector2(-Balance.MERC_BUBBLE_WIDTH * 0.5, -Balance.MERC_BUBBLE_HEIGHT)
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.92))
	UiFonts.set_role(_label, UiFonts.Role.BODY, 15)
	add_child(_label)
	visible = false


func show_line(text: String, alert: bool) -> void:
	if _label == null:
		_ready()
	_label.text = text
	_label.add_theme_color_override("font_color", Color("ffd27a") if alert else Color("f2ead8"))
	_life = Balance.MERC_BUBBLE_SECONDS * (1.4 if alert else 1.0)
	_left = _life
	visible = true
	modulate.a = 1.0


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	var through: float = 1.0 - _left / maxf(_life, 0.001)
	position.y = -through * 10.0
	modulate.a = clampf(_left / 0.5, 0.0, 1.0)
	if _left <= 0.0:
		visible = false
