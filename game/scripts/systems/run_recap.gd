class_name RunRecap
extends RefCounted

## What the player actually built, read back at the end of a run.
##
## Owner request, 2026-09-02: reconstruct the final build and name it, because
## that screenshot is the one people share.
##
## **Everything here is read, never recorded.** The run already knows what towers
## are standing, what is in the hero's slots and which spirit walked with them -
## so there is no new bookkeeping to keep in step, nothing extra to persist, and
## no way for the recap to disagree with the run it describes. A recap that had
## its own counters would be a second source of truth for the same facts, which
## working rule 6 exists to prevent.
##
## Pure and autoload-light on purpose, so the whole thing can be checked without
## a results screen.

## The element the player's towers settled on, or -1 if they never did.
##
## Ties go to no element, deliberately. A player with two Fire and two Water
## towers did not build a Fire run, and calling it one would be the recap
## flattering them rather than describing them.
static func dominant_element(towers: Dictionary) -> int:
	# `RunState.towers` holds entry dictionaries, not resources - `{tower_id,
	# level, target_priority}` - so the kind has to be looked up. Casting the
	# entry to `TowerData` yields null and counts nothing, which is a recap that
	# silently says every run had no element.
	var counts: Dictionary = {}
	for value: Variant in towers.values():
		var entry := value as Dictionary
		if entry == null or entry.is_empty():
			continue
		var placed: TowerData = ContentDB.tower(String(entry.get("tower_id", "")))
		if placed == null or placed.is_combination:
			continue
		counts[placed.element] = int(counts.get(placed.element, 0)) + 1
	var best: int = -1
	var best_count: int = 0
	var tied: bool = false
	for key: Variant in counts:
		var count: int = int(counts[key])
		if count > best_count:
			best_count = count
			best = int(key)
			tied = false
		elif count == best_count:
			tied = true
	return -1 if tied or best_count == 0 else best


## How the player spent the run.
##
## Towers first when there were enough of them to be the plan, then a companion
## that walked the whole way, then the hero alone. Ordered rather than scored:
## a player with four towers *and* a spirit built around the towers, and the
## threshold is what says "enough of them to be the plan" rather than "any".
static func axis_of(tower_count: int, has_companion: bool) -> RunTitleData.Axis:
	if tower_count >= Balance.RECAP_TOWER_AXIS_MINIMUM:
		return RunTitleData.Axis.TOWERS
	if has_companion:
		return RunTitleData.Axis.COMPANION
	return RunTitleData.Axis.BLADE


## The title for this run, or null when the content is missing.
static func title_for(element: int, axis: RunTitleData.Axis) -> RunTitleData:
	var fallback: RunTitleData = null
	for value: Variant in ContentDB.run_titles.values():
		var candidate := value as RunTitleData
		if candidate == null:
			continue
		if candidate.matches(element, axis):
			return candidate
		# Every axis has an elementless title, and it is the honest answer for a
		# run whose element this build does not have a name for yet.
		if candidate.element == -1 and candidate.axis == axis:
			fallback = candidate
	return fallback


## The whole recap, as plain values a screen can render without asking anything
## else. Built from `RunState` and `MetaState` at the moment the run ends.
static func build() -> Dictionary:
	var towers: Dictionary = RunState.towers
	var standing: int = 0
	for value: Variant in towers.values():
		var entry := value as Dictionary
		if entry != null and not entry.is_empty():
			standing += 1
	var element: int = dominant_element(towers)
	var spirit: String = MetaState.equipped_spirit
	var axis: RunTitleData.Axis = axis_of(standing, not spirit.is_empty())
	var title: RunTitleData = title_for(element, axis)

	# The worn pieces, named. Empty slots are left out rather than listed as
	# blanks: a recap is a portrait of what the player chose, and six lines
	# saying "none" is a portrait of what they did not.
	var worn: PackedStringArray = []
	for slot: int in GearData.Slot.size():
		var piece: Dictionary = MetaState.equipped_piece(slot)
		if piece.is_empty():
			continue
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind != null:
			worn.append(kind.display_name)

	var companion_name: String = ""
	if not spirit.is_empty():
		var species: WildlifeData = ContentDB.wildlife_kinds.get(
			SpiritBond.species_of(spirit), null) as WildlifeData
		if species != null:
			companion_name = SpiritBond.display_name(species,
				SpiritBond.rarity_of(spirit), SpiritBond.shiny_of(spirit))
			var temperament: SpiritTraitData = SpiritBond.trait_of_bond(spirit)
			if temperament != null:
				companion_name += " (%s)" % temperament.display_name

	return {
		"title": "" if title == null else title.display_name,
		"flavour": "" if title == null else title.description,
		"element": element,
		"axis": int(axis),
		"towers": standing,
		"worn": worn,
		"companion": companion_name,
		"level": MetaState.hero_level,
	}
