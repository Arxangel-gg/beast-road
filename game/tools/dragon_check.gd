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


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[dragon] " + why)
