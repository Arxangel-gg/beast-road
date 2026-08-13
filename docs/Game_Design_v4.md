# BEAST ROAD

## Game Design Document v4.0 - Production Target

**Status:** AUTHORITATIVE 1.0 DESIGN  
**Date:** 2026-08-13  
**Audience:** design, engineering, art, audio, QA, publishing  
**Supersedes:** `Game Design.md`, `Game_Design_v2.md`, and `Game_Design_v3.md`  
**Working title:** *Beast Road*; final title requires storefront and trademark clearance.

> **North star:** One hero, four roads, and a moving town that cannot be defended everywhere at once. Towers hold the formation. The hero, the route, and the player's timing decide where the defense bends and where it breaks.

---

## 0. How to Use This Document

This is the production source of truth for the intended 1.0 game. Earlier GDDs remain useful design history, but they are not implementation authority after v4 is adopted. When code and this document differ, the difference belongs in the production checklist until the code is migrated or the GDD is deliberately amended.

### Decision language

- **LOCKED** - build this unless the owners approve a written design change.
- **TUNE** - the rule is locked; exact numbers must be validated through playtests.
- **OPEN** - a decision is genuinely unresolved and has an owner and deadline.
- **POST-LAUNCH** - valuable, but not required for 1.0.
- **CUT** - deliberately excluded. Do not implement by accident.

### Change control

Every material design change must update this document, the affected acceptance criteria, and the v4 changelog. Gameplay values belong in `game/scripts/Balance.gd`; content definitions belong in data resources. A feature is not complete because it exists. It is complete when it meets its playtest, clarity, performance, accessibility, and failure-state criteria.

### The four questions every feature must pass

1. Does it sharpen four-road triage or a meaningful between-battle decision?
2. Does the player understand the threat, the choice, and the result?
3. Does it remain useful after the first boss rather than becoming solved or idle?
4. Is it worth its production, asset, test, and tutorial cost?

If the answer to any question is no, revise or cut the feature.

---

# Part I - Product Vision

## 1. High Concept

*Beast Road* is a single-player 2D action tower-defense roguelite for PC. A human refuge rides on the back of Yuri, an ancient walking beast, while a coalition of hostile war hosts closes from four directions. The player controls one hero, designs elemental tower formations, grows the town through distance survived, chooses dangerous roads, raids enemy camps, and fights toward a mountain summit where the true final enemy waits.

The game combines:

- the spatial triage of action tower defense;
- the run-shaping choices of a deckbuilding roguelite;
- the visible growth of a compact traveling town;
- the commitment and attrition of a dark expedition;
- the spectacle of a settlement carried by a colossal living world.

### Player fantasy

> I am the indispensable field commander of a living fortress. I read a collapsing defense, cross the beast in time, trigger a perfect counterattack, and turn a desperate road into a build that feels entirely mine.

### Pitch image

A firelit town and four elemental defenses stand on the immense back of Yuri while enemies climb from a moonlit jungle below. The hero dashes toward the one road about to fail. The whole battlefield sways subtly with Yuri's stride.

That image must remain readable in gameplay, screenshots, trailers, and store capsule art.

## 2. Product Definition

| Field | 1.0 target |
|---|---|
| Genre | Action tower-defense roguelite |
| Mode | Single-player, offline |
| Launch platform | Windows PC |
| Input | Mouse and keyboard; controller parity required for 1.0 |
| Camera | Top-down battlefield, town management, side-profile beast journey |
| Run length | 42-48 minutes of combat; 55-65 minutes median wall-clock including planning `[TUNE]` |
| Campaign | Three acts plus a final summit ascent |
| Business model | Premium complete game; no ads, stamina, loot boxes, or paid power |
| Audience | Players who enjoy Hades-style action clarity, tower-defense planning, and Slay the Spire-style run decisions |
| Rating target | Teen-equivalent fantasy violence; no sexual content; no casualized slavery framing |
| Performance | Stable 60 FPS at 1920x1080 on the declared minimum specification |

## 3. Design Pillars

### 3.1 One hero cannot be everywhere

Four roads create simultaneous obligations. The hero is powerful enough to rescue one failing road, not powerful enough to invalidate tower planning. Travel time, lane pressure, telegraphs, and enemy roles make positioning the main combat decision.

### 3.2 Preparation creates commitment; combat creates adaptation

Towers, town projects, relic sockets, and hero loadouts are changed during safe preparation. In combat, the player adapts through movement, attacks, abilities, targeting doctrines, the war horn, and Command orders. The player is never waiting for towers to finish a solved encounter.

### 3.3 Surviving is building

Yuri's distance advances construction. The town grows because the player held the road, not because a real-time timer elapsed in a menu. Damage and delay visibly slow the expedition, making defense, economy, and journey one loop.

### 3.4 Every run becomes an elemental formation

Eight base towers and ten combination towers create readable, repeatable build identities. All four elements are available from the beginning; scarcity comes from resources, offers, space, and upgrades, not from hiding the game's signature fusion system until the run is nearly over.

### 3.5 A desperate journey with triumphant release

The world is harsh, high-contrast, and dangerous, but not hopeless or cruel for decoration. Near-failures build tension; decisive hero abilities, tower combinations, boss breaks, and extraction choices provide the release. Tone is dark adventure with human warmth, not nihilism.

## 4. Experience Goals and Non-Goals

### The game should make players feel

- clever when a formation answers several enemy roles;
- urgently responsible when two roads deteriorate at once;
- powerful when active play converts danger into Command and a counterattack;
- tempted by a road, horn, or raid that could improve the build or end it;
- attached to Yuri and the town because both visibly carry the history of the run;
- eager to start again because the next build offers a different plan, not merely larger numbers.

### The game should not become

- an idle tower simulator after the first act;
- a frantic click tax where planning is irrelevant;
- a currency spreadsheet with five interchangeable wallets;
- a meta-grind that requires ten wins before the complete game appears;
- a generic or derivative fantasy collage;
- a visibility test where mood lighting hides threats or telegraphs;
- a run lost to one unreadable burst after an hour of play.

## 5. Success Metrics

The following are balance and usability targets, not marketing forecasts.

| Area | Target |
|---|---|
| First-road survival | 90%+ of new Standard players after onboarding `[TUNE]` |
| First Act boss reach | 65-75% of new Standard players `[TUNE]` |
| First full clear | Achievable within 3-6 runs for a genre-familiar player `[TUNE]` |
| Skilled Standard clear rate | 60-75% after mastery `[TUNE]` |
| Meaningful pressure | At least one road at caution or danger for 55-70% of combat time after the opening road `[TUNE]` |
| Idle time | No interval above 8 seconds in which a healthy player has no meaningful tactical action or upcoming decision `[TUNE]` |
| Build diversity | No tower, discipline, road type, or relic appears in more than 35% of winning loadouts without a balance review `[TUNE]` |
| Readability | 90%+ correct recognition of boss telegraphs and elite roles in moderated tests after first exposure `[TUNE]` |
| Performance | 60 FPS at the maximum supported live-enemy/effect budget on minimum spec |

---

# Part II - World, Story, and Tone

## 6. Premise

Yuri is one of the last Worldstriders: beasts large enough to carry soil, water, and a settlement across their backs. A human refuge has built its remaining town upon Yuri and travels toward the Crown of the World, a summit where an ancient beacon can break the chain-magic driving the war hosts into pursuit.

The player is the town's Warden, a singular defender bound to Yuri. The enemy is not an entire species declared evil; it is the Chainbound Host, a military alliance serving the warlord who controls the summit. Regional clans have distinct motives, tactics, and leaders. Some defeated leaders may surrender, defect, or swear a temporary road-oath.

The story is delivered through short battle barks, visual travel moments, boss introductions, crossroads, building vignettes, and an illustrated opening and ending. No mandatory dialogue sequence may interrupt a replay for longer than ten seconds. All cinematics are skippable after first viewing.

## 7. Tone Rules

### LOCKED

- Grim stakes, warm sanctuary, spectacular elemental action.
- Yuri is a character, not a vehicle-shaped menu.
- The town's people react to damage, recovery, bosses, weather, and victory.
- Enemy leaders are dangerous people with agency, not collectible slaves.
- Regional cultures use original names, silhouettes, materials, and language.
- Humor comes from life aboard a walking town, never from atrocity or humiliation.

### CUT

- References to copyrighted factions or shorthand from other franchises in shipped text or asset briefs.
- Permanent loyal enslavement as a reward economy.
- Race-essentialist framing in which every orc is inherently evil.
- lore dumps that stop the run.

## 8. Campaign Arc

Names in this section are production working names and may receive a final narrative naming pass without changing mechanics.

### Act I - The Verdant Maw

A dense, rain-heavy jungle where the Cinderpaint Host marks armor with coal paste and attacks through smoke, roots, and wolf cavalry. The act teaches lane pressure, support enemies, torch control, and raids.

**Visual identity:** saturated wet greens, charcoal blacks, ember orange, heavy foliage, broken shrines, warm town light against cool rain.  
**Mechanical identity:** regeneration, pack leaders, flanking riders.  
**Act boss:** Rakka Coal-Eye, Wolf Marshal `[TUNE name]`.

### Act II - The Sunglass Waste

A bright desert of fused sand, buried roads, and mirage storms. The Veiled Scale-Riders use lizard mounts, reflective armor, javelins, and tunneling scouts.

**Visual identity:** pale sand, red cloth, turquoise glass, violent heat shimmer, long black shadows.  
**Mechanical identity:** speed, projectile deflection, burrowing, split formations.  
**Act boss:** Veyr of the Sunglass, Dune Seer `[TUNE name]`.

### Act III - The White Teeth

A frozen mountain approach where the Rimebound Clans field massive orcs, ice-clad siege carriers, and storm callers. Paths narrow and weather suppresses visibility without hiding telegraphs.

**Visual identity:** blue snow, black stone, pale aurora, red warning cloth, hard moonlight, warm windows on Yuri.  
**Mechanical identity:** armor, tower disruption, lane blockages, coordinated heavy pushes.  
**Act boss:** Mogrun White-Maw, Avalanche King `[TUNE name]`.

### Final Ascent - Crown of the World

After Act III, the run does not end in a reward screen. Yuri climbs a short, authored summit route where remnants of all three armies converge. The final encounter alternates multi-road defense with direct hero pressure on the chains binding Yuri.

**Final boss:** Kharok the Chainmaker `[TUNE name]`.  
**Final reward:** the run ending, a Sigil, unlock payout, ending sequence, and difficulty progression. No in-run reward is granted after the run has already ended.

---

# Part III - The Run

## 9. Run Structure

### Standard run sequence

1. Choose difficulty, unlocked starting doctrine, and optional Treasury cache.
2. Enter Initial Preparation.
3. Fight three road battles in Act I, choosing at two crossroads.
4. Complete a final preparation and defeat the Act I boss.
5. Repeat for Acts II and III with escalating systems and enemy mixtures.
6. Choose an Act III Ascension Keystone.
7. Complete the Final Ascent and defeat the true final boss.
8. View the defense debrief, unlock payout, story result, and next-run hooks.

Each act contains three road legs, two crossroads, a guaranteed Hearthmend stop before the boss, and one act boss. Total run content is nine road battles, six crossroads, three act bosses, and one final ascent.

### Time budget

| Beat | Target |
|---|---:|
| Initial preparation and tutorial prompts | 2-3 min |
| Each road battle | 3.5-4.5 min |
| Each crossroad and preparation | 45-90 sec |
| Each act boss | 2.5-4 min |
| Final Ascent and final boss | 6-8 min |
| Total active combat | 42-48 min |
| Median wall-clock run | 55-65 min |

Menus, crossroads, and preparation pause combat and the run timer used for balance telemetry. Pausing the game never changes the simulation.

## 10. Phase and Scope State Matrix

| System | Preparation / Crossroad | Road Battle | Act Boss | Raid | Final Ascent |
|---|---|---|---|---|---|
| Build or upgrade towers | Yes | No | No | No | Final prep only |
| Change tower doctrine | Yes | Yes | Yes | No | Yes |
| Build town / queue project | Yes | No | No | No | Final prep only |
| Change relic sockets | Yes | No | No | No | Final prep only |
| Change hero loadout | Yes | No | No | No | Final prep only |
| Use hero and abilities | No | Yes | Yes | Yes | Yes |
| Use Command orders | No | Yes | Yes | Raid orders replace them | Yes |
| Use war horn | No | Once per road | No | No | One scripted opportunity |
| Town and beast viewing | Full management | Read-only, simulation continues | Read-only, simulation continues | Hidden | Read-only |
| Battlefield simulation | Paused | Live | Live | Frozen exactly | Live |

### Why preparation is consolidated

Town management, tower upgrading, hero training, relic handling, and route review appear as tabs within one Preparation state. They are not five consecutive modal phases. The player may switch freely, compare consequences, and commit when ready. A single **Ride On** action begins combat after unresolved warnings are shown.

## 11. Scope Navigation and Camera

The mouse wheel forms one consistent spatial ladder.

**Zooming out:** Battlefield Detail -> Battlefield Wide -> Town -> Beast Side Profile.  
**Zooming in:** Beast Side Profile -> Town -> Battlefield Wide -> Battlefield Detail.

### LOCKED behavior

- Battlefield zoom interpolates smoothly within its allowed range before crossing a scope boundary.
- The last battlefield zoom and camera offset are restored when returning.
- Town and Beast scopes preserve their last focus.
- A visible scope rail communicates the current level and adjacent destination.
- Controller triggers and keyboard keys provide identical navigation.
- When a scrollable modal has focus, the wheel scrolls the modal rather than changing scope.
- During live combat, Town and Beast views are read-only and time continues. Lane-pressure edges, boss warnings, and the **Return to Battle** action remain visible.
- Scope transitions never move simulation geometry. They animate only the presentation camera and interface.
- Camera motion, battlefield gait, zoom smoothing, screen shake, and flashes each have accessibility controls.

## 12. Victory, Defeat, and Recovery

### Victory

The player wins by defeating the Chainmaker at the summit while the Town Hall remains standing. The result screen awards Tools, one Sigil until the Legacy cap is reached, eligible unlocks, and run records.

### Town defeat

Town Hall HP reaching zero ends the run immediately. The debrief explains the final breach, road, damage source, economy, build, and unlocked payout.

### Hero wounds

Hero failure uses a wound system so risk matters without allowing one unreadable mistake to erase an hour.

- A lethal hit downs the hero for 8 seconds `[TUNE]`.
- If the Town Hall survives, the hero revives at 50% HP and gains one Wound.
- Each Wound reduces maximum HP by 10% for the remainder of the act `[TUNE]`.
- A third lethal down ends the run.
- Hearthmend removes all Wounds before each act boss.
- A rare Resurrection Draught prevents the next lethal down, restores 40% HP, and is consumed. Carry limit: one.
- Boss mechanics never deal unavoidable lethal damage; telegraph and recovery rules still apply.

This system keeps Darkest Dungeon-style attrition, preserves heroic risk, and avoids making resurrection loot mandatory.

---

# Part IV - Battlefield and Combat

## 13. Battlefield Layout

The Town Hall sits at the center of a top-down battlefield. Four fixed roads approach from north, east, south, and west. Each road has three defense slots:

- **A slot:** base tower;
- **Fusion slot:** combination tower derived from A and B;
- **B slot:** base tower.

The battlefield therefore contains twelve tower slots. Fixed locations preserve lane readability, reduce placement traps, and focus choice on composition, upgrades, target priorities, and timing.

### Road pressure states

Every road reports a normalized pressure score from enemy time-to-breach, current health, role priority, projectile danger, disabled defenses, and hero presence.

- **Stable:** 0-34; muted directional marker.
- **Caution:** 35-64; amber pulse and soft audio cue.
- **Danger:** 65-84; red pulse, stronger lane audio, off-screen threat marker.
- **Collapse:** 85-100; urgent but non-spammy alert, reserved screen-edge emphasis.

Warnings have cooldowns and priorities. Four simultaneous alerts collapse into a single global emergency cue rather than audio clutter.

## 14. Hero Combat

The hero is a responsive melee fighter designed around crossing roads and converting dangerous proximity into tactical advantage.

### Baseline kit

- three-hit basic chain with movement-cancel windows;
- heavy finisher that briefly staggers non-boss enemies;
- eight-direction movement;
- dash with 0.3 seconds of invulnerability and a 4-second base cooldown `[TUNE]`;
- one Attack modifier, one Defense ability, one Power ability, and one Ultimate;
- hit reactions, buffered inputs, aim assist for controller, and generous target selection;
- no stamina bar for basic movement or attacks.

### Combat quality requirements

- Button-to-action latency is below 100 ms at 60 FPS for local input.
- Every hero attack has anticipation, contact, recoil, and recovery; cancel rules are consistent.
- Damage numbers prioritize crits, kills, and large effects; minor tower ticks aggregate to protect readability.
- The hero cannot be body-locked by normal enemies for more than 0.6 seconds without an escape option `[TUNE]`.
- Enemy contact alone does not damage the hero. Enemies attack through committed, dodgeable actions.
- Invulnerability, armor, stagger, silence, root, slow, burn, and healing each have distinct visual and audio language.

## 15. Command: The Anti-Idle Combat Loop

**LOCKED new core system.** Command is a battle-only meter earned through active hero play. It gives the player high-impact tower and lane actions without reopening construction during combat.

### Earning Command

- damage and kill priority targets while near a Caution or Danger road;
- perfect-dodge a committed attack;
- interrupt an enemy support cast;
- protect a damaged blocker or tower;
- complete a discipline-specific skill action.

Passive tower damage does not generate Command. The meter caps at 100 and resets between road battles and bosses.

### Command orders

| Order | Cost | Effect `[TUNE]` | Purpose |
|---|---:|---|---|
| Overdrive | 30 | Selected tower gains +60% attack rate and enhanced utility for 5 sec | Burst and visible payoff |
| Rally Road | 45 | Road-wide stagger pulse; allied blockers gain a shield; towers resist disable for 4 sec | Emergency stabilization |
| Last Stand | 100 | Town Hall becomes invulnerable for 3 sec; all tower attack timers reset; usable once per battle | Earned comeback, not a panic button stockpile |

Orders require a deliberate road or tower target, use large readable VFX, and never auto-cast. Their short tutorial begins in the second road, after basic hero controls are learned.

## 16. Enemy Combat Contract

Every enemy must have a readable job. New enemies are approved by role and counterplay, not by a different health value or costume.

### Universal rules

- All damaging attacks have an anticipation tell, a danger shape or directional cue, a committed action, impact, and recovery.
- Telegraph duration scales with consequence and difficulty, never below the accessibility floor.
- Elite and boss attacks do not reuse a normal tell for a different hit shape.
- Fast enemies sacrifice health or attack commitment; tanks sacrifice speed; supports sacrifice direct pressure.
- Crowd control has diminishing returns on bosses and visible resistance, not unexplained immunity.
- Enemies may attack heroes, blockers, towers, or the Town Hall according to authored roles.
- Enemy movement receives velocity-driven sway and bounce. Speed increases cadence and amplitude; mass damps bounce and strengthens footfall impact.

### Launch roster budget

Each act has four regular enemies and two regional elites. Earlier regulars can return as veterans in later acts. The shared roster creates familiarity while regional roles change the question.

| Region | Regular roles | Elite roles |
|---|---|---|
| Verdant Maw | Coalpaint Raider, Wolf Rider, Rootshield, Ember Shaman | Pack Howler, Wolf Standard-Bearer |
| Sunglass Waste | Veiled Skirmisher, Scale Rider, Glassguard, Dune Burrower | Mirage Seer, Siege Lizard |
| White Teeth | Rime Marauder, Ice Hauler, Snowhide Brute, Storm Caller | Avalanche Warden, White Maw Giant |

Production budget: 12 regular enemies, 6 regional elites, 3 act bosses, and 1 true final boss. Each requires a data resource, production sprite set, silhouette test, animations or procedural motion profile, VFX, SFX, UI icon, codex entry, wave eligibility, and automated validation.

## 17. Waves and Encounter Direction

Waves are authored formations driven by a continuous threat budget. Difficulty should change the problem, not only multiply health.

### Core formation vocabulary

1. **Measured Advance** - readable baseline.
2. **Rush** - fast low-health bodies test response and anti-runner targeting.
3. **Siege Column** - one armored road tests single-target damage and blocking.
4. **Burrower Pincer** - opposite roads plus inner-ring infiltrators.
5. **Howling Pack** - support leaders create a priority-target puzzle.
6. **Night Onslaught** - broad pressure with light suppression.
7. **Torchbreakers** - enemies target lane visibility and support structures.
8. **Caravan Guard** - a valuable carrier is protected by rotating escorts.
9. **False Front** - a small visible push precedes a delayed adjacent surge.
10. **Fourfold Oath** - late-game all-road endurance formation.

### Opening protection envelope

The beginning must teach before it tests the full build.

- Initial Preparation lasts at least 18 seconds and waits for player confirmation.
- Starting Gold and Stone can build one level-1 base tower on each road plus one meaningful upgrade or town choice.
- Wave 1 attacks one clearly marked road with 3-4 basic enemies.
- Wave 2 repeats that road and previews an adjacent threat.
- Wave 3 attacks two roads.
- Wave 4 may introduce a runner.
- Wave 5 may introduce the first support or elite; the director reaches its normal pool by Wave 8 through a smooth protection taper.
- Small opening supply pulses end after Wave 6. The late-game economy remains unchanged.
- The director cannot select Rush, Siege Column, Howling Pack, or four-road pressure until its teaching gate is satisfied.

### Escalation rules

- Threat budget resets its local wave index at each act, then applies a stronger act multiplier.
- Health scales faster than damage; sustained pressure grows without erasing dodge windows.
- Enemy speed grows modestly and primarily through roster composition.
- The final 100 distance of each act increases both body count and role complexity.
- Night increases road coverage and role danger, not simply blackness.
- Late formations become dense internally but the next wave never begins, and Preparation never opens, until the authored queue and all surviving enemies are resolved.
- The director uses anti-repeat weights and cannot create an unwinnable role combination without at least two valid counters in the player's current systems.

## 18. War Horn and Raid Charge

The war horn is a once-per-road push-your-luck action.

When blown:

- Yuri plants their feet and distance-based construction pauses;
- enemies arrive faster and gain temporary threat for 20 seconds `[TUNE]`;
- kills generate greatly increased Raid Charge;
- all future enemies in the run gain +6% HP and +4% damage `[TUNE]`;
- the battlefield, town, and audio enter an unmistakable horn state.

At full Raid Charge, battlefield enemies enter a 20-second weakened window `[TUNE]`. The player may continue exploiting the window or open the raid portal. Raid Charge does not persist between acts and cannot be hoarded after a raid opportunity.

The horn must be attractive when the player wants a relic, an Oathbound leader, or a stronger build, but never mandatory for a standard clear.

## 19. Boss Combat

Bosses are authored multi-road encounters, not oversized lane enemies. Each has an introduction, three phases, two intermissions or phase breaks, reinforcement rules, a discipline-neutral counterplay path, and a no-damage exploit test.

### Act I boss - Wolf Marshal

- Opens on a mounted charge that crosses two roads.
- Uses war cries to empower wolf packs; the hero can interrupt the caller or eliminate marked pack leaders.
- At two-thirds HP, the mount breaks a tower line and becomes independently targetable.
- At one-third HP, smoke darkens unlit roads while fire telegraphs remain high-contrast.

### Act II boss - Dune Seer

- Uses mirrored armor to redirect predictable tower volleys.
- Scale-rider charges draw long lane lines that the hero can bait away from defenses.
- At two-thirds HP, burrowers open an inner pincer.
- At one-third HP, a glass storm periodically changes projectile behavior and exposes the boss after a clean dodge sequence.

### Act III boss - Avalanche King

- Advances slowly with extreme mass while siege teams disable tower utility.
- Ground ruptures temporarily alter one road's pathing without changing slot geometry.
- At two-thirds HP, a snowstorm reduces distant contrast while warnings remain saturated and outlined.
- At one-third HP, the boss alternates Town Hall charges and vulnerable recovery.

### True final boss - The Chainmaker

- Phase 1 commands all four roads using recognizable formations from the run.
- Phase 2 chains two tower formations and forces the hero to break anchors on opposite roads.
- Phase 3 moves the hero onto a close summit arena while the town defense remains visible and Command orders bridge both layers.
- The final break frees Yuri, clears the battlefield, and transitions directly into the ending without a post-victory loot menu.

### Boss fairness rules

- New mechanics are previewed safely before becoming lethal.
- Boss reinforcements obey the live-enemy budget.
- A lethal hit cannot trigger a post-mortem phase.
- Town-targeting moves show both world-space and UI warnings.
- Boss phases are validated with every elemental family and hero discipline.
- Damage immunity cannot exceed 8 consecutive seconds except during a clearly interactive mechanic `[TUNE]`.

---

# Part V - Towers and Elemental Formation

## 20. Tower Grid and Construction Rules

All tower building, selling, element assignment, and upgrading occurs during Preparation. During combat the player may change targeting doctrine and spend Command, but cannot erase a bad commitment through mid-wave construction.

Each road's A and B slots accept any unlocked base tower. When both are built, the Fusion slot can construct the combination defined by their elements. Fusion construction costs Gold and Stone. If a parent tower is destroyed, the combination tower continues at 60% base output but loses its fusion utility until the parent is repaired in Preparation `[TUNE]`.

Selling returns 60% of Gold cost and 40% of Stone cost during Preparation `[TUNE]`. No sale is allowed during combat.

## 21. Base Towers

| Element | Tower | Primary role | Utility identity |
|---|---|---|---|
| Fire | Ember Spire | Fast single-target damage | Stacking burn rewards focus fire |
| Fire | Pyre Cannon | Slow area damage | Ground scorch controls dense packs |
| Water | Rime Lance | Precision control | Strong slow and armor exposure |
| Water | Hoarfrost Bell | Support aura | Pulsed slow, chill amplification, minimal direct damage |
| Earth | Bulwark | Blocker and taunt | High durability; buys hero travel time |
| Earth | Shard Thrower | Piercing line damage | Rewards road alignment and heavy targets |
| Air | Arc Coil | Chain damage | Punishes clustered support formations |
| Air | Gale Turret | Fast disruption | Knockback and anti-runner coverage |

Every base tower must remain useful at level 5. Support upgrades scale utility, radius, reliability, and durability rather than receiving meaningless damage-only levels.

## 22. Combination Towers

| A + B | Combination | Combat identity |
|---|---|---|
| Fire + Air | Firestorm | Chains spread burn through clustered enemies |
| Fire + Earth | Magma | Heavy hits leave persistent damaging ground |
| Fire + Water | Steam Burst | Pressure bursts knock back and expose targets |
| Water + Air | Blizzard | Chains apply chill and can freeze saturated groups |
| Water + Earth | Glacier | Durable control tower that grants road armor |
| Earth + Air | Quake | Kills and heavy impacts produce stagger rings |
| Fire + Fire | Conflagration | Large burn aura with boss-focused heat buildup |
| Water + Water | Deep Freeze | Long control windows at low raw damage |
| Earth + Earth | Bastion | Extreme blocking and road-wide damage reduction |
| Air + Air | Tempest | Very fast multi-chain fire with low per-hit force |

Same-element A and B towers also grant their road +25% element damage `[TUNE]`. Mono-element is a real build, not a failed fusion.

## 23. Tower Levels, Forge, and Doctrines

All towers have five levels.

| Tower level | Gate | Upgrade intent |
|---|---|---|
| 1 | Always | Full role is visible immediately |
| 2 | Always | Early efficiency and reliability |
| 3 | Forge Tier 1 | First mastery spike; utility scales |
| 4 | Forge Tier 2 | Strong specialization and visual evolution |
| 5 | Forge Tier 3 | Capstone behavior, not only larger numbers |

Upgrade costs rise approximately 1.6-1.75x per level `[TUNE]`. A normal successful run can fully master several towers, not all twelve. The correct late-game state contains unresolved upgrade choices.

### Targeting doctrines

- **First:** closest to the Town Hall.
- **Strong:** highest maximum HP.
- **Fast:** greatest current movement speed.
- **Special:** bosses, elites, supports, and siege roles first.

Doctrine changes are free, available in combat, persist through upgrades and scopes, and reset after the run.

### POST-LAUNCH candidate

Level-3 branching specializations are reserved for a post-launch expansion unless production finishes ahead of all 1.0 quality gates. The five-level launch set must already create complete tower identities.

---

# Part VI - Hero Mansion and Disciplines

## 24. Hero Build Structure

The Hero Mansion offers three disciplines: Blood, Holy, and Berserk. Each contains eight authored abilities or nodes, for 24 total. Disciplines can be mixed. The player never unlocks every node in one run.

### Active slots

- **Attack:** available from the beginning; modifies the basic chain.
- **Defense:** available from the beginning.
- **Power:** unlocked for the run after the Act I boss.
- **Ultimate:** unlocked for the run after the Act II boss.
- **Ascension Keystone:** one passive capstone chosen after the Act III boss for the Final Ascent.

Mansion tiers reveal deeper rows. Food trains abilities; only trained abilities can be equipped. Passives consume a doctrine slot or require a matching equipped active. Nothing becomes active merely because it appeared in an unlock pool.

## 25. Discipline Identities

### Blood - controlled sacrifice

High single-target damage, healing through committed aggression, marked prey, and temporary health conversion. Blood must never reward passive self-harm or create an infinite healing loop.

Launch node roles:

1. Hemorrhage Edge - Attack; finisher applies Bleed.
2. Red Pursuit - Attack; dash through marked targets refunds movement.
3. Sanguine Guard - Defense; converts a portion of incoming damage into a delayed recoverable wound.
4. Marrow Drain - Power; channel on a priority target to heal and generate Command.
5. Hunter's Pulse - Passive; marked support kills grant a short speed burst.
6. Open Vein - Passive; crit chance rises against isolated enemies.
7. Crimson Tempest - Ultimate; rapid area strikes with capped healing.
8. Blood Remembers - Augment; Ultimate consumes marks for a final burst.

### Holy - protection and judgment

Shields, lane stabilization, cleanse, precise burst against dangerous roles, and town protection. Holy prevents collapse but cannot make all roads permanently safe.

1. Consecrated Chain - Attack; third hit splashes radiant damage near defenses.
2. Judgment Brand - Attack; marks an elite for amplified tower damage.
3. Aegis Step - Defense; dash leaves a brief shield field.
4. Bulwark Ward - Power; shields a selected road and cleanses one disable.
5. Vigil - Passive; perfect dodges near the Town Hall grant Command.
6. Mercy Under Fire - Passive; reviving from a down emits a non-damaging knockback.
7. Dawn Bell - Ultimate; large stagger and temporary tower haste.
8. Unbroken Oath - Augment; Dawn Bell also repairs blocker shields, not permanent tower HP.

### Berserk - momentum and crowd rupture

Movement, cleave, stagger, execute windows, and risk at low health. Berserk is spectacular but remains readable and cannot permanently stun bosses.

1. Cleaving Road - Attack; wide third hit gains force per enemy struck.
2. Chain Hook - Attack; pulls a non-boss priority target or pulls the hero toward heavy targets.
3. Iron Roar - Defense; brief armor and radial stagger.
4. Tremor - Power; ground line disrupts a dense road.
5. Rising Fury - Passive; sustained active combat increases attack speed to a cap.
6. No Ground Given - Passive; blocking a committed hit empowers the next finisher.
7. Beast's Breath - Ultimate; Yuri-assisted shockwave across a selected road.
8. Break the Host - Augment; elite kills extend the Ultimate's road effect within a hard cap.

All names and exact numbers are `[TUNE]`; the roles, slot structure, acquisition limits, and counterplay are LOCKED.

## 26. Hero Progression During a Run

- The player begins with one starter Attack and one Defense choice from a curated unlocked pool.
- Hero Mansion Tier 1 allows the first training choice before Road 2.
- Each completed road grants one offer: choose one of three affordable nodes, take Food, or reroll once through a Market service.
- Mansion tiers expand offer depth rather than granting free power.
- The run supports at most six trained nodes plus the Ascension Keystone `[TUNE]`.
- Duplicate abilities cannot appear.
- Offers respect equipped synergies while always including at least one off-discipline option.
- Respeccing is available in Preparation for a Food fee that rises per use; it is never available in combat.

---

# Part VII - Town, Economy, and Relics

## 27. Town Design

The town is a circular sanctuary built around the Town Hall. It begins compact and visibly grows, lights, scars, and repairs over the run. All nine building plots exist in the scene from the start as foundations or silhouettes, so the final form is visually promised.

Town Hall, Woodcutter, and Wheat Farm begin at Tier 1. Other unlocked buildings begin as empty plots and must be built during the run.

| Building | Launch function |
|---|---|
| Town Hall | Town HP, relic sockets, project queue, central visual state |
| Woodcutter | Produces Wood per distance survived |
| Wheat Farm | Produces Food per distance survived |
| Forge | Unlocks tower mastery Levels 3-5 and improves repair efficiency |
| Hero Mansion | Reveals and trains hero discipline nodes |
| Scavenger Lodge | Assigns an Oathbound leader for one run-long specialist perk |
| Treasury | Enables a capped one-run resource cache through Legacy progression |
| Trading Market | Converts currencies at a loss and sells one rotating service per act |
| Watchtower | Forecasts formations, road threats, and hidden rewards by tier |

### Building rules

- One construction project is active at a time.
- Projects advance only through distance Yuri travels during road battles.
- A queued project and its expected completion road are always visible.
- Building tiers reset every run.
- Core production buildings have three tiers. Town Hall has four in-run tiers. Advanced buildings have one to three tiers according to their function.
- Damage creates visual scars and may suppress a building, but does not permanently delete it.
- Repairs compete with new growth and tower mastery.
- Every tier changes the town silhouette, lighting, activity, or animation.

### Account unlock timing

- Scavenger Lodge enters the permanent construction pool after the first successful Oathbound recruitment.
- Treasury enters after the first Act I boss defeat.
- Trading Market enters after the first Act II boss defeat.
- Watchtower enters after the first Act III boss defeat.

These unlock content and decisions. They do not arrive as fully built permanent power.

## 28. Economy

Each currency has one primary job and limited secondary uses.

| Resource | Persistence | Primary sources | Primary sinks |
|---|---|---|---|
| Wood | Run | Woodcutter, provision roads, trade | Town construction and Town Hall repair |
| Food | Run | Wheat Farm, provision roads, trade | Hero training, respec, raid recovery |
| Gold | Run | Enemy kills, road rewards, bosses | Base towers and tower upgrades |
| Stone | Run | Armored enemies, elites, road rewards | Fusion towers, blockers, tower repair |
| Command | Battle | Active hero mastery | Tactical orders |
| Tools | Account | Run performance, challenges | Horizontal content and cosmetic unlocks |
| Sigils | Account, capped | True final boss clears | Four bounded Legacy ranks |

Relics, Resurrection Draughts, tower blueprints, and Oathbound leaders are items or unlock IDs, not currencies.

### Economy guardrails

- The initial cache covers four level-1 base towers and one meaningful flexible choice.
- Early supply pulses prevent an opening deadlock, then end before the economy is solved.
- A Standard run cannot fully upgrade every tower, every building, and every hero option.
- Kill income is frequent for feedback but fractional enough that dense waves do not finance the entire run.
- Passive income depends on distance, so horn use and breaches have opportunity cost.
- The Market trades at an explicit loss and has per-preparation limits.
- Emergency repair is a comeback sink, not a profitable loop.
- Unspent run currency has only the capped Treasury use; it is not converted freely into permanent power.

## 29. Relics

Relics provide build-shaping rules, not invisible minor stat soup.

### Launch content

- 24 regional relics: eight Verdant, eight Sunglass, eight Rimebound.
- 3 act Boss Cores, always active for the remainder of the run.
- Regional color identifies origin, not rarity.
- Rarity uses frame shape and icon treatment so colorblind players receive the same information.

### Socket rules

- Relics act only while socketed in the Town Hall.
- Town Hall in-run tiers provide 1 / 2 / 3 / 4 sockets.
- Legacy Rank 4 adds one starting socket but never raises the in-run maximum above four.
- Relics may be rearranged only in Preparation.
- Duplicate relics do not drop within one run.
- Boss Cores are unsocketed, cannot be sold, and end with the run.
- A relic must change a decision, counter a threat, or enable a synergy. Pure +5% filler is CUT.

### Regional identity

- Verdant relics favor healing limits, burn, support interruption, and living defenses.
- Sunglass relics favor movement, projectiles, crit timing, and risk-reward trades.
- Rimebound relics favor armor, control, wounded play, and boss endurance.

Relics from earlier acts remain equipped but stop dropping after their region. This makes the route leave a visible build history.

---

# Part VIII - Roads, Raids, and Oathbound Leaders

## 30. Crossroads

Crossroads occur after Road 1 and Road 2 of each act. Two road cards are shown from an authored pool. The choice changes the next road battle; the act's regional identity remains fixed.

Every card shows:

- road archetype and difficulty;
- expected travel distance and combat duration;
- formation or role modifiers;
- known reward categories;
- unknown reward count, revealed by Watchtower tiers;
- a concise consequence sentence, never lore-only text.

### Road archetypes

| Archetype | Promise | Cost |
|---|---|---|
| Provision Route | Wood, Food, or flexible recovery | Lower rare-item chance |
| Relic Hunt | Guaranteed regional relic choice | Strong regional modifier |
| Chieftain Trail | Guaranteed full Raid Charge opportunity | Elite-heavy formations |
| Long March | More distance and construction progress | Longer battle and higher attrition |
| Swift Passage | Short, focused road | Less income and construction progress |

### Difficulty tiers

- **Guarded:** reduced threat; one standard reward.
- **Contested:** baseline threat; two reward rolls.
- **Perilous:** an explicit dangerous modifier; three reward rolls and one upgraded choice.

The highest tier may guarantee an Oathbound leader opportunity, but never guarantees a specific build solution. Card comparisons use icons plus short text and expose exact numerical modifiers in an optional detail panel.

### Hearthmend

A Hearthmend stop appears before every act boss and is not part of the random road pool. It removes hero Wounds, restores hero HP, and repairs a bounded amount of Town Hall damage. The player chooses one enhanced service: extra town repair, one free respec, or a temporary boss preparation boon `[TUNE]`.

## 31. Raid

Raid is a short push-your-luck arena entered from a full Raid Charge window. The battlefield freezes exactly, including projectiles, timers, waves, effects, construction, and boss state. It resumes from the same simulation state on return.

### Raid sequence

1. Enter a compact surround arena with a distinct regional camp.
2. Fight escalating groups while a visible extraction clock advances.
3. At 25 and 50 seconds, accept an extraction window for partial rewards `[TUNE]`.
4. Refuse both to summon the regional chieftain around 70 seconds.
5. Defeat the chieftain before the 90-second hard limit for the full reward `[TUNE]`.

### Outcomes

- Early extraction: keep earned resources and a partial relic roll.
- Chieftain victory: choose one regional relic and one leader resolution.
- Hero down: immediate ejection, no relic, one Wound, Raid Charge lost.
- Timer expiry: forced extraction with earned resources but no leader.

### Leader resolutions

The defeated chieftain is a person with agency. The player chooses:

- **Accept Oath:** leader joins the Scavenger Lodge for this run and grants a specialist perk.
- **Ransom:** immediate Gold, Food, or a regional road reveal.
- **Take Standard:** a one-run trophy effect with no character assignment.

Oathbound leaders reset after the run. They do not become permanent loyal labor. Three launch specialist families cover economy, tower support, and road intelligence, with regional variants in data.

## 32. Beast Scope and Yuri

The Beast Side Profile is both spectacle and strategic information. It shows Yuri's gait, the town silhouette, scars, current weather, distance to the next stop, act and summit progress, boss foreshadowing, active construction, and travel speed.

### Yuri's gameplay state

Yuri has one mechanical state: travel speed.

- Breaches and major town damage reduce speed.
- Repairs, Hearthmend, and selected road rewards restore speed.
- Speed has a 0.5 floor `[TUNE]` to prevent a death spiral.
- Slower speed reduces construction and passive resources because both depend on distance.
- The war horn temporarily stops speed at zero while combat continues.

Yuri does not have a second combat health bar, mood bar, hunger bar, or bond grind in 1.0. Character is expressed through animation, sound, story reactions, and the world's response.

---

# Part IX - Meta-Progression and Replay

## 33. What Resets

At the end of every run, the following reset:

- town building tiers, damage, projects, and production;
- tower builds, levels, doctrines, and fusion formations;
- Wood, Food, Gold, Stone, and Command;
- hero abilities, Wounds, stats, and Ascension Keystone;
- relics and Boss Cores;
- road state, act state, horn escalation, and Raid Charge;
- Oathbound leaders and raid rewards.

## 34. What Persists

The account save contains:

- unlocked tower, relic, hero-node, road-modifier, building, cosmetic, codex, and difficulty IDs;
- Tools balance;
- Sigils and Legacy Rank, capped at four;
- one capped Treasury cache for the next run;
- achievements, challenges, run records, aggregate statistics, tutorial flags, and settings;
- save version and migration metadata.

No uncapped stat bonus, hero level, building tier, captive level, or automatic damage growth persists.

## 35. Tools and Unlock Philosophy

Tools unlock horizontal possibility:

- alternate tower blueprints within the eight launch identities;
- additional discipline nodes and relics added to offer pools;
- road modifiers and optional challenges;
- cosmetics, town history marks, codex entries, and music layers.

The starter pool contains a viable answer to every launch enemy role. Unlocking content must not make the pool strictly worse through dilution; offer logic uses tags, prerequisites, and protection rules.

## 36. Sigils and Legacy Rank

The true final boss awards one Sigil per completed run until the account has earned four. Four clears expose the complete bounded legacy, replacing the draft's ten-clear requirement.

| Rank | Legacy effect |
|---:|---|
| 1 | Choose one modest starting supply bundle |
| 2 | Reroll one crossroad pair per run |
| 3 | Treasury may carry up to 120 total run-resource value into the next run `[TUNE]` |
| 4 | Start with one additional Town Hall relic socket; maximum remains four |

Treasury resources replace the previous cache rather than stacking. Starting a run consumes the cache. Abandoning before the first completed road restores it; later defeat does not. The Treasury never stores relics in 1.0 because persistent build-defining relics would distort early balance and create a best-in-slot grind.

## 37. Difficulty and Long-Term Challenge

- **Story:** 75% threat budget, more generous telegraphs, full story and unlock access. Awards Tools; first clear awards one Sigil.
- **Standard:** intended balance and primary review target.
- **Veteran:** unlocked by a Standard clear; +20% threat budget and authored elite modifiers `[TUNE]`.
- **Cataclysm:** POST-LAUNCH unless all 1.0 gates pass; modular difficulty oaths and leaderboards remain out of launch scope.

Difficulty never changes enemy telegraph shapes, control responsiveness, or accessibility settings. Higher difficulty increases simultaneous decision pressure and role combinations before resorting to raw damage.

---

# Part X - Presentation and Game Feel

## 38. Art Direction

### Visual thesis

The world is dark around the player and luminous where the player has agency. Yuri and the town carry warm, hand-built light. Enemies emerge from cool or hostile regional color. Projectiles, telegraphs, and interactable states use controlled saturation so beauty improves clarity.

### Lighting and shadows

- Nights are deeper, cooler, and higher contrast than day.
- Contact shadows are firm beneath characters and towers; cast shadows lengthen with time and terrain.
- Hero, enemy, and projectile silhouettes remain readable at the darkest supported setting.
- Telegraphs are emissive and outlined; no shadow may hide a lethal boundary.
- Torch loss changes mood and threat readability through peripheral darkness, not full information removal.
- Ambient foliage receives wind, weather, projectile light, and Yuri's gait in separate low-cost layers.

### Motion

- Battlefield gait is camera-only: subtle elliptical sway and fractional tilt driven by Yuri's speed and settled during the horn.
- Enemy walk sway and bounce derive from actual velocity and mass.
- Towers use anticipation and recoil appropriate to projectile weight.
- Town buildings animate work, damage, repair, and completion.
- Boss phase changes alter silhouette, animation cadence, arena light, and music.
- Reduced Motion disables gait, large recoil, repeated zoom pulses, and nonessential parallax without removing gameplay information.

## 39. VFX and Juice Grammar

Juice communicates state first and celebrates mastery second.

### Projectile anatomy

Every projectile family has:

1. launch anticipation and muzzle response;
2. a readable core silhouette;
3. element-specific trail and secondary motes;
4. impact flash sized to actual area;
5. ground or target reaction;
6. audio transient with distance and priority mixing.

Fire uses hot cores, sparks, ember ribbons, and lingering scorch. Water uses sharp pale cores, mist, frost fracture, and clean slow rings. Earth uses heavy silhouettes, debris, dust shadows, and low-frequency impacts. Air uses forked filaments, brief afterimages, and crisp chain arcs. Hostile projectiles use a distinct red-orange danger family and never resemble collectible rewards.

### Impact hierarchy

- **Tier 1:** basic hits; tiny flash, minimal shake.
- **Tier 2:** crits, freezes, elite breaks; stronger hit-stop, burst, and sound.
- **Tier 3:** Command orders, Ultimates, tower mastery, boss phase breaks; authored camera, light, particles, and music accent.
- **Tier 4:** act boss and true final defeats; unique sequence with strict duration and skip rules.

Repeated effects obey flash, shake, audio-voice, decal, and live-particle budgets. More particles are not a substitute for better timing and shape.

## 40. Audio Direction

### Music

- One adaptive score family per region plus Town, Raid, boss, and summit layers.
- Road music adds percussion with lane pressure and role intensity.
- Horn state introduces a recognizable rhythmic layer.
- Boss phases transition on authored musical bars where practical.
- Town and Beast scopes soften combat layers but preserve urgent lane cues during live battle.

### Sound design

- Each element has a distinct frequency and material family.
- Dangerous off-screen events use directional cues.
- Enemy supports, burrowers, charges, tower breaks, Town Hall hits, Command-ready, raid extraction, and boss phases each have unique priority sounds.
- Minor repeated hits use voice limits and variation to prevent fatigue.
- Night, weather, Yuri's movement, and town life form a dynamic ambient bed.

### Mix priorities

1. lethal telegraph and Town Hall warning;
2. hero action confirmation;
3. boss and elite state;
4. Command and ability readiness;
5. major tower impact;
6. ambient and minor repeated combat.

Separate sliders: master, music, SFX, UI, ambience, and dialogue/barks. A night-mode compression option and mono-audio compatibility are required.

## 41. UI and Readability

### HUD hierarchy

- Town Hall HP and hero HP are always visible in combat.
- Four-road pressure surrounds the town or battlefield edge and preserves cardinal mapping.
- Current resources, Command, abilities, horn, Raid Charge, distance, wave intent, and construction show without overlapping the playfield center.
- Upcoming formation information scales with Watchtower tier.
- Boss HP and phase mechanic replace nonessential HUD layers during bosses.

### Interaction rules

- Hover and controller focus show cost, effect, comparison, prerequisites, and resulting resource balance.
- Disabled actions explain why.
- Destructive changes such as selling or replacing a relic require one confirmation, not repeated modal friction.
- All important states use icon, shape, text, and color where space permits.
- Tooltips use player language first and exact numbers in an expanded view.
- The game can be played at 1280x720 without clipped critical UI and scales cleanly through ultrawide displays.

## 42. Accessibility

Required for 1.0:

- full key rebinding and controller remapping;
- separate camera shake, beast gait, motion, hit-stop, flash intensity, and damage-number controls;
- scalable UI and text, readable at 200% where layout permits;
- colorblind-safe element and rarity iconography;
- high-contrast telegraphs and enemy outlines;
- hold/toggle options for repeated actions;
- aim assist and target cycling;
- Story difficulty and independent telegraph-duration assist;
- subtitle and bark text with speaker labels;
- mono audio and directional threat indicators;
- pause during offline play, including during hero combat;
- tutorial replay, codex, and glossary.

Accessibility assists do not disable achievements except explicitly competitive post-launch modes.

---

# Part XI - Onboarding, Data, and Technical Quality

## 43. Onboarding

The first run teaches through the opening protection envelope.

1. Beast-to-town-to-battlefield scope ladder.
2. Build one base tower and explain roads A/Fusion/B.
3. Move, basic attack, dodge, and committed enemy telegraph.
4. Read road pressure and cross to assist.
5. Upgrade or build the remaining roads with the starting cache.
6. Introduce Command on Road 2.
7. Introduce the war horn and optional raid after the player has stable defenses.
8. Introduce the first crossroads with exactly two fully explained cards.
9. Introduce hero discipline training before the first boss.

Tutorial prompts pause only when an input or irreversible choice is required. Every prompt can be dismissed, reviewed, or disabled. Returning players receive contextual reminders only for unseen systems.

## 44. Data and Architecture Contract

- Every tower, combination, enemy, boss, wave archetype, terrain, road modifier, relic, hero node, building, leader, reward, and difficulty modifier is data-driven.
- All `[TUNE]` values live as named values in `Balance.gd` or data resources according to scope.
- `RunState` is the source of truth for the run.
- `MetaState` stores only the persistent schema in Section 34.
- Systems communicate through typed events, not cross-scope scene references.
- Player-facing strings are data or localization keys, never embedded in gameplay conditionals.
- Stable IDs survive renaming and save migration.
- Randomness is seedable for QA and debrief reproduction.
- The battlefield is suspendable as one deterministic unit for raids and pause.
- Live enemies, projectiles, decals, lights, particles, and audio voices have hard budgets and graceful degradation.

## 45. Save, Recovery, and Versioning

### Save points

- account progression saves after every unlock transaction and completed run;
- run continuation saves at the beginning and end of Preparation, at crossroads, after bosses, and on clean quit;
- combat is not continuously save-scummed; continuing resumes at the last safe preparation checkpoint with deterministic road state;
- a checksum and backup protect against corruption;
- failed migration preserves the old file and offers a clean recovery path.

### v3-to-v4 migration

- retain settings, statistics, and compatible unlocked IDs;
- map removed IDs to documented replacements or refund their Tools value;
- initialize Sigils and Legacy Rank conservatively from recorded full clears, capped at four;
- remove run-only fields mistakenly persisted by older builds;
- version every schema and test migration from all public release versions.

## 46. Launcher and Release Delivery

- Releases are exported by CI from an immutable version tag.
- The launcher checks the public release endpoint, validates status and file metadata, downloads to a temporary file, verifies integrity, then swaps versions recoverably.
- A failed update leaves the previous playable version intact and presents a human-readable retry path.
- Release metadata, launcher endpoint, artifact names, checksums, and game version are validated together before publishing.
- Stable and optional preview channels may exist, but a client never sees an asset it cannot download.
- The game displays its semantic version in Settings and the debrief diagnostics panel.

## 47. Performance Budgets

Exact hardware specification is an OPEN publishing task; the following runtime gates are LOCKED.

- 60 FPS at 1080p on minimum spec during the authored worst-case wave.
- 16.6 ms frame budget with no recurring gameplay hitch above 33 ms.
- Hard live-enemy and queued-spawn caps preserve authored threat through role substitution rather than runaway counts.
- VFX pooling and culling never remove telegraphs, hostile projectile cores, or Command targeting.
- Scope transitions complete without loading screens.
- Save and checkpoint operations remain below 100 ms on target storage `[TUNE]`.
- A 30-minute soak produces no unbounded node, signal, texture, particle, or audio growth.

## 48. Analytics and Balance Evidence

Local run telemetry records:

- elapsed combat and planning time;
- resources earned, spent, and left;
- towers built, upgraded, sold, disabled, and lost;
- hero ability and Command use;
- road pressure, travel time, breaches, Town Hall damage, Wounds, and cause of defeat;
- formations, enemies, elite roles, bosses, raids, extractions, and horn use;
- relics, disciplines, roads, and difficulty;
- frame-time and live-entity peaks.

Telemetry is shown in the defense debrief and can be exported voluntarily. No network analytics SDK is required for 1.0. Personal data is not collected.

---

# Part XII - Content Budget and Production Plan

## 49. Launch Content Budget

| Content | 1.0 count |
|---|---:|
| Regions | 3 + final summit |
| Road battle maps | 3 regional foundations with authored variants |
| Regular enemies | 12 |
| Regional elites | 6 |
| Act bosses | 3 |
| True final bosses | 1 |
| Base towers | 8 |
| Combination towers | 10 |
| Tower levels | 5 |
| Hero disciplines | 3 |
| Hero nodes | 24 |
| Regional relics | 24 |
| Boss Cores | 3 |
| Town buildings | 9 |
| Oathbound leader families | 3 with regional variants |
| Wave formations | 10 |
| Road archetypes | 5 |
| Difficulties | 3, with Cataclysm post-launch |
| Endings | 1 full ending plus defeat debrief variants |

Counts are budgets, not invitations to add filler. If a piece does not meet role, clarity, and quality gates, improve it before adding more.

## 50. Current v3 Baseline to v4 Delta

The current documented build already provides a strong technical and presentation base: four scopes, twelve tower slots, ten combinations, five tower levels, targeting doctrines, tactical formations, multi-phase act bosses, hero combat, raids, wheel scope navigation, gait, lighting and projectile polish, debrief telemetry, complete v3 asset coverage, and automated balance/release tests.

The v4 production delta is a deliberate redesign in the following areas:

- replace the provisional three-region story with Yuri, the Chainbound Host, three authored regional factions, and the summit finale;
- consolidate management into Preparation and lock building/upgrading during combat;
- add Command orders so battle remains active after towers stabilize;
- replace the single pooled economy with Wood, Food, Gold, and Stone roles plus bounded Market exchange;
- expand the town to nine buildings and add account unlock timing;
- replace the eight-spell pool with the 24-node Blood/Holy/Berserk structure;
- implement hero Wounds, Hearthmend, and Resurrection Draught;
- replace terrain crossroads with fixed regional acts and road archetype/difficulty choices;
- reframe captives as Oathbound leaders, ransom, or standards;
- expand enemy content from the v3 breed/elite budget to 12 regulars and 6 regional elites;
- rebuild act bosses to match the new world and add the true final boss;
- regionalize 24 relics and preserve three Boss Cores;
- add Tools, four capped Sigil Legacy ranks, Treasury cache, and the v4 save migration;
- complete controller parity, accessibility, audio, onboarding, localization readiness, and release hardening.

## 51. Production Milestones

### M0 - Design lock and benchmark

- [ ] Owners approve v4 pillars, run length, reset rules, Command, economy, Wounds, Oathbound framing, and summit ending.
- [ ] Capture current v3 Standard balance and performance baseline.
- [ ] Confirm final visual references and narrative naming owner.
- [ ] Convert every production checklist item into an issue with owner and acceptance criteria.

**Exit gate:** no unresolved core-loop decision and no undocumented competing GDD.

### M1 - Run-state and preparation foundation

- [ ] Implement explicit Preparation, Road Battle, Boss, Raid, and Final Ascent states.
- [ ] Lock build, upgrade, relic, and hero-loadout actions outside Preparation.
- [ ] Preserve doctrine changes during combat.
- [ ] Implement four run currencies, sources, sinks, initial cache, and Market limits.
- [ ] Extend RunState and debrief telemetry.
- [ ] Implement v4 checkpoint and save migration tests.

**Exit gate:** one complete v3-content act can be played with v4 phase and economy rules without deadlock.

### M2 - Active combat and early balance

- [ ] Implement Command generation, targeting, three orders, UI, VFX, SFX, tutorial, and telemetry.
- [ ] Implement Wounds, down/revive, Hearthmend, and Resurrection Draught.
- [ ] Tune the first five waves to the opening protection envelope.
- [ ] Validate tower construction lock does not create idle combat.
- [ ] Audit every enemy and boss attack against the telegraph contract.

**Exit gate:** new players survive Road 1 at target rate; experienced players report meaningful actions throughout an upgraded defense.

### M3 - Town, roads, raids, and meta

- [ ] Build nine-building town state and visual growth.
- [ ] Implement five road archetypes, three difficulty tiers, card comparison, and Watchtower reveal layers.
- [ ] Implement the revised raid timing and three leader resolutions.
- [ ] Implement Tools, content pool protections, four Sigil ranks, and Treasury cache.
- [ ] Verify no run-only power leaks into the account save.

**Exit gate:** two complete runs produce distinct route, economy, relic, and leader decisions without grind or runaway power.

### M4 - Hero and regional content

- [ ] Implement 24 hero nodes, slot unlocks, Mansion offers, training, respec, and Ascension Keystones.
- [ ] Produce 12 regular enemies and 6 regional elites with full data and presentation packages.
- [ ] Produce 24 regional relics and three revised Boss Cores.
- [ ] Implement ten formation archetypes and regional eligibility.
- [ ] Replace copyrighted shorthand and provisional copy.

**Exit gate:** every act asks different tactical questions and every discipline can clear Standard with multiple tower families.

### M5 - Bosses, summit, and ending

- [ ] Produce and implement three regional bosses with three phases each.
- [ ] Build the Final Ascent and Chainmaker encounter.
- [ ] Implement opening, region transitions, boss introductions, ending, credits, and skip rules.
- [ ] Complete first-clear building unlocks and difficulty progression.

**Exit gate:** the full 55-65 minute campaign closes from New Run to ending and debrief with no stub, placeholder, or dead-end state.

### M6 - Production presentation

- [ ] Finish environment variants, town tiers, damage/scar states, weather, foliage, shadows, lighting, motion, and scope transitions.
- [ ] Finish tower, enemy, boss, hero, Command, raid, and reward VFX to the impact hierarchy.
- [ ] Complete adaptive music, combat SFX, UI SFX, ambience, mix priority, and volume controls.
- [ ] Complete all HUD, controller focus, tooltips, codex, glossary, and debrief layouts.
- [ ] Remove every placeholder and orphan asset; validate manifests and import settings.

**Exit gate:** blind footage reads correctly without narration and every major action has authored audiovisual response.

### M7 - Release candidate

- [ ] Complete key rebinding, controller parity, accessibility matrix, UI scaling, and colorblind verification.
- [ ] Complete localization extraction and pseudo-localization layout pass.
- [ ] Pass load, save migration, pause, raid suspension, seed reproduction, soak, performance, asset, balance, and launcher tests.
- [ ] Verify clean install, update, rollback, offline launch, corrupt download, and interrupted download paths.
- [ ] Complete store assets, trailer capture, legal notices, privacy statement, credits, and final title clearance.
- [ ] Run structured onboarding, first-clear, and expert balance playtests.
- [ ] Fix all severity-1 and severity-2 defects and document accepted lower-severity risks.

**Exit gate:** signed release checklist, recoverable update, no known blocker, stable 60 FPS target, and complete production content.

## 52. Release Acceptance Checklist

### Core loop

- [ ] Splash -> Menu -> New Run -> all scopes -> three acts -> summit -> win/lose -> payout -> Menu works in one uninterrupted session.
- [ ] Every irreversible choice is previewed and every failure has a recovery or clear consequence.
- [ ] Standard can be cleared from a fresh account without a specific unlock or lucky relic.
- [ ] Acts II and III still demand spending, movement, targeting, Command, and route decisions.

### Balance

- [ ] The opening protection envelope meets survival targets without flattening later difficulty.
- [ ] No road begins before the player can fund basic four-road coverage.
- [ ] No winning build idles for more than the target interval.
- [ ] No tower, discipline, relic, or road choice dominates winning telemetry.
- [ ] Bosses are clearable with every elemental family and discipline.
- [ ] Story, Standard, and Veteran have distinct tested audiences.

### Content and presentation

- [ ] All launch content meets the asset manifest, silhouette, animation, VFX, SFX, UI, data, codex, and test package.
- [ ] Night remains moody and fully playable at minimum brightness.
- [ ] Projectiles and telegraphs remain identifiable under maximum effect load.
- [ ] Yuri's movement is felt without moving gameplay geometry or causing discomfort.
- [ ] No copyrighted placeholder terminology or unreviewed enslavement language ships.

### Reliability

- [ ] No error or warning on cold project load and automated test runs.
- [ ] Save migration succeeds from every public version and never destroys the source save.
- [ ] Raid pause resumes the exact battlefield state.
- [ ] All scope routes work in both directions with mouse, keyboard, and controller.
- [ ] Launcher never advertises an artifact it cannot download and never removes the last playable install on failure.
- [ ] The final tagged release passes clean-install and update tests on a machine without developer tools.

## 53. Kill Questions

Each milestone ends with an honest kill question. A no answer blocks expansion.

1. **Core:** Is choosing where the hero goes more important than simply maximizing damage?
2. **Preparation:** Do pre-battle commitments create anticipation without making a lost road feel predetermined?
3. **Activity:** Once a defense stabilizes, do Command, roles, bosses, and routes keep the player meaningfully engaged?
4. **Economy:** Does every resource force a distinct choice through the summit?
5. **Identity:** Does one screenshot unmistakably communicate a town defending itself on a walking beast?
6. **Run:** Does the final ascent feel like the necessary climax rather than a fourth act attached to the end?
7. **Replay:** Does a new run promise a different plan rather than an obligation to grind permanent power?
8. **Release:** Would the team be comfortable letting a paying stranger experience every path without explanation or developer recovery tools?

---

# Part XIII - Scope Boundaries and Open Items

## 54. Explicitly Out of Scope for 1.0

- multiple heroes, party roster, or hero swapping;
- multiplayer, PvP, co-op, leaderboards, daily online challenges;
- endless mode;
- mobile or console launch builds;
- light and dark tower elements;
- level-3 tower specialization branches;
- relic set crafting or a synergy altar;
- procedural battlefield layouts or freeform tower placement;
- persistent Oathbound leaders or captive leveling;
- uncapped permanent stats, idle resources, or live-service economy;
- Cataclysm modular oaths unless all 1.0 gates are already complete;
- runtime-generated art, dialogue, or balance;
- more regions before the existing three and summit meet quality gates.

## 55. Remaining Open Production Items

These do not alter the core design.

1. **Final product title and legal clearance.** Owner: publishing. Due before store page submission.
2. **Final names and copy edit for factions, bosses, summit, and hero nodes.** Owner: narrative. Due before localization lock.
3. **Minimum and recommended PC hardware.** Owner: engineering/QA. Due after M6 worst-case profiling.
4. **Pricing and launch window.** Owner: publishing. Outside gameplay design.

No core loop, economy, run reset, scope, tower, raid, or hero structure remains OPEN.

---

# Part XIV - Reconciliation and Changelog

## 56. Direction from v1 Through v4

### v1 contribution

v1 established the irresistible image: a settlement on a giant beast, four scopes, distance-based construction, crossroads, a war horn, raids, hero wounds, and dark expedition tone. It also left the win condition, resets, scope, and several ethically and commercially risky systems unresolved.

### v2 contribution

v2 supplied discipline: a true end, a target run length, the central four-road thesis, visible pressure, a deliberately small town, fusion, readable scope limits, and unlock-pool progression. Its strongest lesson remains that a system must serve triage and fit a small team's production reality.

### v3 contribution

v3 restored owner priorities and became the current playable foundation: twelve tower slots, ten combinations, five tower levels, live placement, telegraphed enemy attacks, raids that pause the battlefield, captives in data, six buildings, full menus, saves, and a closing run loop. Subsequent production passes added opening protection, much harder late acts, target doctrines, tactical formations, multi-phase bosses, debrief telemetry, wheel navigation, beast gait, environmental mood, richer projectiles, and complete v3 assets.

### Shared 2026 draft contribution

The shared draft gives the project its next identity: humans and regional orc war hosts, Yuri, jungle/desert/snow acts, a summit true finale, Town/Tower preparation, Wood/Food/Gold/Stone, regional relics, Hearthmend, road difficulty tiers, Treasury and Market progression, and Blood/Holy/Berserk disciplines.

### v4 resolution

v4 keeps the shared draft's stronger world and campaign while restoring the best solved decisions from v2-v3:

- the one-hero/four-road thesis is explicit and measurable;
- telegraphs remain mandatory;
- all elements are available early and all ten combinations remain;
- management is consolidated into one Preparation state;
- combat construction is locked, but doctrines and Command preserve activity;
- the run uses six crossroads, not fifteen stops;
- the final summit is playable and meaningfully different;
- currencies have distinct jobs and a bounded Treasury;
- permanent progression caps after four clears instead of requiring ten;
- hero downing uses Wounds instead of one-hit run deletion;
- leaders have oath, ransom, or trophy agency instead of permanent enslavement;
- original faction language replaces franchise shorthand;
- the production delta, content budget, acceptance gates, and cut list are explicit.

## 57. v4 Locked Decisions Summary

1. Three acts plus one final summit; median 55-65 minute complete run.
2. Nine road battles, six crossroads, three act bosses, one true final boss.
3. Four scopes with the exact wheel navigation ladder.
4. Town/tower/hero/relic changes only in consolidated Preparation.
5. Live combat remains active through hero mastery, doctrines, horn, and Command.
6. Eight base towers, ten combinations, five levels, all four elements available from run start.
7. Four run resources with distinct jobs; Tools and four capped Sigils persist.
8. Nine town buildings; building tiers reset; advanced construction pools unlock by achievements.
9. Three disciplines, eight nodes each, four active slots, one final Keystone.
10. Hero Wounds allow two recoveries; third lethal down or Town Hall destruction ends the run.
11. Raids freeze the battlefield and use two extraction windows plus a chieftain climax.
12. Leaders are Oathbound, ransomed, or represented by standards; no permanent enslavement economy.
13. Twelve regular enemies, six elites, three regional bosses, and one final boss at launch.
14. Twenty-four regional relics plus three Boss Cores.
15. Enemy telegraphs, high-contrast night readability, controlled juice, accessibility, controller parity, save migration, launcher recovery, and 60 FPS are release requirements.

---

## Final Creative Standard

*Beast Road* is finished when the player can look at four failing roads, understand exactly why each is failing, commit to the one only they can save, and turn that decision into a spectacular recovery while Yuri and the town visibly carry the cost forward.

The production goal is not maximal feature count. It is maximal clarity, pressure, personality, consequence, and payoff from the distinctive game already inside the project.
