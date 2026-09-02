class_name UiFonts
extends RefCounted

## Makes the display face fall back to the body face for glyphs it lacks.
##
## Reported from a phone, 2026-09-02: stash buttons read "Sell 12" followed by an
## empty box. **Godot falls back to a system font on desktop and there is nothing
## to fall back to on Android**, so a glyph missing from the bundled face renders
## as tofu there and correctly everywhere the developers were looking.
##
## Cinzel is the display face and every Button in the game uses it. It is an
## inscriptional Roman face and its coverage stops not far past Latin-1: it has
## no arrows and no geometric shapes, which the interface uses for Marks, Shards,
## route steps and the crossroads mark. Alegreya has all four. Chaining them
## costs nothing and fixes every one of those at the point of rendering.
##
## **This is only half the rule.** A glyph missing from *both* faces has nowhere
## to fall back to, and there were eleven of those - hearts, a padlock, a star,
## fullwidth brackets. Those were replaced rather than chained, and
## `font_glyph_check` is what stops new ones arriving.

const DISPLAY: String = "res://fonts/Cinzel-Variable.ttf"
const BODY: String = "res://fonts/Alegreya-Variable.ttf"


## Chains the faces. Safe to call more than once.
static func apply() -> void:
	var display := load(DISPLAY) as FontFile
	var body := load(BODY) as FontFile
	if display == null or body == null:
		return
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
