# Beast Road — Production Gameplay Pass

## Outcome

This pass targets the reported failure mode: the defence became solved around
the first boss, resources stopped mattering, and Acts 2–3 became idle waiting.
It also completes the requested mouse-wheel scope ladder and closes several
dormant gameplay contracts that were present in data but never executed.

## Difficulty and pacing

- Waves arrive every 20 seconds and deploy their pack quickly enough to read as
  a formation rather than a long trickle. Late packs overlap on that cadence
  instead of delaying the next wave until their entire queue has entered.
- Wave count resets its local ramp each act, while act multipliers ensure every
  new region is harder than the one before it.
- HP, damage and speed scale separately. HP grows fastest to create sustained
  lane pressure; damage grows more gently to preserve dodge and repair windows.
- Later acts mix in veterans from earlier terrain.
- Elite squad-leader budgets increase by act and distance. Multiple elites can
  now appear in a late wave.
- The final 100 distance of every act now increases both body count and stats.
- Night adds pack size, opens more lanes, and amplifies unlit-lane danger.

The automated regression target currently reports:

| Checkpoint | Enemies per attacked lane | HP scale | Damage scale |
|---|---:|---:|---:|
| Representative Act 2 night | 17 | 7.63× | 3.81× |
| Late Act 3 night | 42 | 18.40× | intentionally lower than HP |

## Enemy identity

- Glass-born are fast vanguards.
- Wardens carry their high-resistance tank role.
- Howlers visibly buff nearby enemies and fire committed, dodgeable projectiles.
- Burrowers now emerge inside the outer tower line.
- Terrain regeneration is applied in Ashfen.
- Enemies can finally snuff lane torches.
- Procedural walking animation is driven by real velocity: faster units bounce
  and sway harder; mass damps heavy units and strengthens their footfalls.

## Defence and economy

- Towers have five levels. Level 2 is the opening cap; Forge tiers unlock tower
  mastery levels 3, 4 and 5.
- Utility, range, burn, slow, freeze and blocker durability scale with upgrades,
  not only raw damage.
- Bulwark and Bastion durability is live. Enemies can destroy taunting blockers.
- Glacier/Bastion lane armour is live.
- Kill drops retain frequent reward feedback but pay fractionally, preventing a
  large wave from automatically financing every remaining purchase.
- Starting income, passive income and boss payouts were reduced.
- Emergency town repair is a repeatable late-run resource sink and comeback tool.
- Watchtower tiers now reveal next-wave lanes, pack size and elite likelihood.

## Presentation and navigation

- Mouse wheel follows Battlefield detail ↔ Battlefield wide ↔ Town ↔ Beast.
- Battlefield zoom interpolates between 0.62 and 1.18.
- Projectiles have a hot filament, shedding motes, elemental silhouettes,
  longer ribbons, impact light and rings.
- Hostile projectiles have a distinct red-orange trail, light and blast ring.
- Deep-night grading is darker and cooler, while contact/cast shadows are
  harsher and higher contrast.
- Foliage increased from 460 to 620 terrain-aware clumps.
- Replaced the Steppe Horde and Watchtower placeholders with production art.
- Replaced all 31 remaining relic, boss-core and spell placeholders plus Pause;
  the manifest now reports 122/122 real assets and zero placeholders.

## Automated release gates

`res://tools/balance_test.tscn` is part of the release workflow. It validates:

- Forge-gated five-level tower mastery and its resource sink.
- Act 2 and Act 3 count/HP/damage/speed ordering.
- overlapping late-wave cadence and its hard queue cap.
- enemy roles and Burrower insertion depth.
- the complete mouse-wheel scope route in both directions.
- live hostile projectile spawning.

The release gate also runs the asset reporter as a failing check: a missing,
mis-sized, orphaned or placeholder PNG now blocks publication.

The existing load, gameplay soak, launcher release-pipeline test and export gates
remain in place.
