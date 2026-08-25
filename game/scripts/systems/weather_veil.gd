class_name WeatherVeil
extends Node2D

## Rain, snow and blowing dust over the battlefield.
##
## The weather has existed as data since it was written — a tint, an element
## multiplier and a line in the HUD — and has never been *visible*. Act I is
## described as rain-heavy and Act III as a place where "weather suppresses
## visibility" (GDD §177, §193), which is difficult to believe from a label.
##
## **A shader, not particles**, and that is the whole performance story. This
## covers the entire field, so a particle system would need thousands of them to
## look like weather and would cost per-particle CPU work every frame — on the
## GL Compatibility renderer this project ships, and in a browser tab. A fragment
## shader draws the same thing at a cost that depends on screen area rather than
## on density, so "heavier rain" is free. `menu_stage.gd` chooses CPUParticles2D
## for its embers for the opposite and equally good reason: a handful of sparks
## is free on the CPU and the GPU path is one more thing to be wrong on a driver.
##
## Everything is one grid of cells hashed per cell, which is the standard trick:
## each cell owns one drop, so there is no list, no allocation and no sorting,
## and the pattern never repeats visibly because the hash does not.

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

// 0 = clear, 1 = as heavy as this weather gets. Everything scales off it, so a
// weather change is a tween on one number rather than a rebuild.
uniform float amount : hint_range(0.0, 1.0) = 0.0;

// 0 draws falling streaks (rain), 1 draws drifting flakes (snow). Between the
// two is sleet, which is free and occasionally what a region wants.
uniform float flake : hint_range(0.0, 1.0) = 0.0;

// Sideways drift, in UV per second. Negative blows the other way.
uniform float wind = 0.10;

// Downward speed. Snow wants a fraction of rain's.
uniform float fall_speed = 1.5;

// Ground impact rings. Rain has them, snow does not - snow settles.
uniform float impact : hint_range(0.0, 1.0) = 0.0;

uniform vec4 tint : source_color = vec4(0.78, 0.85, 0.96, 1.0);

// The quad's aspect, so drops are not stretched into diagonals on a wide view.
uniform float aspect = 1.777;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One layer of precipitation. `depth` makes near layers bigger and faster, which
// is the only thing separating rain from a moving texture.
float layer(vec2 uv, float depth, float t) {
	float scale = mix(26.0, 13.0, depth);
	vec2 p = uv * scale;
	// Wind and fall are applied in cell space so they stay consistent whatever
	// the scale of the layer.
	p.x += wind * t * scale * mix(0.7, 1.4, depth);
	p.y += fall_speed * t * scale * mix(0.35, 1.0, depth) * 0.12;

	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);

	// Thinning: cells above the threshold are simply empty. This is what makes
	// `amount` mean density rather than opacity - fading opacity alone reads as
	// fog, not as lighter rain.
	if (h > amount * 0.85) {
		return 0.0;
	}

	// Where in its cell this drop sits. Two hashes so x and y are independent.
	vec2 at = vec2(hash(cell + 17.3), hash(cell + 41.7));
	vec2 d = f - at;

	// Rain is a vertical streak; snow is a round dot. Squashing y is what makes
	// the streak, so mixing the squash between the two gives sleet for free.
	float squash = mix(0.16, 1.0, flake);
	d.y *= squash;
	float radius = mix(0.035, 0.075, flake) * mix(0.7, 1.3, depth);
	float drop = 1.0 - smoothstep(0.0, radius, length(d));
	return drop;
}

// Expanding rings where rain lands. A separate, slower grid: impacts are sparse
// and short, and reusing the fall grid would put a ring under every drop, which
// is not what water does.
float ripples(vec2 uv, float t) {
	// 34 cells across the quad, not 9. The quad spans the whole field, so a
	// nine-cell grid put each ring in a 380-unit cell and let it grow to 160 -
	// dinner-plate ripples about a third the height of the town. Rain lands in
	// small rings; the grid has to be fine enough that a cell is roughly a
	// puddle.
	vec2 p = uv * 34.0;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell + 91.7);
	if (h > amount * 0.5) {
		return 0.0;
	}
	// Each cell's ring runs on its own offset phase, so they do not pulse in
	// unison - the single most obvious way a procedural effect gives itself away.
	float phase = fract(t * 1.6 + h * 7.0);
	vec2 at = vec2(hash(cell + 5.1), hash(cell + 8.3));
	float r = phase * 0.34;
	float ring = 1.0 - smoothstep(0.0, 0.10, abs(length(f - at) - r));
	// Fades as it grows, so a ring dies out instead of vanishing mid-stride.
	return ring * (1.0 - phase);
}

void fragment() {
	if (amount <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 uv = UV;
		uv.x *= aspect;
		float t = TIME;

		float fall = 0.0;
		// Three layers. Two reads as flat, four costs more than it shows.
		fall += layer(uv, 0.0, t) * 0.55;
		fall += layer(uv + vec2(3.7, 1.3), 0.5, t) * 0.75;
		fall += layer(uv + vec2(8.1, 5.9), 1.0, t) * 1.0;

		float land = ripples(uv, t) * impact * (1.0 - flake);

		// Impacts contribute less than the fall does. They are the detail that
		// says the rain is hitting something, not the subject.
		float a = clamp(fall + land * 0.45, 0.0, 1.0) * tint.a * amount;
		COLOR = vec4(tint.rgb, a);
	}
}
"""

var _rect: ColorRect = null
var _material: ShaderMaterial = null

## Eased toward its target rather than snapped, so weather arrives and leaves
## instead of appearing. A downpour that switches on between two frames reads as
## a bug in the renderer.
var _amount: float = 0.0
var _wanted: float = 0.0

## How much snow is lying on the ground, 0..1.
##
## Rises while settling weather falls and drains slowly afterwards, so a field
## stays white long after the storm has gone. That asymmetry is the point: snow
## that vanished with the clouds would be an overlay tied to a switch rather than
## a thing that happened.
##
## Announced rather than applied. This system has no business reaching into the
## ground sprite or the foliage - working rule 5 - so it emits and the scopes that
## own those decide what white means to them.
var _cover: float = 0.0
var _settling: bool = false


func _ready() -> void:
	z_as_relative = false
	var extent: float = BattleGrid.HALF_EXTENT * 1.2
	_rect = ColorRect.new()
	_rect.name = "Veil"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size = Vector2(extent * 2.0, extent * 2.0)
	_rect.position = -Vector2(extent, extent)

	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_material.set_shader_parameter("aspect", 1.0)
	_rect.material = _material
	add_child(_rect)

	EventBus.weather_changed.connect(_on_weather_changed)
	_apply(ContentDB.weather(RunState.weather_id))


func _process(delta: float) -> void:
	if not is_equal_approx(_amount, _wanted):
		_amount = move_toward(_amount, _wanted,
			delta / maxf(Balance.WEATHER_FADE_SECONDS, 0.01))
		_material.set_shader_parameter("amount", _amount)
	_tick_cover(delta)


## Snow gathering, and later going.
##
## Settling is scaled by how hard it is actually falling, so a light flurry
## whitens the ground slowly and a blizzard does it fast, from one constant.
func _tick_cover(delta: float) -> void:
	var before: float = _cover
	if _settling and _amount > 0.01:
		_cover = minf(_cover + delta * _amount
			/ maxf(Balance.SNOW_SETTLE_SECONDS, 0.01), 1.0)
	else:
		_cover = maxf(_cover - delta
			/ maxf(Balance.SNOW_MELT_SECONDS, 0.01), 0.0)
	if not is_equal_approx(before, _cover):
		EventBus.snow_cover_changed.emit(_cover)


func _on_weather_changed(weather_id: String) -> void:
	_apply(ContentDB.weather(weather_id))


## Reads one weather's authored numbers into the shader.
##
## Every value comes from the `.tres` - working rule 3. A weather that wants to
## be heavier, colder or windier is an edited resource, never a branch here.
func _apply(weather: WeatherData) -> void:
	if _material == null:
		return
	if weather == null:
		_wanted = 0.0
		return
	_wanted = clampf(weather.precipitation_density, 0.0, 1.0)
	_settling = weather.settles
	# Dust drifts as motes, not as streaks. Only rain falls fast enough in a
	# straight enough line to read as a line.
	var rounded: bool = weather.precipitation == WeatherData.Precipitation.SNOW 		or weather.precipitation == WeatherData.Precipitation.DUST
	_material.set_shader_parameter("flake", 1.0 if rounded else 0.0)
	_material.set_shader_parameter("wind", weather.precipitation_wind)
	_material.set_shader_parameter("fall_speed", weather.precipitation_speed)
	_material.set_shader_parameter("impact",
		1.0 if weather.precipitation == WeatherData.Precipitation.RAIN else 0.0)
	_material.set_shader_parameter("tint", weather.precipitation_tint)
	if weather.precipitation == WeatherData.Precipitation.NONE:
		_wanted = 0.0


## How heavy the precipitation currently reads, 0..1. For the systems that have
## to answer to it — snow settling, the readability gate.
func intensity() -> float:
	return _amount


## How much snow is lying, 0..1.
func cover() -> float:
	return _cover


## Sets how much snow is lying, and tells everything that draws it.
##
## The counterpart to `cover()`, and the only way to move it from outside. Its
## absence was felt immediately: the weather screenshot tool emitted the signal
## by hand and `_tick_cover` overwrote it on the very next frame with its own
## near-zero figure, so the tool reported snow and the picture showed bare ground.
## Anything that has to restore cover - a tool, a scope re-entry, a save - needs
## to move the value this system owns rather than shout past it.
func set_cover(value: float) -> void:
	_cover = clampf(value, 0.0, 1.0)
	EventBus.snow_cover_changed.emit(_cover)
