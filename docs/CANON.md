# Wilderhold - the settled canon

> Drafted 2026-09-17 against every shipped player-facing string, then
> reviewed adversarially against GDD section 57, act integrity and the
> shipped lore. **Nothing here is built yet and several points need an
> owner ruling - they are listed at the end.**

---

# WILDERHOLD — The Settled Canon Spine

*Reconciled against every shipped player-facing string, verified by reading them
rather than by quoting them from a brief. Where a shipped line is load-bearing it
is quoted in full, because the previous pass of this document was built on a
truncated quotation and the truncation was the error.*

---

## 0. What this pass reversed, and why

The previous draft's central mechanism was **the last chain says *walk*, and
cutting it lets Yuri stop.** That is refused. Three shipped strings falsify it,
and the draft quoted the first of them with its second half cut off:

| Shipped string | What it says | What the draft claimed |
|---|---|---|
| `world_yuri.tres` — *"He does not hurry, and he does not stop **for anything short of the boss that stands at the end of each region — he will not leave a land with that thing still standing in it.**"* | Yuri stops. Ten times a campaign. By choice, out of something like principle. | *"he cannot [stop]"* |
| `story_act10.tres` — *"**Yuri stops here. This is where the walk was going.**"* | He stops at the Terrace, before any chain is cut, and the walk had a destination all along. | Stopping is the gift the finale gives him. |
| `world_worldstriders.tres` — *"**Yuri is walking to the top of the world**, and the town on his back is going with him."* | Yuri has intent and a destination of his own. | The chain supplies the going; it *"does not say where."* |

A canon that makes Yuri a compelled animal with no will also cuts against
`world_yuri.tres`'s *"patient past reason"* and against the whole reason the
Warden/Yuri bond is worth having. **Yuri is not compelled. Yuri chose.**

The shipped strings say plainly what the chain in him actually is, and it is not
an instruction:

- `enemies/chainmaker.tres` — *"the chains he made are the only thing still
  **holding** Yuri."* **Holding**, not driving.
- `cinematics/chainmaker.tres` — *"Break him, and Yuri **walks free**."* Free
  **of a holder**.
- `world_summit.tres` — lighting the beacon means *"the Worldstriders that are
  left **stop being hunted**."*

So the chain on Yuri is **the catch** — Kharok's hold on him, the thing by which
a Worldstrider is taken, ridden and put into the ground. Yuri walks the whole
road with it in him, dragging the Host behind it. Cutting it does not give him a
will. **It means nothing can take the one he has.**

Six further corrections are made below and marked **[CORRECTED]**. One of them
was a phrase the release gate would have refused outright.

---

## 1. A chain is not a bond

**A chain is an instruction put into a living thing from outside, which it
cannot refuse. It has an anchor somewhere else.** Every chain in this world has
one: something holding the far end. That is the shape of the whole game — the
tutorial's anchor is a stake in the dirt you can cut, and the last one is a man
at the top of the world you cannot.

**A bond is two who could leave and do not.** It has no anchor. Nothing holds it
but the fact of it continuing.

The test is: *take it away and see what happens.* Cut a chain and the thing stops
being held. There is nothing to cut on a bond — you can only walk away, and then
you find out what it was.

So **the chain on Yuri and the bond between Yuri and the Warden are opposites**,
and one is what is left standing when the other is gone. The Warden cuts a chain
in the tutorial and the bond is what is standing in the gap. Yuri is not grateful
and is not obedient. He simply does not shake them off, and never has since.

### Two chains, and two different freedoms

Shipped fiction says the chains are plural — *"the chain**s** he made"*,
*"the last chain binding Yuri"* — so this needs no new licence.

- **The stake.** Iron, local, driven into the ground at the Hold, the far end of
  a chain run into his flank. It holds him **in place**. The Warden cuts it in the
  tutorial and Yuri **goes**.
- **The last chain.** Not local. Its anchor is at the Crown of the World, in
  Kharok's keeping, and it is the same chain he put into every Worldstrider he
  ever took. It does not tell Yuri anything. It is the **hold** — the handle by
  which he can be found, followed, run down and ridden into the earth as the
  others were. It is why the Host comes up the four roads and not up anybody
  else's. Cut it and **nothing is coming for him any more**.

Cutting the stake frees Yuri to **go**. Cutting the last chain frees him to
**stay standing**. Those are different gifts and the second one is the ending.

This promotes three shipped lines from colour to load-bearing without
contradicting any of them:

- *"The others were caught, chained and ridden into the earth... or simply lay
  down somewhere far from any road and were forgotten. **Yuri has not lain
  down.**"* — the two ways a Worldstrider ends. Taken, or gave up. Yuri has done
  neither, and the whole campaign is him continuing not to.
- *"Moss grows on him; whole gardens have."* — he stood still a very long time
  before the road began. That is the tutorial, already written.
- *"The last chain gives. **Yuri stands**, and the mountain is quiet for the
  first time in a long age."* (`ending_screen.gd`) — **"stands" answers "ridden
  into the earth" and "lay down".** Every other Worldstrider went down. Yuri is
  on his feet at the top of the world and now gets to stay that way. The
  mountain is quiet because the hunt has stopped. That is the payoff and it is
  already written.

**[CORRECTED] Rule for writers — the previous version of this rule would have
failed the release gate.** It recommended *"prefer... held by / **in chains** /
the chain in him"*. `tools/copy_check.gd` line 33 lists **`"in chains"` in
`FORBIDDEN`**, and that gate runs on both the guard and release bars. Any writer
following the old rule would have written a string that cannot ship.

The word *bound* ships in three senses — bound to a person (bond), bound by a
chain (compulsion), duty-bound (*"the one defender bound to hold them"*,
`story_intro.gd`). Disambiguate by context: **if the sentence contains the word
"chain", "bound" means the chain; otherwise it means the bond.** Prefer *bound
to* for the bond, and *held by* / *the chain in him* / *the chain he is on* for
the chain. **Never write "in chains", "shackle", "thrall" or "captive"** — all
four are in the gate's denylist. Never write "Yuri's bond to Kharok" or "the
Warden's chain".

---

## 2. Roadsong, and what a chain is made of

The world runs on one force under four faces: **fire, water, earth and air**.
**[CORRECTED]** — the previous draft wrote *"fire, water, **stone and wind**"*.
Earth and Air are the shipped element names; **Stone is a run currency**, and
using it for an element collides with a wallet the player reads on the HUD.

The old word for the force is **Roadsong**. It is the same thing the ground does
when it is angry and the same thing a tower borrows when it fires. It moves.
That is its whole nature. *(New coinage — see risks.)*

**Chain-magic is Roadsong held still.** A held note, run into a living thing,
which keeps saying itself. That is why shipped fiction can say *"his chain-magic
runs down the world like veins"* (`world_host.tres`) — it is not a leash anybody
holds, it is a sentence the world keeps repeating, spreading along the grain of a
thing that was never meant to stand still.

Two consequences worth having:

- **It surfaces.** Where a vein runs near the surface you can stand on it. Those
  three places are §4's trials.
- **It leaves metal.** **[CORRECTED]** — the previous draft said the Rustwood's
  iron came *"up through the roots of trees that drank it"*. `story_act05.tres`
  says the opposite direction: *"The iron went in through the **wounds of the
  trees** and kept going, and the Rustmother let it in through hers."* The vein
  surfaces in the Rustwood; what gets into a tree gets in the way the shipped
  line already says it does. Do not specify roots.

And it gives the beacon a mechanism rather than a miracle — see §6.

---

## 3. Kharok the Chainmaker

**He was a Warden, and one of the greatest.** That is the origin the game has
never had; it ships his name, a summit, and no past at all.

**What he was trying to fix.** A Worldstrider walks where it likes. The people on
its back go where it goes and — *"the first people who climbed them never climbed
down"* — get no say in it. Most of the time that is fine. Sometimes the beast
walks into a desert, or into the sea, or lies down in a place with nothing in it
and does not get up again, and everyone living on its back finds out what it
decided. **Kharok's beast lay down.** He was there for it, he did not die of it,
and that is the entire reason for everything he has done since.

**What he made.** A way to hold Roadsong still long enough to steer a
Worldstrider. Not to own one — to **steer** one. He would have said, and would
still say, that it was the first time in the world's history that anyone riding a
beast had a say in where they woke up. He was celebrated for it. People brought
him their beasts.

**What it cost, and why that is not cruelty.** The chain works. The beasts he
chained went where they were told, and kept going, and were ridden into the earth
— because he had written an instruction and forgotten to write an ending. He
learned it too late to matter and too late to stop: the held note had already
found the grain of the world and started running on its own. It touches clans and
they march.

**He is the anchor, not the officer.** Read the shipped *"every clan the
Chainmaker holds"* as **anchors**, never as **orders**. The chain marches them;
he is where the far end of it is tied.

**[CORRECTED] — this has to be reconciled with two shipped strings the previous
draft did not weigh.** `story_intro.gd` panel 2 says **"A warlord holds the
summit"**, and `enemies/chainmaker.tres` says **"He commands every road at
once."** A warlord who commands is a commander, and the previous draft asserted
*"he has no court and no staff"* while those two lines were on screen. The
reconciliation that costs nothing: **he commands the way a river commands a
valley.** Every road answers to him because every road's chain is tied to him;
what arrives is not an order carried by anybody. He gives no instruction because
the only instruction he ever wrote is still running and cannot be added to. If
the owner wants the literal reading, §3 changes and the Host's framing goes with
it — see risks.

**The first chain ever made is the one in Kharok.** He put it in himself, to try
it, because he was not the sort of man who would test it on something else first.
The sentence a grieving man writes: ***hold the top of the world, and let nothing
past until what is below is safe.*** He meant it as a guard on the door while he
worked out how to undo what he had started. It is a condition that can never be
met. It has been running in him ever since.

That single decision answers everything:

- **Why he holds the summit.** He cannot leave it.
- **Why he has never lit the beacon.** *Let nothing past* includes his own hand.
  The chain will not let him end the chain. He has stood next to the answer for a
  very long time and cannot reach it.
- **Why he never came back down.** He said he would. He could not.
- **Why he will kill the Warden at the gate.** Because he wrote that sentence
  when he was young and certain, and has been serving it since with perfect
  knowledge of what it is doing.

**He is the most chainbound thing in the game, and he made the chain.** He is not
evil; he is `world_host.tres`'s thesis — *"They are not evil. They are
compelled."* — taken all the way down. Act 10 is a fight against a man who would
very much like to lose and cannot arrange it.

**Forbidden register, permanently.** Kharok has no workers, servants, labourers,
subjects or property. Nobody maintains anything for him. Nobody belongs to him.
He is alone at the top of the world with a lamp he cannot light and a friend
below him he cannot relieve. If a sentence about Kharok could have the word
"master" put in it and still make sense, it is the wrong sentence.

---

## 4. The Gatekeeper

Shipped, and kept: *"set there and told to wait, and it has waited a very long
time"*; *"Nobody came back to relieve it. It has held this stair through every
war that walked up it, and yours is not the first."*

**It was Kharok's closest companion** — the one who followed him up when he went
to fix it. At the last step Kharok said *wait here*. And because Kharok was by
then himself a chain, a thing he said went in as one, and neither of them
understood that until it was done. **Kharok did not decide to chain his friend.**
He said two words to somebody he loved and they became law in him. That is the
most frightening property chain-magic has, and it is the only thing in the canon
that makes Kharok's guilt personal rather than statistical.

The Gatekeeper is not Kharok's servant, agent or man. It is the **first and
longest-held of the chainbound**, standing at a door, waiting for somebody
directly above it who has not come down.

**Why it offers trials, in its own words.** Its order is to hold the last step
and let nothing past that is not ready. It has held that stair through every war
that walked up it, it has destroyed every one of them, and it did not want to.
The chain says *hold the step*. **It does not say the testing has to happen at
the step.** So the trials are the only agency it has — its voice reaching further
down the road than its feet are allowed to go. From its side they mean: *do not
come up here unready. I would rather refuse you at a door than kill you at the
gate.*

That is not generosity. It is a thing that has killed a great many people looking
for any legal way to kill fewer.

**Where the trials are — and each site is already half-written.** Where the vein
running to the Crown breaks ground: the three places on the road you can stand
*on* the chain.

- **Act 3, The White Teeth.** It runs under the ice. `region_snow.tres` already
  has the clan running *"sleds chained to hauler beasts"* — Act 3 is the road's
  first region where chain is a literal object.
- **Act 5, Rustwood.** It has been surfacing into living wood for an age.
  `story_act05.tres` is already a region about iron getting into things.
- **Act 7, Iron Steppe.** `region_iron_steppe.tres`: *"Open grass, **iron
  stones**, and horses that were never chained."* The seam is the iron stones,
  lying in open grass with nothing to hide it — and the region's own shipped
  boast is that its horses were never taken. Standing on the vein there is the
  sharpest the image gets.

**Why the Gatekeeper is met on Act 9, not at its post.** The chain measures its
leash in *time to return*. It may stand exactly one region from the stair and no
further — and the Ashen Reach is that region. So when the third door opens and
something is coming that will not simply die, it comes down as far as it is
allowed and waits on the last ground before the Terrace. This is the one fight in
the game where the Gatekeeper is not standing in a doorway. `story_act09.tres`
calls the Reach a place that *"burns without ever having burned down"* where the
boss *"has no body under the fire; the fire is the shape he has instead"* — it is
the right ground to meet something that is the shape its order left behind.

**Why beating it there removes it from that difficulty's summit.** Its order was
*let nothing past that is not ready*. It has now tested you personally and failed
to stop you. The chain has no further test to make of you on that road, and it
stands aside — not out of mercy, but because a compulsion is a sentence with a
condition and the condition is spent. Walk a different road (Nightmare, Hell) and
it has not tested you on **that** road, and it will be at the gate beside Kharok.

### **[CORRECTED]** The pronoun reveal lands inside the fight, because it has to

The previous draft proposed keeping all six shipped *"it"* strings verbatim and
gating the reveal behind the ladder, so that a player who skips the ladder never
learns there is a person in there. **That is not available, and it was not a good
trade anyway.** Two of the six are `enemies/gatekeeper.tres`'s
`phase_names = ["It Raises the Chain", "It Sets Down the Chain"]` — **banners
that fire during the Gatekeeper fight itself**, which under this plan *is* the
Act 9 reveal. The old proposal had the road still saying *"it"* on screen in the
middle of the scene where the player learns otherwise.

So the fight **is** the reveal, delivered where a player is guaranteed to be
looking, at a cost of one word:

- Phase 1 banner stays **"It Raises the Chain"**.
- Phase 2 banner becomes **"He Sets Down the Chain"**.

Everything before that fight keeps *"it"* and is correct: nobody has seen under
the helm, and the road says *"it"* because the road does not know. Everything
after it says *"he"*. A player who never takes the ladder never opens the helm
and every string they read is true for them. A player who does gets the best beat
in the canon in the one place it can land, and — having beaten him — never sees
those Act 10 banners again, because he is no longer at the summit.

One shipped string changes, by one word, and it is the string the reveal happens
on.

---

## 5. Ascension: what the trials measure

The trials are not a teacher handing out power. They are three places where the
chain comes to the surface, and what they measure is **how much of it a person
can stand in without marching.**

That is why it empowers, why it is capped, and why it is tuned against the harder
roads: the deeper the road, the thicker the vein, and there is a hard limit to
how much held Roadsong a person can carry and still be a person rather than
another thing the chain is saying. A Warden who has walked all three doors and
beaten the thing at the end of them can stand closer to the veins than anybody
alive. Nightmare and Hell run the ladder again because they are thicker ground,
and each pass opens rungs the last one could not reach.

**It never makes the Warden a saviour or a chosen one** (hard constraint 4). It
makes them *tolerant*. Nobody prophesied it; they kept standing on the thing
until it stopped taking.

**[CORRECTED] — this section answers the fiction and the previous draft dodged
the mechanics the brief asked for.** The brief specifies a **tree** that Nightmare
and Hell each *extend*, and an effect that "empowers significantly" and makes
Nightmare tractable after grinding its gear. The previous draft gave no tree, no
rung count and no bound. What this canon licenses, for whoever designs it:

- **A rung is tolerance, never magnitude granted from nowhere.** The fictional
  unit is *how close to a vein you can stand*, so the shape that fits is
  **resistance and uptime** — surviving hazards, statuses and chain-pressure —
  rather than a third damage multiplier stacked on levelling and gear.
- **The cap is fictional as well as numeric.** There is a point past which a
  person becomes another thing the chain is saying. That is why `ASCENSION_MAX`
  exists and why it can rise with difficulty without becoming open-ended.

The numbers, the rung count and whether this is a power scale at all are an owner
ruling and a working-rule-7 amendment — see risks, including a name collision
already in the code.

---

## 6. The Crown of the World: sanctuary and beacon are one place under two names

**"Sanctuary" is what it is called from below.** It is what the Hold needs it to
be: somewhere to *get to*, somewhere the chain has not reached, with a door you
can close. That is what the Warden sets out for — not to save the world, but to
get away to somewhere safe with a stolen beast and as many of their people as will
climb. The owner's brief says it exactly: *a sanctuary they do not know exactly
where it is and must navigate through the world to reach.*

**And the word is already shipped, already meaning this place.**
`data/objectives/crown_unchained.tres` reads: *"Defeat the Chainmaker and reach
**the sanctuary**."* The reconciliation below is not a retcon; half of it is on
disk already and nobody had noticed the two names were for one place.

**"The beacon" is what it turns out to be.** There is no door up there and
nothing to shelter behind. There is a lamp older than Kharok, and what it does
when it is lit is let Roadsong move again — every held note in the world released
at once. Every clan the chain touches goes free in the same moment. The
Worldstriders that are left stop being hunted, Yuri among them.
`story_act10.tres`: *"past the beacon is a world with no chain in it."*

So the Warden climbs the whole world looking for a place to hide and finds a
thing to light. **Sanctuary is not somewhere you go. It is a condition of the
world, and you have to make it.** After that there is nothing to take shelter
from — which is why the Hold can stop being the last one.

This changes no shipped string. `world_summit.tres` already says the beacon
breaks the chain and frees every clan at once; it simply never said what the
people at the bottom of the mountain call it while they are still hoping.

**Who guards it** — already shipped, and matching the owner's *"guarded by the
gatekeeper and the chain bound host"*: Kharok holds the summit; the Gate of the
Crown holds the last step; the remnants of every host converge on the final
ascent.

---

## 7. The Hold, and the last hold

**They are one place**, and the name is a shortening. People who live in the only
one left do not say the whole thing. `world_the_hold.tres` already calls it
*"somewhere that does not move."*

**[CORRECTED] — the previous draft's naming rule expires halfway through its own
tutorial.** It proposed writing *"the last hold the chain has not reached"*, then
in §8 had the chain arrive there. A player who reads that string on the
between-run screen after the tutorial reads something the game has already shown
them is false.

**The name is earned rather than descriptive: the Hold is what held.** The chain
came and it did not take. That survives the tutorial, survives the campaign, and
says the one thing the owner's *"last human hold"* was reaching for without
raising a species question.

**Drop "human" from player-facing strings.** It implies the Chainbound clans are
not human, which cuts directly against *"each was a people once, and each is
still, somewhere under the chain."* The operative word is *free*, not *human*.

Three reasons this is worth having rather than an echo or a rename:

- **It is where the Warden is from.** The tutorial is not a training ground
  somewhere else; it is home, and the beast standing over the fields is the one
  they grew up beside.
- **It makes the between-run screen carry weight.** You come back to the people
  you took the wall from. Your stash, Chronicle, Codex and the Long Ledger all
  live with them.
- **It explains the Ledger.** *"What one Warden sold to what another will buy"* —
  every Warden comes from here, because there is nowhere else left to come from.
  Two Wardens in co-op are two of the Hold's own.

**The Hold's people farm because they eat.** Nobody is set to work there and
nobody oversees anybody. The Warden works the same plots as everyone else and
leaves when they choose to; that is the only register in which a farming
settlement can be written under §57 (see §10).

**How a Warden gets between the road and the Hold is already answered by the
code** and needs no new fiction: a run ends in exactly three ways and each is a
way home. **Turn for home** — the beast turns back and the front is banked where
it stands. **A fall** — you are carried home, and what was banked is still
banked. **The summit** — the road ends. Nothing else should try to explain it.

---

## 8. The tutorial: the theft

The Warden is one of the Hold's people. Not chosen, not warned, not prophesied.
They work the plots, fish the pond, take wood and ore out of the treeline, put an
arrow into something that came out of it, and learn what a road is for — all of it
in a narrow valley with the whole system laid out in the order a person would
actually meet it, and starting gear earned rather than granted.

**Standing over the fields is a Worldstrider on a chain staked into the ground.**
**[CORRECTED] — he is standing, not lying down**, and that correction is both
canon and scope.

- **Canon.** *"Yuri has not lain down"* is a shipped sentence. A tutorial that
  opens on a prone Yuri makes a player read it as false an hour later. The stake
  pins the chain, not the beast: he stands where he is and cannot leave.
- **It is already written.** *"Moss grows on him; whole gardens have"* is shipped
  and is the description of something that has stood in one place a very long
  time. The owner's phrase is *"hijack Yuri from its rest"* — a standing rest.
- **Scope.** A standing Yuri is the sprite the game already ships, plus a chain
  and a stake as props. A lying-down Worldstrider is a new pose, and this
  project's own record says an animator cannot re-pose a standing frame into a
  new posture — it produces the same stance, waving.

That is why the Hold has lasted: **the beast is the wall.** Nothing that marches
will come near a Worldstrider. The Hold grew up against his flank and has lived a
long time believing the stake keeps him safely where he is, and they are not
wrong about what it does.

Then the chain comes. It always comes — *"his chain-magic drives the clans after
us"* is already shipped in panel 2 of the intro — and a beast that cannot move is
a wall exactly once.

**The Warden cuts the chain at the stake.** The owner's word is *hijack* and it
should sting: this is a theft from your own people, it is the right call, and it
is still a theft. Yuri goes. The bond is what is standing in the gap where the
stake was. As many of the Hold as will climb, climb, and the town on his back is
the piece of the Hold that went.

**And the hijack runs the other way, which is the beat worth building.** The
Warden cuts a beast loose to flee to a sanctuary they cannot find. Yuri walks to
the top of the world — because *"Yuri is walking to the top of the world"* and
*"This is where the walk was going"* are both shipped, and because he has had
somewhere to be for longer than the Hold has existed. The Warden thinks they are
steering. They are being carried. By the time they work out that the beast has a
destination, the road behind them is full of the Host, and the destination turns
out to be the only place the sanctuary could ever have been.

That also explains the shipped imperative *"Walk him there"* (intro panel 4)
without making the player a driver: holding four roads is how a beast that size
gets anywhere at all, and it is the only part of the journey the Warden actually
supplies.

**The Warden does not begin the game as a hero.** They begin having done
something irreversible out of necessity, and the whole campaign is them walking
it out. It is also, exactly, the small version of the ending: one person with a
blade cutting one animal loose, then spending ten acts trying to do it for
everybody at once.

**Co-op opens after the first real run**, not after the tutorial: a second Warden
is somebody else from the Hold who saw what you did and came up the road after
you.

---

## 9. The finale, and the exact strings it costs

No region is added, removed, renumbered or renamed. The ten acts and the Final
Ascent (`FINAL_ASCENT_ACT = ACT_COUNT + 1`) stay exactly where they are.

1. **Act 10 — the Gate of the Crown. Kharok.** The stair, and the man who holds
   the summit standing at the door to it, because the door is the only thing his
   own sentence lets him do. If the Gatekeeper has not been beaten on this
   difficulty, it is standing there too, and neither of them wants to be. Kharok
   beaten does not light the beacon — *let nothing past* includes his hand. He
   stands aside. That is all he has ever been able to offer.
2. **The Final Ascent — the last chain.** Exactly what v4 §201 already specifies:
   multi-road defence alternating with direct pressure on the chains binding
   Yuri, with what is left of every host converging on it. The anchor is here.
3. **The beacon.** The Warden lights it. Every held note in the world comes loose
   at once — the Host, the Worldstriders, the Gatekeeper, and far too late the man
   who wrote the first one into himself. *"The last chain gives. Yuri stands, and
   the mountain is quiet for the first time in a long age."*

He stands. Nothing is coming for him. For the first time in an age, that is
somebody's doing.

### **[CORRECTED]** The reassignment falsifies two shipped strings. The previous draft did not name them.

Moving Kharok from act 11 to act 10 is not free, and the previous draft listed
only the mechanical problem. These are the concrete edits, and each is a string a
player reads:

| File | Today | Why it breaks | Proposed |
|---|---|---|---|
| `cinematics/summit.tres` | *"Above waits the beacon, **the Chainmaker**, and the last chain binding Yuri."* `trigger_id = "gatekeeper"` | Kharok is no longer above; he has just fallen at the gate. And its trigger is the Gatekeeper, who has moved to Act 9. | Re-point `trigger_id` to `"chainmaker"`; description becomes *"Ten war hosts lie behind you. Above waits the beacon, and the last chain binding Yuri."* Eyebrow *"Final Ascent · One road remains"* stays correct. |
| `cinematics/chainmaker.tres` | *"Break him, and **Yuri walks free**."* `act = 11`, eyebrow *"True Final Boss"* | Breaking him no longer frees Yuri — the chain is cut one scope later. | `act = 10`, eyebrow *"Act X Boss · The last door"*; *"The one who bound the beast holds the last door. Break him, and the way up is open."* |
| `cinematics/gatekeeper.tres` | `act = 10`, eyebrow *"Act X Boss"* | It is the Act 9 trial now, and a conditional presence at Act 10. | `act = 9`, eyebrow *"The last trial · Set at the last step and told to wait"*. A second, conditional Act 10 appearance is new content. |
| `enemies/gatekeeper.tres` | `phase_names = ["It Raises the Chain", "It Sets Down the Chain"]` | The reveal happens in this fight. | Second banner → *"He Sets Down the Chain"*. |
| `enemies/chainmaker.tres` | *"He **commands** every road at once"*; `phase_names` includes *"The Iron Levy"* | Both read as a command structure, which §3 refuses. | Keep if the owner takes the anchor reading and the register note in §10 is applied; otherwise §3 changes. Owner ruling. |

And one structural consequence the previous draft left implicit:
`run.gd:_on_boss_defeated` sends `act >= ACT_COUNT` into `_begin_final_ascent()`
and `act >= FINAL_ASCENT_ACT` into `_summit_cleared()`. **With Kharok at Act 10,
the Final Ascent has no boss body to call `_summit_cleared()`**, and v4 §201's
"pressure on the chains" is an object, not a creature. That is either a new
asset or a different reading of the brief — see risks.

---

## 10. The register, for anyone writing a string in this world

- **The Host is compelled by magic. Never owned, never worked, never kept.** No
  labour force, no work gang, no servants, no overseers, nobody who "belongs to"
  anyone. A leader you bring down is **sworn, ransomed or memorialised, never
  owned.** If a sentence would survive having the word *master* put in it,
  rewrite the sentence.
- **`copy_check` will refuse these outright**, so do not write them even as
  colour: *slave, enslav-, captive, prisoner, bondage, chattel, thrall, shackle,
  put to work, work detail, forced labour, forced labor, owned by, property of,
  **in chains***. **This document is not player-facing. Never paste this list, or
  §3's, into a `.tres`.**
- **The gate catches vocabulary and cannot catch euphemism.** The forwarded story
  document was refused on one sentence — Kharok *"compelled workers to maintain
  the anchors"* — which passes every word check and is forced labour. A person has
  to read every new Kharok, Gatekeeper and Hold string.
- **A levy, a muster and a host are what the chain does, not what Kharok
  orders.** If *"The Iron Levy"* survives as a phase name, it is the chain
  levying — write nothing that puts a man behind it giving the order.
- **The Gatekeeper is not Kharok's man.** It is chainbound, like the clans, and it
  is the oldest case of it. *"An order chained into him"* is compulsion. *"His
  duty to his lord"* is servitude and does not ship.
- **No dates, no calendar, no industry.** Relative phrases only: *old past
  counting*, *a long age*, *before the roads*, *longer than the Warden has been
  alive*. Yuri has no build date and never will.
- **The Warden is not prophesied.** Nobody was waiting for them. They are a thief
  from a farm who kept going.
- **The chain is the enemy. The people on it are what the chain has done.**

---

## 11. What this costs, stated plainly

**Most of it is words in existing `.tres` fields.** The spine renames nothing,
renumbers nothing, and leaves every act title, region, boss name and banked
expedition where it is. Five shipped strings change and they are enumerated in
§9 rather than waved at.

Genuinely new, and belonging to somebody else's pass:

- **The tutorial map and its narration.** A narrow guided valley is a new
  `BattleGrid` template — the field is a 45×45 authored core inside a 75×75 with
  outskirts, and a corridor is not that shape. The narration is
  `TutorialStepData` with new triggers, appended to the enum and never inserted.
  The **art is nearly free** because of §8's standing-Yuri correction: the beast
  sprite ships, and the new pieces are a chain and a stake prop.
- **The ladder's four encounters.** Three trial arenas and the Act 9 fight.
  `RiftArena extends RaidArena` is the existing seam — a trial is an arena
  entered from the road, which the rift gates already do — so this is content and
  gating rather than a new scope.
- **The per-difficulty Gatekeeper state and the Act 10 conditional presence.**
  State, not prose.
- **The Act 10 / Final Ascent reassignment**, including whatever stands at the
  Final Ascent once Kharok is at the gate.
- **The ascension tree**, which is unspecified above deliberately and is an owner
  ruling first.

The risks list names what each of those disturbs, as questions.

---

## Decisions taken in this draft

- REVERSED the previous draft's central mechanism. 'The last chain says WALK and cutting it lets Yuri stop' is refused: it is falsified by world_yuri.tres ('he does not stop for anything short of the boss that stands at the end of each region - he will not leave a land with that thing still standing in it' - the draft quoted this sentence with its second half cut off), by story_act10.tres ('Yuri stops here. This is where the walk was going') and by world_worldstriders.tres ('Yuri is walking to the top of the world'). Yuri stops ten times a campaign, by choice, and has his own destination.
- REPLACEMENT, read off the shipped strings rather than invented: the last chain is Kharok's HOLD on Yuri - the catch by which a Worldstrider is taken, followed and ridden into the earth. Licensed verbatim by 'the chains he made are the only thing still HOLDING Yuri' (enemies/chainmaker.tres), 'Break him, and Yuri WALKS FREE' (cinematics/chainmaker.tres) and 'the Worldstriders that are left stop being HUNTED' (world_summit.tres). Cutting it does not give Yuri a will; it means nothing can take the one he has.
- Two chains, two freedoms, neither touching Yuri's agency: the STAKE at the Hold (iron, local, pins the chain to the ground) holds him IN PLACE - cut in the tutorial, he GOES. The LAST CHAIN (anchored at the Crown) is the hold - cut at the finale, he STAYS STANDING. Structural rhyme: every chain has an anchor; the first is a stake you can cut, the last is a man you cannot.
- 'Yuri stands' in the shipped ending means he did not go DOWN - it answers 'ridden into the earth' and 'lay down somewhere and were forgotten'. Not 'he stops'. Every other Worldstrider went down; Yuri is on his feet at the top of the world and now gets to stay that way, and 'the mountain is quiet' is the hunt stopping.
- CORRECTED a writers' rule that would have failed the release gate. The previous draft recommended writing 'in chains' for the compulsion sense. tools/copy_check.gd line 33 lists "in chains" in FORBIDDEN, and that gate runs on both the guard and release bars.
- CORRECTED the elements: fire, water, EARTH and AIR. The draft wrote 'stone and wind'; Earth and Air are the shipped element names and Stone is a run currency the player reads on the HUD.
- CORRECTED the Rustwood iron's direction. story_act05.tres says 'The iron went in through the WOUNDS of the trees'; the draft said up through the roots. The vein surfaces there; do not specify roots.
- CORRECTED the tutorial's staging: Yuri is STANDING, held by a chain staked into the ground, not lying down. Canon ('Yuri has not lain down' is shipped and a prone tutorial Yuri makes it read false an hour later; 'Moss grows on him; whole gardens have' already describes a very long stillness; the owner's word is 'rest'). Scope: a standing Yuri is the shipped sprite plus two props, where a lying Worldstrider is a new pose this project's own record says an animator cannot produce from a standing frame.
- CORRECTED the pronoun plan. Keeping all six 'it' strings verbatim was not available: two of them are enemies/gatekeeper.tres's phase banners, which fire DURING the Act 9 fight that is supposed to be the reveal. The fight is now the reveal - banner 1 stays 'It Raises the Chain', banner 2 becomes 'He Sets Down the Chain'. One word, in the one place a player is guaranteed to be looking, and the beat is no longer hidden from most players.
- CORRECTED the Hold's naming rule. 'The last hold the chain has not reached' expires inside the draft's own tutorial, where the chain reaches it. The name is earned instead: the Hold is what HELD. That survives the tutorial and the campaign. 'Human' still dropped, for the reason the draft gave.
- NAMED the two shipped strings the draft's not-a-commander reading contradicts and did not weigh: story_intro.gd panel 2 'A WARLORD holds the summit' and enemies/chainmaker.tres 'He COMMANDS every road at once'. Reconciled as 'he commands the way a river commands a valley' - every road answers to him because every road's chain is tied to him - and escalated to the owner if the literal reading is wanted.
- ENUMERATED the five shipped string edits the Act 10 boss reassignment actually costs, which the draft left as a mechanical footnote. Two of them become FALSE: cinematics/summit.tres ('Above waits the beacon, THE CHAINMAKER, and the last chain') and cinematics/chainmaker.tres ('Break him, and YURI WALKS FREE'). Proposed replacements and a trigger re-point are in the table in section 9.
- STRENGTHENED section 6 with a shipped string the draft missed: data/objectives/crown_unchained.tres already reads 'Defeat the Chainmaker and reach THE SANCTUARY'. The sanctuary/beacon reconciliation is half on disk already; it is not a retcon.
- KEPT and sharpened: Kharok was a Warden and one of the greatest, whose own beast lay down; he built the chain to STEER, not to own, and was celebrated for it; his crime is an engineering mistake made out of grief - an instruction written with no ending. He anchors, he does not officer.
- KEPT: the first chain ever made is the one in Kharok, put there by himself as a test, saying 'hold the top of the world, and let nothing past until what is below is safe' - a condition that can never be met. It answers in one stroke why he holds the summit, why he never lit the beacon, why he never came down, and why he fights while wanting to lose.
- KEPT: the Gatekeeper was Kharok's closest companion; 'wait here' said by a man who was himself a chain became law in him. The trials are its own agency - its order says hold the step, not that the testing must happen at the step - and beating it on Act 9 spends the condition for that road, which derives the owner's per-difficulty mechanic from fiction rather than bolting it on.
- SITED the trials on evidence: Act 3 (region_snow.tres already has 'sleds chained to hauler beasts'), Act 5 (story_act05.tres is already about iron getting into living wood), Act 7 (region_iron_steppe.tres already says 'Open grass, IRON STONES, and horses that were never chained').
- ANSWERED the ascension-tree half of the brief that the draft dodged entirely: the fictional unit is tolerance, so the shape that fits is resistance and uptime rather than a third damage multiplier, and the cap is fictional as well as numeric - past a point a person becomes another thing the chain is saying. Numbers and rung counts are escalated, not assumed.
- INVERTED the hijack, which is the beat the correction buys: the Warden cuts a beast loose to flee to a sanctuary they cannot find, and Yuri walks to the top of the world because he has had somewhere to be for longer than the Hold has existed. The Warden thinks they are steering and is being carried. This also explains the shipped imperative 'Walk him there' without making the player a driver.
- CUT the draft's self-congratulation ('that is the neatest thing in this document') and its references to unstated lettered questions, so the spine reads as canon rather than as a pitch about itself.

## Open - these need the owner

1. SHIPPED-STRING CONTRADICTION, NOT YET RESOLVED BY ME: story_intro.gd panel 2 says 'A WARLORD holds the summit' and enemies/chainmaker.tres says 'He COMMANDS every road at once'. Section 3 needs Kharok to be an anchor rather than an officer, or 'They are not evil. They are compelled.' loses its floor and the Host's whole Oathbound framing (a GDD section 57 release requirement) needs revisiting. QUESTION: do you take the anchor reading - he commands the way a river commands a valley, no orders and nobody carrying them - and keep both strings; or is Kharok literally a warlord with a command structure, in which case section 3 is rewritten and the Host framing is reopened?
2. ACT 10 / ACT 11 REASSIGNMENT FALSIFIES TWO SHIPPED STRINGS AND LEAVES THE FINAL ASCENT WITHOUT A BODY. Today cinematics/gatekeeper.tres is act=10 and cinematics/chainmaker.tres is act=11, and run.gd routes 'act >= ACT_COUNT' into _begin_final_ascent() and 'act >= FINAL_ASCENT_ACT' into _summit_cleared(). With Kharok at Act 10, cinematics/summit.tres ('Above waits the beacon, THE CHAINMAKER, and the last chain') and cinematics/chainmaker.tres ('Break him, and YURI WALKS FREE') both become false, and nothing is left to call _summit_cleared(). QUESTION: do you approve the five string edits tabled in section 9, and does the Final Ascent get a new boss-shaped anchor object (new art, new enemy), or did 'Act 10 boss = Kharok' simply mean 'Kharok is the campaign's final boss and the Gatekeeper should not be at the top', in which case nothing moves at all?
3. ASCENSION AS A THIRD POWER SCALE CONTRADICTS A DATED WRITTEN BOUND AND COLLIDES WITH AN EXISTING NAME IN THE CODE. CLAUDE.md (2026-09-11) records MetaState.ascension as 'prestige and nothing else: a title, a portrait and a leaderboard multiplier... It grants no level, no attribute, no card and no relic - levelling and gear stay the only two scales.' Separately, RunState.hero_ascension ALREADY EXISTS and already grants power - boss_director.gd increments it per boss and hero.gd multiplies max HP by Balance.ASCENSION_STAT_BONUS (0.18). Two unrelated things are called ascension and one of them is already a stat. ASCENSION_MAX is 2 with three titles, against a ladder the brief now runs three times. QUESTION: do you amend working rule 7 and date it, name the new scale something other than 'ascension' to avoid the collision with hero_ascension, and set the rung count and cap per difficulty?
4. SHIPPED PHASE NAME 'THE IRON LEVY' (enemies/chainmaker.tres) IS A COMPELLED-SERVICE WORD WITH A MAN'S NAME ON THE FIGHT. It passes copy_check - a levy is not on the denylist - which is precisely the euphemism class that got the forwarded story document refused. Section 10 proposes reading the levy as something the chain does rather than something Kharok orders. QUESTION: does 'The Iron Levy' stay under that reading, or should it become something with no conscription in it?
5. SHIPPED ASCENSION TITLE 'GATEKEEPER'S WARDEN' (Balance.ASCENSION_TITLES) IS A POSSESSIVE OVER A PERSON, and section 10's own test is that a sentence which survives the word 'master' is the wrong sentence. It is the player's prestige title, granted by a thing that is itself chainbound. It is not in a save (titles derive from a rank index) so it is safe to change. QUESTION: does it stay, or become something non-possessive?
6. 'THE LAST HUMAN HOLD' IS YOUR OWN WORDING AND I HAVE DROPPED 'HUMAN'. It raises a species question the game has never raised and implies the Chainbound clans are not human, cutting against world_host.tres's 'each was a people once, and each is still.' I have replaced it with a name that earns itself - the Hold is what held. QUESTION: do you sign that off, or is the species distinction deliberate?
7. THE TUTORIAL AS A THEFT IS LOAD-BEARING AND IS THE PIECE MOST LIKELY TO BE ARGUED. The Warden cutting a chained beast loose is what causes the ten-act campaign, and the Hold loses its wall because of it. It is what holds 'not a prophesied saviour' up without effort. QUESTION: do you want the opening to be unambiguously heroic instead? If so section 8 is rewritten and constraint 4 gets much harder to hold.
8. THE TUTORIAL MAP IS NEW WORK THAT IS NOT A DATA FILE. A narrow guided valley is a new BattleGrid template - the field is a 45x45 authored core inside a 75x75 with outskirts, and a corridor is not that shape. The narration is TutorialStepData on new triggers, which must be APPENDED to the Trigger enum and never inserted, because that enum is indexed by number out of every .tres and shifting it has already silently repointed twelve steps once. The art is nearly free thanks to the standing-Yuri correction. QUESTION: who owns the map, and does the tutorial run on the real battlefield or on a scene of its own?
9. THE CO-OP GATE MOVES AND IT IS CODE, NOT PROSE. main_menu.gd gates co-op on MetaState.tutorial_done (set by tutorial_coach.gd at the first crossroad); the brief opens it after the first real run. That needs a new statistic or a derivation from best_distance, plus a dated note in CLAUDE.md replacing 'New players run the tutorial before co-op opens'. QUESTION: is 'first real run' a completed run of any kind, or a run that reached a first act boss?
10. THE LADDER IS THE ONE PART OF THIS SPINE WITH A REAL BUILD COST. Three trial arenas, the Act 9 fight, per-difficulty completion state, and a Gatekeeper who must be absent from Act 10 when beaten on that difficulty. RiftArena extends RaidArena is the existing seam and a trial entered from the road is what rift gates already do, so this is content and gating rather than new scope - but the per-difficulty flag is new persistence under working rule 7. It is a run statistic in shape, like best_distance, so it should be derivable rather than a new save key. QUESTION: derivable, or a new key with its own bound written down?
11. NOTHING IN SECTION 57 CAN BE GATED. copy_check catches vocabulary and cannot catch euphemism; the refused document failed on one sentence with every denylisted word removed. Every new Kharok, Gatekeeper and Hold string needs a human read against section 10 before it ships - and the Hold is now a farming settlement with a Warden living in it, which is exactly the setting where 'works the land' can drift into something that reads wrong. QUESTION: who does that read, and does it happen before or after the strings are authored?
12. 'ROADSONG' IS A NEW COINAGE, NOT A SHIPPED WORD. It names the four-element system and gives the beacon a mechanism rather than a miracle, and the whole chain-magic explanation in section 2 hangs off it. QUESTION: do you want that word in player-facing strings, or should the mechanism stay unnamed?
13. YOUR PHRASE 'the chainbound host himself, Kharok' IS READ HERE AS KHAROK BEING THE FIRST AND DEEPEST OF THE CHAINBOUND, not as him being the Host's commander. That reading is what preserves 'They are not evil. They are compelled.' and makes the Act 10 fight a man who wants to lose and cannot arrange it. QUESTION: is the literal reading meant - that he embodies or leads the Host - in which case risk 1 applies and section 3 changes?
