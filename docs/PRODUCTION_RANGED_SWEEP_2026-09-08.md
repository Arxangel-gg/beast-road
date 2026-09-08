# Ranged collision continuation — 2026-09-08

## DONE

Reconciled with Claude's `b217981` checkout: all 26 tower firing packages are
already integrated, and the torch draw-call optimization is retained. The owner
reports the browser works and asked to leave it alone. The unused local browser
probe was removed; no browser export, deployment or browser fix was attempted.

Before adding the hero's bow/crossbow sheets, inspection found two ranged-hit
faults. Arrows only tested their destination each frame, allowing fast shots to
skip targets. Wildlife hits used synthetic IDs based on the whole wildlife
system, so a piercing arrow could hurt one animal repeatedly on successive
frames and spend its pierce budget on that same body.

HeroArrow now sweeps its actual finite travel segment, orders enemy and wildlife
contacts together, and remembers each body's stable instance ID. Impacts occur
at first contact, not at the frame endpoint. Flight is clipped to the weapon's
remaining range. Dead wildlife does not intercept the shot. The wildlife query
uses the visual body anchor rather than the Y-sort feet.

The query is read-only on all peers. Wildlife damage still goes through the
host-guarded `wound_sprite`; guests can resolve cosmetic impacts without local
damage or loot payouts. Existing enemy puppet damage guards remain unchanged.
No EventBus signature, network message, save schema, damage value, ammunition
cost or attack interval changed. No new tuning constant is needed: hit radius
still uses `Balance.HERO_ARROW_HIT_RADIUS`; range and speed remain resource data.

## KILL Q

Does a fast arrow hit the first body crossed, once, within range? Executable
regressions cover a 0.2-second hitch crossing two animals, five frames overlapping
one animal, an enemy intercepting ahead of wildlife, impact placement, range
clipping on a one-second frame, and live/corpse wildlife query behavior.

Passed cleanly: game boot, ranged_check, regression_check, wildlife_spawn_check,
coop_heroes_check, coop_world_check, raid_suspend_check and weapon_vfx_check.
Update Manager's publish_contract_test also passes. These are targeted local
checks, not a new complete CI run, rendered benchmark or publication.

## FILES

- game/scenes/battlefield/hero_arrow.gd
- game/scripts/systems/wildlife.gd
- game/tools/ranged_check.gd
- game/tools/regression_check.gd
- docs/ROAD_TO_RELEASE.md
- This report.

## ASSETS

No asset changes or generation spending in this projectile patch. The earlier
queued tower jobs were integrated and reviewed by Claude; they were not
generated again. Hero bow/crossbow animation sheets remain outstanding.

## BLOCKED

No blocker to this collision fix. Minimum-spec hardware and real-device/co-op
acceptance remain separate production tasks. The browser is not being treated
as a currently reproduced blocker after the owner's confirmation.

## NEXT

Generate and integrate the hero bow/crossbow directional animation sheets,
preserving immediate shot timing and shared co-op input behavior.
