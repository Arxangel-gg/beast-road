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
	_check_the_role_noun_comes_from_content()
	_check_the_beast_scope_names_yuri()
	print("[copy] %d player-facing strings scanned" % _scanned)
	for problem: String in _failures:
		push_error(problem)
	if _failures.is_empty():
		print("[copy] PASS - no enslavement language in anything a player reads, and the beast scope is Yuri's")
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


## The word for these leaders is content, and a screen must ask for it.
##
## `CaptiveData.role_noun` carries the noun - and its own comment explains why
## the examples on it matter, because "a doc comment offering the wrong word is
## how an unreviewed one gets in". `acquire_verb` beside it has been read by
## the town panel since the framing was flagged as unsettled. The noun was read
## by **nothing**, and the screens spelled it out themselves.
##
## That is not a language failure today - every screen says "Oathbound", which
## is the reviewed word - it is the review *surface* being wrong. §57 asks that
## the wording be reviewable in one place, and it cannot be while the screens
## carry their own copy of it.
## **The beast scope names Yuri, not "the beast".**
##
## `V4_CONFORMANCE` §6 has carried this as a `manual` row since it was written,
## on the reasoning that whether a name reads *well* is a judgement. Its target
## is not a judgement though - it is the literal words "not 'the beast'" - and
## the interface names that view in exactly two places: the scope button on the
## HUD nav bar and the row in the rebinding screen. Both are checkable, so the
## row is a gate now.
##
## **It was genuinely open rather than merely unjudged.** Both said "Beast", so
## the one part of the game that names that view named his species. The scope
## itself has no text at all - Yuri appears in `beast_scope.gd` only in a code
## comment - which is why reading the scope said the row was fine.
##
## Descriptive prose elsewhere is untouched and deliberately so: "the town rides
## the beast" and "a crop grows as the beast walks" are the common noun doing its
## job, and the glossary's "Yuri: the beast" is what teaches the name.
func _check_the_beast_scope_names_yuri() -> void:
	var places: Dictionary = {
		"res://scenes/ui/hud.gd": "scope_beast",
		"res://scripts/systems/key_bindings.gd": "&\"scope_beast\"",
	}
	for path: String in places:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_failures.append("[copy] %s is missing, so nothing names the beast scope" % path)
			continue
		var named: bool = false
		for line: String in file.get_as_text().split("
"):
			if not line.contains(String(places[path])):
				continue
			if line.contains("Yuri"):
				named = true
			elif line.contains("\"Beast") or line.contains("\"BEAST"):
				_failures.append(("[copy] %s names the beast scope after his species"
					% path) + " rather than after him: %s" % line.strip_edges())
		if not named:
			_failures.append(("[copy] %s no longer names the beast scope Yuri"
				% path) + " - V4_CONFORMANCE asks that scope for his name")


func _check_the_role_noun_comes_from_content() -> void:
	for value: Variant in ContentDB.captives.values():
		var who := value as CaptiveData
		if who == null:
			continue
		if who.role_noun.strip_edges().is_empty():
			_failures.append(("[copy] %s has no role_noun, so any screen naming"
				% who.id) + " it has to invent the word")
	# And somebody has to be asking. A field authored and read by nothing is
	# the same failure as a misspelt one: the review has a place to look and
	# the game does not use it.
	var asked: bool = false
	for path: String in ["res://scenes/ui/town_panel.gd",
			"res://scenes/ui/results_screen.gd", "res://scenes/city/town_scope.gd"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_as_text().contains("role_noun"):
			asked = true
	if not asked:
		_failures.append("[copy] no screen reads role_noun, so the noun the"
			+ " player sees is written in logic rather than content")
