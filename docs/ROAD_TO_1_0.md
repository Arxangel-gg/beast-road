# Wilderhold — the road to a production-ready 1.0

Written 2026-09-21 with the weekly budget spent, as the single document to
review before work resumes. It supersedes nothing: `CLAUDE.md` is still the
working rules and the record of every decision, `docs/NEXT_SESSION_PLAN.md` is
the immediate ordering, and this is the whole surface in one place.

**It is deliberately uncomfortable in places.** A list of outstanding work is a
model, and a flattering model is worse than none.

---

## 0. How to review this with Fable 5.1

Hand it the document and ask it to attack, not to agree. The questions worth
forcing an answer to:

1. **What on this list is not actually needed for 1.0?** The fastest route to
   shipping is cutting, and this project's own history is that its best
   decisions were cuts (`Game_Design_v2.md` argues it well).
2. **What is missing from §7 — "not yet considered"?** That section is my own
   blind spot by construction. It is the section most likely to be incomplete.
3. **Which items are mutually dependent?** Several here look independent and are
   not: enemy variety, the curve re-measure, and Nightmare/Hell balance are one
   piece of work.
4. **What is the smallest version of §1 that a stranger would call finished?**
5. **Where am I wrong about the predicted reviews in §8?**

Ask it to disagree with a specific line and say why. A review that agrees with
everything has read nothing.

---

## 1. Where the project actually stands

**The loop closes.** Splash → menu → Walk or run → four scopes → ten acts →
Final Ascent → win/lose → payout → menu. Expeditions put the road down and pick
it up. Co-op seats four. The Hold is a place you walk in.

**173 gates** run at release (as `tools/sweep.sh` derives them), 171 at guard, and the release bar is a superset
(`roster_check`, `game_speed_check`, `town_alert_check`, `qol_check`,
`pad_focus_check`, `warden_look_check`, `forge_check`, `resource_reach_check`
and the 4K and ultrawide layout shapes joined on 2026-09-21; **v0.49.0** was
tagged on a 169/169 sweep that day and **v0.50.0** on a 173/173 sweep the next). Roughly 34,000 assertions in
`balance_test` alone.

**And almost nobody has played it.** That gap — between "the gates are green"
and "a person enjoyed this" — is the largest single risk in the project and
nothing on this list closes it except §6.

---

## 2. P0 — blocking, and currently shipped broken

| | What | Why it blocks |
|---|---|---|
| 1 | ~~**Enemies never attack** (v0.47.1)~~ **Shipped in v0.47.2.** | Traced, and the mechanism above was not it: siege breeds arrived at the wall holding a tower target they could never reach and stood there. One rule in `_pick_target`, gated by `enemy_siege_check` across all 68 breeds. "Not the player" was not reproduced; the sanctuary rect grew in v0.47.0 and was unsaid on screen - **said on entering since 2026-09-21** (`town_alert_check`). |
| 2 | ~~**Mounts thrown by Yuri's footfall**~~ **Shipped in v0.47.2.** | Dismount on health lost, `MOUNT_HURT_COOLDOWN`, the horse's picture in an emptying ring on the ride button, the co-op mirror throwing on the same drop. |

Both shipped 2026-09-21. The rest of this document is unchanged by them.

---

## 3. The release checklist, honestly scored

GDD §52 is the formal list. This is what is *real*:

**Solid:** the run loop, all four scopes, ten acts plus the ascent, raids,
rifts, dungeons, camps, forks, the crossroad draft, omens, Road Cards, gear with
nine rarities, affixes and sets, five attributes, four disciplines, mana, the
bow, five professions, gathering, farming, fishing, spirits, the pen, mounts,
the Hold, the Ledger, the market, the smithy, expeditions, act starts, the
Walk, the wrath/climate/weather simulation, the ecology with families and the
Wildblight, fog of war, the minimap, the Guide, achievements, the Chronicle,
save backup, co-op with rejoin.

**Real but unproven:** co-op over the internet at length; Nightmare and Hell;
the web build; the APK; anything on a machine weaker than a 3070 Ti.

**Closed 2026-09-21:** the two-process co-op gate's four guest failures. One was
real - the wildlife spawn fact was relayed with three of its four arguments and never
left the host - and three were the harness measuring a field still suspended under
the road-card draft. `coop_check` walks every relay binding against its signal's
arity now; `tools/coop_ui.sh` and `tools/coop_live.sh` both pass clean.

**Not real:** music for five of ten acts; boss themes anywhere; enemy voices.
(The Act X boss sprite, the mount idles and the Guide's mount page were listed
here on 2026-09-21 and were already on disk or landed that day - hash the folder
before believing a list.)

---

## 4. Content owed — silent absences

Nothing fails on any of these. They are only ever found by counting.

- **Act music**: 76 songs across acts I–V (11, 24, 24, 13, 4). **Acts VI–X have
  none.** Drop files at `music_act%02d_%02d.ogg`.
- **Boss themes**: **zero of eleven.** `music_boss_act%02d.ogg`.
- **Enemy voices**: `EnemyData.voice_sfx` exists; **67 breeds are silent.** Six
  archetype prompts are already written in `docs/SFX_PROMPTS.md`.
- **The reed frog** is owed a recording nothing on disk can honestly stand in
  for.
- ~~**The Last Anchor** (Act X boss) is a placeholder sprite.~~ Real art with
  idle, move and attack frames is on disk; the line above was stale when written.
- ~~**Mount idle sheets**~~ **Shipped 2026-09-21**: four mounts, eight
  directions, five frames, `mode: "v3"` with an `action_description`.
- ~~**A Guide page for mounts**~~ `data/guide/mounts.tres` and its photograph
  already existed.
- **Mix levels have never been heard in play.** 347 takes authored expecting to
  be audible and verified by nobody.

---

## 5. More enemies — the owner's ruling, sized

**Target: 8–14 breeds an act across all 11 acts.** **Shipped 2026-09-21 as the
owner's own table instead: 8 in Act I rising by one to 17 on the Terrace and 19 at the
summit (`Balance.ACT_UNIQUE_ENEMIES`), fourteen new breeds, the four road breeds no
region had ever listed, an authored `veteran_ids` per terrain, and `roster_check` (702)
holding every act to its count exactly and driving the real director's draw. The
Final Ascent is a full eleventh act on the Crown's own ground. The curve was re-measured
on a new account afterwards.** What follows is the sizing that was written before it.

Measured: each region names **4–5** (`enemy_ids` on `TerrainData`), across 10
regions, out of **68** enemy resources including bosses, elites, camp breeds and
camp lords. Reaching the target is roughly **doubling the region-native roster —
30 to 40 new breeds**, since regions lend veterans to one another.

**PixelLab: 5,279 generations remaining, refilling 2026-10-11.** A breed is a
base sprite plus idle, walk and attack animations, so forty breeds is a few
hundred generations. **The art is not the binding constraint.**

**The expensive half is everything after the art.** Each breed needs a facing in
`enemy_facing_check`'s ledger, loops that close on their own pose, a walk that
does not drift off its ground line, a hide, a stagger footing, a voice, and a
kill value on the roster average — **a roster average drifts as the roster
grows**, and twenty-one breeds authored below it once read as a harder game in
every act until `curve_report` refused the batch.

**Region by region, gated each time. Re-run the curve after, never before.**

---

## 6. Never measured — the risk register

Ordered by how much a release could hurt.

1. **No outside playtesting of any kind.** Nobody but the owner has played it,
   in bursts, never a full campaign.
2. **No completed campaign.** 622 waves, about ten and a half hours. Nobody has
   finished one.
3. **Nightmare and Hell are modelled and unplayed.** Equally likely to be
   unplayable or trivial.
4. **Minimum spec is open.** 16.6 ms on a 3070 Ti at 1080p with no headroom.
   Nothing weaker has ever been run.
5. **Mobile performance has never been measured.**
6. **The web build and the APK are exported every release and never launched.**
7. **Co-op has never run as a long session between two real people.**
8. **No crash reporting.** The moment there are testers, this is needed to learn
   anything from them.

---

## 7. Not yet considered — and most of these matter

This is the section to challenge hardest. Several are genre expectations whose
absence a reviewer will name in the first paragraph.

### 7.1 Almost certainly required

- ~~**Game speed control (1× / 2× / pause).**~~ **Built 2026-09-21**: `GameSpeed`
  owns the clock's base rate, 2x on `P` and a button beside RIDE ON, solo only,
  and every borrower of the clock restores through it (`game_speed_check`).
  Pause already existed.
- ~~**Tower targeting priority**~~ **Already built**: `RunState.cycle_target_priority`,
  clicked on the tower's own card in the build list (verified 2026-09-21).
- ~~**Next-wave preview.**~~ **Already built**: the HUD's wave preview label.
- ~~**Colourblind support.**~~ **Already built**: the colourblind modes and their
  preview on the settings screen, applied in-place by `Palette`.
- **Onboarding by gating rather than by teaching.** The strongest fix for "I
  don't know what I'm doing" is not more tutorial steps — it is **not offering
  thirty systems in Act I.** Professions, mounts, the Ledger, the market, rifts
  and the pen could each open at an act. This is a design decision and it is the
  owner's.

### 7.2 Strongly worth having

- **A difficulty below Normal**, or assist toggles. There is Normal, Nightmare
  and Hell, and nothing for someone bouncing off Act II.
- ~~**Text size / UI scale option.**~~ **Built 2026-09-21**: the interface-size
  slider (`qol_check`).
- **Photosensitivity**: the flash scale exists — surface it in first-run
  options rather than burying it. **Still open**, and with build templates the
  last of §7.2 that is.
- ~~**Controller completeness.**~~ **Gated 2026-09-21**: `pad_focus_check` walks
  every screen's focus ring both ways, on both bars.
- ~~**Ultrawide and 4K layout.**~~ **Built 2026-09-21**: `layout_check` and
  `road_sheet_check` run at 3840x2160, 3440x1440 and 2560x1080 on both bars.
  The 4K shape found a real overlap on its first run (`IconKit.rect`).
- ~~**Performance auto-detect**~~ **Built 2026-09-21**: `Graphics.preset_for_machine`,
  said on the settings screen, never overriding a saved choice.
- ~~**Quit-mid-act clarity.**~~ **Built 2026-09-21**: the pause menu says what a
  quit costs since the last banked crossroad and asks twice.
- **Build templates.** With 61 towers, "repeat my last board" is real quality of
  life on a second run. **Still open.**
- **Steam Deck / handheld decision.** A 2D game at 16.6 ms on a 3070 Ti will not
  run on a Deck as it stands. Decide explicitly rather than discover it.

### 7.3 If this is a commercial release

None of this exists and all of it is required to *sell* the game:

- **Store presence**: capsule art, trailer, screenshots, description, tags,
  system requirements.
- **A demo or vertical slice** — the first hour, which is also the best forcing
  function for §7.1's onboarding work.
- **Privacy note and data handling.** The Supabase leaderboard takes a name and
  a score under an anonymous key every copy carries.
- **Leaderboard integrity.** By design, anything a client can write any client
  can forge. Either accept and say so, or scope the board to friends/local.
- **Platform integration** if shipping on Steam: cloud saves (the pinned user
  directory helps), platform achievements beside the in-game ones.
- **Localisation readiness.** Working rule 9 already keeps player-facing strings
  in data, so a translation path is cheap *if it is designed now* and expensive
  later. English-only 1.0 is fine; painting yourself out of it is not.

### 7.4 Worth considering, lower priority

- ~~**Boss phases.**~~ Every boss already had phases with reinforcements and
  bonuses (the line above was stale); **as of 2026-09-21 the slam and volley
  clocks shorten per phase** (`BOSS_PHASE_TEMPO`, measured by `boss_reach_check`).
- **Modding.** Everything is `.tres`; the story is nearly free and is a
  marketing angle. Out of scope for 1.0, worth not foreclosing.
- **New Game+ clarity.** Ascension, Nightmare and Hell exist; whether they read
  as *an endgame* rather than as a difficulty menu is untested.

---

## 8. What players will say — and what to do about it

### First-timer, after an hour

**Praise:** the premise reads instantly; the world looks alive; hits feel good.

**Complaints, in likely order:**
1. "I have no idea what I'm supposed to be doing." — §7.1 onboarding.
2. Proper-noun overload before anything is explained.
3. "The UI is too busy" — worse on mobile.
4. "I didn't know I was losing" — the alert work, already P1.
5. "It runs badly for a 2D game" — §6.4, §6.5.
6. "Act I drags" — 36 waves before a boss.
7. Bugs no gate can see.
8. Art inconsistency and a visible placeholder.

### Completionist, after ten-plus hours

**Praise:** genuine build depth on tuned scales; expeditions are the right answer
to the length; the world simulation is memorable.

**Complaints:**
1. "The middle blurs" — 622 waves against ~24 formations.
2. "Where's the music?" — §4, and impossible to miss over ten hours.
3. "Every act fights the same" — §5.
4. "Bosses are sponges with two moves" — §7.4.
5. "The tower ladder is a lie on Normal" — a full Normal run finishes near level
   8 of 10.
6. "What now?" — the endgame loop is unplayed.
7. Co-op desync and rejoin complaints.
8. "The story is thin" — lore entries and cinematics, no scenes.
9. Nightmare/Hell balance is a coin flip.

**The two highest-value unglamorous items in the whole project are the act music
and the boss themes**, because a completionist hears their absence for ten
straight hours and a first-timer never notices anything else on this list for as
long.

---

## 9. Decisions waiting on the owner

- ~~**Mount speeds and SP drain.**~~ **Built 2026-09-21** under `MOUNT_GALLOP_CEILING`
  and `MOUNT_GALLOP_RANGE`; see CLAUDE.md.
- ~~**Character customization.**~~ **Built 2026-09-21 as a dye** (cloak and sash
  hue turns), which reaches every sheet for free; drawn options stay unbought.
- **Save slots.** The only thing git cannot restore. `SAVE_VERSION` moves and
  `save_backup_check` runs by hand.
- **Should the Hold sell wall repair?** `repair_bill` walks towers only.
- **May a companion court a wild animal?** The courtship machine pairs two
  wildlife *records*; a companion is a node. Recorded rather than half-built.
- **The forwarded canon document inverts the final act** — it has Yuri unbound
  and the plot preventing his binding, against four shipped strings. Nothing has
  been built from it.
- **Onboarding by act-gating** (§7.1) — a design decision, not a bug.
- **Leaderboard integrity and store presence** (§7.3).

---

## 10. Deliberately refused — do not re-raise as gaps

Cooking. Named legendary individuals and Notorious elites (owner ruling: not for
1.0). Host migration mid-run. A true player-to-player order book (needs real
accounts). A second spellcasting skill tree. A third resource pool for
expeditions. Crossroads that cannot be extracted from. Procedural battlefield
*layouts* (v4 §54). PvP, bigger parties, daily challenges. Body recovery at a
death site, secure pouches, forward outposts, rival AI parties, settlement
districts — all wrong-genre imports. Volcanic fissures, sinkholes, landslides,
hail, dust storms, mudslides, geysers, freezing floods and supercells. The canon
document's future-Earth setting, its act rename and reorder, its Earthwitness
layer, and "The Beast Beneath" as a name.

**Deferred rather than refused** (they wait until what shipped has been played):
persistent footprints, boss entrance behaviours, post-battle settling,
anticipation audio on telegraphs.

---

## 11. Suggested sequence

Each numbered block ends with a published build.

1. **P0 regressions** (§2).
2. ~~**Town alert + imminent-damage indicators** (P1).~~ **Built 2026-09-21** (`town_alert_check`).
3. **Mobile**: ~~mount control~~ (the Ride button already asks `TouchInput`),
   ~~`layout_check` overlaps~~ (green at both phone shapes, 2026-09-21), then
   performance.
4. ~~**Mounts properly**~~ **Built 2026-09-21.**
5. ~~**Genre expectations**~~ All four existed; verified 2026-09-21. The three
   §7.2 gaps that did not (quit clarity, auto preset, interface size) are built.
6. **Enemies, region by region** (§5), curve re-measured after.
7. **Audio content**: act music, boss themes, enemy voices (§4).
8. **Onboarding**, once §5 and §7.1 have landed and the first hour can be
   judged as it will ship.
9. **Outside playtesting** (§6.1) — and crash reporting first, or it teaches
   nothing.
10. **Minimum spec, web, APK, Deck** (§6.4–6.6).
11. **Nightmare and Hell, played** (§6.3).
12. **Store presence and the demo** (§7.3), if commercial.

**Steps 9 and 11 are the real gate.** Everything above them is work I can do
alone; those two are not, and 1.0 is not honest without them.

---

## 12. Definition of done for 1.0

A release is production-ready when all of these are true:

- [ ] No known regression blocks play.
- [ ] A full campaign has been completed by somebody, start to summit.
- [ ] At least three people who did not build it have played the first hour and
      their first-hour complaints have been answered or consciously accepted.
- [ ] Every act has music and every boss has a theme.
- [x] Every act draws from 8–14 breeds - 8 to 19, by the owner's table (2026-09-21).
- [ ] No placeholder art ships.
- [ ] The mix has been heard in play by a person.
- [ ] Minimum spec is stated and met on a machine that meets it.
- [ ] Mobile runs at a stated framerate on a stated device.
- [ ] Web and APK have been launched and played.
- [ ] Co-op has run a full act between two real machines over the internet.
- [ ] Nightmare has been played far enough to know it is neither trivial nor
      impossible.
- [ ] Crash reporting exists and has caught at least one real crash.
- [ ] The release sweep is green **after the last commit** and before the tag.

---

## 13. Working discipline that applies to all of it

- A guarantee is a property of every breed, road, act and region, or it is not a
  guarantee. Walk the table; never sample it.
- A model of a thing is not the thing. Photograph the output; measure the files
  actually in use; hash the folder before building what may already exist.
- Trace before theorising when a state machine misbehaves.
- The release bar is a superset of guard's. Diff the two lists before a tag.
- Amending a gate's invariant is the one change that makes every later run agree
  with the bug it was built to catch. Do it deliberately and record it.
- A planted fault must *remove* the correct behaviour, not sit beside it.
- Never edit the tree during a sweep. Never delete an inbox after importing it.
- Commit before planting a fault.
