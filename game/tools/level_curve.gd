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

const WAVES_PER_ACT: int = 10

var _level: int = 1
var _xp: float = 0.0
var _attribute_points: int = 0
var _skill_points: int = 0
var _kills: int = 0


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
			await _walk_campaign(director)
			print("[level]   after a clear: level %d, %d attribute points, %d skill"
				% [_level, _attribute_points, _skill_points])
	_report()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(0)


func _walk_campaign(director: WaveDirector) -> void:
	var terrains: Array[String] = ["jungle", "desert", "snow"]
	for act: int in 3:
		for wave: int in WAVES_PER_ACT:
			RunState.act = act + 1
			RunState.terrain_id = terrains[act]
			RunState.wave_number = act * WAVES_PER_ACT + wave + 1
			director._act_wave = wave + 1
			var per_lane: int = director._archetype_wave_size(
				wave + 1, ContentDB.terrain(RunState.terrain_id), null, Balance.LANE_COUNT)
			var pack: int = per_lane * Balance.LANE_COUNT
			var scale: float = director._hp_scale(0)
			var health: float = Balance.ENEMY_MAX_HP * scale
			for _enemy: int in pack:
				_kills += 1
				_award(health * Balance.HERO_XP_PER_HP)
			if wave == WAVES_PER_ACT - 1:
				print("[level]   act %d done: level %d  (pack %d, hp x%.1f)"
					% [act + 1, _level, pack, scale])


func _report() -> void:
	print("[level] ends at %d of %d after %d kills"
		% [_level, Balance.HERO_MAX_LEVEL, _kills])
	print("[level] %d attribute points, %d skill points, %d of 24 discipline nodes"
		% [_attribute_points, _skill_points,
			Balance.DISCIPLINE_MAX_TRAINED
				+ int(_level / Balance.HERO_DISCIPLINE_CAP_EVERY)])
	print("[level] %.1f hours of play at %d minutes a run"
		% [float(Balance.LEVEL_CURVE_RUNS_PER_TIER * 3) * 60.0 / 60.0,
			60])
	# A single-attribute build's ceiling: the number that decides whether
	# levelling is a nice bonus or the thing that carries the run.
	print("[level] all-in: Might +%.0f%%  Vigour +%.0f%%  Swiftness +%.0f%% move  Focus +%.0f%% command"
		% [float(_attribute_points) * Balance.HERO_MIGHT_PER_POINT * 100.0,
			float(_attribute_points) * Balance.HERO_VIGOUR_PER_POINT * 100.0,
			float(_attribute_points) * Balance.HERO_SWIFTNESS_MOVE_PER_POINT * 100.0,
			float(_attribute_points) * Balance.HERO_FOCUS_COMMAND_PER_POINT * 100.0])

func _award(amount: float) -> void:
	_xp += amount
	while _level < Balance.HERO_MAX_LEVEL:
		var needed: float = Balance.HERO_XP_BASE \
			* pow(float(_level), Balance.HERO_XP_CURVE)
		if _xp < needed:
			break
		_xp -= needed
		_level += 1
		_attribute_points += 1
		if _level % Balance.HERO_SKILL_POINT_EVERY == 0:
			_skill_points += 1
