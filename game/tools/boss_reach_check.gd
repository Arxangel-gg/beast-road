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
