extends Node

## Everything about *where* things live. Autoloaded as `LauncherConfig`.
##
## The repository is a constant rather than something the launcher discovers,
## because a launcher that can be pointed at an arbitrary repo is a launcher
## that can be pointed at a malicious one. Changing where the game comes from
## should mean rebuilding the launcher.

## Change these two and everything else follows.
const REPO_OWNER: String = "Arxangel-gg"
const REPO_NAME: String = "beast-road"

## Release assets whose name contains this are the Windows game build.
const GAME_ASSET_MARKER: String = "windows"

## And this one is the launcher itself.
const LAUNCHER_ASSET_MARKER: String = "launcher"

## The whole-request deadline, and the one that actually matters.
##
## `DOWNLOAD_DEADLINE` has to be generous enough for ninety megabytes on a poor
## line, which makes it useless for noticing a *blocked* host - so the stall
## limit does that job instead: no new bytes at all for this long means try
## somewhere else. A slow connection still moves and is never punished by it.
const DOWNLOAD_DEADLINE: float = 1800.0
const DOWNLOAD_STALL_LIMIT: float = 20.0

## Where a build can be fetched from, in the order they are tried.
##
## **GitHub first, always.** It is where the release actually is, it is the only
## one that is right by construction, and every other entry is a copy somebody
## has to remember to update. The rest exist because GitHub's asset CDN is a
## different host from `github.com` and is unreachable from some countries -
## reported by a player whose launcher sat at 0% forever while the version check
## worked perfectly.
##
## Read from `mirrors.json` beside the launcher when one is there, so a mirror
## can be moved, added or dropped without a new build. The file is a list of
## `{"name": ..., "assets": {"<asset name>": "<direct url>"}}`; see
## `docs/MIRRORS.md` for how to get a direct URL out of Drive or Dropbox that
## survives the next upload.
const MIRROR_FILE: String = "mirrors.json"


## Every place to try for one asset, in order. The first is always GitHub.
static func mirrors_for(asset: String, github_url: String) -> Array:
	var out: Array = []
	if not github_url.is_empty():
		out.append({"name": "GitHub", "url": github_url})
	for entry: Variant in _mirror_file():
		if not (entry is Dictionary):
			continue
		var mirror: Dictionary = entry
		var assets: Variant = mirror.get("assets", null)
		if not (assets is Dictionary):
			continue
		var url: String = String((assets as Dictionary).get(asset, ""))
		# Only http(s). A mirror list is a file on disk and a `file://` entry in
		# one would have the launcher "download" from anywhere on the machine.
		if url.begins_with("http://") or url.begins_with("https://"):
			out.append({"name": String(mirror.get("name", "a mirror")), "url": url})
	return out


## Where a fetched mirror list is kept between runs.
##
## **Cached, because the day it is needed is the day GitHub cannot be reached.**
## A list that only exists on the release it describes is no use to a player who
## cannot reach that release; the copy from last time is.
static func mirror_cache_path() -> String:
	return install_dir_static().path_join(MIRROR_FILE)


## Writes a fetched mirror list to the cache. Anything unparseable is dropped
## rather than stored - a corrupt cache would outlive the request that made it.
static func remember_mirrors(text: String) -> bool:
	if not (JSON.parse_string(text) is Array):
		return false
	DirAccess.make_dir_recursive_absolute(mirror_cache_path().get_base_dir())
	var file: FileAccess = FileAccess.open(mirror_cache_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


## `install_dir` without an instance, for the static helpers above.
static func install_dir_static() -> String:
	var base: String = OS.get_environment("LOCALAPPDATA")
	if base.is_empty():
		base = ProjectSettings.globalize_path("user://")
	return base.replace("\\", "/").path_join("BeastRoad")


## The mirror list from disk, or an empty list. Never throws, never blocks.
##
## Beside the executable first, so a hand-written file always wins over a fetched
## one - somebody who edits it is answering a question the release could not.
static func _mirror_file() -> Array:
	for path: String in [
		OS.get_executable_path().get_base_dir().path_join(MIRROR_FILE),
		mirror_cache_path(),
		ProjectSettings.globalize_path("user://").path_join(MIRROR_FILE),
	]:
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Array:
			return parsed as Array
	return []

## The tag this launcher was built from.
##
## Stamped by CI before the launcher is exported - the placeholder below is what
## sits in the repository, and a build that still says "dev" is one somebody made
## locally. It identifies the build and gates self-replacement; it is **not** what
## decides whether a new launcher is needed. See LAUNCHER_VERSION.
const VERSION: String = "dev"

## The launcher's own version, and the only thing that decides whether a player
## has to download a new launcher. Bump it by hand when the launcher changes.
##
## It is deliberately not the release tag. The tag moves on every game update, so
## comparing tags meant every game update also replaced the launcher - a fresh
## download and a restart for a launcher that had not changed a line. On a metered
## connection that was most of the cost of a patch that touched one .tres file,
## which is how it was found.
##
## Published as a tiny marker asset on every release, `launcher-version-<v>.txt`,
## so a running launcher can compare without downloading anything. CI builds that
## name by reading *this* constant, so the two cannot drift apart.
##
## A marker rather than a version in the executable's own filename, because
## `releases/latest/download/BeastRoadLauncher.exe` is the permanent link testers
## install from and it resolves by exact filename - versioning the exe would break
## it on the release that fixed the update, which is the worst possible timing.
const LAUNCHER_VERSION: String = "3"

## Names the marker asset that carries LAUNCHER_VERSION.
const LAUNCHER_VERSION_ASSET_PREFIX: String = "launcher-version-"


## Whether this build knows its own version. A locally exported launcher does
## not, and must never offer to replace itself with something it cannot compare.
func version_is_stamped() -> bool:
	return VERSION != "dev" and not VERSION.is_empty()


## The launcher version a marker asset advertises, or "" for any other asset.
##
## Releases published before launchers had their own version carry no marker, and
## "" is what tells `ReleaseInfo` to fall back to the old tag comparison rather
## than treat the absence as a mismatch.
func launcher_version_in(asset_name: String) -> String:
	var name: String = asset_name.get_file()
	if not name.to_lower().begins_with(LAUNCHER_VERSION_ASSET_PREFIX):
		return ""
	var found: String = name.get_basename().substr(LAUNCHER_VERSION_ASSET_PREFIX.length())
	if found.is_empty():
		return ""
	# Digits and dots only, so a stray asset cannot be read as a version it is
	# not, never match, and quietly restore the every-release-is-an-update bug.
	for index: int in found.length():
		if not (found[index].is_valid_int() or found[index] == "."):
			return ""
	return found

## The executable to run once installed, relative to the install directory.
const GAME_EXECUTABLE: String = "BeastRoad.exe"

## Written next to the game so the launcher knows what it installed.
const MANIFEST_FILE: String = "installed.json"

const USER_AGENT: String = "BeastRoadLauncher"


func latest_release_url() -> String:
	return "https://api.github.com/repos/%s/%s/releases/latest" % [REPO_OWNER, REPO_NAME]


func releases_page_url() -> String:
	return "https://github.com/%s/%s/releases" % [REPO_OWNER, REPO_NAME]


## Where the game lives. LOCALAPPDATA rather than Roaming: this is a few hundred
## megabytes of binary, and roaming profiles should not carry it across machines.
func install_dir() -> String:
	var base: String = OS.get_environment("LOCALAPPDATA")
	if base.is_empty():
		base = ProjectSettings.globalize_path("user://")
	return base.replace("\\", "/").path_join("BeastRoad")


func game_exe_path() -> String:
	return install_dir().path_join(GAME_EXECUTABLE)


func manifest_path() -> String:
	return install_dir().path_join(MANIFEST_FILE)


## Downloads land beside the install directory, not inside it: a failed or
## half-finished download must never look like an installed game.
func download_path() -> String:
	return install_dir() + ".download.zip"


func staging_dir() -> String:
	return install_dir() + ".staging"


## Headers GitHub's API expects. It rejects requests without a User-Agent.
func api_headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: " + USER_AGENT,
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
	])


func download_headers() -> PackedStringArray:
	return PackedStringArray([
		"User-Agent: " + USER_AGENT,
		"Accept: application/octet-stream",
	])
