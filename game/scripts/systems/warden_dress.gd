class_name WardenDress
extends RefCounted

## What a Warden is wearing, turned into what gets drawn.
##
## Owner rulings, 2026-09-25: the hooded skull is retired, the Warden has a male
## and a female body, capes are a stat slot, and gear changes how the Warden
## looks. The design is `docs/WARDEN_DRESS_PLAN_2026-09-25.md`; this is the one
## place that decides which sheets a Warden wears, so the field, the Hold, the
## lobby and a partner's copy cannot disagree about it.
##
## **Four kinds of layer.** A *body* - a sex and an armour class, one full frame
## per state, chosen rather than composited. A *cape*, drawn in its own sheets
## and tinted by the cape kind. A *weapon*, socketed at the rig's grip and
## turned along the blade. A *head dressing* - a helmet or hair - socketed at
## the head. `tools/warden_rig/` authors the skeleton all of them share.
##
## **A look and never a number.** Nothing here is read by a fight: the grip
## picks which combo is *drawn*, never how long a swing takes, how far it
## reaches or what it deals - those are the weapon's own, as they always were.
## A dress that cannot be drawn yet falls back to the nearest one that can,
## and a Warden with no dress art at all is the painted Warden that shipped.

const BODIES: Array[String] = ["male", "female"]
const DRESS_DIR: String = "res://art/hero/dress/"
const META_DIR: String = "res://data/dress/"
const HELD_DIR: String = "res://art/hero/held/"

## The armour classes, and which to try when one is not drawn yet. Medium falls
## to heavy before light because mail reads nearer plate than leather.
const ARMOUR_FALLBACK: Dictionary = {
	"heavy": ["heavy", "medium", "light"],
	"medium": ["medium", "heavy", "light"],
	"light": ["light"],
}
const CAPE_FALLBACK: Dictionary = {
	"long": ["long"],
	"half": ["half", "long"],
	"pelt": ["pelt", "long"],
}
const ARMOUR_CLASSES: Array[String] = ["light", "medium", "heavy"]
const CAPE_SHAPES: Array[String] = ["long", "half", "pelt"]
const HELMET_CLASSES: Array[String] = ["hood", "circlet", "open_helm", "great_helm"]
## What a weapon is, for how long it is drawn: `Balance.DRESS_WEAPON_LENGTH`.
const WEAPON_CLASSES: Array[String] = ["knife", "short", "sword", "long", "axe", "club", "maul", "polearm"]

## The two-handed combo plays in place of the one-handed one, step for step.
const TWO_HANDED_STATES: Dictionary = {
	"attack_1a": "attack_2h_1",
	"attack_1b": "attack_2h_2",
	"attack_2": "attack_2h_3",
	"attack_3": "attack_2h_4",
}

static var _meta: Dictionary = {}
static var _layers: Dictionary = {}

## Where the dress is read from. The shipped folders in a game; moved to a
## synthetic dress under user:// by `dress_check` alone, so the runtime can be
## driven through its real doors before a single real frame exists - the seam
## `MetaState.slot_root` is for saves.
static var art_root: String = DRESS_DIR
static var meta_root: String = META_DIR
static var held_root: String = HELD_DIR
## The grip table sits with the weapons rather than with a body's sheets, so a
## gate that points the sheets at a synthetic dress still holds real swords.
static var held_table: String = META_DIR + "held.json"


## Whether a body has any dress art at all. False until the base body is on
## disk, which is what keeps the painted Warden playing in the meantime.
static func available(body: String = "male") -> bool:
	return has_layer("%s_base" % body)


static func has_layer(layer: String) -> bool:
	if not _layers.has(layer):
		_layers[layer] = exists(art_root + layer + "/idle.png")
	return bool(_layers[layer])


static func exists(path: String) -> bool:
	return ResourceLoader.exists(path) or (not path.begins_with("res://") and FileAccess.file_exists(path))


## A picture, imported or not: the game's own are imported resources, and the
## gate's synthetic ones are plain PNGs in user://.
static func texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if not path.begins_with("res://") and FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		return ImageTexture.create_from_image(image) if image != null else null
	return null


## Forget what was found on disk; a gate that installs art calls this.
static func forget() -> void:
	_meta.clear()
	_layers.clear()
	_held.clear()
	_held_read = false


static func body_name(look: Dictionary) -> String:
	return BODIES[clampi(int(look.get("body", 0)), 0, BODIES.size() - 1)]


## The body layer a Warden wears: its sex and its armour's class, falling back
## through the classes that are drawn, and to the plain linen at the end.
static func body_layer(body: String, armour: GearData) -> String:
	var wanted: String = armour.look if armour != null else ""
	for cls: String in ARMOUR_FALLBACK.get(wanted, []):
		var layer: String = "%s_%s" % [body, cls]
		if has_layer(layer):
			return layer
	return "%s_base" % body


## The cape layer, or "" for none. A cape is drawn per body, because it hangs
## from that body's shoulders.
static func cape_layer(body: String, cape: GearData) -> String:
	if cape == null:
		return ""
	for shape: String in CAPE_FALLBACK.get(cape.look, ["long"]):
		var layer: String = "%s_cape_%s" % [body, shape]
		if has_layer(layer):
			return layer
	return ""


## The colour a cape is dyed on the body: the kind's own, or none.
static func cape_tint(cape: GearData) -> Color:
	return cape.look_tint if cape != null else Color(1.0, 1.0, 1.0, 0.0)


## Which combo the weapon draws.
static func grip_of(weapon: GearData) -> int:
	return weapon.grip if weapon != null else GearData.Grip.ONE_HAND


static func state_for(state: String, weapon: GearData) -> String:
	if grip_of(weapon) == GearData.Grip.TWO_HAND and TWO_HANDED_STATES.has(state):
		return TWO_HANDED_STATES[state]
	return state


## Where a weapon's held picture is, or "" when it has none yet.
static func held_path(weapon: GearData) -> String:
	if weapon == null:
		return ""
	var path: String = held_root + "held_" + weapon.id + ".png"
	return path if exists(path) else ""


static var _held: Dictionary = {}
static var _held_read: bool = false


## Where the fist closes on a weapon's held picture, and the top of its blade,
## in the picture's own pixels (`tools/warden_rig/install_held.py`). Found from
## the picture when it was installed, so a new weapon needs no numbers typed.
static func held_grip(weapon: GearData) -> Dictionary:
	if not _held_read:
		_held_read = true
		var path: String = held_table
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_held = parsed
	if weapon == null or not _held.has(weapon.id):
		return {}
	var entry: Dictionary = _held[weapon.id]
	var grip: Array = entry.get("grip", [64.0, 100.0])
	return {"grip": Vector2(float(grip[0]), float(grip[1])), "tip": float(entry.get("tip", 0.0))}


## How long the weapon is drawn, in figure heights: its class's length, nudged
## a little by its reach. The class keeps a knife shorter than a sword whatever
## the balance numbers say; the picture never decides it.
static func held_length(weapon: GearData) -> float:
	if weapon == null:
		return 0.0
	var fallback: String = "polearm" if weapon.grip == GearData.Grip.TWO_HAND else "sword"
	var base: float = float(Balance.DRESS_WEAPON_LENGTH.get(weapon.look,
		Balance.DRESS_WEAPON_LENGTH[fallback]))
	return base * (1.0 + (weapon.reach_scale - 1.0) * Balance.DRESS_REACH_NUDGE)


## The helmet's head dressing class, or "" for none.
static func helmet_class(helmet: GearData) -> String:
	return helmet.look if helmet != null else ""


## A state's sheet metadata for a body: its cell, where the cell sits on the
## canvas, its frame count and its sockets. Empty when it has none.
static func meta(body: String, state: String) -> Dictionary:
	var key: String = body + "/" + state
	if _meta.has(key):
		return _meta[key]
	var path: String = meta_root + key + ".json"
	var out: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out = parsed
	_meta[key] = out
	return out


## Everything a Warden wears, from their look and their gear, as the names the
## drawing needs. The one function the hero, the Hold and a partner's copy ask.
static func outfit(look: Dictionary, weapon: GearData, armour: GearData,
		cape: GearData, helmet: GearData) -> Dictionary:
	var body: String = body_name(look)
	return {
		"body": body,
		"body_layer": body_layer(body, armour),
		"cape_layer": cape_layer(body, cape),
		"cape_tint": cape_tint(cape),
		"grip": grip_of(weapon),
		"held": held_path(weapon),
		"held_grip": held_grip(weapon),
		"held_length": held_length(weapon),
		"helmet": helmet_class(helmet),
	}
