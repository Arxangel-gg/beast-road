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

## **The sheet cell, which is bigger than a mount's base painting.**
##
## A gallop reaches further than a walk - the steppe horse's widest pose spans
## 193 - so the cell is the room the widest pose needs rather than an asset
## size. `tools/pack_mount_frames.py` writes them at exactly this and puts
## every pose's feet on the cell's own bottom edge, which is why the reader
## below can put the hooves on the node without measuring anything.
const CELL_W: int = 224
const CELL_H: int = 224
const DIRECTION_COUNT: int = 8

## The animal drawn a second time over its rider's legs. See the shader for
## why this is one sprite twice rather than a second painting.
const OVERLAY_SHADER: String = "res://scripts/shaders/mount_overlay.gdshader"
## How far the fade takes to close, as a share of the sprite's rect.
const OVERLAY_FEATHER: float = 0.10

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
var _breath: float = 0.0
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
## How tall the rider is drawn, in their own pixels. Measured once from the
## sprite they are on, because the Warden's sheet cell is a good deal taller
## than the Warden.
var _rider_height: float = 0.0
## How wide the animal is drawn, for the seat's horizontal offset, and which
## way it is currently pointing along the screen's x.
var _content_width: float = 0.0
var _lean: float = 0.0
var _seat_across: float = 0.0
## The animal's near side, drawn above the rider. Only ever stood up when
## there *is* a rider: a horse in a paddock has no legs to hide.
var _over: Sprite2D = null
var _over_material: ShaderMaterial = null
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

	# **Above the rider**, which is the whole point: the rig itself sits at
	# z -1 so the animal is behind the person, and this one copy of it comes
	# back over their legs. Two, because one sprite cannot be both behind a
	# thing and in front of it.
	_over = Sprite2D.new()
	_over.name = "MountNearSide"
	_over.centered = true
	_over.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_over.z_index = 2
	_over.visible = false
	if ResourceLoader.exists(OVERLAY_SHADER):
		_over_material = ShaderMaterial.new()
		_over_material.shader = load(OVERLAY_SHADER) as Shader
		_over_material.set_shader_parameter("feather", OVERLAY_FEATHER)
		_over.material = _over_material
	add_child(_over)
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
		_seat_sideways(0.0)
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
		_seat_sideways(0.0)
		return
	_measure(kind)
	_measure_rider()
	_sprite.region_enabled = not _sheets.is_empty()
	# **Un-mirrored when there are sheets.** `set_facing` only ever writes
	# `flip_h` for the single-painting fallback, so a mount swapped from one
	# that had no sheets to one that has them would keep whichever way the
	# last fallback happened to be facing - and eight authored rows mirrored
	# is the 'facing backwards' report this project has answered seven times.
	if not _sheets.is_empty():
		_sprite.flip_h = false
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
	_content_width = float(CELL_W)
	_content_floor = 0.0
	# A packed sheet needs no measuring: the packer put the feet on the cell's
	# bottom edge and the animal is as tall as it is. Only the single-painting
	# fallback has margin to account for.
	if _base == null:
		return
	var picture: Image = _base.get_image()
	if picture == null:
		return
	var used: Rect2i = picture.get_used_rect()
	if used.size.y <= 0:
		return
	_content_height = float(used.size.y)
	_content_width = float(used.size.x)
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
	# Which way along the screen the animal is pointing, for the saddle's own
	# offset. Normalised so a body coming straight at the camera leans nowhere.
	_lean = direction.normalized().x
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
	# The climb first, because the seat is measured from it.
	if _climb < 1.0:
		_climb = minf(_climb + delta / maxf(Balance.MOUNT_UP_SECONDS, 0.01), 1.0)
	# **The bob is drawn rather than animated**, for the reason the sheets are
	# kept neutral: a rise and fall baked into eight frames is eight frames this
	# project has to generate twice, and the engine can do it for a sine.
	_bob += delta * Balance.MOUNT_BOB_RATE * _speed_scale
	var lift: float = -absf(sin(_bob)) * Balance.MOUNT_BOB_HEIGHT * _speed_scale
	_breath += delta * Balance.MOUNT_IDLE_BREATH_RATE * _speed_scale
	var inhale: float = sin(_breath) * Balance.MOUNT_IDLE_BREATH_AMOUNT if _state == "idle" else 0.0
	_sprite.scale = Vector2(1.0 - inhale * 0.3, 1.0 + inhale) * _kind.art_scale
	if _state == "idle":
		lift = 0.0
	if _sheets.is_empty():
		# **Dropped by the empty canvas under the animal.** A base painting has
		# margin below the hooves, so placing the texture's bottom edge on the
		# node left the horse floating that far above the ground the Warden is
		# standing on - true of every mount and visible in exactly one place, a
		# screenshot nobody had taken.
		_sprite.texture = _base
		_sprite.offset = Vector2(0.0, -float(_base.get_height()) * 0.5)
		_sprite.position = Vector2(0.0, lift + _content_floor * _kind.art_scale)
		_apply_seat(lift)
		return
	if _state.is_empty() or not _sheets.has(_state):
		# **The seat is applied before giving up on the frame.** A mount whose
		# `idle` sheet is missing while another state's exists plays nothing on
		# the frame it is mounted, and returning here without seating the rider
		# left them standing at the horse's feet for the whole ride - the exact
		# failure `mount_check.climbed()` was added to catch, reachable only
		# through a partial art pass, which is the thing this class is built to
		# survive.
		_apply_seat(lift)
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
	# **The cell's bottom edge is the ground line**, by construction: the packer
	# puts every pose's feet there. So placing the texture's bottom on the node
	# stands the horse exactly where the Warden was standing, with nothing to
	# measure and nothing that can drift between a walk and a gallop packed on
	# different days.
	_sprite.offset = Vector2(0.0, -float(CELL_H) * 0.5)
	_sprite.position = Vector2(0.0, lift)
	_apply_seat(lift)


## Copies the body onto the near-side overlay, and tells it where the saddle
## is.
##
## Copied rather than shared, because a `Sprite2D` is one node with one
## region: the same frame has to be submitted twice to be drawn at two
## depths. Everything that decides *which* frame stays in one place above -
## this only mirrors it, so the two can never come to disagree about which
## way the horse is facing.
func _drive_near_side(anchor: float) -> void:
	if _over == null:
		return
	# No rider, no legs to hide - a paddock horse pays nothing for this.
	if rider == null or not is_instance_valid(rider) or _kind == null:
		_over.visible = false
		return
	_over.visible = visible
	_over.texture = _sprite.texture
	_over.region_enabled = _sprite.region_enabled
	_over.region_rect = _sprite.region_rect
	_over.offset = _sprite.offset
	_over.position = _sprite.position
	_over.scale = _sprite.scale
	_over.flip_h = _sprite.flip_h
	_over.modulate = _sprite.modulate
	if _over_material != null:
		_over_material.set_shader_parameter("anchor",
			clampf(anchor, 0.0, 1.0 - OVERLAY_FEATHER))


## How tall the mount is drawn, in world units. The seat is a share of it.
func _height() -> float:
	if _kind == null:
		return 0.0
	return _content_height * _kind.art_scale


## How tall the rider actually is, measured off whatever sprite they are.
##
## The hero's cell is 160 and the Warden inside it is 99, so seating by the
## cell would put them half a body too high. Measured once per mount rather
## than per frame: a hero does not change size.
func _measure_rider() -> void:
	_rider_height = 0.0
	if rider == null or not is_instance_valid(rider) or rider.texture == null:
		return
	var picture: Image = rider.texture.get_image()
	if picture == null:
		return
	# **The cell, never the sheet.** The Warden is drawn from an eight-row
	# `HeroAnimator` sheet, so `texture` is 1512x1280 and its used rect is very
	# nearly all of it - which made the rider measure about 1270 tall, put their
	# hips 571 up, and seat them at the horse's feet. It was invisible because
	# the tool that photographed this used a single painting instead of the real
	# Warden; the owner spotted the wrong sprite and the bug was behind it.
	var cell: Rect2i = Rect2i(Vector2i.ZERO, picture.get_size())
	if rider.region_enabled:
		cell = Rect2i(rider.region_rect)
		cell = cell.intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	if cell.size.x <= 0 or cell.size.y <= 0:
		return
	var used: Rect2i = picture.get_region(cell).get_used_rect()
	_rider_height = float(used.size.y) * absf(rider.scale.y)


func _apply_seat(lift: float = 0.0) -> void:
	if _kind == null:
		_seat(0.0)
		_seat_sideways(0.0)
		return
	# **From the hooves up, and the hooves are now on the node.** The sprite
	# itself is dropped by whatever margin sits under the animal, so the seat is
	# a share of the animal and nothing else - adding the margin here as well
	# would count it twice.
	var floor_gap: float = 0.0
	# **Eased rather than linear**, and out of a cubic: a rider who rose at a
	# constant rate reads as an elevator. Fast off the ground and settling into
	# the seat is what swinging a leg over looks like at this size.
	# **The saddle meets the rider's hips, not their boots.** A hero sprite is
	# drawn from the feet up, so lifting by the saddle's own height put the
	# whole Warden above the horse with a gap under them - which is what
	# `mount_shot` photographed on all four mounts. A rider straddles: the hips
	# are at the saddle and the legs hang behind the barrel.
	var saddle: float = floor_gap + _height() * _kind.seat
	# **The same number the rider is lifted by, handed to the fade.** The near
	# side closes at the saddle, so the anchor is the saddle's own height read
	# down from the top of whatever rect the sprite is drawing - the cell for a
	# sheet, the painting for the fallback. Derived here rather than in the
	# shader so the two cannot disagree about where the rider is sitting.
	var rect: float = float(CELL_H) if not _sheets.is_empty() \
		else (float(_base.get_height()) if _base != null else float(CELL_H))
	_drive_near_side(1.0 - saddle / maxf(rect * _kind.art_scale, 1.0))
	# Re-measured while the rider is still climbing, because the hero's own
	# animator may not have put a frame on the sprite when the mount was shown -
	# a rider measured at zero would be seated as if they were all legs.
	if _rider_height <= 0.0 or _climb < 1.0:
		_measure_rider()
	var hips: float = _rider_height * Balance.MOUNT_RIDER_HIP
	var risen: float = 1.0 - pow(1.0 - _climb, 3.0)
	_seat((-(maxf(saddle - hips, 0.0) + Balance.MOUNT_RIDER_LIFT) + lift) * risen)
	# Behind the withers, along whichever way the animal is pointing.
	_seat_sideways(-_lean * _content_width * _kind.art_scale
		* Balance.MOUNT_SEAT_BACK * risen)


## Writes the rider's lift, and takes it away again on the way down.
##
## Remembered rather than assumed, because the hero's sprite may carry an offset
## of its own one day and clearing this to zero would quietly take that with it.
## The same as `_seat`, across. Its own applied value, so the two channels can
## be put back independently and neither can be left behind when the Warden
## gets down.
func _seat_sideways(x: float) -> void:
	if rider == null or not is_instance_valid(rider):
		return
	if is_equal_approx(x, _seat_across):
		return
	rider.offset.x += x - _seat_across
	_seat_across = x


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


## The sprite the animal is drawn on.
##
## Handed out so the paddock can put a coat on it - a phenotype is a material
## on the sprite, and the alternative was `StablePaddock` standing its own
## sprite and reimplementing the sheets, which is two readers of one packing
## and one of them eventually reading it wrong.
func body() -> Sprite2D:
	return _sprite


## How far into the saddle the Warden has climbed, 0 to 1. For the gate: a
## climb stuck at zero leaves the rider standing at the horse's feet for the
## whole ride, which is visible in play and invisible to every number.
func climbed() -> float:
	return _climb


func _exit_tree() -> void:
	_seat(0.0)
	_seat_sideways(0.0)
