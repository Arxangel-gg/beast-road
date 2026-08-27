class_name Uninstaller
extends RefCounted

## Removing what the launcher put on this machine.
##
## Two separate things, deliberately kept separate:
##
## - **the build**, which is a few hundred megabytes the launcher downloaded and
##   can download again;
## - **the save**, which is the player's run history, hero, stash and settings,
##   and which nothing anywhere can get back.
##
## A "clean reinstall" wants the first and almost never the second, so removing
## the build is the default and the save is an extra the player has to ask for
## by name. Anything that deletes hundreds of hours by accident is not a
## convenience.

## Where the game keeps its saves. Godot's own layout, and the launcher's `user://`
## is the sibling directory - which is why this is derived from the launcher's
## rather than guessed at from an environment variable.
const GAME_USER_DIR: String = "Beast Road"


## The save directory, as an absolute path.
static func save_dir() -> String:
	var mine: String = ProjectSettings.globalize_path("user://").replace("\\", "/")
	# ".../app_userdata/Beast Road Launcher/" -> ".../app_userdata/Beast Road"
	return mine.rstrip("/").get_base_dir().path_join(GAME_USER_DIR)


## Whether there is anything to remove, so the interface can say so honestly.
static func save_exists() -> bool:
	return DirAccess.dir_exists_absolute(save_dir())


## The directories this is ever allowed to delete.
##
## **A guard, not a formality.** Everything below walks a tree calling `remove`,
## and the one way that becomes a catastrophe is being handed the wrong root -
## an empty string, a drive letter, the user's home. Every delete is checked
## against this list first, so a bug upstream removes nothing rather than
## something irreplaceable.
static func _permitted() -> PackedStringArray:
	return PackedStringArray([
		LauncherConfig.install_dir_static().replace("\\", "/"),
		save_dir(),
	])


static func _allowed(path: String) -> bool:
	var wanted: String = path.replace("\\", "/").rstrip("/")
	if wanted.length() < 8 or not wanted.contains("/"):
		return false
	for root: String in _permitted():
		var allowed: String = root.rstrip("/")
		if wanted == allowed or wanted.begins_with(allowed + "/"):
			return true
	return false


## Removes the installed build, the half-finished download beside it, and the
## manifest that says a build is there. Leaves the save alone.
static func remove_build() -> Dictionary:
	var root: String = LauncherConfig.install_dir_static()
	var report: Dictionary = _remove_tree(root)
	# The download lands *beside* the install directory rather than inside it, so
	# it is not covered by removing the tree and would otherwise be left behind -
	# ninety megabytes of zip nobody can account for.
	var leftover: String = root + ".download.zip"
	if FileAccess.file_exists(leftover) and _allowed(root):
		DirAccess.remove_absolute(leftover)
		report["files"] = int(report.get("files", 0)) + 1
	return report


## Removes the player's saved progress. Only ever on an explicit request.
static func remove_saves() -> Dictionary:
	return _remove_tree(save_dir())


## Deletes a directory and everything under it, depth first.
##
## `DirAccess` has no recursive remove, and a directory is only removable once it
## is empty - so children come first and the root goes last.
static func _remove_tree(root: String) -> Dictionary:
	var report: Dictionary = {"ok": true, "files": 0, "dirs": 0, "error": ""}
	if not _allowed(root):
		report["ok"] = false
		report["error"] = "refused to remove %s - not a directory this launcher owns" % root
		return report
	if not DirAccess.dir_exists_absolute(root):
		return report

	var directory: DirAccess = DirAccess.open(root)
	if directory == null:
		report["ok"] = false
		report["error"] = "could not open %s" % root
		return report

	directory.list_dir_begin()
	var name: String = directory.get_next()
	while name != "":
		var path: String = root.path_join(name)
		if directory.current_is_dir():
			var inner: Dictionary = _remove_tree(path)
			report["files"] = int(report["files"]) + int(inner.get("files", 0))
			report["dirs"] = int(report["dirs"]) + int(inner.get("dirs", 0))
			if not bool(inner.get("ok", true)):
				report["ok"] = false
				report["error"] = inner.get("error", "")
		else:
			if DirAccess.remove_absolute(path) == OK:
				report["files"] = int(report["files"]) + 1
			else:
				report["ok"] = false
				report["error"] = "could not delete %s" % path
		name = directory.get_next()
	directory.list_dir_end()

	if DirAccess.remove_absolute(root) == OK:
		report["dirs"] = int(report["dirs"]) + 1
	elif bool(report["ok"]):
		report["ok"] = false
		report["error"] = "could not remove %s" % root
	return report


## What was removed, in a sentence.
static func describe(report: Dictionary) -> String:
	if not bool(report.get("ok", true)):
		return String(report.get("error", "Something could not be removed."))
	var files: int = int(report.get("files", 0))
	if files == 0:
		return "Nothing to remove."
	return "Removed %d file%s." % [files, "" if files == 1 else "s"]
