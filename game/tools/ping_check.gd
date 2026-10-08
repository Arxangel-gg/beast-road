extends Node

## **The party's pings** (triage of 2026-10-07, item 63).
##
##   godot --headless --path game res://tools/ping_check.tscn
##
## Holds that there are eight pings, one a spoke of the wheel, each with a glyph
## on disk and a line naming who said it, and one for every kind of thing a
## quick ping can be about; that the wheel reads the spoke the pointer leans
## toward and nothing in its middle; that a ping is drawn where it was put, said
## in the feed and pointed at from the edge of the screen; that a Warden pings
## a burst and is then told to wait, that one seat keeps a few marks and the
## oldest goes; that a quick ping is about the body, the tower or the drop under
## it, else the ground; that the host admits a guest's ping by the seat its peer
## holds and refuses a forged one; that a pinging Warden's own company heeds it
## through its orders and one of them says so, while a partner's ping and a ping
## with nothing to heed move nobody; that a held Say square opens the wheel and
## is not also a tap on the chat; and that the wire and the click readers know.

const TAG: String = "[ping]"

var _run: Run = null
var _field: Battlefield = null
var _pings: PingField = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _notices: Array[String] = []
var _said: Array[String] = []
var _clock: int = 100000


func _ready() -> void:
	MetaState.hold_saves()
	var held_roster: Array[Dictionary] = MetaState.mercenaries.duplicate(true)
	var held_marks: int = MetaState.marks
	MetaState.hero_level = 30
	MetaState.mercenaries = []
	MetaState.marks = 100000
	MetaState.hire_mercenary(Mercenaries.offer("ping:0", "Pingmerc", 30, RunState.tier()))
	for row: Dictionary in MetaState.mercenaries:
		MetaState.set_mercenary_taking(String(row["uid"]), true)
	RunState.reset(false, 20261008)
	GameDirector.run_active = true
	GameDirector._muster()
	_test_the_pings()
	_test_the_wheel()
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
	RunState.gain_every_currency(999999)
	_pings = _field.ping_field()
	_check(_pings != null, "the battlefield stands no ping field")
	if _pings != null:
		_pings.now_msec = func() -> int: return _clock
		EventBus.party_notice.connect(_on_notice)
		EventBus.mercenary_said.connect(_on_said)
		_test_a_ping_is_drawn()
		_test_the_burst_and_the_cap()
		await _test_the_quick_ping()
		_test_the_host_admits()
		_test_the_company_heeds()
		_test_the_edge_points()
		_test_the_thumb_holds()
	_test_the_wiring()
	for stage: String in ["pings", "wheel", "drawn", "burst", "quick", "admit", "heed", "edge", "thumb", "wiring"]:
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
		print("%s PASS - %d checks: eight pings on a wheel, drawn, said and pointed at, a burst and a cap, the quick ping reads what is under it, the host admits by the peer's seat, the company heeds its own Warden, and a held square is the wheel" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
	return ok


func _on_notice(_slot: int, text: String) -> void:
	_notices.append(text)


func _on_said(_uid: String, _speaker: String, text: String, _alert: bool) -> void:
	_said.append(text)


## A road breed, any: the pings only ask whether a body is there.
func _a_breed() -> EnemyData:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.category == EnemyData.Category.BREED:
			return breed
	return null


func _marks_of(seat: int) -> Array[PingMark]:
	var out: Array[PingMark] = []
	for mark: PingMark in _pings.marks():
		if mark.seat == seat:
			out.append(mark)
	return out


func _clear_marks() -> void:
	for mark: PingMark in _pings.marks():
		_pings.remove_child(mark)
		mark.free()


func _test_the_pings() -> void:
	var pings: Array[PingData] = ContentDB.ping_list()
	_check(pings.size() == 8, "%d pings, the wheel has eight spokes" % pings.size())
	var slots: Array[int] = []
	var contexts: Dictionary = {}
	for data: PingData in pings:
		_check(not slots.has(data.slot), "two pings share spoke %d" % data.slot)
		slots.append(data.slot)
		_check(IconKit.ui(data.icon) != null, "%s has no glyph on disk (%s)" % [data.id, data.icon])
		_check(data.line.contains("{who}"), "%s's line does not say who said it" % data.id)
		_check(not data.display_name.is_empty(), "%s has no word" % data.id)
		if data.context != PingData.Context.NONE:
			_check(not contexts.has(data.context), "two pings answer the same quick context %d" % data.context)
			contexts[data.context] = data.id
	for want: int in [PingData.Context.GROUND, PingData.Context.BODY, PingData.Context.TOWER,
			PingData.Context.LOOT]:
		_check(contexts.has(want), "no ping answers a quick ping over context %d" % want)
	_reached.append("pings")


func _test_the_wheel() -> void:
	var cases: Array = [[Vector2(0, -80), 0], [Vector2(60, -60), 1], [Vector2(80, 0), 2],
		[Vector2(60, 60), 3], [Vector2(0, 80), 4], [Vector2(-60, 60), 5],
		[Vector2(-80, 0), 6], [Vector2(-60, -60), 7], [Vector2(5, -5), -1]]
	for case: Array in cases:
		var got: int = PingWheel.spoke_for(case[0] as Vector2)
		_check(got == int(case[1]), "a lean of %s reads spoke %d, it is %d" % [str(case[0]), got, int(case[1])])
	var wheel := PingWheel.new()
	add_child(wheel)
	wheel.open(Vector2(-500, -500))
	_check(wheel.centre().x >= Balance.PING_WHEEL_RADIUS and wheel.centre().y >= Balance.PING_WHEEL_RADIUS,
		"a wheel opened off the screen stands at %s, part of it out of reach" % str(wheel.centre()))
	var down := wheel.centre() + Vector2(0, 90)
	wheel.pointer = func() -> Vector2: return down
	wheel._process(0.016)
	var meant: String = ""
	for data: PingData in ContentDB.ping_list():
		if data.slot == 4:
			meant = data.id
	_check(wheel.chosen() == meant, "leaning down chose %s, spoke 4 is %s" % [wheel.chosen(), meant])
	var middle := wheel.centre()
	wheel.pointer = func() -> Vector2: return middle
	wheel._process(0.016)
	_check(wheel.chosen().is_empty(), "letting go in the middle sends %s" % wheel.chosen())
	wheel.queue_free()
	_reached.append("wheel")


func _test_a_ping_is_drawn() -> void:
	_clear_marks()
	_notices.clear()
	var at := _field.town_position() + Vector2(300, 120)
	_check(_pings.ask("danger", at), "a Warden alone could not ping")
	var marks: Array[PingMark] = _pings.marks()
	_check(marks.size() == 1, "%d marks for one ping" % marks.size())
	if marks.size() == 1:
		var mark: PingMark = marks[0]
		_check(mark.global_position.distance_to(at) < 1.0, "the mark stands at %s, the ping was at %s" % [str(mark.global_position), str(at)])
		_check(mark.data.id == "danger" and mark.colour() == ContentDB.ping("danger").colour,
			"the mark is not the ping that was made")
		mark._process(Balance.PING_SECONDS + 0.1)
		_check(mark.is_queued_for_deletion(), "a mark outlived its seconds")
	var heard: bool = false
	for line: String in _notices:
		if line.contains("danger"):
			heard = true
	_check(heard, "the feed never said the ping (%s)" % str(_notices))
	_check(not _pings.ask("nonsense", at), "a ping that does not exist was sent")
	_check(not _pings.ask("here", Vector2(NAN, 0.0)), "a ping at no point was sent")
	_pings.ask("here", Vector2(1.0e9, -1.0e9))
	var far: Array[PingMark] = _pings.marks()
	var outside: bool = false
	for mark: PingMark in far:
		if absf(mark.global_position.x) > BattleGrid.play_extent() + 1.0:
			outside = true
	_check(not outside, "a ping a billion units out stood off the field")
	_reached.append("drawn")


func _test_the_burst_and_the_cap() -> void:
	_clock += 60000
	_clear_marks()
	var at := _field.town_position() + Vector2(-200, 200)
	var sent: int = 0
	for index: int in Balance.PING_BURST + 2:
		if _pings.ask("here", at + Vector2(20.0 * index, 0.0)):
			sent += 1
	_check(sent == Balance.PING_BURST, "%d pings in one burst, the burst is %d" % [sent, Balance.PING_BURST])
	_clock += int(Balance.PING_BURST_SECONDS * 1000.0) + 10
	_check(_pings.ask("here", at), "a Warden could not ping again once the burst had passed")
	_clear_marks()
	# The cap is the seat's, whatever the burst: four said for one seat leaves three.
	for index: int in Balance.PING_LIVE_PER_SEAT + 1:
		EventBus.pinged.emit(2, "here", at + Vector2(0.0, 30.0 * index))
	var held: Array[PingMark] = _marks_of(2)
	_check(held.size() == Balance.PING_LIVE_PER_SEAT,
		"one seat keeps %d marks, it may keep %d" % [held.size(), Balance.PING_LIVE_PER_SEAT])
	var oldest_kept: bool = false
	for mark: PingMark in held:
		if mark.global_position.distance_to(at) < 1.0:
			oldest_kept = true
	_check(not oldest_kept, "the oldest of a seat's marks stayed when a new one came")
	_clear_marks()
	_reached.append("burst")


func _test_the_quick_ping() -> void:
	var town: Vector2 = _field.town_position()
	var open := town + Vector2(520, -520)
	_check(_pings.quick_ping_at(open) == "here", "a quick ping on open ground is %s" % _pings.quick_ping_at(open))
	var breed: EnemyData = _a_breed()
	if breed != null:
		var body: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
		if body != null:
			body.global_position = town + Vector2(-600, 400)
			await get_tree().process_frame
			_check(_pings.quick_ping_at(body.global_position + Vector2(10, -10)) == "attack",
				"a quick ping on a body is %s" % _pings.quick_ping_at(body.global_position))
			body.queue_free()
			await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	var anchor: Vector2i = _field.free_anchor_near(0)
	_field.try_build(anchor, ContentDB.base_towers()[0])
	var tower: Tower = _field.tower_at_anchor(anchor)
	if _check(tower != null, "a tower stands for the quick ping"):
		_check(_pings.quick_ping_at(tower.global_position) == "defend",
			"a quick ping on a tower is %s" % _pings.quick_ping_at(tower.global_position))
	var loot_at := town + Vector2(700, 650)
	_field.spawn_loot("gold", 30, loot_at)
	await get_tree().process_frame
	var drop: Node2D = null
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var piece := node as Node2D
		if piece != null and piece.global_position.distance_to(loot_at) < 300.0:
			drop = piece
	if _check(drop != null, "a drop lies for the quick ping"):
		_check(_pings.quick_ping_at(drop.global_position) == "loot",
			"a quick ping on a drop is %s" % _pings.quick_ping_at(drop.global_position))
	_reached.append("quick")


func _test_the_host_admits() -> void:
	_clock += 60000
	_clear_marks()
	var at := _field.town_position() + Vector2(100, 300)
	_check(_pings.admit(3, ["help", at]), "the host refused a guest's honest ping")
	_check(_marks_of(3).size() == 1, "a guest's admitted ping stands under seat %d" % 3)
	_check(not _pings.admit(0, ["help", at]), "a ping from a peer with no seat was admitted")
	_check(not _pings.admit(3, ["help"]), "a short packet was admitted")
	_check(not _pings.admit(3, ["help", "here"]), "a ping with no point was admitted")
	_check(not _pings.admit(3, ["wrath", at]), "a ping that does not exist was admitted")
	var admitted: int = 1
	for index: int in Balance.PING_BURST + 2:
		if _pings.admit(3, ["here", at]):
			admitted += 1
	_check(admitted == Balance.PING_BURST, "the host let seat 3 ping %d in a burst of %d" % [admitted, Balance.PING_BURST])
	_check(_pings.admit(2, ["here", at]), "one seat's burst refused another's")
	_clear_marks()
	_reached.append("admit")


func _test_the_company_heeds() -> void:
	_clock += 60000
	var bodies: Array[Hero] = _field.company.bodies() if _field.company != null else []
	if not _check(not bodies.is_empty(), "no mercenary stands to heed a ping"):
		_reached.append("heed")
		return
	var merc: Hero = bodies[0]
	var mind: MercenaryInput = _field.company.mind(merc.mercenary_uid)
	var seat: int = int(RunState.company_row(merc.mercenary_uid).get("master", 1))
	var near := merc.global_position + Vector2(220, 0)
	_said.clear()
	EventBus.pinged.emit(seat, "here", near)
	_check(mind.heeding() and mind.anchor().distance_to(near) < 1.0,
		"its Warden pinged here and the mercenary's post is %s" % str(mind.anchor()))
	_check(not _said.is_empty(), "nobody in the company said it heard the ping")
	mind.think(Balance.PING_HEED_SECONDS + 0.2)
	_check(not mind.heeding(), "a ping was heeded past its seconds")
	EventBus.pinged.emit(seat + 1, "here", near + Vector2(0, 200))
	_check(not mind.heeding(), "a partner's ping moved another Warden's mercenary")
	EventBus.pinged.emit(seat, "coming", near)
	_check(not mind.heeding(), "a ping with nothing to heed moved the company")
	var far := merc.global_position + Vector2(Balance.PING_HEED_REACH + 400.0, 0.0)
	EventBus.pinged.emit(seat, "here", far)
	_check(not mind.heeding(), "the company walked off to a ping across the map")
	var breed: EnemyData = _a_breed()
	if breed != null:
		var body: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
		if body != null:
			body.global_position = merc.global_position + Vector2(0, 260)
			EventBus.pinged.emit(seat, "attack", body.global_position)
			_check(mind.target() == body, "an attack ping did not name the body to the company")
			body.queue_free()
	mind.think(Balance.PING_HEED_SECONDS + 0.2)
	var warden: Hero = _field.hero
	EventBus.pinged.emit(seat, "retreat", near)
	_check(mind.heeding() and mind.anchor().distance_to(warden.global_position) < 1.0,
		"fall back did not bring the company to its Warden")
	mind.think(Balance.PING_HEED_SECONDS + 0.2)
	_clear_marks()
	_reached.append("heed")


func _test_the_edge_points() -> void:
	_clock += 60000
	_clear_marks()
	var pointers: ThreatPointers = _run.hud.find_child("ThreatPointers", true, false) as ThreatPointers
	if not _check(pointers != null, "the HUD has no edge arrows"):
		_reached.append("edge")
		return
	var reach: float = BattleGrid.play_extent() - 10.0
	_pings.ask("danger", Vector2(reach, reach))
	pointers.field = _field
	pointers._gather()
	var found: bool = false
	for pointer: Dictionary in pointers.pointers():
		if int(pointer["kind"]) == ThreatPointers.Kind.PING \
				and pointer.get("tint", null) == ContentDB.ping("danger").colour:
			found = true
	_check(found, "a ping off the screen has no arrow in its own colour")
	_check(Balance.THREAT_POINTER_COLOURS.size() == ThreatPointers.Kind.size(),
		"%d arrow colours for %d kinds" % [Balance.THREAT_POINTER_COLOURS.size(), ThreatPointers.Kind.size()])
	_clear_marks()
	_reached.append("edge")


func _test_the_thumb_holds() -> void:
	_clock += 60000
	_clear_marks()
	var hud: HUD = _run.hud
	var square: Button = hud.find_child("ChatSquare", true, false) as Button
	if not _check(square != null, "the HUD has no Say square"):
		_reached.append("thumb")
		return
	square.visible = true
	hud._on_say_down()
	hud._say_down_at -= int(Balance.PING_WHEEL_HOLD * 1000.0) + 50
	hud._tick_say_hold()
	_check(_pings.wheel.is_open(), "holding the Say square did not open the wheel")
	var at: Vector2 = _pings.wheel.centre() + Vector2(90, 0)
	_pings.wheel.pointer = func() -> Vector2: return at
	_pings.wheel._process(0.016)
	hud._on_say_up()
	square.pressed.emit()
	_check(not _pings.wheel.is_open(), "the wheel stayed open after the thumb let go")
	var own: Array[PingMark] = _marks_of(1)
	_check(own.size() == 1 and own[0].global_position.distance_to(_field.hero.global_position) < 1.0,
		"the thumb's ping is not at the Warden's feet (%d marks)" % own.size())
	var chat: PartyChat = hud.get("_chat") as PartyChat
	_check(chat == null or not chat.is_chatting(), "a held square that pinged also opened the chat")
	if chat != null and chat.is_chatting():
		chat.close_chat()
	_clear_marks()
	_reached.append("thumb")


func _test_the_wiring() -> void:
	var relay: String = FileAccess.get_file_as_string("res://scripts/systems/coop_relay.gd")
	_check(relay.contains("[\"pinged\", _on_pinged]"), "the relay does not carry a ping out")
	_check(relay.contains("Fact.PING:") and relay.contains("bus.pinged.emit("), "the relay does not bring a ping in")
	for path: String in ["res://scripts/systems/click_move.gd", "res://scenes/battlefield/placement_cursor.gd"]:
		_check(FileAccess.get_file_as_string(path).contains("alt_pressed"),
			"%s takes Alt and a click for itself" % path.get_file())
	_check(FileAccess.get_file_as_string("res://scripts/components/local_hero_input.gd").contains("_alt_click()"),
		"Alt and a click swings")
	var minimap: String = FileAccess.get_file_as_string("res://scenes/ui/minimap.gd")
	_check(minimap.contains("ping_field") and minimap.contains("pings.marks()"), "the map does not show the pings")
	_reached.append("wiring")
