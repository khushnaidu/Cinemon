-- Discover's New, deeper by genre. Run after 027. Safe to re-run.
--
-- New is trailers published lately for titles in the pool. 027's genre
-- lists are the genres' most popular titles of all time, which rarely get
-- a new trailer, so New Romance came to four trailers.
--
-- So each genre also gets a "soon" list: the most popular titles coming
-- out or just out (films released from 3 months ago to a year ahead;
-- shows with episodes airing from a month ago to four months ahead, which
-- catches new seasons of old shows). Those are the titles with fresh
-- trailers. And New looks back 60 days rather than 30.

-- ── 1. "Soon" lists ───────────────────────────────────────────
alter table public.trailer_candidates
  drop constraint if exists trailer_candidates_list_check;
alter table public.trailer_candidates
  add constraint trailer_candidates_list_check check (
    list in ('trending', 'upcoming', 'now_playing', 'on_the_air')
    or list ~ '^(genre|soon)_(movie|tv)_[0-9]+$');

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
         case when which = 'on_the_air'           then 'tv'
              when which ~ '^(genre|soon)_tv_'    then 'tv'
              when which = 'trending'             then r.v->>'media_type'
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

-- ── 2. The schedule ───────────────────────────────────────────
create or replace function public.trailer_feed_dispatch()
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  api_key text := public.tmdb_key();
  l       record;
  n       int := 0;
  d       text := 'YYYY-MM-DD';
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
    -- Each genre's best known.
    select 'genre_' || g.media_type || '_' || g.genre_id, p,
           'discover/' || g.media_type || '?with_genres=' || g.genre_id
           || '&sort_by=popularity.desc&vote_count.gte=50&include_adult=false&'
      from public.trailer_genres() g
     cross join generate_series(1, 2) p
    union all
    -- Each genre's coming out or just out: where new trailers are.
    select 'soon_' || g.media_type || '_' || g.genre_id, p,
           'discover/' || g.media_type || '?with_genres=' || g.genre_id
           || '&sort_by=popularity.desc&include_adult=false&'
           || case when g.media_type = 'movie' then
                'primary_release_date.gte=' || to_char(current_date - 90, d)
                || '&primary_release_date.lte=' || to_char(current_date + 365, d)
              else
                'air_date.gte=' || to_char(current_date - 30, d)
                || '&air_date.lte=' || to_char(current_date + 120, d)
              end || '&'
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

-- ── 3. What the app reads ─────────────────────────────────────
-- As 027, with New looking back 60 days. In Home, "soon" titles rank with
-- upcoming and in theaters, ahead of the genres' all-time popular.
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
 where t.trailer_published_at > now() - interval '60 days'
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

select public.trailer_feed_dispatch();
