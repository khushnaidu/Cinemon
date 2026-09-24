-- ─────────────────────────────────────────────────────────────
-- 003 — EPISODE POSTS and TOP 3 SHOWS
-- ─────────────────────────────────────────────────────────────
-- Safe to run on an existing database, and idempotent.
--
-- Additive only: no existing column changes type. Rows written before this
-- migration read back as film/show-level posts (null season) and an empty
-- top-3 shows list.

-- ── 1. Episode columns on activities ────────────────────────
-- A post can be about one episode of a show rather than the show itself.
-- film_id stays the show's TMDB id so everything keyed on it (friends'
-- reviews, "your activity", the film index) keeps working; the four columns
-- below say *which* episode. They travel together — see the constraint.
alter table public.activities
  add column if not exists season_number      int,
  add column if not exists episode_number     int,
  add column if not exists episode_title      text,
  add column if not exists episode_still_path text;

alter table public.activities
  drop constraint if exists activities_episode_coherent;
alter table public.activities
  add constraint activities_episode_coherent check (
    (season_number is null and episode_number is null
       and episode_title is null and episode_still_path is null)
    or (season_number is not null and episode_number is not null
       and media_type = 'tv')
  );

-- "Has this user posted about this episode?" and the per-show episode map.
create index if not exists activities_user_episode_idx
  on public.activities (user_id, film_id, season_number, episode_number)
  where season_number is not null;

-- ── 2. Top 3 shows on profiles ──────────────────────────────
alter table public.profiles
  add column if not exists favorite_show_ids int[] not null default '{}';

-- ── 3. Rebuild the feed view ────────────────────────────────
-- The view selects a.*, but a view's output shape is fixed at creation, so
-- without this the new columns exist on the table and are silently missing
-- from every feed read.
drop view if exists public.feed_activities;

create view public.feed_activities
with (security_invoker = true) as
select
  a.*,
  p.username,
  p.photo_url                                as user_photo_url,
  coalesce(l.likes, array[]::text[])         as likes,
  coalesce(r.reactions, '{}'::jsonb)         as reactions
from public.activities a
join public.profiles p on p.id = a.user_id
left join lateral (
  select array_agg(al.user_id::text) as likes
  from public.activity_likes al where al.activity_id = a.id
) l on true
left join lateral (
  select jsonb_object_agg(ar.user_id::text, ar.sticker_id) as reactions
  from public.activity_reactions ar where ar.activity_id = a.id
) r on true;

grant select on public.feed_activities to authenticated;
