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

## Everybody else's body, by seat. This machine's own hero is not in here - it
## is the battlefield's, and it is driven by hands rather than by packets.
##
## **Keyed on slot rather than on "partner"**, because with four players there is
## no such thing as *the* partner. A slot is a seat at the table: stable, agreed
## by everyone, and the same number that picks a colour and a spawn point.
var _bodies: Dictionary = {}
var _inputs: Dictionary = {}
var _state_timer: float = 0.0

## What was true last frame, so a death or a revival can be spotted as a change
## rather than as a signal that cannot say whose it was.
## Who was standing last frame, by slot, so a change can be spotted and told.
var _was_alive: Dictionary = {}

## Whether the current wipe has already been announced, so it is charged once.
var _wipe_announced: bool = false

## Where each player stands when they arrive, and where they come back to.
##
## **By role, not by machine.** The host's hero uses the same spot on both
## screens and so does the guest's, or the two would disagree about who is
## standing where every time anybody respawned.
##
## Far enough apart that two bodies of radius 26 cannot arrive inside one
## another: a wipe used to put both players on exactly `Vector2.ZERO` and they
## came back stuck to each other, which is what "locked at origin" was.
## Where each seat stands when it arrives, and comes back to.
##
## **A ring, one point per seat**, and far enough apart that four bodies of
## radius 26 cannot arrive inside one another. A wipe used to put both players on
## exactly `Vector2.ZERO` and they came back stuck to each other; with four that
## would be worse, not merely twice as bad.
##
## By slot, so the same player stands in the same place on every screen.
const SPAWN_RING: Array[Vector2] = [
	Vector2(-95.0, 30.0),
	Vector2(95.0, -30.0),
	Vector2(-45.0, -85.0),
	Vector2(45.0, 85.0),
]


## The spot a seat comes back to, in world space.
static func spawn_for_slot(number: int, town: Vector2) -> Vector2:
	return town + SPAWN_RING[clampi(number - 1, 0, SPAWN_RING.size() - 1)]


func _ready() -> void:
	EventBus.coop_partner_joined.connect(_on_partner_joined)
	# The roster is the truth about who is here, and it arrives after the
	# connection does. Without this a guest keeps whatever it guessed.
	Coop.party().roster_changed.connect(func() -> void: spawn_partner())
	EventBus.coop_partner_left.connect(_on_partner_left)
	EventBus.coop_request_received.connect(_on_request)
	EventBus.coop_state_changed.connect(_on_session_changed)
	EventBus.coop_hero_state.connect(_on_hero_state)
	EventBus.coop_host_input.connect(_on_host_input)
	EventBus.coop_hero_down.connect(_on_hero_down)
	EventBus.coop_hero_revived.connect(_on_hero_revived)
	EventBus.coop_team_wipe.connect(_on_team_wipe)
	EventBus.coop_revive_progress.connect(_on_revive_progress)

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


## Gives this machine's own hero the spot that belongs to its role.
##
## Called when a partner appears rather than at start-up, because until then
## there is nobody to collide with and the origin is the right answer - and a
## lone player nudged off-centre for no visible reason is a change nobody asked
## for.
func _claim_local_spawn(battlefield: Battlefield) -> void:
	if battlefield.hero == null:
		return
	var number: int = Coop.party().slot()
	if number <= 0:
		return
	battlefield.hero.party_slot = number
	battlefield.hero.spawn_point = spawn_for_slot(number,
		battlefield.town_position())


## One other player's body, by seat, or null.
func body_for_slot(number: int) -> Hero:
	var who: Hero = _bodies.get(number, null) as Hero
	return who if who != null and is_instance_valid(who) else null


## The first other player's body. **Legacy, and only for callers that genuinely
## mean "somebody else"** - a camera hint, a gate that needs any second hero.
## Anything that means a specific player must ask for a slot.
func partner() -> Hero:
	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		var who: Hero = body_for_slot(number)
		if who != null:
			return who
	return null


## True when anybody else's hero is on the field.
func has_partner() -> bool:
	return partner() != null


## Every hero in the party, this machine's own first.
func party_heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	var mine: Hero = _local_hero()
	if mine != null:
		out.append(mine)
	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		var who: Hero = body_for_slot(number)
		if who != null:
			out.append(who)
	return out


# --- Appearing and leaving ---------------------------------------------------

func _on_partner_joined(_peer_id: int) -> void:
	spawn_partner()


func _on_partner_left(_peer_id: int) -> void:
	# **Only the seat that emptied.** Tearing down every body because one player
	# left is what a two-player implementation gets away with and a four-player
	# one must not.
	_prune_bodies()


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


## Gives every other seat in the party a body. Safe to call as often as liked.
##
## Named `spawn_partner` still because a good deal of the game and several gates
## call it, and it does the same job: make sure everybody who is here has
## somewhere to stand. It returns the first one for the same reason.
func spawn_partner() -> Hero:
	# **Nobody has said who is here yet.**
	#
	# A guest reaches CONNECTED before the host's roster lands, and a body that
	# waits for it is a player staring at an empty field for a packet or two -
	# or forever, if nothing re-runs this. So the old two-player assumption
	# stands in until better information arrives: one other player, seat two.
	# `roster_changed` calls this again the moment the truth is known, and the
	# extra seats appear then.
	# **Only when there is no session at all.**
	#
	# A single-process harness has no roster and genuinely wants the classic
	# second hero. A *networked* guest that has not been seated yet must wait:
	# guessing there gave every guest seat one, its own colour, and a body on top
	# of the host's. The host repeats the roster twice a second, so the wait is
	# measured in frames.
	if not Coop.is_networked():
		return _ensure_body(2)
	if Coop.party().slot() <= 0 or Coop.party().seats().is_empty():
		return partner()
	var made: Hero = null
	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		if number == Coop.party().slot():
			continue
		if Coop.party().seat_for_slot(number) == null:
			continue
		var body: Hero = _ensure_body(number)
		if made == null:
			made = body
	_prune_bodies()
	return made if made != null else partner()


## One seat's body, built if it is not already there.
func _ensure_body(number: int) -> Hero:
	var existing: Hero = body_for_slot(number)
	if existing != null:
		return existing
	if field == null or not (field is Battlefield):
		return null
	var battlefield := field as Battlefield
	var scene: PackedScene = load("res://scenes/hero/hero.tscn") as PackedScene
	if scene == null or battlefield.entity_root == null:
		return null

	var hero := scene.instantiate() as Hero
	if hero == null:
		return null
	var driver := RemoteHeroInput.new(hero)
	# Assigned before the node enters the tree, so `Hero._ready` finds a source
	# already present and does not build a local one first. A remote hero that
	# reads this machine's keyboard for even one frame is a hero that twitches
	# whenever the local player walks.
	hero.input = driver
	hero.name = "PartyHero%d" % number
	hero.field = battlefield
	hero.party_slot = number
	hero.bounds_extent = Vector2.ONE * (BattleGrid.HALF_EXTENT - BattleGrid.TILE)
	hero.spawn_point = spawn_for_slot(number, battlefield.town_position())
	hero.position = hero.spawn_point
	battlefield.entity_root.add_child(hero)
	_claim_local_spawn(battlefield)
	# Never claims the hero group. That group answers "which hero does the HUD,
	# the camera and the damage vignette follow", and the answer is always the
	# one this player is driving — see `Hero.set_active` for the raid version of
	# the same problem.
	hero.set_active(false)
	_bodies[number] = hero
	_inputs[number] = driver
	_was_alive[number] = true
	return hero


## Removes bodies for seats nobody occupies any more.
func _prune_bodies() -> void:
	for key: Variant in _bodies.keys():
		var number: int = int(key)
		if number != Coop.party().slot() 				and Coop.party().seat_for_slot(number) != null:
			continue
		_drop_body(number)


func _drop_body(number: int) -> void:
	var driver: RemoteHeroInput = _inputs.get(number, null) as RemoteHeroInput
	if driver != null:
		# Cleared before the node goes, so nothing is left holding a direction.
		# A remote hero still carrying its last move vector walks into a wall
		# forever, which is exactly what a hidden touch stick used to do.
		driver.clear()
	_inputs.erase(number)
	var body: Hero = _bodies.get(number, null) as Hero
	if body != null and is_instance_valid(body):
		body.queue_free()
	_bodies.erase(number)
	_was_alive.erase(number)


## Takes every other player's hero off the field. For leaving a session.
func despawn_partner() -> void:
	for key: Variant in _bodies.keys():
		_drop_body(int(key))


# --- Each frame --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not Coop.is_networked():
		return
	for driver: Variant in _inputs.values():
		(driver as RemoteHeroInput).tick(delta)

	var relay: CoopRelay = Coop.relay()
	if relay == null:
		return

	_watch_deaths()
	_tick_revives(delta)
	if Coop.is_guest():
		_send_input(relay)
	else:
		# The host sends its input too, not only its position. A mirrored hero
		# with no input has no velocity, and every animation in this game is
		# chosen from velocity and state - which is why the guest's partner slid
		# about with no walk cycle and never swung.
		_send_host_input()
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


## Watches both heroes so a death crosses the wire.
##
## Polled rather than hooked to `hero_died`, because that signal is emitted by
## whichever hero died on *this* machine and carries no way to say which of the
## two it was - and the two swap roles across the wire. Comparing against what
## was true last frame answers "whose, and which way" without either hero
## needing to know a network exists.
func _watch_deaths() -> void:
	if not _is_authority_with_company():
		return
	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		var who: Hero = _hero_for_slot(number)
		if who == null:
			continue
		var standing: bool = who.is_alive()
		if standing == bool(_was_alive.get(number, true)):
			continue
		_was_alive[number] = standing
		if standing:
			EventBus.coop_hero_revived.emit(number, who.global_position)
		else:
			EventBus.coop_hero_down.emit(number, who.global_position)


## A hero went down on the host. Put the matching one down here.
##
## `slot` names the seat, which every machine agrees on. Reading it as "mine"
## would drop the wrong player every time.
func _on_hero_down(slot: int, at: Vector2) -> void:
	var who: Hero = _mirrored(slot)
	if who == null or not who.is_alive():
		return
	who.global_position = at
	# **Put down, not damaged.**
	#
	# This used to deal lethal damage and let the local death path take over, so
	# that the collapse, the vignette and the bar all ran exactly as they do
	# alone. The trouble is that damage can be *refused*: invulnerability from a
	# respawn, a resurrection draught, a hit already in flight. When it was
	# refused the guest stayed standing while the host had them on the floor, and
	# the two machines then disagreed about whether anybody needed reviving.
	#
	# Reported from play in its worst form: a guest tending itself during
	# Preparation watched its hero heal while the host watched it die and vanish.
	#
	# `go_down` runs the same `_collapse` the damage path ends in, so nothing is
	# lost by saying it outright - and a fact about the world cannot be declined.
	who.health.current_hp = 0.0
	who.health.changed.emit(0.0, who.health.max_hp)
	who.go_down(at)


func _on_hero_revived(slot: int, at: Vector2) -> void:
	var who: Hero = _mirrored(slot)
	if who != null and not who.is_alive():
		who.global_position = at
		who.revive_in_place()


## Reviving, and the one thing in co-op that costs the run. Host side.
##
## The rules the owner set on 2026-08-25: a player who goes down takes no wound
## and waits. A partner who reaches them and holds gets them up for free. Both
## down at once is the failure, and the pair pays one Wound between them - three
## of those and the run is over, exactly as in solo play.
##
## Run entirely on the host and mirrored, rather than each machine deciding for
## itself. Two machines measuring "is my partner close enough" against positions
## a packet apart is how one player watches a revive complete that never happened
## on the other.
func _tick_revives(delta: float) -> void:
	if not _is_authority_with_company():
		return
	var party: Array[Hero] = party_heroes()
	if party.size() < 2:
		return

	# **A wipe is everybody down, however many everybody is.** With four players
	# it is also the rarer event, which is the point: a party of four should be
	# harder to wipe than a pair, and the Wound is worth the same either way.
	var standing: int = 0
	for who: Hero in party:
		if not who.is_downed():
			standing += 1
	if standing == 0:
		# Latched, or a wipe would be announced on every frame the party spends
		# on the floor - and each announcement would charge the run a Wound.
		if not _wipe_announced:
			_wipe_announced = true
			EventBus.coop_team_wipe.emit()
		return
	_wipe_announced = false

	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		var downed: Hero = _hero_for_slot(number)
		if downed == null or not downed.is_downed():
			continue
		_tick_one_revive(downed, _best_helper(downed, party), delta, number)


## How close to 1.0 counts as a finished revive.
##
## Wider than float noise and narrower than a frame's worth of progress, so it
## can only ever swallow the rounding rather than a real step.
const FULL: float = 0.001


## The nearest standing player who is holding the key, or null.
##
## **Nearest rather than first**, because with four players several may be within
## reach and the bar should belong to whoever actually crossed the field. It also
## keeps the answer stable: a list order is an implementation detail and would
## hand the credit around as bodies were rebuilt.
func _best_helper(downed: Hero, party: Array[Hero]) -> Hero:
	var best: Hero = null
	var nearest: float = Balance.COOP_REVIVE_RADIUS
	for who: Hero in party:
		if who == downed or not who.is_alive() or not who.is_holding_revive():
			continue
		var gap: float = who.global_position.distance_to(downed.global_position)
		if gap <= nearest:
			nearest = gap
			best = who
	return best


## One downed hero, and whatever anybody is doing about it.
func _tick_one_revive(downed: Hero, helper: Hero, delta: float,
		slot: int) -> void:
	if not downed.is_downed():
		return
	# `_best_helper` has already answered the distance and the key. A null here
	# means nobody is helping, and the bar drains.
	var reaching: bool = helper != null
	# Decays when they let go or are driven off. A revive interrupted by having
	# to fight is meant to lose ground, or standing in the open for three seconds
	# during a wave would not be the cost it is supposed to be.
	var step: float = delta / maxf(Balance.COOP_REVIVE_SECONDS, 0.01)
	var before: float = downed.revive_progress()
	var after: float = clampf(before + (step if reaching else -step), 0.0, 1.0)

	# **Full is a state, not the instant of a transition.**
	#
	# This used to get a hero up only on the frame the bar *crossed* 1.0, and
	# that frame never arrived. The last step lands on 0.999995 rather than 1.0 -
	# and `is_equal_approx` reads that as already equal, so the guard below threw
	# it away as a no-op, and every frame after it did the same. The bar sat
	# visibly full, nothing happened, and letting go simply drained it again.
	# Reported from play twice, in exactly those words.
	#
	# Asking about the state instead also makes the rule self-healing: a hero who
	# is down with a full bar gets up, however the bar came to be full.
	if reaching and after >= 1.0 - FULL:
		downed.set_revive_progress(1.0)
		EventBus.coop_revive_progress.emit(slot, 1.0)
		# Announced by `_watch_deaths` on the next frame, from the change in who
		# is alive - the same path a wipe respawn takes. Emitting it here as well
		# would send the fact twice for one revival.
		downed.revive_in_place()
		return

	if is_equal_approx(before, after):
		return
	downed.set_revive_progress(after)
	EventBus.coop_revive_progress.emit(slot, after)


## The pair went down together, so the run pays. Applied on both machines.
##
## The Wound is added here rather than in either hero because it belongs to the
## run, not to a person - charging it in both heroes would cost two Wounds for
## one wipe and end the run in a wave and a half.
func _on_team_wipe() -> void:
	_wipe_announced = true
	var wounds: int = RunState.add_wound()
	if wounds >= RunState.max_wounds():
		RunState.hero_deaths += 1
		GameDirector.end_run(false)
		return
	# Everybody who is on the floor, which with four players may be four people.
	for who: Hero in party_heroes():
		if who.is_downed():
			who.respawn_from_wipe()


## The host's bar, on the guest's screen.
func _on_revive_progress(slot: int, progress: float) -> void:
	var who: Hero = _mirrored(slot)
	if who != null:
		who.set_revive_progress(progress)


## Sets a hero's health from a relayed fraction, against its own maximum.
##
## Against its own maximum on purpose: the two players arrive with heroes at
## different levels and therefore different maximum HP, so an absolute would hand
## a level-5 host's number to a level-20 guest and read as a wound they never
## took.
##
## Never *raises* health past what arrived, and never applies a lethal value: a
## death is announced separately by `coop_hero_down`, which runs the whole death
## path. Assigning zero here would leave a hero at no health and still standing.
func _apply_health(who: Hero, fraction: float) -> void:
	if who == null or who.health == null or who.health.max_hp <= 0.0:
		return
	if not who.is_alive():
		return
	var wanted: float = maxf(clampf(fraction, 0.0, 1.0) * who.health.max_hp, 1.0)
	if is_equal_approx(who.health.current_hp, wanted):
		return
	who.health.current_hp = wanted
	who.health.changed.emit(who.health.current_hp, who.health.max_hp)


## Which hero on this machine stands for the seat the host is talking about.
##
## A slot rather than a boolean, and that is the whole two-to-four change in one
## function: with two players "is it the host's" was enough, and with four the
## question is simply *which seat*, answered the same way on every machine.
func _mirrored(slot: int) -> Hero:
	if not Coop.is_guest():
		return null
	return _hero_for_slot(slot)


## Any hero in the party by seat, this machine's own included.
func _hero_for_slot(number: int) -> Hero:
	if number == Coop.party().slot():
		return _local_hero()
	return body_for_slot(number)


## What the host's player is asking for, so the guest can animate it.
##
## The same snapshot the guest sends upward, travelling the other way. Sent every
## physics frame rather than on the slower state clock: a button press is an edge
## and lives for one frame, so a press sampled at 20Hz is a swing that sometimes
## simply never happens.
## Every player's hands, sent to every machine. Host side.
##
## **With four players this is a relay, not a broadcast of one.** A guest's input
## reaches the host and stops there, so the host passes on what everybody is
## doing - otherwise two guests animate the host perfectly and stand still to
## each other. The host's own seat rides along in the same packet.
func _send_host_input() -> void:
	var mine: Hero = _local_hero()
	if mine == null:
		return
	var source := mine.input as LocalHeroInput
	if source == null:
		return
	EventBus.coop_host_input.emit(Coop.party().slot(),
		source.snapshot(mine.aim_direction()))
	for key: Variant in _inputs.keys():
		var number: int = int(key)
		var driver: RemoteHeroInput = _inputs[key] as RemoteHeroInput
		if driver != null:
			EventBus.coop_host_input.emit(number, driver.last_snapshot())


## The host's stick and buttons, applied to the hero standing in for them here.
func _on_host_input(slot: int, snapshot: Array) -> void:
	if not Coop.is_guest() or slot == Coop.party().slot():
		return
	var driver: RemoteHeroInput = _inputs.get(slot, null) as RemoteHeroInput
	if driver != null:
		driver.apply(snapshot)


## The host tells the guest where both heroes actually are.
##
## Emitted on this machine's own bus rather than pushed at the relay. The relay
## is already subscribed and forwards it like any other fact, so hero positions
## need no send path of their own - and the authority guard covers them for free.
## A guest that tried to author a position would be caught by the same check that
## catches one inventing a kill.
func _send_state() -> void:
	var rows: Array = []
	for number: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		var who: Hero = _hero_for_slot(number)
		if who == null:
			continue
		rows.append([number, who.global_position, who.aim_direction(),
			_health_of(who)])
	if rows.is_empty():
		return
	EventBus.coop_hero_state.emit(rows)


## A hero's health as a fraction of its own maximum.
func _health_of(who: Hero) -> float:
	if who == null or who.health == null or who.health.max_hp <= 0.0:
		return 1.0
	return clampf(who.health.current_hp / who.health.max_hp, 0.0, 1.0)


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
## Facing is deliberately *not* applied here, and that is the fix for a bug play
## found: a partner walked around permanently facing wherever their cursor was,
## while every player sees their own hero face the way they are *walking*. So the
## two of you watched a different character than the one you were playing.
##
## The cause was applying the aim vector directly. `Hero._update_facing` already
## resolves this properly - attack beats movement, movement beats cursor - and a
## mirrored hero now runs it from the relayed input like any other, which means
## it cannot drift from what its owner sees by construction rather than by
## keeping two rules in step.
func _on_hero_state(rows: Array) -> void:
	if not Coop.is_guest():
		return
	for entry: Variant in rows:
		var row: Array = entry as Array
		if row == null or row.size() != 4:
			continue
		_apply_one_state(clampi(int(row[0]), 1, Balance.COOP_MAX_PLAYERS),
			row[1] as Vector2, float(row[3]))


## One seat's authoritative position and health, on a guest.
func _apply_one_state(number: int, at: Vector2, hp: float) -> void:
	var who: Hero = _hero_for_slot(number)
	if who == null:
		return
	_apply_health(who, hp)
	var own: bool = number == Coop.party().slot()
	# **Corrected toward, not snapped to.**
	#
	# Every body here is already walking - somebody else's from the host's
	# relayed input, this player's own from their hands - so a hard assignment
	# every packet fights that motion twenty times a second. It reads as a hero
	# that stutters and, worse, it flattens the velocity the walk cycle is chosen
	# from, so a moving hero plays its idle. Easing onto the authoritative
	# position keeps the movement continuous and still ends up where the host
	# says.
	#
	# Gentler for the hero under this player's own hands: a correction they can
	# feel is worse than a few pixels of disagreement.
	who.global_position = who.global_position.lerp(at,
		Balance.COOP_POSITION_CORRECTION * (0.5 if own else 1.0))


## A guest told the host what its player is asking for. Host side.
##
## **Attributed by the peer it arrived on**, which is the only trustworthy answer:
## a slot carried inside the packet would be a guest naming which body it drives,
## and naming somebody else's is the whole reason the authority model exists.
func _on_request(kind: int, args: Array, from: int) -> void:
	if kind != CoopRelay.Request.HERO_INPUT or not Coop.is_host():
		return
	var number: int = Coop.party().slot_for_peer(from)
	if number <= 0:
		return
	var driver: RemoteHeroInput = _inputs.get(number, null) as RemoteHeroInput
	if driver != null:
		driver.apply(args)


## True when this machine decides things *and* somebody is listening.
##
## Both halves matter: a guest must never author a death, and a host playing
## alone has nobody to tell - so a single-player run pays one boolean per frame
## and sends nothing.
func _is_authority_with_company() -> bool:
	return Coop.is_host() and Coop.partner_present()


func _local_hero() -> Hero:
	if field == null or not (field is Battlefield):
		return null
	return (field as Battlefield).hero
