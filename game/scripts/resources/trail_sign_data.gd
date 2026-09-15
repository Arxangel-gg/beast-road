class_name TrailSignData
extends GameData

## One thing a mythical animal leaves behind.
##
## **The trail before the creature.** `docs/IDEAS_REVIEW_2026-09-15.md` triaged
## a proposal for 112 mythical animals and concluded that the best idea in it is
## not a creature at all: **Evidence -> Tracking -> Encounter**. Claw marks,
## then a stripped sapling, then a bed of flattened grass, then the thing
## itself. It multiplies what is already built - the fog hides what has not been
## seen, the wrath speaks in signs rather than in a bar, the raccoon already
## hides and breaks cover - rather than adding a system beside them. A creature
## you simply walk into is a bigger boar.
##
## A sign is a **place and a sentence**, and nothing else. It grants nothing,
## costs nothing, and is read by walking near it: no button, because a trail the
## player has to press a key at is an errand rather than a thing they noticed.
##
## **The art convention applies** (CLAUDE.md §4): a sign's picture is derived
## from its id, so adding one is a `.tres` and a PNG.

## How near the encounter this sign belongs, from 0 (the first thing you find,
## far from the animal) upward. The trail deals one of each stage in order, so a
## species whose signs are all stage 0 has a trail that never gets warmer.
@export_range(0, 8) var stage: int = 0

## What the Warden makes of it. Shown once, when it is read.
##
## Player-facing and therefore in data (working rule 9). Written as an
## observation rather than as an instruction - "something stripped the bark from
## this sapling, head-high" rather than "track the Moonstag north" - because the
## whole of this feature is the player working it out.
@export_multiline var reading: String = ""

## Which species leaves it, or empty for any. A hollowhorn's kill and a
## moonstag's scrape are not the same sign and should not be dealt to the wrong
## animal's trail.
@export var species: String = ""

## How big it is drawn, against its own painting.
@export_range(0.2, 4.0) var scale: float = 1.0


## Whether this sign may appear on the given species' trail at the given stage.
func suits(species_id: String, at_stage: int) -> bool:
	if stage != at_stage:
		return false
	return species.is_empty() or species == species_id


func get_sprite_path() -> String:
	return GameData.derive_path("battlefield", "sign_", id)
