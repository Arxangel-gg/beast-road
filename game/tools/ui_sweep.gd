extends Node

## Screenshots every UI screen in one run.
##
## "Fix all the padding" is not a thing that can be done by reading code. Half
## these screens are only reachable after a forty-minute run — the results screen
## needs a death, the crossroad needs 300 distance — so in practice nobody has
## ever looked at them since they were written, and a padding fault there lives
## forever.
##
## This instantiates each one directly, feeds it plausible data, and saves a
## frame. Run it, look at seven pictures, fix what is wrong.
##
##   godot --path game res://tools/ui_sweep.tscn

const DEFAULT_SHOTS: String = "user://ui_sweep"

var _index: int = 0
var _screens: Array[Dictionary] = []
var _current: Node = null
var _shots_dir: String = DEFAULT_SHOTS


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_shots_dir = argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots_dir))
	_screens = [
		{"name": "main_menu", "make": _main_menu},
		{"name": "settings", "make": _settings},
		{"name": "crossroad", "make": _crossroad},
		{"name": "results_win", "make": _results.bind(true)},
		{"name": "results_loss", "make": _results.bind(false)},
	]
	_run.call_deferred()


func _run() -> void:
	for screen: Dictionary in _screens:
		_current = (screen["make"] as Callable).call()
		if _current == null:
			print("[sweep] %s SKIPPED" % screen["name"])
			continue
		add_child(_current)
		# Two frames: one to enter the tree and one for the containers to settle.
		# Capturing on the first gives every panel its pre-layout size, which is
		# usually zero and always a lie.
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var image: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/%s.png" % [_shots_dir, screen["name"]]
		var error: Error = image.save_png(path)
		if error != OK:
			push_error("[sweep] could not save %s (error %d)" % [path, error])
			get_tree().quit(1)
			return
		print("[sweep] %s -> %s" % [screen["name"], ProjectSettings.globalize_path(path)])

		_current.queue_free()
		_current = null
		await get_tree().process_frame

	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(0)


func _main_menu() -> Node:
	return load("res://scenes/ui/main_menu.tscn").instantiate()


## The settings panel over the menu, which is where it is actually seen.
func _settings() -> Node:
	var menu: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
	menu.ready.connect(func() -> void: menu.call("_show_settings", true), CONNECT_ONE_SHOT)
	return menu


func _crossroad() -> Node:
	var screen: Node = load("res://scenes/ui/crossroad_screen.tscn").instantiate()
	screen.ready.connect(func() -> void: screen.call("open", 4), CONNECT_ONE_SHOT)
	return screen


## Plausible numbers, not zeroes. A results screen full of "0" hides every
## alignment problem the real one will have.
func _results(victory: bool) -> Node:
	var screen: Node = load("res://scenes/ui/results_screen.tscn").instantiate()
	var summary: Dictionary = {
		"distance": 2700.0 if victory else 1486.0,
		"act": 3 if victory else 2,
		"time": 2734,
		"planning_time": 566,
		"kills": 1841,
		"deaths": 4,
		"raids": 6,
		"chieftains": 3,
		"town_damage": 742.0,
		"town_hits": 28,
		"peak_pressure": 0.86,
		"towers_built": 21,
		"tower_upgrades": 34,
		"towers_lost": 5,
		"towers_sold": 2,
		"resources_earned": 9840,
		"resources_spent": 9120,
		"most_common_wave": "siege_column",
		"command_earned": 436,
		"command_orders": {"overdrive": 7, "rally_road": 3, "last_stand": 1},
		"wounds": 2,
		"hearthmends": 1,
		"unlocks": [
			"tower:Deep Freeze", "relic:Ashen Sigil", "spell:Rift Step",
			"terrain:The Saltglass Flats",
		],
	}
	screen.ready.connect(func() -> void:
		screen.call("show_results", victory, summary), CONNECT_ONE_SHOT)
	return screen
