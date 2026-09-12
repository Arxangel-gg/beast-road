extends Node

## Every script in the project compiles.
##
## `--quit` does not prove that. The boot compiles the autoloads and whatever
## the main scene reaches, and nothing else: a parse error in a screen the
## menu has not opened yet, or in a tool nobody ran, sits there until a player
## reaches it. Running Godot with `--script` does not prove it either - that
## replaces the main loop, so no autoload exists and every script that names
## one fails for the wrong reason.
##
## So this is a scene, under the real autoloads, that loads every `.gd` under
## `res://` and asks each whether it can be instantiated. A script that failed
## to compile cannot, and the engine prints the actual error as it loads.

const SKIP_PREFIXES: Array[String] = ["res://addons/", "res://.godot/"]

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	_walk("res://")
	for _frame: int in 3:
		await get_tree().process_frame
	if _failures > 0:
		push_error("[script-check] FAIL - %d of %d scripts do not compile" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[script-check] PASS - %d scripts compile" % _checked)
	get_tree().quit(0)


func _walk(dir_path: String) -> void:
	for prefix: String in SKIP_PREFIXES:
		if dir_path.begins_with(prefix):
			return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var path: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_walk(path)
		elif name.ends_with(".gd"):
			_check_script(path)
		name = dir.get_next()
	dir.list_dir_end()


func _check_script(path: String) -> void:
	_checked += 1
	var script: GDScript = load(path) as GDScript
	if script == null:
		push_error("[script-check] %s did not load" % path)
		_failures += 1
		return
	if not script.can_instantiate():
		# The engine has already printed the parse or compile error above.
		push_error("[script-check] %s does not compile" % path)
		_failures += 1
