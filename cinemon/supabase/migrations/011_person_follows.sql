-- Following people, and alerts when they have new work (ADR 0001 Phase 6).
-- Run after 011a. Safe to re-run.
--
-- The whole job lives in Postgres: pg_cron runs it, pg_net calls TMDB, and
-- plain SQL diffs the credits and writes the notifications. No Edge Function
-- to deploy, and the logic is testable anywhere Postgres runs.
--
-- One-time setup, after running this file: store the TMDB key (the same v3
-- key the app uses) in Vault, from the SQL editor:
--
--   select vault.create_secret('<your TMDB v3 api key>', 'tmdb_api_key');
--
-- Until then the job runs and does nothing.

-- ── 0. Extensions ─────────────────────────────────────────────
-- Both ship with Supabase. Tolerated if missing, so the file still runs on a
-- plain Postgres for testing.
do $$ begin
  create extension if not exists pg_net with schema extensions;
exception when others then raise notice 'pg_net unavailable: %', sqlerrm;
end $$;
do $$ begin
  create extension if not exists pg_cron;
exception when others then raise notice 'pg_cron unavailable: %', sqlerrm;
end $$;

-- ── 1. Follows ────────────────────────────────────────────────
create table if not exists public.person_follows (
  user_id      uuid not null references public.profiles(id) on delete cascade,
  person_id    int  not null,
  -- Snapshotted, like film_title elsewhere: lists and alerts need no TMDB call.
  person_name  text not null check (char_length(person_name) between 1 and 200),
  profile_path text,
  department   text,
  created_at   timestamptz not null default now(),
  primary key (user_id, person_id)
);
create index if not exists person_follows_person_idx on public.person_follows (person_id);

alter table public.person_follows enable row level security;

-- Public, like favorites, blocks aside.
drop policy if exists "person follows readable"   on public.person_follows;
drop policy if exists "person follows own insert" on public.person_follows;
drop policy if exists "person follows own delete" on public.person_follows;
create policy "person follows readable" on public.person_follows for select to authenticated
  using (not public.is_blocked_pair(auth.uid(), user_id));
create policy "person follows own insert" on public.person_follows for insert to authenticated
  with check (auth.uid() = user_id);
create policy "person follows own delete" on public.person_follows for delete to authenticated
  using (auth.uid() = user_id);

-- Every followed person costs a TMDB call a day. A generous cap keeps one
-- account from turning that into thousands.
create or replace function public.cap_person_follows()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.person_follows where user_id = new.user_id) >= 500 then
    raise exception 'you can follow up to 500 people';
  end if;
  return new;
end $$;

drop trigger if exists person_follows_cap on public.person_follows;
create trigger person_follows_cap
  before insert on public.person_follows
  for each row execute function public.cap_person_follows();

-- ── 2. Alert rows ─────────────────────────────────────────────
-- A credit alert has no acting user, so actor_id becomes optional. The feed
-- reads actors with a left join already.
alter table public.notifications alter column actor_id drop not null;
alter table public.notifications add column if not exists person_id int;
alter table public.notifications add column if not exists person_name text;
alter table public.notifications add column if not exists person_profile_path text;
alter table public.notifications add column if not exists film_id int;
alter table public.notifications add column if not exists media_type text;

-- ── 3. Server state ───────────────────────────────────────────
-- What each person's credits looked like last time. No policies: only the
-- job reads or writes these.
create table if not exists public.person_credit_snapshots (
  person_id   int primary key,
  credit_keys text[] not null,
  checked_at  timestamptz not null
);
alter table public.person_credit_snapshots enable row level security;

-- Calls in flight: pg_net answers asynchronously, into net._http_response.
create table if not exists public.person_watch_requests (
  request_id bigint primary key,
  person_id  int not null,
  created_at timestamptz not null default now()
);
alter table public.person_watch_requests enable row level security;

-- ── 4. The diff ───────────────────────────────────────────────
-- One person's combined_credits, compared with the snapshot. New credits on
-- recent or upcoming titles become alerts for everyone following them.
--
-- The first look at a person only records what's there, so following
-- someone never floods you with their back catalogue.
create or replace function public.person_watch_ingest(pid int, body jsonb)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  previous text[];
  sent     int := 0;
begin
  -- Everything credited, as 'movie:123:cast' / 'tv:456:crew:Director'.
  create temp table if not exists _credits (
    key text, media_type text, film_id int, title text, poster text,
    released date, role text, notable boolean
  ) on commit drop;
  truncate _credits;

  insert into _credits
  select
    c->>'media_type' || ':' || (c->>'id') || ':' ||
      case when kind = 'cast' then 'cast' else 'crew:' || coalesce(c->>'job', '') end,
    c->>'media_type',
    (c->>'id')::int,
    coalesce(c->>'title', c->>'name'),
    c->>'poster_path',
    nullif(coalesce(c->>'release_date', c->>'first_air_date'), '')::date,
    case when kind = 'cast'
         then case when coalesce(c->>'character', '') = '' then 'Cast'
                   else 'as ' || (c->>'character') end
         else c->>'job' end,
    -- What's worth telling someone about. Talk shows, news and reality TV
    -- would turn every press tour into a stream of alerts, and "Self" is how
    -- TMDB marks an appearance as yourself.
    not (
      coalesce(c->'genre_ids', '[]'::jsonb) @> '[10767]'
      or coalesce(c->'genre_ids', '[]'::jsonb) @> '[10763]'
      or coalesce(c->'genre_ids', '[]'::jsonb) @> '[10764]'
      or (kind = 'cast' and coalesce(c->>'character', '') ~* '(^|\W)(self|himself|herself|themselves)(\W|$)')
      or (kind = 'crew' and coalesce(c->>'job', '') in ('Thanks', 'Executive Producer', 'Characters'))
    )
  from (
    select 'cast' as kind, x as c from jsonb_array_elements(coalesce(body->'cast', '[]')) x
    union all
    select 'crew', x from jsonb_array_elements(coalesce(body->'crew', '[]')) x
  ) s
  where c->>'media_type' in ('movie', 'tv') and c ? 'id';

  select credit_keys into previous from public.person_credit_snapshots where person_id = pid;

  if previous is not null then
    with fresh as (
      -- New, notable, and recent or still to come. An old film newly added
      -- to TMDB isn't news.
      select * from _credits
       where notable
         and not (key = any(previous))
         and (released is null or released >= current_date - 180)
    ),
    titles as (
      -- One alert per title, however many jobs they have on it.
      select media_type, film_id,
             min(title) as title, min(poster) as poster, max(released) as released,
             string_agg(distinct role, ' · ') as role
        from fresh
       group by media_type, film_id
       order by max(released) desc nulls first
       -- A burst of catalogue edits shouldn't bury anyone.
       limit 3
    ),
    ins as (
      insert into public.notifications (
        recipient_id, actor_id, type, film_title, film_poster_path,
        comment_preview, person_id, person_name, person_profile_path,
        film_id, media_type
      )
      select f.user_id, null, 'personNewCredit', t.title, t.poster,
             t.role, pid, f.person_name, f.profile_path,
             t.film_id, t.media_type
        from titles t
        join public.person_follows f on f.person_id = pid
       where not exists (
         select 1 from public.notifications n
          where n.recipient_id = f.user_id and n.type = 'personNewCredit'
            and n.person_id = pid and n.film_id = t.film_id
            and n.media_type = t.media_type
       )
      returning 1
    )
    select count(*) into sent from ins;
  end if;

  -- Remember everything seen, ever: a credit that drops off TMDB and comes
  -- back isn't new the second time.
  insert into public.person_credit_snapshots (person_id, credit_keys, checked_at)
  values (
    pid,
    array(select distinct k from unnest(coalesce(previous, '{}') || array(select key from _credits)) k),
    now()
  )
  on conflict (person_id) do update
    set credit_keys = excluded.credit_keys, checked_at = excluded.checked_at;

  return sent;
end $$;

revoke all on function public.person_watch_ingest(int, jsonb) from public, anon, authenticated;

-- ── 5. The schedule ───────────────────────────────────────────
-- Dispatch: ask TMDB about the people most overdue for a check, a few at a
-- time so the calls stay well under TMDB's rate limit. Every 15 minutes at
-- 40 people is ~3,800 people a day, each checked daily.
create or replace function public.person_watch_dispatch(batch int default 40)
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  api_key text;
  p       record;
  n       int := 0;
begin
  begin
    select decrypted_secret into api_key
      from vault.decrypted_secrets where name = 'tmdb_api_key' limit 1;
  exception when others then
    api_key := null;
  end;
  if api_key is null then
    return 0;
  end if;

  for p in
    select f.person_id
      from (select distinct person_id from public.person_follows) f
      left join public.person_credit_snapshots s on s.person_id = f.person_id
     where (s.checked_at is null or s.checked_at < now() - interval '20 hours')
       and not exists (select 1 from public.person_watch_requests r where r.person_id = f.person_id)
     order by s.checked_at nulls first
     limit batch
  loop
    insert into public.person_watch_requests (request_id, person_id)
    values (
      net.http_get(
        url := 'https://api.themoviedb.org/3/person/' || p.person_id
               || '/combined_credits?api_key=' || api_key,
        timeout_milliseconds := 15000
      ),
      p.person_id
    );
    n := n + 1;
  end loop;
  return n;
end $$;

-- Collect: read whatever has come back and diff it. Failures are dropped
-- and simply retried by a later dispatch, since the snapshot didn't move.
create or replace function public.person_watch_collect()
returns int
language plpgsql
security definer set search_path = public
as $$
declare
  r    record;
  sent int := 0;
begin
  for r in
    select q.request_id, q.person_id, h.status_code, h.content
      from public.person_watch_requests q
      join net._http_response h on h.id = q.request_id
  loop
    if r.status_code = 200 then
      begin
        sent := sent + public.person_watch_ingest(r.person_id, r.content::jsonb);
      exception when others then
        raise warning 'person_watch_ingest(%) failed: %', r.person_id, sqlerrm;
      end;
    end if;
    delete from public.person_watch_requests where request_id = r.request_id;
  end loop;

  -- Anything unanswered for an hour is lost; let it be asked again.
  delete from public.person_watch_requests where created_at < now() - interval '1 hour';
  return sent;
end $$;

revoke all on function public.person_watch_dispatch(int) from public, anon, authenticated;
revoke all on function public.person_watch_collect()     from public, anon, authenticated;

do $$ begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('person-watch-dispatch', '*/15 * * * *',
                          'select public.person_watch_dispatch()');
    perform cron.schedule('person-watch-collect', '*/5 * * * *',
                          'select public.person_watch_collect()');
  end if;
end $$;
