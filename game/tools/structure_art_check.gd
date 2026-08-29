extends Node

## Production contract for PixelLab structure packages.
##
## The runtime falls back deliberately; this gate does not. A release has every
## tower loop and every building tier loop, each on the exact 192px canvas with
## a stable ground anchor. It catches the visually expensive failures that a
## generic asset-exists scan cannot: a missing middle pose, a tier silently
## borrowing tier one, or a generated frame hopping sideways on its canvas.

const FRAME_SIZE: Vector2i = Vector2i(192, 192)
const CONTINUATION_FRAMES: int = 3
const ANCHOR_TOLERANCE: int = 2
const WIDTH_DRIFT_FRACTION: float = 0.20
const CITY_FRAME_SIZE: Vector2i = Vector2i(512, 512)
const CITY_IDLE_FRAMES: int = 4
const CITY_ANCHOR_TOLERANCE: int = 8

var _failures: int = 0
var _packages: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var towers: Array[TowerData] = []
	for value: Variant in ContentDB.towers.values():
		var tower := value as TowerData
		if tower != null:
			towers.append(tower)
	towers.sort_custom(func(a: TowerData, b: TowerData) -> bool: return a.id < b.id)
	for tower: TowerData in towers:
		_check_package(tower.get_sprite_path(), "tower %s" % tower.id)
	for building: BuildingData in ContentDB.buildings_sorted():
		for tier: int in range(1, building.max_tier + 1):
			var exact_path: String = building.get_tier_sprite_path(tier)
			if building.get_sprite_path_for_tier(tier) != exact_path:
				_fail("building %s tier %d fell back from %s"
					% [building.id, tier, exact_path])
			_check_package(exact_path,
				"building %s tier %d" % [building.id, tier])
	for city_name: String in ["city_base", "city_damage_1", "city_damage_2",
			"city_damage_3"]:
		_check_city_package("res://art/city/%s.png" % city_name,
			"city stage %s" % city_name)
	if _failures == 0:
		print("[structure-art] PASS — %d complete animated structure packages" % _packages)
	else:
		push_error("[structure-art] FAIL — %d problem(s) across %d packages"
			% [_failures, _packages])
	get_tree().quit(0 if _failures == 0 else 1)


func _check_package(base_path: String, label: String) -> void:
	_packages += 1
	var runtime_frames: Array[Texture2D] = GameData.load_idle_frames(base_path)
	if runtime_frames.size() != CONTINUATION_FRAMES + 1:
		_fail("%s runtime loaded %d poses; expected %d"
			% [label, runtime_frames.size(), CONTINUATION_FRAMES + 1])
	var paths: Array[String] = [base_path]
	for index: int in range(1, CONTINUATION_FRAMES + 1):
		paths.append(GameData.idle_frame_path(base_path, index))
	var images: Array[Image] = []
	for path: String in paths:
		if not ResourceLoader.exists(path):
			_fail("%s is missing %s" % [label, path])
			return
		var texture := load(path) as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		if image == null:
			_fail("%s cannot read %s" % [label, path])
			return
		if Vector2i(image.get_width(), image.get_height()) != FRAME_SIZE:
			_fail("%s has %dx%d frame %s; expected %s"
				% [label, image.get_width(), image.get_height(), path, FRAME_SIZE])
			return
		images.append(image)

	var base_bounds: Rect2i = _alpha_bounds(images[0])
	if not base_bounds.has_area():
		_fail("%s base is fully transparent" % label)
		return
	for index: int in range(1, images.size()):
		var bounds: Rect2i = _alpha_bounds(images[index])
		if not bounds.has_area():
			_fail("%s frame %d is fully transparent" % [label, index])
			continue
		var base_foot: Vector2i = Vector2i(base_bounds.get_center().x, base_bounds.end.y)
		var frame_foot: Vector2i = Vector2i(bounds.get_center().x, bounds.end.y)
		if abs(base_foot.x - frame_foot.x) > ANCHOR_TOLERANCE \
				or abs(base_foot.y - frame_foot.y) > ANCHOR_TOLERANCE:
			_fail("%s frame %d moved its ground anchor from %s to %s"
				% [label, index, base_foot, frame_foot])
		var width_drift: float = absf(float(bounds.size.x - base_bounds.size.x)) \
			/ maxf(float(base_bounds.size.x), 1.0)
		if width_drift > WIDTH_DRIFT_FRACTION:
			_fail("%s frame %d changed silhouette width by %.1f%%"
				% [label, index, width_drift * 100.0])


## The defended city uses four dedicated idle frames per damage state. They are
## larger than ordinary structures, so keep its canvas/anchor contract explicit
## instead of weakening the tighter 192px package gate above.
func _check_city_package(base_path: String, label: String) -> void:
	_packages += 1
	var runtime_frames: Array[Texture2D] = GameData.load_idle_frames(base_path)
	if runtime_frames.size() != CITY_IDLE_FRAMES + 1:
		_fail("%s runtime loaded %d poses; expected base plus %d idle frames"
			% [label, runtime_frames.size(), CITY_IDLE_FRAMES])
	var paths: Array[String] = [base_path]
	for index: int in range(1, CITY_IDLE_FRAMES + 1):
		paths.append(GameData.idle_frame_path(base_path, index))
	var images: Array[Image] = []
	for path: String in paths:
		if not ResourceLoader.exists(path):
			_fail("%s is missing %s" % [label, path])
			return
		var texture := load(path) as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		if image == null:
			_fail("%s cannot read %s" % [label, path])
			return
		if Vector2i(image.get_width(), image.get_height()) != CITY_FRAME_SIZE:
			_fail("%s has %dx%d frame %s; expected %s"
				% [label, image.get_width(), image.get_height(), path,
				CITY_FRAME_SIZE])
			return
		images.append(image)

	var base_bounds: Rect2i = _alpha_bounds(images[0])
	if not base_bounds.has_area():
		_fail("%s base is fully transparent" % label)
		return
	var base_foot := Vector2i(base_bounds.get_center().x, base_bounds.end.y)
	for index: int in range(1, images.size()):
		var bounds: Rect2i = _alpha_bounds(images[index])
		if not bounds.has_area():
			_fail("%s idle frame %d is fully transparent" % [label, index])
			continue
		var frame_foot := Vector2i(bounds.get_center().x, bounds.end.y)
		if abs(base_foot.x - frame_foot.x) > CITY_ANCHOR_TOLERANCE \
				or abs(base_foot.y - frame_foot.y) > CITY_ANCHOR_TOLERANCE:
			_fail("%s idle frame %d moved its ground anchor from %s to %s"
				% [label, index, base_foot, frame_foot])
		var width_drift: float = absf(float(bounds.size.x - base_bounds.size.x)) \
			/ maxf(float(base_bounds.size.x), 1.0)
		if width_drift > WIDTH_DRIFT_FRACTION:
			_fail("%s idle frame %d changed silhouette width by %.1f%%"
				% [label, index, width_drift * 100.0])


func _alpha_bounds(image: Image) -> Rect2i:
	var left: int = image.get_width()
	var top: int = image.get_height()
	var right: int = -1
	var bottom: int = -1
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a <= 0.01:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return Rect2i()
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


func _fail(message: String) -> void:
	_failures += 1
	push_error("[structure-art] %s" % message)
