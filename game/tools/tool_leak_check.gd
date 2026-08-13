class_name ToolLeakCheck
extends RefCounted

## Fails the build if shipped code references a class that does not ship.
##
## `export_presets.cfg` sets `exclude_filter="tools/*"`, so every `class_name`
## declared under `res://tools/` is absent from an exported game. Referencing one
## from a shipped script is not a runtime error you can catch and log — GDScript
## fails to *parse* the file, so the script never loads at all. Anything that
## depended on it is simply not there.
##
## That is not theoretical. `hud.gd` held one such reference for a single
## release. The result was no HUD whatsoever and no tower slot wired to a click,
## and every headless gate passed the whole time, because they all run from
## source where `tools/` exists.
##
## The check is a grep, and a grep is the right tool: the failure is textual, it
## happens before any code runs, and there is nothing to instrument.

const TOOLS_DIR: String = "res://tools/"
const SHIPPED_ROOTS: Array[String] = [
	"res://autoload/", "res://scenes/", "res://scripts/",
]


## Returns {"ok": bool, "leaks": PackedStringArray, "checked": int}.
static func run() -> Dictionary:
	var tool_classes: PackedStringArray = _tool_class_names()
	var leaks: PackedStringArray = []
	var checked: int = 0

	for root: String in SHIPPED_ROOTS:
		for path: String in _scripts_under(root):
			checked += 1
			var text: String = _read(path)
			if text.is_empty():
				continue
			for name: String in tool_classes:
				for line_number: int in _lines_mentioning(text, name):
					leaks.append("%s:%d references %s, which is excluded from the export"
						% [path, line_number, name])

	return {"ok": leaks.is_empty(), "leaks": leaks, "checked": checked}


static func _tool_class_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for path: String in _scripts_under(TOOLS_DIR):
		for line: String in _read(path).split("\n"):
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("class_name "):
				names.append(trimmed.substr(11).split(" ")[0].strip_edges())
				break
	return names


## Line numbers where `name` appears as a whole word outside a comment or string.
##
## Comments are skipped deliberately: the fix for this bug is documented in the
## very files that must not *use* these classes, and a check that cannot tell an
## explanation from a reference would forbid explaining itself.
static func _lines_mentioning(text: String, name: String) -> Array[int]:
	var found: Array[int] = []
	var lines: PackedStringArray = text.split("\n")
	for i: int in lines.size():
		var line: String = lines[i]
		var comment: int = line.find("#")
		if comment >= 0:
			line = line.substr(0, comment)
		if line.strip_edges().is_empty():
			continue
		# Quoted text is data, not a symbol reference.
		line = _strip_quoted(line)
		var at: int = line.find(name)
		while at >= 0:
			var before: String = line[at - 1] if at > 0 else " "
			var after_index: int = at + name.length()
			var after: String = line[after_index] if after_index < line.length() else " "
			if not _is_word_char(before) and not _is_word_char(after) and before != ".":
				found.append(i + 1)
				break
			at = line.find(name, at + 1)
	return found


static func _strip_quoted(line: String) -> String:
	var out: String = ""
	var inside: bool = false
	for i: int in line.length():
		var c: String = line[i]
		if c == "\"":
			inside = not inside
			continue
		if not inside:
			out += c
	return out


static func _is_word_char(c: String) -> bool:
	return c == "_" or (c >= "0" and c <= "9") \
		or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func _scripts_under(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var path: String = root + entry
		if dir.current_is_dir():
			if not entry.begins_with("."):
				found.append_array(_scripts_under(path + "/"))
		elif entry.ends_with(".gd"):
			found.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
