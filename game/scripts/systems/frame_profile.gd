class_name FrameProfile
extends RefCounted

## **Where a frame goes, by system** (2026-09-24). Off unless a diagnostic
## turns it on; `perf_check --trace=` does, and prints a bucket per system on
## every frame inside its window.
##
## Why this exists beside `perf_bisect`: the bisect switches whole scripts
## off and measures the average, which finds a script that is slow all the
## time and cannot find one that is slow only while the fight is heavy - a
## heavy stretch on Act X read 20-36 ms a frame against a 9 ms road either
## side of it, and the bisect's held field, with its bodies immortal, never
## dies, never drops loot and never sees that stretch. A bucket a frame does.
##
## The cost when off is one `Time.get_ticks_usec()` at each wrapped site and
## a static bool, which is nothing. A wrapped site is the system's own tick or
## draw renamed `_measured` with a four-line wrapper under it; the buckets
## are inclusive, so a tower's bucket carries the blows its shots landed.

static var enabled: bool = false
static var _usec: Dictionary = {}
static var _calls: Dictionary = {}


static func add(key: StringName, started_usec: int) -> void:
	if not enabled:
		return
	_usec[key] = int(_usec.get(key, 0)) + (Time.get_ticks_usec() - started_usec)
	_calls[key] = int(_calls.get(key, 0)) + 1


## The frame's buckets as one line, heaviest first, in milliseconds with the
## call count, and the buckets cleared for the next frame.
static func take(top: int = 12) -> String:
	if _usec.is_empty():
		return ""
	var keys: Array = _usec.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_usec[a]) > int(_usec[b]))
	var parts: PackedStringArray = []
	for index: int in mini(keys.size(), top):
		var key: Variant = keys[index]
		parts.append("%s=%.1f/%d" % [String(key), float(_usec[key]) / 1000.0, int(_calls[key])])
	_usec.clear()
	_calls.clear()
	return " ".join(parts)
