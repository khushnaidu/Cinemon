-- Lists: the watchlist now (ADR 0001 Phase 3), playlists next (Phase 4), on
-- one schema. Run after 007. Safe to re-run.

-- ── 1. Tables ─────────────────────────────────────────────────
create table if not exists public.lists (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  kind         text not null check (kind in ('watchlist', 'playlist')),
  title        text check (char_length(title) between 1 and 80),
  description  text check (char_length(description) <= 500),
  visibility   text not null default 'public'
               check (visibility in ('public', 'friends', 'private')),
  item_count   int  not null default 0,
  save_count   int  not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint playlist_has_title check (kind = 'watchlist' or title is not null)
);
create unique index if not exists lists_one_watchlist
  on public.lists (user_id) where kind = 'watchlist';
create index if not exists lists_user_idx on public.lists (user_id, updated_at desc);

-- Film metadata is snapshotted, like activities: a list page is one query,
-- never a TMDB call per row.
create table if not exists public.list_items (
  list_id            uuid not null references public.lists(id) on delete cascade,
  film_id            int  not null,
  media_type         text not null check (media_type in ('movie', 'tv')),
  film_title         text not null,
  film_poster_path   text,
  film_backdrop_path text,
  film_year          text,
  -- Fractional index: append is max + 1, a drag between a and b is (a+b)/2.
  -- Left null by the client on insert; the trigger below appends.
  position           double precision not null,
  note               text check (char_length(note) <= 280),
  -- Watchlist only: struck off. Kept rather than deleted, for undo and for
  -- "watched from my watchlist".
  watched_at         timestamptz,
  added_at           timestamptz not null default now(),
  primary key (list_id, film_id, media_type)
);
create index if not exists list_items_order_idx on public.list_items (list_id, position);
create index if not exists list_items_film_idx  on public.list_items (film_id, media_type);

-- Saving someone else's playlist (Phase 4).
create table if not exists public.list_saves (
  list_id    uuid not null references public.lists(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
create index if not exists list_saves_user_idx on public.list_saves (user_id, created_at desc);

-- ── 2. Who can see a list ─────────────────────────────────────
-- The owner always. Anyone else only if neither has blocked the other, and
-- the list is public, or it's friends-only and they're friends. Security
-- definer so it can read friendships and blocks the viewer can't.
create or replace function public.can_view_list(owner uuid, vis text)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select owner = auth.uid()
      or (
        not public.is_blocked_pair(auth.uid(), owner)
        and (
          vis = 'public'
          or (vis = 'friends' and exists (
                select 1 from public.friendships f
                 where f.status = 'accepted'
                   and ((f.sender_id = auth.uid() and f.receiver_id = owner)
                     or (f.sender_id = owner and f.receiver_id = auth.uid()))))
        )
      );
$$;

create or replace function public.can_view_list_id(target uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.lists l
     where l.id = target and public.can_view_list(l.user_id, l.visibility)
  );
$$;

create or replace function public.owns_list(target uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (select 1 from public.lists where id = target and user_id = auth.uid());
$$;

-- ── 3. RLS ────────────────────────────────────────────────────
alter table public.lists      enable row level security;
alter table public.list_items enable row level security;
alter table public.list_saves enable row level security;

drop policy if exists "lists readable"   on public.lists;
drop policy if exists "lists own insert" on public.lists;
drop policy if exists "lists own update" on public.lists;
drop policy if exists "lists own delete" on public.lists;
create policy "lists readable" on public.lists for select to authenticated
  using (public.can_view_list(user_id, visibility));
-- Watchlists are made by the profile trigger, never by the client.
create policy "lists own insert" on public.lists for insert to authenticated
  with check (auth.uid() = user_id and kind = 'playlist');
create policy "lists own update" on public.lists for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
-- And a watchlist can't be deleted, only emptied.
create policy "lists own delete" on public.lists for delete to authenticated
  using (auth.uid() = user_id and kind = 'playlist');

drop policy if exists "list items readable" on public.list_items;
drop policy if exists "list items own write" on public.list_items;
create policy "list items readable" on public.list_items for select to authenticated
  using (public.can_view_list_id(list_id));
create policy "list items own write" on public.list_items for all to authenticated
  using (public.owns_list(list_id)) with check (public.owns_list(list_id));

drop policy if exists "list saves readable"   on public.list_saves;
drop policy if exists "list saves own insert" on public.list_saves;
drop policy if exists "list saves own delete" on public.list_saves;
create policy "list saves readable" on public.list_saves for select to authenticated
  using (auth.uid() = user_id or public.owns_list(list_id));
create policy "list saves own insert" on public.list_saves for insert to authenticated
  with check (auth.uid() = user_id and public.can_view_list_id(list_id)
              and not public.owns_list(list_id));
create policy "list saves own delete" on public.list_saves for delete to authenticated
  using (auth.uid() = user_id);

-- ── 4. Triggers ───────────────────────────────────────────────
-- A list never changes owner or kind, and its counters are the server's.
create or replace function public.guard_list_update()
returns trigger language plpgsql as $$
begin
  new.user_id    := old.user_id;
  new.kind       := old.kind;
  new.created_at := old.created_at;
  if current_user in ('authenticated', 'anon') then
    new.item_count := old.item_count;
    new.save_count := old.save_count;
  end if;
  return new;
end $$;

drop trigger if exists lists_guard_update on public.lists;
create trigger lists_guard_update
  before update on public.lists
  for each row execute function public.guard_list_update();

-- Append by default: a null position goes after the last item.
create or replace function public.list_item_position()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.position is null then
    select coalesce(max(position), 0) + 1 into new.position
      from public.list_items where list_id = new.list_id;
  end if;
  return new;
end $$;

drop trigger if exists list_items_position on public.list_items;
create trigger list_items_position
  before insert on public.list_items
  for each row execute function public.list_item_position();

-- item_count, and updated_at so profiles order lists by recent activity.
create or replace function public.sync_list_items()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.lists set item_count = item_count + 1, updated_at = now()
     where id = new.list_id;
  elsif tg_op = 'DELETE' then
    update public.lists set item_count = greatest(item_count - 1, 0), updated_at = now()
     where id = old.list_id;
  else
    update public.lists set updated_at = now() where id = new.list_id;
  end if;
  return null;
end $$;

drop trigger if exists list_items_sync on public.list_items;
create trigger list_items_sync
  after insert or update or delete on public.list_items
  for each row execute function public.sync_list_items();

create or replace function public.sync_list_saves()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.lists set save_count = save_count + 1 where id = new.list_id;
  else
    update public.lists set save_count = greatest(save_count - 1, 0) where id = old.list_id;
  end if;
  return null;
end $$;

drop trigger if exists list_saves_sync on public.list_saves;
create trigger list_saves_sync
  after insert or delete on public.list_saves
  for each row execute function public.sync_list_saves();

-- Everyone has a watchlist from the moment they have a profile, so the
-- client never handles a missing one.
create or replace function public.create_watchlist()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.lists (user_id, kind) values (new.id, 'watchlist')
  on conflict do nothing;
  return null;
end $$;

drop trigger if exists profiles_create_watchlist on public.profiles;
create trigger profiles_create_watchlist
  after insert on public.profiles
  for each row execute function public.create_watchlist();

insert into public.lists (user_id, kind)
select p.id, 'watchlist' from public.profiles p
 where not exists (select 1 from public.lists l where l.user_id = p.id and l.kind = 'watchlist');

-- Logging a title strikes it off your watchlist, wherever the log came
-- from. An episode doesn't: watching one episode isn't watching the show.
create or replace function public.strike_watchlist_on_log()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.episode_number is null then
    update public.list_items i
       set watched_at = now()
      from public.lists l
     where l.id = i.list_id
       and l.user_id = new.user_id
       and l.kind = 'watchlist'
       and i.film_id = new.film_id
       and i.media_type = new.media_type
       and i.watched_at is null;
  end if;
  return null;
end $$;

drop trigger if exists activities_strike_watchlist on public.activities;
create trigger activities_strike_watchlist
  after insert on public.activities
  for each row execute function public.strike_watchlist_on_log();
