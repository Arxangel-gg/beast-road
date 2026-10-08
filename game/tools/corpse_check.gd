extends Node

## **The meaty corpse and what eats it** (owner, 2026-10-07; `CorpseField`,
## `WildlifeFeeding`).
##
## On a bare field: a corpse is thrown along the blow, lifted, bounces and comes
## to rest; it lies one of eight ways and wears one of three paintings by the
## meat on it, every one on disk; it rots to bones untouched and the bones fade -
## never in Brutal; a passer-by shoves it; a bite takes meat and jolts it; the
## field keeps a cap and lets bones go first. On a real road: a body killed
## leaves a corpse where it lands, and a spirit leaves none; a scavenger smells
## one further downwind, walks to it and eats it down; a carried carcass follows
## its carrier; and at one carcass the outclassed rival yields.

const TAG: String = "[corpse]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var held_blood: Variant = MetaState.settings.get(UserSettings.BLOOD_LEVEL_KEY, null)
	var held_switch: Variant = MetaState.settings.get(UserSettings.BLOOD_VFX_KEY, null)
	MetaState.settings[UserSettings.BLOOD_VFX_KEY] = true
	_test_the_paintings()
	_test_the_ways()
	await _test_the_throw()
	_test_the_rot()
	_test_the_flies()
	_test_brutal_bones_come_home()
	await _test_the_shove()
	_test_the_bite_and_the_cap()
	_test_the_earth_takes_the_dead()
	_test_manners_at_a_carcass()
	await _test_the_road()
	if held_blood == null:
		MetaState.settings.erase(UserSettings.BLOOD_LEVEL_KEY)
	else:
		MetaState.settings[UserSettings.BLOOD_LEVEL_KEY] = held_blood
	if held_switch == null:
		MetaState.settings.erase(UserSettings.BLOOD_VFX_KEY)
	else:
		MetaState.settings[UserSettings.BLOOD_VFX_KEY] = held_switch
	for stage: String in ["paintings", "ways", "throw", "rot", "flies", "bones", "shove", "bite",
			"earth", "manners", "road", "bouts"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for child: Node in get_children():
		child.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: thrown, bounced, at rest, eight ways and three states, rotting to bones that fade except in Brutal, shoved, bitten, capped, laid by a death, smelt downwind, eaten, carried, contested, and a heap calling vultures and its lord" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


## **The earth's blows take the dead too, each its own way** (owner,
## 2026-10-08: "Earthquakes, wildfires, floods, and tornadoes, should cause some
## affected corpses to get destroyed including skeletons, each having varying
## strengths and ways of disposing of the corpses"). Forty corpses laid for each
## and every door driven directly, because each is a rule about the dead and
## not about the disaster: some are taken and some are left, the way each
## takes is its own, a smaller corpse goes before a larger, and what is not in
## reach is never touched.
## **Manners at a carcass, played out** (owner, 2026-10-08): two wolves that
## share eat side by side; a guard and a rival have it out and one goes; and a
## fight to the death ends with the hurt one fleeing or dead.
func _test_bouts_on_the_field(field: Battlefield, animals: Wildlife, wolf_kind: WildlifeData,
		spot: Vector2) -> void:
	var feeding: WildlifeFeeding = animals.get("_feeding") as WildlifeFeeding
	_check(feeding != null, "the wildlife has no appetite")
	if feeding == null or wolf_kind == null:
		_reached.append("bouts")
		return
	animals.clear()
	field.corpses.corpses().clear()
	var feast: Dictionary = field.corpses.lay(spot + Vector2(0.0, -260.0), spot + Vector2(0.0, -270.0), 60.0)
	feast["vel"] = Vector2.ZERO
	feast["vy"] = 0.0
	feast["height"] = 0.0
	var pair: Array[Dictionary] = []
	for side: float in [-18.0, 18.0]:
		# Two males, kept from courting: a pair of the other sex court and
		# a courting animal does nothing else.
		var wolf: Dictionary = animals.spawn_born(wolf_kind, (feast["at"] as Vector2) + Vector2(side, 0.0),
			{"stage": WildlifeFamilies.Stage.ADULT, "rarity": 0, "sex": WildlifeFamilies.Sex.MALE})
		if wolf.is_empty():
			continue
		wolf["court_cooldown"] = INF
		wolf["meal"] = feast
		wolf["feeding"] = true
		wolf["state"] = Wildlife.State.SETTLED
		wolf["patience"] = 9999.0
		wolf["feed_mood"] = WildlifeFeeding.Mood.SHARE
		pair.append(wolf)
	_check(pair.size() == 2, "the harness could not place two wolves")
	if pair.size() < 2:
		_reached.append("bouts")
		return
	await _wait(2.5)
	_check(pair[0].get("meal", {}) == feast and pair[1].get("meal", {}) == feast
		and (pair[0].get("bout", {}) as Dictionary).is_empty() and int(pair[0].get("bites", 0)) > 0
		and int(pair[1].get("bites", 0)) > 0, "two wolves that share did not eat side by side")
	# A guard: they have it out, and one goes.
	pair[0]["feed_mood"] = WildlifeFeeding.Mood.GUARD
	feeding.set("_dice", _seeded(41))
	var had: int = 0
	for value: Variant in feeding.bouts.values():
		had += int(value)
	var settled: bool = false
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000:
		var now: int = 0
		for value: Variant in feeding.bouts.values():
			now += int(value)
		if now > had:
			settled = true
			break
		await get_tree().process_frame
	_check(settled, "a guard and a rival at one carcass never had it out (%s)" % [feeding.bouts])
	var holding: int = 0
	for wolf: Dictionary in pair:
		holding += 1 if wolf.get("meal", {}) == feast else 0
	_check(settled and holding <= 1, "after a stand-off both wolves still hold the carcass")
	# To the death: the hurt one runs before it dies, or dies.
	for wolf: Dictionary in pair:
		wolf["meal"] = feast
		wolf["feeding"] = true
		wolf["state"] = Wildlife.State.SETTLED
		wolf["feed_mood"] = WildlifeFeeding.Mood.GUARD
		wolf.erase("bout")
	pair[1]["hp"] = Wildlife.pool_of(pair[1]) * 0.4
	feeding.call("_begin_bout", pair[0], pair[1], wolf_kind)
	var bout: Dictionary = pair[0].get("bout", {}) as Dictionary
	bout["intent"] = WildlifeFeeding.Intent.DEATH
	bout["stage"] = WildlifeFeeding.Stage.FIGHT
	var before: Dictionary = feeding.bouts.duplicate()
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 20000 and not (pair[0].get("bout", {}) as Dictionary).is_empty():
		await get_tree().process_frame
	var ended: String = ""
	for key: Variant in feeding.bouts:
		if int(feeding.bouts[key]) > int(before.get(key, 0)):
			ended = String(key)
	_check(ended == "death:fled" or ended == "death:won",
		"a fight to the death ended as '%s'" % ended)
	_check(int(pair[0].get("fought", 0)) + int(pair[1].get("fought", 0)) > 0,
		"a fight to the death landed no blows")
	animals.clear()
	field.corpses.corpses().clear()
	_reached.append("bouts")


func _test_the_earth_takes_the_dead() -> void:
	# A quake's crest: thrown up, bones shattered, a carcass swallowed.
	var field: CorpseField = _bare_field()
	field.set("_dice", _seeded(11))
	var bones: Array[Dictionary] = []
	for index: int in 40:
		var corpse: Dictionary = field.lay(Vector2.from_angle(float(index) * 0.157) * 300.0,
			Vector2.ZERO, 30.0, "", 0.0 if index % 2 == 0 else 1.0)
		corpse["vel"] = Vector2.ZERO
		corpse["height"] = 0.0
		corpse["vy"] = 0.0
		bones.append(corpse)
	var far: Dictionary = field.lay(Vector2(2000.0, 0.0), Vector2(1990.0, 0.0), 30.0)
	field.quake_front(Vector2.ZERO, 280.0, 320.0, 0, 1.0)
	var thrown: int = 0
	for corpse: Dictionary in bones:
		thrown += 1 if float(corpse["vy"]) > 0.0 else 0
	_check(thrown == 40, "a quake's crest threw %d of the 40 corpses it crossed" % thrown)
	var shattered: int = int(field.taken.get("shatter", 0))
	var swallowed: int = int(field.taken.get("swallow", 0))
	_check(shattered > 0 and shattered < 20, "a quake shattered %d of 20 skeletons" % shattered)
	_check(swallowed > 0 and swallowed < 20, "a quake swallowed %d of 20 carcasses" % swallowed)
	_check(shattered > swallowed, "a quake took carcasses (%d) as readily as bones (%d)" % [swallowed, shattered])
	_check(not far.has("leaving") and float(far["vy"]) <= 0.0 or float(far["height"]) <= 4.0,
		"a quake's crest reached a corpse two thousand units off")
	field.quake_front(Vector2.ZERO, 280.0, 320.0, 0, 1.0)
	_check(int(field.taken.get("shatter", 0)) == shattered, "one crest took the same dead twice")

	# A fire: chars meat away and burns bones to ash, given time.
	field = _bare_field()
	field.set("_dice", _seeded(12))
	for index: int in 40:
		field.lay(Vector2(float(index % 8) * 8.0, float(index / 8) * 8.0), Vector2(-10.0, 0.0), 30.0)
	var unburnt: Dictionary = field.lay(Vector2(900.0, 0.0), Vector2(890.0, 0.0), 30.0)
	var fires := PackedVector2Array([Vector2(28.0, 16.0)])
	for _step: int in 60:
		field.burn_near(fires, 0.2)
	var charred: int = 0
	for corpse: Dictionary in field.corpses():
		charred += 1 if float(corpse.get("charred", 0.0)) > 0.5 else 0
	_check(int(field.taken.get("ash", 0)) > 0, "twelve seconds in a fire burned no bones to ash")
	_check(float(unburnt["meat"]) > 0.9 and float(unburnt.get("charred", 0.0)) == 0.0,
		"a fire nine hundred units off charred a corpse")

	# A flood: floats the dead along the water and washes some away.
	field = _bare_field()
	field.set("_dice", _seeded(13))
	var floated: Array[Dictionary] = []
	for index: int in 40:
		floated.append(field.lay(Vector2(float(index) * 30.0, 0.0), Vector2(float(index) * 30.0 - 5.0, 0.0),
			10.0 if index % 2 == 0 else 90.0))
	var starts: Array[Vector2] = []
	for corpse: Dictionary in floated:
		corpse["vel"] = Vector2.ZERO
		starts.append(corpse["at"] as Vector2)
	_check(not field.flood_tick(Balance.CORPSE_FLOOD_FROM * 0.5, Vector2.DOWN, 1.0),
		"a flood under the corpses' knee moved them")
	# Measured over the first step, before the water has taken either.
	field.flood_tick(1.0, Vector2.DOWN, 0.2)
	var drifted_small: float = (floated[0]["at"] as Vector2).y - starts[0].y
	var drifted_large: float = (floated[1]["at"] as Vector2).y - starts[1].y
	for _step: int in 50:
		field.flood_tick(1.0, Vector2.DOWN, 0.2)
	_check(drifted_small > 5.0 and drifted_small > drifted_large,
		"a flood floated a small corpse %.0f and a large one %.0f down the water" % [drifted_small, drifted_large])
	_check(int(field.taken.get("wash", 0)) > 0 and int(field.taken.get("wash", 0)) < 40,
		"a flood washed away %d of 40" % int(field.taken.get("wash", 0)))

	# A funnel: drags in from its reach, flings what reaches its heart, tears some.
	field = _bare_field()
	field.set("_dice", _seeded(14))
	var dragged: Dictionary = field.lay(Vector2(300.0, 0.0), Vector2(290.0, 0.0), 30.0)
	dragged["vel"] = Vector2.ZERO
	var heart: Array[Dictionary] = []
	for index: int in 30:
		var corpse: Dictionary = field.lay(Vector2.from_angle(float(index)) * 20.0, Vector2.ZERO, 30.0)
		corpse["height"] = 0.0
		corpse["vy"] = 0.0
		heart.append(corpse)
	var outside: Dictionary = field.lay(Vector2(2000.0, 0.0), Vector2(1990.0, 0.0), 30.0)
	field.tornado_tick(Vector2.ZERO, 1.0, 0.2)
	_check((dragged["at"] as Vector2).x < 300.0, "a funnel did not drag in a corpse in its reach")
	var flung: int = 0
	for corpse: Dictionary in heart:
		flung += 1 if float(corpse["vy"]) > 0.0 else 0
	_check(flung == 30, "a funnel flung %d of the 30 corpses at its heart" % flung)
	var torn: int = int(field.taken.get("tear", 0))
	_check(torn > 0 and torn < 30, "a funnel tore %d of 30 apart" % torn)
	_check(torn > int(_quake_rate_check(shattered)), "a funnel at its heart is no stronger than a quake's crest")
	_check(not outside.has("leaving") and (outside["at"] as Vector2).x >= 1999.0,
		"a funnel reached a corpse two thousand units off")

	# And a corpse taken is drawn going, then gone.
	var leaving: int = field.count()
	field._process(Balance.CORPSE_LEAVE_SECONDS + 0.1)
	_check(field.count() == leaving - torn, "%d corpses torn apart are still on the ground"
		% (field.count() - (leaving - torn)))
	_reached.append("earth")


## **Manners at a carcass, as rules** (owner, 2026-10-08): who eats the dead,
## who guards and who shares by temperament, what a fight is for, and who backs
## off a stand-off - each measured over two thousand rolls rather than read.
func _test_manners_at_a_carcass() -> void:
	var hunter: WildlifeData = null
	var meek: WildlifeData = null
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind == null:
			continue
		if hunter == null and not kind.scavenges and kind.temperament == WildlifeData.Temperament.PREDATORY:
			hunter = kind
		if meek == null and not kind.scavenges and kind.temperament == WildlifeData.Temperament.PASSIVE:
			meek = kind
	_check(hunter != null and WildlifeFeeding.eats_the_dead(hunter),
		"a hunter that is no scavenger would not take a fresh kill")
	_check(meek != null and not WildlifeFeeding.eats_the_dead(meek), "a grazer eats the dead")
	var dice: RandomNumberGenerator = _seeded(31)
	for pair: Array in [[WildlifeData.Temperament.PREDATORY, Balance.FEED_GUARD_PREDATORY],
			[WildlifeData.Temperament.TERRITORIAL, Balance.FEED_GUARD_TERRITORIAL],
			[WildlifeData.Temperament.CAUTIOUS, Balance.FEED_GUARD_MEEK]]:
		var probe := WildlifeData.new()
		probe.temperament = int(pair[0])
		var guards: int = 0
		for _roll: int in 2000:
			guards += 1 if WildlifeFeeding.roll_mood(probe, dice) == WildlifeFeeding.Mood.GUARD else 0
		_check(absf(float(guards) / 2000.0 - float(pair[1])) < 0.04,
			"temperament %d guarded %.0f%% of meals against %.0f%%"
				% [int(pair[0]), float(guards) / 20.0, float(pair[1]) * 100.0])
		var intents: Array[int] = [0, 0, 0]
		for _roll: int in 2000:
			intents[WildlifeFeeding.roll_intent(probe, dice)] += 1
		if int(pair[0]) == WildlifeData.Temperament.CAUTIOUS:
			_check(intents[WildlifeFeeding.Intent.DEATH] == 0, "a meek animal fought to the death over food")
		else:
			_check(intents[WildlifeFeeding.Intent.DEATH] > 200 and intents[WildlifeFeeding.Intent.SPAR] > 400,
				"a proud animal's fights were %s spar, scare and death" % [intents])
	_check(WildlifeFeeding.backoff_chance(100.0, 300.0, false) > WildlifeFeeding.backoff_chance(100.0, 100.0, false)
		and WildlifeFeeding.backoff_chance(100.0, 100.0, true) > WildlifeFeeding.backoff_chance(100.0, 100.0, false)
		and WildlifeFeeding.backoff_chance(1.0, 1000.0, true) <= 0.95,
		"backing off a stand-off does not follow being outclassed and only sharing")
	_reached.append("manners")


func _quake_rate_check(shattered: int) -> int:
	# A funnel's heart takes more than half again what a crest crossing does.
	return int(float(shattered) * 0.5)


func _seeded(value: int) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = value
	return dice


func _bare_field() -> CorpseField:
	var scope := Node2D.new()
	add_child(scope)
	var field := CorpseField.new()
	scope.add_child(field)
	return field


func _test_the_paintings() -> void:
	var field: CorpseField = _bare_field()
	for state: int in 3:
		for way: int in 8:
			_check(field.texture_for(state, way) != null,
				"no painting for a %s corpse lying %s" % [CorpseField.STATES[state], CorpseField.DIRECTIONS[way]])
	_check(CorpseField.state_for(1.0) == 0 and CorpseField.state_for(0.4) == 1 and CorpseField.state_for(0.1) == 2,
		"the meat shares do not choose the three paintings")
	_reached.append("paintings")


## **Flies over the dead**: none on a fresh carcass, a few once it has lain a
## while and more on a bigger one, none on bones and none on one being carried.
func _test_the_flies() -> void:
	var corpse: Dictionary = {"age": 0.0, "meat": 1.0, "size": 0, "carried_by": null}
	_check(CorpseField.flies_on(corpse) == 0, "a fresh carcass drew flies")
	corpse["age"] = Balance.CORPSE_FLIES_FROM + 1.0
	var small: int = CorpseField.flies_on(corpse)
	_check(small > 0, "a carcass that has lain a while drew no flies")
	corpse["size"] = 2
	_check(CorpseField.flies_on(corpse) > small and CorpseField.flies_on(corpse) <= Balance.CORPSE_FLIES_MAX,
		"a bigger carcass drew %d flies against %d" % [CorpseField.flies_on(corpse), small])
	corpse["meat"] = 0.0
	_check(CorpseField.flies_on(corpse) == 0, "bones drew flies")
	corpse["meat"] = 1.0
	var carrier := Node2D.new()
	add_child(carrier)
	corpse["carried_by"] = carrier
	_check(CorpseField.flies_on(corpse) == 0, "a carcass being carried drew flies")
	carrier.queue_free()
	_reached.append("flies")


## **Brutal bones come home**: in Brutal the bones are banked with the ground and
## laid back where they lay through the battlefield's own doors; outside Brutal
## nothing is banked; a malformed row is dropped.
func _test_brutal_bones_come_home() -> void:
	var field: CorpseField = _bare_field()
	MetaState.settings[UserSettings.BLOOD_LEVEL_KEY] = UserSettings.BLOOD_BRUTAL
	var bones: Dictionary = field.lay(Vector2(120.0, 40.0), Vector2(0.0, 40.0), 30.0, "bogkin")
	bones["meat"] = 0.0
	bones["height"] = 0.0
	field.lay(Vector2(-200.0, 0.0), Vector2(0.0, 0.0), 30.0, "bogkin")
	var banked: Array = field.bones_snapshot()
	_check(banked.size() == 1, "Brutal banked %d rows for one set of bones" % banked.size())
	var home: CorpseField = _bare_field()
	home.restore_bones(banked + [["not", "a row"], 7])
	_check(home.count() == 1, "the banked bones came home as %d corpses" % home.count())
	if home.count() == 1:
		var laid: Dictionary = home.corpses()[0]
		_check((laid["at"] as Vector2).distance_to(bones["at"] as Vector2) < 0.5
				and CorpseField.state_for(float(laid["meat"])) == 2,
			"the bones came home somewhere else or with meat on them")
	MetaState.settings[UserSettings.BLOOD_LEVEL_KEY] = UserSettings.BLOOD_HIGH
	_check(field.bones_snapshot().is_empty(), "outside Brutal bones were banked")
	var source: String = FileAccess.get_file_as_string("res://scenes/battlefield/battlefield.gd")
	_check(source.contains("corpses.bones_snapshot()") and source.contains("corpses.restore_bones("),
		"the battlefield's ground does not bank or lay the bones")
	_reached.append("bones")


func _test_the_ways() -> void:
	_check(CorpseField.direction_for(Vector2.DOWN) == 0, "a corpse thrown south does not lie south")
	for way: int in 8:
		# The paintings' own compass: south, south-east, east ... on a screen whose y runs down.
		var toward: Vector2 = Vector2.from_angle(PI * 0.5 - TAU * float(way) / 8.0)
		_check(CorpseField.direction_for(toward) == way, "a corpse thrown %s lies %s" % [CorpseField.DIRECTIONS[way],
			CorpseField.DIRECTIONS[CorpseField.direction_for(toward)]])
	_check(CorpseField.direction_for(Vector2(1.0, 1.0)) == 1, "a corpse thrown down and right does not lie south-east")
	var seen: Dictionary = {}
	for step: int in 16:
		seen[CorpseField.direction_for(Vector2.from_angle(TAU * float(step) / 16.0))] = true
	_check(seen.size() == 8, "a full turn of throws lies only %d ways" % seen.size())
	# **Amended 2026-10-08**: a corpse is sized by the body's painting rather
	# than its footing, so the bands sit further out - a rabbit small, a
	# soldier medium, a camp lord large.
	_check(CorpseField.size_for(10.0) == CorpseField.Size.SMALL and CorpseField.size_for(45.0) == CorpseField.Size.MEDIUM
		and CorpseField.size_for(90.0) == CorpseField.Size.LARGE, "the sizes do not follow the body")
	var last_scale: float = 0.0
	for reach: float in [5.0, 20.0, 40.0, 70.0, 120.0, 400.0]:
		var scale: float = CorpseField.scale_for(reach)
		_check(scale >= last_scale and scale >= Balance.CORPSE_SCALE_MIN and scale <= Balance.CORPSE_SCALE_MAX,
			"a body of reach %.0f leaves a corpse at %.2f after one at %.2f" % [reach, scale, last_scale])
		last_scale = scale
	_reached.append("ways")


func _test_the_throw() -> void:
	var field: CorpseField = _bare_field()
	var corpse: Dictionary = field.lay(Vector2(500.0, 500.0), Vector2(400.0, 500.0), 30.0)
	var highest: float = 0.0
	var landed: int = 0
	var was_up: bool = false
	for _i: int in 240:
		field._process(1.0 / 60.0)
		var height: float = float(corpse["height"])
		highest = maxf(highest, height)
		if was_up and height <= 0.0:
			landed += 1
		was_up = height > 0.0
	# It is laid four units up; a blow that lifted nothing never climbs past that.
	_check(highest > 6.0, "a corpse was not lifted by the blow (%.1f)" % highest)
	_check(landed >= 2, "a corpse landed %d times - no bounce" % landed)
	_check((corpse["at"] as Vector2).x > 510.0, "a corpse struck from the west did not slide east (%.1f)" % (corpse["at"] as Vector2).x)
	_check((corpse["vel"] as Vector2).length() < 5.0 and float(corpse["height"]) <= 0.0, "a corpse never came to rest")
	_reached.append("throw")


func _test_the_rot() -> void:
	MetaState.settings[UserSettings.BLOOD_LEVEL_KEY] = UserSettings.BLOOD_HIGH
	var field: CorpseField = _bare_field()
	var corpse: Dictionary = field.lay(Vector2.ZERO, Vector2(-10.0, 0.0), 30.0)
	corpse["height"] = 0.0
	corpse["vy"] = 0.0
	corpse["vel"] = Vector2.ZERO
	for _i: int in 100:
		field._process(Balance.CORPSE_ROT_SECONDS / 90.0)
	_check(CorpseField.state_for(float(corpse["meat"])) == 2, "a corpse left alone never rotted to bones")
	for _i: int in 100:
		field._process((Balance.CORPSE_BONES_SECONDS + Balance.CORPSE_FADE_SECONDS) / 90.0)
	_check(field.count() == 0, "bones lay past their time")
	MetaState.settings[UserSettings.BLOOD_LEVEL_KEY] = UserSettings.BLOOD_BRUTAL
	var kept: CorpseField = _bare_field()
	var old: Dictionary = kept.lay(Vector2.ZERO, Vector2(-10.0, 0.0), 30.0)
	old["height"] = 0.0
	old["vy"] = 0.0
	old["vel"] = Vector2.ZERO
	for _i: int in 200:
		kept._process((Balance.CORPSE_ROT_SECONDS + Balance.CORPSE_BONES_SECONDS + Balance.CORPSE_FADE_SECONDS) / 50.0)
	_check(kept.count() == 1, "Brutal bones faded - they are meant to become part of the ground")
	MetaState.settings[UserSettings.BLOOD_LEVEL_KEY] = UserSettings.BLOOD_HIGH
	_reached.append("rot")


func _test_the_shove() -> void:
	var field: CorpseField = _bare_field()
	var corpse: Dictionary = field.lay(Vector2(2000.0, 2000.0), Vector2(1990.0, 2000.0), 20.0)
	for _i: int in 240:
		field._process(1.0 / 60.0)
	var before: Vector2 = corpse["at"]
	var walker := Node2D.new()
	walker.add_to_group(Hero.GROUP_ANY)
	add_child(walker)
	walker.global_position = before + Vector2(-8.0, 0.0)
	for _i: int in 30:
		field._process(1.0 / 60.0)
	_check((corpse["at"] as Vector2).x > before.x + 2.0, "a body standing in a corpse did not shove it")
	walker.queue_free()
	await get_tree().process_frame
	_reached.append("shove")


func _test_the_bite_and_the_cap() -> void:
	var field: CorpseField = _bare_field()
	var corpse: Dictionary = field.lay(Vector2.ZERO, Vector2(-10.0, 0.0), 30.0)
	corpse["height"] = 0.0
	corpse["vy"] = 0.0
	var meat: float = float(corpse["meat"])
	var taken: float = field.bite(corpse, 0.1, Vector2(40.0, 0.0))
	_check(is_equal_approx(taken, 0.1) and float(corpse["meat"]) < meat, "a bite took no meat")
	_check(float(corpse["vy"]) > 0.0, "a bite did not jolt the carcass off the ground")
	_check(field.bite({}, 0.5, Vector2.ZERO) == 0.0, "a bite of nothing took something")
	var bones: Dictionary = field.lay(Vector2(100.0, 0.0), Vector2(90.0, 0.0), 30.0)
	bones["meat"] = 0.0
	for index: int in Balance.CORPSE_MAX - 2:
		field.lay(Vector2(float(index) * 3.0, 50.0), Vector2(float(index) * 3.0 - 10.0, 50.0), 20.0)
	# The bones are the youngest thing on the field, so only the bones-first rule
	# - never age alone - can choose them.
	for each: Dictionary in field.corpses():
		each["age"] = 100.0
	bones["age"] = 0.0
	for index: int in 12:
		field.lay(Vector2(float(index) * 3.0, 80.0), Vector2(float(index) * 3.0 - 10.0, 80.0), 20.0)
	_check(field.count() == Balance.CORPSE_MAX, "%d corpses against a cap of %d" % [field.count(), Balance.CORPSE_MAX])
	_check(not field.corpses().has(bones), "the cap let a fresh corpse go before bare bones")
	_check(field.pile_at(Vector2(60.0, 50.0), 200.0) > 5,
		"a heap of corpses is not a pile")
	_reached.append("bite")


func _test_the_road() -> void:
	RunState.reset(false, 20261007)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	field.wave_director.stop()
	field.sky().events_enabled = false
	field.town.health.floor_hp = field.town.health.max_hp * 0.5
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_camp_mob():
			enemy.queue_free()
	var animals: Wildlife = field.wildlife()
	if animals != null:
		animals.clear()
		animals.set("_hush_left", 1.0e9)
	_check(field.corpses != null, "the battlefield has no corpse field")
	if field.corpses == null:
		run.queue_free()
		return
	await get_tree().process_frame
	# A body killed leaves its corpse where it lands; a spirit leaves none.
	var before: int = field.corpses.count()
	var flesh: Enemy = _stand_a_body(field, field.town_position() + Vector2(900.0, 900.0), EnemyData.Hide.FLESH)
	if flesh != null:
		await get_tree().process_frame
		var painted: Rect2 = Hitbox.painted_rect(flesh)
		var long_side: float = maxf(painted.size.x, painted.size.y)
		flesh.health.kill(flesh.global_position + Vector2(-50.0, 0.0))
		await _wait(Balance.ENEMY_DEATH_FALL_SECONDS + 0.4)
		_check(field.corpses.count() == before + 1, "a body killed left %d corpses" % (field.corpses.count() - before))
		# **As big as the body that fell** (owner, 2026-10-08): the corpse lies
		# about as long as the body's painting was, not the size of its feet.
		if field.corpses.count() > before:
			var laid: Dictionary = field.corpses.corpses()[field.corpses.count() - 1]
			var length: float = Balance.CORPSE_ART_LENGTH * CorpseField.scale_of(laid)
			_check(length >= long_side * 0.6 and length <= long_side * 1.2,
				"a body painted %.0f long left a corpse %.0f long" % [long_side, length])
	before = field.corpses.count()
	var spirit: Enemy = _stand_a_body(field, field.town_position() + Vector2(-900.0, 900.0), EnemyData.Hide.SPIRIT)
	if spirit != null:
		await get_tree().process_frame
		spirit.health.kill(spirit.global_position + Vector2(-50.0, 0.0))
		await _wait(Balance.ENEMY_DEATH_FALL_SECONDS + 0.4)
		_check(field.corpses.count() == before, "a spirit left a corpse")
	# Smelt further downwind.
	_check(WildlifeFeeding.scent_reach(Vector2(100.0, 0.0), Vector2.ZERO, Vector2.RIGHT)
		> WildlifeFeeding.scent_reach(Vector2(-100.0, 0.0), Vector2.ZERO, Vector2.RIGHT),
		"the wind does not carry the smell of a corpse")
	if animals == null:
		_check(false, "the field has no wildlife")
		run.queue_free()
		return
	field.corpses.corpses().clear()
	var wolf_kind: WildlifeData = ContentDB.wildlife_kinds.get("wolf", null) as WildlifeData
	_check(wolf_kind != null and wolf_kind.scavenges and wolf_kind.carries_food, "the wolf does not eat and carry the dead")
	if wolf_kind == null:
		run.queue_free()
		return
	var spot: Vector2 = _quiet_ground(animals)
	field.hero.global_position = spot + Vector2(0.0, 1100.0)
	RunState.wind = Vector2.ZERO
	var meal: Dictionary = field.corpses.lay(spot + Vector2(160.0, 0.0), spot + Vector2(150.0, 0.0), 30.0)
	var wolf: Dictionary = animals.spawn_born(wolf_kind, spot, {"stage": WildlifeFamilies.Stage.ADULT, "rarity": 0})
	_check(not wolf.is_empty(), "the harness could not place a wolf")
	if wolf.is_empty():
		run.queue_free()
		return
	wolf["state"] = Wildlife.State.SETTLED
	wolf["patience"] = 9999.0
	wolf["feed_scan"] = 0.0
	var start: float = float(meal["meat"])
	await _wait(12.0)
	_check(int(wolf.get("bites", 0)) > 0, "a wolf beside a fresh corpse never ate from it (state %d, meal %s)"
		% [int(wolf.get("state", -1)), "none" if (wolf.get("meal", {}) as Dictionary).is_empty() else "set"])
	_check(float(meal["meat"]) < start - 0.05, "a wolf at a corpse took only %.2f of it" % (start - float(meal["meat"])))
	# Carried: the carcass follows its carrier.
	var carried: Dictionary = field.corpses.lay(spot + Vector2(-200.0, 0.0), spot + Vector2(-210.0, 0.0), 14.0)
	var bearer: Sprite2D = wolf["sprite"] as Sprite2D
	field.corpses.carry(carried, bearer)
	bearer.global_position = spot + Vector2(-400.0, 200.0)
	for _i: int in 60:
		field.corpses._process(1.0 / 60.0)
	_check((carried["at"] as Vector2).distance_to(bearer.global_position) < 20.0, "a carried carcass did not follow its carrier")
	field.corpses.drop(carried)
	# A carrier freed under its carcass lets it go, and the field ticks on: the
	# cast of a freed carrier once stopped every corpse's tick for good.
	var orphan: Dictionary = field.corpses.lay(spot + Vector2(-300.0, 0.0), spot + Vector2(-310.0, 0.0), 14.0)
	var after: Dictionary = field.corpses.lay(spot + Vector2(-340.0, 60.0), spot + Vector2(-350.0, 60.0), 14.0)
	var porter := Node2D.new()
	field.add_child(porter)
	field.corpses.carry(orphan, porter)
	porter.free()
	var aged: float = float(after["age"])
	field.corpses._process(0.1)
	_check(float(after["age"]) > aged + 0.05, "a carrier freed under its carcass stopped the corpses' tick")
	_check(typeof(orphan.get("carried_by")) == TYPE_NIL, "a carcass still names a carrier that was freed")
	# Contested: the outclassed yields.
	var bear_kind: WildlifeData = ContentDB.wildlife_kinds.get("bear", null) as WildlifeData
	_check(bear_kind != null, "no bear to contest a carcass")
	if bear_kind != null:
		var prize: Dictionary = field.corpses.lay(spot + Vector2(0.0, 300.0), spot + Vector2(0.0, 290.0), 40.0)
		prize["vel"] = Vector2.ZERO
		prize["vy"] = 0.0
		prize["height"] = 0.0
		wolf["meal"] = prize
		wolf["feeding"] = true
		wolf["state"] = Wildlife.State.SETTLED
		bearer.global_position = prize["at"] as Vector2
		var bear: Dictionary = animals.spawn_born(bear_kind, (prize["at"] as Vector2) + Vector2(20.0, 0.0),
			{"stage": WildlifeFamilies.Stage.ADULT, "rarity": 2})
		_check(not bear.is_empty(), "the harness could not place a bear")
		if not bear.is_empty():
			bear["meal"] = prize
			bear["feeding"] = true
			bear["state"] = Wildlife.State.SETTLED
			bear["patience"] = 9999.0
			# A bear that holds its carcass rather than one that shares it - a
			# sharer lets an outclassed wolf eat beside it (2026-10-08).
			bear["feed_mood"] = WildlifeFeeding.Mood.GUARD
			_check(WildlifeFeeding.alpha_of(bear) > WildlifeFeeding.alpha_of(wolf) * Balance.FEED_YIELD_RATIO,
				"the harness's bear does not outclass its wolf")
			await _wait(1.0)
			_check(int(wolf.get("yielded", 0)) > 0, "an outclassed wolf kept its place at a bear's carcass")
	await _test_bouts_on_the_field(field, animals, wolf_kind, spot)
	# **A heap calls for what eats it** (`WildlifeCarrion`): three dead call
	# vultures down, a big heap past Act I may call its lord, one at a time, and
	# nothing comes while the road is hushed or past the vultures' cap.
	var carrion: WildlifeCarrion = animals.carrion
	_check(carrion != null, "the wildlife has no carrion to answer a heap")
	if carrion != null:
		var held_act: int = RunState.act
		field.corpses.corpses().clear()
		animals.clear()
		await get_tree().process_frame
		animals.set("_hush_left", 0.0)
		carrion.lord_chance = 1.0
		var heap: Vector2 = _quiet_ground(animals)
		field.hero.global_position = heap + Vector2(0.0, 1500.0)
		for index: int in Balance.CARRION_VULTURE_PILE:
			field.corpses.lay(heap + Vector2(float(index) * 24.0, 0.0), heap + Vector2(float(index) * 24.0 - 10.0, 0.0), 30.0)
		var pile: Dictionary = WildlifeCarrion.biggest_pile(field.corpses)
		_check(int(pile.get("count", 0)) == Balance.CARRION_VULTURE_PILE, "a heap of %d read as %d"
			% [Balance.CARRION_VULTURE_PILE, int(pile.get("count", 0))])
		RunState.act = 1
		_check(carrion.consider() == "vultures", "a heap of the dead called no vultures")
		_check(carrion.vulture_count() > 0, "vultures were called and none came")
		for animal: Dictionary in animals.living():
			if (animal["data"] as WildlifeData).id == WildlifeCarrion.VULTURE_ID:
				_check((animal["goal"] as Vector2).distance_to(heap) < Balance.CARRION_PILE_REACH,
					"a vulture was called to somewhere other than the heap")
		_check(carrion.consider() == "", "a heap called vultures again before they rested")
		for index: int in Balance.CARRION_LORD_PILE:
			field.corpses.lay(heap + Vector2(float(index) * 20.0, 30.0), heap + Vector2(float(index) * 20.0 - 10.0, 30.0), 30.0)
		carrion.set("_vulture_rest", 9999.0)
		_check(carrion.consider() == "", "Act I called a carrion lord")
		RunState.act = 2
		_check(carrion.consider() == "lord", "a big heap past Act I called no lord at a certain chance")
		var lords: Array[Dictionary] = []
		for animal: Dictionary in animals.living():
			if bool(animal.get("carrion_lord", false)):
				lords.append(animal)
		_check(lords.size() == 1, "%d carrion lords came" % lords.size())
		if lords.size() == 1:
			var lord: Dictionary = lords[0]
			var lord_kind := lord["data"] as WildlifeData
			_check(lord_kind.scavenges and lord_kind.is_hostile(), "the lord of a heap is not a hunting scavenger")
			_check(bool(lord.get("elite", false)) and float(lord["hp"]) > lord_kind.max_hp * Balance.WILDLIFE_ELITE_HEALTH,
				"the lord of a heap is no tougher than an elite")
			_check((lord["home"] as Vector2).distance_to(heap) < Balance.CARRION_PILE_REACH, "the lord does not keep the heap")
		_check(carrion.consider() != "lord", "a second lord came while the first lived")
		animals.set("_hush_left", 1.0e9)
		carrion.set("_vulture_rest", 0.0)
		_check(carrion.consider() == "", "a hushed road called carrion")
		animals.set("_hush_left", 0.0)
		for _try: int in 10:
			carrion.set("_vulture_rest", 0.0)
			carrion.consider()
		_check(carrion.vulture_count() <= Balance.CARRION_VULTURES_MAX, "%d vultures over a heap against a cap of %d"
			% [carrion.vulture_count(), Balance.CARRION_VULTURES_MAX])
		RunState.act = held_act
		animals.set("_hush_left", 1.0e9)
	# **A real quake on the field crosses the dead** (2026-10-08), last because
	# it frightens every animal on the field - the wave
	# tells the corpse field where its crest is, which no door driven by hand
	# can prove.
	var epicentre: Vector2 = field.town_position() + Vector2(-1400.0, 900.0)
	var shaken: Dictionary = field.corpses.lay(epicentre + Vector2(220.0, 0.0), epicentre, 30.0, "", 0.0)
	shaken["vel"] = Vector2.ZERO
	var selected: Array[String] = ["quake"]
	field.sky().quake(1.0, selected, epicentre)
	await _wait(1.2)
	_check(shaken.has("quaked") or shaken.has("leaving"),
		"a quake breaking two hundred units off never crossed the corpse")
	field.corpses.corpses().clear()
	run.queue_free()
	GameDirector.run_active = false
	for _f: int in 10:
		await get_tree().process_frame
	_reached.append("road")


## Legal wildlife ground as far from every body as the field allows: a wolf is
## a predator, and one that sees a camp body hunts it before it eats.
func _quiet_ground(animals: Wildlife) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_gap: float = -1.0
	for _try: int in 80:
		var spot: Vector2 = animals.call("_clear_point") as Vector2
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
	return best


func _stand_a_body(field: Battlefield, at: Vector2, hide: int) -> Enemy:
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	for id: String in ids:
		var data := ContentDB.enemies[id] as EnemyData
		if data == null or data.category != EnemyData.Category.BREED or data.hide != hide:
			continue
		var body := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
		body.setup(data, RunState.act, field, 1.0, 1.0, 1.0)
		field.add_child(body)
		body.global_position = at
		return body
	_check(false, "no breed with that hide to kill")
	return null


func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		left -= get_process_delta_time()
		await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
