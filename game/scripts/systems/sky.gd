class_name WeatherSky
extends Node2D

## The living half of the weather: rain that rises and falls, lightning, the
## flood it leaves, and the temperature under all of it.
##
## Owner brief, 2026-09-14. Weather was a `.tres`, a tint and a veil of drops
## at one authored density - a *condition*, chosen at a crossroad and held until
## the next. This makes it something that happens while the player stands in
## it. Rain surges and slackens on its own; a heavy stretch can draw lightning,
## and a strike leaves the air charged so the next comes sooner; rain held at
## its heaviest for long enough floods the ground, which slows everything that
## walks on it and drowns what is too small to climb; a heatwave dries the
## wells; and a temperature is derived from all of it for the HUD to forecast.
##
## **One authority, and the numbers travel as facts.** The host rolls
## everything from the run's own `sky` stream and writes the results into
## `RunState` - rain scale, flood, charge, temperature - which is where every
## consumer reads them (working rule 6). Twice a second the host announces
## those four numbers and the guest writes the same ones; a strike is announced
## as a place and a radius, and the guest draws it. Nothing per-drop crosses
## the wire, because a raindrop is not a fact.
##
## **It lives on the battlefield**, so it freezes with the field for a raid
## (working rule 8). `_clock` is sky time, not wall time: rain stops surging
## while the player is in an arena and picks up where it left off.
##
## What it deliberately does not do: it never chooses the weather. The
## crossroad still rolls the sky (`RunState.roll_weather`), and this only says
## how that sky behaves from moment to moment.

## The field this sky is over. Set by the battlefield before `_ready`.
var field: Battlefield = null
## The earth's tools, set by the battlefield: the fire and the ground's memory.
var wildfire: Wildfire = null
var marks: ScorchMarks = null
var zones: WrathZones = null
## Telegraphs: the hum before a quake and the wind before a funnel.
var _quake_warning_left: float = 0.0
var _quake_pending: float = -1.0
var _warn_tremor_timer: float = 0.0
## {from, target, seconds, left, spawn, gust} while a funnel is on its way.
var _pending_tornado: Dictionary = {}
var _basin_opened: bool = false
var _tier_told: int = 0
var _zone_rng: RandomNumberGenerator = null
## The legendary shock and the stillness that comes with it.
var _shock_left: float = 0.0
var _wind_still_left: float = 0.0
## Seconds since the road last killed, felled or burnt anything.
var _quiet: float = 0.0
## When the recent trees fell, on the sky's clock.
var _fells: Array[float] = []
var _burnt_seen: int = 0
## For the gate.
var shocks: int = 0

var _rng: RandomNumberGenerator = null
var _weather: WeatherData = null
## Seconds of sky time this run. Frozen with the field.
var _clock: float = 0.0
## The rain's multiplier on its authored density, smoothed.
var _scale: float = 1.0
var _scale_target: float = 1.0
## What the last two seconds of scale looked like, for the forecast's trend.
var _scale_was: float = 1.0
var _trend_timer: float = 0.0
var _trend: float = 0.0
var _flood: float = 0.0
var _charge: float = 0.0
var _temperature: float = 20.0
var _temperature_target: float = 20.0
## Seeded phases, so every downpour has its own rhythm and both machines'
## would agree if they ever had to.
var _phases: Vector3 = Vector3.ZERO
var _sync_timer: float = 0.0
var _announce_timer: float = 0.0
var _flood_announced: bool = false
var _wells_announced: bool = false
## A guest's sky: it draws what it is told and rolls nothing.
var _mirror: bool = false
## How many strikes this sky has thrown. For the gate.
var strikes: int = 0
## Test seam: a fixed intensity in place of the rolling one, or -1 to roll.
var forced_intensity: float = -1.0
## Test seam: whether the earth's events roll at all. A gate that measures a
## quake it caused cannot also have the earth throwing its own.
var events_enabled: bool = true

var _sheen: ColorRect = null
var _sheen_material: ShaderMaterial = null
var _bolts: Node2D = null

## The earth's wrath. A floor that only rises for the run and a heat that
## decays; hidden, sensed. See Balance under THE EARTH'S WRATH.
var _wrath_floor: float = 0.0
var _wrath_heat: float = 0.0
## A quake in progress: seconds left and how hard.
var _quake_left: float = 0.0
var _quake_magnitude: float = 0.0
var _tremor_timer: float = 0.0
## For the gate.
var quakes: int = 0
var tornadoes: int = 0
var meteors: int = 0
var wildfires: int = 0


func _ready() -> void:
	name = "Sky"
	z_as_relative = false
	_rng = RunState.rng("sky")
	_zone_rng = RunState.rng("zones")
	_phases = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
	_mirror = Coop.is_guest()
	_build_sheen()
	_bolts = Node2D.new()
	_bolts.name = "Bolts"
	_bolts.z_index = Balance.LIGHTNING_Z
	_bolts.z_as_relative = false
	add_child(_bolts)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.coop_sky_clock.connect(_on_sky_clock)
	EventBus.coop_lightning.connect(_on_lightning_seen)
	EventBus.coop_wind_changed.connect(_on_wind_elsewhere)
	EventBus.lightning_struck.connect(_on_lightning_seen)
	EventBus.wildlife_killed.connect(_on_wildlife_killed)
	EventBus.coop_earthquake.connect(_on_earthquake_seen)
	EventBus.earthquake.connect(_on_earthquake_seen)
	EventBus.coop_tornado_spawned.connect(_on_tornado_elsewhere)
	EventBus.coop_meteor_incoming.connect(_on_meteor_elsewhere)
	EventBus.coop_wrath_warned.connect(_on_warned_elsewhere)
	EventBus.act_started.connect(_on_act_started)
	EventBus.gathered.connect(_on_gathered)
	_apply(ContentDB.weather(RunState.weather_id))
	_temperature = _temperature_target
	_publish(true)


func _process(delta: float) -> void:
	if _mirror:
		_tick_warnings(delta)
		_tick_quake(delta)
		_drive_visuals(delta)
		return
	_clock += delta
	_tick_rain(delta)
	_tick_flood(delta)
	_tick_charge(delta)
	_tick_lightning(delta)
	_tick_temperature(delta)
	_tick_wrath(delta)
	if events_enabled:
		_tick_wrath_events(delta)
	_tick_warnings(delta)
	_tick_quake(delta)
	_publish(false)
	_tick_sync(delta)
	_tick_announcements(delta)
	_drive_visuals(delta)


# --- The weather itself -------------------------------------------------------

func _on_weather_changed(weather_id: String) -> void:
	_apply(ContentDB.weather(weather_id))


func _apply(weather: WeatherData) -> void:
	_weather = weather
	_temperature_target = _target_temperature()
	_wells_announced = false


## Whether anything is falling that this sky can vary.
func _falling() -> bool:
	return _weather != null and _weather.precipitation != WeatherData.Precipitation.NONE \
		and _weather.precipitation_density > 0.0


## The rain rising and falling on its own.
##
## Three sines of unrelated periods, summed, the way the menu's vines sway:
## nothing in it repeats on a scale a player would notice, and the sum still
## reads as one thing swelling and slackening rather than as noise. The
## authored `rain_variability` says how far it may swing, so a steady drizzle
## and a squall line are two files rather than two branches.
func _tick_rain(delta: float) -> void:
	if forced_intensity >= 0.0:
		_scale_target = forced_intensity / maxf(_authored_density(), 0.001)
	elif not _falling():
		_scale_target = 1.0
	else:
		# `TAU * t / period`, so the periods in Balance are the periods in
		# seconds. Without the TAU a 95-second period was a ten-minute one, and
		# five minutes of downpour never once swelled.
		var wave: float = 0.5 + 0.5 * (0.55 * sin(TAU * _clock / Balance.SKY_RAIN_PERIODS.x + _phases.x)
			+ 0.30 * sin(TAU * _clock / Balance.SKY_RAIN_PERIODS.y + _phases.y)
			+ 0.15 * sin(TAU * _clock / Balance.SKY_RAIN_PERIODS.z + _phases.z))
		var swing: float = clampf(_weather.rain_variability, 0.0, 1.0)
		var low: float = lerpf(1.0, Balance.SKY_RAIN_SCALE_RANGE.x, swing)
		# An angry earth's storms surge harder.
		var high: float = lerpf(1.0, Balance.SKY_RAIN_SCALE_RANGE.y, swing) \
			* (1.0 + clampf(wrath(), 0.0, 1.0) * Balance.WRATH_RAIN_SURGE)
		_scale_target = lerpf(low, high, wave)
	_scale = lerpf(_scale, _scale_target, minf(delta * Balance.SKY_RAIN_SMOOTHING, 1.0))
	_trend_timer += delta
	if _trend_timer >= 2.0:
		_trend = clampf((_scale - _scale_was) * 4.0, -1.0, 1.0)
		_scale_was = _scale
		_trend_timer = 0.0


func _authored_density() -> float:
	return _weather.precipitation_density if _weather != null else 0.0


## How heavy it is falling right now, 0..1 of the heaviest any sky gets.
func intensity() -> float:
	if forced_intensity >= 0.0:
		return clampf(forced_intensity, 0.0, 1.0)
	if not _falling():
		return 0.0
	return clampf(_authored_density() * _scale, 0.0, 1.0)


## Rain held at its heaviest for long enough floods the ground.
##
## Rises only above `FLOOD_RISE_ABOVE`, so a drizzle never floods however long
## it lasts, and drains on its own clock once the rain eases - the field stays
## wet after the storm, which is the difference between weather that happened
## and weather that was switched off.
func _tick_flood(delta: float) -> void:
	var raining: bool = _weather != null and _weather.floods \
		and _weather.precipitation == WeatherData.Precipitation.RAIN
	var heavy: float = intensity() if raining else 0.0
	var before: float = _flood
	if heavy > Balance.FLOOD_RISE_ABOVE:
		var push: float = (heavy - Balance.FLOOD_RISE_ABOVE) / maxf(1.0 - Balance.FLOOD_RISE_ABOVE, 0.01)
		_flood = minf(_flood + delta * push / maxf(Balance.FLOOD_RISE_SECONDS, 1.0), 1.0)
	else:
		_flood = maxf(_flood - delta / maxf(Balance.FLOOD_DRAIN_SECONDS, 1.0), 0.0)
	RunState.flood = _flood
	# At the knee the water finds its basin: charged ground for the water
	# towers, once per flood.
	if not _mirror and zones != null:
		if _flood >= Balance.FLOOD_KNEE and not _basin_opened:
			_basin_opened = true
			zones.open("flood_basin", _pick_strike_point(_zone_rng), Balance.ZONE_BASIN_RADIUS,
				Balance.ZONE_SECONDS * 2.0)
		elif _flood < Balance.FLOOD_KNEE * 0.5:
			_basin_opened = false
	# Announced when it has moved a visible amount since it was last announced,
	# not since the last frame - a flood rises a few thousandths a step, and
	# measured frame to frame it never crossed the line and was never told.
	if absf(_flood - _flood_told) > 0.004 or (before > 0.0 and _flood == 0.0):
		_flood_told = _flood
		EventBus.flood_changed.emit(_flood)


var _flood_told: float = 0.0


func _tick_charge(delta: float) -> void:
	_charge = maxf(_charge - delta / maxf(Balance.LIGHTNING_CHARGE_DECAY_SECONDS, 1.0), 0.0)


## Whether the sky is charged enough to strike, and how often.
##
## A hazard per second rather than a timer: a timer would strike on schedule,
## and the whole point of lightning is that it does not. It climbs with the
## square of how far the rain is past the threshold, and with the charge the
## last strike left behind - so strikes come rarely from a steady rain and in
## bursts once one has landed, which is what a storm does.
func _hazard() -> float:
	if _weather == null or _weather.lightning_rate <= 0.0:
		return 0.0
	var over: float = (intensity() - Balance.LIGHTNING_MIN_INTENSITY) \
		/ maxf(1.0 - Balance.LIGHTNING_MIN_INTENSITY, 0.01)
	if over <= 0.0:
		return 0.0
	return _weather.lightning_rate / 60.0 * over * over \
		* (1.0 + _charge * Balance.LIGHTNING_CHARGE_HAZARD)


func _tick_lightning(delta: float) -> void:
	var hazard: float = _hazard()
	if hazard <= 0.0:
		return
	if _rng.randf() < hazard * delta:
		strike_at(_pick_strike_point())


## Somewhere on the field, never on the city.
func _pick_strike_point(rng: RandomNumberGenerator = null) -> Vector2:
	if rng == null:
		rng = _rng
	var reach: float = BattleGrid.HALF_EXTENT * 0.86
	for _attempt: int in 12:
		var at := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach))
		if at.length() >= Balance.LIGHTNING_TOWN_CLEARANCE:
			return at
	return Vector2(reach * 0.7, reach * 0.7)


## A strike lands: everything under it is hurt, the storm towers near it are
## charged, and the sky remembers.
##
## **Everything** is what the owner asked for and what it is: bodies, players,
## their spirits and the wildlife, through the same doors every other blow
## uses. Towers are spared - a random strike that broke a defence the player
## paid for would be a tax nobody chose - and the storm towers are the reverse
## of spared: a strike near one is what it was built for.
func strike_at(at: Vector2) -> void:
	strikes += 1
	_charge = minf(_charge + Balance.LIGHTNING_CHARGE_PER_STRIKE, Balance.LIGHTNING_CHARGE_CAP)
	var radius: float = Balance.LIGHTNING_RADIUS
	if field != null:
		var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
			Balance.WAVE_ACT_HP_SCALE.size() - 1)]
		var struck: Array[Enemy] = field.enemies_near(at, radius)
		for enemy: Enemy in struck:
			enemy.take_damage(Balance.LIGHTNING_ENEMY_DAMAGE * act_scale * enemy.shock_scale(), at, 0.0)
		_chain(at, struck, Balance.LIGHTNING_ENEMY_DAMAGE * act_scale)
		var hero_pool: float = 100.0
		if field.hero != null and field.hero.health != null:
			hero_pool = field.hero.health.max_hp
		EnemyGroundStrike.strike_the_players(get_tree(),
			hero_pool * Balance.LIGHTNING_HERO_SHARE, "lightning",
			func(where: Vector2) -> bool: return where.distance_to(at) <= radius)
		var animals: Wildlife = field.wildlife()
		if animals != null:
			animals.wound_near(at, radius, Balance.LIGHTNING_WILDLIFE_DAMAGE)
		for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
			var tower := node as Tower
			if tower == null or not is_instance_valid(tower) or tower.data == null:
				continue
			if tower.data.element != TowerData.Element.AIR:
				continue
			if tower.global_position.distance_to(at) <= Balance.LIGHTNING_EMPOWER_RADIUS:
				tower.storm_charge(Balance.LIGHTNING_EMPOWER_SECONDS)
	if not _mirror:
		# The air where it struck stays charged; the ground under it warms;
		# dry brush under it catches.
		if zones != null:
			zones.open("storm_core", at, Balance.ZONE_STORM_RADIUS)
		if field != null and field.climate() != null:
			field.climate().add_heat(at, Balance.CLIMATE_HEAT_PER_STRIKE, Balance.LIGHTNING_RADIUS * 1.5)
		_dry_lightning(at)
	EventBus.lightning_struck.emit(at, radius)


## The picture of a strike, on every machine that hears of one.
func _on_lightning_seen(at: Vector2, radius: float) -> void:
	RunState.note_earth("strikes")
	_draw_bolt(at)
	Vfx.flash(Balance.LIGHTNING_COLOUR, Balance.LIGHTNING_FLASH, 0.22)
	Vfx.flash_at(at, Balance.LIGHTNING_COLOUR, 70.0)
	Vfx.ring(at, radius, Color(Balance.LIGHTNING_COLOUR, 0.9), 0.4, 5.0)
	Vfx.spark(at, Balance.LIGHTNING_COLOUR, 18, Vector2.UP, 320.0)
	Vfx.dust(at, Color(0.14, 0.12, 0.11), 8, 60.0)
	EventBus.camera_impact.emit(at, 1.0)
	# Thunder arrives after the light, by the distance: a strike across the
	# field rolls in a moment later, one overhead is on top of the flash.
	var ear: Vector2 = field.hero.global_position if field != null and field.hero != null else at
	var away: float = ear.distance_to(at)
	var wait: float = away / maxf(Balance.THUNDER_SPEED, 1.0)
	var clip: String = "sfx_thunder_near" if away < Balance.THUNDER_NEAR else "sfx_thunder_far"
	if wait <= 0.05:
		Sfx.play(clip, 0.0)
	else:
		get_tree().create_timer(wait).timeout.connect(func() -> void: Sfx.play(clip, 0.0))


## A jagged line from the sky to the ground, with a branch or two, for a few
## frames - and then once more, fainter, because a strike is never one flash.
func _draw_bolt(at: Vector2) -> void:
	if _bolts == null:
		return
	var top: Vector2 = at + Vector2(_rng.randf_range(-120.0, 120.0), -Balance.LIGHTNING_BOLT_HEIGHT)
	var main: PackedVector2Array = _jagged(top, at, 12, 70.0)
	# A wide, faint stroke under the bright one: the glow of the air the bolt
	# passed through, which is what makes a line read as light.
	var lines: Array[Line2D] = [_bolt_line(main, 26.0, 0.22), _bolt_line(main, 7.0, 1.0)]
	# One or two branches off the main stroke, thinner and shorter.
	for _b: int in 1 + (1 if _rng.randf() < 0.6 else 0):
		var from_index: int = _rng.randi_range(3, main.size() - 4)
		var from: Vector2 = main[from_index]
		var to: Vector2 = from + Vector2(_rng.randf_range(-260.0, 260.0), _rng.randf_range(160.0, 420.0))
		lines.append(_bolt_line(_jagged(from, to, 5, 40.0), 3.5, 0.7))
	for line: Line2D in lines:
		_bolts.add_child(line)
	var fade: Tween = create_tween()
	fade.tween_interval(0.05)
	fade.tween_callback(func() -> void:
		for line: Line2D in lines:
			line.modulate.a = 0.35)
	fade.tween_interval(0.04)
	fade.tween_callback(func() -> void:
		for line: Line2D in lines:
			line.modulate.a = 1.0)
	fade.tween_interval(0.06)
	fade.tween_callback(func() -> void:
		for line: Line2D in lines:
			line.queue_free())


func _jagged(from: Vector2, to: Vector2, steps: int, jitter: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in steps + 1:
		var t: float = float(index) / float(steps)
		var along: Vector2 = from.lerp(to, t)
		if index > 0 and index < steps:
			along += Vector2(_rng.randf_range(-jitter, jitter), _rng.randf_range(-jitter * 0.4, jitter * 0.4))
		points.append(along)
	return points


func _bolt_line(points: PackedVector2Array, width: float, alpha: float) -> Line2D:
	var line := Line2D.new()
	line.points = points
	line.width = width
	line.default_color = Color(Balance.LIGHTNING_COLOUR, alpha)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = additive
	return line


## The air's temperature: the sky's own, the region's, the hour's and the rain's.
func _target_temperature() -> float:
	var base: float = _weather.temperature if _weather != null else 20.0
	base += float(Balance.SKY_REGION_TEMPERATURE.get(RunState.terrain_id, 0.0))
	base += Balance.SKY_TEMPERATURE_NIGHT * DayNight.sun_darkness()
	base += Balance.SKY_TEMPERATURE_RAIN * intensity()
	return base


func _tick_temperature(delta: float) -> void:
	_temperature_target = _target_temperature()
	_temperature = lerpf(_temperature, _temperature_target,
		minf(delta * Balance.SKY_TEMPERATURE_EASE, 1.0))


# --- The wind (2026-09-15) ---------------------------------------------------

## What the guest was last told, and when. Host-side only.
var _wind_told: Vector2 = Vector2.ZERO
var _wind_told_at: float = -1000.0
## What a guest has been told to ease toward.
var _wind_wanted: Vector2 = Vector2.ZERO
var _wind_heard: bool = false
## What the foliage was last leaned to. Every plant on the field shares a
## handful of materials, so this is two parameter writes rather than a per-plant
## cost - but it is not free, and a wind that wanders continuously would pay it
## every frame for a change no eye can see.
var _wind_drawn: Vector2 = Vector2(9.0, 9.0)
## The gust, kept for the drawing. Simulated on every machine from its own
## clock rather than told, which is the whole reason it is separate from
## `RunState.wind`.
var _gusted: Vector2 = Vector2.ZERO


## Publish the wind, and tell the other machines when it has moved enough to
## be worth a message.
##
## **The wind travels; nothing it moves does.** A leaf, a blade of grass, a
## drifting mote and the lean of every plant on the field are simulated on each
## machine from these two numbers, which is the whole design: the alternative
## is sending a field of foliage sixty times a second to say something both
## machines could have worked out.
##
## A message goes out when the heading has turned `WIND_RELAY_DEGREES` or the
## strength has moved `WIND_RELAY_STRENGTH` since the last one, and never more
## often than `WIND_RELAY_INTERVAL`. On a clock it would be a steady trickle
## saying nothing; on a threshold it is silent through a settled quarter and
## talks through a turn, which is when it matters.
func _set_wind(blowing: Vector2) -> void:
	if not Coop.is_host():
		# A guest eases toward what it was told rather than deriving its own.
		# The derivation is deterministic and would *usually* agree, and
		# "usually" is not a thing to build a shared fight on: the two clocks
		# start at different moments and a rejoining guest has no history at
		# all.
		if _wind_heard:
			RunState.wind = RunState.wind.lerp(_wind_wanted,
				minf(get_process_delta_time() * Balance.WIND_EASE, 1.0))
			_lean_the_foliage()
		return
	RunState.wind = blowing
	_lean_the_foliage()
	_gusted = wind_gusting()
	var now: float = _clock
	if now - _wind_told_at < Balance.WIND_RELAY_INTERVAL:
		return
	# **Still air says nothing.** A heading is undefined when there is no wind,
	# so an angle comparison against a zero vector has to fall back to "it
	# turned as far as it could" - and with the wind at rest on both sides that
	# fires every interval forever, which is a clock wearing a threshold's
	# clothes. Measured at two messages a second over ten minutes of dead calm,
	# against the two and a bit a pure clock would have sent.
	if blowing == Vector2.ZERO and _wind_told == Vector2.ZERO:
		return
	var turned: float = absf(wrapf(blowing.angle() - _wind_told.angle(), -PI, PI)) \
		if _wind_told != Vector2.ZERO and blowing != Vector2.ZERO else PI
	var changed: float = absf(blowing.length() - _wind_told.length())
	if turned < deg_to_rad(Balance.WIND_RELAY_DEGREES) \
			and changed < Balance.WIND_RELAY_STRENGTH:
		return
	_wind_told = blowing
	_wind_told_at = now
	EventBus.wind_changed.emit(blowing)


## A guest hearing the host's wind. Eased into rather than applied.
func _on_wind_elsewhere(blowing: Vector2) -> void:
	hear_wind(blowing)


func hear_wind(blowing: Vector2) -> void:
	_wind_wanted = blowing
	if not _wind_heard:
		# The first one lands outright: easing from a stale zero would leave a
		# rejoining guest walking through still air for a second.
		RunState.wind = blowing
	_wind_heard = true


## For the gate: what the host has actually put on the wire.
func wind_told() -> Vector2:
	return _wind_told


## Lean every plant on the field into the wind, when it has moved enough to see.
##
## **Local on both machines, always.** This is the half of the design the brief
## is most specific about: the wind travels and nothing it moves does. A guest
## running this off its own eased copy is a frame or two behind the host on the
## angle of a fern, which is not a thing anyone can perceive and is the reason
## no foliage state has to cross the wire at all.
func _lean_the_foliage() -> void:
	# The gust belongs here and nowhere else: this is the drawing.
	var showing: Vector2 = wind_gusting() if Coop.is_host() else RunState.wind
	if showing.distance_to(_wind_drawn) < 0.02:
		return
	_wind_drawn = showing
	Foliage.set_wind_vector(showing)


# --- Publishing -----------------------------------------------------------------

## Writes what the sky is doing where everything reads it.
func _publish(force: bool) -> void:
	_set_wind(wind())
	RunState.rain_scale = _scale if _falling() or forced_intensity >= 0.0 else 1.0
	RunState.rain_intensity = intensity()
	RunState.storm_charge = _charge
	RunState.temperature = _temperature
	RunState.wrath = wrath()
	if force:
		RunState.flood = _flood


## The host tells the guest the four numbers, twice a second.
func _tick_sync(delta: float) -> void:
	if not (Coop.is_host() and Coop.partner_present()):
		return
	_sync_timer -= delta
	if _sync_timer > 0.0:
		return
	_sync_timer = Balance.SKY_SYNC_INTERVAL
	EventBus.coop_sky_clock.emit(RunState.rain_scale, _flood, _charge, _temperature)


## A guest writes what it was told.
func _on_sky_clock(rain_scale: float, flood: float, charge: float, temperature: float) -> void:
	if not _mirror:
		return
	_scale = rain_scale
	_charge = charge
	_temperature = temperature
	_flood = clampf(flood, 0.0, 1.0)
	RunState.rain_scale = rain_scale
	RunState.rain_intensity = intensity()
	RunState.storm_charge = charge
	RunState.temperature = temperature
	RunState.flood = _flood
	if absf(_flood - _flood_told) > 0.004:
		_flood_told = _flood
		EventBus.flood_changed.emit(_flood)


## What the HUD says, and when it is worth saying out loud.
func _tick_announcements(delta: float) -> void:
	_announce_timer += delta
	if _announce_timer < 1.0:
		return
	_announce_timer = 0.0
	EventBus.sky_changed.emit(_temperature, _trend, _flood, _charge)
	if _flood >= Balance.FLOOD_ANNOUNCE and not _flood_announced:
		_flood_announced = true
		if _weather != null and not _weather.flood_line.is_empty():
			EventBus.sky_warned.emit(_weather.flood_line, _weather.flood_title)
	elif _flood < Balance.FLOOD_ANNOUNCE * 0.5:
		_flood_announced = false
	if RunState.well_evaporation() > 0.0 and not _wells_announced:
		_wells_announced = true
		if _weather != null and not _weather.heat_line.is_empty():
			EventBus.sky_warned.emit(_weather.heat_line, _weather.heat_title)


# --- The look of it ----------------------------------------------------------------

## Standing water over the field, rising with the flood.
##
## A quad over the ground with a shader that puddles first and sheets later:
## at a low level only the hollows hold water, at the top the whole field is
## a shallow lake with the road just under it. Skipped headless, like every
## shader here, and photographed by `sky_shot`.
func _build_sheen() -> void:
	_sheen = ColorRect.new()
	_sheen.name = "FloodSheen"
	_sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reach: float = BattleGrid.HALF_EXTENT + Balance.TREELINE_RING
	_sheen.size = Vector2.ONE * reach * 2.0
	_sheen.position = -Vector2.ONE * reach
	_sheen.z_index = Balance.FLOOD_SHEEN_Z
	_sheen.z_as_relative = false
	_sheen.visible = false
	if DisplayServer.get_name() != "headless":
		_sheen_material = ShaderMaterial.new()
		_sheen_material.shader = load("res://scripts/shaders/flood_sheen.gdshader")
		_sheen_material.set_shader_parameter("level", 0.0)
		_sheen_material.set_shader_parameter("tint", Balance.FLOOD_TINT)
		_sheen_material.set_shader_parameter("peak_alpha", Balance.FLOOD_SHEEN_ALPHA)
		_sheen_material.set_shader_parameter("puddle_from", Balance.CLIMATE_PUDDLE_FROM)
		_sheen_material.set_shader_parameter("puddle_level", Balance.CLIMATE_PUDDLE_LEVEL)
		# Wet ground puddles before the flood rises: the water reads the
		# climate's own picture, which spans the same square.
		if field != null and field.climate() != null:
			_sheen_material.set_shader_parameter("wet_tex", field.climate().texture())
		_sheen.material = _sheen_material
	else:
		_sheen.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_sheen)


func _drive_visuals(_delta: float) -> void:
	if _sheen == null:
		return
	var puddled: bool = field != null and field.climate() != null \
		and field.climate().wettest() > Balance.CLIMATE_PUDDLE_FROM
	_sheen.visible = (_flood > 0.01 or puddled) and _sheen_material != null
	if _sheen_material != null:
		_sheen_material.set_shader_parameter("level", _flood)
		_sheen_material.set_shader_parameter("rain", clampf(RunState.rain_intensity, 0.0, 1.0))
		_sheen_material.set_shader_parameter("refracts", Graphics.water_refraction())


# --- For the rest of the game, and the gate --------------------------------------------

func flood() -> float:
	return _flood


func charge() -> float:
	return _charge


func temperature() -> float:
	return _temperature


func rain_scale() -> float:
	return _scale


## The chance per second of a strike right now, for the gate and the HUD.
func hazard_now() -> float:
	return _hazard()


# --- The earth's wrath -------------------------------------------------------------------

## What the earth holds against the road, 0..`WRATH_CAP`.
func wrath() -> float:
	return clampf(_wrath_floor + _wrath_heat, 0.0, Balance.WRATH_CAP)


## A wildlife kill by a player or an enemy. Predators killing prey never
## reach here - `Wildlife` announces only the kills that were not the cycle.
func _on_wildlife_killed(_kind_id: String, _food: int, at: Vector2, rarity: int, shiny: bool, grave: bool) -> void:
	if _mirror:
		return
	var scale: float = float(Balance.WRATH_RARITY_SCALE[clampi(rarity, 0, Balance.WRATH_RARITY_SCALE.size() - 1)])
	if shiny:
		scale *= Balance.WRATH_SHINY_SCALE
	if grave:
		scale *= Balance.WRATH_ELITE_KILL_SCALE
	_count_kill(scale)
	# A legendary is a moment the world notices: the shock, and the signs.
	if rarity >= WildlifeData.Rarity.LEGENDARY:
		shocks += 1
		_shock_left = Balance.WRATH_SHOCK_SECONDS
		_tell("legendary_slain", at, Balance.WRATH_SHOCK_SECONDS)


## A worse kill: an elite, a savage. The gate calls it.
func note_grave_kill() -> void:
	if _mirror:
		return
	_count_kill(Balance.WRATH_ELITE_KILL_SCALE)


func _count_kill(scale: float) -> void:
	_wrath_floor = minf(_wrath_floor + Balance.WRATH_FLOOR_PER_KILL * scale, Balance.WRATH_FLOOR_CAP)
	_wrath_heat += Balance.WRATH_HEAT_PER_KILL * scale
	_quiet = 0.0


## A tree felled. A few are the road living; more than that inside the
## window is clear-cutting, and the earth counts it.
func _on_gathered(material_id: String, _amount: int) -> void:
	if _mirror or not material_id.ends_with("_log"):
		return
	_fells.append(_clock)
	while not _fells.is_empty() and _clock - _fells[0] > Balance.WRATH_FELL_WINDOW:
		_fells.pop_front()
	_quiet = 0.0
	if _fells.size() > Balance.WRATH_FELL_FREE:
		_wrath_heat += Balance.WRATH_PER_FELL


## How many living legendaries steady the road right now.
func anchors() -> int:
	var animals: Wildlife = field.wildlife() if field != null else null
	return animals.living_legendaries() if animals != null else 0


## What the earth's hazards are multiplied by this moment: the legendary
## shock lifts them, every anchor standing calms them.
func hazard_boost() -> float:
	var boost: float = Balance.WRATH_SHOCK_HAZARD if _shock_left > 0.0 else 1.0
	return boost / (1.0 + float(anchors()) * Balance.WRATH_ANCHOR_CALM)


## The wind over the field: the weather's own along the road, wandering on
## a slow clock and gusting, and still for a while after a legendary dies.
## The wind, as a heading and a strength.
##
## **It blows from any quarter now** (owner brief, 2026-09-15). It used to be
## the weather's own east-west `wind` with half a radian of wander, which is a
## fine thing for a wildfire to drift along and a poor thing to walk into: on a
## map with four roads pointing four ways, a wind that only ever blew along one
## axis would hurry two lanes and hold two back for the whole run.
##
## So the heading settles on a quarter, holds it for `WIND_QUARTER_SECONDS`,
## and turns to another over `WIND_TURN_SECONDS` - a turn rather than a switch,
## because a wind that snapped through ninety degrees is a state change and not
## weather. Around the settled quarter it wanders by up to
## `WIND_CARDINAL_WANDER_DEGREES` and gusts on its own faster clock.
##
## **Deterministic from the run's clock and its own phases**, like the rest of
## this file, so the host pays no roll for it. That is not what makes a guest
## agree, though - see `_relay_wind`: the moment the wind started moving
## characters it became a fact, and a fact is told rather than re-derived.
func wind() -> Vector2:
	if _wind_still_left > 0.0 or _weather == null:
		return Vector2.ZERO
	var strength: float = clampf(absf(_weather.wind), 0.0, 1.0)
	if is_zero_approx(strength):
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(wind_heading()) * strength


## The wind with its gust on it, which is what things *look* like.
##
## **The gust is deliberately not in `wind()`.** It breathes at
## `WIND_GUST_RATE`, which is fast enough that the strength crosses the relay's
## threshold several times a second - measured at two messages a second over
## ten minutes, against the two and a bit a pure clock would have sent, so the
## threshold was doing no work at all and the wire was carrying a sine wave.
##
## A gust is also the one part of the wind nobody needs to agree about: it is
## thirty percent of a push that is capped at a tenth, so two machines a
## half-breath apart differ by three percent of a walking speed for a second.
## So the settled wind is the fact - it pushes characters, it travels, the
## wildfire drifts along it - and the gust is drawn on top of it locally from
## each machine's own clock. Both halves get to be honest.
func wind_gusting() -> Vector2:
	var settled: Vector2 = wind()
	if settled == Vector2.ZERO:
		return settled
	return settled * (1.0 + Balance.WIND_GUST_SHARE
		* sin(_clock * Balance.WIND_GUST_RATE + _phases.y))


## Which way the wind is blowing, in radians, before the gust.
##
## Separate from `wind()` so the gate can read the heading without the gust
## riding on it: a turn and a breath are different claims and a test that can
## only see their product cannot check either.
func wind_heading() -> float:
	if _weather == null:
		return 0.0
	# Which quarter, and how far through the turn into it. The sequence is a
	# function of the index rather than a walk, so any moment can be asked for
	# without replaying the ones before it - which is what lets a rejoining
	# guest and a gate both start in the middle.
	var hold: float = maxf(Balance.WIND_QUARTER_SECONDS, 1.0)
	var index: int = int(floor(_clock / hold))
	var into: float = _clock - float(index) * hold
	var from_angle: float = _quarter(index - 1)
	var to_angle: float = _quarter(index)
	# The short way round, so a turn from north to west goes through the west
	# and not three times round the compass.
	var swing: float = wrapf(to_angle - from_angle, -PI, PI)
	# **The rate is constant, not the duration.** `WIND_TURN_SECONDS` is how
	# long a *quarter* takes; a reversal is two quarters and takes twice as
	# long. Fixed-duration turns made a half-circle swing round at twice the
	# speed of a quarter one, which the gate caught by measuring the worst jump
	# in a tenth of a second - and a wind that reverses in the time another one
	# takes to shift a quarter is not weather.
	var takes: float = maxf(Balance.WIND_TURN_SECONDS, 0.001) \
		* absf(swing) / (PI * 0.5)
	var turning: float = clampf(into / maxf(takes, 0.001), 0.0, 1.0)
	var settled: float = from_angle + swing * smoothstep(0.0, 1.0, turning)
	# The sign of the weather's own wind still decides which side it favours,
	# so a weather authored as a westerly still reads as one.
	var lean: float = 0.0 if _weather.wind >= 0.0 else PI
	return settled + lean \
		+ sin(_clock * 0.05 + _phases.x) * deg_to_rad(Balance.WIND_CARDINAL_WANDER_DEGREES)


## The cardinal the wind settles on for a given quarter of the run's clock.
##
## Hashed from the index and the run's own phase rather than drawn, so it costs
## no roll, never disturbs another stream (the lesson `decoration-needs-its-own-
## RNG-stream` cost this project), and gives the same answer on every machine.
func _quarter(index: int) -> float:
	var seeded: int = abs(hash(Vector2i(index, int(_phases.z * 1000.0))))
	return float(seeded % 4) * PI * 0.5


## The heat cools, the fire's ash and the storm's wind settle.
func _tick_wrath(delta: float) -> void:
	var half: float = maxf(Balance.WRATH_HEAT_HALF_LIFE, 1.0)
	_wrath_heat *= pow(0.5, delta / half)
	_shock_left = maxf(_shock_left - delta, 0.0)
	_wind_still_left = maxf(_wind_still_left - delta, 0.0)
	_quiet += delta
	# The elements' strain feeds the anger by its share of full, each
	# settling on its own clock: fire cools, faster in the rain; air is
	# volatile; water drains unless a flood stands; the ground remembers.
	var strain: float = RunState.ember / Balance.EMBER_FULL + RunState.gale / Balance.GALE_FULL \
		+ RunState.tide / Balance.TIDE_FULL + RunState.tremor / Balance.TREMOR_FULL
	_wrath_heat += strain * Balance.WRATH_STRAIN_PER_SECOND * delta
	var rain: float = clampf(RunState.rain_intensity, 0.0, 1.0)
	RunState.ember = maxf(RunState.ember - Balance.EMBER_DECAY_PER_SECOND
		* (1.0 + rain * Balance.EMBER_RAIN_DECAY_SCALE) * delta, 0.0)
	RunState.gale = maxf(RunState.gale - Balance.GALE_DECAY_PER_SECOND * delta, 0.0)
	if RunState.flood < Balance.FLOOD_KNEE:
		RunState.tide = maxf(RunState.tide - Balance.TIDE_DECAY_PER_SECOND * delta, 0.0)
	RunState.tremor = maxf(RunState.tremor - Balance.TREMOR_DECAY_PER_SECOND * delta, 0.0)
	# A forest burnt by the player's own fire.
	if wildfire != null and wildfire.burnt_by_player > _burnt_seen:
		_wrath_heat += float(wildfire.burnt_by_player - _burnt_seen) * Balance.WRATH_PER_PLANT_BURNT
		_burnt_seen = wildfire.burnt_by_player
		_quiet = 0.0
	# Left alone long enough, the earth forgets a little - and faster for
	# every legendary still standing on it.
	if _quiet > Balance.WRATH_QUIET_SECONDS:
		_wrath_floor = maxf(_wrath_floor - Balance.WRATH_FLOOR_RECOVERY_PER_SECOND
			* (1.0 + float(anchors())) * delta, 0.0)
	# The signs. Never a number: the birds, the ground, the sky, once each
	# time the anger climbs a step, and again only after it has come down.
	var tier: int = wrath_tier()
	if tier > _tier_told:
		_tier_told = tier
		_tell("unrest_%d" % tier, Vector2.ZERO, 0.0)
	elif tier < _tier_told - 1:
		_tier_told = tier


## The earth's mood in steps, 0 calm to `WRATH_TIERS`. For the signs only;
## nothing shows it as a number.
func wrath_tier() -> int:
	return clampi(int(floor(wrath() / maxf(Balance.WRATH_TIER_STEP, 0.01))), 0, Balance.WRATH_TIERS)


## An act ends: the earth eases and does not forget. Whatever was on its way
## is dropped with the field it was coming to.
func _on_act_started(_act: int, _terrain: String) -> void:
	_quake_warning_left = 0.0
	_quake_pending = -1.0
	_pending_tornado = {}
	_basin_opened = false
	_shock_left = 0.0
	_wind_still_left = 0.0
	_fells.clear()
	_burnt_seen = 0
	if _mirror:
		return
	_wrath_floor *= Balance.WRATH_ACT_CARRY
	_wrath_heat *= Balance.WRATH_ACT_CARRY
	_tier_told = mini(_tier_told, wrath_tier())


## Whether the earth answers this frame, and how.
func _tick_wrath_events(delta: float) -> void:
	var anger: float = wrath()
	# Lifted by the legendary shock, calmed by every anchor standing.
	var boost: float = hazard_boost()
	# A quake: the square, so a calm earth never shakes. Warned first.
	if _quake_left <= 0.0 and _quake_warning_left <= 0.0 \
			and _rng.randf() < Balance.QUAKE_RATE * anger * anger * boost * delta:
		warn_quake(lerpf(0.35, 1.0, clampf(anger / Balance.WRATH_CAP, 0.0, 1.0)))
	# A wildfire: an angry earth, and ground dry enough where it tries. A
	# flood stops it at the source; `start_wildfire` asks the ground.
	if wildfire != null and RunState.flood <= Balance.WILDFIRE_FLOOD_STOPS \
			and _rng.randf() < Balance.WILDFIRE_RATE * anger * boost * delta:
		start_wildfire()
	# A tornado: the earth's anger, or the storm towers' own running.
	var whirl: float = anger + clampf(RunState.gale / Balance.GALE_FULL, 0.0, 1.0)
	if _pending_tornado.is_empty() and _rng.randf() < Balance.TORNADO_RATE * whirl * boost * delta:
		warn_tornado()
	# A meteor: the fire towers' recent damage, sharpened by the anger.
	var ash: float = clampf(RunState.ember / Balance.EMBER_FULL, 0.0, 1.0)
	if ash > 0.0 and _rng.randf() < Balance.METEOR_RATE * ash * (0.3 + anger) * boost * delta:
		drop_meteor()


## The ground shakes: everything alive is hurt by the magnitude, and the
## screen with it.
func quake(magnitude: float) -> void:
	quakes += 1
	_quake_magnitude = clampf(magnitude, 0.0, 1.0)
	_quake_left = Balance.QUAKE_SECONDS
	if field != null and not _mirror:
		var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
			Balance.WAVE_ACT_HP_SCALE.size() - 1)]
		for enemy: Enemy in field.enemies_near(Vector2.ZERO, INF):
			enemy.take_damage(Balance.QUAKE_ENEMY_DAMAGE * act_scale * _quake_magnitude, enemy.global_position, 0.0)
		var hero_pool: float = 100.0
		if field.hero != null and field.hero.health != null:
			hero_pool = field.hero.health.max_hp
		EnemyGroundStrike.strike_the_players(get_tree(), hero_pool * Balance.QUAKE_HERO_SHARE * _quake_magnitude,
			"earthquake", func(_where: Vector2) -> bool: return true)
		# Every tower standing is shaken; a chip by the magnitude, never a fall.
		for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
			var tower := node as Tower
			if tower != null and is_instance_valid(tower) and tower.is_vulnerable():
				tower.hurt(Balance.QUAKE_TOWER_DAMAGE * _quake_magnitude, tower.global_position)
		var animals: Wildlife = field.wildlife()
		if animals != null:
			animals.wound_within(Vector2.ZERO, INF, Balance.QUAKE_WILDLIFE_DAMAGE * _quake_magnitude, false)
			animals.scare_from(Vector2.ZERO, INF)
		# The fault it opens: charged ground for the earth towers, and a
		# line of cracks across it that stays.
		var fault: Vector2 = _pick_strike_point(_zone_rng)
		if zones != null:
			zones.open("seismic_fault", fault, Balance.ZONE_FAULT_RADIUS)
		if marks != null:
			var along: Vector2 = Vector2.RIGHT.rotated(_zone_rng.randf() * TAU)
			for step: int in 5:
				marks.stamp(fault + along * (float(step) - 2.0) * Balance.ZONE_FAULT_RADIUS * 0.3,
					34.0, 0.35 * _quake_magnitude)
	if not _mirror:
		EventBus.earthquake.emit(_quake_magnitude, Balance.QUAKE_SECONDS)


func _on_earthquake_seen(magnitude: float, seconds: float) -> void:
	RunState.note_earth("quakes")
	if _mirror:
		_quake_magnitude = magnitude
		_quake_left = seconds
	EventBus.camera_shake_requested.emit(magnitude * Balance.QUAKE_SHAKE, seconds)
	Sfx.play("sfx_quake", 0.0)


## Tremors while it lasts: dust thrown up around whoever is watching.
func _tick_quake(delta: float) -> void:
	if _quake_left <= 0.0:
		return
	_quake_left -= delta
	_tremor_timer -= delta
	if _tremor_timer <= 0.0:
		_tremor_timer = 0.3
		var around: Vector2 = field.hero.global_position if field != null and field.hero != null else Vector2.ZERO
		for _i: int in 3:
			Vfx.dust(around + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 420.0,
				Color(0.36, 0.3, 0.24), 4, 40.0 + 30.0 * _quake_magnitude)
		EventBus.camera_shake_requested.emit(_quake_magnitude * Balance.QUAKE_SHAKE * 0.6, 0.35)


## A fire somewhere in the foliage, away from the city.
func start_wildfire() -> bool:
	if wildfire == null:
		return false
	for _attempt: int in 8:
		var at: Vector2 = _pick_strike_point()
		# Dry ground catches; soaked ground refuses, however angry the earth.
		if _rng.randf() > _dryness_at(at):
			continue
		if wildfire.ignite_near(at, Balance.WILDFIRE_SPREAD_RADIUS * 2.0, 1.0):
			wildfires += 1
			_tell("wildfire", at, 0.0)
			return true
	return false


## How readily the brush burns at a point: the ground's own answer where
## there is a climate, the sky's where there is not.
func _dryness_at(at: Vector2) -> float:
	if field != null and field.climate() != null:
		return field.climate().dryness_at(at)
	var dry: float = clampf(1.0 - RunState.rain_intensity * 2.0, 0.0, 1.0)
	if RunState.temperature > Balance.WILDFIRE_HOT_FROM:
		dry *= Balance.WILDFIRE_HOT_SPREAD
	return dry


## A strike with no rain on it lights the brush (ChatGPT notes: "Drought +
## Lightning"). Under a heatwave, much more often.
func _dry_lightning(at: Vector2) -> void:
	if wildfire == null or RunState.rain_intensity > 0.05 or RunState.flood > Balance.WILDFIRE_FLOOD_STOPS:
		return
	# The ground under the strike: soaked ground does not catch.
	var ground: Climate = field.climate() if field != null else null
	if ground != null and ground.wetness_at(at) > Balance.CLIMATE_WET_BANDS[0] * 1.75:
		return
	var chance: float = Balance.LIGHTNING_IGNITE_CHANCE
	var degrees: float = ground.temperature_at(at) if ground != null else RunState.temperature
	if degrees > Balance.WILDFIRE_HOT_FROM:
		chance *= Balance.LIGHTNING_IGNITE_HOT_SCALE
	if wildfire.ignite_near(at, Balance.LIGHTNING_RADIUS, chance):
		wildfires += 1
		_tell("wildfire", at, 0.0)


# --- Telegraphs ------------------------------------------------------------------------------

## The ground hums before it breaks: announced, felt, and then the quake.
func warn_quake(magnitude: float) -> void:
	if _quake_warning_left > 0.0:
		return
	_quake_pending = clampf(magnitude, 0.0, 1.0)
	_quake_warning_left = Balance.QUAKE_WARNING_SECONDS
	_warn_tremor_timer = 0.0
	_tell("quake", Vector2.ZERO, Balance.QUAKE_WARNING_SECONDS)


## The wind rises at the edge before the funnel is born there.
func warn_tornado(from: Vector2 = Vector2.INF, target: Vector2 = Vector2.INF, seconds: float = -1.0) -> void:
	if not _pending_tornado.is_empty():
		return
	var reach: float = BattleGrid.HALF_EXTENT * 0.95
	if not from.is_finite():
		from = Vector2.RIGHT.rotated(_rng.randf() * TAU) * reach
	if not target.is_finite():
		target = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)) * reach
	if seconds < 0.0:
		seconds = Balance.TORNADO_SECONDS
	_pending_tornado = {"from": from, "target": target, "seconds": seconds,
		"left": Balance.TORNADO_WARNING_SECONDS, "spawn": true, "gust": 0.0}
	_tell("tornado", from, Balance.TORNADO_WARNING_SECONDS)


## Says a warning here and tells the guest, who says it there.
func _tell(kind_id: String, at: Vector2, seconds: float) -> void:
	_show_warning(kind_id, at, seconds)
	if not _mirror:
		EventBus.wrath_warned.emit(kind_id, at, seconds)


func _on_warned_elsewhere(kind_id: String, at: Vector2, seconds: float) -> void:
	if not _mirror:
		return
	_show_warning(kind_id, at, seconds)
	# The guest runs the tell and not the event: the quake and the funnel
	# arrive as facts of their own when the host's clock runs out.
	match kind_id:
		"quake":
			_quake_pending = -1.0
			_quake_warning_left = seconds
			_warn_tremor_timer = 0.0
		"tornado":
			_pending_tornado = {"from": at, "target": at, "seconds": 0.0, "left": seconds,
				"spawn": false, "gust": 0.0}


## The line and the animals: what a warning is on every machine. A kind with
## no warning of its own says its announcement, which is what the signs do.
func _show_warning(kind_id: String, at: Vector2, _seconds: float) -> void:
	var kind: WrathEventData = ContentDB.wrath_event(kind_id)
	if kind == null:
		return
	if kind_id == "wildfire":
		RunState.note_earth("wildfires")
	var telegraphed: bool = not kind.warning.is_empty()
	var line: String = kind.warning if telegraphed else kind.announce
	var title: String = kind.warning_title if telegraphed else kind.announce_title
	if not line.is_empty():
		EventBus.sky_warned.emit(line, title)
	# A legendary dead: the wind stops, the light goes strange for a beat,
	# the ambience drops and comes back. On every machine.
	if kind_id == "legendary_slain":
		_wind_still_left = Balance.WRATH_STILL_SECONDS
		Vfx.flash(Color(0.04, 0.02, 0.08), 0.42, 1.6)
		Sfx.play("sfx_thunder_far", -4.0)
		var bus: int = AudioServer.get_bus_index(AudioBuses.AMBIENCE)
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, AudioServer.get_bus_volume_db(bus) - 14.0)
			get_tree().create_timer(Balance.WRATH_STILL_SECONDS * 0.75).timeout.connect(
				func() -> void: AudioBuses.apply_volumes())
	# The animals run from what is coming; a sign of the earth's mood, with
	# nothing behind it yet, only quiets them.
	if field != null and not _mirror and _seconds > 0.0:
		var animals: Wildlife = field.wildlife()
		if animals != null:
			animals.scare_from(at, INF if kind_id == "quake" else 700.0)


## The tells run down: the hum grows into the quake, the gust into the funnel.
func _tick_warnings(delta: float) -> void:
	if _quake_warning_left > 0.0:
		_quake_warning_left -= delta
		var progress: float = 1.0 - _quake_warning_left / maxf(Balance.QUAKE_WARNING_SECONDS, 0.1)
		_warn_tremor_timer -= delta
		if _warn_tremor_timer <= 0.0:
			_warn_tremor_timer = 0.32
			EventBus.camera_shake_requested.emit(Balance.QUAKE_SHAKE * 0.12 * (0.3 + progress), 0.3)
			var around: Vector2 = field.hero.global_position if field != null and field.hero != null else Vector2.ZERO
			Vfx.dust(around + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 360.0,
				Color(0.4, 0.34, 0.27), 3, 30.0)
		if _quake_warning_left <= 0.0 and _quake_pending >= 0.0:
			var magnitude: float = _quake_pending
			_quake_pending = -1.0
			quake(magnitude)
	if not _pending_tornado.is_empty():
		_pending_tornado["left"] = float(_pending_tornado["left"]) - delta
		_pending_tornado["gust"] = float(_pending_tornado["gust"]) - delta
		if float(_pending_tornado["gust"]) <= 0.0:
			_pending_tornado["gust"] = 0.22
			var from: Vector2 = _pending_tornado["from"]
			var toward: Vector2 = ((_pending_tornado["target"] as Vector2) - from).normalized()
			# Dust streaking in from where it will come, further each gust.
			var along: float = (1.0 - float(_pending_tornado["left"]) / maxf(Balance.TORNADO_WARNING_SECONDS, 0.1)) * 900.0
			Vfx.dust(from + toward * along + toward.orthogonal() * _rng.randf_range(-260.0, 260.0),
				Color(0.5, 0.45, 0.36), 4, 60.0)
		if float(_pending_tornado["left"]) <= 0.0:
			var pending: Dictionary = _pending_tornado
			_pending_tornado = {}
			if bool(pending["spawn"]):
				spawn_tornado(pending["from"], pending["target"], float(pending["seconds"]))


## A funnel from the edge of the field, heading for a point inside it.
func spawn_tornado(from: Vector2 = Vector2.INF, target: Vector2 = Vector2.INF,
		seconds: float = -1.0) -> Tornado:
	if field == null:
		return null
	var reach: float = BattleGrid.HALF_EXTENT * 0.95
	if not from.is_finite():
		var edge: Vector2 = Vector2.RIGHT.rotated(_rng.randf() * TAU)
		from = edge * reach
	if not target.is_finite():
		target = Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6)) * reach
	if seconds < 0.0:
		seconds = Balance.TORNADO_SECONDS
	var funnel := Tornado.new()
	funnel.at = from
	funnel.seconds_left = seconds
	funnel.field = field
	funnel.aim_at(target)
	field.add_child(funnel)
	tornadoes += 1
	RunState.note_earth("tornadoes")
	if not _mirror:
		EventBus.tornado_spawned.emit(from, target, seconds)
	return funnel


func _on_tornado_elsewhere(at: Vector2, target: Vector2, seconds: float) -> void:
	if _mirror:
		spawn_tornado(at, target, seconds)


## A stone aimed near one of the player's towers - or, with none built, near
## the road they are standing on.
func drop_meteor(at: Vector2 = Vector2.INF) -> Meteor:
	if field == null:
		return null
	if not at.is_finite():
		var towers: Array = get_tree().get_nodes_in_group(Tower.GROUP)
		var anchor: Vector2 = field.hero.global_position if field.hero != null else Vector2.ZERO
		if not towers.is_empty():
			var picked := towers[_rng.randi_range(0, towers.size() - 1)] as Node2D
			if picked != null:
				anchor = picked.global_position
		at = anchor + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() \
			* _rng.randf_range(Balance.METEOR_SCATTER * 0.3, Balance.METEOR_SCATTER)
		if at.length() < Balance.LIGHTNING_TOWN_CLEARANCE:
			at = at.normalized() * Balance.LIGHTNING_TOWN_CLEARANCE
	var stone := Meteor.new()
	stone.at = at
	stone.field = field
	stone.wildfire = wildfire
	stone.marks = marks
	field.add_child(stone)
	meteors += 1
	RunState.note_earth("meteors")
	if not _mirror:
		EventBus.meteor_incoming.emit(at)
	return stone


func _on_meteor_elsewhere(at: Vector2) -> void:
	if _mirror:
		drop_meteor(at)


## The arc from a strike to the bodies near it, and on from them.
##
## Dry ground carries it a little way to a few; a flood carries it far and to
## many, which is what standing in water during a storm ought to cost. Each
## arc is worth a share of the last, so the tail of a chain is a sting.
func _chain(from: Vector2, already: Array[Enemy], damage: float) -> void:
	if field == null:
		return
	var flood: float = clampf(RunState.flood, 0.0, 1.0)
	var range_now: float = Balance.CHAIN_RANGE * (1.0 + flood * Balance.CHAIN_FLOOD_RANGE)
	var jumps: int = Balance.CHAIN_JUMPS + int(round(flood * float(Balance.CHAIN_FLOOD_JUMPS)))
	var struck: Array[Enemy] = already.duplicate()
	var here: Vector2 = from
	var worth: float = damage
	# The body the arc leaves from: wet, it carries the arc further.
	var carrier: Enemy = already.back() if not already.is_empty() else null
	for _jump: int in jumps:
		worth *= Balance.CHAIN_FALLOFF
		var next: Enemy = null
		var reach_now: float = range_now
		if carrier != null and is_instance_valid(carrier) and carrier.is_wet():
			reach_now *= Balance.WET_CHAIN_RANGE
		var nearest: float = reach_now
		for enemy: Enemy in field.enemies_near(here, reach_now):
			if enemy in struck:
				continue
			var away: float = enemy.global_position.distance_to(here)
			if away < nearest:
				nearest = away
				next = enemy
		if next == null:
			break
		struck.append(next)
		var to: Vector2 = next.combat_origin()
		next.take_damage(worth * next.shock_scale(), here, 0.0)
		carrier = next
		chain_arcs += 1
		var arc: Line2D = _bolt_line(_jagged(here, to, 6, 22.0), 4.0, 0.9)
		if _bolts != null:
			_bolts.add_child(arc)
			var fade: Tween = create_tween()
			fade.tween_interval(0.12)
			fade.tween_callback(arc.queue_free)
		Vfx.flash_at(to, Balance.LIGHTNING_COLOUR, 34.0)
		here = to
	var animals: Wildlife = field.wildlife()
	if animals != null and flood > 0.0:
		animals.wound_within(from, range_now, Balance.LIGHTNING_WILDLIFE_DAMAGE * 0.5, false)


## For the gate: how many arcs the last strikes threw.
var chain_arcs: int = 0
