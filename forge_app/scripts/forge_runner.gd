class_name ForgeRunner
extends Node

## Runs `tools/vfx_forge/forge.py` without freezing the window.
##
## **Not `OS.execute`.** That blocks until Blender exits, which for a
## four-take render is a minute of a frozen app and no way to see how far it
## has got. `OS.create_process` does not block and does not capture output
## either, so the command is wrapped in a shell that redirects to a file and
## the file is tailed - which is also what gives a live log rather than a
## wall of text at the end.
##
## The paths are asked of the machine once and then remembered, because a
## tool that cannot find Blender should say so on the first screen rather
## than after somebody presses Render.

signal line_written(text: String)
signal finished(code: int, ok: bool)

const SETTINGS: String = "user://forge_app.json"

var repo: String = ""
var python: String = "python"
var blender: String = ""

var _pid: int = -1
var _log: String = ""
var _read: int = 0
var _poll: Timer = null


func _ready() -> void:
	_poll = Timer.new()
	_poll.wait_time = 0.15
	_poll.timeout.connect(_tick)
	add_child(_poll)
	_load()
	if repo.is_empty():
		repo = _guess_repo()
	if blender.is_empty():
		blender = _guess_blender()


## Where the game is. The app sits at `<repo>/forge_app`, so the repo is its
## parent - and an app copied elsewhere is asked rather than guessed at.
func _guess_repo() -> String:
	var here: String = ProjectSettings.globalize_path("res://")
	return here.rstrip("/\\").get_base_dir()


## Blender, by the same default the Python half uses, then by anything the
## machine has on PATH. Named versions rather than a search of Program
## Files, because a search that finds 3.1 first is worse than a miss.
func _guess_blender() -> String:
	var env: String = OS.get_environment("BLENDER")
	if not env.is_empty() and FileAccess.file_exists(env):
		return env
	for version: String in ["4.5", "4.4", "4.3", "4.2"]:
		var guess: String = "C:/Program Files/Blender Foundation/Blender %s/blender.exe" % version
		if FileAccess.file_exists(guess):
			return guess
	return ""


func forge_script() -> String:
	return repo.path_join("tools/vfx_forge/forge.py")


## What is wrong with the setup, or "" when nothing is.
func complaint() -> String:
	if not FileAccess.file_exists(forge_script()):
		return "No forge at %s. Set the repository folder." % forge_script()
	if blender.is_empty() or not FileAccess.file_exists(blender):
		return "No Blender found. Set its path, or set the BLENDER variable."
	return ""


func busy() -> bool:
	return _pid >= 0 and OS.is_process_running(_pid)


## Every effect the forge knows, read from the forge itself rather than from
## a list here: a file dropped in `effects/` is in this window for the same
## reason it is on the command line.
func catalogue() -> Array:
	var out: Array = []
	var lines: Array = []
	var code: int = OS.execute(python, [forge_script(), "list", "--json"], lines, true)
	if code != 0 or lines.is_empty():
		return out
	var text: String = "\n".join(lines)
	var open: int = text.find("[")
	if open < 0:
		return out
	var parsed: Variant = JSON.parse_string(text.substr(open))
	if parsed is Array:
		out = parsed as Array
	return out


## Renders one effect. `takes` of -1 uses the effect's own `SPEC`.
func render(effect: String, frames: int, size: int, takes: int) -> void:
	if busy():
		return
	_log = OS.get_user_data_dir().path_join("forge_run.log")
	_read = 0
	var parts: PackedStringArray = [
		_quote(python), _quote(forge_script()), effect,
		"--frames", str(frames), "--size", str(size),
	]
	if takes >= 0:
		parts.append_array(["--variants", str(takes)])
	var line: String = " ".join(parts) + " > " + _quote(_log) + " 2>&1"
	line_written.emit("> " + " ".join(parts))
	_pid = _spawn(line)
	if _pid < 0:
		line_written.emit("could not start a shell")
		finished.emit(-1, false)
		return
	_poll.start()


## Every effect, one after another, in one shell so the log is one story.
func render_all(takes: int) -> void:
	if busy():
		return
	_log = OS.get_user_data_dir().path_join("forge_run.log")
	_read = 0
	var parts: PackedStringArray = [_quote(python), _quote(forge_script()), "--all"]
	if takes >= 0:
		parts.append_array(["--variants", str(takes)])
	var line: String = " ".join(parts) + " > " + _quote(_log) + " 2>&1"
	line_written.emit("> " + " ".join(parts))
	_pid = _spawn(line)
	if _pid < 0:
		finished.emit(-1, false)
		return
	_poll.start()


func stop() -> void:
	if _pid >= 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	_poll.stop()


func _spawn(line: String) -> int:
	# The environment the Python half reads Blender out of, set for the
	# child rather than written into the command, so a path with a space in
	# it needs no quoting rules of its own.
	OS.set_environment("BLENDER", blender)
	if OS.get_name() == "Windows":
		return OS.create_process("cmd.exe", ["/c", line], false)
	return OS.create_process("/bin/sh", ["-c", line], false)


func _quote(text: String) -> String:
	return "\"%s\"" % text


func _tick() -> void:
	_drain()
	if _pid >= 0 and not OS.is_process_running(_pid):
		_poll.stop()
		_pid = -1
		# One last read: the shell writes its final lines as it exits, and a
		# run that stopped between two polls would lose its verdict.
		_drain()
		var text: String = _whole_log()
		var ok: bool = text.contains("rendered") and not text.contains("FAILED")
		finished.emit(0 if ok else 1, ok)


func _drain() -> void:
	var text: String = _whole_log()
	if text.length() <= _read:
		return
	var fresh: String = text.substr(_read)
	_read = text.length()
	for line: String in fresh.split("\n"):
		if not line.strip_edges().is_empty():
			line_written.emit(line)


func _whole_log() -> String:
	if _log.is_empty() or not FileAccess.file_exists(_log):
		return ""
	var file: FileAccess = FileAccess.open(_log, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


# --- What the app remembers ---------------------------------------------------

func save() -> void:
	var file: FileAccess = FileAccess.open(SETTINGS, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"repo": repo, "python": python, "blender": blender,
	}, "  "))
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(SETTINGS):
		return
	var file: FileAccess = FileAccess.open(SETTINGS, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		return
	var saved: Dictionary = parsed as Dictionary
	repo = String(saved.get("repo", ""))
	python = String(saved.get("python", "python"))
	blender = String(saved.get("blender", ""))
