class_name Synergies
extends RefCounted

## Which authored synergies are live, and the one list that says a synergy is
## real rather than decorative.
##
## The same shape as `DisciplineEffects`, for the same reason. That file exists
## because twenty-one discipline effects were authored, described to the player,
## priced in a skill point, and read by nothing - and no gate could tell,
## because an effect nothing reads looks exactly like one that works. A synergy
## is *more* prone to it, not less: it fires only when two specific nodes are
## both trained, which is a state most testing never reaches.
##
## So every authored synergy id must appear in `IMPLEMENTED` below, and
## `synergy_check` fails the build if one appears in neither list. Adding a key
## here without a consumer is the exact lie both files exist to prevent, and no
## gate can catch that one - do not add a key until something reads it.

## Synergies with a live consumer.
const IMPLEMENTED: Array[String] = [
	"second_wind",
	"the_watch_answers",
	"break_their_grip",
]

## Authored and not yet read by anything. Empty, and the intention is that it
## stays empty: unlike the discipline effects, this system started with its
## consumers written, so there is no debt to pay down here. The list exists so
## that a half-finished synergy has somewhere honest to sit for a day rather
## than being quietly shipped as working.
const DECLARED_ONLY: Array[String] = []


## Whether every effect this synergy needs is trained.
##
## Trained rather than equipped, deliberately. Only one node sits in each of the
## four slots, and the three finisher effects are all Attack-slot effects - so a
## synergy between two of *those* could never fire at all, by construction. The
## four effects these synergies are built from are all read from the trained
## list, which is what makes the combinations reachable.
static func active(synergy_id: String) -> bool:
	var data: SynergyData = ContentDB.synergy(synergy_id)
	if data == null or data.requires.is_empty():
		return false
	for effect_id: String in data.requires:
		if not DisciplineEffects.trained(effect_id):
			return false
	return true


## How many of this synergy's requirements are trained, for the sheet. A player
## looking at "1 of 2" is a player with something to aim at.
static func progress(synergy_id: String) -> int:
	var data: SynergyData = ContentDB.synergy(synergy_id)
	if data == null:
		return 0
	var done: int = 0
	for effect_id: String in data.requires:
		if DisciplineEffects.trained(effect_id):
			done += 1
	return done


static func all_sorted() -> Array[SynergyData]:
	var ids: Array = ContentDB.synergies.keys()
	ids.sort()
	var out: Array[SynergyData] = []
	for id: Variant in ids:
		var data := ContentDB.synergies[id] as SynergyData
		if data != null:
			out.append(data)
	return out


## The synergies a player is at least halfway to, for the sheet's summary line.
## A list of everything would be a wall; a list of what is nearly in reach is a
## plan.
static func in_reach() -> Array[SynergyData]:
	var out: Array[SynergyData] = []
	for data: SynergyData in all_sorted():
		if progress(data.id) > 0 and not active(data.id):
			out.append(data)
	return out
