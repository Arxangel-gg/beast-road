extends Node

## GDD §57: no unreviewed enslavement language ships.
##
##   godot --headless --path game res://tools/copy_check.tscn
##
## v4 deliberately rewrote the leader framing - sworn, ransomed or memorialised,
## never owned - and CLAUDE.md working rule 9 keeps player-facing strings in data
## so that the wording can be read in one place. What neither of those gives you
## is a way to *notice* when the old vocabulary comes back.
##
## The §57 copy review on 2026-08-25 found exactly that: the shipped `.tres`
## files carried the correct Oathbound wording, and `content_seeder.gd` - which
## regenerates them - still said "Captive", "Bind" and "is bound to the town and
## put to work". One seeder run from a release requirement being violated, by a
## file nobody would have thought to re-read.
##
## So the review is a gate now rather than a thing somebody remembers to do. It
## reads the same strings a player reads, plus the generator that writes them,
## because correcting generated content without correcting its generator leaves
## the old words in the only place that can put them back.

## Words that must not appear in anything a player reads.
##
## Deliberately blunt. A denylist that tries to be clever about context is a
## denylist that argues with you at three in the morning about whether this
## particular use was fine - and the answer §57 wants is that somebody reads it,
## not that a regex adjudicates it. A false positive costs a rename; a false
## negative ships.
const FORBIDDEN: Array[String] = [
	"slave", "enslav", "captive", "prisoner", "bondage", "chattel",
	"thrall", "shackle", "put to work", "work detail", "forced labour",
	"forced labor", "owned by", "property of", "in chains",
]

## Resource fields a player actually sees.
##
## Names, not values: scanning every field would trip on ids and file paths,
## which are code and are explicitly out of §57's scope - the class is still
## `CaptiveData` for save compatibility and that is fine, because nobody reads it.
const PLAYER_FACING: Array[String] = [
	"display_name", "description", "acquire_line", "role_noun", "acquire_verb",
	"effect_line", "eyebrow", "title", "body", "line", "flavour",
	"phase_names", "text", "hint", "label",
]

var _failures: PackedStringArray = []
var _scanned: int = 0


func _ready() -> void:
	_scan_data("res://data")
	_scan_seeder()
	print("[copy] %d player-facing strings scanned" % _scanned)
	for problem: String in _failures:
		push_error(problem)
	if _failures.is_empty():
		print("[copy] PASS - no enslavement language in anything a player reads")
	get_tree().quit(1 if not _failures.is_empty() else 0)


## Every `.tres` under `data/`, field by field.
func _scan_data(root: String) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var path: String = "%s/%s" % [root, name]
		if dir.current_is_dir():
			_scan_data(path)
		elif name.ends_with(".tres"):
			_scan_resource(path)
		name = dir.get_next()
	dir.list_dir_end()


func _scan_resource(path: String) -> void:
	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		return
	for field: String in PLAYER_FACING:
		if not (field in resource):
			continue
		var value: Variant = resource.get(field)
		if value is String:
			_judge(String(value), path, field)
		elif value is Array:
			for entry: Variant in value as Array:
				if entry is String:
					_judge(String(entry), path, field)


## The generator, as source text.
##
## Its string literals become the shipped `.tres` files, so they are player-
## facing however they are stored. This is the half that was actually wrong.
func _scan_seeder() -> void:
	var file: FileAccess = FileAccess.open(
		"res://tools/content_seeder.gd", FileAccess.READ)
	if file == null:
		return
	var line_number: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		line_number += 1
		# Comments are prose about the code, including this gate's own findings,
		# and are not shipped to anybody.
		if line.strip_edges().begins_with("#"):
			continue
		for quoted: String in _quoted_parts(line):
			_judge(quoted, "res://tools/content_seeder.gd", "line %d" % line_number)
	file.close()


## Every double-quoted run in a line of source.
func _quoted_parts(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var parts: PackedStringArray = line.split("\"")
	# Odd indices are inside quotes: a "b" c splits to [a, b, c].
	for index: int in range(1, parts.size(), 2):
		out.append(parts[index])
	return out


func _judge(value: String, path: String, field: String) -> void:
	if value.strip_edges().is_empty() or _is_code(value):
		return
	_scanned += 1
	var lowered: String = value.to_lower()
	for word: String in FORBIDDEN:
		if lowered.contains(word):
			_failures.append("[copy] %s (%s) says \"%s\" - GDD §57 forbids \"%s\" in player-facing copy"
				% [path, field, value, word])
			return


## True for strings that are identifiers rather than sentences.
##
## The one concession to false positives, and it is narrow on purpose: a resource
## path and a snake_case effect key are *code*, and §57 is explicit that the code
## may keep the old vocabulary - the class is still `CaptiveData` for save
## compatibility, and nobody reads it.
##
## The test is that player-facing copy has a space or a capital letter in it,
## which every line of it in this game does. Widening this any further would be
## how a real sentence gets waved through, so it should not be widened.
func _is_code(value: String) -> bool:
	if value.begins_with("res://") or value.begins_with("user://"):
		return true
	return not value.contains(" ") and value == value.to_lower()
