extends Node

## Exercises byte-preserving backup behavior in an isolated fixture. It never
## reads, overwrites, or removes the player's actual Beast Road save.
##
## GDD SS52: "Save migration succeeds from every public version and never destroys
## the source save." A player who tries a v4 build and goes back to v3 hits a
## version mismatch in the other direction, and unlock history is the one thing
## in this project that no checkout can restore.

func _ready() -> void:
	var future: int = MetaState.SAVE_VERSION + 99
	# `res://` keeps the headless gate inside the repository sandbox. The
	# fixture is removed below and can never alias the real `user://` save.
	var fixture_dir: String = "res://.automated_checks/save_backup"
	var save_path: String = fixture_dir.path_join("unreadable.json")
	var backup: String = fixture_dir.path_join("unreadable.bak.json")
	var marker: String = "escape-hatch-probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_dir))

	for path: String in [save_path, backup]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var original: String = JSON.stringify({
		"version": future,
		"unlocked": {"towers": [marker]},
		"stats": {"runs_started": 42},
	}, "\t")
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(original)
	file.close()

	MetaState._back_up_save(original, future, backup)

	var kept: bool = FileAccess.file_exists(backup)
	print("[save] unreadable save backed up=%s" % str(kept))
	var contents: String = ""
	if kept:
		contents = FileAccess.get_file_as_string(backup)
	var intact: bool = contents == original
	print("[save] backup is byte-identical=%s" % str(intact))
	# Second load must not clobber the first copy - the original is the valuable
	# one, and bouncing between builds would otherwise erase it.
	var file2: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	file2.store_string(JSON.stringify({"version": future, "unlocked": {"towers": []}}))
	file2.close()
	MetaState._back_up_save(FileAccess.get_file_as_string(save_path), future, backup)
	var still: bool = FileAccess.get_file_as_string(backup) == original
	print("[save] survives a second mismatch=%s" % str(still))

	for path: String in [save_path, backup]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	if not (kept and intact and still):
		push_error("save backup failed: kept=%s intact=%s survived=%s"
			% [str(kept), str(intact), str(still)])
		get_tree().quit(1)
		return
	for _f: int in 5:
		await get_tree().process_frame
	get_tree().quit(0)
