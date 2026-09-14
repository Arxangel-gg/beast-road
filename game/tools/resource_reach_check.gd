extends Node

## Every authored resource field is read by something, or written down as not.
##
##   godot --headless --path game res://tools/resource_reach_check.tscn
##
## `balance_reach_check` asks this of the tuning constants. **The same fault
## lives one layer down, in the data**, and it is harder to see there: an
## `@export` looks authoritative in the inspector, a `.tres` fills it in, and
## nothing consumes it. Found by hand on 2026-09-13, sixteen of them, and every
## one was a promise the content made that no code kept:
##
## - `boss_slam_knockback` - eleven bosses landing a telegraphed blow that
##   moved the player not at all.
## - `raid_charge_value` - a Siege Lizard worth 5 and a Salt Marcher worth 1
##   filling the war horn identically.
## - `is_channelled` - so every BEAM rooted the caster, including the two
##   Arcane lances that exist to keep them moving.
## - `work_multiplier` - every Oathbound leader worth the same shift, so which
##   one a raid won decided nothing.
## - `settle_line` and `offer_line` - sentences written for the player, in the
##   data, and never on a screen.
## - `contact_interval` - a per-breed swing cadence nothing consulted, beside a
##   constant that had been wrong about it since the day it was written.
## - `forge_value` - a careful ladder from 1 to 30, deleted rather than wired,
##   because its only coherent reading made the economy worse.
## - Ten factions' worth of identity copy, on `ContentDB.faction`, which had no
##   caller in the game at all.
##
## So it is counted now. **The list may shrink and may never grow.**
##
## Two ways a field is read, and the first draft of this missed the second: an
## attribute access `.name` from anywhere, and a *bare* name inside the script
## that declares it - a resource's own helper saying `return damage_near`.
## Counting only the first called eighteen live fields dead.
##
## A gate reading a field does not count, so `tools/` is excluded on purpose: a
## field whose only reader is an assertion about it is still a field the game
## ignores. `visual_identity` below is exactly that.

## Fields nothing in the game reads today, with the reason each is still here.
##
## **Shrink it whenever one is wired or removed.** A new entry is the thing this
## gate exists to make somebody argue for out loud.
const UNREAD: PackedStringArray = [
	# Authored for a codex entry that does not exist: `BlueprintData` is read
	# only by `loot_drop`, and no screen shows a blueprint's details. The line
	# is written and has nowhere to be shown.
	"blueprint_data.gd:source_line",
	# The two rosters a faction names are documentation rather than behaviour -
	# waves are built from `TerrainData`. `balance_test` cross-checks them
	# against the real roster so they cannot drift into fiction, which is the
	# most a documentation field can honestly be asked to do.
	"faction_data.gd:elite_enemy_ids",
	"faction_data.gd:regular_enemy_ids",
	# The act card shows a faction's `mechanical_identity`, which is the half a
	# player can act on. How a region looks is the one thing they can already
	# see out of the window; it is kept for the codex and previews it was
	# authored for, and asserted non-empty by `balance_test`.
	"faction_data.gd:visual_identity",
	# "How much darker the field reads, for the readability gate to account
	# for" - and there is no readability gate. Kept rather than deleted because
	# the number is right and the gate is a real thing to build.
	"weather_data.gd:gloom",
]

const RESOURCES: String = "res://scripts/resources"
const SELF_PATH: String = "res://tools/resource_reach_check.gd"
const ROOTS: PackedStringArray = ["res://scripts", "res://scenes",
	"res://autoload"]

var _failures: PackedStringArray = []
var _checks: int = 0
var _game_code: String = ""


func _ready() -> void:
	MetaState.hold_saves()
	_game_code = _every_game_script()
	var unread: PackedStringArray = _unread_fields()
	_test_every_field_is_read_or_listed(unread)
	_test_the_list_names_only_unread_fields(unread)
	_test_the_list_has_not_grown()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[resource-reach] PASS - %d checks: %d fields listed as unread"
			% [_checks, UNREAD.size()])
	else:
		for failure: String in _failures:
			push_error("[resource-reach] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## Everything that could read a field, as one string - and never `tools/`.
func _every_game_script() -> String:
	var parts: PackedStringArray = []
	for root: String in ROOTS:
		_gather(root, parts)
	return "\n".join(parts)


func _gather(path: String, into: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var full: String = path.path_join(name)
		if directory.current_is_dir():
			_gather(full, into)
		elif name.ends_with(".gd") and full != SELF_PATH:
			var file := FileAccess.open(full, FileAccess.READ)
			if file != null:
				into.append(_code_only(file.get_as_text()))
		name = directory.get_next()
	directory.list_dir_end()


## Every `script.gd:field` the game does not read.
func _unread_fields() -> PackedStringArray:
	var out: PackedStringArray = []
	var directory := DirAccess.open(RESOURCES)
	if directory == null:
		return out
	var declaration := RegEx.create_from_string(
		"(?m)^@export[^\\n]*\\bvar\\s+([a-z_][a-z0-9_]*)\\s*[:=]")
	var header := RegEx.create_from_string("(?m)^@export[^\\n]*\\n")
	var files: PackedStringArray = []
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		if not directory.current_is_dir() and name.ends_with(".gd"):
			files.append(name)
		name = directory.get_next()
	directory.list_dir_end()
	files.sort()

	for file_name: String in files:
		var file := FileAccess.open(RESOURCES.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		# Its own declarations are not a use of the thing being declared, and
		# only the declaration goes - cutting whole lines would hide every
		# helper in the file, which is how the first draft called live fields
		# dead.
		# Comments out here too, and for the same reason: a resource's own
		# docstrings name its fields constantly - "`boss_slam_damage` is a
		# multiple of `contact_damage`" - so every field in the file would
		# read as used by the paragraph describing it.
		var own: String = _code_only(header.sub(text, "", true))
		for found: RegExMatch in declaration.search_all(text):
			var field: String = found.get_string(1)
			if _reads(_game_code, field) or _names_it(own, field):
				continue
			out.append("%s:%s" % [file_name, field])
	return out


## The same text with its whole-line comments taken out.
##
## **Prose is not a reader, and this gate passed on prose once.** Unwiring
## `raid_charge_value` to check the gate could fail left it green, because the
## docstring on the function that had just stopped reading it still said
## `EnemyData.raid_charge_value` - and that contains `.raid_charge_value`. A
## gate a comment can satisfy is worse than no gate, since it reports on the
## explanation rather than the code.
##
## Whole-line comments only. An inline `#` can sit inside a string literal -
## a colour, a URL fragment - and cutting from there would eat real code to
## catch a rarer case than the one that actually bit.
func _code_only(text: String) -> String:
	var kept: PackedStringArray = []
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


## An attribute access, or the name in quotes for a `get()` / `set()`.
func _reads(code: String, field: String) -> bool:
	return code.contains("." + field) or code.contains('"%s"' % field)


## A bare mention inside the script that declares it, on a word boundary, so
## `far` does not match `farm` and call a dead field live.
func _names_it(own: String, field: String) -> bool:
	var finder := RegEx.create_from_string("\\b%s\\b" % field)
	return finder != null and finder.search(own) != null


func _test_every_field_is_read_or_listed(unread: PackedStringArray) -> void:
	# A sanity floor: if the scan finds nothing at all it has stopped working,
	# and an empty result would read as a clean bill of health.
	_check(not _game_code.is_empty(), "no game scripts were read at all")
	for entry: String in unread:
		_check(UNREAD.has(entry),
			("%s is authored and nothing in the game reads it. Wire it, delete "
				+ "it, or add it to UNREAD with a reason - a field the content "
				+ "fills in and no system consumes is a promise nobody keeps")
				% entry)


## And the list may not name a field that is read now, or one that is gone.
func _test_the_list_names_only_unread_fields(unread: PackedStringArray) -> void:
	for entry: String in UNREAD:
		_check(unread.has(entry),
			("UNREAD names %s, which is either read now or no longer exists - "
				+ "take it off the list") % entry)


## The count is a ratchet.
func _test_the_list_has_not_grown() -> void:
	# Sixteen when this seam was opened, five by the time the gate was written.
	# Lowering it is the point; raising it is what this exists to make somebody
	# say out loud.
	_check(UNREAD.size() <= 5,
		("%d fields are listed as read by nothing, against the 5 this gate was "
			+ "written at. The list is a ratchet: it may shrink and may not "
			+ "grow") % UNREAD.size())
