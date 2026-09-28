# The Disciplines, phase 2: clusters, branches and forks

**28 September 2026 · owner: *"complete overhaul ... basic skills clusters, core
skills clusters, defensive and mobility clusters and ultimate clusters with the
style of branching off of a skill for bonuses and forks at the end for
modifiers and variations of the skill similar to diablo4's skill tree system"***

Phase 1 (`SKILL_TREE_REWORK_2026-09-26.md`, built the same day) made the tree
the account's, edited in the Hold, with four arms in rings. It shipped with two
things owed and this is both: every skill was one node with nothing hanging off
it, and a full account could learn the whole tree. What Diablo IV does that
answers both is the shape of a *skill*: a node, a bonus branching off it, and a
fork of two exclusive modifiers at the end. Forty of those forks are forty
decisions nobody can own both sides of.

## 1. The shape

Each arm is a trunk of five clusters, opened by **points spent in that arm**
(`Balance.DISCIPLINE_RING_DEPTH`, counted rather than graphed, as before):

| Cluster | Ring | Opens at | Holds |
|---|---|---|---|
| **Basic** | 1 | 0 | the chain's form(s), with their branches; a passive |
| **Core** | 2 | 3 | the Attack and Power skills, with their branches; a passive |
| **Guard** | 3 | 7 | the Defense skill (the step, the veil, the guard, the roar), with its branches; a passive |
| **Ultimate** | 4 | 11 | the Ultimate, with its branches; a passive |
| **Oath** | 5 | 15 | the arm's Oath - one sworn across the whole tree |

"Defensive and mobility" is one cluster here because this game's Defense slot
already is: Aegis Step is the dash and Sanguine Guard is the shell, and both sit
in the same slot on the bar.

**A skill is three nodes.** The skill (one point), its **enhancement** (one
point; `Kind.UPGRADE` with `parent_id` the skill and no `exclusive`), and one of
two **forks** (one point each; `parent_id` the *enhancement*, sharing an
`exclusive` group). The forks are the variations: a fork is learned only once
its enhancement is, and its twin is then closed. Switching is free in the Hold,
as every reshaping is.

**A passive has ranks** (`DisciplineNodeData.ranks`, three for most). Learning
it again raises the rank for a point, and its effect is the authored value per
rank times the rank. **The per-rank value is the old value over the rank
count**, so a passive at its top rank is worth exactly what the single node was
worth on 2026-09-26 - the ceiling did not move; what moved is that it is
reached in three purchases rather than one. `discipline_tree[id]` holds the
rank (it held `1` since phase 1, so a save reads unchanged).

**The Oath is the key passive.** One per arm at the tip, all four in one
`exclusive` group, so one is sworn across the tree. Each pays for a boon with a
bane, as a portent does.

## 2. Why this makes the top a choice

Phase 1's gate held only that one Normal clear does not buy everything. A full
account earns about 87 points. This tree has about 130 nodes of which about 40
are fork twins (only one of each pair can be held) and 4 are Oaths (only one),
and its passives carry about 30 further ranks - so what a Warden may hold at
once is about 105 points' worth against 87 earned. A capped Warden owns most of
one build and none of the others' forks, which is the shape D4 arrives at with
58 points over a larger tree. `discipline_check` measures this rather than
asserting it: the most any order of learning can hold must exceed what a full
account earns.

## 3. The branch vocabulary

An enhancement or a fork carries an `effect_id` from a small vocabulary read in
one place each, scoped to the skill it hangs off (`DisciplineUpgrades.for_skill`
walks a node's `parent_id` up to the skill or form it belongs to). The bound is
the one every number in this project is held to: **an upgrade moves a number
the skill already has**, and `DISCIPLINE_UPGRADE_CEILING` bounds how far any one
key may move it.

| Key | Moves | Read at |
|---|---|---|
| `up_power` | the spell's damage, by a share | `SpellCaster._resolve` |
| `up_cooldown` | the cooldown it lays down, by a share | `_effective_cooldown` |
| `up_mana` | its cost, by a share | `try_cast` |
| `up_reach` | its cast range | `_reach` |
| `up_radius` | its area | `_radius` |
| `up_duration` | a ward, veil, beam, field or companion's time | `_duration` |
| `up_extra` | one more counted thing: a thorn, a strike, a companion | the kinds that count |
| `up_shove` | its knockback | `_resolve` |
| `up_status_burn` / `_wet` / `_brand` / `_bleed` | what it hits wears a status | `_damage_area`, the single-target kinds |
| `up_vs_burning` / `_wet` / `_branded` / `_bleeding` | harder against a body wearing one | the same |
| `up_kill_mana` / `up_kill_cooldown` | a kill by this spell refunds | after the blow |
| `up_heal` | a share of what it dealt heals the caster | after the blow |
| `up_ward` | a ward of a share of max HP on cast | `try_cast` |

Forms have their own, read where the swing already reads the form: `form_power`
(more on every swing), `form_finisher_heal`, `form_finisher_arc`,
`form_bleed_every_hit`, `form_status_burn`, `form_vs_branded`,
`form_brand_power`, `form_splash_shield`, `form_finisher_dash_refund`,
`form_finisher_mana`, `form_finisher_bolt`, `form_finisher_cast_discount`.

Every key is on `DisciplineEffects.IMPLEMENTED` and the gate's "implemented
means named in code" rule holds each one to a consumer outside the ledger.

## 4. The Oaths

| Oath | Arm | Boon | Bane |
|---|---|---|---|
| **The Red Road** | Blood | every swing heals a share of what it dealt | draughts, fish and the well heal half |
| **The Kept Gate** | Holy | a ward the Warden gains also shields the nearest tower | damage falls away with no tower in reach |
| **No Retreat** | Berserk | the dash strikes what it crosses for a share of a finisher | no perfect evade |
| **The Deep Well** | Arcane | the pool is far deeper | it refills only on kills |

Each is `Kind.OATH` with `effect_id`/`effect_value` for the boon and
`bane_id`/`bane_value` for the bane, and both halves are read by the same
consumers the boon's vocabulary uses. A `curve_report` band read sworn and
unsworn is the gate on each.

## 5. The screen

One arm at a time, as a trunk from left to right - Basic, Core, Guard,
Ultimate, Oath - with the four arms as tabs and the Warden standing at the
root. Inside a cluster each skill stands with its enhancement to its right and
its two forks fanning off the enhancement, joined by lines, so the branching is
what the eye reads. Passives stand under the skills with their rank shown. The
radial map of phase 1 could not hold a hundred and thirty nodes at a readable
size, and a trunk is what the owner named.

## 6. The model

`curve_report._discipline_scale` reads the form and every form upgrade that
moves a swing, and the passives at their rank, through the same `WardenSheet`
doors the hero reads. Spell upgrades are outside that model exactly as spells
are - the report models a naked combo and has never carried a cast - so they
are bounded by `DISCIPLINE_UPGRADE_CEILING` instead, which is the same
arrangement the ascension rank had before it was modelled.

## 7. Art

PixelLab is spent until 2026-10-11. Every branch icon is composed from its
skill's own painted icon with a shipped emblem laid over a corner - the gold
gem for an enhancement, an element or status glyph for each fork - by
`tools/compose_discipline_icons.py`, the recipe the Arsenal's icons were made
under. An Oath wears a relic. Installing a bespoke painting is overwriting the
file.

## 8. Bounds

- Working rule 7: the tree is the same save key with ranks in its values; the
  Oath and the bane are nodes. Nothing new persists.
- An upgrade moves a number the skill has; `DISCIPLINE_UPGRADE_CEILING` bounds
  it; a form upgrade is in the curve's model.
- One Oath. One fork of each pair. A rank never past `ranks`.
- Co-op: the sheet packs `id:rank` (a bare id reads as rank one from an older
  build), and the host's copy of a partner reads their upgrades through the
  same static door.
