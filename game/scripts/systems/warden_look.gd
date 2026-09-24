class_name WardenLook
extends RefCounted

## The Warden's look: what a player may change about how they are drawn.
##
## Owner ruling, 2026-09-21: character customization is approved, with one
## bound written before the code - **it may change nothing but how the Warden
## looks.** No attribute, no stat, no unlock, no currency, nothing the road can
## grow. So a look is two numbers, a dye on the cloak and a dye on the sash,
## applied by `warden_look.gdshaderinc` to the painted sprite; the same frames
## are drawn and the same numbers are read. `warden_look_check` dresses a real
## hero and reads every attribute, the speed and the pool back unchanged.
##
## **Persisted, additively.** `MetaState.look` is this dictionary and nothing
## else; a save written before it has no `look` key and reads back as the
## painted Warden, which is also what a new account is. Every value is clamped
## on read, because a save may hold anything.
##
## **On the wire as two numbers, by value.** A partner's look rides the state
## row behind their mount, so a machine draws the Warden it was told about and
## never a guess; the Hold's seats carry it the same way. Nothing about it is
## trusted for anything but a picture.

const KEY_CLOAK: String = "cloak"
const KEY_SASH: String = "sash"
## The third dye (2026-09-23, from Core Keeper's customisation): the leather -
## straps, belt, boots - which the painting keeps in dark saturated orange-brown,
## clear of the sash's red below it and the lantern's brighter orange above.
## **Appended, never inserted**: a look is packed by position on the wire, and a
## partner on the build before this sends two numbers that must still mean the
## cloak and the sash.
const KEY_LEATHER: String = "leather"
const KEYS: Array[String] = [KEY_CLOAK, KEY_SASH, KEY_LEATHER]

## Looks worth one press, for a player who wants a Warden rather than three
## sliders. Hue turns from the painting: the cloak is teal-steel (0.535), the sash
## red (0.0), the leather orange-brown (0.075).
const PRESETS: Array[Dictionary] = [
	{"label": "Painted", "cloak": 0.0, "sash": 0.0, "leather": 0.0},
	{"label": "Ember", "cloak": -0.495, "sash": 0.12, "leather": -0.04},
	{"label": "Frost", "cloak": 0.045, "sash": 0.5, "leather": -0.475},
	{"label": "Moss", "cloak": -0.205, "sash": 0.1, "leather": 0.0},
	{"label": "Royal", "cloak": 0.215, "sash": 0.12, "leather": -0.075},
	{"label": "Verdant", "cloak": -0.115, "sash": -0.05, "leather": -0.03},
]
## How far either dye may turn the hue, as a share of the wheel. Half a turn
## reaches every colour; there is nothing past it.
const RANGE: float = 0.5
const SHADER_PATH: String = "res://scripts/shaders/warden_look.gdshader"

static var _shader: Shader = null


static func plain() -> Dictionary:
	return {KEY_CLOAK: 0.0, KEY_SASH: 0.0, KEY_LEATHER: 0.0}


## A preset as a look.
static func preset(index: int) -> Dictionary:
	var entry: Dictionary = PRESETS[clampi(index, 0, PRESETS.size() - 1)]
	return clean({KEY_CLOAK: entry["cloak"], KEY_SASH: entry["sash"],
		KEY_LEATHER: entry["leather"]})


## Whatever arrived - a save, a packet, a slider - as a look that is safe to
## draw: known keys only, numbers only, clamped.
static func clean(raw: Variant) -> Dictionary:
	var out: Dictionary = plain()
	if raw is Dictionary:
		var given: Dictionary = raw
		for key: String in KEYS:
			var value: Variant = given.get(key, 0.0)
			if value is float or value is int:
				out[key] = clampf(float(value), -RANGE, RANGE)
	return out


static func is_plain(look: Dictionary) -> bool:
	var cleaned: Dictionary = clean(look)
	for key: String in KEYS:
		if absf(float(cleaned[key])) > 0.0005:
			return false
	return true


static func same(a: Dictionary, b: Dictionary) -> bool:
	var left: Dictionary = clean(a)
	var right: Dictionary = clean(b)
	for key: String in KEYS:
		if not is_equal_approx(float(left[key]), float(right[key])):
			return false
	return true


## The numbers, in key order, for a packet.
static func pack(look: Dictionary) -> Array:
	var cleaned: Dictionary = clean(look)
	var row: Array = []
	for key: String in KEYS:
		row.append(float(cleaned[key]))
	return row


## A packet back into a look. Anything short, long or wrong is the painted
## Warden rather than an error - a picture is not worth refusing a row over.
static func unpack(row: Variant) -> Dictionary:
	if not (row is Array):
		return plain()
	var given: Array = row
	var out: Dictionary = {}
	for index: int in KEYS.size():
		if index < given.size():
			out[KEYS[index]] = given[index]
	return clean(out)


## This machine's own player's look, off the save. What the dye sliders read and
## write; what is *drawn* is `worn`.
static func mine() -> Dictionary:
	return clean(MetaState.look)


## The middle of the cloak's hue band, as a share of the wheel - the teal-steel
## the Warden is painted in (`warden_look.gdshaderinc`, 0.43 to 0.64).
const CLOAK_HUE: float = 0.535
## A set colour greyer than this has no hue worth wearing.
const SET_COLOUR_MIN_SATURATION: float = 0.2


## **You look like what you wear** (2026-09-23, from Core Keeper, where every
## armour piece changes the character). The Warden's frames cannot change with
## gear - every sheet again per piece - but the dye can: a set worn in full puts
## its own colour on the cloak, the same colour its ring turns in at the feet.
##
## Only a cloak left as painted. A dye the player chose is a choice, and a set
## that overrode it would be the game ignoring them. Nothing reads a look.
static func worn() -> Dictionary:
	var full: GearSetData = Modifiers.completed_set()
	return with_set_colour(mine(), full.aura_colour if full != null else Color(0, 0, 0, 0))


## Pure: `look` with a set's colour on a cloak left as painted.
static func with_set_colour(look: Dictionary, colour: Color) -> Dictionary:
	var out: Dictionary = clean(look)
	if colour.a <= 0.0 or colour.s < SET_COLOUR_MIN_SATURATION:
		return out
	if absf(float(out.get(KEY_CLOAK, 0.0))) > 0.0005:
		return out
	out[KEY_CLOAK] = wrapf(colour.h - CLOAK_HUE, -RANGE, RANGE)
	return clean(out)


static func shader() -> Shader:
	if _shader == null and ResourceLoader.exists(SHADER_PATH):
		_shader = load(SHADER_PATH) as Shader
	return _shader


## Puts a look on a sprite.
##
## A sprite already wearing the hero's blood shader gets the dye set on that
## material, because the blood shader includes the dye and a sprite has one
## material. A sprite wearing nothing gets the standalone shader - unless the
## look is the painted Warden, in which case it stays wearing nothing, so a
## plain account pays for no material at all. **Never over another material**:
## something else wanted that sprite drawn a particular way, and a dye is not
## worth silently undoing it - the same rule `BloodStain.attach` keeps.
static func dress(item: CanvasItem, look: Dictionary) -> void:
	if item == null:
		return
	var cleaned: Dictionary = clean(look)
	var material := item.material as ShaderMaterial
	if material != null:
		if material.shader == null:
			return
		var path: String = material.shader.resource_path
		if path != SHADER_PATH and path != BloodStain.SHADER_PATH:
			return
	elif item.material != null:
		return
	else:
		if is_plain(cleaned) or shader() == null:
			return
		material = ShaderMaterial.new()
		material.shader = shader()
		item.material = material
	material.set_shader_parameter("look_cloak", float(cleaned[KEY_CLOAK]))
	material.set_shader_parameter("look_sash", float(cleaned[KEY_SASH]))
	material.set_shader_parameter("look_leather", float(cleaned[KEY_LEATHER]))
