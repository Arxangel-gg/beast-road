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

## Size of the corner marker on seamless assets, which get no border.
const MARKER_PIP: int = 6

## How far the checker shades diverge from the base fill.
const TEXTURE_CONTRAST: float = 0.022

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

	if w < BORDER * 2 + 4 or h < BORDER * 2 + 4:
		img.fill(MAGENTA)
		return img

	var fill: Color = Color(asset.colour, 1.0)
	var seamless: bool = _is_seamless(asset)
	var band: int = clampi(int(minf(w, h) / 16.0), 3, 20)
	var text_inset: int = BORDER + 2

	if asset.transparent:
		img.fill(Color(fill.r, fill.g, fill.b, 0.0))
		_fill_ring(img, Rect2i(BORDER, BORDER, w - BORDER * 2, h - BORDER * 2), band, fill)
		text_inset = BORDER + band + 2
	else:
		img.fill(fill)
		_texture_fill(img, fill)

	# A tiling texture cannot carry a border: four magenta edges turn a tiled
	# floor into graph paper, which is exactly what made the battlefield
	# unreadable. Detection still works — pixel (0,0) is the contract, and the
	# corner pip keeps it visible to a human.
	if seamless:
		img.fill_rect(Rect2i(0, 0, MARKER_PIP, MARKER_PIP), MAGENTA)
		text_inset = BORDER + 2
	else:
		_fill_ring(img, Rect2i(0, 0, w, h), BORDER, MAGENTA)

	var box := Rect2i(text_inset, text_inset, w - text_inset * 2, h - text_inset * 2)
	if box.size.x > 0 and box.size.y > 0:
		var words: PackedStringArray = asset.res_path.get_file().get_basename().split("_", false)
		var layout: Dictionary = PixelFont.fit(words, box.size)
		# Capped independently of the box: text that fills a 512px tile reads as
		# a pattern rather than a label, and tiled across a floor it is noise.
		var scale: int = mini(int(layout["scale"]), _max_scale_for(w, h))
		PixelFont.draw_lines(img, layout["lines"], box, maxi(scale, 1), _text_colour(fill, asset.transparent))

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


## Terrain tiles and full-screen backdrops are laid edge to edge or stretched,
## so they must not carry a frame.
func _is_seamless(asset: ManifestAsset) -> bool:
	return not asset.transparent and (
		asset.res_path.begins_with("res://art/terrain/")
		or asset.res_path.begins_with("res://art/bg/"))


## Label size relative to the asset, so a 64px icon and a 1920px backdrop both
## end up with text that reads as a label.
func _max_scale_for(w: int, h: int) -> int:
	return clampi(int(minf(w, h) / 110.0) + 1, 1, 5)


## Breaks up a flat fill so a tiled floor has some grain to read movement
## against, without turning into a pattern that competes with the units on it.
func _texture_fill(img: Image, fill: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var cell: int = maxi(int(minf(w, h) / 6.0), 8)
	var light: Color = fill.lightened(TEXTURE_CONTRAST)
	var dark: Color = fill.darkened(TEXTURE_CONTRAST)
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			# Deterministic: the same asset regenerates byte-identically, so a
			# rebuild is not a spurious diff in version control.
			var checker: bool = ((x / cell) + (y / cell)) % 2 == 0
			var shade: Color = light if checker else dark
			img.fill_rect(Rect2i(x, y, mini(cell, w - x), mini(cell, h - y)), shade)
			x += cell
		y += cell


func _text_colour(fill: Color, transparent: bool) -> Color:
	if not transparent:
		return VOID if fill.get_luminance() > LIGHT_FILL_THRESHOLD else BONE
	# On a transparent centre there is no fill to contrast against, so keep the
	# category hue but lift it until it reads on the dark arena background.
	if fill.get_luminance() < DARK_TEXT_THRESHOLD:
		return fill.lerp(BONE, 0.65)
	return fill
