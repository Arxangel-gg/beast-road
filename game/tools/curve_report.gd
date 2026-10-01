extends Node

## What the difficulty curve actually looks like, wave by wave.
##
##   godot --headless --path game res://tools/curve_report.tscn
##   godot --headless --path game res://tools/curve_report.tscn -- --players=2
##
## A report, never a gate. Balance is judgement, and a red build is the wrong way
## to express an opinion about pacing — see CLAUDE.md §7 on why the audit score is
## a number and not a claim.
##
## What it exists to answer: "the game scales too difficult too early" is a real
## report and an unfalsifiable one. Three sampled waves cannot tell a smooth ramp
## from a cliff, and the two numbers that matter are never in the same place. So
## this walks a whole run and puts threat and capability on one line.
##
## **Threat** is the effective HP a formation delivers: bodies × per-body HP
## scale. That is what has to be removed before the town is reached, and it is
## the product of two curves that grow independently — pack size and HP scale —
## which is exactly how a difficulty cliff gets built without anyone choosing one.
##
## **Capability** is what the player can have killed it with: the total tower
## damage per second affordable from cumulative income by that wave, at the level
## cap the Forge has reached. It is deliberately generous — it assumes perfect
## spending — because a curve the *best* case cannot hold is unarguable.
##
## The column that matters is PRESSURE, threat over capability. Its absolute
## value means little; its **shape** is the whole point. A flat line is a game
## that stays as hard as it started. A step is a wall.

## Six build spots per lane: an inner/middle/outer trio on each flank of the road.
## Read from Balance rather than restated, so the six-spot road cannot leave
## this report quietly measuring a three-spot one.
const SLOTS_PER_LANE: int = 10

## Roughly how long a formation stays on the road once it has finished walking
## on, before the last body is dealt with. Added to the spawn time and the
## between-wave interval to get a wave cycle.
##
## It is an estimate and it is load bearing: acts advance on distance, distance
## accrues in real time, so the length of a wave cycle is what decides how many
## waves an act contains. Getting it wrong moves every act boundary. [TUNE]
const ENGAGEMENT_SECONDS: float = Balance.WAVE_ENGAGEMENT_SECONDS

## Why the between-wave breather is **not** in the wave cycle.
##
## It looks like an omission and it is not. `Journey.stop()` runs the moment a
## breather opens, so the beast stops walking and no distance accrues for as long
## as the player stands there. Distance is what advances acts, so a breather -
## at fifteen seconds or at thirty - moves no act boundary and changes nothing
## this report measures.
##
## Adding `PREPARATION_BETWEEN_WAVES` to the cycle here would be a plausible
## "fix" that silently made every act shorter in the model than it is in the
## game. Written down so the next person to notice the gap does not close it.

## Hard stop, in case a pacing change ever makes a run much longer than intended.
const MAX_WAVES: int = 1200

var _rows: Array[Dictionary] = []

## Cumulative Gold from kills, carried across waves.
var _earned_gold: float = 0.0
## What the last _affordable_dps call managed to buy. Reported rather than
## inferred: a capability that stops climbing is either out of Gold or out of
## levels, and those two want opposite fixes.
var _bought_towers: int = 0
var _bought_level: int = 1

## How many players the run is being measured for.
##
## Co-op scales the count of enemies and nothing else (`COOP_DESIGN.md` §5), and
## both sides of that move together: twice the bodies, but also two heroes and a
## shared purse earning from twice the kills. Whether those cancel is exactly the
## question this report exists to answer, so it is asked rather than assumed -
## run it at 1 and at 2 and compare the pressure columns.
##
## Not a network session. `WaveDirector.body_scale_for` is the one expression of
## the rule and is asked directly, so this cannot drift from what the director
## actually does when two people are playing.
var _players: int = 1
## Whether to model the returning player's bonded spirit. Off by default: the
## curve is tuned for a first run, which has none.
var _with_companion: bool = false
## **The third capped scale** (owner ruling, 2026-09-17). Negative means
## "read the account", which is what every other input to this model does;
## `--ascension=N` points it at a rank instead.
##
## **This is how Nightmare and Hell are re-measured.** A Warden arriving at
## Nightmare has climbed Normal's ladder, so they hold `GatekeeperTrials.STAGES`
## ranks; one arriving at Hell has climbed two. `expected_rank_for_tier` says
## so rather than a number being typed into a run script.
var _ascension: int = -1
var _body_scale: float = 0.0

## **Augments** (2026-09-26): whether the road's drafts are modelled, and the
## bodies killed so far, which is what the road rank is paid in. On by default -
## an augment level the model does not carry is forbidden, exactly as an
## ascension rank is - and `--no-augments` prints the road without them, so the
## size of what the drafts buy can be read as a difference.
var _with_augments: bool = true
## **Which road, and which Warden walks it** (2026-10-01: *"a difficulty
## balancing that considers augment builds ... gear and levels ... of all
## difficulties"*). `--tier=` measures the Long Road, the Iron Road or the
## Chainmaker's Road; with a tier named the report dresses the Warden that tier
## expects at each act - its boss level, the points placed by
## `EXPECTED_ATTRIBUTE_SHARE`, and the gear `CampaignTierData.expected_gear_*`
## names, worn through the doors a stash equips through - so what is measured
## is the road against the Warden it was balanced for. `--warden=account`
## measures the profile instead, as this report always did.
var _tier_id: String = ""
## The last row of every act in each party size's replay, kept so the boss
## readout can be asked about a party as well as a Warden alone.
var _party_act_rows: Dictionary = {}
## Pressure summed by act over the last replay, as (sum, waves).
var _replay_acts: Dictionary = {}
var _boss_failures: int = 0

## **How long a boss may stand against the defence a walked road holds**, in
## the model's best-case seconds (2026-10-01). Under the floor a giant is a
## speed bump; over the ceiling it is the sponge reported on 2026-09-21. The
## model lands every hit, so play is longer than this by however much of the
## Arsenal misses - which is why the band is short.
const BOSS_SECONDS_BAND: Vector2 = Vector2(9.0, 40.0)
## And a party's boss stands about as long as one Warden's. The ceiling is
## wide because the model's party hand lags a Warden's alone in Act III - the
## seats draft at a solo road's pace on bigger waves - which reads 1.5x there
## and about 1.1x everywhere else.
const BOSS_PARTY_RATIO: Vector2 = Vector2(0.7, 1.6)
## **Which build the draft makes** (2026-10-01). `best` is the planner this
## report always had - a player who knows the deck and builds toward the summit.
## `warden`, `towers` and `town` hold only weapons anchored there (and the
## catalysts every build takes), so each kind of build can be measured against
## the others. `draft` plans nothing: each pick is the best of three cards drawn
## from what the game may deal, which is the player reading three cards at a
## time rather than the one reading the whole deck. `reader` drafts from the
## same three and reads what they say: an earned evolution first, then a level
## on a weapon whose catalyst it holds, then the other half of a pair it has
## begun, and otherwise the best of the three - and never leaves half a pair
## behind. The cards name their pairs since 2026-10-01, so this is the player
## the draft is now written for; `draft` stays as the floor, the player who
## reads nothing but the numbers.
var _build: String = "best"


## Whether this build drafts from what the game deals rather than reading the
## whole deck.
func _drafts() -> bool:
	return _build == "draft" or _build == "reader"
var _draft_dice := RandomNumberGenerator.new()
var _expected_warden: bool = false
var _dressed_act: int = -1
## What the dressed Warden stands with at each act: their health pool and the
## share of every blow their Resolve and rank take off. For the survival line.
var _expected_pool: Dictionary = {}
var _expected_mitigation: Dictionary = {}
var _expected_damage: Dictionary = {}
## The fewest blows the expected Warden survives in any act, for the summary.
var _survival_floor: float = 0.0
var _road_kills: float = 0.0
## **The Arsenal the drafts have built so far** (2026-09-27): card id -> level,
## grown greedily a draft at a time and carried from wave to wave, because the
## drafts only ever grow. See `_deal_the_augments_so_far`.
var _arsenal: Dictionary = {}
var _arsenal_picks: int = 0
## **The kinds of draft a drafting build has taken** (2026-10-01): an act's boss
## deals at its Rare floor and a Tempering offers held cards to grow, and the
## rerolls a road holds. The planner reads the whole deck for every pick, so for
## it the kind never mattered; for a player drafting from three it is most of
## what separates a good draft from a bad one.
var _boss_picks: int = 0
var _camp_picks: int = 0
## Whether the model razes the first camp of each act for its draft;
## `--no-camp-drafts` measures a player who never leaves the road.
var _camp_drafts: bool = true
var _temper_picks: int = 0
var _rerolls: int = Balance.AUGMENT_REROLLS_START
## Which deal a drafting build is handed. One seed of three-card offers is one
## player's luck, so a drafting build is read as a mean over several salts.
var _draft_salt: int = 0
var _offer_count: int = Balance.ROAD_CARD_OFFER_COUNT
var _draft_luck: int = 0
var _rerolls_start: int = Balance.AUGMENT_REROLLS_START
var _draft_floor: int = Balance.AUGMENT_FLOOR_RANK
var _tempering: bool = false
## The hand the main run held at the end of each act, for the readout.
var _hand_by_act: Dictionary = {}
## The hand the model builds toward, planned once a pass - see `_plan_the_hand`.
var _target: Array[String] = []


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--players="):
			_players = maxi(int(argument.split("=")[1]), 1)
		elif argument.begins_with("--ascension="):
			_ascension = clampi(int(argument.split("=")[1]), 0, Balance.ASCENSION_MAX)
		elif argument == "--companion":
			_with_companion = true
		elif argument == "--no-augments":
			_with_augments = false
		elif argument.begins_with("--build="):
			_build = argument.split("=")[1]
		elif argument.begins_with("--luck="):
			_draft_luck = clampi(int(argument.split("=")[1]), 0, Balance.AUGMENT_LUCK_CAP)
		elif argument == "--no-camp-drafts":
			_camp_drafts = false
		elif argument.begins_with("--draft-salt="):
			_draft_salt = int(argument.split("=")[1])
		# Reporting only, like `--body-scale`: how much a draft's choice is
		# worth, read without a game change.
		elif argument.begins_with("--offer-count="):
			_offer_count = maxi(int(argument.split("=")[1]), 1)
		elif argument.begins_with("--rerolls="):
			_rerolls_start = maxi(int(argument.split("=")[1]), 0)
			_rerolls = _rerolls_start
		elif argument.begins_with("--tier="):
			_tier_id = argument.split("=")[1]
			_expected_warden = true
		elif argument == "--warden=account":
			_expected_warden = false
		elif argument == "--warden=expected":
			_expected_warden = true
		# An override, so a scaling value can be swept without editing Balance
		# and rebuilding an opinion each time. Reporting only - the game always
		# reads the table.
		elif argument.begins_with("--body-scale="):
			_body_scale = maxf(float(argument.split("=")[1]), 0.01)
	RunState.reset()
	if not _tier_id.is_empty():
		RunState.tier_id = _tier_id
	if _expected_warden:
		# The Warden is dressed for every act: nothing of it may reach the save.
		MetaState.hold_saves()
		if _ascension < 0:
			_ascension = expected_rank_for_tier(RunState.tier().id)
	var packed: PackedScene = load("res://scenes/run/run.tscn")
	var run: Run = packed.instantiate() as Run
	add_child(run)
	await get_tree().process_frame
	run.journey.stop()
	run.battlefield.wave_director.stop()

	# Walked rather than sampled. Acts advance on distance and distance accrues in
	# real time, so where an act boundary falls depends on how long each wave
	# cycle takes - which depends on the size of the wave. Indexing acts off the
	# wave number instead put all thirty waves in Act 1 and hid both boundaries,
	# which are the two places a curve is most likely to have a cliff in it.
	var director: WaveDirector = run.battlefield.wave_director
	var distance: float = 0.0
	var act_wave: int = 0
	var act: int = 1
	for wave: int in range(1, MAX_WAVES + 1):
		var now_act: int = 1
		# To the summit: the ascent is an act since 2026-09-21, with its own
		# terrain and roster, and `act_end_distance` knows where it ends.
		while now_act < Balance.FINAL_ASCENT_ACT \
				and distance >= Balance.act_end_distance(now_act):
			now_act += 1
		if now_act != act:
			act = now_act
			act_wave = 0
		act_wave += 1

		var row: Dictionary = _measure(director, wave, act, act_wave, distance)
		_rows.append(row)
		_hand_by_act[act] = _arsenal.duplicate()

		var cycle: float = Balance.WAVE_INTERVAL \
			+ float(row["bodies"]) * Balance.WAVE_SPAWN_SPACING \
			+ ENGAGEMENT_SECONDS
		distance += cycle * Balance.BEAST_BASE_SPEED
		if distance >= Balance.act_end_distance(Balance.FINAL_ASCENT_ACT):
			break

	_print_table()
	var bad: int = _judge_party_scaling()
	bad += _judge_escalation()
	bad += _judge_the_drafted_road()

	# Tear gameplay down before draining audio. The full run owns deferred
	# wildlife arrivals; stopping Sfx first allowed one of those callbacks to
	# start a vocal decoder after the stop and immediately before headless exit,
	# leaking its OGG playback/resource objects in CI.
	run.queue_free()
	for _frame: int in 2:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 18:
		await get_tree().process_frame
	get_tree().quit(bad)


## **The Warden this tier expects at this act**, dressed into the account.
##
## Level: the tier's own `expected_level`. Points: `level - 1`, placed by
## `EXPECTED_ATTRIBUTE_SHARE`. Gear: a piece in every slot, of the kind in that
## slot that favours the attribute the slot is dressed for, at the rarity and
## level the tier names for this act - worn through `MetaState.equip`, so its
## points, its affixes and any set it makes reach the model the way they reach
## the fight. Named by slot rather than drawn, so the same tier is the same
## Warden on every run of the report.
func _dress_expected(act: int) -> void:
	if not _expected_warden or act == _dressed_act:
		return
	_dressed_act = act
	var tier: CampaignTierData = RunState.tier()
	if tier == null:
		return
	var level: int = tier.expected_level(mini(act, Balance.ACT_COUNT))
	MetaState.hero_level = level
	var points: int = maxi(level - 1, 0)
	var placed: Array[int] = []
	var given: int = 0
	for share: float in Balance.EXPECTED_ATTRIBUTE_SHARE:
		var each: int = int(floor(float(points) * share))
		placed.append(each)
		given += each
	placed[RunState.Attribute.MIGHT] += points - given
	MetaState.hero_attributes = placed
	# The run reads its own copy, taken when the road began: the dressed
	# Warden has to be in both or the fight-side readers see a new one.
	RunState.hero_attributes = placed.duplicate()
	RunState.hero_level = level
	var along: float = clampf(float(act - 1) / float(maxi(Balance.ACT_COUNT - 1, 1)), 0.0, 1.0)
	var rarity_now: float = lerpf(float(tier.expected_gear_rarity.x), float(tier.expected_gear_rarity.y), along)
	var level_now: float = lerpf(float(tier.expected_gear_level.x), float(tier.expected_gear_level.y), along)
	var slots: int = GearData.Slot.size()
	MetaState.stash.clear()
	MetaState.equipped.clear()
	for slot: int in slots:
		var kind: GearData = _expected_kind(slot, tier.order)
		if kind == null:
			continue
		# **A slot at a time.** Gear is found a piece at a time, so between two
		# rarities a Warden wears some of each: each slot climbs at its own
		# point of the road rather than all nine on one act, which made the
		# curve jump where nothing in the game does.
		var step: float = (float(slot) + 0.5) / float(slots)
		var rarity: int = clampi(int(floor(rarity_now + step)), tier.expected_gear_rarity.x,
			tier.expected_gear_rarity.y)
		var gear_level: int = clampi(int(floor(level_now + step)), tier.expected_gear_level.x,
			tier.expected_gear_level.y)
		var piece: Dictionary = Stash.make(kind.id, rarity, gear_level)
		# A fixed name, so the affixes a piece rolls from it are the same on
		# every run of the report - and a new one each act, because what is
		# worn is cached against the names worn and the whole walk is one frame.
		piece["uid"] = 7000 + act * 100 + slot
		if MetaState.take_gear(piece):
			MetaState.equip(slot, MetaState.stash.size() - 1)
	Modifiers.rebuild()
	# What they stand with, through the same constants the hero reads: Vigour
	# and the bosses already felled on this road for the pool, Resolve and
	# the rank inside Resolve's ceiling for the share a blow loses.
	var vigour: float = float(WardenSheet.attribute_of(null, RunState.Attribute.VIGOUR))
	var resolve: float = float(WardenSheet.attribute_of(null, RunState.Attribute.RESOLVE))
	_expected_pool[act] = (Balance.HERO_MAX_HP + WardenSheet.value_of(null, Modifiers.HERO_MAX_HP)) \
		* (1.0 + vigour * Balance.HERO_VIGOUR_PER_POINT + float(act - 1) * Balance.BOSS_FELLED_VIGOUR)
	_expected_mitigation[act] = minf(resolve * Balance.HERO_RESOLVE_MITIGATION_PER_POINT
		+ minf(float(ascension_rank()) * Balance.ASCENSION_MITIGATION_PER_RANK,
			Balance.ASCENSION_MITIGATION_CAP), Balance.HERO_RESOLVE_MITIGATION_CAP)
	var might: float = float(WardenSheet.attribute_of(null, RunState.Attribute.MIGHT))
	_expected_damage[act] = (1.0 + might * Balance.HERO_MIGHT_PER_POINT) * _core_scale(Modifiers.HERO_DAMAGE)


## The attribute each slot is dressed for in the expected Warden.
const _SLOT_LEANS: Array[int] = [
	RunState.Attribute.MIGHT,      # Weapon
	RunState.Attribute.VIGOUR,     # Armour
	RunState.Attribute.MIGHT,      # Charm
	RunState.Attribute.RESOLVE,    # Helmet
	RunState.Attribute.MIGHT,      # Gloves
	RunState.Attribute.SWIFTNESS,  # Boots
	RunState.Attribute.MIGHT,      # Ring
	RunState.Attribute.FOCUS,      # Amulet
	RunState.Attribute.RESOLVE,    # Cape
]


## The kind for a slot: one that favours the slot's attribute where the slot
## has one, the heaviest of those, and by name on a tie.
func _expected_kind(slot: int, tier_order: int) -> GearData:
	var lean: int = _SLOT_LEANS[slot] if slot < _SLOT_LEANS.size() else RunState.Attribute.MIGHT
	var best: GearData = null
	var best_any: GearData = null
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind == null or int(kind.slot) != slot or kind.trophy or kind.min_tier > tier_order:
			continue
		if best_any == null or _heavier(kind, best_any):
			best_any = kind
		if kind.attribute == lean and (best == null or _heavier(kind, best)):
			best = kind
	return best if best != null else best_any


func _heavier(kind: GearData, than: GearData) -> bool:
	return kind.base_points > than.base_points \
		or (kind.base_points == than.base_points and kind.id < than.id)


## One wave, with the run wound forward to where that wave happens.
func _measure(director: WaveDirector, wave: int, act: int, act_wave: int,
		distance: float) -> Dictionary:
	RunState.act = act
	RunState.wave_number = wave
	RunState.distance_travelled = distance
	_dress_expected(act)
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	RunState.terrain_id = terrain.id if terrain != null else "jungle"
	director._act_wave = act_wave
	_bank_the_cores_won_so_far(act)
	# Measured in daylight. Night is a modifier on top of everything here and
	# folding it in would hide which curve is doing the work.
	DayNight._apply(0.25)

	var lanes: int = director._progressive_lane_count(act_wave)
	var per_lane: int = director._wave_size(act_wave, terrain)
	var bodies: int = int(round(float(per_lane * lanes)
		* (_body_scale if _body_scale > 0.0 else WaveDirector.body_scale_for(_players))))
	var hp: float = director._hp_scale(0)
	var damage: float = director._damage_scale(0)
	var speed: float = director._speed_scale(0)

	# **And the marks the road's tier sets on its bodies** (2026-10-01): a share
	# of the ordinary bodies wear one or more, each multiplying health by its
	# own `health_scale`. Read off the act's own pool at the tier's floor share
	# (the earth's anger lifts it in play), so the harder roads are measured
	# with the bodies they actually send.
	var threat: float = float(bodies) * hp * _mark_health(act)

	# Killing pays for the next wall, so income is a function of the bodies
	# already dealt with rather than of the clock. Modelling it as time-based
	# reported a flat capability for the whole run, which would have made every
	# ratio below meaningless.
	# Later acts pay more, which is what keeps Gold a decision for ten acts
	# rather than three. Modelled here as well as banked in `gain_kill_resources`,
	# or this report would go on reading the flat economy it was what caught.
	_earned_gold += float(bodies) * _gold_per_body() * Balance.kill_act_scale(act) \
		* (Balance.COOP_KILL_INCOME_SCALE if _players > 1 else 1.0)
	var dealt: Dictionary = _deal_the_augments_so_far(act, wave)
	_road_kills += float(bodies)
	# The hero counts toward the defence now, and has to.
	#
	# While the run began with four towers up, leaving the hero out was a
	# conservative simplification: towers were the floor and the hero was the
	# bonus. The zero-capital start inverts that for the opening - for the first
	# waves the hero *is* the entire defence - and a model scoring those waves as
	# having no defence at all divides by nothing and reports an infinite spike
	# exactly where the design intends its gentlest moment.
	# Both heroes count. Two players is two of them on the field, which is most of
	# why twice the bodies is close to the right answer rather than double the
	# difficulty.
	# **And the spirit at their shoulder, when they have one.**
	#
	# A bonded companion is a persistent second body that fights, and this model
	# did not know it existed. Measured on 2026-09-13: the hero model is 38.3
	# damage a second, the best companion's base is 41.3, and at apex rarity it
	# is 88.9 - **two hundred and thirty-two per cent of the hero**. It is off by
	# default because a first run has no companion and the curve is tuned for
	# that player; `--companion` reports the returning one.
	# **And the third capped scale, on the half of capability it actually
	# touches** (owner ruling, 2026-09-17: *"`curve_report` models three scales
	# instead of two"*).
	#
	# Ascension moves what the Warden *survives* rather than what they deal, so
	# it is applied to the hero and the spirit at their shoulder and to nothing
	# else: a tower's uptime is not improved by the person standing near it. A
	# hero who takes `1 - m` of the damage has `1 / (1 - m)` of the effective
	# health, and sustained contribution scales with how long they stand -
	# which is the honest reading of a mitigation number in a model that has no
	# deaths in it.
	#
	# **The figure is read through the same constants the hero reads**, so a
	# re-tune of the ladder moves this too rather than leaving a number behind.
	var standing: float = ascension_uptime(ascension_rank())
	var towers: float = _affordable_dps(_earned_gold) * _core_scale(Modifiers.TOWER_DAMAGE) \
		* _core_scale(Modifiers.TOWER_RATE)
	# **The Arsenal**, after the towers are bought, because a weapon on the
	# towers stands on every one of them.
	var arsenal: float = _arsenal_value(_arsenal, act) * standing
	# **And the Warden's own Might** (2026-10-01). The Arsenal below has always
	# carried it and the Warden's own swing never did, so a levelled Warden's
	# blows were counted at a new one's - invisible on a new account, where
	# Might is nought, and a real share of the late game for anybody else.
	var might: float = 1.0 + float(WardenSheet.attribute_of(null, RunState.Attribute.MIGHT)) \
		* Balance.HERO_MIGHT_PER_POINT
	var warden: float = _hero_dps() * might * _core_scale(Modifiers.HERO_DAMAGE) \
			* _discipline_scale() * standing + _companion_dps() * standing
	var capability: float = warden * float(_players) + towers + arsenal

	return {
		"wave": wave, "act": act, "act_wave": act_wave,
		"gold": _earned_gold, "towers": _bought_towers, "level": _bought_level,
		"lanes": lanes, "per_lane": per_lane, "bodies": bodies,
		"hp": hp, "damage": damage, "speed": speed,
		"threat": threat, "capability": capability,
		"pressure": threat / maxf(capability, 0.001),
		"rank": int(dealt.get("ranks", 0)), "drafts": int(dealt.get("drafts", 0)),
		"arsenal": arsenal, "towers_dps": towers,
		"arsenal_single": _arsenal_value(_arsenal, act, true) * standing,
		# One Warden with nothing but what they carry - their sword, their
		# spirit and their own weapons - against one body: what an arena asks.
		"warden_single": warden + _arsenal_value(_arsenal, act, true, true) * standing,
	}


## **How long the Warden stands, act by act.**
##
## A *readout*, like the purse column: it prints and it fails nothing. That is
## deliberate and it is the honest shape for this number, because the band
## above measures whether the defence can kill a wave and this measures
## whether the person can be killed by one - two different questions, and
## giving the second one a pass/fail would be a second model with an opinion.
##
## **It exists because the owner's ascension ruling asked a question the
## pressure curve cannot answer.** *"Ascension must empower significantly so
## that Nightmare is survivable after grinding its gear"* is a sentence about
## surviving, and pressure is threat over *capability* - a model with no deaths
## in it. Carrying the rank moved the band by 0.002, which is true and is not
## the answer: what a rank buys is here instead, where it is worth 13.6%.
##
## Blows, not seconds. A figure in seconds would need an arrival rate, which is
## a second model of the road; how many hits the Warden can take from the body
## that act sends is read straight off the numbers the wave already has.
func _print_survival() -> void:
	var rank: int = ascension_rank()
	var contact: float = _mean_contact_damage()
	if contact <= 0.0:
		return
	var line: PackedStringArray = []
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		var row: Dictionary = _last_row_of_act(act)
		if row.is_empty():
			continue
		var blow: float = contact * float(row["damage"])
		var pool: float = Balance.HERO_MAX_HP * ascension_uptime(rank)
		line.append("%d:%.1f" % [act, pool / maxf(blow, 0.01)])
	var plain: float = Balance.HERO_MAX_HP / maxf(contact
		* float(_rows[_rows.size() - 1]["damage"]), 0.01)
	var held: float = plain * ascension_uptime(rank)
	print("[curve] blows survived by act, BASE pool   %s"
		% " ".join(line))
	print(("[curve] at the end of the road that body takes a base Warden down in "
		+ "%.1f blows, %.1f at rank %d (+%.0f%%)")
		% [plain, held, rank, (ascension_uptime(rank) - 1.0) * 100.0])
	# **A floor, and it has to say so.** This is `HERO_MAX_HP` - a Warden with
	# no levels, no Vigour and no gear - exactly as `_hero_dps` models a naked
	# combo. Levelling and gear are the two capped scales the campaign is tuned
	# against and they are what carry a real Warden through Act X; printing
	# "1.0 blows" without saying which hero is the misreading this project keeps
	# recording, so the line says it rather than leaving it to be inferred.
	_print_boss_time()
	# **And the Warden the tier expects** (2026-10-01): their own pool and
	# mitigation, dressed act by act, against the same body. This is the
	# number the survival band is held to; the base line above is the floor.
	if _expected_warden and not _expected_pool.is_empty():
		var held_line: PackedStringArray = []
		var fewest: float = INF
		for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
			var row: Dictionary = _last_row_of_act(act)
			if row.is_empty() or not _expected_pool.has(act):
				continue
			var blow: float = contact * float(row["damage"]) * (1.0 - float(_expected_mitigation[act]))
			var blows: float = float(_expected_pool[act]) / maxf(blow, 0.01)
			fewest = minf(fewest, blows)
			held_line.append("%d:%.1f" % [act, blows])
		print("[curve] blows survived by act, EXPECTED Warden   %s" % " ".join(held_line))
		_survival_floor = fewest
		var power: PackedStringArray = []
		for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
			if _expected_damage.has(act):
				power.append("%d:x%.2f" % [act, float(_expected_damage[act])])
		print("[curve] expected Warden damage by act   %s" % " ".join(power))
	print(("[curve]   ^ the base pool only. Levelling, Vigour and gear are the "
		+ "two capped scales that carry a real Warden past act %d; what this "
		+ "shows is the floor ascension lifts and by how much.")
		% Balance.ACT_COUNT)


## **How long each act's boss stands**, against the defence that reaches it
## (2026-10-01). A readout like the survival line: a boss fight is not wave
## pressure, and this is the one number that says whether a giant is a climax
## or a speed bump on each road. The boss walks one road, so a quarter of the
## board meets it; the Warden, their spirit and the whole Arsenal go to it.
## Health through `BossDirector.boss_health_scale`, the road's own, so this
## cannot disagree with the spawn.
func _print_boss_time() -> void:
	_boss_failures = 0
	var solo: Dictionary = {}
	for count: int in [1, Balance.COOP_MAX_PLAYERS]:
		var rows: Dictionary = _party_act_rows.get(count, {})
		if rows.is_empty():
			continue
		var line: PackedStringArray = []
		for act: int in range(1, Balance.ACT_COUNT + 1):
			var seconds: float = boss_seconds(act, rows.get(act, {}), count)
			if seconds < 0.0:
				continue
			line.append("%d:%.0fs" % [act, seconds])
			if count == 1:
				solo[act] = seconds
				if seconds < BOSS_SECONDS_BAND.x or seconds > BOSS_SECONDS_BAND.y:
					printerr("[curve] act %d's boss stands %.0fs against one Warden, outside %.0f-%.0fs"
						% [act, seconds, BOSS_SECONDS_BAND.x, BOSS_SECONDS_BAND.y])
					_boss_failures += 1
			elif solo.has(act):
				var ratio: float = seconds / maxf(float(solo[act]), 0.01)
				if ratio < BOSS_PARTY_RATIO.x or ratio > BOSS_PARTY_RATIO.y:
					printerr("[curve] act %d's boss stands %.1fx as long against %d Wardens as against one, outside %.1f-%.1fx"
						% [act, ratio, count, BOSS_PARTY_RATIO.x, BOSS_PARTY_RATIO.y])
					_boss_failures += 1
		print("[curve] boss time-to-fall, %d player%s   %s"
			% [count, "" if count == 1 else "s", " ".join(line)])
	_print_warden_alone()
	if solo.has(1) and solo.has(Balance.ACT_COUNT) and float(solo[Balance.ACT_COUNT]) <= float(solo[1]):
		printerr("[curve] the last act's boss falls no slower than the first's - the finale is not a climax")
		_boss_failures += 1


## **How long one of an act's road bodies stands against the Warden alone**
## (2026-10-01). A readout for the arenas: a raid, a rift and a dungeon are the
## Warden with no board, so this is the figure their bodies are fought at if
## they stand at the road's own strength. The act's own roster, by mean health.
func _print_warden_alone() -> void:
	var line: PackedStringArray = []
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var row: Dictionary = _last_row_of_act(act)
		var terrain: TerrainData = ContentDB.terrain_for_act(act)
		if row.is_empty() or terrain == null:
			continue
		var total: float = 0.0
		var count: int = 0
		for id: String in terrain.enemy_ids:
			var breed: EnemyData = ContentDB.enemy(id)
			if breed != null:
				total += breed.max_hp
				count += 1
		if count == 0:
			continue
		var health: float = total / float(count) * float(row["hp"])
		line.append("%d:%.1fs" % [act, health / maxf(float(row.get("warden_single", 0.0)), 0.01)])
	print("[curve] one road body against the Warden alone   %s" % " ".join(line))


## How long one act's boss stands against the defence a row measured, or -1.
func boss_seconds(act: int, row: Dictionary, players: int) -> float:
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	if row.is_empty() or terrain == null:
		return -1.0
	var boss: EnemyData = ContentDB.enemy(terrain.boss_id)
	if boss == null:
		return -1.0
	var health: float = boss.max_hp * BossDirector.boss_health_scale(act, RunState.tier(), players)
	var towers: float = float(row.get("towers_dps", 0.0))
	var reach: float = float(row["capability"]) - towers - float(row["arsenal"]) \
		+ towers / float(Balance.LANE_COUNT) + float(row.get("arsenal_single", 0.0))
	return health / maxf(reach, 0.01)


## What the tier's marks add to an average body's health in this act.
func _mark_health(act: int) -> float:
	var tier: CampaignTierData = RunState.tier()
	if tier == null or tier.marked_share <= 0.0 or tier.marks_max <= 0:
		return 1.0
	var pool: Array[EnemyAffixData] = EnemyMarks.pool(act)
	if pool.is_empty():
		return 1.0
	var mean: float = 0.0
	for mark: EnemyAffixData in pool:
		mean += mark.health_scale
	mean /= float(pool.size())
	var worn: float = (1.0 + float(tier.marks_max)) * 0.5
	return 1.0 + tier.marked_share * (pow(mean, worn) - 1.0)


## The average blow a body that walks the road lands.
##
## Read from the roster the same way the Gold figure is, and over the same
## enemies - the ones that *actually walk on*. Camp lords are several times a
## road body and never take a route; averaging them in is the 143% error this
## report already paid for once.
func _mean_contact_damage() -> float:
	var total: float = 0.0
	var count: int = 0
	for value: Variant in ContentDB.enemies.values():
		var enemy := value as EnemyData
		if enemy == null or not _walks_the_road(enemy):
			continue
		total += enemy.contact_damage
		count += 1
	return total / float(maxi(count, 1))


## The last wave modelled in an act, or an empty dictionary.
func _last_row_of_act(act: int) -> Dictionary:
	var found: Dictionary = {}
	for row: Dictionary in _rows:
		if int(row["act"]) == act:
			found = row
	return found


## Which ascension rank this run of the report is modelling.
##
## The account's own unless `--ascension=` says otherwise, which is the same
## rule the hero level and the gear points follow: this model measures the
## profile it was handed, and says which one that was.
func ascension_rank() -> int:
	if _ascension >= 0:
		return _ascension
	return clampi(MetaState.ascension, 0, Balance.ASCENSION_MAX)


## What a rank is worth as sustained uptime.
##
## **Derived from the constants the hero applies, never typed in.** The hero
## sums ascension's mitigation inside Resolve's own ceiling; this model has no
## Resolve in it, so the ceiling that binds here is ascension's own - which is
## deliberately the lower of the two, so modelling it alone can never report a
## Warden tougher than the game allows.
static func ascension_uptime(rank: int) -> float:
	var mitigation: float = minf(float(rank) * Balance.ASCENSION_MITIGATION_PER_RANK,
		minf(Balance.ASCENSION_MITIGATION_CAP, Balance.HERO_RESOLVE_MITIGATION_CAP))
	return 1.0 / maxf(1.0 - mitigation, 0.01)


## The rank a Warden arriving at a campaign tier is expected to hold.
##
## **Derived from the ladder rather than authored on the tier.** A Warden who
## has cleared the tiers before this one has climbed each of their Gatekeeper
## ladders, and each rung pays a rank - so what they hold is the number of
## rungs behind them. Nothing new is stored and no tier gains a field; if the
## ladder ever changes length, this moves with it.
static func expected_rank_for_tier(tier_id: String) -> int:
	var before: int = 0
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		if tier.id == tier_id:
			break
		before += 1
	return clampi(before * GatekeeperTrials.STAGES, 0, Balance.ASCENSION_MAX)


## The hero's own sustained damage, as a floor.
##
## One full three-hit combo against a single target: the windup, active and
## recovery of each swing for the time, the damage of all three for the numerator.
## Single-target on purpose - the swing arcs are 110 and 170 degrees and the
## finisher lunges, so a real hero in a pack does better than this. A floor is
## what a capability model wants.
##
## Read from the same arrays the hero fights with, so a rebalance of the combo
## moves this number too rather than leaving a typed-in constant behind.
## What the spirit at the hero's shoulder adds, at the rarity being modelled.
##
## Zero unless asked for. Read from the companion roster and
## `SPIRIT_APEX_POWER` rather than typed in, so re-tuning either moves this too.
func _companion_dps() -> float:
	if not _with_companion:
		return 0.0
	var best: float = 0.0
	for value: Variant in ContentDB.companions.values():
		var kind := value as CompanionData
		if kind == null or kind.attack_interval <= 0.0:
			continue
		best = maxf(best, kind.damage / kind.attack_interval)
	return best * Balance.SPIRIT_APEX_POWER


func _hero_dps() -> float:
	var damage: float = 0.0
	var duration: float = 0.0
	for index: int in Balance.HERO_ATTACK_DAMAGE.size():
		damage += Balance.HERO_ATTACK_DAMAGE[index]
		duration += Balance.HERO_ATTACK_WINDUP[index] \
			+ Balance.HERO_ATTACK_ACTIVE[index] \
			+ Balance.HERO_ATTACK_RECOVERY[index]
	return damage / maxf(duration, 0.01)


## **What the Disciplines add to a swing, for the account being measured**
## (owner ruling R3, 2026-09-26: a node may carry a number, and the curve
## carries it as part of the levelling scale - a number the model does not
## carry is forbidden, exactly as an ascension rank's is).
##
## Two numbers a node carries on every swing of a sustained fight: the chain's
## form (Hemorrhage Edge is every new Warden's, at 8%), and Rising Fury at its
## cap, which a Warden swinging without pause reaches in
## `RISING_FURY_RAMP_SECONDS`. Read through the same door the hero reads
## (`WardenSheet` with no sheet is this account), so the report and the fight
## cannot disagree about which nodes are held. The rest of the tree is
## conditional - a crit on an isolated body, a burst after a support kill, a
## finisher after a perfect evade - and a best-case model that counted every
## condition as met would be modelling a player the road never produces; they
## are left out and said to be.
func _discipline_scale() -> float:
	var form: DisciplineNodeData = WardenSheet.form_of(null)
	# The form and its enhancement (`form_power`), the one branch that reaches
	# every swing - ruling R3's price for a node that carries a number.
	var scale: float = 1.0 + (form.form_damage + WardenSheet.upgrade_of(null, form.id, "form_power")
		if form != null else 0.0)
	scale *= 1.0 + WardenSheet.trained_value_of(null, "active_attack_speed")
	# **Heavy Hand** (docs/GEAR_REWORK_2026-09-28.md §2): Might's tiers on the
	# finisher, weighed by the finisher's share of the chain's damage - the one
	# perk that touches a blow, carried as part of the levelling scale.
	var chain: float = 0.0
	for hit: float in Balance.HERO_ATTACK_DAMAGE:
		chain += hit
	if chain > 0.0:
		var last: float = Balance.HERO_ATTACK_DAMAGE[Balance.HERO_ATTACK_DAMAGE.size() - 1]
		scale *= 1.0 + last / chain * WardenSheet.perk_of(null, RunState.Attribute.MIGHT)
	return scale


## Average Gold a body is worth, across the enemies that actually walk on.
## Reading it from the data rather than typing a number keeps this honest when
## somebody rebalances a drop.
func _gold_per_body() -> float:
	var total: float = 0.0
	var count: int = 0
	for value: Variant in ContentDB.enemies.values():
		var enemy := value as EnemyData
		if enemy == null or not _walks_the_road(enemy):
			continue
		total += float(enemy.resource_value)
		count += 1
	if count == 0:
		return Balance.KILL_RESOURCE_SCALE
	return total / float(count) * Balance.KILL_RESOURCE_SCALE



## Whether a body of this kind is one a wave ever sends up a lane.
##
## **The average this report earns its Gold from is an average of road
## bodies**, and the only thing that ever made that true was that every
## non-boss enemy in the game happened to be one. It stopped being true on
## 2026-09-15, when the second and third camps were given breeds of their own
## and the war camp a lord - eleven resources that live in a camp, never take a
## route, and are worth several times what a road body is because going to
## find one is supposed to be worth the detour.
##
## **The report went on averaging them in, and it was a 143% error in the
## purse**: 8.88 Gold a body against the 3.64 a road actually pays. The model
## bought roughly two and a half times the towers it should have, so modelled
## capability nearly doubled and mean pressure fell from 0.434 to 0.227 -
## straight through the floor and out the bottom of the band, reported on
## every release since with nothing failing, because this report is advisory
## and its own band check only prints.
##
## Nothing about the *game* moved. A camp lord pays what it always paid, to a
## player who went and killed one.
func _walks_the_road(enemy: EnemyData) -> bool:
	return enemy.category == EnemyData.Category.BREED \
		or enemy.category == EnemyData.Category.ELITE

## Best-case tower damage per second for a given amount of Gold earned.
##
## Spending is assumed perfect, every body is assumed killed and nothing is
## assumed lost, so this is a ceiling rather than a forecast. That is the point:
## a curve the best case cannot hold is unarguable.
func _affordable_dps(earned: float) -> float:
	var gold: float = float(Balance.STARTING_GOLD) + earned

	# **The best build the purse can buy, not the first one it can afford.**
	#
	# This used to fill every slot with a level-one tower and only then start
	# upgrading, a round at a time across all forty. Nobody plays that way, and
	# the arithmetic is brutal: a round of upgrades across forty towers costs
	# forty times a step, so the model reached wave 73 of a ten-act run still
	# at **level 2**, with capability pinned flat from wave 50 - the moment the
	# fortieth slot filled - through the last twenty-three waves of the game.
	# Every conclusion about the late acts was drawn from that flat line.
	#
	# The docstring above already said spending is "assumed perfect". It now is:
	# every count of towers at every level is priced, and the most damaging one
	# the purse covers wins.
	var reference: TowerData = ContentDB.tower("ember_spire")
	if reference == null:
		_bought_towers = 0
		_bought_level = 1
		return 0.0
	var slots: int = Balance.LANE_COUNT * SLOTS_PER_LANE
	var best: float = 0.0
	var best_towers: int = 0
	var best_level: int = 1
	# What one tower costs to stand at each level, accumulated once.
	var to_level: PackedFloat64Array = [float(Balance.TOWER_BUILD_COST)]
	for step: int in range(1, Balance.TOWER_MAX_LEVEL):
		var price: int = Balance.TOWER_UPGRADE_COSTS[mini(step - 1,
			Balance.TOWER_UPGRADE_COSTS.size() - 1)]
		to_level.append(to_level[step - 1] + float(price))
	for level: int in range(1, Balance.TOWER_MAX_LEVEL + 1):
		var each: float = to_level[level - 1]
		if each <= 0.0:
			continue
		var towers: int = mini(int(gold / each), slots)
		if towers <= 0:
			continue
		var interval: float = maxf(reference.interval_at(level), 0.01)
		var output: float = float(towers) * reference.damage_at(level) / interval
		if output > best:
			best = output
			best_towers = towers
			best_level = level

	_bought_towers = best_towers
	_bought_level = best_level
	return best


## **Whose account this was measured on.**
##
## The report reads the save: a levelled hero and worn gear are capability it
## counts, so the same commit measures about five percent easier on a played
## account than on a new one. That is not a fault - a veteran really does have an
## easier road - but it means **a number read here is only comparable to another
## number read on the same account**, and the band is held by CI against a fresh
## one.
##
## This was found by the release sweep of 2026-09-15 disagreeing with a local run
## by 0.023, after a whole session of tuning against the owner's live save. The
## sweep is right, because the sweep is what ships. Printed rather than fixed:
## measuring a veteran's road is a legitimate thing to want, and the failure was
## never knowing which one was on screen.
##
## To measure the way the gate does, point the profile somewhere empty:
##
##   APPDATA=/tmp/empty LOCALAPPDATA=/tmp/empty godot --headless --path game ...
func _print_the_account() -> void:
	var worn: int = 0
	for points: int in MetaState.gear_attribute_points():
		worn += points
	# **Keyed on the hero's level and nothing else.** A new account is not an
	# empty one - it opens with eight towers unlocked and the run hands out a
	# starting weapon, so "no gear and no towers" is never true and the first cut
	# of this line called a fresh profile played. A level above one cannot be
	# baseline.
	var fresh: bool = MetaState.hero_level <= 1
	# **And the third scale, since 2026-09-17.** Ascension is a capped ladder of
	# its own now rather than prestige, so an account carrying ranks measures a
	# different game again - the same trap the gear points and the hero level
	# were printed for. It is not *modelled* here: this report measures the road
	# against towers and hero damage, and what ascension moves is what the hero
	# survives. Re-solving Nightmare and Hell against a ranked Warden is a
	# measurement that has not been taken, and it is the remaining balance task.
	var rank: int = ascension_rank()
	var source: String = "the account's own" if _ascension < 0 else "asked for"
	var ranked: String = "" if rank <= 0 else (
		"  <- carrying %d ascension rank(s), %s, worth %.1f%% hero uptime"
			% [rank, source, (ascension_uptime(rank) - 1.0) * 100.0])
	print(("[curve] measured on %s - hero level %d, %d gear points, %d towers "
		+ "unlocked%s")
		% ["a NEW account" if fresh else "a PLAYED account", MetaState.hero_level,
			worn, MetaState.unlocked_towers.size(),
			("" if fresh else "  <- the band below is held against a new one") + ranked])


## **Does every party size get the same game?**
##
## Judged on the *mean* pressure across the run, not the peak. The peak is
## quantisation noise: capability jumps whenever the purse crosses a tower price,
## so the highest single wave lands wherever a formation happens to fall just
## before a purchase, and sweeping the scaling constant moves it up and down at
## random - 1.60 gave 0.71, 1.75 gave 0.88, 1.90 gave 0.69. Tuning against that
## is tuning against rounding. The mean over forty waves is stable to the third
## decimal and is what a player actually experiences.
##
## Measured 0.363 / 0.340 / 0.346 / 0.337 for one to four players when this was
## written, which is flat enough that the linear rule needed no per-size table.
## The band is here so it stays that way: a change that makes any party size a
## different game fails rather than being discovered by somebody playing it.
func _judge_party_scaling() -> int:
	if _players != 1 or _body_scale > 0.0:
		# Only the plain run judges. A report asked about one party size or an
		# overridden constant is a question, not a verdict.
		return 0
	var means: Array[float] = []
	for count: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		means.append(_mean_pressure_for(count))
	var lowest: float = means[0]
	var highest: float = means[0]
	for value: float in means:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	var spread: float = (highest / maxf(lowest, 0.001) - 1.0) * 100.0
	var readout: String = ""
	for index: int in means.size():
		readout += "%d:%.3f  " % [index + 1, means[index]]
	print("")
	_print_the_account()
	_print_survival()
	print("[curve] mean pressure by party size   %s spread %.0f%%" % [readout, spread])
	var failed: int = 0
	if spread > PARTY_SPREAD_LIMIT:
		printerr("[curve] party sizes do not get the same game: %.0f%% spread, "
			% spread + "limit %.0f%%" % PARTY_SPREAD_LIMIT)
		failed += 1
	for index: int in means.size():
		var band: Vector2 = _band()
		# The band is the drafted hand's (`_judge_the_drafted_road`); the
		# planner reads the whole deck and is what mastery buys.
		if _with_augments:
			break
		if means[index] < band.x or means[index] > band.y:
			printerr("[curve] %d players sits at %.3f, outside %.2f-%.2f"
				% [index + 1, means[index], band.x, band.y])
			failed += 1
	# **And the Warden must be able to stand in it** (2026-10-01): the fewest
	# blows from the act's own body the Warden this tier expects can take, in
	# any act. Under it the road is lost to two hits rather than to a defence.
	if _expected_warden and _survival_floor < _survival_band():
		printerr("[curve] the expected Warden survives %.1f blows somewhere on this road, under %.1f"
			% [_survival_floor, _survival_band()])
		failed += 1
	failed += _boss_failures
	if failed == 0:
		print("[curve] PASS - every party size plays the same curve")
	return failed


## **The road against the hand a player draws** (2026-10-01).
##
## The bands were held against the planner, and the planner takes its every
## pick from the whole deck - a hand no player can draw, since a draft is three
## cards. Measured over six deals with the boss's floor, the Temperings, the
## rerolls and the camp's draft all modelled, a player drafting from three and
## reading what the cards say held about 0.60 of the planner's defence, and the
## Chainmaker's Road read 1.00 for them - past the edge from Act VI. Neither
## four cards an offer nor twelve rerolls nor a purse of luck moved it: the hand
## fills by Act II and then grows, which is the genre, and the gap is what
## reading the whole deck is worth.
##
## So a named road's band is held against the drafted hand, as a mean over
## `DRAFT_SALTS` deals because one deal is one player's luck, and the worst act
## of that mean must stay at or under `DRAFT_PEAK_CEILING`: a climax at the edge
## of what the drafted defence answers, never past it. The planner is printed
## beside it as what mastery of the deck buys, and is no longer the thing judged.
const DRAFT_SALTS: int = 4
const DRAFT_PEAK_CEILING: float = 1.0


func _judge_the_drafted_road() -> int:
	if _players != 1 or _body_scale > 0.0 or _build != "best" or not _with_augments:
		return 0
	var build_was: String = _build
	var salt_was: int = _draft_salt
	_build = "reader"
	var means: Array[float] = []
	var by_act: Dictionary = {}
	for salt: int in DRAFT_SALTS:
		_draft_salt = salt
		means.append(_mean_pressure_for(1))
		for act: Variant in _replay_acts:
			var sums: Vector2 = _replay_acts[act]
			by_act[act] = float(by_act.get(act, 0.0)) + sums.x / maxf(sums.y, 1.0)
	_build = build_was
	_draft_salt = salt_was
	var mean: float = 0.0
	for value: float in means:
		mean += value
	mean /= float(means.size())
	var worst: float = 0.0
	var worst_act: int = 0
	var acts: PackedStringArray = []
	var keys: Array = by_act.keys()
	keys.sort()
	for act: Variant in keys:
		var value: float = float(by_act[act]) / float(DRAFT_SALTS)
		acts.append("%d:%.2f" % [int(act), value])
		if value > worst:
			worst = value
			worst_act = int(act)
	var band: Vector2 = _band()
	var each: PackedStringArray = []
	for value: float in means:
		each.append("%.3f" % value)
	print("[curve] the road a player drafts, mean of %d deals   %.3f  (each %s)   planner %.3f"
		% [DRAFT_SALTS, mean, " ".join(each), _mean_of_rows()])
	print("[curve] the road a player drafts, by act   %s" % " ".join(acts))
	var failed: int = 0
	if mean < band.x or mean > band.y:
		printerr("[curve] the drafted road sits at %.3f, outside %.2f-%.2f" % [mean, band.x, band.y])
		failed += 1
	if worst > DRAFT_PEAK_CEILING:
		printerr("[curve] the drafted road's Act %d reads %.2f, past the edge at %.2f"
			% [worst_act, worst, DRAFT_PEAK_CEILING])
		failed += 1
	if failed == 0:
		print("[curve] PASS - the road a player drafts sits in its band and never past the edge")
	return failed


## The planner's mean over the main walk.
func _mean_of_rows() -> float:
	var total: float = 0.0
	for row: Dictionary in _rows:
		total += float(row["pressure"])
	return total / maxf(float(_rows.size()), 1.0)


## **Does the campaign get harder as it goes?**
##
## The party check asks whether everyone plays the same curve. It says nothing
## about the curve's *shape*, and the shape was wrong: measured over ten acts,
## the hardest act in the game was **Act III** at 0.477, and every one of the
## seven acts after it was easier - the finale easiest of all at 0.335. A
## player who beat the old three-act finale then coasted for two thirds of the
## campaign.
##
## That was invisible for two reasons, both now fixed. The run mean is a
## perfectly healthy 0.348 whatever shape produces it, and the model had
## capability pinned flat from wave 50, which flattered the late acts into
## looking like they were holding up.
##
## Two properties, and they are deliberately loose. Per-act means carry real
## noise - acts differ in how many waves they hold and where those waves fall
## against the purse - so this is not a monotonic ladder. It asks only that the
## end of the road is harder than the start of it, and that no act is a
## holiday.
func _judge_escalation() -> int:
	if _players != 1 or _body_scale > 0.0:
		return 0
	var totals: Dictionary = {}
	var counts: Dictionary = {}
	for row: Dictionary in _rows:
		var act: int = int(row["act"])
		totals[act] = float(totals.get(act, 0.0)) + float(row["pressure"])
		counts[act] = int(counts.get(act, 0)) + 1
	var means: Array[float] = []
	var readout: String = ""
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		if not counts.has(act):
			continue
		var mean: float = float(totals[act]) / float(counts[act])
		means.append(mean)
		readout += "%d:%.2f " % [act, mean]
	print("")
	print("[curve] mean pressure by act   %s" % readout)
	# **What share of the defence is the Arsenal**, act by act - a readout, like
	# the purse: the owner asked for augments that eliminate hordes, and this is
	# how much of the killing the model says they do.
	var shares: Dictionary = {}
	var share_counts: Dictionary = {}
	for row: Dictionary in _rows:
		var at_act: int = int(row["act"])
		shares[at_act] = float(shares.get(at_act, 0.0)) + float(row.get("arsenal", 0.0)) / maxf(float(row["capability"]), 0.001)
		share_counts[at_act] = int(share_counts.get(at_act, 0)) + 1
	var share_line: String = ""
	for at_act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		if share_counts.has(at_act):
			share_line += "%d:%.0f%% " % [at_act, 100.0 * float(shares[at_act]) / float(share_counts[at_act])]
	print("[curve] Arsenal share of the defence by act   %s" % share_line)
	# **And what the model is holding**, so a curve that moves when the deck
	# grows can be read for why: a pick that looks best one draft ahead and
	# leaves the hand no room for an evolution reads as a harder road.
	for at_act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		if not _hand_by_act.has(at_act):
			continue
		var cards: PackedStringArray = []
		var hand: Dictionary = _hand_by_act[at_act] as Dictionary
		for id: Variant in hand:
			cards.append("%s L%d" % [String(id), int(hand[id])])
		print("[curve] Arsenal hand at the end of act %d   %s" % [at_act, ", ".join(cards)])
	if means.size() < Balance.FINAL_ASCENT_ACT:
		return 0

	var failed: int = 0
	var opening: float = (means[0] + means[1] + means[2]) / 3.0
	var closing: float = (means[means.size() - 3] + means[means.size() - 2]
		+ means[means.size() - 1]) / 3.0
	if closing < opening * ESCALATION_RATIO:
		printerr(("[curve] the road does not escalate: the last three acts "
			+ "average %.3f against the first three at %.3f, and a ten-act "
			+ "campaign whose hardest stretch is its opening is a campaign "
			+ "that coasts") % [closing, opening])
		failed += 1
	var act_one: float = means[0]
	for index: int in range(3, means.size()):
		if means[index] < act_one * HOLIDAY_FLOOR:
			printerr(("[curve] act %d sits at %.3f against Act I at %.3f - an "
				+ "act later than the third that asks less than the first is a "
				+ "holiday in the middle of the road")
				% [index + 1, means[index], act_one])
			failed += 1
	failed += _judge_the_surge()
	if failed == 0:
		print("[curve] PASS - the road escalates and no act is a holiday")
	return failed


## **The boss is approached, not hit** (2026-10-01). The surge into each act's
## boss used to land on the act's last wave alone, a step of +0.15 to +0.21
## after a flat stretch - a wall rather than a climb. It climbs across
## `ACT_BOSS_RAMP_DISTANCE` now, and this holds the climb: no step into an
## act's last waves may be larger than `SURGE_STEP_LIMIT`, and the last wave
## must stand above the wave the stretch began on.
##
## From Act II. Act I is where the first board is bought, and the model buys a
## tower every second wave there - exactly as fast as the surge climbs - so its
## last stretch reads flat at about 0.22 on every road, which is the opening
## envelope `balance_test` owns rather than a missing climb.
func _judge_the_surge() -> int:
	var failed: int = 0
	for act: int in range(2, Balance.ACT_COUNT + 1):
		var waves: Array[float] = []
		for row: Dictionary in _rows:
			if int(row["act"]) == act:
				waves.append(float(row["pressure"]))
		if waves.size() < SURGE_WAVES + 1:
			continue
		var stretch: Array[float] = waves.slice(waves.size() - SURGE_WAVES - 1)
		for index: int in range(1, stretch.size()):
			var step: float = stretch[index] - stretch[index - 1]
			if step > SURGE_STEP_LIMIT:
				printerr("[curve] act %d's surge into its boss steps %+.2f in one wave (%.2f -> %.2f), over %.2f"
					% [act, step, stretch[index - 1], stretch[index], SURGE_STEP_LIMIT])
				failed += 1
		if stretch[stretch.size() - 1] <= stretch[0]:
			printerr("[curve] act %d does not climb into its boss (%.2f -> %.2f)"
				% [act, stretch[0], stretch[stretch.size() - 1]])
			failed += 1
	return failed


## How many waves the surge into a boss is read over, and the largest step it
## may take between two of them. [TUNE]
const SURGE_WAVES: int = 4
const SURGE_STEP_LIMIT: float = 0.10


## How much harder the last three acts must be than the first three, and how
## far below Act I any later act may fall. Loose on purpose: per-act means
## carry real noise from how many waves an act holds. [TUNE]
const ESCALATION_RATIO: float = 1.25
const HOLIDAY_FLOOR: float = 0.95


## How far apart the easiest and hardest party sizes may be, and the band each
## must sit in. Wide enough not to trip on model noise, narrow enough that a
## party size becoming a different game fails. [TUNE]
const PARTY_SPREAD_LIMIT: float = 22.0
## **The band the campaign is tuned to sit inside.**
##
## Moved 2026-09-15 from 0.26-0.46 with the owner's ruling that the road should
## pay less and ask more. The old band was not wrong - it described a different
## game, and this file recorded the new one in CLAUDE.md while *these two
## constants* were left behind, so the report judged the re-tune against the game
## it replaced and exited non-zero while printing PASS on escalation.
##
## **A band recorded in prose and enforced by a number in another file is two
## places to change and one place to forget.** This is the one that decides.
##
## **The floor moved again 2026-09-20**, from 0.44, with the owner's report
## that *"all enemies scale to too much health and damage and need to be nerfed
## a bit"*. The act ladders came down - health 2.28 to 1.94 by Act X, damage
## 1.28 to 1.18 - and solo mean pressure with them, 0.479 to 0.417. The ceiling
## is deliberately left where it is: a nerf cannot make the road harder, so
## lowering the top would be inventing a bound nobody asked for.
##
## Measured on an empty profile, which is the account the band is held against.
## A played one read the same figure to the digit here, so the warning above the
## band was noise this time rather than a distortion - worth knowing, because it
## is not always.
const PARTY_PRESSURE_FLOOR: float = 0.40
## 0.58 to 0.64 on 2026-09-24: the owner asked for a harder road (more
## bodies, more health, scarcer income), and a ceiling left where it was would
## judge the re-tune against the game it replaced - the failure recorded when
## the band last moved. The floor is deliberately unmoved.
const PARTY_PRESSURE_CEILING: float = 0.64


## **The band each road is held to**, by which road and which Warden
## (2026-10-01). The plain report - a new account on the Long Road - keeps the
## band this file has always held. With a tier named, the Warden that tier
## expects walks it and the bands climb: the Long Road a little under the new
## account's (a levelled Warden), the Iron Road harder, the Chainmaker's Road
## hardest - each one closer to the edge a best-case defence can answer, so
## every road asks more of the Warden it was built for than the last one did.
## [TUNE]
const TIER_BANDS: Dictionary = {
	"normal": Vector2(0.30, 0.56),
	"nightmare": Vector2(0.48, 0.66),
	"hell": Vector2(0.56, 0.74),
}
## The fewest blows from an act's own body the expected Warden may survive
## anywhere on the road: fewer is a road lost to two hits rather than to a
## defence. [TUNE]
const TIER_SURVIVAL_FLOOR: Dictionary = {"normal": 3.0, "nightmare": 2.5, "hell": 2.3}


func _band() -> Vector2:
	if not _expected_warden or _tier_id.is_empty():
		return Vector2(PARTY_PRESSURE_FLOOR, PARTY_PRESSURE_CEILING)
	return TIER_BANDS.get(RunState.tier().id, Vector2(PARTY_PRESSURE_FLOOR, PARTY_PRESSURE_CEILING))


func _survival_band() -> float:
	return float(TIER_SURVIVAL_FLOOR.get(RunState.tier().id, 0.0))


## Replays the whole curve for one party size and averages the pressure.
##
## Rebuilt from the same `_measure` the table uses rather than scaled from the
## one-player numbers, because capability does not scale linearly - hero damage
## does, tower damage comes off a shared purse that grows with kills, and the
## whole question is whether those two cancel.
func _mean_pressure_for(count: int) -> float:
	var was: int = _players
	var banked: float = _earned_gold
	_players = count
	# **From an empty purse.** `_measure` accumulates gold as it goes, and a
	# replay that inherits the main run's total starts every party size rich -
	# which reported 0.166 where the real run reports 0.363, and would have
	# shipped a gate that measured its own leftovers.
	_earned_gold = 0.0
	# **And from an empty hand.** The replay inherited the main run's kills and
	# its finished Arsenal, so every party size fought the whole road holding
	# the summit's hand from wave 1 - the gold lesson above, a second time.
	var kills_banked: float = _road_kills
	var hand_banked: Dictionary = _arsenal.duplicate()
	var picks_banked: int = _arsenal_picks
	var kinds_banked: Array[int] = [_boss_picks, _temper_picks, _rerolls, _camp_picks]
	_road_kills = 0.0
	_arsenal = {}
	_arsenal_picks = 0
	_boss_picks = 0
	_temper_picks = 0
	_camp_picks = 0
	_rerolls = _rerolls_start
	var target_banked: Array[String] = _target.duplicate()
	_target = []
	var total: float = 0.0
	var samples: int = 0
	_replay_acts = {}
	var director := WaveDirector.new()
	var wave: int = 0
	var distance: float = 0.0
	var act_wave: int = 0
	var act: int = 1
	while wave < MAX_WAVES:
		wave += 1
		# **Asked the same way the table asks it.** This divided by
		# `ACT_DISTANCE`, which is every act the same length - so it did not
		# know about `ACT_OPENING_EXTRA_DISTANCE` and put every act boundary in
		# the replay several waves away from where the table has it. The two
		# were then reporting two different campaigns, and the party means were
		# the wrong one.
		var now: int = 1
		while now < Balance.FINAL_ASCENT_ACT and distance >= Balance.act_end_distance(now):
			now += 1
		if now != act:
			act = now
			act_wave = 0
		act_wave += 1
		var row: Dictionary = _measure(director, wave, act, act_wave, distance)
		total += float(row["pressure"])
		samples += 1
		if not _party_act_rows.has(count):
			_party_act_rows[count] = {}
		_party_act_rows[count][act] = row
		var sums: Vector2 = _replay_acts.get(act, Vector2.ZERO)
		_replay_acts[act] = sums + Vector2(float(row["pressure"]), 1.0)
		var cycle: float = Balance.WAVE_INTERVAL \
			+ float(row["bodies"]) * Balance.WAVE_SPAWN_SPACING \
			+ ENGAGEMENT_SECONDS
		distance += cycle * Balance.BEAST_BASE_SPEED
		if distance >= Balance.act_end_distance(Balance.FINAL_ASCENT_ACT):
			break
	director.free()
	_players = was
	_earned_gold = banked
	_road_kills = kills_banked
	_arsenal = hand_banked
	_arsenal_picks = picks_banked
	_boss_picks = kinds_banked[0]
	_temper_picks = kinds_banked[1]
	_rerolls = kinds_banked[2]
	_camp_picks = kinds_banked[3]
	_target = target_banked
	return total / maxf(float(samples), 1.0)


func _print_table() -> void:
	print("")
	print("WILDERHOLD — difficulty curve, %d waves, daylight, best-case spending, %d player%s"
		% [_rows.size(), _players, "" if _players == 1 else "s"])
	print("")
	print("  wave  act  lanes  pack  bodies     hp   dmg   spd     threat      gold  twr  lvl  rank draft   capable   pressure  step")
	var previous: float = 0.0
	for row: Dictionary in _rows:
		var pressure: float = float(row["pressure"])
		var step: String = "" if previous <= 0.0 \
			else "%+5.0f%%" % ((pressure / previous - 1.0) * 100.0)
		print("  %4d  %3d  %5d  %4d  %6d  %5.2f %5.2f %5.2f  %9.0f %9.0f  %3d  %3d  %4d %5d %9.0f  %9.2f  %s" % [
			row["wave"], row["act"], row["lanes"], row["per_lane"], row["bodies"],
			row["hp"], row["damage"], row["speed"],
			row["threat"], row["gold"], row["towers"], row["level"],
			row["rank"], row["drafts"], row["capability"], pressure, step])
		previous = pressure

	print("")
	_print_worst_steps()


## The three biggest single-wave jumps. A difficulty cliff is not a high number,
## it is a large step, and reading thirty rows to find one is how they get missed.
func _print_worst_steps() -> void:
	var steps: Array[Dictionary] = []
	for i: int in range(1, _rows.size()):
		var before: float = float(_rows[i - 1]["pressure"])
		var after: float = float(_rows[i]["pressure"])
		if before <= 0.0:
			continue
		steps.append({"wave": _rows[i]["wave"], "jump": after / before - 1.0})
	steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["jump"]) > float(b["jump"]))

	print("Sharpest increases:")
	for i: int in mini(3, steps.size()):
		print("  wave %d: %+.0f%%" % [steps[i]["wave"], float(steps[i]["jump"]) * 100.0])
	var first: float = float(_rows[0]["pressure"])
	var last: float = float(_rows[_rows.size() - 1]["pressure"])
	print("Wave 1 to %d: %.2f -> %.2f (%+.0f%% overall)" % [
		_rows.size(), first, last, (last / maxf(first, 0.001) - 1.0) * 100.0])


## The permanent rewards a run is actually carrying by this act.
##
## **This model knew about none of them.** A ten-act run banks one boss core an
## act - always active, never socketed, no choice involved - and the report
## measured a hero and a set of towers that had never killed anything. By Act X
## a real player holds nine of them, so the late acts were being scored as
## harder than they are.
##
## Cores only, and that is the line. Relics, portents and Road Cards are all
## *choices* - which one, whether to take it, and a portent charges a bane for
## its boon - so modelling them means modelling a player's judgement, and the
## report would start measuring a strategy rather than a curve. A core is paid
## for killing a boss and every run gets the same ones in the same order, which
## is exactly what a baseline wants.
##
## The act's own core is deliberately excluded: it is paid for *killing* this
## act's boss, so it is not in hand while this act is being fought.
##
## **Measured: mean pressure 0.433 before this, 0.353 after.** That is not the
## game getting easier - it is the model catching up with a game that had been
## handing out a permanent +25% tower damage since Act III and scoring the
## seven acts after it as though nobody had one. The band is 0.44 to 0.58 and
## the midpoint is 0.36, so the honest figure sits closer to the middle than
## the flattering one did.
func _bank_the_cores_won_so_far(act: int) -> void:
	var held: Array[String] = []
	for earlier: int in range(1, act):
		var core: RelicData = ContentDB.boss_core_for_act(earlier)
		if core != null:
			held.append(core.id)
	RunState.boss_cores = held
	Modifiers.rebuild()


## **The Arsenal the road has dealt by this wave** (2026-09-27; replaces the
## two-number model of 2026-09-26, whose cards were retired as relic-like).
##
## A draft comes with every road rank - paid in kills, one a body, and in the
## act bosses already down - with every act boss, and with every Tempering. Each
## is spent on whichever pick adds the most modelled damage a second: a new
## weapon, a level of a held one, a catalyst, or an evolution once it is earned.
## **Best case in the sense the purse column is one**: a real hand is chosen
## by a person reading three cards, and this picks from the whole deck.
##
## Carried from wave to wave rather than rebuilt, because the drafts only ever
## grow; a wave is met with the hand from before it. Camps, raids, rifts and
## legends are detours the model does not walk, and their drafts are not
## counted.
func _deal_the_augments_so_far(act: int, wave: int) -> Dictionary:
	if not _with_augments:
		RunState.road_cards = [] as Array[String]
		RunState.road_card_levels = {}
		Modifiers.rebuild()
		return {}
	# A party's bodies pay the rank their share, as `Enemy.road_xp_worth` pays it.
	var xp: float = _road_kills * Balance.ROAD_XP_BODY / WaveDirector.body_scale_for(_players) \
		+ float(act - 1) * Balance.ROAD_XP_BOSS
	var ranks: int = 0
	while xp >= RunState.road_rank_cost(ranks):
		xp -= RunState.road_rank_cost(ranks)
		ranks += 1
	var bosses: int = act - 1
	var tempers: int = (wave - 1) / Balance.AUGMENT_HOLDFAST_WAVES
	# **The first camp razed in each act deals a draft** (2026-10-01). The
	# outskirts were built to be walked into for it, and a model that never
	# took one measured a player who never left the road. One an act, at
	# the act's start, as `RunState.note_camp_augment` deals it; the other
	# detours - raids, rifts, legends - are still left out.
	var camps: int = act if _camp_drafts else 0
	var drafts: int = ranks + bosses + tempers + camps
	if _drafts():
		while _boss_picks < bosses:
			_boss_picks += 1
			_arsenal_picks += 1
			_draft_floor = Balance.AUGMENT_FLOOR_BOSS
			_take_the_best_pick(act)
		while _camp_picks < camps:
			_camp_picks += 1
			_arsenal_picks += 1
			_draft_floor = Balance.AUGMENT_FLOOR_CAMP
			_take_the_best_pick(act)
		_draft_floor = Balance.AUGMENT_FLOOR_RANK
		while _temper_picks < tempers:
			_temper_picks += 1
			_arsenal_picks += 1
			_tempering = true
			_take_the_best_pick(act)
			_tempering = false
	while _arsenal_picks < drafts:
		_arsenal_picks += 1
		if not _take_the_best_pick(act):
			break
	_arsenal_picks = maxi(_arsenal_picks, drafts)
	var hand: Array[String] = []
	for id: Variant in _arsenal:
		hand.append(String(id))
	RunState.road_cards = hand
	RunState.road_card_levels = _arsenal.duplicate()
	Modifiers.rebuild()
	return {"ranks": ranks, "drafts": drafts}


## **One draft, spent toward the planned hand** (2026-09-27). Returns false
## when nothing can grow.
##
## This was plain greedy - whichever pick added the most right now - and the
## day the deck grew nine weapons it walked into the trap every Megabonk player
## learns to avoid: it took whatever had the strongest first level, filled all
## eight places by Act II, and never had room for the catalyst an evolution
## wants. From Act VI it held eight weapons at their last level and spent every
## draft on nothing, and the curve read the road as a tenth harder than a player
## who plans would find it. So the model plans first (`_plan_the_hand`) and
## then drafts greedily *within* the plan - the best pick among the planned
## cards, their levels and the evolutions they earn - and a pick that adds
## nothing now is still taken when it is the plan's last step, which is how a
## catalyst gets into the hand before its weapon is ready.
func _take_the_best_pick(act: int) -> bool:
	if _target.is_empty() and not _drafts():
		_target = _plan_the_hand()
	var offered: Array[String] = _offer_for_draft(act)
	var choice: Dictionary = _best_of(act, offered)
	# **A draft that offers nothing is rerolled, and skipped if it still does**,
	# as a player does with the tools the road hands them: two rerolls to start,
	# and a skipped draft banks one.
	if _drafts() and not _tempering and _offers_nothing(choice):
		if _rerolls > 0:
			_rerolls -= 1
			choice = _best_of(act, _offer_for_draft(act, offered))
		if _offers_nothing(choice):
			_rerolls = mini(_rerolls + 1, Balance.AUGMENT_REROLLS_MAX)
			return true
	var best: Dictionary = choice["hand"]
	if best.is_empty():
		return false
	_arsenal = best
	return true


## Whether the best of an offer adds nothing and says nothing.
func _offers_nothing(choice: Dictionary) -> bool:
	return (choice["hand"] as Dictionary).is_empty() \
		or (int(choice["rank"]) <= 0 and float(choice["gain"]) <= 0.0)


## **The best pick among `offered`**, or the whole deck for a build that reads
## it: the hand it makes, what it says to a reader, and what it adds.
func _best_of(act: int, offered: Array[String]) -> Dictionary:
	var now: float = _arsenal_value(_arsenal, act)
	var best: Dictionary = {}
	var gain: float = -1.0
	var rank: int = -1
	var ids: Array[String] = []
	for id: Variant in ContentDB.road_cards:
		ids.append(String(id))
	ids.sort()
	for id: String in ids:
		var card: RoadCardData = ContentDB.road_card(id)
		if card == null or card.retired or card.keystone or card.first_act > act:
			continue
		if not card.is_weapon() and not card.effect_id.begins_with("arsenal_"):
			continue
		if not _in_the_plan(card):
			continue
		if _drafts() and not offered.has(id):
			continue
		# The game's own rule for what a hand may be dealt, so the model never
		# holds what a player could not.
		if not Augments.may_deal(card, _arsenal.keys(), _arsenal, []):
			continue
		var trial: Dictionary = _arsenal.duplicate()
		if not card.evolves_from.is_empty():
			trial.erase(card.evolves_from)
			trial[id] = 1
		elif trial.has(id):
			if int(trial[id]) >= card.max_level():
				continue
			trial[id] = int(trial[id]) + 1
		elif trial.size() >= Balance.ROAD_CARD_HAND:
			if not _drafts():
				continue
			var leaving: String = _weakest_held(trial, act)
			if leaving.is_empty():
				continue
			trial.erase(leaving)
			trial[id] = 1
		else:
			trial[id] = 1
		var worth: float = _arsenal_value(trial, act) - now
		var priority: int = _reader_priority(card) if _build == "reader" else 0
		# Nothing to say and nothing gained is not a pick, as it never was.
		if priority == 0 and worth <= -1.0:
			continue
		if priority > rank or (priority == rank and worth > gain):
			rank = priority
			gain = worth
			best = trial
	return {"hand": best, "rank": rank, "gain": gain}


## **What a card says to a reader**, as a rank among the three: an earned
## evolution, then a level on a weapon whose catalyst is held, then the other
## half of a pair begun, then nothing to say. The numbers break a tie.
func _reader_priority(card: RoadCardData) -> int:
	var hand: Array = _arsenal.keys()
	if not card.evolves_from.is_empty():
		return 3
	if hand.has(card.id):
		for line: Variant in Augments.evolution_lines():
			var parts: Array = line as Array
			if parts[1] == card.id and hand.has(parts[2]) and not hand.has(parts[0]):
				return 2
		return 0
	return 1 if Augments.pairs_with(card.id, hand) else 0


## The held card whose loss costs the hand least, for a drafter leaving one
## behind - and for a reader, never half of a pair it has begun.
func _weakest_held(hand: Dictionary, act: int) -> String:
	var whole: float = _arsenal_value(hand, act)
	var weakest: String = ""
	var least: float = INF
	for held: Variant in hand:
		if _build == "reader" and Augments.pairs_with(String(held), hand.keys()):
			continue
		var without: Dictionary = hand.duplicate()
		without.erase(held)
		var loss: float = whole - _arsenal_value(without, act)
		if loss < least:
			least = loss
			weakest = String(held)
	return weakest


## **Three cards a draft offers**, for the draft build: drawn without repeats
## from what the game may deal this hand, on dice seeded by the act and the
## pick so the report is the same on every run. Empty for the other builds,
## which read the whole deck.
func _offer_for_draft(act: int, exclude: Array[String] = []) -> Array[String]:
	var out: Array[String] = []
	if not _drafts():
		return out
	var pool: Array[String] = []
	var ids: Array[String] = []
	for id: Variant in ContentDB.road_cards:
		ids.append(String(id))
	ids.sort()
	for id: String in ids:
		var card: RoadCardData = ContentDB.road_card(id)
		if card == null or card.retired or card.keystone or card.first_act > act:
			continue
		if not card.is_weapon() and not card.effect_id.begins_with("arsenal_"):
			continue
		if not Augments.may_deal(card, _arsenal.keys(), _arsenal, []):
			continue
		pool.append(id)
	_draft_dice.seed = hash([act, _arsenal_picks, _players, "draft", _draft_salt])
	# **Dealt by the game's own deal**, weights and all, so a change to how
	# the deal leans is measured here the day it is made. Only the cards the
	# model fights with are kept from the deal; a keystone or a ward offered
	# is a pick that adds nothing this model counts, which is what it is.
	var hand: Array = _arsenal.keys()
	var dealt: Array[String] = Augments.temper(_draft_dice, hand, _arsenal,
		_offer_count) if _tempering \
		else Augments.deal(_draft_dice, _offer_count, _draft_floor, hand,
			_arsenal, act, [], _draft_luck, [], exclude)
	for id: String in dealt:
		if pool.has(id):
			out.append(id)
	return out


## Whether a card is one the planned hand wants: in the plan, or the evolution a
## planned weapon and a planned catalyst earn together.
func _in_the_plan(card: RoadCardData) -> bool:
	if not _build_allows(card):
		return false
	if _drafts():
		return true
	if card.evolves_from.is_empty():
		return _target.has(card.id)
	return _target.has(card.evolves_from) and _target.has(card.evolves_with)


## Whether this run's build would take a card at all: a weapon anchored where
## the build is, or a catalyst, which every build takes.
func _build_allows(card: RoadCardData) -> bool:
	if _build == "best" or _drafts() or not card.is_weapon():
		return true
	var weapon: ArsenalWeaponData = card.weapon_data()
	if weapon == null:
		return true
	match _build:
		"warden":
			return weapon.anchor == ArsenalWeaponData.Anchor.WARDEN
		"towers":
			return weapon.anchor == ArsenalWeaponData.Anchor.TOWERS
		"town":
			return weapon.anchor == ArsenalWeaponData.Anchor.TOWN
	return true


## **The hand a player who plans builds toward**: eight cards chosen by what they
## are worth at the end of the road, every weapon at its last level and every
## evolution taken whose weapon and catalyst are both held. A weapon and its
## catalyst are weighed as a pair, by what they add a place, so an evolution
## line is judged as the one thing it is. Best case in the sense the purse is
## one: a real hand is chosen by a person reading three cards at a time.
func _plan_the_hand() -> Array[String]:
	var towers_were: int = _bought_towers
	_bought_towers = Balance.ARSENAL_MODEL_TOWERS
	var singles: Array[String] = []
	var lines: Array = []
	var ids: Array[String] = []
	for id: Variant in ContentDB.road_cards:
		ids.append(String(id))
	ids.sort()
	for id: String in ids:
		var card: RoadCardData = ContentDB.road_card(id)
		if card == null or card.retired or card.keystone or not _build_allows(card):
			continue
		if not card.evolves_from.is_empty():
			lines.append([id, card.evolves_from, card.evolves_with])
		elif card.is_weapon() or card.effect_id.begins_with("arsenal_"):
			singles.append(id)
	var target: Array[String] = []
	while target.size() < Balance.ROAD_CARD_HAND:
		var now: float = _final_value(target, lines)
		var best: Array[String] = []
		var best_rate: float = 0.0
		for id: String in singles:
			if target.has(id):
				continue
			var trial: Array[String] = target.duplicate()
			trial.append(id)
			var rate: float = _final_value(trial, lines) - now
			if rate > best_rate:
				best_rate = rate
				best = [id]
		for line: Array in lines:
			var adds: Array[String] = []
			for part: Variant in [line[1], line[2]]:
				if not target.has(String(part)):
					adds.append(String(part))
			if adds.is_empty() or target.size() + adds.size() > Balance.ROAD_CARD_HAND:
				continue
			var trial: Array[String] = target.duplicate()
			trial.append_array(adds)
			var rate: float = (_final_value(trial, lines) - now) / float(adds.size())
			if rate > best_rate:
				best_rate = rate
				best = adds
		if best.is_empty():
			break
		target.append_array(best)
	_bought_towers = towers_were
	return target


## What a set of cards is worth at the summit, every weapon at its last level and
## every evolution its weapon and catalyst earn.
func _final_value(cards: Array[String], lines: Array) -> float:
	var hand: Dictionary = {}
	for id: String in cards:
		var card: RoadCardData = ContentDB.road_card(id)
		if card != null:
			hand[id] = card.max_level()
	for line: Array in lines:
		if hand.has(String(line[1])) and hand.has(String(line[2])):
			hand.erase(String(line[1]))
			hand[String(line[0])] = 1
	return _arsenal_value(hand, Balance.FINAL_ASCENT_ACT)


## **What a hand of the Arsenal deals a second** - `ArsenalWeaponData.modelled_dps`,
## the line `arsenal_check` holds the fight to, through `Arsenal.hit_for`'s own
## factors: the act, the Warden's Might (a point a level, and gear - the account
## this report reads), the hand and the form, the Arsenal's power, its cadence
## and its volley. A weapon at a Warden's side counts once a Warden, one on the
## towers once for each tower in a Warden's reach - `ARSENAL_MODEL_TOWERS`, or
## fewer while the purse has bought fewer - (and an arc once, its count being
## the pairs), one on the town once.
func _arsenal_value(hand: Dictionary, act: int, single: bool = false,
		warden_only: bool = false) -> float:
	var power: float = 0.0
	var haste: float = 0.0
	var more: int = 0
	for id: Variant in hand:
		var card: RoadCardData = ContentDB.road_card(String(id))
		if card == null or card.is_weapon():
			continue
		var amount: float = card.magnitude_at(int(hand[id]))
		match card.effect_id:
			Modifiers.ARSENAL_POWER:
				power += amount
			Modifiers.ARSENAL_HASTE:
				haste += amount
			Modifiers.ARSENAL_COUNT:
				more += int(round(amount))
	var might: float = float(WardenSheet.attribute_of(null, RunState.Attribute.MIGHT))
	var scale: float = Balance.arsenal_act_scale(act) * (1.0 + power) \
		* (1.0 + might * Balance.HERO_MIGHT_PER_POINT) * _core_scale(Modifiers.HERO_DAMAGE) \
		* _discipline_scale() / maxf(1.0 - haste, Balance.ARSENAL_CADENCE_FLOOR)
	var total: float = 0.0
	for id: Variant in hand:
		var card: RoadCardData = ContentDB.road_card(String(id))
		var weapon: ArsenalWeaponData = card.weapon_data() if card != null else null
		if weapon == null:
			continue
		if warden_only and weapon.anchor != ArsenalWeaponData.Anchor.WARDEN:
			continue
		var level: int = int(hand[id])
		var dps: float = weapon.modelled_dps(level)
		# **One body, for a boss** (2026-10-01): `modelled_dps` is a crowd's
		# worth - a hit times the bodies it lands on - and a giant is one.
		if single:
			dps /= maxf(float(weapon.crowd), 1.0)
		var shots: int = weapon.count_at(level)
		if more > 0 and not _fires_once(weapon):
			dps *= float(shots + mini(more, Balance.ARSENAL_COUNT_CEILING)) / float(maxi(shots, 1))
		match weapon.anchor:
			ArsenalWeaponData.Anchor.WARDEN:
				dps *= float(_players)
			ArsenalWeaponData.Anchor.TOWERS:
				if weapon.pattern == ArsenalWeaponData.Pattern.ARC:
					dps *= 1.0 if _bought_towers >= 2 else 0.0
				else:
					dps *= float(mini(_bought_towers, Balance.ARSENAL_MODEL_TOWERS))
		total += dps
	return total * scale


## A weapon that fires once where it stands, whose count the fight never reads.
func _fires_once(weapon: ArsenalWeaponData) -> bool:
	match weapon.pattern:
		ArsenalWeaponData.Pattern.NOVA, ArsenalWeaponData.Pattern.TRAIL:
			return true
		ArsenalWeaponData.Pattern.STRIKE:
			return weapon.anchor == ArsenalWeaponData.Anchor.TOWERS
		ArsenalWeaponData.Pattern.ON_KILL:
			return weapon.speed <= 0.0
	return false


## What the banked cores do to one number, as a multiplier.
##
## Read off the live table rather than summed from the data, so a core authored
## onto a different key moves this by itself - and so the model cannot drift
## from what the game resolves.
func _core_scale(key: String) -> float:
	return maxf(Modifiers.multiplier(key), 0.0)
