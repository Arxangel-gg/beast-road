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
## The flies' own redraw clock (`CORPSE_FLIES_HZ`), apart from the corpses'.
var _flies_left: float = 0.0
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


## **How big a corpse a body of `reach` leaves** (2026-10-08): its lying
## length against the paintings', as a scale the drawing reads.
static func scale_for(reach: float) -> float:
	return clampf(reach * 2.0 * Balance.CORPSE_BODY_SHARE / Balance.CORPSE_ART_LENGTH,
		Balance.CORPSE_SCALE_MIN, Balance.CORPSE_SCALE_MAX)


## The size band a body of `reach` falls in, by its corpse's scale.
static func size_for(reach: float) -> int:
	return band_of(scale_for(reach))


static func band_of(scale: float) -> int:
	if scale < Balance.CORPSE_SCALE_MEDIUM_FROM:
		return Size.SMALL
	if scale < Balance.CORPSE_SCALE_LARGE_FROM:
		return Size.MEDIUM
	return Size.LARGE


## What a corpse is drawn at: its own scale, or its band's for one banked
## before corpses had one.
static func scale_of(corpse: Dictionary) -> float:
	if corpse.has("scale"):
		return float(corpse["scale"])
	return Balance.CORPSE_SIZE_SCALE[clampi(int(corpse.get("size", 1)), 0, Balance.CORPSE_SIZE_SCALE.size() - 1)]


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
	var scale: float = scale_for(radius)
	var size: int = band_of(scale)
	var corpse: Dictionary = {
		"scale": scale,
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
		# Going: the earth is taking it, and it is drawn going.
		if corpse.has("leaving"):
			corpse["leaving"] = float(corpse["leaving"]) - delta
			moving = true
			if float(corpse["leaving"]) <= 0.0:
				_corpses.remove_at(index)
				continue
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
	_disaster_left -= delta
	if _disaster_left <= 0.0:
		var step: float = 1.0 / Balance.CORPSE_DISASTER_HZ
		_disaster_left = step
		moving = _weather_the_dead(step) or moving
	_redraw_left -= delta
	_flies_left -= delta
	if moving or _redraw_left <= 0.0:
		_redraw_left = 1.0 / Balance.CORPSE_REDRAW_HZ
		queue_redraw()
	elif _flies_left <= 0.0 and _flies_in_view():
		_flies_left = 1.0 / Balance.CORPSE_FLIES_HZ
		queue_redraw()


var _disaster_left: float = 0.0
## How many corpses each of the earth's ways has taken. For the gate.
var taken: Dictionary = {}


## **The earth's blows take the dead too** (owner, 2026-10-08). Read off the
## field it lies on: its fires, its flood and its funnels. A quake is told by
## the wave itself (`quake_front`), which is the one that knows where its crest
## is.
func _weather_the_dead(step: float) -> bool:
	var field := get_parent() as Battlefield
	if field == null:
		return false
	var changed: bool = false
	var fire: Wildfire = field.wildfire()
	if fire != null and fire.fire_count() > 0:
		changed = burn_near(fire.fire_positions(), step) or changed
	if RunState.flood >= Balance.CORPSE_FLOOD_FROM:
		changed = flood_tick(RunState.flood, RunState.wind, step) or changed
	for node: Node in get_tree().get_nodes_in_group(Tornado.GROUP):
		var funnel := node as Tornado
		if funnel == null or not is_instance_valid(funnel) or not field.is_ancestor_of(funnel):
			continue
		changed = tornado_tick(funnel.global_position, funnel.turning, step) or changed
	return changed


## The smaller it is, the likelier the earth takes it: a third again for a
## small corpse, a third less for a large one.
static func _frailty(corpse: Dictionary) -> float:
	match int(corpse.get("size", 1)):
		Size.SMALL:
			return 1.35
		Size.LARGE:
			return 0.65
	return 1.0


func _take(corpse: Dictionary, how: String) -> void:
	if corpse.has("leaving"):
		return
	corpse["leaving"] = Balance.CORPSE_LEAVE_SECONDS
	corpse["how"] = how
	corpse["carried_by"] = null
	taken[how] = int(taken.get(how, 0)) + 1
	var at: Vector2 = corpse["at"]
	var scale: float = scale_of(corpse)
	var bones: bool = state_for(float(corpse["meat"])) == 2
	match how:
		"shatter":
			Vfx.spark(at, Color(0.88, 0.84, 0.74), 7, Vector2.UP, 200.0)
			Vfx.dust(at, Color(0.62, 0.56, 0.48), 5, 30.0 * scale)
		"swallow":
			Vfx.dust(at, Color(0.4, 0.33, 0.26), 8, 34.0 * scale)
			Vfx.scar_dent(at, 18.0 * scale, Balance.SCAR_LANDING_DEPTH * 0.5)
		"ash":
			for _mote: int in 6:
				Vfx.mote(at + Vector2(_dice.randf_range(-12.0, 12.0), -6.0) * scale,
					Vector2(_dice.randf_range(-10.0, 10.0), -_dice.randf_range(30.0, 60.0)),
					Color(0.35, 0.33, 0.32, 0.7), 5.0 * scale, 1.4)
			Vfx.spark(at, Color(1.0, 0.55, 0.2), 5, Vector2.UP, 120.0)
		"wash":
			Vfx.ring(at, 30.0 * scale, Color(0.55, 0.75, 0.95, 0.5), 0.5, 3.0)
		"tear":
			Vfx.spark(at, Color(0.85, 0.82, 0.74) if bones else Color(0.55, 0.12, 0.1), 9,
				Vector2.ZERO, 280.0)
			Vfx.dust(at, Color(0.5, 0.44, 0.38), 6, 40.0 * scale)


## **A quake's crest crossing the dead** (2026-10-08): every corpse in the band
## between `inner` and `outer` from `centre` not yet crossed by crest `ring` is
## thrown up off the ground; bones may shatter and a carcass may be swallowed,
## likelier the nearer the epicentre (`near`, 1 there and 0 at the edge).
func quake_front(centre: Vector2, inner: float, outer: float, ring: int, near: float) -> bool:
	var changed: bool = false
	for corpse: Dictionary in _corpses:
		if corpse.has("leaving") or corpse.get("carried_by", null) != null:
			continue
		var distance: float = (corpse["at"] as Vector2).distance_to(centre)
		if distance < inner or distance > outer:
			continue
		var crossed: Array = corpse.get("quaked", []) as Array
		if crossed.has(ring):
			continue
		crossed.append(ring)
		corpse["quaked"] = crossed
		changed = true
		var away: Vector2 = ((corpse["at"] as Vector2) - centre).normalized()
		corpse["vy"] = Balance.CORPSE_QUAKE_HOP * _dice.randf_range(0.7, 1.1) / (1.0 + float(corpse["size"]) * 0.5)
		corpse["height"] = maxf(float(corpse["height"]), 2.0)
		corpse["vel"] = (corpse["vel"] as Vector2) + away * 60.0
		var strength: float = lerpf(0.5, 1.2, clampf(near, 0.0, 1.0)) * _frailty(corpse)
		if state_for(float(corpse["meat"])) == 2:
			if _dice.randf() < Balance.CORPSE_QUAKE_SHATTER * strength:
				_take(corpse, "shatter")
		elif _dice.randf() < Balance.CORPSE_QUAKE_SWALLOW * strength:
			_take(corpse, "swallow")
	return changed


## **A fire chars the dead and burns bones to ash** (2026-10-08): within
## `CORPSE_FIRE_REACH` of any of `fires`.
func burn_near(fires: PackedVector2Array, step: float) -> bool:
	var changed: bool = false
	var reach: float = Balance.CORPSE_FIRE_REACH
	for corpse: Dictionary in _corpses:
		if corpse.has("leaving"):
			continue
		var at: Vector2 = corpse["at"]
		var burning: bool = false
		for fire: Vector2 in fires:
			if fire.distance_squared_to(at) <= reach * reach:
				burning = true
				break
		if not burning:
			continue
		changed = true
		corpse["meat"] = maxf(0.0, float(corpse["meat"]) - Balance.CORPSE_FIRE_BURN * step)
		corpse["charred"] = minf(1.0, float(corpse.get("charred", 0.0)) + step * 0.6)
		if _dice.randf() < 0.3:
			Vfx.mote(at + Vector2(_dice.randf_range(-10.0, 10.0), -8.0), Vector2(0.0, -40.0),
				Color(0.3, 0.28, 0.27, 0.55), 6.0, 1.2)
		if state_for(float(corpse["meat"])) == 2 \
				and _dice.randf() < Balance.CORPSE_FIRE_ASH * step * _frailty(corpse):
			_take(corpse, "ash")
	return changed


## **A flood floats the dead off and washes them away** (2026-10-08): `depth`
## is the flood's share, `wind` the way the water runs.
func flood_tick(depth: float, wind: Vector2, step: float) -> bool:
	if depth < Balance.CORPSE_FLOOD_FROM:
		return false
	var share: float = clampf((depth - Balance.CORPSE_FLOOD_FROM)
		/ maxf(1.0 - Balance.CORPSE_FLOOD_FROM, 0.01), 0.0, 1.0)
	var way: Vector2 = wind.normalized() if wind.length_squared() > 0.0001 else Vector2.RIGHT
	var changed: bool = false
	for corpse: Dictionary in _corpses:
		if corpse.has("leaving") or corpse.get("carried_by", null) != null:
			continue
		changed = true
		var drift: Vector2 = way * Balance.CORPSE_FLOOD_DRIFT * share * _frailty(corpse) * step
		corpse["at"] = (corpse["at"] as Vector2) + drift
		corpse["spin"] = float(corpse.get("spin", 0.0)) + step
		if _dice.randf() < Balance.CORPSE_FLOOD_WASH * share * step * _frailty(corpse):
			_take(corpse, "wash")
	return changed


## **A funnel drags the dead in and flings them round** (2026-10-08): within
## `CORPSE_TORNADO_PULL` of `at` a corpse is drawn toward it; one that reaches
## its heart is flung round `spin` and up, and may be torn apart.
func tornado_tick(at: Vector2, spin: float, step: float) -> bool:
	var changed: bool = false
	for corpse: Dictionary in _corpses:
		if corpse.has("leaving") or corpse.get("carried_by", null) != null:
			continue
		var here: Vector2 = corpse["at"]
		var off: Vector2 = here - at
		var distance: float = off.length()
		if distance > Balance.CORPSE_TORNADO_PULL:
			continue
		changed = true
		if distance > Balance.TORNADO_CATCH_RADIUS:
			var pull: float = Balance.CORPSE_TORNADO_DRAG * (1.0 - distance / Balance.CORPSE_TORNADO_PULL)
			corpse["at"] = here - off.normalized() * pull * step * _frailty(corpse)
			continue
		if float(corpse.get("height", 0.0)) > 1.0:
			continue
		var round_it: Vector2 = off.normalized().orthogonal() * signf(spin) if distance > 1.0 \
			else Vector2.from_angle(_dice.randf() * TAU)
		corpse["vel"] = round_it * Balance.CORPSE_TORNADO_FLING / (1.0 + float(corpse["size"]) * 0.5)
		corpse["vy"] = Balance.CORPSE_LIFT * 2.0
		corpse["height"] = 4.0
		if _dice.randf() < Balance.CORPSE_TORNADO_TEAR * _frailty(corpse):
			_take(corpse, "tear")
	return changed


## How many flies a carcass draws: none fresh, a few once it has lain a while,
## more on a bigger one, none on bones or on one being carried. Public so the
## gate reads the rule the drawing uses.
static func flies_on(corpse: Dictionary) -> int:
	if float(corpse.get("age", 0.0)) < Balance.CORPSE_FLIES_FROM:
		return 0
	if state_for(float(corpse.get("meat", 0.0))) >= 2:
		return 0
	var carrier: Variant = corpse.get("carried_by", null)
	if carrier != null and is_instance_valid(carrier):
		return 0
	return mini(Balance.CORPSE_FLIES_MAX, 2 + int(corpse.get("size", 0)) * 2)


## Whether any carcass with flies is where the camera can see, which is the only
## time they are worth redrawing for. Never headless (`ScreenCull`).
func _flies_in_view() -> bool:
	for corpse: Dictionary in _corpses:
		if flies_on(corpse) > 0 and (not ScreenCull.culling()
				or ScreenCull.world_sees(self, corpse["at"] as Vector2, Balance.VFX_CULL_MARGIN)):
			return true
	return false


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
		var reach: float = Balance.CORPSE_PUSH_REACH * scale_of(corpse)
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
		var scale: float = scale_of(corpse)
		var size: Vector2 = texture.get_size() * scale
		var at: Vector2 = (corpse["at"] as Vector2) - global_position
		var alpha: float = 1.0
		var tint: Color = Color.WHITE
		# Charred by a fire, and fading as the earth takes it.
		var char_share: float = float(corpse.get("charred", 0.0))
		if char_share > 0.0:
			tint = tint.lerp(Color(0.22, 0.18, 0.16), clampf(char_share, 0.0, 1.0))
		var leaving: float = float(corpse.get("leaving", -1.0))
		if leaving >= 0.0:
			var gone: float = 1.0 - leaving / Balance.CORPSE_LEAVE_SECONDS
			alpha *= 1.0 - gone
			if String(corpse.get("how", "")) == "swallow":
				at.y += size.y * 0.5 * gone
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
			false, Color(tint.r, tint.g, tint.b, alpha))
		_draw_flies(corpse, at, size)


## A few dark specks circling over a carcass, each on its own loop off the
## field's clock, rising and dipping - and drawn, never simulated.
func _draw_flies(corpse: Dictionary, at: Vector2, size: Vector2) -> void:
	var flies: int = flies_on(corpse)
	if flies <= 0:
		return
	var seed_phase: float = float(int(corpse["dir"]) * 7 + int(corpse["size"]) * 3) * 0.37
	var reach: float = maxf(size.x * 0.28, 10.0)
	for fly: int in flies:
		var t: float = _clock * (5.0 + float(fly) * 1.3) + seed_phase + float(fly) * 2.1
		var spot: Vector2 = at + Vector2(cos(t) * reach, sin(t * 1.37) * reach * 0.45 - size.y * 0.5
			- 7.0 * sin(t * 2.3))
		# A dark body and a pale glint of wing that flickers - a dark speck alone
		# read as nothing on dark ground in the first photograph.
		draw_circle(spot, 2.3, Color(0.05, 0.05, 0.04, 0.95))
		if sin(t * 9.0) > -0.2:
			draw_circle(spot + Vector2(1.3 * signf(cos(t)), -1.4), 1.4, Color(0.86, 0.9, 0.97, 0.7))


## **Brutal bones come home** (owed since 2026-10-07): in Brutal the bones of
## the road are part of the ground, so a banked front carries them as it carries
## the blood and the scars - a place, a way and a size each, and the kind.
## Nothing outside Brutal, where bones fade anyway.
func bones_snapshot() -> Array:
	var out: Array = []
	if UserSettings.blood_level() < UserSettings.BLOOD_BRUTAL:
		return out
	for corpse: Dictionary in _corpses:
		if state_for(float(corpse["meat"])) < 2:
			continue
		var at: Vector2 = corpse["at"]
		out.append([at.x, at.y, int(corpse["dir"]), int(corpse["size"]), String(corpse["kind"]),
			scale_of(corpse)])
	return out


## Lays banked bones back where they lay, read clean - a row of the wrong shape
## is dropped, a way and a size are clamped, and never past the field's cap.
func restore_bones(stored: Array) -> void:
	for value: Variant in stored:
		if _corpses.size() >= Balance.CORPSE_MAX:
			break
		if not (value is Array) or (value as Array).size() < 5:
			continue
		var row: Array = value
		var size: int = clampi(int(row[3]), 0, Balance.CORPSE_SIZE_SCALE.size() - 1)
		_corpses.append({
			"scale": clampf(float(row[5]), Balance.CORPSE_SCALE_MIN, Balance.CORPSE_SCALE_MAX) \
				if row.size() > 5 else Balance.CORPSE_SIZE_SCALE[size],
			"at": Vector2(float(row[0]), float(row[1])),
			"vel": Vector2.ZERO,
			"height": 0.0,
			"vy": 0.0,
			"size": clampi(int(row[3]), 0, Balance.CORPSE_SIZE_SCALE.size() - 1),
			"meat": 0.0,
			"dir": clampi(int(row[2]), 0, DIRECTIONS.size() - 1),
			"age": Balance.CORPSE_ROT_SECONDS,
			"bones_for": 0.0,
			"kind": String(row[4]),
			"carried_by": null,
			"spin": 0.0,
		})
	queue_redraw()


func texture_for(state: int, direction: int) -> Texture2D:
	var key: String = "%d:%d" % [state, direction]
	if _textures.has(key):
		return _textures[key]
	var path: String = ART % [STATES[clampi(state, 0, 2)], DIRECTIONS[clampi(direction, 0, 7)]]
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_textures[key] = texture
	return texture
