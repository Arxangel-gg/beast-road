class_name CombatTells
extends Node2D

## **What the next swing would hit, and how far a shot reaches.**
##
## Owner, 2026-09-18, two requests that are one drawing:
##
## - *"Enemies and wildlife that a player is within range of hitting with their
##   next melee attack should become highlighted with an extra highlight outline
##   layer."*
## - *"After a player shoots a ranged shot there should be a range indicator ...
##   After not using another ranged attack for an appropriate duration the range
##   indicator will fade out. All towers that attack enemies should also have
##   this system ... The ranges for any enemies who have ranged attacks should
##   also not be constantly visible but becoming visible temporarily in the same
##   way."*
##
## **The enemy half of that second request is not built here**, and is named
## rather than quietly dropped: this game draws no standing range circle for a
## ranged breed - `Enemy.attack_reach` is a number the shot obeys, not a ring
## on the ground - so there was nothing to make temporary. If one is ever
## drawn, it opens through `show_range` like the other two.
##
## ## One node, one `_draw`, no nodes per body
##
## A wave is two hundred bodies and a road is forty towers. An outline node per
## highlighted body and a ring node per shooter is hundreds of allocations a
## second for something nobody can touch - which is the argument `GroundMarks`,
## `BloodInk` and the Hold's grass were all built under. Everything here is
## triangle arrays and arcs on a single canvas item.
##
## ## The highlight is the strike's own answer
##
## It does not compute who is in reach; it **asks `HeroAttack.would_hit`**, which
## is the function `_strike` itself uses. A tell that worked out its own answer
## would eventually mark a body the blow misses, and a tell that lies about the
## blow is worse than no tell at all. Reach, arc, what counts as a body and which
## step of the chain is next are all read from the one place that decides them.
##
## ## A ring is opened by a shot and closes on its own
##
## Nothing here polls for "is this thing a shooter". A ring appears because
## something *fired* - the hero loosing, a tower firing, a body throwing - and
## fades once that shooter has been quiet for `Balance.RANGE_RING_HOLD`. So a
## range is visible exactly while it is relevant and the screen is not a diagram
## the rest of the time, which is the owner's own distinction.
##
## ## What it is not
##
## Nothing reads any of it. No number moves, nothing is targeted differently, and
## `Graphics.particle_scale()` scales it away to nothing - the bound the fog, the
## phenotypes, the footfalls and the set aura are all held to.

## Where the Warden is and what they are pointing at. Handed in by the scope so
## this file holds no reference to a hero it does not own.
var hero: Callable = Callable()
## Where a tower stands, by its anchor, or null when there is none. Handed in by
## the field for the same reason `hero` is.
var tower_at: Callable = Callable()

## One entry per shooter that has fired recently: where, how far, what colour,
## and how long is left on it.
var _rings: Dictionary = {}
var _clock: float = 0.0


func _ready() -> void:
	z_index = Balance.COMBAT_TELL_Z
	EventBus.ranged_shot_fired.connect(_on_shot)
	EventBus.tower_fired.connect(_on_tower_fired)
	set_process(true)


## A shooter fired. Opens or refreshes its ring.
##
## Keyed by the shooter rather than appended, so a tower firing eight times a
## second holds one ring at full rather than stacking eight.
func show_range(key: int, at: Vector2, reach: float, tint: Color) -> void:
	if reach <= 1.0:
		return
	_rings[key] = {
		"at": at,
		"reach": reach,
		"tint": tint,
		"left": Balance.RANGE_RING_HOLD,
	}


func _on_shot(from: Vector2, reach: float) -> void:
	show_range(0, from, reach, Balance.RANGE_RING_HERO)


## **Around the tower, never around what it hit.** Owner, 2026-09-22: the range
## was *"appearing on the hit enemy instead of showing around the attacking
## tower like in league of legends"*. `tower_fired` carries where the shot went,
## which is what the sound and the muzzle want, and this ring was drawn there - a
## tower's reach centred on its target describes nothing at all. The centre is
## asked of the field by anchor, the one thing the signal names that is the
## tower, and a tower the field cannot find draws no ring rather than a wrong one.
func _on_tower_fired(anchor: Vector2i, _at: Vector2) -> void:
	var data: TowerData = RunState.tower_at(anchor)
	if data == null or not tower_at.is_valid():
		return
	var centre: Variant = tower_at.call(anchor)
	if not (centre is Vector2):
		return
	# The tower's *own* reach at its own level, read the way the shot reads it,
	# so the circle drawn and the circle fired from are one number.
	show_range(anchor.x * 4096 + anchor.y + 1, centre as Vector2,
		data.range_at(RunState.level_at(anchor)), Balance.RANGE_RING_TOWER)


func _process(delta: float) -> void:
	_clock += delta
	var live: Dictionary = {}
	for key: Variant in _rings:
		var ring: Dictionary = _rings[key]
		var left: float = float(ring["left"]) - delta
		if left <= 0.0:
			continue
		ring["left"] = left
		live[key] = ring
	_rings = live
	queue_redraw()


func _draw() -> void:
	var weight: float = Graphics.particle_scale()
	if weight <= 0.01:
		return
	_draw_rings(weight)
	_draw_reach(weight)


## The rings, each fading on its own clock over its last moments only - a ring
## that begins fading the instant it opens reads as a mistake rather than as a
## timer.
func _draw_rings(weight: float) -> void:
	for key: Variant in _rings:
		var ring: Dictionary = _rings[key]
		var left: float = float(ring["left"])
		var alpha: float = clampf(left / maxf(Balance.RANGE_RING_FADE, 0.01),
			0.0, 1.0)
		var tint: Color = ring["tint"] as Color
		tint.a *= alpha * weight
		if tint.a <= 0.004:
			continue
		# Flattened, because the camera looks down and slightly along: a true
		# circle on the ground reads as a hoop standing up. The same reason the
		# set aura is an ellipse.
		_arc(ring["at"] as Vector2, float(ring["reach"]), tint,
			Balance.RANGE_RING_WIDTH)


## The bodies the next swing would land on.
func _draw_reach(weight: float) -> void:
	if not hero.is_valid():
		return
	var found: Variant = hero.call()
	if not (found is Array):
		return
	var tint: Color = Balance.MELEE_TELL_COLOUR
	# A slow breath so it reads as live rather than as a sticker, and never all
	# the way off - a mark that vanishes between frames is a flicker.
	tint.a *= weight * (1.0 - Balance.MELEE_TELL_PULSE
		+ Balance.MELEE_TELL_PULSE * absf(sin(_clock * Balance.MELEE_TELL_RATE)))
	for entry: Variant in found as Array:
		var body := entry as Node2D
		if body == null or not is_instance_valid(body):
			continue
		var wide: float = Balance.ENEMY_BODY_RADIUS
		if body is Enemy:
			wide = (body as Enemy).contact_radius()
		_arc(body.global_position, wide * Balance.MELEE_TELL_SWELL, tint,
			Balance.MELEE_TELL_WIDTH)


## One flattened ring, drawn as a strip of quads with a feathered edge.
##
## `draw_arc` would be one colour across its whole width, and one colour for a
## whole shape is what a hard edge *is* - the finding this project has now paid
## for at the swim sheen, the menu campfire and the blood. Each segment is drawn
## as a band whose outer and inner vertices are transparent, so the line has a
## soft shoulder at any zoom.
func _arc(at: Vector2, radius: float, tint: Color, width: float) -> void:
	if radius <= 1.0 or tint.a <= 0.004:
		return
	var steps: int = Balance.RANGE_RING_SEGMENTS
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var indices: PackedInt32Array = []
	var clear := Color(tint.r, tint.g, tint.b, 0.0)
	for step: int in steps + 1:
		var angle: float = TAU * float(step) / float(steps)
		var out := Vector2(cos(angle), sin(angle) * Balance.RANGE_RING_SQUASH)
		points.append(at + out * (radius - width))
		colours.append(clear)
		points.append(at + out * radius)
		colours.append(tint)
		points.append(at + out * (radius + width))
		colours.append(clear)
	for step: int in steps:
		var a: int = step * 3
		var b: int = (step + 1) * 3
		indices.append_array([a, a + 1, b, b, a + 1, b + 1])
		indices.append_array([a + 1, a + 2, b + 1, b + 1, a + 2, b + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours)
