-- Playlists on Explore, and Explore posts in the home feed (ADR 0001
-- Phase 5, D12 and D13). Run after 009. Safe to re-run.

-- ── 1. A post can be a playlist ───────────────────────────────
alter table public.explore_posts
  add column if not exists list_id uuid references public.lists(id) on delete cascade;
create index if not exists explore_posts_list_idx
  on public.explore_posts (list_id) where list_id is not null;

alter table public.explore_posts drop constraint if exists explore_posts_kind_check;
alter table public.explore_posts add constraint explore_posts_kind_check
  check (kind in ('thought', 'take', 'review', 'critique', 'discussion', 'list'));

-- A list post's text is an optional caption, so it may be empty. Everything
-- else still needs a body.
alter table public.explore_posts drop constraint if exists explore_posts_body_check;
alter table public.explore_posts add constraint explore_posts_body_check
  check (char_length(body) <= 4000 and (kind = 'list' or char_length(body) >= 1));

alter table public.explore_posts drop constraint if exists explore_list_coherent;
alter table public.explore_posts add constraint explore_list_coherent
  check ((kind = 'list') = (list_id is not null));

-- The playlist is the subject. It carries no film, rating or title of its
-- own, and its caption is short.
alter table public.explore_posts drop constraint if exists explore_list_shape;
alter table public.explore_posts add constraint explore_list_shape
  check (kind <> 'list' or (film_id is null and rating is null and headline is null
                            and char_length(body) <= 500));

-- Only your own playlist, only while it's public, and at most three times.
-- If it goes private
-- later the feed view hides the post; deleting it deletes the post.
create or replace function public.check_explore_list_post()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.list_id is not null and not exists (
    select 1 from public.lists l
     where l.id = new.list_id
       and l.user_id = new.user_id
       and l.kind = 'playlist'
       and l.visibility = 'public'
  ) then
    raise exception 'only your own public playlists can be posted';
  end if;
  -- Posting a list again when it's grown is fair; flooding Explore isn't.
  if new.list_id is not null and (
    select count(*) from public.explore_posts where list_id = new.list_id
  ) >= 3 then
    raise exception 'a playlist can be posted to Explore at most 3 times';
  end if;
  return new;
end $$;

drop trigger if exists explore_posts_check_list on public.explore_posts;
create trigger explore_posts_check_list
  before insert on public.explore_posts
  for each row execute function public.check_explore_list_post();

-- The list a post is about is as fixed as its kind.
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
  new.created_at := old.created_at;
  new.user_id := old.user_id;
  new.kind := old.kind;
  new.list_id := old.list_id;
  return new;
end $$;

-- A list invites "you forgot X", so list posts take comments.
drop policy if exists "explore comments insert" on public.explore_comments;
create policy "explore comments insert" on public.explore_comments for insert to authenticated
  with check (
    auth.uid() = user_id
    and not public.is_suspended(auth.uid())
    and exists (
      select 1 from public.explore_posts e
       where e.id = post_id and e.kind in ('thought', 'discussion', 'list')
    )
  );

-- ── 2. The Explore feed carries the list ──────────────────────
-- Title, count and first four posters, so a list card draws without a
-- second query. The join runs as the viewer: a list they can't see (private,
-- or its owner blocked them) drops the post.
drop view if exists public.explore_feed;
create view public.explore_feed
with (security_invoker = true) as
select
  e.*,
  p.username,
  p.photo_url as user_photo_url,
  (select v.value from public.explore_post_votes v
    where v.post_id = e.id and v.user_id = auth.uid()) as my_vote,
  l.title       as list_title,
  l.description as list_description,
  l.item_count  as list_item_count,
  case when l.id is null then null else
    (select coalesce(array_agg(i.film_poster_path order by i.position), '{}')
       from (select film_poster_path, position from public.list_items
              where list_id = l.id order by position limit 4) i)
  end as list_posters
from public.explore_posts e
join public.profiles p on p.id = e.user_id
left join public.lists l on l.id = e.list_id
where not exists (
  select 1 from public.content_reports r
   where r.post_id = e.id and r.reporter_id = auth.uid()
)
and (e.list_id is null or l.visibility = 'public');

grant select on public.explore_feed to authenticated;

-- ── 3. Home feed: activities and Explore posts, one timeline ──
-- Thin references only; the app hydrates each page from feed_activities and
-- explore_feed. You and the people you follow each other with.
-- Paged by (created_at, id) rather than offset, so rows landing in either
-- table mid-scroll can't shift a page.
drop view if exists public.home_feed;
create view public.home_feed
with (security_invoker = true) as
with circle as (
  select auth.uid() as user_id
  union
  select case when f.sender_id = auth.uid() then f.receiver_id else f.sender_id end
    from public.friendships f
   where f.status = 'accepted'
     and auth.uid() in (f.sender_id, f.receiver_id)
)
select 'activity'::text as source, a.id, a.user_id, a.created_at
  from public.activities a
 where a.user_id in (select user_id from circle)
union all
select 'explore'::text as source, e.id, e.user_id, e.created_at
  from public.explore_posts e
 where e.user_id in (select user_id from circle);

grant select on public.home_feed to authenticated;
