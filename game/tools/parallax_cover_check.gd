extends Node

## Every parallax layer in the beast scope covers the whole screen, at every
## point on its own scroll and at every shape of window.
##
##   godot --headless --path game res://tools/parallax_cover_check.tscn
##
## **The fault this exists for was in four places at once and had shipped in all
## of them.** `ParallaxBand`, `ParallaxScatter`, `ParallaxStrip` and the scope's
## own sky each laid their content down starting at their *own origin* and
## running forward two periods, and the scroll slides them backward over one
## period. The scope's camera sits on that origin, so the view straddles it and
## content beginning at 0 begins in the middle: whenever a layer had travelled
## less than half a period, the left of the screen had no layer on it. A far
## ridge ending at a hard vertical edge with sky beside it, on roughly every
## other stretch of road.
##
## Every one of those four said, in as many words, that two copies were enough.
## They were written from the same reasoning and inherited the same hole, which
## is why this measures the real nodes rather than reading a constant back.
##
## **And two periods either side is not a constant either.** The project ships a
## 1280x592 landscape phone whose visible world is 2,335 units wide - CI builds
## for it - against a near band whose period is 1,152 and a sky whose guaranteed
## reach was 967. So the layers ask `ParallaxBand.periods_for` how many copies
## the *viewport* needs, and this walks four window shapes to hold them to it.
##
## It drives the **real beast scope**, not a rebuild of it. A gate that stood the
## layers up itself would have to repeat the scope's band widths, and a layer
## added to the scope tomorrow would simply not be looked at - which is the
## failure `gathering_check` had to be rewritten to avoid on 2026-09-13.

## Distances to sweep, in world units travelled.
##
## Deliberately not round numbers and deliberately dense: the fault appears for
## the *first* half of each period and hides for the second, so a sweep that
## happened to land on multiples of a band width would have reported a clean
## scope. The slowest layer moves 0.11 units a unit travelled and the fastest
## 1.35, so this walks each of them past several of their own periods.
const DISTANCES: Array[float] = [0.0, 37.0, 113.0, 260.0, 401.0, 640.0, 913.0,
	1290.0, 1777.0, 2404.0, 3111.0, 4098.0, 5303.0, 6890.0, 8642.0, 11303.0]

## Window shapes to hold every layer to.
##
## The desktop shape the layers were written against, the landscape phone
## `layout (phone landscape)` already builds for, an ultrawide desktop, and an
## upright phone. The landscape phone is the one that mattered: with the
## project's "expand" stretch a window wider than 16:9 is handed *more world*
## rather than a stretched one, so the shape with the fewest pixels asks the
## layers to cover the most ground.
const SHAPES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 592),
	Vector2i(2560, 1080), Vector2i(430, 932)]

var _failures: PackedStringArray = []
var _checks: int = 0
var _half: float = 960.0


func _ready() -> void:
	MetaState.hold_saves()
	for shape: Vector2i in SHAPES:
		await _drive_the_scope(shape)
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[parallax] PASS - %d checks: %d shapes x %d distances, every "
			% [_checks, SHAPES.size(), DISTANCES.size()]
			+ "layer covers the view and the ladder is in depth order")
	else:
		for failure: String in _failures:
			push_error("[parallax] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## Stands up the real scope at one window shape, walks it down the road and
## measures what it drew.
func _drive_the_scope(shape: Vector2i) -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = shape
	await get_tree().process_frame
	RunState.reset()
	GameDirector.run_active = true
	# Act III, because its skyline strip and its ground are the ones the banding
	# was reported against - and because a region past the first proves the
	# per-act rebuild puts the periods back.
	RunState.act = 3
	RunState.terrain_id = "snow"
	# **Walking, not standing.** The scope freezes its parallax during
	# Preparation - correctly, the beast is at rest - and `RunState.reset` leaves
	# the run in exactly that phase. A first cut of this gate swept sixteen
	# distances against a scope that had never scrolled once and reported every
	# layer as covering the view, because they were all still sitting at their
	# origin. The ladder test below is what caught it: a rate of zero is not a
	# slow layer, it is a scope that is not moving.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var scene: PackedScene = load("res://scenes/run/beast_scope.tscn") as PackedScene
	var scope: BeastScope = scene.instantiate() as BeastScope
	add_child(scope)
	for _f: int in 4:
		await get_tree().process_frame

	# Measured off the scope's own viewport, so the gate and the layers are
	# reading the same number rather than agreeing about a constant.
	_half = ParallaxBand.half_view(scope)
	_test_the_baselines_are_stacked()
	_test_every_strip_reaches_its_edges()
	await _test_the_ladder_is_in_order(scope)
	var layers: Array[Node] = []
	_gather(scope, layers)
	_check(layers.size() >= 5,
		"%s: the scope stood up %d parallax layers; it builds at least five"
			% [shape, layers.size()])
	for distance: float in DISTANCES:
		RunState.distance_travelled = distance
		await get_tree().process_frame
		for layer: Node in layers:
			_measure(layer, distance, shape)
		_measure_the_sky(scope, distance, shape)
	scope.queue_free()
	await get_tree().process_frame


func _gather(from: Node, into: Array[Node]) -> void:
	for child: Node in from.get_children():
		if child is ParallaxBand or child is ParallaxScatter or child is ParallaxStrip:
			into.append(child)
		_gather(child, into)


## One layer, at one distance, at one shape.
##
## A silhouette and a strip are continuous and must *cover* the view; a scatter
## is discrete props and cannot, so what is asked of it is that it has props on
## both sides of the screen. A scatter with nothing to the left of the camera is
## the same fault wearing different clothes.
func _measure(layer: Node, distance: float, shape: Vector2i) -> void:
	var label: String = String(layer.name)
	if layer is ParallaxBand:
		var band := layer as ParallaxBand
		if band.band_width <= 0.0:
			return
		var spread: Array[int] = ParallaxBand.periods_for(band.band_width, _half)
		var left: float = band.position.x + float(spread.min()) * band.band_width
		var right: float = band.position.x + float(spread.max() + 1) * band.band_width
		_check(left <= -_half and right >= _half,
			"%s %s at %.0f: drawn across [%.0f, %.0f], view is [%.0f, %.0f]"
				% [shape, label, distance, left, right, -_half, _half])
		return
	var sprites: Array[Node] = []
	for child: Node in layer.get_children():
		if child is Sprite2D:
			sprites.append(child)
	if sprites.is_empty():
		# A region with no art for this layer draws nothing, which is a supported
		# state rather than a gap - the strip says so itself.
		return
	var reach: Vector2 = _art_span(sprites, (layer as Node2D).position.x)
	_check(reach.x <= -_half and reach.y >= _half,
		"%s %s at %.0f: art reaches [%.0f, %.0f], view is [%.0f, %.0f]"
			% [shape, label, distance, reach.x, reach.y, -_half, _half])


## The sky, which is the scope's own sprites rather than a parallax class.
##
## It had one mirrored clone one width to the right, which covers `[-w/2, 3w/2]`
## of its own space against a scroll over `(-w, 0]` - a guarantee of 967 units
## either side of the camera, and the landscape phone wants 1,167.
func _measure_the_sky(scope: BeastScope, distance: float, shape: Vector2i) -> void:
	if scope.backdrop == null or scope.backdrop.texture == null:
		return
	var sprites: Array[Node] = []
	for child: Node in scope.backdrop.get_parent().get_children():
		var sprite := child as Sprite2D
		if sprite != null and sprite.z_index == Balance.BEAST_BACKDROP_Z:
			sprites.append(sprite)
	if sprites.is_empty():
		return
	var reach: Vector2 = _art_span(sprites, 0.0)
	_check(reach.x <= -_half and reach.y >= _half,
		"%s sky at %.0f: painted across [%.0f, %.0f], view is [%.0f, %.0f]"
			% [shape, distance, reach.x, reach.y, -_half, _half])


## The leftmost and rightmost world x a set of sprites actually paints.
##
## `centered` and `flip_h` both move where the art lands relative to its node,
## and these layers use each of them.
func _art_span(sprites: Array[Node], carried: float) -> Vector2:
	var left: float = INF
	var right: float = -INF
	for node: Node in sprites:
		var sprite := node as Sprite2D
		var wide: float = 0.0
		if sprite.texture != null:
			wide = float(sprite.texture.get_width()) * absf(sprite.scale.x)
		var at: float = carried + sprite.position.x
		var from: float = at - wide * 0.5 if sprite.centered \
			else (at - wide if sprite.flip_h else at)
		left = minf(left, from)
		right = maxf(right, from + wide)
	return Vector2(left, right)


## The painted horizon's foot is behind the ridge, which is why it carries no
## fill of its own.
##
## `ParallaxStrip` drew a rectangle of its own base colour below its baseline for
## a while, on the reasoning that a trimmed silhouette otherwise ends in a cut
## across the sky. It was never visible: the ridge is an opaque polygon filled
## from its own skyline down past the ground, and it starts *above* the strip's
## foot. The fill was deleted, and this is what stops it being written again the
## next time somebody worries about the cut.
func _test_the_baselines_are_stacked() -> void:
	_check(Balance.BEAST_SKYLINE_BASELINE >= Balance.BEAST_RIDGE_BASELINE,
		"the skyline's foot is at %.0f and the ridge's is at %.0f: the strip's "
			% [Balance.BEAST_SKYLINE_BASELINE, Balance.BEAST_RIDGE_BASELINE]
			+ "last row is no longer covered, so it needs a fill again")
	_check(Balance.BEAST_RIDGE_Z > Balance.BEAST_SKYLINE_Z,
		"the ridge is at z %d and the skyline at %d: the ridge no longer draws "
			% [Balance.BEAST_RIDGE_Z, Balance.BEAST_SKYLINE_Z]
			+ "in front of the strip it is covering")


## A horizon strip's art has to touch both edges of its own image.
##
## `ParallaxStrip` lays a strip down in mirrored pairs, which is what buys a
## painted horizon per region for one asset each instead of a tiling puzzle each.
## The whole trick rests on one property of the *canvas* rather than of the
## drawing: a transparent margin at the left or right edge is a column of sky at
## every join, about 35 device pixels of it at the scale these are drawn.
##
## Three of the first ten shipped with one - the Verdant Maw with 20 pixels
## either side, the saltpan with 20 and 21, the Last Terrace with 17 on the left.
## Nothing could have noticed: the manifest checks a size, the art gate checks a
## file exists, and a gap in a hazed layer at the back of the scope is the kind
## of thing an eye reads as "the sky" rather than as a fault.
##
## `tools/trim_skylines.py` is the fix and this is what keeps it applied.
func _test_every_strip_reaches_its_edges() -> void:
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var region: TerrainData = ContentDB.terrain_for_act(act)
		if region == null:
			continue
		var path: String = Balance.BEAST_SKYLINE_FORMAT % region.id
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		var art: Image = texture.get_image()
		if art == null:
			continue
		var tall: int = art.get_height()
		var wide: int = art.get_width()
		for side: int in 2:
			var column: int = 0 if side == 0 else wide - 1
			var drawn: int = 0
			for y: int in tall:
				if art.get_pixel(column, y).a > EDGE_ALPHA:
					drawn += 1
			_check(drawn > 0,
				"%s: column %d of %d is empty, so the mirrored join opens a gap "
					% [region.id, column, wide]
					+ "of sky - run tools/trim_skylines.py")


## Above this an alpha is drawing rather than a generator's stray haze. The same
## threshold `tools/trim_skylines.py` crops to, as a fraction.
const EDGE_ALPHA: float = 8.0 / 255.0


## Depth reads from one cue out here, and it has to be consistent.
##
## A layer further from the camera must slide *slower* than one in front of it,
## always: that difference is the only thing telling a player that the ridge is
## miles off and the brush is at their feet. Draw order is the other statement of
## the same fact, so the two must agree - and for a long time they did not. The
## painted sky ran at 2.4 while the far range ran at 0.18, the middle distance
## outran the ground the beast stands on, and the near band went four times
## faster than the brush drawn over it.
##
## **The rates are measured off the real nodes rather than read out of
## `Balance`.** What matters is the number each layer is actually scrolled with,
## and the scope is the only thing that knows which constant it hands to which
## layer - it got two of those pairings wrong at once. A gate reading the
## constants in the order it expected them would have agreed with itself.
func _test_the_ladder_is_in_order(scope: BeastScope) -> void:
	# One unit of road. Every rate in the scope is far below the narrowest
	# period, so nothing has wrapped yet and `position.x` is exactly `-rate`.
	RunState.distance_travelled = 1.0
	await get_tree().process_frame
	var rungs: Array = []
	if scope.backdrop != null:
		rungs.append(["sky", scope.backdrop.z_index, -scope.backdrop.position.x])
	var layers: Array[Node] = []
	_gather(scope, layers)
	for layer: Node in layers:
		rungs.append([String(layer.name), (layer as Node2D).z_index,
			-(layer as Node2D).position.x])
	var ground := scope.get_node_or_null("Ground0") as Node2D
	if ground != null:
		rungs.append(["ground", ground.z_index, -ground.position.x])
	_check(rungs.size() >= 7,
		"only %d layers reported a scroll rate; the scope has more than that"
			% rungs.size())
	rungs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	var behind: Array = []
	for rung: Array in rungs:
		_check(float(rung[2]) > 0.0,
			"%s does not move at all; a layer that never slides is not parallax"
				% rung[0])
		if not behind.is_empty():
			_check(float(rung[2]) >= float(behind[2]) - 0.0005,
				"%s is drawn in front of %s (z %d against %d) and slides slower "
					% [rung[0], behind[0], int(rung[1]), int(behind[1])]
					+ "(%.2f against %.2f): depth is saying two opposite things"
					% [float(rung[2]), float(behind[2])])
		behind = rung
