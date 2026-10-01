extends Node

## **What the earth does over a stretch of road** (2026-10-01).
##
## A report, like `curve_report`: the earth's anger is a curve too, and nothing
## had ever read it over more than the few seconds a gate holds a field for.
## `wrath_check` proves every rule the anger obeys; this asks what those rules
## add up to on a real road with real waves, real animals and a Warden doing
## what a player does - nothing to the animals at all, or hunting them.
##
## It stands the real run up at an act with a defended board (the same doors
## `perf_check` builds its late board through), parks the Warden in the town -
## out of every fight, so what kills animals is the road and the scripted hunt
## and nothing else - and lets the field run at `--speed=` for `--minutes=` of
## game time. Every game minute it prints the anger, the karma, how many
## animals were killed and how they fell, and what the earth sent.
##
##   godot --headless --path game res://tools/earth_soak.tscn -- --act=5 --minutes=20 --hunt=2
##
## `--hunt=` is harmless animals the Warden kills a game minute, through the
## door every blow on an animal goes through (`Wildlife.wound_sprite`); zero is
## a Warden who never lifts a hand to the wildlife. `--tier=` and `--seed=` as
## everywhere else.

const RUN_SCENE: String = "res://scenes/run/run.tscn"
const PerfCheck := preload("res://tools/perf_check.gd")

var _act: int = 5
var _minutes: float = 20.0
var _hunt: float = 0.0
var _speed: float = 4.0
var _seed: int = 20261001
var _tier: String = ""

var _run: Run = null
var _field: Battlefield = null
var _sky: WeatherSky = null
var _clock: float = 0.0
var _minute_left: float = 60.0
var _hunt_left: float = 0.0
var _started: bool = false
var _row: Dictionary = {}
var _total: Dictionary = {}
var _rows: int = 0
var _wrath_sum: float = 0.0
var _wrath_samples: int = 0
var _at_cap: float = 0.0
var _hunted: int = 0
var _last_sent: Dictionary = {}
var _first_sent: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--act="):
			_act = clampi(int(argument.trim_prefix("--act=")), 1, Balance.ACT_COUNT)
		elif argument.begins_with("--minutes="):
			_minutes = maxf(float(argument.trim_prefix("--minutes=")), 1.0)
		elif argument.begins_with("--hunt="):
			_hunt = maxf(float(argument.trim_prefix("--hunt=")), 0.0)
		elif argument.begins_with("--speed="):
			_speed = clampf(float(argument.trim_prefix("--speed=")), 1.0, 16.0)
		elif argument.begins_with("--seed="):
			_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--tier="):
			_tier = argument.trim_prefix("--tier=")
	RunState.reset(false, _seed)
	if not _tier.is_empty():
		RunState.tier_id = _tier
	PerfCheck.stage_late_act(_act)
	GameDirector.run_active = true
	_run = (load(RUN_SCENE) as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	_sky = _field.sky() if _field != null else null
	if _field == null or _sky == null:
		printerr("[earth] no battlefield or no sky to watch")
		get_tree().quit(1)
		return
	PerfCheck.build_late_board(_field, ContentDB.base_towers())
	# Nothing ends the soak but its clock: the town holds at half and the
	# Warden stands in the town, where no road body can see them.
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	for hero: Hero in _field.heroes():
		hero.global_position = _field.town.global_position
		hero.health.floor_hp = hero.health.max_hp
	_listen()
	_reset_row()
	_first_sent = _sent()
	Engine.time_scale = _speed
	_hunt_left = 60.0 / _hunt if _hunt > 0.0 else INF
	_started = true
	print("[earth] act %d, %s, %.0f game minutes at %.0fx, hunting %.1f a minute, seed %d" % [
		_act, RunState.tier().display_name, _minutes, _speed, _hunt, _seed])
	print("[earth]  min  wrath  karma  kills falls  quake fire funnel stone dragon strike  animals")


func _listen() -> void:
	EventBus.wildlife_killed.connect(func(_k: String, _f: int, _a: Vector2, _r: int, _s: bool, _g: bool) -> void:
		_bump("kills"))
	EventBus.wildlife_fell.connect(func(_k: String, _a: Vector2, rarity: int, _s: bool, cause: String) -> void:
		_bump("falls")
		_bump("fell_" + cause)
		_bump("rarity_%d" % rarity))
	EventBus.lightning_struck.connect(func(_a: Vector2, _r: float) -> void: _bump("strike"))


func _bump(key: String) -> void:
	_row[key] = int(_row.get(key, 0)) + 1
	_total[key] = int(_total.get(key, 0)) + 1


## The sky counts what it sends; a row is what it counted since the last.
func _sent() -> Dictionary:
	return {"quake": _sky.quakes, "fire": _sky.wildfires, "funnel": _sky.tornadoes,
		"stone": _sky.meteors, "dragon": _sky.dragons}


func _reset_row() -> void:
	_row = {}
	_last_sent = _sent()


func _process(delta: float) -> void:
	if not _started:
		return
	_clock += delta
	var anger: float = _sky.wrath()
	_wrath_sum += anger
	_wrath_samples += 1
	if anger >= Balance.WRATH_CAP - 0.01:
		_at_cap += delta
	_hunt_left -= delta
	if _hunt_left <= 0.0:
		_hunt_left += 60.0 / _hunt
		_hunt_one()
	_minute_left -= delta
	if _minute_left <= 0.0:
		_minute_left += 60.0
		_print_row()
	if _clock >= _minutes * 60.0:
		_finish()


## The nearest harmless animal to the town, through the door every blow on an
## animal takes.
func _hunt_one() -> void:
	var wild: Wildlife = _field.wildlife()
	if wild == null:
		return
	var best: Sprite2D = null
	var best_distance: float = INF
	for animal: Dictionary in wild.living():
		var kind := animal.get("data") as WildlifeData
		var sprite := animal.get("sprite") as Sprite2D
		if kind == null or kind.is_hostile() or sprite == null or not is_instance_valid(sprite):
			continue
		if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
			continue
		var distance: float = sprite.global_position.length()
		if distance < best_distance:
			best = sprite
			best_distance = distance
	if best != null and wild.wound_sprite(best, 1.0e6):
		_hunted += 1


func _print_row() -> void:
	_rows += 1
	var now: Dictionary = _sent()
	var sent: Dictionary = {}
	for key: String in now:
		sent[key] = int(now[key]) - int(_last_sent.get(key, 0))
	print("[earth] %4d  %5.2f  %+5.2f  %5d %5d  %5d %4d %6d %5d %6d %6d  %7d" % [
		_rows, _sky.wrath(), RunState.karma, int(_row.get("kills", 0)), int(_row.get("falls", 0)),
		sent["quake"], sent["fire"], sent["funnel"], sent["stone"], sent["dragon"],
		int(_row.get("strike", 0)),
		_field.wildlife().living().size() if _field.wildlife() != null else 0])
	_row = {}
	_last_sent = now


func _finish() -> void:
	_started = false
	Engine.time_scale = 1.0
	var hours: float = _clock / 3600.0
	var now: Dictionary = _sent()
	for key: String in now:
		_total[key] = int(now[key]) - int(_first_sent.get(key, 0))
	var line: PackedStringArray = []
	for key: String in ["kills", "falls", "quake", "fire", "funnel", "stone", "dragon", "strike"]:
		line.append("%s %.1f" % [key, float(_total.get(key, 0)) / maxf(hours, 0.001)])
	print("[earth] an hour of this road: %s" % ", ".join(line))
	var causes: PackedStringArray = []
	for key: String in _total:
		if key.begins_with("fell_") or key.begins_with("rarity_"):
			causes.append("%s %d" % [key, int(_total[key])])
	causes.sort()
	print("[earth] the fallen: %s" % ", ".join(causes))
	print("[earth] mean anger %.2f of %.1f, at the cap %.0f%% of the time, %d hunted, karma %+.2f" % [
		_wrath_sum / maxf(float(_wrath_samples), 1.0), Balance.WRATH_CAP,
		100.0 * _at_cap / maxf(_clock, 0.001), _hunted, RunState.karma])
	Sfx.stop_immediately()
	_run.queue_free()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(0)
