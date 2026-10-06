extends Node
## Traces what becomes of a body a funnel lifts, in the three ways one can
## come down: thrown and surviving, killed in the air, and dropped by a funnel
## that died mid-carry. Diagnostic, never a gate - the owner reported a thrown
## body that "potentially died but kept walking to the city base, untargetable
## by towers and players but able to melee fight players and hit the city",
## and this prints every fact that decides each half of that sentence, twice a
## second, so the next report starts from a dump rather than a theory.
##
##   godot --headless --path game res://tools/tornado_ghost_trace.tscn
##
## What is printed a row: state, in the roster group, dying, the health, the
## pool's dead flag, process mode, visible, position, and whether the field's
## own broadphase (the one towers and the Warden share) can find it.

var _run: Run = null
var _field: Battlefield = null
var _sky: WeatherSky = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260924)
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
	_sky = _field.sky()
	_sky.events_enabled = false
	if _field.wave_director != null:
		_field.wave_director.stop()
	_field.hero.global_position = Vector2(0.0, 0.0)
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()
	await get_tree().process_frame

	await _scenario("dies on landing", 26.0, false)
	await _scenario("funnel dies mid-carry", 60.0, true)
	await _scenario("two funnels on one body", 60.0, false, true)

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	MetaState.resume_saves()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(0)


func _scenario(label: String, hp_scale: float, kill_funnel: bool, twin: bool = false) -> void:
	print("\n[ghost] === %s ===" % label)
	var at: Vector2 = _field.grid.lane_pocket_centre(3)
	var funnel: Tornado = _sky.spawn_tornado(at, at + Vector2(10.0, 0.0), 40.0)
	var second: Tornado = null
	if twin:
		second = _sky.spawn_tornado(at + Vector2(30.0, 0.0), at + Vector2(40.0, 0.0), 40.0)
	await get_tree().process_frame
	funnel.set_process(false)
	funnel.at = at
	funnel.position = at
	if second != null:
		second.set_process(false)
		second.at = at + Vector2(30.0, 0.0)
		second.position = second.at
	var catch: TornadoCatch = funnel.find_child("TornadoCatch", false, false) as TornadoCatch
	var body: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, hp_scale)
	body.global_position = at + Vector2(Balance.TORNADO_CATCH_RADIUS * 0.5, 0.0)
	body.health.died.connect(func(_from: Vector2) -> void:
		print("[ghost]   DIED: mode=%d carried=%s aloft=%d" % [body.process_mode,
			str(is_instance_valid(catch) and catch.carries(body)),
			(catch.get("_aloft") as Dictionary).size() if is_instance_valid(catch) else -1])
		print_stack())
	var started: int = Time.get_ticks_msec()
	var last_row: int = -1000
	var killed_funnel: bool = false
	var budget: int = int((Balance.TORNADO_LIFT_SECONDS + Balance.TORNADO_THROW_SECONDS + (9.0 if twin else 4.0)) * 1000.0)
	while Time.get_ticks_msec() - started < budget:
		await get_tree().process_frame
		var now: int = Time.get_ticks_msec() - started
		if kill_funnel and not killed_funnel and now > int(Balance.TORNADO_LIFT_SECONDS * 500.0):
			killed_funnel = true
			print("[ghost]   -> the funnel dies now")
			funnel.seconds_left = 0.0
			funnel.set_process(true)
			funnel._process(0.1)
		if now - last_row >= 250:
			last_row = now
			_row(now, body, catch)
	_row(Time.get_ticks_msec() - started, body, catch)
	if is_instance_valid(body):
		body.queue_free()
	for f: Tornado in [funnel, second]:
		if f != null and is_instance_valid(f) and f.is_processing() == false and not (f == funnel and killed_funnel):
			f.seconds_left = 0.0
			f.set_process(true)
			f._process(0.1)
	for _f: int in 5:
		await get_tree().process_frame


func _row(ms: int, body_node: Variant, catch_node: Variant) -> void:
	if body_node == null or not is_instance_valid(body_node):
		print("[ghost] %5d ms  body freed" % ms)
		return
	var body := body_node as Enemy
	var catch: TornadoCatch = (catch_node as TornadoCatch) if (catch_node != null and is_instance_valid(catch_node)) else null
	var carriers: int = 0
	for node: Node in get_tree().get_nodes_in_group("tornado_catch_probe"):
		pass
	for f: Node in _field.get_children():
		if f is Tornado:
			var c: Variant = f.get("_catch")
			if c != null and is_instance_valid(c) and (c as TornadoCatch).carries(body):
				carriers += 1
	var found: bool = false
	for near: Enemy in _field.enemies_near(body.global_position, 64.0):
		if near == body:
			found = true
	var slip: Vector2 = body.get("_slip")
	var knock: Vector2 = body.get("_knockback")
	print("[ghost] %5d ms  state=%-8s group=%s dying=%s hp=%.1f mode=%d carriers=%d pos=(%.0f,%.0f) found=%s death_left=%.2f stun=%.2f" % [
		ms, Enemy.State.keys()[body.get("_state")], str(body.is_in_group(Enemy.GROUP)),
		str(body.is_dying()), body.health.current_hp,
		body.process_mode, carriers,
		body.global_position.x, body.global_position.y, str(found),
		float(body.get("_death_left")), float(body.get("_hitstun_left"))])
