# Gear, attributes and the stash — the rework

**Design record · 28 September 2026 · owner request**

> *"Elevate our Gear and loot systems also, and elevate the Gear UI to perfect
> aesthetics and polish ... Also need stat attributes rework and gear rework so
> that players can have better customization options that are more in depth
> and polished ... Be inspired by all of the best genres."*

## 1. What is there, and what is missing

The loot loop is already the owner's *"reason to replay"* (2026-09-01): a
hundred and fourteen kinds over nine slots, seven rarities, attribute points
on the capped scale levelling shares, one to five secondary attributes by
rarity, legendary affixes on `Modifiers` keys from Runed up, ten matched sets,
gear levels one to five bought with Shards and Marks, a Smithy that forges
from timber and ore with a gem deciding how far the piece climbs, a Ledger
that publishes prices, and trading.

What a player **cannot** do is change a piece they hold. A drop is what it
is: its secondaries and its affixes are rolled from its name, and the only
verbs are wear, level, keep, sell, break. Every genre the owner names gives
the player a hand on the piece - Diablo's sockets and tempering, Path of
Exile's currency orbs, Astonia's gem and mod system - and that hand is what
"customization" means. The attributes have the same shape: five numbers that
each multiply one thing, with no moment at which putting a tenth point into
Might *changes* what the Warden is.

So the rework is three things, in this order, each with its bound written
before its code, and one screen that shows all of it.

## 2. Attribute thresholds

Every ten points in an attribute - from levels and from gear together, the
number the Warden card already shows - unlocks a **perk tier**, to four. A
perk is a *named* thing on the card, not a bigger multiplier, and each moves a
number through a door the game already has:

| Attribute | Perk | Each tier | The door |
|---|---|---|---|
| Might | **Heavy Hand** | the finisher hits 6% harder | `HeroAttack` finisher scale, beside the form's |
| Vigour | **Second Wind** | out of combat, 1% of the pool a second comes back | `Health.regen` while nothing has struck for `HERO_REGEN_QUIET` |
| Swiftness | **Light Step** | the dash rests 8% sooner | `Hero.dash_cooldown()` |
| Focus | **Clear Mind** | spells cost 4% less mana | `Hero.cast_discount` (the Arcane's door) |
| Resolve | **Unbowed** | a blow shoves you 15% less | `Hero.shove` scale |

**The bound is the levelling bound.** A perk is reached by points on the
capped scale (working rule 7); it adds none. A tier is a *reason to commit* -
forty Might is a Warden, twenty of everything is not - which is what gives
gear a second axis: a piece that carries the four points that reach a
threshold is worth more than its points, and the stash says so.
`curve_report` reads Heavy Hand through the same door the swing does, so the
one tier that touches damage is modelled; the other four move survival and
mobility, which the curve deliberately does not carry. `ATTRIBUTE_THRESHOLD`
is the step and `ATTRIBUTE_PERK_TIERS` the ceiling; `attribute_check` holds
"one point a level" first and hardest, as it always has, and adds that no
perk grants a point.

## 3. Sockets and gems

A piece from Fine up carries **sockets** by rarity (`GEAR_SOCKETS`:
`[0, 0, 1, 1, 1, 2, 2]`), and a gem from the road's seams - amber, frost,
duskstone - may be set in one at the Smithy. A set gem grants one affix on a
`Modifiers` key, chosen by the gem's kind and sized by its rarity
(`GEAR_GEM_CEILING`, under the legendary ceiling so a gem is never the whole
piece), through exactly the reader legendary affixes already use. Nothing
downstream learns that gems exist.

- **One key a piece.** A gem whose key the piece already carries is refused;
  two sockets hold two different things.
- **Prying a gem out returns it, for Marks.** Diablo II destroyed it; a
  material the road gave up and the player carried home is not the Smithy's
  to eat. The Marks are the price of changing your mind.
- **A gem in a socket is still a material and nothing else** (2026-09-13): it
  moves a number the piece could already have carried as a legendary affix,
  buys no tower and pays no wave.
- **It is the second use of the gem**, beside the forge's rarity roll, which
  is what the materials note asked for on the day the mines were built.

The piece gains one field, `gems: Array[String]` - a list of gem ids, at most
its sockets - additive, so every piece on disk reads as unsocketed.
`SAVE_VERSION` does not move; `balance_test`'s piece-key walk names it.

## 4. Tempering

A piece's secondaries and legendary affixes are rolled from its `uid`, and
that is the whole mechanism of a reroll: **tempering assigns the piece a new
name**, at the Smithy, for Shards and Marks scaled by rarity. The kind, the
rarity, the level, the sockets and the gems stay; the roll is fresh; the
budget is the budget - `Stash.affixes` still divides what the piece is worth
and never adds to it.

- **Bounded by `GEAR_TEMPER_MAX`** (three): a piece records how often it has
  been tempered (`tempers: int`, the second additive field), and the price
  climbs each time. A piece that could be rerolled for ever is a slot machine
  with the drop tables as its reels.
- **Never a piece on the trade table.** The stash is locked while a trade is
  open, and a uid is what the table names a piece by.
- **The Ledger publishes prices by kind and rarity**, never by uid, so a
  tempered piece sells for what it always did.

## 5. The screen

The stash becomes a **paper doll**: the dressed Warden turning on their
pedestal (`WardenStage`, the Glass's own) with the nine slots round them,
each showing the worn piece's icon in its rarity frame, its set mark and its
gems; the list beside it, filtered by slot (tabs), by rarity, and by
"upgrades only", sorted by points, rarity or newest; and a **comparison
card** on hover or focus - every attribute of the candidate against the worn
piece as signed differences, the perk tiers it would reach or lose, the set
it would complete, its affixes and its gems. The consumables tab stays. The
row's verbs grow **Temper** and **Socket**, both of which open the Smithy on
that piece.

Every number on the card comes from the same functions the fight reads
(`Stash.points`, `affixes`, `legendary_affixes`, `worn_set`), never a second
arithmetic. Photographed by `stash_shot` at every shape before it is believed,
because a list that fits its numbers can still be one nobody can read
(2026-09-16).

## 6. Order of work

1. Thresholds and their perks, with the card and `attribute_check`.
2. Sockets and tempering at the Smithy, with the piece fields, the doors on
   `MetaState`, the Ledger's indifference, and `gear_socket_check`.
3. The paper doll and the comparison card, with `stash_shot`.

Each is gated on its own and recorded in CLAUDE.md on its own.
