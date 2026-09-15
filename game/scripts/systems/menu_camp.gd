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
## **What else is up there** (owner, 2026-09-15: "make more props that can also
## be placed around the cliffs for world building").
##
## Eleven, because two or three are drawn and a set of four would repeat inside
## a session. Each is a thing somebody camped here would have put down, and none
## of them is a light - the fire and the lantern are the only two sources in the
## vignette and a third would flatten both.
const PROP_ART: Array[String] = [
	"res://art/ui/menu_prop_tent.png",
	"res://art/ui/menu_prop_woodpile.png",
	"res://art/ui/menu_prop_rack.png",
	"res://art/ui/menu_prop_banner.png",
	"res://art/ui/menu_prop_cairn.png",
	"res://art/ui/menu_prop_crates.png",
	"res://art/ui/menu_prop_bedroll.png",
	"res://art/ui/menu_prop_totem.png",
	"res://art/ui/menu_prop_cart.png",
	"res://art/ui/menu_prop_pillar.png",
	"res://art/ui/menu_prop_pelts.png",
]
## How tall each is drawn against the Warden. A tent is chest height on a
## standing person and a bedroll is at their ankle; one scale for all eleven
## would put a cairn the size of a horse beside them.
const PROP_HEIGHT: Array[float] = [
	0.95, 0.42, 0.78, 1.35, 0.62, 0.50, 0.24, 1.05, 0.55, 0.88, 0.80,
]

static var _art: Dictionary = {}
## Each moving piece and its idle cycle, base frame first.
static var _cycles: Dictionary = {}
static var _looked: bool = false

## What the rock and the cloak are multiplied by, and what the fire is. Set by
## the stage from its own sky, and **floored**: see `graded_for`.
var shade: Color = Color(0.22, 0.21, 0.26, 1.0)
var firelight: Color = Color(1.0, 0.72, 0.36, 1.0)
## How bright the camp's own fire is at this instant, pushed in by the stage
## from `CampFire.flicker`. One is the fire at full; it never reaches zero.
##
## Read only where the *firelight* reaches - the ember shade and the lantern -
## and never by the grading of rock the fire is not on. A whole cliff
## brightening in time with a campfire is a stage light, not a fire.
var fire_pulse: float = 1.0
## The pass that lights the burning parts of what is up there. A node of its
## own because a blend mode belongs to a canvas item and this one is drawn
## over the same art the camp has already drawn - see `fire_sheen.gdshader`.
var _fire_sheen: Node2D = null
var _fire_paint: ShaderMaterial = null

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
	var wanted: Array[String] = [CLIFF_ART, SIT_ART, STAND_ART, RIDE_ART,
		HORSE_ART, LANTERN_ART]
	wanted.append_array(PROP_ART)
	for key: String in wanted:
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
	# **Derived, not counted by hand.** This said `== 6` and adding the
	# eleven ledge props made it false, which reported as the camp being
	# "quietly missing somebody" - the one thing it exists to catch, said
	# about a camp that had everything.
	return _art.size() == 6 + PROP_ART.size()


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
		"props": _pick_props(),
	}


## Which props are up there this visit, where each one stands and how big.
##
## **Drawn without replacement**, so a camp never has two tents. Each is placed
## along the ledge by a *fraction of the figure's own size* rather than by
## pixels, because the figure's size is itself rolled - a prop placed in pixels
## would crowd a big Warden and float away from a small one.
##
## Behind the figure, never in front: this vignette's whole job is that a person
## is standing there looking at the beast, and a crate drawn over their knees
## costs that for a crate. The near side of the ledge stays clear.
func _pick_props() -> Array:
	var chosen: Array = []
	var bag: Array[int] = []
	for index: int in PROP_ART.size():
		bag.append(index)
	var many: int = Balance.MENU_CAMP_PROPS_MIN + int(_rng.randi() % \
		maxi(Balance.MENU_CAMP_PROPS_MAX - Balance.MENU_CAMP_PROPS_MIN + 1, 1))
	for _taken: int in mini(many, bag.size()):
		var at: int = int(_rng.randi() % bag.size())
		var which: int = bag[at]
		bag.remove_at(at)
		chosen.append({
			"art": which,
			# Out along the ledge away from the figure, in figure-widths. The
			# near end is kept clear so nothing stands between the viewer and
			# the Warden.
			"out": _rng.randf_range(0.9, 2.6),
			"lift": _rng.randf_range(-0.04, 0.02),
			"size": _rng.randf_range(0.86, 1.14),
			"mirror": _rng.randf() < 0.5,
		})
	return chosen


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


## The burning pass, built once and drawn over everything the camp draws.
##
## **Skipped headless**, where the dummy renderer cannot compile a shader and
## says so as an error the sweep reads as a failure - the same guard the
## wordmark and the frame carry.
func _light_the_fire() -> void:
	if _fire_sheen != null or DisplayServer.get_name() == "headless":
		return
	_fire_paint = ShaderMaterial.new()
	_fire_paint.shader = load("res://scripts/shaders/fire_sheen.gdshader")
	_fire_paint.set_shader_parameter("strength", Balance.MENU_CAMP_FIRE_SHEEN)
	_fire_paint.set_shader_parameter("glow", Vector3(firelight.r, firelight.g,
		firelight.b))
	_fire_sheen = Node2D.new()
	_fire_sheen.name = "FireSheen"
	_fire_sheen.material = _fire_paint
	_fire_sheen.draw.connect(_draw_burning)
	add_child(_fire_sheen)


## What burns up there: the horse's mane and hooves, and a mounted rider's
## mount under them. The shader decides *which pixels* - see the note on it -
## so this only has to say which sprites to offer.
func _draw_burning() -> void:
	if _camp.is_empty() or _fire_sheen == null:
		return
	var ground: Vector2 = _ground()
	var size: float = _figure_size()
	var facing: float = 1.0 if float(_camp["side"]) < 0.0 else -1.0
	var lit := Color(1.0, 1.0, 1.0, clampf(fire_pulse, 0.6, 1.2))
	if bool(_camp["horse"]):
		var horse: Texture2D = _frame_of(HORSE_ART, float(_camp["phase"]))
		if horse != null:
			var wide: float = size * 1.5
			var tall: float = wide * float(horse.get_height()) \
				/ maxf(float(horse.get_width()), 1.0)
			_burn(horse, ground + Vector2(-size * 0.78 * facing, 0.0),
				wide, tall, facing, lit)
	if int(_camp["pose"]) == Pose.MOUNTED:
		var rider: Texture2D = _frame_of(RIDE_ART, float(_camp["phase"]) * 0.37)
		if rider != null:
			var wide: float = size * 1.55
			var tall: float = wide * float(rider.get_height()) \
				/ maxf(float(rider.get_width()), 1.0)
			_burn(rider, ground, wide, tall, facing, lit)


func _burn(texture: Texture2D, ground: Vector2, wide: float, tall: float,
		facing: float, tint: Color) -> void:
	_fire_sheen.draw_set_transform(ground, 0.0, Vector2(facing, 1.0))
	_fire_sheen.draw_texture_rect(texture, Rect2(-wide * 0.5, -tall, wide, tall),
		false, tint)
	_fire_sheen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _process(delta: float) -> void:
	_time += delta
	if _time - _drawn_at >= 1.0 / maxf(Balance.MENU_CAMP_HZ, 1.0):
		_drawn_at = _time
		queue_redraw()
		_light_the_fire()
		if _fire_sheen != null:
			_fire_sheen.queue_redraw()
		if _fire_paint != null:
			# Fed from here rather than read from `TIME`, so the flame stops
			# with the menu instead of running under a dialog.
			_fire_paint.set_shader_parameter("clock", _time)


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
			#
			# **Graded like the rock now, not spared like a light.** It used to
			# be drawn toward the firelight so that the flames in its art would
			# survive the grading - which kept its whole body bright, and the
			# owner reported the camp as needing "proper colour grading and
			# tint for the scene". The burning pass puts the fire back on top
			# (see `_draw_burning`), so the base is free to sit in the dark with
			# everything else, and the flames read hotter for having something
			# dark to be hot against.
			_blit(horse, ground + Vector2(-size * 0.78 * facing, 0.0),
				wide, tall, facing, shade)

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
		# A rider is graded like anyone else: the mount under them burns, and
		# the burning pass is what says so.
		_blit(figure, ground, wide, tall, facing, shade)
		_draw_lantern(ground, size, tall, facing, pose)
	_draw_props(ground, size, facing)


## The camp's own things, standing on the ledge behind the Warden.
##
## **Graded like the rock, not like the fire.** These are objects the light
## falls on rather than sources of it, so they take `shade` exactly as the cliff
## does - and the ones near enough to the fire warm slightly toward it, which is
## the same distinction the rider and the horse are drawn under.
##
## Drawn *after* the figure and away from it, so tree order and distance both
## say the same thing about what is in front of what.
func _draw_props(ground: Vector2, size: float, facing: float) -> void:
	var props: Array = _camp.get("props", [])
	if props.is_empty() or size <= 0.0:
		return
	var fire: Vector2 = fire_at()
	for prop: Dictionary in props:
		var which: int = int(prop["art"])
		if which < 0 or which >= PROP_ART.size():
			continue
		var texture := _art.get(PROP_ART[which]) as Texture2D
		if texture == null:
			continue
		var tall: float = size * PROP_HEIGHT[which] * float(prop["size"])
		var wide: float = tall * float(texture.get_width()) \
			/ maxf(float(texture.get_height()), 1.0)
		var at: Vector2 = ground + Vector2(size * float(prop["out"]) * -facing,
			size * float(prop["lift"]))
		# Warmed by how close it is to the fire, and by nothing else. A prop at
		# the far end of the ledge is lit by the sky like the rock it stands on.
		var warmth: float = 0.0
		if fire != Vector2.ZERO:
			warmth = clampf(1.0 - at.distance_to(fire) / maxf(size * 2.4, 1.0), 0.0, 1.0)
		var lit: Color = shade.lerp(_emberish(shade),
			warmth * Balance.MENU_CAMP_PROP_FIRELIGHT)
		_blit(texture, at, wide, tall,
			-facing if bool(prop["mirror"]) else facing, lit)


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
	# The pulse rides on how *much* firelight is kept rather than on the
	# colour, so a dim moment pulls the figure back toward its own shade
	# instead of turning the fire brown.
	return dark.lerp(firelight,
		Balance.MENU_CAMP_EMBER_KEEP * clampf(fire_pulse, 0.6, 1.15))
