# Portrait readability and CI diagnostics — 2026-09-07

## DONE

Confirmed v0.6.2 is published with nonempty Windows, launcher, web and Android
assets. Release and Android workflows succeeded. The separate Guard workflow
failed at “Load the game, the launcher, and the menu”:
https://github.com/Arxangel-gg/beast-road/actions/runs/34132878628

This subsequent patch is local and unpublished:

- Portrait touch menus use a 900-unit canvas without changing battlefield or
  landscape scaling. Main-menu title, scrolling actions and footer no longer
  compete for the same space.
- RichTextLabel scales all five font faces correctly and restores inherited
  versus overridden sizes when touch mode changes, without compounding.
- Codex avoids double scaling and refits on live rotation with its Close
  control visible.
- UI_PORTRAIT_MENU_WIDTH lives in Balance.gd and was verified editable through
  the Update Manager tuning parser.
- Menu regressions cover physical touch targets, rich-text sizing, rotation,
  scrollbar dragging, tracking and diagnostics reachability.
- Font coverage now includes authored scenes and data: 550 files checked
  against 1,253 bundled glyphs.
- Both CI workflows use failure reporters that survive strict-shell empty
  matches and long logs. A new shared shell test checks 14 failure/success
  fixtures. This is an independently found diagnostic defect, not a proven
  explanation for the historical Guard failure.

Verification: 75/75 combined local Guard/Release checks and 11/11 final focused
checks passed with zero Godot errors or warnings. These include co-op/WebRTC,
save migration, content, combat, soak checks and rendered phone layouts.
Publisher contract checks, 14 shell fixtures, YAML parsing, syntax checks for
26 workflow shell steps and git diff whitespace checks also passed.

Tests used an isolated local profile, not the player's live save. No local
exports, commit, push, tag, publishing, restart or TeamViewer changes occurred.
No EventBus contract changes were needed.

## KILL Q

Are portrait menus readable and is publishing fully cleared? Rendered phone
checks support the readability improvement and all local gates pass. Actual
device/controller acceptance and minimum-spec rendered FPS remain unverified.
The prior Linux Guard failure cannot be declared resolved without its log.

## FILES

- game/autoload/ScreenFit.gd
- game/scripts/Balance.gd
- game/scripts/systems/ui_metrics.gd
- game/scenes/ui/main_menu.gd
- game/scenes/ui/codex_screen.gd
- game/tools/menu_layout_check.gd
- game/tools/font_glyph_check.gd
- .github/workflows/guard.yml
- .github/workflows/release.yml
- tools/ci_validation_test.sh (new)
- docs/RELEASING.md
- docs/ROAD_TO_RELEASE.md
- This report (new)

## ASSETS

None. No new placeholder requirements or asset-generation credits used.

## BLOCKED

GitHub's public log endpoint refused access. Access through stored credentials
was blocked by the permission reviewer and was not performed. The user has
been asked to attach the failed Guard job log. No credentials are needed in
the attached log; redact any secrets.

## NEXT

Inspect the failed Guard job log before preparing the next publication.
