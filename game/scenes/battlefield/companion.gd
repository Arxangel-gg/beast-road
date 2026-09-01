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

# --- Spirit mode -------------------------------------------------------------
#
# Owner decision, 2026-09-01. A Wildlife Spirit Companion is the same node in a
# different mode: it reuses the follow, hunt, strike and animation the summons
# have always had, and changes only what ends it.
#
# **A spell summon expires; a spirit is defeated.** That is the whole difference,
# and it is why this is a mode rather than a second class - duplicating the AI to
# change the ending condition would leave two behaviours to keep in step.

## Non-empty puts this companion in spirit mode. A `SpiritBond` key.
var spirit_key: String = ""

var _hp: float = 0.0
var _max_hp: float = 0.0

## Seconds left re-forming, or zero when present. A downed spirit is not freed -
## it is the same node, waiting, because the collection says it is still yours.
var _recovering: float = 0.0
var _contact: float = 0.0
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
	if not spirit_key.is_empty():
		# No clock. A spirit stays until it is beaten, unequipped or replaced.
		_left = INF
		var scale: float = SpiritBond.power_scale(
			SpiritBond.rarity_of(spirit_key), SpiritBond.shiny_of(spirit_key))
		_max_hp = data.damage * Balance.SPIRIT_HEALTH_PER_DAMAGE * scale
		_hp = _max_hp
	# Snapshot at summon time rather than read per strike.
	#
	# A companion is paid for at the moment of casting: the relics and buildings
	# in force when it was called are what it swings with. Reading live would let
	# a socket change mid-summon retroactively re-price a spell already spent.
	_power = data.damage * Modifiers.multiplier(Modifiers.HERO_DAMAGE)
	if not spirit_key.is_empty():
		_power *= SpiritBond.power_scale(SpiritBond.rarity_of(spirit_key),
			SpiritBond.shiny_of(spirit_key))

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
	if _recovering > 0.0:
		_tick_recovery(delta)
		return
	_left -= delta
	if _left <= 0.0:
		dismiss()
		return
	if not spirit_key.is_empty():
		_suffer_contact(delta)
		if _hp <= 0.0:
			_go_down()
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


# --- Spirit mode -------------------------------------------------------------

## What a spirit can be hurt by: whatever it is standing in.
##
## **Deliberately not the targeting system.** `CompanionData`'s header makes the
## case that keeping companions out of threat and targeting is the difference
## between adding a spell and adding a unit, and that reasoning survives a spirit
## being mortal - enemies still never *choose* it, never retarget onto it, and
## never lose interest in the town because a wolf walked past.
##
## What changes is that standing in a pack now costs something. A spirit thrown
## into six bodies dies; one fighting at the edge of a line does not. That is
## exactly the bound the owner asked for - meaningful participation, without the
## player being able to hide behind an immortal ally.
func _suffer_contact(delta: float) -> void:
	if field == null or not field.has_method("enemies_near"):
		return
	_contact = maxf(_contact - delta, 0.0)
	if _contact > 0.0:
		return
	var touching: Array = field.enemies_near(global_position,
		Balance.SPIRIT_CONTACT_RADIUS)
	var hurt: float = 0.0
	for value: Variant in touching:
		var enemy := value as Enemy
		if enemy != null and not enemy.is_dying():
			hurt += enemy.data.contact_damage
	if hurt <= 0.0:
		return
	_hp -= hurt
	_contact = Balance.SPIRIT_CONTACT_INTERVAL
	Vfx.spark(global_position, data.colour, 5, Vector2.UP, 130.0)


## Beaten, not killed. It dissolves and begins re-forming.
func _go_down() -> void:
	_recovering = SpiritBond.recovery_seconds(SpiritBond.rarity_of(spirit_key),
		SpiritBond.shiny_of(spirit_key))
	if _sprite != null:
		_sprite.visible = false
	Vfx.ring(global_position, 92.0, Color(data.colour, 0.7), 0.5, 5.0)
	Vfx.spark(global_position, data.colour, 18, Vector2.UP, 190.0)
	EventBus.spirit_downed.emit(spirit_key, _recovering)


## Re-forms, then returns *beside the hero* rather than where it fell.
##
## Where it fell is by definition the place that killed it, and on a road that
## keeps moving it is also somewhere behind. Coming back at the hero's shoulder
## is the only version of this that cannot strand a spirit off-screen or inside
## the town wall.
func _tick_recovery(delta: float) -> void:
	_recovering = maxf(_recovering - delta, 0.0)
	if _recovering > 0.0:
		return
	_hp = _max_hp
	if owner_hero != null and is_instance_valid(owner_hero):
		global_position = owner_hero.global_position \
			+ Vector2.RIGHT.rotated(randf() * TAU) * data.follow_distance
	if _sprite != null:
		_sprite.visible = true
	Vfx.ring(global_position, 84.0, Color(data.colour, 0.8), 0.45, 4.0)
	Vfx.spark(global_position, data.colour, 14, Vector2.UP, 200.0)
	EventBus.spirit_returned.emit(spirit_key)


## Seconds until it returns, for the interface. Zero when it is present.
func recovery_left() -> float:
	return _recovering


func spirit_health_ratio() -> float:
	return clampf(_hp / maxf(_max_hp, 1.0), 0.0, 1.0) if _max_hp > 0.0 else 1.0
