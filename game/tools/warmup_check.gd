extends Node

## The act is warm before it is fought: after the warm-up, every frame the
## act's roster can draw is already in the loader's cache, and so is every
## wildlife frame and every shader; and the real battlefield does the
## warming itself when it lays the region out.
##
##   godot --headless --path game res://tools/warmup_check.tscn
##
## The failure this guards is a breed the warm-up forgot - an elite dealt
## from the wider pool, a boss, an animal - whose first spawn loads thirteen
## frames from disk in the middle of a wave.

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	_test_the_roster_is_warm()
	_test_the_shaders_load()
	await _test_the_field_warms_itself()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[warmup] PASS - %d checks: the roster, the animals, the towers and the shaders "
			% _checks + "are loaded before the act, and the field does it itself")
	else:
		for failure: String in _failures:
			push_error("[warmup] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _frames_of(path: String) -> PackedStringArray:
	var out: PackedStringArray = [path]
	for index: int in range(1, 9):
		for state: String in ["idle", "move", "attack", "fly", "graze"]:
			var frame: String = "%s_%s_%02d.png" % [path.get_basename(), state, index]
			if ResourceLoader.exists(frame):
				out.append(frame)
	return out


## Warm: loaded by the warm-up, and a load now hands back that same
## instance - which is the loader's cache working, and the whole point.
func _warm(frame: String) -> bool:
	if not RosterWarmup.warmed.has(frame):
		return false
	return load(frame) == RosterWarmup.warmed[frame]


func _test_the_roster_is_warm() -> void:
	var terrain_id: String = RunState.terrain_id
	var terrain: TerrainData = ContentDB.terrain(terrain_id)
	_check(terrain != null, "the run's terrain is known")
	if terrain == null:
		return
	var loaded: int = RosterWarmup.warm_act(RunState.act, terrain_id)
	_check(loaded > 100, "the warm-up loaded %d textures, which is not an act" % loaded)
	var ids: Array[String] = []
	ids.append_array(terrain.enemy_ids)
	ids.append_array(terrain.elite_ids)
	if not terrain.boss_id.is_empty():
		ids.append(terrain.boss_id)
	for data: EnemyData in ContentDB.enemies_of_category(EnemyData.Category.ELITE):
		ids.append(data.id)
	var cold: PackedStringArray = []
	for id: String in ids:
		var data: EnemyData = ContentDB.enemy(id)
		if data == null:
			continue
		for frame: String in _frames_of(data.get_sprite_path()):
			if not _warm(frame):
				cold.append(frame)
	_check(cold.is_empty(), "%d roster frames are cold after the warm-up, e.g. %s" % [cold.size(), cold[0] if not cold.is_empty() else ""])
	cold.clear()
	for kind: WildlifeData in ContentDB.wildlife():
		if kind == null or kind.roll_weight(RunState.act) <= 0.0:
			continue
		for frame: String in _frames_of(kind.get_sprite_path()):
			if not _warm(frame):
				cold.append(frame)
	_check(cold.is_empty(), "%d wildlife frames are cold after the warm-up, e.g. %s" % [cold.size(), cold[0] if not cold.is_empty() else ""])
	cold.clear()
	for value: Variant in ContentDB.towers.values():
		var tower := value as TowerData
		if tower == null:
			continue
		for frame: String in _frames_of(tower.get_sprite_path()):
			if not _warm(frame):
				cold.append(frame)
	_check(cold.is_empty(), "%d tower frames are cold after the warm-up, e.g. %s" % [cold.size(), cold[0] if not cold.is_empty() else ""])


func _test_the_shaders_load() -> void:
	var count: int = RosterWarmup.warm_shaders(self)
	_check(count >= 10, "only %d shaders were warmed" % count)


## The battlefield warms the act when it lays the region out, so nothing
## has to remember to call it.
func _test_the_field_warms_itself() -> void:
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.get("battlefield") as Battlefield
	_check(field != null, "the run stands a battlefield up")
	if field != null:
		_check(field.warmed_textures > 100, "the field warmed %d textures on its own" % field.warmed_textures)
	run.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
