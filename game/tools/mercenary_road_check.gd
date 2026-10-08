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
var _heard_who_came: bool = false


func _ready() -> void:
	MetaState.hold_saves()
	var held_roster: Array[Dictionary] = MetaState.mercenaries.duplicate(true)
	var held_marks: int = MetaState.marks
	MetaState.hero_level = 30
	MetaState.mercenaries = []
	MetaState.marks = 100000
	# Hired and nothing else: a hire walks out with the next road unless it is
	# kept home (2026-10-08), so no toggle is pressed here.
	for index: int in 3:
		MetaState.hire_mercenary(Mercenaries.offer("road:%d" % index, "Merc%d" % index, 30, RunState.tier()))
	RunState.reset(false, 20261007)
	GameDirector.run_active = true
	EventBus.company_news.connect(_on_company_news)
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
	await _test_the_strip()
	_test_the_road_counts_it()
	await _test_it_fights()
	_test_the_spoils()
	_test_it_builds()
	await _test_it_talks()
	await _test_the_party()
	await _test_the_wounds()
	_test_the_strip_after_the_bed()
	_test_the_cut()
	for stage: String in ["muster", "seats", "strip", "count", "fight", "spoils", "build", "talk", "party",
			"wounds", "inn line", "cut"]:
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


func _on_company_news(text: String) -> void:
	if text.contains("out with you"):
		_heard_who_came = true


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


## **The company at a glance** (2026-10-08): the HUD carries one line for each
## mercenary that walked out, naming it, its order and its wounds, with a bar
## that follows its health - and the road named who came.
func _test_the_strip() -> void:
	var hud: Node = _run.get("hud")
	var strip := hud.get("_company_strip") as CompanyStrip if hud != null else null
	_check(strip != null, "the HUD has no company readout")
	if strip == null:
		return
	strip.refresh()
	_check(strip.visible, "a company on the road is not shown on the HUD")
	var bodies: Array[Hero] = _field.company.bodies()
	for body: Hero in bodies:
		var reading: Dictionary = strip.row_reading(body.mercenary_uid)
		var name_now: String = String(RunState.company_row(body.mercenary_uid).get("name", ""))
		_check(not reading.is_empty() and String(reading["text"]).begins_with(name_now),
			"the company readout does not name %s (%s)" % [name_now, reading])
		_check(not reading.is_empty() and String(reading["text"]).contains("Follow"),
			"the company readout does not say %s's order" % name_now)
		_check(not reading.is_empty() and String(reading["wounds"]) == "%d/%d" % [Balance.MERC_WOUNDS, Balance.MERC_WOUNDS],
			"%s's wounds read %s" % [name_now, reading.get("wounds", "")])
	if not bodies.is_empty():
		var hurt: Hero = bodies[0]
		# The readout reads health, never how it was lost: set it, because a body
		# fresh on the road is still untouchable for a moment.
		var whole: float = hurt.health.current_hp
		hurt.health.current_hp = hurt.health.max_hp * 0.6
		strip.refresh()
		var after: Dictionary = strip.row_reading(hurt.mercenary_uid)
		_check(not after.is_empty() and bool(after["bar"]) and float(after["ratio"]) < 0.9,
			"a mercenary hurt by two fifths reads %s on its bar" % after.get("ratio", -1.0))
		hurt.health.current_hp = whole
	var rect: Rect2 = strip.get_global_rect()
	var view: Rect2 = strip.get_viewport_rect()
	_check(view.encloses(rect), "the company readout %s is off the screen %s" % [rect, view])
	var spirit := hud.get("_spirit_panel") as Control
	if spirit != null and spirit.visible:
		_check(not spirit.get_global_rect().intersects(rect),
			"the company readout lies over the spirit readout")
	_check(_heard_who_came, "the road never said who walked out")
	_reached.append("strip")


func _test_the_strip_after_the_bed() -> void:
	var hud: Node = _run.get("hud")
	var strip := hud.get("_company_strip") as CompanyStrip if hud != null else null
	if strip == null:
		return
	strip.refresh()
	var carried: int = 0
	for row: Dictionary in RunState.company:
		if bool(row.get("out", false)):
			var reading: Dictionary = strip.row_reading(String(row["uid"]))
			_check(not reading.is_empty() and String(reading["text"]).contains("inn") and not bool(reading["bar"]),
				"a mercenary carried off reads %s" % reading)
			carried += 1
	_check(carried > 0, "nobody was carried off to read")
	_reached.append("inn line")


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


## **It builds from its own purse** through the field's payer doors: a tower is
## its own, the Warden's wallet is never touched, the price comes out at par,
## selling it pays the purse back, and it cannot raise somebody else's tower.
func _test_it_builds() -> void:
	var bodies: Array[Hero] = _field.company.bodies()
	if bodies.is_empty():
		return
	var uid: String = bodies[0].mercenary_uid
	RunState.set_phase(RunState.Phase.PREPARATION)
	# **Amended 2026-10-08** (owner: "what mercenaries build should come out of
	# the player's resources"): the wallet pays, the purse is untouched, it
	# raises any tower and chooses a path at the split, and it works the traps.
	var row: Dictionary = RunState.company_row(uid)
	row["purse"] = 6000
	RunState.gain_every_currency(20000)
	var gold: int = int(RunState.currencies.get(RunState.GOLD, 0))
	var bought: Array[String] = _field.company.spend(uid)
	_check(not bought.is_empty(), "a mercenary with a full wallet behind it bought nothing")
	_check(int(RunState.currencies.get(RunState.GOLD, 0)) < gold, "a mercenary's building did not come out of the wallet")
	_check(int(row["purse"]) == 6000, "a mercenary paid for its building out of its own purse")
	var mine: Vector2i = _field.free_anchor_near(2, 4)
	var built: String = _field.try_build(mine, ContentDB.unlocked_base_towers()[0])
	_check(built.is_empty(), "the Warden could not build the tower a mercenary raises: %s" % built)
	var before: int = RunState.level_at(mine)
	_check(_field.upgrade_for(uid, mine).is_empty() and RunState.level_at(mine) == before + 1,
		"a mercenary could not raise the Warden's tower")
	_check(MercenaryCompany.path_for(null) == TowerData.Path.FOCUS, "a mercenary's split chose nothing")
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/mercenary_company.gd")
	_check(source.contains("_specialise(raised)") and source.contains("upgrade_trap_for("),
		"a mercenary neither chooses a path nor raises a trap")
	_reached.append("build")


## **It talks** (stage four): every moment the company names is a file with
## lines; an idle line waits its turn and a warning does not; the one nearest a
## Herald is the one who calls it; a frenzy far off is nobody's to see; the
## card opens on Interact's door, takes an order and the mercenary says so; and
## the Warden standing beside one is offered the prompt.
func _test_it_talks() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/mercenary_voice.gd") 		+ FileAccess.get_file_as_string("res://scripts/systems/mercenary_company.gd") 		+ FileAccess.get_file_as_string("res://scenes/ui/mercenary_card.gd") 		+ FileAccess.get_file_as_string("res://scenes/ui/inn_screen.gd")
	var named := RegEx.create_from_string("(?:say\\([^,]+, |_anyone\\(|_nearest\\(|line_for\\()\"([a-z_]+)\"")
	var moments: Dictionary = {}
	for found: RegExMatch in named.search_all(source):
		moments[found.get_string(1)] = true
	for entry: Array in MercenaryCard.ORDERS:
		moments[String(entry[2])] = true
	moments["bedridden"] = true
	moments["hold_talk"] = true
	moments["stranger_pitch"] = true
	_check(moments.size() >= 20, "only %d moments are named in code" % moments.size())
	for moment: Variant in moments:
		var data: MercLineData = ContentDB.merc_line(String(moment))
		_check(data != null and not data.lines.is_empty(), "the company says \"%s\" and no file has lines for it" % moment)
	var braces := RegEx.create_from_string("\\{([a-z]+)\\}")
	for value: Variant in ContentDB.merc_lines.values():
		var data := value as MercLineData
		for line: String in data.lines:
			for found: RegExMatch in braces.search_all(line):
				_check(found.get_string(1) in ["warden", "name"], "%s says {%s}, which nothing fills" % [data.id, found.get_string(1)])
	var voice: MercenaryVoice = _field.company.voice
	var bodies: Array[Hero] = _field.company.bodies()
	if voice == null or bodies.size() < 2:
		_check(false, "no voice or too few to talk")
		return
	var said: Array[String] = []
	var listen := func(uid: String, _speaker: String, text: String, _alert: bool) -> void:
		said.append(uid + "|" + text)
	EventBus.mercenary_said.connect(listen)
	var first: Hero = bodies[0]
	var second: Hero = bodies[1]
	# "boss_fell" is idle talk spoken every time it comes, so a refusal here is
	# the gap and never the dice.
	_check(ContentDB.merc_line("boss_fell").chance >= 1.0 and not ContentDB.merc_line("boss_fell").alert,
		"the gap test needs a moment that is idle and always spoken")
	var spoke: String = voice.say(first.mercenary_uid, "boss_fell", true)
	_check(not spoke.is_empty(), "a forced line said nothing")
	_check(SpeechBubble.say(first, "x") != null and first.get_node_or_null("SpeechBubble") != null,
		"a line was said with nothing over the speaker's head")
	_check(voice.say(second.mercenary_uid, "boss_fell").is_empty(),
		"an idle line was said a moment after another")
	_check(not voice.say(second.mercenary_uid, "herald").is_empty(), "a warning waited behind idle talk")
	# The one nearest a Herald calls it.
	first.global_position = _field.town_position() + Vector2(600.0, 0.0)
	second.global_position = _field.town_position() + Vector2(-600.0, 0.0)
	said.clear()
	# Beside the second, so the nearest is not simply the first in the list.
	EventBus.herald_rose.emit(_field.town_position() + Vector2(-700.0, 0.0))
	_check(said.size() == 1 and said[0].begins_with(second.mercenary_uid + "|"),
		"the Herald was not called by the one who saw it: %s" % str(said))
	said.clear()
	EventBus.wildlife_blighted.emit("wolf", _field.town_position() + Vector2(0.0, 5000.0))
	_check(said.is_empty(), "a frenzy far off was seen by %s" % str(said))
	# The card.
	_field.company.talk_to(first.mercenary_uid)
	_check(_field.company.card.is_open() and _field.company.card.uid == first.mercenary_uid, "the card did not open")
	said.clear()
	var hunt: Button = _field.company.card.find_child("Order%d" % MercenaryInput.Order.HUNT, true, false) as Button
	_check(hunt != null, "the card has no Hunt order")
	if hunt != null:
		hunt.pressed.emit()
		_check(_field.company.mind(first.mercenary_uid).order == MercenaryInput.Order.HUNT, "the card's order was not taken")
		_check(said.size() == 1, "an order was not answered: %s" % str(said))
	_field.company.card.hide_card()
	# The prompt, standing beside one.
	EventBus.claim_prompt(EventBus.prompt_owner(), "")
	_field.hero.global_position = first.global_position + Vector2(40.0, 0.0)
	(first.input as MercenaryInput).command(MercenaryInput.Order.GUARD)
	for _f: int in 4:
		await get_tree().physics_frame
	_check(EventBus.prompt_owner() == MercenaryCompany.PROMPT_OWNER,
		"a Warden beside a mercenary is offered %s, not a word with it" % EventBus.prompt_owner())
	EventBus.mercenary_said.disconnect(listen)
	_field.hero.global_position = _field.town_position()
	_reached.append("talk")


## **A party's seats** (stage five): each player's share of the free seats,
## a guest's company admitted on the host within that share, cleaned, never
## stood twice, never on a taken seat; and a guest's drawing of the company -
## puppets that stand where the host says, wear what it says, and go when it
## stops naming them.
func _test_the_party() -> void:
	_check(Mercenaries.seats_for(1) == 3 and Mercenaries.seats_for(2) == 1
			and Mercenaries.seats_for(3) == 1 and Mercenaries.seats_for(4) == 0,
		"the seats are %d, %d, %d and %d for one to four players" % [Mercenaries.seats_for(1),
			Mercenaries.seats_for(2), Mercenaries.seats_for(3), Mercenaries.seats_for(4)])
	var company: MercenaryCompany = _field.company
	var before: int = RunState.company.size()
	var records: Array = []
	for index: int in 3:
		var offered: Dictionary = Mercenaries.offer("guest:%d" % index, "Guest%d" % index, 30, RunState.tier())
		if index == 0:
			offered["level"] = 9999
		records.append(offered)
	var stood: int = company.admit(records, 2)
	var seats: Array[int] = []
	for row: Dictionary in RunState.company:
		var seat: int = int(row.get("slot", 0))
		_check(seat >= 1 and seat <= Balance.COOP_MAX_PLAYERS and not seat in seats,
			"%s stands on seat %d, twice or off the table" % [String(row.get("name", "")), seat])
		seats.append(seat)
	_check(not 1 in seats, "a mercenary stands on the Warden's own seat")
	_check(RunState.company.size() <= Balance.COOP_MAX_PLAYERS - 1,
		"%d mercenaries beside one Warden" % RunState.company.size())
	_check(stood == mini(3, Balance.COOP_MAX_PLAYERS - 1 - before), "the host stood %d of a guest's three, %d seats were free"
		% [stood, Balance.COOP_MAX_PLAYERS - 1 - before])
	for row: Dictionary in RunState.company:
		if bool(row.get("guest", false)):
			# The record itself, not the sheet: a sheet cleans its own level, so it
			# would read clean whether or not the admission did.
			_check(int(company.record(String(row["uid"])).get("level", 0)) <= Balance.HERO_MAX_LEVEL,
				"a guest's forged mercenary was admitted as it was sent")
	_check(company.admit(records, 2) == 0, "a guest's company was stood twice")
	# The guest's drawing.
	var rows: Array = [[3, 2, "merc-x", "Rue", _field.town_position() + Vector2(200.0, 0.0), 0.5,
		Vector2.RIGHT, Vector2.UP, WardenLook.pack(WardenLook.plain()), ["", "", "", "", ""], 2]]
	company.apply_state(rows)
	var drawn: Hero = company.puppet(3)
	_check(drawn != null and drawn.mercenary_uid == "merc-x", "a guest drew no puppet for the seat it was told")
	if drawn != null:
		_check(not drawn.is_local_player(), "a puppet reads as the player")
		_check(absf(drawn.health.current_hp / drawn.health.max_hp - 0.5) < 0.01, "a puppet's health is not the host's")
		_check(not (drawn.input is MercenaryInput), "a puppet has a mind of its own")
	company.apply_state([])
	await get_tree().process_frame
	_check(company.puppet(3) == null, "a puppet the host stopped naming is still standing")
	_reached.append("party")


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
