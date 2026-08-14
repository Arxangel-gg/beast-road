class_name RaidArena
extends EnemyField

## The raid (GDD §6.3). The battlefield is frozen exactly as it was; this is a
## place you went, not a timer you are paying.
##
## Musou-style horde: no lanes, no town, the hero is the only objective. The
## tension is the extraction window — every 30 seconds a door opens for three
## seconds. Take it and leave with a partial reward. Refuse it and the camp gets
## harder, until the chieftain comes out.

@export var enemy_scene: PackedScene
@export var ground: Sprite2D
@export var entity_root: Node2D
@export var effect_root: Node2D
@export var hero: Hero
@export var boundary: Line2D

## Each scope owns its camera; the run makes the right one current when the
## scope changes, so switching does not leave the view sitting in another scope.
@export var camera: Camera2D


func activate() -> void:
	if camera != null:
		camera.make_current()
	CursorKit.use_attack()

var _running: bool = false
var _elapsed: float = 0.0
var _spawn_timer: float = 0.0

var _window_timer: float = 0.0
var _window_left: float = 0.0
var _window_open: bool = false
var _refusals: int = 0
var _next_window: int = 0

var _kills: int = 0
var _chieftain: Enemy = null
var _chieftain_out: bool = false
var _finished: bool = false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng = RunState.rng("raids")
	_setup_ground()
	_setup_boundary()
	set_process(false)


func begin() -> void:
	# queue_free() resolves at frame end; a fast second entry must not inherit
	# targets from the failed camp while that deletion is still pending.
	_clear_enemies()
	_running = true
	_finished = false
	_elapsed = 0.0
	_kills = 0
	_refusals = 0
	_window_timer = Balance.RAID_EXTRACTION_WINDOWS[0]
	_window_left = 0.0
	_window_open = false
	_next_window = 0
	_chieftain = null
	_chieftain_out = false
	set_process(true)
	visible = true
	if hero != null:
		hero.field = self
		hero.sync_from_run_state()
		hero.set_active(true)
	Vfx.bind_world(effect_root if effect_root != null else self)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.raid_started.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta

	if not hero.is_alive() and not _finished:
		# Dying in the camp costs everything, including the meter.
		_finish({"partial": false, "died": true, "kills": _kills})
		return
	if _elapsed >= Balance.RAID_HARD_LIMIT and not _finished:
		_finish({"partial": true, "died": false, "kills": _kills, "timed_out": true})
		return

	_tick_windows(delta)
	_tick_spawning(delta)


# --- Extraction windows -----------------------------------------------------

func _tick_windows(delta: float) -> void:
	if _chieftain_out:
		return

	if _window_open:
		_window_left -= delta
		if _window_left <= 0.0:
			_window_open = false
			_refusals += 1
			_next_window += 1
			EventBus.raid_window_closed.emit()
			EventBus.raid_escalated.emit(_refusals)
		return

	if not _chieftain_out and _elapsed >= Balance.RAID_CHIEFTAIN_TIME:
		_spawn_chieftain()
		return
	if _next_window >= Balance.RAID_EXTRACTION_WINDOWS.size():
		_window_timer = maxf(Balance.RAID_CHIEFTAIN_TIME - _elapsed, 0.0)
		return
	_window_timer = maxf(Balance.RAID_EXTRACTION_WINDOWS[_next_window] - _elapsed, 0.0)
	if _window_timer <= 0.0:
		_window_open = true
		_window_left = Balance.RAID_WINDOW_DURATION
		EventBus.raid_window_opened.emit(Balance.RAID_WINDOW_DURATION)


func window_is_open() -> bool:
	return _window_open


func window_time_left() -> float:
	return maxf(_window_left, 0.0)


func time_to_next_window() -> float:
	return maxf(_window_timer, 0.0)


func refusals() -> int:
	return _refusals


func kills() -> int:
	return _kills


func chieftain_is_out() -> bool:
	return _chieftain_out


## Called by the HUD when the player takes an open window.
func extract() -> bool:
	if not _window_open or _finished:
		return false
	_finish({"partial": true, "died": false, "kills": _kills})
	return true


# --- Spawning ---------------------------------------------------------------

## Each refused window compounds the camp's strength — that is the whole
## push-your-luck curve.
func _escalation() -> float:
	return pow(1.0 + Balance.RAID_REFUSAL_ESCALATION, float(_refusals)) * RunState.enemy_escalation_multiplier()


func _tick_spawning(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = Balance.RAID_SPAWN_INTERVAL / maxf(1.0 + float(_refusals) * 0.4, 1.0)
	if enemy_count() >= Balance.RAID_MAX_ENEMIES:
		return
	var data: EnemyData = _pick_breed()
	if data != null:
		_spawn(data, _edge_point(), _escalation())


func _pick_breed() -> EnemyData:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		var pool: Array[EnemyData] = []
		for id: String in terrain.enemy_ids:
			var regional: EnemyData = ContentDB.enemy(id)
			if regional != null:
				pool.append(regional)
		if not pool.is_empty():
			return pool[_rng.randi_range(0, pool.size() - 1)]
		var breed: EnemyData = ContentDB.enemy(terrain.breed_id)
		if breed != null:
			return breed
	var breeds: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.BREED)
	return breeds[0] if not breeds.is_empty() else null


func _spawn(data: EnemyData, at: Vector2, scale: float) -> Enemy:
	var enemy := enemy_scene.instantiate() as Enemy
	if enemy == null:
		return null
	enemy.setup(data, 0, self, scale)
	enemy.position = at
	entity_root.add_child(enemy)
	return enemy


func _edge_point() -> Vector2:
	return Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU)) * Balance.RAID_ARENA_RADIUS


func _spawn_chieftain() -> void:
	if _chieftain_out:
		return
	_chieftain_out = true
	var elites: Array[EnemyData] = []
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		for id: String in terrain.elite_ids:
			var regional: EnemyData = ContentDB.enemy(id)
			if regional != null:
				elites.append(regional)
	if elites.is_empty():
		elites = ContentDB.enemies_of_category(EnemyData.Category.ELITE)
	var data: EnemyData = elites[_rng.randi_range(0, elites.size() - 1)] if not elites.is_empty() else _pick_breed()
	if data == null:
		return
	_chieftain = _spawn(data, _edge_point(), _escalation() * 4.0)
	EventBus.chieftain_spawned.emit(_captive_id())
	EventBus.camera_shake_requested.emit(14.0, 0.6)


## The captive this camp yields, keyed off the terrain rather than the elite
## that happened to be standing in for the chieftain.
func _captive_id() -> String:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	return terrain.breed_id if terrain != null else ""


func _on_enemy_died(_id: String, _at: Vector2) -> void:
	_kills += 1
	if _chieftain_out and (_chieftain == null or not is_instance_valid(_chieftain) or _chieftain.is_dying()):
		if not _finished:
			_finish({"partial": false, "died": false, "kills": _kills, "chieftain": true})


# --- Ending -----------------------------------------------------------------

func _finish(result: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	_running = false
	set_process(false)
	if hero != null:
		hero.set_active(false)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)

	var reward: Dictionary = _build_reward(result)
	_clear_enemies()
	EventBus.raid_ended.emit(reward)


func _build_reward(result: Dictionary) -> Dictionary:
	var reward: Dictionary = {
		"kills": int(result.get("kills", 0)),
		"died": bool(result.get("died", false)),
		"partial": bool(result.get("partial", false)),
		"timed_out": bool(result.get("timed_out", false)),
		"leader_resolution": "",
		"resources": 0,
		"captive_id": "",
		"relic_id": "",
	}
	if bool(result.get("died", false)):
		return reward

	if bool(result.get("chieftain", false)):
		# Full clear defaults to the Oath resolution until the dedicated outcome
		# chooser lands; this keeps the current one-click reward path save-safe.
		reward["resources"] = 200
		reward["captive_id"] = _captive_id()
		reward["leader_resolution"] = Balance.LEADER_RESOLUTIONS[0]
		reward["relic_id"] = _pick_relic()
		RunState.raids_completed += 1
		return reward

	# Partial extraction scales with how much damage was actually done.
	var ratio: float = clampf(float(reward["kills"]) / float(Balance.RAID_PARTIAL_REWARD_KILLS), 0.0, 1.0)
	reward["resources"] = int(round(160.0 * ratio))
	RunState.raids_completed += 1
	return reward


func _pick_relic() -> String:
	var ids: Array[String] = []
	for value: Variant in ContentDB.relics.values():
		var relic := value as RelicData
		if relic != null and not relic.is_boss_core and relic.region == RunState.act \
				and not RunState.held_relics.has(relic.id) \
				and not RunState.socketed_relics.has(relic.id):
			ids.append(relic.id)
	if ids.is_empty():
		return ""
	ids.sort()
	return ids[_rng.randi_range(0, ids.size() - 1)]


func _clear_enemies() -> void:
	# Enemy.GROUP is global and the frozen battlefield still owns its formation.
	# Clearing the whole SceneTree made a raid silently erase every road enemy,
	# contradicting the exact-resume contract. Only this arena's descendants go.
	if entity_root == null:
		return
	for node: Node in entity_root.get_children():
		if node.is_in_group(Enemy.GROUP):
			node.queue_free()


# --- EnemyField overrides ---------------------------------------------------

func hero_node() -> Node2D:
	return hero


func hero_is_alive() -> bool:
	return hero != null and hero.is_alive()


func target_radius(node: Node2D) -> float:
	return hero.contact_radius() if node == hero else 40.0


func spawn_tracer(from: Vector2, to: Vector2, colour: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = colour
	effect_root.add_child(line)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.tween_callback(line.queue_free)


func _setup_ground() -> void:
	if ground == null:
		return
	var extent: float = Balance.RAID_ARENA_RADIUS * 1.3
	ground.centered = true
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.material = TerrainSeam.material()
	ground.region_enabled = true
	ground.region_rect = Rect2(-extent, -extent, extent * 2.0, extent * 2.0)


func _setup_boundary() -> void:
	if boundary == null:
		return
	var points: PackedVector2Array = []
	for i: int in 97:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 96.0) * Balance.RAID_ARENA_RADIUS)
	boundary.points = points
	boundary.closed = true
	boundary.width = 5.0
	boundary.default_color = Color(0.75, 0.25, 0.22, 0.45)
