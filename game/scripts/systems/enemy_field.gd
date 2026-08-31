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


func _process(delta: float) -> void:
	# After the enemies have taken their own steps this frame, so the push
	# resolves the overlap they just created rather than one from last frame.
	separate_crowd(delta)


## Keeps bodies out of each other.
##
## **One pass over everything, not a query per enemy.** `enemies_near` walks the
## whole group, so asking it once per enemy is O(N squared) and a late wave is
## two hundred enemies. This buckets every body into a coarse grid once, then
## each body only looks at its own cell and the eight around it.
##
## A push rather than a physics body. Enemies are plain `Node2D`s that walk by
## adding a step to their position - giving several hundred of them collision
## shapes would be a rewrite with a frame budget attached, and it would fight the
## lane pathing besides. Displacing them after they have moved achieves the thing
## the player actually sees, which is that two bodies do not occupy one space.
##
## **Bosses are exempt, in both directions.** They neither push nor are pushed,
## so a boss walks through its own escort rather than shovelling it down the
## road - which is also what makes one read as unstoppable rather than as a
## large enemy.
##
## Nothing is pushed anywhere it could not have walked. The displacement is
## offered to `step_is_legal` exactly like a step, so separation cannot post a
## body through a cliff the pathing spent effort respecting.
func separate_crowd(delta: float) -> void:
	var bodies: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
			continue
		if enemy.ignores_crowd():
			continue
		bodies.append(enemy)
	if bodies.size() < 2 and get_tree().get_nodes_in_group(Hero.GROUP_ANY).is_empty():
		return

	var cell: float = Balance.CROWD_CELL
	var buckets: Dictionary = {}
	for index: int in bodies.size():
		var key: Vector2i = Vector2i((bodies[index].global_position / cell).floor())
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		var list: PackedInt32Array = buckets[key]
		list.append(index)
		buckets[key] = list

	var shove: Array[Vector2] = []
	shove.resize(bodies.size())
	for index: int in bodies.size():
		shove[index] = Vector2.ZERO

	for index: int in bodies.size():
		var here: Enemy = bodies[index]
		var at: Vector2 = here.global_position
		var mine: float = here.contact_radius()
		var origin: Vector2i = Vector2i((at / cell).floor())
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				var key: Vector2i = origin + Vector2i(dx, dy)
				if not buckets.has(key):
					continue
				for other_index: int in (buckets[key] as PackedInt32Array):
					# Each pair once: the higher index does the work for both.
					if other_index <= index:
						continue
					var other: Enemy = bodies[other_index]
					var apart: Vector2 = other.global_position - at
					var gap: float = mine + other.contact_radius()
					var distance: float = apart.length()
					if distance >= gap:
						continue
					# Exactly on top of each other has no direction, so one is
					# invented rather than dividing by zero.
					var push: Vector2 = apart / distance if distance > 0.001 						else Vector2.from_angle(float(index) * 2.399)
					var overlap: float = (gap - distance) * 0.5
					shove[index] -= push * overlap
					shove[other_index] += push * overlap

	# Heroes displace enemies and are not displaced themselves. A hero shoved
	# about by the crowd is a hero whose movement stopped answering their hands,
	# and that is worse than an overlap.
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero == null or not hero.is_alive():
			continue
		for index: int in bodies.size():
			var apart: Vector2 = bodies[index].global_position - hero.global_position
			var gap: float = Balance.HERO_BODY_RADIUS + bodies[index].contact_radius()
			var distance: float = apart.length()
			if distance >= gap:
				continue
			var push: Vector2 = apart / distance if distance > 0.001 				else Vector2.from_angle(float(index) * 2.399)
			shove[index] += push * (gap - distance)

	var most: float = Balance.CROWD_MAX_SHOVE * delta
	for index: int in bodies.size():
		var move: Vector2 = shove[index] * Balance.CROWD_STRENGTH
		if move.length() > most:
			move = move.normalized() * most
		if move.length_squared() < 0.0001:
			continue
		var wanted: Vector2 = bodies[index].global_position + move
		if step_is_legal(bodies[index].global_position, wanted):
			bodies[index].global_position = wanted


func enemies_near(point: Vector2, radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var radius_squared: float = radius * radius
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		# **Measured to the body, not the feet.** Depth sorting moved the enemy
		# node down to its ground contact point, and everything that asks "what
		# is near here" is asking about the body - a swing, an arrow, a tower's
		# target, a blast. Measuring to the feet made attacks miss unless they
		# were aimed at the floor, which is exactly how it was reported.
		#
		# Fixed here rather than at each caller because this is the one
		# broadphase they all share: towers, spells, arrows, barricades,
		# companions and wildlife every one of them arrive through this list.
		if enemy.combat_origin().distance_squared_to(point) <= radius_squared:
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
