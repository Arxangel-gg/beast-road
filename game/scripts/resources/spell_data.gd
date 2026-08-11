class_name SpellData
extends GameData

## One of the eight hero spells (GDD §11), flavoured as scavenging incantations.
## Four are equipped per run.
##
## `id = "rift_step"` -> `res://art/icons/spells/spell_rift_step.png`

## What the spell actually does when cast. The caster switches on this, so a new
## spell is a `.tres` with an existing kind, or one new branch — never a script.
enum Kind {
	## Teleport toward the aim point, up to `cast_range`.
	BLINK,
	## Damage everything within `effect_radius` of the hero.
	NOVA,
	## Damage and pull everything within `cast_range` toward the hero.
	HOOK,
	## Strike in front, healing the hero for `lifesteal` of the damage dealt.
	DRAIN,
	## Knockback ring, low damage.
	SHOCKWAVE,
	## Invulnerability and a speed boost for `duration`.
	VEIL,
	## Shield the lane the hero is standing in for `duration`.
	WARD,
	## Channelled beam along the aim direction for `duration`.
	BEAM,
}

@export var kind: Kind = Kind.NOVA

@export var cooldown: float = 6.0

@export var damage: float = 0.0

## Effect radius, or beam width for BEAM. 0 means self-targeted.
@export var effect_radius: float = 0.0

## How long a lingering effect lasts: a shield, a veil, a channelled beam.
@export var duration: float = 0.0

## Distance for movement and reach spells.
@export var cast_range: float = 0.0

## Fraction of damage dealt returned to the hero as health.
@export_range(0.0, 1.0) var lifesteal: float = 0.0

## Impulse applied to anything caught, in px/s.
@export var knockback: float = 0.0

## Movement multiplier granted for `duration`, for VEIL.
@export var speed_bonus: float = 0.0

## The hero cannot move or attack while this resolves.
@export var is_channelled: bool = false


func get_sprite_path() -> String:
	return GameData.derive_path("icons/spells", "spell_", id)
