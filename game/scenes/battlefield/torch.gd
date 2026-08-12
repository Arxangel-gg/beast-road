class_name Torch
extends Node2D

## A torch on a lane, which the player wants kept lit.
##
## This is a mechanic wearing a lighting effect, not decoration. An enemy walking
## past snuffs a torch out; the hero standing near a dead one relights it. The
## darker a lane gets, the stronger and more frequent the things that come down
## it — so keeping the road lit is a real defensive choice competing for the same
## attention as everything else, and it matters most at night when the light is
## also what lets you see.
##
## The flame is procedural: a flickering light, a pulsing core and a plume that
## breathes. There is no fire art in the project and none is needed at this size.

signal state_changed(lit: bool)

## Which lane this belongs to, so the wave director can ask how dark it is.
var lane: int = 0

var _lit: bool = true
var _relight: float = 0.0
var _flicker_seed: float = 0.0

var _post: Polygon2D
var _flame: Polygon2D
var _ember: Polygon2D
var _light: PointLight2D
var _driver: LightDriver


func _ready() -> void:
	add_to_group(GROUP)
	_flicker_seed = randf() * 100.0
	_build()
	_apply_state(true)


const GROUP: StringName = &"torches"


func _build() -> void:
	# A dark post so an unlit torch is still visibly a torch rather than nothing.
	_post = Polygon2D.new()
	_post.polygon = PackedVector2Array([
		Vector2(-3.5, 0.0), Vector2(3.5, 0.0),
		Vector2(2.5, -Balance.TORCH_HEIGHT), Vector2(-2.5, -Balance.TORCH_HEIGHT),
	])
	_post.color = Color(0.16, 0.13, 0.11)
	add_child(_post)

	_flame = Polygon2D.new()
	_flame.color = Color(1.0, 0.72, 0.30, 0.95)
	_flame.position.y = -Balance.TORCH_HEIGHT
	add_child(_flame)

	_ember = Polygon2D.new()
	_ember.color = Color(1.0, 0.94, 0.72, 0.9)
	_ember.position.y = -Balance.TORCH_HEIGHT
	add_child(_ember)

	_light = LightKit.add_light(self, Balance.TORCH_LIGHT_COLOUR,
		Balance.TORCH_LIGHT_RADIUS, Balance.TORCH_LIGHT_ENERGY, Balance.TORCH_FLICKER)
	_light.position.y = -Balance.TORCH_HEIGHT


func _process(delta: float) -> void:
	if not _lit:
		_tick_relight(delta)
		return

	# Two out-of-phase sines: one makes the flame lean, the other makes it
	# breathe. A single sine reads as a pulse rather than as fire.
	_flicker_seed += delta
	var lean: float = sin(_flicker_seed * 5.3) * 0.35 + sin(_flicker_seed * 11.7) * 0.15
	var height: float = 1.0 + sin(_flicker_seed * 8.1) * 0.18
	_flame.polygon = _flame_shape(Balance.TORCH_FLAME_SIZE * height, lean)
	_ember.polygon = _flame_shape(Balance.TORCH_FLAME_SIZE * height * 0.45, lean * 0.6)


## A teardrop leaning by `lean`, widest at the base.
func _flame_shape(size: float, lean: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-size * 0.55, 0.0),
		Vector2(size * 0.55, 0.0),
		Vector2(size * 0.30 + lean * size, -size * 1.1),
		Vector2(lean * size * 1.6, -size * 2.0),
		Vector2(-size * 0.30 + lean * size, -size * 1.1),
	])


func is_lit() -> bool:
	return _lit


## Snuffed by something walking past.
func extinguish() -> void:
	if not _lit:
		return
	_lit = false
	_relight = 0.0
	_apply_state()
	Vfx.spark(global_position + Vector2(0.0, -Balance.TORCH_HEIGHT),
		Color(0.45, 0.45, 0.48), 5, Vector2.UP, 90.0)


## Relit by the hero standing close enough for long enough.
func relight() -> void:
	if _lit:
		return
	_lit = true
	_apply_state()
	var at: Vector2 = global_position + Vector2(0.0, -Balance.TORCH_HEIGHT)
	Vfx.spark(at, Balance.TORCH_LIGHT_COLOUR, 10, Vector2.UP, 200.0)
	Vfx.ring(at, 64.0, Color(Balance.TORCH_LIGHT_COLOUR, 0.7), 0.35, 3.0)
	Vfx.flash_at(at, Balance.TORCH_LIGHT_COLOUR, 22.0)
	Sfx.play("sfx_tower_build", -6.0)


## Held near a dead torch, the hero rekindles it. Deliberately not instant: it
## has to cost a moment of standing still in a lane, or it is not a decision.
func _tick_relight(delta: float) -> void:
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	if hero == null or not is_instance_valid(hero):
		return
	if global_position.distance_to(hero.global_position) > Balance.TORCH_RELIGHT_RANGE:
		_relight = 0.0
		return
	_relight += delta
	# A wisp of the flame returning while the player holds position.
	_ember.polygon = _flame_shape(
		Balance.TORCH_FLAME_SIZE * 0.5 * (_relight / Balance.TORCH_RELIGHT_TIME), 0.0)
	_ember.visible = true
	if _relight >= Balance.TORCH_RELIGHT_TIME:
		relight()


func _apply_state(quiet: bool = false) -> void:
	_flame.visible = _lit
	_ember.visible = _lit
	if _light != null:
		# The driver owns energy frame to frame, so toggling visibility is the
		# only safe way to put a light out without fighting it.
		_light.visible = _lit
	if _driver != null:
		_driver.set_process(_lit)
	if not quiet:
		state_changed.emit(_lit)
		EventBus.torch_state_changed.emit(lane, _lit)
