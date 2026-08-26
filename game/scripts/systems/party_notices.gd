class_name PartyNotices
extends Node

## Turns things that happen into sentences the party can read.
##
## **Written locally on every machine, from facts every machine already has.**
## Sending the sentence over the wire would be sending the same event twice, and
## two machines describing one event differently is worse than either
## description. The relay already guarantees everybody saw the fact; this only
## decides how to say it.
##
## ### Who gets the credit
##
## Spending is attributed to whoever asked for it. On the host that is known
## exactly - a build request arrives on a peer and the peer maps to a seat. On a
## guest it is not knowable at all, because the host announces *that* a tower
## appeared and not *who* paid, so those lines are attributed to the party rather
## than guessed. A wrong name on a receipt is worse than no name.

## Seat 0 means "the party", drawn in the neutral colour rather than anybody's.
const PARTY: int = 0

## Spending below this is not worth a line. A trap costing eight Wood every few
## seconds would bury the feed under its own bookkeeping. [TUNE]
const NOTABLE_SPEND: int = 20

var _last_currency: Dictionary = {}


func _ready() -> void:
	EventBus.tower_changed.connect(_on_tower)
	EventBus.construction_completed.connect(_on_construction)
	EventBus.trap_changed.connect(_on_trap)
	EventBus.barricade_changed.connect(_on_barricade)
	EventBus.wave_cleared.connect(_on_wave)
	EventBus.boss_defeated.connect(_on_boss)
	EventBus.coop_hero_down.connect(_on_down)
	EventBus.coop_hero_revived.connect(_on_revived)
	EventBus.coop_partner_joined.connect(_on_joined)
	EventBus.coop_partner_left.connect(_on_left)
	EventBus.act_started.connect(_on_act)
	EventBus.currency_changed.connect(_on_currency)


## Who is answerable for the thing being built right now.
##
## The host knows, because a request arrives on a peer. Everybody else is
## guessing, and a receipt with the wrong name on it is worse than one with no
## name - so a guest says "the party" and means it.
func _blame() -> int:
	if not Coop.is_networked():
		return Coop.party().slot()
	return Coop.acting_slot if Coop.acting_slot > 0 else PARTY


func _say(slot: int, text: String) -> void:
	EventBus.party_notice.emit(slot, text)


func _who(slot: int) -> String:
	if slot <= 0:
		return "The party"
	var seat: CoopParty.Seat = Coop.party().seat_for_slot(slot)
	if seat == null:
		return Balance.PARTY_COLOUR_NAMES[clampi(slot - 1, 0, 3)]
	return seat.name


# --- Building ----------------------------------------------------------------

func _on_tower(anchor: Vector2i) -> void:
	var data: TowerData = RunState.tower_at(anchor)
	if data == null:
		_say(_blame(), "%s sold a tower." % _who(_blame()))
		return
	var level: int = RunState.level_at(anchor)
	if level > 1:
		_say(_blame(), "%s upgraded %s to level %d."
			% [_who(_blame()), data.display_name, level])
	else:
		_say(_blame(), "%s built %s." % [_who(_blame()), data.display_name])


func _on_construction(building_id: String, tier: int) -> void:
	var data: BuildingData = ContentDB.building(building_id)
	var name: String = data.display_name if data != null else building_id
	_say(PARTY, "%s finished, tier %d." % [name, tier])


func _on_trap(tile: Vector2i) -> void:
	var data: TrapData = RunState.trap_at(tile)
	if data != null:
		_say(_blame(), "%s laid %s." % [_who(_blame()), data.display_name])


func _on_barricade(tile: Vector2i) -> void:
	var data: BarricadeData = RunState.barricade_at(tile)
	if data != null:
		_say(_blame(), "%s raised %s." % [_who(_blame()), data.display_name])


# --- The run -----------------------------------------------------------------

func _on_wave(wave_number: int) -> void:
	_say(PARTY, "Wave %d cleared." % wave_number)


func _on_boss(boss_id: String, act: int) -> void:
	var data: EnemyData = ContentDB.enemy(boss_id)
	_say(PARTY, "%s is down. Act %d is over."
		% [data.display_name if data != null else "The boss", act])


func _on_act(act: int, terrain_id: String) -> void:
	var terrain: TerrainData = ContentDB.terrain(terrain_id)
	_say(PARTY, "Act %d - %s."
		% [act, terrain.display_name if terrain != null else terrain_id])


func _on_down(slot: int, _at: Vector2) -> void:
	_say(slot, "%s is down." % _who(slot))


func _on_revived(slot: int, _at: Vector2) -> void:
	_say(slot, "%s is back up." % _who(slot))


func _on_joined(peer_id: int) -> void:
	var slot: int = Coop.party().slot_for_peer(peer_id)
	_say(slot, "%s joined the party." % _who(slot))


func _on_left(peer_id: int) -> void:
	var slot: int = Coop.party().slot_for_peer(peer_id)
	_say(slot, "%s left the party." % _who(slot))


# --- Spending ----------------------------------------------------------------

## A purse going *down* is somebody buying something.
##
## Watched here rather than announced at each call site, because there are a
## dozen of those and they would each have to remember. Only drops are reported
## and only sizeable ones: income arrives constantly and a feed that narrated it
## would be unreadable.
func _on_currency(currency_id: String, amount: int) -> void:
	var before: int = int(_last_currency.get(currency_id, amount))
	_last_currency[currency_id] = amount
	var spent: int = before - amount
	if spent < NOTABLE_SPEND:
		return
	# Building already says what it bought, in a better sentence than this one
	# could. This is for everything else that quietly drains a shared purse.
	if RunState.can_build_now():
		return
	_say(_blame(), "%s spent %d %s."
		% [_who(_blame()), spent, RunState.currency_name(currency_id)])
