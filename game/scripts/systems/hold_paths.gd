class_name HoldPaths
extends RefCounted

## **The way across the Hold, found rather than assumed** (owner, 2026-10-01:
## *"AI in the hold should have smarter pathfinding so they do not go walking
## into stuck places or walking into walls and ledges instead of routing
## smarter with pathfinding"*).
##
## Everybody in the Hold used to walk in a straight line at where they were
## going and let the shelf rule slide them along whatever bank was in the way.
## A destination on the shelf above, or round the end of a pen's bank, meant a
## figure pressed against an earth face for the rest of its errand.
##
## A lattice of points over the yard, one every `Balance.HOLD_PATH_STEP`,
## joined wherever a person may walk from one to the next **by the same rule
## the Warden walks under** - the yard's own `step_is_legal`, handed in rather
## than copied, so a bank, a cliff, the edge of the map and the fire pit are
## refused here exactly as they are refused underfoot, and a flight is taken
## because the slope rule takes it. Nothing here knows what a stair is.
##
## A route is then pulled tight: a waypoint is dropped whenever the straight
## walk past it is itself legal, so a figure crossing open ground walks one
## line rather than a staircase of lattice steps.
##
## **A look, never a fact.** Only presentation walks these routes - the
## simulated Wardens, the residents and the player's own click-to-walk - and
## nothing about a seat, a door or the session reads one.

## What `survey(from, to)` says of a straight walk.
enum Ground { BLOCKED, PLAIN, SLOPED }

## Strides a sloped walk is read in, and the pace a height change is walked at.
## **The slope rule is read step by step, so it depends on the step**: a flight
## entered from its side is a small rise over a long step and a cliff over a
## short one. A figure takes a few units a frame, so a route judged in long
## strides walked them into the side of a flight and stopped there - which is
## what the gate found on its first run. Flat ground is judged in strides; a
## stretch where the height moves is walked in `FINE` steps, finer than anybody
## here moves.
const COARSE: float = 8.0
const FINE: float = 1.5
## How far ahead a route is pulled tight from each point, and the stride a
## sloped stretch of it is read at.
const PULL: int = 16
const PULL_STRIDE: float = 12.0

var _graph := AStar2D.new()
var _origin: Vector2 = Vector2.ZERO
var _step: float = 48.0
var _columns: int = 0
var _rows: int = 0
var _stands: Callable
var _survey: Callable
var _legal: Callable
var _height: Callable


## Lays the lattice over `bounds`.
##
## - `stands(at) -> bool`: whether a person may stand at a point.
## - `survey(from, to) -> Ground`: what a straight walk crosses - something no
##   person may stand on, one flat level all the way, or ground whose height
##   moves and has to be read for its slope. **Exact rather than sampled**: the
##   first cut read the footing every two units and spent most of a second on
##   it the moment the Hold opened.
## - `legal(from, to) -> bool`: whether a short step is one a person could take.
## - `height(at) -> float`: the ground's height there, in levels.
func build(bounds: Rect2, step: float, stands: Callable, survey: Callable, legal: Callable,
		height: Callable) -> void:
	_graph.clear()
	_origin = bounds.position
	_step = maxf(step, 8.0)
	_stands = stands
	_survey = survey
	_legal = legal
	_height = height
	_columns = maxi(1, int(floor(bounds.size.x / _step)))
	_rows = maxi(1, int(floor(bounds.size.y / _step)))
	_graph.reserve_space(_columns * _rows)
	for row: int in _rows:
		for column: int in _columns:
			var at: Vector2 = _middle(column, row)
			if bool(stands.call(at)):
				_graph.add_point(_id(column, row), at)
	# Right, down, and both downward diagonals: every pair once.
	for row: int in _rows:
		for column: int in _columns:
			var id: int = _id(column, row)
			if not _graph.has_point(id):
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
				var other_column: int = column + offset.x
				var other_row: int = row + offset.y
				if other_column < 0 or other_column >= _columns or other_row >= _rows:
					continue
				var other: int = _id(other_column, other_row)
				if not _graph.has_point(other):
					continue
				# **No corner is cut.** A diagonal is only taken where both of
				# the squares it passes between can be stood in, or a figure
				# shaves the corner of a bank it should have walked round.
				if offset.x != 0 and offset.y != 0:
					if not _graph.has_point(_id(column + offset.x, row)) \
							or not _graph.has_point(_id(column, row + offset.y)):
						continue
				# One way is both ways: the slope rule is symmetric between two
				# places that can both be stood on, which is all a lattice has.
				if _walkable(_graph.get_point_position(id), _graph.get_point_position(other), COARSE):
					_graph.connect_points(id, other, true)


## **The same lattice, asked through another yard.** The Hold's ground never
## changes, so the lattice is laid once a session and every later Hold borrows
## it - its doors are that Hold's own, because the one that laid it may be gone.
func rebind(stands: Callable, survey: Callable, legal: Callable, height: Callable) -> void:
	_stands = stands
	_survey = survey
	_legal = legal
	_height = height


## How many places the lattice has. For the gate.
func size() -> int:
	return _graph.get_point_count()


## **The way from one point to another**, pulled tight, ending at `to` - or as
## near to it as the ground allows when it cannot be reached at all, so a
## figure sent somewhere impossible walks to the edge of where it could go and
## stops, rather than pressing against a bank for ever.
##
## The first point is never `from` itself.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	if _graph.get_point_count() == 0:
		out.append(to)
		return out
	# The straight walk first: open ground needs no lattice at all.
	if _walkable(from, to, PULL_STRIDE):
		out.append(to)
		return out
	var start: int = _graph.get_closest_point(from)
	var end: int = _graph.get_closest_point(to)
	if start < 0 or end < 0:
		out.append(to)
		return out
	var lattice: PackedVector2Array = _graph.get_point_path(start, end, true)
	if lattice.is_empty():
		return out
	var points := PackedVector2Array([from])
	points.append_array(lattice)
	var reached: bool = _graph.get_closest_point(lattice[lattice.size() - 1]) == end
	if reached and _walkable(lattice[lattice.size() - 1], to, PULL_STRIDE):
		points.append(to)
	# **Pulled tight**: from each kept point, the furthest of the next `PULL`
	# that a straight walk reaches, found by halving rather than by trying each
	# in turn - a route is a millisecond to find rather than a walk per pair of
	# points, which on the first cut was eighteen milliseconds and a hitch every
	# time somebody in the Hold set off on an errand.
	var at: int = 0
	while at < points.size() - 1:
		var low: int = at + 1
		var high: int = mini(at + PULL, points.size() - 1)
		if _walkable(points[at], points[high], PULL_STRIDE):
			low = high
		else:
			while high - low > 1:
				var middle: int = (low + high) / 2
				if _walkable(points[at], points[middle], PULL_STRIDE):
					low = middle
				else:
					high = middle
		out.append(points[low])
		at = low
	return out


## Whether a straight walk between two points is one a person could take.
func _walkable(from: Vector2, to: Vector2, stride: float) -> bool:
	var ground: int = int(_survey.call(from, to))
	if ground == Ground.BLOCKED:
		return false
	if ground == Ground.PLAIN:
		return true
	var run: float = from.distance_to(to)
	var samples: int = maxi(1, int(ceil(run / stride)))
	var last: Vector2 = from
	var was: float = float(_height.call(from))
	for sample: int in samples:
		var here: Vector2 = from.lerp(to, float(sample + 1) / float(samples))
		var now: float = float(_height.call(here))
		if not _plain_between(last, here, was, now):
			var pieces: int = maxi(1, int(ceil(last.distance_to(here) / FINE)))
			var step_from: Vector2 = last
			for piece: int in pieces:
				var next: Vector2 = last.lerp(here, float(piece + 1) / float(pieces))
				if not bool(_legal.call(step_from, next)):
					return false
				step_from = next
		last = here
		was = now
	return true


## **Whether a stride is plain ground all the way**: both ends and three
## points between them on one whole level. Equal heights at the ends alone were
## not enough - a line can clip the side of a flight and leave it again between
## two samples at the same height, and the gate found four routes that did.
func _plain_between(from: Vector2, to: Vector2, was: float, now: float) -> bool:
	if not is_equal_approx(was, now) or not is_equal_approx(was, roundf(was)):
		return false
	for share: float in [0.25, 0.5, 0.75]:
		if not is_equal_approx(float(_height.call(from.lerp(to, share))), was):
			return false
	return true


func _middle(column: int, row: int) -> Vector2:
	return _origin + Vector2((float(column) + 0.5) * _step, (float(row) + 0.5) * _step)


func _id(column: int, row: int) -> int:
	return row * _columns + column
