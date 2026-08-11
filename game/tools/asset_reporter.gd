class_name AssetReporter
extends RefCounted

## Scans res://art/ and reports which files are still placeholders and which
## have been replaced with real art (CLAUDE.md §4).
##
## The test is pixel (0,0): the generator sets it to pure magenta and no real
## painted asset will have that. The source PNG on disk is read directly rather
## than the imported texture, because import can recompress and this comparison
## has to be exact.
##
## It also cross-checks the manifest both ways. A file on disk that no manifest
## row asks for, or a size that does not match the row, is a bug — the manifest
## and the art folder are supposed to be the same list.

const MAGENTA: Color = Color(1.0, 0.0, 1.0, 1.0)
const ART_ROOT: String = "res://art"


## Returns a Dictionary with the counts and the formatted report text.
func report() -> Dictionary:
	var parser := ManifestParser.new()
	var assets: Array[ManifestAsset] = parser.parse()

	var expected: Dictionary = {}
	for a: ManifestAsset in assets:
		expected[a.res_path] = a

	var on_disk: PackedStringArray = _scan_pngs(ART_ROOT)
	on_disk.sort()

	var placeholders: PackedStringArray = []
	var real_art: PackedStringArray = []
	var unreadable: PackedStringArray = []
	var orphans: PackedStringArray = []
	var wrong_size: PackedStringArray = []

	for path: String in on_disk:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			unreadable.append(path)
			continue
		var is_placeholder: bool = _is_marker(img.get_pixel(0, 0))
		if is_placeholder:
			placeholders.append(path)
		else:
			real_art.append(path)

		if not expected.has(path):
			orphans.append(path)
			continue
		var spec: ManifestAsset = expected[path]
		if img.get_width() != spec.width or img.get_height() != spec.height:
			wrong_size.append("%s is %dx%d, manifest says %dx%d" % [
				path, img.get_width(), img.get_height(), spec.width, spec.height,
			])

	var missing: PackedStringArray = []
	for a: ManifestAsset in assets:
		if not FileAccess.file_exists(a.res_path):
			missing.append(a.res_path)
	missing.sort()

	var lines: PackedStringArray = []
	lines.append("BEAST ROAD — asset report")
	lines.append("=========================")
	lines.append("manifest: %s" % ManifestParser.manifest_path())
	lines.append("art root: %s" % ART_ROOT)
	lines.append("")
	lines.append("manifest rows : %d" % assets.size())
	lines.append("files on disk : %d" % on_disk.size())
	lines.append("placeholders  : %d   (pixel 0,0 is #FF00FF)" % placeholders.size())
	lines.append("real art      : %d" % real_art.size())
	lines.append("")

	_append_group(lines, "REAL ART (placeholder replaced)", real_art)
	_append_group(lines, "MISSING (in manifest, not on disk)", missing)
	_append_group(lines, "ORPHANS (on disk, not in manifest)", orphans)
	_append_group(lines, "WRONG SIZE", wrong_size)
	_append_group(lines, "UNREADABLE", unreadable)
	_append_group(lines, "PARSE PROBLEMS", parser.errors)

	var clean: bool = (
		missing.is_empty()
		and orphans.is_empty()
		and wrong_size.is_empty()
		and unreadable.is_empty()
		and parser.errors.is_empty()
	)
	if clean:
		if real_art.is_empty():
			lines.append("All %d manifest assets exist and every one is still a placeholder." % assets.size())
		else:
			lines.append("All %d manifest assets exist. %d have real art." % [assets.size(), real_art.size()])
	lines.append("")
	_append_group(lines, "STILL PLACEHOLDER", placeholders)

	return {
		"text": "\n".join(lines),
		"manifest_rows": assets.size(),
		"on_disk": on_disk.size(),
		"placeholders": placeholders.size(),
		"real_art": real_art.size(),
		"missing": missing.size(),
		"orphans": orphans.size(),
		"wrong_size": wrong_size.size(),
		"clean": clean,
	}


func _append_group(lines: PackedStringArray, title: String, entries: PackedStringArray) -> void:
	if entries.is_empty():
		return
	lines.append("%s — %d" % [title, entries.size()])
	for e: String in entries:
		lines.append("  " + e)
	lines.append("")


## 8-bit exact. A hand-painted pixel that lands on pure magenta by accident is
## possible in principle; at (0,0) of an asset drawn on transparency it is not.
func _is_marker(c: Color) -> bool:
	return is_equal_approx(c.r, 1.0) and is_equal_approx(c.g, 0.0) and is_equal_approx(c.b, 1.0)


func _scan_pngs(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var path: String = root.path_join(name)
		if dir.current_is_dir():
			found.append_array(_scan_pngs(path))
		elif name.get_extension().to_lower() == "png":
			found.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return found
