class_name Wildfire
extends Node2D

## Fire in the foliage: it catches, spreads, burns what stands near it, and
## leaves the ground marked.
##
## Owner brief, 2026-09-14. A wildfire is one of the earth's answers to a
## player who has killed too much of its wildlife (`WeatherSky.wrath`), and a
## fire tower's shots can start one on their own. Each burning plant is a
## record here: how long it has left, where it stands, and the flame drawn on
## it. Every spread tick it may light a neighbour, by how dry the air is;
## every frame it hurts what stands too close - bodies, players, spirits,
## animals - and the animals run from it. When it is done the plant is gone
## for the act, the ground under it is scorched, and a woodcutting tree it
## reached never grows back.
##
## **The host burns, the guest watches.** Spread, damage and burn-out are
## rolled where the bodies are authoritative; a guest lights the same plants
## when told (`coop_wildfire_lit`), runs the same burn clock, and draws the
## same marks. Rain shortens a fire and a flood puts it out on both.

var field: Battlefield = null
var foliage: Foliage = null
var gathering: Gathering = null
var animals: Wildlife = null
var marks: ScorchMarks = null
var zones: WrathZones = null

## Each: {at, left, band, index, flame, spread}
var _fires: Array[Dictionary] = []
var _rng: RandomNumberGenerator = null
var _mirror: bool = false
var _scare_timer: float = 0.0
## How many plants this wildfire has lit this act. For the gate.
var lit_count: int = 0
var burnt_count: int = 0
## Plants burnt by a fire the *player* lit - a tower's shot - as against the
## earth's own. Clearing a forest with fire is what the earth holds against
## the road; its own lightning is the cycle.
var burnt_by_player: int = 0
## Plants lit by the blaze currently burning. Reset when the last fire goes
## out, so the bound is per blaze and not per act.
var _blaze_lit: int = 0
## What the blaze has burnt, and where, for the ground it leaves.
var _blaze_burnt: int = 0
var _blaze_sum: Vector2 = Vector2.ZERO


func _ready() -> void:
	name = "Wildfire"
	z_as_relative = false
	z_index = Balance.WILDFIRE_Z
	_rng = RunState.rng("wildfire")
	_mirror = Coop.is_guest()
	EventBus.coop_wildfire_lit.connect(_on_lit_elsewhere)
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: _clear())


## Tries to light a plant near a point. `chance` is rolled once, and the
## nearest unburnt plant inside `radius` catches. Returns whether one did.
func ignite_near(at: Vector2, radius: float, chance: float = 1.0, by_player: bool = false) -> bool:
	if _mirror or _foliage() == null:
		return false
	if chance < 1.0 and _rng.randf() > chance:
		return false
	# Nothing catches in a downpour, and nothing at all under water.
	if RunState.rain_intensity > Balance.WILDFIRE_RAIN_STOPS or RunState.flood > Balance.WILDFIRE_FLOOD_STOPS:
		return false
	var plant: Dictionary = _nearest_unburnt(at, radius)
	if plant.is_empty():
		return false
	_light(plant, 0, by_player)
	return true


## The field's foliage, found when first needed: it is planted after the sky
## is built, so it cannot be handed over at construction.
func _foliage() -> Foliage:
	if foliage == null and field != null:
		foliage = field.foliage_node()
	return foliage


func _nearest_unburnt(at: Vector2, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var nearest: float = radius
	if _foliage() == null:
		return best
	for plant: Dictionary in foliage.plants_near(at, radius):
		if _is_burning(int(plant["band"]), int(plant["index"])):
			continue
		var away: float = (plant["at"] as Vector2).distance_to(at)
		if away <= nearest:
			nearest = away
			best = plant
	return best


func _is_burning(band: int, index: int) -> bool:
	for fire: Dictionary in _fires:
		if int(fire["band"]) == band and int(fire["index"]) == index:
			return true
	return false


func _light(plant: Dictionary, generation: int = 0, by_player: bool = false) -> void:
	var at: Vector2 = plant["at"]
	var flame := Flame.new()
	flame.name = "Wildfire%d" % lit_count
	flame.position = at + Vector2(0.0, -Balance.WILDFIRE_FLAME_LIFT)
	add_child(flame)
	flame.configure(Balance.WILDFIRE_FLAME_SIZE * float(plant.get("scale", 1.0)), 0.0,
		Balance.FLAME_MID, 1.0, false, false)
	_fires.append({"at": at, "left": Balance.WILDFIRE_BURN_SECONDS, "band": int(plant["band"]),
		"index": int(plant["index"]), "flame": flame, "spread": Balance.WILDFIRE_SPREAD_TICK,
		"generation": generation, "player": by_player})
	lit_count += 1
	_blaze_lit += 1
	Vfx.spark(at, Balance.FLAME_MID, 8, Vector2.UP, 160.0)
	# **A wildfire makes a sound.** `sfx_wildfire` has been on disk, in `SOUNDS`
	# and in `MIX` since the earth's wrath was built, and this system had no audio
	# at all - the one recording in this project that was made, registered, mixed
	# and played by nothing. Its mix row authors `limit: 2, gap: 0.08`, which is a
	# throttle written for a call site that did not exist: it is what stops a
	# blaze lighting `WILDFIRE_MAX_LIT` plants from machine-gunning crackles.
	#
	# Above the `_mirror` guard, so a guest hears its own fires too - it reaches
	# this function through `_on_lit_elsewhere` and nothing new crosses the wire.
	Sfx.play_at("sfx_wildfire", at)
	if not _mirror:
		EventBus.wildfire_lit.emit(at)


## The host told us a plant caught. Light the nearest one to where it said,
## and burn it on our own clock.
func _on_lit_elsewhere(at: Vector2) -> void:
	if not _mirror or _foliage() == null:
		return
	var plant: Dictionary = _nearest_unburnt(at, Balance.WILDFIRE_SPREAD_RADIUS)
	if not plant.is_empty():
		_light(plant)


func _process_measured(delta: float) -> void:
	if _fires.is_empty():
		return
	# Rain shortens every fire; a flood ends them all.
	var quench: float = 1.0 + RunState.rain_intensity * Balance.WILDFIRE_RAIN_QUENCH
	var ground: Climate = field.climate() if field != null else null
	var drowned: bool = RunState.flood > Balance.WILDFIRE_FLOOD_STOPS
	_scare_timer -= delta
	var scare: bool = _scare_timer <= 0.0
	if scare:
		_scare_timer = Balance.WILDFIRE_SCARE_TICK
	# **Embers on the wind**, carried the way the spread is. A blaze shedding
	# sparks downwind is the fire telling the player where it is going next.
	_ember_timer -= delta
	var embers: bool = _ember_timer <= 0.0
	if embers:
		_ember_timer = Balance.WILDFIRE_EMBER_TICK
	for index: int in range(_fires.size() - 1, -1, -1):
		var fire: Dictionary = _fires[index]
		var at: Vector2 = fire["at"]
		# Wet ground under a fire puts it out sooner; a fire warms and dries
		# the ground it burns on.
		var soaked: float = ground.wetness_at(at) if ground != null else 0.0
		fire["left"] = float(fire["left"]) - delta * (quench + soaked * Balance.CLIMATE_WET_QUENCH_FIRE)
		if embers:
			# Drawn on both machines: a guest sees the same fire going the same
			# way, and nothing about it is read.
			var carry: Vector2 = (RunState.wind * 0.6 + Vector2.UP).normalized()
			Vfx.spark(at, Balance.FLAME_MID, Balance.WILDFIRE_EMBER_COUNT,
				carry, Balance.WILDFIRE_EMBER_SPEED)
		if not _mirror:
			if ground != null:
				ground.add_heat(at, Balance.CLIMATE_HEAT_PER_FIRE_SECOND * delta, Balance.CLIMATE_FIRE_RADIUS)
				ground.add_wet(at, -Balance.CLIMATE_DRY_PER_FIRE_SECOND * delta, Balance.CLIMATE_FIRE_RADIUS)
			# On `GROUND_HURT_TICK`, not every frame: the same damage over time
			# with a fifth of the blows (2026-09-24).
			var owed: float = float(fire.get("hurt_owed", 0.0)) + delta
			if owed >= Balance.GROUND_HURT_TICK:
				_hurt_around(at, owed)
				owed = 0.0
			fire["hurt_owed"] = owed
			if scare and animals != null:
				animals.scare_from(at, Balance.WILDFIRE_SCARE_RADIUS)
			fire["spread"] = float(fire["spread"]) - delta
			if float(fire["spread"]) <= 0.0:
				fire["spread"] = Balance.WILDFIRE_SPREAD_TICK
				_try_spread(at, int(fire.get("generation", 0)), bool(fire.get("player", false)))
		if drowned or float(fire["left"]) <= 0.0:
			_burn_out(index, drowned)
	if _fires.is_empty():
		_blaze_lit = 0
		# A blaze that burnt a real patch leaves it charged for the fire towers.
		if _blaze_burnt >= Balance.ZONE_BLAZE_MIN_BURNT and zones != null and not _mirror:
			zones.open("burning_ground", _blaze_sum / float(_blaze_burnt), Balance.ZONE_BURN_RADIUS)
		_blaze_burnt = 0
		_blaze_sum = Vector2.ZERO


## Everything standing in the fire is burned by it, a little every frame.
func _hurt_around(at: Vector2, delta: float) -> void:
	if field == null:
		return
	var radius: float = Balance.WILDFIRE_HURT_RADIUS
	var dps: float = Balance.WILDFIRE_DPS * Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_HP_SCALE.size() - 1)]
	for enemy: Enemy in field.enemies_near(at, radius):
		enemy.take_damage(dps * delta, at, 0.0)
	var hero_pool: float = 100.0
	if field.hero != null and field.hero.health != null:
		hero_pool = field.hero.health.max_hp
	EnemyGroundStrike.strike_the_players(get_tree(), hero_pool * Balance.WILDFIRE_HERO_SHARE_PER_SECOND * delta,
		"", func(where: Vector2) -> bool: return where.distance_to(at) <= radius)
	if animals != null:
		animals.burn_near(at, radius, Balance.WILDFIRE_WILDLIFE_DPS * delta)


## A neighbour catches, by how dry the air is and how hard the wind blows.
func _try_spread(at: Vector2, generation: int, by_player: bool = false) -> void:
	if generation >= Balance.WILDFIRE_MAX_GENERATIONS or _fires.size() >= Balance.WILDFIRE_MAX_FIRES:
		return
	# The ground under the fire: its own dryness and heat where there is a
	# climate to ask, the sky's where there is not.
	var ground: Climate = field.climate() if field != null else null
	var hot: bool = (ground.temperature_at(at) if ground != null else RunState.temperature) > Balance.WILDFIRE_HOT_FROM
	var most: int = int(round(Balance.WILDFIRE_MAX_LIT * (Balance.WILDFIRE_HOT_LIT_SCALE if hot else 1.0)))
	if _blaze_lit >= most:
		return
	var dry: float = clampf(1.0 - RunState.rain_intensity * 2.0, 0.0, 1.0)
	if ground != null:
		dry = minf(dry, ground.dryness_at(at) / (Balance.WILDFIRE_HOT_SPREAD if hot else 1.0))
	if hot:
		dry *= Balance.WILDFIRE_HOT_SPREAD
	var weather: WeatherData = ContentDB.weather(RunState.weather_id)
	var wind: float = absf(weather.wind) if weather != null else 0.0
	var chance: float = Balance.WILDFIRE_SPREAD_CHANCE * dry * (1.0 + wind * Balance.WILDFIRE_WIND_SPREAD)
	chance *= pow(Balance.WILDFIRE_SPREAD_DECAY, float(generation))
	if _rng.randf() > chance:
		return
	# Downwind, mostly: the wind carries the embers.
	var plant: Dictionary = _nearest_unburnt(at + Vector2(_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)) * Balance.WILDFIRE_SPREAD_RADIUS * 0.5
		+ RunState.wind * Balance.WILDFIRE_WIND_DRIFT, Balance.WILDFIRE_SPREAD_RADIUS)
	if not plant.is_empty() and (plant["at"] as Vector2).distance_to(at) > 4.0:
		_light(plant, generation + 1, by_player)


## The plant is gone for the act, the ground is marked, and a felled tree it
## reached never grows back.
func _burn_out(index: int, drowned: bool) -> void:
	var fire: Dictionary = _fires[index]
	var at: Vector2 = fire["at"]
	var flame: Flame = fire["flame"]
	if flame != null and is_instance_valid(flame):
		flame.queue_free()
	_fires.remove_at(index)
	if drowned:
		Vfx.dust(at, Color(0.55, 0.6, 0.65), 6, 40.0)
		return
	burnt_count += 1
	if bool(fire.get("player", false)):
		burnt_by_player += 1
	_blaze_burnt += 1
	_blaze_sum += at
	if _foliage() != null:
		foliage.burn_plant(int(fire["band"]), int(fire["index"]))
	if marks != null:
		marks.stamp(at, Balance.WILDFIRE_SCORCH_RADIUS, Balance.WILDFIRE_SCORCH_STRENGTH)
	if gathering != null:
		gathering.burn_near(at, Balance.WILDFIRE_TREE_REACH)
	Vfx.dust(at, Color(0.18, 0.16, 0.14), 8, 50.0)


## Seconds until the next round of embers. One clock for every fire rather than
## one each, so a field of blazes costs a single countdown.
var _ember_timer: float = 0.0


func _clear() -> void:
	for fire: Dictionary in _fires:
		var flame: Flame = fire["flame"]
		if flame != null and is_instance_valid(flame):
			flame.queue_free()
	_fires.clear()
	_blaze_lit = 0
	_blaze_burnt = 0
	_blaze_sum = Vector2.ZERO
	if marks != null:
		marks.clear()


## How much fire stands within reach of a point, 0 for none. A fire tower
## reads it for its own heat.
func heat_at(at: Vector2, radius: float) -> float:
	var total: float = 0.0
	for fire: Dictionary in _fires:
		var away: float = (fire["at"] as Vector2).distance_to(at)
		if away <= radius:
			total += 1.0 - away / maxf(radius, 1.0) * 0.5
	return total


func fire_count() -> int:
	return _fires.size()


func fire_positions() -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for fire: Dictionary in _fires:
		out.append(fire["at"] as Vector2)
	return out


## `FrameProfile` bucket "p_wildfire": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_wildfire", started)
