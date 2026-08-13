class_name CrossroadScreen
extends CanvasLayer

## The choice at a segment boundary (GDD §8). Combat is frozen behind this.
##
## Three option types exist and two are shown, so the choice is real every time
## and the icon language stays small enough to learn.

signal road_chosen(option_id: String)

@export var panel: Control
@export var title: Label
@export var options_box: VBoxContainer

## Width of an option card. Wide enough that no description wraps to three lines,
## which is what makes three cards different heights and the column look broken.
const CARD_WIDTH: float = 620.0

## Matches the theme's button text inset, so a description lines up under the
## name it belongs to instead of starting somewhere near it.
const TEXT_INDENT: int = 34

const OPTIONS: Array[Dictionary] = [
	{"id": "terrain", "name": "The known road", "icon": "distance",
	 "text": "Familiar ground. The same breed you have been fighting."},
	{"id": "risk", "name": "The hard road", "icon": "wave",
	 "text": "Heavier waves, and they stay heavier. A relic waits at the end of it."},
	{"id": "resource", "name": "The long road", "icon": "resource",
	 "text": "Quieter, and it pays. Resources, and time to build."},
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	panel.visible = false


func open(segment_index: int) -> void:
	for child: Node in options_box.get_children():
		child.queue_free()

	title.text = "Crossroad  ·  segment %d of %d" % [
		segment_index, int(Balance.JOURNEY_TOTAL_DISTANCE / Balance.SEGMENT_DISTANCE)]

	var pool: Array[Dictionary] = OPTIONS.duplicate()
	pool.shuffle()
	for i: int in mini(Balance.CROSSROAD_OPTIONS_SHOWN, pool.size()):
		_add_option(pool[i])

	panel.visible = true


## One road, as a framed card.
##
## The description used to be a bare Label sitting directly on the key art with
## no padding and no plate behind it — pale text over a photographic background
## of rocks and sunlight, which is unreadable roughly half the time depending on
## what the art happens to be doing behind that line. Putting each option on its
## own dark plate fixes the contrast and the padding in one move.
func _add_option(option: Dictionary) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InnerPanel"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var button := Button.new()
	button.text = String(option.get("name", "?"))
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	IconKit.on_button(button, String(option.get("icon", "distance")), 26)
	button.pressed.connect(func() -> void: _choose(String(option.get("id", ""))))
	box.add_child(button)

	var text := Label.new()
	text.text = String(option.get("text", ""))
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color("bcc9c4"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Indented to the button's own text inset, so the description reads as
	# belonging to the road above it rather than as a separate loose line.
	text.custom_minimum_size = Vector2(0.0, 0.0)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", TEXT_INDENT)
	indent.add_theme_constant_override("margin_right", 8)
	indent.add_theme_constant_override("margin_bottom", 4)
	indent.add_child(text)
	box.add_child(indent)

	options_box.add_child(card)


## Applies the road's effect, then hands control back to the run.
func _choose(option_id: String) -> void:
	match option_id:
		"resource":
			RunState.gain_resources(180)
		"risk":
			var ids: Array = ContentDB.relics.keys()
			if not ids.is_empty():
				RunState.held_relics.append(String(ids[_rng.randi_range(0, ids.size() - 1)]))
			RunState.war_horn_uses += 1  # the hard road is permanently harder
		_:
			pass
	panel.visible = false
	road_chosen.emit(option_id)
