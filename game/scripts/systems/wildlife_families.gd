class_name WildlifeFamilies
extends RefCounted

## Families, births and the Wildblight (owner brief, 2026-09-14, stage three).
##
## Every animal has a sex, decided once; two adults of one breeding group who
## are healthy, idle and near each other court in stages - seeking,
## approaching, assessing, mating, the outcome, a cooldown - and any fright,
## fight, flood, parting or death interrupts it. A birth is a wild animal:
## rarity and shininess inherited from the parents by the tables below, a
## stage of growth that sizes, toughens, feeds and frees it over its first
## minute, parents who wait for it and guide, defend or hunt for it by their
## temperament. Births are budgeted an act and count toward the population,
## so waiting beside a field of deer is never a farm.
##
## The Wildblight is the frenzy: any animal may sicken - a warning, then a
## frenzy that attacks everything living, then a collapse - once an act at
## most, bounded in number, and a bite may pass it on once. A blighted kill
## pays no wrath and no hunt tally: a mercy, not a hunt.
##
## Lives beside `Wildlife` rather than inside it - that script is already the
## largest in the project - and reads the animal records it is handed. The
## host decides everything here; a guest's puppets are dressed by facts.

enum Sex { FEMALE, MALE }
enum Stage { BABY, ADOLESCENT, ADULT }
enum Court { NONE, SEEKING, APPROACHING, ASSESSING, MATING, OUTCOME, COOLDOWN }
enum Blight { HEALTHY, WARNING, FRENZIED, COLLAPSING }

## What a family fact says (`coop_wildlife_family`): which of these changed.
enum Word { COURTING, BLIGHT, STAGE }

const HEART_ART: String = "res://art/vfx/heart.png"
const BLIGHT_ART: String = "res://art/vfx/blight.png"

var wild: Wildlife = null
## Where a laying species puts its clutch. Null on a field with no nests,
## which makes every species bear its young - the behaviour before this.
var nests: WildlifeNests = null
## Births and outbreaks this act; reset when the act changes.
var births_this_act: int = 0
var outbreaks_this_act: int = 0
var _act_seen: int = -1
## The companion a wild animal may court, when one is out and idle.
var companion: Companion = null

## **The companion's stand-in in the courtship machine.**
##
## Owner, 2026-09-22. The note this replaces said a companion could not court
## *"because the courtship machine pairs two wildlife records and a companion
## is a node"*, and recorded it rather than half-building it. The answer is
## one record: a dictionary shaped exactly like an animal's, refreshed from
## the node every frame, carrying the companion's own sprite so every part of
## the machine that reads a position, shows a heart or measures a distance
## works on it unchanged.
##
## What it is *not* is an animal. It never joins `wild.living()`, so it is in
## no population cap, no predator's search, no wrath ledger and no reward -
## it is only ever offered to the search and ticked.
var _mate_record: Dictionary = {}

## A reserved id no animal can hold: `Wildlife` counts its own up from one.
const COMPANION_ID: int = -7


func _init(wildlife: Wildlife) -> void:
	wild = wildlife


## The frenzy's picture clocks, by animal id - see `_dress_the_frenzy`.
var _frenzy_dress: Dictionary = {}


func _rng() -> RandomNumberGenerator:
	return wild.dice()


# --- What an animal is born with ---------------------------------------------------------

## Fills the record's family fields when an animal is placed. `born` is
## empty for an arrival and carries what the parents gave for a birth; on a
## guest it carries what the host said.
func decorate(animal: Dictionary, kind: WildlifeData, born: Dictionary) -> void:
	var serial: int = int(animal.get("net_id", 0))
	# Derived, never rolled, like the personality: both machines know the
	# species and the serial, so both know the sex without a packet.
	var derived_sex: int = (absi(hash(kind.id)) + serial * 7919) % 2
	animal["sex"] = int(born.get("sex", derived_sex))
	animal["rarity"] = int(born.get("rarity", int(kind.rarity)))
	animal["stage"] = int(born.get("stage", Stage.ADULT))
	animal["age"] = Balance.WILDLIFE_GROWTH_SECONDS if int(animal["stage"]) == Stage.ADULT else 0.0
	animal["born_act"] = int(born.get("born_act", -1))
	animal["parents"] = born.get("parents", [])
	animal["family"] = int(born.get("family", 0))
	animal["court"] = Court.NONE
	animal["partner"] = 0
	animal["court_left"] = 0.0
	animal["court_cooldown"] = 0.0 if int(animal["stage"]) == Stage.ADULT else INF
	animal["familiarity"] = {}
	animal["gestation"] = 0.0
	animal["litter_by"] = 0
	animal["blight"] = Blight.HEALTHY
	animal["blight_left"] = 0.0
	animal["blight_onset"] = -1.0
	animal["exposed"] = {}
	animal["spread"] = false
	animal["generation"] = 0
	animal["young_frames"] = false
	_apply_sex_tint(animal)
	_apply_stage(animal, kind, false)
	# Natural onset: rolled once, when the animal arrives, from the run's own
	# stream. A birth gets a grace before it can sicken.
	if not Coop.is_guest() and kind.blight_eligible and born.is_empty():
		if _rng().randf() < Balance.WILDBLIGHT_ONSET_CHANCE:
			animal["blight_onset"] = _rng().randf_range(Balance.WILDBLIGHT_ONSET_DELAY.x,
				Balance.WILDBLIGHT_ONSET_DELAY.y)


## The subtle sex tint, under everything else that colours a sprite.
func _apply_sex_tint(animal: Dictionary) -> void:
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	sprite.self_modulate = Balance.WILDLIFE_SEX_TINT[clampi(int(animal["sex"]), 0, 1)]


## The rarity of this one animal - the species' unless it was born better.
static func rarity_of(animal: Dictionary) -> int:
	if animal.has("rarity"):
		return int(animal["rarity"])
	var kind := animal.get("data", null) as WildlifeData
	return int(kind.rarity) if kind != null else 0


static func is_adult(animal: Dictionary) -> bool:
	return int(animal.get("stage", Stage.ADULT)) == Stage.ADULT


static func is_frenzied(animal: Dictionary) -> bool:
	var state: int = int(animal.get("blight", Blight.HEALTHY))
	return state == Blight.FRENZIED or state == Blight.COLLAPSING


static func is_sick(animal: Dictionary) -> bool:
	return int(animal.get("blight", Blight.HEALTHY)) != Blight.HEALTHY


static func stage_scale(stage: int) -> float:
	return Balance.WILDLIFE_STAGE_SIZE[clampi(stage, 0, 2)]


## What a stage pays and takes: Food and XP by growth, so a fawn is worth a
## fraction of a hind and a family is never worth more than its adults.
static func yield_scale(animal: Dictionary) -> float:
	return Balance.WILDLIFE_STAGE_YIELD[clampi(int(animal.get("stage", Stage.ADULT)), 0, 2)]


static func speed_scale(animal: Dictionary) -> float:
	var stage: float = Balance.WILDLIFE_STAGE_SPEED[clampi(int(animal.get("stage", Stage.ADULT)), 0, 2)]
	if int(animal.get("blight", Blight.HEALTHY)) == Blight.COLLAPSING:
		return stage * Balance.WILDBLIGHT_COLLAPSE_SPEED
	return stage


static func roam_scale(animal: Dictionary) -> float:
	return Balance.WILDLIFE_STAGE_ROAM[clampi(int(animal.get("stage", Stage.ADULT)), 0, 2)]


## How hard a blighted animal bites: its own bite, or for a species that
## never fought, the authored blight bite, or a small one by its size.
static func blight_bite(animal: Dictionary, kind: WildlifeData) -> float:
	var bite: float = kind.damage
	if kind.blight_damage > 0.0:
		bite = kind.blight_damage
	if bite <= 0.0:
		bite = Balance.WILDBLIGHT_MIN_BITE * maxf(kind.scale, 0.5)
	return bite * float(Balance.WILDLIFE_STAGE_YIELD[clampi(int(animal.get("stage", Stage.ADULT)), 0, 2)])


# --- Growth ---------------------------------------------------------------------------------

func _apply_stage(animal: Dictionary, kind: WildlifeData, announce: bool) -> void:
	var stage: int = int(animal["stage"])
	var elite: float = Balance.WILDLIFE_ELITE_SCALE if bool(animal.get("elite", false)) else 1.0
	var before: float = float(animal.get("size", elite))
	animal["size"] = elite * stage_scale(stage)
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite != null and is_instance_valid(sprite):
		sprite.scale = Vector2.ONE * kind.scale * float(animal["size"])
		# A fawn scuffs less earth than a stag, and this is the one place a body
		# here changes size.
		Footfalls.register_animal(sprite, kind, float(animal["size"]))
		_swap_young_frames(animal, kind)
	# A pool that grows with the body, keeping the share it had.
	var full_before: float = kind.max_hp * (Balance.WILDLIFE_ELITE_HEALTH if bool(animal.get("elite", false)) else 1.0) \
		* Balance.WILDLIFE_STAGE_HEALTH[clampi(_stage_of_size(before, elite), 0, 2)]
	var full_after: float = kind.max_hp * (Balance.WILDLIFE_ELITE_HEALTH if bool(animal.get("elite", false)) else 1.0) \
		* Balance.WILDLIFE_STAGE_HEALTH[stage]
	if animal.has("hp") and full_before > 0.0:
		animal["hp"] = clampf(float(animal["hp"]) / full_before, 0.0, 1.0) * full_after
	elif animal.has("hp"):
		animal["hp"] = full_after
	if stage == Stage.ADULT and is_inf(float(animal.get("court_cooldown", 0.0))):
		# Independent, and free to court - though never in the act it was born.
		animal["court_cooldown"] = Balance.WILDLIFE_COURT_COOLDOWN
	if announce and sprite != null and is_instance_valid(sprite):
		Vfx.dust(sprite.global_position, Color(0.6, 0.55, 0.4), 4, 24.0)
		if wild.is_authority_with_company():
			EventBus.coop_wildlife_family.emit(int(animal["net_id"]), Word.STAGE, stage)


func _stage_of_size(size: float, elite: float) -> int:
	var unit: float = size / maxf(elite, 0.001)
	var best: int = Stage.ADULT
	var best_gap: float = INF
	for stage: int in 3:
		var gap: float = absf(Balance.WILDLIFE_STAGE_SIZE[stage] - unit)
		if gap < best_gap:
			best_gap = gap
			best = stage
	return best


## A species with young art wears it until it is grown.
func _swap_young_frames(animal: Dictionary, kind: WildlifeData) -> void:
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var wants_young: bool = int(animal["stage"]) != Stage.ADULT and not kind.young_id.is_empty()
	if wants_young == bool(animal.get("young_frames", false)):
		return
	var path: String = GameData.derive_path("wildlife", "wildlife_", kind.young_id) if wants_young \
		else kind.get_sprite_path()
	if not ResourceLoader.exists(path):
		return
	animal["young_frames"] = wants_young
	sprite.texture = load(path)
	animal["base"] = sprite.texture
	animal["idle"] = GameData.load_idle_frames(path)
	animal["move"] = GameData.load_move_frames(path)
	animal["graze"] = GameData.load_state_frames(path, "graze")
	animal["fly"] = GameData.load_flight_frames(path)
	animal["attack"] = GameData.load_attack_frames(path)
	animal["ref_h"] = float(sprite.texture.get_height()) if sprite.texture != null else 0.0


func _grow(animal: Dictionary, kind: WildlifeData, delta: float) -> void:
	if int(animal["stage"]) == Stage.ADULT:
		return
	animal["age"] = float(animal["age"]) + delta
	var age: float = float(animal["age"])
	var wanted: int = Stage.BABY
	if age >= Balance.WILDLIFE_GROWTH_SECONDS:
		wanted = Stage.ADULT
	elif age >= Balance.WILDLIFE_GROWTH_SECONDS * Balance.WILDLIFE_ADOLESCENT_AT:
		wanted = Stage.ADOLESCENT
	if wanted != int(animal["stage"]):
		animal["stage"] = wanted
		_apply_stage(animal, kind, true)


# --- The tick ------------------------------------------------------------------------------

## Once a frame, before the animals. The act's budgets, and the companion.
func tick(_delta: float) -> void:
	if RunState.act != _act_seen:
		_act_seen = RunState.act
		births_this_act = 0
		outbreaks_this_act = 0
	if companion != null and not is_instance_valid(companion):
		companion = null
	_refresh_companion_record()
	_tick_companion_courtship(_delta)


## One animal, one frame. True when this drove the animal and the rest of
## its tick should be skipped (a courting animal is doing nothing else).
func tick_animal(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, delta: float) -> bool:
	if Coop.is_guest():
		return false
	_grow(animal, kind, delta)
	_tick_blight(animal, sprite, kind, delta)
	_tick_familiarity(animal, sprite, delta)
	_tick_family(animal, sprite, kind, delta)
	if is_sick(animal):
		_drop_courtship(animal, Court.NONE)
		return false
	return _tick_courtship(animal, sprite, kind, delta)


# --- Familiarity ---------------------------------------------------------------------------

## Bounded 0..1: rises with success and with offspring, decays while apart.
func _tick_familiarity(animal: Dictionary, sprite: Sprite2D, delta: float) -> void:
	var known: Dictionary = animal.get("familiarity", {})
	if known.is_empty():
		return
	for id: Variant in known.keys():
		var other: Dictionary = _by_id(int(id))
		var apart: bool = true
		if not other.is_empty():
			var mate := other.get("sprite", null) as Sprite2D
			if mate != null and is_instance_valid(mate):
				apart = sprite.global_position.distance_to(mate.global_position) > Balance.WILDLIFE_FAMILIARITY_RADIUS
		if apart:
			var left: float = float(known[id]) - Balance.WILDLIFE_FAMILIARITY_DECAY * delta
			if left <= 0.0:
				known.erase(id)
			else:
				known[id] = left


func familiarity(animal: Dictionary, other_id: int) -> float:
	return float((animal.get("familiarity", {}) as Dictionary).get(other_id, 0.0))


func _bump_familiarity(animal: Dictionary, other_id: int, by: float) -> void:
	var known: Dictionary = animal.get("familiarity", {})
	known[other_id] = clampf(float(known.get(other_id, 0.0)) + by, 0.0, 1.0)
	animal["familiarity"] = known


# --- Courtship ----------------------------------------------------------------------------

func _can_court(animal: Dictionary, kind: WildlifeData) -> bool:
	if not kind.breeds or not is_adult(animal) or is_sick(animal):
		return false
	if float(animal.get("court_cooldown", 0.0)) > 0.0:
		return false
	if int(animal.get("born_act", -1)) == RunState.act:
		return false
	var state: int = int(animal.get("state", 0))
	return state == Wildlife.State.SETTLED or state == Wildlife.State.GRAZING \
		or state == Wildlife.State.COURTING


## Whether two animals may pair: one group, opposite sexes, both able.
static func compatible(a: Dictionary, b: Dictionary) -> bool:
	var ka := a.get("data", null) as WildlifeData
	var kb := b.get("data", null) as WildlifeData
	if ka == null or kb == null:
		return false
	if ka.breeding_group_id() != kb.breeding_group_id():
		return false
	return int(a.get("sex", 0)) != int(b.get("sex", 0))


func _tick_courtship(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, delta: float) -> bool:
	animal["court_cooldown"] = float(animal.get("court_cooldown", 0.0)) - delta \
		if not is_inf(float(animal.get("court_cooldown", 0.0))) else INF
	var court: int = int(animal.get("court", Court.NONE))
	# An interruption ends it wherever it was: a fright, a fight, the water
	# rising, a partner gone or too far.
	if court != Court.NONE and court != Court.OUTCOME and _interrupted(animal, sprite, kind):
		_drop_courtship(animal, Court.NONE, Balance.WILDLIFE_COURT_RETRY)
		return false
	match court:
		Court.NONE:
			if not _can_court(animal, kind):
				return false
			if births_this_act >= Balance.WILDLIFE_BIRTHS_PER_ACT or wild.population() >= wild.population_cap():
				return false
			# Only the one who seeks pays the search; the sought is told.
			if int(animal.get("sex", 0)) != Sex.FEMALE:
				return false
			var partner: Dictionary = _seek_partner(animal, sprite, kind)
			if partner.is_empty():
				return false
			_begin_pair(animal, partner)
			return false
		Court.APPROACHING:
			var mate: Dictionary = _by_id(int(animal["partner"]))
			if mate.is_empty():
				_drop_courtship(animal, Court.NONE, Balance.WILDLIFE_COURT_RETRY)
				return false
			var other := mate.get("sprite", null) as Sprite2D
			if other == null or not is_instance_valid(other):
				_drop_courtship(animal, Court.NONE, Balance.WILDLIFE_COURT_RETRY)
				return false
			var gap: float = sprite.global_position.distance_to(other.global_position)
			if gap <= kind.social_spacing * 0.9:
				animal["court"] = Court.ASSESSING
				animal["court_left"] = Balance.WILDLIFE_COURT_ASSESS_SECONDS
				_show_heart(animal, true)
				return true
			# Walk to meet in the middle; the animate call reads the goal.
			animal["state"] = Wildlife.State.COURTING
			animal["goal"] = other.global_position.lerp(sprite.global_position, 0.45)
			return false
		Court.ASSESSING:
			animal["court_left"] = float(animal["court_left"]) - delta
			animal["goal"] = sprite.global_position
			if float(animal["court_left"]) > 0.0:
				return true
			# The one who sought decides for both; the other mirrors.
			if int(animal.get("sex", 0)) == Sex.FEMALE:
				var mate: Dictionary = _by_id(int(animal["partner"]))
				var accept: float = Balance.WILDLIFE_COURT_ACCEPT \
					+ familiarity(animal, int(animal["partner"])) * Balance.WILDLIFE_COURT_FAMILIAR_BONUS
				if not mate.is_empty() and rarity_of(mate) != rarity_of(animal):
					accept *= Balance.WILDLIFE_COURT_MIXED_RARITY
				if _rng().randf() < accept:
					_set_both(animal, mate, Court.MATING, Balance.WILDLIFE_MATING_SECONDS)
				else:
					_drop_courtship(animal, Court.NONE, Balance.WILDLIFE_COURT_RETRY)
					if not mate.is_empty():
						_drop_courtship(mate, Court.NONE, Balance.WILDLIFE_COURT_RETRY)
			return true
		Court.MATING:
			animal["court_left"] = float(animal["court_left"]) - delta
			animal["goal"] = sprite.global_position
			# **Only the one who sought ends it.** Both of the pair tick, and
			# the field walks its animals *backwards* through its list, so
			# whichever was placed second reached the end of the mating first -
			# and ending it dropped the courtship for both. The female never
			# conceived, on any frame, in any pair. So the male holds here and
			# the female moves the two of them on together.
			if int(animal.get("sex", 0)) != Sex.FEMALE:
				return true
			if float(animal["court_left"]) > 0.0:
				return true
			var father: int = int(animal["partner"])
			var mate: Dictionary = _by_id(father)
			_bump_familiarity(animal, father, Balance.WILDLIFE_FAMILIARITY_PER_SUCCESS)
			if not mate.is_empty():
				_bump_familiarity(mate, int(animal["net_id"]), Balance.WILDLIFE_FAMILIARITY_PER_SUCCESS)
				mate["court"] = Court.COOLDOWN
				mate["court_left"] = 0.0
				mate["partner"] = 0
				if not is_inf(float(mate.get("court_cooldown", 0.0))):
					mate["court_cooldown"] = maxf(float(mate.get("court_cooldown", 0.0)),
						Balance.WILDLIFE_COURT_COOLDOWN)
				_show_heart(mate, false)
			# Carrying. The litter is hers from here, whatever he does next.
			animal["court"] = Court.OUTCOME
			animal["gestation"] = kind.gestation_seconds
			animal["litter_by"] = father
			animal["partner"] = 0
			animal["court_left"] = 0.0
			_show_heart(animal, false)
			return false
		Court.OUTCOME:
			# Carrying. Everything else about her is as it was; the litter
			# arrives on her clock, beside her, and is hers whatever the
			# father is doing by then.
			animal["gestation"] = float(animal["gestation"]) - delta
			if float(animal["gestation"]) <= 0.0:
				_give_birth(animal, sprite, kind)
				_drop_courtship(animal, Court.COOLDOWN, Balance.WILDLIFE_COURT_COOLDOWN)
			return false
		_:
			if court == Court.COOLDOWN and float(animal.get("court_cooldown", 0.0)) <= 0.0:
				animal["court"] = Court.NONE
			return false
	return false


## The nearest able partner of the group, with a familiar one preferred by
## the species' loyalty and a stranger chosen over one by its infidelity.
func _seek_partner(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData) -> Dictionary:
	var best: Dictionary = {}
	var best_gap: float = Balance.WILDLIFE_COURT_RADIUS
	var familiar: Dictionary = {}
	var familiar_gap: float = Balance.WILDLIFE_COURT_RADIUS
	# **The companion is offered to the search, never put in the population.**
	# It is one extra candidate here and nowhere else: not in `living()`, so
	# no predator hunts it, no cap counts it and no wrath is owed for it.
	var pool: Array[Dictionary] = wild.living()
	if animal != _mate_record and companion_is_courtable():
		pool = pool.duplicate()
		pool.append(_mate_record)
	for other: Dictionary in pool:
		if other == animal or not compatible(animal, other):
			continue
		var other_kind := other["data"] as WildlifeData
		if not _can_court(other, other_kind) or int(other.get("court", Court.NONE)) != Court.NONE:
			continue
		var mate := other.get("sprite", null) as Sprite2D
		if mate == null or not is_instance_valid(mate) or float(other.get("dying", 0.0)) > 0.0:
			continue
		var gap: float = sprite.global_position.distance_to(mate.global_position)
		if gap >= Balance.WILDLIFE_COURT_RADIUS:
			continue
		if familiarity(animal, int(other["net_id"])) > 0.0 and gap < familiar_gap:
			familiar = other
			familiar_gap = gap
		if gap < best_gap:
			best = other
			best_gap = gap
	if familiar.is_empty():
		return best
	if best == familiar:
		return best
	# A familiar partner near and a stranger nearer: loyalty keeps her, and
	# infidelity is the chance she goes to the stranger anyway.
	if _rng().randf() < kind.infidelity:
		return best
	if _rng().randf() < kind.loyalty:
		return familiar
	return best


func _begin_pair(animal: Dictionary, partner: Dictionary) -> void:
	animal["partner"] = int(partner["net_id"])
	partner["partner"] = int(animal["net_id"])
	_set_both(animal, partner, Court.APPROACHING, 0.0)
	if wild.is_authority_with_company():
		EventBus.coop_wildlife_family.emit(int(animal["net_id"]), Word.COURTING, int(partner["net_id"]))
		EventBus.coop_wildlife_family.emit(int(partner["net_id"]), Word.COURTING, int(animal["net_id"]))


func _set_both(a: Dictionary, b: Dictionary, court: int, left: float) -> void:
	for animal: Dictionary in [a, b]:
		if animal.is_empty():
			continue
		animal["court"] = court
		animal["court_left"] = left
		if court == Court.MATING:
			_show_heart(animal, true)


func _drop_courtship(animal: Dictionary, to: int, cooldown: float = 0.0) -> void:
	var partner: int = int(animal.get("partner", 0))
	animal["court"] = to
	animal["court_left"] = 0.0
	animal["partner"] = 0
	if cooldown > 0.0 and not is_inf(float(animal.get("court_cooldown", 0.0))):
		animal["court_cooldown"] = maxf(float(animal.get("court_cooldown", 0.0)), cooldown)
	if int(animal.get("state", 0)) == Wildlife.State.COURTING:
		animal["state"] = Wildlife.State.SETTLED
	_show_heart(animal, false)
	if partner != 0:
		var mate: Dictionary = _by_id(partner)
		if not mate.is_empty() and int(mate.get("partner", 0)) == int(animal["net_id"]):
			mate["partner"] = 0
			if int(mate.get("court", Court.NONE)) != Court.OUTCOME:
				mate["court"] = to if to != Court.NONE else Court.NONE
				mate["court_left"] = 0.0
				if cooldown > 0.0 and not is_inf(float(mate.get("court_cooldown", 0.0))):
					mate["court_cooldown"] = maxf(float(mate.get("court_cooldown", 0.0)), cooldown)
				if int(mate.get("state", 0)) == Wildlife.State.COURTING:
					mate["state"] = Wildlife.State.SETTLED
				_show_heart(mate, false)
	if wild.is_authority_with_company():
		EventBus.coop_wildlife_family.emit(int(animal["net_id"]), Word.COURTING, 0)


## What ends a courtship: fear, a fight, deep water, or a partner gone far.
func _interrupted(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData) -> bool:
	var state: int = int(animal.get("state", 0))
	if state == Wildlife.State.FLEEING or state == Wildlife.State.LEAVING \
			or state == Wildlife.State.STALKING or state == Wildlife.State.STRIKING:
		return true
	if float(animal.get("dying", 0.0)) > 0.0 or float(animal.get("hp", 1.0)) <= 0.0:
		return true
	if RunState.flood >= Balance.WILDLIFE_COURT_FLOOD:
		return true
	if wild.frightened_at(sprite.global_position, kind):
		return true
	var mate: Dictionary = _by_id(int(animal.get("partner", 0)))
	if mate.is_empty() or float(mate.get("dying", 0.0)) > 0.0 or is_sick(mate):
		return true
	var other := mate.get("sprite", null) as Sprite2D
	if other == null or not is_instance_valid(other):
		return true
	return sprite.global_position.distance_to(other.global_position) > Balance.WILDLIFE_COURT_BREAK_DISTANCE


func _show_heart(animal: Dictionary, on: bool) -> void:
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var heart: Sprite2D = sprite.get_node_or_null("Heart") as Sprite2D
	if not on:
		if heart != null:
			heart.queue_free()
		return
	if heart != null:
		return
	if not ResourceLoader.exists(HEART_ART):
		return
	heart = Sprite2D.new()
	heart.name = "Heart"
	heart.texture = load(HEART_ART) as Texture2D
	heart.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	heart.add_to_group(Graphics.FILTER_GROUP)
	var kind := animal.get("data", null) as WildlifeData
	var lift: float = float(animal.get("ref_h", 48.0)) * 0.95
	heart.position = Vector2(0.0, -lift)
	heart.scale = Vector2.ONE * (Balance.WILDLIFE_HEART_SCALE / maxf(kind.scale * float(animal.get("size", 1.0)), 0.2))
	heart.z_index = 2
	heart.z_as_relative = true
	sprite.add_child(heart)
	var bob: Tween = heart.create_tween().set_loops()
	bob.tween_property(heart, "position:y", -lift - 6.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(heart, "position:y", -lift, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The picture of courtship on a guest, from the host's word.
func dress_courting(animal: Dictionary, partner_id: int) -> void:
	animal["partner"] = partner_id
	_show_heart(animal, partner_id != 0)


# --- Births -------------------------------------------------------------------------------

## The litter: each birth rolled on its own, inside the act's budget and the
## population's cap, beside the mother, from the two parents' rarities and
## shines. The father is whoever she mated with, present or not.
func _give_birth(mother: Dictionary, sprite: Sprite2D, kind: WildlifeData) -> void:
	var father: Dictionary = _by_id(int(mother.get("litter_by", 0)))
	var father_rarity: int = rarity_of(father) if not father.is_empty() else rarity_of(mother)
	var father_shiny: bool = bool(father.get("shiny", false)) if not father.is_empty() else false
	var litter: int = _rng().randi_range(kind.litter_min, kind.litter_max)
	wild.next_family()
	var family: int = wild.family_id()
	# **Rolled first, placed second**, so a nest can sit between the two. The
	# inheritance, the shine and the act's budget are decided in exactly one
	# place whether the species bears its young or lays them - an egg must
	# never be a second route to a rarer animal.
	var clutch: Array[Dictionary] = _roll_clutch(mother, kind, litter, family,
		father_rarity, father_shiny)
	if clutch.is_empty():
		return
	# **A nest is the birth event**, and its budget is spent when it is laid
	# rather than when it opens: a clutch that had to re-ask for room at the end
	# of a region could quietly hatch into nothing, which is the silent failure
	# this project keeps refusing.
	if kind.lays_eggs and nests != null:
		nests.lay(kind, sprite.global_position, clutch, family)
		_bump_familiarity(mother, int(mother.get("litter_by", 0)), Balance.WILDLIFE_FAMILIARITY_PER_BIRTH)
		if not father.is_empty():
			_bump_familiarity(father, int(mother["net_id"]), Balance.WILDLIFE_FAMILIARITY_PER_BIRTH)
		return
	var born_count: int = _place_clutch(kind, sprite.global_position, clutch)
	if born_count > 0:
		_bump_familiarity(mother, int(mother.get("litter_by", 0)), Balance.WILDLIFE_FAMILIARITY_PER_BIRTH)
		if not father.is_empty():
			_bump_familiarity(father, int(mother["net_id"]), Balance.WILDLIFE_FAMILIARITY_PER_BIRTH)
		RunState.note_kept("births", float(born_count))
		EventBus.wildlife_born.emit(kind.id, born_count, sprite.global_position)



## The clutch a pair would produce: one entry per young, or fewer where the
## act's budget or the population cap runs out.
func _roll_clutch(mother: Dictionary, kind: WildlifeData, litter: int,
		family: int, father_rarity: int, father_shiny: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _cub: int in litter:
		if births_this_act >= Balance.WILDLIFE_BIRTHS_PER_ACT \
				or wild.population() + out.size() >= wild.population_cap():
			break
		var rarity: int = inherit_rarity(rarity_of(mother), father_rarity, _rng())
		var shiny: bool = inherit_shiny(rarity, bool(mother.get("shiny", false)),
			father_shiny, _rng())
		births_this_act += 1
		out.append({
			"sex": _rng().randi_range(0, 1),
			"rarity": rarity,
			"shiny": shiny,
			"stage": Stage.BABY,
			"born_act": RunState.act,
			"parents": [int(mother["net_id"]), int(mother.get("litter_by", 0))],
			"family": family,
		})
	return out


## A rolled clutch becomes animals on the ground.
func _place_clutch(kind: WildlifeData, at: Vector2,
		clutch: Array[Dictionary]) -> int:
	var born_count: int = 0
	var credited_variants: Dictionary = {}
	for born: Dictionary in clutch:
		var where: Vector2 = at + Vector2.RIGHT.rotated(_rng().randf() * TAU) \
			* _rng().randf_range(kind.social_spacing * 0.4, kind.social_spacing * 0.8)
		var cub: Dictionary = wild.spawn_born(kind, where, born)
		if cub.is_empty():
			break
		born_count += 1
		# Collection: one credit per birth event and variant, not one per
		# identical sibling. Observation, never slaughter.
		var variant: String = SpiritBond.key(kind.id, int(born["rarity"]),
			bool(born["shiny"]))
		if credited_variants.has(variant):
			cub["credited"] = true
		else:
			credited_variants[variant] = true
		_announce_birth(cub, kind, int(born["rarity"]), bool(born["shiny"]), where)
	return born_count


## A nest opens. The same door a litter goes through, so nothing downstream
## learns that some of this roster lays eggs.
func hatch(kind: WildlifeData, at: Vector2, clutch: Array[Dictionary],
		_family: int) -> void:
	var born_count: int = _place_clutch(kind, at, clutch)
	if born_count > 0:
		RunState.note_kept("births", float(born_count))
		EventBus.wildlife_born.emit(kind.id, born_count, at)


## A rustle and a quiet call; a rarity above the parents' is a restrained
## ring and a chime; a shiny is the shiny's own announcement.
func _announce_birth(cub: Dictionary, kind: WildlifeData, rarity: int, shiny: bool, at: Vector2) -> void:
	Vfx.dust(at, Color(0.55, 0.5, 0.35), 5, 28.0)
	if not kind.vocal_sfx.is_empty():
		Sfx.play_at(kind.vocal_sfx, at, -9.0,
			Wildlife.voice_pitch(kind, stage_scale(0) * float(cub.get("size", 1.0))))
	if rarity > int(kind.rarity):
		Vfx.ring(at, 60.0, Color(SpiritBond.tint(rarity, false), 0.75), 0.6, 3.0)
		Sfx.play_at("sfx_ui_confirm", at, -6.0)
	if shiny:
		Vfx.spark(at, Balance.SPIRIT_SHINY_COLOUR, 10, Vector2.UP, 120.0)


## The offspring's rarity from its parents'. Equal parents climb one step
## rarely; unequal ones give the lower most of the time and one above it
## sometimes, and never climb further.
static func inherit_rarity(a: int, b: int, rng: RandomNumberGenerator) -> int:
	var low: int = mini(a, b)
	var high: int = maxi(a, b)
	if low == high:
		var climb: float = Balance.WILDLIFE_RARITY_CLIMB[clampi(low, 0, 3)]
		if low < WildlifeData.Rarity.LEGENDARY and rng.randf() < climb:
			return low + 1
		return low
	if rng.randf() < Balance.WILDLIFE_MIXED_CLIMB:
		return mini(low + 1, WildlifeData.Rarity.LEGENDARY)
	return low


## Whether a birth shines: the base chance for its rarity, lifted by the
## parents that shone, capped. Never the account's pity - that belongs to
## the road's own sightings.
static func inherit_shiny(rarity: int, mother_shiny: bool, father_shiny: bool,
		rng: RandomNumberGenerator) -> bool:
	return rng.randf() < shiny_birth_chance(rarity, mother_shiny, father_shiny)


static func shiny_birth_chance(rarity: int, mother_shiny: bool, father_shiny: bool) -> float:
	var parents: int = (1 if mother_shiny else 0) + (1 if father_shiny else 0)
	var chance: float = Balance.SPIRIT_SHINY_CHANCE[clampi(rarity, 0, 3)] \
		+ Balance.WILDLIFE_SHINY_PARENT_BONUS[parents]
	return minf(chance, Balance.WILDLIFE_SHINY_BIRTH_CAP)


# --- The family ----------------------------------------------------------------------------

## Young follow their parents and stay near; a parent with young waits for
## them and, by its temperament, guides them away from a threat, turns on it,
## or hunts it.
func _tick_family(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, delta: float) -> void:
	if is_frenzied(animal):
		return
	if not is_adult(animal):
		_tick_young(animal, sprite, kind, delta)
		return
	var young: Array[Dictionary] = wild.young_of(int(animal["net_id"]))
	if young.is_empty():
		return
	# Waiting: no leaving while any of them is still a baby.
	var any_baby: bool = false
	for cub: Dictionary in young:
		if int(cub.get("stage", Stage.ADULT)) == Stage.BABY:
			any_baby = true
			break
	if any_baby:
		animal["patience"] = maxf(float(animal.get("patience", 0.0)), Balance.WILDLIFE_PARENT_WAIT)
		if int(animal.get("state", 0)) == Wildlife.State.LEAVING:
			animal["state"] = Wildlife.State.SETTLED
	# Protection, by temperament.
	var threat: Vector2 = wild.threat_near_for(sprite.global_position, kind, Balance.WILDLIFE_FAMILY_RADIUS)
	if threat == Vector2.INF:
		return
	match kind.protection_of():
		WildlifeData.Protection.GUIDE:
			# Passive: the parent bolts and the young go with it, away from
			# the threat rather than each in its own direction.
			if int(animal.get("state", 0)) != Wildlife.State.FLEEING:
				animal["state"] = Wildlife.State.FLEEING
				animal["goal"] = wild.bolt_from(sprite.global_position, threat)
			for cub: Dictionary in young:
				cub["state"] = Wildlife.State.FLEEING
				cub["goal"] = animal["goal"]
		WildlifeData.Protection.DEFEND:
			# Territorial: the parent stands between and fights for a while.
			animal["defending"] = Balance.WILDLIFE_DEFEND_SECONDS
			animal["hunt"] = maxf(float(animal.get("hunt", 0.0)), Balance.WILDLIFE_DEFEND_SECONDS)
		_:
			# A predator hunts what comes near its young, as it hunts anything.
			animal["hunt"] = maxf(float(animal.get("hunt", 0.0)), Balance.WILDLIFE_DEFEND_SECONDS)


func _tick_young(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, _delta: float) -> void:
	var parents: Array = animal.get("parents", [])
	var parent: Dictionary = {}
	for id: Variant in parents:
		parent = _by_id(int(id))
		if not parent.is_empty():
			break
	if parent.is_empty():
		return
	var guardian := parent.get("sprite", null) as Sprite2D
	if guardian == null or not is_instance_valid(guardian):
		return
	var gap: float = sprite.global_position.distance_to(guardian.global_position)
	var state: int = int(animal.get("state", 0))
	# A parent leaving takes its young; a young one strayed comes back.
	if int(parent.get("state", 0)) == Wildlife.State.LEAVING:
		animal["state"] = Wildlife.State.LEAVING
		animal["goal"] = parent["goal"]
		animal["patience"] = 0.0
	elif gap > kind.social_spacing * Balance.WILDLIFE_YOUNG_STRAY and state == Wildlife.State.SETTLED:
		animal["goal"] = guardian.global_position + (sprite.global_position - guardian.global_position).normalized() \
			* kind.social_spacing * 0.6
		animal["home"] = guardian.global_position


# --- The Wildblight ------------------------------------------------------------------------

func _tick_blight(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, delta: float) -> void:
	match int(animal.get("blight", Blight.HEALTHY)):
		Blight.HEALTHY:
			var onset: float = float(animal.get("blight_onset", -1.0))
			if onset < 0.0:
				return
			onset -= delta
			animal["blight_onset"] = onset
			if onset <= 0.0:
				animal["blight_onset"] = -1.0
				_try_sicken(animal, sprite, kind, true)
		Blight.WARNING:
			animal["blight_left"] = float(animal["blight_left"]) - delta
			# Unsettled: a twitch of the goal every so often, the idle broken.
			if _rng().randf() < delta * 2.0:
				animal["goal"] = sprite.global_position + Vector2.RIGHT.rotated(_rng().randf() * TAU) * 18.0
				animal["state"] = Wildlife.State.SETTLED
			if float(animal["blight_left"]) <= 0.0:
				_frenzy(animal, sprite, kind)
		Blight.FRENZIED:
			animal["blight_left"] = float(animal["blight_left"]) - delta
			_dress_the_frenzy(animal, sprite, kind, delta)
			if float(animal["blight_left"]) <= 0.0:
				sprite.self_modulate = Color.WHITE
				_frenzy_dress.erase(int(animal.get("net_id", 0)))
				_collapse(animal, sprite, kind)
		Blight.COLLAPSING:
			animal["blight_left"] = float(animal["blight_left"]) - delta
			var aura: CanvasItem = sprite.get_node_or_null("Rabid") as CanvasItem
			if aura != null:
				aura.modulate.a = Balance.WILDLIFE_RABID_AURA.a * clampf(float(animal["blight_left"]) / Balance.WILDBLIGHT_COLLAPSE_SECONDS, 0.0, 1.0)
			if float(animal["blight_left"]) <= 0.0:
				wild.perish(animal)


## **A frenzy that cannot be mistaken** (owner, 2026-09-22: "Wildlife with rabies
## needs more clarity and aesthetic appeal vfx juice"). The body pulses a sickly
## green on a fast, uneven beat, foam drips from it, and a toxic ring breathes
## outward every so often - so a frenzied deer reads as *wrong* across the field
## before it reads as a deer. Presentation only, on the decoration's own clock:
## nothing reads any of it, and `Graphics.particle_scale` gives the foam away.
func _dress_the_frenzy(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData,
		delta: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	# Kept beside the record, never in it: an animal's record is what the
	# ecology, the wire and the gates reason about, and a picture's clock has
	# no business there.
	var id: int = int(animal.get("net_id", 0))
	var dressing: Dictionary = _frenzy_dress.get(id, {"clock": 0.0, "froth": 0.0, "ring": 0.0})
	var clock: float = float(dressing["clock"]) + delta
	var beat: float = 0.5 + 0.5 * sin(clock * 9.0 + sin(clock * 2.3) * 2.0)
	sprite.self_modulate = Color.WHITE.lerp(Balance.WILDBLIGHT_FRENZY_TINT,
		0.3 + 0.35 * beat)
	var froth: float = float(dressing["froth"]) - delta
	var ring: float = float(dressing["ring"]) - delta
	var body: float = maxf(kind.scale, 0.5) * 40.0
	var at: Vector2 = sprite.global_position + Vector2(
		sin(clock * 17.0) * body * 0.4, -body * 0.35)
	if froth <= 0.0:
		froth = Balance.WILDBLIGHT_FROTH_EVERY
		Vfx.spark(at, Balance.WILDBLIGHT_FROTH, 3, Vector2.DOWN, 55.0)
	if ring <= 0.0:
		ring = Balance.WILDBLIGHT_RING_EVERY
		Vfx.ring(sprite.global_position, body * 1.6, Balance.WILDBLIGHT_FRENZY_TINT,
			0.5, 4.0)
		Vfx.spark(sprite.global_position, Balance.WILDBLIGHT_FRENZY_TINT, 6,
			Vector2.ZERO, 120.0)
	_frenzy_dress[id] = {"clock": clock, "froth": froth, "ring": ring}


## The limits, asked at the moment it would start: one natural outbreak an
## act, only so many sick at once by the tier, none in Preparation or the
## opening, none on a newborn. Returns whether it took.
func _try_sicken(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, natural: bool) -> bool:
	if is_sick(animal) or float(animal.get("dying", 0.0)) > 0.0 or not kind.blight_eligible:
		return false
	if RunState.is_preparation() or RunState.wave_number < Balance.WILDBLIGHT_OPENING_WAVES:
		return false
	if natural and outbreaks_this_act >= Balance.WILDBLIGHT_OUTBREAKS_PER_ACT:
		return false
	if wild.sick_count() >= active_limit():
		return false
	if float(animal.get("age", 0.0)) < Balance.WILDBLIGHT_BIRTH_GRACE and int(animal.get("born_act", -1)) >= 0:
		return false
	if natural:
		outbreaks_this_act += 1
	animal["blight"] = Blight.WARNING
	animal["blight_left"] = _rng().randf_range(Balance.WILDBLIGHT_WARNING_SECONDS.x, Balance.WILDBLIGHT_WARNING_SECONDS.y)
	# **The three states are heard as well as seen.** A symbol over an
	# unsettled idle is the tell, and it is a tell a player has to be looking
	# at; the three recordings for it had been registered and mixed and played
	# by nothing since the blight was built.
	var where: Sprite2D = animal.get("sprite") as Sprite2D
	if where != null and is_instance_valid(where):
		Sfx.play_group_at("sfx_wildlife_blight_warning", where.global_position, -2.0)
	_drop_courtship(animal, Court.NONE)
	_show_blight_icon(animal, true)
	if wild.is_authority_with_company():
		EventBus.coop_wildlife_family.emit(int(animal["net_id"]), Word.BLIGHT, Blight.WARNING)
	return true


## How many may be sick at once: by the campaign tier.
static func active_limit() -> int:
	var tier: CampaignTierData = RunState.tier()
	var order: int = tier.order if tier != null else 0
	return Balance.WILDBLIGHT_ACTIVE_MAX[clampi(order, 0, Balance.WILDBLIGHT_ACTIVE_MAX.size() - 1)]


func _frenzy(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData) -> void:
	animal["blight"] = Blight.FRENZIED
	animal["blight_left"] = _rng().randf_range(Balance.WILDBLIGHT_FRENZY_SECONDS.x, Balance.WILDBLIGHT_FRENZY_SECONDS.y)
	animal["rabid"] = true
	animal["hunt"] = INF
	animal["truce"] = false
	animal["state"] = Wildlife.State.SETTLED
	_show_blight_icon(animal, false)
	wild.dress_frenzied(animal, sprite, kind)
	Vfx.ring(sprite.global_position, 80.0, Color(Balance.WILDLIFE_RABID_AURA, 0.9), 0.5, 4.0)
	Sfx.play_group_at("sfx_wildlife_blight_frenzy", sprite.global_position, 1.0)
	if not kind.vocal_sfx.is_empty():
		Sfx.play_at(kind.vocal_sfx, sprite.global_position, 2.0,
			Wildlife.voice_pitch(kind, float(animal.get("size", 1.0))))
	if wild.is_authority_with_company():
		EventBus.coop_wildlife_family.emit(int(animal["net_id"]), Word.BLIGHT, Blight.FRENZIED)
	EventBus.wildlife_blighted.emit(kind.id, sprite.global_position)


func _collapse(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData) -> void:
	animal["blight"] = Blight.COLLAPSING
	animal["blight_left"] = Balance.WILDBLIGHT_COLLAPSE_SECONDS
	animal["hunt"] = 0.0
	animal["state"] = Wildlife.State.SETTLED
	animal["goal"] = sprite.global_position
	Vfx.dust(sprite.global_position, Color(0.5, 0.7, 0.4), 6, 30.0)
	Sfx.play_group_at("sfx_wildlife_blight_collapse", sprite.global_position, -1.0)
	if wild.is_authority_with_company():
		EventBus.coop_wildlife_family.emit(int(animal["net_id"]), Word.BLIGHT, Blight.COLLAPSING)


## A bite from a frenzied animal that landed on another animal may pass the
## blight on: once per pair, a bounded chance, at most one secondary per
## carrier, and a secondary carries it no further.
func expose(attacker: Dictionary, victim: Dictionary, victim_kind: WildlifeData) -> void:
	if not is_frenzied(attacker) or is_sick(victim):
		return
	if int(attacker.get("generation", 0)) >= 1 or bool(attacker.get("spread", false)):
		return
	var exposed: Dictionary = attacker.get("exposed", {})
	var victim_id: int = int(victim.get("net_id", 0))
	if exposed.has(victim_id):
		return
	exposed[victim_id] = true
	attacker["exposed"] = exposed
	if _rng().randf() >= Balance.WILDBLIGHT_SPREAD_CHANCE:
		return
	var sprite := victim.get("sprite", null) as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	if _try_sicken(victim, sprite, victim_kind, false):
		attacker["spread"] = true
		victim["generation"] = 1


## The warning symbol over a sickening animal's head.
func _show_blight_icon(animal: Dictionary, on: bool) -> void:
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var icon: Sprite2D = sprite.get_node_or_null("Blight") as Sprite2D
	if not on:
		if icon != null:
			icon.queue_free()
		return
	if icon != null or not ResourceLoader.exists(BLIGHT_ART):
		return
	icon = Sprite2D.new()
	icon.name = "Blight"
	icon.texture = load(BLIGHT_ART) as Texture2D
	icon.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	icon.add_to_group(Graphics.FILTER_GROUP)
	var kind := animal.get("data", null) as WildlifeData
	var lift: float = float(animal.get("ref_h", 48.0)) * 0.95
	icon.position = Vector2(0.0, -lift)
	icon.scale = Vector2.ONE * (Balance.WILDLIFE_HEART_SCALE / maxf(kind.scale * float(animal.get("size", 1.0)), 0.2))
	icon.z_index = 2
	icon.z_as_relative = true
	sprite.add_child(icon)
	var pulse: Tween = icon.create_tween().set_loops()
	pulse.tween_property(icon, "modulate:a", 0.35, 0.3)
	pulse.tween_property(icon, "modulate:a", 1.0, 0.3)


## The picture of the blight on a guest, from the host's word.
func dress_blight(animal: Dictionary, sprite: Sprite2D, kind: WildlifeData, state: int) -> void:
	animal["blight"] = state
	match state:
		Blight.WARNING:
			_show_blight_icon(animal, true)
		Blight.FRENZIED:
			_show_blight_icon(animal, false)
			animal["rabid"] = true
			wild.dress_frenzied(animal, sprite, kind)
		Blight.COLLAPSING:
			animal["blight_left"] = Balance.WILDBLIGHT_COLLAPSE_SECONDS
		_:
			pass


# --- The companion at the shoulder ----------------------------------------------------------

## Every animal by id, the companion included.
##
## One door rather than `wild.animal_by_id` at eight call sites: a wild animal
## paired with the companion looks its partner up every frame through
## `_interrupted`, and a lookup that could not answer would drop the pair on
## the frame after it formed.
func _by_id(id: int) -> Dictionary:
	if id == COMPANION_ID:
		return _mate_record
	return wild.animal_by_id(id)


## Brings the stand-in level with the node, once a frame.
##
## **Its `state` is how the machine is told the companion is busy.**
## `_can_court` already refuses anything not SETTLED, GRAZING or COURTING, so
## a companion that is fighting, hurt or away is refused by the rule that
## already exists rather than by a second one written beside it.
func _refresh_companion_record() -> void:
	if Coop.is_guest():
		_mate_record = {}
		return
	var one: Companion = companion
	if one == null or not is_instance_valid(one) or one.spirit_key.is_empty():
		if not _mate_record.is_empty():
			_release_companion()
		_mate_record = {}
		return
	var species: String = SpiritBond.species_of(one.spirit_key)
	var kind: WildlifeData = ContentDB.wildlife_kinds.get(species, null) as WildlifeData
	var sprite: Sprite2D = one.get("_sprite") as Sprite2D
	if kind == null or not kind.breeds or sprite == null or not is_instance_valid(sprite):
		if not _mate_record.is_empty():
			_release_companion()
		_mate_record = {}
		return
	if _mate_record.is_empty() or _mate_record.get("key", "") != one.spirit_key:
		_mate_record = {
			"net_id": COMPANION_ID,
			"key": one.spirit_key,
			"court": Court.NONE,
			"partner": 0,
			"court_cooldown": 0.0,
			"born_act": -1,
			"stage": Stage.ADULT,
			"size": 1.0,
			"ref_h": 48.0,
			"hp": 1.0,
			"dying": 0.0,
			"familiar": {},
		}
	# Refreshed rather than rebuilt, so a courtship in progress survives the
	# frame. Everything here is read off the node and owned by nobody else.
	_mate_record["data"] = kind
	_mate_record["sprite"] = sprite
	_mate_record["rarity"] = SpiritBond.rarity_of(one.spirit_key)
	_mate_record["shiny"] = SpiritBond.shiny_of(one.spirit_key)
	_mate_record["sex"] = companion_sex(one.spirit_key)
	_mate_record["hp"] = 1.0 if one.is_alive() else 0.0
	# SETTLED only while it is genuinely free; anything else reads to
	# `_can_court` as an animal that is busy.
	_mate_record["state"] = Wildlife.State.SETTLED if one.may_court() \
		else Wildlife.State.STALKING
	if int(_mate_record.get("court", Court.NONE)) != Court.NONE:
		_mate_record["state"] = Wildlife.State.COURTING


## The companion's own courtship tick, through the same machine every animal
## uses - so the stages, the interruptions, the appraisal and the birth are
## one implementation rather than two that drift.
func _tick_companion_courtship(delta: float) -> void:
	if _mate_record.is_empty():
		return
	var kind := _mate_record["data"] as WildlifeData
	var sprite := _mate_record["sprite"] as Sprite2D
	_tick_courtship(_mate_record, sprite, kind, delta)
	# **The court state, never the tick's return.** `_tick_courtship` answers
	# "did I drive this animal, skip the rest of its tick" - and it answers
	# *false* while APPROACHING, precisely because a wild animal still has to
	# be walked to its goal by the wildlife tick afterwards. Reading it as
	# "is it courting" let go of the companion on the one stage where it most
	# needs somewhere to walk to.
	_steer_companion()


## Walks the companion to whoever it is courting, and lets it go when it is
## not. A destination and nothing else: the companion's own brain decides
## whether to obey, and a body to fight always out-ranks this.
func _steer_companion() -> void:
	var one: Companion = companion
	if one == null or not is_instance_valid(one):
		return
	var court: int = int(_mate_record.get("court", Court.NONE))
	if court == Court.NONE or court == Court.OUTCOME or court == Court.COOLDOWN:
		one.courting_at = Vector2.INF
		return
	var mate: Dictionary = _by_id(int(_mate_record.get("partner", 0)))
	var other := mate.get("sprite", null) as Sprite2D
	if mate.is_empty() or other == null or not is_instance_valid(other):
		one.courting_at = Vector2.INF
		return
	# **Meet in the middle while approaching, then stand.** The wild half of
	# the pair walks to the midpoint (see `Court.APPROACHING`), so a companion
	# that walked all the way to the animal would arrive as the animal arrived
	# where the companion had been, and the two would trade places for ever.
	# Once they are assessing or mating, standing still is the behaviour.
	if court == Court.APPROACHING:
		one.courting_at = other.global_position.lerp(one.global_position, 0.45)
	else:
		one.courting_at = one.global_position


## Lets the companion go and clears whatever it was paired with, for the
## frame it is dismissed, replaced or goes down.
func _release_companion() -> void:
	var mate: Dictionary = _by_id(int(_mate_record.get("partner", 0)))
	if not mate.is_empty():
		_drop_courtship(mate, Court.NONE, Balance.WILDLIFE_COURT_RETRY)
	if companion != null and is_instance_valid(companion):
		companion.courting_at = Vector2.INF


## Whether the companion is standing here and free to be courted by a wild
## animal of its own kind. Read by `_seek_partner`.
func companion_is_courtable() -> bool:
	if _mate_record.is_empty():
		return false
	if int(_mate_record.get("court", Court.NONE)) != Court.NONE:
		return false
	var kind := _mate_record["data"] as WildlifeData
	return _can_court(_mate_record, kind)


## The sex of the spirit a bond key summons: decided once a run, from the
## run's seed and the key, so dismissing, re-equipping and reconnecting all
## read the same answer and no machine has to be told.
static func companion_sex(bond_key: String) -> int:
	if bond_key.is_empty():
		return Sex.FEMALE
	if not RunState.companion_sex.has(bond_key):
		RunState.companion_sex[bond_key] = (absi(hash(bond_key)) + RunState.run_seed * 31) % 2
	return int(RunState.companion_sex[bond_key])
