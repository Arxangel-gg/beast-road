class_name SynergyData
extends GameData

## Two trained nodes that do something together they do not do apart.
##
## Stage two of the owner's skill-tree brief (2026-09-08, ruled "do all three,
## in that order"). Stage one gave the trees paths; this gives them reasons to
## take a *particular* path rather than the deepest one.
##
## **The hard constraint, and it is recorded in CLAUDE.md.** The paths decision
## is bounded by "depth buys access, never power - if depth ever starts granting
## magnitude, that is a third power scale beside levelling and gear and it needs
## its own decision". A synergy that read "four Blood nodes, so every Blood
## effect is twenty per cent stronger" is exactly that scale, arriving through a
## side door.
##
## So **no synergy in this system raises a number.** Every one of them changes
## *when* an effect that already exists fires, or *what it fires on*. The
## magnitudes stay the ones the nodes themselves authored, on the same capped
## scales as everything else. That is a real, felt reward - a Howler kill
## refilling your attack speed changes how you fight - and it is not a fourth
## power curve for somebody to tune later.
##
## The price is honest either way: a synergy costs both its nodes, which is two
## skill points and two lots of Food that could have bought breadth instead.
##
## **Requirements are effect ids, not node ids.** A node is a container; the
## effect is the thing the game reads. Naming effects means re-authoring which
## node carries an effect does not silently break a synergy, and it is the same
## key `DisciplineEffects` already indexes.

## The effect ids that must all be trained. Two is the intended shape; the array
## is not capped at two because a three-way is a data decision rather than a
## code one, but see `synergy_check` - every entry must be a real authored
## effect and every synergy must be reachable.
@export var requires: Array[String] = []

## The line shown to a player who has one half and not the other. This is the
## whole point of the system being visible: a synergy nobody can see coming is
## not a build, it is a surprise.
@export_multiline var hint: String = ""


## Synergies are read, never drawn, so they have no sprite of their own. The
## disciplines that carry them do.
func get_sprite_path() -> String:
	return ""
