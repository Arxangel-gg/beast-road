class_name MercLineData
extends GameData

## **What a mercenary says** (owner, 2026-10-07: mercenaries *"occasionally
## just say things, sometimes random things, sometimes regarding whatever
## they're doing or thinking or noticing ... especially having more useful
## things that they say regarding things they notice as though they're alerting
## the player"*). One file a moment, its lines, and whether it is an alert.
##
## Working rule 9: a player-facing string lives in data. The id is the moment
## (`MercenaryVoice` names them), so a new line is a line in a file and a new
## moment is a file and one listener.

## The lines, one chosen at random. `{warden}` is the Warden's name and `{name}`
## the speaker's own.
@export var lines: PackedStringArray = PackedStringArray()
## An alert outranks idle talk and is said even when the company spoke a moment
## ago; idle talk waits its turn.
@export var alert: bool = false
## How often the moment is spoken when it comes, 0 to 1.
@export_range(0.0, 1.0) var chance: float = 1.0
