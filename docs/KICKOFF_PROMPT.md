# KICKOFF PROMPT — paste this into Claude Code as your first message

> Everything below the line is the prompt. Paste it verbatim.

---

You are building a 2D action tower-defense roguelite called **Beast Road** in
**Godot 4.7.1**, on Windows.

## Read first, in this order

1. `CLAUDE.md` — working rules, environment, art pipeline conventions
2. `docs/Game_Design_v2.md` — the design spec, authoritative
3. `docs/ASSET_MANIFEST.md` — asset paths, dimensions, naming

`docs/Game Design.md` is v1 and is archived history. **Do not build from it.**
It contains systems that were deliberately cut.

Do not skim. Read §3 (Four Scopes), §9 (Out of Scope), §10 (Build Order), and
§11 (Technical Direction) of the GDD in full before writing anything.

## Environment notes

- Repo root: `E:\Arxangel\GameDev\BeastRoad\`
- The Godot **folder** is `Godot_v4.7.1-stable_win64.exe\` — the actual
  executable is inside it. Find its real filename; don't assume.
- Godot project root will be `E:\Arxangel\GameDev\BeastRoad\game\`
- Paths contain spaces. Quote them in every command.
- **This is Godot 4.7.1, which is likely newer than your training data.** Do
  not write GDScript from memory of 4.2/4.3. If you are not certain an API
  exists in this exact form, verify it against the local install with a
  headless test script before committing to it. `Image`, `Resource`, and
  editor-tool APIs in particular have moved.

## Your task this session: Stage 0 and Stage 1 only

### Stage 0 — Scaffolding and asset pipeline

1. **Reorganize the repo** to the structure in `CLAUDE.md` §2: create `docs/`
   and move both GDDs into it, create `game/` as the Godot project root.
2. **Initialize git** at the repo root with a Godot 4 `.gitignore`. The Godot
   binary folder must be ignored. Verify current Godot 4 conventions for
   whether `*.import` files are committed — do not assume from older versions.
   Make one initial commit.
3. **Create the Godot project** at `game/` with the directory structure from
   GDD §11. Renderer: `gl_compatibility`. Window 1920×1080, viewport stretch
   mode `canvas_items`.
4. **Write `game/scripts/Balance.gd`** as a single autoloaded constants file
   containing every `[TUNE]` value from the GDD, named clearly, with the GDD
   section referenced in a comment.
5. **Write the three autoloads** — `RunState.gd`, `MetaState.gd`,
   `EventBus.gd` — as stubs with correct structure and typed signals, per GDD
   §11 rules 1, 2 and 5.
6. **Write the Resource classes** — `TowerData`, `EnemyData`, `RelicData`,
   `SpellData`, `TerrainData` — with `class_name`, static typing, and an `id`
   field. Each must expose a `get_sprite_path() -> String` that derives the art
   path from `id` by the convention in `CLAUDE.md` §4.
7. **Write `game/tools/generate_placeholders.gd`** as an `@tool` EditorScript
   that reads `docs/ASSET_MANIFEST.md`, and for every listed asset that does
   not already exist, generates a placeholder PNG at the exact path and exact
   dimensions given. Each placeholder must be:
   - a flat fill in the category colour given in the manifest
   - with a 4px magenta `#FF00FF` border
   - with the asset's filename drawn as text, centered, readable
   - with pixel `(0,0)` set to exactly `#FF00FF` as the detection marker
   - transparent-background assets get a transparent centre; opaque assets get
     an opaque fill
8. **Run it.** Every asset in the manifest must exist on disk afterward.
9. **Write `game/tools/asset_report.gd`** — an EditorScript that scans
   `res://art/`, checks pixel `(0,0)` of each PNG, and prints a report of which
   assets are still placeholders versus replaced with real art. Run it and
   include the output in your report.

### Stage 1 — Does swinging feel good?

Grey box only. **No towers, no lanes, no city, no UI, no waves, no menus.**

- One open arena, flat background, camera following the hero
- Hero: WASD movement (200 px/s), 3-hit melee attack chain on left click,
  dash with 0.3s i-frames on spacebar / right click, 4s cooldown
- One enemy type spawning continuously at the arena edge, walking toward the
  hero, dealing contact damage
- Hero HP, enemy HP, damage, death, respawn on death
- Five minutes of survivable combat
- Use the placeholder sprites — this is what they are for

Everything tunable via `Balance.gd`.

## Verification before you report

- The project opens headless with **zero errors and zero warnings**:
  `"<godot exe>" --headless --path "E:\Arxangel\GameDev\BeastRoad\game" --quit`
- Every asset in the manifest exists at its exact path and dimensions
- `asset_report.gd` runs and produces sane output
- The game actually runs and is playable for five minutes

## Then stop

**Do not start Stage 2.** Report using the format in `CLAUDE.md` §7, and give
me your honest read on the Stage 1 kill question: *is swinging at things fun
with nothing on top of it?*

If you hit a design decision the GDD does not answer, do not invent one — list
it under BLOCKED and stop.
