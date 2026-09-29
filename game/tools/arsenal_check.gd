extends Node

## The Arsenal fires, lands through the one door, scales by the one formula,
## ends its chain reactions, freezes with its scope, and does what the curve
## says it does.
##
##   godot --headless --path game res://tools/arsenal_check.tscn
##
## Owner, 2026-09-27: augments *"more like Megabonk and Tower of Babel ...
## providing new little ways of dealing damage to enemies. The augs still scale
## in game and are also affected by the player's gear and persistent player
## level etc. And even so with it all it still needs to be perfectly balanced."*
## (`docs/AUTO_ARSENAL_2026-09-27.md`)
##
## Each bound is driven on a real battlefield rather than read back:
##
## - **It lands.** Every weapon, alone in the hand, is stood beside a crowd and
##   must hurt it through `Enemy.take_damage`, named in the ledger as its card.
## - **It is what the curve models.** What each weapon dealt a second against a
##   standing crowd is held to its `modelled_dps` - the one line `curve_report`
##   reads - within a band, so the curve cannot be tuned on a model the fight
##   disagrees with.
## - **One formula.** A hit moves with the level, the act, the Warden's Might and
##   the Arsenal's power by exactly the factors the design names, and Focus and
##   the cadence catalyst shorten the cadence to its floor.
## - **A chain reaction ends.** A kill-weapon's own payload never re-fires it,
##   and it fires at most `ARSENAL_KILL_TRIGGERS_PER_SECOND` a second.
## - **It freezes with the field** (working rule 8).
## - **The deal**: a retired card is never dealt, an evolution only to a hand
##   that earned it, and taking one swaps its weapon in the same place.

const BREED: String = "bogkin"
## How long each weapon is measured, in seconds of the field's own clock.
const MEASURE_SECONDS: float = 8.0
## The band a weapon's measured damage a second must sit in, as a share of its
## model. Wide on purpose: a crowd stood still is not a road, and what this
## catches is a weapon that is an order of magnitude off - one that never fires,
## or fires ten times - which is what would make the curve a fiction.
const MODEL_LOW: float = 0.35
const MODEL_HIGH: float = 2.8
## The standard crowd: this many bodies over a disc this wide.
const CROWD_BODIES: int = 14
const CROWD_RADIUS: float = 240.0
## The ring a trail's Warden walks through the crowd.
const WALK_RING: float = 150.0

var _failures: int = 0
var _checks: int = 0
var _reached: Dictionary = {}
var _run: Run = null
var _field: Battlefield = null
var _hero: Hero = null
var _ratios: PackedStringArray = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260927)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_hero = _field.hero if _field != null else null
	RunState.gain_every_currency(50000)
	_quiet_the_road()

	_test_every_weapon_is_authored()
	_test_the_deal()
	_test_the_seats()
	await _test_the_formula()
	await _test_the_elements_react()
	await _test_every_weapon_lands()
	await _test_a_chain_reaction_ends()
	await _test_it_freezes_with_the_field()
	await _test_the_defence()
	_test_the_dice_are_the_runs()

	for stage: String in ["authored", "deal", "seats", "formula", "reacts", "lands", "ends",
			"freezes", "defence"]:
		_check(_reached.has(stage),
			"'%s' never reached its end - it aborted partway, and every check it had not made is unmade" % stage)
	_hold([])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	print("[arsenal] measured / modelled: " + ", ".join(_ratios))
	if _failures == 0:
		print(("[arsenal] PASS - %d checks: every weapon lands through the one door and "
			+ "is what the curve models, one formula scales it, a chain reaction ends, it "
			+ "freezes with the field, and the deal deals only what is earned") % _checks)
	else:
		push_error("[arsenal] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[arsenal] " + why)


## Nothing on the road but what the gate stands there: no waves, no weather, no
## walk, a town that cannot fall and a Warden who cannot - a probe that dies
## mid-measurement reads exactly like a weapon that does not work.
func _quiet_the_road() -> void:
	if _field == null:
		return
	if _field.wave_director != null:
		_field.wave_director.stop()
	_field.sky().events_enabled = false
	# **And the sky is held dry.** A storm weapon hits a wet body harder, and a
	# seed that happens to rain would measure every air weapon half again above
	# its model - and the reactions test wants dry ground to wet by hand.
	_field.sky().forced_intensity = 0.0
	RunState.flood = 0.0
	if _run.journey != null:
		_run.journey.stop()
	if _field.town != null and _field.town.health != null:
		_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	if _hero != null:
		_hero.health.floor_hp = _hero.health.max_hp * 0.5
	# **And the road's own animals are stilled.** A predator killing one of
	# the chain test's bodies is a natural kill, and rightly sets a kill-weapon
	# loose - which read as the payload firing itself, one run in two.
	var animals: Wildlife = _field.wildlife()
	if animals != null:
		animals.clear()
		animals.process_mode = Node.PROCESS_MODE_DISABLED


func _hold(ids: Array, level: int = 1) -> void:
	var hand: Array[String] = []
	var levels: Dictionary = {}
	for id: Variant in ids:
		hand.append(String(id))
		levels[String(id)] = level
	RunState.hands_split = false
	RunState.road_cards = hand
	RunState.road_card_levels = levels
	Modifiers.rebuild()
	EventBus.augment_hand_changed.emit()


func _weapon_cards() -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ContentDB.road_cards:
		var card: RoadCardData = ContentDB.road_card(String(id))
		if card != null and card.is_weapon():
			out.append(card.id)
	out.sort()
	return out


# --- Authored -------------------------------------------------------------------


func _test_every_weapon_is_authored() -> void:
	var named: Dictionary = {}
	for id: String in _weapon_cards():
		var card: RoadCardData = ContentDB.road_card(id)
		var weapon: ArsenalWeaponData = card.weapon_data()
		_check(weapon != null, "%s fires '%s', which is not a weapon" % [id, card.weapon])
		if weapon == null:
			continue
		named[weapon.id] = true
		_check(weapon.level_damage.size() == Balance.AUGMENT_MAX_LEVEL
				and weapon.level_count.size() == Balance.AUGMENT_MAX_LEVEL
				and weapon.level_radius.size() == Balance.AUGMENT_MAX_LEVEL,
			"%s: every level table holds one entry a level" % weapon.id)
		if weapon.is_defensive():
			# **A defence has a number of its own and no hit to model.** Its
			# ladder climbs the share, the stones or the ring rather than a blow,
			# and the curve reads it as nothing (docs/ARSENAL_DEFENSIVE_2026-09-28.md §2).
			_check(weapon.cooldown > 0.0, "%s: a defence still has a cadence" % weapon.id)
			_check(is_zero_approx(weapon.modelled_dps(1)) and is_zero_approx(weapon.modelled_dps(5)),
				"%s: a defence must model as nothing, and it reads %.2f" % [weapon.id, weapon.modelled_dps(5)])
			for level: int in range(2, Balance.AUGMENT_MAX_LEVEL + 1):
				_check(_defence_worth(weapon, level) > _defence_worth(weapon, level - 1),
					"%s: level %d must be worth more than level %d, or taking it again is a wasted pick"
						% [weapon.id, level, level - 1])
			match weapon.pattern:
				ArsenalWeaponData.Pattern.WARD, ArsenalWeaponData.Pattern.MEND:
					_check(weapon.share > 0.0 and weapon.share_at(Balance.AUGMENT_MAX_LEVEL) <= (
						Balance.ARSENAL_WARD_CEILING if weapon.pattern == ArsenalWeaponData.Pattern.WARD
						else Balance.ARSENAL_MEND_CEILING),
						"%s: a share, and one inside its ceiling at level V" % weapon.id)
				ArsenalWeaponData.Pattern.RETORT:
					_check(weapon.damage > 0.0 and weapon.radius > 0.0, "%s: a retort hits, and reaches" % weapon.id)
				ArsenalWeaponData.Pattern.GUARD:
					_check(weapon.count > 0 and weapon.radius > 0.0, "%s: a guard has stones on a ring" % weapon.id)
				ArsenalWeaponData.Pattern.FIELD:
					_check(weapon.radius > 0.0 and weapon.slow < 1.0, "%s: a field reaches, and slows" % weapon.id)
			if not card.evolves_from.is_empty():
				var base_weapon: ArsenalWeaponData = ContentDB.road_card(card.evolves_from).weapon_data() \
					if ContentDB.road_card(card.evolves_from) != null else null
				_check(base_weapon != null and _defence_worth(weapon, 1) >= _defence_worth(base_weapon, Balance.AUGMENT_MAX_LEVEL),
					"%s must be worth at least what %s is at its last level, or evolving is a loss" % [id, card.evolves_from])
		else:
			_check(weapon.damage > 0.0 and weapon.cooldown > 0.0 and weapon.crowd > 0.0,
				"%s: damage, cadence and crowd must all be positive" % weapon.id)
			for level: int in range(2, Balance.AUGMENT_MAX_LEVEL + 1):
				_check(weapon.modelled_dps(level) > weapon.modelled_dps(level - 1),
					"%s: level %d must be stronger than level %d, or taking it again is a wasted pick"
						% [weapon.id, level, level - 1])
		# **A count the runtime never reads is a model that lies.** A pulse, a
		# trail, a burst and a tower's volley fire once where they stand, so a
		# count or a count that grows would multiply the curve's figure and
		# nothing on the field.
		if _fires_once(weapon):
			_check(weapon.count == 1 and weapon.level_count.max() == 0,
				"%s fires once where it stands, and authors a count the fight never reads" % weapon.id)
		if not weapon.effect.is_empty():
			_check(Vfx.FORGE_CATALOGUE.has(weapon.effect),
				"%s plays '%s', which the forge does not know" % [weapon.id, weapon.effect])
		if not weapon.head.is_empty():
			_check(ResourceLoader.exists(Arsenal.HEAD_FORMAT % weapon.head),
				"%s wears the head '%s', which has no art" % [weapon.id, weapon.head])
		if not card.evolves_from.is_empty():
			var base: RoadCardData = ContentDB.road_card(card.evolves_from)
			var catalyst: RoadCardData = ContentDB.road_card(card.evolves_with)
			_check(base != null and base.is_weapon() and base.levels(),
				"%s evolves from '%s', which is not a weapon that levels" % [id, card.evolves_from])
			_check(catalyst != null and not catalyst.is_weapon() and not catalyst.keystone,
				"%s evolves with '%s', which is not a catalyst" % [id, card.evolves_with])
			_check(card.max_level() == 1, "%s is the top of a weapon and must not level" % id)
			if base != null and base.weapon_data() != null and not weapon.is_defensive():
				_check(weapon.modelled_dps(1) > base.weapon_data().modelled_dps(Balance.AUGMENT_MAX_LEVEL),
					"%s must be stronger than %s at its last level, or evolving is a loss" % [id, base.id])
	for id: Variant in ContentDB.arsenal_weapons:
		_check(named.has(String(id)), "the weapon '%s' is fired by no card" % id)
	# **The deck's ratio** (docs/ARSENAL_DEFENSIVE_2026-09-28.md §3): a hand with
	# nothing to keep you standing is a way of killing and nothing else.
	var weapons: int = 0
	var defences: int = 0
	for id: String in _weapon_cards():
		var weapon: ArsenalWeaponData = ContentDB.road_card(id).weapon_data()
		if weapon == null:
			continue
		weapons += 1
		if weapon.is_defensive():
			defences += 1
	_check(float(defences) >= float(weapons) * Balance.ARSENAL_DEFENCE_SHARE,
		"%d of %d weapons are defence - under the %.0f%% the deck is held to"
			% [defences, weapons, Balance.ARSENAL_DEFENCE_SHARE * 100.0])
	_reached["authored"] = true


## What a defence is worth at a level: its share, its stones or its ring.
func _defence_worth(weapon: ArsenalWeaponData, level: int) -> float:
	match weapon.pattern:
		ArsenalWeaponData.Pattern.WARD, ArsenalWeaponData.Pattern.MEND:
			return weapon.share_at(level)
		ArsenalWeaponData.Pattern.GUARD:
			# Stones arrive at III and V; the ring widens a step at every level,
			# so no level is a wasted pick.
			return float(weapon.count_at(level)) * 100.0 + weapon.damage_at(level) + weapon.radius_at(level)
		ArsenalWeaponData.Pattern.FIELD:
			return weapon.radius_at(level)
	return weapon.damage_at(level) * weapon.radius_at(level)


func _fires_once(weapon: ArsenalWeaponData) -> bool:
	match weapon.pattern:
		ArsenalWeaponData.Pattern.NOVA, ArsenalWeaponData.Pattern.TRAIL:
			return true
		ArsenalWeaponData.Pattern.STRIKE:
			return weapon.anchor == ArsenalWeaponData.Anchor.TOWERS
		ArsenalWeaponData.Pattern.ON_KILL:
			return weapon.speed <= 0.0
	return false


# --- The deal -------------------------------------------------------------------


func _test_the_deal() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 20260927
	var dealt_retired: Array[String] = []
	var dealt_weapons: int = 0
	for round: int in 400:
		var act: int = 1 + round % Balance.ACT_COUNT
		for id: String in Augments.deal(dice, 3, 0, [], {}, act, [], 0, []):
			var card: RoadCardData = ContentDB.road_card(id)
			if card.retired:
				dealt_retired.append(id)
			if card.is_weapon():
				dealt_weapons += 1
	_check(dealt_retired.is_empty(),
		"a retired card was dealt: %s - the relic-like cards the owner named are back" % str(dealt_retired))
	_check(dealt_weapons > 400, "four hundred drafts dealt only %d weapons" % dealt_weapons)

	var sunwheel: RoadCardData = ContentDB.road_card("sunwheel")
	_check(not Augments.may_deal(sunwheel, [], {}, []), "an evolution was offered to an empty hand")
	_check(not Augments.may_deal(sunwheel, ["ember_wisps", "twin_casting"],
			{"ember_wisps": 4, "twin_casting": 1}, []),
		"an evolution was offered before its weapon reached its last level")
	_check(not Augments.may_deal(sunwheel, ["ember_wisps"], {"ember_wisps": 5}, []),
		"an evolution was offered without its catalyst")
	_check(Augments.may_deal(sunwheel, ["ember_wisps", "twin_casting"],
			{"ember_wisps": 5, "twin_casting": 1}, []),
		"an earned evolution was not offered")
	_check(Augments.may_deal(ContentDB.road_card("frost_shards"), ["ember_wisps"],
			{"ember_wisps": 1}, []),
		"a second weapon was refused as if two weapons were one card")

	_hold(["ember_wisps", "twin_casting", "chain_spark"], 5)
	var went: String = RunState.take_road_card("sunwheel")
	_check(went == "ember_wisps" and RunState.road_cards.has("sunwheel")
			and RunState.road_cards.has("twin_casting") and RunState.road_cards.size() == 3,
		"taking an evolution did not swap its weapon in the same place: gave up '%s', hand %s"
			% [went, str(RunState.road_cards)])
	# **A weapon that has evolved is not dealt again** (2026-09-27) - it became
	# the evolution. The curve's planner was offered Chain Spark back beside its
	# own Stormcrown, and so was every player.
	_check(not Augments.may_deal(ContentDB.road_card("ember_wisps"), RunState.road_cards,
			RunState.road_card_levels, []),
		"Ember Wisps was offered to a hand already holding the Sunwheel it became")
	# **And an evolution is the mid-run spike**: none opens before Act III, where
	# a Stormcrown at the end of Act II made that act softer than the first.
	var earned: Array = ["ember_wisps", "twin_casting"]
	var at_five: Dictionary = {"ember_wisps": 5, "twin_casting": 1}
	_check(not Augments.candidates(earned, at_five, 2, []).has("sunwheel"),
		"an evolution was dealt in Act II")
	_check(Augments.candidates(earned, at_five, 3, []).has("sunwheel"),
		"an earned evolution was not dealt in Act III")
	# A retired card still resolves, so a banked front that holds one reads it.
	_hold(["set_stance"])
	_check(Modifiers.value(Modifiers.HERO_DAMAGE) > 0.0,
		"a retired card held by an old front no longer reaches the table")
	_hold([])
	_reached["deal"] = true


func _test_the_seats() -> void:
	_check(Augments.seat_keeps(ContentDB.road_card("ember_wisps")),
		"a weapon at a Warden's shoulder must be that Warden's own in co-op")
	_check(not Augments.seat_keeps(ContentDB.road_card("sentry_wisps")),
		"a weapon on the towers must be the party's")
	_check(not Augments.seat_keeps(ContentDB.road_card("falling_stars")),
		"a weapon on the town must be the party's")
	_check(Augments.seat_keeps(ContentDB.road_card("quickening_oil")),
		"a catalyst is read per Warden and must be that Warden's own")
	_check(Augments.seat_keeps(ContentDB.road_card("lantern_ward")),
		"a ward at a Warden's shoulder must be that Warden's own")
	_check(not Augments.seat_keeps(ContentDB.road_card("masons_wisps")),
		"a mend on the towers must be the party's")
	_reached["seats"] = true


# --- The formula ----------------------------------------------------------------


func _test_the_formula() -> void:
	if _hero == null or _hero.arsenal == null:
		_check(false, "the Warden carries no Arsenal")
		return
	var arsenal: Arsenal = _hero.arsenal
	var weapon: ArsenalWeaponData = ContentDB.arsenal_weapon("seeking_flames")
	_hold(["seeking_flames"])
	RunState.act = 1
	var base: float = arsenal.hit_for(weapon, 1)
	_check(is_equal_approx(base, weapon.damage * arsenal.owner_multiplier()),
		"a level I hit in Act I is %.2f, not its damage times the Warden's multiplier (%.2f)"
			% [base, weapon.damage * arsenal.owner_multiplier()])
	_check(is_equal_approx(arsenal.hit_for(weapon, 5) / base, weapon.level_damage[4]),
		"level V does not multiply the hit by its own table")
	RunState.act = 6
	_check(is_equal_approx(arsenal.hit_for(weapon, 1) / base, Balance.arsenal_act_scale(6)),
		"Act VI does not multiply the hit by the act ladder")
	RunState.act = 1

	# Might is the Warden's level and gear: the hit moves with the swing.
	var might: int = RunState.Attribute.MIGHT
	var kept: Array = RunState.hero_attributes.duplicate()
	var swing_before: float = _hero.damage_multiplier()
	RunState.hero_attributes[might] = int(RunState.hero_attributes[might]) + 40
	var swing_after: float = _hero.damage_multiplier()
	_check(swing_after > swing_before, "forty points of Might did not move the Warden's swing")
	_check(is_equal_approx(arsenal.hit_for(weapon, 1) / base, swing_after / swing_before),
		("the Arsenal did not grow with the Warden's Might (%.3f against the swing's %.3f) - "
			+ "gear and level must reach it") % [arsenal.hit_for(weapon, 1) / base, swing_after / swing_before])
	RunState.hero_attributes = kept

	_hold(["seeking_flames", "kindled_heart"])
	_check(is_equal_approx(arsenal.hit_for(weapon, 1) / base,
			1.0 + ContentDB.road_card("kindled_heart").effect_magnitude),
		"Kindled Heart does not multiply the Arsenal by its own number")

	# Cadence: Focus and the catalyst, to the floor and never past it.
	_hold(["seeking_flames"])
	var focus: int = RunState.Attribute.FOCUS
	kept = RunState.hero_attributes.duplicate()
	var plain: float = arsenal.cadence(weapon)
	_check(is_equal_approx(plain, weapon.cooldown * maxf(1.0 - _focus_share(), Balance.ARSENAL_CADENCE_FLOOR)),
		"the cadence with no catalyst is not the authored one less Focus")
	RunState.hero_attributes[focus] = int(RunState.hero_attributes[focus]) + 30
	_check(arsenal.cadence(weapon) < plain, "thirty points of Focus did not quicken the Arsenal")
	RunState.hero_attributes[focus] = 500
	_hold(["seeking_flames", "quickening_oil"], 5)
	_check(arsenal.cadence(weapon) >= weapon.cooldown * Balance.ARSENAL_CADENCE_FLOOR - 0.0001,
		"Focus and the catalyst drove the cadence past its floor")
	RunState.hero_attributes = kept
	_hold(["seeking_flames", "twin_casting"])
	_check(arsenal.count_for(weapon, 1) == weapon.count_at(1) + 1,
		"Twin Casting did not add one to the volley")
	_hold([])
	await get_tree().process_frame
	_reached["formula"] = true


## **The Arsenal answers the elements as a tower's shot does** (2026-09-27): an
## air weapon hits a wet body harder, a water weapon leaves what it hits wet, a
## chain leaving a wet body leaps further - and an earth weapon does none of it.
## Driven through the Arsenal's own `strike_body` and `_fire_chain` with its
## clock stopped, so nothing but the blow under test reaches the bodies.
func _test_the_elements_react() -> void:
	var breed: EnemyData = ContentDB.enemy(BREED)
	if _field == null or _hero == null or _hero.arsenal == null or breed == null:
		_check(false, "the harness needs a battlefield, a Warden with an Arsenal and a breed")
		return
	var arsenal: Arsenal = _hero.arsenal
	await _clear_the_field()
	var where: Vector2 = _stand_for(ContentDB.arsenal_weapon("chain_spark"), [])
	_hold(["chain_spark", "frost_shards", "stone_rain"])
	arsenal.process_mode = Node.PROCESS_MODE_DISABLED
	var spark: Arsenal.Armed = arsenal._armed.get("chain_spark", null) as Arsenal.Armed
	var shards: Arsenal.Armed = arsenal._armed.get("frost_shards", null) as Arsenal.Armed
	var stone: Arsenal.Armed = arsenal._armed.get("stone_rain", null) as Arsenal.Armed
	_check(spark != null and shards != null and stone != null, "the Arsenal did not arm the three")
	if spark == null or shards == null or stone == null:
		arsenal.process_mode = Node.PROCESS_MODE_INHERIT
		return
	var bodies: Array[Enemy] = _crowd(breed, where + Vector2(0.0, 600.0), 4, 200.0, 400.0)
	var dry: Enemy = bodies[0]
	var wet: Enemy = bodies[1]
	wet.apply_wet(Balance.WET_SECONDS)
	_check(wet.is_wet() and not dry.is_wet(), "the harness could not soak one body and keep one dry")

	# A storm weapon on a soaked body: the shock the storm towers already deal.
	var taken_dry: float = _blow(arsenal, spark, dry)
	var taken_wet: float = _blow(arsenal, spark, wet)
	_check(taken_dry > 0.0 and absf(taken_wet / taken_dry - Balance.WET_SHOCK_DAMAGE) < 0.02,
		"an air weapon took %.1f off a wet body and %.1f off a dry one, not %.2fx"
			% [taken_wet, taken_dry, Balance.WET_SHOCK_DAMAGE])
	# An earth weapon does not conduct.
	var stone_dry: float = _blow(arsenal, stone, dry)
	var stone_wet: float = _blow(arsenal, stone, wet)
	_check(stone_dry > 0.0 and absf(stone_wet / stone_dry - 1.0) < 0.02,
		"an earth weapon hit a wet body %.2fx as hard as a dry one - only a storm conducts"
			% (stone_wet / maxf(stone_dry, 0.001)))
	# A water weapon soaks what it hits, and an earth one does not.
	var fresh: Enemy = bodies[2]
	_blow(arsenal, stone, fresh)
	_check(not fresh.is_wet(), "an earth weapon soaked the body it hit")
	_blow(arsenal, shards, fresh)
	_check(fresh.is_wet(), "a water weapon did not leave the body it hit wet")

	# A chain leaving a wet body leaps `WET_CHAIN_RANGE` further: a second body
	# past the dry leap and inside the wet one is reached only when the first is
	# soaked.
	await _clear_the_field()
	var first: Enemy = _crowd(breed, where + Vector2(100.0, 0.0), 1, 0.0, 400.0)[0]
	var gap: float = Balance.ARSENAL_CHAIN_LEAP * (1.0 + Balance.WET_CHAIN_RANGE) * 0.5
	var second: Enemy = _crowd(breed, first.global_position + Vector2(gap, 0.0), 1, 0.0, 400.0)[0]
	var before: float = second.health.current_hp
	arsenal._fire_chain(spark)
	_check(is_equal_approx(second.health.current_hp, before),
		"a chain from a dry body leapt %.0f, past its reach of %.0f" % [gap, Balance.ARSENAL_CHAIN_LEAP])
	first.apply_wet(Balance.WET_SECONDS)
	arsenal._fire_chain(spark)
	_check(second.health.current_hp < before,
		"a chain leaving a wet body did not leap %.0f, inside %.0f"
			% [gap, Balance.ARSENAL_CHAIN_LEAP * Balance.WET_CHAIN_RANGE])

	arsenal.process_mode = Node.PROCESS_MODE_INHERIT
	await _clear_the_field()
	_hold([])
	_reached["reacts"] = true


## What one blow from a weapon took off a body.
func _blow(arsenal: Arsenal, armed: Arsenal.Armed, body: Enemy) -> float:
	var before: float = body.health.current_hp
	arsenal.strike_body(armed, body, 20.0, body.global_position + Vector2(-40.0, 0.0), 0.0)
	return before - body.health.current_hp


func _focus_share() -> float:
	var focus: int = WardenSheet.attribute_of(null, RunState.Attribute.FOCUS)
	return minf(float(focus) * Balance.HERO_FOCUS_COOLDOWN_PER_POINT, Balance.HERO_FOCUS_COOLDOWN_CAP)


# --- Every weapon lands ---------------------------------------------------------


func _test_every_weapon_lands() -> void:
	var breed: EnemyData = ContentDB.enemy(BREED)
	if _field == null or _hero == null or breed == null:
		_check(false, "the harness needs a battlefield, a Warden and a breed")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	# **The ground does not heal the crowd while it is measured.** Act I's
	# jungle mends every body a little a second, which reads as a weapon that
	# named more than the crowd lost.
	var ground: TerrainData = ContentDB.terrain(RunState.terrain_id)
	var mends: float = ground.enemy_hp_regen if ground != null else 0.0
	if ground != null:
		ground.enemy_hp_regen = 0.0
	var towers: Array[Tower] = await _two_towers()
	for id: String in _weapon_cards():
		var card: RoadCardData = ContentDB.road_card(id)
		var weapon: ArsenalWeaponData = card.weapon_data()
		if weapon == null or weapon.is_defensive():
			continue
		await _clear_the_field()
		var arsenal: Arsenal = _hero.arsenal if weapon.anchor == ArsenalWeaponData.Anchor.WARDEN \
			else _field.board_arsenal()
		_check(arsenal != null, "%s: no Arsenal stands where it fires" % id)
		if arsenal == null:
			continue
		var where: Vector2 = _stand_for(weapon, towers)
		var killers: bool = weapon.pattern == ArsenalWeaponData.Pattern.ON_KILL \
			or weapon.every_kills > 0
		var crowd: Array[Enemy] = _crowd(breed, where, CROWD_BODIES, CROWD_RADIUS, 400.0)
		_hold([id])
		arsenal.dealt.clear()
		arsenal.hits.clear()
		RunState.damage_ledger.clear()
		await get_tree().process_frame
		_check(arsenal.armed_cards().has(id), "%s: the Arsenal did not arm it" % id)
		var before: float = _pool(crowd)
		var elapsed: float = 0.0
		var started: int = Time.get_ticks_msec()
		if killers:
			# A kill-weapon needs deaths: bodies with nothing in them, felled by
			# the harness through the ordinary door.
			var fodder: Array[Enemy] = _crowd(breed, where, weapon.every_kills + 4, 60.0, 0.01)
			for body: Enemy in fodder:
				DamageLedger.credit_as(DamageLedger.OTHER)
				body.take_damage(100000.0, where, 0.0)
				await get_tree().process_frame
		# At least five of the weapon's own cadences: a stone every three seconds
		# measured over eight is two or three stones, and a coin toss.
		var window: float = maxf(MEASURE_SECONDS, weapon.cooldown * 5.0)
		while elapsed < window:
			await get_tree().process_frame
			elapsed = float(Time.get_ticks_msec() - started) / 1000.0
			if weapon.pattern == ArsenalWeaponData.Pattern.TRAIL:
				# A trail is laid by walking, so the Warden walks a ring through
				# the crowd at a walker's pace.
				_hero.global_position = where + Vector2.from_angle(
					elapsed * Balance.HERO_MOVE_SPEED / WALK_RING) * WALK_RING
			_check(arsenal.records() <= Balance.ARSENAL_RECORDS_MAX,
				"%s: %d records in the air, past the budget" % [id, arsenal.records()])
		var dealt: float = float(arsenal.dealt.get(id, 0.0))
		var taken: float = before - _pool(crowd)
		_check(dealt > 0.0, "%s: fired at a crowd for %.0f seconds and dealt nothing" % [id, elapsed])
		# **Every point the crowd lost is named** - by this card, its burn, or a
		# tower beside it. A loss nobody named is a blow that went round the door.
		# (What a weapon says it dealt is the blow before the body's own
		# resistances, so it is not the figure to hold the crowd against.)
		var named: float = 0.0
		for source: Variant in RunState.damage_ledger:
			named += float(RunState.damage_ledger[source])
		if not killers:
			_check(absf(taken - named) <= taken * 0.1 + 2.0,
				"%s: the crowd lost %.0f and the ledger names %.0f - a blow went round the door" % [id, taken, named])
		_check(float(RunState.damage_ledger.get(DamageLedger.AUGMENT_PREFIX + id, 0.0)) > 0.0,
			"%s: the ledger does not name it" % id)
		if not killers:
			var anchors: float = float(towers.size()) if weapon.anchor == ArsenalWeaponData.Anchor.TOWERS \
				and weapon.pattern != ArsenalWeaponData.Pattern.ARC else 1.0
			var model: float = weapon.modelled_dps(1) / (1.0 + weapon.burn_share) \
				* Balance.arsenal_act_scale(RunState.act) * arsenal.owner_multiplier() * anchors
			var ratio: float = (dealt / maxf(elapsed, 0.01)) / maxf(model, 0.01)
			_ratios.append("%s %.2f" % [id, ratio])
			_check(ratio >= MODEL_LOW and ratio <= MODEL_HIGH,
				("%s dealt %.1f a second against a model of %.1f (%.2fx) - the curve is "
					+ "measuring a weapon the fight does not have") % [id, dealt / maxf(elapsed, 0.01), model, ratio])
	await _clear_the_field()
	_hold([])
	if ground != null:
		ground.enemy_hp_regen = mends
	_reached["lands"] = true


## Where a weapon's crowd stands: at the Warden's side, on a tower, or at the wall.
func _stand_for(weapon: ArsenalWeaponData, towers: Array[Tower]) -> Vector2:
	match weapon.anchor:
		ArsenalWeaponData.Anchor.TOWERS:
			# A weapon on the board arms the towers near a Warden, so the Warden
			# stands among them.
			if not towers.is_empty():
				_hero.global_position = towers[0].global_position + Vector2(0.0, 120.0)
			if towers.size() >= 2 and weapon.pattern == ArsenalWeaponData.Pattern.ARC:
				return towers[0].global_position.lerp(towers[1].global_position, 0.5)
			return towers[0].global_position + Vector2(40.0, 30.0) if not towers.is_empty() \
				else _field.town_position()
		ArsenalWeaponData.Anchor.TOWN:
			return _field.town_position() + Vector2(400.0, 0.0)
	var at: Vector2 = _field.town_position() + Vector2(900.0, 200.0)
	_hero.global_position = at
	_hero.velocity = Vector2.ZERO
	return at




## **The standard crowd**: bodies that do not walk, spread evenly over a disc -
## a golden-angle spiral, so no ring of them happens to sit on an orbit. The
## crowd a weapon's `crowd` factor is calibrated against, and so the crowd the
## curve's model means.
func _crowd(breed: EnemyData, at: Vector2, count: int, spread: float, hp_scale: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for index: int in count:
		var body: Enemy = _field.spawn_enemy(breed, 0, hp_scale, 0.0, 0.001)
		if body == null:
			continue
		var ring: float = spread * sqrt((float(index) + 0.5) / float(count))
		body.global_position = at + Vector2.from_angle(float(index) * 2.39996) * ring
		out.append(body)
	return out


func _pool(crowd: Array[Enemy]) -> float:
	var total: float = 0.0
	for body: Enemy in crowd:
		if is_instance_valid(body) and body.health != null:
			total += maxf(body.health.current_hp, 0.0)
	return total


func _clear_the_field() -> void:
	for body: Enemy in _field.living_bodies():
		if is_instance_valid(body):
			body.queue_free()
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()
	for _frame: int in 3:
		await get_tree().process_frame


## Two towers near each other, for the weapons that stand on the board.
func _two_towers() -> Array[Tower]:
	var out: Array[Tower] = []
	var data: TowerData = ContentDB.tower("ember_spire")
	RunState.set_phase(RunState.Phase.PREPARATION)
	var first: Vector2i = _field.free_anchor_near(0, 8)
	if _field.try_build(first, data).is_empty():
		pass
	for step: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
			Vector2i(3, 0), Vector2i(0, 3), Vector2i(3, 3), Vector2i(-3, 0)]:
		if _field.try_build(first + step, data).is_empty():
			break
	await get_tree().process_frame
	for tower: Tower in _field.all_towers():
		out.append(tower)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	_check(out.size() >= 2, "the harness stood %d towers, and the board's weapons want two" % out.size())
	if out.size() >= 2:
		_check(out[0].global_position.distance_to(out[1].global_position) <= Balance.ARSENAL_ARC_SPAN,
			"the harness's two towers stand too far apart for an arc")
	return out


# --- The defence (docs/ARSENAL_DEFENSIVE_2026-09-28.md §5) ----------------------


## Each of the five patterns through its real door on the real field: a ward
## worth its share and no more, a mend of what is missing and nothing on a
## whole pool, a retort that answers a blow and never fires alone, a guard that
## swallows a shot and reforms, a field that slows what stands in it.
func _test_the_defence() -> void:
	var breed: EnemyData = ContentDB.enemy(BREED)
	if _field == null or _hero == null or breed == null or _hero.arsenal == null:
		_check(false, "the harness needs a battlefield, a Warden and a breed")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	var arsenal: Arsenal = _hero.arsenal
	var health: Health = _hero.health
	var home: Vector2 = _field.town_position() + Vector2(900.0, 200.0)
	await _clear_the_field()
	_hero.global_position = home
	_hero.velocity = Vector2.ZERO

	# WARD: fires on its cadence, worth its share of the pool, and the ceiling
	# holds whatever the data authors.
	var ward: ArsenalWeaponData = ContentDB.arsenal_weapon("lantern_ward")
	_hold(["lantern_ward"])
	# The pool has no door that takes a ward away, so the harness clears it.
	health.set("_shield", 0.0)
	health.current_hp = health.max_hp
	# **One firing, pinned.** A new card's clock starts part-way through its
	# cadence on the Arsenal's own dice, so a wait of a cadence and a half held
	# one firing on some runs and two on others - the mend read 9 against 5.
	_pin_clock(arsenal, "lantern_ward")
	await _wait_seconds(1.0)
	var expected: float = health.max_hp * ward.share_at(1) * health.shield_scale
	_check(health.shield() > 0.0 and absf(health.shield() - expected) <= expected * 0.15 + 1.0,
		"Lantern Ward must ward %.0f (%.0f%% of the pool); it warded %.0f" % [expected, ward.share_at(1) * 100.0, health.shield()])
	var armed: Arsenal.Armed = arsenal.get("_armed")["lantern_ward"]
	var greedy: ArsenalWeaponData = ward.duplicate() as ArsenalWeaponData
	greedy.share = 5.0
	var kept_weapon: ArsenalWeaponData = armed.weapon
	armed.weapon = greedy
	_check(arsenal.guard_share(armed, Balance.ARSENAL_WARD_CEILING) <= Balance.ARSENAL_WARD_CEILING + 0.0001,
		"a ward authored at five times the pool must be held to the ceiling")
	armed.weapon = kept_weapon
	_hold(["lantern_ward", "steadfast_salt"])
	var salted: float = arsenal.guard_share(arsenal.get("_armed")["lantern_ward"], Balance.ARSENAL_WARD_CEILING)
	_check(salted > ward.share_at(1), "Steadfast Salt must make a ward worth more")

	# MEND: a share of what is missing, and nothing on a whole pool.
	var mend: ArsenalWeaponData = ContentDB.arsenal_weapon("marrow_mend")
	_hold(["marrow_mend"])
	health.current_hp = health.max_hp
	_pin_clock(arsenal, "marrow_mend")
	await _wait_seconds(1.0)
	_check(is_equal_approx(health.current_hp, health.max_hp), "a whole Warden was mended by something")
	health.current_hp = health.max_hp * 0.4
	var missing: float = health.max_hp - health.current_hp
	_pin_clock(arsenal, "marrow_mend")
	await _wait_seconds(1.0)
	var rose: float = health.current_hp - health.max_hp * 0.4
	var mend_expected: float = missing * mend.share_at(1) * health.heal_scale
	_check(rose > 0.0 and absf(rose - mend_expected) <= mend_expected * 0.15 + 1.0,
		"Marrow Mend must heal %.0f (%.0f%% of %.0f missing); it healed %.0f" % [mend_expected, mend.share_at(1) * 100.0, missing, rose])
	health.current_hp = health.max_hp

	# RETORT: nothing while the Warden is left alone; a burst on a blow, named in
	# the ledger; and not a second burst inside the refractory.
	var thorns: ArsenalWeaponData = ContentDB.arsenal_weapon("thornskin")
	_hold(["thornskin"])
	# The ward the first test left would swallow the blow whole, and a blow that
	# takes nothing announces nothing.
	health.set("_shield", 0.0)
	var crowd: Array[Enemy] = _crowd(breed, home, 6, 60.0, 400.0)
	arsenal.dealt.clear()
	RunState.damage_ledger.clear()
	await _wait_seconds(thorns.cooldown + 1.0)
	_check(float(arsenal.dealt.get("thornskin", 0.0)) == 0.0,
		"Thornskin fired at a crowd that had not struck the Warden")
	DamageLedger.credit_as(DamageLedger.OTHER)
	health.take_damage(3.0, home + Vector2.LEFT * 40.0)
	await get_tree().process_frame
	var first: float = float(arsenal.dealt.get("thornskin", 0.0))
	_check(first > 0.0, "a blow on the Warden did not set Thornskin off")
	_check(float(RunState.damage_ledger.get(DamageLedger.AUGMENT_PREFIX + "thornskin", 0.0)) > 0.0,
		"the ledger does not name Thornskin")
	health.take_damage(3.0, home + Vector2.LEFT * 40.0)
	await get_tree().process_frame
	_check(is_equal_approx(float(arsenal.dealt.get("thornskin", 0.0)), first),
		"Thornskin burst twice inside its refractory")
	health.current_hp = health.max_hp
	await _clear_the_field()

	# GUARD: swallows a shot in reach, spends a stone, refuses when spent, reforms.
	var stones: ArsenalWeaponData = ContentDB.arsenal_weapon("guardian_stones")
	_hold(["guardian_stones"])
	await _wait_seconds(0.3)
	var near: Vector2 = home + Vector2(stones.radius, 0.0)
	_check(not arsenal.absorb(home + Vector2(900.0, 0.0)), "a shot far from the Warden was swallowed")
	var swallowed: int = 0
	for _shot: int in stones.count + 2:
		if _field.absorb_hostile_shot(near):
			swallowed += 1
	_check(swallowed == stones.count, "Guardian Stones swallowed %d shots against %d stones" % [swallowed, stones.count])
	await _wait_seconds(stones.cooldown + 0.5)
	_check(arsenal.absorb(near), "a stone did not reform on its cadence")

	# FIELD: a body inside is slowed, one outside is not, and nothing moved.
	# **Within three ticks of the hold**, which is the invariant the v0.61.0
	# tag failed on: a field started part of the way through its *cooldown*
	# like a clocked weapon, on dice seeded from the Arsenal's instance id, so
	# whether the first bite landed inside this wait depended on how many
	# objects a loaded save had allocated. A field stands the moment it is
	# held now, and the dice are the run's - the source walk below holds both.
	var field: ArsenalWeaponData = ContentDB.arsenal_weapon("frostbound_ring")
	_hold(["frostbound_ring"])
	var inside: Enemy = _crowd(breed, home + Vector2(field.radius * 0.5, 0.0), 1, 0.0, 400.0)[0]
	var outside: Enemy = _crowd(breed, home + Vector2(field.radius * 2.5, 0.0), 1, 0.0, 400.0)[0]
	var inside_at: Vector2 = inside.global_position
	await _wait_seconds(Balance.ARSENAL_FIELD_TICK * 3.0)
	_check(inside.targeting_speed() < outside.targeting_speed(),
		"a body in Frostbound Ring walks at %.0f and one outside at %.0f" % [inside.targeting_speed(), outside.targeting_speed()])
	_check(inside.is_wet(), "a body in a water field must be soaked")
	_check(inside.global_position.distance_to(inside_at) < 2.0, "the field moved a body")
	await _clear_the_field()
	_hold([])
	_reached["defence"] = true


## Sets an armed card's clock so it fires once, soon, and not again inside
## the harness's wait.
func _pin_clock(arsenal: Arsenal, card_id: String) -> void:
	var armed: Arsenal.Armed = arsenal.get("_armed").get(card_id, null) as Arsenal.Armed
	if armed != null:
		armed.clock = 0.3


## The Arsenal's dice are the run's, never an allocation count.
func _test_the_dice_are_the_runs() -> void:
	var code: String = FileAccess.get_file_as_string("res://scripts/systems/arsenal.gd")
	for line: String in code.split("
"):
		if line.contains("seed") and line.contains("get_instance_id"):
			_check(false, "the Arsenal seeds its dice from its instance id, which is a count of what was allocated before it: %s" % line.strip_edges())
			return
	_check(code.contains("RunState.run_seed"), "the Arsenal's dice are not seeded from the run")


func _wait_seconds(seconds: float) -> void:
	var started: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < seconds:
		await get_tree().process_frame


# --- A chain reaction ends ------------------------------------------------------


func _test_a_chain_reaction_ends() -> void:
	var breed: EnemyData = ContentDB.enemy(BREED)
	if _field == null or _hero == null or breed == null:
		return
	await _clear_the_field()
	# A tower's kill is a natural kill and rightly sets the card loose; this
	# test is about the payload's own, so nothing else may kill.
	for anchor: Variant in RunState.towers.keys():
		RunState.clear_tower(anchor as Vector2i)
	await get_tree().process_frame
	var where: Vector2 = _stand_for(ContentDB.arsenal_weapon("marrow_seekers"), [])
	_hold(["marrow_seekers"], 5)
	var arsenal: Arsenal = _hero.arsenal
	arsenal.kill_triggers.clear()
	await get_tree().process_frame
	# Bodies the seekers kill in one blow, so every payload can itself kill.
	var fodder: Array[Enemy] = _crowd(breed, where, 16, CROWD_RADIUS, 0.01)
	DamageLedger.credit_as(DamageLedger.OTHER)
	fodder[0].take_damage(100000.0, where, 0.0)
	await _seconds(3.0)
	var fallen: int = 0
	for body: Enemy in fodder:
		if not is_instance_valid(body) or body.is_dying():
			fallen += 1
	_check(fallen > 1, "one death set nothing loose: %d fell" % fallen)
	_check(int(arsenal.kill_triggers.get("marrow_seekers", 0)) == 1,
		("one death released %d volleys - the seekers' own kills fired the card again, "
			+ "which is a chain reaction with no end") % int(arsenal.kill_triggers.get("marrow_seekers", 0)))
	# And many deaths at once: a second's worth, never more.
	await _clear_the_field()
	arsenal.kill_triggers.clear()
	var many: Array[Enemy] = _crowd(breed, where, 24, 160.0, 0.01)
	for body: Enemy in many:
		DamageLedger.credit_as(DamageLedger.OTHER)
		body.take_damage(100000.0, where, 0.0)
	_check(int(arsenal.kill_triggers.get("marrow_seekers", 0)) <= Balance.ARSENAL_KILL_TRIGGERS_PER_SECOND,
		"twenty-four deaths in a moment released %d volleys, past %d a second"
			% [int(arsenal.kill_triggers.get("marrow_seekers", 0)), Balance.ARSENAL_KILL_TRIGGERS_PER_SECOND])
	await _clear_the_field()
	_hold([])
	_reached["ends"] = true


# --- Freezes --------------------------------------------------------------------


func _test_it_freezes_with_the_field() -> void:
	var breed: EnemyData = ContentDB.enemy(BREED)
	if _field == null or _hero == null or breed == null:
		return
	await _clear_the_field()
	var where: Vector2 = _stand_for(ContentDB.arsenal_weapon("seeking_flames"), [])
	# Far enough that a bolt is still in the air when the field stops.
	_crowd(breed, where + Vector2(420.0, 0.0), 6, 40.0, 400.0)
	_hold(["seeking_flames"], 5)
	var arsenal: Arsenal = _hero.arsenal
	var waited: float = 0.0
	while arsenal.records() == 0 and waited < 6.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(arsenal.records() > 0, "no bolt was ever in the air to freeze")
	if arsenal.records() > 0:
		_field.suspend()
		var at: Vector2 = arsenal._records[0]["at"] as Vector2
		await _seconds(0.5)
		_check(arsenal.records() > 0 and (arsenal._records[0]["at"] as Vector2).is_equal_approx(at),
			"a bolt kept flying while the field was frozen for a raid")
		_field.resume()
	await _clear_the_field()
	_hold([])
	_reached["freezes"] = true


func _seconds(span: float) -> void:
	var until: int = Time.get_ticks_msec() + int(span * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
