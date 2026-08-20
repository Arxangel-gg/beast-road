# Beast Road — production release audit

Date: 2026-08-20  
Target: Godot 4.7.1, Windows and web  
Sources: current worktree, Claude Code transcript, `Game_Design_v4.md`,
`GDD_Master.docx`, release workflows, automated gates, and fresh rendered
screenshots.

## Verdict

The game is a substantial playable production candidate, not a release
candidate yet. Its systems and content skeleton are unusually complete:
44/44 automatable conformance probes pass, all 585 manifest assets are present
and non-placeholder, the three acts and summit exist, and the release pipeline
builds Windows, launcher and web artifacts.

It must not be advertised as production-ready until the P0 list below is closed.
The largest gaps are not another combat mechanic. They are a blocked live
leaderboard, final in-motion structure-art acceptance, a visibly weak battlefield
ground pass, mobile-web controls, full-session human validation,
localization/accessibility closeout, and publishing/legal work.

“AAA” is a quality bar, not a switch that code coverage can turn on. Reaching
that bar here means blind playtest footage, art direction, frame pacing, input,
copy, recovery paths and commercial packaging all surviving review. Automated
conformance proves presence and invariants; it does not prove taste, clarity,
balance or delight.

## What Claude had completed before the handoff

- Replaced every manifest placeholder: 405/405 assets report as real art.
- Added the authored 45×45 battlefield layout, routing, regional ground/road
  sets, torches, foliage expansion, weather, shadows and visual settings.
- Added authored beast idle/walk frames and the three side-scope backdrop sets.
- Completed web export and GitHub Pages release jobs.
- Added persistent capped hero progression, gear/stash/blacksmith and campaign
  tiers under the 2026-08-20 owner amendment.
- Completed the audio library, raid terrain/chests/keys, and most visual gates.
- Began the leaderboard: score model, Supabase client, debrief submission row
  and initial board UI existed but were unfinished and unverified.

This audit hardened and completed the local leaderboard path, but the remote
service remains blocked as described below.

## Verified in this audit

- Cold game and launcher load: no project warning or error outside the sandbox.
- GDD audit: 44/44 automatable rows; seven human rows remain deliberately open.
- Manifest: 585 rows, 585 files, zero placeholders.
- PixelLab structure package: 26 tower loops and 27 building-tier loops, all
  four poses on 192×192 transparent canvases. The 53-package size/alpha/anchor/
  silhouette gate passes, and the runtime keeps transform motion only as a
  missing-art fallback.
- Building growth: 18 distinct tier-two/tier-three bases now replace scaling one
  sprite, and all nine buildings change visibly through three tiers.
- Foliage: region-painted horizontal ferns ship for jungle, desert and snow on
  the existing 32-band batched rendering path.
- Shipped-script leak: 101 scripts, none depend on excluded tools.
- Road-tile connectivity, authored grid and three-route lane geometry pass.
- Balance, curve, menu, leaderboard, audio, torch, raid layout, raid suspension,
  seed reproduction, live settings, structures, disciplines and layout pass.
- Save version 6 backup/migration fixture passes all five cases without touching
  the player's save.
- Short soak, 45-second torch-snuff soak and 45-second memory-growth performance
  gate pass. The headless timing number is not a GPU benchmark.
- The fresh post-animation 120-second real-renderer High/1920×1080 gate passes
  on the developer's RTX 3070 Ti at 62 FPS average, 19.7 ms p99, 29.9 ms worst,
  zero >33 ms hitches, +0 orphans, +0.4% nodes and +0.2% memory. This qualifies
  that machine, not minimum spec.
- Launcher failure tests now use a repository-local fixture rather than the real
  `%LOCALAPPDATA%\BeastRoad` install and pass without touching an installed game.
- Fresh 1920×1080 UI sweep covers menu, settings, leaderboard, crossroad, win and
  loss. It found the new leaderboard footer pushing the exit action below the
  screen; the footer was re-budgeted and both results screens were recaptured
  with every action visible.
- Update Manager tuning now includes the authored structure-frame rate alongside
  the existing Balance/UI/graphics constants, sound mix, engine keys and 17
  content-resource groups. Its publish preflight also runs the 53-package art
  gate. Surgical write and publisher-contract tests pass.
- The night gate now maps authored canvas coordinates through the real display
  stretch before reading pixels; five corrected 1440p runs pass at minimum
  brightness and emit a frame for human review.

## P0 — must close before a paid production release

### 1. Make the leaderboard a real, operated service

Local state: implemented. The client now has bounded/sanitized rows, per-tier
boards, unique submission IDs, idempotent retries, a bounded offline outbox,
headless isolation, menu/browser UI and automated tests.

Remote state: blocked. A live REST read returns HTTP 402 because the Supabase
project is service-restricted after exceeding its storage quota.

Remaining work:

- Restore the Supabase project by reducing storage or changing its quota/billing.
- Apply and review the schema, unique `submission_id`, grants and RLS policies in
  `docs/LEADERBOARD.md`.
- Prove live empty-board, non-empty-board, insert, duplicate retry, offline queue,
  reconnect flush, 4xx/5xx, timeout and browser CORS cases.
- Load-test enough concurrent reads/inserts to set a real launch quota and alert.
- Add moderation/report/removal and a privacy/retention statement for published
  player names.
- Choose whether this is explicitly a community/unverified board or build a
  trusted scoring service. The current offline Godot client is tamperable; RLS
  protects the database, not the truth of a submitted score.
- Rotate any credential that has been exposed somewhere it was not intended to
  be public. The shipped client may contain only the public anon key and must
  rely on least-privilege RLS; no service-role secret may enter the repository.

Exit proof: live production round trip from Windows and web, duplicate retry
creates one row, anonymous users cannot update/delete rows or select unintended
tables, and an outage never blocks debrief or menu navigation.

### 2. Complete in-motion acceptance of the PixelLab structure package

Implementation state: complete. PixelLab generated four-pose packages for every
one of the 26 towers and all three tiers of all nine buildings. Higher building
tiers have distinct permanent architecture rather than a scaled tier-one image.
All 180 new art files are in the manifest and imported. Runtime lookup, phase
scatter, beast-step composition, fallback behavior, tuning exposure and the
53-package release gate are implemented and passing. The reproducible prompt and
correction contract is recorded in `STRUCTURE_ART_PIPELINE.md`.

Remaining work:

- Capture all tower families and every building tier at gameplay zoom, at night,
  under weather and under maximum effects.
- Run the owner/blind-reader role-and-tier identification review and regenerate
  any package that fails readability or art-direction judgement.
- Confirm loop continuity by eye in the running game; the automated gate proves
  stable bounds and anchors, but cannot judge a distracting material motion.

Exit proof: a blind capture clearly identifies tower element/role and building
tier without UI labels; no loop pops, feet slide, pivots jump or instances pulse
in unison.

### 3. Rebuild the battlefield environment pass

The fresh authored-map screenshot is functionally readable but not release art:
large black/green/tan patchwork, harsh seams/noisy black streaks and repeated road
texture dominate the frame. This is currently the largest visual gap between the
game and its references.

Remaining work:

- Replace or repaint the Wang ground/road set to eliminate black void-like seams
  and obvious 64-pixel repetition while preserving exact connection masks.
- Add bounded procedural variation inside each road and ground mask, not a new
  procedural layout.
- Finish the foliage variety/density art-direction pass for desert and snow as
  well as jungle; verify fern roots, shadows and y-sort at every camera zoom.
- Rebalance foliage clusters around buildable plots, junctions and telegraphs so
  decoration never hides placement, enemies, projectiles or health bars.
- Re-stage the raid field, whose current capture reads sparse and dark, while
  preserving ramp/chest/key navigation.
- Run the five-night visibility pass again after every ground/foliage repaint.

Exit proof: all three acts read as distinct authored places in blind footage,
tile repetition is not the first thing noticed, and road/enemy separation passes
at minimum brightness.

### 4. Close every manual core-loop and balance acceptance row

No automated soak substitutes for the GDD's 55–65 minute uninterrupted run.

Remaining work:

- Complete fresh-account win and loss paths: splash → menu → all four scopes →
  three acts → summit → ending/Endless choice → payout → menu.
- Run at least one full controller-only session and every scope transition in
  both directions; include pause, rebinding and reconnect.
- Run the fresh-account Standard clear with no lucky relic or specific unlock.
- Test every discipline against multiple elemental tower families and all three
  regional bosses/Chainmaker.
- Collect onboarding, first-clear and expert playtests. Measure survival, idle
  time, tower/discipline/relic pick rates, deaths, economy leftovers, run length
  and abandonment.
- Prove acts II/III still demand movement, spending, targeting, Command and route
  decisions rather than passive tower accumulation.
- Resolve every severity-1/2 defect and document accepted lower-severity risk.

The breather harness exposed a watchdog path that could open Preparation on a
living ranged enemy. The watchdog now counts HP changes as active combat and its
last-resort recovery resolves stranded enemies through the normal death path
before emitting `wave_cleared`. The 180-second regression now passes with three
waves and a breather after each completed wave.

### 5. Make the web target genuinely playable on mobile browsers

The Web preset exports, but the project contains no touch input, virtual controls
or mobile interaction layer. “Builds for web” is not “playable on mobile.”

Remaining work:

- Design touch movement/aim, dash, attacks, spells, scope wheel, tower placement,
  hover-equivalent tooltips, scrolling and back navigation.
- Adapt hit targets and information density for phone/tablet safe areas and
  portrait/landscape policy; define the minimum supported viewport.
- Test iOS Safari and Android Chrome on real devices for memory, audio unlock,
  suspend/resume, soft keyboard, WebGL context loss and leaderboard CORS.
- Decide whether mobile browser support remains a 1.0 promise. If yes, this is a
  P0 feature; if no, amend §54 and the store/README copy before launch.

### 6. Finish release engineering and real-machine qualification

- Run the 120-second windowed 1920×1080 High-quality performance gate on minimum
  and recommended hardware, not only the developer's RTX 3070 Ti.
- Establish and publish minimum/recommended CPU, GPU, RAM and storage.
- Test exported artifacts, not source scenes: clean install, update, rollback,
  corrupt/interrupted download, offline launch and self-update on a machine with
  no Godot, developer tools or prior user data.
- Test Windows scaling at 100/125/150/200%, ultrawide and the minimum supported
  resolution. Verify text, focus, tooltips and modal escape routes.
- Exercise migration from every actually published save version, including
  forward-version rejection and downgrade backup.
- Rehearse the workflow on an untagged dispatch, inspect Windows/web artifacts,
  then tag only after a signed checklist. Do not use a release tag as a test.

### 7. Complete localization, accessibility and copy lock

There are no `.po`/`.pot` catalogs and no translation calls; at least 126 UI text
assignments are literal. M7's localization and pseudo-localization gate is open.

- Extract every player-facing string into data/localization keys, including UI,
  tutorials, results, ending, errors and leaderboard states.
- Run pseudo-localization at +40% length, accented glyphs and right-to-left stress
  even if 1.0 ships English-only; this is layout QA as well as translation prep.
- Add/verify UI scale, keyboard-only navigation, focus visibility, remap conflicts,
  colorblind distinction beyond color, reduced motion, screen-shake zero, flash
  safety and readable minimum brightness.
- Copy-edit all faction, boss, summit, node and item names before localization
  lock; remove superseded `captive`/shackle framing from player-visible art and
  terminology. Current Oathbound text is revised, but the three leader sprites
  still show kneeling bound figures and the UI icon is visibly a pair of cuffs.
- Review title-card and generated-art typography for legibility and licensing.

### 8. Complete commercial, legal and credits work

- Clear the final product title and trademarks in launch territories.
- Decide price, launch window, supported OS/browser matrix and age/rating target.
- Produce store capsules, screenshots, trailer, description, accessibility notes,
  support contact and press kit from the final build.
- Write privacy/retention text for the leaderboard and analytics, terms/code of
  conduct for public names, and a deletion/contact path.
- Inventory every font, audio, PixelLab/ImageGen/other generated asset and third-
  party dependency; archive source/license proof and required notices.
- Replace the minimal in-game credits with complete human, tool, engine, asset,
  music/audio and license credits.
- Confirm repository visibility remains compatible with the unauthenticated
  launcher API, or redesign the update service without embedding a token.

## P1 — production polish required for the intended quality bar

- Finish milestone cutscenes: regional transitions and boss introductions, not
  only opening/ending screens.
- Replace the static, painterly main-menu key art with the requested animated
  pixel-art presentation and verify title/button contrast throughout the loop.
- Complete the global “juice” matrix for fire, impact, land, death, destruction,
  upgrade, fusion, loot, Command, boss phase, objective and completion events.
- Complete loot diversity and remaining currency/supply/relic world art; every
  pickup type must read before the label.
- Review Rank 4 relic-socket timing. The shipped first-clear bonus currently
  grants what v4 assigns to Legacy Rank 4; this is an explicit owner decision,
  not a code-cleanup task.
- Confirm town damage/scar progression and building tier silhouettes in every
  act, weather state and lighting extreme.
- Capture maximum-effect-load footage and verify projectile/telegraph hierarchy,
  colorblind modes, boss tells and damage readability.
- Finish codex/glossary content and ensure every authored enemy, relic, spell,
  discipline, road, weather and building has final copy and icon presentation.
- Review audio loudness on speakers/headphones, ducking during dialogue/ending,
  loop seams, controller UI cues and web/mobile audio behavior.

## P2 — hardening and maintainability before declaring the build “perfected”

- Split oversized responsibility clusters after behavior is locked: `hud.gd`
  (1,895 lines), `battlefield.gd` (about 1,370), `RunState.gd` (1,199),
  `settings_panel.gd` (818), `MetaState.gd`/`enemy.gd` (about 700 each) and
  `wave_director.gd` (about 650). `Balance.gd` is large by design, but the others
  exceed the project's one-responsibility/400-line rule.
- Keep the new content-resource tuning parser conservative. Add schema-aware
  min/max/enum validation so an Update Manager edit cannot create a valid-looking
  but nonsensical `.tres` value.
- Add the leaderboard and results layout to CI screenshot-diff or geometry gates;
  the visual sweep currently requires a local rendered review.
- Add a deterministic watchdog recovery test that does not take three minutes,
  while retaining the full breather simulation as a release test.
- Move remaining player-facing strings out of logic and rename legacy internal
  captive IDs only through a documented save/data migration if the owner wants
  the internal vocabulary cleaned as well.
- Add crash/error reporting appropriate to the privacy policy, release-channel
  version stamping in all reports, and an issue template containing diagnostics.
- Review CI action pinning, least-privilege permissions, artifact retention,
  dependency/license scanning and reproducible version metadata.

## GDD and production-document decisions still required

`GDD_Master.docx` was stale relative to the current Markdown. It has been
regenerated from `Game_Design_v4.md`; the leaderboard contradiction in §37 is
reconciled with the dated owner amendment. Structural validation passes, but
this machine lacks LibreOffice, so the regenerated DOCX still needs a visual
page render/review in Word or LibreOffice.

The remaining design contradictions are:

1. §54 still says Endless is out of scope, while the shipped summit explicitly
   offers Endless and the road-to-release says the owner requested it. Decide and
   amend the GDD; do not leave a release feature in permanent exception status.
2. GDD milestone and acceptance checkboxes remain mostly unchecked even where
   code exists. Close them only from evidence and signed human gates, not from
   the 44/44 symbol audit.
3. §54 says mobile-browser web is in scope, but there is no touch-control design.
4. Confirm whether leaderboard scores are community/unverified or competitive/
   trusted; the backend architecture depends on that choice.
5. Confirm Legacy Rank 4 socket timing and the final Oathbound visual framing.

## Recommended closure order

1. Keep leaderboard networking on the owner's explicit hold. When that hold is
   lifted, restore Supabase, deploy RLS/schema and complete the live test.
2. Resolve the five owner decisions immediately; they change acceptance criteria.
3. Run the blind in-game tower-role/building-tier and loop-motion acceptance on
   the completed PixelLab package; regenerate only rejected packages.
4. Repaint roads/ground/foliage and restage raids; run night and readability QA.
5. Implement mobile touch or formally remove mobile-browser support from 1.0.
6. Lock copy, localization, accessibility, credits and legal/store packages.
7. Run structured balance cohorts and the uninterrupted full-loop matrix.
8. Qualify exported builds on minimum hardware and a clean non-developer machine.
9. Fix all P0/P1 defects, document accepted P2 risk, visually review the master
   GDD, sign the release checklist, rehearse CI, then tag the release.

The release is ready only when every P0 is closed with evidence, every GDD §52
row is signed, no severity-1/2 issue is open, the final artifacts—not the source
tree—pass install/update/play/uninstall recovery, and a paying stranger can reach
every outcome without developer intervention.
