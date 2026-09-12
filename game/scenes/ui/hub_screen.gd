class_name HubScreen
extends CanvasLayer
## The Hold: the standing hub (owner ruling, 2026-09-11).
##
## `IDEAS_REVIEW` §4 refused a hub as "the grammar of a map you hold, and this
## map walks", and that reading still stands for the *world* - the town rides
## the beast and nothing here is a place on it. What the owner asked for is a
## lobby: the one screen where a player meets other players, trades, reads the
## Ledger, and sees who their Warden has become. So this is a view over things
## the menu already had doors to, arranged as one room rather than a column of
## buttons, with the Warden's card beside them.
##
## **It owns no screen.** The menu builds the stash, the Ledger, the co-op
## screen and the rest exactly as before and hands their buttons to this room
## with `adopt`. A button here is the same button it was on the front door -
## same handler, same focus return - so nothing that worked stops working,
## and the front door gets to be a front door.
##
## Laid out the way the codex is: the card and the doors are the flexible part
## and scroll, and the way out is always on screen - `menu_layout_check` holds
## that at phone size, and the first draft of this failed it with the Close
## button fourteen hundred pixels above the top of the screen.

signal closed()

const PANEL_MAX_WIDTH: float = 1100.0
const PANEL_SCREEN_SHARE: float = 0.94
const BODY_SCREEN_SHARE: float = 0.52
const BODY_SCREEN_SHARE_PORTRAIT: float = 0.66
const PORTRAIT_SIZE: float = 128.0
const PORTRAIT_ART: Array[String] = [
	"res://art/hero/hero_base.png",
	"res://art/hero/hero_ascended_1.png",
	"res://art/hero/hero_ascended_2.png",
]

var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: BoxContainer
var _card: VBoxContainer
var _grid: GridContainer
var _close_button: Button
var _first_button: Button = null


func _ready() -> void:
	layer = 90
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.03, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Hold"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var title := Label.new()
	title.text = "THE HOLD"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(title)

	var note := Label.new()
	note.text = ("Where the road's people meet. Companions, trade, the Ledger, and what the "
		+ "Warden has become.")
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("8f9b98"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	_body = BoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override("separation", 18)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	_card = VBoxContainer.new()
	_card.name = "Card"
	_card.add_theme_constant_override("separation", 6)
	_body.add_child(_card)

	_grid = GridContainer.new()
	_grid.name = "Doors"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_grid)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	_refit()


## A door from the front door, moved into the room. The button keeps its
## handler and its focus return; only its parent changes.
func adopt(button: Button) -> void:
	if button == null:
		return
	var parent: Node = button.get_parent()
	if parent != null:
		parent.remove_child(button)
	button.custom_minimum_size = Vector2(0.0, 60.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_child(button)
	if _first_button == null:
		_first_button = button


func open() -> void:
	_build_card()
	visible = true
	_refit()
	_refit.call_deferred()
	if _first_button != null and is_instance_valid(_first_button):
		_first_button.grab_focus()
	else:
		_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## The Warden's card: who they are on this account, read fresh on every open
## so a run just finished shows.
func _build_card() -> void:
	for child: Node in _card.get_children():
		_card.remove_child(child)
		child.queue_free()

	var portrait := TextureRect.new()
	var art: String = PORTRAIT_ART[clampi(MetaState.ascension, 0, PORTRAIT_ART.size() - 1)]
	if ResourceLoader.exists(art):
		portrait.texture = load(art)
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_card.add_child(portrait)

	var name_line := Label.new()
	name_line.text = MetaState.player_name if not MetaState.player_name.is_empty() else "Oathless"
	name_line.add_theme_font_size_override("font_size", 22)
	name_line.add_theme_color_override("font_color", Color("f2e6d0"))
	_card.add_child(name_line)

	_line("%s  ·  level %d" % [MetaState.warden_title(), MetaState.hero_level], Color("e8a33d"))
	if MetaState.ascension > 0:
		_line("Ascended %d of %d times" % [MetaState.ascension, Balance.ASCENSION_MAX], Color("b8ae98"))
	if not MetaState.play_code.is_empty():
		_line("Play code  %s" % MetaState.play_code, Color("b8ae98"))
	_line("%d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards], Color("b8ae98"))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_card.add_child(spacer)
	var heading := Label.new()
	heading.text = "PROFESSIONS"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color("e8a33d"))
	_card.add_child(heading)
	for id: String in Balance.PROFESSIONS:
		_profession_row(id)

	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 6.0)
	_card.add_child(spacer)
	_line("%d runs  ·  %d won  ·  %d rift stages closed" % [MetaState.runs_started,
		MetaState.runs_won, MetaState.rifts_closed], Color("8f9b98"))


func _line(text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(label)


func _profession_row(id: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	var progress: Vector2 = MetaState.profession_progress(id)
	label.text = "%s  ·  level %d  ·  %d / %d" % [id.capitalize(),
		MetaState.profession_level(id), int(progress.x), int(progress.y)]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("c9c2b4"))
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.max_value = maxf(progress.y, 1.0)
	bar.value = progress.x
	bar.show_percentage = false
	row.add_child(bar)
	_card.add_child(row)


## Sized against the screen, like the codex: the panel takes most of the
## width, the scrolling body a share of the height, and on a screen held
## upright the card sits above the doors rather than beside them.
func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = screen.y > screen.x
	var width: float = minf(PANEL_MAX_WIDTH, screen.x * PANEL_SCREEN_SHARE)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	var share: float = BODY_SCREEN_SHARE_PORTRAIT if portrait else BODY_SCREEN_SHARE
	_scroll.custom_minimum_size = Vector2(0.0, maxf(240.0, screen.y * share))
	_body.vertical = portrait
	_grid.columns = 1 if portrait else 2
	_card.custom_minimum_size = Vector2(0.0, 0.0) if portrait else Vector2(300.0, 0.0)
	_panel.reset_size()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
