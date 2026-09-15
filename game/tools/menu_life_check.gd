extends Node

## The menu is alive: birds crossing the sky and fireflies over the valley.
##
## Owner brief, 2026-09-15. Both are procedural, so both are the kind of thing
## that looks finished in a screenshot and is wrong in motion - a sky where the
## birds pile up and never leave, a swarm that blinks in unison, a bird drawn
## big enough to shrink the gate it flies under. Those are the failures held
## here; what the corner actually *looks* like is `menu_shot`'s job and is said
## so in `menu_foliage_check` for the same reason.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_every_species_has_its_wingbeat()
	_test_the_birds_stay_tiny_and_dim()
	_test_a_bird_is_visible_against_any_sky()
	_test_the_sky_never_fills_up()
	_test_the_species_actually_fly_differently()
	_test_the_fireflies_keep_their_own_time()
	_test_the_fireflies_stay_over_the_greenery()
	_finish()


## A species with no art is simply not in the sky, which is the right fallback
## and a silent one - so it is checked rather than relied on.
func _test_every_species_has_its_wingbeat() -> void:
	for base: String in MenuBirds.ART:
		_check(ResourceLoader.exists(base + ".png"), "%s.png must exist" % base)
		var texture: Texture2D = load(base + ".png") as Texture2D
		_check(texture != null and texture.get_width() == 64 and texture.get_height() == 32,
			"%s.png must be 64x32, the manifest's size" % base)
		for index: int in range(1, 6):
			var path: String = "%s_fly_%02d.png" % [base, index]
			_check(ResourceLoader.exists(path), "%s must exist" % path)
	var birds: MenuBirds = _birds()
	_check(birds.winged(),
		"every species must have loaded its frames, or the sky is quietly short of birds")
	birds.queue_free()


## **Tiny is the brief, and it is a statement about the gate.** The scene says
## that a beast with a city on its back walks under that arch; a bird drawn at
## a believable size for its own sake shrinks the arch to a garden gate. And
## dim rather than black: a pure silhouette is a hole cut in the picture.
func _test_the_birds_stay_tiny_and_dim() -> void:
	var birds: MenuBirds = _birds()
	birds.resize(Vector2(1920.0, 1080.0))
	var widest: float = 0.0
	for _step: int in 3000:
		birds.call("_process", 0.05)
		widest = maxf(widest, birds.widest())
	_check(widest > 2.0, "the birds must be drawn at all (%0.1f px)" % widest)
	_check(widest <= 1080.0 * 0.02,
		("a bird must stay tiny against the gate: %0.1f px at 1080p, against the "
			+ "21 px that is already generous") % widest)
	var tint: Color = birds.tint
	_check(tint.get_luminance() < 0.5,
		"a bird must be a dim shape rather than a lit one (%0.3f)" % tint.get_luminance())
	_check(tint.get_luminance() > 0.02,
		("and not a pure silhouette, which reads as a hole in the picture "
			+ "(%0.3f)") % tint.get_luminance())
	birds.queue_free()


## **A bird nobody can see is not a bird.**
##
## The first cut of this shipped seven birds in the sky and not one of them was
## visible, and every number said it was working: the flock was launching, it
## was on screen, it was ten pixels wide, its node was visible and its modulate
## was white. What was wrong is the one thing none of that measures - the whole
## flock shared a tint sampled from the top of the backdrop, which in this scene
## is a dark purple, multiplied down to a near-silhouette. A near-black bird on
## a near-black sky is nothing at all, and the owner's brief says so in as many
## words: "not completely blacked out".
##
## Each bird is shaded against the stretch of sky it is about to cross now, and
## this drives that with both extremes of sky and measures the separation.
func _test_a_bird_is_visible_against_any_sky() -> void:
	var birds: MenuBirds = _birds()
	birds.resize(Vector2(1920.0, 1080.0))
	for sky: Color in [Color(0.04, 0.03, 0.07), Color(0.45, 0.28, 0.2),
			Color(0.75, 0.62, 0.5)]:
		birds.sky_at = func(_at: Vector2) -> Color: return sky
		var shade: Color = birds.call("_shade_for", Vector2(960.0, 200.0))
		var apart: float = absf(shade.get_luminance() - sky.get_luminance())
		_check(apart > 0.03,
			("a bird over a sky of %0.3f is drawn at %0.3f, which is nothing at "
				+ "all against it") % [sky.get_luminance(), shade.get_luminance()])
		_check(shade.get_luminance() < 0.62,
			"and it must never be a bright bird (%0.3f)" % shade.get_luminance())
	# Against a bright sky it is a silhouette; against a dark one it catches the
	# light. Both are real and the difference is the whole trick.
	birds.sky_at = func(_at: Vector2) -> Color: return Color(0.75, 0.62, 0.5)
	var bright: Color = birds.call("_shade_for", Vector2(960.0, 200.0))
	birds.sky_at = func(_at: Vector2) -> Color: return Color(0.04, 0.03, 0.07)
	var dark: Color = birds.call("_shade_for", Vector2(960.0, 200.0))
	_check(bright.get_luminance() < 0.75,
		"a bird against a bright sky must be darker than it")
	_check(dark.get_luminance() > 0.04,
		"and a bird against a dark sky must be lighter than it (%0.3f)"
			% dark.get_luminance())
	birds.queue_free()


## A bird that never leaves is a bird that accumulates. Run the sky for an hour
## and count what is in it.
func _test_the_sky_never_fills_up() -> void:
	var birds: MenuBirds = _birds()
	birds.resize(Vector2(1920.0, 1080.0))
	var most: int = 0
	var launched: bool = false
	for _step: int in 72000:
		birds.call("_process", 0.05)
		most = maxi(most, birds.flying())
		if birds.flying() > 0:
			launched = true
	_check(launched, "birds must actually be launched")
	_check(most <= Balance.MENU_BIRD_CEILING,
		"the sky held %d birds against a ceiling of %d"
			% [most, Balance.MENU_BIRD_CEILING])
	_check(birds.flying() <= Balance.MENU_BIRD_CEILING,
		"and it must still be under the ceiling an hour later (%d)" % birds.flying())
	birds.queue_free()


## Four species is only worth four species if they fly differently. The tables
## are what say so, and a copy-paste that gave them all one beat would leave
## four identical shapes crossing the same sky.
func _test_the_species_actually_fly_differently() -> void:
	var beats: Array[float] = MenuBirds.BEATS
	var bob: Array[float] = MenuBirds.BOB
	var beating: Array[float] = MenuBirds.BEATING
	for table: Array in [beats, bob, beating, MenuBirds.WEIGHT, MenuBirds.FLOCK]:
		_check(table.size() == MenuBirds.ART.size(),
			"every per-species table must have one entry a species (%d of %d)"
				% [table.size(), MenuBirds.ART.size()])
	var distinct: Dictionary = {}
	for index: int in beats.size():
		distinct["%0.2f|%0.2f|%0.2f" % [beats[index], bob[index], beating[index]]] = true
	_check(distinct.size() == beats.size(),
		"two species fly identically: %d distinct flights of %d"
			% [distinct.size(), beats.size()])
	# A soarer must actually soar, and a flapper must actually flap. Without
	# this the tables can differ by a hundredth and satisfy the check above.
	_check(beating[MenuBirds.Species.EAGLE] < 0.3
			and beating[MenuBirds.Species.HAWK] < 0.5,
		"the soarers must hold their wings most of the time")
	_check(beating[MenuBirds.Species.RAVEN] > 0.6
			and beating[MenuBirds.Species.TOUCAN] > 0.6,
		"and the flappers must beat almost all of it")


## **A swarm that blinks together is a string of fairy lights.** Each firefly
## keeps its own clock and its own rate, and the blink is mostly dark - which
## is the shape of the real thing and the thing a plain sine gets wrong.
func _test_the_fireflies_keep_their_own_time() -> void:
	var flies: MenuFireflies = _fireflies()
	flies.resize(Vector2(1920.0, 1080.0))
	_check(flies.alive() > 8, "there must be a swarm (%d)" % flies.alive())
	# **Measured as when each one next flares, not as what they look like right
	# now.** A snapshot of brightnesses is mostly zeroes whatever the swarm is
	# doing - the blink is deliberately dark for most of its cycle - so the
	# first cut of this check read 15 distinct values out of 34 and failed a
	# swarm that was working perfectly. When a fly peaks is the question.
	var peaked: Dictionary = {}
	var waiting: Array[int] = []
	for index: int in flies.alive():
		waiting.append(index)
	for step: int in 400:
		flies.call("_process", 0.05)
		var still: Array[int] = []
		for index: int in waiting:
			if flies.brightness_of(index) > 0.85:
				peaked[step] = true
			else:
				still.append(index)
		waiting = still
	_check(peaked.size() > 12,
		("the swarm must not blink in unison: its flies peaked at %d distinct "
			+ "moments over twenty seconds") % peaked.size())
	# Mostly off. Sampled over a stretch of time on one fly rather than across
	# the swarm, because the swarm's spread would hide a bead that pulses.
	var lit: int = 0
	var samples: int = 0
	for _step: int in 900:
		flies.call("_process", 0.05)
		samples += 1
		if flies.brightness_of(0) > 0.5:
			lit += 1
	var duty: float = float(lit) / float(maxi(samples, 1))
	_check(duty < 0.35,
		"a firefly must be dark most of the time: lit for %0.0f%% of it" % (duty * 100.0))
	_check(duty > 0.01, "and it must light up at all (%0.2f%%)" % (duty * 100.0))
	flies.queue_free()


## They wander, and they wander *somewhere*: the greenery, which is the lower
## part of the screen and its corners. An even sprinkle of dots over the whole
## picture is a starfield.
func _test_the_fireflies_stay_over_the_greenery() -> void:
	var flies: MenuFireflies = _fireflies()
	var span := Vector2(1920.0, 1080.0)
	flies.resize(span)
	var before: Vector2 = flies.position_of(0)
	var highest: float = span.y
	var travelled: float = 0.0
	for _step: int in 2400:
		flies.call("_process", 0.05)
		for index: int in flies.alive():
			highest = minf(highest, flies.position_of(index).y)
		travelled = maxf(travelled, before.distance_to(flies.position_of(0)))
	_check(travelled > 20.0,
		"a firefly must actually wander (%0.1f px in two minutes)" % travelled)
	_check(highest > span.y * 0.3,
		("the swarm must stay over the valley rather than climbing into the sky "
			+ "(reached y %0.0f of %0.0f)") % [highest, span.y])
	flies.queue_free()


func _birds() -> MenuBirds:
	var node := MenuBirds.new()
	add_child(node)
	return node


func _fireflies() -> MenuFireflies:
	var node := MenuFireflies.new()
	add_child(node)
	return node


func _finish() -> void:
	if _failures == 0:
		print("[menu-life] PASS - %d checks: four wingbeats on disk, birds tiny and dim and never piling up, and a swarm that keeps its own time over the valley" % _checks)
	else:
		push_error("[menu-life] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[menu-life] FAIL: %s" % why)
