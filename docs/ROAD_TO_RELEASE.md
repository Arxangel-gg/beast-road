# Road to release

The single running list of what is left. Sessions are long and the list is
longer, so this file — not a chat scrollback — is what carries it forward.

**Rules for this file.** Tick a box only when the thing is done *and* verified by
something repeatable (a gate, a tool, a screenshot). Never tick a row because a
symbol now exists — `run_tool.gd -- audit` already measures that, and CLAUDE.md
§7 is explicit that a passing probe says nothing about whether a feature is good.
Add new work at the bottom of its section rather than rewriting the order.

Status legend: `[ ]` outstanding · `[~]` partially done, detail in the note ·
`[x]` done and verified.

---

## 0. Conformance snapshot

`run_tool.gd -- audit` — **44 / 45 (98%)**. 6 rows need human judgement and are
not counted; they are in section 4.

The one outstanding automatable row is **60 FPS at 1920x1080**, and it is honest
that it fails: the minimum spec is declared in `MINIMUM_SPEC.md` but *derived
rather than verified*, and nothing has been run on a machine of that class. It
cannot go green from this desk.

A passing row means the automatable part exists *and*, for everything closed in
this pass, a gate exercises it. It does not mean the game is finished — CLAUDE.md
§7 is explicit that the audit cannot tell you whether a feature is good, and
section 3 is entirely things the audit cannot see.

Re-run it after any section below is closed; do not hand-edit this number.

---

## 0b. Where this stands, 2026-08-25

Published as **v0.4.69** from `main`. 33 of 33 local gates green at the tag,
plus `tools/coop_live.sh`, `tools/coop_ui.sh` and `tools/lobby.sh`, which run
co-op as two real processes and are deliberately outside CI.

Landed since v0.4.44: the zero-capital start, two-player co-op end to end, the
co-op lobby, visible weather, beast-scope parallax, eight bugs reported from
play, torch shadows, five new foliage assets, and a leaderboard confirmed live.

- **v0.4.49** the replication batch — shared Ride On, the world clock (time of
  day, weather, act), enemy combat state and interpolation, shared pause, and
  hero death with partner revive.
- **v0.4.50** guest towers fire and guest hits are felt; mirrored facing; the
  guest's phase; shared cinematic skips; the revive redesign.
- **v0.4.51** the scope bar as an icon column, the command column, the build
  sheet inset clear of it, and the phone layout in CI for the first time.
- **v0.4.52** tower firing recoil, weather-driven foliage wind, ravens and
  wildlife.
- **v0.4.53** the city rocks and shudders, four silent completions given a
  voice, §57 made a gate, and the minimum spec declared.
- **v0.4.54** the three feature rows that had been flagged as needing a ruling:
  summon companions, traps, barricades.
- **v0.4.55** the second co-op play report — enemies that ignored the guest,
  the guest running its own phantom wave, hero health never replicated at all.
- **v0.4.56–57** the third play report: wildlife facing, scale, y-sorting,
  flight and walk cycles; barricades that actually block; the revive that wanted
  the wrong button; the guest's stuck build cursor; puppets that swing.
- **v0.4.58–60** the hostile roster: six predators and territorial animals with
  idle, walk, strike and death poses, elite variants, drops and experience; the
  frame-cost investigation closed in the negative; three more facing errors.
- **v0.4.69** the party feed, download mirrors and tier gating.

  **Chat and notifications are one list, not two.** A chat window beside a combat
  log is two places to look at the moment a player has least attention to spare,
  and they are about the same thing anyway - "buying the mortar" and "Blue built
  a Glacial Mortar" belong in the order they happened. Every line is coloured by
  the seat answerable for it. Enter opens the box, Enter sends, Escape cancels;
  there is no permanent text field to lose a wave to.

  Notices are written **locally on every machine from facts every machine
  already has**, never sent as sentences - sending them would be sending each
  event twice and risking two machines describing one thing differently.
  Spending is attributed exactly where it is knowable and to "the party" where
  it is not: the host knows who asked because a request arrives on a peer, and a
  guest cannot know, so it does not guess. A wrong name on a receipt is worse
  than no name.

  **Mirrors, and the bug that made them necessary and useless at once.** The
  launcher never set `HTTPRequest.timeout`, so a blocked host produced 0% for
  ever - no error, no retry, no failover, because the retry only ran on an error
  that never arrived. A *stall* watch does that job now: no new bytes for twenty
  seconds means try elsewhere, which catches a blocked host quickly without ever
  punishing a slow line. Mirrors are read from `mirrors.json` beside the
  launcher, so one can be moved or dropped without a new build. See
  `docs/MIRRORS.md`, including how to get a direct URL out of Drive or Dropbox
  that survives the next upload.

  **Tier gating.** A party is gated by its weakest member and is told which one.
  Checked when the run starts rather than at the door, because the host can
  change the tier after the party has formed.
- **v0.4.68** **parties of up to four.** The hero replication layer was built on
  a `host_hero: bool`, which is two-player by construction: with two people a
  wrong seat and a right one are the same number. It is keyed on *slots* now -
  1 to 4, host always 1 - and slot is what picks a colour, a spawn point, a name
  in the party list and which body a packet is about.

  Verified on three and four real processes by `tools/party.sh`. Every machine
  sees every hero, in distinct seats, wearing distinct colours: Red, Blue,
  Yellow, Green.

  **Party-size difficulty is measured rather than asserted.** Mean pressure
  across a full run is 0.363 / 0.339 / 0.346 / 0.337 for one to four players -
  an 8% spread - and `curve_report` now fails if any party size drifts out of
  band. The first attempt judged *peak* pressure and was chasing noise: peak
  moves with tower-affordability rounding, and sweeping the scaling constant
  gave 0.71, 0.88, 0.69, 0.87 for four neighbouring values.

  **Still to come, and none of it is built:** text chat has its wire and its
  relay but no interface; friends lists, passworded lobbies, auto-matchmaking
  and the party lobby view are not started; and difficulty-tier gating for
  parties is not wired. The online half of all of that also waits on the SQL.
- **v0.4.67** **co-op in the browser.** A second transport — WebRTC — so the
  web build can play, and so two desktop players can meet through home routers
  neither of them configured. Nothing above the transport changed: `CoopRelay`
  speaks `send_bytes` on whatever peer is installed, which it does because it
  was written to be path-independent, and portability came free.

  ENet is kept rather than replaced, and each has a job the other cannot do. A
  port needs no internet at all — two people in one house with the line down —
  and is lower latency. A room runs in a browser and crosses a router. The
  interface offers the room first because it is the one that works for
  everybody.

  **The harness earned its place the day it was written.** `webrtc_check.tscn`
  reported "connected in 0.0s" about two peers that could not exchange a byte:
  a mesh answers `get_connection_status()` with CONNECTED immediately, because
  it is connected to itself, so the transport was installing a peer whose data
  channel was still closed. Readiness now asks whether the *other* peer's
  channel is open.
- **v0.4.66** the eighth play report, and matchmaking finished: a **public
  lobby list** on Supabase alongside the local one, so the three doors into a
  game are now your own network, the whole internet, and a pasted code. Plus a
  grave marker where a player fell, flowers that are small and grow in patches,
  Preparation that ends in fight mode, a food economy that is a decision again,
  and an SFX doc that reads the game rather than its own list.
- **v0.4.65** the seventh play report. **Three doors into a game now**: a
  lobby that lists games on your network, a code for everyone else, and a typed
  address for anyone who would rather. Plus the two bugs that made co-op unfair
  rather than merely awkward — a guest's buildings never reached the host, and a
  guest could heal on its own screen while dying on its partner's.
- **v0.4.63** the sixth play report, and the first feature in a while that is
  about *reaching* the game rather than playing it: a **connect code**. Ten
  characters, one Copy button, one paste box. The public address is looked up
  properly now — UPnP first, and when the router will not answer (the common
  case) the game asks the internet instead, so nobody has to go and find their
  own IP. Also: separate spawn points, which turned out to be the "stuck at
  origin" bug; torches that only mind what is actually near them; Tab reaching
  the mode toggle; the guest able to tend itself; a second walk frame for all
  seven wildlife that had one; upright jungle flowers and five new plants.
- **v0.4.62** the fifth play report: the revive that never completed, enemy
  projectiles the guest could not see, the act banner, hawks flying backwards,
  enemies that now bite the wildlife back, mirrored enemies that teleport instead
  of sprinting, a Build/Fight toggle so Preparation can be fought in, and amber
  for ground that takes a trap rather than a tower.

  **The one worth remembering is a float comparison.** `is_equal_approx(0.999995,
  1.0)` is true, so the last step of a three-second revive was discarded as a
  no-op and the bar sat full forever. Two play reports described it precisely and
  the existing gate could not see it, because that gate called
  `revive_in_place()` directly — it asserted the destination and the entire bug
  lived on the road. Driving the thing the way a player drives it found it in one
  run.
- **v0.4.61** the fourth play report: the fork shared between both players, the
  wildlife crowd on the guest, rain retuned, Q and R bound, wildlife health
  bars, the shared pause menu — **and a predator rebalance the gates found**.

**The fourth round, and the first bug a gate found before a person did.**

The breather check started hanging instead of passing. It had not been changed;
what changed was that predatory wildlife existed. Its hero stands still for 150
seconds by design, and with hunts in the game it was dead in seventy of them —
town on full health, eight towers up, killed entirely by ambient wildlife. The
run ended, the ending screen paused the tree, and a headless gate had nobody to
click it, so it hung rather than failed.

Two real defects behind it, both measured rather than argued:

- **A hunt could not end.** Quarry is measured from wherever the animal has got
  to, so anything that closed the distance was by definition still inside its own
  aggro radius. A wolf that noticed you at 760 units chased you for the rest of
  the run. Hunts now have a length (7–12s) and a rest (13–22s), and breaking off
  *moves* rather than merely stopping.
- **Four of six predators outran the hero.** Sustained pursuit was 218–385
  units/s against a hero that walks at 200, so no hunt could be broken by moving
  whatever the timer said. And the bear hit for 54 where the hardest enemy on the
  road hits for 34. Both are now gated as data assertions in
  `regression_check.tscn`: nothing in the wilderness hits harder than the road,
  and nothing but the boar and the hawk can outrun you.

Measured after: a hero that walks away from a hunt stops losing health entirely —
19 HP at t=40, still 19 at t=150 with three to seven predators on the field and
hunts starting throughout. A hero that walks *into* them still dies in fifty
seconds. Both ends of that are what the design asks for.

Three gates were also repaired rather than the code they test. The breather check
now runs while paused, so an ended run is a sentence instead of a six-minute
hang. The two-process co-op harness compared the guest's connect-time seed
against the host's live one and reported a mismatch on every green run. And its
wrapper counted `grep -c`'s "no matches" exit status as a failure, so a clean run
printed "2 of 2 failed" under two PASSes.

**What three rounds of play have established.** Every round found bugs that every
loopback gate passed, and the causes were almost always singular rather than
many: one accessor answering the wrong question, one director running where it
should not, one mask value shared between two namespaces. The gates were not
weak so much as *aimed at symptoms*. Two were actively misleading — a barricade
check that handed the query its own answer, and an art claim written from
glancing at two sprites out of eighteen.

The habit that came out of it: **look at the thing**. Render the screenshot,
composite the contact sheet, print the runtime value. Each of those settled in
one call what reasoning had got backwards.

**Three bugs found on the way that were on nobody's list.** `String(int)` threw
in `Score.row()` on *every* completed run, taking the results screen's score line
and the leaderboard submission with it. A guest's pause never reached the host —
it tripped the authority guard and was dropped silently. And the phone layout had
never passed at all.

**What is genuinely still open**, in the order it matters:

1. **Co-op has now been played by two people, and each round of play has found
   real bugs** — no partner hero spawning, mirrored bodies with no velocity,
   and six replication gaps, in that order. Every one was invisible to a
   loopback gate and obvious within a minute of play. The gates prove the
   transport, the authority model and the plumbing; they say little about feel
   or latency, and the co-op difficulty constant is still provisional.
2. **Co-op hero XP is decided and built, but untested in play** — the owner
   ruled "both players share XP" on 2026-08-24. The award crosses and lands on
   each player's own hero, verified across two processes, but no human has
   watched two heroes level together.
3. **Tower shots and hit feedback now replicate too** (v0.4.50), and the
   reasoning that nearly left them out is worth keeping: the first estimate was
   that relaying shots would be the heaviest traffic in the game. Measured, it
   is about 6% of what the enemy batch already costs — a shot is a plot and a
   point, and towers fire far less often than thirty enemies move. The decision
   was reversed on the number rather than on the intuition.
4. **The UI vertical-bar rework** — the largest remaining code item, and one
   whose acceptance test is "does this feel right on a phone".
5. **All three are done** — §57 copy review, the minimum-spec definition and the
   juice pass. The spec's open question is answered too, in the negative: the
   fixed per-frame cost is **not in any game system**, and A/B timing cannot find
   it. Interleaved, disabling lights, foliage, particles, both shadow types,
   clouds and all 97 CPU particle emitters leaves the frame at 16.8 ms — the same
   as leaving everything on. Combat is free; an idle field costs the same as a
   fight. Finding *where* needs a real profiler attached to a frame, which has
   not been done. See `MINIMUM_SPEC.md`. Two of them left something behind that is worth reading:
   the §57 review found a live regression path rather than a bad string, and the
   minimum spec is *declared but not verified*. See `MINIMUM_SPEC.md`.
5. **Weather does not drive the foliage wind** — the one weather row left.

**A caution worth keeping.** Three features this session compiled, loaded and
passed every gate while being visibly broken: a white wall across half the
sky, dinner-plate rain ripples, and snow that never appeared. Each took one
screenshot to find. The gates answer "does it still run" and have no opinion
whatever about what the screen looks like.

---

## 1. Bugs and regressions

Highest priority: these are things that are wrong, not things that are missing.

- [x] Wave stall recovery could emit `wave_cleared` while a stationary ranged
      enemy was still attacking, opening Preparation on top of it. The watchdog
      now treats aggregate HP change as live combat and, on a genuine stall,
      resolves attackers through the normal death path before clearing. The
      180-second breather gate passes: three waves, two safe breathers.

- [x] Tower shadows anchored to the node rather than the sprite, so raising the
      sprite for y-sorting left the shadow floating. Fixed in `ShadowKit.add_contact`.
- [x] Foliage sorting over health bars. Bars now draw on their own layer above
      world content.
- [x] Foliage sorting over towers and characters. Band granularity was the cause,
      not the tower anchor: 16 bands across the whole field quantised every plant
      to its band centre, so a plant could sort up to half a band out of place.
- [x] No dash during Preparation. Dash is now allowed in every phase the hero can
      move in; attacks and spells stay combat-only.
- [x] Tower range ring not shown on selection.
- [x] Projectile art drawn diagonally, so it read as mis-rotated once turned to
      its heading. Regenerated as 96x48 horizontal bolts, tip-right; verified by
      measuring each sprite's hot pixels against its centre.
- [x] Torch glow uneven. Not a fault in any torch: light adds, and at radius 360
      with ~300 spacing the pools summed, so an isolated torch looked dim beside
      a pair. Per-torch energy came down to 1.15 so the *sum* lands where one
      bright torch used to.
- [x] No torch on the *outer* corner of a U-bend. Straights keep a clearance from
      each vertex, which left the longest arc on the road unlit; each bend now
      gets its own post on the outside of the turn.
- [x] Torch crowding. Fixed and now gated by `tools/torch_check.tscn`, which
      asserts the whole layout: minimum gap, four-road symmetry, and that no
      torch stands on the carriageway.

      Two passes were needed. A per-road filter fixed the reported case — a
      straight's end stop overlapping the corner post of the bend past it — but
      the check then caught a second one the report had not: adjacent *roads*
      putting torches 184 apart where the four final legs converge on the gate.
      A greedy field-wide filter would fix that by keeping road 0's torch and
      dropping road 1's, leaving the roads visibly unequal, so candidates are
      thinned in rotational groups instead: the k-th candidate of all four roads
      is accepted or rejected together, which makes symmetry a property of the
      algorithm rather than something to verify afterwards.

      32 torches, closest pair 212 apart, none on the road.
- [x] Enemy and foliage shadow anchors. Audited every `add_contact` caller: the
      enemy, hero and town sprites all sit at their node origin, so the
      sprite-relative fix is a no-op for them and they were never wrong. Foliage
      builds its shadow by hand and never used `add_contact`. The tower was the
      only offset caller, and it is fixed.

### Raised 2026-08-24 — all eight fixed and gated

Closed on 2026-08-25. Every row below is held by
`tools/regression_check.tscn`, which is in `guard.yml` and runs on every
push. That gate exists because all eight were *quiet* failures - nothing
errored, nothing logged, and so nothing that runs had any opinion about
them. The full local suite is 24 of 24 green.

- [x] **Enemy facing comes from the target lock, not from motion.** An enemy
      whose path bends away from the thing it is locked onto walks backwards.
      Facing has to be the sign of that frame's own velocity X, not the bearing
      to its intended victim - those two agree only on a straight approach,
      which is exactly why it looks correct until a road turns.

- [x] **The threat meter does not update when enemies change path.** It reads
      the wave's opening shape and keeps reading it while the roster
      redistributes. A meter that goes stale precisely when the wave gets
      interesting is worse than no meter, because the player trusts it.

- [x] **Act-boss summons outlive the act.** A boss that dies while its summons
      are alive still ends the wave and the act, and the survivors ride into the
      next act's indefinite Preparation - which the player then spends hunting
      them instead of preparing. They should be despawned on the boss's death,
      with no payout and no drops, because they were not killed.

      GDD §448 says Preparation never opens until all surviving enemies are
      resolved. Despawning *is* resolving them; this is an exception to the
      payout, not to the rule.

- [x] **Build tooltips cover the build panel.** A tooltip that occludes the
      options beside the one being hovered makes comparison impossible - the
      player has to move the mouse away to read what they moved it toward. It
      must open outside the panel's rect rather than over it.

- [x] **Foliage behind a tower draws on top of it.** A plant whose sort origin
      is behind a structure still paints over the structure's sprite. Towers and
      buildings are tall, so the sort key has to account for their height and
      not just their base row.

- [x] **On mobile, closing a build menu can leave tiles unresponsive.** Tapping
      a tile afterwards does not reopen it. Very likely the same class as the
      touch-eating HUD panel fixed in the touch pass: a dismissed panel leaving
      something behind that still swallows the tap.

- [x] **The dash button renders on the main menu** - a combat control over the
      front door.

- [x] **Loot pickups are far too small.** Filed as a bug, not as art: the art is
      fine and the on-screen scale is wrong. A reward the player never notices is
      a reward that did not happen. This wants a real size pass measured against
      the hero sprite at shipping zoom, not a nudge - it has now been raised
      twice.

      **What they turned out to be.** Four of the eight were not where the
      symptom was, and two shared a single cause:

      *Facing* asked about the target before it asked about motion, so the
      lock outranked the legs. Motion now wins while WALKING, and only
      WALKING moves under its own power - so the target branch still covers
      the windup, the strike and the knockback slide, where facing the
      victim is right.

      *The threat meter* read `enemy.lane`, which is written once at spawn
      and never again. Worse than lighting the wrong arc: it graded depth by
      projecting onto a road the enemy had already left, which returns a
      smaller number the further off-road it gets. Two wrong answers that
      looked plausible together. `BattleGrid.lane_at` now answers from where
      the enemy actually is.

      *Foliage sorting* was the interesting one. Bands sorted at their
      *centre*, which makes the error symmetric - a plant in the near half
      of a band sorted in front of where it stood. No band count fixes that,
      it only shrinks it, which is why 16 → 32 helped and did not cure.
      Sorting at the band's leading edge makes the error one-directional:
      nothing can now draw over a thing it is standing behind, as a
      guarantee rather than a tolerance. One line.

      *The mobile lockout and the dash button on the menu* were one bug
      wearing two hats. The controls read `_unhandled_input`, which never
      sees an event a Control consumed first - so a thumb lifted over a
      panel left the stick holding finger 0 forever, `owns_pointer()` stayed
      true, and `placement_cursor` refused every later tap as "that is a
      thumb". Releases now go through `_input`, which runs regardless.
      Separately, the overlay is gated on `run_active`: the visible ring on
      the front door was the smaller half of that problem, because an
      invisible button eats a tap exactly as well as a visible one.

      *Loot scale* was measured rather than nudged. A drop was 11.6% of the
      hero's drawn height - about 13 screen px at the default battlefield
      zoom and under 10 fully zoomed out. Now 58 world units, roughly a
      quarter of the hero, 30 screen px at default and 22 at the widest
      zoom. `LOOT_COLLECT_RANGE` went 34 → 48 with it, because a collect
      radius smaller than the sprite means standing on a coin without
      taking it.

      *Build tooltips* now open in a box beside the panel rather than at the
      cursor, which is by definition inside it. The target-priority tooltip
      was deleted outright - the next line already put the same sentence in
      the panel as a label.

- [x] **`breather_check` was flaky, and had been all along.** Found while
      verifying the above, not caused by it - an A/B run with the change
      reverted failed identically.

      It called `RunState.reset()` with no seed, which draws a fresh random
      one, so every run rolled a different roster, different spawn positions
      and a different time to clear wave 1. Across runs of *identical* code
      the first breather opened anywhere between 24 and 63 seconds. The
      window was 60. The gate had been passing on a coin toss.

      That is worse than having no gate, because a test that goes green on a
      re-run teaches everyone to re-run it. Now seeded, so it measures the
      breather mechanic rather than the dice, and the window is 150s so a
      slow-but-legal wave is not a failure. Verified by running it twice and
      getting byte-identical output - `#1 opened at 30.7s` both times.

      **Worth a look across the other harnesses**: any gate that resets a run
      without a seed is measuring one sample of a distribution.

- [x] **`regression_check` leaked audio at exit**, on an otherwise passing
      run. The jungle music and ambience streams stayed alive, and the guard
      workflow fails a gate on any `WARNING:` line - so a green test would
      have broken the build.

      The cause was teardown order. The run has to leave the tree *first*,
      then the audio autoloads are silenced, then the tree needs enough
      frames to actually collect before quitting. `breather_check._bail`
      already had exactly this sequence, with a comment explaining it, and
      the new gate was written without reading it. Both now match.

      Two harness defects in one session, both found only because the suite
      was re-run rather than trusted once. That is the argument for running
      the whole suite after a change rather than the gate you think is
      relevant.

### Raised 2026-08-26 — the eighth play report

- [x] **Nothing marked where a player fell.** A collapsed hero hides its own
      sprite — it has to, or a corpse lies on the field looking alive — so a
      partner crossing the map had a few pixels of revive bar to aim at. A grave
      marker stands there now, pulsing slowly, and disappears the instant they
      are helped up. Never drawn in a solo run: nobody is coming.
- [x] **Flowers were big, sparse and some were lying down.** All six flower
      sprites redrawn at 32×40 instead of 48×56 and explicitly upright, checked
      on a contact sheet. Flowers now arrive in **patches of three to six** at
      varying sizes rather than one at a time — a single flower in a field reads
      as a mistake — and take a larger share of the draw. Reeds and a wrecked
      cart join the shared props.
- [x] **Build menus stayed open when the wave started.** Build mode followed the
      phase into Preparation and not out of it. It follows both ways now, on
      every machine, so the horn puts everybody in fight mode with the panels
      closed and the cursor changed.
- [x] **Food was over-abundant.** It had one urgent price (45 to tend), started
      above it, accrued while the beast walked, and then twelve species of
      huntable wildlife arrived — a bear alone paid for a whole tend and change.
      Wildlife yields cut to roughly a third across the roster, and the run
      starts on 38 Food, below the price of one tending. The first wounded hero
      is a choice again.
- [x] **Missing sounds were invisible.** The prompts doc only ever compared its
      own hand-written list against the folder, so a sound added to the game and
      never prompted did not appear anywhere — the doc said "nothing
      outstanding" while the game played silence. It reads the game now: every
      `sfx_`, `music_` or `ambience_` literal in any script or resource, in a
      **NEEDS A PROMPT AND A SOUND** section at the top. Currently zero, which is
      now a fact rather than an assumption.
- [x] **Matchmaking.** A Supabase table holding one row per open game, reached
      through three `security definer` functions rather than by writing to the
      table: anonymous clients have no identity, so any delete policy loose
      enough for a host to remove its own row is loose enough for anybody to
      remove every row. Reading goes through a view with no token in it.

      The row is deleted when the run begins, when hosting stops, and when the
      game closes, and swept by a heartbeat window if all three are missed — so
      the table is empty whenever nobody is waiting. The SQL is in
      `docs/MATCHMAKING.md` and has to be run once; **until it is, the public
      list is simply empty and nothing else changes**, which is verified: the
      project answers 404 for the missing table and the client treats that as
      "no games".

### Raised 2026-08-26 — the seventh play report

- [x] **A guest's buildings never appeared for the host.** `try_build` acted
      locally on a guest: it spent a purse the host owns and set a tower the host
      never heard about. The host had a `BUILD_TOWER` handler from the very first
      day of co-op and **nothing in the game ever sent one** — the only caller
      was the transport test. `coop_world_check` passed throughout because it
      called the handler directly, which is the exact trap
      `gate-the-road-not-the-destination` describes.

      Seven functions have now needed the same treatment and three were found by
      play. There is one `_ask_the_host` helper for all of them, so the eighth
      cannot be forgotten: build, upgrade, trap, barricade, tend, repair.
- [x] **A guest healed while its partner watched it die.** A relayed knockdown
      was applied as *damage*, and damage can be refused — invulnerability, a
      draught, a hit already in flight. When it was refused the guest stayed
      standing on its own screen while the host had it on the floor. It is
      applied as a state now: a fact about the world cannot be declined.
- [x] **Codes did not connect.** The code itself was right; the address in it
      could not have worked from where they were. A single address cannot serve
      both cases — the public one is what a friend abroad needs and is exactly
      the one that fails for a friend in the same house, because most routers
      will not loop a connection back to themselves.

      A code carries **both** addresses now (sixteen characters), the joining
      machine tries the public one and falls back to the local one, and ten
      character codes still decode so nothing already pasted into a chat window
      stops working.

      Also fixed on the way: the first version of the pair encoding assembled
      eighty bits into one integer. GDScript integers are 64-bit, so it lost the
      top two octets of the first address while round-tripping the second one
      perfectly — the kind of half-right that reads as working.
- [x] **A lobby.** Hosts shout on the local network once a second and the co-op
      screen lists what it hears; one click joins. No server, and nothing leaves
      the local network.

      Two things had to be right for it to work on one desk, which is how
      everybody tests. Only one program can hold the well-known port, so whoever
      starts second binds a nearby one and *probes* instead — whoever holds the
      port answers directly. And every packet goes to loopback as well as to the
      broadcast address, because Windows will let a program broadcast while
      quietly dropping what comes back until a firewall prompt is answered.

      Held by `tools/lobby.sh`, which runs it in both orders. The two orders are
      different code paths and only one of them is the common one.
- [x] **Torches stopped going out entirely** — caught by the release job hanging,
      not by anything on this desk. The lateral bound was correct and the
      mechanic had been working *because of the bug*: enemies on other legs of a
      bent road were counted as pressure, three bands of them at 185, 505 and 730
      units to the side. Excluding the two that were never near the brazier cut
      real pressure to a third, and 0 of 48 torches went out in a soak that had
      always passed. `TORCH_DIM_PER_ENEMY_SECOND` is 0.26 now: about a pair of
      enemies level with a torch for four seconds. 3 of 48 out in 45 seconds.

      **The local suite was missing five checks that only ever ran on a release.**
      They are in it now — both soaks, the perf budget, the curve report and the
      launcher pipeline test. A release workflow that hangs for half an hour is
      the most expensive way to learn that a constant was wrong.
- [x] **Everything a beacon says is untrusted.** It arrives from whatever else is
      on the network: shape-checked, objects refused when decoded, names stripped
      of control characters and truncated. The worst a hostile beacon can do is
      put a wrong name in a list. The name a host sends is its hero's class and
      level — never a machine name or an account name.

### Raised 2026-08-26 — the sixth play report

- [x] **No easy way to play with a friend.** The public address never populated,
      because it came only from UPnP and most routers will not answer. There is
      a **connect code** now — ten characters from an alphabet with no ambiguous
      shapes, carrying address *and* port — with a Copy button on the host side
      and one paste box on the join side that takes either a code or an address.
      When UPnP fails the game asks the internet for the public address instead,
      which is the step players were being asked to do themselves and did not.
      Round-tripping is gated in `coop_check.tscn`, including the shapes that
      must be *refused*: a code that half-parses dials a stranger.
- [x] **Both players stuck at origin, again.** The cause was the one thing
      section 1 said had not been reproduced: `_finish_respawn` put every hero on
      exactly `Vector2.ZERO`, so a wipe arrived two bodies of radius 26 inside
      one another. Each role has its own spawn point now, assigned by role rather
      than by machine so the two screens agree. Measured: a host that walked 90
      units in a second and a half now walks 300, and a guest that walked 29
      walks 303. That gap *was* the bug.
- [x] **Tab moved the button highlight instead of switching mode.** Tab is also
      `ui_focus_next`, and Godot's focus system runs between `_input` and
      `_unhandled_input`. Caught in `_input` now, and only during Preparation, so
      everywhere else it goes back to being ordinary focus navigation.
- [x] **The build cursor stayed on in Fight mode, and the build panels stayed
      open.** Both swallow clicks, so switching to Fight to deal with a wolf left
      a player looking at a tower list and unable to swing at anything under it.
- [x] **Torches snuffed with nothing near them.** Only the *longitudinal*
      distance was measured, on the reasoning that a torch stands beside the road
      — true for a straight road. The roads bend, and a bent road doubles back,
      so an enemy on another leg entirely projects onto the same point along the
      lane vector. There is a lateral bound now.
- [x] **The guest could not tend itself** while both players had plenty of Food.
      Food is a shared purse the host owns, so a guest spending it locally had
      the balance corrected back while the healing landed on a body the host had
      never healed. It is a request now, as repairing the town also should have
      been — same bug, same bar, and fixing one and not the other is how it comes
      back next week.
- [x] **Seven wildlife had a single walk frame.** All twelve have two now. The
      way to get one was `animate_image`, which takes the existing sprite as its
      first frame and asks only for the *motion* — so palette, scale and facing
      come from the sprite rather than from a description of it. Every pair was
      checked on a contact sheet before it shipped.
- [x] **Flowers were scarce and one was lying down.** `plant_jungle_flower` was
      drawn as a cut flower on its side; it grows upright now. Three new blossoms
      (one per region), mushrooms and bleached bones join the roster, and flowers
      get their own share of the draw rather than competing with ten other kinds
      for one uniform roll. Nothing in the code ever rotated a plant — the
      horizontal one was horizontal in the file.

### Raised 2026-08-26 — the fifth play report

- [x] **The revive bar filled and nothing happened.** The single most-reported
      bug, and the cause is one line. A revive completed only on the frame the
      bar *crossed* 1.0, and that frame never came: the last step lands on
      0.999995, and `is_equal_approx` reads that as already equal to 1.0, so the
      guard meant to skip no-op frames threw the final step away — and every
      frame after it did the same. The bar sat visibly full for as long as the
      key was held and drained the moment it was released, which is exactly what
      was reported, twice.

      Completion is a *state* now, not a transition: a hero who is down with a
      full bar gets up, however the bar came to be full. Held by
      `tools/coop_ui.sh`, which drives it the way a player does — the old gate
      called `revive_in_place()` directly and so tested the destination rather
      than the road, and the road is where all of it lived.
- [x] **Enemy projectiles never appeared on the guest.** A puppet resolves
      nothing and therefore never runs `_strike`, so a ranged enemy on the
      guest's screen hurt people from across the field with nothing in between.
      Blows are announced now, the way tower shots already were, and the guest
      draws the shot without resolving it. Tower shots were checked at the same
      time and were already working — that half of the report was wrong, and it
      took a gate to say so.
- [x] **The act banner appeared for the host alone.** The guest was *assigned*
      the act number and never *told* it changed, so everything derived stayed
      right and everything announced was skipped: the "Verdant Maw · Act I"
      title, the music change, the ambience bed and the region cinematic.
- [x] **Eagles flew backwards.** All four hawk sprites face right; the data said
      left. Read off a 6× contact sheet, which is now the only way facing gets
      claimed here — the other five hostile species were checked in the same
      pass and were correct.
- [x] **Enemies ignored the wildlife mauling them.** They bite back now, but only
      at something already within reach: a target is what `_walk` steers at, so
      one chosen at a distance would pull the column off the road, and the road
      is the one thing a lane enemy must never leave.
- [x] **Mirrored enemies zoomed across the map.** A correction larger than
      anything that could have happened in one packet window is not a correction,
      it is a body in the wrong place — and interpolating one draws the enemy
      sprinting the width of the field in a tenth of a second. It teleports now,
      which also covers every other way a puppet can end up misplaced rather than
      only the one that was found.
- [x] **Mirrored movement was still janky.** Replaced arrive-then-coast with dead
      reckoning plus continuous correction: the body always moves at the speed it
      was last told and is eased toward where the host's copy *should be now*,
      rather than chasing a position that is already a packet old. Nothing has a
      deadline any more, which is what the stutter was.
- [x] **No way to fight during Preparation.** Predatory wildlife could open on a
      hero who was not allowed to swing back. Preparation is now both things,
      with a per-player Build/Fight toggle on Tab and a button in the action bar.
      Local to each machine on purpose: one player laying traps while the other
      clears the wolves is the point.
- [x] **Red boxes on ground where traps are legal.** Three answers now, not two:
      green builds, amber is the wrong tool for this tile (a road takes traps and
      barricades), red is ground nothing can use. Amber carries a sentence as
      well as a colour.
- [~] **Both players locked at origin after a wipe.** Not reproduced once the
      revive was fixed, and the two were almost certainly the same episode — a
      pair who could not be helped up went down together. The property is gated
      now anyway: a wipe must put both on their feet, cost exactly one Wound, and
      leave two heroes who can walk. Left as `[~]` rather than `[x]` because
      "could not reproduce" is not "fixed".

### Raised 2026-08-25 — the fourth play report

- [x] **Wildlife was not replicated, and the guest grew a crowd.** Removal was
      announced by the kill path and by nothing else, so an animal that wandered
      off or ran out of patience was freed on the host and left standing on the
      guest forever — no batch mentioned it again, so it stopped moving too.
      Reported as "wildlife cluster beyond reach and do not appear on the host".
      There is now one `_retire` choke point and every removal goes through it.
- [x] **Pausing for one player showed nothing to the other.** Both panels now
      raise and lower together via the `pause_menu` group.
- [x] **Wildlife had no health bars.** A bar appears once an animal has been hurt
      and is always visible on an elite, which is half of what makes an elite
      readable before it reaches you.
- [x] **The crossroad opened for the host alone.** Both players now stand at the
      fork, whoever clicks first decides it for both, each sees the other's
      cursor while deciding, and the option a partner took is marked before the
      screen closes.

      Only the *segment* crosses the wire. Both machines draw their offers from
      the same seeded stream, so naming the crossroad gets the guest the
      identical pair without sending any of it — and the guest no longer opens
      its own, because two independent draws would put different cards on the
      two tables and then the first click would send a road the other player
      could not see.

      The guest's click *asks*. "Whoever chooses first" needs an arbiter: two
      clicks half a frame apart look simultaneous from both sides, and both
      machines would apply their own road. The host answers, and the answer comes
      back as a fact both apply identically.
- [x] **The host threw away the guest's cursor.** The pointer is the one fact
      either player may author, and the sending side had its exemption while the
      receiving side did not — the packet arrived and the authority guard
      dropped it on the doorstep. `SYMMETRIC_FACTS` now names the exception in
      one place, the way `ANNOUNCEMENT_FACTS` does.
- [x] **Rain was too opaque, too slanted and too slow, and stopped at a visible
      line.** Retuned and the veil widened past the walkable edge.
- [x] **Q did not sound the horn and R did not enter the raid.** Both actions
      existed in the input map and neither was bound in `_unhandled_input`.
- [x] **Predators were the deadliest content in the game.** See §0b — found by
      the breather gate rather than by a person, which is the first time that has
      happened this project.

---

## 2. Conformance — the 8 outstanding rows

### Terrain ids (3 rows) — done

- [x] The three regions now carry v4's ids: `jungle`, `desert`, `snow` (they were
      `ashfen`, `saltglass`, `steppe`). 213 files renamed, including the audio
      beds and the raid chieftain art, which are keyed by region as well.

      `SAVE_VERSION` is 3, and `migrate_save` now *chains* v1 -> v2 -> v3 rather
      than jumping straight to the current shape, so a v1 save walks every step.
      The v3 step remaps unlocked terrain ids and passes an id it does not
      recognise through rather than dropping it — a migration that quietly
      forgets an unlock is worse than one that carries a stale string.

      `save_backup_check.tscn` was extended to prove the v2 -> v3 step and run by
      hand; it is deliberately not in CI (CLAUDE.md §1), because a discarded save
      legitimately warns and the release gate fails on any warning.

      Two traps worth remembering: a whole-word replace protects `steppehorde`
      but skips `_`-joined stems like `ambience_ashfen`, and `MusicPlayer` builds
      its track key from the terrain id — so leaving the audio unrenamed would
      have silently played the Act I theme in all three acts. Scenes had to be
      swept too; `.tres` and `.gd` alone left two `ExtResource` paths dangling.

### Meta systems (2 rows) — done, with two legacy effects outstanding

- [x] Tools. Earned by depth (per act reached, plus a victory bonus), capped, and
      spent automatically on the authored roster order at the end of a run.
      Replaces the old "one tower per act boss felled", which paid a run that
      *died* in Act III the same as one that cleared it.
- [x] Four capped Sigil ranks, one per full clear, persisted and clamped on load.
- [x] Rank 1 — starting supply bundle on every currency.
- [x] Rank 3 — Treasury may carry 120; never lowers a cap the tier already had.
- [~] Rank 4 — "one additional Town Hall relic socket" is already granted by the
      shipped `act3_cleared` bonus, which CLAUDE.md §7 names as the *only*
      sanctioned persistent power. Left on the first clear rather than the
      fourth: strictly more generous than v4, and it avoids two systems paying
      twice for the same achievement. Revisit only if the owner wants it gated.
- [x] Rank 2 — one crossroad redraw per run. Per run rather than per crossroad:
      a reroll at every fork turns the route into a shopping list instead of a
      decision. The button states the remaining count for that reason. Redrawn
      from the same `roads` stream so a seeded replay that rerolls stays
      reproducible. Tested at both edges — rank 1 grants none, rank 2 grants one
      that a redraw actually spends and cannot go negative.

Both surface on the debrief as `Tools N · Legacy rank N of 4`.

### The summit (3 rows) — done

- [x] Final Ascent route. Act III's boss now opens a short authored climb rather
      than ending the campaign. No crossroads and no fork: the journey skips its
      segment logic entirely while `is_final_ascent()`, and the boss is summoned
      by distance rather than at a segment boundary.
- [x] Kharok the Chainmaker — 16k HP, three phases, reinforcements on all four
      roads. The act→boss fallback used to index a directory listing, which would
      have handed the ascent whichever boss sorted fourth; it looks up by id now.
- [x] Summit backdrop.
- [x] Ending sequence. Lines arrive one at a time over a scrim, then the player
      chooses: keep riding into Endless, or take the debrief.

      One deliberate deviation from v4, which ends the run at the summit: the
      owner asked for Endless to continue past it, so both are offered. Ending
      the run from that screen is the *same* end as dying in Endless —
      `summit_reached` carries the win either way, so riding on and falling at
      wave ninety still files a victory.

- [x] Credits. A skippable roll over the summit art rather than on its own
      screen: the art is the last thing the player earned.

---

## 2b. The authored map (2026-08-20)

The owner's map tool now supplies the layout: `docs/beast-road-current-layout-blueprint.json`,
copied to `game/data/maps/battlefield_layout.json` and loaded at build.

- [x] 45×45 at 64 units, replacing the procedural 30×30 with four U-bends. The
      generator went, not because the bends were wrong, but because a generator
      can only make the shape it was written for — and this map **forks and
      rejoins**, which no amount of tuning a single polyline could produce.
- [x] A lane is no longer *a path*. It is a set of routes sharing corridors with
      each other and with the other three lanes. `lane_paths` keeps the shortest
      so old callers still work; enemies pick their own at spawn.
- [x] Route enumeration over a **corridor lattice**, derived rather than
      hard-coded: corridors are three tiles wide, so a run of exactly three
      across one identifies its centre line, and every junction sits where two
      centre lines cross. 49 nodes, 52 edges. Re-exporting the map does not mean
      editing a table.
- [x] Route length capped at 2× the shortest. The map's longest way in is 3.5×,
      about two and a half minutes of walking — the wave is over before it
      arrives, and it reads as a stuck enemy rather than a flanker. 3 routes per
      lane at 2752–4928 units.
- [x] Choice weighted toward shorter routes rather than uniform, so the long way
      round is a minority the player notices instead of a second clump.
- [x] Road baked from the lattice, not per route. Shared corridors would
      otherwise be drawn two and three times, compounding the tiles' alpha edges
      into a visible seam wherever routes overlap.
- [x] Border sealed to building without touching authored tiles. The blueprint
      marks the whole outer ring Background, which is buildable, and a tower
      flush against the edge draws half off the field — but the ring also carries
      the twelve spawn tiles, so only open ground is sealed.
- [x] **568 places take two towers side by side**, which is the layout's stated
      purpose for four-tile gaps, asserted rather than taken on trust.
- [x] `grid_check` rewritten. The old one asserted U-bend shape — that each road
      doubled back and was 25% longer than the straight line — which describes
      the previous design, and a check that describes the last design is worse
      than none because it goes green on a build it never looked at. It now
      verifies every waypoint of every route lands on road and every corridor
      between them is road end to end: the lattice is derived, so a centre line
      found one tile off would still produce routes that connect and look
      plausible while walking enemies through the buildable ground beside the
      road.
- [x] Torches rebuilt on the lattice: one per corridor, **every one lit**, 48
      total. The previous scheme placed a dense row per lane and then, for frame
      rate, gave only one torch in two a light — the worst of both trades, more
      sprites and less light, and exactly the reported symptom of roads lined
      with torches that were still dark. Placed in quarter-turn orbits so the
      lighting is symmetric by construction, and `torch_check` now asserts both
      that symmetry and that no torch is unlit.
- [x] Camera reframed for the 45×45 field: 0.77 → 0.52, range 0.62–1.18 → 0.38–1.00.
      At the old zoom a player at the gate could not see the junction the road
      forks at, so the choice the map is built around happened off screen.
- [x] The hero could not reach their own map. Movement was clamped with
      `limit_length` — a circle of radius 880 on a field that runs to 1440, so
      the corners were unreachable and the further a road bent from the axis the
      less of it could be defended. Bounds are rectangular now and set from the
      grid rather than authored in the scene, so they follow the map.
- [x] Preparation opening on a live enemy. The stall watchdog counts time, and
      time cannot tell a wave that is stuck from a wave that is merely long — the
      authored map's far route is nearly twice the direct one, so an enemy
      walking it tripped a 75s timeout that then opened Preparation on top of it.
      Progress now resets the clock: an enemy closing on the town is not a stall.
- [x] Enemies walking backwards, including the Act I boss. Facing followed the
      *target* only, so an enemy with nothing in reach kept whichever way it last
      fought — and on a map whose roads double back, that is a whole leg walked
      backwards. Now follows direction of travel when there is no target, with a
      deadzone so a sprite tracking a bend does not shudder between facings.
- [x] Hero facing. Was the aim vector alone, so running east with the cursor
      resting west ran backwards. Now resolved in priority order: an attack owns
      the facing for 0.35s, then movement, then the cursor. The eight authored
      frame rows are driven from the same resolved vector as the flip, or the two
      disagree the moment you walk one way and point another.
- [x] Tower projectiles 620 → 880. The camera sits further out, so the same shot
      covered less of the view per second and read as slow — and a slow shot
      leads more, so it also missed more.
- [x] Torch lights. Verified as real enabled `PointLight2D`s rather than as the
      flag meant to produce one: the flag would have passed the entire time the
      bug existed, since torches honestly reported the every-Nth rule that left
      most of them dark. All 48 checked.
- [x] Death report. The panel kept its scene offsets (−400..+400) while being
      forced to 1180 wide, so it sat 190 units left of centre with its button off
      the side of the window. Centred by a container — anchors cannot express
      "centre something whose size depends on its contents" — and Escape or the
      controller's accept now dismiss it, with the button focused on open.
- [x] Repair restores damage art. The town recomputed its stage only on
      `damaged`, so it could get worse and never better: repaired to full it
      stayed visibly ruined with its fires burning, which reads as the repair
      having done nothing. Hooked to `changed` so every route in counts, and a
      stage that improves no longer shakes the camera or plays the hit sound.
- [x] Foliage variety and idle motion. Every region now has its own shrub and
      flower alongside its plant, rock and boulder are shared, and painted plants
      sway — which they previously only appeared to. They shared the blades'
      canvas item and therefore the blades' material, whose sway weight is `UV.y`;
      a texture drawn through `draw_texture_rect` gets its V from the rect, so
      V=0 is the sprite's *top*. Every scattered sprite was swinging about its tip
      with its roots sliding across the ground. They now draw in a child item with
      the same shader inverted and its reach cut to a quarter — a shrub is a woody
      thing and should not whip like grass.
- [x] Horizontal ferns. Jungle, desert and snow now each carry a wide 64×40
      region-painted fern. They use the existing 32-band batched foliage path,
      so the added silhouette does not reintroduce per-plant draw calls.
- [x] **Hero levelling to 100 and the skill tree.** The bounded levelling system
      is complete. The original implementation reset each run; the owner ruling
      of 2026-08-20 now persists level, XP and placed attributes, capped by
      `HERO_MAX_LEVEL`. Building tiers, run currencies, relics and Oathbound
      leaders still reset. The later persistent-hero item records the migration
      and tier curve that make that amendment shippable.

      XP scales with the enemy's health rather than an authored per-enemy number,
      so an elite outpays a runner with no second table to maintain and act
      scaling carries the curve on its own. Four attributes — Might (damage),
      Vigour (health), Swiftness (movement and swing speed), Focus (command and
      spells) — at one point per level, and a skill point every five.

      Built *around* the existing discipline system rather than replacing it. The
      24 nodes, per-road offers and Food costs stay; training now also costs a
      skill point, and the trained cap grows with level (6 → 11 over a run). Two
      gates on purpose: the point is growth earned by fighting, the Food is the
      Preparation decision made against the towers. Skill points only, and the
      hero stops competing with the defence for resources; Food only, and
      levelling has nothing to say about the tree.

      Curve solved by measurement, not guess. `tools/level_curve.tscn` drives the
      *real* wave director — the first version modelled wave growth as
      compounding across the run and reported 103,788 kills, because growth
      compounds per act and resets. A tool that models the thing it measures is
      only as right as the model, and a wrong one produces confident numbers to
      tune against. Measured: 640 kills, level 30 → 63 → 97 across the three
      acts, arriving at the summit three levels short so the longest fight in the
      run still pays.

- [x] **Rebalance.** Three things had made the game easier at once and none
      looked like a balance change: far more buildable ground (568 places take
      two towers abreast, where the old pockets took one), free placement
      removing the slot ceiling, and a hero who can now reach +109% damage.
      Measured peak pressure was 0.26 — towers alone covering roughly four times
      the threat, which is the passive game played from the base.

      `curve_report` models tower capability and **no hero at all**, so peak
      pressure is exactly the fraction of late threat the player must cover
      themselves. Now 0.63: the towers hold most of a wave and the rest is the
      player's job, which is what the levelling exists to make possible.

      Carried by the per-wave rate (0.041 → 0.122), not the act multipliers. The
      first attempt raised those and the balance gate refused it — an act
      multiplier applies in full on the first formation of an act, so 1.26 → 1.68
      is a 33% wall at Act 2's door, exactly the "erase the player's progress on
      the very first formation" the gate exists to catch. Growth is linear, so a
      higher rate lifts wave 51 far more than wave 5 and arrives as a ramp.
      Wave 1 is untouched.

- [x] **Loot with magnetised pickup.** A drop is a *bonus*, never the base
      income — the kill still pays its resources instantly, exactly as before,
      and the drop is an extra share on top. That split is load-bearing: the
      difficulty curve was tuned against guaranteed income, so making the base
      collectable would quietly cut a passive player's economy and re-harden a
      game that had just been balanced. A bonus can only add.

      What it buys is what the rebalance is for — a reason to be on the road
      rather than behind the towers. 34% of ordinary kills drop, elites always
      do and drop triple. The magnet is generous (260 units) because chasing
      coins is not the interesting part; being out there is. Homing latches once
      entered, or a drop at the edge stutters in and out of range and reads as
      broken. Uncollected drops **pay out anyway** on expiry: losing a reward
      already earned by killing the thing teaches a player to stop fighting and
      stand on the road hoovering, which is worse than either extreme.

- [x] **Weather.** Five states, rolled per road so it is known before Preparation
      and can be built *for* rather than discovered mid-wave. Heatwave favours
      fire and thins water; Downpour reverses it; Snowfall favours cold; a
      Duststorm carries wind and stone. Drawn from what each region already is —
      v4 describes Act I as rain-heavy, Act II as a desert of mirage storms, and
      Act III as an approach where "weather suppresses visibility".

      Applied **per element, multiplicatively**. Per element because §20 promises
      "a player who learns one element can read the other", and weather that
      singled out named towers would break exactly that. Multiplicative because
      the region's favoured element is already additive, and stacking two
      additives on one tower is how a "+40%" turns out to be +95% with neither
      number explaining it.

- [x] **Persistent hero and campaign tiers (owner ruling, 2026-08-20).** Hero
      level, experience, placed attributes and the tier cleared now persist;
      everything else — towers, relics, currencies, building tiers, Oathbound
      leaders — still resets. Recorded as dated amendments in GDD §974 and §54
      and in CLAUDE.md's re-cut table and rule 7.

      §974's actual intent survives: the word carrying it was *uncapped*, and
      hero growth still stops at `HERO_MAX_LEVEL`.

      Three tiers — Normal, Nightmare, Hell — each the whole campaign again,
      unlocked by clearing the one below. Boss level expectancies are published
      to the player and are **expectancies, not locks**: a wall that says "come
      back later" throws away the forty minutes already spent, while a fight you
      can see going badly teaches you what to grind for.

      XP retuned from 5.4 to 0.30 per point of health. At 5.4 a single run took
      the hero 1 → 97, which was right when levels reset and wrong now: the whole
      climb would have been over before Nightmare unlocked. Measured ladder:

          Normal    run 1: 9 / 19 / 30   (expects 10 / 20 / 30)
          Nightmare opens at 46          (expects 45 at its first boss)
          Hell      opens at 82          (expects 80), ends at 100

      About seven full clears to cap. `SAVE_VERSION` 3 → 4; v3 saves migrate by
      arriving with no hero block, which is tested, and the save-backup check was
      run by hand — all five rows pass.

- [~] **Leaderboards** — client, score model, offline outbox, idempotent
      submissions, results-screen entry, browser and validation gate are built.
      Production remains blocked by the Supabase project being service-restricted
      for storage quota and by the table/RLS deployment and live round-trip not
      yet being verifiable. See `docs/LEADERBOARD.md`.
- [x] **Web build** — now in scope (§54 amended). Exported from a `Web` preset
      on the same tag as the Windows build, attached to the release as
      `BeastRoad-web.zip`. Hosting is Netlify, not GitHub Pages: publishing to
      Pages needs a Pages site, creating one is an admin operation a workflow
      token cannot perform (three releases failed on it), and it needs a domain
      to be worth having. The zip's `index.html` sits at its root, which is the
      shape Netlify deploys directly, and `_headers` is written into the bundle
      so caching travels with the build rather than living in a host dashboard.
      The page is embedded in a Carrd iframe, which is also why the build stays
      single-threaded — a cross-origin-isolated document will not embed in an
      iframe that is not.

      Two things made this cheap: the project already renders through
      `gl_compatibility`, which is the only path to WebGL2, and it owns no
      `Thread`. So `variant/thread_support=false` costs nothing — and it is
      required, because a threaded build needs COOP/COEP headers and Pages cannot
      send response headers at all. Both workflows fail if `index.worker.js`
      appears, which is what a threaded export writes.

      The preset was not written from memory of an older Godot. The option keys
      were read out of the 4.7.1 binary itself, and the export was run locally to
      the point where it named `web_nothreads_release.zip` — which proves the
      thread key is spelled right and taking effect, without needing the template
      on this machine.

      Rehearsed on every push, not only on a tag: the guard's export job builds
      the web target too, so a web export that cannot work costs a push rather
      than a version number.

      Two behaviours are gated on the platform. `UserSettings.apply_display()`
      returns immediately — a canvas cannot be moved, resized by its page, or put
      fullscreen outside a user gesture, so on load it would ask for fullscreen,
      be refused, and then set a size and a position for a window that does not
      exist. And the default graphics preset is Medium rather than High: the case
      for High rests on the player staying long enough to find the settings
      screen, which is a fair bet from someone who installed the game and a bad
      one from someone who opened a tab.
- [x] **Story intro cinematic.** Four panels and four lines — what Yuri is, what
      is chasing them, who the player is, where the road goes. That is the whole
      premise (GDD §6), and it is the minimum before someone is asked to defend
      four roads for an hour. Art generated at a native 688×384 and drawn
      nearest-neighbour.

      Skippable from the first frame and shown once. A cinematic that cannot be
      skipped gets resented on the second run; one that replays every launch is
      worse. Gated on a save flag rather than on `runs_started`, so a player who
      quits *during* the intro gets it again.

      It lives in `GameDirector.start_run`, not in `Run._ready()`, and that is
      not cosmetic: every headless tool instantiates `run.tscn` directly, so an
      intro inside the run scene played — and paused the tree for eighteen
      seconds — inside the balance test, the layout check and the snuff soak. All
      three failed, none for a reason connected to what they test. `start_run` is
      the door a *player* comes through; tools do not use it.

      The art fills the frame with the text on a gradient scrim. Reserving a
      strip for the text left the panel in a box wider than 16:9, so a 16:9 image
      was pillarboxed on a 16:9 monitor — the one shape it should have fitted.

- [x] **Loot art and cache diversity.** All four run currencies now have
      purpose-built 48px PixelLab world pickups, resolved by convention
      (`loot_<currency>.png`) with the UI icon retained only as a damaged-install
      fallback. Ordinary raid chests use a strapped supply-crate silhouette;
      locked high-ground caches retain the ornate purple relic chest, so their
      value and key requirement read before the player commits to the ramp.

      `tools/loot_art_check.tscn` drives the real `LootDrop` resolver for every
      currency, asserts the two cache paths stay distinct, rejects duplicated or
      empty art, and runs in the push, release and Update Manager preflights.
      Relics still enter the run through authored regional choices and raid
      resolution, not as arbitrary enemy drops; loot variety does not bypass the
      GDD's build-shaping choice.
- [x] **Cinematic pacing and skip model.** Hold time now starts when the *line*
      finishes fading rather than when the panel starts — the prose previously had
      about a second and a half of legible time, less than it takes to read two
      lines. A tap advances to the next panel; only Escape **held** for 0.9s
      abandons the whole thing, with a fill bar so holding reads as doing
      something. Tapping used to skip everything, so hurrying past a line you had
      already read threw away the rest of the opening. Slow push on the art, and
      SFX hooks on open and per panel.
- [x] **Drops are findable and audible.** A soft pool of light under each drop
      rather than an outline on the sprite: at this size an outline competes with
      the road's own edge detail, while a pool separates the drop from whatever it
      landed on. Pulse is out of phase with the hover so it reads as a glint.
      Sounds on drop and collect, plus a floating number on pickup.
- [x] **Skill 4 was off screen.** The bar's box was a flat 496 units for 638
      units of content — the fourth slot hung off the right edge. Now derived from
      slot size and count. Fixing it made the bar collide with the command row,
      so the ability bar moved to centre-bottom (where an ability bar belongs) and
      everything else lifted by one derived `BOTTOM_BAND` constant, so moving the
      bar again moves the rest with it.
- [x] **`layout_check` now catches off-screen widgets.** It could not see this
      class of bug at all: a widget outside the viewport overlaps nothing, so the
      layout looked perfectly clean while a quarter of the ability bar was gone.
- [x] **Settings reorganised.** Screen shake and beast motion moved off the Audio
      page to a new **Game** tab — they were on Audio because Audio was the page
      that already had sliders, and someone turning off camera shake for motion
      sickness has no reason to look under Audio. Tutorial/opening replay added
      there too.
- [x] **`docs/SFX_PROMPTS.md` leads with STILL TO RECORD (11).** Computed from
      disk when the doc is generated, not hand-maintained — a tracked list is
      wrong the moment a file lands, and then it sends you to record something you
      already have. The five new ids are declared in `Sfx.PLANNED` rather than in
      `PATHS`: registering a path with no file makes the loader warn, and the
      release gate fails on any warning, so five unrecorded sounds would have
      blocked every build.

- [x] **Raid terrain is textured.** The first pass drew flat tinted plates —
      legible, and it looked like programmer art, which is a fair trade for a
      prototype and not for a release.

      Raised ground now uses the **region's own sixteen-tile corner set**, the
      same Wang art the battlefield floor uses. Not a shortcut: an island *is*
      different ground, so the moss on jungle rock or the drift on snow is the
      right material for it, and it autotiles against the camp floor with real
      corner transitions rather than ending on a hard square edge. Baked into one
      texture, so a camp is one sprite rather than several hundred nodes.

      The corner mask counts a corner raised only when **every** tile meeting it
      is raised. "Any" was the first attempt and produced a visibly flat island:
      every edge tile then has all four corners set, so every tile drew the full
      upper piece and fifteen of the sixteen tiles — all the transitions — were
      never used at all.

      The cliff outline is kept but softened. The art transition is organic while
      collision follows the tile grid, so a heavy black line advertises the
      mismatch; it stays because the line is the *true* boundary and the art is
      decoration over it, but it now reads as a shadow rather than a border.

- [x] **Beast scope.** The beast is now animated pixel art: a 256px side-profile
      generated from Pixellab with a 9-frame walk and a 7-frame idle, and a
      sidescroller ground strip baked from a 16-tile platform set and scrolled as
      a leapfrogging pair (two nodes tile an arbitrary distance, and the journey
      is arbitrarily long).

      Frames are layered **over** the procedural gait, not in place of it — the
      bob, step sink, settle and footfall impulses all stay, and the walk frame is
      driven by the gait *phase* rather than a timer, so the beast plants a foot
      on the same beat the camera shakes on. Swapping the procedural motion for a
      spritesheet would have traded a gait that responds to speed and pauses for
      one that plays at a fixed rate.

      Absent frames fall back to the single profile sprite, so a partial set costs
      the animation rather than the screen.

      **The scope now composes as one image**, which took four separate fixes and
      each of the first three exposed the next:

      *The style clash.* The three act backdrops were 1920x1080 painterly art, so
      a pixel-art beast stood in front of a photograph. The backdrops were the
      outlier — the rest of the game is pixel art — so all three were regenerated
      as 688x384 pixel art and are scaled to fill the view height from the
      texture, not from a constant.

      *The parallax seam.* A backdrop that does not tile, butted against its own
      left edge, cut a hard vertical line through the sky every time the pair
      leapfrogged. The clone is mirrored, so both joins are edge-against-identical
      -edge and neither shows.

      *The ground that was never drawn.* The strip sat at z -5 under a backdrop
      left at the default 0: baked, scrolled, and covered by an opaque painting on
      every frame. Worse, when it was uncovered it turned out the bake indexed a
      **corner-mask set** by column — laying fourteen part-transparent transition
      tiles in a row, which drew as a single black line at the beast's feet. The
      bake now measures each tile's four corners from its own alpha, so which mask
      a tile answers to is read from the art rather than assumed from its
      filename. It also rebakes on act change: the strip was built once in
      `_ready`, so the desert and the snow both walked on jungle rock and the two
      tilesets that exist to tell the acts apart were never drawn.

      *The light.* Tilesets generate at full daylight saturation. Unlit, Act I's
      grass read as a bright green platform pasted over a sunset; a fixed dark
      tint fixed that and drew Act II's desert as grey slate under a blazing sky.
      The tint is sampled from the backdrop's own horizon instead — hue pulled
      most of the way back toward white so it cannot compound the art's own
      colour, brightness floored so Act I's near-black dusk does not produce a
      featureless void along the bottom of the screen.

      Act II and Act III each got their own 16-tile set. The first snow set was
      generated from "blue glacial ice" and came back electric cyan, which read as
      water rather than ground; regenerated as frost-cracked slate, it sits under
      the aurora as stone.

      **The town is back on its back.** The first generated beast had none, which
      left the premise of the game — a town riding a Worldstrider — as just a
      lizard. Fixed by regenerating the beast *with* the town rather than
      compositing a town sprite over it: the back rises, settles and tilts through
      the walk cycle, so an overlay would slide against it every frame, and
      inpainting nine frames consistently is a harder problem than asking for the
      whole animal once. Walled rampart, tiled roofs, watchtower, banner, lit
      windows and chimney smoke, all of it moving with the body because it *is*
      the body.

- [~] **Foliage variety.** The procedural polygons stay — they are what says
      "ground cover" — and painted kinds are scattered among them in two families:
      **regional** kinds carrying the act's identity (`plant_<region>_<kind>`) and
      **shared** props that look the same everywhere (`prop_<kind>`), because a
      rock is a rock in a jungle or a snowfield.

      The region's own plant stays the common draw at 58%. The extra kinds are
      punctuation: a field of nothing but boulders is as monotonous as a field of
      nothing but reeds, and the point is that a clump is occasionally *not* what
      you expected.

      Jungle has a shrub and a flower; rock and boulder are shared. Desert and
      snow still need their two kinds each, and nothing is animated yet — both
      follow the same convention, so they are files rather than code.
- [x] Tower and building idle animation — recorded again here in error; it was
      already built, and towers additionally derive damage-fire anchors from
      their own silhouette rather than from authored damage art.
- [x] **Mobile browser touch.** Twin sticks, low opacity, appearing where the
      thumb lands rather than sitting in fixed spots — a fixed stick makes a
      player look down to find it, a dynamic one is under the thumb by
      definition. Left moves, right aims and attacks past a threshold so a shot
      can be lined up without committing to it.

      Movement is fed back into the **input map** rather than into the hero:
      `Input.action_press(&"move_left", strength)`. `Hero._move_input()` already
      reads `Input.get_vector` over those actions and respects strength, so a
      thumb arrives by the same road as a key and the hero needed no change.
      Only aim needed a branch, because a direction is not a button.

      Three things were found by measuring rather than by reasoning:

      *Godot emulates a mouse from touch, and the emulated event arrives*
      **before** *the real one.* So a thumb walking the movement stick also drags
      a mouse across the battlefield, and at press time nothing yet knows the
      finger belongs to a stick. Placement now acts on *release*, when it does —
      which also gives a mouse the slide-off-to-cancel it lacked. Only finger 0
      is emulated, so ownership is the test rather than geometry; asking "is this
      point in a stick zone" would have made two corners of the field
      permanently untappable whether a thumb was there or not.

      *The dash button was eating the aim stick.* Sized from screen height, it
      became a quarter of the frame across on a tall viewport, directly under
      where an aiming thumb rests. It is sized from the shorter axis now and sits
      at the right edge at half height — the one part of the frame the HUD never
      claims. That matters more than tidiness: the sticks read `_unhandled_input`
      so Controls win, which means a HUD panel over a touch button does not hide
      it, it *eats the tap*.

      *The zoom hint named a mouse wheel* and pause was Escape-only, so a phone
      player could neither see the whole field nor leave it. Both are buttons now,
      on every platform, because a two-button zoom is no worse with a mouse.

      `tools/touch_check.tscn` is a guard gate — it drives synthetic touch and
      drag events through the real autoload and reads the real input map, because
      this machine has no touchscreen and the alternative test is a phone.
      `tools/touch_shot.tscn` renders it with both thumbs down.
- [ ] Whether the sticks *feel* right under a thumb, on a real phone. Nothing
      headless can answer that, and the check says so.
- [x] Loot diversity: relic and supply cache types, all four currency pickups,
      and a release gate that exercises their runtime resolution.
- [x] **Stash, inventory and blacksmith.** Ten kinds of gear across three slots,
      each a file. A *kind* is authored content — name, slot, icon, which
      attribute it favours; rarity and level are things that happened to one
      particular copy, so they live on the owned instance rather than writing
      back into the content files.

      **Gear grants attribute points, not raw stats.** That keeps one number
      governing hero power — the same number levelling feeds — so a lucky drop
      cannot out-scale the curve the campaign tiers are tuned against, and a
      player can compare a sword to two levels without arithmetic.

      **Two currencies, deliberately not exchangeable.** Gold is a run currency:
      spent under pressure, reset each run. Marks are what the account keeps.
      Mixing them means either hoarding gold instead of defending, or a stash
      purchase competing with the wall about to be overrun. Shards are what
      broken gear becomes and only buy upgrades, so a duplicate poses a real
      question: sell it for Marks, or break it for Shards.

      Upgrades cost **both**, for the same reason — Shards alone and a full stash
      upgrades everything free; Marks alone and salvage has no purpose.

      Stash and blacksmith are one screen because they are one decision. "Is this
      better than mine" and "should I break it to upgrade what I have" are the
      same question from either end.

      Capacity is finite (40): an unlimited stash means never choosing what to
      keep, which is the decision the blacksmith exists to pose. Losing runs pay
      Marks at 55% — a run that died in Act II still cost an hour, and paying
      nothing for it makes the stash a reward for winning, which is backwards for
      a system whose job is making the *next* attempt stronger.

      `SAVE_VERSION` 4 → 5; v4 saves arrive with no stash block, which is handled
      and tested. Save-backup check run by hand, all five rows. CLAUDE.md rule 7
      amended to name the stash and its bounds.
- [x] **The full audio library re-processed (2026-08-20).** 228 takes across 42
      sounds, reduced to 81 shipped files. Three takes for anything that can fire
      more than once every few seconds — impacts, footsteps, shots, loot, UI —
      because that is where one repeated sample is what the ear picks out; one
      take for events that happen once a wave or once a run, since three subtly
      different war horns are three sounds nobody will ever consciously compare
      and three files to ship.

      Peak-normalised to −6 dB (sfx) and −9 dB (ambience). The first pass
      targeted −3 and files came back out of the encoder at 0.0: Vorbis is lossy
      and routinely overshoots the source peak by a couple of decibels on
      transients. Final spread across 81 files is 7.3 dB with nothing clipping.
      `sfx_boss_spawn` overshot by five and took a true-peak limiter rather than
      another blind gain cut, which would only have made it quiet.

      Ambience keeps its stereo image and its internal quiet — trimming silence
      out of a two-minute loop is how a loop gets a seam in it.

      **`play()` now falls through to a group of the same name**, so adding takes
      is a data change rather than a rename across a dozen call sites. That also
      made deleting the 19 superseded single files *necessary* rather than tidy:
      while `sfx_fire_shot.ogg` existed, `play("sfx_fire_shot")` found it directly
      and the three new takes never rotated.

      `audio_verify` follows nested groups — "impact" names three materials and
      each material names its own takes, which is the right shape: first choice
      is which surface was hit, second is which recording of it.

      Inbox emptied, stale v3 names corrected. STILL TO RECORD: 0.

- [x] **Raid overhaul.** The camp was a flat circle 700 units across, and nothing
      in it made one part different from another — so a raid was sixty seconds of
      backing away from whatever spawned. It is now a **40×40 tile field (2560
      units)**, close to the battlefield's 2880 and nearly four times the old
      diameter.

      **Elevation islands**, generated per raid. They do three things at once:
      block movement and line, so contact can be broken and enemies have to come
      round; hold the better loot, so climbing is a decision made under pressure;
      and each is reached by a **one-tile ramp**, which is a choke — whoever
      holds it holds the island.

      `RaidLayout` is pure geometry with no nodes and no autoloads, the same rule
      `BattleGrid` follows, because connectivity decides whether a camp is
      playable and has to be checkable without standing an arena up.
      `tools/raid_layout_check.gd` builds **300 camps** and asserts it: nothing
      stranded, arrival clear, real relief, every chest and key reachable, and a
      key for every lock.

      It found two generator bugs on the first run — procedural terrain is right
      on the seed you looked at and wrong on one you have not seen. Islands grew
      over the arrival point (keeping *seeds* clear is not enough when a seed
      five tiles out has a radius of six), and my first repair lowered stranded
      tiles one level per pass, which produced level-0 hollows inside level-1
      islands that were equally unreachable. Repair now cuts a ramp where one is
      legal and flattens a whole region to its lowest neighbour where none is.

      **Chests and keys.** Locked chests take the high ground; their keys sit on
      the floor the player crosses anyway — a key hidden on *another* island turns
      one detour into two. Keys are not bound to a specific lock: finding "the
      wrong key" in a sixty-second camp reads as the game wasting your time.
      Opened by proximity, because a chest needing a keypress needs the player to
      stop being chased to press it. Chests pay in scattered drops rather than
      into the purse, so opening one happens on the ground in front of you.

      **Raids pay out at all now** — the arena inherited `EnemyField`'s empty
      `spawn_loot`, so a camp full of kills dropped nothing while the battlefield
      beside it did.

      Enemies respect cliffs and slide along them looking for the ramp rather
      than stopping dead, which reads as a siege instead of as a bug. The camp
      floor is the act's own terrain: the raid backdrop tiled across 2560 units
      showed its own seams as a grid.
- [x] **Milestone cutscenes beyond the opening.** First arrivals in the Sunglass
      Waste, the White Teeth and the Final Ascent now receive short illustrated
      travel cards; Rakka, Veyr, Mogrun and Kharok each receive a dedicated boss
      introduction over their regional art. Every word and trigger is a
      `MilestoneCinematicData` resource, while the art remains derived from the
      resource id by convention.

      They pause the whole run rather than letting a newly spawned boss attack
      under an overlay, restore the exact prior pause state, and stay below five
      seconds unattended against the GDD's ten-second ceiling. Tap, mouse,
      keyboard and controller advance; Escape or touch held for 0.9s skips. Each
      full card is first-view only and persisted with the other tutorial/settings
      flags; the HUD's light, non-blocking region and boss title cards remain on
      every replay.

      Headless tools suppress presentation by default, and the focused release
      gate verifies all seven trigger mappings, convention art paths, persistence,
      pause restoration and desktop/mobile input before a build can ship.
- [x] **The new SFX are integrated.** Eleven takes trimmed, peak-normalised to a
      common −3 dB ceiling and converted to Ogg. Peak-normalised rather than
      loudness-normalised because these are one-shots: `loudnorm` is built for
      programme material and would pump a 0.3s click up to match a two-second
      swell. A shared ceiling is what makes the per-sound decibels in `Sfx.MIX`
      mean the same thing for each of them.

      `sfx_ui_move` was 2.00s of which 95% was silence — trimmed to 0.10s and
      lifted 12.4 dB. Three of the five arrived as multiple takes, so they are
      named `_1.._3` and rotated by `Sfx.GROUPS`, which already re-rolls to avoid
      an immediate repeat. Pitch spread sits on top of that: three takes stop the
      *sample* repeating, the spread stops the three takes becoming a pattern over
      a four-panel cinematic or a cleared pack of twelve.

- [x] **The music prompts described the wrong game.** Three music and three
      ambience rows still named Ashfen, Saltglass and Iron Steppe — the v3
      regions, renamed by v4 §175-195. The files on disk had been renamed to
      match; the generator had not, so the doc reported six sounds as missing
      that have existed for months and described three places the game no longer
      contains. Rewritten for the Verdant Maw, the Sunglass Waste and the White
      Teeth. **STILL TO RECORD is now 0.**

- [x] **`tools/audio_verify.tscn`** — every sound id resolves to a real file,
      every group names real sounds, every mix row names a real sound. The loader
      warns on a missing *file*; nothing checked the groups, and a group naming a
      sound that does not exist plays silence and warns about nothing, because
      there is no file to be missing. 44 sounds, 5 groups, all resolving.

- [x] **Cloud shadows.** They faded linearly with daylight, and the night grade
      was deepened from ~0.30 to ~0.15 — so they sat at a few percent of strength
      across most of a run, present in the code and invisible on screen. The fade
      is now curved, strength 0.42 → 0.60, and drift is quicker because on a
      field half again as large the old speed read as a static gradient.

- [x] **Smoothing option.** Off by default and it should stay off — the art is
      authored as pixel art. Seven hardcoded `TEXTURE_FILTER_NEAREST` sites now
      ask `Graphics.canvas_filter()` and join a group so the toggle applies to
      the field being looked at. Like brightness, it does not knock the quality
      preset to Custom: it is about the screen, not what the machine can afford.
- [x] **Main menu: pixel art, and alive.** I argued for keeping the painterly
      key art — a backdrop shares a frame with a pixel-art beast standing in
      front of it, key art shares a frame with nothing — and the owner overruled
      it on 2026-08-21. Their call, and the right one: a first screen is a
      promise about what the game looks like, and one made in a different medium
      is a promise the game does not keep.

      `MenuStage` composes six layers over a 688x384 pixel vista. The backdrop
      is authored with its **middle deliberately empty**, because the thing that
      goes there is the game's own beast on the game's own idle frames — not a
      menu-only illustration of one. That is the whole point of putting it there:
      the thing on the front is the thing you get, down to the town on its back.

      Everything else is motion, each layer on its own rate and period so the
      composition never comes back into phase: the backdrop drifts on two sine
      waves over a 1.03x overscan, the beast counter-drifts at 0.55 of that so
      the two separate in depth, two mist bands breathe, embers rise out of the
      valley pre-seeded across their own lifetime, stars twinkle on individual
      phases, and the horizon glow swells on a twenty-second breath.

      Three things had to be found rather than assumed. A Control's `size` is
      zero in `_ready` and `resized` never fires for a node added after its
      parent has settled, so everything laid out at the origin at native scale —
      it keys off the viewport rect instead. The beast frames carry a hard dark
      ground line under the feet, which is right in the beast scope where there
      is ground and drew as a black bar ruled across the road here; the row is
      *detected* and cropped, because a row number written down would stop being
      the right one the next time the frames are generated. And the mist began
      as slices of the backdrop, on the reasoning that a strip of the vista is
      already the right colour — it drew two flat grey rectangles, because what
      makes mist is having no edges at all. It is a shader now.

      `tools/menu_shot.tscn` captures the menu and the board over it. The front
      door was the one screen no shot tool covered: `ui_shot` captures the in-run
      interfaces and every one needs a Run the menu deliberately has no part of.
      It proves the drift and the idle cycle by driving `_process` rather than by
      waiting — and it samples a whole cycle, after reporting "no change" once
      because the seven-frame idle happened to land back on frame one.
- [x] Leaderboards — **live and verified 2026-08-25.** The `runs` table exists
      on the configured project, answers 200 with rows, and its schema matches
      the contract in `docs/LEADERBOARD.md` field for field. The anon key in
      `Leaderboard.ANON_KEY` is the one that project answers to.

---

## 3. Presentation and juice

### Lighting and atmosphere

- [x] Torch light: even, unblown, readable, and reaching the bend corners.
- [x] Cloud shadows crossing the whole ground. The shader was there and had a
      real bug: a `ColorRect` has no texture, so `TEXTURE_PIXEL_SIZE` is (1,1)
      and the world reconstruction collapsed the whole field into a half-unit
      square. Divided by a 900-unit cloud scale that sampled one point of noise
      for the entire battlefield — a flat wash, not cloud. The quad now passes
      its own world size in, and is sized from the same extent the floor uses so
      it covers exactly the ground it passes over.
- [x] Night at minimum brightness. Two things were missing, and the second was
      the real one.

      **There was no brightness setting at all.** I had deepened the night grade
      from ~0.30 to ~0.15 and left players on a dim screen with no recourse.
      Added under Display, as a lift toward white rather than a gain — a gain on
      a near-black tint leaves it near-black, which is the exact case the control
      exists for. Capped at +55%: at a full lift the day/night cycle stops
      existing, and a setting that can erase a core system will erase it by
      accident. It does not knock the quality preset to Custom, because it is
      about the player's screen, not what their machine can afford, and it
      re-grades a field that is already standing so changing it from the pause
      menu does something.

      **`tools/night_check.tscn`** then answers the row: at the darkest legal
      grade, is the road distinguishable from unlit ground, and an enemy from
      what is behind it. Windowed, not headless — it measures pixels.

	  Getting it to *mean* anything took five wrong versions, each of which
	  returned confident numbers: a hand-rolled world→screen mapping that drifted
	  once the camera followed the hero; sampling at the enemy's node origin,
	  which is at its feet, so it compared road against road and reported a
	  separation of exactly 0.000 twice; freezing the enemy at spawn, which froze
	  its spawn-in part way; and comparing against a point a fixed distance to
	  one side, which landed on road, ground or torchlight depending on where the
	  enemy stopped. The fifth used authored 1920×1080 canvas coordinates against
	  the stretched 1440p/4K viewport texture, confidently sampling the wrong part
	  of the frame. It now composes the canvas and screen transforms, then samples
	  the sprite against the ring around it, which is the question a player
	  actually asks and is asked the same way wherever the enemy stands.

	  Corrected 1440p measurements put the road around 0.078 above ground and the
	  conservative sprite-disc mean 0.007–0.021 away from its local ring. The
	  thresholds sit below those floors (0.025 and 0.005), where scatter cannot
	  make a good build red but an unlit road or invisible sprite still collapses
	  to zero. The check also saves its final frame for visual review. 5 of 5 runs
	  pass.

      Windowed, so it cannot run on CI. By hand, like the save-backup check:

          godot --path game res://tools/night_check.tscn

### VFX

- [x] Painted projectile heads over the existing procedural flight.
- [x] Elemental impact bursts layered over sparks and blast ring.
- [x] Tower AoE pools. Painted per element, then varied per cast: any rotation,
      scale jitter, a few degrees of hue drift, a bloom-in and a slow turn while
      it burns. Four files, and no two casts look stamped — the variety lives in
      the placement, the same way it does in the ground tiles. The exact-radius
      ring survives underneath at low alpha, because the art is ragged on purpose
      and the damage edge is the one thing that must not be vague.
- [x] A juice pass across everything that fires, lands, dies or completes. The
      audit had a clear shape: *fires*, *lands* and *dies* were all spoken for
      already, and **completing** something was not. Four things happened in
      total silence — clearing a wave, felling a boss, levelling up, and getting
      back on your feet.

      Each has a visual and a sound now. The sounds are layered from cues that
      already ship rather than four new recordings, which is the call the boss
      phase change made and for the same reason: an untracked asset is worse than
      a composite that works.

      One judgement worth naming. A wave clearing is **relief**, not triumph, so
      it is the quietest of the four and the only one with no second layer —
      celebrating survival as hard as a boss kill flattens the difference between
      them. Levelling up gets rays rather than a ring, because a ring reads as an
      area of effect and nothing on the field was touched: the player changed.

### Roads and ground

- [x] Per-region road sets and Wang-tiled ground floors.
- [x] Road edge stroke, per environment. Derived from the road's own colour
      rather than a fixed dark line — a sand road wants a warm shadow and a snow
      road a cold one, and one black outline on both looks like a sticker. Two
      steps of falloff, so it reads as depth rather than as an outline.
- [x] **The battlefield floor.** The environment audit called this the largest
      visual gap in the game, and it was three separate faults stacked.

      *Resolution.* Production floors are now sixteen 64px Wang tiles at two
      world units per texel, giving the battlefield a 3264px-class baked surface
      with real crack, root and mineral grain. Roads are also 64px sources baked
      on an exact 3x pixel grid. Both floor and road select deterministic legal
      dihedral variants per cell, preserving corner/edge topology while changing
      which roots, scars and wheel ruts face the eye; the repeated stamp from town
      to map edge is gone without sacrificing seed reproduction.

      *Brightness.* The jungle floor's base material had a **median luminance of
      19 out of 255** — near black, across most of the battlefield, for months.
      That is the "black void-like seams". Snow had a near-black lower against a
      near-white upper, 5.1x apart, reading as holes cut in a snowfield. All
      three sets regenerated, lineless: outlines on a *floor* gave the earth a
      repeating waffle and put a purple fringe around the moss.

      *Palette.* The generator does not take a palette, only prose. The jungle
      set came back with 20% of its pixels outside any hue a jungle floor has —
      magenta and blue noise that clustered into pink patches. `tools/conform_ground.py`
      folds out-of-gamut hues to the nearest edge of a region's declared arcs and
      caps saturation, touching nothing else; it is idempotent, so the committed
      PNG is reproducible from the generated one.

      Two things came out of it that were not planned. `run_tool.gd -- floor-tiles`
      is now a CI gate: four rules, each one written because a real regeneration
      failed it, and it independently reproduces both shipped defects. And which
      of a region's two materials *dominates* is now per-region data — generated
      in tileset order, the jungle drew a dry terracotta field with green patches,
      the right materials in the wrong proportion. `TerrainData.moss_dominant`
      flips the corner mask to its complement, which reads the same sixteen tiles
      the other way round and needs no second set.

      Measured effect on night readability, which was the worry: enemy-against-
      ground separation went from **0.005 against a 0.005 threshold** — exactly
      on the line — to **0.017**.
- [x] Higher-resolution regional road art: all three 16-mask sets now ship at
      64×64 and the manifest/gate derive their seam bands from source size.
- [x] Snow crosshatch replaced by a restrained dirty steel-blue/oxblood set;
      the production exposure conform caps white rims before import.
- [x] Deterministic texture variation within roads and floors using legal
      rotations/reflections that preserve every N/E/S/W or Wang-corner contract.

### Foliage

- [x] Per-act painted foliage: one plant per region, scattered *among* the
      procedural blades rather than replacing them. The polygons are what make
      the ground look covered and cost almost nothing; the sprite is the plant
      the eye stops on. Tinted toward the region's own sampled ground palette so
      it sits in the same light instead of looking pasted on.
- [x] More silhouettes: reeds come in straight and bent, and any region grows an
      occasional broadleaf. One shape per region read as a hatch pattern.
- [x] Idle animation on anything not static: blades and painted plants sway,
      towers and buildings breathe, the beast walks.
- [x] Per-plant hue and saturation jitter, deliberately small — the palette is
      sampled from the region's own ground, and a wide jitter would put plants
      outside their act.
- [x] **More kinds per act, and the art to fill them.** A fourth regional kind
      (`bush`, one per region) and two more shared props, generated and
      integrated: 595 manifest assets, all real art, no placeholders.

      It was files plus one list, as predicted. `REGIONAL_KINDS` and
      `SHARED_KINDS` gained a name each and the path convention did the rest -
      no other code changed.
- [x] **Fallen logs**, plus stumps. Shared props rather than regional: a fallen
      log is a fallen log in a jungle or a snowfield.
- [x] The new kinds sway with everything else. They are painted plants and pick
      up `painted_material()` from the same scatter path the existing kinds use,
      so opting in was not a step - not opting in would have been.

      **The art-direction question that blocked this is closed.** The pixel-art
      restyle already happened and shipped: `beast_scope.gd` says the backdrops
      "are 688x384 pixel art now", 53 PixelLab structure packages are gated, and
      the rendered game is unambiguous. `ASSET_MANIFEST.md` §1 and
      `PIXELLAB_PROMPTS.md` §0 still describe the old painterly style and are
      stale on that point alone - their paths, sizes and contracts are current.

### Towers and buildings

- [x] Idle animation on every tower and building, always running. Every one of
      the 26 towers and all 27 building tiers now has an authored four-pose
      PixelLab package. Runtime loading follows the id-derived path convention,
      scatters phase per instance, and composes with beast-step wobble. The old
      transform breathe remains only as a damaged-install fallback.
- [x] PixelLab art package for every tower and building. The complete batch is
      78 tower continuation frames, 18 higher-tier building bases and 81
      building continuation frames. `structure_art_check.tscn` gates all 53
      packages at exact size, alpha, stable ground anchor and bounded silhouette
      drift. Blind role/tier readability remains a human acceptance row in the
      production audit, not an ungenerated-asset task.
- [x] Beast walk/idle as authored frames, layered over the procedural gait.
- [x] Building tier variants — all nine buildings now have distinct tier-two and
      tier-three architecture, and every tier has its own idle package.
- [x] **Tower attack animations** — as a procedural recoil, and that is an order
      of work rather than a substitute for one. Twenty-six towers would be some
      seventy authored frames; a transform kick reads at every zoom, arrives free
      for any tower added later, and still composes with authored poses when
      somebody draws them, exactly as the idle loop already does (it replaces the
      texture while the same code drives scale and rotation). Gated on both
      halves: firing must shove the tower, and the shove must fully settle — a
      kick that never quite decays leaves every tower a few pixels off its own
      base and reads as misaligned art months later.
- [x] **The city moves**, as gait and jolt rather than authored frames. Two
      reasons, and neither is cost: the sprite is 512×512 and cannot be round
      tripped through the art tool at all, and a city gently scaling reads as
      wobbling masonry. What a city on the back of a walking beast should do is
      rock with the gait — which is also simply true of where it is standing.

      The hit reaction was the real gap. Being struck flashed the sprite white
      and shook the camera, and that was all: shaking the camera says "you were
      hit" while shaking the *city* says "the city was hit", and only the first
      sentence was being spoken. Gated on both, including that they settle.
- [x] **Torch base shadow.** Done and gated (`torch`), the row was simply never
      ticked. `add_contact_sized` rather than `add_contact`, because the ironwork
      is `Polygon2D` and has no texture to measure.

### The beast scope

- [x] Sidescroller background as a procedural tileset — one 16-tile set per act.
- [x] The beast as a proper sidescroller sprite with walk and idle animations.
- [x] Idle while Preparation is paused. The gait, the footfalls and the step
      shake all wind down rather than cut — a gait that stops on the frame the
      phase changes reads as a freeze. Gated by a test that drives `_process`
      synchronously and measures the gait phase; measuring the footfall signal
      proved nothing, because footfalls only fire when the beast camera is
      current and a harness looking at the battlefield never sees one.
- [x] **Procedural background with parallax.** Two drawn silhouette bands: a
      hazed ridge between the sky and the ground, and a near band that passes in
      *front* of the beast. `FOREGROUND_SCROLL` had been sitting in
      `beast_scope.gd` unused - the shape of a layer planned and never built.

      Drawn rather than painted, which is what made it possible at all: new
      painted art is an art-direction task this toolchain cannot do, and a
      distant ridge is one flat colour under a skyline once haze has taken the
      detail out of it anyway.

      Seamless by construction rather than by tiling. The profile is a sum of
      sines whose frequencies are whole cycles across the band's own width, so
      the curve at the far edge equals the curve at the near one by arithmetic
      and translating by one width is invisible. The painted backdrop next door
      has to mirror itself precisely because it lacks that property.

      **Three things were wrong and only looking found them.** The ridge was
      first coloured from `_ground_tint()`, which is a *modulate* and therefore
      near-white by design - it drew a white wall across half the sky. The
      silhouette used `absf(sin)`, which puts a cusp at every zero crossing and
      came out as a row of black triangular teeth. And the near band kept 14% of
      the horizon colour, which against pale desert sand is a hole punched in the
      screen rather than ground. Screenshots at all three acts, each time.

### Weather

Not new scope: §159, §193, §1045 and §1098 all build on weather and §1350
still lists it unfinished. Today it is not visible at all.

- [x] **Rain**, with drops that land. Falling streaks plus small expanding rings
      where they hit, on their own sparser grid - reusing the fall grid would put
      a ring under every drop, which is not what water does.
- [x] **Snow**, with accumulation and melt. Settles in 90 seconds of continuous
      snowfall and takes 240 to go, and the asymmetry is the design: snow that
      left with the clouds would be an overlay tied to a switch rather than a
      thing that happened. The gate asserts melting is slower than settling.

      Lying snow is a patchy noise layer *above* the floor and below the sorted
      units. The first attempt was a `modulate` on the ground sprite and cannot
      work - a modulate multiplies, and multiplying a dark jungle floor by
      anything still leaves a dark jungle floor. It is also why the units are not
      whitened: a wave that cannot be read is a worse problem than a field that
      is not snowy enough.

      The roads staying dark is luck rather than design - they draw above the
      snow layer - but it reads as paths trodden through the snow, so it stays.
- [x] **A shader, not particles**, which is the whole performance story. This
      covers the entire field, so particles would need thousands to look like
      weather and would cost per-particle CPU every frame - on the GL
      Compatibility renderer this ships with, and in a browser tab. A fragment
      shader costs screen area rather than density, so heavier rain is free.
      `menu_stage.gd` picks CPUParticles2D for its embers for the opposite and
      equally good reason, and the code says so in both places.
- [x] Authored per weather rather than branched on an id: precipitation kind,
      density, wind, speed, tint and whether it settles are all fields on the
      `.tres`, so a new weather is still a file.
- [x] **Precipitation falls down.** It did not: the shader sampled at
      `p + offset`, which moves the *pattern* the opposite way from the offset,
      so adding to both axes made rain drift up-and-left at about 36 degrees off
      vertical. Reported as "rain and snow fall leftish". Subtracting fixes the
      direction and makes a positive `wind` blow right, which is what a positive
      number in a `.tres` ought to mean.
- [x] **Snow on the paths, feathered.** A second, much fainter snow layer sits
      *above* the roads, so the paths take a dusting and a drift carries across
      the kerb instead of stopping at it. Both layers sample the same noise at
      the same world position, so the continuation is exact and costs nothing.
- [x] **Snow melts to the weather, not just to the clock.** Rain washes it off
      and a heatwave burns it away - authored per weather as `snow_melt_scale`,
      so a cold drizzle that leaves snow alone needs no code change.
- [x] **Snow makes enemies slip.** Rolled per step against how much snow is
      actually lying, from the combat stream so a seeded replay slips in the
      same places. Sideways rather than forwards, composed with the walk rather
      than replacing it, so it reads as a stumble. Puppets never slip: on a guest
      their footing was decided on the host.
- [x] **Answers to the graphics preset.** Density scales with
      `Graphics.particle_scale()` and the three depth layers drop to two at
      medium and one at low - the real saving, since density in a shader is only
      a threshold while each layer is a whole extra pass per pixel. Both snow
      layers are hidden outright at zero cover rather than left drawing nothing.
- [x] **Weather drives the foliage wind.** `WeatherData` carries an authored
      `wind` field — duststorm 0.95, downpour 0.55, snowfall 0.30, clear 0.18,
      heatwave −0.04. Deliberately *not* derived from the rain:
      `precipitation_wind` is the slant of what is falling and says nothing on a
      dry day, and a duststorm is wind you can see while a heatwave is dead air.

      The shader gains a steady lean on top of its oscillation, which is the half
      that reads as wind rather than as agitation — a breeze waves, a gale holds
      the grass over and *then* waves. Written to the two shared materials, so a
      weather change costs two parameter writes however much grass is on screen.

### Wildlife and ambient life

- [x] **Ravens and wildlife**, as one data-driven system (`scripts/systems/
      wildlife.gd`). **Six kinds** — raven, fox, rabbit, deer, squirrel, raccoon
      — each a `.tres` in `data/wildlife/` plus a sprite named for its id, so a
      seventh is a file rather than a branch. (Four at first; the owner asked for
      six on 2026-08-25.)

      **Three things play reported, and two of them were mine.** They were tiny:
      scales were judged against each other rather than against the hero, who is
      about 224 world units tall — a deer is 3.0 now, not 0.95. They walked
      backwards: the sprites are drawn facing *left* and the flip was written for
      right-facing art. That is a declared per-creature flag now rather than a
      global assumption, which immediately earned itself when the squirrel came
      out of the generator facing right regardless of the prompt.

      And they had no move animation — walking borrowed the standing pose and
      bobbed it, which reads as a cut-out being slid along the ground. There is a
      `_move_01` convention beside the idle one now, sharing one loader, so a
      creature can ship with either sequence, both, or neither.

      The variation is built in the way the row asked for: arrivals are a coin
      flip against a chance, not a top-up to a target count. The cap is a ceiling
      on cost rather than a number to be reached, so the field is genuinely
      sometimes empty and sometimes busy. A fixed population reads as decoration
      however good the sprites are, because the eye works out inside a minute
      that there are always exactly six.

      Ravens fly in from above and leave the same way; the rest walk in from the
      side. Nothing pops into existence in the middle of a field. A raven's
      skittish radius is deliberately zero — they are the animals that turn up
      *because* of a battle rather than in spite of one — while a rabbit bolts
      at 240 units and runs at three times its walking speed.

      Animation is authored idle frames where they exist and a procedural bob
      where they do not, which is the same choice the structures make. Skittish
      checks look at heroes only: testing every enemy would be a distance check
      per animal per enemy per frame to decide whether a rabbit twitches.

      Acts gate who appears, and the field clears when the act turns — a deer
      standing in Act III ash is worse than an empty field.

- [x] **Kept out of the lanes**, and the gate found the real bug here twice. The
      first version of the check asserted no animal *stands* on a road and was
      reporting correct behaviour: a deer crossing a lane is a deer crossing a
      path, and that is the whole point of having them. The invariant that
      actually matters is that nothing ever **chooses** to stand there, and
      testing that turned up two genuine holes — a group's spread offset was
      never validated against the anchor that was, and the wander fallback
      returned `home` unchecked, so an animal that had fled onto a road could
      adopt it as somewhere to live.

### UI and controls

An earlier pass made the bottom bar one row. The remaining objection is that it
is a horizontal bar at all.

- [x] **The scope bar is a vertical icon column** on the right edge - three new
      128px icons (crossed blades on a shield, a gate keep, the beast in
      profile), zoom, and the menu, in 58px squares matching the combat row.
      Shortcuts moved into tooltips: "F1 Battlefield" names a key a phone does
      not have.
- [x] Less padding and sitting higher - y=104 rather than 196. Being narrow is
      what allowed it: a wide row had to sit below the centred status band, and
      a column passes beside it.
- [x] **It does not overlap the build sheet**, and the sheet is *inset past the
      column's width* rather than only moved down. The sheet's height changes
      with its contents - eight towers or one upgrade - so a rule that depends
      on it staying short breaks the first time somebody adds a tower. A
      column's width does not change.
- [x] **The command menu is a column in the top left**, which is what freed the
      bottom right for the build sheet.
- [x] Judged on a phone, and that is where the value was: **the touch layout had
      never actually passed**. Three overlaps and five undersized controls, none
      of them caused by this work - verified by stashing it and re-running. The
      touch run now has its own row in `guard.yml`.

      Worth recording, because the pattern will repeat. The desktop gate passed
      while a screenshot showed the bar still carrying "F1 Battlefield" text on
      every button and the build sheet covering the bottom two. A rectangle
      check has no opinion about a button that should not say anything, and the
      overlap it missed was hidden by the sheet being *drawn* over the column
      rather than intersecting the leaves the check compares. **Look at it.**

      One of the three faults was the gate's own: `canvas_items` stretch scales
      the interface by window/base, so it measured a 120px thumb floor against
      118.2 screen pixels - a property of whatever size the headless window
      opened at, not of the button. It now measures in the units the floor is
      written in.

---

## 4. Production readiness

- [x] Controller parity. There were **no joypad bindings at all** — and nothing
      said so, because a missing binding is not an error: the action simply never
      fires. Added as a layer applied before defaults are captured, so a pad
      binding is part of the defaults and "reset" restores it rather than
      stripping the controller out.

      Left stick moves and right stick aims, read directly for a radial deadzone
      and a rescale from its edge — `Input.get_vector` treats each axis
      separately and turns a diagonal push into a square corner. The stick is
      *also* bound to the four move actions, so anything else reading movement
      gets it free. Gated by a test that every rebindable and every `ui_*` action
      carries a pad event, and that re-applying does not duplicate bindings.
- [~] 60 FPS at 1920×1080. `tools/perf_check.tscn` measures it, asserts growth
      always and asserts frame timing **only when a real renderer is present** —
      the dummy renderer does no GPU work, so a headless frame rate says nothing
      about a real one. It runs in the release workflow every publish.

      **The frame-rate number still has to come from a windowed run on real
      hardware:**

          godot --path game res://tools/perf_check.tscn -- --seconds=120 --build

      **Post-structure-animation developer-hardware pass, 2026-08-20:** RTX 3070
      Ti, High, 1920×1080, 120 measured seconds: 62 FPS average, 19.7 ms p99,
      29.9 ms worst, zero hitches over 33 ms, +0 orphans, +0.4% nodes and +0.2%
      memory. This is the current release evidence after all 53 authored frame
      packages were live. The earlier foliage batching pass converted roughly
      1,380 polygon draw commands to one static mesh per depth band.

      The row remains partial until minimum/recommended hardware are defined and
      qualified; one high-end developer machine is not the shipping matrix.

      One real finding stands: the field carried **107 PointLight2D**, from
      torches going 24 → ~60 with their radius raised 225 → 360. Every 2D light
      redraws everything it covers. One post in two now carries a pool — the rest
      keep flame, glow and smoke and are lit by neighbours — taking it to 75 with
      no visible difference, since the pools overlap heavily at that radius.

- [x] `save_backup_check.tscn` re-run for `SAVE_VERSION` 6 on 2026-08-20 — all
      five rows pass (unreadable save backed up, backup byte-identical, survives
      a second mismatch, v1 source
      preserved, v2 terrain rename with unknown ids kept).

---

## 4b. Scope changes - ruled on 2026-08-24

Raised and ruled on the same day. Every item here either reverses something v4
locks or adds a system v4 does not describe, so each needed an owner rather than
an agent. **The owner ruled yes to all of it on 2026-08-24.**

The two re-cuts are recorded where they belong - GDD §54 and §448, and the
CLAUDE.md re-cut table - rather than only here. This section tracks the *work*;
those files carry the *decision*.

Ordering note: co-op and the zero-capital start both re-tune the same difficulty
surface, and doing them as two separate balance passes means doing the second
one twice. They share a pass.

**Progress, 2026-08-25.** The zero-capital start is built and green. Co-op
has its design settled and written down; no netcode is written yet.

### Cut in §54 - needs a recorded re-cut

- [~] **Two-player co-op.** Design settled in `docs/COOP_DESIGN.md`, and
      **all six steps are built and gated** (2026-08-25). The owner's three rulings:
      **two heroes, one each**; **desktop-to-desktop only** for now, with the
      web build staying single-player; **one shared resource pool**.

      Decided in the design pass rather than left open: **host-authoritative,
      not lockstep**. Seeded reproduction was built to make a *replay*
      reproducible on one machine, which is a different problem from holding
      two live machines in agreement - and lockstep needs bit-identical float
      behaviour across different CPUs to avoid silent desync. Host authority
      also settles rule 6 by strengthening it: the host's `RunState` is the
      one that exists, and the guest's is a read-only mirror.

      The transport was verified against this engine rather than recalled -
      `ENetMultiplayerPeer`, `SceneMultiplayer`, the peer signals, and
      `MultiplayerSpawner`/`MultiplayerSynchronizer` are all present in
      4.7.1, and a server stands up. ENet does not work in web exports, which
      is exactly why the desktop-only ruling removes the relay host, the
      signalling service and the bill.

      The one design question that note left open is now closed: **both
      players go on raids** (owner, 2026-08-25). The alternative would have
      left the holding player watching a frozen battlefield, and making that
      interesting means letting the field tick during a raid - which breaks
      working rule 8 outright. Extraction windows are a joint decision
      rather than per-player, or the same problem reappears inside the raid.

      **Step 1 — lobby and transport.** `game/autoload/Coop.gd` owns the peer
      and the session state machine; `tools/coop_check.tscn` stands a host and
      a guest up in one process over a real loopback socket and is in
      `guard.yml`. No lobby *screen* yet, on purpose — that belongs with the
      UI pass rather than being built twice.

      The load-bearing detail: `Coop` reads its own `multiplayer` property
      rather than the tree's, because a `MultiplayerAPI` is registered per
      subtree. That is the entire reason co-op can be tested on a push instead
      of needing two machines. A subtree's API is also not polled by the loop
      that drives the default one, so the harness pumps both by hand.

      `is_host()` answers **true** in single player, deliberately: a lone
      player is the authority over their own run, so every downstream
      permission check reads the same in both modes and the single-player path
      cannot rot from being the branch nobody exercises.

      New EventBus signals (CLAUDE.md §6): `coop_state_changed`,
      `coop_partner_joined`, `coop_partner_left`, `coop_failed`.

      **Step 2 — the relay layer.** `scripts/systems/coop_relay.gd` is the one
      place a message crosses the wire, and nothing in the battlefield, town or
      beast scope knows a network exists. Host-authored facts forward and
      re-emit on the guest's own bus; guest requests travel the other way and
      stay requests; cosmetic signals are not relayed, enforced by *omission*
      from the binding table rather than by a decision at each call site.

      Raw packets rather than `@rpc`, because `@rpc` resolves by node path and
      the harness has host and guest at different paths in one tree — a
      path-bound relay could not be tested in process at all. The bus is
      injected for the same family of reason: two machines have two buses, and
      sharing the autoload would echo facts forever and trip the guard on
      traffic that never crossed a wire.

      **The guard is the row that matters.** A host-authored fact originating
      on a guest is caught at the moment of emission and named. It cannot be
      enforced by review — one system breaking it once is enough for two
      machines to disagree, and the desync would be debugged nowhere near the
      cause. It records rather than throws: crashing a run in front of two
      players is worse than a loud log and a gate that fails next push.

      New EventBus signal: `coop_request_received(kind, args, from_peer)`.

      **Step 3 — two heroes.** The hero stopped reading `Input` directly. It
      did so in five places, which is right for one hero and wrong for two;
      the alternative was an "is this hero mine" test at each site, and the
      failure mode of getting one wrong is a partner's hero that twitches
      whenever the local player walks. A hero now asks its own `HeroInput`
      and never learns which kind it is.

      Sticks are levels and buttons are edges, handled differently on
      purpose: a newer move vector replaces the older one, while presses are
      latched until read. Packets and physics frames do not line up, so
      assigning the button mask instead of OR-ing it drops the press landing
      in the gap — an attack that never comes out every few seconds, for no
      reason the player can see.

      Hero state needed no new send path: `CoopHeroes` emits it on its own
      bus and the relay forwards it like any other fact, so the authority
      guard covers hero positions for free.

      Not solved yet, and flagged rather than hidden: the guest's own hero
      keeps simulating between state packets, so it will visibly correct
      under latency. Proper prediction is a later refinement — a hero that
      only moves when a packet arrives is worse than one that snaps.

      **Step 4 — enemies and towers over the wire.** Towers turned out to be
      almost free, and that is a dividend rather than luck: `battlefield.gd`
      already rebuilt every tower node from `RunState` on one signal, so a
      guest told what stands where writes it and the tower appears. The gate
      asserts that property directly — if it stops being true, towers need
      real replication and the system needs rewriting rather than patching.

      Enemies are mirrored as puppets. Identity is an assigned integer, not a
      node name: names are unique within a parent, not across a wire, and
      Godot renames on collision. A puppet decides nothing — no targeting,
      walking, damage or payout — while its sprite, facing and walk cycle run
      through the same code as a real enemy, so a guest's field looks alive
      rather than like a slideshow.

      Removals are computed by the *host* comparing its own view against
      itself, never inferred by the guest from a missing batch entry — which
      would empty the field the first time a packet arrived late. That also
      keeps `Enemy` free of any knowledge that a network exists.

      **What the gate deliberately does not claim.** The build order asked
      for "a wave runs identically on both sides", and one process cannot
      honestly assert that: there is one `RunState` autoload, so a simulated
      guest shares the host's run state and the two cannot disagree.
      Everything identity rests on is gated instead. The remainder is a
      two-machine play test — see the row below.

      **Step 6 — the world, not just the things in it (2026-08-25).** Play
      reported six gaps, and they shared a cause: both machines were
      *simulating* a great deal they should have been *told*. Small
      individually; together they were two players standing in different games
      that happened to look alike.

      *Ride On is one decision.* Both players had to press it, and each machine
      then ran it locally and rolled its own next wave from its own stream — so
      the two saw different enemies, which is exactly how it was reported.
      Either player may press it now; the guest asks and stops, and the phase
      change, spawns and wave number come back as facts. Routed through the
      same handler a local click uses, so the coverage warning and breather
      rules apply identically however it arrived.

      *One world clock*, rather than three signals relayed separately: distance
      walked, weather, act. Time of day is *derived* from distance, so sending
      distance keeps both skies, night flags and the night difficulty bonus
      identical without replicating the derivation at all. Weather is
      re-announced only on change — it arrives twice a second and
      `weather_changed` starts a three-second fade, so re-emitting it every
      packet would restart that fade forever and the rain would never arrive.

      *Enemies carry combat state.* The wind-up is the telegraph the whole
      dodge window rests on; a puppet that mirrored position but not the fact
      it was about to strike killed the guest with no warning. Played on the
      transition rather than per packet, or the enemy shudders in place for the
      whole wind-up. DYING is never taken from the wire — a puppet leaves
      through `dismiss`, and a packet pushing it into dying starts a second
      death alongside the one already running.

      *Pause is shared*, or it is not pausing: one player stops while the other
      fights a wave still walking on a machine that has stopped simulating it.
      Either player may do it — needing to put the game down is not an
      authority decision. Applied directly on receipt rather than through the
      announcing path, which has the two telling each other to pause for as
      long as anyone cares to watch. The pause *panel* stays local.

      *Deaths and revive.* Deaths are watched as a change against last frame
      rather than hooked to `hero_died`, because that signal cannot say which
      of the two heroes it was — and the roles swap across the wire. Revive is
      an **acceleration of the existing respawn**, not a separate downed state,
      and that is a design call worth stating: the wound, reduced health and
      invulnerability window are what make dying cost something, and bypassing
      them would make two players *safer* than one rather than *better* than
      one. The second player buys time, and pays for it by leaving a lane.

      **Step 8 — the second play report (v0.4.50).** Four things from play, and
      a fifth and sixth found while fixing them.

      *Facing.* Partners walked around permanently pointed at their own cursor,
      while every player sees their own hero face the way they are **walking**.
      The cause was applying the relayed aim vector directly. `_update_facing`
      already resolves this properly - attack beats movement, movement beats
      cursor - so a mirrored hero now just runs it from the relayed input and
      cannot disagree with its owner by construction.

      *The guest stayed in build mode through a wave.* The relay re-emitted
      `phase_changed` on the guest without ever **writing** the phase, so every
      listener heard that combat had begun while `RunState.phase` still said
      Preparation - and `can_build_now()` reads the phase. Replaced with a
      host-authored `coop_phase` that the guest writes, exactly like tower
      state; the guest's own `phase_changed` then follows from the write.

      *Cinematic skips are shared.* Either player's skip skips for both. Only
      the whole-cinematic hold crosses - advancing one panel stays personal,
      because reading speed is, and yanking the page out from under somebody
      mid-sentence to keep two machines in lockstep is worse than a few seconds
      of drift the next hold resolves anyway.

      *Guest-initiated pause never reached the host*, found while wiring the
      above. It tripped the authority guard and was dropped silently, so a guest
      pausing left the host fighting alone. Pause now travels as a **request**
      the host answers - the existing model, rather than a softer guard.

      *`String(int)` threw in `Score.row()`* on **every** completed run, taking
      the results screen's score line and the leaderboard submission with it. A
      run seed is an int and Godot 4 has no such constructor. Found because the
      new revive gate is the first check that ends a run - which is the argument
      for gates that finish things rather than sampling the middle.

      **The revive redesign, and why the first one was wrong (owner's re-cut,
      2026-08-25).** v0.4.49 made a partner *accelerate the respawn*: the wound,
      the reduced health and the invulnerability window all still applied, on
      the reasoning that two players should be better than one rather than
      safer. The owner re-cut it, and the new rules are better because they put
      the cost somewhere the players can act on:

      * one player down costs the run **nothing** - no Wound, and no clock that
        would quietly stand them up without anybody helping
      * a partner holds `revive` within 150 units for three seconds and returns
        them **where they fell**, at 35% health - fragile, and standing in the
        open during a wave was the price
      * both down at once costs **one** Wound between the pair
      * three Wounds ends the run, exactly as in solo play

      Progress decays when the helper lets go or is driven off, or three seconds
      in the open would not be the cost it is meant to be. The hold travels in
      its own mask beside the button bits, because a button is an edge and is
      latched until read while a hold is a level - a latched hold would revive
      somebody the player had already let go of.

      Gated deliberately hard, because every rule above is a negative or an
      off-by-one: none would announce itself by failing visibly, and the
      double-charge in particular would look only like a run that ended early.
      `is_alive()` now counts a downed hero as not alive, which is what stops
      beast steps walking them out from under their own revive bar.

      **Step 7 — towers shoot, and hits are felt (v0.4.50).** Held back one
      version on the belief that relaying every shot would be the heaviest
      traffic in the game. It is not: twelve towers at roughly 1.5 shots a
      second is about 18 messages a second against the enemy batch's ten
      packets carrying thirty bodies each — call it 6%. The estimate was wrong
      and the decision went with the measurement.

      A guest's towers are now **puppets**: they never acquire, and they fire
      only when told. Left autonomous they were not merely redundant but
      actively divergent — cooldowns, target priority and the closeness
      tie-break all run against puppet positions that are a batch old, so the
      two screens showed different towers shooting different enemies. The host
      sends *where* the shot went rather than *which* enemy it was: a position
      needs no identity to survive the wire, no lookup at the far end, and the
      same batch that placed the puppets placed them against those exact
      coordinates, so the nearest one is the enemy the host meant. If it has
      since died the shot is skipped, because a homing projectile with nothing
      to home on flies off the field.

      `tower_fired` stays local and unrelayed — every machine emits it for its
      own muzzle flash. The host-authored `coop_tower_fired` is a separate
      signal, which is what keeps the guard meaningful: a shot is an *event*,
      and quietly adding `tower_fired` to the announcements list to stop the
      guard shouting would have weakened the one check that catches a guest
      inventing facts.

      **Hit feedback was the bigger bug, and it was invisible from the host's
      seat.** A guest's own hero swings at puppets, `take_damage` correctly
      refuses — and so the player saw no number, no spark, no recoil, only a
      health bar quietly draining. That is not a missing flourish, it is the
      feedback loop of attacking, absent. `mirror` now plays the reaction for
      whatever health was lost since the last packet: one number per batch
      window rather than per hit, which is a fair summary of damage the host
      never itemised. Status effects were guarded at the same time — slow,
      chill and burn were still landing locally on puppets, which is the same
      class of mistake damage had already been fixed for.

- [~] **Second play report, 2026-08-25 — and almost every symptom was one bug.**
      Enemies ignoring the guest, the guest taking no damage, the guest never
      being targeted by melee or ranged, loot flying only to the host: all of it
      was `hero_node()` meaning *this machine's player* and enemies asking it.
      There is a `nearest_hero()` now, kept distinct because the camera and the
      HUD genuinely do want the other question.

      **The guest was running its own waves.** The relayed phase change woke its
      wave director, which began spawning a formation of real enemies from its
      own queue that the host had never heard of. The guest was looking at two
      waves — one mirrored, one invented — which is the whole of "some enemies
      are only visible to one of us".

      **Hero health was never replicated at all.** Each machine simulated its own
      copy, so the two held different opinions about whether anybody was hurt,
      and a guest could die locally while standing up on the host. It travels as
      a fraction now, applied against each hero's own maximum, because the two
      arrive at different levels.

      **The stutter was a second, separate flaw.** Puppets aimed to arrive
      exactly as the next packet landed, so a packet one frame late left the body
      standing still and then jerking. They coast on their last known speed now
      and are redirected rather than restarted.

      Also: loot replicates (host places and banks, guest sees and hears), and
      the hurt vignette is cleared with the run rather than riding onto the menu.

      Gated at the root: with two heroes on the field, an enemy beside the
      partner is offered the partner, one beside the local hero gets that one,
      and a downed hero is offered to nobody however close they are.

- [~] **The two-process harness now covers what play kept breaking (2026-08-25).**
      `tools/coop_ui.sh` tested plumbing — a handshake, a run starting, two heroes
      with velocity. Three rounds of play found bugs it passed, so it now asserts
      the behaviours those rounds broke, live, across two real processes:

      * the guest's own hero shows damage the **host** dealt it (health, which
        was never replicated at all)
      * loot dropped by the host appears on the guest
      * the host's wildlife appears on the guest, so a hunt can be shared

      **Why these are structurally invisible in-process**, and worth the extra
      machinery: one process has one `RunState` and one set of nodes, so a guest
      that computed the wrong answer locally computed the *same* wrong answer the
      host did. Only two processes can tell "the guest was told" from "the guest
      worked it out itself".

      A known limitation, found by the harness racing itself: a fact that arrives
      before the guest's battlefield exists is silently dropped. Everything that
      matters happens well after both fields are up, so it is recorded rather
      than buffered against.

      This is not a substitute for the row below. It cannot judge feel or latency
      and it only checks what somebody thought to assert.

- [ ] **Co-op played by two people on two machines.** Every co-op gate is a
      headless loopback in one process. That proves the transport, the
      authority model and the plumbing; it proves nothing about how co-op
      *feels*, and nothing about latency, which is the one thing the design
      knowingly defers (the guest's own hero visibly corrects).

      Worth doing **before** step 5 tunes difficulty, or the tuning is aimed
      at an experience nobody has had. Same class of row as "whether the
      sticks feel right under a thumb".

      **Step 5 — difficulty scaling, and the naive answer was wrong.** Body
      count is the only thing the player count touches; `balance_test` gates that
      health, damage and speed do *not* move, because scaling those adds duration
      rather than pressure and invalidates every dodge window.

      Measured rather than reasoned about, with `curve_report -- --players=2`:
      doubling the bodies made co-op **43% harder** at the peak (0.90 against a
      solo 0.63), not equal. The reason is worth keeping: the late game is
      *tower* dominated, so a second hero barely moves late capability — at zero
      extra bodies two players still measure 0.60. Bodies scale threat linearly
      while a second player scales capability much less than linearly, because
      the tower count is capped and upgrades escalate.

      Settled at 1.5x bodies for two players, measuring ~0.71. Deliberately above
      the solo curve: the model cannot see two lanes covered *at once*, which is
      the biggest thing a second player brings, and cannot see latency either.
      **Provisional until the two-machine play test.**

      **Step 6 — disconnects.** A guest dropping leaves the host playing on, and
      the rescale happens at the next wave with no code: `_wave_size` is only
      consulted when a wave begins, so a wave already walking is never resized
      under the survivor. A host dropping abandons the guest's run rather than
      recording a defeat — the player did not lose, the session went away, and
      writing a loss would put a phantom run on a leaderboard.

- [x] **Co-op hero XP: shared credit.** **DECIDED 2026-08-24 by the owner — "both
      players should share XP."** The row is ticked on that ruling; it had been
      left open because the answer was a design decision rather than a patch, and
      it was.

      The implementation turns on one distinction: **the award travels, never the
      total.** Hero level and XP persist per account (CLAUDE.md rule 7), so two
      players arrive with heroes at different levels. Relaying an absolute would
      overwrite a level-20 guest with a level-5 host's number and *demote* them —
      a shared pool would quietly delete somebody's progress. The host emits the
      amount before applying it locally, so both machines credit the same figure
      and each applies it to its own hero against its own curve.

      Still untested by two humans: the award crosses and lands correctly across
      two processes, but nobody has watched two heroes level together.

      Original entry, kept because the reasoning still stands: §54 reads "multiplayer, PvP, co-op, daily online
      challenges" as explicitly out of scope for 1.0, with only leaderboards
      carved back by the 2026-08-20 amendment. Restoring co-op is the same kind
      of decision as the two already recorded in CLAUDE.md §1 and deserves the
      same treatment: an owner ruling, dated, written into §54 and CLAUDE.md
      together.

      It is also the largest change anyone has proposed here, and it lands on
      three load-bearing working rules:

      - **Rule 6** - `RunState` is the single source of truth for the run. With
        two players there is a question rule 6 does not answer: whose machine
        owns it, and what the other one holds instead.
      - **Rule 5** - systems talk through `EventBus`. That is genuinely the
        right shape for a network boundary, so the seam already exists. But it
        has never been asked to carry authority, ordering or replay, and a
        signal that is fine locally is not automatically fine across a wire.
      - **Rule 8** - the battlefield freezes for a raid and resumes exactly. A
        pause one player triggers and both must observe identically is a harder
        version of a guarantee the game already makes.

      Determinism is the piece to settle first. Seeded reproduction exists and
      is gated (`seed_reproduction_check.tscn`), which is a real head start
      toward lockstep - but it was built to make a *replay* reproducible, not to
      hold two live machines in agreement, and the gap between those is most of
      the work.

      If this is a yes, the honest sequence is a design pass before any code:
      authority model, what a desync means, what happens when one player drops
      mid-raid, and whether it ships in 1.0 or as the thing after it.

- [~] **Three new player-power systems, checked against the curve (2026-08-25).**
      Companions, traps and barricades all landed in one stretch, so the curve
      was re-read afterwards rather than assumed. Peak pressure is **unchanged at
      0.63**, and the reason is worth writing down because it is not luck.

      `curve_report` models capability as hero DPS plus *every earned Gold spent
      on towers*. That makes it a best case, and it means **traps and barricades
      cannot inflate it**: they are alternative spends of the same wallet, so a
      player who buys a Spike Pit did not buy a tower. The model stays a valid
      upper bound without knowing they exist.

      **Companions are the exception and the model does understate them.** They
      cost a spell slot and a cooldown rather than Gold, so their damage is
      uncounted. A Wolf is 40 DPS at roughly 54% uptime — about 21 sustained,
      against a modelled capability of ~1078 at wave 51. Two percent, which is
      inside the noise of the model itself. Worth knowing, not worth a retune.

      If companions are ever buffed materially, or given more than one slot, that
      2% is where to look first.

- [ ] **Co-op difficulty scaling for two players.** Dependent on the above. The
      director's threat budget is already data-driven and tuned per act, so
      scaling *for* a second player is tuning - but scaling it *well* is a
      balance question that cannot be answered before the mode exists.

### Locked in §448 - needs a recorded re-cut

- [x] **Start with no gold; earn tower money by killing.** Done and gated on
      2026-08-25. `Balance.STARTING_GOLD` is 0.

      **Wood, Food and Stone were deliberately not zeroed, and that is an
      interpretation the owner should confirm.** No tower can be built
      without Gold - every `build_cost_table` entry carries a Gold price - so
      zero Gold already means zero towers, which is the whole of the intent.
      What the secondary wallets decide is *which element* the first
      affordable tower may be, since Fire is the only pure-Gold line.
      Emptying them would not make the opening harder; it would silently
      force every player onto Fire for act 1. Wood and Food also pay for town
      repair and hero tending, which are not tower capital.

      **The re-tune, measured rather than asserted.** The opening Gold ramp,
      best case, wave:total —

          1:5  2:38  3:85  4:137  5:183  6:224  7:247  8:277  9:312  10:344

      A tower costs 70 and four roads cost 280, so the first tower lands on
      **wave 3** - which is when the second road opens - and the four-road
      baseline on **wave 8**. The lane progression paces it without anything
      being tuned to match: the player fights alone through the two
      single-road teaching waves, then buys a road at roughly the rate roads
      arrive.

      **Nothing else needed changing**, which was the surprise. Starting Gold
      was only about 12% of a run's total Gold income, so peak pressure is
      unchanged at 0.63 on wave 51. What changed is the shape of act 1:
      pressure used to sit at 0.02-0.19 through the opening and now ramps
      0.06 → 0.48. The opening stopped being a formality.

      **`curve_report` had to learn about the hero.** It modelled towers as
      the only defence, which was a fair simplification while the run began
      with four of them. With none, the hero *is* the defence for the first
      waves, and a model scoring them as undefended divides by nothing and
      reports an infinite spike where the design intends its gentlest moment.
      Hero DPS is now read from the combo arrays as a single-target floor.

      **`balance_test` asserted the opposite** and now asserts the new
      contract: no starting capital, wave 1 alone must *not* pay for a tower
      (or fighting taught nothing), a first tower by wave 4, all four roads
      by wave 12. Three other harnesses quietly relied on the old cache and
      now fund themselves, so they measure their own subject instead of the
      re-cut.

      Original entry: the intent is good
      and clear: make the hero fight, rather than let the player subcontract the
      act to towers.

      §448's opening protection envelope locks the opposite in as many words -
      "Starting Gold and Stone can build one level-1 base tower on each road
      plus one meaningful upgrade or town choice" - and the whole protection
      taper through Wave 8 assumes those towers are up. `Balance.STARTING_GOLD`
      is 390 and `Balance.STARTING_RESOURCES` is 350, so the *change* is two
      constants. **The re-tune is not.** Waves 1-6, the opening supply pulses,
      the taper and the act multipliers were every one of them tuned against a
      player who starts with four towers.

      Worth ruling on the goal rather than the number. If the goal is "the hero
      has to matter", a reduced start plus a kill bounty may reach it without
      inverting a teaching ramp that currently works. If the goal is literally
      zero, that is a legitimate call - it just means re-tuning the opening
      envelope as a single unit, with `balance_test.tscn` and `curve_report`
      agreeing afterwards.

### Not in the GDD at all - new content, needs a design decision

- [x] **Barricade perimeter with broken entrances.** Built 2026-08-25. Two
      kinds: Stake Line (cheap wood, will not hold long) and Iron Hoarding
      (holds, and costs stone to say so).

      **The pathing objection is answered by not pathing.** There is no
      pathfinder here — enemies follow their lane's waypoints — so a wall that
      rerouted would mean writing one, and a pathfinder is a far larger thing
      than a wall. A barricade is therefore an *obstacle to break* rather than a
      maze piece, which needed no pathing change at all: enemy targeting is
      already field-mediated and striking already looks up `Health.of(target)`
      without caring what it found, so a barricade with a `Health` is simply
      another thing the field can offer. `Enemy` gained four lines and no new
      concept.

      **The broken entrances are the player's, not the map's.** Not a prefab ring
      with gaps designed in — barricades go up one tile at a time and the gaps
      are wherever the player did not spend, so the funnel is a decision somebody
      made rather than a shape they were handed.

      A barricade **slows what is pressed against it**, and that is what makes a
      partial line worth building rather than a speed bump with extra steps: the
      gap is faster than the wall, so the wall shapes where they go instead of
      only delaying them.

      The gate's load-bearing assertion is that the field *offers* the wall to an
      enemy behind it and does not offer it to one already past. If that offer
      stops being made nothing errors — enemies walk past the wall as though it
      were scenery, which reads as the wall being broken rather than the
      targeting. Health replicates as a fraction, so a guest rebuilds against its
      own `max_hp` and the two cannot drift if the resource is retuned.
- [x] **Trap placements.** Built 2026-08-25. Three kinds: Spike Pit (three
      bites), Tar Snare (holds a road still and hurts nothing), Firebloom (one
      burst, and everything on it burns).

      Three decisions, each pinned by the gate because none of them would
      announce itself by breaking.

      **Preparation-only, through the same single gate.** Laying a trap asks
      `RunState.can_build_now()` — the function every other build path asks — so
      §1's locked decision stays reversible in one line. A trap droppable
      mid-combat reopens that decision without erroring; it just quietly becomes
      a different game.

      **The placement rule is inverted.** A tower may not stand on a lane; a trap
      is worthless anywhere else. That is why it is its own resource and its own
      path rather than a `TowerData` with a flag — a flag would mean every caller
      of `placement_problem` had to remember which way round it was reading, and
      two opposite rules a few lines apart is how one gets written backwards.

      **They are consumed.** Triggers, then gone. That is what stops a lane being
      solved once and ceasing to be a lane, and it is why a trap can hit hard
      without being a cheaper tower that cannot be shot.

      Damage is deliberately unscaled by hero modifiers: a trap is the town's,
      not the hero's. Co-op replication came almost free on the same dividend
      towers gave — the battlefield rebuilds trap nodes from `RunState`, so a
      guest told what is laid where writes it and the node follows. Guest traps
      are puppets, or two machines would each spend the same trap's triggers
      against their own copies of the enemies.
- [x] **Summon companion — Wolf, Crow and Bear.** Built 2026-08-25 after the
      owner reaffirmed "continue with everything remaining" twice against a
      standing flag that this wanted a ruling. Three spells, three
      `CompanionData` resources, three sprites.

      **The §54 question is answered by the duration, and that is the whole
      design.** A second *permanent* body is the party roster wearing a different
      word. A summon that expires is a spell effect — Beast's Breath with legs —
      so companions have a duration, and a second cast replaces rather than
      stacks. Those two properties are what keep this inside the cut, so the gate
      asserts them directly: both would rot silently, since neither a duration
      that stopped applying nor a stacking second cast would error or look wrong
      in a screenshot.

      Kept small by the same decision. Companions have no health and nothing
      targets them, so the targeting, threat and death-payout systems never learn
      a new kind of thing exists — the difference between adding a spell and
      adding a unit. Damage goes through the ordinary `take_damage` with
      `active_hero` false: a companion's hit is the hero's damage at one remove,
      not the hero's swing, so finisher discipline nodes do not fire for it.

      Differentiated by role rather than by numbers. Wolf runs things down, Crow
      is fragile reach and the only flier, Bear is slow and throws what it
      reaches (210 knockback).

---

## 5. Done this far

Kept short deliberately — this is a working list, not a changelog. Git carries
the history.

- Launcher updates only when the launcher itself changed (verified against the
  published release, not just the code).
- Chill model for slows; hitstun gated so nothing can be stun-locked.
- Preparation countdown with the tiered early-departure reward.
- Endless after the summit, and its unlock.
- Boss health bar wired; Act III debrief no longer a dead end.
- Element rail in the build menu, with per-tower stat tooltips.
- First-run tutorial: side card, dismissible, per-save, togglable.
- Erase saved data, in Settings.
- Per-region roads and Wang ground floors for all three acts.
- Towers y-sort on their base anchor; shadows anchor to the sprite, not the node.
- Health bars draw above world content, so foliage cannot occlude a readout.
- Foliage sorting bands refined 16 → 32, keeping maximum depth error below one
  tile; each band is now one static mesh, cutting roughly 1,380 draw calls.
- Dash allowed in every phase the hero can move in.
- Tower range rings shown on selection (`Tower.show_range` had no caller at all).
- Beast scope reads as one world: pixel-art skies, ground lit from the horizon,
  and the parallax wrap no longer visible.
