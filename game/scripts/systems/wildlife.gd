class_name Wildlife
extends Node2D

## The animals that live off the roads.
##
## Ambient in the strict sense: nothing here can be killed, hurt, targeted or
## collided with, and nothing here touches a run. It exists so the ground reads
## as inhabited rather than merely decorated - a field with a fox crossing it is
## a place, and the same field without one is a texture.
##
## **The population varies on purpose.** Sometimes almost none, sometimes plenty.
## A fixed count reads as decoration however good the sprites are, because the
## eye works out inside a minute that there are always exactly six. So arrivals
## are a coin flip rather than a top-up to a target, each animal has its own
## patience, and the field is allowed to be empty for a while.
##
## **Nothing here decides anything.** One node with a clock and a list; each
## animal is a sprite walking toward a point it picked. That is deliberately the
## cheapest thing that reads as alive - a real steering system would cost more
## than the battle it is decorating.

## How often an arrival is considered.
const ARRIVAL_INTERVAL: float = 4.0

## What an animal is doing. Small on purpose: ambient life with a rich state
## machine is a bug waiting to be found by somebody watching a wave.
enum State { ARRIVING, SETTLED, FLEEING, LEAVING }

## The grid, so animals can be kept off the roads. Assigned by the battlefield.
var grid: BattleGrid = null

## Where the sprites are parented, and it is not this node.
##
## They go into the battlefield's y-sorted entity root so each animal sorts
## against the enemies and the hero individually. Parented under this system they
## sorted as one block at *its* position, which is the origin - so every animal
## in the game drew at the depth of the town, in front of things it was behind.
var host: Node2D = null

## The field, so a kill can drop something.
var field: Node = null

var _living: Array[Dictionary] = []
var _arrival_clock: float = 0.0
var _kinds: Array[WildlifeData] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Its own stream, seeded from the run. Ambient life must never draw from the
	# combat stream, or a seeded replay would produce a different wave because a
	# rabbit happened to turn up.
	_rng.seed = hash("wildlife") ^ RunState.run_seed
	# A hero's swing is the only thing that can kill an animal, and it is heard
	# rather than fought for: putting wildlife in the enemy group would have
	# towers shooting rabbits and waves never ending, which is a far worse bug
	# than not being able to hunt.
	EventBus.hero_attack_landed.connect(_on_attack_landed)
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void:
		_refresh_kinds()
		# Old residents leave with the old act rather than lingering into ground
		# they do not belong on - a deer standing in Act III ash is worse than an
		# empty field.
		clear())
	_refresh_kinds()


## Which creatures belong in the act we are in.
##
## A deer in the ash of Act III would be saying the wrong thing about the place,
## and describing the place is the entire job.
func _refresh_kinds() -> void:
	_kinds.clear()
	for data: WildlifeData in ContentDB.wildlife():
		if data.acts.is_empty() or data.acts.has(RunState.act):
			_kinds.append(data)


func _process(delta: float) -> void:
	if Graphics.foliage_scale() <= 0.0:
		clear()
		return
	_arrival_clock -= delta
	if _arrival_clock <= 0.0:
		_arrival_clock = ARRIVAL_INTERVAL
		_consider_arrival()
	for index: int in range(_living.size() - 1, -1, -1):
		if _tick_one(_living[index], delta):
			continue
		var sprite: Node = _living[index]["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
		_living.remove_at(index)


## Perhaps something turns up.
##
## A coin flip rather than a refill to a target count, which is the whole
## difference between a population and a quota. The cap is a ceiling on cost, not
## a number to be reached.
func _consider_arrival() -> void:
	if _kinds.is_empty():
		return
	# Shares the foliage slider rather than adding a second one. Both are ambient
	# scatter, and a player who turns decoration down means all of it.
	var cap: int = int(round(float(Balance.WILDLIFE_MAX) * Graphics.foliage_scale()))
	if _living.size() >= cap:
		return
	# Below the floor, something always comes. Above it, arrival stays a coin
	# flip - that is what keeps the population varying rather than sitting at a
	# quota, while still guaranteeing the field is never empty for long.
	if _living.size() >= Balance.WILDLIFE_MIN 			and _rng.randf() > Balance.WILDLIFE_ARRIVAL_CHANCE:
		return
	var kind: WildlifeData = _pick_kind()
	if kind == null:
		return
	var at: Vector2 = _clear_point()
	if at == Vector2.ZERO:
		return
	for _member: int in _rng.randi_range(kind.group_min, kind.group_max):
		if _living.size() >= cap:
			return
		# Groups are spread rather than stacked: four deer on one pixel is one
		# deer with a thick outline. The spread is checked too - the *anchor*
		# being clear says nothing about a point seventy units off it, and that
		# gap is what put deer in lanes.
		var spread: Vector2 = at + Vector2(_rng.randf_range(-70.0, 70.0),
			_rng.randf_range(-52.0, 52.0))
		_spawn(kind, spread if _is_clear(spread) else at)


func _pick_kind() -> WildlifeData:
	var total: float = 0.0
	for kind: WildlifeData in _kinds:
		total += kind.weight
	if total <= 0.0:
		return null
	var roll: float = _rng.randf() * total
	for kind: WildlifeData in _kinds:
		roll -= kind.weight
		if roll <= 0.0:
			return kind
	return _kinds[_kinds.size() - 1]


func _spawn(kind: WildlifeData, at: Vector2) -> void:
	var path: String = kind.get_sprite_path()
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.scale = Vector2.ONE * kind.scale
	# Walks or flies in from off the edge, so nothing pops into existence in the
	# middle of a field somebody is looking at.
	sprite.global_position = at + Vector2(
		Balance.WILDLIFE_ENTRY_DISTANCE * (1.0 if _rng.randf() < 0.5 else -1.0),
		-Balance.WILDLIFE_ENTRY_DISTANCE if kind.flies else 0.0)
	sprite.z_as_relative = false
	# A flier is drawn above the ground it sorts against: the offset lifts the
	# picture without moving the body, so a crow passing in front of an enemy
	# still sorts by where it actually is.
	if kind.flies:
		sprite.offset.y = -Balance.WILDLIFE_FLIER_LIFT
	(host if host != null else self).add_child(sprite)

	_living.append({
		"data": kind,
		"sprite": sprite,
		"state": State.ARRIVING,
		"home": at,
		"goal": at,
		"base": sprite.texture,
		"idle": GameData.load_idle_frames(path),
		"move": GameData.load_move_frames(path),
		"fly": GameData.load_flight_frames(path),
		"frame_clock": _rng.randf() * 4.0,
		"pause": 0.0,
		"patience": _rng.randf_range(kind.stay_min, kind.stay_max),
		"bob": _rng.randf() * TAU,
	})


## One animal, one frame. False when it should be removed.
func _tick_one(animal: Dictionary, delta: float) -> bool:
	var sprite := animal["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return false
	var kind := animal["data"] as WildlifeData

	# Gone, if it has wandered far enough out that nobody can see it. That is
	# what keeps a long run from accumulating animals along the whole road behind
	# the beast, and it is why the cap can be generous.
	if _is_forgotten(sprite.global_position):
		return false

	animal["patience"] = float(animal["patience"]) - delta
	if int(animal["state"]) == State.SETTLED:
		if _frightened(sprite.global_position, kind):
			animal["state"] = State.FLEEING
			animal["goal"] = _bolt_target(sprite.global_position)
		elif float(animal["patience"]) <= 0.0:
			animal["state"] = State.LEAVING
			animal["goal"] = _bolt_target(sprite.global_position)

	var state: int = int(animal["state"])
	var speed: float = kind.speed
	if state == State.FLEEING or state == State.LEAVING:
		speed *= kind.flee_speed_scale
	var toward: Vector2 = (animal["goal"] as Vector2) - sprite.global_position
	var moving: bool = toward.length() > 6.0

	if moving:
		var step: Vector2 = toward.normalized() * speed * delta
		sprite.global_position += step
		# Facing from motion, against the *art's own* direction rather than a
		# guess. The sprites are drawn facing left, the flip was written for
		# right-facing art, and the result was six species walking backwards.
		if absf(step.x) > 0.001:
			sprite.flip_h = (step.x > 0.0) != kind.art_faces_right
	else:
		match state:
			State.ARRIVING:
				animal["state"] = State.SETTLED
			State.FLEEING:
				# It got somewhere else. Whether it stays is a fresh decision, so
				# bolting does not always end with the animal gone.
				animal["state"] = State.SETTLED
				animal["home"] = sprite.global_position
			State.LEAVING:
				return false
			State.SETTLED:
				animal["pause"] = float(animal["pause"]) - delta
				if float(animal["pause"]) <= 0.0:
					animal["pause"] = _rng.randf_range(
						Balance.WILDLIFE_PAUSE_MIN, Balance.WILDLIFE_PAUSE_MAX)
					animal["goal"] = _wander_from(animal["home"] as Vector2, kind)

	_animate(animal, sprite, delta, moving)
	return true


## The idle loop where there is one, a bob where there is not.
##
## The same choice the structures make and for the same reason: authored frames
## win where they exist, and a transform keeps everything else from standing
## perfectly still, which is what makes a sprite read as a cut-out.
func _animate(animal: Dictionary, sprite: Sprite2D, delta: float,
		moving: bool) -> void:
	var kind := animal["data"] as WildlifeData
	# Two authored sequences, chosen by what the animal is doing. Walking has its
	# own frames now rather than borrowing the standing pose and bobbing it,
	# which read as a cut-out being slid along the ground.
	# A flier in motion is *flying*, not walking. A crow that hopped across the
	# sky was the reported symptom of there being only one moving sequence.
	var flight := animal["fly"] as Array
	var frames: Array = animal["idle"] as Array
	var rate: float = Balance.WILDLIFE_IDLE_FRAME_RATE
	if moving:
		var airborne: bool = kind.flies and not flight.is_empty()
		frames = flight if airborne else (animal["move"] as Array)
		rate = Balance.WILDLIFE_FLIGHT_FRAME_RATE if airborne 			else Balance.WILDLIFE_MOVE_FRAME_RATE
	if not frames.is_empty():
		animal["frame_clock"] = float(animal["frame_clock"]) + delta * rate
		var index: int = int(floor(float(animal["frame_clock"]))) % frames.size()
		sprite.texture = frames[index] as Texture2D
		sprite.scale.y = kind.scale
		return
	# No authored frames for this state. Back to the resting pose plus a
	# transform, which keeps it from standing perfectly still - that is what
	# makes a sprite read as a cut-out.
	var base := animal["base"] as Texture2D
	if base != null:
		sprite.texture = base
	animal["bob"] = float(animal["bob"]) + delta * Balance.WILDLIFE_BOB_RATE
	var bob: float = absf(sin(float(animal["bob"]))) if moving else 0.0
	sprite.scale.y = kind.scale * (1.0 + bob * Balance.WILDLIFE_BOB_SCALE)


## Whether anything alarming is close enough to matter.
##
## People and enemies both. A rabbit that bolted from a hero and grazed happily
## through a pack of Bogkin is a rabbit nobody believes.
##
## The enemy check is deliberately *not* a scan of every enemy: it asks the field
## for the ones near this animal, which is the same broadphase the towers use. A
## distance test per animal per enemy per frame, to decide whether a rabbit
## twitches, is exactly the cost ambient decoration must not have.
##
## A raven has a radius of zero and is frightened by nothing: they are the
## animals that turn up *because* of a battle rather than in spite of one.
func _frightened(at: Vector2, kind: WildlifeData) -> bool:
	if kind.skittish_radius <= 0.0:
		return false
	# Every hero, not the local one: a rabbit that only bolted from the host
	# sat perfectly still while the guest walked through it.
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Node2D
		if hero != null and at.distance_to(hero.global_position) < kind.skittish_radius:
			return true
	if field != null and field.has_method("enemies_near"):
		for enemy: Enemy in field.enemies_near(at, kind.skittish_radius):
			if not enemy.is_dying():
				return true
	return false


## A hero swung, and anything small enough nearby does not survive it.
##
## Heard rather than hunted. Wildlife stays out of the enemy group - towers would
## shoot rabbits and waves would never end - so the hero's blow is picked up from
## the bus and resolved here, where it cannot reach the combat systems at all.
func _on_attack_landed(_chain_step: int, _targets: int, at: Vector2) -> void:
	if Coop.is_guest():
		return
	for index: int in range(_living.size() - 1, -1, -1):
		var animal: Dictionary = _living[index]
		var sprite := animal["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		if sprite.global_position.distance_to(at) > Balance.WILDLIFE_KILL_RADIUS:
			continue
		var kind := animal["data"] as WildlifeData
		Vfx.spark(sprite.global_position, Color("c4552e"), 8, Vector2.UP, 180.0)
		if field != null and field.has_method("spawn_loot"):
			field.spawn_loot(RunState.FOOD, kind.food_reward,
				sprite.global_position)
		sprite.queue_free()
		_living.remove_at(index)
		return


## True when an animal is far enough from every player to stop existing.
##
## Distance from the *heroes* rather than from a camera: there are two cameras in
## co-op and either one seeing it is reason enough to keep it. Measuring from the
## people is the same answer without asking the rendering layer anything.
func _is_forgotten(at: Vector2) -> bool:
	var heroes: Array = get_tree().get_nodes_in_group(Hero.GROUP_ANY)
	if heroes.is_empty():
		return false
	for node: Node in heroes:
		var hero := node as Node2D
		if hero != null and at.distance_to(hero.global_position) 				< Balance.WILDLIFE_FORGET_DISTANCE:
			return false
	return true


## Somewhere to run, away from the middle.
func _bolt_target(from: Vector2) -> Vector2:
	var away: Vector2 = from if from.length() > 1.0 else Vector2.RIGHT
	return away.normalized() * Balance.WILDLIFE_ENTRY_DISTANCE


## A new spot to potter over to, on ground it is allowed to stand on.
func _wander_from(home: Vector2, kind: WildlifeData) -> Vector2:
	for _attempt: int in 6:
		var candidate: Vector2 = home + Vector2(
			_rng.randf_range(-kind.roam, kind.roam),
			_rng.randf_range(-kind.roam, kind.roam) * 0.7)
		if _is_clear(candidate):
			return candidate
	# Six misses means the animal is hemmed in. Staying put is the only answer
	# that is certainly legal - returning `home` unchecked would let one that had
	# fled onto a road adopt it as somewhere to live.
	return home if _is_clear(home) else _bolt_target(home)


## A place to arrive at, or zero when the field is too built up to find one.
func _clear_point() -> Vector2:
	var span: float = Balance.WILDLIFE_FIELD_SPAN
	for _attempt: int in 12:
		var candidate := Vector2(_rng.randf_range(-span, span),
			_rng.randf_range(-span, span) * 0.66)
		if _is_clear(candidate):
			return candidate
	return Vector2.ZERO


## Off the roads and out of the town, by the rule the foliage already uses.
##
## Asked of the grid rather than measured against lane centre lines: the lanes
## bend, and a centre-line test would let a deer graze in the middle of a U-turn.
func _is_clear(point: Vector2) -> bool:
	if point.length() < Balance.TOWN_RADIUS + Balance.FOLIAGE_TOWN_MARGIN:
		return false
	if grid == null:
		return true
	var tile: Vector2i = BattleGrid.world_to_tile(point)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var cell: int = grid.cell_at(tile + Vector2i(dx, dy))
			if cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN:
				return false
	return true


## How many are on the field. For the gate, and for anyone who wants to know.
func population() -> int:
	return _living.size()


## Everywhere an animal is currently heading, for the gate.
##
## The goals rather than the positions, because those are two different rules and
## only one of them is a bug. An animal *crossing* a road is a deer crossing a
## path, which is what animals do and what makes the field read as a place. An
## animal that has chosen to stand in a lane makes the lane look like a mistake.
## So what the system guarantees, and what this exposes, is that nothing ever
## picks a destination it should not be standing on.
func goals() -> PackedVector2Array:
	var out := PackedVector2Array()
	for animal: Dictionary in _living:
		if int(animal["state"]) == State.SETTLED 				or int(animal["state"]) == State.ARRIVING:
			out.append(animal["goal"] as Vector2)
	return out


## Removes everything, without waiting for it to wander off.
func clear() -> void:
	for animal: Dictionary in _living:
		var sprite: Node = animal["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_living.clear()
