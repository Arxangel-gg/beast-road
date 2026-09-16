class_name PondFish
extends Node2D

## The fish that are actually in the pond.
##
## Owner brief, 2026-09-16: fish that jump and dive back in or flop, with variety
## and procedural direction; fish visibly swimming with real navigation; never
## overlapping what they should be under; never leaving the water; working with
## whatever shape a procedural pond came out; and reacting to a line cast near
## them - interested or startled by luck, placement and orientation.
##
## **They are the pond's own fish.** The school is stocked from
## `Fishing._roll_fish`, the same draw a cast makes, so every fish a player can
## see swimming is a fish they could pull out - and it wears that species' own
## icon, which is the one the journal and the stash show. A pond full of fish
## nobody could catch would be a worse lie than no fish at all.
##
## **Navigation is the depth field, not a shape.** Each fish looks a little way
## ahead and asks `PondTiles.depth_at` what is there; shallow water turns it, and
## the turn is toward whichever of a few sampled bearings is deepest. That is why
## it works on a pond with five lobes and a bitten rim without knowing anything
## about lobes: the answer comes from the same mask the swimming, the fishing and
## the shore fade all read. A fish cannot leave the water because there is nothing
## outside the water for it to steer toward.
##
## **Drawn over the surface and tinted through it.** The pond root sits below the
## sorted layer, so nothing here can draw over a hero, an enemy or a tower - but
## within the pond a fish is drawn *above* the water tiles and heavily graded
## toward the water's own colour by how deep it is. Under an opaque tilemap it
## would simply be invisible; through the surface is what being underwater looks
## like from above.
##
## **Almost none of it is read.** The school is decoration with one exception,
## named and bounded: a fish that came to look at the float is the fish that
## bites. See `claim_biter`. Everything else - the jumps, the flops, the feeding,
## the bolting - changes no number, and `Graphics.KEY_POND_FISH` takes all of it
## away with nothing else moving.

const UNDERWATER_SHADER: String = "res://scripts/shaders/fish_underwater.gdshader"

enum State { CRUISE, FEED, CURIOUS, STARTLED, JUMPING }

## The pond's depth mask, in the layer's own pixel space.
var depth: Image = null
## The water's colour, for grading a submerged body.
var water: Color = Color(0.16, 0.34, 0.48)
## Where the water nodes are, for stocking and for the deepest-first search.
var nodes: Array[Vector2i] = []

var _school: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0


func _ready() -> void:
	name = "PondFish"
	# **Sorted among themselves.** The whole school is under the pond root, which
	# sits below the field's own sorted layer - so a fish is behind every pad and
	# reed and can never draw over a hero whatever its y. What this adds is the
	# order *within* the water: the nearer fish in front of the further one,
	# rather than whatever order they were stocked in.
	y_sort_enabled = true
	z_index = Balance.POND_FISH_Z
	z_as_relative = true
	visible = Graphics.pond_fish()
	add_to_group(Graphics.POND_FISH_GROUP)


## Stocks the pond. `stock` is asked for one `FishData` at a time, so this knows
## nothing about the rarity tables - the same draw a cast makes answers it, which
## is what keeps what swims and what bites the same list.
func fill(seed_value: int, stock: Callable) -> void:
	_rng.seed = seed_value
	var wanted: int = _rng.randi_range(Balance.POND_FISH_PER_POND.x,
		Balance.POND_FISH_PER_POND.y)
	# A small pond holds fewer: four water nodes with six fish in them is a
	# shoal in a puddle.
	wanted = mini(wanted, maxi(nodes.size() / 2, 1))
	for _one: int in wanted:
		var kind: Variant = stock.call()
		if kind == null:
			continue
		_add(kind as FishData)


func _add(kind: FishData) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Fish"
	var art: String = kind.get_sprite_path()
	if not ResourceLoader.exists(art):
		return
	sprite.texture = load(art) as Texture2D
	sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	sprite.add_to_group(Graphics.FILTER_GROUP)
	# **Its own material.** Every fish carries its own depth and its own phase -
	# a school shimmering in unison is one animation played on six sprites.
	var seen := ShaderMaterial.new()
	seen.shader = load(UNDERWATER_SHADER) as Shader
	seen.set_shader_parameter("water_colour", water)
	seen.set_shader_parameter("silhouette", Balance.POND_FISH_SILHOUETTE)
	seen.set_shader_parameter("shade", Balance.POND_FISH_SHADE)
	seen.set_shader_parameter("fade", Balance.POND_FISH_FADE)
	seen.set_shader_parameter("caustic", Balance.POND_FISH_CAUSTIC)
	seen.set_shader_parameter("wobble", Balance.POND_FISH_WOBBLE)
	seen.set_shader_parameter("phase", _rng.randf() * TAU)
	sprite.material = seen
	# Bigger for the rarer ones, which is the tell a player reads before they
	# ever hook one: the thing cruising the deep water is worth waiting for.
	var grade: float = float(kind.rarity) / float(maxi(FishData.Rarity.size() - 1, 1))
	sprite.scale = Vector2.ONE * Balance.POND_FISH_SCALE * lerpf(1.0, 1.5, grade) \
		* _rng.randf_range(0.85, 1.15)
	sprite.position = _somewhere_wet()
	add_child(sprite)
	_school.append({
		"sprite": sprite,
		"kind": kind,
		"heading": Vector2.RIGHT.rotated(_rng.randf() * TAU),
		"speed": _rng.randf_range(Balance.POND_FISH_SPEED.x, Balance.POND_FISH_SPEED.y)
			* lerpf(1.15, 0.82, grade),
		"state": State.CRUISE,
		"hold": _rng.randf_range(1.0, 5.0),
		"jump_in": _rng.randf_range(Balance.POND_FISH_JUMP_EVERY.x,
			Balance.POND_FISH_JUMP_EVERY.y),
		"jump": 0.0,
		"jump_total": 0.0,
		"jump_from": Vector2.ZERO,
		"jump_to": Vector2.ZERO,
		# How it comes down: elegantly, nose first, or in a flat graceless flop.
		# Its size at the surface. Everything below that is depth.
		"size": sprite.scale,
		"elegant": _rng.randf() < Balance.POND_FISH_ELEGANT,
		"wiggle": _rng.randf() * TAU,
		"taken": false,
	})


# --- The swim ------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible or _school.is_empty():
		return
	_clock += delta
	for fish: Dictionary in _school:
		var sprite: Variant = fish["sprite"]
		if sprite == null or not is_instance_valid(sprite as Object):
			continue
		if int(fish["state"]) == State.JUMPING:
			_tick_jump(fish, sprite as Sprite2D, delta)
			continue
		_tick_swim(fish, sprite as Sprite2D, delta)


func _tick_swim(fish: Dictionary, sprite: Sprite2D, delta: float) -> void:
	var state: int = int(fish["state"])
	fish["hold"] = float(fish["hold"]) - delta
	# **The states, and what ends each of them.** A bolt runs out; curiosity
	# runs out or is answered; feeding and cruising trade off each other.
	if float(fish["hold"]) <= 0.0:
		match state:
			State.STARTLED, State.CURIOUS:
				state = State.CRUISE
				fish["hold"] = _rng.randf_range(2.0, 6.0)
			State.FEED:
				state = State.CRUISE
				fish["hold"] = _rng.randf_range(3.0, 8.0)
			_:
				state = State.FEED if _rng.randf() < Balance.POND_FISH_FEEDS else State.CRUISE
				fish["hold"] = _rng.randf_range(2.5, 7.0)
		fish["state"] = state
	var heading: Vector2 = fish["heading"]
	var speed: float = float(fish["speed"])
	var turn: float = Balance.POND_FISH_TURN
	match state:
		State.STARTLED:
			# Away, fast, and straighter than it ever swims otherwise.
			speed *= Balance.POND_FISH_BOLT_SCALE
			turn *= 0.5
		State.CURIOUS:
			speed *= 1.1
			var toward: Vector2 = (fish.get("look_at", sprite.position) as Vector2) - sprite.position
			if toward.length() > 4.0:
				heading = heading.slerp(toward.normalized(),
					clampf(Balance.POND_FISH_TURN * 1.6 * delta, 0.0, 1.0))
		State.FEED:
			speed *= 0.45
			# Circling: a slow constant turn is what a fish working one patch of
			# water looks like from above.
			heading = heading.rotated(Balance.POND_FISH_FEED_CIRCLE * delta)
		_:
			# A wander that changes its mind on its own clock rather than every
			# frame, so a fish holds a line instead of shivering along one.
			heading = heading.rotated(sin(_clock * 0.7 + float(fish["wiggle"])) * turn * delta)
	# **The bank.** Whatever the fish wanted, the water decides: it looks a
	# little ahead, and if that is shallow it turns toward the deepest bearing
	# it can find. This is the whole of "it cannot leave the pond" and the whole
	# of "it works on any shape".
	var ahead: Vector2 = sprite.position + heading * Balance.POND_FISH_LOOK
	if _wet(ahead) <= Balance.POND_FISH_MIN_DEPTH:
		heading = _deepest_bearing(sprite.position, heading)
		# Nosing a bank is a small startle of its own: it turns hard and puts a
		# little speed on to get away from the shallows.
		speed *= 1.2
	fish["heading"] = heading.normalized()
	var step: Vector2 = fish["heading"] * speed * delta
	var next: Vector2 = sprite.position + step
	# A last refusal, for the frame where a fish is already on a rim: never take
	# a step that ends on dry ground, whatever the steering decided.
	if _wet(next) > 0.0:
		sprite.position = next
	_dress(fish, sprite)
	# A wake now and then, so a fish near the surface marks the water.
	fish["jump_in"] = float(fish["jump_in"]) - delta
	if float(fish["jump_in"]) <= 0.0:
		_begin_jump(fish, sprite)


## How a fish looks from above the water: turned onto its heading, graded toward
## the water's own colour by how deep it is swimming, and thinning with it.
## A seam for the gate: turn a fish and read what the player would see. The real
## `_dress`, never a copy - a ledger that agrees with the data proves only that
## two files agree.
func dress(fish: Dictionary) -> void:
	var sprite: Variant = fish["sprite"]
	if sprite != null and is_instance_valid(sprite as Object):
		_dress(fish, sprite as Sprite2D)


func _dress(fish: Dictionary, sprite: Sprite2D) -> void:
	var heading: Vector2 = fish["heading"]
	var kind := fish["kind"] as FishData
	if kind.art_top_down:
		# Drawn from above with its nose north: turned onto its heading, never
		# mirrored. A mirrored top view points north whichever way it goes.
		sprite.flip_h = false
		sprite.rotation = heading.angle() + PI * 0.5
	else:
		# **Mirrored against what the painting actually does.** Every fish on
		# this roster is drawn facing left, and this flipped as though they
		# faced right - so every fish in every pond swam backwards.
		sprite.flip_h = (heading.x > 0.0) != kind.art_faces_right
		# A gentle roll onto the heading rather than a full turn: the art is a
		# fish in profile, and standing one on its nose to swim north reads as a
		# dead one. Which way the roll leans follows which way it is looking.
		var facing_right: bool = sprite.flip_h != kind.art_faces_right
		sprite.rotation = clampf(heading.y, -1.0, 1.0) * Balance.POND_FISH_PITCH \
			* (1.0 if facing_right else -1.0)
	# How deep it is, handed to the shader rather than multiplied into `modulate`
	# - which could only ever make a fish dimmer, never a silhouette.
	var deep: float = clampf(_wet(sprite.position), 0.0, 1.0)
	var graded: float = maxf(deep, Balance.POND_FISH_MIN_GRADE)
	var held: ShaderMaterial = sprite.material as ShaderMaterial
	if held != null:
		held.set_shader_parameter("depth", graded)
	# Further down is further away.
	sprite.scale = (fish.get("size", sprite.scale) as Vector2) \
		* (1.0 - Balance.POND_FISH_DEPTH_SHRINK * graded)


# --- Out of the water ----------------------------------------------------------

## **A jump.** Out at an angle, over an arc, and back in - which way it goes is
## the fish's own heading turned by a roll, so a pond does not produce the same
## leap twice. It comes down elegantly or in a flop, and the two sound and land
## differently.
func _begin_jump(fish: Dictionary, sprite: Sprite2D) -> void:
	fish["jump_in"] = _rng.randf_range(Balance.POND_FISH_JUMP_EVERY.x,
		Balance.POND_FISH_JUMP_EVERY.y)
	if _rng.randf() > Balance.POND_FISH_JUMP_CHANCE:
		return
	# Where it will come down, and it must be water: a fish that jumped onto the
	# bank would be the one thing here that can leave the pond.
	var heading: Vector2 = fish["heading"]
	var reach: float = _rng.randf_range(Balance.POND_FISH_JUMP_REACH.x,
		Balance.POND_FISH_JUMP_REACH.y)
	var landing: Vector2 = sprite.position + heading.rotated(
		_rng.randf_range(-0.5, 0.5)) * reach
	if _wet(landing) <= Balance.POND_FISH_MIN_DEPTH:
		landing = sprite.position - heading * reach * 0.5
		if _wet(landing) <= Balance.POND_FISH_MIN_DEPTH:
			return
	fish["state"] = State.JUMPING
	# Out of the water it is not seen through water: the shader comes off for
	# the arc, which is most of what makes a jump read as a jump.
	var held: ShaderMaterial = sprite.material as ShaderMaterial
	if held != null:
		held.set_shader_parameter("depth", 0.0)
	# Out of the water it is its own size again, which is most of why a jump
	# reads as a thing surfacing rather than a sprite sliding upward.
	sprite.scale = fish.get("size", sprite.scale) as Vector2
	fish["jump_from"] = sprite.position
	fish["jump_to"] = landing
	fish["jump_total"] = _rng.randf_range(Balance.POND_FISH_JUMP_SECONDS.x,
		Balance.POND_FISH_JUMP_SECONDS.y)
	fish["jump"] = float(fish["jump_total"])
	sprite.z_index = Balance.POND_FISH_AIR_Z
	_break_the_surface(sprite.position, 0.55)
	Sfx.play_at("sfx_fish_nibble", global_position + sprite.position, -7.0)


func _tick_jump(fish: Dictionary, sprite: Sprite2D, delta: float) -> void:
	fish["jump"] = float(fish["jump"]) - delta
	var total: float = maxf(float(fish["jump_total"]), 0.01)
	var through: float = clampf(1.0 - float(fish["jump"]) / total, 0.0, 1.0)
	var from: Vector2 = fish["jump_from"]
	var to: Vector2 = fish["jump_to"]
	var arc: float = sin(through * PI) * Balance.POND_FISH_JUMP_HEIGHT
	sprite.position = from.lerp(to, through) - Vector2(0.0, arc)
	sprite.modulate = Color.WHITE
	var kind := fish["kind"] as FishData
	var facing: float = 1.0 if to.x >= from.x else -1.0
	# A jump obeys the same rule the swim does, or a fish leaps out of the water
	# backwards - which is the one frame anybody would notice it in.
	sprite.flip_h = (facing > 0.0) != kind.art_faces_right if not kind.art_top_down else false
	if bool(fish["elegant"]):
		# Nose up out, nose down in: the body follows the arc it is on.
		sprite.rotation = -cos(through * PI) * Balance.POND_FISH_ARC_PITCH * facing
	else:
		# A flop: it turns over and comes down however it happens to be facing.
		sprite.rotation = through * TAU * Balance.POND_FISH_FLOP_SPINS * facing
	if float(fish["jump"]) > 0.0:
		return
	# Back in.
	sprite.position = to
	sprite.rotation = 0.0
	sprite.z_index = 0
	fish["state"] = State.CRUISE
	fish["hold"] = _rng.randf_range(1.5, 4.0)
	fish["heading"] = (to - from).normalized() if to != from else fish["heading"]
	_break_the_surface(to, 1.0 if bool(fish["elegant"]) else 1.35)
	Sfx.play_at("sfx_fish_escape" if not bool(fish["elegant"]) else "sfx_fish_nibble",
		global_position + to, -4.0)
	_dress(fish, sprite)


## The water answering: a ring, a spray of drops, and a ripple in the surface
## itself if the pond is listening.
func _break_the_surface(local: Vector2, strength: float) -> void:
	var where: Vector2 = to_global(local)
	Vfx.ring(where, 26.0 * strength, Color(0.88, 0.95, 1.0, 0.75), 0.55, 2.0)
	Vfx.spark(where, Color(0.76, 0.88, 1.0), int(4.0 + 5.0 * strength),
		Vector2.UP, 120.0 * strength)
	splashed.emit(where, strength)


## A fish broke the surface here. `Fishing` listens and puts a real ring in the
## water shader, which this node has no business reaching into.
signal splashed(at: Vector2, strength: float)


# --- The line ------------------------------------------------------------------

## **A float landed.** Every fish near enough decides what it thinks of it.
##
## Three things decide, which is what the owner asked for. **Placement**: the
## nearer it lands the stronger the reaction, and inside `POND_FISH_ON_ITS_HEAD`
## it is always a fright - a weight dropped on a fish is not an invitation.
## **Orientation**: a float that lands where a fish is already looking is
## interesting; one that lands behind it is a thing that crept up on it.
## **Luck**: an Angler's own skill tilts the roll, which is the one place in this
## file that the craft touches what a fish does.
##
## Returns how many came to look, for the gate.
func line_landed(local: Vector2, skill: float) -> int:
	var curious: int = 0
	for fish: Dictionary in _school:
		var sprite: Variant = fish["sprite"]
		if sprite == null or not is_instance_valid(sprite as Object) or bool(fish["taken"]):
			continue
		if int(fish["state"]) == State.JUMPING:
			continue
		var body := sprite as Sprite2D
		var toward: Vector2 = local - body.position
		var away: float = toward.length()
		if away > Balance.POND_FISH_NOTICE:
			continue
		if away <= Balance.POND_FISH_ON_ITS_HEAD:
			_startle(fish, body, -toward)
			continue
		# Where it landed against where the fish was looking: 1 dead ahead,
		# -1 directly behind.
		var ahead: float = (fish["heading"] as Vector2).dot(toward.normalized())
		var near: float = 1.0 - away / Balance.POND_FISH_NOTICE
		var interest: float = Balance.POND_FISH_INTEREST \
			+ ahead * Balance.POND_FISH_AHEAD_BONUS \
			+ skill * Balance.POND_FISH_SKILL_BONUS \
			- near * Balance.POND_FISH_NEAR_FRIGHT
		if _rng.randf() < clampf(interest, 0.02, 0.96):
			fish["state"] = State.CURIOUS
			fish["look_at"] = local
			fish["hold"] = _rng.randf_range(Balance.POND_FISH_CURIOUS_SECONDS.x,
				Balance.POND_FISH_CURIOUS_SECONDS.y)
			curious += 1
		else:
			_startle(fish, body, -toward)
	return curious


func _startle(fish: Dictionary, sprite: Sprite2D, away: Vector2) -> void:
	fish["state"] = State.STARTLED
	fish["hold"] = _rng.randf_range(Balance.POND_FISH_BOLT_SECONDS.x,
		Balance.POND_FISH_BOLT_SECONDS.y)
	if away.length() > 0.01:
		fish["heading"] = away.normalized()
	_break_the_surface(sprite.position, 0.35)


## **The one thing here that is read.** A fish that came to look at the float and
## reached it is the fish on the hook - so the species a player watched swim over
## is the species they land, rather than an unrelated roll happening behind the
## same ripple.
##
## Bounded on purpose: it only ever *replaces* a species with one the same pond
## could already have produced, because the school was stocked from the same
## draw a cast makes. Nothing about patience, fight, food or rarity odds moves,
## and with no fish at the float the caller's own roll stands untouched.
func claim_biter(local: Vector2) -> FishData:
	var best: Dictionary = {}
	var nearest: float = Balance.POND_FISH_AT_THE_FLOAT
	for fish: Dictionary in _school:
		if int(fish["state"]) != State.CURIOUS or bool(fish["taken"]):
			continue
		var sprite: Variant = fish["sprite"]
		if sprite == null or not is_instance_valid(sprite as Object):
			continue
		var away: float = (sprite as Sprite2D).position.distance_to(local)
		if away < nearest:
			nearest = away
			best = fish
	if best.is_empty():
		return null
	best["taken"] = true
	var body := best["sprite"] as Sprite2D
	_break_the_surface(body.position, 0.8)
	body.queue_free()
	_school.erase(best)
	return best["kind"] as FishData


## Everything in the pond bolts: the cast landed badly, or something came out of
## the water. Used by `Fishing` when a patch is startled.
func scatter_from(local: Vector2) -> void:
	for fish: Dictionary in _school:
		var sprite: Variant = fish["sprite"]
		if sprite == null or not is_instance_valid(sprite as Object):
			continue
		_startle(fish, sprite as Sprite2D, (sprite as Sprite2D).position - local)


func count() -> int:
	return _school.size()


## **Seams for the gate**, which drives the real school rather than a copy of it.
##
## `school()` hands back the live list - a gate reading it every frame is how a
## fish that crosses a spit of dry ground and carries on swimming is caught,
## which a reading taken at the end would call a pass.
func school() -> Array[Dictionary]:
	return _school


## How deep the water is at a point in this node's space, for the gate to ask the
## same question the steering asks.
func wet_at(local: Vector2) -> float:
	return _wet(local)


# --- The water underneath ------------------------------------------------------

## How deep the water is at a point in this node's own space, 0 on dry ground.
func _wet(local: Vector2) -> float:
	if depth == null:
		return 1.0
	return PondTiles.depth_at(depth, local)


## The deepest of a fan of bearings around the one it was on. Turned rather than
## reversed, so a fish that meets a bank follows it round instead of bouncing
## between two shores like a ball.
func _deepest_bearing(from: Vector2, heading: Vector2) -> Vector2:
	var best: Vector2 = -heading
	var deepest: float = -1.0
	for step: int in Balance.POND_FISH_BEARINGS:
		var turn: float = lerpf(-PI * 0.85, PI * 0.85,
			float(step) / float(maxi(Balance.POND_FISH_BEARINGS - 1, 1)))
		var bearing: Vector2 = heading.rotated(turn)
		var here: float = _wet(from + bearing * Balance.POND_FISH_LOOK)
		# A small bias toward carrying on, so a fish in open water does not
		# wander toward the middle of the pond and stay there.
		here += (1.0 - absf(turn) / PI) * 0.06
		if here > deepest:
			deepest = here
			best = bearing
	return best


## A place in the water to be born in, preferring the deep.
func _somewhere_wet() -> Vector2:
	if nodes.is_empty():
		return Vector2.ZERO
	var best: Vector2 = PondTiles.node_px(nodes[0])
	var deepest: float = -1.0
	for _try: int in 6:
		var node: Vector2i = nodes[_rng.randi_range(0, nodes.size() - 1)]
		var here: Vector2 = PondTiles.node_px(node)
		var wet: float = _wet(here)
		if wet > deepest:
			deepest = wet
			best = here
	return best
