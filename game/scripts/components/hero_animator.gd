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

## Frames per second per state, and whether it repeats.
##
## The attack rates are not chosen by eye: each swing's sheet has to finish in
## the time `hero_attack.gd` actually gives that step, or the sprite is still
## winding up when the damage lands. Step totals are windup + active + recovery
## from Balance — 0.32s, 0.31s and 0.57s — over nine frames.
const STATES: Dictionary = {
	"idle":      {"fps": 8.0,  "loop": true},
	"walk":      {"fps": 12.0, "loop": true},
	"attack_1a": {"fps": 28.0, "loop": false},
	"attack_1b": {"fps": 28.0, "loop": false},
	"attack_2":  {"fps": 29.0, "loop": false},
	"attack_3":  {"fps": 16.0, "loop": false},
	"hurt":      {"fps": 18.0, "loop": false},
	"dash":      {"fps": 56.0, "loop": false},
	"death":     {"fps": 7.0,  "loop": false},
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


func _ready() -> void:
	for state: String in STATES:
		var path: String = "res://art/hero/hero_%s.png" % state
		if ResourceLoader.exists(path):
			_sheets[state] = load(path) as Texture2D
	if sprite != null and not _sheets.is_empty():
		sprite.region_enabled = true
		sprite.centered = true


## True when there is any frame art at all. The hero checks this once so a build
## with no sheets keeps its old static-sprite behaviour untouched.
func has_frames() -> bool:
	return not _sheets.is_empty()


func has_state(state: String) -> bool:
	return _sheets.has(state)


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
	if not _sheets.has(state):
		return
	if _state == state and not restart:
		_playing = true
		return
	_state = state
	_frame = 0.0
	_playing = true
	var sheet: Texture2D = _sheets[state]
	_frames_in_state = maxi(int(sheet.get_width() / CELL_W), 1)


## Walk plays faster when the hero moves faster. 1.0 is the authored rate.
func set_speed_scale(scale: float) -> void:
	_speed_scale = clampf(scale, 0.2, 2.5)


func current_state() -> String:
	return _state


func _process(delta: float) -> void:
	if sprite == null or _state.is_empty() or not _sheets.has(_state):
		return
	var config: Dictionary = STATES[_state]

	if _playing:
		var rate: float = float(config["fps"])
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

	sprite.texture = _sheets[_state]
	sprite.region_rect = Rect2(
		float(int(_frame) * CELL_W), float(_direction * CELL_H),
		float(CELL_W), float(CELL_H))
