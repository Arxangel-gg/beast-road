extends CanvasLayer

## The front door to co-op: host a game, or join a friend's.
##
## This did not exist, and its absence was the whole of "multiplayer is not
## fully integrated". Every piece underneath it worked and was gated — the
## transport, the relay, two heroes, mirrored enemies, shared XP, verified across
## two real processes — and none of it was reachable by a person playing the
## game. A feature nobody can start is not a feature.
##
## Three things it has to do, in the order a player meets them:
##
## 1. **Say your address out loud.** A player who has to find their own IP will
##    not play co-op. The local one is shown for a second machine in the same
##    house, and the external one for a friend somewhere else.
## 2. **Say whether the door is actually open.** UPnP opens the port on most
##    routers; on the rest it silently does not, and the honest answer is to say
##    so and name the port to forward rather than let two people fail to connect
##    and blame the game.
## 3. **Let the host start when they are ready.** The guest follows automatically
##    - `GameDirector` listens for the run starting - so there is no second
##    "ready" button to coordinate.

signal closed()

const PANEL_WIDTH: float = 620.0

var _root: Control = null
var _status: Label = null
var _address_label: Label = null
var _hint: Label = null
var _join_field: LineEdit = null
var _host_button: Button = null
var _share_row: HBoxContainer = null
var _copy_button: Button = null
var _join_button: Button = null
var _begin_button: Button = null
var _leave_button: Button = null


func _ready() -> void:
	layer = 60
	_build()
	visible = false
	EventBus.coop_state_changed.connect(_on_state_changed)
	EventBus.coop_partner_joined.connect(func(_id: int) -> void: _refresh())
	EventBus.coop_partner_left.connect(func(_id: int) -> void: _refresh())
	EventBus.coop_failed.connect(func(_why: String) -> void: _refresh())
	EventBus.coop_address_known.connect(func(_l: String, _e: String, _m: bool) -> void: _refresh())


func open() -> void:
	visible = true
	_refresh()
	_host_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.offset_left = -PANEL_WIDTH * 0.5
	_root.offset_right = PANEL_WIDTH * 0.5
	_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_root)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_root.add_child(column)

	var title := Label.new()
	title.text = "Co-op"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	var blurb := Label.new()
	blurb.text = "Two players, one city. Both of you fight."
	blurb.add_theme_font_size_override("font_size", 15)
	blurb.add_theme_color_override("font_color", Color("aebcb8"))
	column.add_child(blurb)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	_address_label = Label.new()
	_address_label.add_theme_font_size_override("font_size", 15)
	_address_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_address_label.add_theme_color_override("font_color", Color("e8d9a8"))
	column.add_child(_address_label)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color("9aa8a4"))
	column.add_child(_hint)

	# One button, and it is the whole feature. Everything a player has to do to
	# get a friend into their game is press this and paste what it gives them.
	_share_row = HBoxContainer.new()
	_share_row.add_theme_constant_override("separation", 8)
	_share_row.visible = false
	column.add_child(_share_row)
	_copy_button = Button.new()
	_copy_button.text = "Copy code"
	_copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy_button.pressed.connect(_on_copy)
	IconKit.on_button(_copy_button, "pressure_arrow", 20)
	_share_row.add_child(_copy_button)

	_host_button = _button(column, "Host a game", "pressure_arrow")
	_host_button.pressed.connect(_on_host)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	column.add_child(join_row)

	_join_field = LineEdit.new()
	_join_field.placeholder_text = "Paste your friend's code"
	_join_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_field.text_submitted.connect(func(_v: String) -> void: _on_join())
	join_row.add_child(_join_field)

	_join_button = Button.new()
	_join_button.text = "Join"
	_join_button.pressed.connect(_on_join)
	join_row.add_child(_join_button)

	_begin_button = _button(column, "Begin the run", "pressure_arrow")
	_begin_button.pressed.connect(_on_begin)

	_leave_button = _button(column, "Leave session", "close")
	_leave_button.pressed.connect(func() -> void:
		Coop.leave()
		_refresh())

	var back: Button = _button(column, "Back", "close")
	back.pressed.connect(close)


func _button(column: Node, text: String, icon: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	IconKit.on_button(button, icon, 22)
	column.add_child(button)
	return button


func _on_host() -> void:
	if not Coop.host():
		_refresh()
		return
	_refresh()


## Puts the code on the clipboard, and says so.
##
## The label change is not decoration. A copy button that does nothing visible is
## one people press three times and then doubt, and there is nothing else on
## screen to confirm it worked.
func _on_copy() -> void:
	var code: String = _share_code()
	if code.is_empty():
		return
	DisplayServer.clipboard_set(code)
	_copy_button.text = "Copied  %s" % code
	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(_copy_button):
		_copy_button.text = "Copy code"


## Joins by code, or by address for anyone who would rather type one.
##
## Both, because a code cannot say "the machine next to me" and an address
## cannot be pasted from a chat window without someone reading out a port. A
## code has no dots and an address always does, so no guessing is needed.
func _on_join() -> void:
	var typed: String = _join_field.text.strip_edges()
	if typed.is_empty():
		# The single most common case for testing is a second copy on the same
		# machine, so an empty box means that rather than nothing.
		typed = "127.0.0.1"
		_join_field.text = typed
	if CoopCode.looks_like_code(typed):
		var parsed: Dictionary = CoopCode.decode(typed)
		if parsed.is_empty():
			Coop.report_failure("That code is not right. Check it for a missing "
				+ "character and paste it again.")
			_refresh()
			return
		Coop.join(String(parsed["address"]), int(parsed["port"]))
		_refresh()
		return
	Coop.join(typed)
	_refresh()


## Only the host starts the run. The guest follows automatically, because
## `GameDirector` listens for the run starting — there is no second ready button
## to coordinate, and no way for the two to start different worlds.
func _on_begin() -> void:
	if not Coop.is_host() or not Coop.partner_present():
		return
	close()
	GameDirector.start_run()


func _on_state_changed(_state: int) -> void:
	_refresh()


## Everything the player needs to know, in one pass over the session's state.
func _refresh() -> void:
	if not visible:
		return
	var state: int = Coop.state()
	var joined: bool = Coop.partner_present()

	match state:
		Coop.State.OFFLINE:
			_status.text = "Not connected."
			_address_label.text = ""
			_hint.text = "Host a game and send your friend the address, or paste theirs and join."
		Coop.State.HOSTING:
			_status.text = "Player 2 is here. Ready when you are." if joined \
				else "Hosting. Waiting for your friend to join…"
			_address_label.text = _address_text()
			_hint.text = _hint_text()
		Coop.State.CONNECTING:
			_status.text = "Connecting…"
			_address_label.text = ""
			_hint.text = "If nothing happens, check the address and that they are hosting."
		Coop.State.CONNECTED:
			_status.text = "Connected. Waiting for the host to begin the run."
			_address_label.text = ""
			_hint.text = "The run starts when they start it — you will be taken in automatically."
		Coop.State.FAILED:
			_status.text = Coop.last_error
			_address_label.text = ""
			_hint.text = "Try again, or host instead."

	_host_button.disabled = state != Coop.State.OFFLINE and state != Coop.State.FAILED
	_join_button.disabled = _host_button.disabled
	_join_field.editable = not _host_button.disabled
	# Only a host with company may begin, which is the rule the button should
	# express rather than something to find out by pressing it.
	_begin_button.disabled = not (state == Coop.State.HOSTING and joined)
	_begin_button.visible = state == Coop.State.HOSTING
	_leave_button.visible = state != Coop.State.OFFLINE and state != Coop.State.FAILED


## The code to send, and the addresses behind it for anyone who wants them.
##
## The code comes first and in its own line because it is the only thing most
## players will ever need: copy, paste into a chat, done. The raw addresses stay
## underneath for the cases a code cannot cover - a friend on the same network,
## or somebody checking a port forward.
func _address_text() -> String:
	var lines: PackedStringArray = []
	var code: String = _share_code()
	lines.append("Send your friend this code:   %s" % code
		if not code.is_empty() else "Finding your address…")
	if not Coop.local_address.is_empty():
		lines.append("Same network:  %s" % Coop.local_address)
	if not Coop.external_address.is_empty():
		lines.append("Over internet: %s" % Coop.external_address)
	else:
		lines.append("Over internet: looking…")
	lines.append("Port: %d" % Balance.COOP_PORT)
	_share_row.visible = not code.is_empty()
	return "\n".join(lines)


## The code a friend pastes, or "" while there is still nothing to encode.
##
## Prefers the public address, because that is the one a friend anywhere in the
## world can reach. Falls back to the local one so a code always works for two
## machines in the same house rather than showing nothing until a router answers.
func _share_code() -> String:
	var address: String = Coop.external_address if not Coop.external_address.is_empty() 		else Coop.local_address
	if address.is_empty():
		return ""
	return CoopCode.encode(address, Balance.COOP_PORT)


## Whether the door is actually open, said plainly.
##
## A router with UPnP switched off is the common case, not an error. Saying so —
## and naming the port to forward — is the difference between a player who can
## fix it and two people who fail to connect and blame the game.
func _hint_text() -> String:
	if Coop.external_address.is_empty():
		return "Asking your router for a public address…"
	if Coop.port_mapped:
		return "Your router opened the port. Press Copy code and send it to your friend - " \
			+ "they paste it into their box and press Join."
	return "Copy the code and send it. Your router would not open the port on its own, " \
		+ "so you may also need to forward UDP %d to %s - or play on the same network." \
		% [Balance.COOP_PORT, Coop.local_address]
