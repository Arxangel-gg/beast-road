extends Node

## Guards the bugs fixed on 2026-08-24, so they stay fixed.
##
##   godot --headless --path game res://tools/regression_check.tscn
##
## Each of these was reported by the owner playing the game, and each was a
## quiet failure rather than a crash: an enemy facing the wrong way, a readout
## describing a wave that had moved on, a pack that outlived the act that
## summoned it, a control eating taps on the front door. Nothing errored. That
## is exactly the class of bug a harness has to hold, because the next person to
## touch the code will not know to look.
##
## Deliberately not one test per fix where a fix has a shared cause. The touch
## rows below are two symptoms of one thing - a release that never arrived -
## and they are checked as that.

## Fixed, so every run of this gate rolls the same game. Any value would do.
const SEED: int = 141421356

var _failures: int = 0
var _run: Run = null


func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	# Seeded, so a failure here is reproducible rather than a thing that happened
	# once. Nothing below depends on a roll - enemies are spawned and positioned
	# explicitly - but `spawn_enemy` still draws from the combat stream for its
	# lane offset, and a gate nobody can re-run identically is a gate that gets
	# re-run until it passes. See `breather_check` for what that costs.
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame

	_test_lane_is_read_from_position()
	_test_starting_capital()
	_test_loot_reads_at_range()
	await _test_enemy_faces_its_travel()
	await _test_boss_summons_leave_with_the_boss()
	await _test_weather_can_be_seen()
	await _test_the_field_is_inhabited()
	_test_touch_release_always_lands()
	_test_touch_controls_belong_to_the_run()

	# Order matters, and this had it backwards. The run leaves the tree *first*,
	# then the audio autoloads are silenced, then the tree is given enough frames
	# to actually collect everything before quitting. Stopping the music before
	# freeing the battlefield left the jungle music and ambience streams alive,
	# and quitting four frames later reported eight leaked ObjectDB instances on
	# an otherwise passing check - which fails the guard workflow, since it treats
	# any WARNING line as a failure.
	#
	# `breather_check._bail` carries the same sequence and the same comment. It
	# was right and this was written without reading it.
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[regression] PASS - facing, threat lane, boss summons, loot scale, "
			+ "weather, touch ownership, wildlife")
	get_tree().quit(_failures)


## The threat readout must describe where enemies *are*, not where they entered.
##
## `enemy.lane` is written once at spawn. An enemy that breaks off the road to
## chase the hero can end up bearing on another side of the town entirely, and
## the rosette was still crediting the road it came in by.
func _test_lane_is_read_from_position() -> void:
	var span: float = Balance.LANE_SPAWN_RADIUS
	for lane: int in Balance.LANE_COUNT:
		var out: Vector2 = BattleGrid.lane_vector(lane) * span
		_check(BattleGrid.lane_at(out) == lane,
			"a point straight out along lane %d must read as lane %d" % [lane, lane])

	# The actual bug, expressed as a test: something that entered by one lane and
	# walked into another lane's quarter belongs to the quarter it is standing in.
	var north: Vector2 = BattleGrid.lane_vector(0) * span
	var east: Vector2 = BattleGrid.lane_vector(1) * span
	_check(BattleGrid.lane_at(north) != BattleGrid.lane_at(east),
		"opposite quarters must not collapse to one lane")
	_check(BattleGrid.lane_at(Vector2.ZERO) >= 0
		and BattleGrid.lane_at(Vector2.ZERO) < Balance.LANE_COUNT,
		"the town's own centre must still answer with a legal lane")


## The run starts with no build capital (GDD §448, amended 2026-08-24).
##
## Here as well as in `balance_test`, because this one is cheap and the failure
## is silent: a reinstated starting cache would not error, it would just quietly
## delete the design.
func _test_starting_capital() -> void:
	_check(RunState.currency(RunState.GOLD) == 0,
		"the run must start with no Gold, got %d" % RunState.currency(RunState.GOLD))
	var cheapest: int = -1
	for value: Variant in ContentDB.towers.values():
		var tower := value as TowerData
		if tower == null:
			continue
		var gold: int = int(tower.build_cost_table().get(RunState.GOLD, 0))
		if gold > 0 and (cheapest < 0 or gold < cheapest):
			cheapest = gold
	_check(cheapest > 0, "every tower must carry a Gold price for a zero-Gold start to mean anything")
	_check(not RunState.can_afford_cost({RunState.GOLD: cheapest}),
		"no tower may be affordable on the opening frame")


## A pickup has to be findable, and the rule has to agree with the art.
##
## Raised twice by the owner. The collect radius must not be smaller than the
## sprite, or the hero stands on a coin without taking it.
func _test_loot_reads_at_range() -> void:
	_check(Balance.LOOT_COLLECT_RANGE >= Balance.LOOT_ICON_SIZE * 0.5,
		"the collect radius must reach the edge of the drop it is collecting: %.0f vs %.0f" % [
			Balance.LOOT_COLLECT_RANGE, Balance.LOOT_ICON_SIZE * 0.5])
	_check(Balance.GEAR_DROP_ICON_SIZE > Balance.LOOT_ICON_SIZE,
		"gear must stay the more prominent drop")
	_check(Balance.LOOT_GLOW_SIZE > Balance.LOOT_ICON_SIZE,
		"the pool of light must be wider than the thing it is lighting")
	# The screen-pixel floor, which is the number the complaint was actually
	# about. Anything under about 20 px on a 1080p frame is not a reward.
	var on_screen: float = Balance.LOOT_ICON_SIZE * Balance.CAMERA_ZOOM_BATTLEFIELD_MIN
	_check(on_screen >= 20.0,
		"a drop must clear 20 screen px at the widest zoom, got %.1f" % on_screen)


## A walking enemy faces the way it walks; a fighting one faces its victim.
##
## The bug: facing asked about the target first, so an enemy that had acquired
## something walked the rest of a bend backwards.
func _test_enemy_faces_its_travel() -> void:
	var field: Battlefield = _run.battlefield
	var data: EnemyData = ContentDB.enemy("bogkin")
	if data == null or field == null:
		_check(false, "the harness needs a battlefield and a breed to test facing")
		return
	var enemy: Enemy = field.spawn_enemy(data, 0, 1.0)
	if enemy == null:
		_check(false, "spawn_enemy must return the enemy it spawned")
		return
	await get_tree().process_frame

	# Walking left. No target, so this is the plain motion case.
	enemy._state = Enemy.State.WALKING
	enemy._target = null
	enemy._motion = Vector2(-Balance.FACING_DEADZONE * 4.0, 0.0)
	enemy._update_sprite()
	_check(enemy.sprite.flip_h, "an enemy walking left must face left")

	enemy._motion = Vector2(Balance.FACING_DEADZONE * 4.0, 0.0)
	enemy._update_sprite()
	_check(not enemy.sprite.flip_h, "an enemy walking right must face right")

	# The regression itself: still walking right, but locked onto something to
	# the left. Motion has to win, or the enemy moonwalks down the road.
	var victim: Enemy = field.spawn_enemy(data, 0, 1.0)
	if victim != null:
		victim.global_position = enemy.global_position + Vector2(-900.0, 0.0)
		enemy._target = victim
		enemy._state = Enemy.State.WALKING
		enemy._motion = Vector2(Balance.FACING_DEADZONE * 4.0, 0.0)
		enemy._update_sprite()
		_check(not enemy.sprite.flip_h,
			"a walking enemy must face its travel, not a target behind it")

		# Stopped to swing: now the target is the right answer, because only
		# WALKING moves under its own power.
		enemy._state = Enemy.State.WINDUP
		enemy._motion = Vector2.ZERO
		enemy._update_sprite()
		_check(enemy.sprite.flip_h, "an attacking enemy must face what it is hitting")
		victim.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


## A boss's pack must not outlive the act the boss ended.
##
## And must not pay out when it goes: rushing the boss and ignoring its adds
## would otherwise be the most profitable way to fight one.
func _test_boss_summons_leave_with_the_boss() -> void:
	var field: Battlefield = _run.battlefield
	var data: EnemyData = ContentDB.enemy("bogkin")
	if data == null or field == null:
		_check(false, "the harness needs a battlefield and a breed to test summons")
		return

	var summoned: Array[Enemy] = []
	for _i: int in 3:
		var minion: Enemy = field.spawn_enemy(data, 1, 1.0)
		if minion != null:
			minion.add_to_group(Enemy.SUMMON_GROUP)
			summoned.append(minion)
	await get_tree().process_frame
	_check(summoned.size() == 3, "the harness must have three summons to dismiss")

	var kills_before: int = RunState.enemies_killed
	var gold_before: int = RunState.currency(RunState.GOLD)
	var xp_before: float = RunState.hero_xp

	for minion: Enemy in summoned:
		minion.dismiss()
	await get_tree().process_frame

	for minion: Enemy in summoned:
		_check(minion.is_dying(), "a dismissed summon must be leaving the field")
	_check(RunState.enemies_killed == kills_before,
		"dismissing a summon must not count as a kill")
	_check(RunState.currency(RunState.GOLD) == gold_before,
		"dismissing a summon must not pay resources")
	_check(is_equal_approx(RunState.hero_xp, xp_before),
		"dismissing a summon must not pay hero XP")
	_check(get_tree().get_nodes_in_group(Enemy.SUMMON_GROUP).is_empty(),
		"a dismissed summon must leave the summon group")


## A release must be observed even when something else consumed it.
##
## The bug: sticks and the dash button read `_unhandled_input`, which never sees
## an event a Control took first. A thumb lifted over a panel left the stick
## holding finger 0 forever, `owns_pointer()` stayed true, and every later tap on
## a tile was refused as "that is a thumb". The build panel opened once and never
## again.
## Weather must be visible, and snow must gather and then go.
##
## Weather shipped as data, a tint and a HUD label and was never *visible* -
## which is the quietest possible failure: every gate passed, the label said
## "Downpour", and nothing fell out of the sky. A test that only checked the
## resources would have agreed with all of it.
func _test_weather_can_be_seen() -> void:
	var field: Battlefield = _run.battlefield
	if field == null:
		_check(false, "the harness needs a battlefield to look at the weather")
		return
	var veil: WeatherVeil = field.get_node_or_null("WeatherVeil")
	_check(veil != null, "the battlefield must build a weather veil")
	_check(field.get_node_or_null("SnowCover") != null,
		"and something for snow to lie on")
	if veil == null:
		return

	# Every authored weather has to be coherent, because the shader believes it.
	for id: String in ["downpour", "snowfall", "duststorm", "clear"]:
		var weather: WeatherData = ContentDB.weather(id)
		_check(weather != null, "weather %s must exist" % id)
		if weather == null:
			continue
		if weather.precipitation == WeatherData.Precipitation.NONE:
			_check(is_zero_approx(weather.precipitation_density),
				"%s falls as nothing and must have no density" % id)
		else:
			_check(weather.precipitation_density > 0.0,
				"%s must actually fall, or it is weather in name only" % id)
	_check(ContentDB.weather("snowfall").settles,
		"snow must settle, or accumulation can never begin")
	_check(not ContentDB.weather("downpour").settles,
		"rain must not settle: it is not snow")

	# The weather has to reach the ground, not only the sky.
	#
	# Reported as "a downpour does not bend the grass": the veil and the foliage
	# shader knew nothing about each other, so rain fell through a meadow having a
	# pleasant afternoon. Checked on the shared material because that is the thing
	# every blade in the game actually reads.
	var grass: ShaderMaterial = Foliage.wind_material()
	Foliage.set_wind(ContentDB.weather("duststorm"))
	var storm_sway: float = float(grass.get_shader_parameter("sway_degrees"))
	var storm_bias: float = float(grass.get_shader_parameter("wind_bias"))
	Foliage.set_wind(ContentDB.weather("heatwave"))
	var still_sway: float = float(grass.get_shader_parameter("sway_degrees"))
	var still_bias: float = float(grass.get_shader_parameter("wind_bias"))
	_check(storm_sway > still_sway,
		"a duststorm must move the grass more than dead air does, %.1f vs %.1f"
			% [storm_sway, still_sway])
	# The lean is the half that reads as *wind* rather than as agitation, so it
	# is checked separately from the sway.
	_check(absf(storm_bias) > absf(still_bias) + 1.0,
		"and must hold it over, bias %.1f vs %.1f" % [storm_bias, still_bias])
	Foliage.set_wind(ContentDB.weather("clear"))

	# Arriving. Driven rather than waited out - the fade is seconds long and a
	# gate must not be.
	EventBus.weather_changed.emit("downpour")
	for _f: int in 12:
		veil._process(0.5)
	_check(veil.intensity() > 0.3,
		"a downpour must become visible, got %.2f" % veil.intensity())

	# Clearing.
	EventBus.weather_changed.emit("clear")
	for _f: int in 12:
		veil._process(0.5)
	_check(veil.intensity() < 0.05,
		"clear weather must clear, got %.2f" % veil.intensity())

	# Gathering, then melting. The asymmetry is the design: snow outlives the
	# storm by a long way, or it is an overlay tied to a switch.
	veil.set_cover(0.0)
	EventBus.weather_changed.emit("snowfall")
	for _f: int in 40:
		veil._process(1.0)
	_check(veil.cover() > 0.0, "snow must gather while it falls")
	var gathered: float = veil.cover()

	EventBus.weather_changed.emit("clear")
	for _f: int in 40:
		veil._process(1.0)
	_check(veil.cover() < gathered, "and melt back once it stops")
	_check(Balance.SNOW_MELT_SECONDS > Balance.SNOW_SETTLE_SECONDS,
		"melting must be slower than settling, or snow leaves with the clouds")
	veil.set_cover(0.0)
	await get_tree().process_frame


func _test_touch_release_always_lands() -> void:
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	GameDirector.run_active = true
	TouchInput.refresh()

	var thumb: Vector2 = TouchInput.zone(false).get_center()
	var press := InputEventScreenTouch.new()
	press.position = thumb
	press.pressed = true
	press.index = 0
	TouchInput._unhandled_input(press)
	_check(TouchInput.owns_pointer(),
		"a thumb on the movement stick must own the emulated pointer")

	# The release goes to `_input`, the path that still runs when a panel above
	# has already handled the event. `_unhandled_input` is deliberately not used
	# here: that is the path the bug proved cannot be relied on.
	var release := InputEventScreenTouch.new()
	release.position = thumb
	release.pressed = false
	release.index = 0
	TouchInput._input(release)
	_check(not TouchInput.owns_pointer(),
		"lifting the thumb must release the pointer even when a panel ate the event")


## The on-screen controls belong to a run, not to the device.
##
## The dash button drew its ring over the main menu and, worse, went on
## consuming taps there.
func _test_touch_controls_belong_to_the_run() -> void:
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	GameDirector.run_active = false
	TouchInput.refresh()
	TouchInput._process(0.016)
	_check(TouchInput.is_showing(),
		"the setting must still report the controls as enabled for this device")
	_check(not TouchInput.visible,
		"the controls must not be drawn outside a run")

	var tap := InputEventScreenTouch.new()
	tap.position = TouchInput.dash_rect().get_center()
	tap.pressed = true
	tap.index = 0
	TouchInput._unhandled_input(tap)
	_check(not TouchInput.owns_pointer(),
		"a tap outside a run must not be swallowed by the dash button")

	GameDirector.run_active = true
	TouchInput._process(0.016)
	_check(TouchInput.visible, "the controls must come back when a run starts")


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[regression] %s" % why)


## Animals turn up, and they stay off the roads.
##
## The road rule is the one that matters. A deer grazing in the middle of a lane
## makes the lane look like a mistake, and it is exactly the kind of thing that
## survives review because it only happens on some seeds in some acts.
func _test_the_field_is_inhabited() -> void:
	var field: Battlefield = _run.battlefield
	if field == null:
		return
	var wildlife: Wildlife = field.find_child("Wildlife", true, false) as Wildlife
	_check(wildlife != null, "the battlefield must build its wildlife")
	if wildlife == null:
		return

	for kind: WildlifeData in ContentDB.wildlife():
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no sprite at %s" % [kind.id, kind.get_sprite_path()])
		_check(kind.group_min <= kind.group_max,
			"%s has a group range that cannot be rolled" % kind.id)
		_check(kind.stay_min <= kind.stay_max,
			"%s has a patience range that cannot be rolled" % kind.id)
	_check(not ContentDB.wildlife().is_empty(), "there must be something alive out there")

	# Driven rather than waited out: arrivals are on a four second clock and a
	# gate must not be.
	for _tick: int in 40:
		wildlife._process(1.0)
	_check(wildlife.population() > 0, "something should have turned up by now")
	var cap: int = int(round(float(Balance.WILDLIFE_MAX) * Graphics.foliage_scale()))
	_check(wildlife.population() <= cap,
		"population %d must stay under the cap of %d"
			% [wildlife.population(), cap])

	# Where they are *going*, not where they are. A deer crossing a lane is a
	# deer crossing a path and is the whole point of having them; a deer that has
	# decided to stand in one makes the lane look like a mistake. The first was
	# what an earlier version of this check reported, and it was reporting
	# correct behaviour.
	# The hostile roster, and specifically the ladder that makes it interesting.
	#
	# The point of four temperaments is that *seeing* an animal does not tell you
	# what happens next. If they all collapsed to "walks at the player", the
	# whole design would be six enemies wearing fur - and nothing would error.
	var hostile: int = 0
	var predators: int = 0
	var territorial: int = 0
	for kind: WildlifeData in ContentDB.wildlife():
		if not kind.is_hostile():
			# Anything that does not fight must not be carrying an aggro radius
			# or damage, or it is a hostile animal that forgot to say so.
			_check(kind.damage <= 0.0,
				"%s is passive or cautious but deals damage" % kind.id)
			continue
		hostile += 1
		_check(kind.damage > 0.0, "%s must hit for something" % kind.id)
		_check(kind.aggro_radius > 0.0,
			"%s must notice something, or it is hostile in name only" % kind.id)
		_check(kind.attack_range < kind.aggro_radius,
			"%s must notice further than it can reach, or it can never close"
				% kind.id)
		_check(kind.skittish_radius <= 0.0,
			"%s must not also flee: two behaviours that cancel out" % kind.id)
		_check(ResourceLoader.exists(GameData.attack_frame_path(
			kind.get_sprite_path(), 1)),
			"%s has no strike pose, so its blow has no tell" % kind.id)
		if kind.temperament == WildlifeData.Temperament.PREDATORY:
			predators += 1
		elif kind.temperament == WildlifeData.Temperament.TERRITORIAL:
			territorial += 1
	_check(hostile >= 6, "the hostile roster must ship, found %d" % hostile)
	# Both rungs, or the ladder is a step.
	_check(predators > 0 and territorial > 0,
		"both hostile temperaments must exist: %d predators, %d territorial"
			% [predators, territorial])

	# A predator reaches further than a territorial animal, because one is a
	# reach and the other is a boundary. If that inverts, walking past a bear
	# becomes the same decision as walking past a wolf.
	var furthest_territory: float = 0.0
	var shortest_hunt: float = INF
	for kind: WildlifeData in ContentDB.wildlife():
		if not kind.is_hostile():
			continue
		if kind.temperament == WildlifeData.Temperament.TERRITORIAL:
			furthest_territory = maxf(furthest_territory, kind.aggro_radius)
		else:
			shortest_hunt = minf(shortest_hunt, kind.aggro_radius)
	_check(shortest_hunt < INF and furthest_territory > 0.0,
		"the harness needs one of each temperament to compare")

	# **A hunt has to be escapable, and it must not out-hit the road.**
	#
	# Both were violated at once and the result was measurable: a hero standing
	# still with eight towers up and the town on full health was dead in seventy
	# seconds, killed entirely by ambient wildlife. Four of six predators
	# sustained 218-385 units/s against a hero that walks at 200, so no hunt
	# could be broken by moving, and the bear hit for 54 where the hardest enemy
	# on the road hits for 34.
	#
	# Kept as data assertions because that is what they are - two numbers per
	# species, checkable in a millisecond, and the exact pair that will drift the
	# next time somebody wants the bear to feel scarier.
	var hardest_enemy: float = 0.0
	for value: Variant in ContentDB.enemies.values():
		var enemy := value as EnemyData
		if enemy != null:
			hardest_enemy = maxf(hardest_enemy, enemy.contact_damage)
	_check(hardest_enemy > 0.0, "the harness needs the enemy roster to compare")
	for kind: WildlifeData in ContentDB.wildlife():
		if not kind.is_hostile():
			continue
		_check(kind.damage <= hardest_enemy,
			"%s hits for %.0f, harder than anything the road sends (%.0f) - "
				% [kind.id, kind.damage, hardest_enemy]
				+ "ambient wildlife must not be the deadliest content in the game")
		var pursuit: float = kind.speed * kind.charge_speed_scale
		# The boar is the charger and the hawk is the flier: those two are meant
		# to catch you. Everything else must be outrunnable on foot, or the hunt
		# timer is decoration.
		var allowed: float = Balance.HERO_MOVE_SPEED * (1.12
			if kind.id == "boar" or kind.id == "hawk" else 1.0)
		_check(pursuit <= allowed,
			"%s pursues at %.0f/s against a hero that walks at %.0f - a hunt "
				% [kind.id, pursuit, Balance.HERO_MOVE_SPEED]
				+ "nothing can walk away from is a timer on the health bar")

	# And the hunt ends. Driven rather than read: the counters exist, the
	# question is whether anything decrements them back to an animal.
	var hunter: Dictionary = {}
	for animal: Dictionary in wildlife._living:
		var kind := animal["data"] as WildlifeData
		if kind != null and kind.is_hostile():
			hunter = animal
			break
	if not hunter.is_empty():
		hunter["hunt"] = 0.35
		hunter["wary"] = 0.0
		var sprite := hunter["sprite"] as Sprite2D
		var kind := hunter["data"] as WildlifeData
		wildlife._tick_hostile(hunter, sprite, kind, 0.5)
		_check(float(hunter["hunt"]) <= 0.0 and float(hunter["wary"]) > 0.0,
			"a hunt that runs out must break off and rest, hunt=%.2f wary=%.2f"
				% [float(hunter["hunt"]), float(hunter["wary"])])

	# Hunting: it has to be possible at all, and it has to pay by size.
	#
	# "Possible at all" is the one that was broken and looked fine. Wildlife
	# listened for `hero_attack_landed`, which fires only when an *enemy* was hit
	# - so a swing at a rabbit standing alone in a field emitted nothing and no
	# animal in the game could ever be killed.
	for kind: WildlifeData in ContentDB.wildlife():
		_check(kind.max_hp > 0.0, "%s must be killable" % kind.id)
		_check(kind.food_min <= kind.food_max,
			"%s has a food range that cannot be rolled" % kind.id)
		_check(kind.xp_reward > 0, "%s must be worth something to kill" % kind.id)
	var small: WildlifeData = ContentDB.wildlife()[0]
	var large: WildlifeData = small
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.max_hp < small.max_hp:
			small = kind
		if kind.max_hp > large.max_hp:
			large = kind
	# Size has to *mean* something, or the ranges are decoration.
	_check(large.food_min > small.food_max,
		"the largest animal must be worth more food than the smallest, "
			+ "%s %d-%d against %s %d-%d" % [large.id, large.food_min,
			large.food_max, small.id, small.food_min, small.food_max])
	_check(large.xp_reward > small.xp_reward,
		"and more experience")

	var before_food: int = RunState.currency(RunState.FOOD)
	var before_xp: float = RunState.hero_xp
	var hunted: bool = false
	for child: Node in wildlife.get_children():
		var animal := child as Sprite2D
		if animal == null:
			continue
		# Swing at it from close by, the way the hero's attack reports itself.
		var from: Vector2 = animal.global_position - Vector2(40.0, 0.0)
		for _swing: int in 40:
			EventBus.hero_swing_resolved.emit(from, Vector2.RIGHT, 200.0)
		hunted = true
		break
	if hunted:
		for _f: int in 6:
			await get_tree().process_frame
		_check(RunState.hero_xp > before_xp,
			"hunting must grant experience: %0.1f -> %0.1f"
				% [before_xp, RunState.hero_xp])
		# The food arrives as a dropped pickup rather than straight into the
		# purse, so the wallet is not the assertion - the drop existing is.
		_check(get_tree().get_nodes_in_group(LootDrop.GROUP).size() > 0
			or RunState.currency(RunState.FOOD) > before_food,
			"and must drop food")

	var goals: PackedVector2Array = wildlife.goals()
	_check(goals.size() > 0, "settled animals must have somewhere to be")
	for goal: Vector2 in goals:
		_check(wildlife._is_clear(goal),
			"an animal chose to stand on a road or in the town at %s" % goal)
