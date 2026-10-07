# Mercenaries — design, 2026-10-07

The owner's brief, in full in the session transcript of 2026-10-07: the
simulated Wardens in the Hold may be hired for a procedural fee; a mercenary
joins a run, takes a share of the spoils and the rewards, fights and builds its
own towers and traps with its own AI, charges for every run it joins, talks in
the Hold and on the battlefield (random lines, what it is doing or noticing,
and above all useful alerts), has three wounds a run and after the third lies
in a bed at the Hold's inn until a medical bill is paid and it has rested, may
be released at any time, up to three may be hired, and each takes a player's
seat in the party - in co-op as well.

What follows is how that is built against the bounds this project already
holds, and the decisions the brief leaves open, each taken and said.

## 1. What a mercenary is

**A Warden the game simulates, built from the same pieces as a partner.** The
host has simulated every partner's Warden since co-op was built: a `Hero` body
on a seat, driven by an input source that is not this machine's hands, fighting
as a `WardenSheet` - its level, attributes and gear. A mercenary is exactly
that body with `MercenaryInput` as its hands. Nothing about the fight learns
that mercenaries exist: they swing, cast, take blows and fall through the doors
a partner does.

**A record, never a resource.** A mercenary is procedural - a name, a look, a
level, five attribute points and a set of worn pieces, rolled from the Hold
stranger it was hired from. It is stored as a row (`MetaState.mercenaries`),
not authored as data, because nobody authors the strangers either.

## 2. The bound

**A mercenary is no stronger for being kept.** Its level and gear are what they
were when it was hired; it gains no experience and no pieces. That is the
collection-not-accumulation rule spirits, the pen and the stable already live
under, and it is what keeps a mercenary from being a third power scale.

**And it counts as a player, for the road as well as for the seat.** A party of
one Warden and two mercenaries is a party of three: the road sends a party of
three's bodies, a boss stands a party of three's pool, and a body pays a party
of three's share of a rank (`RunState.party_size`). So a mercenary is worth what
a partner is worth and the curve the bands are held against already models it -
`curve_report` measures one to four seats. A hired hand is company, not a cheat.

**Its level is capped at the Warden's.** A stranger is rolled near the hiring
Warden's own level and never above it, with gear near the tier's expected
rarity, so nobody hires a level-100 to carry a level-3.

## 3. Money

- **The fee** (Marks, once) is procedural: a base, times the stranger's level,
  times what its gear is worth (`Stash.points` over its pieces). Shown before
  anything is spent.
- **The contract** (Marks, each road it joins), a share of the fee. Charged when
  the road begins; a Warden who cannot pay goes without, and is told at the gate.
- **The spoils**: `MERC_SPOILS_SHARE` of every kill's run currency goes into the
  mercenary's own purse on the road, and it spends that purse on its own towers
  and traps. The Warden's purse is that much lighter - which is the cost the
  brief names - and the board is no smaller, because the mercenary builds with it.
- **The reward**: `MERC_REWARD_SHARE` of the run's Marks payout goes to the
  mercenary, taken off the Warden's.
- **The bill**: Marks by level, owed after a mercenary's third wound.

## 4. Wounds and the inn

Three wounds a run (`MERC_WOUNDS`). A mercenary that falls gets up after the
respawn a Warden gets, at its spawn, with its wounds one fewer; on the third it
is carried off the road for the rest of the run. Back at the Hold it lies in a
bed at the inn: it rests for `MERC_REST_SECONDS` of wall clock from the moment
it was carried in, and it rejoins only when that rest is over **and** its bill
is paid. Wall clock rather than road walked, because the road is exactly what
it cannot walk. A mercenary may be released from its bed.

## 5. The AI

`MercenaryInput` is a `HeroInput`, so everything it does is a press a player
could make: move, aim, swing, dash, cast. Its order is one of four commands,
shared with the spirit at a Warden's shoulder later:

- **Follow** (default): stay within a leash of the Warden it serves, fight what
  comes within its reach.
- **Guard**: hold the point it stood on when told, fight what comes.
- **Hunt**: go to the nearest body on the road and fight it.
- **Wall**: stand by the town and fight what reaches it.

Every order gives way to staying alive: below a share of its health it falls
back toward the town until it has some back. In Preparation it buys: a tower
on the cheapest free anchor near its post that its purse pays for, else a level
on one it owns, else a trap on the road near its post.

## 6. Talking

Lines are data (`data/merc_lines`, one file a trigger) - working rule 9, and the
rule that keeps a line from being written in code. A mercenary says one when
something it would notice happens - a boss coming, a Herald, a frenzied animal,
the wall struck, a camp near, a dragon overhead, its own wounds, a wave held,
night falling - and now and then something of its own. **Restrained**: each
mercenary waits `MERC_BARK_GAP` between lines and an alert outranks idle talk.
A line shows over its head and in the chat feed under its name.

Interact beside a mercenary (on the road or in the Hold) opens a card: a line
of its own, its wounds and purse, and the four orders.

## 7. Seats and co-op

Up to `MERC_ROSTER_MAX` (3) hired. A Warden takes as many as there are free
seats: alone, up to three; in a party of two players, one each. The lobby counts
mercenaries as seats. **Stage one is a Warden alone and a host's own
mercenaries**; a guest's mercenaries reach the host as a sheet row (the same
door a partner's Warden does) in stage two.

## 8. What persists

`MetaState.mercenaries`: up to three rows of `{uid, name, look, level,
attributes, gear, state, rest_until, bill, taking}`. Additive - absent reads as
nobody hired - so `SAVE_VERSION` does not move. **It amends working rule 7**,
and the amendment is the pen's: a roster of individual characters, bounded at
three, none of whom grows. Nothing about a run is kept on a mercenary but
whether it came home on its feet.

## 9. Stages

1. **The roster** - hire, the fee, release, the inn and the bill, in the Hold.
2. **The road** - spawning on seats, the AI, wounds, the spoils, the reward,
   party size.
3. **Building** - towers and traps from its own purse.
4. **Talking** - the lines, the card, the four orders.
5. **Co-op** - a guest's mercenaries, seats across the party.

Each stage is its own commit with its own gate.
