# Build-defining uniques - design pass (2026-10-07)

**Built 2026-10-07**, with the proposed answers to the three owner questions
(a later fall repeats at `UNIQUE_REPEAT_CHANCE`, a unique trades like any piece,
weapons wait) and one change, recorded in its row: VIII is "your spells brand
what they strike", because borrowing a tower's element changed only a spell's
tint and its wetness, too little to build around. `unique_check` holds it.

*The triage of 2026-10-07 (`IDEAS_REVIEW_2026-10-07.md` §3) adapted
"build-defining uniques" as **authored trophy pieces that carry a
keystone-style re-route** - the Road Card bound, "when or what, never how much" -
**one per act boss, found only there**, and asked for a design pass before any is
authored. This is that pass. Nothing here is built.*

## 1. What a unique is, in one sentence

**A piece of gear that changes a rule of the Warden's fight, earned by beating
one act boss, and paid for with a slot.**

Diablo's uniques are memorable because each one *changes what the build does*
(Grim Reaper's scythe, Doombringer, Shako) rather than adding to a number. This
game already has the two halves: gear that is found and worn on the capped
attribute scale, and keystones - five Road Cards that re-route an effect the
game already has onto a new trigger. A unique is a keystone that lives on a
piece of gear instead of in a hand, so it persists between runs and is chosen
by what the Warden wears.

## 2. The bounds - every one already has a precedent here

| Bound | Precedent | What it rules out |
|---|---|---|
| **A unique re-routes an effect the game already has; it never adds magnitude.** When something fires or what it fires on - never how hard. | Keystones (2026-09-25), discipline synergies (2026-09-10) | "+40% damage", a new damage source, a stat |
| **Its attribute budget is its rarity's, like any piece.** The unique effect is what the slot buys instead of a free choice of kind and affixes. | Matched sets (2026-09-15) - the cost of a set is choice | a unique that is also the best stat stick |
| **A trophy is paid by one thing and never rolled, stocked or forged.** | `GearData.trophy`, the Gatekeeper's Mantle (2026-09-28) | buying one at the Ledger; forging one at the Smithy |
| **Read at the one door the effect already goes through.** A `Modifiers.UNIQUE_*` flag at magnitude one, read by the system it re-routes, exactly as a keystone flag is. | `Modifiers.KEYSTONE_*` | a second code path for an effect |
| **A partner fights as their own account.** The flag comes from the worn kinds a partner's sheet already carries, so the host's copy of a partner reads the partner's unique. | `WardenSheet` (2026-09-26) | a unique that only works for the host |
| **Nothing new persists.** A unique is a kind id; the stash row is `{kind, rarity, level, uid, ...}` as it is today. | Gear affixes (2026-09-11) | a save migration |

## 3. How they drop

- **One unique kind per act boss**, eleven in all, the boss's own.
- **The first fall of that boss on each road (tier) pays its unique once**, laid
  at the Warden's feet *on the machine whose account earned it* - a personal
  drop with no relay, since a partner earns their own on their own machine - at
  the tier's trophy rarity, the Mantle's rule.
- **After the first, a later fall of that boss on that road has a small chance
  to drop it again** (`UNIQUE_REPEAT_CHANCE`, proposed 0.08), so a second copy
  for a partner or a stash is a farm rather than impossible. *(Owner question 1.)*
- **Never rolled by `Stash.roll`, never stocked by the Market or the Ledger,
  never forged.** It can be traded between two players (it is gear), which is
  the one way it moves - *(owner question 2)*.

## 4. Slots

**Rings, amulets, charms, gloves and boots only.** Those slots draw nothing on
the dressed Warden, so a unique needs an icon and nothing else - no held weapon
picture, no armour layer per body. A unique weapon would need a held picture
for the fist to close on and a forge sheet for its swing; that is affordable
later and is not where the first eleven should spend the art.

## 5. The eleven - each a re-route of something already in the game

Each names the existing effect it re-routes and the one door that reads it.

| Act boss | Unique (slot) | The rule it changes | Re-routes, at the door |
|---|---|---|---|
| I | **Rootbinder's Grip** (gloves) | A finisher that kills roots the bodies round the kill for a moment. | The finisher's kill → the existing slow (`apply_slow`) at a root's factor, `HeroAttack._land_on` |
| II | **Sandglass Sabatons** (boots) | A dash leaves a short trail of shifting sand that slows what crosses it. | The dash → a ground slow through `Vfx.ground_slow`, the thorns' door |
| III | **Hoarfrost Signet** (ring) | A body that dies chilled shatters, chilling those round it - Cold Snap, worn. | `KEYSTONE_COLD_SNAP`'s own door, flagged by the piece |
| IV | **Bogwater Amulet** (amulet) | Water you cast leaves the ground wet; lightning that crosses wet ground chains to a body standing on it. | Wet (2026-09-14) and the chain rule, `SpellCaster._touch_the_world` |
| V | **Gearwright's Charm** (charm) | When a tower in reach falls, the Warden's next finisher is empowered. | The perfect-evade empowerment (`No Ground Given`) on a new trigger |
| VI | **Saltbound Band** (ring) | A ward you hold, when struck to nothing, slows what struck it. | The ward break (`WardShell`, `Health`) → `apply_slow` |
| VII | **Horselord's Treads** (boots) | Sprinting through a body shoves it as the mount's charge does, for no damage. | The ram's shove (`MOUNT_RAM_*` knockback) on a sprint, damage zero |
| VIII | **Prismheart** (amulet) | Your spells brand what they strike, so the towers hit it harder. *(Changed when built: the first idea, borrowing a tower's element, moved only a tint and a wetness.)* | The Hemorrhage form's brand (`Enemy.brand`), on `SpellCaster._land` |
| IX | **Emberwreath** (charm) | A burning body that dies lights the brush where it falls - Tinderstrike on burns rather than on the finisher. | `KEYSTONE_TINDERSTRIKE`'s door, a second trigger |
| X | **Anchorchain Gauntlets** (gloves) | A finisher pulls the bodies in its arc a step toward you. | The Chain Hook's pull (`HOOK`) on the finisher |
| Crown | **Kharok's Sigil** (ring) | A blow you take while warded is answered by the nearest tower, which fires at the striker. | `Tower` targeting (Hunter's Mark's door): the striker becomes the board's first choice |

Each moves *when* or *what*: none of the eleven adds a number. The two
weakest are flagged for the owner: **VII** may read as a power if the shove
interrupts a wind-up (it does - that is the point, and the stagger footing of
2026-09-15 bounds how often), and **XI** turns a defensive moment into a board
answer, which is the Warden-and-board coupling the late game was asked for.

## 6. Where it is read, and the co-op half

- `Modifiers` gains `UNIQUE_*` flags and fills them from **worn kinds** - the
  same path the set tiers take - so a partner's unique is read off the partner's
  worn row on the host.
- The doors above each ask `WardenSheet.value_of(sheet, Modifiers.UNIQUE_*)`
  rather than `Modifiers.value`, because each is a Warden key, not a board key -
  the split `WardenSheet` already makes.
- The stash row and the comparison card say the rule in the piece's own words,
  in the legendary gleam's colour; the Codex gains a **Uniques** page listing
  the eleven with the boss that drops each and a "found" mark.

## 7. Gate and art plan

- `unique_check`: every act boss names a unique that exists; a unique kind is a
  trophy, never rolled in a thousand `Stash.roll`s, never on the Market's or
  the Ledger's shelf, never forgeable; the first fall pays it once per tier and
  a second first fall does not; each unique's rule is driven through its real
  door with the piece worn and not worn (the keystone gate's pattern), and a
  partner's sheet reads its own; the budget of a unique equals its rarity's.
- Art: eleven icons with PixelLab, styled on the shipped gear icons ("the
  suffix that matches gear is cold", per the memory note) - about sixty
  generations.

## 8. Owner questions

1. **Repeat drops**: a small chance on a later fall of the same boss (proposed),
   or strictly once per road?
2. **Trading**: may a unique move between two players' stashes like any piece?
   (Proposed yes - it is gear, and trading is how a second copy reaches a
   partner without a farm.)
3. **Weapons later**: is a second wave of unique *weapons* (with held pictures)
   wanted, or are eleven trinkets the whole of it for 1.0?
