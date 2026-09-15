extends Node

## Every tower has a look of its own, and the look is never a fact.
##
## The owner's brief of 2026-09-14: "ensure all towers including the newest
## additions all have game juice vfx catered to each tower". Each tower authors
## a shot style, an air, a colour and a kick (`TowerData.shot`, `ambient`,
## `shot_tint`, `juice_scale`). The bound that makes this safe to author freely
## is that none of it moves a number the fight reads: a lobbed shot is drawn on
## an arc and *hits on the ground*, a lance is a streak at the same speed, a
## spray's pellets touch nothing, a chain's jitter is in the ribbon and not in
## the flight. So this gate reads the data for sense, then builds one tower of
## every style on the real field, fires it at a body, and reads the damage
## back - the shot's own, and the body's health after it lands.
##
## Two ways this could be a lie, and both are held: a style authored on a tower
## whose role it does not suit (a sniper that lobs), and an air or a style that
## nothing in the roster uses, which is a feature that silently never appears.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260914)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	RunState.gain_every_currency(20000)

	_test_every_tower_authors_a_look()
	_test_every_look_is_worn()
	await _test_every_style_lands_the_same_hit()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[tower-juice] PASS - %d checks: every tower's look, and every style the same hit" % _checks)
	else:
		push_error("[tower-juice] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[tower-juice] FAIL: %s" % why)


## The data reads as sense: a kick in its range, an opaque colour, a style that
## suits the role. A sniper draws a streak and a siege piece throws something
## heavy; a well, which never fires, still has an air of its own.
func _test_every_tower_authors_a_look() -> void:
	for id: Variant in ContentDB.towers:
		var tower: TowerData = ContentDB.towers[id] as TowerData
		if tower == null:
			continue
		_check(tower.juice_scale >= 0.5 and tower.juice_scale <= 2.0,
			"%s: juice_scale %.2f is outside 0.5..2.0" % [tower.id, tower.juice_scale])
		_check(tower.shot_colour().a >= 0.999,
			"%s: the shot colour must be opaque" % tower.id)
		_check(is_zero_approx(tower.shot_tint.a) or tower.shot_tint.a >= 0.999,
			"%s: a shot tint is either absent or whole" % tower.id)
		if tower.is_well():
			_check(int(tower.ambient) != TowerData.Ambient.ELEMENT,
				"%s: a well never fires, so its air is the only look it has - author one" % tower.id)
			continue
		match int(tower.role):
			TowerData.Role.SNIPER:
				_check(int(tower.shot) == TowerData.Shot.LANCE,
					"%s: a sniper draws a lance, not %s" % [tower.id, TowerData.shot_name(tower.shot)])
			TowerData.Role.SIEGE:
				_check(int(tower.shot) in [TowerData.Shot.LOB, TowerData.Shot.SPRAY, TowerData.Shot.CHAIN],
					"%s: a siege piece throws something heavy, not a %s" % [tower.id, TowerData.shot_name(tower.shot)])
			_:
				pass


## Every style and every authored air is worn by somebody. An enum arm nothing
## uses is code that has never been seen running.
func _test_every_look_is_worn() -> void:
	var styles: Dictionary = {}
	var airs: Dictionary = {}
	for id: Variant in ContentDB.towers:
		var tower: TowerData = ContentDB.towers[id] as TowerData
		if tower == null:
			continue
		styles[int(tower.shot)] = true
		airs[int(tower.ambient)] = true
	for style: int in [TowerData.Shot.BOLT, TowerData.Shot.LOB, TowerData.Shot.LANCE,
			TowerData.Shot.SPRAY, TowerData.Shot.CHAIN]:
		_check(styles.has(style), "no tower draws a %s" % TowerData.shot_name(style))
	for air: int in [TowerData.Ambient.EMBERS, TowerData.Ambient.SMOKE, TowerData.Ambient.DRIPS,
			TowerData.Ambient.FROST, TowerData.Ambient.GRIT, TowerData.Ambient.MOTES,
			TowerData.Ambient.GUSTS, TowerData.Ambient.SPARKS, TowerData.Ambient.GLINTS]:
		_check(airs.has(air), "no tower authors air %d" % air)


## One tower of each style, built on the real field and fired at a body that
## stands still: the shot carries the tower's own damage, the tower's air is
## the one it authored, and the body is hurt when the shot lands - on the
## ground, whatever the picture did in the air.
func _test_every_style_lands_the_same_hit() -> void:
	if _field == null or _field.wave_director == null:
		_check(false, "the harness needs a battlefield")
		return
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var breed: EnemyData = ContentDB.enemy("bogkin")
	if breed == null:
		_check(false, "the harness needs a breed to shoot at")
		return
	var lane: int = 0
	for style: int in [TowerData.Shot.BOLT, TowerData.Shot.LOB, TowerData.Shot.LANCE,
			TowerData.Shot.SPRAY, TowerData.Shot.CHAIN]:
		var data: TowerData = _tower_of(style)
		if data == null:
			_check(false, "no tower of style %s to build" % TowerData.shot_name(style))
			continue
		RunState.set_phase(RunState.Phase.PREPARATION)
		var anchor: Vector2i = _field.free_anchor_near(lane, 8)
		var problem: String = _field.try_build(anchor, data)
		_check(problem.is_empty(), "%s: must build (%s)" % [data.id, problem])
		if not problem.is_empty():
			continue
		await get_tree().process_frame
		var tower: Tower = _tower_at(anchor)
		_check(tower != null, "%s: the built tower must stand on the field" % data.id)
		if tower == null:
			continue
		var aura: TowerAura = tower.get_node_or_null("Aura") as TowerAura
		_check(aura != null, "%s: a tower carries its air" % data.id)
		if aura != null:
			var wanted: int = int(data.ambient)
			if wanted == TowerData.Ambient.ELEMENT:
				wanted = _default_air(int(data.element))
			_check(aura.built_kind() == wanted,
				"%s: authored air %d, built %d" % [data.id, wanted, aura.built_kind()])

		# A body a little way off, standing still, with a pool the shot cannot empty.
		var body: Enemy = _field.spawn_enemy(breed, lane, 60.0, -1.0, 0.001)
		_check(body != null, "%s: the harness needs a body" % data.id)
		if body == null:
			continue
		body.global_position = tower.origin() + Vector2(tower.effective_range() * 0.8, 0.0)
		RunState.set_phase(RunState.Phase.ROAD_BATTLE)
		# Preparation freezes the effect root and the Ride button thaws it; the
		# harness thaws it itself, without starting the waves.
		_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
		var before: float = body.health.current_hp
		# **The shot is caught as it is born and read as it dies**, never polled:
		# a headless frame can be a quarter of a second, and a shot that lands
		# inside one frame was never there to be polled for.
		var record: Dictionary = {"seen": false, "style": -1, "damage": 0.0, "peak": 0.0, "shadow": false}
		var born: Callable = func(node: Node) -> void:
			var shot := node as Projectile
			if shot == null or shot.data != data or record["seen"]:
				return
			record["seen"] = true
			record["style"] = shot.style()
			record["damage"] = shot.damage
			shot.tree_exiting.connect(func() -> void:
				record["peak"] = shot.peak_lift()
				record["shadow"] = shot.has_shadow())
		_field.effect_root.child_entered_tree.connect(born)
		# Frames rather than seconds, because a headless frame is a few
		# milliseconds and a windowed one sixteen: enough of either for the
		# tower's first cooldown and the shot's whole flight.
		for _frame: int in 1200:
			await get_tree().process_frame
			if record["seen"] and body.health.current_hp < before:
				break
		_field.effect_root.child_entered_tree.disconnect(born)
		_check(record["seen"], "%s: the tower must fire at a body in reach" % data.id)
		if record["seen"]:
			_check(int(record["style"]) == style,
				"%s: the shot must wear the tower's style" % data.id)
			var span: Vector2 = TowerData.damage_range(tower.effective_damage())
			var dealt: float = float(record["damage"])
			_check(dealt >= span.x - 0.01 and dealt <= span.y + 0.01,
				"%s: the shot carries the tower's own damage (%.1f in %s)" % [data.id, dealt, str(span)])
		_check(body.health.current_hp < before,
			"%s: the shot must land on the body whatever the picture did (%.1f -> %.1f)"
			% [data.id, before, body.health.current_hp])
		if style == TowerData.Shot.LOB:
			_check(float(record["peak"]) > 4.0, "%s: a lob rises off its path in the air" % data.id)
			_check(bool(record["shadow"]), "%s: a lob throws a shadow on the ground" % data.id)
		else:
			_check(float(record["peak"]) <= 0.001, "%s: only a lob leaves the ground" % data.id)
		body.queue_free()
		RunState.set_phase(RunState.Phase.PREPARATION)
		_field.try_sell(anchor)
		await get_tree().process_frame
		lane = (lane + 1) % 4


func _tower_of(style: int) -> TowerData:
	var ids: Array = ContentDB.towers.keys()
	ids.sort()
	for id: Variant in ids:
		var tower: TowerData = ContentDB.towers[id] as TowerData
		if tower != null and not tower.is_well() and not tower.is_combination \
				and int(tower.shot) == style and tower.damage_at(1) > 0.0:
			return tower
	return null


func _tower_at(anchor: Vector2i) -> Tower:
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower != null and tower.anchor == anchor:
			return tower
	return null


func _shot_of(data: TowerData) -> Projectile:
	if _field.effect_root == null:
		return null
	for node: Node in _field.effect_root.get_children():
		var shot := node as Projectile
		if shot != null and shot.data == data:
			return shot
	return null


func _default_air(element: int) -> int:
	match element:
		TowerData.Element.FIRE:
			return TowerData.Ambient.EMBERS
		TowerData.Element.WATER:
			return TowerData.Ambient.DRIPS
		TowerData.Element.EARTH:
			return TowerData.Ambient.GRIT
		_:
			return TowerData.Ambient.GUSTS
