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

const USAGE: String = "usage: run_tool.gd -- <generate [--force] | report | seed | import [--dry] | font-check | theme | tool-leak | road-tiles | floor-tiles | audit [--todo]>"


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
		"http-gzip":
			_http_gzip()
		"road-tiles":
			_road_tiles()
		"floor-tiles":
			_floor_tiles()
		"audit":
			_audit(args.has("--todo"))
		_:
			print(USAGE)
			quit(2)


## Every HTTPRequest must turn `accept_gzip` off.
##
## It defaults to on, and on the web that is a trap: the browser has already
## decompressed the body by the time Godot sees it, but `Content-Encoding: gzip`
## is still on the response, so `HTTPRequest` decompresses it a second time and
## returns RESULT_BODY_DECOMPRESS_FAILED over a perfectly good HTTP 200.
##
## It failed *selectively* - responses too small to compress came through fine -
## so the browser build lost only the replies that actually carried something,
## and looked like a matchmaking service that answered every poll with nothing.
## It cost several days.
##
## Checked in the source rather than at runtime because the failure is silent
## and platform-specific: nothing on a desktop machine will ever notice it.
func _http_gzip() -> void:
	const SELF: String = "res://tools/run_tool.gd"
	const NEWLINE: String = "
"
	const MADE: String = "HTTPRequest" + ".new()"
	const DECLINED: String = "accept_gzip" + " = false"
	var offenders: PackedStringArray = []
	for path: String in _gd_files("res://"):
		# This file names the pattern in order to look for it.
		if path == SELF:
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var lines: PackedStringArray = text.split(NEWLINE)
		for index: int in lines.size():
			if not lines[index].contains(MADE):
				continue
			# The setter must follow within a couple of lines, on the object
			# just made. Anything further away is not obviously about this one.
			var near: String = ""
			for look: int in range(index, mini(index + 4, lines.size())):
				near += lines[look]
			if not near.contains(DECLINED):
				offenders.append("%s:%d" % [path, index + 1])
	if offenders.is_empty():
		print("[http] PASS - every HTTPRequest declines gzip")
		return
	for where: String in offenders:
		printerr("[http] FAIL %s makes an HTTPRequest without accept_gzip = false"
			% where)
	quit(1)


## Every .gd file under a directory, recursively.
func _gd_files(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var directory: DirAccess = DirAccess.open(root)
	if directory == null:
		return found
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while name != "":
		var path: String = root.path_join(name)
		if directory.current_is_dir():
			if not name.begins_with("."):
				found.append_array(_gd_files(path))
		elif name.ends_with(".gd"):
			found.append(path)
		name = directory.get_next()
	directory.list_dir_end()
	return found


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
## Every region's floor is legible, textured, and made of two materials that
## belong to the same place.
##
## The jungle floor shipped with a base material whose median luminance was 19
## out of 255 — near black, across most of the battlefield, for months. It was
## found by a person looking at a screenshot and calling it "the largest visual
## gap in the game", which is exactly the kind of defect a two-second check
## should have caught on the push that introduced it.
##
## Four rules, and each one is here because a real regeneration failed it:
##
## 1. **Not a hole.** Median luminance at or above `FLOOR_MIN`. The original
##    jungle base sat at 19 and read as a void the road was suspended over.
## 2. **Has texture.** The 1st-to-99th percentile spread is at least
##    `FLOOR_RANGE_MIN`. Pure-material Wang tiles intentionally devote most of
##    their area to one value, so the wider percentile window measures their
##    cracks and grains without requiring noisy wallpaper.
## 3. **Two materials, not one.** The RGB distance between the pure-lower and
##    pure-upper tiles is at least `FLOOR_MATERIAL_MIN`. A regeneration of the
##    snow set came back with both materials at the same near-white; the
##    sixteen-tile set was intact, correct, and drawing nothing.
## 4. **The same place.** Their luminance ratio is at most `FLOOR_CONTRAST_MAX`.
##    Snow shipped a near-black lower against a near-white upper — 5.1x — which
##    reads as holes cut in a snowfield rather than as drifts on one.
##
## 5. **Moody, not blown out.** Production art deliberately treats snow as dirty
##    steel-blue and saltglass as dusk-lit rather than white. The upper limit is
##    a regression guard against the bright replacement sets this pass rejected.
##
## Brightness is reported as a *median*, never a mean: a tile is mostly its
## material, and a handful of bright specks should not vouch for a black field.
func _floor_tiles() -> void:
	const REGIONS: Array[String] = ["jungle", "desert", "snow"]
	const FORMAT: String = "res://art/terrain/ground_%s_%02d.png"
	# Spelled out rather than read from Balance: this runs under a SceneTree tool
	# where no autoload exists, and naming one is a compile error.
	#
	# Thresholds describe the darker production target. They still reject the old
	# 19-luminance void, a truly flat generated tile, two identical materials, and
	# the near-white snow pass that prompted this rebuild.
	const FLOOR_MIN: int = 35
	const FLOOR_MAX: int = 160
	const FLOOR_RANGE_MIN: int = 6
	const FLOOR_MATERIAL_MIN: float = 10.0
	const FLOOR_CONTRAST_MAX: float = 3.2

	var problems: PackedStringArray = []
	for region: String in REGIONS:
		var medians: Array[int] = []
		var means: Array[Color] = []
		for mask: int in 16:
			var path: String = FORMAT % [region, mask]
			if not ResourceLoader.exists(path):
				problems.append("%s is missing" % path.get_file())
				continue
			var image: Image = (load(path) as Texture2D).get_image()
			image.convert(Image.FORMAT_RGBA8)

			var levels: PackedInt32Array = PackedInt32Array()
			var total := Vector3.ZERO
			for y: int in image.get_height():
				for x: int in image.get_width():
					var pixel: Color = image.get_pixel(x, y)
					if pixel.a <= 0.5:
						continue
					levels.append(int(round(pixel.get_luminance() * 255.0)))
					total += Vector3(pixel.r, pixel.g, pixel.b) * 255.0
			if levels.is_empty():
				problems.append("%s is fully transparent" % path.get_file())
				continue

			levels.sort()
			var count: int = levels.size()
			var median: int = levels[count / 2]
			var spread: int = levels[count * 99 / 100] - levels[count / 100]
			medians.append(median)
			total /= float(count)
			means.append(Color(total.x, total.y, total.z))

			if median < FLOOR_MIN:
				problems.append("%s is a hole, not ground: median luminance %d, floor is %d"
					% [path.get_file(), median, FLOOR_MIN])
			if median > FLOOR_MAX:
				problems.append("%s is overexposed: median luminance %d, ceiling is %d"
					% [path.get_file(), median, FLOOR_MAX])
			if spread < FLOOR_RANGE_MIN:
				problems.append("%s is a flat colour field: p1-p99 spread %d, needs %d"
					% [path.get_file(), spread, FLOOR_RANGE_MIN])

		# Corner masks 0 and 15 are the two materials undiluted. Everything else
		# is a blend of them, so the pair is the whole of what a region is made of.
		if medians.size() == 16 and means.size() == 16:
			var low: float = float(mini(medians[0], medians[15]))
			var high: float = float(maxi(medians[0], medians[15]))
			var ratio: float = high / maxf(low, 1.0)
			var apart: float = Vector3(means[0].r, means[0].g, means[0].b).distance_to(
				Vector3(means[15].r, means[15].g, means[15].b))
			if apart < FLOOR_MATERIAL_MIN:
				problems.append(
					"%s has one material, not two: the pure tiles are %.0f apart, needs %.0f"
					% [region, apart, FLOOR_MATERIAL_MIN])
			if ratio > FLOOR_CONTRAST_MAX:
				problems.append(
					"%s's materials are not the same place: %d against %d (%.1fx, limit %.1fx)"
					% [region, int(low), int(high), ratio, FLOOR_CONTRAST_MAX])
			print("  %-7s medians %d..%d   materials %.0f apart, %.2fx contrast"
				% [region, medians.min(), medians.max(), apart, ratio])

	if problems.is_empty():
		print("Floor tiles: all three regions legible, textured and cohesive.")
		quit(0)
		return
	for problem: String in problems:
		printerr("Floor tiles: %s" % problem)
	quit(1)


func _road_tiles() -> void:
	const SIDES: Array[String] = ["N", "E", "S", "W"]
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
			var lo: int = size / 4
			var hi: int = size * 3 / 4
			var collar: int = maxi(2, size * 2 / 32)
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
				for depth: int in collar:
					for i: int in range(lo, hi):
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
