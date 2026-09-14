extends Node

## Every parallax layer in the beast scope covers the whole screen, at every
## point on its own scroll.
##
##   godot --headless --path game res://tools/parallax_cover_check.tscn
##
## **The fault this exists for was in three classes at once and had shipped in
## all of them.** `ParallaxBand`, `ParallaxScatter` and `ParallaxStrip` each laid
## their content down starting at their *own origin* and running forward two
## periods, and `scroll_to` slides the node backward over one period. The scope's
## camera sits on that origin, so the view is [-960, 960] in the layer's own
## space and content beginning at 0 begins in the middle of it: whenever a layer
## had travelled less than half a period, the left of the screen had no layer on
## it. A far ridge ending at a hard vertical edge with sky beside it, on roughly
## every other stretch of road.
##
## Every one of those three files said, in as many words, that two periods were
## enough for the view to always be covered. They were written from the same
## reasoning and inherited the same hole, which is why this measures the real
## nodes rather than reading the constant back: `ParallaxBand.PERIODS` is the one
## list all three now use, and the assertion is about where the geometry lands.
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
## scope. The slowest layer here moves 0.18 units a unit travelled and the
## fastest 1.35, so this walks each of them past several of their own periods.
const DISTANCES: Array[float] = [0.0, 37.0, 113.0, 260.0, 401.0, 640.0, 913.0,
	1290.0, 1777.0, 2404.0, 3111.0, 4098.0, 5303.0, 6890.0, 8642.0, 11303.0]

var _failures: PackedStringArray = []
var _checks: int = 0
var _half: float = 960.0


func _ready() -> void:
	MetaState.hold_saves()
	_half = float(ProjectSettings.get_setting("display/window/size/viewport_width",
		1920)) * 0.5
	await _drive_the_scope()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[parallax] PASS - %d checks across %d distances, %s"
			% [_checks, DISTANCES.size(), "every layer covers the view"])
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


## Stands up the real scope, walks it down the road and measures what it drew.
func _drive_the_scope() -> void:
	RunState.reset()
	GameDirector.run_active = true
	# Act III, because its skyline strip and its ground are the ones the fault
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

	_test_the_baselines_are_stacked()
	await _test_the_ladder_is_in_order(scope)
	var layers: Array[Node] = []
	_gather(scope, layers)
	_check(layers.size() >= 5,
		"the scope stood up %d parallax layers; it builds at least five"
			% layers.size())
	for distance: float in DISTANCES:
		RunState.distance_travelled = distance
		await get_tree().process_frame
		for layer: Node in layers:
			_measure(layer, distance)
	scope.queue_free()
	await get_tree().process_frame


func _gather(from: Node, into: Array[Node]) -> void:
	for child: Node in from.get_children():
		if child is ParallaxBand or child is ParallaxScatter or child is ParallaxStrip:
			into.append(child)
		_gather(child, into)


## One layer, at one distance.
##
## A silhouette and a strip are continuous and must *cover* the view; a scatter
## is discrete props and cannot, so what is asked of it is that it has props on
## both sides of the screen. A scatter with nothing to the left of the camera is
## the same fault wearing different clothes.
func _measure(layer: Node, distance: float) -> void:
	var name: String = layer.name
	if layer is ParallaxBand:
		var band := layer as ParallaxBand
		if band.band_width <= 0.0:
			return
		_check(band.band_width >= _half,
			"%s: a period is %.0f units and the view's half-width is %.0f, so no "
				% [name, band.band_width, _half]
				+ "number of periods laid from one behind the origin covers it")
		var lowest: int = ParallaxBand.PERIODS.min()
		var highest: int = ParallaxBand.PERIODS.max()
		var left: float = band.position.x + float(lowest) * band.band_width
		var right: float = band.position.x + float(highest + 1) * band.band_width
		_check(left <= -_half and right >= _half,
			"%s at %.0f: drawn across [%.0f, %.0f], view is [%.0f, %.0f]"
				% [name, distance, left, right, -_half, _half])
		return
	var sprites: Array[Node] = []
	for child: Node in layer.get_children():
		if child is Sprite2D:
			sprites.append(child)
	if sprites.is_empty():
		# A region with no art for this layer draws nothing, which is a supported
		# state rather than a gap - the strip says so itself.
		return
	var left_edge: float = INF
	var right_edge: float = -INF
	for node: Node in sprites:
		var sprite := node as Sprite2D
		var wide: float = 0.0
		if sprite.texture != null:
			wide = float(sprite.texture.get_width()) * absf(sprite.scale.x)
		var at: float = layer.position.x + sprite.position.x
		# `centered` and `flip_h` both move where the art lands relative to the
		# node, and this layer uses each of them.
		var from: float = at - wide * 0.5 if sprite.centered \
			else (at - wide if sprite.flip_h else at)
		left_edge = minf(left_edge, from)
		right_edge = maxf(right_edge, from + wide)
	_check(left_edge <= -_half and right_edge >= _half,
		"%s at %.0f: art reaches [%.0f, %.0f], view is [%.0f, %.0f]"
			% [name, distance, left_edge, right_edge, -_half, _half])


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


## Depth reads from one cue out here, and it has to be consistent.
##
## A layer further from the camera must slide *slower* than one in front of it,
## always: that difference is the only thing telling a player that the ridge is
## miles off and the brush is at their feet. Draw order is the other statement of
## the same fact, so the two must agree - and for years they did not. The painted
## sky ran at 2.4 while the far range ran at 0.18, the middle distance outran the
## ground the beast stands on, and the near band went four times faster than the
## brush drawn over it.
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
