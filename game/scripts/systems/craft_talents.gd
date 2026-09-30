class_name CraftTalents
extends RefCounted

## **The talents a Warden keeps, read where each craft makes its own numbers**
## (2026-09-30). One door, `value`, for every reader: a talent the Warden has
## not chosen, a talent of another craft and a key nobody authored all read as
## nothing, so a craft with no talent chosen is exactly what it was.
##
## Personal in co-op as every craft is: a talent is this machine's Warden's, and
## what it moves - a wait, a swing, a seam's gem, a crop's tolerance - is that
## Warden's own work, never the run's purse.


## The share (or, for a count key, the count) this Warden's chosen talents of
## `craft` add to `key`, capped either way at `Balance.CRAFT_TALENT_CEILING`
## for a share.
static func value(craft: String, key: String) -> float:
	var total: float = 0.0
	for id: String in MetaState.craft_talents:
		var talent: CraftTalentData = ContentDB.craft_talent(id)
		if talent != null and talent.craft == craft and talent.key == key:
			total += talent.amount
	if key in COUNTED:
		return total
	return clampf(total, -Balance.CRAFT_TALENT_CEILING, Balance.CRAFT_TALENT_CEILING)


## Keys that count whole things rather than scale a number.
const COUNTED: Array[String] = ["swings"]


## The two a craft offers at `level`, in a stable order.
static func offered(craft: String, level: int) -> Array[CraftTalentData]:
	var out: Array[CraftTalentData] = []
	for value_: Variant in ContentDB.craft_talents.values():
		var talent := value_ as CraftTalentData
		if talent != null and talent.craft == craft and talent.level == level:
			out.append(talent)
	out.sort_custom(func(a: CraftTalentData, b: CraftTalentData) -> bool:
		return a.id < b.id)
	return out
