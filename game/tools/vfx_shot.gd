extends Node2D

## The two shared particles, drawn large enough to judge.
##
## `ring` and `spark` carry roughly three quarters of the effects in the game
## between them, and both grew an authored texture on 2026-09-09 that sits under
## the procedural motion rather than replacing it. Nothing automatic can tell
## whether that layering *looks* right - the art gates only ever prove a file
## exists and is not a placeholder - so this exists to be looked at.
##
## Two mistakes it caught immediately, both invisible to any assertion: the ring
## bloom scaled by its canvas rather than its drawn width and sat a fifth of a
## radius inside the polyline, reading as two rings; and the spark mote, sized
## the same wrong way, came out two pixels across and simply was not there.
##
## The muzzle flashes are here too, fired three frames before the capture: they
## decay to nothing in about a quarter of a second, so anything later is an
## empty floor and anything earlier is four identical peak frames.
##
## Timing is the whole trick. Sparks live about a third of a second, so they are
## fired eight frames before the capture; rings live as long as they are told, so
## they are given four seconds and caught mid-flight where both layers overlap.
## An earlier version fired everything at once and photographed an empty floor.

func _ready() -> void:
	await get_tree().process_frame
	var world := Node2D.new()
	add_child(world)
	Vfx.bind_world(world)
	RenderingServer.set_default_clear_color(Color(0.07, 0.08, 0.10))

	Vfx.ring(Vector2(300, 240), 150.0, Color(1.0, 0.45, 0.15), 4.0, 4.0)
	Vfx.ring(Vector2(760, 240), 110.0, Color(0.33, 0.72, 0.78), 4.0, 3.0)
	Vfx.ring(Vector2(1180, 240), 170.0, Color(0.55, 0.95, 0.45), 4.0, 6.0)

	for _f: int in 100:
		await get_tree().process_frame
	for i: int in 4:
		Vfx.spark(Vector2(300 + i * 300, 700), Color(1.0, 0.75, 0.25) if i % 2 == 0
			else Color(0.45, 0.8, 1.0), 10, Vector2.ZERO, 200.0)
	for _f: int in 8:
		await get_tree().process_frame

	# The four elemental muzzle flashes, mid-decay, one per element and aimed
	# four different ways so the rotation can be judged as well as the art.
	for i: int in 4:
		Vfx.muzzle(Vector2(300 + i * 300, 940),
			Vector2.RIGHT.rotated(TAU * float(i) / 8.0),
			TowerData.element_colour(i), i)
	for _f: int in 3:
		await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var out: String = OS.get_environment("SHOT_OUT")
	if out.is_empty():
		out = "user://vfx_shot.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("[vfx-shot] wrote %s" % out)
	get_tree().quit()
