extends Node

## The beast's tail: joined where its own art says, faded behind real body, and
## lit like the beast it grows out of.
##
##   godot --headless --path game res://tools/beast_tail_check.tscn
##
## **Three faults in one limb, all reported by eye and none catchable before.**
## The tail is a separate sprite hung on a body frame by three constants, and
## every one of them was a guess that looked plausible in the file:
##
## 1. **`BEAST_TAIL_ROOT.y` was 0.56 and the art says 0.365.** That hung the
##    whole tail about nineteen of its own pixels - some seventy on screen -
##    above the haunch. Reported twice as an offset, and nudged by eye the first
##    time, which is why it was still wrong the second time.
## 2. **The fade was on the wrong asset entirely.** The first two cuts
##    feathered the *tail sprite's* root, which fades away the one stretch that
##    has to be continuous - so the tail stopped short of the flank in mid-air
##    however far it was tucked under. The owner's correction: the beast's own
##    baked stub is the end that should dissolve, with the whole tail drawn
##    behind showing through it, and the tail itself neither faded nor scaled.
## 3. **The join shader threw the modulate away.** Both screens tint the beast
##    to the scene's light and a sprite inherits that through `modulate`;
##    `COLOR = art` discards it, so the tail was drawn at full brightness
##    against a body at half of it.
##
## None of it errored, nothing failed, and every gate in the project stayed
## green - a sprite in the wrong place is still a sprite. So this measures the
## art instead of trusting the numbers: where the root row actually is, whether
## the ramp has body to hide behind, and whether the shader still multiplies by
## the colour it is handed.

## How far the measured root row may sit from the authored fraction, as a
## fraction of the tail's height. Four of ninety-six pixels: tight enough to
## catch the 0.195 that was wrong, loose enough that the frames may breathe.
const ROOT_TOLERANCE: float = 0.042

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_root_row_is_where_the_art_says()
	_test_the_stub_fade_has_tail_behind_it()
	_test_the_body_carries_a_stub_that_far()
	_test_the_stub_fades_and_the_tail_does_not()
	_test_the_tail_wears_the_hide()
	_test_the_tail_is_lit_where_it_hangs()
	_test_the_tail_is_graded_by_the_body()
	_test_the_spline_is_anchored_and_alive()
	_test_the_tail_is_drawn_in_the_same_ink()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[beast-tail] PASS - %d checks: root row, stub fade, stub reach, "
			% _checks + "tint, and the tail is painted in the hide's own colours")
	else:
		for failure: String in _failures:
			push_error("[beast-tail] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)




## **Whatever is done to the body happens to the tail, by construction.**
##
## Owner, 2026-09-15: "ensure you do whatever the colour grading and tinting you
## applied to the beast body to also happen to the tail end attachment". It
## already does, and the mechanism is the only reason: the tail is a *child* of
## the beast sprite, so Godot multiplies the body's `modulate` into it - the
## menu's sampled backdrop tint, the scope's ground tint, the day's colour, all
## of it, without either screen having to remember the tail exists.
##
## That is a load-bearing piece of tree shape and nothing was holding it. A tail
## re-parented to the scope to fix a sorting problem would keep drawing in the
## right place and quietly stop being graded, which is a fault nobody would
## connect to the change that caused it.
##
## Three ways the chain breaks, all of them one line of somebody's refactor:
## the tail parented somewhere else, a `self_modulate` on it (which multiplies
## on top of a grade the body never asked for), or a material (which is *not*
## inherited, so anything the body's shader does the tail would not).
func _test_the_tail_is_graded_by_the_body() -> void:
	for screen: String in ["res://scenes/ui/menu_stage.gd", "res://scenes/run/beast_scope.gd"]:
		var file := FileAccess.open(screen, FileAccess.READ)
		if file == null:
			_check(false, "%s is missing" % screen)
			continue
		var code: String = file.get_as_text()
		var body: String = "_beast" if screen.contains("menu_stage") else "beast"
		_check(code.contains("%s.add_child(_tail)" % body),
			("%s must hang the tail off the beast sprite: that parenthood is how "
				+ "every tint the body is given reaches it") % screen)
		_check(not code.contains("_tail.self_modulate"),
			("%s sets self_modulate on the tail, which lands on top of the body's "
				+ "own grade rather than with it") % screen)




## **The spline is anchored at the body and alive at the tip.**
##
## Owner's idea, 2026-09-15: "make the tail a spline animated procedural
## solution". Four things have to be true of it and none of them can be seen in
## a screenshot of one frame.
##
## **Its first point never moves.** That is the whole reason the spline exists -
## every report about this tail since it was built has been about a placement,
## and a limb whose root is the body's own stub row has no placement to get
## wrong. Checked at many instants and with the wind hard over, because a root
## that only holds still in calm air is not an anchor.
##
## **At rest it is the painting.** The art is not straightened or redrawn; it is
## sliced and laid along a chain that, with no sway, *is* the centreline
## measured off the painting. If that were not exact the tail would look
## different from the day it was drawn, and every judgement made about its
## colour would have been made about something else.
##
## **The tip travels and the root does not**, which is what a hanging limb
## does, and **the motion never repeats**, which is the same claim the menu
## foliage is held to and for the same reason: a loop a player can catch is
## worse than no motion.
func _test_the_spline_is_anchored_and_alive() -> void:
	var painting: Texture2D = load("res://art/beast/beast_tail_idle_00.png") as Texture2D
	if painting == null:
		_check(false, "the spline needs the tail painting")
		return
	var limb := BeastTailSpline.new()
	add_child(limb)
	limb.adopt(painting)

	# At rest, the chain is the painting's own centreline, walked backwards.
	limb.sway = 0.0
	limb.wind = 0.0
	var rest: PackedVector2Array = limb.chain()
	_check(rest.size() >= 8, "the chain must have segments: %d" % rest.size())
	_check(limb.tip_drift() < 0.01,
		"at rest the tip must be exactly where the painting puts it: %.3f off"
			% limb.tip_drift())

	# The root holds, whatever the wind is doing.
	var anchor: Vector2 = rest[0] if rest.size() > 0 else Vector2.ZERO
	var worst_root: float = 0.0
	var travelled: float = 0.0
	var poses: Array[Vector2] = []
	for step: int in 30:
		limb.advance(0.31)
		limb.sway = 1.0
		limb.wind = 1.0 if step % 2 == 0 else -1.0
		var now: PackedVector2Array = limb.chain()
		if now.is_empty():
			continue
		worst_root = maxf(worst_root, now[0].distance_to(anchor))
		travelled = maxf(travelled, limb.tip_drift())
		poses.append(now[now.size() - 1])
	_check(worst_root < 0.01,
		"the root must never move, and moved %.3f" % worst_root)
	_check(travelled > 4.0,
		"the tip must actually travel: %.2f pixels at its furthest" % travelled)
	_check(travelled < float(painting.get_width()) * 0.5,
		("and not be flung: %.2f pixels on a %d-wide painting - lower "
			+ "BEAST_TAIL_WHIP") % [travelled, painting.get_width()])

	# No period. Two poses far apart in time must differ, the same claim the
	# menu foliage is held to.
	var same: int = 0
	for one: int in poses.size():
		for two: int in range(one + 6, poses.size()):
			if poses[one].distance_to(poses[two]) < 0.5:
				same += 1
	_check(same <= 2,
		"the sway must not repeat: %d pairs of distant poses are the same" % same)

	# And nothing on it may take the grading off it.
	_check(limb.material == null,
		"the spline must carry no material: a shader here throws away the "
			+ "modulate the beast is graded with")
	limb.queue_free()


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _tail_frames() -> Array[String]:
	var out: Array[String] = []
	for format: String in [Balance.BEAST_TAIL_IDLE_FRAME_FORMAT,
			Balance.BEAST_TAIL_WALK_FRAME_FORMAT]:
		for index: int in 16:
			var path: String = format % index
			if ResourceLoader.exists(path):
				out.append(path)
	return out


## Where the painted tail actually crosses its own root column.
##
## Measured at the column the shader calls the root rather than at the sprite's
## extreme edge: the last pixel or two of a tapered tail is a tip of the
## silhouette and says nothing about where the limb's centre line is.
func _root_row_of(image: Image) -> float:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var column: int = clampi(int(round(Balance.BEAST_TAIL_ROOT.x * float(width - 1))),
		0, width - 1)
	var rows: Array[int] = []
	for y: int in height:
		if image.get_pixel(column, y).a > 0.16:
			rows.append(y)
	if rows.is_empty():
		return -1.0
	return float(rows.min() + rows.max()) * 0.5 / float(height)


func _test_the_root_row_is_where_the_art_says() -> void:
	var frames: Array[String] = _tail_frames()
	_check(not frames.is_empty(), "no tail frames on disk at all")
	for path: String in frames:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			_check(false, "%s will not load" % path)
			continue
		var measured: float = _root_row_of(texture.get_image())
		if measured < 0.0:
			_check(false, "%s has nothing painted on its root column" % path)
			continue
		_check(absf(measured - Balance.BEAST_TAIL_ROOT.y) <= ROOT_TOLERANCE,
			("%s roots at %.3f of its height and BEAST_TAIL_ROOT.y says %.3f - "
				+ "the tail would hang %.0f of its own pixels off the haunch")
				% [path.get_file(), measured, Balance.BEAST_TAIL_ROOT.y,
					absf(measured - Balance.BEAST_TAIL_ROOT.y)
						* float(texture.get_height())])


## Every dissolving pixel of the stub needs solid tail behind it.
##
## The stub fades over its last `BEAST_STUB_FADE_PX`; the tail is tucked
## `BEAST_TAIL_OVERLAP` under. If the fade were the longer of the two, the body
## would be turning transparent where there is no tail to show through, and the
## beast would simply have a hole at the root of its tail.
##
## And the fade has to stay inside the stretch where the stub is the only thing
## painted - past about 42 pixels the hind leg starts, and a fade that reached
## it would dissolve the leg too.
func _test_the_stub_fade_has_tail_behind_it() -> void:
	_check(Balance.BEAST_STUB_FADE_PX <= Balance.BEAST_TAIL_OVERLAP,
		("the stub dissolves over %.0fpx but the tail is only tucked %.0fpx "
			+ "under it, so the last %.0fpx of the body fade out over nothing")
			% [Balance.BEAST_STUB_FADE_PX, Balance.BEAST_TAIL_OVERLAP,
				Balance.BEAST_STUB_FADE_PX - Balance.BEAST_TAIL_OVERLAP])
	_check(Balance.BEAST_STUB_FADE_PX <= 40.0,
		("the stub fade reaches %.0fpx and the hind leg starts at 44 - a fade "
			+ "that far in stops being about the tail") % Balance.BEAST_STUB_FADE_PX)


## And the body has to actually be painted that far in.
##
## The overlap is measured from the body frame's left edge, where the baked stub
## leaves it. If the stub stopped short of the overlap the tail would be tucked
## behind nothing at all, which is the same fault wearing the other hat.
func _test_the_body_carries_a_stub_that_far() -> void:
	var reach: int = int(ceil(Balance.BEAST_TAIL_OVERLAP))
	for index: int in 8:
		var path: String = "res://art/beast/beast_idle_%02d.png" % index
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		var image: Image = texture.get_image()
		var root: Vector2 = BeastTail.root_of(texture)
		if root == Vector2.ZERO:
			continue
		var row: int = int(round(root.y + float(image.get_height()) * 0.5))
		var painted: int = 0
		for x: int in mini(reach, image.get_width()):
			for y: int in range(maxi(0, row - 14),
					mini(image.get_height(), row + 15)):
				if image.get_pixel(x, y).a > 0.16:
					painted += 1
					break
		_check(painted >= reach,
			("%s paints its tail stub for only %d of the %d px the tail is "
				+ "tucked under, so the feathered root has nothing to hide behind")
				% [path.get_file(), painted, reach])


## The stub fades, the tail does not, and the tint survives both.
##
## Greps, the way `discipline_check` proves an effect is wired: weak proof of
## behaviour, strong proof that the lines which caused each reported fault are
## not back. Measured in Godot 4.7.1 before the shader was written this way -
## with a white texture and a modulate of (0.25, 0.50, 0.75), `COLOR = art`
## renders white and `COLOR = art * COLOR` renders the modulate exactly. There
## is no `MODULATE` built-in in this version; it does not compile.
func _test_the_stub_fades_and_the_tail_does_not() -> void:
	var path: String = "res://scripts/shaders/beast_stub_fade.gdshader"
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "the stub fade shader is missing")
	if file != null:
		var code: String = file.get_as_text()
		_check(not code.contains("COLOR = art;"),
			("the stub shader assigns the raw texture to COLOR, which throws the "
				+ "beast's modulate away"))
		_check(code.contains("COLOR = art * COLOR"),
			"the stub shader no longer multiplies by the colour it is handed")
	# The fade goes on the body. A shader on the tail is the fault the owner
	# corrected - it fades the stretch that has to stay continuous, and it costs
	# the tail the scene tint on the way.
	for screen: String in ["res://scenes/ui/menu_stage.gd",
			"res://scenes/run/beast_scope.gd"]:
		var source := FileAccess.open(screen, FileAccess.READ)
		if source == null:
			_check(false, "%s is missing" % screen)
			continue
		var code: String = source.get_as_text()
		_check(not code.contains("_tail.material = "),
			("%s puts a material on the tail sprite - the tail is drawn whole "
				+ "and the beast's stub is what dissolves into it")
				% screen.get_file())
		_check(code.contains("beast_stub_fade.gdshader"),
			"%s never fades the beast's own stub, so the join is a butt-joint"
				% screen.get_file())


## The tail is painted in the same colours as the hide it grows out of.
##
## **Three reports, two wrong gains** (owner, 2026-09-14). The tail was
## generated on its own and its palette was 88% the hide's brightness, bluer,
## and spread differently; a `modulate` cannot fix a distribution, and two
## measured attempts proved it. `tools/match_tail_palette.py` rewrites the
## pixels instead, and this is what holds it there: the tail's pooled colour
## against the body's stub, haunch, belly and rear legs - the same region the
## tool matched against - on mean brightness and on the two channel ratios
## that carry the hue. Compared as art, before any tint, because that is where
## the difference lived and where the fix was made.
##
## `BEAST_TAIL_GRADE` is held at white alongside, so a future "small
## correction" cannot quietly reintroduce the gain that failed twice.
func _test_the_tail_wears_the_hide() -> void:
	_check(Balance.BEAST_TAIL_GRADE.is_equal_approx(Color.WHITE),
		"BEAST_TAIL_GRADE is %s: the tail is matched in its pixels now, and a gain "
			% str(Balance.BEAST_TAIL_GRADE)
			+ "on top of that is the thing that was wrong twice")
	var hide: Array[float] = _pooled_colour(_body_frames(), true)
	var tail: Array[float] = _pooled_colour(_tail_frames(), false)
	if hide.is_empty() or tail.is_empty():
		_check(false, "could not read the body or the tail frames to compare them")
		return
	# Mean luminance, R/G and B/G. Tolerances wide enough for pixel-art
	# quantisation and narrow enough to have caught the tail that shipped:
	# it sat at 0.93 of the hide's brightness and 0.985 of its B/G.
	var lum_ratio: float = tail[0] / maxf(hide[0], 0.001)
	_check(absf(lum_ratio - 1.0) <= HIDE_LUMINANCE_TOLERANCE,
		"the tail is %.2fx the hide's brightness; run tools/match_tail_palette.py"
			% lum_ratio)
	_check(absf(tail[1] - hide[1]) <= HIDE_RATIO_TOLERANCE,
		"the tail's R/G is %.3f against the hide's %.3f" % [tail[1], hide[1]])
	_check(absf(tail[2] - hide[2]) <= HIDE_RATIO_TOLERANCE,
		"the tail's B/G is %.3f against the hide's %.3f" % [tail[2], hide[2]])


const HIDE_LUMINANCE_TOLERANCE: float = 0.06
const HIDE_RATIO_TOLERANCE: float = 0.02
## How far the tail may sit from the hide's brightness at its own height.
## Wider than the palette tolerance because this is a lighting match and the
## tail's own modelling legitimately moves it either way - and narrow enough to
## have caught what shipped, which stood at 1.115 against the low band while
## every palette number agreed. It reads 1.042 now.
const LOW_BAND_TOLERANCE: float = 0.08

## At or below this in every channel, a pixel is ink rather than hide. The same
## number `tools/match_tail_palette.py` separates on, and for the same reason.
const INK: float = 12.0 / 255.0
## How far the tail's share of ink may fall short of the hide's. It may exceed
## it freely: a thin limb is mostly outline, and that is geometry.
const INK_FLOOR_SHARE: float = 0.6


## **A mean cannot see a missing outline, and that is what shipped.**
##
## The tail and the hide agreed on mean brightness, on R/G and on B/G - every
## number the check above reads - while the tail carried **0.0%** of its pixels
## below luminance 0.04 against the hide's 13.5%. Not one true black in the
## whole limb. Its outline and the moss hanging off it had been matched away
## into grey by a histogram that could not tell a line from a surface, and
## beside a body still drawn in crisp black it read as a different, flatter,
## lighter material joined at the hip. Three owner reports; four counting the
## one that found it.
##
## So this measures the two things a mean averages over: **the ink is there and
## it is the body's ink**, and **nothing on the tail is brighter than the
## brightest thing on the body**. The second is not hypothetical either - one
## pixel came back at pure white against a hide whose highlight stops at 188.
func _test_the_tail_is_drawn_in_the_same_ink() -> void:
	var hide: Dictionary = _ink_and_ceiling(_body_frames(), true)
	var tail: Dictionary = _ink_and_ceiling(_tail_frames(), false)
	if hide.is_empty() or tail.is_empty():
		_check(false, "could not read the body or the tail frames to compare their ink")
		return
	_check(float(hide["share"]) > 0.01,
		"the body must be drawn with ink at all for this check to mean anything (%.3f)"
			% float(hide["share"]))
	_check(float(tail["share"]) >= float(hide["share"]) * INK_FLOOR_SHARE,
		("the tail is %.1f%% ink against the hide's %.1f%%: its outline has been "
			+ "matched away into grey; run tools/match_tail_palette.py")
			% [100.0 * float(tail["share"]), 100.0 * float(hide["share"])])
	var body_ink := Color(hide["ink"])
	var tail_ink := Color(tail["ink"])
	_check(absf(tail_ink.get_luminance() - body_ink.get_luminance()) <= 0.02,
		"the tail's ink is %s against the body's %s"
			% [str(tail_ink), str(body_ink)])
	_check(float(tail["ceiling"]) <= float(hide["ceiling"]) + 0.01,
		("the tail's brightest pixel is %.3f against the hide's %.3f: a gain has "
			+ "blown a highlight the body never reaches")
			% [float(tail["ceiling"]), float(hide["ceiling"])])


## The share of a set of frames that is ink, the mean colour of that ink, and
## the brightest surface pixel in them.
func _ink_and_ceiling(paths: Array[String], hide_only: bool) -> Dictionary:
	var ink := Vector3.ZERO
	var ink_count: int = 0
	var solid: int = 0
	var ceiling: float = 0.0
	for path: String in paths:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image == null:
			continue
		var x_to: int = int(float(image.get_width()) * 0.375) if hide_only else image.get_width()
		var y_from: int = image.get_height() / 2 if hide_only else 0
		for y: int in range(y_from, image.get_height()):
			for x: int in range(0, x_to):
				var at: Color = image.get_pixel(x, y)
				if at.a < 0.5:
					continue
				solid += 1
				if at.r <= INK and at.g <= INK and at.b <= INK:
					ink += Vector3(at.r, at.g, at.b)
					ink_count += 1
				else:
					ceiling = maxf(ceiling, maxf(at.r, maxf(at.g, at.b)))
	if solid == 0:
		return {}
	var mean: Vector3 = ink / maxf(float(ink_count), 1.0)
	return {
		"share": float(ink_count) / float(solid),
		"ink": Color(mean.x, mean.y, mean.z),
		"ceiling": ceiling,
	}

## The body frames the tail was matched against, or the single profile.
func _body_frames() -> Array[String]:
	var out: Array[String] = []
	for index: int in 16:
		var path: String = Balance.BEAST_WALK_FRAME_FORMAT % index
		if ResourceLoader.exists(path):
			out.append(path)
	return out


## [mean luminance, R/G, B/G] over the *surface* of the given frames. For the
## body, only the hide at the join - the lower left of the canvas, which is the
## stub, the haunch, the belly and the rear legs and none of the town.
##
## **Ink is left out, because a mean over line and surface together measures
## the shape rather than the colour.** A tail is a thin limb and is therefore a
## bigger share of outline than a haunch is; counted in, that reads as a tail
## 0.89 times the hide's brightness however exactly its hide is matched. The
## ink is checked separately, and by the thing that actually matters about it -
## that it is there, and that it is the body's ink.
func _pooled_colour(paths: Array[String], hide_only: bool) -> Array[float]:
	var total := Vector3.ZERO
	var count: int = 0
	for path: String in paths:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image == null:
			continue
		var x_to: int = int(float(image.get_width()) * 0.375) if hide_only else image.get_width()
		var y_from: int = image.get_height() / 2 if hide_only else 0
		for y: int in range(y_from, image.get_height()):
			for x: int in range(0, x_to):
				var at: Color = image.get_pixel(x, y)
				if at.a >= 0.5 and not (at.r <= INK and at.g <= INK and at.b <= INK):
					total += Vector3(at.r, at.g, at.b)
					count += 1
	if count == 0:
		return []
	var mean: Vector3 = total / float(count)
	var lum: float = 0.2126 * mean.x + 0.7152 * mean.y + 0.0722 * mean.z
	return [lum, mean.x / maxf(mean.y, 0.001), mean.z / maxf(mean.y, 0.001)]


## **The tail is lit like the part of the animal it hangs from, not like its
## back.** Owner, three reports ending 2026-09-15: the tail "is not matching the
## colour grading and tint of the body it's attached to".
##
## The palette was not the fault, and four passes at it are the evidence. The
## tail's surface sits within three percent of the hide's on all three channels,
## on R/G, on B/G, on its share of moss and on its ink - the check above holds
## every one of those and they were all already true. What was wrong is simpler
## and nothing was looking at it: the beast is lit from above, its hide runs
## from 64 across the back at row 120 down to 47 at the feet, and **the tail
## hangs from row 142 to row 238 painted at 63** - the brightness of the back,
## on the lowest limb of the animal. A limb lit by a different sun is exactly
## what that report describes, and no hue match can answer it.
##
## So the reference here is the hide's **low band** rather than the whole
## animal, which is the correction the art needed and the gate needed with it.
func _test_the_tail_is_lit_where_it_hangs() -> void:
	var low: float = _band_luminance(_body_frames(), 0.62, 1.0)
	var back: float = _band_luminance(_body_frames(), 0.3, 0.55)
	var tail: float = _band_luminance(_tail_frames(), 0.0, 1.0)
	if low <= 0.0 or back <= 0.0 or tail <= 0.0:
		_check(false, "could not read a light profile off the frames")
		return
	_check(back > low,
		("the beast must be lit from above for any of this to mean anything: "
			+ "back %.3f against low %.3f") % [back, low])
	_check(tail <= back,
		("the tail hangs at the beast's feet and must not be lit like its back: "
			+ "%.3f against %.3f - run tools/seat_tail_light.py") % [tail, back])
	var ratio: float = tail / maxf(low, 0.001)
	_check(absf(ratio - 1.0) <= LOW_BAND_TOLERANCE,
		("the tail is %.2fx the hide's brightness at its own height (%.3f against "
			+ "%.3f) - run tools/seat_tail_light.py") % [ratio, tail, low])

	# **And the lift stays inside the join it hides in.** A tail nudged further
	# up than the stub dissolves over comes out from under the flank, which is
	# the seam the overlap and the fade exist to bury.
	_check(Balance.BEAST_TAIL_LIFT >= 0.0
			and Balance.BEAST_TAIL_LIFT <= Balance.BEAST_STUB_FADE_PX,
		("the tail lift is %.1f against a stub fade of %.1f: past that the root "
			+ "leaves the body") % [Balance.BEAST_TAIL_LIFT, Balance.BEAST_STUB_FADE_PX])
	# Read by both scopes, or one of them hangs the tail where the other does
	# not - the fault that put the menu and the walk a few pixels apart before.
	for screen: String in ["res://scenes/ui/menu_stage.gd", "res://scenes/run/beast_scope.gd"]:
		var file := FileAccess.open(screen, FileAccess.READ)
		if file == null:
			_check(false, "%s is missing" % screen)
			continue
		_check(file.get_as_text().contains("BEAST_TAIL_LIFT"),
			"%s does not read BEAST_TAIL_LIFT, so the two views hang the tail differently"
				% screen)


## Mean surface luminance over a band of a frame's height, ink held out. The
## band is a fraction so the body and the tail can be asked the same question
## despite being different canvases.
func _band_luminance(paths: Array[String], from: float, to: float) -> float:
	var total: float = 0.0
	var count: int = 0
	for path: String in paths:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image == null:
			continue
		var height: int = image.get_height()
		for y: int in range(int(float(height) * from), mini(int(float(height) * to), height)):
			for x: int in image.get_width():
				var at: Color = image.get_pixel(x, y)
				if at.a >= 0.5 and not (at.r <= INK and at.g <= INK and at.b <= INK):
					total += at.get_luminance()
					count += 1
	return total / float(count) if count > 0 else 0.0
