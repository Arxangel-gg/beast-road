class_name Occluder
extends Node

## Fades this structure while the hero is standing behind it.
##
## Judged entirely from the *hero relative to this sprite* - never from world
## coordinates. An earlier version leaned on a world-space comparison and the
## result was structures reacting to where the origin was rather than to where
## the player was.
##
## The test is deliberately two-part. Being higher up the screen is not enough on
## its own: the hero also has to be within the sprite's own width, or every tower
## in the northern half of the map would fade whenever the player walked north.
##
## The structure stays visible and keeps drawing in front - it just becomes
## translucent, so the hero reads through it without the depth cue being lost.

@export var sprite: Sprite2D

## Extra room above the sprite's base counted as "behind". Larger values make a
## structure fade a little earlier as the hero walks up behind it.
@export var behind_margin: float = 24.0

var _alpha: float = 1.0
var _owner: Node2D
var _half_width: float = 60.0
var _height: float = 120.0


func _ready() -> void:
	_owner = get_parent() as Node2D
	if sprite == null or _owner == null:
		set_process(false)
		return
	_measure()


## Bounds come from the sprite itself, so a 192px tower and a 384px town core get
## proportionate trigger areas without either being hand-tuned.
## Public so an owner that swaps its texture can refresh the trigger bounds.
func remeasure() -> void:
	_measure()


func _measure() -> void:
	if sprite.texture == null:
		return
	var size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
	_half_width = maxf(size.x * 0.5, 8.0)
	_height = maxf(size.y, 16.0)


func _process(delta: float) -> void:
	var wanted: float = 1.0

	# **Every hero, not the player's.** Scenery that only fades for whoever the
	# HUD is following leaves the other three fighting behind a wall they cannot
	# see through - and in co-op the hero this used to ask for was often not even
	# on the same part of the field.
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Node2D
		if hero == null or not is_instance_valid(hero):
			continue
		# Everything below is in this sprite's local frame.
		var offset: Vector2 = hero.global_position - _owner.global_position

		# Behind: higher up the screen than this sprite's base, but not so far up
		# that the sprite could not be covering them.
		var behind: bool = offset.y < behind_margin and offset.y > -_height
		# Overlapping: within the sprite's own width, with a little tolerance.
		var overlapping: bool = absf(offset.x) < _half_width + Balance.OCCLUDER_SIDE_MARGIN

		if behind and overlapping:
			wanted = Balance.OCCLUDER_ALPHA
			break

	if is_equal_approx(_alpha, wanted):
		return
	_alpha = move_toward(_alpha, wanted, Balance.OCCLUDER_FADE_SPEED * delta)
	sprite.modulate.a = _alpha
