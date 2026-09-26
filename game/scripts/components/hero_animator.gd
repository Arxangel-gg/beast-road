class_name HeroAnimator
extends Node

## Eight-direction frame playback for the hero, layered under SpriteAnimator.
##
## This is the first thing in the game to use real animation frames. Everything
## else still moves by transform alone, which is why the two are separate
## components rather than one:
##
##   HeroAnimator   owns `sprite.texture` and `sprite.region_rect` — which frame.
##   SpriteAnimator owns `sprite.position`, `scale` and `rotation` — how it moves.
##
## Neither writes the other's channel, so the procedural juice keeps running on
## top of the frames rather than being replaced by them. That is an owner
## decision, and it is the reason the frames were generated neutral: the walk
## sheet carries the stride and the cloak, and the engine still supplies bounce,
## lean, footfall squash, recoil and the death topple. Baking those into the
## frames would double them.
##
## Sheets are `res://art/hero/hero_<state>.png`, rows = the 8 facings in engine
## index order, columns = frames. Built by `tools/pack_hero_frames.py`.
##
## Missing sheets are not an error. A state with no sheet leaves the sprite on
## whatever it was showing, so a partial art pass degrades to the old static
## sprite instead of a blank screen.

## Cell size, matching `tools/pack_hero_frames.py`. Derived from the widest and
## tallest content across all 648 frames rather than rounded to a power of two:
## nine sheets at 192 square cost the whole frame-hitch budget on a 3070 Ti —
## 55 fps with three hitches a minute, against 64 fps and none without them.
const CELL_W: int = 168
const CELL_H: int = 160
const DIRECTION_COUNT: int = 8

## The facings in row order, as the rig names them - the dressed Warden's socket
## tables are keyed by these.
const FACING_NAMES: Array[String] = [
	"east", "south-east", "south", "south-west",
	"west", "north-west", "north", "north-east",
]

## Where the painted sheets draw the Warden's feet, below the sprite's centre:
## the bottom of the figure sits at 130-135 of a 160 cell across the facings.
## The dressed Warden stands its own feet here, so the shadow, the bars and the
## collision - all placed against the old art - stay exactly where they were.
const PAINTED_FEET_BELOW_CENTRE: float = 54.0

## Frames per second per state, and whether it repeats.
##
## The attack rates are not chosen by eye: each swing's sheet has to finish in
## the time `hero_attack.gd` actually gives that step, or the sprite is still
## winding up when the damage lands. Step totals are windup + active + recovery
## from Balance — 0.32s, 0.31s and 0.57s — over nine frames.
const STATES: Dictionary = {
	"idle":      {"fps": 8.0,  "loop": true},
	"walk":      {"fps": 12.0, "loop": true},
	# **Sprinting** (owner, 2026-09-16). Listed so `hero_sprint.png` drops in the
	# day it is drawn; until then `has_state("sprint")` is false and the hero
	# runs on the walk sheet driven faster, which is what the note at the top of
	# this file means by a partial art pass degrading rather than breaking.
	"sprint":    {"fps": 16.0, "loop": true},
	"attack_1a": {"fps": 28.0, "loop": false},
	"attack_1b": {"fps": 28.0, "loop": false},
	"attack_2":  {"fps": 29.0, "loop": false},
	"attack_3":  {"fps": 16.0, "loop": false},
	"hurt":      {"fps": 18.0, "loop": false},
	"dash":      {"fps": 56.0, "loop": false},
	"death":     {"fps": 7.0,  "loop": false},
	# The loose, paced off the *fastest* bow rather than the slowest.
	#
	# `hero_ranged.request()` emits the shot immediately and then sets
	# `draw_time` as the cooldown, so this animation is never what the arrow
	# waits for. What matters is the other end: the shortbow's 0.54s is the
	# shortest gap between two shots, and an animation slower than that would
	# still be lowering the bow when the next arrow left it. Nine frames at 20
	# fps is 0.45s, which clears the shortbow and simply plays again on the
	# slower weapons - the hand ballista's 2.10s is a pause between shots, not
	# a longer draw to fill.
	"shoot":     {"fps": 20.0, "loop": false},
}

## A one-shot state finished. The hero uses this to fall back to idle or walk.
signal finished(state: String)

@export var sprite: Sprite2D

var _sheets: Dictionary = {}
var _state: String = ""
var _frame: float = 0.0
var _frames_in_state: int = 1
var _direction: int = 2  # south, the base facing
var _playing: bool = false
var _speed_scale: float = 1.0

# The dressed Warden (2026-09-25). Empty until `dress` is called with a body
# whose art is on disk; while it is, everything below plays the painted sheets
# exactly as it always did.
var _outfit: Dictionary = {}
var _dress_sheets: Dictionary = {}
var _state_drawn: String = ""
var _layers: DressLayers = null


func _ready() -> void:
	for state: String in STATES:
		var path: String = "res://art/hero/hero_%s.png" % state
		if ResourceLoader.exists(path):
			_sheets[state] = load(path) as Texture2D
	if sprite != null and not _sheets.is_empty():
		sprite.region_enabled = true
		sprite.centered = true


## Put the Warden in an outfit from `WardenDress.outfit`. Does nothing - the
## painted sheets keep playing - until that body's dress art is on disk.
func dress(outfit: Dictionary) -> void:
	var body: String = String(outfit.get("body", ""))
	if body.is_empty() or not WardenDress.available(body):
		_outfit = {}
		if _layers != null:
			_layers.set_worn(false)
		return
	var changed_body: bool = String(_outfit.get("body_layer", "")) != String(outfit.get("body_layer", ""))
	_outfit = outfit
	if changed_body:
		_dress_sheets.clear()
	if _layers == null and sprite != null:
		_layers = DressLayers.attach(sprite)
	if _layers != null:
		_layers.set_worn(true)
		_layers.wear(outfit)
	if sprite != null:
		sprite.region_enabled = true
		sprite.centered = false
	# A state already playing is re-read in the new outfit's combo.
	if not _state.is_empty():
		_state_drawn = _resolve(_state)


func dressed() -> bool:
	return not _outfit.is_empty()


## True when there is any frame art at all. The hero checks this once so a build
## with no sheets keeps its old static-sprite behaviour untouched.
func has_frames() -> bool:
	return dressed() or not _sheets.is_empty()


func has_state(state: String) -> bool:
	if dressed():
		return not WardenDress.meta(String(_outfit["body"]), _resolve(state)).is_empty()
	return _sheets.has(state)


## The state actually drawn: a two-handed weapon plays the two-handed combo.
func _resolve(state: String) -> String:
	if not dressed():
		return state
	if int(_outfit.get("grip", 0)) == GearData.Grip.TWO_HAND \
			and WardenDress.TWO_HANDED_STATES.has(state):
		return WardenDress.TWO_HANDED_STATES[state]
	return state


func _dress_sheet(state: String) -> Texture2D:
	if not _dress_sheets.has(state):
		_dress_sheets[state] = WardenDress.texture(
			WardenDress.art_root + String(_outfit["body_layer"]) + "/" + state + ".png")
	return _dress_sheets[state]


## Which way the character faces, from a direction vector.
##
## Index runs clockwise from east because screen Y grows downward, which makes
## this a single rounded division with no lookup table — and it is the same
## order the sheet rows are packed in.
func set_facing(direction: Vector2) -> void:
	if direction.length_squared() < 0.0001:
		return
	var step: float = TAU / float(DIRECTION_COUNT)
	_direction = posmod(int(round(direction.angle() / step)), DIRECTION_COUNT)


## Starts a state. Restarting the state already playing is ignored unless
## `restart` is set, so holding a movement key does not reset the walk cycle to
## frame zero every frame.
func play(state: String, restart: bool = false) -> void:
	if not has_state(state):
		return
	if _state == state and not restart:
		_playing = true
		return
	_state = state
	_frame = 0.0
	_playing = true
	if dressed():
		_state_drawn = _resolve(state)
		var meta: Dictionary = WardenDress.meta(String(_outfit["body"]), _state_drawn)
		_frames_in_state = maxi(int(meta.get("frames", 1)), 1)
		return
	var sheet: Texture2D = _sheets[state]
	_frames_in_state = maxi(int(sheet.get_width() / CELL_W), 1)


## Walk plays faster when the hero moves faster. 1.0 is the authored rate.
func set_speed_scale(scale: float) -> void:
	_speed_scale = clampf(scale, 0.2, 2.5)


func current_state() -> String:
	return _state


## Whether a one-shot is still running. Anything driving this animator from a
## movement state has to ask, or it plays "idle" over a swing every frame -
## which is how the Hold's simulated Wardens stood at the forge doing nothing
## while the swing was requested on the tick (found 2026-09-22).
func mid_gesture() -> bool:
	if _state.is_empty() or not STATES.has(_state):
		return false
	return _playing and not bool((STATES[_state] as Dictionary)["loop"])


func _process(delta: float) -> void:
	if sprite == null or _state.is_empty() or not has_state(_state):
		return
	var config: Dictionary = STATES[_state]

	if _playing:
		var rate: float = float(config["fps"])
		# The rates were set so nine painted frames finish in the time the
		# attack step gives them. A dressed sheet may have seven or eight, and
		# a one-shot has to take the same time either way, or the sprite is
		# still winding up when the blow lands.
		if dressed() and not bool(config["loop"]):
			rate *= float(_frames_in_state) / 9.0
		if _state == "walk":
			rate *= _speed_scale
		_frame += delta * rate
		if _frame >= float(_frames_in_state):
			if bool(config["loop"]):
				_frame = fmod(_frame, float(_frames_in_state))
			else:
				# Hold the last frame rather than snapping back. A death that
				# loops back to standing is worse than no animation at all.
				_frame = float(_frames_in_state) - 1
				_playing = false
				finished.emit(_state)

	if dressed():
		_show_dressed()
		return
	sprite.texture = _sheets[_state]
	sprite.region_rect = Rect2(
		float(int(_frame) * CELL_W), float(_direction * CELL_H),
		float(CELL_W), float(CELL_H))


## One frame of the dressed Warden: the body's cell, stood so its feet are
## where the painted Warden's were, and every layer laid on the same frame.
func _show_dressed() -> void:
	var body: String = String(_outfit["body"])
	var meta: Dictionary = WardenDress.meta(body, _state_drawn)
	var sheet: Texture2D = _dress_sheet(_state_drawn)
	if meta.is_empty() or sheet == null:
		return
	var cell: Array = meta["cell"]
	var origin: Array = meta["origin"]
	var feet: Array = (meta.get("foot", {}) as Dictionary).get(FACING_NAMES[_direction], [0.0, 0.0])
	var frame: int = mini(int(_frame), _frames_in_state - 1)
	sprite.texture = sheet
	sprite.region_rect = Rect2(float(frame * int(cell[0])), float(_direction * int(cell[1])),
		float(cell[0]), float(cell[1]))
	# The cell's top-left, placed so the canvas's feet land on the painted
	# Warden's feet: centre-relative, because SpriteAnimator's scale and lean
	# pivot on the sprite's origin.
	var offset := Vector2(float(origin[0]) - float(feet[0]),
		float(origin[1]) - float(feet[1]) + PAINTED_FEET_BELOW_CENTRE)
	sprite.offset = offset
	if _layers != null:
		_layers.show_frame(_state_drawn, frame, _direction, offset, meta)
