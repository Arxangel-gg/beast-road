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


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[affixes] " + message)
