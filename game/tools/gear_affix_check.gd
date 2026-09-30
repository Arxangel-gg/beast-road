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
