class_name DragonBreath
extends Node2D

## **What a dragon's breath looks like, and never what it does.**
##
## Owner, 2026-09-22: *"Dragon firebreath is highly unpolished and needs super
## aesthetically appealing game juicy vfx! Make it with blender's forge and also
## spice it up with whatever we can within Godot ... each dragon type's
## elemental breath attack which should match its element and not all be fire,
## although the non-fire dragons can also breath normal firebreath attacks as
## well ... the fire dragon should ... also have a special ultra firebreath
## attack which is a fire/electric/plasmaish hyperbeam type of laser beam."*
##
## Both breaths in the game were two straight lines of one colour: the war-camp
## wyrm's release (`EnemyGroundStrike`, a line) and the passing dragon's breath
## (`GroundHazard`, "breath"). This is the one picture both now stand up:
##
## - **a charge at the mouth** over the warning - a gathering glow and motes
##   falling into it, crackling arcs round an ultra - so the tell is read at the
##   dragon as well as on the ground;
## - **a feathered, licking cone** in the element's own three colours, drawn as
##   one triangle array with transparent rims (one colour across a whole shape
##   is what a hard edge *is*, the finding this project has paid for at the
##   blood, the swim sheen and the campfire);
## - **forged tongues** (`breath_tongue`) rolled down the line and a bloom
##   (`breath_bloom`) at the mouth and the landing, from Blender;
## - **the element's own matter** thrown off it: embers rise from fire, frost
##   motes drift, storm throws jagged bolts, stone sheds grit;
## - and for the ultra, **a plasma hyperbeam**: a white core in a violet sheath
##   in a fire skin, two arcs spiralling round it and forged `beam_core`
##   segments tiled end to end.
##
## **The bound is the fog's and the footfall's.** It is handed the line the blow
## was already committed to and the width it already resolves at; it reads
## nothing, rolls nothing the run relies on (its own dice), moves no number and
## sends no message. The telegraph's exact edges are still drawn by the strike
## that owns them - a breath that drew its own reach could disagree with it.

var mouth: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
var half_width: float = 40.0
var element: String = "fire"
var ultra: bool = false
var warning: float = 0.6
var blast: float = 0.55

var _age: float = 0.0
var _opened: bool = false
var _tongue_clock: float = 0.0
var _matter_clock: float = 0.0
var _bolts: Array[PackedVector2Array] = []
var _bolt_clock: float = 0.0
var _dice := RandomNumberGenerator.new()
var _seed: float = 0.0


## The element a breath is drawn in, as three colours: a core, a body and a rim.
static func palette(kind: String) -> Array:
	return Balance.DRAGON_BREATH_PALETTES.get(kind,
		Balance.DRAGON_BREATH_PALETTES["fire"]) as Array


## **Which breath a dragon breathes this time**, from its own element and dice.
##
## Its own element most of the time, plain fire the rest - a frost wyrm that
## sometimes breathes fire is the owner's own clause, and one that never did
## would make the fire the rarer sight. A dragon that can breathe the ultra
## breathes it on `DRAGON_ULTRA_CHANCE` of its breaths. The width, reach and
## angle wander by small authored amounts, which is the shape of the blow and
## never its size.
static func choose(kind: EnemyData, dice: RandomNumberGenerator) -> Dictionary:
	var own: String = kind.breath_element if kind != null else ""
	if own.is_empty():
		own = "fire"
	var element_now: String = own
	if own != "fire" and dice.randf() >= Balance.DRAGON_OWN_BREATH_CHANCE:
		element_now = "fire"
	var ultra_now: bool = kind != null and kind.breath_ultra \
		and dice.randf() < Balance.DRAGON_ULTRA_CHANCE
	var out: Dictionary = {
		"element": "plasma" if ultra_now else element_now,
		"ultra": ultra_now,
		"width": dice.randf_range(Balance.DRAGON_BREATH_WIDTH_WANDER.x,
			Balance.DRAGON_BREATH_WIDTH_WANDER.y),
		"reach": dice.randf_range(Balance.DRAGON_BREATH_REACH_WANDER.x,
			Balance.DRAGON_BREATH_REACH_WANDER.y),
		"turn": dice.randf_range(-Balance.DRAGON_BREATH_TURN_WANDER,
			Balance.DRAGON_BREATH_TURN_WANDER),
	}
	if ultra_now:
		out["width"] = Balance.DRAGON_ULTRA_WIDTH
		out["reach"] = Balance.DRAGON_ULTRA_REACH
		out["turn"] = 0.0
	return out


## Stands one up beside `parent`, deferred so it is safe from a `_ready`.
static func breathe(parent: Node, from_mouth: Vector2, to_end: Vector2,
		width: float, kind: String, is_ultra: bool, warn: float) -> DragonBreath:
	var breath := DragonBreath.new()
	breath.mouth = from_mouth
	breath.to = to_end
	breath.half_width = maxf(width, 8.0)
	breath.element = kind
	breath.ultra = is_ultra
	breath.warning = maxf(warn, 0.05)
	breath.blast = Balance.DRAGON_ULTRA_BLAST if is_ultra else Balance.DRAGON_BREATH_BLAST
	if parent != null:
		parent.add_child.call_deferred(breath)
	return breath


func _ready() -> void:
	z_index = Balance.VFX_Z - 1
	global_position = mouth
	_dice.randomize()
	_seed = _dice.randf() * 100.0
	# Light adds; grit does not. A stone breath drawn additively glows, which
	# is the one thing sand in the air does not do.
	if element != "stone":
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = glow
	JuiceDirector.note(JuiceDirector.Priority.HAZARD)
	Sfx.play_at("sfx_spell_cast", mouth, 1.0)


func _process_measured(delta: float) -> void:
	_age += delta
	if _age >= warning:
		if not _opened:
			_open()
		var live: float = _age - warning
		if live <= blast:
			_tongue_clock -= delta
			if _tongue_clock <= 0.0:
				_tongue_clock = Balance.DRAGON_BREATH_TONGUE_EVERY
				_roll_a_tongue()
			_matter_clock -= delta
			if _matter_clock <= 0.0:
				_matter_clock = Balance.DRAGON_BREATH_MATTER_EVERY
				_throw_matter()
	if element == "storm" or ultra:
		_bolt_clock -= delta
		if _bolt_clock <= 0.0:
			_bolt_clock = 0.05
			_regrow_bolts()
	queue_redraw()
	if _age > warning + blast + Balance.DRAGON_BREATH_FADE:
		queue_free()


func _open() -> void:
	_opened = true
	var colours: Array = palette(element)
	var line: Vector2 = to - mouth
	var size: float = half_width * (4.0 if ultra else 3.0)
	Vfx.forge_play("breath_bloom", mouth, size, colours[1] as Color)
	Vfx.forge_hit(_hit_element(), to, size * 1.2, colours[1] as Color)
	Vfx.light_burst(to, colours[1] as Color, size * 2.0, 1.4, 0.4)
	if ultra:
		# Laid end to end down the beam, turned onto it, so the plasma crackles
		# along its whole length rather than at one point.
		var length: float = line.length()
		var step: float = Balance.DRAGON_ULTRA_SEGMENT
		var count: int = maxi(int(ceil(length / step)), 1)
		for index: int in count:
			var at: Vector2 = mouth + line.normalized() * step * (float(index) + 0.5)
			Vfx.forge_play("beam_core", at, step * 1.15, colours[1] as Color, line.angle())
		Vfx.forge_play("beam_end", to, size, colours[0] as Color, (-line).angle())
	var weight: float = Balance.IMPACT_FULL_SHARE * (0.55 if ultra else 0.3)
	EventBus.camera_impact.emit(mouth.lerp(to, 0.5), weight)
	for sound: String in _sounds():
		Sfx.play_at(sound, mouth.lerp(to, 0.35), 1.6)


## A tongue rolled from the mouth down the line, a little further each time.
func _roll_a_tongue() -> void:
	var line: Vector2 = to - mouth
	var length: float = line.length()
	if length <= 1.0 or ultra:
		return
	var colours: Array = palette(element)
	var t: float = _dice.randf_range(0.05, 0.85)
	var at: Vector2 = mouth + line * t + line.normalized().orthogonal() \
		* _dice.randf_range(-0.35, 0.35) * half_width
	# Small and soft: a tongue is texture inside the cone, never a second
	# shape laid over it - the first photograph had them as opaque blobs.
	var tint: Color = (colours[1] as Color).lerp(colours[0] as Color, _dice.randf() * 0.4)
	tint.a = Balance.DRAGON_BREATH_TONGUE_ALPHA
	Vfx.forge_play("breath_tongue", at, half_width * lerpf(2.2, 4.2, t), tint, line.angle())


## The element's own matter, thrown off the length of the breath.
func _throw_matter() -> void:
	var line: Vector2 = to - mouth
	var colours: Array = palette(element)
	var at: Vector2 = mouth + line * _dice.randf_range(0.15, 1.0)
	match element:
		"fire", "plasma":
			Vfx.spark(at, colours[1] as Color, 3, Vector2.UP, 110.0)
		"frost":
			Vfx.spark(at, colours[0] as Color, 3, line.normalized(), 70.0)
		"storm":
			Vfx.spark(at, colours[0] as Color, 2, Vector2.ZERO, 180.0)
		"stone":
			Vfx.dust(at, colours[1] as Color, 3, half_width * 0.8)
		_:
			Vfx.spark(at, colours[1] as Color, 2, Vector2.UP, 80.0)


func _hit_element() -> String:
	match element:
		"frost":
			return "water"
		"storm":
			return "air"
		"stone":
			return "earth"
		_:
			return "fire"


func _sounds() -> Array[String]:
	match element:
		"frost":
			return ["sfx_water_shot"]
		"storm":
			return ["sfx_thunder_near"]
		"stone":
			return ["sfx_quake"]
		"plasma":
			return ["sfx_thunder_near", "sfx_fire_shot"]
		_:
			return ["sfx_fire_shot"]


func _regrow_bolts() -> void:
	_bolts.clear()
	var a := Vector2.ZERO
	var b: Vector2 = to - mouth
	var across: Vector2 = b.normalized().orthogonal()
	for _bolt: int in (3 if ultra else 2):
		var bolt := PackedVector2Array()
		var steps: int = 12
		for index: int in steps + 1:
			var t: float = float(index) / float(steps)
			var jag: float = 0.0 if index == 0 or index == steps \
				else _dice.randf_range(-1.0, 1.0) * half_width * 0.9
			bolt.append(a.lerp(b, t) + across * jag)
		_bolts.append(bolt)


func _draw_measured() -> void:
	var b: Vector2 = to - mouth
	if b.length() < 1.0:
		return
	if _age < warning:
		_draw_charge(clampf(_age / maxf(warning, 0.01), 0.0, 1.0))
		return
	var live: float = _age - warning
	var reveal: float = clampf(live / (0.06 if ultra else 0.14), 0.0, 1.0)
	var fade: float = 1.0 - clampf((live - blast) / maxf(Balance.DRAGON_BREATH_FADE, 0.01),
		0.0, 1.0)
	if ultra:
		_draw_beam(b * reveal, fade)
	else:
		_draw_cone(b * reveal, fade)
	if (element == "storm" or ultra) and fade > 0.2:
		var bright: Color = palette(element)[0] as Color
		for bolt: PackedVector2Array in _bolts:
			var cut := PackedVector2Array()
			for point: Vector2 in bolt:
				cut.append(point * reveal)
			draw_polyline(cut, Color(bright, 0.85 * fade), 2.5, true)


## The gathering at the mouth: a glow that swells and flickers and motes that
## fall into it. An ultra charges bigger and crackles.
func _draw_charge(ready: float) -> void:
	var colours: Array = palette(element)
	var flicker: float = 0.85 + 0.15 * sin(_age * 38.0 + _seed)
	var radius: float = lerpf(8.0, half_width * (2.0 if ultra else 1.4), ready) * flicker
	var points := PackedVector2Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	_fan(points, shades, indices, Vector2.ZERO, radius * 1.8, Color(colours[2] as Color, 0.0),
		Color(colours[1] as Color, 0.45 * ready))
	_fan(points, shades, indices, Vector2.ZERO, radius, Color(colours[1] as Color, 0.0),
		Color(colours[0] as Color, 0.9 * ready))
	BloodInk.paint(self, points, shades, indices)
	for index: int in 7:
		var phase: float = fposmod(_age * 1.6 + float(index) / 7.0, 1.0)
		var angle: float = _seed + float(index) * 2.4
		var at: Vector2 = Vector2.RIGHT.rotated(angle) * radius * 3.2 * (1.0 - phase)
		draw_circle(at, 2.0 + 2.0 * phase, Color(colours[0] as Color, 0.8 * ready))
	if ultra:
		for index: int in 4:
			var angle: float = _age * 9.0 + float(index) * TAU / 4.0
			var from: Vector2 = Vector2.RIGHT.rotated(angle) * radius * 0.6
			var mid: Vector2 = Vector2.RIGHT.rotated(angle + 0.5) * radius * 1.5 \
				+ Vector2(_dice.randf_range(-4.0, 4.0), _dice.randf_range(-4.0, 4.0))
			var tip: Vector2 = Vector2.RIGHT.rotated(angle + 0.9) * radius * 2.1
			draw_polyline(PackedVector2Array([from, mid, tip]),
				Color(colours[0] as Color, 0.9 * ready), 2.0, true)


## The breath: three feathered layers from a narrow mouth to a wide front,
## licking at the edges on their own clocks.
func _draw_cone(b: Vector2, fade: float) -> void:
	var colours: Array = palette(element)
	var points := PackedVector2Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	_strip(points, shades, indices, b * 1.12, 1.45, colours[2] as Color, colours[1] as Color,
		0.6 * fade, 0.0)
	_strip(points, shades, indices, b * 1.06, 1.0, colours[1] as Color, colours[1] as Color,
		0.85 * fade, 1.7)
	_strip(points, shades, indices, b, 0.45, colours[1] as Color, colours[0] as Color,
		1.0 * fade, 3.1)
	BloodInk.paint(self, points, shades, indices)


## The hyperbeam: a straight ray of constant width that breathes fast, a fire
## skin, a violet sheath and a white core, with two arcs wound round it.
func _draw_beam(b: Vector2, fade: float) -> void:
	var colours: Array = palette(element)
	var along: Vector2 = b.normalized()
	var across: Vector2 = along.orthogonal()
	var pulse: float = 1.0 + 0.16 * sin(_age * 44.0)
	var points := PackedVector2Array()
	var shades := PackedColorArray()
	var indices := PackedInt32Array()
	for layer: Array in [[2.4, colours[2], 0.45], [1.25, colours[1], 0.8], [0.4, colours[0], 1.0]]:
		var wide: float = half_width * float(layer[0]) * pulse
		var tint: Color = layer[1] as Color
		_band(points, shades, indices, b, across * wide, Color(tint, 0.0),
			Color(tint, float(layer[2]) * fade))
	BloodInk.paint(self, points, shades, indices)
	for hand: int in 2:
		var helix := PackedVector2Array()
		var turns: float = b.length() / 90.0
		for index: int in 49:
			var t: float = float(index) / 48.0
			var swing: float = sin(t * turns * TAU + _age * 32.0 + float(hand) * PI)
			helix.append(b * t + across * swing * half_width * 0.95 * pulse)
		draw_polyline(helix, Color(colours[0] as Color, 0.8 * fade), 2.2, true)


## One layer of the cone as rows of five vertices: transparent rims, a body
## and a spine, so the edge is soft and the middle is bright.
func _strip(points: PackedVector2Array, shades: PackedColorArray,
		indices: PackedInt32Array, b: Vector2, scale: float, rim: Color, spine: Color,
		alpha: float, offset: float) -> void:
	var along: Vector2 = b.normalized()
	var across: Vector2 = along.orthogonal()
	var rows: int = 20
	var first: int = points.size()
	for row: int in rows + 1:
		var t: float = float(row) / float(rows)
		var lick: float = 1.0 + 0.2 * sin(_age * 13.0 + t * 9.0 + _seed + offset)
		var half: float = lerpf(half_width * 0.28, half_width * 1.65, pow(t, 0.62)) \
			* scale * lick
		var sway: float = sin(_age * 7.0 + t * 5.0 + offset) * half * 0.1
		var centre: Vector2 = b * t + across * sway
		# Brightest near the mouth, thinning out at the front, and the front
		# itself feathered away - a breath ending on a straight cut reads as a
		# shape rather than as something still rolling.
		var strength: float = alpha * lerpf(1.0, 0.6, t) \
			* clampf((1.0 - t) / 0.2, 0.0, 1.0)
		points.append(centre + across * half)
		shades.append(Color(rim, 0.0))
		points.append(centre + across * half * 0.5)
		shades.append(Color(rim.lerp(spine, 0.5), strength * 0.75))
		points.append(centre)
		shades.append(Color(spine, strength))
		points.append(centre - across * half * 0.5)
		shades.append(Color(rim.lerp(spine, 0.5), strength * 0.75))
		points.append(centre - across * half)
		shades.append(Color(rim, 0.0))
	for row: int in rows:
		var a: int = first + row * 5
		var c: int = a + 5
		for lane: int in 4:
			indices.append_array([a + lane, a + lane + 1, c + lane,
				a + lane + 1, c + lane + 1, c + lane])


## A straight band from the mouth to `b`, transparent at both edges.
func _band(points: PackedVector2Array, shades: PackedColorArray,
		indices: PackedInt32Array, b: Vector2, side: Vector2, rim: Color,
		spine: Color) -> void:
	var first: int = points.size()
	for end: Vector2 in [Vector2.ZERO, b]:
		points.append(end + side)
		shades.append(rim)
		points.append(end)
		shades.append(spine)
		points.append(end - side)
		shades.append(rim)
	for lane: int in 2:
		indices.append_array([first + lane, first + lane + 1, first + 3 + lane,
			first + lane + 1, first + 4 + lane, first + 3 + lane])


## A soft disc: a bright middle falling to a clear rim.
func _fan(points: PackedVector2Array, shades: PackedColorArray,
		indices: PackedInt32Array, centre: Vector2, radius: float, rim: Color,
		middle: Color) -> void:
	var first: int = points.size()
	points.append(centre)
	shades.append(middle)
	var steps: int = 20
	for step: int in steps:
		points.append(centre + Vector2.RIGHT.rotated(TAU * float(step) / float(steps)) * radius)
		shades.append(rim)
	for step: int in steps:
		indices.append_array([first, first + 1 + step, first + 1 + (step + 1) % steps])


## `FrameProfile` bucket "d_dragon_breath": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_dragon_breath", started)


## `FrameProfile` bucket "p_dragon_breath": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_dragon_breath", started)
