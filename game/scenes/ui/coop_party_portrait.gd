class_name CoopPartyPortrait
extends PanelContainer

## One occupied seat in the matchmaking lobby.
##
## The battlefield and the lobby share the same authored hero sheet, south
## facing, and the same canonical party colour. This keeps the person somebody
## sees arrive in the lobby visually identical to the Warden they follow once
## the run begins. The component owns only presentation; the roster remains
## entirely inside CoopParty.

const IDLE_SHEET_PATH: String = "res://art/hero/hero_idle.png"
const CELL_SIZE: Vector2i = Vector2i(168, 160)
const SOUTH_DIRECTION: int = 2

var _atlas: AtlasTexture = null
var _portrait: TextureRect = null
var _name_label: Label = null
var _colour_label: Label = null
var _frame: int = 0
var _frame_count: int = 1
var _elapsed: float = 0.0
var _built: bool = false


func configure(slot: int, player_name: String, colour: Color,
		colour_name: String, is_local: bool) -> void:
	_ensure_built()
	_frame = posmod((slot - 1) * 2, _frame_count)
	_name_label.text = "%s%s" % [player_name, "  ·  you" if is_local else ""]
	_colour_label.text = "%d  ·  %s Warden" % [slot, colour_name]
	_name_label.add_theme_color_override("font_color", colour.lightened(0.18))
	_colour_label.add_theme_color_override("font_color", colour)
	_portrait.modulate = Color.WHITE.lerp(colour, Balance.PARTY_TINT_STRENGTH)

	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.025, 0.035, 0.04, 0.96)
	card.border_color = Color(colour.r, colour.g, colour.b, 0.88)
	card.set_border_width_all(2)
	card.set_corner_radius_all(9)
	card.content_margin_left = 6.0
	card.content_margin_top = 6.0
	card.content_margin_right = 6.0
	card.content_margin_bottom = 7.0
	add_theme_stylebox_override("panel", card)
	_update_region()


func _ready() -> void:
	_ensure_built()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _atlas == null or _frame_count <= 1:
		return
	_elapsed += delta
	var frame_time: float = 1.0 / Balance.COOP_LOBBY_IDLE_FPS
	if _elapsed < frame_time:
		return
	var advanced: int = int(floor(_elapsed / frame_time))
	_elapsed -= float(advanced) * frame_time
	_frame = posmod(_frame + advanced, _frame_count)
	_update_region()


func frame_region() -> Rect2:
	return _atlas.region if _atlas != null else Rect2()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Balance.COOP_LOBBY_CARD_SIZE

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Balance.COOP_LOBBY_HERO_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	column.add_child(_portrait)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_name_label)

	_colour_label = Label.new()
	_colour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_colour_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_colour_label)

	if ResourceLoader.exists(IDLE_SHEET_PATH):
		var sheet := load(IDLE_SHEET_PATH) as Texture2D
		if sheet != null:
			_frame_count = maxi(int(sheet.get_width()) / CELL_SIZE.x, 1)
			_atlas = AtlasTexture.new()
			_atlas.atlas = sheet
			_portrait.texture = _atlas
	_update_region()


func _update_region() -> void:
	if _atlas == null:
		return
	_atlas.region = Rect2(
		float(_frame * CELL_SIZE.x), float(SOUTH_DIRECTION * CELL_SIZE.y),
		float(CELL_SIZE.x), float(CELL_SIZE.y))
