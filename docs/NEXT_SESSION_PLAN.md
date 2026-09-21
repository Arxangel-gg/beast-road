# The plan after the credit reset

Written 2026-09-20/21 with the weekly budget nearly spent, so the next session
starts from a decision rather than from a re-read. The reasoning is what each
item has to be built *against*.

---

## P0 - shipped in v0.47.2 (2026-09-21), and what it turned out to be

### 1. Enemies never attack anything

**Traced first, and the leading mechanism was not the cause.** Five traces on
HEAD - a body hand-driven, a body on the live field, four breeds against a
hero, the real director on a fresh account, and the real director on a copy of
the owner's own banked front - all showed the ordinary breeds walking up and
striking. What stood at the wall and never swung was **every Dune Burrower in
the wave**: a siege breed picks the nearest tower in its lane, the road is not
optional so it never leaves the route to reach it, and it arrives at the wall
still holding a target it cannot reach. `_pick_target`'s tower branch had no
reach condition since 2026-08-13; only the hero branch said "a body at the gate
hits the gate". The walk-in/teleport-out loop is real but only ever runs for a
body whose target is not the wall, and a body that walks up honestly stops at
its reach, well outside the padding.

**Fix:** one rule in `_pick_target` - in reach of the town and of nothing it
was aiming at, the town. **Gate:** `enemy_siege_check` (246 checks, on both
bars) walks all 68 breeds to a strike and stands every siege breed at the gate.
Planted, it names all six.

**Not reproduced:** "not the player". Four breeds attacked a hero on the road
at 176 units. What changed in v0.47.0 is the sanctuary rect: a Warden within
256 of the town (362 at a corner) is invisible and immune by the owner's own
rule. That should be said on screen - see P1.

### 2. A mount is thrown by Yuri's footfall

Read straight off the code: `_may_stay_mounted` refused the saddle while
`_beast_stun_left` ran, which every footfall sets. **Now:** a blow that takes
health throws the rider (`Hero.throw_from_saddle`), the saddle closes for
`MOUNT_HURT_COOLDOWN` (6 s), the ride button reads THROWN with the horse's own
picture inside an emptying ring, visible for that clock only, and the co-op
mirror throws on the same drop. `mount_check` is 119 checks; both planted
faults named.

**Still owed from the owner's mount ruling below:** faster mounts, a mounted
sprint that costs SP, per-mount rates. Untouched by the patch.

## P1 - the HUD tells you the town is dying

The screenshot reporting the attack bug shows the town at 24% with nothing on
screen saying so. Two readouts, neither of which changes a number:

- **Under attack**: an indicator wherever the player is, pointing at the town.
- **Imminent damage**: about five seconds of warning before a body reaches the
  wall. That is a telegraph, so `JuiceDirector.Priority.TELEGRAPH` applies - it
  is never damped and never quietened by distance.

The fog's bound applies to both: they may read and may never feed the AI.

---

## P2 - mobile

- **A mount control**, which phones have no way to reach today.
- **The overlap pass.** `layout_check` already drives both phone shapes, so
  these are measurable rather than a matter of taste. Run it and fix what it
  names.
- **Performance.** Its own session with `perf_check` and `perf_bisect`; the
  desktop frame is 16.6 ms on a 3070 Ti with no headroom, so a phone needs a
  real budget rather than a hope.

---

## P3 - systems and content

- **Raids and rifts**: procedural layouts, loot chests placed procedurally, and
  other interactables. `DungeonLayout` already cuts corridors and rooms; grow it
  rather than add a second system.
- **Crossroads as a map you travel.** Replace the background with the procedural
  tileset showing a fork per option, and have a miniature Yuri walk the chosen
  branch before the battlefield returns. Every later choice forks from where the
  last one left off.
- **Dragons.** Every overhead dragon flies as the *fire* sprite and only differs
  once landed - almost certainly one painting used for all four. Polish pass.
- **More enemy SFX.** `EnemyData.voice_sfx` exists and **67 breeds ship with no
  voice at all**; six archetype prompts are already written in the docs.
- **Settings reachable from the Hold**, adopted like every other door so the
  menu list and the walkable place cannot disagree.

---

## Owner rulings that re-cut a recorded bound

### Mounts are faster, and a mounted sprint costs SP

This re-cuts **two** sentences this project wrote down deliberately:

- `MOUNT_SPEED_CEILING` **is** `HERO_SPRINT_SPEED`, on purpose, so a mount bought
  sprint speed without the SP cost rather than new speed.
- *"the rider's SP is untouched, because a mount drinking from SP would make the
  pool the Warden sprints on a shared resource that nothing is tuning."*

**Ruled on both**: a mount is faster than the Warden on foot, a mounted sprint
**does** spend SP, the rate differs per mount, and every mount gets its own tuned
walk and sprint speeds.

**What survives untouched is the bound that made mounts safe at all**: the
dismount-on-attack rule. Mounted, the Warden may not swing, cast, loose, gather,
fish or work a seam, and the first press of attack puts them on their feet. So a
mount still cannot touch a number in a fight, and `curve_report` does not model
movement speed.

**The new bound has to be written before the code**, because the old one is gone.
What is being traded away is not damage - it is **how fast a Warden can be
anywhere on the field**, and with four roads that is a real defensive number. Two
rates per mount (walk, sprint) and an SP drain per mount, tuned against each
other, with a ceiling stated rather than implied.

**`mount_check` asserts SP is unchanged after a gallop.** That invariant is now
wrong and must be **amended deliberately and recorded** - amending a gate's
invariant is the one kind of change that makes every later run agree with the bug
it was built to catch. What replaces it: a mounted sprint spends SP at the
mount's own authored rate, an unsprinted mount spends none, and the ceiling is
measured through `Hero.move_speed()` rather than read off a constant.

### Character customization - approved, and it needs a bound first

A new persistent axis under working rule 7. Before a line of code: **what may a
customization change?** The answer that keeps it safe is *nothing but how the
Warden looks* - no attribute, no stat, no unlock, no currency. Additive save key,
absent reads as the default Warden, `SAVE_VERSION` unmoved.

**Scope it before buying generations.** The Warden is eight directions with idle,
walk, sprint and attack sheets; a naive paper-doll multiplies every option across
every sheet and is the one thing here that could eat the PixelLab budget. Pilot
one option on one direction before committing a batch - the discipline the mount
walk cycles were bought under after the template animations wasted a set.

### Save slots per profile

The one thing in this project **git cannot restore**. It changes the save shape,
so `SAVE_VERSION` moves, the backup path is exercised, and `save_backup_check` is
run **by hand** before any release that changes it.

---

## More enemies: 8-14 an act across all 11 acts

**Measured, not estimated.** Each region names **4-5** breeds today (`enemy_ids`
on `TerrainData`), across 10 regions, out of 68 enemy `.tres` including bosses,
elites, camp breeds and camp lords. Act XI is the Final Ascent.

Reaching 8-14 an act means roughly **doubling the region-native breeds** - about
30 to 40 new ones, since each region lists its own first and veterans after, and
a veteran counts for the act it is lent to.

**PixelLab budget, checked rather than assumed: 5,279 generations remaining,
refilling 2026-10-11.** A breed is a base sprite plus idle, walk and attack
animations, so 40 breeds is a few hundred generations. **PixelLab is not the
binding constraint** - the customization pilot and the dragon polish both fit
beside it with room left over.

**The expensive half is not the art.** Every new breed needs a facing recorded in
`enemy_facing_check`'s ledger, loops that close on their own pose, a walk that
does not drift off the base's ground line, a hide, a stagger footing, a voice,
and a kill value on the roster average. **A roster average drifts as the roster
grows** - twenty-one breeds authored below the average once read as a harder game
in every act and `curve_report` refused it. Re-run the curve after the batch.

Add them **region by region, gated each time**, never as one batch of forty.

---

## Standing lessons that apply to all of the above

- A guarantee is a property of every breed, road, act and region, or it is not a
  guarantee. Walk the table; never sample it.
- A model of a thing is not the thing. Photograph the output; measure the files
  actually in use.
- Trace before theorising when a state machine misbehaves.
- The release bar is a superset of guard's. Diff the two lists before a tag.
- Never delete an inbox after importing it.
