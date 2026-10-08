class_name WildlifeFeeding
extends RefCounted

## **The road's dead feed the road** (owner, 2026-10-07): *"other wildlife can
## come and eat or pull and carry away to eat somewhere else if they prefer, and
## ... fight protectively over the food if they decide to be territorial about
## it, maybe unless challenged by something they decide is more alpha than them
## and if their behavior is appropriate then they may decide to surrender the
## food and leave or maybe they'll try to fight for some time and maybe even to
## the death over it."*
##
## An animal that eats carrion (`WildlifeData.scavenges`) smells a corpse - from
## further downwind, which is the first time the wind decides where an animal
## goes - walks to it, and eats, a bite at a time, each bite jolting the carcass
## (`CorpseField.bite`). One that carries (`carries_food`) may pick it up and eat
## it somewhere quieter. Two at one carcass weigh each other: the weaker by a
## margin yields and goes; close enough, two that hold ground fight over it,
## through the door every animal-on-animal blow goes through, as the cycle - the
## earth does not mind it and nobody is paid.
##
## Host only, like everything an animal decides. A look and an ecology: it pays
## nobody and moves no number in a fight.

var wild: Wildlife = null
var _dice := RandomNumberGenerator.new()


func _init(owner: Wildlife) -> void:
	wild = owner
	_dice.seed = absi(hash("feeding:%d" % RunState.run_seed))


## How far this animal smells a corpse at `meat`: further when the wind blows
## from the meat to it.
static func scent_reach(at: Vector2, meat: Vector2, wind: Vector2) -> float:
	var reach: float = Balance.FEED_SCENT_RADIUS
	if wind.length_squared() < 0.0001:
		return reach
	var downwind: float = (at - meat).normalized().dot(wind.normalized())
	return reach * (1.0 + Balance.FEED_SCENT_WIND * clampf(downwind, -1.0, 1.0) * clampf(wind.length(), 0.0, 1.0))


## How strong an animal is when it comes to a carcass: its pool, its size and
## its rank - the thing a rival weighs before it decides to yield.
static func alpha_of(animal: Dictionary) -> float:
	var kind := animal.get("data", null) as WildlifeData
	if kind == null:
		return 0.0
	var rank: int = WildlifeFamilies.rarity_of(animal)
	return kind.max_hp * kind.scale * float(animal.get("size", 1.0)) * (1.0 + 0.5 * float(rank)) \
		* (1.4 if kind.temperament == WildlifeData.Temperament.PREDATORY else 1.0)


## One frame of an animal's appetite. Returns true when it owned the frame.
func tick(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, delta: float) -> bool:
	var corpses: CorpseField = _corpses()
	if corpses == null or not kind.scavenges:
		return false
	var meal: Dictionary = animal.get("meal", {}) as Dictionary
	# Running, arriving or leaving is no time to eat.
	var state: int = int(animal.get("state", 0))
	if state == Wildlife.State.FLEEING or state == Wildlife.State.LEAVING or state == Wildlife.State.ARRIVING:
		if not meal.is_empty():
			_let_go(animal, corpses)
		return false
	if not meal.is_empty() and (not corpses.corpses().has(meal)
			or float(meal["meat"]) <= Balance.CORPSE_EATEN_FROM):
		_let_go(animal, corpses)
		meal = {}
	var me: Vector2 = sprite.global_position
	if meal.is_empty():
		animal["feed_scan"] = float(animal.get("feed_scan", 0.0)) - delta
		if float(animal["feed_scan"]) > 0.0:
			return false
		animal["feed_scan"] = Balance.FEED_SCAN_SECONDS * _dice.randf_range(0.8, 1.2)
		if int(animal.get("state", 0)) != Wildlife.State.SETTLED or wild._frightened(me, kind):
			return false
		var found: Dictionary = corpses.nearest_meat(me, Balance.FEED_SCENT_RADIUS * (1.0 + Balance.FEED_SCENT_WIND))
		if found.is_empty() or me.distance_to(found["at"] as Vector2) > scent_reach(me, found["at"] as Vector2, RunState.wind):
			return false
		animal["meal"] = found
		animal["feeding"] = false
		meal = found
	# Fright ends a meal: something bigger than the carcass is worth.
	if wild._frightened(me, kind):
		_let_go(animal, corpses)
		return false
	var carried: bool = meal.get("carried_by", null) == sprite
	if carried:
		return _carry(animal, sprite, kind, corpses, meal, delta)
	var at: Vector2 = meal["at"] as Vector2
	var gap: float = me.distance_to(at)
	if gap > Balance.FEED_REACH:
		animal["feeding"] = false
		_walk(animal, sprite, kind, at - me, delta)
		return true
	# At the carcass: weigh any rival, then eat - or pick it up.
	if _contest(animal, sprite, kind, meal):
		return true
	if not bool(animal.get("feeding", false)):
		animal["feeding"] = true
		animal["bite_left"] = Balance.FEED_BITE_SECONDS
		if kind.carries_food and meal.get("carried_by", null) == null \
				and int(meal.get("size", 1)) <= _carry_limit(kind) and _dice.randf() < Balance.FEED_CARRY_CHANCE:
			corpses.carry(meal, sprite)
			animal["carry_to"] = wild._bolt_target(me)
			return true
	animal["bite_left"] = float(animal.get("bite_left", 0.0)) - delta
	if float(animal["bite_left"]) <= 0.0:
		animal["bite_left"] = Balance.FEED_BITE_SECONDS * _dice.randf_range(0.8, 1.3)
		corpses.bite(meal, Balance.FEED_BITE * kind.scale, me)
		animal["bites"] = int(animal.get("bites", 0)) + 1
		wild.earn(animal, Balance.WILDLIFE_LEVEL_XP_MEAL)
	wild._animate(animal, sprite, delta, false)
	return true


## Carrying it away: walk to somewhere quieter, put it down, and eat there.
func _carry(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, corpses: CorpseField,
		meal: Dictionary, delta: float) -> bool:
	var to: Vector2 = animal.get("carry_to", sprite.global_position) as Vector2
	var toward: Vector2 = to - sprite.global_position
	if toward.length() <= Balance.FEED_REACH:
		corpses.drop(meal)
		animal["carry_to"] = null
		animal["feeding"] = false
		return true
	_walk(animal, sprite, kind, toward, delta)
	return true


## **Two at one carcass.** The weaker by a margin yields and goes; a near match
## between two that hold their ground is a fight, through the cycle's own door;
## otherwise they share. Returns true when this animal's frame was spent on it.
func _contest(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, meal: Dictionary) -> bool:
	var mine: float = alpha_of(animal)
	for other: Dictionary in wild.living():
		if other == animal or other.get("meal", {}) != meal or float(other.get("dying", 0.0)) > 0.0:
			continue
		var rival_sprite: Sprite2D = other.get("sprite", null) as Sprite2D
		if rival_sprite == null or rival_sprite.global_position.distance_to(sprite.global_position) > Balance.FEED_REACH * 2.0:
			continue
		var theirs: float = alpha_of(other)
		if mine * Balance.FEED_YIELD_RATIO < theirs:
			# Outclassed: it gives the food up and leaves.
			animal["meal"] = {}
			animal["feeding"] = false
			animal["state"] = Wildlife.State.FLEEING
			animal["goal"] = wild._bolt_target(sprite.global_position, rival_sprite.global_position)
			animal["yielded"] = int(animal.get("yielded", 0)) + 1
			return true
		var proud: bool = kind.temperament == WildlifeData.Temperament.TERRITORIAL \
			or kind.temperament == WildlifeData.Temperament.PREDATORY
		if proud and theirs * Balance.FEED_YIELD_RATIO >= mine:
			animal["fight_left"] = float(animal.get("fight_left", 0.0)) - wild.get_process_delta_time()
			if float(animal["fight_left"]) <= 0.0:
				animal["fight_left"] = Balance.FEED_FIGHT_SECONDS
				wild.wound_sprite(rival_sprite, kind.damage * Balance.FEED_FIGHT_SHARE + 1.0, false, "cycle")
				animal["fought"] = int(animal.get("fought", 0)) + 1
				Vfx.dust(rival_sprite.global_position, Color(0.4, 0.33, 0.25), 3, 18.0)
	return false


func _walk(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, toward: Vector2, delta: float) -> void:
	var step: Vector2 = toward.normalized() * kind.speed * delta
	if step.length() > toward.length():
		step = toward
	wild._walk_step(sprite, step)
	wild._face(animal, sprite, kind, step, delta)
	wild._animate(animal, sprite, delta, true)


func _let_go(animal: Dictionary, corpses: CorpseField) -> void:
	var meal: Dictionary = animal.get("meal", {}) as Dictionary
	if not meal.is_empty() and meal.get("carried_by", null) == animal.get("sprite", null):
		corpses.drop(meal)
	animal["meal"] = {}
	animal["feeding"] = false
	animal["carry_to"] = null


## The biggest corpse size this animal can carry in its mouth.
func _carry_limit(kind: WildlifeData) -> int:
	return CorpseField.Size.MEDIUM if kind.scale >= Balance.FEED_CARRY_SCALE else CorpseField.Size.SMALL


func _corpses() -> CorpseField:
	var field: Node = wild.field if wild != null else null
	if field == null:
		return null
	return field.get("corpses") as CorpseField if "corpses" in field else null
