extends Node

## **Click to move holds** (owner, 2026-10-01: *"Clicking on the battlefield
## should move to the location ... and only attack the clicked target if and
## when the attack is in range ... and if the click was on a valid target to
## then automatically pursue that target until it is in range of the attack,
## inspired by league of legends"*):
##
##   godot --headless --path game res://tools/click_move_check.tscn
##
## Driven on a real run's field, through `ClickMove`'s own press and the
## Warden's own input:
##
## - **A ground click walks there** and the order ends on arrival; a key ends
##   it at once; a held button steers.
## - **A click on a body chases it and swings only in reach** - no swing is
##   thrown while the body is out of the swing's reach, the first is thrown
##   inside it, the swings land, and the order ends when the body falls.
## - **F on a body chases to the bow's reach** and looses there without
##   walking into a swing; an empty quiver chases into the swing instead.
## - **What a click may chase**: a road body, an animal, never one the fog
##   hides; a click beside a body is not on it.
## - **The builder's clicks are the builder's**: with building open a click on
##   a tile a sheet would open for orders nothing, a click on a body still does,
##   and its release opens no sheet; with building closed the same click walks.
## - **Ctrl and a click swings where it points**, and the setting turned off
##   makes every click a swing again.

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run = null
var _field: Battlefield = null
var _hero: Hero = null
var _orders: LocalHeroInput = null
var _moves: ClickMove = null
var _swings: int = 0
var _loosed: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	UserSettings.set_value(UserSettings.CLICK_TO_MOVE_KEY, true)
	await _stand_a_field()
	if _field != null:
		await _test_a_ground_click_walks_there()
		await _test_a_key_takes_the_order()
		await _test_a_held_button_steers()
		await _test_a_body_is_chased_and_struck_in_reach()
		await _test_the_bow_chases_to_its_own_reach()
		await _test_an_empty_quiver_chases_into_the_swing()
		await _test_what_a_click_may_chase()
		await _test_the_builders_clicks_are_the_builders()
		await _test_ctrl_and_the_setting()
		await _test_the_hovered_body_is_lit()
	_check(_finished == 10, "%d of 10 tests reached their end" % _finished)
	if _run != null:
		RunState.set_phase(RunState.Phase.PREPARATION)
		GameDirector.run_active = false
		_run.queue_free()
	UserSettings.set_value(UserSettings.CLICK_TO_MOVE_KEY, true)
	MetaState.resume_saves()
	if _failures == 0:
		print("[click-move] PASS - %d checks: a ground click walks there, a body is chased and struck only in reach, the bow chases to its own reach, the builder keeps its clicks, and Ctrl or the setting swings where it points" % _checks)
	else:
		push_error("[click-move] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _stand_a_field() -> void:
	RunState.reset(false, 20261011)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_hero = _field.hero
	_hero.health.floor_hp = _hero.health.max_hp
	_orders = _hero.input as LocalHeroInput
	_moves = _field.click_move
	_check(_orders != null, "the Warden on the field is not driven by a local input")
	_check(_moves != null, "the field has no click orders")
	if _orders == null or _moves == null:
		_field = null
		return
	EventBus.hero_swing_resolved.connect(_count_swing)
	_hero.ranged.loosed.connect(func(_f: Vector2, _d: Vector2, _a: AmmoData) -> void: _loosed += 1)
	# Out in the open south of the town, clear of its walls and its sanctuary.
	_put_the_warden(Vector2(0.0, 1500.0))
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	GameDirector.set_build_mode(false)


func _count_swing(_a: Variant = null, _b: Variant = null, _c: Variant = null,
		_d: Variant = null, _e: Variant = null, _f: Variant = null) -> void:
	_swings += 1


func _put_the_warden(at: Vector2) -> void:
	_orders.clear_order()
	_hero.global_position = at
	_hero.velocity = Vector2.ZERO


## Runs the field for up to `seconds`, stopping early when `done` says so.
func _run_for(seconds: float, done: Callable = Callable()) -> void:
	var left: float = seconds
	while left > 0.0:
		await get_tree().physics_frame
		left -= 1.0 / float(Engine.physics_ticks_per_second)
		if done.is_valid() and bool(done.call()):
			return


## A body that stands where it is put, with a pool nothing here empties by
## accident, out of the wave's count.
## What the click saw, said when it found no body to chase.
func _why_no_body(body: Enemy) -> String:
	if not is_instance_valid(body):
		return "the body was freed"
	var picked: Node2D = _moves.body_at(Hitbox.body_of(body))
	return "dying %s, hp %.0f, picked %s, targetable %s, order %d, pos %s" % [body.is_dying(), body.health.current_hp,
		picked.name if picked != null else "nothing", LocalHeroInput.can_target(body, _moves.call("_wildlife")),
		int(_orders.order), str(body.global_position)]


func _a_still_body(at: Vector2, health: float = 400.0) -> Enemy:
	var breed: EnemyData = ContentDB.enemy("bogkin")
	var body: Enemy = _field.spawn_enemy(breed, 0, 1.0, 0.001, 0.001)
	await get_tree().process_frame
	body.global_position = at
	body.process_mode = Node.PROCESS_MODE_DISABLED
	body.health.max_hp = health
	body.health.current_hp = health
	# **Seen where it stands.** It is spawned at the road's head, in the fog, and
	# a fog tick landing before it was moved hid it there - so on a slow frame a
	# click found nothing to chase. The fog looks again before the body is used,
	# and it is drawn, or not, by where it now stands.
	await _run_for(Balance.FOG_TICK * 2.5)
	return body


func _test_a_ground_click_walks_there() -> void:
	var start: Vector2 = Vector2(0.0, 1500.0)
	_put_the_warden(start)
	var goal: Vector2 = start + Vector2(320.0, 90.0)
	var marks_before: int = _moves._marks.size()
	_moves._on_press(goal, false)
	_check(_orders.order == LocalHeroInput.Order.MOVE, "a ground click gave no walk order")
	_check(_moves._marks.size() > marks_before, "a ground click left no marker where it landed")
	await _run_for(4.0, func() -> bool: return _orders.order == LocalHeroInput.Order.NONE)
	var off: float = _hero.global_position.distance_to(goal)
	_check(off <= Balance.CLICK_MOVE_ARRIVE + 4.0,
		"a ground click left the Warden %.0f units from where it landed" % off)
	_check(_orders.order == LocalHeroInput.Order.NONE, "the walk order outlived its arrival")
	_finished += 1


func _test_a_key_takes_the_order() -> void:
	_put_the_warden(Vector2(0.0, 1500.0))
	_moves._on_press(Vector2(900.0, 1500.0), false)
	await _run_for(0.2)
	Input.action_press(&"move_up")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(&"move_up")
	_check(_orders.order == LocalHeroInput.Order.NONE, "a key on the keyboard did not take the walk order away")
	_finished += 1


func _test_a_held_button_steers() -> void:
	_put_the_warden(Vector2(0.0, 1500.0))
	_moves._on_press(Vector2(400.0, 1500.0), false)
	_check(_moves._dragging, "a ground click does not steer while the button is held")
	# The steer itself asks the live cursor, which a headless run cannot move;
	# what is held here is that a new order replaces the old destination.
	_orders.order_move(Vector2(-400.0, 1500.0))
	await _run_for(0.5)
	_check(_hero.global_position.x < -20.0, "a steered order did not turn the Warden round")
	_moves._dragging = false
	_finished += 1


func _test_a_body_is_chased_and_struck_in_reach() -> void:
	var start: Vector2 = Vector2(0.0, 1500.0)
	_put_the_warden(start)
	var body: Enemy = await _a_still_body(start + Vector2(520.0, 0.0))
	var before_hp: float = body.health.current_hp
	_swings = 0
	_moves._on_press(Hitbox.body_of(body), false)
	_check(_orders.order == LocalHeroInput.Order.ATTACK, "a click on a body gave no chase order")
	_check(_orders.order_target() == body, "the chase order is not on the body clicked")
	var swung_out_of_reach: Array[float] = []
	var first_swing_gap: Array[float] = [-1.0]
	var watch: Callable = func() -> bool:
		var reach: bool = _hero.attack.reaches(_hero.combat_origin(), body, 1.0)
		if _hero.attack.is_swinging() and not reach:
			swung_out_of_reach.append(_hero.global_position.distance_to(body.global_position))
		if _swings > 0 and first_swing_gap[0] < 0.0:
			first_swing_gap[0] = _hero.global_position.distance_to(body.global_position)
		return body.health.current_hp < before_hp - 1.0 and _swings >= 2
	await _run_for(8.0, watch)
	_check(swung_out_of_reach.is_empty(),
		"the Warden swung at a chased body %d times while it was out of reach" % swung_out_of_reach.size())
	_check(_swings > 0, "the Warden chased a body and never swung")
	_check(body.health.current_hp < before_hp - 1.0, "the chase's swings never landed")
	_check(_hero.global_position.distance_to(start) > 200.0, "the Warden swung without chasing")
	# Kill it: the order ends, and the Warden stands.
	body.health.kill(_hero.global_position)
	await _run_for(0.3)
	_check(_orders.order == LocalHeroInput.Order.NONE, "the chase outlived the body")
	var still_at: Vector2 = _hero.global_position
	await _run_for(0.3)
	_check(_hero.global_position.distance_to(still_at) < 2.0, "the Warden walked on after the body fell")
	_finished += 1


func _arm_the_bow(arrows: int) -> void:
	RunState.ranged_id = "shortbow"
	var kinds: Array[AmmoData] = RunState.ammo_for_weapon("shortbow")
	for kind: AmmoData in kinds:
		RunState.ammo[kind.id] = 0
	if arrows > 0 and not kinds.is_empty():
		RunState.gain_ammo(kinds[0].id, arrows)
		RunState.ammo_id = kinds[0].id


func _test_the_bow_chases_to_its_own_reach() -> void:
	_arm_the_bow(20)
	var start: Vector2 = Vector2(0.0, 1500.0)
	_put_the_warden(start)
	var bow: RangedWeaponData = _hero.ranged.weapon()
	_check(bow != null, "the harness could not arm the Warden with a bow")
	if bow == null:
		_finished += 1
		return
	# Pressed on a body the Warden can see, and then the Warden stands back out
	# of sight with the order kept. It used to be pressed from out of sight on a
	# body the fog had not yet looked at, which passed only while the fog was
	# slower than the harness.
	var far: Vector2 = start + Vector2(bow.effective_range * 1.4, 0.0)
	_put_the_warden(far - Vector2(Balance.FOG_VISION_HERO * 0.5, 0.0))
	var body: Enemy = await _a_still_body(far, 2000.0)
	_loosed = 0
	_moves._on_bow(Hitbox.body_of(body))
	_check(_orders.order == LocalHeroInput.Order.SHOOT, "F on a body gave no bow order: %s" % _why_no_body(body))
	_hero.global_position = start
	_hero.velocity = Vector2.ZERO
	var loosed_at: Array[float] = [-1.0]
	# Out past the Warden's sight the fog takes the body; the chase walks on to
	# where it was last seen and takes it up again - League's rule.
	var chased_unseen: Array[bool] = [false]
	await _run_for(6.0, func() -> bool:
		if not body.is_visible_in_tree() and _orders.order == LocalHeroInput.Order.SHOOT:
			chased_unseen[0] = true
		if _loosed > 0 and loosed_at[0] < 0.0:
			loosed_at[0] = _hero.combat_origin().distance_to(Hitbox.meet(body, _hero.combat_origin()))
		return _loosed >= 2)
	_check(chased_unseen[0], "the bow order did not chase on into the fog after a body it could no longer see")
	_check(_loosed > 0, "a bow order never loosed (order %d, %.0f from the body, armed %s, ammo %d, kinds %d)"
		% [_orders.order, _hero.global_position.distance_to(body.global_position),
			_hero.ranged.armed(), RunState.ammo_count(RunState.ammo_id),
			RunState.ammo_for_weapon("shortbow").size()])
	if loosed_at[0] >= 0.0:
		_check(loosed_at[0] <= bow.effective_range * Balance.CLICK_MOVE_RANGED_SHARE + 30.0,
			"the bow loosed from %.0f, past its own reach of %.0f" % [loosed_at[0], bow.effective_range])
		_check(not _hero.attack.reaches(_hero.combat_origin(), body, 1.0),
			"a bow order walked the Warden into a swing")
	body.health.kill(_hero.global_position)
	await _run_for(0.2)
	_finished += 1


func _test_an_empty_quiver_chases_into_the_swing() -> void:
	_arm_the_bow(0)
	var start: Vector2 = Vector2(0.0, 1500.0)
	_put_the_warden(start)
	var body: Enemy = await _a_still_body(start + Vector2(600.0, 0.0))
	_moves._on_bow(Hitbox.body_of(body))
	_check(_orders.order != LocalHeroInput.Order.NONE, "F on a body with an empty quiver gave no order")
	await _run_for(0.1)
	_check(_orders.order == LocalHeroInput.Order.ATTACK,
		"an empty quiver did not turn the bow order into a chase for the swing")
	body.health.kill(_hero.global_position)
	RunState.ranged_id = ""
	await _run_for(0.2)
	_finished += 1


func _test_what_a_click_may_chase() -> void:
	var start: Vector2 = Vector2(0.0, 1500.0)
	_put_the_warden(start)
	var body: Enemy = await _a_still_body(start + Vector2(500.0, 200.0))
	_check(_moves.body_at(Hitbox.body_of(body)) == body, "a click on a body's middle did not land on it")
	_check(_moves.body_at(Hitbox.feet_of(body)) == body, "a click at a body's feet did not land on it")
	var beside: Vector2 = Hitbox.feet_of(body) + Vector2(body.contact_radius()
		+ Balance.CLICK_MOVE_PICK_SLOP + 60.0, 0.0)
	_check(_moves.body_at(beside) == null, "a click well beside a body landed on it")
	body.visible = false
	_check(_moves.body_at(Hitbox.body_of(body)) == null, "a click found a body the fog was hiding")
	_check(not LocalHeroInput.can_target(body, _field.wildlife()), "a hidden body may still be chased")
	body.visible = true
	_check(not LocalHeroInput.can_target(_hero, _field.wildlife()), "the Warden may chase themselves")
	body.health.kill(_hero.global_position)
	await _run_for(0.2)
	var wildlife: Wildlife = _field.wildlife()
	if wildlife != null:
		var kind: WildlifeData = null
		for value: Variant in ContentDB.wildlife():
			var data := value as WildlifeData
			if data != null and not data.flies and not data.mythic:
				kind = data
				break
		var before: int = wildlife.living_sprites().size()
		if kind != null:
			wildlife.call("_spawn", kind, start + Vector2(-400.0, 0.0))
		var sprites: Array[Node2D] = wildlife.living_sprites()
		_check(sprites.size() > before, "the harness could not place an animal")
		if sprites.size() > before:
			var animal: Node2D = sprites[sprites.size() - 1]
			animal.global_position = start + Vector2(-400.0, 0.0)
			animal.visible = true
			_check(_moves.body_at(Hitbox.body_of(animal)) == animal, "a click on an animal did not land on it")
			_moves._on_press(Hitbox.body_of(animal), false)
			_check(_orders.order == LocalHeroInput.Order.ATTACK and _orders.order_target() == animal,
				"a click on an animal gave no chase order on it")
			_orders.clear_order()
	_finished += 1


func _test_the_builders_clicks_are_the_builders() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	GameDirector.set_build_mode(true)
	await get_tree().process_frame
	var anchor: Vector2i = _field.free_anchor_near(0)
	var tile_at: Vector2 = BattleGrid.tile_to_world(anchor + Vector2i(1, 1))
	_check(_field.placement.takes_click(tile_at), "the builder does not claim a click on open ground while building")
	_put_the_warden(tile_at + Vector2(-500.0, 0.0))
	_moves._on_press(tile_at, false)
	_check(_orders.order == LocalHeroInput.Order.NONE,
		"a click on a tile the builder opens a sheet for walked the Warden there")
	var body: Enemy = await _a_still_body(tile_at)
	_moves._on_press(Hitbox.body_of(body), false)
	_check(_orders.order == LocalHeroInput.Order.ATTACK, "a click on a body while building gave no chase order: %s"
		% _why_no_body(body))
	_check(ClickMove.press_was_order, "a press taken as an order on a body is not marked for the builder")
	body.health.kill(_hero.global_position)
	_orders.clear_order()
	GameDirector.set_build_mode(false)
	await get_tree().process_frame
	_check(not _field.placement.takes_click(tile_at), "the builder still claims clicks with building closed")
	_moves._on_press(tile_at, false)
	_check(_orders.order == LocalHeroInput.Order.MOVE, "with building closed a ground click did not walk")
	_orders.clear_order()
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_finished += 1


func _test_ctrl_and_the_setting() -> void:
	_put_the_warden(Vector2(0.0, 1500.0))
	_moves._on_press(Vector2(600.0, 1500.0), false)
	_moves._on_press(Vector2(100.0, 1500.0), true)
	_check(_orders.order == LocalHeroInput.Order.NONE, "Ctrl and a click did not end the order before its swing")
	# A key or a pad bound to attack is never a click: it swings as it always did.
	Input.action_press(&"attack")
	await get_tree().physics_frame
	_check(_orders.pressed(HeroInput.BUTTON_ATTACK), "a pressed attack that is not a click did not swing")
	Input.action_release(&"attack")
	await get_tree().physics_frame
	# The setting off: an order is dropped, and a click is no order at all.
	_orders.order_move(Vector2(700.0, 1500.0))
	UserSettings.set_value(UserSettings.CLICK_TO_MOVE_KEY, false)
	await get_tree().physics_frame
	_check(_orders.move() == Vector2.ZERO, "a walk order still steered with click to move turned off")
	_check(not _moves.live(), "click orders stayed live with the setting off")
	UserSettings.set_value(UserSettings.CLICK_TO_MOVE_KEY, true)
	_finished += 1


## **What the cursor is over is lit** (owner, 2026-10-06): a body under the
## cursor wears the hover outline on its own material, and leaving it puts the
## outline back exactly as it was - driven through the hover tick with the
## gate's own cursor point, because a headless viewport has no mouse.
func _test_the_hovered_body_is_lit() -> void:
	var orders: ClickMove = _field.click_move
	_check(orders != null, "the field has no ClickMove")
	if orders == null:
		return
	var body: Enemy = await _a_still_body(Vector2(900.0, 300.0))
	await get_tree().process_frame
	# The stain material arrives on the body's first blood tick; a still body
	# may not have had one, and the harness is standing the body up, not
	# testing the tick.
	body.call("_update_blood", 0.016)
	var material := body.sprite.material as ShaderMaterial
	_check(material != null, "the probe body wears no material to light")
	var colour_was: Variant = material.get_shader_parameter("outline_colour") if material != null else null
	var strength_was: Variant = material.get_shader_parameter("outline_strength") if material != null else null
	var width_was: Variant = material.get_shader_parameter("outline_width") if material != null else null
	orders.hover_test_point = body.global_position
	orders.set("_hover_left", 0.0)
	orders.call("_tick_hover", 0.1)
	_check(ClickMove.is_lit(body), "the body under the cursor is not lit")
	if material != null:
		_check(material.get_shader_parameter("outline_colour") == Balance.HOVER_OUTLINE_COLOUR,
			"the hovered body's outline is %s, not the hover colour" % str(material.get_shader_parameter("outline_colour")))
		_check(material.get_shader_parameter("outline_width") == Balance.HOVER_OUTLINE_WIDTH,
			"the hovered body's rim is %s texels, not the hover's %.0f" % [
				str(material.get_shader_parameter("outline_width")), Balance.HOVER_OUTLINE_WIDTH])
	orders.hover_test_point = Vector2(-4000.0, -4000.0)
	orders.set("_hover_left", 0.0)
	orders.call("_tick_hover", 0.1)
	_check(not ClickMove.is_lit(body), "the body stays lit after the cursor leaves")
	if material != null:
		_check(material.get_shader_parameter("outline_colour") == colour_was
				and material.get_shader_parameter("outline_strength") == strength_was
				and material.get_shader_parameter("outline_width") == width_was,
			"leaving did not put the outline back (%s / %s)" % [
				str(material.get_shader_parameter("outline_colour")),
				str(material.get_shader_parameter("outline_strength"))])
	orders.hover_test_point = Vector2.INF
	body.queue_free()
	await get_tree().process_frame
	_finished += 1


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[click-move] " + why)
