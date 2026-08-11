class_name PixelFont
extends RefCounted

## A 5x7 bitmap font blitted straight into an Image.
##
## Placeholders need their filename drawn on them, and an EditorScript has no
## CanvasItem to call `draw_string()` on. Rendering text through a SubViewport
## just to produce a placeholder is a lot of machinery for something that only
## has to be legible, so the glyphs are a literal bitmap.
##
## Each glyph is seven rows of five characters: "#" is ink, anything else is
## empty. Kept as rows rather than one packed string so a miscounted glyph is
## visible on sight — and `validate()` catches it anyway.
##
## Only the characters that appear in a snake_case filename are defined.

const GLYPH_W: int = 5
const GLYPH_H: int = 7

## Glyph width plus one column of letter spacing.
const ADVANCE: int = GLYPH_W + 1

## Glyph height plus two rows of leading.
const LINE_H: int = GLYPH_H + 2

## Upper bound on text scale, so a 1920x1080 backdrop does not get glyphs the
## size of a house.
const MAX_SCALE: int = 16

const GLYPHS: Dictionary = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	".": [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."],
	"/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}


## Returns a list of malformed glyphs. Empty means the table is sound.
static func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	for key: Variant in GLYPHS:
		var rows: Array = GLYPHS[key]
		if rows.size() != GLYPH_H:
			problems.append("'%s' has %d rows, expected %d" % [key, rows.size(), GLYPH_H])
			continue
		for i: int in rows.size():
			var row: String = rows[i]
			if row.length() != GLYPH_W:
				problems.append("'%s' row %d is %d wide, expected %d" % [key, i, row.length(), GLYPH_W])
	return problems


## Draws `lines` centred inside `rect`, at `scale`, in `colour`.
## Pixels are written directly; nothing outside the image is touched.
static func draw_lines(img: Image, lines: PackedStringArray, rect: Rect2i, scale: int, colour: Color) -> void:
	if lines.is_empty() or scale < 1:
		return
	var block_h: int = lines.size() * LINE_H * scale - 2 * scale
	var y: int = rect.position.y + int((rect.size.y - block_h) / 2.0)
	for line: String in lines:
		var line_w: int = line.length() * ADVANCE * scale - scale
		var x: int = rect.position.x + int((rect.size.x - line_w) / 2.0)
		_draw_line(img, line, x, y, scale, colour)
		y += LINE_H * scale


static func _draw_line(img: Image, text: String, x: int, y: int, scale: int, colour: Color) -> void:
	var cursor: int = x
	for i: int in text.length():
		_draw_glyph(img, text[i].to_upper(), cursor, y, scale, colour)
		cursor += ADVANCE * scale


static func _draw_glyph(img: Image, ch: String, x: int, y: int, scale: int, colour: Color) -> void:
	if not GLYPHS.has(ch):
		return
	var rows: Array = GLYPHS[ch]
	var img_w: int = img.get_width()
	var img_h: int = img.get_height()
	for row: int in GLYPH_H:
		var bits: String = rows[row]
		for col: int in GLYPH_W:
			if bits[col] != "#":
				continue
			var px: int = x + col * scale
			var py: int = y + row * scale
			# Clipped rather than skipped, so a glyph half off the edge still
			# draws the part that fits instead of vanishing entirely.
			var rx: int = maxi(px, 0)
			var ry: int = maxi(py, 0)
			var rw: int = mini(px + scale, img_w) - rx
			var rh: int = mini(py + scale, img_h) - ry
			if rw > 0 and rh > 0:
				img.fill_rect(Rect2i(rx, ry, rw, rh), colour)


## Lays `words` out inside a box, picking the largest scale that fits.
## Returns {"scale": int, "lines": PackedStringArray}.
static func fit(words: PackedStringArray, box: Vector2i) -> Dictionary:
	var fallback: Dictionary = {}
	for scale: int in range(MAX_SCALE, 0, -1):
		var max_chars: int = int(float(box.x + scale) / float(ADVANCE * scale))
		if max_chars < 1:
			continue
		var wrapped: Dictionary = _wrap(words, max_chars)
		var lines: PackedStringArray = wrapped["lines"]
		if lines.is_empty():
			continue
		var needed_h: int = lines.size() * LINE_H * scale - 2 * scale
		if needed_h > box.y:
			continue
		# A scale that fits without chopping a word in half is always preferred,
		# even when a larger one would fit by splitting.
		if not bool(wrapped["split"]):
			return {"scale": scale, "lines": lines}
		if fallback.is_empty():
			fallback = {"scale": scale, "lines": lines}
	if not fallback.is_empty():
		return fallback
	return {"scale": 1, "lines": PackedStringArray()}


## Greedy word wrap. Words longer than the line are hard-split, and that is
## reported back so `fit` can prefer a smaller scale that avoids it.
static func _wrap(words: PackedStringArray, max_chars: int) -> Dictionary:
	var lines: PackedStringArray = []
	var current: String = ""
	var split_used: bool = false
	for word: String in words:
		var w: String = word
		while w.length() > max_chars:
			split_used = true
			if not current.is_empty():
				lines.append(current)
				current = ""
			lines.append(w.substr(0, max_chars))
			w = w.substr(max_chars)
		if w.is_empty():
			continue
		if current.is_empty():
			current = w
		elif current.length() + 1 + w.length() <= max_chars:
			current += " " + w
		else:
			lines.append(current)
			current = w
	if not current.is_empty():
		lines.append(current)
	return {"lines": lines, "split": split_used}
