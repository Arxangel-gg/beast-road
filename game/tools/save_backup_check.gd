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
	var migration_backup: String = fixture_dir.path_join("v1-migration.bak.json")
	var marker: String = "escape-hatch-probe"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(fixture_dir))

	for path: String in [save_path, backup, migration_backup]:
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

	var v1_text: String = JSON.stringify({
		"version": 1,
		"unlocked": {"towers": [marker]},
		"settings": {"graphics": {"graphics_preset": "low"}},
	}, "\t")
	var migrated: Dictionary = MetaState.migrate_save(
		JSON.parse_string(v1_text) as Dictionary, v1_text, migration_backup)
	var migration_kept: bool = FileAccess.file_exists(migration_backup) \
		and FileAccess.get_file_as_string(migration_backup) == v1_text
	var migration_valid: bool = int(migrated.get("version", 0)) == MetaState.SAVE_VERSION \
		and (migrated.get("unlocked", {}) as Dictionary).has("buildings") \
		and migrated.has("resource_cache")
	print("[save] v1 source preserved=%s migration valid=%s"
		% [str(migration_kept), str(migration_valid)])

	for path: String in [save_path, backup, migration_backup]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	if not (kept and intact and still and migration_kept and migration_valid):
		push_error("save backup failed: kept=%s intact=%s survived=%s migration=%s/%s"
			% [str(kept), str(intact), str(still), str(migration_kept), str(migration_valid)])
		get_tree().quit(1)
		return
	for _f: int in 5:
		await get_tree().process_frame
	get_tree().quit(0)
