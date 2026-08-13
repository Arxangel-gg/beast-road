# Beast Road v4 Foundation Pass — 2026-08-13

This pass begins the production migration from the working v3 game to the
authoritative `Game_Design_v4.md`. It intentionally delivers one coherent,
playable vertical slice instead of scattering partial hooks across the full v4
backlog.

## Delivered

- Explicit Preparation, Road Battle, Boss, Raid, Final Ascent, and Ended phase
  state in `RunState`.
- An 18-second protected Initial Preparation followed by deliberate **Ride On**
  confirmation and a second-confirm warning for uncovered roads.
- Preparation before each road leg and each act boss. Towers, repairs, town
  projects, relic sockets, and loadout-adjacent town actions are locked outside
  Preparation; targeting doctrines remain available in combat.
- Combat and planning telemetry are now separate. Preparation and crossroads
  no longer inflate active-combat run time.
- The battle-only Command meter, earned by deliberate hero hits on threatened
  roads, priority-target pressure, support interruption, and perfect dodges.
- Three targeted Command orders:
  - **Overdrive** — tower attack-rate and utility surge.
  - **Rally Road** — road-wide stagger plus temporary tower protection.
  - **Last Stand** — once-per-battle Town Hall invulnerability and tower attack
    reset.
- Tier-3 Command feedback, targeting copy, hotkeys, a full meter HUD, debrief
  telemetry, and four original transparent command icons.
- Wounds: an eight-second down, 50% return, 10% act-long maximum-HP loss, and
  run loss on the third down.
- Guaranteed pre-boss Hearthmend that clears Wounds, restores the hero, and
  performs a bounded Town Hall repair.
- Resurrection Draught runtime behavior and raid wounded-ejection behavior.
  The actual data-driven item/reward source is deliberately deferred with the
  broader economy/item migration.
- A bounded mouse-look camera fix. Off-window or synthetic cursor coordinates
  can no longer displace the battlefield beyond the playable composition.
- A gentler teaching envelope while retaining later pressure: two single-road
  teaching waves, two-road and then three-road introductions, eight waves of
  smoothly tapering protection, slower deployment cadence, and six bounded
  supply pulses. Act II/III durability and pack escalation remain intact.
- Deterministic 10-second Preparation after every fully cleared formation.
  Distance, construction and production pause with it; bosses cannot open a
  preparation overlay on top of surviving enemies.
- Live and persistent Video settings, labelled colourblind palette preview,
  and reversible shadow, foliage, cloud and particle budgets. High is the
  authored 60 FPS target; Ultra promotes all torch/unit cast shadows, PCF13
  softness, 175% particles, and 145% foliage for machines with headroom.
- Terrain de-tiling shared by Battlefield, Town, and Raid scopes removes the
  large repeated quadrant cross without softening the source paintings.
- Gradual torch suppression based on hostile mass, automatic recovery when
  pressure clears, a hero-protected minimum flame, and foot-point y-sorting.
- Four run currencies, bounded Market exchange, nine town plots, milestone
  building unlocks, per-currency telemetry, and a capped Treasury carry-over.

## Verification

- Project parses and boots under Godot 4.7.1.
- `balance_test.tscn` passes the opening envelope, three-act curve, explicit
  phase lock, all three Command orders, Wounds, Hearthmend, and Draught checks.
- `raid_suspend_check.tscn` proves enemy position and journey distance remain
  unchanged during a raid and validates 50%-HP wounded ejection.
- `save_backup_check.tscn` proves an unreadable save is copied byte-for-byte and
  a second mismatch cannot overwrite the original backup. Its fixture is
  isolated under `res://.automated_checks`; it never touches the player's save.
- `boot_check.tscn` confirms one active, mobile hero in Preparation, one after
  Ride On, 12 connected tower slots, and a working build panel.
- `torch_check.tscn` passes gradual dimming, recovery, hero bracing, snuffing,
  and relighting.
- `breather_check.tscn` proves one Preparation per cleared wave and no living
  enemies or spawn queue at the transition.
- `live_settings_check.tscn` passes 11 live-apply and persistence checks,
  including Ultra density/shadow promotion and colourblind semantic palettes.
- The real-renderer High gate at 1920x1080 on an RTX 3070 Ti passes at 86 FPS
  average, 13.0 ms p99, zero frames above 33 ms, bounded node/memory growth,
  and a 17.1 ms isolated checkpoint overwrite.
- Foliage retains 420 authored clumps on High while using one cached silhouette
  per clump and a 30 Hz wind update, replacing thousands of child nodes/draws.
- Tool-leak check passes for all shipped scripts.
- Asset report passes with 183/183 real manifest assets and zero placeholders.
- Full UI sweep passes, including the expanded results debrief.
- Preparation and Command were rendered and visually inspected at 1920x1080.
  Their ornate frames, target text, meter, all three order buttons, Wound label,
  and persistent navigation controls do not clip or overlap.

The recurring Windows root-certificate-store message is environmental and does
not affect any test exit code or local game behavior.

## Honest production state

The automatable v4 conformance score now stands at 28/40 (70%). This is not yet a
production-ready v4 game. The complete v3 loop remains playable, while the v4
foundation now makes combat more deliberate and gives attrition meaning.

The 24-node discipline vertical slice now exists: Blood, Holy, and Berserk data,
role-gated active slots, Mansion offers/training, six-node cap, rising-cost
Preparation respec, first combat adapters, and a complete generated icon family.
The launch combat-content budgets now include 12 authored regional regulars,
six regional elites and all ten tactical formations, with generated production
art and faction-bound role selection. Remaining production work includes deeper
bespoke effects for every passive and augment; road and relic budgets; the full
Oath/ransom/standard choice overlay; new terrain/background art; final ascent
and the Chainmaker; deterministic seeds; persistent Tools/Sigils; controller
parity; and broader minimum/recommended target-hardware certification.

## Next milestone

Implement the five road archetypes and remaining regional relics, then author
the remaining discipline passive/augment combat adapters and controller
focus-neighbour polish as part of the next integrated playtest pass.
