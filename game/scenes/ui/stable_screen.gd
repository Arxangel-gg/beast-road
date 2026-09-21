class_name StableScreen
extends CanvasLayer

## **The stable**: what Halric has in the paddock, and which one is yours.
##
## Owner brief, 2026-09-17: *"the ability to get mounts from a vendor at the
## Hold with the right resources ... I want the most aesthetic solution in The
## Hold for it like a stable or something and animated horses with AI and a
## vendor at it."* The paddock and the horses are `StablePaddock`'s; this is the
## counter.
##
## **Every rule lives on `MetaState` and none of them lives here.** The price,
## the refusal, the purchase and the saddling are `buy_mount` and
## `saddle_mount`; this screen calls a door and re-reads the answer, which is
## the rule `PenScreen` follows for the same reason - a screen with its own
## opinion about a price is a second place for the price to be wrong.
##
## **Marks, and never materials.** A material is an input to the Smithy and
## nothing else (2026-09-13), and the run currencies reset - so the only honest
## price for a thing you keep between runs is the account's own, which is what
## the stash, the Ledger and Orden's commission already take. Recorded on
## `MountData.price` as well, because the argument belongs with the number.

signal closed()

const PANEL_WIDTH: float = 1000.0
const ART_SIZE: float = 92.0
const HEADER_HEIGHT: float = 120.0
const HEADER_MIN_SCREEN: float = 900.0
const STABLE_ART: String = "res://art/city/building_granary_tier_02.png"
const KEEPER_ART: String = "res://art/city/merchant_stabler.png"
## What a horse is drawn as when its own painting is not on disk yet. The same
## fallback the paddock uses, for the same reason: a missing picture must leave
## a stiller shop rather than a hole in it.
const FALLBACK_ART: String = "res://art/wildlife/wildlife_steppe_horse.png"

var _panel: PanelContainer
var _heading: Label
var _note: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _purse: Label
var _result: Label
var _close_button: Button
var _art: TextureRect = null


func _ready() -> void:
	# Every plate, button and bar on this screen gets the standing animation
	# and the hover hologram (owner, 2026-09-17). **Deferred**, because a
	# screen builds its own children further down this same function -
	# enrolled here and now it would dress an empty `Control` and nothing else.
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 92
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_refit)
	visible = false


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.03, 0.03, 0.02, 0.9)
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

	# The barn and the man in front of it. A shop header with only the building
	# in it is a picture of a door.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
	column.add_child(header)
	_art = _picture(STABLE_ART, 0.0)
	if _art != null:
		_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(_art)
	var keeper: TextureRect = _picture(KEEPER_ART, HEADER_HEIGHT)
	if keeper != null:
		header.add_child(keeper)

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

	_purse = Label.new()
	_purse.add_theme_font_size_override("font_size", 15)
	_purse.add_theme_color_override("font_color", Color("e8d9a8"))
	column.add_child(_purse)

	# One row at the bottom, for the reason the Market's is one row: a landscape
	# phone inflates a button to a thumb, and two stacked buttons pin 240 pixels
	# of a 430-tall screen before anything else gets one.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	column.add_child(bottom)

	var afoot := Button.new()
	afoot.name = "Unsaddle"
	afoot.text = "Go on foot"
	afoot.custom_minimum_size = Vector2(0.0, 44.0)
	afoot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	afoot.pressed.connect(_unsaddle)
	bottom.add_child(afoot)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.pressed.connect(hide_screen)
	bottom.add_child(_close_button)


func _picture(path: String, side: float) -> TextureRect:
	if not ResourceLoader.exists(path):
		return null
	var art := TextureRect.new()
	art.texture = load(path) as Texture2D
	art.custom_minimum_size = Vector2(side, HEADER_HEIGHT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return art


func open() -> void:
	visible = true
	_result.text = ""
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


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()

	_heading.text = "The Stable  ·  Halric keeps the horses"
	# **The bound, said to the player rather than only written in the code.** A
	# mount that reads as a combat upgrade is one the player will try to fight
	# from, and then report the swing as broken. Better the shop says it.
	_note.text = ("Something to cross ground on, and nothing else. Mounted you "
		+ "cannot swing, cast, loose, gather or fish - and the first time you "
		+ "attack you are on your feet where you stood. A gallop is no faster "
		+ "than a sprint; what it saves you is the breath.")

	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		_rows.add_child(_line("Halric has nothing in the paddock today."))
	for kind: MountData in stock:
		_rows.add_child(_stall(kind))

	_purse.text = "%d Marks" % MetaState.marks


func _stall(kind: MountData) -> Container:
	var owned: bool = MetaState.owns_mount(kind.id)
	var saddled: bool = MetaState.mount_saddled == kind.id

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var stall: Control = _paddock_window(kind, owned)
	row.add_child(stall)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(column)

	var name_line := Label.new()
	name_line.text = kind.display_name + ("  ·  saddled" if saddled else "")
	name_line.add_theme_font_size_override("font_size", 18)
	name_line.add_theme_color_override("font_color",
		Color("e8d9a8") if saddled else Color("efe9dc"))
	column.add_child(name_line)

	var what := Label.new()
	# **Percentages of a walk rather than raw multipliers**, because "1.85"
	# means nothing and "nearly twice your walk" is a thing a buyer can weigh -
	# and what a gallop costs the rider's own SP a second, because that is the
	# other half of the price (owner, 2026-09-21).
	what.text = "Walk +%d%%  ·  Gallop +%d%%  ·  %d SP a second" % [
		int(round((kind.speed - 1.0) * 100.0)),
		int(round((minf(kind.gallop, Balance.MOUNT_GALLOP_CEILING) - 1.0) * 100.0)),
		int(round(kind.sprint_drain))]
	what.add_theme_font_size_override("font_size", 14)
	what.add_theme_color_override("font_color", Color("8d968f"))
	column.add_child(what)

	if not kind.description.is_empty():
		var flavour := Label.new()
		flavour.text = kind.description
		flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavour.add_theme_font_size_override("font_size", 13)
		flavour.add_theme_color_override("font_color", Color("7d8479"))
		column.add_child(flavour)

	var act := Button.new()
	act.custom_minimum_size = Vector2(170.0, 44.0)
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not owned:
		act.text = "%d Marks" % kind.price
		# **Dimmed, silhouetted and genuinely disabled, together** (owner,
		# 2026-09-17). Three states that have to agree: a row that looks dead
		# and still answers a press is the worse failure, because a player who
		# finds one stops trusting the rest of the screen. `UiLocked` is the one
		# door, so the stable, the forge and the professions cannot drift.
		#
		# "Locked" here is *unaffordable*, not unowned: an unowned horse you can
		# pay for is the whole shop, and silhouetting that would hide the thing
		# being sold.
		var afford: bool = MetaState.marks >= kind.price
		act.pressed.connect(func() -> void: _buy(kind))
		UiLocked.set_locked(row, not afford, null, act)
	elif saddled:
		act.text = "Saddled"
		act.disabled = true
	else:
		act.text = "Saddle"
		act.pressed.connect(func() -> void: _saddle(kind))
	row.add_child(act)
	return row


## One horse in its stall, alive.
##
## Owner, 2026-09-17: *"Mounts at the vendor in the UI also need idle
## animations while they're either facing southwest or south east for easy
## viewing and max aesthetic appeal. If a mount is locked it should just be
## the silhouette, still idle animated."*
##
## **The real `MountRig`, not a second drawing of one.** The rig already
## knows which sheet a state uses, how many frames it holds, how to fall back
## when one is missing, and where the animal's feet are - four things this
## screen would otherwise have to learn and then keep in step. A picture of a
## horse that disagrees with the horse is the fault this project has paid for
## in the mount photographs already.
##
## **South-east, which is the owner's own choice and also the readable one.**
## A three-quarter view shows the barrel, the legs and the head at once,
## where a profile hides the chest and a head-on hides the gait. It faces
## *into* the row, so the animal looks toward the words describing it rather
## than out of the panel.
##
## **A `Control` with a `Node2D` in it rather than a `SubViewport`.** Five
## viewports on one screen is five render targets to hold a horse each; a
## canvas item parented to a Control draws in the Control's own canvas for
## nothing. The rig is scaled to the stall rather than the stall to the rig,
## because a Beastcalled draught horse and a marsh pony are painted at
## different heights and a shelf where the rows are different sizes reads as
## broken rather than as varied.
func _paddock_window(kind: MountData, owned: bool) -> Control:
	var stall := Control.new()
	stall.custom_minimum_size = Vector2(ART_SIZE * 1.6, ART_SIZE)
	stall.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stall.clip_contents = true

	var rig := MountRig.new()
	stall.add_child(rig)

	# **Dressed once it is in a tree, never before.** `_ready` is what builds the
	# rig's own sprite, and a node added to a `Control` that is not itself in the
	# tree yet has not had one - `show_mount` then assigns `region_enabled` on a
	# null sprite, which is what `menu_layout_check` caught here four times over.
	# The stall is returned to a caller that adds it, so everything about the
	# animal waits for the frame after that.
	stall.resized.connect(_seat_rig.bind(stall, rig, kind))
	_dress_rig.call_deferred(stall, rig, kind, owned)
	return stall


## Shows the animal, points it, starts it, and locks it if it is not yours.
##
## Deferred out of `_paddock_window` for the reason written there: none of this
## can happen until the rig has had `_ready`.
func _dress_rig(stall: Control, rig: MountRig, kind: MountData,
		_owned: bool) -> void:
	if rig == null or not is_instance_valid(rig) or not rig.is_inside_tree():
		return
	rig.show_mount(kind)
	# Mounts normally sit behind their rider; shop previews must clear the panel.
	rig.z_index = 1
	# South-east: x right, y down. The rig reads a heading rather than an index,
	# so this is the same call the field makes and no table of directions is
	# kept in two places.
	rig.set_facing(Vector2(1.0, 1.0).normalized())
	rig.play("idle")
	# Its own pace, so a shelf of five is five animals rather than one drawn
	# five times - the rule the paddock and the pen are both built under.
	rig.set_speed_scale(randf_range(0.82, 1.18))
	# Buyers need to see the animal; ownership is shown by the purchase button.
	UiLocked.silhouette(rig.body(), false)
	_seat_rig(stall, rig, kind)


## Puts the animal on the floor of its stall at a size that fits it.
func _seat_rig(stall: Control, rig: MountRig, kind: MountData) -> void:
	if stall == null or not is_instance_valid(stall) \
			or rig == null or not is_instance_valid(rig):
		return
	var room: Vector2 = stall.size
	if room.x <= 1.0 or room.y <= 1.0:
		return
	# The cell is the rig's own, so a repack of the sheets moves this too.
	var drawn: float = float(MountRig.CELL_H) * maxf(kind.art_scale, 0.01)
	var fit: float = clampf(room.y / maxf(drawn, 1.0), 0.05, 1.0)
	rig.scale = Vector2(fit, fit)
	# Feet near the bottom of the stall rather than the middle: the rig draws
	# from the ground up, which is what lets a tall horse and a pony share a
	# floor instead of sharing a centre line.
	rig.position = Vector2(room.x * 0.5, room.y * 0.94)


func _buy(kind: MountData) -> void:
	if MetaState.buy_mount(kind.id):
		UiSound.confirm()
		_result.text = "Halric leads the %s out and hands you the reins." \
			% kind.display_name
	else:
		UiSound.deny()
		_result.text = "Not enough Marks for that one."
	_refresh()


func _saddle(kind: MountData) -> void:
	if MetaState.saddle_mount(kind.id):
		UiSound.confirm()
		_result.text = "%s is saddled and waiting at the rail." % kind.display_name
	else:
		UiSound.deny()
	_refresh()


## Off everything. The mount key then says "No mount saddled", which is the one
## thing a player who wants to walk is entitled to.
func _unsaddle() -> void:
	if MetaState.saddle_mount(""):
		UiSound.confirm()
		_result.text = "Halric takes the saddle back. You will be walking."
	_refresh()


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("b8ae98"))
	return label


## Sized against the screen, and the picture is the first thing to give up -
## `menu_layout_check` failed the Forge's first cut at phone sizes with "no way
## out at all", and its header was a third of why.
func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(PANEL_WIDTH, screen.x * 0.94), 0.0)
	var room: bool = screen.y >= HEADER_MIN_SCREEN
	if _art != null:
		_art.get_parent().visible = room
	_scroll.custom_minimum_size = Vector2(0.0, minf(screen.y * 0.42,
		UiMetrics.scroll_room_measured(_scroll, _scroll.get_parent() as Control,
			Balance.UI_PANEL_MARGIN)))
	_panel.reset_size()
