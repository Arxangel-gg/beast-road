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

const USAGE: String = "usage: run_tool.gd -- <generate [--force] | report | seed | import [--dry] | font-check | theme | tool-leak>"


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
