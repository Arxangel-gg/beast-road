extends Node

const LeaderboardScreenScript = preload("res://scenes/ui/leaderboard_screen.gd")
const ChronicleScreenScript = preload("res://scenes/ui/chronicle_screen.gd")

## Boots the real main menu, so a scene edit cannot break the front door
## silently. The settings box used to be authored into main_menu.tscn; removing
## it in favour of the shared component is exactly the change that would leave a
## dangling NodePath and only fail on someone else's machine.

func _ready() -> void:
	var packed: PackedScene = load("res://scenes/ui/main_menu.tscn")
	var menu: Control = packed.instantiate() as Control
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var panels: int = 0
	var boards: int = 0
	var board_buttons: int = 0
	var endless_buttons: int = 0
	var chronicles: int = 0
	var chronicle_buttons: int = 0
	var stage: MenuStage = null
	for node: Node in _all(menu):
		if node is MenuStage:
			stage = node as MenuStage
		if node is SettingsPanel:
			panels += 1
		if node.get_script() == LeaderboardScreenScript:
			boards += 1
		if node is Button and node.name == "Leaderboard":
			board_buttons += 1
		if node is Button and (node.name == "Endless" \
				or (node as Button).text.to_lower().contains("endless")):
			endless_buttons += 1
		if node.get_script() == ChronicleScreenScript:
			chronicles += 1
		if node is Button and node.name == "Chronicle":
			chronicle_buttons += 1
	print("[menu] instantiated ok, settings=%d, boards=%d/%d, chronicle=%d/%d, endless=%d"
		% [panels, boards, board_buttons, chronicles, chronicle_buttons, endless_buttons])
	if panels != 1:
		push_error("main menu should own exactly one SettingsPanel")
		get_tree().quit(1)
		return
	if boards != 1 or board_buttons != 1:
		push_error("main menu should own exactly one leaderboard screen and button")
		get_tree().quit(1)
		return
	if chronicles != 1 or chronicle_buttons != 1:
		push_error("main menu should own exactly one Chronicle screen and button")
		get_tree().quit(1)
		return
	if endless_buttons != 0:
		push_error("GDD §54 cuts Endless from 1.0; the main menu must not expose it")
		get_tree().quit(1)
		return
	# Every long menu surface shares one interaction contract. This catches the
	# co-op regression where the content technically scrolled but the only
	# discoverable input was a mouse wheel.
	var scroll_count: int = 0
	for node: Node in _all(menu):
		if not node is ScrollContainer:
			continue
		scroll_count += 1
		var scroll := node as ScrollContainer
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO \
				or not scroll.follow_focus or scroll.focus_mode != Control.FOCUS_ALL:
			push_error("every menu scroll surface must support drag and focus-follow")
			get_tree().quit(1)
			return
		if bar == null or bar.focus_mode != Control.FOCUS_ALL \
				or bar.custom_minimum_size.x < Balance.UI_SCROLLBAR_WIDTH:
			push_error("every menu scroll surface must expose a focusable draggable rail")
			get_tree().quit(1)
			return
	if scroll_count < 6:
		push_error("expected the co-op, settings and account screens to expose scroll rails")
		get_tree().quit(1)
		return
	var coop_screen: CanvasLayer = menu.get("_coop") as CanvasLayer
	var coop_root: Control = null
	if coop_screen != null:
		coop_root = coop_screen.get("_root") as Control
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var expected_coop_height: float = minf(Balance.COOP_PANEL_VIEW_HEIGHT,
		maxf(Balance.COOP_PANEL_MIN_VIEW_HEIGHT,
			viewport_height - Balance.COOP_PANEL_EDGE_MARGIN * 2.0))
	if coop_root == null or absf(coop_root.size.y - expected_coop_height) > 1.0:
		push_error("the co-op panel must shrink into the viewport before its body scrolls")
		get_tree().quit(1)
		return
	var scroll_style: StyleBox = menu.get_theme_stylebox("scroll", "VScrollBar")
	var pressed_style: StyleBox = menu.get_theme_stylebox("grabber_pressed", "VScrollBar")
	if scroll_style.get_minimum_size().x < 16.0 \
			or pressed_style.get_minimum_size().y < 20.0:
		push_error("the shared scrollbar theme must retain its visible rail and grabber")
		get_tree().quit(1)
		return
	print("[menu] %d scroll surfaces have visible drag, touch and focus paths" % scroll_count)
	if stage == null or stage._beast == null:
		push_error("main menu must own its living beast stage")
		get_tree().quit(1)
		return
	var expected_tint: Color = stage._sampled_beast_tint()
	var actual_tint: Color = stage._beast.modulate
	if _colour_error(actual_tint, expected_tint) > 0.002:
		push_error("menu beast must inherit the sampled gate lighting tint")
		get_tree().quit(1)
		return
	var drawn_height: float = float(stage._baseline) * stage._beast.scale.y
	# MenuStage deliberately lays out from the viewport, not its inherited
	# Control rect; the latter can still be settling during a headless scene boot.
	var expected_height: float = stage._span().y * MenuStage.BEAST_HEIGHT
	if absf(drawn_height - expected_height) > 1.0:
		push_error("menu beast must retain its authored dominant scale")
		get_tree().quit(1)
		return
	# Let the instantiated menu release its nodes before shutting down. Quitting
	# on the same frame turns a healthy gate into a wall of false-positive
	# ObjectDB warnings, and a gate that cries wolf gets ignored. The menu starts
	# the title music on ready, so the audio autoloads have to be stopped too -
	# the dummy driver releases decoder playbacks asynchronously.
	if OS.get_cmdline_user_args().has("--shot"):
		# Only when asked. The gate runs headless in CI, where there is no
		# framebuffer to capture and asking for one is an error, not a picture.
		if OS.get_cmdline_user_args().has("--short"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(960, 540))
		elif OS.get_cmdline_user_args().has("--compact"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280, 720))
		if OS.get_cmdline_user_args().has("--settings"):
			menu.call("_show_settings", true)
		elif OS.get_cmdline_user_args().has("--coop"):
			var coop: CanvasLayer = menu.get("_coop") as CanvasLayer
			if coop != null:
				# A visual capture needs the built screen, not live network polling.
				coop.visible = true
		elif OS.get_cmdline_user_args().has("--chronicle"):
			for node: Node in _all(menu):
				if node.get_script() == ChronicleScreenScript:
					node.call("open")
					break
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png("user://menu_shot.png")
		print("[menu] shot -> user://menu_shot.png")

	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	menu.queue_free()
	for _frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(0)

func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found


func _colour_error(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)),
		maxf(absf(a.b - b.b), absf(a.a - b.a)))
