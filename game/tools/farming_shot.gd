extends Node

## Photographs the Farmer's work: a wild crop with the hero beside it, then
## one plot through its stages - planted, growing, ripe - and a crop wilting
## on ground that is wrong for it. Diagnostic only, never a gate.
##
##   godot --path game res://tools/farming_shot.tscn
##
## Each frame lands in `user://` as `farming_shot_<what>.png`.

var _field: Battlefield = null
var _farm: Farming = null
var _hero: Hero = null


func _ready() -> void:
	RunState.reset(false, 20260914)
	RunState.terrain_id = "jungle"
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = run.get("battlefield") as Battlefield
	_farm = _field.farming() if _field != null else null
	_hero = _field.hero if _field != null else null
	if _farm == null or _hero == null:
		push_error("[farming] no farm or hero")
		get_tree().quit(1)
		return
	if _field.wave_director != null:
		_field.wave_director.stop()
	_field.sky().events_enabled = false
	var wild: int = -1
	var plots: Array[int] = []
	for index: int in _farm.plot_count():
		var state: Dictionary = _farm.plot_state(index)
		if bool(state["wild"]) and wild < 0:
			wild = index
		elif not bool(state["wild"]):
			plots.append(index)
	if wild >= 0:
		_stand_by(wild)
		await _shoot("wild", 40)
	if plots.size() >= 2:
		RunState.add_seeds("barley", 3)
		RunState.add_seeds("ember_pepper", 3)
		var first: int = plots[0]
		_stand_by(first)
		await _shoot("bare", 20)
		_farm.plant(first)
		_farm.grow_by(28.0)
		await _shoot("planted", 30)
		_farm.grow_by(70.0)
		await _shoot("growing", 30)
		_farm.grow_by(200.0)
		await _shoot("ripe", 60)
		# The pepper on jungle ground: wilting.
		RunState.seeds.clear()
		RunState.add_seeds("ember_pepper", 3)
		var second: int = plots[1]
		_stand_by(second)
		_farm.plant(second)
		_farm.grow_by(60.0)
		await _shoot("wilting", 30)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _stand_by(index: int) -> void:
	var at: Vector2 = _farm.plot_state(index)["at"]
	_hero.global_position = at + Vector2(64.0, 36.0)


func _shoot(what: String, settle_frames: int) -> void:
	for _f: int in settle_frames:
		await get_tree().process_frame
	var path: String = "user://farming_shot_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("[farming] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
