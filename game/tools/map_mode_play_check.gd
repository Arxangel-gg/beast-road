extends Node

## Every map mode, played: bodies walk every lane of each layout on the real
## field, and each one reaches the wall or dies on the way.
##
##   godot --headless --fixed-fps 60 --path game res://tools/map_mode_play_check.tscn
##
## `map_mode_check` walks the geometry: routes that are road, gates, mirrors,
## ground. That is the half a number can answer, and it cannot see a body
## steering round a corner of a layout it has never walked. This stands up the
## real run on each map, builds a real tower on its ground, sends three of the
## plainest breed down every lane, and insists each body arrives at the wall -
## or is killed on the way, which proves the same road - within a budget. A body
## that is neither is a body lost on that map, which is the "stuck enemy" report
## this project has chased four times.
##
## The field is kept quiet: no wildlife, no waves, the town and the Warden
## floored, so nothing but the road decides whether a body arrives.

const SEED: int = 20260923
const PER_LANE: int = 3
## The breed sent: Act I's plainest marcher, on the map every layout shares.
const BREED: String = "bogkin"
## Game seconds a mode's bodies have to arrive. The longest way in on any
## layout is about 3,300 units and a marcher walks about 40 a second; the rest
## is the budget a body stuck on a corner does not get.
const BUDGET_SECONDS: float = 150.0
## Near enough to the wall to be hitting it.
const AT_THE_WALL: float = 150.0
## Near enough to be in the queue at a gate. Twelve bodies converging on two or
## four gates stand in line behind the ones already swinging - Classic's own
## south gate holds three of them two hundred units out - and a body waiting its
## turn is not a body lost on the map. A body stuck on a corner is a thousand
## units out, not two hundred and fifty.
const AT_THE_GATE: float = 270.0

var _failures: Array[String] = []
var _struck: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	Engine.max_fps = 0
	EventBus.town_struck.connect(_on_town_struck)
	for mode: String in MapModes.ids():
		await _play(mode)
	for problem: String in _failures:
		push_error("[map-play] " + problem)
	print("[map-play] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	GameDirector.run_active = false
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 12:
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _on_town_struck(_from: Vector2) -> void:
	_struck += 1


func _play(mode: String) -> void:
	RunState.reset(false, SEED)
	RunState.map_mode = mode
	GameDirector.run_active = true
	var run := (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 24:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	_check(field != null, "%s: no battlefield stood up" % mode)
	if field == null:
		run.queue_free()
		return
	_check(field.grid.mode == mode, "%s: the field was laid as %s" % [mode, field.grid.mode])

	var animals: Node = field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	if field.wave_director != null:
		field.wave_director.stop()
	if field.town != null and field.town.health != null:
		field.town.health.floor_hp = field.town.health.max_hp * 0.2
	if field.hero != null and field.hero.health != null:
		field.hero.health.floor_hp = field.hero.health.max_hp * 0.5

	_check(_build_a_tower(field), "%s: no tower could be built on this map's ground" % mode)

	var data: EnemyData = ContentDB.enemies.get(BREED) as EnemyData
	_check(data != null, "no %s to send" % BREED)
	if data == null:
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	var bodies: Array[Enemy] = []
	var lanes: Array[int] = []
	for lane: int in Balance.LANE_COUNT:
		for _i: int in PER_LANE:
			var body: Enemy = field.spawn_enemy(data, lane, 1.0)
			if body != null:
				bodies.append(body)
				lanes.append(lane)
	_check(bodies.size() == Balance.LANE_COUNT * PER_LANE,
		"%s: only %d of %d bodies were sent" % [mode, bodies.size(), Balance.LANE_COUNT * PER_LANE])

	var struck_before: int = _struck
	var reached: Dictionary = {}
	var swinging: Dictionary = {}
	var clock: float = 0.0
	while clock < BUDGET_SECONDS:
		await get_tree().process_frame
		clock += get_process_delta_time()
		var waiting: int = 0
		for body: Enemy in bodies:
			if not _alive(body):
				continue
			var gap: float = _gap_to_wall(field, body.global_position)
			if gap <= AT_THE_GATE:
				reached[body.get_instance_id()] = true
			if gap <= AT_THE_WALL:
				swinging[lanes[bodies.find(body)]] = true
			if not reached.has(body.get_instance_id()):
				waiting += 1
		# Done when every body is at a gate and the wall has been hit: a queue
		# that formed and never swung is a queue standing in the wrong place.
		if waiting == 0 and _struck > struck_before:
			break

	var lost: Array[String] = []
	var died: int = 0
	for index: int in bodies.size():
		var body: Enemy = bodies[index]
		if not _alive(body):
			died += 1
			continue
		if not reached.has(body.get_instance_id()):
			lost.append("lane %d at %s, %.0f from the wall" % [lanes[index],
				body.global_position.round(), _gap_to_wall(field, body.global_position)])
	_check(lost.is_empty(), "%s: %d bodies never reached the wall in %.0fs - %s"
		% [mode, lost.size(), BUDGET_SECONDS, "; ".join(lost)])
	# Not "every lane swung": on a two-gate map three lanes share a gate, and the
	# bodies behind the first in line wait their turn rather than reach the wall.
	_check(not swinging.is_empty(), "%s: no body ever reached the wall itself" % mode)
	_check(_struck > struck_before or died > 0,
		"%s: nothing struck the wall and nothing died - the bodies went nowhere" % mode)
	print("[map-play] %s: %d bodies, %d at the wall, %d killed on the way, %d blows on the wall, %.0fs"
		% [mode, bodies.size(), reached.size(), died, _struck - struck_before, clock])

	run.queue_free()
	GameDirector.run_active = false
	for _frame: int in 8:
		await get_tree().process_frame


## One tower on the lane-0 pocket this map offers, bought through the real door.
func _build_a_tower(field: Battlefield) -> bool:
	RunState.gain_every_currency(100000)
	RunState.set_phase(RunState.Phase.PREPARATION)
	var tower: TowerData = ContentDB.towers.get("ember_spire") as TowerData
	if tower == null:
		return false
	for lane: int in Balance.LANE_COUNT:
		var centre: Vector2 = field.grid.lane_pocket_centre(lane)
		var anchor: Vector2i = BattleGrid.world_to_tile(
			centre - Vector2(BattleGrid.TILE, BattleGrid.TILE) * 0.5)
		if field.try_build(anchor, tower).is_empty():
			return true
	return false


func _alive(body: Enemy) -> bool:
	return is_instance_valid(body) and body.health != null and not body.health.is_dead


func _gap_to_wall(field: Battlefield, at: Vector2) -> float:
	var bounds: Rect2 = field.city_bounds()
	var edge := Vector2(clampf(at.x, bounds.position.x, bounds.end.x),
		clampf(at.y, bounds.position.y, bounds.end.y))
	return at.distance_to(edge)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
