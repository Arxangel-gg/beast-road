# A legendary affix that grants a skill branch (ruling R7), 2026-10-06

Ruling R7 of `SKILL_TREE_REWORK_2026-09-26.md` §6 approved, on the owner's
delegation, that *"a legendary affix may grant a skill upgrade"*. Nothing has
been built on it. This is the design, written so the next session builds it
against bounds rather than inventing them, and so the owner can refuse any of
it before a line of code.

## 1. What it is, in one sentence

A legendary piece may carry, as one of its legendary affixes, **a branch of a
skill the Warden has not learned**, worn exactly as if learned for as long as
the piece is worn.

That is Diablo IV's best-loved system (the triage of 2026-09-26 said so: *"the
praise clusters ... legendary affixes that change how a skill behaves"*) and it
is the only piece of that triage still owed. It fits because the branch
vocabulary already exists: an enhancement or a fork of a skill is a
`DisciplineNodeData` moving one number the skill already has (power, cooldown,
reach, area, time, count, shove, a status, a refund, a heal, a ward), read where
that number is made through `DisciplineUpgrades.for_skill`. A gear-granted branch
is **the same node reached by a second road**, never a new effect.

## 2. The bounds, each the one something older already lives under

1. **It costs the piece an affix.** A branch grant is a `GearAffixData` with a
   `branch_id` instead of a `Modifiers` key, and it takes one of the piece's
   `GEAR_LEGENDARY_COUNT` affix places - so a piece that grants a branch moves
   one fewer number. Rolled from the piece's own `uid` as every affix is, so
   nothing is added to the save and a partner's sheet reads the same grant off
   the same name (`WardenSheet` already carries worn pieces by uid).
2. **It can never exceed the tree.** `DisciplineUpgrades.for_skill` sums a
   branch's key once: a grant of a branch the Warden has *learned* adds nothing.
   The sum is still clamped at `DISCIPLINE_UPGRADE_CEILING`, which is the bound
   every branch is held to today, so a grant cannot be a third road onto the
   levelling scale - it is the tree's own number, reached earlier or without
   the points.
3. **It may grant the twin.** The one thing a grant does that the tree cannot:
   a fork's twin, closed by `exclusive`, may be granted by gear while the other
   is learned - Diablo's "both upgrades" fantasy. Both forks' keys are summed,
   and each is already inside the ceiling on its own; the pair is the choice
   the tree refuses, bought with a legendary affix place. **Recorded as the one
   deliberate loosening**, so it is not read as a bug by the gate that holds
   exclusivity on *learning*.
4. **Never a skill, never an Oath, never a form.** A grant is an enhancement or
   a fork only. Granting a skill would put a cast on the bar from a drop, which
   is the build's core drawn rather than chosen (the triage's own reason for
   refusing random level-up pools); an Oath is a rule with a bane; a form is
   the swing. `gear_affix_check` refuses a `branch_id` that is not a branch.
5. **A grant for a skill not held is dormant.** Worn by a Warden who has not
   learned the branch's skill, it does nothing and the row says so ("Wide
   Fall - Ember Fall not learned"), as a set piece says `3/5`. It is not a
   reason to re-roll the tree, and it must not be a hidden lever.
6. **Tempering rerolls it**, as every affix: a new name is a new grant. That is
   the whole of what makes a branch grant something to *hunt* on the road
   rather than to assemble at the Smithy.

## 3. What the curve carries

`curve_report._discipline_scale` reads the form's enhancement and nothing else
of the tree, by design (2026-09-26: the rest is conditional and a best-case
model that met every condition would model a player the road never produces).
A grant is the same arithmetic: a granted *form* enhancement is read by the same
door and so is in the model; a granted spell branch is outside it exactly as a
learned one is, held by the ceiling. **Nothing new to model.**

## 4. The deal

Branch grants are drawn from the whole branch list at the piece's own rarity
odds; a grant for a skill of an arm the account has not opened is as likely as
any other, because the piece outlives the road and the arm may open next week.
About one legendary in four should carry a grant - enough to be the thing a
player tells a friend about, few enough that a Beastcalled piece is still
mostly its numbers. `GEAR_BRANCH_GRANT_SHARE` in `Balance`, read by the roll.

## 5. The gate

`gear_affix_check` grows: a grant resolves to a real enhancement or fork; a
grant of a learned branch adds nothing; a grant of the twin sums with the
learned fork and stays under the ceiling; a grant for an unheld skill reads
back as dormant through `DisciplineUpgrades.for_skill`; the same uid grants the
same branch on every read and on a partner's sheet; tempering changes it. Plant:
a grant that bypasses the ceiling, named by the ceiling check.

## 6. What it is not

Not a new persistence (the piece is `{kind, rarity, level, uid, gems, tempers}`
as before), not a new power scale (the tree's own numbers under the tree's own
ceiling), not a reason for a fourth tab in the Hold. The Disciplines page shows
a worn grant lit in gold on its node, which is the one screen change.
