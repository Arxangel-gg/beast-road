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
const ENGAGEMENT_SECONDS: float = Balance.WAVE_ENGAGEMENT_SECONDS

## Why the between-wave breather is **not** in the wave cycle.
##
## It looks like an omission and it is not. `Journey.stop()` runs the moment a
## breather opens, so the beast stops walking and no distance accrues for as long
## as the player stands there. Distance is what advances acts, so a breather -
## at fifteen seconds or at thirty - moves no act boundary and changes nothing
## this report measures.
##
## Adding `PREPARATION_BETWEEN_WAVES` to the cycle here would be a plausible
## "fix" that silently made every act shorter in the model than it is in the
## game. Written down so the next person to notice the gap does not close it.

## Hard stop, in case a pacing change ever makes a run much longer than intended.
const MAX_WAVES: int = 1200

var _rows: Array[Dictionary] = []

## Cumulative Gold from kills, carried across waves.
var _earned_gold: float = 0.0
## What the last _affordable_dps call managed to buy. Reported rather than
## inferred: a capability that stops climbing is either out of Gold or out of
## levels, and those two want opposite fixes.
var _bought_towers: int = 0
var _bought_level: int = 1

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
## Whether to model the returning player's bonded spirit. Off by default: the
## curve is tuned for a first run, which has none.
var _with_companion: bool = false
var _body_scale: float = 0.0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--players="):
			_players = maxi(int(argument.split("=")[1]), 1)
		elif argument == "--companion":
			_with_companion = true
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
		var now_act: int = 1
		while now_act < Balance.ACT_COUNT \
				and distance >= Balance.act_end_distance(now_act):
			now_act += 1
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
		if distance >= Balance.JOURNEY_TOTAL_DISTANCE:
			break

	_print_table()
	var bad: int = _judge_party_scaling()
	bad += _judge_escalation()

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
	_bank_the_cores_won_so_far(act)
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
	# Later acts pay more, which is what keeps Gold a decision for ten acts
	# rather than three. Modelled here as well as banked in `gain_kill_resources`,
	# or this report would go on reading the flat economy it was what caught.
	_earned_gold += float(bodies) * _gold_per_body() * Balance.kill_act_scale(act)
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
	# **And the spirit at their shoulder, when they have one.**
	#
	# A bonded companion is a persistent second body that fights, and this model
	# did not know it existed. Measured on 2026-09-13: the hero model is 38.3
	# damage a second, the best companion's base is 41.3, and at apex rarity it
	# is 88.9 - **two hundred and thirty-two per cent of the hero**. It is off by
	# default because a first run has no companion and the curve is tuned for
	# that player; `--companion` reports the returning one.
	var capability: float = _hero_dps() * _core_scale(Modifiers.HERO_DAMAGE) * float(_players) \
		+ _companion_dps() * float(_players) \
		+ _affordable_dps(_earned_gold) * _core_scale(Modifiers.TOWER_DAMAGE)

	return {
		"wave": wave, "act": act, "act_wave": act_wave,
		"gold": _earned_gold, "towers": _bought_towers, "level": _bought_level,
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
## What the spirit at the hero's shoulder adds, at the rarity being modelled.
##
## Zero unless asked for. Read from the companion roster and
## `SPIRIT_APEX_POWER` rather than typed in, so re-tuning either moves this too.
func _companion_dps() -> float:
	if not _with_companion:
		return 0.0
	var best: float = 0.0
	for value: Variant in ContentDB.companions.values():
		var kind := value as CompanionData
		if kind == null or kind.attack_interval <= 0.0:
			continue
		best = maxf(best, kind.damage / kind.attack_interval)
	return best * Balance.SPIRIT_APEX_POWER


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
		if enemy == null or not _walks_the_road(enemy):
			continue
		total += float(enemy.resource_value)
		count += 1
	if count == 0:
		return Balance.KILL_RESOURCE_SCALE
	return total / float(count) * Balance.KILL_RESOURCE_SCALE



## Whether a body of this kind is one a wave ever sends up a lane.
##
## **The average this report earns its Gold from is an average of road
## bodies**, and the only thing that ever made that true was that every
## non-boss enemy in the game happened to be one. It stopped being true on
## 2026-09-15, when the second and third camps were given breeds of their own
## and the war camp a lord - eleven resources that live in a camp, never take a
## route, and are worth several times what a road body is because going to
## find one is supposed to be worth the detour.
##
## **The report went on averaging them in, and it was a 143% error in the
## purse**: 8.88 Gold a body against the 3.64 a road actually pays. The model
## bought roughly two and a half times the towers it should have, so modelled
## capability nearly doubled and mean pressure fell from 0.434 to 0.227 -
## straight through the floor and out the bottom of the band, reported on
## every release since with nothing failing, because this report is advisory
## and its own band check only prints.
##
## Nothing about the *game* moved. A camp lord pays what it always paid, to a
## player who went and killed one.
func _walks_the_road(enemy: EnemyData) -> bool:
	return enemy.category == EnemyData.Category.BREED 		or enemy.category == EnemyData.Category.ELITE

## Best-case tower damage per second for a given amount of Gold earned.
##
## Spending is assumed perfect, every body is assumed killed and nothing is
## assumed lost, so this is a ceiling rather than a forecast. That is the point:
## a curve the best case cannot hold is unarguable.
func _affordable_dps(earned: float) -> float:
	var gold: float = float(Balance.STARTING_GOLD) + earned

	# **The best build the purse can buy, not the first one it can afford.**
	#
	# This used to fill every slot with a level-one tower and only then start
	# upgrading, a round at a time across all forty. Nobody plays that way, and
	# the arithmetic is brutal: a round of upgrades across forty towers costs
	# forty times a step, so the model reached wave 73 of a ten-act run still
	# at **level 2**, with capability pinned flat from wave 50 - the moment the
	# fortieth slot filled - through the last twenty-three waves of the game.
	# Every conclusion about the late acts was drawn from that flat line.
	#
	# The docstring above already said spending is "assumed perfect". It now is:
	# every count of towers at every level is priced, and the most damaging one
	# the purse covers wins.
	var reference: TowerData = ContentDB.tower("ember_spire")
	if reference == null:
		_bought_towers = 0
		_bought_level = 1
		return 0.0
	var slots: int = Balance.LANE_COUNT * SLOTS_PER_LANE
	var best: float = 0.0
	var best_towers: int = 0
	var best_level: int = 1
	# What one tower costs to stand at each level, accumulated once.
	var to_level: PackedFloat64Array = [float(Balance.TOWER_BUILD_COST)]
	for step: int in range(1, Balance.TOWER_MAX_LEVEL):
		var price: int = Balance.TOWER_UPGRADE_COSTS[mini(step - 1,
			Balance.TOWER_UPGRADE_COSTS.size() - 1)]
		to_level.append(to_level[step - 1] + float(price))
	for level: int in range(1, Balance.TOWER_MAX_LEVEL + 1):
		var each: float = to_level[level - 1]
		if each <= 0.0:
			continue
		var towers: int = mini(int(gold / each), slots)
		if towers <= 0:
			continue
		var interval: float = maxf(reference.interval_at(level), 0.01)
		var output: float = float(towers) * reference.damage_at(level) / interval
		if output > best:
			best = output
			best_towers = towers
			best_level = level

	_bought_towers = best_towers
	_bought_level = best_level
	return best


## **Whose account this was measured on.**
##
## The report reads the save: a levelled hero and worn gear are capability it
## counts, so the same commit measures about five percent easier on a played
## account than on a new one. That is not a fault - a veteran really does have an
## easier road - but it means **a number read here is only comparable to another
## number read on the same account**, and the band is held by CI against a fresh
## one.
##
## This was found by the release sweep of 2026-09-15 disagreeing with a local run
## by 0.023, after a whole session of tuning against the owner's live save. The
## sweep is right, because the sweep is what ships. Printed rather than fixed:
## measuring a veteran's road is a legitimate thing to want, and the failure was
## never knowing which one was on screen.
##
## To measure the way the gate does, point the profile somewhere empty:
##
##   APPDATA=/tmp/empty LOCALAPPDATA=/tmp/empty godot --headless --path game ...
func _print_the_account() -> void:
	var worn: int = 0
	for points: int in MetaState.gear_attribute_points():
		worn += points
	# **Keyed on the hero's level and nothing else.** A new account is not an
	# empty one - it opens with eight towers unlocked and the run hands out a
	# starting weapon, so "no gear and no towers" is never true and the first cut
	# of this line called a fresh profile played. A level above one cannot be
	# baseline.
	var fresh: bool = MetaState.hero_level <= 1
	print(("[curve] measured on %s - hero level %d, %d gear points, %d towers "
		+ "unlocked%s")
		% ["a NEW account" if fresh else "a PLAYED account", MetaState.hero_level,
			worn, MetaState.unlocked_towers.size(),
			"" if fresh else "  <- the band below is held against a new one"])


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
	_print_the_account()
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


## **Does the campaign get harder as it goes?**
##
## The party check asks whether everyone plays the same curve. It says nothing
## about the curve's *shape*, and the shape was wrong: measured over ten acts,
## the hardest act in the game was **Act III** at 0.477, and every one of the
## seven acts after it was easier - the finale easiest of all at 0.335. A
## player who beat the old three-act finale then coasted for two thirds of the
## campaign.
##
## That was invisible for two reasons, both now fixed. The run mean is a
## perfectly healthy 0.348 whatever shape produces it, and the model had
## capability pinned flat from wave 50, which flattered the late acts into
## looking like they were holding up.
##
## Two properties, and they are deliberately loose. Per-act means carry real
## noise - acts differ in how many waves they hold and where those waves fall
## against the purse - so this is not a monotonic ladder. It asks only that the
## end of the road is harder than the start of it, and that no act is a
## holiday.
func _judge_escalation() -> int:
	if _players != 1 or _body_scale > 0.0:
		return 0
	var totals: Dictionary = {}
	var counts: Dictionary = {}
	for row: Dictionary in _rows:
		var act: int = int(row["act"])
		totals[act] = float(totals.get(act, 0.0)) + float(row["pressure"])
		counts[act] = int(counts.get(act, 0)) + 1
	var means: Array[float] = []
	var readout: String = ""
	for act: int in range(1, Balance.ACT_COUNT + 1):
		if not counts.has(act):
			continue
		var mean: float = float(totals[act]) / float(counts[act])
		means.append(mean)
		readout += "%d:%.2f " % [act, mean]
	print("")
	print("[curve] mean pressure by act   %s" % readout)
	if means.size() < Balance.ACT_COUNT:
		return 0

	var failed: int = 0
	var opening: float = (means[0] + means[1] + means[2]) / 3.0
	var closing: float = (means[means.size() - 3] + means[means.size() - 2]
		+ means[means.size() - 1]) / 3.0
	if closing < opening * ESCALATION_RATIO:
		printerr(("[curve] the road does not escalate: the last three acts "
			+ "average %.3f against the first three at %.3f, and a ten-act "
			+ "campaign whose hardest stretch is its opening is a campaign "
			+ "that coasts") % [closing, opening])
		failed += 1
	var act_one: float = means[0]
	for index: int in range(3, means.size()):
		if means[index] < act_one * HOLIDAY_FLOOR:
			printerr(("[curve] act %d sits at %.3f against Act I at %.3f - an "
				+ "act later than the third that asks less than the first is a "
				+ "holiday in the middle of the road")
				% [index + 1, means[index], act_one])
			failed += 1
	if failed == 0:
		print("[curve] PASS - the road escalates and no act is a holiday")
	return failed


## How much harder the last three acts must be than the first three, and how
## far below Act I any later act may fall. Loose on purpose: per-act means
## carry real noise from how many waves an act holds. [TUNE]
const ESCALATION_RATIO: float = 1.25
const HOLIDAY_FLOOR: float = 0.95


## How far apart the easiest and hardest party sizes may be, and the band each
## must sit in. Wide enough not to trip on model noise, narrow enough that a
## party size becoming a different game fails. [TUNE]
const PARTY_SPREAD_LIMIT: float = 22.0
## **The band the campaign is tuned to sit inside.**
##
## Moved 2026-09-15 from 0.26-0.46 with the owner's ruling that the road should
## pay less and ask more. The old band was not wrong - it described a different
## game, and this file recorded the new one in CLAUDE.md while *these two
## constants* were left behind, so the report judged the re-tune against the game
## it replaced and exited non-zero while printing PASS on escalation.
##
## **A band recorded in prose and enforced by a number in another file is two
## places to change and one place to forget.** This is the one that decides.
const PARTY_PRESSURE_FLOOR: float = 0.44
const PARTY_PRESSURE_CEILING: float = 0.58


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
		# **Asked the same way the table asks it.** This divided by
		# `ACT_DISTANCE`, which is every act the same length - so it did not
		# know about `ACT_OPENING_EXTRA_DISTANCE` and put every act boundary in
		# the replay several waves away from where the table has it. The two
		# were then reporting two different campaigns, and the party means were
		# the wrong one.
		var now: int = 1
		while now < Balance.ACT_COUNT and distance >= Balance.act_end_distance(now):
			now += 1
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
		if distance >= Balance.JOURNEY_TOTAL_DISTANCE:
			break
	director.free()
	_players = was
	_earned_gold = banked
	return total / maxf(float(samples), 1.0)


func _print_table() -> void:
	print("")
	print("WILDERHOLD — difficulty curve, %d waves, daylight, best-case spending, %d player%s"
		% [_rows.size(), _players, "" if _players == 1 else "s"])
	print("")
	print("  wave  act  lanes  pack  bodies     hp   dmg   spd     threat      gold  twr  lvl   capable   pressure  step")
	var previous: float = 0.0
	for row: Dictionary in _rows:
		var pressure: float = float(row["pressure"])
		var step: String = "" if previous <= 0.0 \
			else "%+5.0f%%" % ((pressure / previous - 1.0) * 100.0)
		print("  %4d  %3d  %5d  %4d  %6d  %5.2f %5.2f %5.2f  %9.0f %9.0f  %3d  %3d %9.0f  %9.2f  %s" % [
			row["wave"], row["act"], row["lanes"], row["per_lane"], row["bodies"],
			row["hp"], row["damage"], row["speed"],
			row["threat"], row["gold"], row["towers"], row["level"],
			row["capability"], pressure, step])
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


## The permanent rewards a run is actually carrying by this act.
##
## **This model knew about none of them.** A ten-act run banks one boss core an
## act - always active, never socketed, no choice involved - and the report
## measured a hero and a set of towers that had never killed anything. By Act X
## a real player holds nine of them, so the late acts were being scored as
## harder than they are.
##
## Cores only, and that is the line. Relics, portents and Road Cards are all
## *choices* - which one, whether to take it, and a portent charges a bane for
## its boon - so modelling them means modelling a player's judgement, and the
## report would start measuring a strategy rather than a curve. A core is paid
## for killing a boss and every run gets the same ones in the same order, which
## is exactly what a baseline wants.
##
## The act's own core is deliberately excluded: it is paid for *killing* this
## act's boss, so it is not in hand while this act is being fought.
##
## **Measured: mean pressure 0.433 before this, 0.353 after.** That is not the
## game getting easier - it is the model catching up with a game that had been
## handing out a permanent +25% tower damage since Act III and scoring the
## seven acts after it as though nobody had one. The band is 0.44 to 0.58 and
## the midpoint is 0.36, so the honest figure sits closer to the middle than
## the flattering one did.
func _bank_the_cores_won_so_far(act: int) -> void:
	var held: Array[String] = []
	for earlier: int in range(1, act):
		var core: RelicData = ContentDB.boss_core_for_act(earlier)
		if core != null:
			held.append(core.id)
	RunState.boss_cores = held
	Modifiers.rebuild()


## What the banked cores do to one number, as a multiplier.
##
## Read off the live table rather than summed from the data, so a core authored
## onto a different key moves this by itself - and so the model cannot drift
## from what the game resolves.
func _core_scale(key: String) -> float:
	return maxf(Modifiers.multiplier(key), 0.0)
