class_name Withdrawal
extends Node

## **The road behind you closes when you turn for home.**
##
## Owner ruling, 2026-09-16: *"pressure should rise against players who walk out
## of a run."* Until now a return settled on the frame the card closed - the
## largest decision in a run, resolved instantly and for free. The withdrawal is
## what it costs: for `HOMECOMING_WITHDRAWAL_SECONDS` the road keeps sending
## bodies at the town, thickening as the beast pulls away, and the fortress the
## party is leaving holds the gate with exactly the board they built.
##
## **What it takes is the condition of the front they carry home.** The wall and
## every emplacement take the damage they actually take, and `Expedition.compose`
## already photographs both - so a withdrawal fought badly is a front that stands
## up battered the next time it is picked up. That is the attrition ruling of
## 2026-09-15 ("extraction that repaired every emplacement would make the correct
## play leave the moment anything is damaged") pointed at the walk out.
##
## **Three bounds, and each one is a design that was tried and rejected.**
##
## 1. **The bank cannot be lost on the way out.** `Health.floor_hp` holds the town
##    at `HOMECOMING_WALL_FLOOR` for the length of the withdrawal, so a party who
##    pressed Turn For Home always reaches home. Extraction is the only ratchet
##    the expedition system has; putting it behind a fight would pin a player who
##    cannot win one at their last successful extraction for ever, and would mean
##    that stopping for the evening while hurt requires winning. See
##    `Balance.HOMECOMING_WALL_FLOOR`.
##
## 2. **Its size is read off the act, never off how far the party pushed.**
##    `MOMENTUM_PER_CROSSROAD` exists so that passing a fork without banking pays
##    a little; a withdrawal priced by road-walked-since-banking is that same
##    quantity with the sign flipped and a larger coefficient, which would make
##    banking at the first fork strictly correct and quietly repeal the ruling
##    twenty lines above it in `Balance.gd`. The bodies are the act's own bodies
##    at the act's own scaling, through `WaveDirector.send_closing_body`.
##
## 3. **Nothing chases.** The roster walks at 28-68 units against a hero at 200,
##    so a pursuer is a mechanic that cannot fire - it can never land a blow on
##    anybody holding a movement key. The bodies do what every body in this game
##    does and walk at the town, which cannot run.
##
## **Nothing new persists and nothing new crosses the wire.** The wall ratio and
## the tower health were already in the snapshot; a guest runs no waves and
## settles no run, and the bodies reach it as the same spawn facts every other
## body does.


## Seconds between bodies at `share` of the way through the withdrawal.
##
## Static and pure, the shape `Run.homecoming_marks` uses, so a gate can read the
## ramp without standing a field up - and so the one place that decides how hard
## a withdrawal presses is the one place a gate measures.
static func spacing_at(share: float) -> float:
	return lerpf(Balance.HOMECOMING_WITHDRAWAL_FIRST,
		Balance.HOMECOMING_WITHDRAWAL_LAST, clampf(share, 0.0, 1.0))


## Roughly how many bodies a whole withdrawal sends. Reporting and gates only:
## the integral of one over the spacing, which for a linear ramp is the length
## over the mean gap.
static func bodies_expected() -> float:
	var mean: float = 0.5 * (Balance.HOMECOMING_WITHDRAWAL_FIRST
		+ Balance.HOMECOMING_WITHDRAWAL_LAST)
	if mean <= 0.0:
		return 0.0
	return Balance.HOMECOMING_WITHDRAWAL_SECONDS / mean


signal finished()

var battlefield: Battlefield = null
var director: WaveDirector = null

var _left: float = 0.0
var _total: float = 0.0
var _next: float = 0.0
var _sent: int = 0
var _town_floor_was: float = 0.0
var _town: Health = null


func _ready() -> void:
	set_process(false)


## **Close the road for `seconds`.** Host-only; the caller awaits `finished`.
func begin(seconds: float) -> void:
	if _total > 0.0:
		return
	_total = maxf(seconds, 0.0)
	_left = _total
	# The first body is sent at once rather than after a gap: a withdrawal that
	# opens with a second and a half of nothing reads as the run having hung.
	_next = 0.0
	_sent = 0
	RunState.withdrawing = true
	_hold_the_wall()
	# **Said once at each end**, and from here rather than from the run, so the
	# two halves of what the player is told cannot drift apart. The banner is the
	# only thing between pressing Turn For Home and being handed a road full of
	# bodies, so it has to name what is happening and that it ends.
	EventBus.preparation_warning.emit(
		"The road behind you closes. Hold the gate while the beast pulls away.")
	if _total <= 0.0:
		_end()
		return
	set_process(true)


## How far through the withdrawal is, from nothing to all of it. Read by the
## interface; changes no number.
func share() -> float:
	if _total <= 0.0:
		return 0.0
	return clampf(1.0 - _left / _total, 0.0, 1.0)


## How many bodies this withdrawal has sent. Gates and the debrief.
func sent() -> int:
	return _sent


## Seconds of road still to hold, for the readout. Zero when nothing is running,
## so a caller can ask without checking first.
func seconds_left() -> float:
	return maxf(_left, 0.0)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_end()
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = spacing_at(share())
	if director != null and is_instance_valid(director):
		director.send_closing_body()
		_sent += 1


## **The town is held above the floor for exactly as long as this runs.**
##
## Set and cleared in one place, and cleared on the way out whatever happened,
## because a floor left standing is the same silent-and-permanent failure shape
## as a hush that never resolves: nothing errors, nothing looks broken, and the
## town can simply never be lost again.
func _hold_the_wall() -> void:
	_town = null
	if battlefield == null or not is_instance_valid(battlefield):
		return
	if battlefield.town == null or not is_instance_valid(battlefield.town):
		return
	_town = battlefield.town.health
	if _town == null:
		return
	_town_floor_was = _town.floor_hp
	_town.floor_hp = maxf(_town.floor_hp,
		_town.max_hp * Balance.HOMECOMING_WALL_FLOOR)


func _release_the_wall() -> void:
	if _town != null and is_instance_valid(_town):
		_town.floor_hp = _town_floor_was
	_town = null


func _end() -> void:
	set_process(false)
	_left = 0.0
	_total = 0.0
	RunState.withdrawing = false
	_release_the_wall()
	if _sent > 0:
		EventBus.preparation_warning.emit("The beast is clear of the road. Home.")
	finished.emit()
