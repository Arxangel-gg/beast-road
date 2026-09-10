extends Node

## A gate must never be able to write to the player's save.
##
## **This exists because one did.** `weapon_vfx_check` wipes the stash to
## simulate a fresh account, and run against a live save on 2026-08-31 it
## persisted that wipe: six identical starting weapons where a played account's
## gear had been. Nothing in the project could restore it - a stash is not in
## git, is not derived from content, and is not re-importable.
##
## The fix is one guard at the single place that writes, and this asserts three
## things about it: that a held save does not reach the disk, that the hold
## nests so two gates cannot un-block each other, and - the part that would
## otherwise rot - that every gate which mutates MetaState actually takes it.

## Tools known to edit `MetaState`, kept only as a floor under the scan below.
##
## **This used to be the whole test, and it rotted.** `trade_check` was written
## after it, rewrites the stash a dozen times, and was never added - so it wrote
## probe gear into the owner's own save on every local run for a day. A list
## somebody has to remember to extend is a list that is wrong the first time
## somebody does not.
##
## It survives as a floor: whatever the scan does or does not notice, these must
## still hold saves. Several of them mutate `MetaState` only by *playing* - a run
## payout, a codex entry recorded where the thing was met - which no amount of
## reading their text will ever see.
const KNOWN_MUTATING: Array[String] = [
	"res://tools/balance_test.gd",
	"res://tools/chronicle_check.gd",
	"res://tools/chronicle_goal_check.gd",
	"res://tools/crowd_check.gd",
	"res://tools/layout_check.gd",
	"res://tools/menu_layout_check.gd",
	"res://tools/support_diagnostics_check.gd",
	"res://tools/weapon_vfx_check.gd",
	"res://tools/discipline_check.gd",
	"res://tools/trade_check.gd",
]

## What counts as editing `MetaState`, as text.
##
## Deliberately generous. A read-only tool told to hold saves loses nothing - the
## hold only blocks writes it was not going to make - while a writer that is
## missed loses somebody's gear, so every ambiguity is resolved toward flagging.
## Assignment, indexed assignment, in-place array edits, and asking for a write
## outright.
const MUTATION_PATTERN: String = \
	"MetaState\\.[A-Za-z_]+\\s*(=[^=]|\\[[^\\]]*\\]\\s*=[^=]|\\.(append|clear|erase|assign|push_back|resize|remove_at|sort|shuffle|merge)\\b)"

## Calls that write the file or rewrite the account outright.
const MUTATION_CALLS: Array[String] = [
	"MetaState.save_game()",
	"MetaState.reset_progress",
	"MetaState.gain_",
	"MetaState.grant_",
	"MetaState.earn_",
	"MetaState.record_",
]

var _failures: int = 0


func _ready() -> void:
	_test_a_held_save_does_not_reach_the_disk()
	_test_holds_nest()
	_test_every_mutating_gate_holds()
	_test_the_one_writer_puts_the_file_back()

	if _failures == 0:
		print("[save-guard] PASS - gates cannot write to a player's save")
	else:
		push_error("[save-guard] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Writes to a scratch path, never the real one: a gate that proves saves are
## blocked by writing the real save would be the bug it is testing for.
func _test_a_held_save_does_not_reach_the_disk() -> void:
	var probe: String = "user://save_guard_probe.json"
	if FileAccess.file_exists(probe):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(probe))

	MetaState.hold_saves()
	_check(MetaState.saves_held(), "holding must report itself held")
	var before: String = _read_real_save()
	MetaState.save_game()
	_check(_read_real_save() == before,
		"a held save_game must leave the player's file untouched")
	MetaState.resume_saves()
	_check(not MetaState.saves_held(), "resuming must release the hold")


func _test_holds_nest() -> void:
	MetaState.hold_saves()
	MetaState.hold_saves()
	MetaState.resume_saves()
	_check(MetaState.saves_held(),
		"two holds must need two resumes, or one gate un-blocks another")
	MetaState.resume_saves()
	_check(not MetaState.saves_held(), "the last resume must release")
	# Never leave it held: a leaked hold would silently stop the game saving.
	MetaState.resume_saves()
	_check(not MetaState.saves_held(), "resume past zero must stay released")


## The assertion that stops this decaying. A gate added later that edits
## MetaState and forgets the hold is exactly the original bug again.
##
## **Found rather than listed.** Every tool in `res://tools/` is read and asked
## whether it writes to `MetaState`; whatever does must also hold saves. Nobody
## has to remember anything when they add a gate, which is the only version of
## this test that stays true.
func _test_every_mutating_gate_holds() -> void:
	var flagged: Dictionary = {}
	for path: String in _tool_scripts():
		var body: String = _read(path)
		if body.is_empty() or not _mutates(body):
			continue
		flagged[path] = true
		_check(body.contains("MetaState.hold_saves()"),
			"%s edits MetaState and must hold saves for its run" % path.get_file())

	# And the floor, independent of the scan: these are known to change the
	# account whether or not their text says so.
	for path: String in KNOWN_MUTATING:
		var body: String = _read(path)
		if not _check(not body.is_empty(), "%s is listed as mutating but is missing"
				% path.get_file()):
			continue
		_check(body.contains("MetaState.hold_saves()"),
			"%s changes the account and must hold saves for its run"
				% path.get_file())


## Tools that may not hold saves, with the reason, and what they owe instead.
##
## Exactly one, and it earns it: `codex_check`'s whole subject is that a
## discovery survives being written to disk and read back, which a held save
## would turn into a test of nothing. The price of the exemption is that it must
## put the player's file back, and that is asserted rather than trusted.
const MAY_WRITE_THE_FILE: Dictionary = {
	"res://tools/codex_check.gd": "_restore_the_save",
}


func _test_the_one_writer_puts_the_file_back() -> void:
	for path: String in MAY_WRITE_THE_FILE:
		var body: String = _read(path)
		if not _check(not body.is_empty(),
				"%s is exempt from holding saves but is missing" % path.get_file()):
			continue
		var owed: String = String(MAY_WRITE_THE_FILE[path])
		_check(body.contains("func %s(" % owed) and body.contains("\t%s()" % owed),
			("%s writes the player's save file and must call %s() to put it back"
				% [path.get_file(), owed]))


func _tool_scripts() -> PackedStringArray:
	var out := PackedStringArray()
	var dir: DirAccess = DirAccess.open("res://tools")
	if dir == null:
		_failures += 1
		print("[save-guard] could not read res://tools to scan it")
		return out
	for name: String in dir.get_files():
		# Exported builds serve `.gd` as `.gd.remap`; either name is the script.
		var script: String = name.trim_suffix(".remap")
		if not script.ends_with(".gd") or script == "save_guard_check.gd":
			continue
		var path: String = "res://tools/%s" % script
		if MAY_WRITE_THE_FILE.has(path):
			continue
		out.append(path)
	return out


func _mutates(body: String) -> bool:
	for call: String in MUTATION_CALLS:
		if body.contains(call):
			return true
	var rule := RegEx.new()
	if rule.compile(MUTATION_PATTERN) != OK:
		_failures += 1
		print("[save-guard] the mutation pattern does not compile")
		return false
	return rule.search(body) != null


func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var body: String = file.get_as_text()
	file.close()
	return body


func _read_real_save() -> String:
	var file: FileAccess = FileAccess.open(MetaState.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var body: String = file.get_as_text()
	file.close()
	return body


func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	print("[save-guard] %s" % why)
	return false
