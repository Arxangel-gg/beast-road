class_name PingField
extends Node2D

## **The party's pings** (triage of 2026-10-07, item 63): eight words a Warden
## can put on the field - here, attack this, hold this, loot, fall back, help,
## on my way, danger - each a glyph standing over the point, a line in the
## party's feed, a chime, a mark on the map and an arrow at the edge of the
## screen while it is off it.
##
## **Relayed as facts.** The host (or a Warden alone) says `EventBus.pinged`;
## the relay carries it to everybody as `Fact.PING`, and every machine draws
## from that one signal, so four screens agree about every mark. A guest asks
## with `Request.PING` - an id and a point - and the host names the seat from
## the peer it arrived on, never from the packet, and holds each seat to the
## same burst a Warden is held to at home.
##
## **A ping moves nothing in a fight.** It is a person speaking. The one thing
## that answers it is the pinging Warden's own company, which heeds it through
## the orders the mercenary AI already has (`MercenaryCompany.heed`).
##
## A tap of the key pings whatever is under the cursor - a body, a tower, a drop
## or the ground; a hold opens the wheel. Alt and a click pings at once. On a
## thumb, holding the Say square opens the same wheel at the Warden's feet.

var field: Battlefield = null
var wheel: PingWheel = null
## The clock a gate may replace, in milliseconds.
var now_msec: Callable = func() -> int: return Time.get_ticks_msec()

var _layer: CanvasLayer = null
var _times: Array[int] = []
var _seat_times: Dictionary = {}
var _held_since: int = -1
var _held_screen: Vector2 = Vector2.ZERO
var _held_world: Vector2 = Vector2.ZERO
var _held_quick: bool = true


func _ready() -> void:
	z_as_relative = false
	z_index = 45
	EventBus.pinged.connect(_on_pinged)
	EventBus.coop_request_received.connect(_on_request)
	_layer = CanvasLayer.new()
	_layer.layer = 24
	add_child(_layer)
	wheel = PingWheel.new()
	_layer.add_child(wheel)


## Every mark still standing, oldest first.
func marks() -> Array[PingMark]:
	var out: Array[PingMark] = []
	for child: Node in get_children():
		var mark := child as PingMark
		if mark != null and not mark.is_queued_for_deletion():
			out.append(mark)
	return out


# --- Asking -----------------------------------------------------------------

## A ping this machine's own Warden makes. Returns whether it was sent - a
## guest's is answered later by the host, as everything a guest asks for is.
func ask(ping_id: String, at: Vector2) -> bool:
	if ContentDB.ping(ping_id) == null or not at.is_finite():
		return false
	if not _may_burst(_times):
		EventBus.party_notice.emit(_own_seat(), "Wait a moment - your party is still looking.")
		return false
	var point: Vector2 = _clamped(at)
	if Coop.is_networked() and Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		return relay != null and relay.request(CoopRelay.Request.PING, [ping_id, point])
	EventBus.pinged.emit(_own_seat(), ping_id, point)
	return true


## **A guest's ping, admitted by the host**: the seat the peer holds, a ping
## that exists, a point that is a point - pulled inside the field - and inside
## that seat's own burst. Returns whether it was said.
func admit(seat: int, args: Array) -> bool:
	if seat <= 0 or args.size() != 2 or not (args[1] is Vector2):
		return false
	var ping_id: String = String(args[0])
	var at: Vector2 = args[1] as Vector2
	if ContentDB.ping(ping_id) == null or not at.is_finite():
		return false
	if not _seat_times.has(seat):
		_seat_times[seat] = [] as Array[int]
	var times: Array[int] = _seat_times[seat] as Array[int]
	if not _may_burst(times):
		return false
	EventBus.pinged.emit(seat, ping_id, _clamped(at))
	return true


func _on_request(kind: int, args: Array, from: int) -> void:
	if kind != CoopRelay.Request.PING or not Coop.is_networked() or Coop.is_guest():
		return
	admit(Coop.party().slot_for_peer(from), args)


## **What a quick ping over `at` is about**: the body nearest it, else a tower,
## else something on the ground worth taking, else the ground itself.
func quick_ping_at(at: Vector2) -> String:
	var want: int = PingData.Context.GROUND
	if _body_near(at) != null:
		want = PingData.Context.BODY
	elif _tower_near(at) != null:
		want = PingData.Context.TOWER
	elif _drop_near(at) != null:
		want = PingData.Context.LOOT
	for data: PingData in ContentDB.ping_list():
		if data.context == want:
			return data.id
	return "here"


func _body_near(at: Vector2) -> Enemy:
	if field == null:
		return null
	var best: Enemy = null
	var best_d: float = INF
	for body: Enemy in field.enemies_near(at, Balance.PING_PICK_RADIUS):
		if body == null or body.is_dying():
			continue
		var d: float = at.distance_squared_to(body.global_position)
		if d < best_d:
			best_d = d
			best = body
	return best


func _tower_near(at: Vector2) -> Tower:
	if field == null:
		return null
	for tower: Tower in field.all_towers():
		if tower != null and is_instance_valid(tower) \
				and tower.global_position.distance_to(at) <= Balance.PING_PICK_RADIUS:
			return tower
	return null


func _drop_near(at: Vector2) -> Node2D:
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as Node2D
		if drop != null and drop.visible and (field == null or field.is_ancestor_of(drop)) \
				and drop.global_position.distance_to(at) <= Balance.PING_PICK_RADIUS:
			return drop
	return null


# --- Drawing ----------------------------------------------------------------

func _on_pinged(seat: int, ping_id: String, at: Vector2) -> void:
	var data: PingData = ContentDB.ping(ping_id)
	if data == null:
		return
	# The oldest of this seat's goes, so one Warden cannot carpet the field.
	var own: Array[PingMark] = []
	for mark: PingMark in marks():
		if mark.seat == seat:
			own.append(mark)
	while own.size() >= Balance.PING_LIVE_PER_SEAT:
		var oldest: PingMark = own.pop_front()
		remove_child(oldest)
		oldest.queue_free()
	var who: String = PartyLog.speaker_name(seat)
	var mark := PingMark.new()
	mark.setup(data, seat, who)
	add_child(mark)
	mark.global_position = at
	Sfx.play_group("sfx_ping_alert" if data.alert else "sfx_ping")
	EventBus.party_notice.emit(seat, data.line.replace("{who}", who))


# --- The key, the click and the thumb -----------------------------------------

func _may_ping() -> bool:
	return GameDirector.run_active and is_visible_in_tree() \
		and (field == null or field.is_visible_in_tree())


func _unhandled_input(event: InputEvent) -> void:
	if not _may_ping():
		return
	if event.is_action_pressed(&"ping") and not event.is_echo():
		begin_hold(get_viewport().get_mouse_position(), get_global_mouse_position(), true)
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"ping") and _held_since >= 0:
		release_hold()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_RIGHT and wheel.is_open():
			cancel_hold()
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_LEFT and button.alt_pressed:
			var at: Vector2 = get_global_mouse_position()
			ask(quick_ping_at(at), at)
			get_viewport().set_input_as_handled()


## The key (or the thumb) goes down at a point on the screen over a point on the
## field. With `quick`, letting go before the wheel opens pings what is there;
## without it - the touch square - only the wheel sends.
func begin_hold(screen_at: Vector2, world_at: Vector2, quick: bool) -> void:
	_held_since = int(now_msec.call())
	_held_screen = screen_at
	_held_world = world_at
	_held_quick = quick
	if not quick:
		wheel.open(screen_at)


func holding() -> bool:
	return _held_since >= 0


## Letting go: the wheel's spoke if it is open, the quick ping if it is not.
## Returns the ping sent, or "".
func release_hold() -> String:
	if _held_since < 0:
		return ""
	_held_since = -1
	var ping_id: String = ""
	if wheel.is_open():
		ping_id = wheel.chosen()
		wheel.close()
	elif _held_quick:
		ping_id = quick_ping_at(_held_world)
	if ping_id.is_empty():
		return ""
	return ping_id if ask(ping_id, _held_world) else ""


func cancel_hold() -> void:
	_held_since = -1
	wheel.close()


func _process(_delta: float) -> void:
	if _held_since >= 0 and not wheel.is_open() \
			and int(now_msec.call()) - _held_since >= int(Balance.PING_WHEEL_HOLD * 1000.0):
		wheel.open(_held_screen)


# --- Rules -------------------------------------------------------------------

## `PING_BURST` inside `PING_BURST_SECONDS`, then refused: a party of four
## carpeting the field is a party reading nothing.
func _may_burst(times: Array[int]) -> bool:
	var now: int = int(now_msec.call())
	var window: int = int(Balance.PING_BURST_SECONDS * 1000.0)
	while not times.is_empty() and now - times[0] > window:
		times.pop_front()
	if times.size() >= Balance.PING_BURST:
		return false
	times.append(now)
	return true


func _clamped(at: Vector2) -> Vector2:
	var reach: float = BattleGrid.play_extent()
	return Vector2(clampf(at.x, -reach, reach), clampf(at.y, -reach, reach))


func _own_seat() -> int:
	return Coop.party().slot() if Coop.is_networked() and Coop.party().slot() > 0 else 1
