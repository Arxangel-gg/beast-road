extends Node

## Spirit Companion personalities (owner request, 2026-09-01: "two legendary
## foxes can actually feel different").
##
## Seven promises. The first two are the design bound and the rest are the ways
## this fails quietly:
##
## 1. **Traits are content.** Adding a `.tres` adds a personality every animal in
##    the game can be met wearing, with no code change.
## 2. **No personality is simply better.** A spirit's power is already capped by
##    `SPIRIT_APEX_POWER`; a trait that raised damage would be a third scale
##    nobody is tuning against, and the best trait would become the only one
##    worth keeping. Every envelope trades.
## 3. **Every trait is reachable.** One that no serial ever selects is content
##    that does not exist, and nothing would report it.
## 4. **Two machines derive the same personality.** The trait comes from the
##    animal's serial precisely so it never has to be sent - and that only holds
##    if it is a pure function of things both machines already agree on. The
##    shiny roll had exactly this bug.
## 5. **Bonding banks the trait of the animal you bonded**, not a fresh roll.
## 6. **An old save still loads.** Every bond made before this has `true` where a
##    trait id now goes, and must read back as a bonded spirit with no
##    personality rather than as a corrupt entry.
## 7. **Bias actually changes who gets bitten.** A Protective spirit and a Hunter
##    standing in the same crowd must walk at different bodies, or the whole
##    system is a tooltip.

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	RunState.reset()
	RunState.act = 1
	_test_traits_are_content()
	_test_none_is_simply_better()
	_test_every_trait_is_reachable()
	_test_derivation_is_agreed()
	await _test_bond_banks_the_animals_trait()
	_test_old_save_reads_as_bonded()
	await _test_bias_changes_the_target()
	_finish()


## 1. Content, not a hardcoded list.
func _test_traits_are_content() -> void:
	var kinds: Array[SpiritTraitData] = ContentDB.spirit_trait_list()
	_check(kinds.size() >= 4,
		"there must be personalities to roll, found %d" % kinds.size())
	for kind: SpiritTraitData in kinds:
		_check(not kind.id.is_empty(), "every trait needs an id")
		_check(not kind.display_name.is_empty(),
			"%s needs a name a player can read" % kind.id)
		_check(ContentDB.spirit_trait(kind.id) == kind,
			"%s must be reachable by id" % kind.id)
	_ran += 1


## 2. The bound. Nothing here may be a straight upgrade.
func _test_none_is_simply_better() -> void:
	for kind: SpiritTraitData in ContentDB.spirit_trait_list():
		_check(kind.resting_worth() <= Balance.SPIRIT_TRAIT_WORTH_CEILING + 0.001,
			"%s is worth %.3f at rest against a ceiling of %.2f - a personality "
				% [kind.id, kind.resting_worth(), Balance.SPIRIT_TRAIT_WORTH_CEILING]
				+ "may change which fight a companion is good at, never how good")
		# And each envelope must trade rather than sit flat above one, which is
		# the same failure wearing a different shape.
		_check(minf(kind.damage_near, kind.damage_far) <= 1.001,
			"%s is above one at both distances" % kind.id)
		_check(minf(kind.damage_whole, kind.damage_hurt) <= 1.001,
			"%s is above one at both health levels" % kind.id)
		# A trait that pays out has to have paid for it somewhere.
		if kind.scavenge_chance > 0.0 or kind.reveal_radius > 0.0:
			_check(kind.resting_worth() < 1.0,
				"%s finds things and still fights as well as everything else"
					% kind.id)
	_ran += 1


## 3. Reachable across the serials an actual run produces.
func _test_every_trait_is_reachable() -> void:
	var kinds: Array[SpiritTraitData] = ContentDB.spirit_trait_list()
	var species: Array[WildlifeData] = ContentDB.wildlife()
	if kinds.is_empty() or species.is_empty():
		_ran += 1
		return
	var seen: Dictionary = {}
	for kind: WildlifeData in species:
		for serial: int in range(1, 40):
			var got: SpiritTraitData = SpiritBond.trait_for(kind.id, serial)
			if got != null:
				seen[got.id] = true
	for kind: SpiritTraitData in kinds:
		_check(seen.has(kind.id),
			"%s is never selected by any serial, so it is content nobody can "
				% kind.id + "meet")
	_ran += 1


## 4. Pure, so co-op needs no packet.
func _test_derivation_is_agreed() -> void:
	var species: Array[WildlifeData] = ContentDB.wildlife()
	if species.is_empty():
		_ran += 1
		return
	var kind: WildlifeData = species[0]
	for serial: int in range(1, 25):
		var host: SpiritTraitData = SpiritBond.trait_for(kind.id, serial)
		var guest: SpiritTraitData = SpiritBond.trait_for(kind.id, serial)
		_check(host == guest,
			"serial %d must give both machines the same personality" % serial)
	# And different serials must not all give the same answer, which is what a
	# solo run had while every animal shared serial zero.
	var spread: Dictionary = {}
	for serial: int in range(1, 25):
		var got: SpiritTraitData = SpiritBond.trait_for(kind.id, serial)
		if got != null:
			spread[got.id] = true
	_check(spread.size() >= 2,
		"consecutive animals of one species must not all share a personality, "
			+ "got %d distinct across 24" % spread.size())
	_ran += 1


## 5. The bond banks what it met.
func _test_bond_banks_the_animals_trait() -> void:
	var kinds: Array[SpiritTraitData] = ContentDB.spirit_trait_list()
	var species: Array[WildlifeData] = ContentDB.wildlife()
	if kinds.is_empty() or species.is_empty():
		_ran += 1
		return
	MetaState.spirit_encounters.clear()
	MetaState.spirit_bonded.clear()
	var kind: WildlifeData = species[0]
	var wanted: SpiritTraitData = kinds[0]
	var key: String = SpiritBond.key(kind.id, kind.rarity, false)
	var needed: int = SpiritBond.needed(kind.rarity, false)
	for meeting: int in needed:
		MetaState.record_spirit_encounter(kind.id, kind.rarity, false, wanted.id)
	_check(MetaState.spirit_is_bonded(key),
		"%d encounters must complete the bond" % needed)
	_check(MetaState.spirit_trait(key) == wanted.id,
		"the bond must carry the personality it was made with, got '%s'"
			% MetaState.spirit_trait(key))
	_check(SpiritBond.trait_of_bond(key) == wanted,
		"and must resolve back to the resource")

	# Round trip. The trait rides the existing bonded value, so this is the test
	# that the save shape did not quietly break.
	var text: String = MetaState.serialized_save()
	MetaState.spirit_bonded.clear()
	MetaState.call("_read_spirits",
		(JSON.parse_string(text) as Dictionary).get("spirits", {}) as Dictionary)
	_check(MetaState.spirit_trait(key) == wanted.id,
		"a personality must survive a save and load, got '%s'"
			% MetaState.spirit_trait(key))
	_ran += 1


## 6. Saves written before personalities existed.
func _test_old_save_reads_as_bonded() -> void:
	var key: String = "wolf|2|0"
	MetaState.call("_read_spirits", {
		"encounters": {key: 9},
		"bonded": {key: true},
		"equipped": "",
	})
	_check(MetaState.spirit_is_bonded(key),
		"a bond written as `true` must still be a bond")
	_check(MetaState.spirit_trait(key).is_empty(),
		"and must read as having no personality rather than one called 'true'")
	_check(SpiritBond.trait_of_bond(key) == null,
		"which resolves to no resource at all")
	MetaState.spirit_encounters.clear()
	MetaState.spirit_bonded.clear()
	_ran += 1


## 7. Bias reaches the field.
##
## Built as a crowd rather than asserted on the scoring function, because what
## fails in practice is the wiring: a trait that never reaches the companion
## scores perfectly in isolation and changes nothing in a fight.
func _test_bias_changes_the_target() -> void:
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED:
			breed = one
			break
	var protective: SpiritTraitData = ContentDB.spirit_trait("protective")
	var hunter: SpiritTraitData = ContentDB.spirit_trait("hunter")
	if breed == null or protective == null or hunter == null:
		_check(false, "the crowd needs a breed and both biased traits")
		_ran += 1
		return

	var field := EnemyField.new()
	add_child(field)
	var hero := Node2D.new()
	hero.global_position = Vector2.ZERO
	add_child(hero)

	# **The situation a Protective spirit is actually for**: the companion is out
	# at the end of its leash with an ordinary body right in front of it, while
	# something promoted is standing on the hero behind it.
	#
	# The first version of this put the companion 880px from its hero, which no
	# companion ever is - it follows at `follow_distance` and hunts within
	# `hunt_range`. At that separation the companion's own distance term drowns
	# every bias, so the test failed on a layout the game cannot produce. Bias is
	# a preference and has to be measured somewhere a preference could matter.
	var close: Enemy = _make(field, breed, Vector2(420.0, 0.0), Enemy.Rank.COMMON)
	var guarded: Enemy = _make(field, breed, Vector2(-60.0, 0.0), Enemy.Rank.CHAMPION)
	await _settle()

	_check(_picks(field, hero, null) == close,
		"with no personality a companion must still take the nearest body")
	_check(_picks(field, hero, protective) == guarded,
		"a Protective spirit must go to what is standing over the hero")
	_check(_picks(field, hero, hunter) == guarded,
		"and a Hunter must go to the promoted body")

	close.queue_free()
	guarded.queue_free()
	hero.queue_free()
	field.queue_free()
	Sfx.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	_ran += 1


## Which body a companion with this temperament would cross to.
func _picks(field: EnemyField, hero: Node2D, temperament: SpiritTraitData) -> Enemy:
	var form := CompanionData.new()
	form.id = "probe"
	form.duration = INF
	form.hunt_range = 4000.0
	form.follow_distance = 90.0
	form.attack_range = 70.0
	form.attack_interval = 1.0
	form.damage = 1.0
	form.speed = 200.0
	var friend := Companion.new()
	friend.setup(form, hero, field)
	add_child(friend)
	# Out at the leash, which is where a companion is whenever it is fighting.
	friend.global_position = Vector2(300.0, 0.0)
	friend.set("_temperament", temperament)
	var picked: Enemy = friend.call("_nearest_enemy")
	friend.queue_free()
	return picked


func _make(field: EnemyField, breed: EnemyData, at: Vector2,
		rank: Enemy.Rank) -> Enemy:
	var scene: PackedScene = load("res://scenes/battlefield/enemy.tscn")
	var foe := scene.instantiate() as Enemy
	if rank != Enemy.Rank.COMMON:
		var worn: Array[EnemyAffixData] = []
		for value: Variant in ContentDB.affixes.values():
			var affix := value as EnemyAffixData
			if affix != null:
				worn.append(affix)
				break
		foe.promote(rank, worn)
	foe.setup(breed, 0, field, 1.0)
	field.add_child(foe)
	foe.global_position = at
	return foe


func _settle() -> void:
	for _frame: int in 4:
		await get_tree().process_frame
		await get_tree().physics_frame


func _finish() -> void:
	if _failures == 0 and _ran == 7:
		print("[spirit-trait] PASS - personalities are content, none is simply "
			+ "better, every one is reachable, two machines agree without a "
			+ "packet, and bias reaches the field")
	elif _failures == 0:
		printerr("[spirit-trait] FAIL - only %d of 7 tests ran" % _ran)
		get_tree().quit(1)
		return
	else:
		printerr("[spirit-trait] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[spirit-trait] FAIL: %s" % why)
