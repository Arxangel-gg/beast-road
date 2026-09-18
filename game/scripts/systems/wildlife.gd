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
## Appended, never inserted: a state is read by number in the records this
## script keeps and by `WildlifeFamilies`.
## **Appended, never inserted.** Nothing indexes this enum from data, unlike
## `Role` and `Trigger` - both of which silently repointed every `.tres` after
## them when a member was added in the middle - but the habit is the protection.
enum State { ARRIVING, SETTLED, FLEEING, LEAVING, STALKING, STRIKING, GRAZING, ALERT,
	SCAVENGING, HIDING, FORAGING, COURTING,
	## The water half of an amphibious animal's life (owner, 2026-09-16): under
	## the surface, lying at it with its eyes out, hauling out onto the bank, and
	## sliding back in. See `_tick_amphibian`.
	SUBMERGED, SURFACED, EMERGING, ENTERING }

## The grid, so animals can be kept off the roads. Assigned by the battlefield.
var grid: BattleGrid = null

## **The places this region's crafts are worked** - the stands of timber and the
## stone seams, as `{at, kind}`. Handed over by the battlefield rather than
## looked up, which is the seam `RiftGates.avoid` and `AmbientLife.work_places`
## already use: this system has no business holding a reference to `Gathering`.
var haunts: Array[Dictionary] = []

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

## Seconds the road stays empty of wildlife, because something is coming.
##
## Owner request, 2026-09-02, under "the Road is always telling you something":
## before a boss, the wildlife leaves. Animals on the field bolt and none arrive
## until it is over, so a player who notices the road has gone quiet has been
## warned by the world rather than by a banner.
##
## **The warning is the absence.** Nothing is drawn, nothing is announced and no
## UI appears; the information is that the thing which is normally there is not.
## That only works because the road is otherwise busy - it is the ecology and the
## ambient life that give this its meaning.
var _hush_left: float = 0.0
var _batch_clock: float = 0.0

## Rising identity for relayed animals. Host side.
var _net_id: int = 0
## Rising identity for one social arrival. Guests mirror positions and do not
## need it; the authority uses it for loose cohesion without stacking bodies.
var _group_id: int = 0
var _kinds: Array[WildlifeData] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.flood_changed.connect(_on_flood)
	# Its own stream, seeded from the run. Ambient life must never draw from the
	# combat stream, or a seeded replay would produce a different wave because a
	# rabbit happened to turn up.
	_rng.seed = hash("wildlife") ^ RunState.run_seed
	_families = WildlifeFamilies.new(self)
	# A hero's swing is the only thing that can kill an animal, and it is heard
	# rather than fought for: putting wildlife in the enemy group would have
	# towers shooting rabbits and waves never ending, which is a far worse bug
	# than not being able to hunt.
	EventBus.hero_swing_resolved.connect(_on_swing_resolved)
	# The road empties before a boss and fills again once it is down.
	EventBus.act_boss_due.connect(func(_act: int) -> void: _hush())
	EventBus.boss_defeated.connect(func(_id: String, _act: int) -> void:
		_hush_left = 0.0)
	# Replicated so a hunt is shared. A guest whose field held different animals
	# could not help farm one, and would watch its partner swing at nothing.
	EventBus.coop_wildlife_spawned.connect(_on_coop_spawned)
	EventBus.coop_wildlife_sack.connect(_on_coop_sack)
	EventBus.coop_wildlife_batch.connect(_on_coop_batch)
	EventBus.coop_wildlife_family.connect(_on_coop_family)
	EventBus.coop_wildlife_born.connect(_on_coop_born)
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
## Sexes, courtship, births, growth and the Wildblight (2026-09-14). Beside
## this script rather than inside it: this one is already the largest in the
## project, and what a family does is its own subject.
var _families: WildlifeFamilies = null
## Every litter gets a family number, so young know their own parents apart
## from another pair's standing beside them.
var _family_id: int = 0


func families() -> WildlifeFamilies:
	return _families


## The run's own stream for this system, for the families to roll on.
func dice() -> RandomNumberGenerator:
	return _rng


func living() -> Array[Dictionary]:
	return _living


## Every living animal of a species decides to fight, because somebody took an
## egg out of one of its nests.
##
## **A third reason an animal comes at you**, beside being a hunter by nature
## and being taken by the Wildblight - and it goes through the same branch, so
## nothing downstream learns that robbery exists. What separates it from the
## frenzy is the target: a frenzied animal attacks everything living including
## its own kind, and a robbed parent wants the people who robbed it.
##
## The bite is `WildlifeFamilies.blight_bite`, which is the helper that already
## answers "what does an animal that never fought hit with" - so a robbed crane
## is a crane that has decided to fight rather than a new number.
func rouse_species(species_id: String, toward: Vector2) -> void:
	for animal: Dictionary in _living:
		var kind := animal.get("data") as WildlifeData
		if kind == null or kind.id != species_id:
			continue
		if float(animal.get("dying", 0.0)) > 0.0:
			continue
		animal["angered"] = true
		animal["wary"] = 0.0
		animal["hunt"] = Balance.WILDLIFE_HUNT_MAX
		var sprite := animal.get("sprite") as Node2D
		if sprite != null and is_instance_valid(sprite):
			animal["goal"] = toward
			Vfx.spark(sprite.global_position, Color(0.92, 0.42, 0.30), 6,
				(toward - sprite.global_position).normalized(), 130.0)
	if not species_id.is_empty():
		var kind: WildlifeData = ContentDB.wildlife_kinds.get(species_id, null) as WildlifeData
		if kind != null and not kind.vocal_sfx.is_empty():
			# From where the species was wronged - the nest that was robbed -
			# rather than from the listener. `sprite` above is loop-local.
			Sfx.play_at(kind.vocal_sfx, toward, -2.0, voice_pitch(kind))


## One animal by its serial, or an empty record.
func animal_by_id(net_id: int) -> Dictionary:
	if net_id == 0:
		return {}
	for animal: Dictionary in _living:
		if int(animal.get("net_id", 0)) == net_id:
			return animal
	return {}


## The ceiling the arrivals respect, so a birth cannot push past it either.
func population_cap() -> int:
	return int(round(float(Balance.WILDLIFE_MAX) * Graphics.foliage_scale()))


## Put a mythic on the field at the end of its own trail.
##
## **The one door a mythic comes through.** `_pick_kind` refuses them, so this
## is the only way one arrives - which is the whole of what the classification
## means. Everything after the placement is ordinary: the same serial, the same
## coat, the same rank sheen, the same bond, the same wrath for killing it, and
## the same count against the population cap that `budget_check` holds.
func place_mythic(kind: WildlifeData, at: Vector2) -> void:
	if kind == null or not kind.mythic or Coop.is_guest():
		return
	for animal: Dictionary in _living:
		if (animal["data"] as WildlifeData) == kind:
			# One at a time. A second is not rarer for being duplicated.
			return
	_spawn(kind, at)


## The young of one parent, by its serial.
func young_of(parent_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if parent_id == 0:
		return out
	for animal: Dictionary in _living:
		if WildlifeFamilies.is_adult(animal):
			continue
		if (animal.get("parents", []) as Array).has(parent_id):
			out.append(animal)
	return out


## The family the next litter belongs to.
func next_family() -> void:
	_family_id += 1


func family_id() -> int:
	return _family_id


## How many are sick right now, for the outbreak ceiling.
func sick_count() -> int:
	var count: int = 0
	for animal: Dictionary in _living:
		if WildlifeFamilies.is_sick(animal) and float(animal.get("dying", 0.0)) <= 0.0:
			count += 1
	return count


## The doors the families reach the rest of this script through, named rather
## than reached into: what frightens a place, where to bolt to, what is near.
func frightened_at(at: Vector2, kind: WildlifeData) -> bool:
	return _frightened(at, kind)


func bolt_from(at: Vector2, threat: Vector2) -> Vector2:
	return _bolt_target(at, threat)


func threat_near_for(at: Vector2, _kind: WildlifeData, radius: float) -> Vector2:
	return _nearest_threat(at, radius)


func is_authority_with_company() -> bool:
	return _is_authority_with_company()


## A blighted animal that has run its course. It simply dies, paying nobody:
## no Food, no experience, no encounter and no wrath - the same treatment a
## predator's kill gets, because neither is the player's doing.
func perish(animal: Dictionary) -> void:
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite != null and is_instance_valid(sprite):
		Vfx.dust(sprite.global_position, Color(0.5, 0.7, 0.4), 8, 44.0)
	if _is_authority_with_company():
		EventBus.coop_wildlife_died.emit(int(animal.get("net_id", 0)))
	animal["dying"] = Balance.WILDLIFE_DEATH_SECONDS
	animal["state"] = State.LEAVING


## The sickly light a frenzied animal wears. The same dress a born-rabid one
## has always had, so the two read alike - which is correct: they are.
func dress_frenzied(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if sprite.get_node_or_null("Rabid") == null:
		_dress_as_rabid(sprite, kind)
	animal["rabid"] = true


## Young born to a pair, placed like any other animal and handed what their
## parents gave them. Returns the record, or empty when the field is full.
func spawn_born(kind: WildlifeData, at: Vector2, born: Dictionary) -> Dictionary:
	var before: int = _living.size()
	_spawn(kind, at, 0, int(born.get("family", 0)), -1, born)
	if _living.size() <= before:
		return {}
	var cub: Dictionary = _living[_living.size() - 1]
	if _is_authority_with_company():
		EventBus.coop_wildlife_born.emit(int(cub["net_id"]), kind.id, at, born)
	return cub


func _refresh_kinds() -> void:
	# **Every species, every act.** The act used to be a gate, which meant a
	# region had character by having nothing else to offer - and the whole
	# roster of an act was three or four animals. It is a preference now:
	# `roll_weight` makes the ones that belong here several times likelier and
	# the ones that do not merely rare, so a bear in Act I is a story rather
	# than an impossibility.
	_kinds.clear()
	for data: WildlifeData in ContentDB.wildlife():
		_kinds.append(data)


func _process(delta: float) -> void:
	_tick_hunt(delta)
	if _families != null:
		_families.tick(delta)
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
	_hush_left = maxf(_hush_left - delta, 0.0)
	_arrival_clock -= delta
	if _arrival_clock <= 0.0:
		_arrival_clock = ARRIVAL_INTERVAL
		if _hush_left <= 0.0:
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


## Every animal the host has announced, as the arguments its spawn fact
## carried, for the welcome (2026-09-14). Host side.
func announced_animals() -> Array:
	var out: Array = []
	for animal: Dictionary in _living:
		var sprite := animal.get("sprite", null) as Sprite2D
		var kind := animal.get("data", null) as WildlifeData
		if sprite == null or not is_instance_valid(sprite) or kind == null:
			continue
		if int(animal.get("net_id", 0)) <= 0 or float(animal.get("dying", 0.0)) > 0.0:
			continue
		out.append([int(animal["net_id"]), kind.id, sprite.global_position,
			bool(animal.get("shiny", false))])
	return out


## The host put an animal down, so one appears here. Guest side.
func _on_coop_spawned(net_id: int, kind_id: String, at: Vector2,
		shiny: bool) -> void:
	if not Coop.is_guest():
		return
	for data: WildlifeData in ContentDB.wildlife():
		if data.id == kind_id:
			_spawn(data, at, net_id, 0, 1 if shiny else 0)
			return


## The host's word about one animal's family life. A guest only draws it.
func _on_coop_family(net_id: int, word: int, value: int) -> void:
	if not Coop.is_guest() or _families == null:
		return
	var animal: Dictionary = animal_by_id(net_id)
	if animal.is_empty():
		return
	var sprite := animal.get("sprite", null) as Sprite2D
	var kind := animal.get("data", null) as WildlifeData
	if sprite == null or not is_instance_valid(sprite) or kind == null:
		return
	match word:
		WildlifeFamilies.Word.COURTING:
			_families.dress_courting(animal, value)
		WildlifeFamilies.Word.BLIGHT:
			_families.dress_blight(animal, sprite, kind, value)
		WildlifeFamilies.Word.STAGE:
			animal["stage"] = value
			animal["age"] = Balance.WILDLIFE_GROWTH_SECONDS \
				if value == WildlifeFamilies.Stage.ADULT else float(animal.get("age", 0.0))
			_families.decorate(animal, kind, {
				"sex": int(animal.get("sex", 0)),
				"rarity": WildlifeFamilies.rarity_of(animal),
				"stage": value,
				"born_act": int(animal.get("born_act", -1)),
				"parents": animal.get("parents", []),
				"family": int(animal.get("family", 0)),
			})
		_:
			pass


## The host bore young, so a guest places the same ones.
func _on_coop_born(net_id: int, kind_id: String, at: Vector2, born: Dictionary) -> void:
	if not Coop.is_guest():
		return
	for data: WildlifeData in ContentDB.wildlife():
		if data.id == kind_id:
			_spawn(data, at, net_id, int(born.get("family", 0)), -1, born)
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
		# The guest collects too. Each player has their own save and their own
		# spirits, so a kill both of them watched is a kill both of them earn -
		# and a guest whose journal never moved would have no reason to hunt.
		_credit_encounter(animal, SpiritBond.Kind.SLAIN)
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
	# **Where first, then what.** The two used to be rolled the other way round,
	# which makes distance impossible to read: a hunter picked before a place is
	# a hunter that lands wherever the place happens to be. See `_wildness_at`.
	var at: Vector2 = _clear_point()
	if at == Vector2.ZERO:
		return
	var kind: WildlifeData = _pick_kind(_hostile_arrivals_allowed(), _wildness_at(at))
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


func _pick_kind(allow_hostile: bool = true, wildness: float = 0.0) -> WildlifeData:
	var total: float = 0.0
	for kind: WildlifeData in _kinds:
		if kind.is_hostile() and not allow_hostile:
			continue
		total += _tilted_weight(kind, wildness)
	if total <= 0.0:
		return null
	var roll: float = _rng.randf() * total
	for kind: WildlifeData in _kinds:
		if kind.is_hostile() and not allow_hostile:
			continue
		roll -= _tilted_weight(kind, wildness)
		if roll <= 0.0:
			return kind
	return null


## A species' weight, tilted by how far out of the settled world the spot is.
##
## **The far ground favours the dangerous and the rare, and the near ground the
## harmless and the common** (owner, 2026-09-15). The act preference is
## untouched underneath - a region still gets the animals that belong to it -
## and this only decides which of those a given *spot* leans toward.
##
## Multiplicative on the weight rather than a filter, so nothing becomes
## impossible anywhere: a wolf near the square is a story, and a rabbit at the
## map's edge is still a rabbit. `wildlife_spawn_check` reads reachability per
## act and is unmoved by this, because at wildness zero it returns the weight
## unchanged and every tier is still drawn somewhere.
func _tilted_weight(kind: WildlifeData, wildness: float) -> float:
	# **A mythic is never scattered.** That is the whole of what the
	# classification means: it weighs nothing in the roll, so the only way one
	# reaches the field is `place_mythic`, at the end of its own trail.
	if kind.mythic:
		return 0.0
	var weight: float = kind.roll_weight(RunState.act)
	if wildness <= 0.0:
		return weight
	var lean: float = 1.0 + wildness * (Balance.WILDLIFE_WILDS_TILT - 1.0)
	if kind.is_hostile():
		weight *= lean
	else:
		weight /= lean
	# Rarity rides the same slope: a Legendary is a thing you go looking for.
	weight *= 1.0 + wildness * float(kind.rarity) * 0.5
	return weight


## The opening Preparation is the player's guaranteed safe read of the board.
## No predator arrives before wave one; later breathers retain the living-world
## pressure the travelling party has already encountered.
func _hostile_arrivals_allowed() -> bool:
	# **Nothing hunts the Warden in the valley.** The Walk teaches that most of
	# what lives out here is harmless by being a place where that is true; a
	# wolf arriving during the lesson about harmless animals would teach the
	# opposite of the sentence on the card.
	if RunState.walking:
		return false
	return not (RunState.is_preparation() and RunState.wave_number == 0)


## Empties the road, and keeps it empty until the boss is down.
##
## Capped rather than open-ended. Clearing it is `boss_defeated`, and a run where
## that never arrives - a boss removed by something else, a state nobody thought
## about - would otherwise leave the wilderness silent for the rest of the act
## with nothing to say why. A cap makes the worst case "the animals came back
## early" instead of "the world died".
func _hush() -> void:
	_hush_left = Balance.WILDLIFE_HUSH_SECONDS
	# A guest mirrors the host's animals, so making them bolt locally would fight
	# the positions arriving over the wire. The host emptying the road empties it
	# for both, which is the same rule the spawner already follows.
	if Coop.is_guest():
		return
	for animal: Dictionary in _living:
		var kind := animal.get("data", null) as WildlifeData
		var sprite := animal.get("sprite", null) as Sprite2D
		if kind == null or sprite == null or not is_instance_valid(sprite):
			continue
		if kind.is_hostile() or float(animal.get("dying", 0.0)) > 0.0:
			continue
		animal["state"] = State.LEAVING
		animal["goal"] = _bolt_target(sprite.global_position)


## True while the road is holding its breath. For anything that wants to know.
func is_hushed() -> bool:
	return _hush_left > 0.0


## True when this machine decides things *and* somebody is listening.
func _is_authority_with_company() -> bool:
	return Coop.is_host() and Coop.partner_present()


## Recorded on the host only: a guest's animals are mirrors of the host's, and
## both machines counting the same deer would be the same discovery twice.
func _remember(kind: WildlifeData) -> void:
	if kind != null and Coop.is_host():
		MetaState.record_seen("wildlife", kind.id)


func _spawn(kind: WildlifeData, at: Vector2, mirrored_id: int = 0,
		group_id: int = 0, told_shiny: int = -1, born: Dictionary = {}) -> void:
	_remember(kind)
	var path: String = kind.get_sprite_path()
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.scale = Vector2.ONE * kind.scale
	# Walks or flies in from off the edge, so nothing pops into existence in the
	# middle of a field somebody is looking at.
	#
	# **Except something born, which is already here** (2026-09-14). A cub
	# placed at the entry point would be carried 1500 units from its mother and
	# walk the whole way back, which is not a birth - it is an arrival wearing a
	# birth's clothes, and the family would never form.
	if born.is_empty():
		sprite.global_position = at + Vector2(
			Balance.WILDLIFE_ENTRY_DISTANCE * (1.0 if _rng.randf() < 0.5 else -1.0),
			-Balance.WILDLIFE_ENTRY_DISTANCE if kind.flies else 0.0)
	else:
		sprite.global_position = at
	sprite.z_as_relative = false
	(host if host != null else self).add_child(sprite)
	var impact_material: ShaderMaterial = ActorPolishScript.attach(sprite)
	# Born with its sack `hoard_chance` of the time. Rolled on both machines
	# from the same stream like the rabid roll above; the host's word arrives
	# as a fact as well, so a guest that rolled differently is corrected.
	# What this animal plants on the ground (owner, 2026-09-17). Re-read when it
	# grows, in `WildlifeFamilies._apply_stage`.
	Footfalls.register_animal(sprite, kind, 1.0)
	var innate: bool = kind.hoards and _rng.randf() < kind.hoard_chance
	if innate:
		_hang_sack(sprite, kind)


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

	# -1 means "decide for yourself"; anything else is the host having
	# already decided. A guest must never roll - it draws from its own
	# stream and would disagree with the host about which animal shone.
	var shiny: bool = told_shiny == 1
	if born.has("shiny"):
		# A birth's shine is its parents' business, decided before it is placed.
		shiny = bool(born["shiny"])
	elif told_shiny < 0:
		shiny = SpiritBond.rolls_shiny(kind.id, kind.rarity, _rng)
	if shiny:
		_dress_as_shiny(sprite, kind, impact_material)
	# **Rank, said in light** (owner, 2026-09-15: "rarer wildlife should have it
	# as well slightly as well as a slight colour tint to indicate their rarity
	# as well as having an outline aura too. Shinys should be super holographic
	# and high contrast ... especially legendary shinies").
	#
	# The amplitude climbs with the rarity and a shiny jumps to the top of the
	# scale, so a Legendary shiny is the loudest thing on the road and a Common
	# one wears nothing at all - which is what keeps the signal worth reading.
	_wear_rarity(sprite, kind.rarity, shiny)

	# **Every animal gets a serial, co-op or not.**
	#
	# It used to be assigned only when there was somebody to tell, so in a solo
	# run every animal in the game had serial zero. That was harmless while the
	# number was only an address; it stopped being harmless when personalities
	# started being derived from it, because zero for everything is one
	# personality for everything. The guest still takes the host's number, so
	# both machines agree without a packet.
	var identity: int = mirrored_id
	if identity == 0:
		_net_id += 1
		identity = _net_id
		if _is_authority_with_company():
			EventBus.coop_wildlife_spawned.emit(identity, kind.id, at, shiny)

	# **And its own coat**, derived from that serial. Here rather than beside the
	# material, because the serial is only decided above - and a coat seeded
	# from a number that is zero for every animal in a solo run is one coat for
	# the whole road, which is exactly what happened to spirit personalities.
	Phenotype.dress(impact_material, kind, identity)

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

	# **Rolled once, here, and never again.** A shiny is decided when the animal
	# is placed, so nothing the player does to one already on the field can
	# reroll it - no walking away and back, no save-scumming a sighting.
	_living.append({
		"net_id": identity,
		"data": kind,
		"shiny": shiny,
		# Fixed when the animal is placed, and readable off it from that moment.
		# Nothing the player does can reroll a temperament, for the same reason
		# nothing can reroll a shiny.
		"trait": SpiritBond.trait_for(kind.id, identity),
		# One animal is one encounter, however many times it is hit or approached.
		"credited": false,
		"group_id": group_id,
		"sprite": sprite,
		# Something born is already where it belongs, so it starts settled
		# rather than walking in from the edge.
		"state": State.SETTLED if not born.is_empty() else State.ARRIVING,
		"home": at,
		"goal": at,
		"base": sprite.texture,
		"idle": GameData.load_idle_frames(path),
		"move": GameData.load_move_frames(path),
		# Head down. Only the grazers have these, and only they graze.
		"graze": GameData.load_state_frames(path, "graze"),
		"graze_left": 0.0,
		"alert_left": 0.0,
		"alert_from": Vector2.ZERO,
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
		# The base frame's height, which every other frame is anchored by.
		"ref_h": float(sprite.texture.get_height()) if sprite.texture != null else 0.0,
		"heading": Vector2.RIGHT,
		"face_hold": 0.0,
		"bank": 0.0,
		# Born rabid: a hostile that fights everything and bites poison. Rolled
		# from the run's stream so both machines agree.
		"rabid": kind.is_hostile() and _rng.randf() < Balance.WILDLIFE_RABID_CHANCE,
		# Whether this one keeps the truce by the water.
		"truce": _rng.randf() < Balance.WILDLIFE_POND_TRUCE_CHANCE,
		"drinking": false,
		# A thief's sack, what is in it, and its clocks. `innate` is the hoard
		# it was born with, rolled only when it dies; `loot` is what it took.
		"sack": innate,
		"innate": innate,
		"loot": [],
		"look": _rng.randf() * Balance.THIEF_LOOK_TICK,
		"hide_left": 0.0,
		"forage_left": 0.0,
		"forage_dust": 0.0,
		"glint": 0.0,
		"hiding": false,
		"target_loot": 0,
	})
	if innate and _is_authority_with_company():
		EventBus.coop_wildlife_sack.emit(identity, true, false)
	# Its sex, its own rarity, its stage of growth and whether it is sickening.
	# Done before the shadow and the anchor, because a baby is a different size
	# and both are measured from it.
	if _families != null:
		_families.decorate(_living[_living.size() - 1], kind, born)
		size = float(_living[_living.size() - 1].get("size", size))
	_apply_visual_anchor(sprite, kind, size, kind.flies, 0.0,
		float(sprite.texture.get_height()) if sprite.texture != null else 0.0)
	# Held on the animal rather than looked up by name every frame: `hold_level`
	# runs per animal per frame, and a string lookup there is a string lookup
	# times the population cap.
	var cast_shadow: Sprite2D = _cast_shadow(sprite, kind, size)
	_living[_living.size() - 1]["shadow"] = cast_shadow
	_living[_living.size() - 1]["shadow_scale"] = \
		cast_shadow.scale if cast_shadow != null else Vector2.ONE
	_living[_living.size() - 1]["shadow_alpha"] = \
		cast_shadow.modulate.a if cast_shadow != null else 1.0
	_living[_living.size() - 1]["shadow_up"] = 0.0
	if bool(_living.back()["rabid"]):
		_dress_as_rabid(sprite, kind)
	if not kind.vocal_sfx.is_empty():
		Sfx.play_at(kind.vocal_sfx, sprite.global_position, -3.0,
			voice_pitch(kind, float(_living.back().get("size", 1.0))))


## One animal, one frame. False when it should be removed.
func _tick_one(animal: Dictionary, delta: float) -> bool:
	var sprite := animal["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return false
	var kind := animal["data"] as WildlifeData

	# Asked before the dying check, and only while the animal is still whole: a
	# corpse is not a bond, and neither is standing next to one.
	if not kind.is_hostile() and float(animal["dying"]) <= 0.0:
		_offer_bond(animal)

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

	# Up a tree with the water under it. Nothing else happens to a climber
	# until the flood falls; then it comes down and carries on as it was.
	if bool(animal.get("treed", false)):
		if RunState.flood < Balance.FLOOD_CLIMB_DOWN:
			animal["treed"] = false
			sprite.modulate.a = 1.0
			sprite.position.y += Balance.WILDLIFE_CLIMB_LIFT
			animal["state"] = State.SETTLED
			animal["goal"] = sprite.global_position
		return true
	if bool(animal.get("climbing", false)) and int(animal["state"]) == State.FLEEING:
		if (animal["goal"] as Vector2).distance_to(sprite.global_position) < 10.0:
			animal["climbing"] = false
			animal["treed"] = true
			# Up the trunk and half hidden in the leaves.
			sprite.position.y -= Balance.WILDLIFE_CLIMB_LIFT
			sprite.modulate.a = 0.55
			Vfx.dust(sprite.global_position, Color("6b7a4a"), 5, 30.0)
			return true

	# Burning: hurt a little every frame until it goes out, and lit while it does.
	if float(animal.get("burning", 0.0)) > 0.0:
		animal["burning"] = float(animal["burning"]) - delta
		sprite.modulate = Color(1.0, 0.6, 0.35) if fmod(float(animal["burning"]), 0.2) < 0.1 else Color.WHITE
		if not Coop.is_guest():
			var index: int = _living.find(animal)
			if index >= 0:
				_wound(index, animal, Balance.WILDFIRE_WILDLIFE_DPS * delta, false)
				if float(animal["dying"]) > 0.0:
					return true
		if float(animal["burning"]) <= 0.0:
			sprite.modulate = Color.WHITE

	# A hoarder's clock runs whatever it is doing, and when it runs out the
	# animal does not walk to the edge - it rifts, because the walk would be
	# the window it just ran out of.
	if kind.hoards:
		var left: float = float(animal["patience"])
		var sack: CanvasItem = sprite.get_node_or_null("Sack") as CanvasItem
		if sack != null:
			var warning: bool = left <= Balance.WILDLIFE_HOARD_WARNING_SECONDS
			var lit: bool = warning and fmod(left, 0.3) < 0.15
			sack.modulate = Color(1.0, 0.55, 0.45) if lit else Color.WHITE
			# The sack glints: the tell that this one is worth the chase, and
			# it stops glinting when the animal lies low with it.
			animal["glint"] = float(animal.get("glint", 0.0)) - delta
			if float(animal["glint"]) <= 0.0 and not bool(animal.get("hiding", false)):
				animal["glint"] = Balance.THIEF_SACK_GLINT_SECONDS
				Vfx.spark(sack.global_position, Color(1.0, 0.86, 0.45), 3, Vector2.UP, 90.0)
		if left <= 0.0:
			_rift_out(animal, sprite)
			return false

	# A hostile that survived a phase transition also leaves without taking one
	# last bite. Arrival filtering handles the normal opening path; this closes
	# the race at the phase boundary.
	if kind.is_hostile() and not _hostile_arrivals_allowed():
		animal["state"] = State.LEAVING
		animal["goal"] = _bolt_target(sprite.global_position)

	# **Mending**, before anything decides anything: an animal that has been left
	# alone is slowly coming back, and a long-lived one that was hurt early in a
	# region should not still be at a sliver when the road leaves it.
	_mend(animal, kind, delta)

	# A thief decides its own frames: the loot it saw, the cover it runs to,
	# the plant it digs at. The host decides; a guest's puppet is walked by
	# the batch and dressed by the sack fact.
	if kind.steals and _is_authority_or_alone():
		if _tick_thief(animal, sprite, kind, delta):
			return true

	# Growing, courting, sickening. A courting animal is doing nothing else,
	# which is what the true means; everything else falls through.
	if _families != null and _families.tick_animal(animal, sprite, kind, delta):
		_animate(animal, sprite, delta, false)
		return true

	# **An amphibious animal owns the frame while it is in the water**, and hands
	# it straight back the moment it is out - everything on the bank is the
	# roster's own states. See `_tick_amphibian`.
	if kind.amphibious and _tick_amphibian(animal, sprite, kind, delta):
		return true

	# A hostile animal decides differently, and gets first refusal on the frame.
	# A frenzied one hunts whatever its species is: the Wildblight is what turns
	# a rabbit into something that comes at you.
	if (kind.is_hostile() or WildlifeFamilies.is_frenzied(animal)
			or bool(animal.get("angered", false))) \
			and int(animal["state"]) != State.LEAVING:
		if _tick_hostile(animal, sprite, kind, delta):
			return true

	if int(animal["state"]) == State.SETTLED:
		var scare: Vector2 = _threat_near(sprite.global_position, kind.skittish_radius) \
			if _frightened(sprite.global_position, kind) else Vector2.INF
		if scare != Vector2.INF or _frightened(sprite.global_position, kind):
			animal["state"] = State.FLEEING
			animal["drinking"] = false
			animal["goal"] = _bolt_target(sprite.global_position, scare)
		elif float(animal["patience"]) <= 0.0:
			animal["state"] = State.LEAVING
			animal["goal"] = _bolt_target(sprite.global_position)

	# Grazing and being alert are stationary states with their own clocks.
	if int(animal["state"]) == State.GRAZING or int(animal["state"]) == State.ALERT:
		if _tick_grazing(animal, sprite, kind, delta):
			return true

	var state: int = int(animal["state"])
	# A baby is slower than its mother, and a collapsing one slower still.
	var speed: float = kind.speed * _savage_speed(animal) \
		* WildlifeFamilies.speed_scale(animal)
	if not kind.flies:
		speed *= RunState.flood_slow()
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
		_walk_step(sprite, step)
		# Facing from motion, against the *art's own* direction rather than a
		# guess. The sprites are drawn facing left, the flip was written for
		# right-facing art, and the result was six species walking backwards.
		animal["heading"] = direction
		_face(animal, sprite, kind, step, delta)
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
					# A grazer with graze frames puts its head down more often
					# than it wanders. Owner brief, 2026-09-12: subtle cues -
					# a deer that stops eating is a deer that noticed something.
					if bool(animal.get("drinking", false)):
						# Arrived at the water: head down and drink a while.
						animal["drinking"] = false
						animal["state"] = State.GRAZING
						animal["graze_left"] = _rng.randf_range(
							Balance.WILDLIFE_DRINK_SECONDS.x, Balance.WILDLIFE_DRINK_SECONDS.y)
						animal["frame_clock"] = 0.0
					elif kind.movement_style == WildlifeData.MovementStyle.GRAZER \
							and not (animal["graze"] as Array).is_empty() \
							and _rng.randf() < Balance.WILDLIFE_GRAZE_CHANCE:
						animal["state"] = State.GRAZING
						animal["graze_left"] = _rng.randf_range(
							Balance.WILDLIFE_GRAZE_SECONDS.x, Balance.WILDLIFE_GRAZE_SECONDS.y)
						animal["frame_clock"] = 0.0
					elif not kind.flies and not kind.is_hostile() \
							and _rng.randf() < Balance.WILDLIFE_DRINK_CHANCE:
						var rim: Vector2 = _drink_spot(sprite.global_position)
						if rim != Vector2.INF:
							animal["drinking"] = true
							animal["goal"] = rim
						else:
							animal["goal"] = _wander_from(animal["home"] as Vector2, kind)
					else:
						animal["goal"] = _wander_from(animal["home"] as Vector2, kind,
							WildlifeFamilies.roam_scale(animal))

	_animate(animal, sprite, delta, moving)
	return true


## Head down, or head up and listening.
##
## Grazing runs the graze frames and watches a wider circle than the flee
## radius. Something inside that circle lifts the head: ALERT, base frame, for
## a moment. Then a decision - the thing is inside the flee radius and the
## animal bolts as it always did; it is merely near and the animal walks off a
## little way to graze somewhere quieter; it has gone and the head goes back
## down. A field of deer that lift their heads a beat before the wolf shows
## is the field telling the player something.
func _tick_grazing(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData,
		delta: float) -> bool:
	var state: int = int(animal["state"])
	animal["patience"] = float(animal["patience"]) - delta
	var threat: Vector2 = _nearest_threat(sprite.global_position,
		kind.skittish_radius * Balance.WILDLIFE_NOTICE_SCALE)
	if state == State.GRAZING:
		if threat != Vector2.INF:
			animal["state"] = State.ALERT
			animal["alert_left"] = Balance.WILDLIFE_ALERT_SECONDS
			animal["alert_from"] = threat
			animal["frame_clock"] = 0.0
			_animate(animal, sprite, delta, false)
			return true
		animal["graze_left"] = float(animal["graze_left"]) - delta
		var frames: Array = animal["graze"] as Array
		if not frames.is_empty():
			animal["frame_clock"] = float(animal["frame_clock"]) + delta * Balance.WILDLIFE_IDLE_FRAME_RATE
			var index: int = int(floor(float(animal["frame_clock"]))) % frames.size()
			sprite.texture = frames[index] as Texture2D
			sprite.scale = Vector2.ONE * kind.scale * float(animal["size"])
			sprite.rotation = 0.0
			_apply_visual_anchor(sprite, kind, float(animal["size"]), false, 0.0, float(animal.get("ref_h", 0.0)))
		if float(animal["graze_left"]) <= 0.0:
			# Nothing around: a while longer. Otherwise back to standing.
			if _nearest_threat(sprite.global_position,
					kind.skittish_radius * Balance.WILDLIFE_NOTICE_SCALE * 1.5) == Vector2.INF \
					and _rng.randf() < 0.5:
				animal["graze_left"] = Balance.WILDLIFE_GRAZE_SAFE_BONUS
			else:
				animal["state"] = State.SETTLED
				animal["pause"] = _rng.randf_range(0.6, 1.8)
		return true
	# ALERT: head up, still, watching.
	animal["alert_left"] = float(animal["alert_left"]) - delta
	var from: Vector2 = animal["alert_from"] as Vector2
	_face(animal, sprite, kind, from - sprite.global_position, delta, true)
	_animate(animal, sprite, delta, false)
	if float(animal["alert_left"]) > 0.0:
		return true
	var near: Vector2 = _nearest_threat(sprite.global_position, kind.skittish_radius)
	if near != Vector2.INF:
		animal["state"] = State.FLEEING
		animal["drinking"] = false
		animal["goal"] = _bolt_target(sprite.global_position, near)
		return true
	var still_there: Vector2 = _nearest_threat(sprite.global_position,
		kind.skittish_radius * Balance.WILDLIFE_NOTICE_SCALE)
	if still_there != Vector2.INF:
		# Not worth running from, not worth staying beside: walk off a little,
		# away from it, and settle there.
		var away: Vector2 = (sprite.global_position - still_there).normalized()
		var goal: Vector2 = sprite.global_position + away * Balance.WILDLIFE_RELOCATE_DISTANCE
		if _is_clear(goal):
			animal["home"] = goal
			animal["goal"] = goal
		else:
			animal["goal"] = _wander_from(animal["home"] as Vector2, kind)
		animal["state"] = State.SETTLED
		animal["pause"] = _rng.randf_range(1.0, 2.5)
		return true
	# It went away. Head back down.
	animal["state"] = State.GRAZING
	animal["graze_left"] = _rng.randf_range(Balance.WILDLIFE_GRAZE_SECONDS.x,
		Balance.WILDLIFE_GRAZE_SECONDS.y)
	return true


## The nearest thing a grazer would notice within `radius`, or INF.
func _nearest_threat(at: Vector2, radius: float) -> Vector2:
	var best: Vector2 = Vector2.INF
	var nearest: float = radius
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Node2D
		if hero == null:
			continue
		var gap: float = at.distance_to(hero.global_position)
		if gap < nearest:
			nearest = gap
			best = hero.global_position
	if field != null and field.has_method("enemies_near"):
		for enemy: Enemy in field.enemies_near(at, radius):
			if enemy.is_dying():
				continue
			var gap: float = at.distance_to(enemy.global_position)
			if gap < nearest:
				nearest = gap
				best = enemy.global_position
	for other: Dictionary in _living:
		var hunter_kind := other.get("data", null) as WildlifeData
		var hunter := other.get("sprite", null) as Sprite2D
		if hunter_kind == null or hunter == null or not is_instance_valid(hunter):
			continue
		if not hunter_kind.is_hostile() or float(other.get("dying", 0.0)) > 0.0:
			continue
		var gap: float = at.distance_to(hunter.global_position)
		if gap < nearest:
			nearest = gap
			best = hunter.global_position
	return best


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
		airborne: bool, extra_lift: float = 0.0, reference_height: float = 0.0) -> void:
	if sprite.texture == null:
		return
	var visual_scale: float = maxf(kind.scale * size, 0.001)
	sprite.offset.x = 0.0
	# **The base frame's height, whatever frame is showing.** Lifting by the
	# current texture's height moved the whole animal every time a sequence
	# with a different canvas came in - a moth jumped a few pixels on every
	# switch between its idle and its flight (owner report, 2026-09-12).
	var height: float = reference_height if reference_height > 0.0 \
		else float(sprite.texture.get_height())
	var ground_lift: float = height * Balance.WILDLIFE_FEET_ANCHOR
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
		_apply_visual_anchor(sprite, kind, float(animal["size"]), kind.flies, 0.0, float(animal.get("ref_h", 0.0)))
		var phase: float = float(swing) / maxf(float(striking.size() - 1), 1.0)
		var lunge: float = sin(phase * PI) * Balance.WILDLIFE_ATTACK_LUNGE
		sprite.offset.x = lunge * (-1.0 if sprite.flip_h else 1.0) \
			/ maxf(sprite.scale.x, 0.001)
		return
	var flight := animal["fly"] as Array
	var frames: Array = animal["idle"] as Array
	var rate: float = Balance.WILDLIFE_IDLE_FRAME_RATE
	var flying_now: bool = false
	if moving:
		var airborne: bool = kind.flies and not flight.is_empty()
		flying_now = airborne
		frames = flight if airborne else (animal["move"] as Array)
		rate = Balance.WILDLIFE_FLIGHT_FRAME_RATE if airborne \
			else Balance.WILDLIFE_MOVE_FRAME_RATE
	# **The moment it leaves the ground**, and only that moment: two wingbeat
	# recordings existed and were reached by nothing, and playing one every
	# frame a bird is in the air would be a rotor rather than a wing.
	if flying_now and not bool(animal.get("was_flying", false)):
		var wing: String = kind.wing_sfx()
		if not wing.is_empty():
			Sfx.play_group_at(wing, sprite.global_position, -7.0)
	animal["was_flying"] = flying_now
	_bank(animal, sprite, kind, delta, moving)
	if not frames.is_empty():
		animal["frame_clock"] = float(animal["frame_clock"]) + delta * rate
		var index: int = int(floor(float(animal["frame_clock"]))) % frames.size()
		sprite.texture = frames[index] as Texture2D
		sprite.scale = Vector2.ONE * kind.scale * float(animal["size"])
		_apply_visual_anchor(sprite, kind, float(animal["size"]), kind.flies and moving, 0.0, float(animal.get("ref_h", 0.0)))
		# **One authored frame is a pose, not a cycle.**
		#
		# Three of the six could not be given a matching second walk frame - the
		# generator returns a different size or a different shade every time - so
		# rather than ship a mismatched pair that flickers, a single-frame walker
		# gets its motion from a hop: rise and fall with a squash at the bottom.
		#
		# For a rabbit or a squirrel that is not a compromise, it is the correct
		# gait. Skipped for anything with a real cycle, which is already moving.
		if moving and frames.size() <= 2 and kind.hops and not kind.flies:
			animal["bob"] = float(animal["bob"]) + delta * Balance.WILDLIFE_HOP_RATE
			var phase: float = float(animal["bob"])
			var lift: float = absf(sin(phase))
			_apply_visual_anchor(sprite, kind, float(animal["size"]), false,
				lift * Balance.WILDLIFE_HOP_HEIGHT, float(animal.get("ref_h", 0.0)))
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
				absf(sway) * Balance.WILDLIFE_STRIDE_LIFT, float(animal.get("ref_h", 0.0)))
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
		bob * Balance.WILDLIFE_STRIDE_LIFT, float(animal.get("ref_h", 0.0)))
	_hold_the_shadow(animal, sprite, kind.flies and moving, delta)


## **The shadow, level and beneath, at the size the animal's height earns.**
##
## Every rotation in this file lands on the sprite - a top-down flier turned onto
## its heading, a banking one rolling, a dying one going over - and the shadow is
## a child of that sprite, so all three carried it round with them. This undoes
## the turn and answers the flier's height, and it is the one place that does, so
## a rotation added later cannot forget about it.
func _hold_the_shadow(animal: Dictionary, sprite: Sprite2D, airborne: bool,
		delta: float) -> void:
	var held: Variant = animal.get("shadow")
	if held == null or not is_instance_valid(held as Object):
		return
	# Eased: a hovering moth crosses the moving threshold several times a second
	# and a snapped shadow flickers between two sizes while it does.
	var up: float = lerpf(float(animal.get("shadow_up", 0.0)), 1.0 if airborne else 0.0,
		clampf(Balance.WILDLIFE_SHADOW_EASE * delta, 0.0, 1.0))
	animal["shadow_up"] = up
	ShadowKit.hold_level(held as Sprite2D, sprite,
		animal.get("shadow_scale", Vector2.ONE) as Vector2,
		float(animal.get("shadow_alpha", 1.0)), up,
		Balance.WILDLIFE_SHADOW_AIRBORNE_SHRINK, Balance.WILDLIFE_SHADOW_AIRBORNE_FADE)


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
	# **Unless somebody hit it.** The rule above is about a predator *choosing*
	# to hunt in the quiet phase. An animal that has just been struck is not
	# choosing anything, and one that drifts politely away while being cut down
	# is a free carcass rather than a wild animal (owner, 2026-09-16).
	animal["provoked"] = maxf(float(animal.get("provoked", 0.0)) - delta, 0.0)
	if RunState.is_preparation() and float(animal.get("provoked", 0.0)) <= 0.0:
		if int(animal["state"]) == State.STALKING 				or int(animal["state"]) == State.STRIKING:
			return _break_off(animal, sprite)
		_drift_from_town(animal, sprite)
		return false

	animal["wary"] = maxf(float(animal["wary"]) - delta, 0.0)
	if float(animal["hunt"]) > 0.0 and not bool(animal.get("rabid", false)):
		animal["hunt"] = float(animal["hunt"]) - delta
		if float(animal["hunt"]) <= 0.0:
			return _break_off(animal, sprite)
	elif float(animal["wary"]) > 0.0:
		return false

	var quarry: Node2D = _quarry_for(sprite.global_position, kind, sprite,
		bool(animal.get("rabid", false)), bool(animal.get("truce", false)),
		bool(animal.get("angered", false)))
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
		_face(animal, sprite, kind, toward, delta, true)
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
	_walk_step(sprite, step)
	animal["heading"] = toward.normalized()
	_face(animal, sprite, kind, step, delta)
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
## Whether a point is inside the city's walls, if there are any here.
##
## Asked of the field rather than answered locally: the battlefield has a
## town and an arena does not, and a second copy of that arithmetic is how
## the wildlife ends up sheltering somebody the enemies are still hunting.
func _sheltered(at: Vector2) -> bool:
	var arena: EnemyField = field as EnemyField
	if arena == null or not is_instance_valid(arena):
		return false
	return arena.inside_city(at)


## Moves an animal, and never into the city.
##
## Owner, 2026-09-17: *"No wildlife or enemies are able to enter the city
## base either."* One function for all three places an animal steps - the
## walk, the charge and the swim - because three copies of a refusal is two
## that will not be fixed the next time the first one is.
##
## **Refuses entering, never leaving**, for the reason `step_is_legal` gives:
## an animal that somehow starts inside has to be able to get out.
func _walk_step(sprite: Node2D, step: Vector2) -> void:
	var to: Vector2 = sprite.global_position + step
	if _sheltered(to) and not _sheltered(sprite.global_position):
		return
	sprite.global_position = to


func _quarry_for(at: Vector2, kind: WildlifeData, self_sprite: Node2D = null,
		rabid: bool = false, truce: bool = false, angered: bool = false) -> Node2D:
	var best: Node2D = null
	# A frenzied grazer has no aggro radius of its own - nothing harmless does -
	# so the blight lends it one, or a turned rabbit would look for trouble and
	# find none (2026-09-14).
	var reach: float = kind.aggro_radius
	if rabid or angered:
		reach = maxf(reach, Balance.WILDBLIGHT_FRENZY_AGGRO) * 1.5
	var best_distance: float = reach
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero == null or not hero.is_alive():
			continue
		# **A predator loses you at the gate** (owner, 2026-09-17: *"If players
		# enter the city base while being chased by wildlife predators, the
		# predators will leave the player alone once they enter the city base"*).
		# Asked every time quarry is chosen rather than once at the start of a
		# hunt, so a chase that follows somebody to the wall ends there.
		if _sheltered(hero.global_position):
			continue
		var distance: float = at.distance_to(hero.global_position)
		if distance < best_distance:
			best_distance = distance
			best = hero
	# And the companions, the same as a hero (owner brief, 2026-09-12).
	for node: Node in get_tree().get_nodes_in_group(Companion.GROUP):
		var spirit := node as Companion
		if spirit == null or not spirit.is_alive():
			continue
		var distance: float = at.distance_to(spirit.global_position)
		if distance < best_distance:
			best_distance = distance
			best = spirit
	if field != null and field.has_method("enemies_near"):
		for enemy: Enemy in field.enemies_near(at, kind.aggro_radius):
			if enemy.is_dying():
				continue
			var distance: float = at.distance_to(enemy.global_position)
			if distance < best_distance:
				best_distance = distance
				best = enemy

	# **And the small things living out here.**
	#
	# Owner request, 2026-09-01: the world should carry on when the player is not
	# involved. A fox that walks past a rabbit to reach a soldier is a fox that
	# only exists for the fight, and the road is supposed to be somewhere the
	# fight is happening rather than the only thing there is.
	#
	# **A chase, never a meal.** `_strike` accepts a Hero or an Enemy and refuses
	# everything else - deliberately, and it says so - which means a predator can
	# be pointed at a rabbit and simply cannot hurt it. That bound is what keeps
	# this pure atmosphere: nothing here can eat a Spirit Companion the player
	# was three encounters away from bonding, and the ecology cannot quietly
	# become a second attrition system nobody is balancing.
	#
	# The rabbit is not helpless either. `_frightened` now counts predators, so
	# what the player sees is a hunt that the prey usually wins by leaving.
	# Deliberately the shorter reach, and stated as its own number rather than
	# folded into the comparison: a predator should notice the player and the
	# soldiers first, and turn to prey only when something small is well inside
	# its radius. Written once as `distance < best_distance * interest` it was
	# comparing against whatever had already been found, which is a different
	# rule that happens to look like this one.
	var prey_reach: float = reach * Balance.WILDLIFE_PREY_INTEREST
	if rabid:
		prey_reach = best_distance
	for other: Dictionary in _living:
		var prey_kind := other.get("data", null) as WildlifeData
		var prey := other.get("sprite", null) as Sprite2D
		if prey_kind == null or prey == null or not is_instance_valid(prey):
			continue
		# A rabid animal has no kin; everything else leaves its own kind alone.
		if (prey_kind.is_hostile() and not rabid) or prey == self_sprite:
			continue
		if float(other.get("dying", 0.0)) > 0.0:
			continue
		# The truce by the water: most animals do not hunt at the pond, so a
		# deer drinking beside a wolf is a scene rather than a kill.
		if truce and not rabid and _near_water(prey.global_position):
			continue
		var distance: float = at.distance_to(prey.global_position)
		if distance < prey_reach and distance < best_distance:
			best_distance = distance
			best = prey
	return best


## One blow, against whatever it caught.
func _strike(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData,
		quarry: Node2D) -> void:
	# Wildlife may fight heroes, road enemies and - since 2026-09-12 - the
	# smaller animals it chases. Never structures: keeping the accepted types
	# explicit makes a future broad target group unable to turn a wolf into a
	# town attacker by accident.
	if quarry is Companion:
		var spirit := quarry as Companion
		var bite: float = _bite_of(animal, kind)
		spirit.take_damage(bite, sprite.global_position)
		if bool(animal.get("rabid", false)):
			spirit.apply_poison(Balance.WILDLIFE_RABID_POISON_DPS, Balance.WILDLIFE_RABID_POISON_SECONDS)
		if not kind.vocal_sfx.is_empty():
			Sfx.play_at(kind.vocal_sfx, sprite.global_position, -4.0,
				voice_pitch(kind, float(animal.get("size", 1.0))))
		return
	if not (quarry is Hero) and not (quarry is Enemy):
		# Prey. Owner report: predators followed prey and never bit it. The bite
		# is a share of the prey's own health, paid to nobody: a wolf's kill
		# drops no Food, banks no encounter and pays no experience, so the
		# ecology cannot become a farm. A Spirit Companion is a `Companion`,
		# not a wildlife record, and is never in this list.
		for index: int in range(_living.size() - 1, -1, -1):
			var prey: Dictionary = _living[index]
			if prey.get("sprite", null) != quarry or float(prey.get("dying", 0.0)) > 0.0:
				continue
			var prey_kind := prey["data"] as WildlifeData
			_wound(index, prey, prey_kind.max_hp * Balance.WILDLIFE_PREY_BITE_SHARE, false)
			# A landed bite is the only way the Wildblight travels, and only
			# ever once per pair and once per carrier.
			if _families != null:
				_families.expose(animal, prey, prey_kind)
			Vfx.spark(quarry.global_position, Color("c4552e"), 5,
				(quarry.global_position - sprite.global_position).normalized(), 150.0)
			if not kind.vocal_sfx.is_empty():
				Sfx.play_at(kind.vocal_sfx, sprite.global_position, -6.0,
					voice_pitch(kind, float(animal.get("size", 1.0))))
			return
		return
	# Softer early, at full strength later. A wolf pack costs 8 a bite and the
	# hero has 100; three of them arriving in Act I read as the wilderness being
	# the boss fight. The ramp is by act rather than by wave so it is legible to
	# a player who noticed it, and so the late game is untouched.
	var power: float = _bite_of(animal, kind)
	var from: Vector2 = sprite.global_position
	var enemy := quarry as Enemy
	if enemy != null:
		enemy.take_damage(power, from, kind.knockback, false)
		# It gets to bite back, if the animal is still standing on top of it when
		# its next swing comes round. The road is not abandoned for this - see
		# `Enemy.provoked_by`.
		enemy.provoked_by(sprite, self)
		if bool(animal.get("rabid", false)) and enemy.has_method("apply_burn"):
			enemy.apply_burn(Balance.WILDLIFE_RABID_POISON_DPS, Balance.WILDLIFE_RABID_POISON_SECONDS)
	else:
		var health: Health = Health.of(quarry)
		if health != null:
			RunState.note_blow(kind.display_name, power)
			health.take_damage(power, from)
		if bool(animal.get("rabid", false)) and quarry.has_method("apply_poison"):
			quarry.call("apply_poison", Balance.WILDLIFE_RABID_POISON_DPS,
				Balance.WILDLIFE_RABID_POISON_SECONDS)
	Vfx.spark(quarry.global_position, Color("c4552e"), 6,
		(quarry.global_position - from).normalized(), 190.0)
	# **Felt where it bit.** A flat 3.0 shook the screen as hard for an animal
	# across the outskirts as for one at the player's feet - the same fault the
	# tower's destruction carried, in a second place that never learned about
	# `camera_impact`.
	EventBus.camera_impact.emit(quarry.global_position, 3.0)
	if not kind.vocal_sfx.is_empty():
		Sfx.play_at(kind.vocal_sfx, sprite.global_position, 0.0,
			voice_pitch(kind, float(animal.get("size", 1.0))))


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
	# And whatever hunts out here. A deer that bolted from a soldier and grazed
	# beside a wolf was the world only reacting to the war.
	for other: Dictionary in _living:
		var hunter_kind := other.get("data", null) as WildlifeData
		var hunter := other.get("sprite", null) as Sprite2D
		if hunter_kind == null or hunter == null or not is_instance_valid(hunter):
			continue
		if not hunter_kind.is_hostile() or float(other.get("dying", 0.0)) > 0.0:
			continue
		if at.distance_to(hunter.global_position) < kind.skittish_radius:
			return true
	return false


## A hero swung, and anything small enough nearby does not survive it.
##
## Heard rather than hunted. Wildlife stays out of the enemy group - towers would
## shoot rabbits and waves would never end - so the hero's blow is picked up from
## the bus and resolved here, where it cannot reach the combat systems at all.
func _on_swing_resolved(at: Vector2, aim: Vector2, reach: float, _step: int) -> void:
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


## Hits whatever animal is within `radius` of a point. Returns whether one was.
##
## The door an arrow comes through. Melee reaches wildlife because the swing is
## announced and this system resolves it; a shot was announced to nobody, so
## arrows passed straight through a wolf standing in the open while a sword
## killed it. Reported from play.
##
## Nearest first, so a shot into a herd takes the animal it was actually aimed
## at rather than whichever happens to sit lowest in the list.
##
## Host-only for the same reason as everything else that can kill: a guest
## dropping a deer locally would pay itself out and disagree with the host about
## what is standing on the field.
func wound_near(at: Vector2, radius: float, damage: float) -> bool:
	if Coop.is_guest():
		return false
	var best: int = -1
	var best_distance: float = radius
	for index: int in _living.size():
		var animal: Dictionary = _living[index]
		if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
			continue
		var sprite := animal["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		var distance: float = sprite.global_position.distance_to(at)
		if distance <= best_distance:
			best = index
			best_distance = distance
	if best < 0:
		return false
	_wound(best, _living[best], damage)
	return true


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


## Read-only projectile candidates, with stable identities and body anchors.
## Guests may resolve cosmetic impacts; wound_sprite still guards all damage.
func projectile_bodies(at: Vector2, radius: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for animal: Dictionary in _living:
		if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
			continue
		var body := animal.get("sprite") as Sprite2D
		if not is_instance_valid(body):
			continue
		var origin: Vector2 = _visual_origin(body)
		if origin.distance_squared_to(at) <= radius * radius:
			found.append({"body": body, "at": origin})
	return found


## Puts damage into one animal, and pays out if that finishes it.
##
## **A wounded animal comes back, slowly, and faster the longer it is left.**
##
## Deliberately too slow to matter inside a fight: at `WILDLIFE_REGEN_SHARE` a
## deer takes minutes to climb out of half, so breaking off and turning round
## meets the same animal. What it changes is the *region*: something wounded and
## left alone is whole again by the time the road comes back past it.
##
## The rate is a share of the animal's own pool rather than a flat number, which
## is what makes it respective to each species - a bear and a rabbit take the
## same time to come back from half, which is the only version of this that does
## not quietly make big animals unkillable or small ones invulnerable.
func _mend(animal: Dictionary, kind: WildlifeData, delta: float) -> void:
	var hp: float = float(animal.get("hp", 0.0))
	if hp <= 0.0 or float(animal.get("dying", 0.0)) > 0.0:
		return
	var full: float = kind.max_hp * (Balance.WILDLIFE_ELITE_HEALTH
		if bool(animal.get("elite", false)) else 1.0)
	if hp >= full:
		animal["calm"] = float(animal.get("calm", 0.0)) + delta
		return
	var calm: float = float(animal.get("calm", 0.0)) + delta
	animal["calm"] = calm
	# Eased in rather than switched on, so nothing visibly changes gear the
	# instant a clock runs out.
	var settled: float = clampf((calm - Balance.WILDLIFE_REGEN_CALM_SECONDS)
		/ maxf(Balance.WILDLIFE_REGEN_RAMP_SECONDS, 0.01), 0.0, 1.0)
	var rate: float = Balance.WILDLIFE_REGEN_SHARE \
		* lerpf(1.0, Balance.WILDLIFE_REGEN_CALM_SCALE, settled)
	animal["hp"] = minf(hp + full * rate * delta, full)
	var bar := animal.get("bar", null) as ProgressBar
	if bar != null and is_instance_valid(bar):
		bar.value = clampf(float(animal["hp"]) / maxf(full, 1.0), 0.0, 1.0)
		# Whole again: the bar goes away, which is how a player learns that
		# leaving something alone works.
		if float(animal["hp"]) >= full and not bool(animal.get("elite", false)):
			bar.visible = false


## The last sound it makes, and the sound of it landing.
##
## Two recordings rather than one: a body crying out and a body hitting the
## ground are different events and a player hears both. Seven death families
## and two falls were registered and reached by nothing before this.
func _say_it_fell(kind: WildlifeData, animal: Dictionary, at: Vector2) -> void:
	if kind == null:
		return
	Sfx.play_group_at(kind.death_sfx(), at, -1.0, voice_pitch(kind, float(animal.get("size", 1.0))))
	Sfx.play_group_at(kind.fall_sfx(), at, -6.0)


## Health rather than a one-hit kill, because the owner asked for size to matter:
## a rabbit should die to a swing and a deer should take a few, which is the only
## way "larger gives more" is a decision rather than a lottery.
func _wound(index: int, animal: Dictionary, damage: float = -1.0, by_player: bool = true) -> void:
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
	# **Struck by a person is a fact the phase does not get to overrule.**
	#
	# Set on the one funnel every wound goes through, so it cannot be written
	# from two places and disagree. Preparation still stops a predator starting a
	# hunt; this is what lets one finish a fight somebody else started.
	if by_player:
		animal["provoked"] = Balance.WILDLIFE_PROVOKED_SECONDS
	# **Hurt resets the calm.** Mending only accelerates after a stretch of not
	# being touched, and this is the one funnel every wound goes through, so
	# there is no second place that could forget to reset it.
	animal["calm"] = 0.0
	var body_at: Vector2 = _visual_origin(sprite)
	# **What the blow lands on, and what the animal says about it.**
	#
	# Five impact recordings and five cries had been made, registered and
	# mixed and played by nothing at all: every animal in this game took a
	# blow in silence. `WildlifeData.body` is what lets a fifty-one species
	# roster pick between them without a branch per animal (working rule 3).
	#
	# The surface first and the cry under it, pitched by the throat making
	# it - the same `voice_pitch` the vocalisations already use, so a fennec
	# yelps higher than a bear and a cub higher than either.
	Sfx.play_group_at(kind.hit_sfx(), body_at, -2.0)
	var cry: String = kind.hurt_sfx()
	if not cry.is_empty():
		Sfx.play_group_at(cry, body_at, -4.0, voice_pitch(kind, float(animal.get("size", 1.0))))
	Vfx.spark(body_at, Color("c4552e"), 6,
		Vector2.UP, 170.0)
	Vfx.blood(body_at, Vector2.UP,
		Balance.VFX_BLOOD_HIT_SIZE if float(animal["hp"]) > 0.0 \
		else Balance.VFX_BLOOD_DEATH_SIZE * 0.75, sprite.global_position)
	if float(animal["hp"]) > 0.0:
		# Being hit is also a very good reason to leave - for a harmless
		# animal always, away from the blow; for a hostile one sometimes: it
		# breaks off, rests, and comes back at the fight from elsewhere. A
		# rabid one never breaks off (owner brief, 2026-09-12).
		if kind.is_hostile():
			if bool(animal.get("rabid", false)):
				return
			if _rng.randf() < Balance.WILDLIFE_HOSTILE_FLEE_CHANCE:
				animal["hunt"] = 0.0
				animal["wary"] = _rng.randf_range(Balance.WILDLIFE_HOSTILE_REGROUP.x,
					Balance.WILDLIFE_HOSTILE_REGROUP.y)
				animal["state"] = State.FLEEING
				animal["goal"] = _bolt_target(sprite.global_position, _threat_near(
					sprite.global_position, kind.aggro_radius))
			return
		animal["state"] = State.FLEEING
		animal["goal"] = _bolt_target(sprite.global_position,
			_threat_near(sprite.global_position, kind.skittish_radius * 1.5))
		return

	if not by_player:
		# A predator's kill. The body falls and that is all: no Food, no
		# experience, no encounter, nothing the player could farm by letting the
		# wolves do the hunting.
		Vfx.dust(sprite.global_position, Color("c4552e"), 8, 50.0)
		_say_it_fell(kind, animal, sprite.global_position)
		if _is_authority_with_company():
			EventBus.coop_wildlife_died.emit(int(animal["net_id"]))
		animal["dying"] = Balance.WILDLIFE_DEATH_SECONDS
		animal["state"] = State.LEAVING
		return

	# Food and experience both scale with the animal, rolled rather than fixed so
	# two deer are not worth exactly the same. Its own stream, so a seeded replay
	# is not changed by whether somebody stopped to hunt.
	var bounty: float = Balance.WILDLIFE_ELITE_REWARD if bool(animal["elite"]) else 1.0
	if bool(animal.get("savage", false)):
		bounty = Balance.HUNT_SAVAGE_REWARD
	elif not WildlifeFamilies.is_sick(animal):
		# One more of this kind on the tally; enough of them and its worst
		# comes looking (owner brief, 2026-09-13). A savage does not count
		# towards the next one - clearing the consequence is not more farming,
		# and neither is putting down something the blight already has.
		_tally_hunt(kind)
	# A fawn is worth a fraction of a hind: the stage scales what the body
	# gives, so a family is never worth more than the adults in it.
	bounty *= WildlifeFamilies.yield_scale(animal)
	var food: int = int(round(float(_rng.randi_range(kind.food_min, kind.food_max))
		* bounty))
	Vfx.dust(sprite.global_position, Color("c4552e"), 10, 60.0)
	_say_it_fell(kind, animal, sprite.global_position)
	if field != null and field.has_method("spawn_loot"):
		field.spawn_loot(RunState.FOOD, food, sprite.global_position)
	if kind.hoards or not (animal.get("loot", []) as Array).is_empty():
		_drop_the_hoard(animal, kind, sprite.global_position)
	RunState.gain_hero_xp(float(kind.xp_reward) * bounty)
	if _is_authority_with_company():
		EventBus.coop_wildlife_died.emit(int(animal["net_id"]))
	# **A mercy is not a hunt.** Putting down something the Wildblight has taken
	# costs the earth nothing and counts toward no tally: the animal was dying
	# anyway, and a consequence for ending it would read as the world punishing
	# the player for the only sensible answer to a frenzy. Everything else pays
	# exactly what it always did, at this animal's own rarity.
	if not WildlifeFamilies.is_sick(animal):
		EventBus.wildlife_killed.emit(kind.id, food, sprite.global_position,
			WildlifeFamilies.rarity_of(animal), bool(animal.get("shiny", false)),
			bool(animal.get("elite", false)) or bool(animal.get("savage", false)))
	# A hostile animal is bonded by besting it. The harmless ones are bonded by
	# getting close instead - see `_offer_bond` - because a collection system
	# that required slaughtering rabbits would be a different game.
	_credit_encounter(animal, SpiritBond.Kind.SLAIN)
	# The body stays until it has fallen; `_retire` announces it when it goes.
	# Left on the field to fall over rather than vanishing on the blow - a kill
	# that deletes its own body reads as the animal never having been there.
	animal["dying"] = Balance.WILDLIFE_DEATH_SECONDS
	animal["state"] = State.LEAVING


## Everything within `radius` of a point bolts from it. Fire, a funnel, the
## ground shaking - the animals do not stay to see what it was.
## **A spot beside the nearest place of this kind of work**, or INF.
##
## Beside rather than on: an animal standing in the middle of a seam is an animal
## the player cannot walk up to the seam past, and the whole point of these
## species is that they are found *at* the work rather than instead of it.
func _haunt_near(from: Vector2, wanted: String) -> Vector2:
	var best: Vector2 = Vector2.INF
	var nearest: float = Balance.WILDLIFE_HAUNT_REACH
	for place: Dictionary in haunts:
		if String(place.get("kind", "")) != wanted:
			continue
		var at: Vector2 = place.get("at", Vector2.ZERO)
		var away: float = from.distance_to(at)
		if away < nearest:
			nearest = away
			best = at
	if best == Vector2.INF:
		return Vector2.INF
	for _try: int in 8:
		var beside: Vector2 = best + Vector2.from_angle(_rng.randf() * TAU) 			* _rng.randf_range(Balance.WILDLIFE_HAUNT_CLEAR,
				Balance.WILDLIFE_HAUNT_CLEAR * 2.4)
		if _is_clear(beside):
			return beside
	return Vector2.INF


## Every living animal's body, for anything that wants to aim at one. Dying and
## already-dead records are left out: a rope thrown at a corpse is a rope the
## player will believe missed.
func living_sprites() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for animal: Dictionary in _living:
		if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
			continue
		var sprite: Variant = animal.get("sprite")
		if sprite != null and is_instance_valid(sprite as Object):
			out.append(sprite as Node2D)
	return out


## **One animal's record, by the instance id of its sprite.**
##
## By id rather than by reference because a rope in the air outlives the animal
## it was thrown at more often than not, and casting a freed object is an error
## in itself in this engine - raised before any guard inside could run.
func record_for_id(sprite_id: int) -> Dictionary:
	for animal: Dictionary in _living:
		var sprite: Variant = animal.get("sprite")
		if sprite != null and is_instance_valid(sprite as Object) \
				and (sprite as Object).get_instance_id() == sprite_id:
			return animal
	return {}


## **Taken off the road alive**, which is not a death: no drop, no experience, no
## wrath, no collection credit from here. `Taming` does the crediting, because
## meeting an animal and keeping one are two different facts.
##
## Retired through `_retire` rather than by freeing the sprite, because freeing
## one behind this system's back leaves `_living` pointing at a dead node and
## every later tick casts it - a fault this project has already paid for once.
func retire_by_id(sprite_id: int) -> bool:
	for index: int in _living.size():
		var sprite: Variant = _living[index].get("sprite")
		if sprite == null or not is_instance_valid(sprite as Object):
			continue
		if (sprite as Object).get_instance_id() != sprite_id:
			continue
		var at: Vector2 = (sprite as Node2D).global_position
		Vfx.ring(at, 70.0, Color(1.0, 0.92, 0.6, 0.7), 0.4, 3.0)
		Vfx.spark(at, Color(1.0, 0.9, 0.62), 12, Vector2.UP, 210.0)
		_retire(index)
		return true
	return false


func scare_from(at: Vector2, radius: float) -> void:
	for animal: Dictionary in _living:
		var sprite := animal["sprite"] as Sprite2D
		var kind := animal["data"] as WildlifeData
		if sprite == null or not is_instance_valid(sprite) or kind == null:
			continue
		if float(animal["dying"]) > 0.0 or bool(animal.get("treed", false)):
			continue
		if kind.is_hostile():
			continue
		var state: int = int(animal["state"])
		if state == State.FLEEING or state == State.LEAVING:
			continue
		if sprite.global_position.distance_to(at) > radius:
			continue
		animal["state"] = State.FLEEING
		animal["drinking"] = false
		animal["goal"] = _bolt_target(sprite.global_position, at if radius < INF else Vector2.INF)


## Hurts every animal within `radius` of a point, not only the nearest. The
## earth's own blows - a quake, a funnel, a meteor - reach all of them, and
## none of those is the player's doing, so `by_player` is false and nothing
## pays out or counts against the earth.
func wound_within(at: Vector2, radius: float, damage: float, by_player: bool = false) -> int:
	if Coop.is_guest() or damage <= 0.0:
		return 0
	var hit: int = 0
	for index: int in _living.size():
		var animal: Dictionary = _living[index]
		if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
			continue
		var sprite := animal["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		if sprite.global_position.distance_to(at) > radius:
			continue
		_wound(index, animal, damage, by_player)
		hit += 1
	return hit


## Caught by a fire: burning for a while, hurt by it every frame, and running.
func burn_near(at: Vector2, radius: float, damage_now: float) -> void:
	if Coop.is_guest():
		return
	for index: int in _living.size():
		var animal: Dictionary = _living[index]
		if float(animal.get("dying", 0.0)) > 0.0:
			continue
		var sprite := animal["sprite"] as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		if sprite.global_position.distance_to(at) > radius:
			continue
		if float(animal.get("burning", 0.0)) <= 0.0:
			Vfx.spark(sprite.global_position, Balance.FLAME_MID, 5, Vector2.UP, 120.0)
		animal["burning"] = Balance.WILDFIRE_BURNING_SECONDS
		if damage_now > 0.0:
			_wound(index, animal, damage_now, false)


## The ground floods (owner brief, 2026-09-14): the flyers leave, the climbers
## get up a tree and wait, and what is too small to do either drowns where it
## stands and leaves what it would have. Decided once as the water reaches
## the height, and forgotten once it has fallen, so a flood that comes and
## goes is two events and not a per-frame cull.
func _on_flood(level: float) -> void:
	if level < Balance.FLOOD_CLIMB_DOWN:
		_flood_struck = false
		return
	if level < Balance.FLOOD_DROWN_LEVEL or _flood_struck:
		return
	_flood_struck = true
	var trunks: PackedVector2Array = PackedVector2Array()
	if field != null and field.has_method("tree_positions"):
		# Only trunks inside the field. The treeline stands beyond the grid,
		# where an animal is forgotten for having wandered off the world - so
		# a climber sent to the nearest of those was quietly deleted on its
		# way up. The gathering trees are inside and are what it climbs.
		var inside: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE
		for trunk: Vector2 in field.call("tree_positions") as PackedVector2Array:
			if absf(trunk.x) <= inside and absf(trunk.y) <= inside:
				trunks.append(trunk)
	for animal: Dictionary in _living:
		var sprite := animal["sprite"] as Sprite2D
		var kind := animal["data"] as WildlifeData
		if sprite == null or not is_instance_valid(sprite) or kind == null:
			continue
		if float(animal["dying"]) > 0.0 or bool(animal.get("treed", false)):
			continue
		if kind.flies:
			animal["state"] = State.LEAVING
			animal["goal"] = _bolt_target(sprite.global_position)
		elif kind.climbs and not trunks.is_empty():
			var nearest: Vector2 = trunks[0]
			for trunk: Vector2 in trunks:
				if trunk.distance_to(sprite.global_position) < nearest.distance_to(sprite.global_position):
					nearest = trunk
			animal["state"] = State.FLEEING
			animal["goal"] = nearest
			animal["climbing"] = true
			animal["drinking"] = false
		elif kind.scale < Balance.FLOOD_DROWN_SCALE:
			_drown(animal, sprite, kind)


## Drowned. The body falls where it stood and leaves its food, because a
## flood that took the small things and left nothing would read as the
## animals simply vanishing.
func _drown(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData) -> void:
	var food: int = _rng.randi_range(kind.food_min, kind.food_max)
	Vfx.dust(sprite.global_position, Color("5a7a92"), 8, 40.0)
	if field != null and field.has_method("spawn_loot") and _is_authority_or_alone():
		field.spawn_loot(RunState.FOOD, food, sprite.global_position)
	if _is_authority_with_company():
		EventBus.coop_wildlife_died.emit(int(animal["net_id"]))
	animal["dying"] = Balance.WILDLIFE_DEATH_SECONDS
	animal["state"] = State.LEAVING


func _is_authority_or_alone() -> bool:
	return not Coop.is_guest()


var _flood_struck: bool = false


## How many legendaries stand alive on the road. A living legendary is an
## anchor: it steadies its region against the earth's wrath, and killing it
## removes that for the run (ChatGPT notes, 2026-09-14, the one idea put
## above the rest).
func living_legendaries() -> int:
	var total: int = 0
	for animal: Dictionary in _living:
		var kind := animal["data"] as WildlifeData
		if kind == null or WildlifeFamilies.rarity_of(animal) != WildlifeData.Rarity.LEGENDARY:
			continue
		if float(animal.get("dying", 0.0)) > 0.0 or bool(animal.get("rifted", false)):
			continue
		total += 1
	return total


## The sack a hoarder carries: the tell that this animal is worth chasing, and
## the thing that flashes when it is about to leave. Drawn from the Gold drop
## art so it reads as the same thing it will become.
func _hang_sack(sprite: Sprite2D, kind: WildlifeData) -> void:
	var path: String = Balance.LOOT_ART_FORMAT % RunState.GOLD
	if not ResourceLoader.exists(path):
		return
	var sack := Sprite2D.new()
	sack.name = "Sack"
	sack.texture = load(path)
	var art: float = maxf(float(sack.texture.get_width()), 1.0)
	var body_scale: float = maxf(kind.scale, 0.01)
	sack.scale = Vector2.ONE * (Balance.WILDLIFE_HOARD_SACK_SIZE / art) / body_scale
	sack.position = Vector2(0.0, -Balance.WILDLIFE_HOARD_SACK_LIFT / body_scale)
	sack.z_index = 1
	sprite.add_child(sack)
	var bob: Tween = sack.create_tween().set_loops()
	bob.tween_property(sack, "position:y", sack.position.y - 5.0, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(sack, "position:y", sack.position.y, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A hoarder's exit: a tear in the air and it is gone, goods and all.
func _rift_out(animal: Dictionary, sprite: Sprite2D) -> void:
	var at: Vector2 = _visual_origin(sprite)
	Vfx.ring(at, 70.0, Color("b48cff"), 0.45, 5.0)
	Vfx.dust(sprite.global_position, Color("7a5cc4"), 12, 80.0)
	# The thief leaving. Its own recording, registered and unplayed until now.
	Sfx.play_group_at("sfx_wildlife_rift_out", at, -1.0)
	animal["rifted"] = true


## What a hoarder was carrying. Gold on top of the food, rolled on the wildlife
## stream; gear on the gear stream, so a seeded run's drops do not move because
## somebody stopped to chase a raccoon. A shiny one always carries gear - the
## rare thing pays like a rare thing - and an elite carries more of both.
func _drop_the_hoard(animal: Dictionary, kind: WildlifeData, at: Vector2) -> void:
	if field == null or not field.has_method("spawn_loot"):
		return
	# What it took comes back first, coin for coin and piece for piece.
	for held: Variant in animal.get("loot", []) as Array:
		var item: Dictionary = held
		var where: Vector2 = at + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 26.0
		var piece: Dictionary = item.get("gear", {})
		if not piece.is_empty() and field.has_method("spawn_gear"):
			field.spawn_gear(piece, where)
		elif int(item.get("amount", 0)) > 0 and not String(item.get("currency", "")).is_empty():
			field.spawn_loot(String(item["currency"]), int(item["amount"]), where)
	# Then the hoard it was born with, if it was born with one. A record with
	# no say on the matter - a stub, or one from before the sack was a chance
	# - is a hoarder that was born with its sack.
	if not bool(animal.get("innate", true)):
		return
	var bounty: float = Balance.WILDLIFE_ELITE_REWARD if bool(animal.get("elite", false)) else 1.0
	var gold: int = int(round(float(_rng.randi_range(kind.hoard_gold_min, kind.hoard_gold_max)) * bounty))
	if gold > 0:
		field.spawn_loot(RunState.GOLD, gold, at)
	var chance: float = kind.hoard_gear_chance * bounty
	if bool(animal.get("shiny", false)):
		chance = 1.0
	if chance <= 0.0 or _rng.randf() > minf(chance, 1.0):
		return
	if not field.has_method("spawn_gear"):
		return
	var tier: CampaignTierData = RunState.tier()
	var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(),
		tier.order if tier != null else 0, RunState.rng("gear"))
	if not piece.is_empty():
		field.spawn_gear(piece, at)


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
func _bolt_target(from: Vector2, threat: Vector2 = Vector2.INF) -> Vector2:
	# Away from what frightened it, a bolt's length, onto ground it may stand
	# on - rather than to the edge of the world, which is where the camps
	# are, so the whole field's rabbits ended up jittering beside a war camp
	# they were fleeing to (owner report, 2026-09-12).
	var away: Vector2
	if threat != Vector2.INF and from.distance_to(threat) > 1.0:
		away = (from - threat).normalized()
	else:
		away = from.normalized() if from.length() > 1.0 else Vector2.RIGHT
	for turn: float in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8]:
		var candidate: Vector2 = from + away.rotated(turn) * Balance.WILDLIFE_BOLT_DISTANCE
		if _is_clear(candidate):
			return candidate
	return away * Balance.WILDLIFE_ENTRY_DISTANCE


## A new spot to potter over to, on ground it is allowed to stand on.
func _wander_from(home: Vector2, kind: WildlifeData, stage_scale: float = 1.0) -> Vector2:
	var roam_scale: float = stage_scale
	match kind.movement_style:
		WildlifeData.MovementStyle.GRAZER:
			roam_scale = 0.48
		WildlifeData.MovementStyle.FORAGER:
			roam_scale = 0.66
		WildlifeData.MovementStyle.SOARER:
			roam_scale = 1.16
		WildlifeData.MovementStyle.SKITTER:
			roam_scale = 0.40
	# **A haunt pulls, it does not tether** (owner, 2026-09-16). A species that
	# keeps to the timber or to the seams mostly heads for one when it decides
	# where to go next; the rest of the time it wanders like anything else, which
	# is what keeps it an animal rather than a spawn point.
	if not kind.haunts.is_empty() and _rng.randf() < kind.haunt_pull:
		var drawn: Vector2 = _haunt_near(home, kind.haunts)
		if drawn != Vector2.INF:
			return drawn
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
## How far out of the settled world a point is, from 0 at the square to 1 at
## the edge of the field.
##
## **The one number distance-based danger is made of.** Owner, 2026-09-15: the
## dangerous and the rare should be likelier the further a player ventures, and
## the harmless should prefer the ground nearer the square. A fraction rather
## than a threshold, because a hard line is a thing players learn to stand
## exactly inside.
func _wildness_at(at: Vector2) -> float:
	var span: float = maxf(Balance.WILDLIFE_FIELD_SPAN, 1.0)
	var out: float = at.length() / span
	var from: float = Balance.WILDLIFE_WILDS_FROM
	if out <= from:
		return 0.0
	return clampf((out - from) / maxf(1.0 - from, 0.01), 0.0, 1.0)


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
			if cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN \
					or cell == BattleGrid.Cell.CAMP:
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


## How many animals have their heads down, for the gate.
func grazing_count() -> int:
	var count: int = 0
	for animal: Dictionary in _living:
		if int(animal["state"]) == State.GRAZING:
			count += 1
	return count


## Removes everything, without waiting for it to wander off.
func clear() -> void:
	for animal: Dictionary in _living:
		var sprite: Node = animal["sprite"]
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_living.clear()


# --- Wildlife Spirit Companions ----------------------------------------------
#
# Owner decision, 2026-09-01. Meeting an animal is what earns its spirit, so this
# is where the collection is actually fed. `SpiritBond` owns the rules; this owns
# the moments.

## Marks a shiny so it is recognisable across a field at a glance.
##
## **Iridescence rather than a tint, since 2026-09-01.** A colour wash was what
## marked these when the system shipped, and it had two problems that only show
## up in play: a tinted rabbit reads as a rabbit in odd lighting rather than as a
## rarity, and an *elite* shiny had two things fighting for `modulate`, so
## whichever tween ran last won and the other tell vanished.
##
## `state_shine` in the actor shaders draws it as a travelling band and a
## scattering of glints on the sprite's own texels, which is a surface catching
## light rather than a filter over the animal - and it leaves `modulate` free, so
## an elite shiny is now visibly both.
##
## The tint survives as the fallback for a build with no material, unchanged. Its
## reasoning still holds there: nothing is drawn *around* a 64px animal, because
## at that size anything around it covers it up.
## What rarity an animal wears, and how brightly.
##
## One table for the ordinary case and one for a shiny, indexed by the same
## rarity - so the two can never disagree about which is louder, and a Common
## shiny still outshines a Legendary that is not.
static func _wear_rarity(sprite: Sprite2D, rarity: int, shiny: bool) -> void:
	if sprite == null:
		return
	var table: Array[float] = Balance.RANK_SHEEN_SHINY if shiny \
		else Balance.RANK_SHEEN_RARE
	var at: int = clampi(rarity, 0, table.size() - 1)
	RankSheen.dress(sprite, table[at], Balance.rank_colour(rarity), shiny)


func _dress_as_shiny(sprite: Sprite2D, kind: WildlifeData,
		material: ShaderMaterial) -> void:
	if ActorState.carried(material):
		ActorState.shine(material, true)
	else:
		sprite.modulate = Color.WHITE.lerp(Balance.SPIRIT_SHINY_COLOUR,
			Balance.SPIRIT_SHINY_TINT_STRENGTH)
		var pulse: Tween = sprite.create_tween().set_loops()
		var half: float = 0.5 / maxf(Balance.SPIRIT_SHINY_PULSE_HZ, 0.1)
		pulse.tween_property(sprite, "modulate",
			Color.WHITE.lerp(Balance.SPIRIT_SHINY_COLOUR,
				Balance.SPIRIT_SHINY_TINT_STRENGTH * 0.35), half)
		pulse.tween_property(sprite, "modulate",
			Color.WHITE.lerp(Balance.SPIRIT_SHINY_COLOUR,
				Balance.SPIRIT_SHINY_TINT_STRENGTH), half)
	# Said out loud the moment it is placed, because a shiny nobody noticed is a
	# shiny that did not happen.
	Vfx.ring(sprite.global_position, 78.0 * kind.scale,
		Color(Balance.SPIRIT_SHINY_COLOUR, 0.7), 0.6, 5.0)
	Vfx.spark(sprite.global_position, Balance.SPIRIT_SHINY_COLOUR, 14,
		Vector2.UP, 150.0)


## Banks one encounter with this animal, at most once per animal.
##
## **The `credited` flag is the anti-farm rule.** Without it a player could bond
## a Legendary by hitting the same deer repeatedly, or by walking in and out of
## a tortoise's bond radius. One animal is one encounter however many times it
## is touched; a second encounter needs a second animal.
func _credit_encounter(animal: Dictionary, _how: SpiritBond.Kind) -> void:
	if bool(animal.get("credited", false)):
		return
	var kind := animal["data"] as WildlifeData
	if kind == null:
		return
	animal["credited"] = true
	var shiny: bool = bool(animal.get("shiny", false))
	var temperament := animal.get("trait", null) as SpiritTraitData
	# **This animal's rarity, never the species'.** A cub born a rung above its
	# parents is that rarity for the collection, the reward and the wire, and
	# writing the upgrade onto the shared `WildlifeData` would have made every
	# animal of that species rarer for the rest of the run (2026-09-14).
	var rarity: int = WildlifeFamilies.rarity_of(animal)
	var result: Dictionary = MetaState.record_spirit_encounter(kind.id, rarity,
		shiny, "" if temperament == null else temperament.id)
	for key: Variant in (result["discovered"] as Array):
		EventBus.spirit_discovered.emit(String(key),
			MetaState.spirit_encounter_count(String(key)),
			SpiritBond.needed(SpiritBond.rarity_of(String(key)),
				SpiritBond.shiny_of(String(key))))
	for key: Variant in (result["bonded"] as Array):
		EventBus.spirit_bonded.emit(String(key))
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite != null and is_instance_valid(sprite) and not (result["bonded"] as Array).is_empty():
		Vfx.ring(sprite.global_position, 96.0, Color(SpiritBond.tint(rarity, shiny), 0.8),
			0.7, 6.0)
		# The bond itself has a recording and had never been played: the ring at
		# the animal's feet was the only thing that ever said it happened.
		Sfx.play_group_at("sfx_wildlife_bond", sprite.global_position, 0.0)


## Offers a bond to a harmless animal the hero has got close to.
##
## **Approach, not slaughter.** The owner's rule: harmless wildlife must not have
## to be killed to be collected. What counts is getting near one before it bolts,
## which is already a real skill check because `skittish_radius` and
## `flee_speed_scale` are authored per species - a tortoise is a formality and a
## snow hare is genuinely difficult. No new stat, no minigame, and the difficulty
## curve came free with the animals.
func _offer_bond(animal: Dictionary) -> void:
	if bool(animal.get("credited", false)):
		return
	var kind := animal["data"] as WildlifeData
	if kind == null or kind.is_hostile():
		return
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var at: Vector2 = sprite.global_position
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Node2D
		if hero == null:
			continue
		if at.distance_to(hero.global_position) <= Balance.SPIRIT_BOND_RADIUS:
			_credit_encounter(animal, SpiritBond.Kind.BONDED)
			return


# --- The second pass (2026-09-12) --------------------------------------------------------

## Faces the animal along `motion`, with hysteresis: only a real sideways
## step turns it, and a turn holds for a moment. Without both, an animal
## steered by separation - a snake beside a heron beside a hedgehog - took
## tiny alternating steps and flipped every frame (owner report).
func _face(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, motion: Vector2,
		delta: float, immediate: bool = false) -> void:
	# Art drawn from above has no left or right to choose between; `_bank`
	# turns it onto its heading instead.
	if kind.art_top_down:
		return
	animal["face_hold"] = maxf(float(animal.get("face_hold", 0.0)) - delta, 0.0)
	var length: float = motion.length()
	if length <= 0.001:
		return
	var sideways: float = absf(motion.x) / length
	if not immediate and (sideways < Balance.WILDLIFE_FACE_DEADZONE
			or float(animal["face_hold"]) > 0.0):
		return
	var wanted: bool = (motion.x > 0.0) != kind.art_faces_right
	if wanted != sprite.flip_h:
		sprite.flip_h = wanted
		animal["face_hold"] = Balance.WILDLIFE_FACE_HOLD


## A flier banks into its heading: nose down when it dives, up when it
## climbs, eased so a turn is a turn rather than a snap. A moth that crossed
## the field bolt upright was the reported symptom.
func _bank(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, delta: float,
		moving: bool) -> void:
	if not kind.flies:
		return
	var heading_now: Vector2 = animal.get("heading", Vector2.RIGHT) as Vector2
	if kind.art_top_down:
		# The art points north, so north is rotated onto the heading. Eased
		# rather than snapped, and held through a hover so a resting moth does
		# not spin to whatever the last stray vector was.
		sprite.flip_h = false
		if moving and not heading_now.is_zero_approx():
			var wanted_turn: float = heading_now.angle() + PI * 0.5
			var turn: float = float(animal.get("bank", wanted_turn))
			turn += wrapf(wanted_turn - turn, -PI, PI) \
				* clampf(Balance.WILDLIFE_TOP_DOWN_TURN * delta, 0.0, 1.0)
			animal["bank"] = turn
			sprite.rotation = turn
		return
	var wanted: float = 0.0
	if moving:
		var heading: Vector2 = heading_now
		var facing_right: bool = sprite.flip_h != kind.art_faces_right
		wanted = clampf(heading.y, -1.0, 1.0) * Balance.WILDLIFE_FLIGHT_BANK \
			* (1.0 if facing_right else -1.0)
	var bank: float = lerpf(float(animal.get("bank", 0.0)), wanted,
		1.0 - exp(-Balance.WILDLIFE_FLIGHT_BANK_RATE * delta))
	animal["bank"] = bank
	sprite.rotation = bank


## A contact shadow under the animal, sized to it; a flier's is paler and
## smaller, because the ground is further away (owner brief, 2026-09-12).
func _cast_shadow(sprite: Sprite2D, kind: WildlifeData, size: float) -> Sprite2D:
	if sprite.texture == null:
		return null
	var width: float = float(sprite.texture.get_width()) * Balance.WILDLIFE_SHADOW_WIDTH
	if kind.flies:
		width *= Balance.WILDLIFE_SHADOW_FLIGHT_SCALE
	var shadow: Sprite2D = ShadowKit.add_contact_sized(sprite, width, 0.0)
	if shadow != null and kind.flies:
		shadow.modulate.a *= Balance.WILDLIFE_SHADOW_FLIGHT_ALPHA
	return shadow


## The sickly light round a rabid animal, so the player knows before the bite.
func _dress_as_rabid(sprite: Sprite2D, kind: WildlifeData) -> void:
	var aura := Sprite2D.new()
	aura.name = "Rabid"
	aura.texture = LightKit.falloff_texture()
	aura.modulate = Balance.WILDLIFE_RABID_AURA
	aura.scale = Vector2.ONE * (Balance.WILDLIFE_RABID_AURA_RADIUS
		/ maxf(float(LightKit.falloff_texture().get_width()), 1.0)) / maxf(kind.scale, 0.01)
	aura.position = Vector2(0.0, -float(sprite.texture.get_height()) * 0.3 if sprite.texture != null else 0.0)
	aura.z_index = -1
	aura.z_as_relative = true
	sprite.add_child(aura)
	var breath: Tween = aura.create_tween().set_loops()
	breath.tween_property(aura, "modulate:a", Balance.WILDLIFE_RABID_AURA.a * 0.35, 0.55)
	breath.tween_property(aura, "modulate:a", Balance.WILDLIFE_RABID_AURA.a, 0.55)
	sprite.modulate = sprite.modulate.lerp(Color(0.75, 1.0, 0.7), 0.35)


## The nearest frightening thing within `radius`, or INF. The fright test
## with the position kept, so a bolt can go away from it.
func _threat_near(at: Vector2, radius: float) -> Vector2:
	return _nearest_threat(at, radius)


# --- Amphibians (2026-09-16) -------------------------------------------------------------

## **The water half of an amphibious animal's life.** True when it has spent the
## frame; false when it is on land and everything else should run.
func _tick_amphibian(animal: Dictionary, sprite: Node2D, kind: WildlifeData,
		delta: float) -> bool:
	var state: int = int(animal["state"])
	var wet: bool = state == State.SUBMERGED or state == State.SURFACED \
		or state == State.EMERGING or state == State.ENTERING
	if not wet:
		# On the bank. Its land clock is the only thing this owns out here: when
		# it runs out the animal goes looking for water again.
		animal["land_left"] = float(animal.get("land_left", 0.0)) - delta
		_hold_the_waterline(animal, sprite, 0.0, delta)
		if float(animal["land_left"]) > 0.0 and animal.has("land_left"):
			return false
		var water: Vector2 = _water_to_enter(sprite.global_position)
		if water == Vector2.INF:
			# No pond in reach: it lives on land like anything else until one
			# is. A region with no water must not strand a species.
			animal["land_left"] = _rng.randf_range(kind.land_seconds.x, kind.land_seconds.y)
			return false
		animal["state"] = State.ENTERING
		animal["goal"] = water
		return false
	match state:
		State.ENTERING:
			return _tick_entering(animal, sprite, kind, delta)
		State.EMERGING:
			return _tick_emerging(animal, sprite, kind, delta)
		State.SURFACED:
			return _tick_surfaced(animal, sprite, kind, delta)
		_:
			return _tick_submerged(animal, sprite, kind, delta)


## Walking into the water: the line rises over it as it goes, so the body sinks
## rather than switching.
func _tick_entering(animal: Dictionary, sprite: Node2D, kind: WildlifeData,
		delta: float) -> bool:
	var goal: Vector2 = animal["goal"]
	var toward: Vector2 = goal - sprite.global_position
	var deep: float = _depth_under(sprite.global_position)
	_hold_the_waterline(animal, sprite,
		Balance.AMPHIBIAN_SUBMERGED_LINE * clampf(deep * 1.6, 0.0, 1.0), delta)
	if toward.length() <= 10.0 or deep >= 0.55:
		animal["state"] = State.SUBMERGED
		animal["water_left"] = _rng.randf_range(kind.water_seconds.x, kind.water_seconds.y)
		_splash(sprite.global_position, 0.8)
		return true
	_swim_step(animal, sprite, kind, toward.normalized(), 1.0, delta)
	return true


## Under the surface: cruising the pond, leaving a wake, and coming up now and
## then. This is where it spends most of its life and where it is hardest to see.
func _tick_submerged(animal: Dictionary, sprite: Node2D, kind: WildlifeData,
		delta: float) -> bool:
	_hold_the_waterline(animal, sprite, Balance.AMPHIBIAN_SUBMERGED_LINE, delta)
	animal["water_left"] = float(animal.get("water_left", 0.0)) - delta
	# **Closing on something.** A predator that marked prey from the surface
	# finishes the approach under the water, which is the ambush.
	var mark: Vector2 = animal.get("ambush", Vector2.INF) as Vector2
	if mark != Vector2.INF:
		var toward: Vector2 = mark - sprite.global_position
		if toward.length() <= Balance.AMPHIBIAN_LUNGE_RANGE or _depth_under(mark) <= 0.0:
			# Up, and from here it is an ordinary hostile animal.
			animal["ambush"] = Vector2.INF
			animal["state"] = State.SETTLED
			animal["land_left"] = _rng.randf_range(kind.land_seconds.x, kind.land_seconds.y)
			_splash(sprite.global_position, 1.25)
			return false
		_swim_step(animal, sprite, kind, toward.normalized(),
			Balance.AMPHIBIAN_AMBUSH_SPEED, delta)
		return true
	var goal: Vector2 = animal["goal"]
	if sprite.global_position.distance_to(goal) <= 14.0 or _depth_under(goal) <= 0.0:
		if _rng.randf() < Balance.AMPHIBIAN_SURFACES:
			animal["state"] = State.SURFACED
			animal["surface_left"] = _rng.randf_range(
				Balance.AMPHIBIAN_SURFACE_HOLD.x, Balance.AMPHIBIAN_SURFACE_HOLD.y)
			_ripple_the_pond(sprite.global_position, 0.35)
			return true
		animal["goal"] = _somewhere_in_the_pond(sprite.global_position)
	_swim_step(animal, sprite, kind, (goal - sprite.global_position).normalized(), 1.0, delta)
	if float(animal["water_left"]) <= 0.0:
		var bank: Vector2 = _drink_spot(sprite.global_position)
		if bank != Vector2.INF:
			animal["state"] = State.EMERGING
			animal["goal"] = bank
	return true


## Lying at the surface with its eyes out: still, watching, and - if it hunts -
## choosing. The state the whole thing exists for.
func _tick_surfaced(animal: Dictionary, sprite: Node2D, kind: WildlifeData,
		delta: float) -> bool:
	_hold_the_waterline(animal, sprite, Balance.AMPHIBIAN_EYELINE, delta)
	animal["surface_left"] = float(animal.get("surface_left", 0.0)) - delta
	# A pair of eyes on the water still ripples it, which is the only thing
	# that gives one away at distance.
	animal["wake"] = float(animal.get("wake", 0.0)) - delta
	if float(animal["wake"]) <= 0.0:
		animal["wake"] = Balance.AMPHIBIAN_WAKE_SECONDS * 2.0
		_ripple_the_pond(sprite.global_position, 0.18)
	if kind.is_hostile() or bool(animal.get("angered", false)):
		var prey: Vector2 = _nearest_prey(sprite.global_position,
			Balance.AMPHIBIAN_AMBUSH_REACH)
		if prey != Vector2.INF:
			animal["ambush"] = prey
			animal["state"] = State.SUBMERGED
			_ripple_the_pond(sprite.global_position, 0.5)
			return true
	if float(animal["surface_left"]) <= 0.0:
		animal["state"] = State.SUBMERGED
		animal["goal"] = _somewhere_in_the_pond(sprite.global_position)
		_ripple_the_pond(sprite.global_position, 0.3)
	_animate(animal, sprite, delta, false)
	return true


## Hauling out: the line slides off as it climbs the bank, so the body comes out
## of the water rather than appearing beside it.
func _tick_emerging(animal: Dictionary, sprite: Node2D, kind: WildlifeData,
		delta: float) -> bool:
	var goal: Vector2 = animal["goal"]
	var toward: Vector2 = goal - sprite.global_position
	var deep: float = _depth_under(sprite.global_position)
	_hold_the_waterline(animal, sprite,
		Balance.AMPHIBIAN_SUBMERGED_LINE * clampf(deep * 1.6, 0.0, 1.0), delta)
	if toward.length() <= 10.0 or deep <= 0.0:
		animal["state"] = State.SETTLED
		animal["home"] = sprite.global_position
		animal["goal"] = sprite.global_position
		animal["land_left"] = _rng.randf_range(kind.land_seconds.x, kind.land_seconds.y)
		_splash(sprite.global_position, 0.5)
		return false
	_swim_step(animal, sprite, kind, toward.normalized(), 0.7, delta)
	return true


## One step of swimming: faster than it walks, steered like everything else, and
## leaving a wake on the water behind it.
func _swim_step(animal: Dictionary, sprite: Node2D, kind: WildlifeData,
		direction: Vector2, urgency: float, delta: float) -> void:
	var speed: float = kind.speed * kind.swim_speed_scale * urgency \
		* WildlifeFamilies.speed_scale(animal)
	var step: Vector2 = direction * speed * delta
	_walk_step(sprite, step)
	animal["heading"] = direction
	_face(animal, sprite as Sprite2D, kind, step, delta)
	_animate(animal, sprite, delta, true)
	animal["wake"] = float(animal.get("wake", 0.0)) - delta
	if float(animal["wake"]) <= 0.0:
		animal["wake"] = Balance.AMPHIBIAN_WAKE_SECONDS
		_ripple_the_pond(sprite.global_position, 0.22)


## **The waterline, eased.** The one thing that makes four states out of one
## sprite: `submerged.gdshader` grades and bends everything below the line, so
## sliding the line is the animal sinking and rising. The material is made on
## first use rather than at birth, because most of the roster never needs one.
func _hold_the_waterline(animal: Dictionary, sprite: Node2D, want: float,
		delta: float) -> void:
	var held: Variant = animal.get("waterline_material")
	var material: ShaderMaterial = null
	if held != null and is_instance_valid(held as Object):
		material = held as ShaderMaterial
	elif want <= 0.001 and float(animal.get("waterline", 0.0)) <= 0.001:
		return
	else:
		material = ShaderMaterial.new()
		material.shader = load("res://scripts/shaders/submerged.gdshader") as Shader
		material.set_shader_parameter("tint", Balance.POND_SUBMERGE_TINT)
		material.set_shader_parameter("feather", 0.1)
		animal["waterline_material"] = material
	var water: Node = field.call("ponds") if field != null and field.has_method("ponds") else null
	if water != null and water.has_method("water_colour"):
		material.set_shader_parameter("water_colour", water.call("water_colour"))
	var line: float = lerpf(float(animal.get("waterline", 0.0)), want,
		clampf(Balance.AMPHIBIAN_LINE_EASE * delta, 0.0, 1.0))
	animal["waterline"] = line
	material.set_shader_parameter("waterline", line)
	# **Its own material only while it is wet.** On dry land the animal wears the
	# blood-and-impact material every other body wears; swapping that out
	# permanently would take its hit flashes with it.
	var wet_enough: bool = line > 0.004
	if wet_enough and sprite.material != material:
		animal["dry_material"] = sprite.material
		sprite.material = material
	elif not wet_enough and sprite.material == material:
		sprite.material = animal.get("dry_material", null) as Material


## How deep the water is under a point, 0 on dry ground.
func _depth_under(at: Vector2) -> float:
	if field == null or not field.has_method("water_depth_at"):
		return 0.0
	return float(field.call("water_depth_at", at))


## The nearest pond worth walking to, as a point in its water.
func _water_to_enter(from: Vector2) -> Vector2:
	if field == null or not field.has_method("ponds"):
		return Vector2.INF
	var ponds: Node = field.call("ponds") as Node
	if ponds == null or not ponds.has_method("pond_positions"):
		return Vector2.INF
	var best: Vector2 = Vector2.INF
	var nearest: float = Balance.AMPHIBIAN_SEEK_WATER
	for heart: Vector2 in ponds.call("pond_positions") as PackedVector2Array:
		var away: float = from.distance_to(heart)
		if away < nearest:
			nearest = away
			best = heart
	return best


## Somewhere else in the pond it is currently in. Sampled rather than solved -
## a pond is any shape at all, and the depth field is the only thing that knows.
func _somewhere_in_the_pond(from: Vector2) -> Vector2:
	for _try: int in 12:
		var at: Vector2 = from + Vector2.from_angle(_rng.randf() * TAU) \
			* _rng.randf_range(40.0, Balance.AMPHIBIAN_SWIM_ROAM)
		if _depth_under(at) > 0.25:
			return at
	return from


## The nearest thing an ambush predator would take, which is the same list
## everything else in this file hunts - so a companion is refused here exactly
## as `_strike` refuses one.
func _nearest_prey(at: Vector2, reach: float) -> Vector2:
	var best: Vector2 = Vector2.INF
	var nearest: float = reach
	# `Hero.GROUP_ANY` and a real cast, like every other search in this file -
	# a hand-written group name is one typo from an ambush that never happens.
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero == null or not is_instance_valid(hero) or not hero.is_alive():
			continue
		var away: float = at.distance_to(hero.global_position)
		if away < nearest:
			nearest = away
			best = hero.global_position
	return best


## A ring on the water where something moved under it, through the pond's own
## door - this file has no business reaching into a water shader.
func _ripple_the_pond(at: Vector2, strength: float) -> void:
	if field == null or not field.has_method("ponds"):
		return
	var ponds: Node = field.call("ponds") as Node
	if ponds != null and ponds.has_method("stir"):
		ponds.call("stir", at, strength)


func _splash(at: Vector2, strength: float) -> void:
	_ripple_the_pond(at, strength)
	Vfx.ring(at, 34.0 * strength, Color(0.86, 0.94, 1.0, 0.7), 0.5, 2.5)
	Vfx.spark(at, Color(0.74, 0.86, 1.0), int(5.0 + 6.0 * strength), Vector2.UP, 150.0 * strength)
	Sfx.play_at("sfx_fish_escape", at, -6.0)


## Whether a point is on or beside a pond.
func _near_water(at: Vector2) -> bool:
	if field == null or not field.has_method("ponds"):
		return false
	var ponds: Node = field.call("ponds") as Node
	if ponds == null or not ponds.has_method("pond_positions"):
		return false
	for centre: Vector2 in ponds.call("pond_positions") as PackedVector2Array:
		if at.distance_to(centre) <= Balance.WILDLIFE_POND_TRUCE_RADIUS:
			return true
	return false


## A dry spot at the rim of the nearest pond in reach, or INF. Walked out
## from the pond's centre until the water ends, then a step further, so a
## deer drinks from the bank rather than falling in.
func _drink_spot(from: Vector2) -> Vector2:
	if field == null or not field.has_method("ponds") or not field.has_method("water_depth_at"):
		return Vector2.INF
	var ponds: Node = field.call("ponds") as Node
	if ponds == null or not ponds.has_method("pond_positions"):
		return Vector2.INF
	var best: Vector2 = Vector2.INF
	var best_distance: float = Balance.WILDLIFE_DRINK_RANGE
	for centre: Vector2 in ponds.call("pond_positions") as PackedVector2Array:
		var distance: float = from.distance_to(centre)
		if distance < best_distance:
			best_distance = distance
			best = centre
	if best == Vector2.INF:
		return Vector2.INF
	var direction: Vector2 = (from - best).normalized() if from.distance_to(best) > 1.0 else Vector2.RIGHT
	var point: Vector2 = best
	for _step: int in 60:
		var next: Vector2 = point + direction * 12.0
		if float(field.call("water_depth_at", next)) <= 0.0:
			break
		point = next
	var rim: Vector2 = point + direction * 22.0
	return rim if _is_clear(rim) else Vector2.INF


# --- The fog and the map (2026-09-12) ----------------------------------------------------

## The animals for the minimap: where, and what kind of thing each is.
func map_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for animal: Dictionary in _living:
		var sprite: Node2D = animal.get("sprite", null) as Node2D
		if sprite == null or not is_instance_valid(sprite) or bool(animal.get("dying", false)):
			continue
		var kind: WildlifeData = animal["data"] as WildlifeData
		out.append({"at": sprite.global_position,
			"hostile": kind != null and kind.temperament != WildlifeData.Temperament.PASSIVE,
			"rabid": bool(animal.get("rabid", false)) or WildlifeFamilies.is_frenzied(animal),
			"elite": bool(animal.get("elite", false)),
			"hoards": kind != null and kind.hoards})
	return out


## An animal in the fog is not drawn. `null` lifts the fog.
func apply_fog(fog: FogOfWar) -> void:
	for animal: Dictionary in _living:
		var sprite: Node2D = animal.get("sprite", null) as Node2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		sprite.visible = fog == null or fog.sees(sprite.global_position)


## Where the nearest animal actually hunting `who` is, or `Vector2.INF`.
##
## A companion asks this to know whether its owner is being hunted by
## something that is not an enemy of the road (owner brief, 2026-09-13: a
## bear that watched wolves take its owner apart). Stalking and striking are
## the two states that mean it; a rabid animal counts wherever it is looking,
## because a rabid animal is hostile to everything.
func threat_to(who: Node2D, radius: float) -> Vector2:
	if who == null or not is_instance_valid(who):
		return Vector2.INF
	var at: Vector2 = who.global_position
	var best: Vector2 = Vector2.INF
	var best_distance: float = radius
	for animal: Dictionary in _living:
		if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 0.0)) <= 0.0:
			continue
		var sprite := animal.get("sprite", null) as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		var state: int = int(animal.get("state", 0))
		var hunting: bool = state == State.STALKING or state == State.STRIKING \
			or bool(animal.get("rabid", false))
		if not hunting:
			continue
		var distance: float = sprite.global_position.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = sprite.global_position
	return best


# --- The road notices a hunter (2026-09-13) ----------------------------------------------

## Kills of each species, decaying. See `Balance.HUNT_TALLY_TRIGGER`.
var _hunt_tally: Dictionary = {}
## Seconds before each species may send another savage.
var _hunt_cooldown: Dictionary = {}


## Ages the tallies and the cooldowns. Called from `_process`.
func _tick_hunt(delta: float) -> void:
	for id: Variant in _hunt_tally.keys():
		var left: float = float(_hunt_tally[id]) - Balance.HUNT_DECAY * delta
		if left <= 0.0:
			_hunt_tally.erase(id)
		else:
			_hunt_tally[id] = left
	for id: Variant in _hunt_cooldown.keys():
		var left: float = float(_hunt_cooldown[id]) - delta
		if left <= 0.0:
			_hunt_cooldown.erase(id)
		else:
			_hunt_cooldown[id] = left


## One more of this species killed by a player. When the tally crosses the
## trigger, the species sends its worst.
func _tally_hunt(kind: WildlifeData) -> void:
	if kind == null or Coop.is_guest():
		return
	if _hunt_cooldown.has(kind.id):
		return
	var tally: float = float(_hunt_tally.get(kind.id, 0.0)) + 1.0
	if tally < Balance.HUNT_TALLY_TRIGGER:
		_hunt_tally[kind.id] = tally
		return
	_hunt_tally.erase(kind.id)
	_hunt_cooldown[kind.id] = Balance.HUNT_COOLDOWN
	_send_a_savage(kind)


## Puts a savage of `kind` on the field, at the edge, already hunting.
##
## It is spawned through the ordinary door so that everything else about an
## animal - the shadow, the bar, the frames, the co-op serial - is true of it
## too; what makes it a savage is the dressing and the numbers afterwards.
func _send_a_savage(kind: WildlifeData) -> void:
	if grid == null:
		return
	var hero: Node2D = _nearest_hero_node()
	if hero == null:
		return
	var from: Vector2 = hero.global_position + Vector2.RIGHT.rotated(
		_rng.randf() * TAU) * Balance.WILDLIFE_BOLT_DISTANCE
	from = from.clamp(Vector2.ONE * -BattleGrid.CORE_HALF_EXTENT,
		Vector2.ONE * BattleGrid.CORE_HALF_EXTENT)
	var before: int = _living.size()
	_spawn(kind, from)
	if _living.size() <= before:
		return
	var animal: Dictionary = _living[_living.size() - 1]
	_make_savage(animal, kind, hero)
	EventBus.preparation_warning.emit(
		"Something large has taken an interest in your hunting.")
	# **The species' own answer to being farmed**, which had its own recording
	# and borrowed a chieftain's roar. A savage is an animal, not a warlord.
	Sfx.play_group("sfx_wildlife_savage_arrival")


## Turns a freshly spawned animal into the thing the road sent.
## **What a savage hits for, and how fast it moves.**
##
## `HUNT_SAVAGE_DAMAGE` and `HUNT_SAVAGE_SPEED` were authored with the rest of
## the savage and read by nothing, so the thing the constants describe as
## "bigger, tougher, harder-hitting and faster" was only the first two of those.
## It arrived five and a half times as tough, half again as large, tinted, lit,
## rabid and worth six times the bounty - and it bit for exactly what an
## ordinary animal of its kind bites for, at exactly its walking speed. A tank
## that cannot hurt you is a chore rather than a consequence, which is the
## opposite of what over-farming is supposed to earn.
##
## Both go through one function each so the multiplier cannot be applied at one
## of the two places a bite is worked out - the spirit at your shoulder is bitten
## by different code from the hero, and half a fix is how the first one of these
## got lost.
func _bite_of(animal: Dictionary, kind: WildlifeData) -> float:
	# What the blight bites for, when the animal it took never had a bite.
	var raw: float = kind.damage
	if WildlifeFamilies.is_frenzied(animal):
		raw = maxf(raw, WildlifeFamilies.blight_bite(animal, kind))
	var bite: float = raw * float(animal["size"]) * Balance.wildlife_bite(RunState.act)
	if bool(animal.get("savage", false)):
		bite *= Balance.HUNT_SAVAGE_DAMAGE
	return bite


func _savage_speed(animal: Dictionary) -> float:
	return Balance.HUNT_SAVAGE_SPEED if bool(animal.get("savage", false)) else 1.0


func _make_savage(animal: Dictionary, kind: WildlifeData, hero: Node2D) -> void:
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	animal["savage"] = true
	animal["elite"] = true
	# Rabid behaviour is what a savage *does* - hunts everything, never breaks
	# off - so it rides that rather than growing a second state machine.
	animal["rabid"] = true
	animal["hp"] = kind.max_hp * Balance.HUNT_SAVAGE_HEALTH
	animal["hunt"] = INF
	animal["state"] = State.STALKING
	animal["goal"] = hero.global_position
	sprite.scale = Vector2.ONE * kind.scale * Balance.HUNT_SAVAGE_SCALE
	sprite.modulate = Balance.HUNT_SAVAGE_TINT
	var aura := Sprite2D.new()
	aura.name = "Savage"
	aura.texture = LightKit.falloff_texture()
	aura.modulate = Balance.HUNT_SAVAGE_AURA
	aura.scale = Vector2.ONE * (Balance.HUNT_SAVAGE_AURA_RADIUS
		/ maxf(float(LightKit.falloff_texture().get_width()), 1.0)) / maxf(kind.scale, 0.01)
	aura.z_index = -1
	aura.z_as_relative = true
	sprite.add_child(aura)
	var breath: Tween = aura.create_tween().set_loops()
	breath.tween_property(aura, "modulate:a", Balance.HUNT_SAVAGE_AURA.a * 0.4, 0.7)
	breath.tween_property(aura, "modulate:a", Balance.HUNT_SAVAGE_AURA.a, 0.7)
	Vfx.ring(sprite.global_position, 150.0, Balance.HUNT_SAVAGE_AURA, 0.9, 4.0)


## The hero a savage is sent after: the nearest one on the field.
func _nearest_hero_node() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Node2D
		if who == null or not is_instance_valid(who):
			continue
		var distance: float = who.global_position.distance_to(global_position)
		if distance < best_distance:
			best_distance = distance
			best = who
	return best


# --- Thieves ---------------------------------------------------------------------------------

## A thief's frame. True when it took the frame - it is lying low or digging -
## and false to let the ordinary walk carry it toward its goal.
##
## Owner brief, 2026-09-14: a loot goblin with an AI. It notices the loot on
## the ground and takes the richest, runs it to cover away from every hero
## and lies low half-seen, breaks cover and bolts when one comes close, and
## when it has nothing it forages the foliage for something. What it carries
## falls when it dies (`_drop_the_hoard`) and goes with it when it rifts. The
## host decides all of it; the guest's puppet is walked by the batch and
## dressed by the sack fact.
func _tick_thief(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, delta: float) -> bool:
	var at: Vector2 = sprite.global_position
	var state: int = int(animal["state"])
	match state:
		State.SCAVENGING:
			var drop := instance_from_id(int(animal.get("target_loot", 0))) as LootDrop
			if drop == null or not is_instance_valid(drop) or drop.steal_worth() <= 0.0:
				animal["state"] = State.SETTLED
				animal["goal"] = at
				return false
			if _frightened(at, kind):
				_give_up(animal, sprite, at)
				return false
			animal["goal"] = drop.global_position
			if at.distance_to(drop.global_position) <= Balance.THIEF_GRAB_REACH:
				var held: Dictionary = drop.steal()
				if not held.is_empty():
					(animal["loot"] as Array).append(held)
					_set_sack(animal, sprite, kind, true)
					Sfx.play_group("sfx_loot_drop", -6.0)
				_run_for_cover(animal, sprite, at, kind)
			return false
		State.HIDING:
			var spot: Vector2 = animal["goal"]
			if at.distance_to(spot) > 8.0:
				if _frightened(at, kind):
					_give_up(animal, sprite, at)
				return false
			if not bool(animal.get("hiding", false)):
				_set_hiding(animal, sprite, true)
				animal["hide_left"] = _rng.randf_range(Balance.THIEF_HIDE_SECONDS.x, Balance.THIEF_HIDE_SECONDS.y)
			animal["hide_left"] = float(animal["hide_left"]) - delta
			var near: Node2D = _nearest_hero_node()
			if near != null and at.distance_to(near.global_position) <= Balance.THIEF_HIDE_BREAK:
				_set_hiding(animal, sprite, false)
				animal["state"] = State.FLEEING
				animal["goal"] = _bolt_target(at, near.global_position)
				return false
			if float(animal["hide_left"]) <= 0.0:
				_set_hiding(animal, sprite, false)
				animal["state"] = State.SETTLED
				animal["home"] = at
				return false
			_animate(animal, sprite, delta, false)
			return true
		State.FORAGING:
			var plant: Vector2 = animal["goal"]
			if at.distance_to(plant) > 10.0:
				if _frightened(at, kind):
					_give_up(animal, sprite, at)
				return false
			animal["forage_left"] = float(animal["forage_left"]) - delta
			animal["forage_dust"] = float(animal.get("forage_dust", 0.0)) - delta
			if float(animal["forage_dust"]) <= 0.0:
				animal["forage_dust"] = 0.6
				Vfx.dust(at + Vector2(0.0, 6.0), Color(0.42, 0.34, 0.24), 3, 22.0)
			if _frightened(at, kind):
				_give_up(animal, sprite, at)
				return false
			if float(animal["forage_left"]) <= 0.0:
				animal["state"] = State.SETTLED
				animal["home"] = at
				if _rng.randf() < Balance.THIEF_FORAGE_FIND:
					var gold: int = int(round(float(_rng.randi_range(kind.hoard_gold_min, kind.hoard_gold_max))
						* Balance.THIEF_FORAGE_GOLD_SCALE))
					if gold > 0:
						(animal["loot"] as Array).append({"currency": RunState.GOLD, "amount": gold, "gear": {}})
						_set_sack(animal, sprite, kind, true)
						Vfx.spark(at, Color(1.0, 0.86, 0.45), 8, Vector2.UP, 160.0)
				return false
			_animate(animal, sprite, delta, false)
			return true
		State.SETTLED:
			animal["look"] = float(animal.get("look", 0.0)) - delta
			if float(animal["look"]) > 0.0:
				return false
			animal["look"] = Balance.THIEF_LOOK_TICK
			var drop: LootDrop = _richest_loot_near(at, Balance.THIEF_NOTICE)
			if drop != null:
				animal["state"] = State.SCAVENGING
				animal["target_loot"] = drop.get_instance_id()
				animal["goal"] = drop.global_position
				return false
			# Nothing to take and nothing carried: dig for something.
			if not bool(animal.get("sack", false)) and float(animal["pause"]) <= 0.0 \
					and _rng.randf() < Balance.THIEF_FORAGE_CHANCE:
				var plant: Vector2 = _plant_near(at, Balance.THIEF_FORAGE_REACH)
				if plant.is_finite():
					animal["state"] = State.FORAGING
					animal["goal"] = plant
					animal["forage_left"] = _rng.randf_range(Balance.THIEF_FORAGE_SECONDS.x, Balance.THIEF_FORAGE_SECONDS.y)
					animal["pause"] = 1.0
					return false
	return false


## Frightened mid-errand: it runs, keeps what it holds, and forgets the rest.
func _give_up(animal: Dictionary, sprite: Sprite2D, at: Vector2) -> void:
	_set_hiding(animal, sprite, false)
	animal["state"] = State.FLEEING
	animal["goal"] = _bolt_target(at, _nearest_threat(at, INF))


## Off to cover with what it took.
func _run_for_cover(animal: Dictionary, sprite: Sprite2D, at: Vector2,
		kind: WildlifeData = null) -> void:
	animal["state"] = State.HIDING
	animal["hiding"] = false
	animal["goal"] = _hiding_spot(at, kind)


## The richest thing lying within reach of its nose, or null.
func _richest_loot_near(at: Vector2, radius: float) -> LootDrop:
	var best: LootDrop = null
	var best_worth: float = 0.0
	var best_away: float = INF
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop == null or not is_instance_valid(drop):
			continue
		var away: float = drop.global_position.distance_to(at)
		if away > radius:
			continue
		var worth: float = drop.steal_worth()
		if worth <= 0.0:
			continue
		if worth > best_worth or (is_equal_approx(worth, best_worth) and away < best_away):
			best = drop
			best_worth = worth
			best_away = away
	return best


## A plant to dig at within reach, on ground it may stand on, or INF.
func _plant_near(at: Vector2, reach: float) -> Vector2:
	if field == null or not field.has_method("foliage_node"):
		return Vector2.INF
	var foliage: Foliage = field.call("foliage_node") as Foliage
	if foliage == null:
		return Vector2.INF
	var plants: Array[Dictionary] = foliage.plants_near(at, reach)
	for _try: int in mini(plants.size(), 6):
		var pick: Dictionary = plants[_rng.randi_range(0, plants.size() - 1)]
		var where: Vector2 = pick["at"]
		if _is_clear(where) and where.distance_to(at) > 24.0:
			return where
	return Vector2.INF


## Cover: the nearest tree standing far enough from every hero, on ground
## it may stand on; failing that, a bolt away from the nearest one.
## **Cover it can actually reach without walking past anybody.**
##
## `THIEF_HIDE_DISTANCE` keeps the tree far from every hero and says nothing
## at all about the *route* to it - so the nearest qualifying tree is often on
## the far side of the hero, the thief takes fright half way there, gives up
## the errand and goes back to shopping. Traced on the real field: it grabbed
## the gear at 1.8s, was frightened at 8.4s with the cover still 900 units off,
## and was scavenging again by 11.1s. It never hid once, which is the whole
## behaviour the brief asked for.
##
## So a trunk is only cover if the straight walk to it stays clear of every
## hero. Preferred rather than required: if nothing is reachable the best
## far-from-everybody tree is still better than standing in the open holding
## the loot.
## **What this animal's throat does to its voice.**
##
## Twenty-three species share one of the twelve recordings, so without this a
## fennec is a fox and a jackal is a wolf. `scale` is the body, and a bigger body
## is a lower voice; `size` is the growth stage, so a cub speaks higher than its
## mother out of the same sample.
##
## Returned as a *shift* rather than applied here, because `Sfx.play_at` already
## multiplies it by the per-play drift the MIX row authors - the scale says what
## kind of animal, the drift says which time it called.
static func voice_pitch(kind: WildlifeData, size: float = 1.0) -> float:
	if kind == null:
		return 0.0
	var body: float = maxf(kind.scale, 0.05) * maxf(size, 0.05)
	var ratio: float = clampf(pow(1.0 / body, Balance.WILDLIFE_VOICE_PITCH_POWER),
		Balance.WILDLIFE_VOICE_PITCH_MIN, Balance.WILDLIFE_VOICE_PITCH_MAX)
	# A young animal is smaller *and* reedier than its size alone implies.
	if size < 0.999:
		ratio *= 1.0 + Balance.WILDLIFE_VOICE_YOUNG_LIFT * (1.0 - clampf(size, 0.0, 1.0))
	return ratio - 1.0


func _hiding_spot(from: Vector2, kind: WildlifeData = null) -> Vector2:
	var heroes: Array = get_tree().get_nodes_in_group(Hero.GROUP_ANY)
	var clearance: float = maxf(kind.skittish_radius if kind != null else 0.0,
		Balance.THIEF_HIDE_BREAK) + Balance.THIEF_ROUTE_CLEARANCE
	var best: Vector2 = Vector2.INF
	var best_away: float = INF
	var open_best: Vector2 = Vector2.INF
	var open_away: float = INF
	if field != null and field.has_method("tree_positions"):
		var inside: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE
		for trunk: Vector2 in field.call("tree_positions") as PackedVector2Array:
			if absf(trunk.x) > inside or absf(trunk.y) > inside:
				continue
			var clear: bool = true
			for node: Node in heroes:
				var hero := node as Node2D
				if hero != null and trunk.distance_to(hero.global_position) < Balance.THIEF_HIDE_DISTANCE:
					clear = false
					break
			if not clear or not _is_clear(trunk):
				continue
			var away: float = trunk.distance_to(from)
			if away < best_away:
				best_away = away
				best = trunk
			if away >= open_away:
				continue
			# The walk, not just the destination.
			var reachable: bool = true
			for node: Node in heroes:
				var hero := node as Node2D
				if hero == null:
					continue
				var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(
					hero.global_position, from, trunk)
				if nearest.distance_to(hero.global_position) < clearance:
					reachable = false
					break
			if reachable:
				open_away = away
				open_best = trunk
	if open_best.is_finite():
		return open_best
	if best.is_finite():
		return best
	var near: Node2D = _nearest_hero_node()
	return _bolt_target(from, near.global_position if near != null else Vector2.INF)


## The sack on or off, and the guest told.
func _set_sack(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, carrying: bool) -> void:
	animal["sack"] = carrying
	var sack: Node = sprite.get_node_or_null("Sack")
	if carrying and sack == null:
		_hang_sack(sprite, kind)
	elif not carrying and sack != null:
		sack.queue_free()
	if _is_authority_with_company():
		EventBus.coop_wildlife_sack.emit(int(animal["net_id"]), carrying, bool(animal.get("hiding", false)))


## Lying low: half seen, and the sack does not glint.
func _set_hiding(animal: Dictionary, sprite: Sprite2D, hiding: bool) -> void:
	if bool(animal.get("hiding", false)) == hiding:
		return
	animal["hiding"] = hiding
	sprite.modulate.a = Balance.THIEF_HIDE_ALPHA if hiding else 1.0
	if _is_authority_with_company():
		EventBus.coop_wildlife_sack.emit(int(animal["net_id"]), bool(animal.get("sack", false)), hiding)


## The host's word on a puppet's sack and cover.
func _on_coop_sack(net_id: int, carrying: bool, hiding: bool) -> void:
	if not Coop.is_guest():
		return
	for animal: Dictionary in _living:
		if int(animal["net_id"]) != net_id:
			continue
		var sprite := animal["sprite"] as Sprite2D
		var kind := animal["data"] as WildlifeData
		if sprite == null or not is_instance_valid(sprite) or kind == null:
			return
		animal["sack"] = carrying
		var sack: Node = sprite.get_node_or_null("Sack")
		if carrying and sack == null:
			_hang_sack(sprite, kind)
		elif not carrying and sack != null:
			sack.queue_free()
		animal["hiding"] = hiding
		sprite.modulate.a = Balance.THIEF_HIDE_ALPHA if hiding else 1.0
		return


## For the gate: what an animal holds.
func carried_loot(index: int) -> Array:
	if index < 0 or index >= _living.size():
		return []
	return _living[index].get("loot", []) as Array
