class_name Enemy
extends Node2D

## True only for the one elite demanded by Oath of the Last Scar.
var oath_pursuer: bool = false

## One enemy walking a lane (GDD §3). Everything about it comes from an
## EnemyData resource, so adding a breed is adding a `.tres`.
##
## **Enemies do not damage by touching.** They walk until something is in reach,
## stop, wind up on a visible tell, and strike. Contact damage was how the first
## prototype worked and it made attacking feel like self-harm: you had to be
## inside the thing that was hurting you in order to hit it. The wind-up is what
## gives the dash something to dodge and the melee chain a window to live in.

const GROUP: StringName = &"enemies"

## Enemies that exist only because a boss called them.
##
## A group rather than a list held by BossDirector: the boss can die on any
## frame, summons die on their own all the time, and a list of node references
## would need validity-checking on every entry. The group carries the same
## information and cannot dangle.
const ActorPolishScript = preload("res://scripts/systems/actor_polish.gd")

const SUMMON_GROUP: StringName = &"boss_summons"

## Identity across two machines, assigned by the host when it spawns this.
##
## Zero in a single-player run and for anything the host never announced. Node
## names would have been the obvious alternative and are the wrong one: they are
## unique within a parent, not across a wire, and Godot renames on collision - so
## two machines can disagree about which enemy is which without either being
## wrong locally.
var net_id: int = 0

## True when this is a picture of an enemy simulated on another machine.
##
## A puppet decides nothing. It does not pick targets, walk, strike, take damage
## or pay out; its position and health arrive as facts. Everything else - the
## sprite, the facing, the walk animation, the tint - runs through exactly the
## same code as a real enemy, which is why a guest's battlefield looks alive
## rather than like a slideshow of the host's.
var puppet: bool = false
var _puppet_last: Vector2 = Vector2.ZERO

## Where the host last said this is, and how long there is to get there.
##
## A puppet is **interpolated**, not snapped. Positions arrive ten times a second
## and a body that jumps to each one and then waits is a body that stutters -
## reported from play as "enemy walks are all jittery". Between packets it walks
## the remaining distance at the speed that will arrive exactly as the next one
## does, so the motion is continuous and the position is still the host's.
var _mirror_target: Vector2 = Vector2.ZERO
var _mirror_ratio: float = 0.0

## True once a position has actually arrived from the host. A puppet decides
## nothing, and that includes deciding where it is before it has been told.
var _mirrored_once: bool = false

## The speed the last two packets implied, so a puppet keeps moving between them.
var _mirror_velocity: Vector2 = Vector2.ZERO

## How long the host has been quiet, so a dropped connection stops rather than
## walking the whole field off the map.
var _mirror_stale: float = 0.0

enum State {
	WALKING,
	WINDUP,
	STRIKE,
	RECOVER,
	DYING,
	## Broken and running. Appended rather than inserted: the state travels over
	## the wire as its integer, so every value before this has to keep its place.
	ROUTED,
	## The tell before a breed's own committed action, and the action itself.
	## Appended for the same reason as `ROUTED`: these are wire values.
	BRACE,
	COMMIT,
}

@export var health: Health
@export var sprite: Sprite2D

## Authored walk frames, and the resting pose they are played instead of.
##
## Empty for anything whose art has none, and that is a supported state rather
## than a gap: `SpriteAnimator` moved every enemy in this game convincingly for
## months on a single static PNG. Frames are an upgrade on top of that, not a
## replacement for it - see `Balance.ENEMY_FRAME_WALK_DAMPING`.
var _walk_frames: Array[Texture2D] = []
var _idle_frames: Array[Texture2D] = []
var _idle_phase: float = 0.0

## The swing, drawn rather than implied.
##
## `_advance_walk_frames` has said since it was written that "the windup
## animation is drawn from the rest pose" - and there was no windup animation.
## An enemy about to hit you stood perfectly still in its standing pose for the
## entire 0.45s tell, which is the one moment in the fight the player is reading
## the body hardest. Authored 2026-09-01 for all twenty-four walkers.
var _attack_frames: Array[Texture2D] = []
var _rest_texture: Texture2D = null

## Advanced by ground covered, never by time, so a chilled or slowed enemy takes
## slower steps rather than moon-walking at full cadence over frozen ground.
var _walk_phase: float = 0.0

## This enemy's own stain material. See `BloodStain`.
var _blood: ShaderMaterial = null
var _blood_tried: bool = false

## A promoted body's polish material, kept rather than dropped on the floor.
##
## An elite claims the sprite's material slot at spawn, which makes `_blood` null
## for the rest of its life - so before 2026-09-01 this reference was created,
## configured and discarded, and there was no way to write anything to a
## promoted body afterwards. Combat state has to reach both. See `ActorState`.
var _polish: ShaderMaterial = null
var _state_seeded: bool = false

## Nerve, 1 whole and 0 broken.
##
## Owner request, 2026-09-02, under "the Road is always telling you something":
## a line that breaks when its champion falls is information the player can read
## off the field without a single number being displayed.
##
## **Only the shape of a fight, never its size.** A routed body runs for a few
## seconds and comes back; it does not despawn, does not stop counting toward the
## wave, and pays out exactly what it always did. That is what keeps morale out
## of the three-act pressure curve - the curve is tuned against how many bodies
## arrive, and this changes none of them. `morale_check` holds that.
var _morale: float = 1.0
var _rout_left: float = 0.0
@export var health_bar: HealthBar
@export var animator: SpriteAnimator

## Set by the spawner before the node enters the tree.
var data: EnemyData = null
var lane: int = 0

# --- Camp mode (2026-09-12) ------------------------------------------------
#
# A camp body belongs to a place rather than to a wave. It has no route and
# no interest in the town: it patrols its ground, goes for a hero who comes
# close, follows only so far, and walks home healing when the hero leaves -
# the jungle-camp rule. Everything else about it - health, damage, the swing,
# the death payout - is the ordinary enemy at a scale, so ten acts of camps
# needed no second roster. `Camps` owns the placing and the paying.

## The group a camp body also joins, so the wave and the pressure readout can
## leave it out: a camp is not a wave, and a camp mob alive on the outskirts
## must not hold a wave open or light a lane.
const CAMP_GROUP: StringName = &"camp_mobs"

## Where this body lives, or INF for a wave body.
var camp_home: Vector2 = Vector2.INF
## How far from home it will follow a hero before turning back.
var camp_leash: float = 0.0
var _camp_goal: Vector2 = Vector2.INF
var _camp_pause: float = 0.0
## Seconds a camp body has gone without a target or a blow.
var _camp_calm: float = 0.0
var _camp_returning: bool = false

var _field: EnemyField = null
var _state: State = State.WALKING
var _state_left: float = 0.0
var _target: Node2D = null

## The animal that bit this one, and the system that owns its numbers.
##
## Held for a few seconds so retaliation is a *reaction* rather than a permanent
## second allegiance: a wolf that harries a column and moves on should get bitten
## for it, and a column that then abandoned the road to hunt wolves would be a
## different game.
var _provoker: Node2D = null
var _provoker_source: Node = null
var _provoked_left: float = 0.0
## When this boss may slam and volley again, and how long its tell has left.
var _slam_left: float = 0.0
## Which shot the current attack drew, so the projectile can be painted.
var _shot_paint: EnemyShotData = null
## **Whether this wind-up ends in a throw rather than a blow**, and how long
## until the next one is allowed. See `EnemyData.thrown_shot_id`: a body that
## closes may let one thing go on the way in, and this is the whole of the extra
## state that costs.
var _throwing: bool = false
var _throw_cooldown: float = 0.0
var _volley_left: float = 0.0
var _slam_tell: float = 0.0

var _knockback: Vector2 = Vector2.ZERO
var _hitstun_left: float = 0.0

## Counts down before another hitstun may be applied. Without it, every hit
## refreshes the flinch and a well-covered tile switches an enemy off.
var _hitstun_refractory: float = 0.0
var _flash_left: float = 0.0
var _impact_direction: Vector2 = Vector2.UP
var _death_left: float = 0.0
var _oath_mark: Line2D = null
var _oath_mark_time: float = 0.0

## Lateral offset from the lane centre line, so a wave reads as a column.
var _lane_offset: float = 0.0

## Which leg of the road this enemy is walking. Only ever increases.
var _path_index: int = 0

## The way in this enemy chose when it spawned.
##
## Held rather than looked up, because the authored map forks: asking the lane
## for "the" path would send every enemy down the shortest corridor and quietly
## throw away the whole point of the layout. Chosen once so the choice is stable
## - re-rolling it per frame would make an enemy dither at every junction.
var _route: PackedVector2Array = PackedVector2Array()


## Separate scaling keeps durability tense without letting late enemies erase
## the town in one hit. Speed gets its own gentler curve too.
var _hp_scale: float = 1.0
var _damage_scale: float = 1.0
var _speed_scale: float = 1.0

# --- Status effects ---
## Movement penalty, derived from `_chill` every tick. Kept as its own field
## because movement and target sorting both read it on hot paths.
var _slow_factor: float = 1.0
## The breed's own committed action: when it may next take one, which way it is
## committed, and what it has banked toward one.
var _behaviour_wait: float = 0.0
var _behaviour_aim: Vector2 = Vector2.RIGHT
var _behaviour_bank: float = 0.0
## How long a guard this body is standing behind has left, and whose it is. A
## guard turns one blow; see `_absorb_guard`.
var _guard_left: float = 0.0

## The chill meter, 0..1. Every slow in the game feeds this one value rather than
## overwriting the last one, and it is the single source of both how slowly the
## enemy walks and whether it shatters. See the chill block in Balance.
var _chill: float = 0.0

## While positive, chill holds instead of decaying. This is what an authored
## `slow_duration` means now.
var _chill_hold: float = 0.0

## Counts down before this enemy may be locked again.
var _freeze_refractory: float = 0.0

var _freeze_left: float = 0.0
var _burn_dps: float = 0.0
var _burn_left: float = 0.0
## Wet: seconds left of it from water that hit this body. Rain and a flood
## wet everybody without a timer - see `is_wet`.
var _wet_left: float = 0.0

## Velocity from the previous frame drives the procedural gait. Keeping it here
## also makes hitstun and freezing visibly settle instead of walking in place.
var _motion: Vector2 = Vector2.ZERO
var _boss_phase: int = 0

## Distance from the depth/contact root to the centre-authored combat pose.
## Stored when category scale is applied so hit feedback never originates from
## the feet merely because the node itself must sort there.
var _depth_lift: float = 0.0

## A slide in progress on snow, and how long is left of it.
##
## Sideways rather than forwards: a slip is losing your footing, not being
## hurried along. Carried as a velocity so it composes with the walk instead of
## replacing it - an enemy mid-slip is still trying to get where it was going,
## which is what makes it read as a stumble rather than as a teleport.
var _slip: Vector2 = Vector2.ZERO
## **This body's own temperament** (owner, 2026-09-22): how far into its reach a
## ranged body comes before it fires on the wall, how its attack cadence
## wanders, and when it may next sidestep a swing. Its own dice, seeded from
## its identity, so nothing it rolls moves the run's stream.
var _temper := RandomNumberGenerator.new()
var _siege_share: float = 1.0
var _dodge_ready: float = 0.0
var _slip_left: float = 0.0


## What a promoted enemy is (owner decision, 2026-08-31).
##
## Orthogonal to `EnemyData.Category`, which is a *breed* - a Bogkin is rank and
## file, a Chainmaker is a boss. Rank is what happened to this particular one on
## its way down the road, so any breed can wear it.
enum Rank {
	## The ordinary case, and it stays the overwhelming one.
	COMMON,
	## Three or four of a kind, all carrying the same single affix. The pack is
	## the threat; no one of them is.
	CHAMPION,
	## One of a kind, carrying several. It is the encounter.
	ELITE,
}

var rank: Rank = Rank.COMMON
var affixes: Array[EnemyAffixData] = []

## The outline that says "this one is different", kept so it can follow the
## sprite's own size.
var _mark: Line2D = null


## Raises this one and applies everything its affixes say.
##
## **Called before `setup`**, because the health scale it produces has to be in
## hand when the health node is filled - promoting afterwards would leave a
## champion with a common's hit points and no error anywhere.
##
## The affixes are simply multiplied together and their effects all apply. That
## is what makes combinations free: Rimewarded and Volatile is a body that chills
## what it touches and detonates when it dies, and nothing anywhere describes
## that pair. A table of every combination is a table that has to be maintained;
## multiplication is not.
func promote(to_rank: Rank, worn: Array[EnemyAffixData]) -> void:
	rank = to_rank
	affixes = worn
	# A ranked body wears a wider bar from the first frame, so the thing that
	# takes forty hits is seen to be that before the first one lands.
	if health_bar != null and to_rank != Rank.COMMON:
		health_bar.set_ranked(Balance.HEALTH_BAR_ELITE_WIDTH if to_rank == Rank.ELITE \
			else Balance.HEALTH_BAR_CHAMPION_WIDTH)
	_wear_rank()


## **A hint of light on the bodies that are the fight** (owner, 2026-09-15:
## "elite and champion enemies should have a hint of holographic-esque vfx juice
## as well"). A champion and an elite wear it faintly; a camp lord, which is a
## miniboss on its own, wears it a little harder.
##
## Called from `promote` and from `_ready`, because the two ways a body becomes
## notable are unrelated: rank is rolled and handed in, and the category is
## authored. A lord is never promoted, so reading only `promote` would have left
## every dragon in the game unlit.
##
## It reads nothing back. See `rank_sheen.gd` for why it is an overlay node
## rather than a material on this sprite.
func _wear_rank() -> void:
	if sprite == null or data == null:
		return
	var amount: float = 0.0
	if data.category == EnemyData.Category.CAMP_LORD:
		amount = Balance.RANK_SHEEN_LORD
	elif rank != Rank.COMMON or data.is_promoted():
		amount = Balance.RANK_SHEEN_ELITE
	if amount <= 0.0:
		return
	RankSheen.dress(sprite, amount, Balance.RANK_SHEEN_ENEMY_COLOUR)


## The combined multiplier for one stat across every affix worn.
func _affix_product(field_name: StringName) -> float:
	var total: float = 1.0
	for affix: EnemyAffixData in affixes:
		total *= float(affix.get(field_name))
	return total


## The largest value any worn affix contributes. Used where stacking would be
## absurd - two sources of resistance should not approach immunity.
func _affix_best(field_name: StringName) -> float:
	var best: float = 0.0
	for affix: EnemyAffixData in affixes:
		best = maxf(best, float(affix.get(field_name)))
	return best


## The rank's own multiplier, before any affix.
func _rank_scale() -> Vector3:
	match rank:
		Rank.CHAMPION:
			return Vector3(Balance.CHAMPION_HEALTH_SCALE,
				Balance.CHAMPION_DAMAGE_SCALE, Balance.CHAMPION_SIZE_SCALE)
		Rank.ELITE:
			return Vector3(Balance.ELITE_HEALTH_SCALE,
				Balance.ELITE_DAMAGE_SCALE, Balance.ELITE_SIZE_SCALE)
		_:
			return Vector3.ONE


## The name the player reads: "Rimewarded Emberclad Bogkin".
##
## Built from the affixes rather than authored, so a new affix needs no strings
## and a combination names itself.
## Makes this body a camp body: home, leash, no route. Called by `Camps`
## after the spawn, once the node is in the tree.
func make_camp_mob(home: Vector2, leash: float) -> void:
	camp_home = home
	camp_leash = leash
	_route = PackedVector2Array()
	_path_index = 0
	_lane_offset = 0.0
	_camp_goal = home
	_camp_pause = 0.0
	add_to_group(CAMP_GROUP)


## A point along this body's route, by fraction of its length from the spawn.
## Zero is the spawn itself. Used to place a breed that surfaces closer in.
func route_point_at(fraction: float) -> Vector2:
	if _route.size() < 2:
		return _route[0] if _route.size() == 1 else global_position
	var total: float = 0.0
	for index: int in _route.size() - 1:
		total += _route[index].distance_to(_route[index + 1])
	var wanted: float = clampf(fraction, 0.0, 1.0) * total
	for index: int in _route.size() - 1:
		var leg: float = _route[index].distance_to(_route[index + 1])
		if wanted <= leg or index == _route.size() - 2:
			_path_index = index
			return _route[index].lerp(_route[index + 1], clampf(wanted / maxf(leg, 0.001), 0.0, 1.0))
		wanted -= leg
	return _route[0]


## Whether something provoked this body recently enough that it is still
## coming for whoever did it. Public because the towers ask (2026-09-13).
## The scope this body was stood up in.
##
## `Enemy.GROUP` is global and a raid camp, a rift maze and the road are all
## `EnemyField`s full of enemies, so "every enemy in the group" is never the
## same question as "every enemy on this field". See `EnemyField.holds_the_wave`.
func field() -> EnemyField:
	return _field


func is_provoked() -> bool:
	return _provoked_left > 0.0


func is_camp_mob() -> bool:
	return camp_home != Vector2.INF


## True while it is walking home to heal; the camp reads this to know a fight
## was broken off rather than won.
func is_camp_returning() -> bool:
	return _camp_returning


func promoted_name() -> String:
	if rank == Rank.COMMON or data == null:
		return data.display_name if data != null else ""
	var parts: PackedStringArray = []
	for affix: EnemyAffixData in affixes:
		parts.append(affix.display_name)
	parts.append(data.display_name)
	return " ".join(parts)


func setup(enemy_data: EnemyData, lane_index: int, field: EnemyField,
		hp_scale: float, damage_scale: float = -1.0, speed_scale: float = 1.0) -> void:
	data = enemy_data
	lane = lane_index
	_field = field
	_hp_scale = hp_scale
	_damage_scale = hp_scale if damage_scale < 0.0 else damage_scale
	_speed_scale = speed_scale
	_route = field.lane_route(lane_index)
	# **What this body plants on the ground**, for the dust its stride throws up
	# (owner, 2026-09-17). Every one of the three numbers is derived from what
	# the breed already declares rather than authored beside it: its own contact
	# radius is the footprint, its hide is the weight - plate and stone drive
	# into the earth, flesh does not, and a spirit has a mass of zero and so is
	# never registered at all - and its own walking speed is what its effort is
	# measured against. So a breed added tomorrow scuffs correctly without
	# anybody remembering this file.
	Footfalls.register(self, contact_radius(),
		Balance.FOOTFALL_MASS_BY_HIDE[clampi(int(data.hide), 0,
			Balance.FOOTFALL_MASS_BY_HIDE.size() - 1)] if data != null else 1.0,
		maxf(data.move_speed if data != null else 1.0, 1.0) * maxf(speed_scale, 0.2))


func _ready() -> void:
	_temper.seed = hash(get_instance_id())
	_siege_share = _temper.randf_range(Balance.ENEMY_SIEGE_SHARE.x,
		Balance.ENEMY_SIEGE_SHARE.y)
	EventBus.hero_swing_started.connect(_on_hero_swing)
	add_to_group(GROUP)
	# **A mark that is born wearing a ward.** Through `guard`, the same door an
	# anchor's shelter uses, so a guarded body turns one blow and is spent - and
	# nothing had to learn that an affix can grant one.
	for affix: EnemyAffixData in affixes:
		if affix.spawn_guard > 0.0:
			grant_guard(affix.spawn_guard)
	if data == null or _field == null:
		push_error("Enemy spawned without data or battlefield; setup() must run first.")
		queue_free()
		return

	# The rank and its affixes multiply into the authored number. Applied here
	# rather than after `setup` because the health node is filled on this line -
	# a promotion that arrived a moment later left a champion with a common's
	# hit points and nothing said so.
	# Every multiplier at once, under one ceiling. Act scale, camp scale, a
	# war camp's champion scale, a rank and two affixes stacked to eighty
	# times a breed's health once - a body the owner hit for five minutes to
	# take a quarter off. Nothing here is a twenty-minute wall.
	var stacked: float = _hp_scale * _rank_scale().x * _affix_product(&"health_scale")
	health.max_hp = data.max_hp * minf(stacked, Balance.ENEMY_HEALTH_MULTIPLIER_CEILING)
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health_bar.bind(health)
	_wear_rank()
	if data != null and data.category == EnemyData.Category.BOSS:
		health_bar.set_ranked(Balance.HEALTH_BAR_BOSS_WIDTH)
	if oath_pursuer:
		_build_oath_mark()

	# Met, and remembered. Recorded on the breed and on every affix it wears, so
	# the codex learns "Rimewarded" the first time one walks down the road rather
	# than only when the player goes looking for it.
	if not puppet:
		MetaState.record_seen("enemy", data.id)
		for affix: EnemyAffixData in affixes:
			MetaState.record_seen("affix", affix.id)
	animator.mass = _mass_for_category()
	animator.capture_home()

	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
		_rest_texture = sprite.texture
		# Frame zero is deliberately *not* part of the loop - `load_move_frames`
		# excludes it, because the base sprite is a standing pose and a two-frame
		# cycle alternating between standing and mid-stride reads as the sprite
		# being swapped rather than animated. That was learned on the wildlife.
		_walk_frames = GameData.load_move_frames(path)
		_idle_frames = GameData.load_idle_frames(path)
		_attack_frames = GameData.load_attack_frames(path)
	if not _walk_frames.is_empty():
		animator.walk_cycle_scale = Balance.ENEMY_FRAME_WALK_DAMPING
	_apply_category_scale()
	# **After the scale, because the ring is drawn around `_depth_lift`** and
	# that is where it is computed. Built before it, the offset read zero and the
	# circle sat a sprite-height low - on the feet, describing the ground rather
	# than the archer. Reported twice as the range circle still being wrong after
	# it had supposedly been recentred; the offset was right and the ordering was
	# not.
	if data.role == EnemyData.Role.HOWLER:
		_build_aura_readout()
	_build_rank_mark()
	animator.capture_home()

	# Shadows are added after the texture, because both are measured from it.
	# A pool under every walker is most of what stops a crowd looking like decals
	# sliding across the floor, and the caster is what makes them streak past a
	# torch at night.
	ShadowKit.add_contact(self, sprite)
	var half: Vector2 = sprite.texture.get_size() * sprite.scale.abs() * 0.5 \
		if sprite.texture != null else Vector2(40, 40)
	ShadowKit.add_caster(self, half.x * 0.42, half.y * 0.20,
		Balance.SHADOW_LAYER_UNITS, half.y * 0.40)

	_lane_offset = RunState.rng("combat").randf_range(
		-Balance.LANE_WIDTH, Balance.LANE_WIDTH) * 0.5
	EventBus.beast_step_landed.connect(_on_beast_step)
	EventBus.enemy_spawned.emit(data.id, global_position)


func _process(delta: float) -> void:
	_tick_oath_mark(delta)
	# Famished and its kind, closing its own wounds.
	if not affixes.is_empty() and _state != State.DYING and health != null:
		var mend: float = _affix_best(&"regeneration")
		if mend > 0.0 and health.current_hp < health.max_hp:
			health.heal(health.max_hp * mend * delta)
	if _state == State.DYING:
		_tick_death(delta)
		return

	if puppet:
		_tick_puppet(delta)
		return

	_tick_status(delta)
	_hitstun_left = maxf(_hitstun_left - delta, 0.0)
	_hitstun_refractory = maxf(_hitstun_refractory - delta, 0.0)
	# **The footing recovers whenever the blows stop**, which is what makes
	# "leave it alone for a moment" the answer rather than a cooldown nobody can
	# see. Ticked here beside the hitstun rather than with the brand, where the
	# first cut put it - `_tick_brand` returns early unless a body is branded, so
	# the load never drained and a plant never ended.
	_stagger_load = maxf(_stagger_load
		- delta / maxf(Balance.STAGGER_WINDOW, 0.01), 0.0)
	_braced_left = maxf(_braced_left - delta, 0.0)
	_brace_refractory = maxf(_brace_refractory - delta, 0.0)
	if _interrupt_clock > 0.0:
		_interrupt_clock -= delta
		if _interrupt_clock <= 0.0:
			_interrupts = 0
	_flash_left = maxf(_flash_left - delta, 0.0)
	_provoked_left = maxf(_provoked_left - delta, 0.0)
	_tick_boss_abilities(delta)
	_knockback = _knockback.move_toward(Vector2.ZERO, Balance.ENEMY_KNOCKBACK_DECAY * delta)

	var before: Vector2 = global_position
	if _freeze_left <= 0.0 and _hitstun_left <= 0.0:
		_tick_state(delta)

	if not _knockback.is_zero_approx():
		global_position = _bounced(global_position + _knockback * delta)
	# **A body standing on the base is put back outside it.**
	#
	# **Not a second copy of `step_is_legal`.** That one refuses a step crossing
	# *in* and deliberately never refuses one going out - its own note lists how a
	# body ends up inside anyway: spawned there, shoved by the crowd, standing
	# there when the town was rebuilt. It declines to repair those. This is the
	# repair.
	#
	# **Padded by the footprint, never by the painting, and the difference is the
	# whole siege.** `deflect_from_city` *grows* the rect by the padding, so the
	# padding is not a safety margin applied to bodies already inside - it is the
	# distance at which every body is turned away. Padded by `sprite_clearance`,
	# which is the whole sprite's diagonal half-extent, that distance is about 135
	# units: a breed that walked up honestly was teleported back out to it on every
	# frame and stood there for the rest of the run. A melee swing is
	# `ENEMY_ATTACK_RANGE + contact_radius()`, about 84, so melee could never land
	# a blow on the city at all, while an Ember Shaman's 210 could - which is
	# exactly what the owner photographed on 2026-09-20: three shamans that would
	# not come closer and one of them shooting the wall from where it stood.
	#
	# The footprint is what the owner asked for in as many words - walk up to the
	# point of colliding with the base's sprite, and deflect off it. Feet at the
	# edge, art free to overlap, everything in reach.
	var battlefield := _field as Battlefield
	if battlefield != null:
		global_position = battlefield.deflect_from_city(global_position,
			contact_radius())
	_motion = (global_position - before) / maxf(delta, 0.0001)
	animator.set_motion(_motion, maxf(data.move_speed, 1.0), delta)
	_update_sprite(delta)
	_update_blood(delta)


func _build_oath_mark() -> void:
	_oath_mark = Line2D.new()
	var points: PackedVector2Array = []
	for index: int in 49:
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 48.0) * 64.0)
	_oath_mark.points = points
	_oath_mark.width = 4.0
	_oath_mark.default_color = Color(1.0, 0.24, 0.16, 0.82)
	_oath_mark.z_index = -1
	add_child(_oath_mark)


func _tick_oath_mark(delta: float) -> void:
	if _oath_mark == null:
		return
	_oath_mark_time += delta
	_oath_mark.modulate.a = 0.48 + sin(_oath_mark_time * 5.2) * 0.25
	_oath_mark.scale = Vector2.ONE * (1.0 + sin(_oath_mark_time * 3.1) * 0.06)


## A mirrored enemy: draw what arrived, decide nothing.
##
## Motion is *derived* from the position the host sent rather than sent
## alongside it. Two reasons: it is a vector the wire does not have to carry, and
## it means facing and the walk cycle are driven by the same `_motion` the real
## enemy uses. A puppet with its own facing rule would be a second implementation
## of the thing that was just fixed for walking backwards.
func _tick_puppet(delta: float) -> void:
	# Walk toward where the host says to be, rather than teleporting there. The
	# step is scaled by how much of the remaining window this frame is, so the
	# body arrives just as the next packet lands however the frame rate varies.
	# **Dead reckoning, corrected continuously.**
	#
	# The first version walked to the last position it was told and arrived
	# exactly as the next packet was due. That is right only when the packet is
	# on time; one late by a single frame left the body standing still and then
	# jerking off toward its new target - arrive, stop, jerk, arrive - which is
	# what "stutter step" looks like from the other seat. Coasting when the
	# window ran out fixed the standing still and left the jerk, because the body
	# was still always chasing a position that was already a packet old.
	#
	# So it does both, every frame, and neither has a deadline. It moves at the
	# speed it was last told, and it eases toward where the host's copy should be
	# *now* - the last position plus that speed times how long ago it arrived.
	# The error shrinks smoothly instead of being spent in a scheduled arrival,
	# and the body never stops, which matters because every animation here is
	# chosen from motion.
	# Nothing until the host has said something. Without this the projected
	# position is the default `Vector2.ZERO` and a puppet that has not yet been
	# told anything walks steadily to the middle of the map - caught by the
	# co-op gate on the first run, which is what that assertion is for.
	if not _mirrored_once:
		return
	_mirror_stale += delta
	var window: float = maxf(_mirror_ratio, 0.05)
	var ahead: float = minf(_mirror_stale, Balance.COOP_MIRROR_COAST_LIMIT)
	var projected: Vector2 = _mirror_target + _mirror_velocity * ahead
	global_position += _mirror_velocity * delta
	global_position = global_position.lerp(projected,
		clampf(delta / window * Balance.COOP_MIRROR_CATCHUP, 0.0, 1.0))
	# Unless the host has been quiet long enough that guessing is worse than
	# waiting - a body that keeps walking on a dropped connection walks off the
	# map.
	if _mirror_stale > Balance.COOP_MIRROR_COAST_LIMIT:
		_mirror_velocity = Vector2.ZERO
	_motion = (global_position - _puppet_last) / maxf(delta, 0.0001)
	_puppet_last = global_position
	if animator != null and data != null:
		animator.set_motion(_motion, maxf(data.move_speed, 1.0), delta)
	_update_sprite(delta)


## The scaling this enemy was spawned with, so a mirror can be built to match.
##
## Read rather than guessed: the guest must construct an identical enemy or the
## health bar it draws is a bar for a different creature.
func hp_scale() -> float:
	return _hp_scale


func damage_scale() -> float:
	return _damage_scale


func speed_scale() -> float:
	return _speed_scale * (1.0 + aura_haste())


## Health as 0..1, which is what crosses the wire. A ratio rather than an
## absolute survives any later change to how max health is computed.
func health_ratio() -> float:
	return health.ratio() if health != null else 0.0


## How long to expect between position packets, in seconds.
##
## Told rather than guessed: the interpolation has to know the size of the window
## it is spreading movement across, and a hard-coded copy of `BATCH_INTERVAL`
## here would silently start stuttering the day that constant was tuned.
func set_mirror_interval(seconds: float) -> void:
	_mirror_ratio = seconds


## Takes a position and health from the host.
##
## Health is assigned rather than damaged: a puppet must not run the death path,
## because the host already ran it and will say so with its own message. Two
## machines each paying out the same kill is how a shared purse doubles.
## Plays a blow the host has already resolved. Guest side.
##
## Cosmetic by construction: nothing here damages anything, because the host has
## and reports the result as health in the next batch. What it adds is the part
## the guest could not derive - a shot leaving a ranged enemy, and the punch that
## makes a melee swing read as a swing rather than as damage appearing.
func strike_remote(at: Vector2, shot_id: String = "") -> void:
	if _state == State.DYING or _field == null or data == null:
		return
	if animator != null:
		animator.punch((at - global_position).normalized(), 1.1)
	if data.role != EnemyData.Role.HOWLER and shot_id.is_empty():
		return
	# **Wearing the shot the host threw** (2026-09-21): the name crosses with
	# the fact and the look is read off this machine's own content, so a
	# partner's screen shows the breed's own head and never a guess. The
	# picture is a bolt whatever the kind - a guest resolves no ground blow.
	_shot_paint = _shot_named(shot_id)
	var shot := load("res://scenes/battlefield/enemy_projectile.gd").new() as EnemyProjectile
	_paint(shot)
	shot.configure_toward(at, combat_origin())
	_field.add_child(shot)


## One of this breed's own shots by name, or null.
func _shot_named(id: String) -> EnemyShotData:
	if data == null or id.is_empty():
		return null
	for entry: EnemyShotData in data.repertoire():
		if entry != null and entry.id == id:
			return entry
	if data.thrown_shot() != null and data.thrown_shot().id == id:
		return data.thrown_shot()
	if data.volley_shot() != null and data.volley_shot().id == id:
		return data.volley_shot()
	return null


## Which of the four combat states this is in, for the wire.
func combat_state() -> int:
	return int(_state)


func mirror(at: Vector2, hp_ratio: float, state: int = -1) -> void:
	# The first packet places it; every one after aims it. Snapping on arrival
	# would put the body where it *was* when the packet was sent and then leave
	# it there, which is the stutter this exists to remove.
	var window: float = maxf(_mirror_ratio, 0.05)
	# **A correction bigger than anything that could have happened is a teleport.**
	#
	# Interpolating one draws the enemy sprinting the width of the field in a
	# tenth of a second, which is what "enemies zoom to the opposite side of the
	# map" is: a body that is simply in the wrong place, with the trip to the
	# right one played out in full view. Showing the jump is the lesser lie, and
	# it covers every way a puppet can end up misplaced - a missed spawn packet,
	# a late join, a knockback - rather than only the one that was found.
	var reachable: float = maxf(data.move_speed if data != null else 1.0, 1.0) 		* window * Balance.COOP_MIRROR_SNAP_FACTOR
	if not _mirrored_once 			or global_position.distance_to(at) > reachable:
		global_position = at
		_puppet_last = at
		_mirror_velocity = Vector2.ZERO
	else:
		# Derived from the *previous* target rather than from where the body
		# actually is: the body is mid-correction and its own displacement is
		# part interpolation, which would feed the error back into the guess.
		# Blended rather than replaced, because a single late or early packet
		# makes one estimate wildly wrong and a puppet should not lurch for it.
		_mirror_velocity = _mirror_velocity.lerp((at - _mirror_target) / window,
			Balance.COOP_MIRROR_VELOCITY_BLEND)
	_mirror_stale = 0.0
	_mirror_target = at
	_mirrored_once = true
	# The wind-up, the strike and the recovery all read from `_state`: it drives
	# the tell's pulsing tint and the animator's posture. A puppet given only a
	# position is an enemy that kills you with no warning, because the telegraph
	# the dodge window depends on never appears.
	#
	# DYING is never taken from the wire. A puppet leaves through `dismiss`, and
	# letting a packet put it into the dying state would start a second death
	# alongside the one already running.
	if state >= 0 and state != int(State.DYING) and _state != State.DYING:
		var was: State = _state
		_state = state as State
		if was != _state and animator != null:
			# Played on the transition rather than every packet, or the enemy
			# shudders in place for the whole state.
			#
			# All three, because a mirrored enemy was coiling and then never
			# swinging: the wind-up crossed and the *punch* did not, so from the
			# guest's seat every attack was a threat that never landed.
			match _state:
				State.WINDUP:
					# The coil the player reads.
					animator.squash(Balance.ANIM_HURT_SQUASH * 0.8)
				State.STRIKE:
					# Toward whatever it faces: the wire carries no target, and
					# an enemy's facing already points at the thing it is hitting.
					animator.punch(
						Vector2.LEFT if sprite.flip_h else Vector2.RIGHT, 1.1)
				State.RECOVER:
					animator.squash(Balance.ANIM_HURT_SQUASH * 0.45)
				_:
					pass
	if health != null and health.max_hp > 0.0:
		var was_hp: float = health.current_hp
		health.current_hp = clampf(hp_ratio, 0.0, 1.0) * health.max_hp
		health.changed.emit(health.current_hp, health.max_hp)
		var lost: float = was_hp - health.current_hp
		if lost > health.max_hp * 0.005:
			_react_to_mirrored_hit(lost)


## Plays the reaction to damage this machine did not resolve.
##
## Without this a guest fights in silence: its own hero's swings land on puppets,
## `take_damage` rightly refuses them, and the player sees no number, no spark
## and no recoil - only a health bar quietly draining. Feeling a hit land is not
## cosmetic detail, it is the whole feedback loop of attacking.
##
## The amount is whatever was lost since the last packet, so several small hits
## inside one batch window arrive as one number. That is a fair summary rather
## than a lie: the total is right, and inventing separate numbers for damage the
## host never itemised would be the invention.
##
## Direction is taken from where this enemy is looking, because the wire does not
## carry it and that is where the fight is - an enemy is facing its target, and
## its target is what hit it.
func _react_to_mirrored_hit(lost: float) -> void:
	if data == null or _state == State.DYING:
		return
	var facing: Vector2 = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	var from: Vector2 = global_position + facing * 24.0
	var body_at: Vector2 = _visual_origin()
	Vfx.number(body_at, lost, Color("ffe3b0"), lost >= data.max_hp * 0.4)
	Vfx.spark(body_at, Color("ffcf9a"), 4, -facing, 170.0)
	Vfx.blood(body_at, -facing, Balance.VFX_BLOOD_HIT_SIZE, global_position)
	if animator != null:
		animator.recoil(from, global_position,
			clampf(lost / maxf(data.max_hp, 1.0) * 3.0, 0.5, 1.8))
		animator.impact_frame()


# --- State machine ----------------------------------------------------------

func _tick_state(delta: float) -> void:
	match _state:
		State.WALKING:
			_grudge_left = maxf(_grudge_left - delta, 0.0)
			_notice_towers(delta)
			_target = _pick_target()
			if _begin_behaviour():
				return
			_throw_cooldown = maxf(_throw_cooldown - delta, 0.0)
			if _target != null and _in_reach(_target):
				_enter(State.WINDUP, Balance.ENEMY_ATTACK_WINDUP)
				# Coil before the blow: the tell the player reads.
				animator.squash(Balance.ANIM_HURT_SQUASH * 0.8)
				if _breakout_armed:
					_break_out()
			elif _may_throw_on_the_way_in():
				# **The same wind-up, so the tell is the tell.** A throw that
				# had its own silent animation would be a blow from nowhere,
				# which is the one thing every telegraph rule here refuses. It
				# is held a little longer than a swing because it arrives from
				# further away and the player has further to step.
				# **Spent when it leaves the hand, not when the arm goes
				# back.** An attempt broken by a blow costs nothing, which is
				# what stops a body that keeps being interrupted from simply
				# never throwing.
				_throwing = true
				_enter(State.WINDUP, Balance.ENEMY_ATTACK_WINDUP
					* Balance.ENEMY_THROW_WINDUP_SCALE)
				animator.squash(Balance.ANIM_HURT_SQUASH * 0.8)
				_walk(delta)
			else:
				_walk(delta)
		State.WINDUP:
			_state_left -= delta
			if _state_left <= 0.0:
				_strike()
				EventBus.enemy_attacked.emit(get_instance_id(), combat_origin(),
					attack_reach())
				_enter(State.STRIKE, Balance.ENEMY_ATTACK_STRIKE)
				var toward: Vector2 = Vector2.RIGHT
				if _target != null and is_instance_valid(_target):
					toward = (_target.global_position - global_position).normalized()
				animator.punch(toward, 1.1)
		State.STRIKE:
			_state_left -= delta
			if _state_left <= 0.0:
				# Recovery carries the breed's own cadence. `contact_interval`
				# is a floor under the *whole* cycle, so what is spent here is
				# whatever the wind-up and the blow did not already cover - at
				# the derived default that is exactly `ENEMY_ATTACK_RECOVERY`,
				# so a breed that authors nothing swings as it always did.
				# **And never on the instant it is ready**: each recovery wanders
				# by the body's own dice, so a crowd does not fire in lockstep and
				# a shooter does not spam the moment its arm comes back.
				_enter(State.RECOVER, maxf(Balance.ENEMY_ATTACK_RECOVERY,
					data.contact_interval - Balance.ENEMY_ATTACK_WINDUP
						- Balance.ENEMY_ATTACK_STRIKE)
					* _temper.randf_range(Balance.ENEMY_CADENCE_WANDER.x,
						Balance.ENEMY_CADENCE_WANDER.y))
				if _field != null and _target == _field.town_node() \
						and data.role == EnemyData.Role.HOWLER:
					_siege_share = maxf(_siege_share - _temper.randf_range(
						Balance.ENEMY_SIEGE_STEP.x, Balance.ENEMY_SIEGE_STEP.y),
						Balance.ENEMY_SIEGE_FLOOR)
		State.RECOVER:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter(State.WALKING, 0.0)
		State.BRACE:
			# The tell. It cannot be cancelled by the breed - only interrupted,
			# and only where the behaviour says a blow interrupts it.
			_state_left -= delta
			if _state_left <= 0.0:
				_commit_behaviour()
		State.COMMIT:
			_state_left -= delta
			_hold_behaviour(delta)
			# **And the shove is actually applied.** `_slip` is spent in
			# `_advance`, which is reached from `_walk`, `_walk_camp` and `_rout`
			# and from nowhere else - so a body in COMMIT was never moved by it,
			# and a pounce crossed **nothing** from the day it was authored. An
			# anchor zeroes its own slip in `_hold_behaviour` and stays rooted,
			# which is the same line saying the opposite thing.
			_step(_slip, delta)
			if _state_left <= 0.0:
				_end_behaviour()
		State.ROUTED:
			_rout_left -= delta
			if _rout_left <= 0.0:
				# **It comes back.** A body that fled the field would be a free
				# kill the wave never had to pay for, and the pressure curve is
				# tuned against how many arrive. Nerve returns part-way rather
				# than whole, so a second shock breaks it again sooner.
				_morale = Balance.ENEMY_MORALE_RALLIED
				_enter(State.WALKING, 0.0)
			else:
				_rout(delta)
		_:
			pass


# --- What this breed does that you remember it for (2026-09-15) ---------------
#
# One committed action with three parts - a tell, a commitment that cannot be
# taken back, and a recovery that is the opening - authored per breed on
# `EnemyData.behaviour` rather than branched on by name (working rule 3).
#
# **The bound: a behaviour changes the shape of a fight and never its size.**
# Nothing here multiplies `contact_damage`. An anchor buys time and pays for it
# in forward progress and attacks not made; a ward turns one blow per ally and
# is spent; a release deals what was banked and no more; a pounce covers ground
# it would have walked anyway. `curve_report` reads the same waves, and
# `enemy_behaviour_check` measures each of those sentences.


## Whether this breed is about to do its own thing, and the setting up of it.
func _begin_behaviour() -> bool:
	if data == null or data.behaviour == EnemyData.Behaviour.NONE or puppet:
		return false
	if _behaviour_wait > 0.0:
		return false
	if not _behaviour_wants_to():
		return false
	_behaviour_aim = _behaviour_heading()
	_enter(State.BRACE, _behaviour_warning())
	# The tell. Every one of these is a *pose* rather than a particle, because
	# the thing a player has to read in a crowd is the silhouette.
	match data.behaviour:
		EnemyData.Behaviour.ANCHOR:
			animator.squash(Balance.ANIM_HURT_SQUASH * 1.3)
		EnemyData.Behaviour.POUNCE:
			animator.squash(Balance.ANIM_HURT_SQUASH * 1.6)
		_:
			animator.squash(Balance.ANIM_HURT_SQUASH)
	# **A boss's own beat weighs on the frame; anything else's does not.**
	#
	# `Priority.BOSS` was authored with a load of 0.45 and a floor of 0.68 and was
	# named by nothing outside the gate - so the loudest fight in the game added
	# nothing at all to the clutter the director measures, and cosmetic effects
	# ran at full strength through exactly the moment that most needed reading.
	#
	# The tell itself is a telegraph and is never damped; what is noted here is
	# that a boss is *doing something*, which is what the rest of the screen
	# should give way to.
	if data != null and data.category == EnemyData.Category.BOSS:
		JuiceDirector.note(JuiceDirector.Priority.BOSS)
	speak()
	JuiceDirector.note(JuiceDirector.Priority.TELEGRAPH)
	Vfx.ring(global_position, _behaviour_reach() * Balance.ENEMY_BEHAVIOUR_TELL_SHARE,
		_behaviour_colour(), _behaviour_warning(), 3.0)
	return true


## Whether the moment is right. Each behaviour answers for itself, and each
## answer is about what is in front of it rather than about a clock alone.
func _behaviour_wants_to() -> bool:
	match data.behaviour:
		EnemyData.Behaviour.ANCHOR:
			# Something worth sheltering from in front, and somebody behind to
			# shelter. A shield with nobody behind it is a slower marcher.
			return _target != null and is_instance_valid(_target) \
				and _allies_within(_behaviour_reach()) > 0
		EnemyData.Behaviour.POUNCE:
			if _target == null or not is_instance_valid(_target):
				return false
			var gap: float = global_position.distance_to(_target.global_position)
			# Out of reach but inside the leap: the whole point of a pounce is
			# the ground it crosses.
			return gap > attack_reach() and gap <= _behaviour_reach()
		EnemyData.Behaviour.WARD:
			return _allies_within(_behaviour_reach()) > 0
		EnemyData.Behaviour.STORE:
			return _behaviour_bank >= 1.0
	return false


## Which way it is committed. Taken once, at the tell, and never updated - that
## is what "committed" means and it is the whole of the counterplay.
func _behaviour_heading() -> Vector2:
	if _target != null and is_instance_valid(_target):
		var toward: Vector2 = _target.global_position - global_position
		if toward.length() > 0.01:
			return toward.normalized()
	return _facing_heading()


func _facing_heading() -> Vector2:
	return Vector2.LEFT if sprite != null and sprite.flip_h else Vector2.RIGHT


func _behaviour_warning() -> float:
	return data.behaviour_warning if data.behaviour_warning > 0.0 \
		else Balance.ENEMY_BEHAVIOUR_WARNING


func _behaviour_reach() -> float:
	return data.behaviour_reach if data.behaviour_reach > 0.0 \
		else Balance.ENEMY_BEHAVIOUR_REACH


func _behaviour_colour() -> Color:
	match data.behaviour:
		EnemyData.Behaviour.ANCHOR:
			return Color(0.62, 0.76, 0.45, 0.7)
		EnemyData.Behaviour.POUNCE:
			return Color(0.9, 0.62, 0.3, 0.75)
		EnemyData.Behaviour.WARD:
			return Color(0.95, 0.88, 0.55, 0.75)
	return Color(0.66, 0.78, 1.0, 0.8)


## The commitment lands.
func _commit_behaviour() -> void:
	_enter(State.COMMIT, maxf(data.behaviour_seconds,
		Balance.ENEMY_BEHAVIOUR_SECONDS))
	match data.behaviour:
		EnemyData.Behaviour.POUNCE:
			# A leap is a shove along the marked line, through the same slip the
			# knockback uses, so nothing downstream learns a pounce exists.
			_slip = _behaviour_aim * _leap_speed()
			animator.punch(_behaviour_aim, 1.5)
		EnemyData.Behaviour.WARD:
			# One turned blow each, to a bounded number of allies, and it does
			# not stack: a second bell over the same body refreshes rather than
			# adds. That is the review's own rule and it is what stops two
			# priests from making a wave unkillable.
			var given: int = 0
			for other: Enemy in _allies_in(_behaviour_reach()):
				if given >= Balance.ENEMY_WARD_MAX_ALLIES:
					break
				other.grant_guard(maxf(data.behaviour_seconds,
					Balance.ENEMY_BEHAVIOUR_SECONDS))
				given += 1
			Vfx.ring(global_position, _behaviour_reach(), _behaviour_colour(), 0.4, 5.0)
		EnemyData.Behaviour.STORE:
			# What was banked, given back along the line it was told to. Through
			# the ground strike every other telegraphed blow uses, so it hits
			# what a ground blow hits and nothing new learns about it.
			_release_bank()
		_:
			pass


## Held for as long as the commitment lasts.
func _hold_behaviour(delta: float) -> void:
	match data.behaviour:
		EnemyData.Behaviour.ANCHOR:
			# Rooted: it does not advance and it does not swing. That is what it
			# is paying, and it is why the guard is not a free damage reduction.
			_slip = Vector2.ZERO
		EnemyData.Behaviour.POUNCE:
			# Down to nothing exactly as the leap ends, which is what makes the
			# ground it covers equal to the reach it was authored with. A flat
			# 240 a second had no relationship to either: from 789 it wanted 3.3
			# seconds against a commitment of 2.4, so it could not reach zero even
			# when it was left alone to try.
			_slip = _slip.move_toward(Vector2.ZERO, delta * _leap_decay())


## The leap's own numbers.
##
## A body shoved at `_leap_speed` and slowed at `_leap_decay` covers exactly
## `_behaviour_reach()` and arrives at exactly nothing, over the seconds the
## breed authored. Stated as a ramp rather than a flat speed because a shove
## that stopped dead would read as a teleport, and one that never stopped is
## what was carrying bodies off the map.
func _leap_seconds() -> float:
	return maxf(data.behaviour_seconds, 0.2)


func _leap_speed() -> float:
	return 2.0 * _behaviour_reach() / _leap_seconds()


func _leap_decay() -> float:
	return _leap_speed() / _leap_seconds()


func _end_behaviour() -> void:
	_behaviour_wait = maxf(data.behaviour_interval, Balance.ENEMY_BEHAVIOUR_INTERVAL)
	_behaviour_bank = 0.0
	# **The recovery is the opening.** It cannot act, it cannot move, and it is
	# the only window some of these breeds ever give.
	_enter(State.RECOVER, maxf(data.behaviour_recovery,
		Balance.ENEMY_BEHAVIOUR_RECOVERY))


## Somebody standing behind this body, close enough to shelter or to hear a bell.
## The strongest aura of a kind reaching this body from an ally standing near it.
##
## **The best rather than the sum**, which is the rule `_affix_best` already
## follows one layer down: two marks multiplying would approach immunity, and a
## body nothing can hurt is not a mark, it is a wall.
func _ally_aura(field_name: StringName) -> float:
	if _state == State.DYING or _field == null:
		return 0.0
	var best: float = 0.0
	for other: Enemy in _allies_in(Balance.ENEMY_AURA_REACH):
		if other == null or other.is_dying() or other.affixes.is_empty():
			continue
		for affix: EnemyAffixData in other.affixes:
			if affix.aura_radius <= 0.0:
				continue
			if global_position.distance_to(other.global_position) > affix.aura_radius:
				continue
			best = maxf(best, float(affix.get(field_name)))
	return best


## **Whether this body is standing by a lit camp fire.** Set by `Camps` when
## a camp stands up and whenever its fire goes out or comes back, and by
## nothing else: a body that asks the weather itself would be a second opinion
## about a fact the camp already owns.
##
## Read in exactly the two places an ally's aura is read, and taken as the
## *better* of the two rather than added - see `Balance.CAMP_FIRE_WARMTH_SPEED`.
var camp_warmth: bool = false


## How much faster this body moves for the company it keeps, or for the fire
## it is standing by. Read by the walk.
func aura_haste() -> float:
	var warmth: float = Balance.CAMP_FIRE_WARMTH_SPEED if camp_warmth else 0.0
	return clampf(maxf(_ally_aura(&"aura_speed"), warmth), 0.0, 0.6)


func _allies_in(within: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	if _field == null:
		return out
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other == null or other == self or not is_instance_valid(other):
			continue
		if other.puppet or other._state == State.DYING:
			continue
		if other.global_position.distance_to(global_position) <= within:
			out.append(other)
	return out


func _allies_within(within: float) -> int:
	return _allies_in(within).size()


## The planted shield standing between this body and a blow, if there is one.
##
## **Never itself**, and never another shield's shield: a chain of redirections
## would be a wall nothing could reach, and one hop is what makes the flank the
## answer. The test is geometric - the shield has to be on the side the blow
## came from and roughly on its line - so a Rootshield covers the bodies it is
## actually in front of and nothing else.
func _anchor_covering(from: Vector2) -> Enemy:
	if data == null or _state == State.DYING or puppet:
		return null
	if data.behaviour == EnemyData.Behaviour.ANCHOR:
		return null
	var incoming: Vector2 = global_position - from
	if incoming.length() < 0.01:
		return null
	var heading: Vector2 = incoming.normalized()
	for other: Enemy in _allies_in(Balance.ENEMY_ANCHOR_COVER):
		if other.data == null or other.data.behaviour != EnemyData.Behaviour.ANCHOR:
			continue
		if not other.is_anchored():
			continue
		var toward: Vector2 = other.global_position - global_position
		# In front of this body with respect to the blow, and near its line.
		if toward.dot(heading) > 0.0:
			continue
		var along: float = absf(toward.dot(heading))
		var across: float = (toward + heading * along).length()
		if across <= Balance.ENEMY_ANCHOR_HALF_WIDTH:
			return other
	return null


## Whether this body is planted behind its own shield right now.
func is_anchored() -> bool:
	return _state == State.COMMIT and data != null \
		and data.behaviour == EnemyData.Behaviour.ANCHOR


## A turned blow. One, and it is spent on the next thing that lands.
func grant_guard(seconds: float) -> void:
	_guard_left = maxf(_guard_left, seconds)


## Whether a guard stands, for the gate and for the shield's own drawing.
func guarded() -> bool:
	return _guard_left > 0.0


## Bank a share of a blow, up to the ceiling. Used by `STORE`.
func _bank_blow(amount: float) -> void:
	if data == null or data.behaviour != EnemyData.Behaviour.STORE:
		return
	if health == null or health.max_hp <= 0.0:
		return
	_behaviour_bank = minf(_behaviour_bank
		+ amount / health.max_hp / maxf(Balance.ENEMY_STORE_SHARE, 0.001), 1.0)


## Give the bank back as one telegraphed strike along the committed line.
##
## **A release rather than a reflection**, which is the review's own point: a
## reflection punishes shooting and a tower shoots on its own, so the player has
## no agency in it at all. A line you can step off is a decision.
func _release_bank() -> void:
	if _field == null:
		return
	var blow := EnemyGroundStrike.new()
	blow.shape = EnemyGroundStrike.Shape.LINE
	# What was banked and no more: a share of this body's own contact damage,
	# scaled by how full the bank was when it opened. A release that dealt a
	# number of its own would be the third power scale this project refuses.
	blow.damage = data.contact_damage * maxf(data.behaviour_power, 0.5) \
		* clampf(_behaviour_bank, 0.0, 1.0)
	blow.delay = _behaviour_warning()
	blow.reach = _behaviour_reach()
	blow.half_width = Balance.ENEMY_STORE_HALF_WIDTH
	blow.tint = _behaviour_colour()
	# Ground to ground, along the line it committed to at the tell.
	blow.aim = _behaviour_aim
	blow.blamed_on = promoted_name()
	blow.global_position = global_position
	# **A dragon breathes it** (owner, 2026-09-22): its own element most of the
	# time and plain fire now and then, the fire wyrm now and then its plasma
	# ultra - drawn by `DragonBreath`. What the dice move is the line's shape:
	# its width, its reach and a small turn. The damage above is the bank's own
	# whatever is breathed, so no element and no ultra is a harder blow.
	if not data.breath_element.is_empty():
		var chosen: Dictionary = DragonBreath.choose(data, RunState.rng("combat"))
		blow.breath = String(chosen["element"])
		blow.ultra = bool(chosen["ultra"])
		blow.half_width *= float(chosen["width"])
		blow.reach *= float(chosen["reach"])
		blow.aim = _behaviour_aim.rotated(float(chosen["turn"]))
		if blow.ultra:
			blow.delay *= Balance.DRAGON_ULTRA_WARNING
		blow.mouth = combat_origin() + blow.aim * data.body_radius * 0.8
	_field.add_child(blow)


func _enter(state: State, duration: float) -> void:
	# **An interrupted throw is dropped rather than banked.** A wind-up that
	# ends in anything but the blow it was coiling for - a hit that stuns, a
	# rout, a death, a behaviour taking over - must not leave `_throwing`
	# standing, or the *next* wind-up looses a javelin instead of landing the
	# sword it was coiling for. Found by probe: the beast's own footfall stuns a
	# body often enough that a rider was reliably interrupted mid-throw.
	if state != State.WINDUP:
		_throwing = false
	# An armoured swing lasts exactly as long as the swing.
	if state != State.WINDUP and state != State.STRIKE:
		_breaking_out = false
	# **A commitment's shove does not outlive it.** The leap is written into
	# `_slip`, which is the field the *snow* also uses - and the snow's copy
	# carries `_slip_left`, so `_tick_slip` clears it. A pounce's carries no
	# timer and nothing else in this file zeroes it, so leaving COMMIT by any
	# door - a rout, a death, a behaviour taken over - left the whole leap
	# velocity on the body for the rest of its life. Measured 2026-09-22 across
	# all eighteen breeds that pounce: 709 to 821 units a second of drift
	# against authored walks of 76 to 96, which is a body carried off the road
	# and never seen again. "Some seem to go off elsewhere."
	#
	# Here rather than in `_end_behaviour`, for the same reason the throw above
	# is dropped here: this is the one funnel every state change goes through,
	# and the interrupted exits are the ones that were wrong.
	if _state == State.COMMIT and state != State.COMMIT:
		_slip = Vector2.ZERO
		_slip_left = 0.0
	_state = state
	_state_left = duration


## Walks the lane's road toward the town, holding a fixed lateral offset so a
## wave arrives as a column rather than in single file.
##
## The road bends now (GDD §13), so this follows waypoints instead of aiming at
## the town. Aiming straight at the town across a U-bend would send the whole
## formation over the open ground the player is meant to be building on, which
## is the entire point of the bend.
func _walk(delta: float) -> void:
	if is_camp_mob():
		_walk_camp(delta)
		return
	var destination: Vector2 = _target.global_position if _target != null else _field.objective_position(global_position)
	var to: Vector2 = destination - global_position
	if to.length() <= 1.0:
		return
	var direction: Vector2 = to.normalized()
	# **The road is not optional.** One that had noticed the hero used to walk
	# straight at them, which pulled whole columns off the bends the map is built
	# around - the player stood on open ground and the formation followed,
	# undoing the reason the road turns at all.
	#
	# The road is held whatever it is looking at. Targeting still decides what it
	# *swings* at, so a hero who comes within reach is fought; a hero who stays
	# off the road is simply not reached, which is the trade a player standing
	# clear of a column should be making.
	#
	# An animal biting it is the one exception: `_biting_back` only returns one
	# already inside reach, so answering it costs no ground.
	if _provoker == null or _target != _provoker:
		direction = _road_direction()

	_advance(direction, delta)


## A camp body's step: at its quarry, home when it has strayed, or about its
## ground when nothing is happening.
func _walk_camp(delta: float) -> void:
	var from_home: float = global_position.distance_to(camp_home)
	if _target != null and is_instance_valid(_target) and not _camp_returning:
		_camp_calm = 0.0
		if from_home > camp_leash:
			# Followed as far as it will. Home, and healing on the way.
			_camp_returning = true
			_target = null
		else:
			var to: Vector2 = _target.global_position - global_position
			if to.length() > 1.0:
				_advance(to.normalized(), delta)
			return
	if _camp_returning:
		if from_home <= Balance.CAMP_PATROL_RADIUS * 0.5:
			_camp_returning = false
			_camp_goal = global_position
			_camp_pause = 0.4
			# Home: a reset camp is a reset camp. Whole again, the League way.
			if health != null:
				health.heal(health.max_hp)
			_camp_calm = Balance.CAMP_IDLE_HEAL_DELAY
			return
		_advance((camp_home - global_position).normalized(), delta)
		return
	# Left alone at home long enough, a camp body mends. Owner brief,
	# 2026-09-12: back to full after being unprovoked and idle a while.
	_camp_calm += delta
	if _camp_calm >= Balance.CAMP_IDLE_HEAL_DELAY and health != null \
			and health.current_hp < health.max_hp:
		health.heal(health.max_hp * Balance.CAMP_IDLE_REGEN * delta)
	# Patrol: a slow potter between points on its own ground.
	_camp_pause -= delta
	var to_goal: Vector2 = _camp_goal - global_position
	if to_goal.length() <= 6.0 or _camp_goal == Vector2.INF:
		if _camp_pause > 0.0:
			return
		var turn: RandomNumberGenerator = RunState.rng("camps")
		_camp_goal = camp_home + Vector2.RIGHT.rotated(turn.randf() * TAU) \
			* turn.randf_range(Balance.CAMP_PATROL_RADIUS * 0.3, Balance.CAMP_PATROL_RADIUS)
		_camp_pause = turn.randf_range(Balance.CAMP_PATROL_PAUSE.x, Balance.CAMP_PATROL_PAUSE.y)
		return
	# Half pace on patrol: a camp that paced at charging speed reads as agitated
	# rather than as at home.
	_tick_slip(delta, to_goal.normalized())
	var step: Vector2 = to_goal.normalized() * current_speed() * 0.5 * delta \
		* RunState.wind_push(to_goal)
	if step.length() > to_goal.length():
		step = to_goal
	# Held inside the field, like every other step. A camp lord is the
	# largest thing on the outskirts and it patrols out here rather than
	# walking a road, so it is the body most likely to be pushed over the
	# edge and the one a player most wants to be able to find.
	var wanted: Vector2 = _field.hold_inside(global_position + step)
	if _field.step_is_legal(global_position, wanted):
		global_position = wanted


## One step in a direction, sliding off whatever it cannot walk through.
##
## Shared by the advance and the rout. Extracted when routing was added, because
## a retreat that did not honour the cliffs would walk bodies through the island
## faces the ramps exist to funnel them around - and a second copy of this is
## exactly the copy that would not be fixed the next time the first one was.
## One step along a heading.
##
## The wind is applied here rather than in `current_speed` for the reason the
## hero applies it at `velocity`: a push depends on which way you are walking,
## and `current_speed` does not know. `targeting_speed` deliberately does not
## read it either - a tower ranking runners wants the body's own pace, not the
## weather's opinion of it, and paying for a dot product inside a sort
## comparator is the mistake that comment already warns about.
func _advance(direction: Vector2, delta: float) -> void:
	_tick_slip(delta, direction)
	_step(direction * current_speed() * RunState.wind_push(direction) + _slip, delta)


## One step at a velocity, sliding off whatever it cannot walk through.
##
## Split out of `_advance` when the pounce was found to cross no ground: a
## commitment has to move the body without also paying it its walking speed, and
## a second copy of the cliff slide is the copy that would not be fixed the next
## time the first one was.
func _step(velocity: Vector2, delta: float) -> void:
	var step: Vector2 = velocity * delta
	if step.length() <= 0.0001:
		return
	# **Held inside the field's own edge.** Nothing bounded a body before this:
	# `Battlefield.step_is_legal` refuses only the city and the base
	# `EnemyField.step_is_legal` returns true outright, so a hard enough shove -
	# a pounce, a funnel, a knockback - walked a body off the map, where it could
	# never arrive and never die while the wave waited on it.
	var wanted: Vector2 = _field.hold_inside(global_position + step)
	if _field.step_is_legal(global_position, wanted):
		global_position = wanted
		return

	# Blocked by a cliff. Slide along it rather than stopping dead: an enemy that
	# freezes at the foot of an island reads as broken, while one that runs along
	# the face looking for the ramp reads as a siege - which is the behaviour the
	# ramp exists to produce.
	for sideways: Vector2 in [Vector2(step.y, -step.x), Vector2(-step.y, step.x)]:
		var slide: Vector2 = _field.hold_inside(global_position + sideways)
		if _field.step_is_legal(global_position, slide):
			global_position = slide
			return


## Running, away from the town rather than merely away from the hero.
##
## **Never toward the wall.** "Away from whatever frightened me" would send a
## body that broke on the town side straight at the gate, which would make
## breaking an enemy's nerve a way of *helping* it arrive - the exact opposite of
## what the player just earned. Retreat is back up the road, always.
func _rout(delta: float) -> void:
	if _field == null:
		return
	_advance(-_road_direction(), delta)


## Nerve, and what shakes it.
##
## Called on the bodies near something that just died badly. Elites, champions
## and bosses are excluded by the caller rather than here, so this stays a plain
## number and the rule about who can break lives in one place.
func shake_morale(amount: float) -> void:
	if amount <= 0.0 or _state == State.DYING or puppet:
		return
	if rank != Rank.COMMON:
		return
	# A living champion nearby holds the line. This is the rally half of the
	# system and it is why killing the leader *first* is the readable play: with
	# one still standing, breaking the bodies around it does nothing.
	if _rallied():
		return
	_morale = maxf(_morale - amount, 0.0)
	if _morale > 0.0 or _state == State.ROUTED:
		return
	_rout_left = Balance.ENEMY_ROUT_SECONDS
	_enter(State.ROUTED, 0.0)
	# Said out loud, because a body that turns and runs is the whole point and a
	# player looking at the other side of the field would otherwise miss it.
	Vfx.spark(_visual_origin(), Balance.ENEMY_ROUT_COLOUR, 9, Vector2.UP, 150.0)


## Whether something is holding this body's nerve together.
func _rallied() -> bool:
	if _field == null or not _field.has_method("enemies_near"):
		return false
	for other: Enemy in _field.enemies_near(global_position, Balance.ENEMY_RALLY_RADIUS):
		if other == self or other.is_dying():
			continue
		if other.rank != Rank.COMMON:
			return true
	return false


## True while this body is running rather than fighting. For the interface and
## for anything that wants to know the line is breaking.
func is_routed() -> bool:
	return _state == State.ROUTED


## Losing your footing on snow.
##
## Rolled per step against how much snow is *actually lying* - a dusting barely
## does it and a covered field does it often - so the effect appears with the
## weather rather than being a property of the act. Read from `RunState`, which
## is where the run's snow depth lives; an enemy caching its own copy would keep
## slipping through a thaw.
##
## Rolled from the combat stream, so a seeded replay slips in the same places.
## Anything else would make a reproducible run stop being reproducible the moment
## it snowed.
##
## Puppets never slip: on a guest they are a picture of an enemy whose footing
## was decided on the host, and rolling locally would have the two machines
## disagree about where it ended up.
func _tick_slip(delta: float, heading: Vector2) -> void:
	if _slip_left > 0.0:
		_slip_left -= delta
		if _slip_left <= 0.0:
			_slip = Vector2.ZERO
		return
	if puppet or RunState.snow_cover <= 0.01:
		return
	var chance: float = Balance.SNOW_SLIP_CHANCE * RunState.snow_cover * delta * 10.0
	if RunState.rng("combat").randf() > chance:
		return
	# Sideways, either way, off the direction of travel.
	var side: Vector2 = heading.orthogonal().normalized()
	if RunState.rng("combat").randf() < 0.5:
		side = -side
	_slip = side * (Balance.SNOW_SLIP_DISTANCE / maxf(Balance.SNOW_SLIP_SECONDS, 0.01))
	_slip_left = Balance.SNOW_SLIP_SECONDS
	# The lean sells it. Without this an enemy slides flat and reads as being
	# dragged rather than as having lost its footing.
	if animator != null:
		animator.punch(side, 0.55)


## Direction to the next waypoint, offset sideways into this enemy's column lane.
##
## The offset is applied perpendicular to the *current segment* rather than to
## the lane's overall heading, so a column keeps its shape around a corner
## instead of fanning out and cutting it.
func _road_direction() -> Vector2:
	var path: PackedVector2Array = _route
	if path.size() < 2:
		return (_field.objective_position(global_position) - global_position).normalized()

	# Advance by *projection along the segment*, not by distance to the waypoint.
	#
	# The radius test this replaces could be missed entirely: an enemy holds a
	# lateral offset of up to half a lane width, so it approaches a line that
	# passes the corner to one side and may never come within any fixed radius of
	# it. The formation then walked to the first bend and stopped there.
	#
	# Asking "am I past the end of this leg" cannot be missed, however wide the
	# column runs or however hard something was knocked sideways.
	#
	# **Re-anchored first when something has thrown it clear of the road.** The
	# advance below only ever moves forward, so a body knocked hard - a finisher,
	# a Tremor, a boss shove - kept aiming at the waypoint it had been walking
	# to, which after a big displacement can be behind it or across a bend. It
	# walked diagonally back over ground the road does not cover. Finding the
	# nearest point on the route instead is both shorter and correct: it is the
	# same decision a person makes when they are knocked off a path.
	_reanchor_if_thrown(path)

	while _path_index < path.size() - 1:
		var from: Vector2 = path[_path_index]
		var segment: Vector2 = path[_path_index + 1] - from
		var length_squared: float = segment.length_squared()
		if length_squared <= 0.01:
			_path_index += 1
			continue
		if (global_position - from).dot(segment) / length_squared >= 1.0:
			_path_index += 1
		else:
			break

	if _path_index >= path.size() - 1:
		return (_field.objective_position(global_position) - global_position).normalized()

	var leg: Vector2 = path[_path_index + 1] - path[_path_index]
	var aim: Vector2 = path[_path_index + 1] + leg.normalized().orthogonal() * _lane_offset
	var toward: Vector2 = aim - global_position
	return toward.normalized() if toward.length() > 1.0 else leg.normalized()


## Snaps the route cursor to whichever leg this body is actually nearest.
##
## Only when it is properly off the road: a formation holds a lateral offset of
## up to half a lane width by design, and re-anchoring on that would fight the
## column's own shape every frame. The threshold is what separates "walking wide
## around a corner" from "thrown into the trees".
func _reanchor_if_thrown(path: PackedVector2Array) -> void:
	if path.size() < 2:
		return
	# **Measured against the leg being followed, not the nearest one.** Gating on
	# the nearest leg is the same mistake in a different shape: a body standing
	# exactly on the first leg while its cursor still says the eighth is as lost
	# as a body can be, and its distance to the nearest leg is zero. What decides
	# whether it is thrown is how far it is from the road it thinks it is on.
	_path_index = reanchor_index(path, global_position, _path_index)


## Which leg a body at `at` should be following, given the one it thinks it is on.
##
## **Static, and free of the node.** Deciding where a thrown body rejoins the
## road is arithmetic over a polyline; testing it was costing a whole `Run` -
## a battlefield, a director, a hero - built and torn down to ask one question,
## which leaked twelve objects on the CI runner and none here. The rule is the
## part worth checking and it needs none of that.
static func reanchor_index(path: PackedVector2Array, at: Vector2, following: int) -> int:
	if path.size() < 2:
		return following
	var current: int = clampi(following, 0, path.size() - 2)
	# Measured against the leg being followed, not the nearest one. Gating on the
	# nearest is the same mistake in a different shape: a body standing exactly
	# on the first leg while its cursor still says the eighth is as lost as a
	# body can be, and its distance to the nearest leg is zero.
	if distance_to_leg(at, path[current], path[current + 1]) 			< Balance.ENEMY_REANCHOR_DISTANCE:
		return current

	var nearest: int = current
	var nearest_distance: float = INF
	for index: int in path.size() - 1:
		var distance: float = distance_to_leg(at, path[index], path[index + 1])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = index
	return nearest


## Distance from a point to one leg of a route.
static func distance_to_leg(at: Vector2, from: Vector2, to: Vector2) -> float:
	var segment: Vector2 = to - from
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.01:
		return at.distance_to(from)
	var along: float = clampf((at - from).dot(segment) / length_squared, 0.0, 1.0)
	return at.distance_to(from + segment * along)


func current_speed() -> float:
	var speed: float = targeting_speed()
	if data.role != EnemyData.Role.HOWLER:
		var howler: Enemy = _nearby_howler()
		if howler != null:
			speed *= 1.0 + howler.data.aura_strength
	return speed


## Cheap speed read for tower target sorting. The full movement calculation
## searches for a nearby Howler; calling that inside a sort comparator turns a
## 180-enemy formation into thousands of group scans per tower volley. Global,
## status and boss-phase speed are enough to rank runners correctly.
func targeting_speed() -> float:
	var speed: float = data.move_speed * _speed_scale * _slow_factor * RunState.flood_slow()
	if _boss_phase > 0:
		speed *= 1.0 + data.phase_speed_bonus * float(_boss_phase)
	if RunState.horn_active:
		speed *= Balance.HORN_ENEMY_SPEED_SCALE
	return speed


## Taunting towers pull first, then the hero if they have come close enough to
## be worth stopping for, then the town.
## Remembers whatever just bit this enemy out of the long grass.
##
## Called by `Wildlife._strike`. Public because the wilderness is a third party:
## it attacks enemies as readily as it attacks players, and an enemy that could
## not answer would make a wolf pack a free demolition tool.
func provoked_by(animal: Node2D, source: Node) -> void:
	if _state == State.DYING or puppet:
		return
	_provoker = animal
	_provoker_source = source
	_provoked_left = Balance.ENEMY_PROVOKED_SECONDS


## The animal worth hitting back, or null.
##
## **Only while it is already in reach**, and that is the whole design. Returning
## it from `_pick_target` makes the enemy stop and swing, and `_walk` steers at
## whatever the target is - so an animal chosen at a distance would pull the
## column off the road, which is the one thing a lane enemy must never do. In
## reach means standing on top of it, and the step it takes to close is nothing.
func _biting_back() -> Node2D:
	if _provoked_left <= 0.0 or _provoker == null 			or not is_instance_valid(_provoker):
		return null
	if not _in_reach(_provoker):
		return null
	return _provoker


func _pick_target() -> Node2D:
	var chosen: Node2D = _choose_target()
	# **A body at the gate hits the gate, whatever it was walking at.**
	#
	# Traced on the owner's own banked front, 2026-09-21: the Dune Burrowers
	# walked the road to the wall carrying the tower in their lane as their
	# target - the road is not optional, so they never left it to reach the
	# tower - and stood there for three minutes in WALKING, thirty-one units
	# from the base, being walked in and deflected out on every frame. That is
	# the "stood against the base, nothing swinging" the owner photographed on
	# v0.47.1. The hero branch has held this rule since 2026-09-12 ("a hero
	# merely *near* used to take the target from a wall already in reach");
	# the tower, grudge and taunt branches never did, and a siege breed is the
	# one that arrives with a target it cannot reach.
	#
	# Applied once, here, rather than in each branch, so the next branch added
	# to `_choose_target` cannot forget it. It does not touch a camp body,
	# which never marches on the town, and it never *takes* a target away
	# from something in reach - it only ever answers the town for a body that
	# is in reach of the town and of nothing it was aiming at.
	if chosen == null or is_camp_mob() or _field == null:
		return chosen
	var town: Node2D = _field.town_node()
	if town == null or chosen == town or not is_instance_valid(chosen):
		return chosen
	if _in_reach(chosen) or not _in_reach(town):
		return chosen
	return town


func _choose_target() -> Node2D:
	var animal: Node2D = _biting_back()
	if animal != null:
		return animal
	if is_camp_mob():
		return _camp_target()
	# A tower this body holds a grudge against, while it does and while the
	# tower stands (owner brief, 2026-09-14).
	if _grudge != null and is_instance_valid(_grudge) and _grudge_left > 0.0 \
			and (_grudge as Tower).is_vulnerable():
		return _grudge
	var taunt: Node2D = _field.taunting_tower_in_lane(lane)
	if taunt != null and is_instance_valid(taunt) and _taunted_by(taunt):
		return taunt
	if data.targets_towers:
		var structure: Node2D = _field.vulnerable_tower_in_lane(lane, global_position)
		if structure != null and is_instance_valid(structure):
			return structure
	# The *nearest* hero, not this machine's own. Asking for the local one made
	# every enemy in a two-player game walk past the guest as though they were
	# not there - no aggro, no melee, no ranged fire, and therefore no damage.
	# The nearest foe: a hero or a companion, whichever is closer (owner brief,
	# 2026-09-12). A companion that stood in the line and was never chosen
	# was a free wall.
	var hero: Node2D = _field.nearest_foe(global_position) if _field.has_method("nearest_foe") \
		else _field.nearest_hero(global_position)
	var town: Node2D = _field.town_node()
	# A barricade is not chosen over the hero: a wall does not distract somebody
	# already in a fight. It is chosen over the *town*, because it is the thing
	# physically in the way of getting there.
	var wall: Node2D = _field.blocking_barricade_ahead(global_position,
		_road_direction())
	if hero != null and is_instance_valid(hero) and _foe_stands(hero):
		# With no town to march on — the raid arena — the hero is the only
		# objective there is, at any distance.
		if town == null:
			return hero
		if global_position.distance_to(hero.global_position) <= Balance.ENEMY_HERO_AGGRO_RANGE:
			# **A body at the gate hits the gate.** A hero merely *near* used to
			# take the target from a wall already in reach, so a besieger at the
			# town with the Warden dashing around it stood there swinging at
			# nothing - reported as "once the melee units reached the base they
			# still did not attack it". The hero is fought when it can be hit;
			# when it cannot and the wall can, the wall is.
			if _in_reach(hero) or not _in_reach(town):
				return hero
	if wall != null and is_instance_valid(wall):
		return wall
	return town


## What a camp body will fight: a living hero inside its aggro, and only
## while both it and the hero are inside its leash of home. Never the town,
## never a tower, never a wall - a camp that marched on the city would be a
## fifth lane nobody tuned.
##
## Once it is walking home it ignores everything until it arrives: a body
## that could be re-pulled a step from home would never get to heal, and the
## League rule this copies is that a reset camp is a reset camp.
func _camp_target() -> Node2D:
	if _camp_returning:
		return null
	var hero: Node2D = _field.nearest_foe(global_position) if _field.has_method("nearest_foe") \
		else _field.nearest_hero(global_position)
	if hero == null or not is_instance_valid(hero) or not _foe_stands(hero):
		return null
	var reach: float = Balance.CAMP_AGGRO
	if _target == hero:
		# Already on it: keep it to the leash rather than the aggro, so a
		# fight that started close does not end the moment the hero steps back.
		reach = camp_leash
	if global_position.distance_to(hero.global_position) > reach:
		return null
	if hero.global_position.distance_to(camp_home) > camp_leash:
		return null
	return hero


## Whether a foe - hero or companion - is still something to fight.
func _foe_stands(foe: Node2D) -> bool:
	if foe == null or not is_instance_valid(foe):
		return false
	if foe is Companion:
		return (foe as Companion).is_alive()
	# **This** hero, not any hero. Asking the field whether somebody is alive
	# kept a body walking at a hero who had gone into a raid: the node is
	# still there, still at its last position, hidden and stilled - so the
	# enemy stood in the open swinging at nothing. Reported 2026-09-13 as
	# "enemies get stuck targeting something invisible", and it is the same
	# fault `Hero.set_present` was written for, one layer further out.
	# **Inside the walls is out of the fight** (owner, 2026-09-17: *"players
	# are hidden to enemies and wildlife while within the city base"*). Asked
	# here rather than at the picker, because this is the funnel both the
	# choosing and the *keeping* of a target go through - a rule written only
	# at selection would let a body that was already chasing somebody follow
	# them in, which is the exact behaviour being removed.
	#
	# The body is not left with nothing to do: `_pick_target` falls through to
	# the town, which is what the owner asked for in the same breath - *"enemies
	# will attack the base instead"*.
	if _field != null and _field.inside_city(foe.global_position):
		return false
	var who := foe as Hero
	if who != null:
		return who.is_alive() and who.is_in_group(Hero.GROUP_ANY)
	return _field.hero_is_alive()


## How far this one can hit, and **exactly what its ring shows**.
##
## The ring used to be `aura_radius` while the shot travelled
## `ENEMY_RANGED_RANGE` plus the target's own radius - so a Howler drew a circle
## of 210 and reached the town from beyond 500. A telegraph that lies is worse
## than no telegraph: the player reads it, stands outside it, and dies anyway.
##
## One number now, drawn and obeyed. Where a ranged breed authored an aura, that
## aura *is* its reach - the circle was always what the player was reading.
func attack_reach() -> float:
	if data.role != EnemyData.Role.HOWLER:
		# A melee arm reaches from the body's surface, so the attacker's own
		# radius belongs in the reach exactly as the target's belongs in the
		# gap. Right for an arm, and wrong for a shot.
		return Balance.ENEMY_ATTACK_RANGE + contact_radius()
	# **A ranged breed reaches exactly as far as it is authored to, and not
	# one unit past it** (owner, 2026-09-22: ranged enemies should strike the
	# base "from their proper ranged attack distances, not beyond").
	#
	# It carried `+ contact_radius()` as well, which is the melee convention
	# applied to a projectile: a shot leaves the body and flies its own
	# range, so a shaman authored at 185 struck from 210. Small, and it
	# contradicted the paragraph above it - "one number now, drawn and
	# obeyed" - because the readout ring reads this function, so the circle
	# a player stands outside was 25 units wide of the resource's own number.
	var authored: float = data.aura_radius
	return authored if authored > 0.0 else Balance.ENEMY_RANGED_RANGE


## Whether the ring touches the target.
##
## Measured body-to-surface: from this one's centre - not its feet, which is
## where the node has sat since depth sorting moved it - to the nearest point of
## the target. A big target is in reach when the circle reaches its edge, which
## is what the circle looks like it means.
func _target_gap(target: Node2D) -> float:
	var battlefield := _field as Battlefield
	if battlefield != null and target == battlefield.town_node():
		var bounds: Rect2 = battlefield.city_bounds()
		var at: Vector2 = global_position
		var edge := Vector2(clampf(at.x, bounds.position.x, bounds.end.x),
			clampf(at.y, bounds.position.y, bounds.end.y))
		# **The distance to the sprite's edge, with nothing subtracted from it.**
		#
		# Owner, 2026-09-20: bodies attacked the city *"from too far away
		# including melee enemies"*. This took off `sprite_clearance`, which is
		# the whole *sprite's* diagonal half-extent - about 135 units on a 192px
		# body, because it measures to the corner of the painting, and a
		# painting includes a lifted head, a banner and a raised arm. None of
		# that is where the body stands.
		#
		# It was also counted twice: `attack_reach()` already adds this body's
		# own `contact_radius()`, exactly as the ordinary branch below leaves
		# the *target's* radius to the gap and the *attacker's* to the reach.
		# So a melee breed stood off the wall by its range, plus its radius,
		# plus a hundred and thirty-five units of picture.
		#
		# `edge` is already the nearest point on the city's own sprite, so the
		# distance to it is the whole answer.
		return maxf(at.distance_to(edge), 0.0)
	return combat_origin().distance_to(target.global_position) - _field.target_radius(target)


func _in_reach(target: Node2D) -> bool:
	var gap: float = _target_gap(target)
	return gap <= attack_reach() * _siege_reach_share(target)


## **A ranged body besieging the wall comes in closer than its longest shot**
## (owner, 2026-09-22: they attacked the city "from beyond their attack ranges
## and should be a bit closer and should not just stand at reach of attack and
## just fire ranged but should also kite closer towards the tower"). Each body
## fires from its own share of its reach and steps nearer after every shot, so
## a line of shamans closes on the gate rather than standing on one circle.
## Against a person it keeps its whole reach - that is the fight it is for.
func _siege_reach_share(target: Node2D) -> float:
	if data == null or data.role != EnemyData.Role.HOWLER or _field == null:
		return 1.0
	if target == null or target != _field.town_node():
		return 1.0
	return _siege_share


func _strike() -> void:
	if _throwing:
		_throwing = false
		_let_the_javelin_go()
		return
	if _target == null or not is_instance_valid(_target):
		return
	# Re-checked at the moment of the blow, slightly generously: stepping out
	# during the wind-up is supposed to work, but not by a single pixel.
	var gap: float = _target_gap(_target)
	if gap > attack_reach() * 1.15:
		return
	# An animal has no Health node - the wildlife system owns those numbers - so
	# the blow is handed back to whoever owns it rather than applied here.
	if _provoker_source != null and _target == _provoker:
		var bite: float = data.contact_damage * _damage_scale \
			* _enemy_damage_scale()
		if _provoker_source.call("wound_sprite", _target, bite):
			Vfx.spark(_target.global_position, Color("c4552e"), 6,
				(_target.global_position - global_position).normalized(), 190.0)
		return
	var target_health: Health = Health.of(_target)
	if target_health == null and not (_target is Companion):
		return
	# Rolled, like a tower's shot. A blow that lands for the same number every
	# time reads as arithmetic; the average is unchanged, so nothing balanced
	# against it moves.
	var damage: float = TowerData.roll_damage(
		data.contact_damage * _damage_scale * _rank_scale().y
			* _affix_product(&"damage_scale")
			* _enemy_damage_scale(), RunState.rng("combat"))
	if _boss_phase > 0:
		damage *= 1.0 + data.phase_damage_bonus * float(_boss_phase)
	if data.role != EnemyData.Role.HOWLER:
		var howler: Enemy = _nearby_howler()
		if howler != null:
			damage *= 1.0 + howler.data.aura_strength
	if RunState.enemies_are_weakened():
		damage *= Balance.WEAKENED_STAT_SCALE
	if _target == _field.town_node():
		damage *= Balance.TOWN_DAMAGE_SCALE
	# Said once the number is final, so the debrief reports the blow that landed
	# rather than the one that was rolled. `promoted_name` carries the affixes:
	# being felled by a Rimewarded Ironhide Bogkin is a different story from a
	# Bogkin, and the death screen should be able to tell it.
	if _target is Hero:
		RunState.note_blow(promoted_name(), damage)
	# Whatever the affixes do to what they touch. Both may apply, and that is the
	# combination working: Rimewarded and Emberclad chills *and* burns, with
	# nothing anywhere describing the pair.
	var struck := _target as Enemy
	for affix: EnemyAffixData in affixes:
		if affix.on_hit_slow_duration > 0.0 and struck != null:
			struck.apply_slow(affix.on_hit_slow, affix.on_hit_slow_duration)
		if affix.on_hit_burn_duration > 0.0 and struck != null:
			struck.apply_burn(affix.on_hit_burn, affix.on_hit_burn_duration)
		# **Mana lands on the person**, which is what makes this mark different
		# from the two above: an enemy's target is nearly always a hero, and mana
		# is worth everything to a caster and nothing at all to a swordhand. The
		# same two axes the five shots vary along.
		if affix.on_hit_mana_burn > 0.0 and _target is Hero:
			(_target as Hero).burn_mana(affix.on_hit_mana_burn)
	# Said out loud, so a guest can draw the blow it is not simulating. A puppet
	# never runs this function, so without the announcement a ranged enemy on the
	# other screen hurt people from across the field with nothing in between.
	if data.role == EnemyData.Role.HOWLER:
		# Says `enemy_struck` itself, once it knows which shot it chose.
		_loose_a_shot(damage)
	elif net_id != 0:
		EventBus.enemy_struck.emit(net_id, _target.global_position, "")
		return
	if _target is Companion:
		(_target as Companion).take_damage(damage, combat_origin())
		return
	target_health.take_damage(damage, global_position)


# --- Damage and status ------------------------------------------------------

## Whether the crowd flows around this one instead of jostling it.
##
## Bosses, in both directions: a boss that shovelled its own escort down the road
## would look absurd, and one that could be shoved by a mob of Bogkins would stop
## reading as a boss. `phases` is the flag the content already uses to mean boss -
## it is empty for everything else - so this asks the data rather than adding a
## second answer to the same question.
##
## Summons are ordinary bodies. They are a crowd, and a crowd is the thing being
## separated.
func ignores_crowd() -> bool:
	return data != null and not data.phase_thresholds.is_empty()


## **This breed, speaking.** Silent unless it has been given a voice.
##
## One call across the whole field at a time (`Balance.ENEMY_VOICE_GAP`): a wave
## is forty bodies, and a shout every time one of them noticed you is a wall of
## noise rather than a road. A static clock rather than one per body, because
## what has to be rationed is *the field*, not each enemy.
##
## Pitched by the body making it, the same way a wildlife voice is - the roster
## shares recordings even more heavily than the animals do, so without this every
## breed that borrows the same roar is the same monster.
static var _last_voice_msec: int = 0


func speak() -> void:
	if data == null or data.voice_sfx.is_empty() or puppet:
		return
	var gap: float = data.voice_gap if data.voice_gap > 0.0 else Balance.ENEMY_VOICE_GAP
	var now: int = Time.get_ticks_msec()
	if now - _last_voice_msec < int(gap * 1000.0):
		return
	_last_voice_msec = now
	var body: float = maxf(contact_radius() / maxf(Balance.ENEMY_BODY_RADIUS, 1.0), 0.05)
	var shift: float = clampf(pow(1.0 / body, Balance.ENEMY_VOICE_PITCH_POWER),
		Balance.WILDLIFE_VOICE_PITCH_MIN, Balance.WILDLIFE_VOICE_PITCH_MAX) - 1.0
	Sfx.play_at(data.voice_sfx, global_position, 0.0, shift)


func contact_radius() -> float:
	return data.body_radius if data != null else Balance.ENEMY_BODY_RADIUS


func is_dying() -> bool:
	return _state == State.DYING


## True while the wind-up tell is showing — the window the player is meant to
## react to.
func is_telegraphing() -> bool:
	return _state == State.WINDUP


## Which phase a boss is in, 0 before the first break. For the welcome
## (2026-09-14), so a guest arriving mid-fight is told the boss as it stands.
func boss_phase() -> int:
	return _boss_phase


## How much sooner a boss in this phase slams and throws. One in phase zero;
## see `Balance.BOSS_PHASE_TEMPO`.
func _phase_tempo() -> float:
	return 1.0 / (1.0 + Balance.BOSS_PHASE_TEMPO * float(maxi(_boss_phase, 0)))


func apply_boss_phase(phase: int) -> void:
	_boss_phase = maxi(phase, _boss_phase)
	if _boss_phase <= 0:
		return
	# The ring and outward sparks make the transition readable through a crowd;
	# the persistent speed/damage change is authored on EnemyData.
	Vfx.ring(global_position, contact_radius() * 2.8,
		Color(1.0, 0.25, 0.12, 0.8), 0.75, 8.0)
	Vfx.spark(global_position, Color("ff7a4e"), 22, Vector2.ZERO, 330.0)
	animator.squash(1.45)


## A puppet ignores damage. The host decides what hurt it and by how much, and
## the answer arrives as health in `mirror`. Applying local damage as well would
## make a guest's enemies die early and then be resurrected by the next packet.
## Whether this body is worth the hero's attention over the ones beside it.
##
## **Extracted from the one `emit` that used to compute it inline.** Three
## discipline nodes describe themselves in terms of "priority prey" - Marrow
## Drain channels on it, Chain Hook pulls it - and each of those reimplementing
## the rule is how the three of them end up disagreeing about what prey is. It is
## also now a thing a gate can ask about, which an expression inside an argument
## list was not.
##
## Elites and champions qualify because they are the fight; Howlers and Burrowers
## qualify despite being ordinary bodies, because one buffs a swarm and the other
## goes round the line at the towers. Killing either first is the read.
func is_priority() -> bool:
	if data == null:
		return false
	return data.is_promoted() \
		or data.role == EnemyData.Role.HOWLER \
		or data.role == EnemyData.Role.BURROWER


## Seconds of brand left, and what it multiplies tower damage by.
##
## Judgment Brand paints an elite and the towers finish it. The amplifier is
## carried *on the brand* rather than looked up by the tower, so nothing in
## `tower.gd` has to know that disciplines exist - it asks the body in front of
## it how badly it has been marked and multiplies.
var _brand_left: float = 0.0
var _brand_amplifier: float = 0.0


## Paints this body for the towers. The longest-lasting brand wins rather than
## the newest, so re-branding something cannot shorten a mark already on it.
func brand(seconds: float, amplifier: float) -> void:
	if _state == State.DYING or seconds <= 0.0 or amplifier <= 0.0:
		return
	var fresh: bool = _brand_left <= 0.0
	_brand_left = maxf(_brand_left, seconds)
	_brand_amplifier = maxf(_brand_amplifier, amplifier)
	if fresh:
		# A mark nobody can see is a number in a log. The player has to be able
		# to pick the branded body out of a line at a glance, because choosing
		# what to brand is the whole decision the node asks for.
		Vfx.ring(_visual_origin(), Balance.DISCIPLINE_BRAND_RING, Color("ffd27a"))


func is_branded() -> bool:
	return _brand_left > 0.0


## Takes the brand off. **Blood Remembers** is the only thing that does this -
## a brand otherwise runs out on its own clock - and it is why the node is
## called what it is: the mark is spent rather than merely expiring.
func clear_brand() -> void:
	_brand_left = 0.0
	_brand_amplifier = 0.0


## What a tower's damage is multiplied by against this body. 1.0 when unbranded,
## so every caller can multiply unconditionally.
func brand_multiplier() -> float:
	return 1.0 + _brand_amplifier if _brand_left > 0.0 else 1.0


func _tick_brand(delta: float) -> void:
	if _brand_left <= 0.0:
		return
	_brand_left = maxf(_brand_left - delta, 0.0)
	if _brand_left <= 0.0:
		_brand_amplifier = 0.0
	_death_element_left = maxf(_death_element_left - delta, 0.0)
	if _death_element_left <= 0.0:
		_death_element = -1


## The element of the last elemental thing that touched this body, and how long
## that is still true for. `TowerData.Element`, or -1 for nothing.
##
## **Marked rather than passed.** Threading an element through `take_damage`
## would touch the thirty places that deal a blow, most of which have no element
## to offer; the handful of things that *do* have one say so here instead, and
## everything else leaves the memory alone.
var _death_element: int = -1
var _death_element_left: float = 0.0

## How reeled this body already is, 0 to 1, and how long it has been planted for.
## Presentation and spacing only: nothing here reads or moves damage.
var _stagger_load: float = 0.0
var _braced_left: float = 0.0
## **The break-out.** How many wind-ups have been knocked out of this body
## lately, whether its next one will be armoured, and whether the one under way
## is. See `_note_an_interruption`.
var _interrupts: int = 0
var _interrupt_clock: float = 0.0
var _breakout_armed: bool = false
var _breaking_out: bool = false
var _brace_refractory: float = 0.0


## Something of this element touched the body. Presentation only: nothing reads
## this but the death, and a body with no mark dies exactly as it always did.
func mark_element(element: int) -> void:
	if _state == State.DYING:
		return
	_death_element = element
	_death_element_left = Balance.DEATH_ELEMENT_MEMORY


func take_damage(amount: float, from: Vector2, knockback: float,
		active_hero: bool = false) -> bool:
	if _state == State.DYING or data == null or puppet:
		return false
	# **Every blow in the game goes through here**, which is why the impact is
	# announced here rather than at each of the thirty places that deal one.
	# Its weight is what the blow took off this body, so a shot that chips a
	# boss is a tremor and one that halves a runner is a hit (owner brief,
	# 2026-09-13).
	if health != null and health.max_hp > 0.0:
		EventBus.camera_impact.emit(global_position,
			amount / health.max_hp / Balance.IMPACT_FULL_SHARE)
	# **A planted shield takes the blow instead of the body behind it.**
	#
	# Redirected rather than reduced, and that distinction is the whole reason
	# this is allowed to exist. A frontal damage reduction raises the effective
	# health of a wave and `curve_report` would have to be re-derived against
	# it; moving the blow to the shield changes *where* the damage goes and not
	# how much there is, so the ten-act curve reads exactly the same. It is also
	# the better fight: the answer is to flank it or to break it, which is what
	# the review asked for, rather than to shoot harder.
	var cover: Enemy = _anchor_covering(from)
	if cover != null:
		return cover.take_damage(amount, from, knockback, active_hero)
	var was_telegraphing: bool = _state == State.WINDUP
	# **A ward turns one blow and is spent.** Checked before anything else so
	# the turned blow is the whole blow, and so a guard can never be worn down
	# by chip damage into something that outlasts a fight.
	if _guard_left > 0.0:
		_guard_left = 0.0
		Vfx.ring(global_position, data.body_radius * 2.2,
			Color(0.95, 0.88, 0.55, 0.8), 0.22, 3.0)
		return false
	var incoming: float = amount
	if RunState.enemies_are_weakened():
		incoming /= Balance.WEAKENED_STAT_SCALE
	# Ironhide and its kind. The *best* share rather than the product, because
	# two sources multiplying would approach immunity, and an enemy nothing can
	# hurt is not an affix, it is a wall.
	incoming *= 1.0 - _affix_best(&"damage_resistance")
	# **And whatever is standing over it.** An aura is a reason to kill one body
	# before the others, which is the readable play morale already makes of a
	# champion - and the best rather than the sum, because two of them
	# multiplying would approach immunity.
	var shelter: float = Balance.CAMP_FIRE_WARMTH_RESIST if camp_warmth else 0.0
	incoming *= 1.0 - clampf(maxf(_ally_aura(&"aura_resistance"), shelter),
		0.0, 0.35)
	if not health.take_damage(incoming, from):
		return false
	# A Prism Warden banks a capped share of what it is given.
	_bank_blow(incoming)
	_note_tower_blow(from)
	var attack_node: DisciplineNodeData = RunState.discipline_node_in_slot(0) \
		if active_hero else null
	if attack_node != null and attack_node.effect_id == "tower_damage_brand" \
			and is_priority():
		# Judgment Brand. Priority prey only, which is what stops it being a free
		# damage multiplier on everything the hero touches: the node asks you to
		# pick the body the towers should finish, and a brand you cannot help but
		# apply is not a choice.
		brand(Balance.DISCIPLINE_BRAND_SECONDS, attack_node.effect_value)
	if attack_node != null and attack_node.effect_id == "bleed_finisher":
		# The finisher is the only hit whose authored base damage reaches the last
		# chain value. Apply a bounded three-second bleed; it uses the shared status
		# path so death rewards and hit accounting remain identical.
		var finisher_damage: float = Balance.HERO_ATTACK_DAMAGE[Balance.HERO_CHAIN_LENGTH - 1] \
			* Modifiers.multiplier(Modifiers.HERO_DAMAGE)
		if amount >= finisher_damage * 0.9:
			apply_burn(amount * attack_node.effect_value, 3.0)
	# **How much this blow is allowed to move the body**, before anything is
	# moved by it. A fresh body reels exactly as it always did; one that has been
	# taking blows faster than it can recover stops being pushed around, and a
	# shield-bearer plants outright. The blow's *damage* was resolved above and
	# is untouched by any of this.
	var rocked: float = _absorb_a_blow()
	_add_hitstun(Balance.ENEMY_HITSTUN * rocked)
	# The number is the clearest signal that a hit registered at all, which
	# matters most when a swing catches six things at once.
	var body_at: Vector2 = _visual_origin()
	Vfx.number(body_at, incoming, Color("ffe3b0"), incoming >= data.max_hp * 0.4)
	var hit_direction: Vector2 = (global_position - from).normalized()
	Vfx.spark(body_at, Color("ffcf9a"), 4, hit_direction, 170.0)
	Vfx.blood(body_at, hit_direction, Balance.VFX_BLOOD_HIT_SIZE, global_position)
	animator.recoil(from, global_position, clampf(amount / maxf(data.max_hp, 1.0) * 3.0, 0.5, 1.8))
	animator.impact_frame()
	var away: Vector2 = global_position - from
	away = away.normalized() if away.length() > 0.001 else Vector2.RIGHT
	_knockback = away * knockback * (1.0 - data.knockback_resistance) * rocked
	# Being hit hard enough interrupts a wind-up. This is what makes attacking
	# into a telegraph a real answer rather than a trade - and a body that has
	# planted is no longer interrupted by it, which is what the plant is *for*.
	if knockback > 0.0 and rocked > Balance.STAGGER_MIN_SCALE \
			and _state == State.WINDUP and not _breaking_out:
		_enter(State.RECOVER, Balance.ENEMY_ATTACK_RECOVERY * 0.5)
		_note_an_interruption()
	if active_hero:
		EventBus.hero_enemy_hit.emit(data.id, lane, is_priority(),
			was_telegraphing and knockback > 0.0, global_position)
	return true


func _on_beast_step(impulse: Vector2, strength: float) -> void:
	if _state == State.DYING or _field is RaidArena:
		return
	var resistance: float = data.knockback_resistance if data != null else 0.0
	_knockback += impulse * strength * (1.0 - resistance) * 0.72
	_add_hitstun(Balance.BEAST_STEP_STUN * strength)
	animator.stagger(impulse, strength / sqrt(maxf(_mass_for_category(), 1.0)))


## Pushed away from a point without being hurt.
##
## Its own operation rather than `take_damage` with zero damage, because damage
## is not a side channel: a zero-damage hit still counts as a hit, still feeds
## the hit reaction, still wakes whatever is listening for the hero landing a
## blow, and would have made Mercy Under Fire read as a free attack that dealt
## nothing. Knockback resistance still applies - a Bulwark is not moved by pity.
func shove(from: Vector2, strength: float) -> void:
	if _state == State.DYING:
		return
	var away: Vector2 = global_position - from
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	var resistance: float = data.knockback_resistance if data != null else 0.0
	_knockback += away.normalized() * strength * (1.0 - resistance)
	_add_hitstun(Balance.ENEMY_HITSTUN)


## Chain Hook drags things in. Expressed as its own operation rather than as
## negative knockback, so knockback resistance does not accidentally make an
## enemy immune to being pulled.
func pull_toward(point: Vector2, strength: float) -> void:
	if _state == State.DYING:
		return
	var toward: Vector2 = point - global_position
	if toward.length() < 1.0:
		return
	_knockback = toward.normalized() * strength
	_add_hitstun(Balance.ENEMY_HITSTUN)


## Feeds the chill meter. Repeated slows stack toward the floor instead of the
## strongest one simply winning, which is what makes a second frost tower worth
## building rather than redundant.
## Locks the enemy briefly, unless one was applied too recently.
##
## The single door for every movement lock in the game. It used to be four
## separate assignments, and the one in `take_damage` fired on *every* hit with
## nothing to stop it refreshing - so enough incoming fire simply switched an
## enemy off, which is what a Glacial Mortar or a Pyre Cannon looked like from
## the player's side. Routing them all through here makes "an enemy always gets
## to move" a property of this class rather than of whatever is shooting it.
## **What a blow is worth as a shove, and what it does to this body's footing.**
##
## Called once per blow, before the flinch and the shove are applied. Returns the
## share of both that this blow gets, and raises the load on the way out, so the
## next one gets less. A body left alone recovers over `STAGGER_WINDOW`.
##
## **Nothing here touches damage**, and that is what lets the ten-act pressure
## curve still be read against the same numbers: a spammed body takes exactly the
## health it always took, it simply stops being furniture.
func _absorb_a_blow() -> float:
	if data == null:
		return 1.0
	if _braced_left > 0.0 or _breaking_out:
		return 0.0
	var worth: float = lerpf(1.0, Balance.STAGGER_MIN_SCALE,
		clampf(_stagger_load, 0.0, 1.0))
	_stagger_load = minf(_stagger_load
		+ 1.0 / maxf(data.stagger_tolerance, 1.0), 1.0)
	if _stagger_load >= Balance.BRACE_AT and data.brace_chance > 0.0 \
			and _brace_refractory <= 0.0 and _state != State.DYING \
			and not puppet and RunState.rng("combat").randf() < data.brace_chance:
		_set_the_shield()
		return 0.0
	return worth


## It plants. No flinch, no shove, a ring of its own, and whoever was standing on
## it is pushed off - which is the spacing the spam was buying, taken back.
##
## **A refusal, never a counter.** It deals no damage: a body that hit back here
## would be a source of damage arriving out of a fight the player was winning,
## and nothing in `curve_report` models it. What it costs the player is that the
## body is now un-interrupted and free to swing.
func _set_the_shield() -> void:
	_braced_left = Balance.BRACE_SECONDS
	_brace_refractory = Balance.BRACE_REFRACTORY + Balance.BRACE_SECONDS
	_knockback = Vector2.ZERO
	_hitstun_left = 0.0
	var at: Vector2 = _visual_origin()
	Vfx.ring(at, data.body_radius * 2.0, Color(0.86, 0.90, 1.0, 0.85), 0.28, 5.0)
	Vfx.spark(at, Color(0.94, 0.96, 1.0), 10, Vector2.ZERO, 200.0)
	animator.squash(1.2)
	Sfx.play_at("sfx_hit_armour_1", global_position, 1.5)
	EventBus.camera_impact.emit(global_position, Balance.IMPACT_FULL_SHARE * 0.25)
	# Everyone standing on it goes back. Heroes only: a brace is an answer to
	# being crowded by a player, and shoving the road's own bodies would be a
	# formation change nobody asked for.
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not who.is_alive():
			continue
		var apart: Vector2 = who.global_position - global_position
		if apart.length() > data.body_radius + attack_reach():
			continue
		var push: Vector2 = apart.normalized() if apart.length() > 0.01 \
			else Vector2.RIGHT
		who.shove(push * Balance.BRACE_SHOVE)


## Whether this body has planted itself. For the gate and for the field.
func is_braced() -> bool:
	return _braced_left > 0.0


## **A wind-up knocked out of this body, counted toward breaking out.**
##
## Owner, 2026-09-22: *"enemies that have been hitstunlocked from the player's
## spammed attacks are eventually able to break out of it and attack back, tuned
## for each enemy appropriately."* The footing above takes the *shove* away from
## a spammed body, and a shield-bearer plants - but the footing drains at two
## thirds a second, so a Warden swinging three times a second holds an ordinary
## body's load low for ever, and every blow still knocks its 0.45-second wind-up
## back into recovery. It never swings. That is the lock.
##
## So interruptions are counted inside `ENEMY_BREAKOUT_WINDOW`, and once a body
## has had `breakout_after()` wind-ups broken, the **next** one is armoured: no
## flinch, no shove, no stun, and the ordinary blow lands at its ordinary size.
## The tell is loud and early, so the answer - step out, or dodge it - is a
## read rather than a surprise.
##
## **Damage never moves, and that is the whole bound.** The blow that breaks out
## is the blow the body was always going to throw; what changed is that spamming
## can no longer refuse it. `curve_report` models no interruptions and so reads
## the same waves.
func _note_an_interruption() -> void:
	if puppet or data == null:
		return
	_interrupts += 1
	_interrupt_clock = Balance.ENEMY_BREAKOUT_WINDOW
	if _interrupts >= breakout_after():
		_breakout_armed = true


## How many wind-ups this body lets be broken before the next is armoured.
##
## **Derived from the tolerance each breed already declares** rather than typed
## into sixty-eight files: a boss (tolerance 1) breaks out after one, an anchor
## or a stone hide after two, an ordinary body after three. A breed tuned to reel
## longer is tuned to be held longer, which is the same statement.
func breakout_after() -> int:
	var tolerance: float = data.stagger_tolerance if data != null else 5.0
	return clampi(int(ceil(tolerance * Balance.ENEMY_BREAKOUT_TOLERANCE_SHARE)),
		1, Balance.ENEMY_BREAKOUT_MAX)


## The armoured swing begins: said loudly, so it is read rather than suffered.
func _break_out() -> void:
	_breakout_armed = false
	_breaking_out = true
	_interrupts = 0
	_interrupt_clock = 0.0
	_hitstun_left = 0.0
	_knockback = Vector2.ZERO
	var at: Vector2 = _visual_origin()
	Vfx.ring(at, data.body_radius * 2.4, Balance.ENEMY_BREAKOUT_COLOUR,
		Balance.ENEMY_ATTACK_WINDUP, 5.0)
	Vfx.spark(at, Balance.ENEMY_BREAKOUT_COLOUR, 12, Vector2.ZERO, 240.0)
	_flash_left = Balance.HIT_FLASH_TIME
	animator.squash(1.25)
	Sfx.play_at("sfx_hit_armour_1", global_position, 1.3)
	EventBus.camera_impact.emit(global_position, Balance.IMPACT_FULL_SHARE * 0.18)


## Whether the swing under way cannot be interrupted. For the gate and the field.
func is_breaking_out() -> bool:
	return _breaking_out


## How reeled this body is, 0 to 1. For the gate.
func stagger_load() -> float:
	return _stagger_load


func _add_hitstun(duration: float) -> void:
	if duration <= 0.0 or _hitstun_refractory > 0.0 or _breaking_out:
		return
	_hitstun_left = maxf(_hitstun_left, duration)
	_hitstun_refractory = duration + Balance.ENEMY_HITSTUN_GAP


func apply_slow(factor: float, duration: float) -> void:
	if factor >= 1.0 or duration <= 0.0:
		return
	_add_chill((1.0 - factor) * Balance.CHILL_PER_SLOW)
	_chill_hold = maxf(_chill_hold, duration)


## A freeze proc is chill, not a lock.
##
## This used to set a timer that any later proc refreshed, so overlapping freeze
## towers held an enemy still for as long as they kept firing. It now fills the
## meter faster than a plain slow does, and the lock - if one happens at all -
## comes from `_shatter`, under the same ceiling and refractory as everything
## else.
func apply_freeze(duration: float) -> void:
	if duration <= 0.0:
		return
	_add_chill(Balance.CHILL_PER_FREEZE_PROC)
	_chill_hold = maxf(_chill_hold, duration)


## Adds chill and locks the enemy if that fills the meter.
func _add_chill(amount: float) -> void:
	# Chill is a host decision, like damage. A puppet told to slow itself would
	# drift out of step with the body the host is actually simulating.
	if puppet:
		return
	if amount <= 0.0 or _state == State.DYING:
		return
	if data != null and data.category == EnemyData.Category.BOSS:
		amount *= Balance.CHILL_BOSS_RESIST
	# Flash freeze: a wet body chills faster.
	if is_wet():
		amount *= Balance.WET_CHILL_SCALE
	_chill = minf(_chill + amount, 1.0)
	mark_element(TowerData.Element.WATER)
	if _chill >= 1.0:
		_shatter()


## The moment at a full meter: a short lock, then back to walking slowed.
func _shatter() -> void:
	if _freeze_refractory > 0.0:
		return
	_freeze_left = maxf(_freeze_left,
		minf(Balance.CHILL_SHATTER_SECONDS, Balance.FREEZE_MAX_SECONDS))
	_freeze_refractory = Balance.FREEZE_REFRACTORY
	_chill = Balance.CHILL_AFTER_SHATTER
	animator.squash(1.25)


func apply_stagger(duration: float) -> void:
	if _state == State.DYING or duration <= 0.0:
		return
	_add_hitstun(duration)
	_knockback += Battlefield.lane_vector(lane) * 90.0
	if _state == State.WINDUP or _state == State.STRIKE:
		_enter(State.RECOVER, maxf(duration * 0.65, Balance.ENEMY_ATTACK_RECOVERY))
	animator.squash(1.35)


func apply_burn(dps: float, duration: float) -> void:
	if dps <= 0.0 or duration <= 0.0 or puppet:
		return
	# Steam: fire on a body soaked by water takes the wet off it and nothing
	# else. Rain-wet is thinner - the burn takes, for half as long.
	if _wet_left > 0.0:
		_wet_left = 0.0
		Vfx.dust(global_position + Vector2(0.0, -20.0), Color(0.86, 0.9, 0.94), 7, 44.0)
		return
	if is_wet():
		duration *= Balance.WET_BURN_SCALE
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = maxf(_burn_left, duration)
	mark_element(TowerData.Element.FIRE)


## Water hit this body: wet for a while. A host decision, like damage.
func apply_wet(seconds: float) -> void:
	if seconds <= 0.0 or puppet or _state == State.DYING:
		return
	if _wet_left <= 0.0:
		Vfx.dust(global_position + Vector2(0.0, -16.0), Color(0.45, 0.62, 0.86), 5, 30.0)
	_wet_left = maxf(_wet_left, seconds)
	# Wet puts a burn out.
	_burn_left = 0.0


## Wet by water that hit it, by rain heavy enough, or by a flood at the knee.
func is_wet() -> bool:
	return _wet_left > 0.0 or RunState.rain_intensity >= Balance.WET_RAIN_FROM \
		or RunState.flood >= Balance.FLOOD_KNEE


## What lightning does to this body against a dry one: conductive when wet.
func shock_scale() -> float:
	return Balance.WET_SHOCK_DAMAGE if is_wet() else 1.0


## The behaviour's own clocks: when it may next commit, and how long a guard
## somebody gave this body has left.
func _tick_behaviour_clocks(delta: float) -> void:
	_behaviour_wait = maxf(_behaviour_wait - delta, 0.0)
	_guard_left = maxf(_guard_left - delta, 0.0)


func _tick_status(delta: float) -> void:
	_tick_behaviour_clocks(delta)
	_tick_brand(delta)
	_freeze_refractory = maxf(_freeze_refractory - delta, 0.0)
	if _chill_hold > 0.0:
		_chill_hold -= delta
	elif _chill > 0.0:
		_chill = maxf(_chill - Balance.CHILL_DECAY * delta, 0.0)
	_slow_factor = lerpf(1.0, Balance.CHILL_SLOW_FLOOR, _chill)
	if _freeze_left > 0.0:
		_freeze_left -= delta
	if _wet_left > 0.0:
		_wet_left -= delta
	if _burn_left > 0.0:
		_burn_left -= delta
		health.take_damage(_burn_dps * delta, global_position)
	if data.hp_regen > 0.0:
		health.heal(data.hp_regen * delta)
	# Walking home is where a camp body heals: fast, and only then, so the
	# choice a hero makes at the leash is a real one - press and finish it, or
	# leave and face it whole.
	if _camp_returning and health != null:
		health.heal(health.max_hp * Balance.CAMP_RETURN_REGEN * delta)
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null and terrain.enemy_hp_regen > 0.0:
		health.heal(terrain.enemy_hp_regen * delta)


func _on_damaged(_amount: float, from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	_impact_direction = (global_position - from).normalized()
	BloodStain.strike(_blood, _impact_direction)
	_camp_calm = 0.0
	# Hit from close by while busy with the wall or the town: whoever did it is
	# the fight now. A body that kept chewing the gate while a companion bit
	# its heels read as ignoring the companion (owner brief, 2026-09-12).
	if _field == null or not _field.has_method("nearest_foe"):
		return
	if _target != null and is_instance_valid(_target) \
			and (_target is Hero or _target is Companion):
		return
	var foe: Node2D = _field.nearest_foe(global_position)
	if foe != null and is_instance_valid(foe) and _foe_stands(foe) \
			and foe.global_position.distance_to(from) <= Balance.ENEMY_RETALIATE_RANGE \
			and global_position.distance_to(foe.global_position) <= Balance.ENEMY_RETALIATE_RANGE:
		_target = foe


# --- Grudges against towers (2026-09-14) ----------------------------------------

## A tower this body has turned on, and for how much longer.
var _grudge: Node2D = null
var _grudge_left: float = 0.0
## Towers this body has already rolled against, by instance id, so a roll is
## one roll: a Bastion is a chance to be pulled in, not a chance per frame.
var _tower_rolls: Dictionary = {}
var _notice_timer: float = 0.0


## A blow landed. If a tower threw it, this body may turn on that tower for a
## while - "attack a tower back after being attacked by it" - with a chance,
## and only if the tower is close enough to reach without leaving the fight.
func _note_tower_blow(from: Vector2) -> void:
	if _field == null or is_camp_mob() or puppet or _grudge_left > 0.0:
		return
	if not _field.has_method("tower_near"):
		return
	var tower: Tower = _field.tower_near(from, Balance.ENEMY_TOWER_BLAME_RADIUS)
	if tower == null or not tower.is_vulnerable():
		return
	if global_position.distance_to(tower.global_position) > Balance.ENEMY_TOWER_GRUDGE_REACH:
		return
	if RunState.rng("combat").randf() < Balance.ENEMY_TOWER_RETALIATE_CHANCE:
		_grudge = tower
		_grudge_left = Balance.ENEMY_TOWER_GRUDGE_SECONDS


## Passing a tower unprovoked: a far rarer roll, once per tower, to go for it
## anyway. A body still prefers the road, which is what the curve is tuned on.
func _notice_towers(delta: float) -> void:
	if _field == null or is_camp_mob() or puppet or _grudge_left > 0.0:
		return
	_notice_timer -= delta
	if _notice_timer > 0.0:
		return
	_notice_timer = Balance.ENEMY_TOWER_NOTICE_TICK
	if not _field.has_method("tower_near"):
		return
	var tower: Tower = _field.tower_near(global_position, Balance.ENEMY_TOWER_NOTICE)
	if tower == null or not tower.is_vulnerable():
		return
	var key: int = tower.get_instance_id()
	if _tower_rolls.has(key):
		return
	var chosen: bool = RunState.rng("combat").randf() < Balance.ENEMY_TOWER_PREEMPT_CHANCE
	_tower_rolls[key] = chosen
	if chosen:
		_grudge = tower
		_grudge_left = Balance.ENEMY_TOWER_GRUDGE_SECONDS


## Whether a taunting tower pulls this body in: within its reach, and by a
## roll made once per tower. A taunt that always worked was a wall that
## chose every fight; a chance is a wall that changes some.
func _taunted_by(taunt: Node2D) -> bool:
	if global_position.distance_to(taunt.global_position) > Balance.BASTION_TAUNT_RADIUS:
		return false
	var key: int = taunt.get_instance_id() + 1
	if not _tower_rolls.has(key):
		_tower_rolls[key] = RunState.rng("combat").randf() < Balance.BASTION_TAUNT_CHANCE
	return bool(_tower_rolls[key])


## Whatever it leaves behind. Volatile and its kin.
##
## Hurts enemies rather than the hero, which is deliberate: the blast is the
## *player's* problem to stand clear of, and making it friendly fire would turn
## a threat into a tool. It reads as a threat because it kills things.
## **How a body comes apart, by what finished it.**
##
## A kill by fire should not look like a kill by frost, and until now every one
## of them looked the same. The element is the one the body was last marked with
## inside `DEATH_ELEMENT_MEMORY`; an ordinary sword leaves no mark and gets the
## death it always got.
##
## **Nothing here is read by anything.** No loot, no reward, no timing and no
## number changes - the corpse fades on the same clock, the drops are the same
## drops. It is the same bound the fog, the rank sheen and the phenotype are
## held to, and turning the particles down turns it down with nothing moving.
func _elemental_end() -> void:
	if _death_element < 0 or Graphics.particle_scale() <= 0.0:
		return
	var at: Vector2 = _visual_origin()
	var size: float = clampf(data.body_radius / 26.0, 0.7, 2.6)
	match _death_element:
		TowerData.Element.FIRE:
			# Charred, and still going out.
			Vfx.spark(at, Color(1.0, 0.62, 0.22), int(10 * size), Vector2.UP, 130.0)
			Vfx.dust(at, Color(0.24, 0.21, 0.2), int(8 * size), 46.0)
			sprite.self_modulate = Color(0.34, 0.26, 0.24, 1.0)
		TowerData.Element.WATER:
			# Frozen through and then not there: the shatter it earned.
			Vfx.spark(at, Color(0.74, 0.92, 1.0), int(14 * size), Vector2.ZERO, 210.0)
			Vfx.ring(at, data.body_radius * 1.5, Color(0.78, 0.94, 1.0, 0.7),
				0.22, 4.0)
			animator.squash(1.5)
			sprite.self_modulate = Color(0.78, 0.9, 1.0, 1.0)
		TowerData.Element.AIR:
			# Taken off its feet and scattered.
			Vfx.spark(at, Color(0.86, 0.95, 1.0), int(12 * size),
				Vector2.UP.rotated(randf_range(-0.8, 0.8)), 260.0)
			animator.punch(Vector2.UP, 1.4)
		TowerData.Element.EARTH:
			# Down in one piece, and a piece of the ground with it.
			Vfx.dust(at, Color(0.5, 0.44, 0.36), int(14 * size), 96.0)
			Vfx.spark(at, Color(0.62, 0.55, 0.45), int(7 * size), Vector2.ZERO, 120.0)
			animator.squash(1.6)
			EventBus.camera_impact.emit(global_position,
				Balance.IMPACT_FULL_SHARE * 0.35 * size)


## **What falls with it, for the bodies around it.**
##
## The opposite decision to an aura: a body whose death mends its company is one
## to leave for last, where a body whose life hastes its company is one to kill
## first. Both exist so that "which of these do I hit" is a question with more
## than one answer.
##
## It mends and never revives - `Health.heal` is the same door a Mason Shrine
## uses, and stone that has fallen stays fallen.
func _mend_the_company() -> void:
	if _field == null or data == null:
		return
	for affix: EnemyAffixData in affixes:
		if affix.death_mends_allies <= 0.0 or affix.aura_radius <= 0.0:
			continue
		for other: Enemy in _allies_in(affix.aura_radius):
			if other == null or other.is_dying() or other.health == null:
				continue
			other.health.heal(other.health.max_hp * affix.death_mends_allies)
		Vfx.ring(combat_origin(), affix.aura_radius,
			Color(affix.mark_colour, 0.45), 0.5, 4.0)


func _burst_on_death() -> void:
	if _field == null:
		return
	for affix: EnemyAffixData in affixes:
		if affix.death_blast_radius <= 0.0:
			continue
		Vfx.ring(combat_origin(), affix.death_blast_radius,
			Color(affix.mark_colour, 0.65), 0.34, 6.0)
		for hero: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
			var who := hero as Hero
			if who == null or not who.is_alive():
				continue
			if combat_origin().distance_to(who.global_position) > affix.death_blast_radius:
				continue
			var hurt: Health = Health.of(who)
			if hurt != null:
				hurt.take_damage(affix.death_blast_damage, combat_origin())


func _on_died(_from: Vector2) -> void:
	_enter(State.DYING, 0.0)
	_death_left = Balance.ENEMY_DEATH_FADE
	remove_from_group(GROUP)
	health_bar.visible = false
	RunState.enemies_killed += 1
	# A promoted body is worth what it cost to bring down.
	var spoils: float = float(data.resource_value)
	if is_camp_mob():
		spoils *= Balance.CAMP_SPOILS_SCALE
	match rank:
		Rank.CHAMPION:
			spoils *= Balance.CHAMPION_REWARD_SCALE
		Rank.ELITE:
			spoils *= Balance.ELITE_REWARD_SCALE
	RunState.gain_kill_resources(int(round(spoils)))
	_burst_on_death()
	_mend_the_company()
	_elemental_end()
	# XP scales with the enemy's health rather than an authored per-enemy number,
	# so an elite is worth more than a runner with no second table to maintain,
	# and act scaling carries the curve forward on its own.
	# The tier's own multiplier on top of the health it already scaled, so a Hell
	# kill is worth more than the same enemy on Normal twice over: once for being
	# tougher, once for the tier being worth running.
	var tier: CampaignTierData = RunState.tier()
	var payout: float = data.max_hp * _hp_scale * Balance.HERO_XP_PER_HP
	if is_camp_mob():
		payout *= Balance.CAMP_XP_SCALE
	RunState.gain_hero_xp(payout * (tier.xp_scale if tier != null else 1.0))
	_drop_loot()
	_drop_gear()
	_drop_blueprint()
	_drop_healing_orb()
	_drop_supply_crate()
	_drop_quiver()
	_drop_mana_orb()
	if data.category == EnemyData.Category.ELITE:
		RunState.gain_currency(RunState.STONE, Balance.ELITE_STONE_REWARD)
		if _field != null and _field.has_method("try_spawn_mender_spark"):
			_field.try_spawn_mender_spark(global_position)
	if oath_pursuer:
		RunState.mark_last_scar_pursuer_defeated()
		Vfx.ring(global_position, 154.0, Color(0.96, 0.36, 0.28, 0.9), 0.72, 8.0)
		Vfx.spark(global_position, Color("ffd0a0"), 28, Vector2.UP, 250.0)
	# **A leader falling breaks the bodies around it.**
	#
	# Only a promoted body does this, and only ordinary ones answer, so the
	# readable play is to kill the champion first and watch its line come apart.
	# Nothing here changes what the wave costs - see `_morale`.
	if rank != Rank.COMMON and _field != null and _field.has_method("enemies_near"):
		for other: Enemy in _field.enemies_near(global_position,
				Balance.ENEMY_MORALE_RADIUS):
			if other != self:
				other.shake_morale(Balance.ENEMY_MORALE_LEADER_LOSS)
	# **Break the Host.** An elite falling while a channel runs buys it a
	# moment more. Said as a fact rather than reached for: the caster is the
	# thing that knows whether a channel is running.
	if rank != Rank.COMMON or data.is_promoted():
		EventBus.elite_fell.emit(_visual_origin())
	EventBus.enemy_died.emit(data.id, _visual_origin())


## Removes this enemy without killing it.
##
## For the pack a boss called and then died before it could spend. The boss's
## death ends the wave and the act, so anything it summoned rides into the next
## act's Preparation - which is untimed and is meant to be the one safe phase.
## The player was spending it hunting leftovers instead of preparing, which is
## the exact failure that phase exists to prevent.
##
## Deliberately not `_on_died`, and the difference is the whole point: nothing
## here is a kill. No kill count, no resources, no hero XP, no loot, no gear, no
## `enemy_died`. Paying out for these would make ignoring a boss's adds and
## rushing the boss the most profitable way to fight one, which is the opposite
## of what summoning is for.
##
## It fades rather than popping. A dozen sprites vanishing on a single frame
## reads as a crash, not as a rout.
func dismiss() -> void:
	if is_dying():
		return
	_enter(State.DYING, 0.0)
	_death_left = Balance.ENEMY_DEATH_FADE
	remove_from_group(GROUP)
	remove_from_group(SUMMON_GROUP)
	health_bar.visible = false


## Scatters this kill's bonus loot, if it rolled any.
##
## Rolled from the combat stream so a seeded replay drops the same things, and
## rounded up to at least one so a low-value enemy that *did* roll a drop never
## produces a pickup worth nothing.
func _drop_loot() -> void:
	if _field == null or not _field.has_method("spawn_loot"):
		return
	var elite: bool = data.is_promoted()
	var chance: float = Balance.LOOT_DROP_CHANCE
	if elite:
		chance = 1.0
	if RunState.rng("combat").randf() > chance:
		return
	var share: float = float(data.resource_value) * Balance.KILL_RESOURCE_SCALE 		* Balance.LOOT_BONUS_SHARE * Balance.kill_act_scale(RunState.act)
	if elite:
		share *= Balance.LOOT_ELITE_MULTIPLIER
	var tier: CampaignTierData = RunState.tier()
	if tier != null:
		share *= tier.loot_scale
	var amount: int = maxi(1, int(round(share)))
	# **An elite leaves a pouch, not a coin** (owner, 2026-09-21). It lands as
	# one thing and spills into pieces when it is taken, which is the second
	# scatter the player gets to watch. A plain body's bonus falls as pieces
	# straight away - `spawn_loot` does the cutting.
	if elite:
		_field.spawn_loot(Balance.COIN_POUCH_ID, amount, global_position)
		return
	var currency: String = RunState.CURRENCIES[
		RunState.rng("combat").randi_range(0, RunState.CURRENCIES.size() - 1)]
	_field.spawn_loot(currency, amount, global_position)


## A sip of life, from something that died hard.
##
## Owner brief, 2026-09-10, and the design is stated in `Balance` beside the
## constants: the orb is the *opposite half* of the Mender's Spark. The Spark is
## one per act, elite-only, gated on being badly hurt, and pays a regeneration
## that breaks when you are hit - an event. An orb is common, needs no
## permission, and heals a little the instant you reach it.
##
## Scaled by rarity and by the enemy's own worth, which is what the brief asked
## for, and capped so that neither can add up to a mistake being paid for.
##
## Rolled on its own RNG stream. The gear roll's comment says why: a separate
## deterministic stream means adding a cosmetic spark cannot rewrite what a
## seeded run drops, and an orb is the kind of thing that gets retuned often.
func _drop_healing_orb() -> void:
	if _field == null or not _field.has_method("spawn_loot") or puppet:
		return
	var chance: float = Balance.HEALING_ORB_BREED_CHANCE
	match data.category:
		EnemyData.Category.ELITE:
			chance = Balance.HEALING_ORB_ELITE_CHANCE
		EnemyData.Category.BOSS:
			chance = Balance.HEALING_ORB_BOSS_CHANCE
	if RunState.rng("recovery").randf() > chance:
		return
	# The amount rides on the drop, not on whoever picks it up, so a partner
	# collecting an orb in co-op gets the orb that was dropped rather than one
	# recomputed from an enemy that no longer exists.
	_field.spawn_loot(Balance.HEALING_ORB_ID, healing_orb_amount(), global_position)


## What one orb from this body is worth, as a whole number of health points on
## the ordinary hero scale. Capped, and the cap is the whole balance argument.
func healing_orb_amount() -> int:
	var fraction: float = Balance.HEALING_ORB_BASE_FRACTION 		+ float(data.resource_value) * Balance.HEALING_ORB_POWER_PER_VALUE
	fraction = minf(fraction, Balance.HEALING_ORB_MAX_FRACTION)
	return maxi(int(round(Balance.HERO_MAX_HP * fraction)), 1)


## A crate, rarely, from something worth killing.
##
## Shares the orb's stream and the orb's reasoning about rarity and power. What
## makes it a different reward is the *spread*: a crate can pay currency, or
## health, or several of both, and which it pays is not known until it breaks.
func _drop_supply_crate() -> void:
	if _field == null or not _field.has_method("spawn_loot") or puppet:
		return
	var chance: float = Balance.SUPPLY_CRATE_BREED_CHANCE
	match data.category:
		EnemyData.Category.ELITE:
			chance = Balance.SUPPLY_CRATE_ELITE_CHANCE
		EnemyData.Category.BOSS:
			chance = Balance.SUPPLY_CRATE_BOSS_CHANCE
	var tier: CampaignTierData = RunState.tier()
	if tier != null:
		chance *= minf(maxf(tier.loot_scale, 1.0), Balance.GEAR_TIER_ODDS_CEILING)
	if RunState.rng("recovery").randf() > chance:
		return
	# The crate carries the *worth of the body that dropped it*, not a fixed
	# figure: what falls out is decided when it breaks, and by then the enemy is
	# gone. Same reasoning as the orb carrying its own healing amount.
	_field.spawn_loot(Balance.SUPPLY_CRATE_ID, crate_value(), global_position)


## What a crate from this body carries, as the currency value of one spill.
func crate_value() -> int:
	var share: float = float(data.resource_value) * Balance.KILL_RESOURCE_SCALE 		* Balance.LOOT_BONUS_SHARE * Balance.SUPPLY_CRATE_VALUE_SCALE 		* Balance.kill_act_scale(RunState.act)
	if data.is_promoted():
		share *= Balance.LOOT_ELITE_MULTIPLIER
	var tier: CampaignTierData = RunState.tier()
	if tier != null:
		share *= tier.loot_scale
	return maxi(1, int(round(share)))


## Gear used to exist only behind a raid chest. The battlefield now has its own
## low-frequency hunt: breeds can surprise, elites are meaningful prospects and
## bosses always leave a piece. A separate deterministic stream means adding a
## cosmetic spark or changing attack variance cannot rewrite the stash reward.
## A quiver, off a breed that carries something to throw, for a Warden who
## carries something to loose (owner, 2026-09-21: "more loot variety").
##
## Never dropped for a Warden without a bow: a pickup that pays nothing is a
## pickup that teaches the player to stop picking things up. Rolled on the
## recovery stream, like the orb, for the reason written above it.
func _drop_quiver() -> void:
	if _field == null or not _field.has_method("spawn_loot") or puppet:
		return
	if data.role != EnemyData.Role.HOWLER and data.thrown_shot_id.is_empty():
		return
	if RunState.ranged_id.is_empty() or RunState.ammo_id.is_empty():
		return
	if RunState.rng("recovery").randf() > Balance.QUIVER_DROP_CHANCE:
		return
	var shots: int = RunState.rng("recovery").randi_range(Balance.QUIVER_SHOTS_MIN,
		Balance.QUIVER_SHOTS_MAX)
	_field.spawn_loot(Balance.QUIVER_ID, shots, global_position)


## The healing orb's blue twin: a share of the mana pool, bounded by the pool.
## Carried as a percentage rather than a number, because the pool is the
## Warden's and the drop should not have to know how deep it is.
func _drop_mana_orb() -> void:
	if _field == null or not _field.has_method("spawn_loot") or puppet:
		return
	var chance: float = Balance.MANA_ORB_BREED_CHANCE
	match data.category:
		EnemyData.Category.ELITE:
			chance = Balance.MANA_ORB_ELITE_CHANCE
		EnemyData.Category.BOSS:
			chance = Balance.MANA_ORB_BOSS_CHANCE
	if RunState.rng("recovery").randf() > chance:
		return
	_field.spawn_loot(Balance.MANA_ORB_ID, Balance.MANA_ORB_PERCENT, global_position)


func _drop_gear() -> void:
	if _field == null or not (_field is Battlefield) \
			or not _field.has_method("spawn_gear"):
		return
	var chance: float = Balance.GEAR_BATTLEFIELD_DROP_CHANCE
	match data.category:
		EnemyData.Category.ELITE:
			chance = Balance.GEAR_BATTLEFIELD_ELITE_CHANCE
		EnemyData.Category.BOSS:
			chance = Balance.GEAR_BATTLEFIELD_BOSS_CHANCE
	var tier: CampaignTierData = RunState.tier()
	if tier != null:
		# A harder tier drops more, not merely bigger numbers. Without this the
		# correct play is to farm Normal forever, because Nightmare costs more and
		# pays the same. Bounded, so Hell cannot fill the stash in one act.
		chance *= minf(maxf(tier.loot_scale, 1.0), Balance.GEAR_TIER_ODDS_CEILING)
	if RunState.rng("gear").randf() > chance:
		return
	var tier_order: int = tier.order if tier != null else 0
	# A boss ends an act and is the reason to have survived it; one piece was the
	# same reward an elite could roll. Rolled separately, so a handful of loot can
	# be different kinds at different rarities rather than one line of text.
	var pieces: int = 1
	if data.category == EnemyData.Category.BOSS:
		pieces += Balance.GEAR_BOSS_EXTRA_PIECES
	for _piece: int in pieces:
		var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), tier_order,
			RunState.rng("gear"))
		if not piece.is_empty():
			_field.spawn_gear(piece, global_position)


## A plan, from something that was worth killing.
##
## **Only what is not already known**, and only from elites and bosses. A
## blueprint the player has read is not a reward, and a common breed dropping
## recipes would turn permanent knowledge into a grind - the whole appeal is that
## a specific fight changed what your next run can do.
##
## Its own RNG stream, like gear, so adding a spark or retuning damage cannot
## quietly rewrite what a boss teaches.
func _drop_blueprint() -> void:
	if _field == null or not (_field is Battlefield) 			or not _field.has_method("spawn_blueprint"):
		return
	var chance: float = 0.0
	match data.category:
		EnemyData.Category.ELITE:
			chance = Balance.BLUEPRINT_ELITE_CHANCE
		EnemyData.Category.BOSS:
			chance = Balance.BLUEPRINT_BOSS_CHANCE
	if chance <= 0.0 or RunState.rng("plans").randf() > chance:
		return
	var unread: Array[String] = []
	var ids: Array = ContentDB.blueprints.keys()
	ids.sort()
	for id: Variant in ids:
		if not MetaState.unlocked_blueprints.has(String(id)):
			unread.append(String(id))
	if unread.is_empty():
		return
	_field.spawn_blueprint(unread[RunState.rng("plans").randi() % unread.size()],
		global_position)


## Coming apart, rather than becoming see-through.
##
## This was `modulate.a` counting down, and a body that fades is a body that
## turns into a ghost of itself and then is not there. Since 2026-09-01 it
## dissolves texel by texel from the feet up, flaring as it goes, in the colour
## of whatever condition it died in - see `state_dissolve`.
##
## The fade survives as the fallback for a body with no material, because the
## alternative there is an enemy that vanishes between one frame and the next.
func _tick_death(delta: float) -> void:
	_death_left -= delta
	if _death_left <= 0.0:
		queue_free()
		return
	var t: float = _death_left / Balance.ENEMY_DEATH_FADE
	var material: ShaderMaterial = _state_material()
	if ActorState.carried(material):
		var alight: float = ActorState.burn_level(_burn_left)
		var iced: float = 1.0 if _freeze_left > 0.0 else _chill
		# A corpse still burns while it comes apart, and still wears its rime -
		# but it is not about to hit anyone, and a wind-up rim on a dying body
		# is a tell that lies. `_update_state_shader` does not run during death,
		# so whatever the rim was at the moment of the kill would otherwise sit
		# there for the whole dissolve.
		ActorState.drive(material, alight, iced, 0.0)
		ActorState.dissolve(material, 1.0 - t, alight, iced)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, t)


## Mass drives how heavily this thing moves. Derived rather than authored, so
## the enemy `.tres` files did not all need a new field.
func _mass_for_category() -> float:
	match data.category:
		EnemyData.Category.ELITE:
			return Balance.ANIM_MASS_ELITE
		EnemyData.Category.BOSS:
			return Balance.ANIM_MASS_BOSS
		_:
			return lerpf(Balance.ANIM_MASS_BREED, Balance.ANIM_MASS_ELITE,
				clampf((data.body_radius - Balance.ENEMY_BODY_RADIUS) / 24.0, 0.0, 0.45))


func _apply_category_scale() -> void:
	var visual_scale: float = Balance.ENEMY_SPRITE_SCALE
	var reference_height: float = 96.0
	match data.category:
		EnemyData.Category.ELITE:
			visual_scale = Balance.ELITE_SPRITE_SCALE
			reference_height = 128.0
		EnemyData.Category.BOSS:
			visual_scale = Balance.BOSS_SPRITE_SCALE
			reference_height = float(sprite.texture.get_height()) if sprite.texture != null else 384.0
	if sprite.texture != null:
		visual_scale *= reference_height / maxf(float(sprite.texture.get_height()), 1.0)
	sprite.scale = Vector2.ONE * visual_scale
	if health_bar != null and sprite.texture != null:
		_depth_lift = float(sprite.texture.get_height()) * visual_scale \
			* Balance.ENEMY_FEET_ANCHOR
		# Preserve the authored world-space picture while changing the node—the
		# Y-sort key and combat position—to its feet.
		global_position.y += _depth_lift
		sprite.position.y -= _depth_lift
		health_bar.position.y = -float(sprite.texture.get_height()) * visual_scale * 0.92 \
			- (Balance.HEALTH_BAR_RANK_LIFT if rank != Rank.COMMON else 0.0)


## **How far above this body's origin its painting reaches**, which is the top
## of its head rather than a number somebody typed.
##
## The node sits at the feet and the sprite is drawn `_depth_lift` above them,
## so the art's top is that plus half its drawn height. Anything hung over a
## body - a marker, a plume, a shout - asks this rather than assuming, because
## a giant and a runner are three times apart and one constant cannot be right
## for both (owner, 2026-09-22: the straggler chevron "needs its height
## adjusted to ensure it's properly above the highest part of the sprite").
func art_top_offset() -> float:
	if sprite == null or sprite.texture == null:
		return _depth_lift + 48.0
	return _depth_lift + float(sprite.texture.get_height()) * absf(sprite.scale.y) * 0.5


## Centre-authored combat position, kept separate from the feet used for depth.
## Projectiles, blood and hit reactions all originate here.
func combat_origin() -> Vector2:
	return global_position + Vector2(0.0, -_depth_lift)


func _visual_origin() -> Vector2:
	return combat_origin()


## The ring that says this one is not ordinary.
##
## **A promotion nobody can see is a promotion that does not exist.** Three tells,
## because one is not enough across a busy field: the body is larger, it stands
## in a coloured ring, and the ring's colour is the affix's own - so a player who
## has met Rimewarded twice recognises the third before it reaches them.
##
## Built after the scale for the same reason the aura ring is: `_depth_lift` does
## not exist before then, and a ring drawn without it sits on the floor.
func _build_rank_mark() -> void:
	if rank == Rank.COMMON or sprite == null or sprite.texture == null:
		return
	# Bigger, first and most legible. Read from across the field before any
	# colour is.
	var grow: float = _rank_scale().z
	sprite.scale *= grow
	_depth_lift *= grow

	var tint: Color = affixes[0].mark_colour if not affixes.is_empty() 		else Color(0.95, 0.82, 0.45)
	# An elite wears every colour it carries, blended, so a two-affix body is
	# visibly not either of its parts.
	for index: int in range(1, affixes.size()):
		tint = tint.lerp(affixes[index].mark_colour, 0.5)

	# **A real outline on the silhouette**, not just a tint. `actor_polish` already
	# draws one for towers and wildlife; a promoted body wears it in its own
	# colour, which is what makes it pick out of a crowd at a glance rather than
	# on inspection.
	var polish: ShaderMaterial = ActorPolishScript.attach(sprite)
	_polish = polish
	if polish != null:
		polish.set_shader_parameter("outline_colour", Color(tint, 0.95))
		polish.set_shader_parameter("outline_strength",
			1.0 if rank == Rank.ELITE else 0.88)
		# **The band moves.** A flat coloured line said "this one is promoted"
		# and nothing else; a glow that licks and breathes says it is dangerous,
		# which is the thing the player actually needs to read across a field.
		# Champions burn wider and slower than elites - at the same speed the two
		# are one effect at two volumes, and the eye separates rhythm long before
		# it separates colour.
		var champion: bool = rank != Rank.ELITE
		polish.set_shader_parameter("aura_colour", Color(tint, 1.0))
		polish.set_shader_parameter("aura_strength",
			Balance.RANK_AURA_STRENGTH_CHAMPION if champion
				else Balance.RANK_AURA_STRENGTH_ELITE)
		polish.set_shader_parameter("aura_speed",
			Balance.RANK_AURA_SPEED_CHAMPION if champion
				else Balance.RANK_AURA_SPEED_ELITE)
		polish.set_shader_parameter("aura_width",
			Balance.RANK_AURA_WIDTH_CHAMPION if champion
				else Balance.RANK_AURA_WIDTH_ELITE)
		polish.set_shader_parameter("aura_scale", Balance.RANK_AURA_SCALE)

	_mark = Line2D.new()
	var radius: float = float(sprite.texture.get_width()) * sprite.scale.x * 0.46
	# **On the ground it stands on.** The ring is a footprint, not a halo - it
	# marks where the body is on the field, which is the feet, and the node
	# already sits there since depth sorting moved it.
	var centre := Vector2.ZERO
	var points: PackedVector2Array = []
	for i: int in 33:
		points.append(centre + Vector2.RIGHT.rotated(TAU * float(i) / 32.0)
			* Vector2(1.0, 0.42) * radius)
	_mark.points = points
	_mark.width = 3.0 if rank == Rank.ELITE else 2.0
	_mark.default_color = Color(tint, 0.85 if rank == Rank.ELITE else 0.6)
	# Under the body: a ring drawn over it would read as a status effect rather
	# than as the ground it stands on.
	_mark.z_index = -1
	add_child(_mark)
	# The sprite carries the colour too, faintly. The ring says "promoted"; the
	# tint says which kind, and it survives the ring being hidden behind a body.
	sprite.self_modulate = Color.WHITE.lerp(tint,
		Balance.RANK_TINT_STRENGTH if rank == Rank.ELITE
			else Balance.RANK_TINT_STRENGTH * 0.6)


## How far the painted body sits from the middle of its own canvas, in node
## units, signed for the way the sprite is currently facing.
##
## Cached per breed: it reads the texture's alpha, which is far too expensive
## to do per spawn, and there are fifteen breeds with an aura in the whole
## game. `get_used_rect` is the opaque bounds; half the canvas is where the
## sprite's origin is.
static var _body_centre: Dictionary = {}


func _body_offset_x() -> float:
	if sprite == null or sprite.texture == null or data == null:
		return 0.0
	if not _body_centre.has(data.id):
		var image: Image = sprite.texture.get_image()
		if image == null:
			return 0.0
		var used: Rect2i = image.get_used_rect()
		_body_centre[data.id] = (float(used.position.x) + float(used.size.x) * 0.5
			- float(image.get_width()) * 0.5)
	var offset: float = float(_body_centre[data.id]) * sprite.scale.x
	return -offset if sprite.flip_h else offset


func _build_aura_readout() -> void:
	if data.aura_radius <= 0.0:
		return
	var ring := Line2D.new()
	ring.name = "AuraRing"
	# **Centred on the body, not the feet, and not on the canvas either.**
	#
	# Depth sorting moved the node down to the ground contact point, so a ring
	# drawn at local zero sat a sprite-height below the thing it described -
	# that was the vertical half, fixed when the readout was written.
	#
	# The horizontal half went unnoticed until the owner reported the ember
	# shaman "not properly anchored in the middle of their circle range". A
	# sprite is drawn centred on its *canvas*, and the painted body is not
	# always in the middle of it: measured across the fifteen breeds that carry
	# an aura, most sit within a few pixels but the ember shaman's body spans
	# x 25..132 of a 192-wide canvas, so its ring stood seventeen pixels to the
	# right of the creature it belonged to.
	#
	# Derived from the art rather than authored per breed, so the fourteen
	# smaller offsets are corrected too and a new breed needs nobody to
	# remember this.
	# The points are built around the node; the horizontal offset rides on
	# `position` so the one place that follows the flip is the one place that
	# sets it. Both, and a breed turning round would move twice.
	var centre := Vector2(0.0, -_depth_lift)
	# The radius is the reach, so the circle and the rule are the same number.
	var shown: float = attack_reach() if data.role == EnemyData.Role.HOWLER \
		else data.aura_radius
	var points: PackedVector2Array = []
	for i: int in 49:
		points.append(centre + Vector2.RIGHT.rotated(TAU * float(i) / 48.0) * shown)
	ring.points = points
	ring.width = 2.0
	ring.default_color = Color(0.95, 0.42, 0.22, 0.22)
	ring.z_index = -1
	ring.position.x = _body_offset_x()
	add_child(ring)


## An active Howler turns a loose pack into an urgent escort target. The first
## valid aura is enough; overlapping Howlers do not compound into a speed spike.
func _nearby_howler() -> Enemy:
	if _field == null:
		return null
	for enemy: Enemy in _field.enemies_near(global_position, Balance.HOWLER_SEARCH_RADIUS):
		if enemy == self or enemy.data == null or enemy.is_dying():
			continue
		if enemy.data.role == EnemyData.Role.HOWLER \
				and global_position.distance_to(enemy.global_position) <= enemy.data.aura_radius:
			return enemy
	return null


## Blood, in proportion to the damage taken.
##
## Enemies bleed for the same reason heroes do: a wounded thing should look
## wounded. It also does a job a health bar cannot - in a pack of eight, the one
## that is nearly dead is the one worth finishing, and this says so without
## making the player read eight bars.
func _update_blood(delta: float) -> void:
	# Asked once, not once a frame. `attach` answers null for a sprite that
	# already has a material, so retrying on null meant retrying for ever.
	if not _blood_tried:
		_blood_tried = true
		_blood = BloodStain.attach(sprite, get_instance_id())
	BloodStain.drive(_blood, health.ratio() if health != null else 1.0, delta)
	if _flash_left > 0.0:
		BloodStain.strike(_blood, _impact_direction)
	BloodStain.drive_impact(_blood, _flash_left)
	_update_state_shader()


## Burning, freezing and winding up, written to whichever material this body has.
##
## `_state_material()` answers null only in a build whose actor shader failed to
## load - the Low preset still gets a stain material, it just gets one with its
## outline turned off. When it *is* null, `_update_sprite` tints instead; see the
## tint block for why that fallback is a gameplay promise rather than a look.
func _update_state_shader() -> void:
	var material: ShaderMaterial = _state_material()
	if material == null:
		return
	if not _state_seeded:
		_state_seeded = true
		ActorState.seed_pattern(material, get_instance_id())
	# Frozen solid is frost at full rather than a fourth effect: it is the same
	# ice, arrived. The chill meter is already 0..1 and needs no conversion.
	var frozen: float = 1.0 if _freeze_left > 0.0 else _chill
	ActorState.drive(material,
		ActorState.burn_level(_burn_left),
		frozen,
		ActorState.telegraph_level(_state_left, Balance.ENEMY_ATTACK_WINDUP)
			if _state == State.WINDUP else 0.0)


## Whichever of this body's two possible materials it actually wears.
func _state_material() -> ShaderMaterial:
	return _blood if _blood != null else _polish


func _update_sprite(delta: float = 0.0) -> void:
	# A walking enemy faces the way it is walking. A fighting enemy faces what it
	# is hitting. Those are different questions and the state answers which one
	# applies, because the two only agree on a straight approach.
	#
	# This used to ask about the target first, which meant an enemy that had
	# acquired something walked the rest of its leg backwards whenever the road
	# bent away from it - the lock outranked the legs. Motion now wins while
	# WALKING, and only WALKING moves under its own power, so the target branch
	# still covers the windup, the strike, the recovery and the knockback slide,
	# where facing the victim is right and facing the slide is not.
	#
	# Thresholded rather than tested against zero: an enemy tracking a bend drifts
	# a fraction of a unit either way on the x axis, and a bare sign test would
	# make it shudder between facings every frame. Below the threshold the facing
	# is left alone rather than reset, so a road running straight up the screen
	# does not blank it.
	# A body running away faces the way it is running, like any other.
	# **A body turns to face what it is walking at, unless turning would move a
	# prop into the wrong hand.**
	#
	# This used to refuse every `FRONT` sprite, which is about thirty-eight of the
	# roster, and the owner reported the result twice: bodies that never turn at
	# all. The refusal was too broad. Mirroring art drawn head-on does not rotate
	# it - it swaps its own left and right - and that is the "facing backwards"
	# fault *only where something is handed*: a shield moves to the other arm, a
	# war horn sounds out of the back of a head. A bandit's sword changing hands
	# reads as a man who turned round, and a symmetric body does not change at
	# all. `EnemyData.art_is_handed()` is the narrow refusal, mostly derived from
	# the shield the stagger work already made every breed declare.
	#
	# A head-on sprite has no painted facing to preserve, so it is treated as
	# drawn facing right: it flips when it goes left, like everything else.
	if not (data.art_facing == EnemyData.Facing.FRONT and data.art_is_handed()):
		var faces_right: bool = data.art_facing != EnemyData.Facing.LEFT
		if (_state == State.WALKING or _state == State.ROUTED) \
				and absf(_motion.x) > Balance.FACING_DEADZONE:
			sprite.flip_h = (_motion.x < 0.0) == faces_right
		elif _target != null and is_instance_valid(_target):
			sprite.flip_h = (_target.global_position.x < global_position.x) == faces_right
	# The ring follows the flip: a mirrored sprite puts its body on the other
	# side of the canvas, so a fixed offset would be wrong by twice itself the
	# moment the breed turned round.
	var ring := get_node_or_null("AuraRing") as Line2D
	if ring != null:
		ring.position.x = _body_offset_x()

	_advance_walk_frames(delta)

	var tint: Color = Color.WHITE
	# **The tint is the fallback, not the effect.** Since 2026-09-01 fire, ice
	# and the wind-up are drawn as material by `actor_state.gdshaderinc`, which
	# is a far better language for all three - see its header. But a machine with
	# polish shaders off has no material at all, and a player who cannot see a
	# wind-up is playing a harder game, not a plainer-looking one. So this stays,
	# and runs only when the shader is not carrying it.
	#
	# The colours come from Balance rather than from here so the two paths cannot
	# describe the same state differently, which they did while these were magic
	# numbers in this function and the shader had defaults of its own.
	if not ActorState.carried(_state_material()):
		if _freeze_left > 0.0:
			tint = Balance.STATE_FROST_COLOUR
		elif _chill > 0.02:
			# Deepens with the meter rather than being on or off, so a player can
			# see a shatter building and read a second frost tower as doing
			# something.
			tint = Color.WHITE.lerp(Balance.STATE_FROST_COLOUR, _chill)
		if _burn_left > 0.0:
			tint = tint.lerp(Balance.STATE_BURN_COLOUR, 0.5)
		# The wind-up tell overrides every other tint, because it is the one the
		# player has to read.
		if _state == State.WINDUP:
			var pulse: float = 0.5 + 0.5 * sin(_state_left * 34.0)
			tint = Balance.STATE_TELEGRAPH_COLOUR.lerp(Color(1.0, 0.95, 0.7), pulse)
	if _flash_left > 0.0:
		tint = Balance.HIT_FLASH_COLOUR.lerp(tint, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)
	sprite.modulate = tint


## Steps the authored walk cycle, or leaves the resting pose alone.
##
## **Driven by ground covered rather than by elapsed time.** A Chill that halves
## an enemy's speed has to halve its cadence too; a time-driven cycle keeps
## striding at full rate while the body crawls, which reads as skating and is
## precisely what the frames were added to stop. The procedural stride in
## `SpriteAnimator` has always worked this way and the two now agree.
##
## Attack tells outrank idle and walk. Idle only fills recovery and stationary
## walking states; a frozen, stunned or dying body must never keep breathing.
func _advance_walk_frames(delta: float) -> void:
	if sprite == null:
		return
	if _state == State.DYING or _freeze_left > 0.0 or _hitstun_left > 0.0:
		return
	# The swing outranks the walk, exactly as it does on the wildlife. A body
	# mid-attack is not walking, and a walk cycle playing through the wind-up
	# would bury the tell it exists to show.
	if _advance_attack_frames():
		return
	# A routed body is walking too - it is simply walking the other way.
	# Left out of this, a fleeing enemy slid backwards up the road in its
	# standing pose, which reads as a body being dragged rather than one
	# running away.
	var walking: bool = (_state == State.WALKING or _state == State.ROUTED) \
		and _motion.length_squared() > 0.0
	if not walking:
		# Back to the standing pose rather than freezing mid-stride: an enemy
		# stopped with one leg forward reads as a bug, and it is where the
		# attack sequence starts from.
		_walk_phase = 0.0
		# Breathing while stopped, in every state that is not a swing, a stun or
		# a death. This used to be WALKING and RECOVER only, so a boss standing
		# at the gate - which is where a player looks at one longest - held a
		# single frame indefinitely. The states that must not breathe are
		# already refused above.
		if not _idle_frames.is_empty():
			_idle_phase = fmod(_idle_phase + delta * Balance.ENEMY_IDLE_FRAME_RATE,
				float(_idle_frames.size()))
			sprite.texture = _idle_frames[int(_idle_phase)]
		elif _rest_texture != null:
			sprite.texture = _rest_texture
		return
	_idle_phase = 0.0
	if _walk_frames.is_empty():
		return
	# Distance-driven, with a floor. See `ENEMY_WALK_FRAME_FLOOR`: the cycle
	# follows the ground the body covers, except when that is so slow the eye
	# stops reading it as a cycle - which is every boss in the game.
	# Scaled by the frames on disk against the count the stride was authored
	# for: an eight-frame walk has twice the poses in the same step, not a
	# step twice as long.
	var density: float = float(_walk_frames.size()) / maxf(Balance.ENEMY_WALK_CYCLE_FRAMES, 1.0)
	_walk_phase += maxf(_motion.length() * Balance.ENEMY_WALK_FRAMES_PER_PIXEL,
		Balance.ENEMY_WALK_FRAME_FLOOR) * density * delta
	sprite.texture = _walk_frames[int(_walk_phase) % _walk_frames.size()]


## The attack pose for this instant, or false if this body is not attacking.
##
## **Driven by where the state machine actually is, not by a timer of its own.**
## The whole value of an authored swing is that the blow lands on the frame that
## looks like the blow - so the sequence is mapped onto the three states rather
## than played at a fixed rate beside them:
##
##   WINDUP  -> the first half, coiling, at the speed the tell actually runs
##   STRIKE  -> the impact pose, held for the whole 0.12s the hit exists
##   RECOVER -> the rest, settling back toward standing
##
## A frame rate of its own would drift out of step the moment any of the three
## durations was tuned, and the failure would be a hit that lands before the
## weapon does - which reads as the enemy cheating rather than as an animation
## being wrong.
func _advance_attack_frames() -> bool:
	if _attack_frames.is_empty():
		return false
	var count: int = _attack_frames.size()
	# **The last frame is the blow.**
	#
	# The authored sequences build toward their action rather than peaking in the
	# middle - looked at on a contact sheet, the final frame is the hammer down,
	# the jaws shut, the lunge extended. Mapping the strike to the middle put the
	# coil on screen at the moment of impact and the blow during the recovery,
	# which reads as a hit landing before the weapon does.
	var impact: int = count - 1
	var frame: int = -1
	match _state:
		State.WINDUP:
			# Everything before the blow, spread across the tell.
			var through: float = clampf(
				1.0 - _state_left / maxf(Balance.ENEMY_ATTACK_WINDUP, 0.001),
				0.0, 1.0)
			frame = clampi(int(through * float(impact)), 0, maxi(impact - 1, 0))
		State.STRIKE:
			frame = impact
		State.RECOVER:
			# Back to standing rather than a fourth pose. Recovery is the longest
			# of the three states by far, and holding an extreme swing through it
			# leaves the body frozen mid-blow for three quarters of a second -
			# which reads as a stutter. Settling to rest is what a body does.
			return false
		_:
			return false
	sprite.texture = _attack_frames[clampi(frame, 0, count - 1)]
	_walk_phase = 0.0
	return true


## Keeps a shove inside the ground the field actually has.
##
## A hard enough blow used to throw a body past the border row and off the
## map, where nothing could reach it and it could not walk back. It bounces
## instead: the component that would leave is reflected and damped, which
## also reads better than a body sliding along an invisible wall.
## Where a knocked-back body ends up, and the wall it bounced off.
##
## **The scope's own edge, asked through `EnemyField.hold_inside`.** This wrote
## `BattleGrid.HALF_EXTENT - BattleGrid.TILE` out by hand, which is a third copy
## of the map's edge - and it is the *battlefield's* edge, so a body knocked back
## inside a raid camp or a rift maze was clamped to a square several times larger
## than the floor it was standing on and could be thrown clean off it.
func _bounced(at: Vector2) -> Vector2:
	var out: Vector2 = _field.hold_inside(at) if _field != null else at
	if not is_equal_approx(out.x, at.x):
		_knockback.x = -_knockback.x * Balance.KNOCKBACK_BOUNCE
	if not is_equal_approx(out.y, at.y):
		_knockback.y = -_knockback.y * Balance.KNOCKBACK_BOUNCE
	return out


# --- What an act boss does (2026-09-13) --------------------------------------------------

## A boss's own two attacks, on their own clocks.
##
## Independent of the walk and of the ordinary strike, because that is what
## makes a boss different from a large marcher: it is dangerous while it is
## walking, and it is dangerous at range. Both are authored per boss; a body
## with neither does nothing here.
func _tick_boss_abilities(delta: float) -> void:
	if data == null or not data.has_boss_abilities() or puppet:
		return
	if _state == State.DYING or _freeze_left > 0.0:
		return
	if _slam_tell > 0.0:
		_slam_tell = maxf(_slam_tell - delta, 0.0)
		if _slam_tell <= 0.0:
			_land_slam()
		return
	_slam_left = maxf(_slam_left - delta, 0.0)
	_volley_left = maxf(_volley_left - delta, 0.0)
	var quarry: Node2D = _field.nearest_foe(global_position) \
		if _field != null and _field.has_method("nearest_foe") else null
	if quarry == null or not is_instance_valid(quarry):
		return
	var gap: float = global_position.distance_to(quarry.global_position)
	if data.boss_slam_damage > 0.0 and _slam_left <= 0.0 \
			and gap <= data.boss_slam_radius * Balance.BOSS_SLAM_COMMIT:
		_begin_slam()
		return
	if data.boss_volley_damage > 0.0 and data.boss_volley_shots > 0 \
			and _volley_left <= 0.0 and gap <= data.boss_volley_range:
		_throw_volley(quarry)


## The tell. A circle the size of the blow, for exactly as long as the player
## has to leave it - drawn from the damage's own radius so the ring cannot
## lie about where the blow lands.
func _begin_slam() -> void:
	_slam_tell = Balance.BOSS_SLAM_TELL
	_slam_left = data.boss_slam_interval * _phase_tempo()
	Vfx.ring(global_position, data.boss_slam_radius,
		Balance.BOSS_SLAM_TELL_COLOUR, Balance.BOSS_SLAM_TELL, 5.0)
	Sfx.play("sfx_boss_stinger", -6.0)


## And the blow, on everything of the player's inside it.
## How hard this body hits, with everything the road has done to that.
##
## **`Modifiers.ENEMY_DAMAGE` was declared, written by five omens and three
## relics, and resolved by nothing.** In `the_far_horn` it is the *bane* - the
## price paid for the boon - so the portent handed over its `raid_charge` for
## free, and the run got easier the more portents were read. That is the exact
## inversion `omen_check` exists to prevent, arriving by a different route than
## the misspelling it watches for: the key was spelt correctly and no system
## ever asked for it.
##
## One function, because four places work out a blow - an ordinary strike, a
## bite at a provoked animal, a boss slam and a boss volley - and a modifier
## applied at three of four is a portent that charges most of the time.
func _enemy_damage_scale() -> float:
	return Balance.ENEMY_CONTACT_DAMAGE_SCALE * _ranged_share() \
		* maxf(Modifiers.multiplier(Modifiers.ENEMY_DAMAGE), 0.0)


func _land_slam() -> void:
	var damage: float = data.contact_damage * data.boss_slam_damage * _damage_scale \
		* _enemy_damage_scale()
	if _boss_phase > 0:
		damage *= 1.0 + data.phase_damage_bonus * float(_boss_phase)
	# Bounded by what a hero can live through. See `Balance.boss_slam_ceiling`:
	# the authored multiplier decides the boss's character and the ceiling
	# decides whether the player gets to be wrong about a telegraph once.
	damage = minf(damage, Balance.boss_slam_ceiling(RunState.act))
	EventBus.camera_impact.emit(global_position, 0.9)
	Vfx.ring(global_position, data.boss_slam_radius, Color(1.0, 0.62, 0.34, 0.8), 0.3, 6.0)
	Vfx.light_burst(global_position, Color(1.0, 0.7, 0.42), data.boss_slam_radius * 1.8, 1.2, 0.35)
	Vfx.dust(global_position, Color(0.42, 0.36, 0.32), 14, data.boss_slam_radius * 0.6)
	# The forged shock at the slam's own radius: the picture of the blow the
	# ring above already promised, never a second reach.
	Vfx.forge_play("slam_impact", global_position,
		data.boss_slam_radius * 2.0, Color(1.0, 0.72, 0.42, 0.8))
	# Through the one function that knows what "everything of the player's"
	# means. This had its own copy until the ranged shots needed the same
	# answer, and two copies of that rule is how one of them forgets about
	# spirits.
	var centre: Vector2 = global_position
	var radius: float = data.boss_slam_radius
	EnemyGroundStrike.strike_the_players(get_tree(), damage, promoted_name(),
		func(at: Vector2) -> bool:
			return centre.distance_to(at) <= radius,
		data.boss_slam_knockback, centre)


## The volley: a fan of shots at whoever it can see.
##
## Through the ordinary enemy projectile, so nothing downstream learns that
## bosses throw things - and so a shot the player dodges is dodged the same
## way every other shot in the game is.
func _throw_volley(quarry: Node2D) -> void:
	_volley_left = data.boss_volley_interval * _phase_tempo()
	var damage: float = data.contact_damage * data.boss_volley_damage * _damage_scale \
		* _enemy_damage_scale()
	if _boss_phase > 0:
		damage *= 1.0 + data.phase_damage_bonus * float(_boss_phase)
	var shots: int = maxi(data.boss_volley_shots, 1)
	# **The shot, and the whole burst.** A boss that throws six has each of them
	# bounded by the burst rather than by the single-shot share, so throwing
	# more shots spreads a volley out instead of multiplying it.
	damage = minf(damage, Balance.boss_volley_shot_ceiling(RunState.act, shots))
	var aim: Vector2 = (quarry.global_position - combat_origin()).normalized()
	# A boss's volley wears the boss's own shot (`EnemyData.volley_shot_id`).
	_shot_paint = data.volley_shot()
	for index: int in shots:
		var share: float = 0.0 if shots <= 1 \
			else (float(index) / float(shots - 1) - 0.5) * 2.0
		var shot := load("res://scenes/battlefield/enemy_projectile.gd").new() as EnemyProjectile
		_paint(shot)
		# Aimed at a point rather than at the body, so a fan is a fan: a
		# volley that all homed on the same target would be one shot drawn
		# three times.
		shot.configure_toward(combat_origin()
			+ aim.rotated(share * Balance.BOSS_VOLLEY_SPREAD) * data.boss_volley_range,
			combat_origin())
		shot.set("_damage", damage)
		shot.set("_target", quarry)
		_field.add_child(shot)
	Sfx.play("sfx_boss_stinger", -9.0)


# --- What a ranged breed throws (2026-09-13) ----------------------------------

## The five shots, dispatched from the breed's own data.
##
## Owner report: "the ranged enemies all have one attack and the same one". They
## did - `role == HOWLER` built one `EnemyProjectile` and nothing varied - so
## fourteen breeds across ten regions posed one question between them.
##
## **The bound is that a shot changes the shape of a blow and never its size.**
## A fan divides the strike it rolled, a mortar and a lance land that one strike
## on whoever is standing there, and a hex trades part of it for mana. Nothing
## here multiplies `damage`, which is what lets the ten-act curve still be read
## against the same numbers.
## **Whether this one may let something go on the approach.**
##
## Five conditions and every one of them is a bound rather than a detail:
##
## - **It has one authored.** A breed with no `thrown_shot_id` never asks.
## - **At a person.** A javelin at the wall or a tower is a siege engine, which
##   is a different breed; and an area shot aimed at the gate resolves on
##   nobody (see `EnemyGroundStrike`), so it would be a blow that vanished.
## - **Out of melee reach.** It may never add a throw to an exchange it is
##   already winning by touching you - that would be damage added rather than
##   damage moved.
## - **Within its own range**, which is authored and is not the Howler range.
## - **Off cooldown**, which is long. One thing on the way in, not a volley.
func _may_throw_on_the_way_in() -> bool:
	if data == null or _throw_cooldown > 0.0 or _state != State.WALKING:
		return false
	if data.thrown_shot() == null:
		return false
	if not (_target is Hero or _target is Companion):
		return false
	if not is_instance_valid(_target):
		return false
	var gap: float = _target_gap(_target)
	return gap > attack_reach() and gap <= data.thrown_range


## One javelin, at a share of what the body hits for.
##
## The damage is rolled through the same door a contact blow is, so every
## modifier that shapes a blow - the rank, the affixes, the weakening, the
## scaling - shapes this one too and nothing here is a second source of harm.
func _let_the_javelin_go() -> void:
	if _target == null or not is_instance_valid(_target) or data == null:
		return
	var shot: EnemyShotData = data.thrown_shot()
	if shot == null:
		return
	_throw_cooldown = data.thrown_interval
	var damage: float = TowerData.roll_damage(
		data.contact_damage * _damage_scale * _rank_scale().y
			* _affix_product(&"damage_scale")
			* _enemy_damage_scale() * data.thrown_share, RunState.rng("combat"))
	if RunState.enemies_are_weakened():
		damage *= Balance.WEAKENED_STAT_SCALE
	if _target is Hero:
		RunState.note_blow(promoted_name(), damage)
	if net_id != 0:
		EventBus.enemy_struck.emit(net_id, _target.global_position, shot.id)
	_shot_paint = shot
	match int(shot.kind):
		EnemyData.Shot.SPRAY:
			_loose_a_fan(damage)
		EnemyData.Shot.LOB:
			_mark_the_ground(damage)
		EnemyData.Shot.LANCE:
			_level_a_lance(damage)
		EnemyData.Shot.HEX:
			_loose_a_hex(damage)
		_:
			_loose_a_bolt(damage, _target, EnemyProjectile.Kind.BOLT)


func _loose_a_shot(damage: float) -> void:
	# A shooter whose target is the wall or a tower throws an ordinary bolt at
	# it, whatever its breed. An area blow resolves on heroes and spirits only
	# (see `EnemyGroundStrike`), so a mortar aimed at the gate would hit nothing
	# at all - a siege breed would quietly stop being able to besiege.
	# **A shot is chosen for its look whatever it is aimed at, and only its
	# *kind* falls back.** An area blow resolves on heroes and their spirits
	# alone (see `EnemyGroundStrike`), so a mortar aimed at the gate would hit
	# nothing and a siege breed would quietly stop being able to besiege -
	# that fallback is right and stays. What was wrong is that the *painting*
	# fell back with it: every breed in the game threw the roster's plain
	# unpainted rune at the wall, which is the owner's report of 2026-09-22
	# that "they all attack the base using the same projectile".
	var at_a_person: bool = _target is Hero or _target is Companion
	var chosen: EnemyShotData = _choose_a_shot()
	var shot: int = data.shot
	if chosen != null:
		shot = int(chosen.kind)
	if not at_a_person:
		shot = EnemyData.Shot.BOLT
	_shot_paint = chosen
	# Said out loud with the shot's name, so a guest can draw the blow it is
	# not simulating in the breed's own head and colours.
	if net_id != 0 and _target != null and is_instance_valid(_target):
		EventBus.enemy_struck.emit(net_id, _target.global_position,
			chosen.id if chosen != null else "")
	_loose_by_kind(shot, damage)


## **One named shot, thrown for real** - the seam `enemy_shot_check` walks
## every breed's repertoire through, so that each shot a breed owns is fired
## at a body and read back rather than trusted from its file. The same
## dispatch `_loose_a_shot` uses, minus the draw; false if the breed does not
## own a shot by that name. At a wall or a tower it throws a bolt, as the
## ordinary path does - an area blow resolves on people.
func loose_named_shot(id: String, damage: float) -> bool:
	if data == null or _field == null:
		return false
	var chosen: EnemyShotData = _shot_named(id)
	if chosen == null:
		return false
	var at_a_person: bool = _target is Hero or _target is Companion
	_shot_paint = chosen
	_loose_by_kind(int(chosen.kind) if at_a_person else EnemyData.Shot.BOLT, damage)
	return true


func _loose_by_kind(shot: int, damage: float) -> void:
	match shot:
		EnemyData.Shot.SPRAY:
			_loose_a_fan(damage)
		EnemyData.Shot.LOB:
			_mark_the_ground(damage)
		EnemyData.Shot.LANCE:
			_level_a_lance(damage)
		EnemyData.Shot.HEX:
			_loose_a_hex(damage)
		_:
			_loose_a_bolt(damage, _target, EnemyProjectile.Kind.BOLT)


## **Which of the things it knows how to throw, this time.**
##
## Weighted rather than gated: a shot is favoured inside its own band and still
## possible outside it. A band that decided absolutely would make a breed a
## state machine the player reads off a tape measure, and the owner asked for
## the choice to be random *and* range-dependent, which is both halves of this.
##
## Drawn from the battlefield's own stream rather than a seeded one: which shot
## a body throws is not something a replay has to reproduce, and putting it on a
## named stream would move every roll made after it (see `decoration needs its
## own RNG stream`).
func _choose_a_shot() -> EnemyShotData:
	var known: Array[EnemyShotData] = data.repertoire()
	if known.is_empty() or _target == null or not is_instance_valid(_target):
		return null
	var gap: float = global_position.distance_to(_target.global_position)
	var total: float = 0.0
	for entry: EnemyShotData in known:
		if entry != null:
			total += maxf(entry.draw_weight(gap), 0.0)
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for entry: EnemyShotData in known:
		if entry == null:
			continue
		roll -= maxf(entry.draw_weight(gap), 0.0)
		if roll <= 0.0:
			return entry
	return known[known.size() - 1]


## One shot, committed at release. What every ranged breed did before this.
func _loose_a_bolt(damage: float, at: Node2D, kind: int) -> EnemyProjectile:
	var shot := load("res://scenes/battlefield/enemy_projectile.gd").new() as EnemyProjectile
	shot.kind = kind
	_paint(shot)
	shot.configure(at, damage, combat_origin())
	_field.add_child(shot)
	return shot


## **A shot wears what its file says**, and nothing else. The projectile is
## drawn from these numbers rather than from art, so painting a breed's own
## bolt costs no sprite; one function so a bolt, a fan and a boss volley
## cannot dress differently from the same file.
func _paint(shot: EnemyProjectile) -> void:
	if _shot_paint == null:
		return
	if _shot_paint.has_tint():
		shot.tint = _shot_paint.tint
		shot.core_tint = _shot_paint.core_tint if _shot_paint.core_tint.a > 0.0 \
			else _shot_paint.tint
		shot.shell_tint = _shot_paint.shell_tint if _shot_paint.shell_tint.a > 0.0 \
			else _shot_paint.tint.darkened(0.72)
	shot.head = int(_shot_paint.head)
	shot.head_scale = _shot_paint.head_scale
	shot.spin = _shot_paint.spin
	shot.wobble = _shot_paint.wobble
	shot.trail_scale = _shot_paint.trail_scale
	shot.pace_scale = _shot_paint.pace


## A fan. The strike is **divided** between the shots rather than fired once
## each, so standing in the middle of one costs exactly what a bolt costs and
## the fan is about position rather than about damage.
func _loose_a_fan(damage: float) -> void:
	var shots: int = maxi(Balance.ENEMY_SHOT_SPRAY_SHOTS, 1)
	var share: float = damage / float(shots)
	var aim: Vector2 = (_combat_point(_target) - combat_origin()).normalized()
	var span: float = Balance.ENEMY_SHOT_SPRAY_SPREAD
	for index: int in shots:
		var offset: float = 0.0 if shots <= 1 \
			else (float(index) / float(shots - 1) - 0.5) * 2.0 * span
		var shot := load("res://scenes/battlefield/enemy_projectile.gd").new() as EnemyProjectile
		shot.kind = EnemyProjectile.Kind.SPRAY
		_paint(shot)
		# Aimed at a *point* rather than at the body: three shots that all
		# homed on one target would be one shot drawn three times.
		shot.configure_toward(combat_origin() + aim.rotated(offset) * _throw_range(),
			combat_origin())
		shot.set("_damage", share)
		shot.set("_target", _target)
		_field.add_child(shot)


## A mortar on the ground where the target is standing *now*. The delay is the
## dodge, and the circle is drawn at the radius the blow will actually use.
func _mark_the_ground(damage: float) -> void:
	var blow := EnemyGroundStrike.new()
	blow.shape = EnemyGroundStrike.Shape.CIRCLE
	blow.damage = damage
	# The shot's own numbers when it authors them, the kind's when it does not.
	# Four shots were painted and sized on 2026-09-14 and none of it reached the
	# screen, because this read three global constants instead.
	blow.delay = _shot_number(
		func(s: EnemyShotData) -> float: return s.tell_delay,
		Balance.ENEMY_SHOT_LOB_DELAY)
	blow.reach = _shot_number(
		func(s: EnemyShotData) -> float: return s.blast_radius,
		Balance.ENEMY_SHOT_LOB_RADIUS)
	blow.tint = _shot_tint(Balance.ENEMY_SHOT_LOB_TINT)
	blow.blamed_on = promoted_name()
	# On the ground under the target, not at its chest: `strike_the_players`
	# measures from a body's feet, which is where a body stands.
	blow.global_position = _target.global_position
	_field.add_child(blow)


## A line out of the thrower, struck along its whole length after a tell.
func _level_a_lance(damage: float) -> void:
	var blow := EnemyGroundStrike.new()
	blow.shape = EnemyGroundStrike.Shape.LINE
	blow.damage = damage
	blow.delay = _shot_number(
		func(s: EnemyShotData) -> float: return s.tell_delay,
		Balance.ENEMY_SHOT_LANCE_DELAY)
	blow.reach = _shot_number(
		func(s: EnemyShotData) -> float: return s.blast_radius,
		Balance.ENEMY_SHOT_LANCE_RANGE)
	blow.half_width = Balance.ENEMY_SHOT_LANCE_HALF_WIDTH
	blow.tint = _shot_tint(Balance.ENEMY_SHOT_LANCE_TINT)
	# Ground to ground. Drawn from the chests it would run a body's height above
	# the floor, and `strike_the_players` measures feet - so the first cut of
	# this struck nobody at all and the gate said so.
	blow.aim = (_target.global_position - global_position).normalized()
	blow.blamed_on = promoted_name()
	blow.global_position = global_position
	_field.add_child(blow)


## Slow, and it follows. Less damage than a bolt, and it takes mana with it.
func _loose_a_hex(damage: float) -> void:
	var shot: EnemyProjectile = _loose_a_bolt(
		damage * Balance.ENEMY_SHOT_HEX_DAMAGE_SHARE, _target, EnemyProjectile.Kind.HEX)
	shot.mana_burn = damage * Balance.ENEMY_SHOT_HEX_MANA_SHARE


## Where a target's body actually is, for aiming at the ground under it.
func _combat_point(at: Node2D) -> Vector2:
	if at == null or not is_instance_valid(at):
		return global_position
	var who := at as Hero
	return who.combat_origin() if who != null and who.has_method("combat_origin") \
		else at.global_position


## How far this breed throws, for a shot that needs a distance rather than a
## body - a fan aims at points, not at people.
func _throw_range() -> float:
	return data.shot_range if data != null and data.shot_range > 0.0 else attack_reach()


## One authored number off the shot being thrown, or the kind's default.
##
## The shot is only consulted when it actually said something: zero means "as
## every shot of this kind behaves", so a breed that authors nothing is
## untouched and nothing in the curve moves.
func _shot_number(pick: Callable, fallback: float) -> float:
	if _shot_paint == null:
		return fallback
	var authored: float = float(pick.call(_shot_paint))
	return authored if authored > 0.0 else fallback


## The colour this shot flies and lands in.
func _shot_tint(fallback: Color) -> Color:
	if _shot_paint != null and _shot_paint.has_tint():
		return _shot_paint.tint
	return fallback


## A ranged body's blow is lighter again than a melee one (owner, 2026-09-22:
## "especially ranged ones") - it lands from where the Warden cannot answer it.
func _ranged_share() -> float:
	if data != null and data.role == EnemyData.Role.HOWLER:
		return Balance.ENEMY_RANGED_DAMAGE_SCALE
	return 1.0


## **Some bodies step out of a swing** (owner, 2026-09-22: "some enemies may also
## defend and attempt to dodge the players attacks by trying to defensively move
## out of the way before continuing including path finding if gone off path").
##
## Heard as the swing *starts*, so it is a read of the wind-up rather than a
## reaction to a blow already landed. A light body, walking or recovering and
## inside the swing's notice, may sidestep - out of the arc and a little back -
## through the same slip the snow uses, which ends on its own clock; the body
## then walks its route from wherever it stood, which is the way back onto the
## road. Never a boss, a camp lord or a body mid-blow, never while braced or
## breaking out, and never twice inside `ENEMY_DODGE_COOLDOWN`.
func _on_hero_swing(_step: int, at: Vector2) -> void:
	if puppet or data == null or _state == State.DYING or _field == null:
		return
	if _state != State.WALKING and _state != State.RECOVER:
		return
	if _dodge_ready > Time.get_ticks_msec() / 1000.0:
		return
	var chance: float = dodge_chance()
	if chance <= 0.0 or global_position.distance_to(at) > Balance.ENEMY_DODGE_NOTICE:
		return
	if _temper.randf() >= chance:
		return
	_dodge_ready = Time.get_ticks_msec() / 1000.0 + Balance.ENEMY_DODGE_COOLDOWN
	var away: Vector2 = global_position - at
	away = away.normalized() if away.length() > 0.01 else Vector2.RIGHT
	var side: Vector2 = away.orthogonal() * (1.0 if _temper.randf() < 0.5 else -1.0)
	var line: Vector2 = (side + away * 0.6).normalized()
	_slip = line * (Balance.ENEMY_DODGE_DISTANCE / maxf(Balance.ENEMY_DODGE_SECONDS, 0.01))
	_slip_left = Balance.ENEMY_DODGE_SECONDS
	if _state == State.RECOVER:
		_enter(State.WALKING, 0.0)
	if animator != null:
		animator.squash(0.9)
	Vfx.dust(global_position, Color(0.55, 0.49, 0.4), 4, 30.0)


## How likely this body is to sidestep a swing: derived from what it already
## declares - a shooter keeps its distance, a light body is nimble, and a boss,
## a camp lord, a plated or stone hide and a shield-bearer stand their ground.
func dodge_chance() -> float:
	if data == null:
		return 0.0
	if data.category == EnemyData.Category.BOSS or data.category == EnemyData.Category.CAMP_LORD:
		return 0.0
	if data.brace_chance > 0.0 or data.hide == EnemyData.Hide.ARMOUR \
			or data.hide == EnemyData.Hide.STONE:
		return 0.0
	if data.role == EnemyData.Role.HOWLER:
		return Balance.ENEMY_DODGE_CHANCE_RANGED
	return Balance.ENEMY_DODGE_CHANCE_LIGHT if data.stagger_tolerance >= 4.0 else 0.0
