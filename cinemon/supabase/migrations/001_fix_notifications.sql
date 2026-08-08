-- Fixes the Activity tab and moves notification creation into the database.
-- Safe to re-run. Already folded into schema.sql.
--
-- Three bugs, all invisible from the client:
--
--   1. Inserts were rolled back. The client inserted with `.select()` chained
--      on, which makes PostgREST add RETURNING. Postgres then applies the
--      SELECT policy to the new row, and that policy only lets the *recipient*
--      see it — never the actor doing the insert. 42501, statement rolled
--      back, zero notifications ever stored.
--
--   2. Deletes silently did nothing. There was no DELETE policy, so unlike /
--      dismiss / "Clear all" matched zero rows. PostgREST still answered 204.
--
--   3. Realtime was never enabled. `supabase_realtime` starts empty on a new
--      project, so `.stream()` returned its initial fetch and never updated.
--
-- Sections 3-7 then move creation server-side, so a notification is a
-- consequence of the like/comment/follow itself rather than a second call the
-- client has to remember to make with the right arguments.

-- ── 1. Let both parties delete ────────────────────────────────
-- Recipient: dismiss / clear. Actor: retract on unlike or un-react.
drop policy if exists "notifications delete" on public.notifications;
create policy "notifications delete" on public.notifications for delete to authenticated
  using (auth.uid() in (recipient_id, actor_id));

-- ── 2. Publish the streamed tables ────────────────────────────
-- replica identity full so Realtime can match a client's filter against a
-- DELETE, which otherwise carries only the primary key.
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

-- ── 3. The one place a notification gets written ──────────────
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

-- ── 4. Likes ──────────────────────────────────────────────────
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

-- ── 5. Reactions ──────────────────────────────────────────────
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

-- ── 6. Comments ───────────────────────────────────────────────
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

-- ── 7. Follow requests ────────────────────────────────────────
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

-- ── 8. Verify ─────────────────────────────────────────────────
select tablename, policyname, cmd
  from pg_policies
 where schemaname = 'public' and tablename = 'notifications'
 order by cmd;

select tablename as published_for_realtime
  from pg_publication_tables
 where pubname = 'supabase_realtime' and schemaname = 'public'
 order by tablename;

select tgname as trigger_name, relname as on_table
  from pg_trigger t join pg_class c on c.oid = t.tgrelid
 where not tgisinternal and tgname like 'on_%'
 order by relname;
