class_name ParallaxStrip
extends Node2D

## A painted horizon layer that scrolls forever without a seam.
##
## `ParallaxBand` draws its distances as procedural silhouettes, which is right
## for a shape whose only job is to be *a* hill - but every region gets the same
## grammar of hills. This draws **art** instead, so the Verdant Maw's horizon is
## a canopy, Saltpan's is a crust of flats and the Last Terrace's is ruins.
##
## **Seamless by mirroring, not by authoring.** Getting a painted strip to tile
## exactly is a constraint on every asset, and the one time this project tried it
## the generator did not honour it. Instead the strip is laid down in mirrored
## *pairs* - the second copy of a pair flipped - so each join is an edge against
## its own reflection and no seam exists to find. It is the trick `beast_scope`
## already uses for the backdrop, which is why the sky has never shown a cut.
##
## The pair is the period, so three of them are laid rather than three single
## copies: see `ParallaxBand.PERIODS` for why the count starts one period behind
## this node's origin rather than at it.
##
## The cost of mirroring is that the horizon is symmetric over two widths. At
## these distances, moving at a fraction of the beast's speed and hazed most of
## the way to the sky colour, that is not something an eye picks up - and it buys
## a layer per region for one asset rather than a tiling puzzle per asset.

## The art. Absent art is a supported state: the layer simply does not draw,
## which is how a region that has not been painted yet costs nothing.
var texture: Texture2D = null:
	set(value):
		texture = value
		_rebuild()

## What the reference canvas maps to, in world units.
##
## **Not the strip's own height.** Each strip is trimmed to its own content, so
## they range from 54 pixels of open steppe to 128 of terraces - scaling each to
## a fixed height would blow the sparse ones up and squash the busy ones, and a
## sparse horizon is *supposed* to be a shorter horizon. Everything is scaled by
## the same `band_height / REFERENCE` instead, so the ten keep their relative
## sizes and one number moves them all.
var band_height: float = 160.0:
	set(value):
		band_height = value
		_rebuild()

## Where its bottom edge sits.
var baseline: float = 0.0:
	set(value):
		baseline = value
		_rebuild()

## Multiplied over the art. The scope passes a hazed horizon colour, so a strip
## belongs to the sky behind it without needing a palette of its own.
var tint: Color = Color.WHITE:
	set(value):
		tint = value
		for piece: Sprite2D in _pieces:
			piece.modulate = value

var _pieces: Array[Sprite2D] = []
var _width: float = 0.0


func _ready() -> void:
	_rebuild()


## Two sprites, the second mirrored, sized to the requested height.
func _rebuild() -> void:
	for piece: Sprite2D in _pieces:
		piece.queue_free()
	_pieces.clear()
	_width = 0.0
	if texture == null or not is_inside_tree():
		return
	var native: Vector2 = texture.get_size()
	if native.y <= 0.0:
		return
	var grow: float = band_height / REFERENCE_HEIGHT
	_width = native.x * grow
	_stands = native.y * grow
	# One mirrored pair per period, laid from one period behind this node's own
	# origin. The scope's camera sits on that origin, so a run of pairs starting
	# at 0 would begin in the middle of the view and leave the left of the screen
	# bare for half of every period - the same hole `ParallaxBand.PERIODS` exists
	# to close, and this borrows that list so the two cannot drift apart.
	for period: int in ParallaxBand.PERIODS:
		var base: float = float(period) * _width * 2.0
		for index: int in 2:
			var piece := Sprite2D.new()
			piece.name = "Strip%d_%d" % [period, index]
			piece.texture = texture
			piece.centered = false
			piece.scale = Vector2.ONE * grow
			# The second copy of a pair is mirrored *and* pushed a full width
			# along, so its left edge is the first's right edge reflected.
			# `flip_h` pivots about the sprite's own origin, so the offset
			# accounts for it.
			piece.flip_h = index == 1
			# Bottom edge on the baseline: the art is trimmed to its own content,
			# so its last row *is* the silhouette's foot.
			piece.position = Vector2(base + _width * (2.0 if index == 1 else 0.0),
				baseline - _stands)
			piece.modulate = tint
			piece.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
			piece.add_to_group(Graphics.FILTER_GROUP)
			add_child(piece)
			_pieces.append(piece)


## Slides the layer for a distance travelled.
##
## Wrapped to two widths rather than one, because the mirrored pair is what
## repeats: wrapping at a single width would jump the seam back into view every
## other period. Kept small for the same reason `ParallaxBand` does it - a raw
## `distance * rate` is in the millions by Act III and loses the precision the
## horizon detail lives in.
func scroll_to(distance: float, rate: float) -> void:
	if _width <= 0.0:
		return
	position.x = -fmod(distance * rate, _width * 2.0)


## Nothing is drawn under the strip's foot, and that is a decision.
##
## A trimmed silhouette ends where its shapes end, so the obvious worry is that
## its last row reads as a cut across the sky - and a fill carrying the base
## colour downward was written here for exactly that reason, on exactly that
## reasoning, while a *different* artifact was being chased. It was never
## visible. `BEAST_SKYLINE_BASELINE` sits below `BEAST_RIDGE_BASELINE`, and the
## ridge is an opaque polygon filled from its own skyline down past the ground -
## so every pixel under this strip's foot already has land in front of it.
##
## `balance_test` holds the two baselines in that order, because the fill was
## dead code paid for at full price and the next agent to notice the cut would
## write it again.


## The canvas every strip was drawn on, before trimming.
const REFERENCE_HEIGHT: float = 128.0

## How tall this particular strip stands once scaled.
var _stands: float = 0.0
