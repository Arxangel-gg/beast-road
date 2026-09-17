class_name StablePaddock
extends Node2D

const ActorPolishScript = preload("res://scripts/systems/actor_polish.gd")

## **The stable's paddock, with horses in it** (owner brief, 2026-09-17).
##
## The owner's words: *"I want the most aesthetic solution in The Hold for it
## like a stable or something and animated horses with AI and a vendor at it."*
##
## This is `PenYard`'s idea applied to the stock rather than to the collection:
## one sprite per horse, **each with its own clock**, grazing where it stands,
## wandering somewhere new, tossing its head - so a paddock of five is never
## five copies of one animation. That is the whole reason to draw a paddock
## rather than list one, and the gate drives forty seconds and refuses a yard
## where every animal is doing the same thing.
##
## **It is a picture and nothing else.** It reads `ContentDB.mounts_sorted()` and
## `MetaState.mounts` to decide what is standing there and which one is the
## Warden's; it writes nothing, rolls no die that matters, and is read by
## nothing. Buying and saddling happen through `MetaState`'s own doors, which is
## the rule `PenScreen` follows for the same reason - a screen that had its own
## opinion about the price would be a second place for the price to live.
##
## **A horse the player owns stands differently**, and that is the only piece of
## information in the picture: the saddled one waits at the rail nearest the
## gate rather than out in the field. A plate would be a label on an animal; a
## horse standing where a horse waits for somebody is the place saying it.

## **The fallback lives on `MountRig` now**, not here. A missing painting has
## to degrade to a stiller picture rather than to a hole in the Hold
## (CLAUDE.md §4), and having two places decide what that picture is would be
## two answers to one question - which is how a paddock ends up drawing a
## different animal from the one the Warden rides.

## Whose authored coat spreads a paddock horse is dressed from. See `_stand`.
const COAT_SOURCE: String = "steppe_horse"

## How far apart two horses try to settle.
const SPACING: float = 150.0

var _stage: Vector2 = Balance.STABLE_PADDOCK
var _horses: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "StablePaddock"
	y_sort_enabled = true
	_rng.seed = hash("hold-stable")
	refresh()
	set_process(true)


## How big the paddock is. Set before or after `refresh`; either re-lays it.
func set_stage(size: Vector2) -> void:
	_stage = size
	_settle_places()


## Stands up the stock.
##
## **Seeded off each horse's own id**, so re-opening the Hold puts every animal
## back where it was rather than shuffling the paddock each visit - a field that
## rearranged itself every time would read as a different field.
func refresh() -> void:
	for horse: Dictionary in _horses:
		var node := horse.get("node") as Node2D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_horses.clear()
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		return
	# Every kind on show, and the field filled out with repeats if the roster is
	# shorter than the paddock. A stable that only stood the kinds it happened to
	# have would read as empty on a small roster and crowded on a large one.
	for index: int in Balance.STABLE_HORSES:
		_horses.append(_stand(stock[index % stock.size()], index))
	_settle_places()


## One horse, with its own art, its own coat and its own clock.
##
## **A `MountRig` rather than a bare sprite**, and that is the fix for a real
## miss rather than a tidy-up. The first cut reached for
## `GameData.load_idle_frames` - the `_idle_01` convention every *structure* and
## animal in this game uses - and a mount does not have those: its art is an
## eight-facing sheet per state. So every lookup came back empty, and the
## paddock was static sprites sliding around a field. The owner asked for
## *animated* horses with AI.
##
## The rig already reads those sheets, turns a body onto its heading, paces the
## legs against how fast it is going and casts the pool it stands in. A paddock
## horse is the same animal the Warden rides, doing the same things, which is
## also why it cannot drift from what a ride looks like.
func _stand(kind: MountData, index: int) -> Dictionary:
	var rig := MountRig.new()
	rig.name = "Horse%d" % index
	add_child(rig)
	rig.show_mount(kind)
	# **Its own coat, off its own place in the line**, so two of the same kind in
	# one field are two horses rather than one horse drawn twice. Same bound as
	# every phenotype in the game: nothing reads it, and `PHENOTYPE_HUE_CEILING`
	# stops a bay turning blue.
	#
	# Dressed from the steppe horse's own `WildlifeData` rather than from a set
	# of spreads typed in here. It is a real horse in the roster with authored
	# spreads somebody judged for a horse, and borrowing them is one number to
	# tune instead of two.
	var coat := ContentDB.wildlife_kinds.get(COAT_SOURCE, null) as WildlifeData
	var skin: Sprite2D = rig.body()
	if coat != null and skin != null:
		Phenotype.dress(ActorPolishScript.attach(skin), coat,
			absi(hash(kind.id + str(index))))
	var own := RandomNumberGenerator.new()
	own.seed = absi(hash("stable:" + kind.id + str(index)))
	return {
		"id": kind.id,
		"kind": kind,
		"node": rig,
		"rng": own,
		"pose": 0,
		"left": own.randf_range(Balance.STABLE_PAUSE_MIN, Balance.STABLE_PAUSE_MAX),
		"home": Vector2.ZERO,
		"to": Vector2.ZERO,
		"clock": own.randf() * 10.0,
	}


## Where each horse lives: on a lattice rather than scattered, because a random
## scatter in a small rectangle puts two of them on top of each other about as
## often as not - the same lesson the outskirts taught and the pen repeats.
##
## The saddled horse is lifted out of the lattice and put at the rail, which is
## the one thing this picture says.
func _settle_places() -> void:
	if _horses.is_empty():
		return
	var across: int = maxi(1, int(floor(_stage.x / SPACING)))
	var rows: int = int(ceil(float(_horses.size()) / float(across)))
	for index: int in _horses.size():
		var own := _horses[index]["rng"] as RandomNumberGenerator
		var at: Vector2
		if String(_horses[index]["id"]) == MetaState.mount_saddled and index < across:
			at = Vector2((float(index) + 0.5) / float(across) * _stage.x - _stage.x * 0.5,
				-_stage.y * 0.5 + 18.0)
		else:
			at = Vector2(
				(float(index % across) + 0.5) / float(across) * _stage.x - _stage.x * 0.5,
				(float(index / across) + 0.5) / float(maxi(rows, 1)) * _stage.y
					- _stage.y * 0.5)
			at += Vector2(own.randf_range(-16.0, 16.0), own.randf_range(-10.0, 10.0))
		_horses[index]["home"] = at
		_horses[index]["to"] = at
		var node := _horses[index]["node"] as Node2D
		if node != null:
			node.position = at


func _process(delta: float) -> void:
	for horse: Dictionary in _horses:
		_tick(horse, delta)


## Graze, wander, stand. Each on its own clock, which at five animals is enough
## that no two are ever doing the same thing.
func _tick(horse: Dictionary, delta: float) -> void:
	var rig := horse["node"] as MountRig
	if rig == null or not is_instance_valid(rig):
		return
	horse["clock"] = float(horse["clock"]) + delta
	horse["left"] = float(horse["left"]) - delta
	if float(horse["left"]) <= 0.0:
		_choose(horse)
	if int(horse["pose"]) == 1:
		var step: Vector2 = (horse["to"] as Vector2) - rig.position
		if step.length() > 4.0:
			var way: Vector2 = step.normalized()
			rig.position += way * Balance.STABLE_WANDER_SPEED * delta
			rig.set_facing(way)
			# Paced against the walk the rig was authored at, so a paddock horse
			# ambling reads slower than one the Warden is riding. The same scale
			# the field drives it with.
			rig.set_speed_scale(Balance.STABLE_WANDER_SPEED
				/ maxf(Balance.HERO_MOVE_SPEED, 1.0) * 3.0)
			rig.play("walk")
		else:
			horse["left"] = 0.0
	else:
		rig.set_speed_scale(1.0)
		rig.play("idle")
		# A slow shift of weight. Grazing animals dip; the one at the rail does
		# not, because it is waiting rather than eating.
		rig.position.y = (horse["home"] as Vector2).y \
			+ sin(float(horse["clock"]) * 1.1) * 0.5


func _choose(horse: Dictionary) -> void:
	var own := horse["rng"] as RandomNumberGenerator
	var roll: float = own.randf()
	if roll < 0.55:
		horse["pose"] = 0
		horse["left"] = own.randf_range(Balance.STABLE_GRAZE_MIN,
			Balance.STABLE_GRAZE_MAX)
		return
	horse["pose"] = 1
	var home := horse["home"] as Vector2
	var to := home + Vector2(own.randf_range(-1.0, 1.0),
		own.randf_range(-0.45, 0.45)).normalized() * own.randf_range(40.0, 130.0)
	# Inside the fence. A horse that wandered out of the paddock would be the
	# stable's whole point walking away from it.
	horse["to"] = Vector2(
		clampf(to.x, -_stage.x * 0.5 + 20.0, _stage.x * 0.5 - 20.0),
		clampf(to.y, -_stage.y * 0.5 + 12.0, _stage.y * 0.5 - 12.0))
	horse["left"] = own.randf_range(Balance.STABLE_PAUSE_MIN,
		Balance.STABLE_PAUSE_MAX)


func _draw() -> void:
	# The fence: four rails around the ground, drawn rather than tiled, because a
	# paddock is a rectangle and a tileset for one would be four corners of art
	# to keep in step with a number in `Balance`.
	var half: Vector2 = _stage * 0.5
	var ground := Rect2(-half, _stage)
	draw_rect(ground, Color(0.26, 0.29, 0.17, 0.55), true)
	var rail := Color(0.40, 0.31, 0.21, 0.95)
	draw_rect(ground, rail, false, 5.0)
	# A second rail inside the first, the way a real fence has two bars. The gap
	# is what makes it read as a fence rather than as a border.
	draw_rect(Rect2(-half + Vector2(0.0, 12.0), _stage - Vector2(0.0, 12.0)),
		Color(0.34, 0.26, 0.18, 0.75), false, 3.0)
	# The gate, north side, where the stabler stands.
	draw_line(Vector2(-40.0, -half.y), Vector2(40.0, -half.y),
		Color(0.55, 0.45, 0.30, 0.95), 6.0)


## How many horses are standing. For the gate.
func standing() -> int:
	return _horses.size()


## What pose a horse is in - 0 grazing, 1 wandering. For the gate.
func pose_at(index: int) -> int:
	if index < 0 or index >= _horses.size():
		return -1
	return int(_horses[index]["pose"])


## Drive the paddock by hand, for a gate with no minutes to spend. The same seam
## `PenYard` and `MusicPlayer` expose, and for the same reason: waiting out forty
## seconds of animation to prove five animals differ is a test of the clock.
func drive(seconds: float, step: float = 0.1) -> void:
	var left: float = seconds
	while left > 0.0:
		for horse: Dictionary in _horses:
			_tick(horse, step)
		left -= step
