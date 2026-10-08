class_name GuardArc
extends Node2D

## **What a raised shield looks like on the ground** (owner, 2026-10-08: "Unable
## to raise shield with Y or standing still"). The guard worked and nothing on
## screen said so: a raised shield slowed the walk and took its share of blows
## with no picture at all. This is the picture - an arc in front of the Warden
## as wide as the shield guards, dim for the whole span and bright for what it
## can still take, flaring on a block and burning red while a broken one rests.
##
## A look: it reads the hero and changes nothing.

var hero: Hero = null
var _shown: float = 0.0
var _flash: float = 0.0
var _perfect: bool = false
var _drew: bool = false


func _ready() -> void:
	name = "GuardArc"
	z_index = -1
	z_as_relative = true


## A blow met: bright for a moment, gold for a perfect guard.
func flash(perfect: bool = false) -> void:
	_flash = 1.0
	_perfect = perfect


## How shown it is now, for the gate.
func shown() -> float:
	return _shown


func _process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	var broken: bool = hero.guard_ratio() < 0.0
	var wanted: float = 1.0 if hero.is_guarding() or broken else 0.0
	_shown = move_toward(_shown, wanted, delta * Balance.GUARD_ARC_EASE)
	_flash = maxf(_flash - delta / Balance.GUARD_ARC_FLASH_SECONDS, 0.0)
	if _shown > 0.001 or _drew:
		queue_redraw()


func _draw() -> void:
	_drew = _shown > 0.001
	if not _drew:
		return
	var kind: GearData = hero.shield_kind()
	if kind == null:
		return
	var span: float = deg_to_rad(clampf(kind.guard_arc, 20.0, 340.0))
	var centre: float = hero.facing_vector().angle()
	var ratio: float = hero.guard_ratio()
	var broken: bool = ratio < 0.0
	var radius: float = Balance.GUARD_ARC_RADIUS
	var whole: PackedVector2Array = _arc(centre, span, radius)
	var base: Color = Balance.GUARD_ARC_BROKEN_COLOUR if broken else Balance.GUARD_ARC_COLOUR
	draw_polyline(whole, Color(base, 0.22 * _shown), Balance.GUARD_ARC_WIDTH * 2.2, true)
	if not broken and ratio > 0.0:
		draw_polyline(_arc(centre, span * clampf(ratio, 0.0, 1.0), radius),
			Color(base, 0.75 * _shown), Balance.GUARD_ARC_WIDTH, true)
	if _flash > 0.0:
		var flare: Color = Balance.SHIELD_PERFECT_COLOUR if _perfect else Color(1.0, 0.98, 0.9)
		draw_polyline(_arc(centre, span, radius + 4.0 * _flash), Color(flare, 0.85 * _flash),
			Balance.GUARD_ARC_WIDTH * (1.0 + _flash), true)


## The arc laid on the ground: flattened, because the camera looks down and
## slightly along.
func _arc(centre: float, span: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps: int = maxi(int(span / 0.12), 4)
	for step: int in steps + 1:
		var angle: float = centre - span * 0.5 + span * float(step) / float(steps)
		points.append(Vector2(cos(angle), sin(angle) * Balance.GUARD_ARC_FLATTEN) * radius)
	return points
