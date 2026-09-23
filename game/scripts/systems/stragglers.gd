class_name Stragglers
extends Node2D

## **Where the last two bodies of a wave are.**
##
## #46 of the forwarded juice list, and the complaint behind it is real: a wave
## does not end until its pack is down, and the last one or two are routinely
## somewhere the player is not - round a camp, behind the treeline, or simply in
## fog, which does not draw a body at all. The wave clock keeps running and the
## player walks the road looking for something they cannot see.
##
## So when a wave reaches its tail, whatever is left wears a plume: a narrow
## column of light above the body, tall enough to clear the treeline and drawn
## over the fog rather than under it.
##
## **The bound is the fog's own, narrowed rather than broken.** `FogOfWar` hides
## and never helps - nothing about targeting, spawning, pathing or reward reads
## it. This reads nothing either: it is a *drawing*, it changes no number, and it
## only ever appears once a wave's queue is empty and the count is down to a
## handful. What it gives away is "the wave is not over and it is that way",
## which is information the wave clock is already charging the player for.
##
## It is a picture in the same sense `DeathMarkers` is: it watches the field
## every so often and draws. Turn the node off and the run is identical.

## How many bodies may be left before a wave counts as being in its tail. Two or
## three is a hunt; a dozen is a fight, and a fight does not need signposting.
const AT_MOST: int = 3

## How often the field is counted. Ten times a second is far more often than a
## wave changes shape, and a plume that appears a third of a second late reads
## as the game noticing rather than as a bug.
const TICK: float = 0.1

var field: EnemyField = null
var director: WaveDirector = null

var _clock: float = 0.0
var _marked: Array[int] = []
var _life: float = 0.0
## **What the next swing would land on**, the same callable `CombatTells`
## reads. A marked body inside it turns gold: the mark stops meaning only
## "this one is left" and starts meaning "and you can hit it from here",
## which is the owner's own request (2026-09-22) and costs no second query -
## the field already answers this question once a frame for the melee tell.
var hero: Callable = Callable()
var _in_reach: Dictionary = {}


func _ready() -> void:
	z_index = Balance.STRAGGLER_Z
	set_process(true)


func _process(delta: float) -> void:
	_life += delta
	_clock -= delta
	if _clock <= 0.0:
		_clock = TICK
		_gather()
	# Only redrawn while something is marked: a plume is rare and the canvas
	# should cost nothing on the ninety-nine waves that never reach a tail.
	if not _marked.is_empty():
		_read_reach()
		queue_redraw()


## The bodies still standing, if the wave is in its tail. Instance **ids** rather
## than nodes, because a body marked this tick is routinely dead by the next one
## and casting a freed object is an error in itself.
func _gather() -> void:
	var was: int = _marked.size()
	_marked.clear()
	if field == null or not is_instance_valid(field):
		if was > 0:
			queue_redraw()
		return
	# A wave still deploying is not in its tail however few are on the road -
	# the rest are queued and about to walk on.
	if director != null and is_instance_valid(director) and director.is_deploying():
		if was > 0:
			queue_redraw()
		return
	var standing: Array[Node] = get_tree().get_nodes_in_group(Enemy.GROUP)
	var alive: Array[int] = []
	for node: Node in standing:
		var body := node as Enemy
		if body == null or not is_instance_valid(body) or body.is_dying():
			continue
		# A camp body is not a wave - it never takes the road and nothing is
		# waiting on it, so pointing at one would send the player on an errand
		# the wave clock is not asking for. The same distinction `enemy_count`
		# draws one layer down.
		if body.is_camp_mob():
			continue
		# And only this field's: a raid's or a rift's bodies share the group.
		if field.has_method("holds_the_wave") and not bool(field.call("holds_the_wave", body)):
			continue
		alive.append(body.get_instance_id())
	if alive.size() > 0 and alive.size() <= AT_MOST:
		_marked = alive
	if was > 0 or not _marked.is_empty():
		queue_redraw()


## The bodies this is marking, by instance id - read by `ThreatPointers`, so an
## arrow at the edge of the screen and a plume over the treeline are the same
## set rather than two answers to "who is left".
func marked() -> Array[int]:
	return _marked


## Which of the marked bodies the next swing would reach. Asked once a frame
## for the whole set rather than per body per draw pass.
func _read_reach() -> void:
	_in_reach.clear()
	if not hero.is_valid():
		return
	var found: Variant = hero.call()
	if not (found is Array):
		return
	for entry: Variant in found as Array:
		var body := entry as Node2D
		if body != null and is_instance_valid(body):
			_in_reach[body.get_instance_id()] = true


func _draw() -> void:
	for id: int in _marked:
		var body := instance_from_id(id) as Node2D
		if body == null or not is_instance_valid(body):
			continue
		var at: Vector2 = to_local(body.global_position)
		# Breathing, and each out of phase with the others by its own id, so two
		# stragglers do not pulse in lockstep and read as one interface element.
		var beat: float = 0.5 + 0.5 * sin(_life * Balance.STRAGGLER_PULSE_HZ * TAU
			+ float(id % 17))
		# **Gold in reach, hostile out of it.** The mark answers two questions
		# with one drawing: where the last body is, and whether walking is
		# still part of the answer. Gold is the colour every "you may act on
		# this" in the game already uses.
		var within: bool = _in_reach.has(id)
		var tone: Color = Balance.STRAGGLER_TONE_REACHED if within \
			else Balance.STRAGGLER_TONE
		tone.a *= 0.62 + 0.38 * beat
		# **A chevron pointing down at the body**, bobbing on its own breath.
		#
		# Not a column: a column of warm light over a body is the loot beacon a
		# drop wears, and two opposite meanings in one visual language is worse
		# than no marker at all. A downward mark in a hostile colour cannot be
		# mistaken for something to pick up.
		# **Above this body's own head**, not a constant: a camp lord is three
		# times a runner and one number put the chevron inside the big ones.
		var crown: float = Balance.STRAGGLER_MARK_LIFT
		var creature := body as Enemy
		if creature != null:
			crown = creature.art_top_offset() + Balance.STRAGGLER_MARK_CLEAR
		var lift: float = crown + 6.0 * beat
		var tip := at + Vector2(0.0, -lift)
		var wide: float = Balance.STRAGGLER_MARK_WIDE * 0.5
		var tall: float = Balance.STRAGGLER_MARK_TALL
		var thick: float = Balance.STRAGGLER_MARK_THICK
		# Drawn twice: a dark backing a shade wider, so the mark reads against a
		# pale road as well as a dark one. The same trick every figure's outline
		# in this game uses, and it costs two more lines.
		var shade := Color(0.05, 0.03, 0.03, tone.a * 0.75)
		for pass_at: int in 2:
			var ink: Color = shade if pass_at == 0 else tone
			var fat: float = thick + (2.0 if pass_at == 0 else 0.0)
			draw_line(tip + Vector2(-wide, -tall), tip, ink, fat, true)
			draw_line(tip, tip + Vector2(wide, -tall), ink, fat, true)
		# **A ring on the ground at the feet**, so the body is findable once the
		# player is close enough to see it through the canopy.
		#
		# Flattened, because the camera looks down and slightly along and a
		# true circle at the feet reads as a hoop standing up - the same
		# reason the set aura and the range rings are ellipses - and sized
		# from the body's own width rather than from one number, so it rings
		# a giant and a runner alike. Both were reported (2026-09-22:
		# "placement and alignment and anchoring needs to be polished").
		var ring: float = Balance.STRAGGLER_RING_RADIUS
		if creature != null:
			ring = maxf(creature.contact_radius() * Balance.STRAGGLER_RING_SPREAD,
				Balance.STRAGGLER_RING_MIN)
		ring *= 0.9 + 0.1 * beat
		_ground_ring(at, ring, Color(tone, tone.a * 0.6),
			Balance.STRAGGLER_RING_WIDTH)
		if within:
			# A glow under whatever the swing would reach: a second, wider,
			# fainter ring rather than a brighter one, so it reads as light
			# off the ground instead of as a thicker line.
			_ground_ring(at, ring * 1.35, Color(tone, tone.a * 0.28),
				Balance.STRAGGLER_RING_WIDTH * 2.2)


## An ellipse on the ground, drawn as a closed polyline.
func _ground_ring(at: Vector2, radius: float, tint: Color, width: float) -> void:
	if radius <= 1.0 or tint.a <= 0.004:
		return
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 26
	for step: int in steps + 1:
		var angle: float = float(step) / float(steps) * TAU
		points.append(at + Vector2(cos(angle) * radius,
			sin(angle) * radius * Balance.STRAGGLER_RING_SQUASH))
	draw_polyline(points, tint, width, true)
