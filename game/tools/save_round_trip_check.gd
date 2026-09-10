extends Node

## What the game writes into a save must be what the game reads back out.
##
## **This exists because a played account was being handed a free sword on every
## launch.** `_seed_starting_gear` is guarded by a flag in `MetaState.settings`;
## `_read_settings` deliberately refuses keys the defaults dictionary does not
## declare, and that flag was never declared. So the grant set it, `save_game`
## wrote it, the next load dropped it, and the account got another Coalpaint
## Edge. Seven of them had accumulated in the owner's stash before anybody
## noticed, and nothing failed, printed, or warned at any point.
##
## The loader's strictness is right and is not what is being questioned here - a
## save is a file on a player's disk and reading unknown keys out of it is how a
## hand-edited save becomes a broken game. What is wrong is a *writer* that does
## not know about it. The same dictionary has caused this twice before, for the
## Video presets and for the colourblind modes, and both times the fix was one
## line and the diagnosis was hours.
##
## So the assertion is the general one: **every key the save carries must be a
## key the loader will accept**, whatever wrote it and whenever it was added.
##
## The second half is the symptom rather than the cause, kept because it is what
## a player would actually report: opening the game twice must not leave you with
## two starting weapons.
##
## Nothing here touches the player's file. The round trip is done in memory
## against `serialized_save`, and saves are held for the whole run.

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	# Held first, before anything is read, because everything below edits the
	# live autoload and the whole subject of this gate is a save being damaged.
	MetaState.hold_saves()

	_test_every_written_setting_can_be_read_back()
	_test_the_opening_weapon_is_granted_once()

	MetaState.resume_saves()
	if _failures == 0:
		print("[save-round-trip] PASS - %d checks; the save reads back what it writes"
			% _checked)
	else:
		push_error("[save-round-trip] FAIL - %d of %d" % [_failures, _checked])
	get_tree().quit(1 if _failures > 0 else 0)


## Every setting written is a setting the loader knows.
##
## `_read_settings` copies across only the keys the defaults dictionary already
## declares. A key written without being declared is therefore not "a setting
## that fails to save" - it saves perfectly, and is thrown away on the way back
## in, which is a much harder thing to notice.
##
## The defaults come from a fresh instance of the script rather than from the
## live autoload: the live one has already been loaded over, so asking it what
## its defaults were would be asking the wrong copy.
func _test_every_written_setting_can_be_read_back() -> void:
	var fresh: Node = ((load("res://autoload/MetaState.gd") as GDScript).new()) as Node
	var defaults: Dictionary = (fresh.get("settings") as Dictionary).duplicate(true)
	fresh.free()

	_checked += 1
	if not _check(not defaults.is_empty(), "could not read the declared settings defaults"):
		return

	var parsed: Variant = JSON.parse_string(MetaState.serialized_save())
	_checked += 1
	if not _check(parsed is Dictionary, "the save the game writes is not a JSON object"):
		return
	var written: Dictionary = (parsed as Dictionary).get("settings", {}) as Dictionary
	_checked += 1
	_check(not written.is_empty(), "the save carries no settings block at all")

	for key: Variant in written:
		_checked += 1
		_check(defaults.has(key),
			("`%s` is written into the save and thrown away on load: "
				+ "`MetaState.settings` does not declare it, and `_read_settings` "
				+ "keeps only declared keys") % [key])


## The opening weapon is a gift, not an allowance.
##
## Two directions, because only the pair says the flag is doing the work: an
## account that has not had it gets one, and an account that has had it does not
## get another. Asserting only the second would pass just as well if the grant
## had been deleted.
func _test_the_opening_weapon_is_granted_once() -> void:
	var stash_before: Array = MetaState.stash.duplicate(true)
	var equipped_before: Dictionary = MetaState.equipped.duplicate(true)
	var flag_before: Variant = MetaState.settings.get(MetaState.STARTING_GEAR_KEY, false)

	MetaState.stash = []
	MetaState.equipped = {}
	MetaState.settings[MetaState.STARTING_GEAR_KEY] = false
	MetaState.call("_seed_starting_gear")
	_checked += 1
	_check(MetaState.stash.size() == 1,
		"a fresh account was not given its opening weapon")

	# The launch after, with the flag as the save would have carried it.
	MetaState.call("_seed_starting_gear")
	_checked += 1
	_check(MetaState.stash.size() == 1,
		("the opening weapon was granted twice in one session; the flag that "
			+ "should stop it is not being read"))

	# And the launch after *that*, with the flag having gone through the save.
	var flag: Variant = MetaState.settings.get(MetaState.STARTING_GEAR_KEY, false)
	var parsed: Variant = JSON.parse_string(MetaState.serialized_save())
	var written: Dictionary = ((parsed as Dictionary).get("settings", {}) as Dictionary)
	_checked += 1
	_check(bool(written.get(MetaState.STARTING_GEAR_KEY, false)) == bool(flag),
		"the opening-weapon flag is not written into the save")

	MetaState.stash = stash_before
	MetaState.equipped = equipped_before
	MetaState.settings[MetaState.STARTING_GEAR_KEY] = flag_before


func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	push_error("[save-round-trip] %s" % why)
	return false
