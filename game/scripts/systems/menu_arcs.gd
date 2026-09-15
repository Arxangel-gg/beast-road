class_name MenuArcs
extends Node2D

## Procedural lightning: short, jagged, additive arcs that snap between points.
##
## **Owner brief, 2026-09-15:** arcs that snap the frame's segments together,
## and "little lightning arcs procedurally spark off of the title text art".
## One node does both, because they are the same thing at two scales and two
## copies of a lightning routine is how one of them ends up looking different.
##
## **Drawn rather than authored, and that is the whole reason it can be small.**
## A bolt is a polyline between two points with its middle pushed off the
## straight line by a decaying random walk - the standard midpoint displacement
## - drawn three times: a wide dim pass for the glow, a narrower brighter one,
## and a thin near-white core. Additive, so over this game's dark plates it can
## only add light, which is the bound `UiJuice` and `MenuFrame` are both held
## to.
##
## **An arc is an event, not an animation.** Each one is born with a life of
## about a fifth of a second, flickers while it lives and is gone; a new one is
## rolled somewhere else. A permanent crackle is a screensaver, and the eye
## stops seeing it inside a minute. `spark_every` is the average gap between
## them and the roll is per-frame against the delta, so the rate does not change
## with the frame rate.
##
## **It reads nothing and is read by nothing.** No input, no layout, no state -
## it is given a list of places an arc may happen and it draws there.

## Where arcs may strike, in this node's own space. Pairs are chosen from it.
var anchors: PackedVector2Array = PackedVector2Array()
## The average seconds between arcs. Smaller is busier.
var spark_every: float = 0.55
## How far apart two anchors may be and still be joined.
var reach: float = 190.0
## The light an arc is made of. Pulled toward the scene by whoever owns this.
var colour: Color = Color(0.62, 0.84, 1.0, 1.0)
## How wide the widest pass is drawn.
var weight: float = 3.0

var _live: Array[Dictionary] = []
var _time: float = 0.0
var _next: float = 0.35
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	var alive: Array[Dictionary] = []
	for arc: Dictionary in _live:
		arc["left"] = float(arc["left"]) - delta
		if float(arc["left"]) > 0.0:
			alive.append(arc)
	_live = alive
	_next -= delta
	if _next <= 0.0:
		_next = spark_every * _rng.randf_range(0.45, 1.75)
		_strike()
	# Only when something is happening. An empty frame costs one comparison.
	if not _live.is_empty() or _time < 0.2:
		queue_redraw()


## Roll one arc between two anchors that are near enough to each other.
##
## **Near enough, or it is a wire rather than a spark.** A bolt drawn between
## two far-apart points reads as a rope of light strung across the screen; the
## reach is what keeps them local, and an arc that finds no partner simply does
## not happen this time.
func _strike() -> void:
	if anchors.size() < 2:
		return
	var from_at: int = int(_rng.randi() % anchors.size())
	var from: Vector2 = anchors[from_at]
	var best: int = -1
	var tries: int = mini(anchors.size(), 12)
	for _try: int in tries:
		var other: int = int(_rng.randi() % anchors.size())
		if other == from_at:
			continue
		if from.distance_to(anchors[other]) <= reach:
			best = other
			break
	if best < 0:
		return
	_live.append({
		"from": from,
		"to": anchors[best],
		"seed": _rng.randi(),
		"life": Balance.MENU_ARC_SECONDS * _rng.randf_range(0.7, 1.35),
		"left": Balance.MENU_ARC_SECONDS * _rng.randf_range(0.7, 1.35),
	})


## Make one happen on purpose, between two given points. For the frame, which
## knows where its joints are, and for the gate.
func strike_between(from: Vector2, to: Vector2) -> void:
	_live.append({
		"from": from,
		"to": to,
		"seed": _rng.randi(),
		"life": Balance.MENU_ARC_SECONDS,
		"left": Balance.MENU_ARC_SECONDS,
	})
	queue_redraw()


## How many arcs are alive. For the gate.
func burning() -> int:
	return _live.size()


## Advance the clock by hand. For the gate, which has no frames to spend.
func advance(delta: float) -> void:
	_process(delta)


## The jagged path of one arc, as a polyline.
##
## **Midpoint displacement**, with the offset halving at every level, so the
## bolt has the same shape of detail at every scale - which is what makes a
## random walk look like lightning rather than like a scribble. Deterministic
## from the arc's own seed, so a bolt does not re-scribble itself between the
## three passes that draw it.
func _path_of(arc: Dictionary) -> PackedVector2Array:
	var from: Vector2 = arc["from"]
	var to: Vector2 = arc["to"]
	var points := PackedVector2Array([from, to])
	var across: Vector2 = (to - from)
	var span: float = across.length()
	if span < 0.01:
		return points
	var sideways: Vector2 = Vector2(-across.y, across.x) / span
	var push: float = span * Balance.MENU_ARC_JAG
	var dice := RandomNumberGenerator.new()
	dice.seed = int(arc["seed"])
	for _level: int in 4:
		var deeper := PackedVector2Array()
		for index: int in points.size() - 1:
			deeper.append(points[index])
			var middle: Vector2 = (points[index] + points[index + 1]) * 0.5
			deeper.append(middle + sideways * dice.randf_range(-push, push))
		deeper.append(points[points.size() - 1])
		points = deeper
		push *= 0.5
	return points


## The most recently struck bolt's path. For the gate, which has no other
## way to ask whether a bolt is jagged.
func path_of_first() -> PackedVector2Array:
	if _live.is_empty():
		return PackedVector2Array()
	return _path_of(_live[_live.size() - 1])


func _draw() -> void:
	for arc: Dictionary in _live:
		var life: float = maxf(float(arc["life"]), 0.001)
		var left: float = clampf(float(arc["left"]) / life, 0.0, 1.0)
		# Bright the instant it strikes, then gone: a bolt that fades evenly
		# reads as a glowing wire being switched off.
		var lit: float = left * left
		# And it flickers while it lives, which is most of what sells it.
		lit *= 0.65 + 0.35 * absf(sin(_time * 46.0 + float(arc["seed"]) * 0.01))
		var path: PackedVector2Array = _path_of(arc)
		if path.size() < 2:
			continue
		# Three passes: a wide dim glow, the bolt, and a near-white core.
		draw_polyline(path, Color(colour.r, colour.g, colour.b,
			0.16 * lit), weight * 3.0, true)
		draw_polyline(path, Color(colour.r, colour.g, colour.b,
			0.45 * lit), weight, true)
		draw_polyline(path, Color(
			minf(colour.r + 0.35, 1.0), minf(colour.g + 0.3, 1.0),
			minf(colour.b + 0.2, 1.0), 0.8 * lit), maxf(weight * 0.34, 1.0), true)
