class_name MenuCamp
extends Node2D

## Somebody is out there watching the beast.
##
## **Owner brief, 2026-09-15:** "put the warden riding a fire horse somewhere
## that would scale nicely in contrast with the scene, and maybe if it's in the
## foreground like a cliff of sorts ... add a camp fire also burning there and
## add the warden riding the fire horse, or sometimes sitting by the campfire,
## looking towards the beast, or the fire procedural variety, sometimes maybe no
## cliff, or some sort of other various setups to make it interesting each time
## players come visit."
##
## **The figure is what makes the beast colossal, and it does that by being
## small.** The scene already says the arch is enormous; what it has never had
## is a human being to measure it against. A foreground figure at a *believable*
## size would be the biggest thing on screen and would quietly take the scale
## away from the beast, so the Warden here is about a tenth of the screen's
## height - near enough to be sharp and dark and unmistakably a person, far
## enough that Yuri still towers behind them.
##
## **A different camp every visit.** The side of the screen, whether there is a
## cliff under it, whether the horse is there, what the Warden is doing, and how
## the pieces sit relative to the fire are all drawn once when the menu opens.
## The dice are the *menu's* own, unseeded, and that is deliberate: a run's seed
## belongs to the run, and a main menu that showed the same camp until the seed
## changed would be a bug wearing determinism's clothes.
##
## **Graded to the scene, except the fire.** Rock and cloak take the horizon's
## colour and are pushed dark, the way the beast and the corner foliage are; the
## flames and the horse's burning mane are light *sources* and are only nudged
## toward the scene's hue, the same distinction the fireflies are drawn under.
##
## One `_draw` for everything, redrawn at `Balance.MENU_CAMP_HZ` rather than
## every frame - the lesson `flame.gd` cost this project twice.

enum Pose { SITTING, STANDING, MOUNTED }

const CLIFF_ART: String = "res://art/ui/menu_camp_cliff.png"
const SIT_ART: String = "res://art/ui/menu_warden_sit.png"
const STAND_ART: String = "res://art/ui/menu_warden_stand.png"
const RIDE_ART: String = "res://art/ui/menu_warden_ride.png"
const HORSE_ART: String = "res://art/ui/menu_fire_horse.png"

const LANTERN_ART: String = "res://art/ui/menu_lantern.png"

static var _art: Dictionary = {}
## Each moving piece and its idle cycle, base frame first.
static var _cycles: Dictionary = {}
static var _looked: bool = false

## What the rock and the cloak are multiplied by, and what the fire is. Set by
## the stage from its own sky, and **floored**: see `graded_for`.
var shade: Color = Color(0.22, 0.21, 0.26, 1.0)
var firelight: Color = Color(1.0, 0.72, 0.36, 1.0)

var _span: Vector2 = Vector2(1920.0, 1080.0)
var _time: float = 0.0
var _drawn_at: float = -1.0
var _rng := RandomNumberGenerator.new()
## The camp this visit: which side, what is in it, and where each piece sits.
var _camp: Dictionary = {}


func _ready() -> void:
	# **Unseeded, on purpose.** See the note at the top: the menu is not a run.
	_rng.randomize()
	_load_art()
	_pitch()
	set_process(true)


static func _load_art() -> void:
	if _looked:
		return
	_looked = true
	for key: String in [CLIFF_ART, SIT_ART, STAND_ART, RIDE_ART, HORSE_ART,
			LANTERN_ART]:
		if ResourceLoader.exists(key):
			_art[key] = load(key) as Texture2D
	# **Nothing out there is a statue** (owner, 2026-09-15: "there should be
	# aesthetic idle animations for them all"). The cloak snaps in the wind,
	# the seated Warden breathes, the horse's mane burns. Every cycle is
	# pinned to its own base frame so it closes, and the frames share one crop
	# box so the figure does not jitter between them.
	for key: String in [SIT_ART, STAND_ART, RIDE_ART, HORSE_ART]:
		var frames: Array[Texture2D] = []
		var base := _art.get(key) as Texture2D
		if base != null:
			frames.append(base)
		var stem: String = key.trim_suffix(".png")
		for index: int in range(1, 9):
			var path: String = "%s_idle_%02d.png" % [stem, index]
			if ResourceLoader.exists(path):
				frames.append(load(path) as Texture2D)
		_cycles[key] = frames


## Whether every piece is on disk. For the gate.
func furnished() -> bool:
	return _art.size() == 6


## How many frames a piece moves through. For the gate: a piece with one frame
## is a statue, and a statue in a scene where everything else breathes is the
## thing the eye lands on.
func frames_of(key: String) -> int:
	var frames: Array = _cycles.get(key, [])
	return frames.size()


## The frame of a piece to draw right now.
##
## Each piece runs on its own clock and its own offset, so the horse's mane and
## the rider's cloak are never in step - two things moving in lockstep read as
## one animation rather than two creatures.
func _frame_of(key: String, offset: float) -> Texture2D:
	var frames: Array = _cycles.get(key, [])
	if frames.is_empty():
		return _art.get(key) as Texture2D
	var index: int = int(floor((_time + offset) * Balance.MENU_CAMP_FRAME_RATE)) \
		% frames.size()
	return frames[index] as Texture2D


## Lay out a camp. Called once when the menu opens, and by the gate as often as
## it likes.
func _pitch() -> void:
	var pose: int = Pose.MOUNTED if _rng.randf() < Balance.MENU_CAMP_MOUNTED_CHANCE \
		else (Pose.SITTING if _rng.randf() < 0.55 else Pose.STANDING)
	_camp = {
		# **Always the bottom-right corner** (owner, 2026-09-15: "the cliff is
		# supposed to be in the bottom right corner, not out in the middle of
		# the scene, but rather closer to the foreground for parallax depth").
		# The first cut put it on either side and inside the frame, which made
		# it a thing standing in the scene rather than a thing the scene is
		# seen *past*. A foreground corner is what buys the depth.
		"side": 1.0,
		"pose": pose,
		# No cliff sometimes: the camp is then simply on the road, lower down
		# and smaller, which reads as further away.
		"cliff": _rng.randf() < Balance.MENU_CAMP_CLIFF_CHANCE,
		# A mounted Warden *is* the horse, so a second one would be two horses.
		"horse": pose != Pose.MOUNTED and _rng.randf() < Balance.MENU_CAMP_HORSE_CHANCE,
		"fire": _rng.randf() < Balance.MENU_CAMP_FIRE_CHANCE or pose == Pose.SITTING,
		"scale": _rng.randf_range(0.85, 1.18),
		# **Where along the bottom edge, and it is a narrow band on purpose.**
		# The corners are taken: buttons down the left, the run statistics down
		# the right, and a camp pitched in either of them is a silhouette with
		# words across it - which is what the first cut did. The band between
		# them is where the road is, and putting the Warden there also puts
		# them in front of Yuri, which is the depth cue the whole vignette is
		# built on.
		# Where the *figure* stands, in from the right edge. **Left of the run
		# statistics, which own the corner itself**: the rock runs on past the
		# Warden and off the screen, so the corner is filled and the ledge has
		# no visible far end, but the person is never standing under the words.
		"at": _rng.randf_range(Balance.MENU_CAMP_BAND.x, Balance.MENU_CAMP_BAND.y),
		"lift": _rng.randf_range(0.0, 0.05),
		# Which way the pieces face. The whole point is that they are looking at
		# the beast, so the figure faces toward the middle of the screen.
		"fire_side": 1.0 if _rng.randf() < 0.5 else -1.0,
		"phase": _rng.randf() * TAU,
		# **The lantern, usually but not always** (owner's words). On the
		# Warden when they are afoot, hanging off the horse when there is one -
		# a rider does not carry a lantern in a sword hand.
		"lantern": _rng.randf() < Balance.MENU_CAMP_LANTERN_CHANCE,
	}


## What is pitched out there right now. For the gate, and for the stage, which
## puts its own flame where the fire is.
func camp() -> Dictionary:
	return _camp.duplicate()


func resize(span: Vector2) -> void:
	if span.x > 0.0 and span.y > 0.0:
		_span = span


## Where the campfire burns, in this node's space, or a zero vector when this
## camp has no fire. The stage hangs a real `CampFire` here so the flame is the
## same animated flame the braziers use.
func fire_at() -> Vector2:
	if _camp.is_empty() or not bool(_camp["fire"]):
		return Vector2.ZERO
	var ground: Vector2 = _ground()
	return ground + Vector2(_figure_size() * 0.85 * float(_camp["fire_side"]),
		-_figure_size() * 0.06)


## How tall the Warden is drawn, in pixels. The number the whole vignette hangs
## on: see the note at the top for why it is deliberately small.
func _figure_size() -> float:
	if _camp.is_empty():
		return 0.0
	var near: float = 1.0 if bool(_camp["cliff"]) else Balance.MENU_CAMP_FAR_SCALE
	return _span.y * Balance.MENU_CAMP_FIGURE * float(_camp["scale"]) * near


## Where the camp's feet are.
func _ground() -> Vector2:
	if _camp.is_empty():
		return Vector2.ZERO
	var x: float = _span.x * (1.0 - float(_camp["at"]))
	# **Well clear of the bottom edge.** The first cut stood the camp two
	# hundredths of the screen off the bottom, which puts a figure's feet at the
	# very last row and a campfire half off the picture. A vignette that is cut
	# off is not a vignette.
	var y: float = _span.y * (Balance.MENU_CAMP_GROUND - float(_camp["lift"]))
	if bool(_camp["cliff"]):
		y -= _span.y * Balance.MENU_CAMP_CLIFF_LIFT
	return Vector2(x, y)


func _process(delta: float) -> void:
	_time += delta
	if _time - _drawn_at >= 1.0 / maxf(Balance.MENU_CAMP_HZ, 1.0):
		_drawn_at = _time
		queue_redraw()


func _draw() -> void:
	if _camp.is_empty():
		return
	var ground: Vector2 = _ground()
	var size: float = _figure_size()
	# The figure faces the middle of the screen, which is where the beast is.
	var facing: float = 1.0 if float(_camp["side"]) < 0.0 else -1.0

	if bool(_camp["cliff"]):
		# Wide and low, its top edge at the figure's feet. Drawn first so
		# everything else stands on it.
		var cliff := _art.get(CLIFF_ART) as Texture2D
		if cliff != null:
			var wide: float = size * Balance.MENU_CAMP_CLIFF_WIDTH
			var tall: float = wide * float(cliff.get_height()) \
				/ maxf(float(cliff.get_width()), 1.0)
			# **Its top edge at the figure's feet, and the rest hanging below**,
			# most of it off the bottom of the screen. The first cut centred it
			# on the feet, so two thirds of a rock face stood *above* the Warden
			# and the outcrop read as a boulder floating at the beast's
			# shoulder. A foreground ledge is the ground you are standing on.
			#
			# And darker than anything on it: this rock is a mass in shadow
			# between the viewer and the light, which makes it the one thing in
			# the vignette that should be close to a true silhouette.
			# Pushed toward the corner so its far end leaves the screen: a
			# foreground ledge with a visible right-hand end is a rock sitting
			# in the picture rather than the ground you are standing on.
			_blit(cliff, ground + Vector2(wide * Balance.MENU_CAMP_CLIFF_OFFSET,
					tall * (1.0 - surface_of(cliff))),
				wide, tall, facing,
				Color(shade.r * Balance.MENU_CAMP_ROCK,
					shade.g * Balance.MENU_CAMP_ROCK,
					shade.b * Balance.MENU_CAMP_ROCK, 1.0))

	if bool(_camp["horse"]):
		var horse: Texture2D = _frame_of(HORSE_ART, float(_camp["phase"]))
		if horse != null:
			var wide: float = size * 1.5
			var tall: float = wide * float(horse.get_height()) \
				/ maxf(float(horse.get_width()), 1.0)
			# Behind and a little aside, so it never covers the person.
			_blit(horse, ground + Vector2(-size * 0.78 * facing, 0.0),
				wide, tall, facing, _emberish(shade))

	var pose: int = int(_camp["pose"])
	var key: String = SIT_ART if pose == Pose.SITTING \
		else (STAND_ART if pose == Pose.STANDING else RIDE_ART)
	var figure: Texture2D = _frame_of(key, float(_camp["phase"]) * 0.37)
	if figure != null:
		var wide: float = size * (1.55 if pose == Pose.MOUNTED else 0.8)
		var tall: float = wide * float(figure.get_height()) \
			/ maxf(float(figure.get_width()), 1.0)
		# A mounted rider is only partly a silhouette: the horse under them is
		# on fire and has to keep it.
		_blit(figure, ground, wide, tall, facing,
			_emberish(shade) if pose == Pose.MOUNTED else shade)
		_draw_lantern(ground, size, tall, facing, pose)


## The lantern, and where it hangs.
##
## On a walking Warden it hangs from the hand at about hip height; with a horse
## in the camp it hangs off the saddle instead, because a rider does not carry
## a lantern in a sword hand. It keeps almost all of its own brightness - it is
## the second light source in the vignette and grading it dark would put it out.
func _draw_lantern(ground: Vector2, size: float, tall: float, facing: float,
		pose: int) -> void:
	if not bool(_camp["lantern"]):
		return
	var lamp := _art.get(LANTERN_ART) as Texture2D
	if lamp == null:
		return
	var high: float = size * Balance.MENU_CAMP_LANTERN_SIZE
	var wide: float = high * float(lamp.get_width()) \
		/ maxf(float(lamp.get_height()), 1.0)
	var hangs: Vector2 = ground
	if pose == Pose.MOUNTED or bool(_camp["horse"]):
		hangs += Vector2(-size * 0.62 * facing, -tall * 0.42)
	else:
		hangs += Vector2(size * 0.26 * facing, -tall * 0.44)
	# A slow swing, on the camp's own phase so two visits never match.
	var swing: float = sin(_time * 0.9 + float(_camp["phase"])) * 0.07
	draw_set_transform(hangs, swing, Vector2(facing, 1.0))
	draw_texture_rect(lamp, Rect2(-wide * 0.5, 0.0, wide, high), false,
		Color(firelight.r, firelight.g, firelight.b, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where the flat top of a piece of ground is, as a fraction of its height.
##
## **Measured, not written down.** The outcrop is painted with grass tufts along
## its lip, so its topmost pixel is a blade of grass some way above the surface
## anything would actually stand on - and standing the Warden on the sprite's
## top edge floated the whole camp a sixth of the rock's height in the air. The
## surface is the first row that is nearly as wide as the widest, which for this
## outcrop is 18 rows down out of 105.
##
## Measure it again rather than adjusting a number if the rock is ever redrawn;
## `menu_camp_check` reads this back against the art.
static var _surfaces: Dictionary = {}


static func surface_of(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var key: String = texture.resource_path
	if _surfaces.has(key):
		return _surfaces[key]
	var found: float = 0.0
	var image: Image = texture.get_image()
	if image != null:
		var widest: int = 0
		var rows: Array[int] = []
		for y: int in image.get_height():
			var count: int = 0
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.25:
					count += 1
			rows.append(count)
			widest = maxi(widest, count)
		for y: int in rows.size():
			if widest > 0 and float(rows[y]) >= float(widest) * 0.92:
				found = float(y) / float(maxi(image.get_height() - 1, 1))
				break
	if not key.is_empty():
		_surfaces[key] = found
	return found


## One piece, standing on `ground`, mirrored to face the middle.
func _blit(texture: Texture2D, ground: Vector2, wide: float, tall: float,
		facing: float, tint: Color) -> void:
	draw_set_transform(ground, 0.0, Vector2(facing, 1.0))
	draw_texture_rect(texture, Rect2(-wide * 0.5, -tall, wide, tall), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The shade a figure standing on ground of this colour should be drawn in.
##
## **A modulate can only take light away, and this art has none to spare.** The
## first cut graded the Warden the way the beast is graded - the local ground
## colour, pushed dark - and produced a multiplier of 0.16 over sprites that
## were *already* drawn as near-silhouettes. A dark figure times a sixth is
## black, and the camp was a fire burning beside nobody. The beast can be graded
## that way because the beast is painted in mid-tones; these are not.
##
## So this is the *foliage* grade rather than the beast grade: the scene's hue
## at a third, over an exposure with a hard floor. The sprites keep almost all
## of their own value and take the colour of the light around them - which is
## all the grading a silhouette can honestly accept.
##
## And on dark ground it warms toward the firelight rather than darkening
## further, because somebody standing by a fire on a dark road is lit by the
## fire. That is the same shape as the birds, in a different corner of the same
## screen, and for the same reason.
static func graded_for(ground: Color, firelight: Color) -> Color:
	var peak: float = maxf(maxf(ground.r, ground.g), maxf(ground.b, 0.001))
	var hue := Color(ground.r / peak, ground.g / peak, ground.b / peak)
	var lit: float = ground.get_luminance()
	var exposure: float = clampf(Balance.MENU_CAMP_FLOOR + lit * 1.6,
		Balance.MENU_CAMP_FLOOR, 1.0)
	var mixed: Color = Color.WHITE.lerp(hue, Balance.MENU_CAMP_TINT)
	var shade := Color(mixed.r * exposure, mixed.g * exposure, mixed.b * exposure, 1.0)
	if lit >= Balance.MENU_CAMP_DARK_GROUND:
		return shade
	var toward: float = clampf(1.0 - lit / Balance.MENU_CAMP_DARK_GROUND, 0.0, 1.0)
	return shade.lerp(Color(firelight.r, firelight.g * 0.86, firelight.b * 0.74, 1.0),
		toward * Balance.MENU_CAMP_FIRELIT)


## A shade for something that is partly on fire: pulled back toward the
## firelight so the flames in the art survive the grading that the rock and the
## cloak are supposed to take. The same distinction the fireflies are drawn
## under - a light source is not lit by the scene.
func _emberish(dark: Color) -> Color:
	return dark.lerp(firelight, Balance.MENU_CAMP_EMBER_KEEP)
