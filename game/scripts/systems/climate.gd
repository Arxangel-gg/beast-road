class_name Climate
extends Node2D

## The ground's own weather: a coarse grid of cells over the field, each
## carrying how much warmer or colder it is than the sky and how wet it
## stands, fed by what fires and burns and floods on it, spreading to its
## neighbours, and read by everything that used to read one number for the
## whole road - the wildfire's dryness, the wells' evaporation, the lightning
## that lights dry brush.
##
## Owner brief, 2026-09-14, by way of the ChatGPT notes: "a coarse
## environmental simulation grid layered over the world ... event-driven and
## staggered ... cells far away from environmental activity effectively go to
## sleep ... clients receive chunk-level changes only when values cross
## meaningful thresholds ... never visually expose its square cell structure".
##
## **Layout.** A cell is `CLIMATE_CELL_TILES` tiles a side. Per cell:
##   heat  - degrees above (or below) the sky's ambient temperature
##   wet   - 0 dry .. 1 standing water
##   soil  - a byte for the ground's long memory (`Soil`), reserved: this
##           pass writes NORMAL everywhere, so lava, ice, mud, ash and the rest
##           plug in as values of a byte that already exists
##   awake - whether the cell is simulated this tick; a cell with nothing
##           happening to it costs nothing
## The bands (`TempBand`, `WetBand`) are derived, and are the only thing that
## crosses the wire: the host tells the guest when a cell crosses one, and
## the guest eases its own copy toward that band's figure.
##
## **Sources are additive with falloff.** `add_heat` and `add_wet` spread a
## source over the cells within a radius, most at the centre, so two fire
## towers side by side make a hotter spot than one, which is the whole reason
## to have cells rather than a number.
##
## **Nothing on screen or in play shows the square.** Every read is a
## bilinear sample across the four nearest cells, and the picture is one
## texel a cell drawn through a linear filter and broken up by noise in the
## shader.
##
## **Interactions live in `_tick`, one line each**, so the next one - wind on
## the fire, cold freezing the wet - is a line beside the ones that exist
## (heat dries the ground; rain and flood wet it) and not a second system.

enum TempBand { COLD, NORMAL, HOT, SCORCHING }
enum WetBand { DRY, NORMAL, WET, FLOODED }
## The ground's long memory. Reserved; only NORMAL is written this pass.
enum Soil { NORMAL, SCORCHED, WATERLOGGED, ASH, FROZEN, MUD, LAVA }

const FORMAT: Image.Format = Image.FORMAT_RGBA8

var field: Battlefield = null
## Half the side of the square the grid covers, in world units.
var half_extent: float = 0.0
## Whether the cells are drawn with their values, for tuning.
var debug_shown: bool = false

var _across: int = 0
var _cell: float = 0.0
var _heat: PackedFloat32Array = PackedFloat32Array()
var _wet: PackedFloat32Array = PackedFloat32Array()
var _soil: PackedByteArray = PackedByteArray()
var _awake: PackedByteArray = PackedByteArray()
var _temp_band: PackedByteArray = PackedByteArray()
var _wet_band: PackedByteArray = PackedByteArray()
## The guest's targets, one per cell, eased toward.
var _heat_target: PackedFloat32Array = PackedFloat32Array()
var _wet_target: PackedFloat32Array = PackedFloat32Array()
var _scratch: PackedFloat32Array = PackedFloat32Array()
var _timer: float = 0.0
var _mirror: bool = false
var _image: Image = null
var _texture: ImageTexture = null
var _overlay: Sprite2D = null
var _material: ShaderMaterial = null
var _picture_dirty: bool = true
var _wettest: float = 0.0
## For the gate.
var ticks: int = 0
var bands_told: int = 0


func _ready() -> void:
	name = "Climate"
	z_as_relative = false
	z_index = Balance.CLIMATE_Z
	_mirror = Coop.is_guest()
	_cell = float(Balance.CLIMATE_CELL_TILES) * BattleGrid.TILE
	if half_extent <= 0.0:
		half_extent = BattleGrid.HALF_EXTENT + Balance.TREELINE_RING
	_across = maxi(int(ceil(half_extent * 2.0 / _cell)), 2)
	var count: int = _across * _across
	_heat.resize(count)
	_heat.fill(0.0)
	_wet.resize(count)
	_wet.fill(Balance.CLIMATE_WET_REST)
	_soil.resize(count)
	_soil.fill(Soil.NORMAL)
	_awake.resize(count)
	_awake.fill(0)
	_temp_band.resize(count)
	_wet_band.resize(count)
	_heat_target = _heat.duplicate()
	_wet_target = _wet.duplicate()
	_scratch = _heat.duplicate()
	for index: int in count:
		_temp_band[index] = _band_of_temperature(RunState.temperature)
		_wet_band[index] = _band_of_wet(_wet[index])
	_build_picture()
	EventBus.coop_climate_band_changed.connect(_on_band_elsewhere)
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void: reset(Balance.CLIMATE_WET_REST))
	set_process_unhandled_input(true)


func _build_picture() -> void:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_across * _across * 4)
	bytes.fill(0)
	_image = Image.create_from_data(_across, _across, false, FORMAT, bytes)
	_texture = ImageTexture.create_from_image(_image)
	_overlay = Sprite2D.new()
	_overlay.name = "Overlay"
	_overlay.texture = _texture
	_overlay.centered = true
	# One texel a cell, stretched over the field and read bilinearly: the
	# picture never shows a square.
	_overlay.scale = Vector2.ONE * (half_extent * 2.0 / float(_across))
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if DisplayServer.get_name() != "headless":
		_material = ShaderMaterial.new()
		_material.shader = load("res://scripts/shaders/climate_overlay.gdshader")
		_material.set_shader_parameter("strength", Balance.CLIMATE_OVERLAY_ALPHA)
		_overlay.material = _material
	else:
		_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_overlay)
	_refresh_picture()


# --- Reading ------------------------------------------------------------------------

## The cell under a point, clamped to the grid.
func cell_of(at: Vector2) -> int:
	var column: int = clampi(int(floor((at.x + half_extent) / _cell)), 0, _across - 1)
	var row: int = clampi(int(floor((at.y + half_extent) / _cell)), 0, _across - 1)
	return row * _across + column


func cell_centre(index: int) -> Vector2:
	var column: int = index % _across
	var row: int = floori(float(index) / float(_across))
	return Vector2((float(column) + 0.5) * _cell - half_extent, (float(row) + 0.5) * _cell - half_extent)


func count() -> int:
	return _across * _across


func across() -> int:
	return _across


## A value read across the four nearest cells, so a walk from one cell to the
## next is a slope and never a step.
func _sample(values: PackedFloat32Array, at: Vector2) -> float:
	var fx: float = (at.x + half_extent) / _cell - 0.5
	var fy: float = (at.y + half_extent) / _cell - 0.5
	var x0: int = clampi(int(floor(fx)), 0, _across - 1)
	var y0: int = clampi(int(floor(fy)), 0, _across - 1)
	var x1: int = mini(x0 + 1, _across - 1)
	var y1: int = mini(y0 + 1, _across - 1)
	var tx: float = clampf(fx - float(x0), 0.0, 1.0)
	var ty: float = clampf(fy - float(y0), 0.0, 1.0)
	var top: float = lerpf(values[y0 * _across + x0], values[y0 * _across + x1], tx)
	var bottom: float = lerpf(values[y1 * _across + x0], values[y1 * _across + x1], tx)
	return lerpf(top, bottom, ty)


## Degrees above or below the sky at a point.
func heat_at(at: Vector2) -> float:
	return _sample(_heat, at)


## The temperature at a point: the sky's, plus the ground's own.
func temperature_at(at: Vector2) -> float:
	return RunState.temperature + heat_at(at)


func wetness_at(at: Vector2) -> float:
	return clampf(_sample(_wet, at), 0.0, 1.0)


## How readily the brush burns here, 0 soaked to 1 tinder: the wetness
## inverted, and the heat on top of it.
func dryness_at(at: Vector2) -> float:
	var dry: float = clampf(1.0 - wetness_at(at) * Balance.CLIMATE_WET_QUENCH, 0.0, 1.0)
	if temperature_at(at) > Balance.WILDFIRE_HOT_FROM:
		dry *= Balance.WILDFIRE_HOT_SPREAD
	return dry


## A well's evaporation at a point, by the local temperature.
func evaporation_at(at: Vector2) -> float:
	return maxf(temperature_at(at) - Balance.WELL_EVAPORATE_FROM, 0.0) * Balance.WELL_EVAPORATE_PER_DEGREE


func temp_band_at(at: Vector2) -> int:
	return _temp_band[cell_of(at)]


func wet_band_at(at: Vector2) -> int:
	return _wet_band[cell_of(at)]


func soil_at(at: Vector2) -> int:
	return _soil[cell_of(at)]


## The wettest cell on the field, for the water to know whether to draw.
func wettest() -> float:
	return _wettest


func awake_count() -> int:
	var total: int = 0
	for index: int in _awake.size():
		if _awake[index] != 0:
			total += 1
	return total


func texture() -> Texture2D:
	return _texture


# --- Sources ------------------------------------------------------------------------------

## Heat (or cold, negative) put into the ground at a point, spread over the
## cells within `radius`, most at the centre. Additive: a second source on
## the same ground stacks on the first.
func add_heat(at: Vector2, degrees: float, radius: float = Balance.CLIMATE_SOURCE_RADIUS) -> void:
	if _mirror:
		return
	_spread(_heat, at, degrees, radius)


## Water put into (or taken from, negative) the ground at a point.
func add_wet(at: Vector2, amount: float, radius: float = Balance.CLIMATE_SOURCE_RADIUS) -> void:
	if _mirror:
		return
	_spread(_wet, at, amount, radius)


func _spread(values: PackedFloat32Array, at: Vector2, amount: float, radius: float) -> void:
	var reach: int = int(ceil(radius / _cell))
	var centre: int = cell_of(at)
	var column: int = centre % _across
	var row: int = floori(float(centre) / float(_across))
	for dy: int in range(-reach, reach + 1):
		var y: int = row + dy
		if y < 0 or y >= _across:
			continue
		for dx: int in range(-reach, reach + 1):
			var x: int = column + dx
			if x < 0 or x >= _across:
				continue
			var index: int = y * _across + x
			var away: float = cell_centre(index).distance_to(at)
			var share: float = clampf(1.0 - away / maxf(radius, 1.0), 0.0, 1.0)
			if share <= 0.0:
				continue
			values[index] += amount * share
			_awake[index] = 1


## Everything back to rest: the act changed, or a gate wants dry ground.
func reset(wet: float = Balance.CLIMATE_WET_REST) -> void:
	_heat.fill(0.0)
	_wet.fill(wet)
	_heat_target.fill(0.0)
	_wet_target.fill(wet)
	_awake.fill(0)
	_soil.fill(Soil.NORMAL)
	for index: int in _temp_band.size():
		_temp_band[index] = _band_of_temperature(RunState.temperature)
		_wet_band[index] = _band_of_wet(wet)
	_picture_dirty = true


# --- The simulation --------------------------------------------------------------------

func _process_measured(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = Balance.CLIMATE_TICK
	if _mirror:
		_ease_toward_bands(Balance.CLIMATE_TICK)
	else:
		_tick(Balance.CLIMATE_TICK)
	if _picture_dirty:
		_refresh_picture()
	if debug_shown:
		queue_redraw()


## One step of the ground: the rain and the flood wet every cell, awake cells
## spread their heat to their neighbours and cool toward the sky, wet ground
## dries toward what the weather allows and faster where it is hot, and a
## cell with nothing left happening to it goes back to sleep.
func _tick(dt: float) -> void:
	ticks += 1
	var rain: float = clampf(RunState.rain_intensity, 0.0, 1.0)
	var flood: float = clampf(RunState.flood, 0.0, 1.0)
	var rest: float = maxf(Balance.CLIMATE_WET_REST, flood)
	var count: int = _heat.size()
	if rain > 0.0 or flood > 0.0:
		# Weather is everywhere: every cell is awake while it lasts.
		for index: int in count:
			_wet[index] = minf(_wet[index] + rain * Balance.CLIMATE_RAIN_WET_RATE * dt, 1.0)
			_wet[index] = maxf(_wet[index], flood)
			_awake[index] = 1
	_scratch = _heat.duplicate()
	var wettest: float = 0.0
	for index: int in count:
		if _awake[index] == 0:
			wettest = maxf(wettest, _wet[index])
			continue
		var column: int = index % _across
		var row: int = floori(float(index) / float(_across))
		# Heat spreads to the four neighbours and cools toward the sky.
		var around: float = 0.0
		var neighbours: int = 0
		if column > 0:
			around += _scratch[index - 1]
			neighbours += 1
		if column < _across - 1:
			around += _scratch[index + 1]
			neighbours += 1
		if row > 0:
			around += _scratch[index - _across]
			neighbours += 1
		if row < _across - 1:
			around += _scratch[index + _across]
			neighbours += 1
		var heat: float = _scratch[index]
		if neighbours > 0:
			heat += (around / float(neighbours) - heat) * Balance.CLIMATE_DIFFUSION * dt / Balance.CLIMATE_TICK
		heat *= exp(-dt / maxf(Balance.CLIMATE_HEAT_TAU, 1.0))
		# Wet ground dries toward what the weather allows, and faster where
		# it is hot: the one interaction this pass ships, in one line.
		var wet: float = _wet[index]
		wet += (rest - wet) * minf(dt / maxf(Balance.CLIMATE_WET_TAU, 1.0), 1.0)
		wet -= maxf(heat, 0.0) * Balance.CLIMATE_DRY_PER_DEGREE * dt
		wet = clampf(wet, 0.0, 1.0)
		_heat[index] = heat
		_wet[index] = wet
		wettest = maxf(wettest, wet)
		if absf(heat) < Balance.CLIMATE_SLEEP_HEAT and absf(wet - rest) < Balance.CLIMATE_SLEEP_WET \
				and rain <= 0.0 and flood <= 0.0:
			_heat[index] = 0.0
			_wet[index] = rest
			_awake[index] = 0
		_note_bands(index)
	_wettest = wettest
	# The picture follows the figures, not only the bands: a cell warming
	# toward HOT is drawn warming.
	if awake_count() > 0:
		_picture_dirty = true
	# The neighbours of a hot cell wake to receive its heat.
	for index: int in count:
		if _awake[index] == 0 or absf(_heat[index]) < Balance.CLIMATE_SLEEP_HEAT * 4.0:
			continue
		var column: int = index % _across
		var row: int = floori(float(index) / float(_across))
		if column > 0:
			_awake[index - 1] = 1
		if column < _across - 1:
			_awake[index + 1] = 1
		if row > 0:
			_awake[index - _across] = 1
		if row < _across - 1:
			_awake[index + _across] = 1


## A cell's bands, and the guest told when one crosses.
func _note_bands(index: int) -> void:
	var temp_band: int = _band_of_temperature(RunState.temperature + _heat[index])
	var wet_band: int = _band_of_wet(_wet[index])
	if temp_band == _temp_band[index] and wet_band == _wet_band[index]:
		return
	_temp_band[index] = temp_band
	_wet_band[index] = wet_band
	_picture_dirty = true
	bands_told += 1
	EventBus.climate_band_changed.emit(index, temp_band, wet_band)


static func _band_of_temperature(degrees: float) -> int:
	var edges: Array = Balance.CLIMATE_TEMP_BANDS
	if degrees < float(edges[0]):
		return TempBand.COLD
	if degrees >= float(edges[2]):
		return TempBand.SCORCHING
	if degrees >= float(edges[1]):
		return TempBand.HOT
	return TempBand.NORMAL


static func _band_of_wet(wet: float) -> int:
	var edges: Array = Balance.CLIMATE_WET_BANDS
	if wet < float(edges[0]):
		return WetBand.DRY
	if wet >= float(edges[2]):
		return WetBand.FLOODED
	if wet >= float(edges[1]):
		return WetBand.WET
	return WetBand.NORMAL


## The guest hears a cell crossed a band and aims its own copy at that
## band's figure; `_ease_toward_bands` walks it there, so nothing snaps.
func _on_band_elsewhere(index: int, temp_band: int, wet_band: int) -> void:
	if not _mirror or index < 0 or index >= _heat.size():
		return
	_temp_band[index] = clampi(temp_band, 0, TempBand.SCORCHING)
	_wet_band[index] = clampi(wet_band, 0, WetBand.FLOODED)
	_heat_target[index] = float(Balance.CLIMATE_BAND_HEAT[_temp_band[index]])
	_wet_target[index] = float(Balance.CLIMATE_BAND_WET[_wet_band[index]])
	_awake[index] = 1
	_picture_dirty = true


func _ease_toward_bands(dt: float) -> void:
	var step: float = minf(dt * Balance.CLIMATE_EASE, 1.0)
	var wettest: float = 0.0
	for index: int in _heat.size():
		if _awake[index] == 0:
			continue
		_heat[index] = lerpf(_heat[index], _heat_target[index], step)
		_wet[index] = lerpf(_wet[index], _wet_target[index], step)
		wettest = maxf(wettest, _wet[index])
		if absf(_heat[index] - _heat_target[index]) < 0.05 and absf(_wet[index] - _wet_target[index]) < 0.005:
			_awake[index] = 0
	_wettest = wettest
	_picture_dirty = true


# --- The picture ----------------------------------------------------------------------------

## One texel a cell: R the heat about the middle, G the wet, B the soil.
func _refresh_picture() -> void:
	if _image == null:
		return
	_picture_dirty = false
	for index: int in _heat.size():
		var column: int = index % _across
		var row: int = floori(float(index) / float(_across))
		var r: float = clampf(0.5 + _heat[index] / Balance.CLIMATE_PICTURE_DEGREES, 0.0, 1.0)
		_image.set_pixel(column, row, Color(r, clampf(_wet[index], 0.0, 1.0),
			float(_soil[index]) / 255.0, 1.0))
	_texture.update(_image)


# --- Tuning ------------------------------------------------------------------------------------

func toggle_debug() -> void:
	debug_shown = not debug_shown
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_climate_debug"):
		toggle_debug()
		get_viewport().set_input_as_handled()


## The cells as they are, for tuning: each one's band colours, its figures,
## and whether it is awake. Drawn only while the toggle is on.
func _draw() -> void:
	if not debug_shown:
		return
	var font: Font = ThemeDB.fallback_font
	for index: int in _heat.size():
		var centre: Vector2 = cell_centre(index)
		var rect := Rect2(centre - Vector2.ONE * _cell * 0.5, Vector2.ONE * _cell)
		var temp_band: int = _temp_band[index]
		var wet_band: int = _wet_band[index]
		var fill: Color = Color(0.2, 0.2, 0.2, 0.08)
		if temp_band == TempBand.HOT:
			fill = Color(1.0, 0.5, 0.2, 0.18)
		elif temp_band == TempBand.SCORCHING:
			fill = Color(1.0, 0.2, 0.1, 0.28)
		elif temp_band == TempBand.COLD:
			fill = Color(0.5, 0.7, 1.0, 0.18)
		draw_rect(rect, fill, true)
		if wet_band >= WetBand.WET:
			draw_rect(rect.grow(-6.0), Color(0.2, 0.5, 1.0, 0.12 * float(wet_band)), true)
		var edge: Color = Color(1.0, 1.0, 1.0, 0.5) if _awake[index] != 0 else Color(1.0, 1.0, 1.0, 0.12)
		draw_rect(rect, edge, false, 2.0 if _awake[index] != 0 else 1.0)
		var line: String = "%+.1f  w%.2f" % [_heat[index], _wet[index]]
		draw_string(font, centre + Vector2(-_cell * 0.42, -6.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			Color(1.0, 1.0, 1.0, 0.9))
		draw_string(font, centre + Vector2(-_cell * 0.42, 22.0), "%s %s%s" % [
			TempBand.keys()[temp_band], WetBand.keys()[wet_band], " *" if _awake[index] != 0 else ""],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.9, 0.6, 0.8))


## `FrameProfile` bucket "climate": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"climate", started)
