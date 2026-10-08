class_name MercenaryCompany
extends Node

## **The company on the road** (owner, 2026-10-07; `docs/MERCENARIES_2026-10-07.md`).
## Stands each mercenary `GameDirector._muster` paid for on its seat, as a
## partner's body with `MercenaryInput` for hands, lets it think every physics
## frame, and carries it off the road after its last wound to a bed at the Hold.
##
## A child of the battlefield, so a raid's freeze holds the company with the
## field (working rule 8) and a field torn down takes it with it.

var field: Battlefield = null
var _bodies: Dictionary = {}
var _minds: Dictionary = {}
## What the company says (`MercenaryVoice`) and the card a Warden talks to one
## through (`MercenaryCard`).
var voice: MercenaryVoice = null
var card: MercenaryCard = null
const PROMPT_OWNER: StringName = &"mercenary"
## Who each mercenary standing here is: its record, from this account's roster
## or from the guest that brought it (2026-10-07, stage five).
var _records: Dictionary = {}
## A guest's drawing of the company, by seat: puppets the host's state moves.
var _puppets: Dictionary = {}
var _state_left: float = 0.0
var _told_empty: bool = true
var _restate_left: float = 0.0


func _ready() -> void:
	name = "MercenaryCompany"
	EventBus.mercenary_fell.connect(_on_fell)
	EventBus.phase_changed.connect(_on_phase_changed)
	voice = MercenaryVoice.new()
	voice.company = self
	add_child(voice)
	card = MercenaryCard.new()
	add_child(card)
	card.ordered.connect(_on_ordered)
	EventBus.coop_request_received.connect(_on_request)
	EventBus.coop_company_state.connect(_on_company_state)
	EventBus.coop_company_carried.connect(_on_company_carried)
	EventBus.coop_company_said.connect(_on_company_said)
	EventBus.pinged.connect(_on_pinged)
	_muster.call_deferred()


## The body of one mercenary on this road, or null.
func body(uid: String) -> Hero:
	var found: Variant = _bodies.get(uid, null)
	return found as Hero if found != null and is_instance_valid(found) else null


## Its mind.
func mind(uid: String) -> MercenaryInput:
	return _minds.get(uid, null) as MercenaryInput


## Every mercenary body standing on this road.
func bodies() -> Array[Hero]:
	var out: Array[Hero] = []
	for uid: Variant in _bodies:
		var found: Hero = body(String(uid))
		if found != null:
			out.append(found)
	return out


func _muster() -> void:
	if field == null:
		return
	for row: Dictionary in RunState.company:
		if not bool(row.get("out", false)) and not bool(row.get("remote", false)):
			_records[String(row["uid"])] = MetaState.mercenary(String(row["uid"]))
			_stand(row)
	for row: Dictionary in RunState.live_mercenaries():
		voice.say(String(row.get("uid", "")), "road_start", true)
		break
	# **The road says who came** (2026-10-08): a company nobody announced is a
	# company the player does not know walked out with them.
	var came: PackedStringArray = []
	for row: Dictionary in CompanyStrip.own_rows():
		came.append(String(row.get("name", "")))
	if not came.is_empty():
		EventBus.company_news.emit("%s %s out with you." % [_named(came),
			"walks" if came.size() == 1 else "walk"])
	if not RunState.company_stayed_home.is_empty():
		get_tree().create_timer(Balance.COMPANY_NEWS_GAP).timeout.connect(_say_who_stayed)


func _say_who_stayed() -> void:
	EventBus.company_news.emit("%s stayed home: no Marks for the contract."
		% _named(PackedStringArray(RunState.company_stayed_home)))


## "Ash", "Ash and Rue", "Ash, Rue and Fen".
static func _named(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return names[0] if names.size() == 1 else ""
	return "%s and %s" % [", ".join(names.slice(0, names.size() - 1)), names[names.size() - 1]]


## How whole a mercenary is on this road, 0 to 1, or -1 when nothing here draws
## it: the body on a host, the puppet the host's word moves on a guest.
func health_ratio(uid: String) -> float:
	var found: Hero = body(uid)
	if found == null:
		for slot: Variant in _puppets:
			var puppet_body: Hero = _puppets[slot] as Hero
			if puppet_body != null and is_instance_valid(puppet_body) and puppet_body.mercenary_uid == uid:
				found = puppet_body
				break
	if found == null or found.health == null or found.health.max_hp <= 0.0:
		return -1.0
	return clampf(found.health.current_hp / found.health.max_hp, 0.0, 1.0)


## One mercenary on its seat.
func _stand(row: Dictionary) -> Hero:
	var uid: String = String(row.get("uid", ""))
	var hired: Dictionary = _records.get(uid, {}) as Dictionary
	if hired.is_empty():
		hired = MetaState.mercenary(uid)
	if hired.is_empty() or field == null or field.entity_root == null:
		return null
	var scene: PackedScene = load("res://scenes/hero/hero.tscn") as PackedScene
	var hero := scene.instantiate() as Hero if scene != null else null
	if hero == null:
		return null
	var hands := MercenaryInput.new(hero, uid)
	hands.master = _master_body(int(row.get("master", 1)))
	hands.field = field
	# Before the tree, so `Hero._ready` never builds a keyboard for it.
	hero.input = hands
	hero.mercenary_uid = uid
	hero.name = "Mercenary%d" % int(row.get("slot", 2))
	hero.field = field
	hero.party_slot = int(row.get("slot", 2))
	hero.bounds_extent = Vector2.ONE * BattleGrid.play_extent()
	hero.spawn_point = CoopHeroes.spawn_for_slot(hero.party_slot, field.town_position())
	hero.position = hero.spawn_point
	field.entity_root.add_child(hero)
	hero.wear_sheet(Mercenaries.sheet_row(hired))
	hero.wear_look(hired.get("look", []))
	hero.wear_gear(Mercenaries.worn_kinds(hired))
	hero.set_present(true)
	# Never the hero group: that group is "whose health the HUD shows".
	hero.set_active(false)
	hero.set_nameplate(String(hired.get("name", "")))
	hands.command(MercenaryInput.Order.FOLLOW)
	_bodies[uid] = hero
	_minds[uid] = hands
	return hero


func _physics_process(delta: float) -> void:
	for uid: Variant in _minds:
		var found: Hero = body(String(uid))
		var hands := _minds[uid] as MercenaryInput
		if found != null and hands != null:
			hands.think(delta)
	_offer_talk()
	if Coop.is_networked():
		if Coop.is_guest():
			_tell_the_host_my_company(delta)
		else:
			_send_company_state(delta)


## **Interact beside a mercenary to talk to it.** The prompt is offered only
## while nothing else on the field holds the line - a seam, a pond or a gate
## beside it keeps its own prompt - and the card closes when the Warden walks off.
func _offer_talk() -> void:
	if field == null or field.hero == null or not field.hero.is_alive():
		return
	var warden: Hero = field.hero
	var nearest: Hero = null
	var best: float = Balance.MERC_TALK_REACH
	for found: Hero in bodies():
		if not found.is_alive():
			continue
		var d: float = found.global_position.distance_to(warden.global_position)
		if d < best:
			best = d
			nearest = found
	if card != null and card.is_open() and (nearest == null or nearest.mercenary_uid != card.uid):
		card.hide_card()
	if nearest == null:
		if EventBus.prompt_owner() == PROMPT_OWNER:
			EventBus.claim_prompt(PROMPT_OWNER, "")
			EventBus.interact_prompt.emit("", "")
		return
	var owner_now: StringName = EventBus.prompt_owner()
	if not owner_now.is_empty() and owner_now != PROMPT_OWNER:
		return
	var said: String = "Talk  ·  %s" % String(RunState.company_row(nearest.mercenary_uid).get("name", ""))
	if owner_now != PROMPT_OWNER:
		if EventBus.claim_prompt(PROMPT_OWNER, said, PROMPT_OWNER, nearest.global_position):
			EventBus.interact_prompt.emit(said, "TALK")
	var hands := warden.input as HeroInput
	if hands != null and hands.pressed(HeroInput.BUTTON_INTERACT):
		if card.is_open():
			card.hide_card()
		else:
			talk_to(nearest.mercenary_uid)


## Opens the card on one mercenary.
func talk_to(uid: String) -> void:
	if card != null and body(uid) != null:
		card.open_for(uid, mind(uid))


## An order from the card: the mind takes it, and the mercenary says so.
func _on_ordered(uid: String, order: int) -> void:
	var hands: MercenaryInput = mind(uid)
	if hands == null:
		return
	hands.command(order)
	for entry: Array in MercenaryCard.ORDERS:
		if int(entry[0]) == order and voice != null:
			voice.say(uid, String(entry[2]), true)


## **It builds in the breather** (owner, 2026-10-07: mercenaries *"place their own
## towers and traps"*). A moment into Preparation, so the player sees it happen,
## each mercenary on its feet makes a few purchases from its own purse through
## the battlefield's payer doors - every rule a purchase obeys is the Warden's
## rule, only the purse differs.
func _on_phase_changed(phase: int, _previous: int) -> void:
	if phase != RunState.Phase.PREPARATION or field == null or not is_inside_tree():
		return
	await get_tree().create_timer(Balance.MERC_BUILD_DELAY, false).timeout
	if field == null or RunState.phase != RunState.Phase.PREPARATION:
		return
	for row: Dictionary in RunState.live_mercenaries():
		spend(String(row.get("uid", "")))


## One mercenary's shopping: raise its weakest tower, else build a new one on
## its own road, else lay a trap there. Returns what it bought, as words.
func spend(uid: String) -> Array[String]:
	var bought: Array[String] = []
	var me: Hero = body(uid)
	if me == null or field == null or not RunState.can_build_now():
		return bought
	var lane: int = _lane_of(me)
	for _purchase: int in Balance.MERC_BUILDS_PER_BREATHER:
		var raised: Vector2i = _weakest_owned(uid)
		if raised != Vector2i(-1, -1) and field.upgrade_for(uid, raised).is_empty():
			bought.append("raise")
			continue
		var tower: TowerData = _dearest_affordable(uid)
		if tower != null:
			var anchor: Vector2i = field.free_anchor_near(lane, 4)
			if field.placement_problem(anchor).is_empty() and field.build_for(uid, anchor, tower).is_empty():
				bought.append(tower.id)
				if voice != null:
					voice.say(uid, "built")
				EventBus.company_news.emit("%s raises a %s on its road." % [
					String(RunState.company_row(uid).get("name", "")), tower.display_name])
				continue
		var trap: TrapData = _affordable_trap(uid)
		if trap != null and _lay_a_trap(uid, me.global_position, trap):
			bought.append(trap.id)
			continue
		break
	return bought


## The road it stands nearest.
func _lane_of(me: Hero) -> int:
	var best: int = 0
	var best_dot: float = -INF
	var from_town: Vector2 = (me.global_position - field.town_position()).normalized()
	for lane: int in Balance.LANE_COUNT:
		var along: float = from_town.dot(Battlefield.lane_vector(lane).normalized())
		if along > best_dot:
			best_dot = along
			best = lane
	return best


## Its tower at the lowest level that can still rise, or (-1, -1).
func _weakest_owned(uid: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var lowest: int = 1 << 30
	for key: Variant in RunState.tower_owners:
		if String(RunState.tower_owners[key]) != uid:
			continue
		var anchor: Vector2i = key
		var level: int = RunState.level_at(anchor)
		if level < mini(Balance.TOWER_MAX_LEVEL, RunState.tower_level_cap()) and level < lowest:
			if RunState.mercenary_can_afford(uid, {RunState.GOLD: Battlefield.upgrade_cost_of(level)}):
				lowest = level
				best = anchor
	return best


## The dearest tower the Warden has unlocked that its purse pays for at par -
## the strongest answer it can afford, which is how a player with money spends it.
func _dearest_affordable(uid: String) -> TowerData:
	var best: TowerData = null
	var best_price: int = -1
	for tower: TowerData in ContentDB.unlocked_base_towers():
		if tower == null or tower.is_well() or tower.is_support():
			continue
		var cost: Dictionary = Battlefield.cost_of(tower)
		var price: int = RunState.par_total(cost)
		if RunState.mercenary_can_afford(uid, cost) and price > best_price:
			best = tower
			best_price = price
	return best


func _affordable_trap(uid: String) -> TrapData:
	for value: Variant in ContentDB.traps.values():
		var trap := value as TrapData
		if trap != null and RunState.mercenary_can_afford(uid, trap.cost):
			return trap
	return null


## A trap on the road nearest it, tried outward ring by ring.
func _lay_a_trap(uid: String, near: Vector2, trap: TrapData) -> bool:
	var origin: Vector2i = BattleGrid.world_to_tile(near)
	for ring: int in Balance.MERC_TRAP_SEARCH:
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				if field.trap_for(uid, origin + Vector2i(dx, dy), trap).is_empty():
					return true
	return false


## Its last wound: it lies where it fell for a moment, then is carried off the
## road and put to bed at the inn - now, not when the run settles, because it
## has left the road whatever the run does next.
func _on_fell(uid: String, _at: Vector2, wounds_left: int) -> void:
	if wounds_left > 0:
		var name_now: String = String(RunState.company_row(uid).get("name", ""))
		EventBus.company_news.emit("%s is down  ·  %d %s left" % [name_now, wounds_left,
			"wound" if wounds_left == 1 else "wounds"])
		return
	carry_off(uid, Balance.MERC_CARRY_SECONDS)


## Takes a mercenary off the road and to a bed. `after` lets it lie a moment.
func carry_off(uid: String, after: float = 0.0) -> void:
	var gone: Hero = body(uid)
	var name_now: String = String(RunState.company_row(uid).get("name", "A mercenary"))
	if after > 0.0 and is_inside_tree():
		await get_tree().create_timer(after, false).timeout
	gone = body(uid)
	if gone != null:
		gone.set_present(false)
		gone.queue_free()
	_bodies.erase(uid)
	_minds.erase(uid)
	var row: Dictionary = RunState.company_row(uid)
	if not row.is_empty():
		row["out"] = true
	# Its owner's account puts it to bed: this one's, or a guest's, told.
	var master: int = int(row.get("master", 1)) if not row.is_empty() else 1
	if Coop.is_networked() and master != _own_seat():
		EventBus.coop_company_carried.emit(uid, master)
	else:
		MetaState.send_mercenary_to_bed(uid)
	EventBus.company_news.emit("%s is carried back to the Hold, to a bed at the inn." % name_now)
	EventBus.mercenary_carried_off.emit(uid)


# --- Co-op (2026-10-07, stage five) ---------------------------------------------

## **A ping heard by the pinging Warden's own company** (2026-10-07). Only the
## machine that simulates them listens - a guest's puppets decide nothing - and
## only a mercenary whose master made the ping heeds it, through the orders its
## mind already has. One of them says so.
func _on_pinged(seat: int, ping_id: String, at: Vector2) -> void:
	if Coop.is_networked() and Coop.is_guest():
		return
	var data: PingData = ContentDB.ping(ping_id)
	if data == null or data.heed == PingData.Heed.NONE:
		return
	var pinger: Hero = _master_body(seat)
	var answering: String = ""
	var nearest: float = INF
	for uid: Variant in _minds:
		var row: Dictionary = RunState.company_row(String(uid))
		if int(row.get("master", 1)) != seat or bool(row.get("out", false)):
			continue
		var hands: MercenaryInput = _minds[uid] as MercenaryInput
		var me: Hero = body(String(uid))
		if hands == null or me == null or not me.is_alive():
			continue
		if hands.heed(data, at, pinger):
			var d: float = me.global_position.distance_to(at)
			if d < nearest:
				nearest = d
				answering = String(uid)
	if not answering.is_empty() and voice != null:
		voice.say(answering, "heeded", true)


## This machine's seat: 1 alone.
func _own_seat() -> int:
	return Coop.party().slot() if Coop.is_networked() and Coop.party().slot() > 0 else 1


## The Warden a mercenary follows: this machine's own, or the partner it came with.
func _master_body(master: int) -> Hero:
	if master == _own_seat() or field == null:
		return field.hero if field != null else null
	var party: CoopHeroes = field.get_node_or_null("CoopHeroes") as CoopHeroes
	var found: Hero = party.body_for_slot(master) if party != null else null
	return found if found != null else field.hero


## **A guest's company, admitted by the host.** Each record is cleaned by the
## rules a save is read under; a uid already standing is not stood twice; and a
## guest brings at most its share of the free seats, on seats no player and no
## other mercenary holds. Returns how many it stood.
func admit(records: Array, master: int) -> int:
	if field == null:
		return 0
	var share: int = Mercenaries.seats_for(Coop.player_count())
	var brought: int = 0
	var taken: Array[int] = []
	for row: Dictionary in RunState.company:
		taken.append(int(row.get("slot", 0)))
		if int(row.get("master", 1)) == master:
			brought += 1
	if Coop.is_networked():
		for seat: Variant in Coop.party().seats():
			if seat is CoopParty.Seat:
				taken.append((seat as CoopParty.Seat).slot)
	else:
		taken.append(_own_seat())
	var stood: int = 0
	for value: Variant in records:
		var record: Dictionary = Mercenaries.clean(value)
		if record.is_empty() or not RunState.company_row(String(record["uid"])).is_empty():
			continue
		if brought >= share:
			break
		var free: Array[int] = Mercenaries.free_seats(taken)
		if free.is_empty():
			break
		var row: Dictionary = {
			"uid": String(record["uid"]), "name": String(record.get("name", "")),
			"slot": free[0], "master": master, "remote": false, "guest": true,
			"wounds": Balance.MERC_WOUNDS, "purse": 0, "spoils": 0.0, "earned": 0, "out": false,
		}
		RunState.company.append(row)
		taken.append(free[0])
		_records[String(record["uid"])] = record
		if _stand(row) != null:
			stood += 1
			brought += 1
	return stood


func _on_request(kind: int, args: Array, from: int) -> void:
	if kind != CoopRelay.Request.MY_COMPANY or not Coop.is_networked() or Coop.is_guest():
		return
	# By the peer it arrived on, never by a seat named in the packet.
	var master: int = Coop.party().slot_for_peer(from)
	if master <= 0 or args.is_empty() or not (args[0] is Array):
		return
	admit(args[0] as Array, master)


## A guest restates its company until it sees it standing - a request sent once
## lands on nothing when the host's field is a frame behind.
func _tell_the_host_my_company(delta: float) -> void:
	var mine: Array = []
	for row: Dictionary in RunState.company:
		if bool(row.get("remote", false)) and not bool(row.get("out", false)) and not _seen(String(row["uid"])):
			var record: Dictionary = MetaState.mercenary(String(row["uid"]))
			if not record.is_empty():
				mine.append(record)
	if mine.is_empty():
		return
	_restate_left -= delta
	if _restate_left > 0.0:
		return
	_restate_left = Balance.MERC_RESTATE_SECONDS
	var relay: CoopRelay = Coop.relay()
	if relay != null:
		relay.request(CoopRelay.Request.MY_COMPANY, [mine])


func _seen(uid: String) -> bool:
	for slot: Variant in _puppets:
		var puppet: Hero = _puppets[slot] as Hero
		if puppet != null and is_instance_valid(puppet) and puppet.mercenary_uid == uid:
			return true
	return false


## The host tells the party where the company is, ten times a second, and once
## more when there is nobody left to tell about.
func _send_company_state(delta: float) -> void:
	_state_left -= delta
	if _state_left > 0.0:
		return
	_state_left = Balance.MERC_STATE_SECONDS
	var rows: Array = []
	for row: Dictionary in RunState.company:
		var found: Hero = body(String(row.get("uid", "")))
		if found == null:
			continue
		var hands := found.input as MercenaryInput
		var hurt: float = found.health.current_hp / maxf(found.health.max_hp, 1.0) if found.health != null else 1.0
		rows.append([int(row.get("slot", 0)), int(row.get("master", 1)), String(row.get("uid", "")),
			String(row.get("name", "")), found.global_position, hurt,
			hands.move() if hands != null else Vector2.ZERO,
			found.aim_direction(), WardenLook.pack(found.look), found.gear_kinds.duplicate(),
			int(row.get("wounds", 0))])
	if rows.is_empty() and _told_empty:
		return
	_told_empty = rows.is_empty()
	EventBus.coop_company_state.emit(rows)


## **A guest draws the company** the host simulates: a puppet a seat, moved by
## the host's word, dressed as it is, named, and gone when the host stops naming
## it. A puppet decides nothing - no mind, no swing, no wound.
func _on_company_state(rows: Array) -> void:
	if not Coop.is_networked() or not Coop.is_guest():
		return
	apply_state(rows)


## The puppets, set from rows. A documented seam: a gate drives it with no wire.
func apply_state(rows: Array) -> void:
	var named: Dictionary = {}
	for entry: Variant in rows:
		var row := entry as Array
		if row == null or row.size() < 11:
			continue
		var slot: int = clampi(int(row[0]), 1, Balance.COOP_MAX_PLAYERS)
		named[slot] = true
		var puppet: Hero = _puppet(slot, String(row[2]), String(row[3]))
		if puppet == null:
			continue
		puppet.global_position = puppet.global_position.lerp(row[4] as Vector2, Balance.COOP_POSITION_CORRECTION)
		if puppet.health != null:
			puppet.health.current_hp = clampf(float(row[5]), 0.0, 1.0) * puppet.health.max_hp
		puppet.visible = float(row[5]) > 0.0
		var hands := puppet.input as RemoteHeroInput
		if hands != null:
			hands.apply([row[6] as Vector2, row[7] as Vector2, 0, 0])
		if row[8] is Array:
			puppet.wear_look(row[8])
		if row[9] is Array:
			puppet.wear_gear(row[9])
	for slot: Variant in _puppets.keys():
		if not named.has(slot):
			var gone: Hero = _puppets[slot] as Hero
			if gone != null and is_instance_valid(gone):
				gone.set_present(false)
				gone.queue_free()
			_puppets.erase(slot)


## A puppet on a seat, built the first time it is named.
func _puppet(slot: int, uid: String, speaker: String) -> Hero:
	var known: Hero = _puppets.get(slot, null) as Hero
	if known != null and is_instance_valid(known):
		return known
	if field == null or field.entity_root == null:
		return null
	var scene: PackedScene = load("res://scenes/hero/hero.tscn") as PackedScene
	var hero := scene.instantiate() as Hero if scene != null else null
	if hero == null:
		return null
	hero.input = RemoteHeroInput.new(hero)
	hero.mercenary_uid = uid
	hero.name = "MercenaryPuppet%d" % slot
	hero.field = field
	hero.party_slot = slot
	hero.bounds_extent = Vector2.ONE * BattleGrid.play_extent()
	hero.position = CoopHeroes.spawn_for_slot(slot, field.town_position())
	field.entity_root.add_child(hero)
	hero.set_present(true)
	hero.set_active(false)
	hero.set_nameplate(speaker)
	_puppets[slot] = hero
	return hero


## Who a standing mercenary is, as admitted.
func record(uid: String) -> Dictionary:
	return _records.get(uid, {}) as Dictionary


## The puppet on a seat, or null. For the gate.
func puppet(slot: int) -> Hero:
	var found: Hero = _puppets.get(slot, null) as Hero
	return found if found != null and is_instance_valid(found) else null


## A mercenary of this account's was carried off on the host's road: it goes to
## bed here, in the account it belongs to.
func _on_company_carried(uid: String, master: int) -> void:
	if not Coop.is_networked() or not Coop.is_guest() or master != _own_seat():
		return
	var row: Dictionary = RunState.company_row(uid)
	if not row.is_empty():
		row["out"] = true
	MetaState.send_mercenary_to_bed(uid)
	EventBus.company_news.emit("%s is carried back to the Hold, to a bed at the inn."
		% String(MetaState.mercenary(uid).get("name", "A mercenary")))


## A line a mercenary said on the host's road, drawn over its puppet here.
func _on_company_said(slot: int, text: String, alert: bool) -> void:
	if not Coop.is_networked() or not Coop.is_guest():
		return
	var found: Hero = puppet(slot)
	if found != null:
		SpeechBubble.say(found, text, alert)
		EventBus.mercenary_said.emit(found.mercenary_uid, found.name, text, alert)
