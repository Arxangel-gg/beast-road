extends Node

## Every authored file actually became content.
##
## `ContentDB` warns and carries on when a `.tres` will not load — which is the
## right behaviour for a running game and the wrong behaviour for a build. The
## warning goes to stderr, the dictionary is quietly short, and every gate over
## that content keeps passing because it only ever asks about what *did* load.
##
## Found by doing it: five blueprints were authored with an unquoted
## `source_line`, so they failed to parse. `ranged_check` printed
## "6 plans … PASS" while eleven files sat on disk, and nothing said the five
## were missing. CI would have caught the warnings — `check` fails on any
## `WARNING:` line — but that is the harness noticing, not the gate, and a gate
## that reports a healthy number computed from broken input is worse than no
## number at all.
##
## So this counts the files on disk and compares. It is deliberately generic:
## it covers every content directory at once, including ones that do not exist
## yet, which is the only version of this check that cannot rot.

const DATA_ROOT: String = "res://data"

var _failures: int = 0
var _checked: int = 0
var _dirs: int = 0


func _ready() -> void:
	var root: DirAccess = DirAccess.open(DATA_ROOT)
	if root == null:
		_fail("no %s directory at all" % DATA_ROOT)
		_finish()
		return
	for folder: String in root.get_directories():
		_check_folder(DATA_ROOT.path_join(folder))
	_check(_dirs >= 20,
		"only %d content directories were walked; the roster should be far larger"
			% _dirs)
	_check(_checked >= 200,
		"only %d content files were checked; the roster should be far larger"
			% _checked)
	_finish()


func _check_folder(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	_dirs += 1
	var ids: Dictionary = {}
	for name: String in dir.get_files():
		# The same pair of suffixes `ContentDB` accepts: an exported build
		# renames `.tres` to `.tres.remap` and the loader wants the original.
		if not (name.ends_with(".tres") or name.ends_with(".tres.remap")):
			continue
		var file: String = path.path_join(name.trim_suffix(".remap"))
		_checked += 1

		var res: Resource = load(file)
		if res == null:
			_fail("%s did not load at all - it is authored but it is not content"
				% file)
			continue
		var data := res as GameData
		if data == null:
			_fail("%s loaded but is not a GameData, so ContentDB drops it" % file)
			continue
		if data.id.is_empty():
			_fail("%s has an empty id; ContentDB keys on the id and drops this"
				% file)
			continue
		# The filename has to *end with* the id rather than equal it. Relics are
		# authored as `relic_01.tres` carrying `id = "01"`, because the prefix
		# belongs to `GameData.derive_path` rather than to the id - so an equality
		# rule flags twenty-seven correct files and teaches everyone to ignore
		# this gate. Ending with it still catches the case that matters: a file
		# renamed without its id following, which leaves the art lookup pointing
		# somewhere the file no longer is.
		var stem: String = file.get_file().get_basename()
		if not stem.ends_with(data.id):
			_fail("%s declares id '%s'; the filename must end with the id, or "
					% [file, data.id]
				+ "the derived art path and the file part company")
		if ids.has(data.id):
			_fail("%s duplicates the id '%s'; ContentDB keeps the first and "
					% [file, data.id] + "silently drops the rest")
		ids[data.id] = true
		if data.display_name.is_empty():
			_fail("%s has no display_name, so it is drawn as an empty string"
				% file)


func _finish() -> void:
	if _failures == 0:
		print("[content] PASS - %d files across %d directories all became content"
			% [_checked, _dirs])
	else:
		push_error("[content] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if not condition:
		_fail(why)


func _fail(why: String) -> void:
	_failures += 1
	print("[content] %s" % why)
