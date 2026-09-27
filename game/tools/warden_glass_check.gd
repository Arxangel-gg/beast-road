extends Node

## The Warden's Glass changes the look, all of it, and nothing else.
##
##   godot --headless --path game res://tools/warden_glass_check.tscn
##
## Owner, 2026-09-26: the whole character customization *"highly polished and
## aesthetic and juicy"*, skin tones included. The screen is offered to every
## new Warden before their first road, so the ways it goes wrong are the comfort
## card's and a look's together:
##
## - **It writes on open.** Opened and closed untouched, the save must be byte
##   for byte what it was - a screen shown to everybody must not change
##   everybody's save.
## - **A control that reaches nothing.** Every body, skin, hairstyle, colour and
##   beard is pressed through its own button and read back off the save *and*
##   off the preview: a swatch that saved a tone the Warden never wore would be
##   the `DisciplineEffects` lie in a picker.
## - **A picker that disagrees with the look.** The grids hold exactly as many
##   choices as `WardenLook.CHOICES` counts, so a style added to the art is a
##   style the screen offers.
## - **It reaches a number.** Everything the save holds but the look is
##   serialized either side of every press, and must not move.

var _failures: int = 0
var _checks: int = 0
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	var kept: Dictionary = MetaState.look.duplicate()
	MetaState.look = WardenLook.plain()
	var glass := WardenGlass.new()
	add_child(glass)
	await get_tree().process_frame
	_test_an_untouched_glass_writes_nothing(glass)
	await _test_every_control_reaches_the_look(glass)
	_test_the_pickers_match_the_counts(glass)
	_test_the_shortcuts(glass)
	_test_every_new_warden_is_asked()
	glass.queue_free()
	MetaState.look = kept
	for stage: String in ["silent", "reaches", "counts", "shortcuts", "asked"]:
		_check(_reached.has(stage),
			"'%s' never reached its end - it aborted partway, and every check it had not made is unmade" % stage)
	MetaState.resume_saves()
	if _failures == 0:
		print(("[glass] PASS - %d checks: an untouched glass writes nothing, every body, skin, "
			+ "hairstyle, colour and beard reaches the save and the Warden in the glass, "
			+ "nothing but the look moves, and every new Warden - each slot, the menu, "
			+ "a slot begun - is asked") % _checks)
	else:
		push_error("[glass] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 8:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[glass] " + why)


## The save as text, with the look taken out: what a look must never move.
func _all_but_the_look() -> String:
	var parsed: Variant = JSON.parse_string(MetaState.serialized_save())
	if not (parsed is Dictionary):
		return ""
	var save: Dictionary = parsed
	save.erase("look")
	return JSON.stringify(save, "", true)


func _test_an_untouched_glass_writes_nothing(glass: WardenGlass) -> void:
	var before: String = MetaState.serialized_save()
	glass.open()
	_check(glass.visible, "the glass did not open")
	glass.close()
	_check(not glass.touched(), "an untouched glass says it was touched")
	_check(MetaState.serialized_save() == before, "opening and closing the glass changed the save")
	_reached["silent"] = true


func _button(glass: WardenGlass, name: String) -> Button:
	return glass.find_child(name, true, false) as Button


func _press(button: Button) -> void:
	if button == null:
		return
	button.pressed.emit()


func _test_every_control_reaches_the_look(glass: WardenGlass) -> void:
	glass.open()
	var rest: String = _all_but_the_look()
	var frames := glass.find_child("Frames", true, false) as HeroAnimator
	var sprite := glass.find_child("Warden", true, false) as Sprite2D
	_check(frames != null and sprite != null, "the glass has no Warden in it")
	for body: int in WardenDress.BODIES.size():
		var button: Button = _button(glass, "Body%d" % body)
		_check(button != null, "no button for body %d" % body)
		_press(button)
		_check(int(MetaState.look["body"]) == body, "the body button %d chose %s" % [body, str(MetaState.look["body"])])
		if frames != null and frames.dressed():
			_check(String(frames._outfit.get("body", "")) == WardenDress.BODIES[body],
				"the Warden in the glass is not the body chosen")
		# The beard is offered to a body that grows one and to nobody else.
		var section := glass.find_child("SectionBeard", true, false) as Control
		var grows: bool = body == 0 or not WardenDress.head_option(WardenDress.BODIES[body], "beard", 1).is_empty()
		_check(section != null and section.visible == grows,
			"body %d is %s a beard" % [body, "offered" if section != null and section.visible else "not offered"])
	_press(_button(glass, "Body0"))
	for index: int in WardenLook.SKIN_TONES.size():
		_press(_button(glass, "Skin%d" % index))
		_check(int(MetaState.look["skin"]) == index, "the skin swatch %d chose %s" % [index, str(MetaState.look["skin"])])
		var material := sprite.material as ShaderMaterial if sprite != null else null
		var painted: Color = WardenDress.skin_painted("male")
		var tone: Color = WardenLook.skin_tone(MetaState.look, painted)
		var to: Variant = material.get_shader_parameter("skin_to") if material != null else null
		_check(to is Vector3 and (to as Vector3).is_equal_approx(Vector3(tone.r, tone.g, tone.b)),
			"skin %d did not reach the Warden in the glass: %s" % [index, str(to)])
	for index: int in int(WardenLook.CHOICES["hair"]):
		_press(_button(glass, "Hair%d" % index))
		_check(int(MetaState.look["hair"]) == index, "the hairstyle %d chose %s" % [index, str(MetaState.look["hair"])])
		if frames != null and frames.dressed():
			var wanted: Dictionary = WardenDress.head_option("male", "hair", index)
			var worn: Dictionary = frames._outfit.get("hair", {})
			_check(String(worn.get("id", "")) == String(wanted.get("id", "")),
				"hairstyle %d is not what the Warden in the glass wears: %s" % [index, str(worn)])
	for index: int in WardenLook.HAIR_COLOURS.size():
		_press(_button(glass, "HairColour%d" % index))
		_check(int(MetaState.look["hair_colour"]) == index, "the hair colour %d did not take" % index)
	for index: int in int(WardenLook.CHOICES["beard"]):
		_press(_button(glass, "Beard%d" % index))
		_check(int(MetaState.look["beard"]) == index, "the beard %d did not take" % index)
	for key: String in [WardenLook.KEY_CLOAK, WardenLook.KEY_SASH, WardenLook.KEY_LEATHER]:
		var slider := glass.find_child("Dye%s" % key.capitalize(), true, false) as HSlider
		_check(slider != null, "no slider for the %s" % key)
		if slider != null:
			slider.value = 0.3
			_check(is_equal_approx(float(MetaState.look[key]), 0.3), "the %s slider did not dye" % key)
	_check(glass.touched(), "a glass that changed the look says it was not touched")
	# A peek is a picture: pointing at a style shows it on the Warden and saves
	# nothing, and pointing away puts the chosen one back.
	_press(_button(glass, "Hair0"))
	var saved: String = MetaState.serialized_save()
	var peeked: Button = _button(glass, "Hair5")
	if peeked != null and frames != null:
		peeked.mouse_entered.emit()
		_check(MetaState.serialized_save() == saved, "peeking at a hairstyle wrote the save")
		if frames.dressed():
			var shown: Dictionary = frames._outfit.get("hair", {})
			_check(String(shown.get("id", "")) == String(WardenDress.head_option("male", "hair", 5).get("id", "")),
				"peeking at a hairstyle did not show it on the Warden")
			peeked.mouse_exited.emit()
			_check((frames._outfit.get("hair", {}) as Dictionary).is_empty(),
				"pointing away from a hairstyle left it on the Warden")
	_check(_all_but_the_look() == rest, "choosing a look moved something that is not the look")
	glass.close()
	await get_tree().process_frame
	_reached["reaches"] = true


func _test_the_pickers_match_the_counts(glass: WardenGlass) -> void:
	glass.open()
	var hair := glass.find_child("HairGrid", true, false) as GridContainer
	var beard := glass.find_child("BeardGrid", true, false) as GridContainer
	_check(hair != null and hair.get_child_count() == int(WardenLook.CHOICES["hair"]),
		"the hairstyle picker holds %d where the look counts %d" % [hair.get_child_count() if hair != null else -1,
			int(WardenLook.CHOICES["hair"])])
	_check(beard != null and beard.get_child_count() == int(WardenLook.CHOICES["beard"]),
		"the beard picker disagrees with the look's count")
	# And the art: every style the look counts is on disk for the male body, the
	# first one drawn - a count with no sheet behind it is a button that dresses
	# the Warden in nothing.
	if WardenDress.available("male") or not WardenDress.heads().is_empty():
		for index: int in range(1, int(WardenLook.CHOICES["hair"])):
			_check(not WardenDress.head_option("male", "hair", index).is_empty(),
				"hairstyle %d has no sheet for the male body" % index)
		for index: int in range(1, int(WardenLook.CHOICES["beard"])):
			_check(not WardenDress.head_option("male", "beard", index).is_empty(),
				"beard %d has no sheet" % index)
	glass.close()
	_reached["counts"] = true


func _test_the_shortcuts(glass: WardenGlass) -> void:
	glass.open()
	_press(_button(glass, "Body1"))
	for turn: int in 12:
		_press(_button(glass, "Surprise"))
		var look: Dictionary = MetaState.look
		_check(int(look["body"]) == 1, "surprise changed the body")
		_check(WardenLook.same(look, WardenLook.clean(look)), "surprise left a look out of bounds: %s" % str(look))
	_press(_button(glass, "Plain"))
	var plain: Dictionary = WardenLook.plain()
	plain["body"] = 1
	_check(WardenLook.same(MetaState.look, plain), "as painted did not keep the body and clear the rest: %s" % str(MetaState.look))
	_press(_button(glass, "Body0"))
	glass.close()
	_reached["shortcuts"] = true


## **Every new Warden is asked, not the first of a sitting** (owner, 2026-09-27:
## *"New players and new slot characters need to bring up character creation
## screen before starting"*).
##
## The offer was one flag for the whole process, so making a second Warden in a
## new slot the same evening skipped the Glass entirely. It is remembered per
## slot now, and an erased slot is forgotten through `MetaState.slot_erased` -
## emitted here so the connection `GameDirector` makes is what is driven, not a
## call to `forget` that would pass with the wiring missing.
##
## The two new doors are walked in the source rather than driven: headless,
## `offer_glass` returns before it opens anything (a waiting run would hang every
## gate that starts one), so a driven door can prove only that it did not crash.
func _test_every_new_warden_is_asked() -> void:
	var kept_runs: int = MetaState.runs_started
	var kept_offered: Dictionary = WardenGlass._offered_slots.duplicate()
	WardenGlass._offered_slots.clear()
	MetaState.runs_started = 0
	MetaState.look = WardenLook.plain()
	var here: int = MetaState.slot()
	var there: int = (here + 1) % maxi(Balance.SAVE_SLOTS, 2)
	_check(WardenGlass.should_offer(), "a Warden who never walked, in the painted look, is not asked")
	WardenGlass.mark_offered()
	_check(not WardenGlass.should_offer(), "a Warden already asked this sitting is asked again")
	_check(WardenGlass.should_offer_for(there),
		"asking the Warden in slot %d used up the ask for slot %d - a second new Warden in one sitting is never asked" % [here, there])
	MetaState.slot_erased.emit(here)
	_check(WardenGlass.should_offer(),
		"erasing slot %d did not forget it, so the next Warden made there is never asked" % here)
	var dyed: Dictionary = WardenLook.plain()
	dyed[WardenLook.DYES[0]] = 0.25
	MetaState.look = dyed
	_check(not WardenGlass.should_offer(), "a Warden who already chose a look is asked again")
	MetaState.look = WardenLook.plain()
	MetaState.runs_started = 1
	_check(not WardenGlass.should_offer(), "a Warden who has walked a road is asked who they are")
	MetaState.runs_started = kept_runs
	WardenGlass._offered_slots = kept_offered

	var menu: String = _body_of("res://scenes/ui/main_menu.gd", "func _ready")
	_check(menu.contains("_ask_who_walks"), "the menu does not ask a new player who they are when it first appears")
	var ask: String = _body_of("res://scenes/ui/main_menu.gd", "func _ask_who_walks")
	_check(ask.contains("GameDirector.offer_glass()"), "the menu's ask does not open the Glass")
	var play: String = _body_of("res://scenes/ui/save_slot_screen.gd", "func _play")
	var switched: int = play.find("MetaState.use_slot(")
	var offered: int = play.find("GameDirector.offer_glass()")
	_check(switched >= 0 and offered > switched,
		"beginning a slot does not open the Glass for the Warden it now holds")
	var slots: String = FileAccess.get_file_as_string("res://scenes/ui/save_slot_screen.gd")
	_check(slots.contains("_play(index)"), "the slot's button does not go through the door that asks")
	_reached["asked"] = true


## One function's body, from its line to the next top-level declaration.
func _body_of(path: String, header: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	var start: int = text.find("\n" + header)
	if start < 0:
		return ""
	var end: int = text.find("\nfunc ", start + 1)
	return text.substr(start, (end - start) if end > 0 else -1)
