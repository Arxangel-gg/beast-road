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
static func on_button(button: Button, id: String, size: int = 24) -> void:
	var texture: Texture2D = sized(id, size)
	if texture == null:
		return
	button.icon = texture
	# Godot centres text and icon together by default, which reads as ragged in a
	# column of buttons. Left-aligned puts every icon on the same vertical line.
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
