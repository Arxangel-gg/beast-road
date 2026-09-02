extends Node

## Every glyph the interface prints must exist in a font that ships with it.
##
## Reported from a phone, 2026-09-02: stash buttons read "Sell 12" followed by an
## empty box. **Godot borrows a missing glyph from a system font on desktop and
## has nothing to borrow from on Android**, so a face that lacks a character
## renders correctly on every machine the game is developed on and as tofu on the
## one it is played on. Eleven such glyphs had accumulated - hearts, a padlock, a
## star, a crossmark, fullwidth brackets, the Marks symbol - and nothing could
## have caught them short of somebody looking at a phone.
##
## Three promises:
##
## 1. **No source string uses a glyph no bundled font can draw.** That is the
##    tofu, and it is unfixable at runtime.
## 2. **The display face falls back to the body face.** Every Button in the game
##    renders in Cinzel, whose coverage stops not far past Latin-1; the arrows
##    and diamonds the interface uses live in Alegreya. Without the chain those
##    are tofu too, and *with* it they are free.
## 3. **The fonts are actually there**, because a missing face is this same
##    failure at full volume.
##
## Scanned rather than rendered. Asking Godot to draw every string and look for
## the notdef box needs a real renderer, and the runners are headless - the same
## reason `night_check` refuses to run there. Reading the cmap needs neither.

const FACES: PackedStringArray = [
	"res://fonts/Cinzel-Variable.ttf",
	"res://fonts/Alegreya-Variable.ttf",
	"res://fonts/AlegreyaSansSC-Bold.ttf",
]

## Where player-facing strings are written.
const ROOTS: PackedStringArray = ["res://scenes", "res://scripts", "res://autoload"]

## Codepoints below this are Latin-1 and in every face here.
const PLAIN: int = 0x00FF

var _failures: int = 0
var _scanned: int = 0


func _ready() -> void:
	var covered: Dictionary = _coverage()
	if covered.is_empty():
		_finish()
		return
	for root: String in ROOTS:
		_walk(root, covered)
	print("[font-glyph] %d files scanned against %d glyphs the bundled faces cover"
		% [_scanned, covered.size()])

	# 2. The chain, which is what makes the arrows and diamonds legal at all.
	UiFonts.apply()
	_check(UiFonts.chained(),
		"the display face must fall back to the body face, or every arrow and "
			+ "diamond in the interface is an empty box on Android")
	_finish()


## Every codepoint at least one bundled face can draw.
func _coverage() -> Dictionary:
	var covered: Dictionary = {}
	for path: String in FACES:
		_check(ResourceLoader.exists(path), "missing font %s" % path)
		var face := load(path) as FontFile
		if face == null:
			continue
		# `get_supported_chars` is the cmap, which is the question being asked.
		for ch: String in face.get_supported_chars():
			covered[ch.unicode_at(0)] = true
	_check(not covered.is_empty(), "no font reported any coverage at all")
	return covered


func _walk(path: String, covered: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var full: String = "%s/%s" % [path, name]
		if dir.current_is_dir():
			_walk(full, covered)
		elif name.ends_with(".gd"):
			_scan(full, covered)
		name = dir.get_next()
	dir.list_dir_end()


func _scan(path: String, covered: Dictionary) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return
	_scanned += 1
	var line: int = 1
	var reported: Dictionary = {}
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code == 10:
			line += 1
			continue
		if code <= PLAIN or covered.has(code) or reported.has(code):
			continue
		reported[code] = true
		_check(false,
			"%s:%d prints U+%04X, which no bundled font can draw - it renders "
				% [path.get_file(), line, code]
				+ "as an empty box on Android and correctly everywhere else")


func _finish() -> void:
	if _failures == 0:
		print("[font-glyph] PASS - every printed glyph exists in a shipped face, "
			+ "and the display face falls back to the body face")
	else:
		push_error("[font-glyph] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[font-glyph] FAIL: %s" % why)
