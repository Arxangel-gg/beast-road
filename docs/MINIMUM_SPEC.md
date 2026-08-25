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

Three runs on the reference machine — Ryzen 7 5800X, RTX 3070 Ti, Windows 11,
1920×1080, vsync off, on the authored worst-case wave:

| Run | Avg frame | p99 | Draw calls | Primitives |
|---|---|---|---|---|
| High preset | 14.0 ms (72 fps) | 18.1 ms | 1138 | 9202 |
| Low preset | 13.3 ms (75 fps) | 16.7 ms | 1001 | 6690 |
| Low, **every** optional effect off | 14.0 ms (72 fps) | 16.7 ms | 830 | 4412 |

**The third row is the finding.** Turning off cast shadows, contact shadows,
clouds, particles and foliage together — cutting primitives by more than half and
draw calls by a quarter — does not improve the frame time at all. It is within
noise of both other runs.

So the ~13–14 ms is a **fixed cost that no graphics setting touches**. It is not
the GPU: a 3070 Ti is not troubled by 1100 2D draw calls, and the numbers would
have moved if it were. It is CPU-side — script work, node processing and draw
call submission through the GL Compatibility renderer.

### Three consequences, and they are the whole reason to write this down

**The quality preset is not a performance escape hatch.** A player whose machine
cannot hold 60 will not rescue it by dropping to Low, because the cost is not in
what Low controls. The presets are about how the game *looks* on a given machine,
not about how fast it runs — and any support advice that says "try lowering the
graphics settings" would be wrong.

**The GPU floor is genuinely low, and the CPU floor is what binds.** This is a 2D
game rendering roughly a thousand batched draws through OpenGL 3.3. Almost any
GPU that can present 1080p will do; the minimum GPU column above is really a
statement about which OpenGL version the driver exposes.

**Headroom on high-end hardware is about 4×, and that is less than it sounds.**
13.3 ms against a 16.7 ms budget is comfortable on a 5800X. A CPU with roughly a
quarter of its single-thread throughput lands exactly on the budget with nothing
spare, and that is what sets the 2015-era floor in the table rather than any
measurement of such a machine.

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

**The fixed 13–14 ms has not been investigated.** It is a large per-frame cost
for a 2D game and it may well be reducible — a profile would say where it goes.
Reducing it would lower the declared minimum, which is the cheapest way to widen
the audience this game can reach. That is a separate piece of work and it has not
been started.

---

## Re-measuring

```bash
godot --path game res://tools/perf_check.tscn -- --quality=low --seconds=90
```

Windowed, not headless: the dummy renderer does no GPU work and will happily
report several hundred frames a second on a machine that stutters. `--off=` takes
a comma-separated list of `cast`, `contact`, `clouds`, `particles`, `foliage` to
price one feature at a time rather than inferring it from the gap between two
presets that differ in five ways at once.
