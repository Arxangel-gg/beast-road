extends Node

## What a breed does that you remember it for, and the bound on all of it.
##
## Owner brief, 2026-09-15, from a forwarded design review: "give each enemy a
## recognisable threat, a readable warning, and a satisfying way to beat it. The
## strongest test is whether seeing that enemy changes the player's next
## decision." The review's four-breed prototype is what is built - an anchor, a
## pounce, a ward and a stored release - and this holds the five sentences the
## whole thing rests on.
##
## **A behaviour changes the shape of a fight and never its size.** That is the
## bound omens, Road Cards, tower paths, spirit traits, hides and every status
## in this game are held to, and it is the first thing measured here: the same
## body, the same blows, the same total damage taken, whatever it was doing.
##
## And four properties that are each a way one of these becomes unfair:
##
## - **Everything is told before it happens.** A tell, then a commitment that
##   cannot be taken back. A blow from nowhere is the thing the telegraph rule
##   refuses, and a commitment that can be cancelled has no counterplay.
## - **Every commitment has a recovery.** That window is the answer; a behaviour
##   without one is a behaviour you cannot punish.
## - **A guard turns one blow and is spent**, is bounded in how many it reaches,
##   and does not stack. Two priests must not make a wave unkillable.
## - **A shield redirects and never reduces.** The blow lands on the shield
##   instead of the body behind it, so the wave's total health is untouched.
##
## **Amended 2026-09-25 (owner): a pounce that connects is a blow.** It was
## ground crossed and nothing else, stood committed for two seconds after, and
## was sized to the breed's whole reach so it flew past a Warden standing closer
## - the owner: "the pounce itself rarely if ever does damage". It lands one blow
## at `ENEMY_POUNCE_DAMAGE_SCALE` of the swing now, may come once more, and may
## run straight into a swing. That is the one exception to the bound above, and
## `_test_a_pounce_lands_and_may_come_again` holds its edges.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260915)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		_check(false, "the harness needs a battlefield")
		_finish()
		return
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	for _frame: int in 4:
		await get_tree().process_frame

	_test_every_behaviour_is_authored_somewhere()
	_test_every_behaviour_is_told_before_it_happens()
	await _test_a_pounce_covers_ground_and_leaves_none_behind()
	await _test_a_pounce_lands_and_may_come_again()
	await _test_a_swing_is_dealt_once()
	await _test_a_guard_turns_one_blow_and_is_spent()
	await _test_a_shield_redirects_rather_than_reduces()
	await _test_a_release_gives_back_only_what_was_banked()
	_finish()


## A behaviour nothing authors is a system that does not exist, and a behaviour
## the enum has but no breed uses is the same thing one layer up.
func _test_every_behaviour_is_authored_somewhere() -> void:
	var seen: Dictionary = {}
	var authored: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or breed.behaviour == EnemyData.Behaviour.NONE:
			continue
		authored += 1
		seen[breed.behaviour] = true
		# Each of the three parts, or the shape is not there.
		_check(breed.behaviour_recovery > 0.0 or Balance.ENEMY_BEHAVIOUR_RECOVERY > 0.0,
			"%s must have a recovery: it is the opening" % breed.id)
		_check(breed.behaviour_interval > 0.0,
			"%s must wait between commitments (%0.2f)"
				% [breed.id, breed.behaviour_interval])
		_check(breed.behaviour_reach > 0.0,
			"%s must reach somewhere (%0.1f)" % [breed.id, breed.behaviour_reach])
	_check(authored >= 4, "the prototype needs several breeds (%d)" % authored)
	for kind: int in [EnemyData.Behaviour.ANCHOR, EnemyData.Behaviour.POUNCE,
			EnemyData.Behaviour.WARD, EnemyData.Behaviour.STORE]:
		_check(seen.has(kind),
			"behaviour %d is in the enum and on no breed, which is content that "
				% kind + "can never appear")


## **The tell is not the blow.** Read off the constants and the data rather than
## driven, because what is being asserted is that a warning exists at all - and
## a zero warning is a blow from nowhere however the machine runs.
func _test_every_behaviour_is_told_before_it_happens() -> void:
	_check(Balance.ENEMY_BEHAVIOUR_WARNING > 0.2,
		"the default tell must be long enough to read (%0.2f)"
			% Balance.ENEMY_BEHAVIOUR_WARNING)
	_check(Balance.ENEMY_BEHAVIOUR_RECOVERY > 0.2,
		"and the default recovery long enough to punish (%0.2f)"
			% Balance.ENEMY_BEHAVIOUR_RECOVERY)
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or breed.behaviour == EnemyData.Behaviour.NONE:
			continue
		var warning: float = breed.behaviour_warning if breed.behaviour_warning > 0.0 \
			else Balance.ENEMY_BEHAVIOUR_WARNING
		_check(warning >= 0.3,
			"%s tells for %0.2fs, which nobody can read" % [breed.id, warning])


## **A pounce crosses the ground it was authored to cross, and leaves nothing
## behind when it is over.**
##
## `_commit_behaviour` writes the leap into `_slip` - "a shove along the marked
## line, through the same slip the knockback uses" - and `_slip` is applied in
## `_advance`, which the COMMIT arm of `_tick_state` never calls. So the two
## halves worth measuring are whether the leap happens at all, and what is left
## in `_slip` afterwards: `_tick_slip` only ever clears a slip the **snow** set,
## because that is the one carrying a timer, and nothing else in the file zeroes
## it. A residue there is added to every step the body takes for the rest of its
## life, which is a body that walks sideways off the road - and "some seem to go
## off elsewhere" is the owner's report of 2026-09-22.
##
## Every breed that pounces, not one of them: eighteen do, and a guarantee is a
## property of all of them or it is not a guarantee. Hand-driven with the run
## stopped, which is `enemy_siege_trace`'s pattern, so nothing else on the field
## can move the body while it is being measured.
func _test_a_pounce_covers_ground_and_leaves_none_behind() -> void:
	const FRAME: float = 1.0 / 60.0
	var pouncers: Array[EnemyData] = []
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.behaviour == EnemyData.Behaviour.POUNCE:
			pouncers.append(breed)
	_check(not pouncers.is_empty(), "no breed pounces, so this measures nothing")
	# **The quarry has to outlive the measurement.** Eighteen breeds each get
	# twenty seconds beside the Warden and they all swing; once the hero is down,
	# `_foe_stands` refuses it, nothing targets it, and every breed after that
	# reads as one that never pounces. It is `stagger_check`'s probe dying three
	# blows into a twelve-blow flurry, one level up.
	if _field.hero != null and _field.hero.health != null:
		_field.hero.health.floor_hp = _field.hero.health.max_hp * 0.5
	for breed: EnemyData in pouncers:
		for interrupted: bool in [false, true]:
			_clear()
			await get_tree().process_frame
			var body: Enemy = await _spawn(breed.id)
			if body == null:
				continue
			_run.process_mode = Node.PROCESS_MODE_DISABLED
			# Far from the town, so nothing steals the target, and with the quarry
			# inside the leap but outside the arm - which is what `_behaviour_wants_to`
			# asks for - and inside `ENEMY_HERO_AGGRO_RANGE`, or it is not a target.
			var away := Vector2(2400.0, 0.0)
			var gap: float = clampf(breed.behaviour_reach * 0.6,
				body.attack_reach() + 30.0, Balance.ENEMY_HERO_AGGRO_RANGE - 20.0)
			body.global_position = away
			_field.hero.global_position = away + Vector2(gap, 0.0)
			var from := Vector2.ZERO
			var covered: float = -1.0
			var committed: bool = false
			var planned: float = 0.0
			for frame: int in 1200:
				var before: int = int(body.get("_state"))
				body.call("_process", FRAME)
				var now: int = int(body.get("_state"))
				if now == Enemy.State.COMMIT and not committed:
					committed = true
					from = body.global_position
					planned = float(body.get("_leap_distance"))
					continue
				if committed and interrupted and now == Enemy.State.COMMIT \
						and frame % 7 == 0:
					# Broken out of the commitment part way through, which a
					# champion falling nearby does. Nothing calls `_end_behaviour`
					# on that path.
					body.shake_morale(9.0)
				if committed and now != Enemy.State.COMMIT and before == Enemy.State.COMMIT:
					covered = from.distance_to(body.global_position)
					break
			# Ten more frames of ordinary walking, which is where a residue shows.
			var walked_from: Vector2 = body.global_position
			for _frame: int in 10:
				body.call("_process", FRAME)
			var drift: float = walked_from.distance_to(body.global_position) / (10.0 * FRAME)
			var slip: Vector2 = body.get("_slip") as Vector2
			_run.process_mode = Node.PROCESS_MODE_INHERIT

			var tag: String = "%s%s" % [breed.id, " (interrupted)" if interrupted else ""]
			_check(committed, "%s never committed to its pounce" % tag)
			if not committed:
				continue
			if not interrupted:
				# Amended 2026-09-25: a leap is sized to land in reach of where
				# the target stood at the tell, not to the breed's whole reach,
				# so what it must cross is the ground it was sized to.
				_check(planned > 0.0 and covered >= planned * 0.8,
					("%s crossed %.0f units on a pounce sized to cross %.0f. "
						+ "The leap is written into `_slip` and `_slip` is applied "
						+ "in `_advance`, which the COMMIT arm never calls")
						% [tag, covered, planned])
			_check(slip.length() <= 1.0,
				("%s left %.0f units a second of drift in `_slip` when its "
					+ "commitment ended - it walks at %.0f, so it is carried %s "
					+ "off the road for the rest of its life. Only the snow's slip "
					+ "carries a timer, so nothing ever clears this one.")
					% [tag, slip.length(), breed.move_speed,
						"sideways" if slip.length() > breed.move_speed else "wide"])
			_check(drift <= maxf(breed.move_speed, 1.0) * 1.6,
				("%s moves at %.0f units a second after its pounce against an "
					+ "authored walk of %.0f") % [tag, drift, breed.move_speed])
	_clear()
	await get_tree().process_frame


## **A pounce at a Warden standing still connects, and what follows is one of
## three things** (owner, 2026-09-25).
##
## Every breed that pounces lands its leap on a Warden who held still inside it,
## and the Warden loses health to it - counted on the hero's own `damaged`
## signal, so a ward or a deferral cannot hide it. Then, across many bodies of
## one breed: a pounce whose target moved out of the arm but not out of the leap
## is sometimes told again, and one that landed in reach is sometimes followed
## straight into a swing. "Sometimes" both ways: a chance that always or never
## fires is not the rule the owner asked for. The dice are each body's own, so
## twenty-four bodies are twenty-four different rolls.
func _test_a_pounce_lands_and_may_come_again() -> void:
	const FRAME: float = 1.0 / 60.0
	var hero: Hero = _field.hero
	if hero == null or hero.health == null:
		_check(false, "the harness needs a hero with health")
		return
	var landed_blows: Array[int] = [0]
	var counter := func(amount: float, _from: Vector2) -> void:
		if amount > 0.0:
			landed_blows[0] += 1
	hero.health.damaged.connect(counter)
	var pouncers: Array[EnemyData] = []
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.behaviour == EnemyData.Behaviour.POUNCE:
			pouncers.append(breed)
	for breed: EnemyData in pouncers:
		var body: Enemy = await _stage_a_pounce(breed.id)
		if body == null:
			continue
		hero.health.heal(hero.health.max_hp)
		hero.health.set("_invulnerable_left", 0.0)
		hero.health.set("_shield", 0.0)
		var before: int = landed_blows[0]
		var outcome: int = _drive_through_the_leap(body, FRAME, false)
		_run.process_mode = Node.PROCESS_MODE_INHERIT
		_check(outcome >= 0, "%s never committed to its pounce" % breed.id)
		_check(bool(body.get("_pounce_landed")),
			("%s pounced at a Warden standing still inside its leap and never "
				+ "connected - it flew past or stopped short") % breed.id)
		_check(landed_blows[0] > before,
			"%s's pounce connected and the Warden lost nothing" % breed.id)
	# The chain and the swing, on one breed, many bodies.
	var again: int = 0
	var swung: int = 0
	var rested: int = 0
	var first: EnemyData = pouncers[0] if not pouncers.is_empty() else null
	if first != null:
		for attempt: int in 24:
			var body: Enemy = await _stage_a_pounce(first.id)
			if body == null:
				continue
			# Half the bodies have their quarry step back out of the arm while
			# they are in the air, which is what a second pounce is for.
			var outcome: int = _drive_through_the_leap(body, FRAME, attempt % 2 == 0)
			_run.process_mode = Node.PROCESS_MODE_INHERIT
			if outcome == Enemy.State.BRACE:
				again += 1
			elif outcome == Enemy.State.WINDUP:
				swung += 1
			elif outcome == Enemy.State.RECOVER:
				rested += 1
		_check(again > 0, ("%s never pounced a second time in 24 leaps whose "
			+ "quarry stepped back inside the leap") % first.id)
		_check(swung > 0, ("%s never followed a pounce that landed in reach "
			+ "with a swing in 24 leaps") % first.id)
		_check(rested > 0, ("%s always followed up - a chance that always "
			+ "fires is not a chance") % first.id)
	hero.health.damaged.disconnect(counter)
	hero.health.heal(hero.health.max_hp)
	_clear()
	await get_tree().process_frame


## One pouncer, far from the town, its quarry inside the leap and outside the
## arm, with the run stopped so nothing else moves either of them.
func _stage_a_pounce(breed_id: String) -> Enemy:
	_clear()
	await get_tree().process_frame
	var body: Enemy = await _spawn(breed_id)
	if body == null:
		return null
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	var breed: EnemyData = body.data
	var away := Vector2(2400.0, 0.0)
	var gap: float = clampf(breed.behaviour_reach * 0.6,
		body.attack_reach() + 30.0, body.hero_aggro_range() - 20.0)
	body.global_position = away
	_field.hero.global_position = away + Vector2(gap, 0.0)
	return body


## Drives a staged pounce until its first commitment ends and says what it went
## into: BRACE (again), WINDUP (a swing), RECOVER, or -1 if it never committed.
## `step_back` moves the quarry, the moment the leap begins, to half an arm
## beyond where the leap will land: out of reach, and well inside the next leap.
func _drive_through_the_leap(body: Enemy, frame_seconds: float, step_back: bool) -> int:
	var committed: bool = false
	for frame: int in 1200:
		var before: int = int(body.get("_state"))
		body.call("_process", frame_seconds)
		var now: int = int(body.get("_state"))
		if now == Enemy.State.COMMIT and not committed:
			committed = true
			if step_back:
				var aim: Vector2 = body.get("_behaviour_aim") as Vector2
				var landing: float = float(body.get("_leap_distance"))
				_field.hero.global_position = body.global_position + aim * (landing + body.attack_reach() * 1.6)
			continue
		if committed and before == Enemy.State.COMMIT and now != Enemy.State.COMMIT:
			return now
	return -1 if not committed else int(body.get("_state"))


## **A swing is dealt once** (2026-09-25). From 2026-09-21 `Enemy._strike` read
## `if HOWLER: shoot  elif net_id: announce; return` - the ranged branch's
## `return` had moved under the new co-op one - so a ranged swing hit twice (its
## projectile, and the same blow again on the frame it was thrown), and a melee
## swing on a co-op host was announced and never dealt. `enemy_shot_check` fires
## shots through its own seam and could not see either; this drives `_strike`.
func _test_a_swing_is_dealt_once() -> void:
	var hero: Hero = _field.hero
	var melee: EnemyData = null
	var ranged: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or breed.category != EnemyData.Category.BREED:
			continue
		if breed.role == EnemyData.Role.HOWLER:
			if ranged == null:
				ranged = breed
		elif melee == null and breed.behaviour == EnemyData.Behaviour.NONE:
			melee = breed
	for pair: Array in [[melee, 4242], [ranged, 0]]:
		var breed := pair[0] as EnemyData
		if breed == null:
			_check(false, "the harness needs a plain melee and a ranged breed")
			continue
		_clear()
		await get_tree().process_frame
		var body: Enemy = await _spawn(breed.id)
		if body == null:
			continue
		_run.process_mode = Node.PROCESS_MODE_DISABLED
		body.global_position = Vector2(2400.0, 0.0)
		hero.global_position = body.global_position + Vector2(body.attack_reach() * 0.5, 0.0)
		hero.health.heal(hero.health.max_hp)
		hero.health.set("_invulnerable_left", 0.0)
		hero.health.set("_shield", 0.0)
		body.set("_target", hero)
		body.net_id = int(pair[1])
		var before: float = hero.health.current_hp
		body.call("_strike")
		var taken: float = before - hero.health.current_hp
		body.net_id = 0
		_run.process_mode = Node.PROCESS_MODE_INHERIT
		if breed.role == EnemyData.Role.HOWLER:
			_check(is_zero_approx(taken),
				("%s's swing took %.1f on the frame it was thrown, before its shot "
					+ "had flown - a ranged blow landing twice") % [breed.id, taken])
		else:
			_check(taken > 0.0,
				("%s's swing on a co-op host (net id %d) was announced and never "
					+ "dealt") % [breed.id, int(pair[1])])
	hero.health.heal(hero.health.max_hp)
	_clear()
	await get_tree().process_frame


## One blow, then gone. Driven through the real `take_damage`.
func _test_a_guard_turns_one_blow_and_is_spent() -> void:
	var body: Enemy = await _spawn("bogkin")
	if body == null:
		return
	var full: float = body.health.current_hp
	body.grant_guard(6.0)
	_check(body.guarded(), "a granted guard must stand")
	_check(not body.take_damage(40.0, body.global_position + Vector2(-50.0, 0.0), 0.0),
		"the guarded blow must be turned")
	_check(is_equal_approx(body.health.current_hp, full),
		"and take nothing: %0.1f of %0.1f" % [body.health.current_hp, full])
	_check(not body.guarded(), "and the guard must be spent")
	body.take_damage(40.0, body.global_position + Vector2(-50.0, 0.0), 0.0)
	_check(body.health.current_hp < full,
		"the next blow must land: %0.1f of %0.1f" % [body.health.current_hp, full])
	# Non-stacking: two bells over one body is still one turned blow.
	body.grant_guard(6.0)
	body.grant_guard(6.0)
	var after: float = body.health.current_hp
	body.take_damage(30.0, body.global_position + Vector2(-50.0, 0.0), 0.0)
	body.take_damage(30.0, body.global_position + Vector2(-50.0, 0.0), 0.0)
	_check(body.health.current_hp < after,
		"two bells must not turn two blows: %0.1f of %0.1f" % [body.health.current_hp, after])
	_check(Balance.ENEMY_WARD_MAX_ALLIES > 0 and Balance.ENEMY_WARD_MAX_ALLIES <= 8,
		"a bell must reach a bounded number of allies (%d)"
			% Balance.ENEMY_WARD_MAX_ALLIES)
	_clear()


## **The whole bound, driven.** The same blow against the same body, once with a
## planted shield in front of it and once without: the wave loses exactly the
## same health either way, and only *which* body lost it changes.
func _test_a_shield_redirects_rather_than_reduces() -> void:
	var shield: Enemy = await _spawn("rootshield")
	var behind: Enemy = await _spawn("bogkin")
	if shield == null or behind == null:
		return
	# The blow comes from the left; the shield stands to the left of the body.
	#
	# **Stood clear of the city, deliberately.** The field's origin is the town,
	# and a body standing on the base is put back outside it by
	# `Enemy._process` - which is correct, is the owner's own rule of
	# 2026-09-20, and is gated by `release_repair_check`. Two probes shoved off
	# it are two probes out of line, and this test is geometric: it read a
	# working shield as a broken one for exactly that reason. What it measures
	# is the redirect, never where the redirect happens, so the frame moves and
	# the invariant does not.
	var anchor: Vector2 = _field.city_bounds().end + Vector2(900.0, 900.0)
	var from: Vector2 = anchor + Vector2(-400.0, 0.0)
	behind.global_position = anchor
	shield.global_position = anchor + Vector2(-120.0, 0.0)
	shield.call("_enter", Enemy.State.COMMIT, 5.0)
	shield.data.behaviour = EnemyData.Behaviour.ANCHOR
	await get_tree().process_frame
	_check(shield.is_anchored(), "the shield must be planted for this to mean anything")
	var shield_before: float = shield.health.current_hp
	var behind_before: float = behind.health.current_hp
	var pool_before: float = shield_before + behind_before
	behind.take_damage(35.0, from, 0.0)
	var pool_after: float = shield.health.current_hp + behind.health.current_hp
	_check(absf((pool_before - pool_after) - 35.0) < 0.6,
		("the wave must lose exactly what was dealt: %0.1f taken off a pool of "
			+ "%0.1f") % [pool_before - pool_after, pool_before])
	# **Measured against what it had**, not against the breed's authored health:
	# the harness spawns at a wave's hp scale, so `data.max_hp` is a fortieth of
	# what is standing there and the first cut of this compared the two.
	_check(shield.health.current_hp < shield_before,
		"and the shield must be the one that lost it (%0.1f of %0.1f)"
			% [shield.health.current_hp, shield_before])
	_check(is_equal_approx(behind.health.current_hp, behind_before),
		"while the body behind loses nothing (%0.1f of %0.1f)"
			% [behind.health.current_hp, behind_before])
	# From the other side there is no cover, which is the flank.
	var body_before: float = behind.health.current_hp
	behind.take_damage(35.0, Vector2(400.0, 0.0), 0.0)
	_check(behind.health.current_hp < body_before,
		"a blow from the open side must reach the body behind")
	_clear()


## A release gives back a share of its own contact damage, scaled by how full
## the bank was - never a number of its own.
func _test_a_release_gives_back_only_what_was_banked() -> void:
	var warden: Enemy = await _spawn("prism_warden")
	if warden == null:
		return
	var breed: EnemyData = ContentDB.enemy("prism_warden")
	_check(breed != null and breed.behaviour == EnemyData.Behaviour.STORE,
		"the Prism Warden must be the one that stores")
	_check(Balance.ENEMY_STORE_SHARE > 0.1 and Balance.ENEMY_STORE_SHARE <= 1.0,
		("a warden must be fillable and must not open on a scratch: %0.2f of its "
			+ "own health") % Balance.ENEMY_STORE_SHARE)
	if breed != null:
		_check(breed.behaviour_power <= 3.0,
			"a release is a share of contact damage, not a number (%0.2f)"
				% breed.behaviour_power)
	# It has to actually fill from being shot, which is the whole idea.
	var before: float = float(warden.get("_behaviour_bank"))
	warden.take_damage(warden.data.max_hp * 0.3, Vector2(-300.0, 0.0), 0.0)
	_check(float(warden.get("_behaviour_bank")) > before,
		"being shot must fill the bank (%0.3f)" % float(warden.get("_behaviour_bank")))
	_check(float(warden.get("_behaviour_bank")) <= 1.0,
		"and it must never overfill (%0.3f)" % float(warden.get("_behaviour_bank")))
	_clear()


func _spawn(breed_id: String) -> Enemy:
	var breed: EnemyData = ContentDB.enemy(breed_id)
	if breed == null:
		_check(false, "the harness needs %s" % breed_id)
		return null
	# The battlefield's own door, the one the wave director uses.
	var body: Enemy = _field.spawn_enemy(breed, 0, 40.0)
	if body == null:
		_check(false, "%s must spawn" % breed_id)
		return null
	await get_tree().process_frame
	return body


func _clear() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body != null and is_instance_valid(body):
			body.queue_free()


func _finish() -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _run != null:
		_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print(("[enemy-behaviour] PASS - %d checks: every behaviour authored and "
			+ "told before it happens, a pounce that crosses its own reach and "
			+ "leaves no drift behind, a guard that turns one blow, and a shield "
			+ "that redirects rather than reduces") % _checks)
	else:
		push_error("[enemy-behaviour] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[enemy-behaviour] FAIL: %s" % why)
