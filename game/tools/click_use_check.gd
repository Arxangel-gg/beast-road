extends Node

## **A left click on what the field is offering uses it** (owner, 2026-09-30:
## *"Left clicking on interactables still doesn't work such as in the hold
## etc."*, after the ruling that *"All interactables should be useable by simply
## left clicking on them while within interaction range"*).
##
## The Hold had been given that rule and the road never had: a seam, a pond, a
## plot, a rift gate, a nest, a well, a wayside encounter, a dungeon's chest and
## its portal, the Walk's chain - every one of them answered the Interact key
## and nothing else, and a left click on any of them swung the Warden's weapon
## at the air beside it.
##
## Four promises, each driven through the real input source:
##
## 1. **The one prompt line says where its offer stands**, and only its holder
##    may move that point.
## 2. **A click that lands there is Interact and not a swing**, and the button
##    held after it is the hold the cast, the reel and the cut read.
## 3. **A click anywhere else is the swing it always was**, and a click that once
##    used an offer never eats the next swing.
## 4. **A pad's attack button is never a click**, however the mouse happens to be
##    resting.
##
## And every owner of the line says where its offer stands - read off the
## source, because the failure is an omission: an owner that never says is an
## offer a click can never reach, with every other check here green.

const OWNERS: PackedStringArray = [
	"res://scripts/systems/dungeon_chest.gd",
	"res://scripts/systems/dungeon_portal.gd",
	"res://scripts/systems/farming.gd",
	"res://scripts/systems/fishing.gd",
	"res://scripts/systems/gathering.gd",
	"res://scripts/systems/rift_gates.gd",
	"res://scripts/systems/walk_chain.gd",
	"res://scripts/systems/wayside.gd",
	"res://scripts/systems/wildlife_nests.gd",
	"res://scenes/battlefield/tower.gd",
]

var _failures: int = 0
var _checks: int = 0
var _hero: Node2D = null
var _input: LocalHeroInput = null
var _mouse_at: Vector2 = Vector2.ZERO


func _ready() -> void:
	MetaState.hold_saves()
	_hero = Node2D.new()
	add_child(_hero)
	_input = LocalHeroInput.new()
	_input.hero = _hero
	_test_the_line_says_where()
	await _test_a_click_on_the_offer_is_interact()
	await _test_a_click_elsewhere_is_a_swing()
	await _test_a_pad_press_is_never_a_click()
	_test_every_owner_says_where()
	EventBus.claim_prompt(&"click_use_check", "")
	MetaState.resume_saves()
	if _failures == 0:
		print(("[click-use] PASS - %d checks: the prompt says where its offer stands, "
			+ "a click on it is Interact and its hold is the reel, a click elsewhere "
			+ "is a swing, a pad press is never a click, and every owner of the "
			+ "line says where") % _checks)
	else:
		push_error("[click-use] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_the_line_says_where() -> void:
	var here := Vector2(410.0, 260.0)
	EventBus.claim_prompt(&"click_use_check", "Mine  ·  Copper", &"", here, 50.0)
	_check(EventBus.prompt_at() == here, "the line did not keep where its offer stands")
	_check(EventBus.lands_on_prompt(here + Vector2(30.0, 0.0)),
		"a point inside the offer's reach did not land on it")
	_check(not EventBus.lands_on_prompt(here + Vector2(80.0, 0.0)),
		"a point past the offer's reach landed on it")
	EventBus.point_prompt(&"somebody_else", Vector2(-900.0, -900.0))
	_check(EventBus.prompt_at() == here, "a system that does not hold the line moved its point")
	EventBus.point_prompt(&"click_use_check", here + Vector2(100.0, 0.0), 50.0)
	_check(EventBus.prompt_at() == here + Vector2(100.0, 0.0),
		"the holder could not move its own point - two seams of one kind say the same words")
	EventBus.claim_prompt(&"click_use_check", "")
	_check(EventBus.prompt_at() == Vector2.INF and not EventBus.lands_on_prompt(here),
		"a cleared line still offered a point to click")
	# An owner that says nothing about where is an offer no click lands on.
	EventBus.claim_prompt(&"click_use_check", "Somewhere")
	_check(not EventBus.lands_on_prompt(here), "an offer with no point was clickable")
	EventBus.claim_prompt(&"click_use_check", "")


func _test_a_click_on_the_offer_is_interact() -> void:
	await _move_mouse(Vector2(640.0, 360.0))
	_press_left(true)
	# Read after the press: a headless window rescales the mouse on every event,
	# so the offer is put wherever the press actually left it.
	var where: Vector2 = _hero.get_global_mouse_position()
	EventBus.claim_prompt(&"click_use_check", "Fish  ·  cast", &"", where, 60.0)
	_check(_input.pressed(HeroInput.BUTTON_INTERACT),
		"a left click on the offer was not a press of Interact")
	_check(not _input.pressed(HeroInput.BUTTON_ATTACK),
		"a left click on the offer swung the weapon as well")
	_check(_input.held(HeroInput.HOLD_INTERACT),
		"the button held after a click on the offer was not the hold a reel reads")
	_check(not _input.held(HeroInput.BUTTON_ATTACK),
		"the button held after a click on the offer read as a held swing")
	await get_tree().process_frame
	_press_left(false)
	_check(not _input.held(HeroInput.HOLD_INTERACT),
		"letting go of the click did not let go of the hold")
	await get_tree().process_frame


func _test_a_click_elsewhere_is_a_swing() -> void:
	await _move_mouse(Vector2(640.0, 360.0))
	_press_left(true)
	var where: Vector2 = _hero.get_global_mouse_position()
	# The offer is somewhere the mouse is not.
	EventBus.claim_prompt(&"click_use_check", "Mine  ·  Copper", &"", where + Vector2(400.0, 0.0), 60.0)
	_check(_input.pressed(HeroInput.BUTTON_ATTACK), "a click beside the offer did not swing")
	_check(not _input.pressed(HeroInput.BUTTON_INTERACT), "a click beside the offer used it")
	await get_tree().process_frame
	_press_left(false)
	await get_tree().process_frame
	# Once a click has used an offer, the next one elsewhere is still a swing.
	_press_left(true)
	where = _hero.get_global_mouse_position()
	EventBus.claim_prompt(&"click_use_check", "Mine  ·  Copper", &"", where, 60.0)
	_check(_input.pressed(HeroInput.BUTTON_INTERACT), "the second click on the offer did not use it")
	await get_tree().process_frame
	_press_left(false)
	await get_tree().process_frame
	_press_left(true)
	where = _hero.get_global_mouse_position()
	EventBus.point_prompt(&"click_use_check", where + Vector2(400.0, 0.0), 60.0)
	_check(_input.pressed(HeroInput.BUTTON_ATTACK),
		"a click that once used an offer ate the next swing")
	await get_tree().process_frame
	_press_left(false)
	await get_tree().process_frame
	EventBus.claim_prompt(&"click_use_check", "")


func _test_a_pad_press_is_never_a_click() -> void:
	await _move_mouse(Vector2(640.0, 360.0))
	var where: Vector2 = _hero.get_global_mouse_position()
	EventBus.claim_prompt(&"click_use_check", "Mine  ·  Copper", &"", where, 60.0)
	# The action without the mouse button: what a pad's attack button sends.
	Input.action_press(&"attack")
	_check(_input.pressed(HeroInput.BUTTON_ATTACK),
		"a pad's attack press over the offer did not swing")
	_check(not _input.pressed(HeroInput.BUTTON_INTERACT),
		"a pad's attack press used the offer the mouse happened to be resting on")
	await get_tree().process_frame
	Input.action_release(&"attack")
	await get_tree().process_frame
	EventBus.claim_prompt(&"click_use_check", "")


func _test_every_owner_says_where() -> void:
	var claim := RegEx.create_from_string("EventBus[.]claim_prompt[(]PROMPT_OWNER, text[^:]*")
	for path: String in OWNERS:
		var source: String = FileAccess.get_file_as_string(path)
		var found: Array[RegExMatch] = claim.search_all(source)
		_check(not found.is_empty(), "%s no longer claims the prompt line" % path)
		for hit: RegExMatch in found:
			var call: String = hit.get_string()
			_check(call.contains("global_position") or call.contains("_offer_at"),
				"%s claims the line without saying where its offer stands: %s - " % [path, call]
					+ "a click on it can never use it")


func _move_mouse(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_mouse_at = at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame


func _press_left(down: bool) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = down
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	# The motion's own point, never the mouse read back: a headless window
	# rescales what it reports, and fed back in that compounds every press.
	press.position = _mouse_at
	press.global_position = _mouse_at
	Input.parse_input_event(press)
	Input.flush_buffered_events()


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[click-use] %s" % why)
