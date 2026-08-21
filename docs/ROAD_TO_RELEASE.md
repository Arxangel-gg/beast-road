# Road to release

The single running list of what is left. Sessions are long and the list is
longer, so this file — not a chat scrollback — is what carries it forward.

**Rules for this file.** Tick a box only when the thing is done *and* verified by
something repeatable (a gate, a tool, a screenshot). Never tick a row because a
symbol now exists — `run_tool.gd -- audit` already measures that, and CLAUDE.md
§7 is explicit that a passing probe says nothing about whether a feature is good.
Add new work at the bottom of its section rather than rewriting the order.

Status legend: `[ ]` outstanding · `[~]` partially done, detail in the note ·
`[x]` done and verified.

---

## 0. Conformance snapshot

`run_tool.gd -- audit` — **44 / 44 (100%)**. 7 rows need human judgement and are
not counted; they are in section 4.

100% here means every automatable row's file or symbol exists *and*, for
everything closed in this pass, a gate exercises it. It does not mean the game is
finished — CLAUDE.md §7 is explicit that the audit cannot tell you whether a
feature is good, and section 3 is entirely things the audit cannot see.

Re-run it after any section below is closed; do not hand-edit this number.

---

## 1. Bugs and regressions

Highest priority: these are things that are wrong, not things that are missing.

- [x] Wave stall recovery could emit `wave_cleared` while a stationary ranged
      enemy was still attacking, opening Preparation on top of it. The watchdog
      now treats aggregate HP change as live combat and, on a genuine stall,
      resolves attackers through the normal death path before clearing. The
      180-second breather gate passes: three waves, two safe breathers.

- [x] Tower shadows anchored to the node rather than the sprite, so raising the
      sprite for y-sorting left the shadow floating. Fixed in `ShadowKit.add_contact`.
- [x] Foliage sorting over health bars. Bars now draw on their own layer above
      world content.
- [x] Foliage sorting over towers and characters. Band granularity was the cause,
      not the tower anchor: 16 bands across the whole field quantised every plant
      to its band centre, so a plant could sort up to half a band out of place.
- [x] No dash during Preparation. Dash is now allowed in every phase the hero can
      move in; attacks and spells stay combat-only.
- [x] Tower range ring not shown on selection.
- [x] Projectile art drawn diagonally, so it read as mis-rotated once turned to
      its heading. Regenerated as 96x48 horizontal bolts, tip-right; verified by
      measuring each sprite's hot pixels against its centre.
- [x] Torch glow uneven. Not a fault in any torch: light adds, and at radius 360
      with ~300 spacing the pools summed, so an isolated torch looked dim beside
      a pair. Per-torch energy came down to 1.15 so the *sum* lands where one
      bright torch used to.
- [x] No torch on the *outer* corner of a U-bend. Straights keep a clearance from
      each vertex, which left the longest arc on the road unlit; each bend now
      gets its own post on the outside of the turn.
- [x] Torch crowding. Fixed and now gated by `tools/torch_check.tscn`, which
      asserts the whole layout: minimum gap, four-road symmetry, and that no
      torch stands on the carriageway.

      Two passes were needed. A per-road filter fixed the reported case — a
      straight's end stop overlapping the corner post of the bend past it — but
      the check then caught a second one the report had not: adjacent *roads*
      putting torches 184 apart where the four final legs converge on the gate.
      A greedy field-wide filter would fix that by keeping road 0's torch and
      dropping road 1's, leaving the roads visibly unequal, so candidates are
      thinned in rotational groups instead: the k-th candidate of all four roads
      is accepted or rejected together, which makes symmetry a property of the
      algorithm rather than something to verify afterwards.

      32 torches, closest pair 212 apart, none on the road.
- [x] Enemy and foliage shadow anchors. Audited every `add_contact` caller: the
      enemy, hero and town sprites all sit at their node origin, so the
      sprite-relative fix is a no-op for them and they were never wrong. Foliage
      builds its shadow by hand and never used `add_contact`. The tower was the
      only offset caller, and it is fixed.

---

## 2. Conformance — the 8 outstanding rows

### Terrain ids (3 rows) — done

- [x] The three regions now carry v4's ids: `jungle`, `desert`, `snow` (they were
      `ashfen`, `saltglass`, `steppe`). 213 files renamed, including the audio
      beds and the raid chieftain art, which are keyed by region as well.

      `SAVE_VERSION` is 3, and `migrate_save` now *chains* v1 -> v2 -> v3 rather
      than jumping straight to the current shape, so a v1 save walks every step.
      The v3 step remaps unlocked terrain ids and passes an id it does not
      recognise through rather than dropping it — a migration that quietly
      forgets an unlock is worse than one that carries a stale string.

      `save_backup_check.tscn` was extended to prove the v2 -> v3 step and run by
      hand; it is deliberately not in CI (CLAUDE.md §1), because a discarded save
      legitimately warns and the release gate fails on any warning.

      Two traps worth remembering: a whole-word replace protects `steppehorde`
      but skips `_`-joined stems like `ambience_ashfen`, and `MusicPlayer` builds
      its track key from the terrain id — so leaving the audio unrenamed would
      have silently played the Act I theme in all three acts. Scenes had to be
      swept too; `.tres` and `.gd` alone left two `ExtResource` paths dangling.

### Meta systems (2 rows) — done, with two legacy effects outstanding

- [x] Tools. Earned by depth (per act reached, plus a victory bonus), capped, and
      spent automatically on the authored roster order at the end of a run.
      Replaces the old "one tower per act boss felled", which paid a run that
      *died* in Act III the same as one that cleared it.
- [x] Four capped Sigil ranks, one per full clear, persisted and clamped on load.
- [x] Rank 1 — starting supply bundle on every currency.
- [x] Rank 3 — Treasury may carry 120; never lowers a cap the tier already had.
- [~] Rank 4 — "one additional Town Hall relic socket" is already granted by the
      shipped `act3_cleared` bonus, which CLAUDE.md §7 names as the *only*
      sanctioned persistent power. Left on the first clear rather than the
      fourth: strictly more generous than v4, and it avoids two systems paying
      twice for the same achievement. Revisit only if the owner wants it gated.
- [x] Rank 2 — one crossroad redraw per run. Per run rather than per crossroad:
      a reroll at every fork turns the route into a shopping list instead of a
      decision. The button states the remaining count for that reason. Redrawn
      from the same `roads` stream so a seeded replay that rerolls stays
      reproducible. Tested at both edges — rank 1 grants none, rank 2 grants one
      that a redraw actually spends and cannot go negative.

Both surface on the debrief as `Tools N · Legacy rank N of 4`.

### The summit (3 rows) — done

- [x] Final Ascent route. Act III's boss now opens a short authored climb rather
      than ending the campaign. No crossroads and no fork: the journey skips its
      segment logic entirely while `is_final_ascent()`, and the boss is summoned
      by distance rather than at a segment boundary.
- [x] Kharok the Chainmaker — 16k HP, three phases, reinforcements on all four
      roads. The act→boss fallback used to index a directory listing, which would
      have handed the ascent whichever boss sorted fourth; it looks up by id now.
- [x] Summit backdrop.
- [x] Ending sequence. Lines arrive one at a time over a scrim, then the player
      chooses: keep riding into Endless, or take the debrief.

      One deliberate deviation from v4, which ends the run at the summit: the
      owner asked for Endless to continue past it, so both are offered. Ending
      the run from that screen is the *same* end as dying in Endless —
      `summit_reached` carries the win either way, so riding on and falling at
      wave ninety still files a victory.

- [x] Credits. A skippable roll over the summit art rather than on its own
      screen: the art is the last thing the player earned.

---

## 2b. The authored map (2026-08-20)

The owner's map tool now supplies the layout: `docs/beast-road-current-layout-blueprint.json`,
copied to `game/data/maps/battlefield_layout.json` and loaded at build.

- [x] 45×45 at 64 units, replacing the procedural 30×30 with four U-bends. The
      generator went, not because the bends were wrong, but because a generator
      can only make the shape it was written for — and this map **forks and
      rejoins**, which no amount of tuning a single polyline could produce.
- [x] A lane is no longer *a path*. It is a set of routes sharing corridors with
      each other and with the other three lanes. `lane_paths` keeps the shortest
      so old callers still work; enemies pick their own at spawn.
- [x] Route enumeration over a **corridor lattice**, derived rather than
      hard-coded: corridors are three tiles wide, so a run of exactly three
      across one identifies its centre line, and every junction sits where two
      centre lines cross. 49 nodes, 52 edges. Re-exporting the map does not mean
      editing a table.
- [x] Route length capped at 2× the shortest. The map's longest way in is 3.5×,
      about two and a half minutes of walking — the wave is over before it
      arrives, and it reads as a stuck enemy rather than a flanker. 3 routes per
      lane at 2752–4928 units.
- [x] Choice weighted toward shorter routes rather than uniform, so the long way
      round is a minority the player notices instead of a second clump.
- [x] Road baked from the lattice, not per route. Shared corridors would
      otherwise be drawn two and three times, compounding the tiles' alpha edges
      into a visible seam wherever routes overlap.
- [x] Border sealed to building without touching authored tiles. The blueprint
      marks the whole outer ring Background, which is buildable, and a tower
      flush against the edge draws half off the field — but the ring also carries
      the twelve spawn tiles, so only open ground is sealed.
- [x] **568 places take two towers side by side**, which is the layout's stated
      purpose for four-tile gaps, asserted rather than taken on trust.
- [x] `grid_check` rewritten. The old one asserted U-bend shape — that each road
      doubled back and was 25% longer than the straight line — which describes
      the previous design, and a check that describes the last design is worse
      than none because it goes green on a build it never looked at. It now
      verifies every waypoint of every route lands on road and every corridor
      between them is road end to end: the lattice is derived, so a centre line
      found one tile off would still produce routes that connect and look
      plausible while walking enemies through the buildable ground beside the
      road.
- [x] Torches rebuilt on the lattice: one per corridor, **every one lit**, 48
      total. The previous scheme placed a dense row per lane and then, for frame
      rate, gave only one torch in two a light — the worst of both trades, more
      sprites and less light, and exactly the reported symptom of roads lined
      with torches that were still dark. Placed in quarter-turn orbits so the
      lighting is symmetric by construction, and `torch_check` now asserts both
      that symmetry and that no torch is unlit.
- [x] Camera reframed for the 45×45 field: 0.77 → 0.52, range 0.62–1.18 → 0.38–1.00.
      At the old zoom a player at the gate could not see the junction the road
      forks at, so the choice the map is built around happened off screen.
- [x] The hero could not reach their own map. Movement was clamped with
      `limit_length` — a circle of radius 880 on a field that runs to 1440, so
      the corners were unreachable and the further a road bent from the axis the
      less of it could be defended. Bounds are rectangular now and set from the
      grid rather than authored in the scene, so they follow the map.
- [x] Preparation opening on a live enemy. The stall watchdog counts time, and
      time cannot tell a wave that is stuck from a wave that is merely long — the
      authored map's far route is nearly twice the direct one, so an enemy
      walking it tripped a 75s timeout that then opened Preparation on top of it.
      Progress now resets the clock: an enemy closing on the town is not a stall.
- [x] Enemies walking backwards, including the Act I boss. Facing followed the
      *target* only, so an enemy with nothing in reach kept whichever way it last
      fought — and on a map whose roads double back, that is a whole leg walked
      backwards. Now follows direction of travel when there is no target, with a
      deadzone so a sprite tracking a bend does not shudder between facings.
- [x] Hero facing. Was the aim vector alone, so running east with the cursor
      resting west ran backwards. Now resolved in priority order: an attack owns
      the facing for 0.35s, then movement, then the cursor. The eight authored
      frame rows are driven from the same resolved vector as the flip, or the two
      disagree the moment you walk one way and point another.
- [x] Tower projectiles 620 → 880. The camera sits further out, so the same shot
      covered less of the view per second and read as slow — and a slow shot
      leads more, so it also missed more.
- [x] Torch lights. Verified as real enabled `PointLight2D`s rather than as the
      flag meant to produce one: the flag would have passed the entire time the
      bug existed, since torches honestly reported the every-Nth rule that left
      most of them dark. All 48 checked.
- [x] Death report. The panel kept its scene offsets (−400..+400) while being
      forced to 1180 wide, so it sat 190 units left of centre with its button off
      the side of the window. Centred by a container — anchors cannot express
      "centre something whose size depends on its contents" — and Escape or the
      controller's accept now dismiss it, with the button focused on open.
- [x] Repair restores damage art. The town recomputed its stage only on
      `damaged`, so it could get worse and never better: repaired to full it
      stayed visibly ruined with its fires burning, which reads as the repair
      having done nothing. Hooked to `changed` so every route in counts, and a
      stage that improves no longer shakes the camera or plays the hit sound.
- [x] Foliage variety and idle motion. Every region now has its own shrub and
      flower alongside its plant, rock and boulder are shared, and painted plants
      sway — which they previously only appeared to. They shared the blades'
      canvas item and therefore the blades' material, whose sway weight is `UV.y`;
      a texture drawn through `draw_texture_rect` gets its V from the rect, so
      V=0 is the sprite's *top*. Every scattered sprite was swinging about its tip
      with its roots sliding across the ground. They now draw in a child item with
      the same shader inverted and its reach cut to a quarter — a shrub is a woody
      thing and should not whip like grass.
- [x] Horizontal ferns. Jungle, desert and snow now each carry a wide 64×40
      region-painted fern. They use the existing 32-band batched foliage path,
      so the added silhouette does not reintroduce per-plant draw calls.
- [x] **Hero levelling to 100 and the skill tree.** The bounded levelling system
      is complete. The original implementation reset each run; the owner ruling
      of 2026-08-20 now persists level, XP and placed attributes, capped by
      `HERO_MAX_LEVEL`. Building tiers, run currencies, relics and Oathbound
      leaders still reset. The later persistent-hero item records the migration
      and tier curve that make that amendment shippable.

      XP scales with the enemy's health rather than an authored per-enemy number,
      so an elite outpays a runner with no second table to maintain and act
      scaling carries the curve on its own. Four attributes — Might (damage),
      Vigour (health), Swiftness (movement and swing speed), Focus (command and
      spells) — at one point per level, and a skill point every five.

      Built *around* the existing discipline system rather than replacing it. The
      24 nodes, per-road offers and Food costs stay; training now also costs a
      skill point, and the trained cap grows with level (6 → 11 over a run). Two
      gates on purpose: the point is growth earned by fighting, the Food is the
      Preparation decision made against the towers. Skill points only, and the
      hero stops competing with the defence for resources; Food only, and
      levelling has nothing to say about the tree.

      Curve solved by measurement, not guess. `tools/level_curve.tscn` drives the
      *real* wave director — the first version modelled wave growth as
      compounding across the run and reported 103,788 kills, because growth
      compounds per act and resets. A tool that models the thing it measures is
      only as right as the model, and a wrong one produces confident numbers to
      tune against. Measured: 640 kills, level 30 → 63 → 97 across the three
      acts, arriving at the summit three levels short so the longest fight in the
      run still pays.

- [x] **Rebalance.** Three things had made the game easier at once and none
      looked like a balance change: far more buildable ground (568 places take
      two towers abreast, where the old pockets took one), free placement
      removing the slot ceiling, and a hero who can now reach +109% damage.
      Measured peak pressure was 0.26 — towers alone covering roughly four times
      the threat, which is the passive game played from the base.

      `curve_report` models tower capability and **no hero at all**, so peak
      pressure is exactly the fraction of late threat the player must cover
      themselves. Now 0.63: the towers hold most of a wave and the rest is the
      player's job, which is what the levelling exists to make possible.

      Carried by the per-wave rate (0.041 → 0.122), not the act multipliers. The
      first attempt raised those and the balance gate refused it — an act
      multiplier applies in full on the first formation of an act, so 1.26 → 1.68
      is a 33% wall at Act 2's door, exactly the "erase the player's progress on
      the very first formation" the gate exists to catch. Growth is linear, so a
      higher rate lifts wave 51 far more than wave 5 and arrives as a ramp.
      Wave 1 is untouched.

- [x] **Loot with magnetised pickup.** A drop is a *bonus*, never the base
      income — the kill still pays its resources instantly, exactly as before,
      and the drop is an extra share on top. That split is load-bearing: the
      difficulty curve was tuned against guaranteed income, so making the base
      collectable would quietly cut a passive player's economy and re-harden a
      game that had just been balanced. A bonus can only add.

      What it buys is what the rebalance is for — a reason to be on the road
      rather than behind the towers. 34% of ordinary kills drop, elites always
      do and drop triple. The magnet is generous (260 units) because chasing
      coins is not the interesting part; being out there is. Homing latches once
      entered, or a drop at the edge stutters in and out of range and reads as
      broken. Uncollected drops **pay out anyway** on expiry: losing a reward
      already earned by killing the thing teaches a player to stop fighting and
      stand on the road hoovering, which is worse than either extreme.

- [x] **Weather.** Five states, rolled per road so it is known before Preparation
      and can be built *for* rather than discovered mid-wave. Heatwave favours
      fire and thins water; Downpour reverses it; Snowfall favours cold; a
      Duststorm carries wind and stone. Drawn from what each region already is —
      v4 describes Act I as rain-heavy, Act II as a desert of mirage storms, and
      Act III as an approach where "weather suppresses visibility".

      Applied **per element, multiplicatively**. Per element because §20 promises
      "a player who learns one element can read the other", and weather that
      singled out named towers would break exactly that. Multiplicative because
      the region's favoured element is already additive, and stacking two
      additives on one tower is how a "+40%" turns out to be +95% with neither
      number explaining it.

- [x] **Persistent hero and campaign tiers (owner ruling, 2026-08-20).** Hero
      level, experience, placed attributes and the tier cleared now persist;
      everything else — towers, relics, currencies, building tiers, Oathbound
      leaders — still resets. Recorded as dated amendments in GDD §974 and §54
      and in CLAUDE.md's re-cut table and rule 7.

      §974's actual intent survives: the word carrying it was *uncapped*, and
      hero growth still stops at `HERO_MAX_LEVEL`.

      Three tiers — Normal, Nightmare, Hell — each the whole campaign again,
      unlocked by clearing the one below. Boss level expectancies are published
      to the player and are **expectancies, not locks**: a wall that says "come
      back later" throws away the forty minutes already spent, while a fight you
      can see going badly teaches you what to grind for.

      XP retuned from 5.4 to 0.30 per point of health. At 5.4 a single run took
      the hero 1 → 97, which was right when levels reset and wrong now: the whole
      climb would have been over before Nightmare unlocked. Measured ladder:

          Normal    run 1: 9 / 19 / 30   (expects 10 / 20 / 30)
          Nightmare opens at 46          (expects 45 at its first boss)
          Hell      opens at 82          (expects 80), ends at 100

      About seven full clears to cap. `SAVE_VERSION` 3 → 4; v3 saves migrate by
      arriving with no hero block, which is tested, and the save-backup check was
      run by hand — all five rows pass.

- [~] **Leaderboards** — client, score model, offline outbox, idempotent
      submissions, results-screen entry, browser and validation gate are built.
      Production remains blocked by the Supabase project being service-restricted
      for storage quota and by the table/RLS deployment and live round-trip not
      yet being verifiable. See `docs/LEADERBOARD.md`.
- [x] **Web build** — now in scope (§54 amended). Exported from a `Web` preset
      on the same tag as the Windows build, attached to the release as
      `BeastRoad-web.zip`. Hosting is Netlify, not GitHub Pages: publishing to
      Pages needs a Pages site, creating one is an admin operation a workflow
      token cannot perform (three releases failed on it), and it needs a domain
      to be worth having. The zip's `index.html` sits at its root, which is the
      shape Netlify deploys directly, and `_headers` is written into the bundle
      so caching travels with the build rather than living in a host dashboard.
      The page is embedded in a Carrd iframe, which is also why the build stays
      single-threaded — a cross-origin-isolated document will not embed in an
      iframe that is not.

      Two things made this cheap: the project already renders through
      `gl_compatibility`, which is the only path to WebGL2, and it owns no
      `Thread`. So `variant/thread_support=false` costs nothing — and it is
      required, because a threaded build needs COOP/COEP headers and Pages cannot
      send response headers at all. Both workflows fail if `index.worker.js`
      appears, which is what a threaded export writes.

      The preset was not written from memory of an older Godot. The option keys
      were read out of the 4.7.1 binary itself, and the export was run locally to
      the point where it named `web_nothreads_release.zip` — which proves the
      thread key is spelled right and taking effect, without needing the template
      on this machine.

      Rehearsed on every push, not only on a tag: the guard's export job builds
      the web target too, so a web export that cannot work costs a push rather
      than a version number.

      Two behaviours are gated on the platform. `UserSettings.apply_display()`
      returns immediately — a canvas cannot be moved, resized by its page, or put
      fullscreen outside a user gesture, so on load it would ask for fullscreen,
      be refused, and then set a size and a position for a window that does not
      exist. And the default graphics preset is Medium rather than High: the case
      for High rests on the player staying long enough to find the settings
      screen, which is a fair bet from someone who installed the game and a bad
      one from someone who opened a tab.
- [x] **Story intro cinematic.** Four panels and four lines — what Yuri is, what
      is chasing them, who the player is, where the road goes. That is the whole
      premise (GDD §6), and it is the minimum before someone is asked to defend
      four roads for an hour. Art generated at a native 688×384 and drawn
      nearest-neighbour.

      Skippable from the first frame and shown once. A cinematic that cannot be
      skipped gets resented on the second run; one that replays every launch is
      worse. Gated on a save flag rather than on `runs_started`, so a player who
      quits *during* the intro gets it again.

      It lives in `GameDirector.start_run`, not in `Run._ready()`, and that is
      not cosmetic: every headless tool instantiates `run.tscn` directly, so an
      intro inside the run scene played — and paused the tree for eighteen
      seconds — inside the balance test, the layout check and the snuff soak. All
      three failed, none for a reason connected to what they test. `start_run` is
      the door a *player* comes through; tools do not use it.

      The art fills the frame with the text on a gradient scrim. Reserving a
      strip for the text left the panel in a box wider than 16:9, so a 16:9 image
      was pillarboxed on a 16:9 monitor — the one shape it should have fitted.

- [x] **Loot art and cache diversity.** All four run currencies now have
      purpose-built 48px PixelLab world pickups, resolved by convention
      (`loot_<currency>.png`) with the UI icon retained only as a damaged-install
      fallback. Ordinary raid chests use a strapped supply-crate silhouette;
      locked high-ground caches retain the ornate purple relic chest, so their
      value and key requirement read before the player commits to the ramp.

      `tools/loot_art_check.tscn` drives the real `LootDrop` resolver for every
      currency, asserts the two cache paths stay distinct, rejects duplicated or
      empty art, and runs in the push, release and Update Manager preflights.
      Relics still enter the run through authored regional choices and raid
      resolution, not as arbitrary enemy drops; loot variety does not bypass the
      GDD's build-shaping choice.
- [x] **Cinematic pacing and skip model.** Hold time now starts when the *line*
      finishes fading rather than when the panel starts — the prose previously had
      about a second and a half of legible time, less than it takes to read two
      lines. A tap advances to the next panel; only Escape **held** for 0.9s
      abandons the whole thing, with a fill bar so holding reads as doing
      something. Tapping used to skip everything, so hurrying past a line you had
      already read threw away the rest of the opening. Slow push on the art, and
      SFX hooks on open and per panel.
- [x] **Drops are findable and audible.** A soft pool of light under each drop
      rather than an outline on the sprite: at this size an outline competes with
      the road's own edge detail, while a pool separates the drop from whatever it
      landed on. Pulse is out of phase with the hover so it reads as a glint.
      Sounds on drop and collect, plus a floating number on pickup.
- [x] **Skill 4 was off screen.** The bar's box was a flat 496 units for 638
      units of content — the fourth slot hung off the right edge. Now derived from
      slot size and count. Fixing it made the bar collide with the command row,
      so the ability bar moved to centre-bottom (where an ability bar belongs) and
      everything else lifted by one derived `BOTTOM_BAND` constant, so moving the
      bar again moves the rest with it.
- [x] **`layout_check` now catches off-screen widgets.** It could not see this
      class of bug at all: a widget outside the viewport overlaps nothing, so the
      layout looked perfectly clean while a quarter of the ability bar was gone.
- [x] **Settings reorganised.** Screen shake and beast motion moved off the Audio
      page to a new **Game** tab — they were on Audio because Audio was the page
      that already had sliders, and someone turning off camera shake for motion
      sickness has no reason to look under Audio. Tutorial/opening replay added
      there too.
- [x] **`docs/SFX_PROMPTS.md` leads with STILL TO RECORD (11).** Computed from
      disk when the doc is generated, not hand-maintained — a tracked list is
      wrong the moment a file lands, and then it sends you to record something you
      already have. The five new ids are declared in `Sfx.PLANNED` rather than in
      `PATHS`: registering a path with no file makes the loader warn, and the
      release gate fails on any warning, so five unrecorded sounds would have
      blocked every build.

- [x] **Raid terrain is textured.** The first pass drew flat tinted plates —
      legible, and it looked like programmer art, which is a fair trade for a
      prototype and not for a release.

      Raised ground now uses the **region's own sixteen-tile corner set**, the
      same Wang art the battlefield floor uses. Not a shortcut: an island *is*
      different ground, so the moss on jungle rock or the drift on snow is the
      right material for it, and it autotiles against the camp floor with real
      corner transitions rather than ending on a hard square edge. Baked into one
      texture, so a camp is one sprite rather than several hundred nodes.

      The corner mask counts a corner raised only when **every** tile meeting it
      is raised. "Any" was the first attempt and produced a visibly flat island:
      every edge tile then has all four corners set, so every tile drew the full
      upper piece and fifteen of the sixteen tiles — all the transitions — were
      never used at all.

      The cliff outline is kept but softened. The art transition is organic while
      collision follows the tile grid, so a heavy black line advertises the
      mismatch; it stays because the line is the *true* boundary and the art is
      decoration over it, but it now reads as a shadow rather than a border.

- [x] **Beast scope.** The beast is now animated pixel art: a 256px side-profile
      generated from Pixellab with a 9-frame walk and a 7-frame idle, and a
      sidescroller ground strip baked from a 16-tile platform set and scrolled as
      a leapfrogging pair (two nodes tile an arbitrary distance, and the journey
      is arbitrarily long).

      Frames are layered **over** the procedural gait, not in place of it — the
      bob, step sink, settle and footfall impulses all stay, and the walk frame is
      driven by the gait *phase* rather than a timer, so the beast plants a foot
      on the same beat the camera shakes on. Swapping the procedural motion for a
      spritesheet would have traded a gait that responds to speed and pauses for
      one that plays at a fixed rate.

      Absent frames fall back to the single profile sprite, so a partial set costs
      the animation rather than the screen.

      **The scope now composes as one image**, which took four separate fixes and
      each of the first three exposed the next:

      *The style clash.* The three act backdrops were 1920x1080 painterly art, so
      a pixel-art beast stood in front of a photograph. The backdrops were the
      outlier — the rest of the game is pixel art — so all three were regenerated
      as 688x384 pixel art and are scaled to fill the view height from the
      texture, not from a constant.

      *The parallax seam.* A backdrop that does not tile, butted against its own
      left edge, cut a hard vertical line through the sky every time the pair
      leapfrogged. The clone is mirrored, so both joins are edge-against-identical
      -edge and neither shows.

      *The ground that was never drawn.* The strip sat at z -5 under a backdrop
      left at the default 0: baked, scrolled, and covered by an opaque painting on
      every frame. Worse, when it was uncovered it turned out the bake indexed a
      **corner-mask set** by column — laying fourteen part-transparent transition
      tiles in a row, which drew as a single black line at the beast's feet. The
      bake now measures each tile's four corners from its own alpha, so which mask
      a tile answers to is read from the art rather than assumed from its
      filename. It also rebakes on act change: the strip was built once in
      `_ready`, so the desert and the snow both walked on jungle rock and the two
      tilesets that exist to tell the acts apart were never drawn.

      *The light.* Tilesets generate at full daylight saturation. Unlit, Act I's
      grass read as a bright green platform pasted over a sunset; a fixed dark
      tint fixed that and drew Act II's desert as grey slate under a blazing sky.
      The tint is sampled from the backdrop's own horizon instead — hue pulled
      most of the way back toward white so it cannot compound the art's own
      colour, brightness floored so Act I's near-black dusk does not produce a
      featureless void along the bottom of the screen.

      Act II and Act III each got their own 16-tile set. The first snow set was
      generated from "blue glacial ice" and came back electric cyan, which read as
      water rather than ground; regenerated as frost-cracked slate, it sits under
      the aurora as stone.

      **The town is back on its back.** The first generated beast had none, which
      left the premise of the game — a town riding a Worldstrider — as just a
      lizard. Fixed by regenerating the beast *with* the town rather than
      compositing a town sprite over it: the back rises, settles and tilts through
      the walk cycle, so an overlay would slide against it every frame, and
      inpainting nine frames consistently is a harder problem than asking for the
      whole animal once. Walled rampart, tiled roofs, watchtower, banner, lit
      windows and chimney smoke, all of it moving with the body because it *is*
      the body.

- [~] **Foliage variety.** The procedural polygons stay — they are what says
      "ground cover" — and painted kinds are scattered among them in two families:
      **regional** kinds carrying the act's identity (`plant_<region>_<kind>`) and
      **shared** props that look the same everywhere (`prop_<kind>`), because a
      rock is a rock in a jungle or a snowfield.

      The region's own plant stays the common draw at 58%. The extra kinds are
      punctuation: a field of nothing but boulders is as monotonous as a field of
      nothing but reeds, and the point is that a clump is occasionally *not* what
      you expected.

      Jungle has a shrub and a flower; rock and boulder are shared. Desert and
      snow still need their two kinds each, and nothing is animated yet — both
      follow the same convention, so they are files rather than code.
- [x] Tower and building idle animation — recorded again here in error; it was
      already built, and towers additionally derive damage-fire anchors from
      their own silhouette rather than from authored damage art.
- [x] **Mobile browser touch.** Twin sticks, low opacity, appearing where the
      thumb lands rather than sitting in fixed spots — a fixed stick makes a
      player look down to find it, a dynamic one is under the thumb by
      definition. Left moves, right aims and attacks past a threshold so a shot
      can be lined up without committing to it.

      Movement is fed back into the **input map** rather than into the hero:
      `Input.action_press(&"move_left", strength)`. `Hero._move_input()` already
      reads `Input.get_vector` over those actions and respects strength, so a
      thumb arrives by the same road as a key and the hero needed no change.
      Only aim needed a branch, because a direction is not a button.

      Three things were found by measuring rather than by reasoning:

      *Godot emulates a mouse from touch, and the emulated event arrives*
      **before** *the real one.* So a thumb walking the movement stick also drags
      a mouse across the battlefield, and at press time nothing yet knows the
      finger belongs to a stick. Placement now acts on *release*, when it does —
      which also gives a mouse the slide-off-to-cancel it lacked. Only finger 0
      is emulated, so ownership is the test rather than geometry; asking "is this
      point in a stick zone" would have made two corners of the field
      permanently untappable whether a thumb was there or not.

      *The dash button was eating the aim stick.* Sized from screen height, it
      became a quarter of the frame across on a tall viewport, directly under
      where an aiming thumb rests. It is sized from the shorter axis now and sits
      at the right edge at half height — the one part of the frame the HUD never
      claims. That matters more than tidiness: the sticks read `_unhandled_input`
      so Controls win, which means a HUD panel over a touch button does not hide
      it, it *eats the tap*.

      *The zoom hint named a mouse wheel* and pause was Escape-only, so a phone
      player could neither see the whole field nor leave it. Both are buttons now,
      on every platform, because a two-button zoom is no worse with a mouse.

      `tools/touch_check.tscn` is a guard gate — it drives synthetic touch and
      drag events through the real autoload and reads the real input map, because
      this machine has no touchscreen and the alternative test is a phone.
      `tools/touch_shot.tscn` renders it with both thumbs down.
- [ ] Whether the sticks *feel* right under a thumb, on a real phone. Nothing
      headless can answer that, and the check says so.
- [x] Loot diversity: relic and supply cache types, all four currency pickups,
      and a release gate that exercises their runtime resolution.
- [x] **Stash, inventory and blacksmith.** Ten kinds of gear across three slots,
      each a file. A *kind* is authored content — name, slot, icon, which
      attribute it favours; rarity and level are things that happened to one
      particular copy, so they live on the owned instance rather than writing
      back into the content files.

      **Gear grants attribute points, not raw stats.** That keeps one number
      governing hero power — the same number levelling feeds — so a lucky drop
      cannot out-scale the curve the campaign tiers are tuned against, and a
      player can compare a sword to two levels without arithmetic.

      **Two currencies, deliberately not exchangeable.** Gold is a run currency:
      spent under pressure, reset each run. Marks are what the account keeps.
      Mixing them means either hoarding gold instead of defending, or a stash
      purchase competing with the wall about to be overrun. Shards are what
      broken gear becomes and only buy upgrades, so a duplicate poses a real
      question: sell it for Marks, or break it for Shards.

      Upgrades cost **both**, for the same reason — Shards alone and a full stash
      upgrades everything free; Marks alone and salvage has no purpose.

      Stash and blacksmith are one screen because they are one decision. "Is this
      better than mine" and "should I break it to upgrade what I have" are the
      same question from either end.

      Capacity is finite (40): an unlimited stash means never choosing what to
      keep, which is the decision the blacksmith exists to pose. Losing runs pay
      Marks at 55% — a run that died in Act II still cost an hour, and paying
      nothing for it makes the stash a reward for winning, which is backwards for
      a system whose job is making the *next* attempt stronger.

      `SAVE_VERSION` 4 → 5; v4 saves arrive with no stash block, which is handled
      and tested. Save-backup check run by hand, all five rows. CLAUDE.md rule 7
      amended to name the stash and its bounds.
- [x] **The full audio library re-processed (2026-08-20).** 228 takes across 42
      sounds, reduced to 81 shipped files. Three takes for anything that can fire
      more than once every few seconds — impacts, footsteps, shots, loot, UI —
      because that is where one repeated sample is what the ear picks out; one
      take for events that happen once a wave or once a run, since three subtly
      different war horns are three sounds nobody will ever consciously compare
      and three files to ship.

      Peak-normalised to −6 dB (sfx) and −9 dB (ambience). The first pass
      targeted −3 and files came back out of the encoder at 0.0: Vorbis is lossy
      and routinely overshoots the source peak by a couple of decibels on
      transients. Final spread across 81 files is 7.3 dB with nothing clipping.
      `sfx_boss_spawn` overshot by five and took a true-peak limiter rather than
      another blind gain cut, which would only have made it quiet.

      Ambience keeps its stereo image and its internal quiet — trimming silence
      out of a two-minute loop is how a loop gets a seam in it.

      **`play()` now falls through to a group of the same name**, so adding takes
      is a data change rather than a rename across a dozen call sites. That also
      made deleting the 19 superseded single files *necessary* rather than tidy:
      while `sfx_fire_shot.ogg` existed, `play("sfx_fire_shot")` found it directly
      and the three new takes never rotated.

      `audio_verify` follows nested groups — "impact" names three materials and
      each material names its own takes, which is the right shape: first choice
      is which surface was hit, second is which recording of it.

      Inbox emptied, stale v3 names corrected. STILL TO RECORD: 0.

- [x] **Raid overhaul.** The camp was a flat circle 700 units across, and nothing
      in it made one part different from another — so a raid was sixty seconds of
      backing away from whatever spawned. It is now a **40×40 tile field (2560
      units)**, close to the battlefield's 2880 and nearly four times the old
      diameter.

      **Elevation islands**, generated per raid. They do three things at once:
      block movement and line, so contact can be broken and enemies have to come
      round; hold the better loot, so climbing is a decision made under pressure;
      and each is reached by a **one-tile ramp**, which is a choke — whoever
      holds it holds the island.

      `RaidLayout` is pure geometry with no nodes and no autoloads, the same rule
      `BattleGrid` follows, because connectivity decides whether a camp is
      playable and has to be checkable without standing an arena up.
      `tools/raid_layout_check.gd` builds **300 camps** and asserts it: nothing
      stranded, arrival clear, real relief, every chest and key reachable, and a
      key for every lock.

      It found two generator bugs on the first run — procedural terrain is right
      on the seed you looked at and wrong on one you have not seen. Islands grew
      over the arrival point (keeping *seeds* clear is not enough when a seed
      five tiles out has a radius of six), and my first repair lowered stranded
      tiles one level per pass, which produced level-0 hollows inside level-1
      islands that were equally unreachable. Repair now cuts a ramp where one is
      legal and flattens a whole region to its lowest neighbour where none is.

      **Chests and keys.** Locked chests take the high ground; their keys sit on
      the floor the player crosses anyway — a key hidden on *another* island turns
      one detour into two. Keys are not bound to a specific lock: finding "the
      wrong key" in a sixty-second camp reads as the game wasting your time.
      Opened by proximity, because a chest needing a keypress needs the player to
      stop being chased to press it. Chests pay in scattered drops rather than
      into the purse, so opening one happens on the ground in front of you.

      **Raids pay out at all now** — the arena inherited `EnemyField`'s empty
      `spawn_loot`, so a camp full of kills dropped nothing while the battlefield
      beside it did.

      Enemies respect cliffs and slide along them looking for the ramp rather
      than stopping dead, which reads as a siege instead of as a bug. The camp
      floor is the act's own terrain: the raid backdrop tiled across 2560 units
      showed its own seams as a grid.
- [x] **Milestone cutscenes beyond the opening.** First arrivals in the Sunglass
      Waste, the White Teeth and the Final Ascent now receive short illustrated
      travel cards; Rakka, Veyr, Mogrun and Kharok each receive a dedicated boss
      introduction over their regional art. Every word and trigger is a
      `MilestoneCinematicData` resource, while the art remains derived from the
      resource id by convention.

      They pause the whole run rather than letting a newly spawned boss attack
      under an overlay, restore the exact prior pause state, and stay below five
      seconds unattended against the GDD's ten-second ceiling. Tap, mouse,
      keyboard and controller advance; Escape or touch held for 0.9s skips. Each
      full card is first-view only and persisted with the other tutorial/settings
      flags; the HUD's light, non-blocking region and boss title cards remain on
      every replay.

      Headless tools suppress presentation by default, and the focused release
      gate verifies all seven trigger mappings, convention art paths, persistence,
      pause restoration and desktop/mobile input before a build can ship.
- [x] **The new SFX are integrated.** Eleven takes trimmed, peak-normalised to a
      common −3 dB ceiling and converted to Ogg. Peak-normalised rather than
      loudness-normalised because these are one-shots: `loudnorm` is built for
      programme material and would pump a 0.3s click up to match a two-second
      swell. A shared ceiling is what makes the per-sound decibels in `Sfx.MIX`
      mean the same thing for each of them.

      `sfx_ui_move` was 2.00s of which 95% was silence — trimmed to 0.10s and
      lifted 12.4 dB. Three of the five arrived as multiple takes, so they are
      named `_1.._3` and rotated by `Sfx.GROUPS`, which already re-rolls to avoid
      an immediate repeat. Pitch spread sits on top of that: three takes stop the
      *sample* repeating, the spread stops the three takes becoming a pattern over
      a four-panel cinematic or a cleared pack of twelve.

- [x] **The music prompts described the wrong game.** Three music and three
      ambience rows still named Ashfen, Saltglass and Iron Steppe — the v3
      regions, renamed by v4 §175-195. The files on disk had been renamed to
      match; the generator had not, so the doc reported six sounds as missing
      that have existed for months and described three places the game no longer
      contains. Rewritten for the Verdant Maw, the Sunglass Waste and the White
      Teeth. **STILL TO RECORD is now 0.**

- [x] **`tools/audio_verify.tscn`** — every sound id resolves to a real file,
      every group names real sounds, every mix row names a real sound. The loader
      warns on a missing *file*; nothing checked the groups, and a group naming a
      sound that does not exist plays silence and warns about nothing, because
      there is no file to be missing. 44 sounds, 5 groups, all resolving.

- [x] **Cloud shadows.** They faded linearly with daylight, and the night grade
      was deepened from ~0.30 to ~0.15 — so they sat at a few percent of strength
      across most of a run, present in the code and invisible on screen. The fade
      is now curved, strength 0.42 → 0.60, and drift is quicker because on a
      field half again as large the old speed read as a static gradient.

- [x] **Smoothing option.** Off by default and it should stay off — the art is
      authored as pixel art. Seven hardcoded `TEXTURE_FILTER_NEAREST` sites now
      ask `Graphics.canvas_filter()` and join a group so the toggle applies to
      the field being looked at. Like brightness, it does not knock the quality
      preset to Custom: it is about the screen, not what the machine can afford.
- [x] **Main menu: pixel art, and alive.** I argued for keeping the painterly
      key art — a backdrop shares a frame with a pixel-art beast standing in
      front of it, key art shares a frame with nothing — and the owner overruled
      it on 2026-08-21. Their call, and the right one: a first screen is a
      promise about what the game looks like, and one made in a different medium
      is a promise the game does not keep.

      `MenuStage` composes six layers over a 688x384 pixel vista. The backdrop
      is authored with its **middle deliberately empty**, because the thing that
      goes there is the game's own beast on the game's own idle frames — not a
      menu-only illustration of one. That is the whole point of putting it there:
      the thing on the front is the thing you get, down to the town on its back.

      Everything else is motion, each layer on its own rate and period so the
      composition never comes back into phase: the backdrop drifts on two sine
      waves over a 1.03x overscan, the beast counter-drifts at 0.55 of that so
      the two separate in depth, two mist bands breathe, embers rise out of the
      valley pre-seeded across their own lifetime, stars twinkle on individual
      phases, and the horizon glow swells on a twenty-second breath.

      Three things had to be found rather than assumed. A Control's `size` is
      zero in `_ready` and `resized` never fires for a node added after its
      parent has settled, so everything laid out at the origin at native scale —
      it keys off the viewport rect instead. The beast frames carry a hard dark
      ground line under the feet, which is right in the beast scope where there
      is ground and drew as a black bar ruled across the road here; the row is
      *detected* and cropped, because a row number written down would stop being
      the right one the next time the frames are generated. And the mist began
      as slices of the backdrop, on the reasoning that a strip of the vista is
      already the right colour — it drew two flat grey rectangles, because what
      makes mist is having no edges at all. It is a shader now.

      `tools/menu_shot.tscn` captures the menu and the board over it. The front
      door was the one screen no shot tool covered: `ui_shot` captures the in-run
      interfaces and every one needs a Run the menu deliberately has no part of.
      It proves the drift and the idle cycle by driving `_process` rather than by
      waiting — and it samples a whole cycle, after reporting "no change" once
      because the seven-frame idle happened to land back on frame one.
- [~] Leaderboards — local/client path complete; Supabase quota, schema/RLS and
      live production verification remain (see the detailed item above).

---

## 3. Presentation and juice

### Lighting and atmosphere

- [x] Torch light: even, unblown, readable, and reaching the bend corners.
- [x] Cloud shadows crossing the whole ground. The shader was there and had a
      real bug: a `ColorRect` has no texture, so `TEXTURE_PIXEL_SIZE` is (1,1)
      and the world reconstruction collapsed the whole field into a half-unit
      square. Divided by a 900-unit cloud scale that sampled one point of noise
      for the entire battlefield — a flat wash, not cloud. The quad now passes
      its own world size in, and is sized from the same extent the floor uses so
      it covers exactly the ground it passes over.
- [x] Night at minimum brightness. Two things were missing, and the second was
      the real one.

      **There was no brightness setting at all.** I had deepened the night grade
      from ~0.30 to ~0.15 and left players on a dim screen with no recourse.
      Added under Display, as a lift toward white rather than a gain — a gain on
      a near-black tint leaves it near-black, which is the exact case the control
      exists for. Capped at +55%: at a full lift the day/night cycle stops
      existing, and a setting that can erase a core system will erase it by
      accident. It does not knock the quality preset to Custom, because it is
      about the player's screen, not what their machine can afford, and it
      re-grades a field that is already standing so changing it from the pause
      menu does something.

      **`tools/night_check.tscn`** then answers the row: at the darkest legal
      grade, is the road distinguishable from unlit ground, and an enemy from
      what is behind it. Windowed, not headless — it measures pixels.

	  Getting it to *mean* anything took five wrong versions, each of which
	  returned confident numbers: a hand-rolled world→screen mapping that drifted
	  once the camera followed the hero; sampling at the enemy's node origin,
	  which is at its feet, so it compared road against road and reported a
	  separation of exactly 0.000 twice; freezing the enemy at spawn, which froze
	  its spawn-in part way; and comparing against a point a fixed distance to
	  one side, which landed on road, ground or torchlight depending on where the
	  enemy stopped. The fifth used authored 1920×1080 canvas coordinates against
	  the stretched 1440p/4K viewport texture, confidently sampling the wrong part
	  of the frame. It now composes the canvas and screen transforms, then samples
	  the sprite against the ring around it, which is the question a player
	  actually asks and is asked the same way wherever the enemy stands.

	  Corrected 1440p measurements put the road around 0.078 above ground and the
	  conservative sprite-disc mean 0.007–0.021 away from its local ring. The
	  thresholds sit below those floors (0.025 and 0.005), where scatter cannot
	  make a good build red but an unlit road or invisible sprite still collapses
	  to zero. The check also saves its final frame for visual review. 5 of 5 runs
	  pass.

      Windowed, so it cannot run on CI. By hand, like the save-backup check:

          godot --path game res://tools/night_check.tscn

### VFX

- [x] Painted projectile heads over the existing procedural flight.
- [x] Elemental impact bursts layered over sparks and blast ring.
- [x] Tower AoE pools. Painted per element, then varied per cast: any rotation,
      scale jitter, a few degrees of hue drift, a bloom-in and a slow turn while
      it burns. Four files, and no two casts look stamped — the variety lives in
      the placement, the same way it does in the ground tiles. The exact-radius
      ring survives underneath at low alpha, because the art is ragged on purpose
      and the damage edge is the one thing that must not be vague.
- [ ] A juice pass across everything that fires, lands, dies or completes.

### Roads and ground

- [x] Per-region road sets and Wang-tiled ground floors.
- [x] Road edge stroke, per environment. Derived from the road's own colour
      rather than a fixed dark line — a sand road wants a warm shadow and a snow
      road a cold one, and one black outline on both looks like a sticker. Two
      steps of falloff, so it reads as depth rather than as an outline.
- [x] **The battlefield floor.** The environment audit called this the largest
      visual gap in the game, and it was three separate faults stacked.

      *Resolution.* Production floors are now sixteen 64px Wang tiles at two
      world units per texel, giving the battlefield a 3264px-class baked surface
      with real crack, root and mineral grain. Roads are also 64px sources baked
      on an exact 3x pixel grid. Both floor and road select deterministic legal
      dihedral variants per cell, preserving corner/edge topology while changing
      which roots, scars and wheel ruts face the eye; the repeated stamp from town
      to map edge is gone without sacrificing seed reproduction.

      *Brightness.* The jungle floor's base material had a **median luminance of
      19 out of 255** — near black, across most of the battlefield, for months.
      That is the "black void-like seams". Snow had a near-black lower against a
      near-white upper, 5.1x apart, reading as holes cut in a snowfield. All
      three sets regenerated, lineless: outlines on a *floor* gave the earth a
      repeating waffle and put a purple fringe around the moss.

      *Palette.* The generator does not take a palette, only prose. The jungle
      set came back with 20% of its pixels outside any hue a jungle floor has —
      magenta and blue noise that clustered into pink patches. `tools/conform_ground.py`
      folds out-of-gamut hues to the nearest edge of a region's declared arcs and
      caps saturation, touching nothing else; it is idempotent, so the committed
      PNG is reproducible from the generated one.

      Two things came out of it that were not planned. `run_tool.gd -- floor-tiles`
      is now a CI gate: four rules, each one written because a real regeneration
      failed it, and it independently reproduces both shipped defects. And which
      of a region's two materials *dominates* is now per-region data — generated
      in tileset order, the jungle drew a dry terracotta field with green patches,
      the right materials in the wrong proportion. `TerrainData.moss_dominant`
      flips the corner mask to its complement, which reads the same sixteen tiles
      the other way round and needs no second set.

      Measured effect on night readability, which was the worry: enemy-against-
      ground separation went from **0.005 against a 0.005 threshold** — exactly
      on the line — to **0.017**.
- [x] Higher-resolution regional road art: all three 16-mask sets now ship at
      64×64 and the manifest/gate derive their seam bands from source size.
- [x] Snow crosshatch replaced by a restrained dirty steel-blue/oxblood set;
      the production exposure conform caps white rims before import.
- [x] Deterministic texture variation within roads and floors using legal
      rotations/reflections that preserve every N/E/S/W or Wang-corner contract.

### Foliage

- [x] Per-act painted foliage: one plant per region, scattered *among* the
      procedural blades rather than replacing them. The polygons are what make
      the ground look covered and cost almost nothing; the sprite is the plant
      the eye stops on. Tinted toward the region's own sampled ground palette so
      it sits in the same light instead of looking pasted on.
- [x] More silhouettes: reeds come in straight and bent, and any region grows an
      occasional broadleaf. One shape per region read as a hatch pattern.
- [x] Idle animation on anything not static: blades and painted plants sway,
      towers and buildings breathe, the beast walks.
- [x] Per-plant hue and saturation jitter, deliberately small — the palette is
      sampled from the region's own ground, and a wide jitter would put plants
      outside their act.

### Towers and buildings

- [x] Idle animation on every tower and building, always running. Every one of
      the 26 towers and all 27 building tiers now has an authored four-pose
      PixelLab package. Runtime loading follows the id-derived path convention,
      scatters phase per instance, and composes with beast-step wobble. The old
      transform breathe remains only as a damaged-install fallback.
- [x] PixelLab art package for every tower and building. The complete batch is
      78 tower continuation frames, 18 higher-tier building bases and 81
      building continuation frames. `structure_art_check.tscn` gates all 53
      packages at exact size, alpha, stable ground anchor and bounded silhouette
      drift. Blind role/tier readability remains a human acceptance row in the
      production audit, not an ungenerated-asset task.
- [x] Beast walk/idle as authored frames, layered over the procedural gait.
- [x] Building tier variants — all nine buildings now have distinct tier-two and
      tier-three architecture, and every tier has its own idle package.

### The beast scope

- [x] Sidescroller background as a procedural tileset — one 16-tile set per act.
- [x] The beast as a proper sidescroller sprite with walk and idle animations.
- [x] Idle while Preparation is paused. The gait, the footfalls and the step
      shake all wind down rather than cut — a gait that stops on the frame the
      phase changes reads as a freeze. Gated by a test that drives `_process`
      synchronously and measures the gait phase; measuring the footfall signal
      proved nothing, because footfalls only fire when the beast camera is
      current and a harness looking at the battlefield never sees one.

---

## 4. Production readiness

- [x] Controller parity. There were **no joypad bindings at all** — and nothing
      said so, because a missing binding is not an error: the action simply never
      fires. Added as a layer applied before defaults are captured, so a pad
      binding is part of the defaults and "reset" restores it rather than
      stripping the controller out.

      Left stick moves and right stick aims, read directly for a radial deadzone
      and a rescale from its edge — `Input.get_vector` treats each axis
      separately and turns a diagonal push into a square corner. The stick is
      *also* bound to the four move actions, so anything else reading movement
      gets it free. Gated by a test that every rebindable and every `ui_*` action
      carries a pad event, and that re-applying does not duplicate bindings.
- [~] 60 FPS at 1920×1080. `tools/perf_check.tscn` measures it, asserts growth
      always and asserts frame timing **only when a real renderer is present** —
      the dummy renderer does no GPU work, so a headless frame rate says nothing
      about a real one. It runs in the release workflow every publish.

      **The frame-rate number still has to come from a windowed run on real
      hardware:**

          godot --path game res://tools/perf_check.tscn -- --seconds=120 --build

      **Post-structure-animation developer-hardware pass, 2026-08-20:** RTX 3070
      Ti, High, 1920×1080, 120 measured seconds: 62 FPS average, 19.7 ms p99,
      29.9 ms worst, zero hitches over 33 ms, +0 orphans, +0.4% nodes and +0.2%
      memory. This is the current release evidence after all 53 authored frame
      packages were live. The earlier foliage batching pass converted roughly
      1,380 polygon draw commands to one static mesh per depth band.

      The row remains partial until minimum/recommended hardware are defined and
      qualified; one high-end developer machine is not the shipping matrix.

      One real finding stands: the field carried **107 PointLight2D**, from
      torches going 24 → ~60 with their radius raised 225 → 360. Every 2D light
      redraws everything it covers. One post in two now carries a pool — the rest
      keep flame, glow and smoke and are lit by neighbours — taking it to 75 with
      no visible difference, since the pools overlap heavily at that radius.

- [x] `save_backup_check.tscn` re-run for `SAVE_VERSION` 6 on 2026-08-20 — all
      five rows pass (unreadable save backed up, backup byte-identical, survives
      a second mismatch, v1 source
      preserved, v2 terrain rename with unknown ids kept).

---

## 5. Done this far

Kept short deliberately — this is a working list, not a changelog. Git carries
the history.

- Launcher updates only when the launcher itself changed (verified against the
  published release, not just the code).
- Chill model for slows; hitstun gated so nothing can be stun-locked.
- Preparation countdown with the tiered early-departure reward.
- Endless after the summit, and its unlock.
- Boss health bar wired; Act III debrief no longer a dead end.
- Element rail in the build menu, with per-tower stat tooltips.
- First-run tutorial: side card, dismissible, per-save, togglable.
- Erase saved data, in Settings.
- Per-region roads and Wang ground floors for all three acts.
- Towers y-sort on their base anchor; shadows anchor to the sprite, not the node.
- Health bars draw above world content, so foliage cannot occlude a readout.
- Foliage sorting bands refined 16 → 32, keeping maximum depth error below one
  tile; each band is now one static mesh, cutting roughly 1,380 draw calls.
- Dash allowed in every phase the hero can move in.
- Tower range rings shown on selection (`Tower.show_range` had no caller at all).
- Beast scope reads as one world: pixel-art skies, ground lit from the horizon,
  and the parallax wrap no longer visible.
