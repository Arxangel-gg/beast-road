extends Node

## A body cannot be held still by swinging faster at it.
##
##   godot --headless --path game res://tools/stagger_check.tscn
##
## Owner, 2026-09-15: "even with enough swiftness players should not be able to
## hit/stunlock enemies from constant fast attacks ... including shield bearing
## enemies to be able to have an even higher chance of enduring/countering/
## blocking player hits and having a chance to stand their ground, or reduce
## knockback".
##
## **The hitstun was already capped and the knockback was not**, which is the
## lock that was actually being built: a 170-unit shove against a 900-unit decay
## lasts a fifth of a second, so a hero swinging faster than five times a second
## keeps a body at arm's length for ever without ever stunning it.
##
## **The bound this whole system lives under is that damage never moves**, and
## that is the first and hardest thing checked here. Everything else is spacing.
## The ways it can go wrong:
##
## - **It nerfs the player.** If a staggered body takes less *damage*, the
##   ten-act pressure curve is measuring a game that no longer exists. The same
##   blow must take the same health at every load.
## - **It never engages.** A tolerance so high that no realistic flurry reaches
##   it is a system nobody meets - the failure this project has shipped more
##   than any other. Measured against a real hero's chain timing.
## - **It never lets go.** A load that does not drain makes the first fight of a
##   wave the only one where knockback works.
## - **A permanent plant.** A shield-bearer that can re-brace the moment its
##   brace ends is immune to being moved for the rest of the fight, and the
##   refractory is the only thing standing between those two.
## - **A brace that hits back.** It must deal nothing: damage arriving out of a
##   fight the player was winning is a source `curve_report` has never modelled.
##
## **Every probe here is kept alive between blows.** The first cut did not, the
## body died three blows into a twelve-blow flurry, and the gate then measured a
## corpse's last shove and called the system broken. A probe that dies mid-
## measurement reads exactly like a feature that does not work.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_roster_is_authored()
	await _test_the_field()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[stagger] PASS - %d checks: damage never moves, a flurry stops "
			+ "shoving, the load lets go, a shield plants and deals nothing, "
			+ "and no body can plant for ever") % _checks)
	else:
		push_error("[stagger] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **Every body has a defensible footing, and only shield-bearers plant.**
func _test_the_roster_is_authored() -> void:
	var braced: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		_check(breed.stagger_tolerance >= 1.0,
			"%s endures %.1f blows, which is not a number of blows"
				% [breed.id, breed.stagger_tolerance])
		_check(breed.stagger_tolerance <= 12.0,
			"%s endures %.1f blows, which is a body nothing ever settles"
				% [breed.id, breed.stagger_tolerance])
		if breed.category == EnemyData.Category.BOSS:
			_check(is_equal_approx(breed.stagger_tolerance, 1.0),
				"%s is a boss and endures %.1f - a boss walks through a combo"
					% [breed.id, breed.stagger_tolerance])
			_check(breed.brace_chance <= 0.0,
				"%s is a boss and also braces, which is two answers to one thing"
					% breed.id)
		if breed.behaviour == EnemyData.Behaviour.ANCHOR:
			_check(breed.brace_chance > 0.0,
				("%s stands in front of things for a living and cannot plant - "
					+ "that is the owner's report exactly") % breed.id)
		if breed.brace_chance > 0.0:
			braced += 1
	_check(braced >= 8,
		("only %d bodies in the whole roster can plant, which is a feature "
			+ "nobody meets") % braced)
	# **Reachable.** If the tolerance were authored past what a real flurry
	# reaches, none of this would ever happen to anybody.
	var step: float = 0.0
	for phase: int in Balance.HERO_CHAIN_LENGTH:
		step += Balance.HERO_ATTACK_WINDUP[phase] \
			+ Balance.HERO_ATTACK_ACTIVE[phase] \
			+ Balance.HERO_ATTACK_RECOVERY[phase]
	var swings: float = Balance.STAGGER_WINDOW \
		/ maxf(step / float(Balance.HERO_CHAIN_LENGTH), 0.02)
	_check(swings > 3.0,
		("a hero lands %.1f blows inside the window at base speed, which cannot "
			+ "fill any body's footing") % swings)
	_check(Balance.STAGGER_MIN_SCALE > 0.0,
		"a body nothing can ever move again is not a body, it is a wall")
	_check(Balance.BRACE_REFRACTORY > Balance.BRACE_SECONDS,
		"a plant that can be renewed before it ends is a permanent plant")


func _test_the_field() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	_check(field != null, "there must be a field")
	if field == null:
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	field.wave_director.stop()
	var animals: Node = field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	for _settle: int in 3:
		await get_tree().process_frame

	var soft: EnemyData = _a_breed(false)
	_check(soft != null, "a plain breed is needed")
	if soft == null:
		await _leave(run)
		return

	# --- Damage never moves, at any load ------------------------------------
	var victim: Enemy = _stand(field, soft, Vector2(3000.0, 3000.0))
	var blow: float = 6.0
	var first: float = _strike(victim, blow, 0.0)
	for _hit: int in 14:
		_strike(victim, blow, 0.0)
	_check(victim.stagger_load() > 0.95,
		"a fifteen-blow flurry left the footing at %.2f, so nothing engaged"
			% victim.stagger_load())
	var last: float = _strike(victim, blow, 0.0)
	_check(is_equal_approx(first, last),
		("a fully staggered body took %.2f where a fresh one took %.2f - the "
			+ "whole bound is that damage does not move") % [last, first])
	victim.queue_free()

	# --- A flurry stops shoving ---------------------------------------------
	var rested: Enemy = _stand(field, soft, Vector2(3600.0, 3000.0))
	_strike(rested, blow, 170.0)
	var fresh_push: float = (rested.get("_knockback") as Vector2).length()
	for _hit: int in 12:
		_strike(rested, blow, 170.0)
	var tired_push: float = (rested.get("_knockback") as Vector2).length()
	_check(fresh_push > 1.0, "a fresh body must be shoved at all: %.1f" % fresh_push)
	_check(tired_push < fresh_push * 0.35,
		("the thirteenth blow in a flurry shoved %.1f against the first's %.1f "
			+ "- that is the lock the owner reported")
			% [tired_push, fresh_push])

	# --- And it lets go ------------------------------------------------------
	await _settle(Balance.STAGGER_WINDOW + 0.4)
	if is_instance_valid(rested):
		_check(rested.stagger_load() <= 0.01,
			"the footing did not recover after a whole window: %.2f"
				% rested.stagger_load())
		_strike(rested, blow, 170.0)
		var recovered: float = (rested.get("_knockback") as Vector2).length()
		_check(recovered > fresh_push * 0.9,
			("a body left alone must be shoved again: %.1f against the "
				+ "original %.1f") % [recovered, fresh_push])
		rested.queue_free()

	# --- A shield plants, deals nothing, and cannot plant for ever -----------
	var guard: EnemyData = _a_breed(true)
	_check(guard != null, "a shield-bearer is needed")
	if guard != null:
		# Its own copy, at a certainty, because a chance is a coin toss wearing a
		# gate's clothes - this project has shipped four of those.
		var sure: EnemyData = guard.duplicate(true) as EnemyData
		sure.brace_chance = 1.0
		var wall: Enemy = _stand(field, sure, Vector2(4200.0, 3000.0))
		var hero: Hero = field.hero
		var hero_hp: float = 0.0
		var hero_at: Vector2 = Vector2.ZERO
		if hero != null and hero.health != null:
			hero.global_position = wall.global_position + Vector2(-40.0, 0.0)
			hero_at = hero.global_position
			hero_hp = hero.health.current_hp
		var planted: bool = false
		for _hit: int in 12:
			_strike(wall, blow, 170.0)
			if wall.is_braced():
				planted = true
				break
		_check(planted,
			"a shield-bearer took twelve blows at a certainty and never planted")
		if planted:
			_check((wall.get("_knockback") as Vector2).length() < 0.01,
				"a planted body was still shoved: %.1f"
					% (wall.get("_knockback") as Vector2).length())
			# It refused to move. It did not refuse to bleed.
			var before: float = wall.health.current_hp
			wall.take_damage(blow, wall.global_position + Vector2(-60.0, 0.0), 170.0)
			_check(wall.health.current_hp < before,
				"a planted body must still take the blow it refused to move for")
			_check((wall.get("_knockback") as Vector2).length() < 0.01,
				"a planted body was shoved by the next blow")
			wall.health.current_hp = wall.health.max_hp
			if hero != null and hero.health != null:
				_check(hero.health.current_hp >= hero_hp - 0.01,
					("bracing cost the hero %.1f health - a brace is a refusal, "
						+ "never a counter") % (hero_hp - hero.health.current_hp))
				await _settle(0.25)
				_check(hero.global_position.distance_to(hero_at) > 1.0,
					"a brace must push whoever is standing on it back")
			# **A moment, not a state.**
			await _settle(Balance.BRACE_SECONDS + 0.15)
			_check(not wall.is_braced(), "the plant never ended")
			var again: bool = false
			for _hit: int in 12:
				_strike(wall, blow, 170.0)
				if wall.is_braced():
					again = true
					break
			_check(not again,
				("a shield-bearer planted again inside its refractory, which is "
					+ "a body that can never be moved for the rest of a fight"))
		wall.queue_free()

	await _leave(run)


## One blow, and what it took off. **The probe is refilled afterwards**, because
## a body that dies partway through a flurry stops answering and the measurement
## silently becomes a reading of a corpse.
func _strike(body: Enemy, amount: float, knockback: float) -> float:
	if not is_instance_valid(body) or body.health == null:
		return 0.0
	var before: float = body.health.current_hp
	body.take_damage(amount, body.global_position + Vector2(-60.0, 0.0), knockback)
	var taken: float = before - body.health.current_hp
	body.health.current_hp = body.health.max_hp
	return taken


func _settle(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _leave(run: Run) -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


func _a_breed(with_a_shield: bool) -> EnemyData:
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	for id: String in ids:
		var breed := ContentDB.enemies[id] as EnemyData
		if breed == null or breed.category != EnemyData.Category.BREED:
			continue
		if with_a_shield and breed.brace_chance <= 0.0:
			continue
		if not with_a_shield and (breed.brace_chance > 0.0
				or breed.knockback_resistance > 0.05):
			continue
		return breed
	return null


func _stand(field: Battlefield, breed: EnemyData, at: Vector2) -> Enemy:
	var body := (load("res://scenes/battlefield/enemy.tscn") as PackedScene) \
		.instantiate() as Enemy
	body.setup(breed, RunState.act, field, 1.0, 1.0, 1.0)
	field.add_child(body)
	body.global_position = at
	return body


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[stagger] " + why)
