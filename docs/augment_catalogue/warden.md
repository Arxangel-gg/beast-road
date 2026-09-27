# Warden — 20 proposed augment cards

Read [the catalogue contract](../AUGMENT_CATALOGUE_2026-09-26.md) with this chapter. All numbers are **[TUNE]**. These are specifications, not claims of implemented or playtested behavior. This branch rewards crossing roads, reading attacks, and finishing important targets. It does not replace the Warden's permanent skill choices.

**Shared interpretation:** `B/R` means battlefield, act bosses, summit, and raid; battlefield-only means no raid effects. In co-op, ordinary Warden cards use their owner's four-slot personal hand and affect only that hero. A Warden keystone occupies the single shared keystone slot, binds to its selecting persistent run seat, and counts that seat's ordinary Warden cards for depth; only the bound hero triggers it. Timers are per hero unless explicitly party-limited; a Warden card paying a shared benefit still obeys a party cooldown across both seats. A natural direct attack can receive several additive modifiers, but generated damage never triggers another augment. One accepted attack/cast ID may trigger each card once. The common contract defines damage, healing, lane transitions, and duration clocks.

| Ref | Card / stable ID | Rarity | First act | Build decision |
|---|---|---|---:|---|
| W01 | Loose Boots / `loose_boots` | Common | 1 | Arrive at the road that needs you |
| W02 | Short Rations / `short_rations` | Common | 1 | Trade a slot for a reliable health reserve |
| W03 | Set Stance / `set_stance` | Common | 1 | Finish the basic chain under pressure |
| W04 | Second Wind / `second_wind` | Uncommon | 1 | Spend dash more confidently |
| W05 | The Long Lever / `the_long_lever` | Uncommon | 1 | Reposition normal enemies with committed blows |
| W06 | The Quiet Approach / `the_quiet_approach` | Rare | 2 | Turn a clean dodge into one safer exchange |
| W07 | Road Runner / `road_runner` | Uncommon | 1 | Change roads and fight on arrival |
| W08 | Counterweight / `counterweight` | Uncommon | 1 | Take the opening after a perfect dodge |
| W09 | Cut the Signal / `cut_the_signal` | Rare | 1 | Interrupt the support instead of farming bodies |
| W10 | Red Thread / `red_thread` | Rare | 2 | Sustain through marked-target combat |
| W11 | Held Breath / `held_breath` | Uncommon | 1 | Alternate a complete basic chain with a spell |
| W12 | Kindled Edge / `kindled_edge` | Uncommon | 1 | Prepare fire for towers without becoming a fire turret |
| W13 | Break the Rime / `break_the_rime` | Rare | 1 | Follow Water control with a finisher |
| W14 | Breach Hunter / `breach_hunter` | Uncommon | 1 | Hunt board-threatening roles |
| W15 | Bell Bearer / `bell_bearer` | Rare | 2 | Reach an endangered defense safely |
| W16 | Borrowed Thunder / `borrowed_thunder` | Epic | 2 | Fight alongside a deliberately Overdriven tower |
| W17 | Hunter's Mark / `hunters_mark` | Rare keystone | 1 | Point the formation at your chosen enemy |
| W18 | Tinderstrike / `tinderstrike` | Epic keystone | 2 | Spread existing fire through a committed finisher |
| W19 | Returning Oath / `returning_oath` | Legendary keystone | 2 | Use dash origin as a second attack position |
| W20 | Oath of Shelter / `oath_of_shelter` | Epic keystone | 2 | Convert a deliberate heal into temporary tower protection |

## W01 — Loose Boots [`loose_boots`]

- **Rarity / gate / target:** Common; Act 1; no prerequisite; owning hero, B/R.
- **Card face:** “Move 4% faster.”
- **Levels I–V:** movement speed **4 / 6 / 8 / 10 / 12%**.
- **Rules:** Add to the augment movement bucket. Always active while held; no cooldown. Does not change dash distance, dash invulnerability, attack timing, knockback, or Yuri's speed. The common movement cap applies.
- **Synergy:** `road_runner`, `bell_bearer`. Its slot competes with a stronger combat condition.
- **Edge cases:** Movement slowdown remains effective; multiplicative terrain penalties apply after the capped positive movement bonus. Removing the card cannot alter position or a dash already in flight.
- **Status:** Existing revised scalar; current 8% opening value becomes this gentler ladder.
- **Acceptance:** At base speed 200 and no other modifiers, levels I/V yield 208/224; a raid transition preserves the correct value without double application.
- **Icon:** Worn boots; retain the existing `loose_boots` icon.

## W02 — Short Rations [`short_rations`]

- **Rarity / gate / target:** Common; Act 1; no prerequisite; owning hero, B/R.
- **Card face:** “Gain 8% maximum Health. This does not heal you.”
- **Levels I–V:** maximum Health **8 / 11 / 14 / 17 / 20%**.
- **Rules:** Always active; additive maximum-Health bucket. Wounds apply after this bonus. Changes preserve absolute current Health, clamped to the new maximum; no on-heal event. No cooldown.
- **Synergy:** `bell_bearer`, `red_thread`; effects using maximum Health respect their own encounter caps.
- **Edge cases:** Taking, upgrading, replacing, reconnecting, and loading never heal. A living hero remains at least 1 HP when a maximum decreases; a downed hero remains downed. No wound removal.
- **Status:** Existing revised scalar and explicit maximum-Health lifecycle.
- **Acceptance:** Taking at 40/100 gives 40/108; removing at 108/108 gives 100/100, never a down or a healing proc.
- **Icon:** Wrapped travel ration; retain `short_rations`.

## W03 — Set Stance [`set_stance`]

- **Rarity / gate / target:** Common; Act 1; complete basic-chain finisher available; owning hero, B/R.
- **Card face:** “Your basic-chain finisher deals 10% more direct damage.”
- **Levels I–V:** finisher damage **10 / 15 / 20 / 25 / 30%**.
- **Rules:** Applies only to the authored final attack of the basic chain, including every native target of that attack; not all hero damage. No cooldown. Cancelled chains grant nothing; no bonus to bleed, burn, echoes, or separate heavy attacks unless data explicitly tags them `basic_finisher`.
- **Synergy:** `held_breath`, `break_the_rime`, `tinderstrike`.
- **Edge cases:** It never lengthens cancel windows, forces stationary play, or grants an extra hit. Bosses receive the normal damage bonus; no added stagger.
- **Status:** Existing revised mechanic; replaces the current broad `hero_damage` payload.
- **Acceptance:** Two opening chain hits remain unchanged; only the tagged finisher gains the listed amount, including after input cancellation and restart.
- **Icon:** Planted sword and boot; retain `set_stance`.

## W04 — Second Wind [`second_wind`]

- **Rarity / gate / target:** Uncommon; Act 1; dash available; owning hero, B/R.
- **Card face:** “Dash cooldown is 8% shorter.”
- **Levels I–V:** cooldown reduction **8 / 11 / 14 / 17 / 20%**.
- **Rules:** Add to the dash reduction bucket, which has a combined 40% reduction ceiling and the game's absolute floor. No change to invulnerability duration or charges. A new cooldown snapshots current reductions; taking the card never resets an active cooldown.
- **Synergy:** `counterweight`, `returning_oath`.
- **Edge cases:** Direct flat refunds apply after normal cooldown calculation, subject to the same floor; no refund can recreate invulnerability while a dash is active.
- **Status:** Existing revised scalar.
- **Acceptance:** A 4-second base cooldown becomes 3.68/3.2 seconds at I/V; 50% combined reduction resolves to 2.4 seconds, not 2.
- **Icon:** Wind through a scarf; retain `second_wind`.

## W05 — The Long Lever [`the_long_lever`]

- **Rarity / gate / target:** Uncommon; Act 1; equipped direct hero attack with nonzero knockback; owning hero, B/R.
- **Card face:** “Your direct attacks push normal enemies 12% farther.”
- **Levels I–V:** extra knockback distance **12 / 18 / 24 / 30 / 36%**.
- **Rules:** Modifies existing direct hero knockback against non-elite, non-boss enemies only; never creates knockback on an attack without it. No cooldown. Elite and boss behavior is unchanged; never moves rooted encounter anchors or enemies off navigable road geometry. Does not affect towers, traps, companions, or stun duration.
- **Synergy:** `set_stance`, `breach_hunter` where the enemy can be displaced.
- **Edge cases:** Displacement cannot push enemies through the Town Hall or into invalid routes; already accepted movement is not recalculated on replacement.
- **Status:** Existing revised source-scoped modifier; current global knockback must be separated.
- **Acceptance:** Identical hero/tower knockback attacks push by 1.12x/1.00x at I; an immovable boss remains immovable.
- **Icon:** Long-handled hammer; retain `the_long_lever`.

## W06 — The Quiet Approach [`the_quiet_approach`]

- **Rarity / gate / target:** Rare; Act 2; perfect-dodge detector; owning hero and dodged enemy, B/R.
- **Card face:** “Perfect-dodge an enemy: its next direct hit against you within 3s deals 15% less damage. 8s cooldown.”
- **Levels I–V:** reduction on that hit **15 / 18 / 21 / 24 / 27%**.
- **Rules:** Track one enemy instance per hero. Consume on its next damaging direct attack against that hero after armor; periodic damage does not consume it. Cooldown begins on successful dodge. No stacking; newer valid applications replace only after cooldown. No global enemy-damage reduction.
- **Synergy:** `counterweight`, `second_wind`.
- **Edge cases:** The same enemy still deals full damage to town, towers, and the other hero. Boss damage reduction applies but scripted non-damage mechanics are unchanged. Self-inflicted damage cannot trigger or consume it.
- **Status:** Existing revised mechanic, deliberately replacing the current global `enemy_damage` effect.
- **Acceptance:** Dodge a siege enemy; its next hero hit is reduced, its next tower hit is unchanged, and loading during the 3-second window does not renew it.
- **Icon:** Soft-soled boot beside a bell; retain `the_quiet_approach`.

## W07 — Road Runner [`road_runner`]

- **Rarity / gate / target:** Uncommon; Act 1; at least two roads active; owning hero, battlefield-only.
- **Card face:** “Enter a different threatened road: deal 10% more direct damage there for 4s. 12s cooldown.”
- **Levels I–V:** direct hero damage **10 / 14 / 18 / 22 / 26%**.
- **Rules:** A road is threatened when an authored living hostile is on it, irrespective of pressure-color oscillation. Requires 2 seconds outside that road before entry, at least one prior road occupied this battle, and landing in the road's combat zone. Only attacks against enemies assigned to that destination road benefit. Cooldown starts on entry; duration cannot extend.
- **Synergy:** `loose_boots`, `bell_bearer`, `relief_watch`.
- **Edge cases:** Teleporting through the town, boundary jitter, initial spawn, respawn, and loading are not entries. No effect in single-road raid arenas; only available when another combat road can actually be reached.
- **Status:** New mechanic.
- **Acceptance:** Crossing north→east enables one 4-second east-only buff; moving back across the boundary during its cooldown yields no refresh.
- **Icon:** Boot crossing two road signs; new art concept only.

## W08 — Counterweight [`counterweight`]

- **Rarity / gate / target:** Uncommon; Act 1; perfect-dodge detector; owning hero, B/R.
- **Card face:** “After a perfect dodge, your next basic attack within 3s has 10% shorter recovery. 6s cooldown.”
- **Levels I–V:** recovery-time reduction **10 / 12.5 / 15 / 17.5 / 20%**.
- **Rules:** One charge, spent on attack commitment, even on a miss; shorten only the recovery after its final native damage frame. Does not alter anticipation, hit count, damage, spell timing, or a generated echo. Start cooldown when charge is granted; no refresh while held. Combined recovery reductions, including the current perfect-evade haste, cannot reduce authored recovery by more than 40%; preserve existing cancel rules and minimum action interval.
- **Synergy:** `set_stance`, `second_wind`, `returning_oath` (echo excludes this bonus).
- **Edge cases:** One multi-projectile enemy attack produces one perfect-dodge event. This extends the existing tempo reward, respecting the September 2 owner direction that perfect evasion must not add damage.
- **Status:** New mechanic.
- **Acceptance:** Perfect-dodge a volley and commit two basic attacks: only the first has shorter recovery, both deal their normal damage, and missing the first still spends the charge.
- **Icon:** Balanced sword and stone; new art concept only.

## W09 — Cut the Signal [`cut_the_signal`]

- **Rarity / gate / target:** Rare; Act 1 after support-interrupt teaching; an interrupt-capable equipped action and interruptible enemy pool; owning hero, battlefield-only.
- **Card face:** “Interrupt a support cast to gain 4 extra Command. Once per 10s for the party.”
- **Levels I–V:** extra Command **4 / 6 / 8 / 10 / 12**.
- **Rules:** A confirmed interruption before a support's cast resolves adds a separate augment Command contribution, once per cast ID. Party-shared 10-second cooldown and Command cap 100; no meter overflow storage. Fixed integer levels are explicitly authored and do not use the current magnitude heuristic.
- **Synergy:** `borrowed_thunder`, `sealed_footings`, `crosswind_orders`.
- **Edge cases:** Killing an idle support, repeatedly striking a staggered body, interrupt-immune bosses, tower interruptions, and raid orders grant nothing. Generated Command cannot trigger another augment.
- **Status:** New mechanic with explicit integer level table.
- **Acceptance:** Two heroes interrupt the same cast on one simulation tick: the party receives one bonus, credited to the accepted interrupt owner.
- **Icon:** Cut pennant cord; new art concept only.

## W10 — Red Thread [`red_thread`]

- **Rarity / gate / target:** Rare; Act 2; equipped hero ability or held card applies Mark; owning hero, B/R.
- **Card face:** “Directly hit a marked enemy to heal 2% of your maximum Health. 10s cooldown; at most 12% each battle.”
- **Levels I–V:** Health restored per trigger **2 / 2.5 / 3 / 3.5 / 4%** of wounded maximum Health.
- **Rules:** Needs positive direct damage to an enemy already marked before that hit. Cooldown per hero; healing cap 12% of maximum Health recorded at battle start. Clamp attempted healing after all healing modifiers to remaining budget. Actual healing and any overheal generated both spend this budget, so full Health cannot farm conversion. Mark may come from either hero. Bosses are valid.
- **Synergy:** `hunters_mark`, `short_rations`; Oath of Shelter cannot coexist with Hunter's Mark, but another Mark source can support it.
- **Edge cases:** No procs from tower damage, burn, self-hits, corpses, regenerated dummy targets, or augment echoes. Raid gets its own isolated healing allowance; returning does not replenish battlefield allowance.
- **Status:** New mechanic.
- **Acceptance:** After three level-V activations, further marked hits heal zero for that battle, including after unequip/reacquire and save/load.
- **Icon:** Red thread tied around a blade; new art concept only.

## W11 — Held Breath [`held_breath`]

- **Rarity / gate / target:** Uncommon; Act 1; an equipped Mana-cost spell; owning hero, B/R.
- **Card face:** “Land a basic-chain finisher: your next Mana-cost spell within 5s costs 10% less Mana. 8s cooldown.”
- **Levels I–V:** spell Mana reduction **10 / 14 / 18 / 22 / 26%**.
- **Rules:** One charge; finisher must deal positive direct damage. Apply discount to the next successful non-Ultimate Mana-cost cast, then consume. Start cooldown on grant; no stack/extension. Total spell-cost reduction across sources may not exceed 40%; costs remain positive and use the normal rounding rule. No damage or cooldown benefit.
- **Synergy:** `set_stance`, `kindled_edge`, `oath_of_shelter` if a healing spell costs Mana.
- **Edge cases:** Failed casts neither spend Mana nor consume charge; free casts neither consume nor gain anything. No infinite reserve from menu swaps. Suppressed if the loadout loses all eligible spells.
- **Status:** New mechanic; supports current spell infrastructure without requiring the pending discipline rework.
- **Acceptance:** A 20-Mana spell costs 18 at I; a failed out-of-range cast leaves the charge unchanged, while a successful cast consumes it once.
- **Icon:** Breath above a closed spellbook; new art concept only.

## W12 — Kindled Edge [`kindled_edge`]

- **Rarity / gate / target:** Uncommon; Act 1; basic-chain finisher; owning hero and struck enemy, B/R.
- **Card face:** “Your finisher burns one target for 12% of your finisher's base damage over 3s. 6s cooldown.”
- **Levels I–V:** total burn damage **12 / 18 / 24 / 30 / 36%** of the native finisher's pre-augment, pre-crit damage.
- **Rules:** Apply after a natural finisher hits, to the hit enemy closest to the attack's aim point (stable instance-ID tie break). Three equal once-per-second ticks. Separate `kindled_edge` burn channel, one per target across the party, strongest replaces and does not add. Cooldown per hero. Native burn immunity/resistance applies. The status counts as Burn for targeting and direct conditional bonuses, but its ticks cannot trigger augment procs.
- **Synergy:** `tinderstrike` can transfer this status under its fixed budget; `set_stance` supports the same finisher rhythm without increasing this base snapshot. Dry Powder affects tower burns only and does not amplify this card.
- **Edge cases:** No burn multiplication through critical hits, damage-on-burn, or repeated copying. Replacing an existing channel uses the larger remaining total rather than adding totals.
- **Status:** New mechanic using the existing Burn status.
- **Acceptance:** A base-100 finisher applies 12 total burn at I regardless of Set Stance; the burn cannot trigger Counterweight, healing, Command, or another burn.
- **Icon:** Ember along a blade edge; new art concept only.

## W13 — Break the Rime [`break_the_rime`]

- **Rarity / gate / target:** Rare; Act 1; active Chill source and hero finisher; owning hero, B/R.
- **Card face:** “Your finisher deals 15% more direct damage to chilled enemies. It does not remove their Chill.”
- **Levels I–V:** conditional damage **15 / 20 / 25 / 30 / 35%**.
- **Rules:** Evaluate Chill before each natural finisher damage event. No cooldown; no extra strike or extra crowd control. Bosses qualify if their resisted Chill status is positive. Add to other finisher damage bonuses in one bucket.
- **Synergy:** `cold_iron_stakes`, `cold_snap`, `set_stance`.
- **Edge cases:** A slow from terrain, trap, or non-Chill debuff does not qualify. A hero hit that first creates Chill does not also receive this bonus. Native multi-target finishers evaluate each target independently.
- **Status:** New mechanic using existing Chill.
- **Acceptance:** One finisher hits chilled and unchilled enemies with equal defense: only the chilled target receives the conditional increment.
- **Icon:** Blade splitting frost; new art concept only.

## W14 — Breach Hunter [`breach_hunter`]

- **Rarity / gate / target:** Uncommon; Act 1 after priority-role tutorial; authored Support or Siege roles in the upcoming pool; owning hero, battlefield-only.
- **Card face:** “Your direct attacks deal 10% more damage to Support and Siege enemies.”
- **Levels I–V:** role-specific damage **10 / 14 / 18 / 22 / 26%**.
- **Rules:** Enemy resource role tags, never name checks. Direct basic and spell hits qualify; not periodic, companion, trap, or tower damage. No cooldown. Bosses receive the bonus only if explicitly assigned a qualifying vulnerable role in encounter data; no universal boss bonus.
- **Synergy:** `hunters_mark`, `cut_the_signal`, `hammer_the_breach`.
- **Edge cases:** A damage number explicitly labels the qualifying role. No benefit on ordinary bodies whose visual model resembles a support. Cannot hit an invulnerable support through its protection mechanic.
- **Status:** New mechanic using data role filters.
- **Acceptance:** A reskinned Support with a new content ID qualifies; a familiar enemy ID with role Regular does not.
- **Icon:** Sword over a broken siege wheel; new art concept only.

## W15 — Bell Bearer [`bell_bearer`]

- **Rarity / gate / target:** Rare; Act 2; at least one tower deployed; owning hero, battlefield-only.
- **Card face:** “Dash to a tower below half Health: gain a shield worth 6% of your maximum Health for 3s. 12s cooldown.”
- **Levels I–V:** personal shield **6 / 8 / 10 / 12 / 14%** of wounded maximum Health.
- **Rules:** On a completed player dash, end within 160 world units of a living tower below 50% permanent HP; shield only the hero. One shield channel per hero, nonstacking; cooldown starts when granted. Tower summons, blockers without tower identity, and Town Hall do not qualify.
- **Synergy:** `loose_boots`, `road_runner`, `stand_by_the_wall`.
- **Edge cases:** No automatic repair, Command, damage, or ally shielding. Environmental/self damage cannot manufacture a qualifying tower; tower must have lost Health to hostile damage during this battle. Shields cannot be banked across encounter boundaries.
- **Status:** New mechanic.
- **Acceptance:** Dash toward a damaged tower grants one shield; walking there, teleporting on load, or dashing toward the town does not.
- **Icon:** Small bell tied to a running cloak; new art concept only.

## W16 — Borrowed Thunder [`borrowed_thunder`]

- **Rarity / gate / target:** Epic; Act 2; Overdrive unlocked and a valid tower; owning hero, battlefield-only.
- **Card face:** “While near a tower you Overdrive, your direct damage is 12% higher for up to 5s.”
- **Levels I–V:** direct hero damage **12 / 16 / 20 / 24 / 28%**.
- **Rules:** On a successfully paid player Overdrive, bind that order to its issuing hero and tower. Bonus is active within 256 world units while the original Overdrive lasts, maximum 5 seconds. One binding per hero; later paid Overdrive replaces it. No new duration, refund, attack-rate boost, or extension of Overdrive itself.
- **Synergy:** `cut_the_signal`, `common_cause`, `crosswind_orders`.
- **Edge cases:** Copied/generated orders do not bind; another hero's Overdrive grants you nothing. Selling, destroying, or disabling the tower suppresses the bonus; resuming it cannot extend the original end time. Transferring Overdrive away from its original tower ends this binding without copying it. Does not bypass the direct-damage cap.
- **Status:** New mechanic using paid Command order events.
- **Acceptance:** Cast Overdrive, leave radius, return: the buff follows eligibility within the same original end time and never multiplies per entry.
- **Icon:** Sword beneath a struck tower bell; new art concept only.

## W17 — Hunter's Mark [`hunters_mark`]

- **Rarity / gate / target:** Rare keystone; Act 1; three ordinary Warden cards and at least one target-selecting tower; enemy and local tower targeting, battlefield-only.
- **Card face:** “Your direct attacks mark one enemy for 4s. Towers on its road prioritize it while it is in range.”
- **Level:** Fixed I; no duplicate offer or Tempering.
- **Rules:** One shared Hunter's Mark enemy for the party; this channel is separate from ability-applied Marks. A natural direct hit from the bound owning hero selects/refreshes it, at most once per 0.5 seconds. Use the first eligible event in deterministic simulation order. Mark is a status with 4-second duration; tower target preference never changes range, legal-target filters, projectile flight, or player doctrine permanently. Bosses can be marked while targetable. Road assignment comes from the enemy's path, not screen position.
- **Synergy:** `red_thread`, `breach_hunter`, `measured_volley` where its doctrine rule still applies. Any existing Mark source also works with Red Thread, so this keystone is optional.
- **Edge cases:** No +damage or focus fire through invulnerability. Priority returns to doctrine on expiry, death, or suppression. A new Hunter's Mark clears only its previous instance, preventing two-player double marking without deleting other abilities' Marks.
- **Status:** Existing revised keystone; eligibility, party ownership, and target-selection bounds require verification.
- **Acceptance:** Mark east; only eligible east towers retarget. At expiry their original doctrines resume and no north tower gains range.
- **Icon:** Notched arrowhead and eye; retain `hunters_mark`.

## W18 — Tinderstrike [`tinderstrike`]

- **Rarity / gate / target:** Epic keystone; Act 2; three ordinary Warden cards, a usable Burn source, and basic finisher; B/R.
- **Card face:** “Hit a burning enemy with your finisher: share half its remaining Burn damage between up to 3 nearby enemies. 8s cooldown.”
- **Level:** Fixed I; 160-unit radius; party-shared 8-second cooldown.
- **Rules:** “Finish” means land a basic-chain finisher, not necessarily kill. Snapshot the strongest existing eligible Burn channel immediately before the direct hit. Copy a total budget equal to 50% of its remaining pre-defense damage across up to 3 other hostiles, evenly; nearest first, stable-ID ties. Preserve its remaining lifetime, capped at 3 seconds. Original status is unchanged. Per-transfer total additionally capped at 50% of the finisher's pre-augment, pre-crit base damage. No target is selected twice. Incoming copy uses a single nonstacking `tinderstrike` status channel.
- **Synergy:** `kindled_edge`; the same natural tower Burn source used by `dry_powder`; `set_stance` for the active rhythm. Dry Powder does not create a Burn source or multiply the copied payload again.
- **Edge cases:** Bosses take normal resisted Burn but never inherit another enemy's HP-based scaling. Transferred burns carry `augment_generated` and the initiating hero's ownership: they cannot spread again, trigger augment Command/healing/bonus rewards, or benefit twice from burn bonuses. Their kills still pay normal enemy XP/loot exactly once. Source killed on the finisher may still provide its pre-hit snapshot. No free environmental fires or wrath bypass.
- **Status:** Existing ID, materially revised mechanic; current campfire reroute must not silently retain its old meaning in an active save.
- **Acceptance:** A source with 60 remaining burn and a base-100 finisher shares 30 total across three targets, not 30 each; their deaths create no further transfer.
- **Icon:** Three embers from a sword; retain `tinderstrike` after semantic art review.

## W19 — Returning Oath [`returning_oath`]

- **Rarity / gate / target:** Legendary keystone; Act 2; three ordinary Warden cards, dash, and basic finisher; owning hero, B/R.
- **Card face:** “After dashing, your next finisher within 3s echoes once at your dash origin for 35% base damage. 10s cooldown.”
- **Level:** Fixed I; one stored origin and one pending echo per hero.
- **Rules:** A completed player dash stores its start point for 3 seconds. The first committed basic finisher during that window consumes it and schedules an echo 0.25 seconds later. Echo uses the finisher's native shape and committed facing translated to the stored origin, with the native target cap limited to 4 enemies. Echo damage is 35% of that finisher's pre-augment, pre-crit direct base, normal armor/resistance afterward. Start the 10-second cooldown when the echo is committed. Re-dashing before use replaces origin without extending the first window.
- **Synergy:** `second_wind`, `set_stance` for the main strike, `the_long_lever` for main-strike setup; echo receives neither card's bonus.
- **Edge cases:** Echo belongs to its initiating hero and cannot crit, stagger, apply statuses, copy spells, trigger augments, or gain life-steal. It can deal damage and pay normal kill XP/loot once. Camera/scope navigation has no effect. Raid entry suspends the battlefield origin, window, and pending echo; return resumes them exactly. Downing, encounter end, or invalidating the old location cancels the pending echo without refund. Freeze preserves the 0.25-second delay exactly.
- **Status:** New mechanic; reuses attack definition, needs a readable ghost-strike presentation and a strict effect budget.
- **Acceptance:** Dodge across a cluster then finish: one echo hits at the original point. Its four kills do not spawn four more echoes or extra proc rewards.
- **Icon:** Two sword silhouettes joined by a curved road; new art concept only.

## W20 — Oath of Shelter [`oath_of_shelter`]

- **Rarity / gate / target:** Epic keystone; Act 2; three ordinary Warden cards, an equipped direct healing ability, and a deployed tower; owning hero's cast and one tower, battlefield-only.
- **Card face:** “Overheal yourself with an ability: turn 50% of the excess into a nearby damaged tower's shield for 6s. 12s cooldown.”
- **Level:** Fixed I; 224-unit radius; maximum shield 10% of recipient tower's maximum permanent HP.
- **Rules:** Only a successfully paid, manually cast hero ability healing its caster qualifies. Select lowest permanent-HP fraction living tower in radius, stable-ID ties; it must currently be below maximum permanent HP and have hostile damage this battle. Excess is attempted healing minus actual healing after healing modifiers. Convert half to raw shield HP, then cap at 10% tower maximum and the common shield limit. Party-shared cooldown starts only on a positive shield. One nonstacking shield on one tower at a time; new application replaces remaining value only if larger.
- **Synergy:** `held_breath`, `short_rations`; complements active defense without repairing permanent tower Health.
- **Edge cases:** Passive regeneration, consumables, Red Thread, shared co-op healing, on-load Health restoration, and generated healing do not qualify. Cannot protect the Town Hall, revive a destroyed tower, or clear disable. Losing branch depth removes the shield. No effect while the battlefield is suspended for raid.
- **Status:** New mechanic using heal results and tower shield lifecycle; no new healing spell required.
- **Acceptance:** A 40-HP self-heal at 90/100 yields 30 excess and a 15-HP tower shield, capped by tower HP; a potion with the same numbers yields none.
- **Icon:** Open hand holding a small roof; new art concept only.
