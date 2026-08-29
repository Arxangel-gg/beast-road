extends SceneTree

## Finalises generated seamless material sources for runtime use.
##
## This does not invent or draw road art. It downsamples the reviewed generated
## paintings and reconciles opposite edges over a narrow band so the runtime
## shader can repeat them without a visible seam.

const FINAL_SIZE: int = 512
const SEAM_BAND: int = 64


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: build_road_surfaces.gd -- <source.png> <output.png>")
		quit(1)
		return
	var source := Image.new()
	var load_error: Error = source.load(args[0])
	if load_error != OK:
		printerr("road surface source could not be loaded: %s" % error_string(load_error))
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	source.resize(FINAL_SIZE, FINAL_SIZE, Image.INTERPOLATE_LANCZOS)
	_reconcile_horizontal(source)
	_reconcile_vertical(source)
	var save_error: Error = source.save_png(args[1])
	if save_error != OK:
		printerr("road surface could not be saved: %s" % error_string(save_error))
		quit(1)
		return
	print("[seamless-texture] %s -> %s (%dx%d, seamless band %d)" % [
		args[0], args[1], FINAL_SIZE, FINAL_SIZE, SEAM_BAND])
	quit(0)


func _reconcile_horizontal(image: Image) -> void:
	for y: int in FINAL_SIZE:
		for inset: int in SEAM_BAND:
			var left_x: int = inset
			var right_x: int = FINAL_SIZE - 1 - inset
			var weight: float = 0.5 + 0.5 * cos(PI * float(inset) / float(SEAM_BAND - 1))
			var left: Color = image.get_pixel(left_x, y)
			var right: Color = image.get_pixel(right_x, y)
			var shared: Color = left.lerp(right, 0.5)
			image.set_pixel(left_x, y, left.lerp(shared, weight))
			image.set_pixel(right_x, y, right.lerp(shared, weight))


func _reconcile_vertical(image: Image) -> void:
	for x: int in FINAL_SIZE:
		for inset: int in SEAM_BAND:
			var top_y: int = inset
			var bottom_y: int = FINAL_SIZE - 1 - inset
			var weight: float = 0.5 + 0.5 * cos(PI * float(inset) / float(SEAM_BAND - 1))
			var top: Color = image.get_pixel(x, top_y)
			var bottom: Color = image.get_pixel(x, bottom_y)
			var shared: Color = top.lerp(bottom, 0.5)
			image.set_pixel(x, top_y, top.lerp(shared, weight))
			image.set_pixel(x, bottom_y, bottom.lerp(shared, weight))
