class_name WardenStage
extends SubViewportContainer

## A Warden standing on a lit pedestal, drawn by the game's own animator.
##
## The Warden's Glass turns one while the player chooses a look, and the Hold's
## Warden card stands one where a portrait of the old painted Warden used to be
## (2026-09-26). **One stage for both**, because both have to show exactly what
## the road will draw: the sprite is dressed by `HeroAnimator` from
## `WardenDress.outfit` - the one function the hero, the Hold and a partner's
## copy ask - and worn through `WardenLook.dress`, so a stage cannot disagree
## with the road, and two stages cannot disagree with each other.
##
## A picture and nothing else: it reads the look and the worn gear and writes
## neither.

## The sprite is drawn at this many screen pixels to one of art.
@export var art_scale: float = 2.0
## Where the Warden's feet stand, as a share of the stage's height.
@export var feet_at: float = 0.86
## Turning on its own, a facing every `turn_seconds`.
@export var turntable: bool = true
@export var turn_seconds: float = 1.5
## How long a hand's turn holds before the turntable resumes.
const TURN_RESUME_SECONDS: float = 4.0
## The pop a change gives the Warden.
const POP_SCALE: float = 1.07
const POP_SECONDS: float = 0.22
const SOUTH: int = 2

var _viewport: SubViewport
var _stage: Node2D
var _sprite: Sprite2D
var _animator: HeroAnimator
var _pedestal: Pedestal
var _sparkles: CPUParticles2D
var _facing: int = SOUTH
var _turn_left: float = 0.0
var _resume_left: float = 0.0
var _pose: String = "idle"
var _pop: Tween = null


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	# Two enums for one idea: the canvas filter is a CanvasItem's, a viewport's
	# default is its own, and their numbers do not line up.
	if Graphics.canvas_filter() == CanvasItem.TEXTURE_FILTER_NEAREST:
		_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	else:
		_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_viewport)
	_stage = Node2D.new()
	_stage.name = "Stage"
	_viewport.add_child(_stage)
	_pedestal = Pedestal.new()
	_stage.add_child(_pedestal)
	_sprite = Sprite2D.new()
	_sprite.name = "Warden"
	var material := ShaderMaterial.new()
	material.shader = WardenLook.shader()
	_sprite.material = material
	_stage.add_child(_sprite)
	_animator = HeroAnimator.new()
	_animator.name = "Frames"
	_animator.sprite = _sprite
	_stage.add_child(_animator)
	_animator.finished.connect(_on_pose_finished)
	_sparkles = CPUParticles2D.new()
	_sparkles.name = "Sparkles"
	_sparkles.emitting = false
	_sparkles.one_shot = true
	_sparkles.amount = maxi(int(roundf(24.0 * Graphics.particle_scale())), 1)
	_sparkles.lifetime = 0.7
	_sparkles.explosiveness = 0.9
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparkles.emission_sphere_radius = 26.0
	_sparkles.direction = Vector2(0.0, -1.0)
	_sparkles.spread = 180.0
	_sparkles.initial_velocity_min = 20.0
	_sparkles.initial_velocity_max = 60.0
	_sparkles.gravity = Vector2(0.0, -30.0)
	_sparkles.scale_amount_min = 1.0
	_sparkles.scale_amount_max = 2.5
	_sparkles.position = Vector2(0.0, -40.0)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparkles.material = additive
	_stage.add_child(_sparkles)


func _ready() -> void:
	_stage.scale = Vector2(art_scale, art_scale)
	_turn_left = turn_seconds


## Dresses the Warden in `look`, wearing this account's gear or none.
func show_look(look: Dictionary, wearing_gear: bool = true) -> void:
	var outfit: Dictionary = WardenDress.outfit(look, _worn(GearData.Slot.WEAPON), _worn(GearData.Slot.ARMOUR),
		_worn(GearData.Slot.CAPE), _worn(GearData.Slot.HELMET)) if wearing_gear \
		else WardenDress.outfit(look, null, null, null, null)
	_wear(outfit, look)


## Dresses the Warden in `look` wearing another player's gear, as the four
## kinds their machine said - cleaned here, since they came off a wire.
func show_look_wearing(look: Dictionary, kinds: Array) -> void:
	var clean: Array[String] = Hero.clean_worn_kinds(kinds)
	_wear(WardenDress.outfit(look, ContentDB.gear(clean[0]), ContentDB.gear(clean[1]),
		ContentDB.gear(clean[2]), ContentDB.gear(clean[3])), look)


func _wear(outfit: Dictionary, look: Dictionary) -> void:
	_animator.dress(outfit)
	WardenLook.dress(_sprite, look)
	face(_facing)
	_animator.play(_pose)


## The Warden's animator and sprite, for a gate reading what is drawn.
func animator() -> HeroAnimator:
	return _animator


func sprite() -> Sprite2D:
	return _sprite


func face(facing: int) -> void:
	_facing = posmod(facing, HeroAnimator.DIRECTION_COUNT)
	_animator.set_facing(Vector2.from_angle(float(_facing) * TAU / float(HeroAnimator.DIRECTION_COUNT)))


## A turn by hand, which holds the turntable off for a while.
func turn(step: int) -> void:
	face(_facing + step)
	_resume_left = TURN_RESUME_SECONDS


## Stands, walks, or strikes once and goes back to what it was doing.
func pose(state: String) -> void:
	if state.begins_with("attack"):
		_animator.play(state, true)
		return
	_pose = state
	_animator.play(state)


func _on_pose_finished(state: String) -> void:
	if state.begins_with("attack"):
		_animator.play(_pose, true)


func reset_turn() -> void:
	_facing = SOUTH
	_turn_left = turn_seconds
	_resume_left = 0.0


## The Warden answers a change: it swells and settles, sparks in the colour
## chosen, and the ring under it takes that colour.
func flourish(colour: Color) -> void:
	if _pop != null and _pop.is_valid():
		_pop.kill()
	_stage.scale = Vector2(art_scale, art_scale) * POP_SCALE
	_pop = create_tween()
	_pop.tween_property(_stage, "scale", Vector2(art_scale, art_scale), POP_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pedestal.flare(colour)
	_sparkles.color = Color(colour.r, colour.g, colour.b, 0.9).lightened(0.25)
	_sparkles.restart()
	_sparkles.emitting = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var room: Vector2 = Vector2(_viewport.size)
	_stage.position = Vector2(room.x * 0.5,
		room.y * feet_at - HeroAnimator.PAINTED_FEET_BELOW_CENTRE * _stage.scale.y)
	if not turntable:
		return
	if _resume_left > 0.0:
		_resume_left -= delta
		return
	_turn_left -= delta
	if _turn_left <= 0.0:
		_turn_left = turn_seconds
		face(_facing + 1)


func _worn(slot: int) -> GearData:
	var piece: Dictionary = MetaState.equipped_piece(slot)
	return ContentDB.gear(String(piece.get("kind", ""))) if not piece.is_empty() else null


## The ground the Warden stands on: a soft shadow and a ring of light that
## breathes, and flares in the colour of whatever was just chosen.
class Pedestal extends Node2D:
	const RESTING: Color = Color(0.91, 0.64, 0.24)
	var _colour: Color = RESTING
	var _flare: float = 0.0
	var _clock: float = 0.0

	func flare(colour: Color) -> void:
		_colour = colour
		_flare = 1.0

	func _process(delta: float) -> void:
		_clock += delta
		_flare = maxf(_flare - delta * 1.6, 0.0)
		queue_redraw()

	func _draw() -> void:
		var feet := Vector2(0.0, HeroAnimator.PAINTED_FEET_BELOW_CENTRE)
		draw_set_transform(feet, 0.0, Vector2(1.0, 0.3))
		for step: int in 5:
			var t: float = float(step) / 4.0
			draw_circle(Vector2.ZERO, lerpf(44.0, 20.0, t), Color(0.0, 0.0, 0.0, 0.10 + 0.06 * t))
		var breath: float = 0.5 + 0.5 * sin(_clock * 2.2)
		var ring: Color = _colour.lerp(RESTING, 1.0 - _flare)
		ring.a = 0.25 + 0.2 * breath + 0.45 * _flare
		draw_arc(Vector2.ZERO, 40.0 + 6.0 * _flare, 0.0, TAU, 48, ring, 2.0 + 2.0 * _flare, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
