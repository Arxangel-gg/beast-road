extends Node

## What a boss may do to a hero who is not standing next to it.
##
##   godot --headless --path game res://tools/boss_reach_check.tscn
##
## **Bosses gained a slam and a volley on 2026-09-13 and nothing measured them.**
## Both are scaled from `contact_damage` so that nothing downstream has to learn
## bosses have abilities - the right bound for the mechanism, and no bound at all
## on the magnitude, because the two things it ties together do not grow
## together:
##
##   `BOSS_ACT_SCALE` runs 1.25 to 12.30. A hero's health runs 103 to 131, since
##   nothing in this game grants health per level - only Vigour, the Sanctum and
##   ascension.
##
## Measured before it was fixed: a volley shot was 41% of the hero's health in
## Act I, 112% by Act IV and 289% by Act X. **Every boss from about Act IV
## one-shot the player from eight hundred units away**, and the Act I boss threw
## five such shots every 3.8 seconds at the longest range in the roster - the
## first boss anybody meets. The owner reported it as four towers not being
## enough for the Act I boss. It was not the towers.
##
## `curve_report` cannot catch this and says so itself: a boss fight is not wave
## pressure, and the report measures waves. So this gate exists to measure the
## one encounter the curve deliberately does not.

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_no_boss_ends_a_fight_from_off_screen()
	_test_the_ladder_ramps()
	_test_the_ceiling_actually_binds()
	_test_every_slam_is_authored_inside_the_shove_bound()
	_test_the_road_reaches_the_boss()
	await _test_a_slam_actually_throws_the_player()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[boss-reach] PASS - %d checks: every boss's reach is survivable and ramps"
			% _checks)
	else:
		for failure: String in _failures:
			push_error("[boss-reach] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## **A boss stands on its road's own difficulty** (2026-10-01). The tier's
## health and damage reach the giant as they reach every body before it, and
## its ceilings rise with the tier's damage, which is how much tougher the
## Warden that road expects is. Both spawns - the act's boss and the Gatekeeper
## owed at the summit - go through the same two scales, and the two ceilings in
## the fight are scaled by the same toughness; read off the source, because a
## spawn that forgot is a boss that walked back onto the Long Road.
func _test_the_road_reaches_the_boss() -> void:
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		for act: int in [1, 5, 10]:
			var base: float = Balance.BOSS_ACT_SCALE[act - 1]
			var pool: float = base * Balance.BOSS_HEALTH_DEPTH[act - 1] * tier.hp_scale
			_check(is_equal_approx(BossDirector.boss_health_scale(act, tier), pool),
				"%s act %d's boss is not given the road's own health (%.2f against %.2f)"
					% [tier.id, act, BossDirector.boss_health_scale(act, tier), pool])
			# A party's giant is deeper and no harder: the pool grows by the
			# Wardens present, the blows do not.
			var party: float = pool * (1.0 + 3.0 * Balance.COOP_BOSS_HEALTH_PER_PLAYER)
			_check(is_equal_approx(BossDirector.boss_health_scale(act, tier, 4), party),
				"%s act %d's boss is not deepened for four Wardens (%.2f against %.2f)"
					% [tier.id, act, BossDirector.boss_health_scale(act, tier, 4), party])
			_check(is_equal_approx(BossDirector.boss_damage_scale(act, tier), base * tier.damage_scale),
				"%s act %d's boss is not given the road's own damage" % [tier.id, act])
	var director: String = FileAccess.get_file_as_string("res://scripts/systems/boss_director.gd")
	_check(director.count("boss_health_scale(") >= 3 and director.count("boss_damage_scale(") >= 3,
		"a boss is spawned somewhere without the road's own scales")
	# Amended 2026-10-07: the party a boss faces is `RunState.party_size`, which
	# counts a hired mercenary as a seat as well as a player - the invariant,
	# that every spawn reads the party, is unchanged.
	_check(director.count("RunState.party_size())") >= 2,
		"a boss is spawned somewhere without the party it faces")
	# And the road says what it expects before it is walked: the gear its own
	# bosses are measured against is in the picker's tooltip, by rarity name.
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		var said: String = MainMenu.gear_expectation(tier)
		_check(said.contains(Stash.RARITY_NAMES[tier.expected_gear_rarity.y]),
			"%s's picker does not say the gear it expects: \"%s\"" % [tier.id, said])
	_check(Balance.BOSS_HEALTH_DEPTH.size() == Balance.ACT_COUNT,
		"BOSS_HEALTH_DEPTH has %d entries for %d acts" % [Balance.BOSS_HEALTH_DEPTH.size(), Balance.ACT_COUNT])
	var enemy: String = FileAccess.get_file_as_string("res://scenes/battlefield/enemy.gd")
	_check(enemy.contains("boss_slam_ceiling(RunState.act) * _tier_toughness()")
		and enemy.contains("boss_volley_shot_ceiling(RunState.act, shots) * _tier_toughness()"),
		"a boss's ceilings are held to a Long Road Warden on every road")


## Every act's boss, in act order, or an empty array if a region names none.
func _bosses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var terrain: TerrainData = ContentDB.terrain_for_act(act)
		if terrain == null or terrain.boss_id.is_empty():
			continue
		var boss: EnemyData = ContentDB.enemy(terrain.boss_id)
		if boss == null:
			continue
		out.append({"act": act, "boss": boss})
	return out


## The contact damage a boss actually swings with at its own act.
func _contact(boss: EnemyData, act: int) -> float:
	var at: int = clampi(act - 1, 0, Balance.BOSS_ACT_SCALE.size() - 1)
	return boss.contact_damage * Balance.BOSS_ACT_SCALE[at]


## Nothing a boss throws may take the whole hero with it.
##
## The hard line, separate from the tuned shares below: a telegraph the player
## cannot afford to misread once is not a telegraph, it is a coin toss.
func _test_no_boss_ends_a_fight_from_off_screen() -> void:
	var listed: Array[Dictionary] = _bosses()
	_check(listed.size() >= 1, "no act names a boss at all")
	for entry: Dictionary in listed:
		var act: int = int(entry["act"])
		var boss: EnemyData = entry["boss"]
		var health: float = Balance.boss_hero_health(act)
		var contact: float = _contact(boss, act)
		var shots: int = maxi(boss.boss_volley_shots, 1)
		if boss.boss_volley_damage > 0.0 and boss.boss_volley_shots > 0:
			var shot: float = minf(contact * boss.boss_volley_damage,
				Balance.boss_volley_shot_ceiling(act, shots))
			_check(shot < health,
				("Act %d's %s takes %.0f of %.0f health with one volley shot - "
					+ "a shot that kills outright is not a telegraph")
					% [act, boss.id, shot, health])
			_check(shot * float(shots) <= health * Balance.BOSS_VOLLEY_BURST_SHARE + 0.5,
				("Act %d's %s throws %d shots worth %.0f of %.0f health together, "
					+ "over the %.0f%% a whole volley may take")
					% [act, boss.id, shots, shot * float(shots), health,
						Balance.BOSS_VOLLEY_BURST_SHARE * 100.0])
		if boss.boss_slam_damage > 0.0:
			var slam: float = minf(contact * boss.boss_slam_damage,
				Balance.boss_slam_ceiling(act))
			_check(slam < health,
				("Act %d's %s slams for %.0f of %.0f health - one blow, and the "
					+ "fight is over") % [act, boss.id, slam, health])


## And the danger has to grow with the road.
##
## The first cut of these abilities was authored boss by boss for character and
## never read as a ladder, so the Act I boss had the shortest volley interval
## and longest range in the game, Acts V and VIII were cliffs at three and seven
## times their neighbours, and the Gatekeeper at the summit threw the weakest
## volley of the late game.
func _test_the_ladder_ramps() -> void:
	var shares: Array[float] = []
	var listed: Array[Dictionary] = _bosses()
	for entry: Dictionary in listed:
		var act: int = int(entry["act"])
		var boss: EnemyData = entry["boss"]
		if boss.boss_volley_damage <= 0.0 or boss.boss_volley_shots <= 0:
			shares.append(-1.0)
			continue
		var shots: int = maxi(boss.boss_volley_shots, 1)
		var shot: float = minf(_contact(boss, act) * boss.boss_volley_damage,
			Balance.boss_volley_shot_ceiling(act, shots))
		shares.append(shot * float(shots) / Balance.boss_hero_health(act))
	var previous: float = -1.0
	var previous_act: int = 0
	for index: int in shares.size():
		if shares[index] < 0.0:
			continue
		var act: int = int(listed[index]["act"])
		if previous >= 0.0:
			_check(shares[index] >= previous - 0.02,
				("Act %d's boss throws a lighter volley than Act %d's (%.0f%% "
					+ "against %.0f%%) - the road must not get safer")
					% [act, previous_act, shares[index] * 100.0, previous * 100.0])
			_check(shares[index] <= previous * 1.6 + 0.05,
				("Act %d's boss jumps from %.0f%% to %.0f%% of the hero - that is "
					+ "a cliff, not a ramp")
					% [act, previous * 100.0, shares[index] * 100.0])
		previous = shares[index]
		previous_act = act


## And the ceiling has to be a real one.
##
## A ceiling above everything it bounds is decoration. This drives the helper
## with an absurd authored multiplier and checks that it is cut down.
func _test_the_ceiling_actually_binds() -> void:
	for act: int in [1, 5, 10]:
		var health: float = Balance.boss_hero_health(act)
		_check(health > 0.0, "act %d has no baseline hero health" % act)
		var one: float = Balance.boss_volley_shot_ceiling(act, 1)
		var many: float = Balance.boss_volley_shot_ceiling(act, 6)
		_check(one <= health * Balance.BOSS_VOLLEY_SHOT_SHARE + 0.001,
			"act %d lets a single shot past its share" % act)
		_check(many < one,
			("act %d does not share a burst out between its shots, so throwing "
				+ "more shots would simply multiply it") % act)
		_check(many * 6.0 <= health * Balance.BOSS_VOLLEY_BURST_SHARE + 0.001,
			"act %d lets six shots past the burst share" % act)
		_check(Balance.boss_slam_ceiling(act) < health,
			"act %d lets a slam kill outright" % act)


## No boss may author a shove the hero would have to be carried through.
##
## `shove_ceiling` is derived from `HERO_SHOVE_MAX_TRAVEL`, and the hero clamps
## to it - so authoring past it is not dangerous, it is *silent*: two bosses
## typed at 600 and 900 would throw exactly the same distance and the field
## would have stopped meaning anything. Caught here instead.
func _test_every_slam_is_authored_inside_the_shove_bound() -> void:
	var ceiling: float = Balance.shove_ceiling()
	var seen: Array[float] = []
	for row: Dictionary in _bosses():
		var boss: EnemyData = row["boss"]
		if boss.boss_slam_damage <= 0.0:
			continue
		_check(boss.boss_slam_knockback > 0.0,
			"%s slams and throws nobody, so the blow is a number rather than an event"
				% boss.id)
		_check(boss.boss_slam_knockback <= ceiling,
			"%s throws at %.0f px/s, past the %.0f the hero clamps to - so it is"
				% [boss.id, boss.boss_slam_knockback, ceiling]
				+ " indistinguishable from any other over-large number")
		_check(Balance.shove_travel(boss.boss_slam_knockback)
				<= Balance.HERO_SHOVE_MAX_TRAVEL + 0.5,
			"%s throws the player %.0f units, past the %.0f bound"
				% [boss.id, Balance.shove_travel(boss.boss_slam_knockback),
					Balance.HERO_SHOVE_MAX_TRAVEL])
		if not seen.has(boss.boss_slam_knockback):
			seen.append(boss.boss_slam_knockback)
	# And they are not all the same number wearing eleven names. The field
	# exists so a Gatekeeper lands differently from a Mirrorfang; authored
	# identically it may as well be a constant.
	_check(seen.size() >= 5,
		"only %d distinct slam shoves across the roster - the field is a constant"
			% seen.size())


## The slam is landed for real and the hero's displacement is measured.
##
## **`boss_slam_knockback` was authored on 2026-09-13 and read by nothing**, so
## every boss landed a telegraphed blow that moved the player not at all. That
## fault is invisible from the data - the number is right there in the file -
## and invisible from the damage, which was always correct. Only distance shows
## it, so distance is what this measures.
##
## Two bosses, the heaviest and the lightest, because one body being thrown
## proves the shove is wired and *two different distances* prove it is being
## read from the boss rather than from a constant.
func _test_a_slam_actually_throws_the_player() -> void:
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
	# Nothing here may kill the probe, and a dead hero refuses to be shoved.
	hero.health.max_hp = 1000000.0
	hero.health.current_hp = hero.health.max_hp

	var travelled: Dictionary = {}
	for ident: String in ["gatekeeper", "mirrorfang"]:
		var boss: EnemyData = ContentDB.enemy(ident)
		if boss == null:
			_check(false, "the roster no longer has %s to measure" % ident)
			continue
		travelled[ident] = await _throw_the_hero(field, hero, boss)
	await _test_a_boss_quickens_as_it_breaks(field, hero)
	run.queue_free()
	await get_tree().process_frame

	var heavy: float = float(travelled.get("gatekeeper", 0.0))
	var light: float = float(travelled.get("mirrorfang", 0.0))
	_check(heavy > 8.0,
		"a Gatekeeper slam moved the hero %.1f units - the blow lands and"
			% heavy + " nothing is thrown")
	_check(light > 4.0,
		"a Mirrorfang slam moved the hero %.1f units" % light)
	# The bound, measured rather than derived: whatever the physics does with a
	# shove, it may not carry the player further than the cap allows.
	_check(heavy <= Balance.HERO_SHOVE_MAX_TRAVEL + 12.0,
		"a Gatekeeper slam carried the hero %.1f units, past the %.0f bound"
			% [heavy, Balance.HERO_SHOVE_MAX_TRAVEL])
	# And the authored number is what decides it. 300 against 140 is a factor of
	# four in distance, so anything short of a clear gap means the slam is
	# reading a constant.
	_check(heavy > light * 1.6,
		"the heaviest slam threw %.1f and the lightest %.1f - too close to be"
			% [heavy, light] + " reading `boss_slam_knockback` at all")


## **A boss in a later phase slams and throws sooner** (2026-09-21), and by
## the authored share rather than by whatever a phase happens to do. Measured
## on a real body through the real doors - `_begin_slam` and `_throw_volley`
## set the clocks - because a tempo applied at one of the two would pass any
## check that read the constant.
func _test_a_boss_quickens_as_it_breaks(field: Battlefield, hero: Hero) -> void:
	var boss: EnemyData = ContentDB.enemy("gatekeeper")
	if boss == null:
		_check(false, "the roster no longer has the gatekeeper to measure")
		return
	var enemy := (load("res://scenes/battlefield/enemy.tscn") as PackedScene) \
		.instantiate() as Enemy
	enemy.setup(boss, RunState.act, field, 1.0, 1.0, 1.0)
	field.add_child(enemy)
	enemy.global_position = hero.global_position + Vector2.LEFT * 300.0
	enemy.call("_begin_slam")
	var rested: float = float(enemy.get("_slam_left"))
	enemy.call("_throw_volley", hero)
	var rested_volley: float = float(enemy.get("_volley_left"))
	_check(is_equal_approx(rested, boss.boss_slam_interval),
		"in phase zero the slam waits its authored %.1f s, waited %.1f"
			% [boss.boss_slam_interval, rested])
	# **By the share of its phases, not the count** (2026-10-06): two phases in
	# is the whole of a two-phase boss's climb, and the authored speed bonus
	# is what it carries there.
	var phases: int = maxi(boss.phase_thresholds.size(), 1)
	var calm_speed: float = enemy.targeting_speed()
	enemy.apply_boss_phase(2)
	enemy.call("_begin_slam")
	var pressed: float = float(enemy.get("_slam_left"))
	enemy.call("_throw_volley", hero)
	var pressed_volley: float = float(enemy.get("_volley_left"))
	var share: float = minf(2.0 / float(phases), 1.0)
	var expected: float = 1.0 / (1.0 + Balance.BOSS_PHASE_TEMPO * share)
	_check(is_equal_approx(enemy.targeting_speed(), calm_speed * (1.0 + boss.phase_speed_bonus * share)),
		"%d of %d phases in, the boss should walk at %.2f of its pace, walks %.2f" % [2, phases,
			1.0 + boss.phase_speed_bonus * share, enemy.targeting_speed() / maxf(calm_speed, 0.001)])
	_check(is_equal_approx(pressed / maxf(rested, 0.001), expected),
		"two phases in, the slam should wait %.2f of its clock, waits %.2f"
			% [expected, pressed / maxf(rested, 0.001)])
	_check(is_equal_approx(pressed_volley / maxf(rested_volley, 0.001), expected),
		"two phases in, the volley should wait %.2f of its clock, waits %.2f"
			% [expected, pressed_volley / maxf(rested_volley, 0.001)])
	_check(pressed < rested and pressed > rested * 0.5,
		"a pressed boss should be sooner and never twice as fast, %.1f against %.1f"
			% [pressed, rested])
	# And a boss that breaks eleven times ends where a boss that breaks twice
	# does: the last phase carries the authored bonus and no more.
	var deep: EnemyData = ContentDB.enemy("chainmaker")
	if deep != null:
		var kharok := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
		kharok.setup(deep, RunState.act, field, 1.0, 1.0, 1.0)
		field.add_child(kharok)
		kharok.global_position = hero.global_position + Vector2.LEFT * 400.0
		var walk: float = kharok.targeting_speed()
		kharok.apply_boss_phase(deep.phase_thresholds.size())
		_check(is_equal_approx(kharok.targeting_speed(), walk * (1.0 + deep.phase_speed_bonus)),
			"in his last of %d phases the Chainmaker walks at %.2f of his pace, not the authored %.2f"
				% [deep.phase_thresholds.size(), kharok.targeting_speed() / maxf(walk, 0.001),
					1.0 + deep.phase_speed_bonus])
		kharok.call("_begin_slam")
		var last_wait: float = float(kharok.get("_slam_left"))
		_check(last_wait > deep.boss_slam_interval * 0.5,
			"in his last phase the Chainmaker slams every %.1f s - more than twice as fast as authored" % last_wait)
		kharok.queue_free()
	enemy.queue_free()
	await get_tree().process_frame
	await _test_a_boss_makes_one_entrance(field, hero, boss)


## **A boss makes an entrance, once** (2026-09-30): the first time it is on the
## screen the ground takes its weight - headless, where every place is on the
## screen, that is its first tick - and never again.
func _test_a_boss_makes_one_entrance(field: Battlefield, hero: Hero, boss: EnemyData) -> void:
	var entrances: Array[int] = [0]
	var ear: Callable = func(_at: Vector2, weight: float) -> void:
		if is_equal_approx(weight, Balance.BOSS_ENTRANCE_IMPACT):
			entrances[0] += 1
	EventBus.camera_impact.connect(ear)
	var enemy := (load("res://scenes/battlefield/enemy.tscn") as PackedScene) \
		.instantiate() as Enemy
	enemy.setup(boss, RunState.act, field, 1.0, 1.0, 1.0)
	field.add_child(enemy)
	enemy.global_position = hero.global_position + Vector2.LEFT * 900.0
	for _frame: int in 12:
		await get_tree().process_frame
	EventBus.camera_impact.disconnect(ear)
	_check(enemy.made_entrance(), "a boss on the screen must make its entrance")
	_check(entrances[0] == 1, "a boss made %d entrances, not one" % entrances[0])
	enemy.queue_free()
	await get_tree().process_frame


## One slam, landed on a hero standing still, and how far it moved them.
func _throw_the_hero(field: Battlefield, hero: Hero, boss: EnemyData) -> float:
	# Placed inside its own circle, and the shove is zeroed first so a previous
	# throw still bleeding off is not counted twice.
	var centre: Vector2 = hero.global_position + Vector2.LEFT * (
		boss.boss_slam_radius * 0.4)
	hero.set("_shoved", Vector2.ZERO)
	hero.velocity = Vector2.ZERO
	for _settle: int in 4:
		await get_tree().physics_frame
	var from: Vector2 = hero.global_position

	# Through the real body, so what is measured is the slam rather than a
	# hand-made call to the shared strike. `setup` is what `_ready` requires.
	var enemy := (load("res://scenes/battlefield/enemy.tscn") as PackedScene) \
		.instantiate() as Enemy
	enemy.setup(boss, RunState.act, field, 1.0, 1.0, 1.0)
	field.add_child(enemy)
	enemy.global_position = centre
	enemy.call("_land_slam")
	# Freed at once: a live boss standing next to the probe would push it with
	# crowd separation, which is not the thing being measured.
	enemy.queue_free()

	# Long enough for the fastest authored shove to bleed off entirely.
	var frames: int = int(ceil(Balance.shove_ceiling()
		/ Balance.HERO_SHOVE_DECAY * 70.0)) + 20
	for _step: int in frames:
		await get_tree().physics_frame
	return from.distance_to(hero.global_position)
