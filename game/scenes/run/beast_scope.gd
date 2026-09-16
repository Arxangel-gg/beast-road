class_name BeastScope
extends Node2D

## The walk (GDD §7). The beast crossing the land with the town on its back —
## References/Scope3(Beast).png — plus how far there is left to go.
##
## This scope shows state and changes nothing. Its job is to make distance feel
## like a place rather than a number in the corner of a HUD.

@export var backdrop: Sprite2D
@export var beast: Sprite2D
@export var route_line: Line2D
@export var route_marker: Sprite2D

## Each scope owns its camera; the run makes the right one current when the
## scope changes, so switching does not leave the view sitting in another scope.
@export var camera: Camera2D



## The hour, on the walk's own tint.
func _on_day_phase(_phase: float, tint: Color, _darkness: float) -> void:
	if _day_tint != null and is_instance_valid(_day_tint):
		_day_tint.color = Graphics.graded(tint)


func activate() -> void:
	if camera != null:
		camera.make_current()
	CursorKit.use_default()

## The mirrored copies of the sky either side of the authored one. Rebuilt when
## the act changes the art and when the window changes how much of it is seen.
var _backdrop_copies: Array[Sprite2D] = []

## Two procedural silhouettes: a hazed ridge between the sky and the ground, and
## a near band that passes in front of the beast. Built rather than painted -
## see `scripts/systems/parallax_band.gd` for why that is the only option here.
var _ridge: ParallaxBand = null
var _foreground: ParallaxBand = null
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
## The quake's own push on the beast, taken off again next frame so it never
## accumulates into the gait.
var _quake_offset: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _day_tint: CanvasModulate = null
## The scope's own weather, the same system the road uses.
var _weather: WeatherVeil = null
## Two more distances in the parallax ladder (2026-09-14).
var _range_band: ParallaxBand = null
## The region's own painted horizon (2026-09-14).
var _skyline: ParallaxStrip = null
var _mid_band: ParallaxBand = null
var _town_light_anchor: Node2D = null
## What the earth is doing to the battlefield, drawn on the carried town.
var _omens: BeastOmens = null

## The tail, a child of the body so it inherits the gait and the scale, drawn
## behind the body from the rear hip. Its frames run on the body's own gait
## phase while walking - the two are one animal - and on their own slow clock
## at rest.
var _tail: BeastTailSpline = null
## The far woods and the near brush: the region's own trees and plants,
## scattered once a period and slid past at their own rates.
var _woods: ParallaxScatter = null
var _brush: ParallaxScatter = null
## How far into the act, with the crossroads marked.
var _track: ActTrack = null


func _ready() -> void:
	_rng.randomize()
	_setup_route()
	_setup_backdrop()
	_setup_ground()
	_load_frames()
	_load_tail()
	_setup_lighting()
	_setup_track()
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: _apply_act_backdrop())


## Beast scope shares the same clock as the battlefield. A warm light from the
## carried settlement keeps the beast and its back readable at deep night while
## the surrounding world remains genuinely dark.
func _setup_lighting() -> void:
	_day_tint = CanvasModulate.new()
	_day_tint.name = "DayTint"
	_day_tint.color = Graphics.graded(DayNight.tint)
	_day_tint.add_to_group(Graphics.TINT_GROUP)
	add_child(_day_tint)
	# A method rather than a lambda: see `Battlefield._setup_lighting`.
	DayNight.phase_changed.connect(_on_day_phase)

	_omens = BeastOmens.new()
	_omens.name = "Omens"
	add_child(_omens)
	_town_light_anchor = Node2D.new()
	_town_light_anchor.name = "CarriedTownLight"
	add_child(_town_light_anchor)
	LightKit.add_light(_town_light_anchor, Balance.BEAST_TOWN_LIGHT_COLOUR,
		Balance.BEAST_TOWN_LIGHT_RADIUS, Balance.BEAST_TOWN_LIGHT_ENERGY,
		Balance.BEAST_TOWN_LIGHT_FLICKER)
	_update_town_light()
	_apply_beast_environment_tint()


func _update_town_light() -> void:
	if _town_light_anchor != null and beast != null:
		_town_light_anchor.position = beast.position \
			+ Vector2(0.0, -Balance.BEAST_TOWN_LIGHT_LIFT)
	# The omens hang off the same place the town's own light does, so a funnel
	# stands over the keep rather than over the animal carrying it.
	if _omens != null and beast != null:
		_omens.town = beast.position + Vector2(0.0, -Balance.BEAST_TOWN_LIGHT_LIFT)
		_omens.town_width = Balance.BEAST_OMEN_TOWN_WIDTH * _frame_scale
		_omens.light = DayNight.tint


func _apply_beast_environment_tint() -> void:
	if beast != null:
		beast.modulate = Color.WHITE.lerp(_ground_tint(),
			Balance.BEAST_ENVIRONMENT_TINT)


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


## The horizon's own colour, averaged, with nothing done to it.
##
## `_ground_tint` below samples the same band and then normalises it toward white,
## because it is used as a `modulate` and a tint must not darken what it tints.
## A silhouette is not a tint - it is painted with an actual colour - and reusing
## the tint for one produced a near-white ridge across half the sky. Two callers,
## two different questions, and only one of them wants the exposure removed.
func _horizon_colour() -> Color:
	if backdrop == null or backdrop.texture == null:
		return Color(0.2, 0.2, 0.25)
	var image: Image = backdrop.texture.get_image()
	if image == null:
		return Color(0.2, 0.2, 0.25)
	var height: int = image.get_height()
	var from: int = maxi(0, height - maxi(1,
		int(round(float(height) * Balance.BEAST_GROUND_LIGHT_BAND))))
	var total: Color = Color(0.0, 0.0, 0.0, 0.0)
	var samples: int = 0
	for y: int in range(from, height, 2):
		for x: int in range(0, image.get_width(), 4):
			var pixel: Color = image.get_pixel(x, y)
			total += Color(pixel.r, pixel.g, pixel.b, 0.0)
			samples += 1
	if samples == 0:
		return Color(0.2, 0.2, 0.25)
	return Color(total.r / float(samples), total.g / float(samples),
		total.b / float(samples))


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


## The tail: loaded by the same convention as the body, attached at the rear
## hip, and absent without complaint when the frames are not there.
func _load_tail() -> void:
	var frames: Array[Texture2D] = _frame_series(Balance.BEAST_TAIL_IDLE_FRAME_FORMAT)
	if frames.is_empty():
		frames = _frame_series(Balance.BEAST_TAIL_WALK_FRAME_FORMAT)
	if beast == null or frames.is_empty():
		return
	# **A spline rather than a sprite** (owner, 2026-09-15). See
	# `beast_tail_spline.gd`: the painting is cut into slices and laid along a
	# chain whose first point is the body's own stub row, so the join cannot
	# come apart on any frame of the gait, and the limb whips rather than
	# cycling through six drawings of itself.
	_tail = BeastTailSpline.new()
	_tail.name = "Tail"
	_tail.adopt(frames[0])
	_tail.frame_time = 1.0 / maxf(Balance.BEAST_IDLE_FRAME_RATE, 1.0)
	if beast.texture != null:
		_tail.harmonise(beast.texture)
	# **The tail carries no material and is never scaled to fit.** It is drawn
	# whole and placed; the beast's own stub is the end that dissolves into it.
	# See `beast_stub_fade.gdshader` (owner's correction, 2026-09-13).
	var fade := ShaderMaterial.new()
	fade.shader = load("res://scripts/shaders/beast_stub_fade.gdshader")
	fade.set_shader_parameter("fade_px", Balance.BEAST_STUB_FADE_PX)
	beast.material = fade
	# The spline puts its own root on its origin, so the node simply goes where
	# the body's stub is - see `_place_tail`.
	_tail.position = Balance.BEAST_TAIL_ANCHOR
	# **The tail was drawn darker than the hide it grows out of.** `modulate`
	# is inherited from the beast, so the day tint and the environment grade
	# already reach it; this multiplies on top and corrects only the difference
	# the two assets were generated with. See `Balance.BEAST_TAIL_GRADE`.
	_tail.modulate = Balance.BEAST_TAIL_GRADE
	_tail.show_behind_parent = true
	_place_tail()
	_tail.texture_filter = beast.texture_filter
	beast.add_child(_tail)


## What the tail is doing: harder on the march, and leaning with the weather.
##
## **The wind is the road's own**, not a second copy of it: `RunState.wind` is
## what the foliage and the wildfire read, so the beast's tail and the plants
## beside the road lean the same way at the same moment.
func _drive_tail(_delta: float, walking: bool) -> void:
	if _tail == null:
		return
	_tail.sway = Balance.BEAST_TAIL_WALK_SWAY if walking else 1.0
	_tail.wind = clampf(RunState.wind.x, -1.0, 1.0)
	_place_tail()


## The act track, on its own layer so the scope's camera never moves it.
func _setup_track() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrackLayer"
	layer.layer = 8
	add_child(layer)
	_track = ActTrack.new()
	_track.name = "ActTrack"
	_track.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_track.offset_left = -ActTrack.WIDTH * 0.5
	_track.offset_right = ActTrack.WIDTH * 0.5
	_track.offset_bottom = -Balance.BEAST_TRACK_BOTTOM_MARGIN
	_track.offset_top = _track.offset_bottom - ActTrack.HEIGHT
	layer.add_child(_track)
	layer.visible = camera != null and camera.is_current()


## Whether the act track is showing. The run calls this with the scope, so
## the track never draws over another scope's screen.
func set_track_visible(showing: bool) -> void:
	if _track != null and _track.get_parent() != null:
		(_track.get_parent() as CanvasLayer).visible = showing


## Picks the frame for this moment, from whichever series is playing.
##
## Driven by the *gait phase* for the walk rather than by a timer, so the frames
## and the bob stay locked together: the beast plants a foot on the same beat the
## camera shakes on, because both read the same number.
func _drive_frames(delta: float, walking: bool, speed_ratio: float) -> void:
	if beast == null:
		return
	_drive_tail(delta, walking)
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
	_place_tail()


## The backdrop was a single sprite whose x was decremented forever. Once it had
## travelled its own width there was nothing behind it, so the view went blank -
## and the texture never changed, so every act looked like Ashfen.
##
## Mirrored copies either side of the authored one, enough to cover the view.
func _setup_backdrop() -> void:
	if backdrop == null:
		return
	# The scope camera is centred at world origin. An uncentred 1920x1080 sprite
	# therefore began at that origin and covered only the lower-right quarter of
	# the screen, leaving the rest as the project's grey clear colour.
	backdrop.centered = true
	backdrop.z_index = Balance.BEAST_BACKDROP_Z
	get_viewport().size_changed.connect(_rebuild_backdrop_copies)
	_build_parallax()
	_build_weather()
	_apply_act_backdrop()


## Lays as many mirrored copies of the sky as the window needs.
##
## **Mirrored, so a join is a reflection rather than a cut.** The backdrop is a
## painting and does not tile: butting its right edge against its own left edge
## put a hard vertical seam through the sky every time the pair leapfrogged.
## Flipped, both joins are edge-against-identical-edge and neither shows - so
## every odd copy is flipped and every even one is not, and consecutive copies
## always meet reflected edges.
##
## **There used to be exactly one clone**, one width to the right, which covers
## `[-w/2, 3w/2]` of the node's own space while the scroll slides it over
## `(-w, 0]`. The guaranteed span was therefore only 967 units either side of the
## camera - fine on the 1920-wide desktop shape it was written against, and
## short on the 1280x592 landscape phone CI already builds for, whose visible
## world is 2,335 units across. The sky simply stopped, partway down the run,
## near the right edge of the screen.
func _rebuild_backdrop_copies() -> void:
	for copy: Sprite2D in _backdrop_copies:
		if is_instance_valid(copy):
			copy.queue_free()
	_backdrop_copies.clear()
	if backdrop == null or backdrop.texture == null:
		return
	var width: float = backdrop.texture.get_width() * backdrop.scale.x
	if width <= 0.0:
		return
	# **Half a width of headroom, because this sprite is centred and the layers
	# are not.** A band's period occupies `[k*w, (k+1)*w]`, so `periods_for`
	# promises `[-r*w, r*w]`; a centred sky straddles its own position instead,
	# which costs exactly half a width off the right of that promise. Asking for
	# half a width more reach is the correction, and it is done here rather than
	# in the helper so the three layers that share it stay simple.
	var reach: float = ParallaxBand.half_view(backdrop) + width * 0.5
	for period: int in ParallaxBand.periods_for(width, reach):
		if period == 0:
			# The authored node is the copy at zero; a second one on top of it
			# would double the sky's brightness wherever it is transparent.
			continue
		var copy := Sprite2D.new()
		copy.name = "Sky%d" % period
		copy.centered = true
		copy.flip_h = absi(period) % 2 == 1
		copy.texture = backdrop.texture
		copy.scale = backdrop.scale
		copy.modulate = backdrop.modulate
		copy.z_index = backdrop.z_index
		copy.texture_filter = backdrop.texture_filter
		copy.set_meta(&"sky_period", period)
		backdrop.add_sibling(copy)
		_backdrop_copies.append(copy)
	_scroll_backdrop()


## The two drawn bands.
##
## Added as children of this scope rather than siblings of the backdrop, so they
## travel with the scope and are removed with it. Their depth is set from Balance
## and must stay ordered against the sky and the ground: anything out of order
## reads as the world turning inside out.
func _build_parallax() -> void:
	# The furthest shape in the view, behind the ridge: nearly all air.
	_range_band = ParallaxBand.new()
	_range_band.name = "FarRange"
	_range_band.band_width = Balance.BEAST_BACKDROP_HEIGHT * (16.0 / 9.0) * 1.4
	_range_band.band_height = Balance.BEAST_RANGE_HEIGHT
	_range_band.baseline = Balance.BEAST_RANGE_BASELINE
	_range_band.z_index = Balance.BEAST_RANGE_Z
	add_child(_range_band)

	# The painted horizon, between the far range and the ridge.
	_skyline = ParallaxStrip.new()
	_skyline.name = "Skyline"
	_skyline.band_height = Balance.BEAST_SKYLINE_HEIGHT
	_skyline.baseline = Balance.BEAST_SKYLINE_BASELINE
	_skyline.z_index = Balance.BEAST_SKYLINE_Z
	add_child(_skyline)

	_ridge = ParallaxBand.new()
	_ridge.name = "Ridge"
	_ridge.band_width = Balance.BEAST_BACKDROP_HEIGHT * (16.0 / 9.0)
	_ridge.band_height = Balance.BEAST_RIDGE_HEIGHT
	_ridge.baseline = Balance.BEAST_RIDGE_BASELINE
	_ridge.z_index = Balance.BEAST_RIDGE_Z
	add_child(_ridge)

	# Between the woods and the brush, which was the one big jump in the ladder.
	_mid_band = ParallaxBand.new()
	_mid_band.name = "MidRise"
	_mid_band.band_width = Balance.BEAST_BACKDROP_HEIGHT * (16.0 / 9.0) * 0.85
	_mid_band.band_height = Balance.BEAST_MID_HEIGHT
	_mid_band.baseline = Balance.BEAST_MID_BASELINE
	_mid_band.z_index = Balance.BEAST_MID_Z
	add_child(_mid_band)

	_foreground = ParallaxBand.new()
	_foreground.name = "NearBand"
	_foreground.band_width = Balance.BEAST_BACKDROP_HEIGHT * (16.0 / 9.0) * 0.6
	_foreground.band_height = Balance.BEAST_FOREGROUND_HEIGHT
	_foreground.baseline = Balance.BEAST_FOREGROUND_BASELINE
	_foreground.z_index = Balance.BEAST_FOREGROUND_Z
	add_child(_foreground)

	# The region's trees on the ridge and its plants in the near ground: the
	# sidescroller's parallax, made of the battlefield's own art.
	_woods = ParallaxScatter.new()
	_woods.name = "Woods"
	_woods.band_width = Balance.BEAST_BACKDROP_HEIGHT * (16.0 / 9.0) * 1.2
	_woods.baseline = Balance.BEAST_WOODS_BASELINE
	_woods.count = Balance.BEAST_WOODS_COUNT
	_woods.scale_range = Balance.BEAST_WOODS_SCALE
	_woods.depth_jitter = 22.0
	_woods.z_index = Balance.BEAST_WOODS_Z
	_woods.filter_group = Graphics.FILTER_GROUP
	add_child(_woods)

	_brush = ParallaxScatter.new()
	_brush.name = "Brush"
	_brush.band_width = Balance.BEAST_BACKDROP_HEIGHT * (16.0 / 9.0) * 0.9
	_brush.baseline = Balance.BEAST_BRUSH_BASELINE
	_brush.count = Balance.BEAST_BRUSH_COUNT
	_brush.scale_range = Balance.BEAST_BRUSH_SCALE
	_brush.depth_jitter = 30.0
	_brush.z_index = Balance.BEAST_BRUSH_Z
	_brush.filter_group = Graphics.FILTER_GROUP
	add_child(_brush)


## Colours and reshapes the bands for the act that just began.
##
## The ridge is the ground's own light pulled most of the way toward the sky,
## which is what distance does to colour - a far hill is mostly the air in front
## of it. The near band is the same ground colour taken down to almost nothing,
## because something that close reads as an occluder rather than as terrain.
##
## Both are reseeded per act, so each region has its own skyline instead of the
## same hills in a different colour.
func _apply_parallax_palette() -> void:
	if _ridge == null or _foreground == null:
		return
	# The horizon's real colour, not the ground's tint. A far ridge is mostly the
	# air in front of it, so it is pulled toward the sky and then taken down -
	# hazed *and* darker than what it stands against, or it reads as fog rather
	# than as land.
	var horizon: Color = _horizon_colour()
	var hazed: Color = horizon.lerp(Color(horizon.r, horizon.g, horizon.b)
		.lightened(0.25), Balance.BEAST_RIDGE_HAZE)
	_ridge.colour = hazed.darkened(Balance.BEAST_RIDGE_SHADE)
	_ridge.colour.a = 1.0
	_ridge.shape_seed = hash(RunState.terrain_id + "ridge")
	_ridge.rebuild()

	# **The painted horizon for this region**, if one has been drawn. Hazed with
	# the same arithmetic the drawn bands use, so it sits inside the stack
	# rather than in front of it.
	if _skyline != null:
		var art: String = Balance.BEAST_SKYLINE_FORMAT % RunState.terrain_id
		_skyline.texture = load(art) as Texture2D if ResourceLoader.exists(art) 			else null
		var sky_haze: Color = horizon.lerp(Color(horizon.r, horizon.g, horizon.b)
			.lightened(0.24), Balance.BEAST_SKYLINE_HAZE)
		_skyline.tint = Color(sky_haze.darkened(Balance.BEAST_SKYLINE_SHADE), 1.0)

	# The two added distances, hazed and shaded from the same horizon: the far
	# range is mostly the air in front of it, the mid rise barely at all.
	if _range_band != null:
		var far_haze: Color = horizon.lerp(Color(horizon.r, horizon.g, horizon.b)
			.lightened(0.30), Balance.BEAST_RANGE_HAZE)
		_range_band.colour = far_haze.darkened(Balance.BEAST_RANGE_SHADE)
		_range_band.colour.a = 1.0
		_range_band.shape_seed = hash(RunState.terrain_id + "range")
		_range_band.rebuild()
	if _mid_band != null:
		var mid_haze: Color = horizon.lerp(Color(horizon.r, horizon.g, horizon.b)
			.lightened(0.18), Balance.BEAST_MID_HAZE)
		_mid_band.colour = mid_haze.darkened(Balance.BEAST_MID_SHADE)
		_mid_band.colour.a = 1.0
		_mid_band.shape_seed = hash(RunState.terrain_id + "mid")
		_mid_band.rebuild()

	_foreground.colour = Color(horizon.r, horizon.g, horizon.b, 1.0) 		.darkened(1.0 - Balance.BEAST_FOREGROUND_DARKEN)
	_foreground.shape_seed = hash(RunState.terrain_id + "near")
	_foreground.rebuild()
	_rebuild_scatter(horizon)


## Lays the woods and the brush from the region's own art, hazed and shaded
## to their depths, reseeded per region and per run.
func _rebuild_scatter(horizon: Color) -> void:
	if _woods == null or _brush == null:
		return
	var region: String = RunState.terrain_id
	var trees: Array[Texture2D] = []
	var base: String = Treeline.TREE_ART_FORMAT % region
	if ResourceLoader.exists(base):
		trees.append(load(base))
	for index: int in range(1, 9):
		var path: String = Treeline.TREE_VARIANT_FORMAT % [region, index]
		if ResourceLoader.exists(path):
			trees.append(load(path))
	if trees.is_empty():
		var fallback: String = Treeline.TREE_ART_FORMAT % "jungle"
		if ResourceLoader.exists(fallback):
			trees.append(load(fallback))
	# Trees sway like trees and brush like brush: the canopy material is slower
	# and reaches further, which is the difference `Foliage` already authors.
	_woods.sway_material = Foliage.canopy_material(region)
	_woods.tint = horizon.lightened(0.2)
	_woods.tint.a = 1.0
	_woods.tint_strength = Balance.BEAST_WOODS_HAZE
	_woods.shape_seed = hash(region + "woods") ^ RunState.run_seed
	_woods.rebuild(trees)

	var plants: Array[Texture2D] = []
	var own: String = Foliage.PLANT_ART_FORMAT % region
	if ResourceLoader.exists(own):
		plants.append(load(own))
	for kind: String in Foliage.REGIONAL_KINDS:
		var path: String = Foliage.REGIONAL_KIND_FORMAT % [region, kind]
		if ResourceLoader.exists(path):
			plants.append(load(path))
	for kind: String in ["rock", "boulder", "log", "stump"]:
		var path: String = Foliage.SHARED_KIND_FORMAT % kind
		if ResourceLoader.exists(path):
			plants.append(load(path))
	_brush.sway_material = Foliage.wind_material()
	_brush.tint = Color(horizon.r, horizon.g, horizon.b, 1.0).darkened(0.7)
	_brush.tint_strength = Balance.BEAST_BRUSH_DARKEN
	_brush.shape_seed = hash(region + "brush") ^ RunState.run_seed
	_brush.rebuild(plants)


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
	# The art decides how wide a period is, so a new sky is a new count of copies.
	_rebuild_backdrop_copies()
	# A new sky is new light and, past Act I, new ground under it.
	_refresh_ground()
	_apply_parallax_palette()
	_apply_beast_environment_tint()


## Slides the sky, and carries its mirrored copies with it.
func _scroll_backdrop() -> void:
	if backdrop == null or backdrop.texture == null:
		return
	var width: float = backdrop.texture.get_width() * backdrop.scale.x
	if width <= 0.0:
		return
	var offset: float = fmod(RunState.distance_travelled
		* Balance.BEAST_BACKDROP_SCROLL, width)
	backdrop.position.x = -offset
	for copy: Sprite2D in _backdrop_copies:
		var period: int = copy.get_meta(&"sky_period", 0) as int
		copy.position.x = -offset + float(period) * width
		copy.position.y = backdrop.position.y
	_scroll_ground()
	# Ordered slowest to fastest, which is the whole illusion: sky, ridge,
	# ground, then the band that overtakes the beast.
	if _ridge != null:
		_ridge.scroll_to(RunState.distance_travelled, Balance.BEAST_RIDGE_SCROLL)
	if _skyline != null:
		_skyline.scroll_to(RunState.distance_travelled, Balance.BEAST_SKYLINE_SCROLL)
	if _range_band != null:
		_range_band.scroll_to(RunState.distance_travelled, Balance.BEAST_RANGE_SCROLL)
	if _mid_band != null:
		_mid_band.scroll_to(RunState.distance_travelled, Balance.BEAST_MID_SCROLL)
	if _woods != null:
		_woods.scroll_to(RunState.distance_travelled, Balance.BEAST_WOODS_SCROLL)
	if _foreground != null:
		_foreground.scroll_to(RunState.distance_travelled,
			Balance.BEAST_FOREGROUND_SCROLL)
	if _brush != null:
		_brush.scroll_to(RunState.distance_travelled, Balance.BEAST_BRUSH_SCROLL)


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
	_update_town_light()
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
		_update_town_light()
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
	_update_town_light()

	_scroll_backdrop()

	_update_route()


func _lumbered_phase(raw_phase: float) -> float:
	var half_step: float = floor(raw_phase / PI)
	var progress: float = fmod(raw_phase, PI) / PI
	var eased: float = pow(clampf(progress, 0.0, 1.0), Balance.BEAST_GAIT_WINDUP_POWER)
	return (half_step + eased) * PI


## The camera's own movement: the footfall, and the earth under it.
##
## **A quake shakes Yuri as well** (owner, 2026-09-15). Moving only the camera
## reads as the operator flinching; the beast is the biggest thing on screen and
## it is standing on the ground that is moving, so it takes its own offset on
## top of its gait. The scale is the ground's magnitude and the player's own
## shake setting, exactly as the footfall is.
func _update_step_shake(delta: float, strength: float) -> void:
	if camera == null:
		return
	var quake: float = _omens.quake_shake() if _omens != null else 0.0
	var shaking: float = float(MetaState.settings.get(UserSettings.SHAKE_KEY, 1.0))
	if beast != null:
		var rock: float = quake * Balance.BEAST_QUAKE_SHAKE * shaking
		_quake_offset = Vector2(_rng.randf_range(-rock, rock),
			_rng.randf_range(-rock, rock)) if rock > 0.01 else Vector2.ZERO
		beast.position += _quake_offset
	if _step_shake_left <= 0.0 and quake <= 0.0:
		if camera.is_current():
			camera.offset = Vector2.ZERO
		return
	if quake > 0.0 and camera.is_current():
		var world: float = quake * Balance.BEAST_QUAKE_SHAKE * shaking
		camera.offset = Vector2(_rng.randf_range(-world, world),
			_rng.randf_range(-world, world))
	if _step_shake_left <= 0.0 or not camera.is_current():
		if quake <= 0.0:
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
	for copy: Sprite2D in _backdrop_copies:
		copy.modulate = tint


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
		# **An act boundary is where an act ends**, not where the distance divides
		# evenly. With every act the same length a modulo found them; with
		# `ACT_ROAD_DISTANCE` it finds none at all, and the walk would have drawn a
		# road of sixty-seven identical ticks and no acts in it.
		var is_act_boundary: bool = _is_act_end(t * Balance.JOURNEY_TOTAL_DISTANCE,
			Balance.SEGMENT_DISTANCE * 0.5)
		var height: float = 34.0 if is_act_boundary else 18.0
		tick.points = PackedVector2Array([Vector2(x, 220.0 - height), Vector2(x, 220.0 + height)])
		tick.width = 5.0 if is_act_boundary else 3.0
		tick.default_color = Color(0.91, 0.64, 0.24, 0.9) if is_act_boundary else Color(0.85, 0.80, 0.72, 0.6)
		route_line.add_child(tick)

	if route_marker != null:
		route_marker.visible = false


## True when this point on the road is where some act hands over to the next.
##
## Asked with the tick spacing as its tolerance, because a tick is drawn at a
## rounded position and an act ends at an authored one - so "close enough to be
## this tick" is the question, never "exactly equal".
func _is_act_end(distance: float, tolerance: float) -> bool:
	for act: int in range(1, Balance.ACT_COUNT):
		if absf(Balance.act_end_distance(act) - distance) <= tolerance:
			return true
	return false


func _update_route() -> void:
	if route_marker == null or not _zoomed_out:
		return
	route_marker.position = Vector2(lerpf(-820.0, 820.0, RunState.journey_ratio()), 220.0)


## Roots the tail on the current frame's own stub. See `BeastTail`.
func _place_tail() -> void:
	if _tail == null or beast == null or beast.texture == null:
		return
	var root: Vector2 = BeastTail.root_of(beast.texture)
	if root == Vector2.ZERO:
		_tail.position = Balance.BEAST_TAIL_ANCHOR
		return
	# **Well inside the edge, not a few pixels.** The tail is drawn behind the
	# body, so the further its root sits under the flank the less of a seam
	# there is to see; six pixels left a visible butt-joint that moved with
	# every frame, reported 2026-09-13. `BEAST_TAIL_OVERLAP` is how far in it
	# goes, and the sprite's own root end is feathered to meet it.
	_tail.position = root + Vector2(Balance.BEAST_TAIL_OVERLAP, -Balance.BEAST_TAIL_LIFT)


## The same weather the road is having, over the scope.
##
## **The two views used to disagree.** The battlefield had rain, dust and snow
## and the beast scope had none, so watching the beast walk through a downpour
## showed a clear evening - two windows on one world that did not agree about
## the weather in it.
##
## The battlefield's own `WeatherVeil`, not a copy of it: it listens to
## `EventBus.weather_changed` itself, so both views turn at the same moment and
## there is one place to tune a storm. Sized to this scope's band rather than to
## the battle grid, because the veil scales its cell count with its quad and a
## grid-sized one out here would drop raindrops the size of the beast.
func _build_weather() -> void:
	_weather = WeatherVeil.new()
	_weather.name = "WeatherVeil"
	_weather.reach = Balance.BEAST_WEATHER_REACH
	_weather.z_index = Balance.BEAST_WEATHER_Z
	add_child(_weather)
