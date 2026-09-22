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

## **Which page is open.** `TAB_ALL` is everything in one list, the way the
## Codex has always read; `TAB_SPIRITS` is the journal on its own; anything
## else is an act number and shows only what walks that road.
##
## Owner, 2026-09-22: *"a tab for all, or tabs for each act, and a tab for
## Wildlife Spirits"*. Both, because they answer different questions - "what
## have I met" wants the whole book and "what am I about to meet" wants one
## act - and the journal wants a page because it is the only section a player
## opens to *do* something rather than to read.
const TAB_ALL: int = 0
const TAB_SPIRITS: int = -1

var _heading: Label
var _note: Label
var _tab: int = TAB_ALL
var _tab_bar: HFlowContainer
## **What the player is looking for** (owner, 2026-09-22: *"also add a search
## for the codex"*). Folded to lower case once here rather than at every
## comparison, and matched against a name, a description and the section it
## sits in - so "howler" finds the role and "burns" finds the affix that does.
##
## It narrows whatever page is open rather than replacing it: a search that
## silently jumped to All would lose the act the player had chosen, and a
## search that only looked at one act would read as broken. The heading says
## which it is.
var _search: String = ""
var _search_edit: LineEdit = null
var _rows: VBoxContainer
var _close_button: Button
var _panel: PanelContainer
var _scroll: ScrollContainer


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


## **Sized for the thing it holds, not for the smallest thing that would fit.**
##
## The entries were 44px squares beside 12pt body text - sprites drawn at 64 to
## 192 shown at a third of their size, with no padding inside the rows and six
## pixels between them. A list of discoveries read as a dense table, which is the
## opposite of what a codex is for.
const ART_SIZE: float = 96.0
const ROW_PAD_X: int = 16
const ROW_PAD_Y: int = 12
const ROW_GAP: int = 12
const FONT_HEADING: int = 26
const FONT_NOTE: int = 15
const FONT_NAME: int = 20
const FONT_BODY: int = 15

## The widest the panel is allowed to be, and the share of the screen it may take
## on anything narrower. A fixed 940 was wider than a phone in portrait, so the
## panel ran off both edges of the one platform that needed the care most.
## **What a tab and the search box are worth on a thumb.** The touch pass
## grows every `BaseButton` to `UI_TOUCH_MIN_TARGET_HEIGHT`, which for thirteen
## tabs is three rows of 92 - two hundred and seventy units of a phone held
## sideways, and the Codex's panel then stood 913 tall in a 775 screen with the
## way out off the bottom of it. They are sized here instead and marked
## `SELF_SIZED`, so the pass grows the type and leaves the box; the same number
## is declared as their touch floor so the layout gates hold them to what they
## were designed for rather than to the general one.
const TAB_HEIGHT: float = 34.0
const TAB_TOUCH_HEIGHT: float = 52.0

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
	_panel = panel
	panel.set_meta(UiMetrics.SELF_SIZED, true)
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
	column.add_child(_build_tab_bar())
	column.add_child(_build_search())

	var scroll := ScrollContainer.new()
	_scroll = scroll
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
	# The way out stays at the bottom of the window whatever is above it.
	# See `UiPanels.pin_last_to_bottom` for why this is a spacer rather than a
	# size flag on the list.
	UiPanels.pin_last_to_bottom(column)


func open() -> void:
	# **Followed rather than fitted once.** A phone rotated with the Codex open
	# kept the panel the old shape had given it, and on the short shape that
	# put the way out off the bottom of the screen. A named method rather than
	# a lambda, for the reason `enemy_shot_check` paid for: a lambda's capture
	# is freed with the screen and every later resize errors on nothing.
	var view: Viewport = get_viewport()
	if view != null and not view.size_changed.is_connected(_on_view_resized):
		view.size_changed.connect(_on_view_resized)
	visible = true
	_refresh()
	_refit()
	_refit.call_deferred()
	_close_button.grab_focus()


func _on_view_resized() -> void:
	if not visible:
		return
	_refit()
	_refit.call_deferred()


func _refit() -> void:
	if not is_inside_tree() or _panel == null or _scroll == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	_panel.custom_minimum_size.x = minf(PANEL_MAX_WIDTH, screen.x * PANEL_SCREEN_SHARE)
	var share: float = LIST_SCREEN_SHARE_PORTRAIT if screen.y > screen.x else LIST_SCREEN_SHARE
	_scroll.custom_minimum_size.y = minf(screen.y * share,
		UiMetrics.scroll_room_measured(_scroll, _scroll.get_parent() as Control,
			Balance.UI_PANEL_MARGIN))


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

	_style_tabs()
	if _search_edit != null:
		_search_edit.custom_minimum_size.y = 			TAB_TOUCH_HEIGHT if _grow_for_touch else TAB_HEIGHT
	if _tab == TAB_SPIRITS:
		_note.text = ("Every animal the road can bond. What one eats is what "
			+ "it costs to keep at your shoulder, and a rarer spirit is a "
			+ "stronger one and eats like it.")
		_build_spirit_journal()
	else:
		if _tab != TAB_ALL:
			_note.text = ("What walks Act %s. Anything with no act of its "
				+ "own - a camp's own breeds, the wyrms - is on the whole "
				+ "book's page.") % _roman(_tab)
		var hits: int = 0
		for section: Dictionary in SECTIONS:
			var kind: String = String(section["kind"])
			var table: Dictionary = ContentDB.get(String(section["source"]))
			var ids: Array = table.keys()
			ids.sort()
			var shown: Array[GameData] = []
			for id: Variant in ids:
				var entry := table[id] as GameData
				if entry != null and _belongs(kind, entry, _tab) \
						and _matches(kind, entry, String(section["title"])):
					shown.append(entry)
			if shown.is_empty():
				continue
			hits += shown.size()
			# **Counted over what is on the page, not over the book.** The
			# heading above already carries the book's own total; repeating it
			# beside a filtered list printed "Breeds · 45 / 9".
			var found: int = 0
			for entry: GameData in shown:
				if MetaState.has_seen(kind, entry.id):
					found += 1
			_rows.add_child(_section_heading("%s  ·  %d / %d" % [
				String(section["title"]), found, shown.size()]))
			for entry: GameData in shown:
				_rows.add_child(_entry_row(kind, entry))
		if hits == 0:
			_rows.add_child(_nothing_found())

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


## **Which page an entry belongs on**, and an entry with no act of its own is
## on the whole book's page only.
##
## Read off the content rather than authored a second time: a breed belongs to
## an act because that act's terrain names it in `enemy_ids`, `veteran_ids` or
## `boss_id`, which is the same list the wave director draws from. A camp's own
## breeds and the wyverns are named by no terrain, so they are on `TAB_ALL` -
## which is correct rather than a gap: they are not what walks that road.
func _belongs(kind: String, entry: GameData, tab: int) -> bool:
	if tab == TAB_ALL:
		return true
	match kind:
		"enemy":
			var terrain: TerrainData = ContentDB.terrain_for_act(tab)
			if terrain == null:
				return false
			return terrain.enemy_ids.has(entry.id) \
				or terrain.veteran_ids.has(entry.id) \
				or terrain.boss_id == entry.id
		"affix":
			var mark := entry as EnemyAffixData
			return mark != null and mark.from_act <= tab
		"wildlife":
			var animal := entry as WildlifeData
			if animal == null:
				return false
			# An empty list is a preference for nowhere in particular, which
			# means everywhere - `roll_weight`'s own reading of it.
			return animal.acts.is_empty() or animal.acts.has(tab)
		_:
			# Weather is the same weather on every road.
			return true


## The tabs, built once. Styled on every refresh so the open one reads as open.
func _build_tab_bar() -> HFlowContainer:
	_tab_bar = HFlowContainer.new()
	_tab_bar.add_theme_constant_override("h_separation", 6)
	_tab_bar.add_theme_constant_override("v_separation", 6)
	_add_tab("All", TAB_ALL)
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		_add_tab(_roman(act), act)
	_add_tab("Spirits", TAB_SPIRITS)
	return _tab_bar


func _add_tab(text: String, which: int) -> void:
	var button := Button.new()
	button.text = text
	button.name = "Tab%d" % which
	button.set_meta(&"tab", which)
	button.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
	button.set_meta(UiMetrics.SELF_SIZED, true)
	button.set_meta(UiMetrics.TOUCH_TARGET_HEIGHT, TAB_TOUCH_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(func() -> void:
		if _tab == which:
			return
		_tab = which
		_refresh()
		# Back to the top: a page changed under a scroll left half way down is
		# a page that looks empty.
		if _scroll != null:
			_scroll.scroll_vertical = 0)
	_tab_bar.add_child(button)


func _style_tabs() -> void:
	if _tab_bar == null:
		return
	for child: Node in _tab_bar.get_children():
		var button := child as Button
		if button == null:
			continue
		var open: bool = int(button.get_meta(&"tab", TAB_ALL)) == _tab
		button.add_theme_color_override("font_color",
			Color("f2dfa8") if open else Color("8d8579"))
		# **Not disabled.** Greying the open tab is the one styling that reads
		# as "this page is unavailable" - exactly backwards. It is lit instead,
		# and pressing it again costs nothing because `_add_tab` returns early.
		button.modulate = Color(1.16, 1.10, 0.96) if open else Color(0.82, 0.82, 0.84)
		# Sized here rather than at build: whether this is a thumb or a mouse is
		# read on every refresh, and a rotation may answer it differently.
		button.custom_minimum_size.y = TAB_TOUCH_HEIGHT if _grow_for_touch else TAB_HEIGHT


## **The search box.** Narrows the open page; it does not replace it.
func _build_search() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = "Search"
	label.add_theme_font_size_override("font_size", FONT_NOTE)
	label.add_theme_color_override("font_color", Color("9b917f"))
	line.add_child(label)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "a name, a word in a description, a section"
	_search_edit.clear_button_enabled = true
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.custom_minimum_size.y = TAB_HEIGHT
	_search_edit.set_meta(UiMetrics.SELF_SIZED, true)
	_search_edit.set_meta(UiMetrics.TOUCH_TARGET_HEIGHT, TAB_TOUCH_HEIGHT)
	# Every keystroke, rather than on submit: a book of 160 entries is searched
	# by typing three letters and reading, and a search that needs Enter is one
	# a player tries once.
	_search_edit.text_changed.connect(func(text: String) -> void:
		_search = text.strip_edges().to_lower()
		_refresh()
		if _scroll != null:
			_scroll.scroll_vertical = 0)
	line.add_child(_search_edit)
	return line


## Whether an entry answers what was typed. Empty matches everything, which is
## what makes the field cost nothing to leave alone.
func _matches(kind: String, entry: GameData, section: String) -> bool:
	if _search.is_empty():
		return true
	if entry.display_name.to_lower().contains(_search) \
			or section.to_lower().contains(_search) \
			or entry.id.to_lower().contains(_search):
		return true
	# The description and the detail line only once the thing has been met -
	# otherwise a search reads out the text of entries the page is deliberately
	# withholding, which is the one thing an unfound row must not do.
	if not MetaState.has_seen(kind, entry.id):
		return false
	return entry.description.to_lower().contains(_search) \
		or _detail_for(kind, entry).to_lower().contains(_search)


## Said out loud, because an empty list under a search box reads as a fault.
func _nothing_found() -> Label:
	var label := Label.new()
	label.text = "Nothing here answers to \"%s\"." % _search
	label.add_theme_font_size_override("font_size", FONT_BODY)
	label.add_theme_color_override("font_color", Color("9b917f"))
	return label


## An act as the road writes it. A table rather than the general algorithm,
## for the reason `boss_fall_card._roman` gives.
func _roman(act: int) -> String:
	const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V",
		"VI", "VII", "VIII", "IX", "X", "XI"]
	return NUMERALS[clampi(act - 1, 0, NUMERALS.size() - 1)]


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
	# **Its own square, whatever the row is doing.** A `TextureRect` in an
	# `HBoxContainer` fills the box's height by default, so a row whose text
	# ran to four lines drew a 96-wide frame 150 tall around a sprite centred
	# in it - the frame no longer fitted the slot, which is what it is for.
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Every entry gets an edge, found or not: a silhouette in a frame reads as
	# a portrait waiting to be filled in, and one without reads as missing art.
	FrameKit.hang(art)
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

	var hits: int = 0
	for kind: WildlifeData in species:
		if not _matches("wildlife", kind, "Wildlife Spirits"):
			continue
		hits += 1
		_rows.add_child(_spirit_species_row(kind))
		if _spirit_open == kind.id:
			for variant: String in SpiritBond.variants_of(kind.id):
				_rows.add_child(_spirit_variant_row(kind, variant))
	if hits == 0:
		_rows.add_child(_nothing_found())


func _spirit_note() -> Label:
	var label := Label.new()
	label.text = ("Meet an animal enough times and its spirit walks with you. "
		+ "Rarer needs fewer. Shinies are rarer still, and count for both.")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("9b917f"))
	return label


## **One species, read like every other page of the Codex** (owner,
## 2026-09-22: the spirits should be *"similar to the rest of the codex having
## the idle animation ... as well as their description and stats and unique
## traits"*).
##
## It was a one-line button with a 30px icon beside four-line entries with
## animated art, which read as a list bolted onto a book. It is the same
## panel the breeds get now: the animal's own idle cycle, its own description,
## what it is worth as a companion, and what it eats at every rarity - with
## the whole thing still a button, because opening it is how the variants are
## reached.
func _spirit_species_row(kind: WildlifeData) -> PanelContainer:
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

	# **A panel with a button laid over it, rather than a button with the
	# content anchored inside one.** A `Button` is not a `Container`, so an
	# anchored child neither sizes it nor is clipped by it - the first cut of
	# this row was 120px tall by construction and the upkeep ladder hung off
	# the bottom of it, drawn and unreadable. A `PanelContainer` takes its
	# height from the tallest child's minimum, which is the text column; the
	# button contributes none and simply covers the row to be pressed.
	var panel := PanelContainer.new()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(1.0, 1.0, 1.0, 0.028) if met > 0 else Color(0.0, 0.0, 0.0, 0.10)
	skin.border_color = Color(0.86, 0.72, 0.42, 0.16 if met > 0 else 0.06)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(6)
	skin.content_margin_left = ROW_PAD_X
	skin.content_margin_right = ROW_PAD_X
	skin.content_margin_top = ROW_PAD_Y
	skin.content_margin_bottom = ROW_PAD_Y
	panel.add_theme_stylebox_override("panel", skin)

	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 18)
	inside.alignment = BoxContainer.ALIGNMENT_CENTER
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inside)

	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	FrameKit.hang(art)
	var path: String = kind.get_sprite_path()
	if ResourceLoader.exists(path):
		art.texture = load(path)
		if met == 0:
			art.modulate = Color(0.0, 0.0, 0.0, 0.55)
		var frames: Array[Texture2D] = GameData.load_idle_frames(path)
		if frames.size() >= 1:
			_animated.append({"rect": art, "frames": frames, "phase": _animated.size()})
	inside.add_child(art)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 5)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(text)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", FONT_NAME)
	if met == 0:
		# Named, because knowing the animal exists is what makes looking for it
		# a thing to do - and nothing else is given away.
		title.text = "%s %s  ·  not yet met" % [
			"v" if _spirit_open == kind.id else ">", kind.display_name]
		title.add_theme_color_override("font_color", Color("6d6556"))
	else:
		title.text = "%s %s  ·  %d of 8 bonded%s" % [
			"v" if _spirit_open == kind.id else ">", kind.display_name, bonded,
			"  ·  WALKING WITH YOU" if equipped else ""]
		title.add_theme_color_override("font_color", Color("efe3c6"))
	text.add_child(title)

	if met > 0:
		var body := Label.new()
		body.text = kind.description
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", FONT_BODY)
		body.add_theme_color_override("font_color", Color("9d9484"))
		text.add_child(body)

		var facts := Label.new()
		facts.text = _spirit_facts(kind)
		facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		facts.add_theme_font_size_override("font_size", FONT_BODY)
		facts.add_theme_color_override("font_color", Color("8fa89a"))
		text.add_child(facts)

		var fed := Label.new()
		fed.text = _spirit_upkeep_line(kind)
		fed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fed.add_theme_font_size_override("font_size", FONT_BODY)
		fed.add_theme_color_override("font_color", Color("c9a86a"))
		text.add_child(fed)

	var press := Button.new()
	press.flat = true
	press.focus_mode = Control.FOCUS_ALL
	press.tooltip_text = "Open %s" % kind.display_name
	press.pressed.connect(func() -> void:
		_spirit_open = "" if _spirit_open == kind.id else kind.id
		_refresh())
	panel.add_child(press)
	return panel


## What the animal is, as a companion: what it brings and what makes it its
## own. Read off its own resource rather than authored twice.
func _spirit_facts(kind: WildlifeData) -> String:
	var facts: PackedStringArray = [
		"%d health" % int(kind.max_hp),
		"%d damage" % int(kind.damage),
		"%d speed" % int(kind.speed),
	]
	var traits: PackedStringArray = []
	if kind.mythic:
		traits.append("a legend, and only ever found at the end of its trail")
	if kind.is_hostile():
		traits.append("hunts")
	else:
		traits.append("harmless until it is cornered")
	if kind.flies:
		traits.append("flies")
	if kind.amphibious:
		traits.append("takes to water")
	if kind.lays_eggs:
		traits.append("lays")
	elif kind.breeds:
		traits.append("bears live young")
	if kind.steals:
		traits.append("steals what is left on the ground")
	if kind.hoards:
		# `hoard_chance` defaults to one, so reading it alone made every animal
		# in the book a loot goblin - `hoards` is the flag that decides.
		traits.append("carries a sack worth taking")
	if kind.group_max > 1:
		traits.append("moves in %d to %d" % [kind.group_min, kind.group_max])
	var line: String = "  ·  ".join(facts)
	if not traits.is_empty():
		line += "\n" + "  ·  ".join(traits)
	return line


## **What it eats, at every rarity.** The one number a player weighs a
## companion by that was nowhere on screen - and until 2026-09-22 it did not
## vary by rarity at all, which is what the owner asked be tuned.
##
## Read through `RunState.spirit_upkeep` on the species' own companion form, so
## the page and the larder cannot disagree about what a bear costs.
func _spirit_upkeep_line(kind: WildlifeData) -> String:
	var form: CompanionData = SpiritBond.companion_form(kind,
		SpiritBond.key(kind.id, 0, false))
	if form == null:
		return ""
	var parts: PackedStringArray = []
	for rarity: int in Balance.SPIRIT_RARITY_NAMES.size():
		parts.append("%s %.1f" % [Balance.SPIRIT_RARITY_NAMES[rarity],
			RunState.spirit_upkeep(form, rarity)])
	return "Eats a minute:  " + "  ·  ".join(parts) + "   (a meal to call)"


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
