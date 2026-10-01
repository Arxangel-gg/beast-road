extends Node

## Photographs a screen as a phone sees it (2026-10-01): the touch layout on,
## at whatever window size the runner gives, every screen `mobile_fit_check`
## measures one photograph each - or the ones named.
##
##   godot --path game res://tools/mobile_shot.tscn -- --screens=WardenGlass,StashScreen
##
## Windowed, because a headless display has no pixels; run it through the
## off-screen runner at a phone's size. Diagnostic only: `mobile_fit_check`
## holds the rectangles, and cannot see whether the screen is any good to look
## at on a phone.

var _screens: Dictionary = {
	"ActStartScreen": ActStartScreen,
	"ChronicleScreen": ChronicleScreen,
	"CodexScreen": CodexScreen,
	"ComfortCard": ComfortCard,
	"DisciplinesScreen": DisciplinesScreen,
	"ExchangeScreen": ExchangeScreen,
	"GuideScreen": GuideScreen,
	"LeaderboardScreen": LeaderboardScreen,
	"PenScreen": PenScreen,
	"SaveSlotScreen": SaveSlotScreen,
	"WardenGlass": WardenGlass,
	"SmithyScreen": SmithyScreen,
	"StableScreen": StableScreen,
	"StashScreen": StashScreen,
	"VendorScreen": VendorScreen,
	"WaysideCard": WaysideCard,
}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[mobile-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--viewport="):
			var dimensions: PackedStringArray = argument.trim_prefix("--viewport=").split("x")
			if dimensions.size() == 2:
				get_window().mode = Window.MODE_WINDOWED
				get_window().size = Vector2i(dimensions[0].to_int(), dimensions[1].to_int())
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	TouchInput.refresh()
	# The canvas the menu hands these screens, as `mobile_fit_check` measures.
	ScreenFit.set_menu_layout(true)
	var wanted: PackedStringArray = PackedStringArray(_screens.keys())
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--screens="):
			wanted = argument.trim_prefix("--screens=").split(",")
	RunState.reset()
	RunState.gain_every_currency(500)
	# Some gear, so the stash is photographed as a player sees it rather than empty.
	var kinds: Array = ContentDB.gear_kinds.keys()
	for index: int in 12:
		MetaState.stash.append(Stash.make(String(kinds[index % kinds.size()]), index % 4, 1))
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.12, 0.14, 0.13)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	for _f: int in 6:
		await get_tree().process_frame
	for label: String in wanted:
		if not _screens.has(label):
			continue
		var screen: Node = (_screens[label] as GDScript).new()
		add_child(screen)
		await get_tree().process_frame
		if screen.has_method("open"):
			screen.call("open")
		var waited: float = 0.0
		while waited < 1.2:
			await get_tree().process_frame
			waited += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "user://mobile_%s_%dx%d.png" % [label, get_window().size.x, get_window().size.y]
		image.save_png(path)
		print("[mobile-shot] -> ", ProjectSettings.globalize_path(path))
		screen.queue_free()
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)
