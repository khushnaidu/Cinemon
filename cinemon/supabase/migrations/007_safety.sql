-- Blocking and moderation: App Store guideline 1.2 for an app with public
-- posts. ADR 0002, items C4 and C2. Run after 006. Safe to re-run.

-- ── 1. Blocks (C4) ────────────────────────────────────────────
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);
create index if not exists user_blocks_blocked_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

-- Only the blocker ever sees the row. The blocked person isn't told.
drop policy if exists "blocks own read"   on public.user_blocks;
drop policy if exists "blocks own insert" on public.user_blocks;
drop policy if exists "blocks own delete" on public.user_blocks;
create policy "blocks own read"   on public.user_blocks for select to authenticated
  using (auth.uid() = blocker_id);
create policy "blocks own insert" on public.user_blocks for insert to authenticated
  with check (auth.uid() = blocker_id);
create policy "blocks own delete" on public.user_blocks for delete to authenticated
  using (auth.uid() = blocker_id);

-- Either direction. Security definer because the blocked side can't read the
-- blocker's row, and still has to be kept out.
create or replace function public.is_blocked_pair(a uuid, b uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks
     where (blocker_id = a and blocked_id = b)
        or (blocker_id = b and blocked_id = a)
  );
$$;

-- Enforcement lives on profiles. Every feed view and comment query joins the
-- author's profile with an inner join (explore_feed, feed_activities,
-- `profiles!inner` in the app), so hiding the profile hides everything they
-- wrote, in both directions, without a filter on each query. Search and
-- profile pages fall out of it too.
drop policy if exists "profiles readable" on public.profiles;
create policy "profiles readable" on public.profiles for select to authenticated
  using (not public.is_blocked_pair(auth.uid(), id));

-- Notifications join the actor with a left join, so they're filtered here.
drop policy if exists "notifications own read" on public.notifications;
create policy "notifications own read" on public.notifications for select to authenticated
  using (auth.uid() = recipient_id and not public.is_blocked_pair(recipient_id, actor_id));

-- No following each other while a block stands.
drop policy if exists "friendships insert" on public.friendships;
create policy "friendships insert" on public.friendships for insert to authenticated
  with check (auth.uid() = sender_id and not public.is_blocked_pair(sender_id, receiver_id));

-- A block ends any follow between the two, both ways. The friendship counter
-- trigger fixes both people's counts as the rows go.
create or replace function public.on_user_block()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.friendships
   where (sender_id = new.blocker_id and receiver_id = new.blocked_id)
      or (sender_id = new.blocked_id and receiver_id = new.blocker_id);
  return null;
end $$;

drop trigger if exists user_blocks_unfollow on public.user_blocks;
create trigger user_blocks_unfollow
  after insert on public.user_blocks
  for each row execute function public.on_user_block();

-- The blocker can't read a blocked profile through the table any more, so the
-- Blocked accounts list comes from here.
create or replace function public.my_blocked_accounts()
returns table (id uuid, username text, photo_url text, blocked_at timestamptz)
language sql
stable
security definer set search_path = public
as $$
  select p.id, p.username, p.photo_url, b.created_at
    from public.user_blocks b
    join public.profiles p on p.id = b.blocked_id
   where b.blocker_id = auth.uid()
   order by b.created_at desc;
$$;

revoke all on function public.my_blocked_accounts() from public, anon;
grant execute on function public.my_blocked_accounts() to authenticated;

-- ── 2. Admins and suspensions (C2) ────────────────────────────
alter table public.profiles add column if not exists is_admin boolean not null default false;
alter table public.profiles add column if not exists suspended_until timestamptz;

-- `profiles self update` lets people write their own row, so these two
-- columns are guarded here. The moderation functions below run as the
-- function owner, and so does the dashboard; a client never does.
create or replace function public.guard_profile_moderation_columns()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon')
     and (new.is_admin, new.suspended_until)
         is distinct from (old.is_admin, old.suspended_until)
  then
    raise exception 'moderation columns are not writable';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_moderation on public.profiles;
create trigger profiles_guard_moderation
  before update on public.profiles
  for each row execute function public.guard_profile_moderation_columns();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.is_suspended(uid uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(
    (select suspended_until > now() from public.profiles where id = uid),
    false
  );
$$;

-- Suspended accounts can still read, edit their profile and delete their own
-- things. They can't publish anything new.
drop policy if exists "explore posts own write" on public.explore_posts;
drop policy if exists "explore posts insert"    on public.explore_posts;
drop policy if exists "explore posts update"    on public.explore_posts;
drop policy if exists "explore posts delete"    on public.explore_posts;
create policy "explore posts insert" on public.explore_posts for insert to authenticated
  with check (auth.uid() = user_id and not public.is_suspended(auth.uid()));
create policy "explore posts update" on public.explore_posts for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and not public.is_suspended(auth.uid()));
create policy "explore posts delete" on public.explore_posts for delete to authenticated
  using (auth.uid() = user_id);

drop policy if exists "explore comments insert" on public.explore_comments;
create policy "explore comments insert" on public.explore_comments for insert to authenticated
  with check (
    auth.uid() = user_id
    and not public.is_suspended(auth.uid())
    and exists (
      select 1 from public.explore_posts e
       where e.id = post_id and e.kind in ('thought', 'discussion')
    )
  );

drop policy if exists "comments own write" on public.comments;
drop policy if exists "comments insert"    on public.comments;
drop policy if exists "comments update"    on public.comments;
drop policy if exists "comments delete"    on public.comments;
create policy "comments insert" on public.comments for insert to authenticated
  with check (auth.uid() = user_id and not public.is_suspended(auth.uid()));
create policy "comments update" on public.comments for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "comments delete" on public.comments for delete to authenticated
  using (auth.uid() = user_id);

drop policy if exists "activities own write" on public.activities;
drop policy if exists "activities insert"    on public.activities;
drop policy if exists "activities update"    on public.activities;
drop policy if exists "activities delete"    on public.activities;
create policy "activities insert" on public.activities for insert to authenticated
  with check (auth.uid() = user_id and not public.is_suspended(auth.uid()));
create policy "activities update" on public.activities for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and not public.is_suspended(auth.uid()));
create policy "activities delete" on public.activities for delete to authenticated
  using (auth.uid() = user_id);

-- ── 3. Report review (C2) ─────────────────────────────────────
alter table public.content_reports
  add column if not exists status text not null default 'open';
alter table public.content_reports
  add column if not exists reviewed_at timestamptz;
alter table public.content_reports
  add column if not exists reviewed_by uuid references public.profiles(id) on delete set null;
alter table public.content_reports drop constraint if exists content_reports_status_check;
alter table public.content_reports add constraint content_reports_status_check
  check (status in ('open', 'actioned', 'dismissed'));
create index if not exists content_reports_open_idx
  on public.content_reports (created_at) where status = 'open';

drop policy if exists "reports admin read" on public.content_reports;
create policy "reports admin read" on public.content_reports for select to authenticated
  using (public.is_admin());

-- Removing a post cascades its reports away, so what was removed, and why,
-- is kept here.
create table if not exists public.moderation_actions (
  id             uuid primary key default gen_random_uuid(),
  admin_id       uuid references public.profiles(id) on delete set null,
  action         text not null check (action in ('remove_post', 'suspend_user', 'unsuspend_user', 'dismiss_reports')),
  target_user_id uuid references public.profiles(id) on delete set null,
  post_id        uuid,
  reason         text,
  snapshot       jsonb,
  created_at     timestamptz not null default now()
);

alter table public.moderation_actions enable row level security;
drop policy if exists "moderation actions admin read" on public.moderation_actions;
create policy "moderation actions admin read" on public.moderation_actions for select to authenticated
  using (public.is_admin());

-- One row per reported post that still has open reports, worst first.
drop view if exists public.moderation_queue;
create view public.moderation_queue
with (security_invoker = true) as
select
  e.id                         as post_id,
  e.user_id                    as author_id,
  p.username                   as author_username,
  p.suspended_until            as author_suspended_until,
  e.kind,
  e.headline,
  e.body,
  e.film_title,
  e.created_at                 as posted_at,
  count(*)                     as report_count,
  array_agg(distinct r.reason) as reasons,
  min(r.created_at)            as first_reported_at
from public.content_reports r
join public.explore_posts e on e.id = r.post_id
join public.profiles p      on p.id = e.user_id
-- Reporters can read their own reports, so without this a non-admin would see
-- a one-report queue of the posts they flagged.
where r.status = 'open' and public.is_admin()
group by e.id, p.id
order by count(*) desc, min(r.created_at);

grant select on public.moderation_queue to authenticated;

create or replace function public.mod_remove_post(target uuid, reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  post public.explore_posts;
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  select * into post from public.explore_posts where id = target;
  if not found then
    return;
  end if;
  insert into public.moderation_actions (admin_id, action, target_user_id, post_id, reason, snapshot)
  values (auth.uid(), 'remove_post', post.user_id, post.id, reason, to_jsonb(post));
  delete from public.explore_posts where id = target;
end $$;

create or replace function public.mod_dismiss_reports(target uuid, reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  update public.content_reports
     set status = 'dismissed', reviewed_at = now(), reviewed_by = auth.uid()
   where post_id = target and status = 'open';
  insert into public.moderation_actions (admin_id, action, post_id, reason)
  values (auth.uid(), 'dismiss_reports', target, reason);
end $$;

-- `suspend_until` null lifts a suspension.
create or replace function public.mod_suspend_user(target uuid, suspend_until timestamptz, reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  update public.profiles set suspended_until = suspend_until where id = target;
  update public.content_reports r
     set status = 'actioned', reviewed_at = now(), reviewed_by = auth.uid()
    from public.explore_posts e
   where r.post_id = e.id and e.user_id = target and r.status = 'open';
  insert into public.moderation_actions (admin_id, action, target_user_id, reason)
  values (auth.uid(),
          case when suspend_until is null then 'unsuspend_user' else 'suspend_user' end,
          target, reason);
end $$;

revoke all on function public.mod_remove_post(uuid, text)                     from public, anon;
revoke all on function public.mod_dismiss_reports(uuid, text)                 from public, anon;
revoke all on function public.mod_suspend_user(uuid, timestamptz, text)       from public, anon;
grant execute on function public.mod_remove_post(uuid, text)                  to authenticated;
grant execute on function public.mod_dismiss_reports(uuid, text)              to authenticated;
grant execute on function public.mod_suspend_user(uuid, timestamptz, text)    to authenticated;

-- Make yourself the first admin from the SQL editor (runs as postgres, so the
-- guard trigger lets it through):
--   update public.profiles set is_admin = true where username = '<you>';
