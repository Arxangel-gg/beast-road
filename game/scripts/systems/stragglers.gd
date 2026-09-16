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
		alive.append(body.get_instance_id())
	if alive.size() > 0 and alive.size() <= AT_MOST:
		_marked = alive
	if was > 0 or not _marked.is_empty():
		queue_redraw()


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
		var height: float = Balance.STRAGGLER_PLUME_HEIGHT * (0.92 + 0.08 * beat)
		var tone: Color = Balance.STRAGGLER_TONE
		tone.a *= 0.55 + 0.45 * beat
		# A column that fades out at the top rather than stopping: a hard-ended
		# bar reads as a UI element standing on the road, and this is meant to
		# read as light coming off the body.
		var steps: int = 5
		for step: int in steps:
			var low: float = float(step) / float(steps)
			var high: float = float(step + 1) / float(steps)
			var band: Color = tone
			band.a *= 1.0 - low
			draw_line(at + Vector2(0.0, -height * low),
				at + Vector2(0.0, -height * high), band,
				Balance.STRAGGLER_PLUME_WIDTH * (1.0 - low * 0.55), true)
		# A small ring at the feet, so the plume has somewhere to stand and the
		# body is findable once the player is close enough to see it.
		draw_arc(at, Balance.STRAGGLER_RING_RADIUS * (0.9 + 0.1 * beat), 0.0, TAU,
			20, Color(tone, tone.a * 0.7), 2.0, true)
