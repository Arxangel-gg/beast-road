class_name IconKit
extends RefCounted

## UI icons, by id, cached.
##
## Same convention as everything else in the project: the id *is* the path. An
## icon called "resource" is `res://art/icons/ui/ui_resource.png` and nothing
## anywhere holds a second copy of that fact.
##
## A missing icon returns null rather than erroring, and every helper here copes
## with null by simply not adding the icon. The production manifest is now
## complete, but keeping this fallback makes content updates fail gracefully
## instead of taking the whole interface down with one missing file.

const UI_DIR: String = "res://art/icons/ui/"

## Cached so a build panel rebuilt on every click does not reload eight textures
## each time.
static var _cache: Dictionary = {}


## The icon for one of the five attributes.
##
## Owner, 2026-09-18: *"All stats need appropriate icons sized perfectly for
## everywhere appropriately for where they are to be referenced in UIs."*
##
## **One function, so every screen draws the same mark for Might.** The name
## is derived from `RunState.ATTRIBUTE_NAMES` rather than from a table here -
## a sixth attribute would otherwise need remembering twice, which is how the
## discipline names ended up in three screens at once.
static func attribute(which: int) -> Texture2D:
	if which < 0 or which >= RunState.ATTRIBUTE_NAMES.size():
		return null
	return ui("attr_%s" % RunState.ATTRIBUTE_NAMES[which].to_lower())


## The same icon at a size, for a row that has to line up with its neighbours.
static func attribute_sized(which: int, pixels: int) -> Texture2D:
	if which < 0 or which >= RunState.ATTRIBUTE_NAMES.size():
		return null
	return sized("attr_%s" % RunState.ATTRIBUTE_NAMES[which].to_lower(),
		pixels)


static func ui(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var path: String = "%sui_%s.png" % [UI_DIR, id]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[id] = texture
	return texture


## The icon for a tower element, so the build panel never needs a match on the
## enum. TowerData.Element order is FIRE, WATER, EARTH, AIR.
static func element(which: int) -> Texture2D:
	return ui(element_id(which))


static func element_sized(which: int, pixels: int) -> Texture2D:
	return sized(element_id(which), pixels)


static func element_id(which: int) -> String:
	var names: Array[String] = ["element_fire", "element_water", "element_earth", "element_air"]
	return names[clampi(which, 0, names.size() - 1)]


## A square icon at a given height. `TextureRect` rather than `Sprite2D` because
## everything it goes into is a Control and mixing the two is how you get things
## that do not lay out.
static func rect(id: String, size: float, tint: Color = Color.WHITE) -> TextureRect:
	var texture: Texture2D = ui(id)
	if texture == null:
		return null
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# **Its own square, whatever row it sits in** (2026-09-21). A box child
	# fills the box's height by default, so a 34px mark in a row made 62 tall
	# by the pools column owned a 34x62 rect - drawn centred and invisible, but
	# reaching 16px under the boss line, which `layout_check` refused at 4K on
	# the runs where the weather label happened to carry its temperature and
	# shove the currency rows under it. The picture never stretched; the rect
	# did, and the rect is what a layout collides with.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = tint
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## An icon followed by a label, as one row. Returns the row so the caller can put
## it in a bar; the label is reachable through `label_of` for live updates.
static func labelled(id: String, text: String, font_size: int = 18,
		icon_size: float = 26.0, tint: Color = Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon: TextureRect = rect(id, icon_size, tint)
	if icon != null:
		row.add_child(icon)

	var label := Label.new()
	label.name = "Value"
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


## Re-cuts a `labelled` row's mark at a new size.
##
## The mark is baked at build time from the 128px source, and the top bar is
## built once - so when the touch layout arrives afterwards `UiMetrics` grows the
## number beside it and the mark stays whatever it was. A 24px icon next to
## 28px type is the readout looking half-finished, which is what it looked like.
static func resize_labelled(row: Node, id: String, icon_size: float) -> void:
	var icon := row.get_child(0) as TextureRect if row.get_child_count() > 0 \
		else null
	if icon == null:
		return
	icon.texture = sized(id, int(icon_size))
	icon.custom_minimum_size = Vector2(icon_size, icon_size)


## The label inside a `labelled` row. Named lookup rather than index, so adding
## anything to the row later cannot silently retarget every text update.
static func label_of(row: Node) -> Label:
	return row.get_node_or_null("Value") as Label


## The icon resampled to an exact pixel size, cached per size.
##
## Button icons are drawn at the texture's natural size, and these are 128px —
## far taller than a 42px button, so Godot simply did not show them. The obvious
## fixes are both unreliable: `expand_icon` sizes against the button's rect,
## which is itself derived from the icon, and `icon_max_width` is a theme
## constant that has to be overridden on the right type to take effect.
##
## Handing Button a texture that is already the right size sidesteps all of it.
static func sized(id: String, pixels: int) -> Texture2D:
	var key: String = "%s@%d" % [id, pixels]
	if _cache.has(key):
		return _cache[key]

	var source: Texture2D = ui(id)
	if source == null:
		_cache[key] = null
		return null

	var image: Image = source.get_image()
	if image == null:
		_cache[key] = source
		return source
	image = image.duplicate() as Image
	image.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
	var scaled: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = scaled
	return scaled


## Puts an icon on a Button. Godot draws button icons left of the text already;
## this only exists so the size is right and a missing icon is a no-op.
## Marks a button as a tile: its icon sits above its word. See `on_button`.
const ICON_ON_TOP: StringName = &"icon_on_top"
## What `on_button` last put on a button and at what size, so a button can be
## re-dressed as a tile and back without its owner remembering either.
const ICON_ID: StringName = &"icon_id"
const ICON_SIZE: StringName = &"icon_size"
## A tile's mark. A tile is the size of an ability slot, and a 24px mark on it
## read as a speck above a word.
const TILE_ICON_SIZE: int = 40


## **A painting as a mark** (2026-09-25): a tower's or a trap's own art, cropped
## to what is drawn and set on a square of `pixels`, feet on the square's foot.
## The build sheets marked every row with its element's glyph, so ten fire
## towers were ten identical flames and a player chose by name alone. Cached by
## path and size, so a sheet rebuilt on every purchase costs one resize a row
## for the life of the process. Null when there is no painting to show.
static func art(path: String, pixels: int) -> Texture2D:
	var key: String = "art:%s@%d" % [path, pixels]
	if _cache.has(key):
		return _cache[key]
	var out: Texture2D = null
	var source: Texture2D = load(path) as Texture2D \
		if not path.is_empty() and ResourceLoader.exists(path) else null
	var image: Image = source.get_image() if source != null else null
	if image != null:
		image = image.duplicate() as Image
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var used: Rect2i = image.get_used_rect()
		if used.has_area():
			image = image.get_region(used)
			var side: int = maxi(image.get_width(), image.get_height())
			var square: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
			square.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()),
				Vector2i((side - image.get_width()) / 2, side - image.get_height()))
			square.resize(pixels, pixels, Image.INTERPOLATE_LANCZOS)
			out = ImageTexture.create_from_image(square)
	_cache[key] = out
	return out


## Puts back whatever mark `on_button` last gave a button - after it has been
## made a tile or unmade one, which changes the mark's size and where it sits.
static func redress(button: Button) -> void:
	if button.has_meta(ICON_ID):
		on_button(button, String(button.get_meta(ICON_ID)),
			int(button.get_meta(ICON_SIZE, 24)))


static func on_button(button: Button, id: String, size: int = 24) -> void:
	button.set_meta(ICON_ID, id)
	button.set_meta(ICON_SIZE, size)
	var pixels: int = maxi(size, TILE_ICON_SIZE) if button.has_meta(ICON_ON_TOP) else size
	var texture: Texture2D = sized(id, pixels)
	if texture == null:
		return
	button.icon = texture
	# **A tile keeps its mark on top** (2026-09-25): the landscape phone's action
	# row is a line of square tiles, icon above word, and a button whose icon is
	# swapped mid-run - Build to Fight, Heal to Ration - must not fall back to
	# the row layout below.
	if button.has_meta(ICON_ON_TOP):
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		return
	# Godot centres text and icon together by default, which reads as ragged in a
	# column of buttons. Left-aligned puts every icon on the same vertical line.
	#
	# **Unless there is no text.** A square button carrying only a mark has no
	# column to line up with - the mark *is* the button - and left-aligning it
	# parks it against one edge with a gap on the other. `alignment` positions
	# the icon and label as a group; `icon_alignment` positions the icon inside
	# that, and it defaults to LEFT, so centring the group alone left the icon
	# where it was. Both are needed.
	if button.text.strip_edges().is_empty():
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		return
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
