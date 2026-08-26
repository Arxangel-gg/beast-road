class_name PartyLog
extends VBoxContainer

## The party's shared feed: what people say, and what the game did about it.
##
## **One list, not two.** A chat window beside a combat log is two places to look
## during the moment when a player has least attention to spare, and the two are
## about the same thing anyway - "buying the mortar" and "Blue built a Glacial
## Mortar" belong in the order they happened.
##
## Everything is coloured by the seat that caused it, so *who* is answerable
## before the sentence is read. Nothing here is authored by a player except the
## chat lines, which are marked as speech by carrying a name.

## How many lines are kept. Old ones are dropped rather than scrolled, because a
## feed that has to be scrolled during a wave is a feed nobody reads.
const MAX_LINES: int = 40

## How long a line holds at full strength, and how long it takes to go. Long
## enough to catch a purchase you missed, short enough that the screen is clear
## when it matters.
const HOLD_SECONDS: float = 9.0
const FADE_SECONDS: float = 2.5

var _lines: Array[Label] = []
var _muted: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	EventBus.coop_chat.connect(_on_chat)
	EventBus.party_notice.connect(_on_notice)


## Somebody typed something. Speech, so it carries a name and lingers.
func _on_chat(slot: int, text: String) -> void:
	var seat: CoopParty.Seat = Coop.party().seat_for_slot(slot)
	var who: String = seat.name if seat != null else "Warden"
	_add("%s: %s" % [who, text], CoopParty.colour_of(slot), true)


## Something happened, and a seat is answerable for it.
func _on_notice(slot: int, text: String) -> void:
	_add(text, CoopParty.colour_of(slot), false)


func _add(text: String, shade: Color, speech: bool) -> void:
	if _muted or text.strip_edges().is_empty():
		return
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", 15 if speech else 14)
	line.add_theme_color_override("font_color", shade)
	line.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
	line.add_theme_constant_override("outline_size", 5)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(Balance.PARTY_LOG_WIDTH, 0.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	_lines.append(line)

	while _lines.size() > MAX_LINES:
		var oldest: Label = _lines.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Speech lingers; an event is a receipt and goes quietly.
	var fade: Tween = line.create_tween()
	fade.tween_interval(HOLD_SECONDS * (1.6 if speech else 1.0))
	fade.tween_property(line, "modulate:a", 0.0, FADE_SECONDS)
	fade.tween_callback(func() -> void:
		_lines.erase(line)
		line.queue_free())


## Hides everything without tearing it down, for a screenshot or a cinematic.
func set_muted(quiet: bool) -> void:
	_muted = quiet
	visible = not quiet
