extends Node

var _failures: int = 0


func _ready() -> void:
	_test_release_parsing()
	_test_download_failure_policy()
	_test_unusable_release()
	_test_self_update_gate()
	_test_launcher_version_gate()
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


## A game-only release must not ask the player for a new launcher.
##
## This is the regression this whole mechanism exists for. The launcher used to
## compare the release tag, which moves every release, so every game update also
## made the player re-download the launcher - reported from a metered connection,
## where it was most of the cost of a patch.
##
## Tested through `launcher_asset_differs` rather than `has_launcher_update`
## because a repository build is never CI-stamped, so the public method can only
## ever return false here and would pass no matter how broken the rule was.
func _test_launcher_version_gate() -> void:
	var versioned: ReleaseInfo = ReleaseInfo.from_json(JSON.stringify({
		"tag_name": "v9.9.9",
		"assets": [
			{"name": "BeastRoad-windows.zip", "browser_download_url": "https://e.invalid/g.zip", "size": 1},
			{"name": "BeastRoadLauncher-l2.exe", "browser_download_url": "https://e.invalid/l.exe", "size": 2},
		],
	}))
	_check(versioned != null, "a versioned launcher release should parse")
	if versioned == null:
		return
	_check(versioned.launcher_version == "2",
		"the launcher version should be read out of the asset filename")
	_check(not versioned.launcher_asset_differs("2", "v0.0.1"),
		"a new game release must not ask for a new launcher when the launcher version matches")
	_check(versioned.launcher_asset_differs("3", "v9.9.9"),
		"a launcher version that differs must still be offered")
	_check(versioned.is_usable(),
		"skipping the launcher update must leave the game installable")

	# The round trip CI depends on: the filename it builds from LAUNCHER_VERSION
	# has to parse back to exactly that string, or a launcher can never match the
	# launcher that was published for it.
	var published: String = "BeastRoadLauncher-l%s.exe" % LauncherConfig.LAUNCHER_VERSION
	_check(LauncherConfig.launcher_version_in(published) == LauncherConfig.LAUNCHER_VERSION,
		"LAUNCHER_VERSION must survive the round trip through the asset filename")

	# A name that merely contains "-l" is not a version. Without this guard
	# "BeastRoad-launcher.exe" parses as "auncher", never matches, and every
	# release looks like a launcher update again.
	_check(LauncherConfig.launcher_version_in("BeastRoad-launcher.exe").is_empty(),
		"a non-numeric suffix must not be read as a launcher version")
	_check(LauncherConfig.launcher_version_in("BeastRoadLauncher.exe").is_empty(),
		"an unversioned launcher asset should report no version")

	# Releases from before launchers were versioned still fall back to the tag, so
	# a player on an old launcher is carried forward exactly once.
	var legacy: ReleaseInfo = ReleaseInfo.from_json(JSON.stringify({
		"tag_name": "v9.9.9",
		"assets": [
			{"name": "BeastRoad-windows.zip", "browser_download_url": "https://e.invalid/g.zip", "size": 1},
			{"name": "BeastRoadLauncher.exe", "browser_download_url": "https://e.invalid/l.exe", "size": 2},
		],
	}))
	_check(legacy.launcher_version.is_empty(), "a legacy asset carries no version")
	_check(legacy.launcher_asset_differs("2", "v0.0.1"),
		"an unversioned release should fall back to comparing the tag")
	_check(not legacy.launcher_asset_differs("2", "v9.9.9"),
		"an unversioned release matching the running tag is not an update")

	# No launcher attached at all is never a launcher update.
	var gameonly: ReleaseInfo = ReleaseInfo.from_json(JSON.stringify({
		"tag_name": "v9.9.9",
		"assets": [{"name": "BeastRoad-windows.zip", "browser_download_url": "https://e.invalid/g.zip", "size": 1}],
	}))
	_check(not gameonly.launcher_asset_differs("2", "v0.0.1"),
		"a release with no launcher asset must never report a launcher update")


func _cleanup() -> void:
	DirAccess.remove_absolute(LauncherConfig.download_path())
	var installer := Installer.new()
	add_child(installer)
	installer.call("_remove_tree", LauncherConfig.install_dir())
	installer.call("_remove_tree", LauncherConfig.staging_dir())
	installer.queue_free()
