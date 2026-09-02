class_name LeaderboardScreen
extends CanvasLayer

## Where you stand, one tier at a time.
##
## Per tier rather than combined, because a combined board answers the wrong
## question: Hell scores six times what Normal does, so a single list would show
## the same three Hell players at the top forever and tell a Normal player
## nothing about the run they just finished. The tier multiplier exists so the
## orders of magnitude do not collide *if* the boards are ever merged; the
## screen still keeps them apart.
##
## It never blocks. The local board is shown immediately from the save, and
## network rows replace it if and when they arrive — so opening this offline, or
## with the table down, shows your own runs rather than a spinner or an error.

signal closed()

var _panel: PanelContainer
var _rows: VBoxContainer
var _heading: Label
var _note: Label
var _tabs: HBoxContainer
var _close_button: Button
var _tier_id: String = "normal"
var _scroll: ScrollContainer


func _ready() -> void:
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Leaderboard.board_loaded.connect(_on_board_loaded)
	get_viewport().size_changed.connect(_refit)
	visible = false


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.88)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(minf(980.0,
		get_viewport().get_visible_rect().size.x - Balance.UI_PANEL_MARGIN * 2.0), 0.0)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))


	# The list scrolls and the close button does not — the same rule the results
	# screen had to learn: a screen whose only way out sits below fifty rows is a
	# screen with no way out.
	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	# Measured against the screen, not against 1080. A fixed 520 plus a heading,
	# three tier tabs, a note line and the Close button came to more than a
	# landscape phone is tall - and a CenterContainer overflows a child it cannot
	# fit *equally in both directions*, so the way out went above the top edge
	# while the list ran off the bottom. Reported as a leaderboard that could not
	# be closed.
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_scroll = scroll
	_refit()

	# **Tabs and note scroll with the rows; heading and Close stay pinned.**
	#
	# A landscape phone is 775 units tall and the pinned parts alone came to more
	# than that once a minimum scroll was insisted on - so no arithmetic could
	# have made this fit, and the panel overflowed however the reservation was
	# computed. Bounding the panel by construction is the only version of this
	# that cannot come back. Same fault, same fix, as the stash.
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	scroll.add_child(inner)
	inner.add_child(_tabs)
	inner.add_child(_note)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	inner.add_child(_rows)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(func() -> void: hide_screen())
	column.add_child(_close_button)


func open() -> void:
	visible = true
	# Re-measured on every open, not only when the window changes size. A
	# screen built before the viewport settled measured itself against the
	# default 1920x1080 and came out taller than the phone it was drawn on -
	# and no `size_changed` follows, because the resize already happened.
	_refit()
	_build_tabs()
	_select(MetaState.last_tier_id)
	_close_button.grab_focus()


func hide_screen() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


## One button per tier. Built from the content rather than hardcoded, so adding
## a fourth tier is a file.
func _build_tabs() -> void:
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		var button := Button.new()
		button.text = tier.display_name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(150.0, 36.0)
		button.pressed.connect(_select.bind(tier.id))
		_tabs.add_child(button)


func _select(tier_id: String) -> void:
	_tier_id = tier_id
	var tier: CampaignTierData = ContentDB.tier(tier_id)
	_heading.text = "Leaderboard  ·  %s" % (tier.display_name if tier != null else tier_id)
	for index: int in _tabs.get_child_count():
		var button := _tabs.get_child(index) as Button
		if button != null:
			button.button_pressed = button.text == (tier.display_name if tier != null else "")

	# Shown from the save first and replaced when the network answers, rather
	# than showing nothing until it does.
	_fill(Leaderboard.local_board(tier_id), false)
	_note.text = "Reading the board…"
	Leaderboard.fetch(tier_id)


func _on_board_loaded(tier_id: String, rows: Array, from_network: bool) -> void:
	# A board that arrived after the player switched tabs is not this board.
	if tier_id != _tier_id:
		return
	_fill(rows, from_network)


func _fill(rows: Array, from_network: bool) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var waiting: int = Leaderboard.pending_count()
	var queued: String = "" if waiting == 0 else \
		"  ·  %d of yours still to send" % waiting
	_note.text = "%d %s%s" % [rows.size(), "entries" if from_network
		else "of your own runs — the board could not be reached", queued]

	if rows.is_empty():
		var empty := Label.new()
		empty.text = "Nothing here yet. Finish a run and post it." if from_network \
			else "No runs of your own on this tier yet."
		empty.add_theme_color_override("font_color", Color("8f9b98"))
		_rows.add_child(empty)
		return

	for index: int in rows.size():
		_rows.add_child(_row(index + 1, rows[index] as Dictionary))


func _row(place: int, entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var own: bool = Leaderboard.is_own(entry)
	var tint: Color = Color("e8a33d") if own else Color("d8d2c4")

	var rank := Label.new()
	rank.text = "%d." % place
	rank.custom_minimum_size = Vector2(52.0, 0.0)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank.add_theme_color_override("font_color", tint)
	row.add_child(rank)

	var name_label := Label.new()
	name_label.text = String(entry.get("name", "—"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", tint)
	row.add_child(name_label)

	var reached := Label.new()
	# Act and wave, not one or the other: two runs both lost in Act II are not
	# the same run, and the wave is what separates them.
	reached.text = "Act %d · wave %d" % [int(entry.get("act", 1)),
		int(entry.get("wave", 0))]
	reached.custom_minimum_size = Vector2(190.0, 0.0)
	reached.add_theme_color_override("font_color", Color("8f9b98"))
	row.add_child(reached)

	var level := Label.new()
	level.text = "Lv%d" % int(entry.get("hero_level", 1))
	level.custom_minimum_size = Vector2(70.0, 0.0)
	level.add_theme_color_override("font_color", Color("8f9b98"))
	row.add_child(level)

	var seconds: int = int(entry.get("duration", 0))
	var time := Label.new()
	time.text = "%d:%02d" % [seconds / 60, seconds % 60]
	time.custom_minimum_size = Vector2(80.0, 0.0)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.add_theme_color_override("font_color", Color("8f9b98"))
	row.add_child(time)

	var score := Label.new()
	score.text = _grouped(int(entry.get("score", 0)))
	score.custom_minimum_size = Vector2(120.0, 0.0)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.add_theme_font_size_override("font_size", 17)
	score.add_theme_color_override("font_color", tint)
	row.add_child(score)

	if bool(entry.get("victory", false)):
		var crown := Label.new()
		crown.text = "◆"
		crown.tooltip_text = "Reached the summit."
		crown.add_theme_color_override("font_color", Color("e8a33d"))
		row.add_child(crown)

	return row


## Thousands separated, because a six-digit score is unreadable without it.
func _grouped(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return ("-" if value < 0 else "") + out


## Re-measures the list against the screen it is actually on.
##
## Called at build time and on every resize, because a phone changes viewport
## when it rotates and a desktop window when it is dragged - and a panel that was
## the right height once is the wrong height afterwards.
func _refit() -> void:
	if _panel == null or _scroll == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(980.0,
		screen.x - Balance.UI_PANEL_MARGIN * 2.0), 0.0)
	# **Measured, not guessed.** This reserved a flat 312 for the heading, the
	# tier tabs, the note and Close - a number that was right when it was written
	# and drifts silently every time the panel gains a line. On a landscape phone
	# it was eight units out, which is enough to put the bottom of the panel past
	# the bottom of the display. Measuring the column's other children cannot
	# drift; the stash had the same fault and the same fix.
	var column: Control = _scroll.get_parent() as Control
	_scroll.custom_minimum_size = Vector2(0.0,
		UiMetrics.scroll_room_measured(_scroll, column, Balance.UI_PANEL_MARGIN))
