class_name Health
extends Node

## Hit points, damage, invulnerability and death, for anything that has them.
##
## Shared by the hero and by enemies so there is exactly one damage path, and so
## an enemy does not need to know what kind of thing it is hitting — it looks up
## a Health on the target and calls it. The city gets the same treatment in
## Stage 4 without this file changing.

## Damage actually applied, after the invulnerability check.
signal damaged(amount: float, from: Vector2)

## HP reached zero. Fired once; further damage is ignored until `revive`.
signal died(from: Vector2)

## Any change at all, including revive. Health bars read off this.
signal changed(current: float, maximum: float)

@export var max_hp: float = 100.0

var current_hp: float = 0.0
var is_dead: bool = false

## Optional flat protection for structures. Damage always leaks through so a
## rapid weak horde cannot be made permanently irrelevant by one armour aura.
var flat_damage_reduction: float = 0.0

var _invulnerable_left: float = 0.0


## Finds the Health belonging to `node`, or null. Keeps callers from having to
## know where in a unit's scene the component sits.
static func of(node: Node) -> Health:
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is Health:
			return child
	return null


func _ready() -> void:
	current_hp = max_hp
	changed.emit(current_hp, max_hp)


func _process(delta: float) -> void:
	if _invulnerable_left > 0.0:
		# Deliberately scaled time: i-frames should not tick away during the
		# hitstop of the blow that granted them.
		_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


func add_invulnerability(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


## Returns true if the damage landed. Callers use the return value to decide
## whether to play an impact — a swing that hits an i-framing target should not
## shake the screen.
func take_damage(amount: float, from: Vector2) -> bool:
	if is_dead or amount <= 0.0 or is_invulnerable():
		return false
	var applied: float = maxf(amount - flat_damage_reduction, amount * 0.20)
	current_hp = maxf(current_hp - applied, 0.0)
	damaged.emit(applied, from)
	changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		is_dead = true
		died.emit(from)
	return true


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_hp = minf(current_hp + amount, max_hp)
	changed.emit(current_hp, max_hp)


## Resolves a system-level softlock without being defeated by temporary
## invulnerability. Ordinary combat must use `take_damage`; this is for an owner
## such as the wave watchdog that has already proved the encounter cannot move.
func kill(from: Vector2) -> void:
	if is_dead:
		return
	current_hp = 0.0
	is_dead = true
	changed.emit(current_hp, max_hp)
	died.emit(from)


## Alive and vulnerable at the requested health fraction.
func revive(fraction: float = 1.0) -> void:
	is_dead = false
	current_hp = max_hp * clampf(fraction, 0.01, 1.0)
	_invulnerable_left = 0.0
	changed.emit(current_hp, max_hp)


func ratio() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0
