extends Node

## **Photographs the party's pings** (2026-10-07): four marks round the Warden
## on a real field - here, attack, danger and help - and the wheel open with
## the pointer leaning toward a spoke. A gate holds what a ping does; only a
## picture says whether a mark reads at play zoom and the wheel is legible.
##
##   tools/perf_offscreen.sh <profile> res://tools/ping_shot.tscn
##
## Written to `user://ping_marks.png` and `user://ping_wheel.png`.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0)
		return
	MetaState.hold_saves()
	RunState.reset(false, 20261008)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 30:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.sky().events_enabled = false
	# A fresh road opens in the morning; only the fog has to be lifted.
	if field.fog() != null:
		field.fog().reveal_all()
	var warden: Hero = field.hero
	warden.global_position = field.town_position() + Vector2(0.0, 420.0)
	var pings: PingField = field.ping_field()
	for _frame: int in 20:
		await get_tree().process_frame
	var at: Vector2 = warden.global_position
	EventBus.pinged.emit(1, "here", at + Vector2(-220.0, -60.0))
	EventBus.pinged.emit(2, "attack", at + Vector2(200.0, -140.0))
	EventBus.pinged.emit(3, "danger", at + Vector2(240.0, 120.0))
	EventBus.pinged.emit(4, "help", at + Vector2(-160.0, 170.0))
	await get_tree().create_timer(0.7).timeout
	await _save("user://ping_marks.png")
	var screen: Vector2 = get_viewport().get_visible_rect().size * 0.5
	pings.begin_hold(screen, at, false)
	var lean: Vector2 = pings.wheel.centre() + Vector2(70.0, -70.0)
	pings.wheel.pointer = func() -> Vector2: return lean
	await get_tree().create_timer(0.3).timeout
	await _save("user://ping_wheel.png")
	pings.cancel_hold()
	MetaState.resume_saves()
	get_tree().quit(0)


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))
	print("[ping-shot] ", path)
