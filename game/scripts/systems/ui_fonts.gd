class_name UiFonts
extends RefCounted

## **Four faces, each kept for what it is best at** (2026-09-30). The owner asked
## for "multiple fonts to be used each the best one for the best purpose", and
## the game had four bundled and drew with one.
##
## - **Body** - Atkinson Hyperlegible Next at 500. Everything read for more than
##   a few words: descriptions, tooltips, readouts, the stash. It was designed
##   for low vision, and it is the face that survives a phone.
## - **Button** - the same face at 620. A button is read at a glance and wants a
##   real bold; it stays Atkinson because a button's label must fit its plate,
##   and a carved display face is a third wider at the same size.
## - **Title** - Cinzel at 700. A screen's name, an act, a boss, a cinematic.
##   Inscriptional capitals: it reads as cut into something, and it is the
##   wordmark's own register. Read a few words at a time, never a paragraph.
## - **Heading** - Alegreya Sans SC Bold, with a little tracking. A panel's own
##   header and a section's label: small capitals say "this is a heading"
##   without the weight of a title.
## - **Flavour** - Alegreya at 500. Lore, a story panel, an encounter's words, a
##   portent's line: a book face, for what is meant to be read as words in the
##   world rather than as interface.
## - **Impact** - Atkinson at 800. Numbers that fly - damage, a streak's count -
##   which have to read in a fifth of a second over anything.
##
## **The weight axis is keyed by its tag as an integer.** `{"wght": 700}` parses,
## matches no axis and leaves the font at 400; from 2026-09-20 to 2026-09-30
## every word in the game, buttons included, rendered at 400 because the theme
## was built that way. `WGHT` is the tag, and `face` is the only place a weight
## is set.
##
## Keep these resources alive: a fallback attached to an unreferenced font is lost
## when the local variable goes out of scope, even though the next load succeeds.

const DISPLAY: String = "res://fonts/Cinzel-Variable.ttf"
const BODY: String = "res://fonts/AtkinsonHyperlegibleNext-Variable.ttf"
const BOOK: String = "res://fonts/Alegreya-Variable.ttf"
const SMALL_CAPS: String = "res://fonts/AlegreyaSansSC-Bold.ttf"

enum Role { BODY, BUTTON, TITLE, HEADING, FLAVOUR, IMPACT }

## 'wght' packed big-endian, as `FontVariation.variation_opentype` keys it.
const WGHT: int = 2003265652

## Each role's face and weight. A static face (the small capitals) has no axis
## and its weight is ignored.
const FACES: Dictionary = {
	Role.BODY: [BODY, 500],
	Role.BUTTON: [BODY, 620],
	Role.TITLE: [DISPLAY, 700],
	Role.HEADING: [SMALL_CAPS, 0],
	Role.FLAVOUR: [BOOK, 500],
	Role.IMPACT: [BODY, 800],
}

## Extra space between letters for the roles that are set in capitals, which
## crowd at a weight a lowercase face does not.
const TRACKING: Dictionary = {
	Role.TITLE: 1,
	Role.HEADING: 1,
}

static var _faces: Dictionary = {}
## Every face a fallback was set on, kept alive: a `FontFile` nobody holds is
## freed, and the next `load` hands back a fresh one with no chain.
static var _kept: Array[FontFile] = []


## The face for `role`, built once and shared, so every label of a role is one
## resource and the renderer batches it as one.
static func face(role: Role) -> Font:
	if _faces.has(role):
		return _faces[role]
	var spec: Array = FACES[role]
	var file := load(String(spec[0])) as FontFile
	if file == null:
		return ThemeDB.fallback_font
	var variation := FontVariation.new()
	variation.base_font = file
	if int(spec[1]) > 0 and file.get_supported_variation_list().has(WGHT):
		variation.variation_opentype = {WGHT: int(spec[1])}
	variation.spacing_glyph = int(TRACKING.get(role, 0))
	_faces[role] = variation
	return variation


## Chains the faces. Safe to call more than once.
##
## Cinzel's coverage stops not far past Latin-1 and the small capitals' near it,
## so both fall back to the body face, which falls back to the book face for the
## arrows and diamonds it lacks.
static func apply() -> void:
	var display := load(DISPLAY) as FontFile
	var body := load(BODY) as FontFile
	if display == null or body == null:
		return
	var symbols := load(BOOK) as FontFile
	if symbols != null and not body.fallbacks.has(symbols):
		body.fallbacks = [symbols] as Array[Font]
	_fall_back_to(display, body)
	var caps := load(SMALL_CAPS) as FontFile
	if caps != null:
		_fall_back_to(caps, body)
	for kept: FontFile in [display, body, symbols, caps]:
		if kept != null and not _kept.has(kept):
			_kept.append(kept)


static func _fall_back_to(face_file: FontFile, body: FontFile) -> void:
	for existing: Variant in face_file.fallbacks:
		if existing == body:
			return
	var chain: Array[Font] = []
	chain.assign(face_file.fallbacks)
	chain.append(body)
	face_file.fallbacks = chain


## Whether the chain is in place. For the gate, and for anything that wants to
## know before it prints a glyph.
static func chained() -> bool:
	for path: String in [DISPLAY, SMALL_CAPS]:
		var face_file := load(path) as FontFile
		if face_file == null:
			return false
		var found: bool = false
		for existing: Variant in face_file.fallbacks:
			if existing is FontFile and (existing as FontFile).resource_path == BODY:
				found = true
		if not found:
			return false
	return true


## Sets a Label (or a Button) in `role` at `size`. One line at a call site, so
## a screen opts a label into a role rather than choosing a font file.
static func set_role(control: Control, role: Role, size: int = 0) -> void:
	if control == null:
		return
	control.add_theme_font_override("font", face(role))
	if control is RichTextLabel:
		control.add_theme_font_override("normal_font", face(role))
		if size > 0:
			control.add_theme_font_size_override("normal_font_size", size)
	if size > 0:
		control.add_theme_font_size_override("font_size", size)
