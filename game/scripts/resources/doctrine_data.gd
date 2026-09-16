class_name DoctrineData
extends GameData

## How a Warden spends a road they did not walk.
##
## **Owner ruling, 2026-09-15**: a player may start a fresh road at any act they
## have reached, and arrives on an authored baseline whose **shape** they choose
## and whose **size** they do not. A doctrine is that shape - every one of them
## spends the same `Balance.ACT_START_BUDGET`, differently.
##
## **Nothing here is a power scale**, which is the bound this is held to and the
## same one omens, Road Cards, tower paths and gear sets are held to. A doctrine
## buys towers the player could have bought, through the same `try_build` a
## player's own build goes through - so the board it leaves is a board the road
## could have produced, at prices the road charges. Whatever it does not spend is
## handed over as Gold rather than kept, so no doctrine can be worth more than
## another by hoarding, and `act_start_check` measures the whole outfit rather
## than reading these numbers back.

## What share of the budget goes on the board at all. The rest is handed over as
## spare Gold, so this is "built for you" against "yours to spend".
@export_range(0.0, 1.0) var board_share: float = 0.70

## Of what goes on the board, how much widens it against deepening it.
##
## 1.0 spends everything on *more emplacements*; 0.0 spends everything on
## *better ones*. This is the one axis that makes two doctrines play differently
## rather than merely cost differently: breadth covers more road and depth holds
## one stretch of it.
@export_range(0.0, 1.0) var breadth: float = 0.55

## Which element this doctrine reaches for first, by **name** rather than by
## index - "fire", "water", "earth", "air", or empty for no preference.
##
## **A string on purpose.** `TowerData.Element` is an enum and this project has
## twice shipped content that indexed an enum by number and silently pointed at
## the wrong member once somebody inserted one. A name that does not resolve is
## something `act_start_check` can see; an integer that means the wrong thing is
## not.
@export var favoured_element: String = ""

## And which role, on the same terms: "skirmisher", "siege", "sniper", "warden".
@export var favoured_role: String = ""


## The element this doctrine favours, or -1 for none.
##
## Resolved by name against the live enum, so renaming a member breaks loudly
## and reordering them cannot quietly repoint every doctrine in the game.
func element_index() -> int:
	return _lookup(TowerData.Element.keys(), favoured_element)


## The role this doctrine favours, or -1 for none.
func role_index() -> int:
	return _lookup(TowerData.Role.keys(), favoured_role)


## Whether both preferences name something real. Empty is real - it means "no
## preference" - and a misspelling is not.
func names_resolve() -> bool:
	return (favoured_element.is_empty() or element_index() >= 0) \
		and (favoured_role.is_empty() or role_index() >= 0)


static func _lookup(names: Array, wanted: String) -> int:
	if wanted.is_empty():
		return -1
	var needle: String = wanted.strip_edges().to_upper()
	for index: int in names.size():
		if String(names[index]).to_upper() == needle:
			return index
	return -1
