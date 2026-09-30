extends Node

## The single source of truth for the current run (GDD §11 rule 1).
##
## No system caches run data locally. Everything here is destroyed on death;
## persistence is MetaState's job and its schema is deliberately tiny (GDD §10).

# --- Journey ---------------------------------------------------------------

enum Phase {
	PREPARATION,
	ROAD_BATTLE,
	BOSS,
	RAID,
	FINAL_ASCENT,
	ENDED,
}

var distance_travelled: float = 0.0

## Omens read so far, in the order they were taken.
##
## Run-scoped and nothing else. Working rule 7 is untouched: an omen is a
## modifier on the current road, exactly as a socketed relic is, and none of it
## survives the run. `Modifiers` resolves both into the same table.
var taken_omens: Array[String] = []

## Omens on offer right now, or empty. Cleared the moment one is read.
var pending_omens: Array[String] = []

## The Road Card hand, in the order the cards were taken.
##
## Run-scoped, like the portents above and for the same reason: a hand that
## survived the run would be an account-level difficulty setting nobody chose,
## and working rule 7 does not sanction one. `Modifiers` resolves cards,
## portents and socketed relics into the same table.
var road_cards: Array[String] = []

## The three on offer at this crossroad, or empty.
var pending_road_cards: Array[String] = []

## **Augments** (2026-09-26, `docs/SKILL_TREE_REWORK_2026-09-26.md` section 8).
##
## Each held card's level, I to V, by id. A card missing from this is at level
## one, which is what a hand assembled by a harness, or a front banked before
## levels existed, reads as.
var road_card_levels: Dictionary = {}

## **The road rank**, the run's own level bar: every kill pays road experience
## and each rank deals a draft. Never the Warden's account level, and it goes
## with the road.
var road_rank: int = 0
var road_xp: float = 0.0

## **This machine's own draft** (`AugmentSeat`), and in co-op its Warden's own
## hand. The `augment_*` fields below read and write it, so every caller that
## read them before reads the same thing; a seat is what lets the host keep one
## more for every guest (2026-09-26, per-Warden hands).
var _mine: AugmentSeat = AugmentSeat.new(1)
## The host's seats for its guests, by slot. Empty alone and on a guest.
var augment_seats: Dictionary = {}
## **Whether the hand is split** into the party's board and each Warden's own
## cards (`AugmentSeat`). Decided when a road begins - co-op or not - and banked
## with a front, so a hand never changes shape halfway down a road.
var hands_split: bool = false

## Drafts earned and not yet opened, oldest first, each `{source, floor}`. A
## draft banks rather than interrupting a fight; the breather opens them.
var augment_queue: Array[Dictionary]:
	get:
		return _mine.queue
	set(value):
		_mine.queue = value

## The draft on the table - the cards dealt and where they came from - or
## empty. Kept here rather than on the screen, so a panel closed by a crossroad
## or a wave loses nothing and the same cards come back.
var augment_offer: Array[String]:
	get:
		return _mine.offer
	set(value):
		_mine.offer = value
var augment_offer_source: String:
	get:
		return _mine.source
	set(value):
		_mine.source = value

## The tools against luck, spent from the road.
var augment_rerolls: int:
	get:
		return _mine.rerolls
	set(value):
		_mine.rerolls = value
var augment_banishes: int:
	get:
		return _mine.banishes
	set(value):
		_mine.banishes = value
## Cards banished from the deck for the rest of the road.
var augment_banished: Array[String]:
	get:
		return _mine.banished
	set(value):
		_mine.banished = value
## Clean waves banked toward the next draft's odds.
var augment_luck: int:
	get:
		return _mine.luck
	set(value):
		_mine.luck = value
## This Warden's own cards in a split hand, as plain data - what a banked front
## carries of them.
var augment_own_hand: Dictionary:
	get:
		return _mine.pack()
	set(value):
		var read: AugmentSeat = AugmentSeat.unpack(value)
		_mine.cards = read.cards
		_mine.levels = read.levels
## The host's seats for its guests, as plain data, for a banked front.
var augment_seat_rows: Array:
	get:
		var rows: Array = []
		for key: Variant in augment_seats:
			rows.append((augment_seats[key] as AugmentSeat).pack())
		return rows
	set(value):
		augment_seats = {}
		for row: Variant in value:
			var seat: AugmentSeat = AugmentSeat.unpack(row)
			augment_seats[seat.slot] = seat
## Waves cleared toward the next Tempering.
var augment_waves_toward_tempering: int = 0
## The acts whose first camp razed has dealt its draft - so a camp that comes
## back, or the eleventh camp of an act, is a fight and never another draft.
var augment_camps_drafted: Array[String] = []
## The wall's hit count when the wave began, so a clean wave can be told.
var _augment_wave_hits: int = 0

## **The damage ledger** (`DamageLedger`): what each source took off the road's
## bodies, and what each augment added to it, by key. Run statistics, banked
## with a front and reset with the road.
var damage_ledger: Dictionary = {}
var beast_speed: float = Balance.BEAST_BASE_SPEED
var act: int = 1
var segment: int = 0
var terrain_id: String = ""

## **True while the Warden is walking the tutorial valley.**
##
## The Walk is the battlefield with an authored layout and a scripted
## director, entered through its own door (`GameDirector.start_walk`) rather
## than through `start_run` - which clears a banked expedition, eats the
## Treasury cache and withdraws the party from the lobby, none of which a
## tutorial may do to a veteran replaying it.
##
## Everything that reads this reads it to be **quiet**: no earth, no camps, no
## arrivals, no scatter, no settled run, no statistics. Nothing reads it to
## behave *differently* in a way a player could exploit, because nothing the
## Walk grants comes out of the run - see `TutorialGrants` for the ledger.
##
## Run-scoped and never saved: a Walk quit halfway grants nothing and is
## offered again from the start.
var walking: bool = false
## **A sandbox road** (2026-09-30): every tower, a full purse, any act, and
## nothing kept - `GameDirector` holds the account's saves for its length and
## reads the account back from disk when it ends. Cleared by `reset`.
var sandbox: bool = false

var phase: Phase = Phase.PREPARATION
var active_road_id: String = ""
var active_road_difficulty_id: String = ""
## Populated only after a Relic Hunt is completed, then consumed by its modal.
var pending_road_relics: Array[String] = []

## Public QA/debrief seed. Every gameplay-random system receives its own named
## stream derived from this value, so adding a spark or audio variation cannot
## silently change tomorrow's formation or crossroad.
var run_seed: int = 1
## Which battlefield layout this road is laid on (`MapModes`).
##
## **The road's, not the machine's.** Classic after every reset; `start_run`
## gives a new road the player's choice (a guest the host's), and a banked
## front comes back on the map it was banked on. The battlefield reads this and
## nothing else, so two machines on one road cannot build two maps.
var map_mode: String = MapModes.CLASSIC
## What the host said the road's layout is, heard beside the seed. A guest's
## `start_run` takes it; nothing else reads it.
var relayed_map_mode: String = MapModes.CLASSIC
## Whether this road's layout was laid varied - Random's proportions rolled from
## the seed. Carried with the mode everywhere the mode goes.
var map_varied: bool = false
var relayed_map_varied: bool = false

## Which lanes' forks are open this act (both camps razed). Run-scoped and
## re-closed every act with the camps; nothing persists. See `Camps`.
var forks_open: Array[bool] = [false, false, false, false]
var road_history: Array[Dictionary] = []
var _rng_streams: Dictionary = {}

const RNG_MIN_SEED: int = 100000000
const RNG_MAX_SEED: int = 999999999
const RNG_STREAM_SALTS: Dictionary = {
	"waves": 104729,
	"roads": 224737,
	"raids": 350377,
	"rewards": 479909,
	"gear": 518363,
	"mender": 571219,
	"bosses": 611953,
	"combat": 746773,
	# Healing orbs and supply crates. Their own stream for the reason the gear
	# roll has one: retuning how often a sip drops must not rewrite what a seeded
	# run's gear or waves do.
	"recovery": 812273,
	# Ponds and what is in them. Its own stream so that digging one more pond in
	# a jungle cannot move a seeded run's waves, and so both machines in co-op
	# derive the identical water without a packet.
	"fishing": 941083,
}

# --- Economy ---------------------------------------------------------------

const WOOD: String = "wood"
const FOOD: String = "food"
const GOLD: String = "gold"
const STONE: String = "stone"
const CURRENCIES: Array[String] = Balance.CURRENCY_IDS

## Four role-specific wallets. `resources` remains a read/write Gold alias for
## old diagnostic tools; production gameplay names the currency it means.
var currencies: Dictionary = {}
var resources: int:
	get:
		return currency(GOLD)
	set(value):
		currencies[GOLD] = maxi(value, 0)
## Fractional enemy drops carried between kills. Large waves stay rewarding
## without turning every one-HP body into a whole resource.
var kill_resource_remainder: float = 0.0
## The fraction of a scarcity-trimmed grant not yet paid, per wallet. Run
## scoped like every other wallet figure; see `_scarcity`.
var _yield_remainder: Dictionary = {}

## Crossroad pairs this run may still redraw. Granted by Sigil rank 2.
var crossroad_rerolls_left: int = 0
var blueprints: Array[String] = []
var market_trades_remaining: int = 0

## Who is currently in town selling, keyed by merchant id:
## `{"stock": Array, "sold": Array, "until_wave": int}`.
##
## Here rather than in `MerchantYard` because of working rule 6 - a system that
## kept its own copy of who was in town would be a second source of truth for
## run state, and co-op has a standing rule against exactly that. `MerchantYard`
## is all static functions over this dictionary and holds nothing itself.
var merchant_visits: Dictionary = {}
var market_service_act: int = 0
var market_service_id: String = ""

# --- Town ------------------------------------------------------------------

var town_hp: float = Balance.TOWN_MAX_HP
var town_max_hp: float = Balance.TOWN_MAX_HP

## Building id -> tier built. Absent or 0 means not built.
var building_tiers: Dictionary = {}

## The one construction in progress, or empty. Keys: id, tier, distance_needed,
## distance_done.
var construction: Dictionary = {}

## Captive ids held, and captive id -> building id for those assigned.
var captives: Array[String] = []
var captive_assignments: Dictionary = {}

# --- Relics ----------------------------------------------------------------

var socketed_relics: Array[String] = []
var held_relics: Array[String] = []
var boss_cores: Array[String] = []

# --- Towers ----------------------------------------------------------------

## Twelve slots: lane * 3 + slot_index. Each entry is {} or
## {"tower_id": String, "level": int}.
## Every tower standing on the battlefield, keyed by the top-left tile of its
## 2x2 footprint (GDD §13). Placement is free, so there is no fixed slot list
## any more and no upper bound - the economy is the limit.
##
## Run-only, like everything else here. Nothing about a battlefield reaches the
## account save.
var towers: Dictionary = {}

## Traps laid on the roads, keyed by tile: {trap_id, triggers_left}.
##
## Beside the towers rather than inside them, because the two obey opposite
## placement rules - a tower may not stand on a lane and a trap is worthless
## anywhere else - and one dictionary holding both would mean every reader had to
## know which kind it had found before it could ask anything useful.
var traps: Dictionary = {}

## Barricades raised across the roads, keyed by tile: {barricade_id, health}.
##
## Health as a *fraction* rather than an absolute, so a guest told about one
## rebuilds it against its own `max_hp` and the two cannot drift if the resource
## is ever retuned mid-version.
var barricades: Dictionary = {}

# --- Hero ------------------------------------------------------------------

## The spell each ability slot casts on this road, derived from the account's
## loadout by `_sync_discipline_spells` and never written anywhere else.
##
## **The Disciplines are the account's, not the run's** (owner rulings R1 and
## R5, 2026-09-26). What is learned, which skill sits in each slot and which
## form the chain takes all live in `MetaState` and are read through the
## functions below; a run keeps no copy of them to drift. This one list stays
## because the combat bar and the caster index it every frame, and it is only
## ever a restatement of the loadout against the slots this road has opened.
var equipped_spells: Array[String] = []
## How many act bosses this run has felled.
##
## **Renamed from `hero_ascension` on 2026-09-17**, because the owner's
## third capped power scale is `MetaState.ascension` and two unrelated
## things called ascension - one run-scoped and one persistent, both
## granting power - is a confusion waiting to be shipped. Run-scoped and
## reset below, so the rename touches no save.
var bosses_felled: int = 0

# --- Levelling ---------------------------------------------------------------
#
# All of it run-scoped. GDD v4 SS974 forbids a hero level persisting, and
# CLAUDE.md SS7 names the save's whole contents - none of this is in it.

## The five attributes, in the order their points are stored.
##
## Resolve was added on 2026-09-13 and is deliberately **last**, so a save
## written before it reads its four numbers into the first four slots and
## arrives with Resolve at zero. Nothing migrates and `SAVE_VERSION` did not
## move. Never reorder this: the array is positional on disk.
enum Attribute { MIGHT, VIGOUR, SWIFTNESS, FOCUS, RESOLVE }

## What each one is called, and what it does, in one place.
##
## Two screens and a tooltip used to keep their own copies of this list, which
## is three chances to add a fifth attribute and only two of them remembering.
const ATTRIBUTE_NAMES: Array[String] = ["Might", "Vigour", "Swiftness", "Focus", "Resolve"]
const ATTRIBUTE_NOTES: Array[String] = [
	"Damage on every swing and every shot.",
	"Maximum health.",
	"Movement and swing speed.",
	"Spell damage, mana, cooldowns and Command.",
	"Blows land softer, wards hold longer, and your spirit stands where you stand.",
]


## And what each one looks like. Beside the names for the reason the names are
## here: a sixth place keeping its own copy of this is a sixth chance to add an
## attribute and remember five times.
##
## Read by the attack effects, which colour a blow by the attribute the weapon
## favours. Nothing reads them as a number.
const ATTRIBUTE_COLOURS: Array[Color] = [
	Color("ff8a5c"), Color("7fd66a"), Color("6fe3d2"), Color("b58cff"), Color("ffd45c"),
]


## The name of an attribute, safely.
static func attribute_name(which: int) -> String:
	return ATTRIBUTE_NAMES[which] if which >= 0 and which < ATTRIBUTE_NAMES.size() else ""


## The colour of an attribute, safely. White for anything unknown, which reads
## as "no opinion" everywhere this is used.
static func attribute_colour(which: int) -> Color:
	if which < 0 or which >= ATTRIBUTE_COLOURS.size():
		return Color.WHITE
	return ATTRIBUTE_COLOURS[which]

## The weather over the battlefield. Rolled per road, held for its duration.
##
## Per road rather than per wave: weather that changed every ninety seconds would
## be noise a player cannot plan around, and the whole point is that it is a
## condition you build *for* during Preparation.
## Keys picked up in the current raid camp.
##
## Not persisted and not carried between camps: a key is a thing you found in
## *this* camp, and banking them would turn the second raid of a run into a free
## chest opening rather than a search.
var raid_keys: int = 0

## Dawn Bell's gift to the towers: how long the haste has left and what it is
## worth, as a multiplier on the interval (below one is faster).
##
## Run-scoped and on `RunState` rather than on each tower, because a tower built
## during the window should be hasted too and a tower sold during it should not
## leave a dangling timer. Read in `Tower.path_interval_scale`, which is the one
## place every firing clock already asks.
## How many standing orders the Quartermaster has filled this run. The price
## of the next one is built from it, so gold always has somewhere to go and the
## somewhere always gets dearer.
var quartermaster_orders: int = 0

var tower_haste_left: float = 0.0
var tower_haste_scale: float = 1.0

var weather_id: String = "clear"

## What the sky is doing right now, written by `Sky` and read by everything
## else. Rain scale is the rain's multiplier on its authored density; the
## intensity is the rain in absolute terms, 0..1; the flood is 0..1 of the
## height that drowns; the charge is the lightning's potential; and the
## temperature is degrees. A guest is told all five twice a second.
var rain_scale: float = 1.0
var rain_intensity: float = 0.0
var flood: float = 0.0
var storm_charge: float = 0.0
var temperature: float = 20.0

## The earth's wrath and what feeds it. Hidden from the player by design; see
## `Balance` under THE EARTH'S WRATH. `ember` is the fire towers' recent
## damage and `gale` is the storm towers' recent running, both decaying.
var wrath: float = 0.0
var ember: float = 0.0
var gale: float = 0.0
var tide: float = 0.0
var tremor: float = 0.0
## The wind over the field this frame, as a vector; the sky writes it.
var wind: Vector2 = Vector2.ZERO
## True while the party is somewhere the sky cannot reach: a raid camp under a
## cliff, a rift, the maze under a dungeon. Set where `DayNight.set_underground`
## is, and for the same reason - the road's weather is the road's.
var wind_sheltered: bool = false


## What the wind does to the speed of something travelling this way.
##
## **One function, so there is one bound.** Walking straight into the wind at
## full strength costs `Balance.WIND_PUSH_MAX` of your speed and walking with it
## gains the same; across the quarter it falls away as the cosine, which is what
## makes a crosswind cost nothing and is the only honest reading of a push.
##
## Symmetric across every mover on the field, capped, and exactly 1.0 when the
## party is sheltered or the air is still. See the note on `WIND_PUSH_MAX` for
## why those four properties are the whole of what keeps this from being a
## difficulty setting nobody chose.
func wind_push(direction: Vector2) -> float:
	if wind_sheltered or wind == Vector2.ZERO:
		return 1.0
	var length: float = direction.length()
	if length <= 0.001:
		return 1.0
	var strength: float = minf(wind.length(), 1.0)
	var with_it: float = wind.normalized().dot(direction / length)
	return clampf(1.0 + with_it * strength * Balance.WIND_PUSH_MAX,
		1.0 - Balance.WIND_PUSH_MAX, 1.0 + Balance.WIND_PUSH_MAX)

## The campaign tier this run is being played on.
var tier_id: String = "normal"

var hero_level: int = 1
var hero_xp: float = 0.0

## Points earned and not yet placed.
var hero_attribute_points: int = 0

## Points placed, one entry per Attribute.
var hero_attributes: Array[int] = [0, 0, 0, 0, 0]

## Carried between scopes so a raid is not a free heal and the walk back from
## the town is not a reset. -1 means "start at full".
var hero_hp: float = -1.0
## The hero's mana, carried across scopes the same way. -1 means full.
var hero_mana: float = -1.0

## Fish eaten out of the stash this run, against `Balance.FISH_MEALS_PER_RUN`.
##
## Run-scoped on purpose, and it is the bound the whole fishing system rests on:
## the pantry persists, the appetite does not. Same shape as
## `market_trades_remaining` and the crossroad rerolls.
var meals_eaten: int = 0
var hero_wounds: int = 0
## Run-only reward from Oath of the Last Scar. Never written to MetaState.
var hero_max_wounds_bonus: int = 0
## Carried consumables, id -> how many. Run state, so it resets like everything
## else here; v4 §698 is explicit that an item is a thing held rather than a
## number in a wallet, and this is the holding.
##
## Replaces `has_resurrection_draught`, a bool that made the Draught the only
## consumable the game could ever have.
var held_items: Dictionary = {}

# --- Run challenges and rare recovery ---------------------------------------

var last_scar_offered: bool = false
var last_scar_pending: bool = false
var last_scar_active: bool = false
var last_scar_resolved: bool = false
var last_scar_failed: bool = false
var last_scar_pursuer_spawned: bool = false
var last_scar_pursuer_defeated: bool = false
var last_scar_min_town_ratio: float = 1.0

## Act number -> count. Dictionaries make a later act-count change harmless.
var mender_sparks_claimed_by_act: Dictionary = {}
var mender_eligible_elites_by_act: Dictionary = {}

# --- Combat state ----------------------------------------------------------

var wave_number: int = 0
var war_horn_uses: int = 0
var horn_active: bool = false
var horn_used_this_battle: bool = false
var raid_charge: float = 0.0
var weakened_until: float = 0.0

## Command is earned only by active hero play and is reset between battles.
var command: float = 0.0
var last_stand_used: bool = false

# --- Statistics ------------------------------------------------------------

var enemies_killed: int = 0
## Authoritative Chronicle measurements on a guest; empty until synchronized.
## Lives with the run and is never persisted or reconstructed from puppet hits.
var chronicle_host_progress: Dictionary = {}
var hero_deaths: int = 0
var raids_completed: int = 0
var chieftains_taken: int = 0
## Active combat time. Preparation and crossroads are tracked separately so
## balance telemetry is not distorted by thoughtful planning.
var run_time_seconds: float = 0.0
var planning_time_seconds: float = 0.0
var resources_earned: int = 0
var resources_spent: int = 0
var currency_earned: Dictionary = {}
var currency_spent: Dictionary = {}
var towers_built: int = 0
var traps_laid: int = 0
var barricades_raised: int = 0
var tower_upgrades: int = 0
var towers_sold: int = 0
var towers_lost: int = 0
var town_damage_taken: float = 0.0
var town_hits_taken: int = 0
var peak_lane_pressure: float = 0.0
var wave_archetype_counts: Dictionary = {}
var command_earned: float = 0.0
var command_orders_used: Dictionary = {}
var wounds_suffered: int = 0
var hearthmends_used: int = 0


func _ready() -> void:
	reset()
	# Shared XP arrives here rather than in a battlefield system, and the two-
	# process live check is what showed why. It was handled in `CoopHeroes`
	# first, which only exists while a battlefield does - so an award landing in
	# a raid, on a crossroad, or in a harness with no field simply vanished. Hero
	# experience is run-level state, and this is where run-level state lives.
	EventBus.coop_xp_awarded.connect(_on_coop_xp_awarded)
	EventBus.town_health_changed.connect(_on_town_health_for_last_scar)
	EventBus.coop_last_scar_resolved.connect(_on_coop_last_scar_resolved)
	# A Mansion raised may open a slot an act early (ruling R6).
	EventBus.construction_completed.connect(_on_construction_completed)
	# **What the road pays in drafts** (augments, 2026-09-26). Kept here beside
	# the hand rather than in a battlefield system, for the reason the shared XP
	# arrives here: a boss, a raid or a rift can end with no field standing.
	EventBus.boss_defeated.connect(_on_boss_for_augments)
	EventBus.camp_cleared.connect(_on_camp_for_augments)
	EventBus.raid_ended.connect(_on_raid_for_augments)
	EventBus.rift_stage_cleared.connect(_on_rift_for_augments)
	EventBus.wildlife_killed.connect(_on_wildlife_for_augments)
	EventBus.wave_started.connect(_on_wave_for_augments)
	EventBus.wave_cleared.connect(_on_wave_cleared_for_augments)
	EventBus.coop_augment_hand.connect(_on_coop_augment_hand)
	EventBus.coop_augment_seat.connect(_on_coop_augment_seat)
	EventBus.coop_arsenal_seat.connect(_on_coop_arsenal_seat)
	EventBus.coop_request_received.connect(_on_coop_augment_request)


## The host earned experience, so this player earns the same amount.
##
## Applied to *this machine's own* hero against its own curve. The award is
## shared; the hero it lands on is not. A guest arriving at level 20 beside a
## level-5 host keeps their level and simply progresses more slowly for the same
## award, exactly as the curve already does in a solo run.
##
## Guest-only. On the host `gain_hero_xp` is what emitted this, and applying it
## again would pay the host twice.
## How much snow is lying on the field, 0..1.
##
## Here rather than only inside the weather system, because it stopped being a
## drawing concern the moment enemies started slipping on it. Working rule 6: the
## run's state lives in one place and nothing caches its own copy.
var snow_cover: float = 0.0


func _on_coop_xp_awarded(amount: float) -> void:
	if Coop.is_guest():
		gain_hero_xp(amount)


func _on_coop_last_scar_resolved(success: bool, reason: String,
		maximum: int) -> void:
	var relay: CoopRelay = Coop.relay()
	if Coop.is_guest() and relay != null and relay.is_replaying():
		mirror_last_scar_resolution(success, reason, maximum)


func _process(delta: float) -> void:
	if not GameDirector.run_active:
		return
	if phase == Phase.PREPARATION:
		planning_time_seconds += delta
	elif phase != Phase.ENDED:
		run_time_seconds += delta


## Rebuilds every gameplay stream. Tests and QA call this with an explicit
## value; normal runs receive a fresh nine-digit code from time, date and pid.
func set_seed(value: int) -> void:
	run_seed = clampi(absi(value), 1, RNG_MAX_SEED)
	_rng_streams.clear()
	# Keep global gameplay calls deterministic while named streams protect major
	# systems from consuming each other's sequence.
	seed(run_seed)


func rng(stream: String) -> RandomNumberGenerator:
	if _rng_streams.has(stream):
		return _rng_streams[stream] as RandomNumberGenerator
	var generator := RandomNumberGenerator.new()
	var salt: int = int(RNG_STREAM_SALTS.get(stream, hash(stream)))
	generator.seed = run_seed * 1000003 + salt
	_rng_streams[stream] = generator
	return generator


func record_road_choice(segment_index: int, road_id: String, difficulty_id: String) -> void:
	road_history.append({
		"segment": segment_index,
		"road": road_id,
		"difficulty": difficulty_id,
	})


func seed_code() -> String:
	return "%09d" % run_seed


## Watchtower tiers and socketed foresight relics feed one bounded information
## ladder. A relic can supply a missing tier but can never reveal beyond tier 3.
func foresight_tier() -> int:
	return clampi(building_tier("watchtower") \
		+ int(round(Modifiers.value(Modifiers.WAVE_FORESIGHT))), 0, 3)


func _fresh_seed() -> int:
	var stamp: Dictionary = Time.get_datetime_dict_from_system(true)
	var value: int = int(Time.get_ticks_usec()) ^ OS.get_process_id() * 7919
	value ^= int(stamp.get("year", 0)) * 366 + int(stamp.get("day", 0)) * 86400
	return RNG_MIN_SEED + posmod(value, RNG_MAX_SEED - RNG_MIN_SEED + 1)


## Wipes everything. Called when a run begins, never mid-run — death wipes the
## run entirely (GDD §10).
func reset(use_treasury_cache: bool = false, requested_seed: int = 0) -> void:
	set_seed(requested_seed if requested_seed != 0 else _fresh_seed())
	distance_travelled = 0.0
	taken_omens.clear()
	pending_omens.clear()
	road_cards.clear()
	pending_road_cards.clear()
	road_card_levels = {}
	road_rank = 0
	road_xp = 0.0
	_mine = AugmentSeat.new(1)
	augment_seats = {}
	hands_split = _session_splits_hands()
	augment_queue = []
	augment_offer = []
	augment_offer_source = ""
	augment_rerolls = Balance.AUGMENT_REROLLS_START
	augment_banishes = Balance.AUGMENT_BANISHES_START
	augment_banished = []
	augment_luck = 0
	augment_waves_toward_tempering = 0
	augment_camps_drafted = []
	_augment_wave_hits = 0
	damage_ledger = {}
	beast_speed = Balance.BEAST_BASE_SPEED
	act = 1
	segment = 0
	forks_open = []
	for _lane: int in Balance.LANE_COUNT:
		forks_open.append(false)
	terrain_id = ""
	walking = false
	sandbox = false
	# Classic unless a door that starts a real road says otherwise: a gate or a
	# harness that resets the run gets the shipped map, whatever the machine's
	# setting is - a check that measured whichever map its developer last chose
	# would be measuring a different game on every desk.
	map_mode = MapModes.CLASSIC
	map_varied = false
	phase = Phase.PREPARATION
	active_road_id = ""
	active_road_difficulty_id = ""
	pending_road_relics.clear()
	road_history.clear()

	# **Ammunition is a run resource and resets with the run** (working rule 7).
	# The *knowledge* of how to make it persists in MetaState; the arrows
	# themselves do not, exactly like Gold. A quiver that carried over would make
	# the first road of every later run trivial for anyone who stockpiled.
	last_blow.clear()
	ammo.clear()
	ranged_id = ""
	ammo_id = ""

	currencies = {
		WOOD: Balance.STARTING_WOOD,
		FOOD: Balance.STARTING_FOOD,
		GOLD: Balance.STARTING_GOLD,
		STONE: Balance.STARTING_STONE,
	}
	# Sigil rank 2: crossroad redraws, granted per run and spent from the
	# crossroad screen. Held here rather than on MetaState because it is run
	# state - the account earns the rank, the run spends the charge.
	crossroad_rerolls_left = MetaState.sigil_crossroad_rerolls()

	# Sigil rank 1: a modest bundle on every currency (v4 §36). Applied before
	# the Treasury cache so the two stack rather than one replacing the other.
	var bundle: int = MetaState.sigil_starting_supply()
	if bundle > 0:
		for id: String in CURRENCIES:
			currencies[id] = currency(id) + bundle

	if use_treasury_cache:
		for id: String in CURRENCIES:
			currencies[id] = currency(id) + int(MetaState.resource_cache.get(id, 0))
		MetaState.resource_cache.clear()
	kill_resource_remainder = 0.0
	blueprints.clear()
	merchant_visits.clear()
	market_trades_remaining = Balance.MARKET_TRADES_PER_PREPARATION
	meals_eaten = 0
	market_service_act = 0
	market_service_id = ""

	town_max_hp = Balance.TOWN_MAX_HP
	town_hp = town_max_hp
	building_tiers.clear()
	construction.clear()
	captives.clear()
	captive_assignments.clear()

	socketed_relics.clear()
	held_relics.clear()
	boss_cores.clear()

	towers.clear()
	traps.clear()
	barricades.clear()

	equipped_spells.clear()
	bosses_felled = 0
	raid_keys = 0
	weather_id = "clear"
	rain_scale = 1.0
	rain_intensity = 0.0
	flood = 0.0
	storm_charge = 0.0
	temperature = 20.0
	wrath = 0.0
	ember = 0.0
	gale = 0.0
	tide = 0.0
	tremor = 0.0
	wind = Vector2.ZERO
	# Restored from the account, not zeroed.
	#
	# This is the owner amendment of 2026-08-20 in one place: the hero is the only
	# thing that survives a run. Towers, relics, currencies and building tiers are
	# all cleared above, exactly as they always were - a player carries who they
	# have become, not the defence they built.
	hero_level = MetaState.hero_level
	hero_xp = MetaState.hero_xp
	hero_attribute_points = MetaState.hero_attribute_points
	hero_attributes = MetaState.hero_attributes.duplicate()
	tier_id = MetaState.last_tier_id
	hero_hp = -1.0
	hero_mana = -1.0
	hero_wounds = 0
	hero_max_wounds_bonus = 0
	held_items.clear()
	last_scar_offered = false
	last_scar_pending = false
	last_scar_active = false
	last_scar_resolved = false
	last_scar_failed = false
	last_scar_pursuer_spawned = false
	last_scar_pursuer_defeated = false
	last_scar_min_town_ratio = 1.0
	mender_sparks_claimed_by_act.clear()
	mender_eligible_elites_by_act.clear()

	wave_number = 0
	war_horn_uses = 0
	horn_active = false
	horn_used_this_battle = false
	raid_charge = 0.0
	weakened_until = 0.0
	command = 0.0
	last_stand_used = false

	enemies_killed = 0
	kept.clear()
	earth_events.clear()
	seeds.clear()
	carried_eggs.clear()
	# A fresh road: whatever happened to the last animal was settled when that
	# run ended, and a flag carried across runs would lose one for a death it
	# already paid for.
	pen_companion_fell = false
	momentum = 0.0
	wayside_answered.clear()
	# A flag left set by a run that was abandoned mid-withdrawal would silence
	# every road wave of the next one. Cleared with the rest of the run.
	withdrawing = false
	tower_health_restore.clear()
	# A doctrine owed to a road that no longer exists is a board built onto
	# the next run. Cleared beside the health it sits next to.
	pending_outfit.clear()
	companion_sex.clear()
	chronicle_host_progress.clear()
	hero_deaths = 0
	raids_completed = 0
	chieftains_taken = 0
	run_time_seconds = 0.0
	planning_time_seconds = 0.0
	resources_earned = 0
	resources_spent = 0
	currency_earned.clear()
	currency_spent.clear()
	for id: String in CURRENCIES:
		currency_earned[id] = 0
		currency_spent[id] = 0
	towers_built = 0
	traps_laid = 0
	barricades_raised = 0
	tower_upgrades = 0
	towers_sold = 0
	towers_lost = 0
	town_damage_taken = 0.0
	tower_haste_left = 0.0
	tower_haste_scale = 1.0
	quartermaster_orders = 0
	town_hits_taken = 0
	peak_lane_pressure = 0.0
	wave_archetype_counts.clear()
	command_earned = 0.0
	command_orders_used.clear()
	wounds_suffered = 0
	hearthmends_used = 0

	_sync_discipline_spells()

	var starting_terrain: TerrainData = ContentDB.terrain_for_act(1)
	if starting_terrain != null:
		terrain_id = starting_terrain.id

	# Buildings flagged available_from_start begin at tier 1, so a new run has a
	# town rather than an empty field.
	for b: BuildingData in ContentDB.buildings_sorted():
		if b.available_from_start:
			building_tiers[b.id] = 1


## Two spells to begin with, drawn from the unlock pool where there is one.
## A first-ever run has an empty pool, and starting with no spells at all would
## make the hero strictly worse than the prototype — so the pool is a preference,
## not a gate.
func _equip_starting_spells() -> void:
	var pool: Array[String] = []
	for id: String in MetaState.unlocked_spells:
		if ContentDB.spells.has(id):
			pool.append(id)
	if pool.is_empty():
		for id: Variant in ContentDB.spells:
			pool.append(String(id))
	pool.sort()
	for i: int in mini(Balance.STARTING_SPELLS, pool.size()):
		equipped_spells.append(pool[i])


## **Skill points the Warden may spend**, counted by the account: what levels
## and first clears have earned less what the tree holds (2026-09-26). Nothing
## is kept, so nothing can leak - the fault the owner's level-100 Warden found,
## holding 16 of the 20 they had earned.
func skill_points() -> int:
	return MetaState.skill_points_free()


## Every node the Warden has learned, the free starters first.
func learned_disciplines() -> Array[String]:
	return MetaState.owned_disciplines()


func has_learned(id: String) -> bool:
	return MetaState.owns_discipline(id)


## The shape the three-hit chain takes: a FORM node, chosen beside the four
## slots rather than in one of them, so every slot can hold a cast.
func chain_form() -> DisciplineNodeData:
	var node: DisciplineNodeData = ContentDB.discipline_node(MetaState.discipline_form)
	if node == null or not node.is_form():
		node = ContentDB.discipline_node(Balance.DISCIPLINE_STARTING_FORM)
	return node


## **Whether a slot is open on this road**, and the one rule for it.
##
## Attack and Defense from the start; Power once the Act I boss has fallen and
## Ultimate once the Act II boss has - and a Mansion built to
## `Balance.DISCIPLINE_EARLY_SLOT_TIER` brings each one act forward (owner
## ruling R6, 2026-09-26: the Mansion's tiers used to reveal deeper rows of a
## per-road tree, and the tree is the account's now).
func slot_is_open(slot: int) -> bool:
	if slot < 0 or slot >= Balance.HERO_MAX_SPELL_SLOTS:
		return false
	if DisciplineNodeData.slot_is_unlocked(slot, act):
		return true
	return act >= DisciplineNodeData.slot_opens_at_act(slot) - 1 and _mansion_opens(slot)


func _mansion_opens(slot: int) -> bool:
	var table: Array[int] = Balance.DISCIPLINE_EARLY_SLOT_TIER
	var needed: int = table[slot] if slot < table.size() else 0
	return needed > 0 and building_tier("sanctum") >= needed


## What a closed slot says about itself, for the Mansion and the combat bar.
func slot_opens_note(slot: int) -> String:
	var table: Array[int] = Balance.DISCIPLINE_EARLY_SLOT_TIER
	var boss: int = DisciplineNodeData.slot_opens_after_boss(slot)
	var line: String = "opens after the Act %s boss" % act_numeral(boss)
	var needed: int = table[slot] if slot < table.size() else 0
	if needed > 0 and boss > 1:
		line += ", or a boss sooner with the Hero Mansion at tier %d" % needed
	return line


## An act as the roman numeral the screens print.
static func act_numeral(act_number: int) -> String:
	const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V",
		"VI", "VII", "VIII", "IX", "X", "XI"]
	return NUMERALS[clampi(act_number - 1, 0, NUMERALS.size() - 1)]


## The skill in a slot this road can cast, or null - empty, or not open yet.
func discipline_node_in_slot(slot: int) -> DisciplineNodeData:
	if not slot_is_open(slot):
		return null
	return loadout_node(slot)


## The skill the account has put in a slot, open or not.
func loadout_node(slot: int) -> DisciplineNodeData:
	if slot < 0 or slot >= MetaState.discipline_loadout.size():
		return null
	var id: String = MetaState.discipline_loadout[slot]
	return ContentDB.discipline_node(id) if not id.is_empty() else null


## Nodes learned in each arm, keyed by `DisciplineNodeData.Discipline`.
func discipline_depth() -> Dictionary:
	return MetaState.discipline_depth()


## **Every node the Warden could learn now**, in the tree's own order - open by
## arm, ring and parent, whether or not a point is free to buy it. The Mansion
## lists these and says what a point would buy; `try_learn_discipline` asks the
## same question with the points included.
func eligible_discipline_nodes() -> Array[DisciplineNodeData]:
	var out: Array[DisciplineNodeData] = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if MetaState.reach_problem(node.id, act).is_empty():
			out.append(node)
	return out


## Whether an arm may be learned in at all - see `Balance.DISCIPLINE_OPENS_AT_ACT`.
func discipline_is_open(discipline: int) -> bool:
	return MetaState.discipline_open(discipline, act)


## The act a closed discipline opens at, for the Mansion's copy.
func discipline_opens_at(discipline: int) -> int:
	var table: Array[int] = Balance.DISCIPLINE_OPENS_AT_ACT
	if discipline < 0 or discipline >= table.size():
		return 1
	return table[discipline]


## Spends a key if one is held. Returns whether it could.
func spend_raid_key() -> bool:
	if raid_keys <= 0:
		return false
	raid_keys -= 1
	return true


## The live weather, or null when the roster is missing.
func weather() -> WeatherData:
	return ContentDB.weather(weather_id)


## How much a weather helps or hurts one element right now.
func weather_scale(element: int) -> float:
	var live: WeatherData = weather()
	return live.scale_for(element) if live != null else 1.0


## Rolls the weather for a new road, weighted, and never the same twice running.
##
## Excluding a repeat matters more than it looks: with five entries and a weighted
## draw, the same weather twice in a row is common enough that players read it as
## the system being broken rather than as chance.
func roll_weather() -> void:
	var options: Array[WeatherData] = ContentDB.weathers_for_act(act)
	if options.is_empty():
		return
	var pool: Array[WeatherData] = []
	for option: WeatherData in options:
		if option.id != weather_id or options.size() == 1:
			pool.append(option)
	var total: float = 0.0
	for option: WeatherData in pool:
		total += _wrathful_weight(option)
	if total <= 0.0:
		return
	var target: float = rng("weather").randf() * total
	for option: WeatherData in pool:
		target -= _wrathful_weight(option)
		if target <= 0.0:
			weather_id = option.id
			MetaState.record_seen("weather", option.id)
			EventBus.weather_changed.emit(option.id)
			return


## How much of its speed anything walking keeps in the flood, 1 on dry ground.
func flood_slow() -> float:
	return lerpf(1.0, Balance.FLOOD_SLOW_FLOOR, clampf(flood, 0.0, 1.0))


## How much longer a well takes to refill in this heat, 1 when it is not hot.
func well_refill_scale() -> float:
	return 1.0 + maxf(temperature - Balance.WELL_HEAT_FROM, 0.0) * Balance.WELL_HEAT_REFILL_PER_DEGREE


## Seconds of refill a well loses every second in this heat, 0 when it is not hot.
func well_evaporation() -> float:
	return maxf(temperature - Balance.WELL_EVAPORATE_FROM, 0.0) * Balance.WELL_EVAPORATE_PER_DEGREE


## A sky's weight at the crossroad, leaned on by the earth's anger: the harsh
## ones grow likelier the more has been killed on the road.
func _wrathful_weight(option: WeatherData) -> float:
	var weight: float = option.weight_for_act(act)
	if option.wrathful:
		weight *= 1.0 + clampf(wrath, 0.0, Balance.WRATH_CAP) * Balance.WRATH_WEATHER_BIAS
	return weight


## Whether the water is over the knee: no dashing, no Aegis Step.
func flood_over_knee() -> bool:
	return flood > Balance.FLOOD_KNEE


## XP required to leave a level.
static func hero_xp_for_level(level: int) -> float:
	if level >= Balance.HERO_MAX_LEVEL:
		return INF
	return Balance.HERO_XP_BASE * pow(float(maxi(level, 1)), Balance.HERO_XP_CURVE)


## Awards experience and resolves however many levels it crosses.
##
## Loops rather than levelling once, because a single boss kill late in a run is
## worth several levels and dropping the remainder would quietly waste it.
func gain_hero_xp(amount: float) -> void:
	if amount <= 0.0 or hero_level >= Balance.HERO_MAX_LEVEL:
		return
	# Shared XP in co-op. Owner ruling, 2026-08-25, closing the gap recorded in
	# docs/COOP_DESIGN.md §10: both players are awarded the same amount.
	#
	# The **award** travels, never the total. That distinction is the whole of
	# making this safe: hero level and XP persist per account (CLAUDE.md rule 7),
	# so two players arrive with heroes at different levels. Relaying an absolute
	# would overwrite a level-20 guest with a level-5 host's number and *demote*
	# them - a shared pool would quietly delete somebody's progress.
	#
	# Emitted before the local application so the two machines credit the same
	# figure; each then applies it to its own hero, against its own curve.
	if Coop.is_host() and Coop.partner_present():
		EventBus.coop_xp_awarded.emit(amount)
	hero_xp += amount
	note_kept("xp", amount)
	var gained: int = 0
	while hero_level < Balance.HERO_MAX_LEVEL:
		var needed: float = hero_xp_for_level(hero_level)
		if hero_xp < needed:
			break
		hero_xp -= needed
		hero_level += 1
		gained += 1
		hero_attribute_points += 1
	if hero_level >= Balance.HERO_MAX_LEVEL:
		hero_xp = 0.0
	# Keep sub-level progress in the account state as it is earned. A level-up
	# persists immediately below; otherwise the normal run-end save writes this
	# value without turning every enemy death into a disk write.
	MetaState.hero_xp = hero_xp
	if gained > 0:
		note_kept("levels", float(gained))
		_store_hero()
		EventBus.hero_levelled.emit(hero_level, hero_attribute_points, skill_points())
	var needed: float = hero_xp_for_level(hero_level)
	EventBus.hero_xp_changed.emit(hero_xp, 0.0 if is_inf(needed) else needed,
		hero_level)


## Writes hero progression back to the account.
##
## On every level and every point placed, rather than at the end of a run. A
## crash or an alt-F4 forty minutes in should not cost a player the levels they
## earned - and "the run ended properly" is exactly the case that does not
## happen when someone rage-quits a losing Hell run, which is when they most need
## the grind to have counted.
func _store_hero() -> void:
	MetaState.hero_level = hero_level
	MetaState.hero_xp = hero_xp
	MetaState.hero_attribute_points = hero_attribute_points
	MetaState.hero_attributes = hero_attributes.duplicate()
	MetaState.last_tier_id = tier_id
	MetaState.save_game()


## Eats a fish out of the pantry, or says why not.
##
## Here rather than on `MetaState` because every reason it can fail is about the
## *run*: there has to be one, there has to be a hero to feed, and the run's
## three meals have to not be spent. `MetaState` owns the larder; this owns the
## appetite, and keeping them apart is what stops the cap being bypassed by any
## other caller that happens to hold a fish id.
##
## Returns "" when the fish was eaten, and a sentence fit to show otherwise.
## Gives a fish to the spirit at your shoulder. The same cap, because the cap
## counts fish rather than mouths - feeding the bear must not be a way round
## the one bound the pantry has.
func feed_spirit(id: String) -> String:
	var refusal: String = _take_a_fish(id)
	if not refusal.is_empty():
		return refusal
	EventBus.fish_given.emit(id, "spirit")
	return ""


## Gives a fish to a player standing beside you who is hurt.
func feed_ally(id: String) -> String:
	var refusal: String = _take_a_fish(id)
	if not refusal.is_empty():
		return refusal
	EventBus.fish_given.emit(id, "ally")
	return ""


## Everything that can refuse a meal, and the spending, in one place.
func _take_a_fish(id: String) -> String:
	if not GameDirector.run_active:
		return "Fish are shared on the road, not between runs."
	var kind: FishData = ContentDB.fish(id)
	if kind == null:
		return "No such fish."
	if MetaState.fish_count(id) <= 0:
		return "You have none of those."
	if meals_eaten >= Balance.FISH_MEALS_PER_RUN:
		return "Nothing left to share this run."
	if not MetaState.spend_fish(id):
		return "You have none of those."
	meals_eaten += 1
	return ""


func eat_fish(id: String) -> String:
	if not GameDirector.run_active:
		return "Fish are eaten on the road, not between runs."
	var kind: FishData = ContentDB.fish(id)
	if kind == null:
		return "No such fish."
	if MetaState.fish_count(id) <= 0:
		return "You have none of those."
	if meals_eaten >= Balance.FISH_MEALS_PER_RUN:
		return "You have eaten all you can stomach this run."
	if not MetaState.spend_fish(id):
		return "You have none of those."
	meals_eaten += 1
	# Announced rather than applied here: the hero is the thing with health, a
	# ward and mana, and `RunState` holds no reference to it (working rule 5).
	EventBus.fish_eaten.emit(id)
	return ""


## How many meals this run has left.
func meals_left() -> int:
	return maxi(Balance.FISH_MEALS_PER_RUN - meals_eaten, 0)


## The campaign tier this run is on.
func tier() -> CampaignTierData:
	var found: CampaignTierData = ContentDB.tier(tier_id)
	if found != null:
		return found
	var all: Array[CampaignTierData] = ContentDB.tiers_sorted()
	return all[0] if not all.is_empty() else null


## What the tier expects the hero to be worth at this act's boss.
func expected_boss_level(for_act: int) -> int:
	var live: CampaignTierData = tier()
	return live.expected_level(for_act) if live != null else 1


## How far under the tier's expectancy the hero is, as a fraction. Zero when at
## or above it.
func under_levelled(for_act: int) -> float:
	var want: int = expected_boss_level(for_act)
	if want <= 1 or hero_level >= want:
		return 0.0
	return clampf(1.0 - float(hero_level) / float(want), 0.0, 1.0)


## Fraction of the way to the next level, for the HUD.
func hero_level_progress() -> float:
	if hero_level >= Balance.HERO_MAX_LEVEL:
		return 1.0
	return clampf(hero_xp / maxf(hero_xp_for_level(hero_level), 1.0), 0.0, 1.0)


## Places one point. Returns why not, or "" when it landed.
func spend_attribute_point(attribute: int) -> String:
	if hero_attribute_points <= 0:
		return "No attribute points to spend."
	if attribute < 0 or attribute >= hero_attributes.size():
		return "No such attribute."
	hero_attribute_points -= 1
	hero_attributes[attribute] += 1
	_store_hero()
	EventBus.hero_attributes_changed.emit()
	return ""


## An attribute's total: points the player placed, plus points their gear grants.
##
## Gear is folded in here rather than at each use site, so every consumer -
## damage, health, movement, command - reads one number and none of them can be
## the one that forgot about equipment.
func attribute(which: int) -> int:
	if which < 0 or which >= hero_attributes.size():
		return 0
	var worn: Array[int] = MetaState.gear_attribute_points()
	var bonus: int = worn[which] if which < worn.size() else 0
	return hero_attributes[which] + bonus


## Learns a node from the Mansion, in Preparation. The Hold's door is
## `MetaState.learn_discipline`, which this is: the road only adds the phase,
## because the tree is the account's and only the time to edit it is the road's.
##
## **No Food, no cap, no offers** (owner ruling R5, 2026-09-26). A point is the
## price, and points come from levels and first clears; the ring a node sits in
## is the gate. A node learned here is kept when the road ends.
func try_learn_discipline(id: String) -> String:
	if not is_preparation():
		return "The tree is learned in Preparation, or in the Hold."
	if building_tier("sanctum") <= 0:
		return "Build the Hero Mansion to learn on the road, or learn in the Hold between roads."
	var problem: String = MetaState.learn_discipline(id, act)
	if problem.is_empty():
		_sync_discipline_spells()
	return problem


## Puts a learned skill into the slot it belongs to, in Preparation. The slot
## may not be open on this road yet; the loadout is the account's, and the skill
## waits there for the boss that opens it.
func try_equip_discipline(id: String) -> String:
	if not is_preparation():
		return "Loadout changes are available only in Preparation."
	var node: DisciplineNodeData = ContentDB.discipline_node(id)
	if node == null or not node.is_active_slot():
		return "That is not a skill for a slot."
	var problem: String = MetaState.set_discipline_slot(node.slot_index(), id)
	if not problem.is_empty():
		return problem
	_sync_discipline_spells()
	EventBus.discipline_equipped.emit(node.slot_index(), id)
	return ""


## Takes up a chain form, in Preparation. Announced as slot -1: the form
## sits beside the four slots.
func try_choose_form(id: String) -> String:
	if not is_preparation():
		return "Loadout changes are available only in Preparation."
	var problem: String = MetaState.set_discipline_form(id, act)
	if problem.is_empty():
		EventBus.discipline_equipped.emit(-1, id)
	return problem


## The combat bar's spells, restated from the loadout against the slots this
## road has opened. Called at a run's start, on a loadout change, when a boss
## falls and when the Mansion is raised - the four things that move it.
func _sync_discipline_spells() -> void:
	equipped_spells.clear()
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var node: DisciplineNodeData = discipline_node_in_slot(slot)
		equipped_spells.append(node.spell_id if node != null else "")
	EventBus.spells_changed.emit()


# --- Tower placement --------------------------------------------------------

func tower_entry(anchor: Vector2i) -> Dictionary:
	return towers.get(anchor, {})


func tile_is_empty(anchor: Vector2i) -> bool:
	return not towers.has(anchor)


func tower_at(anchor: Vector2i) -> TowerData:
	var entry: Dictionary = tower_entry(anchor)
	if entry.is_empty():
		return null
	return ContentDB.tower(String(entry.get("tower_id", "")))


func level_at(anchor: Vector2i) -> int:
	return int(tower_entry(anchor).get("level", 0))


func set_tower(anchor: Vector2i, tower_id: String, level: int) -> void:
	var entry: Dictionary = tower_entry(anchor)
	var priority: int = int(entry.get("target_priority", TowerData.TargetPriority.FIRST))
	# The path survives a level, because it is the thing the levels are for.
	var path: int = int(entry.get("path", TowerData.Path.NONE))
	towers[anchor] = {"tower_id": tower_id, "level": level, "target_priority": priority,
		"path": path}
	EventBus.tower_changed.emit(anchor)


## Which way the tower on that tile was taken, or NONE.
func tower_path(anchor: Vector2i) -> int:
	return int(tower_entry(anchor).get("path", TowerData.Path.NONE))


## Sets it, once. Returns whether it took - a path already chosen is not
## changed, because a free re-pick every Preparation is not a decision.
func set_tower_path(anchor: Vector2i, path: int) -> bool:
	var entry: Dictionary = tower_entry(anchor)
	if entry.is_empty() or int(entry.get("path", TowerData.Path.NONE)) != TowerData.Path.NONE:
		return false
	# **Not before the level it belongs to.** Without this the choice could be
	# taken the moment a tower was built, which skips the ladder the split
	# exists to put a decision on - `tower_path_check` caught it on its first
	# run, which is the whole reason the gate walks the levels rather than
	# asserting the constants.
	if int(entry.get("level", 1)) < Balance.TOWER_SPECIALISE_LEVEL:
		return false
	if path != TowerData.Path.FOCUS and path != TowerData.Path.SPREAD:
		return false
	entry["path"] = path
	towers[anchor] = entry
	EventBus.tower_changed.emit(anchor)
	return true


## Whether this tower is standing at the level where it must choose, and has
## not. The build sheet asks; so does the gate.
func tower_awaits_path(anchor: Vector2i) -> bool:
	var entry: Dictionary = tower_entry(anchor)
	if entry.is_empty():
		return false
	return int(entry.get("level", 1)) >= Balance.TOWER_SPECIALISE_LEVEL \
		and int(entry.get("path", TowerData.Path.NONE)) == TowerData.Path.NONE


## What is laid on a tile, or null.
func trap_at(tile: Vector2i) -> TrapData:
	var entry: Dictionary = traps.get(tile, {}) as Dictionary
	return ContentDB.trap(String(entry.get("trap_id", "")))


## How many triggers that trap has left.
func trap_triggers_left(tile: Vector2i) -> int:
	return int((traps.get(tile, {}) as Dictionary).get("triggers_left", 0))


func set_trap(tile: Vector2i, trap_id: String, triggers_left: int, level: int = 1) -> void:
	traps[tile] = {"trap_id": trap_id, "triggers_left": triggers_left,
		"level": maxi(level, 1)}
	EventBus.trap_changed.emit(tile)


## What level the trap on that tile is, or 0 if nothing is laid there.
func trap_level(tile: Vector2i) -> int:
	var entry: Dictionary = traps.get(tile, {}) as Dictionary
	return int(entry.get("level", 1)) if not entry.is_empty() else 0


## Raises a laid trap by one level, restoring its triggers with it. Returns
## whether it could. The caller has already taken the price.
func upgrade_trap(tile: Vector2i) -> bool:
	var entry: Dictionary = traps.get(tile, {}) as Dictionary
	if entry.is_empty():
		return false
	var level: int = int(entry.get("level", 1))
	if level >= Balance.TRAP_MAX_LEVEL:
		return false
	var kind: TrapData = ContentDB.trap(String(entry.get("trap_id", "")))
	entry["level"] = level + 1
	# A rebuilt trap is a whole trap: the point of paying is a fresh one that
	# hits harder, not a spent one that hits harder once.
	entry["triggers_left"] = kind.triggers if kind != null else int(entry.get("triggers_left", 1))
	traps[tile] = entry
	EventBus.trap_changed.emit(tile)
	return true


func clear_trap(tile: Vector2i) -> void:
	if not traps.has(tile):
		return
	traps.erase(tile)
	EventBus.trap_changed.emit(tile)


## What stands on a tile, or null.
func barricade_at(tile: Vector2i) -> BarricadeData:
	var entry: Dictionary = barricades.get(tile, {}) as Dictionary
	return ContentDB.barricade(String(entry.get("barricade_id", "")))


func barricade_health(tile: Vector2i) -> float:
	return float((barricades.get(tile, {}) as Dictionary).get("health", 1.0))


func set_barricade(tile: Vector2i, barricade_id: String, health: float) -> void:
	barricades[tile] = {"barricade_id": barricade_id, "health": health}
	EventBus.barricade_changed.emit(tile)


func clear_barricade(tile: Vector2i) -> void:
	if not barricades.has(tile):
		return
	barricades.erase(tile)
	EventBus.barricade_changed.emit(tile)


## Takes the tower off `anchor`. `at` is where it stood, and a non-zero one means
## it was **broken** rather than sold - the two are indistinguishable from the
## tile afterwards, and they should not sound or feel the same.
func clear_tower(anchor: Vector2i, broken_at: Vector2 = Vector2.ZERO) -> void:
	if not towers.has(anchor):
		return
	towers.erase(anchor)
	# Before `tower_changed` and synchronously, so a listener reading the pair
	# sees the reason before it sees the consequence.
	if broken_at != Vector2.ZERO:
		EventBus.tower_destroyed.emit(anchor, broken_at)
	EventBus.tower_changed.emit(anchor)


func target_priority_at(anchor: Vector2i) -> int:
	return int(tower_entry(anchor).get("target_priority", TowerData.TargetPriority.FIRST))


func cycle_target_priority(anchor: Vector2i) -> int:
	if not towers.has(anchor):
		return TowerData.TargetPriority.FIRST
	var count: int = TowerData.TargetPriority.size()
	var priority: int = (target_priority_at(anchor) + 1) % count
	towers[anchor]["target_priority"] = priority
	EventBus.tower_targeting_changed.emit(anchor, priority)
	return priority


## Which road a tower answers to, for lane armour, Rally and pressure.
##
## Free placement means a tower is not *in* a lane any more, but several systems
## still need one: road armour applies to a road, Rally targets a road. The
## nearest cardinal by angle is the honest answer - it is the road the tower is
## most plausibly defending.
static func tower_lane(anchor: Vector2i) -> int:
	var at: Vector2 = BattleGrid.footprint_centre(anchor)
	if at.is_zero_approx():
		return 0
	var best: int = 0
	var best_dot: float = -INF
	for lane: int in Balance.LANE_COUNT:
		var dot: float = at.normalized().dot(BattleGrid.lane_vector(lane))
		if dot > best_dot:
			best_dot = dot
			best = lane
	return best


## Every anchor whose tower answers to this road.
func towers_on_lane(lane: int) -> Array:
	var found: Array = []
	for key: Variant in towers:
		var anchor: Vector2i = key
		if tower_lane(anchor) == lane:
			found.append(anchor)
	return found


# --- Fusion by adjacency ----------------------------------------------------

## The four orthogonal neighbours a fusion could pair across.
##
## A tower is 2x2, so "exactly one tower-width gap" is a step of four tiles: two
## for this tower, two for the gap. Diagonals are deliberately excluded (GDD §13).
const FUSION_STEP: int = BattleGrid.FOOTPRINT * 2

static func fusion_partners(anchor: Vector2i) -> Array[Vector2i]:
	return [
		anchor + Vector2i(FUSION_STEP, 0),
		anchor + Vector2i(-FUSION_STEP, 0),
		anchor + Vector2i(0, FUSION_STEP),
		anchor + Vector2i(0, -FUSION_STEP),
	]


## Every combination that could be built on this tile, given what flanks it.
##
## Returns one entry per qualifying pair: {"tower": TowerData, "a": Vector2i,
## "b": Vector2i}. More than one pair can qualify, and v4 §13 says the player
## chooses rather than the game picking for them.
func combinations_for_tile(anchor: Vector2i) -> Array[Dictionary]:
	var offered: Array[Dictionary] = []
	var seen: Dictionary = {}
	# From the *gap*, each parent is one footprint away - not two. Two is the
	# distance between the parents themselves, which is what `fusion_partners`
	# measures; measuring from the middle with the same number looked past both
	# of them and offered nothing.
	for axis: Vector2i in [Vector2i(BattleGrid.FOOTPRINT, 0), Vector2i(0, BattleGrid.FOOTPRINT)]:
		var a: Vector2i = anchor - axis
		var b: Vector2i = anchor + axis
		var left: TowerData = tower_at(a)
		var right: TowerData = tower_at(b)
		if left == null or right == null:
			continue
		# A fusion parent may not itself be a fusion.
		if left.is_combination or right.is_combination:
			continue
		var made: TowerData = ContentDB.combination_for(left.element, right.element)
		if made == null or seen.has(made.id):
			continue
		seen[made.id] = true
		offered.append({"tower": made, "a": a, "b": b})
	return offered


## True when this tower's flanking parents still stand.
##
## A fusion whose parent was destroyed keeps firing at reduced output (GDD §20),
## so this is a question about utility, not existence.
func fusion_parents_intact(anchor: Vector2i) -> bool:
	var entry: Dictionary = tower_entry(anchor)
	if entry.is_empty():
		return true
	var built: TowerData = tower_at(anchor)
	if built == null or not built.is_combination:
		return true
	for axis: Vector2i in [Vector2i(BattleGrid.FOOTPRINT, 0), Vector2i(0, BattleGrid.FOOTPRINT)]:
		if tower_at(anchor - axis) != null and tower_at(anchor + axis) != null:
			return true
	return false


## True when this tower is one of a matching pair that could fuse (GDD §4.2).
##
## Same-element resonance now follows the same adjacency rule as fusion: the pair
## that *would* fuse is the pair that resonates. A tower with a same-element
## partner exactly one tower-width away, orthogonally, gets the bonus - so
## resonance is something the player arranges on the grid rather than something a
## fixed slot handed them.
func has_fusion_synergy(anchor: Vector2i) -> bool:
	var mine: TowerData = tower_at(anchor)
	if mine == null or mine.is_combination:
		return false
	for partner: Vector2i in fusion_partners(anchor):
		var other: TowerData = tower_at(partner)
		if other != null and not other.is_combination and other.element == mine.element:
			return true
	return false


# --- Phase and Command -----------------------------------------------------

func set_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	var previous: Phase = phase
	phase = next_phase
	EventBus.phase_changed.emit(int(phase), int(previous))


func is_preparation() -> bool:
	return phase == Phase.PREPARATION


func can_build_now() -> bool:
	return is_preparation()


## **How many wells stand on the road right now.**
##
## Read off `towers` rather than by walking the Tower group, so there is one
## answer and it is the run's own: an entry leaves this dictionary when a well
## is sold *and* when one is destroyed (`clear_tower`), which is exactly what
## "a well that falls frees its place" has to mean. It is also the only shape
## a `static` price function and the build sheet can both reach.
##
## Per road rather than per player: in co-op the party shares the allowance,
## for the same reason one player sharing it with themselves was already too
## much (2026-09-13).
func wells_standing() -> int:
	var found: int = 0
	for anchor: Variant in towers:
		var kind: TowerData = tower_at(anchor as Vector2i)
		if kind != null and kind.is_well():
			found += 1
	return found


## **The moment a build sheet may open again**, as a msec stamp.
##
## Owner, 2026-09-22: *"add a 1 second grace period so that players cannot
## open a build menu for 1 second after a wave ends ... so that players can
## for example stop spam attacking whatever they were attacking"*. A wave
## closes synchronously - `wave_cleared` is emitted inside `WaveDirector._process`,
## `Run._enter_wave_breather` runs in the same frame, and both `can_build_now()`
## and `GameDirector.build_mode` become true inside that one emit. The very
## next mouse release opens a sheet, and a player still swinging at the last
## body gets one they did not ask for.
##
## **Deliberately not folded into `can_build_now()`.** That question is asked
## by the Quartermaster, by tower repair, by selling and by the crossroad
## path, none of which the player is clicking the ground for; a grace there
## would refuse all of them for a second for no reason. It is asked beside it,
## at the one gate on the click path (`PlacementCursor._is_active`).
var build_grace_until_msec: int = 0


## Arms the grace. Called where Preparation opens *after a wave*, and nowhere
## else: a crossroad, an act start and the opening breather are not moments
## anybody is mid-swing in.
func arm_build_grace() -> void:
	build_grace_until_msec = Time.get_ticks_msec() + int(Balance.BUILD_GRACE_SECONDS * 1000.0)


## Seconds of grace left, or zero. Read by the cursor and by the run's clock.
func build_grace_left() -> float:
	return maxf(float(build_grace_until_msec - Time.get_ticks_msec()) / 1000.0, 0.0)


## **Whether a road is being played right now** - the one time the account may
## not be rearranged underneath it.
##
## Not `phase != ENDED`, which is what the Warden picker and the pen asked, and
## which was wrong in the direction the owner met (2026-09-22: *"even if I don't
## have a run saved I should still be able to change save slots. And even if I
## do"*). The phase becomes `ENDED` only when a run is *settled*: it starts every
## launch as `PREPARATION`, and a road left from the pause menu is abandoned
## without ever reaching `ENDED` - so on a fresh launch, and after every quit,
## the menu refused to change Warden because "a road is under way" when no road
## existed. `run_active` is the director's own answer to that question.
func road_is_live() -> bool:
	return GameDirector.run_active and phase != Phase.ENDED


func is_command_combat() -> bool:
	return phase == Phase.ROAD_BATTLE or phase == Phase.BOSS \
		or phase == Phase.FINAL_ASCENT


func begin_command_battle() -> void:
	command = 0.0
	last_stand_used = false
	horn_used_this_battle = false
	EventBus.command_changed.emit(command, Balance.COMMAND_MAX)


func add_wound() -> int:
	hero_wounds = mini(hero_wounds + 1, max_wounds())
	wounds_suffered += 1
	if last_scar_active:
		last_scar_failed = true
	Modifiers.rebuild()
	EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	return hero_wounds


func hearthmend() -> void:
	hero_wounds = 0
	hearthmends_used += 1
	Modifiers.rebuild()
	hero_hp = -1.0
	hero_mana = -1.0
	var repair: float = town_max_hp * Balance.HEARTHMEND_TOWN_REPAIR_FRACTION
	town_hp = minf(town_hp + repair, town_max_hp)
	EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	EventBus.town_health_changed.emit(town_hp, town_max_hp)
	EventBus.hearthmend_completed.emit(act)


func max_wounds() -> int:
	# **One wound, ever, in Hardcore** (owner, 2026-09-30): nothing raises it -
	# no relic, no card, no node - because "1/1" is the whole of the oath.
	if MetaState.hardcore:
		return 1
	return Balance.HERO_MAX_WOUNDS + hero_max_wounds_bonus


## One authored offer, once per run. Having suffered rather than still carrying
## a Wound lets Hearthmend work without erasing qualification.
func can_offer_last_scar() -> bool:
	return act == Balance.LAST_SCAR_OFFER_ACT and wounds_suffered > 0 \
		and not last_scar_offered and not last_scar_resolved


func accept_last_scar() -> bool:
	if not can_offer_last_scar():
		return false
	last_scar_offered = true
	last_scar_pending = true
	EventBus.last_scar_changed.emit("pending")
	return true


func mirror_accept_last_scar() -> void:
	last_scar_offered = true
	last_scar_pending = true
	EventBus.last_scar_changed.emit("pending")


## The vow attaches to the road ultimately chosen, not to opening its card.
func start_last_scar_road() -> void:
	if not last_scar_pending:
		return
	last_scar_pending = false
	last_scar_active = true
	last_scar_failed = false
	last_scar_pursuer_spawned = false
	last_scar_pursuer_defeated = false
	last_scar_min_town_ratio = town_hp / town_max_hp if town_max_hp > 0.0 else 0.0
	EventBus.last_scar_changed.emit("active")


func last_scar_locks_rations() -> bool:
	return last_scar_active


func mark_last_scar_pursuer_spawned() -> void:
	last_scar_pursuer_spawned = true


func mark_last_scar_pursuer_defeated() -> void:
	if last_scar_active:
		last_scar_pursuer_defeated = true
		EventBus.last_scar_changed.emit("pursuer_defeated")


func _on_town_health_for_last_scar(current: float, maximum: float) -> void:
	if last_scar_active and maximum > 0.0:
		last_scar_min_town_ratio = minf(last_scar_min_town_ratio, current / maximum)


## Settled at the next road boundary. An empty dictionary means no active oath.
func resolve_last_scar_road() -> Dictionary:
	if not last_scar_active:
		return {}
	var reason: String = "complete"
	if last_scar_failed:
		reason = "wound"
	elif last_scar_min_town_ratio < Balance.LAST_SCAR_TOWN_MIN_RATIO:
		reason = "town"
	elif not last_scar_pursuer_defeated:
		reason = "pursuer"
	var success: bool = reason == "complete"
	last_scar_active = false
	last_scar_resolved = true
	if success:
		hero_max_wounds_bonus = Balance.LAST_SCAR_MAX_WOUND_BONUS
		EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	EventBus.last_scar_resolved.emit(success, reason, max_wounds())
	return {"success": success, "reason": reason, "maximum": max_wounds()}


## Applies the authority's settled result on a guest.
func mirror_last_scar_resolution(success: bool, reason: String, maximum: int) -> void:
	last_scar_pending = false
	last_scar_active = false
	last_scar_resolved = true
	hero_max_wounds_bonus = maxi(maximum - Balance.HERO_MAX_WOUNDS, 0) if success else 0
	EventBus.hero_wounds_changed.emit(hero_wounds, max_wounds())
	EventBus.last_scar_resolved.emit(success, reason, max_wounds())


func can_roll_mender_spark() -> bool:
	return int(mender_sparks_claimed_by_act.get(act, 0)) \
		< Balance.MENDER_SPARK_MAX_PER_ACT


## Pity is per act. The allowance is consumed when the drop appears, so leaving
## it on the road is a tactical choice rather than a reroll.
func roll_mender_spark() -> bool:
	if not can_roll_mender_spark():
		return false
	var eligible: int = int(mender_eligible_elites_by_act.get(act, 0)) + 1
	mender_eligible_elites_by_act[act] = eligible
	var drops: bool = eligible >= Balance.MENDER_SPARK_PITY_ELITES \
		or rng("mender").randf() <= Balance.MENDER_SPARK_DROP_CHANCE
	if drops:
		mender_sparks_claimed_by_act[act] = \
			int(mender_sparks_claimed_by_act.get(act, 0)) + 1
		mender_eligible_elites_by_act[act] = 0
	return drops


func gain_command(amount: float) -> void:
	if amount <= 0.0 or not is_command_combat():
		return
	# Focus. Applied to the gain rather than to the ceiling, so it makes orders
	# come round faster without letting a player bank more of them.
	amount *= 1.0 + float(attribute(Attribute.FOCUS)) * Balance.HERO_FOCUS_COMMAND_PER_POINT
	var before: float = command
	command = clampf(command + amount, 0.0, Balance.COMMAND_MAX)
	command_earned += command - before
	if not is_equal_approx(command, before):
		EventBus.command_changed.emit(command, Balance.COMMAND_MAX)


func can_spend_command(cost: float) -> bool:
	return is_command_combat() and cost >= 0.0 and command >= cost


func spend_command(cost: float, order_id: String) -> bool:
	if not can_spend_command(cost):
		return false
	command = maxf(command - cost, 0.0)
	command_orders_used[order_id] = int(command_orders_used.get(order_id, 0)) + 1
	EventBus.command_changed.emit(command, Balance.COMMAND_MAX)
	return true


# --- Economy helpers --------------------------------------------------------

## The last thing to hurt a hero, and how hard.
##
## **Recorded where the blow is dealt, not where it lands.** `Health.take_damage`
## receives a position and an amount; it has no idea what swung. The attacker is
## the only one who knows its own name, so each source says so on its way past.
##
## Cleared with the run. The debrief reads it to answer the one question a death
## screen has always owed the player: what killed me, and for how much.
var last_blow: Dictionary = {}

## What the run keeps whatever happens to it: the account's gains, counted
## where each is banked, so the debrief can say what the road was worth even
## when it ended badly (the fifth forwarded list: "failure should produce
## stories instead of frustration"). Keys: xp, levels, materials, fish, gear,
## spirits, craft_xp. Cleared with the run.
var kept: Dictionary = {}

## The Farmer's seeds, by crop id (2026-09-14). The run's, and cleared with
## it: nothing here persists, which is what keeps farming inside working
## rule 7 as the Angler's craft is. See `Farming`.
var seeds: Dictionary = {}

## The sex of each bonded spirit summoned this run, by bond key.
##
## Decided once and kept for the run (owner brief, 2026-09-14), so dismissing
## a companion, re-equipping it or reconnecting all read the same answer. Run
## scoped on purpose: working rule 7 is untouched, and a sex banked on the
## account would be one more thing `MetaState` writes for no gain.
## **The eggs this Warden is carrying**, each `{species, rarity, shiny}`.
##
## Owner brief, 2026-09-15: imprinted living companions. An egg taken from a
## nest is carried rather than banked, and reaching home with one bonds that
## variant outright - which is the translation `IDEAS_REVIEW_2026-09-15` argued
## for, the proposal's steal-and-be-hunted beat written in this game's own
## grammar rather than an extraction shooter's.
##
## **Run scoped, and personal.** Nothing persists - working rule 7 is untouched,
## because what an egg finally becomes is a *bond*, which the account already
## keeps. And each Warden carries their own: this is one machine's list, never
## relayed, exactly as a caught fish and a craft's practice are that player's.
## A run that falls loses them, which is the whole of the price.
var carried_eggs: Array[Dictionary] = []

var companion_sex: Dictionary = {}
## What the earth did this run, by kind - strikes, quakes, tornadoes, meteors,
## wildfires - counted where each is *seen*, so a guest's debrief agrees with
## the host's. Cleared with the run.
var earth_events: Dictionary = {}


## One egg into the pack.
##
## Capped, because a pack with forty eggs in it is a farm rather than a
## decision - and the cap is what keeps a single act of nest-robbing from being
## the fastest way to fill a collection.
func carry_egg(species_id: String, rarity: int, shiny: bool) -> bool:
	if species_id.is_empty() or carried_eggs.size() >= Balance.EGGS_CARRIED_MAX:
		return false
	carried_eggs.append({"species": species_id, "rarity": rarity, "shiny": shiny})
	return true


func note_kept(key: String, amount: float = 1.0) -> void:
	if amount <= 0.0 or key.is_empty():
		return
	kept[key] = float(kept.get(key, 0.0)) + amount


func add_seeds(id: String, count: int) -> void:
	if count <= 0 or ContentDB.crop(id) == null:
		return
	seeds[id] = mini(int(seeds.get(id, 0)) + count, Balance.FARM_SEED_CAP)


func take_seed(id: String) -> bool:
	if int(seeds.get(id, 0)) <= 0:
		return false
	seeds[id] = int(seeds[id]) - 1
	return true


func seed_count(id: String) -> int:
	return int(seeds.get(id, 0))


func note_earth(kind: String) -> void:
	if kind.is_empty():
		return
	earth_events[kind] = int(earth_events.get(kind, 0)) + 1


## Notes a blow against a hero. Cheap enough to call from every strike.
func note_blow(source_name: String, amount: float) -> void:
	if source_name.is_empty() or amount <= 0.0:
		return
	last_blow = {"source": source_name, "amount": amount}


## "a Rimewarded Bogkin for 34", or "" when nothing has landed yet.
func last_blow_line() -> String:
	if last_blow.is_empty():
		return ""
	return "%s for %d" % [String(last_blow.get("source", "?")),
		int(round(float(last_blow.get("amount", 0.0))))]


# --- Ranged combat -----------------------------------------------------------
#
# Owner decision, 2026-08-31. Three pieces of run state and one rule.

## Ammunition held, by ammo id. **Its own purse, not the four currencies and not
## the stash.**
##
## Kept apart deliberately. Ammunition in the normal inventory would make every
## arrow compete with loot for room, which is how players come to resent a system
## meant to give them options - and a decision about arrows must never compete
## with the wall about to be overrun, the same reasoning that keeps Marks off the
## tower economy.
var ammo: Dictionary = {}

## What the hero has drawn, and what is nocked. Empty means melee only, which is
## where every run starts.
var ranged_id: String = ""
var ammo_id: String = ""


## How much room the quiver has left, counting each shot's bulk.
##
## Bulk is the whole of the scarcity model: no rarity tiers, no encumbrance, no
## second currency. A quiver simply holds fewer bombs than arrows.
func ammo_bulk_used() -> int:
	var used: int = 0
	for id: Variant in ammo.keys():
		var kind := ContentDB.ammo_kinds.get(id, null) as AmmoData
		if kind != null:
			used += int(ammo[id]) * kind.bulk
	return used


func ammo_room() -> int:
	return maxi(Balance.AMMO_CAPACITY - ammo_bulk_used(), 0)


func ammo_count(id: String) -> int:
	return int(ammo.get(id, 0))


## Adds ammunition, refusing what will not fit. Returns how many actually went in.
##
## Refuses rather than silently discarding: a pickup that vanishes into a full
## quiver reads as the game losing it.
func gain_ammo(id: String, amount: int) -> int:
	var kind := ContentDB.ammo_kinds.get(id, null) as AmmoData
	if kind == null or amount <= 0:
		return 0
	var fits: int = ammo_room() / maxi(kind.bulk, 1)
	var taken: int = mini(amount, fits)
	if taken <= 0:
		return 0
	ammo[id] = ammo_count(id) + taken
	EventBus.ammo_changed.emit(id, ammo_count(id))
	return taken


## Spends one shot. False when the quiver is empty, which is the caller's cue to
## fall back rather than to fire nothing.
func spend_one_ammo(id: String) -> bool:
	var held: int = ammo_count(id)
	if held <= 0:
		return false
	if held == 1:
		ammo.erase(id)
	else:
		ammo[id] = held - 1
	EventBus.ammo_changed.emit(id, ammo_count(id))
	return true


## The ammunition this weapon can fire, in a stable order, known recipes only.
func ammo_for_weapon(weapon_id: String) -> Array[AmmoData]:
	var out: Array[AmmoData] = []
	var weapon := ContentDB.ranged_weapons.get(weapon_id, null) as RangedWeaponData
	if weapon == null:
		return out
	var ids: Array = ContentDB.ammo_kinds.keys()
	ids.sort()
	for id: Variant in ids:
		var kind := ContentDB.ammo_kinds[id] as AmmoData
		if kind != null and kind.family == weapon.family:
			out.append(kind)
	return out


## Makes a batch. Returns "" on success, or the reason it refused.
##
## **Blueprint first, then cost, then room.** Checked in that order because they
## are three different answers: one says learn it, one says gather more, and one
## says you are already carrying as much as you can.
func craft_ammo(id: String, batches: int = 1) -> String:
	var kind := ContentDB.ammo_kinds.get(id, null) as AmmoData
	if kind == null:
		return "Nothing is made to that pattern."
	if not kind.known_from_the_start and not MetaState.knows_recipe("ammo", id):
		return "You do not know how to make %s." % kind.display_name
	var runs: int = maxi(batches, 1)
	var cost: Dictionary = {}
	for currency_id: Variant in kind.craft_cost.keys():
		cost[currency_id] = int(kind.craft_cost[currency_id]) * runs
	if not can_afford_cost(cost):
		return "Needs %s." % format_cost(cost)
	var made: int = kind.craft_batch * runs
	if ammo_room() < made * kind.bulk:
		return "No room for that many %s." % kind.display_name
	spend_cost(cost)
	gain_ammo(id, made)
	return ""


func currency(id: String) -> int:
	return int(currencies.get(id, 0))


func currency_name(id: String) -> String:
	return id.capitalize()


func format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in CURRENCIES:
		var amount: int = int(cost.get(id, 0))
		if amount > 0:
			parts.append("%d %s" % [amount, currency_name(id)])
	return " + ".join(parts)


func can_afford_cost(cost: Dictionary) -> bool:
	for key: Variant in cost:
		var id: String = String(key)
		if currency(id) < int(cost[key]):
			return false
	return true


func spend_cost(cost: Dictionary) -> bool:
	if not can_afford_cost(cost):
		return false
	for key: Variant in cost:
		var id: String = String(key)
		var amount: int = maxi(int(cost[key]), 0)
		currencies[id] = currency(id) - amount
		currency_spent[id] = int(currency_spent.get(id, 0)) + amount
		resources_spent += amount
		_emit_currency(id)
	return true


func gain_currency(id: String, amount: int) -> void:
	if not CURRENCIES.has(id) or amount == 0:
		return
	if amount > 0:
		amount = _scarcity(id, amount)
		if amount <= 0:
			return
	currencies[id] = maxi(currency(id) + amount, 0)
	if amount > 0:
		currency_earned[id] = int(currency_earned.get(id, 0)) + amount
		resources_earned += amount
	_emit_currency(id)


func _emit_currency(id: String) -> void:
	EventBus.currency_changed.emit(id, currency(id))
	if id == GOLD:
		EventBus.resources_changed.emit(currency(GOLD))


## Compatibility wrappers for v3 tools and content. The old pooled resource is
## now explicitly Gold; new gameplay code must use a typed cost dictionary.
func can_afford(cost: int) -> bool:
	return currency(GOLD) >= cost


func spend(cost: int) -> bool:
	return spend_cost({GOLD: cost})


func gain_resources(amount: int) -> void:
	gain_currency(GOLD, amount)


## Funds every wallet. For harnesses that want to build without the economy
## being the subject of the test - since towers draw on a secondary currency per
## element now, funding Gold alone buys only the Fire roster.
##
## **Unscaled.** This is a harness funding itself, not the game paying out, so
## it skips the scarcity trim: a test that asked for 2400 and was handed 960
## would be testing `CURRENCY_YIELD_SCALE` rather than whatever it meant to.
func gain_every_currency(amount: int) -> void:
	for id: String in CURRENCIES:
		if amount > 0:
			currencies[id] = maxi(currency(id) + amount, 0)
			currency_earned[id] = int(currency_earned.get(id, 0)) + amount
			resources_earned += amount
			_emit_currency(id)
		else:
			gain_currency(id, amount)


## The scarcity trim for one wallet, carrying the fraction it cannot pay.
##
## Without the carry a trim of 0.4 on a grant of one is a grant of nothing,
## and Food arrives one unit at a time from half its sources - the wallet
## would have stopped filling rather than filled slower, which is a different
## and much worse game. See `Balance.CURRENCY_YIELD_SCALE`.
func _scarcity(id: String, amount: int) -> int:
	var scale: float = float(Balance.CURRENCY_YIELD_SCALE.get(id, 1.0))
	if is_equal_approx(scale, 1.0):
		return amount
	var carried: float = float(_yield_remainder.get(id, 0.0)) + float(amount) * scale
	var whole: int = int(floor(carried))
	_yield_remainder[id] = carried - float(whole)
	return whole


## Adds a scaled enemy drop while retaining fractions across kills.
func gain_kill_resources(base_amount: int) -> void:
	if base_amount <= 0:
		return
	var earned: float = float(base_amount) * Balance.KILL_RESOURCE_SCALE \
		* Balance.kill_act_scale(act) \
		* Modifiers.multiplier(Modifiers.KILL_RESOURCES)
	# Twice the bodies into one shared pool is twice the income, and the tower
	# curve was tuned against one player earning. See the constant for why it is
	# under one since the Arsenal.
	if Coop.partner_present():
		earned *= Balance.COOP_KILL_INCOME_SCALE
	kill_resource_remainder += earned
	var whole: int = int(floor(kill_resource_remainder))
	if whole <= 0:
		return
	kill_resource_remainder -= float(whole)
	gain_resources(whole)


## Takes a card into the hand, and owns both rules that keep the hand bounded.
##
## **One card per effect key.** A second card naming a key the hand already
## holds replaces it rather than adding to it, so rarity is an upgrade path and
## never a stack. Returns the id that left the hand, or "" if nothing did.
##
## **Five slots.** When the hand is full and the card is on a new key, `drop`
## names what the player chose to give up. A `drop` that is not in the hand is
## refused rather than guessed at: a silent fallback here would quietly discard
## whatever happened to be first, which is the kind of loss a player notices and
## cannot undo.
##
## Both rules live in this one function so that `road_card_check` can drive the
## real thing rather than a copy of it.
func take_road_card(card_id: String, drop: String = "") -> String:
	return take_card_for(_mine, card_id, drop)


## `take_road_card`, for a seat: this machine's own, or on the host a guest's.
## The hand a card goes to is `target_hand` - the party's board, or in a split
## hand the seat's own - and every rule below is the same rule on either.
func take_card_for(seat: AugmentSeat, card_id: String, drop: String = "") -> String:
	var card: RoadCardData = ContentDB.road_card(card_id)
	if card == null:
		return ""
	var own: bool = hands_split and Augments.seat_keeps(card)
	var hand: Array[String] = seat.cards if own else road_cards
	var levels: Dictionary = seat.levels if own else road_card_levels
	var room: int = Balance.AUGMENT_SEAT_HAND if own else Balance.ROAD_CARD_HAND
	# **Taking a held card levels it** (augments, 2026-09-26). A card that moves a
	# fraction grows I to V; one at its last level, or one that moves a whole
	# number of things, cannot be taken again.
	if hand.has(card_id):
		var level: int = maxi(1, int(levels.get(card_id, 1)))
		if level >= card.max_level():
			return ""
		levels[card_id] = level + 1
		Modifiers.rebuild()
		EventBus.augment_hand_changed.emit()
		return ""
	var replaced: String = ""
	# **One keystone in a hand** (2026-09-25): a second replaces the first,
	# whatever it re-routes, so a hand is never a stack of mechanics.
	if card.keystone:
		for held: String in hand:
			var kept: RoadCardData = ContentDB.road_card(held)
			if kept != null and kept.keystone:
				replaced = held
				break
	# **An evolution takes its weapon's place** (2026-09-27), in the same slot,
	# so evolving never asks the player to give up a second card for it.
	if not card.evolves_from.is_empty() and hand.has(card.evolves_from):
		replaced = card.evolves_from
	for held: String in hand:
		if not replaced.is_empty():
			break
		var other: RoadCardData = ContentDB.road_card(held)
		if other != null and other.key() == card.key():
			replaced = held
			break
	if replaced.is_empty() and hand.size() >= room:
		if not hand.has(drop):
			return ""
		replaced = drop
	var inherited: int = 1
	if not replaced.is_empty():
		# **A better card for a key already held keeps the levels the old one
		# grew.** Rarity is an upgrade path and so are levels; if taking the
		# better card cost the levels, it would be the worse pick.
		var old: RoadCardData = ContentDB.road_card(replaced)
		if old != null and old.key() == card.key():
			inherited = maxi(1, int(levels.get(replaced, 1)))
		hand.erase(replaced)
		levels.erase(replaced)
	hand.append(card_id)
	levels[card_id] = clampi(inherited, 1, card.max_level())
	Modifiers.rebuild()
	EventBus.augment_hand_changed.emit()
	return replaced


## The level a held card has grown to, or 0 for a card not in the hand - the
## party's board, or this Warden's own cards in a split hand.
func card_level(card_id: String) -> int:
	if road_cards.has(card_id):
		return maxi(1, int(road_card_levels.get(card_id, 1)))
	if hands_split:
		return _mine.card_level(card_id)
	return 0


## Whether this Warden holds a card, on the board or in their own hand.
func holds_card(card_id: String) -> bool:
	return road_cards.has(card_id) or (hands_split and _mine.cards.has(card_id))


## Every card a seat draws against and sees: the whole hand alone, and in a
## split hand the party's board and the seat's own cards.
func hand_of(seat: AugmentSeat = null) -> Array[String]:
	var who: AugmentSeat = seat if seat != null else _mine
	var out: Array[String] = road_cards.duplicate()
	if hands_split:
		out.append_array(who.cards)
	return out


func levels_of(seat: AugmentSeat = null) -> Dictionary:
	var who: AugmentSeat = seat if seat != null else _mine
	var out: Dictionary = road_card_levels.duplicate()
	if hands_split:
		for id: String in who.cards:
			out[id] = who.card_level(id)
	return out


## The hand a card would go into for this Warden: the board, or their own.
func target_hand(card: RoadCardData) -> Array[String]:
	if card != null and hands_split and Augments.seat_keeps(card):
		return _mine.cards
	return road_cards


## Whether taking this card means choosing one to leave, for this Warden.
func hand_is_full_for(card: RoadCardData) -> bool:
	var room: int = Balance.AUGMENT_SEAT_HAND \
		if card != null and hands_split and Augments.seat_keeps(card) else Balance.ROAD_CARD_HAND
	return target_hand(card).size() >= room


## The seat a slot's Warden drafts from: this machine's own, or on the host a
## guest's, made the first time it is asked for.
func augment_seat(slot: int) -> AugmentSeat:
	if slot <= 0 or slot == _my_slot():
		return _mine
	if not augment_seats.has(slot):
		augment_seats[slot] = AugmentSeat.new(slot)
	return augment_seats[slot] as AugmentSeat


## This machine's seat: 1 alone, the assigned seat in company.
func _my_slot() -> int:
	if get_node_or_null(^"/root/Coop") == null:
		return 1
	return maxi(Coop.party().slot(), 1)


## A road splits the hand when it is played in company. Asked of the tree rather
## than of the autoload's name, because `reset` also runs from `_ready`, before
## every autoload after this one has arrived.
func _session_splits_hands() -> bool:
	return get_node_or_null(^"/root/Coop") != null and Coop.is_networked()


## Every tag the Warden already holds - on the cards in the hand and on the
## Disciplines learned - so the deck can lean toward a build being made.
func augment_lean_tags(seat: AugmentSeat = null) -> Array[String]:
	var who: AugmentSeat = seat if seat != null else _mine
	var tags: Array[String] = []
	for held: String in hand_of(who):
		var card: RoadCardData = ContentDB.road_card(held)
		if card == null:
			continue
		for tag: String in card.tags:
			if not tags.has(tag):
				tags.append(tag)
	# A guest's seat is told its Warden's tags with the sheet (`CoopHeroes`);
	# this machine's Warden reads its own account.
	if who != _mine:
		for tag: String in who.learned_tags:
			if not tags.has(tag):
				tags.append(tag)
		return tags
	for id: String in learned_disciplines():
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if node == null:
			continue
		for tag: String in node.tags:
			if not tags.has(tag):
				tags.append(tag)
	return tags


## Road experience a road rank costs, from the rank being left.
static func road_rank_cost(rank: int) -> float:
	return Balance.ROAD_RANK_BASE + Balance.ROAD_RANK_STEP * float(maxi(rank, 0))


## **The road rank grows.** Every kill on the road pays into it, and each rank it
## crosses banks a draft. The host keeps the party's rank; a guest is told it
## with the hand, and the Walk earns nothing because nothing on it is kept.
func gain_road_xp(amount: float) -> void:
	if amount <= 0.0 or walking or Coop.is_guest():
		return
	road_xp += amount
	while road_xp >= road_rank_cost(road_rank):
		road_xp -= road_rank_cost(road_rank)
		road_rank += 1
		EventBus.road_rank_gained.emit(road_rank)
		queue_augment(Augments.SOURCE_RANK)
	EventBus.road_xp_changed.emit(road_xp / road_rank_cost(road_rank))


## Banks a draft from `source`, dealt when it is opened.
func queue_augment(source: String) -> void:
	if walking or Coop.is_guest():
		return
	augment_queue.append({"source": source, "floor": Augments.floor_for(source)})
	EventBus.augment_queued.emit(source, augment_queue.size())
	# **Every seat drafts** (per-Warden hands, 2026-09-26). The rank is the
	# party's, as Vampire Survivors' co-op shares one bar; what each rank deals
	# is every Warden's own.
	if hands_split:
		for slot: int in _guest_slots():
			var seat: AugmentSeat = augment_seat(slot)
			seat.queue.append({"source": source, "floor": Augments.floor_for(source)})
			deal_next_for(seat)
			_tell_seat(seat)


## The guests' slots on this road, host side.
func _guest_slots() -> Array[int]:
	var out: Array[int] = []
	if get_node_or_null(^"/root/Coop") == null:
		return out
	for value: Variant in Coop.party().seats():
		var person := value as CoopParty.Seat
		if person != null and person.slot > 0 and person.slot != _my_slot() \
				and not out.has(person.slot):
			out.append(person.slot)
	return out


## Tells a guest its own seat, whole, so its draft screen shows what the host
## dealt it. Through the bus, which the relay addresses to that guest alone.
func _tell_seat(seat: AugmentSeat) -> void:
	if seat == _mine or not Coop.is_host():
		return
	EventBus.augment_seat_told.emit(seat.slot, seat.pack())


## How many drafts wait, counting the one on the table.
func augments_waiting() -> int:
	return augment_queue.size()


## **Deals the oldest banked draft onto the table**, unless one is already there.
## A draft the deck cannot fill is turned into a reroll rather than lost, which
## is what a hand at its last levels meets. Returns whether a draft is on it.
func deal_next_augment() -> bool:
	# A guest's draft is dealt by the host and told to it (`_on_coop_augment_seat`).
	if Coop.is_guest():
		return not augment_offer.is_empty()
	return deal_next_for(_mine)


func deal_next_for(seat: AugmentSeat) -> bool:
	if not seat.offer.is_empty():
		return true
	while not seat.queue.is_empty():
		var entry: Dictionary = seat.queue[0]
		var source: String = String(entry.get("source", ""))
		var drawn: Array[String] = Augments.deal_for(source, int(entry.get("floor", 0)),
			[], Balance.ROAD_CARD_OFFER_COUNT, seat)
		if drawn.is_empty():
			seat.queue.pop_front()
			seat.rerolls = mini(seat.rerolls + 1, Balance.AUGMENT_REROLLS_MAX)
			continue
		seat.offer = drawn
		seat.source = source
		if seat == _mine:
			EventBus.augment_offer_changed.emit()
		return true
	return false


## **Takes one card from the draft on the table.** `drop` is as for
## `take_road_card`: the card to leave when a new key meets a full hand. A
## Tempering levels the card named and deals nothing new. Returns whether it was
## taken; a refusal leaves the draft exactly where it was.
func resolve_augment(card_id: String, drop: String = "") -> bool:
	if Coop.is_guest():
		return _ask_the_host("take", card_id, drop)
	return resolve_for(_mine, card_id, drop)


func resolve_for(seat: AugmentSeat, card_id: String, drop: String = "") -> bool:
	if not seat.offer.has(card_id):
		return false
	var card: RoadCardData = ContentDB.road_card(card_id)
	var own: bool = card != null and hands_split and Augments.seat_keeps(card)
	var levels: Dictionary = seat.levels if own else road_card_levels
	var hand: Array[String] = seat.cards if own else road_cards
	var held: bool = hand.has(card_id)
	if seat.source == Augments.SOURCE_TEMPERING and not held:
		return false
	var before: int = maxi(1, int(levels.get(card_id, 1))) if held else 0
	take_card_for(seat, card_id, drop)
	var after: int = maxi(1, int(levels.get(card_id, 1))) if hand.has(card_id) else 0
	if not hand.has(card_id) or (held and after <= before):
		return false
	# The luck a clean road banked is spent on the draft it improved.
	seat.luck = 0
	_close_draft_of(seat)
	if seat == _mine:
		EventBus.augment_taken.emit(card_id, after)
	return true


## **A guest's draft door**: the choice is the host's to make real, asked by
## card id and never by what it is worth - the rule the fish, the crops and the
## eggs are asked under. Nothing changes here: the host answers every choice,
## a refusal included, with the seat told whole (`adopt_augment_seat`), and the
## draft screen waits for that answer as the crossroad's own request does.
func _ask_the_host(verb: String, card_id: String = "", drop: String = "") -> bool:
	if augment_offer.is_empty() or (verb == "take" and not augment_offer.has(card_id)):
		return false
	EventBus.augment_choice_asked.emit(verb, card_id, drop)
	return true


## **Deals the draft again**, for a reroll. Another three where the deck allows,
## the same ones back only where it does not.
func reroll_augment() -> bool:
	if Coop.is_guest():
		return augment_rerolls > 0 and _ask_the_host("reroll")
	return reroll_for(_mine)


func reroll_for(seat: AugmentSeat) -> bool:
	if seat.offer.is_empty() or seat.rerolls <= 0 or seat.queue.is_empty():
		return false
	var entry: Dictionary = seat.queue[0]
	var drawn: Array[String] = Augments.deal_for(seat.source,
		int(entry.get("floor", 0)), seat.offer, Balance.ROAD_CARD_OFFER_COUNT, seat)
	if drawn.is_empty():
		return false
	seat.rerolls -= 1
	seat.offer = drawn
	if seat == _mine:
		EventBus.augment_offer_changed.emit()
	return true


## **Banishes a card for the rest of the road**, and deals its place again. A
## Tempering deals only what is held, so it has nothing to banish.
##
## **A card already in the hand may be banished from the deck** (owner,
## 2026-09-30: *"Banishing an arsenal roll will not let players rebanish that
## same slot offer's new offer"*). The deal offers a held card to level it,
## and this refused to banish one - in silence - so the replacement dealt into
## a banished card's place could not be banished whenever it was a level-up.
## The hand keeps the card at the level it has; what leaves is its place in
## the deck for this road, which is the player's own choice about a card they
## do not want offered again.
func banish_augment(card_id: String) -> bool:
	if Coop.is_guest():
		return augment_offer.has(card_id) and augment_banishes > 0 \
			and _ask_the_host("banish", card_id)
	return banish_for(_mine, card_id)


func banish_for(seat: AugmentSeat, card_id: String) -> bool:
	if not seat.offer.has(card_id) or seat.banishes <= 0 or seat.queue.is_empty() \
			or seat.source == Augments.SOURCE_TEMPERING:
		return false
	seat.banishes -= 1
	seat.banished.append(card_id)
	var at: int = seat.offer.find(card_id)
	var entry: Dictionary = seat.queue[0]
	var again: Array[String] = Augments.deal_for(seat.source,
		int(entry.get("floor", 0)), seat.offer, 1, seat)
	if again.is_empty() or seat.offer.has(again[0]):
		seat.offer.remove_at(at)
	else:
		seat.offer[at] = again[0]
	if seat.offer.is_empty():
		_close_draft_of(seat)
	if seat == _mine:
		EventBus.augment_hand_changed.emit()
		EventBus.augment_offer_changed.emit()
	return true


## **Passes on a draft**, banking a reroll for a later one.
func skip_augment() -> bool:
	if Coop.is_guest():
		return not augment_offer.is_empty() and _ask_the_host("skip")
	return skip_for(_mine)


func skip_for(seat: AugmentSeat) -> bool:
	if seat.offer.is_empty():
		return false
	seat.rerolls = mini(seat.rerolls + 1, Balance.AUGMENT_REROLLS_MAX)
	_close_draft_of(seat)
	return true


func _close_augment_draft() -> void:
	_close_draft_of(_mine)


func _close_draft_of(seat: AugmentSeat) -> void:
	seat.offer = []
	seat.source = ""
	if not seat.queue.is_empty():
		seat.queue.pop_front()
	if seat == _mine:
		EventBus.augment_offer_changed.emit()


## A wave began: the wall's count is noted, so the end can tell a clean wave.
func note_augment_wave_started() -> void:
	_augment_wave_hits = town_hits_taken


## **A wave ended.** A wave the wall was never struck in is luck toward the
## next draft, and every `AUGMENT_HOLDFAST_WAVES` survived is a Tempering.
func note_augment_wave_cleared() -> void:
	if walking or Coop.is_guest():
		return
	if town_hits_taken == _augment_wave_hits:
		augment_luck = mini(augment_luck + 1, Balance.AUGMENT_LUCK_CAP)
		for key: Variant in augment_seats:
			var seat: AugmentSeat = augment_seats[key] as AugmentSeat
			seat.luck = mini(seat.luck + 1, Balance.AUGMENT_LUCK_CAP)
	_augment_wave_hits = town_hits_taken
	augment_waves_toward_tempering += 1
	if augment_waves_toward_tempering >= Balance.AUGMENT_HOLDFAST_WAVES:
		augment_waves_toward_tempering = 0
		queue_augment(Augments.SOURCE_TEMPERING)


func _on_boss_for_augments(_boss_id: String, _act: int) -> void:
	queue_augment(Augments.SOURCE_BOSS)


func _on_camp_for_augments(lane: int, tier: int) -> void:
	note_camp_augment(lane, tier)


## A raid brought something back: a partial extraction counts, a death does not.
func _on_raid_for_augments(reward: Dictionary) -> void:
	if not bool(reward.get("died", false)):
		queue_augment(Augments.SOURCE_RAID)


## One draft a rift or dungeon, when its last stage falls - a dungeon of five
## stages is one detour, not five drafts.
func _on_rift_for_augments(stage: int, stages: int) -> void:
	if stage >= stages:
		queue_augment(Augments.SOURCE_RIFT)


## A legend of the trail, brought down. The rarest thing on the road deals the
## rarest draft.
func _on_wildlife_for_augments(kind_id: String, _food: int, _at: Vector2,
		_rarity: int, _shiny: bool, _grave: bool) -> void:
	var kind: WildlifeData = ContentDB.wildlife_kind(kind_id)
	if kind != null and kind.mythic:
		queue_augment(Augments.SOURCE_MYTHIC)


func _on_coop_augment_hand(ids: Array, levels: Array, banished: Array, rank: int) -> void:
	if Coop.is_guest():
		adopt_augment_hand(ids, levels, banished, rank)


## **The host told this guest its own seat**: the draft it was dealt, its tools,
## and its own cards. Applied whole, like the hand, so a guest's draft can never
## drift from the host's by a missed message.
func _on_coop_augment_seat(packed: Dictionary) -> void:
	if not Coop.is_guest():
		return
	adopt_augment_seat(packed)


## **A partner's own cards, told to this guest** (the Arsenal, 2026-09-27), so
## the Arsenal at that partner's side draws here too. Never this machine's own
## seat, which the host tells whole (`adopt_augment_seat`), and never a card
## this build does not have. A picture only: a guest's bodies refuse the blows.
func _on_coop_arsenal_seat(slot: int, cards: Array, levels: Array) -> void:
	if not Coop.is_guest():
		return
	adopt_arsenal_seat(slot, cards, levels)


func adopt_arsenal_seat(slot: int, cards: Array, levels: Array) -> void:
	if slot < 1 or slot > Balance.COOP_MAX_PLAYERS or slot == _my_slot():
		return
	var seat: AugmentSeat = augment_seat(slot)
	seat.cards.clear()
	seat.levels.clear()
	for index: int in cards.size():
		var id: String = String(cards[index]) if cards[index] is String else ""
		var card: RoadCardData = ContentDB.road_card(id)
		if card == null or seat.cards.has(id) or seat.cards.size() >= Balance.AUGMENT_SEAT_HAND:
			continue
		seat.cards.append(id)
		var level: int = int(levels[index]) if index < levels.size() else 1
		seat.levels[id] = clampi(level, 1, card.max_level())
	# The partner's Arsenal re-reads its cards on this, as it does on a draft.
	EventBus.augment_hand_changed.emit()


func adopt_augment_seat(packed: Dictionary) -> void:
	var told: AugmentSeat = AugmentSeat.unpack(packed)
	var waiting_before: int = augment_queue.size()
	told.slot = _mine.slot
	told.learned_tags = _mine.learned_tags
	_mine = told
	Modifiers.rebuild()
	EventBus.augment_hand_changed.emit()
	EventBus.augment_offer_changed.emit()
	if augment_queue.size() > waiting_before and not augment_queue.is_empty():
		EventBus.augment_queued.emit(String(augment_queue[augment_queue.size() - 1].get("source", "")),
			augment_queue.size())


## **A guest's choice, on the host.** Attributed by the peer it arrived on -
## never by a slot inside it - and carried out through the same door this
## machine's own draft uses, against that seat's own offer. Whatever happened,
## the seat is told back whole, so a refused choice reopens the same draft.
func _on_coop_augment_request(kind: int, args: Array, from: int) -> void:
	if kind != CoopRelay.Request.AUGMENT_CHOICE or not Coop.is_host() or not hands_split:
		return
	var slot: int = Coop.party().slot_for_peer(from)
	if slot <= 0 or slot == _my_slot() or args.size() < 3:
		return
	var seat: AugmentSeat = augment_seat(slot)
	var verb: String = String(args[0]) if args[0] is String else ""
	var card_id: String = String(args[1]) if args[1] is String else ""
	var drop: String = String(args[2]) if args[2] is String else ""
	match verb:
		"take":
			resolve_for(seat, card_id, drop)
		"reroll":
			reroll_for(seat)
		"banish":
			banish_for(seat, card_id)
		"skip":
			skip_for(seat)
	deal_next_for(seat)
	_tell_seat(seat)


func _on_wave_for_augments(_wave: int, _lanes: Array) -> void:
	note_augment_wave_started()


func _on_wave_cleared_for_augments(_wave: int) -> void:
	note_augment_wave_cleared()


## A camp fell. The first camp razed in an act deals a draft and the rest are
## fights: twelve camps an act would be twelve drafts, which is a detour worth
## more than the road. Returns whether it dealt.
func note_camp_augment(_lane: int, _tier: int) -> bool:
	var key: String = str(act)
	if augment_camps_drafted.has(key) or walking or Coop.is_guest():
		return false
	augment_camps_drafted.append(key)
	queue_augment(Augments.SOURCE_CAMP)
	return true


## **The host's hand, as a guest holds it** (co-op phase A: one hand for the
## party, drafted by the host). Applied whole rather than as a take, so a
## guest's hand cannot drift from the host's by a missed message.
func adopt_augment_hand(ids: Array, levels: Array, banished: Array, rank: int) -> void:
	road_cards = []
	road_card_levels = {}
	for index: int in ids.size():
		var id: String = String(ids[index])
		var card: RoadCardData = ContentDB.road_card(id)
		if card == null or road_cards.has(id) or road_cards.size() >= Balance.ROAD_CARD_HAND:
			continue
		road_cards.append(id)
		var level: int = int(levels[index]) if index < levels.size() else 1
		road_card_levels[id] = clampi(level, 1, card.max_level())
	augment_banished = []
	for id: Variant in banished:
		if ContentDB.road_card(String(id)) != null:
			augment_banished.append(String(id))
	road_rank = maxi(rank, 0)
	Modifiers.rebuild()
	EventBus.augment_hand_changed.emit()


## True when taking a new-key card would cost the player one they hold.
func road_card_hand_is_full() -> bool:
	return road_cards.size() >= Balance.ROAD_CARD_HAND


## Maximum tower level the current Forge tier supports. Tier 0 permits the
## opening three levels; each Forge tier opens the next band.
func tower_level_cap() -> int:
	return clampi(Balance.tower_level_cap_for_forge(building_tier("forge")),
		Balance.TOWER_BASE_LEVEL_CAP, Balance.TOWER_MAX_LEVEL)


## Resource yield per distance unit, after Granary tiers and captive labour.
func production_rate(currency_id: String) -> float:
	var building_id: String = "woodcutter" if currency_id == WOOD else "granary"
	if currency_id != WOOD and currency_id != FOOD:
		return 0.0
	var producer: BuildingData = ContentDB.building(building_id)
	var rate: float = producer.effect_at(building_tier(building_id)) \
		if producer != null else 0.0
	rate += assigned_captive_work() * Balance.CAPTIVE_WORK_BONUS \
		* Modifiers.multiplier(Modifiers.CAPTIVE_OUTPUT)
	return rate * Modifiers.multiplier(Modifiers.RESOURCE_RATE)


## v3 compatibility: passive "resources" means the combined basic production.
func resource_rate() -> float:
	return production_rate(WOOD) + production_rate(FOOD)


## Everything the town's trade layer does at the top of a Preparation.
##
## Renamed from `begin_preparation_trade` when merchants arrived: the Market is
## now one of two things that reset on this beat, and a function called after
## only one of them is a name that will be wrong again the next time.
func begin_preparation_trade() -> void:
	market_trades_remaining = Balance.MARKET_TRADES_PER_PREPARATION
	MerchantYard.begin_preparation()


func market_service_bought_this_act() -> bool:
	return market_service_act == act


func building_tier(id: String) -> int:
	return int(building_tiers.get(id, 0))


func assigned_captive_count() -> int:
	return captive_assignments.size()


## The work the assigned leaders actually do, as a count of standard shifts.
##
## `CaptiveData.work_multiplier` was authored - a Glass-born at 1.2, a Steppe
## Horde leader at 1.4 - and read by nothing, so production counted *heads*
## and every leader was worth the same shift. Which leader you won from a raid
## decided nothing at all.
##
## The default is 1.0 and that is what a leader authoring nothing contributes,
## so this changes no existing number: it only lets the ones written down as
## better actually be better.
func assigned_captive_work() -> float:
	var shifts: float = 0.0
	for captive_id: Variant in captive_assignments:
		var who: CaptiveData = ContentDB.captive(String(captive_id))
		shifts += maxf(who.work_multiplier, 0.0) if who != null else 1.0
	return shifts


## Relic sockets available: Town Hall tier plus the one meta bonus.
func relic_slot_count() -> int:
	var tier: int = building_tier("town_hall")
	var base: int = Balance.TOWN_HALL_RELIC_SLOTS[clampi(tier - 1, 0, Balance.TOWN_HALL_RELIC_SLOTS.size() - 1)] if tier > 0 else 0
	return base + MetaState.bonus_relic_slots()


## Multiplier applied to enemy HP and damage from accumulated horn uses.
func enemy_escalation_multiplier() -> float:
	return 1.0 + float(war_horn_uses) * Balance.WAR_HORN_ESCALATION_PER_USE


func enemies_are_weakened() -> bool:
	return weakened_until > 0.0


func active_road() -> RoadData:
	return ContentDB.road(active_road_id)


func active_road_difficulty() -> RoadDifficultyData:
	return ContentDB.road_difficulty(active_road_difficulty_id)


## Total journey progress, 0..1.
func journey_ratio() -> float:
	return clampf(distance_travelled / Balance.JOURNEY_TOTAL_DISTANCE, 0.0, 1.0)


## Distance at which this act ends and its boss walks in.
func act_boss_distance() -> float:
	return Balance.act_end_distance(act)


## How far the beast still has to walk before the act boss appears. This was
## invisible, which made a correctly-working boss trigger look like a bug: with
## nothing on screen counting down, "wave 33 and no boss" reads as broken rather
## than as "still 600 units out".
func distance_to_boss() -> float:
	return maxf(act_boss_distance() - distance_travelled, 0.0)


## 0..1 progress through the current act.
func act_progress() -> float:
	var start: float = Balance.act_start_distance(act)
	var length: float = maxf(Balance.act_end_distance(act) - start, 1.0)
	return clampf((distance_travelled - start) / length, 0.0, 1.0)


## Distance remaining until the next crossroad.
func distance_to_crossroad() -> float:
	var next_boundary: float = (floorf(distance_travelled / Balance.SEGMENT_DISTANCE) + 1.0) * Balance.SEGMENT_DISTANCE
	var remaining: float = maxf(next_boundary - distance_travelled, 0.0)
	var road: RoadData = active_road()
	return remaining * (road.distance_scale if road != null else 1.0)


func record_wave_archetype(id: String) -> void:
	if id.is_empty():
		return
	wave_archetype_counts[id] = int(wave_archetype_counts.get(id, 0)) + 1


func most_common_wave_archetype() -> String:
	var best_id: String = ""
	var best_count: int = 0
	for key: Variant in wave_archetype_counts:
		var count: int = int(wave_archetype_counts[key])
		if count > best_count:
			best_count = count
			best_id = String(key)
	return best_id


## True while the run is climbing to the summit, past the last act.
func is_final_ascent() -> bool:
	return act >= Balance.FINAL_ASCENT_ACT


## Distance at which the Chainmaker is due.
func final_ascent_target() -> float:
	return Balance.JOURNEY_TOTAL_DISTANCE + Balance.FINAL_ASCENT_DISTANCE


## Leaves the campaign behind and starts the climb.
##
## The ascent has ground of its own since 2026-09-21 (`terrains/crown.tres`,
## authored at `FINAL_ASCENT_ACT`), so the road changes region here exactly as
## `Journey.resume_after_boss` changes it between acts. A build without that
## terrain keeps the Terrace underfoot, which is what the ascent always was.
func begin_final_ascent() -> void:
	act = Balance.FINAL_ASCENT_ACT
	var summit: TerrainData = ContentDB.terrain_for_act(Balance.FINAL_ASCENT_ACT)
	if summit != null:
		terrain_id = summit.id
	set_phase(Phase.FINAL_ASCENT)


# --- Carried consumables -----------------------------------------------------
#
# `ItemData` promised that "a second consumable is a new file rather than
# another branch", and until now that was not true: the Draught's entire
# behaviour was one bool, read by an `if item_id == "resurrection_draught"`.
# These five functions are what make the promise good.

func item_count(item_id: String) -> int:
	return int(held_items.get(item_id, 0))


## Whether there is room for one more, against that item's own carry limit.
func can_take_item(item_id: String) -> bool:
	var kind: ItemData = ContentDB.item(item_id)
	if kind == null:
		return false
	return item_count(item_id) < maxi(kind.carry_limit, 1)


## Takes one if there is room. Returns whether it was taken, so the caller can
## decide whether to announce it - a reward silently discarded for being at the
## carry limit is worse than one that was never offered.
func take_item(item_id: String) -> bool:
	if not can_take_item(item_id):
		return false
	held_items[item_id] = item_count(item_id) + 1
	EventBus.items_changed.emit()
	return true


## Spends one. Returns whether there was one to spend.
func spend_item(item_id: String) -> bool:
	if item_count(item_id) <= 0:
		return false
	var left: int = item_count(item_id) - 1
	if left <= 0:
		held_items.erase(item_id)
	else:
		held_items[item_id] = left
	EventBus.items_changed.emit()
	return true


## The first held item with a given effect, or null.
##
## By effect rather than by id, which is the whole point: the hero asks "do I
## hold anything that stops a death" and never learns what a Draught is. A
## second revive item is then a file.
func item_with_effect(effect: int, automatic_only: bool = false) -> ItemData:
	var ids: Array = held_items.keys()
	ids.sort()
	for id: Variant in ids:
		var kind: ItemData = ContentDB.item(String(id))
		if kind == null or int(kind.effect) != effect:
			continue
		if automatic_only and not kind.automatic:
			continue
		return kind
	return null


# --- The companion's larder (2026-09-13) --------------------------------------------------

## Whether the bonded spirit is out. Run scoped: a new road starts with the
## companion called if the larder can pay for it, and a player who sent it
## away has sent it away for this run.
var spirit_called: bool = true

## **Whether the animal taken out of the pen went down on this road.**
##
## A bonded *spirit* re-forms - that is what `SpiritBond.recovery_seconds` is for
## and it has been the design since companions were un-cut. A **raised** animal
## does not: it is one particular creature rather than an entry in a collection,
## and the whole stake of taking one out is that it might not come back. Run
## scoped; `MetaState` decides what it means when the run ends.
var pen_companion_fell: bool = false

## **How far the party has pushed since it last banked**, as a fraction.
##
## Raised at each crossroads passed without extracting, cleared when one is
## taken. Read by `Modifiers` into discovery keys only - see
## `Balance.MOMENTUM_PER_CROSSROAD` for why it may never reach a damage number.
var momentum: float = 0.0

## **The acts whose wayside encounter has been answered this run** (2026-09-25).
## An encounter is re-laid from the run's seed whenever the region is, so a
## front banked at a crossroad and resumed would lay an answered one again -
## and bank, resume, answer, bank is a loop that farms gear and sightings.
## Banked with the front (`Expedition`), and `Wayside.may_lay` refuses an act on
## it. Road data, never the account: it resets with the run.
var wayside_answered: Array[int] = []


## **True while the road behind the party is closing** (2026-09-16).
##
## Set for the length of the withdrawal that a return now runs, and read by
## exactly two things: `WaveDirector._road_waves_allowed`, so an ordinary
## formation cannot start underneath the last one, and `Withdrawal` itself.
##
## Run-scoped and never relayed. A guest runs no waves and settles no run, so
## there is nothing for its copy to decide; the bodies reach it as the same
## spawn facts every other body does.
var withdrawing: bool = false


## **May this run still end in defeat?**
##
## False for exactly as long as a withdrawal runs, and it is the same bound
## `Balance.HOMECOMING_WALL_FLOOR` is, arriving through the other door: the town
## cannot fall on the way out, and neither can the party. A Warden on their last
## Wound who goes down during the walk out would otherwise lose the return they
## had already chosen *and* the front it was about to bank - `bank_the_front` is
## reached from `return_home` and from nowhere else, so a run that ends any other
## way banks nothing.
##
## Asked at the two doors that end a run in defeat - a solo death past the last
## Wound, and a co-op team wipe past it - rather than decided at either, so the
## rule has one home and reversing it is one line.
func run_may_be_lost() -> bool:
	return not withdrawing

## **How hurt each restored tower should stand up.**
##
## Tower health lives on the node rather than here - it has never crossed the
## wire and still does not - so a snapshot has nowhere to put it except a place
## the node can read once as it is built. Keyed by anchor, consumed by
## `Tower._ready`, and empty for every tower that was not restored.
var tower_health_restore: Dictionary = {}

## The doctrine a road started at a later act still owes its board to.
##
## **Read once and erased**, which is the pattern `tower_health_restore`
## above already sets: a board built twice is a doctrine worth twice as
## much, and a field can be stood up more than once in a process - a
## re-sync, a guest's welcome, a gate that runs two runs.
##
## Run-scoped like everything else here. Nothing about starting at an act
## reaches `MetaState`: which acts are open is derived from
## `best_distance`, so working rule 7 is exactly where it was.
var pending_outfit: Dictionary = {}
## The fraction of a Food unit the companion has eaten but not yet been
## charged, so a slow drain is a drain rather than a rounding error.
var spirit_upkeep_carry: float = 0.0
## Seconds a fed spirit is not hungry for. A meal buys a while out.
var spirit_full_left: float = 0.0


## What this spirit eats a minute: its own size, and its own rarity.
##
## A bear eats like a bear, and a Legendary eats like the stronger animal it
## is - see `Balance.COMPANION_UPKEEP_BY_RARITY`. The rarity is read off the
## equipped bond rather than off the form, because the form is the species and
## the rarity is the *variant*; `rarity` may be handed in so the Codex can
## print the whole ladder for a species nobody has bonded yet.
func spirit_upkeep(kind: CompanionData, rarity: int = -1) -> float:
	if kind == null:
		return Balance.COMPANION_UPKEEP_PER_MINUTE
	var share: float = 1.0
	for step: Vector2 in Balance.COMPANION_UPKEEP_BY_SCALE:
		if kind.scale >= step.x:
			share = step.y
	var rank: int = rarity
	if rank < 0:
		rank = SpiritBond.rarity_of(MetaState.equipped_spirit) \
			if not MetaState.equipped_spirit.is_empty() else 0
	var table: Array[float] = Balance.COMPANION_UPKEEP_BY_RARITY
	share *= table[clampi(rank, 0, table.size() - 1)]
	return Balance.COMPANION_UPKEEP_PER_MINUTE * share


## Calls the spirit out, if the larder can pay the meal it takes to do it.
## Returns why it could not, or "" on success.
func call_spirit() -> String:
	if MetaState.equipped_spirit.is_empty():
		return "No spirit is bonded."
	if spirit_called:
		return ""
	if currency(FOOD) < Balance.COMPANION_CALL_COST:
		return "Calling a spirit takes %d Food." % Balance.COMPANION_CALL_COST
	spend_cost({FOOD: Balance.COMPANION_CALL_COST})
	spirit_called = true
	spirit_upkeep_carry = 0.0
	EventBus.spirit_equipped.emit(MetaState.equipped_spirit)
	return ""


## Sends it home. Free, and immediate.
func send_spirit_away() -> void:
	if not spirit_called:
		return
	spirit_called = false
	spirit_upkeep_carry = 0.0
	EventBus.spirit_equipped.emit("")


## Eats. Called by the battlefield while a spirit is out; when the larder
## runs dry the spirit goes home rather than starving in place.
func tick_spirit_upkeep(kind: CompanionData, delta: float) -> void:
	if not spirit_called or kind == null:
		return
	if spirit_full_left > 0.0:
		spirit_full_left = maxf(spirit_full_left - delta, 0.0)
		return
	spirit_upkeep_carry += spirit_upkeep(kind) * delta / 60.0
	var whole: int = int(floor(spirit_upkeep_carry))
	if whole <= 0:
		return
	spirit_upkeep_carry -= float(whole)
	if currency(FOOD) < whole:
		send_spirit_away()
		EventBus.preparation_warning.emit("Your spirit went home: nothing left to feed it.")
		return
	spend_cost({FOOD: whole})


## A fed spirit stops eating for a while.
func feed_the_spirit(seconds: float) -> void:
	spirit_full_left = maxf(spirit_full_left, seconds)


# --- Dawn Bell's haste (2026-09-13) -------------------------------------------

## Hastens every tower for a while. `fraction` is how much faster, so 0.32 is a
## third quicker.
func haste_the_towers(fraction: float, seconds: float) -> void:
	if fraction <= 0.0 or seconds <= 0.0:
		return
	tower_haste_scale = 1.0 / (1.0 + fraction)
	tower_haste_left = maxf(tower_haste_left, seconds)


## What a tower's firing interval is multiplied by right now.
func tower_haste() -> float:
	return tower_haste_scale if tower_haste_left > 0.0 else 1.0


## Counted down by the battlefield, which is the thing that freezes for a raid.
func tick_tower_haste(delta: float) -> void:
	if tower_haste_left <= 0.0:
		return
	tower_haste_left = maxf(tower_haste_left - delta, 0.0)
	if tower_haste_left <= 0.0:
		tower_haste_scale = 1.0


# --- The Quartermaster (2026-09-13) -------------------------------------------

## What the next standing order costs. Geometric and unbounded on purpose: a
## sink with a ceiling stops being a sink the moment it is reached.
func quartermaster_price() -> int:
	return maxi(int(round(float(Balance.QUARTERMASTER_BASE_GOLD)
		* pow(Balance.QUARTERMASTER_STEP, float(quartermaster_orders)))), 1)


## Takes the price, or says why not. The caller does the work.
func pay_the_quartermaster() -> bool:
	var price: int = quartermaster_price()
	if not can_afford_cost({GOLD: price}):
		return false
	if not spend_cost({GOLD: price}):
		return false
	quartermaster_orders += 1
	return true


## Rearms every trap on the roads to its full count of triggers.
##
## Bought back rather than granted: a trap the player already laid and already
## paid for, returned to what it was. Returns how many were rearmed.
func rearm_the_traps(near: Vector2 = Vector2.INF, reach: float = 0.0) -> int:
	var rearmed: int = 0
	for key: Variant in traps:
		var tile: Vector2i = key as Vector2i
		# Only the traps near a place, when one is named (Sapper's Due,
		# 2026-09-25); every trap on the roads when it is not.
		if near != Vector2.INF and BattleGrid.tile_to_world(tile).distance_to(near) > reach:
			continue
		var entry: Dictionary = traps[tile]
		var kind: TrapData = ContentDB.trap(String(entry.get("trap_id", "")))
		if kind == null:
			continue
		var level: int = int(entry.get("level", 1))
		# The same arithmetic the level upgrade uses, so a raised trap is
		# rearmed to what it is now rather than to what it was when it was laid.
		var full: int = kind.triggers + Balance.TRAP_LEVEL_TRIGGERS[
			clampi(level - 1, 0, Balance.TRAP_LEVEL_TRIGGERS.size() - 1)]
		if int(entry.get("triggers_left", 0)) >= full:
			continue
		entry["triggers_left"] = full
		traps[tile] = entry
		EventBus.trap_changed.emit(tile)
		rearmed += 1
	return rearmed


func _on_construction_completed(building_id: String, _tier: int) -> void:
	if building_id == "sanctum":
		_sync_discipline_spells()
