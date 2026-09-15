class_name PenScreen
extends CanvasLayer

## The pen: the animals the Warden has raised, and what may be done with them.
##
## **Owner brief, 2026-09-15:** a pen where living companions are kept with idle,
## roaming and resting animations, up to a limit, with the option to release one
## to make room, and a choice of which to take on the next expedition.
##
## **The screen decides nothing.** Every button here calls a door on `MetaState`
## and then re-reads what it says - `pen_take`, `pen_release` - so the rules
## about one at a time, the cap, and not editing the pen mid-run live in one
## place and the screen cannot disagree with them. A screen that enforced its own
## copy of those rules would be a second opinion about the player's animals.
##
## **It only opens between runs**, which is where the pen is editable at all; the
## Hold is a between-runs room, so that is where the door is.

const YardScript = preload("res://scripts/systems/pen_yard.gd")

var _panel: PanelContainer
var _heading: Label
var _note: Label
var _yard: PenYard
var _stage: Control
var _list: VBoxContainer
var _close_button: Button


func _ready() -> void:
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
	_panel.name = "Pen"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_heading = Label.new()
	_heading.text = "THE PEN"
	_heading.add_theme_font_size_override("font_size", 28)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", Color("8f9b98"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)

	# The yard itself, drawn inside a fixed rectangle so the layout does not
	# depend on how many animals happen to be kept.
	var stage := Control.new()
	stage.name = "Yard"
	# Sized in `_refit` from what the window actually has. A fixed minimum here
	# is what put the Close button off the bottom of a short screen.
	stage.custom_minimum_size = Vector2(320.0, 150.0)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	_stage = stage
	_yard = YardScript.new()
	_yard.name = "PenYard"
	stage.add_child(_yard)
	stage.resized.connect(func() -> void:
		_yard.position = stage.size * 0.5
		_yard.set_stage(stage.size - Vector2(16.0, 16.0)))

	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.custom_minimum_size = Vector2(0.0, 110.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.name = "Kept"
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	_refit()


func open() -> void:
	visible = true
	refresh()
	_close_button.grab_focus()


func close() -> void:
	visible = false


## Re-read the pen and lay the whole screen out from it.
##
## One function rather than a patch per button, because the cap, what is out and
## what may be released all change together - a screen that updated one row would
## be a screen that can disagree with itself about a pen the player just changed.
func refresh() -> void:
	if _yard != null:
		_yard.refresh()
	for child: Node in _list.get_children():
		child.queue_free()
	var kept: int = MetaState.pen.size()
	_note.text = ("%d of %d kept. One goes with you; the rest wait here. An "
		+ "animal that falls on the road does not come back - what it taught "
		+ "you does.") % [kept, Balance.PEN_CAPACITY]
	if kept == 0:
		var empty := Label.new()
		empty.text = "Nothing raised yet. Carry an egg home and see what it becomes."
		empty.add_theme_color_override("font_color", Color("7d8a86"))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
		return
	for animal: Dictionary in MetaState.pen:
		_list.add_child(_row(animal))


## One kept animal: what it is, and the two things that may be done to it.
func _row(animal: Dictionary) -> Control:
	var uid: String = String(animal.get("uid", ""))
	var species: String = String(animal.get("species", ""))
	var kind := ContentDB.wildlife_kinds.get(species, null) as WildlifeData
	var out: bool = MetaState.pen_taken == uid

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	var rarity: int = int(animal.get("rarity", 0))
	var shiny: bool = bool(animal.get("shiny", false))
	name_label.text = "%s%s · %s" % [
		"Shining " if shiny else "",
		"?" if kind == null else kind.display_name,
		Balance.SPIRIT_RARITY_NAMES[clampi(rarity, 0, 3)]]
	name_label.add_theme_color_override("font_color",
		Balance.SPIRIT_RARITY_COLOURS[clampi(rarity, 0,
			Balance.SPIRIT_RARITY_COLOURS.size() - 1)])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var take := Button.new()
	take.text = "Leave here" if out else "Take along"
	take.custom_minimum_size = Vector2(130.0, 40.0)
	take.pressed.connect(func() -> void:
		# The door refuses during a run; the screen simply asks and re-reads.
		MetaState.pen_take("" if out else uid)
		refresh())
	row.add_child(take)

	var release := Button.new()
	release.text = "Release"
	release.custom_minimum_size = Vector2(110.0, 40.0)
	release.tooltip_text = ("It goes back to the road. You keep what you learned "
		+ "from raising it.")
	release.pressed.connect(func() -> void:
		MetaState.pen_release(uid)
		refresh())
	row.add_child(release)
	return row


## **Everything here is a share of the window rather than a figure.**
##
## The first cut added fixed minimums - a 280-tall yard, a 220-tall list, a
## heading, a note and a 44-tall button - which came to 853 on a 775-tall screen
## and pushed the way out off the bottom. `menu_layout` refuses that, and it is
## right to: a player who cannot see Close cannot leave. So the panel takes what
## the window has and the yard takes what is left after the parts that must be
## readable.
func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var wide: float = minf(screen.x * 0.9, 700.0)
	var tall: float = minf(screen.y * 0.88, 760.0)
	_panel.custom_minimum_size = Vector2(wide, tall)
	if _stage != null:
		# The heading, the note, the list and the button, plus the panel's own
		# margins - measured as a share so a theme change cannot strand it.
		var kept_back: float = tall * 0.52 + 96.0
		_stage.custom_minimum_size = Vector2(wide - 48.0,
			clampf(tall - kept_back, 110.0, 300.0))


## The yard, for the gate.
func yard() -> PenYard:
	return _yard
