class_name HoldBanner
extends Node2D

## **A hanging cloth that the wind actually moves.**
##
## Owner, 2026-09-17: *"animated things like banners swaying idly or even
## procedurally maybe with splines and wind affecting multiple banners based on
## wind direction"*.
##
## A banner is not a sprite with a wobble on it. It is a **spline down its own
## length**, and every point on that spline is pushed by the wind by a share
## that grows toward the free end: the head is nailed to a pole and does not
## move, the tail is cloth and does. That is the whole of why this is drawn
## rather than painted - a painted flag can only ever flap the way it was
## painted flapping, and four of them side by side flap in step.
##
## ## Why they do not move together
##
## Each banner takes its own phase from where it is standing, so two hung a few
## strides apart ripple out of step while leaning the same way. The lean is
## shared and the ripple is not, which is what a row of flags in one wind looks
## like.
##
## ## What the wind is
##
## A vector handed in, so this file knows nothing about weather: the Hold gives
## it a gentle wandering one, and on the road the same node would take
## `RunState.wind`. **The cross-wind is what shows**: a banner side-on to the
## wind flies out and one edge-on hangs, which is the only way a player reads a
## direction off a flag at all.
##
## ## It is a picture
##
## Nothing reads a banner. It blocks nothing, it is in no group, and turning it
## off changes no number - the bound every decoration in this project is held
## to, the same one the fog and the phenotypes live under.

## How far down the cloth is drawn, and how wide.
var length: float = 96.0
var width: float = 34.0

## **The cloth itself, painted.** Owner, 2026-09-17: *"the banners should use
## pixelart assets ... with varieties and procedural variations, and still use
## the spline sway procedurally for the wind animations, and it should be just
## the flag for the banner in the pixelart sprites"*.
##
## So the sprite is the *pattern* and this node is the *shape*: the strip below
## carries the texture down its own length, and the taper that makes a pennant
## is cut by the mesh rather than painted into the art. That is what guarantees
## every banner in the Hold shares one outline however many devices are drawn -
## a silhouette the generator has to match is a silhouette that will drift, and
## six flags with six slightly different hems is worse than none.
##
## Without a texture it falls back to the two colours below, which is what it
## drew before there was art: a missing file is a plainer banner, never a hole.
var art: Texture2D = null

## The two colours of the cloth: the lit face and the shadowed fold. Read when
## there is no painting, and used to tint one when there is.
var cloth: Color = Color(0.52, 0.16, 0.14)
var shade: Color = Color(0.30, 0.09, 0.08)

## A small shift of its own, so two banners wearing the same painting are not
## the same banner. Multiplied into the cloth, which can only ever darken or
## warm it - a hue rotation here would undo the grade the art was given.
var weathering: Color = Color.WHITE

## The pole it hangs from, or nothing for a cloth hung on a wall.
var pole: bool = true
var pole_tint: Color = Color(0.26, 0.20, 0.14)

## How much of the wind reaches this one. A banner in the lee of a building
## should not fly as hard as one on the wall.
var exposure: float = 1.0

var _wind: Vector2 = Vector2.ZERO
var _clock: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	# Its own phase off its own place, rather than a roll: a banner that
	# re-rolled its phase every time the Hold opened would snap to a new shape
	# on arrival, and two banners built in the same frame would share a seed.
	_phase = fmod(absf(position.x) * 0.031 + absf(position.y) * 0.017, TAU)
	set_process(true)


## The wind this cloth is standing in. Set every frame by whoever owns the
## weather; a banner told nothing simply hangs and breathes.
func set_wind(wind: Vector2) -> void:
	_wind = wind


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	# **The cross-wind is what flies the cloth.** A banner hanging from a pole
	# swings across the wind rather than along it, so the sideways component is
	# the one that moves it and the head-on component only presses it flat.
	var strength: float = _wind.length() * exposure
	var sideways: float = _wind.x * exposure
	var steps: int = Balance.HOLD_BANNER_STEPS
	var left: PackedVector2Array = []
	var right: PackedVector2Array = []
	for step: int in steps + 1:
		var down: float = float(step) / float(steps)
		# The head is nailed and the tail is cloth: the share of the wind a
		# point takes grows with the square of how far down it is, which is
		# what makes a banner bend rather than swing like a plank.
		var give: float = down * down
		var ripple: float = sin(_clock * Balance.HOLD_BANNER_RIPPLE_HZ
			+ _phase + down * Balance.HOLD_BANNER_WAVES)
		var lean: float = sideways * Balance.HOLD_BANNER_LEAN * give
		var flutter: float = ripple * Balance.HOLD_BANNER_FLUTTER \
			* give * (0.35 + strength * Balance.HOLD_BANNER_GUST)
		var middle := Vector2(lean + flutter, down * length)
		# The cloth narrows as it flies out, because a flag seen from the side
		# is a flag you are looking along.
		var half: float = width * 0.5 * (1.0 - absf(lean) / maxf(length, 1.0))
		# **And it tapers to a point**, which is what a pennant is. The first
		# cut tried to cut a swallow tail by lifting the hem, and lifting both
		# edges by the same amount only makes the banner *shorter* - a notch
		# needs a vertex down the middle and this strip has two rails.
		if down > Balance.HOLD_BANNER_TAIL_AT:
			var into: float = (down - Balance.HOLD_BANNER_TAIL_AT) 				/ maxf(1.0 - Balance.HOLD_BANNER_TAIL_AT, 0.001)
			half *= 1.0 - into * Balance.HOLD_BANNER_TAPER
		left.append(middle + Vector2(-half, 0.0))
		right.append(middle + Vector2(half, 0.0))
	# **A banner hangs off something.** The first cut drew a four-unit stripe
	# behind the cloth and photographed as rectangles of fabric floating over
	# the grass: a flag with nothing holding it up is a texture, not a banner.
	# So the post stands on the ground the banner is placed on, the cloth hangs
	# from a crossbar at the top of it, and there is a finial - which is the
	# three pieces that make a shape read as a standard.
	if pole:
		var stand: float = length * Balance.HOLD_BANNER_POST_SHARE
		var thick: float = maxf(width * 0.10, 4.0)
		# **The post stops at the cloth.** Drawn the full drop it showed as a
		# pale line hanging below the banner's hem, which is a pole with
		# nothing on the end of it: what is under a banner is the ground.
		var down_to: float = length * 0.12
		draw_rect(Rect2(-thick * 0.5, -stand, thick, stand + down_to),
			pole_tint, true)
		draw_rect(Rect2(-thick * 0.5, -stand, thick * 0.4, stand + down_to),
			pole_tint.lightened(0.16), true)
		# The crossbar the cloth is nailed to, and its two caps.
		var bar: float = width + thick * 3.0
		draw_rect(Rect2(-bar * 0.5, -thick * 1.2, bar, thick * 0.9),
			pole_tint.lightened(0.10), true)
		for side: int in [-1, 1]:
			draw_rect(Rect2(float(side) * bar * 0.5 - thick * 0.5,
				-thick * 2.0, thick, thick * 2.2),
				pole_tint.darkened(0.2), true)
		# The finial: a small spike, so the top of the post is not a cut.
		draw_rect(Rect2(-thick * 0.35, -stand - thick * 1.6,
			thick * 0.7, thick * 1.8), pole_tint.lightened(0.24), true)
	# One strip, lit down the leading edge and shadowed down the trailing one,
	# so the fold reads without a second sprite.
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var indices: PackedInt32Array = []
	var uvs: PackedVector2Array = []
	for step: int in steps + 1:
		var down: float = float(step) / float(steps)
		# **The fold has to be worth seeing.** A cloth in a wind is light down
		# one bank of the ripple and dark down the next, and that shading is
		# the only thing telling a player it has a surface - so it is applied
		# as a *tint* over the painting rather than instead of it.
		var dim: float = 0.5 + 0.5 * cos(_clock * Balance.HOLD_BANNER_RIPPLE_HZ
			+ _phase + down * Balance.HOLD_BANNER_WAVES)
		if art != null:
			var lit: float = lerpf(Balance.HOLD_BANNER_FOLD_DARK, 1.0, dim)
			# Darkening toward the free end as well: cloth hanging away from
			# the light, rather than a gradient for its own sake.
			lit *= 1.0 - down * Balance.HOLD_BANNER_HEM_SHADE
			var fold := Color(weathering.r * lit, weathering.g * lit,
				weathering.b * lit, 1.0)
			points.append(left[step])
			colours.append(fold)
			uvs.append(Vector2(0.0, down))
			points.append(right[step])
			colours.append(fold)
			uvs.append(Vector2(1.0, down))
			continue
		var deep: Color = shade.darkened(down * 0.22)
		points.append(left[step])
		colours.append(deep.lerp(cloth, dim))
		uvs.append(Vector2(0.0, down))
		points.append(right[step])
		colours.append(cloth.lerp(deep, 0.25 + dim * 0.55))
		uvs.append(Vector2(1.0, down))
	for step: int in steps:
		var base: int = step * 2
		indices.append_array([base, base + 1, base + 2,
			base + 1, base + 3, base + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours, uvs, PackedInt32Array(),
		PackedFloat32Array(), RID() if art == null else art.get_rid())
