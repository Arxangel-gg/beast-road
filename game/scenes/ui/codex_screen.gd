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


## **Sized for the thing it holds, not for the smallest thing that would fit.**
##
## The entries were 44px squares beside 12pt body text - sprites drawn at 64 to
## 192 shown at a third of their size, with no padding inside the rows and six
## pixels between them. A list of discoveries read as a dense table, which is the
## opposite of what a codex is for.
const ART_SIZE: float = 96.0
const ROW_PAD_X: int = 16
const ROW_PAD_Y: int = 12
const ROW_GAP: int = 10
const FONT_HEADING: int = 26
const FONT_NOTE: int = 15
const FONT_NAME: int = 20
const FONT_BODY: int = 15

## The widest the panel is allowed to be, and the share of the screen it may take
## on anything narrower. A fixed 940 was wider than a phone in portrait, so the
## panel ran off both edges of the one platform that needed the care most.
const PANEL_MAX_WIDTH: float = 1040.0
const PANEL_SCREEN_SHARE: float = 0.94
const LIST_SCREEN_SHARE: float = 0.56
const LIST_SCREEN_SHARE_PORTRAIT: float = 0.74

## Entries whose art has an idle sequence, and the frames to play.
##
## Animated here rather than per row, so the whole list steps on one clock and a
## page of forty creatures costs one integer comparison a frame instead of forty
## timers.
var _animated: Array[Dictionary] = []

## Which species' variants are showing in the journal, or "".
var _spirit_open: String = ""
var _art_clock: float = 0.0
var _art_frame: int = 0

## Whether the rows just built should be grown for a thumb.
var _grow_for_touch: bool = false


func _process(delta: float) -> void:
	if _animated.is_empty() or not visible:
		return
	_art_clock += delta * Balance.CODEX_ART_FRAME_RATE
	var step: int = int(_art_clock)
	if step == _art_frame:
		return
	_art_frame = step
	for entry: Dictionary in _animated:
		var rect: TextureRect = entry["rect"]
		if not is_instance_valid(rect):
			continue
		var frames: Array = entry["frames"]
		rect.texture = frames[(step + int(entry["phase"])) % frames.size()]


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
	# Measured against the screen rather than fixed: 940 was wider than a phone
	# held upright, so the panel ran off both edges of the platform that needed
	# the care most.
	var screen: Vector2 = get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		minf(PANEL_MAX_WIDTH, screen.x * PANEL_SCREEN_SHARE), 0.0)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", FONT_HEADING)
	_heading.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_heading)

	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", FONT_NOTE)
	_note.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(_note)

	var scroll := ScrollContainer.new()
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	# Same reasoning as the Chronicle: the entries are the flexible part and
	# scroll; the only way out is always on screen.
	# A portrait screen is nearly all height and very little width, so the list
	# should take much more of it - centred in a tall screen the panel floated in
	# the middle with empty bands above and below, wasting the one dimension a
	# phone has to spare.
	var portrait: bool = screen.y > screen.x
	var share: float = LIST_SCREEN_SHARE_PORTRAIT if portrait else LIST_SCREEN_SHARE
	scroll.custom_minimum_size = Vector2(0.0, maxf(320.0, screen.y * share))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", ROW_GAP)
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
	# Rebuilt rows mean the old TextureRects are about to be freed; a stale entry
	# here would be a freed node walked on every animation step.
	_animated.clear()
	# **Grown for a thumb, which this screen never did.** Only the HUD applied
	# the touch metrics, so on a phone the Codex kept desktop type in a window a
	# third the width - the platform that needed the sizing most was the one not
	# getting it. Applied at the end of the build, below.
	_grow_for_touch = TouchInput.is_showing()
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

	_build_spirit_journal()

	# Applied once over the finished list rather than per row: it walks the tree
	# and is not free, and every row is in place by now.
	UiMetrics.apply_touch_tree(self, _grow_for_touch)


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
	# **Padding inside the row.** There was none: art and text ran to the panel's
	# own edge and rows touched each other, which is most of what made a list of
	# discoveries read as a spreadsheet.
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(1.0, 1.0, 1.0, 0.028) if found else Color(0.0, 0.0, 0.0, 0.10)
	skin.border_color = Color(0.86, 0.72, 0.42, 0.16 if found else 0.06)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(6)
	skin.content_margin_left = ROW_PAD_X
	skin.content_margin_right = ROW_PAD_X
	skin.content_margin_top = ROW_PAD_Y
	skin.content_margin_bottom = ROW_PAD_Y
	panel.add_theme_stylebox_override("panel", skin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path: String = entry.get_sprite_path()
	if ResourceLoader.exists(path):
		art.texture = load(path)
		if not found:
			# A silhouette: the shape is a promise, and blacking it out is what
			# makes an unfound entry read as something to go and meet rather
			# than a gap.
			art.modulate = Color(0.0, 0.0, 0.0, 0.55)
		# **Animated, silhouette included.** A creature standing perfectly still
		# in a book of living things reads as a specimen; the same walk cycle it
		# has on the field makes the page feel like a record of something met.
		# The silhouette animates too - a shape that moves is a better promise
		# than a shape that does not.
		var frames: Array[Texture2D] = GameData.load_idle_frames(path)
		if frames.size() >= 1:
			_animated.append({
				"rect": art,
				"frames": frames,
				# Its own offset, so a page of forty creatures does not breathe
				# in unison - the same reason the grass carries one.
				"phase": _animated.size(),
			})
	row.add_child(art)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)

	var name_label := Label.new()
	name_label.text = entry.display_name if found else "Not yet met"
	name_label.add_theme_font_size_override("font_size", FONT_NAME)
	name_label.add_theme_color_override("font_color",
		Color("efe3c6") if found else Color("6d6960"))
	text.add_child(name_label)

	var body := Label.new()
	body.text = (entry.description + _detail_for(kind, entry)) if found else ""
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", FONT_BODY)
	body.add_theme_color_override("font_color", Color("9d9484"))
	text.add_child(body)
	return panel


# --- The Wildlife Spirit Journal ---------------------------------------------
#
# Owner decision, 2026-09-01. Here rather than on a screen of its own, and that
# is the brief's own preference: the Codex is already "everything the road has
# shown you", and a bonded spirit is exactly that. A second screen would have
# meant two places to look for the same fact.
#
# **One row per species, opened to show its eight variants.** Twenty-three
# species times eight is 184 rows, and a list that long is not a journal, it is
# a spreadsheet. Collapsed, the player sees which animals they have made
# progress on; opened, they see precisely what is left.

func _build_spirit_journal() -> void:
	var species: Array[WildlifeData] = ContentDB.wildlife()
	species.sort_custom(func(a: WildlifeData, b: WildlifeData) -> bool:
		return a.display_name < b.display_name)
	var bonded: int = 0
	var total: int = 0
	for kind: WildlifeData in species:
		for variant: String in SpiritBond.variants_of(kind.id):
			total += 1
			if MetaState.spirit_is_bonded(variant):
				bonded += 1
	_rows.add_child(_section_heading("Wildlife Spirits  ·  %d / %d bonded"
		% [bonded, total]))
	_rows.add_child(_spirit_note())

	for kind: WildlifeData in species:
		_rows.add_child(_spirit_species_row(kind))
		if _spirit_open == kind.id:
			for variant: String in SpiritBond.variants_of(kind.id):
				_rows.add_child(_spirit_variant_row(kind, variant))


func _spirit_note() -> Label:
	var label := Label.new()
	label.text = ("Meet an animal enough times and its spirit walks with you. "
		+ "Rarer needs fewer. Shinies are rarer still, and count for both.")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("9b917f"))
	return label


## One species, closed: how far along it is, and whether anything is equipped.
func _spirit_species_row(kind: WildlifeData) -> Button:
	var bonded: int = 0
	var met: int = 0
	var equipped: bool = false
	for variant: String in SpiritBond.variants_of(kind.id):
		if MetaState.spirit_is_bonded(variant):
			bonded += 1
		if MetaState.spirit_is_known(variant):
			met += 1
		if MetaState.equipped_spirit == variant:
			equipped = true
	var row := Button.new()
	row.text = "%s%s  ·  %d of 8 bonded%s" % [
		"▾ " if _spirit_open == kind.id else "▸ ", kind.display_name, bonded,
		"  ·  WALKING WITH YOU" if equipped else ""]
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = 42.0
	UiMetrics.wrap_row(row)
	if met == 0:
		# Never seen at all. Named, because knowing the animal exists is what
		# makes looking for it a thing to do - but nothing else is given away.
		row.text = "▸ %s  ·  not yet met" % kind.display_name
		row.add_theme_color_override("font_color", Color("6d6556"))
	if ResourceLoader.exists(kind.get_sprite_path()) and met > 0:
		UiMetrics.row_icon(row, load(kind.get_sprite_path()), 30)
	row.pressed.connect(func() -> void:
		_spirit_open = "" if _spirit_open == kind.id else kind.id
		_refresh())
	return row


## One variant, open: its progress, and the button that equips it.
func _spirit_variant_row(kind: WildlifeData, variant: String) -> Button:
	var rarity: int = SpiritBond.rarity_of(variant)
	var shiny: bool = SpiritBond.shiny_of(variant)
	var have: int = MetaState.spirit_encounter_count(variant)
	var want: int = SpiritBond.needed(rarity, shiny)
	var row := Button.new()
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size.y = 38.0
	UiMetrics.wrap_row(row)

	var label: String = "%s%s" % ["Shiny " if shiny else "",
		Balance.SPIRIT_RARITY_NAMES[rarity]]
	if MetaState.spirit_is_bonded(variant):
		var here: bool = MetaState.equipped_spirit == variant
		row.text = "      %s  ·  %s" % [label, "walking with you" if here else "bonded — equip"]
		row.add_theme_color_override("font_color", SpiritBond.tint(rarity, shiny))
		row.disabled = here
		row.pressed.connect(func() -> void:
			MetaState.equip_spirit(variant)
			_refresh())
	elif have > 0:
		row.text = "      %s  ·  %d / %d" % [label, have, want]
		row.disabled = true
	else:
		# Unmet variants are a question mark rather than a row of zeroes: the
		# discovery is meant to be part of the reward, and a journal that lists
		# every shiny you have never seen tells you the answer in advance.
		row.text = "      %s  ·  ???" % label
		row.add_theme_color_override("font_color", Color("4a443a"))
		row.disabled = true
	return row
