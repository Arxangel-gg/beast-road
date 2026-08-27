-- Beast Road matchmaking, rooms and friends.
--
-- ONE SCRIPT, AND IT IS SAFE TO RE-RUN. Paste the whole file into the Supabase
-- SQL editor. It produces the finished state from any starting point, including
-- an empty project and a project part-way through an earlier version.
--
-- This replaced a sequence of blocks that had to be applied in order and never
-- again - a changelog wearing a script's clothes. It broke the moment anybody
-- ran it twice: `create or replace view` refuses to drop or reorder a column,
-- so an older block against a newer database fails with "cannot drop columns
-- from view", and nothing about that error points at the real cause.

-- ================================================================ tables ====

create table if not exists public.lobbies (
  id          uuid primary key default gen_random_uuid(),
  code        text        not null check (char_length(code) between 6 and 24),
  name        text        not null check (char_length(name) <= 40),
  players     smallint    not null default 1 check (players between 1 and 4),
  owner_token text        not null check (char_length(owner_token) between 16 and 64),
  created_at  timestamptz not null default now(),
  heartbeat   timestamptz not null default now()
);

-- Added after the first release, so it is an alter rather than part of the
-- create above: a database that already exists must reach the same shape.
alter table public.lobbies add column if not exists password text;

-- **`create table if not exists` does nothing to a table that already exists**,
-- including its constraints - so a check written when the rules were different
-- is still enforcing the old rules. Two of them were, and both broke real play
-- rather than only this script:
--
--   * `code` was 8-24 characters, from when a lobby always carried an address
--     code. A WebRTC room code is six, so publishing a room to the lobby list
--     failed on the constraint.
--   * `players` was 1-2, from when co-op meant two people. A party of three or
--     four could not update its own headcount.
--
-- Restated rather than assumed, so the table matches this file whatever it was
-- before. Postgres names an inline check `<table>_<column>_check`.
alter table public.lobbies drop constraint if exists lobbies_code_check;
alter table public.lobbies add  constraint lobbies_code_check
  check (char_length(code) between 6 and 24);

alter table public.lobbies drop constraint if exists lobbies_players_check;
alter table public.lobbies add  constraint lobbies_players_check
  check (players between 1 and 4);

alter table public.lobbies drop constraint if exists lobbies_name_check;
alter table public.lobbies add  constraint lobbies_name_check
  check (char_length(name) <= 40);

create index if not exists lobbies_heartbeat_idx on public.lobbies (heartbeat desc);

create table if not exists public.rooms (
  id          uuid primary key default gen_random_uuid(),
  code        text        not null unique check (code ~ '^[0-9A-HJKMNP-TV-Z]{6}$'),
  host_token  text        not null,
  guest_token text,
  created_at  timestamptz not null default now(),
  -- Last time either peer was heard from. The sweep runs on *this*, not on
  -- created_at: a host waiting for a friend to read a code out of a chat window
  -- is idle, not stale, and deleting the room out from under them told the
  -- friend "no game is waiting on that code" while the host still said it was
  -- hosting.
  seen_at     timestamptz not null default now()
);

-- Migration for a database created before seen_at existed.
alter table public.rooms add column if not exists
  seen_at timestamptz not null default now();

-- **Rebuilt for four, and dropped rather than migrated.** Both of these tables
-- hold handshakes in flight and nothing else - the sweep deletes everything in
-- them after two minutes anyway - so recreating them costs at most one
-- connection attempt and avoids a column migration that has to be right first
-- time. Anything joining while this runs simply tries again.
drop table if exists public.signals cascade;

create table public.signals (
  seq        bigserial primary key,
  room       uuid        not null references public.rooms(id) on delete cascade,
  -- Party slots, 1 to 4, rather than 'host' and 'guest'. With one guest those
  -- two words were a complete description of the room; with three they are not,
  -- and every note has to say which peer it is for or three simultaneous
  -- handshakes read each other's offers.
  sender     int         not null check (sender between 1 and 4),
  recipient  int         not null check (recipient between 1 and 4),
  kind       text        not null check (kind in ('offer', 'answer', 'candidate')),
  payload    jsonb       not null,
  created_at timestamptz not null default now()
);

create index if not exists signals_for_peer
  on public.signals (room, recipient, seq);

-- Who is in a room, and in which seat.
--
-- A column per guest would have worked and would have been wrong: three of them
-- named guest2/guest3/guest4, three near-identical branches in every function,
-- and a fourth player meaning another migration. A row per member makes "the
-- lowest free seat" a query rather than a case statement.
create table if not exists public.room_members (
  room    uuid        not null references public.rooms(id) on delete cascade,
  slot    int         not null check (slot between 1 and 4),
  token   text        not null,
  seen_at timestamptz not null default now(),
  primary key (room, slot)
);

create index if not exists room_members_by_token
  on public.room_members (room, token);

create index if not exists signals_room_idx on public.signals (room, seq);

create table if not exists public.presence (
  play_code  text primary key check (play_code ~ '^[0-9A-HJKMNP-TV-Z]{6}$'),
  name       text not null,
  room_code  text,
  heartbeat  timestamptz not null default now()
);

-- Locked by default. Nothing below grants direct table access to anon: the
-- functions run as the definer, and the view is the only way in.
alter table public.lobbies  enable row level security;
alter table public.rooms    enable row level security;
alter table public.signals  enable row level security;
alter table public.presence enable row level security;
revoke all on public.lobbies, public.rooms, public.signals, public.presence
  from anon, authenticated;

-- ================================================================= view ====

-- Dropped rather than replaced. `create or replace view` can only APPEND
-- columns; it refuses to insert or reorder one, because anything selecting by
-- position would silently change meaning. Grants belong to the view, so the
-- grant below is part of the change rather than an afterthought.
drop view if exists public.lobbies_public;

create view public.lobbies_public
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

-- ============================================================ functions ====

-- Signatures that changed since an earlier version. `create or replace
-- function` matches on the argument list, so a new parameter defines a SECOND
-- function beside the old one and PostgREST is left choosing between two
-- candidates - which fails at the call site, long after the SQL appeared to
-- succeed.
drop function if exists public.create_lobby(text, text, text);

create or replace function public.sweep_lobbies()
returns void language sql security definer set search_path = public as $$
  delete from public.lobbies where heartbeat < now() - interval '75 seconds';
$$;

create or replace function public.create_lobby(
  p_code text, p_name text, p_token text, p_password text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform public.sweep_lobbies();
  -- Bounded so one client cannot fill the table by holding the button down.
  if (select count(*) from public.lobbies) > 500 then
    raise exception 'lobby list is full';
  end if;
  insert into public.lobbies (code, name, owner_token, password)
       values (p_code, left(p_name, 40), p_token,
               nullif(btrim(coalesce(p_password, '')), ''))
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
         players   = least(greatest(coalesce(p_players, players), 1), 4)
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

-- Checked in the database, never in the client: a client-side check is a
-- suggestion, because anybody can call the API directly.
create or replace function public.lobby_password_ok(p_code text, p_password text)
returns boolean language sql security definer set search_path = public as $$
  select coalesce(
    (select password is null or password = p_password
       from public.lobbies where code = p_code limit 1),
    false);
$$;

-- Finds a party to join, or says there is none.
--
-- The seat is taken inside the same statement that finds it. Two people
-- pressing Find at the same moment must not both be handed the last seat in the
-- same lobby, and a select-then-update from the client would do exactly that.
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
      -- Nearly-full parties are completed before new ones are started, and
      -- among equals whoever has waited longest gets company first.
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

-- Rooms, which exist only for as long as a WebRTC handshake takes.
create or replace function public.sweep_rooms()
returns void language sql security definer set search_path = public as $$
  delete from public.rooms where seen_at < now() - interval '2 minutes';
$$;

create or replace function public.open_room(p_code text, p_token text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid;
begin
  perform public.sweep_rooms();
  delete from public.rooms
   where code = p_code and seen_at < now() - interval '2 minutes';
  insert into public.rooms (code, host_token) values (p_code, p_token)
    returning id into new_id;
  -- The host takes seat one, in the same table as everybody else. Keeping the
  -- host in `rooms.host_token` *and* in the roster would be two places to ask
  -- who slot one is, and they would disagree eventually.
  insert into public.room_members (room, slot, token) values (new_id, 1, p_token);
  return new_id;
exception when unique_violation then
  return null;
end $$;

-- Returns {"room": uuid, "slot": int}, or null when there is no seat.
--
-- The slot has to come back with the room: a guest cannot pick its own seat
-- without racing every other guest, and it cannot address a single note until
-- it knows which seat it got.
drop function if exists public.enter_room(text, text);
create or replace function public.enter_room(p_code text, p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare found uuid; taken int; seat int;
begin
  perform public.sweep_rooms();
  select id into found from public.rooms where code = p_code
    for update;
  if found is null then
    return null;
  end if;
  -- Already in? Hand back the same seat. A retry after a lost reply must not
  -- consume a second one, which is how a party of two filled a room of four.
  select slot into seat from public.room_members
   where room = found and token = p_token;
  if seat is not null then
    update public.room_members set seen_at = now()
     where room = found and slot = seat;
    return jsonb_build_object('room', found, 'slot', seat);
  end if;
  -- The lowest free seat, decided here rather than by the caller, so two guests
  -- arriving in the same millisecond cannot both be told seat two.
  select min(candidate) into seat
    from generate_series(2, 4) as candidate
   where not exists (
     select 1 from public.room_members m
      where m.room = found and m.slot = candidate);
  if seat is null then
    return null;
  end if;
  insert into public.room_members (room, slot, token) values (found, seat, p_token);
  update public.rooms set seen_at = now() where id = found;
  return jsonb_build_object('room', found, 'slot', seat);
exception when unique_violation then
  -- Lost the race for that seat. The caller retries and takes the next one.
  return null;
end $$;

-- One note, from the caller's seat to a named one.
drop function if exists public.post_signal(uuid, text, text, jsonb);
create or replace function public.post_signal(
  p_room uuid, p_token text, p_kind text, p_payload jsonb, p_to int)
returns bigint language plpgsql security definer set search_path = public as $$
declare mine int; new_seq bigint;
begin
  select slot into mine from public.room_members
   where room = p_room and token = p_token;
  if mine is null then
    return null;
  end if;
  if p_to is null or p_to < 1 or p_to > 4 or p_to = mine then
    return null;
  end if;
  -- A handshake is a dozen messages per pair, so four players is at most a few
  -- dozen. Past that it is either broken or not a handshake.
  if (select count(*) from public.signals where room = p_room) > 600 then
    return null;
  end if;
  insert into public.signals (room, sender, recipient, kind, payload)
       values (p_room, mine, p_to, p_kind, p_payload)
    returning seq into new_seq;
  return new_seq;
end $$;

-- Everything addressed to the caller, oldest first.
drop function if exists public.read_signals(uuid, text, bigint);
create or replace function public.read_signals(
  p_room uuid, p_token text, p_after bigint)
returns setof public.signals language plpgsql security definer
set search_path = public as $$
declare mine int;
begin
  select slot into mine from public.room_members
   where room = p_room and token = p_token;
  if mine is null then
    raise exception 'room % is not open', p_room using errcode = 'no_data_found';
  end if;
  -- A poll is a heartbeat, for the room and for this seat. A member that stops
  -- reading has gone, and the seat should come back.
  update public.rooms set seen_at = now() where id = p_room;
  update public.room_members set seen_at = now()
   where room = p_room and slot = mine;
  -- Addressed, not broadcast. With three guests handshaking at once, a peer
  -- reading everybody's notes would apply two other people's offers.
  return query
    select * from public.signals
     where room = p_room and recipient = mine and seq > coalesce(p_after, 0)
     order by seq;
end $$;

create or replace function public.close_room(p_room uuid, p_token text)
returns boolean language plpgsql security definer set search_path = public as $$
declare hit int;
begin
  -- **Only the host ends a room.** Anybody else leaving frees their seat, so
  -- somebody can take it - and so a guest who gives up does not end a game
  -- three other people are still in.
  delete from public.rooms where id = p_room and host_token = p_token;
  get diagnostics hit = row_count;
  if hit > 0 then
    perform public.sweep_rooms();
    return true;
  end if;
  delete from public.room_members
   where room = p_room and token = p_token and slot > 1;
  get diagnostics hit = row_count;
  if hit > 0 then
    update public.rooms set seen_at = now() where id = p_room;
  end if;
  perform public.sweep_rooms();
  return hit > 0;
end $$;

-- Presence: one row per play code, holding a heartbeat and nothing worth
-- stealing. There are no accounts; a play code is an address somebody chose to
-- share, like a phone number.
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
-- player online; with it you can only ask about codes you were given.
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

-- ================================================================ grants ====

grant execute on function public.create_lobby(text, text, text, text)    to anon;
grant execute on function public.touch_lobby(uuid, text, text, smallint) to anon;
grant execute on function public.delete_lobby(uuid, text)                to anon;
grant execute on function public.lobby_password_ok(text, text)           to anon;
grant execute on function public.find_party(smallint)                    to anon;
grant execute on function public.release_seat(text)                      to anon;
grant execute on function public.open_room(text, text)                   to anon;
grant execute on function public.enter_room(text, text)                  to anon;
grant execute on function public.post_signal(uuid, text, text, jsonb)    to anon;
grant execute on function public.read_signals(uuid, text, bigint)        to anon;
grant execute on function public.post_signal(uuid, text, text, jsonb, int) to anon;
grant execute on function public.enter_room(text, text)                  to anon;
grant execute on function public.close_room(uuid, text)                  to anon;
grant execute on function public.announce_presence(text, text, text)     to anon;
grant execute on function public.friends_online(text[])                  to anon;
grant execute on function public.forget_presence(text)                   to anon;

-- The sweeps are internal. Nothing outside these functions may call them.
revoke execute on function public.sweep_lobbies() from anon, authenticated;
revoke execute on function public.sweep_rooms()   from anon, authenticated;
