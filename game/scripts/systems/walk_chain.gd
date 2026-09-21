class_name WalkChain
extends Node2D

## The chain on Yuri, and the one beat of the Walk that is not a lesson.
##
## The Walk's last stop said "Cut the chain. Hold Interact" and finished the
## moment the Warden stood near the town (2026-09-21): there was no chain to
## hold anything against, so the instruction was a sentence and the ending was
## a walk-up. This is the chain. It stands where the last stop is placed, it
## asks for `Balance.WALK_CHAIN_SECONDS` of Interact held inside
## `WALK_CHAIN_REACH`, it sparks while it is being worked and gives ground
## while it is not, and when it parts it says so once (`cut`) - which is what
## the Walk listens for.
##
## **It reads the same input every other worked thing reads.** A pond, a seam,
## a nest and a gate all ask `HeroInput` through the hero's `input`, and so
## does this; a chain with its own key would be a chain a rider could cut
## from the saddle, which `HeroInput.muted` exists to refuse.
##
## Presentation only past the `cut` signal: nothing else reads it.

signal cut()

const ART: String = "res://art/battlefield/walk_chain.png"
const PROMPT_OWNER: StringName = &"walk_chain"

var field: Node = null

var _worked: float = 0.0
var _done: bool = false
var _art: Texture2D = null
var _spark_clock: float = 0.0
var _prompt: String = ""
var _worked_by_hand: float = 0.0


func _ready() -> void:
	name = "WalkChain"
	if ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _done:
		return
	var near: bool = _someone_near()
	var holding: bool = near and _someone_holds()
	if _worked_by_hand > 0.0:
		holding = true
		_worked_by_hand = maxf(_worked_by_hand - delta, 0.0)
	if holding:
		_worked += delta
		_spark_clock += delta
		if _spark_clock >= 0.22:
			_spark_clock = 0.0
			Vfx.spark(global_position, Color(1.0, 0.85, 0.5), 5, Vector2.UP, 220.0)
	else:
		# It gives ground rather than resetting: letting go for a breath is not
		# starting over, and holding for the whole of it is still the ask.
		_worked = maxf(_worked - delta * 1.5, 0.0)
	_say(near, holding)
	queue_redraw()
	if _worked >= Balance.WALK_CHAIN_SECONDS:
		_part()


## For the gate, and for anything that wants the beat without a hand on the
## button: counts as Interact held for this long.
func work(seconds: float) -> void:
	_worked_by_hand = seconds
	var step: float = 1.0 / 60.0
	var left: float = seconds + step
	while left > 0.0 and not _done:
		_process(step)
		left -= step


func progress() -> float:
	return clampf(_worked / maxf(Balance.WALK_CHAIN_SECONDS, 0.01), 0.0, 1.0)


func is_cut() -> bool:
	return _done


func _heroes() -> Array:
	if field == null or not field.has_method("heroes"):
		return []
	return field.call("heroes")


func _someone_near() -> bool:
	for who: Variant in _heroes():
		var hero := who as Node2D
		if hero != null and is_instance_valid(hero) \
				and hero.global_position.distance_to(global_position) <= Balance.WALK_CHAIN_REACH:
			return true
	return false


func _someone_holds() -> bool:
	for who: Variant in _heroes():
		var hero := who as Node2D
		if hero == null or not is_instance_valid(hero) \
				or hero.global_position.distance_to(global_position) > Balance.WALK_CHAIN_REACH:
			continue
		var source := hero.get("input") as HeroInput
		if source != null and source.held(HeroInput.BUTTON_INTERACT):
			return true
	return false


func _say(near: bool, holding: bool) -> void:
	var text: String = ""
	if near:
		text = ("CUTTING  ·  %d%%" % int(round(progress() * 100.0))) if holding \
			else ("Cut the chain  ·  hold [%s]" % KeyBindings.label_for(&"interact"))
	if text == _prompt:
		return
	if text.is_empty():
		if EventBus.claim_prompt(PROMPT_OWNER, ""):
			EventBus.interact_prompt.emit("", "")
		_prompt = ""
		return
	if not EventBus.claim_prompt(PROMPT_OWNER, text):
		return
	_prompt = text
	EventBus.interact_prompt.emit(text, "interact")


## It parts: a burst, a ring, a knock the camera feels by distance, the sound
## of iron giving, and the word.
func _part() -> void:
	_done = true
	_say(false, false)
	Vfx.spark(global_position, Color(1.0, 0.9, 0.6), 28, Vector2.UP, 340.0)
	Vfx.ring(global_position, 160.0, Color(1.0, 0.85, 0.5, 0.6), 0.5, 6.0)
	EventBus.camera_impact.emit(global_position, Balance.WALK_CHAIN_IMPACT)
	Sfx.play_group_at("sfx_hit_armour", global_position, 4.0)
	cut.emit()
	queue_redraw()


## A stake and a run of links to the ground, in iron, with the links drawn
## apart once it is cut. The painted version stands in front of this when it
## is on disk; the drawing is what keeps the chain from being invisible before
## then, since a chain nobody can see is a stop nobody can finish.
func _draw() -> void:
	if _art != null:
		var size: Vector2 = _art.get_size()
		draw_texture_rect(_art, Rect2(Vector2(-size.x * 0.5, -size.y), size), false,
			Color(0.55, 0.55, 0.6) if _done else Color.WHITE)
		return
	var iron := Color(0.32, 0.34, 0.38)
	var rim := Color(0.62, 0.64, 0.7)
	# The stake.
	draw_rect(Rect2(-7.0, -64.0, 14.0, 64.0), iron)
	draw_rect(Rect2(-9.0, -70.0, 18.0, 8.0), rim)
	# The links, along the ground.
	var gap: float = 26.0 if _done else 18.0
	for index: int in 6:
		var at := Vector2(12.0 + float(index) * gap, -6.0 + (4.0 if index % 2 == 1 else 0.0))
		draw_arc(at, 8.0, 0.0, TAU, 14, rim if index % 2 == 0 else iron, 3.5)
	if not _done and _worked > 0.0:
		# Heat where it is being worked.
		draw_circle(Vector2(12.0, -6.0), 6.0 + progress() * 8.0, Color(1.0, 0.7, 0.3, 0.55))
