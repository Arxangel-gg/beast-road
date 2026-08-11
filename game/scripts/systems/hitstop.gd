class_name Hitstop
extends Node

## Freezes the whole game for a few frames when a blow lands.
##
## This is the single largest contributor to whether a swing feels like it
## connected with something, which makes it load-bearing for Stage 1's kill
## question rather than polish.
##
## Requests come through EventBus so any system can ask without knowing this
## node exists. The longest outstanding request wins — a finisher landing on six
## enemies should not be cut short by a light hit resolving in the same frame.

## Wall-clock deadline in milliseconds. Engine.time_scale is 0 during a freeze,
## which makes `delta` 0, so a freeze cannot be timed with the frame delta that
## it is itself suppressing.
var _until_ms: int = 0


func _ready() -> void:
	EventBus.hitstop_requested.connect(_on_requested)


func _process(_delta: float) -> void:
	if _until_ms == 0:
		return
	if Time.get_ticks_msec() < _until_ms:
		return
	_until_ms = 0
	Engine.time_scale = 1.0


func _on_requested(duration: float) -> void:
	if duration <= 0.0:
		return
	var deadline: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if deadline <= _until_ms:
		return
	_until_ms = deadline
	Engine.time_scale = Balance.HITSTOP_TIME_SCALE


## Time scale must not be left at zero if this node dies mid-freeze.
func _exit_tree() -> void:
	if _until_ms != 0:
		_until_ms = 0
		Engine.time_scale = 1.0
