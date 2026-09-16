# The forwarded canon story, triaged — 2026-09-16

`docs/ChatGPT_More_Ideas_6.md` was committed on 2026-09-16 and had never been
triaged. It is a **1,001-line proposed canon** for Wilderhold: a setting, a
timeline, an origin for the Chainmaker, a ten-act story table, an identity for
the Gatekeeper, an alternate ending and a postgame.

**Nothing in it is built and no ruling is assumed.** Canon is an owner decision,
and this document contains several that re-cut shipped fiction rather than
extending it.

---

## 1. The headline finding: it is not one document, and it argues both sides

It is a **three-turn transcript**, and the turns disagree.

- **Turn 1** (lines 1-68) proposes a post-apocalyptic future Earth: 2377 CE,
  Year 311 "After the Wilding", a cataclysm in 2066.
- **Turn 2** (73-441) is shown the game's actual lore and **explicitly reverses
  turn 1** — *"I would not make Wilderhold explicitly future Earth"* — re-dating
  it to Year 311 of the Bound Age and building a mythic-folklore canon on the
  shipped material.
- **Turn 3** (443-1001) answers a separate request and **reinstates everything
  turn 2 discarded** — 2066, 2377 CE, engineered Worldstriders, the A.W.
  calendar — without acknowledging the reversal.

**So "adopt the document" is not an available action.** Someone has to choose
turn 2 or turn 3, and they are mutually exclusive. Turn 2 is the one written
with the game in front of it.

---

## 2. Refused

**One sentence must not ship, and it is the §57 half a gate cannot catch.**
B34 has Kharok *"compelled workers to maintain the anchors"* — forced labour
with every denylisted word removed. `copy_check` passes all 1,001 lines (it was
run: 2,196 strings, zero hits), which is exactly the point: §57 makes
*"no unreviewed enslavement language ships"* a release requirement **because**
the gate only catches the vocabulary, and a human has to catch the rest. This is
the rest.

**The acts 6-10 rename and reorder.** The document renames three regions,
deletes two (including the finished Glass Fields), invents one (The Chainscar)
and moves the Gatekeeper from Act 10 to Act 9. Beyond the content cost, **it
breaks every banked expedition** — a snapshot names its act — which is the
precise hazard the project avoided on 2026-09-11 by refusing to renumber acts
1-3 when seven were added after them.

**The 2377 CE / Earthworks reinstatement.** The game has 4,032 shipped PNGs and
none of them depicts a reactor, a vehicle or a ruin of industry. Turn 3 also
has humans *manufacture* Yuri in the 2050s, against `world_yuri.tres`'s
*"old past counting"* — a mythic formula a known build date falsifies. **The
bare calendar contradicts nothing** (shipped fiction has no dates at all, only
relative phrases); it is the manufacture that does.

**The Earthwitness layer** (C1-C97, the largest part of the document). It needs
a speaking entity, a creature larger than any sprite in the game, an emergence
set piece, a ten-region "Revealing" and a three-way ending negotiation. The
surfaces this game's fiction actually has are 27 lore entries, 21 cinematic
cards, a four-panel intro and a three-line ending screen — and v4 §6 caps any
mandatory sequence at ten seconds. There is no dialogue system and none is in
scope.

**"The Beast Beneath"** as a name for it. "The beast" is Yuri in fifteen shipped
strings, including the glossary's *"Yuri: the beast"*. The document's own
alternatives — "The Groundspeaker", "The Last Witness" — carry no collision.

**A Yuri who refuses roads.** `world_yuri.tres` states exhaustively when he
stops; `crossroads.tres` says the choice is the party's; v4 §32 gives Yuri
exactly one mechanical state. A Yuri who declines a road takes the one decision
the crossroad exists to give the player.

---

## 3. Needs an owner ruling

**The premise of the final act is inverted, and the document does not notice.**
It has Yuri as one of the last **unbound** Worldstriders, with the plot being to
prevent his binding. The shipped game says he is **already bound and cutting his
chains is the finale** — in four player-facing places and in the spec:

- `enemies/chainmaker.tres` — *"the chains he made are the only thing still holding Yuri"*
- `cinematics/chainmaker.tres` — *"Break him, and Yuri walks free."*
- `cinematics/summit.tres` — *"the last chain binding Yuri"*
- `ending_screen.gd` — *"The last chain gives. Yuri stands…"*
- `Game_Design_v4.md` §201 — the final encounter puts *"direct hero pressure on the chains binding Yuri"*

That last one is a **mechanic**, not a line: v4 makes the chains a thing the
hero attacks, and the document has nothing to attack because nothing is bound
yet. Everything else in the document rests on this, so it is the first ruling.

**"Some genuinely support Kharok."** B36 calls *"They are not evil. They are
compelled."* the spine of the faction design, then B38 immediately gives the
Host four stances including willing collaborators. That sentence ships verbatim
in `world_host.tres` and in panel 2 of the opening intro, and `world_host.tres`
continues *"That is why a leader you bring down is sworn, ransomed or
memorialised, and never owned."* If a clan marches willingly, the stated reason
for the Oathbound framing stops applying to it — and that framing is a §57
release requirement. Willing collaborators are a legitimate story; they are a
re-cut of the premise rather than a nuance on it.

**Nine regions plus the summit, or ten plus the summit?** The document's Act 10
*is* the Crown of the World. The game says *"Ten regions lie between the Verdant
Maw and that step"*, *"Ten acts, then the summit"*, and `FINAL_ASCENT_ACT =
ACT_COUNT + 1`. Folding the summit into Act 10 removes a region and re-points
every per-act table the 622-wave campaign is tuned against.

**The Revealing** (C65-C70): a conquered population involuntarily marked so
everyone can see what they are, adapted from a religious eschatological sign.
Two separate rulings there and neither is mine to make.

**Bosses that survive and talk.** Several of the document's best beats need an
act boss to be freed and deliver exposition. Shipped act bosses are killed —
*"When the Wolf Marshal falls, the green lets go"* — and the Oathbound system is
raid-scoped: `data/captives/` holds exactly three files, all rank-and-file breed
ids, i.e. raid-camp chieftains. The game has no boss-dialogue delivery at all;
an act ends on a full-screen `MilestoneCinematics` card.

**The Gatekeeper becomes a man.** Six shipped strings call it *"it"*, including
two boss-phase banners.

---

## 4. What is genuinely good, and cheap

All of these are **words in existing `.tres` fields**, contradict nothing
shipped, and fill holes the game visibly has. They are recorded as ready rather
than built, because they are still canon.

- **Kharok was a Warden** (B15-B31) — and one of the greatest. His Worldstrider
  was dying; he found a way to hold Roadsong still; he was *celebrated* for it;
  he could not stop. The game ships three sentences about him and **no origin at
  all**, so this is the largest gap in the canon filled at the cost of prose.
- **The Gatekeeper was Kharok's closest companion** (B72-B76) — Kharok could not
  kill him, so he chained an order into him: *wait here*. It attacks because it
  cannot stop waiting. Highest value per word in the document, and it keeps the
  shipped line verbatim (*"Keep that. It's fantastic."*).
- **Roadsong** (B10-B14) names a thing the game already runs: fire, water, stone
  and wind as expressions of one force, which *is* the elemental system and the
  earth's wrath, and held in one place it pools and warps the land — which is
  what a charged zone already does.
- **The chain is anchors** (B65, B22), and the iron poisoning the Rustwood is
  ancient chain-metal carried up through the roots. A retro-explanation for a
  region that already exists.
- **Split lore from mechanics in the Guide** (B95-B96) — the capped-growth and
  run-scope lines belong in Basics, not in Lore & Story. Pure data edit.
- **The beacon as a legend rather than a stated solution** (B97) — good
  instinct, but it introduces one contradiction the document does not notice, so
  it wants checking before it is written.

**And a large part of turn 2 is already true**, which is worth recording so it
is not built twice: *"They are not evil. They are compelled."*, the Warden
explicitly not being a prophesied savior, the Warden-Yuri mutual dependence and
the lantern's stated reason, and **Acts 1-5 preserved almost exactly** — the
document reproduces them down to the verbatim act titles.

---

## 5. How this was checked

Three readers were run against the document, the shipped fiction and the spec,
then three adversarial lenses — contradictions, confirms-and-adds, and risk.
Every claim was checked against the actual `.tres` or `.gd` string rather than
against paraphrase, and `copy_check` was run over the whole document.

The **method** is worth keeping: the previous four forwarded documents each
turned out to be roughly half already-built, and this one is the same. Turn 2 is
largely a transcription of shipped text with about eight genuine repairs in it.
Reading it as a proposal rather than as a description is what finds those eight.
