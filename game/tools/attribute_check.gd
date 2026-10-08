extends Node

## The five attributes: that there are five, that the fifth is read, and that
## adding it did not add power.
##
##   godot --headless --path game res://tools/attribute_check.tscn
##
## Owner brief, 2026-09-13: "A new 5th stat attribute for our player and gear
## for more build diversity."
##
## **The whole safety argument for a fifth attribute is that it adds no
## points.** A level grants one point and gear grants what the budget pays for,
## exactly as before; five attributes is the same power spread five ways. If
## that ever stops being true, the two capped scales the campaign tiers are
## tuned against (working rule 7) have quietly become two and a half, and
## nothing else in the project would notice. So it is asserted first.
##
## Six ways this can be a lie, all of them things that have happened here to
## something else:
##
## 1. **A fifth attribute nothing reads.** `HERO_FOCUS_SPELL_PER_POINT` sat
##    defined and unread for weeks while the Mansion promised spell power, so
##    the fifth is checked by *measuring* the hero rather than by reading the
##    constant back.
## 2. **A fifth attribute nothing names.** Three screens kept their own list of
##    four names; a fifth that landed in one of them draws "+3 " and no word.
## 3. **A fifth attribute no piece of gear favours.** Reachable only as a
##    secondary bonus is reachable only by accident, and nobody builds for an
##    accident.
## 4. **A save that loses its hero.** The array is positional on disk. A file
##    written with four numbers must read back as those four and a zero.
## 5. **A bonus with nowhere to go.** `GEAR_AFFIX_COUNT`'s top may not ask for
##    more bonuses than a hero has attributes, and `GEAR_AFFIX_SPLIT` must have
##    a row for every count it may ask for.
## 6. **A cap that is not a cap.** Mitigation compounds with the health pool and
##    with every heal in the game, so it is the one number here that must not
##    run away.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260913)

	_test_there_are_five_and_all_are_named()
	_test_a_level_still_grants_one_point()
	_test_gear_favours_the_fifth()
	_test_the_affix_tables_reach()
	_test_an_older_save_keeps_its_hero()
	await _test_the_hero_reads_resolve()
	await _test_thresholds_are_perks_not_points()

	Sfx.stop_immediately()
	Vfx.clear()
	for _f: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[attributes] PASS - %d checks: five named, no new points, gear that wants them, a capped fifth, and thresholds that are perks"
			% _checks)
	else:
		push_error("[attributes] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


## Five, named, described, and the arrays the same length as the enum.
func _test_there_are_five_and_all_are_named() -> void:
	var count: int = RunState.Attribute.size()
	_check(count == 5, "the hero has five attributes, not %d" % count)
	_check(RunState.ATTRIBUTE_NAMES.size() == count,
		"every attribute needs a name: %d names for %d attributes"
			% [RunState.ATTRIBUTE_NAMES.size(), count])
	_check(RunState.ATTRIBUTE_NOTES.size() == count,
		"every attribute needs a line saying what it does")
	for which: int in count:
		_check(not RunState.attribute_name(which).is_empty(),
			"attribute %d has no name" % which)
		_check(not RunState.ATTRIBUTE_NOTES[which].strip_edges().is_empty(),
			"%s says nothing about itself" % RunState.attribute_name(which))
	# The order is positional on disk. MIGHT must stay 0 or every save moves.
	_check(RunState.Attribute.MIGHT == 0 and RunState.Attribute.VIGOUR == 1
			and RunState.Attribute.SWIFTNESS == 2 and RunState.Attribute.FOCUS == 3
			and RunState.Attribute.RESOLVE == 4,
		"the attribute order is what a save is written in; it may not be reordered")
	# And the one list, not a copy of it.
	_check(Stash.ATTRIBUTE_COUNT == count,
		"the stash rolls across %d attributes but the hero has %d"
			% [Stash.ATTRIBUTE_COUNT, count])
	_check(RunState.hero_attributes.size() == count,
		"the hero stores %d attributes" % RunState.hero_attributes.size())
	_check(MetaState.gear_attribute_points().size() == count,
		"gear grants points for %d attributes" % MetaState.gear_attribute_points().size())


## **The fifth attribute added choices, not points.**
##
## Driven rather than asserted from a constant: levels are taken and the points
## they hand over are counted. A fifth attribute that arrived with a fifth point
## would be a power scale the acts were never tuned against.
func _test_a_level_still_grants_one_point() -> void:
	RunState.hero_level = 1
	# And no experience carried in from the account's own hero: `reset` copies
	# the saved hero into the run, so on a machine with a levelled save the
	# eighteen points below were landing on top of hundreds and buying fifteen
	# levels. Fresh on CI, which is why this only ever failed at home.
	RunState.hero_xp = 0.0
	RunState.hero_attribute_points = 0
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	var before: int = RunState.hero_attribute_points
	RunState.gain_hero_xp(RunState.hero_xp_for_level(1) + 1.0)
	var gained: int = RunState.hero_attribute_points - before
	_check(RunState.hero_level == 2, "the harness must reach level 2")
	_check(gained == 1, "a level grants exactly one attribute point, not %d" % gained)

	# And every one of the five may be spent into.
	RunState.hero_attribute_points = RunState.Attribute.size()
	for which: int in RunState.Attribute.size():
		_check(RunState.spend_attribute_point(which).is_empty(),
			"a point must be placeable into %s" % RunState.attribute_name(which))
	_check(RunState.spend_attribute_point(RunState.Attribute.size()) != "",
		"there is no sixth attribute to spend into")
	_check(RunState.attribute(RunState.Attribute.RESOLVE) >= 1,
		"a point placed in Resolve must be readable back")


## **A threshold is a perk, never a point** (docs/GEAR_REWORK_2026-09-28.md §2).
##
## Driven through the doors rather than read off the table: the finisher's
## multiplier on a real hero at the opener and at the last blow, the dash's
## rest, a cast's cost, a shove, and the quiet regen on a real pool - and the
## points the perk was reached with are exactly the points the Warden had.
func _test_thresholds_are_perks_not_points() -> void:
	var kept: Array = RunState.hero_attributes.duplicate()
	var kept_points: int = RunState.hero_attribute_points
	var might: int = RunState.Attribute.MIGHT
	for which: int in RunState.Attribute.size():
		_check(ContentDB.attribute_perk(which) != null,
			"%s has no perk authored" % RunState.attribute_name(which))
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	RunState.hero_attribute_points = 3
	_check(WardenSheet.perk_tiers(null, might) == 0, "no points, no tier")
	RunState.hero_attributes[might] = Balance.ATTRIBUTE_THRESHOLD - 1
	_check(WardenSheet.perk_tiers(null, might) == 0, "one point short of the threshold is no tier")
	RunState.hero_attributes[might] = Balance.ATTRIBUTE_THRESHOLD
	_check(WardenSheet.perk_tiers(null, might) == 1, "the threshold is the first tier")
	RunState.hero_attributes[might] = Balance.ATTRIBUTE_THRESHOLD * (Balance.ATTRIBUTE_PERK_TIERS + 3)
	_check(WardenSheet.perk_tiers(null, might) == Balance.ATTRIBUTE_PERK_TIERS,
		"the tiers stop at the ceiling")
	_check(RunState.hero_attribute_points == 3 and RunState.attribute(might)
			== Balance.ATTRIBUTE_THRESHOLD * (Balance.ATTRIBUTE_PERK_TIERS + 3),
		"a perk must neither spend nor grant a point")
	# A partner's sheet answers for the partner. The row packs the account
	# (`MetaState`), and a sheet is cleaned to what its level could have
	# placed, so the account is stood up as a levelled Warden for the pack.
	var kept_meta: Array = MetaState.hero_attributes.duplicate()
	var kept_level: int = MetaState.hero_level
	MetaState.hero_level = Balance.ATTRIBUTE_THRESHOLD * Balance.ATTRIBUTE_PERK_TIERS + 1
	MetaState.hero_attributes = [Balance.ATTRIBUTE_THRESHOLD * Balance.ATTRIBUTE_PERK_TIERS, 0, 0, 0, 0]
	var row: Array = WardenSheet.pack_mine()
	MetaState.hero_attributes = kept_meta
	MetaState.hero_level = kept_level
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	var partner: WardenSheet = WardenSheet.from_row(row)
	_check(WardenSheet.perk_tiers(partner, might) == Balance.ATTRIBUTE_PERK_TIERS
			and WardenSheet.perk_tiers(null, might) == 0,
		"a partner's thresholds must be read off the partner's sheet (%d tiers)" % WardenSheet.perk_tiers(partner, might))

	# The doors, on a real hero.
	var field := EnemyField.new()
	add_child(field)
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	field.add_child(hero)
	await get_tree().process_frame
	var perk: AttributePerkData = ContentDB.attribute_perk(might)
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	hero.attack.set("_step", 0)
	var opener_plain: float = hero.damage_multiplier()
	hero.attack.set("_step", Balance.HERO_CHAIN_LENGTH - 1)
	var finisher_plain: float = hero.damage_multiplier()
	RunState.hero_attributes[might] = Balance.ATTRIBUTE_THRESHOLD * 2
	var finisher_heavy: float = hero.damage_multiplier()
	hero.attack.set("_step", 0)
	var opener_heavy: float = hero.damage_multiplier()
	var might_alone: float = 1.0 + float(Balance.ATTRIBUTE_THRESHOLD * 2) * Balance.HERO_MIGHT_PER_POINT
	_check(is_equal_approx(opener_heavy / opener_plain, might_alone),
		"Heavy Hand must leave the opener to Might alone (%.3f against %.3f)" % [opener_heavy / opener_plain, might_alone])
	_check(is_equal_approx(finisher_heavy / finisher_plain, might_alone * (1.0 + 2.0 * perk.per_tier)),
		"two tiers of Heavy Hand must land %.0f%% on the finisher (%.3f against %.3f)"
			% [2.0 * perk.per_tier * 100.0, finisher_heavy / finisher_plain, might_alone * (1.0 + 2.0 * perk.per_tier)])
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	var rest_plain: float = hero.dash_cooldown()
	RunState.hero_attributes[RunState.Attribute.SWIFTNESS] = Balance.ATTRIBUTE_THRESHOLD
	var swift: AttributePerkData = ContentDB.attribute_perk(RunState.Attribute.SWIFTNESS)
	_check(is_equal_approx(hero.dash_cooldown(), rest_plain * (1.0 - swift.per_tier)),
		"Light Step must rest the dash sooner by one tier")
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	_check(is_equal_approx(hero.cast_cost_scale(), 1.0), "no Focus tier, full price")
	RunState.hero_attributes[RunState.Attribute.FOCUS] = Balance.ATTRIBUTE_THRESHOLD * 3
	var focus: AttributePerkData = ContentDB.attribute_perk(RunState.Attribute.FOCUS)
	_check(is_equal_approx(hero.cast_cost_scale(), 1.0 - 3.0 * focus.per_tier),
		"three tiers of Clear Mind must take %.0f%% off a cast" % (3.0 * focus.per_tier * 100.0))
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	hero.shove(Vector2(200.0, 0.0))
	var shoved_plain: float = (hero.get("_shoved") as Vector2).length()
	hero.set("_shoved", Vector2.ZERO)
	RunState.hero_attributes[RunState.Attribute.RESOLVE] = Balance.ATTRIBUTE_THRESHOLD
	hero.shove(Vector2(200.0, 0.0))
	var shoved_unbowed: float = (hero.get("_shoved") as Vector2).length()
	var resolve: AttributePerkData = ContentDB.attribute_perk(RunState.Attribute.RESOLVE)
	_check(shoved_plain > 0.0 and is_equal_approx(shoved_unbowed / shoved_plain, 1.0 - resolve.per_tier),
		"Unbowed must shove one tier less (%.3f of the plain shove)" % (shoved_unbowed / maxf(shoved_plain, 0.001)))
	hero.set("_shoved", Vector2.ZERO)
	# Second Wind on a real pool: nothing without Vigour, a rise with it, and
	# only once the Warden has been quiet.
	RunState.hero_attributes = [0, 0, 0, 0, 0]
	hero.health.current_hp = hero.health.max_hp * 0.5
	hero.set("_quiet_since", Balance.HERO_REGEN_QUIET + 1.0)
	hero.call("_tick_timers", 1.0)
	_check(is_equal_approx(hero.health.current_hp, hero.health.max_hp * 0.5),
		"Second Wind healed a Warden with no tier of Vigour")
	RunState.hero_attributes[RunState.Attribute.VIGOUR] = Balance.ATTRIBUTE_THRESHOLD
	hero.set("_quiet_since", 0.0)
	hero.call("_tick_timers", 1.0)
	_check(is_equal_approx(hero.health.current_hp, hero.health.max_hp * 0.5),
		"Second Wind healed a Warden that was struck a second ago")
	hero.set("_quiet_since", Balance.HERO_REGEN_QUIET + 1.0)
	hero.call("_tick_timers", 1.0)
	var vigour: AttributePerkData = ContentDB.attribute_perk(RunState.Attribute.VIGOUR)
	var rose: float = hero.health.current_hp - hero.health.max_hp * 0.5
	_check(absf(rose - hero.health.max_hp * vigour.per_tier) < 0.5,
		"one tier of Second Wind must return %.0f%% of the pool a second; it returned %.1f of %.0f"
			% [vigour.per_tier * 100.0, rose, hero.health.max_hp])
	hero.queue_free()
	field.queue_free()
	await get_tree().process_frame
	RunState.hero_attributes = kept
	RunState.hero_attribute_points = kept_points


## Gear that *is* Resolve, not gear that happens to carry some.
##
## A slot with no Resolve primary is a slot where the attribute is unbuildable,
## and a stash where none of the eight slots has one makes the fifth attribute
## a thing that occasionally happens to you.
func _test_gear_favours_the_fifth() -> void:
	var by_slot: Dictionary = {}
	var by_attribute: Dictionary = {}
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind == null:
			continue
		by_attribute[kind.attribute] = int(by_attribute.get(kind.attribute, 0)) + 1
		if kind.attribute == RunState.Attribute.RESOLVE:
			by_slot[kind.slot] = int(by_slot.get(kind.slot, 0)) + 1
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no icon at %s" % [kind.id, kind.get_sprite_path()])
	for which: int in RunState.Attribute.size():
		_check(int(by_attribute.get(which, 0)) > 0,
			"no piece of gear favours %s, so nothing drops that builds it"
				% RunState.attribute_name(which))
	for slot: int in GearData.Slot.size():
		_check(int(by_slot.get(slot, 0)) > 0,
			"the %s slot has no Resolve piece, so the slot cannot be built that way"
				% GearData.name_of_slot(slot))


## The affix tables reach as far as they promise.
##
## Every array keyed by rarity is read through a clamp, so a short one does not
## crash - it silently gives the top rarity whatever the one below was worth.
func _test_the_affix_tables_reach() -> void:
	var top: int = Balance.GEAR_AFFIX_COUNT[Balance.GEAR_AFFIX_COUNT.size() - 1]
	_check(top <= RunState.Attribute.size(),
		"the top rarity asks for %d bonuses and a hero has %d places to put them"
			% [top, RunState.Attribute.size()])
	_check(Balance.GEAR_AFFIX_SPLIT.size() >= top,
		"a piece may carry %d bonuses but only %d splits are authored"
			% [top, Balance.GEAR_AFFIX_SPLIT.size()])
	for row: Array in Balance.GEAR_AFFIX_SPLIT:
		var total: float = 0.0
		for share: float in row:
			total += share
		_check(absf(total - 1.0) < 0.01,
			"a split must sum to one, or a piece gains or loses points by rarity: %.3f" % total)
	# A top-rarity piece with a real budget dresses as many as the table says.
	var kind: GearData = null
	for value: Variant in ContentDB.gear_kinds.values():
		var candidate := value as GearData
		if candidate != null and candidate.base_points >= 4:
			kind = candidate
			break
	if kind == null:
		return
	var rarity: int = Balance.GEAR_AFFIX_COUNT.size() - 1
	var piece: Dictionary = {"kind": kind.id, "rarity": rarity, "level": 10, "uid": "resolve-probe"}
	var rolled: Array[Dictionary] = Stash.affixes(piece, kind)
	var budget: int = Stash.points(piece, kind)
	var spent: int = 0
	var seen: Dictionary = {}
	for affix: Dictionary in rolled:
		spent += int(affix["points"])
		seen[int(affix["attribute"])] = true
	_check(spent == budget,
		"the bonuses must sum to the budget: %d against %d" % [spent, budget])
	_check(seen.size() == rolled.size(), "a piece may not bonus the same attribute twice")
	_check(rolled.size() == mini(top, budget),
		"a top-rarity piece worth %d points carries %d bonuses, not %d"
			% [budget, mini(top, budget), rolled.size()])


## A save written before the fifth attribute reads back with a fifth of zero.
##
## The array is positional on disk, which is why Resolve was appended rather
## than inserted. Driven through the real load path.
func _test_an_older_save_keeps_its_hero() -> void:
	MetaState.hero_level = 9
	MetaState.hero_attributes = [0, 0, 0, 0, 0]
	MetaState.hero_attribute_points = 0
	MetaState._read_hero({
		"level": 9,
		"experience": 0.0,
		"attributes": [3, 2, 1, 2],
		"attribute_points": 0,
	})
	_check(MetaState.hero_attributes.size() == RunState.Attribute.size(),
		"a four-entry save must load into five slots")
	_check(MetaState.hero_attributes[0] == 3 and MetaState.hero_attributes[1] == 2
			and MetaState.hero_attributes[2] == 1 and MetaState.hero_attributes[3] == 2,
		"an older hero's four numbers must land where they were: %s"
			% str(MetaState.hero_attributes))
	_check(MetaState.hero_attributes[4] == 0,
		"and Resolve must arrive at zero, not at somebody else's number")


## The hero actually reads it, measured on the body.
##
## `HERO_FOCUS_SPELL_PER_POINT` was defined and read by nothing for weeks while
## a screen promised what it did, so this drives a real hero and reads the
## numbers off it rather than trusting the constants.
func _test_the_hero_reads_resolve() -> void:
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var hero: Hero = run.battlefield.hero if run.battlefield != null else null
	if hero == null or hero.health == null:
		_check(false, "the harness needs a hero on a battlefield")
		run.queue_free()
		return

	RunState.hero_attributes = [0, 0, 0, 0, 0]
	MetaState.equipped.clear()
	hero._apply_permanent_bonuses()
	var bare_scale: float = hero.health.damage_scale
	var bare_ward: float = hero.health.shield_scale
	_check(is_equal_approx(bare_scale, 1.0),
		"a hero with no Resolve stands exactly where every hero stood before it: %.3f" % bare_scale)
	# **Amended 2026-10-08**: every ward on a Warden is `HERO_WARD_SCALE` of
	# what it was, Resolve or none; what this holds is that no Resolve adds
	# nothing on top of that.
	_check(is_equal_approx(bare_ward, Balance.HERO_WARD_SCALE), "and their wards are worth exactly what they were")

	RunState.hero_attributes[RunState.Attribute.RESOLVE] = 30
	hero._apply_permanent_bonuses()
	_check(hero.health.damage_scale < bare_scale,
		"thirty points of Resolve must make a blow land softer: %.3f" % hero.health.damage_scale)
	_check(hero.health.shield_scale > bare_ward,
		"and a ward worth more: %.3f" % hero.health.shield_scale)

	# Measured on a real blow, because `damage_scale` is a field and a field can
	# be set by something that never reads it.
	var full: float = hero.health.max_hp
	hero.health.current_hp = full
	hero.health.take_damage(100.0, hero.global_position + Vector2.RIGHT * 40.0)
	var with_resolve: float = full - hero.health.current_hp
	RunState.hero_attributes[RunState.Attribute.RESOLVE] = 0
	hero._apply_permanent_bonuses()
	hero.health.current_hp = hero.health.max_hp
	var whole: float = hero.health.max_hp
	hero.health.take_damage(100.0, hero.global_position + Vector2.RIGHT * 40.0)
	var without: float = whole - hero.health.current_hp
	_check(with_resolve < without,
		"a hundred damage must land for less on a resolved hero: %.1f against %.1f"
			% [with_resolve, without])

	# The cap. Mitigation compounds with the pool and with every heal, so this
	# is the one number here that must not run away.
	RunState.hero_attributes[RunState.Attribute.RESOLVE] = 100000
	hero._apply_permanent_bonuses()
	_check(hero.health.damage_scale >= 1.0 - Balance.HERO_RESOLVE_MITIGATION_CAP - 0.001,
		"mitigation must cap at %d%%, not reach %.3f"
			% [int(Balance.HERO_RESOLVE_MITIGATION_CAP * 100.0), 1.0 - hero.health.damage_scale])
	_check(hero.health.damage_scale > 0.0, "a blow may never land for nothing")
	_check(hero.health.shield_scale <= 1.0 + Balance.HERO_RESOLVE_WARD_CAP + 0.001,
		"and the ward bonus must cap too")

	RunState.hero_attributes = [0, 0, 0, 0, 0]
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 10:
		await get_tree().process_frame
	GameDirector.run_active = false
