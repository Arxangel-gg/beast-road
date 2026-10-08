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

## How an animal means to eat: beside others, or holding what it has.
enum Mood { SHARE, GUARD }
## What a fight over a carcass is for.
enum Intent { SPAR, SCARE, DEATH }
## Where a stand-off is.
enum Stage { CHALLENGE, FIGHT }

## How each fight over food ended, by intent and by how. For the gate.
var bouts: Dictionary = {}


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
	if corpses == null or not eats_the_dead(kind):
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
		var reach: float = scent_reach(me, found["at"] as Vector2, RunState.wind) if not found.is_empty() else 0.0
		# A hunter that is no scavenger takes only a fresh kill, close by.
		if not kind.scavenges:
			reach *= Balance.FEED_OPPORTUNIST_SCENT
			if not found.is_empty() and CorpseField.state_for(float(found["meat"])) != 0:
				return false
		if found.is_empty() or me.distance_to(found["at"] as Vector2) > reach:
			return false
		animal["meal"] = found
		animal["feeding"] = false
		animal["feed_mood"] = roll_mood(kind, _dice)
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


## **Who eats the dead**: a scavenger, and a hunter that would not mind.
static func eats_the_dead(kind: WildlifeData) -> bool:
	return kind != null and (kind.scavenges or kind.temperament == WildlifeData.Temperament.PREDATORY)


## **Beside others, or holding it** - decided as an animal comes to a meal, by
## its temperament.
static func roll_mood(kind: WildlifeData, dice: RandomNumberGenerator) -> int:
	var chance: float = Balance.FEED_GUARD_MEEK
	match kind.temperament:
		WildlifeData.Temperament.PREDATORY:
			chance = Balance.FEED_GUARD_PREDATORY
		WildlifeData.Temperament.TERRITORIAL:
			chance = Balance.FEED_GUARD_TERRITORIAL
	return Mood.GUARD if dice.randf() < chance else Mood.SHARE


## What a fight over food is for, by the temperament of the one that starts it.
static func roll_intent(kind: WildlifeData, dice: RandomNumberGenerator) -> int:
	var proud: bool = kind.temperament == WildlifeData.Temperament.PREDATORY \
		or kind.temperament == WildlifeData.Temperament.TERRITORIAL
	var weights: Array[float] = Balance.FEED_INTENT_PROUD if proud else Balance.FEED_INTENT_MEEK
	var roll: float = dice.randf() * (weights[0] + weights[1] + weights[2])
	for index: int in weights.size():
		roll -= weights[index]
		if roll <= 0.0 and weights[index] > 0.0:
			return index
	return Intent.SPAR


## The chance an animal backs off a stand-off: `BACKOFF` at an even match,
## likelier the more it is outclassed, likelier still if it only came to share.
static func backoff_chance(mine: float, theirs: float, sharer: bool) -> float:
	var outclassed: float = theirs / maxf(mine, 0.001)
	return clampf(Balance.FEED_BACKOFF * outclassed * (Balance.FEED_SHARER_BACKOFF if sharer else 1.0),
		0.04, 0.95)


func _mood_of(animal: Dictionary) -> int:
	if not animal.has("feed_mood"):
		animal["feed_mood"] = roll_mood(animal["data"] as WildlifeData, _dice)
	return int(animal["feed_mood"])


## **Two at one carcass, or one coming for a guard's hoard.** A pair in a
## stand-off plays it out; a rival that outclasses one by a margin and will not
## share sends it away; two that share eat side by side; a guard faces anything
## that comes for its carcass or the corpses near it. Returns true when this
## animal's frame was spent on it.
func _contest(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, meal: Dictionary) -> bool:
	var bout: Dictionary = animal.get("bout", {}) as Dictionary
	if not bout.is_empty():
		return _tick_bout(animal, sprite, kind, bout)
	var mine: float = alpha_of(animal)
	var mood: int = _mood_of(animal)
	for other: Dictionary in wild.living():
		if other == animal or float(other.get("dying", 0.0)) > 0.0:
			continue
		var their_meal: Dictionary = other.get("meal", {}) as Dictionary
		if their_meal.is_empty():
			continue
		var rival_sprite: Sprite2D = other.get("sprite", null) as Sprite2D
		if rival_sprite == null or not is_instance_valid(rival_sprite):
			continue
		var apart: float = rival_sprite.global_position.distance_to(sprite.global_position)
		var same: bool = their_meal == meal and apart <= Balance.FEED_REACH * 2.0
		# A guard holds the corpses near its own - the ones it will eat later.
		var hoard: bool = mood == Mood.GUARD and their_meal != meal \
			and (their_meal["at"] as Vector2).distance_to(meal["at"] as Vector2) <= Balance.FEED_HOARD_REACH \
			and apart <= Balance.FEED_GUARD_REACH
		if not same and not hoard:
			continue
		if not (other.get("bout", {}) as Dictionary).is_empty():
			continue
		var theirs: float = alpha_of(other)
		var their_mood: int = _mood_of(other)
		if mood == Mood.SHARE and their_mood == Mood.SHARE:
			continue
		# Outclassed by one that will not share: it gives the food up - whichever
		# of the two notices first.
		if same and mine * Balance.FEED_YIELD_RATIO < theirs and their_mood == Mood.GUARD:
			_yield(animal, sprite, rival_sprite)
			return true
		if same and theirs * Balance.FEED_YIELD_RATIO < mine and mood == Mood.GUARD:
			_yield(other, rival_sprite, sprite)
			return true
		_begin_bout(animal, other, kind)
		return true
	return false


func _begin_bout(animal: Dictionary, other: Dictionary, kind: WildlifeData) -> void:
	var bout: Dictionary = {"a": animal, "b": other, "stage": Stage.CHALLENGE,
		"left": Balance.FEED_CHALLENGE_SECONDS, "intent": roll_intent(kind, _dice), "blows": 0}
	animal["bout"] = bout
	other["bout"] = bout
	var sprite: Sprite2D = animal.get("sprite", null) as Sprite2D
	if sprite != null and not kind.vocal_sfx.is_empty():
		Sfx.play_at(kind.vocal_sfx, sprite.global_position, 0.0, Wildlife.voice_pitch(kind))


## **The stand-off and the fight**, from one side's frame. The first of the two
## decides the clock and the outcome; both face, both strike on their own beat.
func _tick_bout(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, bout: Dictionary) -> bool:
	var other: Dictionary = (bout["b"] if bout["a"] == animal else bout["a"]) as Dictionary
	var rival_sprite: Sprite2D = other.get("sprite", null) as Sprite2D
	if rival_sprite == null or not is_instance_valid(rival_sprite) \
			or float(other.get("dying", 0.0)) > 0.0 or not wild.living().has(other):
		_end_bout(bout, other, "won")
		return false
	var delta: float = wild.get_process_delta_time()
	var toward: Vector2 = rival_sprite.global_position - sprite.global_position
	wild._face(animal, sprite, kind, toward, delta)
	wild._animate(animal, sprite, delta, false)
	var leads: bool = bout["a"] == animal
	if int(bout["stage"]) == Stage.CHALLENGE:
		if not leads:
			return true
		bout["left"] = float(bout["left"]) - delta
		if float(bout["left"]) > 0.0:
			return true
		var a: Dictionary = bout["a"]
		var b: Dictionary = bout["b"]
		var a_backs: bool = _dice.randf() < backoff_chance(alpha_of(a), alpha_of(b), _mood_of(a) == Mood.SHARE)
		var b_backs: bool = _dice.randf() < backoff_chance(alpha_of(b), alpha_of(a), _mood_of(b) == Mood.SHARE)
		if a_backs or b_backs:
			var loser: Dictionary = a if a_backs and (not b_backs or alpha_of(a) <= alpha_of(b)) else b
			_end_bout(bout, loser, "backed off")
			return true
		bout["stage"] = Stage.FIGHT
		return true
	# The fight: each strikes on its own beat.
	var intent: int = int(bout["intent"])
	animal["fight_left"] = float(animal.get("fight_left", 0.0)) - delta
	if float(animal["fight_left"]) <= 0.0:
		animal["fight_left"] = Balance.FEED_FIGHT_SECONDS * _dice.randf_range(0.8, 1.2)
		var scale: float = Balance.FEED_SPAR_SCALE if intent == Intent.SPAR \
			else (Balance.FEED_DEATH_SCALE if intent == Intent.DEATH else 1.0)
		wild.wound_sprite(rival_sprite, kind.damage * Balance.FEED_FIGHT_SHARE * scale + 1.0, false, "cycle")
		animal["fought"] = int(animal.get("fought", 0)) + 1
		bout["blows"] = int(bout["blows"]) + 1
		Vfx.dust(rival_sprite.global_position, Color(0.4, 0.33, 0.25), 3, 18.0)
	var my_share: float = float(animal.get("hp", 0.0)) / maxf(Wildlife.pool_of(animal), 1.0)
	match intent:
		Intent.SPAR:
			if leads and int(bout["blows"]) >= Balance.FEED_SPAR_BLOWS:
				var their_share: float = float(other.get("hp", 0.0)) / maxf(Wildlife.pool_of(other), 1.0)
				_end_bout(bout, animal if my_share < their_share else other, "sized up")
		Intent.SCARE:
			if my_share < Balance.FEED_SCARE_SHARE:
				_end_bout(bout, animal, "scared off")
		Intent.DEATH:
			if my_share < Balance.FEED_FLEE_HEALTH and _dice.randf() < Balance.FEED_FLEE_CHANCE * delta:
				_end_bout(bout, animal, "fled")
	return true


## A bout over: `loser` gives the food up and goes, the other eats on.
func _end_bout(bout: Dictionary, loser: Dictionary, how: String) -> void:
	var a: Dictionary = bout["a"]
	var b: Dictionary = bout["b"]
	a.erase("bout")
	b.erase("bout")
	var key: String = "%s:%s" % [["spar", "scare", "death"][int(bout["intent"])], how]
	bouts[key] = int(bouts.get(key, 0)) + 1
	if how == "won":
		return
	var winner: Dictionary = b if loser == a else a
	var sprite: Sprite2D = loser.get("sprite", null) as Sprite2D
	var other_sprite: Sprite2D = winner.get("sprite", null) as Sprite2D
	if sprite != null and is_instance_valid(sprite):
		_yield(loser, sprite, other_sprite)


func _yield(animal: Dictionary, sprite: Sprite2D, from: Sprite2D) -> void:
	var corpses: CorpseField = _corpses()
	if corpses != null:
		_let_go(animal, corpses)
	animal["meal"] = {}
	animal["feeding"] = false
	animal["state"] = Wildlife.State.FLEEING
	animal["goal"] = wild._bolt_target(sprite.global_position,
		from.global_position if from != null and is_instance_valid(from) else Vector2.INF)
	animal["yielded"] = int(animal.get("yielded", 0)) + 1


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
