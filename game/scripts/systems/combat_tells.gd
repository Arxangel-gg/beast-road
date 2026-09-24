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
## Whether a point is near enough a Warden for an enemy's ring to matter.
var near_a_warden: Callable = Callable()

## One entry per shooter that has fired recently: where, how far, what colour,
## and how long is left on it.
var _rings: Dictionary = {}
var _clock: float = 0.0


func _ready() -> void:
	z_index = Balance.COMBAT_TELL_Z
	EventBus.ranged_shot_fired.connect(_on_shot)
	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.enemy_attacked.connect(_on_enemy_attacked)
	set_process(true)


## A shooter fired. Opens or refreshes its ring.
##
## Keyed by the shooter rather than appended, so a tower firing eight times a
## second holds one ring at full rather than stacking eight.
func show_range(key: int, at: Vector2, reach: float, tint: Color,
		follow: Node2D = null, aim: Vector2 = Vector2.ZERO) -> void:
	if reach <= 1.0:
		return
	# **A pulse on every refresh** (owner, 2026-09-22): a ring already standing
	# brightens and swells for a beat when the shooter fires again, so a
	# held ring still says each shot.
	_rings[key] = {
		"at": at,
		"reach": reach,
		"tint": tint,
		"left": Balance.RANGE_RING_HOLD,
		"pulse": 1.0,
		"follow": follow,
		# **The arc faces what was shot at** (owner, 2026-09-24). Zero means
		# nobody said, and the whole ring is drawn.
		"aim": aim,
	}


func _on_shot(from: Vector2, reach: float, aim: Vector2) -> void:
	show_range(0, from, reach, Balance.RANGE_RING_HERO, null, aim)


## **Around the tower, never around what it hit.** Owner, 2026-09-22: the range
## was *"appearing on the hit enemy instead of showing around the attacking
## tower like in league of legends"*. `tower_fired` carries where the shot went,
## which is what the sound and the muzzle want, and this ring was drawn there - a
## tower's reach centred on its target describes nothing at all. The centre is
## asked of the field by anchor, the one thing the signal names that is the
## tower, and a tower the field cannot find draws no ring rather than a wrong one.
func _on_tower_fired(anchor: Vector2i, at: Vector2) -> void:
	if not Graphics.tower_rings_shown():
		return
	var data: TowerData = RunState.tower_at(anchor)
	if data == null or not tower_at.is_valid():
		return
	var found: Variant = tower_at.call(anchor)
	if not (found is Dictionary):
		return
	# **The tower's own reach, as it fires** - its path, a relay beside it and
	# the ground it stands on all move it - asked of the tower rather than read
	# off its data at its level, which drew a smaller circle than the one it
	# shot from (owner, 2026-09-22: "not properly showing the towers' actual
	# reaches").
	var centre: Vector2 = (found as Dictionary)["at"] as Vector2
	# Where the shot went is the one thing the signal carries that says which
	# way the tower is looking; the ring's centre stays the tower's.
	show_range(anchor.x * 4096 + anchor.y + 1, centre,
		float((found as Dictionary)["reach"]), Balance.RANGE_RING_TOWER, null,
		(at - centre).normalized() if at.distance_to(centre) > 1.0 else Vector2.ZERO)


## **An enemy shows its reach for a while after it attacks**, as a tower does
## (owner, 2026-09-22). Only near a Warden, and only so many at once: a ring
## round every body on a road of two hundred is a diagram rather than a tell.
func _on_enemy_attacked(key: int, at: Vector2, reach: float) -> void:
	if not Graphics.enemy_rings_shown():
		return
	if not near_a_warden.is_valid() or not bool(near_a_warden.call(at)):
		return
	var enemies: int = 0
	for held: Variant in _rings:
		if int(held) < 0:
			enemies += 1
	if enemies >= Balance.RANGE_RING_ENEMY_MAX and not _rings.has(-key):
		return
	var body := instance_from_id(key) as Node2D
	show_range(-key, at, reach, Balance.RANGE_RING_ENEMY, body, _enemy_aim(body))


## Which way a body's reach faces: toward what it is fighting, read off the
## body rather than guessed. Zero when it has no target to face.
func _enemy_aim(body: Node2D) -> Vector2:
	if body == null or not is_instance_valid(body):
		return Vector2.ZERO
	var target: Variant = body.get("_target")
	# Validity first: `is` and `as` on a freed instance both throw before any
	# guard after them can run, and a followed body's target dies every wave.
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	var aimed := target as Node2D
	if aimed == null:
		return Vector2.ZERO
	var line: Vector2 = aimed.global_position - body.global_position
	return line.normalized() if line.length() > 1.0 else Vector2.ZERO


func _process_measured(delta: float) -> void:
	_clock += delta
	var live: Dictionary = {}
	for key: Variant in _rings:
		var ring: Dictionary = _rings[key]
		var left: float = float(ring["left"]) - delta
		if left <= 0.0:
			continue
		ring["left"] = left
		ring["pulse"] = maxf(float(ring.get("pulse", 0.0)) - delta / Balance.RANGE_RING_PULSE_SECONDS, 0.0)
		# **Carried by an enemy while it moves** (owner, 2026-09-22), and let go
		# of the moment the body is gone rather than read after it is freed.
		var held: Variant = ring.get("follow")
		if held != null:
			if is_instance_valid(held):
				var body := held as Node2D
				ring["at"] = body.call("combat_origin") if body.has_method("combat_origin") \
					else body.global_position
				# And turned toward what it is fighting now; a body that has lost
				# its target keeps facing the way it last did.
				var facing: Vector2 = _enemy_aim(body)
				if facing != Vector2.ZERO:
					ring["aim"] = facing
			else:
				ring["follow"] = null
		live[key] = ring
	_rings = live
	queue_redraw()


func _draw_measured() -> void:
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
		var pulse: float = float(ring.get("pulse", 0.0))
		tint.a *= alpha * weight * (1.0 + Balance.RANGE_RING_PULSE_GAIN * pulse)
		if tint.a <= 0.004:
			continue
		# **A true circle's radius**, because a reach is one: towers and bodies
		# measure range as a radius in every direction, and a flattened ring
		# promised 58% of it up and down the screen (owner, 2026-09-22). **And
		# only the part that faces what was shot at** (owner, 2026-09-24): an
		# arc `RANGE_RING_ARC_SPAN` wide on the aim, feathered at both ends,
		# over a wider and fainter halo so it reads as light on the ground
		# rather than as a drawn line.
		var aim: Vector2 = ring.get("aim", Vector2.ZERO) as Vector2
		var halo: Color = tint
		halo.a *= Balance.RANGE_RING_HALO_ALPHA
		_arc(ring["at"] as Vector2, float(ring["reach"]), halo,
			Balance.RANGE_RING_WIDTH * Balance.RANGE_RING_HALO_WIDTH * (1.0 + pulse * 0.5), 1.0, aim)
		_arc(ring["at"] as Vector2, float(ring["reach"]), tint,
			Balance.RANGE_RING_WIDTH * (1.0 + pulse), 1.0, aim)


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
##
## With an `aim`, only the arc of `RANGE_RING_ARC_SPAN` degrees that faces it is
## drawn, and the alpha of its two ends falls away over `RANGE_RING_ARC_FEATHER`
## degrees - a sector edge that ends in a hard cut reads as a slice of pie, and
## one that fades reads as light.
func _arc(at: Vector2, radius: float, tint: Color, width: float,
		squash: float = Balance.RANGE_RING_SQUASH, aim: Vector2 = Vector2.ZERO) -> void:
	if radius <= 1.0 or tint.a <= 0.004:
		return
	var whole: bool = aim == Vector2.ZERO
	var span: float = TAU if whole else deg_to_rad(Balance.RANGE_RING_ARC_SPAN)
	var start: float = 0.0 if whole else aim.angle() - span * 0.5
	var feather: float = 0.0 if whole else clampf(
		deg_to_rad(Balance.RANGE_RING_ARC_FEATHER) / span, 0.0, 0.5)
	var steps: int = maxi(int(round(float(Balance.RANGE_RING_SEGMENTS) * span / TAU)), 8)
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var indices: PackedInt32Array = []
	var clear := Color(tint.r, tint.g, tint.b, 0.0)
	for step: int in steps + 1:
		var along: float = float(step) / float(steps)
		var angle: float = start + span * along
		var out := Vector2(cos(angle), sin(angle) * squash)
		var lit: Color = tint
		if not whole:
			lit.a *= smoothstep(0.0, feather, along) * smoothstep(0.0, feather, 1.0 - along)
		points.append(at + out * (radius - width))
		colours.append(clear)
		points.append(at + out * radius)
		colours.append(lit)
		points.append(at + out * (radius + width))
		colours.append(clear)
	for step: int in steps:
		var a: int = step * 3
		var b: int = (step + 1) * 3
		indices.append_array([a, a + 1, b, b, a + 1, b + 1])
		indices.append_array([a + 1, a + 2, b + 1, b + 1, a + 2, b + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours)


## `FrameProfile` bucket "tells": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"tells", started)


## `FrameProfile` bucket "d_combat_tells": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_combat_tells", started)
