# The frame budget, met — 2026-09-08

## DONE

**55 FPS → 128–136 FPS at a pinned 1920×1080.** `perf_check` passes on real
hardware with 2.2× headroom. GDD §52's 60 FPS release requirement is met.

One cause, one change:

`Flame._draw_layer` drew a separate quad between every pair of segments. Nine
segments × three layers × forty-eight lit flames is **1,296
`draw_colored_polygon` calls every frame**, each a four-point polygon rebuilt
from scratch. In the compatibility renderer a draw call is CPU work whether or
not the GPU cares, which is exactly why the game measured as neither GPU-bound
nor actor-bound.

Consecutive quads shared their edges, so their union is a simple y-monotone
strip — `height > 0` always and `_half_width_at` is clamped at zero, so every
scanline crosses the shape in one interval. The identical filled area is
therefore one polygon per layer: up the left edge, back down the right.

    before   avg 18.3 ms ( 55 fps)  p99 20.1 ms  1489 draw calls  1 hitch/min
    after    avg  7.8 ms (128 fps)  p99  9.1 ms   807 draw calls  1 hitch/min
    after    avg  7.4 ms (136 fps)  p99  9.1 ms   785 draw calls  0 hitches

**`tools/perf_bisect.tscn` is new and is what found it.** It groups every node by
its script, switches `_process` off one group at a time and measures the
difference. `flame.gd` came back at 14.76 ms of a 21.45 ms frame; every other
script in the game sat at a ~2.5 ms noise floor. It is diagnostic only —
asserts nothing, fails nothing, and is deliberately in no workflow.

## What the previous two sessions got wrong, and why

The blocker was recorded as structural: "no hotspot, a 15.4 ms floor, a scope
decision rather than a bug hunt". That conclusion came from
`--off=lights,foliage,clouds,particles,cast,contact`, and `perf_check` also
supports **`flames`**, which that list omits. So the most expensive thing in the
game ran straight through the measurement that was supposed to have turned
everything off. **The floor was the bug.**

The parts of that investigation which were right, and which did the real
narrowing: Low quality buying one frame ruled out the GPU, and an idle
battlefield buying one frame ruled out the actors — killing the leading
hypothesis that per-actor `ShaderMaterial`s were costing draw calls. What was
missing was a way to ask *which code*, rather than which setting.

Also retired: the 62 FPS reading from 2026-08-20, which was taken windowed with
no pinned resolution and is not comparable to anything. It was never a baseline;
the flame cost was present then too.

## CONFORM

`run_tool.gd -- audit` — **46 / 46 automatic probes**, unchanged. This is an
optimisation and a diagnostic tool; it adds no v4 requirement.

## KILL Q

*Does the game hold 60 FPS at 1080p on real hardware?*

Yes, with margin, on this machine — 128–136 FPS across two 60-second runs, zero
hitches on the cleaner one. Two honest limits: **minimum-spec hardware is still
undefined and unqualified**, so "one high-end developer machine is not the
shipping matrix" still stands — what changed is that the margin is 2.2× rather
than negative, so a weaker machine has room to be slower and still pass. And
flame remains the largest single cost at 3.2 ms of a 6.9 ms frame, so there is
more available here if that matrix ever demands it.

The change is not a visual trade. Six flames were rendered at pinned `_time` and
`_seed`, before and after, and diffed: **maximum difference 0 across 3,686,400
pixels**. `night_check`, `torch_check` and `recovery_polish_check` pass on a real
renderer.

## FILES

Created — `game/tools/perf_bisect.gd`, `game/tools/perf_bisect.tscn`, this
report. Modified — `game/scripts/systems/flame.gd`, `docs/ROAD_TO_RELEASE.md`.

## ASSETS

None. No placeholder requirements, no generation credits.

## BLOCKED

Minimum-spec hardware, real-device portrait/controller acceptance, two-machine
co-op and the `menu_layout_check` Linux segfault (unreproduced, not fixed) all
remain open. None is a release blocker on its own terms.

## NEXT

Cut the release.
