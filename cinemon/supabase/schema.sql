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
  -- Spoken review. The waveform is amplitude peaks sampled while recording,
  -- 0..1 — stored with the row because deriving it on read means every client
  -- that scrolls past the card downloads and decodes the audio just to find
  -- out what shape to draw.
  voice_note_url         text,
  voice_note_duration_ms int    not null default 0,
  voice_note_waveform    real[] not null default '{}',
  photo_urls             text[] not null default '{}',
  comment_count      int  not null default 0,
  created_at         timestamptz not null default now(),
  -- A voice note is only meaningful with a duration, and a duration with no
  -- url is a half-written row. 10s is the recording cap, plus slack for
  -- encoder overshoot.
  constraint activities_voice_note_coherent check (
    (voice_note_url is null and voice_note_duration_ms = 0)
    or (voice_note_url is not null
        and voice_note_duration_ms > 0
        and voice_note_duration_ms <= 11000)
  ),
  -- Four is what the stack on the card back can show without the ones
  -- underneath becoming invisible.
  constraint activities_photo_urls_bounded check (
    array_length(photo_urls, 1) is null or array_length(photo_urls, 1) <= 4
  )
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
drop policy if exists "notifications delete"     on public.notifications;
create policy "notifications own read"   on public.notifications for select to authenticated
  using (auth.uid() = recipient_id);
create policy "notifications own update" on public.notifications for update to authenticated
  using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);
-- you may only create a notification where YOU are the actor
create policy "notifications insert" on public.notifications for insert to authenticated
  with check (auth.uid() = actor_id);
-- Both parties can delete: the recipient dismisses or clears their feed, and
-- the actor retracts one when they unlike / un-react. Without the actor case,
-- unliking leaves the "liked your post" notification behind forever.
--
-- A missing DELETE policy does NOT raise an error — it matches zero rows and
-- PostgREST still answers 204, so every delete looks like it worked while
-- nothing changed. Deletes that silently no-op are the symptom to watch for.
create policy "notifications delete" on public.notifications for delete to authenticated
  using (auth.uid() in (recipient_id, actor_id));

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

-- Voice notes and photos attached to a review. One bucket for both: they
-- share a lifetime — an activity's media dies with the activity — and
-- splitting them would only duplicate these policies.
--
-- Public read, matching avatars: these URLs are embedded in feed cards that
-- every friend renders, and signing each one would cost a round trip per card.
insert into storage.buckets (id, name, public)
values ('review-media', 'review-media', true)
on conflict (id) do nothing;

drop policy if exists "review media public read" on storage.objects;
drop policy if exists "review media own write"   on storage.objects;
create policy "review media public read" on storage.objects for select
  using (bucket_id = 'review-media');
-- review-media/<uid>/<activity_id>/<file>. The uid-first layout is what makes
-- the policy work, and it also makes deleting an activity's media a prefix
-- delete that nothing else can be caught by.
create policy "review media own write" on storage.objects for all to authenticated
  using (bucket_id = 'review-media' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'review-media' and (storage.foldername(name))[1] = auth.uid()::text);

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

-- ─────────────────────────────────────────────────────────────
-- 13. REALTIME
-- ─────────────────────────────────────────────────────────────
-- Every repository that calls `.stream()` needs its table published here.
-- A new Supabase project creates the `supabase_realtime` publication empty,
-- so without this the streams still deliver their initial fetch and then go
-- permanently silent — it looks like a working screen that never updates,
-- which is much harder to spot than an outright error.
--
-- `replica identity full` makes Postgres put the whole old row in the WAL on
-- delete/update. Realtime needs it to evaluate the client's filter (the
-- `.eq('recipient_id', ...)` on the stream) against a DELETE, which otherwise
-- carries only the primary key and would be dropped instead of forwarded.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'activities', 'friendships', 'notifications'
  ] loop
    execute format('alter table public.%I replica identity full', t);
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ─────────────────────────────────────────────────────────────
-- 14. NOTIFICATION TRIGGERS
-- ─────────────────────────────────────────────────────────────
-- Notifications are written here, never by the client. Two reasons:
--
--   * The client physically cannot. A notification is always for someone
--     else, and the select policy only exposes a row to its recipient, so an
--     insert that reads itself back is rolled back by RLS.
--   * The row already knows everything. Deriving recipient, film title and
--     poster from the activity removes the chance of a caller forgetting to
--     thread them through the widget tree, and means a client that crashes
--     mid-action can't leave the interaction recorded but unannounced.

-- 3. The one place a notification gets written ──────────────
-- security definer so the trigger can write a row the acting user could never
-- insert themselves (they can't see it afterwards — see bug 1).
create or replace function public.create_notification(
  p_recipient       uuid,
  p_actor           uuid,
  p_type            notification_type,
  p_activity        uuid default null,
  p_film_title      text default null,
  p_film_poster     text default null,
  p_comment_preview text default null,
  p_sticker         text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  -- No self-notifications, and nothing for an activity that vanished.
  if p_recipient is null or p_actor is null or p_recipient = p_actor then
    return;
  end if;

  insert into public.notifications (
    recipient_id, actor_id, type, activity_id,
    film_title, film_poster_path, comment_preview, sticker_id
  ) values (
    p_recipient, p_actor, p_type, p_activity,
    p_film_title, p_film_poster, p_comment_preview, p_sticker
  );
end $$;

-- A security-definer function in `public` is reachable over the REST API and
-- runs as its owner, so leaving EXECUTE open would let any signed-in user
-- forge a notification from anyone to anyone. Triggers call it as the table
-- owner and are unaffected by this revoke.
revoke all on function public.create_notification(
  uuid, uuid, notification_type, uuid, text, text, text, text
) from public, anon, authenticated;

-- 4. Likes ──────────────────────────────────────────────────
create or replace function public.notify_on_like()
returns trigger language plpgsql security definer set search_path = public as $$
declare a public.activities%rowtype;
begin
  if tg_op = 'INSERT' then
    select * into a from public.activities where id = new.activity_id;
    perform public.create_notification(
      a.user_id, new.user_id, 'like', new.activity_id,
      a.film_title, a.film_poster_path);
    return new;
  end if;

  -- Unlike retracts the notification.
  delete from public.notifications
   where type = 'like'
     and activity_id = old.activity_id
     and actor_id = old.user_id;
  return old;
end $$;

drop trigger if exists on_activity_like on public.activity_likes;
create trigger on_activity_like
  after insert or delete on public.activity_likes
  for each row execute function public.notify_on_like();

-- 5. Reactions ──────────────────────────────────────────────
create or replace function public.notify_on_reaction()
returns trigger language plpgsql security definer set search_path = public as $$
declare a public.activities%rowtype;
begin
  if tg_op = 'DELETE' then
    delete from public.notifications
     where type = 'reaction'
       and activity_id = old.activity_id
       and actor_id = old.user_id;
    return old;
  end if;

  select * into a from public.activities where id = new.activity_id;

  -- Swapping sticker updates the existing row rather than stacking a second
  -- notification, so cycling through the picker doesn't spam the recipient.
  if tg_op = 'UPDATE' then
    update public.notifications
       set sticker_id = new.sticker_id, is_read = false, created_at = now()
     where type = 'reaction'
       and activity_id = new.activity_id
       and actor_id = new.user_id;
    if found then
      return new;
    end if;
  end if;

  perform public.create_notification(
    a.user_id, new.user_id, 'reaction', new.activity_id,
    a.film_title, a.film_poster_path, null, new.sticker_id);
  return new;
end $$;

drop trigger if exists on_activity_reaction on public.activity_reactions;
create trigger on_activity_reaction
  after insert or update or delete on public.activity_reactions
  for each row execute function public.notify_on_reaction();

-- 6. Comments ───────────────────────────────────────────────
create or replace function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare a public.activities%rowtype;
begin
  select * into a from public.activities where id = new.activity_id;
  perform public.create_notification(
    a.user_id, new.user_id, 'comment', new.activity_id,
    a.film_title, a.film_poster_path,
    case when char_length(new.content) > 50
         then left(new.content, 50) || '...'
         else new.content end);
  return new;
end $$;

drop trigger if exists on_comment on public.comments;
create trigger on_comment
  after insert on public.comments
  for each row execute function public.notify_on_comment();

-- 7. Follow requests ────────────────────────────────────────
create or replace function public.notify_on_friendship()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if new.status = 'pending' then
      perform public.create_notification(
        new.receiver_id, new.sender_id, 'followRequest');
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    -- Unfollow / cancelled request: drop both sides of the exchange.
    delete from public.notifications
     where type in ('followRequest', 'followAccepted')
       and recipient_id in (old.sender_id, old.receiver_id)
       and actor_id     in (old.sender_id, old.receiver_id);
    return old;
  end if;

  -- Answering a request clears it either way; accepting also tells the sender.
  if new.status is distinct from old.status
     and new.status in ('accepted', 'declined') then
    delete from public.notifications
     where type = 'followRequest'
       and recipient_id = new.receiver_id
       and actor_id     = new.sender_id;

    if new.status = 'accepted' then
      perform public.create_notification(
        new.sender_id, new.receiver_id, 'followAccepted');
    end if;
  end if;
  return new;
end $$;

drop trigger if exists on_friendship on public.friendships;
create trigger on_friendship
  after insert or update or delete on public.friendships
  for each row execute function public.notify_on_friendship();
