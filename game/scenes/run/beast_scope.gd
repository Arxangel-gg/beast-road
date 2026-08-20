class_name BeastScope
extends Node2D

## The walk (GDD §7). The beast crossing the land with the town on its back —
## References/Scope3(Beast).png — plus how far there is left to go.
##
## This scope shows state and changes nothing. Its job is to make distance feel
## like a place rather than a number in the corner of a HUD.

## How far the parallax layers scroll per distance unit.
const BACKDROP_SCROLL: float = 2.4
const FOREGROUND_SCROLL: float = 6.0

@export var backdrop: Sprite2D
@export var beast: Sprite2D
@export var route_line: Line2D
@export var route_marker: Sprite2D

## Each scope owns its camera; the run makes the right one current when the
## scope changes, so switching does not leave the view sitting in another scope.
@export var camera: Camera2D


func activate() -> void:
	if camera != null:
		camera.make_current()
	CursorKit.use_default()

var _backdrop_clone: Sprite2D = null
var _ground_tile_px: int = 32
var _ground_baked_region: String = ""
var _ground_pieces: Array[Sprite2D] = []
var _zoomed_out: bool = false
var _bob: float = 0.0
## Authored frames, when the art exists. Empty falls back to the single profile
## sprite, which is what shipped before them.
##
## Layered *over* the procedural gait rather than replacing it. The bob, the step
## sink, the settle and the footfall impulses stay exactly as they were - frames
## give the legs somewhere to be while all of that is happening. Swapping the
## procedural motion out for a spritesheet would trade a gait that responds to
## speed, pauses and terrain for one that plays at a fixed rate.
var _walk_frames: Array[Texture2D] = []
var _idle_frames: Array[Texture2D] = []
var _frame_clock: float = 0.0

## 1.0 while the single profile sprite is in use, larger once frames load. The
## presentation toggle multiplies this rather than replacing it.
var _frame_scale: float = 1.0

var _gait_pause_left: float = 0.0
var _gait_step: int = 0
var _step_sink: float = 0.0
var _idle_breath: float = 0.0
var _step_shake_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_setup_route()
	_setup_backdrop()
	_setup_ground()
	_load_frames()
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: _apply_act_backdrop())


## The ground the beast walks over, from the region's sidescroller tileset.
##
## Baked into one strip and scrolled as a leapfrogging pair, the same trick the
## backdrop uses: two nodes tile an arbitrary distance, and the journey is
## arbitrarily long. Baking rather than laying tiles as nodes matters more here
## than it looks - a strip wide enough to leapfrog is a hundred tiles, twice.
##
## Absent art falls through to nothing rather than to a placeholder. The scope
## read fine without a ground for the whole project so far; a magenta strip
## across the bottom would be a downgrade.
func _setup_ground() -> void:
	for index: int in 2:
		var piece := Sprite2D.new()
		piece.name = "Ground%d" % index
		piece.centered = true
		piece.z_index = Balance.BEAST_GROUND_Z
		piece.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
		piece.add_to_group(Graphics.FILTER_GROUP)
		piece.position.y = Balance.BEAST_GROUND_Y + Balance.BEAST_FRAME_BASE_Y
		add_child(piece)
		_ground_pieces.append(piece)
	_refresh_ground()


## Rebakes the strip when the act's region changes, and relights it either way.
##
## The strip used to be baked once in `_ready`. A run reaches the desert and the
## snow without the scope ever being rebuilt, so both walked on Act I's jungle
## rock - and the two tilesets that exist to make the acts feel different were
## generated, shipped, and never drawn.
func _refresh_ground() -> void:
	if _ground_pieces.size() < 2:
		return
	var region: String = _ground_region()
	if region != _ground_baked_region:
		var strip: ImageTexture = _bake_ground()
		if strip == null:
			return
		_ground_baked_region = region
		# Drawn at the same grain as the beast and the sky rather than at its
		# native 32px, so the three do not read as three resolutions stacked.
		var grain: float = Balance.BEAST_GROUND_TILE_WORLD \
			/ maxf(float(_ground_tile_px), 1.0)
		for piece: Sprite2D in _ground_pieces:
			piece.texture = strip
			piece.scale = Vector2.ONE * grain
	var tint: Color = _ground_tint()
	for piece: Sprite2D in _ground_pieces:
		piece.modulate = tint


## The light the near ground stands in, taken from the backdrop's own horizon.
##
## Hue comes from the sampled band normalised to its brightest channel and then
## pulled most of the way back toward white, so the ground picks up the sky's
## colour without picking up its exposure or compounding its own. Brightness
## comes from the band's luminance against a neutral, clamped at 1 so a white
## desert sky cannot wash the art out past what was drawn.
func _ground_tint() -> Color:
	if backdrop == null or backdrop.texture == null:
		return Color.WHITE
	var image: Image = backdrop.texture.get_image()
	if image == null:
		return Color.WHITE
	var height: int = image.get_height()
	var from: int = maxi(0, height - maxi(1,
		int(round(float(height) * Balance.BEAST_GROUND_LIGHT_BAND))))
	var total: Color = Color(0.0, 0.0, 0.0, 0.0)
	var samples: int = 0
	# Every fourth pixel: this runs once per act, and the average of a horizon
	# band does not need every texel to be right.
	for y: int in range(from, height, 2):
		for x: int in range(0, image.get_width(), 4):
			var pixel: Color = image.get_pixel(x, y)
			total += Color(pixel.r, pixel.g, pixel.b, 0.0)
			samples += 1
	if samples == 0:
		return Color.WHITE
	var lit := Color(total.r / float(samples), total.g / float(samples),
		total.b / float(samples))
	var peak: float = maxf(maxf(lit.r, lit.g), maxf(lit.b, 0.001))
	var brightness: float = clampf(
		lit.get_luminance() / Balance.BEAST_GROUND_LIGHT_NEUTRAL,
		Balance.BEAST_GROUND_LIGHT_FLOOR, 1.0) * Balance.BEAST_GROUND_SHADE
	var hue := Color(lit.r / peak, lit.g / peak, lit.b / peak)
	var mixed: Color = Color.WHITE.lerp(hue, Balance.BEAST_GROUND_LIGHT_HUE)
	# Three components, not four: multiplying a Color by a float scales alpha
	# with it, which would fade the ground out rather than darken it.
	return Color(mixed.r * brightness, mixed.g * brightness, mixed.b * brightness)


## Composites one tiling strip of ground from the region's sixteen-tile set.
##
## The set is a **corner mask set**, not a row of interchangeable slabs: exactly
## one tile is solid, one is empty, and the other fourteen are the transitions
## between. The first version indexed it by column - first four across the top,
## next four repeating below - which laid fourteen part-transparent transitions
## in a row and drew on screen as a single hard black line at the beast's feet
## with the sky showing through everywhere else.
##
## Which mask each tile answers to is **measured from its own alpha** rather than
## assumed from its filename, so regenerating a tileset cannot silently invert
## the convention and put the sky underground.
func _bake_ground() -> ImageTexture:
	var by_mask: Dictionary = {}
	for index: int in 16:
		var path: String = Balance.BEAST_GROUND_TILE_FORMAT % [_ground_region(), index]
		if not ResourceLoader.exists(path):
			return null
		var image: Image = (load(path) as Texture2D).get_image()
		image.convert(Image.FORMAT_RGBA8)
		by_mask[_tile_mask(image)] = image
		_ground_tile_px = image.get_width()

	var across: int = Balance.BEAST_GROUND_TILES_ACROSS
	var down: int = Balance.BEAST_GROUND_TILES_DOWN
	var canvas: Image = Image.create_empty(across * _ground_tile_px,
		down * _ground_tile_px, false, Image.FORMAT_RGBA8)

	# The surface, as a height per column boundary. Periodic in `across` so the
	# strip's right edge lines up with its own left edge when it wraps - a rolling
	# horizon that stepped at the wrap would advertise the trick every few seconds.
	var surface: PackedInt32Array = PackedInt32Array()
	for corner: int in across + 1:
		var phase: float = TAU * float(corner) / float(across)
		var roll: float = (sin(phase) + sin(phase * 2.0) * 0.5) * Balance.BEAST_GROUND_ROLL
		surface.append(down / 2 - int(round(roll)))

	const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1)]
	for column: int in across:
		for row: int in down:
			var mask: int = 0
			for bit: int in 4:
				var corner: Vector2i = Vector2i(column, row) + CORNERS[bit]
				if corner.y >= surface[corner.x]:
					mask |= 1 << bit
			var piece: Image = by_mask.get(mask, null) as Image
			if piece == null:
				continue
			canvas.blend_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()),
				Vector2i(column * _ground_tile_px, row * _ground_tile_px))
	return ImageTexture.create_from_image(canvas)


## Which corners of a tile carry ground, read from its own alpha.
##
## Bit 0 is the top-left corner, then clockwise: the convention the battlefield
## ground and the raid cliffs already use, so all three agree.
func _tile_mask(image: Image) -> int:
	var quarter: int = image.get_width() / 4
	var far: int = image.get_width() - quarter
	var points: Array[Vector2i] = [Vector2i(quarter, quarter), Vector2i(far, quarter),
		Vector2i(far, far), Vector2i(quarter, far)]
	var mask: int = 0
	for bit: int in 4:
		if image.get_pixelv(points[bit]).a > 0.5:
			mask |= 1 << bit
	return mask


## Which tileset the current act uses.
##
## Falls back to the first region rather than to nothing: a missing set costs the
## act its own material, not its ground.
func _ground_region() -> String:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null and ResourceLoader.exists(
			Balance.BEAST_GROUND_TILE_FORMAT % [terrain.id, 0]):
		return terrain.id
	return "jungle"


## Loads whatever walk and idle frames exist, by convention.
##
## Absence is a supported state, not a failure: the beast shipped as one static
## sprite and still works as one. That matters for a scope whose art arrives in
## pieces - a missing frame set should cost the animation, not the screen.
func _load_frames() -> void:
	_walk_frames = _frame_series(Balance.BEAST_WALK_FRAME_FORMAT)
	_idle_frames = _frame_series(Balance.BEAST_IDLE_FRAME_FORMAT)
	if _walk_frames.is_empty() and _idle_frames.is_empty():
		return
	# The frames are a quarter the size of the profile sprite they replace, so
	# without this the beast arrives correct and tiny. Scaled here rather than in
	# the scene because it depends on *which* art loaded, and the scene has no way
	# to know that.
	_frame_scale = Balance.BEAST_FRAME_SCALE
	if beast != null:
		beast.scale = Vector2.ONE * _frame_scale
		beast.position.y = Balance.BEAST_FRAME_BASE_Y


func _frame_series(format: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for index: int in Balance.BEAST_FRAME_MAX:
		var path: String = format % index
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


## Picks the frame for this moment, from whichever series is playing.
##
## Driven by the *gait phase* for the walk rather than by a timer, so the frames
## and the bob stay locked together: the beast plants a foot on the same beat the
## camera shakes on, because both read the same number.
func _drive_frames(delta: float, walking: bool, speed_ratio: float) -> void:
	if beast == null:
		return
	var series: Array[Texture2D] = _walk_frames if walking else _idle_frames
	if series.is_empty():
		return
	var index: int = 0
	if walking:
		index = int(floor(_bob / TAU * float(series.size()))) % series.size()
	else:
		_frame_clock += delta * Balance.BEAST_IDLE_FRAME_RATE
		index = int(floor(_frame_clock)) % series.size()
	beast.texture = series[maxi(index, 0)]


## The backdrop was a single sprite whose x was decremented forever. Once it had
## travelled its own width there was nothing behind it, so the view went blank -
## and the texture never changed, so every act looked like Ashfen.
##
## A second copy sits one width to the right and the pair wrap around each other,
## which tiles an arbitrary distance from two nodes.
func _setup_backdrop() -> void:
	if backdrop == null:
		return
	# The scope camera is centred at world origin. An uncentred 1920x1080 sprite
	# therefore began at that origin and covered only the lower-right quarter of
	# the screen, leaving the rest as the project's grey clear colour.
	backdrop.centered = true
	backdrop.z_index = Balance.BEAST_BACKDROP_Z
	_backdrop_clone = Sprite2D.new()
	_backdrop_clone.centered = true
	# Mirrored, so the join is a reflection rather than a cut. The backdrop is a
	# painting and does not tile: butting its right edge against its own left edge
	# put a hard vertical seam through the sky every time the pair leapfrogged.
	# Flipped, both joins are edge-against-identical-edge and neither shows.
	_backdrop_clone.flip_h = true
	_backdrop_clone.z_index = backdrop.z_index
	backdrop.add_sibling(_backdrop_clone)
	_apply_act_backdrop()


## Each act has its own sky. Falls back to act 1 rather than going blank if a
## backdrop is missing.
func _apply_act_backdrop() -> void:
	if backdrop == null:
		return
	var path: String = "res://art/bg/macro_act%d.png" % clampi(RunState.act, 1, Balance.ACT_COUNT)
	if not ResourceLoader.exists(path):
		path = "res://art/bg/macro_act1.png"
	if not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path)
	backdrop.texture = texture
	# Scaled to fill the view height rather than drawn at its native size.
	#
	# The backdrops were 1920x1080 paintings and are 688x384 pixel art now, which
	# is a quarter the height - drawn 1:1 the sky would occupy the middle third of
	# the screen with the clear colour above and below it. Derived from the
	# texture so it stays right whatever size the art is next time.
	var fill: float = Balance.BEAST_BACKDROP_HEIGHT / maxf(float(texture.get_height()), 1.0)
	backdrop.scale = Vector2.ONE * fill
	if _backdrop_clone != null:
		_backdrop_clone.texture = texture
		_backdrop_clone.scale = backdrop.scale
		_backdrop_clone.modulate = backdrop.modulate
	# A new sky is new light and, past Act I, new ground under it.
	_refresh_ground()


## Two sprites leapfrogging: whichever has scrolled fully off the left is moved
## one width to the right of the other.
func _scroll_backdrop() -> void:
	if backdrop == null or backdrop.texture == null or _backdrop_clone == null:
		return
	var width: float = backdrop.texture.get_width() * backdrop.scale.x
	if width <= 0.0:
		return
	var offset: float = fmod(RunState.distance_travelled * BACKDROP_SCROLL, width)
	backdrop.position.x = -offset
	_backdrop_clone.position.x = -offset + width
	_backdrop_clone.position.y = backdrop.position.y
	_scroll_ground()


## The ground scrolls faster than the sky, which is what sells the distance.
func _scroll_ground() -> void:
	if _ground_pieces.size() < 2 or _ground_pieces[0].texture == null:
		return
	var width: float = _ground_pieces[0].texture.get_width() * _ground_pieces[0].scale.x
	if width <= 0.0:
		return
	var offset: float = fmod(RunState.distance_travelled * Balance.BEAST_GROUND_SCROLL, width)
	_ground_pieces[0].position.x = -offset
	_ground_pieces[1].position.x = -offset + width


## True while the journey is not advancing and the beast should be at rest.
##
## Asks the run state rather than the journey node: the beast scope is a window
## onto the run and must not hold a reference to the systems driving it
## (CLAUDE.md §5).
func _standing_still() -> bool:
	return RunState.is_preparation() or RunState.phase == RunState.Phase.ENDED


## The standing idle: a slow breath, and everything the walk was doing wound
## down rather than cut. A gait that stops on the frame the phase changes reads
## as a freeze; settling reads as an animal coming to a halt.
func _settle_to_idle(delta: float) -> void:
	_gait_pause_left = 0.0
	_step_sink = move_toward(_step_sink, 0.0, delta * 2.0)
	_step_shake_left = maxf(_step_shake_left - delta * 2.0, 0.0)
	_idle_breath += delta * Balance.BEAST_IDLE_BREATH_RATE * TAU
	if beast != null:
		var rest_y: float = sin(_idle_breath) * Balance.BEAST_IDLE_BREATH
		beast.position.y = move_toward(beast.position.y, rest_y, delta * 90.0)
		beast.position.x = move_toward(beast.position.x,
			Balance.BEAST_PROFILE_BASE_X, delta * 60.0)
	_update_step_shake(delta, 0.0)


func _process(delta: float) -> void:
	# The beast uses the same paired-support cadence as the battlefield camera.
	# Each alternating plant holds for a beat, then the full body settles under
	# its weight; at least one support pair is always in stance.
	var speed_ratio: float = clampf(RunState.beast_speed / Balance.BEAST_BASE_SPEED, 0.0, 1.5)

	# Standing still during Preparation.
	#
	# The beast walks because the journey advances, and the journey is stopped
	# while the player is building - so a beast still lumbering along, still
	# planting footfalls and still shaking the battlefield camera, was animating
	# a journey that was not happening. It breathes instead, and the gait, the
	# footfalls and the step shake all stop with it.
	if _standing_still():
		_settle_to_idle(delta)
		_drive_frames(delta, false, 0.0)
		return
	_drive_frames(delta, true, speed_ratio)

	if _gait_pause_left > 0.0:
		_gait_pause_left = maxf(_gait_pause_left - delta, 0.0)
	else:
		_bob += delta * Balance.BEAST_GAIT_FREQUENCY * TAU * maxf(speed_ratio, 0.25)
		var step: int = int(floor(_bob / PI))
		if step > _gait_step:
			_gait_step = step
			_gait_pause_left = Balance.BEAST_STEP_PAUSE
			_step_sink = 1.0
			_step_shake_left = Balance.BEAST_STEP_SHAKE_TIME
			if camera != null and camera.is_current():
				EventBus.footfall.emit(beast.global_position if beast != null else Vector2.ZERO,
					Balance.BEAST_STEP_MASS * speed_ratio)
				# The same four-beat cardinal the battlefield camera plants on,
				# taken from the one place that defines it rather than restated
				# here - the two used to carry separate copies of the diagonal
				# and could drift apart without anything noticing.
				EventBus.beast_step_landed.emit(
					CameraRig.step_cardinal(_gait_step) * Balance.BEAST_STEP_WORLD_IMPULSE,
					speed_ratio)
	_step_sink = move_toward(_step_sink, 0.0,
		delta / maxf(Balance.BEAST_STEP_SHAKE_TIME, 0.01))
	if beast != null:
		var presentation_phase: float = _lumbered_phase(_bob)
		beast.position.y = sin(presentation_phase) * Balance.BEAST_PROFILE_VERTICAL \
			+ Balance.BEAST_STEP_SINK * _step_sink
		beast.position.x = Balance.BEAST_PROFILE_BASE_X \
			+ sin(presentation_phase * 0.5) * Balance.BEAST_PROFILE_HORIZONTAL
	_update_step_shake(delta, speed_ratio)

	_scroll_backdrop()

	_update_route()


func _lumbered_phase(raw_phase: float) -> float:
	var half_step: float = floor(raw_phase / PI)
	var progress: float = fmod(raw_phase, PI) / PI
	var eased: float = pow(clampf(progress, 0.0, 1.0), Balance.BEAST_GAIT_WINDUP_POWER)
	return (half_step + eased) * PI


func _update_step_shake(delta: float, strength: float) -> void:
	if camera == null:
		return
	if _step_shake_left <= 0.0 or not camera.is_current():
		camera.offset = Vector2.ZERO
		return
	_step_shake_left = maxf(_step_shake_left - delta, 0.0)
	var falloff: float = _step_shake_left / maxf(Balance.BEAST_STEP_SHAKE_TIME, 0.01)
	var setting: float = UserSettings.number(UserSettings.GAIT_KEY, 0.65) \
		* float(MetaState.settings.get(UserSettings.SHAKE_KEY, 1.0))
	var amount: float = Balance.BEAST_STEP_SHAKE * falloff * setting * strength
	camera.offset = Vector2(_rng.randf_range(-amount, amount),
		_rng.randf_range(-amount, amount))


## Toggled from the HUD. Zooming out swaps the walking view for the whole route,
## which is where "how far to the next crossroad" actually reads.
func set_zoomed_out(value: bool) -> void:
	_zoomed_out = value
	if route_line != null:
		route_line.visible = value
	if route_marker != null:
		route_marker.visible = value
	if beast != null:
		beast.scale = Vector2.ONE * _frame_scale * (0.45 if value else 1.0)
	var tint: Color = Color(0.55, 0.55, 0.6) if value else Color.WHITE
	if backdrop != null:
		backdrop.modulate = tint
	if _backdrop_clone != null:
		_backdrop_clone.modulate = tint


func is_zoomed_out() -> bool:
	return _zoomed_out


func toggle_zoom() -> void:
	set_zoomed_out(not _zoomed_out)


## The whole journey as one line, with a tick at every crossroad and act
## boundary so the shape of the run is legible at a glance.
func _setup_route() -> void:
	if route_line == null:
		return
	var left: float = -820.0
	var right: float = 820.0
	route_line.points = PackedVector2Array([Vector2(left, 220.0), Vector2(right, 220.0)])
	route_line.width = 6.0
	route_line.default_color = Color(0.85, 0.80, 0.72, 0.5)
	route_line.visible = false

	var segments: int = int(Balance.JOURNEY_TOTAL_DISTANCE / Balance.SEGMENT_DISTANCE)
	for i: int in range(1, segments):
		var t: float = float(i) / float(segments)
		var tick := Line2D.new()
		var x: float = lerpf(left, right, t)
		var is_act_boundary: bool = int(round(t * Balance.JOURNEY_TOTAL_DISTANCE)) % int(Balance.ACT_DISTANCE) == 0
		var height: float = 34.0 if is_act_boundary else 18.0
		tick.points = PackedVector2Array([Vector2(x, 220.0 - height), Vector2(x, 220.0 + height)])
		tick.width = 5.0 if is_act_boundary else 3.0
		tick.default_color = Color(0.91, 0.64, 0.24, 0.9) if is_act_boundary else Color(0.85, 0.80, 0.72, 0.6)
		route_line.add_child(tick)

	if route_marker != null:
		route_marker.visible = false


func _update_route() -> void:
	if route_marker == null or not _zoomed_out:
		return
	route_marker.position = Vector2(lerpf(-820.0, 820.0, RunState.journey_ratio()), 220.0)
