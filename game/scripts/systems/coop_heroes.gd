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

## What was true last frame, so a death or a revival can be spotted as a change
## rather than as a signal that cannot say whose it was.
var _host_was_alive: bool = true

## Whether the current wipe has already been announced, so it is charged once.
var _wipe_announced: bool = false
var _partner_was_alive: bool = true

## Where each player stands when they arrive, and where they come back to.
##
## **By role, not by machine.** The host's hero uses the same spot on both
## screens and so does the guest's, or the two would disagree about who is
## standing where every time anybody respawned.
##
## Far enough apart that two bodies of radius 26 cannot arrive inside one
## another: a wipe used to put both players on exactly `Vector2.ZERO` and they
## came back stuck to each other, which is what "locked at origin" was.
const HOST_SPAWN: Vector2 = Vector2(-90.0, 30.0)
const GUEST_SPAWN: Vector2 = Vector2(90.0, -30.0)


func _ready() -> void:
	EventBus.coop_partner_joined.connect(_on_partner_joined)
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
	battlefield.hero.spawn_point = battlefield.town_position() 		+ (HOST_SPAWN if Coop.is_host() else GUEST_SPAWN)


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
	# The partner is whichever role this machine is not.
	hero.spawn_point = battlefield.town_position() 		+ (GUEST_SPAWN if Coop.is_host() else HOST_SPAWN)
	hero.position = hero.spawn_point
	battlefield.entity_root.add_child(hero)
	_claim_local_spawn(battlefield)
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
	var mine: Hero = _local_hero()
	var host_alive: bool = mine != null and mine.is_alive()
	var partner_alive: bool = has_partner() and _partner.is_alive()

	if host_alive != _host_was_alive:
		_host_was_alive = host_alive
		if host_alive:
			EventBus.coop_hero_revived.emit(true, mine.global_position)
		else:
			EventBus.coop_hero_down.emit(true, mine.global_position)
	if partner_alive != _partner_was_alive:
		_partner_was_alive = partner_alive
		if partner_alive:
			EventBus.coop_hero_revived.emit(false, _partner.global_position)
		else:
			EventBus.coop_hero_down.emit(false, _partner.global_position)


## A hero went down on the host. Put the matching one down here.
##
## `host_hero` names the role rather than the owner, because the two swap: the
## host's hero is the guest's partner. Reading it as "mine" would drop the wrong
## player every time.
func _on_hero_down(host_hero: bool, at: Vector2) -> void:
	var who: Hero = _mirrored(host_hero)
	if who != null and who.is_alive():
		who.global_position = at
		# Through the normal damage path, so the death animation, the vignette
		# and the respawn timer all run exactly as they do for a solo death.
		who.health.take_damage(who.health.max_hp * 2.0, at)


func _on_hero_revived(host_hero: bool, at: Vector2) -> void:
	var who: Hero = _mirrored(host_hero)
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
	var mine: Hero = _local_hero()
	if mine == null or not has_partner():
		return

	if mine.is_downed() and _partner.is_downed():
		# Latched, or a wipe would be announced on every frame the pair spends on
		# the floor - and each announcement would charge the run another Wound.
		if not _wipe_announced:
			_wipe_announced = true
			EventBus.coop_team_wipe.emit()
		return
	_wipe_announced = false
	_tick_one_revive(mine, _partner, delta, true)
	_tick_one_revive(_partner, mine, delta, false)


## How close to 1.0 counts as a finished revive.
##
## Wider than float noise and narrower than a frame's worth of progress, so it
## can only ever swallow the rounding rather than a real step.
const FULL: float = 0.001


## One downed hero, and whatever their partner is doing about it.
func _tick_one_revive(downed: Hero, helper: Hero, delta: float,
		host_hero: bool) -> void:
	if not downed.is_downed():
		return
	var reaching: bool = helper.is_alive() and helper.is_holding_revive() 		and helper.global_position.distance_to(downed.global_position) 			<= Balance.COOP_REVIVE_RADIUS
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
		EventBus.coop_revive_progress.emit(host_hero, 1.0)
		# Announced by `_watch_deaths` on the next frame, from the change in who
		# is alive - the same path a wipe respawn takes. Emitting it here as well
		# would send the fact twice for one revival.
		downed.revive_in_place()
		return

	if is_equal_approx(before, after):
		return
	downed.set_revive_progress(after)
	EventBus.coop_revive_progress.emit(host_hero, after)


## The pair went down together, so the run pays. Applied on both machines.
##
## The Wound is added here rather than in either hero because it belongs to the
## run, not to a person - charging it in both heroes would cost two Wounds for
## one wipe and end the run in a wave and a half.
func _on_team_wipe() -> void:
	_wipe_announced = true
	var wounds: int = RunState.add_wound()
	if wounds >= Balance.HERO_MAX_WOUNDS:
		RunState.hero_deaths += 1
		GameDirector.end_run(false)
		return
	var mine: Hero = _local_hero()
	if mine != null and mine.is_downed():
		mine.respawn_from_wipe()
	if has_partner() and _partner.is_downed():
		_partner.respawn_from_wipe()


## The host's bar, on the guest's screen.
func _on_revive_progress(host_hero: bool, progress: float) -> void:
	var who: Hero = _mirrored(host_hero)
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


## Which hero here stands for the one the host is talking about.
func _mirrored(host_hero: bool) -> Hero:
	if not Coop.is_guest():
		return null
	return _partner if host_hero else _local_hero()


## What the host's player is asking for, so the guest can animate it.
##
## The same snapshot the guest sends upward, travelling the other way. Sent every
## physics frame rather than on the slower state clock: a button press is an edge
## and lives for one frame, so a press sampled at 20Hz is a swing that sometimes
## simply never happens.
func _send_host_input() -> void:
	var mine: Hero = _local_hero()
	if mine == null:
		return
	var source := mine.input as LocalHeroInput
	if source == null:
		return
	EventBus.coop_host_input.emit(source.snapshot(mine.aim_direction()))


## The host's stick and buttons, applied to the hero standing in for them here.
func _on_host_input(snapshot: Array) -> void:
	if Coop.is_guest() and _remote != null:
		_remote.apply(snapshot)


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
	var partner_hp: float = _health_of(_partner) if has_partner() else 1.0
	EventBus.coop_hero_state.emit(mine.global_position, mine.aim_direction(),
		_health_of(mine), partner_at, partner_aim, partner_hp)


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
func _on_hero_state(host_at: Vector2, _host_aim: Vector2, host_hp: float,
		guest_at: Vector2, _guest_aim: Vector2, guest_hp: float) -> void:
	if not Coop.is_guest():
		return
	# Health is *assigned*, both heroes, and that is the fix for a guest who
	# walked through a battle at full health while the host watched them die.
	#
	# Nothing damages a guest's heroes locally - puppet enemies never strike -
	# so there is no local simulation to fight here. The host is simply the only
	# thing that knows, and until it said so the two machines held two different
	# opinions about whether anybody was hurt.
	if has_partner():
		_apply_health(_partner, host_hp)
	var local: Hero = _local_hero()
	if local != null:
		_apply_health(local, guest_hp)
	# **Corrected toward, not snapped to.**
	#
	# Both heroes are already walking here - the partner from the host's relayed
	# input, this player's own from their hands - so a hard assignment every
	# packet fights that motion twenty times a second. It reads as a hero that
	# stutters and, worse, it flattens the velocity the walk cycle is chosen
	# from, so a moving hero plays its idle. Easing onto the authoritative
	# position keeps the movement continuous and still ends up where the host
	# says.
	if has_partner():
		_partner.global_position = _partner.global_position.lerp(host_at,
			Balance.COOP_POSITION_CORRECTION)
	var mine: Hero = _local_hero()
	if mine != null:
		# Gentler still for the hero under this player's own hands: a correction
		# they can feel is worse than a few pixels of disagreement.
		mine.global_position = mine.global_position.lerp(guest_at,
			Balance.COOP_POSITION_CORRECTION * 0.5)


func _on_request(kind: int, args: Array, _from: int) -> void:
	if kind != CoopRelay.Request.HERO_INPUT or not Coop.is_host():
		return
	if _remote != null:
		_remote.apply(args)


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
