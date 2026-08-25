class_name Companion
extends Node2D

## A summoned Wolf, Crow or Bear, for as long as the spell lasts.
##
## Reads its whole behaviour off `CompanionData` (working rule 3). What it does
## is deliberately small: keep near the hero, hit the nearest thing in reach, and
## go away when the clock runs out.
##
## **It cannot be hurt and nothing targets it.** That is not a shortcut, it is
## what keeps this a spell rather than a party member — see `CompanionData`'s
## header for why §54 makes that distinction load-bearing. It also means the
## targeting, threat and death-payout systems never learn a new kind of thing
## exists, which is the difference between adding a spell and adding a unit.
##
## Damage is dealt through the same `Enemy.take_damage` every other source uses,
## with `active_hero` false: a companion's hit is the hero's damage at one
## remove, but it is not the hero's *swing*, and the discipline nodes that key
## off a finisher should not fire for it.

const GROUP: StringName = &"companions"

var data: CompanionData = null
var field: Node = null

## Whose summon this is. Kept so two players' companions can be told apart, and
## so a hero leaving takes its own with it.
var owner_hero: Node2D = null

var _left: float = 0.0
var _cooldown: float = 0.0
var _sprite: Sprite2D = null
var _bob: float = 0.0
var _power: float = 0.0


func setup(companion: CompanionData, hero: Node2D, arena: Node) -> void:
	data = companion
	owner_hero = hero
	field = arena


func _ready() -> void:
	if data == null:
		queue_free()
		return
	add_to_group(GROUP)
	_left = data.duration
	# Snapshot at summon time rather than read per strike.
	#
	# A companion is paid for at the moment of casting: the relics and buildings
	# in force when it was called are what it swings with. Reading live would let
	# a socket change mid-summon retroactively re-price a spell already spent.
	_power = data.damage * Modifiers.multiplier(Modifiers.HERO_DAMAGE)

	_sprite = Sprite2D.new()
	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	_sprite.scale = Vector2.ONE * data.scale
	add_child(_sprite)
	_bob = randf() * TAU

	Vfx.ring(global_position, 84.0, Color(data.colour, 0.75), 0.45, 4.0)
	Vfx.spark(global_position, data.colour, 12, Vector2.UP, 210.0)


func _physics_process(delta: float) -> void:
	if data == null:
		return
	_left -= delta
	if _left <= 0.0:
		dismiss()
		return
	_cooldown = maxf(_cooldown - delta, 0.0)

	var quarry: Enemy = _nearest_enemy()
	var goal: Vector2 = _goal(quarry)
	var toward: Vector2 = goal - global_position
	if toward.length() > 8.0:
		var step: Vector2 = toward.normalized() * data.speed * delta
		global_position += step
		if _sprite != null and absf(step.x) > 0.001:
			_sprite.flip_h = step.x < 0.0

	if quarry != null and global_position.distance_to(quarry.global_position) \
			<= data.attack_range and _cooldown <= 0.0:
		_strike(quarry)

	_animate(delta)
	# Sorted by its feet like everything else that stands on the ground, except
	# a flier, which is over it.
	z_index = int(global_position.y) + (200 if data.flies else 0)


## Where it wants to be: on top of something to hit, or near its summoner.
func _goal(quarry: Enemy) -> Vector2:
	if quarry != null:
		return quarry.global_position
	if owner_hero != null and is_instance_valid(owner_hero):
		var behind: Vector2 = global_position - owner_hero.global_position
		if behind.length() < 1.0:
			behind = Vector2.RIGHT
		return owner_hero.global_position + behind.normalized() * data.follow_distance
	return global_position


## The closest living enemy worth crossing to.
func _nearest_enemy() -> Enemy:
	if field == null or not field.has_method("enemies_near"):
		return null
	var best: Enemy = null
	var best_distance: float = data.hunt_range
	for enemy: Enemy in field.enemies_near(global_position, data.hunt_range):
		if enemy.is_dying():
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _strike(quarry: Enemy) -> void:
	_cooldown = data.attack_interval
	# `active_hero` false: this is the hero's damage at one remove, not the
	# hero's swing, and the discipline nodes that key off a finisher must not
	# fire for it.
	quarry.take_damage(_power, global_position, data.knockback, false)
	Vfx.spark(quarry.global_position, data.colour, 5,
		(quarry.global_position - global_position).normalized(), 200.0)
	if _sprite != null:
		# A lunge rather than a swing animation: one authored attack pose per
		# companion is three more sprites for something on screen ten seconds at
		# a time, and a shove toward the target reads at any zoom.
		_sprite.position = (quarry.global_position - global_position).normalized() * 9.0


## A drift for a flier, a bob for anything that walks.
func _animate(delta: float) -> void:
	if _sprite == null:
		return
	_bob += delta * 9.0
	var lift: float = -26.0 if data.flies else 0.0
	_sprite.position = _sprite.position.lerp(
		Vector2(0.0, lift + sin(_bob) * (5.0 if data.flies else 2.0)), 0.25)
	# The last second is a fade, so it reads as leaving rather than as popping.
	_sprite.modulate.a = clampf(_left, 0.0, 1.0)


## Goes back where it came from.
func dismiss() -> void:
	if data != null:
		Vfx.ring(global_position, 70.0, Color(data.colour, 0.6), 0.35, 3.0)
	queue_free()
