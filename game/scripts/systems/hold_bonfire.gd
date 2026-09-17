class_name HoldBonfire
extends Node2D

## **The fire in the middle of the Hold, and the wall that keeps people out of
## it.**
##
## Owner, 2026-09-17: *"a central campfire bonfire pit that has a stone wall
## frame so players cannot go into it to accidentally burn themselves, but the
## embers can also blow in the direction of the wind while they rise up from the
## flames."*
##
## Three things, and the order matters because it is what makes a pit read as a
## pit rather than as a fire with a ring painted round it:
##
## 1. the **far** kerb, drawn before the flames, so the fire stands in front of
##    the stones behind it;
## 2. the **fire**, which is the game's own `Flame` rather than a second
##    painting of one - two fires in one project drift apart;
## 3. the **near** kerb over the top, so the flames are seen *inside* the ring.
##
## ## The wall is a rule as well as a picture
##
## `keep_out` is the radius the Hold refuses a step into, and the stones are
## drawn on that same figure - so the wall a player sees and the wall that stops
## them cannot disagree about where it is. That is the same reason the Hold's
## flights read their own low and high side off the map.
##
## ## The embers are the wind made visible
##
## An ember rises on its own buoyancy and is carried sideways by whatever wind
## it is told about, so a change of direction shows in the smoke before it shows
## anywhere else. They are drawn here rather than emitted as nodes because a
## hundred `Node2D`s that live four seconds is a hundred allocations a second
## for something nobody can click on.
##
## Nothing reads any of it. No damage, no heat, no number - the pit is a *shape*
## the yard refuses and the rest is light.

## How far from the middle the stones stand, and how far a Warden is kept out.
var keep_out: float = 92.0

## How tall the kerb reads. Only the near half is ever seen at this angle.
var kerb: float = 26.0

var stone: Color = Color(0.24, 0.22, 0.19)
var glow: Color = Color(1.0, 0.62, 0.26)

var _wind: Vector2 = Vector2.ZERO
var _clock: float = 0.0
var _embers: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _due: float = 0.0


func _ready() -> void:
	_rng.seed = hash("hold-bonfire")
	set_process(true)


## The wind the embers are carried on. Handed in, so this file knows nothing
## about weather - the same contract `HoldBanner` is built under.
func set_wind(wind: Vector2) -> void:
	_wind = wind


## Whether a point is inside the stones. The Hold asks this before it allows a
## step, and `_draw` lays the kerb on the same figure - one number, so the wall
## that is seen and the wall that stops cannot disagree.
func refuses(at: Vector2) -> bool:
	var away: Vector2 = at - global_position
	# Flattened the way every ring in this project is: the camera looks down and
	# slightly along, so a true circle on the floor reads as a hoop standing up
	# and a player would be stopped further away than the stones look.
	away.y /= Balance.HOLD_BONFIRE_SQUASH
	return away.length() < keep_out


func _process(delta: float) -> void:
	_clock += delta
	_due -= delta
	if _due <= 0.0:
		_due = 1.0 / maxf(Balance.HOLD_BONFIRE_EMBER_HZ, 0.01)
		_spark()
	var live: Array[Dictionary] = []
	for ember: Dictionary in _embers:
		var left: float = float(ember["left"]) - delta
		if left <= 0.0:
			continue
		ember["left"] = left
		# Up under its own buoyancy, sideways under the wind. An ember that is
		# higher has been in the wind longer, which is why the drift is applied
		# every tick rather than set once at birth: a gust bends the whole
		# column rather than only what leaves the flames after it.
		var way: Vector2 = Vector2(0.0, -float(ember["rise"])) \
			+ _wind * Balance.HOLD_BONFIRE_EMBER_DRIFT
		ember["at"] = (ember["at"] as Vector2) + way * delta
		live.append(ember)
	_embers = live
	queue_redraw()


func _spark() -> void:
	if _embers.size() >= Balance.HOLD_BONFIRE_EMBERS:
		return
	var angle: float = _rng.randf() * TAU
	var out: float = _rng.randf() * keep_out * 0.42
	_embers.append({
		"at": Vector2(cos(angle) * out,
			sin(angle) * out * Balance.HOLD_BONFIRE_SQUASH - kerb * 0.4),
		"rise": _rng.randf_range(Balance.HOLD_BONFIRE_EMBER_RISE.x,
			Balance.HOLD_BONFIRE_EMBER_RISE.y),
		"left": _rng.randf_range(Balance.HOLD_BONFIRE_EMBER_LIFE.x,
			Balance.HOLD_BONFIRE_EMBER_LIFE.y),
		"full": _rng.randf_range(1.4, 2.6),
		"turn": _rng.randf() * TAU,
	})


func _draw() -> void:
	_ring(true)
	_fire()
	_ring(false)
	_ember_light()


## The kerb, as blocks laid round the pit rather than a stroked ellipse - a ring
## of line reads as a diagram, which is the finding the pens' fences and the
## paddock's rails were both rebuilt on.
func _ring(far: bool) -> void:
	var stones: int = Balance.HOLD_BONFIRE_STONES
	for index: int in stones:
		var angle: float = TAU * float(index) / float(stones)
		var behind: bool = sin(angle) < 0.0
		if behind != far:
			continue
		var seat := Vector2(cos(angle) * keep_out,
			sin(angle) * keep_out * Balance.HOLD_BONFIRE_SQUASH)
		# Each block its own size from its own place, so the ring is laid stone
		# rather than a cog.
		var wide: float = 20.0 + sin(angle * 3.0) * 5.0
		var tall: float = kerb + cos(angle * 2.0) * 4.0
		var face := Rect2(seat.x - wide * 0.5, seat.y - tall * 0.6, wide, tall)
		draw_rect(face, stone.darkened(0.22 if far else 0.0), true)
		# A lit top on the near stones only: the sun is above and the fire is
		# inside, so the far kerb is in its own shadow.
		if not far:
			draw_rect(Rect2(face.position.x, face.position.y,
				wide, tall * 0.34), stone.lightened(0.14), true)
		# And the fire's own light on the inner face.
		var lit: float = maxf(-sin(angle), 0.0) * 0.5 + 0.2
		draw_rect(Rect2(face.position.x + 2.0, face.position.y + tall * 0.2,
			wide - 4.0, tall * 0.3),
			glow * Color(1.0, 1.0, 1.0, lit * _breath() * 0.5), true)


## The bed of the fire: embers in the ash, breathing.
func _fire() -> void:
	var breath: float = _breath()
	for ring: int in 3:
		var share: float = 0.58 - float(ring) * 0.16
		var reach: float = keep_out * share
		draw_set_transform(Vector2.ZERO, 0.0,
			Vector2(1.0, Balance.HOLD_BONFIRE_SQUASH))
		draw_circle(Vector2.ZERO, reach,
			Color(glow.r, glow.g * 0.6, glow.b * 0.3,
				0.10 + 0.06 * breath * float(3 - ring)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Logs, laid across each other, dark against their own light.
	for log_index: int in 3:
		var angle: float = TAU * float(log_index) / 3.0 + 0.4
		var span: float = keep_out * 0.52
		var from := Vector2(cos(angle) * span,
			sin(angle) * span * Balance.HOLD_BONFIRE_SQUASH)
		draw_line(from, -from * 0.9, Color(0.16, 0.11, 0.08), 9.0)
		draw_line(from * 0.55, -from * 0.45,
			glow * Color(1.0, 1.0, 1.0, 0.35 * breath), 5.0)


## The embers themselves, and the haze the column of them makes.
func _ember_light() -> void:
	for ember: Dictionary in _embers:
		var at: Vector2 = ember["at"] as Vector2
		var left: float = float(ember["left"])
		var fade: float = clampf(left / float(Balance.HOLD_BONFIRE_EMBER_LIFE.y),
			0.0, 1.0)
		# Cooling as it climbs: an ember leaves the fire yellow and dies red,
		# which is most of what makes a column of them read as heat.
		var heat: Color = glow.lerp(Color(0.72, 0.16, 0.10), 1.0 - fade)
		var size: float = float(ember["full"]) * (0.4 + fade * 0.6)
		# A little wander of its own, so a column is not a line of dots.
		var wander: float = sin(_clock * 3.1 + float(ember["turn"])) * 3.0
		draw_rect(Rect2(at.x + wander - size * 0.5, at.y - size * 0.5,
			size, size), Color(heat.r, heat.g, heat.b, fade * 0.9), true)


## How hard the fire is burning this instant. Two rates that do not share a
## period, so nothing about it has a beat a person can catch.
func _breath() -> float:
	return 0.6 + 0.25 * sin(_clock * 5.3) + 0.15 * sin(_clock * 2.1 + 1.7)
