class_name GddAudit
extends RefCounted

## Reports how much of GDD v4 actually exists.
##
## The v4 delta replaces most of the game: nine new enemies, three buildings,
## twenty-four hero nodes, four currencies, a new world, a new final boss, and
## three systems that do not exist at all — on top of a build that currently
## ships. At that size "how far along are we" stops being answerable by looking
## at the game, and "done" starts getting reported before it is true.
##
## So the checklist in `docs/V4_CONFORMANCE.md` is machine-read and this runs it.
## One number, every time, from the same source of truth.
##
##   godot --headless --path game --script res://tools/run_tool.gd -- audit
##   godot --headless --path game --script res://tools/run_tool.gd -- audit --todo
##
## **A probe is a smoke test, not proof.** `count:enemies >= 18` says eighteen
## files exist. It cannot say they are good enemies, that they are distinct, or
## that any of them is fun. Passing this is the floor. GDD §52's acceptance
## checklist and the kill questions are the ceiling, and neither is automatable.
##
## Manual rows are reported apart from the score and never counted as done —
## the moment a human judgement can be made to pass by a script, it stops being
## a human judgement.

const CHECKLIST: String = "res://../docs/V4_CONFORMANCE.md"

const DATA_DIR: String = "res://data/"
const BALANCE: String = "res://scripts/Balance.gd"
const EVENTBUS: String = "res://autoload/EventBus.gd"

## Where to look for `class_name X` and `func y`. Tools are excluded on purpose:
## they do not ship, so nothing in the GDD can be satisfied by one.
const SEARCH_ROOTS: Array[String] = [
	"res://autoload/", "res://scenes/", "res://scripts/",
]

## One row of the checklist.
class Row extends RefCounted:
	var section: String
	var item: String
	var target: String
	var probe: String
	var passed: bool = false
	var manual: bool = false
	var detail: String = ""


static func run(todo_only: bool = false) -> Dictionary:
	var rows: Array = _parse()
	if rows.is_empty():
		return {"ok": false, "text": "No checklist rows found in %s" % CHECKLIST,
			"done": 0, "total": 0}

	var index: Dictionary = _build_index()
	for row: Row in rows:
		_evaluate(row, index)

	return _report(rows, todo_only)


# --- Checklist ---------------------------------------------------------------

static func _parse() -> Array:
	var text: String = _read(CHECKLIST)
	if text.is_empty():
		return []

	var rows: Array = []
	var section: String = "General"
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("## "):
			section = trimmed.substr(3).strip_edges()
			continue
		if not trimmed.begins_with("|") or not trimmed.ends_with("|"):
			continue

		var cells: PackedStringArray = trimmed.substr(1, trimmed.length() - 2).split("|")
		if cells.size() != 3:
			continue
		var probe: String = cells[2].strip_edges().replace("`", "")
		# Skips the header and the ---|---|--- rule without needing to count lines.
		if probe.is_empty() or probe == "Probe" or probe.begins_with("-"):
			continue

		var row := Row.new()
		row.section = section
		row.item = cells[0].strip_edges()
		row.target = cells[1].strip_edges()
		row.probe = probe
		rows.append(row)
	return rows


# --- Probes ------------------------------------------------------------------

## Everything the probes need, gathered once. Forty probes each walking the
## script tree would read the same two hundred files forty times.
static func _build_index() -> Dictionary:
	var classes: Dictionary = {}
	var methods: Dictionary = {}
	for root: String in SEARCH_ROOTS:
		for path: String in _scripts_under(root):
			var owner: String = ""
			for line: String in _read(path).split("\n"):
				var trimmed: String = line.strip_edges()
				if trimmed.begins_with("class_name "):
					owner = trimmed.substr(11).split(" ")[0].strip_edges()
					classes[owner] = path
				elif trimmed.begins_with("func "):
					var name: String = trimmed.substr(5).split("(")[0].strip_edges()
					# Autoloads have no class_name, so they are keyed by file stem -
					# `MetaState.migrate_save` has to resolve even though nothing
					# declares `class_name MetaState`.
					var stem: String = path.get_file().get_basename()
					methods["%s.%s" % [stem, name]] = true
					if not owner.is_empty():
						methods["%s.%s" % [owner, name]] = true
	return {
		"classes": classes,
		"methods": methods,
		"balance": _read(BALANCE),
		"eventbus": _read(EVENTBUS),
	}


static func _evaluate(row: Row, index: Dictionary) -> void:
	var probe: String = row.probe

	if probe == "manual":
		row.manual = true
		row.detail = "human judgement"
		return

	if probe.begins_with("count:"):
		_probe_count(row, probe.substr(6))
	elif probe.begins_with("class:"):
		var name: String = probe.substr(6).strip_edges()
		row.passed = (index["classes"] as Dictionary).has(name)
		row.detail = "class_name %s" % name
	elif probe.begins_with("method:"):
		var target: String = probe.substr(7).strip_edges()
		row.passed = (index["methods"] as Dictionary).has(target)
		row.detail = "func %s" % target
	elif probe.begins_with("const:"):
		var name: String = probe.substr(6).strip_edges()
		row.passed = _declares(String(index["balance"]), "const %s" % name)
		row.detail = "Balance.%s" % name
	elif probe.begins_with("signal:"):
		var name: String = probe.substr(7).strip_edges()
		row.passed = _declares(String(index["eventbus"]), "signal %s" % name)
		row.detail = "EventBus.%s" % name
	elif probe.begins_with("file:"):
		var path: String = probe.substr(5).strip_edges()
		row.passed = ResourceLoader.exists(path) or FileAccess.file_exists(path)
		row.detail = path
	else:
		row.detail = "unknown probe '%s'" % probe


## `count:<dir> >= <n>`. Reports the actual number either way, because "12 of 18"
## is a burndown and "missing" is not.
static func _probe_count(row: Row, expression: String) -> void:
	var parts: PackedStringArray = expression.split(" ", false)
	if parts.size() != 3:
		row.detail = "malformed count probe"
		return

	var directory: String = DATA_DIR + parts[0].strip_edges() + "/"
	var wanted: int = int(parts[2])
	var found: int = _count_resources(directory)
	row.passed = (found >= wanted) if parts[1] == ">=" else (found == wanted)
	row.detail = "%d of %d in data/%s" % [found, wanted, parts[0]]


static func _count_resources(directory: String) -> int:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		return 0
	var total: int = 0
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			total += 1
		entry = dir.get_next()
	dir.list_dir_end()
	return total


## True when `declaration` starts a real line, so a mention inside a comment or
## a doc block does not count as an implementation.
static func _declares(text: String, declaration: String) -> bool:
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with(declaration):
			return true
	return false


# --- Report ------------------------------------------------------------------

static func _report(rows: Array, todo_only: bool) -> Dictionary:
	var lines: PackedStringArray = []
	var done: int = 0
	var total: int = 0
	var manual: int = 0

	var section: String = ""
	for row: Row in rows:
		if row.manual:
			manual += 1
		else:
			total += 1
			if row.passed:
				done += 1
		if todo_only and (row.passed or row.manual):
			continue
		if row.section != section:
			section = row.section
			lines.append("")
			lines.append("  %s" % section.to_upper())
		var mark: String = "[x]" if row.passed else ("[~]" if row.manual else "[ ]")
		lines.append("  %s %-42s %s" % [mark, row.item, row.detail])

	var percent: int = int(round(float(done) / float(maxi(total, 1)) * 100.0))
	var header: PackedStringArray = [
		"GDD v4 CONFORMANCE",
		"",
		"  %d of %d automatable checks pass  (%d%%)" % [done, total, percent],
		"  %d rows need a human and are not counted" % manual,
	]
	if todo_only:
		header.append("")
		header.append("  showing outstanding rows only")

	var footer: PackedStringArray = [
		"",
		"  A passing probe means the file or symbol exists. It does not mean the",
		"  feature is good, tuned, or fun - see GDD SS52 and the kill questions.",
	]

	return {
		"ok": true,
		"done": done,
		"total": total,
		"manual": manual,
		"text": "\n".join(header) + "\n" + "\n".join(lines) + "\n" + "\n".join(footer),
	}


# --- Files -------------------------------------------------------------------

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
