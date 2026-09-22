extends Node

## What level does a hero actually reach over a full run?
##
##   godot --headless --path game res://tools/level_curve.tscn
##
## The levelling constants are three numbers that interact — an XP curve, a rate
## per point of enemy health, and the act scaling that decides how much health
## walks down the road. Guessing any one in isolation is how a hero ends Act I at
## level 90 or finishes the game at level 30, and neither is visible from reading
## the constants.
##
## **It drives the real wave director rather than modelling it.** The first
## version modelled wave growth as compounding across the whole run and reported
## 103,788 kills, because growth actually compounds per *act* and resets. A tool
## that models the thing it is measuring is only ever as right as the model, and
## a wrong one is worse than none: it produces confident numbers to tune against.
##
## Reporting only, never a gate. The right curve is a judgement about pacing, and
## a red build is the wrong way to hold an opinion about pacing.

## **How long a run is, asked of `Balance` rather than written down here.**
##
## This file held `WAVES_PER_ACT = 10` and `MINUTES_PER_ACT = 15`, which were
## true of a three-act road and had been wrong since the campaign became 622
## waves and then longer. Ten waves an act over ten acts is a hundred waves
## against a road of about eight hundred, and two and a half hours against
## about twelve - so the one tool that answers "how long is the climb to a
## hundred" was modelling **an eighth of the game**, and the XP curve was
## tuned against it.
##
## `Balance.waves_in_act` and `waves_in_run` are what the wave growth itself
## is scaled by, so this now asks the same question the game asks. And an
## hour is arithmetic rather than an estimate: `WAVE_ROAD_DISTANCE`'s own
## comment says one unit of road is one second at `BEAST_BASE_SPEED`, so the
## road's length *is* the run's length in seconds.
##
## The lesson is the one already written down twice: a constant read only by a
## model the game never runs is exactly as dead as one nothing reads, and far
## harder to see, because every report built on it says the feature works.
##
## **And it printed a tier multiplier it did not apply.** Every line of the
## report named `xp x2.4` and `xp x5.0` beside the tier, and the walk paid the
## health scale alone - so the two tiers that exist to be worth grinding were
## modelled at a fifth and a half of what they pay. A figure printed beside a
## number that does not use it is the most convincing kind of wrong.

var _level: int = 1
var _xp: float = 0.0
var _attribute_points: int = 0
var _skill_points: int = 0
var _kills: int = 0
## Every point of XP the road paid out, including what a capped hero threw
## away. `_xp` cannot answer "how much is a campaign worth" once the cap is
## reached - it reads zero for the ninth campaign exactly as it would for a
## campaign that paid nothing - and that is the number the curve is solved
## against.
var _earned: float = 0.0
## Which wave of the very first campaign each early level landed on. The
## opening is the half of this curve that must **not** move - a new Warden's
## first evening is the evening it was - and "the ladder is five times
## taller" says nothing about it either way. A level's cost in XP is not its
## cost in road, because the road's own income climbs beside it.
var _opening: Dictionary = {}
var _wave_of_run: int = 0


func _ready() -> void:
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 6:
		await get_tree().process_frame

	var director: WaveDirector = run.battlefield.wave_director
	# Levels persist now, so the question is no longer "what does a run reach"
	# but "how many runs is the climb". Each tier is walked from wherever the
	# previous one left the hero.
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		RunState.tier_id = tier.id
		print("[level] --- %s (hp x%.1f, xp x%.1f), expects %s at its bosses ---"
			% [tier.display_name, tier.hp_scale, tier.xp_scale, str(tier.boss_levels)])
		for _run_index: int in Balance.LEVEL_CURVE_RUNS_PER_TIER:
			var before: float = _earned
			await _walk_campaign(director)
			print("[level]   after clear %d: level %d, %d attribute points, %d skill"
				% [_run_index + 1, _level, _attribute_points, _skill_points])
			print("[level]     the campaign paid %.0f XP; %.0f earned in all"
				% [_earned - before, _earned])
	_report()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(0)


func _walk_campaign(director: WaveDirector) -> void:
	# Read from the content rather than named here. A hand-written list of three
	# regions reported a three-act campaign for as long as one existed, and
	# would have gone on doing it silently after the road grew to ten.
	var walked: int = 0
	# **The tier pays twice and the model only counted once.** `_hp_scale`
	# already carries `tier.hp_scale`, so a Hell body walked in here with the
	# right health - and `Enemy._on_died` then multiplies the payout by
	# `tier.xp_scale` a second time, which this never did. So Nightmare was
	# modelled at 42% of what it pays and Hell at 20%, and the one tool that
	# answers "how many campaigns is the climb" was answering it for a game
	# where the harder tiers are barely worth running. Asked of the tier
	# rather than written down, exactly as the health scale is.
	var tier: CampaignTierData = RunState.tier()
	var tier_xp: float = tier.xp_scale if tier != null else 1.0
	for act: int in Balance.FINAL_ASCENT_ACT:
		var ground: TerrainData = ContentDB.terrain_for_act(act + 1)
		var waves: int = int(round(Balance.waves_in_act(act + 1)))
		for wave: int in waves:
			walked += 1
			_wave_of_run = walked
			RunState.act = act + 1
			RunState.terrain_id = ground.id if ground != null else "jungle"
			RunState.wave_number = walked
			director._act_wave = wave + 1
			var per_lane: int = director._archetype_wave_size(
				wave + 1, ContentDB.terrain(RunState.terrain_id), null, Balance.LANE_COUNT)
			var pack: int = per_lane * Balance.LANE_COUNT
			var scale: float = director._hp_scale(0)
			var health: float = Balance.ENEMY_MAX_HP * scale
			for _enemy: int in pack:
				_kills += 1
				_award(health * Balance.HERO_XP_PER_HP * tier_xp)
			if wave == waves - 1:
				print("[level]   act %d done: level %d  (%d waves, pack %d, hp x%.1f)"
					% [act + 1, _level, waves, pack, scale])


func _report() -> void:
	print("[level] ends at %d of %d after %d kills"
		% [_level, Balance.HERO_MAX_LEVEL, _kills])
	var ladder: float = 0.0
	for level: int in range(1, Balance.HERO_MAX_LEVEL):
		ladder += Balance.HERO_XP_BASE * pow(float(level), Balance.HERO_XP_CURVE)
	print("[level] the ladder to %d is %.0f XP; the road paid %.0f"
		% [Balance.HERO_MAX_LEVEL, ladder, _earned])
	var opening: PackedStringArray = []
	for level: int in [2, 5, 10, 20, 30]:
		opening.append("L%d wave %s" % [level,
			str(_opening.get(level, "never"))])
	print("[level] the opening, on the very first campaign: %s"
		% ", ".join(opening))
	print("[level] %d attribute points, %d skill points, %d of 24 discipline nodes"
		% [_attribute_points, _skill_points,
			Balance.DISCIPLINE_MAX_TRAINED
				+ int(_level / Balance.HERO_DISCIPLINE_CAP_EVERY)])
	# A run is exactly as long as the road is, because one unit of road is one
	# second at the beast's base speed - see `WAVE_ROAD_DISTANCE`.
	var run_hours: float = (Balance.JOURNEY_TOTAL_DISTANCE
		+ Balance.FINAL_ASCENT_DISTANCE) / 3600.0
	var runs: int = Balance.LEVEL_CURVE_RUNS_PER_TIER * ContentDB.tiers_sorted().size()
	print("[level] a campaign is %.0f waves and about %.1f hours"
		% [Balance.waves_in_run(), run_hours])
	print("[level] %.0f hours of play over %d campaigns"
		% [float(runs) * run_hours, runs])
	# A single-attribute build's ceiling: the number that decides whether
	# levelling is a nice bonus or the thing that carries the run.
	print("[level] all-in: Might +%.0f%%  Vigour +%.0f%%  Swiftness +%.0f%% move  Focus +%.0f%% command"
		% [float(_attribute_points) * Balance.HERO_MIGHT_PER_POINT * 100.0,
			float(_attribute_points) * Balance.HERO_VIGOUR_PER_POINT * 100.0,
			float(_attribute_points) * Balance.HERO_SWIFTNESS_MOVE_PER_POINT * 100.0,
			float(_attribute_points) * Balance.HERO_FOCUS_COMMAND_PER_POINT * 100.0])

func _award(amount: float) -> void:
	_earned += amount
	_xp += amount
	while _level < Balance.HERO_MAX_LEVEL:
		var needed: float = Balance.HERO_XP_BASE \
			* pow(float(_level), Balance.HERO_XP_CURVE)
		if _xp < needed:
			break
		_xp -= needed
		_level += 1
		if not _opening.has(_level):
			_opening[_level] = _wave_of_run
		_attribute_points += 1
		if _level % Balance.HERO_SKILL_POINT_EVERY == 0:
			_skill_points += 1
