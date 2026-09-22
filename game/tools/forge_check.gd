extends Node

## The forge's sheet is real, the player plays it once, and it is decoration.
##
##   godot --headless --path game res://tools/forge_check.tscn
##
## `tools/vfx_forge` renders an effect in Blender and the game plays the sheet
## through `Vfx.forge_burst` (docs/VFX_FORGE.md). Three ways it can be a lie:
## a sheet that is not on disk at the size the manifest declares, or whose
## cells are empty (a material that rendered nothing packs into a perfectly
## well-formed strip of nothing); a player that leaves the sprite behind, or
## draws it with the density turned off - the decoration bound every effect
## here is held to; and a call site that has quietly gone, so the sheet ships
## and nothing plays it.

const CELL: int = 96

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_sheet_is_on_disk_at_its_size()
	_test_the_variants_are_variants()
	await _test_the_player_plays_it_once_and_gives_way()
	_test_the_forge_is_wired_where_it_says()
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 8:
		await get_tree().process_frame
	if _failures.is_empty():
		print("[forge] PASS - %d checks: the sheet, the player, and where it plays" % _checks)
	else:
		for failure: String in _failures:
			push_error("[forge] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## **The variants differ from each other and from the original** (owner,
## 2026-09-22: the forged effects should have variations).
##
## Compared cell by cell rather than by file size: three renders of the same
## graph with the seed ignored would be byte-identical files, and three
## renders with the seed *applied to nothing downstream* would be three
## different files that draw the same picture. What is measured is the middle
## cell, which is where the noise break-up actually shows - the first two
## cells are the same on purpose, because the ring has not frayed yet.
func _test_the_variants_are_variants() -> void:
	var pool: Array[String] = []
	for path: String in Vfx.FORGE_BURST_VARIANTS:
		if ResourceLoader.exists(path):
			pool.append(path)
	_check(pool.size() >= 2, "the forge must render more than one sheet, found %d"
		% pool.size())
	var seen: Array[int] = []
	for path: String in pool:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			_check(false, "%s will not load" % path)
			continue
		_check(texture.get_height() == CELL and texture.get_width() == CELL * Vfx.FORGE_BURST_FRAMES,
			"%s is not %d cells of %d" % [path, Vfx.FORGE_BURST_FRAMES, CELL])
		var image: Image = texture.get_image()
		if image == null:
			continue
		# Late rather than middle: the graph's seed moves the noise lookup, and
		# what it moves is where the ring frays - which is the back half.
		var late: int = _lit(image, Vfx.FORGE_BURST_FRAMES - 4)
		_check(not seen.has(late),
			"%s draws the same picture as another variant (%d lit)" % [path, late])
		seen.append(late)


func _test_the_sheet_is_on_disk_at_its_size() -> void:
	_check(ResourceLoader.exists(Vfx.FORGE_BURST_ART), "the forged burst is not on disk")
	if not ResourceLoader.exists(Vfx.FORGE_BURST_ART):
		return
	var texture: Texture2D = load(Vfx.FORGE_BURST_ART) as Texture2D
	_check(texture != null, "the forged burst will not load")
	if texture == null:
		return
	_check(texture.get_height() == CELL,
		"the sheet is %d tall and the manifest says %d" % [texture.get_height(), CELL])
	_check(texture.get_width() == CELL * Vfx.FORGE_BURST_FRAMES,
		"the sheet is %d wide, which is not %d cells of %d"
			% [texture.get_width(), Vfx.FORGE_BURST_FRAMES, CELL])
	var image: Image = texture.get_image()
	if image == null:
		_check(false, "the sheet has no image to read")
		return
	var first: int = _lit(image, 0)
	var middle: int = _lit(image, Vfx.FORGE_BURST_FRAMES / 2)
	var last: int = _lit(image, Vfx.FORGE_BURST_FRAMES - 1)
	_check(first > 200, "the first cell is empty (%d lit) - the material rendered nothing" % first)
	_check(middle > 200, "the middle cell is empty (%d lit)" % middle)
	_check(last < middle, "the ring does not fray away: last cell %d lit against the middle's %d"
		% [last, middle])
	# White on transparent, or the tint lands on a colour the render invented.
	var tinted: int = 0
	for x: int in range(0, CELL, 3):
		for y: int in range(0, CELL, 3):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.5 and absf(pixel.r - pixel.g) + absf(pixel.g - pixel.b) > 0.06:
				tinted += 1
	_check(tinted == 0, "%d pixels of the first cell carry a colour; the sheet must be white" % tinted)


func _lit(image: Image, cell: int) -> int:
	var count: int = 0
	for x: int in range(cell * CELL, (cell + 1) * CELL, 2):
		for y: int in range(0, CELL, 2):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
	return count


func _test_the_player_plays_it_once_and_gives_way() -> void:
	var world := Node2D.new()
	add_child(world)
	var before: Node2D = Vfx.world
	Vfx.world = world
	Vfx.forge_burst(Vector2(40.0, 40.0), 120.0, Color(1.0, 0.5, 0.2))
	var sprites: Array[Sprite2D] = _sprites_under(world)
	_check(sprites.size() == 1, "one call should stand one sprite up, stood %d" % sprites.size())
	if sprites.size() == 1:
		var burst: Sprite2D = sprites[0]
		_check(burst.hframes == Vfx.FORGE_BURST_FRAMES,
			"the sprite is cut into %d cells, not %d" % [burst.hframes, Vfx.FORGE_BURST_FRAMES])
		var material := burst.material as CanvasItemMaterial
		_check(material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"a forged burst is light and must be drawn additively")
		_check(burst.modulate.r > burst.modulate.b, "the tint was not applied")
		_check(burst.global_position.is_equal_approx(Vector2(40.0, 40.0)), "it plays where it was asked")
		var life: float = float(Vfx.FORGE_BURST_FRAMES) / Balance.VFX_FORGE_FRAME_RATE
		await get_tree().create_timer(life * 0.5).timeout
		_check(is_instance_valid(burst) and burst.frame > 0 and burst.frame < Vfx.FORGE_BURST_FRAMES - 1,
			"half way through its life the sheet should be mid-play (frame %d)"
				% (burst.frame if is_instance_valid(burst) else -1))
		await get_tree().create_timer(life * 0.7).timeout
		await get_tree().process_frame
		_check(not is_instance_valid(burst), "the sprite must free itself when the sheet has played")
	# **And with the density off it plays nothing at all** - the decoration
	# bound. Set through the same door the settings screen uses.
	Graphics._chosen[Graphics.KEY_PARTICLES] = 0.0
	Vfx.forge_burst(Vector2.ZERO, 120.0)
	_check(_sprites_under(world).is_empty(), "with particles at zero a forged burst still drew")
	Graphics._chosen.erase(Graphics.KEY_PARTICLES)
	Vfx.world = before
	world.queue_free()
	await get_tree().process_frame


func _sprites_under(root: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child: Node in root.get_children():
		if child is Sprite2D:
			out.append(child as Sprite2D)
	return out


func _test_the_forge_is_wired_where_it_says() -> void:
	for path: String in ["res://scenes/battlefield/enemy_projectile.gd",
			"res://scenes/battlefield/enemy.gd", "res://scenes/battlefield/projectile.gd"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_check(false, "%s is missing" % path)
			continue
		_check(file.get_as_text().contains("Vfx.forge_burst("),
			"%s no longer plays the forged burst" % path.get_file())
	var root: String = ProjectSettings.globalize_path("res://").path_join("..").path_join("tools").path_join("vfx_forge")
	_check(FileAccess.file_exists(root.path_join("forge.py")) and FileAccess.file_exists(root.path_join("render.py")),
		"the forge's tools are not at tools/vfx_forge (looked in %s)" % root)
