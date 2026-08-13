extends Node

var _failures: int = 0


func _ready() -> void:
	_test_release_parsing()
	_test_download_failure_policy()
	_test_unusable_release()
	_test_self_update_gate()
	_test_corrupt_archive()
	_test_truncated_archive()
	_cleanup()
	if _failures == 0:
		print("[launcher test] release pipeline checks passed")
	get_tree().quit(_failures)


func _test_release_parsing() -> void:
	var payload: String = JSON.stringify({
		"tag_name": "v9.9.9",
		"name": "Test release",
		"assets": [
			{
				"name": "notes.txt",
				"browser_download_url": "https://example.invalid/notes.txt",
				"size": 4,
			},
			{
				"name": "BeastRoad-windows.zip",
				"browser_download_url": "https://example.invalid/game.zip",
				"size": 123456,
				"digest": "sha256:ABCDEF",
			},
		],
	})
	var release: ReleaseInfo = ReleaseInfo.from_json(payload)
	_check(release != null, "valid release JSON should parse")
	if release == null:
		return
	_check(release.is_usable(), "release with a Windows zip should be usable")
	_check(release.tag == "v9.9.9", "tag should be preserved")
	_check(release.asset_name == "BeastRoad-windows.zip", "Windows archive should be selected")
	_check(release.asset_size == 123456, "asset size should be preserved")
	_check(release.asset_sha256 == "abcdef", "GitHub SHA-256 should be normalized")
	_check(ReleaseInfo.from_json("[]") == null, "non-object JSON should be rejected")
	_check(ReleaseInfo.from_json("{}") == null, "objects without a tag should be rejected")


func _test_download_failure_policy() -> void:
	var installer := Installer.new()
	_check(
		installer._is_retryable_result(HTTPRequest.RESULT_CONNECTION_ERROR),
		"connection interruptions should retry"
	)
	_check(
		installer._is_retryable_result(HTTPRequest.RESULT_TIMEOUT),
		"timeouts should retry"
	)
	_check(
		not installer._is_retryable_result(HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR),
		"disk write errors should not retry"
	)
	_check(
		installer._result_text(HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN).contains("temporary"),
		"file-open failures should identify the local temporary file"
	)
	_check(installer._safe_archive_path("game/BeastRoad.exe") == "game/BeastRoad.exe",
		"normal archive paths should be accepted")
	_check(installer._safe_archive_path("game\\BeastRoad.pck") == "game/BeastRoad.pck",
		"Windows separators should be normalized")
	_check(installer._safe_archive_path("../escape.exe").is_empty(),
		"parent traversal should be rejected")
	_check(installer._safe_archive_path("C:/escape.exe").is_empty(),
		"absolute Windows paths should be rejected")
	installer.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[launcher test] " + message)


# --- Failure paths -----------------------------------------------------------
#
# GDD §52 names six: clean install, update, rollback, offline launch, corrupt
# download and interrupted download. Two were covered. The launcher guards all
# six in code, and until now every one of those guards was an untested claim.
#
# The rule underneath them is a single sentence from §52 - "never removes the
# last playable install on failure" - and it is the one that matters most,
# because the player it fails is the one who can no longer launch anything to
# report it with.

## A fake installed game, so "did the previous install survive" is answerable.
func _plant_install(marker: String) -> void:
	var install: String = LauncherConfig.install_dir()
	DirAccess.make_dir_recursive_absolute(install)
	var file: FileAccess = FileAccess.open(install.path_join("marker.txt"), FileAccess.WRITE)
	if file != null:
		file.store_string(marker)
		file.close()


func _install_marker() -> String:
	var path: String = LauncherConfig.install_dir().path_join("marker.txt")
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _write_bytes(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_buffer(bytes)
		file.close()


## A download that is not a zip at all - the shape GitHub returns when it serves
## an HTML error page with a 200, which is the most common corrupt download
## there is and the one least likely to look like a failure.
func _test_corrupt_archive() -> void:
	var installer := Installer.new()
	add_child(installer)
	_plant_install("previous")
	_write_bytes(LauncherConfig.download_path(),
		"<!doctype html><html>Not Found</html>".to_utf8_buffer())

	# A Dictionary, not a bool: GDScript lambdas capture locals by value, so
	# `failed = not success` inside one writes to a copy and the outer variable
	# never moves. The first version of this test could not fail.
	var outcome: Dictionary = {"failed": false}
	installer.finished.connect(func(success: bool, _message: String) -> void:
		outcome["failed"] = not success, CONNECT_ONE_SHOT)
	installer.call("_unpack")

	_check(outcome["failed"], "a corrupt archive should fail the install")
	_check(_install_marker() == "previous",
		"a corrupt archive must leave the previous install untouched")
	installer.queue_free()


## A truncated zip: real zip magic, cut off part way. A reader can open the
## header and then find nothing behind it.
func _test_truncated_archive() -> void:
	var installer := Installer.new()
	add_child(installer)
	_plant_install("previous")
	var truncated := PackedByteArray([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00])
	_write_bytes(LauncherConfig.download_path(), truncated)

	var outcome: Dictionary = {"failed": false}
	installer.finished.connect(func(success: bool, _message: String) -> void:
		outcome["failed"] = not success, CONNECT_ONE_SHOT)
	installer.call("_unpack")

	_check(outcome["failed"], "a truncated archive should fail the install")
	_check(_install_marker() == "previous",
		"a truncated archive must leave the previous install untouched")
	installer.queue_free()


## A release with no Windows build attached is not installable, and the launcher
## must say so rather than starting a download it cannot finish. §52: "never
## advertises an artifact it cannot download".
func _test_unusable_release() -> void:
	var release: ReleaseInfo = ReleaseInfo.from_json(JSON.stringify({
		"tag_name": "v9.9.9",
		"assets": [{"name": "notes.txt", "browser_download_url": "https://example.invalid/n", "size": 4}],
	}))
	_check(release != null, "a release with no build should still parse")
	_check(not release.is_usable(), "a release with no Windows zip is not usable")

	var installer := Installer.new()
	add_child(installer)
	_plant_install("previous")
	var outcome: Dictionary = {"refused": false}
	installer.finished.connect(func(success: bool, _message: String) -> void:
		outcome["refused"] = not success, CONNECT_ONE_SHOT)
	installer.install(release)
	_check(outcome["refused"], "installing an unusable release should be refused outright")
	_check(_install_marker() == "previous", "a refused install must change nothing")
	installer.queue_free()


## The launcher only offers to replace itself when it knows what it is. A build
## with no CI stamp must never do it - guessing there means overwriting somebody's
## development build with a release.
func _test_self_update_gate() -> void:
	var release: ReleaseInfo = ReleaseInfo.from_json(JSON.stringify({
		"tag_name": "v9.9.9",
		"assets": [
			{"name": "BeastRoad-windows.zip", "browser_download_url": "https://e.invalid/g.zip", "size": 1},
			{"name": "BeastRoadLauncher.exe", "browser_download_url": "https://e.invalid/l.exe", "size": 2},
		],
	}))
	_check(release.launcher_url != "", "the launcher asset should be picked up")
	_check(release.launcher_size == 2, "the launcher size should be preserved")
	_check(not LauncherConfig.version_is_stamped(),
		"a repository build must report itself as unstamped")
	_check(not release.has_launcher_update(),
		"an unstamped build must never offer to replace itself")


func _cleanup() -> void:
	DirAccess.remove_absolute(LauncherConfig.download_path())
	var installer := Installer.new()
	add_child(installer)
	installer.call("_remove_tree", LauncherConfig.install_dir())
	installer.call("_remove_tree", LauncherConfig.staging_dir())
	installer.queue_free()
