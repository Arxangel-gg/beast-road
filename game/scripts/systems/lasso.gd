class_name Lasso
extends Node2D

## The rope thrown at an animal to take it alive.
##
## Owner brief, 2026-09-16: taming "should not be with killing the wildlife but
## similar to pokemon that involves lowering its health to have a higher chance
## and something else to catch the wildlife to tame it, maybe a lasso throw ...
## ensure that it works procedurally and perfectly so that the lasso can properly
## wrap around the assets at the proper anchor location and orientation for all
## wildlife so that it doesn't look awkward."
##
## **It is thrown as ammunition, which is why it needed no new button.** The pad
## is full - every face button, shoulder, stick, D-pad direction and both
## triggers are spoken for, and that is a recorded constraint in this project
## rather than an opinion. A snare is a thing you nock and throw, so it rides the
## bow's own trigger, the bow's own aim, the ammunition cycle, the ammunition
## counts and the crafting that already exist. Cycling to the Snare and pulling
## the trigger is the whole control scheme.
##
## **The wrap is measured off the animal, never guessed.** Every species is a
## different size and a different shape, and a rope drawn at a fixed radius sits
## inside a bear and around a rabbit's postcode. The loop is sized from the
## sprite's *drawn* width and height, seated at the animal's own body centre
## rather than its feet, and squashed to the same ellipse every ring in this game
## uses - the camera looks down and slightly along, so a true circle round a body
## reads as a hoop standing up. It leans with the animal's facing, so the rope
## sits across the shoulders rather than across the picture.
##
## **Nothing here decides whether the animal is caught.** `Taming` owns that, and
## this asks it once, when the rope closes. A presentation that also rolled would
## be a second place the odds live.

enum State { FLYING, CLOSING, STRUGGLING, WON, LOST }

## Where it was thrown from and at, and what it is trying to take.
var field: Node = null
var thrower: Node2D = null
var target_id: int = 0

var _state: int = State.FLYING
var _at: Vector2 = Vector2.ZERO
var _from: Vector2 = Vector2.ZERO
var _heading: Vector2 = Vector2.RIGHT
var _clock: float = 0.0
var _phase_left: float = 0.0
## How tight the loop is drawn, 0 open and 1 closed on the body.
var _tight: float = 0.0
## The struggle: how many pulls are left, and where in the current one it is.
var _pulls: int = 0
var _pull_clock: float = 0.0
var _chance: float = 0.0
var _rng := RandomNumberGenerator.new()
var _spun: float = 0.0


func _ready() -> void:
	name = "Lasso"
	z_as_relative = false
	z_index = Balance.LASSO_Z
	_rng.seed = hash(str(target_id) + str(Time.get_ticks_usec()))


## Thrown. `at` is where it starts and `heading` where it is going.
func throw_from(at: Vector2, heading: Vector2) -> void:
	_from = at
	_at = at
	_heading = heading.normalized() if heading.length() > 0.001 else Vector2.RIGHT
	_state = State.FLYING
	_phase_left = Balance.LASSO_FLIGHT_SECONDS
	Sfx.play_at("sfx_dash", at, -6.0)


func _process_measured(delta: float) -> void:
	_clock += delta
	_spun += delta
	queue_redraw()
	match _state:
		State.FLYING:
			_fly(delta)
		State.CLOSING:
			_close(delta)
		State.STRUGGLING:
			_struggle(delta)
		_:
			_phase_left -= delta
			if _phase_left <= 0.0:
				queue_free()


## Out along the throw. A rope in the air is a rope with a *loop on the end of
## it*, spinning - which is what makes the throw read as a throw rather than as
## a projectile with a texture.
func _fly(delta: float) -> void:
	_phase_left -= delta
	var quarry: Node2D = _quarry()
	if quarry != null:
		# It leads the animal rather than flying at where it was: a rope thrown
		# at a running deer and landing behind it is a miss the player did not
		# make.
		_heading = _heading.slerp((quarry.global_position - _at).normalized(),
			clampf(Balance.LASSO_HOMING * delta, 0.0, 1.0))
	_at += _heading * Balance.LASSO_SPEED * delta
	if quarry != null and _at.distance_to(_body_centre(quarry)) <= Balance.LASSO_CATCH_REACH:
		_state = State.CLOSING
		_phase_left = Balance.LASSO_CLOSE_SECONDS
		Sfx.play_at("sfx_hit_flesh", _at, -8.0)
		return
	if _phase_left <= 0.0 or _at.distance_to(_from) > Balance.LASSO_RANGE:
		_miss()


## The loop closing on the body. Where the odds are asked, once.
func _close(delta: float) -> void:
	_phase_left -= delta
	_tight = 1.0 - clampf(_phase_left / maxf(Balance.LASSO_CLOSE_SECONDS, 0.01), 0.0, 1.0)
	var quarry: Node2D = _quarry()
	if quarry == null:
		_miss()
		return
	_at = _body_centre(quarry)
	if _phase_left > 0.0:
		return
	_chance = Taming.chance_for(target_id, field)
	_pulls = Balance.LASSO_PULLS
	_state = State.STRUGGLING
	_pull_clock = 0.0
	Vfx.ring(_at, Balance.LASSO_LOOP_BASE, Color(Balance.LASSO_ROPE, 0.8), 0.3, 3.0)
	Vfx.dust(_at, Color(0.5, 0.44, 0.36), 6, 40.0)
	EventBus.camera_impact.emit(_at, Balance.LASSO_SHAKE)


## **The struggle**, which is the whole drama of the thing.
##
## Three pulls, each one a beat where the rope goes taut and the animal heaves
## against it. The odds were settled the moment the loop closed - this does not
## re-roll them - but the player does not know the answer until the last pull,
## which is what makes watching it worth anything. A capture decided and shown
## instantly would be a dice roll with a rope drawn on it.
func _struggle(delta: float) -> void:
	var quarry: Node2D = _quarry()
	if quarry == null:
		_miss()
		return
	_at = _body_centre(quarry)
	_pull_clock += delta
	if _pull_clock < Balance.LASSO_PULL_SECONDS:
		return
	_pull_clock = 0.0
	_pulls -= 1
	Vfx.spark(_at, Balance.LASSO_ROPE, 5, Vector2.UP, 130.0)
	Sfx.play_at("sfx_hit_flesh", _at, -12.0)
	EventBus.camera_impact.emit(_at, Balance.LASSO_SHAKE * 0.5)
	if _pulls > 0:
		return
	if _rng.randf() < _chance:
		_won(quarry)
	else:
		_broke_free(quarry)


func _won(quarry: Node2D) -> void:
	_state = State.WON
	_phase_left = 0.35
	_tight = 1.0
	Taming.take(target_id, field)
	Vfx.ring(_at, 90.0, Color(1.0, 0.92, 0.6, 0.85), 0.45, 4.0)
	Vfx.rays(_at, Color(1.0, 0.9, 0.55), 8, 80.0)
	Sfx.play_at("sfx_ui_confirm", _at, 0.0)
	EventBus.camera_impact.emit(_at, Balance.LASSO_SHAKE * 1.4)


func _broke_free(quarry: Node2D) -> void:
	_state = State.LOST
	_phase_left = 0.3
	Vfx.denied(quarry.global_position, "It broke free")
	Vfx.spark(_at, Balance.LASSO_ROPE, 10, Vector2.UP, 220.0)
	Sfx.play_at("sfx_fish_escape", _at, -3.0)
	Taming.scare(target_id, field)


func _miss() -> void:
	_state = State.LOST
	_phase_left = 0.25
	Vfx.dust(_at, Color(0.5, 0.45, 0.38), 5, 30.0)


# --- Where the rope goes --------------------------------------------------------

func _quarry() -> Node2D:
	if target_id == 0:
		return null
	var held: Variant = instance_from_id(target_id)
	if held == null or not is_instance_valid(held as Object):
		return null
	return held as Node2D


## **The middle of the body, not the feet.**
##
## A wildlife sprite stands with its feet on its node's position and its art
## lifted above it, so a rope drawn at `global_position` lies on the ground
## behind the animal. This finds the drawn rectangle and takes its middle, so the
## loop sits across the body whatever the species is.
func _body_centre(quarry: Node2D) -> Vector2:
	var sprite := quarry as Sprite2D
	if sprite == null or sprite.texture == null:
		return quarry.global_position
	var drawn: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
	return quarry.global_position + Vector2(0.0, sprite.offset.y * sprite.scale.y
		+ drawn.y * 0.5)


## How wide and tall to draw the loop for this animal: measured off its own
## drawn size, never a constant. A fixed radius sits inside a bear and around a
## rabbit's postcode.
func _loop_size(quarry: Node2D) -> Vector2:
	var sprite := quarry as Sprite2D
	if sprite == null or sprite.texture == null:
		return Vector2.ONE * Balance.LASSO_LOOP_BASE
	var drawn: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
	return Vector2(maxf(drawn.x * Balance.LASSO_LOOP_SHARE, 14.0),
		maxf(drawn.y * Balance.LASSO_LOOP_SHARE, 10.0) * Balance.LASSO_LOOP_SQUASH)


func _draw_measured() -> void:
	var quarry: Node2D = _quarry()
	var head: Vector2 = to_local(_at)
	var hand: Vector2 = to_local(thrower.global_position
		+ Vector2(0.0, -Balance.LASSO_HAND_LIFT)) if thrower != null \
		and is_instance_valid(thrower) else to_local(_from)
	# **The rope, as a rope.** A slack curve between the hand and the loop rather
	# than a straight line: a taut line between two moving things reads as a
	# laser, and the sag is the single cheapest thing that says "rope".
	_draw_the_rope(hand, head)
	if quarry == null:
		return
	_draw_the_loop(head, _loop_size(quarry), _facing_lean(quarry))


## A slack line, sagging by how far it has to reach and pulled straight as the
## rope goes taut in the struggle.
func _draw_the_rope(hand: Vector2, head: Vector2) -> void:
	var span: float = hand.distance_to(head)
	var sag: float = span * Balance.LASSO_SAG * (1.0 - _tight * 0.85)
	var points := PackedVector2Array()
	for step: int in Balance.LASSO_ROPE_STEPS + 1:
		var t: float = float(step) / float(Balance.LASSO_ROPE_STEPS)
		var along: Vector2 = hand.lerp(head, t)
		# A parabola, plus a shiver while something is fighting it.
		along.y += sin(t * PI) * sag
		if _state == State.STRUGGLING:
			along += Vector2(sin(t * 14.0 + _clock * 30.0), 0.0) \
				* Balance.LASSO_SHIVER * sin(t * PI)
		points.append(along)
	draw_polyline(points, Color(Balance.LASSO_ROPE, 0.95), Balance.LASSO_WIDTH)
	draw_polyline(points, Color(0.0, 0.0, 0.0, 0.3), Balance.LASSO_WIDTH * 1.8)


## **The loop, seated on the body.**
##
## Sized from the animal, squashed to the same ellipse every ring in this game
## uses - the camera looks down and slightly along - and leaned onto the
## animal's facing so it sits across the shoulders rather than across the
## picture. In flight it is open and spinning; closing, it draws in.
func _draw_the_loop(at: Vector2, size: Vector2, lean: float) -> void:
	var open: float = lerpf(Balance.LASSO_LOOP_OPEN, 1.0, _tight)
	var points := PackedVector2Array()
	var steps: int = 22
	for step: int in steps + 1:
		var angle: float = TAU * float(step) / float(steps)
		# The spin is the loop turning about its own axis, which only reads
		# while it is open - a closed rope on a body does not spin.
		var spin: float = _spun * Balance.LASSO_SPIN * (1.0 - _tight)
		var on := Vector2(cos(angle + spin) * size.x * open,
			sin(angle + spin) * size.y * open)
		points.append(at + on.rotated(lean))
	draw_polyline(points, Color(0.0, 0.0, 0.0, 0.35), Balance.LASSO_WIDTH * 1.9)
	draw_polyline(points, Color(Balance.LASSO_ROPE, 0.95), Balance.LASSO_WIDTH)


## How far the loop is tilted to sit on the animal rather than on the screen.
## Taken from which way it is facing, so a rope on a deer running east lies
## across the deer.
func _facing_lean(quarry: Node2D) -> float:
	var sprite := quarry as Sprite2D
	if sprite == null:
		return 0.0
	return Balance.LASSO_LOOP_LEAN * (-1.0 if sprite.flip_h else 1.0)


## `FrameProfile` bucket "d_lasso": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_lasso", started)


## `FrameProfile` bucket "p_lasso": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_lasso", started)
