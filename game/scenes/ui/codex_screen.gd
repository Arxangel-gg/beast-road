class_name CodexScreen
extends CanvasLayer

## What the road has shown you (owner decision, 2026-08-31).
##
## **A view over content that already exists.** `ContentDB` holds every breed,
## affix, tower, relic, weather and animal; `MetaState.codex_seen` holds what has
## been met. This adds no content, no save shape and no balance risk - it reads
## two things the game already maintains and lays them out.
##
## It exists mostly for the affixes. A player who meets "Rimewarded Ironhide
## Bogkin" learns two new words in the middle of a fight they are losing, and
## needs somewhere to look them up afterwards; a promotion system without one
## teaches by attrition.
##
## Undiscovered entries are shown as silhouettes rather than hidden. A codex that
## hides what you have not met cannot tell you how much road is left, which is
## most of why anybody opens one.

## What is catalogued, in the order it is offered. Each row is the section's
## heading, the `codex_seen` prefix, and where the entries come from.
const SECTIONS: Array[Dictionary] = [
	{"title": "Breeds", "kind": "enemy", "source": "enemies"},
	{"title": "Marks of the Promoted", "kind": "affix", "source": "affixes"},
	{"title": "Wildlife", "kind": "wildlife", "source": "wildlife_kinds"},
	{"title": "Weather", "kind": "weather", "source": "weathers"},
]

var _heading: Label
var _note: Label
var _rows: VBoxContainer
var _close_button: Button


func _ready() -> void:
	layer = 90
	visible = false
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(940.0, 0.0)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 22)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_note)

	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	# Same reasoning as the Chronicle: the entries are the flexible part and
	# scroll; the only way out is always on screen.
	scroll.custom_minimum_size = Vector2(0.0, 420.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(hide_screen)
	column.add_child(_close_button)


func open() -> void:
	visible = true
	_refresh()
	_close_button.grab_focus()


func hide_screen() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		hide_screen()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()

	var met: int = 0
	var total: int = 0
	for section: Dictionary in SECTIONS:
		var table: Dictionary = ContentDB.get(String(section["source"]))
		total += table.size()
		met += MetaState.seen_count(String(section["kind"]))

	_heading.text = "Codex  ·  %d of %d found" % [met, total]
	_note.text = ("Everything the road has shown you. What you have not met yet "
		+ "is listed but not described - finding it is the description.")

	for section: Dictionary in SECTIONS:
		var kind: String = String(section["kind"])
		var table: Dictionary = ContentDB.get(String(section["source"]))
		_rows.add_child(_section_heading("%s  ·  %d / %d" % [
			String(section["title"]), MetaState.seen_count(kind), table.size()]))
		var ids: Array = table.keys()
		ids.sort()
		for id: Variant in ids:
			var entry := table[id] as GameData
			if entry != null:
				_rows.add_child(_entry_row(kind, entry))


## The numbers behind an entry, on a second line.
##
## **Only what a player could have worked out by fighting it**, which is the rule
## that keeps a codex from becoming a spoiler sheet. Health, damage and speed are
## observable; so is the fact that something ignores knockback or targets your
## towers. Drop *chances* are not listed as percentages, because a number turns
## a discovery into a farm - the entry says what a thing can leave behind, and
## the player finds out how often by playing.
func _detail_for(kind: String, entry: GameData) -> String:
	match kind:
		"enemy":
			return _enemy_detail(entry as EnemyData)
		"affix":
			return _affix_detail(entry as EnemyAffixData)
		"wildlife":
			var animal := entry as WildlifeData
			if animal == null:
				return ""
			return "
%s  ·  %d health  ·  %s" % [
				"Predator" if animal.is_hostile() else "Harmless",
				int(animal.max_hp),
				"drops food and hide" if animal.max_hp > 0.0 else "ambient"]
		_:
			return ""


func _enemy_detail(foe: EnemyData) -> String:
	if foe == null:
		return ""
	var facts: PackedStringArray = [
		"%d health" % int(foe.max_hp),
		"%d damage" % int(foe.contact_damage),
		"%d speed" % int(foe.move_speed),
	]
	# The traits worth knowing before you meet the next one.
	var traits: PackedStringArray = []
	if foe.role == EnemyData.Role.HOWLER:
		traits.append("strikes at range")
	if foe.targets_towers:
		traits.append("breaks towers")
	if foe.knockback_resistance >= 0.5:
		traits.append("hard to move")
	elif foe.knockback_resistance <= 0.05:
		traits.append("staggers easily")
	if foe.hp_regen > 0.0:
		traits.append("closes its own wounds")
	if foe.aura_radius > 0.0 and foe.aura_strength > 0.0:
		traits.append("strengthens what stands near it")
	if not foe.phase_thresholds.is_empty():
		traits.append("fights in %d stages" % (foe.phase_thresholds.size() + 1))
	var line: String = "
" + "  ·  ".join(facts)
	if not traits.is_empty():
		line += "
" + "  ·  ".join(traits)
	return line


func _affix_detail(affix: EnemyAffixData) -> String:
	if affix == null:
		return ""
	var effects: PackedStringArray = []
	if not is_equal_approx(affix.health_scale, 1.0):
		effects.append("%d%% health" % int(round(affix.health_scale * 100.0)))
	if not is_equal_approx(affix.damage_scale, 1.0):
		effects.append("%d%% damage" % int(round(affix.damage_scale * 100.0)))
	if not is_equal_approx(affix.speed_scale, 1.0):
		effects.append("%d%% speed" % int(round(affix.speed_scale * 100.0)))
	if affix.damage_resistance > 0.0:
		effects.append("takes %d%% less" % int(round(affix.damage_resistance * 100.0)))
	if affix.on_hit_slow_duration > 0.0:
		effects.append("chills what it strikes")
	if affix.on_hit_burn_duration > 0.0:
		effects.append("burns what it strikes")
	if affix.death_blast_radius > 0.0:
		effects.append("bursts when killed")
	if affix.regeneration > 0.0:
		effects.append("mends itself")
	return "
" + "  ·  ".join(effects) if not effects.is_empty() else ""


func _section_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("c9b98d"))
	return label


## One line. Found entries name themselves and say what they are; the rest show
## only that they exist.
func _entry_row(kind: String, entry: GameData) -> PanelContainer:
	var found: bool = MetaState.has_seen(kind, entry.id)
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(44.0, 44.0)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path: String = entry.get_sprite_path()
	if found and ResourceLoader.exists(path):
		art.texture = load(path)
	elif ResourceLoader.exists(path):
		# A silhouette: the shape is a promise, and blacking it out is what makes
		# an unfound entry read as something to go and meet rather than a gap.
		art.texture = load(path)
		art.modulate = Color(0.0, 0.0, 0.0, 0.55)
	row.add_child(art)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = entry.display_name if found else "Not yet met"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color",
		Color("efe3c6") if found else Color("6d6960"))
	text.add_child(name_label)

	var body := Label.new()
	body.text = (entry.description + _detail_for(kind, entry)) if found else ""
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color("9d9484"))
	text.add_child(body)
	return panel
