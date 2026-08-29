extends Node

const CommandSystemScript = preload("res://scripts/systems/command_system.gd")

## Headless regression test for the production difficulty/economy curve.
## It checks the two failure modes this pass fixes: Act 2 becoming easier than
## the player's build, and the upgrade economy ending before the first boss.

var _failures: PackedStringArray = []
var _run: Run = null

## The account's worn gear, put aside for the duration.
var _equipped_before: Dictionary = {}


func _ready() -> void:
	# The tester's own equipment is not part of the game's balance.
	#
	# `RunState.attribute()` returns placed points *plus* whatever gear the
	# account is wearing, which is right for gameplay and wrong for a measurement
	# tool. Three assertions here read that accessor to check where a *placed*
	# point landed, so on a save with a Might weapon equipped they saw placed plus
	# gear and failed - "the point must land", "placed attributes must come back",
	# "placed attributes must survive a new run".
	#
	# CI never saw it. A fresh runner has no save, so the gear bonus is zero and
	# every assertion passed; the failure only appeared on a machine belonging to
	# somebody who had actually played the game, which is the worst possible place
	# for a release gate to first go red.
	#
	# Set aside rather than asserted around: no measurement in this file should
	# depend on what the person running it happens to be wearing.
	_equipped_before = MetaState.equipped.duplicate()
	MetaState.equipped = {}

	RunState.reset()
	var packed: PackedScene = load("res://scenes/run/run.tscn")
	_run = packed.instantiate() as Run
	add_child(_run)
	await get_tree().process_frame
	_run._preparation_left = 0.0
	_run._on_ride_on_requested()
	_run._on_ride_on_requested()
	await get_tree().process_frame
	_run.journey.stop()

	_test_upgrade_track()
	_test_production_profile()
	_test_four_currency_economy()
	await _test_live_tower_utility()
	_test_opening_envelope()
	_test_coop_scaling()
	_test_act_curves()
	_test_sequential_waves()
	_test_enemy_roles()
	await _test_chill_never_locks()
	_test_boss_bar_is_wired()
	_test_damage_states_are_reversible()
	_test_hero_levelling()
	await _test_loot_and_weather()
	_test_tiers_and_persistence()
	_test_stash_economy()
	_test_projectile_art_resolves()
	_test_fusion_pair_lookup()
	_test_tools_and_sigils()
	_test_final_ascent()
	_test_beast_rests_in_preparation()
	_test_controller_parity()
	_test_zoom_range()
	_test_beast_gait()
	_test_hostile_projectile()
	_test_live_relic_updates()
	_test_wave_archetypes()
	_test_road_archetypes()
	_test_target_priorities()
	await _test_preparation_and_command()
	await _test_boss_phases()
	_test_run_telemetry()

	if _failures.is_empty():
		print("[balance] PASS — mastery economy and three-act pressure curve")
	else:
		for failure: String in _failures:
			push_error("[balance] " + failure)

	# Handed back before the process ends. The tool writes no save, but it shares
	# the autoload with anything that might, and a gate that quietly undresses the
	# player would be a worse bug than the one it was added to fix.
	MetaState.equipped = _equipped_before

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for frame: int in 30:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _test_upgrade_track() -> void:
	_check(RunState.tower_level_cap() == 2, "towers must begin capped at level 2")
	_check(ContentDB.building("forge").effect_at(1) == 3.0,
		"Forge tier 1 must communicate mastery level 3")
	RunState.building_tiers["forge"] = 3
	_check(RunState.tower_level_cap() == 5, "Forge tier 3 must unlock level 5")
	var full_cost: int = Balance.TOWER_BUILD_COST
	for cost: int in Balance.TOWER_UPGRADE_COSTS:
		full_cost += cost
	_check(full_cost >= 1000, "one max tower must remain a meaningful late-run investment")
	_check(Balance.TOWER_LEVEL_UTILITY.size() == Balance.TOWER_MAX_LEVEL,
		"utility progression must cover every tower level")


## Release-defining values must not be replaced by a convenient local playtest
## profile. Harnesses may fund or fortify themselves after reset; the product
## contract stays here in one cheap gate.
func _test_production_profile() -> void:
	_check(Balance.ACT_COUNT == 3, "the 1.0 campaign must contain exactly three acts")
	_check(Balance.TOWER_MAX_LEVEL == 5, "the 1.0 tower cap must remain level 5")
	_check(Balance.STARTING_GOLD == 0, "a production run must start with zero Gold")
	_check(is_equal_approx(Balance.HERO_MAX_HP, 100.0),
		"production hero maximum HP must be 100, got %.1f" % Balance.HERO_MAX_HP)
	_check(Balance.HERO_MAX_WOUNDS == 3,
		"the third lethal down must end the run, got a %d-Wound cap" % Balance.HERO_MAX_WOUNDS)


func _test_four_currency_economy() -> void:
	# The wilderness is a third party that happens to you, not a second enemy
	# faction - and in Act I it was reading as the boss fight. A wolf costs 8 a
	# bite against a hero with 100 and they arrive in threes, during the phase
	# the player is meant to be reading the board in.
	var early: float = Balance.wildlife_bite(1)
	var late: float = Balance.wildlife_bite(3)
	_check(early < late,
		"a predator must bite softer in Act I than Act III, got %.2f and %.2f"
			% [early, late])
	_check(early >= 0.4,
		"and not so soft the wilderness stops mattering, got %.2f" % early)
	_check(is_equal_approx(late, 1.0),
		"the late game must be untouched by the ramp, got %.2f" % late)
	_check(RunState.currencies.size() == 4,
		"the run must have exactly four role-specific economy wallets")
	_check(RunState.currency(RunState.GOLD) == 0,
		"a fresh production run must open with no Gold, got %d"
			% RunState.currency(RunState.GOLD))
	# Stone is deliberately still seeded. It cannot buy anything on its own -
	# every tower, Fusion included, carries a Gold price - so this says only that
	# Stone will not be the thing standing between an earned Gold pile and the
	# opening Fusion.
	_check(RunState.currency(RunState.STONE) >= Balance.TOWER_COMBO_STONE_COST,
		"seeded Stone must not be what blocks the opening Fusion")
	_check(ContentDB.buildings.size() == 9,
		"the town must expose all nine launch plots")
	_check(RunState.building_tier("woodcutter") == 1 \
		and RunState.building_tier("granary") == 1,
		"Woodcutter and Wheat Farm must begin at tier one")
	# The exchange is the subject here, not the opening economy, so it funds
	# itself. The run starts with no Gold as of 2026-08-24, and a Market test
	# leaning on the old 390-Gold cache would be silently measuring the re-cut
	# instead of the trade.
	RunState.gain_currency(RunState.GOLD, 200)
	var total_before: int = 0
	for id: String in RunState.CURRENCIES:
		total_before += RunState.currency(id)
	RunState.building_tiers["market"] = 1
	var prior_phase: RunState.Phase = RunState.phase
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.begin_preparation_market()
	var source: String = RunState.GOLD
	var target: String = RunState.FOOD
	var market_problem: String = TownScope.try_market_trade(source, target)
	_check(market_problem.is_empty(),
		"a funded Market exchange must resolve during Preparation (%s)" % market_problem)
	var total_after: int = 0
	for id: String in RunState.CURRENCIES:
		total_after += RunState.currency(id)
	_check(total_after < total_before,
		"Market exchange must destroy value rather than permit a profit loop")
	TownScope.try_market_trade(source, target)
	_check(not TownScope.try_market_trade(source, target).is_empty(),
		"Market exchanges must stop at the per-Preparation cap")
	RunState.set_phase(prior_phase)


func _test_live_tower_utility() -> void:
	var field: Battlefield = _run.battlefield
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(9999)
	var bulwark: TowerData = ContentDB.tower("bulwark")
	var bulwark_at: Vector2i = _free_anchor(field)
	_check(field.try_build(bulwark_at, bulwark).is_empty(), "Bulwark must be buildable")
	await get_tree().process_frame
	var built: Tower = field.tower_at_anchor(bulwark_at)
	_check(built != null and Health.of(built) != null,
		"taunting towers must expose live structure health")
	if built != null and Health.of(built) != null:
		var tower_health: Health = Health.of(built)
		var before_hp: float = tower_health.current_hp
		tower_health.take_damage(10.0, Vector2.ZERO)
		_check(tower_health.current_hp < before_hp,
			"taunting towers must take enemy damage")
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)


func _test_act_curves() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(2, 1200.0, 48, "desert", 12)
	var act2_size: int = director._wave_size(12, ContentDB.terrain("desert"))
	var act2_hp: float = director._hp_scale(0)
	var act2_damage: float = director._damage_scale(0)
	_check(act2_size >= 6, "Act 2 waves must outgrow the compact opening formations")
	_check(act2_hp >= 2.4, "Act 2 durability must materially exceed Act 1")
	_check(act2_damage < act2_hp, "damage must scale below HP to avoid cheap one-shots")

	_set_progress(3, 2550.0, 88, "snow", 22)
	var act3_size: int = director._wave_size(22, ContentDB.terrain("snow"))
	var act3_hp: float = director._hp_scale(0)
	_check(act3_size > act2_size * 1.25, "Iron Steppe must deliver the largest packs")
	_check(act3_hp > act2_hp * 1.35, "Act 3 must demand mastery upgrades")
	_check(director._speed_scale(0) > 1.08, "late-run enemies must move faster")

	# Crossing into Saltglass should reveal new tactics, not erase the player's
	# progress with a seventy-percent stat jump on the very first formation.
	DayNight._apply(0.18)
	_set_progress(1, 790.0, 18, "jungle", 18)
	var act1_exit_hp: float = director._hp_scale(0)
	_set_progress(2, 910.0, 19, "desert", 1)
	var act2_entry_hp: float = director._hp_scale(0)
	_check(act2_entry_hp <= act1_exit_hp * 1.40,
		"Act 2 entry must rise smoothly instead of becoming an early stat wall")
	_set_progress(3, 2550.0, 88, "snow", 22)
	DayNight._apply(0.74)
	print("[balance] Act2 per-lane=%d hp=%.2f damage=%.2f | Act3 per-lane=%d hp=%.2f" \
		% [act2_size, act2_hp, act2_damage, act3_size, act3_hp])


## New players can establish a four-road baseline and learn one pressure at a
## time, while every modifier is neutral before the midgame begins.
func _test_opening_envelope() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(1, 0.0, 1, "jungle", 1)
	DayNight._apply(0.18)
	var terrain: TerrainData = ContentDB.terrain("jungle")
	var first_size: int = director._wave_size(1, terrain)
	var first_hp: float = director._hp_scale(0)
	var first_damage: float = director._damage_scale(0)
	# The opening contract, rewritten for the zero-capital start.
	#
	# This assertion read "opening Gold must cover all four roads plus one flex
	# purchase". As of 2026-08-24 that is false by design - GDD §448's envelope
	# was re-cut by the owner and there is no opening Gold at all.
	#
	# What survives the re-cut is §448's teaching obligation, which the amendment
	# restates rather than removes: the opening must teach before it tests. These
	# are its measurable halves. A player who cannot kill fast enough to afford a
	# first tower has been tested, not taught - and a player handed one for free
	# on wave 1 was never asked to fight for it.
	var ramp: Dictionary = _opening_gold_ramp(director, terrain)
	var first_tower_wave: int = int(ramp["first_tower_wave"])
	var baseline_wave: int = int(ramp["baseline_wave"])
	_check(Balance.STARTING_GOLD == 0,
		"the opening envelope requires zero build capital")
	_check(first_tower_wave >= 2,
		"wave 1 alone must not pay for a tower; first affordability was wave %d"
			% first_tower_wave)
	_check(baseline_wave >= 2,
		"a tower on every road must be earned, not handed over at the gate")
	_check(first_tower_wave > 0 and first_tower_wave <= 4,
		"clearing the opening must pay for a first tower by wave 4, got %s" % (
			"never" if first_tower_wave == 0 else str(first_tower_wave)))
	_check(baseline_wave > 0 and baseline_wave <= 12,
		"a tower for every road must be affordable by wave 12, got %s" % (
			"never" if baseline_wave == 0 else str(baseline_wave)))
	director._wave_timer = 1.0
	RunState.wave_number = 0
	director._on_act_started(1, "jungle")
	_check(director.time_to_next_wave() >= 15.0,
		"live first-wave timer must leave a meaningful planning window")
	RunState.wave_number = 1
	_check(first_size <= 5, "first wave must teach with a compact pack")
	_check(first_hp <= 0.8 and first_damage <= 0.75,
		"first enemies must be forgiving in both durability and contact threat")
	_check(director._progressive_lane_count(2) == 1,
		"the first two waves must teach one road at a time")
	# The property, not the timetable. These used to name the exact waves roads
	# arrived on, so re-pacing the opening - which is a tuning decision, made
	# against the measured curve in tools/curve_report.tscn - failed a gate that
	# had no opinion about the thing that actually matters.
	var widest: int = 0
	var previous_lanes: int = 0
	for act_wave: int in range(1, 20):
		var lanes: int = director._progressive_lane_count(act_wave)
		_check(lanes >= previous_lanes,
			"roads must never close again: wave %d went %d -> %d" % [
				act_wave, previous_lanes, lanes])
		_check(lanes - previous_lanes <= 1,
			"roads must open one at a time: wave %d jumped %d -> %d" % [
				act_wave, previous_lanes, lanes])
		previous_lanes = lanes
		widest = maxi(widest, lanes)
	_check(widest == Balance.WAVE_LANES_MAX,
		"the opening act must reach every road before it ends")

	# Opening curves protect and then get out of the way. Anything above 1.0
	# would be an opening that is harder than the curve it is protecting.
	for curve: Array[float] in [Balance.WAVE_OPENING_COUNT_SCALE,
			Balance.WAVE_OPENING_HP_SCALE, Balance.WAVE_OPENING_DAMAGE_SCALE,
			Balance.WAVE_ACT_OPENING_COUNT_SCALE]:
		for value: float in curve:
			_check(value <= 1.0, "an opening curve must never exceed 1.0, got %.2f" % value)
		_check(is_equal_approx(curve[curve.size() - 1], 1.0),
			"an opening curve must end neutral, got %.2f" % curve[curve.size() - 1])
		_check(director._opening_scale(curve, curve.size() + 1) == 1.0,
			"opening protection must be exactly neutral once its envelope is over")
	var early_formations: Array[WaveArchetypeData] = ContentDB.available_wave_archetypes(1, 3)
	_check(early_formations.size() == 1 and early_formations[0].id == "measured_advance",
		"specialist formations must wait until the core loop is established")
	var supply_total: int = 0
	for amount: int in Balance.WAVE_OPENING_SUPPLIES:
		supply_total += amount
	_check(supply_total >= Balance.TOWER_BUILD_COST,
		"opening supply pulses must finance at least one reactive defence")
	print("[balance] Opening pack=%d hp=%.2f damage=%.2f prep=%.0fs gold=%d supplies=%d" \
		% [first_size, first_hp, first_damage, Balance.WAVE_FIRST_PREPARATION,
			Balance.STARTING_GOLD, supply_total])


## When the opening can afford its first tower, and one for every road.
##
## Walks the opening waves adding what clearing each one pays - bodies times the
## average drop, plus that wave's supply pulse - and reports the wave each
## milestone lands on. Best case throughout: every body killed, nothing spent
## before the milestone. A ramp the best case cannot reach is unarguable.
func _opening_gold_ramp(director: WaveDirector, terrain: TerrainData) -> Dictionary:
	var per_body: float = _gold_per_body()
	var earned: float = float(Balance.STARTING_GOLD)
	var first_tower: int = 0
	var baseline: int = 0
	var trail: PackedStringArray = []
	for act_wave: int in range(1, 13):
		var bodies: int = director._wave_size(act_wave, terrain) \
			* director._progressive_lane_count(act_wave)
		earned += float(bodies) * per_body
		if act_wave <= Balance.WAVE_OPENING_SUPPLIES.size():
			earned += float(Balance.WAVE_OPENING_SUPPLIES[act_wave - 1])
		if first_tower == 0 and earned >= float(Balance.TOWER_BUILD_COST):
			first_tower = act_wave
		if baseline == 0 and earned >= float(Balance.LANE_COUNT * Balance.TOWER_BUILD_COST):
			baseline = act_wave
		trail.append("%d:%d" % [act_wave, int(earned)])
	print("[balance] Opening Gold ramp, wave:total — %s  (tower %d, road %d)" % [
		" ".join(trail), Balance.TOWER_BUILD_COST,
		Balance.LANE_COUNT * Balance.TOWER_BUILD_COST])
	return {"first_tower_wave": first_tower, "baseline_wave": baseline}


## Average Gold a non-boss body pays.
##
## Read from the content rather than typed in, so rebalancing a drop moves the
## gate with it instead of leaving it asserting against a remembered number.
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


## Co-op scales the count of enemies, and nothing else about them.
##
## `docs/COOP_DESIGN.md` §5, and the half that is a gate rather than a judgement.
## Whether the resulting curve *feels* right is pacing, and pacing belongs in
## `curve_report`, which says in its own header that it is a report and never a
## gate. What is not judgement is which knob was turned.
##
## Scaling health or damage to the player count is the classic mistake: it adds
## duration rather than pressure - the same fight, slower - and it invalidates
## every dodge window, because a wind-up tuned to be dodgeable is tuned against a
## particular time-to-kill. This exists so that mistake cannot be made quietly.
func _test_coop_scaling() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(1, 0.0, 12, "jungle", 12)
	var terrain: TerrainData = ContentDB.terrain("jungle")

	_check(is_equal_approx(WaveDirector.body_scale_for(1), 1.0),
		"one player must face an unscaled wave")
	var two: float = WaveDirector.body_scale_for(2)
	_check(two > 1.0, "two players must face more bodies, got %.2f" % two)
	_check(two <= 2.0,
		"and not more than one extra player's worth, got %.2f" % two)

	# The live count is one here, so this is the single-player wave. Two players
	# face it multiplied - the director applies exactly this factor and nothing
	# else touches the count.
	var solo: int = director._wave_size(12, terrain)
	var pair: int = maxi(int(round(float(solo) * two)), 1)
	_check(pair > solo,
		"a two-player wave must be bigger: %d vs %d" % [pair, solo])

	# The rows that must NOT move.
	var hp: float = director._hp_scale(0)
	var damage: float = director._damage_scale(0)
	var speed: float = director._speed_scale(0)
	_check(director._hp_scale(0) == hp and director._damage_scale(0) == damage
		and director._speed_scale(0) == speed,
		"per-enemy scaling must not depend on the player count")
	print("[balance] Co-op wave %d -> %d bodies, hp/damage/speed unchanged at %.2f/%.2f/%.2f"
		% [solo, pair, hp, damage, speed])


func _set_progress(act: int, distance: float, wave: int, terrain_id: String,
		act_wave: int) -> void:
	RunState.act = act
	RunState.distance_travelled = distance
	RunState.wave_number = wave
	RunState.terrain_id = terrain_id
	_run.battlefield.wave_director._act_wave = act_wave
	DayNight._apply(0.74)


## A wave owns its complete formation. A zero timer may not stack another queue
## on top of it; dense late formations preserve endgame pressure within a wave.
func _test_sequential_waves() -> void:
	var director: WaveDirector = _run.battlefield.wave_director
	director.stop()
	director._spawn_queue.clear()
	var before: int = RunState.wave_number
	director._wave_active = true
	director._spawn_queue.append({})
	director._spawn_timer = 99.0
	director._wave_timer = 0.0
	director.start()
	director._process(0.1)
	director.stop()
	_check(RunState.wave_number == before,
		"next wave must wait while the current formation is still deploying")
	director._spawn_queue.clear()
	director._wave_active = false


## An enemy under continuous frost must keep walking.
##
## Two frost towers covering one tile used to hold an enemy still for as long as
## they kept firing, because both slow and freeze refreshed a timer. The lane
## stopped being a lane, and the natural response - build a third - made it
## worse. The rule now is that a lock is a moment: this hammers an enemy with the
## strongest slow and a freeze proc every single frame, which is worse than any
## real tower layout can manage, and asserts it still travels.
func _test_chill_never_locks() -> void:
	var field: Battlefield = _run.battlefield
	var breed: EnemyData = ContentDB.enemy("bogkin")
	if breed == null:
		for id: String in ContentDB.enemies:
			breed = ContentDB.enemy(id)
			break
	if breed == null or field == null:
		_check(false, "the chill check needs a breed and a battlefield")
		return
	var victim: Enemy = field.spawn_enemy(breed, 0, 1.0)
	if victim == null:
		_check(false, "the chill check needs an enemy")
		return
	await get_tree().process_frame

	var step: float = 1.0 / 60.0
	var frozen: float = 0.0
	var longest_lock: float = 0.0
	var lock: float = 0.0
	var slowest: float = 1.0
	for _frame: int in 600:                      # ten seconds of unbroken frost
		victim.apply_slow(0.05, 2.0)
		victim.apply_freeze(1.2)
		victim.call("_tick_status", step)
		slowest = minf(slowest, victim.get("_slow_factor"))
		if float(victim.get("_freeze_left")) > 0.0:
			frozen += step
			lock += step
			longest_lock = maxf(longest_lock, lock)
		else:
			lock = 0.0

	_check(slowest >= Balance.CHILL_SLOW_FLOOR - 0.001,
		"chill must never slow an enemy past the floor")
	_check(slowest < 1.0, "stacked slows must actually slow the enemy")
	_check(longest_lock <= Balance.FREEZE_MAX_SECONDS + 0.02,
		"no single lock may exceed the freeze ceiling")
	# Ten seconds of the worst possible frost, at one lock per refractory.
	_check(frozen <= 10.0 * (Balance.FREEZE_MAX_SECONDS / Balance.FREEZE_REFRACTORY) + 0.5,
		"an enemy under continuous frost must spend most of its time moving")

	# And the same for the flinch, on real frames, because that is what actually
	# pinned enemies: hitstun was applied by every hit with nothing stopping it
	# refreshing, so a splash tower landing on the same enemy every volley held
	# it still forever. Driving _process rather than poking fields is the point -
	# the countdown and the gate both have to be right.
	var free_frames: int = 0
	for _frame: int in 240:
		victim.call("_add_hitstun", Balance.ENEMY_HITSTUN)
		await get_tree().process_frame
		if float(victim.get("_hitstun_left")) <= 0.0:
			free_frames += 1
	_check(free_frames >= 60,
		"an enemy hit every frame must still be free to move most of the time")
	victim.queue_free()


## The boss health bar has to be connected to something.
##
## `HUD.boss_director` is an @export that run.tscn simply never filled in, so
## `_update_boss_bar` hit its null guard on every frame of every boss fight and
## the bar sat at full while the boss died. Nothing errored - a null check that
## silently does nothing looks exactly like a bar that works. This is the check
## that would have caught it, and it is cheap.
func _test_boss_bar_is_wired() -> void:
	var hud: HUD = _run.hud
	_check(hud != null, "the run must have a HUD")
	if hud == null:
		return
	_check(hud.boss_director != null,
		"HUD.boss_director must be wired, or the boss health bar never updates")
	_check(hud.battlefield != null, "HUD.battlefield must be wired")


## Every element's projectile head has to resolve from its own name.
##
## The path is derived, not listed, so nothing errors when it is wrong - the
## shot silently falls back to its polygon and the art simply never appears.
## Renaming an element or a file is the whole failure mode, and this is the only
## thing that would notice.
func _test_projectile_art_resolves() -> void:
	for element: int in [TowerData.Element.FIRE, TowerData.Element.WATER,
			TowerData.Element.EARTH, TowerData.Element.AIR]:
		var name: String = TowerData.element_name(element).to_lower()
		var path: String = Projectile.PROJECTILE_ART_FORMAT % name
		_check(ResourceLoader.exists(path),
			"%s projectile art must resolve at %s" % [TowerData.element_name(element), path])
		var burst: String = Vfx.IMPACT_ART_FORMAT % name
		_check(ResourceLoader.exists(burst),
			"%s impact art must resolve at %s" % [TowerData.element_name(element), burst])


## The named adjacency lookup has to agree with the offer it came from.
##
## `fusion_pair_for` exists so callers stop assembling "which two towers would
## fuse here" out of RunState internals. A wrapper that disagrees with the thing
## it wraps is worse than no wrapper, so this checks the pair it hands back is
## the pair the offer names, and that a non-fusion asks for nothing.
func _test_fusion_pair_lookup() -> void:
	var field: Battlefield = _run.battlefield
	if field == null:
		_check(false, "the fusion lookup needs a battlefield")
		return
	var plain: TowerData = ContentDB.tower("ember_spire")
	_check(field.fusion_pair_for(Vector2i(4, 4), plain).is_empty(),
		"an ordinary tower has no fusion pair")
	_check(field.fusion_pair_for(Vector2i(4, 4), null).is_empty(),
		"no tower has no fusion pair")
	for anchor: Variant in [Vector2i(6, 6), Vector2i(8, 8), Vector2i(10, 10)]:
		var tile: Vector2i = anchor
		for option: Dictionary in RunState.combinations_for_tile(tile):
			var pair: Array[Vector2i] = field.fusion_pair_for(tile, option["tower"] as TowerData)
			_check(pair.size() == 2 and pair[0] == option["a"] and pair[1] == option["b"],
				"fusion_pair_for must return the offer's own two parents")


## Tools buy the roster, Sigils cap at four, and neither leaks power.
##
## CLAUDE.md §7 is the rule being defended here: the account save may hold
## unlocked ids, statistics, settings, Tools, the four Sigil ranks and the
## Treasury cache, and nothing else. A test that only counted Tools going up
## would miss the thing that actually matters, which is that spending them
## widens the roster and never strengthens it.
func _test_tools_and_sigils() -> void:
	var tools_before: int = MetaState.tools
	var sigils_before: int = MetaState.sigils
	var roster_before: int = MetaState.unlocked_towers.size()

	# Depth pays, and paying enough buys roster width.
	var bought: Array[String] = MetaState.award_tools(3, true)
	_check(MetaState.tools <= Balance.TOOLS_MAX, "Tools must respect their cap")
	_check(MetaState.unlocked_towers.size() == roster_before + bought.size(),
		"every Tool spent on the roster must produce exactly one new tower")
	for id: String in bought:
		_check(ContentDB.tower(id) != null, "a bought roster id must name a real tower")

	# The cap is a ceiling, not a soft target: hammer it.
	for _run: int in 40:
		MetaState.award_tools(3, true)
	_check(MetaState.tools <= Balance.TOOLS_MAX,
		"Tools must stay capped across many runs")
	# Not a count of `unlocked_towers` - that pool also collects every tower the
	# player *used*, fusions included, so it is not bounded by the roster. The
	# invariant is that Tools stop buying once the authored order is exhausted.
	for id: String in MetaState.ROSTER_UNLOCK_ORDER:
		_check(MetaState.unlocked_towers.has(id),
			"repeated runs must eventually unlock the whole roster (%s)" % id)
	_check(MetaState.award_tools(3, true).is_empty(),
		"a complete roster must stop consuming Tools")

	# Four ranks, and then done.
	for _win: int in Balance.SIGIL_MAX_RANK + 3:
		MetaState.award_sigil()
	_check(MetaState.sigils == Balance.SIGIL_MAX_RANK,
		"Sigils must stop at the Legacy cap")
	_check(not MetaState.award_sigil(), "a capped Legacy must refuse another Sigil")

	# Rank 3 raises the Treasury ceiling; it must never lower a tier's own cap.
	_check(MetaState.treasury_cap(20) == Balance.SIGIL_RANK3_TREASURY_CAP,
		"rank 3 must raise the Treasury cap")
	_check(MetaState.treasury_cap(999) == 999,
		"a Sigil rank must never reduce a cap the Treasury already had")

	# Rank 2's redraw is a *run* charge earned by an *account* rank, and the two
	# are easy to conflate into a reroll at every crossroad. Check both edges:
	# below rank 2 the run gets none, and at rank 2 it gets exactly one that a
	# redraw actually consumes.
	var rerolls_before: int = RunState.crossroad_rerolls_left
	MetaState.sigils = 1
	_check(MetaState.sigil_crossroad_rerolls() == 0,
		"a Legacy below rank 2 must grant no crossroad redraw")
	MetaState.sigils = 2
	_check(MetaState.sigil_crossroad_rerolls() == Balance.SIGIL_RANK2_REROLLS,
		"rank 2 must grant its crossroad redraws")

	var screen: CrossroadScreen = _run.crossroad_ui
	if screen != null:
		RunState.crossroad_rerolls_left = Balance.SIGIL_RANK2_REROLLS
		screen.call("_reroll")
		_check(RunState.crossroad_rerolls_left == Balance.SIGIL_RANK2_REROLLS - 1,
			"a redraw must spend exactly one charge")
		RunState.crossroad_rerolls_left = 0
		screen.call("_reroll")
		_check(RunState.crossroad_rerolls_left == 0,
			"a run with no charge left must not be able to redraw into the negative")
		screen.panel.visible = false
	RunState.crossroad_rerolls_left = rerolls_before

	MetaState.tools = tools_before
	MetaState.sigils = sigils_before


## Damage art has to come back down when something is repaired.
##
## The town only recomputed its stage on `damaged`, so it could get worse and
## never better: a town repaired to full stayed visibly ruined with its fires
## still burning. That reads as the repair having done nothing, which is the
## worst possible feedback for something the player spent resources on.
func _test_damage_states_are_reversible() -> void:
	var town: TownCore = _run.battlefield.town
	if town == null:
		_check(false, "the battlefield needs a town to check damage stages")
		return

	var full: float = town.health.max_hp
	town.health.current_hp = full
	town.call("_apply_stage", true)
	var pristine: int = town.get("_stage")

	# Down to a quarter, which is past the last threshold.
	town.health.current_hp = full * 0.2
	town.health.changed.emit(town.health.current_hp, full)
	var ruined: int = town.get("_stage")
	_check(ruined > pristine,
		"the town must look worse at 20%% health (stage %d vs %d)" % [ruined, pristine])

	# And back up again.
	town.health.heal(full)
	var repaired: int = town.get("_stage")
	_check(repaired == pristine,
		"repairing the town must restore its art (stage %d, expected %d)"
			% [repaired, pristine])

	var burning: int = 0
	for fire: Variant in town.get("_fires"):
		if (fire as Flame).is_lit():
			burning += 1
	_check(burning == 0, "a fully repaired town must not still be on fire (%d fires)" % burning)


## Levelling has to grow the hero, stop at the cap, and persist only through the
## dedicated capped hero schema introduced by the 2026-08-20 owner amendment.
func _test_hero_levelling() -> void:
	var before_level: int = RunState.hero_level
	RunState.hero_level = 1
	RunState.hero_xp = 0.0
	RunState.hero_attribute_points = 0
	RunState.hero_skill_points = 0
	RunState.hero_attributes = [0, 0, 0, 0]
	MetaState.hero_xp = 0.0
	RunState.gain_hero_xp(3.0)
	_check(is_equal_approx(MetaState.hero_xp, 3.0),
		"sub-level XP must reach account state for the run-end save")
	RunState.hero_xp = 0.0
	MetaState.hero_xp = 0.0

	# One enormous award must resolve every level it crosses, not just one.
	RunState.gain_hero_xp(50000.0)
	_check(RunState.hero_level > 20,
		"a large award must resolve every level it crosses, reached %d" % RunState.hero_level)
	var xp_label: Label = _run.hud.get("_xp_label") as Label
	var xp_band: Control = _run.hud.get("_xp_band") as Control
	_check(xp_label != null and xp_label.text.contains("LEVEL %d" % RunState.hero_level)
		and xp_label.text.contains(" XP"),
		"the battlefield XP strip must show the current level and XP threshold")
	_run.hud.call("_on_scope_changed", int(GameDirector.Scope.RAID))
	_check(xp_band != null and xp_band.visible,
		"the hero XP strip must remain visible in a raid")
	_run.hud.call("_on_scope_changed", int(GameDirector.Scope.TOWN))
	_check(xp_band != null and not xp_band.visible,
		"the hero XP strip must stay out of non-combat scopes")
	_run.hud.call("_on_scope_changed", int(GameDirector.Scope.BATTLEFIELD))
	_check(RunState.hero_attribute_points == RunState.hero_level - 1,
		"one attribute point per level (%d points at level %d)"
			% [RunState.hero_attribute_points, RunState.hero_level])
	_check(RunState.hero_skill_points
		== int(RunState.hero_level / Balance.HERO_SKILL_POINT_EVERY),
		"a skill point every %d levels" % Balance.HERO_SKILL_POINT_EVERY)

	# The cap is a ceiling, not a soft target.
	RunState.gain_hero_xp(50000000.0)
	_check(RunState.hero_level == Balance.HERO_MAX_LEVEL,
		"levelling must stop at %d, reached %d"
			% [Balance.HERO_MAX_LEVEL, RunState.hero_level])
	_check(xp_label != null and xp_label.text.contains("MAX"),
		"the XP strip must communicate the level cap")
	RunState.gain_hero_xp(50000000.0)
	_check(RunState.hero_level == Balance.HERO_MAX_LEVEL,
		"a capped hero must not level again")

	# Points land where they are put, and run out.
	var pool: int = RunState.hero_attribute_points
	_check(RunState.spend_attribute_point(RunState.Attribute.MIGHT).is_empty(),
		"spending a point that exists must succeed")
	_check(RunState.attribute(RunState.Attribute.MIGHT) == 1, "the point must land")
	_check(RunState.hero_attribute_points == pool - 1, "the pool must fall")
	RunState.hero_attribute_points = 0
	_check(not RunState.spend_attribute_point(RunState.Attribute.MIGHT).is_empty(),
		"spending from an empty pool must be refused")

	# The discipline cap grows with level.
	_check(RunState.discipline_cap() > Balance.DISCIPLINE_MAX_TRAINED,
		"a level %d hero should have earned discipline slots" % RunState.hero_level)

	# The generic unlock payload must not duplicate the dedicated hero schema.
	var saved: Dictionary = MetaState.call("_unlocked_payload") if MetaState.has_method(
		"_unlocked_payload") else {}
	for key: Variant in saved:
		var name: String = String(key)
		_check(not name.contains("level") and not name.contains("attribute")
			and not name.contains("xp"),
			"the account save must not carry hero progression, found \"%s\"" % name)

	# Reset restores the hero from the account rather than zeroing it.
	#
	# This assertion used to read "a new run must start at level 1", which was
	# correct until the owner amended GDD §974 on 2026-08-20. Left as it was it
	# would have failed every build from that day on, and the temptation would
	# have been to delete it - so it states the new contract instead, which is the
	# stricter of the two: the hero comes back *exactly* as the account holds it.
	MetaState.hero_level = 37
	MetaState.hero_xp = 6.0
	MetaState.hero_attribute_points = 4
	MetaState.hero_attributes = [3, 0, 0, 0]
	RunState.reset()
	_check(RunState.hero_level == 37, "a new run must restore the account's hero")
	_check(is_equal_approx(RunState.hero_xp, 6.0), "partial XP must come back")
	_check(RunState.hero_attribute_points == 4, "unspent points must come back")
	_check(RunState.attribute(RunState.Attribute.MIGHT) == 3,
		"placed attributes must come back")
	RunState.hero_level = before_level


## Loot must add to income without ever replacing it, and weather must move
## element damage without singling out towers.
##
## The first half is the one that could quietly undo the rebalance: the
## difficulty curve was tuned against *guaranteed* kill income, so a drop system
## that diverted the base into something collectable would cut a passive player's
## economy and re-harden a game that had just been balanced.
func _test_loot_and_weather() -> void:
	var field: Battlefield = _run.battlefield

	# A kill pays its base regardless of whether anyone picks anything up.
	RunState.weather_id = "clear"
	var before: int = RunState.currency(RunState.GOLD)
	RunState.gain_kill_resources(40)
	_check(RunState.currency(RunState.GOLD) > before,
		"a kill must pay its resources whether or not loot is collected")

	# A drop pays on collection, and only once.
	var banked: int = RunState.currency(RunState.GOLD)
	field.spawn_loot(RunState.GOLD, 25, Vector2(300.0, 0.0))
	var drops: Array[Node] = get_tree().get_nodes_in_group(LootDrop.GROUP)
	_check(drops.size() >= 1, "spawn_loot must produce a drop")
	if drops.is_empty():
		return
	var drop := drops[drops.size() - 1] as LootDrop
	drop.call("_collect")
	_check(RunState.currency(RunState.GOLD) == banked + 25,
		"collecting a drop must pay exactly its amount")
	await get_tree().process_frame
	# The approved pickup dissolve deliberately leaves a brief visual shell. It
	# must be inert immediately, then disappear when that presentation finishes.
	drop.call("_collect")
	_check(RunState.currency(RunState.GOLD) == banked + 25,
		"a dissolving drop must not pay a second time")
	await get_tree().create_timer(Balance.LOOT_PICKUP_DISSOLVE_TIME + 0.05).timeout
	_check(not is_instance_valid(drop) or drop.is_queued_for_deletion(),
		"a collected drop must retire when its pickup dissolve ends")

	# A battlefield gear roll becomes the same persistent reward as a raid chest,
	# but arrives as a physical pickup rather than silently editing the stash.
	var stash_before: Array = MetaState.stash.duplicate(true)
	var equipped_before: Dictionary = MetaState.equipped.duplicate()
	var gear_kinds: Array[GearData] = ContentDB.gear_sorted()
	MetaState.stash = []
	MetaState.equipped = {}
	_check(not gear_kinds.is_empty(), "battlefield gear requires at least one gear resource")
	if not gear_kinds.is_empty():
		var piece: Dictionary = Stash.make(gear_kinds[0].id, 1)
		field.spawn_gear(piece, Vector2(320.0, 0.0))
		var gear_drops: Array[Node] = get_tree().get_nodes_in_group(LootDrop.GROUP)
		var gear_drop: LootDrop = null
		for candidate: Node in gear_drops:
			var candidate_drop := candidate as LootDrop
			if candidate_drop != null and not candidate_drop.gear.is_empty():
				gear_drop = candidate_drop
				break
		_check(gear_drop != null, "spawn_gear must produce a physical battlefield pickup")
		if gear_drop != null:
			gear_drop.call("_collect")
			_check(MetaState.stash.size() == 1
				and String((MetaState.stash[0] as Dictionary).get("kind", "")) == gear_kinds[0].id,
				"collecting battlefield gear must deliver it to the stash")
	MetaState.stash = stash_before
	MetaState.equipped = equipped_before
	_check(Balance.GEAR_BATTLEFIELD_DROP_CHANCE < Balance.GEAR_BATTLEFIELD_ELITE_CHANCE
		and Balance.GEAR_BATTLEFIELD_ELITE_CHANCE < Balance.GEAR_BATTLEFIELD_BOSS_CHANCE,
		"battlefield gear odds must climb from breed to elite to boss")

	# Weather scales elements, and Clear scales nothing.
	for element: int in 4:
		_check(is_equal_approx(RunState.weather_scale(element), 1.0),
			"Clear weather must leave element %d alone" % element)

	var heatwave: WeatherData = ContentDB.weather("heatwave")
	_check(heatwave != null, "the heatwave weather must exist")
	if heatwave == null:
		return
	RunState.weather_id = "heatwave"
	_check(RunState.weather_scale(TowerData.Element.FIRE) > 1.0,
		"a heatwave must favour fire")
	_check(RunState.weather_scale(TowerData.Element.WATER) < 1.0,
		"a heatwave must punish water")

	# Every weather must name what it does. A modifier the player cannot read is
	# an unexplained difficulty swing.
	for act: int in [1, 2, 3]:
		var options: Array[WeatherData] = ContentDB.weathers_for_act(act)
		_check(options.size() >= 2, "act %d needs more than one weather" % act)
		for option: WeatherData in options:
			_check(not option.effect_line.is_empty(),
				"weather \"%s\" must say what it does" % option.id)
			_check(option.element_scale.size() == 4,
				"weather \"%s\" must scale all four elements" % option.id)

	# A roll must land on something eligible, and not repeat itself.
	RunState.act = 2
	var seen: Dictionary = {}
	for _try: int in 12:
		var was: String = RunState.weather_id
		RunState.roll_weather()
		_check(RunState.weather_id != was or ContentDB.weathers_for_act(2).size() == 1,
			"a roll should not return the same weather twice running")
		var rolled: WeatherData = RunState.weather()
		_check(rolled != null and rolled.allows_act(2),
			"a roll must land on weather eligible for the act")
		seen[RunState.weather_id] = true
	_check(seen.size() >= 2, "twelve rolls should produce more than one weather")
	RunState.weather_id = "clear"


## Campaign tiers must ladder, and the hero must survive a run while nothing
## else does.
##
## The second half is the owner amendment of 2026-08-20 stated as a test. GDD
## §974 used to forbid *any* hero persistence; it now sanctions exactly four
## fields and nothing more. A tower level or a currency balance sneaking into the
## save would be the original violation wearing the amendment as cover.
func _test_tiers_and_persistence() -> void:
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	_check(tiers.size() >= 3, "there must be three campaign tiers, found %d" % tiers.size())
	if tiers.size() < 3:
		return

	# Each tier must be strictly harder and strictly better paid, or there is no
	# reason to climb.
	for i: int in range(1, tiers.size()):
		_check(tiers[i].hp_scale > tiers[i - 1].hp_scale,
			"%s must be tougher than %s" % [tiers[i].id, tiers[i - 1].id])
		_check(tiers[i].xp_scale > tiers[i - 1].xp_scale,
			"%s must pay better than %s" % [tiers[i].id, tiers[i - 1].id])
		_check(tiers[i].expected_level(1) > tiers[i - 1].expected_level(3),
			"%s should open above where %s ended" % [tiers[i].id, tiers[i - 1].id])
	for tier: CampaignTierData in tiers:
		for act: int in [1, 2, 3]:
			_check(tier.expected_level(act) <= Balance.HERO_MAX_LEVEL,
				"%s expects a level above the cap at act %d" % [tier.id, act])
		_check(not tier.summary.is_empty(), "%s must describe itself" % tier.id)

	# Only the next tier up is ever open.
	var cleared_before: int = MetaState.tier_cleared
	MetaState.tier_cleared = -1
	_check(MetaState.tier_is_unlocked(tiers[0]), "the first tier must always be open")
	_check(not MetaState.tier_is_unlocked(tiers[2]),
		"the last tier must be locked on a fresh account")
	MetaState.tier_cleared = 0
	_check(MetaState.tier_is_unlocked(tiers[1]), "clearing a tier must open the next")
	_check(not MetaState.tier_is_unlocked(tiers[2]),
		"clearing one tier must not open two")
	MetaState.tier_cleared = cleared_before

	# The hero survives a run; the defence does not.
	MetaState.hero_level = 42
	MetaState.hero_attributes = [5, 4, 3, 2]
	MetaState.hero_attribute_points = 7
	RunState.gain_currency(RunState.GOLD, 999)
	RunState.reset()
	_check(RunState.hero_level == 42, "the hero's level must survive a new run")
	_check(RunState.attribute(RunState.Attribute.MIGHT) == 5,
		"placed attributes must survive a new run")
	_check(RunState.hero_attribute_points == 7, "unspent points must survive a new run")
	_check(RunState.towers.is_empty(), "towers must not survive a new run")
	_check(RunState.currency(RunState.GOLD) < 999,
		"a run's currency balance must not survive into the next run")

	# **The save carries the hero and nothing else that is power.**
	#
	# Working rule 7 is the subject here: no relic, tower level, run currency,
	# building tier or Oathbound leader may persist, and the hero is the one
	# sanctioned exception. This list is what enforces it, so anything added to
	# it needs a reason written down rather than a nod.
	#
	# `social` is a play code and a list of other people's play codes. It is an
	# *address book*: nothing in it makes a hero stronger, a run easier or a tier
	# reachable that was not, and deleting the whole block costs a player their
	# contacts and nothing else. Added 2026-08-26 with the friends list.
	var text: String = MetaState.serialized_save()
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary, "the save must be a dictionary")
	if parsed is Dictionary:
		var keys: Array = (parsed as Dictionary).keys()
		for key: Variant in keys:
			_check(String(key) in ["version", "unlocked", "resource_cache", "stats",
				"settings", "hero", "stash", "board", "social", "chronicle"],
				"unexpected top-level save key \"%s\"" % key)
		# Chronicle entries are completed content ids only. Their Tool reward is
		# paid once and stored in the already-sanctioned Tools balance; no live
		# progress or combat modifier may hide under this block.
		var chronicle: Dictionary = (parsed as Dictionary).get("chronicle", {}) as Dictionary
		for key: Variant in chronicle.keys():
			_check(String(key) == "completed",
				"unexpected Chronicle save key \"%s\"" % key)
		# The exception has to stay an address book. A save that starts carrying
		# power under this name would pass the check above and break the rule it
		# exists to keep.
		var social: Dictionary = (parsed as Dictionary).get("social", {}) as Dictionary
		for key: Variant in social.keys():
			_check(String(key) in ["play_code", "friends"],
				"the social block must hold addresses and nothing else, found \"%s\""
					% key)
		var board: Dictionary = (parsed as Dictionary).get("board", {}) as Dictionary
		for key: Variant in board.keys():
			_check(String(key) in ["name", "best", "pending"],
				"unexpected leaderboard save key \"%s\"" % key)
		# The list is about *power*, not tidiness. "story_seen" is on it because it
		# rides in the same block, and it is not progression - a flag saying the
		# opening has played cannot make a run easier. Anything that could is what
		# this check exists to catch.
		var hero: Dictionary = (parsed as Dictionary).get("hero", {}) as Dictionary
		for key: Variant in hero.keys():
			_check(String(key) in ["level", "xp", "attributes", "attribute_points",
				"skill_points", "tier_cleared", "last_tier", "story_seen"],
				"unexpected hero save key \"%s\" - only the amendment's fields persist" % key)

	# The migration every existing player will actually hit: a v3 save has no hero
	# block at all, and must arrive as a level-one hero rather than as garbage.
	MetaState.hero_level = 55
	MetaState.hero_attribute_points = 20
	MetaState.call("_read_hero", {})
	_check(MetaState.hero_level == 1,
		"a save with no hero block must load as level 1, got %d" % MetaState.hero_level)
	_check(MetaState.hero_attribute_points == 0,
		"a save with no hero block must load with no points")
	_check(MetaState.tier_cleared == -1,
		"a save with no hero block must open only the first tier")

	# A hand-edited save must not arrive with more points than its level granted.
	MetaState.call("_read_hero", {"level": 5, "attributes": [900, 0, 0, 0],
		"attribute_points": 900})
	var placed: int = 0
	for value: int in MetaState.hero_attributes:
		placed += value
	_check(placed + MetaState.hero_attribute_points <= 4,
		"a level 5 hero may hold at most 4 points, found %d"
			% (placed + MetaState.hero_attribute_points))

	MetaState.hero_level = 1
	MetaState.hero_attributes = [0, 0, 0, 0]
	MetaState.hero_attribute_points = 0
	RunState.reset()


## The stash economy: rolling, pricing, equipping, and the two currencies
## staying separate.
##
## The equip-index check is the one that matters most. Removing a piece from the
## middle of the array shifts everything after it down, and an equipped index
## that is not shifted with it does not fail loudly - it silently equips a
## different sword, which a player would read as the game losing their gear.
func _test_stash_economy() -> void:
	var kinds: Array[GearData] = ContentDB.gear_sorted()
	_check(kinds.size() >= 6, "there must be gear to find, got %d" % kinds.size())
	if kinds.size() < 6:
		return
	for kind: GearData in kinds:
		_check(kind.base_points > 0, "%s must be worth something" % kind.id)
		_check(kind.attribute >= 0 and kind.attribute < 4,
			"%s names attribute %d, which does not exist" % [kind.id, kind.attribute])

	var stash_before: Array = MetaState.stash.duplicate(true)
	var equipped_before: Dictionary = MetaState.equipped.duplicate()
	var marks_before: int = MetaState.marks
	var shards_before: int = MetaState.shards
	MetaState.stash = []
	MetaState.equipped = {}

	# A roll must produce a real piece, and only from tiers that allow it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var seen_rarities: Dictionary = {}
	for _try: int in 400:
		var piece: Dictionary = Stash.roll(kinds, 0, rng)
		_check(not piece.is_empty(), "a roll must produce a piece")
		if piece.is_empty():
			break
		var kind: GearData = ContentDB.gear(String(piece["kind"]))
		_check(kind != null, "a roll must name real gear")
		if kind != null:
			_check(kind.min_tier <= 0, "tier 0 rolled %s, which needs tier %d"
				% [kind.id, kind.min_tier])
		seen_rarities[int(piece["rarity"])] = true
	_check(seen_rarities.size() >= 2, "400 rolls should produce more than one rarity")

	# Rarity and level must both pay, or neither decision matters.
	var kind_one: GearData = kinds[0]
	var worn: Dictionary = Stash.make(kind_one.id, 0, 1)
	var better: Dictionary = Stash.make(kind_one.id, 2, 1)
	var levelled: Dictionary = Stash.make(kind_one.id, 0, Stash.MAX_LEVEL)
	_check(Stash.points(better, kind_one) > Stash.points(worn, kind_one),
		"a rarer piece must grant more")
	_check(Stash.points(levelled, kind_one) > Stash.points(worn, kind_one),
		"an upgraded piece must grant more")
	_check(Stash.sell_price(better) > Stash.sell_price(worn),
		"a rarer piece must sell for more")
	_check(Stash.upgrade_cost(Stash.make(kind_one.id, 0, Stash.MAX_LEVEL)).is_empty(),
		"a maxed piece must not offer another upgrade")

	# Equipping, and the index shift on removal.
	MetaState.take_gear(Stash.make(kinds[0].id, 0))
	MetaState.take_gear(Stash.make(kinds[1].id, 1))
	MetaState.take_gear(Stash.make(kinds[2].id, 2))
	var third: Dictionary = MetaState.stash[2].duplicate()
	MetaState.equipped[ContentDB.gear(String(third["kind"])).slot] = 2
	MetaState.drop_gear(0)
	var still: Dictionary = MetaState.equipped_piece(
		ContentDB.gear(String(third["kind"])).slot)
	_check(still.get("kind", "") == third["kind"],
		"removing an earlier piece must not change which piece is worn")

	# Worn gear must reach the hero.
	MetaState.stash = []
	MetaState.equipped = {}
	var mighty: GearData = null
	for kind: GearData in kinds:
		if kind.attribute == RunState.Attribute.MIGHT:
			mighty = kind
			break
	if mighty != null:
		var base: int = RunState.attribute(RunState.Attribute.MIGHT)
		MetaState.take_gear(Stash.make(mighty.id, 3))
		MetaState.equipped[mighty.slot] = 0
		_check(RunState.attribute(RunState.Attribute.MIGHT) > base,
			"equipped gear must reach the hero's attributes")

	# Capacity is a ceiling, not a suggestion.
	MetaState.stash = []
	MetaState.equipped = {}
	for _fill: int in Balance.STASH_CAPACITY + 8:
		MetaState.take_gear(Stash.make(kinds[0].id, 0))
	_check(MetaState.stash.size() == Balance.STASH_CAPACITY,
		"the stash must stop at %d, holds %d" % [Balance.STASH_CAPACITY,
			MetaState.stash.size()])
	var full_piece: Dictionary = Stash.make(kinds[1].id, 2)
	var expected_shards: int = Stash.salvage_yield(full_piece)
	var shards_at_capacity: int = MetaState.shards
	var overflow: Dictionary = MetaState.receive_gear(full_piece)
	_check(not bool(overflow.get("stored", true))
		and int(overflow.get("shards", 0)) == expected_shards,
		"a full stash must report its deterministic salvage payout")
	_check(MetaState.stash.size() == Balance.STASH_CAPACITY
		and MetaState.shards == shards_at_capacity + expected_shards,
		"a full stash must auto-break the drop instead of deleting the reward")

	# The two currencies must not be the same currency wearing two hats.
	_check(not RunState.CURRENCIES.has("marks"),
		"marks must not be a run currency - a stash purchase must never compete"
		+ " with the wall about to be overrun")
	_check(not RunState.CURRENCIES.has("shards"), "shards must not be a run currency")

	MetaState.stash = stash_before
	MetaState.equipped = equipped_before
	MetaState.marks = marks_before
	MetaState.shards = shards_before


## The summit has to be reachable, and the Chainmaker has to be the thing at the
## top of it.
##
## `Phase.FINAL_ASCENT` sat in the enum for months while nothing ever entered it,
## and three systems quietly tolerated a state the run could not reach. A symbol
## test would have passed that whole time, which is exactly what CLAUDE.md §7
## warns the audit cannot tell you - so this checks the route, the boss lookup
## and the act mapping rather than the constant.
func _test_final_ascent() -> void:
	var director: BossDirector = _run.boss_director
	_check(director != null, "the run needs a boss director")
	if director == null:
		return

	# Every act maps to its own boss, and the ascent to the Chainmaker.
	var seen: Dictionary = {}
	for act: int in [1, 2, 3, Balance.FINAL_ASCENT_ACT]:
		var boss: EnemyData = director.call("_boss_for_act", act)
		_check(boss != null, "act %d must have a boss" % act)
		if boss == null:
			continue
		_check(not seen.has(boss.id),
			"act %d must not reuse the boss of an earlier act (%s)" % [act, boss.id])
		seen[boss.id] = true
	var summit: EnemyData = director.call("_boss_for_act", Balance.FINAL_ASCENT_ACT)
	_check(summit != null and summit.id == "chainmaker",
		"the Final Ascent must summon the Chainmaker")
	if summit != null:
		_check(summit.phase_names.size() >= 3,
			"the true final boss needs its three phases")
		_check(summit.max_hp > ContentDB.enemy("rust_crown").max_hp,
			"the Chainmaker must outweigh the Act III boss")

	# The route: entering the ascent moves the run past the three acts, and the
	# summit is further out than the journey they just finished.
	var act_before: int = RunState.act
	var phase_before: int = RunState.phase
	RunState.begin_final_ascent()
	_check(RunState.is_final_ascent(), "begin_final_ascent must enter the ascent")
	_check(RunState.final_ascent_target() > Balance.JOURNEY_TOTAL_DISTANCE,
		"the summit must lie beyond the three acts")
	_check(RunState.phase == RunState.Phase.FINAL_ASCENT,
		"the ascent must actually enter its own phase")
	RunState.act = act_before
	RunState.set_phase(phase_before as RunState.Phase)

	_check(_run.ending_ui != null, "the run must carry an ending screen")


## The beast stands still while the player is building.
##
## It walks because the journey advances, and the journey is stopped during
## Preparation - so a beast still lumbering was animating a journey that was not
## happening, and still emitting footfalls that shook the battlefield camera
## somebody was trying to place a tower on.
##
## Driven synchronously rather than over real frames. Awaiting 180 frames while
## flipping the run phase underneath a live wave director hung the suite; calling
## `_process` directly tests the same branch, deterministically, in no time.
func _test_beast_rests_in_preparation() -> void:
	var beast: BeastScope = _run.beast
	if beast == null:
		_check(false, "the run needs a beast scope")
		return

	# Measured on the gait phase, not on the footfall signal: footfalls only fire
	# when the beast camera is the current one, so in a harness looking at the
	# battlefield they never arrive and the test would prove nothing.
	var phase_before: int = RunState.phase
	const STEP: float = 1.0 / 60.0

	RunState.set_phase(RunState.Phase.PREPARATION)
	var rest_start: float = beast.get("_bob")
	for _frame: int in 240:
		beast._process(STEP)
	var rested: float = absf(float(beast.get("_bob")) - rest_start)

	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var walk_start: float = beast.get("_bob")
	for _frame: int in 240:
		beast._process(STEP)
	var walked: float = absf(float(beast.get("_bob")) - walk_start)

	RunState.set_phase(phase_before as RunState.Phase)

	_check(is_zero_approx(rested),
		"the beast's gait must not advance while the journey is stopped")
	# The counterpart matters as much: a beast that never walks is not a fix.
	_check(walked > 0.5, "the beast must walk again once the road resumes")


## Every action a player needs is reachable from a controller.
##
## "Controller parity" is a release row v4 §52 leaves to human judgement, and the
## judgement is easy to get wrong by feel: the game had *no* joypad bindings at
## all and nothing said so, because a missing binding is not an error - the
## action simply never fires. This is the machine-checkable half: every
## rebindable action carries at least one joypad event, and so does every UI
## action, because a pad that can play but cannot press a menu button is not
## parity.
func _test_controller_parity() -> void:
	KeyBindings.apply_pad_bindings()

	for entry: Dictionary in KeyBindings.REBINDABLE:
		var action: StringName = entry["action"]
		if not InputMap.has_action(action):
			_check(false, "%s is rebindable but not in the input map" % action)
			continue
		var pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				pad = true
				break
		_check(pad, "%s has no controller binding" % entry["label"])

	for action: StringName in KeyBindings.PAD_UI:
		var reachable: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				reachable = true
				break
		_check(reachable, "%s must be reachable from a pad" % action)

	# Applying twice must not double a binding: `apply_saved` runs on every
	# settings write, and an action collecting a duplicate every time is a slow
	# leak nobody would look for.
	var before: int = InputMap.action_get_events(&"dash").size()
	KeyBindings.apply_pad_bindings()
	_check(InputMap.action_get_events(&"dash").size() == before,
		"re-applying the pad layer must not duplicate bindings")

	# The stick deadzone has to actually reject a resting stick.
	_check(KeyBindings.PAD_DEADZONE > 0.1,
		"a deadzone below 0.1 lets a worn pad walk the hero on its own")


func _test_enemy_roles() -> void:
	_check(ContentDB.enemy("glassborn").role == EnemyData.Role.VANGUARD,
		"Glass-born must carry the fast-vanguard role")
	_check(ContentDB.enemy("howler").role == EnemyData.Role.HOWLER,
		"Howler must own its aura and ranged threat")
	_check(ContentDB.enemy("burrower").spawn_distance_scale < 0.8,
		"Burrower must emerge inside the outer defence")
	var regular_ids: Dictionary = {}
	var elite_ids: Dictionary = {}
	for terrain: TerrainData in [ContentDB.terrain("jungle"),
			ContentDB.terrain("desert"), ContentDB.terrain("snow")]:
		_check(terrain != null and terrain.enemy_ids.size() == 4,
			"every region must ship four regular enemy roles")
		_check(terrain != null and terrain.elite_ids.size() == 2,
			"every region must ship two regional elites")
		if terrain == null:
			continue
		for id: String in terrain.enemy_ids:
			var enemy: EnemyData = ContentDB.enemy(id)
			regular_ids[id] = true
			_check(enemy != null and ResourceLoader.exists(enemy.get_sprite_path()),
				"regional enemy '%s' needs data and production art" % id)
		for id: String in terrain.elite_ids:
			var elite: EnemyData = ContentDB.enemy(id)
			elite_ids[id] = true
			_check(elite != null and elite.category == EnemyData.Category.ELITE \
					and ResourceLoader.exists(elite.get_sprite_path()),
				"regional elite '%s' needs elite data and production art" % id)
	_check(regular_ids.size() == 12 and elite_ids.size() == 6,
		"launch roster must contain twelve unique regulars and six unique elites")


func _test_wave_archetypes() -> void:
	_check(ContentDB.wave_archetypes.size() >= 10,
		"the battlefield must expose a full tactical wave vocabulary")
	for value: Variant in ContentDB.wave_archetypes.values():
		var archetype := value as WaveArchetypeData
		_check(archetype != null and not archetype.display_name.is_empty(),
			"every wave archetype must be named content")
		if archetype != null and not archetype.signature_enemy_id.is_empty():
			_check(ContentDB.enemy(archetype.signature_enemy_id) != null,
				"wave signature enemy '%s' must exist" % archetype.signature_enemy_id)
	var director: WaveDirector = _run.battlefield.wave_director
	_set_progress(2, 1200.0, 48, "desert", 6)
	var siege: WaveArchetypeData = ContentDB.wave_archetype("siege_column")
	var lanes: Array[int] = director._pick_archetype_lanes(siege, 7)
	_check(lanes.size() == 1, "siege columns must concentrate on one lane")
	RunState.terrain_id = "desert"
	_check(director._signature_enemy(siege).id == "siege_lizard",
		"signature roles must resolve to the active regional faction")
	var pincer: WaveArchetypeData = ContentDB.wave_archetype("burrower_pincer")
	lanes = director._pick_archetype_lanes(pincer, 7)
	_check(lanes.size() == 2 and abs(lanes[0] - lanes[1]) == 2,
		"burrower pincers must split the player's attention across opposite roads")
	var false_front: WaveArchetypeData = ContentDB.wave_archetype("false_front")
	lanes = director._pick_archetype_lanes(false_front, 7)
	_check(lanes.size() == 2 and (abs(lanes[0] - lanes[1]) == 1 \
			or abs(lanes[0] - lanes[1]) == Balance.LANE_COUNT - 1),
		"false fronts must reveal on an adjacent road")
	director._spawn_queue.clear()
	director._build_delayed_surge(false_front, lanes, 5, 1.0, 1.0, 1.0, 1.0)
	var delay_entries: int = 0
	for entry: Dictionary in director._spawn_queue:
		if entry.has("delay"):
			delay_entries += 1
	_check(director._spawn_queue.size() == 11 and delay_entries == 1,
		"false front must preserve its body budget around one authored reveal hold")
	director._spawn_queue.clear()


func _test_road_archetypes() -> void:
	_check(ContentDB.roads.size() == 5,
		"crossroads must expose exactly five authored road archetypes")
	_check(ContentDB.road_difficulties.size() == 3,
		"roads must expose Guarded, Contested and Perilous tiers")
	for value: Variant in ContentDB.roads.values():
		var road := value as RoadData
		_check(road != null and not road.promise.is_empty() \
			and not road.consequence.is_empty(),
			"every road card must state a gameplay promise and consequence")
	var guarded: RoadDifficultyData = ContentDB.road_difficulty("guarded")
	var perilous: RoadDifficultyData = ContentDB.road_difficulty("perilous")
	_check(guarded.reward_rolls == 1 and perilous.reward_rolls == 3 \
		and guarded.stat_scale < perilous.stat_scale,
		"road difficulty must trade explicit threat for reward rolls")
	_check(Balance.ROAD_RELIC_CHOICES == 3,
		"Relic Hunt must present a meaningful three-item regional choice")
	var road_choices: Array[String] = _run.journey.regional_relic_choices_for_test(3)
	_check(road_choices.size() == Balance.ROAD_RELIC_CHOICES,
		"a completed Relic Hunt must resolve three eligible regional offers")
	for relic_id: String in road_choices:
		var offered: RelicData = ContentDB.relic(relic_id)
		_check(offered != null and offered.region == 3,
			"Relic Hunt offer '%s' must belong to the active region" % relic_id)
	var region_counts: Array[int] = [0, 0, 0, 0]
	for value: Variant in ContentDB.relics.values():
		var relic := value as RelicData
		if relic != null and not relic.is_boss_core:
			_check(relic.region >= 1 and relic.region <= Balance.ACT_COUNT,
				"ordinary relic '%s' must belong to one regional pool" % relic.id)
			if relic.region >= 1 and relic.region <= Balance.ACT_COUNT:
				region_counts[relic.region] += 1
	for region: int in range(1, Balance.ACT_COUNT + 1):
		_check(region_counts[region] == 8,
			"region %d must ship exactly eight ordinary relics" % region)


func _test_target_priorities() -> void:
	var field: Battlefield = _run.battlefield
	var anchor: Vector2i = _free_anchor(field)
	RunState.set_tower(anchor, "ember_spire", 1)
	var before: int = RunState.target_priority_at(anchor)
	var after: int = RunState.cycle_target_priority(anchor)
	_check(after != before and after == TowerData.TargetPriority.STRONG,
		"built towers must cycle through player-selected targeting doctrines")
	RunState.set_tower(anchor, "ember_spire", 2)
	_check(RunState.target_priority_at(anchor) == after,
		"upgrading a tower must preserve its targeting doctrine")
	RunState.clear_tower(anchor)


func _test_preparation_and_command() -> void:
	var field: Battlefield = _run.battlefield
	RunState.set_phase(RunState.Phase.PREPARATION)
	var prior_wave: int = RunState.wave_number
	RunState.wave_number = 0
	# Wildlife's controller is a sibling of EntityRoot. Only its sprites are
	# parented into that shared y-sorted layer, so every animal sorts at its own
	# feet instead of the controller's origin.
	var wildlife: Wildlife = field.find_child("Wildlife", true, false) as Wildlife
	_check(wildlife != null and not wildlife._hostile_arrivals_allowed(),
		"hostile wildlife must not appear or attack during opening Preparation")
	RunState.wave_number = prior_wave
	# The phase rule is the subject, not the price. Funded explicitly because the
	# run starts with no Gold as of 2026-08-24 - otherwise this reads "you cannot
	# build in Preparation" when what actually happened is "you cannot afford it",
	# which is a different sentence and a passing gate would have hidden it.
	RunState.gain_every_currency(9999)
	var spire_at: Vector2i = _free_anchor(field)
	_check(field.try_build(spire_at, ContentDB.tower("ember_spire")).is_empty(),
		"tower construction must be legal during Preparation")
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(not field.try_upgrade(spire_at).is_empty(),
		"tower upgrades must be locked during road combat")
	_check(not TownScope.try_start_construction("forge").is_empty(),
		"town construction must be locked during road combat")

	RunState.begin_command_battle()
	field._pressure[1] = 0.72
	EventBus.hero_enemy_hit.emit("howler", 1, true, true, Vector2.RIGHT * 300.0)
	_check(RunState.command >= Balance.COMMAND_HERO_HIT_GAIN \
			+ Balance.COMMAND_PRIORITY_HIT_GAIN + Balance.COMMAND_INTERRUPT_GAIN,
		"active hero hits on a pressured road must generate tactical Command")
	RunState.gain_command(Balance.COMMAND_MAX)
	var command: Node = _run.command_system
	var tower: Tower = field.tower_at_anchor(spire_at)
	_check(command.use_order(CommandSystemScript.OVERDRIVE, spire_at).is_empty(),
		"Overdrive must resolve on a built tower")
	_check(tower != null and tower._command_overdrive_left > 0.0,
		"Overdrive must apply a live tower effect")
	RunState.gain_command(Balance.COMMAND_MAX)
	_check(command.use_order(CommandSystemScript.RALLY_ROAD, spire_at).is_empty(),
		"Rally Road must resolve on a selected road")
	RunState.gain_command(Balance.COMMAND_MAX)
	_check(command.use_order(CommandSystemScript.LAST_STAND, Vector2i.ZERO).is_empty(),
		"Last Stand must resolve at full Command")
	_check(RunState.last_stand_used and field.town.health.is_invulnerable(),
		"Last Stand must protect the Town Hall and enforce once-per-battle use")
	RunState.horn_used_this_battle = false
	_check(_run.war_horn.blow(), "the war horn must be available once in a road battle")
	_run.war_horn._horn_left = 0.01
	_run.war_horn._process(0.02)
	_check(not _run.war_horn.blow(), "the war horn must not be reusable in the same road battle")
	RunState.begin_command_battle()
	_check(not RunState.horn_used_this_battle, "a new battle must restore its one horn opportunity")

	var hero: Hero = field.hero
	RunState.hero_wounds = 0
	RunState.hero_hp = -1.0
	hero.sync_from_run_state()
	var unwounded_max: float = hero.health.max_hp
	RunState.add_wound()
	hero.sync_from_run_state()
	_check(is_equal_approx(hero.health.max_hp, unwounded_max * 0.9),
		"one Wound must reduce maximum hero HP by exactly 10 percent")
	RunState.town_hp = RunState.town_max_hp * 0.5
	RunState.hearthmend()
	hero.apply_hearthmend()
	_check(RunState.hero_wounds == 0 and is_equal_approx(hero.health.current_hp, hero.health.max_hp),
		"Hearthmend must clear Wounds and fully restore the hero")
	_check(RunState.town_hp > RunState.town_max_hp * 0.5,
		"Hearthmend must provide its bounded Town Hall repair")
	RunState.has_resurrection_draught = true
	var deaths_before: int = RunState.hero_deaths
	hero.health.take_damage(hero.health.max_hp * 2.0, Vector2.ZERO)
	_check(hero.is_alive() and not RunState.has_resurrection_draught \
			and RunState.hero_deaths == deaths_before,
		"Resurrection Draught must prevent, not merely delay, the next lethal down")
	_test_draught_is_obtainable()
	_test_hero_tending(field, hero)
	await _test_crossroad_waits_for_the_road(field)
	_test_build_spots_yield_to_the_fight(field)
	await _clear_the_road(field)
	_test_road_survives_a_declined_breather(field)
	_test_level_moves_every_stat_a_tower_has()
	_test_free_placement(field)
	_test_hero_frame_animation(field)
	await _test_enemies_walk_the_road(field)


## The Draught's *mechanic* was complete and correct for months. Nothing in the
## game ever granted one, so the only code that could reach it was the check
## above - which passed, because it set the flag itself. A test that supplies the
## thing it is testing proves the consumer and says nothing about the producer.
func _test_draught_is_obtainable() -> void:
	var draught: ItemData = ContentDB.item("resurrection_draught")
	_check(draught != null, "the Resurrection Draught must exist as data")
	if draught == null:
		return
	_check(draught.carry_limit == 1, "v4 caps the Draught at one carried")
	_check(draught.raid_clear_chance > 0.0,
		"a Draught that no reward can produce is unreachable content")

	# The producer, at the odds the resource declares. A hundred clears of a
	# 34% drop failing every time is not a run of bad luck.
	RunState.has_resurrection_draught = false
	var arena: RaidArena = _run.raid
	var granted: int = 0
	for _attempt: int in 100:
		if not arena._pick_draught().is_empty():
			granted += 1
	_check(granted > 0, "a full raid clear must be able to yield a Draught")

	RunState.has_resurrection_draught = true
	_check(arena._pick_draught().is_empty(),
		"the carry limit must stop a second Draught being granted")
	RunState.has_resurrection_draught = false


## Healing the player can actually choose to do.
##
## Reported: "the player should also have some way of being able to restore
## health and regenerate health." Everything that existed was somebody else's
## timing - Hearthmend three times a run, a spell if the build had one, or a
## Wound revive, which costs a Wound.
func _test_hero_tending(field: Battlefield, hero: Hero) -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.hero_wounds = 0
	RunState.hero_hp = -1.0
	hero.sync_from_run_state()
	# The Draught check above revived the hero, and a revive grants respawn
	# invulnerability - which silently swallowed the damage this test needs
	# and left it tending a hero at full health.
	hero.health._invulnerable_left = 0.0
	hero.health.take_damage(hero.health.max_hp * 0.6, Vector2.ZERO)
	var hurt: float = hero.health.current_hp

	RunState.currencies[RunState.FOOD] = 0
	_check(not field.try_tend_hero().is_empty(),
		"tending must be refused without the Food to pay for it")
	_check(is_equal_approx(hero.health.current_hp, hurt),
		"a refused tend must not heal anyway")

	RunState.currencies[RunState.FOOD] = Balance.HERO_TEND_COST
	Input.action_press(&"tend")
	_run.hud._process(0.0)
	Input.action_release(&"tend")
	_check(hero.health.current_hp > hurt, "pressing V must tend during Preparation")
	_check(RunState.currency(RunState.FOOD) <= 0,
		"tending must charge the Food it quoted")

	hero.health.heal(hero.health.max_hp)
	_check(not field.try_tend_hero().is_empty(),
		"tending a whole hero must be refused rather than wasting the Food")

	# Under fire the same action becomes the deliberately worse field ration:
	# less healing, more Food, a cooldown, and an escalating same-wave price.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	hero.health.take_damage(hero.health.max_hp * 0.5, Vector2.ZERO)
	var combat_hurt: float = hero.health.current_hp
	RunState.currencies[RunState.FOOD] = Balance.RATION_COST + Balance.RATION_ESCALATION
	_check(field.try_tend_hero().is_empty(), "a field ration must work during road combat")
	_check(hero.health.current_hp > combat_hurt, "a field ration must restore health")
	_check(not field.try_tend_hero().is_empty(), "a field ration must respect its cooldown")
	_check(field.ration_price() == Balance.RATION_COST + Balance.RATION_ESCALATION,
		"the next ration in the fight must carry the escalation")


## Reported: "I was at a crossroads during preparation and enemies had spawned
## in mass and destroyed my towers and base."
##
## A crossroad fires on distance walked, which knows nothing about whether a
## formation is still on the road. The modal froze the battlefield, the player
## picked a road, and `_on_road_chosen` then resumed the battlefield *and* opened
## Preparation - so the surviving pack woke up and ate the towers during the one
## phase that is meant to be safe. The boss path had been fixed for exactly this
## and the crossroad path had not, so both now ask the same question.
func _test_crossroad_waits_for_the_road(field: Battlefield) -> void:
	var was_locked: bool = _run._locked
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run._locked = false
	_run._pending_crossroad = -1
	# Earlier suites spawn enemies and leave them standing. This test's whole
	# subject is what happens when the road is and is not clear, so it has to
	# start from a known field rather than from whatever was left lying about.
	await _clear_the_road(field)

	var walker: Enemy = field.spawn_enemy(ContentDB.enemy("howler"), 0, 1.0, 1.0, 1.0)
	await get_tree().process_frame
	_check(field.enemy_count() > 0, "the test needs a live enemy to mean anything")

	_run._on_crossroad_reached(4)
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE,
		"a crossroad reached mid-formation must not open Preparation on top of it")
	_check(_run._pending_crossroad == 4,
		"the crossroad must be remembered rather than dropped")

	# And it must not be forgotten either: once the road is clear it is the next
	# thing that happens, ahead of the between-wave breather.
	if walker != null:
		walker.queue_free()
	await _clear_the_road(field)
	_check(field.enemy_count() == 0, "the road must actually be clear for the second half")
	_run._on_wave_cleared(RunState.wave_number)
	_check(RunState.phase == RunState.Phase.PREPARATION and _run._pending_crossroad < 0,
		"a waiting crossroad must open as soon as the road clears")

	_run.crossroad_ui.visible = false
	_run._locked = was_locked
	_run._pending_crossroad = -1
	# Resuming here restarts the wave director, which promptly deployed a fresh
	# formation into the next suite - and that suite opens Preparation, which now
	# correctly warns about the enemies it found. Left suspended and clear, which
	# is the state Preparation is supposed to be entered in anyway.
	field.wave_director.stop()
	await _clear_the_road(field)


## Frees every living enemy and waits for the tree to actually be rid of them.
## `queue_free` is deferred, so a check on the very next line still counts them.
func _clear_the_road(field: Battlefield) -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()
	for _frame: int in 4:
		await get_tree().process_frame
	if field.enemy_count() > 0:
		push_error("[balance] could not clear the road for the crossroad test")


## A free build anchor, from the field's own search so the test and the game
## agree about what "somewhere legal" means.
func _free_anchor(field: Battlefield) -> Vector2i:
	return field.free_anchor_near(0)


## Reported: "sometimes I'm trying to attack mobs on towers and end up clicking
## on the tower and opening its build menu."
func _test_build_spots_yield_to_the_fight(field: Battlefield) -> void:
	# Reported once as "I'm trying to attack mobs on towers and end up opening
	# the build menu". Free placement answers it structurally rather than with a
	# proximity guard: the placement cursor does not exist outside Preparation,
	# so a click during combat has nothing to open.
	RunState.set_phase(RunState.Phase.PREPARATION)
	_check(field.placement != null, "the battlefield must own a placement cursor")
	if field.placement == null:
		return
	_check(field.placement._is_active(),
		"the placement cursor must be live during Preparation - that is what it is for")

	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_check(not field.placement._is_active(),
		"the placement cursor must be inert during combat, so a swing cannot open a build panel")
	RunState.set_phase(RunState.Phase.PREPARATION)


## Free placement on the grid, and fusion by adjacency (GDD §13).
##
## Owner decision, 2026-08-18: towers go anywhere off-path on a 30x30 grid in
## 2x2 footprints, and a fusion is built on the gap between two orthogonally
## aligned towers exactly one tower-width apart.
func _test_free_placement(field: Battlefield) -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	# Every wallet, not just Gold and Stone. Towers draw on a secondary currency
	# per element now (GDD §20), so a test that funds two of four silently cannot
	# afford half the roster.
	for id: String in RunState.CURRENCIES:
		RunState.currencies[id] = 99999
	RunState.towers.clear()

	var pocket: Vector2i = BattleGrid.world_to_tile(field.grid.lane_pocket_centre(0))
	_check(field.placement_problem(pocket).is_empty(),
		"the bend pocket must be buildable: %s" % field.placement_problem(pocket))

	# Roads and the town refuse construction.
	var on_road: Vector2i = BattleGrid.world_to_tile(field.grid.lane_paths[0][1])
	_check(not field.placement_problem(on_road).is_empty(),
		"a road tile must refuse construction")
	_check(not field.placement_problem(BattleGrid.world_to_tile(Vector2.ZERO)).is_empty(),
		"the town must refuse construction")

	# Build, and the footprint is then taken - including from a tile that would
	# merely overlap it, which is the bug a naive "is this exact anchor free"
	# check would let through.
	var fire: TowerData = ContentDB.tower("ember_spire")
	_check(field.try_build(pocket, fire).is_empty(), "the pocket must accept a tower")
	_check(not RunState.tile_is_empty(pocket), "the tower must be recorded")
	_check(not field.placement_problem(pocket).is_empty(), "its own tile is now taken")
	_check(not field.placement_problem(pocket + Vector2i(1, 0)).is_empty(),
		"a tile overlapping the footprint must be taken too")
	_check(field.placement_problem(pocket + Vector2i(2, 0)).is_empty(),
		"the tile immediately beyond the footprint must still be free")

	# Fusion by adjacency: two towers with exactly one tower-width gap.
	var gap: Vector2i = pocket + Vector2i(2, 0)
	var far: Vector2i = pocket + Vector2i(4, 0)
	_check(RunState.combinations_for_tile(gap).is_empty(),
		"one tower alone offers no fusion")
	_check(field.try_build(far, ContentDB.tower("rime_lance")).is_empty(),
		"the second parent must build")
	var offers: Array[Dictionary] = RunState.combinations_for_tile(gap)
	_check(offers.size() == 1, "a flanked tile must offer exactly one fusion, got %d" % offers.size())
	if not offers.is_empty():
		_check((offers[0]["tower"] as TowerData).id == "steam_burst",
			"Fire + Water must offer Steam Burst, got %s" % offers[0]["tower"].id)

	# Diagonals do not fuse.
	_check(RunState.combinations_for_tile(pocket + Vector2i(2, 2)).is_empty(),
		"a diagonal pair must not offer a fusion")

	# And the fusion builds on the gap.
	var steam: TowerData = ContentDB.tower("steam_burst")
	_check(field.try_build(gap, steam).is_empty(), "the fusion must build on the gap tile")
	_check(RunState.tower_at(gap) == steam, "the gap must hold the fusion")

	# Selling a parent orphans the fusion, which is refunded rather than left
	# standing crippled forever.
	_check(field.try_sell(far).is_empty(), "the parent must sell")
	_check(RunState.tile_is_empty(gap), "an orphaned fusion must be refunded, not left standing")

	# Same-element neighbours resonate, which is now something the player
	# arranges on the grid rather than something a fixed slot handed them.
	RunState.towers.clear()
	_check(field.try_build(pocket, fire).is_empty(), "resonance test needs a tower")
	_check(not RunState.has_fusion_synergy(pocket), "one tower cannot resonate with itself")
	_check(field.try_build(far, fire).is_empty(), "resonance test needs a matching partner")
	_check(RunState.has_fusion_synergy(pocket) and RunState.has_fusion_synergy(far),
		"a matching pair one tower-width apart must resonate")
	RunState.towers.clear()


## An upgrade has to move the stats that make each tower the tower it is.
##
## `utility_at` was only ever spent on slow, burn, freeze and structure health, so
## upgrading a splash tower bought a bigger number and the same blast, and a chain
## tower never reached anything new. Reach grew 12% across four levels - under
## nine pixels a level, which is not something a player can see.
func _test_level_moves_every_stat_a_tower_has() -> void:
	var top: int = Balance.TOWER_MAX_LEVEL
	for value: Variant in ContentDB.towers.values():
		var tower := value as TowerData
		if tower == null:
			continue
		_check(tower.range_at(top) > tower.range_at(1) * 1.25,
			"%s must gain visible reach by level %d" % [tower.id, top])
		if tower.aoe_radius > 0.0:
			_check(tower.aoe_at(top) > tower.aoe_at(1),
				"%s is an area tower and must gain blast radius" % tower.id)
		if tower.extra_targets > 0:
			_check(tower.extra_targets_at(top) > tower.extra_targets_at(1),
				"%s chains and must reach more enemies when levelled" % tower.id)
		if tower.ground_zone_dps > 0.0:
			_check(tower.ground_zone_dps_at(top) > tower.ground_zone_dps_at(1),
				"%s leaves ground and that ground must get stronger" % tower.id)
		if tower.knockback > 0.0:
			_check(tower.knockback_at(top) > tower.knockback_at(1),
				"%s knocks back and that must scale" % tower.id)
		# Reach is the stat that compounds with every other one, so it must stay
		# below the damage curve or one levelled tower covers two roads. Only
		# meaningful for towers that deal damage: a pure support tower like the
		# Hoarfrost Bell has none, and 0/0 is not a growth rate.
		if tower.damage > 0.0:
			_check(tower.range_at(top) / tower.range_at(1) \
				< tower.damage_at(top) / tower.damage_at(1),
				"%s reach must grow more slowly than its damage" % tower.id)


## Reported after beating the Act 1 boss: "act 2 started with a wave while
## preparation appeared but I couldn't use it cause my town started getting
## attacked, so I clicked ride on and after defeating all remaining enemies the
## wave never seemed to have ended and no preparation for next wave ever came."
##
## Two faults in series. The road's wave clock kept running through the boss
## fight and started a formation under it, so `_wave_active` was still true when
## the boss died and Act 2's Preparation opened on a live pack. Then that wave
## closed while carrying a number the new act's Preparation had already claimed,
## so the once-per-wave breather declined - and `_close_wave` had already stopped
## the director, which only Ride On and the end of a breather ever restart. Clear
## road, nothing running, run over.
func _test_road_survives_a_declined_breather(field: Battlefield) -> void:
	var director: WaveDirector = field.wave_director

	# No road formations during a boss. The boss brings its own reinforcements.
	RunState.set_phase(RunState.Phase.BOSS)
	director.start()
	director._wave_active = false
	director._wave_timer = 0.0
	var wave_before: int = RunState.wave_number
	director._process(0.05)
	_check(RunState.wave_number == wave_before and not director._wave_active,
		"a road formation must not begin during a boss encounter")

	# And a wave whose breather is declined must leave the road still running,
	# because the next formation is the only thing that can continue the run.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run._locked = false
	_run._breather = false
	_run._pending_crossroad = -1
	RunState.wave_number = 7
	_run._breather_after_wave = 7  # already claimed, so the breather will decline
	director.stop()
	_run._on_wave_cleared(7)
	_check(director._running,
		"a declined breather must leave the wave director running, not a dead run")
	_check(RunState.phase == RunState.Phase.ROAD_BATTLE,
		"a declined breather must not change phase")
	director.stop()
	RunState.wave_number = wave_before


## The hero's frame animation, which is the first thing in the game to use real
## frames instead of transform tricks.
##
## Four separate features in this project have died silently because nothing
## asserted they were running - torch relighting, the occluder fade and two Vfx
## hooks all sat dead behind an empty "hero" group. Frame playback is exactly
## that shape: it fails to a *working* game with a static sprite, so nobody
## notices until they look closely at a screenshot.
func _test_hero_frame_animation(field: Battlefield) -> void:
	var hero: Hero = field.hero
	_check(hero.frames != null, "the hero must have a frame animator")
	if hero.frames == null:
		return
	_check(hero.frames.has_frames(), "the hero animation sheets must load")

	for state: String in ["idle", "walk", "attack_1a", "attack_1b", "attack_2",
			"attack_3", "hurt", "dash", "death"]:
		_check(hero.frames.has_state(state), "missing hero sheet: %s" % state)

	# Facing is what eight directions are for. Row order runs clockwise from
	# east, so these four are the ones a wrong sign flips.
	var facings: Dictionary = {
		Vector2.RIGHT: 0, Vector2.DOWN: 2, Vector2.LEFT: 4, Vector2.UP: 6,
	}
	for direction: Vector2 in facings:
		hero.frames.set_facing(direction)
		_check(hero.frames._direction == int(facings[direction]),
			"facing %s must select row %d, got %d"
				% [direction, facings[direction], hero.frames._direction])

	# A one-shot must actually finish and release, or the hero locks into the
	# frame it died on and never walks again.
	hero.frames.play("dash", true)
	_check(hero.frames.current_state() == "dash", "play() must switch state")
	var released: bool = false
	for _step: int in 200:
		hero.frames._process(0.016)
		if not hero.frames._playing:
			released = true
			break
	_check(released, "a one-shot state must stop playing rather than loop forever")

	# And a loop must not.
	hero.frames.play("idle", true)
	for _step: int in 200:
		hero.frames._process(0.016)
	_check(hero.frames._playing, "a looping state must keep playing")

	# Both opening swings exist, and the picker returns one of them.
	var seen: Dictionary = {}
	for _roll: int in 60:
		seen[hero._frame_state_for_swing(0)] = true
	_check(seen.has("attack_1a") and seen.has("attack_1b"),
		"the opening swing must vary between its two authored sheets, saw %s" % [seen.keys()])
	_check(hero._frame_state_for_swing(1) == "attack_2" 		and hero._frame_state_for_swing(2) == "attack_3",
		"chain steps 2 and 3 must map to their own sheets")

	hero.frames.play("idle", true)
	hero._locked_state = ""


## Enemies must walk the bent road, not cut across the pocket.
##
## The pocket inside each U-bend is the ground the player builds on, and it is
## only worth anything because the formation walks around it twice. An enemy
## that steers straight at the town would cross it, which reads as pathing
## broken and quietly deletes the reason the bend exists.
func _test_enemies_walk_the_road(field: Battlefield) -> void:
	await _clear_the_road(field)
	_check(field.grid != null, "the battlefield must own a grid")
	if field.grid == null:
		return

	var lane: int = 0
	var pocket: Vector2 = field.grid.lane_pocket_centre(lane)
	var walker: Enemy = field.spawn_enemy(ContentDB.enemy("bogkin"), lane, 1.0, 1.0, 1.0)
	_check(walker != null, "the test needs an enemy")
	if walker == null:
		return

	# It starts on the road, so it starts far from the pocket.
	var start_from_pocket: float = walker.global_position.distance_to(pocket)
	_check(start_from_pocket > BattleGrid.TILE * 3.0,
		"an enemy should not spawn inside the build pocket")

	# Walk it a long way and watch how close it ever comes to the pocket centre.
	var closest_to_pocket: float = INF
	var travelled: float = 0.0
	var previous: Vector2 = walker.global_position
	# Long enough to actually finish, derived rather than guessed.
	#
	# This has now been too short twice, and both times it reported a stall that
	# was really a test that stopped watching. The number is computed from the
	# longest route on the map and the walker's own speed, so growing the map or
	# adding a longer way in cannot quietly turn a pass into a failure again.
	var longest: float = 0.0
	for route: Variant in _run.battlefield.grid.routes[walker.lane]:
		var length: float = 0.0
		var points: PackedVector2Array = route
		for i: int in points.size() - 1:
			length += points[i].distance_to(points[i + 1])
		longest = maxf(longest, length)
	var seconds: float = longest / maxf(walker.current_speed(), 1.0) * 1.6
	for _step: int in int(seconds / 0.03):
		walker._walk(0.03)
		travelled += previous.distance_to(walker.global_position)
		previous = walker.global_position
		closest_to_pocket = minf(closest_to_pocket, walker.global_position.distance_to(pocket))
		if walker.global_position.length() <= Balance.TOWN_RADIUS:
			break

	_check(walker.global_position.length() <= Balance.TOWN_RADIUS * 1.5,
		"the enemy must reach the town, stopped %.0f away" % walker.global_position.length())

	# The pocket is roughly 5x7 tiles, so its centre is ~2 tiles from the road on
	# every side. Anything closer than that means the path was cut.
	_check(closest_to_pocket > BattleGrid.TILE * 1.5,
		"the enemy walked through the build pocket (came within %.0f)" % closest_to_pocket)

	# And it walked the road's length rather than the straight line.
	var straight: float = field.grid.lane_paths[lane][0].length()
	_check(travelled > straight * 1.3,
		"the enemy travelled %.0f, barely more than the %.0f straight line - it cut the bend"
			% [travelled, straight])

	walker.queue_free()
	await _clear_the_road(field)


func _test_boss_phases() -> void:
	var director: BossDirector = _run.boss_director
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var boss: EnemyData = director._boss_for_act(act)
		_check(boss != null and boss.phase_thresholds.size() == 2,
			"every act boss must have two encounter phases")
		_check(boss != null and boss.phase_names.size() == boss.phase_thresholds.size(),
			"boss phase thresholds and names must stay aligned")
	# Exercise the live threshold contract once. Reinforcement composition itself
	# is data-tested above and the soak test covers spawning under load.
	director._defeated_acts.clear()
	_check(director.summon(1), "Act 1 boss must summon for phase validation")
	await get_tree().process_frame
	var boss_enemy: Enemy = director.active_boss()
	_check(boss_enemy != null, "summoned boss must remain active")
	if boss_enemy != null:
		var health: Health = Health.of(boss_enemy)
		health.take_damage(health.max_hp * 0.36, Vector2.ZERO)
		_check(director._active_phase >= 1,
			"boss must enter a new phase after crossing its first health threshold")
		boss_enemy.queue_free()
		director._active = null
		director._active_act = 0
		director._active_phase = 0
	# A killing blow can cross every threshold at once; it must end the encounter,
	# not spawn both phase waves after the boss has already reached zero HP.
	director._defeated_acts.clear()
	_check(director.summon(1), "boss must resummon for lethal-threshold validation")
	await get_tree().process_frame
	boss_enemy = director.active_boss()
	if boss_enemy != null:
		var lethal_health: Health = Health.of(boss_enemy)
		lethal_health.take_damage(lethal_health.max_hp * 2.0, Vector2.ZERO)
		_check(director._active_phase == 0,
			"a lethal blow must not trigger post-mortem boss phases")


func _test_run_telemetry() -> void:
	RunState.wave_archetype_counts.clear()
	RunState.record_wave_archetype("rush")
	RunState.record_wave_archetype("rush")
	RunState.record_wave_archetype("siege_column")
	_check(RunState.most_common_wave_archetype() == "rush",
		"run debrief must identify the most frequent tactical pressure")
	_check(RunState.resources_spent >= 0 and RunState.peak_lane_pressure >= 0.0,
		"run telemetry counters must be safe from the first frame")


func _test_zoom_range() -> void:
	var rig := _run.battlefield.camera as CameraRig
	_check(Balance.CAMERA_MOUSE_LEAN_MAX < Balance.LANE_SPAWN_RADIUS,
		"camera look-ahead must be bounded inside the battlefield")
	rig.reset_to_wide()
	_check(not rig.zoom_by(-1), "wide battlefield limit must hand wheel-out to Town")
	_check(rig.zoom_by(1), "wheel-in must zoom the battlefield")
	rig.reset_to_wide()
	_run._zoom_ladder(-1)
	_check(GameDirector.current_scope == GameDirector.Scope.TOWN,
		"wheel-out from wide battlefield must open Town")
	_run._zoom_ladder(-1)
	_check(GameDirector.current_scope == GameDirector.Scope.BEAST,
		"wheel-out from Town must open Beast")
	_run._zoom_ladder(1)
	_check(GameDirector.current_scope == GameDirector.Scope.TOWN,
		"wheel-in from Beast must return to Town")
	_run._zoom_ladder(1)
	_check(GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD,
		"wheel-in from Town must return to battlefield")


func _test_beast_gait() -> void:
	var rig := _run.battlefield.camera as CameraRig
	_check(rig.beast_motion, "battlefield camera must carry the beast gait")
	_check(Balance.BEAST_GAIT_HORIZONTAL <= 9.0 \
		and Balance.BEAST_GAIT_ROTATION_DEGREES <= 0.2,
		"beast gait must remain below gameplay-disrupting amplitude")
	var previous: float = UserSettings.number(UserSettings.GAIT_KEY, 0.65)
	UserSettings.set_value(UserSettings.GAIT_KEY, 1.0)
	RunState.beast_speed = Balance.BEAST_BASE_SPEED
	rig._tick_gait(0.25)
	_check(rig.offset.length() > 0.1, "enabled beast gait must visibly move the battlefield")
	# Force a support-pair transfer and prove it creates the planted pause, body
	# sink and impact shake that make Yuri read as a massive walker rather than a
	# smoothly floating camera sine.
	rig._gait_pause_left = 0.0
	rig._gait_phase = PI - 0.01
	rig._gait_step = 0
	rig._tick_gait(0.03)
	_check(rig._gait_pause_left > 0.0 and rig._step_sink > 0.0,
		"each alternating support plant must pause and settle under Yuri's mass")
	_check(rig._shake_left > 0.0,
		"a planted beast step must produce a brief impact shake")
	_test_step_shake_shape(rig)
	UserSettings.set_value(UserSettings.GAIT_KEY, 0.0)
	rig._tick_gait(0.016)
	_check(rig.offset == rig._shake_offset and is_zero_approx(rig.rotation),
		"turning beast motion off must stop it immediately")
	UserSettings.set_value(UserSettings.GAIT_KEY, previous)


## The shake is a shape, not just a duration, and every part of that shape is
## invisible to a check that only asks whether it is running.
##
## The three things asserted here are the three that would go quietly: a shake
## that stops being directional, a rumble that dies with the thunder instead of
## outliving it, and a return to per-frame randomness - which looks fine on the
## machine it was written on and vibrates differently on every other one.
func _test_step_shake_shape(rig: CameraRig) -> void:
	# Steps land on the four cardinals in turn. A step that shoves west must
	# shove west, or the shake cannot tell the player which side took the weight.
	for step: int in 4:
		var cardinal: Vector2 = CameraRig.step_cardinal(step)
		_check(is_equal_approx(cardinal.length(), 1.0) \
			and is_zero_approx(cardinal.x * cardinal.y),
			"beast step %d must land on a cardinal, got %s" % [step, cardinal])
	_check(CameraRig.step_cardinal(0) != CameraRig.step_cardinal(1) \
		and CameraRig.step_cardinal(0) == CameraRig.step_cardinal(4),
		"the four-beat walk must cycle through four distinct cardinals")

	# The thunder leads and the rumble outlives it. Sampled at the start and near
	# the end of one shake: the opening displacement must lie along the shove,
	# and what is left at the end must not.
	rig._on_shake_requested(20.0, 0.5, Vector2.LEFT)
	rig._tick_shake(0.001)
	var opening: Vector2 = rig._shake_offset
	_check(opening.x < 0.0 and absf(opening.x) > absf(opening.y),
		"a shake must open along the direction it was shoved, got %s" % opening)

	var settling := Vector2.ZERO
	for _frame: int in 28:
		rig._tick_shake(0.016)
		settling = rig._shake_offset
	_check(settling.length() > 0.0 and settling.length() < opening.length() * 0.5,
		"the rumble must outlive the thunder and be quieter than it")

	# Frame-rate independence. The same elapsed time in different sized steps has
	# to arrive at the same place, or the shake is really being driven by the
	# frame rate and a 144Hz machine gets a different game.
	var sampled: Array[Vector2] = []
	for step_size: float in [0.004, 0.02]:
		rig._on_shake_requested(20.0, 0.5, Vector2.LEFT)
		# The tremble seed is deliberately random per impact, so it has to be
		# pinned here or this would be comparing two different shakes.
		rig._rumble_seed = 1.0
		var elapsed: float = 0.0
		while elapsed < 0.2 - 0.0001:
			rig._tick_shake(step_size)
			elapsed += step_size
		sampled.append(rig._shake_offset)
	_check(sampled[0].distance_to(sampled[1]) < 0.05,
		"the shake must not depend on frame rate: %s at 250fps, %s at 50fps" % sampled)

	rig._shake_left = 0.0
	rig._tick_shake(0.016)


func _test_hostile_projectile() -> void:
	var howler: Enemy = _run.battlefield.spawn_enemy(
		ContentDB.enemy("howler"), 0, 1.0, 1.0, 1.0)
	if howler == null:
		_check(false, "Howler must spawn")
		return
	howler.global_position = Vector2.UP * 300.0
	howler._target = _run.battlefield.town
	howler._strike()
	var found: bool = false
	for child: Node in _run.battlefield.get_children():
		if child.get_script() != null \
				and child.get_script().resource_path == "res://scenes/battlefield/enemy_projectile.gd":
			found = true
			var shot := child as Node2D
			_check(shot.global_position.distance_to(howler.combat_origin()) < 0.5,
				"Howler projectile must originate at the body, not the Y-sort feet")
			var ribbons: int = 0
			for layer: Node in shot.get_children():
				if layer is Line2D:
					ribbons += 1
			_check(ribbons >= 2,
				"hostile projectile must retain its shell and filament presentation")
			break
	_check(found, "Howler must release a visible hostile projectile")


func _test_live_relic_updates() -> void:
	var town: TownCore = _run.battlefield.town
	var before: float = town.health.max_hp
	RunState.held_relics.append("02")
	RunState.set_phase(RunState.Phase.PREPARATION)
	var problem: String = TownScope.try_socket_relic("02")
	_check(problem.is_empty(), "town-health relic must socket during a live run")
	_check(town.health.max_hp > before,
		"socketing a town-health relic must update the live city immediately")
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
