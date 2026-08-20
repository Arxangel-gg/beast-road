class_name RaidKey
extends Node2D

## A key lying in a raid camp. Picked up by walking over it; opens one locked
## chest, whichever the player reaches next.
##
## Keys are not bound to a particular chest on purpose. Matching a specific key
## to a specific lock means a player who finds the wrong one has been given
## nothing, and in a camp they have sixty seconds in, that reads as the game
## wasting their time rather than as a puzzle.

const GROUP: StringName = &"raid_keys"

var _sprite: Sprite2D
var _life: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	var glow := Sprite2D.new()
	glow.texture = LightKit.falloff_texture()
	glow.modulate = Balance.RAID_KEY_GLOW
	glow.scale = Vector2.ONE * (Balance.RAID_CHEST_GLOW * 0.7
		/ maxf(LightKit.falloff_texture().get_width(), 1.0))
	glow.z_index = -1
	add_child(glow)

	_sprite = Sprite2D.new()
	_sprite.texture = IconKit.ui("relic")
	_sprite.modulate = Balance.RAID_KEY_GLOW
	_sprite.scale = Vector2.ONE * 0.7
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	add_child(_sprite)


func _process(delta: float) -> void:
	_life += delta
	if _sprite != null:
		_sprite.rotation = sin(_life * 1.6) * 0.25
		_sprite.position.y = sin(_life * 2.6) * 3.0
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	if hero == null or not is_instance_valid(hero):
		return
	if hero.global_position.distance_to(global_position) > Balance.RAID_REACH:
		return
	RunState.raid_keys += 1
	Sfx.play_group("loot_collect")
	EventBus.raid_key_taken.emit(RunState.raid_keys)
	queue_free()
