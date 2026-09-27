# Beast Road — production augment catalogue

**Design recommendation • 26 September 2026, reviewed 27 September • content specification, not implemented content**

The recommended launch pool is **60 distinct cards: 48 ordinary augments and 12 keystones**, divided equally between **Warden, Rampart, and Hearth**. Solo has **eight cards, including at most one keystone**. Two-player co-op preserves the current split: **four ordinary Warden cards per hero, plus eight shared board slots containing Rampart, Hearth, and the party's single keystone**. Depth comes from combining readable rules and making difficult replacements. More rarity variants of the same passive bonus would make the pool larger without making the game richer.

The defining experience is: **a card makes you defend the next road differently**. Warden changes the intervention; Rampart changes the formation; Hearth changes what the settlement can afford or recover. A strong hand should make the player feel resourceful while leaving another road in need of attention.

This package specifies behavior, draft eligibility, level values, interactions, presentation, migration, engineering work, and release checks. All numerical balance values are **[TUNE]**, including caps and timing. They are testable starting values, not proof of balance. The catalogue has undergone a document review; it has not undergone gameplay validation. “Production ready” requires the gates at the end of this document.

## Read the cards

| Chapter | Contents | What it contributes |
|---|---|---|
| [Warden: W01–W20](augment_catalogue/warden.md) | 16 ordinary + 4 keystones | Movement, finishers, interrupts, deliberate ability use, defense |
| [Rampart: R01–R20](augment_catalogue/rampart.md) | 16 ordinary + 4 keystones | Four elements, doctrines, tower protection, formation and fusion |
| [Hearth: H01–H20](augment_catalogue/hearth.md) | 16 ordinary + 4 keystones | Preparation spending, supply, raids, repair and town survival |

Each entry provides a stable ID, rarity, earliest act, prerequisite, exact level-I face text, complete level ladder, target/scope, trigger, duration, cooldown, cap, interactions, exploit exclusions, implementation status, acceptance test, and icon concept. The shared rules here are part of every entry. An omitted per-card exception never means an unlimited effect.

## Evidence and design fit

The intended Babel reference is **Tower of Babel: Survivors of Chaos**; that is also the game named in this repository's skill-tree proposal. Its official description emphasizes skills, equipment combinations and rare items. Beast Road can borrow the pleasure of a recognizable build taking shape while keeping this augment layer run-local. [Official Tower of Babel page](https://store.steampowered.com/app/2665680/Tower_of_Babel_Survivors_of_Chaos/)

**MegaBonk** explicitly uses randomized upgrades of varying rarity and items with synergies. Here that inspires exciting drafts, upgrade anticipation, and the chance to combine a good ordinary card with a distinctive payoff. It does not justify exponential tower scaling that removes the Warden from the fight. [Official MegaBonk page](https://store.steampowered.com/app/3405340/Megabonk/)

**Brotato** shows the usefulness of limited simultaneous equipment and between-wave purchasing. **Halls of Torment** describes builds assembled from traits, abilities, and items. The design inference for Beast Road is to keep one constrained augment hand and a small vocabulary of interactions with the existing game. These sources inspire principles; the cards and numbers below are original proposals. [Official Brotato page](https://store.steampowered.com/app/1942280/Brotato/), [official Halls of Torment page](https://store.steampowered.com/app/2218750/Halls_of_Torment/)

MegaBonk's developer notes also document proc caps, repeated multipliers, self-damage economy problems, paused damage, offer-pool edge cases, and boss-control fixes. Those are practical reasons to specify event ownership, bounded rewards, pause behavior, and pool exhaustion before authoring dozens of cards. [MegaBonk developer updates](https://steamcommunity.com/app/3405340/allnews/?l=english)

This project has its own stronger constraint: the September 22 design diagnosis says completed defenses can make the late game play itself. New augments must increase *ways to intervene*, not only tower throughput. The governing local references are [GDD v4](Game_Design_v4.md), especially §§3, 10, 15, 20–24, 29, 34, 52–54; [the activity diagnosis](DESIGN_DIRECTION_2026-09-22.md); and [the existing augment plan and as-built record, §8](SKILL_TREE_REWORK_2026-09-26.md). The v3 changelog and v4 reconciliation were read to distinguish working legacy systems from the production target. The v2 lesson remains: expand only after the stage's kill question passes.

## What exists, and what this changes

The September 27 recheck confirms **29 live cards: 24 numerical cards and 5 keystones**. Another **32 resources are staged: 31 numerical cards and Mortar on the March**, for a prospective 61-card scalar-heavy deck. Staging is not implementation: its README identifies missing icons and an unwired Mortar trigger. Warden/co-op work completed while this task was paused; this review accounts for its new personal hands and does not modify that implementation.

| Concern | Current evidence | Recommendation in this catalogue |
|---|---|---|
| Hand | `Balance.ROAD_CARD_HAND = 8`; old comments still say five | Keep eight, keystone included |
| Progression | I–V uses a generic multiplier and magnitude-inferred eligibility | Explicit per-card ladders; every offered level must change a useful value |
| Duplicates | One effect key; rarer cards replace lower rarity versions | One stable family; rarity identifies a design, levels improve it |
| Keystone access | Some require three branch cards, others six | Three ordinary branch cards plus a functioning prerequisite for all twelve |
| Rarity | Per-card weights mean adding content changes effective rarity odds | Choose a rarity bucket first, then a card within it |
| Eligibility | Act/depth/banish/rarity; no comprehensive functional-source check | Check available action, deployed source, destination and current ruleset |
| Ordinary effects | Primarily `Modifiers` scalars; keystones reroute mechanics | Some ordinary cards gain conditional event rules; this is an explicit design extension |
| Co-op | Per-seat four-card Warden hands and eight-card party board are now built; current ownership is inferred from modifier keys | Preserve those capacities; use explicit source/owner metadata, one party keystone, and per-seat offers |
| Ownership | Some Warden-labelled effects change all enemies or hero+tower knockback | Branch is a UI category; source and target ownership are explicit |
| Tower armor | Current `tower_armour` feeds flat damage reduction | Proposed Banked Earth uses a separate percentage bucket; do not reinterpret the old scalar |
| Campaign | Current code and recent notes use ten acts; user-supplied authoritative v4 specifies three plus summit | Card gates below use v4 acts 1–3. Existing ten-act pacing needs a separate calibrated mapping before adoption |
| Assets | 29 road-card icons, 128×128, are in the manifest | Retain appropriate existing icons; new motifs remain uncommissioned concepts |

This request produces a **recommendation**, not a silent amendment to locked design. Adopting conditional ordinary cards, revised keystones, compressed eligibility, new caps or new draft pacing requires one dated change to v4, its acceptance criteria, and changelog. It must also reconcile §8.6 of the skill-tree proposal, which currently limits ordinary augments to scalar modifiers. No additional acts, permanent power, hero roster, synergy altar, currencies, endless mode, or procedural battlefield are proposed.

The three-act availability labels deliberately avoid cards that first become interesting at Act VII or IX. For a retained ten-act campaign, map availability to the first, second, and third *build-development milestones*, then tune the reward cadence against its actual wave count. Do not translate them by multiplying act numbers or enable thirty extra offers without modeling their power.

## The shared card contract

### Ownership, slots and progression

1. **Solo: eight occupied slots. Co-op: four ordinary Warden slots per seat and eight shared board slots.** Every keystone occupies a shared slot in co-op, including Warden keystones; Rampart and Hearth never enter personal slots. No hidden passive inventory, temporary extra slot, or automatic equipping from rewards.
2. **One family per hand.** For this catalogue `family_id = id`. Legacy aliases resolve to that family only for new-run content selection; active legacy saves use their original ruleset. Ordinary duplicate picks improve the held card by one level. A new family starts at I.
3. **Ordinary cards use their authored five values.** Explicitly fixed utility cards and all keystones have max level I. Integer-valued cards can still have five levels; magnitude size does not decide progression. Equal capped values do not generate a selectable upgrade.
4. **One active keystone per solo run or co-op party.** It requires three *other*, non-keystone cards in its branch and its functioning prerequisite. In co-op, a Warden keystone binds to its selecting persistent run seat, counts only that seat's ordinary Warden hand for depth, and fires only from that hero's actions; it still consumes a shared slot. A party reward may offer it with an explicitly named eligible seat; the host's confirmation binds that named seat, not automatically the host. Rampart/Hearth depth counts shared cards. Card level and rarity do not add depth. Replacement previews suppression and the bound owner. Disconnect suppresses the binding while preserving spent state; it never transfers ownership or grants another keystone. Reconnect restores that same run seat, not a transient network peer ID.
5. **Separate offer gates, arming gates, and ongoing dependencies.** A future project, raid extraction, repair or Hearthmend service can be needed to offer/arm a card, without being required after its charge has legitimately been earned. A completed project's Closing the Roof charge and a chosen Hearthmend Compact therefore survive until their explicit expiry. True ongoing dependencies—held card, branch depth, living target when needed, usable ability—suppress effects when lost. Suppression ends card-owned transient buffs; cooldowns, spent budgets and receipts remain. Re-equipping cannot reset these. The UI states the missing dependency and whether any pending charge was forfeited; individual cards define that forfeiture.
6. **Host-authoritative personal drafts and shared effects in co-op.** Ordinary Warden cards affect their owning hero only. Rampart/Hearth effects execute once for the party. Shared caps and cooldowns remain shared even if both heroes hold the same Warden family that pays a party benefit. Warden family levels are independent between seats; one seat cannot level the other's card. A shared-slot pick validates the current board revision before either seat can commit it. No effect amount is multiplied by player count.
7. **Run-local.** Cards, levels, charges, spent budgets and offers reset on New Run. MetaState may store known/unlocked IDs and codex/tutorial flags only within the approved schema. No augment effect persists as a stat.
8. **Cards supplement the chosen kit.** An augment never unlocks the only required attack, dodge, defensive action, or mandatory boss counter. A fresh Standard account must be able to clear without any named card.

### Unlocks and availability

All 60 designs are eligible for the launch content pool by default, subject to the card's act and functional gates. There is **no account grind to unlock power**. First exposure can be recorded for the codex; it does not create an extra stat or require a previous win. The tutorial reveals branches and controls gradually, without secretly reducing the returning player's pool.

An ordinary card's prerequisite must be usable **now**, not merely unlocked in the account. An equipped attack/ability is required when named; a tower must be deployed and able to provide the property. Preview-only future cards can appear in the codex, never occupy a paid reward slot. An optional integration such as a trap requires that system to be enabled in the active content profile; no trap is added simply to make its card eligible.

Legendary means an unusual rule worth mastering, not the largest universal multiplier. Common means easy to understand and assemble. Every archetype must work without its keystone, and without an Epic or Legendary roll.

### Simulation and source vocabulary

| Term | Exact meaning |
|---|---|
| Battle / encounter | One road battle, act boss, raid, or summit encounter. Wave boundaries and boss phases do not reset battle budgets. A raid has isolated state while the suspended battlefield retains its state |
| Preparation | A safe management phase under the GDD state matrix. Reopening a tab or a draft does not create a new Preparation ID |
| Lane / directional road | One of the four authored combat roads. Enemy lane is its path assignment; hero lane is the containing authored combat zone, not camera position |
| Road encounter | One whole road battle involving one or more lanes. “Per road,” “road completion,” travel and economic budgets use this encounter, not four separate allowances |
| Threatened road | Has a living authored hostile, independent of UI pressure-color oscillation |
| Natural direct hit | Positive direct damage from a committed player attack/ability or native tower attack. Periodic ticks, reflected damage, echoes, copied hits and generated card payloads are excluded as triggers |
| Finisher | An authored `basic_finisher` attack tag. It is not synonymous with killing, every heavy attack, or an Ultimate |
| Perfect dodge | The existing accepted Perfect Evade event. Once per enemy attack/dash as the combat resolver specifies; not every frame spent invulnerable |
| Paid Command | A deliberate accepted order that successfully spends the stated Command. Copies, previews, cancellations and refunds are not new orders |
| Base damage for a generated payload | Native source damage after its normal weapon/tower upgrade scaling, before augments, crits, vulnerability and target defense. Recipient applies its own defense once |
| Mark, Burn, Chill | Existing tagged combat statuses. Names alone or a visually similar slow do not qualify. Separate source channels must coexist safely |
| Hostile damage | Damage from an actual encounter enemy. Self-damage, selling, scripted testing and environmental farm loops do not create recovery rewards |

Each accepted causal event has an encounter ID, unique event ID, owner seat, source entity, target entity, original attack/cast ID and origin flag. A multi-hit attack uses one root ID with native hit indices. Each card may trigger only once per root event unless explicitly stated otherwise. Simultaneous valid targets sort by the card's target rule, then stable spawn ID. Never use hash-map iteration order.

Generated damage/status/shields cannot trigger other card payouts, healing, Command or additional generated attacks. **Natural attacks may benefit from several conditional modifiers** and may act on statuses created earlier; this allows synergy without recursive proc trees. Generated kills still award normal enemy XP and native loot exactly once. Attribute them to the initiating owner and card. Augment bonus-resource cards ignore those kills unless explicitly authorized, and none in this catalogue grants such an exception.

Durations and cooldowns use their owning encounter's simulation clock. Pausing freezes them. Raid entry freezes every battlefield timer, projectile, delayed hit, stored position, healing allowance and refund receipt. Raid-local Warden effects use a separate context. Returning restores battlefield values exactly; neither clock ages from wall time. Camera or scope navigation never resets or cancels an effect. Normal encounter completion clears temporary buffs; run budgets and unconsumed preparation commitments follow their explicit lifetimes.

### Stacking and hard bounds

The following are **augment-only ceilings**, unless a row explicitly says combined. Other existing systems still obey their own GDD and Balance caps. An implementation must measure the *combined* loadout as well; a cap on augments alone does not prove the total game is balanced.

| Quantity | Recommended ceiling / rule [TUNE] |
|---|---|
| Hero direct damage | +60% from all currently eligible augments, additive |
| Tower direct damage | +40% from all currently eligible augments, additive |
| Tower attack rate | +25% from augments; rate means attacks/second, not negative interval |
| Tower range | +25% from augments; no projectile or doctrine effect creates extra range |
| Hero movement speed | +25% from augments; dash distance is separate and unchanged |
| Hero maximum Health | +20% from augments; preserve absolute current Health on changes |
| Town maximum Health | +20% from augments; preserve absolute current Health on changes |
| Hero damage reduction | At most 40% from augments; armor resolution remains separate |
| Tower percentage damage reduction | At most 25% from augments, applied after flat armor once |
| Natural resource bonuses | Augment-created extra resources cap at 50% of the same eligible natural resource value per encounter and wallet; use a shared fractional ledger. Each event also clamps additive applicable bonuses at +50%. Completion bonuses spend remaining encounter budget, never multiply augmented output. A raid's ledger is separate from its suspended road battle |
| Cost reduction / refunds | Combined discount on the same ordinary purchase no greater than 30%, minimum payable 70% of its current ordinary cost; no reward re-discounts that purchase |
| Command cost reduction | At most 40% combined; accepted orders always pay a positive cost and preserve their normal usage limits |
| Dash / spell cost reductions | Combined reduction at most 40%, plus existing absolute floors; never zero-cost or continuous invulnerability |
| Augment shields | Across card-created shield channels and extra shield HP added to a native shield, at most 20% of that recipient's unaugmented maximum HP. Base means after normal building/hero upgrades and Wounds, before augment maximum-HP bonuses. Native unmodified shield amount is outside this augment-only ceiling |
| Slow | Rampart adds at most 13 percentage points; ordinary enemy speed stays at least 25% of its un-slowed speed; boss resistance/CC recovery still applies |
| Chain | Added targets must be distinct; never strike the same enemy twice to spend unused bounces |
| Extra targets | Only a card's explicit finite target count; no “all enemies” generic proc target |
| Repair | Never exceeds missing permanent HP, never revives a destroyed structure, never repairs the frozen battlefield during raid |

Damage example: a native 100-damage finisher with +30% Set Stance and +35% Break the Rime receives a capped +60%, yielding 160 before defense/crit. It does not become 175.5. Tower rate +25% turns a 1-second interval into `1 / 1.25 = 0.8` seconds, not 0.75. A 100-Gold ordinary cost with 20% and 15% discounts costs 70 at the combined cap; integer costs round up after the final calculation. Cards with different purchase scopes cannot transfer a discount to another wallet.

For percentage reductions, compute the stated additive augment bucket, clamp once, then multiply the normal post-armor damage by `1 - reduction`. Do not feed percentage values into the existing flat `tower_armour` key. HP and currency use the existing engine precision internally; UI rounds only for display. Every integer purchase uses the same final rounding rule.

Bosses never gain new stun vulnerability through a card. Existing resistance, break windows, and recovery are authoritative. No card disables a required boss phase, heals the town after lethal damage, grants an unavoidable-target exception, or overrides raid failure and Wounds.

**Rally compatibility gate:** the current runtime grants tower protection through timed invulnerability, while v4 specifies blocker shields and disable resistance. Cards discussing shield HP (Closing the Roof and Hearthmend Compact especially) target the v4 contract. They are unavailable until that contract exists and is tested; a percentage shield-size modifier must never be applied to seconds of invulnerability. Sealed Footings deliberately acts after Rally's native protection ends to avoid overlapping immunity. This is a known engineering dependency, not a claim that current Rally already exposes shield HP.

## Drafts that support a build

### Proposed pacing for v4's three-act campaign

This replaces neither the live ten-act schedule nor its constants until the measured curve is recalibrated. It is a target schedule for the production campaign:

| Source | Guaranteed draft budget | Timing and floor |
|---|---:|---|
| Road XP ranks | 5 / 6 / 6 across Acts I / II / III | Spread through active combat; Common floor, bank during danger |
| Crossroads | 2 per act, 6 total | One draft integrated into the existing choice/preparation flow |
| Act bosses | 3 total | Rare floor, awarded before the next combat, including pre-summit; no final-boss draft |
| Tempering | 1 per act, 3 total | At the final preparation before that act boss; choose one useful held-card level |
| Optional success | Maximum 1 additional draft per act | First qualified raid success or enabled authored objective; Uncommon floor; never repeated farming |
| Total | 29 baseline opportunities; maximum 32 | Enough to build eight slots and deepen selected cards without maxing every slot |

Seven ordinary cards at V plus a keystone take 36 accepted picks in solo; the target deliberately leaves unfinished growth. Most runs should finish with a coherent mixed-level hand. Rank thresholds must be fitted to actual kills, not grant the above count merely for elapsed time. No cards pay extra XP or create more draft events. Optional sources do not accumulate into a second reward economy. A source event deduplicates its receipt before adding to the queue.

**Co-op pacing:** retain personal rank drafts and a shared crossroad/boss/optional reward. Each of the 17 target rank events queues one offer per seat; each seat may choose its own Warden card or a shared-board card. A shared pick modifies the board once and consumes only its chooser's receipt; the other seat's offer revalidates its version before resolving. Crossroads, boss rewards and the optional-success budget are once per party. Each of the three Temperings improves one party-selected eligible card, including a named seat's ordinary card, once. This produces 46 baseline accepted-pick opportunities and at most 49, distributed across up to 16 occupied slots. This is a proposed measured schedule, not a claim of power parity with solo. The co-op director must be tested against the resulting earlier board growth; retain neither schedule merely because its scalar caps look safe.

No new modal interrupts a telegraph. Bank drafts; open in Preparation, or from the solo HUD with the whole encounter paused. Co-op defaults to Preparation with both players seeing the same state. If voluntary mid-battle co-op drafting is retained, both clients must acknowledge a shared simulation pause; a local-only pause is invalid. The final victory empties reward UI queues and goes to the ending/debrief; it never offers a card with no remaining combat.

### Offer algorithm

1. Build a sorted eligible pool using content version, act, feature availability, tutorial availability, real prerequisites, family bans, keystone depth, and whether the next level produces a nonzero effective improvement.
2. Prefer one useful held-card upgrade in slot 1 if available. If none, choose a presently functional ordinary card. Slot 2 leans toward the player's chosen/held tags. Slot 3 draws from the whole eligible pool. A slot cannot duplicate another slot's family; at most one keystone appears.
3. For each non-guaranteed-upgrade slot, choose **rarity first** with relative weights Common 60, Uncommon 26, Rare 10, Epic 3.2, Legendary 0.8. Remove empty rarity buckets before normalization. Apply source floor; if no eligible choice remains, relax floor one step with a visible “broader selection” label.
4. Clean-wave Luck is party-scoped and capped at 8. Multiply rarity bucket weight by `1 + 0.04 * luck * rarity_index`, then normalize; reset on an accepted pick. This is a proposed gentler replacement for the current 0.12 factor. It affects opportunity only, not card strength.
5. Within the chosen rarity, card weight is `1 + 0.35 * min(shared_tags, 3)` for the leaning slot; other discovery slots use equal card weight. The guaranteed-upgrade slot chooses uniformly among useful held upgrades, without a second held-card multiplier. Player tags derive only from the actual equipped kit and held cards.
6. If fewer than three distinct legal choices exist, display two or one. If none exist, consume the receipt and award at most one reroll up to its cap, with “No eligible upgrade.” Never spin a reroll loop or deliver a blank blocking modal.
7. At the Act I boss reward, if a valid keystone is available and the player holds none, guarantee one eligible keystone among the three choices. This guarantees an opportunity, not a specific build. Otherwise use the normal algorithm. Keystone strength remains bounded by its prerequisites and its one slot.

Rerolls begin at **2 per run**, bank to **6**; skip grants **1**, up to that cap. Banishes begin at **2 per run**, target an unheld family, and last the run. In co-op, personal offers use their seat's counters and personal Warden bans; shared offers use one party counter set and shared-family bans. A personal draft's shared-family ban requires the same shared-board revision validation and spends a party banish. Shared banned families disappear from both seats' future shared choices; a seat's Warden ban never alters its partner's pool. Banish removes and replaces that choice if possible; a family cannot reappear under an alias. Reroll spends only when a different valid offer can be produced. Reopening a draft or reloading a save reuses the serialized offer and RNG state. Tempering cannot offer a keystone, a capped level or a card with no delta. Branch/rarity icons and “upgrade / new / replace / suppressed” labels distinguish these actions.

Do not hide the cost of a full destination hand. Selecting a new family previews the outgoing card, both effective values, any lost synergy, branch-depth changes and the resulting four-slot personal or eight-slot shared/solo hand. The operation commits atomically. An arbitrary replacement does not inherit the old level; duplicate-family leveling is the way to grow it.

## Six complete example hands

These are **eight-slot solo examples**, not mandatory recipes or named-set bonuses. Each has exactly one keystone and at least three ordinary cards in that keystone's branch. Equipment, spells and towers still need to satisfy the individual functional gates. In co-op, distribute ordinary Warden cards to their owners and keep shared effects on the board; do not duplicate the solo hand for both players.

| Identity | Eight cards | How it plays; meaningful limitation |
|---|---|---|
| Marked relief | Hunter's Mark; Loose Boots; Set Stance; Counterweight; Red Thread; Whetstone Hour; Measured Volley; The Quartermaster | Pick a priority threat, direct the local formation, then finish it yourself. Mark healing has an encounter cap; the build has little global tower protection |
| Walking ember | Tinderstrike; Set Stance; Held Breath; Kindled Edge; Dry Powder; Crossing Fire; Picked Clean; The Quartermaster | Land finishers in a mixed-element defense, spreading a bounded existing Burn. Tower burn and hero burn stay separate; it lacks strong defensive augments |
| Cold line | Cold Snap; Banked Earth; Cold Iron Stakes; Crossing Fire; Set Stance; Break the Rime; Counted the Fires; The Quartermaster | Personal finishes spread finite Chill while Water buys another road time. Boss resistance still matters; no automated death-to-death cascade |
| Relay watch | Relief Watch; Cleared Sightlines; The Conductor; Crosswind Orders; Loose Boots; Road Runner; The Standing Order; The Quartermaster | Use the first Overdrive volley, then carry remaining time to another lane. Transferring loses the original card-specific range/chain benefits: mobility has a cost |
| Mason's road | Mortar on the March; Picked Clean; The Forager; The Quartermaster; The Good Road; Banked Earth; Loose Boots; Set Stance | Spend picks improving held cards and regain a finite amount of town HP in Preparation. Recovery cannot rescue live combat or support deliberate damage farming |
| Four-road command | Four Roads, One Home; Shared Watch; Counted the Fires; The Standing Order; Shared Tools; Sealed Footings; Loose Boots; Cut the Signal | Answer priority targets and distribute paid orders before protecting the center. Needs all four lanes and enough earned Command; cannot hide behind repeated cheap orders on one lane |

These examples cover mark, burn, control, mobility, economy and command. Fusion-focused builds instead choose Common Cause; healing-ability builds can choose Oath of Shelter; the latter consumes the same single keystone opportunity as Hunter's Mark or Tinderstrike. No two keystones are presented as a legal combo.

## What the player sees

The front shows: **name; rarity as word and shape; branch; level; short rules text; target/scope; upgrade delta; and a prerequisite warning when inspecting an unavailable codex card**. The detailed panel adds cooldown, range, cap, trigger exclusions, all five level values, affected current sources, and live contribution. Negative consequences must not be hidden behind hover.

Example: **Road Runner — Uncommon · Warden · II**. “Enter a different threatened road: deal **14%** more direct damage there for **4s**. **12s** cooldown.” The comparison explicitly says “10% → 14%; 2 roads currently eligible.” A replaced supporting Warden card must also show “Hunter's Mark would become inactive: 2 / 3 Warden cards.”

All card rules, glossary terms, suppression reasons and accessibility descriptions live in resources/localization keys. Use parameterized copy such as `augment.road_runner.rules`, with formatted values resolved from the same table used by gameplay. Flavor is optional and subordinate to rules; ship no lore paragraph that forces the important cooldown below the fold. The card chapters provide release-intent English rules, not final localization layouts.

Use the established road-card visual treatment rather than adding another screen. Existing manifest §5.13e defines **128×128 icons** as a single recognizable object. Keep an icon visually distinct at its small HUD size. Rarity color is redundant with a word and border shape. Controller focus order is deterministic; Inspect, Compare, Reroll, Banish, Skip and replacement confirmation all work without hover. Screen shake, flash and card fan animation obey existing accessibility settings. Never cover a boss tell with card VFX.

The per-card motifs are **design concepts, not newly commissioned asset requirements**. This documentation change adds no live asset path or manifest entry. When a card is actually added to runtime, create its manifest row and correctly sized magenta-marked placeholder in the same change, at the ID-derived final path, per AGENTS.md. Production art then overwrites that file, and the release gate rejects remaining placeholders. Reused icons must still accurately communicate a reworked card's behavior. Additional bespoke ghost-strike or status VFX need their own accepted asset budget before implementation; no permanent procedural drawing workaround.

## Engineering handoff

### Data and balance

The existing `RoadCardData` is the migration starting point, not an adequate representation of every new rule. Extend data deliberately; do not implement a giant `match card.id` in hero, tower, or enemy code. Reusable trigger/filter/payload handlers own mechanics; content files select them.

| Data field | Required meaning |
|---|---|
| `id`, `family_id`, `content_version` | Stable identity, duplicate policy, ruleset compatibility |
| `name_key`, `rules_key`, `detail_key` | Localized copy, formatted from live values |
| `branch`, `rarity`, `tags`, `keystone` | Discovery, UI and branch eligibility |
| `first_act`, `required_feature_ids`, `prerequisite_rules` | Present-tense source/target/loadout eligibility |
| `max_level`, `level_value_keys` | Explicit ordered references to Balance values; no magnitude heuristic |
| `trigger_id`, `source_filter`, `target_selector`, `payload_id` | Data-selected mechanic; one main rule per card |
| `allowed_scopes`, `owner_policy` | Battlefield/raid/preparation and per-hero/party execution |
| `cooldown_key`, `duration_key`, `radius_key`, `target_cap_key` | References to named Balance constants |
| `budget_keys`, `reset_policy`, `stack_group`, `proc_policy` | Quantitative bounds and lifecycle |
| `legacy_aliases`, `acceptance_case_id` | Migration provenance and the card's QA receipt |

**Balance.gd remains the owner of every tuning value.** Resources reference stable tuning keys; they do not create a second balance table. A table such as `AUGMENT_ROAD_RUNNER_DAMAGE = [0.10, 0.14, 0.18, 0.22, 0.26]` and named duration/cooldown constants feed both UI and resolver. The named schema above is a proposed API contract, not an existing engine API or a runnable resource example.

Suggested reusable handlers: direct-hit conditional modifier; paid-order temporary modifier; tagged-status application; bounded shield; capped repair; receipt-checked economic credit; next-action charge; target priority override; and one nonrecursive copied payload. If a proposed card needs a tenth bespoke subsystem, redesign it before adding code.

### RunState, events and persistence

RunState owns the hand, levels, content ruleset, offer RNG state, current offers, queue receipts, source event receipts, active effects, party/per-hero cooldowns and all spent budgets. Entity scripts only query or apply the authoritative result; they do not cache a second copy of run power. Battlefield timers stay under the battlefield's suspended context. MetaState stores no current hand or effect.

Existing EventBus signals include `road_card_taken`, `augment_hand_changed`, `augment_queued`, `augment_taken`, `augment_offer_changed`, `augment_seat_told`, `coop_augment_seat`, `augment_choice_asked`, and co-op augment hand messages. This documentation change adds **no signal**. Implementation should first reuse existing authoritative combat events. If required, propose these typed contracts, with a typed resource payload and one-line signal comment in EventBus:

- `augment_effect_resolved(result: AugmentEffectResult)` — an authoritative effect receipt for presentation and ledger, never a fresh proc trigger.
- `augment_eligibility_changed(card_id: String, active: bool, reason_key: String)` — UI feedback after hand/loadout changes.

`AugmentEffectResult` would contain the unique event/context IDs, source and target IDs, owner, applied amount, remaining budget and origin flag. This is proposed work; no class by that name is claimed to exist. Cross-scope messages carry IDs and quantities, never a battlefield reference to a city node.

Host requests contain offer ID, card ID, replacement ID, and hand revision, never client-supplied magnitude. The host validates all of them and publishes one atomic revision. Reject stale/repeated receipts. A reconnect receives the complete hand plus budgets, cooldowns, active targets, counters, current offer and ruleset hash. A different balance/content hash prevents a co-op session from starting rather than silently desynchronizing.

### Legacy content and saves

Do not overwrite the meaning of an existing ID inside an active run. Introduce a content-ruleset version: already-started runs keep their old resource definitions and exact numbers; new runs select the new catalogue only after adoption. Keep the legacy definitions/load path until supported saves are completed or explicitly migrated. Do not point a recursive global loader at two conflicting resources with the same ID. Route lookup by ruleset before lookup by ID.

The following old rarity ladders become one new-run family. This table is a **design mapping**, not an automatic active-save stat conversion:

| Live IDs | New-run disposition |
|---|---|
| `banked_earth`, `riveted_plate` | One Banked Earth family, percentage-DR semantics explicitly versioned |
| `cleared_sightlines`, `the_watchtower_eye` | One Cleared Sightlines family |
| `propped_gate`, `the_deep_cellar` | One Propped Gate family |
| `whetstone_hour`, `the_master_founder` | One Whetstone Hour family |
| `picked_clean`, `the_open_hand` | Retained as separate *conditional* rules in Hearth, not a shared loot multiplier ladder |
| `loose_boots`, `short_rations`, `second_wind` | Retained, with bounded explicit ladders |
| `set_stance`, `the_long_lever`, `the_quiet_approach` | Reworked with specific source and trigger restrictions |
| `dry_powder`, `cold_iron_stakes`, `the_conductor` | Retained as explicitly scoped elemental rules |
| `the_forager`, `the_good_road`, `counted_the_fires`, `the_standing_order` | Retained with Hearth limits and functional gates |
| `the_quartermaster` | Retained, displayed under Hearth, with purchase scope |
| `cold_snap`, `tinderstrike`, `timberwright`, `sappers_due`, `hunters_mark` | All five reviewed/reworked as keystones; no live-save semantic swap |

All 29 live IDs are accounted for. The **32 staged IDs** are reconciled as follows; their files remain untouched:

| Staged IDs | Recommendation |
|---|---|
| `honed_edge`, `the_oathblade` | Do not add another universal hero-damage ladder; use Set Stance/Breach Hunter's active roles |
| `deep_breath`, `wellspring_draught`, `ink_of_the_road`, `the_loud_word`, `grand_incantation` | Defer broad Mana/spell-stat ladders; Held Breath supplies an active casting rhythm |
| `pack_bond`, `the_alphas_due` | Defer this augment family; the launch catalogue must not depend on adding or redesigning companions |
| `iron_lungs`, `legends_heart`, `hard_road_boots` | Fold the design purpose into Short Rations / Loose Boots levels |
| `oiled_gears`, `double_crews`, `the_drill_sergeant` | Replace passive haste ladder with active Rampart haste windows |
| `sharpened_stakes`, `caltrop_masters`, `the_killing_ground` | Do not add trap-stat ladder; retain one eligible Sapper's Due keystone when traps are enabled |
| `pitch_and_tar`, `frostbitten_iron` | Fold into Dry Powder / Cold Iron Stakes bounded roles |
| `masterwork_arsenal`, `rampart_of_legend`, `the_storm_coil`, `the_great_gate` | Fold design purposes into Whetstone Hour / Banked Earth / The Conductor / Propped Gate |
| `tithe_collector`, `full_granary`, `the_caravan_road`, `hagglers_knack` | Fold into Hearth's conditional reward, supply and spending rules |
| `quick_muster`, `long_sight`, `the_beasts_stride` | Fold into Standing Order / Counted the Fires / Good Road |
| `mortar_on_the_march` | Keep concept, rewrite as a budgeted duplicate-level reward; it is still unimplemented |

No one-to-one replacement is promised where semantics differ. Before any actual migration, save a backup, validate the old ruleset, and use fixtures from every supported release. Unknown cards must not silently disappear, refund into permanent power, or reset the player's run. If migration cannot preserve meaning, retain the legacy play path and explain the limitation.

## Validation and release gates

### First implementation slice

Start with **twelve representative cards**, not all sixty: Loose Boots, Set Stance, Counterweight, Hunter's Mark; Banked Earth, Dry Powder, The Conductor, Cold Snap; Picked Clean, The Quartermaster, Counted the Fires, Mortar on the March. This samples scalar, conditional, status, targeting, integer level, economy, utility and capped repair behavior. It is an engineering validation slice, not a reduced launch recommendation. A useful draft needs at least three eligible families in each tested state, so fixtures may supply prerequisite equipment without granting extra shipped cards.

Only expand to the complete 60 when this slice passes the activity and lifecycle gates. The optional trap integration can be disabled without offering a dead Sapper's Due card; it must be enabled and verified before claiming all 60 are playable.

### Required automated cases

| Gate | Required evidence |
|---|---|
| Content | Exactly 60 unique IDs, 20/branch, 16 ordinary + 4 keystones per branch; no unresolved tuning/localization/asset reference; every level useful or explicitly fixed |
| Offers | Seeded reproducibility; adequate sparse pool; empty pool; all bans; all caps; broken prerequisite; last-card banish; reroll no-op; full-hand replacement; floor fallback; guarantee opportunity |
| Caps | Minimum/maximum stats and rounding; simultaneous bonuses; identical target hit twice; cap-aware zero-value upgrade suppression |
| Triggers | Each card's acceptance test; natural versus generated sources; one event delivered twice; multihit attacks; two simultaneous heroes; priority target tie |
| Lifecycle | Pause, each scope transition, exact raid freeze/resume, load during each timed window, down/revive, boss phase, preparation re-entry, replacement/reactivation |
| Economy | Actual spend tracked per wallet; no refund over spend; duplicate receipt; full/empty HP; sell/rebuy; no self-damage rewards; no final-boss payout |
| Co-op | Both seats benefiting correctly; shared cap once; host hand revision rejection; latency/reconnect mid-offer and mid-proc; content hash mismatch |
| Save | Legacy rulesets unchanged, new-run reset, corrupted/unknown ID handled without destroying original, no run power in MetaState |
| Runtime | Verified exact Godot executable; cold headless project load with zero errors/warnings after every implementation stage; relevant existing card/augment/curve gates |
| Performance | Worst supported enemy/effect count on declared minimum hardware; stable 60 FPS with cards active; no unbounded event, target-query or VFX allocation |

The document's exact timers, counters and IDs support these tests. It does not assert the runtime already supplies all necessary events. All implementation changes still follow typed GDScript, small node responsibilities, resource data, Balance constants, EventBus boundaries and RunState ownership.

### Human playtest questions and measurements

The kill question is **“Does this hand make deciding where to go and what to do more interesting after the defense stabilizes?”** A hand that wins by standing at town fails, even when the damage numbers are exciting.

Use at least 12 moderated players split across new, familiar and expert experience, with solo and two-player sessions. This is an initial diagnostic cohort, not statistical proof. Compare seeded no-augment baselines with coherent Warden, Rampart, Hearth and mixed hands at equal progression budgets. Include weak offers, low Health, wounded states, and a full hand that must give something up. Reuse v4 targets: meaningful actions, no idle interval above 8 seconds, boss readability and full-run closure. Additional proposed targets:

- At least 90% of players correctly explain a sampled card's trigger and main limitation after reading it; at least 80% explain why they replaced a card.
- At least three viable non-keystone routes per branch; no specific augment or unlock required for a Standard clear.
- Review any card above 35% of eligible winning loadouts, but condition on act acquired, difficulty, player skill, source pool and prior build. A universally offered tutorial card needs separate interpretation.
- Record pick/skip/replacement rate by *eligible offer*, useful proc frequency, idle periods, lane changes, priority-role kills, Command spent, damage/prevention, healing and wasted healing, resource delta, suppressed time and capped-out upgrades.
- Require whole-build checks: tower DPS, time-to-breach, effective defense coverage, post-cap economy and ultimate uptime. Do not approve three separately fair multipliers without measuring their product.
- Refuse release with an infinite loop, a freeze mismatch, an unrecoverable draft, an uncaught duplicate co-op reward, misleading card text or a missing final asset.

The pause/debrief ledger should report actual card applications and wasted/capped amounts. When several additive damage bonuses share a capped bucket, allocate the final bonus proportionally to their eligible contributions and label it “allocated bonus damage”; do not sum separate hypothetical removals and claim more damage than was dealt. Economic credit reports only additional actual resources, not the whole original drop. Protection reports actual prevented damage, not the theoretical shield size.

### Definition of done

A card is complete when its resource and Balance entries, localized face/detail copy, source/target filtering, save/co-op lifecycle, icon/presentation, acceptance test, performance bounds and playtest evidence all exist. A catalogue is complete when eligible cards can be discovered, understood, combined, replaced and carried through the full ending without making active defense optional.

**Recommended next step:** implement and measure the twelve-card validation slice under a reconciled content ruleset. That implementation has not been started by this documentation task.

## Review receipt — 27 September 2026

- Verified **60 unique card IDs**, **20 per branch**, with **48 ordinary cards and 12 keystones**. Of the ordinary cards, 46 have five authored levels; The Conductor and Counted the Fires are explicitly fixed at I.
- Checked every entry for rarity, face text, level specification, implementation status, acceptance test, icon concept and named synergies. Checked all local document links and referenced synergy IDs; no missing references found.
- Independent reviews corrected the Town Hall maximum-HP cap, lost-charge suppression, co-op seat ownership, generated-effect attribution, Chill transfer lifetime, order-transfer side effects, economic ceilings, and active-save migration policy.
- The exact installed Godot 4.7.1 executable completed the required headless project-open check with **exit code 0 and no errors or warnings** using normal Windows access. Sandboxed preliminary attempts encountered log-directory/certificate access failures; the successful normal-access run supersedes those environment-limited checks.
- Only the specification and three catalogue chapters were changed. No gameplay scripts, resources, GDD, staged content, EventBus signals, production assets, or save formats were changed by this task.
- These checks establish document completeness and the existing project's startup, **not** that the proposed mechanics are implemented, balanced, or release-validated. The runtime and human gates above remain the definition of completion for implementation.


Autoattacking Augments proposed by ChatGPT for inspiration for implementation, adaptation, or rejection along with all other ideas as you see best for our best most perfect use case ever!

Yeah, I can sketch out a big starter list. Just thinking it through.
Absolutely. For Wilderhold, I’d go much bigger than just “orbiting blades” and “automatic fireballs.” The best version is a whole Auto-Arsenal system where different autonomous weapons create completely different builds.
1. Orbiting weapons
- Spectral Blades — swords circle the player and cut enemies they touch.
- Frost Shards — orbiting crystals damage and Chill enemies.
- Ember Wisps — fiery orbs orbit you and periodically shoot firebolts.
- Sawstones — slow, heavy stone discs deal huge contact damage.
- Lightning Orbs — electrical spheres zap enemies as they rotate.
- Thorn Crown — spinning vines damage and Bleed nearby enemies.
- Bone Scythes — skeletal blades sweep around the player.
- Moon Shards — crescent projectiles orbit at different distances.
- Guardian Shields — orbitals block projectiles, then retaliate.
- Runic Satellites — floating runes independently cast small spells.
2. Automatic projectile weapons
- Seeking Flames — continually launches homing fireballs.
- Arcane Missiles — several weak projectiles automatically seek targets.
- Spirit Arrows — fires automatically toward nearby enemies.
- Ice Needles — rapid automatic frost shots that stack Chill.
- Bone Spears — spears periodically fire toward distant targets.
- Chain Bolts — lightning automatically jumps through clustered enemies.
- Stone Shot — heavy rocks launch toward the strongest nearby enemy.
- Poison Needles — low direct damage but stack poison rapidly.
- Shrapnel Burst — periodically fires projectiles in every direction.
- Hunter Bolts — automatically targets elites first.
3. Summoned attackers
- Spirit Raven — circles outward, strikes enemies, and returns.
- Phantom Archer — follows you and continuously fires.
- Ghost Knight — automatically charges nearby enemies.
- Fire Sprite — small elemental familiar launches flames.
- Storm Sprite — zaps targets independently.
- Ice Familiar — fires slowing projectiles.
- Stone Golem — slowly follows and slams enemies.
- Spectral Wolf — rapidly hunts weakened targets.
- Wisp Swarm — numerous tiny spirits attack independently.
- Dragonling — periodically breathes fire across enemy groups.
- Living Vine — lashes nearby enemies automatically.
- Ancient Guardian — powerful temporary summon triggered every few waves.
These could tie beautifully into Wilderhold's existing companion system without replacing the player's actual companion.
4. Automatic area attacks
- Flame Nova — periodic burst of fire around you.
- Frost Nova — damages and freezes nearby enemies.
- Thunderclap — lightning pulse every few seconds.
- Earthquake Pulse — radial physical shockwave.
- Blood Ring — expanding damage circle.
- Arcane Detonation — delayed explosion centered on the player.
- Holy Burst — periodic high-damage pulse against nearby enemies.
- Poison Bloom — releases a spreading toxic cloud.
- Wind Blast — damages and pushes enemies outward.
- Gravity Pulse — pulls enemies inward before exploding.
A build with several of these becomes a walking pulse engine.
5. Ground-targeted automatic attacks
These feel especially good because attacks happen around you rather than always directly from you.
- Meteor Rain — meteors periodically target enemy concentrations.
- Lightning Strike — automatically calls lightning onto nearby enemies.
- Bone Eruption — spikes emerge under random targets.
- Magma Vent — creates temporary lava eruptions.
- Ice Pillar — spikes burst upward beneath enemies.
- Root Snare — roots automatically grab enemies.
- Stone Fissure — cracks travel through enemy groups.
- Shadow Rift — damaging portals periodically open under targets.
- Thunder Field — electrical zones appear near enemy clusters.
- Falling Stars — small celestial projectiles constantly bombard the battlefield.
6. Movement-powered weapons
I especially like these for Wilderhold because they make movement itself part of the build.
- Thornwake — leaves damaging vines behind you.
- Flame Trail — moving creates burning ground.
- Frost Trail — leaves ice that damages and slows.
- Thunderstep — every X distance traveled releases lightning.
- Afterimage — moving generates ghosts that attack nearby enemies.
- Blade Dash — periodically launches blades in your movement direction.
- Dust Devil — movement builds a tornado behind you.
- Stampede — sustained movement summons spectral beasts running alongside you.
- Runic Footsteps — automatically drops explosive runes.
- Momentum Burst — reaching high movement speed fires projectiles around you.
This keeps the Vampire-Survivors-style automation while still rewarding active play.
7. Persistent zones around the player
Instead of individual attacks, these create a permanent damage radius.
- Burning Aura — constant Fire damage nearby.
- Winter Aura — continuously Chills nearby enemies.
- Static Field — lightning periodically arcs between nearby enemies.
- Poison Mist — toxic cloud surrounds you.
- Blade Field — enemies near you repeatedly take physical damage.
- Gravity Well — slowly pulls enemies toward you.
- Repulsion Field — repeatedly pushes nearby enemies away.
- Death Aura — damages enemies more strongly the closer they are.
- Life Drain Field — nearby enemies lose health and heal you.
- Storm Eye — constant wind and lightning surround the player.
8. Automatic beams
These make builds visually distinct from projectile builds.
- Guardian Beam — floating relic continuously attacks the nearest enemy.
- Sunray — rotating beam sweeps around the player.
- Lightning Beam — locks onto one enemy and chains outward.
- Frost Ray — automatically tracks enemies and increases Chill over time.
- Soul Beam — targets the lowest-health enemy.
- Prismatic Beam — periodically changes elemental damage.
- Twin Rays — beams fire from opposite sides of the player.
- Orbital Laser — beam fires down from above onto enemy concentrations.
9. Automatic retaliation
The enemies themselves trigger your weapons.
- Thorns — attackers take return damage.
- Flame Retort — taking damage releases fire.
- Static Revenge — being hit triggers chain lightning.
- Ice Armor — attackers can become Frozen.
- Bloodburst — losing health releases a damage pulse.
- Spiteful Spirits — damage taken summons temporary ghosts.
- Last Word — killing an enemy that recently damaged you causes an explosion.
- Shield Shatter — losing Aegis creates a massive shockwave.
10. Kill-triggered automation
These produce satisfying chain reactions.
- Corpse Explosion — dead enemies explode.
- Soul Seeker — kills release spirits that hunt new enemies.
- Fire Spread — burning enemies ignite nearby targets when they die.
- Frozen Shatter — Frozen enemies explode into damaging shards.
- Lightning Death — killed enemies launch lightning arcs.
- Bone Harvest — kills produce flying bone projectiles.
- Blood Chain — kills create a damaging slash toward another enemy.
- Pestilent Death — poisoned enemies leave toxic clouds.
- Meteor Mark — elite kills call down meteors.
- Chain Reaction — explosions can trigger additional explosions.
This category is fantastic for getting that late-game “the screen is deleting itself” feeling.
11. Timed super-weapons
These should be slower but spectacular.
- Dragon Pass — spectral dragon flies across the battlefield.
- Meteor Storm — barrage every 30–60 seconds.
- Divine Sword — enormous blade periodically falls from the sky.
- Worldbreaker — giant earthquake erupts outward.
- Frozen World — periodically freezes most nearby enemies.
- Stormfront — moving thunderstorm sweeps across the map.
- Wild Hunt — ghostly riders charge through enemies.
- Solar Flare — massive radial burn.
- Black Hole — periodically pulls enemies together and detonates.
- Ancient Beast — huge spectral beast appears briefly and attacks everything.
12. Enemy-targeting logic augments
These aren't weapons themselves—they modify what your automatic weapons prioritize.
- Executioner — auto-attacks prefer low-health enemies.
- Giant Slayer — prioritize elites and bosses.
- Swarmbreaker — prioritize dense enemy clusters.
- Predator — prioritize isolated enemies.
- Elemental Hunter — attacks automatically seek enemies weak to their element.
- Marked Prey — one target becomes marked and all autonomous weapons focus it.
- Threat Response — attacks prioritize enemies closest to the settlement.
- Guardian Instinct — prioritize enemies attacking towers.
These can radically change how the exact same arsenal behaves.
13. Tower-linked autonomous powers
This is where Wilderhold can separate itself from most survivor games.
- Tower Echo — your automatic weapon periodically copies a nearby tower attack.
- Shared Ammunition — projectile augments inherit tower projectile traits.
- Mobile Turret — miniature spectral copy of your strongest tower follows you.
- Tower Spirits — towers occasionally release spirits that attack nearby enemies.
- Crossfire Relay — your auto-attacks bounce between nearby towers.
- Overcharge Pulse — passing near a tower automatically boosts it temporarily.
- Elemental Network — auto-attacks gain the element of your closest tower.
- Fortress Barrage — every X kills causes all towers to fire an additional volley.
14. Disaster-linked autonomous weapons
Another excellent Wilderhold-specific category.
- Stormcaller — lightning storms increase your automatic lightning frequency.
- Flood Current — projectiles chain farther through flooded areas.
- Wildfire Spirits — active wildfires produce additional flame wisps.
- Quakeborn — earthquakes release extra shockwaves around you.
- Tornado Child — nearby tornadoes periodically spawn smaller allied vortices.
- Meteor Kin — natural meteor events enhance your own meteor attacks.
- Blizzard Heart — cold weather strengthens Frost auto-attacks.
- Wrathstorm — higher Earth's Wrath increases autonomous attack frequency.
15. Weapon-copying and echo effects
These can create extremely broken-feeling late-run builds—in a good way.
- Echo Cast — every automatic attack has a chance to repeat.
- Twin Cast — fires two weaker copies.
- Delayed Echo — attack repeats one second later.
- Mirror Shot — projectile fires backward as well.
- Phantom Copy — spectral duplicate casts the same effect elsewhere.
- Chain Echo — killing with an auto-attack can immediately trigger it again.
- Multicast — rare chance to trigger an effect several times.
- Resonance — repeatedly using one auto-weapon gradually accelerates it.
16. Growing weapons
These start modestly and become monsters during the run.
- Hungry Blade — gains size for every X kills.
- Growing Storm — chain count increases over time.
- Blood Familiar — summon grows stronger from elite kills.
- Living Flame — fire projectile count increases as more enemies burn.
- Evolving Orbit — orbital count and radius expand with levels.
- Ancient Seed — begins as a small vine and becomes a giant autonomous plant.
- Soul Collector — gathers enemy souls that increase attack frequency.
- World Scar — earthquake attack permanently expands after boss kills.
17. Defensive auto-weapons
Not everything has to be pure DPS.
- Interceptor Orb — shoots enemy projectiles.
- Guardian Spirit — automatically blocks occasional attacks.
- Repulsion Wave — pushes enemies away periodically.
- Frost Barrier — freezes enemies that get too close.
- Emergency Nova — triggers automatically at low health.
- Healing Wisp — periodically restores health.
- Shield Generator — automatically replenishes Aegis.
- Sanctuary Pulse — periodically heals nearby companions or structures.
18. Resource-powered autonomous attacks
These introduce interesting greed-versus-power decisions.
- Coin Cannon — automatically spends small amounts of currency to fire powerful shots.
- Ore Shrapnel — consumes mined materials for bonus projectiles.
- Mana Furnace — excess energy becomes attacks.
- Blood Engine — trades health for increased auto-attack frequency.
- Wrath Engine — stronger attacks continuously increase Earth's Wrath.
- Harvest Engine — gathering resources charges a devastating automatic attack.
- Interest Barrage — unspent resources increase projectile count.
- Salvage Swarm — destroying towers temporarily creates autonomous drones.
19. Hybrid evolution weapons
This is where I think the system becomes addictive.
Spectral Blades + Fire → Infernal Blades
Burning swords orbit you and fling fire outward.
Frost Shards + Storm Halo → Hailstorm Crown
Orbiting ice periodically launches lightning-charged shards.
Spirit Ravens + Chain Lightning → Storm Ravens
Ravens become flying lightning conductors.
Meteor Rain + Poison → Plague Comets
Meteors leave toxic craters.
Flame Trail + Tornado → Firestorm Wake
Movement creates small flaming tornadoes.
Guardian Beam + Frost → Absolute Ray
Beam gradually freezes anything it remains locked onto.
Thornwake + Life Drain → Bloodroot
Vines drain enemy health and return it to you.
Bone Spears + Corpse Explosion → Grave Cascade
Kills launch bone spears that create further corpse explosions.
Stone Orbitals + Earthquake → Worldbreaker Crown
Orbiting rocks periodically slam into the earth and create shockwaves.
Dragonling + Meteor Storm → Dragonfall
A spectral dragon flies overhead while meteors bombard its path.
And then I’d reserve a handful of truly absurd Mythic evolutions for completed builds:
TEMPEST CROWN — permanent storm orbiting the player.
THE WILD HUNT — an entire spectral hunting pack fights beside you.
WORLD ENGINE — earthquakes, rocks, and meteors constantly react to your movement.
WINTER'S HEART — blizzards and autonomous frost weapons follow you everywhere.
INFERNO WALKER — your movement turns the battlefield into controlled fire.
LIVING FORTRESS — miniature manifestations of your towers orbit and attack alongside you.
BEAST OF THE EARTH — the land itself begins attacking enemies around you.
For launch, I wouldn't implement all of these immediately. I’d select around 30–40 core autonomous weapons, give each roughly 5 upgrade levels, and create perhaps 12–20 secret Evolutions from combinations.
That would already give Wilderhold hundreds of possible run configurations.
And critically, I would let a player simultaneously have something like 6–8 Auto-Arsenal slots. That creates the classic survivor progression:
one pathetic fireball → several independent weapons → ridiculous synergistic machine of destruction.
That power curve would fit Wilderhold exceptionally well.
Yeah. Okay, so here's a big menu of auto-attack style augments for Wilderhold: Orbitals, like spectral blades, frost shards, ember wisps, saw stones. Auto projectiles, seeking flames, arcane missiles, chain lightning bolts, spirit arrows. Summons, spirit ravens, phantom archers, ghost knights, little golems, tiny dragonlings. Area pulses, fire novas, frost pulses, thunder claps, earthquake ripples. Ground targeting stuff like meteors, bone spikes, lightning smites, Movement trails like flame or poison trails, thunder steps, afterimage slashes. Persistent auras as well, static fields, burning auras, winter auras. Beams could also be cool. Guardian beam, rotating sun ray, Retaliation effects like thorns, lightning when hit, ice armor bursts could also be good. Kill triggers too. Corpse explosions, soul seekers, timed super weapons could be fun as well. Spectral dragon flyovers, wild hunt riders, And then crossovers that evolve from combos like burning orbitals that shoot projectiles or ravens that chain lightning. And then later maybe you unveil some mythic evolutions, Tempest Crown, the Wild Hunt, Inferno Walker. Each one feels like a build you discovered. I'd give players multiple slots so they slowly snowball from one tiny wisp to that glorious screen-filling chaos. That's the feeling players chase in those games.