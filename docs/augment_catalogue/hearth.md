# Hearth — the town that carries its people

**Proposed content specification; not implemented or playtest-validated.** This branch rewards preparation, purposeful travel, restrained extraction, and protecting the shared town. Its fantasy is neighbors making a difficult journey possible. It must never solve the economy by waiting, make deliberate damage profitable, or replace the hero's work with passive Command.

This is one branch of the proposed 60-card catalogue: **16 ordinary cards and four mutually exclusive keystones**. Use the catalogue's common contract for the eight-card hand, duplicate upgrades, family exclusivity, deterministic offers, shared co-op ownership, and save receipts. The gates below describe the authoritative **three acts plus summit**; they require pacing calibration before use in the current ten-act implementation.

Every numerical design value below is **[TUNE]**, including percentages, thresholds, durations, counts, caps, and act gates. I–V change only the stated primary parameter. These are initial tuning proposals, not balance results. `counted_the_fires` is an explicitly level-I-only integer utility. Every card has its own family, matching its ID. All four keystones compete for the single shared keystone slot, require **three distinct non-keystone Hearth cards**, and also require the stated functional prerequisite. Dropping below that depth suppresses ongoing and future effects; replacing or re-equipping never replenishes a charge or replays a reward. Offer/arming opportunities are separate from ongoing requirements: completing the event that earns a charge does not suppress that charge.

**Branch-wide accounting and scope.** Resources and card counters belong to the shared run, and the host resolves each receipt once for solo or co-op. Either hero can qualify; two heroes never double a shared transaction, death reward, formation, or extraction receipt. Natural Gold, Wood, Food, and Stone are the only resource bases. Card-created resources cannot themselves earn card bonuses. No account rewards, Tools, Sigils, Treasury deposits, sales, refunds, purchases, or transfers count as income. Keep fractional resource remainders in the authoritative ledger and floor the displayed payout only at settlement; do not round every kill upward. A hostile summon, revived enemy, repeat spawn, boss add, or raid enemy has no extra economy value unless its authored first-life reward explicitly allows it, and its source ID pays only once.

**Distance** means actual positive Yuri displacement during a live road battle. Preparation, paused views, raids, bosses, summit, horn stops, and post-clear waiting produce no distance resources or project progress. A temporary construction bonus changes progress per distance, never advances a project while stationary, and expires at road completion. All battlefield timers freeze during raids. Preparation is identified by a durable checkpoint ID, not a UI opening. A road is an authored road encounter, not a wave. Road-completion rewards require the first successful completion receipt. Prices use the final paid amount after discounts; selling uses that recorded basis, not list price. Economic discounts from augments are additive up to 30% and cannot reduce a price below 70% of its normal current-policy cost; final costs round upward. Discounts never produce a refund. Total augment-created shields on any recipient cannot exceed 20% of that recipient's unaugmented maximum HP; Hearth shields on the same recipient use the greater remaining amount and duration instead of adding.

Offer cards only when their target can matter again this run. In particular, stop offering construction, travel, raid-entry, and general income cards after the final relevant road or service. Never append loot or another draft after the true final boss. Existing held cards may remain as part of a build's opportunity cost; the offer system should not knowingly sell a dead promise.

Icon entries are **motif suggestions and existing comparison assets only**. They do not authorize new art, reuse paths in runtime, or override the ID-derived final asset convention. A later implementation must add each approved new ID to the asset manifest and generate its exact placeholder in the same change.

| # | Card / stable ID | Rarity | First act | Core decision |
|---|---|---|---:|---|
| H01 | Picked Clean / `picked_clean` | Common | 1 | Convert combat income into a stronger next preparation |
| H02 | The Forager / `the_forager` | Common | 1 | Invest in surviving distance and producer capacity |
| H03 | Counted the Fires / `counted_the_fires` | Uncommon | 1 | Prepare for the next formation |
| H04 | The Good Road / `the_good_road` | Uncommon | 1 | Repair the town to recover travel efficiency |
| H05 | The Open Hand / `the_open_hand` | Uncommon | 1 | Expand the defense before making a needed repair |
| H06 | The Standing Order / `the_standing_order` | Uncommon | 2 | Earn raid opportunities through deliberate orders |
| H07 | The Quartermaster / `the_quartermaster` | Common | 1 | Choose the first new tower purchase carefully |
| H08 | Shared Tools / `shared_tools` | Uncommon | 1 | Use Command while a project is underway |
| H09 | Field Supper / `field_supper` | Uncommon | 2 | Take an extraction window for recovery supplies |
| H10 | Honest Scales / `honest_scales` | Rare | 2 | Commit the first Market exchange to a real shortage |
| H11 | When the Horn Falls Quiet / `horn_falls_quiet` | Uncommon | 1 | Recover some production after a necessary horn stop |
| H12 | The Return Signal / `return_signal` | Rare | 2 | Extract, resume active defense, and spend Command |
| H13 | Roofs Before Riches / `roofs_before_riches` | Uncommon | 1 | Repair now to earn a tactical town shield later |
| H14 | Borrowed Apron / `borrowed_apron` | Common | 1 | Choose the first tower upgrade carefully |
| H15 | Shared Watch / `shared_watch` | Rare | 2 | Personally resolve threats on different roads |
| H16 | Closing the Roof / `closing_the_roof` | Rare | 2 | Time an emergency order after a project completes |
| H17 | Timberwright / `timberwright` | Epic keystone | 2 | Turn paid town repair into temporary tower cover |
| H18 | Mortar on the March / `mortar_on_the_march` | Epic keystone | 2 | Commit to duplicates for bounded town recovery |
| H19 | Hearthmend Compact / `hearthmend_compact` | Legendary keystone | 2 | Trade part of Rally's blocker shield for central shelter |
| H20 | Four Roads, One Home / `four_roads_one_home` | Legendary keystone | 3 | Coordinate orders across the entire formation |

## H01 — Picked Clean [`picked_clean`]

- **Rarity:** Common. **Earliest act:** 1.
- **Prerequisite and target:** None; natural Gold and Stone paid by eligible battlefield enemy deaths. Family `picked_clean`.
- **Front-of-card rules text:** “Enemy Gold and Stone rewards are 5% greater.”
- **I–V values:** Reward bonus **5 / 7.5 / 10 / 12.5 / 15%**.
- **Trigger / scope / cooldown / cap / duration:** Modify each eligible first-life death receipt in road battles and act-boss encounters. No cooldown. Apply once to the natural payout before card-created bonuses, within the common economy cap. No raid, preparation, summit, final-boss, or account payout. Active only while held.
- **Named synergies:** `the_quartermaster` turns the Gold into an earlier useful tower; `shared_tools` supports the competing town investment.
- **Exploit / edge cases:** Co-op awards once per dead enemy, independent of last hit. Repeated boss adds and zero-reward summons pay zero. Loot collected after removing the card uses the recorded kill-time multiplier, not collection-time equipment.
- **Implementation status:** **Existing revised** — existing ID and kill-resource concept; currency-specific receipts and the new values need verification and migration.
- **Single acceptance test:** With level I held, resolve two natural 10-Gold receipts plus one repeated source ID; shared Gold increases by 21 total, including fractional carry, and the repeated receipt adds zero.
- **Icon motif / existing comparison asset:** A carefully gathered coin and stone; `card_picked_clean`.

## H02 — The Forager [`the_forager`]

- **Rarity:** Common. **Earliest act:** 1.
- **Prerequisite and target:** At least one active distance producer; the Woodcutter's Wood and Wheat Farm's Food. Family `the_forager`.
- **Front-of-card rules text:** “Your Woodcutter and Wheat Farm produce 6% more from distance traveled.”
- **I–V values:** Production bonus **6 / 9 / 12 / 15 / 18%**.
- **Trigger / scope / cooldown / cap / duration:** Modify eligible production for each actual road-distance increment. No cooldown or flat grant. Never modifies Gold, Stone, kill drops, construction speed, or a suppressed producer. Road battles only; stops completely in preparation, raids, bosses, and summit.
- **Named synergies:** `the_good_road`, `horn_falls_quiet`, `shared_tools`.
- **Exploit / edge cases:** Producer tiers alter the natural base once. Other production bonuses add to the base rather than compounding card output. Teleports, backtracking corrections, save restoration, and zero-distance simulation ticks are not travel.
- **Implementation status:** **Existing revised** — existing production ID narrowed to the v4 two-producer economy.
- **Single acceptance test:** At level I, travel enough to produce 100 natural Wood and 50 natural Food, then spend a minute paused in a raid; totals remain 106 Wood and 53 Food.
- **Icon motif / existing comparison asset:** A basket of useful plants beneath a small roof; `card_the_forager`.

## H03 — Counted the Fires [`counted_the_fires`]

- **Rarity:** Uncommon. **Earliest act:** 1.
- **Prerequisite and target:** At least one unrevealed authored formation remains. Family `counted_the_fires`.
- **Front-of-card rules text:** “Preview one additional upcoming formation: its roads, enemy roles, and elite warning.”
- **I–V values:** **I: one additional formation. II–V: unavailable; maximum level I.**
- **Trigger / scope / cooldown / cap / duration:** While held, reveal exactly one formation beyond the normally available forecast in road battle and its preceding preparation. Recompute when the authored queue advances. No cooldown; no reveal of random rewards or hidden boss phases. In an act-boss encounter or summit, only an authored formation forecast can be extended; never invent a forecast.
- **Named synergies:** `shared_watch` plans hero movement; `four_roads_one_home` plans the order sequence; `the_quartermaster` informs spending.
- **Exploit / edge cases:** Existing Watchtower or route intelligence can overlap; offer only if the card adds unrevealed information. Exclude the max-level card from duplicate offers. The guest receives the same reveal as the host. Removing it can hide future UI information but cannot erase the player's knowledge.
- **Implementation status:** **Existing revised** — existing foresight ID; explicit forecast scope and nonredundancy filtering required.
- **Single acceptance test:** With a base preview of formation A, holding the card reveals B but not C; holding an existing forecast that already covers the entire queue excludes this card from offers.
- **Icon motif / existing comparison asset:** Three distant campfires and a tally notch; `card_counted_the_fires`.

## H04 — The Good Road [`the_good_road`]

- **Rarity:** Uncommon. **Earliest act:** 1.
- **Prerequisite and target:** A road battle remains; Yuri's breach-related travel slowdown. Family `the_good_road`.
- **Front-of-card rules text:** “While the Town Hall has at least 75% HP, its damage-related travel slowdown is 15% smaller.”
- **I–V values:** Slowdown reduction **15 / 20 / 25 / 30 / 35%**.
- **Trigger / scope / cooldown / cap / duration:** During road battle, multiply only the damage/breach slowdown component by `1 − bonus` while the HP threshold is met. Re-evaluate on genuine HP changes. No cooldown. Never exceed the undamaged travel speed; retain the game's minimum speed and all authored stop states. No production in bosses, raids, preparation, or summit.
- **Named synergies:** `the_forager`, `the_open_hand`, `mortar_on_the_march`.
- **Exploit / edge cases:** Horn and scripted stops still set speed to zero. A maximum-HP change does not heal the town and recalculates the threshold normally. This changes travel efficiency, not the number of waves or the clear condition.
- **Implementation status:** **Existing revised** — existing speed card becomes conditional recovery instead of unconditional journey acceleration.
- **Single acceptance test:** With a 40% damage slowdown, level I and 80% Town Hall HP produce a 34% slowdown; dropping below 75% restores 40%, and sounding the horn still stops movement.
- **Icon motif / existing comparison asset:** A repaired road leading toward warm windows; `card_the_good_road`.

## H05 — The Open Hand [`the_open_hand`]

- **Rarity:** Uncommon. **Earliest act:** 1.
- **Prerequisite and target:** A legal new base-tower purchase and a future Town Hall repair opportunity. Family `the_open_hand`.
- **Front-of-card rules text:** “After buying a new base tower, your next Town Hall repair this preparation costs 10% less Wood. Once per preparation.”
- **I–V values:** Wood discount **10 / 13 / 16 / 19 / 22%**.
- **Trigger / scope / cooldown / cap / duration:** A new base tower bought for positive Gold while the card is active arms one discount. Consume on the next completed, positive-HP Town Hall repair transaction in the same preparation. One use per preparation; expires at Ride On. Preparation only, including final preparation. It does not discount a town upgrade or restore HP itself.
- **Named synergies:** `the_good_road`, `roofs_before_riches`, `timberwright`.
- **Exploit / edge cases:** Free towers, sale refunds, canceled quotes, and prior purchases do not arm it. Selling/rebuying cannot farm additional uses. Apply the global discount ceiling to final Wood cost. This rule uses existing tower/repair purchases and does not depend on the retired Food-based hero training fees.
- **Implementation status:** **Existing revised** — retires this ID's old stronger copy of kill-income scaling; needs a preparation receipt trigger.
- **Single acceptance test:** Buy one base tower, then make two equal 100-Wood repairs with level I; they cost 90 and 100 Wood, even if the construction tab is reopened between them.
- **Icon motif / existing comparison asset:** One neighbor offering another a working glove; `card_the_open_hand`.

## H06 — The Standing Order [`the_standing_order`]

- **Rarity:** Uncommon. **Earliest act:** 2.
- **Prerequisite and target:** Command and at least one remaining legal road raid opportunity. Family `the_standing_order`.
- **Front-of-card rules text:** “Your first three successful Command orders each road grant 2 additional Raid Charge.”
- **I–V values:** Added Raid Charge per order **2 / 3 / 4 / 5 / 6 points**, on the displayed 0–100 scale.
- **Trigger / scope / cooldown / cap / duration:** A manually targeted Overdrive, Rally Road, or Last Stand must spend positive Command and affect a legal ally or structure. Grant once for each of the first three such orders in a road. No separate cooldown. Preserve the standard 100 charge cap and encounter's raid-entry limit. Road battles only; no boss, summit, preparation, or raid generation.
- **Named synergies:** `field_supper`, `return_signal`, `shared_tools`.
- **Exploit / edge cases:** Failed casts, no-target confirmations, replayed input, automatic effects, and refunded/canceled orders do not count. Entering or leaving a raid does not reset the three-order count. Charge overflow is lost, not converted into currency or another raid.
- **Implementation status:** **Existing revised** — replaces the passive raid-charge multiplier with active, bounded generation.
- **Single acceptance test:** At level I, four qualifying orders within one road add exactly 6 extra charge; entering and returning from a raid between orders does not change that total.
- **Icon motif / existing comparison asset:** A pinned written order beside three filled notches; `card_the_standing_order`.

## H07 — The Quartermaster [`the_quartermaster`]

- **Rarity:** Common. **Earliest act:** 1.
- **Prerequisite and target:** At least one legal new base-tower placement in an upcoming preparation. Family `the_quartermaster`.
- **Front-of-card rules text:** “The first new base tower you buy each preparation costs 8% less Gold.”
- **I–V values:** Gold discount **8 / 11 / 14 / 17 / 20%**.
- **Trigger / scope / cooldown / cap / duration:** Apply to the first completed purchase of a new base tower in each preparation. One use per preparation; no time cooldown. Does not discount mastery upgrades, fusion surcharges, secondary resources, repairs, or town projects. Includes final preparation if a legal placement exists.
- **Named synergies:** `picked_clean`, `counted_the_fires`, `shared_watch`.
- **Exploit / edge cases:** No starting grant and no bypass of the zero-Gold opening. Selling the discounted tower uses actual Gold paid; rebuilding consumes no second discount. Canceled placements do not spend the use. Same-family legacy cost cards cannot stack as alternate names.
- **Implementation status:** **Existing revised** — move the live ID from Rampart to Hearth and replace its unconditional all-build discount.
- **Single acceptance test:** Two 100-Gold base towers bought with level I in one preparation cost 92 and 100; selling the first refunds the normal sale fraction of 92.
- **Icon motif / existing comparison asset:** A checked invoice and one carefully chosen beam; `card_the_quartermaster`.

## H08 — Shared Tools [`shared_tools`]

- **Rarity:** Uncommon. **Earliest act:** 1.
- **Prerequisite and target:** Command available, an active paid town construction project and a road battle remaining. Family `shared_tools`.
- **Front-of-card rules text:** “After a successful Command order, distance advances your town project 20% faster for 10 seconds. At most three times per road.”
- **I–V values:** Construction progress per distance bonus **20 / 25 / 30 / 35 / 40%**.
- **Trigger / scope / cooldown / cap / duration:** A manual positive-cost order affecting a legal target opens a ten-second battlefield-time window. Only actual distance during that window earns extra progress for the currently queued project. Three activations per road. Orders during an existing window neither extend it nor consume another activation. No boss, summit, preparation, or raid progress.
- **Named synergies:** `the_forager`, `the_standing_order`, `closing_the_roof`.
- **Exploit / edge cases:** No project means no trigger or use consumed. Window time freezes in raid and expires at road end. Stationary horn time can consume window time but earns zero progress. Project completion ends the window; no banking progress toward an unqueued project.
- **Implementation status:** **New mechanic** — bounded Command-to-distance construction window.
- **Single acceptance test:** At level I, ten units of actual travel inside the window produce twelve units of project progress; ten seconds stationary produce zero, even with an active window.
- **Icon motif / existing comparison asset:** Two hands passing a hammer beneath the road banner; compare `card_timberwright`.

## H09 — Field Supper [`field_supper`]

- **Rarity:** Uncommon. **Earliest act:** 2.
- **Prerequisite and target:** A remaining raid whose natural extraction table includes Food. Family `field_supper`.
- **Front-of-card rules text:** “Choosing either raid extraction window grants 10% more of the Food you earned there. Once per act.”
- **I–V values:** Natural raid Food bonus **10 / 15 / 20 / 25 / 30%**.
- **Trigger / scope / cooldown / cap / duration:** Resolve on a deliberate first- or second-window extraction with positive natural Food. One bonus per act, applied only to that raid's earned Food. No time cooldown. Chieftain victory, forced expiry, and hero-down ejection do not qualify. No battlefield, boss, preparation, or summit income.
- **Named synergies:** `the_standing_order`, `return_signal`, `borrowed_apron`.
- **Exploit / edge cases:** Not a new raid-entry allowance. Card-created Food, ransom, duplicated receipts, and zero-Food extractions do not increase the base. The bonus never produces a relic or leader. The original battlefield resumes unchanged; settlement occurs through the ordinary return transaction.
- **Implementation status:** **New mechanic** — choice-specific raid settlement modifier.
- **Single acceptance test:** At level I, a chosen window with 40 natural Food settles 44; a second chosen extraction in the same act with 40 Food settles only 40.
- **Icon motif / existing comparison asset:** A covered cooking pot carried home before nightfall; compare `card_the_forager`.

## H10 — Honest Scales [`honest_scales`]

- **Rarity:** Rare. **Earliest act:** 2.
- **Prerequisite and target:** Trading Market built and usable, with at least one legal exchange remaining. Family `honest_scales`.
- **Front-of-card rules text:** “Your first Market exchange each preparation costs 8% fewer offered resources. Always pay at least 10% more value than you receive.”
- **I–V values:** Offered-resource discount **8 / 11 / 14 / 17 / 20%**.
- **Trigger / scope / cooldown / cap / duration:** Modify one confirmed exchange per preparation, using the unmodified exchange table's common resource-value basis. Discount the outgoing quantity only; retain a minimum offered value of 110% of received value, rounding cost upward. Preserve the Market's original exchange limit. Preparation only, including final preparation.
- **Named synergies:** `the_forager`, `the_quartermaster`, `the_open_hand`.
- **Exploit / edge cases:** Does not apply to Market services or turn an exchange into profit. The exchange's output is never natural income for other cards. Small trades may gain no discount due to integer rounding; preview the exact quote. Only offer after the building is actually usable, including its account-unlock requirements.
- **Implementation status:** **New mechanic** — one-exchange discount plus normalized loss floor; do not reuse an unrestricted build-cost scalar.
- **Single acceptance test:** For a base exchange costing 125 value to receive 100 value, level V costs 110 rather than 100; reversing the exchange cannot restore the starting value.
- **Icon motif / existing comparison asset:** Balanced pans with a visible fee token beside them; compare `card_the_quartermaster`.

## H11 — When the Horn Falls Quiet [`horn_falls_quiet`]

- **Rarity:** Uncommon. **Earliest act:** 1.
- **Prerequisite and target:** An unused road horn opportunity and at least one active Wood/Food producer. Family `horn_falls_quiet`.
- **Front-of-card rules text:** “After the war horn ends, your next 8 seconds of travel produce 15% more Wood and Food.”
- **I–V values:** Natural production bonus **15 / 20 / 25 / 30 / 35%**.
- **Trigger / scope / cooldown / cap / duration:** The first legitimate end of the road's horn stop arms eight seconds of moving battlefield time. Consume time only while Yuri has positive normal road displacement. Expires at road completion. Once per road, no second cooldown. Road battles only; the summit's scripted horn is excluded because it has no production economy.
- **Named synergies:** `the_forager`, `the_good_road`, `shared_tools`.
- **Exploit / edge cases:** Horn toggles, canceled input, and scripted non-horn stops do not arm it. It cannot recover all income lost to a horn by extending combat; the authored finite encounter supplies the available distance. Bonus production adds to the same natural base as `the_forager`.
- **Implementation status:** **New mechanic** — limited production window after the existing once-per-road horn.
- **Single acceptance test:** At level I, with a natural rate of 10 Food per moving second, eight post-horn moving seconds yield 92 Food; an intervening raid neither advances time nor produces Food.
- **Icon motif / existing comparison asset:** A lowered horn beside a returning wheel track; compare `card_the_good_road`.

## H12 — The Return Signal [`return_signal`]

- **Rarity:** Rare. **Earliest act:** 2.
- **Prerequisite and target:** A remaining chosen raid-extraction opportunity and Command enabled. Family `return_signal`.
- **Front-of-card rules text:** “After choosing a raid extraction window, earn 15 Command through hero actions. Your next Overdrive or Rally Road costs 10% less.”
- **I–V values:** Command cost discount **10 / 15 / 20 / 25 / 30%**.
- **Trigger / scope / cooldown / cap / duration:** A chosen window creates one pending return effect. After battlefield resume, accumulate fifteen natural Command earned through either hero's qualifying actions, then arm the discount. Consume on the next successful paid Overdrive or Rally Road. One use per road; expires at road completion. No raid-order, boss, preparation, summit, or Last Stand discount.
- **Named synergies:** `field_supper`, `the_standing_order`, `shared_tools`.
- **Exploit / edge cases:** The frozen battlefield snapshot is not edited in the raid. Apply pending state after resume through an explicit return receipt. Command generated by cards, overflow beyond the meter cap, and pre-raid Command do not satisfy the fifteen-point requirement. Final cost rounds upward; total Command-cost reduction cannot exceed 40%.
- **Implementation status:** **New mechanic** — post-return active-play requirement and one-use order pricing.
- **Single acceptance test:** At level I, extract with 40 stored Command: the discount stays locked until fifteen fresh natural Command is actually credited, then a 30-cost Overdrive costs 27 exactly once.
- **Icon motif / existing comparison asset:** A lantern raised above a returning banner; compare `card_the_standing_order`.

## H13 — Roofs Before Riches [`roofs_before_riches`]

- **Rarity:** Uncommon. **Earliest act:** 1.
- **Prerequisite and target:** Town Hall can be repaired for Wood; Rally Road available. Family `roofs_before_riches`.
- **Front-of-card rules text:** “Pay for Town Hall repair in preparation. Your first Rally Road next battle also shields the Town Hall for 2% of its base maximum HP for 6 seconds.”
- **I–V values:** Town Hall shield **2 / 2.5 / 3 / 3.5 / 4%** of unaugmented maximum HP.
- **Trigger / scope / cooldown / cap / duration:** While this card is active, positive Wood paid and positive HP restored arms one benefit for the immediately following road, act boss, or summit battle. Its first successful manual Rally Road grants the shield for six battlefield seconds. One trigger per battle; expires unused at battle end. Preparation arms it; raids cannot trigger or consume it and freeze its timer. Taking the card after paying cannot read past receipts to arm it.
- **Named synergies:** `the_open_hand`, `timberwright`, `hearthmend_compact`.
- **Exploit / edge cases:** No free Hearthmend repair, rank repair, overheal, town upgrade, or equip event qualifies. Snapshot unaugmented Town Hall maximum at battle start. Same-recipient Hearth shields use the greater remaining shield amount and duration, never sum or refresh indefinitely. Deliberately taking damage costs real HP and repair resources.
- **Implementation status:** **New mechanic** — paid-repair receipt grants one tactical shield opportunity.
- **Single acceptance test:** Repair positive HP for Wood, then cast Rally in the next battle with base Town Hall maximum 1,000: level I grants 20 shield for six seconds; another Rally grants no second shield.
- **Icon motif / existing comparison asset:** A small roof held above a precious coin purse; compare `card_timberwright`.

## H14 — Borrowed Apron [`borrowed_apron`]

- **Rarity:** Common. **Earliest act:** 1.
- **Prerequisite and target:** A deployed tower with a legal remaining paid level upgrade, including any required Forge tier. Family `borrowed_apron`.
- **Front-of-card rules text:** “The first tower level you buy each preparation costs 6% less Gold.”
- **I–V values:** Gold discount **6 / 8 / 10 / 12 / 14%**.
- **Trigger / scope / cooldown / cap / duration:** Modify the first committed positive-Gold tower level-up per preparation. A fusion's ordinary level upgrade qualifies; constructing a new fusion does not. One use per shared preparation, not per player. Secondary resource prices and existing Forge gates remain unchanged. Preparation only, including final preparation.
- **Named synergies:** `picked_clean`, `the_quartermaster`, `honest_scales`.
- **Exploit / edge cases:** Does not change sale refunds or level eligibility. A free scripted upgrade neither consumes nor cashes out the discount. Co-op previews show which transaction consumes the shared use. Sell/rebuild, menu reopening and aborted quotes cannot renew it. This is an upgrade-versus-expansion decision, not a discount on the retired paid hero respec.
- **Implementation status:** **New mechanic** — one-upgrade transaction discount using existing tower leveling.
- **Single acceptance test:** With level I and two otherwise 100-Gold tower upgrades, the first costs 94 and the second costs 100 in the same preparation; secondary Wood/Stone prices remain unchanged.
- **Icon motif / existing comparison asset:** A smith's borrowed apron with one polished rivet; compare `card_the_open_hand`.

## H15 — Shared Watch [`shared_watch`]

- **Rarity:** Rare. **Earliest act:** 2.
- **Prerequisite and target:** A future authored road containing eligible priority threats on at least two roads. Family `shared_watch`.
- **Front-of-card rules text:** “Kill priority threats by direct hero attacks on two different pressured roads. Clearing the road grants 5% more of its naturally earned Wood.”
- **I–V values:** Natural road Wood bonus **5 / 7.5 / 10 / 12.5 / 15%**.
- **Trigger / scope / cooldown / cap / duration:** A qualifying first-life priority-target kill must have an authored Support or Siege role, or Elite rank, and occur while its lane is Caution, Danger or Collapse. Record distinct lanes across either hero. At first successful road-encounter completion, if at least two lanes qualified, grant the bonus on that encounter's natural distance-production Wood plus authored road-reward Wood, within the shared economy ceiling. Once per road encounter; no timer. Road battles only.
- **Named synergies:** `counted_the_fires`, `the_forager`, `four_roads_one_home`.
- **Exploit / edge cases:** Qualifying direct hero attacks include normal weapons and active abilities, excluding towers, traps, reflected damage, all periodic damage regardless of hero position, and card-generated hits. Periodic damage still kills normally but cannot qualify this challenge. Mark two lane lamps in the detail UI. Raid Wood, sales, and card output are excluded; never reward delaying a clear or repeating waves.
- **Implementation status:** **New mechanic** — two-road personal-response challenge with a completion receipt.
- **Single acceptance test:** With level I, direct qualifying kills on roads north and east and 100 natural eligible Wood grant 5 Wood once at completion; two kills on north alone grant zero bonus.
- **Icon motif / existing comparison asset:** Two lit watchfires facing different roads; compare `card_counted_the_fires`.

## H16 — Closing the Roof [`closing_the_roof`]

- **Rarity:** Rare. **Earliest act:** 2.
- **Prerequisite and target:** Active paid town project; at least one allied blocker and Rally Road available. Family `closing_the_roof`.
- **Front-of-card rules text:** “Completing a town project strengthens your next Rally Road's blocker shields by 15%.”
- **I–V values:** Bonus to Rally's natural blocker shield amount **15 / 20 / 25 / 30 / 35%**.
- **Trigger / scope / cooldown / cap / duration:** A unique paid project completion arms one charge. Consume when a manual Rally Road actually grants a shield to at least one blocker. Maximum one stored charge; another completion while armed does not stack. A charge may carry from its completion road into the next battle, then expires at that battle's end. Works in road, act-boss, and summit battles; raid timers and state remain frozen.
- **Named synergies:** `shared_tools`, `the_good_road`, `hearthmend_compact`.
- **Exploit / edge cases:** Free foundations, loading a completed building, canceling/requeuing, and repeated completion events do not arm it. This modifies the ordinary Rally shield once; it cannot increase a shield created by another card. The Rally's existing duration and recipient count remain unchanged.
- **Implementation status:** **New mechanic** — unique town-completion receipt carried into one order.
- **Single acceptance test:** Complete a project with level I, then cast two Rally orders that normally grant 100 blocker shield each; the first grants 115 per eligible blocker and the second grants 100.
- **Icon motif / existing comparison asset:** The final roof beam above a waiting shield; compare `card_timberwright`.

## H17 — Timberwright [`timberwright`]

- **Rarity:** Epic keystone. **Earliest act:** 2.
- **Prerequisite and target:** Three ordinary Hearth cards; a legal paid Town Hall repair, at least one tower and Rally Road available. Targets towers on the chosen lane. `roofs_before_riches` is an optional synergy, not a named-card gate.
- **Front-of-card rules text:** “Pay for Town Hall repair in preparation. Your first Rally Road that reaches damaged towers next battle shields up to three of them for 8% of their base maximum HP for 8 seconds.”
- **I–V values:** **Fixed level I:** 8% shield; eight seconds; three towers; once per battle. II–V unavailable.
- **Trigger / scope / cooldown / cap / duration:** A positive-cost, positive-healing repair receipt committed while this keystone is active arms the benefit. On the next battle's first manual Rally that has damaged towers on its lane, select up to three by lowest current HP fraction, then stable tower ID. Works in road, act-boss, and summit battles. No raid triggering; battlefield timers freeze. No eligible towers means the benefit remains armed for that battle. Taking the card later cannot read past repairs to arm it.
- **Named synergies:** `roofs_before_riches` protects the center while this protects the formation; `the_open_hand` reduces the competing repair cost; `closing_the_roof` improves the Rally's ordinary blocker protection.
- **Exploit / edge cases:** Reworks the live tree-felling permanent heal into temporary cover compatible with v4 preparation commitments. It never resurrects, repairs permanent HP, reactivates a destroyed fusion parent, or bypasses tower-repair costs. Snapshot base tower HP without temporary augment multipliers. A repaired-to-full or destroyed tower is not eligible. Dropping Hearth depth removes surviving shields and pending benefit; re-equipping does not restore either.
- **Implementation status:** **Existing revised** — live ID and art exist; this proposed shield trigger replaces the live gathering heal and requires a deliberate migration.
- **Single acceptance test:** After a paid town repair, Rally a road with four damaged 1,000-base-HP towers: exactly the three lowest HP fractions receive 80 shield for eight seconds; permanent HP remains unchanged.
- **Icon motif / existing comparison asset:** A carpenter holding a temporary timber brace over a tower; `card_timberwright`.

## H18 — Mortar on the March [`mortar_on_the_march`]

- **Rarity:** Epic keystone. **Earliest act:** 2.
- **Prerequisite and target:** Three ordinary Hearth cards, at least one held ordinary card below its level cap, and a future duplicate-capable draft. Targets the shared Town Hall. `the_good_road` is an optional synergy.
- **Front-of-card rules text:** “In Preparation, upgrading a held augment repairs 2% of the Town Hall's base maximum HP. Once per preparation; at most 10% repaired per run.”
- **I–V values:** **Fixed level I:** 2% repair per qualifying duplicate upgrade; one trigger per preparation; 10% base-max-HP lifetime repair budget. II–V unavailable.
- **Trigger / scope / cooldown / cap / duration:** A committed duplicate choice or Tempering that increases an already-held ordinary card's level, such as I to II, qualifies. This keystone must have been active before the choice; either seat's valid upgrade can use the single party allowance. Bind crossroads and their associated drafts to one preparation checkpoint receipt, never UI openings. Resolve repair during actual Preparation, not a paused mid-combat draft; the latter is ineligible and banks no later repair. Snapshot unaugmented Town Hall maximum at first acquisition for the whole run budget. Eligible final pre-summit Preparation still counts; no summit-combat or final-boss payout.
- **Named synergies:** `the_good_road` turns recovered town condition into travel efficiency; `the_forager` makes surviving that distance valuable. Duplicate-heavy hands are the intentional commitment.
- **Exploit / edge cases:** New family acquisition, rarity changes, road XP ranks, hero levels, meta Legacy Rank, free level synchronization, loaded saves, declined offers, and replacement do not trigger. Use a unique draft receipt and persistent spent-budget counter. At full HP, the preparation's trigger is consumed but the unused HP budget is not; no repair is banked. This free repair never arms paid-repair cards. Removing the keystone does not undo already restored HP and cannot refund its consumed trigger or budget.
- **Implementation status:** **New mechanic** — the ID exists only in staged proposal data; replace its ambiguous “every rank” promise and six-card requirement, not an alleged live behavior.
- **Single acceptance test:** With a 1,000-HP budget basis and active keystone, an eligible duplicate repairs 20 HP; a second duplicate in the same preparation, removal/re-equip, and replay of the first receipt each repair zero, and six qualifying preparations cannot exceed 100 total repair.
- **Icon motif / existing comparison asset:** A mason laying one bright seam in a traveling wall; compare `card_timberwright`.

## H19 — Hearthmend Compact [`hearthmend_compact`]

- **Rarity:** Legendary keystone. **Earliest act:** 2.
- **Prerequisite and target:** Three ordinary Hearth cards; an uncommitted upcoming Hearthmend enhanced-service choice to offer/arm the pact; Rally Road and a blocker-shield implementation. `roofs_before_riches` is optional. A committed pact does not require another future Hearthmend and can last through summit.
- **Front-of-card rules text:** “Choose extra town repair at Hearthmend. Until the next Hearthmend, your first Rally Road each battle gives the Town Hall a 5% base-HP shield for 8 seconds, but that order's blocker shields are 20% smaller.”
- **I–V values:** **Fixed level I:** 5% Town Hall shield; eight seconds; 20% reduction to that order's ordinary blocker shields; once per battle. II–V unavailable.
- **Trigger / scope / cooldown / cap / duration:** The card must be held when extra town repair is chosen. That service arms the compact even if its repair is partly wasted, since choosing it forgoes the other enhanced services. The pact ends when the next Hearthmend service is committed; choosing extra repair there renews it, another choice does not. The Act III pact therefore remains available through summit. First successful Rally each road, act boss, or summit battle grants the shield and applies its blocker tradeoff. Raids freeze all effects.
- **Named synergies:** `roofs_before_riches` supplies an alternate earlier shield; `closing_the_roof` partially offsets the blocker tradeoff; `the_good_road` rewards successful central protection.
- **Exploit / edge cases:** Hearthmend does not become a paid-repair receipt. Town Hall shields use the greater remaining amount/duration rather than adding H13's shield. Apply the 20% reduction after ordinary Rally shield bonuses; never consume or reduce existing blocker HP or another card's tower shields. No backward service lookup on equip, no extra enhanced service, and no repair or shield on pact renewal itself. Suppression removes the persistent pact; re-equipping requires a future legal service choice.
- **Implementation status:** **New mechanic** — a service-committed pact with a visible central-defense versus blocker-defense tradeoff. Gate integration and offers on the existing v4 enhanced Hearthmend service being implemented; this card adds no new service or menu.
- **Single acceptance test:** Hold the card and choose extra repair at Act III Hearthmend; the first summit Rally grants 50 Town Hall shield with 1,000 base HP and turns its normal 100-point blocker shields into 80; the second Rally receives neither effect.
- **Icon motif / existing comparison asset:** Several roofs beneath one raised lantern, with a signed cloth strip; compare `card_the_open_hand`.

## H20 — Four Roads, One Home [`four_roads_one_home`]

- **Rarity:** Legendary keystone. **Earliest act:** 3.
- **Prerequisite and target:** Three ordinary Hearth cards; all four lanes accessible with a legal living allied Command target on each and a legal Rally target on whichever lane completes the sequence. `shared_watch` is optional. Targets the shared Town Hall.
- **Front-of-card rules text:** “Use successful Command orders on three different roads, then Rally the fourth. The Town Hall gains an 8% base-HP shield for 12 seconds. Twice per battle.”
- **I–V values:** **Fixed level I:** three distinct preparation roads followed by Rally on the fourth; 8% shield; twelve seconds; two activations per battle. II–V unavailable.
- **Trigger / scope / cooldown / cap / duration:** Each manual positive-cost Overdrive or Rally that affects a living allied tower or blocker records its selected road. Repeated roads do not advance the sequence. Once three are recorded, only a successful Rally on the missing fourth completes the cycle. Its effect resolves normally, then adds the Hall shield and clears the recorded set. Last Stand has no selected road and cannot advance it. Road, act-boss, and summit battles only; raid neither advances nor resets the set.
- **Named synergies:** `shared_watch` rewards the same distributed response; `counted_the_fires` exposes upcoming needs; `shared_tools` makes the qualifying orders advance construction where roads still remain.
- **Exploit / edge cases:** Empty-road casts, auto-casts, free replicated effects, and duplicated network packets do not count. Display the four-road sequence in the detail panel and a compact four-lamp indicator. No new Command is generated. Town shields follow the non-additive Hearth shield rule. The second activation cannot extend total continuous protection past twenty-four seconds. On branch suppression clear progress and remove the shield; restoring depth cannot recreate it. If the authored boss phase temporarily removes a road target, retain progress but do not invent a target.
- **Implementation status:** **New mechanic** — four-road sequence tracking over existing targeted orders, without new currencies or inputs.
- **Single acceptance test:** Cast qualifying orders north, east, west, then Rally south with 1,000 base Town Hall HP: gain exactly 80 shield for twelve seconds and one cycle spent; repeated orders north before the other roads never complete a cycle.
- **Icon motif / existing comparison asset:** Four road ribbons meeting at a warm town window; compare `card_counted_the_fires`.

## Migration disposition

Preserve `picked_clean`, `the_forager`, `counted_the_fires`, `the_good_road`, `the_open_hand`, `the_standing_order`, and `timberwright` as identities, with explicit behavior changes described above. Move `the_quartermaster` from Rampart to Hearth. The old `the_open_hand` 40% kill-resource ladder is **retired as a behavior**; `picked_clean` carries the new-run loot role. The Open Hand's ID now owns the expansion-to-repair decision. Apply only at the versioned new-run boundary in the common policy; legacy active runs retain their original meanings.

The staged `mortar_on_the_march` is accepted only in its rewritten, bounded form here. Other staged Hearth scalars are not additional approved cards: do not load them alongside these twenty as hidden rarity ladders. No listed status means the exact proposal already works. No runtime, schema, staging data, asset manifest, or art file is changed by this document.
