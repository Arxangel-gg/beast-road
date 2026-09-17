class_name MountRig
extends Node2D

## **The horse under the rider** (owner brief, 2026-09-17).
##
## A child of the hero that draws whatever is saddled, at the hero's own feet,
## behind the hero's sprite. It is *presentation and placement* and nothing
## else: the riding itself - the speed, the wind, the refusal to fight, the
## dismount on attack - lives on `Hero`, so turning this node off leaves a
## Warden who still rides and simply cannot be seen doing it.
##
## **Sheets first, base sprite second, nothing third.** A mount's art is a
## sheet per state at `art/mounts/mount_<id>_<state>.png`, rows = the eight
## facings in engine index order, columns = frames - the same packing
## `HeroAnimator` reads and the same tool builds. With no sheet it falls back to
## the single painting at `MountData.get_sprite_path()`, flipped for the western
## facings; with neither it draws nothing and says nothing. That is the rule the
## whole art pipeline is built on (CLAUDE.md §4): a partial art pass degrades to
## a stiller picture rather than to a blank screen.
##
## **The rider is lifted by `sprite.offset`, deliberately.** `SpriteAnimator`
## owns the hero sprite's `position`, `scale` and `rotation` and puts the bounce,
## the lean and the footfall squash there; a second writer on any of those three
## is the sway-and-wobble bug this project has already shipped once. `offset` is
## a fourth channel nothing else on the hero touches, so the seat and the juice
## cannot fight.

const CELL_W: int = 192
const CELL_H: int = 192
const DIRECTION_COUNT: int = 8

## What each state plays at, and whether it repeats. A gallop is the walk sheet
## driven faster when no gallop sheet exists, for the same reason the Warden's
## sprint falls back to the walk: a missing sheet must not be a missing feature.
const STATES: Dictionary = {
	"idle": {"fps": 6.0, "loop": true},
	"walk": {"fps": 11.0, "loop": true},
	"gallop": {"fps": 16.0, "loop": true},
}

## The hero's own sprite, so the seat can be applied to it.
var rider: Sprite2D = null

var _sprite: Sprite2D = null
var _kind: MountData = null
var _sheets: Dictionary = {}
var _base: Texture2D = null
var _state: String = ""
var _frame: float = 0.0
var _frames_in_state: int = 1
var _direction: int = 2
var _speed_scale: float = 1.0
var _bob: float = 0.0
## The pool the horse stands in. Its own, because the rider's was measured off
## the hero's sprite at `_ready` and stays at the Warden's feet - which is
## right, and leaves the animal underneath them standing on nothing. On a
## field where every torch, tower and rabbit casts one, that reads as the
## horse floating.
var _shadow: Sprite2D = null
## How tall the animal actually is, in its own pixels, and how far its feet
## sit above the bottom of the cell. **Measured off the art rather than
## assumed from the canvas**, because a 192 cell holds a horse of about 150
## with headroom above it - so a seat taken as a share of the *cell* puts the
## rider a hand's width out of the saddle, and nothing but a photograph would
## ever say so. This project has spent six passes on exactly that mistake with
## Yuri's tail; measure the output.
var _content_height: float = 0.0
var _content_floor: float = 0.0
var _seat_applied: float = 0.0
## How far up the Warden has climbed, 0 at the stirrup and 1 in the saddle.
##
## `Balance.MOUNT_UP_SECONDS` was a clock with nothing on the end of it: the
## rider was teleported into the seat on the frame the key was pressed and the
## time was spent doing nothing anybody could see. The climb is that time
## drawn. Getting *off* has no counterpart on purpose - the owner's rule is
## that attacking dismounts and the fight starts where you stood, so a
## dismount anybody waits for is a swing that does not land.
var _climb: float = 1.0


func _ready() -> void:
	name = "MountRig"
	# Behind the rider from every angle. A top-down-ish camera never shows the
	# horse in front of the person on it, so this needs no per-facing decision.
	z_index = -1
	_sprite = Sprite2D.new()
	_sprite.name = "Mount"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	visible = false


## Puts a mount under the rider, or takes it away with null.
func show_mount(kind: MountData) -> void:
	if kind == _kind:
		visible = kind != null
		return
	_kind = kind
	_sheets.clear()
	_base = null
	_state = ""
	if kind == null:
		visible = false
		_cast_shadow(null)
		_seat(0.0)
		return
	for state: String in STATES:
		var path: String = "res://art/mounts/mount_%s_%s.png" % [kind.id, state]
		if ResourceLoader.exists(path):
			_sheets[state] = load(path) as Texture2D
	var base: String = kind.get_sprite_path()
	if ResourceLoader.exists(base):
		_base = load(base) as Texture2D
	if _sheets.is_empty() and _base == null:
		# Nothing drawn and nothing said. A mount with no art is a Warden who
		# moves faster and looks the same, which is a content gap rather than a
		# fault - and an error here would print once a frame.
		visible = false
		_cast_shadow(null)
		_seat(0.0)
		return
	_measure(kind)
	_sprite.region_enabled = not _sheets.is_empty()
	_sprite.scale = Vector2.ONE * kind.art_scale
	visible = true
	_cast_shadow(kind)
	_climb = 0.0
	_apply_seat()
	play("idle")


## Reads the animal's own extent out of its base painting.
##
## Once per mount, on the painting rather than on a sheet cell, because every
## mount has a base painting by convention (CLAUDE.md §4) and it is the same
## animal drawn the same size. An unreadable image leaves the cell's own
## height, which is the old behaviour rather than a hole.
func _measure(kind: MountData) -> void:
	_content_height = float(CELL_H)
	_content_floor = 0.0
	if _base == null:
		return
	var picture: Image = _base.get_image()
	if picture == null:
		return
	var used: Rect2i = picture.get_used_rect()
	if used.size.y <= 0:
		return
	_content_height = float(used.size.y)
	# How much empty canvas sits under the hooves, which is what the cell's
	# bottom edge is being placed at.
	_content_floor = float(picture.get_height() - used.end.y)


## The pool under the hooves, sized from the art rather than from a constant,
## so a pony's is smaller than a warhorse's without anybody authoring two.
func _cast_shadow(kind: MountData) -> void:
	if _shadow != null and is_instance_valid(_shadow):
		_shadow.queue_free()
	_shadow = null
	if kind == null:
		return
	var wide: float = float(CELL_W) if not _sheets.is_empty() \
		else (float(_base.get_width()) if _base != null else 0.0)
	# The node sits at the hero's ground contact, so the ground is zero here.
	_shadow = ShadowKit.add_contact_sized(self,
		wide * kind.art_scale * Balance.SHADOW_WIDTH, 0.0)


## Which way it is pointing. Same index order as `HeroAnimator`, because the
## rider and the mount have to turn together and two orders is one of them
## eventually being read as the other.
func set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	var step: float = TAU / float(DIRECTION_COUNT)
	_direction = posmod(int(round(direction.angle() / step)), DIRECTION_COUNT)
	if _sheets.is_empty():
		# The fallback painting has one facing, so it is mirrored - which is
		# safe here in a way it is not for the roster, because a horse carries
		# no shield and no horn. See the facing rule in CLAUDE.md.
		_sprite.flip_h = direction.x < -0.001


func play(state: String) -> void:
	var wanted: String = state
	if not _sheets.has(wanted):
		# A gallop with no sheet of its own is the walk, faster. Anything else
		# with no sheet holds whatever was showing.
		wanted = "walk" if state == "gallop" and _sheets.has("walk") else ""
	if wanted.is_empty() or _state == wanted:
		return
	_state = wanted
	_frame = 0.0
	var sheet: Texture2D = _sheets[wanted] as Texture2D
	_frames_in_state = maxi(int(sheet.get_width() / CELL_W), 1)


## How fast the legs go, against the authored rate.
func set_speed_scale(scale: float) -> void:
	_speed_scale = clampf(scale, 0.3, 2.4)


func _process(delta: float) -> void:
	if not visible or _sprite == null or _kind == null:
		return
	# **The bob is drawn rather than animated**, for the reason the sheets are
	# kept neutral: a rise and fall baked into eight frames is eight frames this
	# project has to generate twice, and the engine can do it for a sine.
	# The climb first, because the seat is measured from it.
	if _climb < 1.0:
		_climb = minf(_climb + delta / maxf(Balance.MOUNT_UP_SECONDS, 0.01), 1.0)
	_bob += delta * Balance.MOUNT_BOB_RATE * _speed_scale
	var lift: float = -absf(sin(_bob)) * Balance.MOUNT_BOB_HEIGHT * _speed_scale
	if _sheets.is_empty():
		_sprite.texture = _base
		_sprite.offset = Vector2(0.0, -float(_base.get_height()) * 0.5)
		_sprite.position = Vector2(0.0, lift)
		_apply_seat(lift)
		return
	if _state.is_empty() or not _sheets.has(_state):
		return
	var config: Dictionary = STATES[_state] as Dictionary
	_frame += delta * float(config["fps"]) * _speed_scale
	if _frame >= float(_frames_in_state):
		_frame = fmod(_frame, float(_frames_in_state)) if bool(config["loop"]) \
			else float(_frames_in_state) - 1
	_sprite.texture = _sheets[_state] as Texture2D
	_sprite.region_rect = Rect2(
		float(int(_frame) * CELL_W), float(_direction * CELL_H),
		float(CELL_W), float(CELL_H))
	# The cell's feet sit at the node, which is the hero's ground contact, so
	# the horse stands where the Warden was standing rather than half in it.
	_sprite.offset = Vector2(0.0, -float(CELL_H) * 0.5)
	_sprite.position = Vector2(0.0, lift)
	_apply_seat(lift)


## How tall the mount is drawn, in world units. The seat is a share of it.
func _height() -> float:
	if _kind == null:
		return 0.0
	return _content_height * _kind.art_scale


func _apply_seat(lift: float = 0.0) -> void:
	if _kind == null:
		_seat(0.0)
		return
	# From the hooves up: the empty canvas under the animal first, then the
	# share of the animal itself. Measured from the cell's bottom edge, which
	# is where the sprite is anchored.
	var floor_gap: float = _content_floor * _kind.art_scale
	# **Eased rather than linear**, and out of a cubic: a rider who rose at a
	# constant rate reads as an elevator. Fast off the ground and settling into
	# the seat is what swinging a leg over looks like at this size.
	var risen: float = 1.0 - pow(1.0 - _climb, 3.0)
	_seat((-(floor_gap + _height() * _kind.seat + Balance.MOUNT_RIDER_LIFT)
		+ lift) * risen)


## Writes the rider's lift, and takes it away again on the way down.
##
## Remembered rather than assumed, because the hero's sprite may carry an offset
## of its own one day and clearing this to zero would quietly take that with it.
func _seat(y: float) -> void:
	# **Validity, not just null.** `_exit_tree` calls this to put the rider
	# back down, and a hero being freed frees its sprite too - touching a
	# freed object throws in Godot, which is the fault `Battlefield._process`
	# shipped once with a companion and flooded the log with.
	if rider == null or not is_instance_valid(rider):
		return
	if is_equal_approx(y, _seat_applied):
		return
	rider.offset.y += y - _seat_applied
	_seat_applied = y


## How far into the saddle the Warden has climbed, 0 to 1. For the gate: a
## climb stuck at zero leaves the rider standing at the horse's feet for the
## whole ride, which is visible in play and invisible to every number.
func climbed() -> float:
	return _climb


func _exit_tree() -> void:
	_seat(0.0)
