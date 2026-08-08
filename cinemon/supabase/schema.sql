-- Cinemon / 35mm — Supabase schema
-- Paste this whole file into the Supabase SQL Editor and hit Run.
-- Safe to re-run: everything is idempotent.

-- ─────────────────────────────────────────────────────────────
-- 1. PROFILES  (was Firestore `users`)
--    id mirrors auth.users.id — that IS the uid.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  email                 text        not null,
  username              text        not null unique,
  display_name          text,
  photo_url             text,
  bio                   text check (char_length(bio) <= 150),
  badge_ids             text[]      not null default '{}',
  favorite_genres       text[]      not null default '{}',
  favorite_film_ids     int[]       not null default '{}',
  favorite_actor_ids    int[]       not null default '{}',
  favorite_director_ids int[]       not null default '{}',
  review_count          int         not null default 0,
  follower_count        int         not null default 0,
  following_count       int         not null default 0,
  created_at            timestamptz not null default now()
);

-- case-insensitive username lookups (availability check + search)
create unique index if not exists profiles_username_lower_idx
  on public.profiles (lower(username));

-- ─────────────────────────────────────────────────────────────
-- 2. ACTIVITIES  (was `activities`)
--    Denormalized username/photo_url are GONE — join to profiles
--    instead. That fixes your "stale denormalized data" tech debt.
-- ─────────────────────────────────────────────────────────────
do $$ begin
  create type activity_type as enum ('watched', 'reviewed');
exception when duplicate_object then null; end $$;

create table if not exists public.activities (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  activity_type      activity_type not null,
  film_id            int  not null,
  film_title         text not null,
  film_poster_path   text,
  film_backdrop_path text,
  film_year          text,
  media_type         text not null default 'movie' check (media_type in ('movie','tv')),
  rating             numeric(2,1) check (rating >= 0.5 and rating <= 5),
  review_text        text,
  comment_count      int  not null default 0,
  created_at         timestamptz not null default now()
);

-- replaces your two required Firestore composite indexes
create index if not exists activities_user_created_idx
  on public.activities (user_id, created_at desc);
create index if not exists activities_created_idx
  on public.activities (created_at desc);
create index if not exists activities_film_idx
  on public.activities (film_id);

-- ─────────────────────────────────────────────────────────────
-- 3. LIKES + REACTIONS
--    Firestore stored these as an array / map on the doc, which
--    can't be queried or counted. Real tables here.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.activity_likes (
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id     uuid not null references public.profiles(id)   on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (activity_id, user_id)
);

-- reactions was Map<userId, stickerId> — one sticker per user per post
create table if not exists public.activity_reactions (
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id     uuid not null references public.profiles(id)   on delete cascade,
  sticker_id  text not null,
  created_at  timestamptz not null default now(),
  primary key (activity_id, user_id)
);

-- ─────────────────────────────────────────────────────────────
-- 4. COMMENTS  (was the `comments` subcollection)
-- ─────────────────────────────────────────────────────────────
create table if not exists public.comments (
  id          uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id     uuid not null references public.profiles(id)   on delete cascade,
  content     text not null check (char_length(content) between 1 and 1000),
  created_at  timestamptz not null default now()
);
create index if not exists comments_activity_idx
  on public.comments (activity_id, created_at);

-- ─────────────────────────────────────────────────────────────
-- 5. FRIENDSHIPS  (follow requests)
-- ─────────────────────────────────────────────────────────────
do $$ begin
  create type friendship_status as enum ('pending', 'accepted', 'declined');
exception when duplicate_object then null; end $$;

create table if not exists public.friendships (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status      friendship_status not null default 'pending',
  created_at  timestamptz not null default now(),
  accepted_at timestamptz,
  constraint no_self_follow check (sender_id <> receiver_id),
  unique (sender_id, receiver_id)
);
create index if not exists friendships_receiver_idx on public.friendships (receiver_id, status);
create index if not exists friendships_sender_idx   on public.friendships (sender_id,   status);

-- ─────────────────────────────────────────────────────────────
-- 6. NOTIFICATIONS
-- ─────────────────────────────────────────────────────────────
do $$ begin
  create type notification_type as enum
    ('like','comment','reaction','followRequest','followAccepted');
exception when duplicate_object then null; end $$;

create table if not exists public.notifications (
  id               uuid primary key default gen_random_uuid(),
  recipient_id     uuid not null references public.profiles(id) on delete cascade,
  actor_id         uuid not null references public.profiles(id) on delete cascade,
  type             notification_type not null,
  activity_id      uuid references public.activities(id) on delete cascade,
  film_title       text,
  film_poster_path text,
  comment_preview  text,
  sticker_id       text,
  is_read          boolean not null default false,
  created_at       timestamptz not null default now()
);
create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);
create index if not exists notifications_unread_idx
  on public.notifications (recipient_id) where not is_read;

-- ─────────────────────────────────────────────────────────────
-- 7. AUTO-CREATE PROFILE ON SIGNUP
--    Removes the "user exists in Auth but not in DB" failure mode.
--    Username defaults to a placeholder; profile-setup screen renames it.
-- ─────────────────────────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, username)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'username',
      'user_' || substr(replace(new.id::text, '-', ''), 1, 10)
    )
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- 8. COUNTER TRIGGERS  (keep counts honest without client writes)
-- ─────────────────────────────────────────────────────────────
create or replace function public.sync_comment_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.activities set comment_count = comment_count + 1 where id = new.activity_id;
  elsif tg_op = 'DELETE' then
    update public.activities set comment_count = greatest(comment_count - 1, 0) where id = old.activity_id;
  end if;
  return null;
end $$;

drop trigger if exists comments_count_trg on public.comments;
create trigger comments_count_trg
  after insert or delete on public.comments
  for each row execute function public.sync_comment_count();

create or replace function public.sync_review_count()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.profiles set review_count = review_count + 1 where id = new.user_id;
  elsif tg_op = 'DELETE' then
    update public.profiles set review_count = greatest(review_count - 1, 0) where id = old.user_id;
  end if;
  return null;
end $$;

drop trigger if exists activities_review_count_trg on public.activities;
create trigger activities_review_count_trg
  after insert or delete on public.activities
  for each row execute function public.sync_review_count();

-- Counts move only on accept / un-accept.
--
-- Friendship here is MUTUAL, not a one-way follow: once accepted, each user
-- both follows and is followed by the other. So both rows get +1 to BOTH
-- counters — matching how the app's areFriends/getFriendIds treat the edge.
create or replace function public.sync_follow_counts()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  delta int;
begin
  if tg_op = 'UPDATE' and new.status = 'accepted' and old.status <> 'accepted' then
    delta := 1;
  elsif tg_op = 'UPDATE' and old.status = 'accepted' and new.status <> 'accepted' then
    delta := -1;
  elsif tg_op = 'DELETE' and old.status = 'accepted' then
    delta := -1;
  else
    return null;
  end if;

  update public.profiles
     set following_count = greatest(following_count + delta, 0),
         follower_count  = greatest(follower_count  + delta, 0)
   where id in (
     coalesce(new.sender_id,   old.sender_id),
     coalesce(new.receiver_id, old.receiver_id)
   );
  return null;
end $$;

drop trigger if exists friendships_count_trg on public.friendships;
create trigger friendships_count_trg
  after update or delete on public.friendships
  for each row execute function public.sync_follow_counts();

-- ─────────────────────────────────────────────────────────────
-- 9. HELPER: are these two users mutually connected?
-- ─────────────────────────────────────────────────────────────
create or replace function public.is_following(target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships
    where status = 'accepted'
      and ((sender_id = auth.uid() and receiver_id = target)
        or (sender_id = target and receiver_id = auth.uid()))
  );
$$;

-- ─────────────────────────────────────────────────────────────
-- 10. ROW LEVEL SECURITY
--     Read-open (it's a social app), write-locked-to-owner.
-- ─────────────────────────────────────────────────────────────
alter table public.profiles           enable row level security;
alter table public.activities         enable row level security;
alter table public.activity_likes     enable row level security;
alter table public.activity_reactions enable row level security;
alter table public.comments           enable row level security;
alter table public.friendships        enable row level security;
alter table public.notifications      enable row level security;

drop policy if exists "profiles readable"    on public.profiles;
drop policy if exists "profiles self update" on public.profiles;
create policy "profiles readable"    on public.profiles for select to authenticated using (true);
create policy "profiles self update" on public.profiles for update to authenticated
  using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "activities readable" on public.activities;
drop policy if exists "activities own write" on public.activities;
create policy "activities readable"  on public.activities for select to authenticated using (true);
create policy "activities own write" on public.activities for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "likes readable" on public.activity_likes;
drop policy if exists "likes own write" on public.activity_likes;
create policy "likes readable"  on public.activity_likes for select to authenticated using (true);
create policy "likes own write" on public.activity_likes for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "reactions readable" on public.activity_reactions;
drop policy if exists "reactions own write" on public.activity_reactions;
create policy "reactions readable"  on public.activity_reactions for select to authenticated using (true);
create policy "reactions own write" on public.activity_reactions for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "comments readable" on public.comments;
drop policy if exists "comments own write" on public.comments;
create policy "comments readable"  on public.comments for select to authenticated using (true);
create policy "comments own write" on public.comments for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- either party can see the friendship; only the sender creates it,
-- only the receiver can accept/decline; either can delete (unfollow).
drop policy if exists "friendships visible"  on public.friendships;
drop policy if exists "friendships insert"   on public.friendships;
drop policy if exists "friendships respond"  on public.friendships;
drop policy if exists "friendships delete"   on public.friendships;
create policy "friendships visible" on public.friendships for select to authenticated
  using (auth.uid() in (sender_id, receiver_id));
create policy "friendships insert"  on public.friendships for insert to authenticated
  with check (auth.uid() = sender_id);
create policy "friendships respond" on public.friendships for update to authenticated
  using (auth.uid() = receiver_id) with check (auth.uid() = receiver_id);
create policy "friendships delete"  on public.friendships for delete to authenticated
  using (auth.uid() in (sender_id, receiver_id));

drop policy if exists "notifications own read"   on public.notifications;
drop policy if exists "notifications own update" on public.notifications;
drop policy if exists "notifications insert"     on public.notifications;
create policy "notifications own read"   on public.notifications for select to authenticated
  using (auth.uid() = recipient_id);
create policy "notifications own update" on public.notifications for update to authenticated
  using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);
-- you may only create a notification where YOU are the actor
create policy "notifications insert" on public.notifications for insert to authenticated
  with check (auth.uid() = actor_id);

-- ─────────────────────────────────────────────────────────────
-- 11. STORAGE  (was Firebase Storage — profile photos)
-- ─────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars public read" on storage.objects;
drop policy if exists "avatars own write"   on storage.objects;
create policy "avatars public read" on storage.objects for select
  using (bucket_id = 'avatars');
-- file must live under a folder named with the user's uid: avatars/<uid>/photo.jpg
create policy "avatars own write" on storage.objects for all to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ─────────────────────────────────────────────────────────────
-- 12. FEED VIEW — one query replaces the N+1 the Firestore code did
-- ─────────────────────────────────────────────────────────────
-- Shapes rows exactly like the client's ActivityModel: the author's
-- username/photo are joined live (never stale), and likes/reactions are
-- aggregated back into the array + map the app already expects.
--
-- Dropped first, not `create or replace`: replacing a view can add columns
-- but cannot rename or retype existing ones, so any change to the output
-- shape fails against an older version of this view.
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
