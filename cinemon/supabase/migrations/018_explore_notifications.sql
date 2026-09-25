-- Activity covers Explore and playlists too: votes on your takes, replies to
-- your posts and replies, and saves of your playlists. Each notification
-- carries what it's about, so tapping it opens that thing. Run after 017.
-- Idempotent.

-- ── 1. What a notification points at ────────────────────────
alter table public.notifications
  add column if not exists explore_post_id uuid references public.explore_posts(id) on delete cascade;
alter table public.notifications
  add column if not exists list_id uuid references public.lists(id) on delete cascade;
-- For votes: 1 agreed, -1 disagreed.
alter table public.notifications
  add column if not exists vote smallint;

create index if not exists notifications_explore_post_idx
  on public.notifications (explore_post_id) where explore_post_id is not null;

-- A post, as a notification's subtitle: its title or the start of it.
create or replace function public.explore_post_blurb(e public.explore_posts)
returns text language sql immutable as $$
  select case
    when char_length(coalesce(nullif(e.headline, ''), e.body)) > 60
      then left(coalesce(nullif(e.headline, ''), e.body), 60) || '...'
    else coalesce(nullif(e.headline, ''), e.body)
  end;
$$;

-- ── 2. Votes ─────────────────────────────────────────────────
-- One notification per voter per post. Changing your vote updates it and
-- brings it back to the top; taking it back removes it.
create or replace function public.notify_on_explore_vote()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  e public.explore_posts;
begin
  if tg_op = 'DELETE' then
    delete from public.notifications
     where type = 'vote' and actor_id = old.user_id and explore_post_id = old.post_id;
    return old;
  end if;

  select * into e from public.explore_posts where id = new.post_id;
  if not found or e.user_id = new.user_id then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    update public.notifications
       set vote = new.value, created_at = now(), is_read = false
     where type = 'vote' and actor_id = new.user_id and explore_post_id = new.post_id;
    if found then
      return new;
    end if;
  end if;

  insert into public.notifications
    (recipient_id, actor_id, type, explore_post_id, vote,
     film_title, film_poster_path, comment_preview)
  values
    (e.user_id, new.user_id, 'vote', e.id, new.value,
     e.film_title, e.film_poster_path, public.explore_post_blurb(e));
  return new;
end $$;

drop trigger if exists on_explore_vote on public.explore_post_votes;
create trigger on_explore_vote
  after insert or update of value or delete on public.explore_post_votes
  for each row execute function public.notify_on_explore_vote();

-- ── 3. Replies ───────────────────────────────────────────────
-- The post's author hears about every reply on it; whoever wrote the reply
-- being answered hears about answers to theirs.
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
      (recipient_id, actor_id, type, explore_post_id,
       film_title, film_poster_path, comment_preview)
    values
      (e.user_id, new.user_id, 'exploreComment', e.id,
       coalesce(e.film_title, public.explore_post_blurb(e)), e.film_poster_path, preview);
  end if;

  if new.parent_id is not null then
    select user_id into parent_author from public.explore_comments where id = new.parent_id;
    if parent_author is not null
       and parent_author <> new.user_id
       and parent_author <> e.user_id then
      insert into public.notifications
        (recipient_id, actor_id, type, explore_post_id,
         film_title, film_poster_path, comment_preview)
      values
        (parent_author, new.user_id, 'exploreReply', e.id,
         coalesce(e.film_title, public.explore_post_blurb(e)), e.film_poster_path, preview);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists on_explore_comment on public.explore_comments;
create trigger on_explore_comment
  after insert on public.explore_comments
  for each row execute function public.notify_on_explore_comment();

-- ── 4. Playlist saves ────────────────────────────────────────
create or replace function public.notify_on_list_save()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  l public.lists;
begin
  if tg_op = 'DELETE' then
    delete from public.notifications
     where type = 'listSave' and actor_id = old.user_id and list_id = old.list_id;
    return old;
  end if;

  select * into l from public.lists where id = new.list_id;
  if not found or l.user_id = new.user_id then
    return new;
  end if;
  insert into public.notifications (recipient_id, actor_id, type, list_id, film_title)
  values (l.user_id, new.user_id, 'listSave', l.id, l.title);
  return new;
end $$;

drop trigger if exists on_list_save on public.list_saves;
create trigger on_list_save
  after insert or delete on public.list_saves
  for each row execute function public.notify_on_list_save();

revoke all on function public.notify_on_explore_vote()    from public, anon, authenticated;
revoke all on function public.notify_on_explore_comment() from public, anon, authenticated;
revoke all on function public.notify_on_list_save()       from public, anon, authenticated;
