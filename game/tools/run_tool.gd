extends SceneTree

## Headless entry point for the asset tools.
##
## `EditorScript` cannot be run from the command line — Godot 4.7's `--script`
## requires a SceneTree or MainLoop, and instantiating an EditorScript outside
## the editor is refused outright. So the tools keep their EditorScript
## front-ends for use inside the editor, the actual work lives in plain
## RefCounted classes, and this script is the third caller.
##
## Nothing here may touch an autoload: replacing the main loop means the
## autoload singletons are never instantiated, and referencing one is a compile
## error rather than a runtime one.
##
##   godot --headless --path game --script res://tools/run_tool.gd -- generate
##   godot --headless --path game --script res://tools/run_tool.gd -- generate --force
##   godot --headless --path game --script res://tools/run_tool.gd -- report
##   godot --headless --path game --script res://tools/run_tool.gd -- seed
##   godot --headless --path game --script res://tools/run_tool.gd -- import [--dry]
##   godot --headless --path game --script res://tools/run_tool.gd -- road-tiles

const USAGE: String = "usage: run_tool.gd -- <generate [--force] | report | seed | import [--dry] | font-check | theme | tool-leak | road-tiles | audit [--todo]>"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print(USAGE)
		quit(2)
		return

	match args[0]:
		"generate":
			_generate(args.has("--force"))
		"report":
			_report()
		"seed":
			_seed()
		"import":
			_import(args.has("--dry"))
		"font-check":
			_font_check()
		"theme":
			_theme()
		"tool-leak":
			_tool_leak()
		"road-tiles":
			_road_tiles()
		"audit":
			_audit(args.has("--todo"))
		_:
			print(USAGE)
			quit(2)


func _generate(force: bool) -> void:
	var generator := PlaceholderGenerator.new()
	var result: Dictionary = generator.generate(force)
	print("Placeholders: %d created, %d already present, %d failed (of %d in manifest)" % [
		result["created"], result["skipped"], result["failed"], result["total"],
	])
	for e: String in generator.errors:
		print("  ERROR: ", e)
	quit(1 if (int(result["failed"]) > 0 or not generator.errors.is_empty()) else 0)


## Every path tile connects on exactly the edges its filename claims.
##
## The autotiler picks a tile purely by index, so a tile whose art connects north
## and west while sitting in the north-east slot draws a road that stops dead in
## the middle of a bend. That happened: the generated set arrived in an order that
## had nothing to do with the mask, two masks were missing outright, and the only
## reason it was caught was a screenshot. It is measurable in a second, so it is
## a gate.
##
## Also checks the collar - the road must present the same cross-section at every
## connected edge - because a tile that is a pixel narrow there leaves a hairline
## of terrain across the road at the join.
func _road_tiles() -> void:
	const SIDES: Array[String] = ["N", "E", "S", "W"]
	const LO: int = 8
	const HI: int = 24
	const COLLAR: int = 2
	# Spelled out rather than read from Battlefield: that class reaches RunState,
	# and an autoload does not exist in a SceneTree tool - naming it is a compile
	# error, not a runtime one.
	const FORMAT: String = "res://art/battlefield/path_tile_%02d.png"
	# Every region's set, not just the default one. A region whose road is one
	# tile short renders a road that stops dead mid-bend, and it does it only in
	# that act - which is the last place anybody looks.
	const REGIONS: Array[String] = ["jungle", "desert", "snow"]
	var sets: Array[String] = [FORMAT]
	for region: String in REGIONS:
		var candidate: String = "res://art/battlefield/path_%s_%%02d.png" % region
		if ResourceLoader.exists(candidate % 0):
			sets.append(candidate)

	var problems: PackedStringArray = []
	for format: String in sets:
		for mask: int in 16:
			var path: String = format % mask
			if not ResourceLoader.exists(path):
				problems.append("%s is missing" % path.get_file())
				continue
			var image: Image = (load(path) as Texture2D).get_image()
			image.convert(Image.FORMAT_RGBA8)
			var size: int = image.get_width()
			var found: int = 0
			for bit: int in 4:
				var count: int = 0
				for i: int in size:
					var at: Vector2i = [Vector2i(i, 0), Vector2i(size - 1, i),
						Vector2i(i, size - 1), Vector2i(0, i)][bit]
					if image.get_pixel(at.x, at.y).a > 0.5:
						count += 1
				if count >= 4:
					found |= 1 << bit
			if found != mask:
				problems.append("%s connects %s, should connect %s" % [
					path.get_file(), _edges(found, SIDES), _edges(mask, SIDES)])
				continue
			for bit: int in 4:
				if not (mask >> bit) & 1:
					continue
				for depth: int in COLLAR:
					for i: int in range(LO, HI):
						var at: Vector2i = [Vector2i(i, depth), Vector2i(size - 1 - depth, i),
							Vector2i(i, size - 1 - depth), Vector2i(depth, i)][bit]
						if image.get_pixel(at.x, at.y).a <= 0.5:
							problems.append("%s has a thin %s collar at %s" % [
								path.get_file(), SIDES[bit], at])
							break
	if problems.is_empty():
		print("Road tiles: %d sets x 16 connect as named, collars solid."
			% sets.size())
		quit(0)
		return
	for problem: String in problems:
		print("  ERROR: ", problem)
	quit(1)


func _edges(mask: int, names: Array[String]) -> String:
	var out: PackedStringArray = []
	for bit: int in 4:
		if (mask >> bit) & 1:
			out.append(names[bit])
	return "".join(out) if not out.is_empty() else "nothing"


func _report() -> void:
	var reporter := AssetReporter.new()
	var result: Dictionary = reporter.report()
	print(result["text"])
	quit(0 if bool(result["clean"]) else 1)


func _seed() -> void:
	var seeder := ContentSeeder.new()
	var result: Dictionary = seeder.seed()
	print("Content: %d created, %d already present, %d errors" % [
		result["created"], result["skipped"], result["errors"],
	])
	for e: String in seeder.errors:
		print("  ERROR: ", e)
	quit(1 if int(result["errors"]) > 0 else 0)


func _import(dry: bool) -> void:
	var importer := ArtImporter.new()
	var result: Dictionary = importer.import_all(dry)
	print(importer.report())
	quit(1 if int(result["problems"]) > 0 else 0)


## Shipped code must not reference anything under tools/: the export strips it,
## and a missing class_name is a parse failure, not a runtime one.
## How much of GDD v4 exists. Reporting only - never fails the build, because a
## migration in progress is supposed to be incomplete.
func _audit(todo_only: bool) -> void:
	var result: Dictionary = GddAudit.run(todo_only)
	print(result["text"])
	quit(0 if bool(result["ok"]) else 1)


func _tool_leak() -> void:
	var result: Dictionary = ToolLeakCheck.run()
	if bool(result["ok"]):
		print("Tool leak check: %d shipped scripts, none reference an excluded class."
			% result["checked"])
		quit(0)
		return
	for leak: String in result["leaks"]:
		print("  ERROR: ", leak)
	quit(1)


func _theme() -> void:
	var result: Dictionary = ThemeBuilder.build()
	if bool(result["ok"]):
		print("Theme written to %s from the UI frame art." % result["path"])
		quit(0)
		return
	print("  ERROR: ", result["error"])
	quit(1)


func _font_check() -> void:
	var problems: PackedStringArray = PixelFont.validate()
	if problems.is_empty():
		print("PixelFont: all %d glyphs are %dx%d." % [PixelFont.GLYPHS.size(), PixelFont.GLYPH_W, PixelFont.GLYPH_H])
		quit(0)
		return
	for p: String in problems:
		print("  ERROR: ", p)
	quit(1)
