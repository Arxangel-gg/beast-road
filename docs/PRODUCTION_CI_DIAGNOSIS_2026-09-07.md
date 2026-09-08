# Session report — CI diagnosis, cross-platform ordering, idle animation

2026-09-07. Local, unpublished. No commit was pushed, no tag consumed, no
export or GitHub deployment performed by this session.

## DONE

- **The v0.6.2 Guard failure is diagnosed**, and without the job log — the log
  endpoint requires admin rights on the repository. Step timings and check-run
  annotations were sufficient. Full working in
  `GUARD_FAILURE_DIAGNOSIS_2026-09-07.md`.

  The failing step left **no `::error title=…::` annotation**, only
  `Process completed with exit code 1.` Since `check()` annotates on every
  failure path it has, the step died *inside the reporter*. The cause is a
  command substitution whose pipeline fails under `errexit`:
  `grep … | head -1` returns 1 when nothing matches, and 141 when `head` closes
  the pipe on `grep`. Both were reproduced in a shell; the observed exit code
  was 1, which identifies the no-match case and therefore says the failing gate
  **printed no anchored `ERROR:`/`FAIL` line**.

  That points at the `run_tool.gd` family — `tool-leak`, `http-gzip`, `report`,
  `road-tiles`, `floor-tiles` — which indent their findings on purpose so a tool
  describing a problem is never mistaken for the engine failing.

- **Reporters now read an indented tool finding.** The `awk` rewrite already in
  the tree stops the reporter dying; it did not stop that family annotating
  "no reason printed", because the scan anchors. A second, indent-tolerant scan
  now runs — only when the anchored one came back empty, and only on an
  already-failing status. The scan that *decides* whether a clean run is dirty
  stays anchored, which is the distinction the indentation exists to draw.

- **`ContentDB._load_dir` sorts its listing.** `DirAccess.get_next()` returns
  filesystem order, and NTFS and ext4 do not agree: every content dictionary had
  a different insertion order on the runners than on the machine the game is
  verified on. Most callers already sort what they take out; the ones that do
  not would get a *different answer* on one platform rather than an error. Now
  the Linux order equals the Windows one, so CI exercises what was verified.

- **`crowd_check` runs on Linux again, as a step that cannot fail the build.**
  CLAUDE.md records re-enabling it as an owner's call because the cost of being
  wrong is a red main. A `continue-on-error` step that annotates a notice either
  way removes that cost rather than accepting it, so the next push answers a
  question that has been open since 2026-09-02. Promoting it back into the load
  gate remains a deliberate decision, to be made against a Linux result.

- **CLAUDE.md's starting-capital section was stale and wrong in the expensive
  direction.** It described `Balance.STARTING_GOLD = 150` and invited moving the
  constant "freely under that ceiling". The owner reverted that the same day it
  was written — recorded in `ROAD_TO_RELEASE.md` §4b — the constant is `0`, and
  `_test_opening_envelope` asserts `== 0` outright. An agent following the file
  every session is told to read first would have made a change a gate forbids.
  Corrected, with the correction itself recorded rather than quietly overwritten.

- Carried in from the working tree and verified rather than authored here: the
  portrait readability pass, the enemy/boss/wildlife idle animation batch (96
  new sprites, all declared in `ASSET_MANIFEST.md`), and the idle-priority
  contract in `enemy_walk_check` (attack tells outrank idle; frozen, stunned and
  dying bodies hold their exact pose).

## CONFORM

`run_tool.gd -- audit` — **46 / 46 automatic probes**, unchanged. Nothing here
adds or removes a v4 requirement; it is CI diagnostics, cross-platform
determinism and documentation accuracy.

## KILL Q

*Can the owner find out what broke a CI run without admin access to its log?*

Before this: no — a failing gate annotated `Process completed with exit code 1.`
and the reason was destroyed by the reporter meant to preserve it. After this:
yes for the mechanism, and the next push proves it end to end. Honestly: this
closes the *diagnosis* gap, not the underlying Linux failure. All 66 Guard
checks and the Release validation set pass on Windows at this tree, so the
reproduction has to come from the runner. I have not fixed a Linux bug — I have
made the next Linux failure legible.

## FILES

Created — `docs/GUARD_FAILURE_DIAGNOSIS_2026-09-07.md`, this report.

Modified — `.github/workflows/guard.yml` (indent-tolerant reason scan; the
reporting-only crowd step), `.github/workflows/release.yml` (indent-tolerant
detail scan), `tools/ci_validation_test.sh` (`tool_finding` fixture),
`game/autoload/ContentDB.gd` (sorted listing), `CLAUDE.md` (starting capital),
`docs/ROAD_TO_RELEASE.md`.

## ASSETS

None added by this session. The 96 idle sprites already in the working tree are
declared in `ASSET_MANIFEST.md` §5.2c, §5.3b, §5.10c and pass the production art
and enemy-walk gates. No asset-generation credits used.

## BLOCKED

- **Which gate failed on Linux, and why.** Needs a runner. The next push says.
- Real-device portrait typography, controller acceptance, minimum-spec rendered
  FPS. All need hardware this session does not have.
- Pushing is the owner's call and was not done.

## NEXT

Push this patch to `main` so Guard runs it. Read the crowd notice and the
annotation on any red gate; both now say something useful.
