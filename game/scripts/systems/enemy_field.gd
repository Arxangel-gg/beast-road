class_name EnemyField
extends Node2D

## What an Enemy needs from the place it is standing in.
##
## Both the battlefield and the raid arena are full of enemies, but they are
## otherwise nothing alike: one has lanes, towers and a town to protect, the
## other is an open arena with only the hero in it. Rather than teach Enemy
## about both, each scope answers the same handful of questions.
##
## Defaults here describe an open arena with no lanes and no town, which is
## exactly the raid; Battlefield overrides the parts that differ.

func town_position() -> Vector2:
	return Vector2.ZERO


## The thing enemies walk toward when nothing better is in reach. Null means
## "there is no objective but the hero".
func town_node() -> Node2D:
	return null


func hero_node() -> Node2D:
	return null


func hero_is_alive() -> bool:
	return false


## The closest living hero to a point, of however many there are.
##
## Distinct from `hero_node()`, and the difference is the whole of co-op being
## playable. `hero_node()` means *this machine's player* — the camera follows it,
## the HUD describes it. An enemy has no such attachment: it should walk at
## whichever hero is nearer, and asking it the local one made every enemy in a
## two-player game ignore the guest completely.
func nearest_hero(_from: Vector2) -> Node2D:
	return null


## Body radius of anything an enemy might walk up to and hit.
func target_radius(_node: Node2D) -> float:
	return 40.0


func lane_direction(_lane: int) -> Vector2:
	return Vector2.UP


## The way in an enemy should take from this lane's spawn.
##
## Declared here rather than only on Battlefield because Enemy calls it on the
## field it was given, and the raid arena hands it this base class. It used to
## reach `lane_path` the same way, which happened to work only because the raid
## never spawns anything that looks for a road - a latent break waiting for the
## first raid enemy that did.
##
## The default is the arena's honest answer: no roads, walk at the objective.
func lane_route(_lane: int) -> PackedVector2Array:
	return PackedVector2Array()


## Only the battlefield has towers that can taunt.
func taunting_tower_in_lane(_lane: int) -> Node2D:
	return null


## A siege target for enemies authored to attack structures.
func vulnerable_tower_in_lane(_lane: int, _from: Vector2) -> Node2D:
	return null


## The barricade an enemy is about to walk into, if any.
##
## Asked with a **heading**, not a lane, and that correction is the whole reason
## barricades did not work. A wall's lane was derived from its angular position
## around the town - but the roads bend, so a wall standing on lane 0's road can
## sit at an angle that reads as lane 1, and the filter then matched nothing. The
## enemies walked straight past it.
##
## A heading has no such problem: whatever the road is doing, a wall is in the
## way if it is in front of you and close. That also handles an enemy halfway
## round a U-bend, which a lane index cannot describe at all.
func blocking_barricade_ahead(_from: Vector2, _heading: Vector2) -> Node2D:
	return null


## Enemies that can still fight.
##
## Deliberately not `get_node_count_in_group`. A wave ends when this reaches
## zero, and the raw group count includes enemies part way through a death
## animation and any that have been freed but not yet removed from the tree - so
## the last kill of a wave held it open for as long as the corpse lasted, and
## anything that failed to finish dying held it open forever.
func enemy_count() -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dying():
			total += 1
	return total


## Who is keeping a wave open, for the watchdog's report.
func living_enemy_summary() -> String:
	var names: PackedStringArray = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
			continue
		names.append("%s on road %d at %.0f,%.0f" % [
			enemy.data.id if enemy.data != null else "?", enemy.lane,
			enemy.global_position.x, enemy.global_position.y])
	return ", ".join(names) if not names.is_empty() else "nothing"


func enemies_near(point: Vector2, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var radius_squared: float = radius * radius
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		if enemy.global_position.distance_squared_to(point) <= radius_squared:
			found.append(enemy)
	return found


## Placeholder VFX hooks. Overridden where there is somewhere to put them.
func spawn_tracer(_from: Vector2, _to: Vector2, _colour: Color) -> void:
	pass


## Drops collectable loot. Both scopes pay; the base is for anything that does
## not.
func spawn_loot(_currency: String, _amount: int, _at: Vector2) -> void:
	pass


## Drops persistent gear. Battlefield overrides this; raids award gear through
## authored chests so a camp route retains its own reward rhythm.
func spawn_gear(_piece: Dictionary, _at: Vector2) -> void:
	pass


## Whether a body may move between two points. Open ground says yes to
## everything; the raid camp has cliffs and answers properly.
func step_is_legal(_from: Vector2, _to: Vector2) -> bool:
	return true


func spawn_ground_zone(_at: Vector2, _dps: float, _duration: float, _radius: float) -> void:
	pass
