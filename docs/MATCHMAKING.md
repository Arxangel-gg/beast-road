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

---

# Rooms and signalling — how the web build plays

The lobby table above answers *"who is open right now"*. This second pair of
tables answers *"how do these two machines reach each other"*, and it is what
makes co-op work **in a browser** and **through a home router nobody
configured**.

Two peers cannot start a WebRTC connection without something in the middle to
pass notes: each has to tell the other what it looks like from the outside
(an SDP offer or answer) and which routes might work (ICE candidates). That is
all a signalling server does, and it is out of the picture the moment the two
are talking directly. Here it is a table, polled over the same REST client the
lobby list uses — a handshake is a handful of messages over a couple of seconds,
so polling costs nothing and avoids a second protocol that would have to behave
identically inside a browser and outside one.

**A room is deleted the instant both sides connect.** Nothing about a finished
handshake is worth keeping.

## The SQL

Run this after the lobby SQL above. Safe to re-run.

```sql
-- A room is two players trying to find each other, and nothing else. It lives
-- for as long as a handshake takes.
create table if not exists public.rooms (
  id          uuid primary key default gen_random_uuid(),
  code        text        not null unique check (code ~ '^[0-9A-HJKMNP-TV-Z]{6}$'),
  host_token  text        not null,
  guest_token text,
  created_at  timestamptz not null default now()
);

-- One note passed between them. `seq` is what lets a reader ask for "anything
-- after what I already have" instead of re-reading the whole exchange.
create table if not exists public.signals (
  seq        bigserial primary key,
  room       uuid        not null references public.rooms(id) on delete cascade,
  sender     text        not null,
  kind       text        not null check (kind in ('offer', 'answer', 'candidate')),
  payload    jsonb       not null,
  created_at timestamptz not null default now()
);

create index if not exists signals_room_idx on public.signals (room, seq);

alter table public.rooms   enable row level security;
alter table public.signals enable row level security;
revoke all on public.rooms, public.signals from anon, authenticated;

-- Rooms nobody finished with. Two minutes is far longer than any handshake and
-- far shorter than a table worth worrying about; the cascade takes the notes
-- with the room.
create or replace function public.sweep_rooms()
returns void language sql security definer set search_path = public as $$
  delete from public.rooms where created_at < now() - interval '2 minutes';
$$;

create or replace function public.open_room(p_code text, p_token text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform public.sweep_rooms();
  -- A code is six characters, so collisions happen. Taking the code back from a
  -- room that is already stale is correct; taking it from a live one is not.
  delete from public.rooms
   where code = p_code and created_at < now() - interval '2 minutes';
  insert into public.rooms (code, host_token) values (p_code, p_token)
    returning id into new_id;
  return new_id;
exception when unique_violation then
  return null;
end $$;

create or replace function public.enter_room(p_code text, p_token text)
returns uuid language plpgsql security definer set search_path = public as $$
declare found uuid;
begin
  perform public.sweep_rooms();
  -- First guest wins, and a second one is refused rather than quietly joining a
  -- handshake already in progress.
  update public.rooms set guest_token = p_token
   where code = p_code and guest_token is null
   returning id into found;
  return found;
end $$;

create or replace function public.post_signal(
  p_room uuid, p_token text, p_kind text, p_payload jsonb)
returns bigint language plpgsql security definer set search_path = public as $$
declare who text; new_seq bigint;
begin
  -- The token says which side this is. A caller that owns neither is not in
  -- this room and cannot write to it.
  select case when host_token  = p_token then 'host'
              when guest_token = p_token then 'guest' end
    into who from public.rooms where id = p_room;
  if who is null then
    return null;
  end if;
  -- Bounded: a handshake is a dozen messages, and anything past that is either
  -- broken or not a handshake.
  if (select count(*) from public.signals where room = p_room) > 200 then
    return null;
  end if;
  insert into public.signals (room, sender, kind, payload)
       values (p_room, who, p_kind, p_payload)
    returning seq into new_seq;
  return new_seq;
end $$;

create or replace function public.read_signals(
  p_room uuid, p_token text, p_after bigint)
returns setof public.signals language plpgsql security definer
set search_path = public as $$
declare who text;
begin
  select case when host_token  = p_token then 'host'
              when guest_token = p_token then 'guest' end
    into who from public.rooms where id = p_room;
  if who is null then
    return;
  end if;
  -- Only the other side's notes. Reading your own back would have each peer
  -- applying its own offer.
  return query
    select * from public.signals
     where room = p_room and seq > coalesce(p_after, 0) and sender <> who
     order by seq;
end $$;

create or replace function public.close_room(p_room uuid, p_token text)
returns boolean language plpgsql security definer set search_path = public as $$
declare hit int;
begin
  delete from public.rooms
   where id = p_room and (host_token = p_token or guest_token = p_token);
  get diagnostics hit = row_count;
  perform public.sweep_rooms();
  return hit > 0;
end $$;

grant execute on function public.open_room(text, text)                   to anon;
grant execute on function public.enter_room(text, text)                  to anon;
grant execute on function public.post_signal(uuid, text, text, jsonb)    to anon;
grant execute on function public.read_signals(uuid, text, bigint)        to anon;
grant execute on function public.close_room(uuid, text)                  to anon;
revoke execute on function public.sweep_rooms() from anon, authenticated;
```

## What a room does not contain

No IP address, no port, no machine name. The SDP and ICE payloads describe how
to reach a peer and are visible only to the other side of that room, for the few
seconds the handshake lasts, and go with the room when it is deleted.

## STUN, and the case this does not cover

Connections are negotiated against public STUN servers, which is enough for the
great majority of home routers. It is **not** enough for a symmetric NAT at both
ends at once — that needs a TURN relay, which is a server that carries the
traffic rather than just the introductions, and therefore a running cost. If
that turns out to matter in practice the place to add it is `ICE_SERVERS` in
`coop_webrtc.gd`; nothing else has to change.

---

# Passwords, matchmaking and friends

Everything above shipped with v0.4.66-70. This section is the v0.4.73 additions,
and like the rest it is safe to re-run.

```sql
-- ---------------------------------------------------------------- passwords --
-- A lobby may be private. The password is never returned by the view - only
-- whether there is one - so a browsing client can draw a padlock without ever
-- being told what opens it.
alter table public.lobbies add column if not exists password text;

create or replace view public.lobbies_public
with (security_invoker = off) as
  select id,
         code,
         name,
         players,
         (password is not null) as locked,
         created_at,
         extract(epoch from (now() - created_at))::int as age_seconds
    from public.lobbies
   where heartbeat > now() - interval '75 seconds'
   order by created_at desc;

grant select on public.lobbies_public to anon;

create or replace function public.create_lobby(
  p_code text, p_name text, p_token text, p_password text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform public.sweep_lobbies();
  if (select count(*) from public.lobbies) > 500 then
    raise exception 'lobby list is full';
  end if;
  insert into public.lobbies (code, name, owner_token, password)
       values (p_code, left(p_name, 40), p_token,
               nullif(btrim(coalesce(p_password, '')), ''))
    returning id into new_id;
  return new_id;
end $$;

-- Checked in the database, never in the client. A client-side check is a
-- suggestion: anybody can call the API directly.
create or replace function public.lobby_password_ok(p_code text, p_password text)
returns boolean language sql security definer set search_path = public as $$
  select coalesce(
    (select password is null or password = p_password
       from public.lobbies where code = p_code limit 1),
    false);
$$;

-- ------------------------------------------------------------- matchmaking --
-- Finds a party to join, or says there is none.
--
-- **The seat is taken inside the same statement that finds it.** Two people
-- pressing Find at the same moment must not both be handed the last seat in the
-- same lobby, and that is exactly what a select-then-update would do.
create or replace function public.find_party(p_max smallint default 4)
returns text language plpgsql security definer set search_path = public as $$
declare found text;
begin
  perform public.sweep_lobbies();
  update public.lobbies
     set players = players + 1
   where id = (
     select id from public.lobbies
      where players < p_max
        and password is null
        and heartbeat > now() - interval '75 seconds'
      -- Oldest first: whoever has been waiting longest gets company, and a
      -- party that is nearly full is completed before a new one is started.
      order by players desc, created_at asc
      limit 1
      for update skip locked)
   returning code into found;
  return found;
end $$;

-- A searcher that gives up, or whose join fails, must give the seat back or the
-- lobby slowly fills with people who never arrived.
create or replace function public.release_seat(p_code text)
returns void language sql security definer set search_path = public as $$
  update public.lobbies set players = greatest(players - 1, 1) where code = p_code;
$$;

grant execute on function public.create_lobby(text, text, text, text) to anon;
grant execute on function public.lobby_password_ok(text, text)        to anon;
grant execute on function public.find_party(smallint)                 to anon;
grant execute on function public.release_seat(text)                   to anon;

-- ---------------------------------------------------------------- friends ---
-- No accounts, so a "friend" is a code somebody chose to share, and the only
-- thing stored is whether that code is online right now. There is nothing here
-- worth stealing: a row says "this play code was seen at this time", which is
-- exactly what a friend already knows.
create table if not exists public.presence (
  play_code  text primary key check (play_code ~ '^[0-9A-HJKMNP-TV-Z]{6}$'),
  name       text not null,
  room_code  text,
  heartbeat  timestamptz not null default now()
);

alter table public.presence enable row level security;
revoke all on public.presence from anon, authenticated;

create or replace function public.announce_presence(
  p_play_code text, p_name text, p_room text)
returns void language sql security definer set search_path = public as $$
  delete from public.presence where heartbeat < now() - interval '120 seconds';
  insert into public.presence (play_code, name, room_code, heartbeat)
       values (p_play_code, left(p_name, 40), p_room, now())
  on conflict (play_code)
    do update set name = excluded.name,
                  room_code = excluded.room_code,
                  heartbeat = now();
$$;

-- Asked about by code, never listed. Without this you could enumerate every
-- player who is online; with it you can only ask about codes you were given.
create or replace function public.friends_online(p_codes text[])
returns table(play_code text, name text, room_code text)
language sql security definer set search_path = public as $$
  select p.play_code, p.name, p.room_code
    from public.presence p
   where p.play_code = any(p_codes)
     and p.heartbeat > now() - interval '120 seconds';
$$;

create or replace function public.forget_presence(p_play_code text)
returns void language sql security definer set search_path = public as $$
  delete from public.presence where play_code = p_play_code;
$$;

grant execute on function public.announce_presence(text, text, text) to anon;
grant execute on function public.friends_online(text[])              to anon;
grant execute on function public.forget_presence(text)               to anon;
```

## Why a friends list has no accounts

Signing in would mean holding passwords, resetting them, and storing something
worth stealing — for a game whose entire social feature is "let me play with the
person I am already talking to".

So each player gets a **play code**: six characters, generated once, kept in
their save. You give it to a friend the way you would give them a phone number.
The only thing the service ever stores against it is a heartbeat and, if they
are hosting, the room they are in — so a friends list is "which of these codes
answered in the last two minutes", and a row leaks nothing its owner did not
hand out.

Presence is asked about **by code and never listed**, which is the difference
between looking up a friend and enumerating every player online.
