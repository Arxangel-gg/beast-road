class_name Expedition
extends RefCounted

## A frontier the Warden can come back to.
##
## **Owner brief, 2026-09-15:** *"if a player successfully extracts, they will be
## able to start the next run fresh from there with the same resources they had
## when they left that run ... all of the towers and their placements will be
## restored including their levels and basically loading that world state back,
## except for the wildlife and foliage etc, kinda resetting it clean and ready to
## be tried again."*
##
## **Two layers, and the split is the whole design.**
##
## - **Persistent**: the seed, the act, the wave, every tower with its level, its
##   chosen path and *how damaged it is*, the run's currencies, the wall, and how
##   far the party pushed without banking. This is what makes a fortress the
##   physical history of a campaign.
## - **Regenerated**: the wildlife, the foliage, the corpses, the drops, the
##   weather and every other living thing. `Battlefield.refresh_terrain` already
##   is that half - it is the one function everything regional goes through - so
##   coming back is the road being alive again rather than a battlefield frozen
##   in amber since Tuesday.
##
## **What it does *not* carry is the reason this is not a second save game.**
## Nothing here reaches `MetaState`'s own rules: no hero level, no gear, no
## attribute, no unlock. Working rule 7's list is untouched. An expedition is the
## *road* put down and picked up again - a run that was paused rather than a
## second account - and everything the account owns is still owned by the
## account.
##
## **Versioned, because a snapshot is a promise about a generator.** `VERSION`
## rises when the shape of what is stored changes in a way an old snapshot could
## not honestly be read into; an expedition from before that is retired rather
## than half-applied, which is the same argument `Phenotype.VERSION` makes.

## The shape of a stored expedition. Raise it when an old one could no longer be
## read into the current game without lying about what it restores.
const VERSION: int = 1


## **Take a photograph of the road as it stands.**
##
## Called at an extraction and nowhere else: a snapshot taken mid-wave would be a
## save-scum, and the whole tension of the crossroads is that what happened since
## the last one is at risk.
static func compose(field: Battlefield, name: String = "") -> Dictionary:
	var towers: Array[Dictionary] = []
	for key: Variant in RunState.towers:
		var anchor := key as Vector2i
		var entry: Dictionary = RunState.tower_entry(anchor)
		if entry.is_empty():
			continue
		towers.append({
			"x": anchor.x,
			"y": anchor.y,
			"kind": String(entry.get("tower_id", "")),
			"level": int(entry.get("level", 1)),
			"path": int(entry.get("path", TowerData.Path.NONE)),
			"priority": int(entry.get("target_priority", 0)),
			# **How hurt it is comes home with it.** Extraction that repaired
			# every emplacement would make the correct play "leave the moment
			# anything is damaged", and attrition would stop existing.
			#
			# Read off the live node, because tower health lives there and has
			# never been in `RunState` - it does not cross the wire either.
			"health": _health_of(field, anchor),
		})
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return [int(a["x"]), int(a["y"])] < [int(b["x"]), int(b["y"])])
	var purse: Dictionary = {}
	for id: String in RunState.CURRENCIES:
		purse[id] = RunState.currency(id)
	return {
		"version": VERSION,
		"seed": RunState.run_seed,
		"act": RunState.act,
		"wave": RunState.wave_number,
		"distance": RunState.distance_travelled,
		"towers": towers,
		"purse": purse,
		"wall": RunState.town_hp / maxf(RunState.town_max_hp, 1.0),
		"momentum": RunState.momentum,
		"tier": RunState.tier_id,
		"name": name,
	}


## How hurt one standing tower is, or whole when there is no field to ask.
static func _health_of(field: Battlefield, anchor: Vector2i) -> float:
	if field == null or not field.has_method("tower_at_anchor"):
		return 1.0
	var built: Tower = field.tower_at_anchor(anchor)
	if built == null or not is_instance_valid(built):
		return 1.0
	return clampf(built.health_ratio(), 0.05, 1.0)


## Whether a stored expedition can be read into this build.
##
## A snapshot from a newer version, or one naming content that no longer exists,
## is refused rather than half-applied: half a fortress is worse than none,
## because the player cannot tell which half is missing.
static func is_readable(stored: Dictionary) -> bool:
	if stored.is_empty():
		return false
	if int(stored.get("version", 0)) != VERSION:
		return false
	if int(stored.get("wave", 0)) <= 0 or int(stored.get("act", 0)) <= 0:
		return false
	for tower: Variant in (stored.get("towers", []) as Array):
		var row := tower as Dictionary
		if row == null or ContentDB.tower(String(row.get("kind", ""))) == null:
			return false
	return true


## **Put the road back down.**
##
## Applied to `RunState` *after* its reset and *before* the field is built, so
## the battlefield stands the towers up the same way it does for a guest being
## handed a host's world - through `_sync_towers`, which is the one path that
## makes a tower node. A second application path is a second thing that can
## drift.
static func apply(stored: Dictionary) -> bool:
	if not is_readable(stored):
		return false
	RunState.set_seed(int(stored.get("seed", 0)))
	RunState.act = int(stored.get("act", 1))
	RunState.wave_number = int(stored.get("wave", 1))
	RunState.distance_travelled = float(stored.get("distance", 0.0))
	RunState.momentum = float(stored.get("momentum", 0.0))
	RunState.towers.clear()
	for tower: Variant in (stored.get("towers", []) as Array):
		var row := tower as Dictionary
		var anchor := Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
		RunState.towers[anchor] = {
			"tower_id": String(row.get("kind", "")),
			"level": int(row.get("level", 1)),
			"target_priority": int(row.get("priority", 0)),
			"path": int(row.get("path", TowerData.Path.NONE)),
		}
		# Waits for the node that is about to be built, which is the only place
		# tower health lives.
		RunState.tower_health_restore[anchor] = clampf(
			float(row.get("health", 1.0)), 0.05, 1.0)
	var purse: Dictionary = stored.get("purse", {}) as Dictionary
	for id: String in RunState.CURRENCIES:
		RunState.currencies[id] = int(purse.get(id, 0))
	RunState.tier_id = String(stored.get("tier", RunState.tier_id))
	# **The wall comes back as hurt as it was.** Same argument as the towers:
	# a wall that healed on extraction is a wall nobody ever has to mend.
	RunState.town_hp = RunState.town_max_hp \
		* clampf(float(stored.get("wall", 1.0)), 0.05, 1.0)
	return true


## What the front looks like on a menu: "Act IV · Wave 37".
static func describe(stored: Dictionary) -> String:
	if not is_readable(stored):
		return ""
	var named: String = String(stored.get("name", ""))
	var where: String = "Act %d · Wave %d" % [
		int(stored.get("act", 1)), int(stored.get("wave", 1))]
	return where if named.is_empty() else "%s · %s" % [named, where]


## How many towers the fortress holds, and how many of them are hurt. For the
## menu and for the repair screen.
static func fortifications(stored: Dictionary) -> Vector2i:
	var standing: int = 0
	var hurt: int = 0
	for tower: Variant in (stored.get("towers", []) as Array):
		var row := tower as Dictionary
		if row == null:
			continue
		standing += 1
		if float(row.get("health", 1.0)) < 0.999:
			hurt += 1
	return Vector2i(standing, hurt)
