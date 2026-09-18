class_name SaleConfirm
extends Control

## **Nothing is sold, broken or dismantled without being asked first.**
##
## Owner, 2026-09-18: *"Anything that is being sold needs an additional
## confirmation to confirm what is being sold and what the player is giving up
## and what they're getting in exchange and allow the players to cancel the
## action to sell as well, including towers and items etc."*
##
## ## Why one panel rather than a line in each screen
##
## There are three doors that destroy something a player owns - selling a piece
## for Marks, breaking one for Shards, and dismantling a tower - and they live in
## two different screens written months apart. A confirmation written at each is
## three chances to word the trade differently and two chances to forget one,
## which is the failure this project has now paid for at four call sites of the
## interact button, five of a spell scale, and eight of a reach. **One panel, one
## sentence, three callers.**
##
## ## It states both halves, because that is the whole point
##
## "Are you sure?" is not a confirmation; it is a speed bump. What a player needs
## is *what leaves* and *what arrives*, in the same breath, before they decide -
## so `ask` takes both and draws them as a trade rather than as a warning. The
## thing being given up is named in full, with its rarity colour, because a stash
## of a hundred and sixty pieces is exactly where the wrong row gets clicked.
##
## ## Cancelling is the default
##
## Cancel takes the focus when the panel opens and Escape closes it, so every way
## of dismissing this without reading it results in **nothing happening**. A
## confirmation whose default is the destructive answer is worse than none at
## all, because it teaches the player to press through it.

## What the player chose. `true` only ever means they pressed Confirm.
signal decided(confirmed: bool)

const DIM: Color = Color(0.02, 0.02, 0.03, 0.72)

var _panel: PanelContainer = null
var _cancel: Button = null


## Opens the panel over `host`, asks the question, and emits `decided`.
##
## `title` is what is about to happen ("Sell this piece"), `giving` is what
## leaves and `getting` is what arrives. `tint` colours the line that names what
## is being given up - a piece's rarity, a tower's element - so the row a player
## is about to destroy is recognisable at a glance.
static func ask(host: Node, title: String, giving: String, getting: String,
		tint: Color = Color.WHITE) -> SaleConfirm:
	var panel := SaleConfirm.new()
	panel._build(title, giving, getting, tint)
	host.add_child(panel)
	return panel


func _build(title: String, giving: String, getting: String,
		tint: Color) -> void:
	name = "SaleConfirm"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# **Above everything, and it eats the pointer.** A modal that let a click
	# through would let the player press the row underneath it, which is the
	# action they are being asked about.
	z_index = Balance.UI_CONFIRM_Z
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = DIM
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(Balance.UI_CONFIRM_WIDTH, 0.0)
	_panel.add_theme_stylebox_override("panel", _plate())
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)

	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Balance.UI_CONFIRM_HEADING)
	column.add_child(heading)

	# **Both halves, in the order they happen.** What leaves, then what arrives.
	column.add_child(_trade_line("You give up", giving, tint))
	column.add_child(_trade_line("You receive", getting,
		Balance.UI_CONFIRM_GAIN))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)

	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.custom_minimum_size = Vector2(0.0, Balance.UI_CONFIRM_BUTTON_HEIGHT)
	_cancel.pressed.connect(_answer.bind(false))
	buttons.add_child(_cancel)

	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm.custom_minimum_size = Vector2(0.0, Balance.UI_CONFIRM_BUTTON_HEIGHT)
	confirm.add_theme_color_override("font_color", Balance.UI_CONFIRM_HEADING)
	confirm.pressed.connect(_answer.bind(true))
	buttons.add_child(confirm)


## The plate the question is printed on. Dark, warm-edged, and shadowed off
## the dimmed screen behind it so it reads as being in front rather than on.
func _plate() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.055, 0.062, 0.068, 0.98)
	box.border_color = Balance.UI_CONFIRM_HEADING
	box.set_border_width_all(2)
	box.set_corner_radius_all(9)
	box.set_content_margin_all(Balance.UI_CONFIRM_PADDING)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 10
	return box


## One row of the trade: a quiet caption and the thing itself.
func _trade_line(caption: String, what: String, tint: Color) -> Container:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Balance.UI_CONFIRM_CAPTION)
	row.add_child(label)

	var value := Label.new()
	value.text = what
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_font_size_override("font_size", 17)
	value.add_theme_color_override("font_color", tint)
	row.add_child(value)
	return row


func _ready() -> void:
	# **Cancel holds the focus.** Every way of dismissing this without reading it
	# has to end in nothing happening; a panel whose default answer destroys
	# something teaches the player to press through it.
	if _cancel != null:
		_cancel.grab_focus()
	Sfx.play("sfx_ui_confirm", -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)


func _answer(confirmed: bool) -> void:
	decided.emit(confirmed)
	queue_free()
