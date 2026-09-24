extends SceneTree

## Does the renderer this game ships on give the screen texture mipmaps? A
## windowed diagnostic: a small white square on black, read back through a
## full-screen pass at a coarse mip. A blurred square means a mip-chain bloom is
## available; a sharp one means it is not and a bloom has to sample by hand.
##
##   godot --path game --script res://tools/bloom_probe.gd -- --save=<png>

const SHADER: String = """
shader_type canvas_item;
render_mode blend_disabled, unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 0.0;
void fragment() {
	COLOR = vec4(textureLod(screen_tex, SCREEN_UV, lod).rgb, 1.0);
}
"""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var view: Rect2 = root.get_visible_rect()
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.size = view.size
	root.add_child(back)
	var spot := ColorRect.new()
	spot.color = Color.WHITE
	spot.size = Vector2(24.0, 24.0)
	spot.position = view.get_center() - spot.size * 0.5
	root.add_child(spot)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var pass_rect := ColorRect.new()
	pass_rect.size = view.size
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	pass_rect.material = material
	layer.add_child(pass_rect)
	for lod: float in [0.0, 3.0, 5.0]:
		material.set_shader_parameter("lod", lod)
		for i: int in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var ratio: float = float(image.get_width()) / view.size.x
		var centre := Vector2i(view.get_center() * ratio)
		var at_centre: float = image.get_pixelv(centre).get_luminance()
		var outside: float = image.get_pixelv(centre + Vector2i(int(40.0 * ratio), 0)).get_luminance()
		print("[bloom] lod %.0f: centre %.3f, 40px out %.3f" % [lod, at_centre, outside])
	quit(0)
