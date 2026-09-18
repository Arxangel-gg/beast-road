class_name GroundTone
extends RefCounted

## **What colour the ground is, for anything that has to match it.**
##
## Owner, 2026-09-17: movement should throw dust *"tuned for the color of the
## ground under where it occurred"*, and before that, that a mount's trail should
## match *"the ground of the area they walk"*.
##
## A dust colour picked by hand is right for one region and wrong for nine. Every
## place in this game paints its floor with a sheet; the honest answer to "what
## colour is the ground here" is to read that sheet. The Hold arrived at this
## first and kept its own copy; the battlefield and the arenas want the same
## answer, and three copies of one reading is how one of them ends up disagreeing
## with the ground it is standing on.
##
## **Lifted, not literal.** Dust in the air catches light that the earth it came
## off does not, so the mean is multiplied by `Balance.GROUND_TONE_LIFT` before
## it is handed back. Without it a puff over dark soil is a smudge nobody sees.
##
## **A mean, not a pixel.** The sheet is downsampled to four by four and averaged,
## which is both far cheaper than sampling a texel per footfall and more correct:
## a single texel of pixel-art ground is frequently a speck of highlight or a
## crack, and a cloud the colour of one crack is not the colour of the ground.
##
## Cached per texture, because the answer cannot change while the sheet does not.

static var _means: Dictionary = {}


## The tone of one ground sheet. `Color(0.46, 0.42, 0.34)` - plain earth - when
## there is nothing to read, so a caller never has to check.
static func of(sheet: Texture2D) -> Color:
	if sheet == null:
		return Balance.GROUND_TONE_FALLBACK
	if _means.has(sheet):
		return _means[sheet] as Color
	var image: Image = sheet.get_image()
	if image == null:
		return Balance.GROUND_TONE_FALLBACK
	image.convert(Image.FORMAT_RGBA8)
	image.resize(4, 4, Image.INTERPOLATE_BILINEAR)
	var total := Color(0.0, 0.0, 0.0)
	for y: int in 4:
		for x: int in 4:
			total += image.get_pixel(x, y)
	var mean: Color = (total / 16.0) * Balance.GROUND_TONE_LIFT
	var lifted := Color(minf(mean.r, 1.0), minf(mean.g, 1.0), minf(mean.b, 1.0))
	_means[sheet] = lifted
	return lifted


## The tone of whatever sheet is at a path. Convenience for callers that hold a
## path rather than a loaded texture; the load is cached by Godot and the mean by
## the table above, so asking every frame would still only read the sheet once.
static func at_path(path: String) -> Color:
	if path.is_empty() or not ResourceLoader.exists(path):
		return Balance.GROUND_TONE_FALLBACK
	return of(load(path) as Texture2D)


## Forgets every cached mean. For the tools that swap ground art in one process
## and would otherwise read the sheet they installed over.
static func forget() -> void:
	_means.clear()
