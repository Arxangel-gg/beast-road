extends Node

## Something enormous crosses the sky, and it changes nothing it should not.
##
##   godot --headless --path game res://tools/dragon_check.tscn
##
## Owner brief, 2026-09-15: dragons breathing fire in flight, affecting the
## environment, as world events the map knows about.
## `docs/IDEAS_REVIEW_2026-09-15.md` put them after the trail and as a
## *world-event system rather than a creature* - "they should be the rarest
## thing in the game and the map should know one is there".
##
## **Five ways an event like this goes wrong, and four of them are silent:**
##
## - **It never happens.** A rate authored so low that no run ever sees one is
##   the same as content that was never built, and this project has shipped
##   that failure more than any other. The rate is asserted against the anger
##   it is cubed by, not eyeballed.
## - **It arrives without warning.** Every disaster here is telegraphed - the
##   quake hums, the funnel streaks, the meteor throws a shadow - and a blow
##   from nowhere is the one thing the forwarded notes were most insistent
##   about.
## - **It hurts something directly.** The bound is that it moves only numbers
##   the earth already has: it lights the foliage through `Wildfire` and warms
##   the ground through `Climate`, and nothing else. A dragon that dealt damage
##   of its own would be a power scale nobody is tuning, arriving from the sky.
## - **It costs the player wrath.** A fire the player did not light is the cycle
##   rather than the debt, which is the rule the earth's own lightning fire is
##   already held to.
## - **Two at once.** A second dragon over a field that is already burning is
##   not rarer for being doubled, and the wildfire's own bounds would be doing
##   all the work.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_it_is_authored_and_rare()
	await _test_it_crosses_warns_and_burns_and_hurts_nothing()
	await _test_it_is_seen_as_the_thing_it_is()
	_test_every_dragon_breathes_its_own()
	await _test_the_breath_leaves_the_mouth()
	_test_every_beam_ends_softly()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[dragon] PASS - %d checks: warned before it arrives, burns "
			+ "through the wildfire and nothing else, costs the player no "
			+ "wrath, and never two at once") % _checks)
	else:
		push_error("[dragon] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **Authored, reachable and rare** - three separate things, and the middle one
## is what a rate this small most often fails.
func _test_it_is_authored_and_rare() -> void:
	var said: WrathEventData = ContentDB.wrath_event("dragon")
	_check(said != null, "the dragon has no line in data/wrath")
	if said != null:
		_check(not said.warning.strip_edges().is_empty(),
			"a dragon must be warned, like every other thing the earth does")
	_check(ResourceLoader.exists(DragonPass.ART),
		"the dragon has no painting at %s" % DragonPass.ART)
	_check(Balance.DRAGON_WARNING_SECONDS >= 2.0,
		("%.1fs of warning is not time to look up"
			% Balance.DRAGON_WARNING_SECONDS))
	# **Rare, and reachable.** The roll is `rate * anger^3 * delta`, so at full
	# anger a minute of road is the number to read. Under a tenth of a percent
	# is content nobody meets; over about one in three is not a rarity.
	var over_a_minute: float = Balance.DRAGON_RATE * 60.0
	_check(over_a_minute > 0.02,
		("at full anger a dragon comes once every %.0f minutes, which is a "
			+ "feature nobody will ever see") % (1.0 / maxf(over_a_minute, 1e-6)))
	_check(over_a_minute < 0.34,
		"at full anger a dragon comes %.2f times a minute, which is weather"
			% over_a_minute)


## **Driven on the real field.**
func _test_it_crosses_warns_and_burns_and_hurts_nothing() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var sky: WeatherSky = field.sky() if field != null else null
	_check(sky != null, "the field must have a sky to send one")
	if sky == null:
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()

	var hero: Hero = field.hero
	var health_before: float = hero.health.current_hp if hero != null \
		and hero.health != null else 0.0
	var wrath_before: float = sky.wrath()

	var wyrm: DragonPass = sky.send_dragon(Vector2(-2000.0, 0.0), Vector2(2000.0, 0.0))
	_check(wyrm != null, "the sky refused to send one")
	if wyrm == null:
		run.queue_free()
		return
	# **Never two.** A second over a field already burning is not rarer.
	_check(sky.send_dragon(Vector2(-2000.0, 80.0), Vector2(2000.0, 80.0)) == null,
		"a second dragon was sent while the first was still crossing")

	# The warning is not the event: nothing may have caught before it arrives.
	wyrm.advance(Balance.DRAGON_WARNING_SECONDS * 0.8, 8)
	_check(wyrm.lit == 0,
		"something caught during the warning, which is the warning being the event")

	# And then it crosses.
	wyrm.advance(Balance.DRAGON_WARNING_SECONDS + Balance.DRAGON_PASS_SECONDS + Balance.DRAGON_LAND_SECONDS, 120)
	_check(wyrm.get("_kind") != null,
		"the event did not select an authored dragon variant")

	# **It hurt nobody.** Everything it does goes through the wildfire, which
	# hurts what stands in it - the hero was never under one.
	if hero != null and hero.health != null:
		_check(hero.health.current_hp >= health_before - 0.01,
			("the sheltered hero lost %.1f to a dragon over "
				+ "the foliage") % (health_before - hero.health.current_hp))
	# **And it cost the player nothing.** A fire they did not light is the cycle.
	_check(sky.wrath() <= wrath_before + 0.001,
		"a dragon raised the earth's anger against the player: %.3f from %.3f"
			% [sky.wrath(), wrath_before])
	var blaze: Wildfire = sky.wildfire
	if blaze != null:
		_check(int(blaze.get("burnt_by_player")) == 0,
			"the dragon's fire was counted against the player")

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


## **It is seen as the thing it is** (2026-09-21). Presentation, and gated
## because every one of these was true in the code and false on the screen:
## the landed body was the base painting standing still while its idle and
## attack sheets sat on disk, the shadow stayed at flight size under a body on
## the ground, a rare wyrm landed at the common size, and all four variants
## flew as one painting tinted.
func _test_it_is_seen_as_the_thing_it_is() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	var variants: Array[EnemyData] = []
	for value: Variant in ContentDB.enemies.values():
		var data := value as EnemyData
		if data != null and data.dragon_event_weight > 0.0:
			variants.append(data)
	variants.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.id < b.id)
	_check(variants.size() >= 4, "four wyrms are authored (%d)" % variants.size())
	for data: EnemyData in variants:
		var own: String = DragonPass.VARIANT_ART_FORMAT % data.id.trim_prefix("dragon_")
		_check(ResourceLoader.exists(own), "%s flies as its own painting (%s)" % [data.id, own])
		var beats: int = GameData.load_flight_frames(own).size()
		_check(beats >= 2, "%s beats its wings (%d flight frames)" % [data.id, beats])
		_check(GameData.load_idle_frames(data.get_sprite_path()).size() >= 2
				and GameData.load_attack_frames(data.get_sprite_path()).size() >= 2,
			"%s breathes and strikes on frames of its own on the ground" % data.id)
	if variants.is_empty():
		run.queue_free()
		return
	var common: DragonPass = _land_one(field, variants[0], 0)
	var rare: DragonPass = _land_one(field, variants[0], Balance.DRAGON_RARITY_WEIGHTS.size() - 1)
	_check(common.has_touched_down() and rare.has_touched_down(), "both wyrms landed")
	_check(rare.landed_size().x > common.landed_size().x * 1.05,
		"a rare wyrm lands larger than a common one (%.0f against %.0f)"
			% [rare.landed_size().x, common.landed_size().x])
	_check(common.shadow_scale() < 0.6,
		"a landed wyrm's shadow settles under it (%.2f of its flight silhouette)" % common.shadow_scale())
	# Breaths held off, so what is read is the idle and not a strike that a
	# landing happened to trigger.
	common.set("_since_fire", -30.0)
	common.set("_attack_left", 0.0)
	var first: int = common.landed_frame_index()
	common.advance(0.4, 8)
	var second: int = common.landed_frame_index()
	_check(first >= 0 and second >= 0 and first != second,
		"a landed wyrm breathes on its own frames (frame %d, then %d)" % [first, second])
	common.set("_attack_left", Balance.DRAGON_BREATH_WARNING)
	_check(common.landed_frame_index() >= 100,
		"a breath on the ground is struck on the attack frames (%d)" % common.landed_frame_index())
	common.set("_landed", false)
	common.set("_height", Balance.DRAGON_HEIGHT)
	_check(common.shadow_scale() > 0.95, "in the air the shadow is the whole silhouette")
	common.queue_free()
	rare.queue_free()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


## A wyrm of a chosen kind and rarity, driven by hand to its landing.
func _land_one(field: Battlefield, kind: EnemyData, rarity: int) -> DragonPass:
	var wyrm := DragonPass.new()
	wyrm.from = Vector2(-2000.0, 0.0)
	wyrm.to = Vector2(2000.0, 0.0)
	wyrm.field = field
	wyrm.authored_plan = {"variant": kind.id, "rarity": rarity,
		"landing": Vector2(0.0, 900.0), "land": true, "curve": Vector2.ZERO}
	field.add_child(wyrm)
	# A little past the midpoint: the step that crosses from the warning into
	# the flight spends its remainder on nothing, so an exact sum lands short.
	wyrm.advance(Balance.DRAGON_WARNING_SECONDS + Balance.DRAGON_PASS_SECONDS * 0.5 + 0.6, 80)
	return wyrm


## **Each dragon breathes its own element, and fire** (owner, 2026-09-22). Every
## dragon names an element the breath can draw; only the fire wyrm carries the
## plasma ultra; over many breaths each breathes its own element most of the
## time and plain fire the rest; and the ultra is a longer, narrower line. The
## damage is the bank's own and is decided before the dice - held by a source
## walk, because an element that multiplied it would pass every picture.
func _test_every_dragon_breathes_its_own() -> void:
	var dragons: Array[EnemyData] = []
	for value: Variant in ContentDB.enemies.values():
		var kind := value as EnemyData
		if kind != null and kind.id.begins_with("dragon_"):
			dragons.append(kind)
	_check(dragons.size() >= 4, "only %d dragons are authored" % dragons.size())
	var ultras: int = 0
	for kind: EnemyData in dragons:
		_check(Balance.DRAGON_BREATH_PALETTES.has(kind.breath_element),
			"%s breathes '%s', which no palette draws" % [kind.id, kind.breath_element])
		if kind.breath_ultra:
			ultras += 1
			_check(kind.breath_element == "fire",
				"%s carries the ultra but is not the fire wyrm" % kind.id)
		var dice := RandomNumberGenerator.new()
		dice.seed = hash(kind.id)
		var own: int = 0
		var fire: int = 0
		var ultra: int = 0
		for _roll: int in 2000:
			var chosen: Dictionary = DragonBreath.choose(kind, dice)
			var element: String = String(chosen["element"])
			if bool(chosen["ultra"]):
				ultra += 1
				_check(element == "plasma", "%s's ultra is drawn as %s" % [kind.id, element])
				_check(float(chosen["reach"]) > 1.0 and float(chosen["width"]) < 1.0,
					"%s's ultra is not a longer, narrower line" % kind.id)
				continue
			var wide: float = float(chosen["width"])
			_check(wide >= Balance.DRAGON_BREATH_WIDTH_WANDER.x - 0.001
				and wide <= Balance.DRAGON_BREATH_WIDTH_WANDER.y + 0.001,
				"%s's breath wandered outside its authored width" % kind.id)
			if element == kind.breath_element:
				own += 1
			if element == "fire":
				fire += 1
		if kind.breath_element != "fire":
			_check(own > fire and fire > 0,
				("%s breathed its own %d times and fire %d - it should mostly "
					+ "breathe its own and sometimes fire") % [kind.id, own, fire])
		_check((ultra > 0) == kind.breath_ultra,
			"%s breathed the ultra %d times with breath_ultra %s" % [kind.id, ultra, kind.breath_ultra])
	_check(ultras == 1, "%d dragons carry the ultra; the fire wyrm alone should" % ultras)
	var source: String = FileAccess.get_file_as_string("res://scenes/battlefield/enemy.gd")
	var release: int = source.find("func _release_bank()")
	var damage_at: int = source.find("blow.damage =", release)
	var dice_at: int = source.find("DragonBreath.choose", release)
	_check(release >= 0 and damage_at > release and dice_at > damage_at,
		"the release's damage must be decided before the breath's dice are rolled")
	_check(dice_at < 0 or not source.substr(dice_at, 900).contains("blow.damage"),
		"something after the breath's dice changes the release's damage")


## **A breath leaves the mouth, and the mouth flies on** (owner, 2026-09-30).
## Stood up where a flying dragon's mouth is, the breath finds that dragon,
## starts at its mouth and follows it frame by frame; the far end stays where
## the blow was aimed.
func _test_the_breath_leaves_the_mouth() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var sky: WeatherSky = field.sky() if field != null else null
	if sky == null:
		_check(false, "the field must have a sky to send one")
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	var wyrm: DragonPass = sky.send_dragon(Vector2(-2000.0, 0.0), Vector2(2000.0, 0.0))
	if wyrm == null:
		_check(false, "the sky refused to send one")
		run.queue_free()
		return
	wyrm.advance(Balance.DRAGON_WARNING_SECONDS + Balance.DRAGON_PASS_SECONDS * 0.2, 12)
	var mouth: Vector2 = wyrm.mouth()
	var body: Vector2 = wyrm.global_position - Vector2(0.0, float(wyrm.get("_height")))
	var heading: Vector2 = wyrm.get("_heading") as Vector2
	_check((mouth - body).dot(heading) > 40.0,
		"the mouth is not ahead of the body along its flight: %s from %s heading %s" % [mouth, body, heading])
	var aim: Vector2 = wyrm.global_position + heading * 500.0 + Vector2(0.0, 200.0)
	var breath: DragonBreath = DragonBreath.breathe(field, mouth, aim, 30.0, "fire", true, 0.4)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(breath.follow == wyrm, "a breath begun at a flying dragon's mouth did not find the dragon")
	_check(breath.global_position.distance_to(wyrm.mouth()) < 1.0,
		"the breath starts %.0f from the mouth" % breath.global_position.distance_to(wyrm.mouth()))
	var started: Vector2 = breath.global_position
	wyrm.advance(0.3, 6)
	await get_tree().process_frame
	_check(breath.global_position.distance_to(started) > 5.0 and breath.global_position.distance_to(wyrm.mouth()) < 1.0,
		"the breath stayed where it began while the dragon flew on: %.0f moved, %.0f from the mouth"
		% [breath.global_position.distance_to(started), breath.global_position.distance_to(wyrm.mouth())])
	_check(breath.to.is_equal_approx(aim), "the far end moved with the dragon - the blow is aimed at the ground")
	# A breath begun far from any dragon - a camp wyrm's - follows nothing.
	var camp: DragonBreath = DragonBreath.breathe(field, wyrm.mouth() + Vector2(900.0, 900.0),
		wyrm.mouth() + Vector2(1300.0, 900.0), 30.0, "fire", false, 0.4)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(camp.follow == null, "a breath far from the passing dragon was carried off by it")
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


## **Every beam ends in a soft point** (owner, 2026-09-30): no light at the
## tip, the full band where the cap meets the beam, a point rather than a cut,
## and the rows run end to end in order. Both painters use it.
func _test_every_beam_ends_softly() -> void:
	var tip: Vector2 = VfxInk.beam_cap(0.0)
	var full: Vector2 = VfxInk.beam_cap(1.0)
	_check(is_equal_approx(tip.x, Balance.BEAM_TIP_WIDTH) and is_zero_approx(tip.y),
		"a beam's tip is %.2f wide at %.2f light - it should be a point with no light" % [tip.x, tip.y])
	_check(is_equal_approx(full.x, 1.0) and is_equal_approx(full.y, 1.0), "the cap does not meet the beam whole")
	_check(VfxInk.beam_cap(0.25).x > 0.4, "the cap is a spike, not a rounded nose")
	var rows: PackedVector2Array = VfxInk.beam_rows(600.0, 20.0)
	var ordered: bool = rows.size() > 4 and is_zero_approx(rows[0].x) and is_equal_approx(rows[rows.size() - 1].x, 600.0)
	for index: int in range(1, rows.size()):
		ordered = ordered and rows[index].x >= rows[index - 1].x
	_check(ordered, "a beam's rows do not run end to end: %s" % rows)
	_check(is_zero_approx(rows[0].y) and is_zero_approx(rows[rows.size() - 1].y), "a beam's two ends are not caps")
	var short: PackedVector2Array = VfxInk.beam_rows(40.0, 30.0)
	_check(short[Balance.BEAM_CAP_ROWS].x <= 40.0 * Balance.BEAM_CAP_MOST + 0.01, "a short beam's cap ate the beam")
	var ink: String = FileAccess.get_file_as_string("res://scripts/systems/vfx_ink.gd")
	var at: int = ink.find("func _draw_beams(")
	_check(at >= 0 and ink.substr(at, 1400).contains("_beam_band(") and not ink.substr(at, 1400).contains("\t_strip(a, b"),
		"the spell beams still end on a straight cut")
	_check(FileAccess.get_file_as_string("res://scripts/systems/dragon_breath.gd").contains("VfxInk.beam_rows("),
		"the dragon's hyperbeam still ends on a straight cut")


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[dragon] " + why)
