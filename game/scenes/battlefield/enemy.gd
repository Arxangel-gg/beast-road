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
var _rest_texture: Texture2D = null

## Advanced by ground covered, never by time, so a chilled or slowed enemy takes
## slower steps rather than moon-walking at full cadence over frozen ground.
var _walk_phase: float = 0.0

## This enemy's own stain material. See `BloodStain`.
var _blood: ShaderMaterial = null
var _blood_tried: bool = false
@export var health_bar: HealthBar
@export var animator: SpriteAnimator

## Set by the spawner before the node enters the tree.
var data: EnemyData = null
var lane: int = 0

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


func _ready() -> void:
	add_to_group(GROUP)
	if data == null or _field == null:
		push_error("Enemy spawned without data or battlefield; setup() must run first.")
		queue_free()
		return

	# The rank and its affixes multiply into the authored number. Applied here
	# rather than after `setup` because the health node is filled on this line -
	# a promotion that arrived a moment later left a champion with a common's
	# hit points and nothing said so.
	health.max_hp = data.max_hp * _hp_scale * _rank_scale().x 		* _affix_product(&"health_scale")
	health.revive()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health_bar.bind(health)
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
	_flash_left = maxf(_flash_left - delta, 0.0)
	_provoked_left = maxf(_provoked_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, Balance.ENEMY_KNOCKBACK_DECAY * delta)

	var before: Vector2 = global_position
	if _freeze_left <= 0.0 and _hitstun_left <= 0.0:
		_tick_state(delta)

	global_position += _knockback * delta
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
	return _speed_scale


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
func strike_remote(at: Vector2) -> void:
	if _state == State.DYING or _field == null or data == null:
		return
	if animator != null:
		animator.punch((at - global_position).normalized(), 1.1)
	if data.role != EnemyData.Role.HOWLER:
		return
	var shot: Node2D = load("res://scenes/battlefield/enemy_projectile.gd").new() as Node2D
	shot.configure_toward(at, combat_origin())
	_field.add_child(shot)


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
			_target = _pick_target()
			if _target != null and _in_reach(_target):
				_enter(State.WINDUP, Balance.ENEMY_ATTACK_WINDUP)
				# Coil before the blow: the tell the player reads.
				animator.squash(Balance.ANIM_HURT_SQUASH * 0.8)
			else:
				_walk(delta)
		State.WINDUP:
			_state_left -= delta
			if _state_left <= 0.0:
				_strike()
				_enter(State.STRIKE, Balance.ENEMY_ATTACK_STRIKE)
				var toward: Vector2 = Vector2.RIGHT
				if _target != null and is_instance_valid(_target):
					toward = (_target.global_position - global_position).normalized()
				animator.punch(toward, 1.1)
		State.STRIKE:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter(State.RECOVER, Balance.ENEMY_ATTACK_RECOVERY)
		State.RECOVER:
			_state_left -= delta
			if _state_left <= 0.0:
				_enter(State.WALKING, 0.0)
		_:
			pass


func _enter(state: State, duration: float) -> void:
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
	var destination: Vector2 = _target.global_position if _target != null else _field.town_position()
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

	_tick_slip(delta, direction)
	var step: Vector2 = (direction * current_speed() + _slip) * delta
	var wanted: Vector2 = global_position + step
	if _field.step_is_legal(global_position, wanted):
		global_position = wanted
		return

	# Blocked by a cliff. Slide along it rather than stopping dead: an enemy that
	# freezes at the foot of an island reads as broken, while one that runs along
	# the face looking for the ramp reads as a siege - which is the behaviour the
	# ramp exists to produce.
	for sideways: Vector2 in [Vector2(step.y, -step.x), Vector2(-step.y, step.x)]:
		var slide: Vector2 = global_position + sideways
		if _field.step_is_legal(global_position, slide):
			global_position = slide
			return


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
		return (_field.town_position() - global_position).normalized()

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
		return (_field.town_position() - global_position).normalized()

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
	var speed: float = data.move_speed * _speed_scale * _slow_factor
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
	var animal: Node2D = _biting_back()
	if animal != null:
		return animal
	var taunt: Node2D = _field.taunting_tower_in_lane(lane)
	if taunt != null and is_instance_valid(taunt):
		return taunt
	if data.targets_towers:
		var structure: Node2D = _field.vulnerable_tower_in_lane(lane, global_position)
		if structure != null and is_instance_valid(structure):
			return structure
	# The *nearest* hero, not this machine's own. Asking for the local one made
	# every enemy in a two-player game walk past the guest as though they were
	# not there - no aggro, no melee, no ranged fire, and therefore no damage.
	var hero: Node2D = _field.nearest_hero(global_position)
	var town: Node2D = _field.town_node()
	# A barricade is not chosen over the hero: a wall does not distract somebody
	# already in a fight. It is chosen over the *town*, because it is the thing
	# physically in the way of getting there.
	var wall: Node2D = _field.blocking_barricade_ahead(global_position,
		_road_direction())
	if hero != null and is_instance_valid(hero) and _field.hero_is_alive():
		# With no town to march on — the raid arena — the hero is the only
		# objective there is, at any distance.
		if town == null or global_position.distance_to(hero.global_position) <= Balance.ENEMY_HERO_AGGRO_RANGE:
			return hero
	if wall != null and is_instance_valid(wall):
		return wall
	return town


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
		return Balance.ENEMY_ATTACK_RANGE + contact_radius()
	var authored: float = data.aura_radius
	return (authored if authored > 0.0 else Balance.ENEMY_RANGED_RANGE) 		+ contact_radius()


## Whether the ring touches the target.
##
## Measured body-to-surface: from this one's centre - not its feet, which is
## where the node has sat since depth sorting moved it - to the nearest point of
## the target. A big target is in reach when the circle reaches its edge, which
## is what the circle looks like it means.
func _in_reach(target: Node2D) -> bool:
	var gap: float = combat_origin().distance_to(target.global_position) 		- _field.target_radius(target)
	return gap <= attack_reach()


func _strike() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	# Re-checked at the moment of the blow, slightly generously: stepping out
	# during the wind-up is supposed to work, but not by a single pixel.
	var gap: float = combat_origin().distance_to(_target.global_position) \
		- _field.target_radius(_target)
	if gap > attack_reach() * 1.15:
		return
	# An animal has no Health node - the wildlife system owns those numbers - so
	# the blow is handed back to whoever owns it rather than applied here.
	if _provoker_source != null and _target == _provoker:
		var bite: float = data.contact_damage * _damage_scale
		if _provoker_source.call("wound_sprite", _target, bite):
			Vfx.spark(_target.global_position, Color("c4552e"), 6,
				(_target.global_position - global_position).normalized(), 190.0)
		return
	var target_health: Health = Health.of(_target)
	if target_health == null:
		return
	# Rolled, like a tower's shot. A blow that lands for the same number every
	# time reads as arithmetic; the average is unchanged, so nothing balanced
	# against it moves.
	var damage: float = TowerData.roll_damage(
		data.contact_damage * _damage_scale * _rank_scale().y
			* _affix_product(&"damage_scale"), RunState.rng("combat"))
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
	# Said out loud, so a guest can draw the blow it is not simulating. A puppet
	# never runs this function, so without the announcement a ranged enemy on the
	# other screen hurt people from across the field with nothing in between.
	if net_id != 0:
		EventBus.enemy_struck.emit(net_id, _target.global_position)
	if data.role == EnemyData.Role.HOWLER:
		var shot: Node2D = load("res://scenes/battlefield/enemy_projectile.gd").new() as Node2D
		shot.configure(_target, damage, combat_origin())
		_field.add_child(shot)
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


func contact_radius() -> float:
	return data.body_radius if data != null else Balance.ENEMY_BODY_RADIUS


func is_dying() -> bool:
	return _state == State.DYING


## True while the wind-up tell is showing — the window the player is meant to
## react to.
func is_telegraphing() -> bool:
	return _state == State.WINDUP


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
func take_damage(amount: float, from: Vector2, knockback: float,
		active_hero: bool = false) -> bool:
	if _state == State.DYING or data == null or puppet:
		return false
	var was_telegraphing: bool = _state == State.WINDUP
	var incoming: float = amount
	if RunState.enemies_are_weakened():
		incoming /= Balance.WEAKENED_STAT_SCALE
	# Ironhide and its kind. The *best* share rather than the product, because
	# two sources multiplying would approach immunity, and an enemy nothing can
	# hurt is not an affix, it is a wall.
	incoming *= 1.0 - _affix_best(&"damage_resistance")
	if not health.take_damage(incoming, from):
		return false
	var attack_node: DisciplineNodeData = RunState.discipline_node_in_slot(0) \
		if active_hero else null
	if attack_node != null and attack_node.effect_id == "bleed_finisher":
		# The finisher is the only hit whose authored base damage reaches the last
		# chain value. Apply a bounded three-second bleed; it uses the shared status
		# path so death rewards and hit accounting remain identical.
		var finisher_damage: float = Balance.HERO_ATTACK_DAMAGE[Balance.HERO_CHAIN_LENGTH - 1] \
			* Modifiers.multiplier(Modifiers.HERO_DAMAGE)
		if amount >= finisher_damage * 0.9:
			apply_burn(amount * attack_node.effect_value, 3.0)
	_add_hitstun(Balance.ENEMY_HITSTUN)
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
	_knockback = away * knockback * (1.0 - data.knockback_resistance)
	# Being hit hard enough interrupts a wind-up. This is what makes attacking
	# into a telegraph a real answer rather than a trade.
	if knockback > 0.0 and _state == State.WINDUP:
		_enter(State.RECOVER, Balance.ENEMY_ATTACK_RECOVERY * 0.5)
	if active_hero:
		var priority: bool = data.category != EnemyData.Category.BREED \
			or data.role == EnemyData.Role.HOWLER or data.role == EnemyData.Role.BURROWER
		EventBus.hero_enemy_hit.emit(data.id, lane, priority,
			was_telegraphing and knockback > 0.0, global_position)
	return true


func _on_beast_step(impulse: Vector2, strength: float) -> void:
	if _state == State.DYING or _field is RaidArena:
		return
	var resistance: float = data.knockback_resistance if data != null else 0.0
	_knockback += impulse * strength * (1.0 - resistance) * 0.72
	_add_hitstun(Balance.BEAST_STEP_STUN * strength)
	animator.beast_step(impulse, strength / sqrt(maxf(_mass_for_category(), 1.0)))


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
func _add_hitstun(duration: float) -> void:
	if duration <= 0.0 or _hitstun_refractory > 0.0:
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
	_chill = minf(_chill + amount, 1.0)
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
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = maxf(_burn_left, duration)


func _tick_status(delta: float) -> void:
	_freeze_refractory = maxf(_freeze_refractory - delta, 0.0)
	if _chill_hold > 0.0:
		_chill_hold -= delta
	elif _chill > 0.0:
		_chill = maxf(_chill - Balance.CHILL_DECAY * delta, 0.0)
	_slow_factor = lerpf(1.0, Balance.CHILL_SLOW_FLOOR, _chill)
	if _freeze_left > 0.0:
		_freeze_left -= delta
	if _burn_left > 0.0:
		_burn_left -= delta
		health.take_damage(_burn_dps * delta, global_position)
	if data.hp_regen > 0.0:
		health.heal(data.hp_regen * delta)
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null and terrain.enemy_hp_regen > 0.0:
		health.heal(terrain.enemy_hp_regen * delta)


func _on_damaged(_amount: float, from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	_impact_direction = (global_position - from).normalized()
	BloodStain.strike(_blood, _impact_direction)


## Whatever it leaves behind. Volatile and its kin.
##
## Hurts enemies rather than the hero, which is deliberate: the blast is the
## *player's* problem to stand clear of, and making it friendly fire would turn
## a threat into a tool. It reads as a threat because it kills things.
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
	match rank:
		Rank.CHAMPION:
			spoils *= Balance.CHAMPION_REWARD_SCALE
		Rank.ELITE:
			spoils *= Balance.ELITE_REWARD_SCALE
	RunState.gain_kill_resources(int(round(spoils)))
	_burst_on_death()
	# XP scales with the enemy's health rather than an authored per-enemy number,
	# so an elite is worth more than a runner with no second table to maintain,
	# and act scaling carries the curve forward on its own.
	# The tier's own multiplier on top of the health it already scaled, so a Hell
	# kill is worth more than the same enemy on Normal twice over: once for being
	# tougher, once for the tier being worth running.
	var tier: CampaignTierData = RunState.tier()
	var payout: float = data.max_hp * _hp_scale * Balance.HERO_XP_PER_HP
	RunState.gain_hero_xp(payout * (tier.xp_scale if tier != null else 1.0))
	_drop_loot()
	_drop_gear()
	_drop_blueprint()
	if data.category == EnemyData.Category.ELITE:
		RunState.gain_currency(RunState.STONE, Balance.ELITE_STONE_REWARD)
		if _field != null and _field.has_method("try_spawn_mender_spark"):
			_field.try_spawn_mender_spark(global_position)
	if oath_pursuer:
		RunState.mark_last_scar_pursuer_defeated()
		Vfx.ring(global_position, 154.0, Color(0.96, 0.36, 0.28, 0.9), 0.72, 8.0)
		Vfx.spark(global_position, Color("ffd0a0"), 28, Vector2.UP, 250.0)
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
	var elite: bool = data.category != EnemyData.Category.BREED
	var chance: float = Balance.LOOT_DROP_CHANCE
	if elite:
		chance = 1.0
	if RunState.rng("combat").randf() > chance:
		return
	var share: float = float(data.resource_value) * Balance.KILL_RESOURCE_SCALE 		* Balance.LOOT_BONUS_SHARE
	if elite:
		share *= Balance.LOOT_ELITE_MULTIPLIER
	var tier: CampaignTierData = RunState.tier()
	if tier != null:
		share *= tier.loot_scale
	var amount: int = maxi(1, int(round(share)))
	var currency: String = RunState.CURRENCIES[
		RunState.rng("combat").randi_range(0, RunState.CURRENCIES.size() - 1)]
	_field.spawn_loot(currency, amount, global_position)


## Gear used to exist only behind a raid chest. The battlefield now has its own
## low-frequency hunt: breeds can surprise, elites are meaningful prospects and
## bosses always leave a piece. A separate deterministic stream means adding a
## cosmetic spark or changing attack variance cannot rewrite the stash reward.
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


func _tick_death(delta: float) -> void:
	_death_left -= delta
	if _death_left <= 0.0:
		queue_free()
		return
	var t: float = _death_left / Balance.ENEMY_DEATH_FADE
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
		health_bar.position.y = -float(sprite.texture.get_height()) * visual_scale * 0.92


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


func _build_aura_readout() -> void:
	if data.aura_radius <= 0.0:
		return
	var ring := Line2D.new()
	# **Centred on the body, not the feet.** Depth sorting moved the node down to
	# the ground contact point; a ring drawn at local zero since then has sat a
	# sprite-height below the thing it describes.
	var centre := Vector2(0.0, -_depth_lift)
	# The radius is the reach, so the circle and the rule are the same number.
	var shown: float = attack_reach() if data.role == EnemyData.Role.HOWLER 		else data.aura_radius
	var points: PackedVector2Array = []
	for i: int in 49:
		points.append(centre + Vector2.RIGHT.rotated(TAU * float(i) / 48.0) * shown)
	ring.points = points
	ring.width = 2.0
	ring.default_color = Color(0.95, 0.42, 0.22, 0.22)
	ring.z_index = -1
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
	if _state == State.WALKING and absf(_motion.x) > Balance.FACING_DEADZONE:
		sprite.flip_h = _motion.x < 0.0
	elif _target != null and is_instance_valid(_target):
		sprite.flip_h = _target.global_position.x < global_position.x

	_advance_walk_frames(delta)

	var tint: Color = Color.WHITE
	if _freeze_left > 0.0:
		tint = Color(0.55, 0.80, 1.0)
	elif _chill > 0.02:
		# Deepens with the meter rather than being on or off, so a player can see
		# a shatter building and read a second frost tower as doing something.
		tint = Color.WHITE.lerp(Color(0.62, 0.84, 1.0), _chill)
	if _burn_left > 0.0:
		tint = tint.lerp(Color(1.0, 0.55, 0.25), 0.5)
	# The wind-up tell overrides every other tint, because it is the one the
	# player has to read.
	if _state == State.WINDUP:
		var pulse: float = 0.5 + 0.5 * sin(_state_left * 34.0)
		tint = Color(1.0, 0.45, 0.35).lerp(Color(1.0, 0.95, 0.7), pulse)
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
## Only WALKING animates. The windup, the strike and the recovery are the frames
## a player reads to decide whether to step back, and a walk cycle playing
## through them would bury the tell - the same reasoning that makes the striking
## sequence outrank everything on the wildlife.
func _advance_walk_frames(delta: float) -> void:
	if _walk_frames.is_empty() or sprite == null:
		return
	var walking: bool = _state == State.WALKING and _freeze_left <= 0.0 \
		and _hitstun_left <= 0.0
	if not walking:
		# Back to the standing pose rather than freezing mid-stride: an enemy
		# stopped with one leg forward reads as a bug, and the windup animation
		# is drawn from the rest pose.
		_walk_phase = 0.0
		if _rest_texture != null:
			sprite.texture = _rest_texture
		return
	_walk_phase += _motion.length() * delta * Balance.ENEMY_WALK_FRAMES_PER_PIXEL
	sprite.texture = _walk_frames[int(_walk_phase) % _walk_frames.size()]
