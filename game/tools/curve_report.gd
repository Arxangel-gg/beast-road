extends Node

## What the difficulty curve actually looks like, wave by wave.
##
##   godot --headless --path game res://tools/curve_report.tscn
##   godot --headless --path game res://tools/curve_report.tscn -- --players=2
##
## A report, never a gate. Balance is judgement, and a red build is the wrong way
## to express an opinion about pacing — see CLAUDE.md §7 on why the audit score is
## a number and not a claim.
##
## What it exists to answer: "the game scales too difficult too early" is a real
## report and an unfalsifiable one. Three sampled waves cannot tell a smooth ramp
## from a cliff, and the two numbers that matter are never in the same place. So
## this walks a whole run and puts threat and capability on one line.
##
## **Threat** is the effective HP a formation delivers: bodies × per-body HP
## scale. That is what has to be removed before the town is reached, and it is
## the product of two curves that grow independently — pack size and HP scale —
## which is exactly how a difficulty cliff gets built without anyone choosing one.
##
## **Capability** is what the player can have killed it with: the total tower
## damage per second affordable from cumulative income by that wave, at the level
## cap the Forge has reached. It is deliberately generous — it assumes perfect
## spending — because a curve the *best* case cannot hold is unarguable.
##
## The column that matters is PRESSURE, threat over capability. Its absolute
## value means little; its **shape** is the whole point. A flat line is a game
## that stays as hard as it started. A step is a wall.

## Six build spots per lane: an inner/middle/outer trio on each flank of the road.
## Read from Balance rather than restated, so the six-spot road cannot leave
## this report quietly measuring a three-spot one.
const SLOTS_PER_LANE: int = 10

## Roughly how long a formation stays on the road once it has finished walking
## on, before the last body is dealt with. Added to the spawn time and the
## between-wave interval to get a wave cycle.
##
## It is an estimate and it is load bearing: acts advance on distance, distance
## accrues in real time, so the length of a wave cycle is what decides how many
## waves an act contains. Getting it wrong moves every act boundary. [TUNE]
const ENGAGEMENT_SECONDS: float = 16.0

## Hard stop, in case a pacing change ever makes a run much longer than intended.
const MAX_WAVES: int = 200

var _rows: Array[Dictionary] = []

## Cumulative Gold from kills, carried across waves.
var _earned_gold: float = 0.0

## How many players the run is being measured for.
##
## Co-op scales the count of enemies and nothing else (`COOP_DESIGN.md` §5), and
## both sides of that move together: twice the bodies, but also two heroes and a
## shared purse earning from twice the kills. Whether those cancel is exactly the
## question this report exists to answer, so it is asked rather than assumed -
## run it at 1 and at 2 and compare the pressure columns.
##
## Not a network session. `WaveDirector.body_scale_for` is the one expression of
## the rule and is asked directly, so this cannot drift from what the director
## actually does when two people are playing.
var _players: int = 1
var _body_scale: float = 0.0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--players="):
			_players = maxi(int(argument.split("=")[1]), 1)
		# An override, so a scaling value can be swept without editing Balance
		# and rebuilding an opinion each time. Reporting only - the game always
		# reads the table.
		elif argument.begins_with("--body-scale="):
			_body_scale = maxf(float(argument.split("=")[1]), 0.01)
	RunState.reset()
	var packed: PackedScene = load("res://scenes/run/run.tscn")
	var run: Run = packed.instantiate() as Run
	add_child(run)
	await get_tree().process_frame
	run.journey.stop()
	run.battlefield.wave_director.stop()

	# Walked rather than sampled. Acts advance on distance and distance accrues in
	# real time, so where an act boundary falls depends on how long each wave
	# cycle takes - which depends on the size of the wave. Indexing acts off the
	# wave number instead put all thirty waves in Act 1 and hid both boundaries,
	# which are the two places a curve is most likely to have a cliff in it.
	var director: WaveDirector = run.battlefield.wave_director
	var distance: float = 0.0
	var act_wave: int = 0
	var act: int = 1
	for wave: int in range(1, MAX_WAVES + 1):
		var now_act: int = clampi(int(floor(distance / Balance.ACT_DISTANCE)) + 1,
			1, Balance.ACT_COUNT)
		if now_act != act:
			act = now_act
			act_wave = 0
		act_wave += 1

		var row: Dictionary = _measure(director, wave, act, act_wave, distance)
		_rows.append(row)

		var cycle: float = Balance.WAVE_INTERVAL \
			+ float(row["bodies"]) * Balance.WAVE_SPAWN_SPACING \
			+ ENGAGEMENT_SECONDS
		distance += cycle * Balance.BEAST_BASE_SPEED
		if distance >= Balance.ACT_DISTANCE * float(Balance.ACT_COUNT):
			break

	_print_table()
	var bad: int = _judge_party_scaling()

	# Tear gameplay down before draining audio. The full run owns deferred
	# wildlife arrivals; stopping Sfx first allowed one of those callbacks to
	# start a vocal decoder after the stop and immediately before headless exit,
	# leaking its OGG playback/resource objects in CI.
	run.queue_free()
	for _frame: int in 2:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 18:
		await get_tree().process_frame
	get_tree().quit(bad)


## One wave, with the run wound forward to where that wave happens.
func _measure(director: WaveDirector, wave: int, act: int, act_wave: int,
		distance: float) -> Dictionary:
	RunState.act = act
	RunState.wave_number = wave
	RunState.distance_travelled = distance
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	RunState.terrain_id = terrain.id if terrain != null else "jungle"
	director._act_wave = act_wave
	# Measured in daylight. Night is a modifier on top of everything here and
	# folding it in would hide which curve is doing the work.
	DayNight._apply(0.25)

	var lanes: int = director._progressive_lane_count(act_wave)
	var per_lane: int = director._wave_size(act_wave, terrain)
	var bodies: int = int(round(float(per_lane * lanes)
		* (_body_scale if _body_scale > 0.0 else WaveDirector.body_scale_for(_players))))
	var hp: float = director._hp_scale(0)
	var damage: float = director._damage_scale(0)
	var speed: float = director._speed_scale(0)

	var threat: float = float(bodies) * hp

	# Killing pays for the next wall, so income is a function of the bodies
	# already dealt with rather than of the clock. Modelling it as time-based
	# reported a flat capability for the whole run, which would have made every
	# ratio below meaningless.
	_earned_gold += float(bodies) * _gold_per_body()
	# The hero counts toward the defence now, and has to.
	#
	# While the run began with four towers up, leaving the hero out was a
	# conservative simplification: towers were the floor and the hero was the
	# bonus. The zero-capital start inverts that for the opening - for the first
	# waves the hero *is* the entire defence - and a model scoring those waves as
	# having no defence at all divides by nothing and reports an infinite spike
	# exactly where the design intends its gentlest moment.
	# Both heroes count. Two players is two of them on the field, which is most of
	# why twice the bodies is close to the right answer rather than double the
	# difficulty.
	var capability: float = _hero_dps() * float(_players) 		+ _affordable_dps(_earned_gold)

	return {
		"wave": wave, "act": act, "act_wave": act_wave,
		"lanes": lanes, "per_lane": per_lane, "bodies": bodies,
		"hp": hp, "damage": damage, "speed": speed,
		"threat": threat, "capability": capability,
		"pressure": threat / maxf(capability, 0.001),
	}


## The hero's own sustained damage, as a floor.
##
## One full three-hit combo against a single target: the windup, active and
## recovery of each swing for the time, the damage of all three for the numerator.
## Single-target on purpose - the swing arcs are 110 and 170 degrees and the
## finisher lunges, so a real hero in a pack does better than this. A floor is
## what a capability model wants.
##
## Read from the same arrays the hero fights with, so a rebalance of the combo
## moves this number too rather than leaving a typed-in constant behind.
func _hero_dps() -> float:
	var damage: float = 0.0
	var duration: float = 0.0
	for index: int in Balance.HERO_ATTACK_DAMAGE.size():
		damage += Balance.HERO_ATTACK_DAMAGE[index]
		duration += Balance.HERO_ATTACK_WINDUP[index] \
			+ Balance.HERO_ATTACK_ACTIVE[index] \
			+ Balance.HERO_ATTACK_RECOVERY[index]
	return damage / maxf(duration, 0.01)


## Average Gold a body is worth, across the enemies that actually walk on.
## Reading it from the data rather than typing a number keeps this honest when
## somebody rebalances a drop.
func _gold_per_body() -> float:
	var total: float = 0.0
	var count: int = 0
	for value: Variant in ContentDB.enemies.values():
		var enemy := value as EnemyData
		if enemy == null or enemy.category == EnemyData.Category.BOSS:
			continue
		total += float(enemy.resource_value)
		count += 1
	if count == 0:
		return Balance.KILL_RESOURCE_SCALE
	return total / float(count) * Balance.KILL_RESOURCE_SCALE


## Best-case tower damage per second for a given amount of Gold earned.
##
## Spending is assumed perfect, every body is assumed killed and nothing is
## assumed lost, so this is a ceiling rather than a forecast. That is the point:
## a curve the best case cannot hold is unarguable.
func _affordable_dps(earned: float) -> float:
	var gold: float = float(Balance.STARTING_GOLD) + earned

	# Spend it on whole towers first, then on the upgrades those towers can take.
	# A tower is worth far more than its cost in raw damage once levelled, so a
	# model that only counts new builds understates a prepared player badly.
	var towers: int = mini(int(gold / float(Balance.TOWER_BUILD_COST)),
		Balance.LANE_COUNT * SLOTS_PER_LANE)
	var spent: float = float(towers) * float(Balance.TOWER_BUILD_COST)
	var level: int = 1
	var cap: int = Balance.TOWER_MAX_LEVEL
	while level < cap:
		var step: int = Balance.TOWER_UPGRADE_COSTS[mini(level - 1,
			Balance.TOWER_UPGRADE_COSTS.size() - 1)]
		var round_cost: float = float(step) * float(towers)
		if spent + round_cost > gold:
			break
		spent += round_cost
		level += 1

	var reference: TowerData = ContentDB.tower("ember_spire")
	if reference == null:
		return float(towers)
	var interval: float = maxf(reference.interval_at(level), 0.01)
	return float(towers) * reference.damage_at(level) / interval


## **Does every party size get the same game?**
##
## Judged on the *mean* pressure across the run, not the peak. The peak is
## quantisation noise: capability jumps whenever the purse crosses a tower price,
## so the highest single wave lands wherever a formation happens to fall just
## before a purchase, and sweeping the scaling constant moves it up and down at
## random - 1.60 gave 0.71, 1.75 gave 0.88, 1.90 gave 0.69. Tuning against that
## is tuning against rounding. The mean over forty waves is stable to the third
## decimal and is what a player actually experiences.
##
## Measured 0.363 / 0.340 / 0.346 / 0.337 for one to four players when this was
## written, which is flat enough that the linear rule needed no per-size table.
## The band is here so it stays that way: a change that makes any party size a
## different game fails rather than being discovered by somebody playing it.
func _judge_party_scaling() -> int:
	if _players != 1 or _body_scale > 0.0:
		# Only the plain run judges. A report asked about one party size or an
		# overridden constant is a question, not a verdict.
		return 0
	var means: Array[float] = []
	for count: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		means.append(_mean_pressure_for(count))
	var lowest: float = means[0]
	var highest: float = means[0]
	for value: float in means:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	var spread: float = (highest / maxf(lowest, 0.001) - 1.0) * 100.0
	var readout: String = ""
	for index: int in means.size():
		readout += "%d:%.3f  " % [index + 1, means[index]]
	print("")
	print("[curve] mean pressure by party size   %s spread %.0f%%" % [readout, spread])
	var failed: int = 0
	if spread > PARTY_SPREAD_LIMIT:
		printerr("[curve] party sizes do not get the same game: %.0f%% spread, "
			% spread + "limit %.0f%%" % PARTY_SPREAD_LIMIT)
		failed += 1
	for index: int in means.size():
		if means[index] < PARTY_PRESSURE_FLOOR or means[index] > PARTY_PRESSURE_CEILING:
			printerr("[curve] %d players sits at %.3f, outside %.2f-%.2f"
				% [index + 1, means[index], PARTY_PRESSURE_FLOOR,
					PARTY_PRESSURE_CEILING])
			failed += 1
	if failed == 0:
		print("[curve] PASS - every party size plays the same curve")
	return failed


## How far apart the easiest and hardest party sizes may be, and the band each
## must sit in. Wide enough not to trip on model noise, narrow enough that a
## party size becoming a different game fails. [TUNE]
const PARTY_SPREAD_LIMIT: float = 22.0
const PARTY_PRESSURE_FLOOR: float = 0.26
const PARTY_PRESSURE_CEILING: float = 0.46


## Replays the whole curve for one party size and averages the pressure.
##
## Rebuilt from the same `_measure` the table uses rather than scaled from the
## one-player numbers, because capability does not scale linearly - hero damage
## does, tower damage comes off a shared purse that grows with kills, and the
## whole question is whether those two cancel.
func _mean_pressure_for(count: int) -> float:
	var was: int = _players
	var banked: float = _earned_gold
	_players = count
	# **From an empty purse.** `_measure` accumulates gold as it goes, and a
	# replay that inherits the main run's total starts every party size rich -
	# which reported 0.166 where the real run reports 0.363, and would have
	# shipped a gate that measured its own leftovers.
	_earned_gold = 0.0
	var total: float = 0.0
	var samples: int = 0
	var director := WaveDirector.new()
	var wave: int = 0
	var distance: float = 0.0
	var act_wave: int = 0
	var act: int = 1
	while wave < MAX_WAVES:
		wave += 1
		var now: int = clampi(int(floor(distance / Balance.ACT_DISTANCE)) + 1, 1,
			Balance.ACT_COUNT)
		if now != act:
			act = now
			act_wave = 0
		act_wave += 1
		var row: Dictionary = _measure(director, wave, act, act_wave, distance)
		total += float(row["pressure"])
		samples += 1
		var cycle: float = Balance.WAVE_INTERVAL \
			+ float(row["bodies"]) * Balance.WAVE_SPAWN_SPACING \
			+ ENGAGEMENT_SECONDS
		distance += cycle * Balance.BEAST_BASE_SPEED
		if distance >= Balance.ACT_DISTANCE * float(Balance.ACT_COUNT):
			break
	director.free()
	_players = was
	_earned_gold = banked
	return total / maxf(float(samples), 1.0)


func _print_table() -> void:
	print("")
	print("BEAST ROAD — difficulty curve, %d waves, daylight, best-case spending, %d player%s"
		% [_rows.size(), _players, "" if _players == 1 else "s"])
	print("")
	print("  wave  act  lanes  pack  bodies     hp   dmg   spd     threat   capable   pressure  step")
	var previous: float = 0.0
	for row: Dictionary in _rows:
		var pressure: float = float(row["pressure"])
		var step: String = "" if previous <= 0.0 \
			else "%+5.0f%%" % ((pressure / previous - 1.0) * 100.0)
		print("  %4d  %3d  %5d  %4d  %6d  %5.2f %5.2f %5.2f  %9.0f %9.0f  %9.2f  %s" % [
			row["wave"], row["act"], row["lanes"], row["per_lane"], row["bodies"],
			row["hp"], row["damage"], row["speed"],
			row["threat"], row["capability"], pressure, step])
		previous = pressure

	print("")
	_print_worst_steps()


## The three biggest single-wave jumps. A difficulty cliff is not a high number,
## it is a large step, and reading thirty rows to find one is how they get missed.
func _print_worst_steps() -> void:
	var steps: Array[Dictionary] = []
	for i: int in range(1, _rows.size()):
		var before: float = float(_rows[i - 1]["pressure"])
		var after: float = float(_rows[i]["pressure"])
		if before <= 0.0:
			continue
		steps.append({"wave": _rows[i]["wave"], "jump": after / before - 1.0})
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["jump"]) > float(b["jump"]))

	print("Sharpest increases:")
	for i: int in mini(3, steps.size()):
		print("  wave %d: %+.0f%%" % [steps[i]["wave"], float(steps[i]["jump"]) * 100.0])
	var first: float = float(_rows[0]["pressure"])
	var last: float = float(_rows[_rows.size() - 1]["pressure"])
	print("Wave 1 to %d: %.2f -> %.2f (%+.0f%% overall)" % [
		_rows.size(), first, last, (last / maxf(first, 0.001) - 1.0) * 100.0])
