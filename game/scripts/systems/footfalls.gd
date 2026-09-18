class_name Footfalls
extends Node2D

## **Every moving thing scuffs the ground it moves over.**
##
## Owner, 2026-09-17: *"Moving for all characters from players to enemies to
## wildlife should also generate ground vfx with perfect game juice and it should
## be tuned for each character's size and mass and speed including the dirt
## clouds etc which should be tuned for the color of the ground under where it
## occurred."*
##
## ## It watches; it is not told
##
## `DeathMarkers` settled this shape: it asks every frame whether each hero is
## standing rather than listening for a death, and that one decision answers most
## of its brief at once. The same applies here and harder. There are five things
## in this game that walk - a Warden, a body, an animal, a companion and a horse
## - and every one of them moves through code of its own, some of it a state
## machine, some of it a shove from the crowd grid, some of it a dash, some of it
## knockback. Emitting a scuff at each of those call sites is the failure this
## project has now shipped three times: an Arcane node applied its reach at four
## of five throws, a spell scale was recomputed by hand at three sites, and the
## interact button was read at eight. **One watcher measures travel, so every way
## a body can move is covered by construction** - including the ways nobody
## thought of, which is why a body knocked back throws dirt without anybody
## having wired knockback to anything.
##
## ## What a body declares, and what is measured
##
## A body registers **once** with three numbers, each derived from what it
## already carries: how wide its foot is, what it weighs against an ordinary road
## body, and how fast it can go. Everything else - how fast it is *actually*
## going, which way, whether it is moving at all - is measured here, from the
## positions, which is the one reading that cannot drift out of step with the
## body it describes.
##
## Effort is measured against the body's **own** ceiling. A rabbit flat out and a
## boss ambling cover the same ground in a second; the rabbit is at its limit and
## should be throwing everything it has, and the boss is strolling.
##
## ## What it is not
##
## Nothing reads a scuff. It changes no number, collides with nothing, and is
## drawn under everything that walks. `Graphics.particle_scale()` scales it away
## on a weak machine and `JuiceDirector` damps it under load, both to nothing,
## and the run is identical either way - the bound the fog, the phenotypes, the
## set aura and the Hold's grass are all held to.
##
## ## What it costs
##
## One pass at `Balance.FOOTFALL_HZ` over the bodies within
## `Balance.FOOTFALL_VIEW` of what the camera is watching, and one triangle array
## for every live mark. A field of two hundred bodies costs what the dozen on
## screen do, and the marks themselves are capped.

## Every body that leaves a mark. Joined by `register`, left by being freed.
const GROUP: StringName = &"treads"

## What the ground looks like at a point. Handed in by the scope, so this file
## knows nothing about where it is - a road, a camp, a maze and the Hold each
## answer for their own floor.
var ground: Callable = Callable()

## Where the camera is looking, for the cull. A scope with no camera hands in
## nothing and everything is considered, which is what a gate wants.
var watching: Callable = Callable()

var _marks: GroundMarks = null
var _seen: Dictionary = {}
var _clock: float = 0.0


## **Declares that this node leaves marks.** Called once, by the body itself,
## with numbers off its own data.
##
## `size` is the footprint in world units - what the body plants on the ground,
## which is its contact radius for everything that has one. `mass` is measured
## against an ordinary road body at one; a body of zero mass never registers,
## which is how a spirit leaves nothing without this file knowing what a spirit
## is. `top` is the fastest that body can travel, in units a second, which is
## what effort is measured against.
static func register(node: Node2D, size: float, mass: float,
		top: float) -> void:
	if node == null or mass <= 0.0 or size <= 0.0 or top <= 0.0:
		return
	node.set_meta(&"tread", Vector3(size, mass, top))
	node.add_to_group(GROUP)


## **An animal's tread, derived in one place.**
##
## Wildlife is the one thing here that is not a node with a script of its own -
## an animal is a record with a sprite - so its derivation cannot live on it. It
## lives here rather than at the two places that call it, because a cub growing
## up is the whole reason this is called twice and two copies of a growth rule is
## how one of them ends up describing a fawn as a stag.
##
## A flyer registers nothing: `flies` is the species saying it is not on the
## ground, and a moth does not scuff anything.
static func register_animal(sprite: Node2D, kind: WildlifeData,
		size: float) -> void:
	if kind == null or kind.flies:
		return
	var bulk: float = maxf(kind.scale, 0.1) * maxf(size, 0.1)
	register(sprite, Balance.ENEMY_BODY_RADIUS * bulk, bulk,
		maxf(kind.speed, 1.0) * maxf(kind.flee_speed_scale, 1.0))


## Stops a body leaving marks without freeing it - a hero who has gone into a
## raid, an animal that has taken to the air, a body being carried.
static func hush(node: Node2D, quiet: bool) -> void:
	if node == null or not node.has_meta(&"tread"):
		return
	if quiet:
		node.remove_from_group(GROUP)
	elif not node.is_in_group(GROUP):
		node.add_to_group(GROUP)


func _ready() -> void:
	_marks = GroundMarks.new()
	_marks.name = "Marks"
	_marks.ground = ground
	add_child(_marks)
	set_process(true)


func _process(delta: float) -> void:
	_clock += delta
	var step: float = 1.0 / maxf(Balance.FOOTFALL_HZ, 1.0)
	if _clock < step:
		return
	var elapsed: float = _clock
	_clock = 0.0
	_walk(elapsed)


func _walk(elapsed: float) -> void:
	# The load is asked once for the whole pass rather than once a body: it is a
	# property of the frame, not of who is standing in it.
	var weight: float = Graphics.particle_scale() \
		* JuiceDirector.weight(JuiceDirector.Priority.COSMETIC)
	var eye := Vector2.ZERO
	var culling: bool = watching.is_valid()
	if culling:
		var found: Variant = watching.call()
		if found is Vector2:
			eye = found as Vector2
		else:
			culling = false

	var here: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var body := node as Node2D
		if body == null or not is_instance_valid(body) or not body.is_inside_tree():
			continue
		var at: Vector2 = body.global_position
		if culling and at.distance_squared_to(eye) \
				> Balance.FOOTFALL_VIEW * Balance.FOOTFALL_VIEW:
			# **Forgotten rather than remembered as standing still.** A body that
			# walks off screen and comes back would otherwise return carrying the
			# whole journey as one stride and empty it into a single scuff.
			continue
		var id: int = body.get_instance_id()
		var was: Variant = _seen.get(id)
		var carried: float = 0.0
		var travelled: float = 0.0
		var way := Vector2.ZERO
		if was is Array:
			var last: Vector2 = (was as Array)[0] as Vector2
			carried = float((was as Array)[1])
			way = at - last
			travelled = way.length()
		var tread: Vector3 = body.get_meta(&"tread", Vector3.ZERO) as Vector3
		var top: float = maxf(tread.z, 1.0)
		var effort: float = clampf(travelled / maxf(elapsed, 0.001) / top,
			0.0, 1.0)
		if effort < Balance.FOOTFALL_MOVING or weight <= 0.01:
			# Standing still lays nothing, and neither does a body nudged a few
			# units by the crowd grid or breathing on the spot.
			here[id] = [at, 0.0]
			continue
		carried += travelled
		var stride: float = maxf(tread.x * Balance.FOOTFALL_STRIDE, 4.0)
		while carried >= stride:
			carried -= stride
			_step(at, way.normalized(), tread, effort, weight)
		here[id] = [at, carried]
	_seen = here
	_marks.bound(Balance.FOOTFALL_MAX_MARKS)


## One stride's worth of scuffed earth.
##
## Thrown **back along the way the body is going**, because that is where the
## foot pushed the ground - dust ahead of a runner reads as something they are
## walking into.
func _step(at: Vector2, way: Vector2, tread: Vector3, effort: float,
		weight: float) -> void:
	var mass: float = tread.y
	var count: int = int(round(lerpf(1.0, float(Balance.FOOTFALL_PUFFS), effort)
		* clampf(mass, 0.5, 2.6) * weight))
	# **Floored at one while the effect is on at all.** A scuff of nothing is not
	# a quieter scuff, it is a missing one, and the load is already answered by
	# how big and how faint each puff is below. Turned right down, it does stop.
	if weight > 0.25:
		count = maxi(count, 1)
	for _index: int in count:
		var throw: float = lerpf(Balance.FOOTFALL_THROW.x,
			Balance.FOOTFALL_THROW.y, effort) * sqrt(mass)
		_marks.scuff(at, -way * throw,
			tread.x * Balance.FOOTFALL_PUFF_SIZE * lerpf(0.7, 1.25, effort)
				* sqrt(mass) * clampf(weight, 0.4, 1.0),
			Balance.FOOTFALL_LIFE,
			Balance.FOOTFALL_ALPHA * clampf(weight, 0.0, 1.0),
			Balance.FOOTFALL_DRAG)


## How many marks are alive. For the gate, which measures rather than asserts.
func live_marks() -> int:
	return _marks.live() if _marks != null else 0
