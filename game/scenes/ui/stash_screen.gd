class_name StashScreen
extends CanvasLayer

## The stash and the blacksmith, on one screen.
##
## One screen rather than two, because they are one decision. "Is this sword
## better than mine" and "should I break it for shards to upgrade the one I have"
## are the same question asked from either end, and putting a wall between them
## makes a player walk back and forth to answer it.
##
## Reached from the main menu, not from a run: gear persists and a run does not
## pause for shopping.

signal closed()

const SLOT_NAMES: Array[String] = ["Weapon", "Armour", "Charm"]
const ATTRIBUTE_NAMES: Array[String] = ["Might", "Vigour", "Swiftness", "Focus"]

var _panel: PanelContainer
var _list: VBoxContainer
var _header: Label
var _note: Label
var _tools: HBoxContainer
var _scroll: ScrollContainer

## Which slot the list is filtered to, or -1 for all. A stash of ninety-six is
## not a list you read; it is one you search.
var _filter: int = -1

## The last thing a bulk action had to say. Kept in a field rather than written
## straight to the label, because `_refresh` rewrites that label - the same trap
## that made every error message in the town sheet invisible.
var _message: String = ""


func _ready() -> void:
	layer = 64
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.88)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(940.0, 0.0)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 22)
	_header.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_header)

	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_note)

	# Bulk work, above the list rather than in it.
	#
	# **Added with the drop-rate rise** (owner direction, 2026-09-01: "the game
	# needs way more loot"). Four times the drops means four times the sorting,
	# and a farming loop where clearing the chaff costs one press per piece is a
	# farming loop nobody runs twice. These never touch what is worn.
	_tools = HBoxContainer.new()
	_tools.add_theme_constant_override("separation", 6)
	column.add_child(_tools)

	# The list scrolls and the close button does not. A full stash is forty rows,
	# and a screen whose only way out is below forty rows is the results screen
	# bug again.
	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_scroll = scroll
	_refit()

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(0.0, 44.0)
	close.pressed.connect(func() -> void: hide_screen())
	column.add_child(close)


func open() -> void:
	visible = true
	_refit()
	_refresh()


func hide_screen() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


func _refit() -> void:
	if _panel == null or _scroll == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(940.0,
		screen.x - Balance.UI_PANEL_MARGIN * 2.0), 0.0)
	# Reserved: heading, note, the tool row, the Close button and the frame's own
	# padding. A fixed 520 was taller than a landscape phone once the rest was
	# added, and a `CenterContainer` overflows equally in both directions - so the
	# way out went off the top of the screen. The same fault the leaderboard had.
	_scroll.custom_minimum_size = Vector2(0.0, UiMetrics.scroll_room(_scroll, 300.0))


## The list, best first within each slot.
##
## Sorted rather than in the order things were picked up, because the question a
## stash is opened to answer is "is any of this better than what I am wearing",
## and the answer to that is at the top of a sorted list and somewhere in the
## middle of an unsorted one. Returns indices into `MetaState.stash`, not copies:
## every action here removes by index.
func _sorted_indices() -> Array[int]:
	var order: Array[int] = []
	for index: int in MetaState.stash.size():
		var piece: Dictionary = MetaState.stash[index]
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if _filter >= 0 and (kind == null or int(kind.slot) != _filter):
			continue
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool:
		var one: Dictionary = MetaState.stash[a]
		var two: Dictionary = MetaState.stash[b]
		var kind_one: GearData = ContentDB.gear(String(one.get("kind", "")))
		var kind_two: GearData = ContentDB.gear(String(two.get("kind", "")))
		var slot_one: int = int(kind_one.slot) if kind_one != null else 9
		var slot_two: int = int(kind_two.slot) if kind_two != null else 9
		if slot_one != slot_two:
			return slot_one < slot_two
		return Stash.points(one, kind_one) > Stash.points(two, kind_two))
	return order


## Everything unworn at or below `rarity`, broken for shards in one press.
##
## Descending, which is not a style choice: `MetaState.drop_gear` removes by
## index and every later index shifts down, so ascending would break the wrong
## pieces from the second one onward. Equipped gear is skipped outright rather
## than filtered afterwards - a bulk action that can strip the hero is a bulk
## action nobody presses.
func _break_all(rarity: int) -> int:
	var worn: Array[int] = []
	for slot: Variant in MetaState.equipped:
		worn.append(int(MetaState.equipped[slot]))
	# Held across the sweep. `drop_gear` writes the save on every removal, so
	# breaking sixty pieces was sixty full serialisations of the whole account
	# - and sixty chances for a crash to land mid-write.
	MetaState.hold_saves()
	var broken: int = 0
	var gained: int = 0
	for index: int in range(MetaState.stash.size() - 1, -1, -1):
		if worn.has(index):
			continue
		var piece: Dictionary = MetaState.stash[index]
		if int(piece.get("rarity", 0)) > rarity or int(piece.get("level", 1)) > 1:
			continue
		gained += Stash.salvage_yield(piece)
		MetaState.drop_gear(index)
		broken += 1
	MetaState.resume_saves()
	MetaState.shards += gained
	if broken > 0:
		MetaState.save_game()
		Sfx.play("sfx_relic_socket")
	return broken


func _build_tools() -> void:
	for child: Node in _tools.get_children():
		_tools.remove_child(child)
		child.queue_free()

	var names: Array[String] = ["All", "Weapon", "Armour", "Charm"]
	for which: int in names.size():
		var index: int = which - 1
		var tab := Button.new()
		tab.text = names[which]
		tab.toggle_mode = true
		tab.button_pressed = _filter == index
		tab.custom_minimum_size = Vector2(0.0, 36.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 13)
		tab.pressed.connect(func() -> void:
			_filter = index
			_refresh())
		_tools.add_child(tab)

	# Two thresholds rather than one "break everything": the first is chaff a
	# player will never wear, the second is what a mid-run stash fills with. Both
	# stop below Fine, because breaking a Fine piece is a decision.
	for rarity: int in 2:
		var sweep := Button.new()
		sweep.text = "Break all %s" % Stash.RARITY_NAMES[rarity]
		sweep.tooltip_text = ("Breaks every unworn, un-upgraded %s piece for shards. "
			+ "Never touches what you are wearing.") % Stash.RARITY_NAMES[rarity]
		sweep.custom_minimum_size = Vector2(0.0, 36.0)
		sweep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sweep.add_theme_font_size_override("font_size", 13)
		var threshold: int = rarity
		sweep.pressed.connect(func() -> void:
			var broken: int = _break_all(threshold)
			_message = "Broke %d piece%s for shards." % [broken,
				"" if broken == 1 else "s"]
			_refresh())
		_tools.add_child(sweep)


func _refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_build_tools()
	_header.text = "Stash  ·  %d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]
	var worn: Array[int] = MetaState.gear_attribute_points()
	var parts: PackedStringArray = []
	for index: int in ATTRIBUTE_NAMES.size():
		if worn[index] > 0:
			parts.append("+%d %s" % [worn[index], ATTRIBUTE_NAMES[index]])
	_note.text = "%d of %d held%s  ·  full-stash drops auto-break into Shards" % [
		MetaState.stash.size(), Balance.STASH_CAPACITY,
		"  ·  worn: " + ", ".join(parts) if not parts.is_empty() else ""]
	if not _message.is_empty():
		_note.text += "   ·   " + _message
		_message = ""

	if MetaState.stash.is_empty():
		var empty := Label.new()
		empty.text = "Nothing yet. Gear can fall on the battlefield or come out of raid chests."
		empty.add_theme_color_override("font_color", Color("8f9b98"))
		_list.add_child(empty)
		return

	for index: int in _sorted_indices():
		_list.add_child(_row(index))


## Big enough that a 128px icon still reads at a glance, small enough that a
## full stash does not turn into a gallery.
const ICON_SIZE: float = 44.0


func _row(index: int) -> Container:
	var piece: Dictionary = MetaState.stash[index]
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var is_worn: bool = int(MetaState.equipped.get(kind.slot if kind else -1, -1)) == index

	# **The icon, which this list never had.** Every gear kind has authored art at
	# `icons/ui/ui_<id>.png` - the same file the blade in the hero's hand is drawn
	# from - and the stash showed none of it, so a screen full of loot read as a
	# spreadsheet. Tinted by rarity so the tier is legible before the text is.
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if kind != null:
		var art: String = kind.get_sprite_path()
		if ResourceLoader.exists(art):
			icon.texture = load(art) as Texture2D
		icon.modulate = Stash.rarity_colour(piece).lerp(Color.WHITE, 0.45)
		icon.tooltip_text = kind.description
	row.add_child(icon)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	if kind == null:
		label.text = "Unknown"
	else:
		label.text = "%s %s  ·  %s  ·  Lv%d  ·  +%d %s%s" % [
			Stash.rarity_name(piece), kind.display_name, kind.slot_name(),
			int(piece.get("level", 1)), Stash.points(piece, kind),
			ATTRIBUTE_NAMES[clampi(kind.attribute, 0, ATTRIBUTE_NAMES.size() - 1)],
			"   ◆ worn" if is_worn else ""]
		label.tooltip_text = kind.description
		label.add_theme_color_override("font_color",
			Stash.rarity_colour(piece).lerp(Color("e8e2d4"), 0.35))
	row.add_child(label)

	# The four actions in a box of their own, fixed width, each filling a
	# quarter of it. Sized individually they were four different widths per row
	# - "Sell 120" is wider than "Sell 12" - so every row started its buttons at
	# a different x and a list of ninety-six read as ragged.
	# **Stacked on a phone, side by side on a desktop.**
	#
	# The four actions share the row with the name on a wide screen, which is
	# how a stash should read. On a phone the same layout gave each button 126
	# units, of which 68 is the frame's own padding - so "Equip" rendered as
	# "EQU" and "Break 11" as "BRE". A second line is the only thing that
	# actually buys the width back.
	var stacked: bool = TouchInput.is_showing()
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	if stacked:
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		actions.custom_minimum_size.x = ACTION_WIDTH * 4.0
	var outer: Container = row
	if stacked:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.add_child(row)
		column.add_child(actions)
		outer = column
	else:
		row.add_child(actions)

	var equip := Button.new()
	equip.text = "Remove" if is_worn else "Equip"
	_size_action(equip)
	equip.disabled = kind == null
	equip.pressed.connect(func() -> void:
		if is_worn:
			MetaState.equipped.erase(kind.slot)
		else:
			MetaState.equipped[kind.slot] = index
		MetaState.save_game()
		EventBus.stash_changed.emit()
		_refresh())
	actions.add_child(equip)

	var cost: Dictionary = Stash.upgrade_cost(piece)
	var upgrade := Button.new()
	if cost.is_empty():
		upgrade.text = "Max"
		upgrade.disabled = true
	else:
		upgrade.text = "%d◇ %d✦" % [int(cost["shards"]), int(cost["marks"])]
		upgrade.tooltip_text = "Upgrade to level %d: %d shards and %d marks." % [
			int(piece.get("level", 1)) + 1, int(cost["shards"]), int(cost["marks"])]
		upgrade.disabled = MetaState.shards < int(cost["shards"]) \
			or MetaState.marks < int(cost["marks"])
		upgrade.pressed.connect(func() -> void:
			MetaState.shards -= int(cost["shards"])
			MetaState.marks -= int(cost["marks"])
			piece["level"] = int(piece.get("level", 1)) + 1
			MetaState.save_game()
			EventBus.stash_changed.emit()
			Sfx.play("sfx_tower_upgrade")
			_refresh())
	_size_action(upgrade)
	actions.add_child(upgrade)

	var sell := Button.new()
	sell.text = "Sell %d✦" % Stash.sell_price(piece)
	_size_action(sell)
	sell.pressed.connect(func() -> void:
		MetaState.marks += Stash.sell_price(piece)
		MetaState.drop_gear(index)
		Sfx.play("sfx_tower_sell")
		_refresh())
	actions.add_child(sell)

	var salvage := Button.new()
	salvage.text = "Break %d◇" % Stash.salvage_yield(piece)
	salvage.tooltip_text = "Breaks it for shards. Shards only buy upgrades."
	_size_action(salvage)
	salvage.pressed.connect(func() -> void:
		MetaState.shards += Stash.salvage_yield(piece)
		MetaState.drop_gear(index)
		Sfx.play("sfx_relic_socket")
		_refresh())
	actions.add_child(salvage)
	return outer


## One width and one height for all four row actions.
##
## They carried four different widths and four different labels, so every row
## began its buttons at a different x and the list read as ragged. Equal boxes
## line the column up whatever the numbers say.
##
## Marked `SELF_SIZED` with a dense target, the same way the in-run build sheet
## is: the generic 120-unit thumb floor is right for an isolated control and
## wrong for a list of ninety-six, where it leaves three rows visible on a phone.
## `ACTION_HEIGHT` is comfortably above the 44-48 both platform guidelines ask
## for, and `layout_check` reads the same meta rather than a copy of it.
const ACTION_WIDTH: float = 132.0
const ACTION_HEIGHT: float = 40.0
## Horizontal frame padding for a row action, against the theme's 34. See
## `_size_action` for why these four are the exception.
const ACTION_PAD_X: float = 12.0


func _size_action(button: Button) -> void:
	# The touch height is the build sheet's dense target, not the generic thumb
	# floor. `SELF_SIZED` stops UiMetrics resizing the box but it still grows the
	# *font* to `UI_TOUCH_MIN_FONT_SIZE`, so a 40-unit box would have 26px type
	# and 28 units of frame padding to fit into and would simply overflow.
	var height: float = Balance.UI_TOUCH_BUILD_TARGET_HEIGHT \
		if TouchInput.is_showing() else ACTION_HEIGHT
	button.custom_minimum_size = Vector2(0.0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clipped rather than allowed to widen: the box is the layout, and a long
	# number must not be able to push its neighbours out of line.
	button.clip_text = true
	# And the frame is narrowed for these four specifically. The theme pads a
	# button by 34 units each side to clear the corner bolts on `ui_button`,
	# which is right for a menu and leaves a 132-unit action button 64 units of
	# room - so "Sell 120" rendered as "Sell 12" and "Break 11" as "Break".
	# These sit in a dense column where the bolts are not the point.
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBox = button.get_theme_stylebox(state, "Button")
		if box == null:
			continue
		var tight: StyleBox = box.duplicate() as StyleBox
		tight.content_margin_left = ACTION_PAD_X
		tight.content_margin_right = ACTION_PAD_X
		button.add_theme_stylebox_override(state, tight)
	button.set_meta(UiMetrics.SELF_SIZED, true)
	button.set_meta(UiMetrics.TOUCH_TARGET_HEIGHT, height)
