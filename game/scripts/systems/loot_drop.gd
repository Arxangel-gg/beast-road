class_name LootDrop
extends Node2D

## A dropped reward that flies to the hero when they come near.
##
## **It is a bonus, never the base income.** The kill still pays its resources
## the instant it dies, exactly as before; this drops an *extra* share on top for
## a player who goes and gets it. That split is deliberate and load-bearing: the
## difficulty curve was tuned against guaranteed income, so making the base
## collectable would quietly cut a passive player's economy and re-harden a game
## that was just balanced. A bonus can only ever add.
##
## What it buys is the thing the rebalance is for — a reason to be on the road
## rather than behind the towers. The magnet is generous for the same reason it
## exists at all: chasing coins is not the interesting part, being out there is.

## Group so the battlefield can sweep them when it tears down.
const GROUP: StringName = &"loot"

var currency: String = ""
var amount: int = 0

var _sprite: Sprite2D
var _velocity: Vector2 = Vector2.ZERO
var _life: float = 0.0
var _homing: bool = false


func setup(currency_id: String, value: int, from: Vector2) -> void:
	currency = currency_id
	amount = value
	position = from
	# Thrown clear of the corpse so a pack that dies together does not leave one
	# stacked pile that reads as a single coin.
	var angle: float = randf() * TAU
	_velocity = Vector2.RIGHT.rotated(angle) * randf_range(
		Balance.LOOT_SCATTER_SPEED * 0.4, Balance.LOOT_SCATTER_SPEED)


func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = IconKit.ui(currency)
	if _sprite.texture != null:
		_sprite.scale = Vector2.ONE * (Balance.LOOT_ICON_SIZE
			/ maxf(_sprite.texture.get_width(), 1.0))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	z_index = Balance.LOOT_Z_INDEX


func _process(delta: float) -> void:
	_life += delta
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	if hero != null and is_instance_valid(hero):
		var to_hero: Vector2 = hero.global_position - global_position
		var distance: float = to_hero.length()
		if distance <= Balance.LOOT_COLLECT_RANGE:
			_collect()
			return
		# Once homing, always homing. Without the latch a drop at the edge of the
		# magnet stutters in and out of range as the hero moves, and reads as
		# broken rather than as out of reach.
		if _homing or distance <= Balance.LOOT_MAGNET_RANGE:
			_homing = true
			_velocity = _velocity.move_toward(
				to_hero.normalized() * Balance.LOOT_MAGNET_SPEED,
				Balance.LOOT_MAGNET_ACCELERATION * delta)

	if not _homing:
		_velocity = _velocity.move_toward(Vector2.ZERO, Balance.LOOT_DRAG * delta)
	position += _velocity * delta

	# A small hover, so a coin lying on a busy road is still findable.
	if _sprite != null:
		_sprite.position.y = sin(_life * Balance.LOOT_BOB_SPEED) * Balance.LOOT_BOB_HEIGHT

	if _life >= Balance.LOOT_LIFETIME:
		# Expiry fades rather than vanishing, and pays out anyway. Losing a reward
		# already earned by killing the thing teaches a player to stop fighting
		# and stand on the road hoovering, which is worse than either extreme.
		_collect()


func _collect() -> void:
	if amount > 0 and not currency.is_empty():
		RunState.gain_currency(currency, amount)
		EventBus.loot_collected.emit(currency, amount, global_position)
	queue_free()
