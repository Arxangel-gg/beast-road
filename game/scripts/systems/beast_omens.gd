class_name BeastOmens
extends Node2D

## What the earth is doing to the town, seen from the road.
##
## **Owner brief, 2026-09-15:** "ways of indicating any natural disasters going
## on on the battlefield also on beastscope view - for example tornado over the
## base, or fire if wildfire, or flooding make water pouring out from the castle
## base on Yuri the beast's back. And earthquake should also have a worldshake
## in beast scope view that also shakes Yuri too. Thunderstorms or lightning
## strikes should also indicate on beast scope view."
##
## **The two scopes are one run, and this is the half that was missing.** A
## tornado tears at the towers whether the player is watching the battlefield or
## the road, and until now switching to the walk was switching the weather off:
## the beast strolled through a clear evening while a wildfire ate the defence
## it was carrying. Nothing about that was wrong in the simulation - the
## battlefield never stopped - but a player on the road had no way to know they
## should go back.
##
## **Everything here is a readout and nothing is a fact.** Not one line of this
## file changes a number, rolls a die or sends a message: it listens to the
## facts the earth already publishes (`EventBus.tornado_spawned` and the rest,
## which are relayed to a guest exactly as they are to the host) and reads
## `RunState` for the standing conditions. Turn this node off and the run is
## identical. That is the same bound the fog of war is held to - it hides and
## never helps - and it is what lets the ten-act curve still be read.
##
## **It draws on the town, not on the screen.** The scope tells it where the
## carried town is each frame, so every indication sits on the thing it is about
## - water pours off the platform's own lip, the funnel stands over the keep -
## rather than being an icon in a corner. A corner icon is a notification; this
## is weather.
##
## One `_draw` for all of it, sampled at `Balance.BEAST_OMEN_HZ` rather than
## every frame: the lesson `flame.gd` cost this project twice.

## Where the carried town is, in this node's space, and how wide it is. Set by
## the scope, which is the only thing that knows where the beast is standing.
var town: Vector2 = Vector2.ZERO
var town_width: float = 260.0
## What the scene is lit by, so a plume at dusk is not a daylight plume.
var light: Color = Color(1.0, 0.86, 0.7, 1.0)

var _time: float = 0.0
var _drawn_at: float = -1.0
var _rng := RandomNumberGenerator.new()

## Each thing the earth is doing, and how long it has left to do it.
var _tornado_left: float = 0.0
var _tornado_burning: bool = false
var _fires: float = 0.0
var _quake_left: float = 0.0
var _quake_magnitude: float = 0.0
var _flash_left: float = 0.0
var _meteor_left: float = 0.0


func _ready() -> void:
	_rng.seed = hash("beast-omens")
	z_as_relative = false
	z_index = Balance.BEAST_OMEN_Z
	EventBus.tornado_spawned.connect(_on_tornado)
	EventBus.tornado_moved.connect(_on_tornado_moved)
	EventBus.wildfire_lit.connect(_on_wildfire)
	EventBus.earthquake.connect(_on_earthquake)
	EventBus.lightning_struck.connect(_on_lightning)
	EventBus.meteor_incoming.connect(_on_meteor)
	set_process(true)


func _on_tornado(_at: Vector2, _target: Vector2, seconds: float) -> void:
	_tornado_left = maxf(_tornado_left, seconds)


func _on_tornado_moved(_at: Vector2, burning: bool) -> void:
	# A funnel that is still reporting its position is still standing, whatever
	# the spawn said its life would be.
	_tornado_left = maxf(_tornado_left, Balance.BEAST_OMEN_TORNADO_HOLD)
	_tornado_burning = burning


func _on_wildfire(_at: Vector2) -> void:
	_fires = minf(_fires + 1.0, Balance.BEAST_OMEN_FIRE_MAX)


func _on_earthquake(magnitude: float, seconds: float) -> void:
	_quake_left = maxf(_quake_left, seconds)
	_quake_magnitude = maxf(_quake_magnitude, magnitude)


func _on_lightning(_at: Vector2, _radius: float) -> void:
	_flash_left = Balance.BEAST_OMEN_FLASH_SECONDS


func _on_meteor(_at: Vector2) -> void:
	_meteor_left = Balance.BEAST_OMEN_METEOR_SECONDS


func _process(delta: float) -> void:
	_time += delta
	_tornado_left = maxf(_tornado_left - delta, 0.0)
	_quake_left = maxf(_quake_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_meteor_left = maxf(_meteor_left - delta, 0.0)
	# Fires fade rather than being counted down one by one: the battlefield
	# reports each plant it lights and never reports one going out, so a decay
	# is the only honest reading of "how much of the road is burning".
	_fires = maxf(_fires - delta * Balance.BEAST_OMEN_FIRE_FADE, 0.0)
	if _quake_left <= 0.0:
		_quake_magnitude = 0.0
	if _time - _drawn_at >= 1.0 / maxf(Balance.BEAST_OMEN_HZ, 1.0):
		_drawn_at = _time
		queue_redraw()


## How hard the world should be shaking, from 0 to 1.
##
## **Read by the scope and applied to the camera *and* to Yuri**, which is the
## owner's point: a quake that only moved the camera would read as the operator
## flinching. The beast is the biggest thing on screen and it has to move.
func quake_shake() -> float:
	if _quake_left <= 0.0:
		return 0.0
	return clampf(_quake_magnitude, 0.0, 1.0)


## Whether anything at all is happening. For the gate, and so the scope can skip
## the whole node on a quiet road.
func anything() -> bool:
	return _tornado_left > 0.0 or _fires > 0.05 or _quake_left > 0.0 \
		or _flash_left > 0.0 or _meteor_left > 0.0 or _flood() > 0.01


## How much water is standing on the battlefield, as a fraction of the knee.
func _flood() -> float:
	return clampf(RunState.flood / maxf(Balance.FLOOD_KNEE, 0.001), 0.0, 1.4)


func _draw() -> void:
	# The sky first, then the town, then what is pouring off it.
	if _meteor_left > 0.0:
		_draw_meteor()
	if _flash_left > 0.0:
		_draw_lightning()
	if _fires > 0.05:
		_draw_fires()
	if _tornado_left > 0.0:
		_draw_tornado()
	if _flood() > 0.01:
		_draw_flood()


## The funnel over the keep.
##
## A stack of ellipses narrowing toward the ground, each offset along its own
## sine, which is the cheapest thing that reads as a rotating column rather than
## a cone. Dust rather than a texture: at this size a painted funnel would be
## eight pixels of smear.
func _draw_tornado() -> void:
	var fade: float = clampf(_tornado_left / Balance.BEAST_OMEN_TORNADO_HOLD, 0.0, 1.0)
	var high: float = town_width * Balance.BEAST_OMEN_TORNADO_HEIGHT
	var foot: Vector2 = town + Vector2(0.0, -town_width * 0.12)
	var dust := Color(0.44, 0.40, 0.36, 0.5 * fade)
	if _tornado_burning:
		# A funnel through a fire carries it, and the field already says so.
		dust = Color(0.62, 0.34, 0.18, 0.62 * fade)
	var rings: int = Balance.BEAST_OMEN_TORNADO_RINGS
	for index: int in rings:
		var up: float = float(index) / float(rings - 1)
		var y: float = foot.y - up * high
		var wide: float = lerpf(town_width * 0.05, town_width * 0.34, pow(up, 0.7))
		var lean: float = sin(_time * 3.1 + up * 5.0) * town_width * 0.05 * up
		var shade: float = 1.0 - up * 0.35
		draw_circle(Vector2(foot.x + lean, y), wide * 0.5,
			Color(dust.r * shade, dust.g * shade, dust.b * shade, dust.a * (0.35 + up * 0.4)))
	# Debris going round it, which is what sells the spin.
	for index: int in Balance.BEAST_OMEN_TORNADO_MOTES:
		var phase: float = _time * 4.2 + float(index) * 1.7
		var up: float = fmod(float(index) / float(Balance.BEAST_OMEN_TORNADO_MOTES)
			+ _time * 0.25, 1.0)
		var wide: float = lerpf(town_width * 0.06, town_width * 0.36, up)
		var at := Vector2(foot.x + cos(phase) * wide * 0.5 + sin(_time * 3.1 + up * 5.0)
			* town_width * 0.05 * up, foot.y - up * high)
		draw_circle(at, maxf(town_width * 0.012, 1.0),
			Color(dust.r, dust.g, dust.b, 0.8 * fade * (1.0 - up * 0.5)))


## Plumes off the burning road, standing on the platform.
func _draw_fires() -> void:
	var plumes: int = clampi(int(ceil(_fires / 2.0)), 1, Balance.BEAST_OMEN_FIRE_PLUMES)
	for index: int in plumes:
		var spread: float = (float(index) / maxf(float(plumes - 1), 1.0) - 0.5)
		if plumes == 1:
			spread = 0.0
		var root: Vector2 = town + Vector2(spread * town_width * 0.6,
			-town_width * 0.06)
		var heat: float = clampf(_fires / Balance.BEAST_OMEN_FIRE_MAX, 0.2, 1.0)
		var high: float = town_width * lerpf(0.12, 0.3, heat)
		# The flame: three tongues on their own clocks.
		for tongue: int in 3:
			var wobble: float = sin(_time * (5.0 + float(tongue)) + float(index) * 2.3)
			var tip: Vector2 = root + Vector2(wobble * town_width * 0.03, -high
				* (0.7 + 0.3 * float(tongue) / 2.0))
			draw_line(root, tip, Color(1.0, 0.55 - 0.12 * float(tongue), 0.18,
				0.72 * heat), maxf(town_width * 0.018, 1.2), true)
		# And the smoke above it, which is what carries at this distance.
		for puff: int in Balance.BEAST_OMEN_SMOKE_PUFFS:
			var rise: float = fmod(float(puff) / float(Balance.BEAST_OMEN_SMOKE_PUFFS)
				+ _time * 0.18 + float(index) * 0.3, 1.0)
			var at: Vector2 = root + Vector2(
				sin(_time * 0.7 + rise * 3.0 + float(index)) * town_width * 0.08 * rise,
				-high - rise * town_width * 0.55)
			draw_circle(at, town_width * (0.02 + rise * 0.05),
				Color(0.22, 0.2, 0.19, 0.34 * heat * (1.0 - rise)))


## Water pouring off the platform's lip.
##
## The owner's own image, and the right one: the town is a walled plate on an
## animal's back, so a flooded battlefield has nowhere to drain except over the
## side. Two to five spouts, each with a splash where it runs out of picture.
func _draw_flood() -> void:
	var depth: float = _flood()
	var spouts: int = clampi(int(ceil(depth * float(Balance.BEAST_OMEN_SPOUTS))),
		1, Balance.BEAST_OMEN_SPOUTS)
	var water := Color(0.58, 0.74, 0.86, clampf(0.35 + depth * 0.3, 0.0, 0.8))
	for index: int in spouts:
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var along: float = (float(index / 2) + 1.0) * 0.22
		var lip: Vector2 = town + Vector2(side * town_width * (0.2 + along),
			-town_width * 0.04)
		var fall: float = town_width * lerpf(0.3, 0.62, depth) \
			* (0.8 + 0.2 * sin(_time * 1.3 + float(index)))
		# A tapering ribbon with a wobble, rather than a straight line: falling
		# water is never a rectangle.
		var points := PackedVector2Array()
		var widths: int = 7
		for step: int in widths:
			var down: float = float(step) / float(widths - 1)
			points.append(lip + Vector2(
				side * town_width * 0.02 * down
					+ sin(_time * 4.0 + down * 6.0 + float(index)) * town_width * 0.012,
				down * fall))
		draw_polyline(points, water, maxf(town_width * 0.022, 1.4), true)
		# The splash at the bottom, drifting as it falls away.
		for drop: int in 4:
			var t: float = fmod(_time * 1.6 + float(drop) * 0.25 + float(index) * 0.4, 1.0)
			draw_circle(points[points.size() - 1] + Vector2(
				side * town_width * 0.05 * t, t * town_width * 0.12),
				maxf(town_width * 0.009, 1.0),
				Color(water.r, water.g, water.b, water.a * (1.0 - t)))


## A strike over the town, and the flash that goes with it.
func _draw_lightning() -> void:
	var fade: float = clampf(_flash_left / Balance.BEAST_OMEN_FLASH_SECONDS, 0.0, 1.0)
	# The bolt is drawn from a fixed seed per strike so it does not crawl while
	# it is on screen - a bolt that redraws itself every frame reads as static.
	var bolt := PackedVector2Array()
	var top: Vector2 = town + Vector2(0.0, -town_width * 1.3)
	var steps: int = 7
	for index: int in steps:
		var down: float = float(index) / float(steps - 1)
		bolt.append(top.lerp(town + Vector2(0.0, -town_width * 0.1), down)
			+ Vector2(sin(down * 9.0 + float(int(_time * 3.0))) * town_width * 0.07
				* (1.0 - down), 0.0))
	draw_polyline(bolt, Color(0.85, 0.9, 1.0, fade), maxf(town_width * 0.02, 1.5), true)
	draw_polyline(bolt, Color(1.0, 1.0, 1.0, fade * 0.7),
		maxf(town_width * 0.008, 1.0), true)
	# And the sky lighting up. Drawn wide rather than as a screen effect so it
	# belongs to the scene rather than to the interface.
	draw_circle(top, town_width * 1.6, Color(0.8, 0.86, 1.0, 0.1 * fade))


## A streak across the sky. The meteor's own warning on the field is its shadow;
## from out here it is the thing itself, going over.
func _draw_meteor() -> void:
	var fade: float = clampf(_meteor_left / Balance.BEAST_OMEN_METEOR_SECONDS, 0.0, 1.0)
	var across: float = 1.0 - fade
	var from: Vector2 = town + Vector2(-town_width * 2.2 + across * town_width * 3.0,
		-town_width * 2.0 + across * town_width * 0.9)
	var to: Vector2 = from + Vector2(town_width * 0.5, town_width * 0.18)
	draw_line(from, to, Color(1.0, 0.72, 0.4, 0.7 * fade), maxf(town_width * 0.012, 1.2), true)
	draw_circle(to, maxf(town_width * 0.018, 1.4), Color(1.0, 0.86, 0.6, 0.85 * fade))
