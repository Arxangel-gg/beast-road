class_name EnemyAffixData
extends GameData

## One thing that can be true of a promoted enemy (owner decision, 2026-08-31).
##
## `id = "rimewarded"` -> `res://art/icons/affixes/affix_rimewarded.png`
##
## **An affix is a modifier, never a branch.** Everything here is a number or a
## flag the shared enemy script already knows how to apply, which is what lets
## two of them combine without anybody writing the combination: Frozen and
## Volatile is a body that slows you and then detonates, and no code says so.
##
## Adding an affix is adding a `.tres`. That is the whole point, and it is why
## twelve breeds can become hundreds of encounters without new art or new AI.

## Multiplied into the promoted enemy's numbers.
@export_range(0.5, 6.0) var health_scale: float = 1.0
@export_range(0.5, 4.0) var damage_scale: float = 1.0
@export_range(0.4, 3.0) var speed_scale: float = 1.0

## What the body does beyond its numbers, applied by the enemy script.
##
## Kept as separate fields rather than one enum so two affixes can each
## contribute and the result is simply both - an enum would force a choice and
## make combinations impossible without a lookup table of every pair.

## Leaves a damaging bloom where it dies.
@export_range(0.0, 400.0) var death_blast_radius: float = 0.0
@export_range(0.0, 200.0) var death_blast_damage: float = 0.0

## When it falls, every ally inside `aura_radius` is mended by this share of its
## own health. A reason to leave it for last rather than first, which is the
## opposite decision to the auras above and is why both exist.
@export_range(0.0, 0.5) var death_mends_allies: float = 0.0

## Chills whatever it strikes.
@export_range(0.1, 1.0) var on_hit_slow: float = 1.0
@export_range(0.0, 8.0) var on_hit_slow_duration: float = 0.0

## Burns whatever it strikes.
@export_range(0.0, 120.0) var on_hit_burn: float = 0.0
@export_range(0.0, 10.0) var on_hit_burn_duration: float = 0.0

## Takes less from everything. A flat share, so it never reaches immunity.
@export_range(0.0, 0.7) var damage_resistance: float = 0.0

## Heals itself each second, as a share of its own maximum.
@export_range(0.0, 0.1) var regeneration: float = 0.0

# --- What a mark does when it lands a blow ----------------------------------
#
# Every one of these moves a number the fight already has. A mark that
# introduced a *mechanic* would be a content system wearing an affix's clothes,
# and `curve_report` - which models an enemy as its contact damage - would never
# see it coming.

## Takes this much mana off a caster it lands on, exactly as the hex shot does.
## Worth nothing at all against a swordhand, which is the point of it.
@export_range(0.0, 60.0) var on_hit_mana_burn: float = 0.0

# --- What a mark does for the bodies around it ------------------------------
#
# Read off `_allies_in`, which the anchor's shelter already uses. An aura is a
# *reason to kill this one first*, which is the same readable play morale makes
# of a champion.

## How far its influence reaches. Zero means it has none.
@export_range(0.0, 500.0) var aura_radius: float = 0.0
## Nearby allies move this much faster while it lives.
@export_range(0.0, 0.6) var aura_speed: float = 0.0
## Nearby allies take this much less while it lives. Capped low: an aura that
## approached immunity would be a wall rather than a mark.
@export_range(0.0, 0.35) var aura_resistance: float = 0.0

## A ward it is born with, in seconds, which turns one blow and is spent - the
## same guard an anchor's shelter grants.
@export_range(0.0, 60.0) var spawn_guard: float = 0.0

## The tint laid over the sprite, and the colour of the outline that marks it.
## Player-facing identity: an affix the player cannot see is one they cannot
## learn to read.
@export var mark_colour: Color = Color(0.9, 0.6, 0.3)

## Which act this may first appear in, so Act I is not answering Act III.
## The earliest act this mark may be worn in.
##
## **Was capped at 3 on a ten-act road**, so acts IV to X could never meet a mark
## authored for them and the back two thirds of the campaign wore the same eight.
## Widened 2026-09-15; the fifth hardcoded three-act range this project has found.
@export_range(1, 10) var from_act: int = 1

# --- 2026-09-25: marks that read the world, and four new ones ---------------
#
# Appended, never inserted: a mark is authored by field name, but the rule this
# project keeps is that a resource grows at its end.

## The weathers (their ids) under which this mark comes up more often. Empty
## means it does not care. The road telling you something: Rimewarded in the
## snow, Galeshod in a duststorm. Read by `EnemyMarks.roll`.
@export var favoured_weather: Array[String] = []

## **Frenzied**: below this share of its health it moves `frenzy_speed` times
## as fast. Zero means never. A number the fight already has - speed - gated on
## a number it already has - health.
@export_range(0.0, 0.6) var frenzy_below: float = 0.0
@export_range(1.0, 2.0) var frenzy_speed: float = 1.0

## **Packbound**: its aura reaches only bodies of its own breed. The same aura,
## narrowed, so a pack of one kind is a pack and a mixed wave is not.
@export var aura_kin_only: bool = false

## **Stormbound**: its death blast leaps to at most this many of the player's
## side nearest it, as lightning, instead of striking everything inside the
## radius. The blast's own damage and radius; only the shape changes.
@export_range(0, 6) var death_chain: int = 0

## **Mirrorhide**: every `tower_glance_interval` seconds, for
## `tower_glance_seconds`, tower shots glance off it. The Warden's blows never
## do - the answer to a mirror is the person, not the board.
@export_range(0.0, 4.0) var tower_glance_seconds: float = 0.0
@export_range(2.0, 20.0) var tower_glance_interval: float = 6.0


func get_sprite_path() -> String:
	return GameData.derive_path("icons/affixes", "affix_", id)
