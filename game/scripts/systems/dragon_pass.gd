class_name DragonPass
extends Node2D

## Something enormous crosses the sky, and what it passes over catches.
##
## **Owner brief, 2026-09-15:** dragons breathing fire in their land and flying
## states, affecting the environment, and world events the map knows about.
## `docs/IDEAS_REVIEW_2026-09-15.md` triaged the forwarded proposal and put
## dragons *after* the trail, as **a world-event system rather than a creature**:
## "the document is right that they should be the rarest thing in the game and
## that the map should know one is there". This is that event.
##
## **It is the earth's, not a fight.** A pass is rolled beside the quake, the
## tornado, the meteor and the wildfire, off the same hidden wrath, and it obeys
## the same two rules those do:
##
## - **It is telegraphed.** The line is said and every animal on the field bolts
##   before the shadow arrives. A blow from nowhere is the thing the forwarded
##   notes warned against and the thing every event here is built against.
## - **It moves only numbers the earth already has.** The dragon never strikes
##   anything: everything it does goes through `Wildfire.ignite_near` and
##   `Climate.add_heat`, so the fire it leaves behaves exactly as the earth's own
##   lightning fire does - it spreads by dryness, it is bounded by
##   `WILDFIRE_MAX_FIRES`, and it costs the player no wrath, because a fire they
##   did not light is the cycle rather than the debt.
##
## **And no new wire numbers.** The warning travels on `wrath_warned`, which the
## quake and the tornado already use, and every plant it lights travels as
## `coop_wildfire_lit`, which the wildfire already sends. A guest draws the
## shadow from the same warning and burns the same plants when told.

const ART: String = "res://art/vfx/dragon_overhead.png"

var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var field: Battlefield = null
var wildfire: Wildfire = null

## How many plants this pass set alight. For the gate.
var lit: int = 0

var _art: Texture2D = null
var _left: float = 0.0
var _flying: bool = false
var _since_fire: float = 0.0
var _mirror: bool = false


func _ready() -> void:
	name = "DragonPass"
	z_as_relative = false
	z_index = Balance.DRAGON_Z
	_mirror = Coop.is_guest()
	_left = Balance.DRAGON_WARNING_SECONDS
	if ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = from
	Sfx.play("sfx_thunder_far", -2.0)
	set_process(true)


func _process(delta: float) -> void:
	_left -= delta
	if not _flying:
		if _left <= 0.0:
			_flying = true
			_left = Balance.DRAGON_PASS_SECONDS
		queue_redraw()
		return
	var travelled: float = 1.0 - clampf(_left / maxf(Balance.DRAGON_PASS_SECONDS,
		0.01), 0.0, 1.0)
	global_position = from.lerp(to, travelled)
	_since_fire += delta
	if _since_fire >= Balance.DRAGON_FIRE_INTERVAL:
		_since_fire = 0.0
		_breathe()
	queue_redraw()
	if _left <= 0.0:
		queue_free()


## What it leaves under itself.
##
## **The host burns and the guest watches**, which is the wildfire's own rule:
## `ignite_near` announces each plant it lights and the guest lights the same
## one when told. A guest that burned on its own would be a second opinion about
## which forest is on fire.
func _breathe() -> void:
	if _mirror or wildfire == null:
		return
	if wildfire.ignite_near(global_position, Balance.DRAGON_FIRE_RADIUS,
			Balance.DRAGON_FIRE_CHANCE, false):
		lit += 1
	# And the ground under it remembers the heat, which is what makes the fire
	# it leaves spread the way a hot day's does.
	if field != null:
		var weather: Climate = field.climate()
		if weather != null:
			weather.add_heat(global_position, Balance.DRAGON_HEAT,
				Balance.DRAGON_FIRE_RADIUS * 1.4)


## The shadow first, then the thing casting it.
##
## Drawn rather than lit: a real light of this size on a field that already
## carries a hundred torches is a frame nobody can afford, and a shadow is what
## a player actually reads as something passing over.
func _draw() -> void:
	if _art == null:
		return
	var size: Vector2 = _art.get_size() * Balance.DRAGON_SCALE
	var turn: float = (to - from).angle() + PI * 0.5
	if not _flying:
		# The warning: the shadow alone, growing in as it comes out of the sun.
		var coming: float = 1.0 - clampf(_left / maxf(
			Balance.DRAGON_WARNING_SECONDS, 0.01), 0.0, 1.0)
		_shadow(size, turn, coming * 0.55)
		return
	_shadow(size, turn, 0.55)
	draw_set_transform(Vector2(0.0, -Balance.DRAGON_HEIGHT), turn, Vector2.ONE)
	draw_texture_rect(_art, Rect2(-size * 0.5, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shadow(size: Vector2, turn: float, strength: float) -> void:
	draw_set_transform(Vector2.ZERO, turn, Vector2.ONE)
	draw_texture_rect(_art, Rect2(-size * 0.5, size), false,
		Color(0.0, 0.0, 0.0, clampf(strength, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Drive the whole pass by hand. For the gate, which has no minutes to spend.
func advance(seconds: float, steps: int = 40) -> void:
	var step: float = seconds / maxf(float(steps), 1.0)
	for _tick: int in steps:
		if not is_instance_valid(self):
			return
		_process(step)
