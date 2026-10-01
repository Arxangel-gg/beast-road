class_name MenuDragon
extends Node2D

## **Something enormous crosses the sky behind the beast.**
##
## The owner's brief: "a rare chance for a dragon to fly by in the main menu
## further in the background scaled in contrast to the other birds and the
## beast".
##
## Not a sixth `MenuBirds` species, for two reasons. The birds carry five
## flight frames each and `dragon_overhead.png` is one image with no wingbeat,
## so it would fail `winged()`; and every bird is drawn at `MENU_BIRD_SIZE` of
## the screen with a depth that only ever shrinks it, which is the opposite of
## what this needs. A dragon that obeyed the bird tables would be a slightly
## large bird.
##
## **Drawn as a silhouette, which is a rule rather than a saving.** `DragonPass`
## and `BeastOmens` both already refuse the painting at distance - "from that
## distance a person sees a shape blotting out the light, and a hundred and
## ninety pixels of detail at that size is detail nobody can resolve".
##
## **But it is a side-on painting now, and that was the fault** (owner,
## 2026-09-22: the menu dragon *"is facing the wrong way and is in the wrong
## orientation ... it should be a sidescroller flying animated dragon"*). It
## borrowed `dragon_overhead.png`, which is drawn looking straight down so
## that one painting serves as both the shadow on the ground and the thing
## casting it - correct for the road's `DragonPass`, and wrong in a sky seen
## from the side, where a top-down animal has no facing at all and reads as a
## shape pasted on. `dragon_flight.png` is the same animal in profile with a
## wingbeat, and the road keeps the overhead one.
##
## **A missing flight sheet falls back to the overhead painting** rather than
## to nothing: a half-finished art pass degrades, which is the rule the mount
## sheets and the music playlist already live under.
##
## **Behind the beast, and that is what sells the scale.** It is built before
## `_build_beast` so the tree puts it further back, and it crosses slowly: a
## shape that big moving at a bird's apparent speed reads as a nearby bird, and
## the whole effect is the contrast between how slowly it crosses and how fast
## the swallows do.
##
## Nothing reads it. It rolls its own dice on its own clock, changes no number
## and is never asked anything - the bound the fireflies, the birds and the
## camp are all held to.

const ART: String = "res://art/vfx/dragon_flight.png"
## What it flew as before the profile was drawn. Only reached if the flight
## sheet is not on disk.
const FALLBACK_ART: String = "res://art/vfx/dragon_overhead.png"

var _texture: Texture2D = null
## The wingbeat, if the flight sheet brought one. Empty is a still painting,
## which is exactly what this was.
var _frames: Array[Texture2D] = []
var _beat: float = 0.0
var _span: Vector2 = Vector2(1920.0, 1080.0)
var _rng := RandomNumberGenerator.new()
var _wait: float = 0.0
var _crossing: float = -1.0
var _high: float = 0.5
var _rightward: bool = true
var _tint: Color = Color(0.1, 0.09, 0.12, 0.5)
## **The rise and fall the wingbeat gives**, one beat sampled, -1 at the top of
## the lift and +1 at the bottom of the glide. See `lift_at`.
var _lift: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	name = "MenuDragon"
	_rng.randomize()
	var path: String = ART if ResourceLoader.exists(ART) else FALLBACK_ART
	if ResourceLoader.exists(path):
		_texture = load(path) as Texture2D
		_frames = GameData.load_idle_frames(path)
		_lift = lift_curve(_frames.size())
	# Never immediately: a dragon on the first frame of the first launch is a
	# mascot rather than a rare thing.
	_wait = _rng.randf_range(Balance.MENU_DRAGON_GAP.x, Balance.MENU_DRAGON_GAP.y)
	set_process(true)


func resize(span: Vector2) -> void:
	_span = span
	queue_redraw()


## The sky's own colour, so the shape is dark *against this sky* rather than a
## black hole cut in the picture - the mistake the menu's birds, its Warden and
## its vines each made once.
func set_tint(sky: Color) -> void:
	_tint = Color(sky.r * 0.35, sky.g * 0.34, sky.b * 0.42,
		Balance.MENU_DRAGON_ALPHA)
	queue_redraw()


func _process(delta: float) -> void:
	if _texture == null:
		return
	if _crossing < 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
		_begin()
		return
	_beat += delta
	_crossing += delta / maxf(Balance.MENU_DRAGON_SECONDS, 0.5)
	if _crossing >= 1.0:
		_crossing = -1.0
		_wait = _rng.randf_range(Balance.MENU_DRAGON_GAP.x, Balance.MENU_DRAGON_GAP.y)
	queue_redraw()


func _begin() -> void:
	_crossing = 0.0
	_rightward = _rng.randf() < 0.5
	# High in the frame and never near the horizon: the beast fills the lower
	# half, and a dragon crossing behind its legs reads as standing on the
	# ground rather than as flying a long way off.
	_high = _rng.randf_range(Balance.MENU_DRAGON_BAND.x, Balance.MENU_DRAGON_BAND.y)


## **Where the wingbeat has carried the body, -1 to 1** (owner, 2026-10-01:
## *"a little bit of smooth vertical sway that is naturally timed with their
## wing flapping animation so that their flaps give them lift as they gently
## glide back down before the next flap"*). Negative is up the screen.
func lift_at(beat: float) -> float:
	if _lift.is_empty() or _frames.is_empty():
		return 0.0
	var count: float = float(_frames.size())
	var phase: float = fposmod(beat * Balance.MENU_DRAGON_BEAT_RATE, count) / count
	var at: float = phase * float(_lift.size())
	var index: int = int(at) % _lift.size()
	return lerpf(_lift[index], _lift[(index + 1) % _lift.size()], at - floorf(at))


## **One wingbeat's height, worked out from when the wings sweep down.**
##
## Lift comes from the downstroke, so the body is pushed up while the wings
## sweep from their highest frame to their lowest - `MENU_DRAGON_DOWNSTROKE`,
## measured off the flight sheet - and sinks the rest of the beat, slowly and
## steadily, the way a glide loses height. The push is a smooth pulse and the
## sink is the pulse's own average, so the body comes back to where it began
## each beat and the motion has no corner in it anywhere: velocity rises and
## falls, it never jumps.
static func lift_curve(frames: int) -> PackedFloat32Array:
	var samples: int = 96
	var out := PackedFloat32Array()
	if frames <= 0:
		return out
	var centre: float = Balance.MENU_DRAGON_DOWNSTROKE.x / float(frames)
	var half: float = Balance.MENU_DRAGON_DOWNSTROKE.y / float(frames)
	var push := PackedFloat32Array()
	var mean: float = 0.0
	for sample: int in samples:
		var phase: float = (float(sample) + 0.5) / float(samples)
		var gap: float = absf(phase - centre)
		gap = minf(gap, 1.0 - gap)
		var value: float = pow(cos(PI * 0.5 * gap / half), 2.0) if gap < half else 0.0
		push.append(value)
		mean += value / float(samples)
	# Up is negative: the push lifts, the steady sink brings it back down.
	var height: float = 0.0
	var low: float = INF
	var high: float = -INF
	for sample: int in samples:
		height += -(push[sample] - mean)
		out.append(height)
	var centre_of: float = 0.0
	for value: float in out:
		centre_of += value / float(samples)
	for sample: int in samples:
		out[sample] -= centre_of
		low = minf(low, out[sample])
		high = maxf(high, out[sample])
	var reach: float = maxf(absf(low), absf(high))
	if reach > 0.0:
		for sample: int in samples:
			out[sample] /= reach
	return out


## Whether one is crossing right now. For the gate.
func crossing() -> bool:
	return _crossing >= 0.0


## Forces one to begin. For the gate, which cannot wait out a rarity measured
## in minutes - the same seam `MusicPlayer.test_slots` is.
func begin_now() -> void:
	_begin()


func _draw() -> void:
	if _texture == null or _crossing < 0.0:
		return
	var wide: float = _span.y * Balance.MENU_DRAGON_SIZE
	var tall: float = wide * float(_texture.get_height()) \
		/ maxf(float(_texture.get_width()), 1.0)
	# All the way across and off both ends, so it is never seen to appear.
	var travel: float = _span.x + wide * 2.0
	var x: float = -wide + travel * (_crossing if _rightward else 1.0 - _crossing)
	var y: float = _span.y * _high
	# It sinks a little as it crosses, which is all the animation a silhouette
	# at this size needs and reads as a long glide rather than a slide.
	y += sin(_crossing * PI) * _span.y * Balance.MENU_DRAGON_SAG
	# And it rides its own wingbeat: up on the downstroke, gliding down after.
	y += lift_at(_beat) * _span.y * Balance.MENU_DRAGON_LIFT
	# Fading in and out at the edges rather than clipping: the shape is huge
	# and popping one on at full strength is a jump cut.
	var edge: float = clampf(sin(_crossing * PI) * 2.2, 0.0, 1.0)
	var shade := Color(_tint.r, _tint.g, _tint.b, _tint.a * edge)
	var facing: float = 1.0 if _rightward else -1.0
	draw_set_transform(Vector2(x, y), 0.0, Vector2(facing, 1.0))
	# **Slow.** A wingbeat at a bird's rate on a shape this size is a bat; the
	# whole effect is the contrast between how slowly this crosses and how
	# fast the swallows do, and the wings have to agree with that.
	var sheet: Texture2D = _texture
	if not _frames.is_empty():
		var step: int = int(_beat * Balance.MENU_DRAGON_BEAT_RATE)
		sheet = _frames[step % _frames.size()]
	draw_texture_rect(sheet, Rect2(-wide * 0.5, -tall * 0.5, wide, tall),
		false, shade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
