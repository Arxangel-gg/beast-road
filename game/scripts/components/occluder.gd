class_name Occluder
extends Node

## Fades a structure when the hero is behind it.
##
## Two problems, one fix. A tall sprite drawn at its build spot hides whatever is
## behind it, and the hero was drawn on top of towers regardless of position -
## so standing behind a tower both looked wrong and hid the hero anyway.
##
## Y-sorting fixes the draw order. This fixes the hiding: a structure the hero is
## standing behind becomes semi-transparent, so the hero is visible through it
## while the structure still reads as being in front.

@export var sprite: Sprite2D

## World-space vertical offset of the sprite's base. The hero counts as "behind"
## when they are above this line.
@export var base_offset: float = 0.0

var _alpha: float = 1.0
var _owner: Node2D


func _ready() -> void:
	_owner = get_parent() as Node2D
	if sprite == null or _owner == null:
		set_process(false)


func _process(delta: float) -> void:
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	var wanted: float = 1.0
	if hero != null and is_instance_valid(hero):
		var offset: Vector2 = hero.global_position - _owner.global_position
		# Behind means above the base line and close enough horizontally to
		# actually be obscured. Distance alone would fade towers the hero is
		# merely standing near.
		var behind: bool = offset.y < base_offset
		var overlapping: bool = absf(offset.x) < Balance.OCCLUDER_RANGE \
			and offset.y > -Balance.OCCLUDER_RANGE * 2.0
		if behind and overlapping:
			wanted = Balance.OCCLUDER_ALPHA

	if is_equal_approx(_alpha, wanted):
		return
	_alpha = move_toward(_alpha, wanted, Balance.OCCLUDER_FADE_SPEED * delta)
	sprite.modulate.a = _alpha
