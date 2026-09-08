# Tower firing continuation — 2026-09-08

## DONE

Reconciled against Claude's clean `22d40d3` checkout. The earlier enemy/boss
idles and all 21 wildlife gait upgrades were already integrated; none were
regenerated or overwritten. Claude's Linux Guard success and the separately
documented rendered performance failure remain distinct findings.

Four elemental towers now play authored firing/recovery poses: Pyre Cannon,
Arc Coil, Glacial Mortar and Grit Sling. The conventional `_attack_01..03.png`
paths are discovered by the shared loader. A single existing `kick` event
starts both the host and guest visual sequence, including when a remote target
has died before the notification arrives. Rapid firing restarts the sequence;
the ordinary idle resumes afterward. Shots, damage and attack intervals are
unchanged. No new network messages or EventBus signatures were introduced.

The image-generation skill guided source preservation and visual review; the
owner-requested PixelLab `animate_image` service produced the frames. Original
sprites at the pinned revision served as both endpoints. Full prompts and job
IDs are in `TOWER_FIRE_BATCH_2026-09-08.json`. Four jobs consumed **12 subscription
generations**, with **1,052 remaining** after this batch. No retries were generated.

All twelve continuation frames were reviewed together before installation.
They retain each tower's architecture and foot anchor. The mortar includes a
small visible mouth splash; no large screen-covering blast was accepted. The
new source PNGs total 204,597 bytes. Runtime adds no nodes, materials, shaders,
lights or particles. Texture selection is resolved once per frame instead of
setting idle and then replacing it with attack on the same frame.

`TOWER_FIRE_ANIMATION_SECONDS` defaults to 0.24 seconds. Update Manager's
existing Balance parser reports it as editable. Existing `structure_check`
and `structure_art_check` already run in Update Manager, Guard and Release,
so their new assertions require no parallel validation list to maintain.

## KILL Q

Do the towers visibly discharge without compromising their silhouette or
changing combat timing? The reviewed frames and focused runtime tests support
that for these four towers. This is a four-tower slice, **not** completion of
all 26 firing packages or certification of full production readiness.

Validation: **all 76 local Guard/Release commands now have clean results**.
The combined run finished 75/76: the only failure was the new manifest section's
size declaration, which the parser did not recognize. It was corrected to the
required `All 192×192, type T` form and the report was rerun cleanly: **1,532
manifest entries, 1,532 real files, zero placeholders**. The original suite
result remains in `.codex-godot-20260907/continuation-results.json`; the corrected
report summary is in `tower-manifest-rerun.log` beside it. `git diff --check`
also passes. The new suspension assertion ran in the clean structure gate.

An early test-fixture error (an off-tree battlefield) was corrected to use the
actual test run's field. The corrected structure test is clean. Headless
performance/growth checks do **not** certify rendered FPS or minimum hardware.

## FILES

- `game/scenes/battlefield/tower.gd`
- `game/scripts/Balance.gd`
- `game/tools/structure_check.gd`
- `game/tools/structure_art_check.gd`
- Twelve tower attack PNGs and their Godot import settings.
- `docs/ASSET_MANIFEST.md`, batch ledger, this report and release roadmap.

## ASSETS

Twelve real 192×192 transparent PNGs added at their final convention paths and
registered in the manifest. No placeholder requirements remain from this slice.

Remaining optional art expansion: the other 22 tower firing packages; hero
bow/crossbow directional animations; additional city damage reactions, foliage
varieties and boss phase poses. These are not silently declared complete.

## BLOCKED

The recorded 55 FPS at 1080p remains a release blocker. Minimum-spec hardware,
real-phone/controller feel and two-person cross-device acceptance also remain
open. The owner has been asked whether measured reductions to optional scenery
on the default preset are acceptable; no preset reductions were made here.

No commit, push, tag, export or publishing was performed. Passing local checks
does not guarantee a subsequent GitHub build or close the performance gate.

## NEXT

Resolve the default-quality/performance direction before expanding the next
visual batch beyond this verified four-tower slice.
