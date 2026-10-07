class_name CorpseField
extends Node2D

## **The meaty corpse** (owner, 2026-10-07): *"a variety of meaty ground corpses
## that enemies and wildlife that die leave in their place that other wildlife
## can come and eat or pull and carry away ... different states for how much of
## a corpse is left as it gets reduced to just some bones that fade out after a
## very long amount of time ... In brutal mode make bones remain wherever they
## finally rested permanently ... ragdoll physics and impulse from the death
## blow that spawns it and from ground bouncing from wildlife eating it and
## impact from characters pushing it, and have 8 directions."*
##
## The missing link of the Living Battlefield (`docs/IDEAS_REVIEW_2026-10-07.md`
## §2.2): everything between a death and the bones. A record a body - where it
## lies, how it is moving, how much meat is left, which of eight ways it faces -
## drawn on one canvas under the bodies. One painted carcass in three states
## (`art/corpses`), scaled to the body that fell.
##
## **A look on this machine**, and the ecology's food on the host: a corpse
## blocks nothing, deals nothing and pays nothing. What eats it is the wildlife
## (`Wildlife` reads `nearest_meat` and calls `bite`), and in co-op the host's
## animals eat the host's corpses; a guest's corpses rot on their own clock.

const GROUP: StringName = &"corpse_fields"
const STATES: Array[String] = ["fresh", "eaten", "bones"]
const DIRECTIONS: Array[String] = ["south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west"]
const ART: String = "res://art/corpses/corpse_%s_%s.png"

## Sizes, by the body that fell.
enum Size { SMALL, MEDIUM, LARGE }

var _corpses: Array[Dictionary] = []
var _push_left: float = 0.0
var _redraw_left: float = 0.0
var _clock: float = 0.0
var _dice := RandomNumberGenerator.new()
## Never a static: an object a static keeps outlives the tree into the engine's
## shutdown, the recorded Linux exit crash.
var _textures: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	z_index = Balance.CORPSE_Z
	z_as_relative = false
	_dice.seed = absi(hash("corpses:%d" % RunState.run_seed))
	EventBus.body_fell.connect(_on_body_fell)


## The field the corpses of `scope` lie on, or null.
static func of(scope: Node) -> CorpseField:
	if scope == null:
		return null
	for found: Node in scope.get_tree().get_nodes_in_group(GROUP):
		if scope.is_ancestor_of(found):
			return found as CorpseField
	return null


## How big a body is, by its contact radius.
static func size_for(radius: float) -> int:
	if radius < Balance.CORPSE_SMALL_BELOW:
		return Size.SMALL
	if radius < Balance.CORPSE_LARGE_FROM:
		return Size.MEDIUM
	return Size.LARGE


## Which of the three paintings a share of meat wears.
static func state_for(meat: float) -> int:
	if meat > Balance.CORPSE_FRESH_FROM:
		return 0
	if meat > Balance.CORPSE_EATEN_FROM:
		return 1
	return 2


## Which of the eight ways a corpse thrown along `away` lies.
static func direction_for(away: Vector2) -> int:
	if away.length_squared() < 0.0001:
		return 0
	# 0 is south (screen down) and the paintings go south, south-east, east -
	# toward the right of the screen, which is a falling angle with y down.
	var turn: float = fposmod(PI * 0.5 - away.angle(), TAU)
	return int(round(turn / (TAU / 8.0))) % 8


func corpses() -> Array[Dictionary]:
	return _corpses


func count() -> int:
	return _corpses.size()


## **A body falls and leaves its corpse**: thrown along the blow, lifted, and
## left to bounce, slide and settle. A spirit and a stone leave nothing - there
## is no meat on either.
func lay(at: Vector2, from: Vector2, radius: float, kind_id: String = "", fresh: float = 1.0) -> Dictionary:
	var away: Vector2 = at - from
	away = away.normalized() if away.length_squared() > 1.0 else Vector2.from_angle(_dice.randf() * TAU)
	var size: int = size_for(radius)
	var corpse: Dictionary = {
		"at": at,
		"vel": away * Balance.CORPSE_THROW * _dice.randf_range(0.7, 1.2) / (1.0 + float(size) * 0.5),
		"height": 4.0,
		"vy": Balance.CORPSE_LIFT * _dice.randf_range(0.7, 1.1) / (1.0 + float(size) * 0.6),
		"size": size,
		"meat": clampf(fresh, 0.0, 1.0),
		"dir": direction_for(away),
		"age": 0.0,
		"bones_for": 0.0,
		"kind": kind_id,
		"carried_by": null,
		"spin": 0.0,
	}
	_corpses.append(corpse)
	while _corpses.size() > Balance.CORPSE_MAX:
		_forget_oldest()
	queue_redraw()
	return corpse


func _forget_oldest() -> void:
	# The oldest bones go first, then the oldest anything: a fresh corpse is
	# food somebody may be walking toward.
	var oldest: int = 0
	var oldest_age: float = -1.0
	for index: int in _corpses.size():
		var corpse: Dictionary = _corpses[index]
		var age: float = float(corpse["age"]) + (100000.0 if state_for(float(corpse["meat"])) == 2 else 0.0)
		if age > oldest_age:
			oldest_age = age
			oldest = index
	_corpses.remove_at(oldest)


## The corpse with meat on it nearest `at` within `reach`, or an empty one.
func nearest_meat(at: Vector2, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = reach * reach
	for corpse: Dictionary in _corpses:
		if float(corpse["meat"]) <= Balance.CORPSE_EATEN_FROM:
			continue
		var d: float = at.distance_squared_to(corpse["at"] as Vector2)
		if d < best_d:
			best_d = d
			best = corpse
	return best


## How many corpses with meat lie within `reach` of `at` - a pile.
func pile_at(at: Vector2, reach: float) -> int:
	var found: int = 0
	for corpse: Dictionary in _corpses:
		if float(corpse["meat"]) > Balance.CORPSE_EATEN_FROM \
				and at.distance_squared_to(corpse["at"] as Vector2) <= reach * reach:
			found += 1
	return found


## **A bite**: meat off the corpse, and the corpse jolts - a bounce off the
## ground and a little slide along the way it was pulled. Returns what was taken.
func bite(corpse: Dictionary, amount: float, from: Vector2) -> float:
	if corpse.is_empty() or not _corpses.has(corpse):
		return 0.0
	var taken: float = minf(float(corpse["meat"]), maxf(amount, 0.0))
	corpse["meat"] = float(corpse["meat"]) - taken
	var pull: Vector2 = (from - (corpse["at"] as Vector2))
	pull = pull.normalized() if pull.length_squared() > 1.0 else Vector2.ZERO
	corpse["vel"] = (corpse["vel"] as Vector2) + pull * Balance.CORPSE_BITE_PULL
	corpse["vy"] = maxf(float(corpse["vy"]), Balance.CORPSE_BITE_HOP)
	queue_redraw()
	return taken


## Something carries a corpse in its mouth: it follows `carrier`.
func carry(corpse: Dictionary, carrier: Node2D) -> void:
	if corpse.is_empty() or not _corpses.has(corpse):
		return
	corpse["carried_by"] = carrier


func drop(corpse: Dictionary) -> void:
	if not corpse.is_empty():
		corpse["carried_by"] = null
		corpse["vy"] = Balance.CORPSE_BITE_HOP


func _on_body_fell(at: Vector2, from: Vector2, radius: float, kind_id: String, scope: Node) -> void:
	if scope != null and not (scope == get_parent() or scope.is_ancestor_of(self) or get_parent() == scope):
		return
	lay(at, from, radius, kind_id)


func _process(delta: float) -> void:
	if _corpses.is_empty():
		return
	_clock += delta
	var moving: bool = false
	var brutal: bool = UserSettings.blood_level() >= UserSettings.BLOOD_BRUTAL
	var index: int = 0
	while index < _corpses.size():
		var corpse: Dictionary = _corpses[index]
		corpse["age"] = float(corpse["age"]) + delta
		# **Validity before the cast.** An animal carrying a carcass can be freed
		# under it, and `as` on a freed object is an engine error that stopped this
		# whole tick on every frame after - every corpse froze (found 2026-10-07).
		var held: Variant = corpse.get("carried_by", null)
		var carrier: Node2D = held as Node2D if held != null and is_instance_valid(held) else null
		if carrier != null:
			corpse["at"] = (corpse["at"] as Vector2).lerp(carrier.global_position, minf(1.0, delta * 12.0))
			corpse["height"] = 10.0
			moving = true
		else:
			corpse["carried_by"] = null
			moving = _step(corpse, delta) or moving
		# Rot: meat goes on its own, slowly, whether or not anything eats it.
		corpse["meat"] = maxf(0.0, float(corpse["meat"]) - delta / Balance.CORPSE_ROT_SECONDS)
		if state_for(float(corpse["meat"])) == 2:
			corpse["bones_for"] = float(corpse["bones_for"]) + delta
			# Bones fade after a very long time - never in Brutal, where they
			# become part of the ground.
			if not brutal and float(corpse["bones_for"]) > Balance.CORPSE_BONES_SECONDS + Balance.CORPSE_FADE_SECONDS:
				_corpses.remove_at(index)
				moving = true
				continue
		index += 1
	_push_left -= delta
	if _push_left <= 0.0:
		_push_left = 1.0 / Balance.CORPSE_PUSH_HZ
		moving = _shoved_by_passers() or moving
	_redraw_left -= delta
	if moving or _redraw_left <= 0.0:
		_redraw_left = 1.0 / Balance.CORPSE_REDRAW_HZ
		queue_redraw()


## One corpse's flight and slide. Returns whether it is still moving.
func _step(corpse: Dictionary, delta: float) -> bool:
	var vel: Vector2 = corpse["vel"]
	var height: float = float(corpse["height"])
	var vy: float = float(corpse["vy"])
	if height > 0.0 or vy > 0.0:
		vy -= Balance.CORPSE_GRAVITY * delta
		height += vy * delta
		if height <= 0.0:
			height = 0.0
			vy = -vy * Balance.CORPSE_BOUNCE if absf(vy) > 60.0 else 0.0
			vel *= 0.7
	else:
		vel = vel.move_toward(Vector2.ZERO, Balance.CORPSE_FRICTION * delta * maxf(vel.length(), 40.0))
	corpse["at"] = (corpse["at"] as Vector2) + vel * delta
	corpse["vel"] = vel
	corpse["height"] = height
	corpse["vy"] = vy
	return vel.length_squared() > 1.0 or height > 0.0


## **Bodies walking into a corpse shove it**: a body's own feet, a little way,
## heavier corpses less.
func _shoved_by_passers() -> bool:
	var shoved: bool = false
	var walkers: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		walkers.append(node as Node2D)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		walkers.append(node as Node2D)
	for corpse: Dictionary in _corpses:
		if corpse.get("carried_by", null) != null:
			continue
		var at: Vector2 = corpse["at"]
		var reach: float = Balance.CORPSE_PUSH_REACH * Balance.CORPSE_SIZE_SCALE[int(corpse["size"])]
		for walker: Node2D in walkers:
			if walker == null or not is_instance_valid(walker):
				continue
			var off: Vector2 = at - walker.global_position
			if off.length_squared() >= reach * reach or off.length_squared() < 0.01:
				continue
			corpse["vel"] = (corpse["vel"] as Vector2) + off.normalized() \
				* Balance.CORPSE_PUSH / (1.0 + float(corpse["size"]))
			shoved = true
	return shoved


func _draw() -> void:
	for corpse: Dictionary in _corpses:
		var texture: Texture2D = texture_for(state_for(float(corpse["meat"])), int(corpse["dir"]))
		if texture == null:
			continue
		var scale: float = Balance.CORPSE_SIZE_SCALE[int(corpse["size"])]
		var size: Vector2 = texture.get_size() * scale
		var at: Vector2 = (corpse["at"] as Vector2) - global_position
		var alpha: float = 1.0
		var bones_for: float = float(corpse["bones_for"])
		if bones_for > Balance.CORPSE_BONES_SECONDS and UserSettings.blood_level() < UserSettings.BLOOD_BRUTAL:
			alpha = clampf(1.0 - (bones_for - Balance.CORPSE_BONES_SECONDS) / Balance.CORPSE_FADE_SECONDS, 0.0, 1.0)
		var height: float = float(corpse["height"])
		if height > 0.5:
			# Its shadow stays on the ground while it is in the air.
			draw_set_transform(at, 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, size.x * 0.32, Color(0, 0, 0, 0.25 * alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(texture, Rect2(at - Vector2(size.x * 0.5, size.y * 0.75 + height), size),
			false, Color(1, 1, 1, alpha))


func texture_for(state: int, direction: int) -> Texture2D:
	var key: String = "%d:%d" % [state, direction]
	if _textures.has(key):
		return _textures[key]
	var path: String = ART % [STATES[clampi(state, 0, 2)], DIRECTIONS[clampi(direction, 0, 7)]]
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[key] = texture
	return texture
