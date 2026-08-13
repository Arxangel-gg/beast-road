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
## locally. Comparing it to the newest release tag is how a launcher knows it is
## out of date, and comparing tags rather than parsing versions is deliberate:
## the tag CI published is the truth, and anything that reasons about version
## ordering eventually refuses a valid rollback.
const VERSION: String = "dev"


## Whether this build knows its own version. A locally exported launcher does
## not, and must never offer to replace itself with something it cannot compare.
func version_is_stamped() -> bool:
	return VERSION != "dev" and not VERSION.is_empty()

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
