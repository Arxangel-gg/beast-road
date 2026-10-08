extends Node

## **A procedural Warden is a Warden the road could have made** (owner,
## 2026-10-07): the Guide's photographs and the trailer at launch dress a random
## Warden in gear "harmonious with the expectation for each phase of the
## player's progression".
##
##   godot --headless --path game res://tools/procedural_warden_check.tscn
##
## Holds that a roll is its key and nothing else; that every piece is a kind
## that drops, in its own slot, at a rarity and level the tier pays at that act,
## a trophy only on somebody who could have won it and a shield only beside a
## free hand; that the look is clean and a beard grows only on the body that
## grows one; that the journey shows - a new Warden in linen and a knife, a
## veteran of the hardest road in plate, under a helm, in dear colours; and that
## wearing one writes the account only while saves are held, takes back what it
## laid last time, and dresses exactly what it rolled.

const TAG: String = "[procedural-warden]"
const ROLLS: int = 160

var _failures: int = 0
var _checked: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var kept: Dictionary = _account()
	_test_a_roll_is_its_key()
	_test_every_piece_could_drop()
	_test_the_journey_shows()
	_test_the_stages()
	_test_wearing()
	_test_the_guide_dresses_its_pictures()
	for stage: String in ["key", "pieces", "journey", "stages", "wear", "guide"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	_restore(kept)
	if _failures == 0:
		print("%s PASS - %d checks: a roll is its key, every piece could have dropped, the journey shows from linen to plate, and wearing one is held, clean and exact" % [TAG, _checked])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checked])
	MetaState.resume_saves()
	get_tree().quit(1 if _failures > 0 else 0)


func _test_a_roll_is_its_key() -> void:
	var first: Dictionary = ProceduralWarden.roll("probe", "normal", 4)
	var again: Dictionary = ProceduralWarden.roll("probe", "normal", 4)
	_check(var_to_str(first) == var_to_str(again), "one key rolled two different Wardens")
	var looks: Dictionary = {}
	for index: int in 60:
		var rolled: Dictionary = ProceduralWarden.roll("probe-%d" % index, "normal", 4)
		looks[var_to_str(rolled["look"])] = true
	_check(looks.size() >= 50, "sixty keys rolled only %d different looks" % looks.size())
	_reached.append("key")


func _test_every_piece_could_drop() -> void:
	var top: int = Stash.RARITY_NAMES.size() - 1
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		for act: int in [1, 5, Balance.ACT_COUNT, Balance.FINAL_ASCENT_ACT]:
			var along: float = clampf(float(act - 1) / float(maxi(Balance.ACT_COUNT - 1, 1)), 0.0, 1.0)
			var low: int = int(round(lerpf(float(tier.expected_gear_rarity.x), float(tier.expected_gear_rarity.y), along))) - 1
			var high: int = int(round(lerpf(float(tier.expected_gear_rarity.x), float(tier.expected_gear_rarity.y), along))) + 1
			for index: int in ROLLS / 4:
				var rolled: Dictionary = ProceduralWarden.roll("drop-%s-%d-%d" % [tier.id, act, index], tier.id, act)
				_check(WardenLook.same(WardenLook.clean(rolled["look"]), rolled["look"] as Dictionary),
					"%s act %d rolled a look that is not clean" % [tier.id, act])
				if WardenLook.is_female(rolled["look"]):
					_check(int((rolled["look"] as Dictionary)[WardenLook.KEY_BEARD]) == 0,
						"a female Warden was rolled a beard")
				var pieces: Dictionary = rolled["pieces"]
				_check(pieces.has(GearData.Slot.WEAPON), "%s act %d rolled a Warden with no weapon" % [tier.id, act])
				var weapon: GearData = null
				for slot: Variant in pieces:
					var piece: Dictionary = pieces[slot]
					var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
					_check(kind != null, "a piece names a kind that does not exist: %s" % piece.get("kind", ""))
					if kind == null:
						continue
					_check(int(kind.slot) == int(slot), "%s was worn in slot %d" % [kind.id, int(slot)])
					var rarity: int = int(piece["rarity"])
					_check(rarity >= clampi(low, 0, top) and rarity <= clampi(high, 0, top) + (1 if kind.trophy else 0),
						"%s act %d wore a %s rarity %d outside %d-%d" % [tier.id, act, kind.id, rarity, low, high])
					_check(int(piece["level"]) >= 1 and int(piece["level"]) <= Stash.MAX_LEVEL,
						"a piece came out at level %d" % int(piece["level"]))
					if kind.trophy:
						_check(tier.order > 0 and kind.id == "gatekeepers_mantle_" + _road_before(tier),
							"%s on %s wore a trophy it could not have won: %s" % [tier.id, act, kind.id])
					if int(slot) == GearData.Slot.WEAPON:
						weapon = kind
						_check(not WardenDress.held_path(kind).is_empty(), "%s has no held picture" % kind.id)
				if pieces.has(GearData.Slot.OFFHAND):
					_check(weapon != null and weapon.grip == GearData.Grip.ONE_HAND,
						"a shield was rolled beside a weapon that leaves no hand free")
	_reached.append("pieces")


func _road_before(tier: CampaignTierData) -> String:
	for other: CampaignTierData in ContentDB.tiers_sorted():
		if other.order == tier.order - 1:
			return other.id
	return ""


## Early against late, over many rolls: the classes climb and the colours do.
func _test_the_journey_shows() -> void:
	var early: Dictionary = _tally(0.02)
	var late: Dictionary = _tally(0.95)
	_check(float(early["light"]) > 0.4, "a new Warden wore light armour %.0f%% of the time" % (float(early["light"]) * 100.0))
	_check(float(early["heavy"]) < 0.15, "a new Warden wore plate %.0f%% of the time" % (float(early["heavy"]) * 100.0))
	_check(float(late["heavy"]) > 0.35, "a veteran of the last road wore plate only %.0f%% of the time" % (float(late["heavy"]) * 100.0))
	_check(float(late["helm"]) > float(early["helm"]) + 0.15,
		"helms were worn %.2f late against %.2f early" % [float(late["helm"]), float(early["helm"])])
	_check(float(late["great"]) > float(early["great"]) + 0.15,
		"great helms %.2f late against %.2f early" % [float(late["great"]), float(early["great"])])
	_check(float(late["weapon"]) > float(early["weapon"]) + 0.2,
		"the weapons climbed from %.2f to %.2f" % [float(early["weapon"]), float(late["weapon"])])
	_check(float(late["noble"]) > float(early["noble"]) + 0.2,
		"dear colours %.2f late against %.2f early" % [float(late["noble"]), float(early["noble"])])
	_check(float(late["rarity"]) > float(early["rarity"]) + 2.0,
		"the rarity worn went from %.1f to %.1f" % [float(early["rarity"]), float(late["rarity"])])
	_reached.append("journey")


func _tally(share: float) -> Dictionary:
	var counts: Dictionary = {"light": 0.0, "heavy": 0.0, "helm": 0.0, "great": 0.0, "weapon": 0.0,
		"noble": 0.0, "rarity": 0.0}
	for index: int in ROLLS:
		var rolled: Dictionary = ProceduralWarden.roll_at("journey-%.2f-%d" % [share, index], share)
		var pieces: Dictionary = rolled["pieces"]
		var armour: GearData = _kind(pieces, GearData.Slot.ARMOUR)
		if armour != null:
			counts["light"] += 1.0 if armour.look == "light" else 0.0
			counts["heavy"] += 1.0 if armour.look == "heavy" else 0.0
		var helm: GearData = _kind(pieces, GearData.Slot.HELMET)
		if helm != null:
			counts["helm"] += 1.0
			counts["great"] += 1.0 if helm.look == "great_helm" else 0.0
		var weapon: GearData = _kind(pieces, GearData.Slot.WEAPON)
		if weapon != null:
			counts["weapon"] += float(ProceduralWarden._WEAPON_STAGE.get(weapon.look, 0.5))
			counts["rarity"] += float(int((pieces[GearData.Slot.WEAPON] as Dictionary)["rarity"]))
		var cape: int = int((rolled["look"] as Dictionary)[WardenLook.KEY_CAPE_COLOUR])
		counts["noble"] += 1.0 if ProceduralWarden._NOBLE.has(cape) else 0.0
	for key: String in counts:
		counts[key] = float(counts[key]) / float(ROLLS)
	return counts


func _kind(pieces: Dictionary, slot: int) -> GearData:
	if not pieces.has(slot):
		return null
	return ContentDB.gear(String((pieces[slot] as Dictionary).get("kind", "")))


func _test_the_stages() -> void:
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	var start: Dictionary = ProceduralWarden.stage_at(0.0)
	_check(String(start["tier"]) == tiers[0].id and int(start["act"]) == 1,
		"the start of a career is %s act %d" % [start["tier"], int(start["act"])])
	var end: Dictionary = ProceduralWarden.stage_at(1.0)
	_check(String(end["tier"]) == tiers[tiers.size() - 1].id and int(end["act"]) >= Balance.ACT_COUNT,
		"the end of a career is %s act %d" % [end["tier"], int(end["act"])])
	var last: float = -1.0
	for tier: CampaignTierData in tiers:
		for act: int in range(1, Balance.ACT_COUNT + 1):
			var share: float = ProceduralWarden.journey_share(tier.order, act)
			_check(share > last, "the journey went backwards at %s act %d" % [tier.id, act])
			last = share
	_reached.append("stages")


func _test_wearing() -> void:
	var rolled: Dictionary = ProceduralWarden.roll("wear-probe", "nightmare", 6)
	MetaState.resume_saves()
	var look_was: String = var_to_str(MetaState.look)
	_check(not ProceduralWarden.wear(rolled), "a Warden was worn with saves not held")
	_check(var_to_str(MetaState.look) == look_was, "a refused wear changed the look")
	MetaState.hold_saves()
	var before: int = MetaState.stash.size()
	_check(ProceduralWarden.wear(rolled), "a held wear was refused")
	var pieces: Dictionary = rolled["pieces"]
	_check(MetaState.stash.size() == before + pieces.size(),
		"the stash went from %d to %d for %d pieces" % [before, MetaState.stash.size(), pieces.size()])
	for slot: int in GearData.Slot.size():
		var worn: Dictionary = MetaState.equipped_piece(slot)
		if pieces.has(slot):
			_check(String(worn.get("kind", "")) == String((pieces[slot] as Dictionary)["kind"]),
				"slot %d wears %s, not %s" % [slot, worn.get("kind", ""), (pieces[slot] as Dictionary)["kind"]])
		else:
			_check(worn.is_empty(), "slot %d wears %s though nothing was rolled for it" % [slot, worn.get("kind", "")])
	_check(WardenLook.same(MetaState.look, rolled["look"]), "the look worn is not the look rolled")
	_check(MetaState.hero_level == int(rolled["level"]), "the level worn is %d, rolled %d" % [MetaState.hero_level, int(rolled["level"])])
	var second: Dictionary = ProceduralWarden.roll("wear-probe-2", "hell", 9)
	ProceduralWarden.wear(second)
	_check(MetaState.stash.size() == before + (second["pieces"] as Dictionary).size(),
		"a second wear left the first one's pieces in the stash (%d)" % MetaState.stash.size())
	_reached.append("wear")


## The Guide tool dresses a Warden in every door a picture is taken through.
func _test_the_guide_dresses_its_pictures() -> void:
	var source: String = FileAccess.get_file_as_string("res://tools/guide_shots.gd")
	for door: String in ["func _shot(", "func _deep_shot(", "func _weather_shot(", "func _water_shot("]:
		var at: int = source.find(door)
		var body: String = source.substr(at, 600) if at >= 0 else ""
		_check(body.contains("_dress_for(id)"), "the Guide's %s takes a picture without dressing its Warden" % door)
	_check(source.contains("ProceduralWarden.wear(ProceduralWarden.roll_at("),
		"the Guide never wears a procedural Warden")
	_reached.append("guide")


func _account() -> Dictionary:
	return {
		"look": MetaState.look.duplicate(true),
		"stash": MetaState.stash.duplicate(true),
		"equipped": MetaState.equipped.duplicate(true),
		"level": MetaState.hero_level,
		"attributes": MetaState.hero_attributes.duplicate(),
	}


func _restore(kept: Dictionary) -> void:
	MetaState.look = kept["look"]
	MetaState.stash.clear()
	for piece: Variant in kept["stash"] as Array:
		MetaState.stash.append(piece)
	MetaState.equipped = kept["equipped"]
	MetaState.hero_level = int(kept["level"])
	MetaState.hero_attributes.clear()
	for value: Variant in kept["attributes"] as Array:
		MetaState.hero_attributes.append(int(value))
	Modifiers.rebuild()


func _check(ok: bool, message: String) -> void:
	_checked += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
