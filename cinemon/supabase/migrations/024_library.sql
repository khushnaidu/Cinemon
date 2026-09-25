-- The library: every film and show someone has seen, whether or not they
-- posted about it. Adding to it posts nothing: no feed item, no
-- notification, no badge. Logging or reviewing a title adds it too, and
-- everyone's existing logs are copied in below. Others see a library on the
-- profile's Films tab, under the same rules as the rest of the profile
-- (private accounts: followers only; blocks hide it both ways).
-- Run after 023. Idempotent.

create table if not exists public.library (
  user_id          uuid not null references public.profiles(id) on delete cascade,
  film_id          int  not null,
  media_type       text not null check (media_type in ('movie', 'tv')),
  film_title       text not null,
  film_poster_path text,
  film_year        text,
  added_at         timestamptz not null default now(),
  primary key (user_id, film_id, media_type)
);
create index if not exists library_user_added_idx on public.library (user_id, added_at desc);

alter table public.library enable row level security;
drop policy if exists "library readable"   on public.library;
drop policy if exists "library own insert" on public.library;
drop policy if exists "library own delete" on public.library;
create policy "library readable" on public.library for select to authenticated
  using (public.can_see(user_id));
create policy "library own insert" on public.library for insert to authenticated
  with check (auth.uid() = user_id and not public.is_suspended(auth.uid()));
create policy "library own delete" on public.library for delete to authenticated
  using (auth.uid() = user_id);
grant select, insert, delete on public.library to authenticated;

-- ── The count on the profile ─────────────────────────────────
alter table public.profiles add column if not exists library_count int not null default 0;

create or replace function public.sync_library_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set library_count = library_count + 1 where id = new.user_id;
  else
    update public.profiles set library_count = greatest(library_count - 1, 0) where id = old.user_id;
  end if;
  return null;
end $$;
drop trigger if exists library_count_trg on public.library;
create trigger library_count_trg after insert or delete on public.library
  for each row execute function public.sync_library_count();

-- ── Adding to the library strikes it off the watchlist ───────
-- The same as logging it (008).
create or replace function public.strike_watchlist_on_library()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.list_items i
     set watched_at = now()
    from public.lists l
   where l.id = i.list_id
     and l.user_id = new.user_id
     and l.kind = 'watchlist'
     and i.film_id = new.film_id
     and i.media_type = new.media_type
     and i.watched_at is null;
  return null;
end $$;
drop trigger if exists library_strike_watchlist on public.library;
create trigger library_strike_watchlist after insert on public.library
  for each row execute function public.strike_watchlist_on_library();

-- ── Logging a title adds it ──────────────────────────────────
-- Whole titles only: an episode log doesn't mean the show was seen.
create or replace function public.library_from_activity()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.episode_number is null then
    insert into public.library (user_id, film_id, media_type, film_title, film_poster_path, film_year, added_at)
    values (new.user_id, new.film_id, new.media_type, new.film_title, new.film_poster_path, new.film_year, new.created_at)
    on conflict do nothing;
  end if;
  return null;
end $$;
drop trigger if exists activities_to_library on public.activities;
create trigger activities_to_library after insert on public.activities
  for each row execute function public.library_from_activity();

-- ── Everyone's logs so far ───────────────────────────────────
insert into public.library (user_id, film_id, media_type, film_title, film_poster_path, film_year, added_at)
select distinct on (a.user_id, a.film_id, a.media_type)
       a.user_id, a.film_id, a.media_type, a.film_title, a.film_poster_path, a.film_year, a.created_at
  from public.activities a
 where a.episode_number is null
 order by a.user_id, a.film_id, a.media_type, a.created_at
on conflict do nothing;

with t as (select p.id, (select count(*) from public.library l where l.user_id = p.id) n
             from public.profiles p)
update public.profiles p set library_count = t.n
  from t where t.id = p.id and p.library_count is distinct from t.n;
