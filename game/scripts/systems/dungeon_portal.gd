class_name DungeonPortal
extends Node2D

## A way out of a rift, or a way further down (owner brief, 2026-09-12:
## "exit portal", and the dungeon's stairs between stages).
##
## A door you walk to and take, rather than a button alone: the HUD still has
## its two buttons at the door, but the place itself should say where the way
## out is - especially while the stage is collapsing and the way out is the
## whole game. Wears the gate art the battlefield already has, so a portal in
## the deep looks like the gate it answers to.

enum Kind { EXIT, STAIRS }

const GROUP: StringName = &"dungeon_portals"

var kind: Kind = Kind.EXIT
var arena: RiftArena = null
## Whether this door is open right now. The exit opens at the door and during
## a collapse; the stairs only at the door.
var open: bool = true

var _sprite: Sprite2D
var _glow: Sprite2D
var _life: float = 0.0
var _prompting: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_glow = Sprite2D.new()
	_glow.texture = LightKit.falloff_texture()
	_glow.modulate = Balance.DUNGEON_EXIT_GLOW if kind == Kind.EXIT else Balance.DUNGEON_STAIRS_GLOW
	_glow.scale = Vector2.ONE * (Balance.DUNGEON_PORTAL_GLOW
		/ maxf(LightKit.falloff_texture().get_width(), 1.0))
	_glow.z_index = -1
	add_child(_glow)
	_sprite = Sprite2D.new()
	var art: String = RiftGates.RIFT_ART if kind == Kind.EXIT else RiftGates.DUNGEON_ART
	if ResourceLoader.exists(art):
		_sprite.texture = load(art)
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	_sprite.scale = Vector2.ONE * Balance.DUNGEON_PORTAL_SCALE
	add_child(_sprite)
	Vfx.ring(global_position, Balance.DUNGEON_PORTAL_REACH, _glow.modulate, 0.6, 4.0)


func _process(delta: float) -> void:
	_life += delta
	var pulse: float = 0.5 + 0.5 * sin(_life * 2.6)
	if _glow != null:
		_glow.modulate.a = 0.35 + 0.35 * pulse
	if _sprite != null:
		_sprite.modulate = Color(1.0, 1.0, 1.0, 0.85 + 0.15 * pulse)
	if not open or arena == null:
		_say("", "")
		return
	var who: Hero = Hero.nearest_on_field(get_tree(), global_position, Balance.DUNGEON_PORTAL_REACH)
	if who == null or not who.is_local_player():
		_say("", "")
		return
	_say("Leave the %s" % arena.what() if kind == Kind.EXIT else "Go deeper", "TAKE")
	var source := who.get("input") as HeroInput
	if source == null or not source.pressed(HeroInput.BUTTON_INTERACT):
		return
	_say("", "")
	if kind == Kind.STAIRS:
		arena.descend()
	else:
		arena.take_exit()


## The prompt, said once per change through the road the well and the gates
## use.
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
