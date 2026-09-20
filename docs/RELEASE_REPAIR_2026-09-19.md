# Release repair — September 19, 2026

## Changes

- Mount/dismount is rebindable in Settings (default **H**). Controllers retain the Ride action. All four stable previews face southeast, render above the panel, and breathe subtly with their feet planted. Existing directional sheets and rider seating are reused.
- City protection follows the sprite frame. Health rejects direct damage, deferred wounds and forced damage deaths inside it; hostile knockback is rejected too. Enemies drop sheltered targets and can attack the city edge without crossing it. Wildlife deflect outward and receive an outward goal, including idle animals initially inside the base.
- Market comparisons remove old cards immediately and resolve the offered item's equipment slot. Legacy shuffled slot mappings can only resolve another already-equipped item of the correct slot.
- Extraction is available at every eligible crossroads after a completed wave, including with zero momentum. The existing withdrawal and host decision flow remains.
- Restored defenses are instantiated during battlefield setup. Tower health restoration now runs after the Health component exists. Checkpoints additionally preserve run inventory, ammunition, city upgrades/construction, relics, disciplines, roads, traps, barricades, statistics and run-local progression flags. Earth wrath and its strains reset. Version 1 checkpoints remain readable; fields not recorded in old checkpoints cannot be recovered retroactively. Wildlife, foliage and weather retain their existing regeneration policy.
- Atkinson Hyperlegible Next replaces the main UI font, with body weight 500 and button weight 700. Supported weights are 200–800. The OFL license is bundled; title and symbol fallbacks remain retained in memory.
- Act 2 count scaling changes from 1.20 to 1.12, HP from 1.30 to 1.20, damage from 1.12 to 1.06, and boss scaling from 2.10 to 1.90. Magic's unlock point remains after the Act 2 boss.
- Earth disasters select a quake, fissures, or traveling ground disturbances. Single/double/triple chances are 86%/12%/2% at low wrath and 62%/30%/8% at maximum wrath. Paths are committed before damage and hit each body at most once per path. Fissures use dark ground splits and existing earth debris art; trails advance along a marked course. Earth events retain their seismic resource zone. Map-wide hero damage falls from 18% to 6% of the reference hero pool; tower damage falls from 45 to 15, before magnitude scaling.
- Dragon world events follow curved routes, can land at a checked location, attack from flight or ground, and depart. Fire/frost/stone/storm variants have authored event weights of 5/3/2/1, tints and ignition behavior. Rarity weights are 75%/20%/4.5%/0.5%, with modest size and breath-strength increases. Only fire variants ignite foliage. Committed encounter and breath plans are relayed to guests. A departed dragon no longer blocks future events.
- Lightning cleanup now retains 64-bit Godot instance IDs, allowing return strokes and cleanup to find their own lines. Chain arcs have layered glow, bright cores and short fades, and are relayed to guests. Lightning-specific impact flashes, rings, sparks and dust finish during pauses and scope suspension. Delayed thunder belongs to its sky and is cancelled when that scene leaves. Cosmetic bolt jitter uses a separate random stream.

## Interface contract

Added typed EventBus signals `world_hazard(kind: String, payload: Dictionary)` and `coop_world_hazard(kind: String, payload: Dictionary)`. Co-op fact 84 carries host-authored ground paths, chain endpoints and dragon encounter plans. Guests render these facts without applying their damage again.

## Validation

- Mount: 95 checks.
- Restoration: 43 checks, including real visible tower nodes and their saved damage.
- Equipment comparison: 10 checks; additional all-slot and legacy mapping probes in the repair suite.
- Release repair: 36 checks covering sanctuary damage, clearance, hazard frequency, traveling damage and dragon landing/departure.
- Lightning lifetime: seven checks, including paused impact particles and suspended chain arcs.
- Font glyph coverage: passed.
- Sky: 852 checks.
- Wrath: 139 checks.
- Co-op transport/relay: passed, including the new hazard dictionary round trip.
- Balance: 34,649 assertions.
- Stable, lightning and earth-pattern screenshots rendered from actual scenes and assets.

## Release qualification still required

A complete Act 2 playthrough with a pre-magic loadout, longer multiplayer sessions, controller/mobile layout inspection and full campaign release qualification remain necessary. These fixes do not certify unrelated systems as production-ready. No build was exported locally or published.
