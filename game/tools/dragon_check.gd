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
	await _test_a_loosed_breath_chases()
	await _test_the_breath_aims_where_it_catches_most()
	await _test_it_sweeps_and_rampages()
	_test_every_beam_ends_softly()
	await _test_the_menu_dragon_rides_its_wings()
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
	# **Over the mouth, never under it** (owner, 2026-09-30).
	_check(not breath.z_as_relative and breath.z_index > wyrm.z_index,
		"the breath draws at %d under the dragon at %d - it comes out from under its own jaw"
			% [breath.z_index, wyrm.z_index])
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


## **A loosed breath chases what it was breathed at, and is still one blow**
## (owner, 2026-09-30: *"Dragon breath should interpolate lerp the end of the
## beam towards its targets"*). A camp wyrm's line holds still through its
## warning, then turns toward its target and catches it - once, however many
## frames the target stands in the beam - and never leaves its arc, so a
## Warden who has moved far enough off the warned line is not followed. The
## picture's far end is the blow's, frame for frame. A passing dragon's far
## end walks toward the nearest Warden and never strays past its reach.
func _test_a_loosed_breath_chases() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var heroes: Array[Hero] = field.heroes() if field != null else []
	if heroes.is_empty():
		_check(false, "the field must have a Warden to chase")
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	var hero: Hero = heroes[0]
	hero.health.max_hp = 100000.0
	hero.health.current_hp = 100000.0
	var blows: Array = []
	hero.health.damaged.connect(func(amount: float, _from: Vector2) -> void: blows.append(amount))
	var origin: Vector2 = Vector2(2600.0, 2600.0)

	# **Amended 2026-10-08** (owner: "interpolating to new targets if where it
	# is aiming does not have a valid target to smartly aim its breath at the
	# next best target"). A Warden past the warned arc with nothing else in reach
	# is the next best target now, and is turned to - at the retargeting rate,
	# never snapped, so the turn is read. One behind it, past where it may turn
	# from where it points, is still not followed. The fifth figure is the
	# widest the line may turn in each case.
	for case: Array in [[0.40, true, "inside its arc", false, Balance.DRAGON_BREATH_TRACK_ARC],
			[0.95, true, "past its arc with nothing else in reach", true,
				Balance.DRAGON_BREATH_RETARGET_RATE * Balance.DRAGON_ULTRA_BLAST + 0.05],
			[2.2, false, "behind it, past where it may turn", true, Balance.DRAGON_BREATH_TRACK_ARC]]:
		blows.clear()
		# The last case's blow left a window of invulnerability behind it.
		hero.health.set("_invulnerable_left", 0.0)
		hero.global_position = origin + Vector2.RIGHT.rotated(float(case[0])) * 300.0
		hero.velocity = Vector2.ZERO
		var strike := EnemyGroundStrike.new()
		strike.shape = EnemyGroundStrike.Shape.LINE
		strike.breath = "fire"
		strike.ultra = bool(case[3])
		strike.reach = 420.0
		strike.half_width = 30.0
		strike.damage = 25.0
		strike.delay = 0.3
		strike.aim = Vector2.RIGHT
		strike.blamed_on = "a check"
		strike.global_position = origin
		strike.track = hero
		field.add_child(strike)
		var held_still: bool = true
		var same_line: bool = true
		var widest: float = 0.0
		var started: int = Time.get_ticks_msec()
		var picture: DragonBreath = null
		while is_instance_valid(strike) and Time.get_ticks_msec() - started < 4000:
			hero.global_position = origin + Vector2.RIGHT.rotated(float(case[0])) * 300.0
			if picture == null:
				for child: Node in field.get_children():
					if child is DragonBreath and (child as DragonBreath).source == strike:
						picture = child as DragonBreath
			if int(strike.get("_blasting") if strike.get("_blasting") != null else -1.0) < 0 \
					and float(strike.get("_blasting")) < 0.0 and not strike.aim.is_equal_approx(Vector2.RIGHT):
				held_still = false
			widest = maxf(widest, absf(strike.aim.angle()))
			if picture != null and is_instance_valid(picture) \
					and picture.to.distance_to(strike.breath_end()) > 1.0 and picture.source == strike:
				await get_tree().process_frame
				if is_instance_valid(strike) and is_instance_valid(picture) \
						and picture.to.distance_to(strike.breath_end()) > 30.0:
					same_line = false
				continue
			await get_tree().process_frame
		_check(held_still, "the breath moved during its warning - the telegraph has to hold still")
		_check(widest <= float(case[4]) + 0.01,
			"the breath turned %.2f off its warned line, past its bound of %.2f (%s)"
			% [widest, float(case[4]), String(case[2])])
		_check(picture != null and same_line, "the beam drawn is not the line that strikes")
		if bool(case[1]):
			_check(blows.size() == 1 and absf(float(blows[0]) - 25.0) < 0.01,
				"a Warden %s was struck %d times (%s) - a chase catches once (widest %.2f)"
				% [String(case[2]), blows.size(), str(blows), widest])
		else:
			_check(blows.is_empty(), "a Warden %s was followed and struck" % String(case[2]))

	# A lasting blow keeps who it caught: the same body twice is passed over,
	# whatever window of invulnerability it did or did not have.
	var once: Dictionary = {}
	var everywhere: Callable = func(_at: Vector2) -> bool: return true
	hero.health.set("_invulnerable_left", 0.0)
	var first: int = EnemyGroundStrike.strike_the_players(get_tree(), 1.0, "a check", everywhere,
		0.0, Vector2.ZERO, once)
	hero.health.set("_invulnerable_left", 0.0)
	var second: int = EnemyGroundStrike.strike_the_players(get_tree(), 1.0, "a check", everywhere,
		0.0, Vector2.ZERO, once)
	_check(first >= 1 and second == 0, "a lasting blow struck the same body twice (%d then %d)"
		% [first, second])

	# A passing dragon's breath: the far end walks toward the Warden, bounded.
	var aimed: Vector2 = origin + Vector2(400.0, 0.0)
	hero.global_position = aimed + Vector2(0.0, 320.0)
	var hazard := GroundHazard.new()
	hazard.field = field
	hazard.mirror = true
	hazard.plan = {"mode": "breath", "from": origin, "to": aimed, "origin": origin,
		"element": "fire", "ultra": false, "width": 30.0, "warning": 0.2,
		"travel": Balance.DRAGON_BREATH_BLAST, "share": 0.0, "tower_damage": 0.0,
		"tint": Color.ORANGE, "blame": "a check"}
	field.add_child(hazard)
	var start_ms: int = Time.get_ticks_msec()
	var strayed: float = 0.0
	while is_instance_valid(hazard) and Time.get_ticks_msec() - start_ms < 3000:
		hero.global_position = aimed + Vector2(0.0, 320.0)
		strayed = maxf(strayed, hazard.breath_end().distance_to(aimed))
		await get_tree().process_frame
	_check(strayed > 20.0, "a passing dragon's breath never moved toward the Warden (%.0f)" % strayed)
	_check(strayed <= Balance.DRAGON_BREATH_TRACK_REACH + 1.0,
		"a passing dragon's breath strayed %.0f from where it was aimed, past %.0f"
		% [strayed, Balance.DRAGON_BREATH_TRACK_REACH])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


## **A breath sweeps, and a landed dragon rampages** (owner, 2026-10-08:
## "doing sweeps of its breath over an area trying to fruit ninja as many
## targets in the sweep or arc motion ... and even going on a short rampage
## landing somewhere" and "Dragons also need walking sidescroller animations").
##
## The sweep is planned across the most it can cross and nothing it cannot;
## loosed on the field it runs its arc and strikes every body on it once and the
## one off it never. A landed dragon plans stops toward what is worth stamping
## on, inside its leash, walks them side-on, and takes off from where it ended
## rather than leaping back to where it came down; a copy told its plan walks
## the same path. A camp dragon walking across the screen walks in profile.
func _test_it_sweeps_and_rampages() -> void:
	# The plan, pure: three bodies inside one span and one alone on the far side.
	var marks: Array[Dictionary] = []
	for angle: float in [0.2, 0.5, 0.8, -1.0]:
		marks.append({"at": Vector2.from_angle(angle) * 300.0, "weight": 1.0})
	var planned: Vector2 = DragonBreath.plan_sweep(marks, Vector2.ZERO, 0.0, 400.0, 30.0, 0.0)
	_check(planned.is_finite(), "three bodies inside one arc were not worth a sweep")
	if planned.is_finite():
		var low: float = minf(planned.x, planned.y)
		var high: float = maxf(planned.x, planned.y)
		_check(low <= 0.2 - 0.05 and high >= 0.8 + 0.05 and low > -0.9,
			"the sweep %.2f..%.2f does not cross the three and leave the one" % [low, high])
		_check(absf(planned.x) < absf(planned.y),
			"the sweep did not start at the end nearer where the breath points")
	var alone: Array[Dictionary] = [marks[3]]
	_check(not DragonBreath.plan_sweep(alone, Vector2.ZERO, 0.0, 400.0, 30.0, 0.0).is_finite(),
		"one body was planned a sweep")

	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	if field == null or field.heroes().is_empty():
		_check(false, "the sweep needs a field with a Warden")
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	var hero: Hero = field.heroes()[0]
	hero.health.max_hp = 100000.0
	hero.health.current_hp = 100000.0
	var origin := Vector2(-2400.0, 2400.0)
	hero.global_position = origin + Vector2(-1600.0, 0.0)
	var breed: EnemyData = ContentDB.enemy("bogkin")
	var bodies: Array[Enemy] = []
	var struck: Dictionary = {}
	for angle: float in [0.2, 0.5, 0.8, -1.0]:
		var body: Enemy = field.spawn_enemy(breed, 0, 40.0, 0.0, 0.001)
		if body == null:
			continue
		body.global_position = origin + Vector2.from_angle(angle) * 300.0
		var id: int = body.get_instance_id()
		struck[id] = 0
		# Only the breath's own blows, which come from where it was breathed:
		# the road's animals and its sky may land others on a live field.
		body.health.damaged.connect(func(_amount: float, from: Vector2) -> void:
			if from.distance_to(origin) < 1.0:
				struck[id] = int(struck[id]) + 1)
		bodies.append(body)
	await get_tree().process_frame
	var sweep: Vector2 = DragonBreath.plan_sweep(DragonBreath.wild_marks(get_tree(), field,
		origin, 430.0, {}, 0.0), origin, 0.0, 400.0, 30.0, 0.0)
	_check(sweep.is_finite(), "the bodies on the field were not worth a sweep")
	var hazard := GroundHazard.new()
	hazard.field = field
	hazard.plan = {"mode": "breath", "from": origin, "to": origin + Vector2(400.0, 0.0),
		"origin": origin, "element": "fire", "ultra": false, "width": 30.0, "warning": 0.2,
		"travel": Balance.DRAGON_SWEEP_SECONDS, "share": 0.0, "tower_damage": 0.0,
		"tint": Color.ORANGE, "blame": "a check", "wild": true, "sweep": [sweep.x, sweep.y]}
	field.add_child(hazard)
	var last_angle: float = 0.0
	var started: int = Time.get_ticks_msec()
	while is_instance_valid(hazard) and Time.get_ticks_msec() - started < 5000:
		for index: int in bodies.size():
			if is_instance_valid(bodies[index]):
				bodies[index].global_position = origin + Vector2.from_angle([0.2, 0.5, 0.8, -1.0][index]) * 300.0
		last_angle = (hazard.breath_end() - origin).angle()
		await get_tree().process_frame
	_check(absf(angle_difference(last_angle, sweep.y)) < 0.05,
		"the sweep ended at %.2f, not at the far end of its arc %.2f" % [last_angle, sweep.y])
	var crossed: int = 0
	for index: int in bodies.size():
		var count: int = int(struck[bodies[index].get_instance_id()]) if is_instance_valid(bodies[index]) else -1
		if index < 3:
			_check(count == 1, "a body on the sweep was struck %d times, not once" % count)
			crossed += 1 if count == 1 else 0
		else:
			_check(count == 0, "the body off the sweep was struck %d times" % count)
	for body: Enemy in bodies:
		if is_instance_valid(body):
			body.queue_free()

	# The rampage: bodies east of where it comes down.
	var centre := origin + Vector2(0.0, -900.0)
	var herd: Array[Enemy] = []
	for offset: Vector2 in [Vector2(320.0, 10.0), Vector2(520.0, -40.0)]:
		var body: Enemy = field.spawn_enemy(breed, 0, 40.0, 0.0, 0.001)
		if body != null:
			body.global_position = centre + offset
			herd.append(body)
	await get_tree().process_frame
	var variant: String = ""
	for value: Variant in ContentDB.enemies.values():
		var kind := value as EnemyData
		if kind != null and kind.dragon_event_weight > 0.0 \
				and not GameData.load_state_frames(kind.get_sprite_path(), "side").is_empty():
			variant = kind.id
			break
	_check(not variant.is_empty(), "no dragon the sky sends has a side-on walk")
	var wyrm := DragonPass.new()
	wyrm.from = centre - Vector2(1200.0, 0.0)
	wyrm.to = centre + Vector2(1200.0, 0.0)
	wyrm.field = field
	wyrm.authored_plan = {"variant": variant, "rarity": 0, "landing": centre, "land": true,
		"fury": 1.0, "curve": Vector2.ZERO}
	field.add_child(wyrm)
	wyrm.set_process(false)
	_check(wyrm.rampage_stops() >= 1, "a dragon landing beside a pack planned no rampage")
	var plan: Dictionary = wyrm.encounter_plan()
	for stop: Variant in plan.get("rampage", []) as Array:
		_check((stop as Vector2).distance_to(centre) <= Balance.DRAGON_RAMPAGE_LEASH + 1.0,
			"a rampage stop lies %.0f from where it came down, past its leash"
				% (stop as Vector2).distance_to(centre))
	var copy := DragonPass.new()
	copy.from = plan["from"] as Vector2
	copy.to = plan["to"] as Vector2
	copy.authored_plan = plan
	field.add_child(copy)
	copy.set_process(false)
	_check(copy.encounter_plan().get("rampage", []) == plan.get("rampage", []),
		"a copy told the plan does not walk the same rampage")
	copy.queue_free()
	wyrm.advance(Balance.DRAGON_WARNING_SECONDS + Balance.DRAGON_PASS_SECONDS * 0.5 - 0.4, 60)
	var landed_seen: bool = false
	var walked: bool = false
	var side_on: bool = false
	var before: Vector2 = wyrm.global_position
	var jump: float = 0.0
	for _step: int in 400:
		if not is_instance_valid(wyrm) or wyrm.is_queued_for_deletion():
			break
		var was_landed: bool = wyrm.is_landed()
		var at: Vector2 = wyrm.global_position
		wyrm.advance(0.05, 1)
		if not is_instance_valid(wyrm):
			break
		landed_seen = landed_seen or wyrm.is_landed()
		if wyrm.is_landed() and not was_landed:
			before = wyrm.global_position
		walked = walked or wyrm.is_rampaging()
		side_on = side_on or wyrm.walking_side_on()
		if was_landed and not wyrm.is_landed():
			# The step that lifts it holds still; the leg starts on the next.
			wyrm.advance(0.05, 1)
			if is_instance_valid(wyrm):
				jump = wyrm.global_position.distance_to(at)
			break
	_check(landed_seen, "the rampaging dragon did not land")
	_check(walked, "the landed dragon never walked its rampage")
	_check(side_on, "a dragon walking east never walked side-on")
	_check(jump < Balance.DRAGON_RAMPAGE_SPEED * 0.05 + 80.0,
		"the dragon leapt %.0f units to take off - it took off from where it came down" % jump)
	_check(before.distance_to(wyrm.global_position if is_instance_valid(wyrm) else before) > 20.0,
		"the dragon never moved off where it came down")
	if is_instance_valid(wyrm):
		wyrm.queue_free()
	for body: Enemy in herd:
		if is_instance_valid(body):
			body.queue_free()

	# A camp dragon walking across the screen walks in profile, and up it does not.
	var lord: Enemy = field.spawn_enemy(ContentDB.enemy(variant), 0, 1.0, 0.0, 0.001)
	if lord != null:
		lord.global_position = origin + Vector2(0.0, 1400.0)
		await get_tree().process_frame
		lord.set("_state", Enemy.State.WALKING)
		lord.set("_motion", Vector2(60.0, 6.0))
		lord.call("_advance_walk_frames", 0.1)
		_check(lord.walking_side_on, "a camp dragon walking across the screen is not drawn side-on")
		lord.set("_motion", Vector2(6.0, 60.0))
		lord.call("_advance_walk_frames", 0.1)
		_check(not lord.walking_side_on, "a camp dragon walking up the screen is drawn side-on")
		lord.queue_free()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


## **A breath aims at the line that catches the most it has not caught**
## (owner, 2026-09-30: "the dragons should be able to more smartly aim their
## breaths so that they can make the best impact on as many targets in its
## range"). Two Wardens on one side of the warned line and one nearer it on the
## other: the breath turns to the two. Once those two are struck - a blow lands
## on a body once - it turns to the one still to reach; once all three are, no
## line is worth turning to.
func _test_the_breath_aims_where_it_catches_most() -> void:
	var origin := Vector2.ZERO
	var heroes: Array[Hero] = []
	for placed: Array in [[0.30, 300.0], [-0.30, 250.0], [-0.30, 360.0]]:
		var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
		add_child(hero)
		hero.global_position = origin + Vector2.RIGHT.rotated(float(placed[0])) * float(placed[1])
		# In play, which is what the breath asks the group for.
		hero.set_present(true)
		heroes.append(hero)
	await get_tree().process_frame
	var struck: Dictionary = {}
	var first: float = DragonBreath.best_line(get_tree(), origin, 0.0,
		Balance.DRAGON_BREATH_TRACK_ARC, 420.0, 30.0, struck, 0.0)
	_check(first != INF and absf(first - (-0.30)) < 0.1,
		"the breath turned to %.2f rather than to the two Wardens at -0.30" % first)
	struck[heroes[1].get_instance_id()] = true
	struck[heroes[2].get_instance_id()] = true
	var second: float = DragonBreath.best_line(get_tree(), origin, 0.0,
		Balance.DRAGON_BREATH_TRACK_ARC, 420.0, 30.0, struck, first)
	_check(second != INF and absf(second - 0.30) < 0.1,
		"with the two struck the breath turned to %.2f rather than to the one left at 0.30" % second)
	struck[heroes[0].get_instance_id()] = true
	_check(DragonBreath.best_line(get_tree(), origin, 0.0, Balance.DRAGON_BREATH_TRACK_ARC,
			420.0, 30.0, struck, second) == INF,
		"with everybody struck the breath still found a line worth turning to")
	for hero: Hero in heroes:
		hero.queue_free()
	for _frame: int in 4:
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


## **The menu's dragon rides its own wingbeat** (owner, 2026-10-01: *"a little
## bit of smooth vertical sway that is naturally timed with their wing flapping
## animation so that their flaps give them lift as they gently glide back down
## before the next flap"*): up while the wings sweep down, down the rest of
## the beat, back where it began each beat, and never a jump.
func _test_the_menu_dragon_rides_its_wings() -> void:
	var dragon := MenuDragon.new()
	add_child(dragon)
	await get_tree().process_frame
	var frames: int = dragon._frames.size()
	_check(frames >= 4, "the menu dragon has %d flight frames - nothing to time a lift to" % frames)
	if frames < 4:
		dragon.queue_free()
		return
	var beat: float = float(frames) / Balance.MENU_DRAGON_BEAT_RATE
	var samples: int = 600
	var rise: float = 0.0
	var sink: float = 0.0
	var biggest_jump: float = 0.0
	var low: float = INF
	var high: float = -INF
	var mean: float = 0.0
	var last: float = dragon.lift_at(0.0)
	for sample: int in range(1, samples + 1):
		var at: float = beat * float(sample) / float(samples)
		var now: float = dragon.lift_at(at)
		var shown: int = int(at * Balance.MENU_DRAGON_BEAT_RATE) % frames
		# Which way the wings are going on the frame being shown: down from
		# the frame they leave the top to the frame they reach the bottom.
		if shown == 3 or shown == 4:
			rise += now - last
		elif shown == 0 or shown == 1:
			sink += now - last
		biggest_jump = maxf(biggest_jump, absf(now - last))
		low = minf(low, now)
		high = maxf(high, now)
		mean += now / float(samples)
		last = now
	_check(rise < -0.6, "the menu dragon does not rise while its wings sweep down (moved %.2f)" % rise)
	_check(sink > 0.1, "the menu dragon does not glide down while its wings come up (moved %.2f)" % sink)
	_check(absf(dragon.lift_at(0.0) - dragon.lift_at(beat)) < 0.02,
		"the menu dragon ends a wingbeat %.2f from where it began - it drifts" % (dragon.lift_at(beat) - dragon.lift_at(0.0)))
	_check(biggest_jump < 0.05, "the menu dragon's lift jumps %.3f in a hundredth of a beat" % biggest_jump)
	_check(low < -0.9 and high > 0.9 and absf(mean) < 0.05,
		"the menu dragon's lift runs %.2f to %.2f about %.2f, not -1 to 1 about nothing" % [low, high, mean])
	# And it is drawn: the picture asks for the lift by name.
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/menu_dragon.gd")
	var drawing: String = source.substr(source.find("func _draw()"))
	_check(drawing.contains("lift_at(_beat)"), "the menu dragon works its lift out and does not draw it")
	dragon.queue_free()
	await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[dragon] " + why)
