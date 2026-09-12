class_name DungeonChest
extends Node2D

## The guardian's chest: what a cleared stage is worth, in a box you open
## (owner brief, 2026-09-12: "a chest with a juicy loot burst").
##
## The stage's spoils were already banked the moment the guardian fell; the
## chest is where they *happen*. Opening it bursts the stage's currency across
## the floor as drops to run through, and names the gear it holds - which is
## carried out at the exit with the rest, so nothing left on this floor is
## lost when it collapses. A stage whose chest is never opened still pays at
## the exit: the chest is the fun, not the fee.

const GROUP: StringName = &"dungeon_chests"

var arena: RiftArena = null
var stage: int = 1

var _sprite: Sprite2D
var _glow: Sprite2D
var _life: float = 0.0
var _opened: bool = false
var _prompting: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_glow = Sprite2D.new()
	_glow.texture = LightKit.falloff_texture()
	_glow.modulate = Balance.LOOT_GLOW_COLOUR
	_glow.scale = Vector2.ONE * (Balance.RAID_CHEST_GLOW * 1.4
		/ maxf(LightKit.falloff_texture().get_width(), 1.0))
	_glow.z_index = -1
	add_child(_glow)
	_sprite = Sprite2D.new()
	var art: String = Balance.LOOT_ART_FORMAT % RaidChest.RELIC_ART_ID
	if ResourceLoader.exists(art):
		_sprite.texture = load(art)
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	_sprite.scale = Vector2.ONE * Balance.DUNGEON_CHEST_SCALE
	add_child(_sprite)
	ShadowKit.add_contact(self, _sprite)
	# It lands: a thump, a ring and a spray, so the vault says the fight is won.
	Vfx.ring(global_position, Balance.RAID_CHEST_GLOW, Balance.LOOT_GLOW_COLOUR, 0.6, 5.0)
	Vfx.spark(global_position, Balance.LOOT_GLOW_COLOUR, 14, Vector2.UP, 220.0)
	Sfx.play("sfx_loot_drop")


func _process(delta: float) -> void:
	_life += delta
	if _opened:
		# Opened: it sits and fades, its glow gone.
		if _sprite != null:
			_sprite.modulate = _sprite.modulate.lerp(Color(0.6, 0.6, 0.6, 0.5), delta * 1.5)
		return
	if _sprite != null:
		_sprite.position.y = sin(_life * 2.2) * 2.0
	if _glow != null:
		_glow.modulate.a = 0.6 + 0.3 * sin(_life * 3.1)
	if arena == null:
		return
	var who: Hero = Hero.nearest_on_field(get_tree(), global_position, Balance.DUNGEON_CHEST_REACH)
	if who == null or not who.is_local_player():
		_say("", "")
		return
	_say("Open the chest", "OPEN")
	var source := who.get("input") as HeroInput
	if source == null or not source.pressed(HeroInput.BUTTON_INTERACT):
		return
	_say("", "")
	_opened = true
	if _glow != null:
		_glow.visible = false
	arena.open_chest(self)


func is_opened() -> bool:
	return _opened


func _say(text: String, button: String) -> void:
	var wanted: bool = not text.is_empty()
	if wanted == _prompting and not wanted:
		return
	_prompting = wanted
	EventBus.interact_prompt.emit(text, button)


func _exit_tree() -> void:
	if _prompting:
		_prompting = false
		EventBus.interact_prompt.emit("", "")
