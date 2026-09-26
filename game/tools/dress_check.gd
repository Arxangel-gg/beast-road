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
	for name: String in ["classes", "held", "length", "combo", "outfit", "bodies"]:
		_check(_reached.has(name), "'%s' never reached its end - a runtime error stopped it" % name)
	for _frame: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("[dress] PASS - %d checks: every class known, every weapon held and sized by its class, the grip picks the combo, the dress resolves" % _checks)
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
			for facing: Variant in sockets:
				_check((sockets[facing] as Array).size() == frames,
					"%s %s %s has %d socket rows for %d frames" % [body, state, facing,
						(sockets[facing] as Array).size(), frames])
	_reached.append("bodies")
