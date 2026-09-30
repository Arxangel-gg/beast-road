extends Node

## **Craft talents** (2026-09-30, `CraftTalentData`): two at each of
## `Balance.CRAFT_TALENT_LEVELS`, one kept, and each moving one number of its
## own craft and nothing else.
##
##   godot --headless --path game res://tools/craft_talent_check.tscn
##
## Holds the offer (every craft that has talents offers exactly two at each
## level, inside the ceiling), the choice (refused below its level, one a level,
## a second putting the first down), the save (read back through the door that
## chooses, so a hand-edited save can only hold what a Warden could have
## chosen), what each moves - measured through the craft's own function where
## it has one - and the bound: `CraftTalents.value` is read by the three craft
## scripts and by nothing a fight is made of.

const TAG: String = "[craft-talents]"
## Which script reads which craft's talents.
const READERS: Dictionary = {
	"angler": "res://scripts/systems/fishing.gd",
	"woodcutter": "res://scripts/systems/gathering.gd",
	"miner": "res://scripts/systems/gathering.gd",
	"farmer": "res://scripts/systems/farming.gd",
	"smith": "res://scripts/systems/forge.gd",
}

var _failures: int = 0
var _checks: int = 0
var _saved_xp: Dictionary = {}
var _saved_talents: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	_saved_xp = MetaState.profession_xp.duplicate()
	_saved_talents = MetaState.craft_talents.duplicate()
	_test_the_offer()
	_test_the_choice()
	_test_the_save()
	_test_what_they_move()
	_test_the_bound()
	MetaState.profession_xp = _saved_xp
	MetaState.craft_talents = _saved_talents
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: two a level, one kept, read back through the door that chooses, and each moves its own craft and nothing else" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("%s FAIL: %s" % [TAG, why])


## Experience that puts `craft` at exactly `level`.
func _set_level(craft: String, level: int) -> void:
	var xp: float = 0.0
	for at: int in range(1, level):
		xp += MetaState.profession_xp_to_leave(at)
	MetaState.profession_xp[craft] = xp
	_check(MetaState.profession_level(craft) == level,
		"the harness put %s at %d, not %d" % [craft, MetaState.profession_level(craft), level])


func _test_the_offer() -> void:
	for craft: String in READERS:
		for at: int in Balance.CRAFT_TALENT_LEVELS:
			var pair: Array[CraftTalentData] = CraftTalents.offered(craft, at)
			_check(pair.size() == 2, "%s offers %d talents at level %d, not two" % [craft, pair.size(), at])
			if pair.size() == 2:
				_check(pair[0].key != pair[1].key,
					"%s's two talents at %d move the same number" % [craft, at])
	for value: Variant in ContentDB.craft_talents.values():
		var talent := value as CraftTalentData
		_check(Balance.PROFESSIONS.has(talent.craft), "%s names no craft" % talent.id)
		_check(Balance.CRAFT_TALENT_LEVELS.has(talent.level), "%s opens at level %d, which offers nothing" % [talent.id, talent.level])
		_check(not talent.description.is_empty() and not talent.display_name.is_empty(),
			"%s says nothing on the card" % talent.id)
		if talent.key in CraftTalents.COUNTED:
			_check(talent.amount >= 1.0 and is_equal_approx(talent.amount, round(talent.amount)),
				"%s counts %s, which is not a whole thing" % [talent.id, str(talent.amount)])
		else:
			_check(absf(talent.amount) > 0.0 and absf(talent.amount) <= Balance.CRAFT_TALENT_CEILING,
				"%s moves its number by %s, past the ceiling" % [talent.id, str(talent.amount)])


func _test_the_choice() -> void:
	MetaState.craft_talents.clear()
	_set_level("angler", 9)
	var pair: Array[CraftTalentData] = CraftTalents.offered("angler", 10)
	var late: Array[CraftTalentData] = CraftTalents.offered("angler", 20)
	_check(not MetaState.choose_talent(pair[0].id).is_empty() and MetaState.craft_talents.is_empty(),
		"a talent was kept below the level it opens at")
	_set_level("angler", 10)
	_check(MetaState.choose_talent(pair[0].id).is_empty() and MetaState.has_talent(pair[0].id),
		"a talent at its level must be kept")
	_check(MetaState.choose_talent(pair[1].id).is_empty() and MetaState.has_talent(pair[1].id)
		and not MetaState.has_talent(pair[0].id),
		"keeping the other talent of a level must put the first down")
	_check(not MetaState.choose_talent(late[0].id).is_empty() and not MetaState.has_talent(late[0].id),
		"a level-20 talent was kept at level 10")
	_check(not MetaState.choose_talent("no_such_talent").is_empty(), "an unknown talent was kept")




func _test_the_save() -> void:
	MetaState.craft_talents.clear()
	_set_level("miner", 20)
	_set_level("farmer", 10)
	var miner10: Array[CraftTalentData] = CraftTalents.offered("miner", 10)
	var miner20: Array[CraftTalentData] = CraftTalents.offered("miner", 20)
	var farmer20: Array[CraftTalentData] = CraftTalents.offered("farmer", 20)
	MetaState.choose_talent(miner10[0].id)
	MetaState.choose_talent(miner20[1].id)
	var data: Dictionary = JSON.parse_string(MetaState.serialized_save())
	# A hand-edited save: both of a level, an unknown one, and one above the
	# craft's level, written straight into the block the read uses.
	var professions: Dictionary = data.get("professions", {})
	professions["talents"] = [miner10[0].id, miner10[1].id, miner20[1].id, "no_such", farmer20[0].id]
	data["professions"] = professions
	MetaState.adopt_save(data)
	_check(MetaState.craft_talents.size() == 2 and MetaState.has_talent(miner20[1].id),
		"the read kept %s from a hand-edited save" % str(MetaState.craft_talents))
	_check(not MetaState.has_talent(farmer20[0].id), "a talent above its craft's level survived the read")
	var mined: int = 0
	for id: String in MetaState.craft_talents:
		if ContentDB.craft_talent(id).craft == "miner" and ContentDB.craft_talent(id).level == 10:
			mined += 1
	_check(mined == 1, "a save kept %d miner talents at level 10" % mined)
	# And an ordinary round trip keeps exactly what was chosen.
	var held: Array[String] = MetaState.craft_talents.duplicate()
	MetaState.adopt_save(JSON.parse_string(MetaState.serialized_save()))
	_check(MetaState.craft_talents == held, "a round trip changed the talents: %s -> %s"
		% [str(held), str(MetaState.craft_talents)])


func _test_what_they_move() -> void:
	MetaState.craft_talents.clear()
	for craft: String in READERS:
		_set_level(craft, 20)
	# Gathering, through its own functions.
	var gathering := Gathering.new()
	add_child(gathering)
	var wood: GatherNodeData = null
	for kind: GatherNodeData in ContentDB.gather_nodes_sorted():
		if kind.craft == "woodcutter":
			wood = kind
			break
	var plain_swing: float = float(gathering.call("_swing_seconds", wood))
	var plain_swings: int = int(gathering.call("_swings_in", wood))
	MetaState.choose_talent("woodcutter_keen_edge")
	var keen: float = float(gathering.call("_swing_seconds", wood))
	_check(is_equal_approx(keen, plain_swing * (1.0 + ContentDB.craft_talent("woodcutter_keen_edge").amount)),
		"Keen Edge took a swing from %.3f to %.3f" % [plain_swing, keen])
	MetaState.choose_talent("woodcutter_tree_reader")
	_check(int(gathering.call("_swings_in", wood)) == plain_swings + 1,
		"Tree Reader must give a trunk one more swing")
	_check(is_equal_approx(float(gathering.call("_swing_seconds", wood)), plain_swing),
		"putting Keen Edge down must give the swing back")
	# The miner's talents are the miner's: a woodcutter's trunk does not feel them.
	MetaState.choose_talent("miner_sure_pick")
	_check(is_equal_approx(float(gathering.call("_swing_seconds", wood)), plain_swing),
		"a miner's talent reached a woodcutter's trunk")
	gathering.queue_free()
	# Farming, through its own static rule.
	var crop: CropData = ContentDB.crops_sorted()[0]
	var plain_fit: float = Farming.fit_for(crop, crop.temp_max + 6.0, (crop.wet_min + crop.wet_max) * 0.5, 20)
	MetaState.choose_talent("farmer_hardy_stock")
	var hardy_fit: float = Farming.fit_for(crop, crop.temp_max + 6.0, (crop.wet_min + crop.wet_max) * 0.5, 20)
	_check(hardy_fit > plain_fit, "Hardy Stock must bear ground further from the crop's band: %.3f -> %.3f"
		% [plain_fit, hardy_fit])
	# The Smith's, through the forge's own price: the stock a forge takes is
	# what the refusal, the spend and the screen all read.
	var plain_wood: int = Forge.wood_cost()
	MetaState.choose_talent("smith_frugal_hand")
	_check(Forge.wood_cost() < plain_wood and Forge.ore_cost() < Balance.FORGE_ORE_COST,
		"Frugal Hand must take less wood and ore: %d of %d" % [Forge.wood_cost(), plain_wood])
	MetaState.choose_talent("smith_quick_study")
	_check(Forge.wood_cost() == plain_wood, "putting Frugal Hand down must restore the forge's price")
	# The one door answers only its own craft and key.
	MetaState.choose_talent("angler_quick_strike")
	_check(is_equal_approx(CraftTalents.value("angler", "bite"), ContentDB.craft_talent("angler_quick_strike").amount)
		and CraftTalents.value("angler", "wait") == 0.0 and CraftTalents.value("farmer", "bite") == 0.0,
		"a talent must answer only its own craft and key")


## Every key a talent names is read by its craft's script, and no script a fight
## is made of reads a talent at all.
func _test_the_bound() -> void:
	for value: Variant in ContentDB.craft_talents.values():
		var talent := value as CraftTalentData
		var path: String = String(READERS.get(talent.craft, ""))
		var source: String = FileAccess.get_file_as_string(path) if not path.is_empty() else ""
		_check(source.contains("CraftTalents.value(") and source.contains("\"%s\")" % talent.key),
			"%s moves '%s', which %s never reads" % [talent.id, talent.key, path])
	var allowed: Array[String] = ["res://scripts/systems/craft_talents.gd"]
	for path: Variant in READERS.values():
		allowed.append(String(path))
	for path: String in _scripts("res://"):
		if path in allowed or path.begins_with("res://tools/"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		_check(not text.contains("CraftTalents.value("),
			"%s reads a craft talent - a talent may touch only its own craft" % path)


func _scripts(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for name: String in dir.get_directories():
		if name.begins_with(".") or name == "addons":
			continue
		out.append_array(_scripts(root.path_join(name)))
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			out.append(root.path_join(name))
	return out
