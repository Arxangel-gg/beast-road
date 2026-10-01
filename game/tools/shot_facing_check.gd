extends Node

## **Every shot faces the way it is going** (owner, 2026-10-01: *"Some
## projectiles are not properly oriented"*):
##
##   godot --headless --path game res://tools/shot_facing_check.tscn
##
## - **An upright head stays upright.** A skull and a bell are drawn with an up,
##   and were turned with the flight - upside down whenever thrown leftward. In
##   every direction the world-facing turn is level and the mirror faces the
##   flight; a head that points is still turned with it.
## - **A spell's painted head keeps its shape.** Every head painting is twice as
##   long as it is tall; drawn into a square it read as pointing either way.
## - **A lob lies along its arc.** A real lob tower fires at a real body and the
##   shot is read in flight: its head leaves the tower nose up and comes down
##   nose first, where it used to run level the whole way.

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_upright_heads()
	_test_streak_heads_keep_their_shape()
	await _test_a_lob_lies_along_its_arc()
	_check(_finished == 3, "%d of 3 tests reached their end" % _finished)
	MetaState.resume_saves()
	if _failures == 0:
		print("[shot-facing] PASS - %d checks: an upright head stays upright and faces its flight, a painted head keeps its shape, and a lob lies along its arc" % _checks)
	else:
		push_error("[shot-facing] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _test_upright_heads() -> void:
	for degrees: float in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		var heading: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(degrees))
		var turned: float = heading.angle()
		for head: int in [EnemyShotData.Head.SKULL, EnemyShotData.Head.BELL]:
			var pose: Vector2 = EnemyProjectile.head_pose(head, turned, heading)
			var world: float = wrapf(turned + pose.x, -PI, PI)
			_check(absf(world) < 0.001,
				"a %s thrown at %d degrees is drawn turned %.0f degrees off upright"
					% [EnemyShotData.Head.keys()[head], int(degrees), rad_to_deg(world)])
			var facing_left: bool = heading.x < -0.001
			if absf(heading.x) > 0.001:
				_check((pose.y < 0.0) == facing_left,
					"a %s thrown at %d degrees faces away from its flight"
						% [EnemyShotData.Head.keys()[head], int(degrees)])
		var dart: Vector2 = EnemyProjectile.head_pose(EnemyShotData.Head.DART, turned, heading)
		_check(dart == Vector2(0.0, 1.0), "a dart is no longer turned with its flight")
	_finished += 1


func _test_streak_heads_keep_their_shape() -> void:
	for element: int in [TowerData.Element.FIRE, TowerData.Element.WATER,
			TowerData.Element.EARTH, TowerData.Element.AIR]:
		var frames: Array[Texture2D] = Vfx.head_frames(Vfx.head_of(element))
		if frames.is_empty():
			continue
		var painted: Vector2 = frames[0].get_size()
		var box: Vector2 = VfxInk.streak_head_box(painted, 12.0)
		_check(absf(box.x / box.y - painted.x / painted.y) < 0.01,
			"a %s head is drawn %.2f long to its height, painted %.2f"
				% [TowerData.element_name(element), box.x / box.y, painted.x / painted.y])
		_check(box.x > 12.0 * 2.0, "a streak's head is drawn no longer than the square it replaced")
	_finished += 1


func _test_a_lob_lies_along_its_arc() -> void:
	RunState.reset(false, 20261005)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.town.health.floor_hp = field.town.health.max_hp * 0.5
	RunState.gain_every_currency(99999)
	var lob: TowerData = null
	for value: Variant in ContentDB.base_towers():
		var data := value as TowerData
		if data != null and data.shot == TowerData.Shot.LOB and not data.is_support() \
				and not data.is_well():
			lob = data
			break
	_check(lob != null, "the roster has no lob tower to fire")
	if lob == null:
		run.queue_free()
		_finished += 1
		return
	var anchor: Vector2i = field.free_anchor_near(0)
	var problem: String = field.try_build(anchor, lob)
	_check(problem.is_empty(), "the harness could not build %s: %s" % [lob.id, problem])
	await get_tree().process_frame
	var tower: Tower = field.tower_at_anchor(anchor)
	if tower == null:
		run.queue_free()
		_finished += 1
		return
	var body: Enemy = field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 40.0)
	await get_tree().process_frame
	body.global_position = tower.origin() + Vector2(tower.effective_range() * 0.75, 0.0)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	var record: Dictionary = {"shot": null}
	var born: Callable = func(node: Node) -> void:
		if record["shot"] == null and node is Projectile:
			record["shot"] = node
	field.effect_root.child_entered_tree.connect(born)
	var headings: Array[Vector2] = []
	for _frame: int in 1500:
		await get_tree().process_frame
		var shot := record["shot"] as Projectile
		if shot == null:
			continue
		if not is_instance_valid(shot) or not shot.is_inside_tree() or not shot.visible:
			break
		headings.append(Vector2.RIGHT.rotated(shot.rotation + shot.lob_tilt()))
	field.effect_root.child_entered_tree.disconnect(born)
	_check(headings.size() >= 6, "the lob was in the air for %d frames - nothing to read" % headings.size())
	if headings.size() >= 6:
		var early: Vector2 = headings[1]
		var late: Vector2 = headings[headings.size() - 2]
		_check(early.y < -0.15, "a lob left its tower pointing %s - level, not up its arc" % early)
		_check(late.y > 0.15, "a lob came down pointing %s - level, not into its body" % late)
	RunState.set_phase(RunState.Phase.PREPARATION)
	GameDirector.run_active = false
	run.queue_free()
	for _f: int in 4:
		await get_tree().process_frame
	_finished += 1


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[shot-facing] " + why)
