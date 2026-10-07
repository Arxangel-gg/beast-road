class_name GroundHazard
extends Node2D

## Committed ground warnings. Each body can be struck only once per path.
var field: Battlefield
var plan: Dictionary = {}
var mirror: bool = false
var _elapsed: float = 0.0
var _dust: float = 0.0
var _hit: Dictionary = {}
var _previous: Vector2
var _erupted: bool = false
## Where a breath's far end is now, and who it chases once loosed
## (2026-09-30). Every machine chases its own nearest Warden; only the host's
## copy strikes, so a guest's picture following its own copy of the same
## Warden is a picture and nothing more.
var _to: Vector2 = Vector2.ZERO
var _chasing: Node2D = null


func _ready() -> void:
	z_index = Balance.VFX_Z - 2
	_previous = plan["from"] as Vector2
	_to = plan["to"] as Vector2
	JuiceDirector.note(JuiceDirector.Priority.TELEGRAPH)
	# **The passing dragon's breath is the same picture as a war-camp wyrm's**
	# (owner, 2026-09-22). The warning's exact edges are still drawn here; the
	# breath itself - cone, tongues, element - is `DragonBreath`.
	if String(plan["mode"]) == "breath":
		var picture: DragonBreath = DragonBreath.breathe(get_parent(),
			plan.get("origin", plan["from"]) as Vector2,
			plan["to"] as Vector2, float(plan["width"]),
			String(plan.get("element", "fire")), bool(plan.get("ultra", false)),
			float(plan["warning"]))
		picture.source = self
		_chasing = _nearest_warden(_to)


func _process_measured(delta: float) -> void:
	_elapsed += delta
	var warning: float = float(plan["warning"])
	var travel: float = float(plan["travel"])
	var progress: float = clampf((_elapsed - warning) / maxf(travel, 0.001), 0.0, 1.0)
	if String(plan["mode"]) == "breath" and _elapsed >= warning:
		_chase(delta)
	var start: Vector2 = plan["from"] as Vector2
	var end: Vector2 = _to
	var head: Vector2 = start.lerp(end, progress)
	if _elapsed >= warning and _elapsed <= warning + travel + delta:
		if not _erupted:
			_erupted = true
			if String(plan["mode"]) == "fissure":
				Vfx.scar_crack(start, end, float(plan["width"]) * 0.5, Balance.SCAR_FISSURE_DEPTH)
				for index: int in Balance.EARTH_DEBRIS_BURSTS:
					Vfx.impact(start.lerp(end, float(index) / float(Balance.EARTH_DEBRIS_BURSTS - 1)),
						TowerData.Element.EARTH, Color(0.65, 0.49, 0.3), float(plan["width"]) * 2.0)
		var a: Vector2 = start if String(plan["mode"]) != "trail" else _previous
		var b: Vector2 = end if String(plan["mode"]) != "trail" else head
		if not mirror:
			_strike(a, b)
		_dust -= delta
		if _dust <= 0.0:
			_dust = Balance.EARTH_PATTERN_DUST_INTERVAL
			if String(plan["mode"]) == "breath":
				pass
			else:
				Vfx.dust(head, Color(0.38, 0.29, 0.18), 5, float(plan["width"]) * 1.8)
				if String(plan["mode"]) == "trail":
					Vfx.impact(head, TowerData.Element.EARTH, Color(0.65, 0.49, 0.3), float(plan["width"]) * 1.5)
					Vfx.scar_dent(head, float(plan["width"]) * 0.7, Balance.SCAR_FISSURE_DEPTH * 0.6)
		_previous = head
	queue_redraw()
	if _elapsed > warning + travel + Balance.EARTH_PATTERN_FADE:
		queue_free()


## The far end walked toward whoever it chases, bounded in speed and in how
## far it may stray from where the breath was aimed.
func _chase(delta: float) -> void:
	var aimed: Vector2 = plan["to"] as Vector2
	# **The far end that catches the most it has not caught** (owner,
	# 2026-09-30), anywhere within the track's reach of where it was aimed;
	# the nearest Warden only when no line reaches anybody new.
	var origin: Vector2 = plan.get("origin", plan["from"]) as Vector2
	var span: float = origin.distance_to(aimed)
	if span > 1.0:
		var home: float = (aimed - origin).angle()
		var arc: float = atan2(Balance.DRAGON_BREATH_TRACK_REACH, span)
		# A wild dragon weighs everything living; a breath that is not wild
		# weighs the Wardens alone, as it always did.
		var best: float = INF
		if bool(plan.get("wild", false)):
			best = DragonBreath.best_line_among(DragonBreath.wild_marks(get_tree(), field,
				origin, span + float(plan["width"]), _hit, float(plan["share"])),
				origin, home, arc, span, float(plan["width"]), (_to - origin).angle())
		else:
			best = DragonBreath.best_line(get_tree(), origin, home, arc, span,
				float(plan["width"]), _hit, (_to - origin).angle())
		if best != INF:
			_to = _to.move_toward(origin + Vector2.from_angle(best) * span,
				delta * Balance.DRAGON_BREATH_TRACK_SPEED)
			return
	if _chasing == null or not is_instance_valid(_chasing) or not _chasing.is_inside_tree():
		_chasing = null
		return
	if _chasing is Hero and not (_chasing as Hero).is_alive():
		return
	var goal: Vector2 = _chasing.global_position
	var off: Vector2 = goal - aimed
	if off.length() > Balance.DRAGON_BREATH_TRACK_REACH:
		goal = aimed + off.normalized() * Balance.DRAGON_BREATH_TRACK_REACH
	_to = _to.move_toward(goal, delta * Balance.DRAGON_BREATH_TRACK_SPEED)


## The Warden nearest where a breath was aimed, outside the walls, or null.
func _nearest_warden(at: Vector2) -> Node2D:
	if field == null:
		return null
	var best: Node2D = null
	var nearest: float = Balance.DRAGON_BREATH_TRACK_REACH * 2.0
	for hero: Hero in field.heroes():
		if hero == null or not is_instance_valid(hero) or not hero.is_alive():
			continue
		if field.inside_city(hero.global_position):
			continue
		var apart: float = hero.global_position.distance_to(at)
		if apart < nearest:
			nearest = apart
			best = hero
	return best


## Where the beam ends now, for the picture.
func breath_end() -> Vector2:
	return _to


func _strike(a: Vector2, b: Vector2) -> void:
	var width: float = float(plan["width"])
	for hero: Hero in field.heroes():
		if hero == null or not hero.is_alive() or _hit.has(hero.get_instance_id()):
			continue
		if hero.global_position.distance_to(Geometry2D.get_closest_point_to_segment(
				hero.global_position, a, b)) > width:
			continue
		_hit[hero.get_instance_id()] = true
		if hero.health.accepts_damage():
			var damage: float = hero.health.max_hp * float(plan["share"])
			RunState.note_blow(String(plan["blame"]), damage)
			EarthHand.open()
			hero.health.take_damage(damage, a)
			EarthHand.close()
	if bool(plan.get("wild", false)):
		_strike_the_wild(a, b, width)
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower == null or _hit.has(tower.get_instance_id()):
			continue
		if tower.global_position.distance_to(Geometry2D.get_closest_point_to_segment(
				tower.global_position, a, b)) <= width:
			_hit[tower.get_instance_id()] = true
			tower.hurt(float(plan["tower_damage"]), a)


## **A wild dragon's breath takes everything on its line** (2026-10-01): the
## Wardens above, and here their spirits, every road and camp body and every
## animal - each once a breath. An animal it kills is the dragon's, and the
## earth counts it (`wildlife_fell`, "dragon").
func _strike_the_wild(a: Vector2, b: Vector2, width: float) -> void:
	var covers: Callable = func(at: Vector2) -> bool:
		return at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b)) <= width
	var hero_pool: float = field.hero.health.max_hp if field.hero != null and field.hero.health != null \
		else 100.0
	for node: Node in get_tree().get_nodes_in_group(Companion.GROUP):
		var pet := node as Companion
		if pet == null or not is_instance_valid(pet) or not pet.is_alive() or _hit.has(pet.get_instance_id()):
			continue
		if not bool(covers.call(pet.global_position)):
			continue
		_hit[pet.get_instance_id()] = true
		pet.take_damage(hero_pool * float(plan["share"]) * Balance.ENEMY_SHOT_SPIRIT_SHARE, a)
	for body: Enemy in field.living_bodies():
		if not is_instance_valid(body) or body.is_dying() or _hit.has(body.get_instance_id()):
			continue
		var reach: float = width + body.contact_radius()
		if body.global_position.distance_to(Geometry2D.get_closest_point_to_segment(
				body.global_position, a, b)) > reach:
			continue
		_hit[body.get_instance_id()] = true
		DamageLedger.credit_as(DamageLedger.EARTH)
		body.take_damage(DragonBreath.wild_blow(body.health.max_hp), a, 0.0)
	var wildlife: Wildlife = field.wildlife()
	if wildlife != null:
		wildlife.wound_where(covers, Balance.DRAGON_WILD_BEAST_SHARE, "dragon", _hit)


## **The earth breaks the same way wherever it breaks.**
##
## The warning was a translucent bar with two hard straight edges, and the
## split it opened was three polylines - and both read as paint on flat
## ground from the distance a disaster is actually watched. Photographed by
## `sky_shot`, where two of these crossing the field came out as a pair of
## gold rectangles.
##
## So it is drawn in the same language `GroundWave` settled on: the warning
## is hairline cracks reaching out from the line rather than a filled bar,
## and the split is **slabs with gaps between them**, each tapering to a
## point and ragged along its edge. The breath is untouched: it is a cone of
## fire rather than earth, and it is the one mode here that is not a crack.
func _draw_measured() -> void:
	var a: Vector2 = to_local(plan["from"] as Vector2)
	var b: Vector2 = to_local(_to)
	var width: float = float(plan["width"])
	var tint: Color = plan["tint"] as Color
	var warning: float = float(plan["warning"])
	var travel: float = float(plan["travel"])
	var fade: float = 1.0 - clampf((_elapsed - warning - travel) / Balance.EARTH_PATTERN_FADE, 0.0, 1.0)
	var side: Vector2 = (b - a).normalized().orthogonal() * width

	if _elapsed < warning:
		_draw_the_warning(a, b, side, width, tint, clampf(_elapsed / maxf(warning, 0.01), 0.0, 1.0))
		return

	# Boundary and damage use the same width, including the committed trail.
	draw_line(a + side, b + side, Color(tint, 0.16 * fade), 2.0, true)
	draw_line(a - side, b - side, Color(tint, 0.16 * fade), 2.0, true)

	if String(plan["mode"]) == "breath":
		return

	var end: Vector2 = b
	if String(plan["mode"]) == "trail":
		end = a.lerp(b, clampf((_elapsed - warning) / travel, 0.0, 1.0))
	_draw_the_split(a, end, side, width, fade)


## Hairline cracks reaching out from where the ground is about to give, and
## a dark seam growing along it. Never a filled bar: what the player has to
## read is *a line on the ground*, and a translucent rectangle over grass is
## the one shape that reads as a user interface rather than as earth.
func _draw_the_warning(a: Vector2, b: Vector2, side: Vector2, width: float,
		tint: Color, ready: float) -> void:
	var along: Vector2 = b - a
	draw_line(a, b, Color(0.07, 0.055, 0.045, 0.30 + 0.45 * ready),
		1.0 + 4.0 * ready, true)
	var steps: int = 18
	for index: int in steps:
		var t: float = (float(index) + 0.5) / float(steps)
		var root: Vector2 = a + along * t
		var lean: float = _hash01(float(index) * 4.7) - 0.5
		var reach: float = width * (0.35 + 0.75 * _hash01(float(index) * 9.1)) * ready
		var tip: Vector2 = (root + side.normalized() * reach * signf(lean)
			+ along.normalized() * lean * width * 0.4)
		draw_line(root, tip, Color(0.08, 0.06, 0.05, 0.22 + 0.42 * ready), 2.0, true)
	# And the two edges, so the shape of what is coming is still exact.
	draw_line(a + side, b + side, Color(tint, 0.30 + 0.34 * ready), 1.5, true)
	draw_line(a - side, b - side, Color(tint, 0.30 + 0.34 * ready), 1.5, true)


## The split itself: slabs of lifted earth either side of a dark seam.
func _draw_the_split(a: Vector2, b: Vector2, side: Vector2, width: float,
		fade: float) -> void:
	var along: Vector2 = b - a
	if along.length_squared() < 4.0:
		return
	var across: Vector2 = side.normalized()
	var steps: int = 14
	# The seam first, so every slab sits on a dark edge.
	var seam := PackedVector2Array()
	for index: int in steps + 1:
		var t: float = float(index) / float(steps)
		seam.append(a + along * t + across * (_hash01(float(index) * 3.3) - 0.5) * width * 0.35)
	draw_polyline(seam, Color(0.06, 0.05, 0.04, 0.82 * fade), width * 0.55, true)

	for index: int in steps:
		for hand: int in 2:
			var dice: float = _hash01(float(index) * 7.13 + float(hand) * 31.7)
			if dice > Balance.QUAKE_CREST_FILL:
				continue
			var dice2: float = _hash01(float(index) * 3.71 + float(hand) * 17.3 + 4.0)
			var t0: float = float(index) / float(steps)
			var t1: float = (float(index) + 0.6 + 0.5 * dice2) / float(steps)
			var lift: float = (1.0 if hand == 0 else -1.0)
			var thick: float = width * (0.30 + 0.40 * dice)
			var slab := PackedVector2Array()
			var ribs: int = 4
			for step: int in ribs + 1:
				var t: float = lerpf(t0, t1, float(step) / float(ribs))
				var pinch: float = sin(float(step) / float(ribs) * PI)
				var rag: float = 1.0 + (_hash01(float(index) * 5.0 + float(step) * 11.0) - 0.5) * 0.3
				slab.append(a + along * t + across * lift * (width * 0.22 + thick * pinch * rag))
			for step: int in range(1, ribs):
				var t: float = lerpf(t1, t0, float(step) / float(ribs))
				slab.append(a + along * t + across * lift * width * 0.20)
			draw_colored_polygon(slab,
				Color(0.44 + 0.10 * dice2, 0.33, 0.20, 0.92 * fade))
			draw_polyline(slab, Color(0.94, 0.80, 0.56, 0.55 * fade), 2.0, true)


## A stable 0..1 from a number, so a split breaks the same way on both
## machines and nothing here moves a roll the run depends on.
func _hash01(of: float) -> float:
	return absf(fmod(sin(of * 12.9898) * 43758.5453, 1.0))


## `FrameProfile` bucket "d_ground_hazard": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_ground_hazard", started)


## `FrameProfile` bucket "p_ground_hazard": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_ground_hazard", started)
