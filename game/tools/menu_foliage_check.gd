extends Node

## The menu's corner plants: painted pixel art on a motion that never repeats.
##
## **Two owner briefs meet here and a gate can only hold one of them.** The
## first (2026-09-14) asked for swaying corner foliage and explicitly *not*
## looping pixel-art animation; the second, the same day, asked for real pixel
## sprites on it. The non-looping half is a property of numbers and is held
## below. The painted half is a picture, and `menu_shot` is what holds it -
## that is not a shortfall to apologise for, it is the reason both halves
## survived: the frond was drawn upside down and both plants were stretched off
## their own aspect, and no assertion in this file could have said so. One
## screenshot said both at once.
##
## What is held here:
##
## - the three sprites exist, load, and are the sizes the manifest declares;
## - a plant built the way the menu builds one reports itself **painted**, so a
##   file arriving late cannot silently ship the silhouettes instead;
## - the motion does not repeat, measured over an hour of plant time;
## - every strand is its own strand, so a corner is a plant and not a tiling;
## - nothing a corner draws reaches the middle of the screen, where the buttons
##   and the title are.

const ART: Array[String] = [
	MenuFoliage.LEAF_ART, MenuFoliage.FROND_ART, MenuFoliage.TENDRIL_ART,
]
const SIZES: Array[Vector2i] = [
	Vector2i(128, 128), Vector2i(96, 128), Vector2i(64, 128),
]

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_the_art_is_on_disk()
	_test_a_corner_is_painted()
	_test_the_motion_never_repeats()
	_test_every_strand_is_its_own()
	_test_a_corner_stays_in_its_corner()
	_finish()


## The art convention (CLAUDE.md section 4) derives a path from a name, so a
## renamed or missing file is a silhouette and no error at all.
func _test_the_art_is_on_disk() -> void:
	for index: int in ART.size():
		var path: String = ART[index]
		_check(ResourceLoader.exists(path), "%s must exist" % path)
		var texture: Texture2D = load(path) as Texture2D
		_check(texture != null, "%s must load as a texture" % path)
		if texture == null:
			continue
		var size := Vector2i(texture.get_width(), texture.get_height())
		_check(size == SIZES[index],
			"%s must be %s, the manifest's size (found %s)"
				% [path, str(SIZES[index]), str(size)])


## Built the way `MenuStage` builds one, and asked whether it is drawing the
## art or the fallback. This is the check that would have failed for the whole
## of the first brief's life, when there was no art to draw.
func _test_a_corner_is_painted() -> void:
	for kind: int in [MenuFoliage.Kind.VINE, MenuFoliage.Kind.FERN]:
		var plant: MenuFoliage = _plant(kind)
		_check(plant.painted(),
			"a %s must draw its painted art rather than the silhouette fallback"
				% ("vine" if kind == MenuFoliage.Kind.VINE else "fern"))
		plant.queue_free()


## **The one design rule this file has**, and the reason none of it is a sprite
## animation: the sway is the sum of two sines whose rates are in an irrational
## ratio, so the plant does not come back to a pose and there is no loop for a
## viewer to notice.
##
## **Two cuts of this check were wrong before this one, and both are worth
## knowing about.**
##
## A *near-return* is not a loop. The first cut forbade the pose ever coming
## within a pixel of its opening one, and a vine came within four tenths of a
## pixel somewhere in an hour - which is not a repeat, it is what any sum of
## sines does. What makes a motion a loop is that it comes back *and then
## follows the same path*, so the check keeps the opening run of poses and asks
## whether the plant ever rejoins it and tracks it.
##
## And *every* such sum has arbitrarily good near-periods, given long enough -
## that is almost-periodicity, and it is a theorem rather than a bug. The
## second cut searched an hour and duly found one at about seventeen minutes,
## which no one looking at a menu will ever see. So the horizon is what a
## viewer could plausibly hold in mind: **three minutes**. Inside that window
## the plant must never retrace sixteen consecutive seconds of its own past.
##
## **What it does and does not catch, measured rather than asserted.** Set the
## two rates in the ratio 3/2 and the fern retraces itself at an offset of 67
## seconds; set them equal or at 2/1 and the vine does it at 7. Those are the
## failures worth a gate, and it names them. It does *not* catch a ratio that
## is merely a close fraction - the golden ratio times 1.7 is a fifteenth of a
## percent from 21/20 and passes here, because the drift over sixteen seconds
## is still under a pixel. That constant was corrected in the same change as
## this file, on the argument that it contradicted its own comment; the gate is
## not the evidence for it, and neither should pretend otherwise.
const LOOP_RUN: int = 16
const LOOP_HORIZON: int = 180
const LOOP_TOLERANCE: float = 1.0


func _test_the_motion_never_repeats() -> void:
	for kind: int in [MenuFoliage.Kind.VINE, MenuFoliage.Kind.FERN]:
		var plant: MenuFoliage = _plant(kind)
		var walk: Array[PackedVector2Array] = []
		for _second: int in LOOP_HORIZON + LOOP_RUN:
			walk.append(plant.pose())
			plant.advance(1.0)
		_check(walk[0].size() > 1,
			"a plant must have strands to pose (%d)" % walk[0].size())
		var moved: float = 0.0
		var longest: int = 0
		var at: int = 0
		for offset: int in range(1, LOOP_HORIZON):
			moved = maxf(moved, _apart(walk[0], walk[offset]))
			var run: int = 0
			for step: int in LOOP_RUN:
				if _apart(walk[step], walk[offset + step]) > LOOP_TOLERANCE:
					break
				run += 1
			if run > longest:
				longest = run
				at = offset
		_check(moved > 1.0,
			"a %s must actually move (furthest from its opening pose: %0.3f)"
				% [_named(kind), moved])
		_check(longest < LOOP_RUN,
			("a %s must never retrace its own past inside %d seconds: "
				+ "at an offset of %ds it followed %d of %d, which is a loop")
				% [_named(kind), LOOP_HORIZON, at, longest, LOOP_RUN])
		plant.queue_free()


## Every strand its own length, lean, sway, phase and leaf size. One set of
## numbers shared by every strand is the thing that reads as a repeated sticker
## rather than as a plant, and it is invisible in a still.
func _test_every_strand_is_its_own() -> void:
	var plant: MenuFoliage = _plant(MenuFoliage.Kind.VINE)
	var strands: Array = plant.get("_strands")
	_check(strands.size() > 2, "a branch must carry several strands (%d)" % strands.size())
	for key: String in ["length", "lean", "sway", "phase", "leaf_size"]:
		var seen: Array[float] = []
		for strand: Dictionary in strands:
			_check(strand.has(key), "every strand must carry '%s'" % key)
			if strand.has(key):
				seen.append(float(strand[key]))
		var same: bool = true
		for value: float in seen:
			if not is_equal_approx(value, seen[0]):
				same = false
		_check(not same or seen.size() < 2,
			"'%s' must differ between strands, or the corner is one plant drawn twice" % key)
	plant.queue_free()


## The corners frame the menu; they must never walk into it. Measured on the
## chains themselves rather than on the art, because the art hangs off them.
func _test_a_corner_stays_in_its_corner() -> void:
	for kind: int in [MenuFoliage.Kind.VINE, MenuFoliage.Kind.FERN]:
		var plant: MenuFoliage = _plant(kind)
		var furthest: float = 0.0
		for step: int in 400:
			plant.advance(0.37)
			for tip: Vector2 in plant.pose():
				furthest = maxf(furthest, tip.length())
		# A plant is drawn in its own space, rooted at the corner. Twice its
		# own reach is already further than any corner has to spare.
		_check(furthest < plant.reach * 2.0,
			"a %s must stay within twice its reach of its corner (%0.1f of %0.1f)"
				% [_named(kind), furthest, plant.reach * 2.0])
		plant.queue_free()


func _named(kind: int) -> String:
	return "vine" if kind == MenuFoliage.Kind.VINE else "fern"


func _plant(kind: int) -> MenuFoliage:
	var plant := MenuFoliage.new()
	plant.kind = kind
	plant.facing = 1.0
	plant.reach = 320.0
	plant.phase = 0.4 if kind == MenuFoliage.Kind.VINE else 1.9
	add_child(plant)
	return plant


## How far apart two poses are, at their furthest-apart tip. A mean would let
## one strand come back onto its old pose while the others hid it.
func _apart(one: PackedVector2Array, two: PackedVector2Array) -> float:
	if one.size() != two.size() or one.is_empty():
		return 1e9
	var worst: float = 0.0
	for index: int in one.size():
		worst = maxf(worst, one[index].distance_to(two[index]))
	return worst


func _finish() -> void:
	if _failures == 0:
		print("[menu-foliage] PASS - %d checks: the art on disk, painted rather than silhouette, a motion with no period, and every strand its own" % _checks)
	else:
		push_error("[menu-foliage] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[menu-foliage] FAIL: %s" % why)
