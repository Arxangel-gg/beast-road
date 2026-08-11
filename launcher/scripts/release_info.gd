class_name ReleaseInfo
extends RefCounted

## One GitHub release, reduced to the four things the launcher cares about.

var tag: String = ""
var title: String = ""
var notes: String = ""
var asset_url: String = ""
var asset_name: String = ""
var asset_size: int = 0


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
		if not name.to_lower().ends_with(".zip"):
			continue
		if not name.to_lower().contains(LauncherConfig.GAME_ASSET_MARKER):
			continue
		info.asset_name = name
		info.asset_url = String(asset.get("browser_download_url", ""))
		# JSON numbers arrive as floats in Godot; a byte count is not a float.
		info.asset_size = int(asset.get("size", 0))
		break
	return info


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
