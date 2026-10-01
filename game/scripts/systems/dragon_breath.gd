class_name DragonBreath
extends Node2D

## **What a dragon's breath looks like, and never what it does.**
##
## Owner, 2026-09-22: *"Dragon firebreath is highly unpolished and needs super
## aesthetically appealing game juicy vfx! Make it with blender's forge and also
## spice it up with whatever we can within Godot ... each dragon type's
## elemental breath attack which should match its element and not all be fire,
## although the non-fire dragons can also breath normal firebreath attacks as
## well ... the fire dragon should ... also have a special ultra firebreath
## attack which is a fire/electric/plasmaish hyperbeam type of laser beam."*
##
## Both breaths in the game were two straight lines of one colour: the war-camp
## wyrm's release (`EnemyGroundStrike`, a line) and the passing dragon's breath
## (`GroundHazard`, "breath"). This is the one picture both now stand up:
##
## - **a charge at the mouth** over the warning - a gathering glow and motes
##   falling into it, crackling arcs round an ultra - so the tell is read at the
##   dragon as well as on the ground;
## - **a feathered, licking cone** in the element's own three colours, drawn as
##   one triangle array with transparent rims (one colour across a whole shape
##   is what a hard edge *is*, the finding this project has paid for at the
##   blood, the swim sheen and the campfire);
## - **forged tongues** (`breath_tongue`) rolled down the line and a bloom
##   (`breath_bloom`) at the mouth and the landing, from Blender;
## - **the element's own matter** thrown off it: embers rise from fire, frost
##   motes drift, storm throws jagged bolts, stone sheds grit;
## - and for the ultra, **a plasma hyperbeam**: a white core in a violet sheath
##   in a fire skin, two arcs spiralling round it and forged `beam_core`
##   segments tiled end to end.
##
## **The bound is the fog's and the footfall's.** It is handed the line the blow
## was already committed to and the width it already resolves at; it reads
## nothing, rolls nothing the run relies on (its own dice), moves no number and
## sends no message. The telegraph's exact edges are still drawn by the strike
## that owns them - a breath that drew its own reach could disagree with it.

var mouth: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var half_width: float = 40.0
var element: String = "fire"
var ultra: bool = false
var warning: float = 0.6
var blast: float = 0.55

var _age: float = 0.0
var _opened: bool = false
var _tongue_clock: float = 0.0
var _matter_clock: float = 0.0
var _bolts: Array[PackedVector2Array] = []
var _bolt_clock: float = 0.0
var _dice := RandomNumberGenerator.new()
var _seed: float = 0.0
## The passing dragon this breath comes out of, when it came from one in the
## air: its mouth is read every frame, so the breath leaves the mouth as the
## body flies on (owner, 2026-09-30). The far end stays where it was aimed.
var follow: Node2D = null
## The blow the far end is read from while it lasts (2026-09-30): a breath
## that chases its target is one line with the blow that deals it, so the
## picture asks the blow where the beam ends rather than keeping its own.
var source: Node = null


## The element a breath is drawn in, as three colours: a core, a body and a rim.
static func palette(kind: String) -> Array:
	return Balance.DRAGON_BREATH_PALETTES.get(kind,
		Balance.DRAGON_BREATH_PALETTES["fire"]) as Array


## **Which breath a dragon breathes this time**, from its own element and dice.
##
## Its own element most of the time, plain fire the rest - a frost wyrm that
## sometimes breathes fire is the owner's own clause, and one that never did
## would make the fire the rarer sight. A dragon that can breathe the ultra
## breathes it on `DRAGON_ULTRA_CHANCE` of its breaths. The width, reach and
## angle wander by small authored amounts, which is the shape of the blow and
## never its size.
static func choose(kind: EnemyData, dice: RandomNumberGenerator) -> Dictionary:
	var own: String = kind.breath_element if kind != null else ""
	if own.is_empty():
		own = "fire"
	var element_now: String = own
	if own != "fire" and dice.randf() >= Balance.DRAGON_OWN_BREATH_CHANCE:
		element_now = "fire"
	var ultra_now: bool = kind != null and kind.breath_ultra \
		and dice.randf() < Balance.DRAGON_ULTRA_CHANCE
	var out: Dictionary = {
		"element": "plasma" if ultra_now else element_now,
		"ultra": ultra_now,
		"width": dice.randf_range(Balance.DRAGON_BREATH_WIDTH_WANDER.x,
			Balance.DRAGON_BREATH_WIDTH_WANDER.y),
		"reach": dice.randf_range(Balance.DRAGON_BREATH_REACH_WANDER.x,
			Balance.DRAGON_BREATH_REACH_WANDER.y),
		"turn": dice.randf_range(-Balance.DRAGON_BREATH_TURN_WANDER,
			Balance.DRAGON_BREATH_TURN_WANDER),
	}
	if ultra_now:
		out["width"] = Balance.DRAGON_ULTRA_WIDTH
		out["reach"] = Balance.DRAGON_ULTRA_REACH
		out["turn"] = 0.0
	return out


## Stands one up beside `parent`, deferred so it is safe from a `_ready`.
static func breathe(parent: Node, from_mouth: Vector2, to_end: Vector2,
		width: float, kind: String, is_ultra: bool, warn: float) -> DragonBreath:
	var breath := DragonBreath.new()
	breath.mouth = from_mouth
	breath.to = to_end
	breath.half_width = maxf(width, 8.0)
	breath.element = kind
	breath.ultra = is_ultra
	breath.warning = maxf(warn, 0.05)
	breath.blast = Balance.DRAGON_ULTRA_BLAST if is_ultra else Balance.DRAGON_BREATH_BLAST
	if parent != null:
		parent.add_child.call_deferred(breath)
	return breath


func _ready() -> void:
	z_index = Balance.VFX_Z - 1
	if follow == null:
		follow = _nearest_mouth(get_tree(), mouth)
	# **Over the mouth it leaves, never under it** (owner, 2026-09-30: "Dragon
	# breath should zsort ontop of dragon's mouth not behind it"). A passing
	# dragon draws at `DRAGON_Z` - absolute, above the whole field - and the
	# breath at the effects layer, so the breath came out from under its own
	# jaw. A breath that follows a dragon draws one step above it.
	if follow != null:
		z_as_relative = false
		z_index = follow.z_index + 1
	_follow_the_mouth()
	global_position = mouth
	_dice.randomize()
	_seed = _dice.randf() * 100.0
	# Light adds; grit does not. A stone breath drawn additively glows, which
	# is the one thing sand in the air does not do.
	if element != "stone":
		var glow: CanvasItemMaterial = LightKit.additive_material()
		material = glow
	JuiceDirector.note(JuiceDirector.Priority.HAZARD)
	Sfx.play_at("sfx_spell_cast", mouth, 1.0)


## **The passing dragon whose mouth is nearest `at`**, within
## `DRAGON_BREATH_FOLLOW_REACH`, or null. Found rather than handed over,
## because the breath is stood up from a relayed hazard plan and a plan
## carries positions, never a node - a guest's own mirror of the dragon is
## found the same way.
static func _nearest_mouth(tree: SceneTree, at: Vector2) -> Node2D:
	if tree == null:
		return null
	var best: Node2D = null
	var nearest: float = Balance.DRAGON_BREATH_FOLLOW_REACH
	for node: Node in tree.get_nodes_in_group(DragonPass.GROUP):
		var pass_node := node as DragonPass
		if pass_node == null or not pass_node.is_inside_tree():
			continue
		var apart: float = pass_node.mouth().distance_to(at)
		if apart <= nearest:
			nearest = apart
			best = pass_node
	return best


func _follow_the_mouth() -> void:
	if follow == null:
		return
	if not is_instance_valid(follow) or not follow.is_inside_tree():
		follow = null
		return
	var pass_node := follow as DragonPass
	if pass_node != null:
		mouth = pass_node.mouth()
		if is_inside_tree():
			global_position = mouth


func _process_measured(delta: float) -> void:
	_age += delta
	_follow_the_mouth()
	if source != null:
		if is_instance_valid(source) and source.has_method(&"breath_end"):
			to = source.call(&"breath_end") as Vector2
		else:
			source = null
	if _age >= warning:
		if not _opened:
			_open()
		var live: float = _age - warning
		if live <= blast:
			_tongue_clock -= delta
			if _tongue_clock <= 0.0:
				_tongue_clock = Balance.DRAGON_BREATH_TONGUE_EVERY
				_roll_a_tongue()
			_matter_clock -= delta
			if _matter_clock <= 0.0:
				_matter_clock = Balance.DRAGON_BREATH_MATTER_EVERY
				_throw_matter()
			_contact_clock -= delta
			if _contact_clock <= 0.0:
				_contact_clock = Balance.DRAGON_BREATH_CONTACT_EVERY
				_scorch_the_contact()
		_carry_the_light()
	if element == "storm" or ultra:
		_bolt_clock -= delta
		if _bolt_clock <= 0.0:
			_bolt_clock = 0.05
			_regrow_bolts()
	queue_redraw()
	if _age > warning + blast + Balance.DRAGON_BREATH_FADE:
		queue_free()


func _open() -> void:
	_opened = true
	var colours: Array = palette(element)
	var line: Vector2 = to - mouth
	var size: float = half_width * (4.0 if ultra else 3.0)
	Vfx.forge_play("breath_bloom", mouth, size, colours[1] as Color)
	Vfx.forge_hit(_hit_element(), to, size * 1.2, colours[1] as Color)
	Vfx.light_burst(to, colours[1] as Color, size * 2.0, 1.4, 0.4)
	if ultra:
		# Laid end to end down the beam, turned onto it, so the plasma crackles
		# along its whole length rather than at one point.
		var length: float = line.length()
		var step: float = Balance.DRAGON_ULTRA_SEGMENT
		var count: int = maxi(int(ceil(length / step)), 1)
		for index: int in count:
			var at: Vector2 = mouth + line.normalized() * step * (float(index) + 0.5)
			Vfx.forge_play("beam_core", at, step * 1.15, colours[1] as Color, line.angle())
		Vfx.forge_play("beam_end", to, size, colours[0] as Color, (-line).angle())
	var weight: float = Balance.IMPACT_FULL_SHARE * (0.55 if ultra else 0.3)
	EventBus.camera_impact.emit(mouth.lerp(to, 0.5), weight)
	for sound: String in _sounds():
		Sfx.play_at(sound, mouth.lerp(to, 0.35), 1.6)


## **Where the beam meets the ground** (owner, 2026-09-30: "more polish and
## more juice ... super juicy and aesthetically appealing though still
## optimized"). The end of the breath is where it lands, so it throws its
## element there on a clock - a forged hit the width of the beam, a spray off
## the ground, and a breath of the ground's own dust - and a light rides the
## end while it burns. All of it ink records and one light, so a sweep costs
## what a standing breath costs.
func _scorch_the_contact() -> void:
	var colours: Array = palette(element)
	var along: Vector2 = (to - mouth).normalized()
	var size: float = half_width * (2.4 if ultra else 1.8)
	Vfx.forge_hit(_hit_element(), to, size, colours[1] as Color)
	Vfx.spark(to, colours[0] as Color, 4 if ultra else 3, -along, 160.0)
	Vfx.dust(to, (colours[2] as Color).darkened(0.4), 2, half_width * 0.6)


## A light at the end of the beam for as long as it burns, given back when it
## goes out. Made by `LightKit.add_light` on a holder that rides the end, so its
## driver is the one writer of its energy and its flicker (`light_writer_check`:
## the first cut wrote the energy itself every frame beside nothing, which is
## exactly the second writer that strobed the menu's fires).
func _carry_the_light() -> void:
	var live: float = _age - warning
	if live > blast:
		if _end_light != null and is_instance_valid(_end_light):
			_end_light.queue_free()
			_end_light = null
		return
	if _end_light == null and Graphics.particle_scale() > 0.05:
		_end_light = Node2D.new()
		_end_light.top_level = true
		add_child(_end_light)
		LightKit.add_light(_end_light, palette(element)[1] as Color,
			half_width * 2.0 * (3.0 if ultra else 2.2), Balance.DRAGON_BREATH_END_LIGHT,
			Balance.TORCH_FLICKER)
	if _end_light != null:
		_end_light.global_position = to


var _contact_clock: float = 0.0
## The holder of the light at the end of the beam, freed with it.
var _end_light: Node2D = null


## **Where a breath should point to catch the most it has not caught yet**
## (owner, 2026-09-30: "the dragons should be able to more smartly aim their
## breaths so that they can make the best impact on as many targets in its
## range at any given time"). Candidate lines fan across `arc` either side of
## `home`; each scores the Wardens it would cover that the blow has not
## already struck - a blow lands on a body once, so a sweep is worth what it
## has still to reach - with a little for lying near the middle of the band,
## and the line nearest where the breath already points breaks a tie, so a
## breath with nothing new to reach holds still rather than twitching.
## `Vector2.INF` when no candidate reaches anybody.
static func best_line(tree: SceneTree, from: Vector2, home: float, arc: float,
		reach: float, half: float, struck: Dictionary, now: float) -> float:
	if tree == null:
		return INF
	var targets: Array[Dictionary] = []
	for node: Node in tree.get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not is_instance_valid(who) or not who.is_alive():
			continue
		if struck.has(who.get_instance_id()):
			continue
		if who.global_position.distance_to(from) > reach + half:
			continue
		targets.append({"at": who.global_position, "weight": 1.0})
	return best_line_among(targets, from, home, arc, reach, half, now)


## **The line that weighs most**, among `marks` (`{at, weight}`), inside `arc`
## of `home`. INF when no line reaches anything. Ties go to where the breath
## already points, so a breath with nothing new to reach holds still.
static func best_line_among(marks: Array[Dictionary], from: Vector2, home: float,
		arc: float, reach: float, half: float, now: float) -> float:
	if marks.is_empty():
		return INF
	var best: float = INF
	var best_score: float = 0.0
	var steps: int = Balance.DRAGON_BREATH_AIM_STEPS
	for index: int in steps:
		var angle: float = home + lerpf(-arc, arc, float(index) / float(maxi(steps - 1, 1)))
		var end: Vector2 = from + Vector2.from_angle(angle) * reach
		var score: float = 0.0
		for mark: Dictionary in marks:
			var at: Vector2 = mark["at"]
			var off: float = Geometry2D.get_closest_point_to_segment(at, from, end).distance_to(at)
			if off <= half:
				score += float(mark["weight"]) * (1.0 + 0.25 * (1.0 - off / maxf(half, 1.0)))
		score -= absf(angle_difference(now, angle)) * 0.01
		if score > best_score:
			best_score = score
			best = angle
	return best


## **Everything a wild dragon may breathe on, weighed the way Aurelion Sol
## would** (owner, 2026-10-01): the Wardens, their spirits, every road and camp
## body and every animal within `reach` of `from` not yet struck, each worth
## more the nearer it is, the more it is already hurt and - most of all - if
## this breath would finish it. `hero_share` is what the breath takes from a
## Warden, so a Warden it would finish is weighed as one.
static func wild_marks(tree: SceneTree, field: Battlefield, from: Vector2, reach: float,
		struck: Dictionary, hero_share: float) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	if tree == null:
		return marks
	for node: Node in tree.get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not is_instance_valid(who) or not who.is_alive():
			continue
		if struck.has(who.get_instance_id()):
			continue
		if field != null and field.inside_city(who.global_position):
			continue
		var pool: Health = who.health
		if pool == null:
			continue
		_weigh(marks, who.global_position, from, reach, pool.current_hp, pool.max_hp,
			pool.max_hp * hero_share, Balance.DRAGON_AIM_WARDEN)
	for node: Node in tree.get_nodes_in_group(Companion.GROUP):
		var pet := node as Companion
		if pet == null or not is_instance_valid(pet) or not pet.is_alive():
			continue
		if struck.has(pet.get_instance_id()):
			continue
		_weigh(marks, pet.global_position, from, reach, 1.0, 1.0, 0.0, 1.0)
	if field != null:
		for body: Enemy in field.living_bodies():
			if not is_instance_valid(body) or body.is_dying() or struck.has(body.get_instance_id()):
				continue
			var health: Health = body.health
			if health == null:
				continue
			_weigh(marks, body.global_position, from, reach, health.current_hp, health.max_hp,
				wild_blow(health.max_hp), 1.0)
		var wildlife: Wildlife = field.wildlife()
		if wildlife != null:
			for animal: Dictionary in wildlife.living():
				var sprite := animal.get("sprite", null) as Sprite2D
				var kind := animal.get("data", null) as WildlifeData
				if sprite == null or kind == null or not is_instance_valid(sprite):
					continue
				if float(animal.get("dying", 0.0)) > 0.0 or struck.has(sprite.get_instance_id()):
					continue
				var full: float = Wildlife.pool_of(animal)
				_weigh(marks, sprite.global_position, from, reach, float(animal.get("hp", 0.0)),
					full, full * Balance.DRAGON_WILD_BEAST_SHARE, 1.0)
	return marks


## What a wild breath takes from a body of `pool`: a share of it, capped by the
## act so a boss is scorched and never melted.
static func wild_blow(pool: float) -> float:
	var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_HP_SCALE.size() - 1)]
	return minf(pool * Balance.DRAGON_WILD_BODY_SHARE, Balance.DRAGON_WILD_BODY_CAP * act_scale)


static func _weigh(marks: Array[Dictionary], at: Vector2, from: Vector2, reach: float,
		current: float, full: float, blow: float, scale: float) -> void:
	var distance: float = at.distance_to(from)
	if distance > reach:
		return
	var weight: float = 1.0 + Balance.DRAGON_AIM_NEAR * (1.0 - distance / maxf(reach, 1.0))
	if blow > 0.0 and current <= blow:
		weight += Balance.DRAGON_AIM_LAST_HIT
	elif full > 0.0:
		weight += Balance.DRAGON_AIM_WEAK * (1.0 - clampf(current / full, 0.0, 1.0))
	marks.append({"at": at, "weight": weight * scale})


## The single most worth breathing on, or INF.
static func heaviest(marks: Array[Dictionary]) -> Vector2:
	var best: Vector2 = Vector2.INF
	var most: float = 0.0
	for mark: Dictionary in marks:
		if float(mark["weight"]) > most:
			most = float(mark["weight"])
			best = mark["at"]
	return best


## A tongue rolled from the mouth down the line, a little further each time.
func _roll_a_tongue() -> void:
	var line: Vector2 = to - mouth
	var length: float = line.length()
	if length <= 1.0 or ultra:
		return
	var colours: Array = palette(element)
	var t: float = _dice.randf_range(0.05, 0.85)
	var at: Vector2 = mouth + line * t + line.normalized().orthogonal() \
		* _dice.randf_range(-0.35, 0.35) * half_width
	# Small and soft: a tongue is texture inside the cone, never a second
	# shape laid over it - the first photograph had them as opaque blobs.
	var tint: Color = (colours[1] as Color).lerp(colours[0] as Color, _dice.randf() * 0.4)
	tint.a = Balance.DRAGON_BREATH_TONGUE_ALPHA
	Vfx.forge_play("breath_tongue", at, half_width * lerpf(2.2, 4.2, t), tint, line.angle())


## The element's own matter, thrown off the length of the breath.
func _throw_matter() -> void:
	var line: Vector2 = to - mouth
	var colours: Array = palette(element)
	var at: Vector2 = mouth + line * _dice.randf_range(0.15, 1.0)
	match element:
		"fire", "plasma":
			Vfx.spark(at, colours[1] as Color, 3, Vector2.UP, 110.0)
		"frost":
			Vfx.spark(at, colours[0] as Color, 3, line.normalized(), 70.0)
		"storm":
			Vfx.spark(at, colours[0] as Color, 2, Vector2.ZERO, 180.0)
		"stone":
			Vfx.dust(at, colours[1] as Color, 3, half_width * 0.8)
		_:
			Vfx.spark(at, colours[1] as Color, 2, Vector2.UP, 80.0)


func _hit_element() -> String:
	match element:
		"frost":
			return "water"
		"storm":
			return "air"
		"stone":
			return "earth"
		_:
			return "fire"


func _sounds() -> Array[String]:
	match element:
		"frost":
			return ["sfx_water_shot"]
		"storm":
			return ["sfx_thunder_near"]
		"stone":
			return ["sfx_quake"]
		"plasma":
			return ["sfx_thunder_near", "sfx_fire_shot"]
		_:
			return ["sfx_fire_shot"]


func _regrow_bolts() -> void:
	_bolts.clear()
	var a := Vector2.ZERO
	var b: Vector2 = to - mouth
	var across: Vector2 = b.normalized().orthogonal()
	for _bolt: int in (3 if ultra else 2):
		var bolt := PackedVector2Array()
		var steps: int = 12
		for index: int in steps + 1:
			var t: float = float(index) / float(steps)
			var jag: float = 0.0 if index == 0 or index == steps \
				else _dice.randf_range(-1.0, 1.0) * half_width * 0.9
			bolt.append(a.lerp(b, t) + across * jag)
		_bolts.append(bolt)


func _draw_measured() -> void:
	var b: Vector2 = to - mouth
	if b.length() < 1.0:
		return
	if _age < warning:
		_draw_charge(clampf(_age / maxf(warning, 0.01), 0.0, 1.0))
		return
	var live: float = _age - warning
	var reveal: float = clampf(live / (0.06 if ultra else 0.14), 0.0, 1.0)
	var fade: float = 1.0 - clampf((live - blast) / maxf(Balance.DRAGON_BREATH_FADE, 0.01),
		0.0, 1.0)
	if ultra:
		_draw_beam(b * reveal, fade)
	else:
		_draw_cone(b * reveal, fade)
	if (element == "storm" or ultra) and fade > 0.2:
		var bright: Color = palette(element)[0] as Color
		for bolt: PackedVector2Array in _bolts:
			var cut := PackedVector2Array()
			for point: Vector2 in bolt:
				cut.append(point * reveal)
			draw_polyline(cut, Color(bright, 0.85 * fade), 2.5, true)


## The gathering at the mouth: a glow that swells and flickers and motes that
## fall into it. An ultra charges bigger and crackles.
func _draw_charge(ready: float) -> void:
	var colours: Array = palette(element)
	var flicker: float = 0.85 + 0.15 * sin(_age * 38.0 + _seed)
	var radius: float = lerpf(8.0, half_width * (2.0 if ultra else 1.4), ready) * flicker
	var points := PackedVector2Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	_fan(points, shades, indices, Vector2.ZERO, radius * 1.8, Color(colours[2] as Color, 0.0),
		Color(colours[1] as Color, 0.45 * ready))
	_fan(points, shades, indices, Vector2.ZERO, radius, Color(colours[1] as Color, 0.0),
		Color(colours[0] as Color, 0.9 * ready))
	BloodInk.paint(self, points, shades, indices)
	for index: int in 7:
		var phase: float = fposmod(_age * 1.6 + float(index) / 7.0, 1.0)
		var angle: float = _seed + float(index) * 2.4
		var at: Vector2 = Vector2.RIGHT.rotated(angle) * radius * 3.2 * (1.0 - phase)
		draw_circle(at, 2.0 + 2.0 * phase, Color(colours[0] as Color, 0.8 * ready))
	if ultra:
		for index: int in 4:
			var angle: float = _age * 9.0 + float(index) * TAU / 4.0
			var from: Vector2 = Vector2.RIGHT.rotated(angle) * radius * 0.6
			var mid: Vector2 = Vector2.RIGHT.rotated(angle + 0.5) * radius * 1.5 \
				+ Vector2(_dice.randf_range(-4.0, 4.0), _dice.randf_range(-4.0, 4.0))
			var tip: Vector2 = Vector2.RIGHT.rotated(angle + 0.9) * radius * 2.1
			draw_polyline(PackedVector2Array([from, mid, tip]),
				Color(colours[0] as Color, 0.9 * ready), 2.0, true)


## The breath: three feathered layers from a narrow mouth to a wide front,
## licking at the edges on their own clocks.
func _draw_cone(b: Vector2, fade: float) -> void:
	var colours: Array = palette(element)
	var points := PackedVector2Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	_strip(points, shades, indices, b * 1.12, 1.45, colours[2] as Color, colours[1] as Color,
		0.6 * fade, 0.0)
	_strip(points, shades, indices, b * 1.06, 1.0, colours[1] as Color, colours[1] as Color,
		0.85 * fade, 1.7)
	_strip(points, shades, indices, b, 0.45, colours[1] as Color, colours[0] as Color,
		1.0 * fade, 3.1)
	BloodInk.paint(self, points, shades, indices)


## The hyperbeam: a straight ray of constant width that breathes fast, a fire
## skin, a violet sheath and a white core, with two arcs wound round it.
func _draw_beam(b: Vector2, fade: float) -> void:
	var colours: Array = palette(element)
	var along: Vector2 = b.normalized()
	var across: Vector2 = along.orthogonal()
	var pulse: float = 1.0 + 0.16 * sin(_age * 44.0)
	var points := PackedVector2Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	for layer: Array in [[2.4, colours[2], 0.45], [1.25, colours[1], 0.8], [0.4, colours[0], 1.0]]:
		var wide: float = half_width * float(layer[0]) * pulse
		var tint: Color = layer[1] as Color
		_band(points, shades, indices, b, across * wide, Color(tint, 0.0),
			Color(tint, float(layer[2]) * fade))
	BloodInk.paint(self, points, shades, indices)
	# The arcs close in with the band at both ends (2026-09-30): an arc that ran
	# to full width at the mouth and the tip was a hard white cut over a soft one.
	var length: float = b.length()
	var cap: float = minf(half_width * 1.25 * Balance.BEAM_CAP_WIDTHS, length * Balance.BEAM_CAP_MOST)
	for hand: int in 2:
		var helix := PackedVector2Array()
		var tints := PackedColorArray()
		var turns: float = length / 90.0
		for index: int in 49:
			var t: float = float(index) / 48.0
			var shape: Vector2 = VfxInk.beam_cap(minf(t, 1.0 - t) * length / maxf(cap, 0.01))
			var swing: float = sin(t * turns * TAU + _age * 32.0 + float(hand) * PI)
			helix.append(b * t + across * swing * half_width * 0.95 * pulse * shape.x)
			tints.append(Color(colours[0] as Color, 0.8 * fade * shape.y))
		draw_polyline_colors(helix, tints, 2.2, true)


## One layer of the cone as rows of five vertices: transparent rims, a body
## and a spine, so the edge is soft and the middle is bright.
func _strip(points: PackedVector2Array, shades: PackedColorArray,
		indices: PackedInt32Array, b: Vector2, scale: float, rim: Color, spine: Color,
		alpha: float, offset: float) -> void:
	var along: Vector2 = b.normalized()
	var across: Vector2 = along.orthogonal()
	var rows: int = 20
	var first: int = points.size()
	for row: int in rows + 1:
		var t: float = float(row) / float(rows)
		var lick: float = 1.0 + 0.2 * sin(_age * 13.0 + t * 9.0 + _seed + offset)
		var half: float = lerpf(half_width * 0.28, half_width * 1.65, pow(t, 0.62)) \
			* scale * lick
		# A round nose at the mouth rather than a flat cut (2026-09-30).
		var nose: Vector2 = VfxInk.beam_cap(t / 0.09)
		half *= nose.x
		var sway: float = sin(_age * 7.0 + t * 5.0 + offset) * half * 0.1
		var centre: Vector2 = b * t + across * sway
		# Brightest near the mouth, thinning out at the front, and the front
		# itself feathered away - a breath ending on a straight cut reads as a
		# shape rather than as something still rolling.
		var strength: float = alpha * lerpf(1.0, 0.6, t) \
			* clampf((1.0 - t) / 0.2, 0.0, 1.0) * lerpf(0.55, 1.0, nose.y)
		points.append(centre + across * half)
		shades.append(Color(rim, 0.0))
		points.append(centre + across * half * 0.5)
		shades.append(Color(rim.lerp(spine, 0.5), strength * 0.75))
		points.append(centre)
		shades.append(Color(spine, strength))
		points.append(centre - across * half * 0.5)
		shades.append(Color(rim.lerp(spine, 0.5), strength * 0.75))
		points.append(centre - across * half)
		shades.append(Color(rim, 0.0))
	for row: int in rows:
		var a: int = first + row * 5
		var c: int = a + 5
		for lane: int in 4:
			indices.append_array([a + lane, a + lane + 1, c + lane,
				a + lane + 1, c + lane + 1, c + lane])


## A band from the mouth to `b`, transparent at both edges and closing in a
## soft pointed cap at both ends (2026-09-30) - the ends every beam in the
## game shares (`VfxInk.beam_cap`), never a straight cut.
func _band(points: PackedVector2Array, shades: PackedColorArray,
		indices: PackedInt32Array, b: Vector2, side: Vector2, rim: Color,
		spine: Color) -> void:
	var length: float = b.length()
	if length < 0.1:
		return
	var along: Vector2 = b / length
	var first: int = points.size()
	var rows: PackedVector2Array = VfxInk.beam_rows(length, side.length())
	for row: Vector2 in rows:
		var shape: Vector2 = VfxInk.beam_cap(row.y)
		var at: Vector2 = along * row.x
		points.append(at + side * shape.x)
		shades.append(rim)
		points.append(at)
		shades.append(Color(spine, spine.a * shape.y))
		points.append(at - side * shape.x)
		shades.append(rim)
	for step: int in rows.size() - 1:
		var row: int = first + step * 3
		for lane: int in 2:
			indices.append_array([row + lane, row + lane + 1, row + 3 + lane,
				row + lane + 1, row + 4 + lane, row + 3 + lane])


## A soft disc: a bright middle falling to a clear rim.
func _fan(points: PackedVector2Array, shades: PackedColorArray,
		indices: PackedInt32Array, centre: Vector2, radius: float, rim: Color,
		middle: Color) -> void:
	var first: int = points.size()
	points.append(centre)
	shades.append(middle)
	var steps: int = 20
	for step: int in steps:
		points.append(centre + Vector2.RIGHT.rotated(TAU * float(step) / float(steps)) * radius)
		shades.append(rim)
	for step: int in steps:
		indices.append_array([first, first + 1 + step, first + 1 + (step + 1) % steps])


## `FrameProfile` bucket "d_dragon_breath": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_dragon_breath", started)


## `FrameProfile` bucket "p_dragon_breath": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_dragon_breath", started)
