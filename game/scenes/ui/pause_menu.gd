class_name PauseMenu
extends CanvasLayer

## Pause overlay. Pauses the tree, so every scope stops together and nothing
## keeps ticking behind it.

@export var panel: Control
@export var resume_button: Button
@export var menu_button: Button

var _settings: SettingsPanel
var _settings_button: Button
## What a quit costs, said above the button that would do it. See
## `_on_menu_pressed`.
var _warning: Label
var _battlefield: Label
var _confirming: bool = false
var _menu_text: String = ""


func _ready() -> void:
	# Every plate, button and bar on this screen gets the standing animation
	# and the hover hologram (owner, 2026-09-17). **Deferred**, because a
	# screen builds its own children further down this same function -
	# enrolled here and now it would dress an empty `Control` and nothing else.
	UiJuice.enrol.call_deferred(get_tree(), self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Findable, so a partner's pause can raise this one too.
	add_to_group(&"pause_menu")
	panel.visible = false

	# An arrow for "carry on" and a cross for "leave". The obvious pairing - a
	# cross on Resume, meaning "close this menu" - puts the quit symbol on the
	# button that does not quit, directly above the one that does.
	IconKit.on_button(resume_button, "pressure_arrow", 24)
	IconKit.on_button(menu_button, "close", 24)
	_menu_text = menu_button.text

	_build_settings()
	_build_warning()
	_build_battlefield_line()
	# **Grown from the centre, and bounded by the screen.** Reported as the pause
	# menu sitting low and running off the bottom of a phone. `anchors_preset = 8`
	# in a `.tscn` writes the anchors and nothing else - the grow directions stay
	# at their default of `GROW_DIRECTION_END` - so once Settings joined Resume and
	# Abandon the panel needed more height than its authored 240 and took it all
	# downward from a fixed top edge. Only `set_anchors_preset()` in code sets the
	# grow directions, which is exactly what this does.
	UiMetrics.centre_panel(panel)
	get_viewport().size_changed.connect(func() -> void: UiMetrics.centre_panel(panel))
	resume_button.pressed.connect(toggle)
	menu_button.pressed.connect(_on_menu_pressed)


## **Leaving is said before it is done** (2026-09-21, roadmap §7.2: "a player
## who quits mid-act should be *told* what they will lose"). A road banks only
## when the party turns for home at a crossroad, so a quit from here abandons
## everything since that bank - and the button said "Abandon the road" without
## saying what the road was worth. The first press explains and becomes the
## confirmation; the second press leaves. Reopening the pause menu resets it,
## so a confirmation never waits silently for a later press.
func _on_menu_pressed() -> void:
	var cost: String = leaving_costs()
	if _confirming or cost.is_empty():
		_leave()
		return
	_confirming = true
	if _warning != null:
		_warning.text = cost
		_warning.visible = true
	menu_button.text = "Leave anyway"
	UiMetrics.centre_panel(panel)


func _leave() -> void:
	# Leaving unpauses the other player as well: quitting is not a reason to
	# leave somebody frozen on a battlefield they can no longer act on. The
	# session ending is what they are told about next.
	GameDirector.set_paused(false)
	Coop.leave()
	GameDirector.goto_menu()


func _reset_confirm() -> void:
	_confirming = false
	if _warning != null:
		_warning.visible = false
	if not _menu_text.is_empty():
		menu_button.text = _menu_text


## What a quit from here costs, as a sentence, or empty when it costs nothing.
##
## Static and pure over the run state, so `quit_warning_check` can ask it about
## roads nobody is standing on. A guest's road is the host's - nothing of
## theirs is banked or lost - and the Walk and an ended run cost nothing.
static func leaving_costs() -> String:
	if not GameDirector.run_active or RunState.walking \
			or RunState.phase == RunState.Phase.ENDED:
		return ""
	if Coop.is_guest():
		return ("The road is the host's to keep. Leaving costs you nothing "
			+ "banked, and the party plays on without you.")
	var here: String = "Act %d, wave %d" % [RunState.act, RunState.wave_number]
	var banked: Dictionary = MetaState.expedition
	if Expedition.is_readable(banked):
		var at: String = "Act %d, wave %d" % [int(banked.get("act", 1)),
			int(banked.get("wave", 1))]
		var same_road: bool = int(banked.get("seed", -1)) == RunState.run_seed
		var lost: int = RunState.wave_number - int(banked.get("wave", 1))
		if same_road and lost > 0:
			return ("Leaving now loses %d wave%s of road since you last turned "
				% [lost, "" if lost == 1 else "s"]
				+ "for home at %s. Resume will start there, not at %s." % [at, here])
		return ("Your road is banked at %s. Leaving loses whatever has happened "
			% at + "since that crossroad.")
	return ("Nothing of this road is banked. Leaving now loses all of it - %s, "
		% here + "and everything built. Turn for home at a crossroad to bank a "
		+ "road before you stop.")


## Which battlefield this road is laid on, above the buttons.
##
## Random settles on a layout when the road begins and says so nowhere else, and
## a banked road keeps the map it was banked on whatever the setting says now -
## so without this a player testing layouts cannot tell which one they are on.
func _build_battlefield_line() -> void:
	_battlefield = Label.new()
	_battlefield.name = "BattlefieldLine"
	_battlefield.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_battlefield.add_theme_font_size_override("font_size", 14)
	_battlefield.modulate = Color(1.0, 1.0, 1.0, 0.75)
	var box: Node = resume_button.get_parent()
	box.add_child(_battlefield)
	box.move_child(_battlefield, resume_button.get_index())
	_say_the_battlefield()


func _say_the_battlefield() -> void:
	if _battlefield == null:
		return
	_battlefield.text = battlefield_line()


## The words, pure over the run: "Battlefield: Keep", and "varied" when Random
## rolled its proportions.
static func battlefield_line() -> String:
	var line: String = "Battlefield: %s" % MapModes.label_of(RunState.map_mode)
	if RunState.map_varied:
		line += "  ·  varied"
	return line


## The line above the leave button, hidden until a press asks for it. A Label
## rather than a dialog, so the answer stands where the question was asked.
func _build_warning() -> void:
	_warning = Label.new()
	_warning.name = "LeaveWarning"
	_warning.visible = false
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size = Vector2(340.0, 0.0)
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.add_theme_font_size_override("font_size", 14)
	_warning.add_theme_color_override("font_color", Color("e8a33d"))
	var box: Node = menu_button.get_parent()
	box.add_child(_warning)
	box.move_child(_warning, menu_button.get_index())


## Settings reachable from the pause screen, not only from the title.
##
## This is the case that actually matters. Without it the only route to the
## volume sliders was to abandon the run and go back to the main menu, which
## nobody does — they alt-tab and mute the game at the OS instead, which throws
## away the entire soundtrack and mix to fix one slider being too loud.
func _build_settings() -> void:
	var dim := ColorRect.new()
	dim.name = "SettingsDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.02, 0.022, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	panel.get_parent().add_child(dim)
	_settings = SettingsPanel.new()
	_settings.set_anchors_preset(Control.PRESET_CENTER)
	_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings.visible = false
	_settings.closed.connect(func() -> void: _show_settings(false))
	# On the pause layer, so it is above the paused world like the panel is.
	panel.get_parent().add_child(_settings)

	# Inserted above "Abandon the road", so the destructive option stays last.
	_settings_button = Button.new()
	_settings_button.text = "Settings"
	_settings_button.custom_minimum_size = Vector2(320.0, 48.0)
	IconKit.on_button(_settings_button, "settings", 24)
	_settings_button.pressed.connect(func() -> void: _show_settings(true))
	var box: Node = menu_button.get_parent()
	box.add_child(_settings_button)
	box.move_child(_settings_button, menu_button.get_index())


func _show_settings(showing: bool) -> void:
	_settings.visible = showing
	var dim: ColorRect = panel.get_parent().get_node_or_null("SettingsDim") as ColorRect
	if dim != null:
		dim.visible = showing
	# The pause panel steps aside rather than stacking: two panels overlapping in
	# the middle of the screen is unreadable, and the pause menu has nothing on it
	# worth seeing while the settings are open.
	panel.visible = not showing
	if not showing and _settings_button != null:
		_settings_button.grab_focus()


func toggle() -> void:
	if _settings != null and _settings.visible:
		# Escape out of settings first, rather than unpausing straight into the
		# game from a screen the player is still reading.
		_show_settings(false)
		return
	var showing: bool = not panel.visible
	if showing:
		_say_the_battlefield()
	set_showing(showing)
	# Through GameDirector, which tells the other player. Setting the tree
	# directly pauses one machine while the other keeps fighting a wave that is
	# still walking on a battlefield which has stopped simulating it.
	GameDirector.set_paused(showing)


## Shows or hides the panel without touching the paused state.
##
## **The panel is shared**, which reverses an earlier call of mine. I had kept it
## local on the reasoning that a player reading the settings has not asked their
## friend to read them too - but a game that stops with no visible cause is worse
## than a menu you did not open, and either player being able to *resume* means
## both need something to resume from. Owner's decision, 2026-08-25.
func set_showing(showing: bool) -> void:
	panel.visible = showing
	_reset_confirm()
	# Re-measured on every open. The settings button is added at runtime and the
	# touch pass can grow all three, so the panel this centres is not the one the
	# scene file described.
	if showing:
		UiMetrics.centre_panel(panel)
	if showing or _settings == null:
		return
	# Resuming closes the settings behind it, and the dim with them - otherwise a
	# partner's resume leaves this screen dimmed with nothing on it.
	_settings.visible = false
	var dim: ColorRect = panel.get_parent().get_node_or_null("SettingsDim") as ColorRect
	if dim != null:
		dim.visible = false
