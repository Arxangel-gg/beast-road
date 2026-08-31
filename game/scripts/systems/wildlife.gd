class_name Wildlife
extends Node2D

const ActorPolishScript = preload("res://scripts/systems/actor_polish.gd")

## The animals that live off the roads.
##
## Wildlife is not part of the wave roster and towers never target it, but a hero
## may hunt it and hostile species may threaten heroes or road enemies. Nothing
## here can target a structure. It exists so the ground reads as inhabited rather
## than merely decorated - a field with a fox crossing it is a place, and the
## same field without one is a texture.
##
## **The population varies on purpose.** Sometimes almost none, sometimes plenty.
## A fixed count reads as decoration however good the sprites are, because the
## eye works out inside a minute that there are always exactly six. So arrivals
## are a coin flip rather than a top-up to a target, each animal has its own
## patience, and the field is allowed to be empty for a while.
##
## One system owns the population, steering and small combat seam. Species share
## the cheap movement core, then use data-authored movement styles and social
## spacing so their behavior differs without a bespoke node tree per animal.

## How often an arrival is considered.
const ARRIVAL_INTERVAL: float = 4.0

## How often a guest is told where the animals are. Slower than the enemy batch
## on purpose: nothing is being aimed at, so a coarser update is invisible.
const BATCH_INTERVAL: float = 0.2

## What an animal is doing.
##
## `STALKING` and `STRIKING` are the hostile half. Deliberately only two: an
## ambient creature with a combat state machine as deep as an enemy's is a
## maintenance cost paid for something the player reads as "the wolf is coming".
enum State { ARRIVING, SETTLED, FLEEING, LEAVING, STALKING, STRIKING }

## The grid, so animals can be kept off the roads. Assigned by the battlefield.
var grid: BattleGrid = null

## Where the sprites are parented, and it is not this node.
##
## They go into the battlefield's y-sorted entity root so each animal sorts
## against the enemies and the hero individually. Parented under this system they
## sorted as one block at *its* position, which is the origin - so every animal
## in the game drew at the depth of the town, in front of things it was behind.
var host: Node2D = null

## The field, so a kill can drop something.
var field: Node = null

var _living: Array[Dictionary] = []
var _arrival_clock: float = 0.0
var _batch_clock: float = 0.0

## Rising identity for relayed animals. Host side.
var _net_id: int = 0
## Rising identity for one social arrival. Guests mirror positions and do not
## need it; the authority uses it for loose cohesion without stacking bodies.
var _group_id: int = 0
var _kinds: Array[WildlifeData] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Its own stream, seeded from the run. Ambient life must never draw from the
	# combat stream, or a seeded replay would produce a different wave because a
	# rabbit happened to turn up.
	_rng.seed = hash("wildlife") ^ RunState.run_seed
	# A hero's swing is the only thing that can kill an animal, and it is heard
	# rather than fought for: putting wildlife in the enemy group would have
	# towers shooting rabbits and waves never ending, which is a far worse bug
	# than not being able to hunt.
	EventBus.hero_swing_resolved.connect(_on_swing_resolved)
	# Replicated so a hunt is shared. A guest whose field held different animals
	# could not help farm one, and would watch its partner swing at nothing.
	EventBus.coop_wildlife_spawned.connect(_on_coop_spawned)
	EventBus.coop_wildlife_batch.connect(_on_coop_batch)
	EventBus.coop_wildlife_removed.connect(_on_coop_removed)
	EventBus.coop_wildlife_died.connect(_on_coop_died)
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void:
		_refresh_kinds()
		# Old residents leave with the old act rather than lingering into ground
		# they do not belong on - a deer standing in Act III ash is worse than an
		# empty field.
		clear())
	_refresh_kinds()


## Which creatures belong in the act we are in.
##
## A deer in the ash of Act III would be saying the wrong thing about the place,
## and describing the place is the entire job.
func _refresh_kinds() -> void:
	_kinds.clear()
	for data: WildlifeData in ContentDB.wildlife():
		if data.acts.is_empty() or data.acts.has(RunState.act):
			_kinds.append(data)


func _process(delta: float) -> void:
	if Graphics.foliage_scale() <= 0.0:
		clear()
		return
	# A guest decides nothing about the wildlife: no arrivals, no wandering, no
	# hunting. Its animals are the host's, mirrored - otherwise the two fields
	# hold different creatures and a shared hunt is impossible.
	if Coop.is_guest():
		_tick_puppets(delta)
		return
	if _is_authority_with_company():
		_batch_clock -= delta
		if _batch_clock <= 0.0:
			_batch_clock = BATCH_INTERVAL
			_send_batch()
	_arrival_clock -= delta
	if _arrival_clock <= 0.0:
		_arrival_clock = ARRIVAL_INTERVAL
		_consider_arrival()
	for index: int in range(_living.size() - 1, -1, -1):
		if _tick_one(_living[index], delta):
			continue
		_retire(index)


## Mirrored animals: walk to where the host said, and animate from that.
##
## The same treatment the enemies get, and for the same reason - a body that is
## repositioned has no velocity, and every animation here is chosen from whether
## the thing is moving.
func _tick_puppets(delta: float) -> void:
	for index: int in range(_living.size() - 1, -1, -1):
		var animal: Dictionary = _living[index]
		var sprite := animal["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			_living.remove_at(index)
			continue
		if float(animal.get("dying", 0.0)) > 0.0:
			if not _tick_dying(animal, sprite, delta):
				_retire(index)
			continue
		var target := animal["goal"] as Vector2
		var before: Vector2 = sprite.global_position
		sprite.global_position = before.lerp(target,
			clampf(delta / BATCH_INTERVAL, 0.0, 1.0))
		var step: Vector2 = sprite.global_position - before
		var kind := animal["data"] as WildlifeData
		if absf(step.x) > 0.001:
			sprite.flip_h = (step.x > 0.0) != kind.art_faces_right
		_animate(animal, sprite, delta, step.length() > 0.5)


## Everything alive, in one packet. Host side.
func _send_batch() -> void:
	var entries: Array = []
	for animal: Dictionary in _living:
		var sprite := animal["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		entries.append([int(animal["net_id"]), sprite.global_position])
	if not entries.is_empty():
		EventBus.coop_wildlife_batch.emit(entries)


## The host put an animal down, so one appears here. Guest side.
func _on_coop_spawned(net_id: int, kind_id: String, at: Vector2) -> void:
	if not Coop.is_guest():
		return
	for data: WildlifeData in ContentDB.wildlife():
		if data.id == kind_id:
			_spawn(data, at, net_id)
			return


func _on_coop_batch(entries: Array) -> void:
	if not Coop.is_guest():
		return
	for entry: Variant in entries:
		var row := entry as Array
		if row == null or row.size() != 2:
			continue
		for animal: Dictionary in _living:
			if int(animal["net_id"]) == int(row[0]):
				animal["goal"] = row[1] as Vector2
				break


func _on_coop_removed(net_id: int) -> void:
	if not Coop.is_guest():
		return
	for index: int in range(_living.size() - 1, -1, -1):
		if int(_living[index]["net_id"]) != net_id:
			continue
		var sprite: Node = _living[index]["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
		_living.remove_at(index)
		return


## The host settled a hunt. Start the same authored fall locally instead of
## leaving an apparently living animal standing until the later removal packet.
func _on_coop_died(net_id: int) -> void:
	if not Coop.is_guest():
		return
	for animal: Dictionary in _living:
		if int(animal["net_id"]) != net_id:
			continue
		if float(animal.get("dying", 0.0)) > 0.0:
			return
		animal["hp"] = 0.0
		animal["dying"] = Balance.WILDLIFE_DEATH_SECONDS
		animal["state"] = State.LEAVING
		var sprite := animal["sprite"] as Sprite2D
		var bar := animal["bar"] as ProgressBar
		if bar != null and is_instance_valid(bar):
			bar.visible = false
		if sprite != null and is_instance_valid(sprite):
			Vfx.blood(_visual_origin(sprite), Vector2.UP,
				Balance.VFX_BLOOD_DEATH_SIZE * 0.75, sprite.global_position)
			Vfx.dust(sprite.global_position, Color("c4552e"), 10, 60.0)
		return


## Takes one animal off the field, and tells the guest it went.
##
## **The single place a removal happens**, which it was not: the kill path
## announced itself and every other path did not. An animal that wandered off or
## ran out of patience was freed on the host and left standing on the guest
## forever - so they piled up, stopped moving because no batch mentioned them
## again, and formed a little crowd of creatures the host had never heard of.
## Reported from play as exactly that.
func _retire(index: int) -> void:
	var animal: Dictionary = _living[index]
	if _is_authority_with_company():
		EventBus.coop_wildlife_removed.emit(int(animal["net_id"]))
	var sprite: Node = animal["sprite"]
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	_living.remove_at(index)


## Perhaps something turns up.
##
## A coin flip rather than a refill to a target count, which is the whole
## difference between a population and a quota. The cap is a ceiling on cost, not
## a number to be reached.
func _consider_arrival() -> void:
	if _kinds.is_empty():
		return
	# Shares the foliage slider rather than adding a second one. Both are ambient
	# scatter, and a player who turns decoration down means all of it.
	var cap: int = int(round(float(Balance.WILDLIFE_MAX) * Graphics.foliage_scale()))
	if _living.size() >= cap:
		return
	# Below the floor, something always comes. Above it, arrival stays a coin
	# flip - that is what keeps the population varying rather than sitting at a
	# quota, while still guaranteeing the field is never empty for long.
	if _living.size() >= Balance.WILDLIFE_MIN 			and _rng.randf() > Balance.WILDLIFE_ARRIVAL_CHANCE:
		return
	var kind: WildlifeData = _pick_kind(_hostile_arrivals_allowed())
	if kind == null:
		return
	# Predators are capped as a group, not weighted down as six species.
	#
	# The weights are what make the roster varied and they are worth keeping. The
	# cap is what keeps variety from becoming pressure: six hostile kinds at 42%
	# of arrivals will, given a long enough road, put a dozen hunters on one
	# field, and that is a second enemy faction rather than a wilderness.
	if kind.is_hostile() and _hostile_count() >= Balance.WILDLIFE_HOSTILE_MAX:
		return
	var at: Vector2 = _clear_point()
	if at == Vector2.ZERO:
		return
	_group_id += 1
	var social_id: int = _group_id
	var placed: Array[Vector2] = []
	for _member: int in _rng.randi_range(kind.group_min, kind.group_max):
		if _living.size() >= cap:
			return
		# Never fall back to the anchor. That fallback put every remaining wolf on
		# the same pixel whenever the nearby rolls touched a road.
		var spread: Vector2 = _social_spawn_point(at, kind, placed)
		if spread == Vector2.INF:
			continue
		placed.append(spread)
		_spawn(kind, spread, 0, social_id)


func _social_spawn_point(anchor: Vector2, kind: WildlifeData,
		placed: Array[Vector2]) -> Vector2:
	var clearance: float = maxf(Balance.WILDLIFE_GROUP_SPAWN_SPACING,
		kind.social_spacing)
	for attempt: int in 18:
		var ring: int = attempt / 6
		var radius: float = clearance * (0.82 + float(ring) * 0.52)
		var candidate: Vector2 = anchor if placed.is_empty() and attempt == 0 \
			else anchor + Vector2.RIGHT.rotated(_rng.randf() * TAU) \
				* _rng.randf_range(radius, radius * 1.32)
		if _is_clear(candidate) and _has_social_room(candidate, clearance, placed):
			return candidate
	return Vector2.INF


func _has_social_room(at: Vector2, clearance: float,
		placed: Array[Vector2]) -> bool:
	for other: Vector2 in placed:
		if at.distance_to(other) < clearance:
			return false
	for animal: Dictionary in _living:
		if float(animal.get("dying", 0.0)) > 0.0:
			continue
		var sprite := animal.get("sprite", null) as Sprite2D
		if sprite != null and is_instance_valid(sprite) \
				and at.distance_to(sprite.global_position) < clearance:
			return false
	return true


## How many things out there would attack you, right now.
func _hostile_count() -> int:
	var count: int = 0
	for animal: Dictionary in _living:
		var kind := animal["data"] as WildlifeData
		if kind != null and kind.is_hostile() and float(animal["dying"]) <= 0.0:
			count += 1
	return count


func _pick_kind(allow_hostile: bool = true) -> WildlifeData:
	var total: float = 0.0
	for kind: WildlifeData in _kinds:
		if kind.is_hostile() and not allow_hostile:
			continue
		total += kind.weight
	if total <= 0.0:
		return null
	var roll: float = _rng.randf() * total
	for kind: WildlifeData in _kinds:
		if kind.is_hostile() and not allow_hostile:
			continue
		roll -= kind.weight
		if roll <= 0.0:
			return kind
	return null


## The opening Preparation is the player's guaranteed safe read of the board.
## No predator arrives before wave one; later breathers retain the living-world
## pressure the travelling party has already encountered.
func _hostile_arrivals_allowed() -> bool:
	return not (RunState.is_preparation() and RunState.wave_number == 0)


## True when this machine decides things *and* somebody is listening.
func _is_authority_with_company() -> bool:
	return Coop.is_host() and Coop.partner_present()


## Recorded on the host only: a guest's animals are mirrors of the host's, and
## both machines counting the same deer would be the same discovery twice.
func _remember(kind: WildlifeData) -> void:
	if kind != null and Coop.is_host():
		MetaState.record_seen("wildlife", kind.id)


func _spawn(kind: WildlifeData, at: Vector2, mirrored_id: int = 0,
		group_id: int = 0) -> void:
	_remember(kind)
	var path: String = kind.get_sprite_path()
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.scale = Vector2.ONE * kind.scale
	# Walks or flies in from off the edge, so nothing pops into existence in the
	# middle of a field somebody is looking at.
	sprite.global_position = at + Vector2(
		Balance.WILDLIFE_ENTRY_DISTANCE * (1.0 if _rng.randf() < 0.5 else -1.0),
		-Balance.WILDLIFE_ENTRY_DISTANCE if kind.flies else 0.0)
	sprite.z_as_relative = false
	(host if host != null else self).add_child(sprite)
	var impact_material: ShaderMaterial = ActorPolishScript.attach(sprite)


	# Elite: the same animal grown and scarred, not a different one.
	#
	# The tell has to be visible *before* it reaches you, so it is size and
	# colour rather than a name in a tooltip - a bigger, darker, ember-eyed wolf
	# reads at a glance and at any zoom. Everything else about it scales from one
	# number, so an elite is stronger, tougher and worth more without six fields
	# needing to agree.
	var elite: bool = kind.elite_chance > 0.0 		and _rng.randf() < kind.elite_chance
	var size: float = Balance.WILDLIFE_ELITE_SCALE if elite else 1.0
	if elite:
		sprite.scale = Vector2.ONE * kind.scale * size
		sprite.modulate = Balance.WILDLIFE_ELITE_TINT
		# A slow ember pulse under it, so it is unmistakable even in a crowd.
		Vfx.ring(at, 90.0 * size, Color(Balance.WILDLIFE_ELITE_TINT, 0.55),
			0.7, 3.0)

	var identity: int = mirrored_id
	if identity == 0 and _is_authority_with_company():
		_net_id += 1
		identity = _net_id
		EventBus.coop_wildlife_spawned.emit(identity, kind.id, at)

	# A bar over anything that can be hurt, hidden until it has been.
	#
	# Always-on bars over a field of rabbits is a HUD, not a world - but an
	# animal you have hit and not killed has to show what is left, or hunting a
	# deer is guesswork. An **elite** shows its bar from the moment it arrives,
	# because that is half of what makes it readable as an elite before it
	# reaches you.
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.custom_minimum_size = Vector2(Balance.WILDLIFE_BAR_WIDTH,
		Balance.WILDLIFE_BAR_HEIGHT)
	bar.size = bar.custom_minimum_size
	bar.position = Vector2(-Balance.WILDLIFE_BAR_WIDTH * 0.5,
		-Balance.WILDLIFE_BAR_LIFT * kind.scale * size)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = elite
	bar.modulate = Balance.WILDLIFE_ELITE_TINT if elite else Color.WHITE
	sprite.add_child(bar)

	_living.append({
		"net_id": identity,
		"data": kind,
		"group_id": group_id,
		"sprite": sprite,
		"state": State.ARRIVING,
		"home": at,
		"goal": at,
		"base": sprite.texture,
		"idle": GameData.load_idle_frames(path),
		"move": GameData.load_move_frames(path),
		"fly": GameData.load_flight_frames(path),
		"attack": GameData.load_attack_frames(path),
		"frame_clock": _rng.randf() * 4.0,
		"pause": 0.0,
		"hp": kind.max_hp * (Balance.WILDLIFE_ELITE_HEALTH if elite else 1.0),
		"elite": elite,
		"size": size,
		"swing": 0.0,
		"bar": bar,
		"impact": impact_material,
		"dying": 0.0,
		"patience": _rng.randf_range(kind.stay_min, kind.stay_max),
		# A hunt is an event with a start and an end. Both counters below.
		"hunt": 0.0,
		"wary": 0.0,
		"bob": _rng.randf() * TAU,
		"steer_phase": _rng.randf() * TAU,
	})
	_apply_visual_anchor(sprite, kind, size, kind.flies)
	if not kind.vocal_sfx.is_empty():
		Sfx.play(kind.vocal_sfx, -3.0)


## One animal, one frame. False when it should be removed.
func _tick_one(animal: Dictionary, delta: float) -> bool:
	var sprite := animal["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return false
	var kind := animal["data"] as WildlifeData

	# A body already on its way down is not doing anything else.
	if float(animal["dying"]) > 0.0:
		var falling := animal["bar"] as ProgressBar
		if falling != null and is_instance_valid(falling):
			falling.visible = false
		return _tick_dying(animal, sprite, delta)

	# Gone, if it has wandered far enough out that nobody can see it. That is
	# what keeps a long run from accumulating animals along the whole road behind
	# the beast, and it is why the cap can be generous.
	if _is_forgotten(sprite.global_position):
		return false

	animal["patience"] = float(animal["patience"]) - delta
	animal["swing"] = maxf(float(animal["swing"]) - delta, 0.0)

	# A hostile that survived a phase transition also leaves without taking one
	# last bite. Arrival filtering handles the normal opening path; this closes
	# the race at the phase boundary.
	if kind.is_hostile() and not _hostile_arrivals_allowed():
		animal["state"] = State.LEAVING
		animal["goal"] = _bolt_target(sprite.global_position)

	# A hostile animal decides differently, and gets first refusal on the frame.
	if kind.is_hostile() and int(animal["state"]) != State.LEAVING:
		if _tick_hostile(animal, sprite, kind, delta):
			return true

	if int(animal["state"]) == State.SETTLED:
		if _frightened(sprite.global_position, kind):
			animal["state"] = State.FLEEING
			animal["goal"] = _bolt_target(sprite.global_position)
		elif float(animal["patience"]) <= 0.0:
			animal["state"] = State.LEAVING
			animal["goal"] = _bolt_target(sprite.global_position)

	var state: int = int(animal["state"])
	var speed: float = kind.speed
	if state == State.FLEEING or state == State.LEAVING:
		speed *= kind.flee_speed_scale
	var toward: Vector2 = (animal["goal"] as Vector2) - sprite.global_position
	var moving: bool = toward.length() > 6.0

	if moving:
		var direction: Vector2 = _steered_direction(animal, toward.normalized(), delta)
		var burst: float = Balance.WILDLIFE_SKITTER_BURST \
			if kind.movement_style == WildlifeData.MovementStyle.SKITTER else 1.0
		var step: Vector2 = direction * speed * burst * delta
		if step.length() > toward.length():
			step = toward
		sprite.global_position += step
		# Facing from motion, against the *art's own* direction rather than a
		# guess. The sprites are drawn facing left, the flip was written for
		# right-facing art, and the result was six species walking backwards.
		if absf(step.x) > 0.001:
			sprite.flip_h = (step.x > 0.0) != kind.art_faces_right
	else:
		match state:
			State.ARRIVING:
				animal["state"] = State.SETTLED
			State.FLEEING:
				# It got somewhere else. Whether it stays is a fresh decision, so
				# bolting does not always end with the animal gone.
				animal["state"] = State.SETTLED
				animal["home"] = sprite.global_position
			State.LEAVING:
				return false
			State.SETTLED:
				animal["pause"] = float(animal["pause"]) - delta
				if float(animal["pause"]) <= 0.0:
					var pause_scale: float = lerpf(1.65, 0.42, kind.activity)
					animal["pause"] = _rng.randf_range(
						Balance.WILDLIFE_PAUSE_MIN, Balance.WILDLIFE_PAUSE_MAX) \
						* pause_scale
					animal["goal"] = _wander_from(animal["home"] as Vector2, kind)

	_animate(animal, sprite, delta, moving)
	return true


## Separation, loose group cohesion, and a small curved path. With at most 22
## animals this bounded scan is cheaper than maintaining another spatial index,
## and it removes the exact-overlap silhouette that made a pack look like one
## wolf with a thick outline.
func _steered_direction(animal: Dictionary, wanted: Vector2,
		delta: float) -> Vector2:
	var sprite := animal["sprite"] as Sprite2D
	var kind := animal["data"] as WildlifeData
	if sprite == null or wanted.is_zero_approx():
		return wanted
	var repel := Vector2.ZERO
	var centre := Vector2.ZERO
	var group_count: int = 0
	var social_id: int = int(animal.get("group_id", 0))
	var radius: float = maxf(Balance.WILDLIFE_SEPARATION_RADIUS,
		kind.social_spacing)
	for other: Dictionary in _living:
		if other == animal or float(other.get("dying", 0.0)) > 0.0:
			continue
		var other_sprite := other.get("sprite", null) as Sprite2D
		if other_sprite == null or not is_instance_valid(other_sprite):
			continue
		var apart: Vector2 = sprite.global_position - other_sprite.global_position
		var distance: float = apart.length()
		if distance > 0.001 and distance < radius:
			repel += apart.normalized() * (1.0 - distance / radius)
		if social_id > 0 and int(other.get("group_id", 0)) == social_id:
			centre += other_sprite.global_position
			group_count += 1

	var steer: Vector2 = wanted
	if not repel.is_zero_approx():
		steer += repel.normalized() * (Balance.WILDLIFE_SEPARATION_STRENGTH
			/ maxf(kind.speed, 1.0))
	if group_count > 0 and kind.group_cohesion > 0.0:
		centre /= float(group_count)
		var together: Vector2 = centre - sprite.global_position
		if together.length() > kind.social_spacing * 1.35:
			steer += together.normalized() * kind.group_cohesion \
				* Balance.WILDLIFE_COHESION_STRENGTH

	animal["steer_phase"] = float(animal.get("steer_phase", 0.0)) \
		+ delta * (1.15 if kind.flies else 0.72)
	var curve: float = Balance.WILDLIFE_SOAR_CURVE if kind.movement_style \
		== WildlifeData.MovementStyle.SOARER else Balance.WILDLIFE_WANDER_CURVE
	steer += wanted.orthogonal() * sin(float(animal["steer_phase"])) * curve
	return steer.normalized() if not steer.is_zero_approx() else wanted


## The node is the animal's ground contact, never its hips. Changing animation
## frames only changes the picture above that point, so depth remains stable.
func _apply_visual_anchor(sprite: Sprite2D, kind: WildlifeData, size: float,
		airborne: bool, extra_lift: float = 0.0) -> void:
	if sprite.texture == null:
		return
	var visual_scale: float = maxf(kind.scale * size, 0.001)
	sprite.offset.x = 0.0
	var ground_lift: float = float(sprite.texture.get_height()) \
		* Balance.WILDLIFE_FEET_ANCHOR
	var air_lift: float = Balance.WILDLIFE_FLIER_LIFT if airborne else 0.0
	sprite.offset.y = -ground_lift - (air_lift + extra_lift) / visual_scale


## The idle loop where there is one, a bob where there is not.
##
## The same choice the structures make and for the same reason: authored frames
## win where they exist, and a transform keeps everything else from standing
## perfectly still, which is what makes a sprite read as a cut-out.
func _animate(animal: Dictionary, sprite: Sprite2D, delta: float,
		moving: bool) -> void:
	var kind := animal["data"] as WildlifeData
	sprite.rotation = 0.0
	# Two authored sequences, chosen by what the animal is doing. Walking has its
	# own frames now rather than borrowing the standing pose and bobbing it,
	# which read as a cut-out being slid along the ground.
	# A flier in motion is *flying*, not walking. A crow that hopped across the
	# sky was the reported symptom of there being only one moving sequence.
	# Striking wins over everything: it is the frame the player is reading.
	var striking: Array = animal["attack"] as Array
	if int(animal["state"]) == State.STRIKING and not striking.is_empty():
		animal["frame_clock"] = float(animal["frame_clock"]) \
			+ delta * Balance.WILDLIFE_ATTACK_FRAME_RATE
		var swing: int = int(floor(float(animal["frame_clock"]))) % striking.size()
		sprite.texture = striking[swing] as Texture2D
		sprite.scale = Vector2.ONE * kind.scale * float(animal["size"])
		_apply_visual_anchor(sprite, kind, float(animal["size"]), kind.flies)
		var phase: float = float(swing) / maxf(float(striking.size() - 1), 1.0)
		var lunge: float = sin(phase * PI) * Balance.WILDLIFE_ATTACK_LUNGE
		sprite.offset.x = lunge * (-1.0 if sprite.flip_h else 1.0) \
			/ maxf(sprite.scale.x, 0.001)
		return
	var flight := animal["fly"] as Array
	var frames: Array = animal["idle"] as Array
	var rate: float = Balance.WILDLIFE_IDLE_FRAME_RATE
	if moving:
		var airborne: bool = kind.flies and not flight.is_empty()
		frames = flight if airborne else (animal["move"] as Array)
		rate = Balance.WILDLIFE_FLIGHT_FRAME_RATE if airborne \
			else Balance.WILDLIFE_MOVE_FRAME_RATE
	if not frames.is_empty():
		animal["frame_clock"] = float(animal["frame_clock"]) + delta * rate
		var index: int = int(floor(float(animal["frame_clock"]))) % frames.size()
		sprite.texture = frames[index] as Texture2D
		sprite.scale = Vector2.ONE * kind.scale * float(animal["size"])
		_apply_visual_anchor(sprite, kind, float(animal["size"]),
			kind.flies and moving)
		# **One authored frame is a pose, not a cycle.**
		#
		# Three of the six could not be given a matching second walk frame - the
		# generator returns a different size or a different shade every time - so
		# rather than ship a mismatched pair that flickers, a single-frame walker
		# gets its motion from a hop: rise and fall with a squash at the bottom.
		#
		# For a rabbit or a squirrel that is not a compromise, it is the correct
		# gait. Skipped for anything with a real cycle, which is already moving.
		if moving and frames.size() == 1 and kind.hops and not kind.flies:
			animal["bob"] = float(animal["bob"]) + delta * Balance.WILDLIFE_HOP_RATE
			var phase: float = float(animal["bob"])
			var lift: float = absf(sin(phase))
			_apply_visual_anchor(sprite, kind, float(animal["size"]), false,
				lift * Balance.WILDLIFE_HOP_HEIGHT)
			# Squashed at the bottom of the arc, stretched at the top, which is
			# what makes a hop read as weight rather than as a sprite sliding up
			# and down.
			var squash: float = (1.0 - lift) * Balance.WILDLIFE_HOP_SQUASH
			sprite.scale.y = kind.scale * float(animal["size"]) * (1.0 - squash)
			sprite.scale.x = kind.scale * float(animal["size"]) * (1.0 + squash * 0.6)
		elif moving and frames.size() == 1 and not kind.flies:
			# One frame and no hop: a slow rise and fall through the stride, so a
			# wolf or a bear reads as walking rather than sliding, without ever
			# leaving the ground.
			animal["bob"] = float(animal["bob"]) + delta * Balance.WILDLIFE_BOB_RATE
			var sway: float = sin(float(animal["bob"]))
			_apply_visual_anchor(sprite, kind, float(animal["size"]), false,
				absf(sway) * Balance.WILDLIFE_STRIDE_LIFT)
			sprite.scale.y = kind.scale * float(animal["size"]) \
				* (1.0 + sway * Balance.WILDLIFE_BOB_SCALE * 0.5)
			sprite.scale.x = kind.scale * float(animal["size"])
		return
	# No authored frames for this state. Back to the resting pose plus a
	# transform, which keeps it from standing perfectly still - that is what
	# makes a sprite read as a cut-out.
	var base := animal["base"] as Texture2D
	if base != null:
		sprite.texture = base
	animal["bob"] = float(animal["bob"]) + delta * Balance.WILDLIFE_BOB_RATE
	var wave: float = sin(float(animal["bob"]))
	var bob: float = absf(wave) if moving else 0.0
	sprite.scale = Vector2(kind.scale * float(animal["size"]),
		kind.scale * float(animal["size"]) * (1.0 + (bob * Balance.WILDLIFE_BOB_SCALE
			if moving else wave * Balance.WILDLIFE_BOB_SCALE * 0.16)))
	if not moving:
		# A breathing weight shift gives every missing authored idle an honest
		# living fallback. It is intentionally subtler than a stride and never
		# changes the ground-contact anchor.
		sprite.scale.x *= 1.0 - wave * Balance.WILDLIFE_BOB_SCALE * 0.08
		sprite.rotation = wave * 0.006
	_apply_visual_anchor(sprite, kind, float(animal["size"]), kind.flies and moving,
		bob * Balance.WILDLIFE_STRIDE_LIFT)


## Dying, shown rather than skipped.
##
## Procedural rather than an authored death frame, and for once that is the
## *better* answer rather than the affordable one: a toppling, fading body works
## for six creatures that have nothing anatomically in common, and it cannot
## disagree with the sprite it started from - which authored frames from this
## generator repeatedly have.
func _tick_dying(animal: Dictionary, sprite: Sprite2D, delta: float) -> bool:
	animal["dying"] = float(animal["dying"]) - delta
	var left: float = float(animal["dying"])
	if left <= 0.0:
		return false
	var through: float = 1.0 - left / Balance.WILDLIFE_DEATH_SECONDS
	# Over onto its side, settling as it goes, and fading out at the end.
	sprite.rotation = deg_to_rad(through * Balance.WILDLIFE_DEATH_ROLL
		* (-1.0 if sprite.flip_h else 1.0))
	sprite.scale.y = float(animal["size"]) * (animal["data"] as WildlifeData).scale 		* (1.0 - through * 0.3)
	sprite.modulate.a = clampf(1.0 - through, 0.0, 1.0)
	return true


## The hostile half: find something, close on it, hit it.
##
## Returns true when it has taken the frame - a stalking animal does not also
## wander, and a striking one does not move at all.
##
## **What it hunts is whatever is nearest, hero or enemy.** The wilderness is a
## third party rather than a second enemy faction: a boar that charges through a
## Bogkin pack on its way to you is the whole idea, and it costs one comparison.
func _tick_hostile(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData,
		delta: float) -> bool:
	# **A hunt has to be able to end.**
	#
	# It could not. Quarry was measured from wherever the animal had got to, so
	# an animal that closed the distance was by definition still inside its own
	# aggro radius - a wolf that noticed you at 760 units then chased you for the
	# rest of the run, and six of them at once is a background damage tax rather
	# than an encounter. Found by the breather gate: a hero standing still with
	# eight towers up and the town untouched was dead in seventy seconds, and the
	# waves were not what killed it.
	#
	# So a hunt is given a length and a rest. It commits, it presses, it breaks
	# off, and it goes back to being an animal for a while. That is also the
	# shape the design asks for - the wilderness as a third party that *happens*
	# to you, not a second enemy faction with unlimited stamina.
	# **Nothing hunts during Preparation.**
	#
	# Preparation is the phase the player reads the board in, and it is spent
	# standing at the town - which is exactly where a predator that has noticed
	# them will come. Played back as "predators attack the city base and it makes
	# the hero hurt noise": nothing was attacking the town, a wolf was mauling
	# the hero standing next to it, over and over, through the one phase that is
	# supposed to be the quiet one.
	#
	# They go docile and drift off rather than freezing. A predator that stops
	# dead a body-length away has not disengaged in any way the player can read,
	# and it is on top of them the instant the wave starts.
	if RunState.is_preparation():
		if int(animal["state"]) == State.STALKING 				or int(animal["state"]) == State.STRIKING:
			return _break_off(animal, sprite)
		_drift_from_town(animal, sprite)
		return false

	animal["wary"] = maxf(float(animal["wary"]) - delta, 0.0)
	if float(animal["hunt"]) > 0.0:
		animal["hunt"] = float(animal["hunt"]) - delta
		if float(animal["hunt"]) <= 0.0:
			return _break_off(animal, sprite)
	elif float(animal["wary"]) > 0.0:
		return false

	var quarry: Node2D = _quarry_for(sprite.global_position, kind)
	if quarry == null:
		# Nothing worth attacking. A territorial animal goes back to standing
		# about; a predator keeps looking while it wanders.
		if int(animal["state"]) == State.STALKING 				or int(animal["state"]) == State.STRIKING:
			animal["state"] = State.SETTLED
		animal["hunt"] = 0.0
		return false

	if float(animal["hunt"]) <= 0.0:
		animal["hunt"] = _rng.randf_range(Balance.WILDLIFE_HUNT_MIN,
			Balance.WILDLIFE_HUNT_MAX)

	var toward: Vector2 = quarry.global_position - sprite.global_position
	var distance: float = toward.length()
	var reach: float = kind.attack_range * float(animal["size"])

	if distance <= reach:
		animal["state"] = State.STRIKING
		if absf(toward.x) > 0.001:
			sprite.flip_h = (toward.x > 0.0) != kind.art_faces_right
		if float(animal["swing"]) <= 0.0:
			animal["swing"] = kind.attack_interval
			animal["frame_clock"] = 0.0
			_strike(animal, sprite, kind, quarry)
		_animate(animal, sprite, delta, false)
		return true

	# Closing. Faster than it walks, because a hunt that moves at grazing pace
	# is not a hunt.
	animal["state"] = State.STALKING
	var step: Vector2 = _steered_direction(animal, toward.normalized(), delta) \
		* kind.speed * kind.charge_speed_scale * delta
	if step.length() > distance:
		step = toward
	sprite.global_position += step
	if absf(step.x) > 0.001:
		sprite.flip_h = (step.x > 0.0) != kind.art_faces_right
	_animate(animal, sprite, delta, true)
	return true


## Gives up, walks off, and stays an animal for a while.
##
## Breaking off *moves* rather than merely stopping, because a predator that
## simply stands still next to you has not disengaged in any way the player can
## read - it looks like a bug, and the moment it is allowed to hunt again it is
## already on top of you.
func _break_off(animal: Dictionary, sprite: Sprite2D) -> bool:
	animal["hunt"] = 0.0
	animal["wary"] = _rng.randf_range(Balance.WILDLIFE_HUNT_REST_MIN,
		Balance.WILDLIFE_HUNT_REST_MAX)
	animal["state"] = State.FLEEING
	animal["goal"] = _bolt_target(sprite.global_position)
	return false


## Sends a settled animal a little further out, away from the town.
##
## Only when it is already near: an animal halfway across the field has no
## business walking anywhere on account of a phase, and re-goaling every predator
## every Preparation would read as the wilderness politely clearing the room.
func _drift_from_town(animal: Dictionary, sprite: Sprite2D) -> void:
	var out: Vector2 = sprite.global_position
	if out.length() > Balance.WILDLIFE_TOWN_SPACE:
		return
	if not is_zero_approx(float(animal.get("drifted", 0.0))):
		return
	var away: Vector2 = out.normalized() if out.length() > 1.0 		else Vector2.from_angle(_rng.randf() * TAU)
	animal["state"] = State.SETTLED
	animal["drifted"] = 1.0
	animal["goal"] = away * Balance.WILDLIFE_TOWN_SPACE 		* _rng.randf_range(1.05, 1.4)


## The nearest thing worth attacking, or null.
##
## A territorial animal only answers inside its own ground; a predator reaches as
## far as it can see. Same number, two meanings - see `aggro_radius`.
func _quarry_for(at: Vector2, kind: WildlifeData) -> Node2D:
	var best: Node2D = null
	var best_distance: float = kind.aggro_radius
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero == null or not hero.is_alive():
			continue
		var distance: float = at.distance_to(hero.global_position)
		if distance < best_distance:
			best_distance = distance
			best = hero
	if field != null and field.has_method("enemies_near"):
		for enemy: Enemy in field.enemies_near(at, kind.aggro_radius):
			if enemy.is_dying():
				continue
			var distance: float = at.distance_to(enemy.global_position)
			if distance < best_distance:
				best_distance = distance
				best = enemy
	return best


## One blow, against whatever it caught.
func _strike(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData,
		quarry: Node2D) -> void:
	# Wildlife may fight heroes and road enemies, never structures. Keeping the
	# accepted types explicit makes a future broad target group unable to turn a
	# wolf into a town attacker by accident.
	if not (quarry is Hero) and not (quarry is Enemy):
		return
	# Softer early, at full strength later. A wolf pack costs 8 a bite and the
	# hero has 100; three of them arriving in Act I read as the wilderness being
	# the boss fight. The ramp is by act rather than by wave so it is legible to
	# a player who noticed it, and so the late game is untouched.
	var power: float = kind.damage * float(animal["size"]) * Balance.wildlife_bite(RunState.act)
	var from: Vector2 = sprite.global_position
	var enemy := quarry as Enemy
	if enemy != null:
		enemy.take_damage(power, from, kind.knockback, false)
		# It gets to bite back, if the animal is still standing on top of it when
		# its next swing comes round. The road is not abandoned for this - see
		# `Enemy.provoked_by`.
		enemy.provoked_by(sprite, self)
	else:
		var health: Health = Health.of(quarry)
		if health != null:
			RunState.note_blow(kind.display_name, power)
			health.take_damage(power, from)
	Vfx.spark(quarry.global_position, Color("c4552e"), 6,
		(quarry.global_position - from).normalized(), 190.0)
	EventBus.camera_shake_requested.emit(3.0, 0.12)
	if not kind.vocal_sfx.is_empty():
		Sfx.play(kind.vocal_sfx)


## Whether anything alarming is close enough to matter.
##
## People and enemies both. A rabbit that bolted from a hero and grazed happily
## through a pack of Bogkin is a rabbit nobody believes.
##
## The enemy check is deliberately *not* a scan of every enemy: it asks the field
## for the ones near this animal, which is the same broadphase the towers use. A
## distance test per animal per enemy per frame, to decide whether a rabbit
## twitches, is exactly the cost ambient decoration must not have.
##
## A raven has a radius of zero and is frightened by nothing: they are the
## animals that turn up *because* of a battle rather than in spite of one.
func _frightened(at: Vector2, kind: WildlifeData) -> bool:
	# Nothing that hunts is also afraid. A wolf that bolted from the hero it was
	# stalking would be two behaviours cancelling each other out.
	if kind.is_hostile() or kind.skittish_radius <= 0.0:
		return false
	# Every hero, not the local one: a rabbit that only bolted from the host
	# sat perfectly still while the guest walked through it.
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Node2D
		if hero != null and at.distance_to(hero.global_position) < kind.skittish_radius:
			return true
	if field != null and field.has_method("enemies_near"):
		for enemy: Enemy in field.enemies_near(at, kind.skittish_radius):
			if not enemy.is_dying():
				return true
	return false


## A hero swung, and anything small enough nearby does not survive it.
##
## Heard rather than hunted. Wildlife stays out of the enemy group - towers would
## shoot rabbits and waves would never end - so the hero's blow is picked up from
## the bus and resolved here, where it cannot reach the combat systems at all.
func _on_swing_resolved(at: Vector2, aim: Vector2, reach: float) -> void:
	# The host decides what died, like everything else that pays out. A guest
	# swinging kills nothing locally and is told what happened.
	if Coop.is_guest():
		return
	var forward: Vector2 = aim.normalized() if aim.length() > 0.001 else Vector2.RIGHT
	for index: int in range(_living.size() - 1, -1, -1):
		var animal: Dictionary = _living[index]
		if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
			continue
		var sprite := animal["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		var toward: Vector2 = sprite.global_position - at
		var distance: float = toward.length()
		if distance > reach + Balance.WILDLIFE_KILL_REACH_BONUS:
			continue
		# In front of the swing, not merely near it. A blade that killed things
		# behind the hero would be a strange thing to discover by accident.
		if distance > 1.0 and toward.normalized().dot(forward) < 0.2:
			continue
		_wound(index, animal)
		return


## Hits one named animal, for whoever is not the hero.
##
## Public because an enemy that has been bitten swings back, and it cannot reach
## into `_living` to do it - the wildlife system owns those numbers and this is
## the door. Returns whether anything was actually there.
##
## Host-only, like every other way an animal can be hurt: a guest that killed a
## wolf locally would be paying itself out and disagreeing with the host about
## what is standing on the field.
func wound_sprite(sprite: Node2D, damage: float) -> bool:
	if Coop.is_guest() or sprite == null:
		return false
	for index: int in range(_living.size() - 1, -1, -1):
		if _living[index]["sprite"] != sprite:
			continue
		if float(_living[index].get("dying", 0.0)) > 0.0 \
				or float(_living[index].get("hp", 0.0)) <= 0.0:
			return false
		_wound(index, _living[index], damage)
		return true
	return false


## Puts damage into one animal, and pays out if that finishes it.
##
## Health rather than a one-hit kill, because the owner asked for size to matter:
## a rabbit should die to a swing and a deer should take a few, which is the only
## way "larger gives more" is a decision rather than a lottery.
func _wound(index: int, animal: Dictionary, damage: float = -1.0) -> void:
	if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
		return
	var kind := animal["data"] as WildlifeData
	var sprite := animal["sprite"] as Sprite2D
	var impact := animal.get("impact", null) as ShaderMaterial
	ActorPolishScript.strike(impact, Vector2.UP)
	if impact != null:
		var fade: Tween = create_tween()
		fade.tween_method(func(value: float) -> void:
			ActorPolishScript.drive(impact, value), Balance.HIT_FLASH_TIME, 0.0,
			Balance.HIT_FLASH_TIME)
	animal["hp"] = float(animal["hp"]) - (Balance.HERO_ATTACK_DAMAGE[0]
		if damage < 0.0 else damage)
	# Hurt, so the bar comes out and stays out.
	var bar := animal["bar"] as ProgressBar
	if bar != null and is_instance_valid(bar):
		bar.visible = true
		var full: float = kind.max_hp 			* (Balance.WILDLIFE_ELITE_HEALTH if bool(animal["elite"]) else 1.0)
		bar.value = clampf(float(animal["hp"]) / maxf(full, 1.0), 0.0, 1.0)
	var body_at: Vector2 = _visual_origin(sprite)
	Vfx.spark(body_at, Color("c4552e"), 6,
		Vector2.UP, 170.0)
	Vfx.blood(body_at, Vector2.UP,
		Balance.VFX_BLOOD_HIT_SIZE if float(animal["hp"]) > 0.0 \
		else Balance.VFX_BLOOD_DEATH_SIZE * 0.75, sprite.global_position)
	if float(animal["hp"]) > 0.0:
		# Being hit is also a very good reason to leave.
		animal["state"] = State.FLEEING
		animal["goal"] = _bolt_target(sprite.global_position)
		return

	# Food and experience both scale with the animal, rolled rather than fixed so
	# two deer are not worth exactly the same. Its own stream, so a seeded replay
	# is not changed by whether somebody stopped to hunt.
	var bounty: float = Balance.WILDLIFE_ELITE_REWARD if bool(animal["elite"]) else 1.0
	var food: int = int(round(float(_rng.randi_range(kind.food_min, kind.food_max))
		* bounty))
	Vfx.dust(sprite.global_position, Color("c4552e"), 10, 60.0)
	if field != null and field.has_method("spawn_loot"):
		field.spawn_loot(RunState.FOOD, food, sprite.global_position)
	RunState.gain_hero_xp(float(kind.xp_reward) * bounty)
	if _is_authority_with_company():
		EventBus.coop_wildlife_died.emit(int(animal["net_id"]))
	EventBus.wildlife_killed.emit(kind.id, food, sprite.global_position)
	# The body stays until it has fallen; `_retire` announces it when it goes.
	# Left on the field to fall over rather than vanishing on the blow - a kill
	# that deletes its own body reads as the animal never having been there.
	animal["dying"] = Balance.WILDLIFE_DEATH_SECONDS
	animal["state"] = State.LEAVING


func _visual_origin(sprite: Sprite2D) -> Vector2:
	if sprite == null:
		return Vector2.ZERO
	return sprite.global_position + Vector2(0.0, sprite.offset.y * sprite.scale.y)


## True when an animal is far enough from every player to stop existing.
##
## Distance from the *heroes* rather than from a camera: there are two cameras in
## co-op and either one seeing it is reason enough to keep it. Measuring from the
## people is the same answer without asking the rendering layer anything.
func _is_forgotten(at: Vector2) -> bool:
	var heroes: Array = get_tree().get_nodes_in_group(Hero.GROUP_ANY)
	if heroes.is_empty():
		return false
	for node: Node in heroes:
		var hero := node as Node2D
		if hero != null and at.distance_to(hero.global_position) 				< Balance.WILDLIFE_FORGET_DISTANCE:
			return false
	return true


## Somewhere to run, away from the middle.
func _bolt_target(from: Vector2) -> Vector2:
	var away: Vector2 = from if from.length() > 1.0 else Vector2.RIGHT
	return away.normalized() * Balance.WILDLIFE_ENTRY_DISTANCE


## A new spot to potter over to, on ground it is allowed to stand on.
func _wander_from(home: Vector2, kind: WildlifeData) -> Vector2:
	var roam_scale: float = 1.0
	match kind.movement_style:
		WildlifeData.MovementStyle.GRAZER:
			roam_scale = 0.48
		WildlifeData.MovementStyle.FORAGER:
			roam_scale = 0.66
		WildlifeData.MovementStyle.SOARER:
			roam_scale = 1.16
		WildlifeData.MovementStyle.SKITTER:
			roam_scale = 0.40
	for _attempt: int in 6:
		var candidate: Vector2 = home + Vector2(
			_rng.randf_range(-kind.roam, kind.roam) * roam_scale,
			_rng.randf_range(-kind.roam, kind.roam) * 0.7 * roam_scale)
		if _is_clear(candidate):
			return candidate
	# Six misses means the animal is hemmed in. Staying put is the only answer
	# that is certainly legal - returning `home` unchecked would let one that had
	# fled onto a road adopt it as somewhere to live.
	return home if _is_clear(home) else _bolt_target(home)


## A place to arrive at, or zero when the field is too built up to find one.
func _clear_point() -> Vector2:
	var span: float = Balance.WILDLIFE_FIELD_SPAN
	var floor_out: float = Balance.WILDLIFE_SPAWN_CLEARANCE
	for _attempt: int in 18:
		# **A ring, not the whole field.** Sampling the square uniformly put most
		# candidates near the middle, which is the town - so animals arrived on
		# the doorstep and the rejects were wasted attempts. Drawing an angle and
		# a distance outside the clearance puts arrivals where animals come from,
		# out among the trees and off the edge of what the player is watching.
		var angle: float = _rng.randf() * TAU
		var reach: float = _rng.randf_range(floor_out, span)
		var candidate := Vector2(cos(angle) * reach, sin(angle) * reach * 0.66)
		if candidate.length() < floor_out:
			continue
		if _is_clear(candidate):
			return candidate
	return Vector2.ZERO


## Off the roads and out of the town, by the rule the foliage already uses.
##
## Asked of the grid rather than measured against lane centre lines: the lanes
## bend, and a centre-line test would let a deer graze in the middle of a U-turn.
func _is_clear(point: Vector2) -> bool:
	# The town keeps an animal's distance, not a plant's. This used to be the
	# foliage margin, which is 340 units - close enough that a deer read as
	# standing in the city and a wolf that noticed the hero there was already on
	# them. Every placement path runs through here, including the social spread
	# that puts the rest of a pack down.
	if point.length() < Balance.WILDLIFE_SPAWN_CLEARANCE:
		return false
	if grid == null:
		return true
	var tile: Vector2i = BattleGrid.world_to_tile(point)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var cell: int = grid.cell_at(tile + Vector2i(dx, dy))
			if cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN:
				return false
	return true


## How many are on the field. For the gate, and for anyone who wants to know.
func population() -> int:
	return _living.size()


## Everywhere an animal is currently heading, for the gate.
##
## The goals rather than the positions, because those are two different rules and
## only one of them is a bug. An animal *crossing* a road is a deer crossing a
## path, which is what animals do and what makes the field read as a place. An
## animal that has chosen to stand in a lane makes the lane look like a mistake.
## So what the system guarantees, and what this exposes, is that nothing ever
## picks a destination it should not be standing on.
func goals() -> PackedVector2Array:
	var out := PackedVector2Array()
	for animal: Dictionary in _living:
		if int(animal["state"]) == State.SETTLED 				or int(animal["state"]) == State.ARRIVING:
			out.append(animal["goal"] as Vector2)
	return out


## Removes everything, without waiting for it to wander off.
func clear() -> void:
	for animal: Dictionary in _living:
		var sprite: Node = animal["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_living.clear()
