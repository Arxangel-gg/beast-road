extends Node

## **The front door lets the painting through and is never quite still**
## (owner, 2026-10-07). Stands the real main menu up and holds that every door
## in its column is see-through and wears a glow; that the glow breathes embers
## at rest, bursts and brightens under the pointer and the pad's focus, flashes
## on a press, keeps to its cap, gives its embers up at a particle scale of
## nothing, dresses a door added later, and puts itself out on a door that has
## left the column - the Hold's adopted doors are the Hold's.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	var packed: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu: Control = packed.instantiate() as Control
	add_child(menu)
	for _i: int in 4:
		await get_tree().process_frame
	var column: Control = menu.call("front_column") as Control
	_check(column != null, "the menu has no column of front doors")
	if column == null:
		_finish()
		return
	var doors: Array[Button] = []
	for child: Node in column.get_children():
		if child is Button and (child as Button).visible:
			doors.append(child as Button)
	_check(doors.size() >= 3, "only %d front doors stand in the column" % doors.size())
	for door: Button in doors:
		_test_a_door_is_dressed(door)
	if not doors.is_empty():
		_test_the_glow_answers(doors[0])
	await _test_a_door_added_later(column)
	await _test_a_door_that_leaves(column, doors)
	_test_the_hold_is_the_holds(menu, column)
	_finish()


func _test_a_door_is_dressed(door: Button) -> void:
	var see: float = float(door.get_meta(&"ui_see_through", 1.0))
	_check(absf(see - Balance.MENU_BUTTON_ALPHA) < 0.001,
		"%s is not see-through (%.2f)" % [door.name, see])
	var plate := door.get_theme_stylebox("normal") as StyleBoxTexture
	if plate != null:
		_check(plate.modulate_color.a < 0.99,
			"%s's plate is still whole (%.2f)" % [door.name, plate.modulate_color.a])
	var fx: MenuButtonFx = MenuButtonFx.of(door)
	_check(fx != null, "%s wears no glow" % door.name)
	if fx != null:
		_check(fx.lit(), "%s's glow is out on the front door" % door.name)
		_check(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s's glow takes the press" % door.name)
		var additive := fx.material as CanvasItemMaterial
		_check(additive != null and additive.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"%s's glow is not additive - it could hide a word" % door.name)


func _test_the_glow_answers(door: Button) -> void:
	var fx: MenuButtonFx = MenuButtonFx.of(door)
	if fx == null:
		return
	# At rest: embers, and no hover. The menu hands its first door the pad's
	# focus, which reads as under the player, so that is given up first.
	door.release_focus()
	var seen: int = 0
	for _i: int in 300:
		fx.advance(1.0 / 30.0)
		seen = maxi(seen, fx.motes_aloft())
	_check(seen >= 1, "a door at rest raised no ember in ten seconds")
	_check(fx.hover_share() < 0.01, "a door at rest reads as hovered")
	# Under the pointer: a burst, and the hover eases in.
	var before: int = fx.motes_aloft()
	door.mouse_entered.emit()
	_check(fx.motes_aloft() >= before + mini(Balance.MENU_BUTTON_FX_BURST,
			Balance.MENU_BUTTON_FX_MAX - before) - 1,
		"a hover burst %d embers, wanted about %d" % [fx.motes_aloft() - before, Balance.MENU_BUTTON_FX_BURST])
	for _i: int in 15:
		fx.advance(1.0 / 30.0)
	_check(fx.hover_share() > 0.95, "a hovered door eased in to %.2f" % fx.hover_share())
	# A long hover keeps to the cap.
	var most: int = 0
	for _i: int in 600:
		fx.advance(1.0 / 30.0)
		most = maxi(most, fx.motes_aloft())
	_check(most <= Balance.MENU_BUTTON_FX_MAX, "%d embers aloft against a cap of %d"
		% [most, Balance.MENU_BUTTON_FX_MAX])
	_check(most > seen, "a hovered door burns no brighter than one at rest (%d against %d)" % [most, seen])
	# A press flashes, and the flash passes.
	door.button_down.emit()
	_check(fx.flash_share() > 0.99, "a press did not flash")
	for _i: int in int(ceil(Balance.MENU_BUTTON_FX_FLASH * 30.0)) + 2:
		fx.advance(1.0 / 30.0)
	_check(fx.flash_share() <= 0.0, "a press's flash outlived itself")
	# Leaving puts the hover out - the pointer and the focus both.
	door.release_focus()
	door.mouse_exited.emit()
	for _i: int in 15:
		fx.advance(1.0 / 30.0)
	_check(fx.hover_share() < 0.05, "a door left alone stayed lit at %.2f" % fx.hover_share())
	# The pad's focus is a hover too.
	door.focus_entered.emit()
	for _i: int in 15:
		fx.advance(1.0 / 30.0)
	_check(fx.hover_share() > 0.95, "the pad's focus did not light the door")
	door.focus_exited.emit()


func _test_a_door_added_later(column: Control) -> void:
	var held: Dictionary = Graphics.to_dictionary()
	Graphics.set_switch(Graphics.KEY_PARTICLES, 0.0)
	var late := Button.new()
	late.name = "LateDoor"
	late.text = "Resume"
	column.add_child(late)
	for _i: int in 3:
		await get_tree().process_frame
	var fx: MenuButtonFx = MenuButtonFx.of(late)
	_check(fx != null, "a door added after the menu stood wears no glow")
	_check(absf(float(late.get_meta(&"ui_see_through", 1.0)) - Balance.MENU_BUTTON_ALPHA) < 0.001,
		"a door added after the menu stood is not see-through")
	if fx != null:
		late.mouse_entered.emit()
		for _i: int in 300:
			fx.advance(1.0 / 30.0)
		_check(fx.motes_aloft() == 0, "%d embers rose at a particle scale of nothing" % fx.motes_aloft())
	Graphics.from_dictionary(held)
	late.queue_free()
	await get_tree().process_frame


func _test_a_door_that_leaves(column: Control, doors: Array[Button]) -> void:
	if doors.size() < 2:
		return
	var door: Button = doors[doors.size() - 1]
	var fx: MenuButtonFx = MenuButtonFx.of(door)
	if fx == null:
		return
	door.mouse_entered.emit()
	fx.advance(0.1)
	var elsewhere := Control.new()
	add_child(elsewhere)
	door.reparent(elsewhere)
	fx.advance(0.1)
	_check(not fx.lit(), "a door that left the column is still lit")
	_check(not fx.visible and fx.motes_aloft() == 0, "a door that left the column still draws embers")
	door.reparent(column)
	fx.advance(0.1)
	_check(fx.lit(), "a door put back in the column did not light again")


func _test_the_hold_is_the_holds(menu: Node, column: Control) -> void:
	var stack: Array[Node] = [menu]
	var outside: int = 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children(true):
			stack.append(child)
		var fx := node as MenuButtonFx
		if fx == null:
			continue
		var button := fx.get_parent() as Button
		if button != null and not column.is_ancestor_of(button):
			outside += 1
			fx.advance(0.1)
			_check(not fx.lit(), "%s glows in the Hold" % button.name)
	print("[menu_fx] %d glows on doors the Hold adopted, all out" % outside)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("menu_button_fx_check: " + message)


func _finish() -> void:
	if _failures == 0:
		print("menu_button_fx_check: PASS (%d checks)" % _checks)
	else:
		print("menu_button_fx_check: FAIL (%d of %d)" % [_failures, _checks])
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _child: Node in get_children():
		_child.queue_free()
	for _i: int in 30:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)
