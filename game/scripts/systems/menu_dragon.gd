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
## ninety pixels of detail at that size is detail nobody can resolve". The same
## art, the same treatment, so the thing a player meets on the menu and the
## thing that crosses the road are recognisably one animal.
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

const ART: String = "res://art/vfx/dragon_overhead.png"

var _texture: Texture2D = null
var _span: Vector2 = Vector2(1920.0, 1080.0)
var _rng := RandomNumberGenerator.new()
var _wait: float = 0.0
var _crossing: float = -1.0
var _high: float = 0.5
var _rightward: bool = true
var _tint: Color = Color(0.1, 0.09, 0.12, 0.5)


func _ready() -> void:
	name = "MenuDragon"
	_rng.randomize()
	if ResourceLoader.exists(ART):
		_texture = load(ART) as Texture2D
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
	# Fading in and out at the edges rather than clipping: the shape is huge
	# and popping one on at full strength is a jump cut.
	var edge: float = clampf(sin(_crossing * PI) * 2.2, 0.0, 1.0)
	var shade := Color(_tint.r, _tint.g, _tint.b, _tint.a * edge)
	var facing: float = 1.0 if _rightward else -1.0
	draw_set_transform(Vector2(x, y), 0.0, Vector2(facing, 1.0))
	draw_texture_rect(_texture, Rect2(-wide * 0.5, -tall * 0.5, wide, tall),
		false, shade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
