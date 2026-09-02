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

## The length of the window currently running, so elapsed time can be derived.
var _invulnerable_granted: float = 0.0


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
	# Kept so `evaded` can say *how far into* the window a blow arrived. Without
	# it the listener knows only that something was dodged, and a dodge the
	# player scraped is indistinguishable from one they had a second to spare on.
	_invulnerable_granted = _invulnerable_left


## Returns true if the damage landed. Callers use the return value to decide
## whether to play an impact — a swing that hits an i-framing target should not
## shake the screen.
func take_damage(amount: float, from: Vector2) -> bool:
	if is_dead or amount <= 0.0:
		return false
	if is_invulnerable():
		# Said out loud rather than swallowed. See `evaded`.
		evaded.emit(_invulnerable_granted - _invulnerable_left, from)
		return false
	var applied: float = maxf(amount - flat_damage_reduction, amount * 0.20)
	# Shield first, and it can absorb a blow whole.
	#
	# **After mitigation, not before.** `flat_damage_reduction` is armour, and
	# armour still works while a ward is up; spending the shield against the raw
	# number would make wearing armour under a ward worth nothing. The shield
	# pays for what armour did not stop.
	if _shield > 0.0:
		var absorbed: float = minf(_shield, applied)
		_shield -= absorbed
		applied -= absorbed
		shield_changed.emit(_shield)
		if applied <= 0.0:
			# The blow landed - it was simply paid for. Still reported as a hit,
			# because a ward that made attacks silent would read as the enemy
			# having missed.
			damaged.emit(0.0, from)
			return true
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
	_shield = 0.0
	shield_changed.emit(0.0)
	current_hp = 0.0
	is_dead = true
	changed.emit(current_hp, max_hp)
	died.emit(from)


## Alive and vulnerable at the requested health fraction.
func revive(fraction: float = 1.0) -> void:
	is_dead = false
	_shield = 0.0
	shield_changed.emit(0.0)
	current_hp = max_hp * clampf(fraction, 0.01, 1.0)
	_invulnerable_left = 0.0
	changed.emit(current_hp, max_hp)


func ratio() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0


# --- Shield ------------------------------------------------------------------
#
# A pool spent before health that never regenerates on its own. Added for the
# WARD consumable, and deliberately the smallest thing that could earn that
# effect a place in `ItemData.Effect`: an enum arm the game has no concept for is
# a promise to a designer that nothing keeps.
#
# Not a stat. It does not scale with anything, it is never persisted, and death
# or revival clears it - so it cannot quietly become a second health bar that the
# difficulty curve has to be re-tuned around.

## Emitted whenever the pool changes, so a bar can draw it.
signal shield_changed(remaining: float)

## A blow arrived and the i-frames ate it.
##
## Distinct from `damaged`, which only fires when something got through. Until
## 2026-09-02 a dodged hit was silent: `take_damage` returned false and nothing
## anywhere could tell the difference between "you evaded that" and "no attack
## happened". Perfect Evade is built on knowing which.
##
## `into` is how much of the invulnerability had already elapsed when the blow
## landed. A hit that arrives in the first moments of it is one the player
## dashed *at the last instant*, which is the whole skill being rewarded; one
## that arrives late is a player who dashed early and got lucky.
signal evaded(into: float, from: Vector2)

## How much of the shield is left. Zero is the ordinary state.
var _shield: float = 0.0


func shield() -> float:
	return _shield


## Adds to the pool rather than replacing it, but never past a ceiling: two
## wards running should be worth more than one and not worth unlimited.
func add_shield(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	_shield = minf(_shield + amount, max_hp * Balance.HEALTH_SHIELD_CEILING)
	shield_changed.emit(_shield)
