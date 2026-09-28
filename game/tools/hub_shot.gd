## Photographs the Hold's *screen* - the room with its bar, its prompt, its
## markers and the Warden's card - at noon and at midnight, and measures the
## interface against the room in both.
##
##   godot --path game res://tools/hub_shot.tscn
##
## `hold_shot` photographs the yard alone, and the fault of 2026-09-28 (owner:
## *"The Hold gets a dark overlay cast over everything including the UIs"*)
## was the hour's tint reaching the interface - which a photograph of a yard
## with no interface in it can never show. This stands the real `HubScreen` up
## and reads two rectangles off the frame: a button's, which may be graded by
## `UiTint`'s own night floor and no further, and the room's, which must darken.
##
## **Never headless.** There is no frame to read.
extends Node

const SIZE := Vector2i(1600, 900)

var _hub: HubScreen = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[hub-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260917)
	_hub = HubScreen.new()
	add_child(_hub)
	await get_tree().process_frame
	_hub.open()
	await get_tree().process_frame
	var bar: float = -1.0
	var room: float = -1.0
	for hour: String in ["noon", "midnight"]:
		DayNight._apply(0.30 if hour == "noon" else 0.92)
		for _settle: int in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = get_viewport().get_texture().get_image()
		var path: String = "user://hub_shot_%s.png" % hour
		frame.save_png(ProjectSettings.globalize_path(path))
		print("[hub-shot] %s -> %s" % [hour, ProjectSettings.globalize_path(path)])
		var bar_now: float = _mean(frame, _bar_rect())
		var room_now: float = _mean(frame, Rect2i(SIZE.x / 2 - 200, SIZE.y / 2 - 60, 400, 120))
		print("[hub-shot] %s: bar %.3f, room %.3f" % [hour, bar_now, room_now])
		if bar < 0.0:
			bar = bar_now
			room = room_now
		else:
			print("[hub-shot] midnight against noon: bar %.2fx, room %.2fx - %s"
				% [bar_now / maxf(bar, 0.001), room_now / maxf(room, 0.001),
					"the interface keeps its own light" if bar_now >= bar * UiTint.SHADE_FLOOR * UiTint.PLATE
						and room_now < room * 0.8
					else "the hour reaches the interface, or the room is not following the hour"])
	_hub.close()
	await get_tree().process_frame
	Sfx.stop_immediately()
	get_tree().quit(0)


## The first button of the bar, in screen pixels - a plate the room's tint
## must not reach. The whole top strip would read the yard between the
## buttons and call the interface dim. Falls back to a strip along the top.
func _bar_rect() -> Rect2i:
	var bar: Node = _hub.find_child("Bar", true, false)
	if bar != null and bar.get_child_count() > 0 and bar.get_child(0) is Control:
		var rect: Rect2 = (bar.get_child(0) as Control).get_global_rect()
		return Rect2i(rect.position, rect.size).intersection(Rect2i(Vector2i.ZERO, SIZE))
	return Rect2i(0, 0, SIZE.x, 80)


static func _mean(frame: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y, 2):
		for x: int in range(rect.position.x, rect.end.x, 2):
			total += frame.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(float(count), 1.0)
