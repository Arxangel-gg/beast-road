class_name Craters
extends Node2D

## The holes the sky punches in the road, and they stay punched.
##
## Owner brief, 2026-09-16: a meteor should "leave perfectly implemented polished
## craters in their place for the remainder of the act that run".
##
## `ScorchMarks` already remembers *burning* - one low-resolution image over the
## whole field, a texel every `SCORCH_TEXEL` units, stamped with feathered discs
## and cleared when the region changes. That is the right shape for a burn and the
## wrong one for a hole: a crater has a lit rim, a shadowed inner wall, a floor
## and ejecta thrown out of it, and none of that survives being a blurred disc in
## a coarse greyscale image.
##
## So a crater is drawn geometry with its own place in the list, and the list is
## cleared exactly where the scorch marks are - `refresh_terrain`, the one
## function everything regional goes through, which is also when the foliage
## regrows. A crater therefore lasts the act and no longer, which is what was
## asked for.
##
## **It is read by nothing.** Nothing about pathing, placement, building,
## targeting or damage asks whether a tile is cratered; a crater is a picture of
## something that already happened, exactly as the scorch marks and the fog's
## drawing are. Turn this node off and the run is identical.
##
## **And it redraws only when it has to.** A pit is static once it has cooled, so
## the canvas item is rebuilt when one opens and then left alone - a field of
## craters costs one draw and no per-frame work. While any pit is still glowing
## the node redraws, and stops of its own accord when the last one goes out.

## The pits, oldest first: `{at, radius, seed, opened}`.
var pits: Array[Dictionary] = []
var _clock: float = 0.0
## When the youngest pit stops glowing. Nothing redraws after this.
var _hot_until: float = -1.0


func _ready() -> void:
	name = "Craters"
	y_sort_enabled = false
	z_as_relative = false
	z_index = Balance.CRATER_Z
	set_process(false)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()
	if _clock > _hot_until:
		set_process(false)


## A new hole in the ground. Drawn on every machine - the guest mirrors the
## meteor that made it and calls this from the same place - so nothing about a
## crater crosses the wire.
func open(at: Vector2, radius: float) -> void:
	if radius <= 1.0:
		return
	# The oldest goes when the field is full. A cap rather than a fade: a crater
	# that healed over would be the one thing on this field that un-happened.
	while pits.size() >= Balance.CRATER_MAX:
		pits.pop_front()
	pits.append({"at": at, "radius": radius, "seed": hash(at) & 0x7fffffff,
		"opened": _clock})
	_hot_until = _clock + Balance.CRATER_GLOW_SECONDS
	set_process(true)
	queue_redraw()


## The region changed. Called beside `ScorchMarks.clear` in `refresh_terrain`,
## because they answer the same question about the same ground.
func clear() -> void:
	if pits.is_empty():
		return
	pits.clear()
	_hot_until = -1.0
	set_process(false)
	queue_redraw()


func count() -> int:
	return pits.size()


# --- The drawing ---------------------------------------------------------------

## Where the light comes from over the field: the top-left, the same corner the
## shadows and the flood's glints use. A pit lit from there has a bright *outer*
## rim on the near side and a bright *inner* wall on the far side, because the far
## wall is the one turned back toward the light. Getting that the wrong way round
## is what makes a drawn crater read as a bump.
const LIGHT := Vector2(-0.55, -0.8)


func _draw() -> void:
	for pit: Dictionary in pits:
		_draw_pit(pit)


func _draw_pit(pit: Dictionary) -> void:
	var at: Vector2 = pit["at"]
	var radius: float = pit["radius"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pit["seed"])
	# How lately it was made: a fresh pit still has heat in it and cools over
	# `CRATER_GLOW_SECONDS`. After that it is stone and never changes again.
	var heat: float = clampf(1.0 - (_clock - float(pit["opened"]))
		/ maxf(Balance.CRATER_GLOW_SECONDS, 0.01), 0.0, 1.0)
	_draw_ejecta(at, radius, rng)
	_draw_bowl(at, radius, heat)
	_draw_rim(at, radius)
	_draw_debris(at, radius, rng)


## The dirt thrown out of it: tapered rays from the rim outward, fading to
## nothing, more on one side than the other so it is not a starburst.
func _draw_ejecta(at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var lean: float = rng.randf() * TAU
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for ray: int in Balance.CRATER_RAYS:
		var angle: float = rng.randf_range(0.0, TAU)
		# Weighted toward one quarter: a stone comes in at an angle and throws
		# most of what it lifts away from where it came from.
		angle = lerp_angle(angle, lean, 0.45)
		var out: Vector2 = Vector2(cos(angle), sin(angle) * Balance.CRATER_SQUASH)
		var reach: float = radius * rng.randf_range(Balance.CRATER_RAY_REACH.x,
			Balance.CRATER_RAY_REACH.y)
		var wide: float = radius * rng.randf_range(0.07, 0.16)
		var side: Vector2 = Vector2(-out.y, out.x).normalized()
		var first: int = points.size()
		var dirt: Color = Balance.CRATER_EJECTA
		points.append(at + out * radius * 0.82 + side * wide)
		points.append(at + out * radius * 0.82 - side * wide)
		points.append(at + out * reach)
		colours.append(Color(dirt.r, dirt.g, dirt.b, dirt.a))
		colours.append(Color(dirt.r, dirt.g, dirt.b, dirt.a))
		colours.append(Color(dirt.r, dirt.g, dirt.b, 0.0))
		indices.append_array([first, first + 1, first + 2])
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## The hole: a floor, and an inner wall that is shadowed on the light's own side
## and lit on the far one. A fresh pit glows through its floor for a while.
func _draw_bowl(at: Vector2, radius: float, heat: float) -> void:
	var steps: int = 26
	var light: Vector2 = LIGHT.normalized()
	var floor_tone: Color = Balance.CRATER_FLOOR
	if heat > 0.0:
		floor_tone = floor_tone.lerp(Balance.CRATER_EMBER, heat * heat)
	var points := PackedVector2Array([at])
	var colours := PackedColorArray([floor_tone])
	for band: int in 2:
		for s: int in steps:
			var angle: float = TAU * float(s) / float(steps)
			var out := Vector2(cos(angle), sin(angle) * Balance.CRATER_SQUASH)
			var span: float = radius * (0.52 if band == 0 else 0.92)
			points.append(at + out * span)
			if band == 0:
				colours.append(floor_tone)
				continue
			# The wall turned back toward the light is lit; the near one is in
			# its own shadow. `out` points out of the pit, so a wall *facing*
			# the light has `out` pointing away from it.
			var facing: float = clampf(-out.normalized().dot(light), -1.0, 1.0)
			colours.append(Balance.CRATER_WALL_DARK.lerp(Balance.CRATER_WALL_LIT,
				0.5 + 0.5 * facing))
	var indices := PackedInt32Array()
	for s: int in steps:
		var inner: int = 1 + s
		var next_inner: int = 1 + (s + 1) % steps
		indices.append_array([0, inner, next_inner])
		var outer: int = 1 + steps + s
		var next_outer: int = 1 + steps + (s + 1) % steps
		indices.append_array([inner, outer, next_inner, outer, next_outer, next_inner])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## The raised lip around it: bright where the light lands on it, dark on the far
## side where it shades the ground beyond, and clear at its outer edge so it
## blends into the road rather than ending in a ring.
func _draw_rim(at: Vector2, radius: float) -> void:
	var steps: int = 26
	var light: Vector2 = LIGHT.normalized()
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for band: int in 2:
		for s: int in steps:
			var angle: float = TAU * float(s) / float(steps)
			var out := Vector2(cos(angle), sin(angle) * Balance.CRATER_SQUASH)
			points.append(at + out * radius * (0.92 if band == 0 else 1.0 + Balance.CRATER_RIM))
			if band == 1:
				colours.append(Color(0.0, 0.0, 0.0, 0.0))
				continue
			var facing: float = clampf(out.normalized().dot(light), -1.0, 1.0)
			colours.append(Balance.CRATER_RIM_DARK.lerp(Balance.CRATER_RIM_LIT,
				0.5 + 0.5 * facing))
	var indices := PackedInt32Array()
	for s: int in steps:
		var inner: int = s
		var next_inner: int = (s + 1) % steps
		var outer: int = steps + s
		var next_outer: int = steps + (s + 1) % steps
		indices.append_array([inner, outer, next_inner, outer, next_outer, next_inner])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## Lumps of what came out, lying where they fell. Small, dark, and never inside
## the hole: the pit is the one place the debris is not.
func _draw_debris(at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	for _rock: int in Balance.CRATER_DEBRIS:
		var angle: float = rng.randf_range(0.0, TAU)
		var away: float = radius * rng.randf_range(1.0, Balance.CRATER_RAY_REACH.y * 0.9)
		var here: Vector2 = at + Vector2(cos(angle), sin(angle) * Balance.CRATER_SQUASH) * away
		var size: float = radius * rng.randf_range(0.025, 0.06)
		# A shadow under it, then the stone: two ellipses, which at this size is
		# the whole difference between a rock and a speck of dirt.
		draw_circle(here + Vector2(size * 0.4, size * 0.5), size, Color(0.0, 0.0, 0.0, 0.3))
		draw_circle(here, size, Balance.CRATER_DEBRIS_TONE)
