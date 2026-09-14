class_name ParallaxBand
extends Node2D

## One procedurally drawn silhouette that slides past the beast.
##
## The beast scope had exactly two depths — a painted sky and the ground under
## the feet — so distance read as a texture sliding rather than as land being
## crossed. The near band's scroll rate had been sitting in `beast_scope.gd`
## unused since whenever it was written, which is the shape of a layer that was
## planned and never built.
##
## **Drawn rather than painted**, and that is what makes it possible at all. New
## painted art is an art-direction task and the house style is painterly, which
## this toolchain cannot generate — see `docs/PIXELLAB_PROMPTS.md` §0. A
## silhouette needs no texture: it is one flat colour under a skyline, which is
## how distant land reads anyway once haze has taken the detail out of it.
##
## **Seamless by construction, not by tiling.** The profile is a sum of sines
## whose frequencies are whole numbers of cycles across the band's own width, so
## the curve at `x = width` is identical to the curve at `x = 0` by arithmetic.
## Translating by exactly one width is then invisible, and there is no join to
## hide — the backdrop pair next door has to mirror itself precisely because a
## painting does not have this property.

## Whole cycles across the band. Low frequencies are the landform; the high one
## is the ridge detail that keeps it from reading as a wave.
const HARMONICS: Array[int] = [1, 2, 3, 7]

## How much of the height each harmonic gets. Front-loaded, so the shape is
## mostly one big landform with smaller things happening on it.
const WEIGHTS: Array[float] = [0.52, 0.26, 0.14, 0.08]

## Points across one period. Enough that the ridge line is smooth at the widths
## these bands are drawn at, cheap enough to rebuild whenever an act changes.
const RESOLUTION: int = 96

## One period, in world units. `PERIODS` of them are drawn, so the view is
## always covered however far the band has slid.
##
## Must be at least half the view width, which is what makes three enough.
var band_width: float = 1920.0

## The periods `_draw` lays down, as multiples of `band_width` from this node's
## own origin.
##
## **Three, starting one period behind it, and the missing one was the bug.**
## The pair that shipped ran [0, 2w] while `scroll_to` slides the node over
## (-w, 0], so a band that had travelled less than half a period covered none of
## the left half of the screen. The scope's camera sits on this node's origin,
## so the view is [-960, 960] in its own space and a run beginning at 0 starts
## in the middle of it. What a player saw was the far ridge ending at a hard
## vertical edge with sky beside it, on roughly every other stretch of road.
##
## Kept as a constant rather than written into the loop because the gate reads
## this array: the property it asserts is about the periods that are actually
## drawn, and a copy of the arithmetic in a test would have passed with the
## fault still in place.
const PERIODS: Array[int] = [-1, 0, 1]

## How tall the silhouette stands above its baseline at full amplitude.
var band_height: float = 180.0

## Where the flat bottom of the band sits, in this node's own space.
var baseline: float = 0.0

var colour: Color = Color(0.1, 0.1, 0.12, 1.0)

## Chosen per act, so each region has its own skyline rather than every act
## having the same hills in a different colour.
var shape_seed: int = 0

var _profile: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	y_sort_enabled = false
	rebuild()


## Recomputes the silhouette. Cheap, and called when the act or the palette
## changes rather than every frame.
func rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	var phases: Array[float] = []
	for _h: int in HARMONICS.size():
		phases.append(rng.randf() * TAU)

	var points: PackedVector2Array = PackedVector2Array()
	for step: int in RESOLUTION + 1:
		var t: float = float(step) / float(RESOLUTION)
		var height: float = 0.0
		for index: int in HARMONICS.size():
			# `t` runs 0..1 across the period and the frequency is a whole number
			# of cycles, so every term returns to its starting value at t == 1.
			height += WEIGHTS[index] * sin(TAU * float(HARMONICS[index]) * t
				+ phases[index])
		# Mapped to positive by shifting, **not** by folding. `absf` was the first
		# attempt and it puts a sharp cusp at every zero crossing, so the band
		# came out as a row of black triangular teeth rather than as land. The
		# weights sum to one, so the sum lands in roughly -1..1 and this maps it
		# to 0..1 with the curve left smooth.
		var risen: float = (height + 1.0) * 0.5
		points.append(Vector2(t * band_width, baseline - risen * band_height))
	_profile = points
	queue_redraw()


func _draw() -> void:
	if _profile.size() < 2:
		return
	# Each period is the one before translated by exactly one width, which the
	# harmonic construction makes indistinguishable from a continuation.
	for period: int in PERIODS:
		var shifted: PackedVector2Array = PackedVector2Array()
		var offset: float = float(period) * band_width
		for point: Vector2 in _profile:
			shifted.append(point + Vector2(offset, 0.0))
		# Closed against a floor well below the baseline rather than against the
		# baseline itself: these sit in front of things and must not show a seam
		# where the fill stops.
		shifted.append(Vector2(offset + band_width, baseline + band_height * 4.0))
		shifted.append(Vector2(offset, baseline + band_height * 4.0))
		draw_colored_polygon(shifted, colour)


## Slides the band for a distance travelled.
##
## Wrapped by one period, so the number stays small however long the run gets -
## a raw `distance * rate` would be in the millions by Act III and lose precision
## exactly where the ridge detail lives.
func scroll_to(distance: float, rate: float) -> void:
	position.x = -fmod(distance * rate, band_width)
