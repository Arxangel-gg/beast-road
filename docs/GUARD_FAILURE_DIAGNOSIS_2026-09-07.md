# The v0.6.2 Guard failure, diagnosed without the log — 2026-09-07

`PRODUCTION_READABILITY_2026-09-07.md` closed with the failed Guard job's log
still needed, and the log endpoint refused: downloading a job log requires admin
rights on the repository, which this session does not have.

The log was not needed. Two public endpoints answered the question between them:
the job's **step timings** and the check run's **annotations**.

```
GET /repos/Arxangel-gg/beast-road/actions/runs/34132878628/jobs
GET /repos/Arxangel-gg/beast-road/check-runs/101776960508/annotations
```

## What the run actually says

| | |
|---|---|
| Failing job | `Does it load` (`ubuntu-latest`), commit `83e373f` |
| Failing step | 7, "Load the game, the launcher, and the menu" |
| Step duration | **74 s** (the same step on the last green run, `e3db9b0`, took 366 s) |
| Annotations | two: a Node.js 20 deprecation warning, and `Process completed with exit code 1.` |

**There is no `::error title=…::` annotation.** That is the finding. `check()`
emits one on every failure path it has — timeout, non-zero exit, and dirty
output — so a check that failed and returned 1 would have left one behind. None
exists, which means the step died *inside the reporter*, before it annotated.

## Why the reporter died

The version that ran (`git show 83e373f:.github/workflows/guard.yml`) quoted the
failing line like this, under `set -euo pipefail`:

```bash
why="$(grep -E '^(SCRIPT )?ERROR:|FAIL' "$log" | grep -v 'depended scripts' | head -1)"
echo "::error title=$name::Exited $status. ${why:-no reason printed}"
```

An assignment from a command substitution takes the pipeline's exit status as
its own, and `errexit` acts on it. The pipeline fails in **two** different ways,
both reproduced:

| log contents | pipeline status | step exits | annotation |
|---|---|---|---|
| no matching line | `grep` finds nothing → **1** | 1 | none |
| many matching lines | `head -1` closes the pipe, `grep` takes SIGPIPE → **141** | 141 | none |

Either way the `echo` never runs. The reporter written to stop a gate failing
with no reason given was itself the thing removing the reason.

**The observed exit code was 1, not 141**, so it was the first row: the failing
gate's log held **no line matching `^(SCRIPT )?ERROR:` and no line containing
`FAIL`**.

## Which gate that points at

Every `_check`-style gate reports failure through `push_error`, which Godot
prints as `ERROR: …` at the start of a line — verified against 4.7.1 rather than
assumed. Those would have matched, and would have annotated.

The gates that would **not** match are the `run_tool.gd` family, and they do not
match *on purpose*. `run_tool.gd` prints its own findings indented:

```gdscript
print("  ERROR: %s makes an HTTPRequest without accept_gzip = false" % where)
```

with the reason stated in the source: the load gate anchors on a line *starting*
with `ERROR`, and a tool describing a problem must not be mistaken for the engine
failing. Guard runs five of them — `tool-leak`, `http-gzip`, `report`,
`road-tiles`, `floor-tiles`.

So the failure was a gate that had already printed exactly what was wrong, in a
form the reporter could not read, followed by a reporter that killed the shell
rather than say so.

**This is not narrowed to a single gate.** The 74 s mark cannot be converted to a
position in the list with any confidence: the runner is faster than the
development machine on CPU-bound work (editor-quit 3–4 s there against 8.6 s
here) and identical on the wall-clock-bound ones (the 210 s breather), so a
single scale factor does not exist. What is established is the *mechanism*, and
that the failing gate printed no anchored diagnostic.

## What changed

1. **The reporters cannot die.** Already fixed in the readability patch: `awk`
   returns success with no match and consumes no pipe. Both workflows, both
   scan sites.
2. **The reporters can now see an indented tool finding.** New here. A second,
   indent-tolerant scan runs only when the anchored one came back empty and only
   on an already-failing status — so a failing `run_tool.gd` gate now quotes its
   own finding instead of annotating "no reason printed". The scan that *decides*
   whether a clean run is dirty stays anchored, which is the distinction the
   indentation exists to draw.
3. **A fixture holds it.** `tools/ci_validation_test.sh` gained a `tool_finding`
   case carrying real `run_tool.gd`-shaped output; it fails without the second
   scan. 16 cases across both workflows.

## What is still not known

Which gate failed, and why it failed on Linux and not on Windows. All 66 Guard
checks pass on Windows at this working tree, so the reproduction has to come
from the runner. The next push is what answers it — and now it will say what
broke rather than "Process completed with exit code 1."
