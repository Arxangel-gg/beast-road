class_name KillStreak
extends Node2D

## **A burst of kills is celebrated where it happens** (2026-09-30, owner: *"more
## aesthetic appeal and polish and game juice"*, and *"players should have fun
## eliminating way more hordes"*). The Arsenal, the swing and the towers near the
## Warden now kill in bursts, and the game said nothing about it: a body died,
## and the next, and the next.
##
## Every road body that falls within `KILL_STREAK_REACH` of this machine's own
## Warden and `KILL_STREAK_WINDOW` of the kill before it adds to a streak. A
## counter - "x12" - rides above the Warden while the streak is alive, jumping
## on every kill; each tier in `KILL_STREAK_TIERS` says its word over the Warden
## with a ring and a chime a little higher than the last. The window lapsing
## ends it, and it fades.
##
## **A look and never a fact.** Nothing reads a streak: it pays nothing, grants
## nothing and moves no number, so a streak is the fight told back to the player
## and never a reason the fight went differently. It counts kills near the Warden
## rather than kills the Warden made, because what the player watches is the knot
## coming apart around them - their swing, their Arsenal and the towers they
## stand beside - and a streak that ignored the tower that finished a body at
## their feet would read as a miscount. In co-op each machine counts round its
## own Warden and nothing crosses the wire.

## Whose feats these are: this machine's own Warden, or null.
var hero_getter: Callable = Callable()
var _count: int = 0
var _last_msec: int = -100000
var _pop: float = 0.0
var _shown: float = 0.0
var _tier: int = -1
var _font: Font = null


func _ready() -> void:
	z_index = Balance.VFX_Z + 3
	_font = UiFonts.face(UiFonts.Role.IMPACT)
	EventBus.enemy_died.connect(_on_enemy_died)


func count() -> int:
	return _count if _alive() else 0


func tier() -> int:
	return _tier if _alive() else -1


func _alive() -> bool:
	return Time.get_ticks_msec() - _last_msec <= int(Balance.KILL_STREAK_WINDOW * 1000.0)


func _hero() -> Node2D:
	if not hero_getter.is_valid():
		return null
	var found: Variant = hero_getter.call()
	return found as Node2D if found is Node2D and is_instance_valid(found) else null


func _on_enemy_died(_enemy_id: String, at: Vector2) -> void:
	var warden: Node2D = _hero()
	if warden == null or at.distance_to(warden.global_position) > Balance.KILL_STREAK_REACH:
		return
	if not _alive():
		_count = 0
		_tier = -1
	_count += 1
	_last_msec = Time.get_ticks_msec()
	_pop = 1.0
	var reached: int = -1
	for index: int in Balance.KILL_STREAK_TIERS.size():
		if _count == Balance.KILL_STREAK_TIERS[index]:
			reached = index
	if reached >= 0:
		_tier = reached
		_announce(warden, reached)
	set_process(true)
	queue_redraw()


func _announce(warden: Node2D, index: int) -> void:
	var colour: Color = Balance.KILL_STREAK_COLOURS[mini(index, Balance.KILL_STREAK_COLOURS.size() - 1)]
	var said: String = Balance.KILL_STREAK_NAMES[mini(index, Balance.KILL_STREAK_NAMES.size() - 1)]
	var at: Vector2 = warden.global_position + Vector2(0.0, -Balance.KILL_STREAK_LIFT)
	Vfx.word(at, "%s  x%d" % [said, _count], colour, Balance.KILL_STREAK_WORD_SIZE + index * 2)
	Vfx.ring(warden.global_position, Balance.KILL_STREAK_RING + 18.0 * float(index), colour, 0.45, 5.0)
	Vfx.spark(warden.global_position + Vector2(0.0, -40.0), colour, 10 + index * 3, Vector2.UP, 280.0)
	Sfx.play("sfx_profession_level", Balance.KILL_STREAK_DB,
		Balance.KILL_STREAK_PITCH_STEP * float(index))


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 5.0, 0.0)
	var wanted: float = 1.0 if _alive() and _count >= Balance.KILL_STREAK_SHOW_FROM else 0.0
	_shown = move_toward(_shown, wanted, delta * (6.0 if wanted > 0.0 else 2.5))
	var warden: Node2D = _hero()
	if warden != null:
		global_position = warden.global_position + Vector2(0.0, -Balance.KILL_STREAK_LIFT)
	queue_redraw()
	if _shown <= 0.0 and _pop <= 0.0:
		set_process(false)


func _draw() -> void:
	if _shown <= 0.004 or _font == null:
		return
	var index: int = maxi(_tier, 0)
	var colour: Color = Balance.KILL_STREAK_COLOURS[mini(index, Balance.KILL_STREAK_COLOURS.size() - 1)] \
		if _tier >= 0 else Color(0.96, 0.92, 0.84)
	colour.a *= _shown
	var size: int = Balance.KILL_STREAK_COUNTER_SIZE + int(round(8.0 * _pop))
	var text: String = "x%d" % _count
	var wide: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := Vector2(-wide * 0.5, 0.0)
	draw_string_outline(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 7,
		Color(0.03, 0.02, 0.025, 0.9 * _shown))
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)
