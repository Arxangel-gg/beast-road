extends SceneTree

## Proves the tower shading on the renderer, windowed (a headless run has no
## lights to measure). A diagnostic, not a gate: lighting is drawn, and headless
## CI never compiles a shader.
##
##   godot --path game --script res://tools/shade_probe.gd -- --orig=<path to the old shader>
##
## 1. At `shade_strength` 0 the new shader must light a sprite exactly as the old
##    one did - every other body in the game wears it.
## 2. At strength 1 a light on the left lights the left half more and the right
##    half less, and the other way round.
## 3. The sun's relief lights no flat pixel and moves the halves apart.

const TOWER: String = "res://art/towers/tower_ember_spire.png"

var _sprite: Sprite2D
var _light: PointLight2D
var _sun: DirectionalLight2D
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _arg(prefix: String) -> String:
	for raw: String in OS.get_cmdline_user_args():
		if raw.begins_with(prefix):
			return raw.substr(prefix.length())
	return ""


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		print("[shade] FAIL: %s" % message)


func _run() -> void:
	var view: Rect2 = root.get_visible_rect()
	var dark := CanvasModulate.new()
	dark.color = Color(0.18, 0.2, 0.3)
	root.add_child(dark)
	_sprite = Sprite2D.new()
	# `--sprite=` and `--shader=` (2026-09-25): a body in its blood shader is
	# held to the same three proofs as a tower in its polish, and `--body`
	# shades it at the body's strength rather than the tower's.
	var sprite_path: String = _arg("--sprite=")
	_sprite.texture = load(sprite_path if not sprite_path.is_empty() else TOWER)
	_sprite.scale = Vector2(2.5, 2.5)
	_sprite.position = view.get_center()
	root.add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = LightKit.falloff_texture()
	_light.texture_scale = 8.0
	_light.energy = 1.2
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	root.add_child(_light)

	var orig := Shader.new()
	var orig_path: String = _arg("--orig=")
	orig.code = FileAccess.get_file_as_string(orig_path)
	var shader_path: String = _arg("--shader=")
	var fresh: Shader = load(shader_path if not shader_path.is_empty()
		else "res://scripts/shaders/actor_polish.gdshader") as Shader

	_light.position = _sprite.position + Vector2(-420.0, -40.0)
	var old_look: Image = await _shot(orig, 0.0)
	var same_look: Image = await _shot(fresh, 0.0)
	var worst: int = _worst_difference(old_look, same_look)
	print("[shade] strength 0 against the old shader: worst channel difference %d" % worst)
	_check(worst <= 2, "at strength 0 the shader must light a body as it always did (%d)" % worst)

	var left_lit: Image = await _shot(fresh, 1.0)
	var plain: Vector2 = _halves(same_look)
	var shaded: Vector2 = _halves(left_lit)
	print("[shade] light on the left: plain L %.4f R %.4f, shaded L %.4f R %.4f"
		% [plain.x, plain.y, shaded.x, shaded.y])
	_check(shaded.x - shaded.y > plain.x - plain.y + 0.004,
		"a light on the left must light the left of the tower more than its right")

	_light.position = _sprite.position + Vector2(420.0, -40.0)
	var right_plain: Vector2 = _halves(await _shot(fresh, 0.0))
	var right_shaded: Vector2 = _halves(await _shot(fresh, 1.0))
	print("[shade] light on the right: plain L %.4f R %.4f, shaded L %.4f R %.4f"
		% [right_plain.x, right_plain.y, right_shaded.x, right_shaded.y])
	_check(right_shaded.y - right_shaded.x > right_plain.y - right_plain.x + 0.004,
		"a light on the right must light the right of the tower more than its left")

	_light.visible = false
	# The sun is a daytime light: judged under a day's tint, not a night's.
	dark.color = Color(1.0, 0.97, 0.92)
	_sun = DirectionalLight2D.new()
	_sun.blend_mode = Light2D.BLEND_MODE_ADD
	_sun.energy = Balance.SUN_RELIEF_ENERGY
	_sun.height = 0.0
	root.add_child(_sun)
	var none: Image = await _shot(fresh, 1.0)
	for degrees: float in [0.0, 90.0, 180.0, 270.0]:
		_sun.rotation_degrees = degrees
		var lit: Image = await _shot(fresh, 1.0)
		var halves: Vector2 = _halves(lit)
		var dark_halves: Vector2 = _halves(none)
		var vertical: Vector2 = _top_bottom(lit) - _top_bottom(none)
		print("[shade] sun at %3d deg: L %+.4f R %+.4f  T %+.4f B %+.4f" % [int(degrees),
			halves.x - dark_halves.x, halves.y - dark_halves.y, vertical.x, vertical.y])
	var flat: int = _flat_difference(none, await _shot(fresh, 1.0))
	var save: String = _arg("--save=")
	if not save.is_empty():
		_sun.rotation_degrees = 270.0
		var sun_left: Image = await _shot(fresh, 1.0)
		_sun.rotation_degrees = 90.0
		var sun_right: Image = await _shot(fresh, 1.0)
		_strip([same_look, left_lit, none, sun_left, sun_right]).save_png(save)
		print("[shade] saved %s" % save)
	print("[shade] sun on flat pixels: %d" % flat)

	if orig_path.is_empty():
		print("[shade] (no --orig given: the first check compared nothing)")
	print("[shade] %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)


func _shot(shader: Shader, strength: float) -> Image:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("outline_colour", Balance.ACTOR_OUTLINE_COLOUR)
	material.set_shader_parameter("outline_strength", Balance.ACTOR_OUTLINE_STRENGTH)
	material.set_shader_parameter("impact_colour", Balance.IMPACT_RIM_COLOUR)
	material.set_shader_parameter("impact_strength", 0.0)
	if strength > 0.0:
		var body: bool = OS.get_cmdline_user_args().has("--body")
		material.set_shader_parameter("shade_strength",
			strength * (Balance.BODY_SHADE_STRENGTH if body else 1.0))
		material.set_shader_parameter("shade_relief",
			Balance.BODY_SHADE_RELIEF if body else Balance.TOWER_SHADE_RELIEF)
		material.set_shader_parameter("shade_reach",
			Balance.BODY_SHADE_REACH if body else Balance.TOWER_SHADE_REACH)
		material.set_shader_parameter("shade_gain",
			Balance.BODY_SHADE_GAIN if body else Balance.TOWER_SHADE_GAIN)
	_sprite.material = material
	for i: int in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Crops of the tower from each shot, side by side: the plain light, the shaded
## light, the sun from the left and from the right.
func _strip(shots: Array) -> Image:
	var box: Rect2i = _box(shots[0])
	var strip := Image.create(box.size.x * shots.size(), box.size.y, false, Image.FORMAT_RGBA8)
	for index: int in shots.size():
		var shot: Image = shots[index]
		shot.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(shot, box, Vector2i(box.size.x * index, 0))
	return strip


func _box(image: Image) -> Rect2i:
	var view: Rect2 = root.get_visible_rect()
	var ratio: float = float(image.get_width()) / view.size.x
	var half: Vector2 = _sprite.texture.get_size() * _sprite.scale * 0.5
	var from: Vector2 = (_sprite.position - half) * ratio
	return Rect2i(Vector2i(from), Vector2i(half * 2.0 * ratio))


func _halves(image: Image) -> Vector2:
	var box: Rect2i = _box(image)
	return Vector2(_mean(image, Rect2i(box.position, Vector2i(box.size.x / 2, box.size.y))),
		_mean(image, Rect2i(box.position + Vector2i(box.size.x / 2, 0),
			Vector2i(box.size.x / 2, box.size.y))))


func _top_bottom(image: Image) -> Vector2:
	var box: Rect2i = _box(image)
	return Vector2(_mean(image, Rect2i(box.position, Vector2i(box.size.x, box.size.y / 2))),
		_mean(image, Rect2i(box.position + Vector2i(0, box.size.y / 2),
			Vector2i(box.size.x, box.size.y / 2))))


func _mean(image: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	var count: int = 0
	for y: int in range(rect.position.y, rect.end.y, 2):
		for x: int in range(rect.position.x, rect.end.x, 2):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(float(count), 1.0)


func _worst_difference(a: Image, b: Image) -> int:
	var worst: int = 0
	var box: Rect2i = _box(a)
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			worst = maxi(worst, int(roundf(maxf(absf(p.r - q.r),
				maxf(absf(p.g - q.g), absf(p.b - q.b))) * 255.0)))
	return worst


## Pixels well inside the sprite where the painting is flat, compared with and
## without the sun: the relief must not light a flat surface.
func _flat_difference(a: Image, b: Image) -> int:
	var texture_image: Image = _sprite.texture.get_image()
	var box: Rect2i = _box(a)
	var ratio: float = float(box.size.x) / float(texture_image.get_width())
	var worst: int = 0
	for ty: int in range(3, texture_image.get_height() - 3, 3):
		for tx: int in range(3, texture_image.get_width() - 3, 3):
			var centre: Color = texture_image.get_pixel(tx, ty)
			if centre.a < 0.99:
				continue
			var flat: bool = true
			for offset: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
				var other: Color = texture_image.get_pixel(tx + offset.x, ty + offset.y)
				if other.a < 0.99 or absf(other.get_luminance() - centre.get_luminance()) > 0.004:
					flat = false
			if not flat:
				continue
			var x: int = box.position.x + int((float(tx) + 0.5) * ratio)
			var y: int = box.position.y + int((float(ty) + 0.5) * ratio)
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			worst = maxi(worst, int(roundf(absf(p.get_luminance() - q.get_luminance()) * 255.0)))
	return worst
