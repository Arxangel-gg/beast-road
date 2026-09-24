class_name WrathZones
extends Node2D

## Ground a disaster leaves charged.
##
## Owner brief, 2026-09-14, by way of the ChatGPT notes: "players may actually
## want to build toward the disaster instead of always fleeing from it". A
## strike leaves a storm core, a blaze or a stone leaves burning ground, a
## flood at its height leaves a basin, a quake leaves a fault - and for a
## while the towers of that element standing on it are overcharged. The
## catastrophe empowers the matching element, which is what makes flirting
## with it a decision rather than a tax.
##
## Bounded: no more than `ZONE_MAX` stand at once and the oldest goes, a zone
## lasts `ZONE_SECONDS`, and a second of the same kind over the first renews
## it rather than doubling it. What a zone does to a tower is one number
## (`ZONE_TOWER_BUFF` at the centre, less toward the edge) on a figure the
## tower already has, which is the bound every addition here is held to.
##
## The host opens them and tells the guest (`coop_wrath_zone_opened`); each
## machine runs its own clock, which drifts by nothing anyone can see. Drawn
## with `_draw` rather than a shader so a headless gate can count them.

## Each: {kind, element, at, radius, left, total, colour}
var zones: Array[Dictionary] = []
## How many were ever opened this act. For the gate.
var opened: int = 0
var _mirror: bool = false
var _pulse: float = 0.0
var _drew: bool = false


func _ready() -> void:
	name = "WrathZones"
	z_as_relative = false
	z_index = Balance.ZONE_Z
	_mirror = Coop.is_guest()
	EventBus.coop_wrath_zone_opened.connect(_on_opened_elsewhere)
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void: clear())


## The host opens charged ground of a kind at a point. Returns whether it did;
## a kind that names no element leaves nothing.
func open(kind_id: String, at: Vector2, radius: float, seconds: float = Balance.ZONE_SECONDS) -> bool:
	if _mirror:
		return false
	return _open(kind_id, at, radius, seconds, true)


func _open(kind_id: String, at: Vector2, radius: float, seconds: float, tell: bool) -> bool:
	var kind: WrathEventData = ContentDB.wrath_event(kind_id)
	if kind == null or kind.element < 0 or radius <= 0.0:
		return false
	# The same kind already over this ground is renewed and widened, never
	# doubled: two storm cores on one spot would be one buff counted twice.
	for zone: Dictionary in zones:
		if String(zone["kind"]) != kind_id:
			continue
		if (zone["at"] as Vector2).distance_to(at) < float(zone["radius"]) * 0.8:
			zone["left"] = maxf(float(zone["left"]), seconds)
			zone["total"] = maxf(float(zone["total"]), seconds)
			zone["radius"] = maxf(float(zone["radius"]), radius)
			return true
	while zones.size() >= Balance.ZONE_MAX:
		zones.pop_front()
	zones.append({"kind": kind_id, "element": kind.element, "at": at, "radius": radius,
		"left": seconds, "total": seconds, "colour": kind.colour})
	opened += 1
	Vfx.ring(at, radius, Color(kind.colour, 0.9), 0.9, 6.0)
	Vfx.spark(at, kind.colour, 12, Vector2.UP, 200.0)
	if tell:
		EventBus.wrath_zone_opened.emit(kind_id, at, radius, seconds)
	if not kind.announce.is_empty():
		EventBus.sky_warned.emit(kind.announce, kind.announce_title)
	queue_redraw()
	return true


func _on_opened_elsewhere(kind_id: String, at: Vector2, radius: float, seconds: float) -> void:
	if _mirror:
		_open(kind_id, at, radius, seconds, false)


## How charged the ground is for an element at a point: 1 at a zone's
## centre, falling toward its edge, 0 off any. The strongest zone counts,
## never the sum.
func boost_at(element: int, at: Vector2) -> float:
	var best: float = 0.0
	for zone: Dictionary in zones:
		if int(zone["element"]) != element:
			continue
		var radius: float = float(zone["radius"])
		var away: float = (zone["at"] as Vector2).distance_to(at)
		if away <= radius:
			best = maxf(best, 1.0 - away / maxf(radius, 1.0) * 0.6)
	return best


## The kind of charged ground under a point, or "" for none.
func kind_at(at: Vector2) -> String:
	for zone: Dictionary in zones:
		if (zone["at"] as Vector2).distance_to(at) <= float(zone["radius"]):
			return String(zone["kind"])
	return ""


func count() -> int:
	return zones.size()


func clear() -> void:
	zones.clear()
	queue_redraw()


func _process_measured(delta: float) -> void:
	if zones.is_empty():
		if _drew:
			_drew = false
			queue_redraw()
		return
	_pulse += delta
	for index: int in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[index]
		zone["left"] = float(zone["left"]) - delta
		if float(zone["left"]) <= 0.0:
			zones.remove_at(index)
	queue_redraw()


## A soft disc, a breathing ring at the edge, and three short arcs turning
## inside it - enough to say "this ground is different" without a texture,
## in the kind's own colour so a player learns the four at a glance.
func _draw_measured() -> void:
	_drew = not zones.is_empty()
	for zone: Dictionary in zones:
		var at: Vector2 = zone["at"]
		var radius: float = float(zone["radius"])
		var left: float = float(zone["left"])
		var total: float = maxf(float(zone["total"]), 1.0)
		var fade: float = minf(minf((total - left) / 1.5, 1.0), left / 5.0)
		fade = clampf(fade, 0.0, 1.0)
		var colour: Color = zone["colour"]
		var alpha: float = fade * (0.22 + 0.06 * sin(_pulse * 2.0))
		draw_circle(at, radius, Color(colour, alpha * 0.5))
		draw_circle(at, radius * 0.45, Color(colour, alpha * 0.35))
		var breathe: float = radius * (0.95 + 0.03 * sin(_pulse * 1.3))
		draw_arc(at, breathe, 0.0, TAU, 56, Color(colour, alpha * 1.8), 3.0, true)
		for spoke: int in 3:
			var from: float = _pulse * 0.7 + float(spoke) * TAU / 3.0
			draw_arc(at, radius * 0.62, from, from + 0.9, 14, Color(colour, alpha * 1.3), 2.0, true)


## `FrameProfile` bucket "d_wrath_zones": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_wrath_zones", started)


## `FrameProfile` bucket "p_wrath_zones": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_wrath_zones", started)
