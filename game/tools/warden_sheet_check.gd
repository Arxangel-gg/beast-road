extends Node

## **A Warden fights as their own account** (2026-09-26, COOP_DESIGN §11).
##
##   godot --headless --path game res://tools/warden_sheet_check.tscn
##
## The host simulates every hero, and its copy of a guest's Warden read the
## host's account: a level-1 guest fought as a level-100 host and cast the
## host's skills. A guest now tells the host its sheet and the host's copy reads
## it through `WardenSheet`'s door. What this holds:
##
## - **Null is this machine's own Warden, exactly.** Every reader, with no sheet,
##   answers what the call site read before - a solo road cannot move.
## - **A sheet reads back the account it was packed from**, with the gear's
##   points, affixes and set tiers worked out by the host from the pieces.
## - **A row is cleaned by the rules a save is read under**, so a sheet can only
##   describe a Warden the game could have produced.
## - **A partner's body fights as its sheet** - its damage, health, mana, speed,
##   swing, form and skills - and keeps its own wounds across a refit.
## - **The wire attributes a sheet by the peer it arrived on**, and a sheet that
##   lands before the body is worn when the body is built.
## - **Nothing in the hero reads round the door**, by a walk of its scripts.

const SEED: int = 262626
const EXPECTED_TESTS: int = 9

var _failures: PackedStringArray = []
var _finished: int = 0
var _run: Node = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	_build_a_played_account()
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	if _field != null and _field.hero != null:
		_field.hero.set_present(true)

	_test_null_is_this_machines_warden()
	_test_a_sheet_reads_back_its_account()
	_test_a_row_is_cleaned()
	_test_the_host_works_out_the_gear()
	await _test_a_partner_fights_as_its_sheet()
	await _test_a_partner_keeps_its_own_wounds()
	await _test_the_wire_attributes_by_peer()
	_test_a_body_built_later_wears_the_sheet()
	_test_nothing_reads_round_the_door()
	_check(_finished == EXPECTED_TESTS,
		"%d of %d tests reached their end - a runtime error aborted one, and every check it had not made is unmade"
			% [_finished, EXPECTED_TESTS])

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	for problem: String in _failures:
		push_error("[warden-sheet] FAIL: " + problem)
	if _failures.is_empty():
		print("[warden-sheet] PASS - a Warden fights as their own account: null is this machine, a sheet reads back its account, rows are cleaned, a partner fights as its sheet and the wire attributes it by peer")
	else:
		push_error("[warden-sheet] FAIL - %d problem(s)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


## A Warden with something on the sheet: a level, placed points, learned nodes,
## a form, a slotted skill and worn gear with a legendary affix on a Warden key.
func _build_a_played_account() -> void:
	MetaState.hero_level = 41
	MetaState.hero_attributes = [12, 6, 9, 5, 8]
	MetaState.hero_attribute_points = 0
	MetaState.discipline_tree = {}
	MetaState.first_clears = {}
	var nodes: Array = ContentDB.discipline_nodes.values()
	nodes.sort_custom(func(a: Variant, b: Variant) -> bool:
		var x := a as DisciplineNodeData
		var y := b as DisciplineNodeData
		return x.depth_to_open() < y.depth_to_open() \
			or (x.depth_to_open() == y.depth_to_open() and x.id < y.id))
	for value: Variant in nodes:
		var node := value as DisciplineNodeData
		if MetaState.skill_points_free() <= 0:
			break
		MetaState.learn_discipline(node.id, Balance.ACT_COUNT)
	for id: Variant in MetaState.discipline_tree:
		var node: DisciplineNodeData = ContentDB.discipline_node(String(id))
		if node != null and node.is_form():
			MetaState.set_discipline_form(node.id)
			break
	for id: Variant in MetaState.discipline_tree:
		var node: DisciplineNodeData = ContentDB.discipline_node(String(id))
		if node != null and node.slot_index() == 1 and not node.spell_id.is_empty():
			MetaState.set_discipline_slot(1, node.id)
			break
	MetaState.stash = []
	MetaState.equipped = {}
	var weapon: Dictionary = _piece_with_warden_affix()
	if not weapon.is_empty():
		MetaState.stash.append(weapon)
		MetaState.equip(GearData.Slot.WEAPON, 0)
	Modifiers.rebuild()


## A top-rarity weapon whose legendary affixes include a Warden key. Found by
## walking names, because an affix is rolled from a piece's own `uid`.
func _piece_with_warden_affix() -> Dictionary:
	var kind: GearData = null
	for value: Variant in ContentDB.gear_kinds.values():
		var gear := value as GearData
		if gear != null and gear.slot == GearData.Slot.WEAPON:
			kind = gear
			break
	if kind == null:
		return {}
	var rarity: int = Stash.RARITY_NAMES.size() - 1
	for uid: int in range(1, 4000):
		var piece: Dictionary = {"kind": kind.id, "rarity": rarity, "level": Stash.MAX_LEVEL, "uid": uid}
		for affix: GearAffixData in Stash.legendary_affixes(piece, kind):
			if Modifiers.WARDEN_KEYS.has(affix.effect_id):
				return piece
	return {}


# --- 1 ---------------------------------------------------------------------------

## **Null is this machine's own Warden, to the digit.** Every reader against the
## expression its call sites used before.
func _test_null_is_this_machines_warden() -> void:
	for which: int in RunState.ATTRIBUTE_NAMES.size():
		_check(WardenSheet.attribute_of(null, which) == RunState.attribute(which),
			"with no sheet, attribute %d read %d against the account's %d"
				% [which, WardenSheet.attribute_of(null, which), RunState.attribute(which)])
	for key: String in Modifiers.keys_in_use():
		_check(WardenSheet.value_of(null, key) == Modifiers.value(key)
			and WardenSheet.multiplier_of(null, key) == Modifiers.multiplier(key),
			"with no sheet, %s read %.4f against the table's %.4f"
				% [key, WardenSheet.value_of(null, key), Modifiers.value(key)])
	for effect_id: String in _every_effect():
		_check(WardenSheet.trained_value_of(null, effect_id) == DisciplineEffects.trained_value(effect_id)
			and WardenSheet.trained_of(null, effect_id) == DisciplineEffects.trained(effect_id),
			"with no sheet, the effect %s read differently from the account" % effect_id)
	_check(WardenSheet.form_of(null) == RunState.chain_form(), "with no sheet, the form is not the account's")
	_check(WardenSheet.ascension_of(null) == MetaState.ascension, "with no sheet, the ascension is not the account's")
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var expected: String = RunState.equipped_spells[slot] if slot < RunState.equipped_spells.size() else ""
		_check(WardenSheet.spell_in_slot_of(null, slot) == expected,
			"with no sheet, slot %d cast %s against the road's %s"
				% [slot, WardenSheet.spell_in_slot_of(null, slot), expected])
		_check(WardenSheet.node_in_slot_of(null, slot) == RunState.discipline_node_in_slot(slot),
			"with no sheet, slot %d held a different node" % slot)
	for data: SynergyData in Synergies.all_sorted():
		_check(WardenSheet.synergy_of(null, data.id) == Synergies.active(data.id),
			"with no sheet, the synergy %s answered differently" % data.id)
	_finished += 1


# --- 2 ---------------------------------------------------------------------------

## **A sheet reads back the account it was packed from**: the host, handed this
## machine's own row, works out the same Warden - every attribute with its gear
## points, every Warden key with its affixes and set tiers, the form, every
## trained effect and every slot.
func _test_a_sheet_reads_back_its_account() -> void:
	_check(not MetaState.worn_pieces().is_empty(), "the harness wears nothing, so the gear half proves nothing")
	_check(MetaState.discipline_tree.size() >= 4, "the harness learned too little to test a tree")
	var sheet: WardenSheet = WardenSheet.from_row(WardenSheet.pack_mine())
	for which: int in RunState.ATTRIBUTE_NAMES.size():
		_check(WardenSheet.attribute_of(sheet, which) == RunState.attribute(which),
			"packed and read back, attribute %d is %d against the account's %d"
				% [which, WardenSheet.attribute_of(sheet, which), RunState.attribute(which)])
	var own: float = 0.0
	for key: String in Modifiers.WARDEN_KEYS:
		own += absf(Modifiers.own_value(key))
		_check(is_equal_approx(WardenSheet.value_of(sheet, key), Modifiers.value(key)),
			"packed and read back, %s is %.4f against the account's %.4f"
				% [key, WardenSheet.value_of(sheet, key), Modifiers.value(key)])
	_check(own > 0.0, "the worn gear moves no Warden key, so the affix half proves nothing")
	_check(WardenSheet.form_of(sheet) == RunState.chain_form(),
		"packed and read back, the form is %s against %s"
			% [WardenSheet.form_of(sheet).id, RunState.chain_form().id])
	for effect_id: String in _every_effect():
		_check(is_equal_approx(WardenSheet.trained_value_of(sheet, effect_id),
				DisciplineEffects.trained_value(effect_id)),
			"packed and read back, the effect %s is %.3f against %.3f"
				% [effect_id, WardenSheet.trained_value_of(sheet, effect_id),
					DisciplineEffects.trained_value(effect_id)])
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		_check(WardenSheet.node_in_slot_of(sheet, slot) == RunState.discipline_node_in_slot(slot),
			"packed and read back, slot %d holds a different node" % slot)
	_finished += 1


# --- 3 ---------------------------------------------------------------------------

## **A row is cleaned by the rules a save is read under.**
func _test_a_row_is_cleaned() -> void:
	var bare: WardenSheet = WardenSheet.from_row("not a row")
	_check(bare.level == 1 and _sum(bare.placed) == 0 and bare.worn.is_empty(),
		"a packet that is not a row read as more than a bare Warden")
	_check(bare.form == Balance.DISCIPLINE_STARTING_FORM, "a bare Warden has no starting form")
	var greedy: Array = WardenSheet.pack_mine()
	greedy[WardenSheet.AT_LEVEL] = 9999
	greedy[WardenSheet.AT_PLACED] = [999, 999, 999, 999, 999]
	greedy[WardenSheet.AT_ASCENSION] = 999
	var sheet: WardenSheet = WardenSheet.from_row(greedy)
	_check(sheet.level == Balance.HERO_MAX_LEVEL, "a level of 9999 read as %d" % sheet.level)
	_check(_sum(sheet.placed) == Balance.HERO_MAX_LEVEL - 1,
		"placed points of 999 each came to %d against the %d the level grants"
			% [_sum(sheet.placed), Balance.HERO_MAX_LEVEL - 1])
	_check(sheet.ascension == Balance.ASCENSION_MAX, "an ascension of 999 read as %d" % sheet.ascension)
	var low: Array = WardenSheet.pack_mine()
	low[WardenSheet.AT_LEVEL] = 5
	low[WardenSheet.AT_PLACED] = [3, 3, 3, 3, 3]
	var trimmed: WardenSheet = WardenSheet.from_row(low)
	_check(_sum(trimmed.placed) == 4 and trimmed.placed[0] == 3,
		"a level-5 row placed %s; it may place four, trimmed from the last attribute"
			% str(trimmed.placed))
	# Nodes: a level-1 Warden who says it learned the whole tree holds only
	# what a level-1 Warden could, and nothing no order could reach.
	var every: Array = []
	for id: Variant in ContentDB.discipline_nodes:
		every.append(String(id))
	var claims: Array = WardenSheet.pack_mine()
	claims[WardenSheet.AT_LEVEL] = 1
	claims[WardenSheet.AT_LEARNED] = every + ["no_such_node", 7, null]
	var cleaned: WardenSheet = WardenSheet.from_row(claims)
	var beyond: int = cleaned.learned.size() - Balance.DISCIPLINE_STARTERS.size()
	_check(beyond <= WardenSheet.points_ceiling(1),
		"a level-1 row kept %d nodes beyond the starters against a ceiling of %d"
			% [beyond, WardenSheet.points_ceiling(1)])
	var held: Array[String] = []
	for id: Variant in cleaned.learned:
		held.append(String(id))
	_check(MetaState.stranded_node(held).is_empty(),
		"a cleaned row holds %s, which no order of learning reaches" % MetaState.stranded_node(held))
	_check(not cleaned.learned.has("no_such_node"), "a node this build lacks was kept")
	var exclusive: Dictionary = {}
	for id: String in held:
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if node != null and not node.exclusive.is_empty():
			_check(not exclusive.has(node.exclusive),
				"a cleaned row holds both halves of the exclusive pair %s" % node.exclusive)
			exclusive[node.exclusive] = true
	# The form and the slots only ever name what is held and fits.
	var stray: Array = WardenSheet.pack_mine()
	stray[WardenSheet.AT_LEARNED] = []
	stray[WardenSheet.AT_FORM] = String(MetaState.discipline_form)
	stray[WardenSheet.AT_LOADOUT] = MetaState.discipline_loadout.duplicate()
	var unlearned: WardenSheet = WardenSheet.from_row(stray)
	_check(unlearned.form == Balance.DISCIPLINE_STARTING_FORM or unlearned.learned.has(unlearned.form),
		"a row with nothing learned kept the form %s" % unlearned.form)
	for slot: int in unlearned.loadout.size():
		var id: String = unlearned.loadout[slot]
		var node: DisciplineNodeData = ContentDB.discipline_node(id) if not id.is_empty() else null
		_check(id.is_empty() or (unlearned.learned.has(id) and node != null and node.slot_index() == slot),
			"slot %d kept %s, which the row does not hold or which does not fit it" % [slot, id])
	# Pieces: unknown kinds, two in one slot, and rarity and level past the ends.
	var weapon: Dictionary = MetaState.worn_pieces()[0] if not MetaState.worn_pieces().is_empty() else {}
	var pieces: Array = WardenSheet.pack_mine()
	var twice: Dictionary = weapon.duplicate()
	twice["rarity"] = 99
	twice["level"] = 99
	pieces[WardenSheet.AT_WORN] = [twice, weapon.duplicate(), {"kind": "no_such_kind"}, "a sword", 12]
	var dressed: WardenSheet = WardenSheet.from_row(pieces)
	_check(dressed.worn.size() == 1, "a row wearing two weapons and a stranger kept %d pieces" % dressed.worn.size())
	if dressed.worn.size() == 1:
		_check(int(dressed.worn[0]["rarity"]) == Stash.RARITY_NAMES.size() - 1
			and int(dressed.worn[0]["level"]) == Stash.MAX_LEVEL,
			"a piece of rarity 99 and level 99 read as %s" % str(dressed.worn[0]))
	_finished += 1


# --- 4 ---------------------------------------------------------------------------

## **The host works out the gear, never trusts it.** A partner whose sword
## carries a Warden-key affix reads that affix; the host's own gear does not
## reach the partner, and the partner's does not reach the board.
func _test_the_host_works_out_the_gear() -> void:
	var sword: Dictionary = _piece_with_warden_affix()
	var kind: GearData = ContentDB.gear(String(sword.get("kind", "")))
	var key: String = ""
	var magnitude: float = 0.0
	# One key, and every affix on it: a sword may carry two Warden keys, and the
	# first cut of this summed both into one figure and blamed the door for it.
	for affix: GearAffixData in Stash.legendary_affixes(sword, kind):
		if Modifiers.WARDEN_KEYS.has(affix.effect_id) and (key.is_empty() or key == affix.effect_id):
			key = affix.effect_id
			magnitude += affix.magnitude
	_check(not key.is_empty(), "the harness found no sword with a Warden-key affix")
	if key.is_empty():
		_finished += 1
		return
	var bare_row: Array = WardenSheet.pack_mine()
	bare_row[WardenSheet.AT_WORN] = []
	var bare: WardenSheet = WardenSheet.from_row(bare_row)
	var armed_row: Array = bare_row.duplicate(true)
	armed_row[WardenSheet.AT_WORN] = [sword]
	var armed: WardenSheet = WardenSheet.from_row(armed_row)
	var shared: float = Modifiers.value(key) - Modifiers.own_value(key)
	_check(is_equal_approx(WardenSheet.value_of(bare, key), shared),
		"a partner wearing nothing read %s at %.4f - the host's own gear reached them (shared part %.4f)"
			% [key, WardenSheet.value_of(bare, key), shared])
	_check(WardenSheet.value_of(armed, key) >= shared + magnitude - 0.0001,
		"a partner's %s affix of %.3f did not reach them (%.4f against a shared %.4f)"
			% [key, magnitude, WardenSheet.value_of(armed, key), shared])
	# A board key is the board's, whoever asks.
	_check(WardenSheet.value_of(armed, Modifiers.TOWER_DAMAGE) == Modifiers.value(Modifiers.TOWER_DAMAGE),
		"a partner's sheet moved the board's own tower damage")
	# And the points: the affixes a piece dresses, summed.
	var points: Array[int] = [0, 0, 0, 0, 0]
	for affix: Dictionary in Stash.affixes(sword, kind):
		points[int(affix["attribute"])] += int(affix["points"])
	for which: int in points.size():
		_check(WardenSheet.attribute_of(armed, which) - WardenSheet.attribute_of(bare, which) == points[which],
			"the sword's %d points to attribute %d arrived as %d"
				% [points[which], which,
					WardenSheet.attribute_of(armed, which) - WardenSheet.attribute_of(bare, which)])
	_finished += 1


# --- 5 ---------------------------------------------------------------------------

## **A partner's body fights as its sheet.** A strong sheet against this bare
## host's numbers: more damage by its Might, more health by its Vigour, a deeper
## pool by its Focus, a faster swing by its Swiftness, its own form and its own
## skill in its own slot - and this machine's own Warden untouched.
func _test_a_partner_fights_as_its_sheet() -> void:
	var partner: Hero = _spawn_partner()
	var mine: Hero = _field.hero if _field != null else null
	if partner == null or mine == null:
		_check(false, "the harness needs a partner and a Warden")
		_finished += 1
		return
	var before_damage: float = mine.damage_multiplier()
	var before_hp: float = mine.health.max_hp
	var row: Array = WardenSheet.pack_mine()
	row[WardenSheet.AT_LEVEL] = Balance.HERO_MAX_LEVEL
	row[WardenSheet.AT_PLACED] = [40, 20, 20, 10, 9]
	row[WardenSheet.AT_WORN] = []
	partner.wear_sheet(row)
	for _f: int in 2:
		await get_tree().process_frame
	_check(partner.sheet != null, "wear_sheet left the partner with no sheet")
	if partner.sheet == null:
		_finished += 1
		return
	_check(partner.attack.sheet == partner.sheet and partner.spells.sheet == partner.sheet,
		"the partner's swing or caster was not handed its sheet - they read the host's account")
	var might: int = WardenSheet.attribute_of(partner.sheet, RunState.Attribute.MIGHT)
	var host_might: int = RunState.attribute(RunState.Attribute.MIGHT)
	var expected: float = before_damage \
		* (1.0 + float(might) * Balance.HERO_MIGHT_PER_POINT) / (1.0 + float(host_might) * Balance.HERO_MIGHT_PER_POINT) \
		* WardenSheet.multiplier_of(partner.sheet, Modifiers.HERO_DAMAGE) / Modifiers.multiplier(Modifiers.HERO_DAMAGE) \
		* (1.0 + WardenSheet.form_of(partner.sheet).form_damage) / (1.0 + RunState.chain_form().form_damage)
	_check(is_equal_approx(partner.damage_multiplier(), expected),
		"the partner hits for %.4f against the %.4f its Might of %d asks (the host, Might %d, hits for %.4f)"
			% [partner.damage_multiplier(), expected, might, host_might, before_damage])
	_check(partner.health.max_hp > before_hp,
		"the partner's pool is %.1f against the host's %.1f - its Vigour of %d did nothing"
			% [partner.health.max_hp, before_hp, WardenSheet.attribute_of(partner.sheet, RunState.Attribute.VIGOUR)])
	_check(is_equal_approx(partner.mana_max(), Balance.HERO_MANA_BASE
			+ float(WardenSheet.attribute_of(partner.sheet, RunState.Attribute.FOCUS)) * Balance.HERO_MANA_PER_FOCUS),
		"the partner's mana pool did not follow its Focus")
	_check(partner.attack.call("_swiftness_scale") < mine.attack.call("_swiftness_scale"),
		"the partner swings at the host's pace - its Swiftness did not reach the swing")
	_check(is_equal_approx(mine.damage_multiplier(), before_damage) and is_equal_approx(mine.health.max_hp, before_hp),
		"the partner's sheet moved this machine's own Warden")
	# Its own skill in its own slot, where this machine's is empty.
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var spell: SpellData = partner.spells.spell_in_slot(slot)
		var wanted: String = WardenSheet.spell_in_slot_of(partner.sheet, slot)
		_check((spell.id if spell != null else "") == wanted,
			"the partner's slot %d casts %s against its sheet's %s"
				% [slot, spell.id if spell != null else "nothing", wanted])
	var differs: Array = WardenSheet.pack_mine()
	differs[WardenSheet.AT_LOADOUT] = ["", "", "", ""]
	partner.wear_sheet(differs)
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		_check(partner.spells.spell_in_slot(slot) == null,
			"a partner with an empty loadout cast from slot %d - the host's own skill" % slot)
	_finished += 1


# --- 6 ---------------------------------------------------------------------------

## **A partner keeps its own wounds.** `RunState.hero_hp` is this machine's
## Warden; a refit (a relic socketed, a boss fallen) used to give every partner
## the host's figure.
func _test_a_partner_keeps_its_own_wounds() -> void:
	var partner: Hero = _field.partner_hero() if _field != null else null
	if partner == null:
		_check(false, "the harness has no partner to wound")
		_finished += 1
		return
	partner.wear_sheet(WardenSheet.pack_mine())
	partner.health.current_hp = partner.health.max_hp * 0.5
	RunState.hero_hp = 3.0
	EventBus.hero_attributes_changed.emit()
	for _f: int in 2:
		await get_tree().process_frame
	_check(is_equal_approx(partner.health.current_hp / partner.health.max_hp, 0.5),
		"a refit gave the partner %.1f of %.1f - the host's wounds, not its own half"
			% [partner.health.current_hp, partner.health.max_hp])
	RunState.hero_hp = -1.0
	_finished += 1


# --- 7 ---------------------------------------------------------------------------

## **The wire attributes a sheet by the peer it arrived on**, and never lets a
## packet rewrite this machine's own Warden or a seat nobody sits in.
func _test_the_wire_attributes_by_peer() -> void:
	var heroes: Node = _field.get_node_or_null("CoopHeroes") if _field != null else null
	var partner: Hero = _field.partner_hero() if _field != null else null
	if heroes == null or partner == null:
		_check(false, "the harness needs CoopHeroes and a partner")
		_finished += 1
		return
	var party: CoopParty = Coop.party()
	var _mine: int = party.seat(1, "Host")
	var peer: int = 5151
	var slot: int = party.seat(peer, "Sheet")
	(heroes.get("_bodies") as Dictionary)[slot] = partner
	var row: Array = WardenSheet.pack_mine()
	row[WardenSheet.AT_LEVEL] = 30
	row[WardenSheet.AT_PLACED] = [29, 0, 0, 0, 0]
	heroes.call("_on_request", CoopRelay.Request.HERO_SHEET, [row], peer)
	_check(partner.sheet != null and partner.sheet.level == 30 and partner.sheet.placed[0] == 29,
		"a guest's sheet never reached the host's mirror of it")
	var stranger: Array = row.duplicate(true)
	stranger[WardenSheet.AT_LEVEL] = 2
	heroes.call("_on_request", CoopRelay.Request.HERO_SHEET, [stranger], 9999)
	_check(partner.sheet != null and partner.sheet.level == 30,
		"a sheet from an unseated peer rewrote somebody's Warden")
	var mine: Hero = _field.hero
	heroes.call("_on_request", CoopRelay.Request.HERO_SHEET, [stranger], 1)
	_check(mine.sheet == null, "a packet wrote a sheet onto this machine's own Warden")
	_check(((heroes.get("_sheets") as Dictionary).get(slot, []) as Array) == row,
		"the host did not keep the seat's sheet for a body built later")
	party.unseat(peer)
	party.unseat(1)
	(heroes.get("_bodies") as Dictionary).erase(slot)
	(heroes.get("_sheets") as Dictionary).clear()
	_finished += 1


# --- 8 ---------------------------------------------------------------------------

## **A sheet that lands before its body is worn when the body is built.** A
## sheet is told once and only again when it changes, so one lost to that race
## would leave a partner fighting as the host for the whole road.
func _test_a_body_built_later_wears_the_sheet() -> void:
	var heroes: Node = _field.get_node_or_null("CoopHeroes") if _field != null else null
	if heroes == null:
		_check(false, "the harness needs CoopHeroes")
		_finished += 1
		return
	var row: Array = WardenSheet.pack_mine()
	row[WardenSheet.AT_LEVEL] = 22
	var slot: int = 3
	(heroes.get("_sheets") as Dictionary)[slot] = row
	var built: Hero = heroes.call("_ensure_body", slot) as Hero
	_check(built != null and built.sheet != null and built.sheet.level == 22,
		"a body built after its sheet arrived fights as the host")
	if built != null:
		heroes.call("_drop_body", slot)
	(heroes.get("_sheets") as Dictionary).clear()
	_finished += 1


# --- 9 ---------------------------------------------------------------------------

## **Nothing in the hero reads round the door.** Every read of the account a
## Warden brings to a fight goes through `WardenSheet`; a direct read added
## beside the door is a read that answers the host's account for a partner, and
## that is invisible to every test that plays alone.
func _test_nothing_reads_round_the_door() -> void:
	var forbidden: Array[String] = ["RunState.attribute(", "DisciplineEffects.trained",
		"Synergies.active(", "RunState.chain_form()", "MetaState.ascension",
		"RunState.discipline_node_in_slot(", "RunState.equipped_spells["]
	for key: String in ["HERO_DAMAGE", "HERO_MAX_HP", "HERO_SPEED", "DASH_COOLDOWN",
			"MANA_REGEN", "SPELL_POWER", "COMPANION_DAMAGE", "KNOCKBACK"]:
		forbidden.append("Modifiers.multiplier(Modifiers.%s)" % key)
		forbidden.append("Modifiers.value(Modifiers.%s)" % key)
	for path: String in ["res://scenes/hero/hero.gd", "res://scenes/hero/hero_attack.gd",
			"res://scenes/hero/spell_caster.gd", "res://scenes/battlefield/companion.gd"]:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for number: int in lines.size():
			var line: String = lines[number].strip_edges()
			if line.begins_with("#"):
				continue
			for needle: String in forbidden:
				_check(not line.contains(needle),
					"%s:%d reads %s round the door: %s" % [path.get_file(), number + 1, needle, line])
	_finished += 1


# --- helpers ---------------------------------------------------------------------

func _spawn_partner() -> Hero:
	var heroes: Node = _field.get_node_or_null("CoopHeroes") if _field != null else null
	if heroes == null:
		return null
	return heroes.call("spawn_partner") as Hero


func _every_effect() -> Array[String]:
	var out: Array[String] = []
	for value: Variant in ContentDB.discipline_nodes.values():
		var node := value as DisciplineNodeData
		if node != null and not node.effect_id.is_empty() and not out.has(node.effect_id):
			out.append(node.effect_id)
	return out


func _sum(values: Array[int]) -> int:
	var total: int = 0
	for value: int in values:
		total += value
	return total


func _check(condition: bool, why: String) -> void:
	if not condition:
		_failures.append(why)
