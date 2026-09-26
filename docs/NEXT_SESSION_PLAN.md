# The road to a production-ready release (written 2026-09-24 late, for Opus 5.5)

Written with the weekly budget at three percent, so the next sessions start
from decisions rather than from a re-read. **Read CLAUDE.md first**, and its
entries dated 2026-09-24 in particular. Then this file, top to bottom, and
work it in the order given: each section is ordered by what unblocks what.

**Standing rules from the owner**, none negotiable: never run agents or
workflows (ultracode or not); ask before any windowed Godot run and run one
at a time, since a window covers the owner's screen; commit before planting
a fault; never edit the tree while a sweep is running; never delete an inbox
after importing it; photograph anything a player looks at before believing a
number about it.

**How work is done here.** Every change is measured or photographed, gated
by a check on both workflow bars, and recorded in CLAUDE.md as a decision
with its reasoning. A change to a gate's invariant is recorded, never
quiet. Before any tag: `tools/sweep.sh <scratch> release`, then the
three-line guard/release/neither diff in CLAUDE.md. Tag with
`tools\release.ps1 -Version X.Y.Z`; CI builds; check the run.

---

## 0b. The content multipliers (2026-09-25, later)

The owner forwarded eight proposals; `docs/IDEAS_REVIEW_2026-09-25.md` is the
triage, and all four pieces it ordered are built, gated on both bars and
recorded in CLAUDE.md:

- **Marks** by one door (`EnemyMarks`), favoured by the weather; Nightmare and
  Hell mark a share of the road's commoners and their bosses (behaviour, never
  size) and raise the wrath floor; four new marks; speed marks finally move
  their bodies; a guest sees a body's rank and marks. `mark_rules_check`.
- **Keystone Road Cards** - five, one a hand, dealt apart on their own stream.
  `keystone_check`.
- **Wayside encounters** - six, solo only, every answer an existing door.
  `wayside_check`. **Owed**: a Guide page and a photograph of the props at play
  zoom (both need the screen).
- **Inherited coats** - a newborn wears its parents' coat, with a mutation.
  `phenotype_check`.

**Expect the owner to notice on Nightmare and Hell**: marked commoners, marked
bosses and an angrier earth from the first act. On Normal nothing moved.

## 0a. Where things stand (2026-09-25, end of day)

Built, gated and recorded in CLAUDE.md under 2026-09-25 - read those entries
before touching the phone HUD, the sheets or the touch input:

- **Taps in build mode open the menu anywhere** (tap-versus-drag on the
  sticks, and a second finger's tap). This was the owner's worst mobile bug.
  **Still owed: a check on a real phone** - the rule is gated headless, but a
  thumb's slop and timing are only measurable under a thumb. If taps still go
  missing, `TOUCH_TAP_SLOP` and `TOUCH_TAP_SECONDS` are the two numbers.
- The phone HUD: tiles, the thumb cluster under a two-column scope bar, solid
  dimmed plates, wrapping slot names, the top shade, sheets that stand the
  combat row down and carry each tower's painting, a centred title that waits
  for a sheet, the command panel as a faded meter.
- The pounce strikes and may chain or follow into a swing; the double hit in
  `_strike` is gone and ranged damage is back to 1.0 - **expect the owner to
  feel the game got harder at range and easier from cats that used to stand
  still**; both are the fix, not a tuning slip.
- Fast-forward costs a quarter of the road's pay; the wheel and the pinch zoom
  the battlefield only; a lost Walk shows a report.
- Draw calls 950 to 849-870 at Act X (the torch atlas).
- **A hovered build offer stands on its plot as a see-through ghost, playing
  its idle, inside a full circle of its reach**, and the tooltip picture plays
  the idle too; every idle loop had played its rest pose twice. Photographed on
  desktop; on a landscape phone the plot sits under the sheet.

**Open, in order:**

1. **Portrait is only the web build's, and it is still miniature** - the HUD at
   430x932 is desktop-sized type on a phone-sized screen, and DASH floats
   mid-screen because a one-column scope bar leaves no room under it. Android is
   landscape-locked, so this is the browser's problem alone. The answer is a
   portrait layout, not a scale: decide with the owner whether the web build
   should simply ask the player to turn the phone.
2. **The pool figures on a phone are small** (the HP/MP/SP bars are 16 units in
   a column that cannot grow on the portrait shape). A landscape-only taller bar
   is the likely answer; `BarName`'s header explains why a Label cannot be used.
3. **The flame tongue is a `draw_mesh` per flame**, which never batches. The
   next draw-call lever is a baked animation strip drawn as texture regions;
   photograph it against the mesh before believing it.
4. **Measure on the owner's two phones** after the tap fix: the model, the
   resolution, the act and the preset the settings screen shows.

## 0. Where things stand (2026-09-24, end of day)

- **v0.56.6 is live** (difficulty batch, formations, siege orders, the bar
  and ink conversions, the roster fix, the pinned wrath gate). **v0.56.7 is
  building** with the torch ironwork, sleeping flames, the minimap clock and
  the shared additive material. First thing: check that run. If red, read the
  failing gate (`gh run view <id> --json jobs` and the check-run annotations
  work without admin) and fix that gate before anything below.
- **Performance on this machine is done.** `perf_check --act=10 --build`,
  1080p on the 180 Hz screen, High, forty level-8 towers on Act X's waves:
  13.0 ms average (77 fps), p99 22.2, worst 35.8, two hitches in ninety
  seconds, 975 draw calls. It was 76 ms and 950 hitches a minute this morning.
  Do not spend more on this machine; every remaining row is a millisecond.
- **Conformance**: 47 of 47 automatable rows pass; four human-judgement rows
  remain (section 2). **Art**: 0 placeholders among 4,582 manifest assets by
  the magenta rule; the known stand-in is the Last Anchor's sprite.
  **Music**: 76 songs over 5 of 10 acts, 0 of 10 boss themes.
- **The difficulty re-tune has never been played.** Counts +8%, health +6%,
  damage +2% and contact 0.62 to 0.65, kill income 0.36 to 0.33, road
  trickle 0.20 to 0.18, formations and siege orders - all on `curve_report`'s
  word (solo 0.488, four players 0.573, band 0.40 to 0.64). Expect a play
  report and move `Balance` numbers, not code.

---

## 1. P0 - the one thing the owner has photographed

**Built 2026-09-25, measured headless, not yet photographed.** Every card
row centres through `CrossroadScreen._card_row`; `_fit_play_cards` sizes the
cards to the tallest face after layout, widening into the row's spare width
and then shrinking the illustration on a short screen; the cards flip in on
`scale` and lift on hover. `layout_check` deals the three wordiest portents
at five shapes and holds the words inside the cards, equal heights, a centred
row and every card on the screen; planted, it named the left-packed row (the
screenshot, 498 units of lean) and the spill. **Still owed: `portent_shot`,
one windowed photograph** - ask for the screen first.

**The portent cards** (`game/scenes/ui/crossroad_screen.gd`, cards built
near line 1205, title at 863). Off-centre, the flavour sentence overflowing
the card's bottom, no juice on the deal.

1. Write `portent_shot` on `road_sheet_shot`'s pattern and photograph first,
   at 1920x1080 and the phone shapes `layout_check` uses.
2. Centre the row: the cards' container wants
   `alignment = BoxContainer.ALIGNMENT_CENTER` and equal widths; check whether
   the row is anchored full-width or sized to content.
3. The overflow: the flavour label is either outside the card's box or the
   card has a height while the label autowraps and grows. Put it inside the
   box, equalise card heights by the tallest, and remember `Control.size` is
   clamped to the combined minimum, so a panel grows past its offsets rather
   than shrinking.
4. Juice, bounded: the hologram hover/focus sweep already on every button
   (`ui_juice_check`, additive only), a rise on hover, a rarity-coloured rim,
   one driven sweep when the three are dealt. Nothing reads a look.
5. Gate: `layout_check` at every shape stays green and opens this screen;
   one check in `omen_check` that every flavour label's rect is inside its
   card.

---

## 2. Verification - the production claim depends on it

Nothing here is code. Each is one reading, and the claim is only true once
all four hold sixty on Low.

1. **A weak laptop** (integrated GPU) on Low, `perf_check --act=10 --build`.
   Low was 61 ms when High was 76 because the cost was script; script is now
   about 5 ms, so Low should scale well. Unmeasured.
2. **A phone.** The Android workflow builds the APK. Low, the governor
   (`QualityGovernor`) and the light budget are built for it. Unmeasured.
3. **The web build.** Same. Web saves are per-origin.
4. **Four-player Act X.** The perf harness is solo; `tools/coop_ui.sh` and
   `coop_live_check` are the two-process harnesses. A guest should be lighter
   than the host (no AI, no waves); the host mirroring three guests is the
   unknown.
5. **A play of the difficulty tune** by the owner (section 0).
6. **The mix levels heard in play.** Every level was authored expecting to
   be audible; none has been verified by ear.
7. ~~`weapon_vfx_check` fails about once in five.~~ **Answered** (CLAUDE.md,
   2026-09-25): the first swing loaded the blade's art and the frame after the
   load outlasted the swing; a warm-up swing loads it first. Two more coin
   tosses were answered the same way on 2026-09-25 - `wildlife_family_check`'s
   courting mate and `tower_support_check`'s shaman shot. Run a gate six to
   eight times before trusting a single green.
8. **The four human-judgement conformance rows** (`run_tool.gd -- audit
   --todo`): read them for this release and record the reading.

---

## 3. Content that is missing rather than wrong

- **Music for Acts VI to X** at `music_act%02d_%02d.ogg`; seven regions also
  borrow another's battle track (`TerrainData.battle_music`).
- **Boss themes** at `music_boss_act%02d.ogg`, 0 of 10; the crossfade and the
  stinger are built.
- **Ambience recordings** for the seven regions lying under a borrowed bed
  (`TerrainData.ambience_bed`).
- **Enemy voices**: 67 breeds with `EnemyData.voice_sfx` empty; six archetype
  prompts in `docs/SFX_PROMPTS.md`. Import with `import_audio.py`, then
  `register_sfx.py`, then `--import`. Never delete the inbox.
- ~~The Last Anchor's sprite~~ - **drawn** (commit 29f74d02, with idle, walk
  and attack frames); this line was stale. Checked on a contact sheet beside
  the Chainmaker and the Cinder Titan on 2026-09-25: it belongs.
- **The Warden's chop and mine sheets**; `Hero.play_work_swing` takes one by
  name. The Warden was re-founded as a PixelLab character for the dress pilot
  (`Warden (dress pilot)`), so new states are reachable again.
- **A Guide page for mounts** (`guide_shots` needs the screen).
- ~~Idle loops for Frostpoint and the Stillwater Mirror.~~ **Painted** by
  `tools/paint_still_idle.py` (the animator returns an object at rest nearly
  still, and the lock erases what little it draws). Both towers are listed in
  `lock_tower_frames.py`'s `AUTHORED_IDLE` so the lock leaves them alone.

---

## 4. Feel and juice, each a look and never a fact

**Items 1 to 5 were built on 2026-09-25 (v0.56.9)** - the formation's horn,
the siege mark, the tower-under-attack alert with a flash on every bitten
bar, the last kill held for a hitstop beat, and the countdown ticks - and
are recorded in CLAUDE.md. Items 6 and 7 remain as written. **Also done that
day and not in this plan's first draft**: `unsafe_property_access` raised to
an error with all 199 sites resolved, and `coop_check`'s crash at quit.

Bounds for every item: read by nothing, damped by `JuiceDirector` as
COSMETIC, scaled away by `Graphics.particle_scale`, records on `VfxInk` or
`BloodMotes` rather than nodes (`frame_budget_check` holds that a hit
allocates nothing), photographed before believed. Most of the forwarded
juice lists are already built - grep for what a system reads before adding.

1. **A wave arriving as a beat**: the formation's `display_name` on the
   banner (`EventBus.wave_archetype_started` carries the id), a horn sting
   for the leaders, a `camera_impact` when the signature body steps on.
2. **A body under siege orders readable**: a mark in `CombatTells` for a body
   whose `targets_towers()` is true and that is not a siege breed.
3. **Tower hits felt on the board**: a flash on the tower's bar and the
   town-alert rule (once per cooldown, named by road) for a tower under
   attack; `town_alert_check` is the model.
4. **The last body of a wave** (`Stragglers`): a louder finisher and a brief
   slow through `GameSpeed` - never write `Engine.time_scale` directly.
5. **Preparation's clock**: a chime at ten seconds, a pulse on the last
   three, through `Sfx.MIX`.
6. **The deferred second rank** (owner, 2026-09-15): persistent footprints,
   boss entrance behaviours, post-battle settling, anticipation audio on the
   telegraphs. Content, not systems; build after 1 to 5 have been played.
7. **Bodies shaded by light direction**: towers wear `actor_polish` with
   `shade_strength`; rolling it to bodies is one uniform a kind and a
   decision (section 6).

---

## 5. Performance - only after section 2 says where

Measured and ranked on this machine (`perf_bisect --visuals`, held Act X):

    towers 1.1 ms   embers 0.56   flame_tick 0.31 (now sleeps)
    flame_tongue 0.26   flame_halo 0.17   everything else at noise

1. ~~**The towers**~~ **Split, 2026-09-25**: tick 0.35 ms, light 0.28, glow
   0.15, aura 0.04, the relief shader 0.01. Not the shader; no lever.
2. ~~**The embers**~~ **Built, 2026-09-25**: a ring of packed arrays on the
   additive ink, photographed with `torch_shot --close`.
3. **Draw calls** (912 at peak after the above): the bisect prints a draw
   column now. The torches are 323 of them and the flames' tongues 135. If it
   ranks: atlas the foliage per region through Godot's texture-atlas
   import (watch edge bleed under linear filtering; photograph), share the
   per-instance shader materials on bodies, towers and loot by moving the
   per-instance value into a channel the shader reads, and render the flame
   tongues once into a 48-cell strip so flames batch.
4. **Ground blood**: keep the one triangle array; move the fade into a shader
   off `TIME` so `BloodField` rebuilds only when marks change. `blood_shot`
   before and after.
5. **A landscape phone's road sheet** has 76 units of room with the spirit
   readout up (section 6 decides).

---

## 6. Decisions only the owner can make - ask, do not build

- **Warden-only objectives** (`DESIGN_DIRECTION_2026-09-22.md` section 2,
  item 2): a caravan to escort, a shrine to hold, an elite that must fall to
  melee. Siege orders are the first half of "no sitting at base"; this is the
  second. A content system: its bound (what it pays, what ignoring it costs,
  never a power scale) is written before code, as spirits, the pantry,
  professions and materials each were.
- **Whether fast-forward costs something** (same document, item 4).
- **The behaviour floor**: `_commit_behaviour` holds every commitment for at
  least `ENEMY_BEHAVIOUR_SECONDS` (2.4 s), which overrides every POUNCE and
  STORE window on twenty-seven breeds. A pacing decision.
- **The landscape phone's spirit readout** stepping aside while a sheet is
  open, which softens a 2026-09-17 ruling.
- **Modular gear on the Warden's body** (`WARDEN_DRESS_DESIGN_2026-09-24.md`):
  designed and piloted, about ninety generations, weapons first. A budget
  decision.
- **The game speed button on touch layouts**: hidden for now; the column has
  no room on a landscape phone.
- **Bodies shaded by light direction** (section 4, item 7).
- **Named legendaries and Notorious elites**: refused for 1.0 on 2026-09-15;
  1.1 candidates.
- **`WAVE_VANGUARD_SHARE` and `WAVE_SIEGE_ORDER_SHARE`** are numbers the
  owner will feel on the next play; move them, not the code.

---

## 7. Release mechanics, so a tag is never lost to a stale gate

- The release bar is a superset of guard's; five judgement-heavy reports
  (`balance_test`, `curve_report`, `soak`, `perf_check`, `map_mode_play_check`)
  are release-only. **`balance_test` was red on main for a day this week
  because nothing on push runs it** - run it by hand after touching
  `LootDrop`, `Projectile`, `EnemyProjectile`, `Balance` or the wave director.
- Eight gates in this project's history were coin tosses; every one was a
  fresh seed. Any gate that stands up a run pins its seed
  (`RunState.reset(false, seed)`).
- `curve_report` reads the account; tune against an empty `APPDATA`.
- The pre-tag diff (CLAUDE.md, "the diff to run before a tag has three
  lines") over `res://tools/[a-z_0-9]+\.(tscn|gd)`.
- After a new `class_name`, run `--import` and then `git checkout project.godot`.

---

## 8. What is done and must not be built twice

Pooling (`NodePool`), dust and every hit effect as ink records, the bar as
one `_draw`, the ink ageing on its clock, the torch ironwork baked, sleeping
flames, the minimap on a clock, one additive material, the roster cache
invalidation, formations, siege orders, the difficulty tune, the band at
0.40 to 0.64, the wrath gate pinned. The 25 ChatGPT optimisation items are
triaged in CLAUDE.md's 2026-09-24 entries: fifteen already built under
other names, six refused on measurement, two not worth it at this scale,
two open (transparent overdraw at night, and the renderer rows above). Do
not rebuild a spatial hash, a simulation LOD, chunking, threads or MultiMesh
foliage without a measurement that names them.

---

## 9. Phones, measured by the owner (2026-09-24, night) - now the top of section 2

**A 2019 phone runs the game at 6 fps; a 2025 phone at 45.** Both start on
Low (`Graphics.preset_for_machine`), and Low is the floor the governor can
step to, so the old phone has nowhere to go. A seven-fold gap on one build
says the old phone is bound by something the desktop never priced: fill
rate at the screen's native resolution, and 2D lights, which cost nothing on
the 3070 Ti and dominate on a 2019 mobile GPU. The script side alone cannot
explain 166 ms a frame.

**First, three facts from the owner, before any code**: the two phone models
and screen resolutions, the act and wave the readings were taken at, and
what the settings screen says the preset is (Auto chose Low for ...).

**Then, in order, each measured on the old phone with the APK the Android
workflow builds:**

1. **Render scale.** The project stretches `canvas_items`, which renders the
   canvas at the window's full resolution; a 2019 phone at 2340x1080 pays
   for every pixel of every full-screen pass. Render the canvas at a lower
   resolution and upscale (stretch mode `viewport` on phones, or a
   `content_scale_factor` below one under a Graphics key), and measure. This
   is the single largest lever on a fill-rate-bound GPU and it is a look:
   the painterly art upscales cleanly under linear filtering.
2. **Count the full-screen passes.** Every shader with `hint_screen_texture`
   (`color_grade` with bloom, the weather veil, the flood sheen and the quake
   ripple, the fog) is a screen copy per pass on a tile-based mobile GPU.
   Bloom and refraction are already off on Low; check the rest are, and
   merge or skip what is left on the lowest rung.
3. **A rung below Low** (`Minimal`, chosen for a phone judged old by name and
   reachable by the governor): no 2D lights at all (torch pools and the
   town's pool are sprites already), `actor_polish` at `shade_strength` 0
   (it is then the engine's own formula, measured byte-identical), the
   foliage sway material off (plain sprites), fog drawing off, particles at
   their floor, blood and bloom off, the frame cap at 30. A look and never a
   fact, like every preset: not one number the fight reads moves.
4. **Physics rate on phones pinned to 60** whatever the display reports, so a
   120 Hz panel does not double the hero's tick on a CPU that cannot afford
   it (`Graphics.physics_rate_for`).
5. **Then the script side**, which on a 2019 CPU is five to eight times the
   desktop's 5 to 9 ms: the same headless profile (`perf_check --trace`)
   run on the phone build names which buckets, and the bodies' and towers'
   ticks are the ones to cadence further.

The 2025 phone gets the same headroom from every one of these, and the
governor then has a rung to step to on both.

**Built on 2026-09-25 (v0.56.8), not yet measured on a phone**: items 1, 3
and 4 above - `PRESET_MINIMAL` as the governor's floor with every light
disabled and no grade or pixel filter by default, Low and below rendering at
the logical size wherever that saves pixels, and a phone's physics pinned to
60. `governor_check` holds all of it. **What is left**: the owner's readings
on both phones with this build (models, resolutions, act, preset shown);
item 2 for the fog quad and the weather veil, which still draw on Minimal;
and item 5, the script side on the phone's CPU, once the readings say the
GPU is no longer the wall.
