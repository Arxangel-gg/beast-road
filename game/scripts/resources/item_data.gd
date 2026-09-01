class_name ItemData
extends GameData

## A carried consumable (GDD v4 §29, §698).
##
## v4 is explicit that "Relics, Resurrection Draughts, tower blueprints, and
## Oathbound leaders are items or unlock IDs, not currencies" — an item is a
## thing the player is holding, with a carry limit, not a number in a wallet.
##
## `id = "resurrection_draught"` -> `res://art/icons/ui/ui_resurrection_draught.png`
## by the usual path convention.

## What holding one *does*, as a semantic key rather than an id.
##
## **This is what made the header above true.** It claimed "a second consumable
## is a file, not an edit to the reward code", and that was not so: the Draught's
## whole behaviour was `RunState.has_resurrection_draught`, a bool, consumed by
## `if item_id == "resurrection_draught"`. That is exactly the
## `if enemy_name == "bogkin"` shape working rule 3 forbids, and it meant the
## second item could never be authored - only implemented.
##
## An effect key plus a bounded magnitude is the same pattern `BuildingData` and
## `DisciplineNodeData` already use, so a new consumable is a `.tres`, an icon,
## and at most one arm added to a `match`.
## **Only effects the game has a concept for.** A PURGE arm was written here and
## removed before it shipped: the hero carries no statuses to clear, so an item
## bearing it would have been authorable, takeable, drawable in the HUD, and
## completely inert. An enum arm nothing can implement is a promise to a designer
## that nothing keeps - `item_check` now fails the build on one.
enum Effect {
	## Prevents the next lethal down and restores `effect_value` of maximum HP.
	REVIVE,
	## Restores `effect_value` of maximum HP the moment it is used.
	MEND,
	## Adds `effect_value` of maximum HP to the shield pool, spent before health.
	WARD,
}

@export var effect: Effect = Effect.REVIVE

## Bounded magnitude, read as a fraction of maximum HP by the effects that want
## one and ignored by the ones that do not.
@export_range(0.0, 3.0, 0.01) var effect_value: float = 0.40

## Whether the item spends itself the moment its condition is met, rather than
## waiting to be used. The Draught does: it is an insurance policy, not a button.
@export var automatic: bool = true

## How many the player may hold at once. v4 caps the Draught at one so it stays
## an emergency rather than a stack of extra lives.
@export var carry_limit: int = 1

## The line shown when one is awarded.
@export_multiline var acquire_line: String = ""

## Chance a full raid clear yields one, 0..1. Rarity is data, not a branch in the
## raid: a second consumable is a file, not an edit to the reward code.
@export_range(0.0, 1.0, 0.01) var raid_clear_chance: float = 0.0


## Where this item's icon belongs, by the usual convention.
##
## The Resurrection Draught ships at the path this returns, and its manifest row
## keeps the convention covered by the production-art gate.
func get_sprite_path() -> String:
	if id.is_empty():
		return ""
	return "res://art/icons/ui/ui_%s.png" % id


## What the effect does, in the player's words. Data rather than a UI branch, so
## a new consumable describes itself everywhere it is drawn.
func effect_line() -> String:
	match effect:
		Effect.REVIVE:
			return "Prevents the next lethal down and restores %d%% health." \
				% int(effect_value * 100.0)
		Effect.MEND:
			return "Restores %d%% health." % int(effect_value * 100.0)
		Effect.WARD:
			return "Absorbs damage equal to %d%% of your health." \
				% int(effect_value * 100.0)
		_:
			return "Clears every status you are carrying."
