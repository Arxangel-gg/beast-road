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
- [~] A few torches still sit closer together than the rest, where a segment's
      end stop lands near a corner post. Cosmetic; needs a minimum-gap pass.
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
- [ ] Rank 2 — reroll one crossroad pair per run. Needs a button on the crossroad
      screen and a per-run counter; nothing else.

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
- [ ] Night at minimum brightness still playable (audit's human-judgement row).

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

- [ ] `save_backup_check.tscn` run by hand before any release that changes
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
