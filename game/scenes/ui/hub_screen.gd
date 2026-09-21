class_name HubScreen
extends CanvasLayer
## The Hold: the standing hub (owner ruling, 2026-09-11), and a **place** you
## walk in rather than a column of buttons (owner ruling, 2026-09-17).
##
## `IDEAS_REVIEW` §4 refused a hub as "the grammar of a map you hold, and this
## map walks", and that reading still stands for the *world* - the town rides
## the beast and nothing standing still may compete with it. A yard between
## runs is not a place on the road, so the refusal does not reach it.
##
## **It owns no screen.** The menu builds the stash, the Ledger, the co-op
## screen and the rest exactly as before and hands their buttons to this room
## with `adopt`. A button here is the same button it was on the front door -
## same handler, same focus return - so nothing that worked stops working,
## and the front door gets to be a front door.
##
## **And now every one of those buttons is also a building.** `HoldYard` stands
## one where each door is and presses that same button when the Warden walks up
## to it, so the place and the list can never disagree about what is in the
## Hold: they are the same buttons, read twice.
##
## **The list did not go away, and that is deliberate.** Walking is the Hold;
## it is not a toll. The Warden's card carries every door as a row, so a player
## on a phone, on a pad, or simply in a hurry reaches the stash in one press -
## and `menu_layout_check` still holds that the way out is on screen at every
## shape, which the first draft of this screen failed with the Close button
## fourteen hundred pixels above the top of it.

signal closed()

const PANEL_MAX_WIDTH: float = 1100.0
const PANEL_SCREEN_SHARE: float = 0.94
const BODY_SCREEN_SHARE: float = 0.52
const BODY_SCREEN_SHARE_PORTRAIT: float = 0.66
const PORTRAIT_SIZE: float = 128.0
## The Warden's own idle sheet - the current art, not the old reference
## (owner report, 2026-09-12). The south row, cycled.
const PORTRAIT_SHEET: String = "res://art/hero/hero_idle.png"
const PORTRAIT_ROW: int = 2
const PORTRAIT_FPS: float = 8.0
const RANK_TINTS: Array[Color] = [Color.WHITE, Color(1.0, 0.94, 0.8), Color(1.0, 0.86, 0.6)]

## How much of the screen the yard is allowed to fill. The rest is the strip
## the prompt and the way out live on.
const YARD_SHARE: Vector2 = Vector2(0.98, 0.80)

var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: BoxContainer
var _card: VBoxContainer
var _grid: GridContainer
var _close_button: Button
var _first_button: Button = null
var _portrait: TextureRect = null
var _portrait_frames: int = 1
## True while a door from this room is open over it. The room hides so the
## door's screen is on top, and comes back when the door closes.
var _suspended: bool = false
var _rename_edit: LineEdit = null

var _yard: HoldYard = null

## How far in the Warden has pulled the view, over the fit. See
## `Balance.HOLD_ZOOM_MIN`.
##
## **Two numbers, because a zoom is a move rather than a setting.** `_zoom` is
## where the slider says to be and `_zoom_now` is where the view has got to;
## the gap is closed in `_process` at the same rate the battlefield's camera
## settles at, so the two places this game zooms feel like one game.
var _zoom: float = Balance.HOLD_ZOOM_DEFAULT
var _zoom_now: float = Balance.HOLD_ZOOM_DEFAULT
var _zoom_slider: HSlider = null
var _session: HoldSession = null
## The card and every door as a list, over the yard. Hidden until asked for.
var _card_root: Control = null
var _prompt: Label = null
var _note: Label = null
var _doors_button: Button = null
var _public_button: Button = null
var _bar: GridContainer = null
var _note_left: float = 0.0
## The road out: the chooser the host presses, and the timed answer a guest is
## given when somebody else presses it.
var _road_panel: PanelContainer = null
var _road_rows: VBoxContainer = null
var _answer_left: float = 0.0
var _answer_line: Label = null


func _ready() -> void:
	# Every plate, button and bar on this screen gets the standing animation
	# and the hover hologram (owner, 2026-09-17). **Deferred**, because a
	# screen builds its own children further down this same function -
	# enrolled here and now it would dress an empty `Control` and nothing else.
	UiJuice.enrol.call_deferred(get_tree(), self)
	layer = 90
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


func _build() -> void:
	var back := ColorRect.new()
	back.name = "Backdrop"
	back.color = Color(0.04, 0.05, 0.05, 1.0)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_yard = HoldYard.new()
	add_child(_yard)
	_yard.entered.connect(_on_entered)
	_yard.walked.connect(_on_walked)

	_session = HoldSession.new()
	_session.yard = _yard
	add_child(_session)
	_session.note.connect(_say)
	_session.seats_changed.connect(_refresh_bar)

	_build_frame()
	_build_panel()
	_refit()


## The strip over the yard: what the Hold is, what is in reach, and the handful
## of things that are about the Hold itself rather than about a building in it.
func _build_frame() -> void:
	var frame := Control.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	# **A column rather than a row**, because five buttons and a title do not
	# fit across a 430-wide phone - and what falls off the right-hand end of
	# that row is Close, which is the one thing `menu_layout_check` exists to
	# keep on screen. The grid wraps instead; `_refit` decides how far.
	var top := VBoxContainer.new()
	top.name = "Top"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22.0
	top.offset_right = -22.0
	top.offset_top = 16.0
	top.add_theme_constant_override("separation", 8)
	frame.add_child(top)

	var title := Label.new()
	title.text = "THE HOLD"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e8a33d"))
	top.add_child(title)

	_bar = GridContainer.new()
	_bar.name = "Bar"
	_bar.columns = 5
	_bar.add_theme_constant_override("h_separation", 8)
	_bar.add_theme_constant_override("v_separation", 8)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_bar)

	_doors_button = _strip_button("The Warden", _show_card)
	_public_button = _strip_button("Doors", _toggle_public)
	_strip_button("Invite", _invite)
	_strip_button("Find a Hold", _find)
	_close_button = _strip_button("Close", close)

	_note = Label.new()
	_note.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_note.offset_top = 58.0
	_note.offset_left = 22.0
	_note.offset_right = -22.0
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", Color("9fd2b4"))
	frame.add_child(_note)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -66.0
	_prompt.offset_bottom = -18.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color("f2e6d0"))
	_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	frame.add_child(_prompt)

	# The zoom, in the bottom-left corner: the prompt owns the middle of that
	# band and the Warden's own furniture the right of it.
	var zoom_corner := MarginContainer.new()
	zoom_corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	zoom_corner.offset_left = 22.0
	zoom_corner.offset_top = -58.0
	zoom_corner.offset_right = 282.0
	zoom_corner.offset_bottom = -18.0
	frame.add_child(zoom_corner)
	_build_zoom(zoom_corner)

	_build_road_panel(frame)
	EventBus.party_run_offered.connect(_on_road_offered)


func _strip_button(text: String, on: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(on)
	_bar.add_child(button)
	return button


func _build_panel() -> void:
	_card_root = Control.new()
	_card_root.name = "Card"
	_card_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_root.visible = false
	add_child(_card_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.03, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_root.add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Hold"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	var title := Label.new()
	title.text = "THE WARDEN"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(title)

	var note := Label.new()
	note.text = ("Every door in the Hold, and what the Warden has become. Walk to a "
		+ "building to use it, or take the row here.")
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

	var back := Button.new()
	back.text = "Back to the yard"
	back.custom_minimum_size = Vector2(0.0, 44.0)
	back.pressed.connect(_hide_card)
	column.add_child(back)


## A door from the front door, moved into the room. The button keeps its
## handler and its focus return; only its parent changes - and the room steps
## aside when it is pressed, so the screen it opens is on top rather than
## underneath (owner report, 2026-09-12).
##
## It is also **bound to its building**, by the button's own name, so a door
## added to the menu tomorrow is a door in the yard tomorrow.
func adopt(button: Button) -> void:
	if button == null:
		return
	var parent: Node = button.get_parent()
	if parent != null:
		parent.remove_child(button)
	button.custom_minimum_size = Vector2(0.0, 60.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(suspend)
	_grid.add_child(button)
	if _yard != null:
		_yard.bind(button.name, button)
	if _first_button == null:
		_first_button = button


## Hides the room for a door, remembering to come back.
func suspend() -> void:
	if not visible:
		return
	_suspended = true
	visible = false
	if _yard != null:
		_yard.set_driving(false)


func is_suspended() -> bool:
	return _suspended


func _process(delta: float) -> void:
	# The view eases onto the zoom the slider asks for. Exponential rather than
	# linear, so it moves fastest when it is furthest away and settles without
	# a stop - and it costs a `_refit` only while it is actually moving.
	if not is_equal_approx(_zoom_now, _zoom):
		var ease: float = 1.0 - exp(-Balance.CAMERA_ZOOM_LERP_SPEED * delta)
		_zoom_now = lerpf(_zoom_now, _zoom, ease)
		if absf(_zoom_now - _zoom) < 0.002:
			_zoom_now = _zoom
	# **The view follows the Warden every frame, not only while the zoom is
	# moving.** Smoothing the zoom moved the only `_refit` call into the branch
	# above, so once it settled the camera stopped following - the Hold looked
	# locked to the map instead of to the player, which is what the owner
	# reported. Following is a handful of assignments; it belongs outside.
	_refit()
	if not visible:
		return
	_tick_prompt()
	if _note_left > 0.0:
		_note_left -= delta
		if _note_left <= 0.0 and _note != null:
			_note.text = ""
	if _answer_left > 0.0:
		_answer_left -= delta
		if _answer_line != null and is_instance_valid(_answer_line):
			_answer_line.text = "%d seconds to answer" % int(ceil(_answer_left))
		if _answer_left <= 0.0:
			_hide_road()
	if _portrait == null or _portrait_frames <= 1 or not _card_root.visible:
		return
	var atlas := _portrait.texture as AtlasTexture
	if atlas == null:
		return
	var frame: int = int(Time.get_ticks_msec() * 0.001 * PORTRAIT_FPS) % _portrait_frames
	atlas.region.position.x = float(frame * HeroAnimator.CELL_W)


func _tick_prompt() -> void:
	if _prompt == null or _yard == null:
		return
	if _card_root != null and _card_root.visible:
		_prompt.text = ""
		return
	var label: String = _yard.focus_label()
	if label.is_empty():
		_prompt.text = ("Tap where you want to stand" if TouchInput.is_showing()
			else "Walk with the movement keys")
		_prompt.modulate = Color(1.0, 1.0, 1.0, 0.45)
		return
	_prompt.modulate = Color.WHITE
	_prompt.text = "%s   -   %s" % [label,
		"tap again to enter" if TouchInput.is_showing() else "press Interact"]


func open() -> void:
	_suspended = false
	_build_card()
	visible = true
	if _yard != null:
		_yard.set_driving(true)
	if _session != null:
		_session.open()
		_session.introduce()
	_refresh_bar()
	_refit()
	_refit.call_deferred()
	if _card_root != null and _card_root.visible:
		if _first_button != null and is_instance_valid(_first_button):
			_first_button.grab_focus()
	else:
		_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	if _yard != null:
		_yard.set_driving(false)
	if _session != null:
		_session.close()
	closed.emit()


func _show_card() -> void:
	if _card_root == null:
		return
	_build_card()
	_card_root.visible = true
	if _yard != null:
		_yard.set_driving(false)
	if _first_button != null and is_instance_valid(_first_button):
		_first_button.grab_focus()
	_refit()


func _hide_card() -> void:
	if _card_root == null:
		return
	_card_root.visible = false
	if _yard != null:
		_yard.set_driving(true)
	_close_button.grab_focus()


# ---------------------------------------------------------------- the session


func _refresh_bar() -> void:
	if _public_button == null:
		return
	var open_doors: bool = HoldSession.is_public()
	_public_button.text = "Doors: open" if open_doors else "Doors: closed"
	if _session != null and _session.occupied() > 1:
		_public_button.text += "  (%d here)" % _session.occupied()


func _toggle_public() -> void:
	if _session == null:
		return
	_session.set_public(not HoldSession.is_public())
	_refresh_bar()


func _invite() -> void:
	if _session == null:
		return
	var code: String = _session.invite()
	if not code.is_empty():
		DisplayServer.clipboard_set(code)


func _find() -> void:
	if _session != null:
		_session.find()


func _say(line: String) -> void:
	if _note == null:
		return
	_note.text = line
	_note_left = 6.0


func _on_walked(at: Vector2, facing: Vector2) -> void:
	if _session != null:
		_session.report(at, facing)


## A station the Warden walked up to. Most of them press their own button and
## this only makes the sound; the ones with **no** button are the ones this
## screen answers itself - the Warden's stone is the card, which is where the
## rename and the professions live.
## **The wheel and the pad move the same number the slider does.**
##
## One door for all three, so the slider can never say one thing while the view
## shows another - the failure `HUD._refresh_zoom_slider` was written to avoid,
## in the one other place this game has a zoom.
func set_zoom(level: float) -> void:
	var was: float = _zoom
	_zoom = clampf(level, Balance.HOLD_ZOOM_MIN, Balance.HOLD_ZOOM_MAX)
	if is_equal_approx(was, _zoom):
		return
	if _zoom_slider != null and not is_equal_approx(_zoom_slider.value, _zoom):
		_zoom_slider.set_value_no_signal(_zoom)


## The wheel, in the one `_unhandled_input` this screen has: a second copy of a
## Godot callback is silently the only one that runs, and this file already owns
## the cancel key and the interact press.
func _wheel_zoom(event: InputEvent) -> bool:
	if _yard == null:
		return false
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return false
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		set_zoom(_zoom + Balance.HOLD_ZOOM_STEP)
		return true
	if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		set_zoom(_zoom - Balance.HOLD_ZOOM_STEP)
		return true
	return false


## The slider, and the two buttons a thumb uses instead of a wheel.
##
## Vertical would match the HUD's, and this one is horizontal on purpose: the
## Hold's own furniture runs along the bottom of the screen and a column here
## would stand in the middle of the yard.
func _build_zoom(into: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	into.add_child(row)

	var out := Button.new()
	out.text = "-"
	out.focus_mode = Control.FOCUS_NONE
	out.custom_minimum_size = Vector2(34.0, 0.0)
	out.pressed.connect(func() -> void:
		set_zoom(_zoom - Balance.HOLD_ZOOM_STEP))
	row.add_child(out)

	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = Balance.HOLD_ZOOM_MIN
	_zoom_slider.max_value = Balance.HOLD_ZOOM_MAX
	_zoom_slider.step = 0.01
	_zoom_slider.value = _zoom
	_zoom_slider.custom_minimum_size = Vector2(150.0, 0.0)
	_zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zoom_slider.tooltip_text = "How close the Hold is drawn"
	_zoom_slider.value_changed.connect(func(level: float) -> void:
		set_zoom(level))
	row.add_child(_zoom_slider)

	var closer := Button.new()
	closer.text = "+"
	closer.focus_mode = Control.FOCUS_NONE
	closer.custom_minimum_size = Vector2(34.0, 0.0)
	closer.pressed.connect(func() -> void:
		set_zoom(_zoom + Balance.HOLD_ZOOM_STEP))
	row.add_child(closer)


func _on_entered(station: String) -> void:
	UiSound.confirm()
	if station == "card":
		_show_card()
	elif station == "road":
		_show_road()
	elif station == "pond":
		_fish_the_pond()


## **One cast at the Hold's pond.**
##
## Owner, 2026-09-17: *"players can also only fish for up to 3 fish every 10
## minutes at their Hold's pond."*
##
## Deliberately not the road's fishing. `Fishing` is a cast, a wait, a hook and
## a reel held in a band, and all of that is built on the tension of standing
## still on a battlefield while a wave walks past - a hub has none of that, so
## the same minigame here would be the skill without the risk. What the Hold's
## pond is instead is a *small standing supply*: walk over, take what it has,
## come back later.
##
## **The cap is the whole of it.** `FISH_MEALS_PER_RUN` is the one thing between
## a deep larder and a Warden who cannot be killed, and an uncapped pond in the
## one place nothing is hunting you is the way round it. Three, then the pond is
## quiet for ten minutes, written to the save so quitting to the menu does not
## reset the window.
func _fish_the_pond() -> void:
	if MetaState.hold_pond_left() <= 0:
		var wait: float = MetaState.hold_pond_wait()
		_note.text = "The pond is quiet. Try again in about %d minutes." \
			% maxi(int(ceil(wait / 60.0)), 1)
		return
	var caught: FishData = _pond_catch()
	if caught == null:
		_note.text = "Nothing is rising."
		return
	# **The larder is asked before the pond is charged.** A full pantry that
	# still spent one of the three would be a cast the player paid for and did
	# not get, which is the shape of bug nobody reports and everybody feels.
	if MetaState.fish_total() >= Balance.FISH_STASH_CAPACITY:
		_note.text = "The larder is full."
		return
	if not MetaState.hold_pond_take():
		return
	MetaState.take_fish(caught.id)
	var left: int = MetaState.hold_pond_left()
	_note.text = "%s. %s" % [caught.display_name,
		("The pond has %d left." % left) if left > 0
			else "That is the pond emptied for now."]
	UiSound.confirm()


## What is in the Hold's pond.
##
## The common end of the same roster the road fishes, weighted by `roll_weight`
## exactly as a pond on the battlefield is - so the Hold is a *quiet* pond
## rather than a second table of fish that could drift from the first. Nothing
## rare rises here: what makes the rare fish worth having is the road.
func _pond_catch() -> FishData:
	var pool: Array[FishData] = []
	var weight: float = 0.0
	for kind: FishData in ContentDB.fish_sorted():
		if int(kind.rarity) > Balance.HOLD_POND_RARITY_CEILING:
			continue
		pool.append(kind)
		weight += maxf(kind.roll_weight, 0.01)
	if pool.is_empty():
		return null
	var roll: float = randf() * weight
	for kind: FishData in pool:
		roll -= maxf(kind.roll_weight, 0.01)
		if roll <= 0.0:
			return kind
	return pool[pool.size() - 1]


# ---------------------------------------------------------------- the card


## The Warden's card: who they are on this account, read fresh on every open
## so a run just finished shows.
func _build_card() -> void:
	for child: Node in _card.get_children():
		_card.remove_child(child)
		child.queue_free()

	var portrait := TextureRect.new()
	_portrait = portrait
	_portrait_frames = 1
	if ResourceLoader.exists(PORTRAIT_SHEET):
		var sheet: Texture2D = load(PORTRAIT_SHEET)
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(0.0, float(PORTRAIT_ROW * HeroAnimator.CELL_H),
			float(HeroAnimator.CELL_W), float(HeroAnimator.CELL_H))
		portrait.texture = atlas
		_portrait_frames = maxi(int(sheet.get_width() / HeroAnimator.CELL_W), 1)
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	# The rank is a warmth on the same Warden rather than a different picture.
	portrait.modulate = RANK_TINTS[clampi(MetaState.ascension, 0, RANK_TINTS.size() - 1)]
	# And the dye is the same Warden in different cloth (2026-09-21).
	WardenLook.dress(portrait, WardenLook.mine())
	_card.add_child(portrait)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	_card.add_child(name_row)
	var name_line := Label.new()
	name_line.text = MetaState.player_name if not MetaState.player_name.is_empty() else "Oathless"
	name_line.add_theme_font_size_override("font_size", 22)
	name_line.add_theme_color_override("font_color", Color("f2e6d0"))
	name_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_line)
	var rename := Button.new()
	rename.text = "Rename"
	rename.custom_minimum_size = Vector2(0.0, 32.0)
	rename.pressed.connect(_toggle_rename)
	name_row.add_child(rename)
	_rename_edit = LineEdit.new()
	_rename_edit.placeholder_text = "A name for the Warden"
	_rename_edit.max_length = Balance.SCORE_NAME_MAX
	_rename_edit.text = MetaState.player_name
	_rename_edit.visible = false
	_rename_edit.text_submitted.connect(func(text: String) -> void:
		MetaState.rename_player(text)
		_build_card())
	_card.add_child(_rename_edit)

	# **The look** (owner, 2026-09-21: character customization, bounded to how
	# the Warden looks and nothing else). Two dyes, previewed on the portrait
	# above as the slider moves, saved through `MetaState.set_look` so the
	# clamp lives in one place.
	_card.add_child(_look_row("Cloak", WardenLook.KEY_CLOAK))
	_card.add_child(_look_row("Sash", WardenLook.KEY_SASH))

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


func _look_row(text: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(56.0, 0.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("8d968f"))
	row.add_child(label)
	var slider := HSlider.new()
	slider.name = "Look%s" % key.capitalize()
	slider.min_value = -WardenLook.RANGE
	slider.max_value = WardenLook.RANGE
	slider.step = 0.02
	slider.value = float(WardenLook.mine().get(key, 0.0))
	slider.custom_minimum_size = Vector2(180.0, 24.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		MetaState.set_look(key, v)
		if _portrait != null:
			WardenLook.dress(_portrait, WardenLook.mine()))
	row.add_child(slider)
	return row


func _toggle_rename() -> void:
	if _rename_edit == null:
		return
	_rename_edit.visible = not _rename_edit.visible
	if _rename_edit.visible:
		_rename_edit.text = MetaState.player_name
		_rename_edit.grab_focus()
		_rename_edit.select_all()


func _line(text: String, colour: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(label)


## **The mark each craft is known by**, resolved through `IconKit` off gear the
## game already has art for.
##
## The Farmer is deliberately absent rather than approximated: there is no crop
## or seed in the icon set, and a root-ware charm standing in for farming would
## read as a mistake rather than as a mark. A craft with no entry simply shows
## none, and the row lays out the same either way.
const CRAFT_MARKS: Dictionary = {
	"angler": "reckoners_rod",
	"woodcutter": "oathbreakers_axe",
	"miner": "iron_ore",
	"smith": "stonewarden_hammer",
}

## How big a craft's mark is drawn, and how tall its bar is inside its frame.
## How big a craft's mark is drawn.
##
## **Forty-four rather than twenty-two** (owner, 2026-09-17: *"the icons need
## to be larger and each profession should have appropriate room"*). At 22 the
## mark was smaller than the words beside it, which makes it punctuation; at
## 44 it is the thing the eye lands on and the name confirms it.
const CRAFT_MARK: int = 44
## A rung's own pip inside an opened card. Smaller than the craft's mark, so
## the card still reads as one thing with a list under it.
const CRAFT_RUNG: int = 20
const CRAFT_BAR: float = 10.0


## One craft, as a card that can be opened.
##
## Owner, 2026-09-17: *"Professions should show a current/max level info
## detail for each so that players know what their current level is for each
## out of the maximum level cap"*, and *"the ability to expand it to show more
## details about what the player has unlocked for that profession and see
## locked disabled dim entries for what's still locked."*
##
## **What a craft opens is derived, never authored here.** The ladder comes
## from the gather nodes that craft actually works, and the level each rung
## wants is asked of `Balance.gather_level_for` - the same function the road
## asks when it decides whether to dig one. So the card cannot promise a seam
## the field then refuses, which is the shape of fault this project has paid
## for in the Ledger's prices and in a discipline node no seed could offer. A
## craft with no nodes shows no ladder rather than an invented one.
func _profession_row(id: String) -> void:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)

	# **The name line carries the mark**, so the eye finds the craft before it
	# reads the words - five identical rows of text is a spreadsheet.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var mark: Texture2D = IconKit.sized(String(CRAFT_MARKS.get(id, "")), CRAFT_MARK) \
		if CRAFT_MARKS.has(id) else null
	if mark != null:
		var badge := TextureRect.new()
		badge.texture = mark
		badge.custom_minimum_size = Vector2(CRAFT_MARK, CRAFT_MARK)
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(badge)

	var level: int = MetaState.profession_level(id)
	var progress: Vector2 = MetaState.profession_progress(id)
	var label := Label.new()
	# **Out of the cap, which is the half that was missing.** "level 3" says
	# nothing about whether that is early or nearly done; "3 / 20" says both.
	label.text = "%s  \u00b7  level %d / %d" % [id.capitalize(), level,
		Balance.PROFESSION_MAX_LEVEL]
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("c9c2b4"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(label)

	var ladder: Array[Dictionary] = _craft_ladder(id, level)
	var more: Button = null
	if not ladder.is_empty():
		more = Button.new()
		more.toggle_mode = true
		more.text = "\u25be"
		more.focus_mode = Control.FOCUS_NONE
		more.custom_minimum_size = Vector2(38.0, 0.0)
		more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		more.tooltip_text = "What this craft has opened, and what it has not."
		head.add_child(more)
	card.add_child(head)

	# **The bar sits in a recess rather than on the card.** A bare bar on a flat
	# panel has no edge of its own, so an empty one is invisible and a full one
	# reads as a stripe of paint. A frame gives it both ends.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _bar_recess())
	var pad := MarginContainer.new()
	for edge: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(edge, 2)
	frame.add_child(pad)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, CRAFT_BAR)
	bar.max_value = maxf(progress.y, 1.0)
	bar.value = progress.x
	bar.show_percentage = false
	pad.add_child(bar)
	card.add_child(frame)

	var count := Label.new()
	count.text = ("%d / %d to the next" % [int(progress.x), int(progress.y)]) \
		if level < Balance.PROFESSION_MAX_LEVEL else "mastered"
	count.add_theme_font_size_override("font_size", 12)
	count.add_theme_color_override("font_color", Color("8d968f"))
	card.add_child(count)

	if more != null:
		var detail: VBoxContainer = _craft_detail(ladder)
		detail.visible = false
		card.add_child(detail)
		more.toggled.connect(func(on: bool) -> void:
			detail.visible = on
			more.text = "\u25b4" if on else "\u25be")
	_card.add_child(card)


## What this craft opens, rung by rung, and which rungs are still shut.
##
## Read off the gather nodes the craft actually works, grouped by rarity, and
## asked of the same function the road asks - so the two cannot drift.
func _craft_ladder(id: String, level: int) -> Array[Dictionary]:
	var wanted: Dictionary = {}
	for node: GatherNodeData in ContentDB.gather_nodes_sorted():
		if node.craft != id:
			continue
		var rarity: int = clampi(node.rarity, 0,
			Balance.GATHER_LEVEL_SHARE_BY_RARITY.size() - 1)
		var at: int = Balance.gather_level_for(rarity, node.min_level)
		# The *easiest* example of each rarity, because that is the rung: a
		# player wants to know when Rare seams open, not when the hardest
		# particular one does.
		if not wanted.has(rarity) or at < int(wanted[rarity]):
			wanted[rarity] = at
	var rungs: Array[Dictionary] = []
	var bands: Array = wanted.keys()
	bands.sort()
	for rarity: int in bands:
		rungs.append({
			"rarity": rarity,
			"at": int(wanted[rarity]),
			"open": level >= int(wanted[rarity]),
		})
	return rungs


## The opened card: one line a rung, the shut ones dimmed and silhouetted.
func _craft_detail(ladder: Array[Dictionary]) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	for rung: Dictionary in ladder:
		var rarity: int = int(rung["rarity"])
		var open_now: bool = bool(rung["open"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)

		var pip := TextureRect.new()
		pip.custom_minimum_size = Vector2(CRAFT_RUNG, CRAFT_RUNG)
		pip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pip.texture = IconKit.sized("iron_ore", CRAFT_RUNG)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(pip)

		var words := Label.new()
		words.text = "%s seams  \u00b7  %s" % [
			Balance.SPIRIT_RARITY_NAMES[clampi(rarity, 0,
				Balance.SPIRIT_RARITY_NAMES.size() - 1)],
			"open" if open_now else ("level %d" % int(rung["at"]))]
		words.add_theme_font_size_override("font_size", 13)
		words.add_theme_color_override("font_color",
			Color("c9c2b4") if open_now else Color("7d8479"))
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)

		# The one door for "you have not got this yet": dimmed, silhouetted and,
		# where there is a button, genuinely disabled. See `UiLocked`.
		UiLocked.set_locked(line, not open_now, pip, null)
		list.add_child(line)
	return list


## The recess a craft's bar sits in: dark, with a lit edge on the side the light
## is coming from, so it reads as cut into the card rather than laid on it.
func _bar_recess() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.07, 0.92)
	box.border_color = Color(0.30, 0.34, 0.33, 0.85)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	return box


## Sized against the screen, like the codex: the panel takes most of the
## width, the scrolling body a share of the height, and on a screen held
## upright the card sits above the doors rather than beside them.
##
## The yard is fitted rather than scrolled: the whole Hold is visible at once
## on every shape, which is what a lobby is for.
func _refit() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if _yard != null:
		var room: Vector2 = screen * YARD_SHARE
		var fit: float = minf(room.x / HoldYard.YARD.x, room.y / HoldYard.YARD.y)
		fit *= _zoom_now
		_yard.scale = Vector2.ONE * fit
		var middle := Vector2(screen.x * 0.5, screen.y * 0.5 + screen.y * 0.03)
		# **Pulled in, the view follows the Warden.** A zoom that kept the
		# yard centred would magnify whatever happens to be in the middle of
		# the map, which is not where anybody is standing.
		#
		# Clamped so the edge of the yard never pulls inside the room it is
		# drawn in: the valley continues past the map, but the *place* should
		# not slide off the panel.
		var away: Vector2 = -_yard.warden_at() * fit
		var slack := Vector2(
			maxf(HoldYard.YARD.x * fit * 0.5 - room.x * 0.5, 0.0),
			maxf(HoldYard.YARD.y * fit * 0.5 - room.y * 0.5, 0.0))
		_yard.position = middle + Vector2(
			clampf(away.x, -slack.x, slack.x),
			clampf(away.y, -slack.y, slack.y))
	# **The bar wraps rather than shrinking**, which is the answer this
	# project reached once already for the scope column: shrinking produced
	# targets under the size a thumb needs, and that trades one layout fault
	# for a worse one.
	if _bar != null:
		_bar.columns = 5 if screen.x >= 900.0 else (3 if screen.x >= 620.0 else 2)
	if _road_panel != null:
		var road: Control = _road_rows
		if road != null:
			road.custom_minimum_size = Vector2(minf(520.0, screen.x * 0.9), 0.0)
	if _panel == null:
		return
	var portrait: bool = screen.y > screen.x
	var width: float = minf(PANEL_MAX_WIDTH, screen.x * PANEL_SCREEN_SHARE)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	var share: float = BODY_SCREEN_SHARE_PORTRAIT if portrait else BODY_SCREEN_SHARE
	_scroll.custom_minimum_size = Vector2(0.0, maxf(240.0, screen.y * share))
	_body.vertical = portrait
	_grid.columns = 1 if portrait else 2
	_card.custom_minimum_size = Vector2(0.0, 0.0) if portrait else Vector2(300.0, 0.0)
	_panel.reset_size()


## Where a screen point lands in the yard. The yard is scaled rather than
## scrolled, so this is one divide - and it is the only place the two
## coordinate systems meet.
func _yard_point(at: Vector2) -> Vector2:
	if _yard == null or _yard.scale.x <= 0.0:
		return Vector2.ZERO
	return (at - _yard.position) / _yard.scale.x


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _wheel_zoom(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		if _card_root != null and _card_root.visible:
			_hide_card()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if _card_root != null and _card_root.visible:
		return
	if event.is_action_pressed(&"interact"):
		if _yard != null:
			_yard.use_focus()
		get_viewport().set_input_as_handled()
		return
	# A tap walks there; a tap on something already in reach opens it, which is
	# the only way a thumb can both cross a yard and use a door in it.
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _yard == null:
		return
	var at: Vector2 = _yard_point(click.position)
	var within: bool = _yard.warden_at().distance_to(at) <= Balance.HOLD_REACH
	if within and not _yard.focus().is_empty():
		_yard.use_focus()
	else:
		_yard.walk_toward(at)
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------- the road out
#
# Owner brief, 2026-09-17: a party is formed in the Hold and taken out from
# it, or a Warden goes alone; and when the host takes a party onto a road the
# rest are told what kind of road it is and given a clock to answer in.
#
# **Three roads, and they are the three the front door already offers**, which
# is deliberate: the Hold is a second way to the same doors rather than a
# second set of rules. Continuing is offered only when there is a front to
# continue, and an act start only when the account has reached one.


func _build_road_panel(frame: Control) -> void:
	_road_panel = PanelContainer.new()
	_road_panel.name = "Road"
	_road_panel.set_anchors_preset(Control.PRESET_CENTER)
	_road_panel.visible = false
	frame.add_child(_road_panel)

	_road_rows = VBoxContainer.new()
	_road_rows.add_theme_constant_override("separation", 8)
	_road_rows.custom_minimum_size = Vector2(520.0, 0.0)
	_road_panel.add_child(_road_rows)


## The host's own press: what kind of road, and who is coming.
func _show_road() -> void:
	if _road_panel == null:
		return
	_clear_road()
	_answer_left = 0.0
	_road_line("THE ROAD OUT", 20, Color("e8a33d"))
	if Coop.is_guest():
		_road_line("The Hold's host takes the road. You will be asked.", 15,
			Color("b8ae98"))
		_road_button("Close", _hide_road)
		_road_panel.visible = true
		return
	if MetaState.has_expedition():
		var front: Dictionary = MetaState.expedition
		_road_button("Continue  ·  %s" % Expedition.describe(front),
			func() -> void: _take_the_road(HoldSession.Road.CONTINUE,
				int(front.get("act", 1)), Expedition.describe(front)))
	var furthest: int = ActStart.furthest_act()
	if furthest > 1:
		_road_button("Start at Act %d" % furthest,
			func() -> void: _take_the_road(HoldSession.Road.ACT_START, furthest,
				"a fresh road opening at Act %d" % furthest))
	_road_button("Take the Road  ·  a new expedition",
		func() -> void: _take_the_road(HoldSession.Road.FRESH, 1,
			"a new expedition from Act I"))
	_road_button("Close", _hide_road)
	_road_panel.visible = true


## **Alone, it simply goes. With a party, it asks first.**
##
## The host owns the run - that has not changed - but a road is the one
## decision in this game that costs everybody the next hour, and a continued
## run is somebody else's banked front. So the party is told which kind of road
## it is and given a clock, exactly as a raid or a rift is put to them.
func _take_the_road(kind: int, act: int, detail: String) -> void:
	if _session != null and _session.offer_run(kind, act, detail):
		_clear_road()
		_road_line("Asking the party...", 17, Color("e8a33d"))
		_road_line(detail, 15, Color("b8ae98"))
		_answer_left = Balance.PARTY_ROAD_ANSWER_SECONDS
		_answer_line = _road_line("", 14, Color("9fd2b4"))
		_road_button("Go now", func() -> void: _begin_road(kind, act))
		return
	_begin_road(kind, act)


func _begin_road(kind: int, act: int) -> void:
	_hide_road()
	close()
	match kind:
		HoldSession.Road.CONTINUE:
			GameDirector.start_run(0, true)
		HoldSession.Road.ACT_START:
			GameDirector.start_run(0, false, act, "")
		_:
			GameDirector.start_run()


## A guest being asked. The clock is the host's and is shown rather than kept:
## a prompt with no visible end reads as a prompt that is waiting for you
## rather than one that is about to answer itself.
func _on_road_offered(kind: int, _act: int, detail: String, seconds: float) -> void:
	if _road_panel == null or Coop.is_host():
		return
	if not visible:
		open()
	_clear_road()
	_road_line("THE HOST IS TAKING THE ROAD", 18, Color("e8a33d"))
	_road_line(_road_words(kind), 16, Color("f2e6d0"))
	_road_line(detail, 15, Color("b8ae98"))
	_answer_left = seconds
	_answer_line = _road_line("", 14, Color("9fd2b4"))
	_road_button("Come along", func() -> void:
		if _session != null:
			_session.reply(true)
		_hide_road())
	_road_button("Stay in the Hold", func() -> void:
		if _session != null:
			_session.reply(false)
		_hide_road())
	_road_panel.visible = true


func _road_words(kind: int) -> String:
	match kind:
		HoldSession.Road.CONTINUE:
			return "A run they had already begun, picked up where they left it."
		HoldSession.Road.ACT_START:
			return "A fresh road opening further along than Act I."
		_:
			return "A new expedition, from the beginning."


func _clear_road() -> void:
	_answer_line = null
	for child: Node in _road_rows.get_children():
		_road_rows.remove_child(child)
		child.queue_free()


func _hide_road() -> void:
	_answer_left = 0.0
	_answer_line = null
	if _road_panel != null:
		_road_panel.visible = false


func _road_line(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_road_rows.add_child(label)
	return label


func _road_button(text: String, on: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.pressed.connect(on)
	_road_rows.add_child(button)
