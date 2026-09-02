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

## This spirit's personality, or null. See `SpiritTraitData`.
##
## Read once at summon rather than per frame: it belongs to the bond, and the
## bond cannot change while the companion is standing on the field.
var _temperament: SpiritTraitData = null


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
		_temperament = SpiritBond.trait_of_bond(spirit_key)

	_sprite = Sprite2D.new()
	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	_sprite.scale = Vector2.ONE * data.scale
	add_child(_sprite)
	_bob = randf() * TAU
	if not spirit_key.is_empty():
		_dress_as_spirit()

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


## The living enemy worth crossing to, by this companion's own lights.
##
## **Scored rather than sorted by distance**, since 2026-09-01, because that is
## where a personality actually lives: a Protective spirit and a Hunter standing
## in the same crowd should walk at different bodies. Distance is still the base
## of the score, so a companion with no personality behaves exactly as it always
## did and every trait remains a *preference* rather than a rule - none of them
## will cross the whole field past something already biting it.
func _nearest_enemy() -> Enemy:
	if field == null or not field.has_method("enemies_near"):
		return null
	var bias: int = SpiritTraitData.Bias.NEAREST
	if _temperament != null:
		bias = int(_temperament.bias)
	var hero_at: Vector2 = global_position
	if owner_hero != null and is_instance_valid(owner_hero):
		hero_at = owner_hero.global_position

	var best: Enemy = null
	var best_score: float = -INF
	for enemy: Enemy in field.enemies_near(global_position, data.hunt_range):
		if enemy.is_dying():
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance >= data.hunt_range:
			continue
		var score: float = -distance
		match bias:
			SpiritTraitData.Bias.ATTACKER:
				# Whatever is closest to *you*, and most of all whatever is
				# already winding up at you. There is no "who hit the hero last"
				# on record and there does not need to be: a body at your
				# shoulder mid-swing is the thing a protective animal goes for.
				score -= enemy.global_position.distance_to(hero_at) \
					* Balance.SPIRIT_TRAIT_GUARD_WEIGHT
				if enemy.is_telegraphing():
					score += Balance.SPIRIT_TRAIT_TELEGRAPH_BONUS
			SpiritTraitData.Bias.PROMOTED:
				if enemy.rank != Enemy.Rank.COMMON:
					score += Balance.SPIRIT_TRAIT_PROMOTED_BONUS
			_:
				pass
		if score > best_score:
			best_score = score
			best = enemy
	return best


## The damage this swing lands, personality included.
##
## Both envelopes average to one (`SpiritTraitData.resting_worth`, held by the
## gate), so this can change *where* a companion is dangerous and never how
## dangerous it is overall.
func _swing_power() -> float:
	if _temperament == null:
		return _power
	var closeness: float = 1.0
	if owner_hero != null and is_instance_valid(owner_hero):
		closeness = 1.0 - clampf(
			global_position.distance_to(owner_hero.global_position)
			/ maxf(data.hunt_range, 1.0), 0.0, 1.0)
	var health: float = spirit_health_ratio() if _max_hp > 0.0 else 1.0
	return _power * _temperament.damage_scale(closeness, health)


## How far this companion draws loose pickups in. Zero for most of them.
func reveal_radius() -> float:
	return 0.0 if _temperament == null else _temperament.reveal_radius


func _strike(quarry: Enemy) -> void:
	_cooldown = data.attack_interval
	# `active_hero` false: this is the hero's damage at one remove, not the
	# hero's swing, and the discipline nodes that key off a finisher must not
	# fire for it.
	quarry.take_damage(_swing_power(), global_position, data.knockback, false)
	Vfx.spark(quarry.global_position, data.colour, 5,
		(quarry.global_position - global_position).normalized(), 200.0)
	_scavenge(quarry)
	if _sprite != null:
		# A lunge rather than a swing animation: one authored attack pose per
		# companion is three more sprites for something on screen ten seconds at
		# a time, and a shove toward the target reads at any zoom.
		_sprite.position = (quarry.global_position - global_position).normalized() * 9.0


## A Scavenger's finder's fee, on a body it brought down itself.
##
## Only on a kill, and only its own: a trait that paid out on every hit would be
## an income multiplier rather than a personality, and the drop economy is tuned
## against kills. Paid for out of the same damage envelope everything else is -
## Scavenger swings a little softer than the others, which is the whole trade.
func _scavenge(quarry: Enemy) -> void:
	if _temperament == null or _temperament.scavenge_chance <= 0.0:
		return
	if not quarry.is_dying():
		return
	if field == null or not field.has_method("spawn_loot"):
		return
	if RunState.rng("combat").randf() > _temperament.scavenge_chance:
		return
	var currency: String = RunState.CURRENCIES[
		RunState.rng("combat").randi_range(0, RunState.CURRENCIES.size() - 1)]
	field.spawn_loot(currency, Balance.SPIRIT_TRAIT_SCAVENGE_AMOUNT,
		quarry.global_position)
	Vfx.spark(quarry.global_position, data.colour, 8, Vector2.UP, 170.0)


## A drift for a flier, a bob for anything that walks.
func _animate(delta: float) -> void:
	if _sprite == null:
		return
	_bob += delta * 9.0
	var lift: float = -26.0 if data.flies else 0.0
	_sprite.position = _sprite.position.lerp(
		Vector2(0.0, lift + sin(_bob) * (5.0 if data.flies else 2.0)), 0.25)
	# The last second is a fade, so it reads as leaving rather than as popping.
	#
	# **Spell summons only.** A spirit has no clock - `_left` is INF, which clamps
	# to 1.0 and would overwrite the translucency that makes it read as a spirit
	# at all, every frame, silently. It would also fight the breath tween for
	# ownership of the same property.
	if spirit_key.is_empty():
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


## Makes a spirit read as a manifestation rather than as the animal wandering in.
##
## **Translucency and a tint, and nothing drawn on top.** These are the same
## 64px wildlife sprites; an outline, a particle system or a bloom pass at that
## size covers the animal up, and the owner's brief is explicit that the pixel
## art must stay readable. Alpha plus a colour is enough to say "this is not
## flesh" while leaving every pixel visible.
##
## The tint is the variant's own, so rarity and shine are legible on the field
## rather than only in the journal - a Shiny Legendary Wolf walking beside you
## should be recognisable as one without opening a menu.
func _dress_as_spirit() -> void:
	if _sprite == null:
		return
	# A spirit wears the actor outline like everything else that stands on the
	# battlefield, and a shiny one also shines: the same travelling band the
	# living animal wore, so a player who hunted a Shiny Legendary sees the thing
	# they hunted walking beside them rather than a differently-tinted version of
	# it. The translucency below is what says "spirit"; this says "the rare one".
	#
	# Attached for every spirit rather than only the shiny ones. One material on
	# a single companion is nothing, and giving only the rare variants a
	# silhouette would make the *outline* read as part of the rarity.
	var polish: ShaderMaterial = ActorPolish.attach(_sprite)
	if SpiritBond.shiny_of(spirit_key):
		ActorState.shine(polish, true)
	var hue: Color = data.colour
	hue.a = Balance.SPIRIT_DRAW_ALPHA
	_sprite.modulate = hue
	# A slow breath rather than a flicker: it has to survive being looked at for
	# a whole run, which is a much harder test than looking good for a second.
	var breath: Tween = _sprite.create_tween().set_loops()
	var dim: Color = hue
	dim.a = Balance.SPIRIT_DRAW_ALPHA * 0.78
	var half: float = 0.5 / maxf(Balance.SPIRIT_BREATH_HZ, 0.05)
	breath.tween_property(_sprite, "modulate", dim, half)
	breath.tween_property(_sprite, "modulate", hue, half)
