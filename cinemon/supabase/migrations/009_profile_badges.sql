-- Badges are awarded by the database (ADR 0001 Phase 5). Run after 008.
-- Safe to re-run.
--
-- The app used to decide badges itself and write them into
-- profiles.badge_ids, so anyone could award themselves anything, and a
-- review posted from another device never counted. Now triggers on the rows
-- that earn a badge award it, with the date, and the client only reads.
--
-- profiles.badge_ids is still kept in step, because older builds read it.

-- ── 1. Inputs the rules need ──────────────────────────────────
-- Night Owl and Binge Watcher are about the poster's own clock, which the
-- server doesn't know. The app reports its UTC offset ('+09:00') each launch,
-- which follows daylight saving closely enough for a badge; an IANA name
-- works too. Until it has, UTC.
alter table public.profiles add column if not exists time_zone text;

-- Genre badges need the genres of what was reviewed. The app sends TMDB's
-- genre ids with each log; older rows have none and simply don't count.
alter table public.activities add column if not exists genre_ids int[] not null default '{}';
create index if not exists activities_genre_idx
  on public.activities using gin (genre_ids) where activity_type = 'reviewed';

-- A bad zone name must never fail someone's post, so it falls back to UTC.
create or replace function public.local_time(ts timestamptz, tz text)
returns timestamp
language plpgsql
stable
as $$
begin
  -- As an interval, an offset keeps its ISO sign; as a zone name, '+09:00'
  -- would be read POSIX-style and land 18 hours out.
  if tz ~ '^[+-][0-9]{2}:[0-9]{2}$' then
    return ts at time zone tz::interval;
  end if;
  return ts at time zone coalesce(nullif(tz, ''), 'UTC');
exception when others then
  return ts at time zone 'UTC';
end $$;

-- ── 2. Earned badges ──────────────────────────────────────────
create table if not exists public.user_badges (
  user_id   uuid not null references public.profiles(id) on delete cascade,
  badge_id  text not null check (char_length(badge_id) between 1 and 40),
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);
create index if not exists user_badges_user_idx on public.user_badges (user_id, earned_at desc);

alter table public.user_badges enable row level security;

-- Anyone can see what anyone earned, blocks aside. Nobody writes: there are
-- no insert, update or delete policies, only the security definer below.
drop policy if exists "user badges readable" on public.user_badges;
create policy "user badges readable" on public.user_badges for select to authenticated
  using (not public.is_blocked_pair(auth.uid(), user_id));

-- The one way a badge is given. Returns whether it was new.
create or replace function public.award_badge(uid uuid, badge text, at timestamptz default now())
returns boolean
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.user_badges (user_id, badge_id, earned_at)
  values (uid, badge, at)
  on conflict do nothing;
  if not found then
    return false;
  end if;
  update public.profiles
     set badge_ids = array_append(badge_ids, badge)
   where id = uid and not (badge = any(badge_ids));
  return true;
end $$;

revoke all on function public.award_badge(uuid, text, timestamptz) from public, anon, authenticated;

-- The client can't write badge_ids any more. Quietly kept rather than
-- refused, so an older build that still tries doesn't fail the rest of its
-- profile save.
create or replace function public.guard_profile_badges()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    new.badge_ids := old.badge_ids;
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_badges on public.profiles;
create trigger profiles_guard_badges
  before update on public.profiles
  for each row execute function public.guard_profile_badges();

-- ── 3. Rules ──────────────────────────────────────────────────
-- Reviews: milestones, Night Owl, Binge Watcher and the genre badges. Fires
-- on a new review and on a log that's upgraded to one.
create or replace function public.award_review_badges()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  n         int;
  tz        text;
  local_now timestamp;
  g         record;
begin
  if new.activity_type <> 'reviewed' then
    return null;
  end if;
  if tg_op = 'UPDATE' and old.activity_type = 'reviewed' then
    return null;
  end if;

  select count(*) into n from public.activities
   where user_id = new.user_id and activity_type = 'reviewed';
  if n >= 1   then perform public.award_badge(new.user_id, 'first_review'); end if;
  if n >= 10  then perform public.award_badge(new.user_id, 'reviewer_10');  end if;
  if n >= 25  then perform public.award_badge(new.user_id, 'reviewer_25');  end if;
  if n >= 50  then perform public.award_badge(new.user_id, 'reviewer_50');  end if;
  if n >= 100 then perform public.award_badge(new.user_id, 'reviewer_100'); end if;

  select time_zone into tz from public.profiles where id = new.user_id;
  local_now := public.local_time(now(), tz);

  -- Midnight to 4am, their time.
  if extract(hour from local_now) < 4 then
    perform public.award_badge(new.user_id, 'night_owl');
  end if;

  select count(*) into n from public.activities
   where user_id = new.user_id
     and activity_type = 'reviewed'
     and created_at > now() - interval '2 days'
     and public.local_time(created_at, tz)::date = local_now::date;
  if n >= 3 then
    perform public.award_badge(new.user_id, 'binge_watcher');
  end if;

  if 27 = any(new.genre_ids) then
    perform public.award_badge(new.user_id, 'horror_fan');
  end if;
  for g in select * from (values
             (35,    'comedy_lover'),
             (28,    'action_hero'),
             (10749, 'romantic_soul')) as t(genre, badge)
  loop
    if g.genre = any(new.genre_ids) then
      select count(*) into n from public.activities
       where user_id = new.user_id
         and activity_type = 'reviewed'
         and genre_ids @> array[g.genre];
      if n >= 5 then
        perform public.award_badge(new.user_id, g.badge);
      end if;
    end if;
  end loop;

  return null;
end $$;

drop trigger if exists activities_award_badges on public.activities;
create trigger activities_award_badges
  after insert or update of activity_type on public.activities
  for each row execute function public.award_review_badges();

-- Lists: Curator for a first public playlist, Tastemaker when one of yours
-- reaches 10 saves. save_count moves by trigger, which fires this too.
create or replace function public.award_list_badges()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kind <> 'playlist' then
    return null;
  end if;
  if new.visibility = 'public' then
    perform public.award_badge(new.user_id, 'curator');
  end if;
  if new.save_count >= 10 then
    perform public.award_badge(new.user_id, 'tastemaker');
  end if;
  return null;
end $$;

drop trigger if exists lists_award_badges on public.lists;
create trigger lists_award_badges
  after insert or update of visibility, save_count on public.lists
  for each row execute function public.award_list_badges();

-- Clean Slate: 10 titles struck off your watchlist. Striking happens by hand
-- or by the log trigger in 008; both are updates of watched_at.
create or replace function public.award_strike_badges()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
  n     int;
begin
  if new.watched_at is null or old.watched_at is not null then
    return null;
  end if;
  select user_id into owner from public.lists
   where id = new.list_id and kind = 'watchlist';
  if owner is null then
    return null;
  end if;
  select count(*) into n from public.list_items
   where list_id = new.list_id and watched_at is not null;
  if n >= 10 then
    perform public.award_badge(owner, 'clean_slate');
  end if;
  return null;
end $$;

drop trigger if exists list_items_award_badges on public.list_items;
create trigger list_items_award_badges
  after update of watched_at on public.list_items
  for each row execute function public.award_strike_badges();

-- Early Adopter: everyone who joins before the public launch. Move the date
-- when the launch is set.
create or replace function public.early_adopter_until()
returns timestamptz language sql immutable as $$
  select timestamptz '2027-01-01 00:00:00+00';
$$;

create or replace function public.award_signup_badges()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.created_at < public.early_adopter_until() then
    perform public.award_badge(new.id, 'early_adopter', new.created_at);
  end if;
  return null;
end $$;

drop trigger if exists profiles_award_badges on public.profiles;
create trigger profiles_award_badges
  after insert on public.profiles
  for each row execute function public.award_signup_badges();

-- ── 4. Progress toward what you haven't earned ────────────────
-- Your own only: it counts rows other people may not be allowed to see.
create or replace function public.my_badge_progress()
returns jsonb
language sql
stable
security definer set search_path = public
as $$
  with r as (
    select genre_ids from public.activities
     where user_id = auth.uid() and activity_type = 'reviewed'
  )
  select jsonb_build_object(
    'reviews', (select count(*) from r),
    'comedy',  (select count(*) from r where genre_ids @> array[35]),
    'action',  (select count(*) from r where genre_ids @> array[28]),
    'romance', (select count(*) from r where genre_ids @> array[10749]),
    'top_saves', (select coalesce(max(save_count), 0) from public.lists
                   where user_id = auth.uid() and kind = 'playlist'),
    'strikes', (select count(*) from public.list_items i
                  join public.lists l on l.id = i.list_id
                 where l.user_id = auth.uid() and l.kind = 'watchlist'
                   and i.watched_at is not null)
  );
$$;

revoke all on function public.my_badge_progress() from public, anon;
grant execute on function public.my_badge_progress() to authenticated;

-- ── 5. Backfill ───────────────────────────────────────────────
-- Everything the old client awarded stays awarded. Where the data can say
-- when a badge was earned, that date replaces "now".
insert into public.user_badges (user_id, badge_id, earned_at)
select p.id, b.badge, now()
  from public.profiles p, unnest(p.badge_ids) as b(badge)
 where b.badge <> ''
on conflict do nothing;

-- The nth review's date for each milestone.
insert into public.user_badges (user_id, badge_id, earned_at)
select r.user_id, m.badge, r.created_at
  from (select user_id, created_at,
               row_number() over (partition by user_id order by created_at) as n
          from public.activities where activity_type = 'reviewed') r
  join (values (1, 'first_review'), (10, 'reviewer_10'), (25, 'reviewer_25'),
               (50, 'reviewer_50'), (100, 'reviewer_100')) as m(n, badge)
    on m.n = r.n
on conflict (user_id, badge_id)
  do update set earned_at = least(public.user_badges.earned_at, excluded.earned_at);

-- First public playlist.
insert into public.user_badges (user_id, badge_id, earned_at)
select user_id, 'curator', min(created_at)
  from public.lists
 where kind = 'playlist' and visibility = 'public'
 group by user_id
on conflict (user_id, badge_id)
  do update set earned_at = least(public.user_badges.earned_at, excluded.earned_at);

-- The 10th save on any of your playlists.
insert into public.user_badges (user_id, badge_id, earned_at)
select l.user_id, 'tastemaker', min(s.created_at)
  from (select list_id, created_at,
               row_number() over (partition by list_id order by created_at) as n
          from public.list_saves) s
  join public.lists l on l.id = s.list_id
 where s.n = 10
 group by l.user_id
on conflict (user_id, badge_id)
  do update set earned_at = least(public.user_badges.earned_at, excluded.earned_at);

-- The 10th strike-off.
insert into public.user_badges (user_id, badge_id, earned_at)
select w.user_id, 'clean_slate', w.watched_at
  from (select l.user_id, i.watched_at,
               row_number() over (partition by l.id order by i.watched_at) as n
          from public.list_items i
          join public.lists l on l.id = i.list_id
         where l.kind = 'watchlist' and i.watched_at is not null) w
 where w.n = 10
on conflict (user_id, badge_id)
  do update set earned_at = least(public.user_badges.earned_at, excluded.earned_at);

insert into public.user_badges (user_id, badge_id, earned_at)
select id, 'early_adopter', created_at
  from public.profiles
 where created_at < public.early_adopter_until()
on conflict (user_id, badge_id)
  do update set earned_at = least(public.user_badges.earned_at, excluded.earned_at);

-- And badge_ids back in step for older builds, earliest first.
update public.profiles p
   set badge_ids = b.ids
  from (select user_id, array_agg(badge_id order by earned_at, badge_id) as ids
          from public.user_badges group by user_id) b
 where b.user_id = p.id
   and p.badge_ids is distinct from b.ids;
