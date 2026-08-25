class_name MainMenu
extends Control

const LeaderboardScreenScript = preload("res://scenes/ui/leaderboard_screen.gd")
const CoopScreenScript = preload("res://scenes/ui/coop_screen.gd")

## The front door. Shows what the unlock pool has grown to, because that is the
## only thing that persists between runs (GDD §10) and it should be visible.

@export var new_run_button: Button
@export var settings_button: Button
@export var quit_button: Button
@export var stats_label: Label
@export var seed_input: LineEdit



var _settings: SettingsPanel
var _leaderboard: CanvasLayer
var _coop: CanvasLayer


func _ready() -> void:
	MusicPlayer.play("menu")
	new_run_button.pressed.connect(_start_run)
	quit_button.pressed.connect(GameDirector.quit_game)
	seed_input.text_submitted.connect(func(_value: String) -> void: _start_run())

	# All three carry an icon, which also left-aligns them. Without one on the
	# first button its label stayed centred while the two below it were not, and a
	# menu column with one odd row out reads as a mistake before it reads as a
	# menu. The arrow means the same here as on the pause screen: carry on.
	IconKit.on_button(new_run_button, "pressure_arrow", 26)
	IconKit.on_button(settings_button, "settings", 24)
	IconKit.on_button(quit_button, "close", 24)

	_build_tier_row()
	_build_stash_button()
	_build_endless_button()
	_build_coop_button()
	_build_leaderboard_button()
	_build_settings()
	settings_button.pressed.connect(func() -> void: _show_settings(true))

	stats_label.text = _summary()
	new_run_button.grab_focus()
	_setup_stage()


## Swaps the still key art for the living one.
##
## The authored `Art` node stays in the scene and is emptied rather than freed.
## It is what the scene file's NodePath points at, and a menu that deletes its
## own exported node is a menu that breaks the next time someone opens the scene
## — which is exactly the failure `menu_check` exists to catch.
func _setup_stage() -> void:
	var art: TextureRect = get_node_or_null("Art") as TextureRect
	if art == null:
		return
	art.texture = null

	var stage := MenuStage.new()
	stage.name = "Stage"
	# Directly after the art it replaces, so it is under the logo, the buttons
	# and the statistics line and over nothing else.
	art.add_sibling(stage)
	move_child(stage, art.get_index() + 1)


## The stash, reached from the menu rather than from a run.
##
## Only once there is something in it. A button leading to an empty screen on a
## first launch is a promise the game has not made yet, and the first gear a
## player finds announces itself anyway.
func _build_stash_button() -> void:
	if MetaState.stash.is_empty() and MetaState.marks <= 0 and MetaState.shards <= 0:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.text = "Stash  ·  %d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]
	IconKit.on_button(button, "relic", 24)
	column.add_child(button)
	column.move_child(button, new_run_button.get_index() + 1)

	var screen := StashScreen.new()
	add_child(screen)
	screen.closed.connect(func() -> void:
		button.text = "Stash  ·  %d Marks  ·  %d Shards" % [MetaState.marks, MetaState.shards]
		new_run_button.grab_focus())
	button.pressed.connect(func() -> void: screen.open())


## The campaign tier, chosen before a run and shown with the hero it will be
## played by.
##
## Built here rather than in the scene because which tiers exist is an account
## question: a locked tier is not drawn at all. A row of greyed-out buttons
## advertises content a new player cannot have and reads as a paywall.
func _build_tier_row() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return

	var hero := Label.new()
	hero.text = "Warden  ·  level %d" % MetaState.hero_level
	if MetaState.hero_attribute_points > 0:
		hero.text += "  ·  %d unspent" % MetaState.hero_attribute_points
	hero.add_theme_font_size_override("font_size", 15)
	hero.add_theme_color_override("font_color", Color("b8ae98"))
	column.add_child(hero)
	column.move_child(hero, new_run_button.get_index())

	var unlocked: Array[CampaignTierData] = []
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		if MetaState.tier_is_unlocked(tier):
			unlocked.append(tier)
	if unlocked.size() <= 1:
		# One tier open is not a choice, and a picker with one entry is furniture.
		if not unlocked.is_empty():
			MetaState.last_tier_id = unlocked[0].id
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for tier: CampaignTierData in unlocked:
		var button := Button.new()
		button.toggle_mode = true
		button.text = tier.display_name
		button.tooltip_text = "%s
Expects level %s at its act bosses." % [
			tier.summary, str(tier.boss_levels)]
		button.button_pressed = tier.id == MetaState.last_tier_id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			MetaState.last_tier_id = tier.id
			MetaState.save_game()
			for other: Node in row.get_children():
				(other as Button).button_pressed = (other as Button).text == tier.display_name)
		row.add_child(button)
	column.add_child(row)
	column.move_child(row, new_run_button.get_index())


## Endless is earned by finishing, so the button only exists once the summit has
## been reached. Built here rather than in the scene because it is conditional:
## a permanent button that says "locked" is a worse front door than one that
## arrives when it means something.
func _build_endless_button() -> void:
	if not MetaState.act3_cleared or new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Endless"
	button.text = "Endless road"
	button.tooltip_text = "The same three acts, escalating from the first wave, and no finish line."
	button.custom_minimum_size = new_run_button.custom_minimum_size
	button.theme_type_variation = new_run_button.theme_type_variation
	column.add_child(button)
	column.move_child(button, new_run_button.get_index() + 1)
	IconKit.on_button(button, "pressure_arrow", 26)
	button.pressed.connect(func() -> void: _start_run(true))


## The shared board is always reachable. With no network it becomes this save's
## personal-best list, so the button never opens a dead screen.
## Co-op, on the front door.
##
## Directly under the button that starts a single-player run, because that is
## where a player looks for "the other way to play" and because co-op is a
## separate mode rather than a setting on this one.
##
## Its absence was the whole of "multiplayer is not fully integrated": every
## piece underneath worked and was gated across two real processes, and none of
## it could be reached by anyone playing the game.
func _build_coop_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Coop"
	button.text = "Co-op"
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "pressure_arrow", 26)
	column.add_child(button)
	# Immediately below "New run", not at the bottom with the utilities.
	column.move_child(button, new_run_button.get_index() + 1)

	_coop = CoopScreenScript.new()
	add_child(_coop)
	_coop.closed.connect(func() -> void: button.grab_focus())
	button.pressed.connect(func() -> void: _coop.open())


func _build_leaderboard_button() -> void:
	if new_run_button == null:
		return
	var column: Node = new_run_button.get_parent()
	if column == null:
		return
	var button := Button.new()
	button.name = "Leaderboard"
	button.text = "Leaderboard"
	button.custom_minimum_size = settings_button.custom_minimum_size
	button.theme_type_variation = settings_button.theme_type_variation
	IconKit.on_button(button, "distance", 24)
	column.add_child(button)
	column.move_child(button, settings_button.get_index())

	_leaderboard = LeaderboardScreenScript.new()
	add_child(_leaderboard)
	_leaderboard.closed.connect(func() -> void: button.grab_focus())
	button.pressed.connect(func() -> void: _leaderboard.open())


func _start_run(endless: bool = false) -> void:
	var requested: int = 0
	var entered: String = seed_input.text.strip_edges()
	if not entered.is_empty():
		if not entered.is_valid_int() or int(entered) <= 0:
			seed_input.text = ""
			seed_input.placeholder_text = "Use 1–999999999"
			seed_input.grab_focus()
			return
		requested = clampi(int(entered), 1, RunState.RNG_MAX_SEED)
	GameDirector.start_run(requested, endless)


## The panel is the shared component, centred over the key art. The menu used to
## hand-roll its own settings box in the scene file, which is how it ended up
## offering exactly one setting while three volume sliders sat unreachable in the
## save file.
func _build_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.set_anchors_preset(Control.PRESET_CENTER)
	_settings.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings.grow_vertical = Control.GROW_DIRECTION_BOTH
	_settings.visible = false
	_settings.closed.connect(func() -> void: _show_settings(false))
	add_child(_settings)


func _show_settings(showing: bool) -> void:
	_settings.visible = showing
	if not showing:
		settings_button.grab_focus()


func _summary() -> String:
	return "\n".join([
		"Runs   %d started   ·   %d reached the sanctuary" % [MetaState.runs_started, MetaState.runs_won],
		"Furthest   %d of %d" % [int(MetaState.best_distance), int(Balance.JOURNEY_TOTAL_DISTANCE)],
		"Unlocked   %d towers   ·   %d relics   ·   %d lands" % [
			MetaState.unlocked_towers.size(),
			MetaState.unlocked_relics.size(),
			MetaState.unlocked_terrains.size()],
	])
