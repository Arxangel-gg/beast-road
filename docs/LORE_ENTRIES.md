# Wilderhold - the Guide's lore entries

> Drafted 2026-09-17 against every shipped player-facing string, then
> reviewed adversarially against GDD section 57, act integrity and the
> shipped lore. **Nothing here is built yet and several points need an
> owner ruling - they are listed at the end.**

---

# Guide lore entries — corrected

## What I verified against shipped data

I read every string the draft leans on. Three findings reshape it.

**1. The draft's core reading is right, and shipped data supports it harder than
the draft found.** `enemies/chainmaker.tres` — *"The one who bound the beast …
the chains he made are the only thing still holding Yuri."*
`cinematics/summit.tres` — *"the last chain binding Yuri."* So the brief's
hijack story is already canon. But the draft missed two more:

- **`objectives/crown_unchained.tres`: *"Defeat the Chainmaker and reach the
  sanctuary."*** That is the **only** occurrence of "sanctuary" in shipped data,
  and it already puts the sanctuary past Kharok. The draft presented
  sanctuary = beacon as a clever economy; it is not an invention, it is shipped.
  `no_stone_fallen.tres` says *"Defeat the Chainmaker"* too. **Two shipped
  objectives already treat Kharok as the final fight** while
  `terrains/last_terrace.tres` sets `boss_id = "gatekeeper"`. The brief is not
  promoting Kharok — it is resolving a contradiction the game already ships.
- **`relics/core_gatekeeper.tres`: *"The last door was carrying its own
  weight."*** Shipped copy already calls the Gatekeeper **a door**. The draft
  invented the doors and worried about it. It is an extension of shipped
  metaphor.

**2. The draft's §57 self-check was run against the wrong list.** It published
"words deliberately not used" that omits three words that are on
`tools/copy_check.gd`'s `FORBIDDEN`: **`captive`, `shackle`, `in chains`**. The
draft's prose happens to avoid them, by luck rather than by checking. The real
list: `slave, enslav, captive, prisoner, bondage, chattel, thrall, shackle, put
to work, work detail, forced labour, forced labor, owned by, property of, in
chains`. **`body` is a scanned field**, so every line below is gated. Anything
written after this — a tutorial script, a cinematic, a Kharok line — must be
checked against that list and not a remembered one.

**3. The format finding the draft missed entirely, and it governs every page.**
`guide_screen.gd::_build_lore` renders **every entry's full body inline, in one
scrolling column**, grouped by category. There is no per-entry page. So:

| | shipped | the draft | corrected |
|---|---|---|---|
| WORLD entries | 7 | 14 | 14 |
| WORLD body words | ~669 | ~2,030 | ~1,510 |
| longest WORLD page | 133 words | 185 | 150 |
| STORY page shape | **one paragraph, ~50–55 words** | 3 paragraphs, ~180 | one paragraph, ~70 |

The draft's new pages run 160–185 words against a shipped range of 71–133, and
its prologue is three paragraphs and 180 words sitting at the top of a section
where **every shipped act page is one paragraph of about fifty words**. That is
the clearest "this is not the shipped voice" signal available and the draft's
own voice section never measured it. Every page below is cut to the shipped
envelope, which fixed most of the purple prose as a side effect.

The draft's "height budget" risk is unfounded — the body scrolls. The real cost
is reading length, above.

---

## Format notes

`LoreEntryData`: `id`, `display_name`, `title`, `category` (WORLD=0, STORY=1,
REGION=2), `unlock_act`, `order`, `art`, `body`. In `.tres`, paragraph breaks
are `\n\n` and dashes are ` - `. New entries take `display_name` = `title` and
`art = ""`.

`guide_check` requires `body.strip_edges().length() >= 60` and
`0 <= unlock_act <= ACT_COUNT`. All pages below pass. `unlock_act` is compared
against `MetaState.highest_act`; zero is always readable.

---

# PART ONE — revisions to shipped entries

## 1. `world_yuri` — append one paragraph

Both shipped paragraphs unchanged, verbatim. Append:

> He stood still for a long time before this. The Chainmaker's host drove the
> iron in where the ground was good and left him there, and he did what a
> Worldstrider does when it cannot walk, which is stand. He never lay down. The
> Warden cut the iron off him and he was moving before the morning was out. What
> still holds him is not on him and cannot be cut here - Kharok has that end, at
> the top of the world, and Yuri is walking towards it.

**Two corrections to the draft.**

**The draft falsified a shipped line.** It wrote *"the moss and the gardens are
what standing still that long looks like"*, re-explaining Yuri's moss as a
product of being held. `world_worldstriders` (shipped) says soil settles on
Worldstriders **as a class** — *"beasts so large that soil settled on their
backs, water pooled in the folds of their hide"* — walking or not. A
never-caught Worldstrider still has gardens on it. The re-explanation is
removed; the moss stays what it always was.

**The draft contradicted its own next page.** It wrote *"The chain that still
holds him was never iron"*, while its own `world_the_chain` opens *"It is real
chain … weighs what iron weighs."* Corrected to the formulation that page
actually argues: the iron is not *on him*, and the far end is not a thing you
can reach.

---

## 2. `world_worldstriders` — insert into paragraph 2

Paragraph 1 unchanged. Paragraph 2, insertion marked, everything else verbatim:

> Yuri is one of the last. The others were caught, chained and ridden into the
> earth by the Chainmaker's host, or simply lay down somewhere far from any road
> and were forgotten. **Yuri was caught too, and got neither of those. He was
> pinned standing, in good ground within sight of a human wall, and the town on
> his back stopped where he stopped.** Yuri has not lain down. Yuri is walking to
> the top of the world, and the town on his back is going with him.

Shorter than the draft's three sentences, and **it does not empty the town** —
see §4 below, which is where the draft broke a shipped line.

---

## 3. `world_host` — append one paragraph

Both shipped paragraphs unchanged, verbatim, including "They are not evil. They
are compelled." Append:

> They are on the roads at all because Yuri is walking; a beast that cannot move
> needs no army in front of it. And the oldest thing on the chain is in none of
> the clans. It is standing at the last step of the world, where Kharok set it
> himself and told it to wait.

---

## 4. `world_summit` — insert a second paragraph

Paragraph 1 and the closing paragraph unchanged, verbatim. Insert between them:

> The Hold had another word for it. Nobody there could say where the sanctuary
> was, only that there was supposed to be a thing at the top of the world that
> breaks chains, and that nobody who went looking had sent word back. It is the
> same place. It is a stair, a gate, a beacon, and Kharok standing in front of
> all three.

**Corrected from the draft: tense.** The draft's insertion said nobody knew
where it was, in a page whose *first paragraph* has just told you exactly where
it is. Put in the past explicitly, it reads as the Hold's ignorance rather than
the page's.

**"Sanctuary" is now a shipped word being picked up**, not a coinage —
`crown_unchained.tres`. Worth saying in the change note so nobody later
"corrects" it.

---

## 5. `world_the_hold` — append one paragraph

Both shipped paragraphs unchanged, verbatim. Append:

> The Hold is the one the Warden came out of: the same fields, the same wall, the
> same gate. The Host broke on that wall and did not get through it, which is the
> only reason there is still a gate to come back to. Not everybody went up the
> roads that night. Somebody had to stay and shut it behind them, and they are
> still there, and they would like to hear how the road went.

**This fixes a contradiction inside the draft that nothing flagged.** Its
prologue said the wall *"was going to hold, and then it was not going to"* — the
Host breaking through — and this entry said people stayed behind and *"are still
keeping it"*. Both cannot be true. The resolution is the one the fiction wants
anyway: **the Host turned off the wall to follow the beast.** That is why the
Hold survives, why there is somewhere to come back to, and why the Host is on
the roads at all — which is also what §3's appended paragraph now says.

---

# PART TWO — new entries

## 6. `world_last_hold` — "The Last Hold"

`category = WORLD`, `unlock_act = 0`

> Fields, a woodlot, four ponds, an ore seam somebody's grandmother opened, and a
> wall around all of it. It is the last one. There were others, and nobody can
> tell you much about what became of them, which tells you enough.
>
> Everything a Warden knows how to do was learned inside that wall. The Hold had
> nobody spare, so everyone learned all of it: where a tower goes, how to mend a
> gate, how to take a fish out of a pond without going in after it, which end of
> an axe. None of it was training for anything. It was the work in front of
> people.
>
> Yuri stood in the field outside, close enough that the weather came off his
> flank. Nobody alive had seen him move.

**§57-adjacent correction.** The draft wrote *"The Hold had nobody to spare, so
it taught every child all of it … It was just the work that was there."* That is
not enslavement language and would pass the gate, but a page describing a
walled settlement that puts *every child* to all of its work is the kind of
sentence a human reviewer stops on, and the meaning did not need it. Changed to
"everyone", which is also the better fit for an adult Warden.

The simile ("the way a village grows in the lee of a hill") is cut. Ending on
*"Nobody alive had seen him move"* is drier and does the same work.

---

## 7. `world_the_chain` — "The Chain"

`category = WORLD`, `unlock_act = 0`

> Where it touches, it is real chain: somebody made it, link by link, with a
> hammer, and a length of it weighs what iron weighs. Between those places there
> is nothing to see at all. The iron is only where it is fixed. The order is the
> chain, and the order runs down the world like veins.
>
> Where it reaches a people, the people march, and the marching does not stop.
> Where it reaches a beast, the beast stands. It does whichever the maker wanted,
> and that is the part that takes a while to sit with: it is not a curse and it
> is not a sickness. It is a decision, held open by somebody a long way off.
>
> The iron can be cut. The other end cannot, because the other end is not a
> thing. It is Kharok, still holding on.

**Correction: the draft led with "It is real chain" and left it there**, which
reads against shipped `world_host` — *"his chain-magic runs down the world like
veins"*. Veins are not iron links strung across a continent. Paragraph 1 now
reconciles the two explicitly, in shipped vocabulary: iron where it is fixed,
the order in between, running like veins. That makes both the shipped line and
the new page true, and it is a better page for it.

**"Anchor" is deliberately avoided** — the refused story document's one bad
sentence was *"compelled workers to maintain the anchors"*, and echoing its noun
in the project's plainest statement of how compulsion works is an avoidable
resemblance.

---

## 8. `world_kharok` — "Kharok the Chainmaker"

`category = WORLD`, `unlock_act = 5`

> He was a Warden, and one of the best of them. Not Yuri's - his own beast is
> under a hill somewhere. It lay down the way they do, and he could not get it
> up again.
>
> What he did afterwards was work out how a beast could be made to keep going
> without needing to want to. It is chain-magic and it has never once failed. He
> used it on every Worldstrider his host could reach and rode most of them into
> the ground, and then there was one left. That one he pinned standing, outside a
> wall, in good ground.
>
> He will tell you he is keeping the last Worldstriders alive. He is not lying.
> The clans on the chain are not his people either - they are people it reached
> on the way up.

**Three corrections.**

**The draft contradicted itself in one paragraph.** It wrote *"Some of the wall
lines on Yuri's back are his"* and, two sentences later, *"His beast lay down"* —
so either Kharok was Yuri's Warden or he was not, and the page supported
neither. Whether Kharok was Yuri's own Warden is a large canon commitment
(it makes the pinning personal and complicates *"The Warden and Yuri are
bound"*). Stated plainly the other way: **not Yuri's.** If the owner wants the
personal version, that is a different and bigger page.

**"That is not the part of it that is untrue" is unparseable**, and the shipped
register is plain. Replaced with *"He is not lying"*, which is harder and says
the same thing.

**The staking now has a reason.** The draft had the host stake Yuri and consider
it "finished business", which is odd for a host that rides beasts to death. The
corrected paragraph makes it the same act as the self-justification: the ridden
ones died, so the last one is the one he keeps standing. *"He is not lying"*
then lands on the worst possible reading, which is what §57's framing wants —
his logic coherent, his conclusion refused.

**§57.** *"made to keep going without needing to want to"* is the highest-risk
sentence in this set and the reason a human read is still required. Its subject
is a **beast** and its verb is **going**, not work; shipped canon already has
these beasts *"caught, chained and ridden into the earth"*, which is worse. *"The
clans on the chain are not his people"* is the ownership denial, deliberately
placed in his own entry.

---

## 9. `world_gatekeeper` — "The Gatekeeper"

`category = WORLD`, `unlock_act = 3`

> The Host calls it the Gatekeeper. Kharok called him something else once, when
> they walked the same road and he was the only person Kharok trusted at his
> back.
>
> He set him at the last step and told him to wait, and he put the order in with
> the chain so that it would hold. Then he went up. Nobody has come back to
> relieve it. It has held that stair through every war that has walked up it, and
> it has never been able to put the order down, and there is a real question
> about how much of what is under the armour remembers being given one.
>
> Everybody says "it". That started as a mistake and has been getting closer to
> accurate ever since. Beat it and it sets the chain down, which is the only
> thing anyone has ever done for it.

Kept almost as drafted — this is the strongest page in the set. The `him` → `it`
slide is the page and must survive editing. Trimmed to the shipped envelope.

It picks up three shipped strings without touching them:
`enemies/gatekeeper.tres` *"Nobody has come back to relieve it"*;
`cinematics/gatekeeper.tres` *"It has held this stair through every war that
walked up it"*; and the phase names *"It Raises the Chain"* / *"It Sets Down the
Chain"*, which winning now makes literal.

**No name is invented.** Correct call, kept.

---

## 10. `world_gatekeepers_doors` — "The Gatekeeper's Doors"

`category = WORLD`, `unlock_act = 3`

> Four doors stand on the road with no wall on either side of them: one in the
> snow, one in the Rustwood, one on the Iron Steppe, one in the Ashen Reach. They
> open in order, and nothing whatever makes a Warden open any of them.
>
> Behind the first three are the sentinels the Gatekeeper set on the stair's
> approaches, back when it still expected to be relieved. Behind the fourth is
> the stair, and the Gatekeeper on it.
>
> Beat it at its own door and it sets the chain down; reach the Last Terrace
> after that and the step is empty, with Kharok alone on it. Leave the doors shut
> and it is up there beside him, both at once. Walk a harder road and the doors
> are shut again - it keeps its own count, and the count does not carry.

**Correction: the draft dodged what the first three trials contain** — *"things
the Gatekeeper set behind them … making arrangements"*, which is vagueness where
the brief asked for trials. The answer is already on disk:
`enemies/gate_sentinel.tres`, *"Set on the stair and told to hold it. It is
still holding it."* — the Last Terrace's own breed, whose shipped description is
the same sentence as the Gatekeeper's. **The first three doors are gate
sentinels.** That turns a content request into reuse and makes the ladder a
graduated version of the fight it leads to.

The mechanism is otherwise the draft's and is right: the fourth door takes the
Warden **up**, so *"set there and told to wait"* stays literally true, the ladder
stays opt-in and ordered, and "beating him clears him from that difficulty's
summit" is a consequence rather than a rule.

**It is also less of an invention than the draft thought.**
`relics/core_gatekeeper.tres` already reads *"The last door was carrying its own
weight."*

---

## 11. `world_ascension` — "Ascension"

`category = WORLD`, `unlock_act = 9`

> A Warden who gets all four doors open has stood in front of the chain longer
> than anyone now living, and has watched the oldest thing on it set its length
> down. Nobody comes away from that unchanged.
>
> Ascension is the Hold's word for what is left afterwards. The Gatekeeper hands
> nothing over; it stops hiding how the thing is made, and a Warden who has seen
> that can take a weight they could not take before. It is the third way a Warden
> grows and the last, and like levelling and like gear it has a ceiling, because
> a person is only so large.
>
> Nobody needs it to walk a road. It is for the roads walked again, where the
> wall comes down faster than it used to. Each harder road shuts the doors and
> runs them again, and each time there is further to go.

**Three corrections.**

**The draft dodged a brief item.** The brief says *"Nightmare and Hell each run
the ladder again and extend the ascension tree."* The draft's page says the
doors reset per difficulty but **never says the tree grows** — it explicitly
declines to enumerate ranks and leaves extension unsaid. The last sentence now
says it.

**The draft's final paragraph contradicted itself.** *"Nobody needs it. Every
road can be walked without it"* followed by *"on those roads it is most of the
reason anyone gets up the stairs at all"*. Both halves of the brief are true of
*different* roads, so the page now names which: not needed to walk a road, and
for the roads walked again.

**Two size metaphors in one entry** — "the same size" and "carry weight" — is
one more than the shipped register would use. One kept.

---

## 12. `world_second_warden` — "The Second Warden"

`category = WORLD`, `unlock_act = 1`

> The Hold taught everyone the same work, so the Warden was never the only one
> who could do it. Some of the others went up the roads that night as well, and a
> few walk roads of their own now - other towns, other beasts, or no beast at all
> since theirs went down.
>
> One of them can come and stand a road with you. Only one Warden is bound to
> Yuri, and that does not change while there are two of you on his back. The
> second is a guest. The beast knows the difference even if the Host does not.

**The draft dodged this and flagged it instead.** Co-op unlocking after the
first real run is a brief item, and *"One defender, bound to one beast"* is a
shipped line that a second Warden on one beast falsifies unless somebody
answers it. The answer is cheap, it is one data file, and it is already set up
by `world_last_hold` ("everyone learned all of it"). The bond stays singular;
the guest is a guest. `unlock_act = 1` matches the brief.

The *reading* still wants a ruling and is in the risks — but flagging a question
is not a substitute for proposing the answer.

---

## 13. `story_prologue` — "Prologue · Before the Road"

`category = STORY`, `unlock_act = 0`, `order = 0`.
Title: `"Prologue  ·  Before the Road"` (double-spaced middot, matching the act
pages).

> The Host came up the valley and the Hold's wall was not going to hold. Nobody
> had asked the Warden and nothing had been foretold; there was a beast in the
> field outside the gate that nobody alive had seen move, and cutting tools, and
> no better idea. Yuri stood. The four roads up his flanks were walked that
> night, and the Host turned off the wall to follow.

**Rewritten from three paragraphs and ~180 words to one paragraph and ~68.**
Every shipped STORY page is **one paragraph of about fifty words** — `story_act01`
is 53, `story_act10` is 50. A three-paragraph prologue at the top of that
section is visibly a different kind of object, on the page where the difference
is most obvious.

**It also drops an invention that broke a shipped line.** The draft wrote *"The
town on his back was where its people had left it, waiting"* — an emptied town.
`world_worldstriders` (shipped) says *"the first people who climbed them never
climbed down"*. A ghost town on a Worldstrider undercuts that for no gain. The
town stopped; it did not empty — now said once, in §2, where it belongs.

**The rumour and the sanctuary moved to `world_summit`**, which is the page about
the sanctuary. The prologue does not need to carry them.

Constraint 4 is still discharged in one clause: *"Nobody had asked the Warden and
nothing had been foretold."*

---

# PART THREE — the shipped entry the Act 10 change falsifies

## `story_act10` — "Act 10 · The Last Terrace"

**Shipped:**

> Stone stairs to the sky. The Gate of the Crown holds the last step, set there
> and told to wait, and the Gatekeeper has waited longer than the Warden has been
> alive. Past it is the beacon, and past the beacon is a world with no chain in
> it. Yuri stops here. This is where the walk was going.

**Corrected proposal** — one paragraph, final three sentences verbatim:

> Stone stairs to the sky. Kharok is at the top of them, holding every road at
> once and the last chain on Yuri with them, and if the Gate of the Crown was
> left shut on the road below, the Gatekeeper is standing up there too. Past them
> is the beacon, and past the beacon is a world with no chain in it. Yuri stops
> here. This is where the walk was going.

**Two corrections to the draft.**

**It dropped "the Gate of the Crown", a shipped proper noun still in use.**
`region_last_terrace.tres` (shipped, untouched) says *"Stairs cut into the top of
the world. **The Gate of the Crown** holds them."* Deleting the name from one
page and leaving it on another leaves the game using a proper noun it no longer
introduces. It is kept here — and made the **fourth door's** name, which ties the
new mechanism to shipped vocabulary instead of adding to it.

**It was two paragraphs.** Every shipped act page is one.

---

# Reading order

`ContentDB.lore_sorted()` sorts **globally by `order`, tie-broken by `id`**, and
`_build_lore` then filters by category — so cross-category `order` collisions are
harmless and the draft's table was safe on that point.

**Corrected rule: order follows `unlock_act`, then reading order.** The draft
interleaved gated pages among readable ones, which matters because a locked row
still renders — `_lore_row` draws *"Reach Act N"* and *"This chapter is still
ahead of you."* **All seven shipped WORLD entries are `unlock_act = 0`, so the
WORLD section has never shown a locked row.** This change introduces the first
five. Clustering them at the end keeps a new account's Lore tab a clean run of
readable pages.

| order | id | unlock_act | status |
|---|---|---|---|
| 0 | `world_worldstriders` | 0 | revised |
| 1 | `world_yuri` | 0 | revised |
| 2 | `world_last_hold` | 0 | **new** |
| 3 | `world_the_chain` | 0 | **new** |
| 4 | `world_host` | 0 | revised (was 2) |
| 5 | `world_warden` | 0 | unchanged (was 3) |
| 6 | `world_summit` | 0 | revised (was 4) |
| 7 | `world_the_hold` | 0 | revised (was 5) |
| 8 | `world_road_cards` | 0 | unchanged (was 6) |
| 9 | `world_second_warden` | 1 | **new** |
| 10 | `world_gatekeeper` | 3 | **new** |
| 11 | `world_gatekeepers_doors` | 3 | **new** |
| 12 | `world_kharok` | 5 | **new** |
| 13 | `world_ascension` | 9 | **new** |

`story_prologue` takes `order = 0` in STORY, ahead of the act pages at 1–10.

---

# §57 review

Checked against the **actual** `copy_check.FORBIDDEN` list, quoted above rather
than remembered. No entry uses any of the fifteen. `body` is a scanned field, so
the gate will confirm the vocabulary — what it cannot confirm is the framing,
which is the whole of §57's release requirement.

**Where the compulsion sits, in every page:**

- The chain carries **an order**, held open by a person. *"It is not a curse and
  it is not a sickness. It is a decision."*
- The Gatekeeper is **told to wait**, which is the shipped framing, and waiting
  is the entirety of what was done to him. He is set to no task, makes nothing,
  fetches nothing and serves nobody.
- The clans are **compelled** (shipped, verbatim), and *"not his people"* is
  stated in Kharok's own entry, in his own worst light.
- Yuri is **pinned standing**. He is not used, ridden or worked in the present
  tense; the riding is shipped past tense about the beasts that died.

**The two sentences a human should read before this ships:**

1. `world_kharok` — *"work out how a beast could be made to keep going without
   needing to want to."* Magical compulsion of an animal, milder than shipped
   *"ridden into the earth"* — but it is the sentence in this set that most
   resembles the refused document's shape.
2. `world_last_hold` — *"The Hold had nobody spare, so everyone learned all of
   it."* Already softened from the draft's "every child"; still a page about a
   community that needed everyone working.

Neither is a §57 violation on my reading. Both are the reason §57 is a human
requirement and not a regex.


---

## Decisions taken in this draft

- The iron/last-chain split is kept as the spine, but corrected: the draft's Yuri page said the remaining chain 'was never iron' while its own Chain page said the chain is real iron. The corrected formulation is the one the Chain page actually argues - the iron is not on him, and the far end is not a thing you can cut.
- Kept 'Yuri has not lain down' verbatim by distinguishing lying down from being pinned standing - but removed the draft's re-explanation of Yuri's moss as a product of standing still, which falsified the shipped Worldstriders line that soil settles on these beasts as a class, walking or not.
- Kharok stays a former Warden, but is stated plainly to be NOT Yuri's Warden - the draft had 'some of the wall lines on Yuri's back are his' two sentences from 'his beast lay down', supporting neither reading.
- Kharok's pinning of Yuri is given a reason rather than left as 'finished business': the ridden Worldstriders died, so the last one is the one he keeps standing. This makes 'he is keeping the last Worldstriders alive' true in its worst sense, and replaces the draft's unparseable 'that is not the part of it that is untrue' with 'He is not lying.'
- The Gatekeeper page is kept nearly as drafted - the him-to-it slide is the strongest writing in the set - trimmed only to the shipped length envelope.
- The Gatekeeper's first three doors are answered with a shipped resource rather than dodged: enemies/gate_sentinel.tres, 'Set on the stair and told to hold it. It is still holding it.' The draft said only 'things the Gatekeeper set behind them', which is vagueness where the brief asked for trials.
- The Gate of the Crown is restored to story_act10 and made the fourth door's name. The draft deleted it while region_last_terrace.tres still uses it, which would have left the game using a proper noun it no longer introduces.
- The Hold's survival is made explicit and consistent: the Host turned off the wall to follow the beast. The draft's prologue had the wall failing while its Hold page had people still keeping the gate - a flat contradiction nothing flagged.
- The prologue is cut from three paragraphs and ~180 words to one paragraph and ~68, because every shipped STORY page is one paragraph of about fifty words. story_act10 is likewise returned to one paragraph.
- The emptied town on Yuri's back is removed. The draft invented it and it sits against the shipped line 'the first people who climbed them never climbed down'; the town stopped when he stopped, which is all the story needs.
- All new pages are cut to the shipped WORLD envelope (71-133 words; the corrected set runs 110-150). The Lore tab renders every body inline in one scroll, so the draft's 2,030-word WORLD section was a 3x increase in reading length on a screen with no per-entry page.
- Order now follows unlock_act then reading order, clustering the five gated pages at the end. All seven shipped WORLD entries are unlock_act 0, so this change introduces the first locked rows that section has ever shown, and the draft interleaved them.
- A co-op page (world_second_warden, unlock_act 1) is written rather than only flagged. 'One defender, bound to one beast' is shipped and a second Warden falsifies it unless answered; the bond stays singular and the second Warden is a guest.
- world_summit's insertion is put explicitly in the past tense, because the draft had paragraph two saying nobody knew where the sanctuary was directly after paragraph one states where the beacon is.
- 'Sanctuary' is documented as a shipped word being picked up (objectives/crown_unchained.tres, its only occurrence) rather than as a coinage, so nobody later 'corrects' it.
- world_the_chain's opening is reconciled with shipped 'his chain-magic runs down the world like veins' - iron where it is fixed, the order in between - rather than leading with 'It is real chain' and leaving the two unreconciled. The word 'anchor' is deliberately avoided as an echo of the refused document's one bad sentence.
- The draft's claim that data/tiers/*.tres 'carry display names only and no fiction' is false: hell.tres reads 'The Chainmaker's own terms. Come at ninety or do not come.' The harder roads already have a voice, which world_ascension's closing sentence now answers.

## Open - these need the owner

1. OWNER RULING: Is Kharok a former Warden whose own beast lay down, and is the Gatekeeper his closest companion? Both are invented. They are consistent with every shipped string and CLAUDE.md's 2026-09-16 triage named exactly this as the largest canon gap closable with prose - but canon is the owner's.
2. OWNER RULING: Was Kharok ever Yuri's Warden? I ruled 'no' because the draft supported both readings in one paragraph and 'no' is the cheaper commitment. 'Yes' makes the pinning personal and is a better story, but it complicates the shipped line 'The Warden and Yuri are bound' and needs its own page.
3. OWNER RULING: Who was Yuri's Warden while he stood in the field, and what happened to them? 'One defender, bound to one beast' is shipped as a general law, so a Worldstrider that stood outside a human wall for generations with no Warden is a hole a player will find. No page above answers it; the corrected prose avoids raising it rather than closing it.
4. SECTION 57 - two sentences want a human read before they ship. world_kharok: 'work out how a beast could be made to keep going without needing to want to' (magical compulsion of an animal, milder than the shipped 'ridden into the earth', but the closest in shape to the refused document's sentence). world_last_hold: 'The Hold had nobody spare, so everyone learned all of it' (already softened from the draft's 'every child'). Neither is a violation on my reading; both are why §57 is a human requirement.
5. PROCESS - the draft's published §57 vocabulary list omitted three words that ARE on copy_check.FORBIDDEN: captive, shackle, in chains. Its prose avoids them by luck, not by checking. Anyone writing the tutorial script, Kharok's lines or the new cinematics must check the real list in tools/copy_check.gd, not a remembered one.
6. DATA CHANGES the Act 10 promotion requires, none of them lore. terrains/last_terrace.tres boss_id 'gatekeeper' -> 'chainmaker'; cinematics/gatekeeper.tres eyebrow 'Act X Boss'; cinematics/chainmaker.tres eyebrow 'True Final Boss'; cinematics/summit.tres trigger_id is 'gatekeeper'; enemies/gatekeeper.tres description mentions no doors.
7. DATA GAP the draft missed: relics/core_gatekeeper.tres is a boss core with source_act = 10, and there is NO core_chainmaker. All ten acts have exactly one core. Moving the Gatekeeper off Act 10 leaves the act's core named for a boss that is no longer there, and Kharok with none. Is a new core authored, or is core_gatekeeper re-pointed at the ladder?
8. WORKING RULE 7 - Balance.gd carries a signed 2026-09-11 block stating ascension 'is prestige and nothing else ... grants no level, no attribute, no card, no relic'. The brief re-cuts that to a third capped power scale. CLAUDE.md and that comment both need a dated amendment in the same change.
9. CODE HAZARD the draft missed: Balance.gd already has a SECOND, older 'ascension' - ASCENSION_STAT_BONUS at line 4650, 'Stat multiplier added per boss ascension', a survivor of the three-act design that is unrelated to MetaState.ascension at line 2549. Wiring a new stat scale into a file with two constants named ascension is how the wrong one gets read.
10. ASCENSION_MAX is 2 and ASCENSION_TITLES holds three positional entries. Both must grow for Nightmare and Hell to extend the tree, and a positional title array is the Role/Trigger hazard that has already shipped wrong content twice.
11. SCOPE - the tutorial map does not exist. data/tutorial/ is twenty in-run coach steps, not a place. world_last_hold and story_prologue describe a walled settlement with fields, a woodlot, four ponds and an ore seam, and a night the Host came up a valley. Every word of that is currently lore for something the game cannot show.
12. SCOPE - the doors need a prop, an interact prompt, an arena entry and a per-difficulty completion flag. Recommend building them on RiftGates (an existing interactable gate read by the same 'interact' action) and gate_sentinel (an existing breed), not as new art. Is that acceptable, or do the doors want their own asset?
13. OWNER RULING: does the ascension rank still arrive on the summit results screen, or does clearing the ladder become the grant point? The brief says clearing the trials unlocks ascension; the shipped code offers it after the summit. world_ascension is written to the brief.
14. READING: 'hijack Yuri from its rest' is read as pinned standing, not sleeping unbound. The shipped data forces this ('The one who bound the beast'), but if the owner meant Yuri was resting free, cinematics/summit.tres's 'the last chain binding Yuri' is wrong and Part One needs rewriting.
15. READING: the between-runs Hold and the tutorial's last human hold are one place, and the Host turned off its wall to follow the beast. If the owner intends the tutorial hold to be overrun or permanently lost, world_last_hold and the world_the_hold revision both need reworking.
16. READING: a second Warden is another of the Hold's own, a guest on Yuri's back, with only one Warden bound to him. Does the owner want co-op's second player to have a different origin - another beast's Warden, say - and does it want its own page at all?
17. READING LENGTH - the WORLD section goes from 7 entries and ~669 words to 14 and ~1,510, all rendered inline in one scroll with no per-entry page. That is still more than double. Cutting further means cutting pages, not sentences.
18. ART - all new entries take art = "". Four shipped world entries carry story art (story_worldstrider, story_host, story_warden, story_summit), so the new pages will read plainer beside them. Art for Kharok, the Gatekeeper, the chain and the last hold is an ASSET request nobody has raised.
19. CHURN - order changes for five shipped entries (world_host, world_warden, world_summit, world_the_hold, world_road_cards). Display-only, not an id, not saved, no migration - but it is churn in shipped files, and the ordering rule (unlock_act, then reading order) should be written down so the next person does not reshuffle by taste.
