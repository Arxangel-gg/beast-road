class_name BuildGhost
extends Node2D

## **What a hovered offer would be, standing where it would stand** (owner,
## 2026-09-25: "an on-hover visual see-through semi-transparent placed in place
## of the selected tile with its attack range full circle indicator at the tile
## selected while hovering on a tower or trap").
##
## A build sheet lists names and prices, and the one question a row cannot
## answer is the one that decides where a tower goes: *what would it cover from
## here?* So while a row is hovered its own painting stands on the chosen ground,
## see-through and breathing, inside a full circle of the reach it would have.
##
## **The reach is asked, never worked out here.** `Battlefield.preview_tower`
## hands in `Tower.reach_for` and `preview_trap` hands in `Trap.radius_for` - the
## same two functions a built tower's `effective_range` and a laid trap's
## `radius_now` read. A ghost with its own arithmetic would be a second opinion
## about a number the player is deciding on, and the first time either was
## tuned the promise and the tower would disagree. `road_sheet_check` builds the
## tower after hovering it and holds the two against each other.
##
## **A picture and nothing else**: nothing reads it, it rolls no dice, it sends
## nothing over the wire - each machine draws its own player's hover - and it
## changes no number. It processes only while it is showing something.

## The offer's own painting, or null for a reach alone (an upgrade, whose tower
## is already standing there).
var texture: Texture2D = null
## Where the painting's middle stands, in world space.
var sprite_at: Vector2 = Vector2.ZERO
## Where the reach is measured from, in world space, and how far it goes.
var reach_at: Vector2 = Vector2.ZERO
var reach: float = 0.0
## The offer's element or trap colour.
var tint: Color = Color.WHITE
## The ground it would stand on - a tower's plot, a trap's tile - centred on
## `reach_at`, so the chosen ground is marked by the ghost itself rather than by
## wherever the cursor happens to be (it is over the sheet while a row is hovered).
var plot: Vector2 = Vector2.ZERO
## **Its idle, not a still** (owner, 2026-09-25: "the onhover placement indicator
## of the tower/trap should also be animated in its idle state"). The offer's own
## idle loop at the rate the field plays it - a tower's at
## `STRUCTURE_IDLE_FRAME_RATE`, a trap's at `TRAP_FRAME_RATE` - and a structure
## with no loop breathes and sways exactly as a standing one does, so the ghost
## moves the way the thing it promises will move once it is built.
var frames: Array[Texture2D] = []
var frame_rate: float = 0.0
var breathes: bool = false

var _clock: float = 0.0


func _ready() -> void:
	z_index = Balance.BUILD_GHOST_Z
	visible = false
	set_process(false)


func show_offer(art: Texture2D, picture_at: Vector2, reach_from: Vector2, radius: float,
		colour: Color, ground: Vector2 = Vector2.ZERO, loop: Array[Texture2D] = [],
		loop_rate: float = 0.0, still_breathes: bool = false) -> void:
	plot = ground
	frames = loop
	frame_rate = loop_rate
	breathes = still_breathes
	# The same offer hovered again does not restart its breath.
	var same: bool = visible and art == texture and picture_at.is_equal_approx(sprite_at) \
		and is_equal_approx(radius, reach)
	texture = art
	sprite_at = picture_at
	reach_at = reach_from
	reach = maxf(radius, 0.0)
	tint = colour
	if not same:
		_clock = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func clear() -> void:
	if not visible and texture == null and reach <= 0.0:
		return
	visible = false
	set_process(false)
	texture = null
	frames = []
	reach = 0.0
	queue_redraw()


## Whether it is showing an offer at all.
func showing() -> bool:
	return visible and (texture != null or reach > 0.0)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	if reach > 0.0:
		_draw_reach(to_local(reach_at))
	if plot.x > 0.0 and plot.y > 0.0:
		var ground := Rect2(to_local(reach_at) - plot * 0.5, plot)
		draw_rect(ground, Color(tint.r, tint.g, tint.b, Balance.BUILD_GHOST_PLOT_FILL))
		draw_rect(ground, Color(tint.r, tint.g, tint.b, Balance.BUILD_GHOST_PLOT_LINE), false,
			2.0)
	if texture != null:
		var breathe: float = 0.5 + 0.5 * sin(_clock * TAU / Balance.BUILD_GHOST_BREATHE_SECONDS)
		var alpha: float = lerpf(Balance.BUILD_GHOST_ALPHA_MIN, Balance.BUILD_GHOST_ALPHA_MAX,
			breathe)
		# Washed a little toward its colour, so it reads as a promise rather than
		# as a tower that is already there.
		var wash: Color = Color.WHITE.lerp(tint, Balance.BUILD_GHOST_WASH)
		var picture: Texture2D = pose()
		var size: Vector2 = picture.get_size()
		var turn: float = 0.0
		var grow: float = 1.0
		if frames.is_empty() and breathes:
			# `Tower._tick_step_wobble`'s own idle for a structure with no loop.
			var phase: float = _clock * Balance.STRUCTURE_IDLE_RATE * TAU
			grow = 1.0 + sin(phase) * Balance.STRUCTURE_IDLE_SCALE
			turn = deg_to_rad(sin(phase * 0.63) * Balance.STRUCTURE_IDLE_SWAY)
		draw_set_transform(to_local(sprite_at), turn, Vector2.ONE * grow)
		draw_texture(picture, -size * 0.5, Color(wash.r, wash.g, wash.b, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The pose it is drawing now: the idle loop's current frame, or the painting
## when there is no loop. `_draw` reads this and so does `road_sheet_check`,
## so the gate watches the picture rather than the list it was handed.
func pose() -> Texture2D:
	if not frames.is_empty() and frame_rate > 0.0:
		var frame: Texture2D = frames[int(floor(_clock * frame_rate)) % frames.size()]
		if frame != null:
			return frame
	return texture


## A true circle - the reach is the same distance in every direction on the
## ground, and a flattened ring promised 58% of it up and down the screen once
## (CLAUDE.md, 2026-09-22). Faint in the middle and brighter toward the edge, so
## the ground inside still reads; a solid rim the eye can follow; and a wave
## leaving the centre, so the circle says it is live rather than a mark on the map.
func _draw_reach(centre: Vector2) -> void:
	var steps: int = Balance.BUILD_GHOST_SEGMENTS
	var inner := Color(tint.r, tint.g, tint.b, Balance.BUILD_GHOST_FILL_CENTRE)
	var outer := Color(tint.r, tint.g, tint.b, Balance.BUILD_GHOST_FILL_RIM)
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([inner])
	var indices := PackedInt32Array()
	for step: int in steps:
		points.append(centre + Vector2.RIGHT.rotated(TAU * float(step) / float(steps)) * reach)
		colours.append(outer)
	for step: int in steps:
		indices.append_array([0, 1 + step, 1 + (step + 1) % steps])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)
	draw_arc(centre, reach, 0.0, TAU, steps,
		Color(tint.r, tint.g, tint.b, Balance.BUILD_GHOST_RIM_ALPHA),
		Balance.BUILD_GHOST_RIM_WIDTH, true)
	var wave: float = fmod(_clock, Balance.BUILD_GHOST_WAVE_SECONDS) \
		/ Balance.BUILD_GHOST_WAVE_SECONDS
	if wave > 0.02:
		draw_arc(centre, reach * wave, 0.0, TAU, steps,
			Color(tint.r, tint.g, tint.b, Balance.BUILD_GHOST_RIM_ALPHA * 0.45 * (1.0 - wave)),
			Balance.BUILD_GHOST_RIM_WIDTH * 0.75, true)
