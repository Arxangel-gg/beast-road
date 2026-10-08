class_name MercenaryInput
extends RemoteHeroInput

## **A mercenary's hands** (owner, 2026-10-07: mercenaries *"will fight and
## place their own towers and traps and play as players would with their own
## smart AI"*). A partner's body already takes its hands from a snapshot
## (`RemoteHeroInput`); this one writes its own snapshot every physics frame
## from what it sees, so everything it does is a press a player could make -
## a walk, an aim, a swing, a dash, a sprint - and nothing about the fight
## learns that mercenaries exist.
##
## **Its order**, one of four, shared later with the spirit at the Warden's
## shoulder: follow the Warden, guard a point, hunt the road, or hold the wall.
## Every order gives way to staying alive.

enum Order { FOLLOW, GUARD, HUNT, WALL }

## What it was told to do.
var order: int = Order.FOLLOW
## Where it was told to stand, for GUARD.
var post: Vector2 = Vector2.ZERO
## The Warden it follows.
var master: Hero = null
## The field it fights on.
var field: Battlefield = null

var _target: Enemy = null
var _think_left: float = 0.0
var _swing_left: float = 0.0
var _dash_left: float = 0.0
var _wander: Vector2 = Vector2.ZERO
var _wander_left: float = 0.0
var _retreating: bool = false
## **A ping being heeded** (2026-10-07): where to be, the body to fight, and for
## how long before the order it was given takes back over.
var _heed_at: Vector2 = Vector2.ZERO
var _heed_left: float = 0.0
var _heed_target: Enemy = null
## Its own dice: a decision never draws on a stream the road rolls.
var _dice := RandomNumberGenerator.new()
## **An animal on it** (owner, 2026-10-08): the animal being answered, its pool
## when the answer began, how long it has been run from, and the animals already
## driven off once, by their sprite - one that comes back is put down.
enum WildAnswer { KILL, SCARE, FLEE }
var _wild: Dictionary = {}
var _wild_start: float = 0.0
var _wild_fled: float = 0.0
var _wild_spared: Dictionary = {}


func _init(for_hero: Node2D = null, seed_name: String = "") -> void:
	super(for_hero)
	_dice.seed = absi(hash("mercenary-mind:" + seed_name))


## Told an order. GUARD stands where the mercenary is told it.
func command(new_order: int) -> void:
	order = clampi(new_order, 0, Order.size() - 1)
	var body := hero as Hero
	if body != null:
		post = body.global_position
	_target = null
	_think_left = 0.0


## **Heeds a ping its master made** (2026-10-07), through what the mind can
## already do: go somewhere, fight something, come back. Nothing it does here is
## a new verb - a GO is a post for a while, an ATTACK is a target for a while,
## and a COME is the pinging Warden's side. A ping further than
## `PING_HEED_REACH` away is a walk, not an answer, and is let go. Returns
## whether it was heeded.
func heed(ping: PingData, at: Vector2, pinger: Node2D) -> bool:
	var body := hero as Hero
	if ping == null or body == null or not body.is_alive():
		return false
	var point: Vector2 = at
	if ping.heed == PingData.Heed.COME:
		if pinger == null or not is_instance_valid(pinger):
			return false
		point = pinger.global_position
	elif ping.heed == PingData.Heed.NONE:
		return false
	if body.global_position.distance_to(point) > Balance.PING_HEED_REACH:
		return false
	_heed_at = point
	_heed_left = Balance.PING_HEED_SECONDS
	_heed_target = null
	if ping.heed == PingData.Heed.ATTACK:
		_heed_target = _nearest(at, Balance.PING_PICK_RADIUS)
		_target = _heed_target
	elif ping.heed == PingData.Heed.COME:
		# Coming back is coming back: whatever it was fighting can wait.
		_target = null
	_think_left = 0.0
	return true


## Whether a ping is still being heeded.
func heeding() -> bool:
	return _heed_left > 0.0


## The one thing the AI is fighting, or null.
func target() -> Enemy:
	return _target if is_instance_valid(_target) and not _target.is_dying() else null


## Whether it is falling back to recover.
func is_retreating() -> bool:
	return _retreating


## Where the current order says it should be.
func anchor() -> Vector2:
	var body := hero as Hero
	if _heed_left > 0.0:
		return _heed_at
	match order:
		Order.FOLLOW:
			if master != null and is_instance_valid(master):
				return master.global_position
		Order.GUARD:
			return post
		Order.WALL:
			if field != null:
				return field.town_position()
		Order.HUNT:
			var prey: Enemy = _nearest_on_the_road()
			if prey != null:
				return prey.global_position
	return body.global_position if body != null else Vector2.ZERO


## One physics frame of thought, written as a snapshot the hero reads.
func think(delta: float) -> void:
	var body := hero as Hero
	if body == null or not is_instance_valid(body) or not body.is_alive():
		apply([Vector2.ZERO, Vector2.ZERO, 0, 0])
		return
	_swing_left = maxf(0.0, _swing_left - delta)
	_dash_left = maxf(0.0, _dash_left - delta)
	_think_left -= delta
	if _heed_left > 0.0:
		_heed_left = maxf(0.0, _heed_left - delta)
		if _heed_left <= 0.0:
			_heed_target = null
	if _think_left <= 0.0:
		_think_left = Balance.MERC_THINK_SECONDS
		_choose(body)
	var move := Vector2.ZERO
	var aim := Vector2.ZERO
	var presses: int = 0
	var holds: int = 0
	var me: Vector2 = body.global_position
	var share: float = body.health.current_hp / maxf(body.health.max_hp, 1.0) if body.health != null else 1.0
	if _retreating:
		if share >= Balance.MERC_RECOVER_SHARE:
			_retreating = false
	elif share <= Balance.MERC_RETREAT_SHARE:
		_retreating = true
		_target = null
	var home: Vector2 = anchor()
	var wild: Dictionary = _wild_frame(body, share, delta)
	if not wild.is_empty():
		move = wild["move"] as Vector2
		aim = wild["aim"] as Vector2
		presses = int(wild["presses"])
		holds = int(wild["holds"])
	elif _retreating and field != null:
		var town: Vector2 = field.town_position()
		move = town - me
		if move.length() < Balance.MERC_LEASH * 0.5:
			move = Vector2.ZERO
		holds |= HeroInput.HOLD_SPRINT
		var near: Enemy = _nearest(me, Balance.MERC_ENGAGE_RADIUS * 0.5)
		if near != null and _dash_left <= 0.0:
			# Away from what is on it.
			aim = (me - near.global_position).normalized()
			presses |= HeroInput.BUTTON_DASH
			_dash_left = Balance.MERC_DASH_GAP
	elif target() != null:
		var at: Vector2 = _target.global_position
		# From the body's own edge to the point it swings at, as the Warden's
		# swing measures it.
		var gap: float = Hitbox.reach_gap(_target, me)
		aim = (at - me).normalized()
		var reach: float = Balance.HERO_ATTACK_RANGE[0] * (body.attack.reach_scale() if body.attack != null else 1.0)
		if gap > reach * Balance.MERC_CLOSE_SHARE:
			move = at - me
			if gap > reach * 3.0 and _dash_left <= 0.0:
				presses |= HeroInput.BUTTON_DASH
				_dash_left = Balance.MERC_DASH_GAP
		elif _swing_left <= 0.0:
			presses |= HeroInput.BUTTON_ATTACK
			_swing_left = Balance.MERC_SWING_GAP
	else:
		var away: float = me.distance_to(home)
		if away > Balance.MERC_LEASH:
			move = home - me
			if away > Balance.MERC_LEASH * 3.0:
				holds |= HeroInput.HOLD_SPRINT
		else:
			_wander_left -= delta
			if _wander_left <= 0.0:
				_wander_left = _dice.randf_range(1.5, 3.5)
				_wander = Vector2.ZERO if _dice.randf() < 0.5 \
					else Vector2.from_angle(_dice.randf() * TAU) * 0.4
			move = _wander
	if move.length() > 1.0:
		move = move.normalized()
	apply([move, aim, presses, holds])


## **What a hired Warden does about an animal on it**, as a rule a gate reads
## (owner, 2026-10-08: "decide if they want to try to kill a wildlife if it
## becomes necessary to, if not to attack it to scare it away without intending
## to kill them if possible, but killing ones that must be put down as a means
## of self defense if it's not possible to run away"). A blighted animal or one
## sent after the party is put down, and so is one driven off once that came
## back, or one run from for `MERC_WILD_CORNERED` that could not be shaken.
## Hurt, it runs; otherwise it fights to drive the animal off.
static func wild_answer(own_share: float, must_die: bool, came_back: bool, fled_for: float) -> int:
	if must_die or came_back or fled_for >= Balance.MERC_WILD_CORNERED:
		return WildAnswer.KILL
	if own_share <= Balance.MERC_WILD_FLEE_SHARE:
		return WildAnswer.FLEE
	return WildAnswer.SCARE


## One frame of answering an animal hunting this body, or empty when none is.
func _wild_frame(body: Hero, share: float, delta: float) -> Dictionary:
	var animals: Wildlife = field.wildlife() if field != null else null
	var animal: Dictionary = animals.hunter_of(body, Balance.MERC_WILD_NOTICE) if animals != null else {}
	if animal.is_empty():
		_wild = {}
		_wild_fled = 0.0
		return {}
	var sprite := animal.get("sprite", null) as Node2D
	if sprite == null or not is_instance_valid(sprite):
		return {}
	var key: int = sprite.get_instance_id()
	if not is_same(animal, _wild):
		_wild = animal
		_wild_start = float(animal.get("hp", 0.0))
		_wild_fled = 0.0
	var me: Vector2 = body.global_position
	var at: Vector2 = sprite.global_position
	var must_die: bool = bool(animal.get("rabid", false)) or animals.hunts_the_players(animal)
	var answer: int = wild_answer(share, must_die, _wild_spared.has(key), _wild_fled)
	var out: Dictionary = {"move": Vector2.ZERO, "aim": (at - me).normalized(), "presses": 0, "holds": 0}
	if answer == WildAnswer.FLEE:
		_wild_fled += delta
		var away: Vector2 = (me - at).normalized()
		out["move"] = away
		out["holds"] = HeroInput.HOLD_SPRINT
		if _dash_left <= 0.0 and me.distance_to(at) < Balance.MERC_WILD_NOTICE * 0.4:
			out["aim"] = away
			out["presses"] = HeroInput.BUTTON_DASH
			_dash_left = Balance.MERC_DASH_GAP
		return out
	if answer == WildAnswer.SCARE \
			and _wild_start - float(animal.get("hp", 0.0)) >= Wildlife.pool_of(animal) * Balance.MERC_WILD_SCARE_SHARE:
		animals.scare_off(animal, me)
		if _wild_spared.size() >= 16:
			_wild_spared.clear()
		_wild_spared[key] = true
		_wild = {}
		return {}
	var reach: float = Balance.HERO_ATTACK_RANGE[0] * (body.attack.reach_scale() if body.attack != null else 1.0)
	if me.distance_to(at) > reach * Balance.MERC_CLOSE_SHARE:
		out["move"] = at - me
	elif _swing_left <= 0.0:
		out["presses"] = HeroInput.BUTTON_ATTACK
		_swing_left = Balance.MERC_SWING_GAP
	return out


## Picks what to fight: the nearest body inside its engage radius of where its
## order puts it, or for HUNT anything on the road.
func _choose(body: Hero) -> void:
	if _retreating:
		return
	# A body a ping named is the body, for as long as the ping is heeded.
	if _heed_left > 0.0 and _heed_target != null and is_instance_valid(_heed_target) \
			and not _heed_target.is_dying():
		_target = _heed_target
		return
	var home: Vector2 = anchor()
	var reach: float = Balance.MERC_ENGAGE_RADIUS
	if order == Order.HUNT:
		reach = Balance.MERC_HUNT_RADIUS
	var best: Enemy = null
	var best_d: float = INF
	var me: Vector2 = body.global_position
	if field == null:
		_target = null
		return
	for enemy: Enemy in field.enemies_near(home, reach):
		if enemy == null or enemy.is_dying() or enemy.hidden_from_the_board():
			continue
		var d: float = me.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	_target = best


func _nearest(point: Vector2, radius: float) -> Enemy:
	if field == null:
		return null
	var best: Enemy = null
	var best_d: float = INF
	for enemy: Enemy in field.enemies_near(point, radius):
		if enemy == null or enemy.is_dying():
			continue
		var d: float = point.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _nearest_on_the_road() -> Enemy:
	var body := hero as Hero
	if body == null or field == null:
		return null
	return _nearest(body.global_position, Balance.MERC_HUNT_RADIUS)
