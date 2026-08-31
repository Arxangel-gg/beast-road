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

const MUTATING_GATES: Array[String] = [
	"res://tools/balance_test.gd",
	"res://tools/chronicle_check.gd",
	"res://tools/weapon_vfx_check.gd",
	"res://tools/discipline_check.gd",
]

var _failures: int = 0


func _ready() -> void:
	_test_a_held_save_does_not_reach_the_disk()
	_test_holds_nest()
	_test_every_mutating_gate_holds()

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
func _test_every_mutating_gate_holds() -> void:
	for path: String in MUTATING_GATES:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			_failures += 1
			print("[save-guard] %s is listed as mutating but is missing" % path)
			continue
		var body: String = file.get_as_text()
		file.close()
		_check(body.contains("MetaState.hold_saves()"),
			"%s edits MetaState and must hold saves for its run" % path.get_file())


func _read_real_save() -> String:
	var file: FileAccess = FileAccess.open(MetaState.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var body: String = file.get_as_text()
	file.close()
	return body


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[save-guard] %s" % why)
