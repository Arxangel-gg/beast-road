# Matchmaking — the public lobby list

Beast Road offers three ways into a game, in the order most people will use
them: the **local lobby** (games on your own network, found with a UDP beacon,
no server involved), the **public lobby list** (this document), and a
**connect code** pasted by hand.

The public list is one small table in Supabase. It holds one row per game that
is *currently open* and nothing else — no accounts, no history, no chat. A row
is created when somebody hosts, updated every twenty seconds while they wait,
and deleted the moment the pair enters a run. **When nobody is looking for a
game the table is empty**, which is the state it should spend most of its life
in.

## What a row contains

Only what a stranger needs to join, and nothing that identifies a machine or a
person:

| column | what it is |
|---|---|
| `id` | the row's own identifier |
| `code` | the connect code, carrying both addresses and the port |
| `name` | the host's hero class and level, e.g. `Warden · level 9` |
| `players` | 1 while waiting, 2 once a partner has arrived |
| `owner_token` | a secret the host generated; never leaves that machine except to prove it owns this row |
| `created_at` | when it was listed, for ordering and for the age shown in the list |
| `heartbeat` | last time the host said it was still there |

The name is deliberately the hero, not the player: no machine name, no account
name, nothing typed by a person.

## Why the client never writes to the table

The anon key is in the client, which is what an anon key is for — it identifies
the project and grants nothing on its own. What matters is what it can reach.

Anonymous clients have no identity, so any `delete` policy permissive enough to
let a host remove its own row is permissive enough to let anybody remove every
row. So the table takes **no direct writes at all**. It is reached through three
`security definer` functions, each of which requires the token handed back when
the row was created, and read through a view that does not expose that token.

## The SQL

Run this once in the Supabase SQL editor. It is safe to re-run.

```sql
-- The table. No client ever touches it directly.
create table if not exists public.lobbies (
  id          uuid primary key default gen_random_uuid(),
  code        text        not null check (char_length(code) between 8 and 24),
  name        text        not null check (char_length(name) <= 40),
  players     smallint    not null default 1 check (players between 1 and 2),
  owner_token text        not null check (char_length(owner_token) between 16 and 64),
  created_at  timestamptz not null default now(),
  heartbeat   timestamptz not null default now()
);

create index if not exists lobbies_heartbeat_idx on public.lobbies (heartbeat desc);

-- Locked by default. Nothing below grants direct table access to anon; the
-- functions run as the definer and the view is the only way in.
alter table public.lobbies enable row level security;
revoke all on public.lobbies from anon, authenticated;

-- What a browsing client sees: everything except the token, and only rows whose
-- host has spoken recently. The sweep is a read-time filter as well as a
-- delete, so a crashed host disappears from every list within the minute even
-- if nothing has cleaned up yet.
create or replace view public.lobbies_public
with (security_invoker = off) as
  select id,
         code,
         name,
         players,
         created_at,
         extract(epoch from (now() - created_at))::int as age_seconds
    from public.lobbies
   where heartbeat > now() - interval '75 seconds'
   order by created_at desc;

grant select on public.lobbies_public to anon;

-- Sweeps rows nobody has touched. Called from every write so the table cleans
-- itself under exactly the traffic that dirties it, with no scheduler to set up
-- and nothing to go stale when the game is quiet.
create or replace function public.sweep_lobbies()
returns void language sql security definer set search_path = public as $$
  delete from public.lobbies where heartbeat < now() - interval '75 seconds';
$$;

create or replace function public.create_lobby(
  p_code text, p_name text, p_token text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform public.sweep_lobbies();
  -- Bounded so one client cannot fill the table by holding the button down.
  if (select count(*) from public.lobbies) > 500 then
    raise exception 'lobby list is full';
  end if;
  insert into public.lobbies (code, name, owner_token)
       values (p_code, left(p_name, 40), p_token)
    returning id into new_id;
  return new_id;
end $$;

create or replace function public.touch_lobby(
  p_id uuid, p_token text, p_code text, p_players smallint)
returns boolean language plpgsql security definer set search_path = public as $$
declare hit int;
begin
  perform public.sweep_lobbies();
  update public.lobbies
     set heartbeat = now(),
         code      = coalesce(p_code, code),
         players   = least(greatest(coalesce(p_players, players), 1), 2)
   where id = p_id and owner_token = p_token;
  get diagnostics hit = row_count;
  return hit > 0;
end $$;

create or replace function public.delete_lobby(p_id uuid, p_token text)
returns boolean language plpgsql security definer set search_path = public as $$
declare hit int;
begin
  delete from public.lobbies where id = p_id and owner_token = p_token;
  get diagnostics hit = row_count;
  perform public.sweep_lobbies();
  return hit > 0;
end $$;

grant execute on function public.create_lobby(text, text, text) to anon;
grant execute on function public.touch_lobby(uuid, text, text, smallint) to anon;
grant execute on function public.delete_lobby(uuid, text) to anon;
revoke execute on function public.sweep_lobbies() from anon, authenticated;
```

## How the row is removed

Four ways, so no single one has to be reliable:

1. **The run begins.** `GameDirector.start_run` withdraws it. A party that is
   playing is not looking for anybody.
2. **Hosting stops.** `Coop.leave` withdraws it.
3. **The game closes.** `CoopDirectory._exit_tree` withdraws it, best effort.
4. **Nothing at all happens.** The heartbeat lapses, the row stops appearing in
   `lobbies_public` within 75 seconds, and the next write from anybody sweeps it.

## What happens before the SQL is applied

Nothing breaks. Every call fails quietly, the public list stays empty, and the
local lobby and the connect code work exactly as they do now. The game never
blocks on this table and never shows an error about it.
