-- Discover: the Trailers tab by genre. Run after 026. Safe to re-run.
--
-- The tab becomes Discover, with Home (what's trending, then everything
-- else worth a look) and New, each for films or shows, narrowed to a genre.
--
-- Trending alone is ~60 titles, so "documentaries" would be two trailers.
-- So every 6 hours the job also asks TMDB for the most popular titles in
-- each genre (two pages of 20), and those join the pool the feeds draw
-- from. A genre then has dozens of trailers, and a refresh still puts the
-- ones you haven't watched first.
--
-- Builds before this one read feed 'trending' and keep working: that feed
-- is unchanged. 'home' is new.

-- ── 1. Genre lists ────────────────────────────────────────────
-- 'genre_movie_27', 'genre_tv_99': one list per media type and genre.
alter table public.trailer_candidates
  drop constraint if exists trailer_candidates_list_check;
alter table public.trailer_candidates
  add constraint trailer_candidates_list_check check (
    list in ('trending', 'upcoming', 'now_playing', 'on_the_air')
    or list ~ '^genre_(movie|tv)_[0-9]+$');

-- The genres asked about. TV's News, Reality, Talk and Soap are left out,
-- as are TV movies: the feed skips the first three anyway.
create or replace function public.trailer_genres()
returns table (media_type text, genre_id int)
language sql immutable
set search_path = public
as $$
  select 'movie', g from unnest(array[
    28, 12, 16, 35, 80, 99, 18, 10751, 14, 36, 27, 10402, 9648, 10749, 878,
    53, 10752, 37]) g
  union all
  select 'tv', g from unnest(array[
    10759, 16, 35, 80, 99, 18, 10751, 10762, 9648, 10765, 10768, 37]) g
$$;

-- ── 2. Reading a list page ────────────────────────────────────
-- As 013, plus genre lists, which say their media type in their name.
create or replace function public.trailer_list_ingest(which text, page int, body jsonb)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  n int;
begin
  insert into public.trailer_candidates as c (list, media_type, tmdb_id, rank, seen_at)
  select which,
         case when which = 'on_the_air'       then 'tv'
              when which like 'genre\_tv\_%'  then 'tv'
              when which = 'trending'         then r.v->>'media_type'
              else 'movie' end,
         (r.v->>'id')::int,
         (page - 1) * 100 + r.ord::int,
         now()
    from jsonb_array_elements(coalesce(body->'results', '[]')) with ordinality r(v, ord)
   where r.v ? 'id'
     and not coalesce((r.v->>'adult')::boolean, false)
     and (which <> 'trending' or r.v->>'media_type' in ('movie', 'tv'))
  on conflict (list, media_type, tmdb_id) do update
    set rank = excluded.rank, seen_at = excluded.seen_at;
  get diagnostics n = row_count;

  insert into public.trailer_titles (media_type, tmdb_id)
  select media_type, tmdb_id from public.trailer_candidates where list = which
  on conflict (media_type, tmdb_id) do nothing;
  return n;
end $$;

revoke all on function public.trailer_list_ingest(text, int, jsonb) from public, anon, authenticated;

-- ── 3. The schedule ───────────────────────────────────────────
-- 013's seven list calls, plus two pages per genre: popular, with enough
-- votes to be something people have heard of.
create or replace function public.trailer_feed_dispatch()
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  api_key text := public.tmdb_key();
  l       record;
  n       int := 0;
begin
  if api_key is null then
    return 0;
  end if;

  for l in
    select * from (values
      ('trending',    1, 'trending/all/week?'),
      ('trending',    2, 'trending/all/week?'),
      ('trending',    3, 'trending/all/week?'),
      ('upcoming',    1, 'movie/upcoming?region=US&'),
      ('upcoming',    2, 'movie/upcoming?region=US&'),
      ('now_playing', 1, 'movie/now_playing?region=US&'),
      ('on_the_air',  1, 'tv/on_the_air?')) v(list, page, path)
    union all
    select 'genre_' || g.media_type || '_' || g.genre_id, p,
           'discover/' || g.media_type || '?with_genres=' || g.genre_id
           || '&sort_by=popularity.desc&vote_count.gte=50&include_adult=false&'
      from public.trailer_genres() g
     cross join generate_series(1, 2) p
  loop
    if not exists (select 1 from public.trailer_requests
                    where kind = 'list:' || l.list || ':' || l.page) then
      insert into public.trailer_requests (request_id, kind)
      values (net.http_get(
                url := 'https://api.themoviedb.org/3/' || l.path
                       || 'language=en-US&page=' || l.page || '&api_key=' || api_key,
                timeout_milliseconds := 15000),
              'list:' || l.list || ':' || l.page);
      n := n + 1;
    end if;
  end loop;

  -- Off every list for two days: forgotten.
  delete from public.trailer_candidates where seen_at < now() - interval '2 days';
  delete from public.trailer_titles t
   where not exists (select 1 from public.trailer_candidates c
                      where c.media_type = t.media_type and c.tmdb_id = t.tmdb_id);
  return n;
end $$;

revoke all on function public.trailer_feed_dispatch() from public, anon, authenticated;

-- ── 4. What the app reads ─────────────────────────────────────
-- As 013, plus 'home': every title in the pool once, trending first in
-- TMDB's order, then what's upcoming, in theaters or on the air, then the
-- genres' popular titles. The genre lists interleave (every genre's first
-- before any genre's second), so an unfiltered Home isn't all one genre.
-- The app narrows it by media type and genre.
create or replace view public.trailer_feed_items
with (security_invoker = true) as
with shown as (
  select * from public.trailer_titles
   where title is not null and trailer_key is not null and not skip
)
select 'trending'::text as feed,
       c.rank,
       c.media_type, c.tmdb_id,
       t.trailer_key as video_id, t.trailer_name as video_title,
       t.trailer_type as category, t.trailer_published_at as published_at,
       t.title, t.poster_path, t.backdrop_path, t.year, t.genre_ids
  from public.trailer_current c
  join shown t on t.media_type = c.media_type and t.tmdb_id = c.tmdb_id
 where c.list = 'trending'
union all
select 'latest',
       (row_number() over (order by t.trailer_published_at desc))::int,
       t.media_type, t.tmdb_id,
       t.trailer_key, t.trailer_name, t.trailer_type, t.trailer_published_at,
       t.title, t.poster_path, t.backdrop_path, t.year, t.genre_ids
  from shown t
 where t.trailer_published_at > now() - interval '30 days'
   and exists (select 1 from public.trailer_current c
                where c.media_type = t.media_type and c.tmdb_id = t.tmdb_id)
union all
select 'home',
       (row_number() over (order by b.score, b.media_type, b.tmdb_id))::int,
       t.media_type, t.tmdb_id,
       t.trailer_key, t.trailer_name, t.trailer_type, t.trailer_published_at,
       t.title, t.poster_path, t.backdrop_path, t.year, t.genre_ids
  from (select c.media_type, c.tmdb_id,
               min(case when c.list = 'trending' then c.rank
                        when c.list like 'genre\_%' then 2000 + c.rank
                        else 1000 + c.rank end) as score
          from public.trailer_current c
         group by c.media_type, c.tmdb_id) b
  join shown t on t.media_type = b.media_type and t.tmdb_id = b.tmdb_id;

grant select on public.trailer_feed_items to authenticated;

-- Start filling the genres now rather than at the next 6-hour mark. The
-- titles are looked up 60 every 2 minutes, so the pool is full in about
-- an hour; Home works throughout, with fewer titles per genre at first.
select public.trailer_feed_dispatch();
