extends Node

## **Mercenaries on the road** (owner, 2026-10-07; stage two of
## `docs/MERCENARIES_2026-10-07.md`). Stands a real road with two hired and a
## third who cannot be paid, and holds: the muster charges each contract and
## leaves the unpaid one home; each mercenary stands on its own seat as itself,
## never as the player; the road counts it as a seat; it fights what comes near;
## a kill's spoils are shared and nothing is created; a fall is its own wound and
## never the Warden's death; its last wound carries it off to a bed with its
## bill; and the payout's cut is its share.

const TAG: String = "[mercenary-road]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _run: Run = null
var _field: Battlefield = null
var _hero_died: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	var held_roster: Array[Dictionary] = MetaState.mercenaries.duplicate(true)
	var held_marks: int = MetaState.marks
	MetaState.hero_level = 30
	MetaState.mercenaries = []
	MetaState.marks = 100000
	for index: int in 3:
		MetaState.hire_mercenary(Mercenaries.offer("road:%d" % index, "Merc%d" % index, 30, RunState.tier()))
	for row: Dictionary in MetaState.mercenaries:
		MetaState.set_mercenary_taking(String(row["uid"]), true)
	RunState.reset(false, 20261007)
	GameDirector.run_active = true
	_test_the_muster()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	EventBus.hero_died.connect(func(_at: Vector2) -> void: _hero_died += 1)
	_test_the_seats()
	_test_the_road_counts_it()
	await _test_it_fights()
	_test_the_spoils()
	await _test_the_wounds()
	_test_the_cut()
	for stage: String in ["muster", "seats", "count", "fight", "spoils", "wounds", "cut"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.mercenaries = held_roster
	MetaState.marks = held_marks
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: the muster pays and leaves the unpaid home, each stands as itself on a seat the road counts, fights, shares the spoils, falls on its own wounds and goes to bed on its last" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_the_muster() -> void:
	var rows: Array[Dictionary] = MetaState.mercenaries_taking()
	_check(rows.size() == 3, "three marked to come, %d taken" % rows.size())
	var first: int = Mercenaries.contract(rows[0])
	var second: int = Mercenaries.contract(rows[1])
	# Enough for two contracts and not the third.
	MetaState.marks = first + second + Mercenaries.contract(rows[2]) - 1
	var before: int = MetaState.marks
	GameDirector._muster()
	_check(RunState.company.size() == 2, "%d walked out, two could be paid for" % RunState.company.size())
	_check(MetaState.marks == before - first - second,
		"the muster took %d, the two contracts are %d" % [before - MetaState.marks, first + second])
	_check(RunState.company_stayed_home.size() == 1, "the one who could not be paid did not stay home")
	var seats: Array[int] = []
	for row: Dictionary in RunState.company:
		seats.append(int(row["slot"]))
		_check(int(row["wounds"]) == Balance.MERC_WOUNDS, "a mercenary walked out with %d wounds" % int(row["wounds"]))
	_check(seats == [2, 3], "the company stands on seats %s, alone it is 2 and 3" % str(seats))
	_reached.append("muster")


func _test_the_seats() -> void:
	var bodies: Array[Hero] = _field.company.bodies()
	_check(bodies.size() == 2, "%d mercenaries stand on the road, two walked out" % bodies.size())
	for body: Hero in bodies:
		var row: Dictionary = MetaState.mercenary(body.mercenary_uid)
		_check(body.is_mercenary() and not body.is_local_player(), "%s reads as the player" % body.name)
		_check(body.sheet != null and body.sheet.level == int(row.get("level", 0)),
			"%s fights at level %d, it was hired at %d" % [body.name,
				body.sheet.level if body.sheet != null else -1, int(row.get("level", 0))])
		_check(body.is_in_group(Hero.GROUP_ANY), "%s is not a body the road can see" % body.name)
		_check(not body.is_in_group(Hero.GROUP), "%s took the hero group - the HUD would show its health" % body.name)
		_check(body.input is MercenaryInput, "%s has somebody else's hands" % body.name)
	_check(_field.hero != null and _field.hero.is_local_player(), "the Warden stopped being the player")
	_reached.append("seats")


func _test_the_road_counts_it() -> void:
	_check(RunState.party_size() == 3, "a Warden and two mercenaries are a party of %d" % RunState.party_size())
	_check(is_equal_approx(_field.wave_director.coop_body_scale(), WaveDirector.body_scale_for(3)),
		"the road sends %.2f of a party's bodies, a party of three is %.2f"
		% [_field.wave_director.coop_body_scale(), WaveDirector.body_scale_for(3)])
	_reached.append("count")


func _test_it_fights() -> void:
	var bodies: Array[Hero] = _field.company.bodies()
	if bodies.is_empty():
		return
	var merc: Hero = bodies[0]
	_field.hero.global_position = _field.town_position()
	merc.global_position = _field.town_position() + Vector2(900.0, 0.0)
	# A Warden swings only in a fight's phase, and so does a mercenary.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var mind := merc.input as MercenaryInput
	mind.command(MercenaryInput.Order.GUARD)
	var foe: Enemy = _stand_a_body(merc.global_position + Vector2(140.0, 0.0))
	_check(foe != null, "no body to fight")
	if foe == null:
		return
	foe.health.max_hp = 100000.0
	foe.health.current_hp = 100000.0
	foe.set_physics_process(false)
	foe.set_process(false)
	var whole: float = foe.health.current_hp
	var left: float = 6.0
	while left > 0.0 and foe.health.current_hp >= whole:
		left -= get_physics_process_delta_time()
		await get_tree().physics_frame
	_check(foe.health.current_hp < whole, "a mercenary on guard beside a body never hurt it")
	_check(mind.target() == foe or foe.health.current_hp < whole, "a mercenary never chose the body beside it")
	foe.queue_free()
	await get_tree().process_frame
	_reached.append("fight")


func _test_the_spoils() -> void:
	var purse_before: int = 0
	for row: Dictionary in RunState.company:
		purse_before += int(row.get("purse", 0))
	var gold_before: int = RunState.currency(RunState.GOLD)
	for _i: int in 200:
		RunState.gain_kill_resources(10)
	var purse_after: int = 0
	for row: Dictionary in RunState.company:
		purse_after += int(row.get("purse", 0))
	var to_company: int = purse_after - purse_before
	var to_warden: int = RunState.currency(RunState.GOLD) - gold_before
	_check(to_company > 0, "the company was paid nothing of two hundred kills")
	_check(to_warden > to_company, "the company took %d against the Warden's %d" % [to_company, to_warden])
	var share: float = float(to_company) / float(maxi(to_company + to_warden, 1))
	var wanted: float = Balance.MERC_SPOILS_SHARE * float(RunState.live_mercenaries().size())
	_check(absf(share - wanted) < 0.04, "the company took %.2f of the spoils, its share is %.2f" % [share, wanted])
	# Its own build door: a price paid at par from its purse, and never the Warden's wallet.
	var uid: String = String(RunState.company[0]["uid"])
	var gold: int = RunState.currency(RunState.GOLD)
	var row: Dictionary = RunState.company_row(uid)
	row["purse"] = 50
	_check(not RunState.mercenary_spend(uid, {"gold": 30, "wood": 30}), "a mercenary paid 60 out of 50")
	_check(RunState.mercenary_spend(uid, {"gold": 20, "wood": 20}) and int(row["purse"]) == 10,
		"a mercenary's 40 at par did not come out of its purse")
	_check(RunState.currency(RunState.GOLD) == gold, "a mercenary's purchase touched the Warden's wallet")
	_reached.append("spoils")


func _test_the_wounds() -> void:
	var bodies: Array[Hero] = _field.company.bodies()
	if bodies.is_empty():
		return
	var merc: Hero = bodies[0]
	var uid: String = merc.mercenary_uid
	var warden_hp: float = RunState.hero_hp
	var deaths: int = RunState.hero_deaths
	var size_before: int = RunState.party_size()
	for wound: int in Balance.MERC_WOUNDS:
		merc.health.take_damage(merc.health.max_hp * 10.0, merc.global_position + Vector2(-50.0, 0.0))
		await get_tree().process_frame
		var left: int = int(RunState.company_row(uid).get("wounds", -1))
		_check(left == Balance.MERC_WOUNDS - wound - 1, "after wound %d it has %d left" % [wound + 1, left])
		if left > 0:
			var waited: float = 0.0
			while waited < Balance.HERO_RESPAWN_DELAY + 2.0 and not merc.is_alive():
				waited += get_physics_process_delta_time()
				await get_tree().physics_frame
			_check(merc.is_alive(), "a mercenary with wounds left did not get up")
			# Up again, it is untouchable for a moment, as a Warden is.
			waited = 0.0
			while waited < 6.0 and merc.health.is_invulnerable():
				waited += get_physics_process_delta_time()
				await get_tree().physics_frame
	_check(RunState.hero_deaths == deaths and _hero_died == 0, "a mercenary falling was counted as the Warden dying")
	_check(is_equal_approx(RunState.hero_hp, warden_hp), "a mercenary's wounds moved the Warden's health")
	var waited: float = 0.0
	while waited < Balance.MERC_CARRY_SECONDS + 1.5 and _field.company.body(uid) != null:
		waited += get_process_delta_time()
		await get_tree().process_frame
	_check(_field.company.body(uid) == null, "a mercenary on its last wound was not carried off")
	var row: Dictionary = MetaState.mercenary(uid)
	_check(String(row.get("state", "")) == Mercenaries.STATE_RESTING and int(row.get("bill", 0)) == Mercenaries.bill(row),
		"a mercenary carried off is not in a bed with its bill")
	_check(RunState.party_size() == size_before - 1, "the road still counts a mercenary that was carried off")
	_reached.append("wounds")


func _test_the_cut() -> void:
	var cut: int = RunState.company_cut(1000)
	_check(cut == int(round(1000.0 * Balance.MERC_REWARD_SHARE * float(RunState.company.size()))),
		"the company's cut of 1000 is %d" % cut)
	_check(RunState.company_cut(0) == 0, "the company cut a payout of nothing")
	_reached.append("cut")


func _stand_a_body(at: Vector2) -> Enemy:
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	var kind: EnemyData = null
	for id: String in ids:
		var data := ContentDB.enemies[id] as EnemyData
		if data != null and data.category == EnemyData.Category.BREED:
			kind = data
			break
	if kind == null:
		return null
	var body := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
	body.setup(kind, RunState.act, _field, 1.0, 1.0, 1.0)
	_field.add_child(body)
	body.global_position = at
	return body


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
