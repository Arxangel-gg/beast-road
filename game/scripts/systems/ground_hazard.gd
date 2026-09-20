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


func _ready() -> void:
	z_index = Balance.VFX_Z - 2
	_previous = plan["from"] as Vector2
	JuiceDirector.note(JuiceDirector.Priority.TELEGRAPH)


func _process(delta: float) -> void:
	_elapsed += delta
	var warning: float = float(plan["warning"])
	var travel: float = float(plan["travel"])
	var progress: float = clampf((_elapsed - warning) / maxf(travel, 0.001), 0.0, 1.0)
	var start: Vector2 = plan["from"] as Vector2
	var end: Vector2 = plan["to"] as Vector2
	var head: Vector2 = start.lerp(end, progress)
	if _elapsed >= warning and _elapsed <= warning + travel + delta:
		if not _erupted:
			_erupted = true
			if String(plan["mode"]) == "fissure":
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
				var mouth: Vector2 = plan.get("origin", start) as Vector2
				Vfx.spark(mouth, plan["tint"] as Color, 12,
					(end - mouth).normalized(), mouth.distance_to(end))
			else:
				Vfx.dust(head, Color(0.38, 0.29, 0.18), 5, float(plan["width"]) * 1.8)
				if String(plan["mode"]) == "trail":
					Vfx.impact(head, TowerData.Element.EARTH, Color(0.65, 0.49, 0.3), float(plan["width"]) * 1.5)
		_previous = head
	queue_redraw()
	if _elapsed > warning + travel + Balance.EARTH_PATTERN_FADE:
		queue_free()


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
			hero.health.take_damage(damage, a)
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower == null or _hit.has(tower.get_instance_id()):
			continue
		if tower.global_position.distance_to(Geometry2D.get_closest_point_to_segment(
				tower.global_position, a, b)) <= width:
			_hit[tower.get_instance_id()] = true
			tower.hurt(float(plan["tower_damage"]), a)


func _draw() -> void:
	var a: Vector2 = to_local(plan["from"] as Vector2)
	var b: Vector2 = to_local(plan["to"] as Vector2)
	var width: float = float(plan["width"])
	var tint: Color = plan["tint"] as Color
	var warning: float = float(plan["warning"])
	var travel: float = float(plan["travel"])
	var fade: float = 1.0 - clampf((_elapsed - warning - travel) / Balance.EARTH_PATTERN_FADE, 0.0, 1.0)
	var side: Vector2 = (b - a).normalized().orthogonal() * width
	# Boundary and damage use the same width, including the committed trail.
	var boundary_alpha: float = 0.7 if _elapsed < warning else 0.18
	draw_line(a + side, b + side, Color(tint, boundary_alpha * fade), 2.0, true)
	draw_line(a - side, b - side, Color(tint, boundary_alpha * fade), 2.0, true)
	if _elapsed < warning:
		draw_line(a, b, Color(tint, 0.12 + 0.16 * _elapsed / warning), width * 2.0, true)
		return
	var end: Vector2 = b
	if String(plan["mode"]) == "breath":
		var mouth: Vector2 = to_local(plan.get("origin", plan["from"]) as Vector2)
		draw_line(mouth, b, Color(tint, 0.48 * fade), width * 1.6, true)
		draw_line(mouth, b, Color(tint.lightened(0.6), 0.9 * fade), width * 0.35, true)
		return
	if String(plan["mode"]) == "trail":
		end = a.lerp(b, clampf((_elapsed - warning) / travel, 0.0, 1.0))
	var points := PackedVector2Array()
	for index: int in 25:
		var t: float = float(index) / 24.0
		var bend: float = sin(float(index) * 12.9898 + a.x * 0.01) * 0.3
		points.append(a.lerp(end, t) + side * bend)
	# A raised soil lip around a dark split, with fine branches into the ground.
	draw_polyline(points, Color(0.42, 0.30, 0.17, fade), 17.0, true)
	draw_polyline(points, Color(0.07, 0.055, 0.04, fade), 11.0, true)
	draw_polyline(points, Color(tint, 0.30 * fade), 1.0, true)
	for index: int in range(2, points.size() - 1, 3):
		var branch: Vector2 = points[index] + side * (0.7 if index % 2 == 0 else -0.7)
		draw_line(points[index], branch, Color(0.08, 0.06, 0.04, fade), 3.5, true)
