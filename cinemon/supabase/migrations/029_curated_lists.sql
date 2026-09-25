-- Explore › Lists: 35mm Selects, community lists, moods and covers.
-- Run after 028. Safe to re-run.
--
--   * Covers. A playlist's cover is a six-strip of its first posters (the
--     default), one film the curator picks, or, for Selects only, our own
--     artwork.
--   * Moods. Up to three per playlist, from a fixed set, for Browse by mood.
--   * 35mm Selects. Playlists we make and rank ourselves, owned by the
--     official account. Only the dashboard (or an admin) can make a list a
--     Select, give it a tagline or artwork.
--   * Explore reads Selects straight from `lists`, and the community lists
--     and mood counts from two functions below.

-- ── 1. Columns ────────────────────────────────────────────────
alter table public.lists add column if not exists cover_style text not null default 'strip';
alter table public.lists add column if not exists cover_path  text;
alter table public.lists add column if not exists cover_url   text;
alter table public.lists add column if not exists moods       text[] not null default '{}';
alter table public.lists add column if not exists is_select   boolean not null default false;
alter table public.lists add column if not exists select_rank int;
alter table public.lists add column if not exists tagline     text;

alter table public.lists drop constraint if exists lists_cover_style_check;
alter table public.lists add constraint lists_cover_style_check
  check (cover_style in ('strip', 'film', 'artwork'));
alter table public.lists drop constraint if exists lists_tagline_check;
alter table public.lists add constraint lists_tagline_check
  check (tagline is null or char_length(tagline) between 1 and 140);

-- The moods, as slugs; the app has the labels. Adding one is a new
-- migration and an app release.
create or replace function public.list_moods()
returns text[] language sql immutable as $$
  select array['slow_burn', 'tender', 'neon', 'epic', 'unsettling', 'rainy_day',
               'sunlit', 'late_night', 'funny', 'heartbreaking', 'mind_bending',
               'cozy']
$$;

alter table public.lists drop constraint if exists lists_moods_check;
alter table public.lists add constraint lists_moods_check
  check (cardinality(moods) <= 3 and moods <@ public.list_moods());

create index if not exists lists_selects_idx on public.lists (select_rank) where is_select;
create index if not exists lists_moods_idx on public.lists using gin (moods) where kind = 'playlist';

-- ── 2. Who can curate ─────────────────────────────────────────
-- Owners write their own lists (`lists own update`), so the curation
-- columns are guarded here, like the moderation columns on profiles (007).
create or replace function public.guard_list_curation()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') and not public.is_admin() then
    if (new.is_select, new.select_rank, new.tagline, new.cover_url)
       is distinct from (case when tg_op = 'UPDATE'
                              then (old.is_select, old.select_rank, old.tagline, old.cover_url)
                              else (false, null::int, null::text, null::text) end)
    then
      raise exception 'curation columns are not writable';
    end if;
    if new.cover_style = 'artwork'
       and (tg_op = 'INSERT' or old.cover_style is distinct from 'artwork') then
      raise exception 'artwork covers are for 35mm Selects';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists lists_guard_curation on public.lists;
create trigger lists_guard_curation before insert or update on public.lists
  for each row execute function public.guard_list_curation();

-- The tagline goes through the same filter as the title and description.
drop trigger if exists filter_lists on public.lists;
create trigger filter_lists before insert or update on public.lists
  for each row execute function public.refuse_objectionable('title', 'description', 'tagline');

-- ── 3. What Explore reads ─────────────────────────────────────
-- Public playlists by people (not Selects), best first: saves this week,
-- then all-time saves, then the newest. With a mood, only lists with that
-- mood, Selects included. Security definer because saves by other people
-- aren't readable; who you may see is checked here the way `lists readable`
-- checks it.
drop function if exists public.explore_lists(text, int);
create or replace function public.explore_lists(p_mood text default null, p_limit int default 20)
returns table (
  id uuid, user_id uuid, kind text, title text, description text,
  visibility text, item_count int, save_count int, updated_at timestamptz,
  cover_style text, cover_path text, cover_url text, moods text[],
  is_select boolean, select_rank int, tagline text,
  owner_username text, week_saves int, posters text[]
)
language sql stable
security definer set search_path = public
as $$
  select l.id, l.user_id, l.kind, l.title, l.description,
         l.visibility, l.item_count, l.save_count, l.updated_at,
         l.cover_style, l.cover_path, l.cover_url, l.moods,
         l.is_select, l.select_rank, l.tagline,
         p.username,
         (select count(*)::int from public.list_saves s
           where s.list_id = l.id and s.created_at > now() - interval '7 days'),
         array(select i.film_poster_path from public.list_items i
                where i.list_id = l.id and i.film_poster_path is not null
                order by i.position limit 6)
    from public.lists l
    join public.profiles p on p.id = l.user_id
   where l.kind = 'playlist'
     and l.visibility = 'public'
     and l.item_count >= 3
     and (case when p_mood is null then not l.is_select else p_mood = any(l.moods) end)
     and public.can_view_list(l.user_id, l.visibility)
     and not public.i_reported('list', l.id)
     and not public.is_suspended(l.user_id)
   order by 18 desc, l.save_count desc, l.updated_at desc
   limit least(greatest(p_limit, 1), 50)
$$;

revoke all on function public.explore_lists(text, int) from public, anon;
grant execute on function public.explore_lists(text, int) to authenticated;

-- How many public playlists have each mood, for Browse by mood.
create or replace function public.explore_mood_counts()
returns table (mood text, n int)
language sql stable
security definer set search_path = public
as $$
  select m, count(l.id)::int
    from unnest(public.list_moods()) m
    left join public.lists l
      on m = any(l.moods) and l.kind = 'playlist' and l.visibility = 'public'
     and l.item_count >= 3 and not public.is_suspended(l.user_id)
   group by m
$$;

revoke all on function public.explore_mood_counts() from public, anon;
grant execute on function public.explore_mood_counts() to authenticated;

-- ── 4. Artwork ────────────────────────────────────────────────
-- Selects' own artwork, uploaded from the dashboard. Public, like posters.
insert into storage.buckets (id, name, public)
values ('selects', 'selects', true)
on conflict (id) do update set public = true;

-- ── 5. Verified accounts and reserved names ───────────────────
-- A small seal beside the username, for the official account and the
-- founder. Set from the dashboard only, like the moderation columns.
alter table public.profiles add column if not exists is_verified boolean not null default false;

create or replace function public.guard_profile_moderation_columns()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.is_admin, new.suspended_until, new.is_verified)
         is distinct from (old.is_admin, old.suspended_until, old.is_verified)
  then
    raise exception 'moderation columns are not writable';
  end if;
  return new;
end $$;

-- As 020, with the founder's name held too. Reserving only stops a new
-- claim (the guard fires when a username changes), so whoever already has
-- a name keeps it.
create or replace function public.username_reserved(username text)
returns boolean language sql immutable as $$
  with n as (
    select replace(public.moderation_normalise(username), ' ', '') as name
  )
  select n.name in (select replace(public.moderation_normalise(x), ' ', '')
                      from unnest(array[
                        'mod', 'mods', 'support', 'help', 'helpdesk', 'team',
                        'security', 'safety', 'trust', 'apple', 'tmdb',
                        'justwatch', 'youtube', 'system', 'root', 'null',
                        'undefined', 'deleted', 'unknown', 'everyone', 'here',
                        'contact', 'privacy', 'legal', 'terms', 'abuse',
                        'report', 'reports', 'noreply', 'appstore',
                        'appreview', 'khush', 'selects', 'thirtyfivemm']) x)
      or n.name ~ (select string_agg(replace(public.moderation_normalise(x), ' ', ''), '|')
                     from unnest(array['35mm', 'admin', 'moderator',
                                       'official', 'staff']) x)
    from n;
$$;
