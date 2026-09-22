# The VFX Forge — the window

A standalone Godot project that designs, renders and previews Wilderhold's
effect sheets. It is the GUI half of `tools/vfx_forge`; the Python half is
what actually drives Blender, and this never renders anything itself.

    Godot_v4.7.1-stable_win64.exe --path forge_app

## Why it is its own project

It ships to nobody and has nothing to do with the game's scene tree, so it
must not be able to break the game by existing — the same reason the launcher
is its own project. What it shares with the game is `tools/vfx_forge`, which
is the part doing the work.

## Why it exists at all

A lit-pixel count says nothing about what an effect looks like moving. Two of
the first twenty-four effects passed every numeric rule in `forge_check` while
rendering as a cog and a sunburst, and the only thing that caught them was
looking. A tool that renders a sheet and cannot show it playing is a slower
command line.

So the preview draws a sheet **exactly the way the game will**:

- **tinted**, because every sheet is white on transparent and the game tints
  it once per use — try it under all five before judging it;
- **additive**, because that is the blend the game uses, and an effect judged
  on a normal blend reads far more solid than it will;
- **at 30 frames a second**, which is `Balance.VFX_FORGE_FRAME_RATE` — a sheet
  played at sixty is half as long as it will be in play;
- **over a plate the colour of the road**, because a bright effect on a black
  rectangle always looks good.

The contact strip underneath says what each cell *is*, which is the reading
that catches a flame whose curve is perfect and whose picture is a sunburst.

## What is on the screen

| | |
|---|---|
| **Effects** | The catalogue, read from `tools/vfx_forge/effects/` rather than from any list here. A file dropped in that folder appears on **Re-read the folder**. |
| **Preview** | Play/pause (also `Space`), restart, a scrub bar, the tint, the ground plate, the cell outline, and zoom. |
| **Render** | Frames, cell pixels and takes, defaulting to the effect's own `SPEC`. **Render this effect** (`Ctrl+R`) or **Render every effect**. |
| **Look at** | Which take to play, and a reload from disk. |
| **The forge says** | Blender's own output, live, while it renders. |

`F11` fills the screen; `Escape` leaves it.

## Setting it up

**Paths** asks for three things and remembers them in `user://forge_app.json`:

- **Repository** — the folder holding `tools/vfx_forge`. Guessed from where
  the app is: it lives at `<repo>/forge_app`.
- **Python** — whatever runs `forge.py`. `python` by default.
- **Blender** — 4.5 or later. The `BLENDER` variable is read first, then the
  usual install paths.

If any of them is wrong the window says so on the first screen rather than
after somebody presses Render.

## Rendering

Renders run in a shell that redirects to a file, which the app tails — so the
window stays alive and the log arrives as it happens rather than as a wall of
text at the end. **Stop** kills the shell.

Sheets are written straight into `game/art/vfx/` at the names the game loads
(`forge_<id>.png`, then `forge_<id>_01.png` and up for each take). After a
render the game needs one import before it draws the new ones:

    Godot_v4.7.1-stable_win64.exe --headless --path game --import
    git checkout game/project.godot

(the import strips that file's comments) and then:

    Godot_v4.7.1-stable_win64.exe --headless --path game res://tools/forge_check.tscn

`forge_check` holds every rule a sheet has to obey, including the two a person
cannot check by eye: that every sheet on disk is an effect the game can play,
and that every effect the game names has a sheet.

If you added an effect, add its rows to `docs/ASSET_MANIFEST.md` as well —
`run_tool.gd -- report` fails on a file that is not declared there.

## What a sheet is allowed to be

`docs/VFX_FORGE.md` §3 draws the line and it has not moved: **a sheet is
allowed only where the effect's size is fixed decoration.** A telegraph is
drawn at the blow's own radius, from the same two numbers the damage uses, and
stays procedural — so the warning and the blow can never disagree about where
or when.
