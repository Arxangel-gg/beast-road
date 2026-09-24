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
	await _test_a_broken_tower_is_not_a_sold_one()
	await _test_a_ring_outlives_its_bodys_target()

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


## **Losing a tower must not sound like selling one.**
##
## `Sfx._on_tower_changed` told "built or upgraded" from "sold" by asking whether
## the tile was empty afterwards - and a tower smashed by a siege breed empties
## its tile exactly as a sale does, so the moment a player's defence came apart
## played a dismantle-and-refund noise.
##
## Driven through the real doors: a tower is built, then broken through
## `Health.kill`, and the gate reads back that the destruction was announced and
## that the sale was not. It reads the *signals* rather than listening for audio,
## because headless has no ear and the fault was never in the mixer.
func _test_a_broken_tower_is_not_a_sold_one() -> void:
	var anchor: Vector2i = _field.free_anchor_near(0)
	var broken: Array[Vector2i] = []
	var changed: Array[Vector2i] = []
	var ear_broken: Callable = func(at_anchor: Vector2i, _at: Vector2) -> void:
		broken.append(at_anchor)
	var ear_changed: Callable = func(at_anchor: Vector2i) -> void:
		changed.append(at_anchor)
	EventBus.tower_destroyed.connect(ear_broken)
	EventBus.tower_changed.connect(ear_changed)

	# A sale empties the tile and must announce nothing broken.
	RunState.set_tower(anchor, "ember_spire", 1)
	RunState.clear_tower(anchor)
	_check(broken.is_empty(), "selling a tower announced a destruction")
	_check(changed.has(anchor), "selling a tower announced no change at all")

	# Breaking one announces both, and the destruction first.
	broken.clear()
	changed.clear()
	RunState.set_tower(anchor, "ember_spire", 1)
	RunState.clear_tower(anchor, Vector2(120.0, 90.0))
	_check(broken.has(anchor), "a broken tower announced no destruction")
	_check(changed.has(anchor), "a broken tower announced no change")
	# The order is what lets a listener tell them apart at all.
	_check(Sfx._broken == Sfx.NO_ANCHOR,
		"the sound layer kept the broken anchor instead of consuming it")

	EventBus.tower_destroyed.disconnect(ear_broken)
	EventBus.tower_changed.disconnect(ear_changed)
	await get_tree().process_frame


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
	# **And the road stops too.**
	#
	# Five rounds of up to twelve hundred frames each is minutes of game
	# time, and the beast walks through all of it: on 2026-09-22 the fourth
	# round crossed a `SEGMENT_DISTANCE` boundary, the crossroad opened, the
	# battlefield suspended itself, and the last two towers were measured on
	# a frozen field - reported as a tower that would not fire at a body
	# standing well inside its reach.
	#
	# It had nothing to do with the towers. What made it appear was adding a
	# tenth tower to each element, which moved which tower each style picks
	# and shifted the timing by a second or two - so the gate had been one
	# authored tower away from this since the day it was written.
	if _run.journey != null:
		_run.journey.stop()
	# **And the Warden cannot be killed while this runs.**
	#
	# The hero stands on a live road for the whole of it, and the road has an
	# ecology on it. On 2026-09-22 a badger mauled the harness hero to death
	# in the middle of the fourth round - `last_blow` read *"Badger for 10"* -
	# the run settled, the battlefield suspended, and the last two towers were
	# measured on a frozen field. It was reported as a tower that would not
	# fire at a body standing well inside its reach, which is exactly the
	# probe-dies-mid-measurement lesson this project keeps relearning, with
	# the probe being the Warden rather than the target.
	#
	# Taken out of the world rather than made unkillable, through the door
	# `Battlefield.suspend` already uses: a hero nothing can find is a hero
	# nothing hunts, and this gate has no opinion about the Warden at all.
	# **And the town cannot fall while this runs**, which is the door the
	# withdrawal and `enemy_siege_check` already use. Five rounds of up to
	# twelve hundred frames is minutes of game time on a live road: on
	# 2026-09-22 a body reached the gate in the middle of the fourth round,
	# the run settled, the battlefield suspended, and the last two towers
	# were measured on a frozen field - reported as a tower that would not
	# fire at a body standing well inside its reach. Nothing about the towers
	# was wrong, and the gate had been one authored tower away from this
	# since the day it was written: adding a tenth tower to each element
	# moved which tower the lob style picks and shifted the timing.
	if _field.town != null and _field.town.health != null:
		_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
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
		# **A frame for the field to notice where it is.** The body is
		# teleported after it is spawned, and what a tower asks is the crowd
		# grid rather than the node - so on the frame of the move it can be
		# in the bucket it was spawned into and invisible to a tower standing
		# next to it. Three of the five rounds happened to work anyway.
		await get_tree().process_frame
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
		# **The range ring stands round the tower, never round what it hit.**
		# Owner, 2026-09-22: it was "appearing on the hit enemy instead of
		# showing around the attacking tower like in league of legends".
		if record["seen"]:
			var tells: Node = _field.get("_tells") as Node
			var rings: Dictionary = tells.get("_rings") as Dictionary if tells != null else {}
			var ring: Dictionary = rings.get(anchor.x * 4096 + anchor.y + 1, {}) as Dictionary
			_check(not ring.is_empty(), "%s: firing opened no range ring" % data.id)
			if not ring.is_empty():
				var centre: Vector2 = ring["at"] as Vector2
				_check(centre.distance_to(tower.origin()) < 1.0,
					("%s: the range ring is centred %.0f units from the tower and %.0f "
						+ "from the body it shot - a reach drawn round its target")
						% [data.id, centre.distance_to(tower.origin()),
							centre.distance_to(body.global_position)])
		if style == TowerData.Shot.LOB:
			_check(float(record["peak"]) > 4.0, "%s: a lob rises off its path in the air" % data.id)
			_check(bool(record["shadow"]), "%s: a lob throws a shadow on the ground" % data.id)
		else:
			_check(float(record["peak"]) <= 0.001, "%s: only a lob leaves the ground" % data.id)
		body.queue_free()
		RunState.set_phase(RunState.Phase.PREPARATION)
		# **The sell is checked, and the field is left empty.** These rounds
		# share a field, so a tower that outlives its own round shoots the
		# next round's body and a shot that outlives it is read as the next
		# tower's. Both were silent: the sell's refusal was thrown away, and
		# the effect root was never emptied.
		_check(_field.try_sell(anchor).is_empty(),
			"%s: the harness must be able to sell it again" % data.id)
		for leftover: Node in _field.effect_root.get_children():
			if leftover is Projectile:
				leftover.queue_free()
		await get_tree().process_frame
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


## **A followed ring survives the death of what its body was fighting**
## (2026-09-24). The arc reads the body's `_target` every frame to face it,
## and the first cut asked `target is Node2D` before asking whether the
## target still existed - `is` on a freed instance throws, so every ring on
## the field printed an error a frame from the moment its body's target
## died, which on Act X is sixty lines a frame. The ring keeps the way it
## last faced; the harness frees the target outright, which is the case a
## `queue_free` would only reach a frame later.
func _test_a_ring_outlives_its_bodys_target() -> void:
	var tells: Node = _field.get("_tells") as Node
	_check(tells != null, "the field stands no CombatTells")
	if tells == null:
		return
	var hero: Node2D = _field.hero
	_check(hero != null and is_instance_valid(hero), "the harness needs a Warden to be near")
	if hero == null:
		return
	var breeds: Array = ContentDB.enemies.values()
	if breeds.is_empty():
		return
	var breed: EnemyData = breeds[0] as EnemyData
	var body: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	var quarry: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	_check(body != null and quarry != null, "the harness needs two bodies")
	if body == null or quarry == null:
		return
	body.global_position = hero.global_position + Vector2(180.0, 0.0)
	quarry.global_position = body.global_position + Vector2(120.0, 0.0)
	await get_tree().process_frame
	body.set("_target", quarry)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	EventBus.enemy_attacked.emit(body.get_instance_id(), body.global_position, 140.0)
	tells.call("_process", 0.016)
	var rings: Dictionary = tells.get("_rings") as Dictionary
	var ring: Dictionary = rings.get(-body.get_instance_id(), {}) as Dictionary
	_check(not ring.is_empty(), "a body attacking near the Warden opened no ring")
	var facing: Vector2 = ring.get("aim", Vector2.ZERO) as Vector2
	_check(facing.x > 0.9, "the ring faces what the body is fighting (got %s)" % str(facing))
	# The quarry dies. Freed outright, so the body's `_target` is a freed
	# instance on the very next tick - the thing the guard has to survive.
	quarry.free()
	for _frame: int in 3:
		tells.call("_process", 0.016)
	rings = tells.get("_rings") as Dictionary
	ring = rings.get(-body.get_instance_id(), {}) as Dictionary
	_check(not ring.is_empty(), "the ring vanished when its body's target died")
	_check((ring.get("aim", Vector2.ZERO) as Vector2).is_equal_approx(facing),
		"a ring whose body lost its target keeps the way it last faced")
	body.queue_free()
	RunState.set_phase(RunState.Phase.PREPARATION)
	await get_tree().process_frame
