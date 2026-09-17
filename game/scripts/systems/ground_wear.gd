class_name GroundWear
extends RefCounted

## **Earth worn through grass, with a soft edge.**
##
## `draw_rect` and `draw_circle` cannot have one: a single colour for the whole
## shape *is* a hard edge, which is the fourth thing in this project to be
## rebuilt on that finding after the swim sheen, the menu campfire and the
## blood. Both shapes here are triangle arrays with a colour per vertex - solid
## along the middle, transparent at the rim - wearing the ground's own texture.
##
## **One definition, three callers.** The Hold's paths and station doors, the
## pens and the stable paddock all want the same thing, and the Hold had already
## paid for two of them disagreeing: `HoldYard._draw_pens` laid textured earth
## and `PenYard._draw` painted an opaque rectangle straight over it, so four pens
## went back to reading as panes of glass with nobody having changed either
## function. Two copies of a look drift exactly as two copies of a rule do.
##
## **The texture is read in world coordinates**, so a patch is the same soil as
## the ground it is worn into and does not swim when the shape moves. That needs
## the *canvas item* to wrap rather than clamp - a node drawing these must set
## `texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED`, or every UV past one
## clamps to the sheet's edge column and the whole patch comes out as one flat
## smear of whatever happens to be there.
##
## **A tint multiplies, so soil is taken by lifting rather than by darkening.**
## The first cut darkened the mossy sheet toward brown and photographed as moss
## in shadow: a path nobody would read as a path. Red up and green down is the
## whole difference between grass and the earth under it.


## A trodden route: a spine with a width, feathered into the grass either side.
##
## `lift` answers how far a point is drawn above its own place - the Hold's
## shelves - and a segment whose two ends disagree is **not drawn at all**. That
## gap is where the stair is, and a strip stretched down a bank face would be a
## path painted over a cliff.
static func tread(item: RID, soil: Texture2D, spine: Array, wide: float,
		tint: Color, lift: Callable = Callable()) -> void:
	if soil == null or spine.size() < 2:
		return
	var sheet := Vector2(maxf(float(soil.get_width()), 1.0),
		maxf(float(soil.get_height()), 1.0))
	var rim := Color(tint.r, tint.g, tint.b, 0.0)
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	var lifts: PackedFloat32Array = []
	for index: int in spine.size():
		var here: Vector2 = spine[index] as Vector2
		var ahead: Vector2 = spine[mini(index + 1, spine.size() - 1)] as Vector2
		var behind: Vector2 = spine[maxi(index - 1, 0)] as Vector2
		var way: Vector2 = ahead - behind
		if way.length_squared() < 0.01:
			way = Vector2.RIGHT
		var side: Vector2 = way.normalized().orthogonal()
		# The rim wanders, from the point's own place rather than from a roll: a
		# path of constant width is a road, and nothing here was surveyed.
		var swell: float = wide * (0.80 + 0.30
			* absf(sin(here.x * 0.011 + here.y * 0.017)))
		var up: float = 0.0 if not lift.is_valid() else float(lift.call(here))
		var at: Vector2 = here + Vector2(0.0, up)
		lifts.append(up)
		for rail: int in 3:
			var corner: Vector2 = at + side * float(rail - 1) * swell
			points.append(corner)
			colours.append(tint if rail == 1 else rim)
			uvs.append(Vector2(corner.x / sheet.x, corner.y / sheet.y))
	for index: int in spine.size() - 1:
		if not is_equal_approx(lifts[index], lifts[index + 1]):
			continue
		var a: int = index * 3
		var c: int = a + 3
		indices.append_array([a, a + 1, c, a + 1, c + 1, c,
			a + 1, a + 2, c + 1, a + 2, c + 2, c + 1])
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(item, indices, points,
		colours, uvs, PackedInt32Array(), PackedFloat32Array(), soil.get_rid())


## A patch worn bare - inside a pen, in front of a door, at the feet of somebody
## who stands in one place all day.
##
## Flattened, for the reason every ellipse in this project is: the camera looks
## down and slightly along, so a true circle on the floor reads as a hoop
## standing up. Its outline wobbles from the angle alone, so a patch is a shape
## the ground wore rather than one somebody stamped.
static func patch(item: RID, soil: Texture2D, at: Vector2, wide: float,
		tint: Color, squash: float = 0.58) -> void:
	if soil == null or wide <= 0.0:
		return
	var sheet := Vector2(maxf(float(soil.get_width()), 1.0),
		maxf(float(soil.get_height()), 1.0))
	var steps: int = 22
	var points: PackedVector2Array = [at]
	var colours: PackedColorArray = [tint]
	var uvs: PackedVector2Array = [Vector2(at.x / sheet.x, at.y / sheet.y)]
	var indices: PackedInt32Array = []
	var rim := Color(tint.r, tint.g, tint.b, 0.0)
	for step: int in steps + 1:
		var angle: float = TAU * float(step) / float(steps)
		var reach: float = wide * (0.84 + 0.22
			* sin(angle * 3.0 + at.x * 0.01))
		var corner: Vector2 = at + Vector2(cos(angle) * reach,
			sin(angle) * reach * squash)
		points.append(corner)
		colours.append(rim)
		uvs.append(Vector2(corner.x / sheet.x, corner.y / sheet.y))
	for step: int in steps:
		indices.append_array([0, step + 1, step + 2])
	RenderingServer.canvas_item_add_triangle_array(item, indices, points,
		colours, uvs, PackedInt32Array(), PackedFloat32Array(), soil.get_rid())
