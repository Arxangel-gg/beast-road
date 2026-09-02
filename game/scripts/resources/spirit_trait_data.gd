class_name SpiritTraitData
extends GameData

## A Spirit Companion's personality.
##
## Owner request, 2026-09-01: "two legendary foxes can actually feel different".
## A spirit's *power* comes from its variant - species, rarity, shiny - and that
## is a ladder with a ceiling (`SpiritBond.power_scale`). This is the other axis:
## how it fights, which is free of that ladder because it changes behaviour
## rather than numbers.
##
## ## Where a trait comes from
##
## The living animal carries it, decided the moment it is placed and derived from
## its own serial number, so it is fixed before the player ever sees it and both
## machines in a co-op run compute the same answer without a packet. Bonding an
## animal banks *that animal's* trait against the variant. Which trait your
## Legendary Fox has is therefore luck at the moment you met it, and is yours.
##
## ## The bound
##
## **A trait may not be a damage upgrade.** Working rule 7 keeps hero power on
## one capped scale and `SPIRIT_APEX_POWER` caps a spirit's; a personality that
## simply hit harder would be a third scale nobody is tuning against, and the
## best trait would become the only trait worth keeping.
##
## So every trait's damage is an *envelope* that trades: Timid is stronger at the
## hero's shoulder and weaker away from it, Ferocious is stronger hurt and weaker
## whole, and the two utility traits pay a flat tax for what they find. The mean
## of each envelope is one, and `spirit_trait_check` holds that - so a trait can
## change which fight a companion is good at and can never change how good it is.

## What this companion goes after first. Pure behaviour, and therefore free.
##
## `ATTACKER` answers the owner's "Protective": whatever last hit the hero.
## `PROMOTED` answers "Hunter": elites and champions before ordinary bodies.
enum Bias { NEAREST, ATTACKER, PROMOTED }

@export var bias: Bias = Bias.NEAREST

## Damage multiplier at the hero's shoulder, and out at the end of its leash.
##
## Their mean is the trait's resting worth and is held to one by the gate. A
## trait that wanted to be better in both places would be a straight upgrade.
@export_range(0.5, 1.5) var damage_near: float = 1.0
@export_range(0.5, 1.5) var damage_far: float = 1.0

## Damage multiplier at full health, and at the point of going down.
##
## Same rule, same gate. Ferocious lives here.
@export_range(0.5, 1.5) var damage_whole: float = 1.0
@export_range(0.5, 1.5) var damage_hurt: float = 1.0

## Chance one of this companion's kills leaves something extra behind.
##
## Paid for out of the damage envelope rather than added on top - a trait that
## found loot *and* fought as well as the others is the strictly-better trait
## the bound above exists to prevent.
@export_range(0.0, 0.5) var scavenge_chance: float = 0.0

## How far this companion draws loose pickups toward the hero, in pixels.
@export_range(0.0, 400.0) var reveal_radius: float = 0.0


func get_sprite_path() -> String:
	return ""


## The trait's resting worth: the mean of both envelopes, multiplied.
##
## One means "as good as having no personality at all, differently". Above one
## is a trait that is simply better and is what the gate refuses.
func resting_worth() -> float:
	return ((damage_near + damage_far) * 0.5) * ((damage_whole + damage_hurt) * 0.5)


## The damage multiplier for a companion in this situation.
##
## `closeness` is 1 at the hero's shoulder and 0 at the end of the leash;
## `health` is 1 whole and 0 about to go down.
func damage_scale(closeness: float, health: float) -> float:
	var by_distance: float = lerpf(damage_far, damage_near, clampf(closeness, 0.0, 1.0))
	var by_wound: float = lerpf(damage_hurt, damage_whole, clampf(health, 0.0, 1.0))
	return by_distance * by_wound
