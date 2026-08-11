class_name EnemySpawner
extends Node

## Stage 1's stand-in for waves.
##
## GDD §10 puts waves in Stage 2 and the WaveDirector with them, so this is
## deliberately not that: it is a continuous trickle that thickens over five
## minutes, just enough to give a session a shape and answer whether swinging is
## fun. When the WaveDirector arrives this script is replaced, not extended.

@export var enemy_scene: PackedScene

## The breed to spawn. A resource, not a branch — Stage 2 swaps this per terrain.
@export var enemy_data: EnemyData

## Where spawned enemies are parented. Kept separate from the spawner so the
## entity list is y-sorted independently of the systems that create it.
@export var entities_root: Node2D

@export var hero: Hero

## How many tries to find a spawn point far enough from the hero before giving
## up and using the point opposite them.
const PLACEMENT_ATTEMPTS: int = 8

var _elapsed: float = 0.0
var _next_spawn_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# Checked up front and once: a mis-wired NodePath here would otherwise only
	# show up as an error per spawn attempt, forever, starting a second and a
	# half in — long after a one-frame smoke test has exited.
	var missing: PackedStringArray = []
	if enemy_scene == null:
		missing.append("enemy_scene")
	if enemy_data == null:
		missing.append("enemy_data")
	if entities_root == null:
		missing.append("entities_root")
	if hero == null:
		missing.append("hero")
	if not missing.is_empty():
		push_error("EnemySpawner is missing: %s. Spawning disabled." % ", ".join(missing))
		set_process(false)
		return
	_next_spawn_left = Balance.SPAWN_INTERVAL_START


func _process(delta: float) -> void:
	_elapsed += delta
	_next_spawn_left -= delta
	if _next_spawn_left > 0.0:
		return

	var ramp: float = clampf(_elapsed / Balance.SPAWN_RAMP_SECONDS, 0.0, 1.0)
	_next_spawn_left = lerpf(Balance.SPAWN_INTERVAL_START, Balance.SPAWN_INTERVAL_END, ramp)

	var burst: int = int(round(lerpf(Balance.SPAWN_BURST_START, Balance.SPAWN_BURST_END, ramp)))
	for i: int in burst:
		if get_tree().get_node_count_in_group(Enemy.GROUP) >= Balance.SPAWN_MAX_ALIVE:
			return
		_spawn_one()


func _spawn_one() -> void:
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		push_error("enemy_scene did not instantiate an Enemy.")
		return
	enemy.setup(enemy_data, hero, hero.contact_radius() if hero != null else 0.0)
	enemy.position = _pick_spawn_point()
	entities_root.add_child(enemy)


## Somewhere on the spawn ring, but never right on top of the hero — that reads
## as the game cheating rather than as pressure.
func _pick_spawn_point() -> Vector2:
	var radius: float = Balance.ENEMY_SPAWN_RADIUS
	var hero_position: Vector2 = hero.global_position if hero != null else Vector2.ZERO
	for i: int in PLACEMENT_ATTEMPTS:
		var candidate: Vector2 = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * radius
		if candidate.distance_to(hero_position) >= Balance.SPAWN_MIN_DISTANCE_FROM_HERO:
			return candidate
	# The hero is standing on the ring. The far side is the best available spot.
	if hero_position.length() > 1.0:
		return -hero_position.normalized() * radius
	return Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * radius
