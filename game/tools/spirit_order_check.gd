extends Node

## **A spirit takes orders** (triage of 2026-10-07: "companion commands - one
## command set for a spirit and a mercenary").
##
##   godot --headless --path game res://tools/spirit_order_check.tscn
##
## Holds that a spirit starts a road following; that the spirit panel's order
## button cycles the mercenaries' four orders and the spirit takes each; that a
## guarding spirit stands at its post and looks round it rather than round
## itself, a hunting one looks further, and one holding the wall stands off the
## gate; that the order survives the spirit re-forming and a new road starts it
## following; and that it heeds its own Warden's pings and nobody else's.

const TAG: String = "[spirit-order]"

var _run: Run = null
var _field: Battlefield = null
var _hero: Hero = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var held_spirit: String = MetaState.equipped_spirit
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	MetaState.equipped_spirit = SpiritBond.key("fox", 1, false)
	RunState.reset(false, 20261012)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 30:
		await get_tree().process_frame
	_field = _run.battlefield
	_hero = _field.hero
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_hero.global_position = _field.town_position() + Vector2(0.0, 900.0)
	# Called out, as a road with Food in the larder calls it.
	RunState.spirit_called = true
	_hero._refresh_spirit()
	for _frame: int in 4:
		await get_tree().process_frame
	await _test_the_orders()
	await _test_it_keeps_its_order()
	_test_the_pings()
	_test_a_new_road()
	for stage: String in ["orders", "keeps", "pings", "road"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.equipped_spirit = held_spirit
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: a spirit follows, guards its post, hunts further, holds the wall, keeps its order when it re-forms, and heeds its own Warden's pings" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
	return ok


func _breed() -> EnemyData:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.category == EnemyData.Category.BREED:
			return breed
	return null


func _body(at: Vector2) -> Enemy:
	var body: Enemy = _field.spawn_enemy(_breed(), 0, 60.0, -1.0, 0.001)
	if body != null:
		body.global_position = at
	return body


func _clear_bodies() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()


func _spirit() -> Companion:
	return _hero.spirit if _hero.spirit != null and is_instance_valid(_hero.spirit) else null


func _test_the_orders() -> void:
	var spirit: Companion = _spirit()
	if not _check(spirit != null, "the Warden has no spirit at their shoulder"):
		_reached.append("orders")
		return
	_check(spirit.order == MercenaryInput.Order.FOLLOW and RunState.spirit_order == 0,
		"a road starts its spirit on order %d" % spirit.order)
	_check(spirit.anchor() == Vector2.INF, "a following spirit has a place to stand")
	var hud: HUD = _run.hud
	var button: Button = hud.find_child("SpiritOrder", true, false) as Button
	_check(button != null and button.visible, "the spirit panel has no order button")
	# Guard: its post is where the Warden stood, and it looks round the post.
	hud.cycle_spirit_order()
	_check(spirit.order == MercenaryInput.Order.GUARD and RunState.spirit_order == MercenaryInput.Order.GUARD,
		"the order button did not set guard")
	if button != null:
		_check(button.text == "Guard", "the order button says %s for guard" % button.text)
	var post: Vector2 = spirit.post
	_check(post.distance_to(_hero.global_position) < 1.0, "a guarding spirit's post is not where its Warden stood")
	_hero.global_position += Vector2(1500.0, 0.0)
	_check(spirit._goal(null).distance_to(post) < 1.0, "a guarding spirit follows its Warden off its post")
	spirit.global_position = post + Vector2(-700.0, 0.0)
	var by_post: Enemy = _body(post + Vector2(60.0, 0.0))
	var by_spirit: Enemy = _body(spirit.global_position + Vector2(30.0, 0.0))
	await get_tree().process_frame
	_check(spirit._nearest_enemy() == by_post, "a guarding spirit went for a body by itself rather than by its post")
	_clear_bodies()
	await get_tree().process_frame
	# Hunt: it looks further than its own range.
	hud.cycle_spirit_order()
	_check(spirit.order == MercenaryInput.Order.HUNT, "the second press did not set hunt")
	spirit.global_position = _hero.global_position
	var far: Enemy = _body(spirit.global_position + Vector2(spirit.data.hunt_range * 1.4, 0.0))
	await get_tree().process_frame
	_check(spirit._nearest_enemy() == far, "a hunting spirit did not look past its own range")
	spirit.command(MercenaryInput.Order.FOLLOW)
	_check(spirit._nearest_enemy() == null, "a following spirit looked past its own range")
	spirit.command(MercenaryInput.Order.HUNT)
	_clear_bodies()
	await get_tree().process_frame
	# Hold the wall: off the gate, toward its Warden.
	hud.cycle_spirit_order()
	_check(spirit.order == MercenaryInput.Order.WALL, "the third press did not set the wall")
	var stand: Vector2 = spirit.anchor()
	var off: float = stand.distance_to(_field.town_position())
	_check(absf(off - Balance.SPIRIT_WALL_STAND) < 1.0, "a spirit holding the wall stands %d from the town" % int(off))
	hud.cycle_spirit_order()
	_check(spirit.order == MercenaryInput.Order.FOLLOW, "the fourth press did not come round to follow")
	# Two buttons in the row must not widen the readout past its column, with
	# the widest words they wear together: the order shows only while the
	# spirit is out, so beside it the toggle says "Send home".
	if button != null:
		var panel: Control = hud.get("_spirit_panel") as Control
		var toggle: Button = hud.find_child("SpiritToggle", true, false) as Button
		var widest: int = 0
		for entry: Array in MercenaryCard.ORDERS:
			button.text = String(entry[3])
			if toggle != null:
				toggle.text = "Send home"
			await get_tree().process_frame
			widest = maxi(widest, int(panel.get_combined_minimum_size().x) if panel != null else 9999)
		_check(widest <= int(HUD.SPIRIT_PANEL_WIDTH) + 1,
			"the spirit readout wants %d wide with its order button, its column gives %d"
				% [widest, int(HUD.SPIRIT_PANEL_WIDTH)])
	_check(not FileAccess.get_file_as_string("res://scenes/battlefield/companion.gd").contains("var threat: Vector2 = _threat_to_owner()\n"),
		"a spirit told to stand somewhere still runs to whatever hunts its Warden")
	_reached.append("orders")


func _test_it_keeps_its_order() -> void:
	RunState.spirit_order = MercenaryInput.Order.HUNT
	var old: Companion = _spirit()
	if old != null:
		old.queue_free()
	_hero.spirit = null
	for _frame: int in 6:
		await get_tree().process_frame
	_hero._refresh_spirit()
	var fresh: Companion = _spirit()
	if _check(fresh != null, "the spirit did not come back"):
		_check(fresh.order == MercenaryInput.Order.HUNT, "a spirit that re-formed forgot its order (%d)" % fresh.order)
	_reached.append("keeps")


func _test_the_pings() -> void:
	var spirit: Companion = _spirit()
	if spirit == null:
		_reached.append("pings")
		return
	spirit.command(MercenaryInput.Order.FOLLOW)
	var near: Vector2 = spirit.global_position + Vector2(200.0, 0.0)
	EventBus.pinged.emit(1, "here", near)
	_check(spirit.heeding() and spirit.anchor().distance_to(near) < 1.0, "a spirit did not heed its own Warden's ping")
	spirit.command(MercenaryInput.Order.FOLLOW)
	EventBus.pinged.emit(2, "here", near)
	_check(not spirit.heeding(), "a spirit heeded a partner's ping")
	EventBus.pinged.emit(1, "coming", near)
	_check(not spirit.heeding(), "a spirit heeded a ping with nothing to heed")
	_reached.append("pings")


func _test_a_new_road() -> void:
	RunState.spirit_order = MercenaryInput.Order.WALL
	var seed_now: int = RunState.run_seed
	RunState.reset(false, seed_now + 1)
	_check(RunState.spirit_order == MercenaryInput.Order.FOLLOW, "a new road did not start the spirit following")
	_reached.append("road")
