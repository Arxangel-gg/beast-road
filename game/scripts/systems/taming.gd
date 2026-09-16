class_name Taming
extends Object

## **Taking an animal alive.** The odds, and what happens when it works.
##
## Owner brief, 2026-09-16: taming "should not be with killing the wildlife but
## similar to pokemon that involves lowering its health to have a higher chance
## and something else to catch the wildlife".
##
## **What decides it, in the order it matters:**
##
##  1. **How hurt it is.** Whole, almost nothing works; at a sliver, most things
##     do. This is the whole shape of the mechanic and it is why wildlife mend
##     slowly rather than quickly - the point of wearing an animal down is that
##     it stays worn down long enough to throw at.
##  2. **What it is.** A legendary is far harder than a rabbit, on the same
##     rarity ladder the gear, the fish and the spirits all use.
##  3. **What you threw.** A better snare is a better chance, which is what makes
##     crafting one worth doing.
##
## **Nothing here is a power scale.** A caught animal goes into the pen at the
## health it was caught with and is the *same* creature it was on the road: same
## species, same rarity, same shine, same temperament. Catching is a second way
## to *get* one, not a way to get a better one - which is what keeps this inside
## the pen's own bound, where the bond is permanent and the animal is not.
##
## **And it can only ever take what the road actually offered.** The rarity, the
## shine and the trait are read off the animal that was on the field, decided
## when it was placed; nothing here rolls any of them. A capture that re-rolled
## its prize would be a loot box wearing a rope.

## A static-only helper, like `DisciplineEffects`. Nothing here holds state -
## the animal is the state, and it lives in `Wildlife`.


## **How likely this throw is to take.**
##
## Public so the interface can show it before the rope leaves the hand: a
## capture the player cannot estimate is a slot machine, and the whole reason to
## wear an animal down is lost if they cannot see it working.
static func chance_for(target_id: int, field: Node) -> float:
	var animal: Dictionary = _animal(target_id, field)
	if animal.is_empty():
		return 0.0
	var kind: WildlifeData = animal.get("data", null) as WildlifeData
	if kind == null:
		return 0.0
	var full: float = kind.max_hp * (Balance.WILDLIFE_ELITE_HEALTH
		if bool(animal.get("elite", false)) else 1.0)
	var left: float = clampf(float(animal.get("hp", full)) / maxf(full, 1.0), 0.0, 1.0)
	# Hurt is the whole of it: a whole animal barely gives, a spent one mostly
	# does. Curved rather than straight, so the last quarter of a fight is where
	# the odds actually move - otherwise the correct play is one swing and a
	# throw, and the wearing-down is decoration.
	var worn: float = pow(1.0 - left, Balance.TAME_WEAR_CURVE)
	var chance: float = lerpf(Balance.TAME_CHANCE_WHOLE, Balance.TAME_CHANCE_SPENT, worn)
	# What it is. The same four-rung ladder the gear, the fish and the spirits
	# use, so a player reads one rarity across the whole game.
	var rank: int = clampi(WildlifeFamilies.rarity_of(animal), 0,
		Balance.TAME_RARITY_SCALE.size() - 1)
	chance *= Balance.TAME_RARITY_SCALE[rank]
	if bool(animal.get("shiny", false)):
		chance *= Balance.TAME_SHINY_SCALE
	# What you threw.
	chance *= _snare_strength()
	# A frightened animal is harder to rope and a frenzied one barely notices,
	# which is the one place the Wildblight makes something *easier*.
	if WildlifeFamilies.is_frenzied(animal):
		chance *= Balance.TAME_FRENZIED_SCALE
	elif int(animal.get("state", 0)) == Wildlife.State.FLEEING:
		chance *= Balance.TAME_FLEEING_SCALE
	return clampf(chance, 0.0, Balance.TAME_CHANCE_CEILING)


## **It worked.** The animal comes off the road and goes into the pen at the
## health it was caught with - hurt, because being hurt is how it was caught -
## and the pen mends it on the wall clock from there.
static func take(target_id: int, field: Node) -> bool:
	var animals: Node = _wildlife(field)
	var animal: Dictionary = _animal(target_id, field)
	if animals == null or animal.is_empty():
		return false
	var kind: WildlifeData = animal.get("data", null) as WildlifeData
	if kind == null:
		return false
	if not MetaState.pen_has_room():
		# Said rather than silently dropped: losing a legendary to a full pen
		# with no explanation is the worst thing this system could do.
		EventBus.preparation_warning.emit("The pen is full. Release one first.")
		return false
	var full: float = kind.max_hp * (Balance.WILDLIFE_ELITE_HEALTH
		if bool(animal.get("elite", false)) else 1.0)
	var health: float = clampf(float(animal.get("hp", full)) / maxf(full, 1.0),
		Balance.TAME_MIN_HEALTH, 1.0)
	# **Read off the animal, never rolled.** Its rarity, its shine and its
	# temperament were all decided the moment it was placed; a capture that
	# re-rolled any of them would be a loot box wearing a rope.
	var uid: String = MetaState.pen_add(kind.id,
		WildlifeFamilies.rarity_of(animal), bool(animal.get("shiny", false)),
		str(animal.get("trait", "")), health)
	if uid.is_empty():
		return false
	# Meeting one and keeping one are two different facts, and the journal
	# records the first whether or not the second worked - the same split
	# hatching an egg already makes.
	MetaState.record_spirit_encounter(kind.id, WildlifeFamilies.rarity_of(animal),
		bool(animal.get("shiny", false)), str(animal.get("trait", "")))
	if animals.has_method("retire_by_id"):
		animals.call("retire_by_id", target_id)
	# **Straight to work** (owner, 2026-09-16: "when the wildlife is captured it
	# can be instantly set as a companion that is usable"). Only when nothing is
	# already out: a catch that silently replaced the animal a player walked in
	# with would be the mid-run swap the pen exists to forbid.
	if MetaState.pen_taken.is_empty():
		MetaState.pen_take(uid, true)
	EventBus.wildlife_tamed.emit(kind.id, uid,
		WildlifeFamilies.rarity_of(animal), bool(animal.get("shiny", false)))
	return true


## It broke free. Everything of that species on the field knows, which is the
## cost of a failed throw: a second attempt is against an animal that is now
## running.
static func scare(target_id: int, field: Node) -> void:
	var animals: Node = _wildlife(field)
	var animal: Dictionary = _animal(target_id, field)
	if animals == null or animal.is_empty():
		return
	var sprite: Variant = animal.get("sprite")
	if sprite == null or not is_instance_valid(sprite as Object):
		return
	if animals.has_method("scare_from"):
		animals.call("scare_from", (sprite as Node2D).global_position,
			Balance.TAME_SCARE_RADIUS)


# --- Finding things -------------------------------------------------------------

static func _wildlife(field: Node) -> Node:
	if field == null or not field.has_method("wildlife"):
		return null
	return field.call("wildlife") as Node


## The animal's record, by the instance id of its sprite. Held by id rather than
## by reference for the reason everything in this project is: casting a freed
## object is an error in itself, raised before any guard inside can run.
static func _animal(target_id: int, field: Node) -> Dictionary:
	var animals: Node = _wildlife(field)
	if animals == null or not animals.has_method("record_for_id"):
		return {}
	return animals.call("record_for_id", target_id) as Dictionary


## How good the snare in hand is. A better one is a better chance, which is what
## makes crafting one worth doing.
static func _snare_strength() -> float:
	var held: AmmoData = ContentDB.ammo_kinds.get(RunState.ammo_id, null) as AmmoData
	if held == null or not held.snares:
		return 1.0
	return maxf(held.snare_strength, 0.05)
