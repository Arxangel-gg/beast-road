extends Node

## **A body is met where it is drawn, and reached the same from every side**
## (owner, 2026-10-01: *"Enemy hitboxes need to be elevated and polished, it
## currently sits just at their body origin or feet root for most enemies.
## Enemies also need to have hitbox targeting improved on players and wildlife
## as well and vice versa"*):
##
##   godot --headless --path game res://tools/hitbox_check.tscn
##
## Held on the real field, through `Hitbox` and the doors that ask it:
##
## - **The stroke.** A body can be met anywhere from its feet to its upper
##   chest, and not over its head.
## - **Reach is the same from every side.** A body's `_target_gap` to a Warden
##   standing the same ground distance north, south, east and west reads the
##   same four times, on the tallest breed the roster has - which is where the
##   old chest-to-feet measure was furthest out.
## - **A tower's shot lands on the body.** A real tower fires at a real body and
##   the shot is read where it dies: on the body's stroke, above its feet.
## - **An animal's body is its painting**, offset and scale included.
##
## **The ways this goes wrong:** a measure that reverts to a single point; a
## reach that is longer to the south than to the north; a shot that strikes
## the ground under what it hit.

const SEED: int = 20261003

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run
var _field: Battlefield


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	if _field.town != null and _field.town.health != null:
		_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	RunState.gain_every_currency(99999)

	await _test_the_stroke()
	await _test_reach_is_the_same_from_every_side()
	await _test_a_tower_shot_lands_on_the_body()
	_test_an_animal_is_its_painting()
	await _test_a_boss_is_its_painting()
	await _test_the_zones_pay_what_they_say()

	_check(_finished == 6, "%d of 6 tests reached their end" % _finished)
	_run.queue_free()
	for _f: int in 6:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures == 0:
		print(("[hitbox] PASS - %d checks: a body is its painting, feet to crown, "
			+ "reached alike from every side, a boss's leg is the boss, and the zones pay") % _checks)
	else:
		push_error("[hitbox] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


## The tallest ordinary breed: where a measure from one point was furthest out.
func _tallest_breed() -> EnemyData:
	var best: EnemyData = null
	var height: float = 0.0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or breed.category != EnemyData.Category.BREED:
			continue
		var path: String = breed.get_sprite_path()
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path) as Texture2D
		if texture != null and float(texture.get_height()) > height:
			height = float(texture.get_height())
			best = breed
	return best


func _spawn(breed: EnemyData, at: Vector2) -> Enemy:
	var body: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	if body == null:
		return null
	await get_tree().process_frame
	body.global_position = at
	await get_tree().process_frame
	return body


func _test_the_stroke() -> void:
	var breed: EnemyData = _tallest_breed()
	var body: Enemy = await _spawn(breed, Vector2(2200.0, 1800.0))
	_check(body != null, "the harness needs a body")
	if body == null:
		_finished += 1
		return
	var feet: Vector2 = body.global_position
	var centre: Vector2 = body.combat_origin()
	_check(Hitbox.feet_of(body) == feet, "a body's feet are not where it stands")
	_check(Hitbox.body_of(body) == centre, "a body's middle is not its combat origin")
	_check(centre.y < feet.y - 10.0, "%s's body is drawn at its feet - nothing to elevate" % breed.id)
	_check(Hitbox.gap(body, feet) < 0.01, "a blow at the feet does not meet the body")
	_check(Hitbox.gap(body, centre) < 0.01, "a blow at the middle does not meet the body")
	var chest: Vector2 = feet + (centre - feet) * 1.3
	_check(Hitbox.gap(body, chest) < 0.01, "a blow at the chest does not meet the body")
	# **Amended 2026-10-07**: the spine's top is the crown of the painting now,
	# not a share past the middle, so "well over the head" is measured off it.
	var crown: Vector2 = Hitbox.top_of(body)
	_check(crown.y < centre.y, "%s's crown is not above its middle" % breed.id)
	var over: Vector2 = crown + (crown - feet) * 0.6
	_check(Hitbox.reach_gap(body, over) > 0.0,
		"a blow well over the head of %s meets it - the body has no top" % breed.id)
	body.queue_free()
	await get_tree().process_frame
	_finished += 1


func _test_reach_is_the_same_from_every_side() -> void:
	var breed: EnemyData = _tallest_breed()
	var hero: Hero = _field.hero
	var body: Enemy = await _spawn(breed, Vector2(2200.0, 1800.0))
	if body == null or hero == null:
		_check(false, "the harness needs a body and a Warden")
		_finished += 1
		return
	var gaps: Array[float] = []
	var ground: float = body.attack_reach() * 0.8
	for side: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		hero.global_position = body.global_position + side * ground
		gaps.append(float(body.call("_target_gap", hero)))
	var spread: float = gaps.max() - gaps.min()
	_check(spread < 0.5, ("%s reaches a Warden %.0f away by %s north, south, west and east - "
		+ "one gap, four answers") % [breed.id, ground, gaps])
	var in_reach: Array[bool] = []
	for side: Vector2 in [Vector2.UP, Vector2.DOWN]:
		hero.global_position = body.global_position + side * ground
		in_reach.append(bool(body.call("_in_reach", hero)))
	_check(in_reach[0] == in_reach[1], "%s can reach a Warden to one side and not the other" % breed.id)
	hero.global_position = Vector2.ZERO
	body.queue_free()
	await get_tree().process_frame
	_finished += 1


func _test_a_tower_shot_lands_on_the_body() -> void:
	var tower_data: TowerData = null
	for value: Variant in ContentDB.base_towers():
		var data := value as TowerData
		if data != null and not data.is_support() and not data.is_well() \
				and data.shot == TowerData.Shot.BOLT:
			tower_data = data
			break
	var anchor: Vector2i = _field.free_anchor_near(0)
	var problem: String = _field.try_build(anchor, tower_data) if tower_data != null else "no bolt tower"
	_check(problem.is_empty(), "the harness could not build a bolt tower: %s" % problem)
	await get_tree().process_frame
	var tower: Tower = _field.tower_at_anchor(anchor)
	if tower == null:
		_finished += 1
		return
	var body: Enemy = await _spawn(_tallest_breed(), tower.origin() + Vector2(tower.effective_range() * 0.7, 0.0))
	if body == null:
		_finished += 1
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	var record: Dictionary = {"seen": false, "at": Vector2.INF}
	var born: Callable = func(node: Node) -> void:
		var shot := node as Projectile
		if shot == null or record["seen"]:
			return
		record["seen"] = true
		shot.tree_exiting.connect(func() -> void: record["at"] = shot.global_position)
	_field.effect_root.child_entered_tree.connect(born)
	for _frame: int in 1500:
		await get_tree().process_frame
		if record["at"] != Vector2.INF:
			break
	_field.effect_root.child_entered_tree.disconnect(born)
	_check(record["seen"], "the tower never fired at a body in reach")
	var landed: Vector2 = record["at"] as Vector2
	if landed != Vector2.INF:
		var lift: float = body.global_position.y - body.combat_origin().y
		_check(Hitbox.gap(body, landed) <= body.contact_radius() + Balance.PROJECTILE_HIT_RADIUS + 2.0,
			"the shot died %.0f from the body's stroke" % Hitbox.gap(body, landed))
		_check(landed.y < body.global_position.y - lift * 0.3,
			("the shot struck at %s, the ground under a body whose middle is %.0f up - it "
				+ "flew at the feet") % [landed, lift])
	RunState.set_phase(RunState.Phase.PREPARATION)
	body.queue_free()
	await get_tree().process_frame
	_finished += 1


func _test_an_animal_is_its_painting() -> void:
	var sprite := Sprite2D.new()
	add_child(sprite)
	sprite.global_position = Vector2(300.0, 400.0)
	sprite.offset = Vector2(0.0, -40.0)
	sprite.scale = Vector2(2.0, 2.0)
	_check(Hitbox.body_of(sprite).is_equal_approx(Vector2(300.0, 320.0)),
		"an animal's body is %s - not its painted middle" % Hitbox.body_of(sprite))
	_check(Hitbox.feet_of(sprite) == Vector2(300.0, 400.0), "an animal's feet are not where it stands")
	sprite.queue_free()
	_finished += 1


## **The widest act boss's painting**: where a stick down the middle was furthest
## from the picture.
func _widest_boss() -> EnemyData:
	var best: EnemyData = null
	var width: float = 0.0
	for data: EnemyData in ContentDB.enemies_of_category(EnemyData.Category.BOSS):
		var path: String = data.get_sprite_path()
		if not ResourceLoader.exists(path):
			continue
		var share: Rect2 = Hitbox.paint_share(path)
		var texture: Texture2D = load(path) as Texture2D
		var wide: float = share.size.x * float(texture.get_width()) if texture != null else 0.0
		if wide > width:
			width = wide
			best = data
	return best


## **A boss is its painting** (owner, 2026-10-07: *"Act bosses are untargettable
## as the player goes to try to only hit the target between their legs and
## doesn't attack it there either"*). Three things had to be true and none was:
## the painted body is measured, a click on its chest picks it, and a Warden
## standing at its leg reaches it and a swing from there lands.
func _test_a_boss_is_its_painting() -> void:
	var data: EnemyData = _widest_boss()
	var boss: Enemy = await _spawn(data, Vector2(2600.0, 1900.0)) if data != null else null
	_check(boss != null, "the harness needs an act boss")
	var hero: Hero = _field.hero
	if boss == null or hero == null:
		_finished += 1
		return
	boss.health.max_hp = 1.0e7
	boss.health.current_hp = 1.0e7
	var painted: Rect2 = Hitbox.painted_rect(boss)
	_check(painted.size.x > boss.contact_radius() * 2.0,
		"%s's painted body is %s - it was never measured" % [data.id, painted])
	_check(Hitbox.hit_radius(boss) > boss.contact_radius() * 1.5,
		"%s stands %.0f wide to a blow on a painting %.0f wide - a stick down its middle"
			% [data.id, Hitbox.hit_radius(boss) * 2.0, painted.size.x])
	var chest := Vector2(painted.get_center().x + painted.size.x * 0.12,
		painted.position.y + painted.size.y * 0.45)
	_check(Hitbox.reach_gap(boss, chest) == 0.0,
		"a point on %s's chest is %.0f from its body" % [data.id, Hitbox.reach_gap(boss, chest)])
	# The fog is not this test's subject: a body the fog hides is refused a
	# click by design, and the boss stands where nobody has looked yet.
	boss.visible = true
	if _field.click_move != null:
		var picked: Node2D = _field.click_move.body_at(chest)
		_check(picked == boss, "a click on %s's chest picked %s - it is read as the ground"
			% [data.id, picked])
	# A Warden at its leg: inside its painted outline, near the edge, where a
	# line down its middle is furthest away - measured off the painting, so a
	# hitbox that shrank back to a stick leaves the Warden out of reach.
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	hero.global_position = boss.global_position + Vector2(painted.size.x * 0.42, 12.0)
	var origin: Vector2 = hero.combat_origin()
	_check(Hitbox.zone_at(hero, Hitbox.aim_point(boss, hero, false)) == Hitbox.Zone.HEAD,
		"%s strikes a Warden below the head - a giant's blow falls from above" % data.id)
	_check(hero.attack.reaches(origin, boss),
		"a Warden beside %s's leg is out of its reach (%.0f from its body)"
			% [data.id, Hitbox.reach_gap(boss, origin)])
	var before: float = boss.health.current_hp
	var aim: Vector2 = (Hitbox.meet(boss, origin) - origin).normalized()
	hero.attack.cancel()
	hero.attack.request()
	for _i: int in 60:
		hero.attack.tick(1.0 / 60.0, aim, origin)
	_check(boss.health.current_hp < before,
		"a swing from beside %s's leg took nothing - the Warden swings at the space between its legs"
			% data.id)
	hero.attack.cancel()
	hero.process_mode = Node.PROCESS_MODE_INHERIT
	hero.global_position = Vector2.ZERO
	boss.queue_free()
	await get_tree().process_frame
	_finished += 1


## **The zones pay what they say** (owner, 2026-10-07: *"different parts of the
## characters ... that are hit should deal different amounts of damage depending
## on how vital the area is etc with higher crit chances in the weakpoint
## areas"*). Read off a real blow through the Warden's own landing door: the legs
## never more than an unzoned blow, the head never less, the head's mean inside
## what its scale and its crit can make it - and a body's blow on the Warden
## lands where the two bodies' heights put it.
func _test_the_zones_pay_what_they_say() -> void:
	var breed: EnemyData = _tallest_breed()
	var body: Enemy = await _spawn(breed, Vector2(2200.0, 1800.0))
	var hero: Hero = _field.hero
	if body == null or hero == null:
		_check(false, "the harness needs a body and a Warden")
		_finished += 1
		return
	var spine: PackedVector2Array = Hitbox.spine_of(body)
	_check(Hitbox.zone_at(body, spine[0]) == Hitbox.Zone.LEGS, "a body's feet are not its legs")
	_check(Hitbox.zone_at(body, spine[0].lerp(spine[1], 0.55)) == Hitbox.Zone.TORSO,
		"a body's middle is not its torso")
	_check(Hitbox.zone_at(body, spine[1]) == Hitbox.Zone.HEAD, "a body's crown is not its head")
	body.health.max_hp = 1.0e7
	body.health.current_hp = 1.0e7
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	var origin: Vector2 = hero.combat_origin()
	var dealt: Callable = func(zone: int) -> float:
		var before: float = body.health.current_hp
		hero.attack.set("_hit_ids", {})
		hero.attack.call("_land_on", body, 100.0, 0.0, false, null, origin, zone, Vector2.INF)
		return before - body.health.current_hp
	var plain: float = float(dealt.call(-1))
	var legs: float = float(dealt.call(Hitbox.Zone.LEGS))
	_check(plain > 0.0, "an unzoned blow took nothing")
	_check(legs > 0.0 and legs < plain, "a blow on the legs took %.1f against an unzoned %.1f" % [legs, plain])
	var heads: float = 0.0
	var lowest: float = INF
	for _i: int in 60:
		var one: float = float(dealt.call(Hitbox.Zone.HEAD))
		heads += one
		lowest = minf(lowest, one)
	var mean: float = heads / 60.0
	_check(lowest >= plain * Balance.HITBOX_ZONE_DAMAGE[Hitbox.Zone.HEAD] * 0.99,
		"a head blow took %.1f, under the head's own scale on an unzoned %.1f" % [lowest, plain])
	_check(mean <= plain * Balance.HITBOX_ZONE_DAMAGE[Hitbox.Zone.HEAD] * Balance.HITBOX_CRIT_SCALE,
		"head blows averaged %.1f, past what a head and a crit can make of %.1f" % [mean, plain])
	# A body's blow on the Warden falls from its own shoulder: the tallest
	# breed's above the legs (a giant's on the head is the boss test's).
	hero.global_position = body.global_position + Vector2(70.0, 0.0)
	_check(Hitbox.zone_at(hero, Hitbox.aim_point(body, hero, false)) != Hitbox.Zone.LEGS,
		"%s, the tallest breed, strikes a Warden on the legs" % breed.id)
	_check(Hitbox.zone_at(hero, Hitbox.aim_point(body, hero, true)) == Hitbox.Zone.HEAD,
		"a blow meant for the head is aimed elsewhere")
	_check(Hitbox.zone_scale(hero, Hitbox.Zone.HEAD) > Hitbox.zone_scale(hero, Hitbox.Zone.TORSO),
		"a Warden's head takes no more than their torso")
	hero.process_mode = Node.PROCESS_MODE_INHERIT
	hero.global_position = Vector2.ZERO
	body.queue_free()
	await get_tree().process_frame
	_finished += 1


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[hitbox] " + message)
