-- ADR 0004 D2 and D3: one-way follows, public accounts by default, and a
-- private switch that hides everything but the profile header from anyone
-- who doesn't follow you. Run after 016_notification_types. Idempotent.
--
-- `friendships` (mutual, request-only) is copied across once and then left
-- alone: builds from before this one still read it. A later migration drops
-- it once every tester is on the new build.

-- ── 1. Private accounts ──────────────────────────────────────
alter table public.profiles
  add column if not exists is_private boolean not null default false;

-- ── 2. Follows ───────────────────────────────────────────────
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followee_id uuid not null references public.profiles(id) on delete cascade,
  status      text not null default 'accepted'
              check (status in ('pending', 'accepted')),
  created_at  timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (follower_id, followee_id),
  constraint follows_not_self check (follower_id <> followee_id)
);
create index if not exists follows_followee_idx on public.follows (followee_id, status);
create index if not exists follows_follower_idx on public.follows (follower_id, status);

alter table public.follows enable row level security;

-- ── 3. Who you are to someone ────────────────────────────────
-- Whether the viewer follows [target], accepted. Replaces the mutual check of
-- the same name, which nothing called.
create or replace function public.is_following(target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.follows
     where follower_id = auth.uid() and followee_id = target
       and status = 'accepted'
  );
$$;

-- Whether the viewer may see [owner]'s content (ADR 0004 D3): their own; or,
-- with no block either way, a public account's or one they follow. Security
-- definer so it can read blocks and follows the viewer can't.
create or replace function public.can_see(owner uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select owner = auth.uid()
      or (
        not public.is_blocked_pair(auth.uid(), owner)
        and (
          not coalesce((select p.is_private from public.profiles p where p.id = owner), false)
          or exists (
            select 1 from public.follows f
             where f.follower_id = auth.uid() and f.followee_id = owner
               and f.status = 'accepted'
          )
        )
      );
$$;

-- ── 4. Following is decided by the server ────────────────────
-- A follow of a public account is accepted at once; of a private one, it's a
-- request. The client's status is ignored.
create or replace function public.follow_status_on_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce((select is_private from public.profiles where id = new.followee_id), false) then
    new.status := 'pending';
    new.accepted_at := null;
  else
    new.status := 'accepted';
    new.accepted_at := now();
  end if;
  new.created_at := now();
  return new;
end $$;

drop trigger if exists follows_status_on_insert on public.follows;
create trigger follows_status_on_insert
  before insert on public.follows
  for each row execute function public.follow_status_on_insert();

-- The only update is accepting a request, by the account being followed.
create or replace function public.guard_follow_update()
returns trigger language plpgsql as $$
begin
  if new.follower_id <> old.follower_id or new.followee_id <> old.followee_id then
    raise exception 'can''t move a follow';
  end if;
  if current_user in ('authenticated', 'anon') then
    if not (old.status = 'pending' and new.status = 'accepted') then
      raise exception 'only a pending request can be accepted';
    end if;
    new.accepted_at := now();
  end if;
  return new;
end $$;

drop trigger if exists follows_guard_update on public.follows;
create trigger follows_guard_update
  before update on public.follows
  for each row execute function public.guard_follow_update();

-- Rows: yours either way, pending included. Anyone else's only once accepted,
-- and only if both people are visible to you: a private account's followers
-- and following stay hidden from people who don't follow it, and it doesn't
-- turn up in a public account's lists either.
drop policy if exists "follows readable" on public.follows;
create policy "follows readable" on public.follows for select to authenticated
  using (
    auth.uid() in (follower_id, followee_id)
    or (status = 'accepted' and public.can_see(follower_id) and public.can_see(followee_id))
  );

drop policy if exists "follows insert own" on public.follows;
create policy "follows insert own" on public.follows for insert to authenticated
  with check (
    follower_id = auth.uid()
    and not public.is_blocked_pair(follower_id, followee_id)
  );

-- Accept: the followee.
drop policy if exists "follows accept" on public.follows;
create policy "follows accept" on public.follows for update to authenticated
  using (followee_id = auth.uid()) with check (followee_id = auth.uid());

-- Unfollow or cancel (the follower); decline or remove a follower (the
-- followee). All the same: the row goes.
drop policy if exists "follows delete" on public.follows;
create policy "follows delete" on public.follows for delete to authenticated
  using (auth.uid() in (follower_id, followee_id));

-- ── 5. Counts: one direction each ────────────────────────────
create or replace function public.sync_follows_counts()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  was_on boolean := tg_op in ('UPDATE', 'DELETE') and old.status = 'accepted';
  is_on  boolean := tg_op in ('INSERT', 'UPDATE') and new.status = 'accepted';
  f uuid := coalesce(new.follower_id, old.follower_id);
  t uuid := coalesce(new.followee_id, old.followee_id);
  delta int;
begin
  if was_on = is_on then
    return null;
  end if;
  delta := case when is_on then 1 else -1 end;
  update public.profiles set following_count = greatest(following_count + delta, 0) where id = f;
  update public.profiles set follower_count  = greatest(follower_count  + delta, 0) where id = t;
  return null;
end $$;

drop trigger if exists follows_count_trg on public.follows;
create trigger follows_count_trg
  after insert or update or delete on public.follows
  for each row execute function public.sync_follows_counts();

-- The old triggers counted both ways; they stay only for old builds writing
-- to friendships, and must not touch the counts any more.
drop trigger if exists friendships_count_trg on public.friendships;

-- ── 6. Notifications ─────────────────────────────────────────
create or replace function public.notify_on_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.create_notification(
      new.followee_id, new.follower_id,
      case when new.status = 'pending' then 'followRequest' else 'follow' end::notification_type);
    return new;
  end if;

  if tg_op = 'DELETE' then
    -- Unfollowed, cancelled or declined: the notifications about it go too.
    delete from public.notifications
     where type in ('follow', 'followRequest')
       and recipient_id = old.followee_id and actor_id = old.follower_id;
    delete from public.notifications
     where type = 'followAccepted'
       and recipient_id = old.follower_id and actor_id = old.followee_id;
    return old;
  end if;

  -- Accepted: the request becomes "started following you", and the follower
  -- hears it was approved.
  if old.status = 'pending' and new.status = 'accepted' then
    update public.notifications
       set type = 'follow', created_at = now(), is_read = false
     where type = 'followRequest'
       and recipient_id = new.followee_id and actor_id = new.follower_id;
    perform public.create_notification(new.follower_id, new.followee_id, 'followAccepted');
  end if;
  return new;
end $$;

drop trigger if exists on_follow on public.follows;
create trigger on_follow
  after insert or update or delete on public.follows
  for each row execute function public.notify_on_follow();

-- ── 7. Going public accepts every waiting request ────────────
create or replace function public.accept_requests_on_public()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.is_private and not new.is_private then
    update public.follows set status = 'accepted', accepted_at = now()
     where followee_id = new.id and status = 'pending';
  end if;
  return null;
end $$;

drop trigger if exists profiles_accept_on_public on public.profiles;
create trigger profiles_accept_on_public
  after update of is_private on public.profiles
  for each row execute function public.accept_requests_on_public();

-- ── 8. A block ends follows both ways ────────────────────────
create or replace function public.on_user_block()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.follows
   where (follower_id = new.blocker_id and followee_id = new.blocked_id)
      or (follower_id = new.blocked_id and followee_id = new.blocker_id);
  delete from public.friendships
   where (sender_id = new.blocker_id and receiver_id = new.blocked_id)
      or (sender_id = new.blocked_id and receiver_id = new.blocker_id);
  return null;
end $$;

-- ── 9. Everything else reads through can_see() ───────────────
-- Report-hide (014) stays in each policy.
drop policy if exists "activities readable" on public.activities;
create policy "activities readable" on public.activities for select to authenticated
  using (public.can_see(user_id) and not public.i_reported('activity', id));

-- Likes, reactions and comments go with the review they're on.
create or replace function public.can_see_activity(target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.activities a
     where a.id = target and public.can_see(a.user_id)
  );
$$;

drop policy if exists "likes readable" on public.activity_likes;
create policy "likes readable" on public.activity_likes for select to authenticated
  using (public.can_see_activity(activity_id));

drop policy if exists "reactions readable" on public.activity_reactions;
create policy "reactions readable" on public.activity_reactions for select to authenticated
  using (public.can_see_activity(activity_id));

drop policy if exists "comments readable" on public.comments;
create policy "comments readable" on public.comments for select to authenticated
  using (public.can_see_activity(activity_id) and not public.i_reported('activity_comment', id));

drop policy if exists "explore posts readable" on public.explore_posts;
create policy "explore posts readable" on public.explore_posts for select to authenticated
  using (public.can_see(user_id) and not public.i_reported('post', id));

-- A reply belongs to the post it's on: a private account's reply on a public
-- post shows, as on Instagram.
create or replace function public.can_see_post(target uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.explore_posts e
     where e.id = target and public.can_see(e.user_id)
  );
$$;

drop policy if exists "explore comments readable" on public.explore_comments;
create policy "explore comments readable" on public.explore_comments for select to authenticated
  using (public.can_see_post(post_id) and not public.i_reported('post_comment', id));

drop policy if exists "user badges readable" on public.user_badges;
create policy "user badges readable" on public.user_badges for select to authenticated
  using (public.can_see(user_id));

drop policy if exists "person follows readable" on public.person_follows;
create policy "person follows readable" on public.person_follows for select to authenticated
  using (public.can_see(user_id));

-- Lists: public ones need the owner to be visible; "friends" lists are now
-- for followers (the stored value stays 'friends').
create or replace function public.can_view_list(owner uuid, vis text)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select owner = auth.uid()
      or (
        not public.is_blocked_pair(auth.uid(), owner)
        and (
          (vis = 'public' and public.can_see(owner))
          or (vis = 'friends' and public.is_following(owner))
        )
      );
$$;

-- ── 10. Home: you and the people you follow ──────────────────
drop view if exists public.home_feed;
create view public.home_feed
with (security_invoker = true) as
with circle as (
  select auth.uid() as user_id
  union
  select f.followee_id from public.follows f
   where f.follower_id = auth.uid() and f.status = 'accepted'
)
select 'activity'::text as source, a.id, a.user_id, a.created_at
  from public.activities a
 where a.user_id in (select user_id from circle)
union all
select 'explore'::text as source, e.id, e.user_id, e.created_at
  from public.explore_posts e
 where e.user_id in (select user_id from circle);

grant select on public.home_feed to authenticated;

-- ── 11. Realtime, for the requests badge ─────────────────────
alter table public.follows replica identity full;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'follows'
  ) then
    alter publication supabase_realtime add table public.follows;
  end if;
end $$;

-- ── 12. Bring the friendships across, once ───────────────────
-- An accepted friendship was two people following each other, so it becomes
-- two follows. A pending one was someone asking to follow; everyone starts
-- public, and public accounts don't take requests, so it becomes a follow and
-- its notification "started following you". Declined ones are dropped. The
-- triggers are bypassed so the old dates survive and nobody is notified twice.
do $$
begin
  if not exists (select 1 from public.follows) then
    alter table public.follows disable trigger follows_status_on_insert;
    alter table public.follows disable trigger on_follow;
    alter table public.follows disable trigger follows_count_trg;

    insert into public.follows (follower_id, followee_id, status, created_at, accepted_at)
    select sender_id, receiver_id, 'accepted', created_at, coalesce(accepted_at, created_at)
      from public.friendships where status = 'accepted'
    union
    select receiver_id, sender_id, 'accepted', created_at, coalesce(accepted_at, created_at)
      from public.friendships where status = 'accepted'
    union
    select sender_id, receiver_id, 'accepted', created_at, created_at
      from public.friendships where status = 'pending'
    on conflict do nothing;

    update public.notifications set type = 'follow'
     where type = 'followRequest';

    alter table public.follows enable trigger follows_status_on_insert;
    alter table public.follows enable trigger on_follow;
    alter table public.follows enable trigger follows_count_trg;
  end if;
end $$;

-- Counts from scratch, one direction each.
update public.profiles p set
  follower_count  = (select count(*) from public.follows f
                      where f.followee_id = p.id and f.status = 'accepted'),
  following_count = (select count(*) from public.follows f
                      where f.follower_id = p.id and f.status = 'accepted');
