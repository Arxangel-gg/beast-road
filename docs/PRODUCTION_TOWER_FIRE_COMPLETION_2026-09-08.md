# Every tower fires — 2026-09-08

Continues `PRODUCTION_TOWER_FIRE_2026-09-08.md`, which shipped a four-tower
pilot. This finishes the other 22 and corrects one claim in that report.

## DONE

- **All 26 towers now have three authored firing poses.** `structure_art_check`
  and `structure_check` both pass, and `run_tool.gd -- report` counts **1,598
  manifest assets, 1,598 with real art, zero placeholders** (up from 1,532).

- **The tree arrived failing.** The pilot report states "all 76 local
  Guard/Release commands now have clean results". That was not true of the tree
  as handed over: `_check_firing_package` was added to `structure_art_check` and
  fails any tower without three poses, and only four towers had them, so the
  gate failed on 22 towers. Verified by running it, not by reading the report.
  Pushing that would have reddened `main`.

- **Twenty packages were already generated and never staged.**
  `TOWER_FIRE_COMPLETION_2026-09-08.json` held their job ids; the frames had
  not been downloaded. Retrieval costs no generations, so those 60 frames were
  free. `tide_caller` and `zephyr_needle` appeared in no ledger at all and were
  generated from scratch.

- **Nine packages were rejected on review and regenerated.** Split by what
  caught them, because the split is the point:

  | caught by eye | fault |
  |---|---|
  | `shard_thrower` | frame 1 replaced the crystal with a white starburst |
  | `glacier` | crenellations changed shape between frames |
  | `tempest` | upper third bleached to white, losing the stonework |
  | `conflagration` | yellow streaks ran down the outer walls |
  | `gale_turret` | violet ring extended well outside the silhouette |

  | caught by measurement | fault |
  |---|---|
  | `bastion` | added ground debris put a frame **5px** below the base anchor |
  | `deep_freeze` | a side halo moved the horizontal centre **4px** |
  | `conflagration` (2nd try) | **garbled text** rendered below the base, **11px** outside the anchor |

  `deep_freeze` needed three attempts: the first drew a halo, the second drew a
  literal white ring, the third was clean. `bastion` and `deep_freeze` had
  already been *installed* from the eye-review pass — the anchor sweep is what
  found them.

- **A cache bug made the first remedial review a lie.**
  `stage_animation_batch.py` skipped downloading any frame whose file already
  existed. The rejected frames sat at exactly the paths the replacements wanted,
  so nothing was fetched and the new contact sheet showed the art that had just
  been rejected — indistinguishable from the model ignoring the prompt. It now
  writes the job id beside each frame and re-fetches when it differs.

## CONFORM

`run_tool.gd -- audit` — **46 / 46 automatic probes**, unchanged. This adds art
and a cosmetic playback path; it creates no new v4 requirement.

## KILL Q

*Do the towers visibly discharge without compromising their silhouette or
changing combat timing?*

For all 26 now, yes — with the caveat that "visibly discharge" was judged from
contact sheets at native resolution, not from play. Nothing about timing moved:
firing poses are texture swaps driven by the existing `kick` event, with no new
nodes, materials, shaders, lights or particles, and no new EventBus signal or
network message.

The honest worry is that **the gate cannot see art quality**.
`structure_art_check` checks size, ground anchor and the placeholder marker;
every aesthetic fault in the table above would have sailed through it. Five of
the nine rejects were invisible to it. CLAUDE.md §7 says a passing probe cannot
tell you whether a feature is good, and this is the clearest example of that the
project has produced: the gate went green on art with a starburst where a
crystal should be.

## FILES

Created — `TOWER_FIRE_REMEDIAL_2026-09-08.json` (job provenance plus the reason
each package was regenerated), this report.

Modified — `docs/ASSET_MANIFEST.md` §5.4c (rewritten from a four-tower pilot
section to all 26), `docs/ROAD_TO_RELEASE.md`,
`tools/stage_animation_batch.py`. Carried in from Codex and verified rather than
authored here: `game/scenes/battlefield/tower.gd`, `game/scripts/Balance.gd`,
`game/tools/structure_check.gd`, `game/tools/structure_art_check.gd`.

## ASSETS

66 new 192×192 transparent PNGs at their convention paths, all declared in
`ASSET_MANIFEST.md` §5.4c. **33 subscription generations** used across three
remedial rounds; 959 remaining, resetting 2026-09-18. The 60 frames retrieved
from Codex's existing jobs cost nothing.

## BLOCKED

The 55 FPS at 1080p remains the release blocker, and 78 more textures do not
touch it — see `ROAD_TO_RELEASE.md` §4 for the diagnosis. Minimum-spec hardware,
real-device portrait/controller acceptance and two-machine co-op remain open.

## NEXT

Owner's call on the frame budget: ship against a knowingly unmet §52
requirement, or spend an optimisation pass on the 15.4 ms floor.
