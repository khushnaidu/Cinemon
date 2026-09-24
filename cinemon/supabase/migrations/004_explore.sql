-- Explore: public posts from everyone — hot takes, reviews, critiques,
-- discussions, plain thoughts — optionally about one film, show or episode.
-- Safe to re-run.
--
-- A separate table rather than more rows in `activities`. An activity is a
-- diary entry ("I watched this"), always about exactly one title, and it
-- drives the home feed, profile grids and review counts. An Explore post is
-- conversation: it may be about nothing in particular, and it must never
-- appear in someone's diary. Sharing the table would mean filtering one kind
-- out of every existing query forever.

-- ── 1. Posts ──────────────────────────────────────────────────
create table if not exists public.explore_posts (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  kind               text not null default 'thought'
                     check (kind in ('thought', 'take', 'review', 'critique', 'discussion')),
  headline           text check (char_length(headline) <= 120),
  body               text not null check (char_length(body) between 1 and 4000),
  rating             numeric(2,1) check (rating >= 0.5 and rating <= 5),
  has_spoilers       boolean not null default false,

  -- The optional subject. Denormalised like activities, so a feed page is one
  -- query and never a TMDB round trip per card.
  media_type         text check (media_type in ('movie', 'tv')),
  film_id            int,
  film_title         text,
  film_poster_path   text,
  film_backdrop_path text,
  film_year          text,
  season_number      int,
  episode_number     int,
  episode_title      text,
  episode_still_path text,

  -- Trigger-maintained. For a hot take the two vote columns are agree /
  -- disagree; for every other kind only agree_count moves, and it's a like.
  agree_count        int not null default 0,
  disagree_count     int not null default 0,
  comment_count      int not null default 0,
  created_at         timestamptz not null default now(),
  -- Set by trigger when the content changes; null means never edited.
  updated_at         timestamptz,

  -- A subject is all-or-nothing.
  constraint explore_subject_coherent check (
    (film_id is null and film_title is null and media_type is null)
    or (film_id is not null and film_title is not null and media_type is not null)
  ),
  -- An episode belongs to a show, and needs both numbers.
  constraint explore_episode_coherent check (
    (season_number is null and episode_number is null)
    or (season_number is not null and episode_number is not null
        and media_type = 'tv')
  ),
  -- A review is of something, and a critique has a title.
  constraint explore_review_has_subject check (kind <> 'review' or film_id is not null),
  constraint explore_critique_has_headline check (kind <> 'critique' or headline is not null),
  -- Hot takes are short by definition.
  constraint explore_take_is_short check (kind <> 'take' or char_length(body) <= 280)
);

-- For databases that ran an earlier copy of this file.
alter table public.explore_posts add column if not exists updated_at timestamptz;

create index if not exists explore_posts_created_idx
  on public.explore_posts (created_at desc);
create index if not exists explore_posts_subject_idx
  on public.explore_posts (film_id, media_type, created_at desc)
  where film_id is not null;
create index if not exists explore_posts_user_idx
  on public.explore_posts (user_id, created_at desc);
create index if not exists explore_posts_kind_idx
  on public.explore_posts (kind, created_at desc);

-- ── 2. Votes ──────────────────────────────────────────────────
-- One row per user per post. value 1 is a like (or "agree" on a hot take),
-- -1 is "disagree" and only means anything on a hot take.
create table if not exists public.explore_post_votes (
  post_id    uuid not null references public.explore_posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id)      on delete cascade,
  value      smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- ── 3. Comments ───────────────────────────────────────────────
create table if not exists public.explore_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.explore_posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id)      on delete cascade,
  content    text not null check (char_length(content) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists explore_comments_post_idx
  on public.explore_comments (post_id, created_at);

-- ── 4. Reports ────────────────────────────────────────────────
-- App Store guideline 1.2: public user-generated content needs a way to flag
-- it. Write-only from the client; reviewed from the dashboard.
create table if not exists public.content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  post_id     uuid references public.explore_posts(id) on delete cascade,
  comment_id  uuid references public.explore_comments(id) on delete cascade,
  reason      text not null check (char_length(reason) between 1 and 200),
  created_at  timestamptz not null default now(),
  constraint content_reports_target check (post_id is not null or comment_id is not null),
  unique (reporter_id, post_id)
);

-- ── 5. Counters ───────────────────────────────────────────────
-- security definer: a voter can't update someone else's post under RLS, and
-- shouldn't be able to — only the trigger writes these columns.
create or replace function public.sync_explore_votes()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op in ('DELETE', 'UPDATE') then
    update public.explore_posts
       set agree_count    = greatest(agree_count    - (old.value =  1)::int, 0),
           disagree_count = greatest(disagree_count - (old.value = -1)::int, 0)
     where id = old.post_id;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    update public.explore_posts
       set agree_count    = agree_count    + (new.value =  1)::int,
           disagree_count = disagree_count + (new.value = -1)::int
     where id = new.post_id;
  end if;
  return null;
end $$;

drop trigger if exists explore_votes_count_trg on public.explore_post_votes;
create trigger explore_votes_count_trg
  after insert or update or delete on public.explore_post_votes
  for each row execute function public.sync_explore_votes();

create or replace function public.sync_explore_comment_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.explore_posts set comment_count = comment_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update public.explore_posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end $$;

drop trigger if exists explore_comments_count_trg on public.explore_comments;
create trigger explore_comments_count_trg
  after insert or delete on public.explore_comments
  for each row execute function public.sync_explore_comment_count();

-- Stamp edits. Only content counts: the counters above update this row too,
-- and a vote must not mark someone's post as edited.
create or replace function public.stamp_explore_edit()
returns trigger language plpgsql as $$
begin
  if (new.body, new.headline, new.rating, new.has_spoilers,
      new.film_id, new.media_type, new.season_number, new.episode_number)
     is distinct from
     (old.body, old.headline, old.rating, old.has_spoilers,
      old.film_id, old.media_type, old.season_number, old.episode_number)
  then
    new.updated_at := now();
  else
    new.updated_at := old.updated_at;
  end if;
  -- Nobody rewrites history or moves a post to another author.
  new.created_at := old.created_at;
  new.user_id := old.user_id;
  new.kind := old.kind;
  return new;
end $$;

drop trigger if exists explore_posts_edit_trg on public.explore_posts;
create trigger explore_posts_edit_trg
  before update on public.explore_posts
  for each row execute function public.stamp_explore_edit();

-- ── 6. RLS ────────────────────────────────────────────────────
alter table public.explore_posts      enable row level security;
alter table public.explore_post_votes enable row level security;
alter table public.explore_comments   enable row level security;
alter table public.content_reports    enable row level security;

drop policy if exists "explore posts readable"  on public.explore_posts;
drop policy if exists "explore posts own write" on public.explore_posts;
create policy "explore posts readable"  on public.explore_posts for select to authenticated using (true);
create policy "explore posts own write" on public.explore_posts for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "explore votes readable"  on public.explore_post_votes;
drop policy if exists "explore votes own write" on public.explore_post_votes;
create policy "explore votes readable"  on public.explore_post_votes for select to authenticated using (true);
create policy "explore votes own write" on public.explore_post_votes for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "explore comments readable" on public.explore_comments;
drop policy if exists "explore comments insert"   on public.explore_comments;
drop policy if exists "explore comments delete"   on public.explore_comments;
create policy "explore comments readable" on public.explore_comments for select to authenticated using (true);
create policy "explore comments insert" on public.explore_comments for insert to authenticated
  with check (auth.uid() = user_id);
-- Your own comment, or any comment on your own post: a public thread needs
-- its author to be able to clear out abuse.
create policy "explore comments delete" on public.explore_comments for delete to authenticated
  using (
    auth.uid() = user_id
    or auth.uid() = (select e.user_id from public.explore_posts e where e.id = post_id)
  );

drop policy if exists "reports insert own" on public.content_reports;
create policy "reports insert own" on public.content_reports for insert to authenticated
  with check (auth.uid() = reporter_id);

-- ── 7. Feed view ──────────────────────────────────────────────
-- Author joined live, plus the viewer's own vote so the client can draw the
-- lit state without a second query.
drop view if exists public.explore_feed;
create view public.explore_feed
with (security_invoker = true) as
select
  e.*,
  p.username,
  p.photo_url as user_photo_url,
  (select v.value from public.explore_post_votes v
    where v.post_id = e.id and v.user_id = auth.uid()) as my_vote
from public.explore_posts e
join public.profiles p on p.id = e.user_id;

grant select on public.explore_feed to authenticated;
