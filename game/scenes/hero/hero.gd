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

## The *active* hero — exactly one at a time. The camera follows it, the HUD
## describes it, and `set_active` is what claims it.
const GROUP: StringName = &"hero"

## **Every** hero on the field, claimed for life rather than passed around.
##
## The distinction is the whole of co-op being playable. Anything that means
## "this player" wants `GROUP`; anything that means "a person standing there" —
## an enemy choosing whom to hit, a coin deciding where to fly, a rabbit deciding
## whether to bolt — wants this one. Asking the first question when you meant the
## second is how a guest ends up walking through a battle untouched, with the
## loot ignoring them and the wildlife unbothered.
const GROUP_ANY: StringName = &"heroes"


## The closest hero to a point, or null when nobody is within reach.
##
## The answer to "is a person standing there", which is what a torch, a dropped
## key and a chest all actually want to know. Written once because three call
## sites asked it by reaching for `GROUP` - the *player's* hero - and so only
## ever noticed one of four, whichever the active scope had claimed. A guest
## could stand on a raid key and watch it ignore them.
static func nearest_on_field(tree: SceneTree, at: Vector2,
		within: float = INF) -> Hero:
	var best: Hero = null
	var best_distance: float = within
	for node: Node in tree.get_nodes_in_group(GROUP_ANY):
		var who := node as Hero
		if who == null or not is_instance_valid(who) or not who.is_alive():
			continue
		var distance: float = who.global_position.distance_to(at)
		if distance <= best_distance:
			best_distance = distance
			best = who
	return best

## Where this hero's intentions come from.
##
## A local player, or a partner over the wire. Defaults to local, so a hero that
## is never told otherwise behaves exactly as it always has - which is every hero
## in a single-player run. See `scripts/components/hero_input.gd`.
var input: HeroInput = null

@export var health: Health
@export var attack: HeroAttack
@export var sprite: Sprite2D
## The ring a finished set turns at the feet. Presentation; read by nothing.
var _set_aura: SetAura = null

## This hero's own stain material. See `BloodStain`.
var _blood: ShaderMaterial = null
var _blood_tried: bool = false
@export var health_bar: HealthBar
@export var spells: SpellCaster

## The bow, when there is one. Built in code rather than exported from the scene
## because a run starts melee-only and most of them stay that way - a node in
## every hero scene for a weapon most heroes never pick up is a node that has to
## be understood by everyone reading the scene.
var ranged: HeroRanged = null
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
		if ranged != null:
			ranged.field = value
		# The bonded spirit follows the hero between scopes rather than being
		# left on the battlefield when the raid opens.
		_refresh_spirit()

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
var _dash_refused_said: float = 0.0
var _dash_cooldown_left: float = 0.0

## Whether the dash now running has already been paid for by a perfect evade.
##
## One refund per dash. Without it a hero standing in a crowd dodges four blows
## in one window and gets the cooldown back four times over, which is not a
## skill ceiling - it is free dashing for standing in the worst place on the
## field.
var _dash_refunded: bool = false
var _dash_direction: Vector2 = Vector2.RIGHT

## No Ground Given: how long the answered blow stays worth something.
var _guard_left: float = 0.0

## Iron Roar: seconds of armour left. The share it turns away sits on `health`.
var _armor_left: float = 0.0

## Sanguine Guard: the recoverable window opens when the veil ends and closes
## a while after; what is still banked when it closes is taken then.
var _wound_delay_left: float = 0.0
var _wound_left: float = 0.0
var _wound_fraction: float = 0.0

## Mana: what spells draw on. Refills slowly, faster with Focus; carried across
## scopes through RunState like health; full again on a revive.
var mana: float = 0.0
## **SP.** Run-scoped like mana, tied to no attribute, and spent only on
## sprinting. See `Balance.HERO_STAMINA_MAX` for why it is flat.
var stamina: float = Balance.HERO_STAMINA_MAX
var _sprinting: bool = false
## How long the dash button has been held. Past `HERO_SPRINT_HOLD` it is a
## sprint rather than a dash.
var _dash_held: float = 0.0
var _dash_spent: bool = false
## Seconds until the pool starts refilling, and until the next puff of dust.
var _stamina_rest: float = 0.0
var _sprint_dust: float = 0.0
## True while the legs have given out and have not yet clawed back the floor.
var _winded: bool = false
## The last value announced, so the bar is told when it changes and not 60
## times a second.
var _stamina_said: float = -1.0
var _mana_announce_left: float = 0.0

## **Riding** (owner brief, 2026-09-17). What is saddled while the Warden is
## up, null on foot; the bound is written on `MountData` and is one sentence -
## **a mount is movement and nothing else.** Every number below is the mount's
## own, so SP is untouched and nothing here can reach a blow.
var _mount: MountData = null
var _mount_rig: MountRig = null
## Seconds left of getting on. The Warden is already mounted while this runs -
## it is the climb, not a decision that can still be refused - so it may not
## gate anything but the picture.
var _mount_up_left: float = 0.0
## Seconds before another mount is allowed. Without it, holding the key is a
## flicker between two states several times a second.
var _mount_wait: float = 0.0
## The mount's own wind, its rest clock, and whether it has run itself out.
## **Its own, not the Warden's.** A mount drinking from SP would make the pool
## the Warden sprints on a shared resource, which is a coupling nobody asked
## for and the tuning would have to answer for.
var mount_wind: float = 0.0
var _mount_wind_rest: float = 0.0
var _mount_winded: bool = false
var _mount_wind_said: float = -1.0
var _galloping: bool = false
var _mount_dust: float = 0.0
## The last line said about refusing to mount, so it is said once rather than
## sixty times a second while the key is held.
var _mount_refused_said: float = 0.0
## **Which mount a hero that is not this machine's player rides.**
##
## Riding itself needs no wire: the mount key is in the input snapshot, so a
## partner's hero gets on at the same press on every machine. What a machine
## cannot know is *which* horse, because that is the other account's saved
## choice - and `MetaState.saddled_mount()` read for somebody else's Warden
## returns this player's own. So the id travels and the behaviour does not,
## which is the smallest thing that can cross here.
##
## Empty means "this account decides", which is every hero in a solo run and
## this player's own hero in a shared one.
var told_mount: String = ""

var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_decay: float = 0.0
var _attack_recoil_ready: bool = false

var _respawn_left: float = 0.0
var _respawn_fraction: float = Balance.HERO_WOUND_REVIVE_HP

## True while this hero is down and waiting for a partner, in co-op.
##
## Not the same as being dead, and the difference is the whole mechanic: a downed
## hero has taken **no wound** and has **no respawn timer**. The only two ways
## out are a partner reaching them, or both players going down at once - and only
## the second costs the run anything.
var _downed: bool = false

## How far through the revive hold the partner has got, from 0 to 1.
##
## Owned by the host and mirrored to the guest, so both players watch the same
## bar fill. Decays when the partner lets go or walks away: a revive interrupted
## by having to fight is supposed to lose ground.
var _revive_progress: float = 0.0

## Seconds left on Hunter's Pulse. See `move_speed`.
var _pulse_left: float = 0.0

## Where this hero comes back to.
##
## **Two heroes must not share one**, which is what the origin was. A team wipe
## put both players on exactly `Vector2.ZERO`, two bodies of radius 26 occupying
## the same point, and they arrived stuck - reported twice as "locked at origin
## on the city base". `CoopHeroes` assigns one per *role* rather than per
## machine, so the host's hero comes back to the same side of the town on both
## screens.
##
## Defaults to the origin, which is correct for a lone player: there is nothing
## to collide with.
var spawn_point: Vector2 = Vector2.ZERO

## Which seat at the table this hero belongs to, 1 to 4.
##
## **Colour comes from here and from nowhere else**, so a player is the same
## colour on every screen in the party. 1 alone, which is why a solo run is a
## party of one rather than a case with no colour.
## The seat colour leaned into the sprite, composed with everything else that
## writes `modulate`. White when playing alone.
var _tint: Color = Color.WHITE
## The light this hero carries, kept so its colour can follow the seat.
var _light: PointLight2D = null

var party_slot: int = 1:
	set(value):
		party_slot = clampi(value, 1, Balance.COOP_MAX_PLAYERS)
		_apply_party_colour()
var _flash_left: float = 0.0
var _impact_direction: Vector2 = Vector2.UP
## Motion the hero did not ask for: the beast's footfall, and a boss slam.
##
## One field rather than two, because everything that reads it wants the same
## thing - the part of `velocity` that is not the player walking. It is
## subtracted from `own_speed`, from the gait, and from anything else that
## asks what the hero is doing under their own power.
var _shoved: Vector2 = Vector2.ZERO

# --- Swimming (2026-09-12) ---------------------------------------------------
#
# Owner brief: a hero who walks into a pond falls in and swims - slower, no
# weapon, the legs under a band of water - and comes out with a splash. The
# water is asked, not assumed: `Fishing.water_depth_at` is the one place that
# knows where the ponds are, and the hero reads it every frame.

## How deep the water under the feet is, 0 on dry ground.
var _swim_depth: float = 0.0
var _swimming: bool = false
var _swim_ripple_in: float = 0.0
var _swim_cover: SwimCover = null
var _badge: InteractBadge = null
## True from the moment a hero drowns until it stands again.
var _drowned: bool = false
var _beast_stun_left: float = 0.0

## Ash Veil's movement bonus while it lasts.
var _veil_speed_bonus: float = 0.0
var _veil_left: float = 0.0

## Mender's Spark is deliberately interruptible: the heal is strongest when the
## player makes space for it instead of treating it as armour under fire.
var _mender_left: float = 0.0
var _mender_grace_left: float = 0.0
var _depth_lift: float = 0.0

## The line a drawn bow puts in front of the hero. Built once, moved every frame.
var _aim_guide: Line2D = null


## The set this hero is wearing in full, or null. For the gate and the screens.
func worn_set() -> GearSetData:
	return _set_aura.worn_set() if _set_aura != null else null


func _ready() -> void:
	# Local unless something says otherwise, which is every hero in a
	# single-player run and one of the two in co-op. Set before anything else:
	# `_physics_process` asks it on the first frame and a null source there would
	# be a crash in the most-run function in the game.
	if input == null:
		input = LocalHeroInput.new(self)

	# The CharacterBody's position is its feet. Moving the body down while lifting
	# every centre-authored visual/physical part by the same amount preserves the
	# picture and collision in world space, but gives the shared Y sorter the only
	# depth key that is meaningful beside a tree or flower: ground contact.
	_depth_lift = float(HeroAnimator.CELL_H) * sprite.scale.y \
		* Balance.HERO_FEET_ANCHOR if sprite != null else 0.0
	global_position.y += _depth_lift
	if sprite != null:
		sprite.position.y -= _depth_lift
	var body := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body != null:
		body.position.y -= _depth_lift
	if health_bar != null:
		health_bar.position.y -= _depth_lift

	# A finished set turns at the feet. Added here rather than to the scene so a
	# raid's hero and the field's hero each get their own and neither has to be
	# told about equipment: it asks `Modifiers`, which is the one place that
	# knows what is worn.
	_set_aura = SetAura.new()
	add_child(_set_aura)
	_set_aura.position.y = -_depth_lift

	# NOT added to the group here. There are two Hero instances - one in the
	# battlefield, one in the raid - and if both join the group then
	# get_first_node_in_group("hero") is a coin flip. That ambiguity is what left
	# the damage vignette stuck red after a raid: the raid hero reported low
	# health, and on return the battlefield hero never re-emitted, so nothing
	# corrected it. The active scope claims its hero explicitly.
	set_active(false)

	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.evaded.connect(_on_evaded)
	EventBus.enemy_died.connect(_on_enemy_died)
	health.changed.connect(_on_health_changed)
	attack.lunge_requested.connect(_on_lunge_requested)
	# **Not joined here.** Presence is owned by `set_present`, which the scope
	# calls when it becomes the live one. Joining on `_ready` put every scope's
	# hero in play at once - and the raid's hero then stood at the raid's origin,
	# inside the running battlefield, for wildlife to walk over and maul.
	health_bar.bind(health)
	# Built here rather than placed in the scene: it is co-op furniture, it draws
	# nothing at all in a solo run, and adding it in code keeps one hero scene
	# serving both.
	add_child(ReviveBar.new(self))

	# The hero carries the light the player navigates by after dark. It throws no
	# shadows: it sits inside the hero, so the only thing it could shadow is the
	# hero, and a character standing in their own shadow reads as a rendering bug.
	_light = LightKit.add_light(self, Balance.HERO_LIGHT_COLOUR,
		Balance.HERO_LIGHT_RADIUS, Balance.HERO_LIGHT_ENERGY,
		Balance.HERO_LIGHT_FLICKER)
	if _light != null:
		_light.position.y = -_depth_lift
	# The party colour is decided before this existed, so it is applied again now
	# that there is a light to colour.
	_apply_party_colour()

	# **And again whenever the party changes.** The colour was only ever applied
	# when `party_slot` was assigned, which happens once, when the body is made.
	# Everything about how it is drawn depends on how many players there are -
	# the mark and the tint are hidden entirely when playing alone - so a hero
	# who was alone when they spawned stayed uncoloured after somebody joined,
	# and a hero left alone kept a colour that no longer meant anything. That is
	# the whole of "the colours are not reliable".
	var party: CoopParty = Coop.party()
	if party != null and not party.roster_changed.is_connected(_apply_party_colour):
		party.roster_changed.connect(_apply_party_colour)

	# Torches and the town do shadow the hero, though, which is the cue that
	# matters: walking past a lit brazier should swing a streak around behind you.
	ShadowKit.add_contact(self, sprite)
	if sprite != null and sprite.texture != null:
		var half: Vector2 = sprite.texture.get_size() * 0.5
		ShadowKit.add_caster(self, half.x * 0.40, half.y * 0.18,
			Balance.SHADOW_LAYER_UNITS, sprite.position.y + half.y * 0.40)
	animator.mass = Balance.ANIM_MASS_HERO
	animator.capture_home()
	# The water over the legs while swimming. A sibling of the sprite rather
	# than a material on it: the sprite already wears the blood material.
	_swim_cover = SwimCover.new()
	_swim_cover.name = "SwimCover"
	_swim_cover.sprite = sprite
	add_child(_swim_cover)

	# The horse under the rider. Added before anything reads it, and drawn
	# behind the sprite from every angle - see `MountRig`.
	_mount_rig = MountRig.new()
	_mount_rig.rider = sprite
	add_child(_mount_rig)
	# **The symbol that says what can be done here** (owner, 2026-09-16). Only
	# over this machine's own Warden: a partner's prompt is their business, and
	# a badge over an ally would be this screen guessing at another player's
	# reach. `InteractBadge` reads the prompt line and is read by nothing.
	if is_local_player():
		_badge = InteractBadge.new()
		add_child(_badge)
	attack.landed.connect(_on_attack_landed)

	spells.field = field

	ranged = HeroRanged.new()
	ranged.name = "Ranged"
	ranged.hero = self
	ranged.field = field
	ranged.loosed.connect(_on_loosed)
	ranged.dry.connect(func() -> void: EventBus.hero_out_of_ammo.emit())
	add_child(ranged)
	spells.hero = self
	spells.blink_requested.connect(_on_blink)
	# Changing the equipped spirit at the shrine takes effect on the road, not
	# on the next run.
	EventBus.spirit_equipped.connect(func(_key: String) -> void: _refresh_spirit())
	spells.veil_requested.connect(_on_veil)
	spells.heal_requested.connect(func(amount: float) -> void: health.heal(amount))
	# **Wellspring** and **Siphoning Veil**, the two Arcane effects that reach
	# the body rather than the field. Shares rather than numbers, resolved here
	# where the pool and the health are - the caster deliberately does not know
	# how deep either is.
	spells.mana_refunded.connect(func(share: float) -> void:
		mana = minf(mana + mana_max() * share, mana_max())
		EventBus.hero_mana_changed.emit(mana, mana_max()))
	spells.ward_requested.connect(func(share: float) -> void:
		health.add_shield(health.max_hp * share))
	spells.armor_requested.connect(_on_armor_requested)
	spells.wound_guard_requested.connect(_on_wound_guard_requested)
	spells.dash_refund_requested.connect(refund_dash)
	EventBus.fish_eaten.connect(_on_fish_eaten)
	EventBus.fish_given.connect(_on_fish_given)
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
	_build_aim_guide()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if not is_alive():
		_tick_respawn(delta)
		return

	_aim = _compute_aim()
	_update_facing(delta)
	_update_aim_guide()
	_tick_swim(delta)

	# **A swimmer still swings, slowly** (owner, 2026-09-16). This refused
	# combat outright - "no weapon in the water: a swimmer has both hands full
	# staying up" - which is a fair rule for somebody who swam out to a fishing
	# spot and the wrong one for a flood, where the water arrives at a fight that
	# is already happening and the bodies on the road do not stop.
	if attack != null:
		attack.drag = Balance.HERO_SWIM_ATTACK_DRAG if _swimming else 1.0
	# **Before `can_fight` is asked**, because riding is what makes the answer
	# no - and because the owner's rule is that pressing attack *dismounts* and
	# the fight starts where you stood. A press read after the refusal would be
	# a swing thrown away rather than a dismount.
	_tick_mount(delta)

	var combat_input: bool = can_fight()
	if combat_input and _beast_stun_left <= 0.0 and (
			input.pressed(HeroInput.BUTTON_ATTACK)
			or input.held(HeroInput.HOLD_ATTACK)):
		attack.request()
	# Dash is movement, and movement is allowed whenever the hero is on the field.
	# Gating it behind combat meant a player repositioning during Preparation had
	# to walk, which is the one phase where they are most likely to want to cross
	# the map. It still costs its cooldown, so nothing is gained by spamming it.
	if _beast_stun_left <= 0.0 and not _swimming and input.pressed(HeroInput.BUTTON_DASH):
		_try_dash()
	_tick_sprint(delta)
	if ranged != null:
		ranged.tick(delta)
		if input.pressed(HeroInput.BUTTON_AMMO_CYCLE):
			ranged.cycle_ammo()
		# Gated behind the same `can_fight` as the swing: a bow is a weapon, and
		# the phases that forbid fighting forbid all of it.
		if input.pressed(HeroInput.BUTTON_USE_ITEM):
			# Not gated behind `can_fight`. Drinking a tonic is not an attack,
			# and the phases that forbid fighting - Preparation with the build
			# sheet open, a crossroad - are exactly when a player wants to patch
			# themselves up before the next formation arrives.
			use_carried_item()
		if combat_input and _beast_stun_left <= 0.0 				and input.pressed(HeroInput.BUTTON_RANGED):
			# The body, like the swing and the spells beside it. The root is
			# the hero's ground contact for depth sorting, so passing it here
			# loosed every arrow from the Warden's boots.
			ranged.request(_aim, combat_origin())
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		if combat_input and _beast_stun_left <= 0.0 \
				and input.pressed(HeroInput.spell_button(slot)):
			spells.try_cast(slot, _aim, combat_origin())

	attack.damage_multiplier = damage_multiplier()
	if combat_input:
		attack.tick(delta, _aim, combat_origin())
		spells.tick(delta, _aim, combat_origin())
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
		var movement_scale: float = attack.move_scale()
		if input.held(HeroInput.HOLD_ATTACK) and not attack.is_swinging():
			movement_scale *= Balance.TOUCH_AUTOATTACK_MOVE_SCALE
		# Drawing slows the walk. Not a stop - standing still to shoot should be
		# a decision the player feels making, not one the game makes for them.
		if ranged != null:
			movement_scale *= ranged.move_scale()
		if _swimming:
			movement_scale *= Balance.SWIM_SPEED_SCALE
		# **And the wind.** A multiplier at the point of travel rather than a
		# bonus inside `move_speed`, because which way you are going is the
		# whole of it: `move_speed` has no direction and a crosswind costs
		# nothing. Symmetric with every other mover on the field and capped in
		# `RunState.wind_push`; see the note on `Balance.WIND_PUSH_MAX`.
		velocity = move_input * move_speed() * movement_scale \
			* RunState.wind_push(move_input)
	velocity += _lunge_velocity + _shoved

	move_and_slide()

	global_position = _inside_bounds(global_position)

	animator.set_motion(velocity, move_speed(), delta)
	_drive_frames()
	_update_sprite(delta)


## Reads the water under the feet and moves the hero in or out of it.
##
## Hysteresis on the threshold, so a hero standing on a bank does not flicker
## between wading and walking on every ripple of the depth field.
func _tick_swim(delta: float) -> void:
	_tick_poison(delta)
	_tick_meal(delta)
	_swim_depth = 0.0
	if field != null and field.has_method("water_depth_at") and is_in_group(GROUP_ANY):
		_swim_depth = float(field.call("water_depth_at", global_position))
	var wet: bool = _swim_depth >= (Balance.SWIM_THRESHOLD * 0.6 if _swimming else Balance.SWIM_THRESHOLD)
	if wet != _swimming:
		_swimming = wet
		_swim_ripple_in = 0.0
		if _swim_cover != null:
			_swim_cover.visible = wet
			_swim_cover.waterline = Balance.SWIM_WATERLINE
			_swim_cover.field = field
			if wet and field.has_method("water_colour"):
				var colour: Color = field.call("water_colour") as Color
				colour.a = Balance.SWIM_COVER_ALPHA
				_swim_cover.water = colour
		if wet:
			attack.cancel()
			spells.cancel_channel()
			Vfx.sheet_burst(global_position, "res://art/vfx/splash.png", Balance.FISHING_SPLASH_SIZE * 1.3)
			Vfx.sheet_burst(global_position, "res://art/vfx/ripple.png", Balance.FISHING_SPLASH_SIZE * 1.8,
				Color(1.0, 1.0, 1.0, 0.8), true)
			if field.has_method("stir"):
				field.call("stir", global_position, 1.0)
			Sfx.play("sfx_swim_enter")
			EventBus.camera_shake_requested.emit(2.5, 0.12)
		else:
			Vfx.spark(global_position, Color(0.72, 0.86, 0.98), 10, Vector2.UP, 120.0)
			Sfx.play("sfx_swim_exit")
		if is_local_player():
			EventBus.hero_swim_changed.emit(wet)
	if not _swimming:
		return
	# Strokes stir the water while the body moves.
	_swim_ripple_in -= delta
	if _swim_ripple_in <= 0.0 and own_speed() > Balance.FISHING_STILL_SPEED:
		_swim_ripple_in = Balance.SWIM_RIPPLE_INTERVAL
		if field.has_method("stir"):
			field.call("stir", global_position, 0.45)
		Sfx.play("sfx_swim_stroke", -6.0)


## Whether this hero is in the water.
func is_swimming() -> bool:
	return _swimming


## A rabid animal's bite (2026-09-12): damage over time, in small bites, from
## nowhere in particular so it does not knock the hero about.
var _poison_left: float = 0.0
var _poison_dps: float = 0.0
var _poison_tick: float = 0.0


func apply_poison(dps: float, seconds: float) -> void:
	_poison_dps = maxf(_poison_dps, dps)
	_poison_left = maxf(_poison_left, seconds)


func _tick_poison(delta: float) -> void:
	if _poison_left <= 0.0:
		return
	_poison_left -= delta
	_poison_tick -= delta
	if _poison_tick > 0.0:
		return
	_poison_tick = 0.5
	if health != null and is_alive():
		# **The venom says it was the venom.** The bite that delivered it names
		# itself through `Wildlife._strike`, and the poison that finishes the job
		# did not - so a Warden killed by the Wildblight was told they were killed
		# by whatever last touched them, on one of the three deaths in this game a
		# player is least likely to be able to explain.
		RunState.note_blow("The Wildblight", _poison_dps * 0.5)
		health.take_damage(_poison_dps * 0.5, global_position + Vector2.DOWN * 8.0)
		Vfx.spark(global_position + Vector2.UP * 30.0, Balance.WILDLIFE_RABID_AURA, 3, Vector2.UP, 70.0)
	if _poison_left <= 0.0:
		_poison_dps = 0.0


## How deep the water under the hero is, for the readouts.
func swim_depth() -> float:
	return _swim_depth


## Going under. The body sinks beneath the band of water rather than
## collapsing on it: the cover rises to the crown over the drowning time and
## the sprite fades with it.
func _drown(at: Vector2) -> void:
	_drowned = true
	# Drowning takes the hero without a blow, so nothing named it and the debrief
	# reported whatever had last hit them - often several minutes and a region ago.
	RunState.note_blow("Deep water", maxf(health.max_hp, 1.0))
	if _swim_cover != null:
		_swim_cover.visible = true
		var sink: Tween = _swim_cover.create_tween()
		sink.tween_property(_swim_cover, "waterline", 1.05, Balance.DROWN_SECONDS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		sink.tween_callback(func() -> void:
			sprite.visible = false
			_swim_cover.visible = false)
	for _bubble: int in 3:
		Vfx.spark(at + Vector2(randf_range(-10.0, 10.0), -20.0), Color(0.86, 0.94, 1.0), 6,
			Vector2.UP, 90.0)
	if field != null and field.has_method("stir"):
		field.call("stir", at, 1.0)
	Sfx.play("sfx_drown")
	EventBus.hero_drowned.emit(at)


## Called by the scope that owns this hero when it becomes, or stops being, the
## active one. Claiming the group makes exactly one hero findable at a time.
## Whether the world may touch this hero at all.
##
## **`GROUP_ANY` is not "every hero node", it is "every hero in play"**, and the
## difference cost weeks. Both scopes keep their own Hero and both live in the
## tree at once, so the raid arena's hero stood in `GROUP_ANY` at the raid's
## origin for the whole of every battlefield. Wildlife found it, walked to the
## city and mauled it - and any Hero taking damage emits `hero_damaged`, which
## plays the hurt sound and the blood vignette wherever the real hero is.
##
## That is the "invisible thing at the origin that hurts me no matter where I
## am", reported five times. It was a hero in another scope entirely.
##
## Separate from `set_active` because the two questions differ for a partner: a
## co-op partner is emphatically in play and must never claim `GROUP`, which
## answers "whose health does the HUD show".
func set_present(present: bool) -> void:
	if present == is_in_group(GROUP_ANY):
		return
	if present:
		add_to_group(GROUP_ANY)
	else:
		remove_from_group(GROUP_ANY)


func set_active(active: bool) -> void:
	# **Presence is not this question.** `set_active` follows the *phase* - a
	# hero is the active avatar during Preparation and combat and not during a
	# cinematic - while presence follows the *scope*, which is what decides
	# whether the world can touch it at all. Tying them made a hero vanish from
	# the world every time the phase changed.
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
		refill_mana()
		_restore_presence()


## Raid failure is an immediate ejection. The field hero was frozen alive, so
## it needs the same half-health Wound recovery without its normal down timer.
func apply_raid_wound() -> void:
	_respawn_left = 0.0
	RunState.hero_hp = -1.0
	_apply_permanent_bonuses()
	if health.is_dead:
		health.revive(Balance.HERO_WOUND_REVIVE_HP)
		refill_mana()
	else:
		health.current_hp = health.max_hp * Balance.HERO_WOUND_REVIVE_HP
		health.changed.emit(health.current_hp, health.max_hp)
	health.add_invulnerability(Balance.HERO_RESPAWN_INVULN)
	_restore_presence()


## Standing and able to act.
##
## Being *downed* counts as not alive even though the body has not necessarily
## been dealt lethal damage - a hero waiting for a partner is out of the fight in
## every way that matters, and anything that walks, swings or is targeted should
## treat them as gone until somebody gets them up.
func is_alive() -> bool:
	return not health.is_dead and not _downed


## Whether the last collapse was in the water. The death markers ask, because
## a stone over a drowning lands with a splash and leaves no bones.
func is_drowned() -> bool:
	return _drowned


## Whether this hero may swing and cast right now.
##
## Read from `RunState`, which both heroes share, so the phase binds the pair
## identically without either being special-cased. Extracted from
## `_physics_process` so a test can ask the question rather than re-deriving it -
## a duplicated condition is one that drifts.
##
## **Preparation is fightable now, and that is an owner call from play.** The
## phase used to forbid it outright, which was defensible while nothing could
## reach you during it - and then predatory wildlife arrived and a wolf pack
## could open on a hero who was not allowed to swing back. Being mauled while
## holding a hammer is not a design, it is an oversight.
##
## What stops Preparation becoming a free combat round is that there is nothing
## to fight: the phase only opens on a cleared road. What can be there is
## wildlife, which is exactly what the player needs to answer.
##
## The mode is per-player and local. See `GameDirector.build_mode`.
func can_fight() -> bool:
	# **Mounted, you may not fight** (owner, 2026-09-17). Answered first and
	# unconditionally, before any phase is read, because this is the bound that
	# makes a mount safe: it can never touch a number in a fight. The press that
	# asked is not lost - `_tick_mount` has already turned it into a dismount.
	if _mount != null:
		return false
	if RunState.is_command_combat() or RunState.phase == RunState.Phase.RAID:
		return true
	# In a camp or a rift the fight is the whole of the place, whatever phase
	# the road outside is in - a guest raiding alone while the host's road
	# reaches a crossroad must not lose its sword to the host's phase.
	if field is RaidArena:
		return true
	return RunState.is_preparation() and not GameDirector.build_mode


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
## Resolve's share: what a blow is worth when it lands.
##
## Returned as the `damage_scale` a hero stands at when nothing else is
## happening to them, rather than as a bonus, because that is the field Iron
## Roar and the Sanguine Guard already take the *minimum* of. A hero with no
## Resolve stands at exactly 1.0, which is where every hero stood before this.
func _resolve_scale() -> float:
	var points: int = RunState.attribute(RunState.Attribute.RESOLVE)
	var mitigation: float = minf(
		float(points) * Balance.HERO_RESOLVE_MITIGATION_PER_POINT,
		Balance.HERO_RESOLVE_MITIGATION_CAP)
	# **And what the Gatekeeper's ladder bought** (owner ruling, 2026-09-17).
	#
	# Summed inside one `minf` against Resolve's own cap rather than multiplied
	# after it, which is the whole safety of the re-cut: an ascended Warden with
	# maxed Resolve stands at *one* ceiling rather than at the product of two,
	# so the third scale can never take mitigation somewhere the second was
	# already tuned to stop.
	mitigation = minf(mitigation + minf(
		float(MetaState.ascension) * Balance.ASCENSION_MITIGATION_PER_RANK,
		Balance.ASCENSION_MITIGATION_CAP), Balance.HERO_RESOLVE_MITIGATION_CAP)
	return 1.0 - mitigation


## And what a ward given to them is worth.
func _resolve_ward_scale() -> float:
	var points: int = RunState.attribute(RunState.Attribute.RESOLVE)
	return 1.0 + minf(float(points) * Balance.HERO_RESOLVE_WARD_PER_POINT
		+ float(MetaState.ascension) * Balance.ASCENSION_WARD_PER_RANK,
		Balance.HERO_RESOLVE_WARD_CAP)


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
	# **Hunter's Pulse.** "Marked support kills grant a short speed burst."
	# Summed with the others rather than multiplied, so it cannot compound with
	# Swiftness or a relic into a number nobody predicted.
	if _pulse_left > 0.0:
		bonus += DisciplineEffects.trained_value("support_kill_speed")
	bonus += float(RunState.attribute(RunState.Attribute.SWIFTNESS)) * Balance.HERO_SWIFTNESS_MOVE_PER_POINT
	bonus += _meal_speed
	# Wading (2026-09-14). A multiplier rather than a bonus, so it cannot be
	# summed away by Swiftness: water is water whoever is walking through it.
	# A swimmer is already paying the water's price and does not pay it twice.
	# **Riding replaces running rather than stacking with it.** A gallop on top
	# of a sprint would be new speed, which is the third scale this project has
	# refused a dozen times; a gallop *instead of* one is the speed the Warden
	# already had, bought without SP and paid for by being unable to fight.
	# `Balance.MOUNT_SPEED_CEILING` is `HERO_SPRINT_SPEED`, and `mount_check`
	# measures every authored mount against it rather than reading the figure.
	var running: float = Balance.HERO_SPRINT_SPEED if _sprinting else 1.0
	if _mount != null:
		running = minf(_mount.gallop if _galloping else _mount.speed,
			Balance.MOUNT_SPEED_CEILING)
	return Balance.HERO_MOVE_SPEED * (1.0 + bonus) * running \
		* (1.0 if _swimming else RunState.flood_slow())


## Puts the hero's shot in the world.
##
## Parented to the battlefield rather than to the hero, so an arrow already in
## the air is not recalled when its archer dies. The same reasoning the tower
## uses for selling a tower mid-flight.
func _on_loosed(from: Vector2, direction: Vector2, kind: AmmoData) -> void:
	if field == null or ranged == null or not ranged.armed():
		return
	# **A snare is thrown, not shot** (owner, 2026-09-16). Ammunition rather than
	# a new system is what let taming reuse this trigger, this aim, the cycle
	# button and the counts - the pad had no button left to give it.
	if kind.snares:
		_throw_a_snare(from, direction)
	else:
		var arrow := HeroArrow.new()
		arrow.launch(field, from + direction * Balance.HERO_ARROW_MUZZLE, direction,
			ranged.weapon(), kind, damage_multiplier())
		field.add_child(arrow)
	_facing = direction
	_facing_hold = Balance.HERO_ATTACK_FACING_HOLD
	# Locked like a sword swing, for the same reason: the loose has to survive
	# the player still walking. `_lock_frames` answers to `has_state`, so a build
	# without the sheet keeps whatever it was already showing rather than
	# blanking - which is how the whole ranged system shipped before this frame
	# art existed.
	_lock_frames("shoot")
	EventBus.hero_loosed.emit(from, direction, kind.id)


## **The rope, aimed at the nearest animal in the throw's cone.**
##
## Aimed at an *animal* rather than flying straight, because a rope is thrown at
## something rather than in a direction - and because nothing else in the game
## answers to a lasso, a throw with no animal in front of it is simply a rope on
## the ground rather than a refusal the player has to decode.
func _throw_a_snare(from: Vector2, direction: Vector2) -> void:
	var rope := Lasso.new()
	rope.field = field
	rope.thrower = self
	var quarry: Node2D = _animal_in_front(from, direction)
	rope.target_id = quarry.get_instance_id() if quarry != null else 0
	field.add_child(rope)
	rope.throw_from(from + direction * Balance.HERO_ARROW_MUZZLE, direction)


## The animal nearest the line of the throw, inside the rope's reach and roughly
## in front. Generous on angle: a rope is aimed by hand and the player is running.
func _animal_in_front(from: Vector2, direction: Vector2) -> Node2D:
	var best: Node2D = null
	var nearest: float = Balance.LASSO_RANGE
	var animals: Node = field.call("wildlife") if field != null 		and field.has_method("wildlife") else null
	if animals == null or not animals.has_method("living_sprites"):
		return null
	for node: Node in animals.call("living_sprites") as Array[Node2D]:
		if node == null or not is_instance_valid(node):
			continue
		var toward: Vector2 = node.global_position - from
		var away: float = toward.length()
		if away > nearest or away < 1.0:
			continue
		if direction.dot(toward / away) < Balance.LASSO_AIM_COS:
			continue
		nearest = away
		best = node
	return best


## Damage multiplier the attack chain applies to every swing.
func damage_multiplier() -> float:
	var multiplier: float = Modifiers.multiplier(Modifiers.HERO_DAMAGE) * (1.0 + _meal_damage)
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
	# **No Ground Given**, spent on the finisher and on nothing else. Asked here
	# rather than applied at the evade, so the bonus rides the swing the card
	# names rather than whatever the hero happened to do next.
	if _guard_left > 0.0 and attack != null \
			and attack.current_step() >= Balance.HERO_CHAIN_LENGTH - 1:
		multiplier *= 1.0 + DisciplineEffects.trained_value("block_finisher")
	return multiplier


## Max HP after the Sanctum, relics and boss ascensions.
func _apply_permanent_bonuses() -> void:
	var sanctum: BuildingData = ContentDB.building("sanctum")
	var bonus: float = 0.0
	if sanctum != null:
		bonus += sanctum.effect_at(RunState.building_tier("sanctum"))
	var felled: float = float(RunState.bosses_felled) * Balance.BOSS_FELLED_VIGOUR
	var wound_scale: float = maxf(1.0 - float(RunState.hero_wounds) \
		* Balance.HERO_WOUND_HP_PENALTY, 0.4)
	health.max_hp = (Balance.HERO_MAX_HP + Modifiers.value(Modifiers.HERO_MAX_HP)) \
		* (1.0 + bonus + felled + _vigour_bonus()) * wound_scale
	if RunState.hero_hp >= 0.0:
		health.current_hp = clampf(RunState.hero_hp, 1.0, health.max_hp)
	else:
		health.current_hp = health.max_hp
	health.changed.emit(health.current_hp, health.max_hp)
	# Resolve, re-read here because this is the one function every source of
	# permanent hero power already flows through - a level, a socket, a piece of
	# gear, a wound. `maxf` against any armour currently running, so re-reading
	# it in the middle of an Iron Roar does not cancel the Roar.
	health.damage_scale = minf(health.damage_scale, _resolve_scale()) \
		if _armor_left > 0.0 else _resolve_scale()
	health.shield_scale = _resolve_ward_scale()
	# Mana comes back the same way health does: what the last scope left, or
	# full when there was no last scope.
	mana = clampf(RunState.hero_mana, 0.0, mana_max()) if RunState.hero_mana >= 0.0 else mana_max()
	EventBus.hero_mana_changed.emit(mana, mana_max())


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


## The pool's size and refill, both deepened by Focus.
func mana_max() -> float:
	return Balance.HERO_MANA_BASE \
		+ float(RunState.attribute(RunState.Attribute.FOCUS)) * Balance.HERO_MANA_PER_FOCUS


func mana_regen() -> float:
	return Balance.HERO_MANA_REGEN \
		+ float(RunState.attribute(RunState.Attribute.FOCUS)) * Balance.HERO_MANA_REGEN_PER_FOCUS


## Pays for a cast. False, and nothing spent, when the pool cannot cover it.
## **Mana taken rather than spent.**
##
## `spend_mana` refuses when the pool is short, because a spell either casts or
## does not. Being robbed is the other thing: it takes what is there and leaves
## the pool empty, which is what a hex - and now a mark - does to a caster.
##
## Worth nothing at all to a swordhand, which is the point of it: it is the one
## threat in the game whose weight depends on who the player decided to be.
func burn_mana(amount: float) -> void:
	if amount <= 0.0 or mana <= 0.0:
		return
	mana = maxf(mana - amount, 0.0)
	RunState.hero_mana = mana
	EventBus.hero_mana_changed.emit(mana, mana_max())


func spend_mana(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if mana < cost:
		return false
	mana -= cost
	RunState.hero_mana = mana
	EventBus.hero_mana_changed.emit(mana, mana_max())
	return true


## Full again. A revive, a hearthmend - the moments health comes back whole.
func refill_mana() -> void:
	mana = mana_max()
	RunState.hero_mana = mana
	EventBus.hero_mana_changed.emit(mana, mana_max())


func _tick_mana(delta: float) -> void:
	if health == null or health.is_dead:
		return
	var cap: float = mana_max()
	if mana < cap:
		mana = minf(mana + mana_regen() * delta, cap)
		RunState.hero_mana = mana
	# The HUD is told a few times a second rather than every frame; a bar
	# cannot show sixty updates a second and the bus does not need them.
	_mana_announce_left -= delta
	if _mana_announce_left <= 0.0:
		_mana_announce_left = 0.1
		EventBus.hero_mana_changed.emit(mana, cap)


func _on_veil(duration: float, speed_bonus: float) -> void:
	health.add_invulnerability(duration)
	_veil_speed_bonus = speed_bonus
	_veil_left = duration


## Iron Roar. Armour is a share of harm turned away, applied on `health` where
## every blow already passes, and timed here where the hero's clocks live.
func _on_armor_requested(fraction: float, seconds: float) -> void:
	if health == null or seconds <= 0.0:
		return
	_armor_left = maxf(_armor_left, seconds)
	health.damage_scale = minf(health.damage_scale, 1.0 - clampf(fraction, 0.0, 0.9))


## Sanguine Guard. Opens after `delay` - the veil, during which nothing lands
## anyway - and stays open for `seconds`.
func _on_wound_guard_requested(fraction: float, delay: float, seconds: float) -> void:
	if health == null or seconds <= 0.0:
		return
	_wound_fraction = clampf(fraction, 0.0, 1.0)
	_wound_left = seconds
	_wound_delay_left = maxf(delay, 0.0)
	if _wound_delay_left <= 0.0:
		health.deferred_fraction = _wound_fraction


## A fish was eaten. Restores whatever it carried, as fractions of this hero's
## own maximums - so a meal is worth the same share of a fresh hero as of a
## wounded one, and never a flat number the curve would have to be retuned for.
##
## The partner does not eat this one: a fish comes out of one account's pantry
## and feeds the person who kept it.
## A meal's lingering buff: seconds left, and what it is worth.
##
## The rarer the fish the longer and stronger (owner brief, 2026-09-13). Held
## here rather than in `Modifiers` because it is a *meal*, not a relic: it
## belongs to this body for this while, and a co-op partner who was handed the
## fish carries their own.
var _meal_left: float = 0.0
var _meal_damage: float = 0.0
var _meal_speed: float = 0.0


## Whatever the fish was worth, for however long its rarity buys.
func take_meal_buff(kind: FishData) -> void:
	if kind == null:
		return
	var tier: int = clampi(int(kind.rarity), 0, Balance.FISH_BUFF_SECONDS.size() - 1)
	_meal_left = maxf(_meal_left, Balance.FISH_BUFF_SECONDS[tier])
	_meal_damage = maxf(_meal_damage, Balance.FISH_BUFF_DAMAGE[tier])
	_meal_speed = maxf(_meal_speed, Balance.FISH_BUFF_SPEED[tier])


func _tick_meal(delta: float) -> void:
	if _meal_left <= 0.0:
		return
	_meal_left = maxf(_meal_left - delta, 0.0)
	if _meal_left <= 0.0:
		_meal_damage = 0.0
		_meal_speed = 0.0


func _on_fish_eaten(fish_id: String) -> void:
	if health == null or health.is_dead or not is_local_player():
		return
	var kind: FishData = ContentDB.fish(fish_id)
	if kind == null:
		return
	if kind.heal_fraction > 0.0:
		health.heal(health.max_hp * kind.heal_fraction)
	if kind.shield_fraction > 0.0:
		health.add_shield(health.max_hp * kind.shield_fraction)
	if kind.mana_fraction > 0.0:
		mana = minf(mana + mana_max() * kind.mana_fraction, mana_max())
		RunState.hero_mana = mana
		EventBus.hero_mana_changed.emit(mana, mana_max())
	take_meal_buff(kind)
	Vfx.ring(combat_origin(), 54.0, kind.rarity_colour(), 0.4, 4.0)
	Sfx.play("sfx_ui_confirm", -2.0)


## Whether this body is the one under this machine's hands.
##
## In a solo run there is one hero and it is always this one. In co-op the
## partner's body is in the same tree, and a good deal depends on telling them
## apart - who a fish feeds, whose line is in the water.
func is_local_player() -> bool:
	return not Coop.is_networked() or party_slot == Coop.party().slot()


## Clears every disable on this hero. Bulwark Ward's cleanse, for the caster
## and for a partner standing on the warded ground.
func cleanse_disables() -> void:
	_beast_stun_left = 0.0
	Vfx.ring(global_position, 60.0, Color("dff5ff"), 0.3, 4.0)


## Gives back a share of the dash cooldown. Red Pursuit, and any later node
## that wants the same currency.
func refund_dash(fraction: float) -> void:
	if fraction <= 0.0:
		return
	_dash_cooldown_left = maxf(_dash_cooldown_left - Balance.HERO_DASH_COOLDOWN * fraction, 0.0)


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
## True while down and waiting for help, rather than dead and waiting for a clock.
func is_downed() -> bool:
	return _downed


func revive_progress() -> float:
	return _revive_progress


## Mirrored from the host, or set by it. The bar reads this and nothing else.
func set_revive_progress(value: float) -> void:
	_revive_progress = clampf(value, 0.0, 1.0)


## Whether this hero's player is holding the revive key right now.
##
## Asked of the input source rather than of `Input`, so a partner's hold arrives
## over the wire through the same seam their movement does and the host can read
## both players' hands without either hero knowing a network exists.
func is_holding_revive() -> bool:
	return input != null and input.held(HeroInput.HOLD_REVIVE)


## Helped back up by a partner. Costs the run nothing.
##
## Comes back **where they fell**, which is the point: the partner crossed the
## field and stood in the open for three seconds to make that happen, and
## teleporting the rescued hero to the spawn would throw that away.
func revive_in_place() -> void:
	# Any hero who is not standing, rather than only one flagged downed.
	#
	# Reported from play: the bar filled and nothing happened. A hero can stop
	# being alive by more than one road - the solo wound path, a raid ejection, a
	# lethal packet arriving a frame before the flag - and refusing to get them up
	# because the flag was not set leaves a body on the floor that the game has
	# no other way to recover.
	if is_alive():
		return
	_downed = false
	_revive_progress = 0.0
	_respawn_fraction = Balance.COOP_DOWNED_REVIVE_HP
	_finish_respawn(false)


## Both players went down, so the run pays a Wound and both come back.
##
## The wound itself is added once, by whoever is coordinating the pair - not here
## - because it belongs to the run rather than to either hero, and adding it in
## both heroes would charge twice for one wipe.
func respawn_from_wipe() -> void:
	_downed = false
	_revive_progress = 0.0
	_respawn_fraction = Balance.HERO_WOUND_REVIVE_HP
	_finish_respawn()


## 0..1, for a cooldown readout in a later stage.
## A blow arrived and the dash ate it.
##
## Owner request, 2026-09-02: the dash exists, and a well-timed one should be
## worth more than an early one. **Perfect Evade is about *when*, not whether.**
## A player who dashed a full second early and happened to be invulnerable did
## not read anything; one who dashed as the blow landed did, and that is the
## only difference between the two - so the window is measured from the start of
## the i-frames rather than from the dash input.
##
## The reward is tempo and nothing else: part of the dash back, and a few
## quickened swings. Hero power is on one capped scale (working rule 7), so a
## dodge that hit harder would be a second scale nobody is tuning against - what
## a good dodge earns is the *chance to act*, which is what it opens in the
## fiction too.
## **Hunter's Pulse**, which promised "marked support kills grant a short speed
## burst" and did nothing: `support_kill_speed` was one of twenty-one discipline
## effects with no consumer anywhere in the codebase.
##
## The Howler is the support - it is the body that buffs the ones around it, and
## `enemy.gd` already asks `_nearby_howler()` before every blow. So this pays for
## the same play the morale system teaches: kill the one holding the others
## together, and the reward is the tempo to reach the next knot.
##
## The role is read from the breed rather than carried on the signal, because
## `enemy_died(id, at)` is a typed EventBus fact and widening it for one node
## would be a contract change (working rule 5).
func _on_enemy_died(enemy_id: String, _at: Vector2) -> void:
	if not is_alive() or not DisciplineEffects.trained("support_kill_speed"):
		return
	var breed: EnemyData = ContentDB.enemy(enemy_id)
	if breed == null or breed.role != EnemyData.Role.HOWLER:
		return
	_pulse_left = Balance.HUNTERS_PULSE_SECONDS
	Vfx.ring(global_position, 96.0, Balance.HERO_EVADE_COLOUR, 0.22, 3.0)
	# **Second Wind.** Rising Fury ebbs the moment you stop swinging, and killing
	# a Howler usually means the knot around it comes apart and there is nothing
	# to swing at - so the reward for the play the game most wants you to make
	# was, in practice, losing your attack speed. This hands it straight back at
	# the cap. No number changes: the ramp is the ramp, it simply starts full.
	if Synergies.active("second_wind") and attack != null:
		attack.fill_fury()


## **What a perfect evade looks like.**
##
## Drawn here rather than on a listener because the signal is the announcement
## and this is the reaction: a system that wants to *count* evades listens, and
## a player who wants to know they nailed one needs it on the frame it happened.
##
## A cold ring and a brief freeze, not a hit's warm burst - an evade is a blow
## that did not land, and dressing it like damage would read as one.
func _show_a_perfect_evade() -> void:
	EventBus.hitstop_requested.emit(Balance.EVADE_HITSTOP)
	Vfx.ring(global_position, Balance.EVADE_RING_RADIUS,
		Color(Balance.EVADE_TINT, 0.9), 0.26, 3.0)
	Vfx.flash_at(global_position, Color(Balance.EVADE_TINT, 0.5),
		Balance.EVADE_FLASH_RADIUS)
	EventBus.camera_impact.emit(global_position, Balance.EVADE_SHAKE)
	Sfx.play("sfx_dash", -4.0)


func _on_evaded(into: float, from: Vector2) -> void:
	if into > Balance.HERO_PERFECT_EVADE_WINDOW:
		return
	EventBus.hero_perfect_evade.emit(global_position)
	_show_a_perfect_evade()
	# **No Ground Given.** A perfect evade is this game's block - the i-frame
	# window is how a committed hit is answered - so it empowers the *next
	# finisher* rather than every swing after it. One evade, one blow.
	if DisciplineEffects.trained("block_finisher"):
		_guard_left = Balance.DISCIPLINE_GUARD_SECONDS
	if attack != null:
		attack.grant_haste(Balance.HERO_EVADE_HASTE_SECONDS)
	# One refund per dash. See `_dash_refunded`.
	if not _dash_refunded:
		_dash_refunded = true
		_dash_cooldown_left = maxf(_dash_cooldown_left
			- Balance.HERO_DASH_COOLDOWN * Balance.HERO_EVADE_REFUND, 0.0)
	# Drawn toward whatever swung, so the flourish reads as an answer to *that*
	# blow rather than as something the hero did on their own.
	var away: Vector2 = (global_position - from).normalized()
	if away.length() < 0.001:
		away = Vector2.UP
	Vfx.ring(global_position, 92.0, Balance.HERO_EVADE_COLOUR, 0.34, 5.0)
	Vfx.spark(global_position, Balance.HERO_EVADE_COLOUR, 10, away, 260.0)
	# **Vigil.** "Perfect dodges near the Town Hall grant Command."
	#
	# The node has said that to the player since it was authored and did nothing:
	# `town_dodge_command` was one of twenty-one discipline effects with no
	# consumer anywhere in the codebase. Trained rather than equipped, because
	# Vigil is a PASSIVE and never occupies a slot.
	#
	# Command and not damage, exactly as written - a dodge that hit harder would
	# be a second power scale beside levelling and gear (working rule 7). What it
	# buys is the chance to *order* something, which is the same currency the
	# rest of the evade reward is paid in.
	# `town_node()` rather than a null check on the field: `EnemyField` answers
	# `town_position()` with the origin when there is no town, so the raid arena
	# would have paid Vigil to anyone dodging near its centre.
	if DisciplineEffects.trained("town_dodge_command") 			and field != null and field.town_node() != null:
		var hall: Vector2 = field.town_position()
		if global_position.distance_to(hall) <= Balance.VIGIL_COMMAND_RADIUS:
			RunState.gain_command(
				DisciplineEffects.trained_value("town_dodge_command"))
			Vfx.ring(global_position, 118.0, Balance.HERO_EVADE_COLOUR, 0.28, 4.0)
	# Not the dash whoosh, which already played when the dash started - a reward
	# that sounds like the thing it rewards is a reward nobody hears. The blink
	# cue is crisp, short, and already means "you were not there".
	Sfx.play("sfx_spell_blink", -4.0)


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
	_dash_refused_said = maxf(_dash_refused_said - delta, 0.0)
	_tick_mana(delta)
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_beast_stun_left = maxf(_beast_stun_left - delta, 0.0)
	_shoved = _shoved.move_toward(Vector2.ZERO, Balance.HERO_SHOVE_DECAY * delta)
	_pulse_left = maxf(_pulse_left - delta, 0.0)
	if _veil_left > 0.0:
		_veil_left = maxf(_veil_left - delta, 0.0)
		if _veil_left <= 0.0:
			_veil_speed_bonus = 0.0
	if _armor_left > 0.0:
		_armor_left = maxf(_armor_left - delta, 0.0)
		if _armor_left <= 0.0 and health != null:
			# Back to what Resolve alone is worth, not to nothing. Before the
			# fifth attribute these were the same number.
			health.damage_scale = _resolve_scale()
	if _wound_delay_left > 0.0:
		_wound_delay_left = maxf(_wound_delay_left - delta, 0.0)
		if _wound_delay_left <= 0.0 and health != null:
			health.deferred_fraction = _wound_fraction
	elif _wound_left > 0.0:
		_wound_left = maxf(_wound_left - delta, 0.0)
		if _wound_left <= 0.0 and health != null:
			# The window closed. Whatever was not won back is taken now, and
			# said out loud so the player knows why they just lost health.
			var owed: float = health.settle_deferred(global_position)
			if owed >= 1.0:
				Vfx.number(combat_origin(), owed, Color("ff7a6a"), false)
	if _mender_left > 0.0 and health != null and not health.is_dead:
		_mender_left = maxf(_mender_left - delta, 0.0)
		_mender_grace_left = maxf(_mender_grace_left - delta, 0.0)
		health.heal(health.max_hp * Balance.MENDER_SPARK_REGEN_PER_SECOND * delta)
	if _lunge_velocity != Vector2.ZERO:
		_lunge_velocity = _lunge_velocity.move_toward(Vector2.ZERO, _lunge_decay * delta)


## **SP, and the sprint it pays for.**
##
## Diablo II's shape, which is the good part of it: running drains, standing
## refills after a pause, and at empty you are *forced* to walk until you have
## clawed back `HERO_SPRINT_FLOOR`. That last rule is why stamina is a resource
## rather than a speed setting - spending it all costs something you feel.
##
## A tap of the dash button is the dash it always was. Only a hold past
## `HERO_SPRINT_HOLD` becomes a sprint, and only while actually moving: standing
## on the button is not running, and draining the pool for it would be the one
## way to be punished for nothing.
func _tick_sprint(delta: float) -> void:
	# **A rider spends nothing** (owner brief, 2026-09-17). The gallop has its
	# own wind on the mount, so returning here is what keeps SP out of it -
	# without this the sprint key would drain both pools at once and the
	# Warden would arrive winded from a journey they did not walk.
	if _mount != null:
		return
	# **Two ways in, and they engage differently.** The dash button has to be
	# held past `HERO_SPRINT_HOLD` so that a tap of it stays a dash; the
	# sprint key exists only to sprint, so it takes effect on the press.
	var dashing: bool = input != null and input.held(HeroInput.HOLD_DASH)
	var asked: bool = input != null and input.held(HeroInput.HOLD_SPRINT)
	if dashing:
		_dash_held += delta
	else:
		_dash_held = 0.0
	var down: bool = asked or dashing
	var committed: bool = asked or _dash_held >= Balance.HERO_SPRINT_HOLD
	var walking: bool = (velocity - _shoved).length() > 6.0
	var may: bool = down and walking and committed \
		and not _winded and not _swimming and is_alive() \
		and _beast_stun_left <= 0.0 and not RunState.flood_over_knee()
	if may and stamina > 0.0:
		_sprinting = true
		stamina = maxf(stamina - Balance.HERO_STAMINA_DRAIN * delta, 0.0)
		_stamina_rest = Balance.HERO_STAMINA_REGEN_DELAY
		_kick_up_dust(delta)
		if stamina <= 0.0:
			_give_out()
	else:
		_sprinting = false
		_stamina_rest = maxf(_stamina_rest - delta, 0.0)
		if _stamina_rest <= 0.0 and stamina < Balance.HERO_STAMINA_MAX:
			stamina = minf(stamina + Balance.HERO_STAMINA_REGEN * delta,
				Balance.HERO_STAMINA_MAX)
		# Back on its feet: the floor is what stops a player tapping sprint the
		# instant the legs give out and getting a stride out of it.
		if _winded and stamina >= Balance.HERO_SPRINT_FLOOR:
			_winded = false
	if not is_equal_approx(stamina, _stamina_said):
		_stamina_said = stamina
		EventBus.hero_stamina_changed.emit(stamina, Balance.HERO_STAMINA_MAX)


# --- Mounts ------------------------------------------------------------------

## **What riding forbids**, as one mask.
##
## Handed to the hero's own input source, which is what every one of the eight
## interact call sites already holds, so a gather, a cast, an egg and a fishing
## line are all refused in one place. See `HeroInput.muted` for why it is there
## rather than at each site.
##
## `BUTTON_MOUNT` is deliberately absent: a mount key that muted itself would be
## a Warden who cannot get off. `HOLD_DASH` and `HOLD_SPRINT` are absent too,
## because the gallop *is* the sprint - which is the owner's own clause.
const MOUNTED_MUTE: int = HeroInput.BUTTON_ATTACK | HeroInput.HOLD_ATTACK \
	| HeroInput.BUTTON_RANGED | HeroInput.BUTTON_AMMO_CYCLE \
	| HeroInput.BUTTON_INTERACT | HeroInput.HOLD_INTERACT \
	| HeroInput.BUTTON_DASH | HeroInput.HOLD_REVIVE


## Getting on, staying on, galloping, and getting off.
##
## Run before `can_fight()` is asked, because a press of attack while mounted is
## a *dismount* rather than a refusal - the owner's rule is that the Warden
## dismounts when they attack and the fight starts where they stood, so the
## press has to be seen before the mute swallows it.
func _tick_mount(delta: float) -> void:
	_mount_wait = maxf(_mount_wait - delta, 0.0)
	_mount_up_left = maxf(_mount_up_left - delta, 0.0)
	_mount_refused_said = maxf(_mount_refused_said - delta, 0.0)
	if input == null:
		return

	if _mount != null:
		# **The dismount, and the swing that asked for it.** Read through the raw
		# source rather than through `pressed`, because the mask is what a rider
		# is muted by and the point of this branch is to hear the muted button.
		if _asked_to_fight():
			dismount()
			# Not consumed: the mute comes off in the same frame, so the press the
			# player made lands as the swing they meant. The owner's words were
			# "they dismount when they attack and start fighting where they
			# dismounted".
			return
		if input.pressed(HeroInput.BUTTON_MOUNT):
			dismount()
			return
		if not _may_stay_mounted():
			dismount()
			return
		_tick_gallop(delta)
		_drive_mount()
		return

	if input.pressed(HeroInput.BUTTON_MOUNT):
		mount()


## Whether the player asked to fight this frame, through any of the doors a
## rider is muted on.
##
## **Asked of the raw source**, since `pressed`/`held` answer false for exactly
## these bits while mounted. One function, so the list cannot drift from
## `MOUNTED_MUTE` - which is the failure this project has shipped twice.
func _asked_to_fight() -> bool:
	if input == null or _beast_stun_left > 0.0:
		return false
	var was: int = input.muted
	input.muted = 0
	var asked: bool = input.pressed(HeroInput.BUTTON_ATTACK) \
		or input.held(HeroInput.HOLD_ATTACK) \
		or input.pressed(HeroInput.BUTTON_RANGED) \
		or input.pressed(HeroInput.BUTTON_INTERACT)
	if not asked:
		for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
			if input.pressed(HeroInput.spell_button(slot)):
				asked = true
				break
	input.muted = was
	return asked


## Gets on, if there is anything to get on and anywhere to do it.
##
## Every refusal says why at the feet rather than doing nothing, because a key
## that silently does not work reads as a key that is not bound.
func mount() -> bool:
	if _mount != null or _mount_wait > 0.0 or not is_alive():
		return false
	var kind: MountData = _saddled()
	if kind == null:
		_refuse("No mount saddled")
		return false
	if _swimming or RunState.flood_over_knee():
		_refuse("Too deep to ride")
		return false
	if _beast_stun_left > 0.0:
		return false
	# **Not a fairness rule.** A rider cannot fight, so mounting in a crowd only
	# ever costs the player - this is here because doing it by accident in the
	# middle of a wave reads as the game disarming you.
	if _danger_near():
		_refuse("Not with something this close")
		return false
	_mount = kind
	_mount_up_left = Balance.MOUNT_UP_SECONDS
	mount_wind = kind.stamina
	_mount_winded = false
	_galloping = false
	_mount_wind_rest = 0.0
	_mount_wind_said = -1.0
	if input != null:
		input.muted = MOUNTED_MUTE
	# A channel or a swing already running is ended rather than left hanging:
	# the rider is out of the fight from this frame, and a cast that finished in
	# the saddle would be the one thing this feature must not allow.
	attack.cancel()
	spells.cancel_channel()
	if _mount_rig != null:
		_mount_rig.show_mount(kind)
	Vfx.dust(global_position, Color(0.55, 0.49, 0.4), 6, 40.0)
	Sfx.play_at("sfx_footstep_heavy", global_position, -4.0)
	# **Only this machine's own player says so.** The signal carries no hero,
	# so every listener would have to guess whose it was - and `CoopHeroes`
	# would record a partner's horse under this player's seat. The same
	# distinction `_say_wind` makes for the readout.
	if is_local_player():
		EventBus.hero_mounted.emit(kind.id)
	_say_wind()
	return true


## Which mount this hero rides: the one it was told, or this account's own.
func _saddled() -> MountData:
	if not told_mount.is_empty():
		return ContentDB.mount(told_mount)
	return MetaState.saddled_mount()


## A mirrored hero was told which horse it is on.
##
## Re-dresses a hero that is *already* up, because the state packet carrying
## the id arrives twenty times a second while the press that mounted it
## arrived on a frame - so without this the first moment of every partner's
## ride is drawn with the wrong animal.
func wear_mount(id: String) -> void:
	if told_mount == id:
		return
	told_mount = id
	if _mount == null or _mount_rig == null:
		return
	var kind: MountData = _saddled()
	if kind == null:
		dismount()
		return
	_mount = kind
	_mount_rig.show_mount(kind)


## Gets off, here, facing the way the Warden was going.
##
## Idempotent, because several things call it - the attack press, the mount
## key, and every condition that ends a ride - and a dismount that fired twice
## would pay its dust and its sound twice.
func dismount() -> bool:
	if _mount == null:
		return false
	_mount = null
	_galloping = false
	_mount_up_left = 0.0
	_mount_wait = Balance.MOUNT_REMOUNT_DELAY
	if input != null:
		input.muted = 0
	if _mount_rig != null:
		_mount_rig.show_mount(null)
	Vfx.dust(global_position, Color(0.55, 0.49, 0.4), 5, 34.0)
	if is_local_player():
		EventBus.hero_dismounted.emit()
	_say_wind()
	return true


## Whether riding is still allowed at all.
##
## Checked every frame rather than hooked to each cause, for the reason
## `DeathMarkers` watches heroes instead of listening for a death: every way of
## ending a ride arrives through one of these facts, without a signal per path.
func _may_stay_mounted() -> bool:
	if not is_alive() or _downed:
		return false
	if _swimming or RunState.flood_over_knee():
		return false
	if _beast_stun_left > 0.0:
		return false
	return true


## The mount's own wind. The same shape as the Warden's SP and a separate
## pool: the horse gets tired, the rider does not.
func _tick_gallop(delta: float) -> void:
	var asked: bool = input.held(HeroInput.HOLD_SPRINT) \
		or input.held(HeroInput.HOLD_DASH)
	var moving: bool = (velocity - _shoved).length() > 6.0
	var may: bool = asked and moving and not _mount_winded \
		and _mount_up_left <= 0.0
	if may and mount_wind > 0.0:
		_galloping = true
		mount_wind = maxf(mount_wind - _mount.stamina_drain * delta, 0.0)
		_mount_wind_rest = Balance.MOUNT_WIND_REST
		_kick_up_hooves(delta)
		if mount_wind <= 0.0:
			_mount_winded = true
			_galloping = false
	else:
		_galloping = false
		_mount_wind_rest = maxf(_mount_wind_rest - delta, 0.0)
		if _mount_wind_rest <= 0.0 and mount_wind < _mount.stamina:
			mount_wind = minf(mount_wind + _mount.stamina_regen * delta,
				_mount.stamina)
		if _mount_winded and mount_wind >= Balance.MOUNT_WIND_FLOOR:
			_mount_winded = false
	_say_wind()


## Tells the readout, on change rather than sixty times a second - the rule the
## Warden's own pools are announced under.
##
## **The same bar, not a second one.** A rider's SP bar shows the horse's wind
## while they are up and their own the moment they are down, because the pool
## under the thumb is whichever one the player is currently spending.
func _say_wind() -> void:
	if not is_local_player():
		return
	if _mount == null:
		_stamina_said = -1.0
		_mount_wind_said = -1.0
		EventBus.hero_stamina_changed.emit(stamina, Balance.HERO_STAMINA_MAX)
		return
	if is_equal_approx(mount_wind, _mount_wind_said):
		return
	_mount_wind_said = mount_wind
	EventBus.hero_stamina_changed.emit(mount_wind, _mount.stamina)


## Dirt off the hooves while galloping, on its own clock. A puff a frame is a
## solid cloud; this is four feet leaving the ground.
func _kick_up_hooves(delta: float) -> void:
	_mount_dust -= delta
	if _mount_dust > 0.0:
		return
	_mount_dust = Balance.MOUNT_DUST_INTERVAL
	var behind: Vector2 = global_position - velocity.normalized() * 20.0
	Vfx.dust(behind, Color(0.55, 0.49, 0.4), 4, 34.0)


## Points the mount and paces its legs. Presentation only.
func _drive_mount() -> void:
	if _mount_rig == null:
		return
	var own: Vector2 = velocity - _shoved
	var speed: float = own.length()
	_mount_rig.set_facing(_facing if speed <= 4.0 else own.normalized())
	if speed > 4.0:
		_mount_rig.set_speed_scale(speed / maxf(Balance.HERO_MOVE_SPEED, 1.0))
		_mount_rig.play("gallop" if _galloping else "walk")
	else:
		_mount_rig.set_speed_scale(1.0)
		_mount_rig.play("idle")


## Something hostile within `MOUNT_DANGER_RANGE`.
##
## Asks the field's own enemy reader rather than the group, so a camp body
## nothing is waiting on and a road body both count - what matters is whether
## the Warden is about to need their hands.
func _danger_near() -> bool:
	if field == null or not field.has_method("enemies_near"):
		return false
	var close: Array = field.call("enemies_near", global_position,
		Balance.MOUNT_DANGER_RANGE) as Array
	return not close.is_empty()


## Says why, once, at the feet.
func _refuse(line: String) -> void:
	if _mount_refused_said > 0.0:
		return
	_mount_refused_said = 1.4
	Vfx.word(global_position + Vector2(0.0, -40.0), line, Color(0.9, 0.84, 0.6), 18)


## Whether the Warden is up. Read by the HUD, the prompts and the gate.
func is_mounted() -> bool:
	return _mount != null


## What they are riding, or null.
func mounted_kind() -> MountData:
	return _mount


## Whether the mount is at a gallop right now.
func is_galloping() -> bool:
	return _galloping


## The legs gave out: forced to walk until the floor is back. Said out loud,
## because a character that silently slows down reads as the game stuttering.
func _give_out() -> void:
	if _winded:
		return
	_winded = true
	_sprinting = false
	EventBus.hero_winded.emit()
	Vfx.word(global_position + Vector2(0.0, -46.0), "Winded",
		Color(0.85, 0.82, 0.7), 20)
	Vfx.dust(global_position, Color(0.52, 0.46, 0.38), 8, 46.0)
	Sfx.play_at("sfx_hero_hurt", global_position, -8.0)


## Dust off the heels while running, on its own clock rather than every frame -
## a puff a frame is a solid cloud, and this is feet leaving the ground.
func _kick_up_dust(delta: float) -> void:
	_sprint_dust -= delta
	if _sprint_dust > 0.0:
		return
	_sprint_dust = Balance.HERO_SPRINT_DUST
	var behind: Vector2 = global_position - velocity.normalized() * 14.0
	Vfx.dust(behind, Color(0.55, 0.49, 0.4), 3, 26.0)


## Whether the Warden is running. Read by the movement and by the animator, and
## by the gate.
func is_sprinting() -> bool:
	return _sprinting


func _try_dash() -> void:
	# Over the knee there is no dashing (owner brief, 2026-09-14): the water
	# takes the legs. Said once at the feet, not refused in silence.
	if RunState.flood_over_knee():
		if _dash_refused_said <= 0.0:
			_dash_refused_said = 1.2
			Vfx.word(global_position + Vector2(0.0, -40.0), "Too deep", Color(0.7, 0.85, 1.0), 20)
		return
	if _dash_cooldown_left > 0.0 or _dash_left > 0.0:
		return
	# Dash where you are steering; fall back to where you are looking, so a
	# standing dash still goes somewhere deliberate.
	var move_input: Vector2 = _move_input()
	_dash_direction = move_input.normalized() if move_input.length() > 0.1 else _aim
	_dash_left = Balance.HERO_DASH_DURATION
	_dash_cooldown_left = Balance.HERO_DASH_COOLDOWN
	_dash_refunded = false
	health.add_invulnerability(Balance.HERO_DASH_IFRAMES)
	animator.dash(_dash_direction, Balance.HERO_DASH_DURATION)
	_lock_frames("dash")
	_spawn_dash_ghosts()
	EventBus.hero_dashed.emit(Balance.HERO_DASH_IFRAMES)


## Sized so the lunge covers `distance` while decaying linearly to zero over
## HERO_ATTACK_LUNGE_TIME. Tuning the distance is enough; the speed follows.
func _on_attack_landed(chain_step: int, _targets: int, _at: Vector2) -> void:
	# Sanguine Guard: a landed blow wins back part of the banked wound.
	if _wound_left > 0.0 and health != null:
		var won: float = health.recover_deferred(Balance.DISCIPLINE_WOUND_RECOVER_PER_HIT)
		if won >= 1.0:
			Vfx.number(combat_origin(), won, Balance.HEALING_ORB_COLOUR, false)
	# A connecting swing squashes harder than a whiffed one.
	animator.squash(Balance.ANIM_PUNCH_SQUASH * (1.6 if chain_step == 2 else 1.0))
	# The blade meets resistance. This replaces any remaining forward lunge with
	# a short counter-step, but never touches HeroAttack's chain or buffer state.
	if not _attack_recoil_ready:
		return
	_attack_recoil_ready = false
	var recoil: float = Balance.HERO_ATTACK_RECOIL[clampi(chain_step, 0,
		Balance.HERO_ATTACK_RECOIL.size() - 1)]
	_apply_attack_impulse(-attack.swing_direction(), recoil,
		Balance.HERO_ATTACK_RECOIL_TIME)


func _on_lunge_requested(direction: Vector2, distance: float) -> void:
	_attack_recoil_ready = true
	var capped: float = _capped_lunge_distance(direction, distance)
	_apply_attack_impulse(direction, capped, Balance.HERO_ATTACK_LUNGE_TIME)
	animator.punch(direction, clampf(capped / 110.0, 0.35, 1.5))
	_lock_frames(_frame_state_for_swing(attack.current_step()))


## Stops a forward step at the first hostile body in its corridor. Enemies are
## CharacterBody2D nodes and may not physically collide with the hero, so relying
## on `move_and_slide` alone allowed the finisher to cross straight through.
func _capped_lunge_distance(direction: Vector2, wanted: float) -> float:
	var aim: Vector2 = direction.normalized()
	if aim == Vector2.ZERO:
		return 0.0
	var capped: float = wanted
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dying():
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		var forward: float = to_enemy.dot(aim)
		if forward <= 0.0 or forward > wanted + enemy.contact_radius() \
				+ Balance.HERO_ATTACK_BODY_CLEARANCE:
			continue
		var sideways: float = absf(aim.cross(to_enemy))
		if sideways > enemy.contact_radius() + Balance.HERO_ATTACK_LUNGE_CORRIDOR:
			continue
		capped = minf(capped, maxf(0.0, forward - enemy.contact_radius()
			- Balance.HERO_ATTACK_BODY_CLEARANCE))
	return capped


func _apply_attack_impulse(direction: Vector2, distance: float,
		duration: float) -> void:
	if duration <= 0.0 or distance <= 0.0 or direction == Vector2.ZERO:
		_lunge_velocity = Vector2.ZERO
		_lunge_decay = 0.0
		return
	var speed: float = 2.0 * distance / duration
	_lunge_velocity = direction.normalized() * speed
	_lunge_decay = speed / duration


func _on_damaged(amount: float, from: Vector2) -> void:
	if _mender_left > 0.0 and _mender_grace_left <= 0.0:
		_mender_left = 0.0
		var recovery: Resource = ContentDB.recovery_drop(Balance.MENDER_SPARK_ID)
		if recovery != null:
			EventBus.preparation_warning.emit(String(recovery.get("broken_line")))
	_flash_left = Balance.HIT_FLASH_TIME
	# **The blow the player feels most.** Every other impact in the game shakes
	# the camera by how hard it landed and how far away it was; the one landing
	# on the hero did not, which is the one the camera is sitting on.
	if health != null and health.max_hp > 0.0:
		EventBus.camera_impact.emit(global_position,
			amount / health.max_hp / Balance.IMPACT_FULL_SHARE)
	var body_at: Vector2 = combat_origin()
	_impact_direction = (body_at - from).normalized()
	BloodStain.strike(_blood, _impact_direction)
	animator.impact_frame()
	animator.recoil(from, body_at, 1.0)
	_lock_frames("hurt")
	EventBus.hero_damaged.emit(amount, from, body_at)
	EventBus.camera_shake_requested.emit(4.0, 0.18)


## The root is the hero's ground contact for Y-sorting; combat originates from
## the centre-authored pose that occupied this world position before that depth
## correction. Keeping the two meanings explicit prevents future sorting work
## from moving swings, spells and hit feedback down to the Warden's boots.
## How fast the hero is moving under their own power.
##
## The beast's footfall shoves the body through `_shoved`, and that
## shove is real motion the physics sees - but it is not the hero going
## anywhere. Fishing reads this: the first cut read `velocity` and a hero on a
## walking beast was never still enough to cast.
func own_speed() -> float:
	return (velocity - _shoved).length()


func combat_origin() -> Vector2:
	return global_position + Vector2(0.0, -_depth_lift)


## Kindles the rare elite recovery on the hero who physically collected it.
## The authority runs the healing; ordinary co-op hero snapshots mirror HP.
## Drinks one healing orb. `points` is health, decided by the body that dropped
## it and capped there.
##
## Announced rather than silent. A heal the player does not notice is a heal
## that did not happen as far as they are concerned, and the floating number is
## the only thing that tells an orb from a coin at a glance.
func drink_healing_orb(points: float) -> void:
	if health == null or health.is_dead or points <= 0.0:
		return
	var before: float = health.current_hp
	health.heal(points)
	var gained: int = int(round(health.current_hp - before))
	if gained <= 0:
		return
	Vfx.number(combat_origin(), float(gained), Balance.HEALING_ORB_COLOUR, false)
	var drop := ContentDB.recovery_drops.get(Balance.HEALING_ORB_ID, null) 		as RecoveryDropData
	if drop != null and not drop.pickup_line.is_empty():
		EventBus.preparation_warning.emit(drop.pickup_line % gained)


## Drinks a draught from a healing well.
##
## Separate from the orb because the two are different objects with different
## costs - an orb is found, a well is built - and a player should be able to
## tell which one just healed them from the colour and the line alone.
func drink_from_well(points: float) -> void:
	if health == null or health.is_dead or points <= 0.0:
		return
	var before: float = health.current_hp
	health.heal(points)
	var gained: int = int(round(health.current_hp - before))
	if gained <= 0:
		return
	Vfx.number(combat_origin(), float(gained), Balance.WELL_COLOUR, false)
	EventBus.preparation_warning.emit("HEALING WELL  ·  +%d health" % gained)


func apply_mender_spark() -> void:
	if health == null or health.is_dead:
		return
	health.heal(health.max_hp * Balance.MENDER_SPARK_IMMEDIATE_FRACTION)
	_mender_left = Balance.MENDER_SPARK_DURATION
	_mender_grace_left = Balance.MENDER_SPARK_BREAK_GRACE
	Vfx.ring(combat_origin(), 104.0, Color(0.48, 0.96, 0.66, 0.82), 0.55, 6.0)
	Vfx.spark(global_position, Color("c8ffe0"), 18, Vector2.UP, 190.0)
	EventBus.mender_spark_collected.emit(party_slot, global_position)
	var recovery: Resource = ContentDB.recovery_drop(Balance.MENDER_SPARK_ID)
	if recovery != null:
		EventBus.preparation_warning.emit(String(recovery.get("pickup_line")))


func mender_active() -> bool:
	return _mender_left > 0.0


func mender_seconds_left() -> float:
	return _mender_left


## Throw this hero, without hurting them.
##
## The boss slam is the caller that needed this: `boss_slam_knockback` was
## authored for eleven bosses and read by nothing, so a telegraphed blow that
## covered four hundred units moved the player not at all.
##
## Capped at `Balance.shove_ceiling`, because a shove is a decaying impulse and
## its reach grows with the square of the speed - so a number typed one digit
## too long is the difference between staggering back and being posted across
## the field. It adds no stun: the player keeps full control of a body that is
## briefly sliding, which is the difference between a shove and a stun.
func shove(push: Vector2) -> void:
	if not is_alive() or push.is_zero_approx():
		return
	var speed: float = minf(push.length(), Balance.shove_ceiling())
	# The total, not the new push: two slams landing on the same frame would
	# otherwise sum past the bound `HERO_SHOVE_MAX_TRAVEL` is there to hold.
	_shoved = (_shoved + push.normalized() * speed).limit_length(
		Balance.shove_ceiling())
	animator.stagger(push.normalized(), 0.5)


func _on_beast_step(impulse: Vector2, strength: float) -> void:
	if field is RaidArena or not is_alive():
		return
	# The camera rig owns the guard: a beast in Preparation takes no step, so
	# no footfall arrives here. A second guard on this side made a stray step
	# - which `structure_check` sends on purpose - do nothing, and the physical
	# recipients of a plant must all answer the same event.
	_shoved += impulse * clampf(strength, 0.0, 1.2)
	_beast_stun_left = maxf(_beast_stun_left, Balance.BEAST_STEP_STUN * strength)
	animator.stagger(impulse, strength)


func _on_health_changed(current: float, maximum: float) -> void:
	RunState.hero_hp = current
	Modifiers.rebuild()
	EventBus.hero_health_changed.emit(current, maximum)


func _on_died(at: Vector2) -> void:
	# **Off the horse first.** `_physics_process` returns on its first line for
	# a hero who is not standing, so `_tick_mount` - which is what ends every
	# other ride - never runs again after this frame. Without this a corpse is
	# drawn sitting on a horse and its input stays muted, and a revive brings
	# the Warden back still mounted and still unable to swing.
	dismount()
	# Asked by *effect*, never by id. The hero's question is "do I hold anything
	# that stops a death"; what a Draught is happens to be the answer today and
	# a second revive item is now a file rather than another branch here.
	var saviour: ItemData = RunState.item_with_effect(ItemData.Effect.REVIVE, true)
	if saviour != null and RunState.spend_item(saviour.id):
		_stand_back_up(saviour.effect_value)
		return
	# In co-op, going down is not by itself the end of anything.
	#
	# No wound, no respawn clock: the hero lies there until a partner gets them
	# up, or until the other player goes down too and the pair pays one Wound
	# between them. Owner's re-cut, 2026-08-25. Solo play is untouched below.
	if Coop.partner_present():
		go_down(at)
		return
	var wounds: int = RunState.add_wound()
	# A party walking out cannot be killed out of the walk. See
	# `RunState.run_may_be_lost` - they stand back up and keep holding.
	if wounds >= RunState.max_wounds() and RunState.run_may_be_lost():
		RunState.hero_deaths += 1
		EventBus.hero_died.emit(at)
		GameDirector.end_run(false)
		return
	_respawn_left = Balance.HERO_RESPAWN_DELAY
	_respawn_fraction = Balance.HERO_WOUND_REVIVE_HP
	_collapse(at)


## Goes down without dying: no Wound, no respawn clock, waiting for a partner.
##
## Public rather than a branch buried in the death path, so the rule can be
## provoked and checked directly. The difference between this and a solo death is
## entirely in what it *does not* do, and that is the hardest kind of behaviour
## to gate by accident.
func go_down(at: Vector2) -> void:
	if _downed:
		return
	# Same reason as `_on_died`: a downed hero is not alive, so the tick that
	# ends a ride stops running.
	dismount()
	_downed = true
	_revive_progress = 0.0
	_collapse(at)


## Everything that happens to the body when a hero goes down, either way.
##
## Shared so the two paths cannot drift: a downed hero and a dead one look
## identical, which is correct - the difference is what happens next, not what it
## looks like.
func _collapse(at: Vector2) -> void:
	_dash_left = 0.0
	_armor_left = 0.0
	_wound_left = 0.0
	_wound_delay_left = 0.0
	_lunge_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	attack.cancel()
	health_bar.visible = false
	# With a death sheet the body collapses on screen and is hidden when the
	# animation ends. Without one it vanishes immediately, as it always did -
	# the respawn timer is eight seconds either way. In the water there is no
	# collapse: the body goes under.
	if _swimming:
		_drown(at)
	elif frames != null and frames.has_state("death"):
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
	# A downed hero has no clock. They are waiting for a person, not a timer, and
	# letting this run would stand them straight back up on the next frame.
	if _downed:
		return
	_respawn_left -= delta
	if _respawn_left > 0.0:
		return
	_finish_respawn()


## Getting back up, wherever the decision came from.
##
## Extracted so the co-op path cannot drift from the solo one. A guest told its
## partner is on their feet must come back exactly as it would have on its own -
## same health fraction, same invulnerability window, same announcement - or the
## two machines end up with heroes in different conditions.
func _finish_respawn(to_spawn: bool = true) -> void:
	if to_spawn:
		global_position = spawn_point
	# Standing again is standing on land, whatever took them down.
	_drowned = false
	RunState.hero_hp = -1.0
	_apply_permanent_bonuses()
	_restore_presence()
	_stand_back_up(_respawn_fraction)


## The one way the hero gets back on their feet in the field.
##
## Both revives - the Draught spending itself and the respawn clock running out -
## used to write out the same four lines separately, and Mercy Under Fire was
## added to only one of them. That is precisely the failure this session spent a
## day on: an effect wired into one of two call sites looks implemented and is
## half-inert, and no gate can see the half that is missing. One function, so a
## third way to stand up cannot quietly skip a step.
func _stand_back_up(fraction: float) -> void:
	health.revive(fraction)
	refill_mana()
	health.add_invulnerability(Balance.HERO_RESPAWN_INVULN)
	_mercy_under_fire()
	EventBus.hero_respawned.emit(global_position)


## Mercy Under Fire: getting up shoves the crowd off you.
##
## The one moment in the game where the player has no agency at all is the frame
## they stand back up - inside a ring of whatever killed them, with respawn
## invulnerability that runs out before they can walk out of it. The discipline
## node has promised exactly this since it was authored ("Reviving from a down
## emits a non-damaging knockback") and, like twenty other effect ids, nothing
## read it.
##
## Non-damaging is the whole design and is why `shove` exists. A revive that
## killed things would make dying a play.
func _mercy_under_fire() -> void:
	var push: float = DisciplineEffects.trained_value("revive_knockback")
	if push <= 0.0:
		return
	_synergies_on_standing_up()
	var pushed: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_inside_tree():
			continue
		if enemy.global_position.distance_to(global_position) > Balance.MERCY_RADIUS:
			continue
		enemy.shove(global_position, push)
		pushed += 1
	Vfx.ring(global_position, Balance.MERCY_RADIUS, Balance.HERO_EVADE_COLOUR, 0.34, 5.0)
	if pushed > 0:
		EventBus.camera_shake_requested.emit(4.0, 0.22)


## The two synergies that fire on getting up.
##
## Both are the same idea from opposite sides: the shove clears the crowd, and
## on its own that is a moment of space you cannot use. `break_their_grip` gives
## you the legs to leave, and `the_watch_answers` pays the town for having stood
## up inside its shadow - the same reward Vigil pays for a perfect dodge there,
## on the reasonable ground that going down near home is at least as noteworthy.
##
## Neither raises a number. `SynergyData` records why that is a hard rule rather
## than restraint: the paths decision is bounded by "depth buys access, never
## power", and a synergy that multiplied something would be that bound going out
## through a side door.
func _synergies_on_standing_up() -> void:
	if Synergies.active("break_their_grip"):
		_pulse_left = Balance.HUNTERS_PULSE_SECONDS
	if not Synergies.active("the_watch_answers"):
		return
	# Same guard as Vigil's, and for the same reason: `town_position` answers
	# with the origin when there is no town, so the raid arena would pay this to
	# anyone who went down near its centre.
	if field == null or field.town_node() == null:
		return
	if global_position.distance_to(field.town_position()) > Balance.VIGIL_COMMAND_RADIUS:
		return
	RunState.gain_command(DisciplineEffects.trained_value("town_dodge_command"))
	Vfx.ring(global_position, 132.0, Balance.HERO_EVADE_COLOUR, 0.36, 4.0)


func apply_hearthmend() -> void:
	_respawn_left = 0.0
	RunState.hero_hp = -1.0
	_apply_permanent_bonuses()
	if health.is_dead:
		global_position = Vector2.ZERO
		health.revive()
		refill_mana()
	else:
		health.current_hp = health.max_hp
		health.changed.emit(health.current_hp, health.max_hp)
	_restore_presence()


## Colours this hero as its player, on the ground and on the body.
##
## **Both, and lightly on the body.** A mark under the feet alone was not enough
## to tell four heroes apart in a crowded lane - reported from play - and a body
## painted flat red would fight the art, the lighting and the damage flash, which
## is a readout the player needs more than the colour. So the sprite is *leaned*
## toward the seat colour rather than replaced by it: enough to pick your friend
## out at a glance, little enough that the character still looks like itself and
## a white hurt-flash still reads as one.
##
## `_tint` is stored rather than written straight onto the sprite, because
## everything else that touches `modulate` - the flash, the dash ghosts, the
## death fade - has to compose with it instead of erasing it.
func _apply_party_colour() -> void:
	if not is_inside_tree():
		return
	var wanted: Color = CoopParty.colour_of(party_slot)
	var showing: bool = Coop.player_count() > 1

	var mark: Node2D = get_node_or_null("PartyMark") as Node2D
	if mark == null:
		mark = _build_party_mark()
	mark.modulate = Color(wanted.r, wanted.g, wanted.b, Balance.PARTY_MARK_ALPHA)
	mark.scale = Vector2.ONE * Balance.PARTY_MARK_SCALE
	# Only ever drawn in company. One player does not need to be told which
	# player they are.
	mark.visible = showing

	_tint = Color.WHITE.lerp(wanted, Balance.PARTY_TINT_STRENGTH) if showing \
		else Color.WHITE
	if sprite != null:
		sprite.modulate = _tint

	# **The light too, and it is the cue that carries furthest.** A hero's light
	# reaches well past their body, so after dark it says who is where long
	# before a silhouette is readable - and this game is mostly played after
	# dark. Leaving it the same warm white for everybody threw away the one
	# identifier that was already on screen.
	if _light != null and is_instance_valid(_light):
		_light.color = Balance.HERO_LIGHT_COLOUR.lerp(wanted,
			Balance.PARTY_LIGHT_STRENGTH) if showing 			else Balance.HERO_LIGHT_COLOUR


## The name over the head, in co-op. Owner brief, 2026-09-12: the Warden's
## name displayed above players' heads in multiplayer games. Empty hides it.
var _nameplate: Label = null


func set_nameplate(text: String) -> void:
	if text.is_empty():
		if _nameplate != null:
			_nameplate.visible = false
		return
	if _nameplate == null:
		_nameplate = Label.new()
		_nameplate.name = "Nameplate"
		_nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_nameplate.add_theme_font_size_override("font_size", 13)
		_nameplate.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		_nameplate.add_theme_constant_override("outline_size", 4)
		_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nameplate.z_as_relative = false
		_nameplate.z_index = Balance.HEALTH_BAR_Z
		_nameplate.size = Vector2(200.0, 20.0)
		_nameplate.position = Vector2(-100.0, -Balance.HERO_NAMEPLATE_LIFT)
		add_child(_nameplate)
	_nameplate.text = text
	_nameplate.add_theme_color_override("font_color", _tint.lerp(Color.WHITE, 0.45))
	_nameplate.visible = true


func _build_party_mark() -> Node2D:
	var ring := Sprite2D.new()
	ring.name = "PartyMark"
	ring.texture = LightKit.falloff_texture()
	ring.scale = Vector2.ONE * Balance.PARTY_MARK_SCALE
	ring.position.y = Balance.PARTY_MARK_LIFT
	# Under everything, and *relative* so the entity root's y-sorting still
	# places it against the ground rather than lifting it out of the scene.
	ring.z_as_relative = true
	ring.z_index = -3
	add_child(ring)
	return ring


func _restore_presence() -> void:
	sprite.visible = true
	sprite.modulate = _tint
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
	# Blood, in proportion to the damage taken. Driven here because this is the
	# function that already owns how the hero looks, and it runs whether the
	# hero is this machine's or a mirrored one - a partner across the field
	# should be visibly hurt too.
	# Asked once, not once a frame. `attach` answers null for a sprite that
	# already has a material, so retrying on null meant retrying for ever.
	if not _blood_tried:
		_blood_tried = true
		_blood = BloodStain.attach(sprite, get_instance_id())
	BloodStain.drive(_blood, health.ratio(), _delta)
	if _flash_left > 0.0:
		BloodStain.strike(_blood, _impact_direction)
	BloodStain.drive_impact(_blood, _flash_left)
	# Eight authored facings already point the right way. Flipping on top of
	# them mirrors the western rows twice and puts the blade in the wrong hand.
	sprite.flip_h = _facing.x < -0.001 if frames == null or not frames.has_frames() else false

	# **Composed with the seat colour, not written over it.**
	#
	# This runs every frame and used to start from white, so a tinted hero was
	# repainted plain on the very next tick and the party colours vanished the
	# moment anybody moved. The hurt flash still wins outright while it lasts -
	# it is a readout the player needs more than the colour.
	var tint: Color = _tint
	if _flash_left > 0.0:
		tint = Balance.HIT_FLASH_COLOUR.lerp(_tint, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)
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
	# The beast's footfall shoves the hero through `_shoved`, and that
	# shove is real motion - the body slides - but it is not a stride. Reading
	# it as one played the walk cycle every time the deck pitched, and on a
	# stopped beast the impulse decays over most of a second, so the hero was
	# walking on the spot for the first second of every Preparation.
	var own: Vector2 = velocity - _shoved
	var speed: float = own.length()
	if speed > 4.0:
		# **The stride is scaled against the walking speed, not the current one.**
		# Dividing by `move_speed()` while sprinting gives a ratio near one and
		# the legs would go at exactly the pace they do walking, which is what
		# covering more ground at the same cadence looks like: ice.
		var pace: float = speed / maxf(Balance.HERO_MOVE_SPEED, 1.0)
		if _sprinting:
			pace *= Balance.HERO_SPRINT_STRIDE
		frames.set_speed_scale(pace)
		# `HeroAnimator` tolerates a missing sheet by design, so `hero_sprint.png`
		# drops in the day it exists and nothing else changes. Until then a run is
		# the walk driven faster with the engine's own lean, bounce and footfall
		# squash on top - which is what those were built to supply.
		# **A rider sits.** The legs belong to the horse while the Warden is up,
		# and a walk cycle on a mounted sprite is a person running on the spot
		# in mid-air. The engine's lean and bounce still play on top, which is
		# what gives a gallop its weight without a mounted sheet existing.
		frames.play("idle" if _mount != null
			else ("sprint" if _sprinting and frames.has_state("sprint") else "walk"))
	else:
		frames.play("idle")
	# **The run's posture, from the engine.** The sheets are deliberately neutral
	# - see `HeroAnimator` - so the lean and the lower stance that separate a
	# sprint from a fast walk are supplied here rather than drawn into frames,
	# which is also the only way to have them at all: the Warden's own PixelLab
	# character no longer exists, so a hand-posed sprint sheet is not a
	# generation away.
	animator.drive(own.normalized() if speed > 4.0 else Vector2.ZERO,
		1.0 if _sprinting else 0.0)


## **The work pose.** Asked for by `Gathering` when a swing starts.
##
## The heavy swing sheet rather than a sheet of its own, and that is a choice
## rather than a gap. The Warden's frames came from a PixelLab character that no
## longer exists in the account, so a new eight-direction state is not a
## generation away - and at 168x160 an axe into a trunk and a two-handed sword
## into a body are the same body doing the same thing. What matters is that the
## hero visibly *works*, facing the thing they are working, once per swing and
## in time with it.
##
## If a dedicated chop and mine sheet are ever drawn, they drop in here by name
## and nothing else changes.
func play_work_swing(toward: Vector2) -> void:
	if frames == null:
		return
	var facing: Vector2 = toward - global_position
	if facing.length_squared() > 1.0:
		frames.set_facing(facing.normalized())
	var state: String = "attack_3" if frames.has_state("attack_3") else "attack_1a"
	_lock_frames(state)


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


## The line a drawn bow puts in front of the hero.
##
## **A thumb stick has no cursor.** Aim on a phone is a direction and nothing
## else, so a player firing a bow was pointing at something they could not see -
## which is half of "ensure that mobile users are able to use ranged weapons and
## aim perfectly accurately". The other half was that there was no way to fire at
## all; `TouchInput` grew a trigger for that.
##
## Drawn for the mouse too, because it is the visible proof of the fix beside it:
## the guide leaves `combat_origin()` along the same vector the arrow does, so if
## the two ever disagree again it is on screen rather than in a bug report.
func _build_aim_guide() -> void:
	_aim_guide = Line2D.new()
	_aim_guide.name = "AimGuide"
	_aim_guide.width = Balance.HERO_AIM_GUIDE_WIDTH
	_aim_guide.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_aim_guide.end_cap_mode = Line2D.LINE_CAP_ROUND
	# Tapered to nothing at the far end: a line of even weight reads as a laser
	# sight, and the hero is holding a bow.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(1.0, 0.05))
	_aim_guide.width_curve = taper
	_aim_guide.z_index = Balance.VFX_Z - 1
	_aim_guide.visible = false
	add_child(_aim_guide)


func _update_aim_guide() -> void:
	if _aim_guide == null:
		return
	# Only for the hero this player is driving. A partner's aim line across the
	# field would be four lines in a full party and none of them yours.
	var wanted: bool = ranged != null and ranged.armed() and is_alive() \
		and can_fight() and input != null and input.is_local()
	_aim_guide.visible = wanted
	if not wanted:
		return
	var body: Vector2 = combat_origin() - global_position
	_aim_guide.points = PackedVector2Array([
		body + _aim * Balance.HERO_AIM_GUIDE_START,
		body + _aim * Balance.HERO_AIM_GUIDE_LENGTH,
	])
	var kind: AmmoData = ranged.nocked()
	var tint: Color = TowerData.element_colour(kind.element) if kind != null \
		and kind.element >= 0 else Color("e8d9b0")
	tint.a = Balance.HERO_AIM_GUIDE_DRAWING_ALPHA if ranged.is_drawing() \
		else Balance.HERO_AIM_GUIDE_ALPHA
	_aim_guide.default_color = tint


## Drinks the first thing being carried that is meant to be drunk.
##
## **Dispatched on the effect, never on the id.** The whole point of the
## consumable rework is that this function does not know what a Draught is; a new
## tonic is a `.tres` and, at most, one arm here. `item_check` fails the build if
## anything is authored against an effect this does not answer.
##
## Automatic items are skipped: a Draught is an insurance policy that spends
## itself when it is needed, and letting a player waste one on a button is a
## worse outcome than the button doing nothing.
func use_carried_item() -> bool:
	if health == null or health.is_dead:
		return false
	var ids: Array = RunState.held_items.keys()
	ids.sort()
	for id: Variant in ids:
		var kind: ItemData = ContentDB.item(String(id))
		if kind == null or kind.automatic:
			continue
		match kind.effect:
			ItemData.Effect.MEND:
				if health.current_hp >= health.max_hp:
					# Refused rather than spent. A full-health player pressing
					# the button by accident should not lose the tonic.
					EventBus.preparation_warning.emit("Already at full health.")
					return false
				if not RunState.spend_item(kind.id):
					return false
				health.heal(health.max_hp * kind.effect_value)
				Vfx.ring(combat_origin(), 92.0, Color(0.52, 0.94, 0.60, 0.80), 0.45, 6.0)
				Vfx.spark(global_position, Color("bdffcf"), 14, Vector2.UP, 170.0)
			ItemData.Effect.WARD:
				if not RunState.spend_item(kind.id):
					return false
				health.add_shield(health.max_hp * kind.effect_value)
				Vfx.ring(combat_origin(), 104.0, Color(0.60, 0.78, 1.0, 0.82), 0.55, 7.0)
				Vfx.spark(global_position, Color("cfe2ff"), 16, Vector2.UP, 150.0)
			_:
				continue
		EventBus.preparation_warning.emit(kind.display_name)
		return true
	return false


# --- The bonded spirit -------------------------------------------------------

## The Wildlife Spirit walking with this hero, or null.
##
## A child of the hero's concerns rather than of the battlefield's, for the same
## reason `attack`, `ranged` and `spells` are: it belongs to *this* hero, and in
## co-op two heroes each have their own. It is parented to the field so it sorts
## and draws with everything else standing on the ground.
var spirit: Companion = null


## Brings the equipped spirit onto whatever field the hero is standing on.
##
## Called when the field changes and when the equipment does, so a spirit
## follows the hero into a raid and a change made at the shrine takes effect on
## the road rather than on the next run.
##
## Only the local player's own hero summons one. A partner's spirit is their
## business and their save; mirroring it would mean sending a whole second
## companion's state across the wire for something cosmetic to the other player.
func _refresh_spirit() -> void:
	# The local player's own hero only. A partner's spirit is their save and
	# their business; mirroring it would put a second companion on the wire
	# for something the other player only ever sees.
	if not is_inside_tree() or input == null or not input.is_local():
		return
	# **Sent away stays away.** The spirit is a toggle now (owner brief,
	# 2026-09-13): calling one costs a meal, keeping one costs Food while it
	# is out, and a player who cannot or does not want to pay sends it home.
	# **An animal taken out of the pen walks ahead of a bonded spirit.**
	#
	# One companion at a time is the bound §54's cut left standing, so when the
	# Warden has taken a raised animal out that is the one at their shoulder. It
	# is not a stronger spirit - the same variant, the same rarity, the same
	# power scale - it is *that creature*, and the difference is that it does not
	# come back if it goes down.
	var raised: Dictionary = MetaState.pen_companion()
	var wanted: String = ""
	if RunState.spirit_called:
		wanted = SpiritBond.key(String(raised.get("species", "")),
			int(raised.get("rarity", 0)), bool(raised.get("shiny", false))) 			if not raised.is_empty() else MetaState.equipped_spirit
	var from_pen: bool = not raised.is_empty() and not wanted.is_empty()
	if spirit != null and is_instance_valid(spirit):
		if spirit.spirit_key == wanted and spirit.field == field 				and spirit.from_pen == from_pen:
			return
		spirit.dismiss()
		spirit = null
	if wanted.is_empty() or field == null:
		return
	var kind := ContentDB.wildlife_kinds.get(
		SpiritBond.species_of(wanted), null) as WildlifeData
	if kind == null:
		return
	spirit = Companion.new()
	spirit.spirit_key = wanted
	spirit.from_pen = from_pen
	spirit.setup(SpiritBond.companion_form(kind, wanted), self, field)
	spirit.global_position = global_position \
		+ Vector2.RIGHT.rotated(randf() * TAU) * 90.0
	# Into the sorted layer with everything else that stands on the ground.
	# Parented to the field itself, the companion sat beside the ground and
	# the cloud layers and sorted against them by its own z - which put it
	# under the ground on one side of the town and over the weather on the
	# other. Reported as "companions become invisible past a certain y".
	var layer: Node = field.get("entity_root") as Node
	(layer if layer != null else field).add_child(spirit)


## A fish handed to somebody: the spirit at your shoulder, or a player beside
## you who is hurt. Only the hero that gave it answers - the pantry belongs to
## whoever caught the fish (owner brief, 2026-09-13).
func _on_fish_given(fish_id: String, to: String) -> void:
	if not is_local_player():
		return
	var kind: FishData = ContentDB.fish(fish_id)
	if kind == null:
		return
	if to == "spirit":
		if spirit != null and is_instance_valid(spirit):
			spirit.feed(kind)
		return
	var ally: Hero = nearest_hurt_ally()
	if ally == null:
		return
	if ally.health != null:
		if kind.heal_fraction > 0.0:
			ally.health.heal(ally.health.max_hp * kind.heal_fraction)
		if kind.shield_fraction > 0.0:
			ally.health.add_shield(ally.health.max_hp * kind.shield_fraction)
	ally.take_meal_buff(kind)
	Vfx.ring(ally.combat_origin(), 54.0, kind.rarity_colour(), 0.4, 4.0)
	Sfx.play("sfx_ui_confirm", -2.0)


## The nearest other hero in reach who has actually lost something, or null.
##
## "Who is hurt" rather than "who is nearest", for the same reason the well
## pours for the most hurt: handing a meal to somebody at full health is a
## meal thrown away, and the cap counts it.
func nearest_hurt_ally() -> Hero:
	var best: Hero = null
	var best_distance: float = Balance.FISH_SHARE_RANGE
	for node: Node in get_tree().get_nodes_in_group(GROUP_ANY):
		var who := node as Hero
		if who == null or who == self or not is_instance_valid(who):
			continue
		if who.health == null or who.health.is_dead:
			continue
		# **`current_hp`, not `current`.** Read as `current` since it was written,
		# which GDScript resolves at *runtime* on a `Node` - so every call
		# errored, `has_hurt_ally` was never true, and the Share button on a fish
		# had never once appeared. Reported by the owner as "sharing a catch
		# doesn't show the ability to share it".
		if who.health.current_hp >= who.health.max_hp:
			continue
		var distance: float = who.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = who
	return best


## Whether there is somebody beside this hero worth handing a fish to.
func has_hurt_ally() -> bool:
	return nearest_hurt_ally() != null


# --- The six that used to do nothing (2026-09-13) -----------------------------

## No Ground Given: the answered blow fades if it is not spent.
##
## Called from the hero's own tick, so it is suspended with the battlefield like
## everything else the hero owns.
func tick_guard(delta: float) -> void:
	_guard_left = maxf(_guard_left - delta, 0.0)


## And spent, by the swing that used it.
func spend_guard() -> void:
	_guard_left = 0.0


func is_guarded() -> bool:
	return _guard_left > 0.0


## **Open Vein.** A body with nothing else near it is a body you have time to
## place a blow on, and this is the chance of placing one.
##
## Rolled per body rather than per swing, so a finisher into a crowd is not a
## lottery ticket for the whole crowd - the node's own text is about *isolated*
## enemies, and a crowd has none in it by definition.
func telling_blow(enemy: Node2D) -> float:
	var chance: float = DisciplineEffects.trained_value("isolated_crit")
	if chance <= 0.0 or enemy == null or field == null:
		return 1.0
	var near: Array = field.enemies_near(enemy.global_position,
		Balance.DISCIPLINE_ISOLATED_RADIUS)
	# Itself, and nobody else.
	if near.size() > 1:
		return 1.0
	if RunState.rng("combat").randf() >= chance:
		return 1.0
	return 2.0
