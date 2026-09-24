-- ADR 0004 D1: every kind of user content can be reported, reported content
-- disappears for the person who reported it, and the moderation queue covers
-- all of it. Run after 013. Idempotent.

-- ── 1. content_reports points at any kind of content ──────────
alter table public.content_reports
  add column if not exists activity_id uuid references public.activities(id) on delete cascade;
alter table public.content_reports
  add column if not exists activity_comment_id uuid references public.comments(id) on delete cascade;
alter table public.content_reports
  add column if not exists list_id uuid references public.lists(id) on delete cascade;
alter table public.content_reports
  add column if not exists profile_id uuid references public.profiles(id) on delete cascade;

alter table public.content_reports drop constraint if exists content_reports_target;
alter table public.content_reports add constraint content_reports_target check (
  num_nonnulls(post_id, comment_id, activity_id, activity_comment_id, list_id, profile_id) = 1
);

-- What was reported, for the queue and the app. The queue reads it, so it
-- goes first when this file is rerun.
drop view if exists public.moderation_queue;
alter table public.content_reports drop column if exists target_kind;
alter table public.content_reports add column target_kind text generated always as (
  case
    when post_id             is not null then 'post'
    when comment_id          is not null then 'post_comment'
    when activity_id         is not null then 'activity'
    when activity_comment_id is not null then 'activity_comment'
    when list_id             is not null then 'list'
    else 'profile'
  end
) stored;

-- Reporting the same thing twice is a no-op, whatever the thing is. These
-- also serve the report-hide lookups below.
alter table public.content_reports drop constraint if exists content_reports_reporter_id_post_id_key;
create unique index if not exists content_reports_once_post
  on public.content_reports (reporter_id, post_id) where post_id is not null;
create unique index if not exists content_reports_once_post_comment
  on public.content_reports (reporter_id, comment_id) where comment_id is not null;
create unique index if not exists content_reports_once_activity
  on public.content_reports (reporter_id, activity_id) where activity_id is not null;
create unique index if not exists content_reports_once_activity_comment
  on public.content_reports (reporter_id, activity_comment_id) where activity_comment_id is not null;
create unique index if not exists content_reports_once_list
  on public.content_reports (reporter_id, list_id) where list_id is not null;
create unique index if not exists content_reports_once_profile
  on public.content_reports (reporter_id, profile_id) where profile_id is not null;

-- You can't report yourself or your own things; the app never offers it.
drop policy if exists "reports insert own" on public.content_reports;
create policy "reports insert own" on public.content_reports for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and (profile_id is null or profile_id <> auth.uid())
  );

-- ── 2. What you report disappears for you (ADR 0002 C3, widened) ──
-- In the tables' own read policies, so every view and query obeys it.
create or replace function public.i_reported(kind text, target uuid)
returns boolean
language sql stable security invoker set search_path = public
as $$
  select exists (
    select 1 from public.content_reports r
     where r.reporter_id = auth.uid()
       and case kind
             when 'post'             then r.post_id = target
             when 'post_comment'     then r.comment_id = target
             when 'activity'         then r.activity_id = target
             when 'activity_comment' then r.activity_comment_id = target
             when 'list'             then r.list_id = target
           end
  );
$$;

drop policy if exists "activities readable" on public.activities;
create policy "activities readable" on public.activities for select to authenticated
  using (not public.i_reported('activity', id));

drop policy if exists "comments readable" on public.comments;
create policy "comments readable" on public.comments for select to authenticated
  using (not public.i_reported('activity_comment', id));

drop policy if exists "explore posts readable" on public.explore_posts;
create policy "explore posts readable" on public.explore_posts for select to authenticated
  using (not public.i_reported('post', id));

drop policy if exists "explore comments readable" on public.explore_comments;
create policy "explore comments readable" on public.explore_comments for select to authenticated
  using (not public.i_reported('post_comment', id));

drop policy if exists "lists readable" on public.lists;
create policy "lists readable" on public.lists for select to authenticated
  using (public.can_view_list(user_id, visibility) and not public.i_reported('list', id));

-- ── 3. Moderation across every kind ───────────────────────────
alter table public.moderation_actions drop constraint if exists moderation_actions_action_check;
alter table public.moderation_actions add constraint moderation_actions_action_check
  check (action in ('remove_post', 'remove_content', 'suspend_user', 'unsuspend_user', 'dismiss_reports'));
alter table public.moderation_actions add column if not exists target_kind text;
alter table public.moderation_actions add column if not exists target_id uuid;

-- One row per reported thing with open reports, worst first. `excerpt` is
-- whatever text the thing carries, so the queue reads without a second query.
drop view if exists public.moderation_queue;
create view public.moderation_queue
with (security_invoker = true) as
with open_reports as (
  select r.*,
         coalesce(r.post_id, r.comment_id, r.activity_id, r.activity_comment_id,
                  r.list_id, r.profile_id) as target_id
    from public.content_reports r
   where r.status = 'open' and public.is_admin()
),
targets as (
  select 'post' as kind, e.id, e.user_id as author_id,
         concat_ws(' — ', e.kind::text, e.film_title, e.headline, e.body) as excerpt,
         e.created_at as posted_at
    from public.explore_posts e
  union all
  select 'post_comment', c.id, c.user_id, c.content, c.created_at
    from public.explore_comments c
  union all
  select 'activity', a.id, a.user_id,
         concat_ws(' — ', a.film_title, a.review_text), a.created_at
    from public.activities a
  union all
  select 'activity_comment', c.id, c.user_id, c.content, c.created_at
    from public.comments c
  union all
  select 'list', l.id, l.user_id, concat_ws(' — ', l.title, l.description), l.created_at
    from public.lists l
  union all
  select 'profile', p.id, p.id,
         concat_ws(' — ', '@' || p.username, p.display_name, p.bio), p.created_at
    from public.profiles p
)
select
  r.target_kind                as kind,
  r.target_id,
  t.author_id,
  p.username                   as author_username,
  p.suspended_until            as author_suspended_until,
  t.excerpt,
  t.posted_at,
  count(*)                     as report_count,
  array_agg(distinct r.reason) as reasons,
  min(r.created_at)            as first_reported_at
from open_reports r
join targets t          on t.kind = r.target_kind and t.id = r.target_id
join public.profiles p  on p.id = t.author_id
group by r.target_kind, r.target_id, t.author_id, p.id, t.excerpt, t.posted_at
order by count(*) desc, min(r.created_at);

grant select on public.moderation_queue to authenticated;

-- Deletes the thing and keeps a snapshot, since its reports cascade away with
-- it. Profiles aren't removed: suspend the account or edit it by hand.
create or replace function public.mod_remove_content(kind text, target uuid, reason text)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  snap jsonb;
  author uuid;
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  case kind
    when 'post' then
      select to_jsonb(x), x.user_id into snap, author from public.explore_posts x where x.id = target;
      delete from public.explore_posts where id = target;
    when 'post_comment' then
      select to_jsonb(x), x.user_id into snap, author from public.explore_comments x where x.id = target;
      delete from public.explore_comments where id = target;
    when 'activity' then
      select to_jsonb(x), x.user_id into snap, author from public.activities x where x.id = target;
      delete from public.activities where id = target;
    when 'activity_comment' then
      select to_jsonb(x), x.user_id into snap, author from public.comments x where x.id = target;
      delete from public.comments where id = target;
    when 'list' then
      select to_jsonb(x), x.user_id into snap, author from public.lists x where x.id = target;
      delete from public.lists where id = target;
    else
      raise exception 'can''t remove a %; suspend the account instead', kind;
  end case;
  if snap is null then
    return;
  end if;
  insert into public.moderation_actions
    (admin_id, action, target_user_id, post_id, target_kind, target_id, reason, snapshot)
  values
    (auth.uid(), 'remove_content', author, case when kind = 'post' then target end,
     kind, target, reason, snap);
end $$;

-- The old name still works, for the runbook and anything that calls it.
create or replace function public.mod_remove_post(target uuid, reason text)
returns void
language sql
security definer set search_path = public
as $$
  select public.mod_remove_content('post', target, reason);
$$;

drop function if exists public.mod_dismiss_reports(uuid, text);
create or replace function public.mod_dismiss_reports(target uuid, reason text default null)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  kind text;
begin
  if not public.is_admin() then
    raise exception 'admins only';
  end if;
  update public.content_reports
     set status = 'dismissed', reviewed_at = now(), reviewed_by = auth.uid()
   where target in (post_id, comment_id, activity_id, activity_comment_id, list_id, profile_id)
     and status = 'open'
  returning target_kind into kind;
  insert into public.moderation_actions (admin_id, action, target_kind, target_id, post_id, reason)
  values (auth.uid(), 'dismiss_reports', kind, target,
          case when kind = 'post' then target end, reason);
end $$;

-- Suspending someone closes every open report against them or their things.
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
   where r.status = 'open'
     and (r.profile_id = target
       or r.post_id             in (select id from public.explore_posts    where user_id = target)
       or r.comment_id          in (select id from public.explore_comments where user_id = target)
       or r.activity_id         in (select id from public.activities       where user_id = target)
       or r.activity_comment_id in (select id from public.comments         where user_id = target)
       or r.list_id             in (select id from public.lists            where user_id = target));
  insert into public.moderation_actions (admin_id, action, target_user_id, reason)
  values (auth.uid(),
          case when suspend_until is null then 'unsuspend_user' else 'suspend_user' end,
          target, reason);
end $$;

revoke all on function public.mod_remove_content(text, uuid, text)         from public, anon;
revoke all on function public.mod_remove_post(uuid, text)                  from public, anon;
revoke all on function public.mod_dismiss_reports(uuid, text)              from public, anon;
revoke all on function public.mod_suspend_user(uuid, timestamptz, text)    from public, anon;
grant execute on function public.mod_remove_content(text, uuid, text)      to authenticated;
grant execute on function public.mod_remove_post(uuid, text)               to authenticated;
grant execute on function public.mod_dismiss_reports(uuid, text)           to authenticated;
grant execute on function public.mod_suspend_user(uuid, timestamptz, text) to authenticated;
