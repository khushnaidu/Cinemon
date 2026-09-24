-- Trailers from TMDB only, and trending people worth the name (ADR 0001
-- Phase 7, second pass). Run after 012. Safe to re-run.
--
-- 012 took its trailers from KinoCheck, whose videos are its own re-uploads
-- with a KinoCheck intro in front. TMDB links the studios' own uploads, the
-- same ones the film page plays, and has no daily limit. So KinoCheck goes.
--
-- The two feeds now mean:
--   * Trending: what's trending on TMDB this week, films and shows, each
--     with its newest official trailer, in TMDB's order.
--   * New: trailers published in the last 30 days, newest first, from
--     what's upcoming, in theaters, on the air or trending.
--
-- And the People tab's "trending" list is built from the same place: the
-- leads and directors of this week's trending titles. TMDB's own trending
-- people list is mostly bot traffic to adult performers that TMDB doesn't
-- flag as adult.

-- ── 1. Out with 012's feed ────────────────────────────────────
drop view     if exists public.trailer_feed_items;
drop function if exists public.trailer_feed_ingest(text, text, jsonb);
drop function if exists public.trailer_title_missing(text, int);
drop table    if exists public.trailer_feed;
truncate public.trailer_requests;

-- ── 2. Tables ─────────────────────────────────────────────────
-- Which lists each title was on at the last refresh.
create table if not exists public.trailer_candidates (
  list       text not null check (list in ('trending', 'upcoming', 'now_playing', 'on_the_air')),
  media_type text not null check (media_type in ('movie', 'tv')),
  tmdb_id    int  not null,
  rank       int  not null,
  seen_at    timestamptz not null default now(),
  primary key (list, media_type, tmdb_id)
);
alter table public.trailer_candidates enable row level security;
drop policy if exists "trailer candidates readable" on public.trailer_candidates;
create policy "trailer candidates readable" on public.trailer_candidates
  for select to authenticated using (true);

alter table public.trailer_titles add column if not exists trailer_name         text;
alter table public.trailer_titles add column if not exists trailer_type         text;
alter table public.trailer_titles add column if not exists trailer_published_at timestamptz;
alter table public.trailer_titles add column if not exists people               jsonb not null default '[]';
alter table public.trailer_titles add column if not exists skip                 boolean not null default false;
-- Every title looked up again, for its people and its trailer's date.
update public.trailer_titles set checked_at = null;

-- ── 3. What the app reads ─────────────────────────────────────
-- The newest refresh of each list. Older rows linger until the cleanup, so
-- they're filtered out here rather than trusted.
create or replace view public.trailer_current
with (security_invoker = true) as
select c.*
  from public.trailer_candidates c
 where c.seen_at >= (select max(seen_at) from public.trailer_candidates x
                      where x.list = c.list) - interval '1 hour';

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
                where c.media_type = t.media_type and c.tmdb_id = t.tmdb_id);

grant select on public.trailer_current    to authenticated;
grant select on public.trailer_feed_items to authenticated;

-- The People tab before you type: top-billed cast and directors (or
-- creators) of this week's trending titles, each once. Taken in turns, so
-- every title's lead comes before any title's second lead and one ensemble
-- can't fill the grid.
create or replace view public.trending_people
with (security_invoker = true) as
select person_id, name, profile_path, department, known_for_title, score
  from (
    select distinct on ((p->>'id')::int)
           (p->>'id')::int              as person_id,
           p->>'name'                   as name,
           p->>'profile_path'           as profile_path,
           p->>'department'             as department,
           t.title                      as known_for_title,
           coalesce((p->>'order')::int, 0) * 1000 + c.rank as score
      from public.trailer_current c
      join public.trailer_titles t on t.media_type = c.media_type and t.tmdb_id = c.tmdb_id
      cross join lateral jsonb_array_elements(t.people) p
     where c.list = 'trending'
       and not t.skip
       and coalesce(p->>'profile_path', '') <> ''
     order by (p->>'id')::int, coalesce((p->>'order')::int, 0) * 1000 + c.rank
  ) x
 order by score;

grant select on public.trending_people to authenticated;

-- ── 4. Reading the answers ────────────────────────────────────
-- One page of a TMDB list.
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
         case when which = 'on_the_air' then 'tv'
              when which = 'trending'   then r.v->>'media_type'
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

-- One title's details, with `append_to_response=videos,credits`.
create or replace function public.trailer_title_ingest(mt text, id int, body jsonb)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  best jsonb;
  genres int[];
begin
  genres := coalesce(array(select (g->>'id')::int
                             from jsonb_array_elements(coalesce(body->'genres', '[]')) g), '{}');

  -- The one a person would pick, and the same rule as the film page: an
  -- official trailer, newest first, then any trailer, then a teaser.
  select v into best
    from jsonb_array_elements(coalesce(body->'videos'->'results', '[]')) v
   where v->>'site' = 'YouTube' and v->>'type' in ('Trailer', 'Teaser')
   order by (v->>'type' = 'Trailer') desc,
            coalesce((v->>'official')::boolean, false) desc,
            v->>'published_at' desc nulls last
   limit 1;

  update public.trailer_titles set
    title                = coalesce(body->>'title', body->>'name'),
    poster_path          = body->>'poster_path',
    backdrop_path        = body->>'backdrop_path',
    year                 = extract(year from nullif(coalesce(body->>'release_date',
                                                             body->>'first_air_date'), '')::date)::int,
    genre_ids            = genres,
    trailer_key          = best->>'key',
    trailer_name         = best->>'name',
    trailer_type         = best->>'type',
    trailer_published_at = (best->>'published_at')::timestamptz,
    -- Talk, news and reality TV trend constantly and aren't what this tab
    -- is for. Adult titles never.
    skip                 = coalesce((body->>'adult')::boolean, false)
                           or genres && array[10763, 10764, 10767],
    -- Four leads and the director or creators. The director ranks with
    -- the second lead.
    people               = coalesce((
      select jsonb_agg(p) from (
        select jsonb_build_object('id', c->'id', 'name', c->'name',
                                  'profile_path', c->'profile_path',
                                  'department', 'Acting', 'order', (c->>'order')::int) p
          from jsonb_array_elements(coalesce(body->'credits'->'cast', '[]')) c
         where (c->>'order')::int < 4
        union all
        select jsonb_build_object('id', c->'id', 'name', c->'name',
                                  'profile_path', c->'profile_path',
                                  'department', 'Directing', 'order', 1)
          from jsonb_array_elements(coalesce(body->'credits'->'crew', '[]')) c
         where c->>'job' = 'Director'
        union all
        select jsonb_build_object('id', c->'id', 'name', c->'name',
                                  'profile_path', c->'profile_path',
                                  'department', 'Writing', 'order', 1)
          from jsonb_array_elements(coalesce(body->'created_by', '[]')) c
      ) x), '[]'),
    checked_at           = now()
  where media_type = mt and tmdb_id = id;
end $$;

revoke all on function public.trailer_list_ingest(text, int, jsonb)  from public, anon, authenticated;
revoke all on function public.trailer_title_ingest(text, int, jsonb) from public, anon, authenticated;

-- ── 5. The schedule ───────────────────────────────────────────
-- Every 6 hours: the lists. Seven TMDB calls.
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

  for l in select * from (values
      ('trending',    1, 'trending/all/week?'),
      ('trending',    2, 'trending/all/week?'),
      ('trending',    3, 'trending/all/week?'),
      ('upcoming',    1, 'movie/upcoming?region=US&'),
      ('upcoming',    2, 'movie/upcoming?region=US&'),
      ('now_playing', 1, 'movie/now_playing?region=US&'),
      ('on_the_air',  1, 'tv/on_the_air?')) v(list, page, path)
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

-- Every 2 minutes: read what's come back, then look up the next titles.
-- Each is looked up again daily, since new trailers are the point.
create or replace function public.trailer_feed_collect(batch int default 60)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  api_key text := public.tmdb_key();
  r       record;
  part    text[];
  n       int := 0;
begin
  for r in
    select q.request_id, q.kind, h.status_code, h.content
      from public.trailer_requests q
      join net._http_response h on h.id = q.request_id
     order by q.request_id
  loop
    part := string_to_array(r.kind, ':');
    begin
      if part[1] = 'title' then
        if r.status_code = 200 then
          perform public.trailer_title_ingest(part[2], part[3]::int, r.content::jsonb);
        elsif r.status_code = 404 then
          update public.trailer_titles set checked_at = now(), skip = true
           where media_type = part[2] and tmdb_id = part[3]::int;
        end if;
      elsif part[1] = 'list' and r.status_code = 200 then
        n := n + public.trailer_list_ingest(part[2], part[3]::int, r.content::jsonb);
      end if;
    exception when others then
      raise warning 'trailer_feed_collect(%) failed: %', r.kind, sqlerrm;
    end;
    delete from public.trailer_requests where request_id = r.request_id;
  end loop;

  delete from public.trailer_requests where created_at < now() - interval '1 hour';

  if api_key is not null then
    for r in
      select t.media_type, t.tmdb_id
        from public.trailer_titles t
       where (t.checked_at is null or t.checked_at < now() - interval '20 hours')
         and not exists (select 1 from public.trailer_requests q
                          where q.kind = 'title:' || t.media_type || ':' || t.tmdb_id)
       order by t.checked_at nulls first
       limit batch
    loop
      insert into public.trailer_requests (request_id, kind)
      values (net.http_get(
                url := 'https://api.themoviedb.org/3/' || r.media_type || '/' || r.tmdb_id
                       || '?append_to_response=videos,credits&language=en-US&api_key=' || api_key,
                timeout_milliseconds := 15000),
              'title:' || r.media_type || ':' || r.tmdb_id);
    end loop;
  end if;

  return n;
end $$;

revoke all on function public.trailer_feed_dispatch()   from public, anon, authenticated;
revoke all on function public.trailer_feed_collect(int) from public, anon, authenticated;

-- Same job names as 012, so these replace its schedule.
do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('trailer-feed-dispatch', '7 */6 * * *',
                          'select public.trailer_feed_dispatch()');
    perform cron.schedule('trailer-feed-collect', '*/2 * * * *',
                          'select public.trailer_feed_collect()');
  end if;
end $$;

select public.trailer_feed_dispatch();
