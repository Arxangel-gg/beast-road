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

`run_tool.gd -- audit` — **36 / 44 (82%)**, 7 rows need human judgement.

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
- [ ] Enemy and foliage shadow anchors — same class of bug as the tower one.
      Audit every `add_contact` caller for a sprite offset it does not account for.

---

## 2. Conformance — the 8 outstanding rows

### Terrain ids (3 rows) — a rename plus a save migration

- [ ] `ashfen` → `jungle`, `saltglass` → `desert`, `steppe` → `snow`.
      Touches the terrain `.tres`, 48 Wang ground tiles, 48 road tiles, the
      manifest, and `run_tool.gd`'s region list.
      **`MetaState.unlocked_terrains` stores ids**, so this needs a `SAVE_VERSION`
      bump and a run of `res://tools/save_backup_check.tscn` (CLAUDE.md §1 — that
      check is deliberately not in CI).

### Meta systems that do not exist (2 rows)

- [ ] Tools: earning, cap (`Balance.TOOLS_MAX`), persistence, payout, UI.
- [ ] Four capped Sigil ranks (`Balance.SIGIL_MAX_RANK`), awarded one per win.

Both are already sanctioned for `MetaState` by CLAUDE.md §7, so the save schema
is agreed; nothing else is built.

### The summit (3 rows) — the largest remaining feature

- [ ] Final Ascent route (`Balance.FINAL_ASCENT_DISTANCE`). `Phase.FINAL_ASCENT`
      exists as an enum three systems tolerate; **nothing ever enters it**.
- [ ] Kharok the Chainmaker, three phases (v4 §513): all four roads → chained
      tower formations → summit arena with the town still visible.
- [ ] Summit backdrop art.
- [ ] Ending and credits. v4 wants the final break to transition *directly* into
      the ending with no post-victory loot menu.

Beating Act III currently rolls into Endless. That is a good loop and was asked
for, but it is not v4's ending.

---

## 3. Presentation and juice

### Lighting and atmosphere

- [x] Torch light: even, unblown, readable, and reaching the bend corners.
- [ ] Cloud shadows crossing the whole ground, procedurally. `CloudShadows`
      exists as a full-field noise shader; it needs to actually read as moving
      cloud over terrain.
- [ ] Night at minimum brightness still playable (audit's human-judgement row).

### VFX

- [x] Painted projectile heads over the existing procedural flight.
- [x] Elemental impact bursts layered over sparks and blast ring.
- [ ] Tower AoE pools: replace the thin ring with painted art, ideally generated
      per-cast so no two are identical, the way the tilesets vary.
- [ ] A juice pass across everything that fires, lands, dies or completes.

### Roads and ground

- [x] Per-region road sets and Wang-tiled ground floors.
- [ ] Road edge stroke, catered per environment.
- [ ] Procedural texture variation within a road, not one tile repeated.

### Foliage

- [ ] Per-act foliage matching each region.
- [ ] More kinds and more variation, placed procedurally.
- [ ] Idle animation on anything not static.
- [ ] Minor hue variation per plant, still inside the region's palette.

### Towers and buildings

- [ ] PixelLab art for every tower and building.
- [ ] Idle animations on all of them, always running, so the field is not static.
- [ ] Building tier variants — nine buildings have one sprite each; v4 §M3 wants
      visible growth.

### The beast scope

- [ ] Sidescroller background as a procedural tileset.
- [ ] The beast as a proper sidescroller sprite with walk and idle animations.
- [ ] Idle while Preparation is paused: the walk, the shake and the gait all stop.

---

## 4. Production readiness

- [ ] Controller parity (audit human-judgement row, no implementation seen).
- [ ] 60 FPS at 1920×1080, measured.
- [ ] Opening, region transitions and boss introductions.
- [ ] **Oathbound framing decision.** "No enslavement language ships" is a v4 §57
      *release requirement*, and CLAUDE.md flags it as needing the owner, not an
      agent. Blocking for 1.0.
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
