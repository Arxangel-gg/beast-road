class_name SpellData
extends GameData

## One of the eight hero spells (GDD §8), flavoured as scavenging incantations.
## Four are equipped per run, chosen three-at-a-time on level-up.
##
## `id = "rift_step"` -> `res://art/icons/spells/spell_rift_step.png`

@export var cooldown: float = 6.0

@export var damage: float = 0.0

## Effect radius, or length for a line spell. 0 means self-targeted.
@export var effect_radius: float = 0.0

## How long a lingering effect lasts: a shield, a veil, a channelled beam.
@export var duration: float = 0.0

## Distance for movement spells like Rift Step.
@export var cast_range: float = 0.0

## Fraction of damage dealt that is returned to the hero as health.
@export_range(0.0, 1.0) var lifesteal: float = 0.0

## Impulse applied to anything caught, in px/s.
@export var knockback: float = 0.0

## The hero cannot move or attack while this is resolving.
@export var is_channelled: bool = false


func get_sprite_path() -> String:
	return GameData.derive_path("icons/spells", "spell_", id)
