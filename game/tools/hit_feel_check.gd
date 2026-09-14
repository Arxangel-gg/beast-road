extends Node

## What a blow lands on is felt: every breed names a hide, the roster has
## all three that make a sound, a swing that connects announces the hide of
## the body it struck, the hitstop it asks for is scaled by it, and the
## sound picked for it is the right one.
##
##   godot --headless --path game res://tools/hit_feel_check.tscn
##
## Driven through the real `HeroAttack._strike` against real bodies, because
## the failure this guards is a multiplier applied at the wrong site: a hide
## authored on every breed and read by nothing would pass a data walk.

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _landed_hide: int = -1
var _hitstop: float = -1.0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	_check(_field != null and _field.hero != null, "the battlefield must stand a hero up")
	_test_every_breed_names_a_hide()
	_test_the_sound_follows_the_hide()
	if _field != null and _field.hero != null:
		EventBus.hero_attack_landed.connect(_on_landed)
		EventBus.hitstop_requested.connect(_on_hitstop)
		await _test_a_swing_says_what_it_struck()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[hit-feel] PASS - %d checks: every breed has a hide, the sound follows it, "
			% _checks + "a swing names what it struck and holds the blade by it")
	else:
		for failure: String in _failures:
			push_error("[hit-feel] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _on_landed(_step: int, _targets: int, _at: Vector2, hide: int) -> void:
	_landed_hide = hide


func _on_hitstop(seconds: float) -> void:
	_hitstop = seconds


func _test_every_breed_names_a_hide() -> void:
	var seen: Dictionary = {}
	for value: Variant in ContentDB.enemies.values():
		var data := value as EnemyData
		if data == null:
			continue
		_check(data.hide >= EnemyData.Hide.FLESH and data.hide <= EnemyData.Hide.SPIRIT,
			"%s names a hide outside the enum (%d)" % [data.id, data.hide])
		seen[data.hide] = true
	for hide: int in [EnemyData.Hide.FLESH, EnemyData.Hide.ARMOUR, EnemyData.Hide.STONE]:
		_check(seen.has(hide), "no breed on the roster is of hide %d - a sound with nothing to make it" % hide)
	_check(Balance.HIDE_HITSTOP_SCALE.size() == EnemyData.Hide.size(),
		"HIDE_HITSTOP_SCALE has %d entries for %d hides" % [Balance.HIDE_HITSTOP_SCALE.size(), EnemyData.Hide.size()])
	_check(float(Balance.HIDE_HITSTOP_SCALE[EnemyData.Hide.ARMOUR]) > float(Balance.HIDE_HITSTOP_SCALE[EnemyData.Hide.FLESH]),
		"armour should hold the blade longer than flesh")
	_check(float(Balance.HIDE_HITSTOP_SCALE[EnemyData.Hide.SPIRIT]) < float(Balance.HIDE_HITSTOP_SCALE[EnemyData.Hide.FLESH]),
		"a spirit should hold the blade less than flesh")


func _test_the_sound_follows_the_hide() -> void:
	_check(Sfx.hit_group_for(EnemyData.Hide.ARMOUR) == "sfx_hit_armour", "armour does not ring")
	_check(Sfx.hit_group_for(EnemyData.Hide.STONE) == "sfx_hit_stone", "stone does not chip")
	_check(Sfx.hit_group_for(EnemyData.Hide.FLESH) == "sfx_hit_flesh", "flesh does not crack")
	for hide: int in EnemyData.Hide.size():
		_check(Sfx.GROUPS.has(Sfx.hit_group_for(hide)), "hide %d picks a sound group that does not exist" % hide)


## A swing on an armoured body and a swing on a fleshy one: each names its
## hide, and the hitstop between them differs by the authored scale.
func _test_a_swing_says_what_it_struck() -> void:
	var armoured: EnemyData = null
	var fleshy: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var data := value as EnemyData
		if data == null or data.category != EnemyData.Category.BREED:
			continue
		if data.hide == EnemyData.Hide.ARMOUR and armoured == null:
			armoured = data
		if data.hide == EnemyData.Hide.FLESH and fleshy == null:
			fleshy = data
	_check(armoured != null and fleshy != null, "an armoured breed and a fleshy one to swing at")
	if armoured == null or fleshy == null:
		return
	var results: Dictionary = {}
	for data: EnemyData in [armoured, fleshy]:
		var at: Vector2 = Vector2(600.0, 600.0)
		var body: Enemy = _field.spawn_enemy(data, 0, 40.0)
		body.global_position = at
		await get_tree().process_frame
		var attack: HeroAttack = _field.hero.attack
		_landed_hide = -1
		_hitstop = -1.0
		attack.set("_swing_origin", at + Vector2(-60.0, 0.0))
		attack.set("_swing_aim", Vector2.RIGHT)
		attack.set("_step", 0)
		attack.set("_hit_ids", {})
		attack.call("_strike")
		results[data.hide] = {"hide": _landed_hide, "hitstop": _hitstop}
		body.queue_free()
		await get_tree().process_frame
	var a: Dictionary = results[EnemyData.Hide.ARMOUR]
	var f: Dictionary = results[EnemyData.Hide.FLESH]
	_check(int(a["hide"]) == EnemyData.Hide.ARMOUR, "a swing on armour did not say armour (%d)" % int(a["hide"]))
	_check(int(f["hide"]) == EnemyData.Hide.FLESH, "a swing on flesh did not say flesh (%d)" % int(f["hide"]))
	_check(float(a["hitstop"]) > 0.0 and float(f["hitstop"]) > 0.0, "a connecting swing asked for no hitstop")
	var expected: float = float(Balance.HIDE_HITSTOP_SCALE[EnemyData.Hide.ARMOUR]) / float(Balance.HIDE_HITSTOP_SCALE[EnemyData.Hide.FLESH])
	_check(absf(float(a["hitstop"]) / maxf(float(f["hitstop"]), 0.0001) - expected) < 0.01,
		"armour's hitstop is %.3f against flesh's %.3f; the scale says %.2f" % [float(a["hitstop"]), float(f["hitstop"]), expected])
