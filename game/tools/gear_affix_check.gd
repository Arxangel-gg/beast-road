extends Node

## Legendary affixes on gear (owner brief, 2026-09-12: "legendary gear with
## affixes similar to Diablo").
##
## An affix moves a number `Modifiers` already resolves - the bound omens and
## Road Cards are built under - and nothing else. What this holds:
##
## - **every affix names a key `Modifiers` has a constant for.** A misspelt
##   key lands in the table under a name nothing reads: the sword still says
##   the words and does nothing;
## - a counted key (chain targets, wave foresight) is moved by a whole
##   number, never a fraction that `int()` throws away;
## - no scaled affix moves its key by more than `GEAR_LEGENDARY_CEILING`;
## - the roll is arithmetic: the same piece wears the same affixes on every
##   read, and a rarity wears exactly the count `GEAR_LEGENDARY_COUNT` says
##   when enough affixes fit it - never more;
## - the two ordinary rarities wear none.

const COUNTED: Array[String] = ["chain_targets", "wave_foresight"]

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	_test_the_data()
	_test_the_roll()
	_test_the_make()
	_test_the_grants()
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[affixes] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[affixes] PASS - %d checks over %d affixes" % [_checked, ContentDB.gear_affixes.size()])
	get_tree().quit(0)


func _known_keys() -> Dictionary:
	var keys: Dictionary = {}
	var script: GDScript = Modifiers.get_script() as GDScript
	if script == null:
		return keys
	for name: String in script.get_script_constant_map():
		var value: Variant = script.get_script_constant_map()[name]
		if value is String and not String(value).is_empty():
			keys[String(value)] = name
	return keys


func _test_the_data() -> void:
	var known: Dictionary = _known_keys()
	_check(known.size() >= 10, "Modifiers publishes its keys as constants (%d)" % known.size())
	_check(ContentDB.gear_affixes.size() >= 12, "there are affixes to find (%d)" % ContentDB.gear_affixes.size())
	_check(Balance.GEAR_LEGENDARY_COUNT.size() == Stash.RARITY_NAMES.size(),
		"the count table covers every rarity")
	_check(Balance.GEAR_LEGENDARY_COUNT[0] == 0 and Balance.GEAR_LEGENDARY_COUNT[1] == 0,
		"the ordinary rarities wear no affix")
	for id: Variant in ContentDB.gear_affixes:
		var affix: GearAffixData = ContentDB.gear_affixes[id] as GearAffixData
		if affix == null:
			_check(false, "affix %s is not a GearAffixData" % String(id))
			continue
		_check(known.has(affix.effect_id),
			"affix %s moves a key Modifiers resolves: '%s'" % [affix.id, affix.effect_id])
		if COUNTED.has(affix.effect_id):
			_check(affix.magnitude >= 1.0 and is_equal_approx(affix.magnitude, round(affix.magnitude)),
				"affix %s moves a counted key by a whole number (%s)" % [affix.id, affix.magnitude])
		else:
			# Either sign: a cost that falls is as much an affix as a damage that
			# rises, and the ceiling is on how far the number moves.
			_check(not is_zero_approx(affix.magnitude) and absf(affix.magnitude) <= Balance.GEAR_LEGENDARY_CEILING + 0.0001,
				"affix %s stays under the ceiling (|%s| <= %s)" % [affix.id, affix.magnitude, Balance.GEAR_LEGENDARY_CEILING])
		_check(affix.min_rarity >= 0 and affix.min_rarity < Stash.RARITY_NAMES.size(),
			"affix %s's rarity floor is a rarity" % affix.id)
		_check(affix.weight > 0.0, "affix %s can be rolled" % affix.id)
		_check(not affix.display_name.is_empty() and not affix.description.is_empty(),
			"affix %s has a name and a line" % affix.id)


func _test_the_roll() -> void:
	var kinds: Array = ContentDB.gear_sorted()
	_check(not kinds.is_empty(), "there is gear to roll on")
	if kinds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	var top_seen: int = 0
	for rarity: int in Stash.RARITY_NAMES.size():
		var wanted: int = Balance.GEAR_LEGENDARY_COUNT[rarity]
		for sample: int in 8:
			var kind: GearData = kinds[(sample * 7 + rarity) % kinds.size()] as GearData
			var piece: Dictionary = {"kind": kind.id, "rarity": rarity, "level": 3 + sample,
				"uid": rng.randi() & 0x3FFFFFFF}
			var first: Array[GearAffixData] = Stash.legendary_affixes(piece, kind)
			var again: Array[GearAffixData] = Stash.legendary_affixes(piece, kind)
			var same: bool = first.size() == again.size()
			for index: int in mini(first.size(), again.size()):
				if first[index].id != again[index].id:
					same = false
			_check(same, "%s %s wears the same affixes on every read" % [Stash.RARITY_NAMES[rarity], kind.id])
			_check(first.size() <= wanted, "%s %s wears at most %d affixes (%d)" % [
				Stash.RARITY_NAMES[rarity], kind.id, wanted, first.size()])
			if wanted > 0:
				var fitting: int = 0
				for id: Variant in ContentDB.gear_affixes:
					var affix: GearAffixData = ContentDB.gear_affixes[id] as GearAffixData
					if affix != null and affix.min_rarity <= rarity \
							and (affix.slots.is_empty() or affix.slots.has(int(kind.slot))):
						fitting += 1
				if fitting >= wanted:
					_check(first.size() == wanted, "%s %s wears exactly %d affixes when %d fit (%d)" % [
						Stash.RARITY_NAMES[rarity], kind.id, wanted, fitting, first.size()])
				var ids: Dictionary = {}
				for affix: GearAffixData in first:
					_check(not ids.has(affix.id), "%s %s does not wear %s twice" % [
						Stash.RARITY_NAMES[rarity], kind.id, affix.id])
					ids[affix.id] = true
					_check(affix.min_rarity <= rarity, "%s wears nothing above its rarity" % kind.id)
			else:
				_check(first.is_empty(), "%s %s wears no affix" % [Stash.RARITY_NAMES[rarity], kind.id])
			if rarity == Stash.RARITY_NAMES.size() - 1:
				top_seen += first.size()
	_check(top_seen > 0, "the top rarity actually wears affixes")


## **A branch grant** (ruling R7, `docs/LEGENDARY_SKILL_AFFIX_2026-10-06.md`,
## built 2026-10-06). Every grantable branch is an enhancement or a fork and
## never a skill, an Oath or a form; about the authored share of affix-bearing
## pieces carry one, in place of a number, and the same name grants the same
## branch on every read; through the real door - a piece received, worn and
## read by `WardenSheet.upgrade_of` - a grant is the branch's own value for a
## learned skill, nothing for one not learned, the same on a partner's sheet,
## nothing extra on a branch already learned, both forks when the twin is
## granted, and never past the ceiling however many ranks a planted tree
## claims. The modifier table gains no key from it.
func _test_the_grants() -> void:
	var branches: Array[DisciplineNodeData] = Stash.grantable_branches()
	_check(branches.size() >= 20, "there are branches to grant (%d)" % branches.size())
	for node: DisciplineNodeData in branches:
		_check(node.kind == DisciplineNodeData.Kind.UPGRADE and not node.effect_id.is_empty(),
			"grantable %s is a branch that moves something" % node.id)
		_check(not node.is_oath() and not node.is_form(), "grantable %s is neither an Oath nor a form" % node.id)
		var affix: GearAffixData = Stash.grant_affix(node)
		_check(affix.is_grant() and affix.effect_id.is_empty() and affix.branch_id == node.id
			and not affix.line().is_empty(), "the grant affix for %s names its branch and no key" % node.id)
		_check(Stash.grant_affix(node) == affix, "the grant affix for %s is made once" % node.id)
	# The share, over many names on the first kind of every slot that can wear one.
	var kinds: Array = ContentDB.gear_sorted()
	var kind: GearData = null
	for candidate: Variant in kinds:
		if (candidate as GearData) != null and not (candidate as GearData).trophy:
			kind = candidate as GearData
			break
	_check(kind != null, "a kind to roll grants on")
	if kind == null:
		return
	var rarity: int = 3
	var granted: int = 0
	var sampled: int = 0
	var first_grant: GearAffixData = null
	var first_uid: int = -1
	for uid: int in range(1, 801):
		var piece: Dictionary = {"kind": kind.id, "rarity": rarity, "level": 5, "uid": uid * 1000003}
		var worn: Array[GearAffixData] = Stash.legendary_affixes(piece, kind)
		if worn.is_empty():
			continue
		sampled += 1
		for affix: GearAffixData in worn:
			if affix.is_grant():
				granted += 1
				if first_grant == null:
					first_grant = affix
					first_uid = uid * 1000003
	var share: float = float(granted) / maxf(float(sampled), 1.0)
	_check(sampled >= 700 and share > Balance.GEAR_BRANCH_GRANT_SHARE * 0.6
		and share < Balance.GEAR_BRANCH_GRANT_SHARE * 1.5,
		"about %.0f%% of affix-bearing pieces carry a grant (%.1f%% of %d)" % [
			Balance.GEAR_BRANCH_GRANT_SHARE * 100.0, share * 100.0, sampled])
	_check(first_grant != null, "some name on %s rolls a grant" % kind.id)
	if first_grant == null:
		return
	var totals: Dictionary = Modifiers.gear_totals([{"kind": kind.id, "rarity": rarity, "level": 5, "uid": first_uid}])
	_check(not totals.has(""), "a grant puts no key on the modifier table")
	# Through the real door: the piece worn, its branch read where a swing reads it.
	var node: DisciplineNodeData = ContentDB.discipline_node(first_grant.branch_id)
	var root: String = DisciplineUpgrades.root_of(node)
	var root_node: DisciplineNodeData = ContentDB.discipline_node(root)
	_check(root_node != null, "the granted branch %s has a root" % node.id)
	if root_node == null:
		return
	var key: String = node.effect_id
	var piece: Dictionary = Stash.make(kind.id, rarity, 5)
	piece["uid"] = first_uid
	MetaState.receive_gear(piece)
	var index: int = MetaState.stash.size() - 1
	MetaState.equip(kind.slot, index)
	var kept_tree: Dictionary = MetaState.discipline_tree.duplicate()
	var kept_form: String = MetaState.discipline_form
	_check(MetaState.branch_grants().has(node.id), "the worn piece grants %s on the account" % node.id)
	# Dormant: the skill not learned, the form not in use.
	MetaState.discipline_tree.erase(root)
	if root_node.is_form():
		MetaState.discipline_form = ""
	var asleep: float = WardenSheet.upgrade_of(null, root, key)
	_check(is_zero_approx(asleep), "a grant for a skill not held is dormant (%.3f)" % asleep)
	_check(GearRow.grant_note(first_grant).contains("dormant"), "the row says the grant is dormant")
	# Live: the skill learned (or the form taken up).
	if root_node.is_form():
		MetaState.discipline_form = root
	else:
		MetaState.discipline_tree[root] = 1
	var expected: float = node.effect_value if DisciplineUpgrades.COUNTED.has(key) \
		else minf(node.effect_value, Balance.DISCIPLINE_UPGRADE_CEILING)
	var awake: float = WardenSheet.upgrade_of(null, root, key)
	_check(is_equal_approx(awake, expected), "a worn grant reads as its branch's own value (%.3f for %.3f)" % [awake, expected])
	_check(GearRow.grant_note(first_grant).is_empty(), "the row says nothing for a live grant")
	# A partner's sheet reads the same grant off the same worn row.
	var sheet: WardenSheet = WardenSheet.from_row(WardenSheet.pack_mine())
	_check(sheet.grants.has(node.id), "a partner's sheet carries the grant")
	_check(is_equal_approx(WardenSheet.upgrade_of(sheet, root, key), expected),
		"a partner reads the grant as this machine does")
	# Learned as well: the grant adds nothing.
	MetaState.discipline_tree[node.id] = 1
	var learned_too: float = WardenSheet.upgrade_of(null, root, key)
	_check(is_equal_approx(learned_too, expected), "a grant of a learned branch adds nothing (%.3f)" % learned_too)
	MetaState.discipline_tree.erase(node.id)
	# The twin: a learned fork beside its granted twin, both read - on any
	# exclusive pair the tree holds, since the first grant above may be an
	# enhancement with no twin.
	var twin_seen: bool = false
	var forks: Array[DisciplineNodeData] = Stash.grantable_branches()
	for one: DisciplineNodeData in forks:
		if one.exclusive.is_empty():
			continue
		for other: DisciplineNodeData in forks:
			if other == one or other.exclusive != one.exclusive \
					or DisciplineUpgrades.root_of(other) != DisciplineUpgrades.root_of(one):
				continue
			var fork_root: String = DisciplineUpgrades.root_of(one)
			var learned: Dictionary = {fork_root: 1, other.id: 1}
			var merged: Dictionary = DisciplineUpgrades.with_grants(learned, {one.id: true}, "")
			var both: Dictionary = DisciplineUpgrades.for_skill(merged, fork_root)
			var alone: Dictionary = DisciplineUpgrades.for_skill(learned, fork_root)
			var expected_one: float = one.effect_value + (float(alone.get(one.effect_id, 0.0)))
			_check(both.has(other.effect_id) and both.has(one.effect_id)
				and is_equal_approx(float(both[one.effect_id]), expected_one),
				"a granted twin (%s) is read beside the learned fork (%s)" % [one.id, other.id])
			twin_seen = true
			break
		if twin_seen:
			break
	_check(twin_seen, "the tree holds an exclusive pair to grant across")
	# The ceiling: a planted tree claiming fifty ranks of a share reads the ceiling.
	if not DisciplineUpgrades.COUNTED.has(key):
		var fat: Dictionary = {root: 1, node.id: 50}
		_check(DisciplineUpgrades.value(fat, root, key) <= Balance.DISCIPLINE_UPGRADE_CEILING + 0.0001,
			"a grant can never read past the ceiling")
	# A different name on the same kind can grant a different branch.
	var other_branch: bool = false
	for uid: int in range(1, 801):
		var probe: Dictionary = {"kind": kind.id, "rarity": rarity, "level": 5, "uid": uid * 1000003}
		for affix: GearAffixData in Stash.legendary_affixes(probe, kind):
			if affix.is_grant() and affix.branch_id != node.id:
				other_branch = true
	_check(other_branch, "another name grants another branch")
	print("[affixes] grants: %d branches, %.1f%% of pieces, twin %s" % [branches.size(), share * 100.0, "seen" if twin_seen else "not found"])
	MetaState.discipline_tree = kept_tree
	MetaState.discipline_form = kept_form


## **A piece's make** (owner, 2026-09-30: "qualities/rarities"). The weights
## put the average make at one, so the gear scale's middle does not move; a
## drop's make follows those weights over many names; a make scales the
## points and nothing else; absent is ordinary, so an old piece is untouched;
## two pieces of different make are different gear to a trade; and the name
## says so. Unchained, the rung above Beastcalled, steps up by less than the
## rung below it did.
func _test_the_make() -> void:
	var total: float = 0.0
	var mean: float = 0.0
	for index: int in Balance.GEAR_QUALITY_WEIGHTS.size():
		total += Balance.GEAR_QUALITY_WEIGHTS[index]
		mean += Balance.GEAR_QUALITY_WEIGHTS[index] * Stash.QUALITY_SCALE[index]
	_check(Balance.GEAR_QUALITY_WEIGHTS.size() == Stash.QUALITY_NAMES.size()
		and Stash.QUALITY_SCALE.size() == Stash.QUALITY_NAMES.size(), "every make needs a weight and a scale")
	_check(absf(mean / total - 1.0) < 0.01,
		"the average make is %.3f - it must sit at one, or the gear scale moves" % (mean / total))
	var counts: Array[int] = [0, 0, 0, 0]
	for name: int in 20000:
		counts[Stash.quality_for_name(Stash.new_uid())] += 1
	for index: int in counts.size():
		var wanted: float = Balance.GEAR_QUALITY_WEIGHTS[index] / total
		var seen: float = float(counts[index]) / 20000.0
		_check(absf(seen - wanted) < 0.02,
			"%s drops %.3f of the time against %.3f authored" % [Stash.QUALITY_NAMES[index], seen, wanted])
	# The strongest kind, so a make's tenth is never lost to rounding. The first
	# cut asked for six base points, no kind has more than five, and every check
	# below this line silently never ran: a comparison of nothing.
	var kind: GearData = null
	for value: Variant in ContentDB.gear_kinds.values():
		var candidate := value as GearData
		if candidate != null and not candidate.trophy \
				and (kind == null or candidate.base_points > kind.base_points):
			kind = candidate
	_check(kind != null, "no gear kind to measure a make on")
	if kind != null:
		var plain: Dictionary = Stash.make(kind.id, 4, 3)
		var master: Dictionary = plain.duplicate()
		master["quality"] = 3
		var cracked: Dictionary = plain.duplicate()
		cracked["quality"] = 0
		_check(Stash.quality(plain) == Stash.QUALITY_ORDINARY, "a piece with no make must read as ordinary")
		_check(Stash.points(master, kind) > Stash.points(plain, kind) and Stash.points(cracked, kind) < Stash.points(plain, kind),
			"a Masterwork must grant more than ordinary and a Cracked piece less (%d, %d, %d)"
			% [Stash.points(cracked, kind), Stash.points(plain, kind), Stash.points(master, kind)])
		_check(not Stash.same_gear(plain, master), "a trade could swap an ordinary piece for a Masterwork of the same kind")
		_check(Stash.display_name(master, kind).begins_with("Masterwork ") and not Stash.display_name(plain, kind).begins_with(" "),
			"a Masterwork must say so in its name, and an ordinary piece say nothing")
		_test_the_make_travels(kind)
	var mantle: Dictionary = GatekeeperTrials.mantle_for("normal")
	_check(mantle.is_empty() or Stash.quality(mantle) == Stash.QUALITY_NAMES.size() - 1,
		"the Gatekeeper's Mantle is a trophy and must always be a Masterwork")
	var top: int = Stash.RARITY_NAMES.size() - 1
	_check(Stash.RARITY_NAMES[top] == "Unchained", "the top of the ladder is Unchained")
	_check(Stash.RARITY_POINTS[top] / Stash.RARITY_POINTS[top - 1]
		< Stash.RARITY_POINTS[top - 1] / Stash.RARITY_POINTS[top - 2],
		"Unchained must step up by less than Beastcalled did - longer, never steeper")


## **The make goes where the piece goes**: through the real save and its
## reader (a planted make of 99 reads back as the best the game has), through a
## temper (which renames the piece and must not re-roll its make), and onto a
## partner's sheet. The account is put back exactly as it was afterwards.
func _test_the_make_travels(kind: GearData) -> void:
	var restore: String = MetaState.serialized_save()
	var worn: Dictionary = Stash.make(kind.id, 4, 3)
	worn["quality"] = 3
	var planted: Dictionary = Stash.make(kind.id, 1, 2)
	planted["quality"] = 99
	MetaState.stash.append(worn)
	MetaState.stash.append(planted)
	MetaState.adopt_save(MetaState.parse_save_text(MetaState.serialized_save()))
	var back: int = Stash.index_of(MetaState.stash, Stash.uid(worn))
	var odd: int = Stash.index_of(MetaState.stash, Stash.uid(planted))
	_check(back >= 0 and Stash.quality(MetaState.stash[back]) == 3,
		"a Masterwork came back from the save as something else")
	_check(odd >= 0 and Stash.quality(MetaState.stash[odd]) == Stash.QUALITY_NAMES.size() - 1,
		"a make of 99 must read back as the best make the game has")
	if back < 0:
		MetaState.adopt_save(MetaState.parse_save_text(restore))
		return
	MetaState.shards = 1000000
	MetaState.marks = 1000000
	var why: String = MetaState.temper_gear(Stash.uid(MetaState.stash[back]))
	_check(why.is_empty() and Stash.quality(MetaState.stash[back]) == 3,
		"tempering re-rolled a piece's make (%s)" % why)
	MetaState.equip(kind.slot, back)
	var sheet: WardenSheet = WardenSheet.from_row(WardenSheet.pack_mine())
	var carried: bool = false
	for piece: Dictionary in sheet.worn:
		if String(piece.get("kind", "")) == kind.id and Stash.quality(piece) == 3:
			carried = true
	_check(carried, "a partner's sheet dropped the make of a worn Masterwork")
	MetaState.adopt_save(MetaState.parse_save_text(restore))


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[affixes] " + message)
