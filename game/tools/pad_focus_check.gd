extends Node

## Every screen can be walked with a pad.
##
##   godot --headless --path game res://tools/pad_focus_check.tscn
##
## The roadmap's "controller completeness" (§7.2, 2026-09-21): the pad is
## full, every rebindable action has a button, and whether every *screen* -
## the stash, the forge, the stable, the Ledger, the pen, the Guide, the
## Chronicle, the codex, the boards, the act start, the pause menu and the
## settings - can actually be navigated by focus alone had never been asked.
## A screen with one button the D-pad cannot reach is a screen a pad player
## cannot leave.
##
## **Walked, not counted.** Each screen is stood up through its real `open()`,
## and the gate starts at the first thing that can take focus and follows
## `find_next_valid_focus` until it comes back round, which is exactly what a
## D-pad press does. Every visible, enabled, focusable control has to be on
## that ring. A control that is focusable and never reached is the fault this
## exists to name: a button drawn where a pad cannot go.
##
## **The ways this goes wrong:** a screen with nothing focusable at all (a
## pad player cannot even close it), a focus ring that skips a control, and a
## `focus_mode` set to none on the one button that matters.

## Screens with a no-argument `open()`. The crossroad wants a segment and the
## hub wants the menu's buttons to adopt, so those two are covered by the menu
## gate and the co-op harness rather than stood up bare here.
## A `var` rather than a `const`: a class reference is not a constant
## expression to GDScript, and `PackedStringArray([...])` was refused for the
## same reason once.
var _screens: Array = [
	["ActStartScreen", ActStartScreen],
	["ChronicleScreen", ChronicleScreen],
	["CodexScreen", CodexScreen],
	["ExchangeScreen", ExchangeScreen],
	["GuideScreen", GuideScreen],
	["LeaderboardScreen", LeaderboardScreen],
	["PenScreen", PenScreen],
	["SmithyScreen", SmithyScreen],
	["StableScreen", StableScreen],
	["StashScreen", StashScreen],
	["VendorScreen", VendorScreen],
]

## More steps than any screen has controls; the walk stops when the ring
## closes, so the budget only ever bounds a ring that never does.
const RING_BUDGET: int = 512

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	# A screen full of empty lists has nothing to walk; give the account
	# something to show so the rows that carry the buttons exist.
	RunState.reset()
	RunState.gain_every_currency(500)
	for entry: Array in _screens:
		await _walk_screen(String(entry[0]), entry[1] as GDScript)
	await _walk_main_menu()
	await _walk_pause_menu()
	await _walk_settings()
	MetaState.resume_saves()
	if _failures == 0:
		print("[pad-focus] PASS - %d checks: every screen has a focus ring and every control is on it"
			% _checks)
	else:
		push_error("[pad-focus] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _walk_screen(label: String, script: GDScript) -> void:
	var screen: Node = script.new()
	add_child(screen)
	await get_tree().process_frame
	if screen.has_method("open"):
		screen.call("open")
	await get_tree().process_frame
	await get_tree().process_frame
	_walk(label, screen)
	screen.queue_free()
	await get_tree().process_frame


func _walk_main_menu() -> void:
	var menu: Control = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as Control
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	_walk("MainMenu", menu)
	menu.queue_free()
	await get_tree().process_frame


func _walk_pause_menu() -> void:
	var menu: PauseMenu = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child(menu)
	await get_tree().process_frame
	menu.set_showing(true)
	await get_tree().process_frame
	_walk("PauseMenu", menu)
	menu.queue_free()
	await get_tree().process_frame


func _walk_settings() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var panel := SettingsPanel.new()
	host.add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	_walk("SettingsPanel", host)
	host.queue_free()
	await get_tree().process_frame


## The ring, from the first focusable control, until it comes back round or
## runs out. Every focusable control the screen shows has to be on it.
func _walk(label: String, root: Node) -> void:
	var focusable: Array[Control] = []
	_collect(root, focusable)
	_check(not focusable.is_empty(),
		"%s shows nothing a pad can focus, so a pad player cannot even close it" % label)
	if focusable.is_empty():
		return
	var start: Control = focusable[0]
	start.grab_focus()
	var seen: Dictionary = {}
	var at: Control = start
	# **A generous budget, not the count.** The engine's ring also walks
	# click-focus controls this gate does not count, so a budget of twice the
	# count stopped short of the far end of the vendor's ring and reported two
	# reachable buttons as unreachable. The ring ends when it comes back round.
	for _step: int in RING_BUDGET:
		if at == null:
			break
		seen[at.get_instance_id()] = true
		at = at.find_next_valid_focus()
		if at == start:
			break
	var missed: PackedStringArray = []
	for control: Control in focusable:
		if not seen.has(control.get_instance_id()):
			missed.append("%s (%s)" % [control.name, control.get_class()])
	_check(missed.is_empty(),
		"%s: %d of %d focusable controls are not on the focus ring: %s"
			% [label, missed.size(), focusable.size(), ", ".join(missed)])
	# The other way round too, because a pad goes both ways and a chain of
	# `focus_previous` overrides can break in one direction only.
	at = start
	var seen_back: Dictionary = {}
	for _step: int in RING_BUDGET:
		if at == null:
			break
		seen_back[at.get_instance_id()] = true
		at = at.find_prev_valid_focus()
		if at == start:
			break
	_check(seen_back.size() == seen.size(),
		"%s: walking backwards reaches %d controls and forwards %d" % [label, seen_back.size(), seen.size()])
	print("[pad-focus] %s: %d focusable, ring of %d" % [label, focusable.size(), seen.size()])


## Visible, enabled, and asking for focus. A disabled button is skipped by the
## engine's own walk and is not a pad player's problem; a hidden one is not on
## screen to reach.
func _collect(node: Node, out: Array[Control]) -> void:
	var control := node as Control
	if control != null and control.is_visible_in_tree() \
			and control.focus_mode == Control.FOCUS_ALL:
		var button := control as BaseButton
		var slider := control as Range
		if (button == null or not button.disabled) and (slider == null or slider.editable):
			out.append(control)
	for child: Node in node.get_children():
		_collect(child, out)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[pad-focus] %s" % why)
