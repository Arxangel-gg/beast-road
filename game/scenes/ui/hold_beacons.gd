class_name HoldBeacons
extends Control

## A marker over every door of the Hold, and a louder one over every door with
## something waiting behind it.
##
## Owner, 2026-09-27: *"Interactables at the Hold need to have clear and
## aesthetic indicators for interaction that are further attention grabbing and
## have more indicators to get the player to come interact with it to check the
## notifications/see what's new."* The Hold marked only what was already in reach
## - a ring on the ground at the Warden's feet - so a door across the square was
## a painting of a building until somebody walked up to it by chance.
##
## **Three levels of saying so, from quiet to loud.** Every door wears a small
## floating marker, so what can be used is never a guess. Walking near one names
## it. A door with something waiting (`HoldNews`) wears a bouncing badge with a
## count, a pillar of light off its roof, rings rolling out along the ground and
## a few rising motes - and when it is off the screen, an arrow at the edge
## points to it. The prompt line says how many doors are waiting.
##
## **Drawn in screen space**, so the words stay sharp at every zoom, from the
## yard's own marks (`HoldYard.beacon_marks`). It reads the yard and `HoldNews`
## and writes nothing: a picture of the account, never a change to it.

var yard: HoldYard = null
## The top of the room the yard is shown in - under the Hold's own bar - so an
## edge arrow never sits on a button. Set by the hub whenever it lays out.
var room_top: float = 0.0

## What was laid out on the last frame, for the gate and the prompt: id ->
## `{at, foot, top, hot, count, lines, near, arrow, label}`. Laid out in
## `_process` rather than in `_draw` so it is measurable headless, where nothing
## is drawn.
var marks: Dictionary = {}

var _news: Dictionary = {}
var _news_left: float = 0.0
var _clock: float = 0.0
var _light: _Light = null


func _ready() -> void:
	name = "Beacons"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The light is its own canvas with an additive blend, drawn behind the
	# badges so a pillar brightens the ground and never washes a number out.
	_light = _Light.new()
	_light.beacons = self
	_light.show_behind_parent = true
	_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light.material = add
	add_child(_light)


## Asks every door again. Cheap - a handful of reads off the account - and done
## on a clock rather than every frame, and at once when the Hold comes back.
func refresh_news() -> void:
	_news.clear()
	_news_left = Balance.HOLD_NEWS_REFRESH
	if yard == null or not is_instance_valid(yard):
		return
	for mark: Dictionary in yard.beacon_marks():
		var lines: Array[Dictionary] = HoldNews.of(String(mark["id"]))
		if not lines.is_empty():
			_news[String(mark["id"])] = lines


## The lines waiting at one door, or none.
func news_of(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var got: Variant = _news.get(id, [])
	if got is Array:
		out.assign(got)
	return out


## How many doors have something waiting.
func waiting() -> int:
	return _news.size()


func _process(delta: float) -> void:
	if yard == null or not is_instance_valid(yard) or not is_visible_in_tree():
		return
	_clock += delta
	_news_left -= delta
	if _news_left <= 0.0:
		refresh_news()
	_layout()
	queue_redraw()
	_light.queue_redraw()


func _room() -> Rect2:
	var edge: float = Balance.HOLD_BEACON_EDGE
	var top: float = maxf(room_top, edge)
	return Rect2(Vector2(edge, top), Vector2(maxf(size.x - edge * 2.0, 1.0),
		maxf(size.y - top - Balance.HOLD_BEACON_FOOT_INSET, 1.0)))


func _layout() -> void:
	marks.clear()
	var to_screen: Transform2D = get_global_transform().affine_inverse() \
		* yard.get_global_transform()
	var warden: Vector2 = yard.warden_at()
	var room: Rect2 = _room()
	for mark: Dictionary in yard.beacon_marks():
		var id: String = String(mark["id"])
		var lines: Array[Dictionary] = news_of(id)
		var phase: float = float(absi(hash(id)) % 628) * 0.01
		var bob: float = sin(_clock * Balance.HOLD_BEACON_BOB_RATE + phase) \
			* Balance.HOLD_BEACON_BOB
		var top: Vector2 = to_screen * (mark["top"] as Vector2)
		var at: Vector2 = top + Vector2(0.0, -Balance.HOLD_BEACON_LIFT + bob)
		var hot: bool = not lines.is_empty()
		marks[id] = {
			"id": id,
			"label": String(mark["label"]),
			"at": at,
			"foot": to_screen * (mark["foot"] as Vector2),
			"top": top,
			"hot": hot,
			"count": HoldNews.count(lines),
			"lines": lines,
			"phase": phase,
			"near": warden.distance_to(mark["at"] as Vector2)
				<= Balance.HOLD_REACH * Balance.HOLD_BEACON_NEAR,
			"arrow": hot and not room.has_point(at),
			"edge": _edge_point(room, at),
		}


## Where on the room's rim the line from its middle toward `target` leaves it.
func _edge_point(room: Rect2, target: Vector2) -> Vector2:
	var middle: Vector2 = room.get_center()
	var away: Vector2 = target - middle
	if away.length_squared() < 1.0:
		return middle
	var half: Vector2 = room.size * 0.5 - Vector2.ONE * Balance.HOLD_BEACON_ARROW_SIZE
	var stretch: float = minf(absf(half.x / away.x) if absf(away.x) > 0.001 else INF,
		absf(half.y / away.y) if absf(away.y) > 0.001 else INF)
	return middle + away * minf(stretch, 1.0)


# --- Drawing ------------------------------------------------------------------


func _draw() -> void:
	var font: Font = get_theme_default_font()
	for id: String in marks:
		var mark: Dictionary = marks[id]
		if bool(mark["arrow"]):
			_draw_arrow(mark, font)
			continue
		if bool(mark["hot"]):
			_draw_badge(mark, font)
		else:
			_draw_marker(mark)
		if bool(mark["near"]):
			_draw_plate(mark, font)


## The quiet marker every door wears: a small gem turning over the roof.
func _draw_marker(mark: Dictionary) -> void:
	var at: Vector2 = mark["at"] as Vector2
	var near: bool = bool(mark["near"])
	var side: float = Balance.HOLD_BEACON_GEM * (1.3 if near else 1.0)
	var turn: float = 0.55 + 0.45 * absf(cos(_clock * 1.3 + float(mark["phase"])))
	var gem := PackedVector2Array([at + Vector2(0.0, -side), at + Vector2(side * turn, 0.0),
		at + Vector2(0.0, side), at + Vector2(-side * turn, 0.0)])
	var gold := Balance.HOLD_BEACON_GOLD
	var alpha: float = 0.95 if near else 0.62
	draw_colored_polygon(gem, Color(gold.r, gold.g, gold.b, alpha))
	gem.append(gem[0])
	draw_polyline(gem, Color(0.08, 0.06, 0.04, alpha), 2.0)


## The loud one: a round badge with the count, hopping, on a stem to its roof.
func _draw_badge(mark: Dictionary, font: Font) -> void:
	var hop: float = absf(sin(_clock * Balance.HOLD_BEACON_HOP_RATE
		+ float(mark["phase"]))) * Balance.HOLD_BEACON_HOP
	var at: Vector2 = (mark["at"] as Vector2) - Vector2(0.0, hop)
	var radius: float = Balance.HOLD_BEACON_BADGE
	var gold := Balance.HOLD_BEACON_GOLD
	var ink := Color(0.09, 0.06, 0.03)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-radius * 0.45, radius * 0.6),
		at + Vector2(radius * 0.45, radius * 0.6), at + Vector2(0.0, radius * 1.55)]), ink)
	draw_circle(at, radius + 3.0, ink)
	draw_circle(at, radius, gold)
	draw_circle(at + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.35,
		Color(1.0, 0.96, 0.82, 0.55))
	var count: int = int(mark["count"])
	var text: String = "!" if count <= 1 else ("9+" if count > 9 else str(count))
	var font_size: int = int(radius * 1.35)
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, at + Vector2(-extent.x * 0.5, extent.y * 0.32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## The door's name, and what is waiting there, over its marker.
func _draw_plate(mark: Dictionary, font: Font) -> void:
	var rows: Array[String] = [String(mark["label"])]
	for line: Dictionary in mark["lines"] as Array[Dictionary]:
		rows.append(String(line.get("text", "")))
	var sizes: Array[int] = []
	var wide: float = 0.0
	for index: int in rows.size():
		var font_size: int = 17 if index == 0 else 15
		sizes.append(font_size)
		wide = maxf(wide, font.get_string_size(rows[index], HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x)
	var line_height: float = 21.0
	var box := Vector2(wide + 22.0, line_height * float(rows.size()) + 10.0)
	var lift: float = Balance.HOLD_BEACON_BADGE * 2.4 if bool(mark["hot"]) \
		else Balance.HOLD_BEACON_GEM * 2.4
	var corner := (mark["at"] as Vector2) - Vector2(box.x * 0.5, lift + box.y)
	corner.x = clampf(corner.x, 4.0, maxf(size.x - box.x - 4.0, 4.0))
	corner.y = maxf(corner.y, room_top + 4.0)
	draw_rect(Rect2(corner, box), Color(0.05, 0.05, 0.04, 0.78))
	draw_rect(Rect2(corner, box), Color(Balance.HOLD_BEACON_GOLD, 0.7), false, 1.5)
	for index: int in rows.size():
		var colour: Color = Color("f2e6d0") if index == 0 else Color("9fd2b4")
		draw_string(font, corner + Vector2(11.0, 22.0 + line_height * float(index)),
			rows[index], HORIZONTAL_ALIGNMENT_LEFT, -1, sizes[index], colour)


## A door with something waiting that the view does not show: an arrow on the
## rim of the room pointing at it, carrying its badge.
func _draw_arrow(mark: Dictionary, font: Font) -> void:
	var at: Vector2 = mark["edge"] as Vector2
	var toward: Vector2 = ((mark["at"] as Vector2) - at).normalized()
	if toward.length_squared() < 0.5:
		toward = Vector2.UP
	var pulse: float = 1.0 + 0.12 * sin(_clock * 5.0 + float(mark["phase"]))
	var side: float = Balance.HOLD_BEACON_ARROW_SIZE * pulse
	var across := Vector2(-toward.y, toward.x)
	var tip: Vector2 = at + toward * side
	var ink := Color(0.09, 0.06, 0.03)
	var points := PackedVector2Array([tip, at - toward * side * 0.4 + across * side * 0.75,
		at - toward * side * 0.4 - across * side * 0.75])
	draw_colored_polygon(points, Balance.HOLD_BEACON_GOLD)
	points.append(points[0])
	draw_polyline(points, ink, 2.5)
	var badge: Vector2 = at - toward * side * 1.25
	draw_circle(badge, Balance.HOLD_BEACON_BADGE * 0.72 + 2.0, ink)
	draw_circle(badge, Balance.HOLD_BEACON_BADGE * 0.72, Balance.HOLD_BEACON_GOLD)
	var count: int = int(mark["count"])
	var text: String = "!" if count <= 1 else ("9+" if count > 9 else str(count))
	var font_size: int = int(Balance.HOLD_BEACON_BADGE)
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, badge + Vector2(-extent.x * 0.5, extent.y * 0.32), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## The additive half: a pillar of light off the roof, rings rolling out along the
## ground, and motes rising - for doors with something waiting, on screen.
func _paint_light(canvas: Control) -> void:
	var gold := Balance.HOLD_BEACON_GOLD
	var zoom: float = yard.scale.x if yard != null else 1.0
	var motes: int = maxi(int(round(3.0 * Graphics.particle_scale())), 0)
	for id: String in marks:
		var mark: Dictionary = marks[id]
		if not bool(mark["hot"]) or bool(mark["arrow"]):
			continue
		var phase: float = float(mark["phase"])
		var foot: Vector2 = mark["foot"] as Vector2
		var crown: Vector2 = (mark["top"] as Vector2) - Vector2(0.0, Balance.HOLD_BEACON_LIFT * 2.0)
		var glow: float = Balance.HOLD_BEACON_PILLAR_ALPHA \
			* (0.75 + 0.25 * sin(_clock * 2.1 + phase))
		var half: float = Balance.HOLD_BEACON_PILLAR_WIDTH * 0.5
		var lit := Color(gold.r, gold.g, gold.b, glow)
		var clear := Color(gold.r, gold.g, gold.b, 0.0)
		var faint := Color(gold.r, gold.g, gold.b, glow * 0.12)
		# Two halves, each bright down the middle and clear at its edge, and
		# fading as it climbs: a shaft of light has no hard side.
		for side_sign: float in [-1.0, 1.0]:
			canvas.draw_polygon(PackedVector2Array([foot, foot + Vector2(half * side_sign, 0.0),
				crown + Vector2(half * side_sign * 0.7, 0.0), crown]),
				PackedColorArray([lit, clear, clear, faint]))
		# Rings along the ground, flattened as every ring at the feet is.
		for ring: int in 2:
			var age: float = fmod(_clock * 0.55 + float(ring) * 0.5 + phase, 1.0)
			var radius: float = lerpf(Balance.HOLD_BEACON_RING_FROM,
				Balance.HOLD_BEACON_RING_TO, age) * zoom
			canvas.draw_set_transform(foot, 0.0, Vector2(1.0, 0.36))
			canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40,
				Color(gold.r, gold.g, gold.b, (1.0 - age) * 0.55), 3.0)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# A soft disc behind the badge.
		var badge: Vector2 = mark["at"] as Vector2
		_soft_disc(canvas, badge, Balance.HOLD_BEACON_BADGE * 2.3,
			Color(gold.r, gold.g, gold.b, 0.34))
		var climb: float = maxf(foot.y - crown.y, 1.0)
		for mote: int in motes:
			var rise: float = fmod(_clock * 38.0 + float(mote) * climb / 3.0 + phase * 40.0, climb)
			var sway: float = sin(_clock * 2.3 + float(mote) * 2.1 + phase) * half * 0.6
			_soft_disc(canvas, foot + Vector2(sway, -rise), 5.0,
				Color(1.0, 0.9, 0.6, 0.55 * (1.0 - rise / climb)))


func _soft_disc(canvas: Control, at: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array([at])
	var colours := PackedColorArray([colour])
	var rim := Color(colour.r, colour.g, colour.b, 0.0)
	for step: int in 17:
		var angle: float = TAU * float(step) / 16.0
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
		colours.append(rim)
	for step: int in 16:
		canvas.draw_polygon(PackedVector2Array([points[0], points[step + 1], points[step + 2]]),
			PackedColorArray([colours[0], colours[step + 1], colours[step + 2]]))


class _Light extends Control:
	var beacons: HoldBeacons = null

	func _draw() -> void:
		if beacons != null:
			beacons._paint_light(self)
