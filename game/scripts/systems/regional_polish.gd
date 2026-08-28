class_name RegionalPolish
extends CanvasLayer

## One quality-gated screen pass combines regional grade, edge atmosphere and
## heat shimmer. Combining them is the budget: High pays one screen sample, not
## three, and Low/Medium hide the pass outright.

var field: CanvasItem = null
var _material: ShaderMaterial = null
var _rect: ColorRect = null

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 grade_tint : source_color = vec3(1.0);
uniform vec3 edge_tint : source_color = vec3(0.08, 0.12, 0.14);
uniform float grade_strength = 0.0;
uniform float vignette = 0.0;
uniform float edge_atmosphere = 0.0;
uniform float heat_strength = 0.0;
uniform float heat_speed = 0.42;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 centred = SCREEN_UV - vec2(0.5);
	float heat_mask = smoothstep(0.62, 0.05, length(centred));
	float wave = sin(SCREEN_UV.y * 210.0 + TIME * heat_speed * 13.0)
		+ sin(SCREEN_UV.y * 73.0 - TIME * heat_speed * 7.0);
	vec2 warped = SCREEN_UV + vec2(wave * heat_strength * heat_mask, 0.0);
	vec4 scene = texture(screen_texture, warped);
	vec3 graded = mix(scene.rgb, scene.rgb * grade_tint, grade_strength);
	float edge = smoothstep(0.28, 0.72, length(centred * vec2(1.0, 0.86)));
	graded = mix(graded, edge_tint, edge * edge_atmosphere);
	graded *= 1.0 - edge * vignette;
	COLOR = vec4(graded, scene.a);
}
"""


func _ready() -> void:
	layer = 2
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material.shader = shader
	_rect.material = _material
	add_child(_rect)
	EventBus.weather_changed.connect(func(_id: String) -> void: refresh())
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void: refresh())
	refresh()


func _process(_delta: float) -> void:
	visible = field != null and field.is_visible_in_tree() \
		and Graphics.regional_post_processing()


func refresh() -> void:
	if _material == null:
		return
	var scale: float = Graphics.regional_post_scale()
	var tint: Color = Color("dce8df")
	var edge: Color = Color("122126")
	match RunState.terrain_id:
		"desert":
			tint = Color("f2d7b0")
			edge = Color("593827")
		"snow":
			tint = Color("dcecff")
			edge = Color("26364a")
	_material.set_shader_parameter("grade_tint", Vector3(tint.r, tint.g, tint.b))
	_material.set_shader_parameter("edge_tint", Vector3(edge.r, edge.g, edge.b))
	_material.set_shader_parameter("grade_strength", Balance.REGION_GRADE_STRENGTH * scale)
	_material.set_shader_parameter("vignette", Balance.REGION_GRADE_VIGNETTE * scale)
	_material.set_shader_parameter("edge_atmosphere",
		Balance.REGION_EDGE_ATMOSPHERE * scale)
	var heat: bool = RunState.terrain_id == "desert" and RunState.weather_id == "heatwave"
	_material.set_shader_parameter("heat_strength",
		Balance.DESERT_HEAT_DISTORTION * scale if heat else 0.0)
	_material.set_shader_parameter("heat_speed", Balance.DESERT_HEAT_SPEED)
