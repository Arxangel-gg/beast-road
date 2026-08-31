# CLAUDE.md — BEAST ROAD

Project instructions. Read this at the start of every session, before touching
any code.

---

## 1. What this project is

A 2D action tower-defense roguelite in Godot 4.7.1. One hero defends four
lanes around a city riding on the back of a walking beast.

**The design spec is `docs/GDD_Master.docx` (v4.0).** It is authoritative. This
file contains working rules only — it does not restate the design. When the
two conflict, the GDD wins for *what* to build and this file wins for *how*.

`docs/Game_Design_v4.md` is the same document in markdown and is the one to
read — a `.docx` is awkward to grep. If the two ever disagree, the `.docx` is
the signed copy.

`docs/V4_CONFORMANCE.md` turns v4's LOCKED decisions into machine-checked rows.
`run_tool.gd -- audit` reports how much of v4 exists; `-- audit --todo` lists
only what is outstanding. **Run it before claiming a milestone is done.**

### The older GDDs

Superseded, but not worthless, and one of them is a trap:

- `docs/Game_Design_v3.md` was authoritative until 2026-08-13 and **is what the
  shipping code was built to**. When code and v4 disagree, v3 usually explains
  why the code is the way it is.
- `docs/Game_Design_v2.md` argues well for scope discipline. Read it before you
  cut or re-cut anything.
- `docs/Game Design.md` is v1, archived history. **Do not build from it.**

### Re-cuts of owner decisions

v3 §14 marks three things *"Un-cut. Owner's spec."* — decisions the owner
personally reversed against v2's cuts. v4 re-cuts two of them. That is an owner
decision being made a second time, so it needs an owner, not an agent.

| v3 §14 "Owner's spec." | v4 position | Status |
|---|---|---|
| Mid-combat tower placement | locked to Preparation | **DECIDED 2026-08-13: lock it. Build v4.** |
| Partial raid extraction | kept — two windows plus chieftain climax | no conflict |
| Chieftain capture → captive labour | replaced by Oathbound / ransom / standard | **DECIDED 2026-08-20: adopt v4's Oathbound framing.** |
| Run-scoped hero power (v4 §974) | — | **DECIDED 2026-08-20: hero level, attributes and loot now persist. See below.** |
| Co-op (v4 §54 cut) | cut for 1.0 | **DECIDED 2026-08-24: build two-player co-op. See below.** |
| Starting build capital (v4 §448) | one tower per road at start | **DECIDED 2026-08-27: a bounded purse. See below.** |
| Ranged weapons, ammo, blueprints, crafting (not in v4) | absent from the spec | **DECIDED 2026-08-31: build them. See below.** |

**Mid-combat tower placement is settled.** Construction and upgrades belong to
Preparation; Command orders, doctrines, the horn and the hero carry in-combat
agency. Do not reopen it, and do not leave the v3 behaviour in place "just in
case" — a build path that only works in one of two designs is worse than either.

**The captive question is settled.** v4's framing is adopted: leaders are sworn,
ransomed or memorialised, never owned. The owner ruled on 2026-08-20.

It was held open because v4 makes *"no casualized slavery framing"* a
rating-target requirement (§2) and *"no unreviewed enslavement language ships"* a
release requirement (§57), and v3 §6.3 had flagged the framing as unsettled. That
is now decided rather than pending — but the §57 requirement is unchanged by the
decision. Player-facing strings still live in data (working rule 9), and any new
leader copy still has to be read before it ships. What has changed is that
Oathbound mechanics may now be built on, rather than parked.

**Two-player co-op is in scope, as of 2026-08-24.** The owner reversed v4 §54's
cut. Two players, cross-platform, defending one city. PvP, bigger parties and
daily challenges stay cut.

This is the one re-cut that changes the shape of the codebase rather than the
content of the game, so it comes with a standing rule: **co-op does not get to
quietly break working rules 5, 6 and 8.** `RunState` stays the single source of
truth - co-op answers *whose* copy is authoritative, it does not license a second
local cache. Systems still talk through `EventBus`, which is the seam the network
layer belongs at. The raid freeze still resumes exactly, now for two observers
instead of one. Where co-op genuinely cannot satisfy one of those rules, amend
the rule here, dated, in the same change - do not leave the codebase disagreeing
with this file.

**The run opens with a bounded purse, as of 2026-08-27.** This value has now
been ruled on three times: one tower per road (v4 §448), nothing at all
(2026-08-24), and now `Balance.STARTING_GOLD = 150` - enough for two of the four
roads, with the rest taken off the enemies the player kills.

The bound is the decision, not the number. What §448's teaching obligation was
ever protecting is that **the opening must ask something of the player before it
tests them**: a purse that covers every road hands over a finished defence and
asks nothing. So the gate asserts *at most half the roads*, and that a tower on
every road is earned rather than issued. Move the constant freely under that
ceiling; going over it is a design change and should be argued in
`_test_opening_envelope`, which is the one place with an opinion about it.

**Gold is the only wallet that was zeroed**, and that is a decision rather than
an omission. Every tower carries a Gold price, so zero Gold already means zero
towers on the opening frame. What Wood, Food and Stone decide is *which element*
the first affordable tower may be — Fire is the one pure-Gold line — so emptying
them would not harden the opening, it would quietly force Fire for Act I. Wood
and Food also pay for town repair and hero tending, which are not tower capital.
If that reading is ever revisited, revisit it as a decision.

**Measured at 150 on 2026-08-27.** Two towers are affordable before wave 1 and
the four-road baseline arrives on wave 4, against a lane progression that opens
the second road on wave 3 and the fourth on wave 10 - so the ring is covered
slightly ahead of the roads that need covering. At zero it was wave 3 and wave 8.
This is a deliberately softer Act I than the 2026-08-24 ruling produced, and the
owner made the call knowing that; peak run pressure is unaffected either way,
because starting Gold is around a tenth of a run's total income.

Two things had to learn about the change and both are gates now. `curve_report`
models hero DPS as part of capability, because with no towers the hero *is* the
defence for the opening waves and a tower-only model divides by nothing there.
`balance_test` asserts the new contract at both ends: wave 1 alone must **not**
pay for a tower, and a first tower must be affordable by wave 4. Any harness
that wants to build without the economy being its subject must fund itself with
`RunState.gain_every_currency` — three of them were silently leaning on the old
390-Gold cache.

**Ranged combat, ammunition, blueprints and crafting are in scope, as of
2026-08-31.** None of them appears in v4. The owner asked for all four after
being told they were outside the spec, which makes this an addition to the
design rather than a misreading of it.

What that buys, and what it costs, stated plainly so the next argument about it
starts from the same place:

- **The hero gains an answer at range.** Every fight currently resolves by
  walking at something. A bow changes which enemy you deal with first, and that
  is the whole reason to build it.
- **Ammunition is the price.** Range without a cost is simply a better melee
  attack, so ammo is a run resource that is spent, found and crafted. It is
  *not* an inventory of stacks competing with loot — it has its own pool, per
  the same reasoning that keeps Marks off the tower economy (working rule 7).
- **Blueprints are permanent knowledge**, and the only thing in this group that
  touches `MetaState`. They unlock *recipes*, and are covered by the existing
  `unlocked` list rather than a new save shape — so working rule 7 is unchanged
  and no new persistence was sanctioned by this decision.
- **Crafting is bounded to what a blueprint names.** There is no research, no
  recipe modification and no ingredient sprawl; the materials are the four run
  currencies plus what enemies already drop.

The bound worth defending is that **melee remains the reliable default**. If a
run can be completed at range without ever closing, the trade this system exists
to create has collapsed and the ammo economy is decoration. `balance_test` owns
that question.

**Otherwise: do not silently implement a re-cut of anything in v3 §14.** Ask, or
leave the v3 behaviour in place and flag it.

### The three escape hatches — and why there are only three

The project is going all in on v4. That is the right call and it does not need
hedging: a runtime flag that keeps v3 behaviour alive doubles the surface that
has to be balanced, tested and understood, and the unused branch rots until it
is a liability rather than an option. **Do not add feature flags to preserve v3.**

What deserves reversibility is only what is *expensive or impossible* to
recreate. That is three things, and all three cost nothing to keep.

**1. `v3-final` — the last working v3 game.**
Branch at `v0.3.7`, pushed. A complete, released, verified-playable build: full
loop, 122/122 real assets, all gates green. If the migration stalls half-done,
this is what still runs. Never commit to it; it is a photograph, not a branch to
develop on.

**2. One gate, not scattered conditionals.**
A decision that could ever be revisited must be enforced in exactly one place.
Building is locked to Preparation via `RunState.can_build_now()` — every build
and upgrade path asks that one function, and nothing anywhere else tests the
phase inline. Reversing the decision is then a one-line change instead of an
archaeology exercise, and *that* is the escape hatch. It is also just better
code, which is why it costs nothing.

**3. The player's save.**
The only thing in this project git cannot restore. `MetaState` copies any save
whose version it cannot read to `user://beast_road_save.v<N>.bak.json` before
starting fresh, and never overwrites an existing backup — the first copy is the
valuable one, and a player bouncing between builds would otherwise lose the
original on the third launch. Verified by
`res://tools/save_backup_check.tscn`.

That check is **not** in CI: a discarded save legitimately emits a warning, and
the release gate fails on any warning. **Run it by hand before any release that
changes `SAVE_VERSION`.**

`References/` holds the owner's visual references, one per scope. They are the
target, not a mood board — check them before designing a screen.

---

## 2. Environment

| Thing | Path |
|-------|------|
| Repo root | `E:\Arxangel\GameDev\BeastRoad\` |
| Godot binary | `E:\Arxangel\GameDev\BeastRoad\Godot_v4.7.1-stable_win64.exe\` (this is a **folder**; the executable is inside it) |
| Godot project root | `E:\Arxangel\GameDev\BeastRoad\game\` |
| Launcher project | `E:\Arxangel\GameDev\BeastRoad\launcher\` (its own Godot project) |
| Design docs | `E:\Arxangel\GameDev\BeastRoad\docs\` |

Windows. Paths contain spaces — quote them in every shell command.

Verify the exact executable filename inside the Godot folder before running it;
do not assume.

### Godot version discipline

This is **Godot 4.7.1**. Your training data may predate it. Several
`Image`, `Resource`, and `TileMap` APIs changed across 4.2 → 4.7.

**Do not write GDScript from memory of an older version.** Before using any
API you are not certain about:

1. Check the local docs or run a one-line test script headless
2. If an API errors, read the actual error rather than guessing a replacement

Verify the project opens cleanly after every stage:

```
"<godot folder>\<Godot executable>" --headless --path "E:\Arxangel\GameDev\BeastRoad\game" --quit
```

Zero errors and zero warnings in that output is the bar. Not "it probably
works."

---

## 3. Working rules

1. **The target is the full game** (GDD §52 "Release Acceptance Checklist").
   Build toward a loop that closes: splash → menu → run → all scopes → three
   acts → summit → win/lose → payout → menu. Report honestly what is real and
   what is a stub.
2. **Never build anything in GDD §54 (Explicitly Out of Scope for 1.0).** If a
   system is on that list it was cut on purpose. §55 lists what is genuinely
   still OPEN, and none of it is gameplay.
3. **Data-driven, always.** Every tower, enemy, relic, spell, and terrain is a
   `Resource` (`.tres`) in `/data`. No hardcoded stat branches, no
   `if enemy_name == "bogkin"`. Adding content must mean adding a file.
4. **All tuning constants live in `game/scripts/Balance.gd`.** Every `[TUNE]`
   value in the GDD goes there as a named constant. No magic numbers in
   gameplay scripts.
5. **Systems talk through `EventBus`**, never direct cross-scope node
   references. The battlefield must not hold a reference to the city.
6. **`RunState` is the single source of truth for the current run.** No system
   caches run data locally.
7. **`MetaState` writes only what v4 sanctions, plus the hero.** Unlocked IDs,
   run statistics, settings, Tools, the four capped Sigil ranks, the Treasury
   cache (GDD §57) — **and, since 2026-08-20, hero level, experience, placed
   attributes and the campaign tier cleared.**

   That last clause is an owner re-cut of v4 §974, taken deliberately: the game
   is now a multi-run grind with Normal / Nightmare / Hell tiers, and a hero who
   resets every run cannot climb them. The amendment is recorded in GDD §54 and
   §974 with the same date.

   **The rest of the rule is unchanged and still binding.** No relic, tower
   level, run currency balance, building tier or Oathbound leader may persist.
   Hero power is now sanctioned; everything else on that list is still a design
   violation, and the answer is still to flag it rather than implement it.

   The bound that replaces §974's is `Balance.HERO_MAX_LEVEL`: hero growth is
   *capped*, not uncapped, and §54's cut of "uncapped permanent stats" survives
   intact. The stash has its own bound in `Balance.STASH_CAPACITY`, and gear
   grants *attribute points* rather than raw stats — so worn equipment is
   measured on the same capped scale as levelling and cannot out-run the curve
   the campaign tiers are tuned against.

   Gold, Wood, Food and Stone are still run currencies and still reset. Marks and
   Shards are account currencies and deliberately do not exchange with them: a
   stash purchase must never compete with the wall about to be overrun.
8. **The battlefield freezes during a raid and resumes exactly as it was**
   (GDD §52, "Raid pause resumes the exact battlefield state"). It must
   therefore be suspendable as a unit — no system may keep ticking off a timer
   the battlefield does not own.
9. **Player-facing strings live in data, not in logic.** This matters most for
   the Oathbound leader system, whose framing v4 deliberately rewrote: leaders
   are sworn, ransomed or memorialised, never owned. **No enslavement language
   ships** (GDD §57), and that is a release requirement, not a preference.

---

## 4. Art pipeline — the rule that matters

**Every sprite path is derived from its resource `id` by convention.** A
`TowerData` with `id = "ember_spire"` loads
`res://art/towers/tower_ember_spire.png`. Nothing else.

This means: **replacing a placeholder with real art is overwriting a file.**
No code change, no manifest edit.

**But you must re-import.** Godot only re-imports changed art in the *editor*;
the runtime loads whatever `.godot/imported/` already holds, so a game or a tool
scene launched after overwriting a PNG keeps rendering the old texture — silently,
with no error. Every screenshot you take to check your art is a screenshot of the
previous version until you run:

```
"<godot folder>\<Godot executable>" --headless --path "E:\Arxangel\GameDev\BeastRoad\game" --import
```

CI already does this (`guard.yml`, "Import assets"), which is why builds were
right while local checks were stale. Verified art that disagrees with what the
game draws is this, every time.

- Placeholders live at the **exact final path and exact final pixel
  dimensions** listed in `docs/ASSET_MANIFEST.md`
- Every placeholder has pixel `(0,0)` set to pure magenta `#FF00FF` as a
  detection marker. Real art will not have this.
- `game/tools/asset_report.gd` scans `res://art/` and reports which files are
  still placeholders

If you add a new asset requirement, you must add it to
`docs/ASSET_MANIFEST.md` **and** regenerate its placeholder in the same
change. An asset that exists in code but not in the manifest is a bug.

Never draw art in code as a permanent solution. Placeholder PNGs only.

---

## 5. Code conventions

- GDScript, `snake_case` files and functions, `PascalCase` classes
- Static typing everywhere: `var speed: float = 200.0`, typed signal params,
  typed function returns
- `class_name` on every Resource script
- One node responsibility per script; no 400-line god scripts
- Comments explain *why*, not *what*
- No `get_node("../../..")` chains — use `@export` node references or EventBus

---

## 6. Two-person split

- **Person A — Combat:** hero, towers, enemies, waves, raid, fusion
- **Person B — Run layer:** city, crossroads, macro, meta, UI, save

`EventBus.gd` is the contract between them. When adding a signal, add it to
`EventBus.gd` with a typed signature and a one-line comment, and mention it in
your session report so the other side knows it exists.

---

## 7. Session report format

End every work session with:

```
DONE      — what now works, verifiable by running it
CONFORM   — the audit score before and after (run_tool.gd -- audit)
KILL Q    — the milestone's kill question (GDD §53) and your honest read on it
FILES     — created / modified
ASSETS    — any new placeholder requirements added to the manifest
BLOCKED   — anything needing a human decision
NEXT      — the single next step (do not start it)
```

Be honest in KILL Q. If a stage feels bad, say so — that is the entire point
of the gate.

CONFORM is a number, not a claim. A rising score means files and symbols now
exist; it says nothing about whether the feature is good. Never report a
milestone complete on the audit alone — §53's kill question is the real gate,
and the audit cannot answer it.

---

## 8. Shipping

Builds are made by GitHub Actions, never locally — no one needs Godot's export
templates on their machine. Publishing is pushing a tag:

```
tools\release.ps1 -Version 0.4.0
```

`.github/workflows/release.yml` exports the game and the launcher, zips the
game, and attaches both to a GitHub Release. The launcher reads
`releases/latest` and offers Install / Update / Play. Full details in
`docs/RELEASING.md`.

The repository must be **public** for the launcher to read the API without a
token. Never ship a token inside the launcher to work around that.
