# AGENTS.md — BEAST ROAD

Project instructions. Read this at the start of every session, before touching
any code.

---

## 1. What this project is

A 2D action tower-defense roguelite in Godot 4.7.1. One hero defends four
lanes around a city riding on the back of a walking beast.

**The design spec is `docs/Game_Design_v3.md`.** It is authoritative. This
file contains working rules only — it does not restate the design. When the
two conflict, the GDD wins for *what* to build and this file wins for *how*.

`docs/Game_Design_v2.md` is superseded but **worth reading before you cut or
re-cut anything** — it argues well for scope discipline, and v3's §14 says
exactly which of those arguments the owner overruled and why.

`docs/Game Design.md` is v1, archived history. **Do not build from it.**

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

1. **The target is the full game** (GDD §9 "The full loop"). Build toward a
   loop that closes: splash → menu → run → all four scopes → boss → win/lose →
   unlock payout → menu. Report honestly what is real and what is a stub.
2. **Never build anything in GDD §12 (Still Out of Scope).** That list is
   shorter than v2's was, and everything the owner un-cut is already in v3 —
   so if a system is on that list, it was cut on purpose.
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
7. **`MetaState` writes only unlocked IDs, run statistics, and settings.** If
   anything else appears in the save file, a design decision has been
   violated — flag it instead of implementing it.
8. **The battlefield freezes during a raid and resumes exactly as it was**
   (GDD §6.3). It must therefore be suspendable as a unit — no system may keep
   ticking off a timer the battlefield does not own.
9. **Player-facing strings live in data, not in logic.** This matters most for
   the captive system (GDD §6.3), whose framing is explicitly unsettled.

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
KILL Q    — the stage's kill question and your honest read on it
FILES     — created / modified
ASSETS    — any new placeholder requirements added to the manifest
BLOCKED   — anything needing a human decision
NEXT      — the single next step (do not start it)
```

Be honest in KILL Q. If a stage feels bad, say so — that is the entire point
of the gate.

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
