class_name MountCooldownRing
extends Control

## The ring on the ride button while a thrown rider waits for the saddle
## (owner, 2026-09-21: *"a UI icon with a progress ring visible ONLY while the
## cooldown runs"*).
##
## **It draws one clock and reads one function.** `Hero.mount_cooldown_ratio`
## is the throw's cooldown and nothing else - not the remount delay, not the
## climb into the saddle - so this appears when a blow put the Warden on their
## feet and at no other time. The HUD toggles `visible` off that ratio every
## frame; a ring left showing at zero would be a warning about nothing.
##
## **The icon is the horse itself**, cropped from its own idle sheet facing
## south-east - the same cell the stable previews show - so the ring says
## which animal is waiting without a second painting anybody has to author.
## With no sheet it falls back to the base painting, and with neither it is a
## ring around nothing, which is still a ring.
##
## A `Control` with a `_draw` rather than a stack of nodes: it is a child of a
## button that is itself laid out by the action bar, and a thing that is not in
## the layout cannot collide with anything in it (`layout_check` ignores what a
## widget contains). Same argument as `BarName`.

const RING_WIDTH: float = 3.0
const RING_COLOUR := Color("ffcf76")
const TRACK_COLOUR := Color(1.0, 1.0, 1.0, 0.16)
const DISC_COLOUR := Color(0.06, 0.05, 0.04, 0.72)
const ICON_SHARE: float = 0.72
const ARC_POINTS: int = 40

## 1 the moment the rider was thrown, 0 when the saddle is open.
var ratio: float = 0.0
var _icon: Texture2D = null
var _icon_region: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Picks the picture for the animal that threw its rider.
func show_for(kind: MountData) -> void:
	_icon = null
	_icon_region = Rect2()
	if kind == null:
		return
	var sheet: String = "res://art/mounts/mount_%s_idle.png" % kind.id
	if ResourceLoader.exists(sheet):
		_icon = load(sheet) as Texture2D
		if _icon != null:
			# Rows are the eight facings in engine index order; south-east is
			# index 1, the facing every stable preview uses.
			_icon_region = Rect2(0.0, float(MountRig.CELL_H),
				float(MountRig.CELL_W), float(MountRig.CELL_H))
			return
	var base: String = kind.get_sprite_path()
	if ResourceLoader.exists(base):
		_icon = load(base) as Texture2D
		if _icon != null:
			_icon_region = Rect2(Vector2.ZERO, _icon.get_size())


func _draw() -> void:
	var centre: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - RING_WIDTH * 0.5
	if radius <= 1.0:
		return
	draw_circle(centre, radius, DISC_COLOUR)
	if _icon != null and _icon_region.size.x > 0.0 and _icon_region.size.y > 0.0:
		var fit: float = radius * 2.0 * ICON_SHARE
		var scale_by: float = fit / maxf(_icon_region.size.x, _icon_region.size.y)
		var drawn: Vector2 = _icon_region.size * scale_by
		draw_texture_rect_region(_icon, Rect2(centre - drawn * 0.5, drawn), _icon_region)
	draw_arc(centre, radius, 0.0, TAU, ARC_POINTS, TRACK_COLOUR, RING_WIDTH, true)
	# The arc is what is *left* to wait, shrinking clockwise from the top, so
	# the ring empties as the saddle opens - a ring that filled up would read
	# as a charge rather than as a wait.
	var left: float = clampf(ratio, 0.0, 1.0)
	if left > 0.0:
		draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * left, ARC_POINTS,
			RING_COLOUR, RING_WIDTH, true)
