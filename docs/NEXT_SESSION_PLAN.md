# The plan for the next session (written 2026-09-24, for Opus 5.5)

Written with the weekly budget nearly spent, so the next session starts from
decisions rather than from a re-read. **Read CLAUDE.md first** - the entries
dated 2026-09-24 are what this plan builds on. The owner's standing rules:
never run agents or workflows (ultracode or not); ask before any windowed
Godot run and run one at a time; commit before planting a fault; never edit
the tree during a sweep; never delete an inbox after importing it.

---

## 0. Where things stand

- **v0.56.3** failed its release on `ranged_check` (a once-a-frame roster
  missed a body stood up in the same frame). Fixed in `446a1a4a`.
- **v0.56.4** was tagged on that fix and will fail on `balance_test`, which had
  been red on main since the pooling and ink commits (two harness invariants
  moved by design). Fixed in `cb42e522`.
- **v0.56.5** is tagged on `cb42e522` and carries: the roster fix, the
  difficulty tune, wave formations, siege orders, and the balance amendments.
  **First thing next session: check the v0.56.5 release run.** If it is red,
  read the failing gate's log (`gh run view <id> --log-failed` needs auth;
  the step name and annotations do not - see the memory directory) and fix
  that gate before anything else. Nothing else in this plan matters while
  nothing new is live.
- The owner's brief of 2026-09-24 is triaged below into what was built (§1),
  what is yours (§2-§5), and what needs the owner (§6).

Measured on a new account after the tune (`curve_report`, `APPDATA` pointed
at an empty directory):

    mean pressure by party size   1:0.488  2:0.528  3:0.553  4:0.573
    by act   1:0.25 2:0.19 3:0.34 4:0.34 5:0.43 6:0.47 7:0.59 8:0.54 9:0.63 10:0.67 11:0.65
    band     floor 0.40, ceiling 0.64 (moved from 0.58, recorded in CLAUDE.md)

---

## 1. Built this session (do not build twice)

- **Difficulty tune**: counts +8%, health +6%, damage +2% and contact 0.62 to
  0.65, kill income 0.36 to 0.33, road trickle 0.20 to 0.18. Constants and
  rationale in `Balance.gd`, dated 2026-09-24.
- **Formations**: `WaveArchetypeData.formation` (SCATTERED / VANGUARD /
  REARGUARD), `WaveDirector._marshal_queue`, `WAVE_VANGUARD_SHARE`/`_ROLES`.
  Ten signature-led archetypes author VANGUARD, the two howler ones REARGUARD.
- **Siege orders**: `WAVE_SIEGE_ORDER_SHARE` by act (none in Acts I-II),
  `WaveDirector._order_the_siege`, `Enemy.order_siege()`, one reader
  `Enemy.targets_towers()`. Gated by `wave_library_check` (143) and
  `enemy_siege_check` (301).
- **Roster cache**: `EnemyField.roster_changed()` + a group-count key.

---

## 2. P0 for you: the portent cards (owner's screenshot)

**Report:** *"Cards need to be center aligned with proper padding and cards
need to be able to fit all texts properly without overflow ... and need to be
more juicy."* The screenshot shows three cards left-of-centre, and the flavour
line (the italic sentence after the BOON) drawn past the card's bottom edge.

**Where:** `game/scenes/ui/crossroad_screen.gd`. The portent path builds its
cards near line 1205 (`card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)`),
the title at line 863 (`"THE ROAD AHEAD  ·  read one portent"`). Read the
whole builder before touching it - the same file lays the road cards (line
918, 1060) and the two share helpers.

**What to do, in order:**

1. **Photograph first.** There is no `portent_shot`; write one following
   `road_sheet_shot`'s pattern (stand the screen up, force three offers,
   save a PNG). Every layout fix in this project that skipped the photograph
   was wrong once. Take the shot at 1920x1080 and at the phone shapes
   `layout_check` uses.
2. **Centre the row**: the cards' container wants
   `alignment = BoxContainer.ALIGNMENT_CENTER` and equal
   `custom_minimum_size` widths; check whether the row is anchored full-width
   or sized to content - the screenshot's offset says it is not centred in
   the viewport.
3. **The overflow**: the flavour text is almost certainly a `Label` placed
   after the card's `PanelContainer` rather than inside its `VBoxContainer`,
   or the card has a fixed height while the flavour label has
   `autowrap_mode` on and grows. Put it inside the card's box with autowrap,
   give every card the same height by reading the tallest, and remember
   `Control.size` is clamped to the combined minimum - a panel never shrinks
   to fit, it grows past its offsets (CLAUDE.md, the trap menu note).
4. **Juice, bounded**: a card is a `Control`, so the existing hologram
   hover/focus sweep (`ui_juice_check`, additive only) applies if the card is
   a `Button` or wears the same material. A rise on hover, a rarity-coloured
   rim, a one-shot sweep when the three are dealt (driven, never looped).
   Nothing reads a card's look; `Graphics.particle_scale` gives away any
   motes.
5. **Gate**: `layout_check` at every shape must stay green; add the portent
   screen to whatever `layout_check` stands up if it does not already open
   it (a screen nothing opens is a screen nothing measures). Add one check
   in `omen_check` or `road_card_check` that every offered card's flavour
   label rect is inside its card rect.

---

## 3. For you: the juice pass ("tastefully ultra juicy, mindful of optimisation")

The bounds every item is held to: a look and never a fact (nothing reads it),
damped by `JuiceDirector` as COSMETIC, scaled away by
`Graphics.particle_scale`, records on `VfxInk`/`BloodMotes` rather than nodes
(a hit allocates nothing - `frame_budget_check` holds it), and photographed
before it is believed. Most of the two-hundred-item juice list is already
built (`docs/IDEAS_REVIEW_2026-09-16.md`, `_2026-09-24.md`); grep for what a
system *reads* before adding one. Worth doing, in order:

1. **Wave arrival as a beat.** A VANGUARD wave now leads with its tanks; say
   so: a banner line naming the formation (`WaveArchetypeData.display_name`
   already exists), a horn sting for the leaders, a `camera_impact` at the
   spawn when a signature body steps on. `EventBus.wave_archetype_started`
   already carries the id.
2. **A body under siege orders is readable.** A small mark over a body whose
   `targets_towers()` is true and that is not a siege breed (a pick-axe
   glyph, or the tower-target ring the tells already draw). The player must
   be able to read "that one is going for my tower" - it is the whole point
   of the orders. Presentation only; `CombatTells` is the place.
3. **Tower hits felt on the board**: `Tower.hurt` already shakes and leaves
   rubble; a tower under attack by a body wants a flash on its health bar and
   the town-alert banner's rule applied (once per cooldown, named by road).
   `town_alert_check` is the model.
4. **Kill streaks and the last body**: the loot-streak pitch exists; a wave's
   last body (`Stragglers`) could carry a louder finisher and a brief slow
   (`GameSpeed.restore()` after - never write `Engine.time_scale` directly,
   `game_speed_check` walks the source).
5. **Preparation opening**: the sheet clocks exist; a soft chime at ten
   seconds and a pulse on the countdown's last three, through `Sfx.MIX`.

Do not: add `PointLight2D`s per effect (budgeted in `LightKit`), add nodes
per hit, loop a shimmer, or put a number on anything a telegraph draws.

---

## 4. For you: smarter AI, bounded

Every one of these changes the *shape* of a fight and never its size (no
damage multiplier, no new pool), and each is authored on `EnemyData` where a
breed differs. Read `enemy.gd`'s `_pick_target`/`_choose_target` wrapper and
`Wildlife.hunts_the_players` first.

1. **Focus fire on the Warden who hits them**: the grudge branch exists;
   check that a body struck from outside `ENEMY_HERO_AGGRO_RANGE` by an arrow
   or a spell turns on the shooter for a bounded window rather than walking
   on. Gate in `enemy_behaviour_check`.
2. **Shooters hold their reach**: `ENEMY_SIEGE_SHARE` steps ranged bodies
   nearer to the wall; against a Warden a HOWLER should back off when the
   Warden closes inside a fraction of its reach (kiting), once per cooldown,
   never off the road. Measure on the real field, hold the probe still.
3. **Wildlife as cover**: bodies already fight animals only when bitten
   (`_biting_back`). Leave it - the trace of 2026-09-22 showed a column
   pulled off the road is worse than a body ignoring a wolf.
4. **Bodies answer a tower that hurts them**: a body under fire from one
   tower for several seconds with no target in reach could take a siege
   order itself (`order_siege()`), bounded by the act's share. That closes
   "sit at base" further without a new system.

Do **not** build the ChatGPT "simulation LOD / spatial hash / scheduler"
items as AI work - see §7.

---

## 5. For you: housekeeping that is cheap and real

- `docs/ROAD_TO_1_0.md` has the release checklist; walk it.
- The 4K/ultrawide shapes and the phone shapes are on both bars; keep them
  green after the card fix.
- Run the pre-tag diff (CLAUDE.md, "the diff to run before a tag has three
  lines") and the full `tools/sweep.sh <scratch> release` before any tag.
- `perf_check --act=10 --build` windowed on the 180 Hz screen is the number
  that matters for "144+"; it wants the screen for ninety seconds - ask.

---

## 6. Needs the owner

- **Warden-only objectives** (`DESIGN_DIRECTION_2026-09-22.md` §2, item 2):
  a caravan to escort, a shrine to hold, an elite that must fall to melee.
  It is a content system, so it needs a bound written before code (what it
  pays, what it costs to ignore, never a power scale). Siege orders are
  built; this is the other half of "no sitting at base".
- **Fast-forward costing something** (§2 item 4): a design ruling.
- **The vanguard share and the siege share** are numbers the owner will feel
  on the next play; expect a report and move `WAVE_VANGUARD_SHARE` /
  `WAVE_SIEGE_ORDER_SHARE` rather than the code.

---

## 7. ChatGPT's 25 optimisation items, triaged against what ships

Measured facts this rests on are in CLAUDE.md's 2026-09-24 entries: at Act X
peak the frame is 17.9 ms windowed at 1080p, script about 9 ms, and the
lever is the number of things drawn, not script.

| # | Item | Verdict |
|---|------|---------|
| 1 | Simulation scheduler / staggered ticks | **Mostly built** as cadences: `ENEMY_RETARGET_SECONDS`, `TOWER_AIM_INTERVAL`, `TOWER_IDLE_RESCAN_SECONDS`, `ENEMY_HOWLER_SENSE_SECONDS`, fog 10 Hz, trample 15 Hz, `FOOTFALL_HZ`, `FLAME_REDRAW_HZ`. A central scheduler class would be a refactor for no measured gain; add a cadence where the profile names a per-frame cost. |
| 2 | Spatial hash for everything | **Not worth it now.** `EnemyField.living_bodies` gathers once a frame and `separate_crowd` already buckets; roster is 40-70 bodies, not 1,500. Revisit only if `perf_check --trace` names `enemies_near`. |
| 3 | Simulation LOD | **Refused.** Every body on this field is on a road toward the town; there is no "far" body whose AI can be abstracted without changing what arrives. Wildlife already forgets animals out of sight. |
| 4 | Flow fields for hordes | **Built** (routes are shared polylines per lane; rifts use a flow field). |
| 5 | Pooling + budgets | **Built** (`NodePool`, `VFX_INK_*_MAX`, `LOOT_FIELD_MAX`, `PROJECTILE_LIGHT_MAX`, `SHADOW_LIGHT_BUDGET_*`). |
| 6 | Fake projectiles | **Built** - no physics bodies; a shot is one node and one additive child. |
| 7 | No physics on visuals | **Built** - `VfxInk`, `BloodMotes`, records not bodies. |
| 8-9 | MultiMesh foliage, hybrid trees | **Measured and refused**: the 725 plants cost 0.4 ms (`perf_bisect --visuals`); the renderer batches texture rects already. |
| 10 | Event-driven climate | **Built** (dirty cells, band crossings only). |
| 11 | Aggregate ecology | **Refused** - the ecology *is* the field the player stands on; nothing is off-screen enough. |
| 12-13 | Staggered tower targeting, separate acquire/fire | **Built** (choice once a frame shared, idle rescan cadence). |
| 14 | Squared distances | **Built** where it matters (`enemies_near`). |
| 15 | Cache references | **Built** (`all_towers()` rebuilt on change, `Tower._lane` once). |
| 16 | Data-oriented arrays | **Built for VFX and blood**; bodies stay nodes (they are the game). |
| 17 | Threads | **Refused** for 1.0 - nothing measured is on the main thread long enough, and the gates cannot see a race. |
| 18 | Chunking | **Refused** - one field, 87 tiles a side, already culled per emitter (`ScreenCull`). |
| 19 | LOD/HLOD | n/a in 2D beyond what `ScreenCull` does. |
| 20 | Transparent overdraw | **Worth a look**: bloom, fog, veil, flood sheen stack at night. Measure with `perf_bisect --visuals` before touching. |
| 21 | Dynamic VFX scaling | **Built** (`JuiceDirector` load, `QualityGovernor`). |
| 22 | Audio priority | **Built** (voice pool, `SFX_CUTOFF`, `MIX` limits). |
| 23 | Prewarm | **Built** (`RosterWarmup.warm_act`, `warm_shaders`, `Vfx.warm_art`). |
| 24 | No spawn-all-at-once | **Built** (`WAVE_SPAWN_SPACING`, `MASS_KILL_PER_FRAME`). |
| 25 | Explicit budgets | **Built** as `frame_budget_check` + `perf_check` ledger; a written ms table would be prose that drifts. |

The honest next millisecond is renderer-side: torches and pools, particles,
the ink under load, the tells, the bars - `perf_bisect --visuals` ranked them.
