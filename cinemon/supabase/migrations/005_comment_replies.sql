-- Reply threads on comments, and comments only where they belong on Explore.
-- Run after 004. Safe to re-run.
--
-- Threads are one level deep, the way Instagram does it: a reply to a reply
-- joins the same thread under the top-level comment (the client prefixes the
-- @username). Deeper nesting reads badly on a phone-width column.

-- ── 1. parent_id on both comment tables ───────────────────────
alter table public.comments
  add column if not exists parent_id uuid references public.comments(id) on delete cascade;
create index if not exists comments_parent_idx
  on public.comments (parent_id) where parent_id is not null;

alter table public.explore_comments
  add column if not exists parent_id uuid references public.explore_comments(id) on delete cascade;
create index if not exists explore_comments_parent_idx
  on public.explore_comments (parent_id) where parent_id is not null;

-- ── 2. Keep threads flat and on the right post ────────────────
-- Re-points a reply-to-a-reply at the thread's root, and refuses a parent
-- from some other post.
create or replace function public.flatten_comment_reply()
returns trigger language plpgsql as $$
declare
  p_parent uuid;
  p_owner  uuid;
begin
  if new.parent_id is null then
    return new;
  end if;

  if tg_table_name = 'comments' then
    select c.parent_id, c.activity_id into p_parent, p_owner
      from public.comments c where c.id = new.parent_id;
    if p_owner is distinct from new.activity_id then
      raise exception 'reply parent belongs to a different post';
    end if;
  else
    select c.parent_id, c.post_id into p_parent, p_owner
      from public.explore_comments c where c.id = new.parent_id;
    if p_owner is distinct from new.post_id then
      raise exception 'reply parent belongs to a different post';
    end if;
  end if;

  if p_parent is not null then
    new.parent_id := p_parent;
  end if;
  return new;
end $$;

drop trigger if exists comments_flatten_reply on public.comments;
create trigger comments_flatten_reply
  before insert on public.comments
  for each row execute function public.flatten_comment_reply();

drop trigger if exists explore_comments_flatten_reply on public.explore_comments;
create trigger explore_comments_flatten_reply
  before insert on public.explore_comments
  for each row execute function public.flatten_comment_reply();

-- ── 3. Explore: comments only on thoughts and discussions ─────
-- Hot takes, reviews and critiques are the poster's stated opinion; the app
-- hides the thread on them, and this stops a client that doesn't.
drop policy if exists "explore comments insert" on public.explore_comments;
create policy "explore comments insert" on public.explore_comments for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.explore_posts e
       where e.id = post_id and e.kind in ('thought', 'discussion')
    )
  );
