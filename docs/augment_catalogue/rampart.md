# Rampart — 20 proposed augment cards

**Design proposal; none of the revisions below is implemented by this document.** This is the Rampart third of the proposed 60-card catalogue: sixteen ordinary cards and four mutually exclusive keystones. Every number is **[TUNE]**, including times, target counts, distances and limits. A complete specification makes the work testable; it does not make these values playtested.

The unlock labels below use the parent catalogue's proposed three-act campaign plus summit. The current playable campaign and staged cards use ten acts; implementing this catalogue requires an explicit unlock-table migration, not silently renumbering the existing content.

Rampart should make the Warden's decisions improve the board. Four dependable cards establish a defence. The other twelve ordinary cards reward targeting, an elemental formation, rescue, or spending Command. Keystones change how an existing effect reaches its target. Nothing repairs structures automatically, creates towers during combat, or gives unattended tower kills a new reward loop.

## Shared rules for this branch

- **Ownership and slots:** solo uses eight slots across all branches. In co-op, Rampart/Hearth and every keystone use the eight-slot party board; each hero also has four ordinary Warden slots. One keystone total for the party. A second copy upgrades its destination-hand family rather than stacking. Board effects share one trigger budget regardless of player count. Ordinary cards retain their intrinsic rarity at every level.
- **Levels:** the five authored values below replace the current automatic magnitude multiplier for these proposed revisions. Each successful upgrade must change the displayed and resolved value. The Conductor is an explicitly fixed, one-level counted utility; keystones are also fixed at level I. Never offer a capped card as an upgrade.
- **Definitions:** a direct Warden hit is a player-initiated melee, ranged or actively cast skill impact, excluding damage over time, summons, reflected damage and generated augment effects. A direct kill must have that impact as its lethal source. A priority enemy is an authored support, siege, elite or boss role; summoned disposable bodies and resurrected copies do not qualify for reward triggers. An interrupt must actually cancel an interruptible hostile action. A perfect dodge must evade a committed damaging attack, not merely dash near a telegraph.
- **Events and causality:** triggered card effects cannot activate other cards. A real Warden action may satisfy several independent cards, but each receives the original event once. Base tower impacts can satisfy the two expressly named formation conditions below; bonus chains and secondary card effects cannot. Every transient state belongs to `RunState` and the suspended battlefield's clock.
- **Targets and distances:** distances use build-grid tile widths, measured between combat origins. Resolve ties by stable tower/enemy instance ID. A tower must be built, alive and enabled when receiving or consuming a benefit. Support towers without a damage attack never receive damage, attack-rate or extra-chain buffs. Combination towers qualify for element conditions through their authored parent elements; they count as one tower and one impact, never two elements on the same impact.
- **Bounded buffs:** all Rampart direct-damage additions share an augment-only additive bucket capped at **+40%**; attack-rate additions cap at **+25%**; reach additions at **+25%**. Armour means an explicitly proposed damage-taken reduction, additive within an augment-only bucket capped at **25%**, resolved after flat armour; this is not the current `tower_armour` flat-reduction interpretation. Other systems keep their own authored semantics. The final combined mitigation ceiling must be checked with relics, shields and Command before release.
- **Timer rules:** durations do not stack; a retrigger may refresh only where the individual card says so. Cooldowns begin when a benefit is granted. Raid entry freezes these timers and all stored charges exactly; the cards give no raid-arena benefit. Normal battle completion discards transient marks, charges and buffs. Cooldowns must not be reset by opening a menu, reconnecting, replacing a card, or save/load; a new battle starts a fresh battle budget.
- **Bosses:** direct damage, burn and valid tower buffs work normally. Control retains the target's existing resistances, diminishing returns and immunities. A card never interrupts an uninterruptible action, adds a boss vulnerability, or overrides a scripted invulnerability.
- **Keystones:** all four require three **other held Rampart cards**, plus the stated usable source. Losing that depth or source suppresses the keystone immediately; it does not consume a new slot or refund a draft. All four are alternatives, not a stack. Display the unmet requirement on the hand card. Rerouting cannot extend an effect's original expiry or multiply its magnitude.
- **Presentation:** front text below is the level-I face. Inspection shows current → next values, conditions, source eligibility, party ownership and limits. An icon motif is an art brief only. Reuse refers to an existing icon for that same card ID; no new asset, placeholder or manifest requirement is created by this proposal.

## Catalogue at a glance

| # | Card / stable ID | Rarity | Earliest act | What earns its value |
|---|---|---|---|---|
| R01 | The Whetstone Hour / `whetstone_hour` | Common | I | Reliable tower damage |
| R02 | Banked Earth / `banked_earth` | Common | I | Reliable structure protection |
| R03 | Cleared Sightlines / `cleared_sightlines` | Common | I | Reliable firing reach |
| R04 | The Propped Gate / `propped_gate` | Common | I | A larger Town Hall health ceiling |
| R05 | Cold Iron Stakes / `cold_iron_stakes` | Uncommon | I | Strike the enemy your Water towers must hold |
| R06 | Dry Powder / `dry_powder` | Uncommon | I | Strike burning enemies to strengthen tower burns |
| R07 | The Conductor / `the_conductor` | Rare | II | Overdrive a real chain tower |
| R08 | Measured Volley / `measured_volley` | Uncommon | I | Change doctrine to answer a priority target |
| R09 | Stone and Spark / `stone_and_spark` | Rare | II | Follow your hit with Earth control near Air towers |
| R10 | Crossing Fire / `crossing_fire` | Rare | II | Two towers of different elements help finish your target |
| R11 | Stand by the Wall / `stand_by_the_wall` | Uncommon | I | Perfect-dodge beside a damaged tower |
| R12 | Sealed Footings / `sealed_footings` | Uncommon | II | Rally the road facing a disable threat |
| R13 | Hammer the Breach / `hammer_the_breach` | Rare | II | Personally finish an elite on a pressured road |
| R14 | Parents Kept / `parents_kept` | Rare | II | Interrupt a threat to a fusion's parent |
| R15 | Crosswind Orders / `crosswind_orders` | Uncommon | II | Extend the reach of your Overdrive target |
| R16 | Hold the Gap / `hold_the_gap` | Uncommon | I | Help Earth towers push threats away from the gate |
| R17 | Cold Snap / `cold_snap` | Epic keystone | II | Finish a chilled enemy to transfer its chill |
| R18 | Sapper's Due / `sappers_due` | Rare keystone | II | A personal elite kill recovers a spent trap charge |
| R19 | Relief Watch / `relief_watch` | Epic keystone | II | Carry the remainder of Overdrive to another road |
| R20 | Common Cause / `common_cause` | Epic keystone | III | Spend Overdrive to briefly restore an orphaned fusion's utility |

## R01 — The Whetstone Hour [`whetstone_hour`]

- **Rarity / act / prerequisite / target:** Common / I / at least one living damaging tower / all party towers that have a direct attack, including fusions.
- **Front:** “Towers deal **8% more direct damage**.”
- **Levels I–V:** **+8 / 10 / 12 / 14 / 16%** direct tower damage.
- **Resolution:** continuously contributes to the +40% damage bucket; no trigger, duration or cooldown. Applies to the attack's direct primary, splash and native chain hits, once per resolved damage packet. Does not increase burn, ground damage, trap damage, healing or Command generation. Normal boss rules; suspended and inactive in raids.
- **Synergy IDs:** `measured_volley`, `crossing_fire`, `common_cause`.
- **Edges:** a fusion uses its own attack once, not an extra bonus for each parent. A card proc cannot manufacture a second copy of a projectile. Modifier previews must separate direct damage from burn damage.
- **Status:** **Existing revised.** Consolidates `the_master_founder` and staged `masterwork_arsenal` into this family; no separate rarity-upgrade cards.
- **Acceptance:** at level V, a 100-damage base impact resolves as 116 before enemy mitigation, while a separate 20-DPS burn remains 20.
- **Icon:** whetstone across a blade; reuse `res://art/icons/road_cards/card_whetstone_hour.png`.

## R02 — Banked Earth [`banked_earth`]

- **Rarity / act / prerequisite / target:** Common / I / at least one living tower / party towers, including blockers and fusions; not the Town Hall.
- **Front:** “Towers take **8% less damage**.”
- **Levels I–V:** **8 / 11 / 14 / 17 / 20%** tower damage reduction.
- **Resolution:** continuous contribution to the 25% augment mitigation bucket, after flat armour. No trigger, duration or cooldown; no repair or shield grant. Applies to valid enemy attacks and authored environmental damage that normally damages a tower. Boss damage qualifies; raid timers and board stay frozen.
- **Synergy IDs:** `stand_by_the_wall`, `parents_kept`, `common_cause`.
- **Edges:** explicitly a new percentage-reduction interpretation, not multiplying the existing tiny flat-armour number. Negative damage is impossible. Rebuilding or replacing a card does not heal a tower. Immunity remains an existing system's effect, never this card's.
- **Status:** **Existing revised; mechanic migration required.** Merges `riveted_plate` and staged `rampart_of_legend`.
- **Acceptance:** a 100-damage hit after flat armour becomes 80 at V; with Stand by the Wall also active it cannot become less than 75 through augments alone.
- **Icon:** earth bank against a tower footing; reuse `res://art/icons/road_cards/card_banked_earth.png`.

## R03 — Cleared Sightlines [`cleared_sightlines`]

- **Rarity / act / prerequisite / target:** Common / I / one living damaging tower / party damaging towers and fusions.
- **Front:** “Tower attacks reach **5% farther**.”
- **Levels I–V:** **+5 / 7 / 9 / 11 / 13%** attack range.
- **Resolution:** continuous contribution to the +25% reach bucket. No trigger, duration or cooldown. Extends acquisition and legitimate attack reach, not splash radius, aura size, projectile chain-search radius, support radius or well reach. Boss targets use ordinary acquisition; no raid benefit.
- **Synergy IDs:** `crosswind_orders`, `the_conductor`, `relief_watch`.
- **Edges:** does not turn an out-of-bounds or hidden target into a legal target. Display the actual resulting reach. A projectile already fired remains valid when a temporary reach buff ends, using existing projectile rules.
- **Status:** **Existing revised.** Merges `the_watchtower_eye`.
- **Acceptance:** a base-range-200 tower has range 226 at V; its base-40 splash radius stays 40, and its combined reach bonus never exceeds 25% from augments.
- **Icon:** cleared branches framing an eye; reuse `res://art/icons/road_cards/card_cleared_sightlines.png`.

## R04 — The Propped Gate [`propped_gate`]

- **Rarity / act / prerequisite / target:** Common / I / a living Town Hall / shared Town Hall maximum health.
- **Front:** “The Town Hall's maximum health is **10% higher**. This does not repair it.”
- **Levels I–V:** **+10 / 12.5 / 15 / 17.5 / 20%** maximum health, additive to the augment maximum-health bucket capped at +20%.
- **Resolution:** continuous maximum-health modifier; no duration or cooldown. Taking or levelling the card preserves current HP in absolute units. Repairs may later fill the additional capacity through their existing paid or earned rules. If the card leaves the hand, clamp current HP to the reduced maximum without granting any health.
- **Synergy IDs:** `banked_earth`, `stand_by_the_wall`, `hold_the_gap`.
- **Edges:** taking, replacing, saving or reconnecting never restores current HP. It cannot resurrect a destroyed Town Hall or delay an already resolved defeat. Boss and summit attacks use the ordinary health pool; no extra raid protection.
- **Status:** **Existing revised; current-HP policy must be verified.** Merges `the_deep_cellar` and staged `the_great_gate`.
- **Acceptance:** a 1,000-max/600-current Town Hall becomes 1,200-max/600-current at V; repeatedly dropping and reacquiring the family never raises 600.
- **Icon:** one heavy beam holding a gate; reuse `res://art/icons/road_cards/card_propped_gate.png`.

## R05 — Cold Iron Stakes [`cold_iron_stakes`]

- **Rarity / act / prerequisite / target:** Uncommon / I / a living tower with a real slow effect / enemies directly struck by a Warden.
- **Front:** “For **6 seconds** after you hit an enemy, tower slows reduce its movement by **5 extra percentage points**.”
- **Levels I–V:** **5 / 7 / 9 / 11 / 13 percentage points** additional slow.
- **Resolution:** a direct Warden hit marks that enemy for six seconds; subsequent direct hits refresh, never stack. Keep at most three marked enemies party-wide, replacing the oldest. Only an existing tower slow can receive the added strength. It gains no duration and does not create chill, freeze or a new status. The card cannot lower final movement speed below 25% of normal; stricter boss floors win. No cooldown; six-second marks freeze during raids.
- **Synergy IDs:** `cold_snap`, `crossing_fire`, `hold_the_gap`.
- **Edges:** no extra benefit on slow-immune targets. If a different system already slows below 25%, leave that system's result unchanged and add nothing. Switching away from all usable slow towers suppresses the card.
- **Status:** **Existing revised; conditional slow reader required.** Merges staged `frostbitten_iron`.
- **Acceptance:** a tower's 30% slow becomes 43% at V on a marked ordinary enemy, stays 30% on an unmarked enemy, and never bypasses a boss's own limit.
- **Icon:** pale stakes in frozen earth; reuse `res://art/icons/road_cards/card_cold_iron_stakes.png`.

## R06 — Dry Powder [`dry_powder`]

- **Rarity / act / prerequisite / target:** Uncommon / I / a living burn-applying tower / currently burning enemies personally struck by a Warden.
- **Front:** “Hit a burning enemy to make tower burns on it deal **12% more damage for 6 seconds**.”
- **Levels I–V:** **+12 / 18 / 24 / 30 / 36%** tower burn damage on the marked enemy.
- **Resolution:** snapshot eligibility on the direct Warden hit; the enemy must already carry a tower burn. Mark lasts six seconds, refreshable by another eligible hit. Maximum three marked enemies party-wide; replace oldest. Adds to the existing burn-damage bucket, with a proposed augment-only ceiling of +40%. Does not add or extend burn stacks, ignite terrain or affect hero burns. No cooldown; bosses retain burn resistance, and raid entry freezes the mark.
- **Synergy IDs:** `crossing_fire`, `cold_iron_stakes`, `common_cause`.
- **Edges:** burn damage cannot refresh its own mark. A newly applied burn may use the remaining mark, but removing all burns does not produce free ignition. Marks expire normally if the player leaves the road.
- **Status:** **Existing revised; conditional burn reader required.** Merges staged `pitch_and_tar`.
- **Acceptance:** at V a tower's otherwise-100-DPS burn becomes 136 DPS for six seconds after the valid hit; a hero's separate burn and an unmarked enemy remain unchanged.
- **Icon:** sealed powder horn above a small ember; reuse `res://art/icons/road_cards/card_dry_powder.png`.

## R07 — The Conductor [`the_conductor`]

- **Rarity / act / prerequisite / target:** Rare / II / Overdrive available and a living damaging tower with native chaining / the chosen Overdrive tower.
- **Front:** “After Overdrive, that tower's next chain attack jumps to **1 extra enemy**.”
- **Levels:** **fixed I: +1 additional chain target**. No duplicate upgrades.
- **Resolution:** a paid, successful Overdrive gives its target one charge lasting six seconds. The next native chain attack consumes it on launch. Extend only the native chain, with its existing range and falloff; cap at one extra enemy per attack and one stored charge for the party. A new valid grant replaces the old charge; six-second party cooldown. Bosses may be one native target but never receive multiple hits from the same attack. No charge is spent or granted in raids.
- **Synergy IDs:** `cleared_sightlines`, `crosswind_orders`, `stone_and_spark`.
- **Edges:** cannot give chaining to a non-chain tower; the draft names this requirement. If no additional legal enemy exists, the attack consumes the charge without duplicating damage onto its first target. The extra hit cannot trigger other augments.
- **Status:** **Existing revised; charged attack condition required.** Merges staged `the_storm_coil`.
- **Acceptance:** a two-target native attack can strike three distinct legal enemies once after Overdrive; the following attack returns to two and a lone boss is still hit once.
- **Icon:** a forked conducting rod; reuse `res://art/icons/road_cards/card_the_conductor.png`.

## R08 — Measured Volley [`measured_volley`]

- **Rarity / act / prerequisite / target:** Uncommon / I / doctrines available and a living damaging tower / the tower whose doctrine the player changes.
- **Front:** “After you change a tower's doctrine, its next direct attack against a priority enemy deals **12% more damage**.”
- **Levels I–V:** **+12 / 16 / 20 / 24 / 28%** direct damage for one eligible attack.
- **Resolution:** changing to a different doctrine arms one charge for eight seconds. The tower must have fired under its old doctrine since its last activation. Only an attack whose primary target is a priority enemy consumes the charge; buff only that primary impact, not splash or chains. Twelve-second cooldown per tower; at most three charged towers party-wide, oldest charge displaced. Adds to the +40% direct-damage bucket. Bosses qualify; raid entry freezes charge and cooldown.
- **Synergy IDs:** `whetstone_hour`, `crossing_fire`, `cleared_sightlines`.
- **Edges:** clicking the current doctrine or cycling through menus does nothing. Reverting does not stack or renew a charge. Failed or cancelled shots retain the charge until expiry; a successfully launched shot consumes it once even if it misses.
- **Status:** **New mechanic** using existing doctrine and attack events.
- **Acceptance:** repeated doctrine toggles without an intervening real shot grant one charge at most; an eligible shot receives the current level's bonus once.
- **Icon motif:** one sighting notch aligned with a command pennant; new same-ID icon would be required at implementation.

## R09 — Stone and Spark [`stone_and_spark`]

- **Rarity / act / prerequisite / target:** Rare / II / one Earth tower with displacement or stagger and a distinct Air damaging tower within four tiles of that source / up to two Air towers near the Earth source.
- **Front:** “When an Earth tower staggers or pushes an enemy you recently hit, the nearest **2 Air towers** fire **8% faster for 6 seconds**.”
- **Levels I–V:** **+8 / 10 / 12 / 14 / 16%** attack rate.
- **Resolution:** the target must have taken a direct Warden hit in the previous four seconds. A native Earth tower impact must then cause actual stagger or displacement. Select the nearest two living Air attack towers within four tiles of the Earth source, excluding that source; buff for six seconds. Ten-second party cooldown. Adds to the +25% rate bucket and never resets attack timers. Fusions may qualify through an Earth or Air parent but cannot be both source and recipient in one activation.
- **Synergy IDs:** `hold_the_gap`, `the_conductor`, `crossing_fire`.
- **Edges:** resisted control does not activate it; boss control immunities remain. Player knockback, generated bonus hits and repeated crowd-control updates are not Earth-source events. Raid entry freezes all associated state.
- **Status:** **New mechanic** joining existing elemental control and tower rate.
- **Acceptance:** Warden hit → valid Earth stagger grants the nearest two Air towers the buff once; reversing the order, using a resisted stagger, or reusing the source tower as recipient grants nothing.
- **Icon motif:** an earth buttress protecting a fork of lightning; new same-ID icon would be required.

## R10 — Crossing Fire [`crossing_fire`]

- **Rarity / act / prerequisite / target:** Rare / II / two living damaging towers contributing two different elements / enemies directly engaged by a Warden.
- **Front:** “After two different tower elements hit your target, towers deal **10% more direct damage** to it for **5 seconds**.”
- **Levels I–V:** **+10 / 13 / 16 / 19 / 22%** direct tower damage to the marked enemy.
- **Resolution:** a direct Warden hit opens a three-second collection window on that enemy. Two distinct towers must land native direct impacts representing different elements within that window. Each attack resource explicitly declares one `formation_element` from its tower's elements; a fusion cannot count as both on one hit or change that choice opportunistically. Completion grants five seconds of bonus; eight-second cooldown per enemy from completion. At most three active collection/buff records party-wide, replacing oldest; retain cooldown receipts separately until expiry even if a record is evicted. The completing hit is not retroactively amplified. Adds to the +40% bucket; bosses qualify.
- **Synergy IDs:** `dry_powder`, `cold_iron_stakes`, `stone_and_spark`.
- **Edges:** DoTs, extra augment chains and generated effects do not count. Hits during the buff do not renew it. Three-record cap and cooldown survive save/load; raids freeze both.
- **Status:** **New mechanic** using native impact element metadata.
- **Acceptance:** one dual-element fusion hitting twice cannot activate it; a Fire tower and Water tower following a Warden hit can, and the bonus ends after five seconds without automatic renewal.
- **Icon motif:** two different arrowheads crossing over one target; new same-ID icon would be required.

## R11 — Stand by the Wall [`stand_by_the_wall`]

- **Rarity / act / prerequisite / target:** Uncommon / I / a living tower and a usable dash / nearby damaged towers.
- **Front:** “Perfect-dodge beside a damaged tower to make up to **3 nearby towers take 12% less damage for 4 seconds**.”
- **Levels I–V:** **12 / 15 / 18 / 21 / 24%** tower damage reduction.
- **Resolution:** a verified perfect dodge must occur within three tiles of at least one living tower below full health. Grant the buff to the nearest three living towers within that radius for four seconds. Eight-second party cooldown. Adds to the 25% augment mitigation bucket; no healing, shield or timer reset. Boss attacks can provide the qualifying dodge under the same verified-hit test. Raid entry freezes the buff and cooldown.
- **Synergy IDs:** `banked_earth`, `parents_kept`, `relief_watch`.
- **Edges:** intentional tower damage alone cannot trigger anything. A harmless telegraph, dash near a stationary enemy, or co-op duplication of one dodge does not count. Destroyed towers cannot be selected.
- **Status:** **New mechanic**; depends on a verified perfect-dodge event, not the current proximity-only approximation.
- **Acceptance:** an actually evaded boss strike grants four seconds once; merely dashing beside its telegraph grants nothing, and Banked Earth cannot raise combined augment mitigation past 25%.
- **Icon motif:** a bootprint passing behind a battered parapet; new same-ID icon would be required.

## R12 — Sealed Footings [`sealed_footings`]

- **Rarity / act / prerequisite / target:** Uncommon / II / Rally Road available and an upcoming or present authored tower-disable threat / the selected road's living towers.
- **Front:** “When Rally Road's protection ends, new tower disables on that road last **20% less time for 4 seconds**.”
- **Levels I–V:** **20 / 30 / 40 / 50 / 60%** reduction to newly applied disable duration.
- **Resolution:** a paid Rally Road schedules a four-second window beginning when that order's native disable protection expires normally. Snapshot eligible towers at the successful order. Shorten disables applied during the later window once, after enemy duration rules; do not cleanse existing effects or shorten hostile attack telegraphs. Eight-second party cooldown begins at scheduling; one pending/active window, no stacking or refresh. Cancellation or premature loss of the original order cancels its pending window. Does not affect damage, slows, environmental danger or scripted boss lockouts. Raid entry freezes both the pending delay and active window.
- **Synergy IDs:** `banked_earth`, `parents_kept`, `common_cause`.
- **Edges:** complete immunity during native Rally does not consume this later window. Other immunity can still make an individual application irrelevant. Suppress the offer if no reducible disable exists. Its native-protection-ended event must be implemented and tested; it never lengthens invulnerability or cleanses a boss lockout.
- **Status:** **New mechanic; conditional release gate** on a useful, nonredundant disable-duration reader.
- **Acceptance:** a normally five-second reducible disable newly applied during the window lasts two seconds at V; an existing disable and a scripted boss lockout are unchanged.
- **Icon motif:** wax-sealed joints at a tower's feet; new same-ID icon would be required.

## R13 — Hammer the Breach [`hammer_the_breach`]

- **Rarity / act / prerequisite / target:** Rare / II / damaging towers on a road and an authored elite encounter available / towers on the elite's road.
- **Front:** “Personally defeat an elite or boss while another enemy remains on its road: its nearest **4 towers fire 9% faster for 5 seconds**.”
- **Levels I–V:** **+9 / 12 / 15 / 18 / 21%** tower attack rate.
- **Resolution:** the lethal event must be a direct Warden impact on a naturally spawned elite or boss, while at least one hostile remains on that road. Grant five seconds to the nearest four eligible towers on that road within six tiles of the death. Twelve-second party cooldown, no stacking; +25% rate-bucket cap. Does not reset attacks, accelerate wells, or reward passive tower kills. Boss adds retain their own authored rank; the boss itself qualifies only if fighting continues.
- **Synergy IDs:** `whetstone_hour`, `measured_volley`, `relief_watch`.
- **Edges:** no benefit after battle-end cleanup; killing resurrected or endlessly summoned copies does not farm triggers. Both co-op observers share one death-event ID. Raid elite kills do not affect the suspended battlefield.
- **Status:** **New mechanic** using existing kill attribution and tower rate.
- **Acceptance:** a direct elite kill with three surviving enemies buffs at most four nearby towers once; a tower kill, summoned-copy kill or last-enemy kill grants nothing.
- **Icon motif:** a hammer through a broken siege crest; new same-ID icon would be required.

## R14 — Parents Kept [`parents_kept`]

- **Rarity / act / prerequisite / target:** Rare / II / a living fusion with two living linked parents / one fusion whose parent the Warden protects.
- **Front:** “Interrupt an enemy attacking a fusion's parent to make that fusion take **12% less damage for 6 seconds**.”
- **Levels I–V:** **12 / 15 / 18 / 21 / 24%** fusion damage reduction.
- **Resolution:** a direct Warden action must genuinely interrupt an attack already committed against one of the fusion's living parents. Select the threatened parent's closest eligible fusion if it feeds more than one, tie by ID. Grant six seconds; ten-second party cooldown; one protected fusion at a time. Adds to the 25% mitigation bucket. Both linked parents must remain alive; losing either suppresses the buff immediately. No parent HP is restored.
- **Synergy IDs:** `banked_earth`, `stand_by_the_wall`, `common_cause`.
- **Edges:** ordinary damage to an enemy merely walking toward a parent is insufficient. Uninterruptible boss attacks cannot grant the buff. A surviving valid buff and its cooldown freeze during a raid, and do not reappear after a suppressed source returns.
- **Status:** **New mechanic** using existing fusion links and committed-attack attribution.
- **Acceptance:** cancelling a real strike at a parent buffs its linked fusion once; killing that parent immediately removes the buff, and interrupting an attack aimed at the hero does nothing.
- **Icon motif:** two small stones bracing a larger central stone; new same-ID icon would be required.

## R15 — Crosswind Orders [`crosswind_orders`]

- **Rarity / act / prerequisite / target:** Uncommon / II / Overdrive and a living damaging tower / the direct target of a paid Overdrive.
- **Front:** “Your Overdrive target also gains **8% attack reach** while that order lasts.”
- **Levels I–V:** **+8 / 11 / 14 / 17 / 20%** attack range.
- **Resolution:** grant the reach bonus on a successful paid Overdrive for exactly that order's remaining duration, nominally five seconds. One recipient party-wide; a new Overdrive replaces this card's previous reach grant. No extra cooldown beyond successful paid orders. Adds to the +25% reach bucket. No splash, chain-search, support or aura expansion. Boss acquisition remains ordinary; raid entry freezes the order and bonus.
- **Synergy IDs:** `cleared_sightlines`, `the_conductor`, `relief_watch`.
- **Edges:** a failed order spends nothing and grants nothing. A generated transfer of Overdrive is not another paid cast: the reach bonus remains attached to the original tower only while that original order remains there; it does not copy or migrate. Remove it immediately if the order leaves that tower.
- **Status:** **New mechanic** joining existing Overdrive and attack range.
- **Acceptance:** at V an otherwise-range-200 target reaches 240 for the actual Overdrive duration; with Cleared Sightlines V it stops at 250, and transferring Overdrive removes the original bonus without copying it.
- **Icon motif:** a command pennant streaming into a sightline; new same-ID icon would be required.

## R16 — Hold the Gap [`hold_the_gap`]

- **Rarity / act / prerequisite / target:** Uncommon / I / a living Earth tower with native knockback / enemies near the Town Hall directly hit by a Warden.
- **Front:** “For **6 seconds** after you hit an enemy near the gate, Earth towers push it **12% farther**.”
- **Levels I–V:** **+12 / 16 / 20 / 24 / 28%** native Earth-tower knockback distance.
- **Resolution:** the direct Warden hit must occur within five tiles of the Town Hall. Mark that enemy for six seconds; a qualifying direct hit refreshes, never stacks. Maximum three marks party-wide, replace oldest. Only native displacement from an Earth tower or Earth-parented fusion gains the multiplier; it grants no new knockback. No cooldown. Existing stagger load, crowd-control resistance, path bounds and boss immunities remain authoritative; raid entry freezes marks.
- **Synergy IDs:** `stone_and_spark`, `cold_iron_stakes`, `propped_gate`.
- **Edges:** cannot push a target through walls, off its valid route, into another road or back past its spawn boundary. A bonus hit produced by another augment cannot activate this one. No permanent mark on an enemy merely remaining near the gate.
- **Status:** **New mechanic**; must use a scoped tower-knockback reader, not the current global key that also changes Warden knockback.
- **Acceptance:** a legal 100-unit native Earth shove becomes 128 before existing resistance at V; the hero's shove and a knockback-immune boss remain unchanged.
- **Icon motif:** an earthen wedge holding a narrow gateway; new same-ID icon would be required.

## R17 — Cold Snap [`cold_snap`]

- **Rarity / act / prerequisite / target:** Epic keystone / II / three other held Rampart cards and a living source of real chill / nearby enemies around a personally finished chilled target.
- **Front:** “Personally finish a chilled enemy to spread **60% of its remaining chill** to up to **4 nearby enemies**.”
- **Level:** **fixed I**. Copy **60%** of the source's natural Chill slow fraction; source minimum **20 percentage points** of movement reduction before resistance; radius **3 tiles**, maximum **4 targets**, party cooldown **3 seconds**. No damage component.
- **Resolution:** a direct Warden lethal impact samples the strongest pre-existing non-augment-generated Chill channel just before death. Copy 60% of its slow fraction to each of the nearest four other enemies, with its remaining lifetime capped at three seconds. Use a separate `cold_snap` channel: it never adds to native slow or freeze buildup; the strongest currently active slow wins after native resistance and the ordinary-enemy movement floor. A new copy replaces that channel only if stronger, or equally strong with a later expiry; weaker copies do not extend it. Copied Chill cannot be a later Cold Snap source. It creates no damage burst and does not bypass freeze refractory periods. Bosses use their normal resistance; a direct boss death can be a source if combat remains. Raid arena excluded.
- **Synergy IDs:** `cold_iron_stakes`, `crossing_fire`, `hold_the_gap`.
- **Edges:** chill spread carries generated-origin metadata and cannot trigger a card, including another Cold Snap. A tower kill, DoT kill or repeated death notification cannot activate it. Suppress below three other Rampart cards or when no usable chill source remains; cooldown persists through suppression and reconnect.
- **Status:** **Existing revised.** Current live card spreads on chilled death; this revision adds the personal finish, budget, eligibility and nonrecursive contract.
- **Acceptance:** personally killing a 50%-chilled enemy applies 30 percentage points of chill to at most four eligible neighbours; a resulting shatter or secondary death produces no second transfer.
- **Icon:** a cracked cold shard with four short rays; reuse `res://art/icons/road_cards/card_cold_snap.png`.

## R18 — Sapper's Due [`sappers_due`]

- **Rarity / act / prerequisite / target:** Rare keystone / II / three other held Rampart cards and a built, charge-based trap in a ruleset that already supports traps / one expended trap near a personal elite kill.
- **Front:** “Personally defeat an elite to restore **1 spent charge** to the nearest trap. **Twice per battle**.”
- **Level:** **fixed I**. Restore **1 charge**, radius **4 tiles** from the slain elite, party cooldown **12 seconds**, maximum **2 successful restores per battle**.
- **Resolution:** a direct Warden elite or boss kill finds the nearest alive trap missing at least one charge. Restore one through the normal rearm path, never above its authored capacity; do not fire it, reset its trigger cooldown or pay its purchase price. No eligible trap means no activation, cooldown or budget spent. Boss kills qualify only while combat continues. Raid kills never rearm the frozen board.
- **Synergy IDs:** `hold_the_gap`, `cold_iron_stakes`, `hammer_the_breach`.
- **Edges:** repeated death notifications, resurrected elites, player-spawned disposable bodies and trap-generated kills cannot grant charges. Unlimited-charge traps do not qualify. Suppress without branch depth or a built compatible trap. This is an optional integration, not permission to add traps to a ruleset that excludes them.
- **Status:** **Existing revised; optional integration.** Replaces the live mining-node trigger with a combat rescue trigger and bounded single-charge payment. No new trap system is proposed.
- **Acceptance:** one direct elite kill restores exactly one missing charge to one nearest eligible trap; the third successful kill of the battle restores none, and a tower's elite kill restores none.
- **Icon:** one trap tooth beside a reclaimed pin; reuse `res://art/icons/road_cards/card_sappers_due.png`.

## R19 — Relief Watch [`relief_watch`]

- **Rarity / act / prerequisite / target:** Epic keystone / II / three other held Rampart cards, a usable tagged basic finisher, Overdrive, and living damaging towers on two roads / one currently Overdriven tower and one tower on the striking Warden's road.
- **Front:** “Land a basic-chain finisher on another road to move an active party Overdrive there, keeping its remaining time.”
- **Level:** **fixed I**. At most **1 transfer per paid Overdrive**; recipient within **4 tiles** of the Warden; remaining duration and magnitude are unchanged.
- **Resolution:** either hero's natural tagged basic finisher may transfer one eligible active paid Overdrive from a different road to the nearest eligible attack tower on the hit's road. Choose the oldest eligible order by paid simulation timestamp, then stable order ID; the recipient cannot already have Overdrive. Finisher does not mean lethal hit. The original tower loses Overdrive before the recipient gains it. Transfer remaining attack-rate and utility enhancement, not other card buffs or attack-timer progress. No new Command spend, refund, timer reset or order-used event. If no recipient exists, retain the original order and unused transfer.
- **Synergy IDs:** `crosswind_orders`, `stone_and_spark`, `hammer_the_breach`.
- **Edges:** a party has one transfer opportunity for each uniquely identified paid order, regardless of who swings. Generated finishers do not count. The old target's Crosswind reach, Borrowed Thunder binding and Conductor charge end when its order leaves; none is copied. Bosses can be hit to transfer. Raids freeze the order and transfer eligibility. Suppress when depth or the two-road source requirement is lost.
- **Status:** **New mechanic**, strictly rerouting one existing order.
- **Acceptance:** transferring an Overdrive with 2.2 seconds left removes it from A and grants exactly 2.2 seconds to B, with no simultaneous overlap, new charge, Command refund or additional transfer.
- **Icon motif:** one pennant passed between two watch posts; new same-ID icon would be required.

## R20 — Common Cause [`common_cause`]

- **Rarity / act / prerequisite / target:** Epic keystone / III / three other held Rampart cards, Overdrive and a built fusion with at least one living linked parent / an Overdriven fusion with exactly one destroyed parent.
- **Front:** “Overdrive temporarily restores an orphaned fusion's normal utility. Its damage penalty remains.”
- **Level:** **fixed I**. One supported fusion party-wide; support lasts only the original Overdrive duration, nominally **5 seconds**. No new magnitude, charges or separate cooldown.
- **Resolution:** a paid Overdrive on a fusion with one destroyed parent temporarily satisfies the missing-parent check for that fusion's already-authored utility. Keep the orphan's base-output penalty; do not recreate, repair or simulate the missing tower. The normal Overdrive bonus still operates by its own rules. Loss of the second parent, expiry or removal of the order ends utility support immediately. A second valid activation replaces the first card support without extending either order's expiry.
- **Synergy IDs:** `parents_kept`, `banked_earth`, `crosswind_orders`, `dry_powder`.
- **Edges:** no support for a sold-parent configuration that should have refunded the fusion, no permanent unlock, and no inherited utility from arbitrary tower types. Restored utility retains existing damage/control budgets and boss restrictions; it cannot emit other augment triggers. Health stays unchanged. Raid entry freezes the existing order. Losing depth or the last live parent suppresses support immediately.
- **Status:** **New mechanic** rerouting the existing fusion-utility permission during paid Command; requires verifying each fusion has a useful, separable utility gate.
- **Acceptance:** a fusion at the existing orphan output penalty regains only its authored utility for the five-second Overdrive window; its missing parent remains destroyed, its damage penalty remains, and utility disappears on expiry or second-parent destruction.
- **Icon motif:** one surviving parent holding a broken three-stone arch together; new same-ID icon would be required.

## Migration and release checks

Retain stable identities only under the versioned lookup described in the [common migration policy](../AUGMENT_CATALOGUE_2026-09-26.md). Family consolidation applies to new-run content selection. Existing runs retain their legacy definitions, levels and exact numbers; this chapter authorizes neither active-save conversion nor compensating bonus drafts. Any future conversion needs its own tested, explicit policy.

`the_quartermaster` and staged `hagglers_knack` belong to the Hearth economy family. Staged `tower_rate` cards are not three additional Rampart offers here: their active-play replacements are Stone and Spark and Hammer the Breach. Existing no-op upgrades at numerical ceilings are specifically removed by the explicit level tables.

The art references above describe existing same-ID icons only. Newly proposed IDs have no approved runtime asset requirement yet. Implementation must add their final-path manifest entries and matching placeholders together under project rules, then satisfy the separate production-art gate before release; this design task commissions neither.

The branch's release gates are practical: each offered card has a usable source; all eligible levels visibly change a result; idle tower play cannot activate any of R05–R20; three healthy example boards can sustain distinct Water-control, Earth/Air-support and Fire/fusion builds; a solo player and a co-op party obey identical board-buff caps; all transient state survives save/load and raid freeze exactly. The current tests and pressure report do not establish any of those claims for this proposed content.
