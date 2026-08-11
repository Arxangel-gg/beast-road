class_name InstallState
extends RefCounted

## What is on this machine right now, read from the install manifest.
##
## The manifest is the only thing that says a build is *finished*. It is written
## last, after the extract has completed, so an interrupted install leaves no
## manifest and is correctly reported as "not installed" rather than as a
## corrupt game that will not start.

var installed: bool = false
var tag: String = ""
var installed_at: String = ""
var exe_path: String = ""


static func read() -> InstallState:
	var state := InstallState.new()
	state.exe_path = LauncherConfig.game_exe_path()

	var path: String = LauncherConfig.manifest_path()
	if not FileAccess.file_exists(path):
		return state
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return state
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return state

	var data: Dictionary = parsed
	state.tag = String(data.get("tag", ""))
	state.installed_at = String(data.get("installed_at", ""))
	# A manifest pointing at a missing executable is worse than no manifest:
	# it would offer "Play" for something that cannot run.
	state.installed = not state.tag.is_empty() and FileAccess.file_exists(state.exe_path)
	return state


static func write(tag: String) -> Error:
	var data: Dictionary = {
		"tag": tag,
		"installed_at": Time.get_datetime_string_from_system(true),
		"executable": LauncherConfig.GAME_EXECUTABLE,
	}
	var file: FileAccess = FileAccess.open(LauncherConfig.manifest_path(), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


static func clear() -> void:
	var path: String = LauncherConfig.manifest_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
