class_name VfxInk
extends Node2D

## One canvas for the short-lived light of a fight (2026-09-24).
##
## A spark was a `Line2D` with a sprite on its tip and two tweens; a ring a
## `Line2D`, a bloom sprite and two tweens; a flash a polygon and a tween; a
## shot's mote a sprite and a tween eighteen times a second; a damage number a
## `Label` and five tweens; a muzzle a polygon, a sprite and three tweens; an
## impact two sprites, a material and two tweens. On Act X's waves that was
## well over a thousand nodes allocated and freed every second, and the
## `VfxLayer` sat against `VFX_MAX_LIVE` evicting its oldest child on every
## frame. Measured: 7,151 canvas items and 2,674 draw calls on a field of
## forty-two bodies, at 90-99 ms a frame.
##
## Every one of those is a small bright shape that moves for a fraction of a
## second, and that is one `_draw`: the items are records in arrays, advanced
## once a frame, and each kind is handed to the renderer as a single triangle
## array - or, for the painted art and the numbers, one draw command each with
## no node behind it. No node is born or freed for any of them, and the count
## is capped per kind by dropping the oldest, which is what the layer did.
##
## **Two of these stand on a field.** The additive one carries what is light -
## sparks, rings, flashes, motes, rays, the forged sheets - so a spark over a
## torch pool brightens it rather than painting a flat stroke across it; the
## flat one carries what is paint - the impact and muzzle art, the numbers -
## because additive text over a bright ground disappears. Every drawn shape
## has a solid middle and a rim at zero alpha - the rule `BloodInk`, the menu
## fire and the swim sheen all ended at: one colour for the whole shape is what
## a hard edge *is*.
##
## A look, never a fact. Nothing reads this canvas; `Graphics.particle_scale`
## and `JuiceDirector` thin what reaches it at the doors in `Vfx`, and a record
## dropped for the cap changes nothing about the blow that made it.
##
## `finish_when_paused`: the canvas processes always, and while the tree is
## paused only the records flagged `always` advance - a lightning strike's
## sparks must burn out under a pause exactly as the strike's own light does
## (`lightning_lifetime_check`), and a tower's must not.

## Whether this canvas adds light or lays paint.
var additive: bool = true

## The records, one array a kind. A record is a Dictionary rather than a node:
## an allocation still, but one a few hundred bytes wide with no tree, no
## transform notification and no free at the end of it.
var _sparks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _rays: Array[Dictionary] = []
## Painted art played once: a sheet of cells, or a list of frames, or a single
## texture that fades.
var _art: Array[Dictionary] = []
## Damage numbers.
var _numbers: Array[Dictionary] = []
## Dust: a soft disc that drifts out, grows and fades - paint, on the flat
## canvas, because a puff of earth over a lit road darkens it.
var _dust: Array[Dictionary] = []
## **Streaks and beams** (2026-09-28): what travels from a cast to where it
## lands, and the line a channel is. A spell used to resolve as a sheet at
## the far end and nothing between - the owner's own words: *"only
## displaying a vfx forge animated sprite at a set distance away from the
## player without showing any projectiles or beams"*. A streak is a head on
## a path with a trail of ghosts behind it; a beam is a feathered band that a
## channel redraws every frame. Records, like everything else here.
var _streaks: Array[Dictionary] = []
var _beams: Array[Dictionary] = []

## Reused every frame rather than reallocated.
var _points: PackedVector2Array = PackedVector2Array()
var _colours: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()

## The numbers' face: the project theme's, as the labels wore.
var _font: Font = null
var _font_size: int = 18
## Whether the last frame drew anything, so the frame after the last record
## dies is drawn too - without it the final picture stayed on the canvas
## until the next record arrived. And the redraw clock (`VFX_INK_HZ`).
var _was_live: bool = false
var _age_debt: float = 0.0


func _init(adds_light: bool = true) -> void:
	additive = adds_light


## **The canvas every flame's embers land on** (2026-09-25): the additive
## one, registered here so a `Flame` - which the headless `--script` tools load
## and which therefore may not name an autoload - can reach it.
static var ember_canvas: VfxInk = null
## **Embers are a ring of packed arrays, keyed by when each was born**
## (2026-09-25). A flame sheds hundreds a second and an ember's path is a
## function of its age alone, so as a nine-key dictionary aged every tick the
## records cost more than the emitter they replaced (1.01 ms of a held Act X
## frame against 0.87). Here an ember is written once and never touched again:
## its age is the ink's own ember clock less its birth, the clock runs only
## while the tree does (so a pause holds them, as it held the records), the
## dead are skipped where they are and dropped from the front of the ring, and
## at the cap the oldest gives way. Born is a 64-bit float so a ten-hour road
## still places an ember to the microsecond.
var _ember_at: PackedVector2Array = PackedVector2Array()
var _ember_velocity: PackedVector2Array = PackedVector2Array()
var _ember_born: PackedFloat64Array = PackedFloat64Array()
var _ember_life: PackedFloat32Array = PackedFloat32Array()
var _ember_size: PackedFloat32Array = PackedFloat32Array()
var _ember_rise: PackedFloat32Array = PackedFloat32Array()
var _ember_core: PackedColorArray = PackedColorArray()
var _ember_body: PackedColorArray = PackedColorArray()
var _ember_head: int = 0
var _ember_count: int = 0
var _ember_clock: float = 0.0


func _exit_tree() -> void:
	if ember_canvas == self:
		ember_canvas = null


func _ready() -> void:
	name = "VfxInk" if additive else "VfxInkFlat"
	if additive:
		ember_canvas = self
	z_index = Balance.VFX_Z if additive else Balance.VFX_Z + 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	add_to_group(Graphics.FILTER_GROUP)
	if additive:
		var glow: CanvasItemMaterial = LightKit.additive_material()
		material = glow
	# Numbers that fly are read in a fifth of a second over anything: the
	# heaviest cut of the body face (`UiFonts.Role.IMPACT`).
	_font = UiFonts.face(UiFonts.Role.IMPACT)
	var theme: Theme = ThemeDB.get_project_theme()
	_font_size = theme.default_font_size if theme != null else ThemeDB.fallback_font_size


func clear() -> void:
	_sparks.clear()
	_rings.clear()
	_flashes.clear()
	_motes.clear()
	_rays.clear()
	_art.clear()
	_numbers.clear()
	_dust.clear()
	_streaks.clear()
	_beams.clear()
	_ember_head = 0
	_ember_count = 0
	queue_redraw()


## How many records live, for the gates.
func live() -> int:
	return _sparks.size() + _rings.size() + _flashes.size() + _motes.size() + _rays.size() \
		+ _art.size() + _numbers.size() + _dust.size() + _streaks.size() + _beams.size()


## Every kind's live count, for a diagnostic: what a busy frame is made of.
func census() -> Dictionary:
	return {"sparks": _sparks.size(), "rings": _rings.size(), "flashes": _flashes.size(),
		"motes": _motes.size(), "rays": _rays.size(), "art": _art.size(),
		"numbers": _numbers.size(), "dust": _dust.size(), "streaks": _streaks.size(),
		"beams": _beams.size(), "embers": _ember_count}


func live_streaks() -> int:
	return _streaks.size()


func live_beams() -> int:
	return _beams.size()


## The streaks in the air, for the gates: where each is going.
func streak_records() -> Array[Dictionary]:
	return _streaks


func live_sparks() -> int:
	return _sparks.size()


func live_rings() -> int:
	return _rings.size()


func live_art() -> int:
	return _art.size()


func live_numbers() -> int:
	return _numbers.size()


## The embers the ring holds. A dead one behind a living one is counted until
## it reaches the front, which is at most one ember lifetime of overstatement.
func live_embers() -> int:
	return _ember_count


## An ember: born at `at` moving at `velocity`, lifted by `rise` a second a
## second, running from `core` to `body` over its first third and fading
## and shrinking to nothing over `life`. Its own array and its own cap, so a
## hundred torches never push a shot's trail out of the motes.
func ember(at: Vector2, velocity: Vector2, rise: float, core: Color, body: Color,
		size: float, life: float) -> void:
	var cap: int = Balance.VFX_INK_EMBERS_MAX
	if _ember_born.size() != cap:
		_ember_at.resize(cap)
		_ember_velocity.resize(cap)
		_ember_born.resize(cap)
		_ember_life.resize(cap)
		_ember_size.resize(cap)
		_ember_rise.resize(cap)
		_ember_core.resize(cap)
		_ember_body.resize(cap)
		_ember_head = 0
		_ember_count = 0
	var slot: int = 0
	if _ember_count < cap:
		slot = (_ember_head + _ember_count) % cap
		_ember_count += 1
	else:
		slot = _ember_head
		_ember_head = (_ember_head + 1) % cap
	_ember_at[slot] = at
	_ember_velocity[slot] = velocity
	_ember_born[slot] = _ember_clock
	_ember_life[slot] = maxf(life, 0.02)
	_ember_size[slot] = maxf(size, 0.5)
	_ember_rise[slot] = rise
	_ember_core[slot] = core
	_ember_body[slot] = body


## Drops the dead from the front of the ring and says whether any are left.
func _prune_embers() -> bool:
	var cap: int = _ember_born.size()
	while _ember_count > 0 and _ember_clock - _ember_born[_ember_head] >= _ember_life[_ember_head]:
		_ember_head = (_ember_head + 1) % cap
		_ember_count -= 1
	return _ember_count > 0


func live_dust() -> int:
	return _dust.size()


## The painted records, oldest first, for a gate that wants to read a sheet's
## turn, flip, tint and age back off what was actually laid.
func art_records() -> Array[Dictionary]:
	return _art.duplicate()


func number_records() -> Array[Dictionary]:
	return _numbers.duplicate()


# --- Doors ----------------------------------------------------------------------

## A shard flying from `at` along `direction` (random when zero), fading as it
## goes, with a soft mote on its tip. `speed` is the reach it covers over its
## life, eased out.
func spark(at: Vector2, direction: Vector2, colour: Color, speed: float,
		always: bool = false) -> void:
	if not ScreenCull.world_sees(self, at, speed):
		return
	var angle: float
	if direction == Vector2.ZERO:
		angle = randf() * TAU
	else:
		angle = direction.angle() + randf_range(-Balance.VFX_SPARK_SPREAD, Balance.VFX_SPARK_SPREAD)
	_push(_sparks, {
		"at": at,
		"dir": Vector2.RIGHT.rotated(angle),
		"travel": speed * randf_range(0.5, 1.2),
		"length": randf_range(6.0, 16.0),
		"width": randf_range(2.0, 4.0),
		"colour": colour,
		"life": Balance.VFX_SPARK_LIFE * randf_range(0.7, 1.3),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_SPARKS_MAX)


## A ring growing from nothing to `to_radius` over `life`, `width` thick, with
## a faint wider halo, fading as it grows.
func ring(at: Vector2, to_radius: float, colour: Color, life: float, width: float,
		always: bool = false) -> void:
	if not ScreenCull.world_sees(self, at, to_radius):
		return
	_push(_rings, {
		"at": at,
		"radius": maxf(to_radius, 1.0),
		"width": maxf(width, 1.0),
		"colour": colour,
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_RINGS_MAX)


## A soft disc that swells to nearly twice its size and is gone in a sixth of
## a second - the light of a blow landing.
func flash(at: Vector2, colour: Color, radius: float, always: bool = false) -> void:
	if not ScreenCull.world_sees(self, at, radius * 2.0):
		return
	_push(_flashes, {
		"at": at,
		"radius": maxf(radius, 1.0),
		"colour": Color(colour.lerp(Color.WHITE, 0.6), 0.85),
		"life": Balance.VFX_FLASH_LIFE,
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_FLASHES_MAX)


## A soft dot that drifts by `drift` over `life`, shrinking and fading - what a
## shot sheds behind it, what a spray throws, what a mote is.
func mote(at: Vector2, drift: Vector2, colour: Color, size: float, life: float,
		always: bool = false) -> void:
	if not ScreenCull.world_sees(self, at, drift.length() + size):
		return
	_push(_motes, {
		"at": at,
		"drift": drift,
		"colour": colour,
		"size": maxf(size, 0.5),
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_MOTES_MAX)


## A ray out from `at`: a shard that grows from a third of its reach to the
## whole of it and fades - the burst round a build or an upgrade.
func ray(at: Vector2, direction: Vector2, colour: Color, inner: float, outer: float,
		life: float, always: bool = false) -> void:
	if not ScreenCull.world_sees(self, at, outer):
		return
	_push(_rays, {
		"at": at,
		"dir": direction,
		"inner": inner,
		"outer": outer,
		"width": randf_range(2.0, 4.5),
		"colour": colour,
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_RAYS_MAX)


## Painted art played once at `at`: `frames` in order over `life` (one frame
## holds for the whole life), turned by `rotation`, at `scale` (a negative
## axis mirrors), in `tint`. `grow` is the scale the picture starts from as a
## share of `scale`, easing out to it; `fade_from` is the share of the life
## after which it fades to nothing (1.0 never fades - a sheet that ends on an
## empty cell needs none). Centred on `at`, as a sprite would be.
func art(frames: Array[Texture2D], at: Vector2, rotation: float, scale: Vector2,
		tint: Color, life: float, grow: float = 1.0, fade_from: float = 0.0,
		always: bool = false) -> void:
	if frames.is_empty():
		return
	var reach: float = float(frames[0].get_width()) * maxf(absf(scale.x), absf(scale.y))
	if not ScreenCull.world_sees(self, at, reach) or _crowded(at, frames[0]):
		return
	_push(_art, {
		"frames": frames,
		"sheet": 0,
		"at": at,
		"rot": rotation,
		"scale": scale,
		"tint": tint,
		"life": maxf(life, 0.02),
		"grow": grow,
		"fade_from": fade_from,
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_ART_MAX)


## A forged sheet: one texture holding `cells` square cells in a row, played
## end to end over `life`.
func sheet(texture: Texture2D, cells: int, at: Vector2, rotation: float, scale: Vector2,
		tint: Color, life: float, always: bool = false) -> void:
	if texture == null or cells < 1:
		return
	var reach: float = float(texture.get_height()) * maxf(absf(scale.x), absf(scale.y))
	if not ScreenCull.world_sees(self, at, reach) or _crowded(at, texture):
		return
	var frames: Array[Texture2D] = [texture]
	_push(_art, {
		"frames": frames,
		"sheet": cells,
		"at": at,
		"rot": rotation,
		"scale": scale,
		"tint": tint,
		"life": maxf(life, 0.02),
		"grow": 1.0,
		"fade_from": 1.0,
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_ART_MAX)


## A damage number: pops, rises and hangs, then falls back a little and fades.
## `big` is a critical or a finisher - larger, tilted, longer.
func number(at: Vector2, text: String, colour: Color, big: bool) -> void:
	if not ScreenCull.world_sees(self, at, 80.0):
		return
	var rise: float = Balance.VFX_NUMBER_RISE \
		* (1.0 + (Balance.VFX_NUMBER_BIG_RISE_BONUS if big else 0.0))
	_push(_numbers, {
		"at": at + Vector2(randf_range(-14.0, 14.0), -20.0),
		"text": text,
		"colour": colour,
		"big": big,
		"tilt": deg_to_rad(randf_range(-Balance.VFX_NUMBER_TILT_DEGREES,
			Balance.VFX_NUMBER_TILT_DEGREES)) if big else 0.0,
		"side": randf_range(-26.0, 26.0),
		"rise": rise,
		"life": Balance.VFX_NUMBER_LIFE * (1.25 if big else 1.0),
		"age": 0.0,
		"always": false,
	}, Balance.VFX_INK_NUMBERS_MAX)


## A puff of dust: born at `at`, drifting `drift` on an ease-out, growing to
## `grow` times its size and fading to nothing over `life`. What `Vfx.dust`
## stood up as an octagon and three tweens (2026-09-24).
func dust(at: Vector2, drift: Vector2, colour: Color, size: float, grow: float,
		life: float, always: bool = false) -> void:
	if not ScreenCull.world_sees(self, at, drift.length() + size * grow):
		return
	_push(_dust, {
		"at": at,
		"drift": drift,
		"colour": colour,
		"size": maxf(size, 0.5),
		"grow": maxf(grow, 1.0),
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_DUST_MAX)


## **A streak**: a head that travels `from` to `to` over `life`, the way
## `path` says - "fall" accelerates in like a stone, "lob" arcs over by
## `arc` and lands, "line" is straight and even - with `frames` painted on
## the head turned along its way, or a bead of light when there are none,
## and ghosts of itself behind it. Drawn only; nothing reads where it is.
func streak(from: Vector2, to: Vector2, life: float, colour: Color, frames: Array[Texture2D],
		size: float, arc: float, path: String, always: bool = false) -> void:
	_push(_streaks, {
		"from": from,
		"to": to,
		"colour": colour,
		"frames": frames,
		"size": maxf(size, 2.0),
		"arc": arc,
		"path": path,
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_STREAKS_MAX)


## **A beam**: a feathered band from `from` to `to`, `width` either side, that
## fades over `life`. A channel calls it every frame with a life a little
## over a frame, so the beam is continuous while it is held and gone the
## moment it is not; a single call is a flash of one.
func beam(from: Vector2, to: Vector2, width: float, colour: Color, life: float,
		always: bool = false) -> void:
	_push(_beams, {
		"from": from,
		"to": to,
		"width": maxf(width, 1.0),
		"colour": colour,
		"life": maxf(life, 0.02),
		"age": 0.0,
		"always": always,
	}, Balance.VFX_INK_BEAMS_MAX)


## **One picture of a kind on one spot at a time** (2026-09-30). Forty towers
## converging on the body at the gate landed several painted and forged hits
## on the same few pixels inside a twentieth of a second - each a large
## additive or blended quad, and together one picture drawn five times over.
## A hit of the same picture in the same `VFX_CROWD_CELL` inside
## `VFX_CROWD_SECONDS` of the last is not drawn again; a different picture, a
## different spot or a later moment always is. Never headless, like the cull.
var _crowd: Dictionary = {}


func _crowded(at: Vector2, picture: Texture2D) -> bool:
	if not ScreenCull.culling():
		return false
	var cell := Vector2i((at / Balance.VFX_CROWD_CELL).floor())
	var key: int = hash([cell, picture.get_instance_id()])
	var now: int = Time.get_ticks_msec()
	var last: int = int(_crowd.get(key, -100000))
	if now - last < int(Balance.VFX_CROWD_SECONDS * 1000.0):
		return true
	if _crowd.size() > 512:
		_crowd.clear()
	_crowd[key] = now
	return false


func _push(into: Array[Dictionary], record: Dictionary, cap: int) -> void:
	into.append(record)
	# The oldest give way, which is what the node layer did with its cap.
	while into.size() > cap:
		into.remove_at(0)


# --- The clock --------------------------------------------------------------------

func _process_measured(delta: float) -> void:
	var paused: bool = get_tree() != null and get_tree().paused
	# **Aged on the redraw clock, never per frame** (2026-09-24). The canvas
	# draws on `VFX_INK_HZ`; a record advanced a hundred and forty-four times a
	# second and drawn thirty times is script spent on positions nobody sees.
	# The frame's delta is banked and every record steps once a tick by what
	# was banked, so at 144 Hz the walks are a fifth of what they were and the
	# picture is the same picture. A record's life is still the tree's real
	# seconds, and the first record after a quiet stretch is drawn on the
	# frame it arrives - a spark must not wait a tick to exist.
	_age_debt += delta
	if _was_live and _age_debt < 1.0 / Balance.VFX_INK_HZ:
		return
	var step: float = _age_debt
	_age_debt = 0.0
	var moved: bool = false
	moved = _age(_sparks, step, paused) or moved
	moved = _age(_rings, step, paused) or moved
	moved = _age(_flashes, step, paused) or moved
	moved = _age(_motes, step, paused) or moved
	moved = _age(_rays, step, paused) or moved
	moved = _age(_art, step, paused) or moved
	moved = _age(_numbers, step, paused) or moved
	moved = _age(_dust, step, paused) or moved
	moved = _age(_streaks, step, paused) or moved
	moved = _age(_beams, step, paused) or moved
	if not paused:
		_ember_clock += step
	moved = _prune_embers() or moved
	if moved:
		queue_redraw()
	elif _was_live:
		# The last record died this frame: draw the empty canvas once.
		queue_redraw()
	_was_live = moved


## Ages every record that may move now and drops the ones that are done.
## Returns whether anything is alive to draw.
func _age(records: Array[Dictionary], delta: float, paused: bool) -> bool:
	if records.is_empty():
		return false
	var index: int = records.size() - 1
	while index >= 0:
		var record: Dictionary = records[index]
		if not paused or bool(record["always"]):
			var age: float = float(record["age"]) + delta
			if age >= float(record["life"]):
				records.remove_at(index)
			else:
				record["age"] = age
		index -= 1
	return not records.is_empty()


# --- The picture ------------------------------------------------------------------

func _draw_measured() -> void:
	var inverse: Transform2D = global_transform.affine_inverse()
	# Dust first: it lies under everything else a blow throws.
	_draw_dust(inverse)
	_draw_beams(inverse)
	_draw_sparks(inverse)
	_draw_rays(inverse)
	_draw_rings(inverse)
	_draw_flashes(inverse)
	_draw_motes(inverse)
	_draw_embers(inverse)
	_draw_streaks(inverse)
	_draw_art(inverse)
	_draw_numbers(inverse)


func _begin() -> void:
	_points.clear()
	_colours.clear()
	_indices.clear()


func _flush() -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colours)


## A feathered strip: a spine from `head` to `tail` with `width` either side,
## solid along the spine and clear at the edges, the alpha falling from `lit`
## at the head to `lit * tail_share` at the tail. Nine vertices, eight
## triangles, no hard edge anywhere.
func _strip(head: Vector2, tail: Vector2, width: float, colour: Color, lit: float,
		tail_share: float) -> void:
	var along: Vector2 = tail - head
	if along.length_squared() < 0.01:
		return
	var side: Vector2 = along.normalized().orthogonal() * width
	var clear := Color(colour.r, colour.g, colour.b, 0.0)
	var base: int = _points.size()
	for step: int in 3:
		var t: float = float(step) * 0.5
		var centre: Vector2 = head + along * t
		var mid := Color(colour.r, colour.g, colour.b, lit * lerpf(1.0, tail_share, t))
		_points.append(centre - side)
		_colours.append(clear)
		_points.append(centre)
		_colours.append(mid)
		_points.append(centre + side)
		_colours.append(clear)
	for step: int in 2:
		var row: int = base + step * 3
		for column: int in 2:
			var a: int = row + column
			_indices.append(a)
			_indices.append(a + 1)
			_indices.append(a + 3)
			_indices.append(a + 1)
			_indices.append(a + 4)
			_indices.append(a + 3)


## **How a beam's end is shaped** (2026-09-30): at a distance `u` into the cap,
## from nothing at the tip to one where the cap meets the beam, how wide the
## band is (a rounded curve that keeps a point, `BEAM_TIP_WIDTH` at the tip)
## and how much of its light it carries (none at the tip). Static and shared
## with `DragonBreath`, so every beam in the game ends the same way.
static func beam_cap(u: float) -> Vector2:
	var along: float = clampf(u, 0.0, 1.0)
	var round_nose: float = sqrt(1.0 - (1.0 - along) * (1.0 - along))
	var wide: float = lerpf(Balance.BEAM_TIP_WIDTH, 1.0, pow(round_nose, 1.35))
	var light: float = along * along * (3.0 - 2.0 * along)
	return Vector2(wide, light)


## The distances along a beam of `length` at which its rows stand: a row
## at each end, `BEAM_CAP_ROWS` through each cap, and nothing between the caps
## because a straight band needs no more. Paired with how far each row is into
## its cap (one in the middle).
static func beam_rows(length: float, width: float) -> PackedVector2Array:
	var cap: float = minf(width * Balance.BEAM_CAP_WIDTHS, length * Balance.BEAM_CAP_MOST)
	var rows := PackedVector2Array()
	if cap <= 0.01:
		rows.append(Vector2(0.0, 1.0))
		rows.append(Vector2(length, 1.0))
		return rows
	for step: int in Balance.BEAM_CAP_ROWS + 1:
		var u: float = float(step) / float(Balance.BEAM_CAP_ROWS)
		rows.append(Vector2(cap * u, u))
	for step: int in range(Balance.BEAM_CAP_ROWS, -1, -1):
		var u: float = float(step) / float(Balance.BEAM_CAP_ROWS)
		rows.append(Vector2(length - cap * u, u))
	return rows


## A beam's band: `_strip`'s three lanes, laid on `beam_rows` so both ends
## close in a soft pointed cap instead of stopping on a straight cut.
func _beam_band(head: Vector2, tail: Vector2, width: float, colour: Color, lit: float,
		tail_share: float) -> void:
	var line: Vector2 = tail - head
	var length: float = line.length()
	if length < 0.1:
		return
	var along: Vector2 = line / length
	var across: Vector2 = along.orthogonal()
	var clear := Color(colour.r, colour.g, colour.b, 0.0)
	var base: int = _points.size()
	var rows: PackedVector2Array = beam_rows(length, width)
	for row: Vector2 in rows:
		var shape: Vector2 = beam_cap(row.y)
		var t: float = row.x / length
		var centre: Vector2 = head + along * row.x
		var side: Vector2 = across * width * shape.x
		_points.append(centre - side)
		_colours.append(clear)
		_points.append(centre)
		_colours.append(Color(colour.r, colour.g, colour.b, lit * lerpf(1.0, tail_share, t) * shape.y))
		_points.append(centre + side)
		_colours.append(clear)
	for step: int in rows.size() - 1:
		var row: int = base + step * 3
		for column: int in 2:
			var a: int = row + column
			_indices.append(a)
			_indices.append(a + 1)
			_indices.append(a + 3)
			_indices.append(a + 1)
			_indices.append(a + 4)
			_indices.append(a + 3)


## A soft disc: solid in the middle, clear at the rim, `segments` wide.
func _disc(centre: Vector2, radius: float, colour: Color, lit: float, segments: int) -> void:
	var base: int = _points.size()
	_points.append(centre)
	_colours.append(Color(colour.r, colour.g, colour.b, lit))
	var clear := Color(colour.r, colour.g, colour.b, 0.0)
	for step: int in segments:
		var angle: float = TAU * float(step) / float(segments)
		_points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		_colours.append(clear)
	for step: int in segments:
		_indices.append(base)
		_indices.append(base + 1 + step)
		_indices.append(base + 1 + (step + 1) % segments)


## A soft annulus: clear inside, solid on the ring, clear outside.
func _annulus(centre: Vector2, radius: float, width: float, colour: Color, lit: float,
		segments: int) -> void:
	var base: int = _points.size()
	var clear := Color(colour.r, colour.g, colour.b, 0.0)
	var mid := Color(colour.r, colour.g, colour.b, lit)
	for step: int in segments + 1:
		var angle: float = TAU * float(step) / float(segments)
		var out := Vector2(cos(angle), sin(angle))
		_points.append(centre + out * maxf(radius - width, 0.0))
		_colours.append(clear)
		_points.append(centre + out * radius)
		_colours.append(mid)
		_points.append(centre + out * (radius + width))
		_colours.append(clear)
	for step: int in segments:
		var row: int = base + step * 3
		for column: int in 2:
			var a: int = row + column
			_indices.append(a)
			_indices.append(a + 1)
			_indices.append(a + 3)
			_indices.append(a + 1)
			_indices.append(a + 4)
			_indices.append(a + 3)


## **Sparks, motes and flashes are quads of a soft dot, not fans of
## triangles** (2026-09-24, second cut). A triangle array is a new GPU buffer
## on every redraw in the Compatibility renderer, and the visual ablation
## table read the two ink canvases at two milliseconds a frame together
## with the script side already small. A texture rect is an instance in a
## batch the renderer already keeps, so a thousand sparks are one draw call
## and no buffer. A spark is a stretched dot with a brighter dot at its
## head; a mote and a flash are one dot each. Rings and rays keep their
## triangles: they are few, and a ring is a telegraph drawn at the blow's
## own radius.
func _draw_sparks(inverse: Transform2D) -> void:
	if _sparks.is_empty():
		return
	var dot: Texture2D = Flame.dot_texture()
	for record: Dictionary in _sparks:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		var dir: Vector2 = record["dir"] as Vector2
		var head: Vector2 = (record["at"] as Vector2) + dir * float(record["travel"]) * eased
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		if lit <= 0.004:
			continue
		var length: float = float(record["length"]) * (1.0 - 0.4 * t)
		var width: float = float(record["width"]) * (1.0 - 0.3 * t)
		var tail: Vector2 = head - dir * length
		var middle: Vector2 = inverse * ((head + tail) * 0.5)
		var along: Vector2 = inverse.basis_xform(dir)
		draw_set_transform(middle, along.angle(), Vector2.ONE)
		draw_texture_rect(dot, Rect2(-length * 0.5, -width, length, width * 2.0), false,
			Color(colour.r, colour.g, colour.b, lit * 0.8))
		var bead: float = width * 1.8 * lerpf(1.0, 0.35, t)
		var bead_at: Vector2 = inverse * head
		draw_set_transform(bead_at, 0.0, Vector2.ONE)
		draw_texture_rect(dot, Rect2(-bead, -bead, bead * 2.0, bead * 2.0), false,
			Color(colour.r, colour.g, colour.b, lit * 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
func _draw_rays(inverse: Transform2D) -> void:
	if _rays.is_empty():
		return
	_begin()
	for record: Dictionary in _rays:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var grown: float = lerpf(0.35, 1.0, 1.0 - pow(1.0 - t, 4.0))
		var lit: float = 1.0 if t < 0.18 else 1.0 - (t - 0.18) / 0.82
		var at: Vector2 = record["at"] as Vector2
		var dir: Vector2 = record["dir"] as Vector2
		var colour: Color = record["colour"] as Color
		_strip(inverse * (at + dir * float(record["outer"]) * grown),
			inverse * (at + dir * float(record["inner"]) * grown),
			float(record["width"]) * 0.5, colour, colour.a * lit, 0.6)
	_flush()


func _draw_rings(inverse: Transform2D) -> void:
	if _rings.is_empty():
		return
	_begin()
	for record: Dictionary in _rings:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var grown: float = 1.0 - pow(1.0 - t, 2.0)
		var radius: float = lerpf(4.0, float(record["radius"]), grown)
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		var at: Vector2 = inverse * (record["at"] as Vector2)
		var width: float = float(record["width"])
		# The bloom: the same ring, wide and faint, so the edge reads as a
		# wave leaving a point rather than a drawn circle.
		_annulus(at, radius, width * 3.5, colour, lit * 0.22, 24)
		_annulus(at, radius, width, colour, lit, 24)
	_flush()


func _draw_flashes(inverse: Transform2D) -> void:
	if _flashes.is_empty():
		return
	var dot: Texture2D = Flame.dot_texture()
	for record: Dictionary in _flashes:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var grown: float = lerpf(1.0, 1.9, 1.0 - pow(1.0 - t, 2.0))
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		if lit <= 0.004:
			continue
		var radius: float = float(record["radius"]) * grown
		var at: Vector2 = inverse * (record["at"] as Vector2)
		draw_texture_rect(dot, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false,
			Color(colour.r, colour.g, colour.b, lit))
## The soft dot, drifting out on an ease-out and growing as it fades: the
## octagon it replaces was a translucent blob at this size, and a soft disc
## reads as the same puff with a softer edge.
func _draw_dust(inverse: Transform2D) -> void:
	if _dust.is_empty():
		return
	var dot: Texture2D = Flame.dot_texture()
	for record: Dictionary in _dust:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		if lit <= 0.004:
			continue
		var eased: float = 1.0 - (1.0 - t) * (1.0 - t)
		var at: Vector2 = inverse * ((record["at"] as Vector2) + (record["drift"] as Vector2) * eased)
		var radius: float = float(record["size"]) * lerpf(1.0, float(record["grow"]), t)
		draw_texture_rect(dot, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false,
			Color(colour.r, colour.g, colour.b, lit))


func _draw_embers(inverse: Transform2D) -> void:
	if _ember_count == 0:
		return
	var dot: Texture2D = Flame.dot_texture()
	var cap: int = _ember_born.size()
	for index: int in _ember_count:
		var slot: int = (_ember_head + index) % cap
		var age: float = _ember_clock - _ember_born[slot]
		var life: float = _ember_life[slot]
		if age >= life or age < 0.0:
			continue
		var t: float = age / life
		var colour: Color = _ember_core[slot].lerp(_ember_body[slot], minf(t / 0.35, 1.0))
		# The emitter's own ramp: whole through the first third, then fading -
		# fading from birth left a torch's embers as specks nobody saw.
		var lit: float = colour.a * (1.0 if t < 0.35 else 1.0 - (t - 0.35) / 0.65)
		if lit <= 0.004:
			continue
		var at: Vector2 = inverse * (_ember_at[slot] + _ember_velocity[slot] * age
			+ Vector2(0.0, -0.5 * _ember_rise[slot] * age * age))
		var radius: float = _ember_size[slot] * (1.0 - 0.6 * t)
		draw_texture_rect(dot, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false,
			Color(colour.r, colour.g, colour.b, lit))


func _draw_motes(inverse: Transform2D) -> void:
	if _motes.is_empty():
		return
	var dot: Texture2D = Flame.dot_texture()
	for record: Dictionary in _motes:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		if lit <= 0.004:
			continue
		var at: Vector2 = inverse * ((record["at"] as Vector2) + (record["drift"] as Vector2) * t)
		var radius: float = float(record["size"]) * lerpf(1.0, 0.35, t)
		draw_texture_rect(dot, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false,
			Color(colour.r, colour.g, colour.b, lit))
## Where a streak is at `t` of its life, and which way it is going.
static func streak_at(record: Dictionary, t: float) -> Vector2:
	var from: Vector2 = record["from"] as Vector2
	var to: Vector2 = record["to"] as Vector2
	var eased: float = t
	match String(record["path"]):
		"fall":
			eased = t * t
		"lob":
			eased = t
	var at: Vector2 = from.lerp(to, eased)
	var arc: float = float(record["arc"])
	if arc > 0.0:
		at.y -= sin(t * PI) * arc
	return at


## A streak's head on its way, its ghosts behind it, and its painted frames
## when it has them - drawn every frame it lives, so a stone falling for a
## second is a stone seen falling.
func _draw_streaks(inverse: Transform2D) -> void:
	if _streaks.is_empty():
		return
	var dot: Texture2D = Flame.dot_texture()
	for record: Dictionary in _streaks:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var colour: Color = record["colour"] as Color
		var size: float = float(record["size"])
		var head: Vector2 = streak_at(record, t)
		var ahead: Vector2 = streak_at(record, minf(t + 0.02, 1.0))
		var heading: Vector2 = (ahead - head)
		if heading.length_squared() < 0.001:
			heading = (record["to"] as Vector2) - (record["from"] as Vector2)
		var angle: float = inverse.basis_xform(heading).angle()
		# The ghosts: where the head was, fading back along the way.
		for ghost: int in range(Balance.VFX_STREAK_GHOSTS, 0, -1):
			var back: float = t - float(ghost) * Balance.VFX_STREAK_GHOST_STEP
			if back <= 0.0:
				continue
			var share: float = 1.0 - float(ghost) / float(Balance.VFX_STREAK_GHOSTS + 1)
			var radius: float = size * lerpf(0.45, 1.0, share)
			var at: Vector2 = inverse * streak_at(record, back)
			draw_texture_rect(dot, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0),
				false, Color(colour.r, colour.g, colour.b, colour.a * 0.55 * share))
		var where: Vector2 = inverse * head
		var glow: float = size * 1.6
		draw_texture_rect(dot, Rect2(where.x - glow, where.y - glow, glow * 2.0, glow * 2.0), false,
			Color(colour.r, colour.g, colour.b, colour.a * 0.7))
		var frames: Array[Texture2D] = record["frames"]
		if frames.is_empty():
			var bead: float = size * 0.7
			draw_texture_rect(dot, Rect2(where.x - bead, where.y - bead, bead * 2.0, bead * 2.0), false,
				Color(colour.lerp(Color.WHITE, 0.6), colour.a))
			continue
		var frame: Texture2D = frames[int(float(record["age"]) * Balance.VFX_STREAK_FRAME_RATE) % frames.size()]
		draw_set_transform(where, angle, Vector2.ONE)
		draw_texture_rect(frame, Rect2(-size, -size, size * 2.0, size * 2.0), false,
			colour.lightened(0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A beam: a wide faint band, a narrow bright one and a white filament, all
## from `from` to `to`, pulsing a little so a held channel reads as alive.
func _draw_beams(inverse: Transform2D) -> void:
	if _beams.is_empty():
		return
	_begin()
	for record: Dictionary in _beams:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var colour: Color = record["colour"] as Color
		var lit: float = colour.a * (1.0 - t)
		if lit <= 0.004:
			continue
		var a: Vector2 = inverse * (record["from"] as Vector2)
		var b: Vector2 = inverse * (record["to"] as Vector2)
		var width: float = float(record["width"])
		var pulse: float = 1.0 + 0.12 * sin(_ember_clock * 40.0 + float(record.get("seed", 0)))
		_beam_band(a, b, width * 2.2 * pulse, colour, lit * 0.35, 0.8)
		_beam_band(a, b, width * 0.9 * pulse, colour.lerp(Color.WHITE, 0.25), lit * 0.85, 0.85)
		_beam_band(a, b, width * 0.28, Color.WHITE, lit, 0.9)
	_flush()


## Painted art: a transform per record and one draw command, centred on its
## point as a sprite is. A sheet reads its cell off its age; a frame list
## plays end to end; a single texture holds and fades.
func _draw_art(inverse: Transform2D) -> void:
	if _art.is_empty():
		return
	for record: Dictionary in _art:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var frames: Array[Texture2D] = record["frames"]
		var cells: int = int(record["sheet"])
		var tint: Color = record["tint"] as Color
		var fade_from: float = float(record["fade_from"])
		if fade_from < 1.0 and t > fade_from:
			tint.a *= 1.0 - (t - fade_from) / maxf(1.0 - fade_from, 0.001)
		var grow: float = float(record["grow"])
		var scale: Vector2 = record["scale"] as Vector2
		if grow < 1.0:
			scale *= lerpf(grow, 1.0, 1.0 - pow(1.0 - minf(t / 0.35, 1.0), 2.0))
		draw_set_transform(inverse * (record["at"] as Vector2), float(record["rot"]), scale)
		if cells > 1:
			var texture: Texture2D = frames[0]
			var tall: float = float(texture.get_height())
			var cell: int = clampi(int(t * float(cells)), 0, cells - 1)
			draw_texture_rect_region(texture, Rect2(-tall * 0.5, -tall * 0.5, tall, tall),
				Rect2(float(cell) * tall, 0.0, tall, tall), tint)
		else:
			var frame: Texture2D = frames[clampi(int(t * float(frames.size())), 0, frames.size() - 1)]
			draw_texture(frame, -frame.get_size() * 0.5, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Damage numbers: a pop (scale from a third to `VFX_NUMBER_POP` and back to
## one), a rise that eases out then sinks back a little, a fade over the
## second half - the motion the labels had, on one canvas.
func _draw_numbers(inverse: Transform2D) -> void:
	if _numbers.is_empty() or _font == null:
		return
	for record: Dictionary in _numbers:
		var t: float = clampf(float(record["age"]) / float(record["life"]), 0.0, 1.0)
		var big: bool = bool(record["big"])
		var pop: float = Balance.VFX_NUMBER_POP * (1.15 if big else 1.0)
		var scale: float
		if t < 0.16:
			var u: float = t / 0.16
			scale = lerpf(0.35, pop, 1.0 - pow(1.0 - u, 3.0))
		elif t < 0.40:
			var u: float = (t - 0.16) / 0.24
			scale = lerpf(pop, 1.0, u * u * (3.0 - 2.0 * u))
		else:
			scale = 1.0
		var rise: float = float(record["rise"])
		var side: float = float(record["side"])
		var offset: Vector2
		if t < 0.55:
			var u: float = t / 0.55
			offset = Vector2(side * 0.7, -rise) * (1.0 - pow(1.0 - u, 3.0))
		else:
			var u: float = (t - 0.55) / 0.45
			offset = Vector2(side * 0.7, -rise).lerp(Vector2(side, -rise * 0.82),
				1.0 - cos(u * PI * 0.5))
		var colour: Color = record["colour"] as Color
		if t > 0.5:
			colour.a *= 1.0 - (t - 0.5) / 0.5
		var size: int = Balance.VFX_NUMBER_SIZE_BIG if big else Balance.VFX_NUMBER_SIZE
		var text: String = String(record["text"])
		var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at: Vector2 = inverse * ((record["at"] as Vector2) + offset)
		draw_set_transform(at, float(record["tilt"]), Vector2.ONE * scale)
		var pen := Vector2(-width * 0.5, float(size) * 0.35)
		draw_string_outline(_font, pen, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			8 if big else 6, Color(0.02, 0.04, 0.05, 0.9 * colour.a))
		draw_string(_font, pen, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## `FrameProfile` bucket "ink_draw": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"ink_draw", started)


## `FrameProfile` bucket "ink": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"ink", started)
