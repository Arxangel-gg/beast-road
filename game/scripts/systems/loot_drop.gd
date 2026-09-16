class_name LootDrop
extends Node2D

## A dropped reward that flies to the nearest hero when they come near.
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

## Identity across the wire, assigned by the host. 0 means local-only.
var net_id: int = 0

## True when the host decides whether this is collected and this machine only
## draws it. A guest's drops are pictures of the host's.
var puppet: bool = false

var currency: String = ""
var amount: int = 0
var gear: Dictionary = {}

## The plan this drop teaches, or "". Blueprints ride the ordinary loot path
## rather than getting a system of their own: they scatter, glow, magnetise and
## are picked up exactly like everything else, because a discovery the player has
## to walk over is a discovery they notice.
var blueprint: String = ""
## Set down by a player rather than shaken out of something that died.
##
## It changes two things and deliberately nothing else: the drop lasts far
## longer, and it never expires into the void without being offered back. A
## piece a player put on the floor is a message to somebody, and the road
## should not eat it while they are walking over.
var player_dropped: bool = false

var _sprite: Sprite2D
var _velocity: Vector2 = Vector2.ZERO
var _life: float = 0.0
var _homing: bool = false
var _glow: Sprite2D
## The plate naming this drop, on gear and blueprints only.
var _plate: Label = null
var _beacon: Sprite2D
var _orbiters: Array[Sprite2D] = []
var _glow_colour: Color = Balance.LOOT_GLOW_COLOUR
var _glow_size: float = Balance.LOOT_GLOW_SIZE
var _material: ShaderMaterial = null
var _taken: bool = false

const LOOT_SHADER: String = "res://scripts/shaders/loot_polish.gdshader"


func setup(currency_id: String, value: int, from: Vector2) -> void:
	currency = currency_id
	amount = value
	position = from
	# Thrown clear of the corpse so a pack that dies together does not leave one
	# stacked pile that reads as a single coin.
	var angle: float = randf() * TAU
	_velocity = Vector2.RIGHT.rotated(angle) * randf_range(
		Balance.LOOT_SCATTER_SPEED * 0.4, Balance.LOOT_SCATTER_SPEED)
	if currency == Balance.MENDER_SPARK_ID:
		_glow_colour = Color(0.44, 0.96, 0.62, 0.72)
		_glow_size = Balance.GEAR_DROP_GLOW_SIZE
	elif currency == Balance.HEALING_ORB_ID:
		# Crimson against the Spark's green. Two recoveries that glowed alike
		# would teach the player that one of them is the other, and they are
		# deliberately opposite halves of the same idea.
		_glow_colour = Balance.HEALING_ORB_COLOUR
		_glow_size = Balance.GEAR_DROP_GLOW_SIZE
	elif currency == Balance.SUPPLY_CRATE_ID:
		_glow_colour = Balance.SUPPLY_CRATE_COLOUR
		_glow_size = Balance.GEAR_DROP_GLOW_SIZE


## A plan on the ground. Rarity drives the glow, so a legendary recipe announces
## itself across the field the way a legendary weapon would.
func setup_blueprint(plan_id: String, from: Vector2) -> void:
	blueprint = plan_id
	position = from
	var plan := ContentDB.blueprints.get(plan_id, null) as BlueprintData
	var rank: int = ["common", "uncommon", "rare", "legendary"].find(
		plan.rarity if plan != null else "common")
	_glow_colour = Balance.GEAR_RARITY_COLOURS[clampi(rank, 0,
		Balance.GEAR_RARITY_COLOURS.size() - 1)]
	_glow_colour.a = 0.62
	_glow_size = Balance.GEAR_DROP_GLOW_SIZE
	_velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(
		Balance.LOOT_SCATTER_SPEED * 0.55, Balance.LOOT_SCATTER_SPEED * 1.15)


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
		var recovery: Resource = ContentDB.recovery_drop(currency)
		var painted: String = String(recovery.call("get_sprite_path")) if recovery != null \
			else Balance.LOOT_ART_FORMAT % currency
		if ResourceLoader.exists(painted):
			_sprite.texture = load(painted)
		else:
			_sprite.texture = IconKit.ui(currency)
	if _sprite.texture != null:
		_sprite.scale = Vector2.ONE * (icon_size
			/ maxf(_sprite.texture.get_width(), 1.0))
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	if Graphics.polish_shaders() and ResourceLoader.exists(LOOT_SHADER):
		_material = ShaderMaterial.new()
		_material.shader = load(LOOT_SHADER) as Shader
		_material.set_shader_parameter("rarity_colour", _glow_colour)
		_material.set_shader_parameter("shimmer_strength", Balance.LOOT_SHIMMER_STRENGTH)
		_material.set_shader_parameter("seed", float(get_instance_id() % 997))
		_material.set_shader_parameter("pickup", 0.0)
		_sprite.material = _material
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
	_build_attention_fx()
	_build_name_plate()

	add_child(_sprite)
	z_index = Balance.LOOT_Z_INDEX
	Sfx.play_group("loot_drop")

	# **It arrives, rather than being there.** The scatter already threw drops
	# clear of the corpse, but each one appeared at full size with no moment of
	# its own, so a wave's spoils read as inventory materialising. A short pop
	# that overshoots gives the eye a change in size to catch, which is what
	# makes a coin land instead of exist.
	var pop: Tween = create_tween()
	pop.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale = Vector2.ONE * Balance.LOOT_POP_FROM
	pop.tween_property(self, "scale",
		Vector2.ONE * Balance.LOOT_POP_OVERSHOOT, Balance.LOOT_POP_TIME * 0.6)
	pop.tween_property(self, "scale", Vector2.ONE, Balance.LOOT_POP_TIME * 0.4)


func _process(delta: float) -> void:
	if _taken:
		return
	_life += delta
	# The *nearest* hero, not the one holding the hero group.
	#
	# That group answers "which hero does the HUD describe", which is this
	# machine's own - so in co-op every coin on the field flew to the host and
	# ignored the guest standing on top of it.
	var hero: Node2D = _nearest_hero()
	if hero != null and is_instance_valid(hero):
		var to_hero: Vector2 = hero.global_position - global_position
		var distance: float = to_hero.length()
		if distance <= Balance.LOOT_COLLECT_RANGE:
			_collect(hero as Hero)
			return
		# Once homing, always homing. Without the latch a drop at the edge of the
		# magnet stutters in and out of range as the hero moves, and reads as
		# broken rather than as out of reach.
		# A Curious spirit is a second magnet with the hero's address.
		#
		# It nudges the *latch* rather than the destination: what it finds still
		# flies to the player, so the trait widens the net without changing who
		# gets paid - which matters in co-op, where each machine already homes
		# loot to its own hero.
		if _homing or distance <= Balance.LOOT_MAGNET_RANGE 				or _noticed_by_companion():
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
	if _beacon != null:
		var spire: ShaderMaterial = _beacon.material as ShaderMaterial
		if spire != null:
			spire.set_shader_parameter("clock", _life)
		# **The plate fades with distance** rather than being drawn at full
		# strength across the whole field: near the hero it is a label, far
		# away it would be one more piece of text over the fight.
		if _plate != null:
			var who: Node2D = _nearest_hero()
			var gap: float = global_position.distance_to(who.global_position) 				if who != null else Balance.LOOT_PLATE_FADE_RANGE
			_plate.modulate.a = clampf(
				1.0 - gap / maxf(Balance.LOOT_PLATE_FADE_RANGE, 1.0), 0.0, 1.0)
		var beam_pulse: float = 0.88 + 0.12 * sin(_life * 2.1)
		_beacon.modulate.a = Balance.LOOT_BEACON_ALPHA * beam_pulse
		_beacon.scale.x = Balance.LOOT_BEACON_WIDTH * (0.92 + 0.08 * beam_pulse) \
			/ maxf(float(_beacon.texture.get_width()), 1.0)
	for index: int in _orbiters.size():
		var mote: Sprite2D = _orbiters[index]
		var angle: float = _life * Balance.LOOT_ORBIT_SPEED \
			+ TAU * float(index) / float(maxi(_orbiters.size(), 1))
		mote.position = Vector2(cos(angle) * Balance.LOOT_ORBIT_RADIUS.x,
			sin(angle) * Balance.LOOT_ORBIT_RADIUS.y - 5.0)
		mote.modulate.a = 0.48 + 0.34 * (0.5 + 0.5 * sin(angle * 1.7))

	var span: float = Balance.LOOT_PLAYER_DROP_LIFETIME if player_dropped 		else Balance.LOOT_LIFETIME
	if _life >= span:
		# Expiry fades rather than vanishing, and pays out anyway. Losing a reward
		# already earned by killing the thing teaches a player to stop fighting
		# and stand on the road hoovering, which is worse than either extreme.
		if currency == Balance.MENDER_SPARK_ID 				or currency == Balance.HEALING_ORB_ID:
			# **Recoveries expire; they are not paid out.** Everything else is a
			# reward already earned by the kill, and taking it back would teach
			# the player to stop fighting and hoover. A heal is different: it is
			# earned by *going and getting it*, and one that arrived by itself
			# would remove the only decision an orb poses.
			_expire_special()
		else:
			_collect(hero as Hero)


## Persistent, low-cost motion around the drop. The shimmer lives inside the
## icon and can disappear into a similarly coloured road; these two motes and a
## narrow vertical glow change the silhouette around it, which remains readable
## on Low quality and at the fully zoomed-out camera.
func _build_attention_fx() -> void:
	var light: Texture2D = LightKit.falloff_texture()
	if light == null:
		return
	# **A column, not a blob.** A stretched falloff sprite says "something
	# glows here" and nothing else; the spire shader gives it a hot core, a
	# flared foot and motes climbing it, and scales all three by how rare the
	# drop is - so an Oathbound piece is findable across a field of foliage and
	# a copper coin is a candle. See `loot_beacon.gdshader`.
	var rich: float = _richness()
	var tall: float = Balance.LOOT_BEACON_HEIGHT 		* lerpf(1.0, Balance.LOOT_BEACON_RARE_HEIGHT, rich)
	var wide: float = Balance.LOOT_BEACON_WIDTH 		* lerpf(1.0, Balance.LOOT_BEACON_RARE_WIDTH, rich)
	_beacon = Sprite2D.new()
	_beacon.name = "PickupBeacon"
	_beacon.texture = light
	_beacon.modulate = Color(_glow_colour, Balance.LOOT_BEACON_ALPHA)
	_beacon.scale = Vector2(wide / maxf(float(light.get_width()), 1.0),
		tall / maxf(float(light.get_height()), 1.0))
	_beacon.position.y = -tall * 0.30
	_beacon.z_index = -1
	if DisplayServer.get_name() != "headless":
		var spire := ShaderMaterial.new()
		spire.shader = load("res://scripts/shaders/loot_beacon.gdshader")
		spire.set_shader_parameter("richness", rich)
		spire.set_shader_parameter("tint", Color(_glow_colour, 1.0))
		_beacon.material = spire
	add_child(_beacon)

	for index: int in Balance.LOOT_ORBIT_COUNT:
		var mote := Sprite2D.new()
		mote.name = "PickupMote%d" % index
		mote.texture = light
		mote.modulate = Color(_glow_colour, 0.72)
		mote.scale = Vector2.ONE * (Balance.LOOT_ORBIT_SIZE
			/ maxf(float(light.get_width()), 1.0))
		mote.z_index = 1
		add_child(mote)
		_orbiters.append(mote)


## The spray when a drop is taken, in the drop's own colour.
##
## Rarity was visible while a piece lay on the ground and invisible at the moment
## it was collected, which is the moment the player is actually looking at it.
## **How a pickup sounds: a streak that climbs, and a weight from its rarity.**
##
## Static, because the streak belongs to the *player* rather than to any one
## drop, and the drop that raises it is freed a frame later.
static var _streak: int = 0
static var _last_pickup_msec: int = 0


## Plays the pickup, pitched.
##
## Hoovering a burst of drops climbs - each pickup inside `LOOT_STREAK_WINDOW`
## of the last is a semitone-ish higher, to a ceiling, and the ladder resets the
## moment the player stops. That is the whole of the "escalating pickup audio"
## the notes asked for, and it is what turns six coins from one sound six times
## into a run of them.
##
## Rarity pulls the other way: a rarer piece lands *lower* and a little louder,
## so a Beastcalled sword reads as weight rather than as the top of a scale -
## and cannot be confused with the sixth coin in a row.
##
## Audio only. Nothing here is read by anything that decides a payout.
func _pickup_sound() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_pickup_msec > int(Balance.LOOT_STREAK_WINDOW * 1000.0):
		_streak = 0
	else:
		_streak += 1
	_last_pickup_msec = now
	var shift: float = minf(float(_streak) * Balance.LOOT_STREAK_PITCH_STEP,
		Balance.LOOT_STREAK_PITCH_MAX)
	var louder: float = 0.0
	if not gear.is_empty():
		var rarity: int = int(gear.get("rarity", 0))
		shift -= float(rarity) * Balance.LOOT_RARITY_PITCH_DROP
		louder = float(rarity) * Balance.LOOT_RARITY_DB
	Sfx.play_group("loot_collect", louder, shift)


func _burst() -> void:
	Vfx.spark(global_position, _glow_colour, Balance.LOOT_TAKE_SPARKS,
		Vector2.UP, Balance.LOOT_TAKE_SPEED)


## Whichever hero is closest, of however many there are.
func _nearest_hero() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not who.is_alive():
			continue
		var distance: float = global_position.distance_to(who.global_position)
		if distance < best_distance:
			best_distance = distance
			best = who
	return best


## Taken on the host's say-so: the feedback without the payout.
##
## A guest still gets the pop, the number and the sound, because that is what
## tells the player their friend picked something up. It does not gain the
## currency, because `RunState` already has it from the host.
func collect_mirrored() -> void:
	if _taken:
		return
	_taken = true
	_pickup_sound()
	if currency == Balance.MENDER_SPARK_ID or currency == Balance.HEALING_ORB_ID:
		Vfx.ring(global_position, _glow_size * 0.62, _glow_colour, 0.42, 5.0)
		_burst()
	elif gear.is_empty() and amount > 0:
		Vfx.number(global_position, float(amount), Balance.LOOT_GLOW_COLOUR, false)
	else:
		Vfx.ring(global_position, _glow_size * 0.55, _glow_colour, 0.32, 4.0)
	_dissolve_and_free()


## What this drop is worth to a thief, 0 for a thing a thief cannot carry:
## gear by its rarity, Gold by the coin, anything else by less. A crate, an
## orb, a spark and a blueprint are not carried off, and neither is a piece a
## player put down on purpose.
func steal_worth() -> float:
	if puppet or _taken or player_dropped or _homing:
		return 0.0
	if not gear.is_empty():
		return 2.0 + float(int(gear.get("rarity", 0)))
	if not blueprint.is_empty() or currency == Balance.SUPPLY_CRATE_ID \
			or currency == Balance.HEALING_ORB_ID or currency == Balance.MENDER_SPARK_ID:
		return 0.0
	if amount <= 0 or currency.is_empty():
		return 0.0
	return float(amount) / (40.0 if currency == RunState.GOLD else 120.0)


## A thief takes it: the drop is gone from every machine and nobody is paid;
## what it held comes back as the thief's own. Empty when it could not be.
func steal() -> Dictionary:
	if steal_worth() <= 0.0:
		return {}
	_taken = true
	if net_id != 0:
		EventBus.coop_loot_taken.emit(net_id)
	var held: Dictionary = {"currency": currency, "amount": amount, "gear": gear.duplicate(true)}
	Vfx.dust(global_position, Color(0.5, 0.45, 0.4), 5, 30.0)
	_dissolve_and_free()
	return held


func is_taken() -> bool:
	return _taken


func _collect(who: Hero = null) -> void:
	# A guest's drop is a picture. The host decides what was picked up and says
	# so, or two machines would each bank the same coin.
	if puppet or _taken:
		return
	_taken = true
	if net_id != 0:
		EventBus.coop_loot_taken.emit(net_id)
	if currency == Balance.SUPPLY_CRATE_ID:
		_break_open()
	elif currency == Balance.HEALING_ORB_ID:
		# `amount` is health, decided by the body that dropped it. Read from the
		# drop rather than recomputed, so an orb lying on the road for twenty
		# seconds is still worth what the thing that died was worth.
		if who != null and is_instance_valid(who):
			who.drink_healing_orb(float(amount))
		_pickup_sound()
		Vfx.ring(global_position, _glow_size * 0.6, _glow_colour, 0.36, 4.0)
		_burst()
	elif currency == Balance.MENDER_SPARK_ID:
		if who != null and is_instance_valid(who):
			who.apply_mender_spark()
		_pickup_sound()
		Vfx.ring(global_position, _glow_size * 0.62, _glow_colour, 0.42, 5.0)
		_burst()
	elif not blueprint.is_empty():
		_learn_it()
	elif not gear.is_empty():
		var result: Dictionary = MetaState.receive_gear(gear)
		var stored: bool = bool(result.get("stored", false))
		var salvaged: int = int(result.get("shards", 0))
		var kind: GearData = ContentDB.gear(String(gear.get("kind", "")))
		var title: String = kind.display_name if kind != null else "Gear"
		var outcome: String = "taken to the stash" if stored \
			else "stash full  ·  broken into %d Shards" % salvaged
		# The banner escalates with the ring, so the words and the light agree.
		# A Runed find that the screen flashes for and the text mentions in the
		# same grey sentence as a Worn buckle reads as a bug in one of the two.
		var rarity: int = clampi(int(gear.get("rarity", 0)), 0,
			Stash.RARITY_NAMES.size() - 1)
		if rarity >= 3:
			EventBus.preparation_warning.emit("%s %s  ·  %s" % [
				Stash.rarity_name(gear).to_upper(), title.to_upper(), outcome])
		else:
			EventBus.preparation_warning.emit("%s  %s  ·  %s" % [
				Stash.rarity_name(gear), title, outcome])
		EventBus.gear_collected.emit(gear, stored, salvaged, global_position)
		_pickup_sound()
		_celebrate_gear()
		_burst()
	elif amount > 0 and not currency.is_empty():
		RunState.gain_currency(currency, amount)
		_pickup_sound()
		Vfx.number(global_position, float(amount), Balance.LOOT_GLOW_COLOUR, false)
		# Taken, not merely deducted. The number said what was gained and nothing
		# said it had been picked *up* - so collecting a coin looked the same as
		# a coin timing out, which is the one distinction a player cares about.
		_burst()
		EventBus.loot_collected.emit(currency, amount, global_position)
	_dissolve_and_free()


## The pickup, sized to what was picked up.
##
## Every rarity used to get the same 0.32-second ring. The glow on the ground
## already said "this one is gold" and then the moment of taking it said nothing
## at all - so the single best event in a loot game landed with the same weight
## as a Worn buckle, and a player farming for hours had no beat to farm *for*.
##
## The bottom two rarities are deliberately left almost alone. A flash and a
## camera kick on every common drop is not celebration, it is a screen that
## twitches constantly and teaches the player to ignore it. Rays start at Fine,
## the flash at Runed, and the camera moves for Oathbound and nothing else in
## this system - so when it does move, it means one thing.
func _celebrate_gear() -> void:
	var rarity: int = clampi(int(gear.get("rarity", 0)), 0,
		Balance.GEAR_PICKUP_RING.size() - 1)
	Vfx.ring(global_position, Balance.GEAR_PICKUP_RING[rarity], _glow_colour,
		Balance.GEAR_PICKUP_RING_LIFE[rarity], 4.0)
	var rays: int = Balance.GEAR_PICKUP_RAYS[rarity]
	if rays > 0:
		Vfx.rays(global_position, _glow_colour, rays,
			Balance.GEAR_PICKUP_RING[rarity] * 0.7, randf() * TAU)
	var flash: float = Balance.GEAR_PICKUP_FLASH[rarity]
	if flash > 0.0:
		Vfx.flash(_glow_colour, flash, 0.42)
	var shake: float = Balance.GEAR_PICKUP_SHAKE[rarity]
	if shake > 0.0:
		# Through the bus rather than by finding a camera. The battlefield and
		# the raid both own one, and a drop has no business knowing which scope
		# it is lying in (working rule 5).
		EventBus.camera_shake_requested.emit(shake, 0.38)


## Bursts the crate and scatters what was inside.
##
## **The crate is a roll you had to walk to.** It breaks on contact rather than
## needing to be attacked, which is deliberate: the decision it poses is the one
## every drop on this road poses - leave the line or leave the reward - and
## making it a second thing to hit would have needed a health component, a hit
## test and a new combat verb to say something the walk already says.
##
## What falls out is spawned as ordinary drops rather than granted directly, so
## the spill is magnetised, replicated and collected by exactly the machinery
## that carries every other reward. In co-op that means the partner can take a
## piece of your crate, which is the same rule that already governs a coin.
##
## Rolled on the host only. `_collect` has already refused for a puppet by the
## time this runs, so a guest never invents contents its host does not have.
func _break_open() -> void:
	var field: Node = get_parent()
	while field != null and not field.has_method("spawn_loot"):
		field = field.get_parent()
	_pickup_sound()
	Vfx.ring(global_position, _glow_size * 0.85, Balance.SUPPLY_CRATE_COLOUR, 0.42, 5.0)
	Vfx.spark(global_position, Balance.SUPPLY_CRATE_COLOUR, 12, Vector2.ZERO, 240.0)
	Vfx.rays(global_position, Balance.SUPPLY_CRATE_COLOUR, 10, 74.0, randf() * TAU)
	_burst()
	if field == null:
		return
	var rng: RandomNumberGenerator = RunState.rng("recovery")
	var spills: int = rng.randi_range(Balance.SUPPLY_CRATE_MIN_SPILLS,
		Balance.SUPPLY_CRATE_MAX_SPILLS)
	for _spill: int in spills:
		if rng.randf() < Balance.SUPPLY_CRATE_ORB_SHARE:
			field.call("spawn_loot", Balance.HEALING_ORB_ID,
				maxi(int(round(Balance.HERO_MAX_HP
					* Balance.HEALING_ORB_BASE_FRACTION)), 1), global_position)
		else:
			var which: String = RunState.CURRENCIES[
				rng.randi_range(0, RunState.CURRENCIES.size() - 1)]
			field.call("spawn_loot", which, maxi(amount, 1), global_position)


## Reads the plan, and hands over the first bow.
##
## **A weapon blueprint gives you the weapon.** Learning how to make a bow and
## then being unable to hold one is a joke at the player's expense; a bow is one
## object, not a batch, so knowing the plan and owning it are the same moment.
## Ammunition works the other way round, which is the whole distinction: the
## knowledge is permanent and the arrows are spent.
func _learn_it() -> void:
	var plan := ContentDB.blueprints.get(blueprint, null) as BlueprintData
	if plan == null:
		return
	var fresh: bool = MetaState.learn_blueprint(plan.id)
	if plan.unlocks_kind == "ranged" and RunState.ranged_id.is_empty():
		RunState.ranged_id = plan.unlocks_id
		# Enough to try it with. A first bow and no arrows is a first bow the
		# player cannot form an opinion about.
		var opener: AmmoData = _first_ammo_for(plan.unlocks_id)
		if opener != null:
			RunState.gain_ammo(opener.id, Balance.RANGED_STARTING_SHOTS)
			RunState.ammo_id = opener.id
	EventBus.preparation_warning.emit("%s  ·  %s" % [plan.display_name,
		"recipe learned" if fresh else "already known"])
	EventBus.blueprint_learned.emit(plan.id, fresh)
	_pickup_sound()
	Vfx.ring(global_position, _glow_size * 0.62, _glow_colour, 0.42, 5.0)
	_burst()


## The plainest ammunition this weapon can fire, which is the one that needs no
## plan of its own.
func _first_ammo_for(weapon_id: String) -> AmmoData:
	var weapon := ContentDB.ranged_weapons.get(weapon_id, null) as RangedWeaponData
	if weapon == null:
		return null
	var ids: Array = ContentDB.ammo_kinds.keys()
	ids.sort()
	for id: Variant in ids:
		var kind := ContentDB.ammo_kinds[id] as AmmoData
		if kind != null and kind.family == weapon.family and kind.known_from_the_start:
			return kind
	return null


func _expire_special() -> void:
	if _taken or puppet:
		return
	_taken = true
	if net_id != 0:
		EventBus.coop_loot_taken.emit(net_id)
	_dissolve_and_free()


## Shader grain peels away while the node rises and shrinks. Payout already
## happened, so this is presentation only and cannot be interrupted into a
## duplicate pickup.
func _dissolve_and_free() -> void:
	set_process(false)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	if _material != null:
		tween.tween_method(_set_pickup_dissolve, 0.0, 1.0,
			Balance.LOOT_PICKUP_DISSOLVE_TIME)
	tween.tween_property(self, "position:y", position.y - 22.0,
		Balance.LOOT_PICKUP_DISSOLVE_TIME)
	tween.tween_property(self, "scale", Vector2.ONE * 0.55,
		Balance.LOOT_PICKUP_DISSOLVE_TIME)
	tween.chain().tween_callback(queue_free)


func _set_pickup_dissolve(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("pickup", value)


## Whether a companion with the Curious temperament is standing near enough to
## have spotted this.
##
## Asked only while the drop is not already homing, and there is at most one
## companion per player - so this is a handful of distance checks a frame in the
## worst case, on things that already exist in a group.
func _noticed_by_companion() -> bool:
	for node: Node in get_tree().get_nodes_in_group(Companion.GROUP):
		var friend := node as Companion
		if friend == null or not is_instance_valid(friend):
			continue
		var reach: float = friend.reveal_radius()
		if reach > 0.0 and friend.global_position.distance_to(global_position) <= reach:
			return true
	return false


## How rare this drop is, 0 for the commonest and 1 for the top of the ladder.
##
## One number, because the spire, the plate and the take-burst all want the
## same answer and asking three times is three chances to disagree. A currency
## drop has no rarity at all and reads as 0 - a coin is a coin.
func _richness() -> float:
	var top: float = maxf(float(Balance.GEAR_RARITY_COLOURS.size() - 1), 1.0)
	if not gear.is_empty():
		return clampf(float(int(gear.get("rarity", 0))) / top, 0.0, 1.0)
	if not blueprint.is_empty():
		var plan := ContentDB.blueprints.get(blueprint, null) as BlueprintData
		var rank: int = ["common", "uncommon", "rare", "legendary"].find(
			plan.rarity if plan != null else "common")
		return clampf(float(maxi(rank, 0)) / top, 0.0, 1.0)
	return 0.0


## The plate that names what is lying there.
##
## **Gear is named by its slot, not by its kind.** "Boots" is the question a
## player on the field actually has - do I care - and which boots they are is a
## question for the stash. It is how Diablo names an unidentified drop and it is
## the right amount of information for something you are deciding whether to
## walk toward.
##
## Only gear and blueprints get one. A coin is self-evident from its own colour,
## and a plate over every copper piece would bury the field in text.
func _build_name_plate() -> void:
	var words: String = _plate_text()
	if words.is_empty():
		return
	_plate = Label.new()
	_plate.name = "PickupPlate"
	_plate.text = words
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_theme_font_size_override("font_size", Balance.LOOT_PLATE_SIZE)
	_plate.add_theme_color_override("font_color",
		Color(_glow_colour.r, _glow_colour.g, _glow_colour.b, 1.0))
	_plate.add_theme_constant_override("outline_size", 5)
	_plate.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.03, 0.9))
	# The backing is a StyleBox on the label rather than a second node: one
	# control, one draw, and it cannot drift out of line with its own text.
	var backing := StyleBoxFlat.new()
	backing.bg_color = Balance.LOOT_PLATE_BACKING
	backing.corner_radius_top_left = 3
	backing.corner_radius_top_right = 3
	backing.corner_radius_bottom_left = 3
	backing.corner_radius_bottom_right = 3
	backing.content_margin_left = Balance.LOOT_PLATE_PAD.x
	backing.content_margin_right = Balance.LOOT_PLATE_PAD.x
	backing.content_margin_top = Balance.LOOT_PLATE_PAD.y
	backing.content_margin_bottom = Balance.LOOT_PLATE_PAD.y
	# A rarity-tinted hairline, so the frame carries the colour too rather than
	# leaving it all to the text.
	backing.border_width_bottom = 2
	backing.border_color = Color(_glow_colour.r, _glow_colour.g, _glow_colour.b, 0.75)
	_plate.add_theme_stylebox_override("normal", backing)
	add_child(_plate)
	_place_plate()


## Centred over the drop, which needs the label's own measured width.
func _place_plate() -> void:
	if _plate == null:
		return
	var wide: float = _plate.get_minimum_size().x
	_plate.position = Vector2(-wide * 0.5, Balance.LOOT_PLATE_LIFT)


## What the plate says, or nothing at all.
func _plate_text() -> String:
	if not gear.is_empty():
		var kind: GearData = ContentDB.gear(String(gear.get("kind", "")))
		if kind != null:
			return kind.slot_name()
		return "Gear"
	if not blueprint.is_empty():
		return "Blueprint"
	return ""
