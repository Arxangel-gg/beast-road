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
	"res://fonts/AtkinsonHyperlegibleNext-Variable.ttf",
	"res://fonts/Cinzel-Variable.ttf",
	"res://fonts/Alegreya-Variable.ttf",
	"res://fonts/AlegreyaSansSC-Bold.ttf",
]

## Where player-facing strings are written.
const ROOTS: PackedStringArray = ["res://scenes", "res://scripts", "res://autoload", "res://data"]

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
	_test_the_weights_move()
	_test_the_theme_wears_the_roles()
	_finish()


## 4. **A weight that is set is a weight that is drawn** (2026-09-30). The axis
## is keyed by its tag as an integer, and `{"wght": 700}` parses and moves
## nothing: every word in the game rendered at 400 for ten days that way. So
## each role's face is *measured* against the same face at 400 - a heavier cut
## is wider - and no file in the project may key the axis by its name.
func _test_the_weights_move() -> void:
	const PROBE: String = "Build Ember Spire 120 Gold"
	for role: int in UiFonts.FACES:
		var spec: Array = UiFonts.FACES[role]
		var weight: int = int(spec[1])
		var file := load(String(spec[0])) as FontFile
		if weight <= 0 or weight == 400 or file == null:
			continue
		var plain := FontVariation.new()
		plain.base_font = file
		plain.variation_opentype = {UiFonts.WGHT: 400}
		var drawn: float = UiFonts.face(role).get_string_size(PROBE,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var at_400: float = plain.get_string_size(PROBE, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		_check(drawn > at_400 + 0.5,
			"role %s asks %s for weight %d and draws %.1f wide against %.1f at 400 - "
				% [UiFonts.Role.keys()[role], String(spec[0]).get_file(), weight, drawn, at_400]
				+ "the weight never reached the font")
	for root: String in ["res://scripts", "res://scenes", "res://autoload", "res://tools"]:
		_refuse_named_axis(root)
	var theme: String = FileAccess.get_file_as_string("res://ui_theme.tres")
	_check(not theme.contains("\"wght\""),
		"ui_theme.tres keys a weight by the name \"wght\" - it parses and draws at 400")


func _refuse_named_axis(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = "%s/%s" % [path, name]
		if dir.current_is_dir():
			_refuse_named_axis(full)
		elif name.ends_with(".gd") and full != "res://tools/font_glyph_check.gd":
			# Code only: the notes that explain the trap have to be able to show it.
			for line: String in FileAccess.get_file_as_string(full).split("
"):
				if line.strip_edges().begins_with("#"):
					continue
				_check(not line.contains("{\"wght\""),
					"%s keys the weight axis by its name - it parses and draws at 400; "
						% full + "use UiFonts.WGHT")
		name = dir.get_next()
	dir.list_dir_end()


## 5. **The theme draws with the roles**: body text in the body face, a button in
## the button face, and a draw that once reached for the engine's own Open Sans
## (`ThemeDB.fallback_font`) is gone from every script but the debug overlay.
func _test_the_theme_wears_the_roles() -> void:
	var engine_face := RegEx.create_from_string("ThemeDB[.]fallback_font(?!_)")
	var theme: Theme = load("res://ui_theme.tres") as Theme
	_check(theme != null, "ui_theme.tres did not load")
	if theme == null:
		return
	for pair: Array in [[theme.default_font, UiFonts.Role.BODY, "the default"],
			[theme.get_font("font", "Button"), UiFonts.Role.BUTTON, "a button"]]:
		var font := pair[0] as FontVariation
		var spec: Array = UiFonts.FACES[int(pair[1])]
		_check(font != null and font.base_font != null
				and font.base_font.resource_path == String(spec[0])
				and int(font.variation_opentype.get(UiFonts.WGHT, 0)) == int(spec[1]),
			"%s font in the theme is not UiFonts' %s face - re-run run_tool.gd -- theme"
				% [pair[2], UiFonts.Role.keys()[int(pair[1])]])
	for path: String in ["res://scripts/systems/kill_streak.gd",
			"res://scripts/systems/vfx_ink.gd", "res://scenes/battlefield/placement_cursor.gd",
			"res://scripts/components/revive_bar.gd", "res://scenes/ui/disciplines_screen.gd",
			"res://autoload/TouchInput.gd"]:
		_check(engine_face.search(FileAccess.get_file_as_string(path)) == null,
			"%s draws with ThemeDB.fallback_font, which is the engine's Open Sans " % path
				+ "rather than any face the game ships")


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
		# Scene labels and authored data are player-facing copy too. Checking
		# scripts alone missed exactly the strings moved out of UI logic.
		elif name.ends_with(".gd") or name.ends_with(".tres") or name.ends_with(".tscn"):
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
