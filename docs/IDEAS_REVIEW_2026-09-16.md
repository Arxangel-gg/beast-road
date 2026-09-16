# Game juice: 200 forwarded ideas, triaged — 2026-09-16

The owner forwarded a 200-item prioritised juice list and asked for the best
version of it for Wilderhold, "for implementation, adaptation, or rejection as
you know best".

**The headline finding is the same one the last three forwarded documents
produced: a large share of it is already built here, under other names.** That
is not a criticism of the document — it was written without access to the
project, and it says so. But a plan that starts by re-listing things that shipped
months ago is a plan that spends the month rebuilding them.

So this is the list re-sorted against what the code actually does today.

---

## 1. Already built — do not rebuild

Roughly **ninety** of the 200 are shipped. The ones most likely to be
re-attempted by mistake:

| Forwarded | Already here as |
|---|---|
| #1 universal hit-response stack | `Enemy.take_damage` → recoil, hit flash, `EnemyData.hide` sparks/sound, `camera_impact` |
| #2 contextual hitstop | `HIDE_HITSTOP_SCALE` — armour holds the blade a beat longer than flesh |
| #3 enemy death satisfaction | element-marked deaths (fire chars, water shatters, air throws, earth drops and shakes) |
| #5 tower firing feedback | lean-toward-target, recoil kick, muzzle flash, per-tower `Shot` style and `juice_scale` |
| #6 projectile travel juice | five authored shot styles — bolt, lob with shadow, lance streak, spray fan, chain crackle |
| #7 enemy telegraphs | the telegraph *rule*: quake hum, tornado dust, meteor shadow, boss slam ring, `EnemyGroundStrike` |
| **#10 camera trauma system** | **`EventBus.camera_impact(at, weight)`, scaled by distance from what the camera watches** |
| #16 smart damage numbers | pop, arc, hang and tilt |
| #18 persistent combat decals | `ScorchMarks`, `blood_stain.gdshader`, `Tower._leave_rubble`, and `Craters` as of today |
| #19 directional blood/debris | `Vfx.blood(at, direction, …)` inherits the blow |
| #20 status transformation | Wet, burning, chill, brand — all visible on the body |
| #44 act-completion celebration | kill flash and slow, colour drain, ink-away, the felled thing held full-screen with its name |
| #59–#63 weather, disasters, day/night, torches | the whole Earth's Wrath layer |
| #66 world ambient motion | flames, foliage, wind, butterflies, fireflies, and pond fish as of today |
| #67/#70 wildlife personality, shiny treatment | states, families, the Wildblight, rank sheen, `Phenotype` coats |
| #92/#93 city damage and recovery states | built |
| #96 distance audio | `Sfx.play_at` — added 2026-09-15 |

**#10 deserves calling out twice.** It is the document's own S+++ architectural
recommendation and it has been in this game since 2026-09-13, emitted from the
one funnel every blow goes through, weighted by what the blow removed and by
distance from the camera. Anyone reading the forwarded list cold would build it
again.

---

## 2. Build next — the real gaps, in order

### Tier 1 — architecture that makes everything after it cheaper

**1. The Juice Director (#200) and `JuiceProfile` (#199).**
This is the one genuinely transformative item in the document and I agree with
its own placement of it. Today every effect is emitted at its call site: `Enemy`
decides its own sparks, `Tower` its own kick, `Meteor` its own rings. That is
*correct* and it is why the game feels as it does — but it means nothing can
answer "is this the most important thing on screen right now", and nothing can be
turned down as a set.

A director takes `hit`, `crit`, `kill`, `elite_kill`, `tower_fire`,
`legendary_drop`, `boss_break`, `wave_clear`, `extraction_start` and decides the
response from importance, distance, how much is already happening, the
accessibility settings and the frame budget.

**The bound it must be built under**, and it is the same one every feel change
in this project is held to: *a director may change how something is presented and
never whether it happened.* Turn it off and the run is byte-identical. That is
what `feel_check` already asserts for the sound, the lean and the death marks,
and it is what keeps a presentation layer from becoming a gameplay layer.

**2. Accessibility and budget as one set (#182–#195).**
Shake slider, flash intensity, damage-number density, effect opacity under
clutter, VFX priority (telegraph > hazard > boss > player > cosmetic), particle
and decal budgets. `Graphics` has the switches; what is missing is that they are
a *scale* rather than an on/off, and that the priority order exists at all. This
is Tier 1 because the director is the thing that enforces it, so they want
building together.

### Tier 2 — the moments this game is actually about

**3. Extraction as a sequence (#41, #42).**
The document calls this the crown jewel and it is right. Today the homecoming
pass is *a card with numbers on it* — a good card, built 2026-09-14 — and
turning for home is the biggest decision in a run. It should be: beacon, music
transition, pressure rising, the road behind you closing, and then a hard release
when you are out. This is the single largest felt gain available.

**4. Post-boss silence (#138).** One second of near-total quiet after a boss
dies, before the victory release. Trivial to build, enormous.

**5. Tower upgrade transformation (#23).** Placement already rises out of its own
foundation (2026-09-14). Upgrading — the thing a player does forty times a run —
still swaps a sprite.

**6. Resource vacuuming and loot physics (#32, #33, #34).** Drops that burst,
settle, and then magnetise to the player with escalating pickup audio and
rarity-specific tone. This is the cheapest addictive-ness in the document and
none of it is built.

### Tier 3 — clarity, which is juice that does a job

**7. Interaction icons over the head** — already requested by the owner
separately; this document's #84 agrees and argues against permanent glowing
outlines, which is the right call.

**8. Success and failure clarity for the crafts** — also separately requested.
#160's "players recognise *I can craft this now* from audio alone" is the version
worth building.

**9. Last enemies of a wave (#46).** A real annoyance today: the wave does not
end and there is no way to find the last body.

**10. Delayed-damage health segment (#74) and rolling counters (#72).** The
enemy bars already have the trail (`HEALTH_BAR_TRAIL_COLOUR`); the hero's does
not, and every resource number in the game teleports.

### Tier 4 — worth doing, not urgent

#65 foreground occlusion dither · #85/#86 chest physicality and rarity tells ·
#110 hand-drawn animation smears · #123 controller haptics · #148 co-op revive
escalation · #149 co-op pings · #172/#173 ultra-rare atmospheric moments ·
#48 vertical music remixing (the playlist layer exists; the *layering* does not).

---

## 3. Refused, and why

- **#137 rare-loot slow-motion.** This is a tower defence with a wave clock and
  a wall being hit. Slowing the world for a drop punishes the player for finding
  something good. The drop beam (#31) does the same job and costs nothing.
- **#181 automatic replay-worthy framing.** Taking the camera off the player
  during a fight they are still in is the one thing a defence game must not do.
  `MilestoneCinematics` already owns the once-ever beats, which is the honest
  version.
- **#167 nemesis-like recurring elites.** This is a persistence axis wearing a
  cosmetic's clothes, and CLAUDE.md already refused named persistent individuals
  for 1.0 on 2026-09-15 — the same ruling covers it.
- **#104 chromatic aberration.** On pixel art at this scale it reads as a
  rendering fault rather than an effect. #103's restrained additive bursts do the
  job.
- **#176 corpse push.** Corpses are drawn, not simulated; pushing them means a
  physics body per corpse for a frame of feedback nobody is looking at.

---

## 4. The principle worth keeping from the document

> Do not make everything equally flashy. If every arrow feels like a nuclear
> explosion, nothing feels important.

That is the best line in it and it is the argument for the Juice Director rather
than for two hundred separate effects. Wilderhold's dynamic range should run from
a footstep in mud to the moment the extraction beacon lights, and the only way to
hold that range is to have one thing deciding what is loud.
