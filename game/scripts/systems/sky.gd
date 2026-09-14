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

var _sheen: ColorRect = null
var _sheen_material: ShaderMaterial = null
var _bolts: Node2D = null


func _ready() -> void:
	name = "Sky"
	z_as_relative = false
	_rng = RunState.rng("sky")
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
	EventBus.lightning_struck.connect(_on_lightning_seen)
	_apply(ContentDB.weather(RunState.weather_id))
	_temperature = _temperature_target
	_publish(true)


func _process(delta: float) -> void:
	if _mirror:
		_drive_visuals(delta)
		return
	_clock += delta
	_tick_rain(delta)
	_tick_flood(delta)
	_tick_charge(delta)
	_tick_lightning(delta)
	_tick_temperature(delta)
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
		var high: float = lerpf(1.0, Balance.SKY_RAIN_SCALE_RANGE.y, swing)
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
func _pick_strike_point() -> Vector2:
	var reach: float = BattleGrid.HALF_EXTENT * 0.86
	for _attempt: int in 12:
		var at := Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach))
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
		for enemy: Enemy in field.enemies_near(at, radius):
			enemy.take_damage(Balance.LIGHTNING_ENEMY_DAMAGE * act_scale, at, 0.0)
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
	EventBus.lightning_struck.emit(at, radius)


## The picture of a strike, on every machine that hears of one.
func _on_lightning_seen(at: Vector2, radius: float) -> void:
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
	var lines: Array[Line2D] = [_bolt_line(main, 7.0, 1.0)]
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
	base += Balance.SKY_TEMPERATURE_NIGHT * DayNight.darkness
	base += Balance.SKY_TEMPERATURE_RAIN * intensity()
	return base


func _tick_temperature(delta: float) -> void:
	_temperature_target = _target_temperature()
	_temperature = lerpf(_temperature, _temperature_target,
		minf(delta * Balance.SKY_TEMPERATURE_EASE, 1.0))


# --- Publishing -----------------------------------------------------------------

## Writes what the sky is doing where everything reads it.
func _publish(force: bool) -> void:
	RunState.rain_scale = _scale if _falling() or forced_intensity >= 0.0 else 1.0
	RunState.rain_intensity = intensity()
	RunState.storm_charge = _charge
	RunState.temperature = _temperature
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
		_sheen.material = _sheen_material
	else:
		_sheen.color = Color(0.0, 0.0, 0.0, 0.0)
	add_child(_sheen)


func _drive_visuals(_delta: float) -> void:
	if _sheen == null:
		return
	_sheen.visible = _flood > 0.01 and _sheen_material != null
	if _sheen_material != null:
		_sheen_material.set_shader_parameter("level", _flood)


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
