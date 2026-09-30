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
## The modular Warden's own choices (owner, 2026-09-26: *"8 hairstyles, beards
## yes, code sway, one face"*): which body, which hairstyle, which hair colour,
## which beard. **Appended after the dyes, never inserted** - the wire packs by
## position, and a partner on an older build sends three numbers that must
## still mean the three dyes. Each is a whole number, an index rather than a
## hue turn, and 0 is always the plain choice: the male body, bald, the first
## colour, clean-shaven. A look still changes nothing but a picture.
const KEY_BODY: String = "body"
const KEY_HAIR: String = "hair"
const KEY_HAIR_COLOUR: String = "hair_colour"
const KEY_BEARD: String = "beard"
## The skin (owner, 2026-09-26: *"make sure players can also properly select
## their skintones"*). **Appended last**, for the reason every key after the
## dyes was: a partner on the build before this sends seven numbers, and they
## must still mean the dyes, the body, the hair and the beard. 0 is the skin as
## the body was painted, so an older row reads as the painting.
const KEY_SKIN: String = "skin"
const KEYS: Array[String] = [KEY_CLOAK, KEY_SASH, KEY_LEATHER,
	KEY_BODY, KEY_HAIR, KEY_HAIR_COLOUR, KEY_BEARD, KEY_SKIN]
## The hue turns, which the dye shader reads.
const DYES: Array[String] = [KEY_CLOAK, KEY_SASH, KEY_LEATHER]
## The hair colours a style may be drawn in. Every style is drawn once, in
## chroma-key green, and its light and dark are mapped onto one of these at
## runtime (`hair_tint.gdshader`), so a colour costs nothing and black and white
## are reachable, which a hue turn is not.
const HAIR_COLOURS: Array[Color] = [
	Color8(58, 38, 26),     # dark brown
	Color8(26, 22, 22),     # black
	Color8(96, 64, 40),     # brown
	Color8(122, 70, 40),    # chestnut
	Color8(134, 52, 32),    # auburn
	Color8(178, 86, 40),    # copper
	Color8(212, 176, 108),  # blonde
	Color8(182, 170, 142),  # ash
	Color8(128, 124, 120),  # grey
	Color8(226, 222, 212),  # white
]
## The names the creation screen shows, one a colour.
const HAIR_COLOUR_NAMES: Array[String] = ["Dark brown", "Black", "Brown", "Chestnut", "Auburn",
	"Copper", "Blonde", "Ash", "Grey", "White"]
## The skin tones, lightest to deepest, as the middle of the skin: what the
## painted skin's own mean is turned into (`warden_look.gdshaderinc`), so the
## painting's shading - the lit crown, the shadow under the jaw, the warm
## knuckles - is kept at every tone rather than flattened onto a ramp. The
## first entry is the skin as painted, and turns nothing. Judged on the male
## base at every facing (2026-09-26): the painted skin is a mid tan, so no entry
## sits within a step of it, and a tone nearer than that is a choice that looks
## like no choice.
const SKIN_TONES: Array[Color] = [
	Color(0, 0, 0, 0),      # as painted
	Color8(242, 212, 194),  # porcelain
	Color8(234, 194, 166),  # fair
	Color8(224, 176, 140),  # light
	Color8(212, 150, 126),  # rosy
	Color8(196, 158, 112),  # olive
	Color8(148, 98, 64),    # bronze
	Color8(120, 78, 52),    # brown
	Color8(92, 59, 41),     # deep
	Color8(64, 42, 31),     # ebony
]
## The names the creation screen shows, one a tone.
const SKIN_NAMES: Array[String] = ["As painted", "Porcelain", "Fair", "Light", "Rosy", "Olive",
	"Bronze", "Brown", "Deep", "Ebony"]
## How many of each choice there are, the plain one included: two bodies,
## eighteen styles and bald, the colours above, six beards and clean-shaven,
## and the tones above. Owner, 2026-09-26: *"12-24 hairstyles or more and
## including styles for both genders"* and *"4-8 beards is fine"*. A style's
## place in the count is the same style on either body (`tools/warden_rig/heads.json`).
const CHOICES: Dictionary = {
	KEY_BODY: 2, KEY_HAIR: 19, KEY_HAIR_COLOUR: 10, KEY_BEARD: 7, KEY_SKIN: 10,
}

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
	var out: Dictionary = {}
	for key: String in DYES:
		out[key] = 0.0
	for key: String in CHOICES:
		out[key] = 0
	return out


## `look` wearing a preset's dyes, and keeping everything else it chose - a
## preset is a set of colours, never a new body or a haircut.
static func dyed_as(look: Dictionary, index: int) -> Dictionary:
	var out: Dictionary = clean(look)
	var dyes: Dictionary = preset(index)
	for key: String in DYES:
		out[key] = dyes[key]
	return out


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
			if not (value is float or value is int):
				continue
			if CHOICES.has(key):
				out[key] = clampi(roundi(float(value)), 0, int(CHOICES[key]) - 1)
			else:
				out[key] = clampf(float(value), -RANGE, RANGE)
	return out


## One entry, cleaned as `clean` would clean it.
static func cleaned_value(key: String, value: float) -> Variant:
	var one: Dictionary = {}
	one[key] = value
	return clean(one).get(key, 0.0)


## Whether a look is the female body - whose voice, not only whose sheets.
static func is_female(look: Variant) -> bool:
	var dictionary := look as Dictionary if look is Dictionary else {}
	return int(dictionary.get(KEY_BODY, 0)) == 1


static func is_plain(look: Dictionary) -> bool:
	return is_undyed(look) and _default_choices(clean(look))


## No dye on any band: the painting as it was painted.
static func is_undyed(look: Dictionary) -> bool:
	var cleaned: Dictionary = clean(look)
	for key: String in DYES:
		if absf(float(cleaned[key])) > 0.0005:
			return false
	return true


static func _default_choices(cleaned: Dictionary) -> bool:
	for key: String in CHOICES:
		if int(cleaned[key]) != 0:
			return false
	return true


## The colour a hair or beard is drawn in.
static func hair_colour(look: Dictionary) -> Color:
	return HAIR_COLOURS[int(clean(look)[KEY_HAIR_COLOUR])]


## The tone the painted skin's mean is turned to: the chosen tone, or `painted`
## itself (measured off the body's sheets when they are packed, carried in their
## meta) for the painting as painted - which the shader reads as nothing to
## turn. A body never measured is transparent and turns nothing either.
static func skin_tone(look: Dictionary, painted: Color) -> Color:
	var index: int = int(clean(look)[KEY_SKIN])
	if index <= 0 or painted.a <= 0.0:
		return painted
	return SKIN_TONES[index]


## One channel of a skin pixel turned from `painted` to `tone`: the rule the
## shader applies, written out for the gate and the creation screen's swatches.
## Darkening multiplies; lightening multiplies in the inverted space, so a
## highlight is compressed toward white rather than clipped to it - a straight
## multiply turned porcelain's lit crown into a flat white smear. Either way the
## painted mean lands exactly on the tone.
static func turn_skin_channel(value: float, painted: float, tone: float) -> float:
	if tone > painted:
		return clampf(1.0 - (1.0 - value) * (1.0 - tone) / maxf(1.0 - painted, 0.001), 0.0, 1.0)
	return clampf(value * tone / maxf(painted, 0.001), 0.0, 1.0)


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
		if (is_undyed(cleaned) and int(cleaned[KEY_SKIN]) == 0) or shader() == null:
			return
		material = ShaderMaterial.new()
		material.shader = shader()
		item.material = material
	material.set_shader_parameter("look_cloak", float(cleaned[KEY_CLOAK]))
	material.set_shader_parameter("look_sash", float(cleaned[KEY_SASH]))
	material.set_shader_parameter("look_leather", float(cleaned[KEY_LEATHER]))
	# The skin turns only where a body sheet's mask says skin (set per sheet by
	# `HeroAnimator`); on art with no mask this is a number nothing reads.
	var painted: Color = WardenDress.skin_painted(WardenDress.body_name(cleaned))
	var tone: Color = skin_tone(cleaned, painted)
	material.set_shader_parameter("skin_from", Vector3(painted.r, painted.g, painted.b))
	material.set_shader_parameter("skin_to", Vector3(tone.r, tone.g, tone.b))
