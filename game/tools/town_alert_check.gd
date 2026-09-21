extends Node
## The wall said out loud, and the sanctuary said on entering (2026-09-21).
##
## "I didn't know I was losing" was the first-hour complaint the roadmap put
## first, and the town bar answered a blow with nothing. Driven on the real
## run scene and read back off the HUD's own banner and its own state, because
## a banner authored and never fed would pass a data walk:
##
## - a blow on the town flashes the bar and names the road it came from;
## - a second blow inside the cooldown says nothing new, and one after it
##   names its own road;
## - under the critical share the bar reads as critical, and not above it;
## - a body inside `TOWN_ALERT_NEAR` of the town reads as a threat and is said
##   once; gone, it is not;
## - stepping into the sanctuary in combat is said once, not again inside the
##   cooldown, and again after it.

const TAG: String = "[town-alert]"

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	await _test_the_wall_and_the_sanctuary()
	MetaState.resume_saves()
	_finish()


func _test_the_wall_and_the_sanctuary() -> void:
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var hud: HUD = run.hud
	if not _check(field != null and hud != null, "the run stands up a field and a HUD"):
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	# Hand-driven from here: the HUD's own tick would race the reads.
	run.process_mode = Node.PROCESS_MODE_DISABLED
	var banner: Label = hud.get("_message") as Label
	var town: Vector2 = field.town_position()

	# A blow names its road.
	EventBus.town_struck.emit(town + Vector2(700.0, 0.0))
	_check(banner.text.contains("UNDER ATTACK") and banner.text.contains("EAST"),
		"a blow from the east says the wall is under attack from the east (\"%s\")" % banner.text)
	_check(bool(hud.town_alert_state()["flashing"]), "and the bar flashes")
	# Inside the cooldown a second road is not named.
	EventBus.town_struck.emit(town + Vector2(-700.0, 0.0))
	_check(banner.text.contains("EAST") and not banner.text.contains("WEST"),
		"a second blow inside the cooldown does not replace the banner (\"%s\")" % banner.text)
	hud.call("_tick_town_alert", Balance.TOWN_ALERT_COOLDOWN + 0.5)
	EventBus.town_struck.emit(town + Vector2(0.0, -700.0))
	_check(banner.text.contains("NORTH"),
		"after the cooldown a blow from the north names the north (\"%s\")" % banner.text)

	# Critical, and not.
	EventBus.town_health_changed.emit(1000.0 * Balance.TOWN_ALERT_CRITICAL_SHARE * 0.5, 1000.0)
	_check(bool(hud.town_alert_state()["critical"]), "under the critical share the wall reads as critical")
	EventBus.town_health_changed.emit(1000.0, 1000.0)
	_check(not bool(hud.town_alert_state()["critical"]), "and whole it does not")

	# Bodies at the gate.
	hud.call("_tick_town_alert", Balance.TOWN_ALERT_COOLDOWN + 1.0)
	banner.text = ""
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var data := value as EnemyData
		if data != null and data.category == EnemyData.Category.BREED:
			breed = data
			break
	var body: Enemy = field.spawn_enemy(breed, 0, 1.0) if breed != null else null
	if _check(body != null, "a body can be stood at the gate"):
		body.global_position = town + Vector2(Balance.TOWN_ALERT_NEAR * 0.5, 0.0)
		hud.call("_tick_town_alert", 1.0)
		_check(bool(hud.town_alert_state()["threatened"]),
			"a body inside TOWN_ALERT_NEAR reads as a threat")
		_check(banner.text.contains("GATE"), "and is said once (\"%s\")" % banner.text)
		body.queue_free()
		await get_tree().process_frame
		hud.call("_tick_town_alert", 1.0)
		_check(not bool(hud.town_alert_state()["threatened"]), "gone, the threat is gone")

	# The sanctuary.
	var hero: Hero = field.hero
	if _check(hero != null, "the field has a hero"):
		hero.global_position = town + Vector2(3000.0, 0.0)
		hud.call("_tick_sanctuary", 0.1)
		banner.text = ""
		hero.global_position = town
		hud.call("_tick_sanctuary", 0.1)
		_check(banner.text.contains("SANCTUARY"),
			"stepping onto the town in combat is said (\"%s\")" % banner.text)
		banner.text = ""
		hero.global_position = town + Vector2(3000.0, 0.0)
		hud.call("_tick_sanctuary", 0.1)
		hero.global_position = town
		hud.call("_tick_sanctuary", 0.1)
		_check(banner.text.is_empty(), "and not again inside the cooldown (\"%s\")" % banner.text)
		hero.global_position = town + Vector2(3000.0, 0.0)
		hud.call("_tick_sanctuary", Balance.SANCTUARY_SAY_COOLDOWN + 1.0)
		hero.global_position = town
		hud.call("_tick_sanctuary", 0.1)
		_check(banner.text.contains("SANCTUARY"), "and again after it")

	run.process_mode = Node.PROCESS_MODE_INHERIT
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failures += 1
	push_error("%s %s" % [TAG, why])
	return false


func _finish() -> void:
	if _failures == 0:
		print("%s PASS - %d checks" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
