extends Node

## Several Wardens on one machine, and the first of them is the file that was
## already there.
##
##   godot --headless --path game res://tools/save_slot_check.tscn
##
## **Slot 0 is the historic save**, and everything else in this gate is
## downstream of that. A player's save is the one thing in this project git
## cannot restore, so save slots were built to add files rather than to move
## one: an existing account is slot 0 by *derivation* - no migration, no
## rename, no version bump - and the first launch after slots shipped reads
## exactly the file the last launch before them wrote.
##
## The literal path is written out below rather than read from
## `MetaState.SAVE_PATH`, deliberately. Comparing the constant to itself would
## pass on a build that renamed it, which is the failure that would cost every
## player their account at once - the same reasoning `user_dir_check` holds the
## pinned user directory as a literal.
##
## **Everything that writes is pointed at a fixture first.** `MetaState.slot_root`
## is the documented seam: with it moved, the doors under test are the real
## `use_slot`, `erase_slot`, `load_save` and `save_game`, and a developer's own
## Wardens are not merely protected by the save hold - they are not on any path
## this gate can reach. Saves are held either side of that window, and the
## fixture is removed at the end.

## The name a player's save has had since the game shipped. If this gate fails
## on this line, do not change this line.
const HISTORIC_SAVE: String = "user://beast_road_save.json"
const HISTORIC_BACKUP: String = "user://beast_road_save.v%d.bak.json"
const HISTORIC_UNREADABLE: String = "user://beast_road_save.unreadable.%d.bak.json"

const FIXTURE_DIR: String = "res://.automated_checks/save_slots"
const FIXTURE_BASE: String = FIXTURE_DIR + "/probe.json"

var _failures: int = 0
var _checked: int = 0
var _saved_root: String = ""
var _saved_slot: int = 0
var _saved_phase: int = 0


func _ready() -> void:
	# Held first, before anything is read: everything below rewrites the live
	# autoload, and the whole subject of this gate is where a save lands.
	MetaState.hold_saves()
	_saved_root = MetaState.slot_root
	_saved_slot = MetaState.slot()
	_saved_phase = int(RunState.phase)

	# With the shipping root, before it is moved anywhere.
	_test_slot_zero_is_the_historic_file()

	_open_the_fixture()
	# The root is already moved, so a write can no longer name a real slot.
	# Resumed rather than held because the subject is two *files* not seeing
	# each other, and a held save would make that a test of nothing - the same
	# exemption `codex_check` earns, narrowed by the fixture.
	MetaState.resume_saves()

	_test_two_wardens_do_not_see_each_other()
	_test_a_new_slot_is_a_new_account()
	_test_switching_is_refused_during_a_run()
	_test_an_absent_slot_reads_as_empty()
	_test_a_malformed_pointer_reads_as_slot_zero()
	_test_erasing_one_leaves_the_others()
	_test_the_backup_rule_holds_per_slot()
	_test_no_shipping_path_skips_the_derivation()

	MetaState.hold_saves()
	_close_the_fixture()

	if _failures == 0:
		print("[save-slots] PASS - %d checks; slot 0 is the historic file and "
			% _checked + "no two Wardens share one")
	else:
		push_error("[save-slots] FAIL - %d of %d" % [_failures, _checked])
	# Never leave it held: a leaked hold would silently stop the game saving.
	MetaState.resume_saves()
	get_tree().quit(1 if _failures > 0 else 0)


# --- The invariant everything else rests on ----------------------------------

## The historic file, by name, and the historic backups with it.
##
## Four names, because a rename of any one of them is a different account lost:
## the save itself, the versioned backup a build that cannot read it keeps, the
## unreadable copy, and the temporary sibling an atomic write goes through.
func _test_slot_zero_is_the_historic_file() -> void:
	_check(MetaState.slot_root == HISTORIC_SAVE,
		("a shipping build must start with the historic save as its root, not %s"
			% MetaState.slot_root))
	_check(MetaState.slot_path(0) == HISTORIC_SAVE,
		"slot 0 must be %s, not %s" % [HISTORIC_SAVE, MetaState.slot_path(0)])
	_check(MetaState.slot_backup_path(0, MetaState.SAVE_VERSION)
			== HISTORIC_BACKUP % MetaState.SAVE_VERSION,
		"slot 0's version backup moved off the name players' disks already have")
	_check(MetaState.slot_unreadable_path(0, 1234) == HISTORIC_UNREADABLE % 1234,
		"slot 0's unreadable backup moved off its historic name")
	# And the two constants the rest of the project still reads.
	_check(MetaState.SAVE_PATH == HISTORIC_SAVE,
		"MetaState.SAVE_PATH is no longer the historic save path")
	_check(MetaState.SAVE_VERSION == 7,
		("SAVE_VERSION moved. A slot is an ordinary save in the ordinary format, "
			+ "so adding slots must not have bumped it; if the schema genuinely "
			+ "changed for another reason, change this number and say why"))

	# **The pointer is not in a slot.** A slot is an ordinary save and carries
	# no idea which slot it is, so no save key was added and `balance_test`'s
	# top-level allowlist is untouched.
	_check(MetaState.slot_pointer_path() != MetaState.slot_path(0),
		"the active-slot pointer must be its own file, not the save")
	var written: Dictionary = MetaState.parse_save_text(MetaState.serialized_save())
	_check(not written.has("slot") and not written.has("slots"),
		"which slot is active must not be written into a save")

	# Every later slot is a file of its own, and no two collide.
	var seen: Dictionary = {}
	for index: int in Balance.SAVE_SLOTS:
		var path: String = MetaState.slot_path(index)
		_check(not seen.has(path), "slots %s and %d resolve to the same file"
			% [str(seen.get(path, -1)), index])
		seen[path] = index
	_check(Balance.SAVE_SLOTS >= 2,
		"a cap below two is not save slots")
	# Out of range must not silently name a real slot's file to write over.
	_check(not MetaState.use_slot(Balance.SAVE_SLOTS),
		"an index past the cap was accepted as a slot")
	_check(not MetaState.use_slot(-1), "a negative index was accepted as a slot")


# --- Two Wardens -------------------------------------------------------------

## **Write distinct Wardens, switch, read both back.**
##
## The failure this catches is the whole feature going wrong at once: one file
## under two names, or a switch that loads the new slot over the old one's
## fields without clearing them. Both look perfectly ordinary on screen - the
## second Warden simply *is* the first - and neither errors.
func _test_two_wardens_do_not_see_each_other() -> void:
	RunState.set_phase(RunState.Phase.ENDED)
	_be_slot(0)
	_write_a_warden("Ardwin", 11, 111)

	_check(MetaState.use_slot(1), "the second slot could not be entered")
	_check(MetaState.slot() == 1, "entering a slot did not change which is live")
	_check(MetaState.player_name != "Ardwin",
		("the second Warden arrived wearing the first one's name, so a switch "
			+ "does not clear the account"))
	_write_a_warden("Belisent", 42, 4242)

	# The first one's file, on disk, untouched by any of that.
	var first: Dictionary = MetaState.slot_summary(0)
	_check(bool(first.get("exists", false)), "the first Warden's file went missing")
	_check(String(first.get("name", "")) == "Ardwin",
		"the first Warden is now called %s" % first.get("name", ""))
	_check(int(first.get("level", 0)) == 11,
		"the first Warden's level followed the second's")
	_check(int(first.get("marks", 0)) == 111,
		"the first Warden's Marks followed the second's")
	var second: Dictionary = MetaState.slot_summary(1)
	_check(String(second.get("name", "")) == "Belisent"
			and int(second.get("level", 0)) == 42 and int(second.get("marks", 0)) == 4242,
		"the live Warden's card does not describe the live Warden")
	_check(bool(second.get("current", false)) and not bool(first.get("current", false)),
		"the card does not say which Warden is being played")

	# And back. The first one is read off its own file rather than remembered.
	_check(MetaState.use_slot(0), "the first slot could not be returned to")
	_check(MetaState.player_name == "Ardwin" and MetaState.hero_level == 11
			and MetaState.marks == 111,
		"going back read something other than the first Warden")
	# The one this project loses gear to: a container carried across rather
	# than cleared. The pen, the stable and the pantry are three different
	# shapes and all three go through the same reset.
	_check(MetaState.pen.is_empty() and MetaState.mounts.is_empty()
			and MetaState.fish.is_empty(),
		"a Warden is carrying something the other one collected")
	_check(MetaState.use_slot(1) and MetaState.player_name == "Belisent",
		"the second Warden did not survive being left and returned to")
	_be_slot(0)


## **A slot nobody has played is a new account**, which is more than an empty
## one: it has the opening weapon, has not been taught the game and has not
## seen the cinematics. Those three live in `settings`, which is deliberately
## *kept* across a switch - so without `_clear_account_progress_settings` a
## second Warden would begin unarmed and untaught and nothing would say why.
func _test_a_new_slot_is_a_new_account() -> void:
	RunState.set_phase(RunState.Phase.ENDED)
	_be_slot(0)
	_erase_files_for(2)
	# **Played first, or this measures nothing.** A CI profile is a new account
	# already: its tutorial is unseen and its cinematic list is empty, so
	# switching to an empty slot from it reads "new" whether or not anything
	# resets. The Warden being left has to be a *played* one - the shape this
	# project has been caught by before, where a clean profile hid half a panel.
	MetaState.settings["tutorial_seen"] = true
	MetaState.settings[MetaState.MILESTONE_CINEMATICS_SEEN_KEY] = ["already_watched"]
	MetaState.settings[MetaState.STARTING_GEAR_KEY] = true
	MetaState.settings[UserSettings.VOLUME_KEYS[0]] = 0.31
	MetaState.stash = []
	MetaState.equipped = {}
	_check(MetaState.use_slot(2), "an unplayed slot could not be entered")
	_check(MetaState.stash.size() >= 1,
		"a new Warden began with an empty stash and no weapon in hand")
	_check(not bool(MetaState.settings.get("tutorial_seen", true)),
		"a new Warden was treated as having already been taught the game")
	_check((MetaState.settings.get(MetaState.MILESTONE_CINEMATICS_SEEN_KEY, [1]) as Array).is_empty(),
		"a new Warden was treated as having seen the cinematics")
	_check(MetaState.hero_level == 1 and MetaState.marks == 0
			and MetaState.ascension == 0 and MetaState.tools == 0,
		"a new Warden did not start at the bottom of every ladder")
	# **A preference is not progress and must survive**, which is the other
	# half of the same decision: wiping somebody's volume because they made a
	# second Warden would be a second, unasked-for destruction.
	_check(is_equal_approx(float(MetaState.settings.get(UserSettings.VOLUME_KEYS[0], 1.0)), 0.31),
		"a new Warden reset a preference that belongs to the person, not the account")
	_be_slot(0)


# --- The refusals ------------------------------------------------------------

## **Not mid-run**, which is the rule `pen_take` already holds and for a
## sharper reason: a road is banked at a crossroad, so switching Warden while
## one is under way abandons a front the player never chose to give up - and
## the other slot's menu looks entirely ordinary afterwards.
func _test_switching_is_refused_during_a_run() -> void:
	RunState.set_phase(RunState.Phase.ENDED)
	_be_slot(0)
	_write_a_warden("Ardwin", 11, 111)
	MetaState.use_slot(1)
	_write_a_warden("Belisent", 42, 4242)
	_be_slot(0)

	# A road is live only while the director says so. Every phase is walked
	# with one, and then without - the second half is the owner's report of
	# 2026-09-22: on a fresh launch, and after a road left from the pause menu,
	# the phase is still `PREPARATION` and no road exists, and the picker
	# refused anyway.
	GameDirector.run_active = true
	for phase: int in [RunState.Phase.PREPARATION, RunState.Phase.ROAD_BATTLE,
			RunState.Phase.BOSS, RunState.Phase.RAID, RunState.Phase.FINAL_ASCENT]:
		RunState.set_phase(phase as RunState.Phase)
		_check(not MetaState.use_slot(1),
			"the Warden was changed mid-run, in phase %d" % phase)
		_check(MetaState.slot() == 0 and MetaState.player_name == "Ardwin",
			"a refused switch still moved the account, in phase %d" % phase)
		_check(not MetaState.erase_slot(1),
			"a slot was erased mid-run, in phase %d" % phase)
		_check(FileAccess.file_exists(MetaState.slot_path(1)),
			"a refused erase still took the file, in phase %d" % phase)
	GameDirector.run_active = false
	RunState.set_phase(RunState.Phase.PREPARATION)
	_check(MetaState.use_slot(1) and MetaState.slot() == 1,
		("with no road live the Warden could not be changed, because the phase "
			+ "still read PREPARATION - which is every fresh launch and every "
			+ "road left from the pause menu"))
	_be_slot(0)
	RunState.set_phase(RunState.Phase.ENDED)

	# And never the slot being played, whatever the phase. Erasing the account
	# you are standing in is `erase_progress` in Settings: a different door,
	# with its own confirmation, that does not leave the game writing to a file
	# it has just deleted.
	_check(not MetaState.erase_slot(0), "the live slot erased itself")
	_check(MetaState.use_slot(1) and not MetaState.erase_slot(1),
		"the live slot erased itself from slot 1")
	_be_slot(0)
	# Slot 0 is never erasable from here, live or not.
	_check(not MetaState.erase_slot(0) and FileAccess.file_exists(MetaState.slot_path(0)),
		"the historic save can be deleted from the slot picker")


## An absent slot is a card that says "empty", never an error and never another
## slot's contents leaking into the answer.
func _test_an_absent_slot_reads_as_empty() -> void:
	RunState.set_phase(RunState.Phase.ENDED)
	_be_slot(0)
	_write_a_warden("Ardwin", 11, 111)
	_erase_files_for(3)
	var empty: Dictionary = MetaState.slot_summary(3)
	_check(not bool(empty.get("exists", false)), "an absent slot read as played")
	_check(String(empty.get("name", "")).is_empty() and int(empty.get("level", 0)) == 0
			and int(empty.get("marks", 0)) == 0 and int(empty.get("played", 0)) == 0,
		"an absent slot reported somebody's figures")
	# Out of range is the same answer rather than a crash or a clamp onto a real
	# slot, which is what a screen built against a stale cap would ask for.
	var beyond: Dictionary = MetaState.slot_summary(Balance.SAVE_SLOTS + 5)
	_check(not bool(beyond.get("exists", false)) and not bool(beyond.get("current", false)),
		"an index past the cap described a real slot")
	# A file that is there and unreadable is also not a Warden.
	_write_text(MetaState.slot_path(3), "{\"version\": 7, \"hero\": {\"lev")
	var broken: Dictionary = MetaState.slot_summary(3)
	_check(not bool(broken.get("exists", false)),
		"a save that cannot be parsed was offered as a Warden to play")
	_erase_files_for(3)


## **A pointer it cannot read means slot 0.** Missing, empty, not an object,
## out of range, nonsense in the field - every one of those is what a player
## who has never seen this feature has, and they must land on the historic save
## and notice nothing at all.
func _test_a_malformed_pointer_reads_as_slot_zero() -> void:
	var pointer: String = MetaState.slot_pointer_path()
	_erase_file(pointer)
	_check(MetaState.read_slot_pointer() == 0,
		"no pointer at all did not read as the first Warden")
	for rubbish: String in ["", "   ", "not json at all", "[]", "3",
			"{\"slot\":", "{\"slot\": \"banana\"}", "{\"slot\": -4}",
			"{\"slot\": 999}", "{\"other\": 1}"]:
		_write_text(pointer, rubbish)
		var read: int = MetaState.read_slot_pointer()
		_check(read == 0,
			"a pointer reading %s opened slot %d instead of the historic save"
				% [JSON.stringify(rubbish), read])
	# A pointer it *can* read is obeyed, or the paragraph above is describing a
	# function that always returns zero.
	_write_text(pointer, JSON.stringify({"slot": 1}))
	_check(MetaState.read_slot_pointer() == 1,
		"a valid pointer was ignored, so every launch would open slot 0")
	_erase_file(pointer)

	# And the pointer is written when the Warden changes, or the choice is lost
	# on the next launch.
	RunState.set_phase(RunState.Phase.ENDED)
	_be_slot(0)
	MetaState.use_slot(1)
	_check(MetaState.read_slot_pointer() == 1,
		"switching Warden did not record which one, so the next launch forgets")
	_be_slot(0)
	_check(MetaState.read_slot_pointer() == 0, "switching back did not record it")


## Erasing one Warden takes that Warden and nothing else - including the
## temporary sibling, which `read_committed_text` would otherwise adopt on the
## next read and raise the slot from the dead.
func _test_erasing_one_leaves_the_others() -> void:
	RunState.set_phase(RunState.Phase.ENDED)
	_be_slot(0)
	_write_a_warden("Ardwin", 11, 111)
	MetaState.use_slot(1)
	_write_a_warden("Belisent", 42, 4242)
	MetaState.use_slot(2)
	_write_a_warden("Coelric", 7, 77)
	_be_slot(0)

	_write_text(MetaState.slot_path(1) + MetaState.SAVE_TEMP_SUFFIX, "{\"version\": 7}")
	_check(MetaState.erase_slot(1), "a slot that exists refused to be erased")
	_check(not FileAccess.file_exists(MetaState.slot_path(1)),
		"erasing a slot left its file")
	_check(not FileAccess.file_exists(MetaState.slot_path(1) + MetaState.SAVE_TEMP_SUFFIX),
		("erasing a slot left its temporary sibling, which the next read adopts "
			+ "- the Warden comes back from the dead"))
	_check(not bool(MetaState.slot_summary(1).get("exists", false)),
		"an erased slot still reads as played")

	var kept: Dictionary = MetaState.slot_summary(2)
	_check(String(kept.get("name", "")) == "Coelric" and int(kept.get("level", 0)) == 7,
		"erasing one Warden changed another")
	_check(MetaState.player_name == "Ardwin" and MetaState.slot() == 0,
		"erasing a slot disturbed the account being played")
	_check(FileAccess.file_exists(MetaState.slot_path(0)),
		"erasing a slot took the historic save with it")
	_erase_files_for(2)


## The version-backup rule, **per slot**: one copy per version, never
## overwritten, and two Wardens who hit the same mismatch are two files worth
## keeping. One naming scheme for all of them would have the second overwrite
## nothing and the support copy describe the wrong account.
##
## Driven at `_back_up_save` and `back_up_unreadable` with no path passed -
## the shipping default, which is the derivation under test - rather than
## through `load_save`. `load_save` warns when it discards a save, correctly,
## and a warning fails this project's bar; what it adds over these two is only
## that it calls them, which the source walk below holds instead.
func _test_the_backup_rule_holds_per_slot() -> void:
	RunState.set_phase(RunState.Phase.ENDED)
	_be_slot(0)
	var future: int = MetaState.SAVE_VERSION + 99

	# No two slots back up to one file, for either kind of copy.
	var names: Dictionary = {}
	for index: int in Balance.SAVE_SLOTS:
		for path: String in [MetaState.slot_backup_path(index, future),
				MetaState.slot_unreadable_path(index, 1)]:
			_check(not names.has(path), "slots %s and %d back up to the same file"
				% [str(names.get(path, -1)), index])
			names[path] = index
			_erase_file(path)

	# Slot 1's own copy, kept byte for byte under slot 1's own name.
	_be_slot(1)
	var original: String = JSON.stringify({"version": future, "board": {"name": "Ghost"}}, "	")
	var backup: String = MetaState.slot_backup_path(1, future)
	_check(MetaState.call("_back_up_save", original, future),
		"a save of an unknown version could not be kept")
	_check(FileAccess.file_exists(backup),
		"the copy of slot 1's unreadable save is not under slot 1's name")
	_check(FileAccess.get_file_as_string(backup) == original,
		"the copy kept of an unreadable slot is not byte-identical")

	# Never overwritten. The first copy is the valuable one, and a player
	# bouncing between two builds would otherwise lose it on the third launch.
	MetaState.call("_back_up_save", JSON.stringify({"version": future, "n": 2}), future)
	_check(FileAccess.get_file_as_string(backup) == original,
		("the second mismatch overwrote the first copy; the first is the "
			+ "valuable one, and bouncing between builds would erase it"))

	# And none of it reached another slot.
	for index: int in Balance.SAVE_SLOTS:
		if index == 1:
			continue
		_check(not FileAccess.file_exists(MetaState.slot_backup_path(index, future)),
			"slot 1's version mismatch wrote a backup for slot %d" % index)

	# The unparseable copy, the same two properties, under slot 1's name.
	var broken: String = "{\"version\": 7, \"board\": {\"na"
	var before: PackedStringArray = _fixture_files()
	var kept: String = MetaState.back_up_unreadable(broken)
	_check(not kept.is_empty(), "a save that could not be parsed was not kept")
	_check(kept.get_file().begins_with(
			MetaState.slot_path(1).get_file().get_basename()),
		"the copy of an unparseable slot is filed under another slot's name: %s" % kept)
	_check(FileAccess.get_file_as_string(kept) == broken,
		"the copy of an unparseable slot is not byte-identical")
	var after: PackedStringArray = _fixture_files()
	_check(after.size() == before.size() + 1,
		"keeping one unreadable copy wrote %d files" % (after.size() - before.size()))
	MetaState.back_up_unreadable("something else entirely", kept)
	_check(FileAccess.get_file_as_string(kept) == broken,
		"a second corrupt copy overwrote the first")

	_be_slot(0)
	_check(not FileAccess.file_exists(MetaState.slot_backup_path(0, future)),
		"slot 1's mismatch left a backup named for the historic save")
	_erase_files_for(1)


## **Nothing in `MetaState` may name a save path outside the derivation.**
##
## The failure this catches is an omission, which is the one shape a driven
## test cannot see: a call site left on - or put back on - a fixed path writes
## one Warden over another's file, and every check above stays green because
## every check above asks the derivation. So the file is read and the paths in
## it are counted.
##
## `SAVE_PATH` is allowed exactly twice - its own declaration, and `slot_root`
## starting there - and the two suffixes exactly once each, in the derivations.
func _test_no_shipping_path_skips_the_derivation() -> void:
	var body: String = FileAccess.get_file_as_string("res://autoload/MetaState.gd")
	if not _check(not body.is_empty(), "could not read MetaState.gd to walk it"):
		return
	var code: PackedStringArray = PackedStringArray()
	for line: String in body.split("
"):
		var trimmed: String = line.strip_edges()
		# Comments talk about these names on purpose; only code may not.
		if trimmed.begins_with("#"):
			continue
		code.append(line)
	var text: String = "
".join(code)
	_check(text.count("SAVE_PATH") == 2,
		("SAVE_PATH is named %d times in MetaState's code; it may appear only "
			+ "in its own declaration and as `slot_root`'s starting value - "
			+ "every other path comes from `slot_path`") % text.count("SAVE_PATH"))
	_check(text.count("SAVE_BACKUP_SUFFIX") == 2,
		"SAVE_BACKUP_SUFFIX is used outside `slot_backup_path`")
	_check(text.count("SAVE_UNREADABLE_SUFFIX") == 2,
		"SAVE_UNREADABLE_SUFFIX is used outside `slot_unreadable_path`")
	# The literal, in case somebody writes the path out rather than the name.
	_check(not text.contains("\"user://beast_road_save.v")
			and not text.contains("\"user://beast_road_save.unreadable"),
		"a save path is written out as a literal rather than derived per slot")
	_check(text.count("slot_path(_slot)") >= 2,
		("the save is no longer written and read through `slot_path(_slot)`, "
			+ "which is the one thing that keeps two Wardens apart"))


# --- Harness -----------------------------------------------------------------

## Moves the whole naming scheme - saves, backups and the pointer - into a
## directory under the repository. `res://` keeps a headless gate inside the
## sandbox and can never alias a real `user://` slot.
func _open_the_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	MetaState.slot_root = FIXTURE_BASE
	_wipe_the_fixture()
	# Not a slot of its own: the fixture's own account starts from nothing so
	# that whatever the developer's live save happened to hold cannot be read
	# by a check as if a slot had written it.
	MetaState.call("_adopt_new_account")


func _close_the_fixture() -> void:
	_wipe_the_fixture()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	MetaState.slot_root = _saved_root
	RunState.set_phase(_saved_phase as RunState.Phase)
	# `_slot` is private and there is no door back to it with saves held, which
	# is correct - a gate must not be able to move the player's Warden. Put back
	# by hand so nothing later in this process writes under the wrong number.
	MetaState.set("_slot", _saved_slot)


func _wipe_the_fixture() -> void:
	var dir: DirAccess = DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return
	for name: String in dir.get_files():
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(FIXTURE_DIR.path_join(name)))


func _fixture_files() -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(FIXTURE_DIR)
	return dir.get_files() if dir != null else PackedStringArray()


## Enter a slot, failing loudly rather than measuring the wrong account if it
## refuses - every check after a silent refusal would be reading somebody else.
func _be_slot(index: int) -> void:
	if MetaState.slot() == index:
		return
	_check(MetaState.use_slot(index), "the harness could not reach slot %d" % index)


## Three fields that are three different blocks of the save - the board, the
## hero and the stash - so a switch that carried one across and cleared the
## others is named rather than missed.
func _write_a_warden(named: String, level: int, coin: int) -> void:
	MetaState.player_name = named
	MetaState.hero_level = level
	MetaState.marks = coin
	MetaState.save_game()


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "the harness could not write %s" % path)
		return
	file.store_string(text)
	file.close()


func _erase_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _erase_files_for(index: int) -> void:
	_erase_file(MetaState.slot_path(index))
	_erase_file(MetaState.slot_path(index) + MetaState.SAVE_TEMP_SUFFIX)


func _check(condition: bool, why: String) -> bool:
	_checked += 1
	if condition:
		return true
	_failures += 1
	push_error("[save-slots] %s" % why)
	return false
