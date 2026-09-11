extends Node

## The save directory must not move when the game is renamed.
##
## Godot derives `user://` from `application/config/name`. The game was renamed
## from Beast Road to Wilderhold on 2026-09-11, and a rename that carried the
## user directory with it would have left every existing save - the owner's
## included - in a folder the game no longer reads. Nothing would error: the
## menu would simply show a fresh account, and the next save would write beside
## the old one.
##
## `project.godot` therefore pins the directory with `use_custom_user_dir`, and
## this gate holds the pin: it fails if the setting is dropped, if the name
## drifts, or if the engine resolves `user://` anywhere other than the folder
## the game has always used. It reads nothing and writes nothing.

## The folder every save has ever lived in, relative to the platform's data
## directory. Lowercase `godot` on purpose - see project.godot for why.
const PINNED_DIR: String = "godot/app_userdata/Beast Road"

var _failures: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_check(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)),
		"application/config/use_custom_user_dir must be on")
	var declared: String = String(ProjectSettings.get_setting(
		"application/config/custom_user_dir_name", ""))
	_check(declared == PINNED_DIR,
		"custom_user_dir_name is %s, expected %s" % [declared, PINNED_DIR])

	var resolved: String = OS.get_user_data_dir().replace("\\", "/").rstrip("/")
	# Case-insensitive, because Windows reports the path with whatever case the
	# setting used while the folder on disk is "Godot", and both are the same
	# directory there. A different *name* is the failure this looks for.
	_check(resolved.to_lower().ends_with("/" + PINNED_DIR.to_lower()),
		"user:// resolves to %s, which is not the pinned save directory" % resolved)
	_check(not resolved.to_lower().contains("wilderhold"),
		"user:// followed the new title into %s" % resolved)
	_check(ProjectSettings.globalize_path(MetaState.SAVE_PATH).replace("\\", "/")
			.begins_with(resolved),
		"the save path does not sit inside the pinned directory")

	if _failures > 0:
		push_error("[user-dir] FAIL - %d problem(s); the save directory has moved" % _failures)
		get_tree().quit(1)
		return
	print("[user-dir] PASS - user:// is pinned to %s" % resolved)
	get_tree().quit(0)


func _check(ok: bool, why: String) -> void:
	if ok:
		return
	_failures += 1
	print("  ERROR: %s" % why)
