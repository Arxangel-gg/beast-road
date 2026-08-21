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
var gear: Dictionary = {}

var _sprite: Sprite2D
var _velocity: Vector2 = Vector2.ZERO
var _life: float = 0.0
var _homing: bool = false
var _glow: Sprite2D
var _glow_colour: Color = Balance.LOOT_GLOW_COLOUR
var _glow_size: float = Balance.LOOT_GLOW_SIZE


func setup(currency_id: String, value: int, from: Vector2) -> void:
	currency = currency_id
	amount = value
	position = from
	# Thrown clear of the corpse so a pack that dies together does not leave one
	# stacked pile that reads as a single coin.
	var angle: float = randf() * TAU
	_velocity = Vector2.RIGHT.rotated(angle) * randf_range(
		Balance.LOOT_SCATTER_SPEED * 0.4, Balance.LOOT_SCATTER_SPEED)


func setup_gear(piece: Dictionary, from: Vector2) -> void:
	gear = piece.duplicate(true)
	position = from
	var rarity: int = clampi(int(gear.get("rarity", 0)), 0,
		Balance.GEAR_RARITY_COLOURS.size() - 1)
	_glow_colour = Balance.GEAR_RARITY_COLOURS[rarity]
	_glow_colour.a = 0.58
	_glow_size = Balance.GEAR_DROP_GLOW_SIZE
	var angle: float = randf() * TAU
	_velocity = Vector2.RIGHT.rotated(angle) * randf_range(
		Balance.LOOT_SCATTER_SPEED * 0.55, Balance.LOOT_SCATTER_SPEED * 1.15)


func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	# World art where it exists, the currency's UI icon otherwise.
	#
	# A HUD icon is drawn to read at 24px against a dark bar, not lying on a lit
	# road among corpses, so the ones that have proper drop art use it - and the
	# fallback keeps every currency working the moment it is added, rather than
	# dropping an invisible pickup until somebody notices.
	var icon_size: float = Balance.LOOT_ICON_SIZE
	if not gear.is_empty():
		var kind: GearData = ContentDB.gear(String(gear.get("kind", "")))
		if kind != null and ResourceLoader.exists(kind.get_sprite_path()):
			_sprite.texture = load(kind.get_sprite_path())
		icon_size = Balance.GEAR_DROP_ICON_SIZE
	else:
		var painted: String = Balance.LOOT_ART_FORMAT % currency
		if ResourceLoader.exists(painted):
			_sprite.texture = load(painted)
		else:
			_sprite.texture = IconKit.ui(currency)
	if _sprite.texture != null:
		_sprite.scale = Vector2.ONE * (icon_size
			/ maxf(_sprite.texture.get_width(), 1.0))
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	# A soft pool under the drop, so a coin lying on a lit road still reads.
	#
	# Behind the sprite rather than a shader on it: an outline drawn on the sprite
	# competes with the road's own edge detail at this size, while a pool of light
	# separates the drop from whatever it landed on regardless of what that was.
	var glow := Sprite2D.new()
	glow.texture = LightKit.falloff_texture()
	glow.modulate = _glow_colour
	glow.scale = Vector2.ONE * (_glow_size
		/ maxf(LightKit.falloff_texture().get_width(), 1.0))
	glow.z_index = -1
	add_child(glow)
	_glow = glow

	add_child(_sprite)
	z_index = Balance.LOOT_Z_INDEX
	Sfx.play_group("loot_drop")


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
	# The pool breathes out of phase with the hover, which reads as a thing
	# glinting rather than as a sprite being scaled.
	if _glow != null:
		var pulse: float = 1.0 + sin(_life * Balance.LOOT_GLOW_SPEED) * 0.16
		_glow.scale = Vector2.ONE * (_glow_size * pulse
			/ maxf(LightKit.falloff_texture().get_width(), 1.0))

	if _life >= Balance.LOOT_LIFETIME:
		# Expiry fades rather than vanishing, and pays out anyway. Losing a reward
		# already earned by killing the thing teaches a player to stop fighting
		# and stand on the road hoovering, which is worse than either extreme.
		_collect()


func _collect() -> void:
	if not gear.is_empty():
		var result: Dictionary = MetaState.receive_gear(gear)
		var stored: bool = bool(result.get("stored", false))
		var salvaged: int = int(result.get("shards", 0))
		var kind: GearData = ContentDB.gear(String(gear.get("kind", "")))
		var title: String = kind.display_name if kind != null else "Gear"
		var outcome: String = "taken to the stash" if stored \
			else "stash full  ·  broken into %d Shards" % salvaged
		EventBus.preparation_warning.emit("%s  %s  ·  %s" % [
			Stash.rarity_name(gear), title, outcome])
		EventBus.gear_collected.emit(gear, stored, salvaged, global_position)
		Sfx.play_group("loot_collect")
		Vfx.ring(global_position, _glow_size * 0.55, _glow_colour, 0.32, 4.0)
	elif amount > 0 and not currency.is_empty():
		RunState.gain_currency(currency, amount)
		Sfx.play_group("loot_collect")
		Vfx.number(global_position, float(amount), Balance.LOOT_GLOW_COLOUR, false)
		EventBus.loot_collected.emit(currency, amount, global_position)
	queue_free()
