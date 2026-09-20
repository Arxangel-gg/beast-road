extends Node

var _failures: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 19092026)
	var world := Node2D.new()
	add_child(world)
	Vfx.bind_world(world)
	var sky := WeatherSky.new()
	world.add_child(sky)
	sky.set_process(false)
	var bolts := sky.get("_bolts") as Node2D
	sky.call("_on_lightning_seen", Vector2.ZERO, 80.0)
	_check(bolts.get_child_count() > 0, "strike did not draw")
	var line: Node = bolts.get_child(0)
	_check(line.get_instance_id() > 2147483647, "probe must exercise a 64-bit instance ID")
	get_tree().paused = true
	await get_tree().create_timer(1.0, true).timeout
	get_tree().paused = false
	_check(bolts.get_child_count() == 0, "lightning remained after its lifetime while paused")
	_check((Vfx.get("_container") as Node).get_child_count() == 0,
		"lightning impact particles remained while paused")
	for index: int in 12:
		sky.call("_draw_chain", Vector2.ZERO, Vector2(180.0, float(index) * 8.0))
	_check(bolts.get_child_count() == 36, "chain hops lost their glow/core layers")
	sky.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.5, true).timeout
	_check(bolts.get_child_count() == 0, "chain lightning remained after scope suspension")
	sky.call("_draw_bolt", Vector2.ZERO)
	sky.clear_bolts()
	await get_tree().process_frame
	await get_tree().create_timer(0.8, true).timeout
	_check(bolts.get_child_count() == 0, "cleared lightning reappeared in a return stroke")
	Vfx.bind_world(null)
	world.queue_free()
	await get_tree().process_frame
	MetaState.resume_saves()
	print("[lightning-lifetime] %s - seven lifetime and pause checks" % [
		"PASS" if _failures == 0 else "FAIL"])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error("[lightning-lifetime] " + message)
