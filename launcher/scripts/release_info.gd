class_name ReleaseInfo
extends RefCounted

## One GitHub release, reduced to the four things the launcher cares about.

var tag: String = ""
var title: String = ""
var notes: String = ""
var asset_url: String = ""

## Where `mirrors.json` is on this release, if it published one.
##
## The mirror list travels *with the release* rather than being baked into the
## launcher, so a mirror can be added, moved or dropped without every player
## needing a new launcher first. It is cached on disk after each successful
## fetch, because the one moment it is needed is the moment GitHub cannot be
## reached - and a list that only exists on GitHub is no use then.
var mirrors_url: String = ""
var asset_name: String = ""
var asset_size: int = 0
var asset_sha256: String = ""

## The launcher build attached to the same release, when there is one. Kept
## separate from the game asset because they update independently: most releases
## change the game and leave the launcher alone.
var launcher_url: String = ""
var launcher_name: String = ""
var launcher_size: int = 0

## The launcher version its filename advertises, or "" on releases published
## before launchers carried one.
var launcher_version: String = ""


func is_usable() -> bool:
	return not tag.is_empty() and not asset_url.is_empty()


## Parses the body of /releases/latest. Returns null when the payload is not a
## release (GitHub answers rate limits and 404s with a JSON object too, so the
## shape has to be checked rather than assumed).
static func from_json(text: String) -> ReleaseInfo:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return null
	var data: Dictionary = parsed
	if not data.has("tag_name"):
		return null

	var info := ReleaseInfo.new()
	info.tag = String(data.get("tag_name", ""))
	info.title = String(data.get("name", info.tag))
	info.notes = String(data.get("body", "")).strip_edges()

	var assets: Array = data.get("assets", []) as Array
	for entry: Variant in assets:
		var asset: Dictionary = entry as Dictionary
		if asset == null:
			continue
		var name: String = String(asset.get("name", ""))

		# The version marker is checked first and does not `continue`-guard the
		# others, because it is a different asset from the launcher itself and
		# GitHub does not promise an order for the two.
		var marked: String = LauncherConfig.launcher_version_in(name)
		if not marked.is_empty():
			info.launcher_version = marked
			continue

		if name == LauncherConfig.MIRROR_FILE:
			info.mirrors_url = String(asset.get("browser_download_url", ""))
			continue

		# The launcher is an .exe and the game is a .zip, so the two never
		# compete for the same slot.
		if name.to_lower().ends_with(".exe") 				and name.to_lower().contains(LauncherConfig.LAUNCHER_ASSET_MARKER):
			info.launcher_name = name
			info.launcher_url = String(asset.get("browser_download_url", ""))
			info.launcher_size = int(asset.get("size", 0))
			continue

		if not name.to_lower().ends_with(".zip"):
			continue
		if not name.to_lower().contains(LauncherConfig.GAME_ASSET_MARKER):
			continue
		info.asset_name = name
		info.asset_url = String(asset.get("browser_download_url", ""))
		# JSON numbers arrive as floats in Godot; a byte count is not a float.
		info.asset_size = int(asset.get("size", 0))
		var digest: String = String(asset.get("digest", "")).strip_edges().to_lower()
		if digest.begins_with("sha256:"):
			info.asset_sha256 = digest.trim_prefix("sha256:")
	return info


## True when this release carries a launcher build different from the running one.
##
## A launcher that cannot tell what it is - one exported locally, with no CI
## stamp - never offers to replace itself. Guessing there means possibly
## overwriting a developer's build with a release, which is a bad way to find out
## the check was wrong.
func has_launcher_update() -> bool:
	return LauncherConfig.version_is_stamped() 		and launcher_asset_differs(LauncherConfig.LAUNCHER_VERSION, LauncherConfig.VERSION)


## Whether this release's launcher asset is a different build from the running
## launcher, ignoring the stamp guard.
##
## Split out from `has_launcher_update` so the rule can be tested: a repository
## build is never stamped, so going through the guard can only ever prove the
## negative case, and the case that matters here is the *positive* one - that a
## game-only release does not ask for a new launcher.
##
## This used to compare the release tag, which changes on every release, so every
## game update replaced the launcher too. The launcher version changes only when
## the launcher does, so a run of game-only releases now leaves it alone however
## long that run gets.
func launcher_asset_differs(running_launcher_version: String, running_tag: String) -> bool:
	if launcher_url.is_empty():
		return false
	if not launcher_version.is_empty():
		return launcher_version != running_launcher_version
	# A release from before launchers were versioned cannot say whether its
	# launcher differs, so the tag is all there is to go on. Kept only so that an
	# older release still carries a player forward onto a launcher that knows
	# better; it is the old, over-eager behaviour and applies to nothing new.
	return tag != running_tag


## True when `tag` differs from what is installed. Deliberately not a semantic
## version comparison: the tag the CI published is the truth, and a launcher
## that tries to reason about version ordering will eventually refuse a valid
## rollback.
func differs_from(installed_tag: String) -> bool:
	return tag != installed_tag


func size_text() -> String:
	if asset_size <= 0:
		return "unknown size"
	return "%.1f MB" % (float(asset_size) / 1048576.0)
