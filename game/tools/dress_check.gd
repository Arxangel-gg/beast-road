extends Node

## The modular Warden's data (owner rulings, 2026-09-25): every piece of gear
## says how it is worn, every weapon has a picture and a grip, and the dress
## resolves to something drawable whatever is worn.
##
## - **Every class is one the drawing knows.** An armour names light, medium or
##   heavy; a helmet one of four head dressings; a cape a shape and a colour. A
##   misspelt class is not an error anywhere else - it falls back and draws the
##   linen - so it is refused here, by name.
## - **Every weapon is held.** A picture on disk, a grip found on the handle
##   (an opaque pixel, below the blade's top), and a length on the body that
##   comes from its reach: a knife is shorter than a sword and a glaive longer.
## - **The grip picks the drawn combo and nothing else.** A two-handed weapon
##   draws the two-handed steps; a one-handed or paired one draws its own.
## - **Nothing drawable is missing.** Until the base body is on disk the dress
##   is unavailable and the painted Warden plays; once it is, every state has a
##   sheet and a socket table of the right shape.
## - **What is under the body is under it.** Judged by the holder a part hangs
##   from among the body sprite's own children, which is how Godot orders them,
##   and never by the part's own flag - the first cut flagged the back of the
##   cape as behind and drew it over the Warden.
## - **The fist closes over the handle** (owner, 2026-09-25). A fist's width of
##   handle round each gripping fist goes under the body, never past the hilt,
##   drawn where the fist is; the guard and the blade stay over it.

const STATES: Array[String] = [
	"idle", "walk", "sprint", "dash", "hurt", "death", "shoot",
	"attack_1a", "attack_1b", "attack_2", "attack_3",
	"attack_2h_1", "attack_2h_2", "attack_2h_3", "attack_2h_4",
]

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	WardenDress.forget()
	_test_every_class_is_known()
	_test_every_weapon_is_held()
	_test_length_follows_reach()
	_test_grip_picks_the_combo()
	_test_the_outfit_resolves()
	_test_drawn_bodies_are_whole()
	await _test_the_runtime_lays_every_part()
	await _test_the_fist_closes_over_the_handle()
	for name: String in ["classes", "held", "length", "combo", "outfit", "bodies", "runtime", "fist"]:
		_check(_reached.has(name), "'%s' never reached its end - a runtime error stopped it" % name)
	for _frame: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("[dress] PASS - %d checks: every class known, every weapon held and sized by its class, the grip picks the combo, the dress resolves, the fist closes over the handle" % _checks)
	else:
		push_error("[dress] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[dress] FAIL: %s" % why)


func _gear() -> Array[GearData]:
	var out: Array[GearData] = []
	var ids: Array = ContentDB.gear_kinds.keys()
	ids.sort()
	for id: Variant in ids:
		out.append(ContentDB.gear(String(id)))
	return out


func _test_every_class_is_known() -> void:
	var seen: Dictionary = {}
	for kind: GearData in _gear():
		seen[kind.slot] = int(seen.get(kind.slot, 0)) + 1
		match kind.slot:
			GearData.Slot.ARMOUR:
				_check(WardenDress.ARMOUR_CLASSES.has(kind.look),
					"%s is armour of class '%s', which the drawing does not know" % [kind.id, kind.look])
			GearData.Slot.HELMET:
				_check(WardenDress.HELMET_CLASSES.has(kind.look),
					"%s is a helmet of class '%s', which the drawing does not know" % [kind.id, kind.look])
			GearData.Slot.CAPE:
				_check(WardenDress.CAPE_SHAPES.has(kind.look),
					"%s is a cape of shape '%s', which the drawing does not know" % [kind.id, kind.look])
				_check(is_equal_approx(kind.look_tint.a, 1.0),
					"%s is a cape with no colour of its own" % kind.id)
			GearData.Slot.WEAPON:
				_check(WardenDress.WEAPON_CLASSES.has(kind.look),
					"%s is a weapon of class '%s', which has no drawn length" % [kind.id, kind.look])
			_:
				_check(kind.look.is_empty(),
					"%s names a look class '%s' in a slot that is not drawn on the body" % [kind.id, kind.look])
		if kind.slot != GearData.Slot.WEAPON:
			_check(kind.grip == GearData.Grip.ONE_HAND,
				"%s is not a weapon and names a grip" % kind.id)
	_check(int(seen.get(GearData.Slot.CAPE, 0)) >= 4, "there are fewer than four capes")
	_reached.append("classes")


func _test_every_weapon_is_held() -> void:
	for kind: GearData in _gear():
		if kind.slot != GearData.Slot.WEAPON:
			continue
		var path: String = WardenDress.held_path(kind)
		_check(not path.is_empty(), "%s has no held picture at %s" % [kind.id, WardenDress.HELD_DIR])
		var grip: Dictionary = WardenDress.held_grip(kind)
		_check(not grip.is_empty(), "%s has no grip in held.json" % kind.id)
		if path.is_empty() or grip.is_empty():
			continue
		var image: Image = (load(path) as Texture2D).get_image()
		var at: Vector2 = grip["grip"]
		_check(Rect2(Vector2.ZERO, Vector2(image.get_size())).has_point(at),
			"%s's grip %s is off its picture" % [kind.id, at])
		if Rect2(Vector2.ZERO, Vector2(image.get_size())).has_point(at):
			_check(image.get_pixelv(Vector2i(at)).a > 0.3,
				"%s's grip %s is on nothing - the fist would close on air" % [kind.id, at])
		_check(float(grip["tip"]) < at.y - 20.0,
			"%s's blade top %.0f is not well above its grip %.0f" % [kind.id, grip["tip"], at.y])
		# The handle a fist may hide: round the grip, below the blade's top, on
		# the picture. A hilt that reached the tip would let a foreshortened
		# fist hide the whole blade.
		var hilt: Vector2 = grip.get("hilt", Vector2.ZERO)
		_check(hilt.x <= at.y and at.y <= hilt.y,
			"%s's grip row %.0f is not on its hilt %s" % [kind.id, at.y, hilt])
		_check(hilt.x > float(grip["tip"]) + 1.0 and hilt.y < float(image.get_height()),
			"%s's hilt %s reaches past its picture or to its tip %.0f" % [kind.id, hilt, grip["tip"]])
		_check(hilt.y > hilt.x, "%s's hilt %s is no handle at all" % [kind.id, hilt])
	_reached.append("held")


func _test_length_follows_reach() -> void:
	var knife: GearData = ContentDB.gear("tally_knife")
	var sword: GearData = ContentDB.gear("coalpaint_edge")
	var glaive: GearData = ContentDB.gear("ashfall_glaive")
	_check(knife != null and sword != null and glaive != null, "the reference weapons are missing")
	if knife != null and sword != null and glaive != null:
		_check(WardenDress.held_length(knife) < WardenDress.held_length(sword),
			"a knife is drawn no shorter than a sword")
		_check(WardenDress.held_length(glaive) > WardenDress.held_length(sword),
			"a glaive is drawn no longer than a sword")
	for kind: GearData in _gear():
		if kind.slot != GearData.Slot.WEAPON:
			continue
		var length: float = WardenDress.held_length(kind)
		_check(length > 0.18 and length < 0.95,
			"%s is drawn %.2f figures long - off the body's scale" % [kind.id, length])
	_reached.append("length")


func _test_grip_picks_the_combo() -> void:
	var two: GearData = ContentDB.gear("gravebell_maul")
	var one: GearData = ContentDB.gear("coalpaint_edge")
	var pair: GearData = ContentDB.gear("twinfang_dirks")
	_check(two != null and two.grip == GearData.Grip.TWO_HAND, "the maul is not held in two hands")
	_check(pair != null and pair.grip == GearData.Grip.PAIRED, "the dirks are not a pair")
	for state: String in WardenDress.TWO_HANDED_STATES:
		_check(WardenDress.state_for(state, two) == WardenDress.TWO_HANDED_STATES[state],
			"a two-handed weapon does not draw the two-handed %s" % state)
		_check(WardenDress.state_for(state, one) == state,
			"a one-handed weapon draws something other than its own %s" % state)
		_check(WardenDress.state_for(state, pair) == state,
			"a pair draws something other than the one-handed %s" % state)
	_check(WardenDress.state_for("walk", two) == "walk", "the grip changed a state that is not an attack")
	_reached.append("combo")


func _test_the_outfit_resolves() -> void:
	var cape: GearData = ContentDB.gear("roadwardens_mantle")
	var armour: GearData = ContentDB.gear("reaver_plate")
	var weapon: GearData = ContentDB.gear("coalpaint_edge")
	var helmet: GearData = ContentDB.gear("huntsman_hood")
	for body: int in WardenDress.BODIES.size():
		var outfit: Dictionary = WardenDress.outfit({"body": body}, weapon, armour, cape, helmet)
		var name: String = WardenDress.BODIES[body]
		_check(outfit["body"] == name, "look body %d did not resolve to %s" % [body, name])
		_check(String(outfit["body_layer"]).begins_with(name + "_"),
			"%s's body layer '%s' is not theirs" % [name, outfit["body_layer"]])
		_check(outfit["helmet"] == "hood", "the hood did not resolve as a hood")
		_check(not String(outfit["held"]).is_empty(), "the starting weapon has no held picture")
	# A look that is nonsense still draws somebody.
	var odd: Dictionary = WardenDress.outfit({"body": 99}, null, null, null, null)
	_check(WardenDress.BODIES.has(odd["body"]), "an out-of-range body drew nobody")
	_check(String(odd["cape_layer"]).is_empty(), "no cape drew a cape")
	_reached.append("outfit")


func _test_drawn_bodies_are_whole() -> void:
	for body: String in WardenDress.BODIES:
		if not WardenDress.available(body):
			print("[dress] %s has no dress art yet; the painted Warden plays" % body)
			continue
		for state: String in STATES:
			var meta: Dictionary = WardenDress.meta(body, state)
			_check(not meta.is_empty(), "%s has no %s metadata" % [body, state])
			if meta.is_empty():
				continue
			var sheet_path: String = WardenDress.DRESS_DIR + body + "_base/" + state + ".png"
			_check(ResourceLoader.exists(sheet_path), "%s has no %s sheet" % [body, state])
			var frames: int = int(meta.get("frames", 0))
			var cell: Array = meta.get("cell", [0, 0])
			if ResourceLoader.exists(sheet_path):
				var sheet: Texture2D = load(sheet_path) as Texture2D
				_check(sheet.get_width() == int(cell[0]) * frames and sheet.get_height() == int(cell[1]) * 8,
					"%s %s sheet is %dx%d for %d frames of %s" % [body, state, sheet.get_width(),
						sheet.get_height(), frames, cell])
			var sockets: Dictionary = meta.get("sockets", {})
			_check(sockets.size() == 8, "%s %s has sockets for %d facings" % [body, state, sockets.size()])
			_check(float(meta.get("fist", 0.0)) > 0.0,
				"%s %s carries no fist size, so no weapon closes in a fist" % [body, state])
			for facing: Variant in sockets:
				_check((sockets[facing] as Array).size() == frames,
					"%s %s %s has %d socket rows for %d frames" % [body, state, facing,
						(sockets[facing] as Array).size(), frames])
	_reached.append("bodies")


# --- The runtime, through its real doors ---------------------------------------

const TEST_ROOT: String = "user://dress_test/"
const TEST_CELL: Vector2i = Vector2i(40, 60)
const TEST_ORIGIN: Vector2 = Vector2(80.0, 110.0)
const TEST_FOOT: Vector2 = Vector2(100.0, 170.0)
## Half a fist in the synthetic dress, in the cell's pixels.
const TEST_FIST: float = 5.55


## A socket the gate can predict: every number differs by state, frame and row,
## so a layer read from the wrong one is caught.
func _test_socket(state_index: int, frame: int, row: int) -> Array:
	var right: Array = [10.0 + frame, 20.0 + row, 30.0 * frame + 5.0 * state_index, 0.5 + 0.05 * frame,
		(frame + row) % 2]
	var left: Array = [30.0 - frame, 25.0 + row, 200.0 - 20.0 * frame, 0.6, (frame + row + 1) % 2]
	return right + left + [20.0, 8.0, row]


## Where a part is drawn against the body, the way Godot decides it: by the
## holder it hangs from among the body sprite's own children. A part's own
## `show_behind_parent` orders it only against its holder, so reading the flag
## off the part - which is what this gate did at first - passes a cape drawn
## over the body. Returns "under", "over" or why it is neither.
func _against(part: Node, body: Node) -> String:
	var node: Node = part
	while node != null and node.get_parent() != body:
		node = node.get_parent()
	if node == null:
		return "not on the body at all"
	return "under" if (node as CanvasItem).show_behind_parent else "over"


func _write_test_dress() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_ROOT + "art/male_base")
	DirAccess.make_dir_recursive_absolute(TEST_ROOT + "art/male_cape_long")
	DirAccess.make_dir_recursive_absolute(TEST_ROOT + "meta/male")
	for index: int in STATES.size():
		var state: String = STATES[index]
		var frames: int = 7 if state.begins_with("attack") else 8
		var sheet := Image.create(TEST_CELL.x * frames, TEST_CELL.y * 8, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.8, 0.7, 0.6, 1.0))
		sheet.save_png(TEST_ROOT + "art/male_base/%s.png" % state)
		sheet.fill(Color(0.5, 0.5, 0.5, 1.0))
		sheet.save_png(TEST_ROOT + "art/male_cape_long/%s.png" % state)
		var sockets: Dictionary = {}
		var feet: Dictionary = {}
		for row: int in 8:
			var rows: Array = []
			for frame: int in frames:
				rows.append(_test_socket(index, frame, row))
			sockets[HeroAnimator.FACING_NAMES[row]] = rows
			feet[HeroAnimator.FACING_NAMES[row]] = [TEST_FOOT.x + row, TEST_FOOT.y]
		var meta: Dictionary = {"cell": [TEST_CELL.x, TEST_CELL.y], "origin": [TEST_ORIGIN.x, TEST_ORIGIN.y],
			"canvas": [208, 208], "frames": frames, "loop": not state.begins_with("attack"),
			"foot": feet, "stature": 150.0, "fist": TEST_FIST, "sockets": sockets}
		var file := FileAccess.open(TEST_ROOT + "meta/male/%s.json" % state, FileAccess.WRITE)
		file.store_string(JSON.stringify(meta))
		file.close()


func _test_the_runtime_lays_every_part() -> void:
	_write_test_dress()
	var saved: Array = [WardenDress.art_root, WardenDress.meta_root]
	WardenDress.art_root = TEST_ROOT + "art/"
	WardenDress.meta_root = TEST_ROOT + "meta/"
	WardenDress.forget()
	_check(WardenDress.available("male"), "the synthetic dress is not found through the seam")

	var sprite := Sprite2D.new()
	add_child(sprite)
	var animator := HeroAnimator.new()
	animator.sprite = sprite
	add_child(animator)
	var sword: GearData = ContentDB.gear("coalpaint_edge")
	var maul: GearData = ContentDB.gear("gravebell_maul")
	var dirks: GearData = ContentDB.gear("twinfang_dirks")
	var cape: GearData = ContentDB.gear("roadwardens_mantle")

	animator.dress(WardenDress.outfit({"body": 0}, sword, null, cape, null))
	_check(animator.dressed(), "a body with dress art on disk was not dressed")
	animator.set_facing(Vector2(0.0, 1.0))
	animator.play("attack_1a", true)
	animator._process(0.0)
	var row: int = 2
	var feet := Vector2(TEST_FOOT.x + row, TEST_FOOT.y)
	var offset: Vector2 = TEST_ORIGIN - feet + Vector2(0.0, HeroAnimator.PAINTED_FEET_BELOW_CENTRE)
	_check(sprite.region_rect == Rect2(0, row * TEST_CELL.y, TEST_CELL.x, TEST_CELL.y),
		"the body drew %s, not frame 0 of the south row" % sprite.region_rect)
	_check(sprite.offset.is_equal_approx(offset),
		"the body stands at %s, not with its feet where the painted Warden's were (%s)" % [sprite.offset, offset])
	var layers: DressLayers = sprite.get_node_or_null("Dress") as DressLayers
	_check(layers != null, "no dress layers were put on the sprite")
	if layers != null:
		_check(_against(layers, sprite) == "over", "the layer over the body is %s it" % _against(layers, sprite))
		_check(_against(layers.behind, sprite) == "under",
			"the layer under the body is %s it" % _against(layers.behind, sprite))
		var socket: Array = _test_socket(STATES.find("attack_1a"), 0, row)
		var at: Vector2 = offset + Vector2(socket[0], socket[1])
		var grip: Dictionary = WardenDress.held_grip(sword)
		var pieces: Array[Sprite2D] = layers.drawn(0)
		_check(not pieces.is_empty(), "the sword is not drawn")
		# This frame's right hand is behind the chest: the whole sword is.
		_check(int(socket[4]) == 0, "the synthetic socket changed; the gate's reading of it is stale")
		_check(pieces.size() == 1, "a sword behind the body was cut into %d pieces" % pieces.size())
		for weapon: Sprite2D in pieces:
			_check(weapon.position.is_equal_approx(at),
				"the sword is at %s, not on the right fist's socket %s" % [weapon.position, at])
			_check(is_equal_approx(weapon.rotation, deg_to_rad(float(socket[2])) + PI * 0.5),
				"the sword is not turned along the socket's blade")
			_check(is_equal_approx(weapon.scale.y / weapon.scale.x, float(socket[3])),
				"the sword is not shortened by what the camera sees of it")
			_check(_against(weapon, sprite) == "under",
				"a sword whose hand is behind the chest is drawn %s the body" % _against(weapon, sprite))
			_check(weapon.offset.is_equal_approx(Vector2(-(grip["grip"] as Vector2).x,
					weapon.region_rect.position.y - (grip["grip"] as Vector2).y)),
				"the sword is not held by its grip")
			_check(is_equal_approx(weapon.region_rect.size.y, float(weapon.texture.get_height())),
				"a sword behind the body is not drawn whole")
		var cape_back: Sprite2D = layers.cape_back()
		var cape_front: Sprite2D = layers.cape_front()
		_check(cape_back.visible and not cape_front.visible,
			"a Warden facing the camera does not wear the cape behind")
		_check(_against(cape_back, sprite) == "under",
			"the cape behind a Warden facing the camera is drawn %s the body" % _against(cape_back, sprite))
		var tint := Color(cape.look_tint.r, cape.look_tint.g, cape.look_tint.b, 1.0)
		_check(cape_back.self_modulate.is_equal_approx(tint), "the cape is not dyed its kind's colour")
		animator.set_facing(Vector2(0.0, -1.0))
		animator._process(0.0)
		_check(cape_front.visible and not cape_back.visible,
			"a Warden walking away does not wear the cape over the body")
		_check(_against(cape_front, sprite) == "over",
			"the cape over a Warden walking away is drawn %s the body" % _against(cape_front, sprite))
		_check(layers.drawn(1).is_empty(), "a one-handed sword shows a second blade")

		# Two hands: the forehand draws the two-handed combo.
		animator.dress(WardenDress.outfit({"body": 0}, maul, null, null, null))
		animator.play("attack_1a", true)
		animator._process(0.0)
		_check(animator._state_drawn == "attack_2h_1", "a maul drew %s for the forehand" % animator._state_drawn)
		_check(not cape_back.visible and not cape_front.visible, "no cape drew a cape")

		# A pair: the second blade is in the left fist.
		animator.dress(WardenDress.outfit({"body": 0}, dirks, null, null, null))
		animator.play("attack_1b", true)
		animator._process(0.0)
		var pair: Array = _test_socket(STATES.find("attack_1b"), 0, 6)
		var off: Array[Sprite2D] = layers.drawn(1)
		_check(not off.is_empty(), "the second dirk is not drawn")
		for part: Sprite2D in off:
			_check(part.position.is_equal_approx(sprite.offset + Vector2(pair[5], pair[6])),
				"the second dirk is not on the left fist's socket")

		# Undressed, nothing the dress drew is left on the body, under or over.
		WardenDress.art_root = TEST_ROOT + "nothing/"
		WardenDress.forget()
		animator.dress(WardenDress.outfit({"body": 0}, sword, null, null, null))
		_check(not layers.visible and not layers.behind.visible,
			"a Warden whose dress went away still draws its layers")
		WardenDress.art_root = TEST_ROOT + "art/"
		WardenDress.forget()

	# And a body with no art is the painted Warden, untouched.
	WardenDress.art_root = TEST_ROOT + "nothing/"
	WardenDress.forget()
	var plain_sprite := Sprite2D.new()
	add_child(plain_sprite)
	var plain := HeroAnimator.new()
	plain.sprite = plain_sprite
	add_child(plain)
	plain.dress(WardenDress.outfit({"body": 0}, sword, null, null, null))
	_check(not plain.dressed(), "a body with no dress art was dressed anyway")

	WardenDress.art_root = saved[0]
	WardenDress.meta_root = saved[1]
	WardenDress.forget()
	for node: Node in [animator, sprite, plain, plain_sprite]:
		node.queue_free()
	await get_tree().process_frame
	_reached.append("runtime")


# --- The fist closes over the handle -------------------------------------------
#
# Owner, 2026-09-25: "make sure the part of the hand that grips the weapon gets
# zsorted over the blade". Driven through `show_frame`, the one door
# `HeroAnimator` lays a frame through, with sockets the gate writes itself so
# every case - a fist in front, behind, foreshortened, two on one haft, a pair -
# is a case it chose rather than one a synthetic table happened to contain.

## A socket row: the right hand, the left hand and the head.
func _grip_socket(right: Vector2, angle: float, reach: float, front: int,
		left: Vector2 = Vector2.ZERO, left_angle: float = 0.0, left_front: int = 0) -> Array:
	return [right.x, right.y, angle, reach, front, left.x, left.y, left_angle, reach, left_front, 20.0, 8.0, 2]


func _grip_meta(socket: Array, fist: float = TEST_FIST) -> Dictionary:
	var meta: Dictionary = {"cell": [TEST_CELL.x, TEST_CELL.y], "stature": 150.0, "sockets": {"south": [socket]}}
	if fist > 0.0:
		meta["fist"] = fist
	return meta


## The texture pixel `pixel` of a weapon's picture, as drawn by `part`, in the
## body sprite's own coordinates - through the node's real transform, so a
## piece whose offset or region disagreed with where it sits is caught.
func _drawn_at(part: Sprite2D, pixel: Vector2) -> Vector2:
	var local: Vector2 = part.offset + pixel - Vector2(0.0, part.region_rect.position.y)
	return part.transform * local


func _rows_of(part: Sprite2D) -> Vector2i:
	return Vector2i(int(part.region_rect.position.y), int(part.region_rect.end.y))


func _rows_text(parts: Array[Sprite2D]) -> String:
	if parts.is_empty():
		return "nothing"
	var out: PackedStringArray = []
	for part: Sprite2D in parts:
		out.append(str(_rows_of(part)))
	return ", ".join(out)


func _test_the_fist_closes_over_the_handle() -> void:
	var body := Sprite2D.new()
	add_child(body)
	var layers: DressLayers = DressLayers.attach(body)
	var sword: GearData = ContentDB.gear("coalpaint_edge")
	var maul: GearData = ContentDB.gear("gravebell_maul")
	var dirks: GearData = ContentDB.gear("twinfang_dirks")
	var sword_grip: Dictionary = WardenDress.held_grip(sword)
	var grip: Vector2 = sword_grip.get("grip", Vector2.ZERO)
	var hilt: Vector2 = sword_grip.get("hilt", Vector2.ZERO)
	_check(hilt.y > hilt.x, "the sword has no hilt in held.json")
	var offset := Vector2(-20.0, -90.0)
	var fist_at := Vector2(24.0, 30.0)

	# In front of the body, seen whole: a fist's width of handle under the body.
	layers.wear(WardenDress.outfit({"body": 0}, sword, null, null, null))
	layers.show_frame("attack_1a", 0, 2, offset, _grip_meta(_grip_socket(fist_at, -10.0, 1.0, 1)))
	var pieces: Array[Sprite2D] = layers.drawn(0)
	var height: int = pieces[0].texture.get_height() if not pieces.is_empty() else 0
	var covered: int = 0
	var under: Array[Sprite2D] = []
	for part: Sprite2D in pieces:
		var rows: Vector2i = _rows_of(part)
		_check(rows.x == covered, "the sword's picture is cut with a gap or an overlap at row %d" % covered)
		covered = rows.y
		_check(part.position == pieces[0].position and part.rotation == pieces[0].rotation
			and part.scale == pieces[0].scale, "the pieces of one sword are not laid as one")
		if _against(part, body) == "under":
			under.append(part)
		else:
			_check(_against(part, body) == "over", "a piece of the sword is %s" % _against(part, body))
	_check(covered == height, "the sword's picture is drawn to row %d of %d" % [covered, height])
	_check(under.size() == 1, "a sword in one fist hides %d stretches of itself under the body" % under.size())
	if under.size() == 1:
		var band: Vector2i = _rows_of(under[0])
		var along: float = under[0].scale.y
		_check(band.x <= int(grip.y) and int(grip.y) < band.y,
			"the stretch under the body (rows %s) is not where the fist closes (row %.0f)" % [band, grip.y])
		_check(band.x >= int(hilt.x) and band.y <= int(hilt.y) + 1,
			"the stretch under the body (rows %s) reaches past the hilt %s - a guard or a pommel under the fingers" % [band, hilt])
		var drawn_length: float = float(band.y - band.x) * along
		_check(drawn_length >= 2.0 * TEST_FIST - 0.01 and drawn_length <= 2.0 * TEST_FIST + 2.0 * along + 0.01,
			"the stretch under the fist is %.1f px of handle for a fist %.1f across" % [drawn_length, 2.0 * TEST_FIST])
		_check(_drawn_at(under[0], grip).distance_to(offset + fist_at) < 0.01,
			"the grip is drawn at %s, not in the fist at %s" % [_drawn_at(under[0], grip), offset + fist_at])
	var guard_row: int = int(hilt.x) - 1
	var blade_over: bool = false
	for part: Sprite2D in pieces:
		var rows: Vector2i = _rows_of(part)
		if rows.x <= guard_row and guard_row < rows.y:
			blade_over = _against(part, body) == "over"
	_check(blade_over, "the guard, the first row above the hilt, is not drawn over the body")

	# Foreshortened, a fist covers more of the picture, and never past the hilt.
	layers.show_frame("attack_1a", 0, 2, offset, _grip_meta(_grip_socket(fist_at, -10.0, 0.1, 1)))
	under = []
	for part: Sprite2D in layers.drawn(0):
		if _against(part, body) == "under":
			under.append(part)
	_check(under.size() == 1 and _rows_of(under[0]) == Vector2i(int(hilt.x), int(hilt.y) + 1),
		"a sword pointing at the camera hides %s under the fist, not exactly its hilt %s" % [
			_rows_text(under), hilt])

	# Behind the body, the whole sword is behind it.
	layers.show_frame("attack_1a", 0, 2, offset, _grip_meta(_grip_socket(fist_at, -10.0, 1.0, 0)))
	pieces = layers.drawn(0)
	_check(pieces.size() == 1 and _against(pieces[0], body) == "under"
		and _rows_of(pieces[0]) == Vector2i(0, height),
		"a sword behind the chest is not drawn whole behind the body")

	# A table from before fists were measured draws the weapon whole, in front.
	layers.show_frame("attack_1a", 0, 2, offset, _grip_meta(_grip_socket(fist_at, -10.0, 1.0, 1), 0.0))
	pieces = layers.drawn(0)
	_check(pieces.size() == 1 and _against(pieces[0], body) == "over",
		"a table with no fist size did not draw the sword whole over the body")

	# Two fists on one haft: a stretch under each, the second where the left
	# fist is on the haft.
	layers.wear(WardenDress.outfit({"body": 0}, maul, null, null, null))
	var maul_hilt: Vector2 = WardenDress.held_grip(maul).get("hilt", Vector2.ZERO)
	var maul_grip: Vector2 = WardenDress.held_grip(maul).get("grip", Vector2.ZERO)
	var left_at: Vector2 = fist_at + Vector2(0.0, 16.0)
	layers.show_frame("attack_2h_1", 0, 2, offset,
		_grip_meta(_grip_socket(fist_at, -90.0, 1.0, 1, left_at, -90.0, 1)))
	under = []
	for part: Sprite2D in layers.drawn(0):
		if _against(part, body) == "under":
			under.append(part)
	_check(under.size() == 2, "a maul in two fists hides %d stretches under the body, not two" % under.size())
	if under.size() == 2:
		var second: Vector2i = _rows_of(under[1])
		var centre := Vector2(maul_grip.x, (second.x + second.y) * 0.5)
		var where: Vector2 = _drawn_at(under[1], centre)
		_check(where.distance_to(offset + left_at) <= 1.5,
			"the second stretch is drawn at %s, not in the left fist at %s" % [where, offset + left_at])
		_check(second.y <= int(maul_hilt.y) + 1, "the left fist's stretch reaches past the haft's end")
	layers.show_frame("attack_2h_1", 0, 2, offset,
		_grip_meta(_grip_socket(fist_at, -90.0, 1.0, 1, left_at, -90.0, 0)))
	var hidden: int = 0
	for part: Sprite2D in layers.drawn(0):
		hidden += 1 if _against(part, body) == "under" else 0
	_check(hidden == 1, "a left fist behind the chest still hid the haft it holds (%d stretches)" % hidden)

	# A pair: each blade closes in its own fist.
	layers.wear(WardenDress.outfit({"body": 0}, dirks, null, null, null))
	var dirk_grip: Vector2 = WardenDress.held_grip(dirks).get("grip", Vector2.ZERO)
	layers.show_frame("attack_1b", 0, 2, offset,
		_grip_meta(_grip_socket(fist_at, -10.0, 1.0, 1, left_at, 190.0, 1)))
	for hand: int in 2:
		var at: Vector2 = offset + (fist_at if hand == 0 else left_at)
		var hid: Array[Sprite2D] = []
		for part: Sprite2D in layers.drawn(hand):
			if _against(part, body) == "under":
				hid.append(part)
		_check(hid.size() == 1, "dirk %d hides %d stretches under its fist, not one" % [hand, hid.size()])
		if hid.size() == 1:
			_check(_drawn_at(hid[0], dirk_grip).distance_to(at) < 0.01,
				"dirk %d's grip is drawn at %s, not in its fist at %s" % [hand, _drawn_at(hid[0], dirk_grip), at])

	# The rule itself, where a fist could not be: no fist, no stretch; a band
	# never escapes the picture's rows.
	_check(DressLayers.grip_bands(Vector2(10, 20), 0.0, 1.0, [15.0]).is_empty(), "no fist still hid a stretch")
	var cut: Array[Dictionary] = DressLayers.pieces(128, [Vector2i(-5, 10), Vector2i(120, 140)])
	var total: int = 0
	for piece: Dictionary in cut:
		var rows: Vector2i = piece["rows"]
		total += rows.y - rows.x
	_check(total == 128, "a picture cut at bands past its edges is %d rows, not 128" % total)

	layers.queue_free()
	body.queue_free()
	await get_tree().process_frame
	_reached.append("fist")
