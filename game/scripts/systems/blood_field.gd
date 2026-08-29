class_name BloodField
extends Node2D

## Blood on the ground, drawn as one canvas rather than one node per splat.
##
## A hit leaves a mark and the mark outlives the hit. That is most of what makes
## a fight read as having happened - the field remembers where the fighting was,
## and a player crossing their own last stand sees it.
##
## **One node, many marks.** The obvious build is a `Polygon2D` per splat with a
## tween on its alpha, which is the idiom everywhere else in `Vfx` and is right
## for a handful of short-lived things. Blood is not a handful: a busy wave puts
## down hundreds, each would be a node in the tree with its own tween, and the
## cap in `Vfx._track` would start evicting live effects to make room for
## bloodstains. So this owns a plain array and paints all of it in one `_draw`.
##
## Redrawn at a fixed low rate rather than every frame. Fading takes many
## seconds; ten steps a second is invisible as motion and is a tenth of the work.

## The oldest marks are dropped first. Generous enough that a long fight leaves a
## real trail, bounded so a whole act cannot accumulate into a slideshow.
const MAX_SPLATS: int = 140

## How often the canvas repaints while anything is fading.
const REDRAW_HZ: float = 10.0

## One mark: where, how big, its blobs, when it was laid down, how long it lasts.
var _splats: Array[Dictionary] = []
var _since_redraw: float = 0.0
var _rain_wash: float = 1.0


func _ready() -> void:
	# Under everything that walks on it, and above the ground it stains.
	z_index = Balance.BLOOD_GROUND_Z
	texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	add_to_group(Graphics.FILTER_GROUP)
	EventBus.weather_changed.connect(_on_weather_changed)
	_on_weather_changed(RunState.weather_id)
	set_process(false)


## Lays a mark down. `heading` biases the spatter the way the blow was going.
func splat(at: Vector2, heading: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var blobs: Array = []
	var count: int = rng.randi_range(Balance.BLOOD_BLOBS_MIN, Balance.BLOOD_BLOBS_MAX)
	var along: Vector2 = heading.normalized() if heading.length_squared() > 0.001 \
		else Vector2.from_angle(rng.randf() * TAU)
	for i: int in count:
		# Most of the mark pools at the point of impact; the rest throws forward
		# along the blow. A perfectly radial splat reads as a stamp rather than
		# as something that happened in a direction.
		var throw: float = pow(rng.randf(), 2.0) * size * Balance.BLOOD_THROW
		var spread: float = rng.randf_range(-0.7, 0.7)
		var offset: Vector2 = along.rotated(spread) * throw \
			+ Vector2.from_angle(rng.randf() * TAU) * rng.randf() * size * 0.28
		blobs.append({
			"at": offset,
			"r": rng.randf_range(size * 0.10, size * 0.30) * (1.0 - throw / (size * 2.0) * 0.4),
		})
	_splats.append({
		"at": at,
		"blobs": blobs,
		"age": 0.0,
		# Life is an authored promise now: every mark that is not displaced by the
		# bounded field survives the full ten-minute memory window. Randomising it
		# below one quietly turned "600 seconds" into as little as eight minutes.
		"life": Balance.BLOOD_GROUND_LIFE,
		"tone": rng.randf(),
	})
	while _splats.size() > MAX_SPLATS:
		_splats.remove_at(0)
	set_process(true)
	queue_redraw()


## One procedural droplet, added when its visible ballistic mote reaches the
## floor. Separate from `splat`: a burst must not stamp a large stain at impact
## before its particles have actually landed.
func droplet(at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	if not bool(UserSettings.value(UserSettings.BLOOD_VFX_KEY, true)):
		return
	_splats.append({
		"at": at,
		"blobs": [{"at": Vector2.ZERO,
			"r": maxf(radius * rng.randf_range(0.78, 1.22), 1.4)}],
		"age": 0.0,
		"life": Balance.BLOOD_GROUND_LIFE,
		"tone": rng.randf(),
	})
	while _splats.size() > MAX_SPLATS:
		_splats.remove_at(0)
	set_process(true)
	queue_redraw()


## How many marks the field is holding. For the gate.
func marks() -> int:
	return _splats.size()


## Current ageing rate, exposed for the release gate.
func wash_multiplier() -> float:
	return _rain_wash


## Clears the field. Called between roads: last week's blood is not this fight.
func wipe() -> void:
	_splats.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for splat: Dictionary in _splats:
		splat["age"] = float(splat["age"]) + delta * _rain_wash
		if float(splat["age"]) < float(splat["life"]):
			alive.append(splat)
	_splats = alive
	if _splats.is_empty():
		set_process(false)
		queue_redraw()
		return
	_since_redraw += delta
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		queue_redraw()


func _on_weather_changed(weather_id: String) -> void:
	var weather: WeatherData = ContentDB.weather(weather_id)
	_rain_wash = Balance.BLOOD_RAIN_WASH_MULTIPLIER \
		if weather != null and weather.precipitation == WeatherData.Precipitation.RAIN \
		else 1.0


func _draw() -> void:
	for splat: Dictionary in _splats:
		var life: float = maxf(float(splat["life"]), 0.01)
		var t: float = clampf(float(splat["age"]) / life, 0.0, 1.0)
		# Holds, then goes. Blood does not begin fading the instant it lands, and
		# a mark that starts disappearing immediately never reads as a stain.
		var alpha: float = Balance.BLOOD_GROUND_ALPHA \
			* (1.0 - smoothstep(Balance.BLOOD_HOLD, 1.0, t))
		if alpha <= 0.004:
			continue
		# Darkens as it dries, which is what sells it as old rather than merely
		# transparent.
		var tone: Color = Balance.BLOOD_FRESH.lerp(Balance.BLOOD_DRY,
			clampf(t * 1.4, 0.0, 1.0) * 0.85 + float(splat["tone"]) * 0.15)
		tone.a = alpha
		var origin: Vector2 = to_local(splat["at"] as Vector2)
		for blob: Variant in (splat["blobs"] as Array):
			var one: Dictionary = blob
			draw_circle(origin + (one["at"] as Vector2), float(one["r"]), tone)
