extends Node

## Three things a player meets between the systems, added 2026-09-21 off the
## roadmap's "not yet considered" list (§7.2):
##
##   godot --headless --path game res://tools/qol_check.tscn
##
## - **Leaving is said before it is done.** The pause menu's leave button used
##   to abandon the road on the first press with nothing on screen saying what
##   the road was worth. `PauseMenu.leaving_costs` is the sentence; the first
##   press shows it and the second leaves. What this holds is that the sentence
##   is right for every state a run can be in - nothing banked, banked on this
##   road, banked and no waves since, a guest, the Walk, an ended run - and that
##   the first press does not leave.
## - **A preset chosen for the machine.** `Graphics.preset_for_machine` is pure
##   over the adapter name, so this asks it about machines nobody is sitting at:
##   a discrete card stays High, an integrated chip is Medium, a software
##   renderer is Low, the web is Medium whatever the card, and a phone is Low.
##   And a saved choice is never second-guessed.
## - **The interface size.** A slider that writes a number and changes nothing
##   is the failure the graphics settings once shipped with, so this sets the
##   value through the real door and reads the window's scale factor back.
##
## **The ways this goes wrong:** a warning that names the wrong wave, a first
## press that leaves, a guest told they are losing a road that was never theirs,
## a card the table mistakes for a chip, and a slider that only takes effect on
## the next launch.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_leaving_is_said()
	_test_the_first_press_does_not_leave()
	_test_a_preset_for_the_machine()
	_test_the_interface_size()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[qol] PASS - %d checks: a quit says what it costs, the first press "
			+ "explains and the second leaves, a preset fits the machine, and the "
			+ "interface size takes effect now") % _checks)
	else:
		push_error("[qol] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


# --- The quit warning --------------------------------------------------------


## A banked front as `Expedition.compose` would write it, without a field.
func _bank(act: int, wave: int, seed_value: int) -> Dictionary:
	return {"version": Expedition.VERSION, "progress": "", "seed": seed_value,
		"act": act, "wave": wave, "distance": 0.0, "towers": [], "purse": {},
		"wall": 1.0}


func _test_leaving_is_said() -> void:
	RunState.reset()
	GameDirector.run_active = true
	RunState.phase = RunState.Phase.ROAD_BATTLE
	RunState.act = 2
	RunState.wave_number = 40
	RunState.walking = false

	# Nothing banked: the whole road is at stake, and the line says how to
	# bank one.
	MetaState.expedition = {}
	var said: String = PauseMenu.leaving_costs()
	_check(said.contains("Nothing of this road is banked"),
		"with nothing banked the warning must say so, said '%s'" % said)
	_check(said.contains("Act 2, wave 40"),
		"and name where the player is standing, said '%s'" % said)
	_check(said.contains("Turn for home"),
		"and say how a road is banked, said '%s'" % said)

	# Banked on this road, twelve waves ago: the cost is those twelve waves.
	MetaState.expedition = _bank(2, 28, RunState.run_seed)
	said = PauseMenu.leaving_costs()
	_check(said.contains("12 waves"),
		"banked twelve waves ago, the warning must count them, said '%s'" % said)
	_check(said.contains("Act 2, wave 28"),
		"and name the bank, said '%s'" % said)

	# One wave, singular - a warning that says "1 waves" reads as a template.
	MetaState.expedition = _bank(2, 39, RunState.run_seed)
	said = PauseMenu.leaving_costs()
	_check(said.contains("1 wave of road"),
		"one wave since the bank must read as one wave, said '%s'" % said)

	# Banked at this very wave: nothing counted, and no negative number.
	MetaState.expedition = _bank(2, 40, RunState.run_seed)
	said = PauseMenu.leaving_costs()
	_check(said.contains("banked at Act 2, wave 40") and not said.contains("-"),
		"banked at the current wave the warning must not count, said '%s'" % said)

	# A bank from another road: named, never subtracted from.
	MetaState.expedition = _bank(1, 70, RunState.run_seed + 1)
	said = PauseMenu.leaving_costs()
	_check(said.contains("banked at Act 1, wave 70") and not said.contains("waves of road"),
		"a bank from another road is named and never counted, said '%s'" % said)

	# The Walk costs nothing, and an ended run costs nothing.
	MetaState.expedition = {}
	RunState.walking = true
	_check(PauseMenu.leaving_costs().is_empty(),
		"leaving the Walk costs nothing and must say nothing")
	RunState.walking = false
	RunState.phase = RunState.Phase.ENDED
	_check(PauseMenu.leaving_costs().is_empty(),
		"leaving an ended run costs nothing and must say nothing")
	RunState.phase = RunState.Phase.ROAD_BATTLE
	GameDirector.run_active = false
	_check(PauseMenu.leaving_costs().is_empty(),
		"with no run active there is nothing to warn about")
	GameDirector.run_active = true


func _test_the_first_press_does_not_leave() -> void:
	RunState.reset()
	GameDirector.run_active = true
	RunState.phase = RunState.Phase.PREPARATION
	RunState.act = 3
	RunState.wave_number = 12
	MetaState.expedition = {}
	var menu: PauseMenu = load("res://scenes/ui/pause_menu.tscn").instantiate() as PauseMenu
	add_child(menu)
	menu.set_showing(true)
	var before: String = menu.menu_button.text
	var warning: Label = menu.panel.find_child("LeaveWarning", true, false) as Label
	_check(warning != null and not warning.visible,
		"the warning must exist and stay hidden until a press asks for it")
	menu.menu_button.pressed.emit()
	_check(GameDirector.run_active,
		"the first press must not leave the run - it explains")
	_check(warning != null and warning.visible and warning.text.contains("Nothing of this road"),
		"the first press must show what leaving costs, showing '%s'"
			% (warning.text if warning != null else "<no label>"))
	_check(menu.menu_button.text != before,
		"the leave button must read as a confirmation after the first press")
	# Closing and reopening the menu forgets the confirmation, so a stale
	# "leave anyway" never waits for a later press.
	menu.set_showing(false)
	menu.set_showing(true)
	_check(warning != null and not warning.visible and menu.menu_button.text == before,
		"reopening the pause menu must reset the confirmation")
	menu.queue_free()


# --- The machine's preset ----------------------------------------------------


func _test_a_preset_for_the_machine() -> void:
	var cases: Array = [
		["NVIDIA GeForce RTX 3070 Ti", false, false, Graphics.PRESET_HIGH],
		["AMD Radeon RX 6800 XT", false, false, Graphics.PRESET_HIGH],
		["Intel(R) UHD Graphics 620", false, false, Graphics.PRESET_MEDIUM],
		["Intel(R) Iris(R) Xe Graphics", false, false, Graphics.PRESET_MEDIUM],
		["AMD Radeon(TM) Graphics", false, false, Graphics.PRESET_MEDIUM],
		["AMD Radeon Vega 8 Graphics", false, false, Graphics.PRESET_MEDIUM],
		["llvmpipe (LLVM 15.0.7, 256 bits)", false, false, Graphics.PRESET_LOW],
		["Microsoft Basic Render Driver", false, false, Graphics.PRESET_LOW],
		["", false, false, Graphics.DEFAULT_PRESET],
		["NVIDIA GeForce RTX 3070 Ti", true, false, Graphics.DEFAULT_PRESET_WEB],
		["Adreno (TM) 650", false, true, Graphics.PRESET_LOW],
	]
	for row: Array in cases:
		var got: String = Graphics.preset_for_machine(String(row[0]), bool(row[1]), bool(row[2]))
		_check(got == String(row[3]),
			"'%s' (web=%s mobile=%s) should start on %s, got %s"
				% [row[0], str(row[1]), str(row[2]), row[3], got])
	# A saved choice is never second-guessed by the machine.
	var kept: Dictionary = Graphics.to_dictionary()
	Graphics.from_dictionary({Graphics.KEY_PRESET: Graphics.PRESET_LOW})
	_check(Graphics.preset() == Graphics.PRESET_LOW,
		"a preset the player chose must win over the machine's, got %s" % Graphics.preset())
	Graphics.from_dictionary(kept)
	# And the default is one of the presets, whatever machine this gate runs on.
	_check(Graphics.PRESETS.has(Graphics.default_preset()),
		"the default preset must be a real preset, got %s" % Graphics.default_preset())


# --- The interface size ------------------------------------------------------


func _test_the_interface_size() -> void:
	var window: Window = get_window()
	if window == null:
		_check(false, "no window to fit")
		return
	var was: Variant = MetaState.settings.get(UserSettings.UI_SCALE_KEY, null)
	UserSettings.set_value(UserSettings.UI_SCALE_KEY, 1.0)
	var base: float = window.content_scale_factor
	UserSettings.set_value(UserSettings.UI_SCALE_KEY, 1.3)
	_check(is_equal_approx(window.content_scale_factor, base * 1.3),
		"the interface size must change the window's scale now, %.2f -> %.2f"
			% [base, window.content_scale_factor])
	# Out of range is clamped rather than obeyed: a save may hold anything.
	UserSettings.set_value(UserSettings.UI_SCALE_KEY, 9.0)
	_check(is_equal_approx(window.content_scale_factor, base * UserSettings.UI_SCALE_MAX),
		"a size past the ceiling must be held to it, got %.2f" % window.content_scale_factor)
	UserSettings.set_value(UserSettings.UI_SCALE_KEY, 1.0)
	_check(is_equal_approx(window.content_scale_factor, base),
		"back at one the window must fit as it did, %.2f vs %.2f"
			% [window.content_scale_factor, base])
	if was == null:
		MetaState.settings.erase(UserSettings.UI_SCALE_KEY)
	else:
		UserSettings.set_value(UserSettings.UI_SCALE_KEY, was)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[qol] %s" % why)
