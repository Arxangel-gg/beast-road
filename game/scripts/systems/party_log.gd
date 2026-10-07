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
##
## **League's log, as of 2026-10-01** (owner: *"make it more like league of
## legends"*). Every line carries the road's clock, a speaker's name is in their
## seat's colour and their words in the log's own light, `/me` and `/roll` read
## as what they are, and the log is a *history*: a line that has faded is hidden
## rather than thrown away, and opening the chat brings the last lines back at
## full strength over a dark backing, so a player who looks away during a wave
## can read what they missed by pressing Enter.

## How many lines are kept. Old ones are dropped rather than scrolled, because a
## feed that has to be scrolled during a wave is a feed nobody reads.
const MAX_LINES: int = 40

## How long a line holds at full strength, and how long it takes to go. Long
## enough to catch a purchase you missed, short enough that the screen is clear
## when it matters.
const HOLD_SECONDS: float = 9.0
const FADE_SECONDS: float = 2.5

## The lines kept: each `{node, born, speech, slot}`, oldest first.
var _lines: Array[Dictionary] = []
var _muted: bool = false
## Whether the chat box is open, so the log reads as its history.
var _open: bool = false
## Seats whose speech this screen does not draw (`/mute`). This machine's own
## choice, never sent: muting somebody is not something to announce to them.
var muted_slots: Dictionary = {}
var _backing: StyleBoxFlat = null


func _ready() -> void:
	add_theme_constant_override("separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	EventBus.coop_chat.connect(_on_chat)
	EventBus.party_notice.connect(_on_notice)
	_backing = StyleBoxFlat.new()
	_backing.bg_color = Color(0.03, 0.04, 0.05, 0.72)
	_backing.border_color = Color(0.86, 0.72, 0.42, 0.28)
	_backing.set_border_width_all(1)
	_backing.set_corner_radius_all(6)
	set_process(false)
	resized.connect(queue_redraw)


## Somebody typed something. Speech, so it carries a name and lingers.
func _on_chat(slot: int, text: String) -> void:
	if muted_slots.has(slot):
		return
	_add(ChatLine.render(_stamp(), speaker_name(slot), CoopParty.colour_of(slot), text),
		true, slot)


## Something happened, and a seat is answerable for it.
func _on_notice(slot: int, text: String) -> void:
	_add("%s[color=#%s]%s[/color]" % [_stamp_markup(), CoopParty.colour_of(slot).to_html(false),
		ChatLine.escape(text)], false, slot)


## A line from this machine to its own player - a command's answer, a refusal.
## Grey, so it is never mistaken for somebody speaking.
func say_system(text: String) -> void:
	_add("[color=#a39a88]%s[/color]" % ChatLine.escape(text), false, 0)


## Who a seat is, by name. Alone there is no seat to read, so it is the Warden's
## own name - a solo line is the player talking to themselves, which is what a
## `/roll` or a note to self is.
static func speaker_name(slot: int) -> String:
	var seat: CoopParty.Seat = Coop.party().seat_for_slot(slot)
	if seat != null and not seat.name.is_empty():
		return seat.name
	if not MetaState.player_name.is_empty():
		return MetaState.player_name
	return "Warden"


func _stamp() -> String:
	if not GameDirector.run_active:
		return ""
	return ChatLine.stamp(RunState.run_time_seconds)


func _stamp_markup() -> String:
	var stamp: String = _stamp()
	return "[color=#8d8579]%s[/color] " % ChatLine.escape(stamp) if not stamp.is_empty() else ""


func _add(markup: String, speech: bool, slot: int) -> void:
	if _muted or markup.strip_edges().is_empty():
		return
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(Balance.PARTY_LOG_WIDTH, 0.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_font_override("normal_font", UiFonts.face(UiFonts.Role.BODY))
	line.add_theme_font_override("bold_font", UiFonts.face(UiFonts.Role.BUTTON))
	line.add_theme_font_override("italics_font", UiFonts.face(UiFonts.Role.FLAVOUR))
	var size_px: int = 15 if speech else 14
	for key: String in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		line.add_theme_font_size_override(key, size_px)
	line.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.95))
	line.add_theme_constant_override("outline_size", 5)
	line.text = markup
	add_child(line)
	_lines.append({"node": line, "born": Time.get_ticks_msec(), "speech": speech, "slot": slot})
	while _lines.size() > MAX_LINES:
		var oldest: Dictionary = _lines.pop_front()
		# Validity before the cast: casting a freed line is an engine error.
		var gone: Variant = oldest["node"]
		if is_instance_valid(gone):
			(gone as Node).queue_free()
	_show_lines()
	set_process(true)


## Empties the log (`/clear`).
func clear() -> void:
	for entry: Dictionary in _lines:
		if is_instance_valid(entry["node"]):
			(entry["node"] as Node).queue_free()
	_lines.clear()
	queue_redraw()


## How many lines are kept, and how many are on the screen now, for the gate.
func line_count() -> int:
	return _lines.size()


func shown_count() -> int:
	var shown: int = 0
	for entry: Dictionary in _lines:
		if not is_instance_valid(entry["node"]):
			continue
		var node := entry["node"] as RichTextLabel
		if node.visible and node.modulate.a > 0.01:
			shown += 1
	return shown


## The text of every kept line, markup taken out, oldest first - for the gate.
func plain_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in _lines:
		if is_instance_valid(entry["node"]):
			out.append((entry["node"] as RichTextLabel).get_parsed_text())
	return out


## The chat box opened or closed. Open, the log is its history.
func set_open(open: bool) -> void:
	if _open == open:
		return
	_open = open
	_show_lines()
	set_process(true)
	queue_redraw()


func is_open() -> bool:
	return _open


func _process(_delta: float) -> void:
	if not _show_lines() and not _open:
		set_process(false)


## Lays every kept line out as it should read now: the last few at full strength
## while the chat is open, and otherwise each by its own age. Returns whether
## anything is still on the screen.
func _show_lines() -> bool:
	var now: int = Time.get_ticks_msec()
	var any: bool = false
	var count: int = _lines.size()
	for i: int in count:
		var entry: Dictionary = _lines[i]
		if not is_instance_valid(entry["node"]):
			continue
		var node := entry["node"] as RichTextLabel
		var alpha: float = 0.0
		if _open:
			alpha = 1.0 if i >= count - Balance.CHAT_OPEN_LINES else 0.0
		else:
			var age: float = float(now - int(entry["born"])) / 1000.0
			var hold: float = HOLD_SECONDS * (1.6 if bool(entry["speech"]) else 1.0)
			if age < hold:
				alpha = 1.0
			elif age < hold + FADE_SECONDS:
				alpha = 1.0 - (age - hold) / FADE_SECONDS
		node.visible = alpha > 0.0
		node.modulate.a = alpha
		if alpha > 0.0:
			any = true
	return any


## The dark under the history while the chat is open, so lines read over a busy
## road - League's log has one for the same reason.
func _draw() -> void:
	if not _open or _backing == null or shown_count() == 0:
		return
	draw_style_box(_backing, Rect2(Vector2(-10.0, -8.0), size + Vector2(20.0, 16.0)))


## Hides everything without tearing it down, for a screenshot or a cinematic.
func set_muted(quiet: bool) -> void:
	_muted = quiet
	visible = not quiet
