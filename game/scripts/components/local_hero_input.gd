class_name LocalHeroInput
extends HeroInput

## The hero this machine's player is driving, from whatever device is in use.
##
## Every line here was moved out of `hero.gd` rather than written fresh, and the
## behaviour is deliberately unchanged: the stick wins when it is pushed and the
## keys the rest of the time, touch outranks the pad for aim, and both fall back
## to the previous direction. A player who has never heard of co-op must not be
## able to tell that the hero stopped reading `Input` for itself.


func move() -> Vector2:
	if _typing():
		return Vector2.ZERO
	# The stick when it is pushed, the keys otherwise — rather than one device
	# being selected in a menu. A player with a pad in their hands and a keyboard
	# on the desk uses both without telling the game which.
	var pad: Vector2 = KeyBindings.pad_move()
	if pad != Vector2.ZERO:
		_drop_order()
		return pad
	var keys: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if keys != Vector2.ZERO:
		# A hand on the keys is the newest order there is.
		_drop_order()
		return keys
	if order != Order.NONE:
		_steer_now()
		return _steer
	return Vector2.ZERO


## **Orders** (owner, 2026-10-01: *"Clicking on the battlefield should move to
## the location, similar to the click to move setup in the Hold, and only
## attack the clicked target if and when the attack is in range of doing the
## attack on the enemy, whether it's a melee or ranged attack, and if the click
## was on a valid target to then automatically pursue that target until it is
## in range of the attack, inspired by league of legends"*).
##
## An order is what a click asked for, held until it is done: walk to a place,
## or chase a body and attack it - with the swing, or with the bow (`SHOOT`,
## given by F on a body). It lives on the source rather than on the hero
## because it *is* input: what it produces is a direction to walk, an aim and a
## press, exactly what a stick and a button produce, so the hero needs no
## branch for it and a guest's orders cross the wire as the walk and the swing
## they turn into. `ClickMove` gives them; a key, a stick, Ctrl and a click,
## the target falling and the Warden getting nowhere take them away.
enum Order { NONE, MOVE, ATTACK, SHOOT }

var order: int = Order.NONE
var _order_to: Vector2 = Vector2.ZERO
var _order_target_id: int = 0
## This physics frame's answer, worked out once however often it is asked: the
## hero asks `move` twice a tick and the snapshot asks again.
var _steered_frame: int = -1
var _steer: Vector2 = Vector2.ZERO
var _in_reach: bool = false
## The give-up clock: where the Warden stood when this window began, and how
## long the window has left. Movement, not closing the gap, is what counts - a
## body walking away as fast as the Warden is still being chased.
var _stuck_from: Vector2 = Vector2.INF
var _stuck_left: float = 0.0
## Where a chased body was last seen, for a chase into the fog.
var _last_seen: Vector2 = Vector2.INF


func order_move(at: Vector2) -> void:
	order = Order.MOVE
	_order_to = at
	_order_target_id = 0
	_restart_order()


## Chase `body` and attack it once in reach - with the bow when `shoot`.
func order_attack(body: Node2D, shoot: bool = false) -> void:
	if not can_target(body, _wildlife()):
		return
	order = Order.SHOOT if shoot else Order.ATTACK
	_order_target_id = body.get_instance_id()
	_restart_order()
	_last_seen = Hitbox.feet_of(body)


func clear_order() -> void:
	order = Order.NONE
	_order_target_id = 0
	_steer = Vector2.ZERO
	_in_reach = false
	_steered_frame = -1


func order_target() -> Node2D:
	if _order_target_id == 0:
		return null
	var found: Object = instance_from_id(_order_target_id)
	if found == null or not is_instance_valid(found):
		return null
	return found as Node2D


func order_destination() -> Vector2:
	return _order_to


## Whether the order is standing in reach of its target this tick.
func order_in_reach() -> bool:
	_steer_now()
	return _in_reach


func _restart_order() -> void:
	_steered_frame = -1
	_in_reach = false
	_stuck_from = Vector2.INF
	_stuck_left = Balance.CLICK_MOVE_STUCK_SECONDS


func _drop_order() -> void:
	if order != Order.NONE:
		clear_order()


## **What a click may chase**: a road body or an animal that is alive, drawn and
## not the fog's - never a Warden, a spirit or a horse. Static so `ClickMove`
## picks by the same rule the order keeps by. An animal is a sprite the
## wildlife system keeps a record for, so the system is asked.
static func can_target(body: Node2D, wildlife: Wildlife) -> bool:
	# The fog hides a body by not drawing it; a click must not find one either.
	return is_alive_target(body, wildlife) and body.is_visible_in_tree()


## Whether a body is still something an order may chase, seen or not.
static func is_alive_target(body: Node2D, wildlife: Wildlife) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	if body is Hero or body is Companion or body is MountRig:
		return false
	var enemy := body as Enemy
	if enemy != null:
		return not enemy.is_dying()
	if wildlife == null:
		return false
	var record: Dictionary = wildlife.record_for_id(body.get_instance_id())
	return not record.is_empty() and float(record.get("hp", 0.0)) > 0.0 \
		and float(record.get("dying", 0.0)) <= 0.0


## The wildlife on the field the Warden stands in - none in a raid's camp.
func _wildlife() -> Wildlife:
	var warden := hero as Hero
	if warden == null or warden.field == null or not warden.field.has_method("wildlife"):
		return null
	return warden.field.call("wildlife") as Wildlife


## Whether a click is an order at all right now: the setting, a mouse rather
## than a thumb, and a Warden to give it to.
func _clicks_order() -> bool:
	return hero != null and UserSettings.click_to_move() and not TouchInput.is_showing()


## Works out this tick's walk, and whether the target is in reach, once.
func _steer_now() -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _steered_frame:
		return
	_steered_frame = frame
	_steer = Vector2.ZERO
	_in_reach = false
	if order == Order.NONE:
		return
	var warden := hero as Hero
	if not _clicks_order() or warden == null or not warden.is_alive():
		clear_order()
		return
	var feet: Vector2 = warden.global_position
	var goal: Vector2 = _order_to
	if order == Order.MOVE:
		if feet.distance_to(goal) <= Balance.CLICK_MOVE_ARRIVE:
			clear_order()
			return
	else:
		var body: Node2D = order_target()
		var wildlife: Wildlife = _wildlife()
		if not is_alive_target(body, wildlife):
			clear_order()
			return
		# **Into the fog, to where it was last seen** - League's rule. The
		# chase walks there, takes the body up again the moment it is seen,
		# and ends if it arrives to nothing.
		if not body.is_visible_in_tree():
			if _last_seen == Vector2.INF or feet.distance_to(_last_seen) <= Balance.CLICK_MOVE_ARRIVE:
				clear_order()
				return
			_steer = (_last_seen - feet).normalized()
			_tick_stuck(warden, feet)
			return
		_last_seen = Hitbox.feet_of(body)
		# A bow with nothing to loose chases into a swing instead.
		if order == Order.SHOOT and not _can_loose(warden):
			order = Order.ATTACK
		if _reaches(warden, body):
			_in_reach = true
			_stuck_from = Vector2.INF
			return
		goal = Hitbox.feet_of(body)
	_steer = (goal - feet).normalized()
	_tick_stuck(warden, feet)


## Gives the order up when the Warden has been walking at it and getting
## nowhere - a tower, a cliff or the town's wall in the way.
func _tick_stuck(warden: Hero, feet: Vector2) -> void:
	# Time the Warden could not have moved does not count against it.
	var held: bool = warden.attack.is_swinging() or warden.spells.is_channelling()
	if held:
		_stuck_from = Vector2.INF
		return
	if _stuck_from == Vector2.INF:
		_stuck_from = feet
		_stuck_left = Balance.CLICK_MOVE_STUCK_SECONDS
		return
	_stuck_left -= 1.0 / float(Engine.physics_ticks_per_second)
	if _stuck_left > 0.0:
		return
	if feet.distance_to(_stuck_from) < Balance.CLICK_MOVE_STUCK_PROGRESS:
		clear_order()
		return
	_stuck_from = feet
	_stuck_left = Balance.CLICK_MOVE_STUCK_SECONDS


func _reaches(warden: Hero, body: Node2D) -> bool:
	var from: Vector2 = warden.combat_origin()
	if order == Order.SHOOT:
		var bow: RangedWeaponData = warden.ranged.weapon()
		return bow != null and from.distance_to(Hitbox.meet(body, from)) \
			<= bow.effective_range * Balance.CLICK_MOVE_RANGED_SHARE
	return warden.attack.reaches(from, body, Balance.CLICK_MOVE_REACH_SHARE)


## Whether the Warden's bow has anything to loose.
static func _can_loose(warden: Hero) -> bool:
	if warden.ranged == null or not warden.ranged.armed():
		return false
	for kind: AmmoData in RunState.ammo_for_weapon(RunState.ranged_id):
		if RunState.ammo_count(kind.id) > 0:
			return true
	return false


## The aim an order in reach gives - at the body - or zero for none. A spell or
## a bow loosed by hand that tick goes where the cursor points, as an ability
## does in League, so a cast is never dragged onto whatever is being swung at.
func _order_aim() -> Vector2:
	if order != Order.ATTACK and order != Order.SHOOT:
		return Vector2.ZERO
	_steer_now()
	if not _in_reach:
		return Vector2.ZERO
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		if Input.is_action_just_pressed(&"spell_%d" % (slot + 1)):
			return Vector2.ZERO
	if order != Order.SHOOT and Input.is_action_just_pressed(&"ranged"):
		return Vector2.ZERO
	var body: Node2D = order_target()
	var warden := hero as Hero
	if body == null or warden == null:
		return Vector2.ZERO
	var from: Vector2 = warden.combat_origin()
	var to: Vector2 = Hitbox.meet(body, from) - from
	return to.normalized() if to.length() > 0.001 else Vector2.ZERO


## The swing an order in reach asks for, every tick it stands there - League's
## auto-attack. The chain's own buffer and cadence decide when it lands.
func _order_swings() -> bool:
	if order != Order.ATTACK:
		return false
	_steer_now()
	return _in_reach


func _order_looses() -> bool:
	if order != Order.SHOOT:
		return false
	_steer_now()
	var warden := hero as Hero
	return _in_reach and warden != null and warden.ranged != null \
		and not warden.ranged.is_drawing()


func aim(previous: Vector2) -> Vector2:
	# Touch first, for the same reason the pad is checked before the mouse: a
	# thumb on the right stick is an explicit statement about where to point, and
	# on a phone the emulated mouse cursor is wherever the last tap happened to
	# land. Movement and attack arrive as ordinary input actions and need no
	# branch; a direction is not a button, so aim does.
	var touch: Vector2 = TouchInput.aim()
	if touch != Vector2.ZERO:
		return touch
	var pad: Vector2 = KeyBindings.pad_aim()
	if pad != Vector2.ZERO:
		return pad.normalized()
	if hero == null:
		return previous
	var ordered: Vector2 = _order_aim()
	if ordered != Vector2.ZERO:
		return ordered
	# **From the body, not from the boots.** A `CharacterBody2D`'s position is its
	# feet - `Hero` deliberately moves the node down to its ground contact so the
	# shared Y sorter has something meaningful to sort by - but every shot, swing
	# and spell leaves from `combat_origin()`, which is that same point lifted
	# back up to the chest.
	#
	# Measuring the aim from one and firing from the other put the arrow on a
	# parallel line about fifty units above the one the player drew with the
	# cursor: nearly ten degrees of error at mid range and far worse up close.
	# Reported as "the ranged weapons do not shoot exactly where the mouse cursor
	# was aiming". Both ends of the line come from the same point now.
	var from: Vector2 = hero.combat_origin() if hero.has_method("combat_origin") \
		else hero.global_position
	return HeroInput.aim_at(from, hero.get_global_mouse_position(), previous)


## **A left click on what the field is offering uses it** (owner, 2026-09-30:
## *"All interactables should be useable by simply left clicking on them while
## within interaction range"*). The prompt line is only ever held while the
## Warden is in reach of something, and it says where that something stands;
## a click whose point lands there is a press of Interact and not a swing, and
## the button held after it is the reel, the cast and the cut. A click anywhere
## else is the swing it always was.
##
## Only the mouse: a pad's attack button is never a click, and a phone has its
## own button wearing the prompt.
func _click_uses() -> bool:
	if hero == null or TouchInput.is_showing():
		return false
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return false
	return EventBus.lands_on_prompt(hero.get_global_mouse_position())


## Whether the left button that is down went down on the offer.
var _using_click: bool = false


## **Nothing a hand does reaches the Warden while the player is typing**
## (2026-10-01). A line typed into the chat walked, swung and cast with every
## letter, because the keys are polled rather than heard - see `TextFocus`.
func _typing() -> bool:
	return hero != null and TextFocus.typing(hero)


func _read_press(button: int) -> bool:
	if _typing():
		return false
	match button:
		BUTTON_ATTACK:
			if not Input.is_action_just_pressed(&"attack"):
				return _order_swings()
			# Each press decides afresh, so a click that once landed on an offer
			# can never eat the next swing.
			_using_click = _click_uses()
			if _using_click:
				return false
			# **A click is an order, not a swing** (2026-10-01) - `ClickMove`
			# has already read where it landed. Ctrl and a click swings where
			# it points, as it always did; a key or a pad bound to attack is
			# never a click.
			if _clicks_order() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
					and not Input.is_key_pressed(KEY_CTRL):
				return _order_swings()
			return true
		BUTTON_DASH:
			return Input.is_action_just_pressed(&"dash")
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		if button == HeroInput.spell_button(slot):
			return Input.is_action_just_pressed(&"spell_%d" % (slot + 1))
	if button == BUTTON_RANGED:
		# A bow order looses on its own clock; a press with no order looses
		# where the cursor points.
		if order == Order.SHOOT:
			return _order_looses()
		return Input.is_action_just_pressed(&"ranged")
	if button == BUTTON_AMMO_CYCLE:
		return Input.is_action_just_pressed(&"ammo_cycle")
	if button == BUTTON_USE_ITEM:
		# No touch branch, deliberately. The USE button presses the *action*, the
		# way the dash and the bow's trigger do, so a thumb and a key arrive here
		# by the same route. Asking `TouchInput` again here would consume the
		# press twice.
		return Input.is_action_just_pressed(&"use_item")
	if button == BUTTON_INTERACT:
		if Input.is_action_just_pressed(&"attack") and _click_uses():
			_using_click = true
			return true
		return Input.is_action_just_pressed(&"interact")
	# **The mount key** (2026-09-17). Not rebindable and not on the pad, for the
	# reason recorded in the memory directory: every rebindable action needs a
	# joypad button and there is no free one. What a thumb and a pad reach
	# instead is the action bar's own Ride button, which presses this intent.
	if button == BUTTON_MOUNT:
		return Input.is_action_just_pressed(&"mount") or TouchInput.mount_pressed()
	return false


func _read_hold(mask: int) -> bool:
	if _typing():
		return false
	if mask == HOLD_REVIVE:
		# The touch button is asked as well as the key. There is no `revive`
		# action a thumb can reach, so on a phone this was always false and a
		# fallen partner stayed down for the rest of the run.
		return Input.is_action_pressed(&"revive") or TouchInput.revive_held()
	if mask == HOLD_ATTACK:
		return TouchInput.is_showing() and TouchInput.attacking()
	# The reel. The touch button drives the action itself, so one read serves
	# a key, a pad button and a thumb.
	if mask == HOLD_INTERACT:
		return Input.is_action_pressed(&"interact") or _click_still_down()
	# **The sprint key** (2026-09-17). Its own action, so it can be found in the
	# settings screen and moved - which is the half that was missing, not the
	# sprint. On a pad it shares the dash button, so this reads true while A is
	# down and the hero engages at once.
	if mask == HOLD_SPRINT:
		return Input.is_action_pressed(&"sprint")
	if mask == HOLD_GUARD:
		return InputMap.has_action(&"guard") and Input.is_action_pressed(&"guard")
	# The dash button held. The older way in, and still the only one on a thumb:
	# the hero tells a tap from a hold, not this.
	if mask == HOLD_DASH:
		return Input.is_action_pressed(&"dash")
	# Held attack, for anything that wants to know the button is still down.
	# Tested *after* the holds, so a future hold sharing this value cannot shadow
	# it the way this branch once shadowed the revive.
	if mask == BUTTON_ATTACK:
		return Input.is_action_pressed(&"attack") and not _click_still_down()
	return false


## The click that used the offer, still held - and forgotten the moment the
## button comes up, so the next click is asked again.
func _click_still_down() -> bool:
	if _using_click and not Input.is_action_pressed(&"attack"):
		_using_click = false
	return _using_click


func is_local() -> bool:
	return true


## This frame's intentions, packed for the wire.
##
## Sent as-is rather than as a position: relaying *input* rather than *outcome*
## is what keeps the host the only thing that decides where a hero ends up. A
## guest that sent its position would be telling the host what happened, which is
## the authority inversion the whole layer exists to prevent.
func snapshot(current_aim: Vector2) -> Array:
	var buttons: int = 0
	if pressed(BUTTON_ATTACK):
		buttons |= BUTTON_ATTACK
	if pressed(BUTTON_DASH):
		buttons |= BUTTON_DASH
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var bit: int = HeroInput.spell_button(slot)
		if pressed(bit):
			buttons |= bit
	# Packed like every other button, so a guest's shot is the host's shot. A
	# ranged attack that only existed locally would fire on one screen.
	for bit: int in [BUTTON_RANGED, BUTTON_AMMO_CYCLE, BUTTON_USE_ITEM, BUTTON_INTERACT,
			BUTTON_MOUNT]:
		if pressed(bit):
			buttons |= bit
	var holds: int = 0
	if held(HOLD_REVIVE):
		holds |= HOLD_REVIVE
	if held(HOLD_ATTACK):
		holds |= HOLD_ATTACK
	if held(HOLD_INTERACT):
		holds |= HOLD_INTERACT
	if held(HOLD_DASH):
		holds |= HOLD_DASH
	if held(HOLD_SPRINT):
		holds |= HOLD_SPRINT
	if held(HOLD_GUARD):
		holds |= HOLD_GUARD
	return [move(), current_aim, buttons, holds]
