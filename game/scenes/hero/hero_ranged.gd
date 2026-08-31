class_name HeroRanged
extends Node

## The hero's answer at range (owner decision, 2026-08-31).
##
## Deliberately shaped like `HeroAttack`: a small state machine the hero ticks,
## reporting through signals. It owns the draw timer and the decision to spend a
## shot, and nothing else - the projectile, the damage and the status all come
## from the same places a tower's shot does.
##
## **Melee stays the reliable default.** Two things enforce that and both are
## data: the draw is slower than a swing, and every shot costs ammunition that
## has to be found or made. If a run can be finished without ever closing, that
## balance has failed and `balance_test` is where the argument belongs.

## Fired when a shot leaves, so the hero can lunge back a little and the sound
## can play once.
signal loosed(from: Vector2, direction: Vector2, ammo: AmmoData)

## Fired when the trigger comes down on an empty quiver. The hero says so rather
## than doing nothing, because doing nothing reads as a broken button.
signal dry()

var field: EnemyField = null
var hero: Node2D = null

var _draw_left: float = 0.0


## Whether a bow is in hand at all. Runs start melee-only.
func armed() -> bool:
	return not RunState.ranged_id.is_empty() \
		and ContentDB.ranged_weapons.has(RunState.ranged_id)


func weapon() -> RangedWeaponData:
	return ContentDB.ranged_weapons.get(RunState.ranged_id, null) as RangedWeaponData


func nocked() -> AmmoData:
	return ContentDB.ammo_kinds.get(RunState.ammo_id, null) as AmmoData


## How much the hero is slowed while the draw is still running.
func move_scale() -> float:
	if _draw_left <= 0.0 or not armed():
		return 1.0
	return weapon().draw_move_scale


func is_drawing() -> bool:
	return _draw_left > 0.0


func tick(delta: float) -> void:
	_draw_left = maxf(_draw_left - delta, 0.0)


## Moves to the next ammunition this weapon can fire and the player knows.
##
## Cycles rather than opening a menu: the choice is between three or four things
## and a radial for that is ceremony. Skips what is not held, so cycling never
## lands on an empty type - the player asked for a different arrow, not for a
## different way to fire nothing.
func cycle_ammo() -> void:
	if not armed():
		return
	var options: Array[AmmoData] = RunState.ammo_for_weapon(RunState.ranged_id)
	var usable: Array[AmmoData] = []
	for kind: AmmoData in options:
		if RunState.ammo_count(kind.id) > 0:
			usable.append(kind)
	if usable.is_empty():
		return
	var at: int = 0
	for index: int in usable.size():
		if usable[index].id == RunState.ammo_id:
			at = index + 1
			break
	RunState.ammo_id = usable[at % usable.size()].id


## Looses a shot toward `aim`, if there is one to loose.
func request(aim: Vector2, origin: Vector2) -> void:
	if not armed() or _draw_left > 0.0:
		return
	var kind: AmmoData = nocked()
	# Falls back rather than refusing. Running out of the special arrow should
	# leave the bow working, not leave the player pressing a dead button and
	# wondering which system broke.
	if kind == null or RunState.ammo_count(kind.id) <= 0:
		cycle_ammo()
		kind = nocked()
	if kind == null or not RunState.spend_one_ammo(kind.id):
		dry.emit()
		return
	_draw_left = weapon().draw_time
	var heading: Vector2 = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	loosed.emit(origin, heading, kind)
