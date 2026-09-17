extends Node

## Everything that survives death — and nothing else (GDD §7, §11 rule 5).
##
## The entire save schema is three things: unlocked ids, run statistics, and
## settings. Death wipes the run; clearing content only widens the pool of
## things that *can* appear next time. You start every run at zero power.
##
## If a field that is not one of those three shows up in a pull request here, a
## design decision has been violated. Flag it instead of implementing it.

const SAVE_PATH: String = "user://beast_road_save.json"

## Where a save of an unrecognised version is preserved before the game starts
## fresh. One per version, so a player who tries several builds keeps a copy of
## each rather than each overwriting the last.
const SAVE_BACKUP_PATH: String = "user://beast_road_save.v%d.bak.json"

## Where a save this build cannot even *parse* is preserved before the account
## starts fresh. Stamped with the time rather than a version, because a broken
## file has no version to read - and each one is kept, since the second corrupt
## copy tells support something the first did not.
const SAVE_UNREADABLE_BACKUP_PATH: String = "user://beast_road_save.unreadable.%d.bak.json"

## The sibling a save is written to before it replaces the real one. See
## `write_text_atomically` for why the save is never written in place.
const SAVE_TEMP_SUFFIX: String = ".tmp"

## Bumped when the schema changes so an old file can be migrated or discarded.
const SAVE_VERSION: int = 7

## Terrain ids as they were before v4's regions were adopted. A save records
## which terrains a player has unlocked *by id*, so renaming the content renames
## the save keys with it - and a v2 save would otherwise arrive holding three ids
## that no longer name anything, silently losing the unlocks.
## Save versions this build can carry forward. Anything else is backed up and
## the account starts fresh.
const MIGRATABLE_VERSIONS: Array[int] = [1, 2, 3, 4, 5, 6]

const TERRAIN_RENAMES_V3: Dictionary = {
	"ashfen": "jungle",
	"saltglass": "desert",
	"steppe": "snow",
}

## The save file was written or loaded.
signal save_written()
signal save_loaded()

# --- Unlock pool: ids only, never state ---
## Base towers the account may build. Seeded with the eight the game shipped
## with, so **every element and every fusion is reachable on run one** - v4 §3.4
## is explicit that the signature fusion system is not hidden behind progress.
##
## What unlocks is the *roster*: the eight later towers that widen each element
## from two roles to four (GDD §21, §35). Elements are never gated.
## The weapon the hero begins holding (owner decision, 2026-08-31).
##
## The blade the swing draws comes from the equipped weapon, and a new account
## equipped nothing - so the first fight of a new player's first run showed an
## empty-handed hero, and stayed that way until a boss dropped gear. The opening
## should show the weapon it is teaching you to use.
##
## **Granted once, not re-seeded like the towers.** A tower id is knowledge and
## cannot be sold; a weapon is an object with a sale price, so re-granting it on
## every launch would be a Marks printer. The flag below is what makes it once.
const STARTING_WEAPON: String = "coalpaint_edge"
const STARTING_GEAR_KEY: String = "starting_gear_granted"

const STARTING_TOWERS: Array[String] = [
	"ember_spire", "pyre_cannon",
	"rime_lance", "hoarfrost_bell",
	"bulwark", "shard_thrower",
	"arc_coil", "gale_turret",
]

## The roster order the later towers are earned in, bought with Tools at the end
## of a run (v4 §35). It was one per act boss felled, which paid a run that died
## in Act III the same as one that cleared it; Tools price depth instead. Still
## an authored order, so a new player meets one
## new tower at a time rather than sixteen at once.
const ROSTER_UNLOCK_ORDER: Array[String] = [
	"tide_caller", "grit_sling",
	"cinder_lance", "glacial_mortar",
	"stonewatch", "zephyr_needle",
	# One more each for earth and air (owner brief, 2026-09-12): the rail showed
	# five fire and five water towers against four of the other two.
	"rootcrusher", "thunderhead",
	"ashen_censer", "stormvane",
	# The eight of 2026-09-11, two per element in the same pairing the rest of
	# the ladder uses: a Warden and a Siege, then a Skirmisher and a Sniper -
	# each a combination the roster did not have rather than a bigger number.
	"cinder_moat", "rime_ward",
	"scree_gun", "squall_vane",
	"ash_thrower", "hailcaster",
	"barrow_stake", "gale_lance",
	# The five of 2026-09-14, to eight an element: the towers that work for
	# their neighbours, after every gun, and the kiln with them.
	"flash_kiln", "mason_shrine", "stillwater_mirror", "wind_relay", "bellows_forge",
	# The well is last on purpose. It is the only tower that does not shoot, and
	# a player offered one before they have learned what a road costs them will
	# read it as a worse gun rather than as a trade.
	"healing_well",
]

var unlocked_towers: Array[String] = []
var unlocked_relics: Array[String] = []
var unlocked_spells: Array[String] = []
var unlocked_terrains: Array[String] = []

## Recipes the player knows (owner decision, 2026-08-31).
##
## **In the `unlocked` block, because that is what a blueprint is.** Learning one
## is permanent knowledge, exactly like a tower or a spell becoming available -
## so it needs no new save shape and working rule 7 is untouched. A blueprint is
## never an item, never consumed, and never sits in a bag once read.
var unlocked_blueprints: Array[String] = []

## Everything the player has met, as "kind:id" - "enemy:bogkin", "affix:cruel".
##
## **In the `unlocked` block, because that is what a discovery is.** Having met a
## thing is permanent knowledge in exactly the way an unlocked tower is, so this
## needs no new save shape and working rule 7 is untouched. One flat list rather
## than a dictionary per kind: the codex reads it by prefix, and a new kind of
## discoverable costs nothing here.
var codex_seen: Array[String] = []

# --- The pantry ---------------------------------------------------------------

## Reads the larder back, dropping anything that no longer names a fish.
##
## Unknown ids are discarded rather than carried, which is the opposite of what
## the terrain migration does - and deliberately. A stale *unlock* is harmless
## and might name content that comes back; a stale consumable is a row in a list
## with no name, no icon and no effect, which a player would try to eat.
func _read_pantry(pantry: Dictionary) -> void:
	fish.clear()
	var stored: Variant = pantry.get("fish", {})
	if not (stored is Dictionary):
		return
	for key: Variant in (stored as Dictionary):
		var id: String = String(key)
		if ContentDB.fish(id) == null:
			continue
		var count: int = int((stored as Dictionary)[key])
		if count > 0:
			fish[id] = count


func fish_count(id: String) -> int:
	return int(fish.get(id, 0))


## How many fish are kept in total, against `Balance.FISH_STASH_CAPACITY`.
func fish_total() -> int:
	var held: int = 0
	for id: Variant in fish:
		held += int(fish[id])
	return held


## Keeps one. False when the larder is full, so the caller can say so rather
## than silently dropping a catch the player stood still for.
func take_fish(id: String) -> bool:
	if id.is_empty() or ContentDB.fish(id) == null:
		return false
	if fish_total() >= Balance.FISH_STASH_CAPACITY:
		return false
	fish[id] = fish_count(id) + 1
	RunState.note_kept("fish", 1.0)
	save_game()
	return true


## Eats one. False when there was none.
func spend_fish(id: String) -> bool:
	var held: int = fish_count(id)
	if held <= 0:
		return false
	if held <= 1:
		fish.erase(id)
	else:
		fish[id] = held - 1
	save_game()
	return true


# --- Professions --------------------------------------------------------------

## What the Warden has cut down and dug up, by `MaterialData.id`.
##
## **The newest kind of persistence, and the most tightly bounded.** CLAUDE.md
## §7 names what a save may hold; materials were added to it on 2026-09-13 with
## one rule: a material is an input to the Smithy and nothing else. It grants no
## attribute, buys no tower, pays no wave and does not exchange for a run
## currency. What it makes is gear, which is already on the capped scale
## levelling shares.
##
## A new account has none, which is the owner's own instruction and is also what
## makes the first geode mean something.
var materials: Dictionary = {}


## How many of one material are in the account's store.
func material_count(id: String) -> int:
	return int(materials.get(id, 0))


## Everything held, most valuable first, for the Smithy.
func materials_held() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for kind: MaterialData in ContentDB.materials_sorted():
		var held: int = material_count(kind.id)
		if held > 0:
			out.append({"id": kind.id, "count": held})
	return out


## Adds to the store. Refuses anything the content does not name, so a misspelt
## id cannot quietly create a material nothing can ever spend.
func gain_material(id: String, amount: int) -> bool:
	if amount <= 0 or ContentDB.material(id) == null:
		return false
	materials[id] = mini(material_count(id) + amount, Balance.MATERIAL_STACK_CEILING)
	RunState.note_kept("materials", float(amount))
	save_game()
	EventBus.materials_changed.emit()
	return true


## Takes from it. Returns false and changes nothing when there are not enough -
## the forge asks before it spends, and a partial spend would lose materials.
func spend_material(id: String, amount: int) -> bool:
	if amount <= 0 or material_count(id) < amount:
		return false
	var left: int = material_count(id) - amount
	if left > 0:
		materials[id] = left
	else:
		materials.erase(id)
	save_game()
	EventBus.materials_changed.emit()
	return true


## Reads the store back, keeping only ids the content names and counts that are
## counts. A save is a file on somebody's disk; everything in it is a claim.
func _read_materials(block: Dictionary) -> void:
	materials.clear()
	for key: Variant in block:
		var id: String = String(key)
		if ContentDB.material(id) == null:
			continue
		var held: int = int(block[key])
		if held > 0:
			materials[id] = mini(held, Balance.MATERIAL_STACK_CEILING)


## Reads the professions back, keeping only the ones the game names.
func _read_professions(block: Dictionary) -> void:
	profession_xp.clear()
	var stored: Variant = block.get("xp", {})
	if not (stored is Dictionary):
		return
	for key: Variant in (stored as Dictionary):
		var id: String = String(key)
		if not Balance.PROFESSIONS.has(id):
			continue
		var xp: float = maxf(float((stored as Dictionary)[key]), 0.0)
		if xp > 0.0:
			profession_xp[id] = minf(xp, profession_xp_to_cap())


## Experience needed to leave `level`.
static func profession_xp_to_leave(level: int) -> float:
	return Balance.PROFESSION_XP_BASE * pow(float(maxi(level, 1)), Balance.PROFESSION_XP_CURVE)


## The experience that reaches the cap; nothing past it is kept.
static func profession_xp_to_cap() -> float:
	var total: float = 0.0
	for level: int in range(1, Balance.PROFESSION_MAX_LEVEL):
		total += profession_xp_to_leave(level)
	return total


## The level a profession's experience amounts to, 1 at nothing.
func profession_level(id: String) -> int:
	var xp: float = float(profession_xp.get(id, 0.0))
	var level: int = 1
	# A hair of slack: the cap is a sum of these terms, and subtracting them
	# back one at a time lands a rounding error short of the last threshold.
	while level < Balance.PROFESSION_MAX_LEVEL and xp + 0.001 >= profession_xp_to_leave(level):
		xp -= profession_xp_to_leave(level)
		level += 1
	return level


## How far into the current level a profession is: (earned, needed). At the
## cap both are the last level's cost, so a bar drawn from them reads full.
func profession_progress(id: String) -> Vector2:
	var xp: float = float(profession_xp.get(id, 0.0))
	var level: int = 1
	while level < Balance.PROFESSION_MAX_LEVEL and xp + 0.001 >= profession_xp_to_leave(level):
		xp -= profession_xp_to_leave(level)
		level += 1
	if level >= Balance.PROFESSION_MAX_LEVEL:
		var last: float = profession_xp_to_leave(Balance.PROFESSION_MAX_LEVEL - 1)
		return Vector2(last, last)
	return Vector2(xp, profession_xp_to_leave(level))


## Trains a profession. Returns the level afterwards; announces a new one.
func gain_profession_xp(id: String, amount: int) -> int:
	if not Balance.PROFESSIONS.has(id) or amount <= 0:
		return profession_level(id)
	var before: int = profession_level(id)
	profession_xp[id] = minf(float(profession_xp.get(id, 0.0)) + float(amount),
		profession_xp_to_cap())
	RunState.note_kept("craft_xp", float(amount))
	var after: int = profession_level(id)
	if after > before:
		EventBus.profession_levelled.emit(id, after)
	save_game()
	return after


# --- Wildlife Spirit Companions ----------------------------------------------
#
# Owner decision, 2026-09-01. Every wildlife species can be bonded as a Spirit
# Companion at each rarity, and again as a Shiny of each; the progression is
# permanent and survives runs.
#
# **This is an amendment to working rule 7 and it is deliberate.** That rule
# lists exactly what may persist, and companion progression was not on it. The
# owner asked for a persistent collection system in detail, which is the same
# shape of decision as the hero re-cut on 2026-08-20 - so it is recorded in
# CLAUDE.md with its date rather than smuggled in here.
#
# **The bound that keeps it honest**: what persists is *which spirits you have
# met and bonded*, and nothing else. No spirit carries a level, no run currency
# is banked, and a bonded spirit is not stronger for having been owned longer -
# its power comes entirely from the variant's rarity, which is fixed the moment
# the animal was placed. Collection, not accumulation.

## Encounters banked per variant, keyed by `SpiritBond.key`. Uncapped counts are
## kept past the threshold: the journal shows "12 / 10" rather than pretending
## the last two sightings did not happen.
var spirit_encounters: Dictionary = {}

## Which variants are bonded. Derived from the counts, but stored, because the
## moment a bond completes is a thing to celebrate exactly once.
var spirit_bonded: Dictionary = {}

## The one spirit walking with the hero, as a `SpiritBond` key, or "".
##
## One slot to begin with, per the owner's brief. The storage is a single string
## rather than an array only because a second slot is a change to what is
## *equipped*, not to how a bond is earned - and the earning is the part that
## would be painful to migrate.
var equipped_spirit: String = ""

## **Living companions the Warden keeps**, each its own animal rather than an
## entry in a collection: `{uid, species, rarity, shiny, trait, born}`.
##
## **This is the amendment to working rule 7 that the pen makes**, and its bound
## is one sentence: **the bond is permanent and the animal is not.**
## `spirit_bonded` is the collection and nothing here touches it, so an animal
## dying on the road costs the player *that animal* and never a line in the
## journal - the same variant can be raised again. A penned animal grants no
## attribute, banks no currency, and is no stronger for having been kept longer;
## its power is its variant's rarity, fixed when it hatched, exactly as a bonded
## spirit's is.
##
## Additive, like the pantry, the spirits and the materials before it: a save
## written before the pen has no `pen` key and reads back as an empty pen, which
## is also what a new account is. `SAVE_VERSION` did not move.
var pen: Array[Dictionary] = []

## The uid of the one animal that is out of the pen and on the road, or empty.
## One at a time, which is the same bound `equipped_spirit` has had since the
## companions were un-cut: what §54 refuses is a *roster* the player commands.
var pen_taken: String = ""

## **The frontier the Warden can go back to.**
##
## One snapshot, written on a successful extraction and on nothing else. A wipe
## does *not* clear it, which is the whole anti-frustration rule: everything
## since the last crossroads is at risk and everything before it is banked, so
## pushing deeper is exciting rather than horrifying (owner ruling, 2026-09-15).
##
## **It carries no account progress.** No hero level, no gear, no attribute, no
## unlock - working rule 7's list is untouched. What it holds is *the road*: the
## seed, the act, the wave, the fortifications and the run's own purse, all of
## which already reset every run and none of which has ever been allowed to
## persist. That is not a loophole in the rule, it is a change to what a "run"
## is: an expedition is a run put down and picked up, and the thing that is now
## resumable is the *world* rather than the Warden.
##
## Additive: a save from before this has no `expedition` key and reads back as
## no frontier, which is what a new account is. `SAVE_VERSION` did not move.
var expedition: Dictionary = {}

## Milestone-gated construction pool. These are content permissions, not built
## tiers; every building still starts over each run.
var unlocked_buildings: Array[String] = []

## Treasury's one sanctioned carry-over. Capped per currency and consumed when
## the next run begins, so it cannot compound into permanent power.
var resource_cache: Dictionary = {}

## Set once Act 3 has been cleared. Worth exactly one extra starting Town Hall
## relic slot, capped at +1. This is the only sanctioned persistent power.
var act3_cleared: bool = false

## Tools: the account currency that widens what a run can contain (v4 §35).
## Earned by getting deep, spent on the roster. Never on power.
var tools: int = 0

# --- Hero progression (owner amendment, 2026-08-20) ---------------------------
#
# GDD §974 read "no hero level persists" through v4.0. The owner re-cut it: the
# game is now a multi-run climb through Normal, Nightmare and Hell, and a hero
# who resets every run cannot climb it. CLAUDE.md §7 carries the same amendment.
#
# What §974 was protecting is still protected. Growth is *capped* at
# HERO_MAX_LEVEL, so nothing unbounded persists, and the rest of the run - towers,
# relics, currencies, building tiers, Oathbound leaders - resets exactly as
# before. A player carries their hero forward, not their defence.

## The hero's level, experience and placed attributes, carried between runs.
var hero_level: int = 1
var hero_xp: float = 0.0
var hero_attributes: Array[int] = [0, 0, 0, 0, 0]
var hero_attribute_points: int = 0
var hero_skill_points: int = 0
## The Warden's ascension rank, 0 to `Balance.ASCENSION_MAX` (owner request,
## 2026-09-11). Prestige: a title, a portrait and a score multiplier, never
## power. See the note in Balance.
var ascension: int = 0

## Highest campaign tier order fully cleared. -1 means none, so only the first
## tier is open.
var tier_cleared: int = -1

## **Which rungs of the Gatekeeper's ladder are climbed, per difficulty.**
##
## Tier id -> stages cleared, 0 to `GatekeeperTrials.STAGES`. Added
## 2026-09-17 with the owner's ruling; the reasoning and the working-rule-7
## argument live on `GatekeeperTrials`, which is the only thing that writes it.
##
## A statistic in shape, like `best_distance` and `rifts_closed`: it grants no
## power of its own. What it decides is which trial is offered next and whether
## the Gatekeeper stands at that tier's summit. Additive - absent reads as an
## empty ladder, which is what a new account has.
var gatekeeper: Dictionary = {}

## **The Market's shelf**: what the vendor in the Hold has out, and when it
## was laid there.
##
## Added 2026-09-17 with the owner's vendor ruling. It is written to the save
## for one reason and it is the rule itself: a stock held in memory is
## re-rolled by restarting the game, which is exactly the thing the brief
## forbids. The reasoning and the working-rule-7 argument live on
## `VendorStock`, which is the only thing that writes it.
##
## Nothing in here is the player's. It is unowned gear on a shelf and the
## moment it was put there; buying one spends Marks and puts a piece in the
## stash, through the door gear has always arrived by. Additive - absent
## reads as a shelf that has never been stocked, which is a new account.
var vendor: Dictionary = {}

## The tier the player last chose, so the picker reopens where they left off.
var last_tier_id: String = "normal"

## This player's own six-character code, and the codes they have kept.
##
## **New persistent data, and worth justifying against working rule 7.** That
## rule is about game *power* - relics, tower levels, currencies, building tiers
## - none of which may survive a run. Neither of these is power: a play code is
## an address, like a phone number, and a friends list is a handful of other
## people's addresses. Nothing here makes a hero stronger or a run easier, and
## deleting the whole block costs a player their contacts and nothing else.
##
## The code is generated once, on first need, and never changes - it is what a
## friend has written down.
var play_code: String = ""
var friends: Array = []

# --- The stash (owner ruling, 2026-08-20) -------------------------------------
#
# Gear persists with the hero. Marks are the account's currency and shards are
# what broken gear becomes; neither is a run currency, and gold cannot be turned
# into either. That separation is the point: a stash purchase must never compete
# with the wall that is about to be overrun.

## Owned gear, each a plain dictionary of kind, rarity and level.
var stash: Array = []

## Equipped pieces, keyed by GearData.Slot. Values are indices into `stash`.
var equipped: Dictionary = {}

## The account's currency, and what salvage yields.
var marks: int = 0

## Lines standing in the Long Ledger, as `ExchangeOrder.to_record` wrote them.
##
## **This holds gear, and that is why it has to be here.** A listed piece is out
## of the stash and carried by its order - see `ExchangeOrder` for why a flag on
## a stash entry would not do - so a save that did not write these would destroy
## everything a player had listed the moment they quit.
##
## It is not new *kinds* of persistence. Working rule 7 already sanctions owned
## gear and Marks; this is the same two things parked in a second list while a
## caravan is on its way, which is exactly what escrow is. The owner decision is
## recorded in CLAUDE.md with its date.
##
## Additive: a save written before the Ledger has no key and reads as an empty
## board, so `SAVE_VERSION` did not move.
var exchange_orders: Array = []
var shards: int = 0


## Whether the opening cinematic has been shown. A setting rather than a
## statistic: it exists so the intro plays once, and it is cleared when a player
## wipes their save because a fresh account should see the opening again.
var story_intro_seen: bool = false


## Legacy rank, one per full clear, capped at Balance.SIGIL_MAX_RANK (v4 §36).
var sigils: int = 0

## One-time account deeds. The ids point at ChronicleObjectiveData; completing
## one grants only its horizontal Tool reward and never changes combat stats.
var completed_objectives: Array[String] = []

# --- Run statistics ---
## The name a submitted run is posted under, and this save's own best runs.
##
## Both are run statistics under working rule 7 — a name is what a statistic is
## filed under, and a best-run row is a record of a run that finished. Neither
## carries power: nothing in a row is ever read back into a run, which is the
## line rule 7 actually draws.
var player_name: String = ""
var best_runs: Array = []

## Runs that finished while the board was unreachable.
##
## A bounded outbox, not a permanent record. Rows retain their submission IDs
## across retries and leave the queue only after success, so a lost response
## cannot create duplicate leaderboard entries.
var pending_runs: Array = []

var runs_started: int = 0
## Rift and dungeon stages closed, all time. A statistic, like the kills.
var rifts_closed: int = 0
## Camps razed on the outskirts, across every run. A statistic (working rule
## 7), like the rift stages.
var camps_razed: int = 0
var runs_won: int = 0
var best_distance: float = 0.0
var total_enemies_killed: int = 0

# --- More statistics, and what they unlock (2026-09-12) ------------------------
#
# Owner brief: a clear view of the account's progress, and achievements. Every
# one of these is a count the account keeps anyway; an achievement is a count
# with a threshold and a name (working rule 7: statistics are sanctioned, and
# an achievement grants nothing). `stat` is the single read for all of them,
# derived ones included, so an achievement file names a key and nothing else.

## The furthest act this account has reached, across every run.
var highest_act: int = 0
var bosses_felled: int = 0
var forks_opened: int = 0
var war_camps_razed: int = 0
var dungeons_finished: int = 0
var fish_caught_total: int = 0
var swims: int = 0
var coop_runs: int = 0
## Achievement ids unlocked, in the order they were earned.
var achievements: Array[String] = []
## Whether the first road has been walked to a crossroad. Co-op waits for it
## (owner brief: new players run through the tutorial before co-op unlocks).
var tutorial_done: bool = false


## One read for every statistic an achievement may name. Unknown keys read
## zero, so a misspelt key can never unlock - `guide_check` refuses them.
func stat(key: String) -> float:
	match key:
		"runs_started": return float(runs_started)
		"runs_won": return float(runs_won)
		"highest_act": return float(highest_act)
		"bosses_felled": return float(bosses_felled)
		"total_enemies_killed": return float(total_enemies_killed)
		"camps_razed": return float(camps_razed)
		"forks_opened": return float(forks_opened)
		"war_camps_razed": return float(war_camps_razed)
		"rifts_closed": return float(rifts_closed)
		"dungeons_finished": return float(dungeons_finished)
		"fish_caught_total": return float(fish_caught_total)
		"swims": return float(swims)
		"coop_runs": return float(coop_runs)
		"spirits_bonded": return float(spirit_bonded.size())
		"hero_level": return float(hero_level)
		"ascension": return float(ascension)
		"best_distance": return best_distance
		"codex_share":
			var total: int = 0
			for source: String in ["enemies", "affixes", "wildlife_kinds", "weathers"]:
				total += (ContentDB.get(source) as Dictionary).size()
			return float(codex_seen.size()) / float(maxi(total, 1))
		_:
			return 0.0


## Whether a key names a statistic this account keeps. For the gate.
func has_stat(key: String) -> bool:
	return key in ["runs_started", "runs_won", "highest_act", "bosses_felled",
		"total_enemies_killed", "camps_razed", "forks_opened", "war_camps_razed",
		"rifts_closed", "dungeons_finished", "fish_caught_total", "swims", "coop_runs",
		"spirits_bonded", "hero_level", "ascension", "best_distance", "codex_share"]


## Compares every achievement to its statistic and says so once for each
## newly met. Cheap - two dozen comparisons - so it runs after any count moves.
func check_achievements() -> void:
	var earned: bool = false
	for achievement: AchievementData in ContentDB.achievements_sorted():
		if achievements.has(achievement.id) or not achievement.is_met():
			continue
		achievements.append(achievement.id)
		earned = true
		EventBus.achievement_unlocked.emit(achievement.id)
	if earned:
		save_game()


## The first road walked to its crossroad. Said once.
func mark_tutorial_done() -> void:
	if tutorial_done:
		return
	tutorial_done = true
	save_game()


## Renames the Warden. The name is cleaned the way the board cleans it, so a
## name that cannot be posted cannot be worn either.
func rename_player(wanted: String) -> void:
	var cleaned: String = Score.clean_name(wanted)
	if cleaned == player_name:
		return
	player_name = cleaned
	save_game()
	EventBus.player_renamed.emit(player_name)


func _wire_statistics() -> void:
	EventBus.boss_defeated.connect(func(_id: String, _act: int) -> void:
		bosses_felled += 1
		check_achievements())
	EventBus.act_started.connect(func(act: int, _terrain: String) -> void:
		if act > highest_act:
			highest_act = act
			check_achievements())
	EventBus.fish_caught.connect(func(_id: String, _food: int) -> void:
		fish_caught_total += 1
		check_achievements())
	EventBus.camp_cleared.connect(func(_lane: int, tier: int) -> void:
		if tier == BattleGrid.CampTier.BARON:
			war_camps_razed += 1
		check_achievements())
	EventBus.fork_opened.connect(func(_lane: int) -> void:
		forks_opened += 1
		check_achievements())
	EventBus.hero_swim_changed.connect(func(swimming: bool) -> void:
		if swimming:
			swims += 1
			check_achievements())
	EventBus.rift_ended.connect(func(reward: Dictionary) -> void:
		if int(reward.get("kind", 0)) == RiftArena.Kind.DUNGEON \
				and int(reward.get("stages", 0)) >= Balance.DUNGEON_STAGES \
				and not bool(reward.get("died", false)):
			dungeons_finished += 1
		check_achievements())
	EventBus.spirit_bonded.connect(func(_key: String) -> void: check_achievements())
	EventBus.hero_levelled.connect(func(_level: int, _points: int, _skill: int) -> void: check_achievements())
	EventBus.run_started.connect(func() -> void:
		if Coop.partner_present():
			coop_runs += 1
		check_achievements())

# --- Settings ---
const MILESTONE_CINEMATICS_SEEN_KEY: String = "milestone_cinematics_seen"

## The pantry: fish id to how many are kept. Persists between runs.
##
## **This is an amendment to working rule 7 and it is recorded in CLAUDE.md.**
## What is new is that a *consumable* survives a run, which no previous rule
## sanctioned - the Tonic and the Draught are held in `RunState` and lost with
## everything else. The owner asked for fish to be kept in the stash and eaten
## from it, which is a between-runs store by definition.
##
## The bound that keeps it from being a fourth power scale is not here: it is
## `RunState.meals_eaten`, capped at `Balance.FISH_MEALS_PER_RUN`. The pantry
## persists; the appetite does not. A player who fished for an hour carries a
## deeper choice of meals into the next run, never more of them.
##
## Additive: a save written before fishing has no `pantry` key and reads back as
## an empty larder, so `SAVE_VERSION` did not move and there is no migration to
## get wrong.
var fish: Dictionary = {}

## Professions: id to experience, kept between runs (owner request, 2026-09-11).
##
## **New persistent data, and an amendment to working rule 7.** What persists
## is how *practised* the hero is at a thing - the Angler, first - and the
## bound is `Balance.PROFESSIONS`: a profession that is not on that list is
## not read from a save and cannot be trained, so this block can never grow a
## key by accident. The level is derived from the experience rather than
## stored beside it, so the two cannot disagree.
##
## **A profession may not touch the fight.** It changes how well the hero does
## the thing the profession is and nothing else; levelling and gear stay the
## only two scales the campaign tiers are tuned against. `fishing_check` reads
## the Angler's effects and fails on any that reaches past the pond.
##
## Additive: a save without a `professions` key reads back as level 1 in all
## of them, so `SAVE_VERSION` did not move.
var profession_xp: Dictionary = {}

var settings: Dictionary = {
	"chronicle_goal": "",
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"ambience_volume": 0.9,
	"weather_volume": 0.9,
	"screen_shake": 1.0,
	# The two comfort scales added 2026-09-16 beside the shake. Declared here or
	# they are silently dropped - the loader rejects keys it does not already
	# know, which is how a setting appears to save and reverts on next launch.
	# Both default to 1, so the shipped game is exactly what it was and a save
	# written before today reads as untouched.
	"screen_flash": 1.0,
	"damage_number_density": 1.0,
	"beast_gait": 0.65,
	"display_mode": UserSettings.DISPLAY_FULLSCREEN,
	# These keys must exist before load_save() merges persisted settings. The
	# loader deliberately rejects unknown keys, so omitting them made Video and
	# colourblind selections appear to save while silently reverting on launch.
	"graphics": {},
	"colourblind_mode": "off",
	"key_bindings": {},
	# Must exist here or it is silently dropped: the loader rejects keys it does
	# not already know, so a default missing from this dictionary is a setting
	# that appears to save and reverts on the next launch.
	"tutorial_seen": false,
	## First-view milestone ids. The HUD's light title cards remain on replays.
	MILESTONE_CINEMATICS_SEEN_KEY: [],
	## Whether this account has already been given its opening weapon.
	##
	## **Missing from here until 2026-09-10, and it granted a free sword on every
	## launch.** `_read_settings` drops keys this dictionary does not declare, so
	## `_seed_starting_gear` set the flag, `save_game` wrote it, and the next
	## load threw it away and handed out another Coalpaint Edge. Found by
	## diffing a save either side of a tool run - a played account had seven of
	## them - and it is the third time this exact dictionary has caused it, after
	## Video and the colourblind modes.
	STARTING_GEAR_KEY: false,
}


## Banks Tools for a finished run and spends them on the roster.
##
## Earning is by depth, not by kills: a per-kill trickle pays for farming one
## wave, which is the opposite of what the run is for. Spending is automatic and
## in the authored order, because a shop for one currency with one thing to buy
## is a menu standing in front of a decision nobody makes.
##
## Records having met something. True when it is the first time.
##
## **Deliberately cheap to call.** It is invoked from spawn paths that run
## hundreds of times a wave, so the common case - already known - is one
## dictionary-free array lookup and a return. Saving happens on the rare first
## sighting, not on every enemy that walks down the road.
func record_seen(kind: String, thing_id: String) -> bool:
	if thing_id.is_empty():
		return false
	var key: String = "%s:%s" % [kind, thing_id]
	if codex_seen.has(key):
		return false
	codex_seen.append(key)
	save_game()
	return true


## Whether something has been met.
func has_seen(kind: String, thing_id: String) -> bool:
	return codex_seen.has("%s:%s" % [kind, thing_id])


## How many of one kind have been met, for a heading.
func seen_count(kind: String) -> int:
	var prefix: String = kind + ":"
	var total: int = 0
	for entry: String in codex_seen:
		if entry.begins_with(prefix):
			total += 1
	return total


## Learns a recipe. True when it was new, so the caller can announce it.
##
## Announcing matters more here than for most unlocks: a blueprint is the moment
## the game promises your *next* run will be different, and a discovery that
## slides past in a loot toast has not made that promise.
func learn_blueprint(blueprint_id: String) -> bool:
	if blueprint_id.is_empty() or unlocked_blueprints.has(blueprint_id):
		return false
	unlocked_blueprints.append(blueprint_id)
	save_game()
	return true


## Whether a recipe is known. Ammunition marked `known_from_the_start` needs no
## blueprint - a bow the player cannot feed is a bow they cannot evaluate.
func knows_recipe(kind: String, recipe_id: String) -> bool:
	for value: Variant in ContentDB.blueprints.values():
		var plan := value as BlueprintData
		if plan == null or plan.unlocks_kind != kind or plan.unlocks_id != recipe_id:
			continue
		return unlocked_blueprints.has(plan.id)
	# No blueprint teaches it, so nothing is gating it.
	return true


## Returns what was unlocked as `"kind:id"` - `"tower:tide_caller"`,
## `"blueprint:plan_shortbow"` - because two shelves means the caller can no
## longer assume what it was handed. It used to return bare tower ids and the
## debrief announced every one of them as a tower; the first blueprint bought
## would have been shown as one.
##
## **Tools spend down two shelves, in order.** The eight roster towers cost 32 of
## the 40 a player may hold, so before this they simply stopped meaning anything
## once the roster was complete: every later run banked Tools against a cap that
## bought nothing, and a currency that accumulates toward nothing is worse than
## no currency, because the player keeps being told they earned some.
##
## The second shelf is blueprints, which cost less because a recipe is a smaller
## thing than a tower. Both shelves are `unlocked` ids, so working rule 7 is
## untouched - this widens the content pool and grants no combat stat, which is
## the whole constraint on what Tools are allowed to buy.
##
## When both are exhausted the player has everything, and Tools stop being
## awarded rather than banking silently - see `tools_have_a_sink`.
func award_tools(act_reached: int, victory: bool) -> Array[String]:
	var bought: Array[String] = []
	if not tools_have_a_sink():
		return bought

	var earned: int = Balance.TOOLS_PER_ACT * maxi(act_reached, 1)
	if victory:
		earned += Balance.TOOLS_VICTORY_BONUS
	tools = mini(tools + earned, Balance.TOOLS_MAX)

	while tools >= Balance.TOOLS_PER_ROSTER_TOWER:
		var id: String = earn_next_roster_tower()
		if id.is_empty():
			break                                   # roster complete
		tools -= Balance.TOOLS_PER_ROSTER_TOWER
		bought.append("tower:" + id)
	while tools >= Balance.TOOLS_PER_BLUEPRINT:
		var id: String = earn_next_blueprint()
		if id.is_empty():
			break                                   # everything is known
		tools -= Balance.TOOLS_PER_BLUEPRINT
		bought.append("blueprint:" + id)
	return bought


## The next unknown recipe in stable content order, or an empty string.
##
## Ordered by id rather than by a hand-kept list: blueprints are peers, unlike
## the roster towers, whose order widens one element at a time on purpose.
func earn_next_blueprint() -> String:
	var known: Array[String] = []
	for id: String in ContentDB.blueprints.keys():
		known.append(id)
	known.sort()
	for id: String in known:
		if not unlocked_blueprints.has(id):
			unlocked_blueprints.append(id)
			save_game()
			return id
	return ""


## Whether Tools can still buy anything at all.
##
## Asked before awarding rather than after, so a finished account is told it has
## everything instead of being handed a currency with nowhere to go.
func tools_have_a_sink() -> bool:
	for id: String in ROSTER_UNLOCK_ORDER:
		if not unlocked_towers.has(id):
			return true
	for id: Variant in ContentDB.blueprints.keys():
		if not unlocked_blueprints.has(String(id)):
			return true
	return false


## One Sigil per full clear, until the legacy is complete.
##
## v4 §36 wants this on the true final boss. The Chainmaker does not exist yet,
## so it is awarded on the summit clear that currently ends the campaign - the
## same moment, one boss early. Move the call, not the rule, when the summit is
## built.
func award_sigil() -> bool:
	if sigils >= Balance.SIGIL_MAX_RANK:
		return false
	sigils += 1
	save_game()
	return true


## Records every newly met deed in stable content order and banks its Tools.
##
## Evaluated once from the completed run summary. This makes co-op behavior
## deterministic and keeps objectives from subscribing to a second copy of
## every combat event merely to reconstruct facts RunState already owns.
func complete_chronicle(summary: Dictionary) -> Array[String]:
	var completed_now: Array[String] = []
	for objective: ChronicleObjectiveData in ContentDB.chronicle_objectives_sorted():
		if completed_objectives.has(objective.id) or not objective.is_met(summary):
			continue
		completed_objectives.append(objective.id)
		completed_now.append(objective.id)
		tools = mini(tools + objective.tool_reward, Balance.TOOLS_MAX)
	return completed_now


func objective_completed(id: String) -> bool:
	return completed_objectives.has(id)


func chronicle_completed_count() -> int:
	var count: int = 0
	for objective: ChronicleObjectiveData in ContentDB.chronicle_objectives_sorted():
		if objective_completed(objective.id):
			count += 1
	return count


## What the Treasury may carry between runs. Rank 3 raises it (v4 §36).
func treasury_cap(tier_cap: int) -> int:
	if sigils >= 3:
		return maxi(tier_cap, Balance.SIGIL_RANK3_TREASURY_CAP)
	return tier_cap


## Throws the account away and starts over.
##
## Offered in Settings because a roguelite's unlock pool is most of what a
## returning player is playing against, and somebody who wants the first run
## back has no other way to get it. Deliberately total: progress, statistics and
## the Treasury cache all go.
##
## Player settings are *kept*. Volume, display mode and key bindings are not
## progress, and wiping somebody's key bindings because they wanted a fresh
## unlock pool would be a second, unasked-for destruction.
func erase_progress() -> void:
	unlocked_towers.clear()
	unlocked_relics.clear()
	unlocked_spells.clear()
	unlocked_blueprints.clear()
	codex_seen.clear()
	unlocked_terrains.clear()
	unlocked_buildings.clear()
	resource_cache.clear()
	act3_cleared = false
	tools = 0
	sigils = 0
	hero_level = 1
	hero_xp = 0.0
	hero_attributes = [0, 0, 0, 0, 0]
	hero_attribute_points = 0
	hero_skill_points = 0
	ascension = 0
	tier_cleared = -1
	gatekeeper = {}
	vendor = {}
	last_tier_id = "normal"
	profession_xp.clear()
	materials.clear()
	stash.clear()
	equipped.clear()
	marks = 0
	exchange_orders = []
	shards = 0
	player_name = ""
	best_runs.clear()
	pending_runs.clear()
	runs_started = 0
	rifts_closed = 0
	camps_razed = 0
	highest_act = 0
	bosses_felled = 0
	forks_opened = 0
	war_camps_razed = 0
	dungeons_finished = 0
	fish_caught_total = 0
	swims = 0
	coop_runs = 0
	achievements.clear()
	tutorial_done = false
	runs_won = 0
	best_distance = 0.0
	total_enemies_killed = 0
	completed_objectives.clear()
	_seed_starting_roster()
	# Cleared before re-seeding: somebody erasing their progress is asking for a
	# first run, and a first run starts with a weapon in hand.
	settings[STARTING_GEAR_KEY] = false
	_seed_starting_gear()
	# The tutorial comes back too. It is a preference and the rest of the
	# preferences are kept, but somebody erasing their progress is asking for a
	# first run, and a first run includes being shown how the game works.
	settings["tutorial_seen"] = false
	settings[MILESTONE_CINEMATICS_SEEN_KEY] = []
	# And the opening cinematic, for the same reason: somebody erasing their
	# progress is asking for a first run, and a first run starts with the story.
	story_intro_seen = false
	# Written immediately rather than left in memory: the player asked for the
	# save to be gone, and a crash before the next autosave would hand it back.
	save_game()


func milestone_cinematic_seen(id: String) -> bool:
	if id.is_empty():
		return false
	var seen: Array = _milestone_cinematic_ids()
	return seen.has(id)


func mark_milestone_cinematic_seen(id: String) -> void:
	if id.is_empty() or milestone_cinematic_seen(id):
		return
	var seen: Array = _milestone_cinematic_ids()
	seen.append(id)
	settings[MILESTONE_CINEMATICS_SEEN_KEY] = seen
	save_game()


func _milestone_cinematic_ids() -> Array:
	var stored: Variant = settings.get(MILESTONE_CINEMATICS_SEEN_KEY, [])
	if stored is Array:
		return stored as Array
	# A hand-edited or damaged setting must not break a milestone signal in the
	# middle of a run. Treat it as a fresh first-view list and repair in memory.
	settings[MILESTONE_CINEMATICS_SEEN_KEY] = []
	return []


## Every account starts able to build the original eight, whatever the save
## says. A save written before the roster existed has none of them listed, and a
## player who could build nothing at all would have no way to earn the rest.
func _seed_starting_roster() -> void:
	for id: String in STARTING_TOWERS:
		if not unlocked_towers.has(id):
			unlocked_towers.append(id)


## Puts the tier-0 weapon in the hero's hand, once per account.
##
## Deliberately not idempotent the way `_seed_starting_roster` is - see
## `STARTING_WEAPON`. The flag is only set on success, so an account that somehow
## reaches this before the content is loaded gets its weapon on the next launch
## rather than losing it forever to a flag set too early.
func _seed_starting_gear() -> void:
	if bool(settings.get(STARTING_GEAR_KEY, false)):
		return
	if ContentDB.gear(STARTING_WEAPON) == null:
		return
	if stash.size() < Balance.STASH_CAPACITY:
		stash.append(Stash.make(STARTING_WEAPON, 0))
		# Equipped, not merely owned: the decision was that the first fight shows
		# a weapon, and one sitting in the stash shows nothing.
		if not equipped.has(GearData.Slot.WEAPON):
			equipped[GearData.Slot.WEAPON] = stash.size() - 1
	settings[STARTING_GEAR_KEY] = true


## Fells an act boss and widens the roster by one, in a fixed order.
##
## Returns the tower id earned, or "" when the roster is already complete.
## Persisted immediately: an unlock that only exists until the process exits is
## not progression.
func earn_next_roster_tower() -> String:
	for id: String in ROSTER_UNLOCK_ORDER:
		if not unlocked_towers.has(id):
			unlocked_towers.append(id)
			save_game()
			return id
	return ""


func _ready() -> void:
	load_save()
	_wire_statistics()
	_seed_starting_roster()
	# After `load_save`, never inside it: the stash is parsed late, so a piece
	# appended mid-parse would be overwritten by the save's own list.
	_seed_starting_gear()
	# Applied here rather than left to whoever happens to read a setting first.
	# The buses had exactly that bug once already, and display mode has no other
	# owner at all - without this a windowed player is put back into fullscreen
	# every single launch.
	UserSettings.apply_all()


## Extra Town Hall relic slots granted by meta-progression. Capped by design.
## Rank 4's legacy effect in v4 §36 is "one additional Town Hall relic socket",
## which is exactly what the shipped `act3_cleared` bonus already grants - and
## CLAUDE.md §7 names that bonus as the *only* sanctioned persistent power. So
## the socket stays on the first clear rather than the fourth: strictly more
## generous than v4, takes nothing away from an account that has it, and avoids
## two systems paying twice for the same achievement.
func bonus_relic_slots() -> int:
	return Balance.ACT3_CLEAR_BONUS_RELIC_SLOTS if act3_cleared else 0


## The starting bundle rank 1 grants, per currency (v4 §36).
func sigil_starting_supply() -> int:
	return Balance.SIGIL_RANK1_SUPPLY if sigils >= 1 else 0


## Crossroad redraws this account has earned (rank 2).
func sigil_crossroad_rerolls() -> int:
	return Balance.SIGIL_RANK2_REROLLS if sigils >= 2 else 0


## Reads the hero block, clamping everything.
##
## A save is a file on someone's disk and may have been edited, truncated or
## written by a build that is not this one. Every field is bounded here rather
## than trusted, because an out-of-range level does not fail loudly - it produces
## a hero with 4,000 attribute points and a game that is no longer a game.
## Reads the social block: this player's code and the friends they have kept.
##
## Bounded like everything else here, and for the same reason - a save is a file
## on somebody's disk. A malformed code is dropped rather than repaired, because
## a repaired one would be a *different* code, and a play code is the one thing
## a friend has written down.
func _read_social(social: Dictionary) -> void:
	var kept: String = String(social.get("play_code", "")).to_upper()
	play_code = kept if kept.length() == 6 else ""
	friends = []
	for entry: Variant in (social.get("friends", []) as Array):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var code: String = String(row.get("code", "")).to_upper()
		if code.length() != 6 or friends.size() >= Balance.FRIENDS_MAX:
			continue
		friends.append({
			"code": code,
			"name": String(row.get("name", "")).substr(0, 24),
		})


func _read_hero(hero: Dictionary) -> void:
	hero_level = clampi(int(hero.get("level", 1)), 1, Balance.HERO_MAX_LEVEL)
	hero_xp = maxf(float(hero.get("xp", 0.0)), 0.0)
	hero_attribute_points = maxi(int(hero.get("attribute_points", 0)), 0)
	ascension = clampi(int(hero.get("ascension", 0)), 0, Balance.ASCENSION_MAX)
	hero_skill_points = maxi(int(hero.get("skill_points", 0)), 0)
	tier_cleared = clampi(int(hero.get("tier_cleared", -1)), -1, 8)
	# **A malformed row is dropped rather than trusted**, the rule the pen is
	# read under: this list decides what the Gatekeeper does at a summit, and a
	# tier id the game does not have would be a ladder nothing could ever
	# finish.
	gatekeeper = {}
	for key: Variant in (hero.get("gatekeeper", {}) as Dictionary):
		var tier_id: String = String(key)
		if ContentDB.tiers.has(tier_id):
			gatekeeper[tier_id] = clampi(
				int((hero["gatekeeper"] as Dictionary)[key]), 0, GatekeeperTrials.STAGES)
	last_tier_id = String(hero.get("last_tier", "normal"))
	story_intro_seen = bool(hero.get("story_seen", false))

	hero_attributes = [0, 0, 0, 0, 0]
	var stored: Array = hero.get("attributes", []) as Array
	for i: int in mini(stored.size(), hero_attributes.size()):
		hero_attributes[i] = maxi(int(stored[i]), 0)

	# Placed points plus unspent may not exceed what the level could ever have
	# granted. This is the one line that stops a hand-edited save from arriving
	# with a maxed hero on a fresh account.
	var granted: int = hero_level - 1
	var placed: int = 0
	for value: int in hero_attributes:
		placed += value
	if placed + hero_attribute_points > granted:
		var over: int = placed + hero_attribute_points - granted
		hero_attribute_points = maxi(hero_attribute_points - over, 0)
		over = placed + hero_attribute_points - granted
		for i: int in hero_attributes.size():
			if over <= 0:
				break
			var taken: int = mini(hero_attributes[i], over)
			hero_attributes[i] -= taken
			over -= taken


## Reads the stash, discarding anything that is not a real piece of gear.
##
## A save is a file on someone's disk. Every entry is validated against the
## content that actually exists rather than trusted, because a piece naming a
## kind this build no longer ships is not an error anywhere — it is a silent hole
## that surfaces later as a null in the equip screen.
## Set while reading a stash when a piece had never been named, so `load_save`
## can write the names it just handed out. See `_read_stash`.
var _named_a_piece: bool = false


func _read_stash(data: Dictionary) -> void:
	_named_a_piece = false
	marks = maxi(int(data.get("marks", 0)), 0)
	# Read through `ExchangeOrder`, which refuses anything malformed rather than
	# repairing it: an order restored half-way is an order holding a piece that
	# is also in the stash, and duplicated gear is the one outcome the whole
	# escrow design exists to prevent.
	exchange_orders = []
	for entry: Variant in data.get("orders", []) as Array:
		if not (entry is Dictionary):
			continue
		if ExchangeOrder.from_record(entry as Dictionary) == null:
			continue
		exchange_orders.append((entry as Dictionary).duplicate(true))
		if exchange_orders.size() >= Balance.EXCHANGE_SLOTS:
			break
	shards = maxi(int(data.get("shards", 0)), 0)
	stash = []
	for entry: Variant in data.get("gear", []) as Array:
		if not (entry is Dictionary):
			continue
		var piece: Dictionary = entry
		var kind: String = String(piece.get("kind", ""))
		if ContentDB.gear(kind) == null:
			continue
		var restored: Dictionary = Stash.make(kind, int(piece.get("rarity", 0)),
			int(piece.get("level", 1)))
		# Additive: a piece saved before favourites existed simply has no flag
		# and reads back unmarked, so `SAVE_VERSION` did not move for this.
		if bool(piece.get("favourite", false)):
			restored["favourite"] = true
		# Additive in the same way, and for a system that did not exist when
		# these were written: a piece saved before trading has no name and is
		# given one here. `Stash.make` has already put a fresh one on `restored`,
		# so this keeps the saved name when there is one rather than renaming
		# every piece in the stash on every load - which would break an offer
		# that was open across a save.
		if piece.has("uid"):
			restored["uid"] = int(piece["uid"])
		else:
			# **And it is written back at the end of the load.** `Stash.make`
			# gave it a fresh name a moment ago, and without this that name is
			# only in memory - so the next launch names it again, differently.
			#
			# That was survivable while a name meant nothing but "which piece is
			# on the trade table". It stopped being survivable when affixes
			# started being rolled from it: a sword from an old save would have
			# granted different attributes every time the game was opened.
			_named_a_piece = true
		stash.append(restored)
		if stash.size() >= Balance.STASH_CAPACITY:
			break

	equipped = {}
	for key: Variant in (data.get("equipped", {}) as Dictionary):
		var index: int = int((data["equipped"] as Dictionary)[key])
		if index >= 0 and index < stash.size():
			equipped[int(key)] = index


## The leaderboard block, bounded on the way in.
##
## Read defensively for the same reason the hero and stash blocks are: a save is
## a file on a player's disk and the only thing standing between an edited one
## and a broken screen is what happens here. A row that is not a dictionary is
## dropped rather than stored, and the name goes through the same cleaner a
## submitted name does — a save carrying newlines in its name would otherwise
## break every row of a board it appears on.
func _read_board(data: Dictionary) -> void:
	player_name = Score.clean_name(String(data.get("name", ""))) \
		if not String(data.get("name", "")).is_empty() else ""

	best_runs = []
	var best_value: Variant = data.get("best", [])
	if best_value is Array:
		for entry: Variant in best_value as Array:
			if entry is Dictionary:
				best_runs.append(Score.clean_row(entry as Dictionary))
			if best_runs.size() >= Balance.LEADERBOARD_LOCAL_MAX:
				break

	pending_runs = []
	var pending_value: Variant = data.get("pending", [])
	if pending_value is Array:
		for entry: Variant in pending_value as Array:
			if entry is Dictionary:
				pending_runs.append(Score.clean_row(entry as Dictionary))
			if pending_runs.size() >= Balance.LEADERBOARD_PENDING_MAX:
				break


## The piece worn in a slot, or an empty dictionary.
func equipped_piece(slot: int) -> Dictionary:
	var index: int = int(equipped.get(slot, -1))
	if index < 0 or index >= stash.size():
		return {}
	return stash[index]


## Attribute points every equipped piece grants, one entry per attribute.
func gear_attribute_points() -> Array[int]:
	var out: Array[int] = []
	out.resize(RunState.ATTRIBUTE_NAMES.size())
	out.fill(0)
	for slot: Variant in equipped:
		var piece: Dictionary = equipped_piece(int(slot))
		if piece.is_empty():
			continue
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind == null:
			continue
		# Every bonus on the piece, not only the kind's own attribute. The total
		# is unchanged - `Stash.affixes` divides `Stash.points` rather than
		# adding to it - so this widens what a piece dresses without moving the
		# scale the campaign tiers are tuned against.
		for affix: Dictionary in Stash.affixes(piece, kind):
			var which: int = int(affix["attribute"])
			if which >= 0 and which < out.size():
				out[which] += int(affix["points"])
	return out


## Takes a piece into the stash. Returns false when there is no room.
func take_gear(piece: Dictionary) -> bool:
	if piece.is_empty() or stash.size() >= Balance.STASH_CAPACITY:
		return false
	stash.append(piece)
	save_game()
	EventBus.stash_changed.emit()
	return true


## Delivers a drop without ever deleting an earned reward. A free stash slot
## stores it; a full stash breaks it into shards immediately. The returned
## payload is presentation-neutral so battlefield pickups and raid chests can
## describe the same outcome in their own UI.
func receive_gear(piece: Dictionary) -> Dictionary:
	if piece.is_empty():
		return {"stored": false, "shards": 0}
	if take_gear(piece):
		RunState.note_kept("gear", 1.0)
		return {"stored": true, "shards": 0}
	var salvaged: int = Stash.salvage_yield(piece)
	shards += salvaged
	save_game()
	EventBus.stash_changed.emit()
	return {"stored": false, "shards": salvaged}


## Removes a piece, keeping the equipped indices pointing at the same gear.
##
## Indices shift when an element is removed from the middle of an array, so
## anything equipped after the removed slot has to move down with it. Getting
## this wrong does not fail loudly - it silently re-equips a different sword.
func drop_gear(index: int) -> Dictionary:
	if index < 0 or index >= stash.size():
		return {}
	var piece: Dictionary = stash[index]
	stash.remove_at(index)
	var moved: Dictionary = {}
	for slot: Variant in equipped:
		var at: int = int(equipped[slot])
		if at == index:
			continue
		moved[int(slot)] = at - 1 if at > index else at
	equipped = moved
	save_game()
	EventBus.stash_changed.emit()
	return piece


## Which campaign tiers this account may choose.
func tier_is_unlocked(tier: CampaignTierData) -> bool:
	return tier != null and tier.order <= tier_cleared + 1


## Records a full clear, which is what opens the next tier.
## The Warden's title, by rank.
func warden_title() -> String:
	return Balance.ASCENSION_TITLES[clampi(ascension, 0, Balance.ASCENSION_TITLES.size() - 1)]


## Ascends, once per summit clear, up to the cap. Returns the new rank, or the
## old one when nothing changed.
func ascend() -> int:
	if ascension >= Balance.ASCENSION_MAX:
		return ascension
	ascension += 1
	save_game()
	EventBus.warden_ascended.emit(ascension)
	return ascension


## **A rung of the Gatekeeper's ladder pays a rank.**
##
## Called by `GatekeeperTrials.record_cleared` and by nothing else, so the
## ladder is the only door to the scale and `ascend()` - the summit's own
## offer - stays exactly what it was.
##
## Saves nothing itself: the caller writes the ladder and the rank in one
## `save_game`, because a rank banked without the rung that bought it would let
## a player take the same trial twice.
func grant_ascension_rank() -> int:
	if ascension >= Balance.ASCENSION_MAX:
		return ascension
	ascension += 1
	EventBus.warden_ascended.emit(ascension)
	return ascension


func record_tier_cleared(order: int) -> void:
	if order > tier_cleared:
		tier_cleared = order
		save_game()


## This player's own code, made the first time anybody asks for it.
##
## Generated rather than assigned by a server, because there is no server that
## knows who anybody is - and it does not need to be unique against the world,
## only unguessable enough that a stranger cannot find you by typing. Thirty-two
## to the sixth is a billion.
func own_play_code() -> String:
	if play_code.length() != 6:
		play_code = Supabase.room_code()
		save_game()
	return play_code


## Keeps somebody's code under a name of this player's choosing.
func remember_friend(code: String, called: String) -> bool:
	var cleaned: String = code.strip_edges().to_upper().replace("-", "")
	if cleaned.length() != 6 or cleaned == own_play_code():
		return false
	for entry: Variant in friends:
		if String((entry as Dictionary).get("code", "")) == cleaned:
			return false
	if friends.size() >= Balance.FRIENDS_MAX:
		return false
	friends.append({"code": cleaned, "name": called.strip_edges().substr(0, 24)})
	save_game()
	return true


func forget_friend(code: String) -> void:
	for index: int in range(friends.size() - 1, -1, -1):
		if String((friends[index] as Dictionary).get("code", "")) == code:
			friends.remove_at(index)
	save_game()


func friend_codes() -> Array:
	var out: Array = []
	for entry: Variant in friends:
		out.append(String((entry as Dictionary).get("code", "")))
	return out


## Blocks writes to the player's save slot while a gate is mutating this state.
##
## **A gate that edits MetaState must never be able to persist it.** Several do -
## they wipe the stash to simulate a fresh account, drain Tools to prove the
## economy ends, reset the starting-gear flag - and any `save_game()` reached
## while that scratch state is live writes it over a real player's file. That is
## not hypothetical: `weapon_vfx_check` run against a live save destroyed a
## stash on 2026-08-31, and the stash is the one thing in this project that
## neither git nor a re-import can restore.
##
## A counter rather than a flag so nested gates cannot un-block each other.
var _saves_held: int = 0


## Stops this state from reaching the disk until `resume_saves` is called.
func hold_saves() -> void:
	_saves_held += 1


func resume_saves() -> void:
	_saves_held = maxi(_saves_held - 1, 0)


func saves_held() -> bool:
	return _saves_held > 0


func save_game() -> void:
	if _saves_held > 0:
		return
	if not write_text_atomically(SAVE_PATH, serialized_save()):
		push_warning("MetaState: could not write the save: %s" % SAVE_PATH)
		return
	save_written.emit()


## Writes `text` to `path` without ever leaving a half-written file there.
##
## The save used to be opened for writing in place, which truncates it to zero
## bytes before the first byte of the new contents lands. A crash, a power cut
## or the browser tab closing inside that window left a file the loader could
## not parse - and it is written dozens of times a run, on every first codex
## sighting and every piece of gear picked up. The next launch would then have
## started a fresh account over it, which for this game means the stash, the
## hero and every Ledger order, none of it recoverable from anywhere.
##
## So the contents go to a sibling first and are renamed over the original only
## once they are complete. On Windows the engine's rename is a remove followed
## by a rename, so there is still one instant with no committed file and a
## finished sibling; `read_committed_text` adopts the sibling in that case.
static func write_text_atomically(path: String, text: String) -> bool:
	var temp: String = path + SAVE_TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	if DirAccess.rename_absolute(temp, path) != OK:
		# The original is untouched; the sibling would only confuse the next
		# read, so it goes rather than being left to look like a newer save.
		DirAccess.remove_absolute(temp)
		return false
	return true


## The committed contents of `path`, or "" when there is no save at all.
##
## Two leftovers are possible from `write_text_atomically`, and they mean
## opposite things. A sibling with **no** committed file beside it is a write
## that finished and a rename that did not: the sibling is the newest complete
## save and is adopted. A sibling **beside** a committed file is a write that
## did not get as far as the rename, and may be incomplete: the committed file
## wins and the sibling is removed.
static func read_committed_text(path: String) -> String:
	var temp: String = path + SAVE_TEMP_SUFFIX
	if not FileAccess.file_exists(path):
		if not FileAccess.file_exists(temp):
			return ""
		if DirAccess.rename_absolute(temp, path) != OK:
			return ""
	elif FileAccess.file_exists(temp):
		DirAccess.remove_absolute(temp)
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## Parses save text into its dictionary, or an empty one if it is not a save.
##
## A `JSON` instance rather than `JSON.parse_string`, because the static call
## prints an engine ERROR line on bad input. A corrupt save is a condition this
## code handles, not an engine failure, and every gate in this project fails on
## that line.
static func parse_save_text(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data as Dictionary


## Keeps a copy of a save that could not be parsed, and names where it went.
##
## Never overwrites: each copy is stamped, so a player whose file breaks twice
## keeps both. Returns "" if nothing could be written, which the caller reports
## rather than treating as success.
static func back_up_unreadable(text: String, test_path: String = "") -> String:
	var path: String = test_path
	if path.is_empty():
		path = SAVE_UNREADABLE_BACKUP_PATH % int(Time.get_unix_time_from_system())
	if FileAccess.file_exists(path):
		return path
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(text)
	file.close()
	return path


## The exact payload written by save_game(). Release gates use this to time an
## isolated checkpoint inside the project instead of ever touching a player's
## real save slot while another development session may be running.
func serialized_save() -> String:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"unlocked": {
			"towers": unlocked_towers,
			"relics": unlocked_relics,
			"spells": unlocked_spells,
			"blueprints": unlocked_blueprints,
			"codex": codex_seen,
			"terrains": unlocked_terrains,
			"buildings": unlocked_buildings,
			"tools": tools,
			"sigils": sigils,
			"act3_cleared": act3_cleared,
		},
		"hero": {
			"level": hero_level,
			"xp": hero_xp,
			"attributes": hero_attributes,
			"attribute_points": hero_attribute_points,
			"ascension": ascension,
			"gatekeeper": gatekeeper,
			"skill_points": hero_skill_points,
			"tier_cleared": tier_cleared,
			"last_tier": last_tier_id,
			"story_seen": story_intro_seen,
		},
		"social": {
			"play_code": play_code,
			"friends": friends,
		},
		"stash": {
			"gear": stash,
			"equipped": equipped,
			"marks": marks,
			"orders": exchange_orders,
			"shards": shards,
		},
		# Additive and optional: a save written before spirits existed simply
		# has no "spirits" key and reads back as an empty collection, so this
		# needed no SAVE_VERSION bump and no migration path.
		"pantry": {
			"fish": fish,
		},
		"professions": {
			"xp": profession_xp,
		},
		# Additive, like the pantry and the spirits before it: a save written
		# before the mines simply has no "materials" key and reads back empty,
		# which is also what a new account is. No SAVE_VERSION bump, no
		# migration to get wrong.
		"materials": materials,
		"spirits": {
			"encounters": spirit_encounters,
			"bonded": spirit_bonded,
			"equipped": equipped_spirit,
		},
		# The living ones. Additive for the same reason everything above it is:
		# a save from before the pen reads back as an empty pen, which is what a
		# new account is, so there is no migration to get wrong.
		"pen": {
			"animals": pen,
			"taken": pen_taken,
		},
		# The frontier. One snapshot, and an unreadable one is dropped on load
		# rather than half-applied - half a fortress is worse than none, because
		# the player cannot tell which half is missing.
		# The Market's shelf. Unowned gear and the moment it was laid out, kept
		# so that quitting the game is not a way to re-roll a shop.
		"vendor": vendor,
		"expedition": expedition,
		"resource_cache": resource_cache,
		"chronicle": {
			"completed": completed_objectives,
		},
		"stats": {
			"runs_started": runs_started,
			"rifts_closed": rifts_closed,
			"camps_razed": camps_razed,
			"runs_won": runs_won,
			"best_distance": best_distance,
			"total_enemies_killed": total_enemies_killed,
			"highest_act": highest_act,
			"bosses_felled": bosses_felled,
			"forks_opened": forks_opened,
			"war_camps_razed": war_camps_razed,
			"dungeons_finished": dungeons_finished,
			"fish_caught_total": fish_caught_total,
			"swims": swims,
			"coop_runs": coop_runs,
			"achievements": achievements,
			"tutorial_done": tutorial_done,
		},
		"board": {
			"name": player_name,
			"best": best_runs,
			"pending": pending_runs,
		},
		"settings": settings,
	}
	return JSON.stringify(data, "\t")


func load_save() -> void:
	var text: String = read_committed_text(SAVE_PATH)
	if text.is_empty():
		if FileAccess.file_exists(SAVE_PATH):
			push_warning("MetaState: the save is empty; starting fresh.")
		return

	var data: Dictionary = parse_save_text(text)
	if data.is_empty():
		# Kept before it is ignored. The old behaviour warned and returned, and
		# the next save_game() then wrote a fresh account over the only copy of
		# what the player had - the one loss in this project nothing can undo.
		var kept: String = back_up_unreadable(text)
		if kept.is_empty():
			push_warning("MetaState: the save could not be read and no copy could be kept; starting fresh.")
		else:
			push_warning("MetaState: the save could not be read; kept a copy at %s and started fresh."
				% kept)
		return

	# An unknown version is discarded rather than half-read - but never before a
	# copy is kept.
	#
	# This is the one thing in the project that git cannot undo. Rolling the game
	# back is a checkout; rolling a player's unlock history back is impossible
	# once the file is gone, and a version mismatch happens in *both* directions:
	# a v4 build reading a v3 save, and a v3 build reading a save that v4 has
	# already migrated. The second is the dangerous one, because it is what
	# happens to anyone who tries a build and then goes back.
	#
	# GDD §52 requires migration to "never destroy the source save". Keeping the
	# original is the whole of that requirement, and it costs one file copy.
	var found_version: int = int(data.get("version", 0))
	if found_version != SAVE_VERSION and not MIGRATABLE_VERSIONS.has(found_version):
		_back_up_save(text, found_version)
		push_warning("MetaState: save version %d is not %d; kept a copy at %s and started fresh."
			% [found_version, SAVE_VERSION, SAVE_BACKUP_PATH % found_version])
		return
	if found_version != SAVE_VERSION:
		data = migrate_save(data, text)
		if data.is_empty():
			return

	var unlocked: Dictionary = data.get("unlocked", {}) as Dictionary
	unlocked_towers = _string_array(unlocked.get("towers", []))
	_seed_starting_roster()
	unlocked_relics = _string_array(unlocked.get("relics", []))
	unlocked_spells = _string_array(unlocked.get("spells", []))
	# Absent in saves written before 2026-08-31, which read as knowing nothing -
	# correct, because those runs never had a blueprint to find.
	unlocked_blueprints = _string_array(unlocked.get("blueprints", []))
	codex_seen = _string_array(unlocked.get("codex", []))
	unlocked_terrains = _string_array(unlocked.get("terrains", []))
	unlocked_buildings = _string_array(unlocked.get("buildings", []))
	act3_cleared = bool(unlocked.get("act3_cleared", false))
	tools = clampi(int(unlocked.get("tools", 0)), 0, Balance.TOOLS_MAX)
	sigils = clampi(int(unlocked.get("sigils", 0)), 0, Balance.SIGIL_MAX_RANK)
	_read_hero(data.get("hero", {}) as Dictionary)
	_read_pantry(data.get("pantry", {}) as Dictionary)
	_read_professions(data.get("professions", {}) as Dictionary)
	_read_materials(data.get("materials", {}) as Dictionary)
	_read_spirits(data.get("spirits", {}) as Dictionary)
	_read_pen(data.get("pen", {}) as Dictionary)
	vendor = data.get("vendor", {}) as Dictionary
	var front: Dictionary = data.get("expedition", {}) as Dictionary
	expedition = front if Expedition.is_readable(front) else {}
	_read_social(data.get("social", {}) as Dictionary)
	_read_stash(data.get("stash", {}) as Dictionary)
	_read_board(data.get("board", {}) as Dictionary)
	resource_cache = data.get("resource_cache", {}) as Dictionary
	completed_objectives = _unique_string_array(
		(data.get("chronicle", {}) as Dictionary).get("completed", []))

	var stats: Dictionary = data.get("stats", {}) as Dictionary
	runs_started = int(stats.get("runs_started", 0))
	rifts_closed = maxi(int(stats.get("rifts_closed", 0)), 0)
	camps_razed = maxi(int(stats.get("camps_razed", 0)), 0)
	runs_won = int(stats.get("runs_won", 0))
	best_distance = float(stats.get("best_distance", 0.0))
	total_enemies_killed = int(stats.get("total_enemies_killed", 0))
	highest_act = maxi(int(stats.get("highest_act", 0)), 0)
	bosses_felled = maxi(int(stats.get("bosses_felled", 0)), 0)
	forks_opened = maxi(int(stats.get("forks_opened", 0)), 0)
	war_camps_razed = maxi(int(stats.get("war_camps_razed", 0)), 0)
	dungeons_finished = maxi(int(stats.get("dungeons_finished", 0)), 0)
	fish_caught_total = maxi(int(stats.get("fish_caught_total", 0)), 0)
	swims = maxi(int(stats.get("swims", 0)), 0)
	coop_runs = maxi(int(stats.get("coop_runs", 0)), 0)
	achievements = _unique_string_array(stats.get("achievements", []))
	tutorial_done = bool(stats.get("tutorial_done", false))

	_read_settings(data.get("settings", {}) as Dictionary)

	# A piece that had never been named now has one, and it has to survive the
	# session that gave it. Once: the flag is cleared by the next `_read_stash`.
	if _named_a_piece:
		_named_a_piece = false
		save_game()

	save_loaded.emit()


## Merge only supported preferences so old saves inherit newly added defaults.
func _read_settings(loaded_settings: Dictionary) -> void:
	for key: Variant in loaded_settings:
		if settings.has(key):
			settings[key] = loaded_settings[key]


## Migrates a known public schema without ever mutating its source file first.
## The returned dictionary is consumed in memory and only becomes current when
## save_game() later completes successfully.
func migrate_save(data: Dictionary, source_text: String = "",
		backup_path: String = "") -> Dictionary:
	var found_version: int = int(data.get("version", 0))
	if found_version == SAVE_VERSION:
		return data
	if not MIGRATABLE_VERSIONS.has(found_version):
		return {}
	var original: String = source_text if not source_text.is_empty() else JSON.stringify(data, "\t")
	if not _back_up_save(original, found_version, backup_path):
		return {}
	var migrated: Dictionary = data.duplicate(true)
	var unlocked: Dictionary = migrated.get("unlocked", {}) as Dictionary

	# Applied in order, so a v1 save walks every step rather than jumping to the
	# current shape and skipping the ones in between.
	if found_version <= 1:
		if not migrated.has("resource_cache"):
			migrated["resource_cache"] = {}
		if not unlocked.has("buildings"):
			unlocked["buildings"] = []
	if found_version <= 2:
		unlocked["terrains"] = _renamed_terrains(unlocked.get("terrains", []))
	if not migrated.has("chronicle"):
		migrated["chronicle"] = {"completed": []}

	migrated["unlocked"] = unlocked
	migrated["version"] = SAVE_VERSION
	return migrated


## Rewrites unlocked terrain ids to their v4 region names, dropping nothing: an
## id that is already current, or that names no terrain at all, is passed through
## rather than discarded. A migration that quietly forgets an unlock is worse
## than one that carries a stale string.
func _renamed_terrains(ids: Array) -> Array:
	var out: Array = []
	for value: Variant in ids:
		var id: String = String(value)
		out.append(TERRAIN_RENAMES_V3.get(id, id))
	return out


func building_unlocked(id: String) -> bool:
	var data: BuildingData = ContentDB.building(id)
	return data != null and (not data.requires_unlock or unlocked_buildings.has(id))


func unlock_building(id: String) -> bool:
	if unlocked_buildings.has(id) or ContentDB.building(id) == null:
		return false
	unlocked_buildings.append(id)
	EventBus.unlock_earned.emit("building", id)
	return true


## Preserves a save this build cannot read.
##
## Deliberately never overwrites an existing backup: the *first* copy is the
## valuable one. Bouncing between two builds would otherwise have each launch
## re-back-up the file the previous launch already reset, and the original would
## be gone by the third run.
func _back_up_save(text: String, version: int, test_path: String = "") -> bool:
	# The override exists only so the regression gate can prove byte preservation
	# in an isolated fixture. Shipping callers always use the versioned path.
	var path: String = test_path if not test_path.is_empty() else SAVE_BACKUP_PATH % version
	if FileAccess.file_exists(path):
		return true
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("MetaState: could not write save backup to %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


## JSON gives back an untyped Array; the rest of the codebase wants Array[String].
func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item: Variant in (value as Array):
			out.append(str(item))
	return out


## Chronicle ids are counted in the front door, so a duplicated or hand-edited
## save must not claim more completed deeds than the game contains. Unknown ids
## are preserved for forward/backward compatibility; only duplicates and empty
## entries are discarded.
func _unique_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	for id: String in _string_array(value):
		if not id.is_empty() and not out.has(id):
			out.append(id)
	return out


# --- Wildlife Spirit Companions ----------------------------------------------

## Records one encounter with a variant and reports what changed.
##
## Returns a dictionary the caller can announce from: `discovered` for the first
## sighting of a variant, `bonded` for the encounter that completes it, and the
## counts either way. Both are wanted - meeting a Rare Fox for the first time is
## worth saying out loud, and so is the fifth one.
##
## **A shiny encounter also feeds the plain variant of the same rarity.** Finding
## something rare must never be worth *less* than finding something ordinary, and
## without this a player chasing the normal Rare Wolf would groan at a shiny one.
## `trait_id` is the personality of the *particular animal* this encounter was
## with. It is banked only on the encounter that completes the bond, because that
## is the animal you actually took - meeting nine foxes and bonding the tenth
## gives you the tenth one's temperament, which is the one you were standing next
## to when it agreed to come.
## A bond made by raising one rather than by meeting many.
##
## **The same entry, reached another way.** An imprint writes the key every
## sighting eventually would; it does not write a level, a stat or a second
## kind of spirit, so working rule 7 is exactly where it was and a raised
## companion is no stronger than a met one. What the egg bought is the *time*,
## and it was paid for by carrying it home through a species that wanted it
## back.
##
## Returns true when this is a bond the account did not already have.
func bond_from_egg(species_id: String, rarity: int, shiny: bool,
		trait_id: String = "") -> bool:
	if species_id.is_empty():
		return false
	var key: String = SpiritBond.key(species_id, rarity, shiny)
	# The sighting is recorded either way: an egg is an encounter with the
	# animal, and the journal should say so even when the bond already stood.
	spirit_encounters[key] = int(spirit_encounters.get(key, 0)) + 1
	if spirit_bonded.has(key):
		save_game()
		return false
	spirit_bonded[key] = trait_id
	RunState.note_kept("spirits", 1.0)
	save_game()
	return true


func record_spirit_encounter(species_id: String, rarity: int, shiny: bool,
		trait_id: String = "") -> Dictionary:
	var result: Dictionary = {"keys": [], "discovered": [], "bonded": []}
	if species_id.is_empty():
		return result
	# Built rather than written as a ternary: a conditional expression yields an
	# untyped Array, which will not assign to Array[bool] and fails at runtime
	# rather than at parse time.
	var wanted: Array[bool] = [false]
	if shiny:
		wanted = [true, false]
	for is_shiny: bool in wanted:
		var key: String = SpiritBond.key(species_id, rarity, is_shiny)
		var before: int = int(spirit_encounters.get(key, 0))
		if before == 0:
			result["discovered"].append(key)
		spirit_encounters[key] = before + 1
		result["keys"].append(key)
		if not spirit_bonded.has(key) \
				and before + 1 >= SpiritBond.needed(rarity, is_shiny):
			# The value carries the personality. Storing it here rather than in
			# a second dictionary is what keeps this save additive: a file
			# written before traits existed has `true` in this slot, which reads
			# back as "no personality" and costs nothing to have.
			spirit_bonded[key] = trait_id
			result["bonded"].append(key)
			RunState.note_kept("spirits", 1.0)
	save_game()
	return result


func spirit_encounter_count(bond_key: String) -> int:
	return int(spirit_encounters.get(bond_key, 0))


func spirit_is_bonded(bond_key: String) -> bool:
	return spirit_bonded.has(bond_key)


## The personality this bonded variant carries, or "" for none.
##
## Empty is a supported answer, not a bug: every bond made before 2026-09-01 has
## no personality and must keep working exactly as it did.
func spirit_trait(bond_key: String) -> String:
	var stored: Variant = spirit_bonded.get(bond_key, "")
	return String(stored) if stored is String else ""


## Whether a variant has ever been met. Drives the journal's silhouettes: an
## unmet variant is a question mark rather than a row of zeroes, because the
## discovery is meant to be part of the reward.
func spirit_is_known(bond_key: String) -> bool:
	return spirit_encounter_count(bond_key) > 0


## Equips a bonded spirit, or clears the slot with "".
## --- The frontier -----------------------------------------------------------

## **Bank the road as it stands.** Called by an extraction and nothing else.
func bank_expedition(snapshot: Dictionary) -> bool:
	if not Expedition.is_readable(snapshot):
		return false
	expedition = snapshot
	save_game()
	return true


## Whether there is a frontier to go back to.
func has_expedition() -> bool:
	return Expedition.is_readable(expedition)


## **Give the banked road up.**
##
## Called when a Warden takes a fresh road or starts at an act rather than
## resuming (owner ruling, 2026-09-17). Deliberately *not* called when a run
## ends badly: a wipe leaves the front where it was, which is the whole of the
## anti-frustration rule, and a door that quietly cleared it on a loss would
## make pushing deeper horrifying rather than exciting.
##
## Saves immediately. A front cleared in memory and still on disk comes back on
## the next launch, and a player who took a fresh road would be offered the
## campaign they had just abandoned.
func clear_expedition() -> void:
	if expedition.is_empty():
		return
	expedition = {}
	save_game()


## **Mend every damaged fortification on the banked front.**
##
## Returns why it could not, or "" on success. Validate, then spend, then mend -
## in that order and with the whole bill checked first, which is the rule the
## forge is built under: a mend that ate half a player's timber and then found
## it was short of ore is worse than one that refuses.
func mend_expedition() -> String:
	if not has_expedition():
		return "There is no front to mend."
	var bill: Dictionary = Expedition.repair_bill(expedition)
	if bill.is_empty():
		return "Nothing out there is damaged."
	for id: Variant in bill:
		if int(materials.get(String(id), 0)) < int(bill[id]):
			return "Not enough %s." % String(id).replace("_", " ")
	for id: Variant in bill:
		spend_material(String(id), int(bill[id]))
	expedition = Expedition.mend(expedition)
	save_game()
	return ""


## **Give up the frontier.** Starting a fresh campaign from Act I abandons it,
## and the player is asked first - this is the one thing here that destroys
## something they spent hundreds of waves building.
func abandon_expedition() -> void:
	expedition = {}
	save_game()


## --- The pen ---------------------------------------------------------------

## Reads the kept animals off a save. Anything malformed is dropped rather than
## trusted: this list is the one place a bad row would put a companion on the
## road with no species to draw.
func _read_pen(stored: Dictionary) -> void:
	pen.clear()
	pen_taken = ""
	for row: Variant in (stored.get("animals", []) as Array):
		var animal := row as Dictionary
		if animal == null:
			continue
		var species: String = String(animal.get("species", ""))
		if species.is_empty() or ContentDB.wildlife_kinds.get(species, null) == null:
			continue
		pen.append({
			"uid": String(animal.get("uid", _fresh_pen_uid())),
			"species": species,
			"rarity": clampi(int(animal.get("rarity", 0)), 0, 3),
			"shiny": bool(animal.get("shiny", false)),
			"trait": String(animal.get("trait", "")),
			# **How hurt it is, and when that was last worked out.** Absent on
			# every entry written before 2026-09-16, which reads as a whole
			# animal - which is what those animals were. See `pen_health`.
			"health": clampf(float(animal.get("health", 1.0)), 0.0, 1.0),
			"healed_at": float(animal.get("healed_at", 0.0)),
		})
		if pen.size() >= Balance.PEN_CAPACITY:
			break
	var taken: String = String(stored.get("taken", ""))
	if not taken.is_empty() and penned(taken).is_empty():
		# An animal that was out when the game closed and is not in the list is
		# not a companion, it is a dangling name. Better an empty field than a
		# road with a ghost on it.
		taken = ""
	pen_taken = taken


## A name for one animal, unique within this account's pen.
func _fresh_pen_uid() -> String:
	var taken: Dictionary = {}
	for animal: Dictionary in pen:
		taken[String(animal.get("uid", ""))] = true
	var next: int = pen.size() + 1
	while taken.has("pen%d" % next):
		next += 1
	return "pen%d" % next


## The animal with this name, or an empty dictionary.
func penned(uid: String) -> Dictionary:
	for animal: Dictionary in pen:
		if String(animal.get("uid", "")) == uid:
			return animal
	return {}


## Whether the pen has room for one more.
func pen_has_room() -> bool:
	return pen.size() < Balance.PEN_CAPACITY


## **Put a living animal in the pen.** Returns its name, or empty if it is full.
##
## The caller is expected to have bonded the variant separately: hatching does
## both, because meeting an animal and keeping one are two different facts and
## the journal should record the first whether or not there is room for the
## second.
func pen_add(species_id: String, rarity: int, shiny: bool,
		trait_id: String = "", health: float = 1.0) -> String:
	if species_id.is_empty() or not pen_has_room():
		return ""
	if ContentDB.wildlife_kinds.get(species_id, null) == null:
		return ""
	var uid: String = _fresh_pen_uid()
	pen.append({
		"uid": uid,
		"species": species_id,
		"rarity": clampi(rarity, 0, 3),
		"shiny": shiny,
		"trait": trait_id,
		# Something caught is caught *hurt* - that is how it was caught - and
		# the pen is where it gets better.
		"health": clampf(health, 0.0, 1.0),
		"healed_at": Time.get_unix_time_from_system(),
	})
	save_game()
	return uid


# --- The pen mends, on the wall clock (2026-09-16) ----------------------------------------

## **How whole an animal in the pen is, 0 to 1**, reckoned now.
##
## Computed on read rather than kept up to date on write: a number that is only
## correct after somebody remembered to refresh it is a number that is wrong, and
## this is the one place that works it out, so the pen screen and the companion
## that walks out of it cannot disagree.
##
## The rate is the road's own share of the pool, times `PEN_REGEN_SCALE` -
## nothing is hunting it in there and somebody is feeding it - so a pen heals a
## bear and a rabbit in the same time, respective to each one's own maximum,
## which is the shape the owner asked for.
func pen_health(uid: String) -> float:
	var animal: Dictionary = penned(uid)
	if animal.is_empty():
		return 0.0
	return _reckon_pen_health(animal)


func _reckon_pen_health(animal: Dictionary) -> float:
	var health: float = clampf(float(animal.get("health", 1.0)), 0.0, 1.0)
	if health >= 1.0:
		return 1.0
	var stamped: float = float(animal.get("healed_at", 0.0))
	var now: float = Time.get_unix_time_from_system()
	if stamped <= 0.0:
		animal["healed_at"] = now
		return health
	# **A clock that went backwards mends nothing.** A player who changes their
	# system time, or a machine correcting itself, must not be able to make an
	# animal *un*-heal; the stamp is simply moved up to now.
	var elapsed: float = now - stamped
	if elapsed <= 0.0:
		animal["healed_at"] = now
		return health
	# Capped, because coming back after a month should not be a different
	# feature from coming back after a day.
	elapsed = minf(elapsed, Balance.PEN_REGEN_MAX_HOURS * 3600.0)
	var rate: float = Balance.WILDLIFE_REGEN_SHARE * Balance.WILDLIFE_REGEN_CALM_SCALE \
		* Balance.PEN_REGEN_SCALE
	health = clampf(health + rate * elapsed, 0.0, 1.0)
	animal["health"] = health
	animal["healed_at"] = now
	return health


## How long until this one is whole, in seconds of real time. Zero when it is.
## Used by the pen screen, which says it in hours and minutes rather than as a
## bar creeping - a bar that moves a pixel an hour reads as a bar that is stuck.
func pen_seconds_to_whole(uid: String) -> float:
	var health: float = pen_health(uid)
	if health >= 1.0:
		return 0.0
	var rate: float = Balance.WILDLIFE_REGEN_SHARE * Balance.WILDLIFE_REGEN_CALM_SCALE \
		* Balance.PEN_REGEN_SCALE
	return (1.0 - health) / maxf(rate, 0.000001)


## An animal came home hurt - off the road, or out of a run. Stamped now, so its
## mending starts from this moment rather than from whenever it was last read.
func pen_set_health(uid: String, health: float) -> void:
	for animal: Dictionary in pen:
		if String(animal.get("uid", "")) != uid:
			continue
		animal["health"] = clampf(health, 0.0, 1.0)
		animal["healed_at"] = Time.get_unix_time_from_system()
		save_game()
		return


## **Let one go.** It leaves the pen and the account keeps the bond, which is the
## bound this whole thing rests on: releasing costs the animal, never the
## journal entry that says you raised one.
func pen_release(uid: String) -> bool:
	for index: int in pen.size():
		if String(pen[index].get("uid", "")) != uid:
			continue
		if pen_taken == uid:
			pen_taken = ""
		pen.remove_at(index)
		save_game()
		return true
	return false


## **Take one out for the next expedition.** Empty puts everything back.
##
## Refused during a run: what goes on the road is decided before leaving, which
## is what makes taking a favourite a decision with a cost rather than a swap
## made the moment one looks like dying.
func pen_take(uid: String, freshly_caught: bool = false) -> bool:
	# **The mid-run refusal, and the one thing that is allowed through it.**
	#
	# Swapping animals mid-run is the decision being made after the risk instead
	# of before it, which is what the whole pen rests on. An animal *caught this
	# minute* is not a swap: it came off the road, it was never safe in the pen,
	# and putting it to work is the reason anybody threw a rope. It can only ever
	# be made safer from there - see `pen_stand_down`.
	if not freshly_caught and RunState.phase != RunState.Phase.ENDED:
		return false
	if uid.is_empty():
		pen_taken = ""
		save_game()
		return true
	if penned(uid).is_empty():
		return false
	pen_taken = uid
	save_game()
	return true


## **Put the one that is out back in the pen**, allowed at any time.
##
## Owner, 2026-09-16: a caught animal "can also be toggled off so that it can
## stay protected in case it is low health and players dont want to risk it
## dying so that they can take it to their pen".
##
## Not gated on the phase, unlike taking one out, and the asymmetry is the whole
## point: this can only ever make an animal *safer*. The rule the pen is built
## under is that you cannot duck the risk you already accepted by swapping to a
## fresh animal mid-fight; standing one down accepts the loss of it for the rest
## of the run instead, which is the opposite of ducking.
func pen_stand_down() -> bool:
	if pen_taken.is_empty():
		return false
	pen_taken = ""
	save_game()
	return true


## The animal currently out of the pen, or an empty dictionary.
func pen_companion() -> Dictionary:
	return penned(pen_taken) if not pen_taken.is_empty() else {}


## **It did not come home.** The animal is gone from the pen for good.
##
## The bond is untouched, on purpose and as the bound: the player can raise
## another of that variant, and the journal still says they raised this one.
func pen_lose_taken() -> bool:
	if pen_taken.is_empty():
		return false
	var lost: String = pen_taken
	pen_taken = ""
	for index: int in pen.size():
		if String(pen[index].get("uid", "")) == lost:
			pen.remove_at(index)
			save_game()
			return true
	save_game()
	return false


func equip_spirit(bond_key: String) -> bool:
	if bond_key.is_empty():
		equipped_spirit = ""
		save_game()
		EventBus.spirit_equipped.emit("")
		return true
	if not spirit_is_bonded(bond_key):
		return false
	equipped_spirit = bond_key
	save_game()
	EventBus.spirit_equipped.emit(bond_key)
	return true


## How many variants are bonded, for a heading.
func spirit_bond_count() -> int:
	return spirit_bonded.size()


## Reads the spirit collection, defaulting to empty.
##
## Every field is optional. A save from before this system existed has no
## "spirits" key at all, and one written by a future build with more in it loses
## only what this version cannot read - neither is corruption, and neither
## needed a SAVE_VERSION bump.
func _read_spirits(block: Dictionary) -> void:
	spirit_encounters = {}
	for key: Variant in (block.get("encounters", {}) as Dictionary):
		var count: int = int((block["encounters"] as Dictionary)[key])
		if count > 0:
			spirit_encounters[String(key)] = count
	spirit_bonded = {}
	for key: Variant in (block.get("bonded", {}) as Dictionary):
		# `true` from a save written before personalities existed; a string from
		# any save since. Both mean "bonded"; only the second means anything more.
		var stored: Variant = (block["bonded"] as Dictionary)[key]
		spirit_bonded[String(key)] = String(stored) if stored is String else ""
	equipped_spirit = String(block.get("equipped", ""))
	# A spirit that is equipped but not bonded is a save somebody edited, or one
	# written by a build whose thresholds were different. Clearing it is safer
	# than summoning something the collection does not contain.
	if not equipped_spirit.is_empty() and not spirit_bonded.has(equipped_spirit):
		equipped_spirit = ""
