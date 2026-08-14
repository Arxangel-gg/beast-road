# Beast Road — V4 Roads and Visual Polish Pass

Date: 2026-08-13

This pass advances the playable v4 foundation while preserving the existing
three-act run. It is implementation evidence, not a claim that the full v4
release checklist is complete.

## Player-facing results

- Preparation now waits for **Ride On**. During a between-wave breather, the
  player can start immediately for up to 30 bonus Gold, declining linearly to
  zero over ten seconds. The game then waits indefinitely with no penalty.
- Breath­ers cannot open until the active wave's spawn queue and living enemies
  are both clear. Hero movement remains available throughout Preparation.
- The opening remains forgiving, while Act 2 and Act 3 pressure rise through a
  smoother durability, damage, speed, density, elite and spacing curve.
- Beast gait is slower and more lateral, with a long mass-heavy wind-up,
  accelerated foot plant, momentary hold, camera impulse, character buffet,
  tiny hit-stop and recovery falloff.
- Roads are less visually dominant, nights remain moody without burying
  gameplay, terrain seams use a half-texel-safe repeat shader, and foliage
  derives its act palette from the active terrain art.
- The Command panel clears the skill dock. Preparation presentation is smaller.
  Raid Charge is named and aligned with its action instead of appearing as an
  unexplained bar.

## New v4 systems and content

- Five data-driven road archetypes: Provision Route, Relic Hunt, Chieftain
  Trail, Long March and Swift Passage.
- Three data-driven difficulty tiers: Guarded, Contested and Perilous.
- Road cards communicate travel distance, enemy body/durability, reward rolls,
  resource categories and their authored promise/consequence before selection.
- Road danger modifies wave body, durability, damage, speed, spacing and elite
  pressure. Road rewards settle only after completing the selected route.
- A completed Relic Hunt presents three duplicate-safe relic choices from the
  current region before the next road or act boss can begin.
- All 24 ordinary relics are regionalized at eight per act. Four new Rimebound
  relics and production icons complete the launch count.
- All 18 v4 regional enemy/elite assets were regenerated one at a time as
  transparent 192×192, canonical screen-right sprites at the approved elevated
  character angle. Runtime horizontal flipping therefore remains valid.

## Verification

- Godot editor/import and script parse: pass.
- Balance regression: pass (opening 3 bodies at 0.71 HP / 0.63 damage scale;
  Act 2 seven per lane; Act 3 twelve per lane at the authored late probe).
- HUD layout at 1920×1080: 83 visible widgets, zero overflow, zero overlaps.
- Graphics and colourblind live application: 11/11 checks pass; Low, High and
  Ultra visibly alter foliage, shadows, clouds and shadow-casting lights.
- Raid suspension/death/retry: pass.
- Torch pressure, hero minimum and relight: pass.
- Tower durability, repair, siege targeting, damage flames and step impulse:
  pass.
- Asset manifest: 187/187 files present, no magenta placeholders.
- Headless 30-second combat growth sample: 145 fps CPU-side, 0 hitches, node
  count -0.9%, orphans +0, memory -0.2%. GPU timing requires a windowed pass.
- GDD audit: 30/40 automatable release checks pass (75%). The remaining gaps
  include the Summit/Chainmaker, meta Tools/Sigils, Resurrection Draught, final
  regional terrain/backdrop naming and deterministic seed reproduction.

## Next production gate

Completed after this report was opened:

- Watchtower tier 1 reveals road threat values and next-wave lanes/formation.
- Tier 2 adds wave scale/intent and hidden road reward depth.
- Tier 3 identifies signature enemies and exact reward categories.
- Socketed foresight relics contribute one bounded intelligence tier.
- Named deterministic streams isolate roads, waves, raids, rewards, bosses and
  combat from cosmetic randomness.
- Main menu seed entry, persistent in-run readout, route history and debrief
  diagnostics allow a reported run to be reproduced.
- Seeds `314159265` and `271828182` completed automated six-crossroad itinerary
  simulations; replaying `314159265` reproduced all six road/tier decisions and
  ten wave plans exactly.

The next production gate is the Final Ascent and Chainmaker encounter.
