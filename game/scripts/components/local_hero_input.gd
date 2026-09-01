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
	# The stick when it is pushed, the keys otherwise — rather than one device
	# being selected in a menu. A player with a pad in their hands and a keyboard
	# on the desk uses both without telling the game which.
	var pad: Vector2 = KeyBindings.pad_move()
	if pad != Vector2.ZERO:
		return pad
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


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


func pressed(button: int) -> bool:
	match button:
		BUTTON_ATTACK:
			return Input.is_action_just_pressed(&"attack")
		BUTTON_DASH:
			return Input.is_action_just_pressed(&"dash")
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		if button == HeroInput.spell_button(slot):
			return Input.is_action_just_pressed(&"spell_%d" % (slot + 1))
	if button == BUTTON_RANGED:
		return Input.is_action_just_pressed(&"ranged")
	if button == BUTTON_AMMO_CYCLE:
		return Input.is_action_just_pressed(&"ammo_cycle")
	return false


func held(mask: int) -> bool:
	if mask == HOLD_REVIVE:
		# The touch button is asked as well as the key. There is no `revive`
		# action a thumb can reach, so on a phone this was always false and a
		# fallen partner stayed down for the rest of the run.
		return Input.is_action_pressed(&"revive") or TouchInput.revive_held()
	if mask == HOLD_ATTACK:
		return TouchInput.is_showing() and TouchInput.attacking()
	# Held attack, for anything that wants to know the button is still down.
	# Tested *after* the holds, so a future hold sharing this value cannot shadow
	# it the way this branch once shadowed the revive.
	if mask == BUTTON_ATTACK:
		return Input.is_action_pressed(&"attack")
	return false


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
	for bit: int in [BUTTON_RANGED, BUTTON_AMMO_CYCLE]:
		if pressed(bit):
			buttons |= bit
	var holds: int = 0
	if held(HOLD_REVIVE):
		holds |= HOLD_REVIVE
	if held(HOLD_ATTACK):
		holds |= HOLD_ATTACK
	return [move(), current_aim, buttons, holds]
