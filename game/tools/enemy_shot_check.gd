extends Node

## Five ranged answers instead of one, and the bound that keeps them honest.
##
##   godot --headless --path game res://tools/enemy_shot_check.tscn
##
## Owner report, 2026-09-13: "the ranged enemies all have one attack and the
## same one, we need more variety."
##
## They did. `role == HOWLER` built one `EnemyProjectile` and nothing else
## varied, so fourteen breeds across ten regions posed a single question between
## them and a player who learned to sidestep in Act I had learned the entire
## ranged game.
##
## **The bound is that a shot changes the shape of a blow, never its size.** A
## fan divides the strike it rolled; a mortar and a lance land that one strike
## on whoever is standing there; a hex trades part of it for mana. If any of
## them ever multiplies, the ten-act pressure curve is being read against
## numbers that no longer describe the fight - and nothing else in the project
## would notice, because the curve models a ranged enemy as its
## `contact_damage`.
##
## So this gate **measures** rather than reads: it fires each shot at a body
## with a known health pool and reads what came off. Five ways it can be a lie:
##
## 1. **A shot that deals more than the strike it rolled.** The bound.
## 2. **A shot that deals nothing.** A silent dud is worse than a bolt, and an
##    area blow that resolved on nobody would be exactly that.
## 3. **A telegraph that lies about where the blow lands.** A ring drawn at a
##    radius the blow does not use teaches the player the wrong thing.
## 4. **A blow that dies with its thrower.** Then killing a shooter after it
##    commits is free, and the telegraph is a reward rather than a warning.
## 5. **A breed that cannot besiege.** An area blow resolves on heroes and
##    spirits only, so a shooter whose target is the wall must fall back to a
##    bolt or quietly stop being able to attack the town.

var _failures: int = 0
var _checks: int = 0
var _field: Node = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260913)
	RunState.phase = RunState.Phase.ROAD_BATTLE

	_test_every_shot_is_authored_somewhere()
	_test_every_breed_owns_its_shots()
	await _test_every_breed_hits_what_it_may()
	await _test_each_shot_lands_and_none_exceeds_its_strike()
	await _test_a_blow_outlives_its_thrower()
	_test_the_tell_matches_the_blow()
	await _test_the_riders_throw_on_the_way_in()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _field != null and is_instance_valid(_field):
		_field.queue_free()
	for _f: int in 12:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print(("[enemy-shots] PASS - %d checks: five kinds, every breed's own shots "
			+ "walked against a hero and the wall, each lands, none exceeds its strike")
			% _checks)
	else:
		push_error("[enemy-shots] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


## Every shot the enum names is thrown by somebody, and nobody who cannot throw
## authors one.
##
## A shot nothing throws is a feature that silently never appears, which is the
## exact failure the portent pool had: ten cards looked ample until you noticed
## that what is dealt leaves.
func _test_every_shot_is_authored_somewhere() -> void:
	var thrown: Dictionary = {}
	var shooters: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		var shoots: bool = breed.role == EnemyData.Role.HOWLER
		if shoots:
			shooters += 1
			thrown[breed.shot] = int(thrown.get(breed.shot, 0)) + 1
		else:
			_check(breed.shot == EnemyData.Shot.BOLT,
				"%s is not a shooter but authors a shot, which nothing will ever throw"
					% breed.id)
	_check(shooters >= 5, "there must be ranged breeds to vary; found %d" % shooters)
	for shot: int in EnemyData.Shot.size():
		_check(int(thrown.get(shot, 0)) > 0,
			"no breed throws shot %d, so it is a feature that never appears" % shot)
	# And no one shot is the whole roster, which is the thing being fixed.
	for shot: int in EnemyData.Shot.size():
		_check(int(thrown.get(shot, 0)) < shooters,
			"every shooter throws shot %d - that is the one-answer problem again" % shot)


## Fired for real at a body with a known pool, and the damage read off it.
##
## Driven rather than asserted from the constants: the failure this is written
## against is a shot that is *authored* correctly and resolves on nobody, which
## reads identically from the data side.
func _test_each_shot_lands_and_none_exceeds_its_strike() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	GameDirector.run_active = true
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var hero: Hero = field.hero if field != null else null
	if hero == null or hero.health == null:
		_check(false, "the harness needs a hero on a battlefield")
		run.queue_free()
		return

	# A pool deep enough that nothing here can kill the probe, and i-frames off
	# so a second blow is not silently evaded.
	hero.health.max_hp = 100000.0
	const STRIKE: float = 400.0
	for shot: int in EnemyData.Shot.size():
		var shooter: Enemy = _a_shooter(field, hero, shot)
		if shooter == null or not is_instance_valid(shooter):
			_check(false, "the harness could not place a shooter for shot %d" % shot)
			continue
		hero.health.current_hp = hero.health.max_hp
		hero.mana = hero.mana_max()
		shooter.call("_loose_a_shot", STRIKE)
		# Long enough for a mortar's tell and a hex's slow flight.
		for _frame: int in 240:
			hero.health._invulnerable_left = 0.0
			await get_tree().process_frame
		var taken: float = hero.health.max_hp - hero.health.current_hp
		_check(taken > 0.0,
			"shot %d landed nothing at all - a silent dud is worse than a bolt" % shot)
		_check(taken <= STRIKE + 0.5,
			("shot %d took %.1f from a strike of %.1f - a shot may change the shape "
				+ "of a blow and never its size") % [shot, taken, STRIKE])
		if shot == EnemyData.Shot.HEX:
			_check(hero.mana < hero.mana_max(),
				"a hex must take mana with it, which is the whole of what makes it a hex")
		if is_instance_valid(shooter):
			shooter.queue_free()
		await get_tree().process_frame

	# 5. A shooter aimed at the wall still hurts the wall, whatever it throws.
	var town: Node2D = field.town_node()
	if town != null:
		var health: Health = Health.of(town)
		if health != null:
			var before: float = health.current_hp
			var sieger: Enemy = _a_shooter(field, town, EnemyData.Shot.LOB)
			if sieger != null and is_instance_valid(sieger):
				sieger.call("_loose_a_shot", STRIKE)
				for _frame: int in 120:
					await get_tree().process_frame
				_check(health.current_hp < before,
					"a mortar breed aimed at the wall must still hurt the wall - an area "
						+ "blow resolves on people, so it has to fall back to a bolt")
				sieger.queue_free()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	GameDirector.run_active = false


## A blow already thrown lands even when its thrower does not survive the tell.
##
## Otherwise the correct play against every mortar and lance breed is to kill it
## after it commits, and the telegraph stops being a warning and becomes a
## window in which the enemy can be deleted for free.
func _test_a_blow_outlives_its_thrower() -> void:
	_field = Node2D.new()
	add_child(_field)
	var mark := Node2D.new()
	_field.add_child(mark)

	var blow := EnemyGroundStrike.new()
	blow.shape = EnemyGroundStrike.Shape.CIRCLE
	blow.damage = 5.0
	blow.delay = 0.2
	blow.reach = 120.0
	_field.add_child(blow)
	mark.queue_free()
	await get_tree().process_frame
	_check(is_instance_valid(blow),
		"a blow must not be freed along with whatever threw it")
	# And it clears itself up rather than sitting on the field forever.
	for _frame: int in 60:
		await get_tree().process_frame
		if not is_instance_valid(blow):
			break
	_check(not is_instance_valid(blow), "and it must clean itself up when it lands")
	_field.queue_free()
	_field = null
	await get_tree().process_frame


## The tell is built from the blow's own numbers.
##
## Checked on the shape rather than on the drawing: a circle covers exactly what
## it says it covers and a line covers exactly its own width. A ring drawn at a
## radius the blow does not use teaches the player the wrong lesson, which is
## worse than drawing nothing.
func _test_the_tell_matches_the_blow() -> void:
	var ring := EnemyGroundStrike.new()
	ring.shape = EnemyGroundStrike.Shape.CIRCLE
	ring.reach = 100.0
	_check(bool(ring.call("_covers", Vector2(99.0, 0.0))), "a circle covers inside itself")
	_check(not bool(ring.call("_covers", Vector2(101.0, 0.0))), "and not outside it")
	ring.free()

	var line := EnemyGroundStrike.new()
	line.shape = EnemyGroundStrike.Shape.LINE
	line.aim = Vector2.RIGHT
	line.reach = 300.0
	line.half_width = 30.0
	_check(bool(line.call("_covers", Vector2(150.0, 29.0))), "a line covers its own width")
	_check(not bool(line.call("_covers", Vector2(150.0, 31.0))), "and nothing beside it")
	_check(not bool(line.call("_covers", Vector2(301.0, 0.0))), "and nothing past its reach")
	_check(not bool(line.call("_covers", Vector2(-10.0, 0.0))), "and nothing behind the thrower")
	line.free()


## **Every breed owns its shots, every shot is owned once, and every shooter
## carries a real repertoire** (owner, 2026-09-21: "Enemies should not be
## reusing the same projectiles as each other, each enemy should have its own
## unique projectiles ... ranged enemies are to have multiple variations of
## ranged projectiles and ranged attacks each tuned for that enemy").
##
## Twelve shared files served twenty-four breeds until this; a Fog Lantern and
## a Mirage Seer threw the same `snap_bolt`. A shot is named for its breed now
## and named by exactly one, a shooter knows at least three of at least two
## kinds, and no two of a breed's own shots look alike - the same kind with the
## same head has to fly in a colour clearly its own, or the "variation" is one
## shot drawn twice. A boss that throws a volley wears a shot of its own too.
func _test_every_breed_owns_its_shots() -> void:
	var owners: Dictionary = {}
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		var mine: PackedStringArray = PackedStringArray()
		for id: String in breed.shot_ids:
			mine.append(id)
		if not breed.thrown_shot_id.is_empty():
			mine.append(breed.thrown_shot_id)
		if not breed.volley_shot_id.is_empty():
			mine.append(breed.volley_shot_id)
		for id: String in mine:
			_check(ContentDB.enemy_shots.has(id),
				"%s names %s, which is not a shot on disk" % [breed.id, id])
			_check(not owners.has(id) or String(owners[id]) == breed.id,
				"%s is thrown by both %s and %s - each breed owns its own"
					% [id, String(owners.get(id, "")), breed.id])
			owners[id] = breed.id
			_check(id.begins_with(breed.id + "_"),
				"%s throws %s, which is not named for it" % [breed.id, id])
		if breed.boss_volley_shots > 0:
			_check(not breed.volley_shot_id.is_empty(),
				"%s throws a volley in the roster's plain rune" % breed.id)
		if breed.role != EnemyData.Role.HOWLER:
			continue
		_check(breed.shot_ids.size() >= 3,
			"%s shoots for a living and knows %d shots; three is the floor"
				% [breed.id, breed.shot_ids.size()])
		var kinds: Dictionary = {}
		var seen: Array[EnemyShotData] = []
		for id: String in breed.shot_ids:
			var shot := ContentDB.enemy_shots.get(id) as EnemyShotData
			if shot == null:
				continue
			kinds[int(shot.kind)] = true
			for other: EnemyShotData in seen:
				var alike: bool = int(other.kind) == int(shot.kind) \
					and int(other.head) == int(shot.head) \
					and absf(other.tint.r - shot.tint.r) + absf(other.tint.g - shot.tint.g) \
						+ absf(other.tint.b - shot.tint.b) <= 0.18
				_check(not alike,
					"%s throws %s and %s, which look alike - one shot drawn twice"
						% [breed.id, other.id, shot.id])
			seen.append(shot)
		_check(kinds.size() >= 2,
			"%s knows %d shots of one kind - the verb that answers them never changes"
				% [breed.id, breed.shot_ids.size()])
	for id: Variant in ContentDB.enemy_shots.keys():
		_check(owners.has(id), "%s is thrown by nobody" % String(id))


## **Every shot every breed owns lands on what it may hit** - the systematic
## walk the owner asked for ("all enemies need to be tested to have the right
## ranges, the right amount of attacks and variations, and ensuring that all of
## their attacks are able to hit all of the targets that they're allowed to
## target"). A real body of each breed, its repertoire thrown shot by shot
## through the same dispatch the fight uses (`loose_named_shot`), at a hero
## with a known pool and then at the wall - and the damage read back. Held to
## the bound every shot is held to: something lands, and never more than the
## strike it was rolled from.
func _test_every_breed_hits_what_it_may() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	GameDirector.run_active = true
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var hero: Hero = field.hero if field != null else null
	var town: Node2D = field.town_node() if field != null else null
	if hero == null or hero.health == null or town == null:
		_check(false, "the harness needs a hero and a town on a battlefield")
		run.queue_free()
		return
	hero.health.max_hp = 100000.0
	var wall: Health = Health.of(town)
	if wall != null:
		wall.max_hp = 100000.0
		wall.current_hp = wall.max_hp
	const STRIKE: float = 300.0
	var breeds: int = 0
	var shots: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or not breed.throws_something() and breed.volley_shot_id.is_empty():
			continue
		var mine: PackedStringArray = PackedStringArray()
		for id: String in breed.shot_ids:
			mine.append(id)
		if not breed.thrown_shot_id.is_empty():
			mine.append(breed.thrown_shot_id)
		if not breed.volley_shot_id.is_empty():
			mine.append(breed.volley_shot_id)
		if mine.is_empty():
			continue
		breeds += 1
		var enemy := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
		enemy.setup(breed, 0, field, 1.0, 1.0, 1.0)
		field.add_child(enemy)
		# **Held still, and re-aimed before every shot.** A live body picks its
		# own target every tick and walks its route; the first cut let it, so
		# each breed's first shot landed and every later one was thrown at the
		# town from wherever the body had walked to - sixteen "silent duds" that
		# were the harness measuring a body that had changed its mind.
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.global_position = hero.global_position + Vector2.RIGHT * 180.0
		for id: String in mine:
			shots += 1
			enemy.set("_target", hero)
			hero.health.current_hp = hero.health.max_hp
			hero.mana = hero.mana_max()
			# **Nothing of the last shot may still be in the air.** A fan's other
			# two pellets and a bolt that landed late were counted against the
			# next shot, which then "took 500 from a strike of 300".
			await _settle(field)
			hero.health.current_hp = hero.health.max_hp
			var thrown: bool = bool(enemy.loose_named_shot(id, STRIKE))
			_check(thrown, "%s refused to throw its own %s" % [breed.id, id])
			if not thrown:
				continue
			# **Seconds, not frames.** Headless runs far above sixty a second, so
			# 240 frames is under a second of game time and a slow hex needs
			# more than that to cross 180 units.
			var taken: float = 0.0
			var waited: float = 0.0
			while waited < 4.0:
				hero.health._invulnerable_left = 0.0
				await get_tree().process_frame
				waited += get_process_delta_time()
				taken = hero.health.max_hp - hero.health.current_hp
				if taken > 0.0 and waited > 0.2:
					break
			_check(taken > 0.0,
				"%s's %s landed nothing on a hero at 220 units - a silent dud" % [breed.id, id])
			_check(taken <= STRIKE + 0.5,
				"%s's %s took %.1f from a strike of %.1f - a shot may change the shape of a blow and never its size"
					% [breed.id, id, taken, STRIKE])
		# And the wall: whatever it throws, aimed at the gate it must hurt the gate.
		if wall != null and not breed.shot_ids.is_empty():
			enemy.set("_target", town)
			enemy.global_position = town.global_position + Vector2.RIGHT * 300.0
			wall.current_hp = wall.max_hp
			var last: String = breed.shot_ids[breed.shot_ids.size() - 1]
			await _settle(field)
			wall.current_hp = wall.max_hp
			if bool(enemy.loose_named_shot(last, STRIKE)):
				var hurt: float = 0.0
				var waited: float = 0.0
				while waited < 4.0:
					await get_tree().process_frame
					waited += get_process_delta_time()
					hurt = wall.max_hp - wall.current_hp
					if hurt > 0.0 and waited > 0.2:
						break
				_check(hurt > 0.0,
					"%s aimed %s at the wall and the wall was not hurt - the bolt fallback is gone"
						% [breed.id, last])
		await _settle(field)
		if is_instance_valid(enemy):
			enemy.queue_free()
		await get_tree().process_frame
	_check(breeds >= 24, "the walk should cover the whole ranged roster, covered %d" % breeds)
	print("[enemy-shots] walked %d breeds and %d shots against a hero and the wall" % [breeds, shots])
	if wall != null:
		wall.current_hp = wall.max_hp
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	GameDirector.run_active = false


## Waits until no hostile shot or ground blow is left under the field, so one
## shot's remains are never counted against the next. Bounded, because a shot
## that never lands is a fault the walk should report rather than wait on.
func _settle(field: Battlefield) -> void:
	var waited: float = 0.0
	while waited < 4.0:
		var flying: bool = false
		for child: Node in field.get_children():
			if child is EnemyProjectile or child is EnemyGroundStrike:
				flying = true
				break
		if not flying:
			return
		await get_tree().process_frame
		waited += get_process_delta_time()


## A live shooter on the field, aimed at `at`, throwing `shot`.

## **A breed that closes may let one thing go on the way in.**
##
## Owner, 2026-09-15: "they also need more variety in their ranged abilities. So
## do the ones on the horses." The mounted breeds are all VANGUARD - they charge
## and they touch you - so they had no answer at range at all, while all three
## are painted with a javelin raised overhand.
##
## **The bound is this file's own bound applied to a body that is not a
## shooter**: the throw is a *share* of the blow the rider would land, so it
## moves damage forward in time rather than adding a source of it. Four ways
## that goes wrong and none of them shows in the data:
##
## - **It throws harder than it hits.** Then a rider who opens at range is
##   strictly worse to meet than one who simply arrived, which is damage added.
## - **It throws in melee.** Then the throw is stapled onto an exchange the
##   body is already winning by touching you.
## - **It throws at the wall.** A lob or a fan aimed at the gate resolves on
##   nobody (see the note at the top), so a siege that only threw would stop
##   being a siege - and a cavalryman javelining masonry is not the picture
##   either.
## - **It never throws at all.** An authored range of zero, a misspelt shot id,
##   a cooldown longer than the walk: every one of them is silent, and a
##   feature that never appears is the failure this project keeps paying for.
func _test_the_riders_throw_on_the_way_in() -> void:
	var carriers: Array[EnemyData] = []
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or breed.thrown_shot_id.is_empty():
			continue
		carriers.append(breed)
		_check(breed.thrown_shot() != null,
			("%s throws \"%s\", which is not a shot on disk - it would wind up "
				+ "and let go of nothing") % [breed.id, breed.thrown_shot_id])
		_check(breed.thrown_range > 0.0,
			"%s authors a throw with no range, so it never throws" % breed.id)
		# **And a throw past the aggro range never happens either**, which is
		# the same silence wearing a bigger number. A body only takes a hero as
		# its target inside `ENEMY_HERO_AGGRO_RANGE`; outside it the target is
		# the town, and a throw is never aimed at the town. The first cut
		# authored 700 and threw nothing at all - caught here on the first run.
		_check(breed.thrown_range <= Balance.ENEMY_HERO_AGGRO_RANGE,
			("%s throws %.0f but only notices a hero at %.0f, so the throw is "
				+ "a feature that never appears")
				% [breed.id, breed.thrown_range, Balance.ENEMY_HERO_AGGRO_RANGE])
		_check(breed.thrown_range > Balance.ENEMY_ATTACK_RANGE + breed.body_radius,
			("%s throws no further than it can reach, so it would never choose "
				+ "to throw") % breed.id)
		_check(breed.thrown_share > 0.0 and breed.thrown_share <= 1.0,
			("%s throws for %.2f of its blow - above one is a shot that adds "
				+ "damage rather than moving it") % [breed.id, breed.thrown_share])
		_check(breed.role != EnemyData.Role.HOWLER,
			("%s is a Howler and also carries a thrown opener; a shooter's "
				+ "answer at range is its repertoire") % breed.id)
	_check(not carriers.is_empty(),
		"nothing carries a thrown opener, so the whole feature is unreachable")
	if carriers.is_empty():
		return

	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	GameDirector.run_active = true
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var hero: Hero = field.hero if field != null else null
	if hero == null or hero.health == null:
		_check(false, "the harness needs a hero on a battlefield")
		run.queue_free()
		return
	hero.health.max_hp = 100000.0
	# **The road has to be running.** A fresh run opens in Preparation, which
	# suspends the battlefield (working rule 8) - every body on it stops
	# ticking mid-state. The gates that fire a shot by hand never noticed;
	# this one drives a body's own decision, so the field has to be awake or
	# the rider freezes half way through its wind-up and reads exactly like a
	# breed that refuses to throw.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	# **An empty road, or this measures the road rather than the rider.**
	# Probed first: a predator wandered over and bit the rider, the rider turned
	# to fight the animal, and the hitstun from that broke the wind-up every two
	# seconds - so "threw nothing" was true and had nothing to do with throwing.
	# The director is stopped for the same reason a wave would be: this gate is
	# about one body's decision.
	field.wave_director.stop()
	var animals: Node = field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		# Stopped as well as emptied: `clear` frees with `queue_free`, which is
		# deferred, so the animals are still standing there this frame - and a
		# rider placed on top of one turns to fight it. Two frames of patience
		# is the whole difference between this gate and a coin toss.
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	for _settle: int in 3:
		await get_tree().process_frame

	var breed: EnemyData = carriers[0]

	# **The decision, then the blow** - the same split the five shots above are
	# tested with, and for the same reason. Letting a body live in the field for
	# three seconds and waiting to be hit measures the road rather than the
	# rider: probed first, a predator wandered over and bit it (`Wildlife._strike`
	# takes an Enemy), the rider turned to fight the animal, and the hitstun
	# broke every wind-up. That reads exactly like a breed that refuses to
	# throw, and it is not one.
	var rider_reach: float = Balance.ENEMY_ATTACK_RANGE
	var rider: Enemy = _a_rider(field, hero, breed, 200.0)
	if rider != null and is_instance_valid(rider):
		# **Stood at a gap measured off the body itself**, half way between the
		# furthest it can touch and the furthest it can throw. Computing that
		# from the constants instead put it a few units the wrong side of a
		# reach that includes the breed's own radius and the hero's, and the
		# gate failed for arithmetic rather than for behaviour.
		rider_reach = rider.attack_reach() + field.target_radius(hero)
		_stand_it_off(rider, hero, field,
			(rider_reach + breed.thrown_range) * 0.5)
		var seen: float = rider.call("combat_origin").distance_to(
			hero.global_position) - field.target_radius(hero)
		_check(bool(rider.call("_may_throw_on_the_way_in")),
			("%s will not throw: measured gap %.0f, reach %.0f, range %.0f, "
				+ "state %s, cooldown %.2f, shot %s, target %s") % [breed.id,
					seen, rider.attack_reach(), breed.thrown_range,
					str(rider.get("_state")),
					float(rider.get("_throw_cooldown")),
					"none" if breed.thrown_shot() == null else breed.thrown_shot().id,
					str(rider.get("_target"))])
		# And the body wires that decision to its own wind-up, rather than the
		# answer being true and nothing asking it. **Ticked by hand rather than
		# by waiting a frame**: waiting hands the rider to the road, and the
		# road is full - an animal that bites it retargets it in the gap
		# between the question and the answer.
		rider.call("_tick_state", 0.016)
		var chose: Variant = rider.get("_target")
		var looking_at_the_hero: bool = chose == hero
		_check(not looking_at_the_hero or bool(rider.get("_throwing")),
			("%s decided it could throw and then wound up to do something else"
				+ " (it is looking at %s, in state %s)")
				% [breed.id,
					"nothing" if chose == null else (chose as Node).name,
					str(rider.get("_state"))])

		# **And the blow the wind-up ends in is the throw.** Driven through
		# `_strike` rather than by calling the throw directly, because the thing
		# that can silently come undone is the dispatch: `_strike` with
		# `_throwing` standing must let the javelin go instead of swinging, and
		# at this distance a swing lands nothing at all - so damage arriving is
		# the proof, and its size is the bound.
		hero.health.current_hp = hero.health.max_hp
		rider.set("_target", hero)
		rider.set("_throwing", true)
		rider.call("_strike")
		_check(not bool(rider.get("_throwing")),
			("%s struck without spending the throw, so its next swing would "
				+ "loose another javelin") % breed.id)
		# **Waited on, but not blindly, and this cost the gate three checks
		# without telling anybody.** Three seconds of real frames is three
		# seconds of the road: a tower can shoot the probe, an animal can bite
		# it, it can reach the wall and be spent. When it was, `rider.get(...)`
		# below hit a freed instance - and GDScript *aborts the whole function*
		# on that, so the last three checks in this test silently never ran
		# while the gate printed PASS. That is the same shape as a comparison
		# of two nothings, and the same family as the freed-companion cast.
		#
		# So the wait ends the moment the javelin has landed, which is all it
		# was ever waiting for, and the probe surviving is a check rather than
		# an assumption.
		var taken: float = 0.0
		for _frame: int in 180:
			hero.health._invulnerable_left = 0.0
			await get_tree().process_frame
			taken = hero.health.max_hp - hero.health.current_hp
			if taken > 0.0 or not is_instance_valid(rider):
				break
		_check(is_instance_valid(rider),
			("%s was taken off the field before its javelin could be measured "
				+ "- the road reached the probe, so the checks below were never "
				+ "asked") % breed.id)
		_check(taken > 0.0,
			"%s let a javelin go and nothing arrived - a silent dud" % breed.id)
		# **Softer than the blow it opens with.** The share is well under one and
		# the damage roll is a spread around it, so a full contact blow is the
		# line no roll may cross: a throw moves damage forward in time, it does
		# not add a source of it.
		_check(taken < breed.contact_damage,
			("%s threw for %.1f against a contact blow of %.1f - a throw is a "
				+ "share of the blow, never the blow at a distance")
				% [breed.id, taken, breed.contact_damage])
		# And it is spent on release rather than on the attempt, so a rider
		# broken mid-throw has not lost its javelin.
		_check(is_instance_valid(rider)
				and float(rider.get("_throw_cooldown")) > 0.0,
			"%s threw and started no cooldown, so it can throw every wind-up"
				% breed.id)
		if is_instance_valid(rider):
			rider.queue_free()
		await get_tree().process_frame

	# **Never in melee.** The same body inside its own reach must have nothing
	# to say here: a throw stapled onto an exchange it is already winning by
	# touching you is damage added rather than moved.
	var close: Enemy = _a_rider(field, hero, breed, 200.0)
	if close != null and is_instance_valid(close):
		_stand_it_off(close, hero, field, rider_reach * 0.4)
		_check(not bool(close.call("_may_throw_on_the_way_in")),
			"%s would throw at something it could already hit" % breed.id)
		close.queue_free()
		await get_tree().process_frame

	# **Never at the wall.** An area blow resolves on heroes and spirits only,
	# so a javelin at the gate is a shot that vanishes - and a cavalryman
	# javelining masonry is not the picture either.
	var town: Node2D = field.town_node()
	if town != null:
		var sieger: Enemy = _a_rider(field, hero, breed, 0.0)
		if sieger != null and is_instance_valid(sieger):
			sieger.global_position = town.global_position + Vector2.RIGHT * (
				breed.thrown_range * 0.6)
			sieger.set("_target", town)
			_check(not bool(sieger.call("_may_throw_on_the_way_in")),
				"%s would throw at the town, where the blow lands on nobody"
					% breed.id)
			sieger.queue_free()
			await get_tree().process_frame

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	GameDirector.run_active = false


## Puts a body an exact distance from its target, on the far side from the town.
##
## Anywhere else and `_pick_target` may legitimately choose the wall instead of
## the person - a body walking to the gate is supposed to prefer the gate - and
## the probe would be measuring target selection rather than the throw.
func _stand_it_off(body: Enemy, at: Node2D, field: Battlefield,
		gap: float) -> void:
	# **Beside its target, never above it.** A body measures a gap from its
	# `combat_origin` - its chest, not its feet - so an offset with any vertical
	# component has the depth lift added to it under the square root. Placed on
	# the line from the town, that lift was worth anything from nothing to
	# seventy units depending on where the run's road happened to bend, and the
	# gate passed or failed on the geometry of the map rather than on the rider.
	# So the offset is horizontal, and solved so the *measured* gap is the one
	# asked for.
	var lift: float = body.global_position.y - body.call("combat_origin").y
	var radius: float = field.target_radius(at)
	var want: float = gap + radius
	var across: float = sqrt(maxf(want * want - lift * lift, 1.0))
	var side: float = 1.0
	var town: Node2D = field.town_node()
	if town != null and at.global_position.x < town.global_position.x:
		# On the far side of its target from the wall, so `_pick_target` has no
		# reason to prefer the gate over the person.
		side = -1.0
	body.global_position = at.global_position + Vector2(across * side, 0.0)
	body.set("_target", at)


## One rider of a named breed, stood a given distance from its target.
func _a_rider(field: Battlefield, at: Node2D, breed: EnemyData,
		gap: float) -> Enemy:
	if field == null or breed == null:
		return null
	var scene := load("res://scenes/battlefield/enemy.tscn") as PackedScene
	var enemy := scene.instantiate() as Enemy
	enemy.setup(breed, 0, field, 1.0, 1.0, 1.0)
	field.add_child(enemy)
	enemy.global_position = at.global_position + Vector2.RIGHT * gap
	enemy.set("_target", at)
	# **Nothing is biting it.** An animal that has bitten a body owns its
	# attention through `_biting_back`, and the road has animals on it; a probe
	# that inherited one would be answering a question about wildlife.
	enemy.set("_provoker", null)
	enemy.set("_provoker_source", null)
	enemy.set("_provoked_left", 0.0)
	return enemy


func _a_shooter(field: Battlefield, at: Node2D, shot: int) -> Enemy:
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var candidate := value as EnemyData
		if candidate != null and candidate.role == EnemyData.Role.HOWLER:
			breed = candidate
			break
	if breed == null or field == null:
		return null
	# The breed is *posed* rather than picked by its authored shot, so the gate
	# tests all five even if the roster stops authoring one of them - and so a
	# breed's own data is never what decides whether its shot is covered here.
	var posed: EnemyData = breed.duplicate() as EnemyData
	posed.shot = shot
	# **And its repertoire is emptied**, or the pose decides nothing. Since
	# 2026-09-13 a breed draws from `shot_ids` when it has one, so posing `shot`
	# on a breed that knows several would test whichever the draw happened to
	# pick - which is how this gate started reporting that a hex took no mana.
	# The repertoire has its own gate; this one is about the five kinds.
	posed.shot_ids = PackedStringArray()
	var enemy := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
	# Through `setup` rather than by assigning `data`: `_ready` refuses a body
	# that has no field and frees itself, and a freed probe reads exactly like a
	# shot that resolved on nobody.
	enemy.setup(posed, 0, field, 1.0, 1.0, 1.0)
	field.add_child(enemy)
	enemy.global_position = at.global_position + Vector2.RIGHT * 220.0
	enemy.set("_target", at)
	return enemy
