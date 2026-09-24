-- Privacy hardening: make the database match what 35mm.contact/privacy says.
-- ADR 0002, items C1, C3, C5 and C8. Run after 005. Safe to re-run.
--
-- Ship together with the app build that stops reading profiles.email: older
-- builds expect the column and will fail to load profiles once it's gone.

-- ── 1. Email is private (C5) ──────────────────────────────────
-- `profiles` is readable by every signed-in user, and it carried a copy of
-- each user's sign-in email. The copy is dropped rather than hidden behind a
-- column grant: auth.users already holds the address, the client gets its own
-- from the session, and a column grant would need re-granting every time
-- `profiles` gains a column.

-- New sign-ups stop writing the copy before the column goes.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data->>'username',
      'user_' || substr(replace(new.id::text, '-', ''), 1, 10)
    )
  )
  on conflict (id) do nothing;
  return new;
end $$;

alter table public.profiles drop column if exists email;

-- ── 2. Reported posts stay hidden from the reporter (C3) ──────
-- The feed view runs as the viewer, so it can only see the viewer's own
-- reports if the viewer is allowed to read them. Other people's reports stay
-- invisible.
drop policy if exists "reports select own" on public.content_reports;
create policy "reports select own" on public.content_reports for select to authenticated
  using (auth.uid() = reporter_id);

drop view if exists public.explore_feed;
create view public.explore_feed
with (security_invoker = true) as
select
  e.*,
  p.username,
  p.photo_url as user_photo_url,
  (select v.value from public.explore_post_votes v
    where v.post_id = e.id and v.user_id = auth.uid()) as my_vote
from public.explore_posts e
join public.profiles p on p.id = e.user_id
where not exists (
  select 1 from public.content_reports r
   where r.post_id = e.id and r.reporter_id = auth.uid()
);

grant select on public.explore_feed to authenticated;

-- ── 3. Who voted which way is private (C8) ────────────────────
-- Counts live on explore_posts and my_vote only ever reads the viewer's own
-- row, so nothing needs anyone else's vote.
drop policy if exists "explore votes readable" on public.explore_post_votes;
create policy "explore votes readable" on public.explore_post_votes for select to authenticated
  using (auth.uid() = user_id);

-- ── 4. Delete your own account (C1) ───────────────────────────
-- App Store guideline 5.1.1(v): deletion has to start in the app. Deleting
-- the auth user cascades to profiles, and from there to every table (all
-- foreign keys are `on delete cascade`). The counter triggers on friendships,
-- likes, comments and votes correct other people's counts as rows go.
--
-- Storage has no cascade and can't be cleared from SQL, so the app empties
-- avatars/<uid>/ and review-media/<uid>/ before calling this.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = me;
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
