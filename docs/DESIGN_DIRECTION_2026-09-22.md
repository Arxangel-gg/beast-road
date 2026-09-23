# Wilderhold — where the design is failing, and how to fix it

Written 2026-09-22 after the owner's play report: *"act 3 and act 4 felt too easy
once I had enough towers up everywhere, the game became easy fast forward and sit
at base mode ... had me questioning whether it would even become a success"*, and
*"the map's pathing also too closely resembles a swastika"*.

This is a decision document. Nothing in it is built. Each section ends with a
recommendation and what it costs.

---

## 0. The honest read

The systems are deep and most of them work. What is failing is **the moment-to-
moment loop after the board is built**. From Act III on, a finished defence plays
the game for you, and fast-forward makes that obvious. Every other complaint —
polish, juice, "is this worth finishing" — is downstream of that one fact: a
player who is not being asked anything notices every rough edge, and a player
under pressure forgives most of them.

So the order matters: **fix the loop first, then the map, then the juice.** Juice
spent on a loop that plays itself is decoration on a screensaver.

---

## 1. P0 — the map reads as a swastika

**This is a release blocker, not a taste issue.** Four roads, each bending the
same rotational way around a centre, is a pinwheel with fourfold rotational
symmetry and no mirror symmetry — exactly the property that makes the shape read
that way. Store review, streamers and press will see it. It must change before
anyone outside plays it.

The cause is structural: `BattleGrid` lays the outskirts from **one lane-local
template rotated four times**. Rotation preserves handedness, so every road hooks
the same way.

Options, cheapest first:

| | Change | Cost | Risk |
|---|---|---|---|
| A | **Mirror alternate lanes.** Lay N/S from the template and E/W from its mirror image, so the four hooks pair up into two mirrored halves. The figure gains mirror symmetry and stops being a pinwheel. | Small: a mirror flag in the lane transform, the authored core's corridors mirrored for two lanes. | Every gate that walks routes, camps and anchors re-measures (grid, routes, camps, bounds). |
| B | **Closed rectangles per road** (the owner's idea): each road splits into two legs that run both sides of its quadrant and meet again, so a road is a loop rather than a hook. | Medium: a new outskirts template; routes gain real choice. | The same gates, plus the route-length bound. |
| C | **Procedural roads**: a seeded generator lays each run's roads as branching paths from the edge to the town, constrained to avoid rotational symmetry. | Large: generator, validation (reachability, lengths, build ground), and the Guide/art that assume a fixed map. | Highest; also re-opens v4 §54's cut of procedural layouts, which needs a ruling. |

**Recommendation: A now, B for 1.0, C only if replayability testing asks for
it.** A removes the shape in days. B is the better *game*: two ways into each
quadrant is a real routing decision for enemies and a real placement decision for
the player, and it answers §2 below as well.

---

## 2. The late game plays itself

Why it happens, from the code:

- **Towers scale on a capped ladder and never lose.** Once every road is covered,
  added pressure is absorbed by upgrades, and nothing threatens the board itself
  except rare siege breeds and weather.
- **The Warden is optional.** Fast-forward plus a built board means standing at
  the town is the correct play — the hero's best contribution is not being needed.
- **Enemy counts rise; enemy *kinds of problem* do not.** More bodies is a DPS
  check the board already passed.

What fixes it, in order of leverage:

1. **Enemies that attack the board, not just the town.** A share of every late
   wave targets towers (sappers, burrowers, flyers that ignore roads, shielded
   breakers). A board you must repair and re-place keeps the player moving.
2. **Objectives only the Warden can answer.** Per act, events the towers cannot
   solve: a caravan to escort, a shrine to hold, an elite that must be killed in
   melee before it reaches a road, a camp that reinforces the next wave if left
   standing. This is what makes the hero necessary and fast-forward costly.
3. **Wave modifiers that change the rules**, drawn from the wave library — flyers
   that skip the road, a wave immune to one element, a wave that splits at the
   fork. Each one invalidates a slice of a solved board.
4. **Fast-forward costs something**: a smaller early-ride bonus at 2x, or no
   loot magnetism, so it is a convenience rather than the dominant strategy.
5. **Longer, sharper bosses** with phases that demand the Warden.

**Recommendation: 1 and 2 first.** They are what turns "sit at base" into "run to
the east road, the sappers are on the wall". Both reuse existing systems: siege
breeds and `targets_towers` already exist; camps, rifts and the trail already
give the Warden places to be.

---

## 3. Polish and juice — where it actually shows

Not everything; the moments a player repeats hundreds of times:

- **Spells** have almost no presentation: no projectile, beam or impact of their
  own. Each spell needs a cast flash, a travelling piece, and an impact — the
  forge can make the sheets the same way it made the dragon breath.
- **The first hour's screen density.** Too many panels, numbers and readouts at
  once; the HUD should reveal itself as systems open (the Command panel now does).
- **Loot variety.** More kinds, more distinct silhouettes per slot, and uniques
  with a single memorable effect each (within the rule that effects move numbers
  `Modifiers` already resolves).
- **Audio** — act music for VI–X and boss themes are the biggest single gap; ten
  hours without music reads as unfinished.

---

## 4. Performance at peak waves

The frame misses 60 fps from Act III–IV peaks. Measured causes to expect, from
earlier profiling: per-body scripts (movement, crowd separation, targeting),
draw-call count from many small effects, and fog/climate stamps. The fix path is
the one this project has used before: profile a peak wave with `perf_bisect`,
take the top script, and budget per-frame work (enemy ticks at reduced rates when
off-screen, pooled effects, batched rings). A 15 fps cap now exists as a floor for
weak machines; it is not a fix.

---

## 5. Suggested plan

1. **Map A** (mirror alternate lanes) — removes the P0.
2. **Board-attacking enemies + Warden-only objectives** from Act III.
3. **Spell VFX** and **peak-wave performance**, in parallel.
4. **Map B** (closed-loop roads) with the enemy routing it enables.
5. Music, loot variety, outside playtesting.

Steps 1–2 decide whether the game is worth finishing; they are also the cheapest
way to find out. If a playtester is still bored in Act IV after them, that is the
signal to revisit the core loop rather than polish it.
