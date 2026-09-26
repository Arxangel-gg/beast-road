class_name WaysideChoiceData
extends GameData

## One answer to a wayside encounter: what it costs, what it gives, and what it
## sets loose. See `WaysideData`.
##
## **A boon and a bane, each one existing door.** Two slots rather than a list,
## because a choice that did four things would be a system wearing a card's
## clothes - and because a gate can hold two named effects against the purse,
## the stash, the journal and the earth, where it could not hold an open list.

## What a choice gives, or sets loose. Each is a door that already exists;
## `Wayside._apply` is the one place they are opened.
##
## **Appended to, never inserted into**: a choice's `.tres` names these by
## number, and this project has twice shipped content pointing at the wrong
## member because an enum grew in the middle.
enum Effect {
	NOTHING,
	## `boon_amount` of `boon_currency`, scaled by the act as a kill is, laid on
	## the ground as pieces for the Warden to pick up.
	CURRENCY,
	## One piece of gear per whole `boon_amount`, rolled on the stash tables at
	## the tier being played, laid on the ground.
	GEAR,
	## `boon_amount` sightings of the encounter's animal toward its bond, through
	## `MetaState.record_spirit_encounter`. Only on an ANIMAL encounter.
	SIGHTING,
	## A share of the Warden's health, through `Health.heal`.
	HEAL,
	## A share of what the Warden's next level costs, through `gain_hero_xp`.
	EXPERIENCE,
	## The species sends its worst after the Warden: the encounter's own animal,
	## or the region's predator for a prop. The savage over-farming already sends.
	SAVAGE,
	## The earth notices: `amount` of wrath heat, as that many common kills.
	WRATH,
}

## The button.
@export var label: String = ""
## Under the button: what taking it gives and risks, in the world's words.
@export var hint: String = ""
## Said once it is done.
@export_multiline var outcome: String = ""
## An empty currency is a choice that costs nothing.
@export var cost_currency: String = ""
@export var cost_amount: int = 0
@export var boon: Effect = Effect.NOTHING
## Only for CURRENCY.
@export var boon_currency: String = ""
@export var boon_amount: float = 0.0
@export var bane: Effect = Effect.NOTHING
@export var bane_amount: float = 0.0


## The price as the purse reads it, or empty for free.
func cost() -> Dictionary:
	if cost_currency.is_empty() or cost_amount <= 0:
		return {}
	return {cost_currency: cost_amount}
