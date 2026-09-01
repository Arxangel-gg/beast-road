extends Node

var _failures: int = 0
var _previous_local_app_data: String = ""
var _fixture_base: String = ""


func _ready() -> void:
	# LauncherConfig normally targets the player's real LOCALAPPDATA install.
	# Every failure-path test below writes and removes trees, so redirect the
	# entire contract into a repository-local fixture before asking it for a
	# single path. A release gate must never be able to delete the game it tests.
	_previous_local_app_data = OS.get_environment("LOCALAPPDATA")
	_fixture_base = ProjectSettings.globalize_path(
		"res://.automated_checks/release_pipeline")
	OS.set_environment("LOCALAPPDATA", _fixture_base)
	_test_release_parsing()
	_test_download_failure_policy()
	_test_unusable_release()
	_test_self_update_gate()
	_test_launcher_version_gate()
	_test_corrupt_archive()
	_test_truncated_archive()
	_test_uninstall_guard()
	_test_uninstall_removes_the_build()
	if _failures == 0:
		_test_mirrors()
		_test_mirrors_in_release_notes()
	_cleanup()
	if _failures == 0:
		print("[launcher test] release pipeline checks passed")
	else:
		print("[launcher test] release pipeline checks failed: %d" % _failures)
	get_tree().quit(_failures)


## The uninstaller must refuse anything that is not its own.
##
## Everything it does walks a tree calling `remove`, and the way that becomes a
## catastrophe is being handed the wrong root - an empty string, a drive letter,
## a home directory. The guard is the whole safety of the feature, so it is
## tested directly rather than inferred from the happy path.
##
## **`remove_saves` is never called here.** It would delete this machine's real
## save: the path comes from the launcher's own `user://`, which no fixture
## redirects. A release gate must not be able to end somebody's campaign.
func _test_uninstall_guard() -> void:
	for forbidden: String in ["", "/", "C:/", "C:/Windows",
			ProjectSettings.globalize_path("res://"),
			OS.get_environment("USERPROFILE")]:
		if forbidden.is_empty():
			continue
		var report: Dictionary = Uninstaller._remove_tree(forbidden)
		_check(not bool(report.get("ok", true)),
			"the uninstaller must refuse %s" % forbidden)
		_check(int(report.get("files", 0)) == 0,
			"and must not have deleted anything from %s" % forbidden)


## And it must actually remove the build when it is pointed at one.
func _test_uninstall_removes_the_build() -> void:
	var root: String = LauncherConfig.install_dir_static()
	DirAccess.make_dir_recursive_absolute(root.path_join("data"))
	for path: String in [root.path_join("BeastRoad.exe"),
			root.path_join("installed.json"),
			root.path_join("data/pack.pck")]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		_check(file != null, "the fixture needs %s" % path)
		if file != null:
			file.store_string("x")
			file.close()
	# The half-finished download sits *beside* the directory, so removing the
	# tree does not touch it and it would be left behind.
	var leftover: String = root + ".download.zip"
	var stray: FileAccess = FileAccess.open(leftover, FileAccess.WRITE)
	if stray != null:
		stray.store_string("x")
		stray.close()

	var report: Dictionary = Uninstaller.remove_build()
	_check(bool(report.get("ok", false)),
		"removing the build must succeed: %s" % String(report.get("error", "")))
	_check(not DirAccess.dir_exists_absolute(root),
		"the install directory must be gone")
	_check(not FileAccess.file_exists(leftover),
		"and so must the half-finished download beside it")


## Where a build may be fetched from, and in what order.
##
## **A fallback nobody tests is a fallback that does not work on the day it is
## needed**, and this one is needed exactly when the developer cannot reproduce
## the problem - a player in a country where GitHub's asset host is unreachable.
func _test_mirrors() -> void:
	var github: String = "https://github.com/o/r/releases/download/v1/BeastRoad-windows.zip"
	# An interrupted prior gate may have left this exact fixture behind. Remove
	# only the redirected test cache before asserting the no-file baseline.
	DirAccess.remove_absolute(LauncherConfig.mirror_cache_path())

	# With no mirror file, GitHub and nothing else. It is where the release
	# actually is; every other entry is a copy somebody has to remember.
	var plain: Array = LauncherConfig.mirrors_for("BeastRoad-windows.zip", github)
	_check(plain.size() >= 1, "there must always be somewhere to download from")
	_check(String((plain[0] as Dictionary)["name"]) == "GitHub",
		"GitHub must be tried first, it is the only source that is right by "
			+ "construction")
	_check(String((plain[0] as Dictionary)["url"]) == github,
		"and it must use the release's own asset url")

	# A release with no asset has nowhere to go, and must say so rather than
	# offering an empty list that reads as success.
	_check(LauncherConfig.mirrors_for("BeastRoad-windows.zip", "").is_empty(),
		"a release with no asset must offer no sources at all")

	# Only http(s). The mirror list is a file on disk, and a `file://` entry in
	# one would have the launcher "download" from anywhere on the machine.
	var written: String = LauncherConfig.mirror_cache_path()
	DirAccess.make_dir_recursive_absolute(written.get_base_dir())
	var file: FileAccess = FileAccess.open(written, FileAccess.WRITE)
	_check(file != null, "the test must be able to write a mirror file")
	if file == null:
		return
	file.store_string(JSON.stringify([
		{"name": "Drive", "assets": {"BeastRoad-windows.zip": "https://example.invalid/a.zip"}},
		{"name": "Dropbox", "assets": {"BeastRoad-windows.zip": "https://example.invalid/b.zip"}},
		{"name": "Evil", "assets": {"BeastRoad-windows.zip": "file:///C:/Windows/System32/x"}},
		{"name": "Wrong asset", "assets": {"something-else.zip": "https://example.invalid/c.zip"}},
		"not a mirror at all",
	]))
	file.close()
	_check(LauncherConfig.mirrors_for("BeastRoad-windows.zip", "").is_empty(),
		"cached mirrors must never substitute for an asset absent from the release")

	var listed: Array = LauncherConfig.mirrors_for("BeastRoad-windows.zip", github)
	var names: Array = []
	for entry: Variant in listed:
		names.append(String((entry as Dictionary)["name"]))
	_check(names == ["GitHub", "Drive", "Dropbox"],
		"mirrors must be offered in order, http(s) only, and only for the asset "
			+ "actually being fetched - got %s" % str(names))
	DirAccess.remove_absolute(written)

	# A fetched list is cached, so the day GitHub cannot be reached is not the
	# day the mirror list becomes unreachable too.
	_check(LauncherConfig.remember_mirrors(JSON.stringify([
		{"name": "Dropbox", "assets": {"BeastRoad-windows.zip": "https://example.invalid/d.zip"}}])),
		"a well-formed mirror list must be cached")
	_check(not LauncherConfig.remember_mirrors("{\"not\": \"a list\"}"),
		"and a malformed one must be refused rather than stored - a corrupt "
			+ "cache outlives the request that made it")
	var cached: Array = LauncherConfig.mirrors_for("BeastRoad-windows.zip", github)
	var cached_names: Array = []
	for entry: Variant in cached:
		cached_names.append(String((entry as Dictionary)["name"]))
	_check(cached_names == ["GitHub", "Dropbox"],
		"a cached list must be used when no file sits beside the launcher, "
			+ "got %s" % str(cached_names))
	DirAccess.remove_absolute(LauncherConfig.mirror_cache_path())


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
			{"name": "BeastRoadLauncher.exe", "browser_download_url": "https://e.invalid/l.exe", "size": 2},
			{"name": "launcher-version-2.txt", "browser_download_url": "https://e.invalid/v.txt", "size": 40},
		],
	}))
	_check(versioned != null, "a versioned launcher release should parse")
	if versioned == null:
		return
	_check(versioned.launcher_version == "2",
		"the launcher version should be read out of the marker asset")
	_check(versioned.launcher_name == "BeastRoadLauncher.exe",
		"the launcher executable keeps its permanent name, so the install link still resolves")
	_check(not versioned.launcher_asset_differs("2", "v0.0.1"),
		"a new game release must not ask for a new launcher when the launcher version matches")
	_check(versioned.launcher_asset_differs("3", "v9.9.9"),
		"a launcher version that differs must still be offered")
	_check(versioned.is_usable(),
		"skipping the launcher update must leave the game installable")

	# The round trip CI depends on: the marker filename it builds from
	# LAUNCHER_VERSION has to parse back to exactly that string, or a launcher can
	# never match the launcher that was published for it.
	var published: String = "%s%s.txt" % [
		LauncherConfig.LAUNCHER_VERSION_ASSET_PREFIX, LauncherConfig.LAUNCHER_VERSION]
	_check(LauncherConfig.launcher_version_in(published) == LauncherConfig.LAUNCHER_VERSION,
		"LAUNCHER_VERSION must survive the round trip through the marker filename")

	_check(LauncherConfig.launcher_version_in("BeastRoadLauncher.exe").is_empty(),
		"the launcher executable is not a version marker")
	_check(LauncherConfig.launcher_version_in("BeastRoad-windows.zip").is_empty(),
		"the game archive is not a version marker")
	_check(LauncherConfig.launcher_version_in("launcher-version-notes.txt").is_empty(),
		"a non-numeric marker must not be read as a launcher version")

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
	OS.set_environment("LOCALAPPDATA", _previous_local_app_data)
	if DirAccess.dir_exists_absolute(_fixture_base):
		DirAccess.remove_absolute(_fixture_base)


## The mirror list carried in the release notes.
##
## **This is the path that reaches a filtered player**, and the reason it exists
## is a bug that made the whole mirror system useless to the only people it was
## built for. `mirrors.json` was published as a release asset, and release assets
## are served from `release-assets.githubusercontent.com` - the same host the
## mirrors exist to route around. A launcher behind a national filter read the
## API perfectly, knew the latest tag, drew the changelog, and then retried
## GitHub forever with an empty mirror list, because the only copy of that list
## it knew how to fetch was on the far side of the block.
##
## Reported by a friend of the owner's, on a VPN, stuck at "No data from GitHub
## for 20 seconds" while the screen behind the dialog cheerfully read
## "Latest v0.5.1".
func _test_mirrors_in_release_notes() -> void:
	var mirrors: String = JSON.stringify([
		{"name": "Dropbox", "assets": {"BeastRoad-windows.zip": "https://example.invalid/m.zip"}}])
	var notes: String = "## What changed\n\nThings.\n\n" \
		+ ReleaseInfo.MIRROR_OPEN + "\n" + mirrors + "\n" + ReleaseInfo.MIRROR_CLOSE \
		+ "\n\n**Full Changelog**: https://example.invalid/compare"

	_check(ReleaseInfo.mirrors_in_notes(notes) == mirrors,
		"the mirror block must come back out of a release body exactly as it "
			+ "went in")
	_check(not ReleaseInfo.notes_without_mirrors(notes).contains("beast-road-mirrors"),
		"and must be stripped from what the player reads - the launcher shows "
			+ "these notes as plain text, where an HTML comment is not invisible")
	_check(ReleaseInfo.notes_without_mirrors(notes).contains("What changed")
			and ReleaseInfo.notes_without_mirrors(notes).contains("Full Changelog"),
		"stripping the block must leave the rest of the notes intact on both "
			+ "sides of it")

	# Releases published before this existed, and any body somebody edits by
	# hand, must pass through untouched rather than being mangled.
	_check(ReleaseInfo.mirrors_in_notes("just some notes").is_empty(),
		"a body with no mirror block must yield no mirrors")
	_check(ReleaseInfo.notes_without_mirrors("just some notes") == "just some notes",
		"and must be left exactly as it was")
	# An unterminated marker is corruption, not a list. Reading to the end of the
	# body would hand `remember_mirrors` a half-written array.
	_check(ReleaseInfo.mirrors_in_notes(ReleaseInfo.MIRROR_OPEN + "\n[{}").is_empty(),
		"an unclosed mirror block must be refused rather than read to the end "
			+ "of the notes")

	# The whole point, end to end: a release whose body carries mirrors must
	# produce a usable mirror list without any second request.
	DirAccess.remove_absolute(LauncherConfig.mirror_cache_path())
	var info: ReleaseInfo = ReleaseInfo.from_json(JSON.stringify({
		"tag_name": "v9.9.9",
		"body": notes,
		"assets": [{
			"name": "BeastRoad-windows.zip",
			"browser_download_url": "https://example.invalid/gh.zip",
			"size": 123,
		}],
	}))
	_check(info != null and info.mirrors_inline == mirrors,
		"a release carrying mirrors in its body must expose them without a "
			+ "second request to a host that may be blocked")
	if info == null:
		return
	_check(LauncherConfig.remember_mirrors(info.mirrors_inline),
		"and that list must be well-formed enough to cache")
	var names: Array = []
	for entry: Variant in LauncherConfig.mirrors_for(
			"BeastRoad-windows.zip", "https://example.invalid/gh.zip"):
		names.append(String((entry as Dictionary)["name"]))
	_check(names == ["GitHub", "Dropbox"],
		"a filtered player must end up with somewhere to go after GitHub - "
			+ "got %s" % str(names))
	DirAccess.remove_absolute(LauncherConfig.mirror_cache_path())
