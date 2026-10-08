extends Node

## **The chat answers Enter, alone and in company, and reads like League's**
## (owner, 2026-10-01: *"Need to be able to chat in game, was already
## implemented but there's no controls hotkey for it and need you to elevate and
## polish it further and make it more like league of legends"*):
##
##   godot --headless --path game res://tools/chat_check.tscn
##
## Every Enter, Escape and Up here is a real key pushed through the viewport, on
## a solo road - which is where the box never opened before, and so where it
## was reported as having no key.
##
## **The ways this goes wrong:** a box that opens only in a networked session; a
## Warden who walks and swings with the letters typed; an Escape that closes the
## box and pauses the game as well; a command sent to the party as words; a roll
## from the wire that claims more than its dice; a bracket in a message read as
## markup; a flood of lines; a muted partner heard; and a key the Controls page
## never names.

const SEED: int = 20261004

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run
var _hud: HUD
var _log: PartyLog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaState.hold_saves()
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	_run.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	_hud = _run.hud
	_run.battlefield.wave_director.stop()
	_log = _hud.get("_party_log") as PartyLog
	_check(_log != null, "the HUD has no party log")

	await _test_enter_opens_alone_and_the_hands_are_still()
	await _test_a_line_is_said_and_escape_closes_unsent()
	await _test_the_commands()
	await _test_the_wire()
	await _test_burst_mute_and_recall()
	_test_the_controls_page_names_it()
	await _test_a_thumb_has_a_say_square()

	var expected: int = 7
	_check(_finished == expected, "%d of %d tests reached their end" % [_finished, expected])
	if get_tree().paused:
		GameDirector.set_paused(false)
	_run.queue_free()
	for _f: int in 6:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures == 0:
		print(("[chat] PASS - %d checks: Enter opens the chat alone and in company, the "
			+ "Warden is still while a line is typed, Escape closes it unsent and pauses "
			+ "nothing, the commands answer, the wire claims nothing and escapes its "
			+ "markup, a burst is held, a muted seat is not heard, Up says a line again, "
			+ "and the Controls page names the key") % _checks)
	else:
		push_error("[chat] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


## **A phone has no Enter** (2026-10-01): in company a thumb's column carries
## a Say square that opens the box and, pressed again, sends what is in it;
## alone it is not there, where the speed square is.
func _test_a_thumb_has_a_say_square() -> void:
	var kept_touch: Variant = MetaState.settings.get(TouchInput.TOUCH_KEY, false)
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	TouchInput.refresh()
	await get_tree().process_frame
	var square := _hud.find_child("ChatSquare", true, false) as Button
	_check(square != null, "a thumb's column has no Say square")
	if square != null:
		_check(not square.visible, "the Say square shows on a solo road")
		Coop.set("_state", Coop.State.HOSTING)
		EventBus.coop_partner_joined.emit(2)
		await get_tree().process_frame
		_check(square.visible, "the Say square is hidden in company")
		square.pressed.emit()
		await get_tree().process_frame
		_check(_hud.is_chatting(), "the Say square did not open the chat")
		(_hud.get("_chat_box") as LineEdit).text = "on my way"
		square.pressed.emit()
		await get_tree().process_frame
		_check(not _hud.is_chatting(), "the Say square's second press did not send the line")
		Coop.set("_state", Coop.State.OFFLINE)
		EventBus.coop_partner_left.emit(2)
		await get_tree().process_frame
		_check(not square.visible, "the Say square stayed after company left")
	MetaState.settings[TouchInput.TOUCH_KEY] = kept_touch
	TouchInput.refresh()
	await get_tree().process_frame
	_finished += 1


# --- Helpers ----------------------------------------------------------------


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)
	for _f: int in 3:
		await get_tree().process_frame


## Opens the box with Enter, types `text` into it, and sends it with Enter.
func _say(text: String) -> void:
	if not _hud.is_chatting():
		await _key(KEY_ENTER)
	var box := _hud.get("_chat_box") as LineEdit
	box.text = text
	await _key(KEY_ENTER)


func _log_has(fragment: String) -> bool:
	for line: String in _log.plain_lines():
		if line.contains(fragment):
			return true
	return false


# --- Tests ------------------------------------------------------------------


func _test_enter_opens_alone_and_the_hands_are_still() -> void:
	_check(not Coop.is_networked(), "the harness should be alone")
	await _key(KEY_ENTER)
	var box := _hud.get("_chat_box") as LineEdit
	_check(_hud.is_chatting(), "Enter on a solo road did not open the chat - the report itself")
	_check(get_viewport().gui_get_focus_owner() == box, "the chat opened without taking the keys")
	_check(_log.is_open(), "the log did not open as the chat's history")
	var hero: Hero = _run.battlefield.hero
	var input := hero.get("input") as HeroInput
	Input.action_press(&"move_up")
	Input.action_press(&"attack")
	_check(input.move() == Vector2.ZERO, "a Warden walked while a line was typed")
	_check(not input.held(HeroInput.BUTTON_ATTACK), "a Warden swung while a line was typed")
	_check(TextFocus.typing(hero), "TextFocus does not see the chat box")
	await _key(KEY_ESCAPE)
	_check(input.move() != Vector2.ZERO, "the Warden stayed still once the chat closed")
	Input.action_release(&"move_up")
	Input.action_release(&"attack")
	_finished += 1


func _test_a_line_is_said_and_escape_closes_unsent() -> void:
	var said: String = "hold the east gate"
	await _say(said)
	_check(not _hud.is_chatting(), "Enter sent the line and left the box open")
	_check(_log_has(said), "a line sent alone is not in the log")
	_check(_log_has(PartyLog.speaker_name(1) + ":"), "a line does not carry its speaker's name")
	_check(not _log.is_open(), "the log stayed open as history once the chat closed")
	await _key(KEY_ENTER)
	var box := _hud.get("_chat_box") as LineEdit
	box.text = "never sent"
	await _key(KEY_ESCAPE)
	_check(not _hud.is_chatting(), "Escape did not close the chat")
	_check(not _log_has("never sent"), "Escape sent the line it should have dropped")
	_check(not get_tree().paused, "the Escape that closed the chat also paused the game")
	_finished += 1


func _test_the_commands() -> void:
	var before: int = _log.line_count()
	await _say("/help")
	_check(_log.line_count() >= before + ChatLine.COMMANDS.size(), "/help listed nothing")
	_check(_log_has("/roll"), "/help did not name /roll")
	_check(not _log_has(PartyLog.speaker_name(1) + ": /help"), "/help was said to the party as words")
	await _say("/roll 20")
	var rolled: int = -1
	for line: String in _log.plain_lines():
		var at: int = line.find(" rolls ")
		if at >= 0 and line.contains("(1-20)"):
			rolled = line.substr(at + 7).split(" ")[0].to_int()
	_check(rolled >= 1 and rolled <= 20, "/roll 20 rolled %d" % rolled)
	await _say("/me raises the lantern")
	_check(_log_has("* %s raises the lantern" % PartyLog.speaker_name(1)), "/me was not read as an emote")
	await _say("/nonsense")
	_check(_log_has("No command /nonsense"), "an unknown command was not answered")
	await _say("/time")
	_check(_log_has("on the road"), "/time did not say the road's clock")
	_check(_log_has("[0"), "the log's lines carry no clock")
	await _say("/clear")
	_check(_log.line_count() == 0, "/clear left %d lines" % _log.line_count())
	_finished += 1


func _test_the_wire() -> void:
	var forged: Dictionary = ChatLine.read_wire("/roll 900 100")
	_check(int(forged["kind"]) == ChatLine.Kind.SAY, "a roll past its dice was read as a roll")
	var honest: Dictionary = ChatLine.read_wire("/roll 57 100")
	_check(int(honest["kind"]) == ChatLine.Kind.ROLL and int(honest["rolled"]) == 57,
		"an honest roll from the wire was not read as one")
	_check(ChatLine.clean("one\ntwo\tthree") == "one two three", "a line kept a newline or a tab")
	_check(ChatLine.clean("x".repeat(400)).length() == Balance.CHAT_MAX_LENGTH, "a line ran past the box's length")
	EventBus.coop_chat.emit(2, "look [b]here[/b] [color=red]now")
	await get_tree().process_frame
	_check(_log_has("[b]here[/b]"), "a partner's brackets were read as markup")
	var said: Dictionary = ChatLine.parse("/p /me sneaks")
	_check(int(said["kind"]) == ChatLine.Kind.SAY and not String(said["text"]).begins_with("/"),
		"a party line kept a slash that the far side would read as a command")
	_finished += 1


func _test_burst_mute_and_recall() -> void:
	_log.clear()
	_hud.chat().forget_burst()
	for i: int in Balance.CHAT_BURST + 1:
		await _say("burst %d" % i)
	_check(_log_has("burst %d" % (Balance.CHAT_BURST - 1)), "a burst's last allowed line was held")
	_check(not _log_has("burst %d" % Balance.CHAT_BURST), "a line past the burst was sent")
	_check(_log_has("Slow down"), "a held line did not say why")

	_log.muted_slots[3] = true
	EventBus.coop_chat.emit(3, "muted words")
	await get_tree().process_frame
	_check(not _log_has("muted words"), "a muted seat was heard")
	_log.muted_slots.erase(3)
	await _say("/mute Nobody")
	_check(_log_has("Nobody in the party is called"), "/mute of nobody said nothing")

	await _key(KEY_ENTER)
	await _key(KEY_UP)
	var box := _hud.get("_chat_box") as LineEdit
	_check(box.text == "/mute Nobody", "Up did not say the last line again, it read '%s'" % box.text)
	await _key(KEY_UP)
	_check(box.text.begins_with("burst"), "a second Up did not reach the line before, it read '%s'" % box.text)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	_check(box.text.is_empty(), "Down past the newest line did not clear the box")
	await _key(KEY_ESCAPE)
	_finished += 1


func _test_the_controls_page_names_it() -> void:
	var named: bool = false
	for entry: Dictionary in KeyBindings.FIXED:
		if entry.get("action", &"") == &"chat":
			named = true
	_check(named, "the Controls page's fixed keys do not name the chat")
	_check(KeyBindings.label_for(&"chat") == "Enter", "the chat's key reads '%s'" % KeyBindings.label_for(&"chat"))
	var page: String = FileAccess.get_file_as_string("res://scenes/ui/settings_panel.gd")
	_check(page.contains("KeyBindings.FIXED"), "the Controls page never lists the fixed keys")
	# **Every action is on the page** (owner, 2026-10-08: Tab, which switches
	# build and fight modes, was on none). A key a player cannot read about is a
	# key they do not have, whichever list it belongs on.
	var listed: Dictionary = {}
	for entry: Dictionary in KeyBindings.REBINDABLE + KeyBindings.FIXED:
		listed[StringName(entry.get("action", &""))] = true
	var missing: PackedStringArray = []
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_") or KeyBindings.DEVELOPER.has(action) or listed.has(action):
			continue
		missing.append(String(action))
	_check(missing.is_empty(), "the Controls page names no key for: %s" % ", ".join(missing))
	_check(KeyBindings.label_for(&"toggle_build_mode") == "Tab",
		"build mode reads '%s' on the Controls page" % KeyBindings.label_for(&"toggle_build_mode"))
	_finished += 1


func _check(condition: bool, why: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[chat] " + why)
	return condition
