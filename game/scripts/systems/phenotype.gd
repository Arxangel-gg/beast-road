class_name Phenotype
extends RefCounted

## No two deer are the same deer.
##
## **Owner brief, 2026-09-15:** "Wildlife should also all generate with some
## random variations using shaders appropriately for all wildlife with seeds so
## that they all end up looking unique and different in some ways ... companion
## made alive wildlife should keep the seed for the duration of its lifespan."
##
## Thirty-nine species share one painting each, so a field of six deer is one
## deer drawn six times - and the thing that makes a wilderness read as alive is
## that no two animals in it are identical. The cheapest honest answer is not
## more art: it is a coat, derived from the animal's own serial number and drawn
## by the shader the sprite already wears.
##
## **It is a look and never a number.** Nothing reads a phenotype: not rarity,
## not the collection, not the hunt, not loot, not the wrath the earth keeps.
## `Graphics.KEY_PHENOTYPE` turns every one of them off and no number in the
## game moves - the same bound the fog of war and the rank sheen are held to,
## and the reason all three can be given to a weak machine.
##
## **Four bounds, and each is a way this goes wrong.**
##
## - **A coat may never be mistaken for a rarity.** The rank sheen already says
##   what an animal is worth, in light, on a ladder that climbs to a legendary
##   shiny. A hue wide enough to make one fox blue makes the ladder unreadable,
##   so the spread is authored per species and small: `PHENOTYPE_HUE_CEILING` is
##   the hard limit and `phenotype_check` refuses anything past it.
## - **A coat may never stop an animal being its species.** The variation is a
##   shift of the painting's own colours rather than a palette swap: the deer is
##   a lighter or darker deer with a different scatter of dapples, never a
##   different animal.
## - **It must survive being looked at twice.** The seed is the animal's serial,
##   which is fixed the moment it is placed and is what `SpiritBond.trait_for`
##   already derives a temperament from - so walking away and back cannot reroll
##   a coat any more than it can reroll a shine.
## - **It must be reproducible after the generator changes.** `VERSION` is mixed
##   into every seed, so a change to how coats are drawn is a deliberate bump
##   rather than a silent reshuffle of every animal in the game.
##
## **Nothing persists.** A wild animal's coat lives as long as the animal. A
## bonded spirit's is derived from the run's own seed and its variant key, so it
## is the same companion for the whole run, agrees on both machines in co-op
## without a packet, and is gone with the run - which keeps working rule 7
## exactly where it was.

## Bump this when the *meaning* of a seed changes - a new pattern in the middle
## of the enum, a different mixing function, a different uniform range. Mixed
## into every seed so that an old serial cannot quietly draw a new coat.
const VERSION: int = 1

## The uniforms the shader reads. Named here so the gate can walk them rather
## than a copy of them.
## A typed array rather than a `PackedStringArray`: a packed array built from a
## literal is not a constant expression, which this project has now been caught
## by twice (`PackedFloat32Array`, then this).
const UNIFORMS: Array[String] = [
	"coat_hue", "coat_light", "coat_saturation",
	"coat_pattern", "coat_pattern_strength", "coat_pattern_scale",
	"coat_pattern_tint", "coat_offset",
]


## The seed for one animal: its species, its serial and the generator.
##
## The same mixing `SpiritBond.trait_for` uses, for the same reason - a serial
## on its own is 1, 2, 3, and consecutive integers through a weak hash give
## consecutive results, which would make every animal placed in a row look like
## a gradient rather than like a crowd.
static func seed_for(species_id: String, serial: int) -> int:
	return absi(hash(species_id + "#%d" % VERSION) ^ (serial * 2654435761))


## Dress a sprite's own material in a coat.
##
## The material is the one `ActorPolish` already attached, because a sprite has
## one material slot and `ActorState` owns it - the burning, the chill, the wet.
## A second shader here would have to be merged into the first and the two would
## drift the first time either was tuned, which is the argument the rank sheen
## is a child node for. A coat cannot be a child node: it has to change the
## body's own pixels rather than add light over them.
static func dress(material: ShaderMaterial, kind: WildlifeData,
		serial: int) -> void:
	if material == null or kind == null:
		return
	apply(material, kind, genes(kind, serial))


## **A coat as the numbers an animal carries** (2026-09-25): split out of
## `dress` so a newborn can be handed its parents' rather than its serial's.
##
## The draws are exactly the ones `dress` always made, in the same order, so an
## animal that was not born on the road wears the coat it always wore -
## `phenotype_check` holds that against the original arithmetic.
static func genes(kind: WildlifeData, serial: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_for(kind.id, serial)
	# Each draw is its own call so that adding one later shifts nothing before
	# it - the same discipline every seeded stream in this project is held to.
	var hue: float = rng.randf_range(-1.0, 1.0) * spread(kind, "hue")
	var light: float = rng.randf_range(-1.0, 1.0) * spread(kind, "light")
	var saturation: float = rng.randf_range(-1.0, 1.0) * spread(kind, "saturation")
	# **The pattern is the species' own or nothing.** A rabbit does not grow
	# stripes because a die came up stripes; what varies is where its markings
	# fall and how strong they are, which is what actually differs between two
	# animals of a kind.
	var strength: float = 0.0
	if kind.coat_pattern != WildlifeData.Coat.NONE:
		strength = kind.coat_pattern_strength * rng.randf_range(0.55, 1.0)
	# Where the markings sit. Seeded rather than centred, and *not* mirrored:
	# the same offset read on both halves of the sprite is what makes a coat
	# look printed rather than grown.
	var offset := Vector2(rng.randf() * 64.0, rng.randf() * 64.0)
	return {"hue": hue, "light": light, "saturation": saturation,
		"strength": strength, "offset": offset}


## How far a species' coat may wander on one gene: its own authored spread,
## never past the ceiling that keeps a coat from reading as a rarity.
static func spread(kind: WildlifeData, gene: String) -> float:
	match gene:
		"hue":
			return minf(kind.coat_hue_spread, Balance.PHENOTYPE_HUE_CEILING)
		"light":
			return minf(kind.coat_light_spread, Balance.PHENOTYPE_LIGHT_CEILING)
		"saturation":
			return minf(kind.coat_saturation_spread, Balance.PHENOTYPE_SATURATION_CEILING)
	return 0.0


## Puts a coat on a material. The species decides the pattern, its scale and its
## tint; the coat decides everything that differs between two of a kind.
static func apply(material: ShaderMaterial, kind: WildlifeData, coat: Dictionary) -> void:
	if material == null or kind == null:
		return
	if not Graphics.phenotypes():
		_plain(material)
		return
	material.set_shader_parameter("coat_hue", float(coat.get("hue", 0.0)))
	material.set_shader_parameter("coat_light", float(coat.get("light", 0.0)))
	material.set_shader_parameter("coat_saturation", float(coat.get("saturation", 0.0)))
	material.set_shader_parameter("coat_pattern", int(kind.coat_pattern))
	material.set_shader_parameter("coat_pattern_strength", float(coat.get("strength", 0.0)))
	material.set_shader_parameter("coat_pattern_scale",
		maxf(kind.coat_pattern_scale, 1.0))
	material.set_shader_parameter("coat_pattern_tint", kind.coat_pattern_tint)
	material.set_shader_parameter("coat_offset", coat.get("offset", Vector2.ZERO) as Vector2)


## **A newborn wears its parents' coat** (2026-09-25, `IDEAS_REVIEW_2026-09-25`
## §5). Each gene comes from the mother, from the father, or now and then from
## between them, and then drifts by a small mutation - so a litter looks like a
## family rather than like strangers who arrived together, and no two cubs of a
## litter are the same cub.
##
## **Clamped to the species' own spread**, so resemblance can never walk a coat
## past a ceiling over generations: a family of foxes is a family of foxes,
## never a blue one, and a coat still cannot be mistaken for a rarity.
##
## **A look and never a number**, like every coat. Speed, bite, loyalty and an
## element were proposed as inherited genes too and refused: bred numbers are a
## stat scale found by breeding, and breeding would become the way to power.
static func inherit(kind: WildlifeData, mother: Dictionary, father: Dictionary,
		dice: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}
	for gene: String in ["hue", "light", "saturation"]:
		var limit: float = spread(kind, gene)
		var value: float = _one_gene(float(mother.get(gene, 0.0)),
			float(father.get(gene, mother.get(gene, 0.0))), dice)
		value += dice.randf_range(-1.0, 1.0) * limit * Balance.PHENOTYPE_MUTATION
		out[gene] = clampf(value, -limit, limit)
	var strength: float = 0.0
	if kind.coat_pattern != WildlifeData.Coat.NONE:
		strength = _one_gene(float(mother.get("strength", 0.0)),
			float(father.get("strength", mother.get("strength", 0.0))), dice)
		strength += dice.randf_range(-1.0, 1.0) * kind.coat_pattern_strength \
			* Balance.PHENOTYPE_MUTATION
		strength = clampf(strength, 0.0, kind.coat_pattern_strength)
	out["strength"] = strength
	# Where the markings sit: one parent's, nudged. A blend of two offsets is a
	# pattern that belongs to neither, which reads as noise rather than as kin.
	var from: Dictionary = mother if dice.randf() < 0.5 else father
	var offset: Vector2 = from.get("offset", Vector2.ZERO) as Vector2
	offset += Vector2(dice.randf_range(-1.0, 1.0), dice.randf_range(-1.0, 1.0)) \
		* Balance.PHENOTYPE_OFFSET_DRIFT
	out["offset"] = Vector2(fposmod(offset.x, 64.0), fposmod(offset.y, 64.0))
	return out


static func _one_gene(from_mother: float, from_father: float,
		dice: RandomNumberGenerator) -> float:
	var pick: float = dice.randf()
	if pick < Balance.PHENOTYPE_BLEND_CHANCE:
		return lerpf(from_mother, from_father, dice.randf())
	if pick < Balance.PHENOTYPE_BLEND_CHANCE + (1.0 - Balance.PHENOTYPE_BLEND_CHANCE) * 0.5:
		return from_mother
	return from_father


## The coat an animal record wears: the one it was born with, or its serial's.
static func coat_of(animal: Dictionary) -> Dictionary:
	if animal.has("coat"):
		return animal["coat"] as Dictionary
	var kind := animal.get("data", null) as WildlifeData
	if kind == null:
		return {}
	return genes(kind, int(animal.get("net_id", 0)))


## What a coat is, as numbers, without needing a material. For the gate, and for
## anything that wants to compare two animals without reading a shader back.
static func describe(kind: WildlifeData, serial: int) -> Dictionary:
	var material := ShaderMaterial.new()
	material.shader = load(ActorPolish.SHADER_PATH) as Shader
	dress(material, kind, serial)
	var out: Dictionary = {}
	for name: String in UNIFORMS:
		out[name] = material.get_shader_parameter(name)
	return out


## Every uniform back to the neutral value, so a body with no coat is
## pixel-identical to one drawn before coats existed.
static func _plain(material: ShaderMaterial) -> void:
	material.set_shader_parameter("coat_hue", 0.0)
	material.set_shader_parameter("coat_light", 0.0)
	material.set_shader_parameter("coat_saturation", 0.0)
	material.set_shader_parameter("coat_pattern", 0)
	material.set_shader_parameter("coat_pattern_strength", 0.0)
	material.set_shader_parameter("coat_pattern_scale", 6.0)
	material.set_shader_parameter("coat_pattern_tint", Color(0, 0, 0, 0))
	material.set_shader_parameter("coat_offset", Vector2.ZERO)
