extends Node

## Release contract for the reward silhouettes the player reads on the road.
##
## Currency pickups used to fall back to 128px HUD illustrations, scaled into a
## 26px world slot. They were technically visible but belonged to a different
## context and could not be judged as a family. This gate proves that every run
## currency resolves through LootDrop's real convention, that ordinary and
## premium raid caches choose different art, and that no two reward types are a
## duplicated file wearing a different name.

const CURRENCY_IDS: Array[String] = ["wood", "food", "gold", "stone"]
const REWARD_IDS: Array[String] = ["supplies", "relic"]
const FRAME_SIZE: Vector2i = Vector2i(48, 48)

var _failures: int = 0
var _signatures: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	for reward_id: String in CURRENCY_IDS + REWARD_IDS:
		_check_art(reward_id)
	for currency: String in CURRENCY_IDS:
		_check_runtime_currency(currency)

	var supply := RaidChest.new()
	var premium := RaidChest.new()
	premium.locked = true
	_check(supply.art_path() == Balance.LOOT_ART_FORMAT % "supplies",
		"ordinary raid cache must use the supply silhouette")
	_check(premium.art_path() == Balance.LOOT_ART_FORMAT % "relic",
		"locked raid cache must use the relic silhouette")
	_check(supply.art_path() != premium.art_path(),
		"ordinary and locked raid caches must not look identical")
	supply.free()
	premium.free()

	if _failures == 0:
		print("[loot-art] PASS — 4 currency pickups and 2 distinct cache types")
	else:
		push_error("[loot-art] FAIL — %d problem(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check_art(reward_id: String) -> void:
	var path: String = Balance.LOOT_ART_FORMAT % reward_id
	if not ResourceLoader.exists(path):
		_fail("%s has no world art at %s" % [reward_id, path])
		return
	var texture := load(path) as Texture2D
	var image: Image = texture.get_image() if texture != null else null
	if image == null:
		_fail("%s cannot be read" % path)
		return
	var size := Vector2i(image.get_width(), image.get_height())
	_check(size == FRAME_SIZE, "%s is %s; expected %s" % [path, size, FRAME_SIZE])

	var visible_pixels: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				visible_pixels += 1
	_check(visible_pixels >= 36, "%s is empty or too sparse to read" % path)

	var signature: int = hash(image.get_data())
	if _signatures.has(signature):
		_fail("%s duplicates %s" % [path, _signatures[signature]])
	else:
		_signatures[signature] = path


func _check_runtime_currency(currency: String) -> void:
	var drop := LootDrop.new()
	drop.setup(currency, 1, Vector2.ZERO)
	add_child(drop)
	var sprite := drop.get("_sprite") as Sprite2D
	var path: String = sprite.texture.resource_path if sprite != null \
		and sprite.texture != null else ""
	_check(path == Balance.LOOT_ART_FORMAT % currency,
		"%s runtime pickup resolved %s" % [currency, path if not path.is_empty() else "no art"])
	drop.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	push_error("[loot-art] %s" % message)
