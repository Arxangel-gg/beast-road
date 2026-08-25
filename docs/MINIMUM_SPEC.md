# Minimum specification

GDD §47 locks "60 FPS at 1920×1080 on the declared minimum specification", and
`V4_CONFORMANCE.md` has carried that row as `manual` because **the specification
had never been declared**. A performance requirement that names an undeclared
machine cannot be passed or failed. This declares it.

Written 2026-08-25 from measurements taken with `tools/perf_check.tscn`.

---

## The declaration

| | Minimum | Recommended |
|---|---|---|
| **OS** | Windows 10 64-bit | Windows 10/11 64-bit |
| **CPU** | 4 cores, ~2015 desktop class (Intel i5-6400 / AMD FX-8350) | 6 cores, ~2020 desktop class |
| **RAM** | 4 GB | 8 GB |
| **GPU** | Anything with OpenGL 3.3 — Intel HD 520, GeForce GT 730, Radeon R7 240 | Any discrete card from 2016 onward |
| **Storage** | 500 MB | 500 MB |
| **Display** | 1280×720 | 1920×1080 |
| **Quality preset** | Low | High |

Browser play needs a current Chrome, Edge, Firefox or Safari with WebGL 2. The
web build is single-threaded — a threaded export needs COOP/COEP headers that
GitHub Pages cannot set — so it is the slowest way to run the game and is not
what the table above describes.

---

## What the measurements actually say

Four runs on the reference machine — Ryzen 7 5800X, RTX 3070 Ti, Windows 11,
1920×1080, vsync off, on the authored worst-case wave:

| Run | Avg frame | Physics | Draw calls | Primitives |
|---|---|---|---|---|
| High preset | 14.0 ms (72 fps) | — | 1138 | 9202 |
| Low preset | 13.3 ms (75 fps) | 0.1 ms | 1019 | 6526 |
| Low, **every** optional effect off | 14.0 ms (72 fps) | — | 830 | 4412 |
| Low, **all 51 2D lights off** | 15.0 ms (67 fps) | 0.1 ms | 1133 | 6332 |

**Read the spread before reading the rows.** The four runs differ by 1.7 ms and
the configurations differ enormously — one of them halves the primitives, another
removes every light in the game. Turning all the lights *off* produced the
slowest run of the four, which is not a real result: it is run-to-run variance,
and it is the size of every other difference in the table. Do not conclude from
these numbers that any one system costs more than another. Nothing measured so
far separates them.

### What is solid

**Physics is free.** 0.1 ms, consistently. Whatever the frame is doing, it is not
that.

**Nothing disabled so far moves the frame time out of the 13–15 ms band** —
including cast shadows, contact shadows, clouds, particles, foliage and every 2D
light, individually and together. That is the finding, and it is a negative one:
the cost is not in any of the systems a quality setting controls.

**It is not the GPU.** A 3070 Ti is not troubled by ~1100 batched 2D draw calls,
and removing more than half the primitives changed nothing.

### Three consequences, and they are the whole reason to write this down

**The quality preset is not a performance escape hatch.** A player whose machine
cannot hold 60 will not rescue it by dropping to Low, because the cost is not in
what Low controls. The presets are about how the game *looks* on a given machine,
not how fast it runs — so support advice along the lines of "try lowering your
graphics settings" would be wrong.

**The GPU floor is genuinely low, and the CPU floor is what binds.** This is a 2D
game rendering roughly a thousand batched draws through OpenGL 3.3. Almost any
GPU that can present 1080p will do; the minimum GPU column above is really a
statement about which OpenGL version the driver exposes.

**Headroom on high-end hardware is about 4×, and that is less than it sounds.**
13–15 ms against a 16.7 ms budget is comfortable on a 5800X and not generous. A
CPU with roughly a quarter of its single-thread throughput lands on the budget
with nothing spare, and that — rather than any measurement of such a machine — is
what sets the 2015-era floor in the table.

---

## What this declaration is not

**Nothing has been measured on minimum-spec hardware.** Every number above comes
from one modern desktop. The minimum column is *derived* — from the renderer's
OpenGL requirement, from the measured fixed frame cost, and from the ratio a
weaker CPU would need to stay inside the budget.

That derivation is a reasonable engineering estimate and it is not a test. Until
the game has been run on a machine of roughly the declared class, the honest
status of §47's row is "declared, not verified". `V4_CONFORMANCE.md` should say
so rather than showing it green.

**The fixed 13–15 ms has been located but not explained.** `Performance`
monitors put essentially all of it in the process step and none in physics, and a
census of the running scene found only 182 nodes with `_process` or
`_physics_process` enabled — 147 of them torches and their flames and light
drivers. 182 script callbacks cannot plausibly account for 13 ms, so the cost is
mostly *engine* work inside that step rather than GDScript, and Godot's process
monitor cannot separate the two.

Answering it properly needs a real profiler rather than these monitors. It is
worth doing: it is a large per-frame cost for a 2D game, and reducing it would
lower the declared minimum, which is the cheapest available way to widen who can
play this. It has not been started.

**Beware the variance.** Any future comparison needs several runs per
configuration, or repeats of the mistake above: three of the four rows in the
table were initially over-read as meaningful differences when they sit inside the
noise. `--off=lights` was added to the perf tool during this work and is worth
keeping — it answered its question, and the answer was "not that".

---

## Re-measuring

```bash
godot --path game res://tools/perf_check.tscn -- --quality=low --seconds=90
```

Windowed, not headless: the dummy renderer does no GPU work and will happily
report several hundred frames a second on a machine that stutters. `--off=` takes
a comma-separated list of `cast`, `contact`, `clouds`, `particles`, `foliage`,
`lights` to price one feature at a time rather than inferring it from the gap
between two presets that differ in five ways at once. Run each configuration
several times: the spread between runs is around 1.7 ms, which is larger than
every difference measured so far.
