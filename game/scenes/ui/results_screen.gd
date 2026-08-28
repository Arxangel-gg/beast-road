class_name ResultsScreen
extends CanvasLayer

## End of run (GDD §9, §10). Win or lose, the unlock payout has already been
## banked by GameDirector; this only reports it.

@export var panel: Control
@export var title: Label
@export var body: Label
@export var menu_button: Button

## The score line, the name field and the submit button.
##
## Submission is a **button, never automatic**, for two reasons and either would
## be enough. A name is published to a board other people read, and publishing
## someone's chosen name is an action they should take rather than one that
## happens to them. And the headless gates — the soak, the balance run, the
## breather check — drive real runs to completion; a `run_ended` handler that
## posted would put CI on the public board every time it was green.
var _score_label: Label
var _name_field: LineEdit
var _submit_button: Button
var _submit_note: Label
var _pending_row: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	# The panel was a fixed 800x600 box. A finished three-act run produces the
	# longest debrief in the game - every act, every road, and the whole unlock
	# payout - and a VBoxContainer does not shrink its children below their
	# minimum size, so the text simply pushed the one button off the bottom.
	# Winning the game left the player on a screen with no way out of it.
	# Wide enough for the longest debrief, and centred rather than stretched: a
	# full-height panel around a short summary is a small block of text at the
	# top of an enormous empty box, which reads as a bug rather than as a screen.
	# Centred by a container rather than by anchors.
	#
	# The panel carried offsets from the scene (-400 to +400) and was then given a
	# 1180 minimum width. A PanelContainer grows right from its left offset, so it
	# ended up 190 units left of centre with its right edge - and the button on it
	# - hanging off the side of a 1600-wide window. Anchoring cannot express
	# "centre something whose size depends on its contents"; a CenterContainer
	# can, and it stays correct at any window size and any length of debrief.
	_centre_panel()
	panel.custom_minimum_size = Vector2(1180.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	IconKit.on_button(menu_button, "close", 24)
	# The body sits on its own dark plate rather than directly on the ornate
	# frame. Twelve lines of statistics against riveted ironwork is a lot of
	# texture behind a lot of small type, and the plate is what makes it legible.
	_plate_body()
	_build_board_row()
	menu_button.text = "Return to the menu"
	menu_button.pressed.connect(_leave)
	Leaderboard.submitted.connect(_on_submitted)


## The score, and the one control that publishes it.
func _build_board_row() -> void:
	var column: Node = menu_button.get_parent()
	if column == null:
		return
	var at: int = menu_button.get_index()

	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color("e8a33d"))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_score_label)
	column.move_child(_score_label, at)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	column.move_child(row, at + 1)

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Name for the board"
	_name_field.max_length = Balance.SCORE_NAME_MAX
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.custom_minimum_size = Vector2(0.0, 40.0)
	row.add_child(_name_field)

	_submit_button = Button.new()
	_submit_button.text = "Post to the board"
	_submit_button.custom_minimum_size = Vector2(220.0, 40.0)
	_submit_button.pressed.connect(_submit)
	row.add_child(_submit_button)

	_submit_note = Label.new()
	_submit_note.add_theme_font_size_override("font_size", 13)
	_submit_note.add_theme_color_override("font_color", Color("b8ae98"))
	_submit_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_submit_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_submit_note)
	column.move_child(_submit_note, at + 2)


func _submit() -> void:
	if _pending_row.is_empty():
		return
	var chosen: String = Score.clean_name(_name_field.text)
	# Remembered so the next run's field is already filled. A player who has to
	# retype their name every run will stop posting after two.
	MetaState.player_name = chosen
	MetaState.save_game()
	_submit_button.disabled = true
	_submit_note.text = "Sending…"
	Leaderboard.submit(_pending_summary, ContentDB.tier(RunState.tier_id))


func _on_submitted(ok: bool, message: String) -> void:
	if _submit_note == null:
		return
	_submit_note.text = message
	# A failed post is already in the bounded outbox. Re-enabling here would mint
	# a second submission id and turn one offline run into two eventual rows.
	_submit_button.disabled = true


## Fills in the score line and readies the submit row.
func _show_score(summary: Dictionary) -> void:
	_pending_summary = summary
	var tier: CampaignTierData = ContentDB.tier(RunState.tier_id)
	_pending_row = Score.row(summary, tier, MetaState.player_name,
		MetaState.hero_level, "", "preview")
	if _score_label != null:
		_score_label.text = "Score  %s        %s" % [
			_grouped(int(_pending_row.get("score", 0))),
			tier.display_name if tier != null else "Normal"]
	if _name_field != null:
		# Empty rather than pre-filled with the fallback: a field showing
		# "Oathless" reads as a name already chosen, and the player posts it.
		_name_field.text = MetaState.player_name
	if _submit_button != null:
		_submit_button.disabled = false
	if _submit_note != null:
		_submit_note.text = ""


## Thousands separated, because a five-digit score is unreadable without it.
func _grouped(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			out += ","
		out += digits[index]
	return ("-" if value < 0 else "") + out


## Wraps the panel in a container that fills the screen and centres its child.
func _centre_panel() -> void:
	var parent: Node = panel.get_parent()
	if parent == null or parent is CenterContainer:
		return
	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The container is only for layout; clicks belong to the panel on it.
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var index: int = panel.get_index()
	parent.remove_child(panel)
	parent.add_child(centre)
	parent.move_child(centre, index)
	centre.add_child(panel)


func _leave() -> void:
	get_tree().paused = false
	GameDirector.goto_menu()


## The debrief is a dead end unless something can dismiss it, and a mouse is not
## the only way people play. Escape and the controller's accept both leave.
func _unhandled_input(event: InputEvent) -> void:
	if panel == null or not panel.visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_leave()


func _plate_body() -> void:
	if body == null or body.get_parent() == null:
		return
	var column: Node = body.get_parent()
	var index: int = body.get_index()
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"InnerPanel"
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# The statistics scroll and the button does not. Length is content here - a
	# longer run genuinely has more to say - so the fix is to give the text
	# somewhere to go, not to trim what a player earned the right to read.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Grows with the text up to a ceiling, then scrolls. Expanding to fill
	# instead is what left a short debrief floating in a void, and a fixed height
	# would clip the long one - which is the case that had no way out.
	scroll.custom_minimum_size = Vector2(0.0, 0.0)
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	column.remove_child(body)
	plate.add_child(body)
	scroll.add_child(plate)
	column.add_child(scroll)
	column.move_child(scroll, index)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Statistics are read down a column, so they need room between the lines. The
	# default leading packs them tight enough that the eye loses its place.
	body.add_theme_constant_override("line_spacing", 6)


## The summary this screen is showing, held for the submit button.
var _pending_summary: Dictionary = {}


func show_results(victory: bool, summary: Dictionary) -> void:
	_show_score(summary)
	title.text = "The sanctuary" if victory else "The road ends here"
	# Focused so a controller or the keyboard can leave without hunting for the
	# button, and so the one way out is visibly the one way out.
	menu_button.grab_focus.call_deferred()

	var unlocks: Array = summary.get("unlocks", [])
	var chronicle: Array = summary.get("chronicle", [])
	var seconds: int = int(summary.get("time", 0))
	var duration: String = "%d:%02d" % [seconds / 60, seconds % 60]
	var planning_seconds: int = int(summary.get("planning_time", 0))
	var planning_duration: String = "%d:%02d" % [planning_seconds / 60, planning_seconds % 60]
	var wave_id: String = String(summary.get("most_common_wave", ""))
	var wave: WaveArchetypeData = ContentDB.wave_archetype(wave_id)
	var wave_name: String = wave.display_name if wave != null else "—"
	var command_orders: Dictionary = summary.get("command_orders", {})
	var command_order_total: int = 0
	for value: Variant in command_orders.values():
		command_order_total += int(value)
	var road_names: PackedStringArray = []
	for entry: Dictionary in summary.get("roads", []):
		var road: RoadData = ContentDB.road(String(entry.get("road", "")))
		var difficulty: RoadDifficultyData = ContentDB.road_difficulty(
			String(entry.get("difficulty", "")))
		if road != null and difficulty != null:
			road_names.append("%s %s" % [difficulty.display_name, road.display_name])
	var route_lines: PackedStringArray = []
	for start: int in range(0, road_names.size(), 3):
		route_lines.append("  →  ".join(road_names.slice(start, mini(start + 3, road_names.size()))))
	var lines: PackedStringArray = [
		"Run seed   %09d" % int(summary.get("seed", 0)),
		"Route   %s" % ("\n        ".join(route_lines) if not route_lines.is_empty() else "—"),
		"Distance   %d of %d" % [int(summary.get("distance", 0)), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Reached act %d   ·   %s combat   ·   %s planning" % [
			int(summary.get("act", 1)), duration, planning_duration],
		"Killed %d   ·   fell %d times" % [int(summary.get("kills", 0)), int(summary.get("deaths", 0))],
		"Raids %d   ·   Oathbound leaders %d" % [int(summary.get("raids", 0)), int(summary.get("chieftains", 0))],
		"",
		"DEFENCE",
		"Town damage %d across %d breaches   ·   peak pressure %d%%" % [
			int(round(float(summary.get("town_damage", 0.0)))),
			int(summary.get("town_hits", 0)),
			int(round(float(summary.get("peak_pressure", 0.0)) * 100.0))],
		"Built %d   ·   upgraded %d   ·   lost %d   ·   sold %d" % [
			int(summary.get("towers_built", 0)), int(summary.get("tower_upgrades", 0)),
			int(summary.get("towers_lost", 0)), int(summary.get("towers_sold", 0))],
		"Resources earned %d   ·   invested %d   ·   signature threat %s" % [
			int(summary.get("resources_earned", 0)), int(summary.get("resources_spent", 0)), wave_name],
		"Command earned %d   ·   orders issued %d" % [
			int(round(float(summary.get("command_earned", 0.0)))), command_order_total],
		"Wounds suffered %d   ·   Hearthmends %d" % [
			int(summary.get("wounds", 0)), int(summary.get("hearthmends", 0))],
		"",
		"Tools %d   ·   Legacy rank %d of %d" % [
			int(summary.get("tools", 0)), int(summary.get("sigils", 0)),
			Balance.SIGIL_MAX_RANK],
		"",
		"Added to the pool: %d" % unlocks.size(),
	]
	for entry: String in unlocks:
		lines.append("   " + entry.replace(":", "  "))
	if not chronicle.is_empty():
		lines.append("")
		lines.append("CHRONICLE  ·  %d deed%s kept  ·  +%d Tools" % [
			chronicle.size(), "" if chronicle.size() == 1 else "s",
			int(summary.get("chronicle_tools", 0))])
		for id: String in chronicle:
			var objective: ChronicleObjectiveData = ContentDB.chronicle_objective(id)
			if objective != null:
				lines.append("   ◆  " + objective.display_name)

	# GDD §46 wants the version in the debrief as well as in Settings, and this is
	# the better of the two places: it is the screen somebody is looking at when a
	# run has just gone wrong, which is the moment they screenshot it.
	lines.append("")
	lines.append(BuildInfo.diagnostics())
	body.text = "\n".join(lines)

	# Measured after the text is in, so the panel is only as tall as it needs to
	# be and the scroll only appears when the debrief actually overruns.
	await get_tree().process_frame
	var wanted: float = body.get_combined_minimum_size().y
	var scroll_box: ScrollContainer = body.get_parent().get_parent() as ScrollContainer
	if scroll_box != null:
		# Reserve the real height consumed by the title and the complete board
		# footer. A percentage of the viewport worked before the leaderboard row
		# existed, then pushed both the focused exit button and the submit status
		# below 1080p. The content scroll is the flexible part; every action stays
		# on screen.
		var column: VBoxContainer = scroll_box.get_parent() as VBoxContainer
		var fixed_height: float = 0.0
		var fixed_controls: int = 0
		if column != null:
			for child: Node in column.get_children():
				if child is Control and child != scroll_box and (child as Control).visible:
					fixed_height += (child as Control).get_combined_minimum_size().y
					fixed_controls += 1
		var separation: float = float(column.get_theme_constant("separation")) \
			if column != null else 0.0
		var viewport_height: float = get_viewport().get_visible_rect().size.y
		var available: float = viewport_height - 96.0 - fixed_height \
			- separation * float(fixed_controls)
		scroll_box.custom_minimum_size = Vector2(0.0,
			minf(wanted, maxf(220.0, available)))

	panel.visible = true
	get_tree().paused = true
	menu_button.grab_focus()
