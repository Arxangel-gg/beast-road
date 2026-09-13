class_name SmithyScreen
extends CanvasLayer

## The forge in the Hold: where wood, ore and a gem become a piece of gear.
##
## Owner brief, 2026-09-13: a place to smith, and "a gem plus smithing level
## gives a chance at rarity".
##
## **In the Hold rather than on the road**, and that is the same reasoning the
## stash is there under: materials persist and a run does not, so the forge
## belongs beside the other things a Warden owns between roads. It is also the
## one place a player can see everything the mines gave them at once, which is
## what makes going back out for a Duskstone a decision rather than a habit.
##
## **The odds are on the screen.** `Forge.rung_odds` is drawn before anything is
## spent, because a forge that hides its chances is a slot machine, and the
## whole point of practising the Smith is that the player can see it working.

signal closed()

const PANEL_WIDTH: float = 980.0
## The material swatch. Photographed at 44 and the four woods were four brown
## boxes; the frame round them was louder than the art inside it.
const SWATCH: float = 58.0
const FORGE_ART: String = "res://art/battlefield/smithy.png"
## The header, and the screen height below which it is not worth its room.
##
## A picture is the first thing to give up when the way out is at stake:
## `menu_layout_check` failed the first cut of this screen at phone sizes
## with "no way out at all", and the forge was a third of why.
const HEADER_HEIGHT: float = 132.0
const HEADER_MIN_SCREEN: float = 900.0

var _heading: Label
var _note: Label
var _panel: PanelContainer
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _close_button: Button
var _strike_button: Button = null
var _result: Label = null
var _art: TextureRect = null

## What is on the anvil.
var _wood: String = ""
var _ore: String = ""
var _gem: String = ""


func _ready() -> void:
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_refit)
	visible = false


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	# The forge itself, above its own screen. A header rather than an animation:
	# the generated flare cycle strobed from embers to near-white and read as a
	# fault rather than as fire, so the still frame is the one that ships.
	if ResourceLoader.exists(FORGE_ART):
		_art = TextureRect.new()
		_art.texture = load(FORGE_ART) as Texture2D
		_art.custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		FrameKit.hang(_art)
		column.add_child(_art)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_note)

	_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	_scroll.add_child(_rows)

	_result = Label.new()
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.add_theme_font_size_override("font_size", 15)
	_result.add_theme_color_override("font_color", Color("d8d2c4"))
	column.add_child(_result)

	_strike_button = Button.new()
	_strike_button.text = "Strike"
	_strike_button.custom_minimum_size = Vector2(0.0, 48.0)
	_strike_button.pressed.connect(_strike)
	column.add_child(_strike_button)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(hide_screen)
	column.add_child(_close_button)


func open() -> void:
	visible = true
	_pick_defaults()
	_refresh()
	_refit()
	_refit.call_deferred()
	_close_button.grab_focus()


func hide_screen() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


## Opens on something the player can actually afford, where there is one.
##
## A forge that opens on three empty slots and a refusal reads as broken; a
## forge that opens on the cheapest workable recipe reads as a forge.
func _pick_defaults() -> void:
	for kind: MaterialData in ContentDB.materials_sorted():
		var held: int = MetaState.material_count(kind.id)
		if held <= 0:
			continue
		match kind.kind:
			MaterialData.Kind.WOOD:
				if _unusable(_wood, Balance.FORGE_WOOD_COST):
					_wood = kind.id
			MaterialData.Kind.ORE:
				if _unusable(_ore, Balance.FORGE_ORE_COST):
					_ore = kind.id
			_:
				if _unusable(_gem, Balance.FORGE_GEM_COST):
					_gem = kind.id


## Whether what is on the anvil could still be struck.
##
## **Only what is no longer usable is re-picked.** The first cut chose all three
## on every open, so a player who deliberately set Ironbark found Bloodpine back
## on the anvil the next time they walked in.
func _unusable(id: String, needs: int) -> bool:
	return id.is_empty() or MetaState.material_count(id) < needs


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()

	var level: int = MetaState.profession_level("smith")
	var progress: Vector2 = MetaState.profession_progress("smith")
	_heading.text = "The Forge  ·  Smith %d" % level
	_note.text = ("Wood and ore decide how good a piece the forge may attempt. "
		+ "The gem decides how often it climbs a rung of rarity, and practice "
		+ "adds to that. Every piece is rolled on the same tables a found one "
		+ "is, so nothing here is a shortcut past the road - only another way "
		+ "onto it.\n"
		+ "Experience %d of %d toward the next level." % [
			int(progress.x), int(progress.y)])

	var held: Array[Dictionary] = MetaState.materials_held()
	if held.is_empty():
		_rows.add_child(_line("Nothing in the store yet. Chop a tree or break a "
			+ "seam out past the roads and bring it back."))
		_strike_button.disabled = true
		_result.text = ""
		return

	_rows.add_child(_heading_row("Wood  ·  %d needed" % Balance.FORGE_WOOD_COST))
	_add_choices(MaterialData.Kind.WOOD)
	_rows.add_child(_heading_row("Ore  ·  %d needed" % Balance.FORGE_ORE_COST))
	_add_choices(MaterialData.Kind.ORE)
	_rows.add_child(_heading_row("The gem to set  ·  1 needed"))
	_add_choices(MaterialData.Kind.GEM)

	var refused: String = Forge.refusal(_wood, _ore, _gem)
	_strike_button.disabled = not refused.is_empty()
	if refused.is_empty():
		var odds: int = int(round(Forge.rung_odds(_gem) * 100.0))
		var gem: MaterialData = ContentDB.material(_gem)
		var steps: int = mini((gem.rarity if gem != null else 0) + 1,
			Balance.FORGE_MAX_RARITY_STEPS)
		_result.text = "%d%% to climb each rung, up to %d rung%s." % [
			odds, steps, "" if steps == 1 else "s"]
	else:
		_result.text = refused


func _add_choices(kind: int) -> void:
	var any: bool = false
	for material: MaterialData in ContentDB.materials_sorted():
		if material.kind != kind:
			continue
		var held: int = MetaState.material_count(material.id)
		if held <= 0:
			continue
		any = true
		_rows.add_child(_choice_row(material, held))
	if not any:
		_rows.add_child(_line("None of this yet."))


func _choice_row(material: MaterialData, held: int) -> PanelContainer:
	var chosen: bool = _selected(material.kind) == material.id
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"InnerPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	if ResourceLoader.exists(material.get_sprite_path()):
		var art := TextureRect.new()
		art.texture = load(material.get_sprite_path()) as Texture2D
		art.custom_minimum_size = Vector2(SWATCH, SWATCH)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		FrameKit.hang(art)
		row.add_child(art)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)

	var name_label := Label.new()
	# **What it is, not only what it is called.** A player choosing between four
	# logs could read the flavour text or guess; the rarity is the thing the
	# forge actually reads, so the row says it.
	name_label.text = "%s  ·  %s  ·  %d held" % [material.display_name,
		Balance.SPIRIT_RARITY_NAMES[clampi(material.rarity, 0,
			Balance.SPIRIT_RARITY_NAMES.size() - 1)], held]
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color",
		Color("e8a33d") if chosen else Color("d8d2c4"))
	copy.add_child(name_label)

	var note := Label.new()
	note.text = material.description
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("9fa7a2"))
	copy.add_child(note)

	var pick := Button.new()
	pick.text = "On the anvil" if chosen else "Use"
	pick.disabled = chosen
	pick.custom_minimum_size = Vector2(150.0, 44.0)
	var id: String = material.id
	var which: int = material.kind
	pick.pressed.connect(func() -> void:
		_choose(which, id)
		_refresh())
	row.add_child(pick)
	return panel


func _selected(kind: int) -> String:
	match kind:
		MaterialData.Kind.WOOD:
			return _wood
		MaterialData.Kind.ORE:
			return _ore
		_:
			return _gem


func _choose(kind: int, id: String) -> void:
	match kind:
		MaterialData.Kind.WOOD:
			_wood = id
		MaterialData.Kind.ORE:
			_ore = id
		_:
			_gem = id


func _strike() -> void:
	var piece: Dictionary = Forge.forge(_wood, _ore, _gem)
	if piece.has("error"):
		_result.text = String(piece["error"])
		Sfx.play("sfx_ui_deny", -4.0)
		_refresh()
		return
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	_result.text = "The forge gives up a %s %s, level %d. It is in the stash." % [
		Stash.rarity_name(piece), kind.display_name if kind != null else "piece",
		int(piece.get("level", 1))]
	Sfx.play("sfx_ui_confirm", -2.0)
	_refresh()


func _heading_row(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("8fb9a8"))
	return label


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("9fa7a2"))
	return label


func _refit() -> void:
	if _panel == null or _scroll == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(PANEL_WIDTH,
		screen.x - Balance.UI_PANEL_MARGIN * 2.0), 0.0)
	# The forge picture is the first thing to go on a short screen. Measured
	# after it is hidden, so the list is offered the room the picture gave up
	# rather than the room it would have had either way.
	if _art != null:
		_art.visible = screen.y >= HEADER_MIN_SCREEN
		_art.custom_minimum_size = Vector2(0.0, HEADER_HEIGHT if _art.visible else 0.0)
	_scroll.custom_minimum_size = Vector2(0.0, minf(screen.y * 0.42,
		UiMetrics.scroll_room_measured(_scroll, _scroll.get_parent() as Control,
			Balance.UI_PANEL_MARGIN)))
