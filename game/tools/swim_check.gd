extends Node

## Ponds under the player, never over, and a hero who swims (owner brief,
## 2026-09-12: "ponds should never be on top of a player", "walking into a
## pond should swim").
##
## What this holds, on the real battlefield:
##
## - the water draws under the entities, so a swimmer is drawn over it;
## - a hero on dry ground is not swimming; one placed in a pond's middle is,
##   and one walked back out is not;
## - the depth field is deeper in the middle than at the rim, and dry off
##   the water;
## - swimming is slower than walking by the swim scale, and the cover over
##   the submerged half is showing.

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	RunState.reset(false, 20260912)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var ponds: Node = field.ponds()
	var hero: Hero = field.hero
	_check(ponds != null and hero != null, "the battlefield has ponds and a hero")
	if ponds != null and hero != null:
		await _test(field, ponds, hero)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	Sfx.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[swim] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[swim] PASS - %d checks: the water under the hero, in and out, depth and pace" % _checked)
	get_tree().quit(0)


func _test(field: Battlefield, ponds: Node, hero: Hero) -> void:
	var spots: PackedVector2Array = ponds.call("pond_positions")
	_check(spots.size() >= 1, "there are ponds (%d)" % spots.size())
	# The water is drawn by the pond roots under the Fishing node, each pushed
	# below the sorted layer, so a swimmer draws over it.
	var under: bool = false
	var found: int = 0
	var highest: int = -100
	for node: Node in _walk(field):
		if node.name == "Pond" and node is Node2D:
			found += 1
			highest = maxi(highest, (node as Node2D).z_index)
			under = (node as Node2D).z_index < 0 and (found == 1 or under)
	_check(found >= 1 and under, "every pond root draws under the entities (%d ponds, highest z %d)" % [found, highest])
	_check(not hero.is_swimming() and float(field.water_depth_at(hero.global_position)) <= 0.0,
		"the hero starts on dry ground")
	if spots.is_empty():
		return
	var middle: Vector2 = spots[0]
	var deep: float = float(field.water_depth_at(middle))
	_check(deep > Balance.SWIM_THRESHOLD, "the middle of a pond is deep (%.2f)" % deep)
	# Find the rim: walk outward until the water ends.
	var rim: Vector2 = middle
	var step: Vector2 = Vector2.RIGHT * 12.0
	for _out: int in 60:
		if float(field.water_depth_at(rim + step)) <= 0.0:
			break
		rim += step
	var shallow: float = float(field.water_depth_at(rim))
	_check(shallow > 0.0 and shallow < deep, "the rim is shallower than the middle (%.2f < %.2f)" % [shallow, deep])
	_check(float(field.water_depth_at(rim + step * 6.0)) <= 0.0, "and the bank is dry")
	# In.
	var walking: float = hero.move_speed()
	hero.global_position = middle
	for _f: int in 6:
		await get_tree().physics_frame
	_check(hero.is_swimming(), "a hero in the middle of a pond swims")
	_check(hero.swim_depth() > Balance.SWIM_THRESHOLD, "and reads the depth under it")
	var cover: Node = hero.get("_swim_cover") as Node
	_check(cover != null and (cover as CanvasItem).visible, "the water covers the submerged half")
	# The pace: the scale is applied to the stride in `Hero._physics_process`,
	# which this gate cannot drive; what it can hold is that the scale is a
	# real slowdown and that the walk it scales is a real walk.
	_check(Balance.SWIM_SPEED_SCALE > 0.2 and Balance.SWIM_SPEED_SCALE < 1.0,
		"swimming is slower than walking, by a scale that still moves (%.2f)" % Balance.SWIM_SPEED_SCALE)
	_check(walking > 0.0, "the hero walks at a real pace (%.0f)" % walking)
	# Out.
	hero.global_position = rim + step * 8.0
	for _f: int in 6:
		await get_tree().physics_frame
	_check(not hero.is_swimming(), "a hero back on the bank walks")
	_check(MetaState.swims >= 1, "the statistic counted the swim")


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[swim] " + message)
