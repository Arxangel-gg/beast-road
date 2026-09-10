# The Long Ledger — operations

The in-game marketplace. Post a price, ride the road, come back to it settled.

Owner brief, 2026-09-10: a grand exchange "for players to be able to create a
trading economy for all of the loot in the game".

## The one thing to understand before changing anything

**Prices are shared. Custody is not.**

There is no account server. The Supabase project behind the leaderboard answers
to an anonymous key that every copy of the game carries, so anything a client
can write, any client can forge. A forged leaderboard row is graffiti; a forged
*item* is the end of the loot economy, and `CLAUDE.md` records the bound: gear
is never created.

So the Ledger shares the only thing safe to share — **what pieces sold for** —
and never the pieces. The counterparty is always the Ledger's own caravans, the
escrow is always local and always in the player's own save, and the worst a
forged row can do is make somebody's guide price wrong for a day.

If the project ever gains real accounts and server-side logic, a true
player-to-player order book becomes possible and this is the decision to revisit
first. Until then, **do not** be tempted to put items in the table. One
compromised client with a text editor would mint Oathbound gear for everybody.

## The table

The game reads and writes one table. It does not exist yet and the game works
without it: an unreachable feed falls back to the authored markup and
`Balance.EXCHANGE_BASELINE_SUPPLY`, which is the state most sessions will be in
and the state every gate runs in.

```sql
create table if not exists public.exchange_sales (
  id          bigint generated always as identity primary key,
  at          timestamptz not null default now(),
  rarity      smallint not null check (rarity between 0 and 4),
  price       integer  not null check (price >= 0 and price <= 100000000),
  vendor      integer  not null check (vendor >= 1 and vendor <= 100000000)
);

alter table public.exchange_sales enable row level security;

-- Anyone may read the going rate, and anyone may report a sale. There is
-- nothing here worth protecting and nothing here worth forging for: the game
-- clamps what the feed can do to a price, so a hostile row is worth a nudge.
create policy "read the going rate"
  on public.exchange_sales for select using (true);
create policy "report a sale"
  on public.exchange_sales for insert with check (true);

create index if not exists exchange_sales_recent
  on public.exchange_sales (at desc);
```

**No update or delete policy on purpose.** A row is a fact about a completed
sale; nothing should be able to rewrite history, and a table nobody can edit is
a table with no interesting attack on it.

### Keeping it small

One row per completed sale, three small integers. At a thousand sales a day
that is well under a megabyte a year, and the game only ever reads the newest
`Balance.EXCHANGE_FEED_ROWS`. If it ever needs trimming, delete by age:

```sql
delete from public.exchange_sales where at < now() - interval '90 days';
```

The first Supabase project this game used was restricted for exceeding its
storage quota, which is why that paragraph is here rather than assumed.

## What the numbers mean

| constant | what it decides |
|---|---|
| `EXCHANGE_SLOTS` | lines a player may have standing (6) |
| `EXCHANGE_GUIDE_OVER_VENDOR` | what a caravan pays over the stash's own sell price |
| `EXCHANGE_BID_FLOOR` | **the anti-laundering bound** — see below |
| `EXCHANGE_ASK_CEILING` | the most anyone will ever pay |
| `EXCHANGE_DEMAND_FLOOR` / `_CEILING` | how far the feed may move a price |
| `EXCHANGE_FILL_AT_GUIDE` | fraction of an order closed per unit of road |
| `EXCHANGE_BASELINE_SUPPLY` | how much of each rarity the road carries offline |

**The two load-bearing ones** are `EXCHANGE_BID_FLOOR` against
`EXCHANGE_GUIDE_OVER_VENDOR`, and `EXCHANGE_BASELINE_SUPPLY`.

The first stops buy-low-vendor-high from printing Marks: the cheapest possible
purchase must cost more than the stash pays for the same piece. `0.72 × 1.6 =
1.152`, so it does, by about fifteen percent — and `ExchangeMarket.min_bid`
floors at vendor + 1 outright as well, so the two constants cannot be retuned
into each other by accident.

The second stops the Ledger from replacing the road as the place gear comes
from. Gear is "the reason to replay" (owner, 2026-09-01); if Oathbound pieces
were freely buyable, a player would farm Marks and buy their build.

`exchange_check` holds both against every rarity and level in the game, and both
have been verified by breaking them deliberately. Moving either is a red gate
rather than a slow economic collapse nobody notices for a month.

## Why orders fill on distance

Word travels with the caravans, so **the road is the clock**. Standing in town
settles nothing; a long run settles a lot. The Ledger pays you for playing, and
never for leaving the game open — which is also why the screen says "about half
a run of road left" and never a number of minutes.
