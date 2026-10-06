class_name DungeonCache
extends Node2D

## A cache off the way: a crate in a room the main line does not pass, holding
## a share of the stage's currency (owner item 29, 2026-10-06: "loot chests,
## interactables").
##
## **It moves where a stage is paid, never how much.** The vault's chest and
## the exit pay the stage's figure less the caches' shares; a cache broken
## open pays its share on the floor as drops; a cache left shut when the
## stage ends forfeits it. So the sum when every cache is opened is exactly
## the stage's figure (`RiftArena._stage_resources`), and what the player
## decides is whether to go and look for them against the clock - which is
## the whole reason a maze has rooms off the way. `rift_check` holds the sum.
##
## Opened the way the guardian's chest is opened: walk up, press Interact.

const GROUP: StringName = &"dungeon_caches"
const PROMPT_OWNER: StringName = &"dungeon_cache"
const ART_ID: String = "supply_crate"

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
	_glow.modulate = Color(Balance.LOOT_GLOW_COLOUR, 0.55)
	_glow.scale = Vector2.ONE * (Balance.RAID_CHEST_GLOW * 0.9
		/ maxf(LightKit.falloff_texture().get_width(), 1.0))
	_glow.z_index = -1
	add_child(_glow)
	_sprite = Sprite2D.new()
	var art: String = Balance.LOOT_ART_FORMAT % ART_ID
	if ResourceLoader.exists(art):
		_sprite.texture = load(art)
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	_sprite.scale = Vector2.ONE * Balance.DUNGEON_CACHE_SCALE
	add_child(_sprite)
	ShadowKit.add_contact(self, _sprite)


func _process(delta: float) -> void:
	_life += delta
	if _opened:
		if _sprite != null:
			_sprite.modulate = _sprite.modulate.lerp(Color(0.55, 0.55, 0.55, 0.45), delta * 1.5)
		return
	if _glow != null:
		_glow.modulate.a = 0.4 + 0.2 * sin(_life * 2.6)
	if arena == null:
		return
	var who: Hero = Hero.nearest_on_field(get_tree(), global_position, Balance.DUNGEON_CHEST_REACH)
	if who == null or not who.is_local_player():
		_say("", "")
		return
	_say("Break open the cache", "OPEN")
	var source := who.get("input") as HeroInput
	if source == null or not source.pressed(HeroInput.BUTTON_INTERACT):
		return
	_say("", "")
	open()


## Opened: the share bursts on the floor, through the arena, which keeps the
## count the stage is settled by.
func open() -> void:
	if _opened:
		return
	_opened = true
	if _glow != null:
		_glow.visible = false
	if arena != null:
		arena.open_cache(self)


func is_opened() -> bool:
	return _opened


func _say(text: String, button: String) -> void:
	var wanted: bool = not text.is_empty()
	if wanted == _prompting and not wanted \
			and EventBus.prompt_owner() == PROMPT_OWNER:
		return
	if wanted:
		EventBus.point_prompt(PROMPT_OWNER, global_position)
	if not EventBus.claim_prompt(PROMPT_OWNER, text, &"", global_position):
		return
	_prompting = wanted
	EventBus.interact_prompt.emit(text, button)


func _exit_tree() -> void:
	if _prompting and EventBus.claim_prompt(PROMPT_OWNER, ""):
		_prompting = false
		EventBus.interact_prompt.emit("", "")
