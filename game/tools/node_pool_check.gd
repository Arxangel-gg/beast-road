extends Node

## The pools (2026-09-24): a piece and a shot come back, come back *reset*,
## and are handed out again; and a stalled wave's rescue closes the wave on
## the frame it fires while killing on its own clock.
##
##   godot --headless --path game res://tools/node_pool_check.tscn
##
## A gate that counts nodes cannot see the fault pooling invites, which is a
## node that remembers its last life - a coin that is still "taken", a shot
## still aimed at a body two waves back, a blueprint's plate over a piece of
## timber. So every test here takes a released node *back* and reads what it
## says it is. The stall rescue is driven on the real battlefield, because
## the invariant it holds - the wave closes now, the deaths come later - is a
## fact about `holds_the_wave`, `enemy_count` and the field's own tick.

var _failures: Array[String] = []
var _checks: int = 0
## Which tests reached their own last line. A GDScript runtime error stops the
## function it is in and nothing else, so a test that aborts halfway reads
## exactly like one that passed.
var _reached: Dictionary = {}
var _world: Node2D = null
var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	var held: Dictionary = Graphics.to_dictionary()
	Graphics.apply_preset(Graphics.PRESET_HIGH)
	NodePool.clear()
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	Vfx.bind_world(_world)
	await _test_a_piece_comes_back_reset()
	await _test_a_piece_forgets_what_it_was()
	await _test_a_shot_comes_back()
	await _test_a_hostile_shot_comes_back()
	await _test_a_release_this_frame_is_not_handed_out()
	await _test_the_rescue_kills_on_its_clock()
	for stage: String in ["piece", "forget", "shot", "hostile", "deferred", "rescue"]:
		_check(_reached.has(stage),
			("'%s' never reached its end - it aborted partway, and every check "
				+ "it had not made yet is a check nobody made") % stage)
	Vfx.bind_world(null)
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	NodePool.clear()
	Graphics.from_dictionary(held)
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 12:
		await get_tree().process_frame
	for problem: String in _failures:
		push_error("[node_pool] " + problem)
	print("[node_pool] %d checks, %d failed" % [_checks, _failures.size()])
	print("[node_pool] %s" % ("PASS - a piece and a shot come back reset, and the rescue kills on its clock"
		if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _seconds(span: float) -> void:
	var waited: float = 0.0
	while waited < span:
		await get_tree().process_frame
		waited += get_process_delta_time()


## The pieces under a node - the effect layers `Vfx` stands up live there too.
func _pieces_under(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is LootDrop:
			count += 1
	return count


func _lamps_under(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is PointLight2D:
			count += 1
	return count


# --- A piece comes back reset ---------------------------------------------------

## Thirty pieces put down and collected are thirty pieces parked - out of the
## field, out of the group, hidden, not processing, and holding "taken" - and
## the next thirty are those same thirty, dressed anew, with nothing new made.
func _test_a_piece_comes_back_reset() -> void:
	var pieces: Array[LootDrop] = []
	for i: int in 30:
		var piece: LootDrop = LootDrop.take()
		piece.setup(RunState.GOLD, 5, Vector2(100.0 + float(i) * 9.0, 200.0))
		piece.lead = i == 0
		piece.siblings = 30
		_world.add_child(piece)
		pieces.append(piece)
	_check(NodePool.made(&"loot") == 30,
		"thirty pieces on an empty pool are thirty allocations, not %d" % NodePool.made(&"loot"))
	await _frames(3)
	_check(pieces[4].is_inside_tree() and pieces[4].visible and pieces[4].is_processing(),
		"a piece put down is in the field, visible and processing")
	_check(pieces[4].is_in_group(LootDrop.GROUP), "and in the loot group")
	var plain_children: int = pieces[4].get_child_count()
	for piece: LootDrop in pieces:
		piece.collect_mirrored()
	await _seconds(Balance.LOOT_PICKUP_DISSOLVE_TIME + 0.3)
	_check(_pieces_under(_world) == 0,
		"every collected piece left the field (%d still under it)" % _pieces_under(_world))
	_check(NodePool.pooled(&"loot") == 30,
		"thirty collected pieces are thirty parked (%d)" % NodePool.pooled(&"loot"))
	var parked: LootDrop = pieces[3]
	_check(is_instance_valid(parked), "a collected piece is kept, not freed")
	if is_instance_valid(parked):
		_check(parked.get_parent() == NodePool.lot(), "a collected piece waits in the lot")
		_check(not parked.visible, "a parked piece is not visible")
		_check(not parked.is_processing(), "a parked piece does not process")
		_check(not parked.is_in_group(LootDrop.GROUP), "a parked piece is in no group")
		_check(parked.is_taken(),
			"a parked piece reads as taken, so a thief that remembered it by id finds nothing")
		_check(parked.amount == 0 and parked.currency.is_empty(),
			"a parked piece has forgotten its coin (%s %d)" % [parked.currency, parked.amount])
	_check(get_tree().get_nodes_in_group(LootDrop.GROUP).is_empty(),
		"no parked piece answers the loot group")

	var again: Array[LootDrop] = []
	for i: int in 30:
		var piece: LootDrop = LootDrop.take()
		piece.setup(RunState.GOLD, 7, Vector2(100.0 + float(i) * 9.0, 260.0))
		piece.lead = i == 0
		piece.siblings = 30
		_world.add_child(piece)
		again.append(piece)
	var same: int = 0
	for piece: LootDrop in again:
		if pieces.has(piece):
			same += 1
	_check(same == 30,
		"thirty pieces taken from a pool of thirty are the same thirty (%d were)" % same)
	_check(NodePool.made(&"loot") == 30,
		"a second handful allocated nothing new (%d made)" % NodePool.made(&"loot"))
	_check(NodePool.reused(&"loot") == 30,
		"and was thirty reuses (%d)" % NodePool.reused(&"loot"))
	await _frames(3)
	var one: LootDrop = again[5]
	_check(one.visible and one.is_processing() and one.is_in_group(LootDrop.GROUP)
		and not one.is_taken(),
		"a reused piece is dressed: visible, processing, in the group, not taken")
	_check(one.amount == 7 and one.currency == RunState.GOLD,
		"a reused piece is the coin it was set up as (%s %d)" % [one.currency, one.amount])
	# A plain piece reused as a plain piece carries exactly what it carried:
	# one sprite and one glow. A second set of either is the pool's whole
	# saving thrown away, one child at a time.
	var grown: int = 0
	for index: int in range(1, again.size()):
		var piece: LootDrop = again[index]
		if pieces.find(piece) >= 1 and piece.get_child_count() != plain_children:
			grown += 1
	_check(grown == 0,
		"%d reused plain pieces grew children on reuse (a plain piece has %d)" % [grown, plain_children])
	for piece: LootDrop in again:
		piece.collect_mirrored()
	await _seconds(Balance.LOOT_PICKUP_DISSOLVE_TIME + 0.3)
	_reached["piece"] = true


# --- A piece forgets what it was ------------------------------------------------

## A blueprint's piece - plate, spire, lamp - comes back as a piece of timber
## with none of them showing.
func _test_a_piece_forgets_what_it_was() -> void:
	var plans: Array = ContentDB.blueprints.keys()
	plans.sort()
	_check(not plans.is_empty(), "the harness needs a blueprint to drop")
	if plans.is_empty():
		return
	var piece: LootDrop = LootDrop.take()
	piece.setup_blueprint(String(plans[0]), Vector2(300.0, 300.0))
	_world.add_child(piece)
	await _frames(3)
	var plate := piece.get_node_or_null("PickupPlate") as Label
	_check(plate != null and plate.visible and plate.text == "Blueprint",
		"a blueprint on the ground wears its plate")
	var beacon := piece.get_node_or_null("PickupBeacon") as Sprite2D
	_check(beacon != null, "and carries its spire")
	_check(_lamps_under(piece) == 1,
		"and its lamp (%d lights under it)" % _lamps_under(piece))
	piece.collect_mirrored()
	await _seconds(Balance.LOOT_PICKUP_DISSOLVE_TIME + 0.3)
	var back: LootDrop = LootDrop.take()
	_check(back == piece, "the blueprint's piece is the one the pool hands back")
	back.setup(RunState.WOOD, 3, Vector2(320.0, 300.0))
	back.lead = false
	_world.add_child(back)
	await _frames(3)
	_check(back.blueprint.is_empty() and back.currency == RunState.WOOD and back.amount == 3,
		"a piece reused as timber is timber (blueprint '%s', %s %d)"
			% [back.blueprint, back.currency, back.amount])
	_check(plate != null and is_instance_valid(plate) and not plate.visible,
		"the plate from its last life is hidden")
	_check(beacon != null and is_instance_valid(beacon) and not beacon.visible,
		"the spire from its last life is hidden")
	_check(_lamps_under(back) == 0,
		"the lamp from its last life is gone (%d lights under it)" % _lamps_under(back))
	_check(Color(back.get("_glow_colour")) == Balance.LOOT_GLOW_COLOUR,
		"the glow is a coin's, not a blueprint's rarity")
	back.collect_mirrored()
	await _seconds(Balance.LOOT_PICKUP_DISSOLVE_TIME + 0.3)
	_reached["forget"] = true


# --- A shot comes back ---------------------------------------------------------

func _a_tower() -> TowerData:
	var ids: Array = ContentDB.towers.keys()
	ids.sort()
	for id: Variant in ids:
		var tower: TowerData = ContentDB.towers[id] as TowerData
		if tower != null and not tower.is_well() and not tower.is_combination \
				and tower.damage_at(1) > 0.0:
			return tower
	return null


## A shot that runs out of life is parked, and the next shot is that one,
## having forgotten its tier, its tower and its trail - and carrying one glow
## layer, not two.
func _test_a_shot_comes_back() -> void:
	var data: TowerData = _a_tower()
	_check(data != null, "the harness needs a tower that shoots")
	if data == null:
		return
	var shot: Projectile = Projectile.take()
	shot.setup(null, data, 10.0, 0.0, 5)
	shot.set("_life", Balance.PROJECTILE_MAX_LIFE + 1.0)
	_world.add_child(shot)
	shot.global_position = Vector2(400.0, 400.0)
	await _frames(3)
	_check(is_instance_valid(shot), "a shot that ran out of life is kept, not freed")
	if not is_instance_valid(shot):
		return
	_check(shot.get_parent() == NodePool.lot(), "and is parked")
	_check(not shot.visible and not shot.is_processing(), "hidden and not processing")
	var again: Projectile = Projectile.take()
	_check(again == shot, "the next shot is the parked one")
	_check(again.tier == 1 and again.data == null,
		"and it has forgotten its tier and its tower (tier %d)" % again.tier)
	_check((again.get("_history") as PackedVector2Array).is_empty(),
		"and its trail")
	_check(not bool(again.get("_aimed")), "and its aim")
	again.setup(null, data, 4.0, 0.0, 2)
	_world.add_child(again)
	again.global_position = Vector2(420.0, 400.0)
	await _frames(2)
	_check(again.visible and again.is_processing() and again.tier == 2,
		"a reused shot is dressed for its new tier")
	var glows: int = 0
	for child: Node in again.get_children():
		if child is Projectile.ProjectileGlow:
			glows += 1
	_check(glows == 1, "a reused shot has one glow layer, not %d" % glows)
	_check(NodePool.made(&"shot") == 1,
		"two shots in a row are one allocation (%d)" % NodePool.made(&"shot"))
	again.set("_life", Balance.PROJECTILE_MAX_LIFE + 1.0)
	await _frames(3)
	_reached["shot"] = true


# --- A hostile shot comes back ---------------------------------------------------

## A painted hostile shot comes back wearing the roster's own paint, so a
## thrower that paints nothing throws the shot every breed threw before.
func _test_a_hostile_shot_comes_back() -> void:
	var shot: EnemyProjectile = EnemyProjectile.take()
	shot.tint = Color.RED
	shot.head = EnemyShotData.Head.SKULL
	shot.kind = EnemyProjectile.Kind.HEX
	shot.head_scale = 1.6
	shot.configure_toward(Vector2(600.0, 0.0), Vector2(0.0, 0.0))
	shot.set("_life", Balance.ENEMY_PROJECTILE_MAX_LIFE + 1.0)
	_world.add_child(shot)
	await _frames(3)
	_check(is_instance_valid(shot) and shot.get_parent() == NodePool.lot(),
		"a hostile shot that ran out of life is parked, not freed")
	var again: EnemyProjectile = EnemyProjectile.take()
	_check(again == shot, "the next hostile shot is the parked one")
	_check(again.tint == Balance.ENEMY_PROJECTILE_COLOUR
		and again.head == EnemyShotData.Head.RUNE
		and again.kind == EnemyProjectile.Kind.BOLT
		and is_equal_approx(again.head_scale, 1.0),
		"a reused hostile shot wears the roster's own paint until its thrower paints it")
	again.configure_toward(Vector2(0.0, 600.0), Vector2(0.0, 0.0))
	_world.add_child(again)
	await _frames(2)
	_check(again.visible and again.is_processing(), "a reused hostile shot flies")
	var ribbons: int = 0
	var glows: int = 0
	for child: Node in again.get_children():
		if child is EnemyProjectile.EnemyShotGlow:
			ribbons += 1
		elif child is Sprite2D:
			glows += 1
	_check(ribbons == 1 and glows == 1,
		"a reused hostile shot has one ribbon and one glow, not %d and %d" % [ribbons, glows])
	_check(NodePool.made(&"enemy_shot") == 1,
		"two hostile shots in a row are one allocation (%d)" % NodePool.made(&"enemy_shot"))
	again.set("_life", Balance.ENEMY_PROJECTILE_MAX_LIFE + 1.0)
	await _frames(3)
	_reached["hostile"] = true


# --- A release this frame is not handed out ----------------------------------------

## A node given back and asked for on the same frame is still in the field,
## so it is not the one handed out; a frame later it is. And the free list is
## capped: past the cap a node is freed as it always was.
func _test_a_release_this_frame_is_not_handed_out() -> void:
	var probe := Node2D.new()
	_world.add_child(probe)
	NodePool.give(&"probe", probe, 4)
	var fresh: Node = NodePool.take(&"probe", func() -> Node: return Node2D.new())
	_check(fresh != probe,
		"a node released this frame is still in the field and is not handed out")
	_check(probe.get_parent() == _world, "it stays under the field until the deferred park runs")
	await _frames(1)
	_check(probe.get_parent() == NodePool.lot(), "and is parked a frame later")
	var next: Node = NodePool.take(&"probe", func() -> Node: return Node2D.new())
	_check(next == probe, "then it is the one handed out")
	_check(next.get_parent() == null, "handed out, it is out of the lot")
	fresh.queue_free()
	next.queue_free()
	var extra: Array[Node] = []
	for _i: int in 6:
		var node := Node2D.new()
		_world.add_child(node)
		NodePool.give(&"probe", node, 4)
		extra.append(node)
	await _frames(2)
	_check(NodePool.pooled(&"probe") == 4,
		"the free list is capped at four (%d parked)" % NodePool.pooled(&"probe"))
	var freed: int = 0
	for node: Node in extra:
		if not is_instance_valid(node):
			freed += 1
	_check(freed == 2, "and the two past the cap were freed as they always were (%d)" % freed)
	_reached["deferred"] = true


# --- The rescue kills on its clock ---------------------------------------------

func _a_breed() -> EnemyData:
	for one: EnemyData in ContentDB.enemies.values():
		if one != null and one.category == EnemyData.Category.BREED:
			return one
	return null


## Twelve road bodies hold a wave; the rescue resolves all twelve and the wave
## closes on that same frame - no body holds it - while the deaths arrive no
## more than `MASS_KILL_PER_FRAME` a frame, every one of them arrives, and a
## body waiting its turn strikes nothing.
func _test_the_rescue_kills_on_its_clock() -> void:
	RunState.reset(false, 20260924)
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	await _frames(20)
	var field: Battlefield = _run.battlefield
	_check(field != null, "the harness could not stand a battlefield up")
	if field == null:
		return
	RunState.set_phase(RunState.Phase.PREPARATION)
	var breed: EnemyData = _a_breed()
	_check(breed != null, "no breed to stand up")
	if breed == null:
		return
	var bodies: Array[Enemy] = []
	for i: int in 12:
		var body: Enemy = field.spawn_enemy(breed, i % 4, 1.0)
		if body != null:
			bodies.append(body)
	await _frames(1)
	_check(bodies.size() == 12, "the harness could only spawn %d of 12 bodies" % bodies.size())
	_check(field.enemy_count() == 12,
		"twelve road bodies hold the wave (%d)" % field.enemy_count())
	var town_hp: float = field.town.health.current_hp \
		if field.town != null and field.town.health != null else -1.0
	var resolved: int = field.resolve_stalled_wave()
	_check(resolved == 12, "the rescue resolved all twelve (%d)" % resolved)
	_check(field.enemy_count() == 0,
		"and the wave closed on the same frame: no body holds it (%d do)" % field.enemy_count())
	_check(field.doomed_pending() == 12,
		"with all twelve still owed a death (%d)" % field.doomed_pending())
	await _frames(1)
	var died_first: int = 0
	for body: Enemy in bodies:
		if not is_instance_valid(body) or body.is_dying():
			died_first += 1
	_check(died_first > 0 and died_first <= Balance.MASS_KILL_PER_FRAME,
		("one frame after the rescue %d had died: at least one, and no more than "
			+ "%d a frame") % [died_first, Balance.MASS_KILL_PER_FRAME])
	await _frames(ceili(12.0 / float(Balance.MASS_KILL_PER_FRAME)) + 2)
	var died_all: int = 0
	for body: Enemy in bodies:
		if not is_instance_valid(body) or body.is_dying():
			died_all += 1
	_check(died_all == 12, "every doomed body died on the clock (%d of 12)" % died_all)
	_check(field.doomed_pending() == 0,
		"and none is still owed (%d)" % field.doomed_pending())
	var town_after: float = field.town.health.current_hp \
		if field.town != null and field.town.health != null else -1.0
	_check(is_equal_approx(town_hp, town_after),
		"a doomed body struck nothing while it waited (town %.0f -> %.0f)" % [town_hp, town_after])
	_reached["rescue"] = true
