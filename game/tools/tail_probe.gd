class_name TailProbe
extends RefCounted

## Reads Yuri's tail against the hide it grows from, **off the rendered frame**.
##
## Shared by the two shot tools that can see the beast - `menu_shot` and
## `beast_shot` - because the owner reported the tail's grade in both scopes
## and a probe that lived in one of them measured half of the complaint.
##
## Seven passes compared the two *paintings* and an eighth compared the two
## `modulate` properties, and all eight agreed the tail was fine while the owner
## was looking at a grey limb on a warm animal. A child's own `modulate` always
## reads white whatever its parent is doing to it at draw time, and source art
## says nothing about what a shader or an inherited tint did to it afterwards.
## This reads the frame.
##
## **Three readings, and the middle one is the answer.** The limb is sampled
## along its own chain, the hide is sampled *at the join* - a small square of
## flank just inside the root, which is the paint the tail is meant to
## continue - and the flank is sampled around the body's centre for context.
## Comparing the limb against the body's centre was how the ninth pass measured
## a seventeen-percent gap that was mostly the difference between a haunch and
## a shoulder.

## Below this summed brightness a pixel is night sky, not paint.
const NEAR_BLACK: float = 0.16
## Into the flank from the root, in the art's own pixels: past the stub's fade
## (`BEAST_STUB_FADE_PX`) and well short of the hind leg at column 44.
const JOIN_INSET_PX: float = 40.0
## Half-size of the hide sample at the join, in art pixels.
const JOIN_REACH_PX: float = 10.0
## The share of the chain measured, from the root. The tip is a few pixels
## thick and its samples catch the sky beside it.
const ROOT_SHARE: float = 0.66


## The tail node, wherever the scene hung it. **A `Node2D`, not a `Sprite2D`**:
## a spline draws slices, and a cast to `Sprite2D` returned null over a tail
## plainly on screen for as long as the tail has been a spline.
static func find_tail(from: Node) -> CanvasItem:
	if from.name == &"Tail":
		return from as CanvasItem
	for child: Node in from.get_children():
		var found: CanvasItem = find_tail(child)
		if found != null:
			return found
	return null


## The body the tail hangs off: the tail's own parent, which is the one
## definition that cannot disagree with the scene.
static func find_body(from: Node) -> CanvasItem:
	var tail: CanvasItem = find_tail(from)
	return tail.get_parent() as CanvasItem if tail != null else null


## Prints the three readings and returns the limb's gap from the hide at the
## join: `{"hue": degrees, "lum": percent, "sat": difference}`. Empty when
## nothing lit could be measured. Call after `RenderingServer.frame_post_draw`.
static func report(viewport: Viewport, tail: CanvasItem, label: String) -> Dictionary:
	var body := tail.get_parent() as CanvasItem
	if body == null:
		print("[%s] the tail has no body to compare against" % label)
		return {}
	var frame: Image = viewport.get_texture().get_image()
	var grain: Vector2 = _frame_scale(viewport, frame)
	var limb: Dictionary = _paint_along(frame, tail, grain)
	var join: Dictionary = _paint_at_join(frame, tail, grain)
	var flank: Dictionary = _paint_in(frame, _screen_rect(body, frame, grain))
	if limb.is_empty() or join.is_empty():
		print("[%s] paint: nothing lit to measure" % label)
		return {}
	_say(label, "tail ", limb)
	_say(label, "join ", join)
	if not flank.is_empty():
		_say(label, "flank", flank)
	var hue_gap: float = absf(fposmod(float(limb["hue"]) - float(join["hue"]) + 180.0, 360.0) - 180.0)
	var lum_gap: float = (float(limb["lum"]) / maxf(float(join["lum"]), 0.0001) - 1.0) * 100.0
	var sat_gap: float = float(limb["sat"]) - float(join["sat"])
	print("[%s] paint  gap at the join: hue %.1f deg, lum %+.1f%%, sat %+.3f"
		% [label, hue_gap, lum_gap, sat_gap])
	return {"hue": hue_gap, "lum": lum_gap, "sat": sat_gap}


static func _say(label: String, what: String, paint: Dictionary) -> void:
	print("[%s] paint  %s rgb(%3d,%3d,%3d) hue %5.1f sat %.3f lum %.3f  (%d px)"
		% [label, what, int(paint["r"]), int(paint["g"]), int(paint["b"]),
			paint["hue"], paint["sat"], paint["lum"], int(paint["lit"])])


## **Screen space is the canvas transform, never the world.** The menu has no
## camera, so a node's global transform is its place on screen there; the
## beast scope has one, and the first reading taken through it sampled world
## coordinates as pixels and found nothing lit at all.
##
## **The photograph is not in the game's own units.** The frame comes back at
## the window's resolution and every node's global position is in the content
## scale under it; every sample taken without this factor was read at three
## quarters of the way to where it meant to look.
static func _frame_scale(viewport: Viewport, frame: Image) -> Vector2:
	var view: Vector2 = viewport.get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return Vector2.ONE
	return Vector2(float(frame.get_width()) / view.x,
		float(frame.get_height()) / view.y)


## The paint on the limb itself, gathered in small discs along its chain.
## A spline draws away from its origin, so a square centred there is mostly
## sky - and sky is blue, which is why two runs with and without a deliberate
## fault once reported byte-identical readings.
static func _paint_along(frame: Image, tail: CanvasItem, grain: Vector2) -> Dictionary:
	if not tail.has_method("chain"):
		return _paint_in(frame, _screen_rect(tail, frame, grain))
	var links: PackedVector2Array = tail.call("chain") as PackedVector2Array
	if links.is_empty():
		return _paint_in(frame, _screen_rect(tail, frame, grain))
	var to_screen: Transform2D = tail.get_global_transform_with_canvas()
	var root: Vector2 = _root_of(tail)
	var measured: int = maxi(int(float(links.size()) * ROOT_SHARE), 2)
	var total := Vector3.ZERO
	var lit: int = 0
	for index: int in measured:
		var at: Vector2 = (to_screen * (links[index] - root)) * grain
		for step: int in 81:
			var dx: int = step % 9 - 4
			var dy: int = step / 9 - 4
			var x: int = int(at.x) + dx * 2
			var y: int = int(at.y) + dy * 2
			if x < 0 or y < 0 or x >= frame.get_width() or y >= frame.get_height():
				continue
			var pixel: Color = frame.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b < NEAR_BLACK:
				continue
			total += Vector3(pixel.r, pixel.g, pixel.b)
			lit += 1
	return _summary(total, lit)


## The hide just inside the root: the flank the tail continues.
static func _paint_at_join(frame: Image, tail: CanvasItem, grain: Vector2) -> Dictionary:
	if not tail.has_method("chain"):
		return {}
	var links: PackedVector2Array = tail.call("chain") as PackedVector2Array
	if links.is_empty():
		return {}
	var to_screen: Transform2D = tail.get_global_transform_with_canvas()
	var scale: Vector2 = to_screen.get_scale() * grain
	var root: Vector2 = _root_of(tail)
	var centre: Vector2 = (to_screen * (links[0] - root + Vector2(JOIN_INSET_PX, 0.0))) * grain
	var reach: Vector2 = Vector2(JOIN_REACH_PX, JOIN_REACH_PX) * scale
	var box := Rect2i(Vector2i(centre - reach), Vector2i(reach * 2.0))
	return _paint_in(frame, box)


## **The chain is in the painting's own pixels, with the root at `root_in_art`,
## and the node's origin is that root.** The first cut of this probe walked the
## chain as though it were local and read 52 lit pixels of night sky as the
## tail - the same three-quarters-of-the-way mistake as the frame scale, in a
## different coordinate.
static func _root_of(tail: CanvasItem) -> Vector2:
	if tail.has_method("root_in_art"):
		return tail.call("root_in_art") as Vector2
	return Vector2.ZERO


## A node's rectangle on the screen, in pixels of the captured frame: a square
## around its origin, sized by how big it is drawn.
static func _screen_rect(item: CanvasItem, frame: Image, grain: Vector2) -> Rect2i:
	var view: Vector2 = Vector2(frame.get_width(), frame.get_height())
	var on_canvas: Transform2D = item.get_global_transform_with_canvas()
	var here: Vector2 = on_canvas.origin * grain
	var scale: Vector2 = on_canvas.get_scale() * grain
	var reach: float = maxf(40.0, 26.0 * maxf(scale.x, scale.y))
	return Rect2i(Vector2i(maxf(here.x - reach, 0.0), maxf(here.y - reach, 0.0)),
		Vector2i(minf(reach * 2.0, view.x), minf(reach * 2.0, view.y)))


## The mean colour of the lit pixels in a rectangle. Near-black pixels are
## skipped: both subjects stand against a night sky, and averaging the sky in
## reports two very similar blacks and calls it a match.
static func _paint_in(frame: Image, box: Rect2i) -> Dictionary:
	var total := Vector3.ZERO
	var lit: int = 0
	for y: int in range(maxi(box.position.y, 0), mini(box.end.y, frame.get_height())):
		for x: int in range(maxi(box.position.x, 0), mini(box.end.x, frame.get_width())):
			var pixel: Color = frame.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b < NEAR_BLACK:
				continue
			total += Vector3(pixel.r, pixel.g, pixel.b)
			lit += 1
	return _summary(total, lit)


static func _summary(total: Vector3, lit: int) -> Dictionary:
	if lit == 0:
		return {}
	var mean: Vector3 = total / float(lit)
	var paint := Color(mean.x, mean.y, mean.z)
	return {
		"r": mean.x * 255.0, "g": mean.y * 255.0, "b": mean.z * 255.0,
		"hue": paint.h * 360.0, "sat": paint.s, "lum": paint.v, "lit": lit,
	}
