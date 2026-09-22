class_name HoldGlow
extends Node2D

## The Hold's light and its air: a lamp in every window, and embers over the
## fires.
##
## Owner, 2026-09-22: *"the Hold is also lacking a lot of aesthetic visuals and
## lighting and juice compared to our battlefield."* Photographed first
## (`hold_shot`), which is what turned that into specific things:
##
## - **Only the square fire and the wall torches were lit.** The furnace, the
##   market, the stash, the Chronicle and the rest each carry a painted window
##   and none of them put anything on the ground, so at dusk the settlement
##   went dark while a single campfire burned in the middle of it.
## - **The fires threw nothing.** A flame with no embers above it is a decal;
##   the road's camp fires have thrown them since the camps were built.
##
## **The bound is every decoration's here: nothing reads any of it.** No step,
## no reach, no door, no roll and no packet. `Graphics.particle_scale()` takes
## the embers to nothing, and the Hold is then exactly the Hold it was.
##
## **A third thing belongs here and is not here: a contact shadow under
## everything that stands.** Nothing in the yard casts one, which is most of
## why the place still reads a little like a collage - the road's towers,
## bodies and animals have had one since they were drawn. It is recorded
## rather than left for somebody to start over on, because seven arrangements
## were written and photographed and not one put a pixel on the screen:
##
##   a triangle fan with per-vertex alpha; nested `draw_circle` rings under a
##   `draw_set_transform`; nested `draw_colored_polygon` ellipses; a
##   `draw_texture_rect` of the torches' own radial gradient; a child
##   `Sprite2D` at `z_index = -1`; the same sprite with `show_behind_parent`;
##   and all of those again reading the owners live each frame rather than
##   from a list handed over once, after that list turned out to hold freed
##   nodes by the second frame.
##
## What is known, so the next attempt starts from evidence rather than from an
## eighth primitive: `draw_circle` for the embers works on this very node
## every frame; the shadow pass reported eighteen live owners; `to_local` is
## the right conversion, because the yard is *scaled* by the Hold's zoom and a
## difference of two global positions is therefore in screen units; and
## forcing `z_index = 100` with full alpha changed nothing, so it is neither
## the data nor the layering. **Draw one `draw_circle` at a hard-coded yard
## coordinate and find out where it lands.**

## An ember's life, how far it drifts up in that time, and how many a fire may
## have going at once. Small numbers on purpose: this is the air over a fire,
## not a fountain.
const EMBER_LIFE: Vector2 = Vector2(1.1, 2.3)
const EMBER_RISE: Vector2 = Vector2(46.0, 92.0)
const EMBER_SPREAD: float = 16.0
const EMBER_SIZE: Vector2 = Vector2(1.4, 2.8)
const EMBER_PER_FIRE: int = 5
const EMBER_HOT: Color = Color(1.0, 0.72, 0.34, 0.9)
const EMBER_COOL: Color = Color(0.86, 0.32, 0.14, 0.0)

## What a lit window is worth. Warm and small: this is light spilling out of a
## door, not a second bonfire, and a reach any larger turns the square into one
## flat pool with no shape in it.
const WINDOW_TINT: Color = Color(1.0, 0.84, 0.58)
const WINDOW_REACH: float = 210.0
const WINDOW_ENERGY: float = 0.72
const WINDOW_FLICKER: float = 0.05
## The furnace is the exception and is meant to be: it is the brightest thing
## in the Hold after the bonfire, and a smithy that is not is a smithy nobody
## can find.
const FURNACE_TINT: Color = Color(1.0, 0.62, 0.30)
const FURNACE_REACH: float = 330.0
const FURNACE_ENERGY: float = 1.15
const FURNACE_FLICKER: float = 0.22
## Which stations light up, and how far above their own foot the window sits.
## A building with no fire and no lamp in its painting is not given one - the
## road out and the Warden's Stone are stone in a field.
const LIT: Dictionary = {
	"smithy": Vector2(0.0, -74.0),
	"anvil": Vector2(0.0, -26.0),
	"vendor": Vector2(0.0, -58.0),
	"stash": Vector2(0.0, -62.0),
	"chronicle": Vector2(0.0, -70.0),
	"leaderboard": Vector2(0.0, -92.0),
	"codex": Vector2(0.0, -66.0),
	"pen": Vector2(0.0, -54.0),
	"stable": Vector2(0.0, -58.0),
	"ledger": Vector2(0.0, -30.0),
}

var _embers: Array[Dictionary] = []
var _lights: Array[PointLight2D] = []
var _own := RandomNumberGenerator.new()
## The fires this draws air over, given rather than found: the yard owns them
## and a node that went looking would be a second opinion about where they are.
var _fires: Array[Node2D] = []


func _ready() -> void:
	name = "HoldGlow"
	# Decoration's own dice. A draw on a named stream moves every roll after
	# it, which is why the ponds' glints and the raccoon's foraging each carry
	# one of these rather than asking the run.
	_own.seed = absi(hash("hold-glow"))
	z_index = 0
	set_process(true)


## How many windows are lit, so a gate can ask.
func lit() -> int:
	return _lights.size()


## Lights the windows of whatever stations this yard built. Stations are handed
## in rather than looked up, for the reason the fires are.
func light_stations(stations: Array[Dictionary]) -> void:
	for station: Dictionary in stations:
		var id: String = String(station.get("id", ""))
		if not LIT.has(id):
			continue
		var node := station.get("node") as Node2D
		if node == null:
			continue
		var furnace: bool = id == "smithy" or id == "anvil"
		# `LightKit` rather than a hand-rolled `PointLight2D`: it owns the
		# falloff texture, the additive blend that lights a sprite instead of
		# washing it out, and the flicker. A second copy of any of those is a
		# window here that behaves unlike every torch on the road.
		var lamp := Node2D.new()
		lamp.position = LIT[id] as Vector2
		node.add_child(lamp)
		var light: PointLight2D = LightKit.add_light(lamp,
			FURNACE_TINT if furnace else WINDOW_TINT,
			FURNACE_REACH if furnace else WINDOW_REACH,
			FURNACE_ENERGY if furnace else WINDOW_ENERGY,
			FURNACE_FLICKER if furnace else WINDOW_FLICKER)
		if light != null:
			_lights.append(light)


## The fires whose air this draws embers into.
func over_fires(fires: Array) -> void:
	_fires.clear()
	for fire: Variant in fires:
		var node := fire as Node2D
		if node != null:
			_fires.append(node)


func _process(delta: float) -> void:
	_tick_embers(delta)
	queue_redraw()


func _tick_embers(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for ember: Dictionary in _embers:
		ember["left"] = float(ember["left"]) - delta
		if float(ember["left"]) <= 0.0:
			continue
		ember["at"] = (ember["at"] as Vector2) + (ember["way"] as Vector2) * delta
		alive.append(ember)
	_embers = alive

	if Graphics.particle_scale() <= 0.01 or _fires.is_empty():
		return
	var want: int = int(round(float(_fires.size() * EMBER_PER_FIRE)
		* Graphics.particle_scale()))
	var tries: int = maxi(want - _embers.size(), 0)
	for _spawn: int in mini(tries, 2):
		var fire: Node2D = _fires[_own.randi() % _fires.size()]
		if not is_instance_valid(fire):
			continue
		var how_big: float = maxf(fire.scale.x, 0.2)
		var born: Dictionary = {
			"at": fire.position + Vector2(
				_own.randf_range(-EMBER_SPREAD, EMBER_SPREAD) * how_big,
				-6.0 * how_big),
			"way": Vector2(_own.randf_range(-12.0, 12.0),
				-_own.randf_range(EMBER_RISE.x, EMBER_RISE.y)) * how_big,
			"life": _own.randf_range(EMBER_LIFE.x, EMBER_LIFE.y),
			"size": _own.randf_range(EMBER_SIZE.x, EMBER_SIZE.y) * how_big,
		}
		born["left"] = born["life"]
		_embers.append(born)


func _draw() -> void:
	for ember: Dictionary in _embers:
		var share: float = float(ember["left"]) / maxf(float(ember["life"]), 0.01)
		var tint: Color = EMBER_COOL.lerp(EMBER_HOT, share)
		draw_circle(ember["at"] as Vector2, float(ember["size"]) * share, tint)
