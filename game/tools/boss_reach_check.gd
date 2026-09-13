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
