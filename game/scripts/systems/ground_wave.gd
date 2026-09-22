class_name GroundWave
extends Node2D

## The earth's wave: rings of broken ground rolling out from where it split.
##
## Owner, 2026-09-22: the ground-wave disaster was *"a low quality and
## unaesthetically appealing and low game juice starting solution"*. The
## complaint was exact, and the worst of it was not the picture:
##
## **An earthquake used to be one number, everywhere, on one frame.** Every
## hero, every enemy, every tower and every animal on the field took their
## share at the instant it broke, through a filter reading
## `func(_where): return true`. There was nowhere to be, nothing arriving and
## nothing to read - the only thing on screen was a camera shake and three
## dust puffs near whoever was watching, and a fault crack stamped somewhere
## random that had nothing to do with anything.
##
## **Now it comes from a place and it travels.** The ground splits at an
## epicentre, the split is shown while the earth hums, and then one to three
## crests roll outward across the whole field. A body is struck **once per
## ring, as the front reaches it**, so the blow arrives where the player can
## see it coming from.
##
## **The bound is that a wave may only ever be gentler than the old number
## was, never harder.** Every ring carries the total divided by the number of
## rings, and the rings reach past the far corner of the grid - so anything
## that does not move takes *exactly* what it took before, which is every
## tower and most of the road. What reading it buys a Warden is the rings
## they step out of, and nothing else: no ring hits twice, no ring hits
## harder than its share, and the sum is fixed before the first one is born.
## That is what lets `curve_report` still be read against the same numbers.
##
## The whole of it lives under the battlefield, so a raid freezes it exactly
## as it freezes everything else (working rule 8) and nothing had to learn
## that the earth has a clock.

## What each ring is while it runs.
##
## `reach` is where it stops. It is set past the far corner of the grid so a
## stationary body is caught by every ring - which is the arithmetic the
## bound above rests on.
class Ring:
	var born: float = 0.0
	var radius: float = 0.0
	var alive: bool = false
	var struck: Dictionary = {}
	var fissured: bool = false
	var wounded_the_animals: bool = false


var field: Battlefield = null
## Where the cracks go and where the charged ground opens. **Handed over
## rather than walked up to**: `Sky` already holds both, and a wave that
## reached up the tree for its parent would make `Sky` and `GroundWave`
## depend on each other, which GDScript resolves at compile time and does
## badly.
var marks: ScorchMarks = null
var zones: WrathZones = null
## A guest draws the wave and hurts nobody: the host has already decided who
## was hit and reports it as health. The same rule every one of the earth's
## events is relayed under.
var mirror: bool = false

var at: Vector2 = Vector2.ZERO
var magnitude: float = 1.0
var rings: int = 1
## What one ring takes off a hero, an enemy, a tower. Handed over already
## divided, so the caller owns the total and this owns the arrival.
var hero_share: float = 0.0
var enemy_damage: float = 0.0
var tower_damage: float = 0.0
var wildlife_damage: float = 0.0

var _rings: Array[Ring] = []
var _elapsed: float = 0.0
var _warned: float = 0.0
var _dust_in: float = 0.0
var _sheet_in: float = 0.0
var _opened: bool = false
var _ripple: ColorRect = null
var _ripple_material: ShaderMaterial = null
var _reach: float = 0.0
var _seen: RandomNumberGenerator = RandomNumberGenerator.new()


## Stands the wave up. `warning` may be zero for a wave that is already due -
## a guest is told about one that has already broken on the host.
func configure(epicentre: Vector2, power: float, ring_count: int,
		warning: float) -> void:
	at = epicentre
	magnitude = clampf(power, 0.0, 1.0)
	rings = clampi(ring_count, 1, Balance.QUAKE_RINGS_MAX)
	_warned = maxf(warning, 0.0)
	# Past the far corner, so nothing standing still is missed by a ring.
	_reach = (BattleGrid.HALF_EXTENT * Balance.QUAKE_WAVE_REACH_SHARE
		+ at.length())
	for index: int in rings:
		var ring := Ring.new()
		ring.born = _warned + float(index) * Balance.QUAKE_AFTERSHOCK_GAP
		_rings.append(ring)
	# Decoration's own dice: where dust puffs along a crest may not depend on
	# the run's stream, or turning the dust off would move every later roll.
	_seen.seed = absi(hash("quake") + int(at.x) * 31 + int(at.y))


func _ready() -> void:
	z_index = Balance.VFX_Z - 2
	z_as_relative = false
	global_position = Vector2.ZERO
	JuiceDirector.note(JuiceDirector.Priority.TELEGRAPH)
	_build_ripple()


## The screen-reading half. Never headless, where there is no frame to copy.
func _build_ripple() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not Graphics.water_refraction():
		return
	_ripple = ColorRect.new()
	_ripple.name = "QuakeRipple"
	_ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the whole viewport rather than over the field: the shader works in
	# screen space, because that is the only space in which a ring stays
	# round whatever the camera is doing.
	_ripple.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ripple.z_index = Balance.VFX_Z - 1
	_ripple_material = ShaderMaterial.new()
	_ripple_material.shader = load("res://scripts/shaders/quake_ripple.gdshader")
	_ripple_material.set_shader_parameter("crest", Balance.QUAKE_RIPPLE_CREST)
	_ripple_material.set_shader_parameter("strength", Balance.QUAKE_RIPPLE_STRENGTH)
	_ripple.material = _ripple_material
	var layer := CanvasLayer.new()
	layer.name = "QuakeRippleLayer"
	layer.layer = Balance.QUAKE_RIPPLE_LAYER
	layer.add_child(_ripple)
	add_child(layer)


func _process(delta: float) -> void:
	_elapsed += delta
	var running: bool = false
	for ring: Ring in _rings:
		var age: float = _elapsed - ring.born
		if age < 0.0:
			running = true
			continue
		ring.radius = age * Balance.QUAKE_WAVE_SPEED
		ring.alive = ring.radius <= _reach
		if ring.alive:
			running = true
			if not mirror:
				_strike_the_front(ring)
			_leave_the_fault(ring)
	_tell(delta)
	_drive_ripple()
	queue_redraw()
	if not running:
		queue_free()


## How far through its run a ring is, 0 at the epicentre and 1 at its reach.
func _spent(ring: Ring) -> float:
	return clampf(ring.radius / maxf(_reach, 1.0), 0.0, 1.0)


## **Everything the front has just reached, once.**
##
## A body is inside the crest when its distance from the epicentre is within
## half a crest width of the ring's radius. Tracked per ring by instance id,
## so a body running outward with the wave cannot be struck twice by it and
## a body running inward cannot dodge one it has already taken.
func _strike_the_front(ring: Ring) -> void:
	if field == null:
		return
	var half: float = Balance.QUAKE_CREST_WIDTH * 0.5
	# The share falls as the ring runs out of the ground, which is what makes
	# standing at the far edge of the field a real place to be.
	var fade: float = lerpf(1.0, Balance.QUAKE_EDGE_SHARE, _spent(ring))

	for hero: Hero in field.heroes():
		if hero == null or not hero.is_alive():
			continue
		var id: int = hero.get_instance_id()
		if ring.struck.has(id):
			continue
		if absf(hero.global_position.distance_to(at) - ring.radius) > half:
			continue
		ring.struck[id] = true
		if not hero.health.accepts_damage():
			continue
		var damage: float = hero.health.max_hp * hero_share * fade
		RunState.note_blow("earthquake", damage)
		hero.health.take_damage(damage, at)
		# Thrown off their feet away from the split, which is the one thing
		# the wave does that the old blow did not - and it moves nobody more
		# than a shove already can.
		hero.shove((hero.global_position - at).normalized()
			* Balance.QUAKE_HERO_KNOCKBACK * magnitude)

	for enemy: Enemy in field.enemies_near(Vector2.ZERO, INF):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var id: int = enemy.get_instance_id()
		if ring.struck.has(id):
			continue
		if absf(enemy.global_position.distance_to(at) - ring.radius) > half:
			continue
		ring.struck[id] = true
		enemy.take_damage(enemy_damage * fade, at,
			Balance.QUAKE_ENEMY_KNOCKBACK * magnitude)

	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower == null or not is_instance_valid(tower) or not tower.is_vulnerable():
			continue
		var id: int = tower.get_instance_id()
		if ring.struck.has(id):
			continue
		if absf(tower.global_position.distance_to(at) - ring.radius) > half:
			continue
		ring.struck[id] = true
		tower.hurt(tower_damage * fade, at)

	# The animals are wounded once, by the first ring, at the whole amount -
	# `wound_within` takes a circle rather than a band, so a ring-by-ring
	# version would hit the inner ones once per ring and the outer ones not
	# at all. Same total as before, and they are already running.
	if ring == _rings[0] and not ring.wounded_the_animals:
		ring.wounded_the_animals = true
		var animals: Wildlife = field.wildlife()
		if animals != null:
			animals.wound_within(Vector2.ZERO, INF, wildlife_damage * float(rings), false)
			animals.scare_from(at, INF)


## **The fault it leaves is where it actually broke.**
##
## The old one was stamped at a point drawn from its own stream, so the crack
## in the ground had no relationship to anything the player had watched
## happen. This lays cracks along the first ring's own front, at the distance
## the wave was strongest.
func _leave_the_fault(ring: Ring) -> void:
	if mirror or ring.fissured or ring != _rings[0]:
		return
	if _spent(ring) < Balance.QUAKE_FISSURE_AT:
		return
	ring.fissured = true
	var turn: float = _seen.randf() * TAU
	var first: Vector2 = Vector2.ZERO
	for index: int in Balance.QUAKE_FISSURE_ARMS:
		var angle: float = turn + TAU * float(index) / float(Balance.QUAKE_FISSURE_ARMS)
		var along: Vector2 = Vector2.RIGHT.rotated(angle)
		var spot: Vector2 = at + along * ring.radius
		if index == 0:
			first = spot
		if marks != null:
			for step: int in 4:
				marks.stamp(spot + along * (float(step) - 1.5) * 44.0,
					34.0, 0.35 * magnitude)
	# One charged ground per quake, as before, and now at a place the player
	# saw the earth open rather than at a point nobody watched.
	if zones != null:
		zones.open("seismic_fault", first, Balance.ZONE_FAULT_RADIUS)


# --- what it looks like -------------------------------------------------------

## Dust off the crest, the forged sheet along it, and the split at the middle
## while the earth is still humming. All of it decoration: nothing here reads
## a number and `Graphics.particle_scale` takes every part of it away.
func _tell(delta: float) -> void:
	if Graphics.particle_scale() <= 0.0:
		return
	_dust_in -= delta
	_sheet_in -= delta
	if _elapsed < _warned:
		# **Before anything moves, the ground says where.** A blow from
		# nowhere is the thing every telegraph in this project refuses, and
		# the old quake's warning was a sound and a camera tremor - neither
		# of which says *here*.
		if _dust_in <= 0.0:
			_dust_in = Balance.QUAKE_TELL_INTERVAL
			var near: float = Balance.QUAKE_TELL_RADIUS * (0.4 + 0.6 * _elapsed / maxf(_warned, 0.01))
			Vfx.dust(at + Vector2(_seen.randf_range(-1.0, 1.0),
				_seen.randf_range(-1.0, 1.0)) * near,
				Color(0.40, 0.33, 0.25), 3, 44.0)
		return
	if _dust_in <= 0.0:
		_dust_in = Balance.QUAKE_DUST_INTERVAL
		for ring: Ring in _rings:
			if not ring.alive or ring.radius < 40.0:
				continue
			for _puff: int in Balance.QUAKE_DUST_PER_TICK:
				var angle: float = _seen.randf() * TAU
				var spot: Vector2 = at + Vector2.RIGHT.rotated(angle) * ring.radius
				Vfx.dust(spot, Color(0.42, 0.34, 0.26), 4,
					Balance.QUAKE_CREST_WIDTH * 0.7)
	if _sheet_in <= 0.0:
		_sheet_in = Balance.QUAKE_SHEET_INTERVAL
		for ring: Ring in _rings:
			if not ring.alive or ring.radius < 60.0:
				continue
			var angle: float = _seen.randf() * TAU
			var spot: Vector2 = at + Vector2.RIGHT.rotated(angle) * ring.radius
			Vfx.forge_play("quake_dust", spot,
				Balance.QUAKE_FORGE_REACH * (0.7 + 0.5 * magnitude),
				Color(0.70, 0.60, 0.46, 0.75))


## Feeds the shader the rings in the space it works in: aspect-corrected
## screen UV, so a ring stays round whatever the camera is doing and the
## picture cannot disagree with where the front actually is.
func _drive_ripple() -> void:
	if _ripple_material == null:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var screen: Vector2 = viewport.get_visible_rect().size
	if screen.x <= 0.0 or screen.y <= 0.0:
		return
	var to_screen: Transform2D = get_viewport_transform()
	var aspect: float = screen.x / screen.y
	var centre: Vector2 = to_screen * at
	var scale: float = to_screen.get_scale().x
	var lives := Vector3.ZERO
	var showing: bool = false
	for index: int in 3:
		var ring_value := Vector3(0.0, 0.0, -1.0)
		if index < _rings.size() and _rings[index].alive and _rings[index].radius > 1.0:
			var ring: Ring = _rings[index]
			ring_value = Vector3(centre.x / screen.y, centre.y / screen.y,
				ring.radius * scale / screen.y)
			# It fades as it runs out, so a wave leaves rather than stopping.
			lives[index] = 1.0 - _spent(ring)
			showing = true
		_ripple_material.set_shader_parameter(
			["ring_a", "ring_b", "ring_c"][index], ring_value)
	_ripple_material.set_shader_parameter("ring_life", lives)
	_ripple_material.set_shader_parameter("aspect", aspect)
	if _ripple != null:
		_ripple.visible = showing


func _draw() -> void:
	if _elapsed < _warned:
		_draw_the_split()
		return
	for ring: Ring in _rings:
		# Nothing is drawn until the front has cleared the split it came out
		# of: a crest of slabs inside its own epicentre is a rosette.
		if not ring.alive or ring.radius < Balance.QUAKE_CREST_WIDTH:
			continue
		_draw_crest(ring)


## The epicentre while the earth hums: a star of hairline cracks that widens
## and darkens as the moment comes.
func _draw_the_split() -> void:
	var ready: float = clampf(_elapsed / maxf(_warned, 0.01), 0.0, 1.0)
	var reach: float = Balance.QUAKE_TELL_RADIUS * (0.25 + 0.75 * ready)
	var ink: float = 0.25 + 0.55 * ready
	for index: int in Balance.QUAKE_FISSURE_ARMS * 2:
		var angle: float = TAU * float(index) / float(Balance.QUAKE_FISSURE_ARMS * 2)
		# Each arm its own length, so the star is a break rather than a
		# compass rose.
		var along: float = reach * (0.45
			+ 0.55 * absf(fmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)))
		var tip: Vector2 = to_local(at) + Vector2.RIGHT.rotated(angle) * absf(along)
		draw_line(to_local(at), tip, Color(0.08, 0.06, 0.05, ink), 3.0 + 3.0 * ready, true)
	draw_circle(to_local(at), 10.0 + 16.0 * ready, Color(0.06, 0.05, 0.04, ink * 0.8))


## One crest: broken ground, not a painted ring.
##
## **Photographed three times before these numbers were chosen, and all
## three readings are worth keeping.** At the fissure's own alphas it was a
## pale hairline nobody could see from the distance a quake is actually
## watched. Drawn solid and bright it became an enormous flat donut laid
## over the field - the same failure the forge's first flame had, where one
## colour all the way through reads as paint rather than as a thing. Drawn
## as broken polylines it read as a ring of fence panels, because a polyline
## has one width and two flat ends.
##
## What earth breaking looks like is **slabs with gaps between them**, each
## tapering to a point at both ends and ragged along its outer edge. So each
## piece is a polygon: the outer arc with a per-vertex jitter, the inner arc
## back, and the two ends pinched onto the centreline. The gaps are as much
## of the effect as the slabs.
func _draw_crest(ring: Ring) -> void:
	var spent: float = _spent(ring)
	var fade: float = (1.0 - spent) * clampf(magnitude + 0.3, 0.0, 1.0)
	if fade <= 0.02:
		return
	var wide: float = Balance.QUAKE_CREST_WIDTH * (1.0 - 0.45 * spent)
	var middle: Vector2 = to_local(at)
	# A ring far out has more circumference to cover, so it is walked in more
	# pieces - otherwise a distant crest is a dotted line of long dashes.
	var steps: int = maxi(int(float(Balance.QUAKE_CREST_SEGMENTS)
		* (0.5 + 1.4 * spent)), 20)

	for index: int in steps:
		# Each piece decides for itself, off a hash of where it is rather
		# than off a stream: the crest must break in the same places on both
		# machines and must not move a roll the run depends on.
		var dice: float = _hash01(float(index) * 7.13 + ring.born * 3.7)
		if dice > Balance.QUAKE_CREST_FILL:
			continue
		var dice2: float = _hash01(float(index) * 3.71 + ring.born * 11.3 + 4.0)
		var a0: float = TAU * float(index) / float(steps)
		var a1: float = TAU * (float(index) + 0.75 + 0.5 * dice2) / float(steps)
		# Pieces do not all sit on one circle - a crest is a front, not a
		# hoop, and half of what makes it read as earth is that its outer
		# edge is uneven at every scale.
		var thick: float = wide * (0.22 + 0.30 * dice)
		# **Never inside its own middle.** A piece sits on its own radius, so
		# a young ring plus a negative jitter put the inner edge through the
		# epicentre and the polygon folded over itself - which Godot refuses
		# with "triangulation failed" and draws nothing at all. The floor is
		# the piece's own thickness, which is the smallest radius at which a
		# lens of that thickness is still a lens.
		var radius: float = maxf(ring.radius + (dice2 - 0.5) * wide * 0.8,
			thick * 1.2)

		var slab := PackedVector2Array()
		var lit := PackedVector2Array()
		var ribs: int = 5
		for step: int in ribs + 1:
			var t: float = float(step) / float(ribs)
			var angle: float = lerpf(a0, a1, t)
			var along: Vector2 = Vector2.RIGHT.rotated(angle)
			# Pinched to nothing at both ends, fattest a third of the way
			# along: a slab of earth is not a brick.
			var pinch: float = sin(t * PI)
			var rag: float = 1.0 + (_hash01(float(index) * 5.0 + t * 17.0) - 0.5) * 0.30
			slab.append(middle + along * (radius + thick * 0.5 * pinch * rag))
			lit.append(middle + along * (radius + thick * 0.42 * pinch * rag))
		# **The interior only, coming back.** The ends are pinched to nothing,
		# so an inner point at t=0 or t=1 lands exactly on the outer point
		# already there - a polygon with two duplicated vertices, which
		# Godot refuses with "triangulation failed" 255 times a run and
		# draws nothing at all. The tips are the outer arc's own first and
		# last points and the way back starts inside them.
		for step: int in range(1, ribs):
			var t: float = 1.0 - float(step) / float(ribs)
			var angle: float = lerpf(a0, a1, t)
			var along: Vector2 = Vector2.RIGHT.rotated(angle)
			var pinch: float = sin(t * PI)
			slab.append(middle + along * (radius - thick * 0.5 * pinch))
		# The dark split the slab was lifted out of, laid first and just
		# behind, so the earth reads as having come from somewhere.
		var behind := PackedVector2Array()
		for point: Vector2 in slab:
			behind.append(middle + (point - middle) * (1.0 - thick * 0.30 / maxf(radius, 1.0)))
		draw_colored_polygon(behind, Color(0.05, 0.04, 0.03, 0.62 * fade))
		draw_colored_polygon(slab, Color(0.44 + 0.10 * dice2, 0.33, 0.20, 0.90 * fade))
		# And the sun on the lifted edge, which is what says it is raised
		# rather than painted.
		draw_polyline(lit, Color(0.96, 0.84, 0.60, 0.80 * fade), 2.5, true)
		# A crack running back from the piece into the ground it has left.
		if dice2 > 0.6:
			var mid: Vector2 = Vector2.RIGHT.rotated((a0 + a1) * 0.5)
			draw_line(middle + mid * (radius - thick * 0.5),
				middle + mid * (radius - thick * 0.5 - wide * (0.4 + dice)),
				Color(0.06, 0.05, 0.04, 0.50 * fade), 2.5, true)


## A stable 0..1 from a number. Not the run's stream and not a generator:
## every machine drawing this crest must break it in the same places, and
## nothing here may move a roll the run depends on.
func _hash01(of: float) -> float:
	return absf(fmod(sin(of * 12.9898) * 43758.5453, 1.0))
