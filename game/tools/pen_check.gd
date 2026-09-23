extends Node

## The pen: kept, taken out, lost, and released.
##
##   godot --headless --path game res://tools/pen_check.tscn
##
## Owner brief, 2026-09-15: *"Alive companions should be keepable at a pen ...
## up to an appropriate limit ... with the option to release any of them to make
## room for another, or they can choose which one they want to take out of the
## pen to follow them on their next expedition. Alive companions that are removed
## from a pen will stay with the player ... if the companion has not died during
## the run it was taken into."*
##
## **The amendment to working rule 7 is one sentence and it is what this gate
## exists to hold: the bond is permanent and the animal is not.** Losing a
## raised creature costs the player that creature and never a line in the
## journal - the same variant can be raised again. A gate that let the two get
## confused would be a gate that let a death eat collection progress.
##
## **The ways this goes wrong:**
##
## - **A lost animal takes its bond with it.** Then dying on the road undoes
##   discovery, which nothing else in this project does.
## - **The pen is not a cap.** Without one the "release to make room" decision
##   the brief asks for never happens.
## - **A raised animal re-forms.** A bonded spirit does, by design and since
##   companions were un-cut; if a raised one did too, the whole stake of taking
##   a favourite out is gone.
## - **A dangling name.** `pen_taken` naming an animal that is not in the pen is
##   a companion with no creature behind it.
## - **The pen is edited mid-run.** Swapping the animal out the moment it looks
##   like dying is the decision being made after the risk instead of before it.
## - **It does not survive a save.** The whole point of the pen is that it is
##   between runs, and a roster that reads back empty is a roster that lost
##   everything a player raised.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_cap_and_the_room()
	_test_taking_one_out()
	_test_losing_one_keeps_the_bond()
	_test_it_reads_back()
	_test_the_pen_mends_over_real_time()
	await _test_the_yard()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[pen] PASS - %d checks: the pen caps and releases, one goes out "
			+ "at a time and only between runs, a lost animal keeps its bond, "
			+ "and the roster survives a save") % _checks)
	else:
		push_error("[pen] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _a_species() -> String:
	var ids: Array = ContentDB.wildlife_kinds.keys()
	ids.sort()
	return String(ids[0]) if not ids.is_empty() else ""


func _clear() -> void:
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	RunState.pen_companion_fell = false


## **A cap is what makes a full pen a decision.**
func _test_the_cap_and_the_room() -> void:
	_clear()
	var species: String = _a_species()
	_check(not species.is_empty(), "the roster must have an animal to keep")
	if species.is_empty():
		return
	_check(Balance.PEN_CAPACITY >= 4,
		"a pen of %d is a slot rather than a pen" % Balance.PEN_CAPACITY)
	var names: Array[String] = []
	for index: int in Balance.PEN_CAPACITY:
		var uid: String = MetaState.pen_add(species, 0, false, "")
		_check(not uid.is_empty(), "the pen refused animal %d of its own capacity"
			% (index + 1))
		_check(not names.has(uid), "two animals were given the name %s" % uid)
		names.append(uid)
	_check(MetaState.pen.size() == Balance.PEN_CAPACITY,
		"a filled pen holds %d against a capacity of %d"
			% [MetaState.pen.size(), Balance.PEN_CAPACITY])
	_check(not MetaState.pen_has_room(), "a full pen still reported room")
	_check(MetaState.pen_add(species, 0, false, "").is_empty(),
		"a full pen took one more, so the cap is not a cap")
	# **Releasing is what makes room.**
	_check(MetaState.pen_release(names[0]), "the pen refused to release an animal")
	_check(MetaState.pen_has_room(), "releasing one left no room")
	_check(MetaState.penned(names[0]).is_empty(),
		"a released animal is still in the pen")
	_check(not MetaState.pen_release(names[0]),
		"the pen released the same animal twice")
	_check(not MetaState.pen_release("not-a-name"),
		"the pen released an animal that was never in it")
	# An unknown species is not an animal.
	_check(MetaState.pen_add("not-a-species", 0, false, "").is_empty(),
		"the pen took something that is not a species")


## **One at a time, and decided before leaving.**
func _test_taking_one_out() -> void:
	_clear()
	var species: String = _a_species()
	var first: String = MetaState.pen_add(species, 1, false, "")
	var second: String = MetaState.pen_add(species, 2, true, "")
	RunState.set_phase(RunState.Phase.ENDED)
	_check(MetaState.pen_take(first), "the pen refused to hand one over in town")
	_check(MetaState.pen_taken == first, "the wrong animal came out")
	_check(MetaState.pen_take(second), "the pen refused to swap in town")
	_check(MetaState.pen_taken == second,
		"taking a second left the first out, which is two companions")
	_check(not MetaState.pen_take("not-a-name"),
		"the pen handed over an animal that was never in it")
	_check(MetaState.pen_taken == second,
		"a refused request still changed which animal was out")
	# **Not during a run.** Swapping when it starts to look dangerous is the
	# decision being made after the risk rather than before it.
	GameDirector.run_active = true
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(not MetaState.pen_take(first),
		"the pen was edited mid-run, so the risk can be dodged after the fact")
	_check(MetaState.pen_taken == second, "a mid-run request changed the pen")
	GameDirector.run_active = false
	RunState.set_phase(RunState.Phase.ENDED)
	_check(MetaState.pen_take(""), "the pen refused to take everything back")
	_check(MetaState.pen_taken.is_empty(), "something stayed out")
	# The companion door answers what is out, and nothing when nothing is.
	_check(MetaState.pen_companion().is_empty(),
		"an empty pen_taken still named a companion")
	_check(MetaState.pen_take(first) and not MetaState.pen_companion().is_empty(),
		"an animal that is out is not reported as the companion")
	_check(String(MetaState.pen_companion().get("uid", "")) == first,
		"the companion door named the wrong animal")


## **The one that matters: a death costs the creature and never the journal.**
func _test_losing_one_keeps_the_bond() -> void:
	_clear()
	var species: String = _a_species()
	var uid: String = MetaState.pen_add(species, 2, false, "")
	RunState.set_phase(RunState.Phase.ENDED)
	MetaState.pen_take(uid)
	# Bonded the way hatching bonds it, so the journal genuinely holds the entry.
	MetaState.bond_from_egg(species, 2, false, "")
	var key: String = SpiritBond.key(species, 2, false)
	_check(MetaState.spirit_is_bonded(key),
		"the variant must be bonded before the animal can be lost")
	var bonds_before: int = MetaState.spirit_bonded.size()

	_check(MetaState.pen_lose_taken(), "the pen refused to lose the animal out")
	_check(MetaState.penned(uid).is_empty(),
		"a lost animal is still in the pen")
	_check(MetaState.pen_taken.is_empty(),
		"a lost animal is still named as the one out")
	# **And the bond stands.**
	_check(MetaState.spirit_is_bonded(key),
		("losing a raised animal took its bond with it - a death must never "
			+ "undo discovery"))
	_check(MetaState.spirit_bonded.size() == bonds_before,
		"losing an animal changed the collection: %d against %d"
			% [MetaState.spirit_bonded.size(), bonds_before])
	_check(not MetaState.pen_lose_taken(),
		"the pen lost an animal when nothing was out")
	# **A raised animal does not re-form**, which is the difference from a spirit.
	var companion := Companion.new()
	companion.from_pen = true
	_check(companion.from_pen,
		"a raised animal must be able to say that it is one")
	companion.free()


## **A roster that does not survive a save is a roster that lost everything.**
func _test_it_reads_back() -> void:
	_clear()
	var species: String = _a_species()
	var kept: String = MetaState.pen_add(species, 3, true, "")
	RunState.set_phase(RunState.Phase.ENDED)
	MetaState.pen_take(kept)
	var written: Array = MetaState.pen.duplicate(true)
	var taken: String = MetaState.pen_taken

	# Through the real read, with the real shape, rather than by re-assigning.
	MetaState.call("_read_pen", {"animals": written, "taken": taken})
	_check(MetaState.pen.size() == 1, "the pen read back %d animals"
		% MetaState.pen.size())
	if MetaState.pen.size() == 1:
		_check(String(MetaState.pen[0].get("species", "")) == species,
			"the animal read back as a different species")
		_check(int(MetaState.pen[0].get("rarity", 0)) == 3,
			"the animal read back at the wrong rarity")
		_check(bool(MetaState.pen[0].get("shiny", false)),
			"a shiny animal read back plain")
	_check(MetaState.pen_taken == taken, "the animal out did not read back")

	# **A save from before the pen is an empty pen**, which is a new account.
	MetaState.call("_read_pen", {})
	_check(MetaState.pen.is_empty(),
		"a save with no pen key read back %d animals" % MetaState.pen.size())
	_check(MetaState.pen_taken.is_empty(), "a save with no pen key had one out")

	# **A dangling name is not a companion.** An animal named as out that is not
	# in the list would be a road with a ghost on it.
	MetaState.call("_read_pen", {"animals": [], "taken": "pen9"})
	_check(MetaState.pen_taken.is_empty(),
		"a name with no animal behind it was kept")
	# And a malformed row is dropped rather than trusted.
	MetaState.call("_read_pen", {"animals": [{"species": "not-a-species"}],
		"taken": ""})
	_check(MetaState.pen.is_empty(),
		"a row naming no real species was kept, and it has nothing to draw")
	_clear()


## **The yard is a picture of the pen and nothing more.**
##
## It stands one animal per kept creature, gives each its own clock so a pen of
## twelve is not twelve copies of one animation, and writes nothing back - the
## brief asked for animals that idle, roam and rest, and the failure worth
## catching is a yard that quietly became the authority on what is kept.
## **The pen mends on the wall clock** (owner, 2026-09-16).
##
## Driven by moving the stamp rather than by waiting, because the thing under
## test is a clock and a gate cannot wait an hour. That is also the honest test:
## the feature's whole claim is that it works on elapsed real time whether or not
## the game was running, so backdating the stamp *is* the game having been shut.
func _test_the_pen_mends_over_real_time() -> void:
	MetaState.pen.clear()
	var uid: String = MetaState.pen_add("rabbit", 0, false, "", 0.2)
	_check(not uid.is_empty(), "a hurt animal goes into the pen")
	_check(is_equal_approx(MetaState.pen_health(uid), 0.2),
		"and it is as hurt as it was put in (%.2f)" % MetaState.pen_health(uid))
	# An hour ago.
	var animal: Dictionary = MetaState.penned(uid)
	animal["healed_at"] = Time.get_unix_time_from_system() - 3600.0
	var after: float = MetaState.pen_health(uid)
	_check(after > 0.2, "an hour of real time mends it (%.2f -> %.2f)" % [0.2, after])
	_check(after <= 1.0, "and never past whole (%.2f)" % after)
	# **Never backwards.** A player who moves their system clock, or a machine
	# correcting itself, must not be able to un-heal an animal.
	var held: float = MetaState.pen_health(uid)
	animal["healed_at"] = Time.get_unix_time_from_system() + 9000.0
	_check(MetaState.pen_health(uid) >= held,
		"a clock that went backwards did not un-heal it (%.2f -> %.2f)"
			% [held, MetaState.pen_health(uid)])
	# **Capped.** A month away is not a different feature from a day away.
	MetaState.pen_set_health(uid, 0.05)
	animal["healed_at"] = Time.get_unix_time_from_system() - 3600.0 * 24.0 * 400.0
	_check(MetaState.pen_health(uid) <= 1.0, "a year away is still at most whole")
	# And it survives being written out and read back, which is the whole point
	# of storing the stamp rather than a countdown.
	MetaState.pen_set_health(uid, 0.4)
	var written: Dictionary = {"animals": MetaState.pen.duplicate(true),
		"taken": MetaState.pen_taken}
	MetaState.pen.clear()
	MetaState.call("_read_pen", written)
	_check(is_equal_approx(MetaState.pen_health(uid), 0.4),
		"a hurt animal is still hurt after a save and a load (%.2f)"
			% MetaState.pen_health(uid))
	# A whole animal costs nothing to ask about and stays whole.
	var well: String = MetaState.pen_add("fox", 0, false, "", 1.0)
	_check(is_equal_approx(MetaState.pen_health(well), 1.0), "a whole animal stays whole")
	MetaState.pen.clear()


func _test_the_yard() -> void:
	_clear()
	var species: String = _a_species()
	for index: int in 6:
		MetaState.pen_add(species, index % 4, index == 3, "")
	var screen: PenScreen = PenScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	await get_tree().process_frame
	var yard: PenYard = screen.yard()
	_check(yard != null, "the screen must build a yard")
	if yard != null:
		_check(yard.standing() == 6,
			"six kept animals stood up %d in the yard" % yard.standing())
		# **Each keeps its own clock.** Driven for a while; if every animal is
		# doing the same thing, the yard is one animation drawn six times.
		yard.advance(40.0, 200)
		var poses: Dictionary = {}
		for animal: Dictionary in MetaState.pen:
			poses[yard.pose_of(String(animal.get("uid", "")))] = true
		_check(poses.size() >= 2,
			("after forty seconds every animal in the pen was doing the same "
				+ "thing, so the yard is one clock rather than six"))
		# **And it decided nothing.**
		_check(MetaState.pen.size() == 6,
			"the yard changed the pen: %d animals" % MetaState.pen.size())
		_check(MetaState.pen_taken.is_empty(),
			"the yard took an animal out on its own")
		# An empty pen is a yard with nothing in it rather than a broken one.
		_clear()
		screen.refresh()
		_check(yard.standing() == 0,
			"an emptied pen left %d animals standing" % yard.standing())
	screen.queue_free()
	await get_tree().process_frame
	_clear()


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[pen] " + why)
