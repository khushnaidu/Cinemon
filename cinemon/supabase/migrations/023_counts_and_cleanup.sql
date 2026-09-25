-- Counts that always match, and notifications that leave with what they
-- were about. Run after 022. Idempotent; safe to run again whenever a count
-- looks wrong, since section 4 recounts everything from the rows themselves.

-- ── 1. The count triggers, recreated ─────────────────────────
-- The same bodies the schema and 004/008/017 define. Recreated here so the
-- live project is certain to have them however it was first set up. Every
-- one runs as the owner, so they work whoever writes (a commenter deleting
-- their comment on someone else's review can't update that review), and
-- never goes below zero.
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
create trigger comments_count_trg after insert or delete on public.comments
  for each row execute function public.sync_comment_count();

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
create trigger explore_comments_count_trg after insert or delete on public.explore_comments
  for each row execute function public.sync_explore_comment_count();

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
create trigger explore_votes_count_trg after insert or update or delete on public.explore_post_votes
  for each row execute function public.sync_explore_votes();

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
create trigger activities_review_count_trg after insert or delete on public.activities
  for each row execute function public.sync_review_count();

create or replace function public.sync_list_items()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.lists set item_count = item_count + 1, updated_at = now() where id = new.list_id;
  elsif tg_op = 'DELETE' then
    update public.lists set item_count = greatest(item_count - 1, 0), updated_at = now() where id = old.list_id;
  else
    update public.lists set updated_at = now() where id = new.list_id;
  end if;
  return null;
end $$;
drop trigger if exists list_items_sync on public.list_items;
create trigger list_items_sync after insert or update or delete on public.list_items
  for each row execute function public.sync_list_items();

create or replace function public.sync_list_saves()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.lists set save_count = save_count + 1 where id = new.list_id;
  else
    update public.lists set save_count = greatest(save_count - 1, 0) where id = old.list_id;
  end if;
  return null;
end $$;
drop trigger if exists list_saves_sync on public.list_saves;
create trigger list_saves_sync after insert or delete on public.list_saves
  for each row execute function public.sync_list_saves();

-- ── 2. Comment notifications go with their comment ───────────
-- Each "commented" / "replied" notification now points at its comment, and
-- the foreign key deletes it when the comment is deleted (by its author, by
-- a moderator, or with the review or post it was on).
alter table public.notifications
  add column if not exists comment_id uuid references public.comments(id) on delete cascade;
alter table public.notifications
  add column if not exists explore_comment_id uuid references public.explore_comments(id) on delete cascade;
create index if not exists notifications_comment_idx
  on public.notifications (comment_id) where comment_id is not null;
create index if not exists notifications_explore_comment_idx
  on public.notifications (explore_comment_id) where explore_comment_id is not null;

create or replace function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  a public.activities%rowtype;
begin
  select * into a from public.activities where id = new.activity_id;
  if not found or a.user_id = new.user_id then
    return new;
  end if;
  insert into public.notifications
    (recipient_id, actor_id, type, activity_id, comment_id,
     film_title, film_poster_path, comment_preview)
  values
    (a.user_id, new.user_id, 'comment', new.activity_id, new.id,
     a.film_title, a.film_poster_path,
     case when char_length(new.content) > 50
          then left(new.content, 50) || '...' else new.content end);
  return new;
end $$;

create or replace function public.notify_on_explore_comment()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  e public.explore_posts;
  parent_author uuid;
  preview text := case when char_length(new.content) > 60
                       then left(new.content, 60) || '...'
                       else new.content end;
begin
  select * into e from public.explore_posts where id = new.post_id;
  if not found then
    return new;
  end if;

  if e.user_id <> new.user_id then
    insert into public.notifications
      (recipient_id, actor_id, type, explore_post_id, explore_comment_id,
       film_title, film_poster_path, comment_preview)
    values
      (e.user_id, new.user_id, 'exploreComment', e.id, new.id,
       coalesce(e.film_title, public.explore_post_blurb(e)), e.film_poster_path, preview);
  end if;

  if new.parent_id is not null then
    select user_id into parent_author from public.explore_comments where id = new.parent_id;
    if parent_author is not null
       and parent_author <> new.user_id
       and parent_author <> e.user_id then
      insert into public.notifications
        (recipient_id, actor_id, type, explore_post_id, explore_comment_id,
         film_title, film_poster_path, comment_preview)
      values
        (parent_author, new.user_id, 'exploreReply', e.id, new.id,
         coalesce(e.film_title, public.explore_post_blurb(e)), e.film_poster_path, preview);
    end if;
  end if;
  return new;
end $$;

-- Older comment notifications have no comment_id: drop the ones whose
-- comment is already gone (nothing left by that person on that review).
delete from public.notifications n
 where n.type = 'comment' and n.comment_id is null and n.activity_id is not null
   and not exists (select 1 from public.comments c
                    where c.activity_id = n.activity_id and c.user_id = n.actor_id);
delete from public.notifications n
 where n.type in ('exploreComment', 'exploreReply')
   and n.explore_comment_id is null and n.explore_post_id is not null
   and not exists (select 1 from public.explore_comments c
                    where c.post_id = n.explore_post_id and c.user_id = n.actor_id);

-- ── 3. Deleting reports how many rows went ───────────────────
-- (Nothing to change on the server: the app now asks for the deleted rows
-- back and treats none as a failure, so a delete RLS refused shows an error
-- instead of looking done.)

-- ── 4. Recount everything from the rows ──────────────────────
-- Only rows whose number is actually wrong are touched.
with t as (select a.id, (select count(*) from public.comments c where c.activity_id = a.id) n
             from public.activities a)
update public.activities a set comment_count = t.n
  from t where t.id = a.id and a.comment_count is distinct from t.n;

with t as (select e.id,
                  (select count(*) from public.explore_comments c where c.post_id = e.id) c,
                  (select count(*) from public.explore_post_votes v where v.post_id = e.id and v.value = 1) ag,
                  (select count(*) from public.explore_post_votes v where v.post_id = e.id and v.value = -1) dis
             from public.explore_posts e)
update public.explore_posts e
   set comment_count = t.c, agree_count = t.ag, disagree_count = t.dis
  from t
 where t.id = e.id
   and (e.comment_count, e.agree_count, e.disagree_count) is distinct from (t.c, t.ag, t.dis);

with t as (select p.id,
                  (select count(*) from public.activities a where a.user_id = p.id) r,
                  (select count(*) from public.follows f where f.followee_id = p.id and f.status = 'accepted') fr,
                  (select count(*) from public.follows f where f.follower_id = p.id and f.status = 'accepted') fg
             from public.profiles p)
update public.profiles p
   set review_count = t.r, follower_count = t.fr, following_count = t.fg
  from t
 where t.id = p.id
   and (p.review_count, p.follower_count, p.following_count) is distinct from (t.r, t.fr, t.fg);

with t as (select l.id,
                  (select count(*) from public.list_items i where i.list_id = l.id) i,
                  (select count(*) from public.list_saves s where s.list_id = l.id) s
             from public.lists l)
update public.lists l
   set item_count = t.i, save_count = t.s
  from t
 where t.id = l.id and (l.item_count, l.save_count) is distinct from (t.i, t.s);
