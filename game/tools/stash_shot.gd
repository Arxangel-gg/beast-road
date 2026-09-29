extends Node

## Photographs the stash as a paper doll, on a stocked account, on a desktop
## and on a narrow window - the picture `stash_doll_check` cannot take.
##
##   godot --path game res://tools/stash_shot.tscn
##
## Windowed, because a headless display has no pixels. The account is stocked
## for the shot and put back after it: a worn Chainbroken sword with a gem set,
## a worn Oathbound armour, a worn Fine helmet, and a shelf of unworn pieces
## across every rarity, one of them an upgrade. The first unworn row is hovered
## so the comparison card is in the frame.

const SIZE := Vector2i(1600, 900)
const NARROW := Vector2i(1000, 700)

var _screen: StashScreen = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[stash-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	var stash_before: Array = MetaState.stash.duplicate(true)
	var equipped_before: Dictionary = MetaState.equipped.duplicate()
	var materials_before: Dictionary = MetaState.materials.duplicate()
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260928)
	_stock()
	_screen = StashScreen.new()
	add_child(_screen)
	await get_tree().process_frame
	_screen.open()
	for _settle: int in 6:
		await get_tree().process_frame
	await _hover_first_unworn()
	for _settle: int in 6:
		await get_tree().process_frame
	await _save("user://stash_shot.png")
	get_window().size = NARROW
	get_viewport().set_content_scale_size(NARROW)
	await get_tree().process_frame
	_screen.call("_refit")
	for _settle: int in 6:
		await get_tree().process_frame
	await _save("user://stash_shot_narrow.png")
	_screen.hide_screen()
	MetaState.stash = stash_before
	MetaState.equipped = equipped_before
	MetaState.materials = materials_before
	Modifiers.rebuild()
	MetaState.resume_saves()
	Sfx.stop_immediately()
	await get_tree().process_frame
	get_tree().quit(0)


func _kind_in(slot: int, skip: int = 0) -> GearData:
	var seen: int = 0
	for kind: GearData in ContentDB.gear_sorted():
		if kind != null and int(kind.slot) == slot:
			if seen == skip:
				return kind
			seen += 1
	return null


func _stock() -> void:
	MetaState.stash = []
	MetaState.equipped = {}
	var names: int = Stash.RARITY_NAMES.size()
	_receive(_kind_in(GearData.Slot.WEAPON), names - 2, 4, true)
	var sword: Dictionary = MetaState.stash[MetaState.stash.size() - 1]
	for gem: MaterialData in ContentDB.materials_sorted():
		if gem.kind == MaterialData.Kind.GEM and not gem.gem_key.is_empty():
			MetaState.gain_material(gem.id, 1)
			MetaState.socket_gem(Stash.uid(sword), gem.id)
			break
	_receive(_kind_in(GearData.Slot.ARMOUR), 4, 3, true)
	_receive(_kind_in(GearData.Slot.HELMET), 2, 2, true)
	_receive(_kind_in(GearData.Slot.RING), names - 1, 5, false)
	_receive(_kind_in(GearData.Slot.WEAPON, 1), 3, 2, false)
	_receive(_kind_in(GearData.Slot.GLOVES), 1, 1, false)
	_receive(_kind_in(GearData.Slot.BOOTS), 0, 1, false)
	_receive(_kind_in(GearData.Slot.AMULET), 2, 1, false)
	_receive(_kind_in(GearData.Slot.CAPE), 3, 2, false)
	_receive(_kind_in(GearData.Slot.CHARM), 1, 1, false)
	RunState.hero_attributes = [Balance.ATTRIBUTE_THRESHOLD * 2, Balance.ATTRIBUTE_THRESHOLD, 4, 2, 0]
	Modifiers.rebuild()


func _receive(kind: GearData, rarity: int, level: int, wear: bool) -> void:
	if kind == null:
		return
	MetaState.receive_gear(Stash.make(kind.id, rarity, level))
	if wear:
		MetaState.equip(kind.slot, MetaState.stash.size() - 1)


func _hover_first_unworn() -> void:
	var list: VBoxContainer = _screen.get("_list") as VBoxContainer
	if list == null:
		return
	var at: int = 0
	for stripe: Node in list.get_children():
		if at >= MetaState.stash.size():
			break
		if not MetaState.is_equipped_index(at):
			var card: Button = _first_button(stripe)
			if card != null:
				# **A row a player can hover is a row on the screen.** This emitted
				# the hover on a row scrolled out of the lane, and the comparison
				# card - correctly - sat clamped at the screen's edge beside
				# nothing, which photographed as the card covering the list.
				var scroll: ScrollContainer = _screen.get("_scroll") as ScrollContainer
				if scroll != null:
					scroll.ensure_control_visible(card)
					await get_tree().process_frame
					await get_tree().process_frame
				card.mouse_entered.emit()
			return
		at += 1


func _first_button(from: Node) -> Button:
	var button := from as Button
	if button != null:
		return button
	for child: Node in from.get_children():
		var hit: Button = _first_button(child)
		if hit != null:
			return hit
	return null


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	frame.save_png(ProjectSettings.globalize_path(path))
	print("[stash-shot] -> %s" % ProjectSettings.globalize_path(path))
