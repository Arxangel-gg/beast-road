extends Control

## The VFX Forge, as a window.
##
## Owner, 2026-09-22: *"make it a full standalone app that can also be
## customized with an aesthetically appealing smart dark mode fully featured
## GUI so that I can also try previewing the shots and rendering sprite
## sheets within our app"*.
##
## **Its own Godot project, beside the launcher, for the launcher's own
## reason**: it ships to nobody and has nothing to do with the game's scene
## tree, so it must not be able to break the game by existing. What it shares
## with the game is the Python half under `tools/vfx_forge`, which is the
## thing actually doing the work - this window never renders anything itself
## and never authors an effect. It lists what the forge knows, asks it to
## render, and plays the result back the way the game will.
##
## **Everything it lists is read from the forge**, never from a table here: a
## file dropped in `effects/` appears in this window for exactly the same
## reason it appears on the command line. A tool with its own copy of the
## catalogue is a tool that is wrong the first time somebody adds an effect.

const SheetPlayerScript := preload("res://scripts/sheet_player.gd")
const RunnerScript := preload("res://scripts/forge_runner.gd")
const SkinScript := preload("res://scripts/forge_skin.gd")

## Tints to try a white sheet under: the four elements the game has, plus a
## plain one. A sheet is judged under the colour it will be used in, and the
## forge's whole premise is that one sheet serves all of them.
const TINTS: Array[Dictionary] = [
	{"name": "Fire", "colour": Color("ff8a3c")},
	{"name": "Water", "colour": Color("5fc6ff")},
	{"name": "Earth", "colour": Color("c9a86a")},
	{"name": "Air", "colour": Color("c9e8ff")},
	{"name": "Blood", "colour": Color("d9483c")},
	{"name": "Plain", "colour": Color("ffffff")},
]

var _runner: ForgeRunner = null
var _list: ItemList = null
var _player: SheetPlayer = null
var _strip: Control = null
var _log: RichTextLabel = null
var _status: Label = null
var _scrub: HSlider = null
var _frames: SpinBox = null
var _size: SpinBox = null
var _takes: SpinBox = null
var _take_pick: OptionButton = null
var _tint_pick: OptionButton = null
var _why: Label = null
var _render: Button = null
var _render_all: Button = null
var _play: Button = null

var _catalogue: Array = []
var _chosen: String = ""


func _ready() -> void:
	theme = SkinScript.build()
	_runner = RunnerScript.new()
	add_child(_runner)
	_runner.line_written.connect(_on_line)
	_runner.finished.connect(_on_finished)
	_build()
	_refresh_catalogue()
	var wrong: String = _runner.complaint()
	if wrong.is_empty():
		_say("Ready. %d effects." % _catalogue.size())
	else:
		_say(wrong, SkinScript.DANGER)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = SkinScript.PAPER
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 14.0
	page.offset_right = -14.0
	page.offset_top = 12.0
	page.offset_bottom = -12.0
	page.add_theme_constant_override("separation", 10)
	add_child(page)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	page.add_child(head)
	head.add_child(SkinScript.title("Wilderhold VFX Forge", 22))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	_status = SkinScript.quiet("")
	# **Never wrapped.** `quiet` wraps by default, which is right for a
	# paragraph and catastrophic here: in a row with an expanding spacer the
	# label is offered no width, wraps to one character a line, and the whole
	# header grows four hundred pixels tall - which is what the first
	# photograph of this window showed, with everything else pushed off the
	# bottom of the screen.
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	# And not clipped either: `clip_text` with `SHRINK_END` beside an
	# expanding spacer truncates to nothing, which is a status line that is
	# always empty. Off, its minimum width is its text, which the header has.
	_status.size_flags_horizontal = Control.SIZE_SHRINK_END
	head.add_child(_status)
	var paths := Button.new()
	paths.text = "Paths"
	paths.pressed.connect(_open_paths)
	head.add_child(paths)

	# **A splitter, because how much room each half deserves depends on what
	# you are doing** - reading a long catalogue, or looking closely at one
	# cell. That is the user's call rather than a number in this file, which
	# is the argument the Update Manager's tuning divider was added under.
	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 250
	page.add_child(body)
	body.add_child(_build_catalogue())
	body.add_child(_build_stage())


func _build_catalogue() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230.0, 0.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(SkinScript.title("Effects", 17))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.allow_reselect = true
	_list.item_selected.connect(_on_chosen)
	column.add_child(_list)
	var again := Button.new()
	again.text = "Re-read the folder"
	again.tooltip_text = ("The catalogue is the `effects/` folder, so a file "
		+ "dropped there while this is open appears on a press.")
	again.pressed.connect(_refresh_catalogue)
	column.add_child(again)
	return panel


func _build_stage() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)

	var top := HSplitContainer.new()
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.split_offset = -300
	column.add_child(top)

	# The preview, and the strip under it.
	var stage := PanelContainer.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 8)
	stage.add_child(inside)
	_why = SkinScript.quiet("Pick an effect.")
	inside.add_child(_why)
	_player = SheetPlayerScript.new()
	_player.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_player.custom_minimum_size = Vector2(0.0, 240.0)
	_player.frame_changed.connect(_on_frame)
	inside.add_child(_player)
	inside.add_child(_build_transport())
	_strip = Control.new()
	_strip.custom_minimum_size = Vector2(0.0, 72.0)
	# **Clipped, and rebuilt when the width changes.** The strip lays one
	# `TextureRect` a cell in a box that does not shrink, so on a narrow stage
	# a twenty-four cell effect walks straight out of the panel and over the
	# controls beside it - which is what the first photograph showed.
	_strip.clip_contents = true
	_strip.resized.connect(_rebuild_strip)
	inside.add_child(_strip)
	top.add_child(stage)

	top.add_child(_build_controls())

	# The log, which is the Blender half talking.
	var foot := PanelContainer.new()
	var foot_column := VBoxContainer.new()
	foot_column.add_theme_constant_override("separation", 6)
	foot.add_child(foot_column)
	foot_column.add_child(SkinScript.title("The forge says", 15))
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0.0, 116.0)
	_log.scroll_following = true
	_log.bbcode_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 12)
	foot_column.add_child(_log)
	column.add_child(foot)
	return column


func _build_transport() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_play = Button.new()
	_play.text = "Pause"
	_play.custom_minimum_size = Vector2(74.0, 0.0)
	_play.pressed.connect(func() -> void:
		_player.playing = not _player.playing
		_play.text = "Pause" if _player.playing else "Play")
	row.add_child(_play)

	var again := Button.new()
	again.text = "Restart"
	again.pressed.connect(func() -> void:
		_player.restart()
		_play.text = "Pause")
	row.add_child(again)

	_scrub = HSlider.new()
	_scrub.min_value = 0
	_scrub.max_value = 15
	_scrub.step = 1
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.value_changed.connect(func(to: float) -> void:
		if not _player.playing:
			_player.scrub_to(int(to))
		elif absf(to - float(_player.current_frame())) > 1.5:
			_player.scrub_to(int(to))
			_play.text = "Play")
	row.add_child(_scrub)

	_tint_pick = OptionButton.new()
	for entry: Dictionary in TINTS:
		_tint_pick.add_item(String(entry["name"]))
	_tint_pick.selected = 0
	_tint_pick.tooltip_text = ("A sheet is white on transparent and the game "
		+ "tints it once per use, so it is judged under a colour rather than "
		+ "in the grey it was rendered in.")
	_tint_pick.item_selected.connect(func(index: int) -> void:
		_player.tint = TINTS[index]["colour"]
		_rebuild_strip())
	row.add_child(_tint_pick)

	var ground := Button.new()
	ground.text = "Ground"
	ground.tooltip_text = "A bright effect on a black plate always looks good."
	ground.pressed.connect(func() -> void: _player.ground += 1)
	row.add_child(ground)

	var grid := CheckBox.new()
	grid.text = "Cell"
	grid.tooltip_text = "The cell's own edges and its middle."
	grid.toggled.connect(func(on: bool) -> void: _player.show_grid = on)
	row.add_child(grid)

	var out := Button.new()
	out.text = "-"
	out.custom_minimum_size = Vector2(32.0, 0.0)
	out.pressed.connect(func() -> void: _player.zoom -= 0.5)
	row.add_child(out)
	var into := Button.new()
	into.text = "+"
	into.custom_minimum_size = Vector2(32.0, 0.0)
	into.pressed.connect(func() -> void: _player.zoom += 0.5)
	row.add_child(into)
	return row


func _build_controls() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(270.0, 0.0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(SkinScript.title("Render", 17))

	_frames = _number(column, "Frames", 2, 64, 16)
	_size = _number(column, "Cell pixels", 16, 256, 96)
	_takes = _number(column, "Takes", 1, 8, 3)
	_takes.tooltip_text = ("Each take moves where the noise is sampled, so it "
		+ "is the same effect frayed somewhere else rather than a recolour. "
		+ "The game picks one at random, flips it and turns it.")

	_render = Button.new()
	_render.text = "Render this effect"
	_render.pressed.connect(_do_render)
	column.add_child(_render)

	_render_all = Button.new()
	_render_all.text = "Render every effect"
	_render_all.tooltip_text = "Long. The log says which one it is on."
	_render_all.pressed.connect(_do_render_all)
	column.add_child(_render_all)

	var stop := Button.new()
	stop.text = "Stop"
	stop.pressed.connect(func() -> void:
		_runner.stop()
		_say("Stopped.", SkinScript.DANGER)
		_set_busy(false))
	column.add_child(stop)

	column.add_child(_rule())
	column.add_child(SkinScript.title("Look at", 17))
	_take_pick = OptionButton.new()
	_take_pick.tooltip_text = "Which take of this effect to play."
	_take_pick.item_selected.connect(func(_i: int) -> void: _load_sheet())
	column.add_child(_take_pick)

	var reload := Button.new()
	reload.text = "Reload from disk"
	reload.pressed.connect(_load_sheet)
	column.add_child(reload)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(SkinScript.quiet(
		"A sheet is allowed only where the effect's size is fixed "
		+ "decoration. A telegraph is drawn at the blow's own radius and "
		+ "stays procedural - VFX_FORGE.md section 3."))
	return panel


func _number(into: Control, label: String, low: int, high: int, now: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_label: Label = SkinScript.line(label, 14)
	name_label.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(name_label)
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.value = now
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	into.add_child(row)
	return box


func _rule() -> Control:
	var line := ColorRect.new()
	line.color = SkinScript.shade(0.5)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	return line


# --- The catalogue -----------------------------------------------------------

func _refresh_catalogue() -> void:
	_catalogue = _runner.catalogue()
	_list.clear()
	for row: Variant in _catalogue:
		var spec := row as Dictionary
		_list.add_item(String(spec.get("id", "?")))
	if _catalogue.is_empty():
		_say("The forge listed nothing. Check the paths.", SkinScript.DANGER)
		return
	_list.select(0)
	_on_chosen(0)


func _on_chosen(index: int) -> void:
	if index < 0 or index >= _catalogue.size():
		return
	var spec := _catalogue[index] as Dictionary
	_chosen = String(spec.get("id", ""))
	_frames.value = int(spec.get("frames", 16))
	_size.value = int(spec.get("size", 96))
	_takes.value = int(spec.get("variants", 1))
	_why.text = "%s  -  %s" % [_chosen, String(spec.get("why", ""))]
	_fill_takes(int(spec.get("variants", 1)))
	_load_sheet()


## Only the takes that are on disk, so the list is what can be looked at
## rather than what was asked for.
func _fill_takes(most: int) -> void:
	_take_pick.clear()
	for take: int in maxi(most, 1) + 4:
		if FileAccess.file_exists(_sheet_path(take)):
			_take_pick.add_item("take %d" % take, take)
	if _take_pick.item_count == 0:
		_take_pick.add_item("not rendered yet", 0)
	_take_pick.selected = 0


func _sheet_path(take: int) -> String:
	var name: String = "forge_%s.png" % _chosen if take == 0 \
		else "forge_%s_%02d.png" % [_chosen, take]
	return _runner.repo.path_join("game/art/vfx").path_join(name)


func _load_sheet() -> void:
	if _chosen.is_empty():
		return
	var take: int = _take_pick.get_selected_id() if _take_pick.item_count > 0 else 0
	var path: String = _sheet_path(take)
	if not FileAccess.file_exists(path):
		_player.sheet = null
		_rebuild_strip()
		_say("%s has no sheet on disk yet." % _chosen, SkinScript.DANGER)
		return
	var image: Image = Image.load_from_file(path)
	if image == null:
		_say("Could not read %s." % path, SkinScript.DANGER)
		return
	_player.cells = maxi(image.get_width() / maxi(image.get_height(), 1), 1)
	_player.sheet = ImageTexture.create_from_image(image)
	_player.restart()
	_play.text = "Pause"
	_scrub.max_value = _player.cells - 1
	_rebuild_strip()
	_say("%s: %d cells of %dpx." % [_chosen, _player.cells, image.get_height()])


func _rebuild_strip() -> void:
	if _player == null or _strip == null:
		return
	_player.contact_strip(_strip, _strip.size.x if _strip.size.x > 16.0 else 600.0)


func _on_frame(frame: int, of: int) -> void:
	if _scrub != null and not _scrub.has_focus():
		_scrub.set_value_no_signal(float(frame))
	if _status != null and _player.playing:
		_say("%s  -  cell %d of %d" % [_chosen, frame + 1, of])


# --- Rendering ---------------------------------------------------------------

func _do_render() -> void:
	var wrong: String = _runner.complaint()
	if not wrong.is_empty():
		_say(wrong, SkinScript.DANGER)
		return
	if _chosen.is_empty():
		return
	_log.clear()
	_set_busy(true)
	_say("Rendering %s..." % _chosen)
	_runner.render(_chosen, int(_frames.value), int(_size.value), int(_takes.value))


func _do_render_all() -> void:
	var wrong: String = _runner.complaint()
	if not wrong.is_empty():
		_say(wrong, SkinScript.DANGER)
		return
	_log.clear()
	_set_busy(true)
	_say("Rendering every effect. This takes a while.")
	_runner.render_all(-1)


func _set_busy(busy: bool) -> void:
	_render.disabled = busy
	_render_all.disabled = busy


func _on_line(text: String) -> void:
	var colour: Color = SkinScript.INK
	if text.contains("FAIL") or text.contains("empty") or text.contains("Error"):
		colour = SkinScript.DANGER
	elif text.begins_with("forge:"):
		colour = SkinScript.GOOD
	_log.push_color(colour)
	_log.add_text(text + "\n")
	_log.pop()


func _on_finished(_code: int, ok: bool) -> void:
	_set_busy(false)
	if ok:
		_say("Done.", SkinScript.GOOD)
		_fill_takes(int(_takes.value))
		_load_sheet()
	else:
		_say("The render failed. The log says why.", SkinScript.DANGER)


func _say(text: String, colour: Color = SkinScript.INK) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override("font_color", colour)


# --- Where things are --------------------------------------------------------

func _open_paths() -> void:
	var window := AcceptDialog.new()
	window.title = "Where things are"
	window.theme = theme
	window.min_size = Vector2i(620, 240)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	window.add_child(column)
	column.add_child(SkinScript.quiet(
		"The repository is the folder holding `tools/vfx_forge`. Blender is "
		+ "the executable the Python half drives; the BLENDER variable is "
		+ "read first if it is set."))
	var repo: LineEdit = _path_row(column, "Repository", _runner.repo)
	var python: LineEdit = _path_row(column, "Python", _runner.python)
	var blender: LineEdit = _path_row(column, "Blender", _runner.blender)
	window.confirmed.connect(func() -> void:
		_runner.repo = repo.text.strip_edges()
		_runner.python = python.text.strip_edges()
		_runner.blender = blender.text.strip_edges()
		_runner.save()
		_refresh_catalogue()
		var wrong: String = _runner.complaint()
		_say(wrong if not wrong.is_empty() else "Saved.",
			SkinScript.DANGER if not wrong.is_empty() else SkinScript.GOOD))
	add_child(window)
	window.popup_centered()


func _path_row(into: Control, label: String, now: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label: Label = SkinScript.line(label, 14)
	name_label.custom_minimum_size = Vector2(90.0, 0.0)
	row.add_child(name_label)
	var edit := LineEdit.new()
	edit.text = now
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	into.add_child(row)
	return edit


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F11:
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif key.keycode == KEY_SPACE:
		_player.playing = not _player.playing
		_play.text = "Pause" if _player.playing else "Play"
	elif key.keycode == KEY_R and key.ctrl_pressed:
		_do_render()
