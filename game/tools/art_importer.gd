class_name ArtImporter
extends RefCounted

## Installs finished art from `art_inbox/` into `res://art/`.
##
## The point of this is that **the filename is the only thing the artist has to
## get right**. Everything else — which folder it belongs in, what pixel size it
## has to be, whether it needs an alpha channel — is already in the manifest, so
## asking a human to reproduce that by hand is asking them to make mistakes.
##
## Generate at whatever resolution the tool gives you. This resizes.
##
##   - transparent assets are scaled to *fit* and centred on a clear canvas, so
##     nothing gets cropped off a sprite and the margin stays even
##   - opaque assets are scaled to *cover* and centre-cropped, so a backdrop
##     fills the frame with no letterboxing
##
## An existing file is overwritten: installing real art is meant to be exactly
## that. The originals stay in the inbox, so a bad import is undoable.

const INBOX_RELATIVE: String = "../art_inbox"

## A transparent asset whose pixels are all this opaque did not export an alpha
## channel, whatever the file format claims.
const ALPHA_THRESHOLD: float = 0.98

## Fraction of pixels that must be see-through for the alpha to count as real.
const MIN_TRANSPARENT_FRACTION: float = 0.005

var installed: PackedStringArray = []
var skipped: PackedStringArray = []
var problems: PackedStringArray = []

## Non-fatal remarks, reported but not blocking.
var notes: PackedStringArray = []


static func inbox_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join(INBOX_RELATIVE).simplify_path()


## Returns {"installed": int, "skipped": int, "problems": int}.
func import_all(dry_run: bool = false) -> Dictionary:
	installed = []
	skipped = []
	problems = []
	notes = []

	var inbox: String = inbox_dir()
	if not DirAccess.dir_exists_absolute(inbox):
		problems.append("No art_inbox folder at %s" % inbox)
		return _summary()

	var parser := ManifestParser.new()
	var assets: Array[ManifestAsset] = parser.parse()
	if assets.is_empty():
		problems.append("Manifest produced no assets.")
		return _summary()

	var by_name: Dictionary = {}
	for asset: ManifestAsset in assets:
		by_name[asset.file_name().to_lower()] = asset

	var dir: DirAccess = DirAccess.open(inbox)
	if dir == null:
		problems.append("Could not open %s" % inbox)
		return _summary()

	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if dir.current_is_dir() or name.begins_with("."):
			name = dir.get_next()
			continue
		if name.get_extension().to_lower() != "png":
			skipped.append("%s — not a .png" % name)
			name = dir.get_next()
			continue

		var key: String = name.to_lower()
		if not by_name.has(key):
			problems.append("%s — no manifest entry with that filename. Check the spelling against docs/ASSET_PROMPTS.md." % name)
			name = dir.get_next()
			continue

		_install(inbox.path_join(name), by_name[key] as ManifestAsset, dry_run)
		name = dir.get_next()
	dir.list_dir_end()

	return _summary()


func _install(source: String, asset: ManifestAsset, dry_run: bool) -> void:
	var img: Image = Image.load_from_file(source)
	if img == null:
		problems.append("%s — could not be read as an image." % asset.file_name())
		return

	var original: Vector2i = img.get_size()

	# A missing alpha channel is fatal for a sprite - a hero on an opaque black
	# square is a black square. It is *not* fatal for a UI frame: a panel that
	# fills its whole rectangle is a perfectly good panel, and demanding
	# transparency of one only produced a regenerate-and-fail loop.
	if asset.transparent and not _has_real_alpha(img):
		if _alpha_optional(asset):
			notes.append("%s — fully opaque, installed anyway (UI frames may be solid)." % asset.file_name())
		else:
			problems.append("%s — no alpha channel; it arrived fully opaque. Ask for 'a true transparent alpha channel, not a checkerboard pattern drawn in the image' and regenerate." % asset.file_name())
			return

	img.convert(Image.FORMAT_RGBA8)
	var fitted: Image = _fit(img, asset) if asset.transparent else _cover(img, asset)

	if dry_run:
		installed.append("%s  %dx%d -> %dx%d  (dry run)" % [
			asset.file_name(), original.x, original.y, asset.width, asset.height])
		return

	var folder: String = asset.res_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
	var err: int = fitted.save_png(asset.res_path)
	if err != OK:
		problems.append("%s — could not write %s (error %d)" % [asset.file_name(), asset.res_path, err])
		return
	installed.append("%s  %dx%d -> %dx%d  %s" % [
		asset.file_name(), original.x, original.y, asset.width, asset.height, asset.res_path])


## Scale to fit inside the target, centred on a fully transparent canvas.
## Nothing is cropped, and the sprite keeps an even margin.
func _fit(img: Image, asset: ManifestAsset) -> Image:
	var scale: float = minf(float(asset.width) / float(img.get_width()),
		float(asset.height) / float(img.get_height()))
	var w: int = maxi(int(round(float(img.get_width()) * scale)), 1)
	var h: int = maxi(int(round(float(img.get_height()) * scale)), 1)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)

	var canvas: Image = Image.create_empty(asset.width, asset.height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	canvas.blit_rect(img, Rect2i(0, 0, w, h),
		Vector2i(int((asset.width - w) / 2.0), int((asset.height - h) / 2.0)))
	return canvas


## Scale to cover the target, then centre-crop. Backdrops must fill the frame.
func _cover(img: Image, asset: ManifestAsset) -> Image:
	var scale: float = maxf(float(asset.width) / float(img.get_width()),
		float(asset.height) / float(img.get_height()))
	var w: int = maxi(int(ceil(float(img.get_width()) * scale)), asset.width)
	var h: int = maxi(int(ceil(float(img.get_height()) * scale)), asset.height)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)

	var x: int = int((w - asset.width) / 2.0)
	var y: int = int((h - asset.height) / 2.0)
	return img.get_region(Rect2i(x, y, asset.width, asset.height))


## Samples rather than scanning every pixel: a 1024x1024 import would otherwise
## be a million get_pixel calls for a yes/no answer.
## Frames, bars and buttons are drawn as filled rectangles. Everything else that
## claims transparency has to actually have it.
func _alpha_optional(asset: ManifestAsset) -> bool:
	return asset.res_path.begins_with("res://art/ui/")


func _has_real_alpha(img: Image) -> bool:
	if not img.detect_alpha():
		return false
	var w: int = img.get_width()
	var h: int = img.get_height()
	var step: int = maxi(int(minf(w, h) / 64.0), 1)
	var seen: int = 0
	var clear: int = 0
	var y: int = 0
	while y < h:
		var x: int = 0
		while x < w:
			seen += 1
			if img.get_pixel(x, y).a < ALPHA_THRESHOLD:
				clear += 1
			x += step
		y += step
	return seen > 0 and float(clear) / float(seen) >= MIN_TRANSPARENT_FRACTION


func _summary() -> Dictionary:
	return {"installed": installed.size(), "skipped": skipped.size(), "problems": problems.size()}


func report() -> String:
	var lines: PackedStringArray = []
	lines.append("BEAST ROAD — art import")
	lines.append("=======================")
	lines.append("inbox: %s" % inbox_dir())
	lines.append("")
	if not installed.is_empty():
		lines.append("INSTALLED — %d" % installed.size())
		for line: String in installed:
			lines.append("  " + line)
		lines.append("")
	if not problems.is_empty():
		lines.append("PROBLEMS — %d" % problems.size())
		for line: String in problems:
			lines.append("  " + line)
		lines.append("")
	if not skipped.is_empty():
		lines.append("SKIPPED — %d" % skipped.size())
		for line: String in skipped:
			lines.append("  " + line)
		lines.append("")
	if installed.is_empty() and problems.is_empty() and skipped.is_empty():
		lines.append("Inbox is empty. Drop finished PNGs into art_inbox/ and run this again.")
	return "\n".join(lines)
