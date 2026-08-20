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

	# The list scrolls and the close button does not. A full stash is forty rows,
	# and a screen whose only way out is below forty rows is the results screen
	# bug again.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, 520.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

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
	_refresh()


func hide_screen() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_screen()


func _refresh() -> void:
	for child: Node in _list.get_children():
		child.queue_free()

	_header.text = "Stash  ·  %d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]
	var worn: Array[int] = MetaState.gear_attribute_points()
	var parts: PackedStringArray = []
	for index: int in ATTRIBUTE_NAMES.size():
		if worn[index] > 0:
			parts.append("+%d %s" % [worn[index], ATTRIBUTE_NAMES[index]])
	_note.text = "%d of %d held%s" % [MetaState.stash.size(), Balance.STASH_CAPACITY,
		"  ·  worn: " + ", ".join(parts) if not parts.is_empty() else ""]

	if MetaState.stash.is_empty():
		var empty := Label.new()
		empty.text = "Nothing yet. Gear comes out of raid chests."
		empty.add_theme_color_override("font_color", Color("8f9b98"))
		_list.add_child(empty)
		return

	for index: int in MetaState.stash.size():
		_list.add_child(_row(index))


func _row(index: int) -> HBoxContainer:
	var piece: Dictionary = MetaState.stash[index]
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var is_worn: bool = int(MetaState.equipped.get(kind.slot if kind else -1, -1)) == index

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
	row.add_child(label)

	var equip := Button.new()
	equip.text = "Remove" if is_worn else "Equip"
	equip.custom_minimum_size = Vector2(96.0, 34.0)
	equip.disabled = kind == null
	equip.pressed.connect(func() -> void:
		if is_worn:
			MetaState.equipped.erase(kind.slot)
		else:
			MetaState.equipped[kind.slot] = index
		MetaState.save_game()
		EventBus.stash_changed.emit()
		_refresh())
	row.add_child(equip)

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
	upgrade.custom_minimum_size = Vector2(112.0, 34.0)
	row.add_child(upgrade)

	var sell := Button.new()
	sell.text = "Sell %d✦" % Stash.sell_price(piece)
	sell.custom_minimum_size = Vector2(104.0, 34.0)
	sell.pressed.connect(func() -> void:
		MetaState.marks += Stash.sell_price(piece)
		MetaState.drop_gear(index)
		Sfx.play("sfx_tower_sell")
		_refresh())
	row.add_child(sell)

	var salvage := Button.new()
	salvage.text = "Break %d◇" % Stash.salvage_yield(piece)
	salvage.tooltip_text = "Breaks it for shards. Shards only buy upgrades."
	salvage.custom_minimum_size = Vector2(104.0, 34.0)
	salvage.pressed.connect(func() -> void:
		MetaState.shards += Stash.salvage_yield(piece)
		MetaState.drop_gear(index)
		Sfx.play("sfx_relic_socket")
		_refresh())
	row.add_child(salvage)
	return row
