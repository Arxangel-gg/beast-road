class_name MenuBirds
extends Node2D

## Birds crossing the menu's sky.
##
## **Owner brief, 2026-09-15:** "birds that fly through the sky of the scene,
## they must be tiny because of the scale of the scene showing yuri and a gate
## that he the beast with a whole map on his back still walks under ... so birds
## must be tiny and their movements appropriately tuned for realism and
## proceduralism. Toucans, as well as ravens, hawks, and eagles ... and most
## just showing a dim dark silhouette, not completely blacked out but tinted
## darker for the right natural appearance."
##
## **Tiny is the whole brief and it is a statement about the gate, not the
## birds.** The scene's job is to say that a beast with a city on its back walks
## under that arch; a bird drawn at a believable size for its own sake would
## quietly shrink the arch to a garden gate. So a bird here is between
## `Balance.MENU_BIRD_SIZE` of the screen's height at its nearest and a third of
## that at its furthest, which is four to fourteen pixels at 1080p - big enough
## to read as a bird by its silhouette and its beat, too small to be looked at.
##
## **Four species, and they fly differently, which is the only reason to have
## four.** A raven beats steadily and holds a line. A toucan beats harder and
## faster and bobs as it goes - a real one flies in shallow undulations, which
## is the thing about it you notice from a distance. A hawk soars and puts in a
## flurry of beats now and then. An eagle soars further and beats even more
## rarely, on a long slow arc. Everything about that lives in `data/` by way of
## the tables below rather than in branches (working rule 3 in spirit; these are
## four constants and a script, not content).
##
## **Dim, not black.** Every bird is multiplied by a tint the stage takes from
## its own sky and darkened by distance, so a bird against a sunset is a warm
## grey shape and the same bird against a night sky is a cool one. A pure
## silhouette reads as a hole cut in the picture.
##
## One `_draw` for every bird on screen, and the frames are loaded once for the
## whole menu rather than per bird - the lesson `flame.gd` cost this project
## twice.

enum Species { RAVEN, TOUCAN, HAWK, EAGLE }

const ART: Array[String] = [
	"res://art/ui/menu_bird_raven", "res://art/ui/menu_bird_toucan",
	"res://art/ui/menu_bird_hawk", "res://art/ui/menu_bird_eagle",
]
## Wingbeats a second; how far the body rises and falls over one beat, as a
## share of its own height; and how much of the time it is beating at all.
## A soarer's tenth means it holds its wings nine tenths of the way across.
const BEATS: Array[float] = [3.4, 4.6, 2.1, 1.5]
const BOB: Array[float] = [0.18, 0.55, 0.06, 0.04]
const BEATING: Array[float] = [0.85, 1.0, 0.22, 0.12]
## How often each species turns up, relative to the others, and how many come
## at once. Ravens travel together; an eagle does not.
const WEIGHT: Array[float] = [3.0, 2.0, 1.5, 0.6]
const FLOCK: Array[int] = [4, 3, 1, 1]

## What the birds are multiplied by when nothing better is known.
var tint: Color = Color(0.30, 0.29, 0.33, 1.0)
## Asks the backdrop what colour the sky is at a point, in this node's own
## space. Set by the stage; without it every bird wears `tint`.
var sky_at: Callable = Callable()

static var _frames: Array = []
static var _looked: bool = false

var _span: Vector2 = Vector2(1920.0, 1080.0)
var _time: float = 0.0
var _drawn_at: float = -1.0
var _next: float = 0.0
var _rng := RandomNumberGenerator.new()
var _birds: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = hash("menu-birds")
	_load_art()
	set_process(true)


## The frames, once for the whole menu. A species with no art on disk is simply
## not in the sky - the fallback is fewer birds rather than a wrong-looking one,
## because at four pixels a drawn stand-in is a smudge.
static func _load_art() -> void:
	if _looked:
		return
	_looked = true
	_frames = []
	for base: String in ART:
		var sheet: Array[Texture2D] = []
		if ResourceLoader.exists(base + ".png"):
			sheet.append(load(base + ".png") as Texture2D)
		for index: int in range(1, 8):
			var path: String = "%s_fly_%02d.png" % [base, index]
			if ResourceLoader.exists(path):
				sheet.append(load(path) as Texture2D)
		_frames.append(sheet)


## Whether every species has its art. For the gate.
func winged() -> bool:
	if _frames.size() != ART.size():
		return false
	for sheet: Variant in _frames:
		if (sheet as Array).size() < 2:
			return false
	return true


func resize(span: Vector2) -> void:
	if span.x > 0.0 and span.y > 0.0:
		_span = span


func _process(delta: float) -> void:
	_time += delta
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(Balance.MENU_BIRD_GAP.x, Balance.MENU_BIRD_GAP.y)
		_launch()
	var still_flying: Array[Dictionary] = []
	for bird: Dictionary in _birds:
		_fly(bird, delta)
		if not bool(bird["gone"]):
			still_flying.append(bird)
	_birds = still_flying
	if _time - _drawn_at >= 1.0 / maxf(Balance.MENU_BIRD_HZ, 1.0):
		_drawn_at = _time
		queue_redraw()


## A new bird, or a few of them.
func _launch() -> void:
	if _birds.size() >= Balance.MENU_BIRD_CEILING:
		return
	var species: int = _pick()
	var flock: int = _rng.randi_range(1, FLOCK[species])
	# One crossing, one heading, one altitude band. A flock that each chose its
	# own would be four birds that happen to be on screen together.
	var rightward: bool = _rng.randf() < 0.5
	var high: float = _rng.randf()
	var depth: float = _rng.randf()
	var speed: float = lerpf(Balance.MENU_BIRD_SPEED.x, Balance.MENU_BIRD_SPEED.y,
		1.0 - depth) * _span.x
	var climb: float = _rng.randf_range(-0.05, 0.05)
	for index: int in flock:
		if _birds.size() >= Balance.MENU_BIRD_CEILING:
			return
		_birds.append({
			"species": species,
			"at": Vector2(
				(-0.08 if rightward else 1.08) * _span.x
					- float(index) * _rng.randf_range(24.0, 90.0) * (1.0 if rightward else -1.0),
				lerpf(Balance.MENU_BIRD_BAND.x, Balance.MENU_BIRD_BAND.y, high) * _span.y
					+ _rng.randf_range(-0.02, 0.02) * _span.y),
			"heading": Vector2(1.0 if rightward else -1.0, climb).normalized(),
			"speed": speed * _rng.randf_range(0.94, 1.06),
			"depth": depth,
			"beat": _rng.randf() * TAU,
			# A soarer is not beating most of the time; this is the clock that
			# decides when it decides to.
			"flurry": 0.0,
			"until": _rng.randf_range(1.5, 4.0),
			"gone": false,
			# **Each bird is shaded against the sky it will actually cross**,
			# sampled once at launch rather than shared. One tint for the whole
			# flock was the first cut and it was invisible: taken from the top
			# of the backdrop, which in this scene is a dark purple, and
			# multiplied down to a near-silhouette, it produced a near-black
			# bird on a near-black sky. The owner's "not completely blacked out"
			# is about exactly this.
			"shade": _shade_for(Vector2(
				(0.5 if rightward else 0.5) * _span.x,
				lerpf(Balance.MENU_BIRD_BAND.x, Balance.MENU_BIRD_BAND.y, high) * _span.y)),
		})


## What one bird is multiplied by, given the sky it is about to cross.
##
## **Dark against a bright sky, faintly lit against a dark one.** The first is
## what a bird looks like at dusk and the second is what it looks like against
## a night sky - a shape catching the last of the light - and between them the
## bird is always visible, which a fixed multiplier cannot promise. The
## threshold is the point where a near-silhouette stops separating from what is
## behind it.
func _shade_for(at: Vector2) -> Color:
	var sky: Color = tint
	if sky_at.is_valid():
		var sampled: Color = sky_at.call(at)
		if sampled.a > 0.0:
			sky = sampled
	var light: float = sky.get_luminance()
	if light >= Balance.MENU_BIRD_DARK_SKY:
		# Bright enough to silhouette against.
		return Color(sky.r * 0.35, sky.g * 0.34, sky.b * 0.38, 0.95)
	# Too dark to silhouette against, so the bird catches the light instead -
	# still dim, still far from white, and now separable from its background.
	var lift: float = Balance.MENU_BIRD_DARK_SKY / maxf(light, 0.01)
	return Color(minf(sky.r * lift, 0.52), minf(sky.g * lift, 0.5),
		minf(sky.b * lift * 1.1, 0.58), 0.9)


func _pick() -> int:
	var total: float = 0.0
	for weight: float in WEIGHT:
		total += weight
	var roll: float = _rng.randf() * total
	for index: int in WEIGHT.size():
		roll -= WEIGHT[index]
		if roll <= 0.0:
			return index
	return 0


## One bird's second of flight.
##
## **A bird does not hold a ruler.** The heading wanders on its own slow clock,
## which is what separates this from a sprite sliding across a layer, and a
## soarer's wander is wider than a flapper's because that is what soaring is -
## riding whatever the air is doing rather than going somewhere.
func _fly(bird: Dictionary, delta: float) -> void:
	var species: int = int(bird["species"])
	bird["beat"] = float(bird["beat"]) + delta * BEATS[species] * TAU
	bird["until"] = float(bird["until"]) - delta
	if float(bird["until"]) <= 0.0:
		bird["until"] = _rng.randf_range(1.5, 4.0)
		# A flurry of beats, then the wings go out again. For a flapper this is
		# always on, so the roll only really decides anything for a soarer.
		bird["flurry"] = 1.0 if _rng.randf() < BEATING[species] else 0.0
		var heading: Vector2 = bird["heading"]
		var wander: float = lerpf(0.05, 0.16, 1.0 - BEATING[species])
		bird["heading"] = heading.rotated(_rng.randf_range(-wander, wander))
	var heading: Vector2 = bird["heading"]
	var at: Vector2 = bird["at"]
	at += heading * float(bird["speed"]) * delta
	bird["at"] = at
	if at.x < -0.16 * _span.x or at.x > 1.16 * _span.x \
			or at.y < -0.1 * _span.y or at.y > _span.y * 0.78:
		bird["gone"] = true


## How big a bird of this depth is drawn, in pixels of screen height.
func _size_of(depth: float) -> float:
	return _span.y * Balance.MENU_BIRD_SIZE * lerpf(1.0, 0.34, depth)


func flying() -> int:
	return _birds.size()


## Where every bird is, for a diagnostic shot that needs to know where to look.
func perches() -> PackedVector2Array:
	var out := PackedVector2Array()
	for bird: Dictionary in _birds:
		out.append(bird["at"])
	return out


## For the gate: the biggest bird on screen right now, in pixels.
func widest() -> float:
	var worst: float = 0.0
	for bird: Dictionary in _birds:
		worst = maxf(worst, _size_of(float(bird["depth"])))
	return worst


func _draw() -> void:
	for bird: Dictionary in _birds:
		var species: int = int(bird["species"])
		if species >= _frames.size():
			continue
		var sheet: Array = _frames[species]
		if sheet.is_empty():
			continue
		var beating: bool = float(bird["flurry"]) > 0.5 or BEATING[species] >= 0.99
		var phase: float = float(bird["beat"])
		var frame: int = 0
		if beating and sheet.size() > 1:
			frame = 1 + int(floor(phase / TAU * float(sheet.size() - 1))) % (sheet.size() - 1)
		var texture := sheet[frame] as Texture2D
		if texture == null:
			continue
		var wide: float = _size_of(float(bird["depth"]))
		var tall: float = wide * float(texture.get_height()) / maxf(float(texture.get_width()), 1.0)
		# The undulation. A toucan's flight path visibly rises and falls with
		# the beat and a soaring eagle's does not, and at this size that bob is
		# most of what tells the two apart.
		var bob: float = sin(phase) * tall * BOB[species] * (1.0 if beating else 0.25)
		var at: Vector2 = Vector2(bird["at"]) + Vector2(0.0, bob)
		# Further birds are dimmer as well as smaller: haze, and the only thing
		# that makes a flat sky read as deep.
		var haze: float = lerpf(1.0, Balance.MENU_BIRD_FAR_FADE, float(bird["depth"]))
		var own := Color(bird.get("shade", tint))
		var shade := Color(own.r, own.g, own.b, own.a * haze)
		# Turned to its own heading, and mirrored when it is going left. The art
		# is drawn flying right, so this is the one sprite in the project that
		# *should* be flipped - a bird in profile is symmetrical about its own
		# axis, which is exactly the condition `art_facing` exists to record.
		var facing: float = 1.0 if Vector2(bird["heading"]).x >= 0.0 else -1.0
		draw_set_transform(at, Vector2(bird["heading"]).angle() * facing,
			Vector2(facing, 1.0))
		draw_texture_rect(texture, Rect2(-wide * 0.5, -tall * 0.5, wide, tall),
			false, shade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
