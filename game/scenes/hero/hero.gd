class_name Hero
extends CharacterBody2D

## The hero (GDD §3.1). Movement, dash, health and death; the attack chain is
## its own state machine in hero_attack.gd.
##
## CharacterBody2D rather than a plain Node2D so the town and towers can become
## solid obstacles without the movement having to be rewritten and re-tuned.
##
## Movement speed is the hero's most valuable stat: the job is reaching the lane
## that is collapsing. Nothing here should ever make the hero feel heavy.

const GROUP: StringName = &"hero"

## Where this hero's intentions come from.
##
## A local player, or a partner over the wire. Defaults to local, so a hero that
## is never told otherwise behaves exactly as it always has - which is every hero
## in a single-player run. See `scripts/components/hero_input.gd`.
var input: HeroInput = null

@export var health: Health
@export var attack: HeroAttack
@export var sprite: Sprite2D
@export var health_bar: HealthBar
@export var spells: SpellCaster
@export var animator: SpriteAnimator

## Eight-direction frame playback. Null-safe throughout: a build with no sheets
## in res://art/hero/ keeps the old static sprite and every transform effect.
@export var frames: HeroAnimator

## The state frames are locked into until it finishes - a swing, a flinch, a
## dash. Movement cannot interrupt these, which is what stops a walk cycle
## cutting an attack in half.
var _locked_state: String = ""

## How far from the origin the hero may roam. Differs per scope — the
## battlefield lane ring and the raid arena are not the same size — so the
## scene that owns the hero sets it. 0 falls back to the Balance default.
@export var bounds_radius: float = 0.0

## Half-extents of a rectangular playable area. Takes precedence over
## `bounds_radius` when either axis is set.
##
## The battlefield is a square map and was being clamped to a circle, so the
## hero could reach 880 units in any direction on a field that runs to 1440 — the
## corners of their own map were simply unreachable, and the further the road
## bent from the axis the less of it they could defend. The raid arena really is
## a circle and still uses the radius.
@export var bounds_extent: Vector2 = Vector2.ZERO

## The scope the hero is standing in. Set by that scope on entry — the hero
## never goes looking up the tree for the thing it happens to be parented to.
var field: EnemyField = null:
	set(value):
		field = value
		if spells != null:
			spells.field = value

var _aim: Vector2 = Vector2.RIGHT

## Which way the hero is *looking*, which is not always where they are aiming.
##
## Walking looks where you are going; standing still looks where the mouse is;
## swinging looks where the swing went, for as long as the swing lasts. Facing
## used to be the aim vector alone, so a hero running east with the cursor
## resting west ran backwards the whole way.
var _facing: Vector2 = Vector2.RIGHT

## Counts down while an attack owns the facing.
var _facing_hold: float = 0.0

var _dash_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT

var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_decay: float = 0.0

var _respawn_left: float = 0.0
var _respawn_fraction: float = Balance.HERO_WOUND_REVIVE_HP
var _flash_left: float = 0.0
var _beast_impulse: Vector2 = Vector2.ZERO
var _beast_stun_left: float = 0.0

## Ash Veil's movement bonus while it lasts.
var _veil_speed_bonus: float = 0.0
var _veil_left: float = 0.0


func _ready() -> void:
	# Local unless something says otherwise, which is every hero in a
	# single-player run and one of the two in co-op. Set before anything else:
	# `_physics_process` asks it on the first frame and a null source there would
	# be a crash in the most-run function in the game.
	if input == null:
		input = LocalHeroInput.new(self)

	# NOT added to the group here. There are two Hero instances - one in the
	# battlefield, one in the raid - and if both join the group then
	# get_first_node_in_group("hero") is a coin flip. That ambiguity is what left
	# the damage vignette stuck red after a raid: the raid hero reported low
	# health, and on return the battlefield hero never re-emitted, so nothing
	# corrected it. The active scope claims its hero explicitly.
	set_active(false)

	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	attack.lunge_requested.connect(_on_lunge_requested)
	health_bar.bind(health)

	# The hero carries the light the player navigates by after dark. It throws no
	# shadows: it sits inside the hero, so the only thing it could shadow is the
	# hero, and a character standing in their own shadow reads as a rendering bug.
	LightKit.add_light(self, Balance.HERO_LIGHT_COLOUR, Balance.HERO_LIGHT_RADIUS,
		Balance.HERO_LIGHT_ENERGY, Balance.HERO_LIGHT_FLICKER)

	# Torches and the town do shadow the hero, though, which is the cue that
	# matters: walking past a lit brazier should swing a streak around behind you.
	ShadowKit.add_contact(self, sprite)
	if sprite != null and sprite.texture != null:
		var half: Vector2 = sprite.texture.get_size() * 0.5
		ShadowKit.add_caster(self, half.x * 0.40, half.y * 0.18,
			Balance.SHADOW_LAYER_UNITS, half.y * 0.40)
	animator.mass = Balance.ANIM_MASS_HERO
	animator.capture_home()
	attack.landed.connect(_on_attack_landed)

	spells.field = field
	spells.blink_requested.connect(_on_blink)
	spells.veil_requested.connect(_on_veil)
	spells.heal_requested.connect(func(amount: float) -> void: health.heal(amount))
	EventBus.relic_socketed.connect(_on_relic_changed)
	EventBus.relic_unsocketed.connect(_on_relic_changed)
	EventBus.boss_defeated.connect(_on_boss_bonus_changed)
	EventBus.construction_completed.connect(_on_construction_completed)
	# Vigour changes the health pool, so the pool has to be rebuilt when a point
	# lands. Without this a player spends into Vigour mid-wave and sees nothing
	# until the next thing that happens to recompute it.
	EventBus.hero_attributes_changed.connect(_apply_permanent_bonuses)
	EventBus.beast_step_landed.connect(_on_beast_step)
	if frames != null and frames.has_frames():
		frames.finished.connect(_on_frames_finished)
		frames.play("idle")

	_apply_permanent_bonuses()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if health.is_dead:
		_tick_respawn(delta)
		return

	_aim = _compute_aim()
	_update_facing(delta)

	var combat_input: bool = can_fight()
	if combat_input and _beast_stun_left <= 0.0 and input.pressed(HeroInput.BUTTON_ATTACK):
		attack.request()
	# Dash is movement, and movement is allowed whenever the hero is on the field.
	# Gating it behind combat meant a player repositioning during Preparation had
	# to walk, which is the one phase where they are most likely to want to cross
	# the map. It still costs its cooldown, so nothing is gained by spamming it.
	if _beast_stun_left <= 0.0 and input.pressed(HeroInput.BUTTON_DASH):
		_try_dash()
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		if combat_input and _beast_stun_left <= 0.0 \
				and input.pressed(HeroInput.spell_button(slot)):
			spells.try_cast(slot, _aim, global_position)

	attack.damage_multiplier = damage_multiplier()
	if combat_input:
		attack.tick(delta, _aim, global_position)
		spells.tick(delta, _aim, global_position)
	else:
		# Preparation is playable traversal and construction time, not ten free
		# seconds of cooldown recovery or a lingering attack/channel state.
		attack.cancel()
		spells.cancel_channel()

	var move_input: Vector2 = _move_input()
	if _dash_left > 0.0:
		velocity = _dash_direction * (Balance.HERO_DASH_DISTANCE / Balance.HERO_DASH_DURATION)
	elif spells.is_channelling():
		velocity = Vector2.ZERO
	else:
		velocity = move_input * move_speed() * attack.move_scale()
	velocity += _lunge_velocity + _beast_impulse

	move_and_slide()

	global_position = _inside_bounds(global_position)

	animator.set_motion(velocity, move_speed(), delta)
	_drive_frames()
	_update_sprite(delta)


## Called by the scope that owns this hero when it becomes, or stops being, the
## active one. Claiming the group makes exactly one hero findable at a time.
func set_active(active: bool) -> void:
	if active:
		if not is_in_group(GROUP):
			add_to_group(GROUP)
		# Re-announce on becoming active. Every listener that tracks health -
		# the vignette, the HUD bar - is edge-driven, so a scope change has to
		# re-assert the current value or they keep showing the other hero's.
		if health != null:
			health.changed.emit(health.current_hp, health.max_hp)
	elif is_in_group(GROUP):
		remove_from_group(GROUP)


## Scope transitions share health through RunState. Raid and battlefield use
## separate Hero nodes, so each active copy must explicitly claim that state.
func sync_from_run_state() -> void:
	var was_dead: bool = health.is_dead
	_apply_permanent_bonuses()
	if was_dead:
		var saved_fraction: float = health.current_hp / health.max_hp \
			if health.max_hp > 0.0 else 1.0
		health.revive(saved_fraction)
		_restore_presence()


## Raid failure is an immediate ejection. The field hero was frozen alive, so
## it needs the same half-health Wound recovery without its normal down timer.
func apply_raid_wound() -> void:
	_respawn_left = 0.0
	RunState.hero_hp = -1.0
	_apply_permanent_bonuses()
	if health.is_dead:
		health.revive(Balance.HERO_WOUND_REVIVE_HP)
	else:
		health.current_hp = health.max_hp * Balance.HERO_WOUND_REVIVE_HP
		health.changed.emit(health.current_hp, health.max_hp)
	health.add_invulnerability(Balance.HERO_RESPAWN_INVULN)
	_restore_presence()


func is_alive() -> bool:
	return not health.is_dead


## Whether this hero may swing and cast right now.
##
## Read from `RunState`, which both heroes share, so the phase binds the pair
## identically without either being special-cased. Extracted from
## `_physics_process` so a test can ask the question rather than re-deriving it -
## a duplicated condition is one that drifts, and this one drifting would mean a
## guest able to attack during Preparation, which is a cheat rather than a
## glitch.
func can_fight() -> bool:
	return RunState.is_command_combat() or RunState.phase == RunState.Phase.RAID


func aim_direction() -> Vector2:
	return _aim


## Points this hero, without it having been asked to by any input.
##
## For the partner's hero on a guest, whose aim is a fact received rather than a
## decision made here. Sets `_facing` as well as `_aim`, and holds it briefly, so
## the sprite does not snap back to the walk direction on the very next frame -
## which is the same hold `_update_facing` gives a swing, for the same reason.
func face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	_aim = direction
	_facing = direction
	_facing_hold = Balance.HERO_ATTACK_FACING_HOLD


func contact_radius() -> float:
	return Balance.HERO_BODY_RADIUS


## Base speed after the Sanctum, relics and an active Ash Veil.
## Vigour's share of the health pool.
func _vigour_bonus() -> float:
	var points: int = RunState.attribute(RunState.Attribute.VIGOUR)
	return float(points) * Balance.HERO_VIGOUR_PER_POINT


func move_speed() -> float:
	var sanctum: BuildingData = ContentDB.building("sanctum")
	var bonus: float = 0.0
	if sanctum != null:
		bonus += sanctum.effect_at(RunState.building_tier("sanctum"))
	bonus += Modifiers.value(Modifiers.HERO_SPEED)
	bonus += _veil_speed_bonus
	bonus += float(RunState.attribute(RunState.Attribute.SWIFTNESS)) * Balance.HERO_SWIFTNESS_MOVE_PER_POINT
	return Balance.HERO_MOVE_SPEED * (1.0 + bonus)


## Damage multiplier the attack chain applies to every swing.
func damage_multiplier() -> float:
	var multiplier: float = Modifiers.multiplier(Modifiers.HERO_DAMAGE)
	# Might. Additive with itself and multiplicative with everything else, so a
	# hundred points is a known ceiling rather than something that compounds
	# with relics into a number nobody predicted.
	var might: int = RunState.attribute(RunState.Attribute.MIGHT)
	multiplier *= 1.0 + float(might) * Balance.HERO_MIGHT_PER_POINT
	var attack_node: DisciplineNodeData = RunState.discipline_node_in_slot(0)
	if attack_node != null:
		match attack_node.effect_id:
			"bleed_finisher":
				multiplier *= 1.08
			"defense_radiant_finisher":
				multiplier *= 1.05
			"crowd_finisher_force":
				multiplier *= 1.04
	return multiplier


## Max HP after the Sanctum, relics and boss ascensions.
func _apply_permanent_bonuses() -> void:
	var sanctum: BuildingData = ContentDB.building("sanctum")
	var bonus: float = 0.0
	if sanctum != null:
		bonus += sanctum.effect_at(RunState.building_tier("sanctum"))
	var ascension: float = float(RunState.hero_ascension) * Balance.ASCENSION_STAT_BONUS
	var wound_scale: float = maxf(1.0 - float(RunState.hero_wounds) \
		* Balance.HERO_WOUND_HP_PENALTY, 0.4)
	health.max_hp = (Balance.HERO_MAX_HP + Modifiers.value(Modifiers.HERO_MAX_HP)) \
		* (1.0 + bonus + ascension + _vigour_bonus()) * wound_scale
	if RunState.hero_hp >= 0.0:
		health.current_hp = clampf(RunState.hero_hp, 1.0, health.max_hp)
	else:
		health.current_hp = health.max_hp
	health.changed.emit(health.current_hp, health.max_hp)


func _on_relic_changed(_id: String) -> void:
	_apply_permanent_bonuses()


func _on_boss_bonus_changed(_id: String, _act: int) -> void:
	_apply_permanent_bonuses()


## Holds a point inside whatever shape the scope's playable area is.
func _inside_bounds(at: Vector2) -> Vector2:
	if bounds_extent.x > 0.0 or bounds_extent.y > 0.0:
		return Vector2(
			clampf(at.x, -bounds_extent.x, bounds_extent.x),
			clampf(at.y, -bounds_extent.y, bounds_extent.y))
	return at.limit_length(bounds_radius if bounds_radius > 0.0 else Balance.ARENA_RADIUS)


func _on_construction_completed(id: String, _tier: int) -> void:
	if id == "sanctum":
		_apply_permanent_bonuses()


func _on_blink(to: Vector2) -> void:
	global_position = _inside_bounds(to)
	health.add_invulnerability(Balance.BLINK_IFRAMES)


func _on_veil(duration: float, speed_bonus: float) -> void:
	health.add_invulnerability(duration)
	_veil_speed_bonus = speed_bonus
	_veil_left = duration


## Hands this hero over to a different source of intentions.
##
## The partner's hero is given a `RemoteHeroInput` when it spawns. Nothing else
## about it changes: it walks, swings, dashes, is stunned by the beast's step and
## dies through exactly the same code as the local one. That is the reason for
## the seam — a bug that affects only the partner's hero becomes unlikely rather
## than expected, because there is no second implementation for it to live in.
##
## Passing null restores local control, which is what a partner leaving means.
func use_input(source: HeroInput) -> void:
	input = source if source != null else LocalHeroInput.new(self)


## How fast this hero is getting back up, as a multiple of the normal rate.
##
## One when alone or when the partner is elsewhere; faster while they stand close
## enough to be doing something about it. Reads the battlefield's partner rather
## than caching it, so a partner who leaves mid-revive stops helping.
func _revive_speed() -> float:
	if not Coop.is_networked():
		return 1.0
	var scope := field as Battlefield
	if scope == null:
		return 1.0
	var helper: Hero = scope.partner_hero() if scope.hero == self else scope.hero
	if helper == null or not is_instance_valid(helper) or not helper.is_alive():
		return 1.0
	if global_position.distance_to(helper.global_position) > Balance.COOP_REVIVE_RADIUS:
		return 1.0
	return Balance.COOP_REVIVE_SPEED


## Brings this hero back because the host says it is back.
##
## The host owns when a revival happens; the local respawn timer is what decides
## it there. Here it is simply obeyed, so the two machines never disagree about
## whether somebody is on their feet.
func revive_from_coop() -> void:
	if is_alive():
		return
	_respawn_left = 0.0
	_finish_respawn()


## 0..1, for a cooldown readout in a later stage.
func dash_cooldown_ratio() -> float:
	if Balance.HERO_DASH_COOLDOWN <= 0.0:
		return 0.0
	return _dash_cooldown_left / Balance.HERO_DASH_COOLDOWN


## Movement, from whoever is driving this hero.
##
## The device-juggling that used to live here moved to `LocalHeroInput` intact.
## The hero no longer knows whether a stick, a keyboard or a partner on another
## machine is asking it to walk, and that is the point.
func _move_input() -> Vector2:
	return input.move()


## Where the hero is pointing.
##
## Also delegated. `_aim` is passed in as the fallback so a source with nothing
## to say leaves the hero facing where it already was: a hero that snaps east
## every time a stick centres reads as broken.
## Resolves the three claims on which way the hero looks.
##
## Order matters and is the whole behaviour: an attack outranks movement, and
## movement outranks the cursor. Without the hold an attack thrown behind you is
## visible for a single frame before the walk direction takes the sprite back.
func _update_facing(delta: float) -> void:
	_facing_hold = maxf(_facing_hold - delta, 0.0)
	if attack != null and attack.is_swinging():
		_facing = _aim
		_facing_hold = Balance.HERO_ATTACK_FACING_HOLD
		return
	if _facing_hold > 0.0:
		return
	var moving: Vector2 = _move_input()
	if moving.length() > 0.1:
		_facing = moving.normalized()
		return
	_facing = _aim


func _compute_aim() -> Vector2:
	# Touch first, for the same reason the pad is checked before the mouse: a
	# thumb on the right stick is an explicit statement about where to point, and
	# on a phone the emulated mouse cursor is wherever the last tap happened to
	# land. Movement and attack arrive as ordinary input actions and need no
	# branch here; a direction is not a button, so aim does.
	return input.aim(_aim)


func _tick_timers(delta: float) -> void:
	_dash_left = maxf(_dash_left - delta, 0.0)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_beast_stun_left = maxf(_beast_stun_left - delta, 0.0)
	_beast_impulse = _beast_impulse.move_toward(Vector2.ZERO, 260.0 * delta)
	if _veil_left > 0.0:
		_veil_left = maxf(_veil_left - delta, 0.0)
		if _veil_left <= 0.0:
			_veil_speed_bonus = 0.0
	if _lunge_velocity != Vector2.ZERO:
		_lunge_velocity = _lunge_velocity.move_toward(Vector2.ZERO, _lunge_decay * delta)


func _try_dash() -> void:
	if _dash_cooldown_left > 0.0 or _dash_left > 0.0:
		return
	# Dash where you are steering; fall back to where you are looking, so a
	# standing dash still goes somewhere deliberate.
	var move_input: Vector2 = _move_input()
	_dash_direction = move_input.normalized() if move_input.length() > 0.1 else _aim
	_dash_left = Balance.HERO_DASH_DURATION
	_dash_cooldown_left = Balance.HERO_DASH_COOLDOWN
	health.add_invulnerability(Balance.HERO_DASH_IFRAMES)
	animator.dash(_dash_direction, Balance.HERO_DASH_DURATION)
	_lock_frames("dash")
	_spawn_dash_ghosts()
	EventBus.hero_dashed.emit(Balance.HERO_DASH_IFRAMES)


## Sized so the lunge covers `distance` while decaying linearly to zero over
## HERO_ATTACK_LUNGE_TIME. Tuning the distance is enough; the speed follows.
func _on_attack_landed(chain_step: int, _targets: int, _at: Vector2) -> void:
	# A connecting swing squashes harder than a whiffed one.
	animator.squash(Balance.ANIM_PUNCH_SQUASH * (1.6 if chain_step == 2 else 1.0))


func _on_lunge_requested(direction: Vector2, distance: float) -> void:
	var duration: float = Balance.HERO_ATTACK_LUNGE_TIME
	if duration <= 0.0 or distance <= 0.0:
		return
	var speed: float = 2.0 * distance / duration
	_lunge_velocity = direction * speed
	_lunge_decay = speed / duration
	animator.punch(direction, clampf(distance / 110.0, 0.6, 1.5))
	_lock_frames(_frame_state_for_swing(attack.current_step()))


func _on_damaged(amount: float, from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	animator.impact_frame()
	animator.recoil(from, global_position, 1.0)
	_lock_frames("hurt")
	EventBus.hero_damaged.emit(amount, from)
	EventBus.camera_shake_requested.emit(4.0, 0.18)


func _on_beast_step(impulse: Vector2, strength: float) -> void:
	if field is RaidArena or health.is_dead:
		return
	_beast_impulse += impulse * clampf(strength, 0.0, 1.2)
	_beast_stun_left = maxf(_beast_stun_left, Balance.BEAST_STEP_STUN * strength)
	animator.beast_step(impulse, strength)


func _on_health_changed(current: float, maximum: float) -> void:
	RunState.hero_hp = current
	Modifiers.rebuild()
	EventBus.hero_health_changed.emit(current, maximum)


func _on_died(at: Vector2) -> void:
	if RunState.has_resurrection_draught:
		RunState.has_resurrection_draught = false
		health.revive(Balance.HERO_DRAUGHT_REVIVE_HP)
		health.add_invulnerability(Balance.HERO_RESPAWN_INVULN)
		EventBus.hero_respawned.emit(global_position)
		return
	var wounds: int = RunState.add_wound()
	if wounds >= Balance.HERO_MAX_WOUNDS:
		RunState.hero_deaths += 1
		EventBus.hero_died.emit(at)
		GameDirector.end_run(false)
		return
	_respawn_left = Balance.HERO_RESPAWN_DELAY
	_respawn_fraction = Balance.HERO_WOUND_REVIVE_HP
	_dash_left = 0.0
	_lunge_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	attack.cancel()
	health_bar.visible = false
	# With a death sheet the body collapses on screen and is hidden when the
	# animation ends. Without one it vanishes immediately, as it always did -
	# the respawn timer is eight seconds either way.
	if frames != null and frames.has_state("death"):
		_lock_frames("death")
	else:
		sprite.visible = false
	RunState.hero_deaths += 1
	EventBus.hero_died.emit(at)


func _tick_respawn(delta: float) -> void:
	# A partner standing over you gets you up faster.
	#
	# Deliberately an acceleration of the respawn that already exists rather than
	# a separate downed-and-revived mechanic. The solo rules - the wound, the
	# reduced health, the invulnerability window - are what make dying cost
	# something, and a co-op path that bypassed them would make two players safer
	# than one rather than better than one.
	#
	# So the second player buys *time*, which is the thing that actually hurts
	# during a wave, and buys it only by being there: crossing the field to reach
	# a downed friend is the decision, and it is paid for in a lane going
	# undefended while they do it.
	_respawn_left -= delta * _revive_speed()
	if _respawn_left > 0.0:
		return
	_finish_respawn()


## Getting back up, wherever the decision came from.
##
## Extracted so the co-op path cannot drift from the solo one. A guest told its
## partner is on their feet must come back exactly as it would have on its own -
## same health fraction, same invulnerability window, same announcement - or the
## two machines end up with heroes in different conditions.
func _finish_respawn() -> void:
	global_position = Vector2.ZERO
	RunState.hero_hp = -1.0
	_apply_permanent_bonuses()
	health.revive(_respawn_fraction)
	health.add_invulnerability(Balance.HERO_RESPAWN_INVULN)
	_restore_presence()
	EventBus.hero_respawned.emit(global_position)


func apply_hearthmend() -> void:
	_respawn_left = 0.0
	RunState.hero_hp = -1.0
	_apply_permanent_bonuses()
	if health.is_dead:
		global_position = Vector2.ZERO
		health.revive()
	else:
		health.current_hp = health.max_hp
		health.changed.emit(health.current_hp, health.max_hp)
	_restore_presence()


func _restore_presence() -> void:
	sprite.visible = true
	sprite.modulate = Color.WHITE
	health_bar.visible = true
	# A revive has to release the death sheet as well as the body. Without this
	# the Warden stands back up still holding the last frame of their collapse.
	_locked_state = ""
	if frames != null and frames.has_frames():
		frames.play("idle", true)


## Fading copies of the sprite left along the dash path. Cheap, and the single
## clearest way to make a 0.16s movement read as fast rather than as a teleport.
func _spawn_dash_ghosts() -> void:
	var parent: Node = get_parent()
	if parent == null or sprite.texture == null:
		return
	for i: int in Balance.ANIM_DASH_GHOSTS:
		var ghost := Sprite2D.new()
		# Copy how the sprite is *framed*, not just what texture it uses. Handing a
		# bare Sprite2D an atlas or a spritesheet draws the entire sheet: every
		# frame of every direction, splayed around the hero for a fraction of a
		# second. That is the flicker seen on every dash once the hero became a
		# multi-frame sprite.
		ghost.texture = sprite.texture
		ghost.region_enabled = sprite.region_enabled
		ghost.region_rect = sprite.region_rect
		ghost.hframes = sprite.hframes
		ghost.vframes = sprite.vframes
		ghost.frame = sprite.frame
		ghost.centered = sprite.centered
		ghost.offset = sprite.offset
		ghost.scale = sprite.scale
		ghost.flip_h = sprite.flip_h
		ghost.flip_v = sprite.flip_v
		ghost.global_position = global_position + _dash_direction * (float(i) * 22.0)
		ghost.z_index = -1
		ghost.modulate = Color(0.65, 0.85, 1.0, 0.42 - 0.08 * float(i))
		parent.add_child(ghost)

		var life: float = Balance.ANIM_DASH_GHOST_LIFE
		var tween: Tween = ghost.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "modulate:a", 0.0, life)
		tween.tween_property(ghost, "scale", Vector2.ONE * 0.86, life)
		tween.chain().tween_callback(ghost.queue_free)


func _update_sprite(_delta: float) -> void:
	# Eight authored facings already point the right way. Flipping on top of
	# them mirrors the western rows twice and puts the blade in the wrong hand.
	sprite.flip_h = _facing.x < -0.001 if frames == null or not frames.has_frames() else false

	var tint: Color = Color.WHITE
	if _flash_left > 0.0:
		tint = Balance.HIT_FLASH_COLOUR.lerp(Color.WHITE, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)
	# Blinking is the only cue that i-frames are active, and the dash is the
	# hero's whole defensive game — it has to be unmissable.
	if health.is_invulnerable():
		var phase: float = Time.get_ticks_msec() / 1000.0 * Balance.INVULN_BLINK_RATE
		tint.a = 0.35 + 0.4 * (0.5 + 0.5 * sin(phase * TAU))
	sprite.modulate = tint


# --- Frame animation ---------------------------------------------------------

## Chooses the hero's animation state each frame.
##
## Only movement and idle are decided here. Everything else - swings, the dash,
## a flinch, death - is pushed in by the event that causes it and holds the
## sprite until its sheet finishes, because those are the animations the player
## reads to know what their own character is doing.
##
## Facing comes from the aim vector rather than from velocity, so backing away
## from an enemy keeps the Warden pointed at it. That is what the eight
## directions are for; `sprite.flip_h` stays off when frames are present or the
## western rows would be mirrored twice.
func _drive_frames() -> void:
	if frames == null or not frames.has_frames():
		return
	# The same resolved facing the flip uses. Driving the eight authored rows from
	# the aim vector while the flip followed movement would have the two disagree
	# the moment a player walked one way and pointed another.
	frames.set_facing(_facing)
	if not _locked_state.is_empty():
		return
	var speed: float = velocity.length()
	if speed > 4.0:
		frames.set_speed_scale(speed / maxf(move_speed(), 1.0))
		frames.play("walk")
	else:
		frames.play("idle")


## Plays a state that movement cannot interrupt.
func _lock_frames(state: String) -> void:
	if frames == null or not frames.has_state(state):
		return
	_locked_state = state
	frames.play(state, true)


func _on_frames_finished(state: String) -> void:
	if state == "death":
		sprite.visible = false
	if state == _locked_state:
		_locked_state = ""


## The swing sheets, one per chain step.
##
## Step 1 has two authored variants and picks between them at even odds, so a
## held attack button does not play the identical opening swing every time. The
## chain's own steps 2 and 3 are already distinct, so only the opener repeats
## often enough to need it.
func _frame_state_for_swing(step: int) -> String:
	if step == 0:
		return "attack_1a" if RunState.rng("combat").randf() < 0.5 else "attack_1b"
	return "attack_%d" % (step + 1)
