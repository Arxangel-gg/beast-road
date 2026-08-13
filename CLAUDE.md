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
| Chieftain capture → captive labour | replaced by Oathbound / ransom / standard | **needs the owner** |

**Mid-combat tower placement is settled.** Construction and upgrades belong to
Preparation; Command orders, doctrines, the horn and the hero carry in-combat
agency. Do not reopen it, and do not leave the v3 behaviour in place "just in
case" — a build path that only works in one of two designs is worse than either.

The captive question is genuinely different from a pacing call: v4 makes
*"no casualized slavery framing"* a rating-target requirement (§2) and *"no
unreviewed enslavement language ships"* a release requirement (§57). v3 §6.3
had already flagged the framing as unsettled and kept it in data for exactly
this reason. Until the owner rules, keep the strings in data and do not build
new mechanics on top of the labour framing.

**Otherwise: do not silently implement a re-cut of anything in v3 §14.** Ask, or
leave the v3 behaviour in place and flag it.

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
7. **`MetaState` writes only what v4 sanctions:** unlocked IDs, run statistics,
   settings, Tools, the four capped Sigil ranks, and the Treasury cache (GDD
   §57). Nothing else. The rule this enforces is §52's — *"no run-only power
   leaks into the account save"* — so if you find yourself persisting a relic,
   a tower level, a currency balance or hero progress, a design decision has
   been violated. Flag it instead of implementing it.
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
No code change, no re-import step, no manifest edit.

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
