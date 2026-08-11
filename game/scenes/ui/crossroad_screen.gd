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

const OPTIONS: Array[Dictionary] = [
	{"id": "terrain", "name": "The known road",
	 "text": "Familiar ground. The same breed you have been fighting."},
	{"id": "risk", "name": "The hard road",
	 "text": "Heavier waves. A relic waits at the end of it."},
	{"id": "resource", "name": "The long road",
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


func _add_option(option: Dictionary) -> void:
	var box := VBoxContainer.new()
	var button := Button.new()
	button.text = String(option.get("name", "?"))
	button.custom_minimum_size = Vector2(560, 56)
	button.pressed.connect(func() -> void: _choose(String(option.get("id", ""))))
	box.add_child(button)

	var text := Label.new()
	text.text = String(option.get("text", ""))
	text.add_theme_font_size_override("font_size", 15)
	box.add_child(text)
	options_box.add_child(box)


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
