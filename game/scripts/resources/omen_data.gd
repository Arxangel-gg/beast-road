class_name OmenData
extends GameData

## A portent read at the end of an act: one thing the road takes, one it gives.
##
## Owner brief, 2026-09-10, from the ideas document: Diablo IV's Infernal Hordes,
## where a player deliberately makes their own run worse in exchange for more.
##
## ## Why this shape and not another difficulty slider
##
## The run already has one of those. Every crossroad offers Guarded, Contested
## or Perilous, which trades danger for reward rolls - a scalar, chosen fresh
## each time, forgotten by the next crossroad. It works and it is not memorable,
## because nothing about it accumulates and nothing about it has a name.
##
## An omen **stays for the rest of the run and stacks with the ones before it**.
## Three acts, three omens, and by the summit a player is carrying a specific
## sentence about what kind of run this was: the night never lifted, the Bogkin
## came in numbers, and every one of them was worth something. That sentence is
## the thing worth having. It is also the reason the bane is written first on
## the card - the cost is the decision, and the boon is what makes it tempting.
##
## ## What an omen may and may not do
##
## Both halves resolve into `Modifiers`, the same flat table relics and boss
## cores feed, so nothing downstream needs to know an omen exists. That is the
## bound as well as the plumbing: **an omen may only move numbers the game
## already has an opinion about.** A portent that added a mechanic would be a
## content system wearing a card's clothes, and it would not be testable against
## the curve the acts are tuned to.
##
## **No art, deliberately.** Working rule 4 says an asset a resource requires
## must be in `ASSET_MANIFEST.md` with a placeholder generated in the same
## change, and ten new icons is a real cost for a card that already carries a
## name, a cost, a promise and a portent line. If omens ever earn icons, this is
## where the path convention goes, and the manifest rows go in with it.

## What the road takes. An effect key from `Modifiers`, and how much.
##
## Signed as it acts: an omen that makes enemies hit harder carries a positive
## `enemy_damage`, and one that costs the player health carries a negative
## `hero_max_hp`. `omen_check` asserts the bane is genuinely a cost rather than
## flavour text over a free upgrade.
@export var bane_effect: String = ""
@export var bane_magnitude: float = 0.0

## What the road gives, in the same terms.
@export var boon_effect: String = ""
@export var boon_magnitude: float = 0.0

## The cost, in the player's words, on the card.
@export_multiline var bane_text: String = ""

## And the promise.
@export_multiline var boon_text: String = ""

## What the Warden actually saw. One line, and the only place the road speaks.
##
## Player-facing string in data rather than in logic, per working rule 9 - and
## the reason omens carry one at all is that "+35% enemy quantity" is a number
## while "the tracks come in fours now, and they are not going around us" is a
## road that is telling you something.
@export_multiline var portent: String = ""

## Earliest act this may be read in. Some omens are too heavy for Act I.
@export_range(1, 3) var first_act: int = 1


## The three portents a given run offers at a given act.
##
## **Derived on both machines, never relayed**, which is the pattern the regional
## relic offer already uses. The draw comes out of the run's own seeded stream,
## so a host and a guest compute the same three without a packet, and a shared
## seed reproduces its portents like everything else in a run.
##
## The first version of this rolled on the host only with the unseeded global
## RNG. The guest was offered nothing, so when the host chose, the guest refused
## an id it had never been shown and played the rest of the run without the
## modifiers its partner had. Nothing anywhere said so.
##
## Static and on the resource rather than on the run scene so that `omen_check`
## can ask what a seed would show without building a battlefield - a test that
## needs a scene to exist is a test that quietly becomes a no-op.
##
## Sorted before shuffling, because `ContentDB.omens` is a dictionary and its
## order is an implementation detail. Shuffling an unordered list is not
## reproducible from a seed, which is the fault this project already recorded
## once for `hash(id + seed)` orderings.
static func offer(taken: Array, act: int, count: int) -> Array[String]:
	var pool: Array[String] = []
	for id: Variant in ContentDB.omens:
		var omen: OmenData = ContentDB.omen(String(id))
		if omen == null or taken.has(omen.id) or omen.first_act > act:
			continue
		pool.append(omen.id)
	if pool.size() < count or count <= 0:
		return []
	pool.sort()
	# Fisher-Yates from the run's stream, drawing without replacement.
	for index: int in range(pool.size() - 1, 0, -1):
		var other: int = RunState.rng("omens").randi_range(0, index)
		var swap: String = pool[index]
		pool[index] = pool[other]
		pool[other] = swap
	pool.resize(count)
	return pool
