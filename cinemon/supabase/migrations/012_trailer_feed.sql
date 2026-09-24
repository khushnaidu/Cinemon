-- The Trailers tab's feed (ADR 0001 Phase 7). Run after 011. Safe to re-run.
--
-- Built like Phase 6's alerts, entirely in Postgres: pg_cron runs it,
-- pg_net makes the calls, and plain SQL turns the answers into a table the
-- app reads. The app never calls KinoCheck itself, since its free tier is
-- 1,000 requests a day per client and every install would share it.
--
--   * Every 6 hours, KinoCheck's trending and latest trailers (100 each, two
--     calls), which replace the feed.
--   * Every 2 minutes, whatever has come back is read, and titles not yet
--     known are looked up on TMDB (title, poster, backdrop, year), a few at
--     a time.
--   * If KinoCheck fails or comes back thin, TMDB's now playing and upcoming
--     films stand in, with their own trailers, so the tab is never empty.
--
-- Uses the TMDB key already in Vault from 011 (`tmdb_api_key`). KinoCheck
-- needs no key.

-- ── 1. Tables ─────────────────────────────────────────────────
-- What each title looks like, from TMDB. Kept apart from the feed so a title
-- that stays in it is only looked up once a week.
create table if not exists public.trailer_titles (
  media_type    text not null check (media_type in ('movie', 'tv')),
  tmdb_id       int  not null,
  title         text,
  poster_path   text,
  backdrop_path text,
  year          int,
  genre_ids     int[] not null default '{}',
  -- The title's own best trailer: only used by TMDB fallback rows, which
  -- come without a video.
  trailer_key   text,
  -- Null until looked up. A title TMDB doesn't know keeps a null title and
  -- simply never shows.
  checked_at    timestamptz,
  primary key (media_type, tmdb_id)
);

create table if not exists public.trailer_feed (
  feed         text not null check (feed in ('trending', 'latest')),
  rank         int  not null,
  media_type   text not null,
  tmdb_id      int  not null,
  video_id     text,
  video_title  text,
  category     text,
  published_at timestamptz,
  source       text not null check (source in ('kinocheck', 'tmdb')),
  primary key (feed, rank)
);

create table if not exists public.trailer_requests (
  request_id bigint primary key,
  -- 'kinocheck:trending', 'tmdb:latest', 'title:movie:123'
  kind       text not null,
  created_at timestamptz not null default now()
);

alter table public.trailer_titles   enable row level security;
alter table public.trailer_feed     enable row level security;
alter table public.trailer_requests enable row level security;

-- Anyone signed in reads the feed. Only the job writes.
drop policy if exists "trailer titles readable" on public.trailer_titles;
drop policy if exists "trailer feed readable"   on public.trailer_feed;
create policy "trailer titles readable" on public.trailer_titles for select to authenticated using (true);
create policy "trailer feed readable"   on public.trailer_feed   for select to authenticated using (true);

-- ── 2. What the app reads ─────────────────────────────────────
-- Only rows that can be shown: a known title and a video to play.
create or replace view public.trailer_feed_items
with (security_invoker = true) as
select f.feed, f.rank, f.media_type, f.tmdb_id,
       coalesce(f.video_id, t.trailer_key) as video_id,
       f.video_title, f.category, f.published_at,
       t.title, t.poster_path, t.backdrop_path, t.year, t.genre_ids
  from public.trailer_feed f
  join public.trailer_titles t
    on t.media_type = f.media_type and t.tmdb_id = f.tmdb_id
 where t.title is not null
   and coalesce(f.video_id, t.trailer_key) is not null;

grant select on public.trailer_feed_items to authenticated;

-- ── 3. Reading the answers ────────────────────────────────────
-- A feed page from KinoCheck or TMDB replaces that feed. Returns how many
-- rows it kept.
create or replace function public.trailer_feed_ingest(which text, src text, body jsonb)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  n int;
begin
  create temp table if not exists _trailers (
    ord int, media_type text, tmdb_id int, video_id text, video_title text,
    category text, published_at timestamptz,
    title text, poster text, backdrop text, year int, genre_ids int[]
  ) on commit drop;
  truncate _trailers;

  if src = 'kinocheck' then
    -- An object keyed "0", "1", … beside "_metadata", not an array.
    insert into _trailers (ord, media_type, tmdb_id, video_id, video_title, category, published_at)
    select e.key::int,
           case v->'resource'->>'type' when 'show' then 'tv' else 'movie' end,
           (v->'resource'->>'tmdb_id')::int,
           v->>'youtube_video_id',
           v->>'title',
           v->'categories'->>0,
           (v->>'published')::timestamptz
      from jsonb_each(body) e, lateral (select e.value as v) x
     where e.key ~ '^[0-9]+$'
       and v->'resource'->>'type' in ('movie', 'show')
       and coalesce(v->'resource'->>'tmdb_id', '') ~ '^[0-9]+$'
       and coalesce(v->>'youtube_video_id', '') <> '';
  else
    -- TMDB's now_playing / upcoming. No video yet: the title lookup finds
    -- its trailer.
    insert into _trailers (ord, media_type, tmdb_id, title, poster, backdrop, year, genre_ids)
    select r.ord::int, 'movie', (r.v->>'id')::int,
           r.v->>'title', r.v->>'poster_path', r.v->>'backdrop_path',
           extract(year from nullif(r.v->>'release_date', '')::date)::int,
           coalesce(array(select jsonb_array_elements_text(r.v->'genre_ids')::int), '{}')
      from jsonb_array_elements(coalesce(body->'results', '[]')) with ordinality r(v, ord)
     where r.v ? 'id' and not coalesce((r.v->>'adult')::boolean, false);
  end if;

  -- One page per title: trending often has a second trailer for the same
  -- film, and a feed of the same film twice reads as a bug.
  delete from _trailers a
   using _trailers b
   where a.media_type = b.media_type and a.tmdb_id = b.tmdb_id and a.ord > b.ord;

  select count(*) into n from _trailers;

  if src = 'kinocheck' then
    -- Thin or empty: keep what's there rather than blank the tab.
    if n < 10 then
      return 0;
    end if;
  else
    -- The fallback only fills in while KinoCheck hasn't.
    if (select count(*) from public.trailer_feed
         where feed = which and source = 'kinocheck') >= 10 then
      return 0;
    end if;
  end if;

  delete from public.trailer_feed where feed = which;
  insert into public.trailer_feed (feed, rank, media_type, tmdb_id, video_id,
                                   video_title, category, published_at, source)
  select which, row_number() over (order by ord), media_type, tmdb_id, video_id,
         video_title, category, published_at, src
    from _trailers;

  -- Titles to look up. TMDB's own list already says what they are, so those
  -- start with it and only need their trailer.
  insert into public.trailer_titles (media_type, tmdb_id, title, poster_path,
                                     backdrop_path, year, genre_ids)
  select media_type, tmdb_id, title, poster, backdrop, year, coalesce(genre_ids, '{}')
    from _trailers
  on conflict (media_type, tmdb_id) do nothing;

  return n;
end $$;

-- One title's TMDB details, with `append_to_response=videos`.
create or replace function public.trailer_title_ingest(mt text, id int, body jsonb)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.trailer_titles set
    title         = coalesce(body->>'title', body->>'name'),
    poster_path   = body->>'poster_path',
    backdrop_path = body->>'backdrop_path',
    year          = extract(year from nullif(coalesce(body->>'release_date',
                                                      body->>'first_air_date'), '')::date)::int,
    genre_ids     = coalesce(array(select (g->>'id')::int
                                     from jsonb_array_elements(coalesce(body->'genres', '[]')) g), '{}'),
    -- The one a person would pick: an official YouTube trailer, newest
    -- first, then any trailer, then a teaser.
    trailer_key   = (select v->>'key'
                       from jsonb_array_elements(coalesce(body->'videos'->'results', '[]')) v
                      where v->>'site' = 'YouTube' and v->>'type' in ('Trailer', 'Teaser')
                      order by (v->>'type' = 'Trailer') desc,
                               coalesce((v->>'official')::boolean, false) desc,
                               v->>'published_at' desc nulls last
                      limit 1),
    checked_at    = now()
  where media_type = mt and tmdb_id = id;
end $$;

-- A title TMDB won't describe: remembered as checked, so it isn't asked
-- about every two minutes, and hidden by its null title.
create or replace function public.trailer_title_missing(mt text, id int)
returns void
language sql
security definer set search_path = public
as $$
  update public.trailer_titles set checked_at = now()
   where media_type = mt and tmdb_id = id;
$$;

revoke all on function public.trailer_feed_ingest(text, text, jsonb) from public, anon, authenticated;
revoke all on function public.trailer_title_ingest(text, int, jsonb)  from public, anon, authenticated;
revoke all on function public.trailer_title_missing(text, int)        from public, anon, authenticated;

-- ── 4. The schedule ───────────────────────────────────────────
create or replace function public.tmdb_key()
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  k text;
begin
  select decrypted_secret into k
    from vault.decrypted_secrets where name = 'tmdb_api_key' limit 1;
  return k;
exception when others then
  return null;
end $$;

revoke all on function public.tmdb_key() from public, anon, authenticated;

-- Every 6 hours: ask KinoCheck for both feeds, and TMDB too for any feed
-- that KinoCheck hasn't filled, in case it fails again.
create or replace function public.trailer_feed_dispatch()
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  api_key text := public.tmdb_key();
  which   text;
  n       int := 0;
begin
  foreach which in array array['trending', 'latest'] loop
    if not exists (select 1 from public.trailer_requests where kind = 'kinocheck:' || which) then
      insert into public.trailer_requests (request_id, kind)
      values (net.http_get(
                url := 'https://api.kinocheck.com/trailers/' || which || '?limit=100&language=en',
                timeout_milliseconds := 20000),
              'kinocheck:' || which);
      n := n + 1;
    end if;

    if api_key is not null
       and (select count(*) from public.trailer_feed
             where feed = which and source = 'kinocheck') < 10
       and not exists (select 1 from public.trailer_requests where kind = 'tmdb:' || which) then
      insert into public.trailer_requests (request_id, kind)
      values (net.http_get(
                url := 'https://api.themoviedb.org/3/movie/'
                       || case which when 'trending' then 'now_playing' else 'upcoming' end
                       || '?region=US&language=en-US&api_key=' || api_key,
                timeout_milliseconds := 15000),
              'tmdb:' || which);
      n := n + 1;
    end if;
  end loop;

  -- Titles that have left both feeds are forgotten after a month.
  delete from public.trailer_titles t
   where t.checked_at < now() - interval '30 days'
     and not exists (select 1 from public.trailer_feed f
                      where f.media_type = t.media_type and f.tmdb_id = t.tmdb_id);
  return n;
end $$;

-- Every 2 minutes: read what's come back, then look up the next few titles.
-- A failed answer is dropped; the next dispatch asks again.
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
     -- KinoCheck first, so a fallback that arrives with it sees it landed.
     order by q.kind like 'kinocheck:%' desc, q.request_id
  loop
    part := string_to_array(r.kind, ':');
    begin
      if part[1] = 'title' then
        if r.status_code = 200 then
          perform public.trailer_title_ingest(part[2], part[3]::int, r.content::jsonb);
        elsif r.status_code = 404 then
          perform public.trailer_title_missing(part[2], part[3]::int);
        end if;
      elsif r.status_code = 200 then
        n := n + public.trailer_feed_ingest(part[2], part[1], r.content::jsonb);
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
       where (t.checked_at is null or t.checked_at < now() - interval '7 days')
         and exists (select 1 from public.trailer_feed f
                      where f.media_type = t.media_type and f.tmdb_id = t.tmdb_id)
         and not exists (select 1 from public.trailer_requests q
                          where q.kind = 'title:' || t.media_type || ':' || t.tmdb_id)
       order by t.checked_at nulls first
       limit batch
    loop
      insert into public.trailer_requests (request_id, kind)
      values (net.http_get(
                url := 'https://api.themoviedb.org/3/' || r.media_type || '/' || r.tmdb_id
                       || '?append_to_response=videos&language=en-US&api_key=' || api_key,
                timeout_milliseconds := 15000),
              'title:' || r.media_type || ':' || r.tmdb_id);
    end loop;
  end if;

  return n;
end $$;

revoke all on function public.trailer_feed_dispatch()     from public, anon, authenticated;
revoke all on function public.trailer_feed_collect(int)   from public, anon, authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('trailer-feed-dispatch', '7 */6 * * *',
                          'select public.trailer_feed_dispatch()');
    perform cron.schedule('trailer-feed-collect', '*/2 * * * *',
                          'select public.trailer_feed_collect()');
  end if;
end $$;

-- Start now rather than at the next 6-hour mark. The feed fills over the
-- following few minutes as titles are looked up.
select public.trailer_feed_dispatch();
