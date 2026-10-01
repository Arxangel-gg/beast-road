extends Node2D

## Photographs the body light's roughness (2026-10-01): one painting twice
## under the same torch in the dark, matte on the left and with the gloss the
## game ships on the right. Steel and pale stone should catch the light; cloth,
## leather and moss should not.
##
##   godot --path game res://tools/gloss_shot.tscn -- --art=res://art/towers/tower_bastion.png
##
## Windowed, because a headless display has no pixels. Diagnostic only.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[gloss-shot] skipped: a headless display has no pixels to read")
		get_tree().quit(0)
		return
	var art: String = "res://art/towers/tower_bastion.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--art="):
			art = arg.substr(6)
	var dark := CanvasModulate.new()
	dark.color = Color(0.22, 0.22, 0.26)
	add_child(dark)
	var view: Vector2 = get_viewport_rect().size
	var shader: Shader = load("res://scripts/shaders/actor_polish.gdshader") as Shader
	for index: int in 2:
		var sprite := Sprite2D.new()
		sprite.texture = load(art) as Texture2D
		sprite.scale = Vector2.ONE * 2.2
		sprite.position = Vector2(view.x * (0.3 + 0.4 * float(index)), view.y * 0.5)
		var made := ShaderMaterial.new()
		made.shader = shader
		made.set_shader_parameter("shade_strength", 1.0)
		made.set_shader_parameter("shade_gloss", 0.0 if index == 0 else Balance.ACTOR_SHADE_GLOSS)
		sprite.material = made
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		var torch := PointLight2D.new()
		torch.texture = load("res://art/vfx/light_soft.png") as Texture2D if ResourceLoader.exists("res://art/vfx/light_soft.png") else _soft()
		torch.texture_scale = 3.0
		torch.energy = 1.6
		torch.color = Color(1.0, 0.75, 0.45)
		torch.position = sprite.position + Vector2(-170.0, -60.0)
		add_child(torch)
	for _frame: int in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://gloss_shot.png")
	print("[gloss-shot] -> ", ProjectSettings.globalize_path("user://gloss_shot.png"))
	get_tree().quit(0)


func _soft() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var made := GradientTexture2D.new()
	made.gradient = gradient
	made.fill = GradientTexture2D.FILL_RADIAL
	made.fill_from = Vector2(0.5, 0.5)
	made.fill_to = Vector2(1.0, 0.5)
	made.width = 256
	made.height = 256
	return made
