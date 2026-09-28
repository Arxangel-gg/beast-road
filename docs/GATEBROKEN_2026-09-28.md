# Gatebroken: what beating the Gatekeeper's ladder pays

**28 September 2026 · owner: *"brainstorm the perfect system for rewarding
players who complete the gatekeeper's trials ... inspired by astonia 3's
seyan du class"***

## 1. What Seyan'Du was, and which part of it travels

In Astonia 3 a warrior or a mage who finished every quest and passed the
Seyan'Du's tests *became* Seyan'Du: a class with no restriction, able to use
both a warrior's and a mage's skills, wearing gear only a Seyan'Du could wear,
recognisable across a room. Three things made it the thing the whole server
chased, and only two of them translate:

- **Freedom the other classes did not have.** Wilderhold has no classes; it has
  four arms and one Oath. The one rule a Warden lives under that a class lives
  under is *one Oath at a time*. That is the restriction to lift.
- **Gear only they could wear.** A trophy that says where you have been. This
  game's gear is the capped attribute scale, and a trophy piece on it is safe.
- **Being the strongest thing on the server.** That part does not travel:
  ascension already is the third capped scale, measured by `curve_report`, and
  a fourth would be the untuned scale this project refuses.

## 2. What a Gatebroken Warden is

A Warden who has beaten the Gatekeeper on a campaign tier - rung 4 of that
tier's ladder (`GatekeeperTrials.cleared_on(tier) == STAGES`), which is also
what takes the Gatekeeper off that tier's summit - is **Gatebroken** on that
tier. It is a fact derived from `MetaState.gatekeeper`, stored nowhere else.

### 2.1 The second Oath

A Gatebroken Warden may swear **two Oaths, from two different arms**. Every
Oath is a boon paid for with a bane, so two are two prices as well as two
gifts; what is new is the *pairing* - the Red Road's lifesteal under the Deep
Well's kill-fed pool, No Retreat's striking dash under the Kept Gate's wards.
That is the Seyan'Du's cross-class freedom in this game's own terms: the one
rule the tree has that a build cannot buy its way past, lifted for the one
thing the road offers that is optional and hard.

- `MetaState.oaths_allowed()` is 2 when Gatebroken on any tier, else 1.
- `reach_problem` refuses a second Oath of the *same* arm always, and a second
  Oath at all unless Gatebroken; `_settle_disciplines` keeps the first two.
- `DisciplineUpgrades.boon` and `bane` sum over every sworn Oath.
- A partner's sheet carries the count (`AT_OATHS`, appended; an older row reads
  as one), so the host's copy of a Gatebroken partner swears two.
- `curve_report` reads the account's sworn Oaths through the same door.

### 2.2 The Gatekeeper's Mantle

The Gatekeeper's fall on a tier pays a **cape only it pays**: `GearData` with
`slot = CAPE`, `trophy = true` (never rolled by `Stash.roll`, never on the
Ledger's shelf), at the tier's own rarity - Oathbound on the Long Road,
Chainbroken on the Iron Road, Beastcalled on the Chainmaker's - with its own
look and tint, and Resolve as its attribute, because what does not break is
what the Gatekeeper tests. It is gear: attribute points on the capped scale
through `Stash.points`, nothing more. Once per tier, through
`GatekeeperTrials.record_cleared` when the rung is 4, laid on the ground where
he fell so it is picked up rather than banked.

### 2.3 The title

"Gatebroken" on the Hold's card and after the name on the board, once; "twice"
and "thrice" as the tiers fall. Prestige, read off the same fact.

## 3. Bounds

- **Working rule 7**: nothing new persists. `MetaState.gatekeeper` already
  holds the rungs; the Mantle is a stash piece; the second Oath is a node in
  the tree the account already keeps.
- **No fourth scale.** Two Oaths are two nodes' worth of boons and banes the
  model already reads; the Mantle is gear on the gear scale.
- **Optional stays optional.** A Warden who never knocks loses a cape and a
  pairing, and is otherwise exactly as strong - the ladder's own rule
  (`GATEKEEPER_AND_ASCENSION.md` §6).

## 4. Order of work

1. `oaths_allowed`, the door, the settle, the sheet, the curve - and
   `discipline_branch_check` grows a Gatebroken case.
2. The three Mantles as data, with their looks composed from a shipped cape and
   the Gatekeeper's own colour until PixelLab returns.
3. The title on the card and the board.
