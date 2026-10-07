extends Node

## **Two marks that change a fight's shape** (triage of 2026-10-07):
## Leeching (`lifesteal`) and Riven (`split_on_death`).
##
## On a real field. A Leeching body's real swing on the Warden wins back its
## share of what the blow took, and a plain body's wins back nothing. A Riven
## body that falls comes apart into its pieces: of its own breed, a share of its
## pool, carrying on along its road where it fell, counted by the wave - and a
## piece that falls splits no further.

const TAG: String = "[mark-fields]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261007)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	if _field.town != null and _field.town.health != null:
		_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	await _test_leeching()
	await _test_riven()
	for stage: String in ["leeching", "riven"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: a leech wins back its share of a real blow and a plain body none, and a riven body comes apart into lesser pieces of itself on its own road that split no further" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _melee_breed() -> EnemyData:
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	for id: Variant in ids:
		var foe := ContentDB.enemies[id] as EnemyData
		if foe != null and foe.category == EnemyData.Category.BREED and foe.role != EnemyData.Role.HOWLER \
				and foe.variant_of.is_empty() and foe.contact_damage > 0.0:
			return foe
	return null


func _marked(data: EnemyData, mark_id: String) -> Enemy:
	var marks: Array[EnemyAffixData] = []
	var mark: EnemyAffixData = ContentDB.affixes.get(mark_id, null) as EnemyAffixData
	if mark != null:
		marks.append(mark)
	return _field.spawn_enemy(data, 0, 1.0, -1.0, 1.0, false, Enemy.Rank.COMMON, marks)


func _swing_at_the_warden(body: Enemy) -> float:
	var hero: Hero = _field.hero
	hero.health.current_hp = hero.health.max_hp
	body.global_position = hero.global_position + Vector2(40.0, 0.0)
	body.set("_target", hero)
	body.health.current_hp = body.health.max_hp * 0.5
	var before: float = body.health.current_hp
	var hero_before: float = hero.health.current_hp
	body.call("_strike")
	var taken: float = hero_before - hero.health.current_hp
	return (body.health.current_hp - before) / maxf(taken, 0.001) if taken > 0.0 else -1.0


func _test_leeching() -> void:
	var breed: EnemyData = _melee_breed()
	_check(breed != null and ContentDB.affixes.has("leeching"), "no melee breed or no Leeching mark")
	if breed == null or not ContentDB.affixes.has("leeching"):
		return
	var leech: Enemy = _marked(breed, "leeching")
	var plain: Enemy = _field.spawn_enemy(breed, 0, 1.0)
	await get_tree().process_frame
	leech.process_mode = Node.PROCESS_MODE_DISABLED
	plain.process_mode = Node.PROCESS_MODE_DISABLED
	var won: float = _swing_at_the_warden(leech)
	var share: float = (ContentDB.affixes["leeching"] as EnemyAffixData).lifesteal
	_check(won >= 0.0, "the leech's swing took nothing from the Warden")
	_check(absf(won - share) < 0.02, "a leech won back %.3f of its blow, not %.3f" % [won, share])
	var plain_won: float = _swing_at_the_warden(plain)
	_check(absf(plain_won) < 0.001, "a plain body won back %.3f of its blow" % plain_won)
	leech.queue_free()
	plain.queue_free()
	await get_tree().process_frame
	_reached.append("leeching")


func _pieces_of(data: EnemyData) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body != null and body.data == data and float(body.get("_split_share")) < 1.0:
			out.append(body)
	return out


func _test_riven() -> void:
	var breed: EnemyData = _melee_breed()
	var mark: EnemyAffixData = ContentDB.affixes.get("riven", null) as EnemyAffixData
	_check(breed != null and mark != null, "no melee breed or no Riven mark")
	if breed == null or mark == null:
		return
	var riven: Enemy = _marked(breed, "riven")
	await get_tree().process_frame
	riven.global_position = riven.route_point_at(0.45)
	var index: int = int(riven.get("_path_index"))
	# The parent's own pool, less what its mark added: what a piece is a share of.
	var whole: float = riven.health.max_hp / mark.health_scale
	var at: Vector2 = riven.global_position
	riven.health.take_damage(riven.health.max_hp * 10.0, at + Vector2(-60.0, 0.0))
	await get_tree().process_frame
	var pieces: Array[Enemy] = _pieces_of(breed)
	_check(pieces.size() == mark.split_on_death, "a riven body came apart into %d, not %d" % [pieces.size(), mark.split_on_death])
	for piece: Enemy in pieces:
		_check(absf(piece.health.max_hp - whole * Balance.MARK_SPLIT_HEALTH_SHARE) < 1.0,
			"a piece holds %.1f, not %.1f" % [piece.health.max_hp, whole * Balance.MARK_SPLIT_HEALTH_SHARE])
		_check(piece.global_position.distance_to(at) <= Balance.MARK_SPLIT_SPREAD + 2.0,
			"a piece stood %.0f from where its body fell" % piece.global_position.distance_to(at))
		_check(int(piece.get("_path_index")) == index, "a piece did not take up its body's road")
		_check(piece.affixes.is_empty(), "a piece wears a mark")
		_check(_field.holds_the_wave(piece),
			"a piece is not counted by the wave")
	if not pieces.is_empty():
		var before: int = get_tree().get_nodes_in_group(Enemy.GROUP).size()
		pieces[0].health.take_damage(pieces[0].health.max_hp * 10.0, pieces[0].global_position)
		await get_tree().process_frame
		_check(_pieces_of(breed).size() == pieces.size() - 1
				and get_tree().get_nodes_in_group(Enemy.GROUP).size() == before - 1,
			"a piece that fell split again")
	for piece: Enemy in _pieces_of(breed):
		piece.queue_free()
	await get_tree().process_frame
	_reached.append("riven")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
