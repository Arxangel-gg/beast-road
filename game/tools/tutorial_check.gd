extends Node

## The coach's nineteen steps, and whether each one fires on the thing it is
## about.
##
##   godot --headless --path game res://tools/tutorial_check.tscn
##
## **This gate exists because twelve of them were one place out.** A step names
## its trigger by index, `TutorialStepData.Trigger` gained `RAID_AVAILABLE` at
## position seven after the data was written, and every step from there on
## shifted: a new player was told about raids when they found gear, about gear
## when they levelled, about levelling when they cast, and never about rift
## gates at all - the last step named index 19 in an enum of nineteen, which is
## out of range and fires on nothing.
##
## Nothing failed. Godot does not clamp an out-of-range enum on a resource, the
## coach simply never matched it, and the tutorial is the one system whose
## audience has no idea what it was supposed to say. It was found by walking
## every `.tres` in the project against its own script's enums, not by playing.
##
## Four ways this can be a lie:
##
## 1. **A step on a trigger that does not exist.** The fault above.
## 2. **A trigger with no step.** The other half of the same fault: a gap in the
##    sequence is what the shift left behind, and a gap says nothing out loud.
## 3. **A step on a trigger nothing fires.** A trigger declared and never
##    emitted is a step that waits forever - the same failure a discipline
##    effect nothing reads has, in a system a beginner is relying on.
## 4. **A step that says nothing, or says it for no time.**

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_every_step_names_a_real_trigger()
	_test_every_trigger_has_a_step()
	_test_every_trigger_is_fired()
	_test_every_step_says_something()
	MetaState.resume_saves()
	if _failures == 0:
		print("[tutorial] PASS - %d checks: %d steps over %d triggers, each fired and each read"
			% [_checks, ContentDB.tutorial_steps.size(), TutorialStepData.Trigger.size()])
	else:
		push_error("[tutorial] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


func _steps() -> Array[TutorialStepData]:
	var out: Array[TutorialStepData] = []
	for value: Variant in ContentDB.tutorial_steps.values():
		var step := value as TutorialStepData
		if step != null:
			out.append(step)
	out.sort_custom(func(a: TutorialStepData, b: TutorialStepData) -> bool:
		return a.id < b.id)
	return out


## In range, which is the half that was out.
func _test_every_step_names_a_real_trigger() -> void:
	var count: int = TutorialStepData.Trigger.size()
	_check(count > 0, "the coach needs triggers")
	for step: TutorialStepData in _steps():
		_check(int(step.trigger) >= 0 and int(step.trigger) < count,
			("%s waits on trigger %d and there are %d - Godot does not clamp this, "
				+ "so the step simply never shows") % [step.id, int(step.trigger), count])


## And no gaps, which is the half that says nothing out loud.
func _test_every_trigger_has_a_step() -> void:
	var seen: Dictionary = {}
	for step: TutorialStepData in _steps():
		seen[int(step.trigger)] = true
	# More than one step may share a trigger - `order` exists for exactly that -
	# so this asks for at least one rather than for exactly one.
	for trigger: int in TutorialStepData.Trigger.size():
		_check(seen.has(trigger),
			"trigger %d has no step, which is what a shifted sequence leaves behind"
				% trigger)


## A step waiting on something nothing announces waits forever.
##
## A grep, like the one `discipline_check` uses on effect keys: weak proof of
## behaviour, strong proof of wiring, and wiring is the half that breaks.
func _test_every_trigger_is_fired() -> void:
	var names: PackedStringArray = TutorialStepData.Trigger.keys()
	for trigger: int in names.size():
		var key: String = "Trigger.%s" % names[trigger]
		_check(_named_in_code(key),
			"%s is declared and fired by nothing, so its step would wait forever" % key)


func _named_in_code(key: String) -> bool:
	for root: String in ["res://scripts", "res://scenes", "res://autoload"]:
		if _mentions(root, key):
			return true
	return false


func _mentions(path: String, wanted: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var full: String = path.path_join(name)
		if directory.current_is_dir():
			if _mentions(full, wanted):
				directory.list_dir_end()
				return true
		elif name.ends_with(".gd"):
			var file := FileAccess.open(full, FileAccess.READ)
			if file != null and file.get_as_text().contains(wanted):
				directory.list_dir_end()
				return true
		name = directory.get_next()
	directory.list_dir_end()
	return false


## And it has to say something, for long enough to read.
func _test_every_step_says_something() -> void:
	for step: TutorialStepData in _steps():
		_check(not step.body.strip_edges().is_empty(), "%s says nothing" % step.id)
		_check(not step.display_name.strip_edges().is_empty(), "%s has no name" % step.id)
		# Read mid-run, over a battlefield, by somebody who has never seen the
		# game. Under four seconds is a prompt nobody finishes.
		_check(step.seconds >= 4.0,
			"%s is on screen for %.1fs, which is not long enough to read"
				% [step.id, step.seconds])
