class_name SetAura
extends Node2D

## What wearing a whole matched set looks like.
##
## **Owner brief, 2026-09-15:** *"Wearing a full set should have a visual vfx
## game juicy effect on players!"*
##
## A slow ring of motes turning at the wearer's feet in the set's own colour,
## breathing once every `GEAR_SET_AURA_PERIOD`. It is the one thing in the game
## that says *you finished a set* without a panel being open, which is the whole
## reason a set is worth assembling rather than a checklist to tick.
##
## **It is read by nothing.** No number, no roll, no message: turn this node off
## and the run is byte-identical. That is the fog's bound, the rank sheen's, the
## phenotype's and the elemental death's, and the reason is the same - it can be
## given away on a weak machine, and `Graphics.particle_scale` gives it away.
##
## **It asks rather than listens.** Equipment cannot change during a run - the
## stash is a between-runs screen - so a signal per change would be a wire for
## an event that happens nowhere, and `Modifiers.completed_set()` is cheap and
## cannot go stale the way a cached answer can. Asked on a slow clock rather
## than every frame for the same reason the flames redraw at 30Hz.

## How often the worn set is re-read, in seconds. Equipment does not change
## mid-run, so this is a formality rather than a poll - but a formality that
## costs nothing is how a screen and a field stay agreed.
const RE_READ: float = 0.75

## How many segments the ring is drawn with. Enough that it reads as a curve
## at the zoom the camera actually uses rather than as a polygon.
const RING_STEPS: int = 40

var _set: GearSetData = null
var _clock: float = 0.0
var _ask_in: float = 0.0


func _ready() -> void:
	name = "SetAura"
	z_as_relative = true
	z_index = -1
	visible = false
	set_process(true)
	_look()


func _process_measured(delta: float) -> void:
	_clock += delta
	_ask_in -= delta
	if _ask_in <= 0.0:
		_ask_in = RE_READ
		_look()
	if visible:
		queue_redraw()


## Which set, if any, is being worn in full right now.
func _look() -> void:
	var found: GearSetData = Modifiers.completed_set()
	var wanted: bool = found != null and Graphics.particle_scale() > 0.0
	if found != _set or wanted != visible:
		# **The moment it completes, once.** The ring of motes at the feet is
		# what a finished set *is*; this is the beat it arrives on, and it
		# fires only on the change - a sheet played every re-read would be
		# eight a second for as long as the set is worn.
		if found != null and _set == null:
			Vfx.forge_play("set_motes", global_position,
				Balance.SET_AURA_ARRIVAL_REACH, found.aura_colour)
		_set = found
		visible = wanted
		queue_redraw()


## The set being worn in full, or null. For the gate and for the screens.
func worn_set() -> GearSetData:
	return _set if visible else null


func _draw_measured() -> void:
	if _set == null:
		return
	var breath: float = 0.5 + 0.5 * sin(TAU * _clock
		/ maxf(Balance.GEAR_SET_AURA_PERIOD, 0.1))
	var radius: float = Balance.GEAR_SET_AURA_RADIUS * (0.92 + 0.08 * breath)
	var tint: Color = _set.aura_colour
	var flat: float = Balance.GEAR_SET_AURA_FLATTEN
	# The ring itself, faint, on the ground rather than around the body: a halo
	# at chest height reads as a status effect, and this is not one.
	#
	# **A polyline rather than `draw_arc`**, because an arc is a true circle
	# and this is a shape lying on the ground. Drawn as one it stood up like a
	# hoop around the Warden's knees while the motes rode the flattened
	# ellipse below it - two halves of one ring disagreeing about which way
	# the ground faces. Seen in `set_aura_shot` and by nothing else.
	var hoop := PackedVector2Array()
	for step: int in RING_STEPS + 1:
		var edge: float = TAU * float(step) / float(RING_STEPS)
		hoop.append(Vector2(cos(edge) * radius, sin(edge) * radius * flat))
	draw_polyline(hoop,
		Color(tint.r, tint.g, tint.b, tint.a * (0.18 + 0.12 * breath)),
		2.0, true)
	# And the motes going round it, on that same ellipse.
	var count: int = maxi(3, int(round(6.0 * Graphics.particle_scale())))
	for index: int in count:
		var turn: float = TAU * float(index) / float(count) \
			+ _clock * 0.9
		var at := Vector2(cos(turn) * radius, sin(turn) * radius * flat)
		var lit: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(turn * 2.0 + _clock * 2.2))
		draw_circle(at, 2.4 * (0.7 + 0.3 * breath),
			Color(tint.r, tint.g, tint.b, tint.a * lit))


## `FrameProfile` bucket "d_set_aura": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_set_aura", started)


## `FrameProfile` bucket "p_set_aura": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_set_aura", started)
