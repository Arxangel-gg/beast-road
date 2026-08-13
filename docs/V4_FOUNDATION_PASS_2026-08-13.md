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
- A gentler teaching envelope while retaining later pressure: four single-road
  teaching waves, smaller/slower opening packs, slower deployment cadence, and
  a modest opening supply increase. Act II/III durability and pack escalation
  remain intact.

## Verification

- Project parses and boots under Godot 4.7.1.
- `balance_test.tscn` passes the opening envelope, three-act curve, explicit
  phase lock, all three Command orders, Wounds, Hearthmend, and Draught checks.
- `raid_suspend_check.tscn` proves enemy position and journey distance remain
  unchanged during a raid and validates 50%-HP wounded ejection.
- `save_backup_check.tscn` proves an unreadable save is copied byte-for-byte and
  a second mismatch cannot overwrite the original backup. Its fixture is
  isolated under `res://.automated_checks`; it never touches the player's save.
- `boot_check.tscn` confirms zero active heroes in Preparation, one after Ride
  On, 12 connected tower slots, and a working build panel.
- `torch_check.tscn` passes.
- Tool-leak check passes for all 71 shipped scripts.
- Asset report passes with 126/126 real manifest assets and zero placeholders.
- Full UI sweep passes, including the expanded results debrief.
- Preparation and Command were rendered and visually inspected at 1920x1080.
  Their ornate frames, target text, meter, all three order buttons, Wound label,
  and persistent navigation controls do not clip or overlap.

The recurring Windows root-certificate-store message is environmental and does
not affect any test exit code or local game behavior.

## Honest production state

The automatable v4 conformance score moves from 6/39 to 11/39. This is not yet a
production-ready v4 game. The complete v3 loop remains playable, while the v4
foundation now makes combat more deliberate and gives attrition meaning.

The largest remaining production systems are the four-resource economy and
Market; nine-building town; 24-node discipline system; full enemy, elite,
formation, road, and relic content budgets; Oathbound resolutions; authored
regions; final ascent and the Chainmaker; save migration; deterministic seeds;
rebinding, controller parity, colourblind support; and target-hardware
performance/certification gates.

## Next milestone

Implement the four-resource economy and nine-building town as one atomic
migration, including bounded Market exchange and compatibility conversion for
the current single-resource run state. Do not split UI labels from transaction
logic or save migration: all three must land together so no intermediate build
silently spends the wrong currency.
