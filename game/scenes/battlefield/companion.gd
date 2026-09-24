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

## **True when this is an animal the Warden raised** rather than a bonded spirit.
##
## The difference is the only one that matters here: a spirit re-forms after it
## is beaten and a raised animal does not. One creature, one life, and the reason
## taking a favourite out of the pen is a decision rather than a free upgrade.
var from_pen: bool = false

var _hp: float = 0.0
var _max_hp: float = 0.0

## Seconds left re-forming, or zero when present. A downed spirit is not freed -
## it is the same node, waiting, because the collection says it is still yours.
var _recovering: float = 0.0
var _contact: float = 0.0
var _sprite: Sprite2D = null
var _bob: float = 0.0
var _power: float = 0.0

# --- Frames (2026-09-12) -----------------------------------------------------
#
# Owner report: companions faced the wrong way and used no animations. A
# companion borrows a species' frames - a Spirit Wolf is the wolf's own idle,
# run and bite - so nothing was drawn for this, and a spirit runs exactly like
# the animal the player bonded. The facing comes from the art rather than a
# guess about it.
var _frames_idle: Array[Texture2D] = []
var _frames_move: Array[Texture2D] = []
var _frames_attack: Array[Texture2D] = []
var _base_texture: Texture2D = null
var _faces_right: bool = false
var _frame_clock: float = 0.0
var _striking_left: float = 0.0
var _vocal: String = ""
var _bar: ProgressBar = null

## This spirit's personality, or null. See `SpiritTraitData`.
##
## Read once at summon rather than per frame: it belongs to the bond, and the
## bond cannot change while the companion is standing on the field.
var _temperament: SpiritTraitData = null
var _moving: bool = false


func setup(companion: CompanionData, hero: Node2D, arena: Node) -> void:
	data = companion
	owner_hero = hero
	field = arena


func _ready() -> void:
	if data == null:
		queue_free()
		return
	add_to_group(GROUP)
	# **A raised animal scuffs the ground; a spirit does not.**
	#
	# That is the hide rule of the roster in a second place rather than a new
	# one - `Balance.FOOTFALL_MASS_BY_HIDE` gives a spirit a mass of zero, and a
	# thing with no body leaves no dust however fast it crosses the yard. What
	# `from_pen` separates is exactly that: the creature in the pen is alive and
	# the summoned one is not. Its footprint comes off the species it actually
	# is, so a raised badger and a raised bear are not the same weight.
	# **Every companion marks the ground, raised or summoned.** Owner,
	# 2026-09-18: *"Companions also must produce the moving ground vfx!"* The
	# first cut gave a summoned spirit nothing, on the reading that a spirit
	# has no body - `FOOTFALL_MASS_BY_HIDE` gives one a mass of zero and that
	# rule still stands for the *roster*, where it separates a wight from a
	# golem. A companion at your shoulder is a different question and the
	# owner has answered it: it walks, so it scuffs. A summoned one is lighter
	# rather than weightless, which keeps the distinction visible without
	# making it invisible.
	var bulk: float = 1.0 if from_pen else Balance.FOOTFALL_SPIRIT_MASS
	Footfalls.register_animal(self, ContentDB.wildlife_kind(data.wildlife_id),
		bulk)
	_left = data.duration
	if not spirit_key.is_empty():
		# No clock. A spirit stays until it is beaten, unequipped or replaced.
		_left = INF
		var scale: float = SpiritBond.power_scale(
			SpiritBond.rarity_of(spirit_key), SpiritBond.shiny_of(spirit_key))
		# The spirit stands where the Warden stands: Resolve is the one
		# attribute that reaches past the hero's own body. Health only - a
		# spirit's damage is `SPIRIT_APEX_POWER`'s business and the trait's,
		# and a fifth attribute quietly raising it would be the third power
		# scale this project keeps refusing.
		var keeper: float = 1.0 + minf(
			float(RunState.attribute(RunState.Attribute.RESOLVE))
				* Balance.HERO_RESOLVE_SPIRIT_PER_POINT,
			Balance.HERO_RESOLVE_SPIRIT_CAP)
		_max_hp = data.damage * Balance.SPIRIT_HEALTH_PER_DAMAGE * scale * keeper
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
	_load_frames()
	_sprite.scale = Vector2.ONE * data.scale
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	add_child(_sprite)
	_bob = randf() * TAU
	_wear_its_own_coat()
	if not spirit_key.is_empty():
		_dress_as_spirit()
		_build_bar()

	Vfx.ring(global_position, 84.0, Color(data.colour, 0.75), 0.45, 4.0)
	Vfx.spark(global_position, data.colour, 12, Vector2.UP, 210.0)
	Sfx.play_at("sfx_companion_summon", global_position)
	if not _vocal.is_empty():
		Sfx.play_at(_vocal, global_position, -4.0)


## **The spirit at your shoulder is one animal, not the species.**
##
## Owner, 2026-09-15: "companion made alive wildlife should keep the seed for
## the duration of its lifespan." A bonded spirit wears the same coat every time
## it is called for the whole run - dismiss it, re-equip it, reconnect, and it
## is the same animal - and a *different* one next run.
##
## **Seeded from the run rather than from the save.** Nothing about a bond
## persists but which variants have been met (working rule 7, amended
## 2026-09-01), and a coat kept on disk would be a new kind of persistence for a
## picture. The run seed and the variant key together are stable for exactly as
## long as the run is, and are the same two numbers on both machines - so a
## guest's companion wears the host's coat without a packet, the same way
## `RunState.companion_sex` does.
func _wear_its_own_coat() -> void:
	if _sprite == null:
		return
	var species: String = data.wildlife_id
	if not spirit_key.is_empty():
		species = SpiritBond.species_of(spirit_key)
	var kind := ContentDB.wildlife_kinds.get(species, null) as WildlifeData
	if kind == null:
		return
	var serial: int = absi(RunState.run_seed ^ hash(spirit_key if not spirit_key.is_empty()
		else data.id))
	Phenotype.dress(ActorPolish.attach(_sprite), kind, serial)


## The frames this companion wears: a species' own, or its single sprite.
func _load_frames() -> void:
	var species: String = SpiritBond.species_of(spirit_key) if not spirit_key.is_empty() \
		else data.wildlife_id
	var kind := ContentDB.wildlife_kinds.get(species, null) as WildlifeData
	var path: String = kind.get_sprite_path() if kind != null else data.get_sprite_path()
	if kind != null and ResourceLoader.exists(path):
		_faces_right = kind.art_faces_right
		_vocal = kind.vocal_sfx
		_frames_idle = GameData.load_idle_frames(path)
		_frames_move = GameData.load_move_frames(path)
		if kind.flies:
			var flight: Array[Texture2D] = GameData.load_flight_frames(path)
			if not flight.is_empty():
				_frames_move = flight
		_frames_attack = GameData.load_attack_frames(path)
	else:
		path = data.get_sprite_path()
		_faces_right = data.art_faces_right
	if ResourceLoader.exists(path):
		_base_texture = load(path)
		_sprite.texture = _base_texture
		# Sorted by the feet: the node is the ground contact, the sprite stands
		# up from it.
		_sprite.offset = Foliage.foot_offset(_base_texture)


## A bar over a spirit, hidden until it has been hurt. A summon has no health
## and no bar.
func _build_bar() -> void:
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 1.0
	_bar.custom_minimum_size = Vector2(Balance.WILDLIFE_BAR_WIDTH, Balance.WILDLIFE_BAR_HEIGHT)
	_bar.size = _bar.custom_minimum_size
	_bar.position = Vector2(-Balance.WILDLIFE_BAR_WIDTH * 0.5, -Balance.COMPANION_BAR_LIFT * data.scale)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	_bar.modulate = data.colour
	_bar.z_index = Balance.HEALTH_BAR_Z
	_bar.z_as_relative = false
	add_child(_bar)


func _refresh_bar() -> void:
	if _bar == null:
		return
	var ratio: float = spirit_health_ratio()
	_bar.value = ratio
	_bar.visible = ratio < 0.999 and _recovering <= 0.0


func _physics_process_measured(delta: float) -> void:
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
	# **What is hunting my owner comes first.** A wolf pack is wildlife, not an
	# enemy of the road, and a companion that only ever looked for an `Enemy`
	# stood and watched while its owner was taken apart (owner brief,
	# 2026-09-13). A threat nearer to the owner than the chosen body is
	# answered instead.
	var threat: Vector2 = _threat_to_owner()
	var guard: bool = threat != Vector2.INF
	if guard and quarry != null and owner_hero != null and is_instance_valid(owner_hero):
		guard = threat.distance_to(owner_hero.global_position) \
			< quarry.global_position.distance_to(owner_hero.global_position)
	var goal: Vector2 = threat if guard else _goal(quarry)
	var toward: Vector2 = goal - global_position
	var moving: bool = toward.length() > 8.0
	if moving:
		var step: Vector2 = toward.normalized() * data.speed * delta
		global_position += step
		# Facing from motion, against the art's own direction: the painted
		# animals face left, and a flip written for right-facing art ran every
		# one of them backwards.
		if _sprite != null and absf(step.x) > 0.001:
			_sprite.flip_h = (step.x > 0.0) != _faces_right
	elif quarry != null and _sprite != null:
		var facing: float = quarry.global_position.x - global_position.x
		if absf(facing) > 0.001:
			_sprite.flip_h = (facing > 0.0) != _faces_right
	_moving = moving

	if guard and global_position.distance_to(threat) <= data.attack_range \
			and _cooldown <= 0.0:
		_bite_wildlife(threat)
	elif quarry != null and global_position.distance_to(quarry.global_position) \
			<= data.attack_range and _cooldown <= 0.0:
		_strike(quarry)

	_animate(delta)
	# Sorted by its feet by the layer it lives in, like everything else that
	# stands on the ground; a flier sits a step above the ground-bound.
	z_index = 1 if data.flies else 0
	_tick_poison(delta)


## **Where a wild animal of its own kind is waiting**, or `Vector2.INF`.
##
## Owner, 2026-09-22: a companion may court a wild animal *"only if they're
## the same species and proper opposite genders, and the player's companion is
## not actively targeting anything or busy with anything"*.
##
## Set by `WildlifeFamilies`, read here, and **always beneath the fight**: it
## is consulted after the threat to the owner and after the quarry, so the
## first body that needs answering ends the courtship by simply out-ranking
## it. Nothing about a companion's numbers changes while it courts - this is a
## destination and a stand, and the animal it walks to is the one that bears.
var courting_at: Vector2 = Vector2.INF


## Whether it is free to be asked. Every clause is "it has nothing else to do".
##
## `spirit_key` is the line between a bonded or raised companion and a *spell*
## summon: a wolf called for twenty seconds courting anything is absurd, and
## that flag is already what separates the two everywhere else in this file.
func may_court() -> bool:
	if data == null or not is_alive() or _recovering > 0.0:
		return false
	if spirit_key.is_empty():
		return false
	if _striking_left > 0.0 or _cooldown > 0.0:
		return false
	if _threat_to_owner() != Vector2.INF:
		return false
	return _nearest_enemy() == null


## Where it wants to be: on top of something to hit, or near its summoner.
func _goal(quarry: Enemy) -> Vector2:
	if quarry != null:
		return quarry.global_position
	# Beneath the fight and above the follow: a companion with nothing to
	# answer goes to the animal it is courting, and stops following its
	# owner about while it does.
	if courting_at != Vector2.INF:
		return courting_at
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


## **What is actually hunting my owner**, when it is not an enemy of the road.
##
## A bonded bear watched a pack of wolves take its owner apart, because the
## only thing a companion ever looked for was an `Enemy` - and a wolf is
## wildlife. Reported 2026-09-13. A predator stalking or striking the owner
## is a threat, and so is anything rabid nearby; the companion goes for it
## with the same swing it uses on a body, landed through the wildlife
## system's own door.
func _threat_to_owner() -> Vector2:
	if owner_hero == null or not is_instance_valid(owner_hero):
		return Vector2.INF
	var animals: Node = null
	if field != null and field.has_method("wildlife_system"):
		animals = field.call("wildlife_system")
	if animals == null or not animals.has_method("threat_to"):
		return Vector2.INF
	return animals.call("threat_to", owner_hero, Balance.COMPANION_GUARD_RANGE) as Vector2


## Bites whatever is at that spot. Wildlife owns its own numbers, so the
## wound goes through `Wildlife.wound_near` exactly as the hero's swing does.
func _bite_wildlife(at: Vector2) -> void:
	var animals: Node = null
	if field != null and field.has_method("wildlife_system"):
		animals = field.call("wildlife_system")
	if animals == null or not animals.has_method("wound_near"):
		return
	animals.call("wound_near", at, Balance.COMPANION_BITE_RADIUS, _swing_power())
	_striking_left = Balance.COMPANION_STRIKE_FRAMES_SECONDS
	_cooldown = data.attack_interval
	Sfx.play_at("sfx_companion_strike", global_position)


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
	# The bite's frames, where the species has them, over a lunge either way.
	_striking_left = Balance.COMPANION_STRIKE_FRAMES_SECONDS
	_frame_clock = 0.0
	# **A spirit fights where it is standing**, which is often not where the
	# Warden is - `sfx_companion_down` in this same file has used `play_at` since
	# it was written, and every other sound the companion makes did not.
	Sfx.play_at("sfx_companion_strike", global_position)
	if not _vocal.is_empty():
		Sfx.play_at(_vocal, global_position, -9.0)
	if _sprite != null:
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


## The species' frames where they exist - the bite, the run, the stand - and
## a drift or a bob over them, so a companion never stands perfectly still.
func _animate(delta: float) -> void:
	if _sprite == null:
		return
	_striking_left = maxf(_striking_left - delta, 0.0)
	var frames: Array[Texture2D] = _frames_idle
	var rate: float = Balance.WILDLIFE_IDLE_FRAME_RATE
	if _striking_left > 0.0 and not _frames_attack.is_empty():
		frames = _frames_attack
		rate = Balance.WILDLIFE_ATTACK_FRAME_RATE
	elif _moving and not _frames_move.is_empty():
		frames = _frames_move
		rate = Balance.WILDLIFE_FLIGHT_FRAME_RATE if data.flies else Balance.WILDLIFE_MOVE_FRAME_RATE
	if not frames.is_empty():
		_frame_clock += delta * rate
		_sprite.texture = frames[int(floor(_frame_clock)) % frames.size()]
	elif _base_texture != null:
		_sprite.texture = _base_texture
	_refresh_bar()
	_bob += delta * 9.0
	var lift: float = -26.0 if data.flies else 0.0
	# A walker with a real cycle keeps its feet on the ground; the bob is for
	# the flier's drift and the single-sprite fallback.
	var sway: float = 5.0 if data.flies else (0.0 if not _frames_move.is_empty() else 2.0)
	_sprite.position = _sprite.position.lerp(
		Vector2(0.0, lift + sin(_bob) * sway), 0.25)
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
	# **A raised animal does not re-form.** It is told once, here, and what that
	# costs is settled when the run ends - not now, because a run that is still
	# being played might yet be abandoned and the pen is not a run's to edit.
	if from_pen:
		RunState.pen_companion_fell = true
		if data != null:
			Vfx.ring(global_position, 110.0, Color(data.colour, 0.75), 0.7, 6.0)
		Sfx.play_at("sfx_companion_down", global_position, 2.0)
		EventBus.spirit_downed.emit(spirit_key, 0.0)
		queue_free()
		return
	_recovering = SpiritBond.recovery_seconds(SpiritBond.rarity_of(spirit_key),
		SpiritBond.shiny_of(spirit_key))
	if _sprite != null:
		_sprite.visible = false
	if _bar != null:
		_bar.visible = false
	Vfx.ring(global_position, 92.0, Color(data.colour, 0.7), 0.5, 5.0)
	Vfx.spark(global_position, data.colour, 18, Vector2.UP, 190.0)
	Sfx.play_at("sfx_companion_down", global_position)
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
	Sfx.play_at("sfx_companion_return", global_position)
	if not _vocal.is_empty():
		Sfx.play_at(_vocal, global_position, -4.0)
	EventBus.spirit_returned.emit(spirit_key)


## Seconds until it returns, for the interface. Zero when it is present.
func recovery_left() -> float:
	return _recovering


## Standing and fighting: not down, not dismissed. What the things that can
## target it ask.
func is_alive() -> bool:
	return data != null and _recovering <= 0.0 and _hp > 0.0 and _left > 0.0


## A blow from something that chose it (owner brief, 2026-09-12: companions
## are targets like players). Same road as the contact damage it already
## takes; going down is the same going down.
func take_damage(amount: float, from: Vector2) -> void:
	if not is_alive() or amount <= 0.0:
		return
	_hp -= amount
	Vfx.spark(global_position, data.colour, 5, (global_position - from).normalized(), 130.0)
	_refresh_bar()
	if _hp <= 0.0:
		_go_down()


## A rabid bite: damage over time, ticked here.
var _poison_left: float = 0.0
var _poison_dps: float = 0.0


func apply_poison(dps: float, seconds: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_left = maxf(_poison_left, seconds)


func _tick_poison(delta: float) -> void:
	if _poison_left <= 0.0:
		return
	_poison_left -= delta
	take_damage(_poison_dps * delta, global_position + Vector2.DOWN)


func contact_radius() -> float:
	return 30.0 * (data.scale if data != null else 1.0)


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
	# **A spirit has a sex, and it is the same one all run** (owner brief,
	# 2026-09-14). Decided once per bond key from the run's seed and kept in
	# `RunState.companion_sex`, so dismissing it, re-equipping it and
	# reconnecting all read the same answer and nothing has to cross the wire.
	# Worn on `self_modulate`, which is under the rarity hue and well under a
	# shiny's band - a tell for a player who looks, never a second palette.
	_sprite.self_modulate = Balance.WILDLIFE_SEX_TINT[
		clampi(WildlifeFamilies.companion_sex(spirit_key), 0, 1)]
	# A slow breath rather than a flicker: it has to survive being looked at for
	# a whole run, which is a much harder test than looking good for a second.
	var breath: Tween = _sprite.create_tween().set_loops()
	var dim: Color = hue
	dim.a = Balance.SPIRIT_DRAW_ALPHA * 0.78
	var half: float = 0.5 / maxf(Balance.SPIRIT_BREATH_HZ, 0.05)
	breath.tween_property(_sprite, "modulate", dim, half)
	breath.tween_property(_sprite, "modulate", hue, half)


## A fish, handed over (owner brief, 2026-09-13).
##
## Heals by the fish's rarity and stops the spirit being hungry for a while -
## which is what makes a full larder worth spending on something other than
## yourself, now that a spirit eats to stay out.
func feed(kind: FishData) -> void:
	if kind == null:
		return
	var tier: int = clampi(int(kind.rarity), 0, Balance.FISH_SPIRIT_HEAL.size() - 1)
	_hp = minf(_hp + _max_hp * Balance.FISH_SPIRIT_HEAL[tier], _max_hp)
	_refresh_bar()
	RunState.feed_the_spirit(Balance.FISH_SPIRIT_FULL_SECONDS[tier])
	Vfx.ring(global_position, 60.0, kind.rarity_colour(), 0.45, 4.0)
	Vfx.spark(global_position, kind.rarity_colour(), 9, Vector2.UP, 150.0)
	Sfx.play("sfx_ui_confirm", -3.0)


## `FrameProfile` bucket "companion": the real work is `_physics_process_measured` above.
func _physics_process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_physics_process_measured(delta)
	FrameProfile.add(&"companion", started)
