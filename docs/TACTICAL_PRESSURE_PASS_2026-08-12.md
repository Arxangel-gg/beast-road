# Tactical Pressure Pass — 2026-08-12

This pass turns the production difficulty curve into authored tactical
encounters. The raw Act 2/3 pressure from v0.2.0 remains intact; waves now ask
different questions, towers accept player targeting orders, bosses change state
twice, and the results screen explains what happened during the run.

## Tactical wave vocabulary

Six `WaveArchetypeData` resources live in `game/data/waves/`:

| Formation | Tactical demand |
|---|---|
| Measured Advance | Neutral baseline using the act's normal lane progression |
| Rush | Fast, lower-health bodies test reaction time and anti-runner targeting |
| Siege Column | One dense, slow, armoured road with a Warden leader |
| Burrower Pincer | Opposite lanes plus infiltrators emerging inside the tower ring |
| Howling Pack | Howler leaders turn escorts into priority-target puzzles |
| Night Onslaught | Four-road deployment, strongly weighted toward night |

Archetypes multiply the continuous wave curve; they do not replace it. Their
per-lane count is normalized against the number of roads attacked, so a four-
lane formation spreads a comparable total threat budget rather than accidentally
quadrupling it. The immediate-repeat weight is reduced whenever another legal
formation exists.

Watchtower information now scales by tier:

1. formation name and attacked roads;
2. approximate per-road size and formation intent;
3. signature leader identity or elite warning.

## Tower targeting doctrines

Every built tower stores one targeting doctrine in `RunState`:

- **First** — closest to the town;
- **Strong** — greatest maximum health;
- **Fast** — highest current movement speed;
- **Special** — bosses and elite/role threats first.

The build/upgrade panel cycles the doctrine and explains it. The choice persists
through upgrades and scope changes but, like all run power, not between runs.

## Boss encounters

Every act boss has thresholds at roughly two-thirds and one-third health. A
phase transition:

- announces an authored phase name;
- visibly pulses the boss;
- increases its speed and damage by data-authored increments;
- opens reinforcements on roads other than the boss's own.

The Drowned Choir calls Howlers, Mirrorfang calls Burrowers, and the Rust Crown
levies Wardens. A lethal blow cannot trigger post-mortem phases.

## Run debrief

`RunState` now records run-local telemetry only—nothing is added to the
persistent save schema:

- elapsed time;
- resources earned and spent;
- towers built, upgraded, sold, and lost;
- town damage and breach count;
- peak lane pressure;
- wave formation counts and the signature formation.

The results screen presents these as a defence debrief. This makes future
balance sessions evidence-led without violating the GDD's strict persistence
rules.

## Release gates

The balance gate validates the tactical content, lane geometry, targeting
persistence, boss thresholds, lethal-threshold safety, and telemetry. The
release workflow performs an editor registration pass so new `class_name`
Resource types resolve correctly on a cold GitHub Actions checkout.
