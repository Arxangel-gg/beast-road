# Production continuation — 2026-09-07

Unpublished working-tree patch on the local v0.6.1 baseline. No commit, push,
tag, export or GitHub deployment was performed in this session. No restart,
sign-out or TeamViewer changes were made.

## DONE

- Chronicle deeds can be tracked/untracked from the menu, retain the selected
  ID as a local setting, and show live progress on the battlefield. Pinning
  grants no reward and does not prevent other deeds from being earned.
- Guest progress and final deed payouts use validated host measurements, not
  zero-valued puppet counters. A relayed fatal team wipe no longer settles the
  guest before the final snapshot. Only the host's terminal fact settles it;
  duplicate, malformed and non-host terminal messages cannot pay twice.
- The guest's victory ending visibly waits for the host. Credits remain
  available; host settlement dismisses the ending and releases the pause.
- Settings → Data offers an explicit Prepare report / Copy report workflow.
  It previews a bounded, allowlisted build/platform/quality/run snapshot. No
  account names, room codes, addresses, logs or save files are collected by
  this report; nothing is sent automatically. Clipboard failure retains the
  selectable text rather than claiming successful copying.
- Shared scrollbars preserve the tuned keyboard increment while allowing
  pixel-accurate focus scrolling. The previous coarse Range step could leave
  the bottom of Track/Copy buttons clipped. Actual mouse clicks and thumb
  dragging are now exercised at both phone-shaped window sizes.
- UI copy is authored as ID-bearing GameData and registered in ContentDB.
  The content gate caught the initial Resource-only integration; corrected
  content now loads 363 files across 33 directories.
- New goal, diagnostics, audit-parser and mobile-menu gates are present exactly
  once in the Update Manager, guard workflow and release workflow; the
  publisher contract test enforces that parity.
- Optional Dropbox mirroring runs only on release tags. A mirror failure
  discards incomplete mirror metadata and does not prevent primary GitHub
  assets from publishing. Reused web filenames now revalidate rather than
  requesting immutable caching. Update Manager messages match automatic Pages
  deployment and distinguish confirmed desktop downloads from unconfirmed web
  deployment.
- The crowd regression harness uses seeded, ordered fixed-step fixtures and
  covers coincident starts, reversed insertion, negative coordinates and
  large-body separation. Linux re-enablement is deliberately not claimed.
- The audit reports 46/46 automatic probes and five manual acceptance rows.
  Annotated manual requirements no longer distort its counts; malformed
  probes remain failures. Minimum-spec documentation no longer claims 4×
  headroom from a 13–15 ms frame time.

## Verification

- 61 distinct Godot command configurations have clean final results: exit 0,
  no ERROR/SCRIPT ERROR/WARNING output. This covers the release checks, the
  Update Manager's foliage check, affected co-op/crowd checks, and additional
  rendered/layout configurations. The content check initially failed and was
  rerun after its fix; the initial lifecycle-test shutdown retention was
  removed by explicitly stopping audio and letting teardown finish.
- Includes the 210-second breather check, defeat/snuff soak, headless resource
  growth/checkpoint check, save migration and launcher release pipeline.
- Chronicle lifecycle regression uses the shipping director and relay for
  guest victory and defeat, including a fatal TEAM_WIPE before the final
  snapshot, then final rewards and duplicate-end rejection.
- Rendered menu interaction checks passed at 430×932 and 932×430. HUD/layout
  checks passed at 1920×1080 and both phone shapes, with rendered captures at
  desktop and landscape phone sizes. No measured overflow, unintended overlap,
  clipping or panel crowding was reported by the HUD checks.
- Publisher contract test, PowerShell parsing, two workflow YAML parses,
  24 shell-step syntax checks and `git diff --check` passed.
- Tests used project-local disposable APPDATA under `.codex-godot-20260907`,
  verified by Godot's actual user-data path. Generated logs and screenshots
  remain there, ignored by Git. Player progression was not used as a test slot.

## Contract / tuning

New typed EventBus fact: `coop_chronicle_progress(summary: Dictionary)`.
CoopRelay appends `CHRONICLE_PROGRESS = 46` without renumbering earlier facts.
The host sends final progress before RUN_ENDED on the existing reliable channel.

`Balance.CHRONICLE_SYNC_INTERVAL` defaults to 1 second and is editable in the
Update Manager's Tools and Sigils section. Final settlement does not wait for
that interval. `UI_SCROLL_STEP` remains the editable keyboard/wheel increment;
one-pixel scrollbar quantization is an implementation requirement, not tuning.

## KILL Q

Can a guest earn the same eligible deeds without premature or duplicate payout,
and can the owner catch this patch's regressions before consuming a release tag?
The lifecycle, UI and publishing-contract checks now say yes locally. This is
not an assertion of production certification or a successful cloud publish.

## FILES

Created: Chronicle text/progress service and gate; support diagnostics copy,
collector, panel and gate; audit-parser regression gate; this report. New
resources live in `game/data/ui`; scripts/scenes/tools follow existing folders.

Modified: ContentDB, EventBus, GameDirector, MetaState, RunState, project
autoload registration, Balance, Chronicle/ending/HUD/settings UI, co-op relay,
shared UI metrics, co-op/crowd/layout/menu/save-guard/audit tests, publisher and
its contract test, guard/release workflows, release and conformance docs.

## ASSETS

No sprite or placeholder requirements added. No asset-generation credits used.

## BLOCKED / remaining acceptance

No new design decision is required for this patch. Cloud export/deployment,
Linux crowd behavior, real multi-device co-op, controller parity and minimum-
spec FPS are not certified by this Windows pass. The checkpoint sample was
99.5 ms against its 100 ms budget: passing, but with little measured margin.

Portrait captures also show text smaller than comfortable reading size. The
geometry tests verify visibility and configured virtual touch targets, not
physical readability or device DPI. A dedicated portrait typography/scaling
pass remains necessary; do not mark mobile UX complete from these tests alone.

## NEXT

Run an unpublished GitHub Actions branch rehearsal before consuming a release
tag. Do not infer cloud publishing success from the local checks.
