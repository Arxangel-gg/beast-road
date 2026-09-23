class_name SaveSlotScreen
extends CanvasLayer

## The Wardens this machine keeps, and which one is being played.
##
## **Owner, 2026-09-22:** "save slots per profile are desirable."
##
## **The screen decides nothing.** Which slot is active, what each one holds,
## whether a switch is allowed and whether a slot may be erased are all
## `MetaState` doors - `slot`, `slot_summary`, `use_slot`, `erase_slot` - asked
## and re-read, never copied. A screen that kept its own idea of which slot was
## live would be a second opinion about which save the game is writing, which is
## the one disagreement in this project nobody can undo.
##
## **The first Warden is the save that was already there**, and the page says
## so. An existing account is slot one by definition rather than by migration
## (`MetaState.slot_path`), and "Erase" is deliberately not offered for it: a
## player who wants that account gone wants `Erase progress` in Settings, which
## is a different door with its own confirmation and does not leave the game
## pointing at a file it just deleted.
##
## **It only opens between runs**, because that is the only time a slot may
## change - the rule `MetaState.use_slot` holds and the reason it holds it. The
## page says why rather than showing a dead button with no explanation.

var _panel: PanelContainer
var _note: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _close_button: Button

## The erase that has been asked for once. Two presses, like giving up a front
## on the menu: a single press that deletes a Warden is a press somebody makes
## by accident exactly once.
var _armed: int = -1


func _ready() -> void:
	# Every plate, button and bar on this screen gets the standing animation and
	# the hover hologram (owner, 2026-09-17). **Deferred**, because a screen
	# builds its own children further down this same function - enrolled here and
	# now it would dress an empty `Control` and nothing else.
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 92
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.03, 0.80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "SaveSlots"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var heading := Label.new()
	heading.text = "WARDENS"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(heading)

	# **Everything but the heading and the way out scrolls**, which is the shape
	# `act_start_screen` settled on and for the same measured reason: four cards
	# with their own buttons are together taller than a landscape phone before
	# Close gets a pixel. One scroll for the body means the panel's own minimum
	# is a heading, a strip and one thumb-sized row, which fits anything.
	_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", Color("8f9b98"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_note)

	_list = VBoxContainer.new()
	_list.name = "Slots"
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_list)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	# The way out stays at the bottom of the window whatever is above it.
	UiPanels.pin_last_to_bottom(column)
	_refit()


func open() -> void:
	visible = true
	refresh()
	_close_button.grab_focus()


func close() -> void:
	visible = false


## Re-read every slot and lay the whole page out from it.
##
## One function rather than a patch per press, the reason the pen and act-start
## screens give: which slot is live, what each holds and what may be done to
## them all change together, and a page that updated one row is a page that can
## disagree with itself about which Warden is being played.
func refresh() -> void:
	_armed = -1
	for child: Node in _list.get_children():
		child.queue_free()
	_note.text = _note_text()
	for index: int in Balance.SAVE_SLOTS:
		_list.add_child(_card(MetaState.slot_summary(index)))


func _note_text() -> String:
	if not _between_runs():
		return ("A road is under way, so the Warden cannot be changed. Switching "
			+ "now would walk away from a front that has not been banked. Finish "
			+ "the road, or turn for home at a crossroad, and come back.")
	return ("Each Warden keeps everything of their own - level, gear, stash, pen, "
		+ "stable, larder, crafts and banked road. The first is the account this "
		+ "machine already had. A banked road stays with the Warden who banked "
		+ "it, so changing Warden never costs one.")


## Whether a slot may change at all, asked the way `MetaState.use_slot` asks it
## rather than kept here. The door refuses regardless; this only decides what
## the page says and which buttons are worth offering.
func _between_runs() -> bool:
	return not RunState.road_is_live()


func _card(summary: Dictionary) -> Control:
	var index: int = int(summary.get("index", 0))
	var current: bool = bool(summary.get("current", false))
	var exists: bool = bool(summary.get("exists", false))

	var card := PanelContainer.new()
	card.name = "Slot%d" % index
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)

	var title := Label.new()
	title.text = "Warden %d%s" % [index + 1, "   ·   playing now" if current else ""]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color",
		Color("e8a33d") if current else Color("c9d3d0"))
	row.add_child(title)

	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color("8f9b98"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text = _detail_text(summary)
	row.add_child(detail)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	row.add_child(buttons)

	var play := Button.new()
	play.name = "Play%d" % index
	play.text = "Playing" if current else ("Play this Warden" if exists else "Begin here")
	play.custom_minimum_size = Vector2(0.0, 40.0)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.disabled = current or not _between_runs()
	play.pressed.connect(func() -> void:
		# The door refuses during a run and for an index this build has no slot
		# for; the page simply asks and re-reads whatever it says.
		MetaState.use_slot(index)
		refresh())
	buttons.add_child(play)

	# **The first Warden has no Erase**, and the button says why rather than
	# being missing: the historic save is what every other slot is measured
	# against, and throwing it away is `Erase progress` in Settings.
	var erase := Button.new()
	erase.name = "Erase%d" % index
	erase.custom_minimum_size = Vector2(0.0, 40.0)
	erase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if index == 0:
		erase.text = "Kept"
		erase.disabled = true
		erase.tooltip_text = ("The first Warden is the account this machine "
			+ "already had. Settings has Erase progress.")
	elif current:
		erase.text = "Erase"
		erase.disabled = true
		erase.tooltip_text = "Move to another Warden first."
	elif not exists:
		erase.text = "Erase"
		erase.disabled = true
	else:
		erase.text = "Erase" if _armed != index else "Erase for good?  ·  press again"
		erase.disabled = not _between_runs()
		erase.pressed.connect(func() -> void:
			if _armed != index:
				_armed = index
				erase.text = "Erase for good?  ·  press again"
				return
			MetaState.erase_slot(index)
			refresh())
	buttons.add_child(erase)
	return card


## What a slot is worth saying, read off the summary and nothing else.
func _detail_text(summary: Dictionary) -> String:
	if not bool(summary.get("exists", false)):
		return "Empty.  A new Warden begins here, from the first road."
	var name_shown: String = String(summary.get("name", "")).strip_edges()
	if name_shown.is_empty():
		name_shown = "Unnamed"
	var parts: PackedStringArray = [
		name_shown,
		"Level %d" % int(summary.get("level", 1)),
		"Act %d" % int(summary.get("act", 1)),
		"%d Marks" % int(summary.get("marks", 0)),
	]
	var rank: int = int(summary.get("ascension", 0))
	if rank > 0:
		parts.append("Ascension %d" % rank)
	var played: int = int(summary.get("played", 0))
	if played > 0:
		parts.append("last played %s" % _how_long_ago(played))
	return "   ·   ".join(parts)


## When a slot was last written, said the way a person says it.
##
## From the file's own modified time, so it cannot drift from the file it
## describes and nothing had to be added to the save to carry it. Never in
## seconds: a Warden nobody has touched for a fortnight is "14 days", and
## "1209600" is a number nobody reads.
func _how_long_ago(unix_seconds: int) -> String:
	var elapsed: int = int(Time.get_unix_time_from_system()) - unix_seconds
	if elapsed < 90:
		return "just now"
	var minutes: int = elapsed / 60
	if minutes < 60:
		return "%d min ago" % minutes
	var hours: int = minutes / 60
	if hours < 24:
		return "%dh ago" % hours
	return "%d day%s ago" % [hours / 24, "" if hours / 24 == 1 else "s"]


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	# A share of the window rather than fixed minimums that add up, which is
	# what pushed the pen's Close button off a short screen once.
	var wide: float = minf(screen.x * 0.9, 700.0)
	var tall: float = minf(screen.y * 0.86, 660.0)
	_panel.custom_minimum_size = Vector2(wide, tall)
	if _scroll != null:
		# A floor rather than a share: the scroll already expands into whatever
		# the panel has spare, so this only has to be small enough that a
		# heading, it, and one thumb-sized row fit the shortest screen the game
		# runs on.
		_scroll.custom_minimum_size = Vector2(0.0, clampf(tall - 200.0, 60.0, 520.0))
