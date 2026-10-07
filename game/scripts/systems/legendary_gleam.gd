class_name LegendaryGleam
extends RefCounted

## **Legendary gear gleams** (owner, 2026-10-07: *"Legendary gear should have
## animations and game juicy vfx"*). The pieces that wear legendary affixes -
## Runed and above, `Balance.GEAR_GLEAM_FROM_RARITY` - wear
## `legendary_gleam.gdshader` on their own painting wherever it is drawn: a
## breathing rim, a sweeping sheen and twinkles, harder up the ladder, the top
## rung's sheen turning through the spectrum. The weapon in a Warden's hand
## gleams the same way and sheds motes off its tip (`DressLayers`).
##
## A look and never a fact: nothing reads a gleam, and it changes no number.

const SHADER: String = "res://scripts/shaders/legendary_gleam.gdshader"
## Set on whatever wears a gleam, so a gate can ask without reading a material.
const META: StringName = &"legendary_gleam"


## How hard a piece of this rarity gleams: nothing below the first legendary
## rung, then rising to one at the top of the ladder.
static func tier(rarity: int) -> float:
	var top: int = Stash.RARITY_NAMES.size() - 1
	var first: int = Balance.GEAR_GLEAM_FROM_RARITY
	if rarity < first or top <= first:
		return 0.0 if rarity < first else 1.0
	return lerpf(Balance.GEAR_GLEAM_FLOOR, 1.0, float(rarity - first) / float(top - first))


## The gleam for one piece of this rarity, or null for a piece that does not
## gleam. A material of its own, so `seed` keeps two pieces out of step.
static func material_for(rarity: int, seed_name: String) -> ShaderMaterial:
	var strength: float = tier(rarity)
	if strength <= 0.0 or not ResourceLoader.exists(SHADER):
		return null
	var material := ShaderMaterial.new()
	material.shader = load(SHADER) as Shader
	var colour: Color = Stash.RARITY_COLOURS[clampi(rarity, 0, Stash.RARITY_COLOURS.size() - 1)]
	material.set_shader_parameter("rarity_colour", colour)
	material.set_shader_parameter("tier", strength)
	material.set_shader_parameter("prismatic", 1.0 if rarity >= Stash.RARITY_NAMES.size() - 1 else 0.0)
	material.set_shader_parameter("seed", float(absi(hash(seed_name)) % 997) / 997.0)
	material.set_shader_parameter("sweep_seconds",
		lerpf(Balance.GEAR_GLEAM_SWEEP_SECONDS.x, Balance.GEAR_GLEAM_SWEEP_SECONDS.y, strength))
	return material


## Dresses an icon of `piece`. Leaves anything that is not legendary as it was,
## and takes a gleam off an icon reused for a piece that no longer earns one.
static func dress(icon: CanvasItem, piece: Dictionary) -> void:
	if icon == null:
		return
	var rarity: int = int(piece.get("rarity", 0))
	var material: ShaderMaterial = material_for(rarity, str(piece.get("uid", piece.get("kind", ""))))
	if material == null:
		if icon.has_meta(META):
			icon.material = null
			icon.remove_meta(META)
		return
	icon.material = material
	icon.set_meta(META, rarity)


## Whether `icon` wears a gleam, and of what rarity (-1 for none).
static func rarity_of(icon: CanvasItem) -> int:
	if icon == null or not icon.has_meta(META):
		return -1
	return int(icon.get_meta(META))
