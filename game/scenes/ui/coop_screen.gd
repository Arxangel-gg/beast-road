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
var _room_button: Button = null
var _share_row: HBoxContainer = null
var _copy_button: Button = null
var _lobby_title: Label = null
var _lobby_list: VBoxContainer = null
var _public_title: Label = null
var _public_list: VBoxContainer = null
var _diagnostic: Label = null
var _party_view: VBoxContainer = null
var _friends_list: VBoxContainer = null
var _friend_field: LineEdit = null
var _password_field: LineEdit = null
var _find_button: Button = null

## The seat claimed by a matchmaking search, held so it can be given back if the
## search is abandoned or the join fails.
var _claimed: String = ""
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
	# Listen while the screen is up and only while it is up. A socket bound for
	# the whole session would be a socket nobody is looking at.
	Coop.beacon().listen()
	if not Coop.beacon().games_changed.is_connected(_on_games_changed):
		Coop.beacon().games_changed.connect(_on_games_changed)
	# And the public list, which is the same idea reaching further.
	Coop.directory().browse()
	Coop.friends().begin()
	if not Coop.friends().friends_changed.is_connected(_on_friends):
		Coop.friends().friends_changed.connect(_on_friends)
	_on_friends(Coop.friends().rows())
	if not Coop.directory().games_changed.is_connected(_on_public_games):
		Coop.directory().games_changed.connect(_on_public_games)
		Coop.directory().status_changed.connect(
			func(_text: String) -> void: _refresh())
	_on_games_changed(Coop.beacon().games())
	_on_public_games(Coop.directory().games())
	_refresh()
	_host_button.grab_focus()


func close() -> void:
	visible = false
	# The host keeps shouting; only the listening stops. Somebody who opened this
	# screen, hosted, and closed it is still findable by their friend.
	Coop.beacon().stop_listening()
	# Stops polling; a listing this machine owns stays up, because a host who
	# closed this screen is still hosting.
	Coop.directory().stop_browsing()
	Coop.friends().end()
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

	# **The lobby.** Three doors, in the order most people will use them: the
	# games already on this network, a code for everyone else, and a typed
	# address for anyone who would rather.
	_lobby_title = Label.new()
	_lobby_title.add_theme_font_size_override("font_size", 15)
	_lobby_title.add_theme_color_override("font_color", Color("9aa8a4"))
	column.add_child(_lobby_title)

	_lobby_list = VBoxContainer.new()
	_lobby_list.add_theme_constant_override("separation", 4)
	column.add_child(_lobby_list)

	# **Who is actually here.** A party assembles over a minute or two and the
	# only thing anybody wants during that is a list of who has arrived, in their
	# colour, so the party knows when to start.
	_party_view = VBoxContainer.new()
	_party_view.add_theme_constant_override("separation", 3)
	column.add_child(_party_view)

	_public_title = Label.new()
	_public_title.add_theme_font_size_override("font_size", 15)
	_public_title.add_theme_color_override("font_color", Color("9aa8a4"))
	column.add_child(_public_title)

	_public_list = VBoxContainer.new()
	_public_list.add_theme_constant_override("separation", 4)
	column.add_child(_public_list)

	# **Friends: a code you were given, not an account you signed up for.**
	var friend_row := HBoxContainer.new()
	friend_row.add_theme_constant_override("separation", 8)
	column.add_child(friend_row)
	_friend_field = LineEdit.new()
	_friend_field.placeholder_text = "Add a friend by their play code"
	_friend_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friend_field.max_length = 7
	_friend_field.text_submitted.connect(func(_v: String) -> void: _on_add_friend())
	friend_row.add_child(_friend_field)
	var add := Button.new()
	add.text = "Add"
	add.pressed.connect(_on_add_friend)
	friend_row.add_child(add)

	_friends_list = VBoxContainer.new()
	_friends_list.add_theme_constant_override("separation", 3)
	column.add_child(_friends_list)

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

	# **The one that works everywhere**, and therefore the one on top.
	#
	# A room needs no port forwarded, crosses two home routers, and runs in a
	# browser - so a desktop player and a web player meet on it identically.
	# Opening a port is still offered below it because it needs no internet at
	# all, which is what two people in one house with the line down actually
	# want, and it is the lower-latency path when it is available.
	# **Find a party** sits above hosting, because it is the answer for somebody
	# who does not care *whose* game they join and just wants to play. It joins
	# whoever has been waiting longest and opens a room only when nobody has.
	_find_button = _button(column, "Find a party  ·  join anyone waiting",
		"pressure_arrow")
	_find_button.pressed.connect(_on_find_party)

	# Optional, and empty means open. A lobby with a password is still listed -
	# with a padlock - because a private game nobody can see is a private game
	# whose owner cannot tell their friend where it is.
	_password_field = LineEdit.new()
	_password_field.placeholder_text = "Password for your room (optional)"
	_password_field.secret = true
	_password_field.max_length = 32
	column.add_child(_password_field)

	_room_button = _button(column, "Host a room  ·  anyone can join",
		"pressure_arrow")
	_room_button.pressed.connect(_on_host_room)

	_host_button = _button(column, "Open a port  ·  same network or forwarded",
		"pressure_arrow")
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

	# **One line that says why co-op is not working.**
	#
	# "It does not work" is the hardest report to act on, and the three things
	# that can be wrong are invisible from the outside: the build is older than
	# the feature, this platform has no WebRTC, or the matchmaking service is not
	# answering. The version matters most of all on the web, where the build is
	# whatever was last deployed rather than whatever was last released.
	_diagnostic = Label.new()
	_diagnostic.add_theme_font_size_override("font_size", 12)
	_diagnostic.add_theme_color_override("font_color", Color("7d8a86"))
	_diagnostic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_diagnostic)

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


## Opens a room over WebRTC. The code it returns is the whole handshake.
func _on_host_room() -> void:
	Coop.directory().set_password(
		_password_field.text if _password_field != null else "")
	Coop.host_room()
	_refresh()


## Joins whoever has been waiting longest, or opens a room if nobody has.
##
## **The seat is claimed by the service before this machine is told about it**,
## so two people searching at the same instant cannot both be handed the last
## seat in one lobby. If the join then fails, the seat is given back - otherwise
## a lobby slowly fills with people who never arrived.
func _on_find_party() -> void:
	if _find_button != null:
		_find_button.disabled = true
		_find_button.text = "Searching..."
	Coop.directory().find_party(func(usable: bool, code: String) -> void:
		if usable:
			_claimed = code
			_join_field.text = code
			_on_join()
		else:
			# Nobody waiting. Becoming the host is the useful answer - somebody
			# has to be first, and the searcher is already here.
			if not code.is_empty():
				Coop.directory().release_seat(code)
			Coop.directory().set_password("")
			Coop.host_room()
		if _find_button != null:
			_find_button.disabled = false
			_find_button.text = "Find a party  ·  join anyone waiting"
		_refresh())


## Puts the code on the clipboard, and says so.
##
## The label change is not decoration. A copy button that does nothing visible is
## one people press three times and then doubt, and there is nothing else on
## screen to confirm it worked.
func _on_add_friend() -> void:
	var typed: String = _friend_field.text
	_friend_field.text = ""
	if MetaState.remember_friend(typed, ""):
		Coop.friends().refresh()
	else:
		Coop.report_failure("That is not a play code, or you already have it. "
			+ "A code is six characters.")
	_refresh()


## Everybody known, and which of them is playing right now.
##
## An offline friend is still drawn, greyed out. A list that shows only the
## people who happen to be on is a list that looks broken when nobody is.
func _on_friends(rows: Array) -> void:
	if _friends_list == null:
		return
	for child: Node in _friends_list.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Friends  ·  your code is %s" % MetaState.own_play_code()
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("9aa8a4"))
	_friends_list.add_child(title)

	for entry: Variant in rows:
		var friend: Dictionary = entry
		var online: bool = bool(friend["online"])
		var room: String = String(friend["room"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_friends_list.add_child(row)

		var who := Button.new()
		var name: String = String(friend["name"])
		var shown: String = name if not name.is_empty() else String(friend["code"])
		who.text = "%s  ·  %s" % [shown,
			("in a room" if not room.is_empty() else "online") if online
				else "offline"]
		who.alignment = HORIZONTAL_ALIGNMENT_LEFT
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_theme_font_size_override("font_size", 14)
		# Only joinable when they are actually hosting something joinable.
		who.disabled = room.is_empty() or Coop.state() != Coop.State.OFFLINE
		who.add_theme_color_override("font_color",
			Color("cfe3d8") if online else Color("6c7a75"))
		var code: String = room
		who.pressed.connect(func() -> void:
			_join_field.text = code
			_on_join())
		row.add_child(who)

		var drop := Button.new()
		drop.text = "✕"
		drop.tooltip_text = "Forget this friend"
		var forget: String = String(friend["code"])
		drop.pressed.connect(func() -> void:
			MetaState.forget_friend(forget)
			Coop.friends().refresh())
		row.add_child(drop)


## The party, one row per seat, in each player's own colour.
func _update_party_view() -> void:
	if _party_view == null:
		return
	for child: Node in _party_view.get_children():
		child.queue_free()
	if not Coop.is_networked():
		return
	var seats: Array = Coop.party().seats()
	var header := Label.new()
	header.text = "Party  %d/%d" % [maxi(seats.size(), 1), Balance.COOP_MAX_PLAYERS]
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color("9aa8a4"))
	_party_view.add_child(header)

	for entry: Variant in seats:
		var seat := entry as CoopParty.Seat
		var row := Label.new()
		var mine: String = "  (you)" if seat.slot == Coop.party().slot() else ""
		# The colour name is written out as well as shown, because "Blue" is what
		# people say out loud and because a colour alone is no use to a player who
		# cannot tell two of them apart.
		row.text = "%d. %s  ·  %s%s" % [seat.slot, seat.name,
			seat.colour_name(), mine]
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override("font_color", seat.colour())
		_party_view.add_child(row)


## The three things that can be wrong, stated plainly.
func _update_diagnostic() -> void:
	if _diagnostic == null:
		return
	# `BuildInfo.VERSION` is stamped from the tag at export and left as "dev" in
	# the repository, so a build made on somebody's machine says so rather than
	# impersonating a release.
	var version: String = BuildInfo.VERSION
	var platform: String = "browser" if OS.has_feature("web") else OS.get_name()
	var rtc: String = "yes" if CoopWebRTC.available() else "NO"
	var lobby: String = "unreachable" if Coop.directory().status().begins_with(
		"Could not") else "reachable"
	_diagnostic.text = "build %s  ·  %s  ·  rooms: %s  ·  lobby list: %s" % [
		version, platform, rtc, lobby]


## Six characters, no dots. See `_on_join`.
static func _looks_like_room(text: String) -> bool:
	var cleaned: String = text.strip_edges().to_upper().replace("-", "")
	if cleaned.length() != 6 or cleaned.contains("."):
		return false
	for character: String in cleaned:
		if not "0123456789ABCDEFGHJKMNPQRSTVWXYZ".contains(character):
			return false
	return true


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
	# **A room code is tried first**, because it is the one a player is most
	# likely to have been sent and the only one that works from a browser. Six
	# characters and no dot: an address has dots and a connect code is ten or
	# sixteen characters, so the three cannot be confused for one another.
	if _looks_like_room(typed):
		Coop.join_room(typed)
		_refresh()
		return
	if CoopCode.looks_like_code(typed):
		var parsed: Dictionary = CoopCode.decode(typed)
		if parsed.is_empty():
			Coop.report_failure("That code is not right. Check it for a missing "
				+ "character and paste it again.")
			_refresh()
			return
		Coop.join(String(parsed["address"]), int(parsed["port"]),
			String(parsed.get("alternate", "")))
		_refresh()
		return
	Coop.join(typed)
	_refresh()


## Only the host starts the run. The guest follows automatically, because
## `GameDirector` listens for the run starting — there is no second ready button
## to coordinate, and no way for the two to start different worlds.
func _on_begin() -> void:
	# **Nobody is dragged into a tier they have not opened.**
	#
	# Checked here rather than when they joined, because the host may change the
	# tier after the party has formed, and a check at the door would miss that.
	# Named, too: "somebody in your party cannot play this" sends four people
	# asking each other which of them it is.
	var blocked: String = Coop.party_blocked_from(RunState.tier())
	if not blocked.is_empty():
		Coop.report_failure(blocked + " Choose a lower tier, or play without them.")
		_refresh()
		return
	if not Coop.is_host() or not Coop.partner_present():
		return
	close()
	GameDirector.start_run()


func _on_state_changed(state: int) -> void:
	# A search that ended badly gives its seat back. Held until the outcome is
	# known rather than released on the way out, because a join that succeeds
	# must keep the seat it was given.
	if not _claimed.is_empty() and (state == Coop.State.OFFLINE
			or state == Coop.State.FAILED):
		Coop.directory().release_seat(_claimed)
		_claimed = ""
	elif state == Coop.State.CONNECTED:
		_claimed = ""
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
			_hint.text = "Same network? Pick their game above. Anywhere else? Host, " 				+ "press Copy code, and send them the code."
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
	if _room_button != null:
		_room_button.disabled = _host_button.disabled or not CoopWebRTC.available()
		# Said plainly rather than left as a button that does nothing. A desktop
		# build without the extension is a build somebody made wrong, and a
		# browser always has it.
		_room_button.tooltip_text = "Six characters to share. Works in a browser " 			+ "and through a home router." if CoopWebRTC.available() 			else "This build was made without WebRTC support."
	# Opening a port is desktop-only: a browser cannot do it, and offering it is
	# offering a button that must fail.
	if OS.has_feature("web"):
		_host_button.visible = false
	# The lobby rows are join buttons, so they follow the same rule.
	_on_games_changed(Coop.beacon().games())
	_on_public_games(Coop.directory().games())
	_update_diagnostic()
	_update_party_view()
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
	# Listed publicly the moment there is something worth listing. The code
	# improves when the public address arrives, and `publish` updates the row
	# rather than adding a second one.
	if not code.is_empty() and Coop.is_host() 			and Coop.state() == Coop.State.HOSTING:
		Coop.directory().publish(code, Coop.lobby_name())
	return "\n".join(lines)


## Redraws the list of games found on this network.
##
## Rebuilt wholesale rather than diffed. There are never more than a handful of
## rows, they change a few times a minute at most, and a list that is rebuilt
## cannot drift out of step with what was actually heard.
func _on_games_changed(found: Array) -> void:
	if _lobby_list == null:
		return
	for child: Node in _lobby_list.get_children():
		child.queue_free()
	var joinable: Array = []
	for entry: Variant in found:
		var game: Dictionary = entry
		# A full game is listed and not offered: seeing that your friend already
		# started without you is information, and a Join button that refuses is
		# not.
		joinable.append(game)
	if joinable.is_empty():
		_lobby_title.text = "No games found on this network yet."
		return
	_lobby_title.text = "Games on this network:"
	for entry: Variant in joinable:
		var game: Dictionary = entry
		var full: bool = int(game["players"]) >= 2
		var row := Button.new()
		row.text = "%s  ·  %s%s" % [String(game["name"]), String(game["address"]),
			"   (full)" if full else ""]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0.0, 34.0)
		row.add_theme_font_size_override("font_size", 15)
		row.disabled = full or Coop.state() != Coop.State.OFFLINE 			and Coop.state() != Coop.State.FAILED
		IconKit.on_button(row, "pressure_arrow", 18)
		var address: String = String(game["address"])
		var port: int = int(game["port"])
		row.pressed.connect(func() -> void:
			Coop.join(address, port)
			_refresh())
		_lobby_list.add_child(row)


## Redraws the public list. Same shape as the local one, different reach.
func _on_public_games(found: Array) -> void:
	if _public_list == null:
		return
	for child: Node in _public_list.get_children():
		child.queue_free()
	var joinable: Array = []
	for entry: Variant in found:
		var game: Dictionary = entry
		# A party with a free seat, not just an empty one.
		if int(game["players"]) < Balance.COOP_MAX_PLAYERS:
			joinable.append(game)
	var note: String = Coop.directory().status()
	if joinable.is_empty():
		_public_title.text = note if not note.is_empty() 			else "No public games open right now. Host one and anybody can join."
		return
	_public_title.text = "Open to anyone:" if note.is_empty() else note
	for entry: Variant in joinable:
		var game: Dictionary = entry
		var row := Button.new()
		# The age says whether somebody is still sitting there. A lobby three
		# seconds old is a person waiting; one four minutes old is usually not.
		# The headcount is the first thing anybody wants from a lobby list: a
		# party of three needs one more, and a party of one may be a long wait.
		var locked: bool = bool(game.get("locked", false))
		row.text = "%s%s  ·  %d/%d  ·  waiting %s" % [
			"🔒 " if locked else "", String(game["name"]),
			int(game["players"]), Balance.COOP_MAX_PLAYERS,
			_waited(int(game["age"]))]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0.0, 34.0)
		row.add_theme_font_size_override("font_size", 15)
		row.disabled = Coop.state() != Coop.State.OFFLINE 			and Coop.state() != Coop.State.FAILED
		IconKit.on_button(row, "pressure_arrow", 18)
		var code: String = String(game["code"])
		# Straight through `_on_join`, so a lobby row and a pasted code take
		# exactly the same path - including working out which transport the code
		# is for. A second join path is a second place for it to be wrong.
		row.pressed.connect(func() -> void:
			_join_field.text = code
			_on_join())
		_public_list.add_child(row)


static func _waited(seconds: int) -> String:
	if seconds < 60:
		return "%ds" % maxi(seconds, 0)
	return "%dm" % int(seconds / 60.0)


## The code a friend pastes, or "" while there is still nothing to encode.
##
## Prefers the public address, because that is the one a friend anywhere in the
## world can reach. Falls back to the local one so a code always works for two
## machines in the same house rather than showing nothing until a router answers.
func _share_code() -> String:
	# **A room code beats an address code whenever there is one.** It is six
	# characters instead of sixteen, it works from a browser, it crosses a router
	# nobody configured, and it names no address at all - so it is what a player
	# should be handing to a friend whenever this machine has one.
	if not Coop.room_code.is_empty():
		return Coop.room_code
	# Otherwise both addresses in one code. Whoever pastes it tries the public
	# one and falls back to the local one, so the same code works from the next
	# room and from another country - which a single address cannot do.
	return CoopCode.encode_pair(Coop.external_address, Coop.local_address,
		Balance.COOP_PORT)


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
