class_name ActStartScreen
extends CanvasLayer

## Where a road begins, and how it is outfitted.
##
## **Owner ruling, 2026-09-15:** a player may start a fresh road at any act they
## have reached, and arrives on an authored baseline whose *shape* they choose -
## four doctrines - and whose *size* they do not.
##
## **The screen decides nothing.** Which acts are open is `ActStart.may_start`,
## what a road opens with is `ActStart.budget_for`, and what a doctrine does with
## it is `ActStart.outfit` - every one of them asked and re-read, never copied.
## A screen that kept its own idea of which acts were unlocked would be a second
## opinion about the player's account.
##
## **It is not the expedition and it says so.** Resuming is *your* road picked up
## where you left it; this is a new one that happens to begin further along.
## Confusing the two costs a player a banked front, so the note says which is
## which and the Hold offers them as separate doors.

var _panel: PanelContainer
var _note: Label
var _acts: HFlowContainer
var _doctrines: VBoxContainer
var _doctrine_scroll: ScrollContainer
var _summary: Label
var _begin_button: Button
var _close_button: Button

var _act: int = 1
var _doctrine_id: String = ""


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
	_panel.name = "ActStart"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var heading := Label.new()
	heading.text = "START A ROAD"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(heading)

	# **Everything but the heading and the two buttons scrolls.**
	#
	# The first cut gave each piece its own share of the window, which is the pen
	# screen's approach and works while the pieces are few. Here the note, two
	# wrapped rows of acts and the summary are together taller than a landscape
	# phone before the doctrine list gets a pixel - so Close went off the bottom
	# of a 932x430 screen and `menu_layout_check` said so. One scroll for the
	# body means the panel's own minimum is a heading and two buttons, which fits
	# anything; on a tall screen it simply never scrolls.
	_doctrine_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_doctrine_scroll, TouchInput.is_showing())
	_doctrine_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_doctrine_scroll)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_doctrine_scroll.add_child(body)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", Color("8f9b98"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_note)

	# **Wrapped, not scrolled.** Ten acts do not fit on one row of a phone, and
	# a sideways `ScrollContainer` would have to disable the vertical axis -
	# which is exactly what `UiMetrics.prepare_scroll` mandates and `menu_check`
	# holds every menu surface to. A flow container wraps onto a second row and
	# the interaction contract has one fewer surface to keep.
	_acts = HFlowContainer.new()
	_acts.name = "Acts"
	_acts.add_theme_constant_override("h_separation", 6)
	_acts.add_theme_constant_override("v_separation", 6)
	_acts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_acts)

	_doctrines = VBoxContainer.new()
	_doctrines.name = "Doctrines"
	_doctrines.add_theme_constant_override("separation", 6)
	_doctrines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_doctrines)

	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 15)
	_summary.add_theme_color_override("font_color", Color("c9d3d0"))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_summary)

	# **One row, not two.** `UiMetrics` inflates a button to a thumb on a touch
	# layout, so two stacked buttons pin 240 pixels of a 430-tall landscape phone
	# before the heading or the list get any - which is what put Close off the
	# bottom twice. Side by side, the pinned part is one row high.
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.pressed.connect(close)
	buttons.add_child(_close_button)

	_begin_button = Button.new()
	_begin_button.text = "Take the road"
	_begin_button.custom_minimum_size = Vector2(0.0, 44.0)
	_begin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_begin_button.size_flags_stretch_ratio = 2.0
	_begin_button.pressed.connect(_begin)
	buttons.add_child(_begin_button)
	_refit()


func open() -> void:
	visible = true
	_act = ActStart.furthest_act()
	if _doctrine_id.is_empty():
		var first: DoctrineData = _doctrine_list().front() as DoctrineData
		_doctrine_id = first.id if first != null else ""
	refresh()
	_close_button.grab_focus()


func close() -> void:
	visible = false


## Re-read the account and lay the whole screen out from it.
##
## One function rather than a patch per press, for the reason the pen screen
## gives: the act, the doctrine and what they are worth all change together, and
## a screen that updated one row is a screen that can disagree with itself.
func refresh() -> void:
	_note.text = ("A new road, beginning at an act you have already reached. "
		+ "This is not your banked front - that is Resume, and it stays where it "
		+ "is. Every doctrine below spends the same purse; what you are choosing "
		+ "is its shape.")
	for child: Node in _acts.get_children():
		child.queue_free()
	var furthest: int = ActStart.furthest_act()
	for act: int in range(1, furthest + 1):
		var button := Button.new()
		button.text = "Act %d" % act
		button.toggle_mode = true
		button.button_pressed = act == _act
		button.custom_minimum_size = Vector2(76.0, 40.0)
		var chosen: int = act
		button.pressed.connect(func() -> void:
			_act = chosen
			refresh())
		_acts.add_child(button)

	for child: Node in _doctrines.get_children():
		child.queue_free()
	for doctrine: DoctrineData in _doctrine_list():
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = doctrine.id == _doctrine_id
		button.custom_minimum_size = Vector2(0.0, 58.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s" % [doctrine.display_name, doctrine.description]
		button.add_theme_font_size_override("font_size", 14)
		var chosen_id: String = doctrine.id
		button.pressed.connect(func() -> void:
			_doctrine_id = chosen_id
			refresh())
		_doctrines.add_child(button)

	_summary.text = _summary_text()
	# Act I needs no doctrine - it *is* the walk, and there is nothing to outfit.
	_begin_button.text = "Take the road from Act %d" % _act


## What this road opens with, read off the same doors that will open it.
func _summary_text() -> String:
	if _act <= 1:
		return ("Act I opens with nothing built and nothing spare, which is the "
			+ "game as it is meant to begin. No doctrine applies.")
	var budget: int = ActStart.budget_for(_act)
	var doctrine: DoctrineData = ContentDB.doctrine(_doctrine_id)
	if doctrine == null:
		return "%d Gold to outfit with." % budget
	var span: int = maxi(Balance.ACT_START_BOARD_MAX - Balance.ACT_START_BOARD_MIN, 0)
	var wanted: int = Balance.ACT_START_BOARD_MIN + int(round(
		float(span) * clampf(doctrine.breadth, 0.0, 1.0)))
	var spare: int = int(round(float(budget) * (1.0 - clampf(
		doctrine.board_share, 0.0, 1.0))))
	return ("%d Gold, which %s spends on about %d emplacements and leaves roughly "
		+ "%d in the purse. The board is built before the first wave; what is "
		+ "spare is yours.") % [budget, doctrine.display_name, wanted, spare]


func _doctrine_list() -> Array:
	var all: Array = []
	for value: Variant in ContentDB.doctrines.values():
		var doctrine := value as DoctrineData
		if doctrine != null:
			all.append(doctrine)
	all.sort_custom(func(a: DoctrineData, b: DoctrineData) -> bool:
		return a.breadth > b.breadth)
	return all


func _begin() -> void:
	if not ActStart.may_start(_act):
		return
	close()
	# Act I is an ordinary new run; there is no road behind it to outfit.
	if _act <= 1:
		GameDirector.start_run()
	else:
		GameDirector.start_run(0, false, _act, _doctrine_id)


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	# Measured as a share of the window rather than as fixed minimums, because
	# fixed minimums that add up are what pushed the pen's Close button off a
	# short screen.
	var wide: float = minf(screen.x * 0.9, 700.0)
	var tall: float = minf(screen.y * 0.86, 680.0)
	_panel.custom_minimum_size = Vector2(wide, tall)
	if _doctrine_scroll != null:
		# **A floor rather than a share.** The scroll already expands into
		# whatever the panel has spare, so all this has to do is be small enough
		# that the panel's own minimum - a heading, this, and one row of thumb-
		# sized buttons - fits the shortest screen the game runs on.
		_doctrine_scroll.custom_minimum_size = Vector2(0.0,
			clampf(tall - 260.0, 60.0, 440.0))
