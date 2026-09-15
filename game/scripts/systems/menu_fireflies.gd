class_name MenuFireflies
extends Node2D

## Fireflies over the menu's valley.
##
## **Owner brief, 2026-09-15:** "tiny little fireflies as well procedurally
## coming on and off where they're more likely to be on the map as they wander".
##
## Two ideas and they are separate on purpose. A firefly *wanders* - a slow
## drift with a little jitter on it, never a straight line and never a circuit -
## and it *glows on and off* on its own clock, which is the thing that reads as
## alive. A swarm that all blink together is a string of fairy lights; a swarm
## where each one keeps its own time is a summer evening.
##
## **Where they are likely to be is the third idea**, and it is what stops them
## being an even sprinkle of dots. Each one is drawn toward the greenery - the
## lower third of the screen and the corners where the plants hang - by a weight
## that is sampled where it stands rather than by spawning it there, so a firefly
## that drifts out over the road wanders back rather than snapping.
##
## Nothing here is a sprite. A firefly at this scale is two pixels of light and
## a halo, and a texture for that is a texture of a blurred dot. One `_draw` for
## the whole swarm - the lesson `flame.gd` cost this project twice - and the
## redraw is sampled rather than every frame.

## How many, and how big the light is at full brightness.
@export var count: int = 34
@export var glow: Color = Color(0.86, 0.94, 0.48, 1.0)

var _span: Vector2 = Vector2(1920.0, 1080.0)
var _time: float = 0.0
var _drawn_at: float = -1.0
var _rng := RandomNumberGenerator.new()
## Each fly: where it is, where it is drifting, its own blink clock and rate,
## and how long its current mood lasts.
var _flies: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = hash("menu-fireflies")
	set_process(true)


## The screen the swarm lives on. Called by the stage on every layout.
func resize(span: Vector2) -> void:
	if span.x <= 0.0 or span.y <= 0.0:
		return
	var grew: bool = _flies.is_empty()
	_span = span
	if grew:
		_hatch()


func _hatch() -> void:
	_flies.clear()
	for index: int in count:
		_flies.append({
			"at": Vector2(_rng.randf() * _span.x,
				lerpf(_span.y * 0.45, _span.y, _rng.randf())),
			"drift": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(6.0, 22.0),
			# Its own clock, its own rate. Shared, they are fairy lights.
			"blink": _rng.randf() * TAU,
			"rate": _rng.randf_range(0.5, 1.5),
			# How long until it changes its mind about where it is going.
			"mood": _rng.randf_range(0.8, 3.2),
			"size": _rng.randf_range(1.6, 3.4),
		})


func _process(delta: float) -> void:
	_time += delta
	for fly: Dictionary in _flies:
		_wander(fly, delta)
	# **Sampled, not every frame.** Three dozen soft dots is nothing to draw and
	# everything to redraw sixty times a second on a menu that is otherwise
	# still; `flame.gd` was 5.2 ms of an 18.5 ms frame for exactly this reason.
	if _time - _drawn_at >= 1.0 / maxf(Balance.MENU_FIREFLY_HZ, 1.0):
		_drawn_at = _time
		queue_redraw()


## One firefly's drift. Slow, aimless, and pulled toward the greenery.
func _wander(fly: Dictionary, delta: float) -> void:
	fly["mood"] = float(fly["mood"]) - delta
	if float(fly["mood"]) <= 0.0:
		fly["mood"] = _rng.randf_range(0.8, 3.2)
		# A new heading near the old one rather than a fresh one: a firefly
		# meanders, it does not teleport its intentions.
		var was: Vector2 = fly["drift"]
		fly["drift"] = was.rotated(_rng.randf_range(-1.1, 1.1)) \
			* _rng.randf_range(0.7, 1.35)
	var at: Vector2 = fly["at"]
	var drift: Vector2 = fly["drift"]
	# The pull home. Weakest where they belong and strongest out over the sky,
	# so the swarm has a shape without any of them being fenced in.
	var away: float = clampf((_span.y * 0.62 - at.y) / maxf(_span.y * 0.5, 1.0), -1.0, 1.0)
	drift.y += away * Balance.MENU_FIREFLY_HOMING * delta
	# And toward the corners, where the plants are.
	var side: float = signf(_span.x * 0.5 - at.x)
	drift.x -= side * Balance.MENU_FIREFLY_HOMING * 0.35 * delta
	fly["drift"] = drift.limit_length(30.0)
	at += drift * delta
	# Wrapped rather than clamped: a firefly that reaches the edge of the
	# screen has simply gone behind the trees and another comes out the other
	# side. Clamping would pile them up along the border.
	at.x = wrapf(at.x, -20.0, _span.x + 20.0)
	at.y = clampf(at.y, _span.y * 0.34, _span.y + 10.0)
	fly["at"] = at


## How bright one firefly is right now, from 0 to 1.
##
## **Mostly dark.** A firefly is off far more than it is on, and the curve is
## what says so: a sine raised to a power spends most of its time near nothing
## and flares briefly, which is the shape of the real thing. A plain sine is a
## pulsing bead.
func brightness_of(index: int) -> float:
	if index < 0 or index >= _flies.size():
		return 0.0
	var fly: Dictionary = _flies[index]
	var wave: float = 0.5 + 0.5 * sin(_time * float(fly["rate"]) + float(fly["blink"]))
	return pow(wave, Balance.MENU_FIREFLY_SHARPNESS)


## For the gate: where a firefly is.
func position_of(index: int) -> Vector2:
	if index < 0 or index >= _flies.size():
		return Vector2.ZERO
	return _flies[index]["at"]


func alive() -> int:
	return _flies.size()


func _draw() -> void:
	for index: int in _flies.size():
		var lit: float = brightness_of(index)
		if lit <= 0.02:
			continue
		var at: Vector2 = _flies[index]["at"]
		var size: float = float(_flies[index]["size"])
		# A halo and a core. Two circles beat a texture at this size, and the
		# halo is what keeps a two-pixel light from reading as a dead pixel.
		draw_circle(at, size * 2.6, Color(glow.r, glow.g, glow.b, 0.10 * lit))
		draw_circle(at, size, Color(glow.r, glow.g, glow.b, 0.72 * lit))
