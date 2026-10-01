class_name PartyChat
extends VBoxContainer

## **The party's feed and the line a player types into, as one piece**
## (2026-10-01: the road's chat, taken out of the HUD so the Hold can carry
## the same one). What a line means is `ChatLine`'s; what is said to the party
## is `EventBus.coop_chat`, which the relay forwards - this is the box, the
## history, the commands that answer on this machine, and the keys.
##
## **The box is hidden until Enter is pressed.** A permanent text field in the
## corner of an action game is a permanent invitation to lose a wave to it, and
## it would also swallow every key a player meant for the hero.
##
## **Alone as well as in company.** Alone, a line is a note to self and the
## commands still answer: `/roll`, `/time`, `/help`.
##
## The owner decides when it may open (`available`): the road's HUD while a
## road is live, the Hold while the Hold is the screen in front of the player.

## Whether the box may open now. Asked on every key, so a screen laid over the
## owner closes the chat to it without anything having to tell this.
var available: Callable = func() -> bool: return true

var feed: PartyLog = null
var box: LineEdit = null
## What this machine has said, newest last, for Up and Down.
var _sent: Array[String] = []
var _recall: int = 0
## When each recent line was sent, for the burst limit.
var _times: Array[int] = []
## A roll is a game between people and moves nothing in the run, so it has dice
## of its own rather than the run's.
var _dice := RandomNumberGenerator.new()


func _init() -> void:
	name = "PartyFeed"
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed = PartyLog.new()
	feed.name = "PartyLog"
	add_child(feed)
	box = LineEdit.new()
	box.name = "ChatBox"
	box.max_length = Balance.CHAT_MAX_LENGTH
	box.visible = false
	box.custom_minimum_size = Vector2(Balance.PARTY_LOG_WIDTH, 0.0)
	box.text_submitted.connect(submit)
	# A box that looks like a channel: dark, a gold rule, the party's own
	# colour on the caret, so it reads as the log's own line rather than as a
	# settings field dropped on the road.
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.03, 0.04, 0.05, 0.86)
	field.border_color = Color(0.86, 0.72, 0.42, 0.55)
	field.set_border_width_all(1)
	field.set_corner_radius_all(5)
	field.content_margin_left = 10.0
	field.content_margin_right = 10.0
	field.content_margin_top = 5.0
	field.content_margin_bottom = 5.0
	for state: String in ["normal", "focus", "read_only"]:
		box.add_theme_stylebox_override(state, field)
	box.add_theme_color_override("font_color", Color("ece6d8"))
	box.add_theme_color_override("font_placeholder_color", Color(0.62, 0.58, 0.52, 0.8))
	box.add_theme_color_override("caret_color", Color("f2dfa8"))
	add_child(box)
	_dice.randomize()


## Enter opens the box; Enter sends and closes it; Escape closes it unsent.
##
## In `_input` rather than `_unhandled_input`: a LineEdit with focus eats the
## key before an unhandled handler ever sees it, so the second Enter would
## never reach this.
func _input(event: InputEvent) -> void:
	if not may_open():
		if is_chatting():
			close_chat()
		return
	if is_chatting() and event.is_action_pressed(&"ui_cancel"):
		close_chat()
		get_viewport().set_input_as_handled()
		return
	# Up and Down walk back through what this machine has said, as League's
	# box does - the line said a moment ago is the one most often said again.
	var key := event as InputEventKey
	if is_chatting() and key != null and key.pressed and key.keycode in [KEY_UP, KEY_DOWN]:
		_walk_back(-1 if key.keycode == KEY_UP else 1)
		get_viewport().set_input_as_handled()
		return
	if not _is_chat_key(event):
		return
	if is_chatting():
		submit(box.text)
	else:
		open_chat()
	get_viewport().set_input_as_handled()


## Enter, or the keypad's Enter: the `chat` action names the main one, and a
## hand on the keypad presses the other without thinking about it.
func _is_chat_key(event: InputEvent) -> bool:
	if event.is_action_pressed(&"chat"):
		return true
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.physical_keycode == KEY_KP_ENTER


func may_open() -> bool:
	return box != null and is_inside_tree() and is_visible_in_tree() and bool(available.call())


## Opens the box over the log's history.
func open_chat() -> void:
	if not may_open():
		return
	box.placeholder_text = ("Party  ·  Enter to send, /help for commands"
		if Coop.is_networked() else "Say something  ·  /help for commands")
	box.visible = true
	_recall = _sent.size()
	box.grab_focus()
	feed.set_open(true)


func is_chatting() -> bool:
	return box != null and is_instance_valid(box) and box.visible


## Opens the box, or sends what is in it and closes it - the one press a thumb
## has for what Enter does twice.
func toggle() -> void:
	if is_chatting():
		submit(box.text)
	else:
		open_chat()


func close_chat() -> void:
	if box == null or not is_instance_valid(box):
		return
	box.text = ""
	box.visible = false
	box.release_focus()
	feed.set_open(false)


## Forgets the burst clock, for a gate that sends more than a burst on purpose.
func forget_burst() -> void:
	_times.clear()


func _walk_back(step: int) -> void:
	if _sent.is_empty():
		return
	_recall = clampi(_recall + step, 0, _sent.size())
	box.text = _sent[_recall] if _recall < _sent.size() else ""
	box.caret_column = box.text.length()


## A line typed and sent: a command for this machine is answered here, and a
## line that travels is emitted - not sent. The relay forwards it and the host
## passes it on to the rest of the party; this machine draws its own copy from
## the same signal, so every screen reads the same text the same way.
func submit(text: String) -> void:
	var line: Dictionary = ChatLine.parse(text)
	close_chat()
	var kind: int = int(line["kind"])
	if kind == ChatLine.Kind.EMPTY:
		return
	_remember(ChatLine.clean(text))
	match kind:
		ChatLine.Kind.HELP:
			say_to_self("Enter opens and sends, Escape closes, Up and Down recall.")
			for command: Dictionary in ChatLine.COMMANDS:
				say_to_self("%s  -  %s" % [String(command["usage"]), String(command["says"])])
			return
		ChatLine.Kind.CLEAR:
			feed.clear()
			return
		ChatLine.Kind.TIME:
			if GameDirector.run_active:
				say_to_self("%s on the road  ·  Act %d  ·  wave %d" % [
					ChatLine.stamp(RunState.run_time_seconds).trim_prefix("[").trim_suffix("]"),
					RunState.act, RunState.wave_number])
			else:
				say_to_self("In the Hold, between roads.")
			return
		ChatLine.Kind.MUTE, ChatLine.Kind.UNMUTE:
			_mute_by_name(String(line.get("name", "")), kind == ChatLine.Kind.MUTE)
			return
		ChatLine.Kind.UNKNOWN:
			var why: String = String(line.get("why", ""))
			say_to_self(why if not why.is_empty()
				else "No command /%s. /help lists them." % String(line.get("word", "")))
			return
	if not _may_send():
		say_to_self("Slow down - your party is still reading.")
		return
	var rolled: int = 0
	if kind == ChatLine.Kind.ROLL:
		rolled = _dice.randi_range(1, int(line["most"]))
	var slot: int = Coop.party().slot()
	EventBus.coop_chat.emit(maxi(slot, 1), ChatLine.wire(line, rolled))


func say_to_self(text: String) -> void:
	feed.say_system(text)


func _remember(text: String) -> void:
	if text.is_empty():
		return
	if _sent.is_empty() or _sent.back() != text:
		_sent.append(text)
	while _sent.size() > Balance.CHAT_HISTORY:
		_sent.pop_front()


## **A burst is a few lines, never a flood.** `CHAT_BURST` lines inside
## `CHAT_BURST_SECONDS`, then the box says so rather than sending: a party of
## four reading a wall of text in a wave is a party losing the wave.
func _may_send() -> bool:
	var now: int = Time.get_ticks_msec()
	var window: int = int(Balance.CHAT_BURST_SECONDS * 1000.0)
	while not _times.is_empty() and now - _times[0] > window:
		_times.pop_front()
	if _times.size() >= Balance.CHAT_BURST:
		return false
	_times.append(now)
	return true


## Mutes or unmutes a seat by the start of its name - this screen only, and
## never the player's own seat, since a player cannot be rude to themselves.
func _mute_by_name(name_text: String, mute: bool) -> void:
	var wanted: String = name_text.strip_edges().to_lower()
	if wanted.is_empty():
		say_to_self("/%s wants a name." % ("mute" if mute else "unmute"))
		return
	var own: int = Coop.party().slot()
	for slot: int in range(1, Balance.PARTY_COLOURS.size() + 1):
		var seat: CoopParty.Seat = Coop.party().seat_for_slot(slot)
		if seat == null or slot == own or not seat.name.to_lower().begins_with(wanted):
			continue
		if mute:
			feed.muted_slots[slot] = true
			say_to_self("%s is muted on this screen." % seat.name)
		else:
			feed.muted_slots.erase(slot)
			say_to_self("%s can be heard again." % seat.name)
		return
	say_to_self("Nobody in the party is called \"%s\"." % name_text.strip_edges())
