class_name ComfortCard
extends CanvasLayer

## The three comfort scales, offered once, before the first road.
##
## `docs/ROAD_TO_1_0.md` §7.2: *"the flash scale exists - surface it in
## first-run options rather than burying it."* All three existed and all three
## were four clicks deep in Settings, on a tab nobody has a reason to open
## before they have seen the thing that would send them there. A player made ill
## by flashing should not have to already know the answer exists.
##
## **It writes nothing unless a slider actually moved.** That is the bound and
## it is checked by serializing the whole save either side of an untouched card
## and insisting the two are byte-identical. A first-run card that quietly wrote
## three values every account already had would be a feature that changes every
## save on disk for everybody who dismissed it.
##
## **And it stores no flag saying it has been seen.** `MetaState._read_settings`
## drops undeclared keys, so a new one has to be declared in the defaults - and
## then every save on the machine gains a key on its next write, for players who
## never opened this. Whether to offer it is *derived* from `runs_started`,
## which the save already keeps, exactly as `Graphics.default_preset` and
## `TutorialGrants.should_offer` are derived. That also re-arms correctly after
## `Erase progress` and for a second Warden in a new slot, which a stored flag
## would not.
##
## **The rows come from `UserSettings.COMFORT_ROWS`** rather than being restated
## here, so this card and the settings panel cannot disagree about what a
## slider does. Two definitions of one setting is the failure this project has
## paid for with an Arcane node's reach and with the beast scope's shake.

## Layer 92, beside the slot picker: over the menu, under nothing that matters.
const LAYER: int = 92

var _panel: PanelContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _close_button: Button

## Whether any slider moved. Nothing is written unless this is true.
var _touched: bool = false

## Emitted when the card is closed, so the caller can go on with what it was
## doing. A signal rather than an `await` on a method, because the run opens
## this and a run must never be left waiting on a card nobody can see.
signal closed()


func _ready() -> void:
	# Every plate, button and bar gets the standing animation and the hover
	# hologram. Deferred, because this function builds its own children below -
	# enrolled here and now it would dress an empty `Control`.
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = LAYER
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


## Whether a Warden who has never taken a road should be shown this.
##
## **Derived, never stored.** See the note at the top of the file: a flag would
## be a new settings key, which is a byte every existing save gains for a card
## its owner will never see.
static func should_offer() -> bool:
	return MetaState.runs_started <= 0


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.03, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Comfort"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var heading := Label.new()
	heading.text = "BEFORE THE ROAD"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(heading)

	# Everything but the heading and the way out scrolls, which is the shape the
	# act-start and slot screens settled on: three rows with their readouts are
	# together taller than a landscape phone before Close gets a pixel.
	_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)

	var note := Label.new()
	note.text = ("The road is loud. Set these however you like now, or leave "
		+ "them alone - they are all in Settings whenever you want them.")
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("8f9b98"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)

	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 12)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_rows)
	for row: Dictionary in UserSettings.COMFORT_ROWS:
		_rows.add_child(_comfort_row(row))

	_close_button = Button.new()
	_close_button.text = "Take the road"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	# The way out stays at the bottom of the window whatever is above it.
	UiPanels.pin_last_to_bottom(column)
	_refit()


## One scale, from the table. Label above, slider and readout below, because
## this card is read once by somebody who has not learned the interface yet.
func _comfort_row(row: Dictionary) -> VBoxContainer:
	var key: String = String(row["key"])
	var holder := VBoxContainer.new()
	holder.name = key
	holder.add_theme_constant_override("separation", 2)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = String(row["label"])
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color("d6dedb"))
	holder.add_child(title)

	var note := Label.new()
	note.text = String(row.get("note", ""))
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("7f8c89"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(note)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	holder.add_child(line)

	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = float(row["minimum"])
	slider.max_value = float(row["maximum"])
	slider.step = float(row["step"])
	# **Read, never written.** Opening this card must not set a value: a card
	# that wrote what it found would change the save of everybody who dismissed
	# it, which is the one thing it is not allowed to do.
	slider.value = UserSettings.number(key, float(row["default"]))
	slider.custom_minimum_size = Vector2(240.0, 28.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(slider)

	var readout := Label.new()
	readout.name = "Readout"
	readout.text = _said(slider.value)
	readout.custom_minimum_size = Vector2(64.0, 0.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.add_theme_font_size_override("font_size", 15)
	readout.add_theme_color_override("font_color", Color("9aa8a4"))
	line.add_child(readout)

	slider.value_changed.connect(func(v: float) -> void:
		readout.text = _said(v)
		UserSettings.set_value(key, v)
		_touched = true)
	return holder


static func _said(value: float) -> String:
	return "Off" if value <= 0.001 else "%d%%" % int(round(value * 100.0))


## Sized as a share of the window rather than from fixed minimums that add up,
## which is what pushed the pen's Close button off a short screen once.
func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var wide: float = minf(screen.x * 0.9, 620.0)
	var tall: float = minf(screen.y * 0.86, 560.0)
	_panel.custom_minimum_size = Vector2(wide, tall)
	if _scroll != null:
		# A floor rather than a share: the scroll expands into whatever the
		# panel has spare, so this only has to be small enough that a heading,
		# it and one thumb-sized button fit the shortest screen this runs on.
		_scroll.custom_minimum_size = Vector2(0.0, clampf(tall - 200.0, 60.0, 440.0))


func open() -> void:
	_touched = false
	visible = true
	if _close_button != null:
		_close_button.grab_focus()


## Closes, and saves **only** if something moved.
##
## `UserSettings.set_value` has already applied each change as it happened; what
## this decides is whether the account is written to disk at all. An untouched
## card leaves the save byte for byte where it found it.
func close() -> void:
	visible = false
	if _touched:
		MetaState.save_game()
		_touched = false
	closed.emit()
