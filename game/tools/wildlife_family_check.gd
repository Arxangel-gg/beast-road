extends Node

## Families, births and the Wildblight, measured on the real field.
##
## The owner's brief of 2026-09-14 asks for evidence rather than claims, and
## names what the evidence has to be: the advertised inheritance odds and
## their limits, one animal's rarity never moving another's, no reroll on a
## reconnect, growth and courtship and illness suspended with the road, a
## frenzy that works on species that never fought, bounded population and
## transmission, and reward attribution that cannot be farmed. Each of those
## is a test below, and the probabilities are *measured over many rolls*
## rather than read back out of the table they came from.

const SEED: int = 20260914
## Enough rolls that a 2% arm is measured rather than sampled.
const ROLLS: int = 40000

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _animals: Wildlife = null
var _families: WildlifeFamilies = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	_animals = _field.wildlife() if _field != null else null
	_families = _animals.families() if _animals != null else null
	_check(_field != null and _animals != null and _families != null,
		"the field, its wildlife and its families")
	if _field == null or _animals == null or _families == null:
		_finish()
		return
	_field.sky().events_enabled = false
	if _field.wave_director != null:
		_field.wave_director.stop()
	# The road's bodies, not the camps': a camp whose bodies vanish is a camp
	# razed. **A grazing animal will not court while anything frightens it**,
	# which is the design and was this gate's first fault: the opening wave was
	# still walking, so a pair stood in FLEEING for three thousand frames and
	# the courtship never began.
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_camp_mob():
			enemy.queue_free()
	await get_tree().process_frame

	_test_the_species_are_authored_sensibly()
	_test_inheritance_keeps_its_advertised_odds()
	_test_a_rarity_belongs_to_the_animal_and_not_the_species()
	_test_shiny_birth_odds_and_their_ceiling()
	await _test_a_pair_courts_through_its_stages_and_bears()
	await _test_a_fright_interrupts_a_courtship()
	await _test_a_companion_may_court_and_may_be_refused()
	await _test_births_are_budgeted_and_counted()
	await _test_young_grow_and_are_worth_less()
	await _test_a_reconnect_rerolls_nothing()
	await _test_the_blight_runs_its_course_and_is_bounded()
	await _test_a_frenzy_works_on_a_species_that_never_fought()
	await _test_a_mercy_is_not_a_hunt()
	await _test_a_raid_suspends_all_of_it()
	_test_a_companion_keeps_its_sex()
	_finish()


func _finish() -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _run != null:
		_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[wildlife-family] PASS - %d checks: the odds, the pair, the litter, the growth, the blight, the bounds" % _checks)
	else:
		for failure: String in _failures:
			push_error("[wildlife-family] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(why)
	print("[wildlife-family] FAIL: %s" % why)


func _dice() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return rng


func _kind(id: String) -> WildlifeData:
	return ContentDB.wildlife_kind(id) if ContentDB.has_method("wildlife_kind") else _find(id)


func _find(id: String) -> WildlifeData:
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.id == id:
			return kind
	return null


## Somebody breeds, the groups are shared deliberately, and every litter and
## gestation is a real number. An authored family that cannot pair is a
## feature that silently never happens.
func _test_the_species_are_authored_sensibly() -> void:
	var breeders: int = 0
	var groups: Dictionary = {}
	for kind: WildlifeData in ContentDB.wildlife():
		if not kind.breeds:
			continue
		breeders += 1
		var group: String = kind.breeding_group_id()
		groups[group] = int(groups.get(group, 0)) + 1
		_check(kind.litter_min >= 1 and kind.litter_max >= kind.litter_min,
			"%s: a litter of %d..%d" % [kind.id, kind.litter_min, kind.litter_max])
		_check(kind.gestation_seconds > 0.0, "%s: a gestation" % kind.id)
		_check(kind.loyalty >= 0.0 and kind.loyalty <= 1.0
			and kind.infidelity >= 0.0 and kind.infidelity <= 1.0,
			"%s: loyalty and infidelity are shares" % kind.id)
		if not kind.young_id.is_empty():
			var path: String = GameData.derive_path("wildlife", "wildlife_", kind.young_id)
			_check(ResourceLoader.exists(path),
				"%s names young art that is not on disk (%s)" % [kind.id, path])
	_check(breeders >= 6, "at least a few species raise families (%d)" % breeders)
	# The brief's own example: a Deer and a Pale Stag are one breeding group.
	var deer: WildlifeData = _find("deer")
	var stag: WildlifeData = _find("stag")
	_check(deer != null and stag != null
		and deer.breeding_group_id() == stag.breeding_group_id(),
		"the deer and the pale stag must share a breeding group")
	# And a group of one can never pair, which is a family nobody ever sees.
	for group: Variant in groups:
		_check(int(groups[group]) >= 1, "breeding group %s" % String(group))


## The rarity tables, measured. Equal parents climb rarely and Legendary
## never climbs; unequal parents give the lower most of the time and one
## above it sometimes, and **never two rungs, ever**.
func _test_inheritance_keeps_its_advertised_odds() -> void:
	var rng: RandomNumberGenerator = _dice()
	for tier: int in 4:
		var climbed: int = 0
		for _roll: int in ROLLS:
			var born: int = WildlifeFamilies.inherit_rarity(tier, tier, rng)
			_check_once(born == tier or born == tier + 1,
				"equal %d parents must bear %d or %d, never %d" % [tier, tier, tier + 1, born])
			if born > tier:
				climbed += 1
		var seen: float = float(climbed) / float(ROLLS)
		var wanted: float = Balance.WILDLIFE_RARITY_CLIMB[tier]
		_check(absf(seen - wanted) <= maxf(wanted * 0.25, 0.004),
			"equal %d parents climb %.3f, advertised %.3f" % [tier, seen, wanted])
	# Legendary is the ceiling: two of them bear one, always.
	var top: int = WildlifeData.Rarity.LEGENDARY
	for _roll: int in 500:
		_check_once(WildlifeFamilies.inherit_rarity(top, top, rng) == top,
			"two legendaries bear a legendary and nothing above it")
	# Mixed: the lower rarity, or one above the lower - the brief's own
	# Common + Legendary case, which must never bear a Legendary.
	var above: int = 0
	for _roll: int in ROLLS:
		var born: int = WildlifeFamilies.inherit_rarity(WildlifeData.Rarity.COMMON, top, rng)
		_check_once(born <= WildlifeData.Rarity.UNCOMMON,
			"a common and a legendary bear a common or an uncommon, never %d" % born)
		if born > WildlifeData.Rarity.COMMON:
			above += 1
	var mixed: float = float(above) / float(ROLLS)
	_check(absf(mixed - Balance.WILDLIFE_MIXED_CLIMB) <= 0.03,
		"mixed parents give the higher rung %.3f of the time, advertised %.3f"
		% [mixed, Balance.WILDLIFE_MIXED_CLIMB])


## Said once however many rolls trip it, so a failing table is one line
## rather than forty thousand.
var _said: Dictionary = {}


func _check_once(condition: bool, why: String) -> void:
	if condition or _said.has(why):
		if not _said.has(why):
			_checks += 1
			_said[why] = true
		return
	_said[why] = true
	_check(false, why)


## **The rarity is the animal's, not the resource's.** Writing an upgrade onto
## the shared `WildlifeData` would make every animal of that species rarer for
## the rest of the run - which is the trap the brief names by name.
func _test_a_rarity_belongs_to_the_animal_and_not_the_species() -> void:
	var kind: WildlifeData = _find("deer")
	if kind == null:
		_check(false, "the harness needs a deer")
		return
	var was: int = int(kind.rarity)
	var plain: Dictionary = {"data": kind}
	var rare: Dictionary = {"data": kind, "rarity": WildlifeData.Rarity.LEGENDARY}
	_check(WildlifeFamilies.rarity_of(rare) == WildlifeData.Rarity.LEGENDARY,
		"an animal born rare reads as rare")
	_check(WildlifeFamilies.rarity_of(plain) == was,
		"and its sibling is still the species' own rarity (%d)" % WildlifeFamilies.rarity_of(plain))
	_check(int(kind.rarity) == was,
		"and the shared resource is untouched (%d, was %d)" % [int(kind.rarity), was])


## A shiny birth: the variant's own chance lifted by the parents that shone,
## never past the ceiling, and two plain parents can still bear one.
func _test_shiny_birth_odds_and_their_ceiling() -> void:
	for tier: int in 4:
		var none: float = WildlifeFamilies.shiny_birth_chance(tier, false, false)
		var one: float = WildlifeFamilies.shiny_birth_chance(tier, true, false)
		var both: float = WildlifeFamilies.shiny_birth_chance(tier, true, true)
		_check(none > 0.0, "two plain parents can still bear a shiny at tier %d" % tier)
		_check(one > none and both > one,
			"a shining parent helps, and two help more (%.3f < %.3f < %.3f)" % [none, one, both])
		_check(both <= Balance.WILDLIFE_SHINY_BIRTH_CAP + 0.0001,
			"tier %d: two shining parents reach %.3f, past the %.3f ceiling"
			% [tier, both, Balance.WILDLIFE_SHINY_BIRTH_CAP])
		_check(is_equal_approx(none, Balance.SPIRIT_SHINY_CHANCE[tier]),
			"an unshining pair bears at the variant's own rate")
	# Measured: two plain Commons still bear the occasional shiny.
	var rng: RandomNumberGenerator = _dice()
	var shone: int = 0
	for _roll: int in ROLLS:
		if WildlifeFamilies.inherit_shiny(WildlifeData.Rarity.COMMON, false, false, rng):
			shone += 1
	var rate: float = float(shone) / float(ROLLS)
	_check(absf(rate - Balance.SPIRIT_SHINY_CHANCE[0]) <= 0.005,
		"measured shiny births from two plain commons: %.3f against %.3f"
		% [rate, Balance.SPIRIT_SHINY_CHANCE[0]])


## Two adults, near, healthy and idle: they pair, close, appraise, mate and
## bear. Driven by the real tick rather than by calling the birth.
## **A companion courts, and every clause the owner named is a refusal**
## (2026-09-22: *"companions may court a wild animal or be courted by one only
## if they're the same species and proper opposite genders, and the player's
## companion is not actively targeting anything or busy with anything, it
## would then still need to be interested"*).
##
## Driven on the real field through the real machine. The interesting half is
## the four refusals rather than the one success: a courtship that happened
## whatever was standing there would be the feature working by accident.
func _test_a_companion_may_court_and_may_be_refused() -> void:
	var deer: WildlifeData = ContentDB.wildlife_kinds.get("deer", null) as WildlifeData
	if deer == null or not deer.breeds:
		_check(false, "the gate needs a breeding species to court with")
		return

	# A companion of that species, female, so the wild half seeks and the
	# whole conversation is driven from the animal's side.
	var key: String = SpiritBond.key(deer.id, 0, false)
	RunState.companion_sex[key] = WildlifeFamilies.Sex.FEMALE
	var spirit: Companion = await _stand_a_companion(deer, key)
	if spirit == null:
		return

	# **Never in the population.** This is the bound the whole design rests
	# on: the record is offered to the search and to nothing else.
	var counted: int = _animals.population()
	for _frame: int in 3:
		await get_tree().process_frame
	_check(_animals.population() == counted,
		"a companion is not wildlife: the population moved from %d to %d"
			% [counted, _animals.population()])
	for animal: Dictionary in _animals.living():
		_check(int(animal.get("net_id", 0)) != WildlifeFamilies.COMPANION_ID,
			"the companion's record must never be in living()")

	# 1. THE WRONG SPECIES. A wolf standing on top of it courts nothing.
	var wolf: WildlifeData = ContentDB.wildlife_kinds.get("wolf", null) as WildlifeData
	if wolf != null and wolf.breeds:
		var stranger: Dictionary = _settle(_place(wolf, {"sex": WildlifeFamilies.Sex.MALE,
			"stage": WildlifeFamilies.Stage.ADULT},
			spirit.global_position + Vector2(60.0, 0.0)))
		if not stranger.is_empty():
			var paired: bool = await _watch_for_pair(spirit, 240)
			_check(not paired, "a wolf must not court a deer")
			_animals.perish(stranger)
			await get_tree().process_frame

	# 2. THE SAME SEX. Its own species, and still nothing.
	var brother: Dictionary = _settle(_place(deer, {"sex": WildlifeFamilies.Sex.FEMALE,
		"stage": WildlifeFamilies.Stage.ADULT},
		spirit.global_position + Vector2(60.0, 0.0)))
	if not brother.is_empty():
		var paired: bool = await _watch_for_pair(spirit, 240)
		_check(not paired, "two females must not court")
		_animals.perish(brother)
		await get_tree().process_frame

	# 3. BUSY. The right animal, and a companion with something to answer.
	var mate: Dictionary = _settle(_place(deer, {"sex": WildlifeFamilies.Sex.MALE,
		"stage": WildlifeFamilies.Stage.ADULT},
		spirit.global_position + Vector2(60.0, 0.0)))
	if mate.is_empty():
		return
	spirit.courting_at = Vector2.INF
	var busy: Enemy = _stand_a_body_near(spirit.global_position)
	if busy != null:
		_check(not spirit.may_court(),
			"a companion with a body in front of it is busy")
		var paired: bool = await _watch_for_pair(spirit, 180)
		_check(not paired, "and a busy companion courts nothing")
		busy.queue_free()
		await _let_the_swing_finish(spirit)

	# 4. AND THEN IT COURTS. Same species, opposite sexes, nothing to do.
	_check(spirit.may_court(), "with the road quiet it is free to be courted (%s)"
		% _why_it_will_not_court(spirit))
	var courted: bool = await _watch_for_pair(spirit, 3000)
	_check(courted, "a companion must court a wild animal of its own kind")
	if courted:
		# It walks to the meeting rather than standing at its owner's heel:
		# the destination is the whole of what the machine asks of the node.
		_check(spirit.courting_at != Vector2.INF,
			"and it is sent somewhere to meet")

	# 5. AND IT IS LET GO. Dismissed mid-courtship, the animal is freed too
	#    rather than left standing in APPROACHING for the rest of the run.
	var partner_id: int = int(_families.get("_mate_record").get("partner", 0))
	spirit.queue_free()
	for _frame: int in 6:
		await get_tree().process_frame
	var abandoned: Dictionary = _animals.animal_by_id(partner_id)
	if not abandoned.is_empty():
		_check(int(abandoned.get("court", 0)) == WildlifeFamilies.Court.NONE,
			"a dismissed companion lets its partner go, left at %d"
				% int(abandoned.get("court", 0)))


## Settles a placed animal so it is eligible to court: born before this act,
## off its cooldown, standing still with no clock running it off the field.
## Exactly what `_stand_a_pair` does to its two, and for the same reason - an
## animal spawned this frame carries `born_act == RunState.act`, which
## `_can_court` refuses by design.
func _settle(animal: Dictionary) -> Dictionary:
	if animal.is_empty():
		return animal
	animal["state"] = Wildlife.State.SETTLED
	animal["goal"] = (animal["sprite"] as Sprite2D).global_position
	animal["patience"] = 9999.0
	animal["court_cooldown"] = 0.0
	animal["born_act"] = -1
	return animal


## A companion of a species, standing beside the hero on quiet ground.
func _stand_a_companion(kind: WildlifeData, key: String) -> Companion:
	var form: CompanionData = SpiritBond.companion_form(kind, key)
	if form == null:
		_check(false, "the gate needs a companion form for %s" % kind.id)
		return null
	var at: Vector2 = _quiet_ground(kind)
	_field.hero.global_position = at
	var spirit := Companion.new()
	spirit.spirit_key = key
	spirit.setup(form, _field.hero, _field)
	_field.add_child(spirit)
	spirit.global_position = at + Vector2(24.0, 0.0)
	# **The hero has to be holding it.** `Battlefield._process` is what tells
	# the ecology who is standing here, and it reads `hero.spirit` - a
	# companion added to the field and owned by nobody is a node the families
	# machine never hears about, which is how the first run of this test
	# reported the whole feature as broken.
	_field.hero.set("spirit", spirit)
	for _frame: int in 4:
		await get_tree().process_frame
	return spirit


## Waits out the swing the probe body provoked, in **seconds**.
##
## This was three frames, and three frames is nothing: headless runs far above
## sixty a second, so the companion was still 0.95s into the cooldown its own
## `attack_interval` authored when the next line asked whether it was free.
## That is the same fault `enemy_shot_check` paid for once - a wait counted in
## frames is a wait in whatever the machine felt like giving.
##
## The figure is the companion's own numbers rather than a typed constant, so a
## slower companion is waited out correctly without anybody editing this file.
func _let_the_swing_finish(spirit: Companion) -> void:
	var window: float = Balance.COMPANION_STRIKE_FRAMES_SECONDS
	if spirit != null and spirit.data != null:
		window += spirit.data.attack_interval
	await get_tree().create_timer(window + 0.25).timeout


## Why a companion is refusing to court, named rather than left to be guessed.
##
## `may_court` answers one bool over five conditions, so a gate that only ever
## printed "it is not free" sent the last session reading the state machine
## instead of the state. Every failure here should say which of the five.
func _why_it_will_not_court(spirit: Companion) -> String:
	if spirit == null:
		return "there is no companion"
	var said: Array[String] = []
	if not spirit.is_alive():
		said.append("it is down")
	if float(spirit.get("_recovering")) > 0.0:
		said.append("recovering for %.1fs" % float(spirit.get("_recovering")))
	if float(spirit.get("_striking_left")) > 0.0:
		said.append("mid-swing")
	if float(spirit.get("_cooldown")) > 0.0:
		said.append("swing cooldown %.2fs" % float(spirit.get("_cooldown")))
	if String(spirit.spirit_key).is_empty():
		said.append("no spirit key")
	return "free" if said.is_empty() else ", ".join(said)


## An ordinary body near enough to occupy a companion.
func _stand_a_body_near(at: Vector2) -> Enemy:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or breed.category != EnemyData.Category.BREED:
			continue
		var body: Enemy = _field.spawn_enemy(breed, 0, 9999.0, 1.0, 0.0, false)
		if body == null:
			continue
		body.global_position = at + Vector2(40.0, 0.0)
		return body
	return null


## Whether the companion's record pairs with anything inside `frames`.
func _watch_for_pair(spirit: Companion, frames: int) -> bool:
	for _frame: int in frames:
		await get_tree().process_frame
		if not is_instance_valid(spirit):
			return false
		var record: Dictionary = _families.get("_mate_record") as Dictionary
		if record.is_empty():
			continue
		if int(record.get("court", 0)) != WildlifeFamilies.Court.NONE:
			return true
	return false


func _test_a_pair_courts_through_its_stages_and_bears() -> void:
	var pair: Array[Dictionary] = await _stand_a_pair("deer")
	if pair.size() != 2:
		return
	var mother: Dictionary = pair[0]
	var before: int = _animals.population()
	var reached: Dictionary = {}
	var born: bool = false
	# **Off the birth, never off the population.** An ordinary arrival moves
	# the population too, and the first cut of this read one of those as a
	# birth - so it broke out of the loop mid-courtship and then read the
	# arrival as the cub.
	var litters: Array[int] = []
	var ear: Callable = func(_id: String, count: int, _at: Vector2) -> void:
		litters.append(count)
	EventBus.wildlife_born.connect(ear)
	for _frame: int in 6000:
		await get_tree().process_frame
		reached[int(mother.get("court", 0))] = true
		# Carrying: the clock is wound rather than waited out. A deer's
		# gestation is forty seconds of road, which is the design and is not
		# something a gate should sit through - what is being tested is that
		# the mating leads to a birth, not that a float counts down.
		if int(mother.get("court", 0)) == WildlifeFamilies.Court.OUTCOME 				and float(mother.get("gestation", 0.0)) > 0.1:
			mother["gestation"] = 0.05
		if not litters.is_empty():
			born = true
			break
	_check(reached.has(WildlifeFamilies.Court.APPROACHING), "a pair closes on each other")
	_check(reached.has(WildlifeFamilies.Court.ASSESSING), "and appraises")
	_check(reached.has(WildlifeFamilies.Court.MATING), "and mates")
	_check(reached.has(WildlifeFamilies.Court.OUTCOME) or born, "and carries")
	EventBus.wildlife_born.disconnect(ear)
	_check(born, "and bears young (population %d -> %d, litters %s)"
		% [before, _animals.population(), str(litters)])
	if not born:
		await _clear()
		return
	var cub: Dictionary = {}
	for animal: Dictionary in _animals.living():
		if (animal.get("parents", []) as Array).has(int(mother["net_id"])):
			cub = animal
	_check(not cub.is_empty(), "and the cub is on the field")
	if cub.is_empty():
		await _clear()
		return
	_check(not WildlifeFamilies.is_adult(cub), "what is born is young")
	_check(int(cub.get("born_act", -1)) == RunState.act, "and knows the act it was born in")
	_check((cub.get("parents", []) as Array).size() == 2, "and knows its parents")
	_check(float(mother.get("court_cooldown", 0.0)) > 0.0,
		"and the mother waits before pairing again")
	await _clear()


## Anything that frightens a courting animal ends the courtship.
func _test_a_fright_interrupts_a_courtship() -> void:
	var pair: Array[Dictionary] = await _stand_a_pair("deer")
	if pair.size() != 2:
		return
	var mother: Dictionary = pair[0]
	for _frame: int in 600:
		await get_tree().process_frame
		if int(mother.get("court", 0)) != WildlifeFamilies.Court.NONE:
			break
	_check(int(mother.get("court", 0)) != WildlifeFamilies.Court.NONE,
		"the pair must be courting before it can be interrupted")
	# The hero walks up: inside a deer's skittish radius is a fright.
	var sprite := mother["sprite"] as Sprite2D
	_field.hero.global_position = sprite.global_position + Vector2(20.0, 0.0)
	for _frame: int in 60:
		await get_tree().process_frame
	_check(int(mother.get("court", 0)) == WildlifeFamilies.Court.NONE
		or int(mother.get("court", 0)) == WildlifeFamilies.Court.COOLDOWN,
		"a fright ends the courtship (%d)" % int(mother.get("court", 0)))
	_field.hero.global_position = Vector2(700.0, 1800.0)
	await _clear()


## Births stop at the act's budget, and at the population cap before that.
func _test_births_are_budgeted_and_counted() -> void:
	await _clear()
	var kind: WildlifeData = _find("rabbit")
	if kind == null:
		_check(false, "the harness needs a rabbit")
		return
	_families.births_this_act = Balance.WILDLIFE_BIRTHS_PER_ACT
	var before: int = _animals.population()
	var cub: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.BABY})
	_check(not cub.is_empty(), "the budget is checked by the families, not by the spawner")
	# The budget is what `_give_birth` respects; drive it through a real pair.
	_families.births_this_act = Balance.WILDLIFE_BIRTHS_PER_ACT
	var pair: Array[Dictionary] = await _stand_a_pair("deer")
	if pair.size() == 2:
		var mother: Dictionary = pair[0]
		# Counted off the birth itself rather than off the population, which an
		# ordinary arrival also moves - the first cut read one of those as a
		# birth and failed a rule that was working.
		var litters: Array[int] = []
		var ear: Callable = func(_id: String, count: int, _at: Vector2) -> void:
			litters.append(count)
		EventBus.wildlife_born.connect(ear)
		for _frame: int in 2200:
			await get_tree().process_frame
			if not litters.is_empty():
				break
		EventBus.wildlife_born.disconnect(ear)
		_check(litters.is_empty(), "a spent birth budget bears nothing (%s)" % str(litters))
	_families.births_this_act = 0
	await _clear()
	_check(before <= _animals.population() + 8, "the harness tidied up after itself")


## A cub grows through its stages, and is worth less than its mother at each.
func _test_young_grow_and_are_worth_less() -> void:
	await _clear()
	var kind: WildlifeData = _find("deer")
	var cub: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.BABY, "rarity": int(kind.rarity), "sex": 0})
	if cub.is_empty():
		_check(false, "the harness needs a cub")
		return
	var sprite := cub["sprite"] as Sprite2D
	_check(int(cub["stage"]) == WildlifeFamilies.Stage.BABY, "born a baby")
	var small: float = sprite.scale.x
	_check(WildlifeFamilies.yield_scale(cub) < 1.0, "a baby is worth less than an adult")
	_check(WildlifeFamilies.speed_scale(cub) < 1.0, "and slower")
	_check(WildlifeFamilies.roam_scale(cub) < 1.0, "and stays nearer home")
	_check(float(cub.get("hp", 0.0)) < kind.max_hp, "and softer (%.0f of %.0f)"
		% [float(cub.get("hp", 0.0)), kind.max_hp])
	if not kind.young_id.is_empty():
		_check(bool(cub.get("young_frames", false)), "an antlered species' cub wears its own art")
	# Aged by hand through the real growth, which is what the clock does.
	cub["age"] = Balance.WILDLIFE_GROWTH_SECONDS * Balance.WILDLIFE_ADOLESCENT_AT + 0.1
	for _frame: int in 6:
		await get_tree().process_frame
	_check(int(cub["stage"]) == WildlifeFamilies.Stage.ADOLESCENT,
		"it grows to adolescent (%d)" % int(cub["stage"]))
	cub["age"] = Balance.WILDLIFE_GROWTH_SECONDS + 0.1
	for _frame: int in 6:
		await get_tree().process_frame
	_check(int(cub["stage"]) == WildlifeFamilies.Stage.ADULT, "and then grown")
	_check(sprite.scale.x > small, "and bigger than it was (%.2f -> %.2f)" % [small, sprite.scale.x])
	_check(is_equal_approx(WildlifeFamilies.yield_scale(cub), 1.0),
		"and worth what an adult is worth")
	_check(not bool(cub.get("young_frames", false)), "and wearing the adult's art")
	await _clear()


## Nothing here rerolls. The brief's reconnect case: the host's word is
## applied to an animal that already exists, and its sex, rarity and shine
## come back the same.
func _test_a_reconnect_rerolls_nothing() -> void:
	await _clear()
	var kind: WildlifeData = _find("deer")
	var born: Dictionary = {"sex": 1, "rarity": WildlifeData.Rarity.RARE, "shiny": true,
		"stage": WildlifeFamilies.Stage.BABY, "born_act": RunState.act, "parents": [7, 8], "family": 3}
	var cub: Dictionary = _place(kind, born)
	if cub.is_empty():
		_check(false, "the harness needs a cub")
		return
	var sex: int = int(cub["sex"])
	var rarity: int = WildlifeFamilies.rarity_of(cub)
	var shiny: bool = bool(cub["shiny"])
	_check(sex == 1 and rarity == WildlifeData.Rarity.RARE and shiny,
		"a cub is born with what its parents gave it")
	# The same word applied again, as a late fact would be.
	_families.decorate(cub, kind, born)
	_check(int(cub["sex"]) == sex, "a second telling does not reroll its sex")
	_check(WildlifeFamilies.rarity_of(cub) == rarity, "nor its rarity")
	_check(bool(cub["shiny"]) == shiny, "nor its shine")
	_check(int(cub["stage"]) == WildlifeFamilies.Stage.BABY, "nor its stage")
	# And one encounter per animal however often it is touched: the credit
	# flag is the existing anti-farm rule and a birth must not dodge it.
	cub["credited"] = true
	_families.decorate(cub, kind, born)
	_check(bool(cub.get("credited", false)), "and a credited cub stays credited")
	await _clear()


## Warning, frenzy, collapse, gone - and never more at once than the tier
## allows, never a second natural outbreak in one act.
func _test_the_blight_runs_its_course_and_is_bounded() -> void:
	await _clear()
	RunState.wave_number = Balance.WILDBLIGHT_OPENING_WAVES + 1
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var kind: WildlifeData = _find("rabbit")
	# One patch of ground for the whole outbreak, so nothing here is retired
	# for being too far from the hero while the test watches something else.
	var one: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.ADULT})
	if one.is_empty():
		_check(false, "the harness needs an animal")
		return
	var ground: Vector2 = (one["sprite"] as Sprite2D).global_position
	_check(not WildlifeFamilies.is_sick(one), "an animal arrives healthy")
	var sprite := one["sprite"] as Sprite2D
	_check(_families.call("_try_sicken", one, sprite, kind, true), "it can be taken")
	_check(int(one["blight"]) == WildlifeFamilies.Blight.WARNING, "the warning comes first")
	_check(sprite.get_node_or_null("Blight") != null, "and is drawn over its head")
	_check(_families.outbreaks_this_act == 1, "and the act's outbreak is spent")
	# A second natural outbreak this act is refused.
	var two: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.ADULT},
		ground + Vector2(70.0, 0.0))
	if not two.is_empty():
		_check(not _families.call("_try_sicken", two, two["sprite"], kind, true),
			"a second natural outbreak in one act is refused")
	# The warning runs out into the frenzy.
	one["blight_left"] = 0.01
	for _frame: int in 8:
		await get_tree().process_frame
	_check(int(one["blight"]) == WildlifeFamilies.Blight.FRENZIED, "the warning becomes a frenzy")
	_check(bool(one.get("rabid", false)), "which hunts like a rabid animal")
	_check(sprite.get_node_or_null("Blight") == null, "and the warning icon is gone")
	_check(sprite.get_node_or_null("Rabid") != null, "and the sickly light is on")
	# And the frenzy is finite: it exhausts, collapses and dies.
	one["blight_left"] = 0.01
	for _frame: int in 8:
		await get_tree().process_frame
	_check(int(one["blight"]) == WildlifeFamilies.Blight.COLLAPSING, "a frenzy exhausts itself")
	_check(WildlifeFamilies.speed_scale(one) < 1.0, "and falters")
	one["blight_left"] = 0.01
	for _frame: int in 8:
		await get_tree().process_frame
	_check(float(one.get("dying", 0.0)) > 0.0, "and then it dies of it")
	# Contagion: once per pair, once per carrier, and a secondary spreads none.
	var carrier: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.ADULT},
		ground + Vector2(140.0, 0.0))
	var victim: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.ADULT},
		ground + Vector2(210.0, 0.0))
	if not carrier.is_empty() and not victim.is_empty():
		carrier["blight"] = WildlifeFamilies.Blight.FRENZIED
		carrier["generation"] = 0
		carrier["spread"] = true
		_families.expose(carrier, victim, kind)
		_check(not WildlifeFamilies.is_sick(victim),
			"a carrier that has already seeded one passes it to nobody else")
		carrier["spread"] = false
		carrier["exposed"] = {}
		var secondary: Dictionary = {"data": kind, "blight": WildlifeFamilies.Blight.FRENZIED,
			"generation": 1, "exposed": {}, "net_id": -5}
		_families.expose(secondary, victim, kind)
		_check(not WildlifeFamilies.is_sick(victim), "and a secondary infection spreads no further")
	_check(WildlifeFamilies.active_limit() >= 1
		and WildlifeFamilies.active_limit() <= 3,
		"the number that may be sick at once is small (%d)" % WildlifeFamilies.active_limit())
	await _clear()


## The brief: "simply setting that flag on a rabbit will not create a properly
## functioning frenzied rabbit". So a rabbit is turned, and it must find
## something and be able to hurt it.
func _test_a_frenzy_works_on_a_species_that_never_fought() -> void:
	await _clear()
	var kind: WildlifeData = _find("rabbit")
	_check(kind != null and not kind.is_hostile() and kind.damage <= 0.0,
		"the harness needs a species that never fights")
	if kind == null:
		return
	var one: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.ADULT})
	if one.is_empty():
		_check(false, "the harness needs a rabbit")
		return
	var sprite := one["sprite"] as Sprite2D
	one["blight"] = WildlifeFamilies.Blight.FRENZIED
	one["blight_left"] = 60.0
	one["rabid"] = true
	one["hunt"] = INF
	_check(WildlifeFamilies.blight_bite(one, kind) > 0.0,
		"a frenzied rabbit can hurt something (%.1f)" % WildlifeFamilies.blight_bite(one, kind))
	# The hero stands near it. A healthy rabbit runs; a frenzied one comes.
	_field.hero.global_position = sprite.global_position + Vector2(150.0, 0.0)
	var quarry: Node2D = _animals.call("_quarry_for", sprite.global_position, kind, sprite, true, false)
	_check(quarry != null, "a frenzied grazer finds something to attack")
	var before: float = _field.hero.health.current_hp
	var closed: bool = false
	for _frame: int in 900:
		await get_tree().process_frame
		if sprite.global_position.distance_to(_field.hero.global_position) < kind.attack_range:
			closed = true
		if _field.hero.health.current_hp < before:
			break
	_check(closed, "and closes on it")
	_check(_field.hero.health.current_hp < before,
		"and bites it (%.0f -> %.0f)" % [before, _field.hero.health.current_hp])
	_field.hero.health.revive(1.0)
	_field.hero.global_position = Vector2(0.0, 1400.0)
	await _clear()


## Putting down something the blight has taken pays no wrath and counts
## toward no hunt tally: a mercy is not a hunt.
func _test_a_mercy_is_not_a_hunt() -> void:
	await _clear()
	var kind: WildlifeData = _find("rabbit")
	var sick: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.ADULT})
	if sick.is_empty():
		_check(false, "the harness needs an animal")
		return
	var mercy_ground: Vector2 = (sick["sprite"] as Sprite2D).global_position
	sick["blight"] = WildlifeFamilies.Blight.FRENZIED
	var told: Array[String] = []
	var ear: Callable = func(id: String, _food: int, _at: Vector2, _rarity: int,
			_shiny: bool, _grave: bool) -> void:
		told.append(id)
	EventBus.wildlife_killed.connect(ear)
	var index: int = _animals.living().find(sick)
	_animals.call("_wound", index, sick, 9999.0, true)
	await get_tree().process_frame
	EventBus.wildlife_killed.disconnect(ear)
	_check(told.is_empty(), "a blighted kill tells the earth nothing (%s)" % str(told))
	# And a healthy one still does, or the rule above would be a hole.
	var healthy: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.ADULT},
		mercy_ground + Vector2(80.0, 0.0))
	if healthy.is_empty():
		return
	var heard: Array[String] = []
	var ear2: Callable = func(id: String, _food: int, _at: Vector2, _rarity: int,
			_shiny: bool, _grave: bool) -> void:
		heard.append(id)
	EventBus.wildlife_killed.connect(ear2)
	_animals.call("_wound", _animals.living().find(healthy), healthy, 9999.0, true)
	await get_tree().process_frame
	EventBus.wildlife_killed.disconnect(ear2)
	_check(heard.size() == 1, "a healthy kill still does (%s)" % str(heard))
	await _clear()


## Working rule 8: the whole of this freezes with the battlefield, because it
## lives under it. A courtship, a gestation, a growth and a blight must not
## advance while the party is in a raid.
func _test_a_raid_suspends_all_of_it() -> void:
	await _clear()
	var kind: WildlifeData = _find("deer")
	var cub: Dictionary = _place(kind, {"stage": WildlifeFamilies.Stage.BABY, "rarity": int(kind.rarity), "sex": 0})
	if cub.is_empty():
		_check(false, "the harness needs a cub")
		return
	cub["blight"] = WildlifeFamilies.Blight.WARNING
	cub["blight_left"] = 99.0
	var age: float = float(cub["age"])
	var left: float = float(cub["blight_left"])
	_field.suspend()
	for _frame: int in 30:
		await get_tree().process_frame
	_check(is_equal_approx(float(cub["age"]), age),
		"a suspended field grows nothing (%.2f -> %.2f)" % [age, float(cub["age"])])
	_check(is_equal_approx(float(cub["blight_left"]), left),
		"and sickens nothing (%.2f -> %.2f)" % [left, float(cub["blight_left"])])
	_field.resume()
	for _frame: int in 10:
		await get_tree().process_frame
	_check(float(cub["age"]) > age, "and it all runs again when the road does")
	cub["blight"] = WildlifeFamilies.Blight.HEALTHY
	await _clear()


## A companion's sex is decided once a run and survives being dismissed,
## re-equipped and reconnected - none of which may reroll it.
func _test_a_companion_keeps_its_sex() -> void:
	var key: String = SpiritBond.key("fox", WildlifeData.Rarity.RARE, false)
	var first: int = WildlifeFamilies.companion_sex(key)
	_check(first == 0 or first == 1, "a spirit has a sex (%d)" % first)
	for _again: int in 20:
		_check_once(WildlifeFamilies.companion_sex(key) == first,
			"a spirit's sex is the same every time it is asked")
	# Dismissed and re-equipped is the same key asked again; a reconnect is
	# the same run seed. Only a new run may deal a new answer.
	var other: String = SpiritBond.key("fox", WildlifeData.Rarity.RARE, true)
	_check(RunState.companion_sex.has(key), "and it is remembered for the run")
	var _shiny_sex: int = WildlifeFamilies.companion_sex(other)
	_check(RunState.companion_sex.size() >= 2, "each variant has its own")
	RunState.companion_sex.clear()
	_check(not RunState.companion_sex.has(key), "and a fresh run clears them")


# --- Harness ----------------------------------------------------------------------------

## Two grown, healthy, idle animals of one species, stood near each other with
## nothing frightening in reach.
func _stand_a_pair(id: String) -> Array[Dictionary]:
	await _clear()
	var kind: WildlifeData = _find(id)
	if kind == null:
		_check(false, "the harness needs a %s" % id)
		return []
	# **Near enough to be remembered, far enough not to frighten.** An animal
	# further than `WILDLIFE_FORGET_DISTANCE` from every hero is retired on the
	# next frame, so a harness that parks the hero at the other end of the map is
	# a harness whose animals quietly stop existing - which the first cut did.
	# **Ground with nothing frightening on it.** A grazing animal will not court
	# while anything it is afraid of is inside its skittish radius, which is the
	# design - and the camps never leave, so a fixed spot is a spot that may
	# happen to sit beside one. The harness asks the wildlife for legal ground
	# and then walks away from every body until it has room.
	var at: Vector2 = _quiet_ground(kind)
	_field.hero.global_position = at + Vector2(0.0, 1100.0)
	var out: Array[Dictionary] = []
	for sex: int in 2:
		var one: Dictionary = _animals.spawn_born(kind, at + Vector2(float(sex) * 160.0, 0.0),
			{"sex": sex, "stage": WildlifeFamilies.Stage.ADULT, "rarity": int(kind.rarity)})
		if one.is_empty():
			_check(false, "the harness could not place a %s" % id)
			return []
		# Settled where it stands, with no clock running it off the field.
		one["state"] = Wildlife.State.SETTLED
		one["goal"] = (one["sprite"] as Sprite2D).global_position
		one["patience"] = 9999.0
		one["court_cooldown"] = 0.0
		one["born_act"] = -1
		out.append(one)
	# The female is out[0], which is who seeks.
	return out


## One animal stood on quiet ground with the hero near enough to remember it.
##
## **Always through a non-empty `born`.** That is what tells `_spawn` the
## animal is already where it belongs; an empty one places it at the entry
## point fifteen hundred units away, from where the hero cannot see it and the
## forget rule retires it on the next frame.
## **`near` keeps a group together.** Each call used to pick its own random
## patch of quiet ground and move the hero to it, so an animal placed early
## could end up further from the hero than `WILDLIFE_FORGET_DISTANCE` and be
## retired in the middle of the test that was watching it - the blight never
## advanced, about one run in four, and only in a long sweep. A test that
## needs several animals asks for one spot and passes it to each.
func _place(kind: WildlifeData, born: Dictionary, near: Vector2 = Vector2.INF) -> Dictionary:
	var at: Vector2 = near if near != Vector2.INF else _quiet_ground(kind)
	if near == Vector2.INF:
		_field.hero.global_position = at + Vector2(0.0, 1100.0)
	var animal: Dictionary = _animals.spawn_born(kind, at, born)
	if animal.is_empty():
		_check(false, "the harness could not place a %s" % kind.id)
		return {}
	animal["patience"] = 9999.0
	return animal


## Legal wildlife ground with no body of any kind within a wide margin.
func _quiet_ground(kind: WildlifeData) -> Vector2:
	var margin: float = maxf(kind.skittish_radius, 400.0) + 260.0
	var best: Vector2 = Vector2.ZERO
	var best_gap: float = -1.0
	for _try: int in 60:
		var spot: Vector2 = _animals.call("_clear_point")
		if spot == Vector2.ZERO:
			continue
		var gap: float = INF
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var body := node as Node2D
			if body != null and is_instance_valid(body):
				gap = minf(gap, spot.distance_to(body.global_position))
		if gap > best_gap:
			best_gap = gap
			best = spot
		if gap >= margin:
			return spot
	_check(best_gap >= margin * 0.6,
		"the harness needs quiet ground: the best it found was %.0f from a body" % best_gap)
	return best


## Everything off the field, and the budgets back.
func _clear() -> void:
	_animals.clear()
	_families.births_this_act = 0
	_families.outbreaks_this_act = 0
	for _f: int in 3:
		await get_tree().process_frame
