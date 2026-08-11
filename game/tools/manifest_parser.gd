class_name ManifestParser
extends RefCounted

## Reads docs/ASSET_MANIFEST.md §5 and returns the full asset list.
##
## The manifest is the single source of truth for what art exists (CLAUDE.md §4)
## and it is written for humans first, so this parser has to cope with three
## different ways a section lists its assets:
##
##   1. A full table:      | `hero_base.png` | 128x128 | T | `#E8A33D` |
##   2. A partial table plus a prose default:
##      "All 128x192, type T."  then  | `tower_ember_spire.png` | Fire | `#C4552E` |
##   3. No table at all, just a prose default and an inline list, sometimes
##      with a numeric range:  Files: `relic_01.png` ... `relic_20.png`
##
## Anything a row does not state falls back to the section's prose default.
## Parsing is bounded to section 5 so the prompt tables in section 6 — which
## also mention asset names — are never mistaken for asset requirements.

## The manifest lives outside the Godot project root, so it is read through an
## absolute OS path rather than res://.
const MANIFEST_RELATIVE_PATH: String = "../docs/ASSET_MANIFEST.md"

var errors: PackedStringArray = []


## Absolute path to the manifest, derived from the project location.
static func manifest_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(MANIFEST_RELATIVE_PATH).simplify_path()


func parse() -> Array[ManifestAsset]:
	errors = []
	var path: String = manifest_path()
	if not FileAccess.file_exists(path):
		errors.append("Manifest not found at %s" % path)
		return []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Could not open manifest at %s" % path)
		return []
	var text: String = file.get_as_text()
	file.close()
	return parse_text(text)


func parse_text(text: String) -> Array[ManifestAsset]:
	var re_section := RegEx.create_from_string("^###\\s+(5\\.\\d+[^\\n]*?)\\s*$")
	var re_folder := RegEx.create_from_string("`res://art/([A-Za-z0-9_/]+?)/?`")
	# The size separator is U+00D7 MULTIPLICATION SIGN in the manifest, and the
	# range separator is U+2026 HORIZONTAL ELLIPSIS. Both are written as GDScript
	# escapes so the literal character reaches PCRE2 — "\u" is not a PCRE escape.
	var re_default_size := RegEx.create_from_string("[Aa]ll\\s+(\\d+)\\s*[×xX]\\s*(\\d+)\\s*,\\s*type\\s+([TO])")
	var re_colour := RegEx.create_from_string("#([0-9A-Fa-f]{6})")
	var re_size := RegEx.create_from_string("^(\\d+)\\s*[×xX]\\s*(\\d+)$")
	var re_png := RegEx.create_from_string("`([A-Za-z0-9_\\-./]+\\.png)`")
	var re_ellipsis := RegEx.create_from_string("[…]|\\.\\.\\.")

	var assets: Array[ManifestAsset] = []
	var seen: Dictionary = {}

	var section_name: String = ""
	var folder: String = ""
	var def_w: int = 0
	var def_h: int = 0
	var def_transparent: bool = true
	var def_colour: Color = Color.MAGENTA
	var def_colour_set: bool = false
	var in_section_5: bool = false

	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()

		# Section 5 is the machine-read part. Section 6 onward is prose prompts
		# that mention the same asset names, so it must not be parsed.
		if line.begins_with("## "):
			in_section_5 = line.begins_with("## 5.")
			continue
		if not in_section_5:
			continue

		var m_section := re_section.search(line)
		if m_section != null:
			section_name = m_section.get_string(1).strip_edges()
			var m_folder := re_folder.search(line)
			folder = m_folder.get_string(1) if m_folder != null else ""
			# Every section restates its own defaults; never inherit the last one.
			def_w = 0
			def_h = 0
			def_transparent = true
			def_colour = Color.MAGENTA
			def_colour_set = false
			continue

		if folder.is_empty():
			continue

		# Notes and callouts never declare assets.
		if line.begins_with(">"):
			continue

		# "All 128x192, type T." / "All 96x96, type T, placeholder colour `#9B8FC4`."
		var m_default := re_default_size.search(line)
		if m_default != null:
			def_w = m_default.get_string(1).to_int()
			def_h = m_default.get_string(2).to_int()
			def_transparent = m_default.get_string(3) == "T"
			var m_def_colour := re_colour.search(line)
			if m_def_colour != null:
				def_colour = Color.from_string("#" + m_def_colour.get_string(1), Color.MAGENTA)
				def_colour_set = true
			continue

		var names: PackedStringArray = []
		var row_w: int = def_w
		var row_h: int = def_h
		var row_transparent: bool = def_transparent
		var row_colour: Color = def_colour
		var row_colour_set: bool = def_colour_set

		if line.begins_with("|"):
			# Table row. Column order varies between sections, so each cell is
			# identified by what it looks like rather than by its position.
			for cell_raw: String in line.split("|"):
				var cell: String = cell_raw.strip_edges()
				if cell.is_empty():
					continue
				var m_png := re_png.search(cell)
				if m_png != null:
					names.append(m_png.get_string(1))
					continue
				var stripped: String = cell.replace("`", "").strip_edges()
				var m_size := re_size.search(stripped)
				if m_size != null:
					row_w = m_size.get_string(1).to_int()
					row_h = m_size.get_string(2).to_int()
					continue
				if stripped == "T" or stripped == "O":
					row_transparent = stripped == "T"
					continue
				var m_cell_colour := re_colour.search(stripped)
				if m_cell_colour != null:
					row_colour = Color.from_string("#" + m_cell_colour.get_string(1), Color.MAGENTA)
					row_colour_set = true
			if names.is_empty():
				continue  # header or separator row
		else:
			# Prose list: `spell_rift_step.png` . `spell_cinder_nova.png` . ...
			# or a numeric range: `relic_01.png` ... `relic_20.png`
			names = _names_from_prose(line, re_png, re_ellipsis)
			if names.is_empty():
				continue

		for name: String in names:
			var asset := ManifestAsset.new()
			asset.res_path = "res://art/%s/%s" % [folder, name]
			asset.width = row_w
			asset.height = row_h
			asset.transparent = row_transparent
			asset.colour = row_colour
			asset.section = section_name

			if not asset.is_valid():
				errors.append("%s: no size given and no section default (%s)" % [asset.res_path, section_name])
				continue
			if not row_colour_set:
				errors.append("%s: no placeholder colour given (%s)" % [asset.res_path, section_name])
			if seen.has(asset.res_path):
				errors.append("%s: listed more than once" % asset.res_path)
				continue
			seen[asset.res_path] = true
			assets.append(asset)

	return assets


## Pulls every backticked *.png out of a prose line, expanding "a ... b" into
## the numbered files between a and b.
func _names_from_prose(line: String, re_png: RegEx, re_ellipsis: RegEx) -> PackedStringArray:
	var matches: Array[RegExMatch] = re_png.search_all(line)
	if matches.is_empty():
		return PackedStringArray()

	var ellipses: Array[RegExMatch] = re_ellipsis.search_all(line)
	var out: PackedStringArray = []
	for i: int in matches.size():
		out.append(matches[i].get_string(1))
		if i + 1 >= matches.size():
			continue
		# An ellipsis sitting between two names means "and everything between".
		var gap_start: int = matches[i].get_end(0)
		var gap_end: int = matches[i + 1].get_start(0)
		for e: RegExMatch in ellipses:
			if e.get_start(0) >= gap_start and e.get_end(0) <= gap_end:
				out.append_array(_expand_range(matches[i].get_string(1), matches[i + 1].get_string(1)))
				break
	return out


## "relic_01.png" .. "relic_20.png" -> relic_02.png through relic_19.png.
## The endpoints are already in the list, so only the interior is generated.
func _expand_range(first: String, last: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var a: String = first.get_basename()
	var b: String = last.get_basename()
	var a_digits: String = _trailing_digits(a)
	var b_digits: String = _trailing_digits(b)
	if a_digits.is_empty() or b_digits.is_empty():
		errors.append("Range '%s .. %s' does not end in numbers" % [first, last])
		return out
	var prefix: String = a.substr(0, a.length() - a_digits.length())
	if prefix != b.substr(0, b.length() - b_digits.length()):
		errors.append("Range '%s .. %s' has mismatched prefixes" % [first, last])
		return out
	var from: int = a_digits.to_int()
	var to: int = b_digits.to_int()
	if to <= from:
		errors.append("Range '%s .. %s' does not count upward" % [first, last])
		return out
	var pad: int = a_digits.length()
	for n: int in range(from + 1, to):
		out.append("%s%s.png" % [prefix, str(n).pad_zeros(pad)])
	return out


func _trailing_digits(s: String) -> String:
	var i: int = s.length()
	while i > 0 and s[i - 1] >= "0" and s[i - 1] <= "9":
		i -= 1
	return s.substr(i)
