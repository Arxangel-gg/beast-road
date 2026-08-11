class_name PlaceholderGenerator
extends RefCounted

## Generates a placeholder PNG for every asset listed in docs/ASSET_MANIFEST.md
## that is not already on disk.
##
## The contract these files have to honour (CLAUDE.md §4):
##
##   - exact final path and exact final pixel dimensions, so installing real art
##     is overwriting a file and nothing else
##   - pixel (0,0) is pure magenta, which is how asset_report.gd tells a
##     placeholder from real art
##   - transparent-background assets get a genuinely transparent centre, so a
##     broken alpha channel shows up now rather than after ninety images exist
##
## Existing files are never touched unless `force` is set. That is deliberate:
## running this after real art has been installed must not destroy it.

## Width of the magenta detection border, in pixels.
const BORDER: int = 4

const MAGENTA: Color = Color(1.0, 0.0, 1.0, 1.0)
const BONE: Color = Color("d9cdb8")
const VOID: Color = Color("0b1416")

## Luminance above which a fill counts as light and wants dark text on it.
const LIGHT_FILL_THRESHOLD: float = 0.45

## Text on a transparent centre is read against the dark game background, so a
## dark category colour is lifted toward bone before it is drawn.
const DARK_TEXT_THRESHOLD: float = 0.40

var errors: PackedStringArray = []


## Returns {"created": int, "skipped": int, "failed": int, "total": int}.
func generate(force: bool = false) -> Dictionary:
	errors = []

	var font_problems: PackedStringArray = PixelFont.validate()
	if not font_problems.is_empty():
		for p: String in font_problems:
			errors.append("PixelFont: " + p)
		return {"created": 0, "skipped": 0, "failed": 0, "total": 0}

	var parser := ManifestParser.new()
	var assets: Array[ManifestAsset] = parser.parse()
	errors.append_array(parser.errors)
	if assets.is_empty():
		errors.append("Manifest produced no assets — check %s" % ManifestParser.manifest_path())
		return {"created": 0, "skipped": 0, "failed": 0, "total": 0}

	var created: int = 0
	var skipped: int = 0
	var failed: int = 0

	for asset: ManifestAsset in assets:
		if FileAccess.file_exists(asset.res_path) and not force:
			skipped += 1
			continue
		var dir: String = asset.res_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			var mk: int = DirAccess.make_dir_recursive_absolute(dir)
			if mk != OK:
				errors.append("Could not create %s (error %d)" % [dir, mk])
				failed += 1
				continue
		var img: Image = build_image(asset)
		var err: int = img.save_png(asset.res_path)
		if err != OK:
			errors.append("Could not write %s (error %d)" % [asset.res_path, err])
			failed += 1
			continue
		created += 1

	return {"created": created, "skipped": skipped, "failed": failed, "total": assets.size()}


func build_image(asset: ManifestAsset) -> Image:
	var w: int = asset.width
	var h: int = asset.height
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

	# Too small to hold a border and anything else: a solid marker is the only
	# honest thing to draw. No manifest entry is this small, but a future one
	# should not silently produce garbage.
	if w < BORDER * 2 + 4 or h < BORDER * 2 + 4:
		img.fill(MAGENTA)
		return img

	var fill: Color = Color(asset.colour, 1.0)
	var band: int = clampi(int(minf(w, h) / 16.0), 3, 20)
	var text_inset: int = BORDER + 2

	if asset.transparent:
		# Transparent centre with a category-coloured band just inside the
		# border: the silhouette still reads at a glance, and the alpha channel
		# is real rather than a checkerboard drawn into the pixels.
		img.fill(Color(fill.r, fill.g, fill.b, 0.0))
		_fill_ring(img, Rect2i(BORDER, BORDER, w - BORDER * 2, h - BORDER * 2), band, fill)
		text_inset = BORDER + band + 2
	else:
		img.fill(fill)

	_fill_ring(img, Rect2i(0, 0, w, h), BORDER, MAGENTA)

	var box := Rect2i(text_inset, text_inset, w - text_inset * 2, h - text_inset * 2)
	if box.size.x > 0 and box.size.y > 0:
		var words: PackedStringArray = asset.res_path.get_file().get_basename().split("_", false)
		var layout: Dictionary = PixelFont.fit(words, box.size)
		PixelFont.draw_lines(img, layout["lines"], box, int(layout["scale"]), _text_colour(fill, asset.transparent))

	# Last, so nothing can overwrite the detection marker.
	img.set_pixel(0, 0, MAGENTA)
	return img


## Draws a `thickness`-wide ring just inside `rect`.
func _fill_ring(img: Image, rect: Rect2i, thickness: int, colour: Color) -> void:
	var t: int = mini(thickness, mini(rect.size.x, rect.size.y) / 2)
	if t <= 0:
		return
	var x: int = rect.position.x
	var y: int = rect.position.y
	var w: int = rect.size.x
	var h: int = rect.size.y
	img.fill_rect(Rect2i(x, y, w, t), colour)
	img.fill_rect(Rect2i(x, y + h - t, w, t), colour)
	img.fill_rect(Rect2i(x, y + t, t, h - t * 2), colour)
	img.fill_rect(Rect2i(x + w - t, y + t, t, h - t * 2), colour)


func _text_colour(fill: Color, transparent: bool) -> Color:
	if not transparent:
		return VOID if fill.get_luminance() > LIGHT_FILL_THRESHOLD else BONE
	# On a transparent centre there is no fill to contrast against, so keep the
	# category hue but lift it until it reads on the dark arena background.
	if fill.get_luminance() < DARK_TEXT_THRESHOLD:
		return fill.lerp(BONE, 0.65)
	return fill
