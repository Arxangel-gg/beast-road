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


## Body radius of anything an enemy might walk up to and hit.
func target_radius(_node: Node2D) -> float:
	return 40.0


func lane_direction(_lane: int) -> Vector2:
	return Vector2.UP


## Only the battlefield has towers that can taunt.
func taunting_tower_in_lane(_lane: int) -> Node2D:
	return null


## A siege target for enemies authored to attack structures.
func vulnerable_tower_in_lane(_lane: int, _from: Vector2) -> Node2D:
	return null


func enemy_count() -> int:
	return get_tree().get_node_count_in_group(Enemy.GROUP)


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


func spawn_ground_zone(_at: Vector2, _dps: float, _duration: float, _radius: float) -> void:
	pass
