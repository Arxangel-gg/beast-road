extends Node

## Renders the portent cards, so the fit and the deal can be looked at.
##
##   godot --path game res://tools/portent_shot.tscn
##
## Diagnostic only, never a gate. `layout_check` measures that the words stay
## inside the cards, that the three are one height, that the row is centred and
## that every card is on the screen; it cannot see whether the cards read as a
## hand a person chooses from. Dealt the three portents with the most to say,
## the middle one hovered, after the deal has settled.

func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that edits
	# the account must never be able to write it to the player's disk.
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 14:
		await get_tree().process_frame
	var wordy: Array = []
	for value: Variant in ContentDB.omens.values():
		var omen := value as OmenData
		if omen != null:
			wordy.append(omen)
	wordy.sort_custom(func(a: OmenData, b: OmenData) -> bool:
		return (a.bane_text + a.boon_text + a.portent).length() \
			> (b.bane_text + b.boon_text + b.portent).length())
	RunState.pending_omens.clear()
	for index: int in mini(3, wordy.size()):
		RunState.pending_omens.append((wordy[index] as OmenData).id)
	var screen: CrossroadScreen = run.crossroad_ui
	screen.open_omen_choice()
	await get_tree().create_timer(1.4).timeout
	var cards: Array[Control] = []
	for node: Node in screen.call("_entrance_cards"):
		var card := node as Control
		if card != null and CrossroadScreen.play_face(card) != null:
			cards.append(card)
	if cards.size() >= 2:
		cards[1].mouse_entered.emit()
	await get_tree().create_timer(0.4).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://portent_shot.png")
	print("[portent] shot -> %s" % ProjectSettings.globalize_path("user://portent_shot.png"))
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(0)
