class_name GuideScreen
extends CanvasLayer

## The guide: everything a player might need to look up, in one place.
##
## Owner brief (2026-09-12): a section on the main menu with all of the game's
## guide sections - the lore, the story as unlocked so far, how to fish, how
## to heal, the basics with screenshots, what resources and items are, a
## glossary, a clear view of progress, and achievements.
##
## Laid out like the codex: a panel, tabs across the top, a scrolling body
## and a Close that is always on screen. Every word comes from data
## (`GuideSectionData`, `LoreEntryData`, `AchievementData`) so the guide is
## edited by editing files, and `guide_check` reads the same files to make
## sure every section names a real category, every picture exists, and every
## achievement reads a statistic the account actually keeps.

signal closed()

const CATEGORY_ORDER: Array[String] = ["Lore & Story", "Basics", "Fighting", "Building",
	"The Road", "Fishing & Water", "Healing", "Resources", "Items & Gear",
	"Companions", "Camps & Rifts", "Co-op", "Glossary", "Progress", "Achievements"]

const PANEL_MAX_WIDTH: float = 1100.0
const PANEL_SCREEN_SHARE: float = 0.94
const BODY_SCREEN_SHARE: float = 0.58
const BODY_SCREEN_SHARE_PORTRAIT: float = 0.72
const IMAGE_WIDTH: float = 420.0

var _panel: PanelContainer
var _tabs: HBoxContainer
var _tab_scroll: ScrollContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _close_button: Button
var _title: Label
var _category: String = ""
var _tab_buttons: Dictionary = {}


func _ready() -> void:
	layer = 91
	visible = false
	_build()
	get_viewport().size_changed.connect(_refit)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.name = "Guide"
	_panel.set_meta(UiMetrics.SELF_SIZED, true)
	centre.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)

	_title = Label.new()
	_title.text = "THE GUIDE"
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color("e8a33d"))
	column.add_child(_title)

	# The tabs scroll sideways on a phone rather than wrapping into three rows
	# that push the body off the screen.
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Every menu scroll surface shares one contract (menu_check): drag, and
	# focus that follows the keyboard. The tab strip never scrolls vertically,
	# but it is a ScrollContainer and holds the contract like the rest.
	UiMetrics.prepare_scroll(_tab_scroll, TouchInput.is_showing())
	# ...and sideways as well: the tabs are a strip.
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tab_scroll.custom_minimum_size = Vector2(0.0, 50.0)
	column.add_child(_tab_scroll)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tab_scroll.add_child(_tabs)
	for name: String in CATEGORY_ORDER:
		var button := Button.new()
		button.text = name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, 40.0)
		button.pressed.connect(func() -> void: show_category(name))
		_tabs.add_child(button)
		_tab_buttons[name] = button

	_scroll = ScrollContainer.new()
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	UiMetrics.prepare_scroll(_scroll, TouchInput.is_showing())
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	_scroll.add_child(_body)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0.0, 44.0)
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	_refit()


func open(category: String = "") -> void:
	visible = true
	show_category(category if not category.is_empty() else
		(_category if not _category.is_empty() else CATEGORY_ORDER[0]))
	_refit()
	_refit.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func show_category(name: String) -> void:
	_category = name
	for key: Variant in _tab_buttons:
		(_tab_buttons[key] as Button).button_pressed = String(key) == name
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0
	match name:
		"Lore & Story":
			_build_lore()
		"Progress":
			_build_progress()
		"Achievements":
			_build_achievements()
		_:
			_build_sections(name)
	UiMetrics.apply_touch_tree(_body, TouchInput.is_showing())
	var button: Button = _tab_buttons.get(name, null) as Button
	if button != null:
		button.grab_focus()


# --- Sections ------------------------------------------------------------------

func _build_sections(category: String) -> void:
	var sections: Array[GuideSectionData] = ContentDB.guide_sections_sorted()
	var any: bool = false
	for section: GuideSectionData in sections:
		if section.category != category:
			continue
		any = true
		_body.add_child(_section(section))
	if not any:
		_body.add_child(_note("Nothing written here yet."))


func _section(section: GuideSectionData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _skin())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	if not section.image.is_empty() and ResourceLoader.exists(section.image):
		var picture := TextureRect.new()
		picture.texture = load(section.image)
		picture.custom_minimum_size = Vector2(IMAGE_WIDTH, IMAGE_WIDTH * 0.5625)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	text.add_child(_heading(section.title))
	text.add_child(_paragraph(section.body))
	return panel


# --- Lore and the story so far ---------------------------------------------------

func _build_lore() -> void:
	var entries: Array[LoreEntryData] = ContentDB.lore_sorted()
	for category: int in [LoreEntryData.Category.WORLD, LoreEntryData.Category.STORY,
			LoreEntryData.Category.REGION]:
		var label: String = ["The World", "The Story So Far", "The Regions"][category]
		_body.add_child(_heading(label, 22))
		for entry: LoreEntryData in entries:
			if int(entry.category) != category:
				continue
			_body.add_child(_lore_row(entry))


func _lore_row(entry: LoreEntryData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _skin(entry.is_unlocked()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	if entry.is_unlocked() and not entry.art.is_empty() and ResourceLoader.exists(entry.art):
		var picture := TextureRect.new()
		picture.texture = load(entry.art)
		picture.custom_minimum_size = Vector2(180.0, 100.0)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(picture)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 6)
	row.add_child(text)
	if entry.is_unlocked():
		text.add_child(_heading(entry.title))
		text.add_child(_paragraph(entry.body))
	else:
		var locked: Label = _heading("Reach Act %d" % entry.unlock_act)
		locked.add_theme_color_override("font_color", Color("6d6960"))
		text.add_child(locked)
		text.add_child(_paragraph("This chapter is still ahead of you.", Color("6d6960")))
	return panel


# --- Progress --------------------------------------------------------------------

func _build_progress() -> void:
	_body.add_child(_heading("Where this account stands", 22))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	var codex_total: int = 0
	for source: String in ["enemies", "affixes", "wildlife_kinds", "weathers"]:
		codex_total += (ContentDB.get(source) as Dictionary).size()
	var codex_seen: int = MetaState.codex_seen.size()
	var lore_read: int = 0
	var lore_total: int = 0
	for entry: LoreEntryData in ContentDB.lore_sorted():
		lore_total += 1
		if entry.is_unlocked():
			lore_read += 1
	var earned: int = 0
	var achievements: Array[AchievementData] = ContentDB.achievements_sorted()
	for achievement: AchievementData in achievements:
		if MetaState.achievements.has(achievement.id):
			earned += 1
	var rows: Array = [
		["Warden", "%s  ·  %s  ·  level %d" % [
			MetaState.player_name if not MetaState.player_name.is_empty() else "Oathless",
			MetaState.warden_title(), MetaState.hero_level]],
		["Runs", "%d started  ·  %d won" % [MetaState.runs_started, MetaState.runs_won]],
		["Furthest act", "Act %d of %d" % [MetaState.highest_act, Balance.ACT_COUNT]],
		["Bosses felled", str(MetaState.bosses_felled)],
		["Enemies slain", str(MetaState.total_enemies_killed)],
		["Camps razed", "%d  ·  %d forks opened  ·  %d war camps" % [
			MetaState.camps_razed, MetaState.forks_opened, MetaState.war_camps_razed]],
		["Rifts", "%d stages closed  ·  %d dungeons finished" % [
			MetaState.rifts_closed, MetaState.dungeons_finished]],
		["Fish landed", "%d  ·  Angler level %d" % [MetaState.fish_caught_total,
			MetaState.profession_level("angler")]],
		["Codex", "%d of %d found" % [codex_seen, codex_total]],
		["Lore", "%d of %d chapters read" % [lore_read, lore_total]],
		["Spirits", "%d bonded" % MetaState.spirit_bonded.size()],
		["Achievements", "%d of %d" % [earned, achievements.size()]],
		["Best distance", "%d" % int(MetaState.best_distance)],
		["Marks and Shards", "%d  ·  %d" % [MetaState.marks, MetaState.shards]],
	]
	for pair: Array in rows:
		var key: Label = _paragraph(String(pair[0]), Color("e8a33d"))
		var value: Label = _paragraph(String(pair[1]))
		grid.add_child(key)
		grid.add_child(value)
	_body.add_child(_note("Everything here is a statistic the account keeps. None of it is power."))


# --- Achievements ----------------------------------------------------------------

func _build_achievements() -> void:
	var achievements: Array[AchievementData] = ContentDB.achievements_sorted()
	var earned: int = 0
	for achievement: AchievementData in achievements:
		if MetaState.achievements.has(achievement.id):
			earned += 1
	_body.add_child(_heading("Achievements  ·  %d of %d" % [earned, achievements.size()], 22))
	for achievement: AchievementData in achievements:
		_body.add_child(_achievement_row(achievement))


func _achievement_row(achievement: AchievementData) -> Control:
	var done: bool = MetaState.achievements.has(achievement.id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _skin(done))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var icon: TextureRect = IconKit.rect(achievement.icon, 40.0)
	if icon != null:
		icon.modulate = Color.WHITE if done else Color(0.4, 0.4, 0.42)
		row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	var title: Label = _heading(achievement.title)
	if not done:
		title.add_theme_color_override("font_color", Color("8a8478"))
	text.add_child(title)
	text.add_child(_paragraph(achievement.description))
	if not done:
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.value = achievement.progress()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0.0, 6.0)
		text.add_child(bar)
	return panel


# --- Pieces -----------------------------------------------------------------------

func _skin(lit: bool = true) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(1.0, 1.0, 1.0, 0.03) if lit else Color(0.0, 0.0, 0.0, 0.12)
	skin.border_color = Color(0.86, 0.72, 0.42, 0.16 if lit else 0.06)
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(6)
	skin.content_margin_left = 16
	skin.content_margin_right = 16
	skin.content_margin_top = 12
	skin.content_margin_bottom = 12
	return skin


func _heading(text: String, size: int = 20) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("efe3c6"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _paragraph(text: String, colour: Color = Color("c9c2b4")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _note(text: String) -> Label:
	var label: Label = _paragraph(text, Color("8f9b98"))
	return label


func _refit() -> void:
	if _panel == null:
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var portrait: bool = screen.y > screen.x
	var width: float = minf(PANEL_MAX_WIDTH, screen.x * PANEL_SCREEN_SHARE)
	_panel.custom_minimum_size = Vector2(width, 0.0)
	_tab_scroll.custom_minimum_size = Vector2(width - 40.0, 50.0)
	var share: float = BODY_SCREEN_SHARE_PORTRAIT if portrait else BODY_SCREEN_SHARE
	# Bounded above by the screen: on a phone held sideways (932x430) the
	# tabs, the body and the Close have to share 430 pixels, and a body that
	# insists on 260 pushes the Close off the bottom (menu_layout_check).
	var room: float = maxf(screen.y - 420.0, 120.0)
	_scroll.custom_minimum_size = Vector2(0.0, clampf(screen.y * share, 120.0, room))
	_panel.reset_size()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
