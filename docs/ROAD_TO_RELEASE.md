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
- [ ] Foliage: horizontal ferns, more variety, idle animations.
- [ ] Rebalance for the larger map, hero levelling, loot, weather.

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

      Getting it to *mean* anything took four wrong versions, each of which
      returned confident numbers: a hand-rolled world→screen mapping that drifted
      once the camera followed the hero; sampling at the enemy's node origin,
      which is at its feet, so it compared road against road and reported a
      separation of exactly 0.000 twice; freezing the enemy at spawn, which froze
      its spawn-in part way; and comparing against a point a fixed distance to
      one side, which landed on road, ground or torchlight depending on where the
      enemy stopped. It now samples the sprite against the ring around it, which
      is the question a player actually asks and is asked the same way wherever
      the enemy stands.

      Thresholds sit *below* the measured band (road 0.033–0.055, enemy
      0.050–0.083) rather than inside it. That spread is not noise — foliage
      scatters afresh every build — and a gate pitched mid-band fails a good
      build about one run in six. Under the floor it still catches what it is
      for: torches that stopped lighting the road collapse it to near zero.
      5 of 5 runs pass.

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
- [ ] Procedural texture variation within a road, not one tile repeated.

### Foliage

- [x] Per-act painted foliage: one plant per region, scattered *among* the
      procedural blades rather than replacing them. The polygons are what make
      the ground look covered and cost almost nothing; the sprite is the plant
      the eye stops on. Tinted toward the region's own sampled ground palette so
      it sits in the same light instead of looking pasted on.
- [x] More silhouettes: reeds come in straight and bent, and any region grows an
      occasional broadleaf. One shape per region read as a hatch pattern.
- [ ] Idle animation on anything not static.
- [x] Per-plant hue and saturation jitter, deliberately small — the palette is
      sampled from the region's own ground, and a wide jitter would put plants
      outside their act.

### Towers and buildings

- [x] Idle animation on every tower and building, always running. Towers compose
      it with the beast-step wobble as a separate channel rather than a second
      writer — two systems assigning `sprite.rotation` means the later one erases
      the earlier. Phases are scattered per instance; in unison it reads as the
      whole screen pulsing rather than as a place.

      Frames were considered and rejected for the reason the project already
      works this way: a transform is cheaper, it applies to every structure
      including ones added later, and a spritesheet would still want this
      underneath it.
- [~] PixelLab art for every tower and building. All 26 towers and 9 buildings
      already have generated art; what is missing is *more* of it — tier variants
      and per-element silhouette passes.
- [ ] Beast walk/idle as authored frames, layered over the procedural gait.
- [ ] Building tier variants — nine buildings have one sprite each; v4 §M3 wants
      visible growth.

### The beast scope

- [ ] Sidescroller background as a procedural tileset.
- [ ] The beast as a proper sidescroller sprite with walk and idle animations.
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

      One real finding stands: the field carried **107 PointLight2D**, from
      torches going 24 → ~60 with their radius raised 225 → 360. Every 2D light
      redraws everything it covers. One post in two now carries a pool — the rest
      keep flame, glow and smoke and are lit by neighbours — taking it to 75 with
      no visible difference, since the pools overlap heavily at that radius.

- [x] `save_backup_check.tscn` run by hand — all five rows pass (unreadable save
      backed up, backup byte-identical, survives a second mismatch, v1 source
      preserved, v2 terrain rename with unknown ids kept). `SAVE_VERSION` is
      unchanged since v0.4.25, so this release did not strictly need it.
- [ ] `save_backup_check.tscn` re-run by hand before any release that changes
      `SAVE_VERSION`.

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
- Foliage sorting bands refined 16 -> 48, cutting depth error to about a tile.
- Dash allowed in every phase the hero can move in.
- Tower range rings shown on selection (`Tower.show_range` had no caller at all).
