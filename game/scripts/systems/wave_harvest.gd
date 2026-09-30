class_name WaveHarvest
extends RefCounted

## **What a wave paid, said when it is held** (2026-09-30, owner: *"more
## aesthetic appeal and polish and game juice"*). The wall has been said out
## loud since 2026-09-21 and the purse rolls rather than jumps, but nothing ever
## put the two together: a wave ended, the breather began, and what the fight
## had just earned was a set of numbers that had quietly moved in a corner. The
## economy this game rests on - "tower money is taken off the enemies the player
## kills" (§1, 2026-08-27) - is only a decision if the player can see what a
## wave was worth.
##
## So the HUD's message line says it when the wave closes: how many fell and
## what each wallet gained. **A readout and nothing else**: it reads the run's
## purse at the start and at the end and counts deaths in between; it pays
## nothing, moves no number and sends nothing. A wallet that ended lower than it
## began (a heal paid for mid-wave) is left out rather than shown as a loss,
## because the line is a harvest, not a ledger.

var _before: Dictionary = {}
var _kills: int = 0
var _open: bool = false


## A wave has begun: remember the purse and start counting.
func begin() -> void:
	_before.clear()
	for id: String in Balance.CURRENCY_IDS:
		_before[id] = RunState.currency(id)
	_kills = 0
	_open = true


## A body fell while the wave was open.
func note_kill() -> void:
	if _open:
		_kills += 1


## The wave is held: the sentence, or "" when there is nothing to say - a wave
## that was never begun here, or a calm one in which nothing fell and nothing
## was earned.
func close(wave_number: int) -> String:
	if not _open:
		return ""
	_open = false
	var parts: PackedStringArray = []
	for id: String in Balance.CURRENCY_IDS:
		var gained: int = RunState.currency(id) - int(_before.get(id, 0))
		if gained > 0:
			parts.append("+%d %s" % [gained, RunState.currency_name(id)])
	if _kills <= 0 and parts.is_empty():
		return ""
	var line: String = "Wave %d held  ·  %d fell" % [wave_number, _kills]
	if not parts.is_empty():
		line += "  ·  " + "  ".join(parts)
	return line


## For the gate: whether a wave is being counted.
func is_open() -> bool:
	return _open
