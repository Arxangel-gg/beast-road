class_name WardenSheet
extends RefCounted

## **What a Warden brings to a fight**, for a Warden this machine does not own
## (2026-09-26, `docs/COOP_DESIGN.md` §11).
##
## The host simulates every hero, and its copy of a guest's Warden read the
## host's own account for everything that Warden is: the attributes, the gear
## under them, the affixes and set tiers on the Warden's numbers, the ascension
## rank, the chain form, every learned node and the four skills. A level-1 guest
## fought as a level-100 host. So a guest tells the host its sheet - as it
## already tells its dye and its gear - and the host's copy of that Warden reads
## it here.
##
## **Facts about the account travel, never numbers derived from them.** The
## level, the placed points, the ascension rank, the nodes and the worn pieces
## cross; the gear's attribute points, legendary affixes and set tiers are
## worked out on arrival from the pieces, with the same `Stash` functions the
## owner's machine uses. A piece's affixes are rolled from its own `uid`, so both
## machines agree without a packet carrying a figure.
##
## **One door for every read.** The static readers below take a sheet that may
## be null, and null means *this machine's own Warden*: the exact expression each
## call site used before. A solo road and the host's own hero read the numbers
## they always read by construction, and `warden_sheet_check` walks the hero's
## scripts for any read that goes round this door.

## The row's shape, by position. Appended to, never inserted into: a row from an
## older build is short, and a short row is a Warden with less on the sheet.
const AT_LEVEL: int = 0
const AT_PLACED: int = 1
const AT_ASCENSION: int = 2
const AT_FORM: int = 3
const AT_LEARNED: int = 4
const AT_LOADOUT: int = 5
const AT_WORN: int = 6
## Appended 2026-09-28: how many Oaths this Warden may hold (Gatebroken). An
## older row has none and reads as one.
const AT_OATHS: int = 7

## The most nodes a row may name before it is read at all. Well past the whole
## tree; a row longer than this is not a Warden, it is a packet to refuse.
const LEARNED_READ_MAX: int = 256
const WORN_READ_MAX: int = 16

var level: int = 1
## The seat the Warden sits in, set by the host when it wears the sheet: what
## finds that Warden's own augment cards (`Modifiers.seat_value`).
var slot: int = 0
var placed: Array[int] = [0, 0, 0, 0, 0]
var ascension: int = 0
var form: String = ""
## Every node the Warden holds, the free starters included, by id.
var learned: Dictionary = {}
## How many Oaths the row said its Warden may hold, 1 or 2.
var oaths_allowed: int = 1
var loadout: Array[String] = ["", "", "", ""]
## The pieces worn, one a slot at most, each `{kind, rarity, level, uid}`.
var worn: Array[Dictionary] = []

## Worked out once on arrival, never sent.
var _gear_points: Array[int] = [0, 0, 0, 0, 0]
var _gear_totals: Dictionary = {}
## The node carrying each learned effect, found once rather than walked on every
## swing - the fight asks this on every blow the Warden lands.
var _by_effect: Dictionary = {}


# --- Packing this machine's own Warden ----------------------------------------

## This machine's Warden as a row, for telling the host.
static func pack_mine() -> Array:
	var tree: Array = []
	for key: Variant in MetaState.discipline_tree:
		# A rank rides the id as "id:3" (2026-09-28); a bare id is rank one, which
		# is what an older build sends and reads.
		var rank: int = MetaState.discipline_rank(String(key))
		tree.append(String(key) if rank <= 1 else "%s:%d" % [key, rank])
	tree.sort()
	var pieces: Array = []
	for piece: Dictionary in MetaState.worn_pieces():
		pieces.append({
			"kind": String(piece.get("kind", "")),
			"rarity": int(piece.get("rarity", 0)),
			"level": int(piece.get("level", 1)),
			"uid": int(piece.get("uid", 0)),
			"gems": Stash.gems(piece),
		})
	return [
		MetaState.hero_level,
		MetaState.hero_attributes.duplicate(),
		MetaState.ascension,
		MetaState.discipline_form,
		tree,
		MetaState.discipline_loadout.duplicate(),
		pieces,
		MetaState.oaths_allowed(),
	]


# --- Reading a partner's row ---------------------------------------------------

## A partner's sheet, **cleaned by the rules a hand-edited save is read under**:
## it can only ever describe a Warden the game could have produced. Anything
## that is not a row reads as a bare level-one Warden.
static func from_row(row: Variant) -> WardenSheet:
	var sheet := WardenSheet.new()
	var given: Array = row if row is Array else []
	sheet.level = clampi(_int_at(given, AT_LEVEL, 1), 1, Balance.HERO_MAX_LEVEL)
	sheet._read_placed(_array_at(given, AT_PLACED))
	sheet.ascension = clampi(_int_at(given, AT_ASCENSION, 0), 0, Balance.ASCENSION_MAX)
	sheet._read_worn(_array_at(given, AT_WORN))
	sheet.oaths_allowed = clampi(_int_at(given, AT_OATHS, 1), 1, Balance.OATHS_GATEBROKEN)
	sheet._read_learned(_array_at(given, AT_LEARNED))
	sheet._read_form(_string_at(given, AT_FORM))
	sheet._read_loadout(_array_at(given, AT_LOADOUT))
	sheet._derive_gear()
	return sheet


## Placed points, trimmed to what the level could ever have granted - the save's
## own line (`MetaState._read_hero`): `level - 1`, taken off the last attribute
## first so a trimmed row is still a row somebody could have placed.
func _read_placed(values: Array) -> void:
	placed = [0, 0, 0, 0, 0]
	for i: int in mini(values.size(), placed.size()):
		placed[i] = maxi(_as_int(values[i], 0), 0)
	var over: int = -(level - 1)
	for value: int in placed:
		over += value
	var i: int = placed.size() - 1
	while over > 0 and i >= 0:
		var taken: int = mini(placed[i], over)
		placed[i] -= taken
		over -= taken
		i -= 1


## Pieces: a kind this build has, in its own slot, one a slot, within the
## stash's rarity and level bounds. The `uid` is kept because the affixes are
## rolled from it; a piece without one rolls as uid zero rather than as a
## fresh random name, which would make the same sword two swords.
func _read_worn(values: Array) -> void:
	worn = []
	var slots: Dictionary = {}
	for value: Variant in values.slice(0, WORN_READ_MAX):
		if not value is Dictionary:
			continue
		var raw: Dictionary = value
		var kind_id: String = String(raw.get("kind", "")) if raw.get("kind", "") is String else ""
		var kind: GearData = ContentDB.gear(kind_id) if not kind_id.is_empty() else null
		if kind == null or slots.has(kind.slot):
			continue
		slots[kind.slot] = true
		var piece: Dictionary = {
			"kind": kind_id,
			"rarity": clampi(_as_int(raw.get("rarity", 0), 0), 0, Stash.RARITY_NAMES.size() - 1),
			"level": clampi(_as_int(raw.get("level", 1), 1), 1, Stash.MAX_LEVEL),
			"uid": _as_int(raw.get("uid", 0), 0),
		}
		# Gems, cleaned as the save reads them: a real gem, no more than the
		# rarity's sockets. A row from an older build carries none.
		var gems: Array = []
		if raw.get("gems", null) is Array:
			for gem_id: Variant in raw["gems"] as Array:
				var gem: MaterialData = ContentDB.material(String(gem_id)) if gem_id is String else null
				if gem != null and gem.kind == MaterialData.Kind.GEM and gems.size() < Stash.sockets(piece):
					gems.append(String(gem_id))
		if not gems.is_empty():
			piece["gems"] = gems
		worn.append(piece)


## Nodes: ones this build has, then no more than the most points that level
## could ever have bought, then none that no order of learning could reach, then
## no two that exclude each other. The starters are always held.
func _read_learned(values: Array) -> void:
	learned = {}
	for id: String in Balance.DISCIPLINE_STARTERS:
		if ContentDB.discipline_node(id) != null:
			learned[id] = 1
	var tree: Array[String] = []
	var ranks: Dictionary = {}
	for value: Variant in values.slice(0, LEARNED_READ_MAX):
		var text: String = String(value) if value is String else ""
		var id: String = text.get_slice(":", 0)
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if id.is_empty() or learned.has(id) or tree.has(id) or node == null:
			continue
		tree.append(id)
		ranks[id] = clampi(int(text.get_slice(":", 1)) if text.contains(":") else 1, 1, maxi(node.ranks, 1))
	# Trimmed to the points the level could have earned, ranks counted, off
	# the end - a rank first, then the node.
	var most: int = points_ceiling(level)
	var spent: int = 0
	for id: String in tree:
		spent += int(ranks[id])
	while spent > most and not tree.is_empty():
		var last: String = tree[tree.size() - 1]
		if int(ranks[last]) > 1:
			ranks[last] = int(ranks[last]) - 1
		else:
			tree.remove_at(tree.size() - 1)
			ranks.erase(last)
		spent -= 1
	var exclusive: Dictionary = {}
	var kept: Array[String] = []
	for id: String in tree:
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if not node.exclusive.is_empty():
			var allowed: int = oaths_allowed if node.is_oath() else 1
			if int(exclusive.get(node.exclusive, 0)) >= allowed:
				continue
			exclusive[node.exclusive] = int(exclusive.get(node.exclusive, 0)) + 1
		kept.append(id)
	var held: Array[String] = []
	for id: Variant in learned:
		held.append(String(id))
	held.append_array(kept)
	var stranded: String = MetaState.stranded_node(held, ranks)
	while not stranded.is_empty() and kept.has(stranded):
		kept.erase(stranded)
		held.erase(stranded)
		ranks.erase(stranded)
		stranded = MetaState.stranded_node(held, ranks)
	for id: String in kept:
		learned[id] = int(ranks[id])
	_by_effect = {}
	for id: String in Balance.DISCIPLINE_STARTERS:
		_index_effect(id)
	for id: Variant in learned:
		_index_effect(String(id))


## The first node found for an effect wins, starters first - the order
## `MetaState._learned_with_effect` walks, so a sheet and the save it came from
## agree about which node answers.
func _index_effect(id: String) -> void:
	var node: DisciplineNodeData = ContentDB.discipline_node(id)
	if node != null and learned.has(id) and not node.effect_id.is_empty() \
			and not _by_effect.has(node.effect_id):
		_by_effect[node.effect_id] = node


func _read_form(id: String) -> void:
	var node: DisciplineNodeData = ContentDB.discipline_node(id) if not id.is_empty() else null
	# Any form: taking one up is free (2026-09-30), so a partner's form is not a
	# node they had to learn. What a form is worth is its own data either way.
	form = id if node != null and node.is_form() else Balance.DISCIPLINE_STARTING_FORM


## A slot keeps its node only when the Warden holds it and it fits that slot:
## `MetaState._clean_loadout`'s rule.
func _read_loadout(values: Array) -> void:
	loadout = ["", "", "", ""]
	for slot: int in mini(values.size(), loadout.size()):
		var id: String = String(values[slot]) if values[slot] is String else ""
		var node: DisciplineNodeData = ContentDB.discipline_node(id) if not id.is_empty() else null
		if node != null and learned.has(id) and node.slot_index() == slot:
			loadout[slot] = id


func _derive_gear() -> void:
	_gear_points = [0, 0, 0, 0, 0]
	for piece: Dictionary in worn:
		var kind: GearData = ContentDB.gear(String(piece["kind"]))
		for affix: Dictionary in Stash.affixes(piece, kind):
			var which: int = int(affix["attribute"])
			if which >= 0 and which < _gear_points.size():
				_gear_points[which] += int(affix["points"])
	_gear_totals = Modifiers.gear_totals(worn)


## The most nodes a Warden of this level could hold beyond the starters: every
## point the level grants and every first clear there is to have.
## The tags the Warden's learned nodes carry, for the deck's lean in a seat
## the host deals for (`AugmentSeat.learned_tags`).
func tags() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in learned:
		var node: DisciplineNodeData = ContentDB.discipline_node(String(id))
		if node == null:
			continue
		for tag: String in node.tags:
			if not out.has(tag):
				out.append(tag)
	return out


static func points_ceiling(of_level: int) -> int:
	return MetaState.skill_points_for_level(of_level) \
		+ ContentDB.tiers.size() * (Balance.ACT_COUNT + 1) * Balance.SKILL_POINTS_PER_FIRST_CLEAR


# --- The one door --------------------------------------------------------------

## An attribute, placed and worn together.
static func attribute_of(sheet: WardenSheet, which: int) -> int:
	if sheet == null:
		return RunState.attribute(which)
	if which < 0 or which >= sheet.placed.size():
		return 0
	return sheet.placed[which] + sheet._gear_points[which]


## **How many perk tiers an attribute has reached** (docs/GEAR_REWORK_2026-09-28.md
## §2): placed and worn together over the threshold, to the ceiling. A partner's
## sheet answers for the partner, so the host's copy of a guest reads the
## guest's thresholds.
static func perk_tiers(sheet: WardenSheet, which: int) -> int:
	return clampi(attribute_of(sheet, which) / Balance.ATTRIBUTE_THRESHOLD, 0,
		Balance.ATTRIBUTE_PERK_TIERS)


## What an attribute's perk is worth to this Warden: its tiers times the share
## one tier is authored at. Nought with no tier, and nought for an attribute
## with no perk authored.
static func perk_of(sheet: WardenSheet, which: int) -> float:
	var tiers: int = perk_tiers(sheet, which)
	if tiers <= 0:
		return 0.0
	var perk: AttributePerkData = ContentDB.attribute_perk(which)
	return float(tiers) * perk.per_tier if perk != null else 0.0


## A Warden key's summed magnitude: the part of the table everybody shares, and
## this Warden's own gear. Any other key is the board's and is read whole.
static func value_of(sheet: WardenSheet, key: String) -> float:
	if sheet == null or not Modifiers.WARDEN_KEYS.has(key):
		return Modifiers.value(key)
	return Modifiers.value(key) - Modifiers.own_value(key) \
		+ float(sheet._gear_totals.get(key, 0.0)) + Modifiers.seat_value(sheet.slot, key)


static func multiplier_of(sheet: WardenSheet, key: String) -> float:
	if sheet == null or not Modifiers.WARDEN_KEYS.has(key):
		return Modifiers.multiplier(key)
	return 1.0 + value_of(sheet, key)


static func trained_value_of(sheet: WardenSheet, effect_id: String) -> float:
	if sheet == null:
		return DisciplineEffects.trained_value(effect_id)
	var node: DisciplineNodeData = sheet._learned_with_effect(effect_id)
	return node.effect_value * float(maxi(int(sheet.learned.get(node.id, 1)), 1)) \
		if node != null else 0.0


## What a Warden's branches do to one skill or form, by key - bounded, see
## `DisciplineUpgrades`. Null is this machine's own Warden.
static func upgrade_of(sheet: WardenSheet, skill_id: String, key: String) -> float:
	return DisciplineUpgrades.value(
		MetaState.discipline_tree if sheet == null else sheet.learned, skill_id, key)


## The same for whichever learned skill casts a spell.
static func spell_upgrade_of(sheet: WardenSheet, spell_id: String, key: String) -> float:
	return DisciplineUpgrades.for_spell(
		MetaState.discipline_tree if sheet == null else sheet.learned, spell_id, key)


## The sworn Oath's boon or bane, by key.
static func boon_of(sheet: WardenSheet, key: String) -> float:
	return DisciplineUpgrades.boon(MetaState.discipline_tree if sheet == null else sheet.learned, key)


static func bane_of(sheet: WardenSheet, key: String) -> float:
	return DisciplineUpgrades.bane(MetaState.discipline_tree if sheet == null else sheet.learned, key)


static func trained_of(sheet: WardenSheet, effect_id: String) -> bool:
	if sheet == null:
		return DisciplineEffects.trained(effect_id)
	return sheet._learned_with_effect(effect_id) != null


static func form_of(sheet: WardenSheet) -> DisciplineNodeData:
	if sheet == null:
		return RunState.chain_form()
	var node: DisciplineNodeData = ContentDB.discipline_node(sheet.form)
	if node == null or not node.is_form():
		node = ContentDB.discipline_node(Balance.DISCIPLINE_STARTING_FORM)
	return node


static func synergy_of(sheet: WardenSheet, synergy_id: String) -> bool:
	if sheet == null:
		return Synergies.active(synergy_id)
	var data: SynergyData = ContentDB.synergy(synergy_id)
	if data == null or data.requires.is_empty():
		return false
	for effect_id: String in data.requires:
		if not trained_of(sheet, effect_id):
			return false
	return true


static func ascension_of(sheet: WardenSheet) -> int:
	return MetaState.ascension if sheet == null else sheet.ascension


## The node in a slot on this road, or null - empty, or not open yet.
static func node_in_slot_of(sheet: WardenSheet, slot: int) -> DisciplineNodeData:
	if sheet == null:
		return RunState.discipline_node_in_slot(slot)
	if slot < 0 or slot >= sheet.loadout.size() or not RunState.slot_is_open(slot) \
			or sheet.loadout[slot].is_empty():
		return null
	return ContentDB.discipline_node(sheet.loadout[slot])


## The spell a slot casts on this road: the Warden's own node in it, if the
## road has opened that slot. Whether a slot is open is the run's (`act`, the
## Mansion), so it is asked of the run for every Warden alike.
static func spell_in_slot_of(sheet: WardenSheet, slot: int) -> String:
	if sheet == null:
		return RunState.equipped_spells[slot] \
			if slot >= 0 and slot < RunState.equipped_spells.size() else ""
	var node: DisciplineNodeData = node_in_slot_of(sheet, slot)
	return node.spell_id if node != null else ""


func _learned_with_effect(effect_id: String) -> DisciplineNodeData:
	return _by_effect.get(effect_id, null) as DisciplineNodeData


# --- Reading a row safely -------------------------------------------------------

static func _as_int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(value)
	return fallback


static func _int_at(row: Array, at: int, fallback: int) -> int:
	return _as_int(row[at], fallback) if at < row.size() else fallback


static func _string_at(row: Array, at: int) -> String:
	return String(row[at]) if at < row.size() and row[at] is String else ""


static func _array_at(row: Array, at: int) -> Array:
	return row[at] if at < row.size() and row[at] is Array else []
