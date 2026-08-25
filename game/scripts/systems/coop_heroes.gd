class_name CoopHeroes
extends Node

## The second hero: when it exists, who drives it, and what it is told.
##
## Step 3 of `docs/COOP_DESIGN.md`. Two players, one city, and both of them
## fight — the owner's ruling on 2026-08-24.
##
## The partner's hero is an ordinary `hero.tscn` with a `RemoteHeroInput` instead
## of a local one. That is the whole of the difference. It walks, swings, dashes,
## is knocked about by the beast's step and dies through exactly the same code as
## the hero standing next to it, because a second implementation is a second
## place for bugs to live and only one of the two would ever be play-tested.
##
## **Who is authoritative.** The host simulates. On the guest this hero is a
## picture of something happening on another machine, corrected whenever a state
## packet lands. The guest's *own* hero keeps simulating locally between packets
## rather than freezing until the next one — that is naive prediction, it will
## visibly correct under latency, and `docs/COOP_DESIGN.md` §2 already says
## proper prediction is a later refinement. A hero that only moves when a packet
## arrives is worse than one that occasionally snaps.
##
## Nothing here runs in a single-player game. `partner()` is null, no packets are
## sent, and the cost is one early return per physics frame.

## How often a hero's position is put on the wire, in seconds. [TUNE]
##
## Every physics frame would be 60 packets a second per hero to describe
## something that moves smoothly and predictably. This is the knob to turn if
## co-op ever looks jittery; it is not the knob to turn if it looks *wrong*.
const STATE_INTERVAL: float = 0.05

## The battlefield that owns the heroes. Assigned on creation.
var field: Node = null

var _partner: Hero = null
var _remote: RemoteHeroInput = null
var _state_timer: float = 0.0

## Where a partner hero appears if nothing better is known. Beside the town,
## which is the one place on the map guaranteed to be walkable.
const SPAWN_OFFSET: Vector2 = Vector2(90.0, 0.0)


func _ready() -> void:
	EventBus.coop_partner_joined.connect(_on_partner_joined)
	EventBus.coop_partner_left.connect(_on_partner_left)
	EventBus.coop_request_received.connect(_on_request)
	EventBus.coop_state_changed.connect(_on_session_changed)
	EventBus.coop_hero_state.connect(_on_hero_state)

	# **The partner may already be here.**
	#
	# Both of the signals above fire while the players are still in the *menu* -
	# the host gets `coop_partner_joined` when the peer connects, the guest gets
	# CONNECTED at the same moment - and this system is built by
	# `Battlefield._ready()`, which happens long afterwards. Listening alone
	# therefore missed the only announcement that was ever going to come.
	#
	# The cost was the whole of co-op looking broken from a player's seat: no
	# partner hero on either screen, so neither could see the other, and on the
	# host no `_remote` to feed, so the guest's input went nowhere and its hero
	# was corrected back to its spawn on every state packet - "the guest cannot
	# move". One missing line, two symptoms, and both of them the first thing
	# anybody would notice.
	#
	# Asking rather than waiting is also simply more robust: a scope rebuilt
	# mid-session - a raid, a return to the battlefield - gets its partner back
	# without depending on an event that has already gone by.
	if Coop.partner_present():
		spawn_partner()


## The partner's hero, or null when playing alone.
func partner() -> Hero:
	return _partner


## True when a second hero is on the field.
func has_partner() -> bool:
	return _partner != null and is_instance_valid(_partner)


# --- Appearing and leaving ---------------------------------------------------

func _on_partner_joined(_peer_id: int) -> void:
	spawn_partner()


func _on_partner_left(_peer_id: int) -> void:
	despawn_partner()


## A guest that has just connected has a partner too — the host.
##
## `coop_partner_joined` is the *host's* view of an arrival. The guest learns the
## same fact by reaching CONNECTED, and without this the second hero would appear
## on one machine and not the other.
func _on_session_changed(state: int) -> void:
	if state == Coop.State.CONNECTED:
		spawn_partner()
	elif state == Coop.State.OFFLINE or state == Coop.State.FAILED:
		despawn_partner()


## Puts the partner's hero on the field. Safe to call twice.
func spawn_partner() -> Hero:
	if has_partner():
		return _partner
	if field == null or not (field is Battlefield):
		return null
	var battlefield := field as Battlefield
	var scene: PackedScene = load("res://scenes/hero/hero.tscn") as PackedScene
	if scene == null or battlefield.entity_root == null:
		return null

	var hero := scene.instantiate() as Hero
	if hero == null:
		return null
	_remote = RemoteHeroInput.new(hero)
	# Assigned before the node enters the tree, so `Hero._ready` finds a source
	# already present and does not build a local one first. A partner hero that
	# reads this machine's keyboard for even one frame is a partner hero that
	# twitches whenever its owner walks.
	hero.input = _remote
	hero.name = "PartnerHero"
	hero.field = battlefield
	hero.bounds_extent = Vector2.ONE * (BattleGrid.HALF_EXTENT - BattleGrid.TILE)
	hero.position = battlefield.town_position() + SPAWN_OFFSET
	battlefield.entity_root.add_child(hero)
	# Never claims the hero group. That group answers "which hero does the HUD,
	# the camera and the damage vignette follow", and the answer is always the
	# one this player is driving — see `Hero.set_active` for the raid version of
	# the same problem.
	hero.set_active(false)
	_partner = hero
	return hero


## Takes the partner's hero off the field.
func despawn_partner() -> void:
	if _remote != null:
		# Cleared before the node goes, so nothing is left holding a direction.
		# A remote hero still carrying its last move vector walks into a wall
		# forever, which is exactly what a hidden touch stick used to do.
		_remote.clear()
	_remote = null
	if _partner != null and is_instance_valid(_partner):
		_partner.queue_free()
	_partner = null


# --- Each frame --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not Coop.is_networked():
		return
	if _remote != null:
		_remote.tick(delta)

	var relay: CoopRelay = Coop.relay()
	if relay == null:
		return

	if Coop.is_guest():
		_send_input(relay)
	else:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_state_timer = STATE_INTERVAL
			_send_state()


## The guest tells the host what its player is asking for — never what happened.
##
## Input rather than outcome, and that distinction is the authority model in one
## line. A guest that sent its position would be informing the host of a fact,
## and the host would have no way to refuse it.
func _send_input(relay: CoopRelay) -> void:
	var mine: Hero = _local_hero()
	if mine == null:
		return
	var source := mine.input as LocalHeroInput
	if source == null:
		return
	relay.request(CoopRelay.Request.HERO_INPUT, source.snapshot(mine.aim_direction()))


## The host tells the guest where both heroes actually are.
##
## Emitted on this machine's own bus rather than pushed at the relay. The relay
## is already subscribed and forwards it like any other fact, so hero positions
## need no send path of their own - and the authority guard covers them for free.
## A guest that tried to author a position would be caught by the same check that
## catches one inventing a kill.
func _send_state() -> void:
	var mine: Hero = _local_hero()
	if mine == null:
		return
	var partner_at: Vector2 = _partner.global_position if has_partner() else Vector2.ZERO
	var partner_aim: Vector2 = _partner.aim_direction() if has_partner() else Vector2.ZERO
	EventBus.coop_hero_state.emit(mine.global_position, mine.aim_direction(),
		partner_at, partner_aim)


## Applies a state packet. Guest side.
##
## The two heroes swap roles across the wire: the host's own hero is the guest's
## *partner*, and the host's partner is the guest looking at itself. Getting this
## backwards would have each player watching the other's body wearing their name.
##
## The guest's own hero has its position corrected but not its aim: aim is the
## one thing a player feels immediately, and taking it from a packet arriving
## twenty times a second would make their own cursor lag. The host still decides
## what that aim *did*.
func _on_hero_state(host_at: Vector2, host_aim: Vector2,
		guest_at: Vector2, _guest_aim: Vector2) -> void:
	if not Coop.is_guest():
		return
	if has_partner():
		_partner.global_position = host_at
		_partner.face(host_aim)
	var mine: Hero = _local_hero()
	if mine != null:
		mine.global_position = guest_at


func _on_request(kind: int, args: Array, _from: int) -> void:
	if kind != CoopRelay.Request.HERO_INPUT or not Coop.is_host():
		return
	if _remote != null:
		_remote.apply(args)


func _local_hero() -> Hero:
	if field == null or not (field is Battlefield):
		return null
	return (field as Battlefield).hero
