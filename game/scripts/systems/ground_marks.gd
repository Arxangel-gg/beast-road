class_name GroundMarks
extends Node2D

## **What a horse leaves behind, in the colour of the ground it is on.**
##
## Owner, 2026-09-17: *"mounts should also leave vfx trails matching the ground
## of the area they walk and affecting it more if they're sprinting on the
## mount"*, and separately that dismounting should carry the speed it was
## travelling at *"as a means of continued force to impact on the ground ...
## including dirt clouds matching the ground's color and grading"*.
##
## ## Why the colour is sampled rather than authored
##
## A dust colour picked by hand is right for one region and wrong for nine. This
## reads the *actual pixel* under the hoof from the ground sheet the place is
## painted with, lifts it and warms it a little - so a gallop across the Hold's
## turf throws green-brown, the same gallop on the lower yard throws grey, and a
## desert road would throw sand without anybody adding a table. The same
## argument the bank's tint and the Hold's own wall stone are taken under.
##
## ## What it is and is not
##
## It is a picture. Nothing reads a mark, nothing collides with one, and they
## are drawn in one triangle array per frame rather than as a node apiece - a
## gallop lays a few dozen a second and a `Node2D` each would be a few dozen
## allocations a second for something nobody can touch.
##
## Marks fade on their own clock and are dropped when they are spent, so the
## list is bounded by `Balance.MOUNT_MARK_LIFE` times the rate rather than by a
## cap somebody has to remember.

## What the ground looks like here. Handed in, so this file knows nothing about
## where it is standing.
var ground: Callable = Callable()

var _marks: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _clock: float = 0.0


func _ready() -> void:
	_rng.seed = hash("ground-marks")
	set_process(true)


## **A hoof fall.** `hard` runs 0 at a walk to 1 at a gallop, and decides how
## much is thrown and how far it carries - which is the owner's "affecting it
## more if they're sprinting".
func hoof(at: Vector2, way: Vector2, hard: float) -> void:
	var count: int = int(round(lerpf(1.0, float(Balance.MOUNT_MARK_PUFFS),
		clampf(hard, 0.0, 1.0))))
	for _index: int in count:
		_mark(at, -way * lerpf(20.0, 110.0, hard),
			_rng.randf_range(7.0, 15.0) * lerpf(0.7, 1.35, hard),
			Balance.MOUNT_MARK_LIFE, Balance.MOUNT_MARK_ALPHA,
			Balance.MOUNT_MARK_DRAG)


## **A rider hitting the ground**, carrying whatever they were doing.
##
## The same marks thrown harder and wider, plus a ring of them: what separates a
## landing from a footfall at this size is that a landing throws dirt *outward*
## in every direction rather than back along the way it was going.
func impact(at: Vector2, way: Vector2, hard: float) -> void:
	var count: int = int(round(lerpf(4.0, float(Balance.MOUNT_MARK_PUFFS) * 3.0,
		clampf(hard, 0.0, 1.0))))
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var out := Vector2(cos(angle), sin(angle) * 0.5)
		_mark(at, out * lerpf(40.0, 190.0, hard) - way * 40.0,
			_rng.randf_range(7.0, 15.0) * 1.6 * lerpf(0.7, 1.35, hard),
			Balance.MOUNT_MARK_LIFE, Balance.MOUNT_MARK_ALPHA,
			Balance.MOUNT_MARK_DRAG)


## **The general case, which a hoof fall and a landing are both shapes of.**
##
## Added for the footfalls of 2026-09-17 - every body on the field scuffs the
## ground it moves over - and the hoof and the landing were re-expressed through
## it rather than left beside it. One painter, three callers: a second copy of
## this arithmetic is how one of them ends up disagreeing with the ground.
func scuff(at: Vector2, way: Vector2, size: float, life: float,
		alpha: float, drag: float, tint: Color = Color(0, 0, 0, 0)) -> void:
	_mark(at, way, size, life, alpha, drag, tint)


## How many marks are alive. Read by a driver that has to bound them.
func live() -> int:
	return _marks.size()


## Drops the oldest marks until no more than `keep` are alive.
##
## **A cap rather than a hope.** Two hundred bodies at a run is two hundred
## strides a second, and every live mark is drawn every frame. The oldest go
## first, which is also the least visible - a mark near the end of its life is
## already nearly transparent.
func bound(keep: int) -> void:
	if _marks.size() > keep:
		_marks = _marks.slice(_marks.size() - keep)


func _mark(at: Vector2, way: Vector2, size: float, life: float,
		alpha: float, drag: float, told: Color = Color(0, 0, 0, 0)) -> void:
	# **A told colour wins.** The ground is the right answer for dust and the
	# wrong one for a leaf, which is the colour of the plant it came off.
	var tint: Color = Balance.GROUND_TONE_FALLBACK
	if told.a > 0.01:
		tint = told
	elif ground.is_valid():
		var found: Variant = ground.call(at)
		if found is Color:
			tint = found as Color
	_marks.append({
		"at": at + Vector2(_rng.randf_range(-6.0, 6.0),
			_rng.randf_range(-4.0, 4.0)),
		"way": way * _rng.randf_range(0.7, 1.3),
		"left": life * _rng.randf_range(0.7, 1.25),
		"full": life,
		"size": size,
		"alpha": alpha,
		# **Carried by the mark, not by this node.** A shod hoof throws earth
		# that keeps going and a boot scuffs dust that stops almost at once, and
		# one painter now serves both - the Hold lays hoof marks and footfalls
		# into the same array.
		"drag": drag,
		"tint": tint,
	})


func _process_measured(delta: float) -> void:
	_clock += delta
	var live: Array[Dictionary] = []
	for mark: Dictionary in _marks:
		var left: float = float(mark["left"]) - delta
		if left <= 0.0:
			continue
		mark["left"] = left
		# Dirt thrown up slows quickly and then hangs: the drag is what stops a
		# puff reading as a bullet.
		mark["way"] = (mark["way"] as Vector2) * (1.0 - delta
			* float(mark.get("drag", Balance.MOUNT_MARK_DRAG)))
		mark["at"] = (mark["at"] as Vector2) + (mark["way"] as Vector2) * delta
		live.append(mark)
	_marks = live
	queue_redraw()


func _draw_measured() -> void:
	if _marks.is_empty():
		return
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var indices: PackedInt32Array = []
	var steps: int = 7
	for mark: Dictionary in _marks:
		var share: float = clampf(float(mark["left"]) / maxf(float(mark["full"]),
			0.01), 0.0, 1.0)
		# It grows as it fades, which is what a cloud of dust does.
		var size: float = float(mark["size"]) * lerpf(1.7, 0.7, share)
		var tint: Color = mark["tint"] as Color
		var middle := Color(tint.r, tint.g, tint.b,
			share * float(mark.get("alpha", Balance.MOUNT_MARK_ALPHA)))
		var rim := Color(tint.r, tint.g, tint.b, 0.0)
		var at: Vector2 = mark["at"] as Vector2
		var base: int = points.size()
		points.append(at)
		colours.append(middle)
		for step: int in steps + 1:
			var angle: float = TAU * float(step) / float(steps)
			points.append(at + Vector2(cos(angle) * size,
				sin(angle) * size * 0.62))
			colours.append(rim)
		for step: int in steps:
			indices.append_array([base, base + step + 1, base + step + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours)


## `FrameProfile` bucket "d_ground_marks": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_ground_marks", started)


## `FrameProfile` bucket "p_ground_marks": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_ground_marks", started)
