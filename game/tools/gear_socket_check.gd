extends Node

## Sockets and tempering: chosen, paid, bounded, kept and seen.
##
##   godot --headless --path game res://tools/gear_socket_check.tscn
##
## `docs/GEAR_REWORK_2026-09-28.md` §3-4. A piece from Fine up carries sockets
## by rarity; a gem the road's seams gave up, set in one, grants an affix on a
## `Modifiers` key sized by the gem's rarity; tempering renames the piece, which
## is what rerolls its secondaries and its legendary affixes, for Shards and
## Marks that climb to a cap.
##
## **The bound is the legendary affix's**: a gem moves a number the table
## already resolves, by a magnitude under the legendary ceiling, and nothing
## downstream learns that gems exist. What a socket *costs* is the gem - a
## material, which is an input to the Smithy and nothing else - and a slot's
## worth of choosing.
##
## **Seven ways this is a lie, driven rather than read:**
##
## - **A gem grants nothing.** Its key lands in the table under a name nothing
##   reads: the socket is filled, the gem is gone, and the piece is exactly what
##   it was. Every gem key is held to `Modifiers.keys_in_use()` and to a reader
##   outside the table.
## - **It is not paid for.** A socket that does not take the gem off the store,
##   or a pry that does not put it back, is either a gem printer or a gem
##   eater.
## - **Two of one thing.** A gem whose key the piece already carries, by another
##   gem or by its own legendary affix, would stack past the ceiling.
## - **It is lost on the way to disk.** `_read_stash` rebuilds every piece
##   through `Stash.make` and copies the fields it knows; a field it does not
##   know is a gem that vanishes on the next launch. And a row a hand or an
##   older build wrote wrong must read as a piece the game could have produced.
## - **A partner does not wear it.** A guest's pieces cross by kind, rarity,
##   level and name; a gem that does not cross is a Warden weaker on the host's
##   screen than on their own.
## - **Tempering rerolls the wrong thing**, or costs nothing, or never stops.
## - **The screen cannot reach it.** A door with no button is a feature that
##   does not exist.

var _failures: int = 0
var _checks: int = 0

## The account before the gate touched it, put back at the end whatever fails.
var _stash_before: Array = []
var _equipped_before: Dictionary = {}
var _materials_before: Dictionary = {}
var _marks_before: int = 0
var _shards_before: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_stash_before = MetaState.stash.duplicate(true)
	_equipped_before = MetaState.equipped.duplicate()
	_materials_before = MetaState.materials.duplicate()
	_marks_before = MetaState.marks
	_shards_before = MetaState.shards
	_test_sockets_by_rarity()
	_test_every_gem_grants_something_read()
	_test_setting_and_prying()
	_test_one_key_a_piece()
	_test_the_trade_lock()
	_test_tempering()
	_test_the_save_round_trip()
	_test_a_partner_wears_its_gems()
	await _test_the_screen()
	_test_the_bars_carry_it()
	_restore()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[gear-socket] PASS - %d checks: sockets by rarity, every gem "
			+ "read, set and pried for exactly the gem, one key a piece, locked "
			+ "under a trade, tempered by name at a climbing price to a cap, "
			+ "kept across the save, worn by a partner, and on the screen")
			% _checks)
	else:
		push_error("[gear-socket] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _restore() -> void:
	MetaState.stash = _stash_before
	MetaState.equipped = _equipped_before
	MetaState.materials = _materials_before
	MetaState.marks = _marks_before
	MetaState.shards = _shards_before
	Modifiers.rebuild()


# --- The tables --------------------------------------------------------------

func _test_sockets_by_rarity() -> void:
	_check(Balance.GEAR_SOCKETS.size() == Stash.RARITY_NAMES.size(),
		("GEAR_SOCKETS has %d entries for %d rarities - a rarity read through the "
			+ "clamp silently gets the one below it") % [Balance.GEAR_SOCKETS.size(),
			Stash.RARITY_NAMES.size()])
	_check(Balance.GEAR_SOCKETS[0] == 0 and Balance.GEAR_SOCKETS[1] == 0,
		"the two lowest rarities carry a socket, so a Rough drop is a gem's home")
	_check(Balance.GEAR_SOCKETS[Balance.GEAR_SOCKETS.size() - 1] >= 2,
		"the top rarity carries fewer than two sockets")
	for rarity: int in range(1, Balance.GEAR_SOCKETS.size()):
		_check(Balance.GEAR_SOCKETS[rarity] >= Balance.GEAR_SOCKETS[rarity - 1],
			"sockets fall from rarity %d to %d" % [rarity - 1, rarity])
	_check(Balance.GEAR_GEM_MAGNITUDE.size() == 4,
		"a gem's rarity runs 0-3 and the magnitude table has %d entries"
			% Balance.GEAR_GEM_MAGNITUDE.size())
	for rarity: int in Balance.GEAR_GEM_MAGNITUDE.size():
		_check(Balance.GEAR_GEM_MAGNITUDE[rarity] <= Balance.GEAR_GEM_CEILING,
			"a rarity-%d gem is authored past the gem ceiling" % rarity)
	_check(Balance.GEAR_GEM_CEILING < Balance.GEAR_LEGENDARY_CEILING,
		"a gem may move a key as far as a legendary affix, so a gem is a "
			+ "legendary affix the player chose")
	_check(Balance.GEAR_TEMPER_SHARDS.size() == Stash.RARITY_NAMES.size()
		and Balance.GEAR_TEMPER_MARKS.size() == Stash.RARITY_NAMES.size(),
		"the tempering price tables are not one entry a rarity")
	_check(Balance.GEAR_TEMPER_STEP > 1.0, "tempering does not get dearer")
	_check(Balance.GEAR_TEMPER_MAX >= 1, "tempering is never allowed")


## **A gem's key must be read by something outside the table.** The
## `DisciplineEffects` lie on a material: the gem is spent, the socket filled,
## and the key sits in the table under a name nothing asks for.
func _test_every_gem_grants_something_read() -> void:
	var known: PackedStringArray = Modifiers.keys_in_use()
	var granting: int = 0
	var sources: String = ""
	for folder: String in ["res://scenes", "res://scripts", "res://autoload"]:
		for path: String in _scripts_under(folder):
			if path.ends_with("Modifiers.gd") or path.ends_with("stash.gd"):
				continue
			sources += FileAccess.get_file_as_string(path)
	for kind: MaterialData in ContentDB.materials_sorted():
		if kind.kind != MaterialData.Kind.GEM:
			_check(kind.gem_key.is_empty(),
				"%s is not a gem and authors a gem key" % kind.id)
			continue
		if kind.gem_key.is_empty():
			continue
		granting += 1
		_check(known.has(kind.gem_key),
			"%s grants '%s', which Modifiers has no constant for" % [kind.id, kind.gem_key])
		_check(sources.contains("\"%s\"" % kind.gem_key)
			or sources.contains("Modifiers.%s" % kind.gem_key.to_upper()),
			"%s grants '%s' and no script outside the table reads it"
				% [kind.id, kind.gem_key])
	_check(granting >= 3, "only %d gems grant anything set" % granting)


# --- Setting and prying ------------------------------------------------------

func _gem_of_rarity(rarity: int) -> MaterialData:
	for kind: MaterialData in ContentDB.materials_sorted():
		if kind.kind == MaterialData.Kind.GEM and kind.rarity == rarity \
				and not kind.gem_key.is_empty():
			return kind
	return null


func _a_kind() -> GearData:
	var ids: Array = ContentDB.gear_kinds.keys()
	ids.sort()
	return ContentDB.gear(String(ids[0]))


## A piece of this rarity in the stash, worn, and its position.
func _wear(kind: GearData, rarity: int) -> Dictionary:
	MetaState.receive_gear(Stash.make(kind.id, rarity, 1))
	var piece: Dictionary = MetaState.stash[MetaState.stash.size() - 1]
	MetaState.equip(kind.slot, MetaState.stash.size() - 1)
	Modifiers.rebuild()
	return piece


func _test_setting_and_prying() -> void:
	var kind: GearData = _a_kind()
	var amber: MaterialData = _gem_of_rarity(1)
	var frost: MaterialData = _gem_of_rarity(2)
	_check(amber != null and frost != null, "a rarity-1 and a rarity-2 gem are needed")
	if amber == null or frost == null:
		return
	MetaState.stash = []
	MetaState.equipped = {}
	MetaState.materials = {}
	MetaState.marks = 0
	var top: int = Stash.RARITY_NAMES.size() - 2
	var piece: Dictionary = _wear(kind, top)
	var uid: int = Stash.uid(piece)
	_check(Stash.sockets(piece) == 2, "the rarity below the top wears %d sockets" % Stash.sockets(piece))
	var before: float = Modifiers.value(amber.gem_key)

	# Nothing held: refused, and nothing moved.
	var refused: String = MetaState.socket_gem(uid, amber.id)
	_check(not refused.is_empty(), "a gem the Warden does not hold was set")
	_check(Stash.gems(piece).is_empty(), "and it is in the piece")

	# Held: set, spent, and read.
	MetaState.gain_material(amber.id, 1)
	var answer: String = MetaState.socket_gem(uid, amber.id)
	_check(answer.is_empty(), "setting a held gem was refused: %s" % answer)
	_check(MetaState.material_count(amber.id) == 0, "the gem was set and not spent")
	_check(_same(Stash.gems(piece), [amber.id]), "the piece does not carry the gem")
	Modifiers.rebuild()
	var wanted: float = Balance.GEAR_GEM_MAGNITUDE[amber.rarity]
	_check(is_equal_approx(Modifiers.value(amber.gem_key) - before, wanted),
		"a set %s moved '%s' by %.3f, not the %.3f its rarity says"
			% [amber.id, amber.gem_key, Modifiers.value(amber.gem_key) - before, wanted])
	# Through the sheet the Warden's own numbers read, too.
	_check(is_equal_approx(WardenSheet.value_of(null, amber.gem_key) - before, wanted),
		"the Warden's own sheet does not read the gem")

	# The same key twice: refused, and the gem stays in the store.
	MetaState.gain_material(amber.id, 1)
	_check(not MetaState.socket_gem(uid, amber.id).is_empty(),
		"a second gem on the same key was set")
	_check(MetaState.material_count(amber.id) == 1, "and the refused gem was spent")

	# A different key fills the second socket; a third is refused.
	MetaState.gain_material(frost.id, 2)
	_check(MetaState.socket_gem(uid, frost.id).is_empty(), "the second socket refused a gem")
	_check(not MetaState.socket_gem(uid, frost.id).is_empty(), "a third gem went into two sockets")
	_check(MetaState.material_count(frost.id) == 1, "the refused third gem was spent")
	_check(Stash.gems(piece).size() == 2, "the piece carries %d gems" % Stash.gems(piece).size())

	# A Rough piece has nowhere to put one.
	var rough: Dictionary = _wear(kind, 0)
	_check(not MetaState.socket_gem(Stash.uid(rough), frost.id).is_empty(),
		"a Rough piece took a gem")
	_check(Stash.gems(rough).is_empty(), "and carries it")
	# And a piece not in the stash.
	_check(not MetaState.socket_gem(-777, frost.id).is_empty(), "a piece nobody holds took a gem")

	# Prying: refused short of Marks, then paid, returned and no longer read.
	MetaState.marks = 0
	_check(not MetaState.unsocket_gem(uid, 0).is_empty(), "a gem was pried out for no Marks")
	var cost: int = Stash.unsocket_cost(amber.id)
	_check(cost > 0, "prying is free")
	MetaState.marks = cost
	_check(MetaState.unsocket_gem(uid, 0).is_empty(), "prying with the Marks in hand was refused")
	_check(MetaState.marks == 0, "prying took %d Marks of %d" % [cost - MetaState.marks, cost])
	_check(MetaState.material_count(amber.id) == 2, "the pried gem did not come back to the store")
	_check(_same(Stash.gems(piece), [frost.id]), "the wrong gem was pried out")
	Modifiers.rebuild()
	_check(is_equal_approx(Modifiers.value(amber.gem_key), before),
		"a pried gem is still read")
	_check(not MetaState.unsocket_gem(uid, 5).is_empty(), "an empty socket was pried")


## **A gem whose key the piece's own legendary affix carries is refused.**
## Pure over a dictionary: a legendary affix is rolled from the name, so a name
## that carries the key is found by looking.
func _test_one_key_a_piece() -> void:
	var top: int = Stash.RARITY_NAMES.size() - 1
	var kinds: Array = ContentDB.gear_kinds.keys()
	kinds.sort()
	var found: bool = false
	# An affix names the slots it may land on, so the search is over kinds as
	# well as names - a key a gem grants may be an affix only a ring can wear.
	for gem: MaterialData in ContentDB.materials_sorted():
		if gem.kind != MaterialData.Kind.GEM or gem.gem_key.is_empty() or found:
			continue
		for kind_id: Variant in kinds:
			var kind: GearData = ContentDB.gear(String(kind_id))
			for name: int in range(1, 400):
				var piece: Dictionary = {"kind": kind.id, "rarity": top, "level": 1, "uid": name}
				var carries: bool = false
				for affix: GearAffixData in Stash.legendary_affixes(piece, kind):
					if affix.effect_id == gem.gem_key:
						carries = true
				if not carries:
					continue
				found = true
				_check(not Stash.socket_problem(piece, gem.id, kind).is_empty(),
					"%s may be set in a piece whose own affix already carries '%s'"
						% [gem.id, gem.gem_key])
				break
			if found:
				break
	_check(found, "no top-rarity piece of any kind in 400 names carries a gem's key "
		+ "as its own affix, so the one-key rule could not be driven")


func _test_the_trade_lock() -> void:
	var kind: GearData = _a_kind()
	var frost: MaterialData = _gem_of_rarity(2)
	if frost == null:
		return
	var piece: Dictionary = _wear(kind, Stash.RARITY_NAMES.size() - 2)
	MetaState.gain_material(frost.id, 1)
	MetaState.shards = 1000
	MetaState.marks = 1000
	var trade := TradeSession.new()
	trade.invite(TradeSession.HOST)
	trade.accept_invite(TradeSession.GUEST)
	TradeBooth.set("_session", trade)
	TradeBooth.set("_side", TradeSession.HOST)
	_check(TradeBooth.is_trading(), "the probe trade did not open")
	_check(not MetaState.socket_gem(Stash.uid(piece), frost.id).is_empty(),
		"a gem was set while a trade was open")
	_check(not MetaState.temper_gear(Stash.uid(piece)).is_empty(),
		"a piece was tempered while a trade was open - the name on the table changed")
	TradeBooth.set("_session", null)
	_check(not TradeBooth.is_trading(), "the probe trade did not close")
	_check(MetaState.unsocket_gem(Stash.uid(piece), 0) != "", "an empty socket was pried")


# --- Tempering ---------------------------------------------------------------

func _test_tempering() -> void:
	var kind: GearData = _a_kind()
	var frost: MaterialData = _gem_of_rarity(2)
	MetaState.stash = []
	MetaState.equipped = {}
	var rarity: int = Stash.RARITY_NAMES.size() - 2
	var piece: Dictionary = _wear(kind, rarity)
	var uid: int = Stash.uid(piece)
	if frost != null:
		MetaState.gain_material(frost.id, 1)
		MetaState.socket_gem(uid, frost.id)
	var gems_before: Array[String] = Stash.gems(piece)

	MetaState.shards = 0
	MetaState.marks = 0
	_check(not MetaState.temper_gear(uid).is_empty(), "a piece was tempered for nothing")
	_check(Stash.uid(piece) == uid, "and renamed")

	var last_cost: Dictionary = {}
	for round: int in Balance.GEAR_TEMPER_MAX:
		var cost: Dictionary = Stash.temper_cost(piece)
		_check(not cost.is_empty(), "temper %d of %d is refused by the price" % [round + 1, Balance.GEAR_TEMPER_MAX])
		if cost.is_empty():
			return
		if not last_cost.is_empty():
			_check(int(cost["shards"]) > int(last_cost["shards"]) and int(cost["marks"]) > int(last_cost["marks"]),
				"temper %d costs no more than the one before" % (round + 1))
		last_cost = cost
		MetaState.shards = int(cost["shards"]) - 1
		MetaState.marks = int(cost["marks"])
		_check(not MetaState.temper_gear(Stash.uid(piece)).is_empty(),
			"tempered a Shard short")
		MetaState.shards = int(cost["shards"])
		MetaState.marks = int(cost["marks"]) - 1
		_check(not MetaState.temper_gear(Stash.uid(piece)).is_empty(),
			"tempered a Mark short")
		MetaState.marks = int(cost["marks"])
		var old_name: int = Stash.uid(piece)
		var answer: String = MetaState.temper_gear(old_name)
		_check(answer.is_empty(), "temper %d refused with the price in hand: %s" % [round + 1, answer])
		_check(MetaState.shards == 0 and MetaState.marks == 0,
			"temper %d left %d Shards and %d Marks of a price it should have taken whole"
				% [round + 1, MetaState.shards, MetaState.marks])
		_check(Stash.uid(piece) != old_name, "temper %d did not rename the piece" % (round + 1))
		_check(Stash.tempers(piece) == round + 1, "temper %d counted as %d" % [round + 1, Stash.tempers(piece)])
		# What stays: the kind, the rarity, the level, the gems, and its place.
		_check(String(piece["kind"]) == kind.id and int(piece["rarity"]) == rarity
			and int(piece["level"]) == 1, "tempering changed what the piece is")
		_check(_same(Stash.gems(piece), gems_before), "tempering lost a set gem")
		_check(MetaState.equipped_index(kind.slot) == Stash.index_of(MetaState.stash, Stash.uid(piece)),
			"the tempered piece is no longer the one worn - the equipped map kept the old name")
		# And what a new name rolls is the name's: the same as any piece so named.
		var twin: Dictionary = {"kind": kind.id, "rarity": rarity, "level": 1, "uid": Stash.uid(piece)}
		_check(Stash.affixes(piece, kind) == Stash.affixes(twin, kind),
			"a tempered piece's secondaries are not its new name's")
	_check(Stash.temper_cost(piece).is_empty(), "a piece tempered %d times has a price left" % Balance.GEAR_TEMPER_MAX)
	MetaState.shards = 100000
	MetaState.marks = 100000
	_check(not MetaState.temper_gear(Stash.uid(piece)).is_empty(),
		"a piece was tempered past the cap")
	_check(MetaState.shards == 100000, "and charged for it")


# --- The save ----------------------------------------------------------------

func _test_the_save_round_trip() -> void:
	var kind: GearData = _a_kind()
	var amber: MaterialData = _gem_of_rarity(1)
	var frost: MaterialData = _gem_of_rarity(2)
	if amber == null or frost == null:
		return
	MetaState.stash = []
	MetaState.equipped = {}
	var piece: Dictionary = _wear(kind, Stash.RARITY_NAMES.size() - 2)
	MetaState.gain_material(amber.id, 1)
	MetaState.socket_gem(Stash.uid(piece), amber.id)
	MetaState.shards = 100000
	MetaState.marks = 100000
	MetaState.temper_gear(Stash.uid(piece))
	var uid: int = Stash.uid(piece)
	# Through the real parser, which is what turns the text on disk into what
	# `adopt_save` reads - and JSON has no integers, so every number in it is
	# a float until something makes it one.
	var data: Dictionary = MetaState.parse_save_text(MetaState.serialized_save())
	_check(not data.is_empty(), "the save did not serialize")
	if data.is_empty():
		return
	MetaState.adopt_save(data)
	var index: int = Stash.index_of(MetaState.stash, uid)
	_check(index >= 0, "the tempered piece did not come back by its new name")
	if index < 0:
		return
	var back: Dictionary = MetaState.stash[index]
	_check(_same(Stash.gems(back), [amber.id]),
		"the set gem did not survive the save: %s" % str(back.get("gems", null)))
	_check(Stash.tempers(back) == 1, "the tempering count did not survive the save")
	_check(MetaState.equipped_index(kind.slot) == index, "the worn piece is not worn after the save")

	# A row a hand wrote: an unknown id, a material that is not a gem, more gems
	# than sockets, and a tempering count past the cap - each read as a piece
	# the game could have produced.
	var not_a_gem: String = ""
	for material: MaterialData in ContentDB.materials_sorted():
		if material.kind != MaterialData.Kind.GEM:
			not_a_gem = material.id
			break
	var gear: Array = (data.get("stash", {}) as Dictionary).get("gear", []) as Array
	_check(not gear.is_empty(), "the save's stash block carries no gear")
	for row: Variant in gear:
		if row is Dictionary and int((row as Dictionary).get("uid", 0)) == uid:
			(row as Dictionary)["gems"] = ["no_such_gem", not_a_gem, amber.id, frost.id, amber.id]
			(row as Dictionary)["tempers"] = 99
	MetaState.adopt_save(data)
	index = Stash.index_of(MetaState.stash, uid)
	_check(index >= 0, "the planted row did not read")
	if index >= 0:
		back = MetaState.stash[index]
		_check(_same(Stash.gems(back), [amber.id, frost.id]),
			"a planted row read back as %s - an unknown id, a log, or a third gem was kept"
				% str(Stash.gems(back)))
		_check(Stash.tempers(back) == Balance.GEAR_TEMPER_MAX,
			"a tempering count of 99 read back as %d" % Stash.tempers(back))
	# And a piece from before sockets is unsocketed and untempered.
	for row: Variant in gear:
		if row is Dictionary and int((row as Dictionary).get("uid", 0)) == uid:
			(row as Dictionary).erase("gems")
			(row as Dictionary).erase("tempers")
	MetaState.adopt_save(data)
	index = Stash.index_of(MetaState.stash, uid)
	if index >= 0:
		back = MetaState.stash[index]
		_check(Stash.gems(back).is_empty() and Stash.tempers(back) == 0
			and not back.has("gems") and not back.has("tempers"),
			"a piece written before sockets reads back with some")


# --- The wire ----------------------------------------------------------------

func _test_a_partner_wears_its_gems() -> void:
	var kind: GearData = _a_kind()
	var frost: MaterialData = _gem_of_rarity(2)
	if frost == null:
		return
	MetaState.stash = []
	MetaState.equipped = {}
	var piece: Dictionary = _wear(kind, Stash.RARITY_NAMES.size() - 2)
	MetaState.gain_material(frost.id, 1)
	MetaState.socket_gem(Stash.uid(piece), frost.id)
	var row: Array = WardenSheet.pack_mine()
	var sheet: WardenSheet = WardenSheet.from_row(row)
	_check(sheet.worn.size() == 1, "the packed sheet wears %d pieces" % sheet.worn.size())
	var wanted: float = Balance.GEAR_GEM_MAGNITUDE[frost.rarity]
	_check(is_equal_approx(float(sheet._gear_totals.get(frost.gem_key, 0.0)), wanted),
		"a partner's sheet reads the set gem as %.3f, not %.3f"
			% [float(sheet._gear_totals.get(frost.gem_key, 0.0)), wanted])
	# A row that carries nonsense in the gems, or none at all.
	var worn: Array = (row[WardenSheet.AT_WORN] as Array).duplicate(true)
	(worn[0] as Dictionary)["gems"] = ["no_such_gem", frost.id, frost.id, frost.id]
	row[WardenSheet.AT_WORN] = worn
	sheet = WardenSheet.from_row(row)
	_check(_same(Stash.gems(sheet.worn[0]), [frost.id, frost.id]),
		"a partner's row with nonsense gems read as %s" % str(Stash.gems(sheet.worn[0])))
	(worn[0] as Dictionary).erase("gems")
	sheet = WardenSheet.from_row(row)
	_check(Stash.gems(sheet.worn[0]).is_empty(), "a row from an older build grew gems")


# --- The screen --------------------------------------------------------------

func _test_the_screen() -> void:
	var kind: GearData = _a_kind()
	var amber: MaterialData = _gem_of_rarity(1)
	if amber == null:
		return
	MetaState.stash = []
	MetaState.equipped = {}
	var piece: Dictionary = _wear(kind, Stash.RARITY_NAMES.size() - 2)
	MetaState.gain_material(amber.id, 1)
	MetaState.socket_gem(Stash.uid(piece), amber.id)
	MetaState.shards = 100000
	MetaState.marks = 100000
	MetaState.temper_gear(Stash.uid(piece))
	var screen: StashScreen = StashScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var row: Control = screen.call("_row", 0) as Control
	_check(row != null, "the stash could not build the row")
	var said: String = _labels_under(row)
	_check(said.contains(amber.display_name) and said.contains(Modifiers.label(amber.gem_key)),
		"the row does not name the set gem or what it grants: \"%s\"" % said)
	_check(said.contains("1 empty socket"), "the row does not say a socket is free: \"%s\"" % said)
	_check(said.contains("Tempered x1"), "the row does not say the piece was tempered: \"%s\"" % said)
	if row != null:
		row.queue_free()
	# The shared row every other screen builds says the gem too.
	var shared: HBoxContainer = GearRow.build(piece)
	var shared_said: String = _labels_under(shared)
	_check(shared_said.contains(amber.display_name),
		"the trade window's row does not name the set gem: \"%s\"" % shared_said)
	if shared != null:
		shared.queue_free()
	# And the doors have buttons: the menu calls all three.
	var source: String = FileAccess.get_file_as_string("res://scenes/ui/stash_screen.gd")
	for door: String in ["MetaState.socket_gem(", "MetaState.unsocket_gem(", "MetaState.temper_gear("]:
		_check(source.contains(door), "the stash screen never calls %s" % door)
	screen.queue_free()
	await get_tree().process_frame


func _test_the_bars_carry_it() -> void:
	for workflow: String in ["res://../.github/workflows/guard.yml",
			"res://../.github/workflows/release.yml"]:
		var text: String = FileAccess.get_file_as_string(workflow)
		_check(text.contains("gear_socket_check.tscn"),
			"%s does not run this gate" % workflow.get_file())


# --- Helpers -----------------------------------------------------------------

## Two lists of ids hold the same ids in the same order, whatever their typing.
func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for at: int in a.size():
		if String(a[at]) != String(b[at]):
			return false
	return true


func _labels_under(node: Node) -> String:
	if node == null:
		return ""
	var lines: PackedStringArray = []
	var label := node as Label
	if label != null:
		lines.append(label.text)
	for child: Node in node.get_children():
		lines.append(_labels_under(child))
	return " | ".join(lines)


func _scripts_under(folder: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			out.append(folder.path_join(name))
	for sub: String in dir.get_directories():
		out.append_array(_scripts_under(folder.path_join(sub)))
	return out


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[gear-socket] " + why)
