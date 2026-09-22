class_name BuildTemplate
extends RefCounted

## A board a player has stood up once, kept so they can stand it up again.
##
## `docs/ROAD_TO_1_0.md` §7.2: *"With 61 towers, 'repeat my last board' is real
## quality of life on a second run."* Forty emplacements placed one click at a
## time is forty clicks somebody has already made, and the campaign is ten
## evenings long.
##
## **It is a shopping list and never a purse.** Every emplacement is bought at
## the price the road charges, through `Battlefield.try_build` and
## `try_upgrade` and through no second door - which is the same argument
## `ActStart.outfit` is built on, and the reason no economy rule had to learn
## that templates exist. Anything the purse, the board or the Forge refuses is
## simply not bought, and is said out loud by name.
##
## **Anchors are core-relative, and that is the load-bearing decision.** The
## authored 45x45 core is byte-identical on every seed, but `BattleGrid._init`
## rolls `camp_side` from the layout seed, and the outskirts it lays differ with
## it - so a tower recorded at an absolute tile can land on ground that is a
## road on the next run. `Expedition.compose` stores absolute tiles and gets
## away with it only because `Expedition.apply` restores the same seed first; a
## template is applied to a *different* seed by definition, so it must not copy
## that choice. A recorded tower outside the core is dropped when the board is
## composed rather than silently failing when it is applied: an unbuilt tower
## looks exactly like open ground.
##
## **Nothing about power is stored.** A row is a place, a kind, a level, a path
## and a targeting priority - all of them things the player bought once and
## would buy again. No currency, no seed, no wall, no relic; `balance_test`'s
## save-key guard holds that by walking the keys a row may carry.

## The keys a row may carry, and nothing else. Read by `balance_test`, so a
## purse or a seed cannot be smuggled into a template.
const ROW_KEYS: Array[String] = ["cx", "cy", "kind", "level", "path", "priority"]


## What is standing now, as a list of rows, core-relative.
##
## Towers only: traps and barricades are cheap, quick and placed by where the
## road runs, which differs by seed - a template that replayed them would be
## naming ground the run may not have.
static func compose(field: Battlefield) -> Dictionary:
	var rows: Array = []
	if field == null:
		return {}
	for key: Variant in RunState.towers.keys():
		var anchor: Vector2i = key as Vector2i
		var entry: Dictionary = RunState.towers[key] as Dictionary
		if entry == null or entry.is_empty():
			continue
		# **Wholly in the core, footprint and all.** A tower half over the line
		# is a tower whose other half is on ground the next seed may have laid
		# differently.
		if not BattleGrid.in_core(anchor) \
				or not BattleGrid.in_core(anchor + Vector2i(BattleGrid.FOOTPRINT - 1,
					BattleGrid.FOOTPRINT - 1)):
			continue
		rows.append({
			"cx": anchor.x - BattleGrid.OUTSKIRTS,
			"cy": anchor.y - BattleGrid.OUTSKIRTS,
			"kind": String(entry.get("tower_id", "")),
			"level": int(entry.get("level", 1)),
			"path": int(entry.get("path", TowerData.Path.NONE)),
			"priority": int(entry.get("target_priority",
				TowerData.TargetPriority.FIRST)),
		})
	if rows.is_empty():
		return {}
	return {"rows": rows}


## Whether a stored template is worth offering at all.
##
## Every row must name a tower this build still has. A template kept from a
## version that has since dropped a tower is read as far as it goes rather than
## refused outright, which is `Expedition.is_readable`'s own rule.
static func is_readable(stored: Dictionary) -> bool:
	return not rows_of(stored).is_empty()


## The rows of a stored template, dropping any that are malformed or name a
## tower `ContentDB` does not answer.
static func rows_of(stored: Dictionary) -> Array:
	var out: Array = []
	if stored == null or stored.is_empty():
		return out
	for entry: Variant in (stored.get("rows", []) as Array):
		var row: Dictionary = entry as Dictionary
		if row == null or row.is_empty():
			continue
		var kind: TowerData = ContentDB.tower(String(row.get("kind", "")))
		if kind == null:
			continue
		var anchor: Vector2i = anchor_of(row)
		if not BattleGrid.in_core(anchor):
			continue
		out.append(row)
	return out


## Where a row stands on this run's grid. Core-relative in, absolute out.
static func anchor_of(row: Dictionary) -> Vector2i:
	return Vector2i(int(row.get("cx", 0)) + BattleGrid.OUTSKIRTS,
		int(row.get("cy", 0)) + BattleGrid.OUTSKIRTS)


## What standing the whole board up would cost, in Gold, without spending any.
##
## Quoted through the same two functions the purchase charges, so the number on
## the button and the number taken cannot drift apart - which is the rule the
## Forge and the Quartermaster are already held to.
static func quote(stored: Dictionary) -> int:
	var total: int = 0
	for entry: Variant in rows_of(stored):
		var row: Dictionary = entry as Dictionary
		var kind: TowerData = ContentDB.tower(String(row["kind"]))
		if kind == null:
			continue
		total += Battlefield.build_cost_of(kind)
		for level: int in range(1, int(row.get("level", 1))):
			total += Battlefield.upgrade_cost_of(level)
	return total


## Stands the board up, and says what did not land.
##
## **Two passes**, because a fusion needs its neighbours standing before it can
## be offered at all - the ordinary towers first, then the combinations, which
## is the order a player building by hand takes without thinking about it.
##
## Returns `{"built": int, "refused": Array[String]}`. A refusal is a sentence
## from the one door that refused it, so a board that ran out of Gold says so in
## the game's own words rather than in this file's.
static func apply(field: Battlefield, stored: Dictionary) -> Dictionary:
	var built: int = 0
	var refused: Array[String] = []
	if field == null:
		return {"built": 0, "refused": refused}
	var rows: Array = rows_of(stored)
	for pass_fusions: bool in [false, true]:
		for entry: Variant in rows:
			var row: Dictionary = entry as Dictionary
			var kind: TowerData = ContentDB.tower(String(row["kind"]))
			if kind == null or kind.is_combination != pass_fusions:
				continue
			var anchor: Vector2i = anchor_of(row)
			# Already there - a player pressing this twice, or a board that was
			# partly standing - is not a refusal.
			if RunState.tower_at(anchor) != null:
				continue
			var problem: String = field.try_build(anchor, kind)
			if not problem.is_empty():
				refused.append("%s: %s" % [kind.display_name, problem])
				continue
			built += 1
			_raise(field, anchor, row)
	return {"built": built, "refused": refused}


## Takes one emplacement up to the level and the path it was recorded at.
##
## The path is set at `TOWER_SPECIALISE_LEVEL` and not before, because
## `RunState.set_tower_path` refuses it earlier - which is the ladder the split
## exists to put a decision on, and a template must climb it like anybody else.
static func _raise(field: Battlefield, anchor: Vector2i, row: Dictionary) -> void:
	var wanted: int = int(row.get("level", 1))
	var path: int = int(row.get("path", TowerData.Path.NONE))
	while RunState.level_at(anchor) < wanted:
		var before: int = RunState.level_at(anchor)
		if not field.try_upgrade(anchor).is_empty():
			break
		if RunState.level_at(anchor) <= before:
			break
		if path != TowerData.Path.NONE \
				and RunState.level_at(anchor) >= Balance.TOWER_SPECIALISE_LEVEL:
			RunState.set_tower_path(anchor, path)
	# **Cycled rather than set**, because `cycle_target_priority` is the only
	# door there is and it is the one the player's own click uses - it emits
	# `tower_targeting_changed`, which the tower's own readout listens for.
	# Bounded by the number of priorities, so a value this build no longer has
	# stops rather than spinning.
	var wanted_priority: int = int(row.get("priority",
		TowerData.TargetPriority.FIRST))
	for _turn: int in TowerData.TargetPriority.size():
		if RunState.target_priority_at(anchor) == wanted_priority:
			break
		RunState.cycle_target_priority(anchor)


## What to say on the button, or "" when there is nothing to offer.
static func say(stored: Dictionary) -> String:
	var rows: Array = rows_of(stored)
	if rows.is_empty():
		return ""
	return "Rebuild last board  ·  %d towers  ·  %d Gold" % [rows.size(),
		quote(stored)]
