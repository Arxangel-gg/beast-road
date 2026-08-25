# Leaderboard operations

The game has one public, per-tier community board backed by Supabase and a
bounded personal-best board in the save. Network failure never blocks a run,
debrief, or menu. Posting is explicit from the debrief; merely finishing a run
does not publish anything.

## The project the game points at

`Leaderboard.ENDPOINT` and `Leaderboard.ANON_KEY` name it. The two must always
agree: a Supabase anon key is a JWT whose `ref` claim *is* the project, so a key
left over from a different project answers every request with 401 and no other
clue. Both were repointed on 2026-08-20 after the first project was restricted
for exceeding its storage quota (HTTP 402 on every request, including reads).

**Current status, verified 2026-08-25: the table is LIVE.** A read answers 200
with rows, the schema matches the contract below exactly, and the anon key in
`Leaderboard.ANON_KEY` is the one that project answers to. Four rows present.

Nothing below needs doing again unless the project is moved. The rest of this
section is kept because it is how you tell *which* broken state you are in.

Historical: before the SQL had been run once, a read answered:

```
{"code":"PGRST205","message":"Could not find the table 'public.runs' in the schema cache"}
```

That is the expected answer before the SQL below has been run once, and it is
not a code failure — the game handles it the same way it handles being offline:
personal runs are still scored, shown and stored, at most
`Balance.LEADERBOARD_PENDING_MAX` unsent rows are queued, and the shared board
reports itself unavailable rather than erroring.

To check which state you are in, without opening the game:

```bash
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON"   "https://xscyioampvjfqcciccie.supabase.co/rest/v1/runs?select=submission_id&limit=1"
```

`[]` means the table is live and empty. `PGRST205` means run the SQL. `401`
means the key and the URL are from different projects.

## Create or repair the table

Run this once in the Supabase SQL editor. It is intentionally safe to rerun: the
table and policies are replaced into the same contract.

```sql
create table if not exists public.runs (
  submission_id uuid primary key,
  name text not null,
  tier text not null,
  score integer not null,
  act smallint not null,
  wave integer not null,
  hero_level smallint not null,
  duration integer not null,
  victory boolean not null,
  seed text not null,
  version text not null,
  created_at timestamptz not null default now(),

  constraint runs_name_length check (char_length(name) between 1 and 20),
  constraint runs_name_controls check (name !~ '[[:cntrl:]]'),
  constraint runs_tier check (tier in ('normal', 'nightmare', 'hell')),
  constraint runs_score check (score between 0 and 999999999),
  constraint runs_act check (act between 1 and 3),
  constraint runs_wave check (wave between 0 and 100000),
  constraint runs_hero_level check (hero_level between 1 and 100),
  constraint runs_duration check (duration between 0 and 86400),
  constraint runs_seed_length check (char_length(seed) <= 32),
  constraint runs_version_length check (char_length(version) between 1 and 32)
);

create index if not exists runs_tier_score_created_idx
  on public.runs (tier, score desc, created_at asc);

alter table public.runs enable row level security;

revoke all on table public.runs from anon, authenticated;
grant select on table public.runs to anon, authenticated;
grant insert (
  submission_id, name, tier, score, act, wave, hero_level, duration,
  victory, seed, version
) on table public.runs to anon, authenticated;

drop policy if exists "runs are publicly readable" on public.runs;
create policy "runs are publicly readable"
  on public.runs for select
  to anon, authenticated
  using (true);

drop policy if exists "bounded runs may be submitted" on public.runs;
create policy "bounded runs may be submitted"
  on public.runs for insert
  to anon, authenticated
  with check (
    char_length(name) between 1 and 20
    and name !~ '[[:cntrl:]]'
    and tier in ('normal', 'nightmare', 'hell')
    and score between 0 and 999999999
    and act between 1 and 3
    and wave between 0 and 100000
    and hero_level between 1 and 100
    and duration between 0 and 86400
    and char_length(seed) <= 32
    and char_length(version) between 1 and 32
  );
```

Do not add update or delete grants. The anon key is a public client identifier;
the grants, constraints, and Row Level Security policies above are the security
boundary.

## Verification

1. Run `res://tools/leaderboard_check.tscn` headless. It proves scoring,
   sanitising, idempotency keys, empty-board handling, and that headless gates
   cannot contact the public service.
2. With the project restored and the SQL applied, open the game normally, finish
   a run, choose a public name, and post once.
3. Reopen the leaderboard and confirm the row appears on the correct tier.
4. Disable the network, post another run, restart while still offline, and
   confirm the personal row remains and the outbox stays bounded.
5. Restore the network, restart, and confirm the pending row is inserted once.
6. Attempt `PATCH` and `DELETE` with the anon key. Both must be rejected.

## Trust model and privacy

This is an offline single-player game. No client-side leaderboard can prove a
run was not modified, so the shared board is a community score board, not an
anti-cheat authority. The database blocks malformed writes and duplicate retry
rows; it does not claim server-authoritative play. The only player-entered value
published is the name they explicitly submit. No email, account id, IP address,
or save file is stored in `runs`.
