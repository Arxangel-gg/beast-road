extends Node

## Every forged sheet is real, every one is played, and none of them is read.
##
##   godot --headless --path game res://tools/forge_check.tscn
##
## `tools/vfx_forge` renders each effect in Blender from one node graph and
## the game plays the sheet through `Vfx.forge_play` (docs/VFX_FORGE.md).
## Grown from one effect to twenty-four on 2026-09-22, and the ways it can be
## a lie grew with it:
##
## - **A sheet that is not on disk**, or whose cells are empty - a material
##   that rendered nothing packs into a perfectly well-formed strip of
##   nothing, and no number anywhere goes wrong.
## - **A sheet on disk that the catalogue does not name.** That one is the
##   `DisciplineEffects` lie in the art layer: the file ships, the render
##   time was paid, and nothing in the game can ever play it. Walked in both
##   directions for exactly the reason `audio_verify` walks its two.
## - **An effect the catalogue names that no script outside `Vfx` plays.**
##   An entry read by nobody is a row in a table, not an effect.
## - **A take that is not a take**: three renders of one graph with the seed
##   reaching nothing downstream are three different files drawing the same
##   picture.
## - **A turn policy broken.** An `UPRIGHT` sheet spun lies on its side and
##   an `AIMED` one spun points its spray into the ground it came off. Both
##   are measured on the sprite the player actually stands up.
## - **A player that leaves the sprite behind, or draws with the density
##   off** - the decoration bound every effect here is held to.

## **A cell is square, and between these.** Deliberately a range rather than
## one number: an effect declares its own size in its `SPEC`, and what a
## mortar landing wants is not what a meteor wants. What must hold is that a
## sheet is a row of *squares* - the player divides the width by the height
## to find the cell count, so a sheet that is not is played at the wrong
## length with nothing saying so.
const CELL_MIN: int = 32
const CELL_MAX: int = 256

## Where the sheets live, for the walk in the other direction.
const VFX_DIR: String = "res://art/vfx"

## The one script allowed to know the catalogue exists. Reading it while
## looking for call sites would make every row name itself, which is the
## vacuous check `audio_verify` nearly shipped.
const THE_PLAYER: String = "res://autoload/Vfx.gd"

var _failures: PackedStringArray = []
var _checks: int = 0
var _world: Node2D = null


func _ready() -> void:
	MetaState.hold_saves()
	_test_every_effect_has_a_sheet()
	_test_every_sheet_has_an_effect()
	_test_the_takes_are_takes()
	_test_every_effect_is_played_by_something()
	_test_the_elements_are_covered()
	await _test_the_player_plays_it_once_and_gives_way()
	await _test_the_turn_policy_is_obeyed()
	_test_the_forge_is_where_it_says()
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 8:
		await get_tree().process_frame
	if _failures.is_empty():
		print("[forge] PASS - %d checks over %d effects: the sheets, the player, the turns, the wiring"
			% [_checks, Vfx.FORGE_CATALOGUE.size()])
	else:
		for failure: String in _failures:
			push_error("[forge] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


# --- the sheets --------------------------------------------------------------

## Every take of one effect, found by the same rule `Vfx` finds them by.
func _takes_of(effect: String) -> Array[String]:
	var out: Array[String] = []
	var plain: String = Vfx.FORGE_ART_FORMAT % effect
	if ResourceLoader.exists(plain):
		out.append(plain)
	for take: int in range(1, Vfx.FORGE_TAKES_MAX + 1):
		var path: String = Vfx.FORGE_TAKE_FORMAT % [effect, take]
		if ResourceLoader.exists(path):
			out.append(path)
	return out


func _test_every_effect_has_a_sheet() -> void:
	for key: Variant in Vfx.FORGE_CATALOGUE:
		var effect: String = String(key)
		var takes: Array[String] = _takes_of(effect)
		_check(not takes.is_empty(),
			"%s is in the catalogue and has no sheet on disk - every call to it draws nothing"
				% effect)
		for path: String in takes:
			_read_one_sheet(effect, path)


## A sheet is a row of squares, white on transparent, and its cells are not
## empty. The cell count is read off the file rather than declared, so an
## effect re-rendered at a different length simply is that length.
func _read_one_sheet(effect: String, path: String) -> void:
	var texture: Texture2D = load(path) as Texture2D
	_check(texture != null, "%s will not load" % path)
	if texture == null:
		return
	var tall: int = texture.get_height()
	var wide: int = texture.get_width()
	_check(tall >= CELL_MIN and tall <= CELL_MAX,
		"%s has %d-pixel cells, outside the %d..%d a sheet is rendered at"
			% [path, tall, CELL_MIN, CELL_MAX])
	_check(tall > 0 and wide % tall == 0,
		"%s is %dx%d - a sheet is a whole number of square cells" % [path, wide, tall])
	if tall <= 0 or wide % tall != 0:
		return
	var cells: int = wide / tall
	_check(cells >= 8, "%s has only %d cells; nothing at %d frames a second reads"
		% [path, cells, int(Balance.VFX_FORGE_FRAME_RATE)])
	var image: Image = texture.get_image()
	if image == null:
		_check(false, "%s has no image to read" % path)
		return
	var first: int = _lit(image, 0, tall)
	var middle: int = _lit(image, cells / 2, tall)
	# **A share of the cell, never a count.** The first cut held an absolute
	# 200 against a 96-pixel cell sampled every other pixel; at 64 the same
	# grid holds fewer than half as many samples, so nine perfectly good
	# sheets read as blank. What "empty" means is a fraction of what is
	# there to fill.
	var samples: int = (tall / 2) * (tall / 2)
	var floor_lit: int = maxi(int(float(samples) * 0.02), 20)
	_check(first + middle > floor_lit,
		"%s draws nothing in its first or middle cell (%d + %d lit of %d sampled)"
			% [path, first, middle, samples])
	# White on transparent, or the game's tint lands on a colour the render
	# invented. Sampled on the middle cell, which is the fullest one.
	var tinted: int = 0
	var start: int = (cells / 2) * tall
	for x: int in range(start, start + tall, 4):
		for y: int in range(0, tall, 4):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.5 and absf(pixel.r - pixel.g) + absf(pixel.g - pixel.b) > 0.06:
				tinted += 1
	_check(tinted == 0,
		"%d sampled pixels of %s carry a colour; a forged sheet must be white (%s)"
			% [tinted, path.get_file(), effect])


func _lit(image: Image, cell: int, tall: int) -> int:
	var count: int = 0
	for x: int in range(cell * tall, (cell + 1) * tall, 2):
		for y: int in range(0, tall, 2):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
	return count


## **And the other direction.** A sheet rendered, imported and shipped that
## the catalogue does not name is an effect nobody can play - the render was
## paid for and the file is dead weight. Nothing errors, which is why this
## has to be walked rather than trusted.
func _test_every_sheet_has_an_effect() -> void:
	var dir: DirAccess = DirAccess.open(VFX_DIR)
	_check(dir != null, "cannot read %s" % VFX_DIR)
	if dir == null:
		return
	var orphans: PackedStringArray = []
	for file: String in dir.get_files():
		# Imported textures answer as `.png.import` headless; either spelling
		# names the same sheet.
		var named: String = file.trim_suffix(".import")
		if not named.begins_with("forge_") or not named.ends_with(".png"):
			continue
		var stem: String = named.trim_prefix("forge_").trim_suffix(".png")
		var parts: PackedStringArray = stem.rsplit("_", true, 1)
		var effect: String = stem
		if parts.size() == 2 and parts[1].is_valid_int():
			effect = parts[0]
		if not Vfx.FORGE_CATALOGUE.has(effect) and not orphans.has(effect):
			orphans.append(effect)
	_check(orphans.is_empty(),
		"%d sheet(s) on disk that the catalogue does not name, so nothing can play them: %s"
			% [orphans.size(), ", ".join(orphans)])


## **The takes differ from each other.** Compared cell by cell rather than by
## file size: a graph whose seed reaches nothing downstream renders
## byte-identical takes, and one whose seed reaches only a colour renders
## different files that draw the same picture. Read late, because the seed
## moves where the noise breaks the effect up and that is the back half.
func _test_the_takes_are_takes() -> void:
	var with_takes: int = 0
	for key: Variant in Vfx.FORGE_CATALOGUE:
		var effect: String = String(key)
		var takes: Array[String] = _takes_of(effect)
		if takes.size() < 2:
			continue
		with_takes += 1
		var seen: Array[String] = []
		for path: String in takes:
			var texture: Texture2D = load(path) as Texture2D
			if texture == null:
				continue
			var image: Image = texture.get_image()
			if image == null:
				continue
			# **The pixels, not a count of them.** A lit-pixel total is a
			# single number and two genuinely different pictures collide on
			# it constantly - the first cut of this failed three honest
			# takes for having the same total. What the check is for is a
			# seed that reaches nothing downstream, and that produces files
			# that are identical, which is exactly what this asks.
			var fingerprint: String = image.get_data().hex_encode()
			_check(not seen.has(fingerprint),
				"%s is pixel-for-pixel another take of %s - the seed reached nothing"
					% [path.get_file(), effect])
			seen.append(fingerprint)
	_check(with_takes >= 12,
		"only %d effects have more than one take; the owner asked for several of each"
			% with_takes)


## **Every effect is played by some script that is not the player.** The same
## rule `DisciplineEffects` is held to: a key on a list that no consumer names
## is a promise nobody keeps. Grepped rather than driven, because what this
## catches is *wiring* - which is the half that goes silently missing.
func _test_every_effect_is_played_by_something() -> void:
	var text: String = _all_game_source() + "
" + _the_player_without_its_tables()
	for key: Variant in Vfx.FORGE_CATALOGUE:
		var effect: String = String(key)
		if Vfx.FORGE_HIT_BY_ELEMENT.values().has(effect):
			# The five hits are reached by a *lookup* rather than by being
			# written down at a call site, so a grep can never see them.
			# They are driven instead, below, which is a stronger answer.
			continue
		_check(text.contains('"%s"' % effect),
			"nothing plays %s, so its sheet ships and never draws" % effect)


## `Vfx` with its two catalogue literals cut out.
##
## **A declaration is not a call site.** Reading the player whole would let
## every row name itself and the check would pass on an effect nothing
## plays - the vacuous shape `audio_verify` nearly shipped. Reading it not at
## all would fail the effects `Vfx` legitimately plays from its own signal
## handlers, which is where a level landing and a relic socketing belong.
func _the_player_without_its_tables() -> String:
	var file := FileAccess.open(THE_PLAYER, FileAccess.READ)
	if file == null:
		_check(false, "%s is missing" % THE_PLAYER)
		return ""
	var text: String = file.get_as_text()
	for table: String in ["const FORGE_CATALOGUE: Dictionary = {",
			"const FORGE_HIT_BY_ELEMENT: Dictionary = {"]:
		var opens: int = text.find(table)
		if opens < 0:
			_check(false, "%s no longer declares %s" % [THE_PLAYER, table])
			continue
		var closes: int = text.find("
}", opens)
		if closes < 0:
			continue
		text = text.substr(0, opens) + text.substr(closes + 2)
	return text


func _all_game_source() -> String:
	var out: PackedStringArray = []
	_gather("res://scenes", out)
	_gather("res://scripts", out)
	_gather("res://autoload", out)
	return "\n".join(out)


func _gather(from: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(from)
	if dir == null:
		return
	for named: String in dir.get_files():
		if not named.ends_with(".gd"):
			continue
		var path: String = from.path_join(named)
		if path == THE_PLAYER:
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			into.append(file.get_as_text())
	for sub: String in dir.get_directories():
		_gather(from.path_join(sub), into)


## The five hits, and the refusal. An element with no row must draw nothing
## rather than fall back to some other element's picture - a fire hit on an
## air blow is worse than no hit at all.
func _test_the_elements_are_covered() -> void:
	for named: Variant in Vfx.FORGE_HIT_BY_ELEMENT:
		var effect: String = String(Vfx.FORGE_HIT_BY_ELEMENT[named])
		_check(Vfx.FORGE_CATALOGUE.has(effect),
			"element %s is mapped to %s, which is not in the catalogue" % [named, effect])
		_check(not _takes_of(effect).is_empty(),
			"element %s is mapped to %s, which has no sheet" % [named, effect])
	for element: int in TowerData.Element.size():
		var named: String = TowerData.element_name(element).to_lower()
		_check(Vfx.FORGE_HIT_BY_ELEMENT.has(named),
			"the element %s has no forged hit; every element the game has must have one" % named)


# --- the player ---------------------------------------------------------------

func _stage() -> Node2D:
	if _world == null:
		_world = Node2D.new()
		add_child(_world)
	for child: Node in _world.get_children():
		_world.remove_child(child)
		child.free()
	return _world


func _sprites_under(root: Node) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for child: Node in root.get_children():
		if child is Sprite2D:
			out.append(child as Sprite2D)
	return out


func _test_the_player_plays_it_once_and_gives_way() -> void:
	var world: Node2D = _stage()
	var before: Node2D = Vfx.world
	Vfx.world = world
	Vfx.forge_play("burst", Vector2(40.0, 40.0), 120.0, Color(1.0, 0.5, 0.2))
	var sprites: Array[Sprite2D] = _sprites_under(world)
	_check(sprites.size() == 1, "one call should stand one sprite up, stood %d" % sprites.size())
	if sprites.size() == 1:
		var burst: Sprite2D = sprites[0]
		var texture: Texture2D = burst.texture
		var cells: int = 0
		if texture != null and texture.get_height() > 0:
			cells = texture.get_width() / texture.get_height()
		_check(burst.hframes == cells and cells > 0,
			"the sprite is cut into %d cells and the sheet holds %d" % [burst.hframes, cells])
		var material := burst.material as CanvasItemMaterial
		_check(material != null and material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD,
			"a forged sheet is light and must be drawn additively")
		_check(burst.modulate.r > burst.modulate.b, "the tint was not applied")
		_check(burst.global_position.is_equal_approx(Vector2(40.0, 40.0)),
			"it plays where it was asked")
		var life: float = float(maxi(cells, 1)) / Balance.VFX_FORGE_FRAME_RATE
		await get_tree().create_timer(life * 0.5).timeout
		_check(is_instance_valid(burst) and burst.frame > 0 and burst.frame < cells - 1,
			"half way through its life the sheet should be mid-play (frame %d)"
				% (burst.frame if is_instance_valid(burst) else -1))
		await get_tree().create_timer(life * 0.7).timeout
		await get_tree().process_frame
		_check(not is_instance_valid(burst), "the sprite must free itself when the sheet has played")

	# **Every element actually draws**, which is the answer for the five the
	# grep above skips. They are reached by a lookup rather than written at
	# a call site, so the only honest way to ask whether they work is to ask
	# for one and see a sprite - which is a stronger check than a grep and
	# is why they are excused from it.
	for element: int in TowerData.Element.size():
		world = _stage()
		var named: String = TowerData.element_name(element).to_lower()
		Vfx.forge_hit(named, Vector2(12.0, 0.0), 100.0, Color(0.9, 0.9, 1.0))
		var drew: Array[Sprite2D] = _sprites_under(world)
		_check(drew.size() == 1,
			"asking for the %s hit stood %d sprites up" % [named, drew.size()])
		if drew.size() == 1:
			_check(drew[0].texture != null, "the %s hit stood a sprite with no sheet" % named)
	# And a sword's hit, which is the one that is not an element at all.
	world = _stage()
	Vfx.forge_hit("physical", Vector2.ZERO, 100.0)
	_check(_sprites_under(world).size() == 1, "steel has no forged hit")

	# An effect nobody authored, and an element nobody mapped: both draw
	# nothing rather than erroring, which is what lets a half-finished art
	# pass ship rather than crash.
	world = _stage()
	Vfx.forge_play("no_such_effect_at_all", Vector2.ZERO, 100.0)
	_check(_sprites_under(world).is_empty(), "an unknown effect drew something")
	Vfx.forge_hit("aether", Vector2.ZERO, 100.0)
	_check(_sprites_under(world).is_empty(), "an unknown element drew something")

	# **And with the density off it plays nothing at all** - the decoration
	# bound. Set through the same door the settings screen uses.
	Graphics._chosen[Graphics.KEY_PARTICLES] = 0.0
	Vfx.forge_play("burst", Vector2.ZERO, 120.0)
	Vfx.forge_hit("fire", Vector2.ZERO, 120.0)
	_check(_sprites_under(world).is_empty(), "with particles at zero a forged sheet still drew")
	Graphics._chosen.erase(Graphics.KEY_PARTICLES)
	Vfx.world = before
	await get_tree().process_frame


## **What may be turned, and what may not.** Measured on the sprites the
## player actually stands up rather than read back off the table, because a
## table that says UPRIGHT while the code spins everything would pass a read.
func _test_the_turn_policy_is_obeyed() -> void:
	var world: Node2D = _stage()
	var before: Node2D = Vfx.world
	Vfx.world = world

	# Free: a spread of angles over enough calls that one repeated angle
	# cannot pass.
	for _i: int in 24:
		Vfx.forge_play("burst", Vector2.ZERO, 100.0)
	var angles: Array[float] = []
	for sprite: Sprite2D in _sprites_under(world):
		angles.append(sprite.rotation)
	var spread: float = 0.0
	if not angles.is_empty():
		for angle: float in angles:
			spread = maxf(spread, absf(angle - angles[0]))
	_check(spread > 1.0,
		"a freely-turned sheet came out at the same angle 24 times (spread %.2f rad)" % spread)

	# Upright: never turned, never flipped top to bottom, mirrored sometimes.
	world = _stage()
	for _i: int in 16:
		Vfx.forge_play("level_up", Vector2.ZERO, 100.0)
	var upright: Array[Sprite2D] = _sprites_under(world)
	var turned: int = 0
	var upside_down: int = 0
	var mirrored: int = 0
	for sprite: Sprite2D in upright:
		if absf(sprite.rotation) > 0.001:
			turned += 1
		if sprite.flip_v:
			upside_down += 1
		if sprite.flip_h:
			mirrored += 1
	_check(turned == 0, "%d of %d upright sheets were turned; the ground is down"
		% [turned, upright.size()])
	_check(upside_down == 0, "%d of %d upright sheets were flipped top to bottom"
		% [upside_down, upright.size()])
	_check(mirrored > 0 and mirrored < upright.size(),
		"an upright sheet should be mirrored left to right sometimes (%d of %d)"
			% [mirrored, upright.size()])

	# Aimed: laid along the angle it was given, within the wander, and never
	# mirrored along that same axis.
	world = _stage()
	var aim: float = 0.9
	for _i: int in 16:
		Vfx.forge_play("beam_end", Vector2.ZERO, 100.0, Color.WHITE, aim)
	var aimed: Array[Sprite2D] = _sprites_under(world)
	var off: int = 0
	var flipped_along: int = 0
	for sprite: Sprite2D in aimed:
		if absf(sprite.rotation - aim) > Vfx.FORGE_AIM_WANDER + 0.001:
			off += 1
		if sprite.flip_h:
			flipped_along += 1
	_check(off == 0, "%d of %d aimed sheets were laid off their aim by more than the wander"
		% [off, aimed.size()])
	_check(flipped_along == 0,
		"%d of %d aimed sheets were mirrored along the very axis they point down"
			% [flipped_along, aimed.size()])

	# And the size wanders without ever being nothing.
	var least: float = 9999.0
	var most: float = 0.0
	for sprite: Sprite2D in aimed:
		least = minf(least, sprite.scale.x)
		most = maxf(most, sprite.scale.x)
	_check(least > 0.0, "a forged sheet was drawn at no size at all")
	_check(most > least, "the size never wandered across 16 plays")
	_check(most / maxf(least, 0.0001) < 1.0 + 3.0 * Vfx.FORGE_SIZE_JITTER,
		"the size wandered further than the jitter allows (%.2f to %.2f)" % [least, most])

	Vfx.world = before
	_stage()
	await get_tree().process_frame


func _test_the_forge_is_where_it_says() -> void:
	var here: String = ProjectSettings.globalize_path("res://")
	var root: String = here.path_join("..").path_join("tools").path_join("vfx_forge")
	_check(FileAccess.file_exists(root.path_join("forge.py")),
		"the forge's command line is not at tools/vfx_forge (looked in %s)" % root)
	_check(FileAccess.file_exists(root.path_join("render.py")),
		"the forge's renderer is not at tools/vfx_forge")
	_check(FileAccess.file_exists(root.path_join("forge_kit.py")),
		"the forge's shared vocabulary is not at tools/vfx_forge")
	# **An effect is a file.** Working rule 3 applied to art: the catalogue
	# and the folder must be the same list, or one of them is a lie.
	var missing: PackedStringArray = []
	for key: Variant in Vfx.FORGE_CATALOGUE:
		var source: String = root.path_join("effects").path_join("%s.py" % String(key))
		if not FileAccess.file_exists(source):
			missing.append(String(key))
	_check(missing.is_empty(),
		"%d effect(s) can be played and cannot be re-rendered, having no file in effects/: %s"
			% [missing.size(), ", ".join(missing)])
