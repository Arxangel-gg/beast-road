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
const LAUNCHER_VERSION: String = "2"

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
