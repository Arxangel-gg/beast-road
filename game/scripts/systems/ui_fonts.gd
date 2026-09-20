class_name UiFonts
extends RefCounted

## Readable UI body text, with retained title and symbol fallbacks on all platforms.
## Keep these resources alive: a fallback attached to an unreferenced font is lost
## when the local variable goes out of scope, even though the next load succeeds.

const DISPLAY: String = "res://fonts/Cinzel-Variable.ttf"
const BODY: String = "res://fonts/AtkinsonHyperlegibleNext-Variable.ttf"

## Keep the optional title face alive even on screens using only the new UI face.
static var _display_face: FontFile


## Chains the faces. Safe to call more than once.
static func apply() -> void:
	var display := load(DISPLAY) as FontFile
	_display_face = display
	var body := load(BODY) as FontFile
	if display == null or body == null:
		return
	var symbols := load("res://fonts/Alegreya-Variable.ttf") as FontFile
	if symbols != null and not body.fallbacks.has(symbols):
		body.fallbacks = [symbols] as Array[Font]
	for existing: Variant in display.fallbacks:
		if existing == body:
			return
	var chain: Array[Font] = []
	chain.assign(display.fallbacks)
	chain.append(body)
	display.fallbacks = chain


## Whether the chain is in place. For the gate, and for anything that wants to
## know before it prints a glyph.
static func chained() -> bool:
	var display := load(DISPLAY) as FontFile
	if display == null:
		return false
	for existing: Variant in display.fallbacks:
		if existing is FontFile and (existing as FontFile).resource_path == BODY:
			return true
	return false
